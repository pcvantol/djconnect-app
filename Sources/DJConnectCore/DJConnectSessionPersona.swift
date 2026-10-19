import Foundation

public enum DJConnectSessionPersonaValue: String, Codable, CaseIterable, Equatable, Sendable {
    case homeDJ = "home_dj", radioDJ = "radio_dj", clubDJ = "club_dj", festivalDJ = "festival_dj"
    public var localizationKey: String { "ui.session.persona." + rawValue }
}

public struct DJConnectSessionPersonaSnapshot: Codable, Equatable, Sendable {
    public let sessionID: String
    public let selectedPersona: DJConnectSessionPersonaValue
    public let personaRevision: Int
    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id", selectedPersona = "selected_persona", personaRevision = "persona_revision"
    }
    public init(sessionID: String, selectedPersona: DJConnectSessionPersonaValue, personaRevision: Int) {
        self.sessionID = sessionID; self.selectedPersona = selectedPersona; self.personaRevision = personaRevision
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try c.decode(String.self, forKey: .sessionID)
        selectedPersona = try c.decode(DJConnectSessionPersonaValue.self, forKey: .selectedPersona)
        personaRevision = try c.decode(Int.self, forKey: .personaRevision)
        guard !sessionID.isEmpty, personaRevision >= 0 else { throw DJConnectError.invalidResponse }
    }
}

public struct DJConnectSessionPersonaResponse: Decodable, Equatable, Sendable {
    public let success: Bool
    public let contractVersion: Int
    public let sessionID: String
    public let selectedPersona: DJConnectSessionPersonaValue
    public let personaRevision: Int
    public let changed: Bool
    enum CodingKeys: String, CodingKey {
        case success, changed, contractVersion = "contract_version", sessionID = "session_id"
        case selectedPersona = "selected_persona", personaRevision = "persona_revision"
    }
    public var snapshot: DJConnectSessionPersonaSnapshot {
        .init(sessionID: sessionID, selectedPersona: selectedPersona, personaRevision: personaRevision)
    }
}

public struct DJConnectSessionPersonaConflict: Error, Sendable {
    public let current: DJConnectSessionPersonaSnapshot
    public init(current: DJConnectSessionPersonaSnapshot) { self.current = current }
}

struct DJConnectPersonaCapability: Decodable, Sendable {
    let available: Bool
    let version: Int
    let path, method, authentication, ordering, scope: String
    let values: [String]
    let touchReaction: DJConnectPersonaReactionCapability?
    enum CodingKeys: String, CodingKey {
        case touchReaction = "touch_reaction"
        case available, version, path, method, authentication, ordering, scope, values
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        available = try c.decode(Bool.self, forKey: .available); version = try c.decode(Int.self, forKey: .version)
        path = try c.decode(String.self, forKey: .path); method = try c.decode(String.self, forKey: .method)
        authentication = try c.decode(String.self, forKey: .authentication); ordering = try c.decode(String.self, forKey: .ordering)
        scope = try c.decode(String.self, forKey: .scope); values = try c.decode([String].self, forKey: .values)
        // An unknown/malformed additive feature cannot break the base selector.
        touchReaction = try? c.decode(DJConnectPersonaReactionCapability.self, forKey: .touchReaction)
    }
    var isSupported: Bool {
        available && version == 1 && path == "/api/djconnect/v1/session/persona" && method == "POST" &&
        authentication == "paired_device_bearer" && ordering == "expected_persona_revision" &&
        scope == "active_device_bound_owner_session" &&
        values == DJConnectSessionPersonaValue.allCases.map(\.rawValue)
    }
}

public extension DJConnectSessionRuntime {
    /// Retain ordering even when contradictory server fields cannot confirm a value.
    var personaRevisionFloor: Int? {
        [personaRevision, broadcast.session.sessionID == sessionID ? broadcast.session.personaRevision : nil, broadcast.personaConflictRevision]
            .compactMap { $0 }.filter { $0 >= 0 }.max()
    }
    var confirmedPersona: DJConnectSessionPersonaSnapshot? {
        var candidates: [DJConnectSessionPersonaSnapshot] = []
        if let value = selectedPersona, let revision = personaRevision, revision >= 0 {
            candidates.append(.init(sessionID: sessionID, selectedPersona: value, personaRevision: revision))
        }
        if broadcast.session.sessionID == sessionID, let value = broadcast.session.selectedPersona,
           let revision = broadcast.session.personaRevision, revision >= 0 {
            candidates.append(.init(sessionID: sessionID, selectedPersona: value, personaRevision: revision))
        }
        guard let newest = candidates.max(by: { $0.personaRevision < $1.personaRevision }),
              (broadcast.personaConflictRevision ?? -1) < newest.personaRevision,
              candidates.allSatisfy({ $0.personaRevision != newest.personaRevision || $0.selectedPersona == newest.selectedPersona }) else { return nil }
        return newest
    }

    /// Treat the complete HTTP Runtime's two persona tuples together before
    /// forwarding it to the shared live/HTTP Broadcast reducer.
    var personaSafeBroadcast: DJConnectBroadcastState {
        var result = presenceSafeBroadcast
        if let confirmed = confirmedPersona {
            result.session.selectedPersona = confirmed.selectedPersona
            result.session.personaRevision = confirmed.personaRevision
        } else if let floor = personaRevisionFloor {
            result.personaConflictRevision = floor
        }
        return result
    }

    func applying(persona incoming: DJConnectSessionPersonaSnapshot) -> Self {
        guard incoming.sessionID == sessionID, incoming.personaRevision >= 0 else { return self }
        if let floor = personaRevisionFloor {
            if incoming.personaRevision == floor, let confirmed = confirmedPersona,
               confirmed.selectedPersona != incoming.selectedPersona {
                var denied = self
                denied.broadcast.personaConflictRevision = floor
                return denied
            }
            guard incoming.personaRevision > floor ||
                    (incoming.personaRevision == floor && confirmedPersona?.selectedPersona == incoming.selectedPersona) else { return self }
        }
        var result = self
        result.selectedPersona = incoming.selectedPersona; result.personaRevision = incoming.personaRevision
        result.broadcast.session.selectedPersona = incoming.selectedPersona
        result.broadcast.session.personaRevision = incoming.personaRevision
        result.broadcast.personaConflictRevision = nil
        return result
    }
}
