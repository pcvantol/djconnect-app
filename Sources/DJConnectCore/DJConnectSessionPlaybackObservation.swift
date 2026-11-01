import Foundation

/// Whitelisted observation DATA for the existing presentation. No private
/// fields, expiry/rate assertion, owner identity or native permission is encoded.
public struct DJConnectSessionPlaybackObservation: Codable, Equatable, Hashable, Sendable {
    public enum PlaybackState: String, Codable, Sendable {
        case playing, paused, stopped, unknown
        public var symbolName: String {
            switch self {
            case .playing: "play.fill"
            case .paused: "pause.fill"
            case .stopped: "stop.fill"
            case .unknown: "questionmark"
            }
        }
    }
    public let playbackState: PlaybackState
    public let observedAtMilliseconds: Int64
    public var observedAt: Date { Date(timeIntervalSince1970: Double(observedAtMilliseconds) / 1000) }
    enum CodingKeys: String, CodingKey {
        case playbackState = "playback_state"
        case observedAtMilliseconds = "observed_at_ms"
    }
    init(frame: DirectRichFrame) throws {
        guard let state = PlaybackState(rawValue: frame.playback_state),
              Self.validTimestamp(frame.observed_at_ms) else { throw DJConnectError.invalidResponse }
        playbackState = state; observedAtMilliseconds = frame.observed_at_ms
    }
    public init(from decoder: any Decoder) throws {
        let all = try decoder.container(keyedBy: ObservationKey.self)
        guard Set(all.allKeys.map(\.stringValue)) == ["playback_state", "observed_at_ms"] else {
            throw DJConnectError.invalidResponse
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        playbackState = try c.decode(PlaybackState.self, forKey: .playbackState)
        observedAtMilliseconds = try c.decode(Int64.self, forKey: .observedAtMilliseconds)
        guard Self.validTimestamp(observedAtMilliseconds) else { throw DJConnectError.invalidResponse }
    }
    private static func validTimestamp(_ value: Int64) -> Bool {
        // Bounded display DATA only; no comparison to the client's current wall.
        (0...253_402_300_799_999).contains(value)
    }
}

struct ObservationKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
