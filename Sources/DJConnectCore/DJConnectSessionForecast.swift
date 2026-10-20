import Foundation

/// Read-only, producer-authored intentions. Never a queue or a local Planner.
public struct DJConnectSessionForecast: Codable, Equatable, Sendable {
    public struct Anchor: Codable, Equatable, Sendable {
        public let item_id: String
        public let source_url: String
    }
    public struct Section: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let title: String
        public let claim_type: String
        public let text: String
        public let source_url: String?
        var valid: Bool {
            ["current": "current", "guidance": "intention", "aim": "conditional_target"][id] == claim_type &&
                !title.isEmpty && title.count <= 200 && !text.isEmpty && text.count <= 2000 &&
                (source_url == nil || DJConnectSessionForecast.publicLink(source_url!))
        }
    }
    public struct Imagery: Codable, Equatable, Sendable {
        public struct Subject: Codable, Equatable, Sendable {
            public let type: String
            public let id: String
            public let name: String
        }
        public struct Attribution: Codable, Equatable, Sendable {
            public let provider: String?
            public let mark: String?
            public let url: String?
            public let creator: String?
            public let license: String?
        }
        public let subject: Subject
        public let role: String
        public let source_url: String
        public let image_source_url: String?
        public let attribution: Attribution
        public let usage_basis: String
        public let expires_at: String
        public let url: String
        public let cache_policy: String
        public func admittedPath(sessionID: String, at date: Date) -> String? {
            let identity = subject.id.split(separator: ":", omittingEmptySubsequences: false)
            let base62 = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".utf8)
            guard identity.count == 3, identity[0] == "spotify", identity[1] == "artist",
                  identity[2].utf8.count == 22, identity[2].utf8.allSatisfy({ base62.contains($0) }),
                  role == "current", subject.type == "artist", !subject.name.isEmpty, subject.name.count <= 300,
                  usage_basis == "spotify_display_current_only",
                  attribution.provider == "Spotify", attribution.mark == "spotify", attribution.url == source_url,
                  source_url == "https://open.spotify.com/artist/" + String(identity[2]),
                  cache_policy == "active_session_no_store", let deadline = DJConnectSessionForecast.timestamp(expires_at),
                  date < deadline, let parts = URLComponents(string: url), parts.scheme == nil, parts.host == nil,
                  parts.query == nil, parts.fragment == nil, parts.percentEncodedPath == url else { return nil }
            let prefix = "/api/djconnect/v1/session/forecast/art/" + sessionID + "/"
            guard url.hasPrefix(prefix) else { return nil }
            let token = String(url.dropFirst(prefix.count))
            guard (20...128).contains(token.count), token.unicodeScalars.allSatisfy({
                CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).contains($0) && $0.isASCII
            }) else { return nil }
            return url
        }
    }
    public let contract_version: Int
    public let session_id: String
    public let revision: Int
    public let state: String
    public let issued_at: String?
    public let valid_until: String?
    public let nominal_window_seconds: Int
    public let supported_window_seconds: Int
    public let current_anchor: Anchor?
    public let summary: String
    public let sections: [Section]
    public let imagery: [Imagery]

    enum CodingKeys: String, CodingKey {
        case contract_version, session_id, revision, state, issued_at, valid_until
        case nominal_window_seconds, supported_window_seconds, current_anchor, summary, sections, imagery
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        contract_version = try c.decode(Int.self, forKey: .contract_version)
        session_id = try c.decode(String.self, forKey: .session_id)
        revision = try c.decode(Int.self, forKey: .revision)
        state = try c.decode(String.self, forKey: .state)
        issued_at = try c.decodeIfPresent(String.self, forKey: .issued_at)
        valid_until = try c.decodeIfPresent(String.self, forKey: .valid_until)
        nominal_window_seconds = try c.decode(Int.self, forKey: .nominal_window_seconds)
        supported_window_seconds = try c.decode(Int.self, forKey: .supported_window_seconds)
        current_anchor = try c.decodeIfPresent(Anchor.self, forKey: .current_anchor)
        summary = try c.decode(String.self, forKey: .summary)
        sections = try c.decode([Section].self, forKey: .sections)
        // Optional image corruption must not suppress the original authored text.
        imagery = Array(((try? c.decode([LossyBroadcastValue<Imagery>].self, forKey: .imagery))?.compactMap(\.value) ?? []).prefix(2))
    }

    public static func timestamp(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
    static func publicLink(_ value: String) -> Bool {
        guard let url = URLComponents(string: value) else { return false }
        return url.scheme == "https" && url.host?.isEmpty == false && url.user == nil && url.password == nil
    }
    public var structurallyValid: Bool {
        guard contract_version == 1, !session_id.isEmpty, session_id.count <= 200,
              revision >= 0, nominal_window_seconds == 900, (0...900).contains(supported_window_seconds),
              ["ready", "limited", "empty", "expired", "withdrawn"].contains(state),
              summary.count <= 4000, sections.count <= 3, imagery.count <= 8,
              sections.allSatisfy(\.valid), Set(sections.map(\.id)).count == sections.count else { return false }
        if ["empty", "expired", "withdrawn"].contains(state) {
            return summary.isEmpty && sections.isEmpty && imagery.isEmpty && current_anchor == nil && supported_window_seconds == 0
        }
        guard let issued = Self.timestamp(issued_at), let until = Self.timestamp(valid_until),
              until >= issued, until.timeIntervalSince(issued) <= 120 else { return false }
        if let anchor = current_anchor {
            guard !anchor.item_id.isEmpty, Self.publicLink(anchor.source_url) else { return false }
        }
        return true
    }
    public func isVisible(sessionID: String, playbackItemID: String?, playbackSource: String?, at now: Date) -> Bool {
        guard structurallyValid, session_id == sessionID, ["ready", "limited"].contains(state),
              let issued = Self.timestamp(issued_at), let until = Self.timestamp(valid_until),
              issued <= now, now < until else { return false }
        if let anchor = current_anchor {
            return anchor.item_id == playbackItemID && anchor.source_url == playbackSource
        }
        // A current section needs an exact current anchor, even if text is authored.
        return !sections.contains { $0.claim_type == "current" }
    }
}

struct DJConnectForecastCapability: Decodable, Sendable {
    let available: Bool
    let version: Int
    let path: String
    let method: String
    let authentication: String
    let scope: String
    let live_field: String
    let live_event: String
    let nominal_window_seconds: Int
    let history: Bool
    let emitted_imagery_roles: [String]
    let qualified_upcoming_media: Bool
    var supported: Bool {
        available && version == 1 && path == "/api/djconnect/v1/session/forecast/{session_id}" && method == "GET" &&
            authentication == "paired_device_bearer" && scope == "active_device_bound_owner_session" &&
            live_field == "session_forecast" && live_event == "forecast_changed" &&
            nominal_window_seconds == 900 && !history && emitted_imagery_roles == ["current"] && !qualified_upcoming_media
    }
}

public struct DJConnectSessionForecastResponse: Decodable, Sendable {
    public let success: Bool
    public let contract_version: Int
    public let session_id: String
    public let forecast: DJConnectSessionForecast
}

/// Installation-local ordering only. A read/toggle never renews producer validity.
/// Missing/invalid input withdraws content while retaining the last revision floor.
public struct DJConnectForecastCursor: Sendable {
    public private(set) var projection: DJConnectSessionForecast?
    public private(set) var revisionFloor: Int = -1
    private var lastAccepted: DJConnectSessionForecast?
    private var admittedWall: Date?
    private var monotonicDeadline: TimeInterval?
    public let sessionID: String
    public init(sessionID: String) { self.sessionID = sessionID }
    public var remainingLifetime: TimeInterval? {
        monotonicDeadline.map { max(0, $0 - ProcessInfo.processInfo.systemUptime) }
    }

    public mutating func receive(_ incoming: DJConnectSessionForecast?, at now: Date = Date(),
                                 uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard admittedWall.map({ now >= $0 }) ?? true else { projection = nil; return }
        guard let incoming, incoming.structurallyValid, incoming.session_id == sessionID else {
            projection = nil
            return
        }
        guard incoming.revision >= revisionFloor else { return }
        if incoming.revision == revisionFloor {
            // Equal revisions with changed content cannot restore withdrawn content.
            if incoming != lastAccepted { projection = nil }
            return
        }
        revisionFloor = incoming.revision
        let deadline = DJConnectSessionForecast.timestamp(incoming.valid_until).map { uptime + max(0, $0.timeIntervalSince(now)) } ?? uptime
        if incoming.valid_until == lastAccepted?.valid_until, let previous = monotonicDeadline {
            monotonicDeadline = min(previous, deadline)
        } else { monotonicDeadline = deadline }
        admittedWall = now
        lastAccepted = incoming
        projection = incoming
    }
    public mutating func withdraw() { projection = nil }
    public func visible(playbackItemID: String?, playbackSource: String?, at now: Date,
                        uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> DJConnectSessionForecast? {
        guard let admittedWall, now >= admittedWall, let monotonicDeadline, uptime < monotonicDeadline,
              let projection, projection.isVisible(sessionID: sessionID, playbackItemID: playbackItemID,
                                                   playbackSource: playbackSource, at: now) else { return nil }
        return projection
    }
}
