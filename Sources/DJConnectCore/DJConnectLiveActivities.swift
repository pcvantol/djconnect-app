import Foundation

#if os(iOS) && canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
public struct TrackInsightLiveActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var title: String
        public var artist: String
        public var deviceName: String?
        public var progressMS: Int?
        public var durationMS: Int?
        public var artworkURL: URL?
        public var isPlaying: Bool
        public var volumePercent: Int?
        public var isLiked: Bool?
        public var animationSeed: Int

        public init(
            title: String,
            artist: String,
            deviceName: String? = nil,
            progressMS: Int? = nil,
            durationMS: Int? = nil,
            artworkURL: URL? = nil,
            isPlaying: Bool = false,
            volumePercent: Int? = nil,
            isLiked: Bool? = nil,
            animationSeed: Int = 0
        ) {
            self.title = title
            self.artist = artist
            self.deviceName = deviceName
            self.progressMS = progressMS
            self.durationMS = durationMS
            self.artworkURL = artworkURL
            self.isPlaying = isPlaying
            self.volumePercent = volumePercent
            self.isLiked = isLiked
            self.animationSeed = animationSeed
        }
    }

    public var sessionID: String

    public init(sessionID: String) {
        self.sessionID = sessionID
    }
}

@available(iOS 16.1, *)
public extension TrackInsightLiveActivityAttributes.ContentState {
    init(playback: DJConnectPlayback) {
        self.init(
            title: playback.trackName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? playback.trackName! : "DJConnect",
            artist: playback.artistName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? playback.artistName! : "Speelt Nu",
            deviceName: playback.device?.name,
            progressMS: playback.progressMS,
            durationMS: playback.durationMS,
            artworkURL: playback.albumImageURL,
            isPlaying: playback.isPlaying == true,
            volumePercent: playback.volumePercent ?? playback.device?.volumePercent,
            isLiked: playback.isLiked ?? playback.favoriteStatus,
            animationSeed: TrackInsightLiveActivityAttributes.ContentState.seed(for: playback)
        )
    }

    static func seed(for playback: DJConnectPlayback) -> Int {
        let value = "\(playback.trackName ?? "")|\(playback.artistName ?? "")|\(playback.device?.name ?? "")"
        return value.unicodeScalars.reduce(0) { result, scalar in
            ((result &* 31) &+ Int(scalar.value)) & 0x7fffffff
        }
    }

    var progress: Double {
        guard let progressMS, let durationMS, durationMS > 0 else {
            return 0
        }
        return min(1, max(0, Double(progressMS) / Double(durationMS)))
    }
}
#endif


/// Shared renderer palette, not personal content or a new backend Mood model.
/// Only closed color tokens are retained as bounded device UI state.
public enum DJConnectSessionMoodTheme: String, Codable, CaseIterable, Sendable {
    case brand, chill, groove, energy, party

    public init(sessionMood: String?) {
        self = sessionMood.flatMap(Self.init(rawValue:)) ?? .brand
    }
    public var colorValues: [UInt32] {
        switch self {
        case .brand: [0x3285FF, 0x843DF5, 0xCB27F5]
        case .chill: [0x4DA3FF, 0x7B61FF, 0xD184FF]
        case .groove: [0x06C7AD, 0x169BC8, 0x10B981]
        case .energy: [0xDDFF00, 0x00B8FF, 0x39FF78]
        case .party: [0xFF287F, 0xAA38F5, 0xF43DCE]
        }
    }
    public var glow: Double {
        switch self {
        case .brand, .chill: 0.36
        case .groove: 0.46
        case .energy: 0.58
        case .party: 0.66
        }
    }
}

/// Closed, expiring renderer preference only; never proof of an active Session.
public struct DJConnectWidgetPaletteSnapshot: Codable, Equatable, Sendable {
    public static let storageKey = "DJConnectWidgetPalette.v1"
    public let observedAt: Date
    public let theme: DJConnectSessionMoodTheme
    public var expiresAt: Date { observedAt.addingTimeInterval(120) }
    public init(theme: DJConnectSessionMoodTheme, at now: Date) { self.theme = theme; observedAt = now }
    public static func resolve(session: String?, trackInsight: DJConnectSessionMoodTheme?, profile: String?) -> DJConnectSessionMoodTheme {
        if let session, let theme = DJConnectSessionMoodTheme(rawValue: session), theme != .brand { return theme }
        return trackInsight ?? DJConnectSessionMoodTheme(sessionMood: profile)
    }
    public func renderingTheme(at now: Date) -> DJConnectSessionMoodTheme {
        now >= observedAt && now < expiresAt ? theme : .brand
    }
    public static func load(from defaults: UserDefaults, at now: Date) -> Self? {
        guard let data = defaults.data(forKey: storageKey), let value = try? JSONDecoder().decode(Self.self, from: data),
              now >= value.observedAt, now < value.expiresAt else { return nil }
        return value
    }
}

/// Passive surfaces carry neutral runtime status and closed UI styling until
/// an independently qualified passive grant supplies explicit rich content. Owner Moments and
/// authenticated no-store artwork must never be copied into this store.
public struct DJConnectSessionSurfaceSnapshot: Codable, Equatable, Hashable, Sendable {
    public static let storageKey = "DJConnectSessionSurfaceSnapshot.v1"
    public static let widgetKind = "DJConnectSessionWidget"
    public static let legacyKinds = ["DJConnectNowPlayingWidget", "DJConnectQueueWidget", "DJConnectTrackInsightWidget", "DJConnectAskDJWidget"]
    public static let maximumLifetime: TimeInterval = 120
    public let observedAt: Date
    public let expiresAt: Date
    /// Optional for existing caches. This is a renderer-only palette token;
    /// it never grants permission to export Moment/artwork or generated copy.
    public let theme: DJConnectSessionMoodTheme?
    public let rich: DJConnectPassiveActivityContent?

    public init(observedAt: Date, theme: DJConnectSessionMoodTheme? = nil, rich: DJConnectPassiveActivityContent? = nil) {
        self.observedAt = observedAt
        self.expiresAt = min(observedAt.addingTimeInterval(Self.maximumLifetime), rich?.expiresAt ?? .distantFuture)
        self.theme = theme
        self.rich = rich
    }

    public static func observe(runtimeState: String?, authorized: Bool, isDemo: Bool,
                               confirmedMood: String? = nil, at now: Date) -> Self? {
        guard runtimeState == "active", authorized, !isDemo else { return nil }
        // Deliberately independent of playback: pause/wait retains the Session.
        return Self(observedAt: now, theme: confirmedMood.map { DJConnectSessionMoodTheme(sessionMood: $0) })
    }

    public func renderingTheme(at now: Date) -> DJConnectSessionMoodTheme {
        isCurrent(at: now) ? (theme ?? .brand) : .brand
    }

    public static func needsWidgetReload(current: Self?, previous: Self?, lastReloadAt: Date?, at now: Date) -> Bool {
        if (current == nil) != (previous == nil) || current?.theme != previous?.theme { return true }
        guard current != nil else { return false }
        guard let lastReloadAt else { return true }
        // Reload cadence is independent of fresh observations written to cache.
        return now.timeIntervalSince(lastReloadAt) >= 60
    }

    public func isCurrent(at now: Date) -> Bool {
        observedAt <= now && expiresAt > now && expiresAt > observedAt
            && expiresAt.timeIntervalSince(observedAt) <= Self.maximumLifetime
    }

    /// Rich fields may expire earlier than the independently observed Session.
    /// Removing them preserves its original observation, never a sliding lease.
    public func neutral(at now: Date) -> Self? {
        let value = Self(observedAt: observedAt, theme: theme)
        return value.isCurrent(at: now) ? value : nil
    }

    public static func load(from defaults: UserDefaults, at now: Date = Date()) -> Self? {
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(Self.self, from: data), snapshot.isCurrent(at: now) else { return nil }
        return snapshot
    }

    @discardableResult
    public static func replace(_ snapshot: Self?, in defaults: UserDefaults) throws -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try snapshot.map { try encoder.encode($0) }
        var changed = defaults.data(forKey: storageKey) != encoded
        // Only retired transient rendering caches; never chat/history/settings.
        for key in [DJConnectNowPlayingWidgetSnapshot.storageKey, DJConnectQueueWidgetSnapshot.storageKey,
                    DJConnectTrackInsightWidgetSnapshot.storageKey, DJConnectAskDJWidgetSnapshot.storageKey,
                    DJConnectPlaylistsWidgetSnapshot.storageKey] {
            if defaults.object(forKey: key) != nil { changed = true; defaults.removeObject(forKey: key) }
        }
        if changed {
            if let encoded { defaults.set(encoded, forKey: storageKey) }
            else { defaults.removeObject(forKey: storageKey) }
        }
        return changed
    }
}

#if os(iOS) && canImport(ActivityKit)
@available(iOS 16.1, *)
public struct DJConnectSessionLiveActivityAttributes: ActivityAttributes, Sendable {
    public typealias ContentState = DJConnectSessionSurfaceSnapshot
    // Random local runtime identity, never a Profile/session credential or text.
    public let presentationID: String
    public init(presentationID: String) { self.presentationID = presentationID }
}
#endif


/// Device-private presentation bookkeeping, never the App Group projection.
/// Keeping the random ID stable lets ActivityKit dismissal survive app restart.
public enum DJConnectSessionSurfacePresentation {
    // Separate request/build and exact-instance dismissal markers distinguish
    // OS retirement from a user action. No content or authorization is migrated.
    public static let requestedKey = "DJConnectSessionSurface.requested.v2"
    private static let requestedBuildKey = "DJConnectSessionSurface.requestedBuild.v2"
    private static let requestedActivityKey = "DJConnectSessionSurface.requestedActivity.v3"
    private static let dismissedKey = "DJConnectSessionSurface.dismissed.v3"
    public static func canRequest(_ presentationID: String, build: String, in defaults: UserDefaults) -> Bool {
        guard defaults.string(forKey: dismissedKey) != presentationID else { return false }
        return defaults.string(forKey: requestedKey) != presentationID || defaults.string(forKey: requestedBuildKey) != build
    }
    public static func requested(_ presentationID: String, build: String, activityID: String? = nil, in defaults: UserDefaults) {
        defaults.set(presentationID, forKey: requestedKey)
        defaults.set(build, forKey: requestedBuildKey)
        defaults.set(activityID, forKey: requestedActivityKey)
    }
    public static func userDismissed(_ presentationID: String, activityID: String? = nil, in defaults: UserDefaults) {
        guard defaults.string(forKey: requestedKey) == presentationID,
              activityID == nil || defaults.string(forKey: requestedActivityKey) == activityID else { return }
        defaults.set(presentationID, forKey: dismissedKey)
    }
    public static func applicationEnded(_ presentationID: String, wasDismissed: Bool, activityID: String? = nil, in defaults: UserDefaults) {
        if wasDismissed { userDismissed(presentationID, activityID: activityID, in: defaults) }
        guard activityID == nil || defaults.string(forKey: requestedActivityKey) == activityID else { return }
        guard !wasDismissed, defaults.string(forKey: requestedKey) == presentationID else { return }
        defaults.removeObject(forKey: requestedKey)
        defaults.removeObject(forKey: requestedBuildKey)
        defaults.removeObject(forKey: requestedActivityKey)
    }
    public static func identity(for sessionID: String, in deviceDefaults: UserDefaults) -> String {
        let bindingKey = "DJConnectSessionSurface.localBinding"
        let identityKey = "DJConnectSessionSurface.localPresentation"
        if deviceDefaults.string(forKey: bindingKey) == sessionID,
           let existing = deviceDefaults.string(forKey: identityKey), UUID(uuidString: existing) != nil { return existing }
        let identity = UUID().uuidString
        deviceDefaults.set(sessionID, forKey: bindingKey)
        deviceDefaults.set(identity, forKey: identityKey)
        return identity
    }
    public static func end(in deviceDefaults: UserDefaults) {
        deviceDefaults.removeObject(forKey: "DJConnectSessionSurface.localBinding")
        deviceDefaults.removeObject(forKey: "DJConnectSessionSurface.localPresentation")
    }
}
