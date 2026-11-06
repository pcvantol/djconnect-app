import Foundation

public struct DJConnectWatchProxyDJResponseRequest: Codable, Sendable {
    public var text: String?
    public var djText: String?
    public var audioURL: String?
    public var audioType: String?

    public init(text: String? = nil, djText: String? = nil, audioURL: String? = nil, audioType: String? = nil) {
        self.text = text
        self.djText = djText
        self.audioURL = audioURL
        self.audioType = audioType
    }

    enum CodingKeys: String, CodingKey {
        case text
        case djText = "dj_text"
        case audioURL = "audio_url"
        case audioType = "audio_type"
    }
}

/// Own paired-watch purpose. This is never an iPhone widget projection or grant.
/// Installation-local UI choice only, never a server grant or bearer.
public struct DJConnectWatchWidgetConsent: Codable, Equatable, Sendable {
    public static let storageKey = "DJConnectOwnWatchWidgetConsent.v1"
    public let owner: String
    public let binding: String
    public let pairing: String
    public let purpose: String
    public init(owner: String, binding: String, pairing: String) {
        self.owner = owner; self.binding = binding; self.pairing = pairing
        purpose = "paired_watch_widget_v1:track_cover_locked_display"
    }
    public func matches(owner: String, binding: String, pairing: String) -> Bool {
        !owner.isEmpty && !binding.isEmpty && !pairing.isEmpty && self.owner == owner &&
            self.binding == binding && self.pairing == pairing &&
            purpose == "paired_watch_widget_v1:track_cover_locked_display"
    }
}

public struct DJConnectWatchWidgetProjection: Codable, Equatable, Sendable {
    public struct Track: Codable, Equatable, Sendable {
        public let item_id: String
        public let subject_uri: String
        public let track: String
        public let observed_at: String
        public let expires_at: String
        public let source_url: String
        public let attribution: [String: String]
        public let usage_basis: String
        enum CodingKeys: String, CodingKey { case item_id, subject_uri, track, observed_at, expires_at, source_url, attribution, usage_basis }
        public init(from decoder: Decoder) throws {
            let keys = try decoder.container(keyedBy: WatchWidgetKey.self)
            guard Set(keys.allKeys.map(\.stringValue)).isSubset(of: Set(CodingKeys.all)) else { throw DJConnectError.invalidResponse }
            let c = try decoder.container(keyedBy: CodingKeys.self)
            item_id = try c.decode(String.self, forKey: .item_id); subject_uri = try c.decode(String.self, forKey: .subject_uri)
            track = try c.decode(String.self, forKey: .track); observed_at = try c.decode(String.self, forKey: .observed_at)
            expires_at = try c.decode(String.self, forKey: .expires_at); source_url = try c.decode(String.self, forKey: .source_url)
            attribution = try c.decode([String: String].self, forKey: .attribution); usage_basis = try c.decode(String.self, forKey: .usage_basis)
        }
    }
    public let schema_version: Int
    public let scope: String
    public let surface: String
    public let binding_id: String
    public let generation: String
    public let session_id: String
    public let delivery_sequence: Int
    public let as_of: String
    public let observed_at: String
    public let expires_at: String
    public let state: String
    public let cache_policy: DJConnectPassiveSession.CachePolicy
    public let mood: DJConnectPassiveSession.Mood
    public let now_playing: Track?
    public let artwork: [DJConnectPassiveSession.Artwork]
    public let now_playing_status: DJConnectBackgroundSession.Status
    public let artwork_status: DJConnectBackgroundSession.Status
    public let revision: String
    enum CodingKeys: String, CodingKey, CaseIterable {
        case schema_version, scope, surface, binding_id, generation, session_id, delivery_sequence, as_of, observed_at, expires_at, state, cache_policy, mood, now_playing, artwork, now_playing_status, artwork_status, revision
    }
    public init(from decoder: Decoder) throws {
        let keys = try decoder.container(keyedBy: WatchWidgetKey.self)
        guard Set(keys.allKeys.map(\.stringValue)).isSubset(of: Set(CodingKeys.allCases.map(\.rawValue))) else { throw DJConnectError.invalidResponse }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema_version = try c.decode(Int.self, forKey: .schema_version); scope = try c.decode(String.self, forKey: .scope)
        surface = try c.decode(String.self, forKey: .surface); binding_id = try c.decode(String.self, forKey: .binding_id)
        generation = try c.decode(String.self, forKey: .generation); session_id = try c.decode(String.self, forKey: .session_id)
        delivery_sequence = try c.decode(Int.self, forKey: .delivery_sequence); as_of = try c.decode(String.self, forKey: .as_of)
        observed_at = try c.decode(String.self, forKey: .observed_at); expires_at = try c.decode(String.self, forKey: .expires_at)
        state = try c.decode(String.self, forKey: .state); cache_policy = try c.decode(DJConnectPassiveSession.CachePolicy.self, forKey: .cache_policy)
        mood = try c.decode(DJConnectPassiveSession.Mood.self, forKey: .mood); now_playing = try c.decodeIfPresent(Track.self, forKey: .now_playing)
        artwork = try c.decode([DJConnectPassiveSession.Artwork].self, forKey: .artwork)
        now_playing_status = try c.decode(DJConnectBackgroundSession.Status.self, forKey: .now_playing_status)
        artwork_status = try c.decode(DJConnectBackgroundSession.Status.self, forKey: .artwork_status)
        revision = try c.decode(String.self, forKey: .revision)
    }
    public var isValid: Bool {
        guard schema_version == 1, scope == "paired_watch_widget_v1", surface == "watch_widget",
              [binding_id, generation, session_id, revision].allSatisfy(DJConnectPassiveSession.identifier),
              delivery_sequence >= 0, Int64(delivery_sequence) <= 9_007_199_254_740_991,
              ["active", "stale", "withdrawn"].contains(state),
              DJConnectPassiveSession.interval(observed_at, expires_at), let read = DJConnectHistoryEntry.date(as_of),
              let observed = DJConnectHistoryEntry.date(observed_at), read >= observed,
              cache_policy.scope == "current_watch_widget_only", cache_policy.maximum_seconds == 120,
              !cache_policy.renew_on_read, cache_policy.locked_display,
              cache_policy.os_pixel_erasure == "best_effort_when_learned",
              mood.revision >= 0, mood.value == nil || ["chill", "groove", "energy", "party"].contains(mood.value!),
              now_playing_status.isValid, artwork_status.isValid, artwork.count <= 1,
              (now_playing == nil) == (now_playing_status.state != "available"),
              artwork.isEmpty == (artwork_status.state != "available") else { return false }
        if state != "active" { return now_playing == nil && artwork.isEmpty && mood.value == nil && mood.revision == 0 }
        if let t = now_playing {
            guard DJConnectPassiveSession.identifier(t.item_id), DJConnectPassiveSession.spotify(t.subject_uri, type: "track"),
                  DJConnectPassiveSession.bounded(t.track, limit: 640), DJConnectPassiveSession.publicURL(t.source_url),
                  DJConnectPassiveSession.interval(t.observed_at, t.expires_at), t.usage_basis == "spotify_temporary_passive_metadata",
                  t.attribution["mark"] == "spotify", now_playing_status.reason == "qualified" else { return false }
        }
        for a in artwork {
            guard let t = now_playing, a.slot == "now_playing", a.role == "current_cover", a.subject.provider == "spotify",
                  ["track", "album"].contains(a.subject.type), DJConnectPassiveSession.spotify(a.subject.uri, type: a.subject.type),
                  a.subject.type != "track" || a.subject.uri == t.subject_uri,
                  DJConnectPassiveSession.identifier(a.asset_id), DJConnectPassiveSession.identifier(a.media_revision),
                  DJConnectPassiveSession.interval(a.captured_at, a.expires_at), DJConnectPassiveSession.publicURL(a.source_url),
                  !a.crop_allowed, a.usage_basis == "spotify_temporary_passive_cover", a.width > 0, a.height > 0,
                  a.width <= 4096, a.height <= 4096, a.width * a.height <= 16_000_000,
                  a.rights.passive_cache, a.rights.os_snapshot, !a.rights.external_relay, !a.rights.watch_replication,
                  a.rights.paired_watch_cache == true,
                  a.image_path == "/api/djconnect/v1/session/surface/image/\(session_id)/\(a.asset_id)" else { return false }
        }
        return true
    }
    public func isCurrent(at now: Date) -> Bool {
        isValid && state == "active" && DJConnectPassiveSession.current(from: as_of, until: expires_at, at: now)
    }
    public func currentTrack(at now: Date) -> Track? {
        guard isCurrent(at: now), let t = now_playing, DJConnectPassiveSession.current(from: t.observed_at, until: t.expires_at, at: now) else { return nil }
        return t
    }
    public func currentArtwork(at now: Date) -> DJConnectPassiveSession.Artwork? {
        guard currentTrack(at: now) != nil else { return nil }
        return artwork.first { $0.isCurrent(at: now) }
    }
}
private struct WatchWidgetKey: CodingKey {
    let stringValue: String; var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
private extension DJConnectWatchWidgetProjection.Track.CodingKeys {
    static var all: [String] { ["item_id", "subject_uri", "track", "observed_at", "expires_at", "source_url", "attribution", "usage_basis"] }
}
public struct DJConnectWatchWidgetResponse: Codable, Sendable {
    public let success: Bool
    public let contract_version: Int
    public let grant_id: String
    public let passive_session: DJConnectWatchWidgetProjection
    public func validates(sessionID: String) -> Bool {
        success && contract_version == 1 && DJConnectPassiveSession.identifier(grant_id) &&
            passive_session.session_id == sessionID && passive_session.isValid
    }
}
public struct DJConnectWatchWidgetAction: Codable, Sendable {
    public let sessionID: String
    public let binding: String
    public let grantID: String?
    public let enabled: Bool
    public let response: DJConnectWatchWidgetResponse?
    public init(sessionID: String, binding: String, grantID: String? = nil, enabled: Bool = true, response: DJConnectWatchWidgetResponse? = nil) {
        self.sessionID = sessionID; self.binding = binding; self.grantID = grantID; self.enabled = enabled; self.response = response
    }
}
public struct DJConnectWatchWidgetCache: Codable, Sendable {
    public static let storageKey = "DJConnectPairedWatchWidget.v1"
    public let projection: DJConnectWatchWidgetProjection
    public let receivedAt: Date
    public let receivedUptime: TimeInterval
    public var image: Data?
    public init(projection: DJConnectWatchWidgetProjection, image: Data? = nil, at now: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) throws {
        guard projection.isCurrent(at: now), image == nil || projection.currentArtwork(at: now) != nil,
              image?.count ?? 0 <= 24_000 else { throw DJConnectError.invalidResponse }
        self.projection = projection; self.image = image; receivedAt = now; receivedUptime = uptime
    }
    public func isCurrent(at now: Date, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        guard now >= receivedAt, uptime >= receivedUptime, receivedUptime.isFinite, uptime.isFinite,
              image?.count ?? 0 <= 24_000, projection.isCurrent(at: now),
              let end = DJConnectHistoryEntry.date(projection.expires_at) else { return false }
        return uptime - receivedUptime < end.timeIntervalSince(receivedAt)
    }
    public static func load(from defaults: UserDefaults, at now: Date) -> Self? {
        guard let bytes = defaults.data(forKey: storageKey), bytes.count <= 40_000,
              let value = try? JSONDecoder().decode(Self.self, from: bytes), value.isCurrent(at: now) else {
            defaults.removeObject(forKey: storageKey); return nil
        }
        return value
    }
}
