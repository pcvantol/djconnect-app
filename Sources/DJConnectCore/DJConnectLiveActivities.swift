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
