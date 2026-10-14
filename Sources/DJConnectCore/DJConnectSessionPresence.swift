import Foundation

public enum DJConnectSessionPresenceValue: String, Codable, CaseIterable, Equatable, Sendable {
    case musicOnly = "music_only"
    case occasional, balanced, talkative, presenter
    public var localizationKey: String { "ui.session.presence." + rawValue }
}

public struct DJConnectSessionPresenceSnapshot: Codable, Equatable, Sendable {
    public let sessionID: String
    public let selectedPresence: DJConnectSessionPresenceValue
    public let presenceRevision: Int
    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id", selectedPresence = "selected_presence", presenceRevision = "presence_revision"
    }
    public init(sessionID: String, selectedPresence: DJConnectSessionPresenceValue, presenceRevision: Int) {
        self.sessionID = sessionID; self.selectedPresence = selectedPresence; self.presenceRevision = presenceRevision
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try c.decode(String.self, forKey: .sessionID)
        selectedPresence = try c.decode(DJConnectSessionPresenceValue.self, forKey: .selectedPresence)
        presenceRevision = try c.decode(Int.self, forKey: .presenceRevision)
        guard !sessionID.isEmpty, presenceRevision >= 0 else { throw DJConnectError.invalidResponse }
    }
}

public struct DJConnectSessionPresenceResponse: Decodable, Equatable, Sendable {
    public let success: Bool
    public let contractVersion: Int
    public let sessionID: String
    public let selectedPresence: DJConnectSessionPresenceValue
    public let presenceRevision: Int
    public let changed: Bool
    enum CodingKeys: String, CodingKey {
        case success, changed, contractVersion = "contract_version", sessionID = "session_id"
        case selectedPresence = "selected_presence", presenceRevision = "presence_revision"
    }
    public var snapshot: DJConnectSessionPresenceSnapshot {
        .init(sessionID: sessionID, selectedPresence: selectedPresence, presenceRevision: presenceRevision)
    }
}

public struct DJConnectSessionPresenceConflict: Error, Sendable {
    public let current: DJConnectSessionPresenceSnapshot
    public init(current: DJConnectSessionPresenceSnapshot) { self.current = current }
}

struct DJConnectPresenceCapability: Decodable, Sendable {
    let available: Bool
    let version: Int
    let path, method, authentication, ordering, scope: String
    let values: [String]
    let defaultValue: String
    enum CodingKeys: String, CodingKey {
        case available, version, path, method, authentication, ordering, scope, values
        case defaultValue = "default"
    }
    var isSupported: Bool {
        available && version == 1 && path == "/api/djconnect/v1/session/presence" && method == "POST" &&
        authentication == "paired_device_bearer" && ordering == "expected_presence_revision" &&
        scope == "active_device_bound_owner_session" && defaultValue == "balanced" &&
        values == DJConnectSessionPresenceValue.allCases.map(\.rawValue)
    }
}

public extension DJConnectSessionRuntime {
    /// Retain ordering even when contradictory server fields cannot confirm a value.
    var presenceRevisionFloor: Int? {
        [presenceRevision, broadcast.session.sessionID == sessionID ? broadcast.session.presenceRevision : nil, broadcast.presenceConflictRevision]
            .compactMap { $0 }.filter { $0 >= 0 }.max()
    }
    var confirmedPresence: DJConnectSessionPresenceSnapshot? {
        var candidates: [DJConnectSessionPresenceSnapshot] = []
        if let value = selectedPresence, let revision = presenceRevision, revision >= 0 {
            candidates.append(.init(sessionID: sessionID, selectedPresence: value, presenceRevision: revision))
        }
        if broadcast.session.sessionID == sessionID, let value = broadcast.session.selectedPresence,
           let revision = broadcast.session.presenceRevision, revision >= 0 {
            candidates.append(.init(sessionID: sessionID, selectedPresence: value, presenceRevision: revision))
        }
        guard let newest = candidates.max(by: { $0.presenceRevision < $1.presenceRevision }),
              (broadcast.presenceConflictRevision ?? -1) < newest.presenceRevision,
              candidates.allSatisfy({ $0.presenceRevision != newest.presenceRevision || $0.selectedPresence == newest.selectedPresence }) else { return nil }
        return newest
    }

    /// Treat the complete HTTP Runtime's two presence tuples together before
    /// forwarding it to the shared live/HTTP Broadcast reducer.
    var presenceSafeBroadcast: DJConnectBroadcastState {
        var result = broadcast
        if let confirmed = confirmedPresence {
            result.session.selectedPresence = confirmed.selectedPresence
            result.session.presenceRevision = confirmed.presenceRevision
        } else if let floor = presenceRevisionFloor {
            result.presenceConflictRevision = floor
        }
        return result
    }

    func applying(presence incoming: DJConnectSessionPresenceSnapshot) -> Self {
        guard incoming.sessionID == sessionID, incoming.presenceRevision >= 0 else { return self }
        if let floor = presenceRevisionFloor {
            guard incoming.presenceRevision > floor ||
                    (incoming.presenceRevision == floor && confirmedPresence?.selectedPresence == incoming.selectedPresence) else { return self }
        }
        var result = self
        result.selectedPresence = incoming.selectedPresence; result.presenceRevision = incoming.presenceRevision
        result.broadcast.session.selectedPresence = incoming.selectedPresence
        result.broadcast.session.presenceRevision = incoming.presenceRevision
        result.broadcast.presenceConflictRevision = nil
        return result
    }
}
