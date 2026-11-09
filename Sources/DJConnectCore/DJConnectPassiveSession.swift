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
    public func validates(sessionID: String, surface: DJConnectPassiveSurface, projectionVersion: Int = 1) -> Bool {
        success && contract_version == 1 && passive_session.schema_version == projectionVersion && DJConnectPassiveSession.identifier(grant_id) &&
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
        public let rights: DJConnectBackgroundSession.Rights?
        public let sources: [[String: String]]?
        public let expression_license: DJConnectBackgroundSession.ExpressionLicense?
        public let purpose: String?
        public let retained_expires_at: String?
        public init(moment_id: String, published_at: String, text: String, persona: String,
                    source_attribution: [String: String], usage_basis: String, expires_at: String,
                    rights: DJConnectBackgroundSession.Rights? = nil, sources: [[String: String]]? = nil,
                    expression_license: DJConnectBackgroundSession.ExpressionLicense? = nil,
                    purpose: String? = nil, retained_expires_at: String? = nil) {
            self.moment_id = moment_id; self.published_at = published_at; self.text = text; self.persona = persona
            self.source_attribution = source_attribution; self.usage_basis = usage_basis; self.expires_at = expires_at
            self.rights = rights; self.sources = sources; self.expression_license = expression_license
            self.purpose = purpose; self.retained_expires_at = retained_expires_at
        }
        public func isCurrent(at now: Date) -> Bool { DJConnectPassiveSession.current(from: published_at, until: expires_at, at: now) }
    }
    public struct Progress: Codable, Equatable, Hashable, Sendable {
        public let schema_version: Int
        public let position_ms: Int
        public let duration_ms: Int
        public let playback_state: String
        public let observed_at: String
        public let expires_at: String
        public func fraction(at now: Date, playback: NowPlaying, state: String) -> Double? {
            guard schema_version == 1, position_ms >= 0, duration_ms > 0, position_ms <= duration_ms,
                  Int64(duration_ms) <= 9_007_199_254_740_991,
                  ["playing", "paused"].contains(playback_state), playback_state == state,
                  observed_at == playback.observed_at, expires_at == playback.expires_at,
                  DJConnectPassiveSession.interval(observed_at, expires_at),
                  DJConnectPassiveSession.current(from: observed_at, until: expires_at, at: now),
                  let observed = DJConnectHistoryEntry.date(observed_at) else { return nil }
            let elapsed = playback_state == "playing" ? max(0, now.timeIntervalSince(observed)) * 1000 : 0
            return min(1, (Double(position_ms) + elapsed) / Double(duration_ms))
        }
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
        public let progress: Progress?
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
            public let paired_watch_cache: Bool?
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
    public private(set) var contribution_status: DJConnectBackgroundSession.Status?
    public private(set) var now_playing_status: DJConnectBackgroundSession.Status?
    public private(set) var artwork_status: DJConnectBackgroundSession.Status?
    public private(set) var latest_contribution: Contribution?
    public private(set) var latest_contribution_status: DJConnectBackgroundSession.Status?

    public static func identifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128 && value.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil
    }
    static func bounded(_ value: String, limit: Int, empty: Bool = false) -> Bool {
        (empty || !value.isEmpty) && value.unicodeScalars.count <= limit && !value.contains("\u{0000}")
    }
    private static func attribution(_ value: [String: String], allowEmpty: Bool = false) -> Bool {
        (allowEmpty || !value.isEmpty) && value.count <= 8 && value.allSatisfy { bounded($0.key, limit: 64) && bounded($0.value, limit: 1024) }
    }
    static func publicURL(_ value: String) -> Bool {
        guard let u = URLComponents(string: value) else { return false }
        return value.utf8.count <= 2048 && u.scheme == "https" && u.host?.isEmpty == false && u.user == nil && u.password == nil
    }
    static func spotify(_ value: String, type: String = "(track|album)") -> Bool {
        value.range(of: "^spotify:" + type + ":[A-Za-z0-9]{22}$", options: .regularExpression) != nil
    }
    static func interval(_ start: String, _ end: String) -> Bool {
        guard let a = DJConnectHistoryEntry.date(start), let b = DJConnectHistoryEntry.date(end) else { return false }
        return b > a && b.timeIntervalSince(a) <= 120.001
    }
    static func current(from start: String, until end: String, at now: Date) -> Bool {
        guard let a = DJConnectHistoryEntry.date(start), let b = DJConnectHistoryEntry.date(end) else { return false }
        return a <= now && now < b
    }
    public var isValid: Bool {
        if schema_version == 4 {
            guard surface == .widget, let latest_contribution_status, latest_contribution_status.isValid,
                  (latest_contribution == nil) == (latest_contribution_status.state != "available") else { return false }
            if let latest_contribution {
                guard latest_contribution_status.reason == "qualified",
                      hasValidRetainedContribution(latest_contribution) else { return false }
            }
        } else if latest_contribution != nil || latest_contribution_status != nil {
            return false
        }
        if schema_version == 1 { return hasValidFields(allowPublicResearch: false) }
        guard (schema_version == 3 || schema_version == 4), hasValidFields(allowPublicResearch: true),
              let contribution_status, let now_playing_status, let artwork_status,
              contribution_status.isValid, now_playing_status.isValid, artwork_status.isValid,
              (contribution == nil) == (contribution_status.state != "available"),
              (now_playing == nil) == (now_playing_status.state != "available"),
              artwork.isEmpty == (artwork_status.state != "available") else { return false }
        if let contribution {
            guard contribution_status.reason == "qualified", let rights = contribution.rights,
                  DJConnectBackgroundSession.Contribution(rights: rights, sources: contribution.sources,
                    expression_license: contribution.expression_license).validates(contribution) else { return false }
        }
        return now_playing == nil || now_playing_status.reason == "qualified"
    }
    private func hasValidRetainedContribution(_ value: Contribution) -> Bool {
        guard value.purpose == "retained_latest", presence != "music_only",
              Self.identifier(value.moment_id), Self.bounded(value.text, limit: 640),
              DJConnectSessionPersonaValue(rawValue: value.persona) != nil,
              Self.attribution(value.source_attribution, allowEmpty: value.usage_basis == "runtime_authored_direction"),
              ["cc0_facts_authored_expression", "runtime_authored_direction", "public_artist_narration_v1"].contains(value.usage_basis),
              let published = DJConnectHistoryEntry.date(value.published_at),
              let retained = value.retained_expires_at.flatMap(DJConnectHistoryEntry.date),
              let expiry = DJConnectHistoryEntry.date(value.expires_at),
              let snapshotExpiry = DJConnectHistoryEntry.date(expires_at),
              let readAt = DJConnectHistoryEntry.date(as_of),
              published <= readAt, published < expiry, expiry <= min(retained, snapshotExpiry),
              retained.timeIntervalSince(published) <= 1_800.001, let rights = value.rights else { return false }
        return DJConnectBackgroundSession.Contribution(rights: rights, sources: value.sources,
            expression_license: value.expression_license).validates(value)
    }
    // Background v2 has its own decoder and explicit rights/status validation.
    // This common field checker never changes foreground v1 admission.
    func hasValidFields(allowPublicResearch: Bool) -> Bool {
        guard Self.identifier(binding_id), Self.identifier(generation), Self.identifier(session_id),
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
            guard c.purpose == nil, c.retained_expires_at == nil,
                  Self.identifier(c.moment_id), Self.bounded(c.text, limit: 640),
                  DJConnectSessionPersonaValue(rawValue: c.persona) != nil, Self.interval(c.published_at, c.expires_at),
                  Self.attribution(c.source_attribution, allowEmpty: c.usage_basis == "runtime_authored_direction"), (["cc0_facts_authored_expression", "runtime_authored_direction"].contains(c.usage_basis) ||
                    (allowPublicResearch && c.usage_basis == "public_artist_narration_v1")),
                  presence != "music_only" else { return false }
        }
        if let n = now_playing {
            guard schema_version == 3 || schema_version == 4 || n.progress == nil else { return false }
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
    public func currentWidgetContribution(at now: Date) -> Contribution? {
        guard surface == .widget else { return nil }
        guard schema_version == 4 else { return currentContribution(at: now) }
        return isCurrent(at: now) && latest_contribution?.isCurrent(at: now) == true ? latest_contribution : nil
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
        if schema_version == 4 {
            copy.latest_contribution = currentWidgetContribution(at: now)
            if latest_contribution != nil && copy.latest_contribution == nil {
                copy.latest_contribution_status = .init(state: "stale", reason: "expired")
            }
        }
        copy.now_playing = currentPlayback(at: now)
        copy.artwork = artwork.filter { currentArtwork(slot: $0.slot, at: now) != nil }
        if schema_version == 3 || schema_version == 4 {
            if contribution != nil && copy.contribution == nil { copy.contribution_status = .init(state: "stale", reason: "expired") }
            if now_playing != nil && copy.now_playing == nil { copy.now_playing_status = .init(state: "stale", reason: "expired") }
            if !artwork.isEmpty && copy.artwork.isEmpty { copy.artwork_status = .init(state: "stale", reason: "expired") }
        }
        return copy
    }
    public var deadlines: [Date] {
        Set(([expires_at, contribution?.expires_at, latest_contribution?.expires_at, now_playing?.expires_at] + artwork.map { Optional($0.expires_at) })
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
    /// Stage optional pixels into the same original observation. Never rebuild
    /// the receive pair after asynchronous image IO or restore it from DATA.
    public func staging(pixels next: [String: Data], at now: Date,
                        uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) throws -> Self {
        guard isCurrent(at: now, uptime: uptime), next.count <= 2,
              next.values.allSatisfy({ $0.count <= Self.maximumImageBytes }),
              next.keys.allSatisfy({ projection.currentArtwork(slot: $0, at: now) != nil }) else { throw DJConnectError.invalidResponse }
        var copy = removingExpiredFields(at: now)
        copy.pixels = next
        return copy
    }
    /// A pure read/as_of change or a fresh observation of the same item does not
    /// spend a widget reload. Cache expiry still keeps its original source bound.
    public func hasSameDisplayContent(as other: Self?) -> Bool {
        guard let other else { return false }
        let a = projection, b = other.projection
        let musicEqual = a.now_playing?.item_id == b.now_playing?.item_id && a.now_playing?.subject_uri == b.now_playing?.subject_uri &&
            a.now_playing?.track == b.now_playing?.track && a.now_playing?.artist == b.now_playing?.artist &&
            a.now_playing?.album == b.now_playing?.album && a.now_playing?.attribution == b.now_playing?.attribution &&
            a.now_playing?.progress?.duration_ms == b.now_playing?.progress?.duration_ms && a.playback_state == b.playback_state
        return a.binding_id == b.binding_id && a.generation == b.generation && a.state == b.state &&
            a.mood == b.mood && a.presence == b.presence && a.persona == b.persona &&
            a.contribution == b.contribution && a.latest_contribution == b.latest_contribution &&
            musicEqual && a.artwork == b.artwork && pixels == other.pixels
    }
    public static func key(_ surface: DJConnectPassiveSurface) -> String { "DJConnectPassiveSurface.v1." + surface.rawValue }
    public static func replace(_ value: Self?, surface: DJConnectPassiveSurface, in defaults: UserDefaults) throws {
        try replace(value, surface: surface, in: defaults, now: { Date() }, uptime: { ProcessInfo.processInfo.systemUptime })
    }
    // Deterministic clock seam for tests only; production publication samples
    // the actual invocation, never the cache's saved receive timestamp.
    static func replace(_ value: Self?, surface: DJConnectPassiveSurface, in defaults: UserDefaults,
                        at now: Date, uptime: TimeInterval) throws {
        try replace(value, surface: surface, in: defaults, now: { now }, uptime: { uptime })
    }
    static func replace(_ value: Self?, surface: DJConnectPassiveSurface, in defaults: UserDefaults,
                        now: () -> Date, uptime: () -> TimeInterval) throws {
        guard let value else { defaults.removeObject(forKey: key(surface)); return }
        guard !Task.isCancelled, value.projection.surface == surface, value.isCurrent(at: now(), uptime: uptime()) else { throw DJConnectError.invalidResponse }
        let data = try JSONEncoder().encode(value)
        guard data.count <= maximumEncodedBytes else { throw DJConnectError.payloadTooLarge(limitBytes: maximumEncodedBytes, actualBytes: data.count) }
        guard !Task.isCancelled, value.isCurrent(at: now(), uptime: uptime()) else { throw DJConnectError.invalidResponse }
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
    /// Local render invalidation only. Artwork still requires a current grant
    /// and exact matching App Group pixels in the extension.
    public let hasCachedPlaybackArtwork: Bool?
    /// Absent for every legacy encoding. DATA only: the explicit local-v2
    /// codec and actual native custody are independently required.
    public let directLocalVersion: Int?
    /// Negotiated foreground projection; independent of the direct-local codec.
    public let foregroundProjectionVersion: Int?
    public let researchAttribution: DJConnectDirectResearchAttribution?
    public init?(cache: DJConnectPassiveSurfaceCache, at now: Date = Date()) {
        guard cache.projection.surface == .liveActivity, cache.projection.cache_policy.locked_display,
              cache.isCurrent(at: now), let expiry = DJConnectHistoryEntry.date(cache.projection.expires_at) else { return nil }
        let p = cache.projection.removingExpiredFields(at: now)
        bindingID = p.binding_id; generation = p.generation; sequence = p.delivery_sequence
        receivedAt = cache.receivedAt; receivedUptime = cache.receivedUptime
        nowPlaying = p.currentPlayback(at: now)
        // A playing-track Activity does not render DJ prose. Exclude that field
        // in v3 so its shorter publication lease/budget cannot remove the track.
        contribution = p.schema_version == 3 && nowPlaying != nil ? nil : p.currentContribution(at: now)
        playbackState = nowPlaying == nil ? nil : p.playback_state
        hasCachedPlaybackArtwork = nowPlaying != nil &&
            p.currentArtwork(slot: "now_playing", at: now) != nil && cache.pixels["now_playing"] != nil ? true : nil
        directLocalVersion = nil; researchAttribution = nil
        foregroundProjectionVersion = p.schema_version == 3 ? 3 : nil
        expiresAt = p.schema_version == 3 && nowPlaying != nil ? expiry : (p.deadlines.min() ?? expiry)
        guard contribution != nil || nowPlaying != nil,
              let encoded = try? JSONEncoder().encode(self), encoded.count <= 2_800 else { return nil }
    }
    /// Internal presentation-data assembly only; does not map source clocks or
    /// supply a native start/update permit. No public positive factory exists.
    init(directLocalBinding binding: String, generation: String, sequence: Int,
         receivedAt: Date, receivedUptime: TimeInterval, expiresAt: Date,
         contribution: DJConnectPassiveSession.Contribution?, nowPlaying: DJConnectPassiveSession.NowPlaying?,
         playbackState: String?, researchAttribution: DJConnectDirectResearchAttribution?) {
        bindingID = binding; self.generation = generation; self.sequence = sequence
        self.receivedAt = receivedAt; self.receivedUptime = receivedUptime; self.expiresAt = expiresAt
        self.contribution = contribution; self.nowPlaying = nowPlaying; self.playbackState = playbackState
        hasCachedPlaybackArtwork = nil
        directLocalVersion = 2; self.researchAttribution = researchAttribution
        foregroundProjectionVersion = nil
    }
    public func isCurrent(at now: Date, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        now >= receivedAt && now < expiresAt && uptime >= receivedUptime &&
            uptime - receivedUptime < expiresAt.timeIntervalSince(receivedAt)
    }
}
