import Foundation

#if os(iOS) && canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
public struct TrackInsightLiveActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var title: String
        public var artist: String
        public var genre: String?
        public var mood: String?
        public var vibe: String?
        public var bpm: Int?
        public var key: String?
        public var energy: Double?
        public var danceability: Double?
        public var intensity: Double?
        public var musicDNAMatchPercent: Int?
        public var summary: String?
        public var animationSeed: Int

        public init(
            title: String,
            artist: String,
            genre: String? = nil,
            mood: String? = nil,
            vibe: String? = nil,
            bpm: Int? = nil,
            key: String? = nil,
            energy: Double? = nil,
            danceability: Double? = nil,
            intensity: Double? = nil,
            musicDNAMatchPercent: Int? = nil,
            summary: String? = nil,
            animationSeed: Int = 0
        ) {
            self.title = title
            self.artist = artist
            self.genre = genre
            self.mood = mood
            self.vibe = vibe
            self.bpm = bpm
            self.key = key
            self.energy = energy
            self.danceability = danceability
            self.intensity = intensity
            self.musicDNAMatchPercent = musicDNAMatchPercent
            self.summary = summary
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
    init(insight: TrackInsight) {
        self.init(
            title: insight.title,
            artist: insight.artist,
            genre: insight.genre,
            mood: insight.mood,
            vibe: insight.vibe,
            bpm: insight.bpm.map { Int($0.rounded()) },
            key: insight.key,
            energy: insight.energy,
            danceability: insight.danceability,
            intensity: insight.intensity,
            musicDNAMatchPercent: insight.musicDNAMatchPercent,
            summary: insight.summary,
            animationSeed: TrackInsightLiveActivityAttributes.ContentState.seed(for: insight)
        )
    }

    static func seed(for insight: TrackInsight) -> Int {
        let value = "\(insight.title)|\(insight.artist)|\(insight.genre ?? "")|\(insight.vibe ?? "")"
        return value.unicodeScalars.reduce(0) { result, scalar in
            ((result &* 31) &+ Int(scalar.value)) & 0x7fffffff
        }
    }
}
#endif
