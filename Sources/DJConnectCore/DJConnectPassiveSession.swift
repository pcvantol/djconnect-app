import Foundation

/// Frozen Core passive-surface v1. A grant is app RAM, never part of the OS cache.
public enum DJConnectPassiveSurface: String, Codable, CaseIterable, Sendable {
    case widget, liveActivity = "live_activity"
}

public struct DJConnectPassiveSurfaceResponse: Decodable, Sendable {
    public let success: Bool
    public let contract_version: Int
    public let grant_id: String
    public let passive_session: DJConnectPassiveSession
    public func validates(sessionID: String, surface: DJConnectPassiveSurface) -> Bool {
        success && contract_version == 1 && DJConnectPassiveSession.identifier(grant_id) &&
        passive_session.session_id == sessionID && passive_session.surface == surface && passive_session.isValid
    }
}

/// Only these independently authorized fields may be copied into the current OS cache.
public struct DJConnectPassiveSession: Codable, Equatable, Hashable, Sendable {
    public struct CachePolicy: Codable, Equatable, Hashable, Sendable {
        public let scope: String
        public let maximum_seconds: Int
        public let renew_on_read: Bool
        public let locked_display: Bool
        public let os_pixel_erasure: String
    }
    public struct Mood: Codable, Equatable, Hashable, Sendable {
        public let value: String?
        public let revision: Int
    }
    public struct Navigation: Codable, Equatable, Hashable, Sendable {
        public let kind: String
        public let session_id: String
    }
    public struct Contribution: Codable, Equatable, Hashable, Sendable {
        public let moment_id: String
        public let published_at: String
        public let text: String
        public let persona: String
        public let source_attribution: [String: String]
        public let usage_basis: String
        public let expires_at: String
        public func isCurrent(at now: Date) -> Bool { DJConnectPassiveSession.current(from: published_at, until: expires_at, at: now) }
    }
    public struct NowPlaying: Codable, Equatable, Hashable, Sendable {
        public let item_id: String
        public let subject_uri: String
        public let track: String
        public let artist: String
        public let album: String
        public let observed_at: String
        public let expires_at: String
        public let source_url: String
        public let attribution: [String: String]
        public let usage_basis: String
        public func isCurrent(at now: Date) -> Bool { DJConnectPassiveSession.current(from: observed_at, until: expires_at, at: now) }
    }
    public struct Artwork: Codable, Equatable, Hashable, Sendable {
        public struct Subject: Codable, Equatable, Hashable, Sendable {
            public let provider: String
            public let uri: String
            public let type: String
            public let album_uri: String?
        }
        public struct Rights: Codable, Equatable, Hashable, Sendable {
            public let passive_cache: Bool
            public let os_snapshot: Bool
            public let external_relay: Bool
            public let watch_replication: Bool
        }
        public let slot: String
        public let asset_id: String
        public let subject: Subject
        public let role: String
        public let media_revision: String
        public let captured_at: String
        public let expires_at: String
        public let source_url: String
        public let attribution: [String: String]
        public let alt_text: [String: String]
        public let width: Int
        public let height: Int
        public let crop_allowed: Bool
        public let usage_basis: String
        public let image_path: String
        public let rights: Rights
        public func isCurrent(at now: Date) -> Bool { DJConnectPassiveSession.current(from: captured_at, until: expires_at, at: now) }
    }
    public let schema_version: Int
    public let surface: DJConnectPassiveSurface
    public let binding_id: String
    public let generation: String
    public let session_id: String
    public let delivery_sequence: Int
    public let revision: String
    public let as_of: String
    public let observed_at: String
    public let expires_at: String
    public let state: String
    public let playback_state: String
    public let cache_policy: CachePolicy
    public let mood: Mood
    public let presence: String
    public let persona: String
    public let navigation: Navigation
    public private(set) var contribution: Contribution?
    public private(set) var now_playing: NowPlaying?
    public private(set) var artwork: [Artwork]

    public static func identifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128 && value.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil
    }
    private static func bounded(_ value: String, limit: Int, empty: Bool = false) -> Bool {
        (empty || !value.isEmpty) && value.unicodeScalars.count <= limit && !value.contains("\u{0000}")
    }
    private static func attribution(_ value: [String: String], allowEmpty: Bool = false) -> Bool {
        (allowEmpty || !value.isEmpty) && value.count <= 8 && value.allSatisfy { bounded($0.key, limit: 64) && bounded($0.value, limit: 1024) }
    }
    private static func publicURL(_ value: String) -> Bool {
        guard let u = URLComponents(string: value) else { return false }
        return value.utf8.count <= 2048 && u.scheme == "https" && u.host?.isEmpty == false && u.user == nil && u.password == nil
    }
    private static func spotify(_ value: String, type: String = "(track|album)") -> Bool {
        value.range(of: "^spotify:" + type + ":[A-Za-z0-9]{22}$", options: .regularExpression) != nil
    }
    private static func interval(_ start: String, _ end: String) -> Bool {
        guard let a = DJConnectHistoryEntry.date(start), let b = DJConnectHistoryEntry.date(end) else { return false }
        return b > a && b.timeIntervalSince(a) <= 120.001
    }
    static func current(from start: String, until end: String, at now: Date) -> Bool {
        guard let a = DJConnectHistoryEntry.date(start), let b = DJConnectHistoryEntry.date(end) else { return false }
        return a <= now && now < b
    }
    public var isValid: Bool {
        guard schema_version == 1, Self.identifier(binding_id), Self.identifier(generation), Self.identifier(session_id),
              Self.identifier(revision), delivery_sequence >= 0, ["active", "stale"].contains(state),
              ["idle", "stopped", "playing", "paused"].contains(playback_state),
              Self.interval(observed_at, expires_at), DJConnectHistoryEntry.date(as_of) != nil,
              cache_policy.scope == "current_surface_only", cache_policy.maximum_seconds == 120,
              !cache_policy.renew_on_read, cache_policy.os_pixel_erasure == "best_effort_when_learned",
              surface != .liveActivity || cache_policy.locked_display,
              mood.revision >= 0, mood.value == nil || ["chill", "groove", "energy", "party"].contains(mood.value!),
              DJConnectSessionPresenceValue(rawValue: presence) != nil, DJConnectSessionPersonaValue(rawValue: persona) != nil,
              navigation.kind == "open_session", navigation.session_id == session_id,
              artwork.count <= 2, Set(artwork.map(\.slot)).count == artwork.count else { return false }
        if let c = contribution {
            guard Self.identifier(c.moment_id), Self.bounded(c.text, limit: 640),
                  DJConnectSessionPersonaValue(rawValue: c.persona) != nil, Self.interval(c.published_at, c.expires_at),
                  Self.attribution(c.source_attribution, allowEmpty: c.usage_basis == "runtime_authored_direction"), ["cc0_facts_authored_expression", "runtime_authored_direction"].contains(c.usage_basis),
                  presence != "music_only" else { return false }
        }
        if let n = now_playing {
            guard Self.identifier(n.item_id), Self.spotify(n.subject_uri, type: "track"), Self.bounded(n.track, limit: 640),
                  Self.bounded(n.artist, limit: 256, empty: true), Self.bounded(n.album, limit: 256, empty: true),
                  Self.interval(n.observed_at, n.expires_at), Self.publicURL(n.source_url), Self.attribution(n.attribution),
                  n.usage_basis == "spotify_temporary_passive_metadata" else { return false }
        }
        for a in artwork {
            guard ["contribution", "now_playing"].contains(a.slot), Self.identifier(a.asset_id), Self.identifier(a.media_revision),
                  a.subject.provider == "spotify", ["track", "album"].contains(a.subject.type), Self.spotify(a.subject.uri, type: a.subject.type),
                  a.subject.album_uri == nil || Self.spotify(a.subject.album_uri!, type: "album"),
                  a.role == (a.slot == "contribution" ? "contextual_cover" : "current_cover"),
                  Self.interval(a.captured_at, a.expires_at), Self.publicURL(a.source_url), Self.attribution(a.attribution),
                  a.usage_basis == "spotify_temporary_passive_cover", !a.crop_allowed,
                  a.rights.passive_cache, a.rights.os_snapshot, !a.rights.external_relay, !a.rights.watch_replication,
                  a.width > 0, a.height > 0, a.width <= 4096, a.height <= 4096, a.width * a.height <= 16_000_000,
                  a.image_path == "/api/djconnect/v1/session/surface/image/\(session_id)/\(a.asset_id)",
                  Set(a.alt_text.keys) == Set(["en", "nl", "de", "fr", "es"]),
                  a.alt_text.values.allSatisfy({ Self.bounded($0, limit: 640) }),
                  a.slot != "contribution" || contribution != nil,
                  a.slot != "now_playing" || now_playing != nil else { return false }
            // A current track cover must never be relabelled as another recording.
            if a.slot == "now_playing", a.subject.type == "track", a.subject.uri != now_playing?.subject_uri { return false }
        }
        return true
    }
    public func isCurrent(at now: Date) -> Bool {
        isValid && state == "active" && Self.current(from: as_of, until: expires_at, at: now)
    }
    public func currentContribution(at now: Date) -> Contribution? {
        isCurrent(at: now) && contribution?.isCurrent(at: now) == true ? contribution : nil
    }
    public func currentPlayback(at now: Date) -> NowPlaying? {
        isCurrent(at: now) && now_playing?.isCurrent(at: now) == true ? now_playing : nil
    }
    public func currentArtwork(slot: String, at now: Date) -> Artwork? {
        guard isCurrent(at: now), slot == "contribution" ? currentContribution(at: now) != nil : currentPlayback(at: now) != nil else { return nil }
        return artwork.first { $0.slot == slot && $0.isCurrent(at: now) }
    }
    public func removingExpiredFields(at now: Date) -> Self {
        var copy = self
        copy.contribution = currentContribution(at: now)
        copy.now_playing = currentPlayback(at: now)
        copy.artwork = artwork.filter { currentArtwork(slot: $0.slot, at: now) != nil }
        return copy
    }
    public var deadlines: [Date] {
        Set(([expires_at, contribution?.expires_at, now_playing?.expires_at] + artwork.map { Optional($0.expires_at) })
            .compactMap { $0.flatMap(DJConnectHistoryEntry.date) }).sorted()
    }
}

/// One current grant-qualified snapshot, bounded pixels and a process-independent
/// uptime fence. No HTTP envelope/grant/bearer, history, or arbitrary URL cache.
public struct DJConnectPassiveSurfaceCache: Codable, Equatable, Sendable {
    public static let maximumEncodedBytes = 1_000_000
    public static let maximumImageBytes = 256_000
    public private(set) var projection: DJConnectPassiveSession
    public let receivedAt: Date
    public let receivedUptime: TimeInterval
    public private(set) var pixels: [String: Data]
    public init(projection: DJConnectPassiveSession, pixels: [String: Data] = [:],
                at now: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) throws {
        guard projection.isValid, pixels.count <= 2, Set(pixels.keys).isSubset(of: ["contribution", "now_playing"]),
              pixels.values.allSatisfy({ $0.count <= Self.maximumImageBytes }),
              pixels.keys.allSatisfy({ projection.currentArtwork(slot: $0, at: now) != nil }) else { throw DJConnectError.invalidResponse }
        self.projection = projection; self.pixels = pixels; receivedAt = now; receivedUptime = uptime
    }
    public func isCurrent(at now: Date, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        guard pixels.count <= 2, pixels.values.allSatisfy({ $0.count <= Self.maximumImageBytes }),
              pixels.keys.allSatisfy({ slot in projection.artwork.contains(where: { $0.slot == slot }) }),
              now >= receivedAt, uptime >= receivedUptime, let expiry = DJConnectHistoryEntry.date(projection.expires_at) else { return false }
        return uptime - receivedUptime < expiry.timeIntervalSince(receivedAt) && projection.isCurrent(at: now)
    }
    public func removingExpiredFields(at now: Date) -> Self {
        var copy = self
        copy.projection = projection.removingExpiredFields(at: now)
        copy.pixels = pixels.filter { projection.currentArtwork(slot: $0.key, at: now) != nil }
        return copy // Keep the original receive time and uptime fence.
    }
    /// A pure read/as_of change or a fresh observation of the same item does not
    /// spend a widget reload. Cache expiry still keeps its original source bound.
    public func hasSameDisplayContent(as other: Self?) -> Bool {
        guard let other else { return false }
        let a = projection, b = other.projection
        let musicEqual = a.now_playing?.item_id == b.now_playing?.item_id && a.now_playing?.subject_uri == b.now_playing?.subject_uri &&
            a.now_playing?.track == b.now_playing?.track && a.now_playing?.artist == b.now_playing?.artist &&
            a.now_playing?.album == b.now_playing?.album && a.now_playing?.attribution == b.now_playing?.attribution
        return a.binding_id == b.binding_id && a.generation == b.generation && a.state == b.state &&
            a.mood == b.mood && a.presence == b.presence && a.persona == b.persona &&
            a.contribution == b.contribution && musicEqual && a.artwork == b.artwork && pixels == other.pixels
    }
    public static func key(_ surface: DJConnectPassiveSurface) -> String { "DJConnectPassiveSurface.v1." + surface.rawValue }
    public static func replace(_ value: Self?, surface: DJConnectPassiveSurface, in defaults: UserDefaults) throws {
        guard let value else { defaults.removeObject(forKey: key(surface)); return }
        guard value.projection.surface == surface, value.isCurrent(at: value.receivedAt, uptime: value.receivedUptime) else { throw DJConnectError.invalidResponse }
        let data = try JSONEncoder().encode(value)
        guard data.count <= maximumEncodedBytes else { throw DJConnectError.payloadTooLarge(limitBytes: maximumEncodedBytes, actualBytes: data.count) }
        defaults.set(data, forKey: key(surface))
    }
    public static func load(surface: DJConnectPassiveSurface, from defaults: UserDefaults, at now: Date = Date(),
                            uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Self? {
        guard let data = defaults.data(forKey: key(surface)), data.count <= maximumEncodedBytes,
              let value = try? JSONDecoder().decode(Self.self, from: data), value.projection.surface == surface,
              value.isCurrent(at: now, uptime: uptime) else {
            defaults.removeObject(forKey: key(surface)); return nil
        }
        return value
    }
}

/// ActivityKit has a small state budget. Keep complete qualified text and source
/// attribution or fall back to neutral; never truncate a factual sentence to fit.
public struct DJConnectPassiveActivityContent: Codable, Equatable, Hashable, Sendable {
    public let bindingID: String
    public let generation: String
    public let sequence: Int
    public let receivedAt: Date
    public let receivedUptime: TimeInterval
    public let expiresAt: Date
    public let contribution: DJConnectPassiveSession.Contribution?
    public let nowPlaying: DJConnectPassiveSession.NowPlaying?
    /// Optional so an already published activity remains decodable after upgrade.
    public let playbackState: String?
    public init?(cache: DJConnectPassiveSurfaceCache, at now: Date = Date()) {
        guard cache.projection.surface == .liveActivity, cache.projection.cache_policy.locked_display,
              cache.isCurrent(at: now), let expiry = DJConnectHistoryEntry.date(cache.projection.expires_at) else { return nil }
        let p = cache.projection.removingExpiredFields(at: now)
        bindingID = p.binding_id; generation = p.generation; sequence = p.delivery_sequence
        receivedAt = cache.receivedAt; receivedUptime = cache.receivedUptime
        contribution = p.currentContribution(at: now); nowPlaying = p.currentPlayback(at: now)
        playbackState = nowPlaying == nil ? nil : p.playback_state
        expiresAt = p.deadlines.min() ?? expiry
        guard contribution != nil || nowPlaying != nil,
              let encoded = try? JSONEncoder().encode(self), encoded.count <= 2_800 else { return nil }
    }
    public func isCurrent(at now: Date, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        now >= receivedAt && now < expiresAt && uptime >= receivedUptime &&
            uptime - receivedUptime < expiresAt.timeIntervalSince(receivedAt)
    }
}
