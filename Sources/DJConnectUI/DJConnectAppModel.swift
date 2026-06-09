import Combine
import DJConnectCore
import Foundation

@MainActor
public final class DJConnectAppModel: ObservableObject {
    @Published public var homeAssistantURL = ""
    @Published public var pairingStatus: DJConnectPairingStatus = .unpaired
    @Published public var isConnected = false
    @Published public var backendAvailable = true
    @Published public var updateRequiredMessage: String?
    @Published public var playback: DJConnectPlayback?
    @Published public var queue: [String] = []
    @Published public var playlists: [String] = []
    @Published public var selectedOutput = "Not selected"
    @Published public var djResponseText = ""
    @Published public var logLevel = "info"
    @Published public var language = "nl"
    @Published public var voiceEnabled = true
    @Published public var localResponseAudioEnabled = true

    public var volume: Double {
        get { Double(playback?.volumePercent ?? 0) }
        set {
            var updated = playback ?? DJConnectPlayback()
            updated.volumePercent = Int(newValue.rounded())
            playback = updated
        }
    }

    public var isPlaying: Bool {
        playback?.isPlaying ?? false
    }

    public init(playback: DJConnectPlayback? = nil) {
        self.playback = playback
    }

    public func apply(playback: DJConnectPlayback?) {
        self.playback = playback
        selectedOutput = playback?.device?.name ?? selectedOutput
        backendAvailable = true
        updateRequiredMessage = nil
    }

    public func apply(error: DJConnectError) {
        switch error {
        case let .backendUnavailable(message):
            backendAvailable = false
            djResponseText = message ?? "Playback backend unavailable"
        case let .versionMismatch(mismatch):
            updateRequiredMessage = mismatch.message ?? "DJConnect update required"
        case .authStale:
            pairingStatus = .stale
        case .routeMissing:
            pairingStatus = .stale
        default:
            break
        }
    }
}

public extension DJConnectAppModel {
    static var preview: DJConnectAppModel {
        DJConnectAppModel(
            playback: DJConnectPlayback(
                hasPlayback: true,
                isPlaying: true,
                trackName: "Late Night Connection",
                artistName: "DJConnect",
                progressMS: 72_000,
                durationMS: 184_000,
                volumePercent: 35,
                shuffle: false,
                repeatState: .off,
                device: DJConnectPlaybackDevice(
                    name: "Living Room",
                    type: "Speaker",
                    active: true,
                    supportsVolume: true,
                    volumePercent: 35
                )
            )
        )
    }
}
