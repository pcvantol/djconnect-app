import Combine
import DJConnectCore
import Foundation

@MainActor
public final class DJConnectAppModel: ObservableObject {
    @Published public var homeAssistantURL = "" {
        didSet { defaults.set(homeAssistantURL, forKey: homeAssistantURLKey) }
    }
    @Published public var pairingToken = ""
    @Published public var pairingStatus: DJConnectPairingStatus = .unpaired
    @Published public var isConnected = false
    @Published public var isPairing = false
    @Published public var backendAvailable = true
    @Published public var updateRequiredMessage: String?
    @Published public var pairingMessage: String?
    @Published public var playback: DJConnectPlayback?
    @Published public var queue: [String] = []
    @Published public var playlists: [String] = []
    @Published public var selectedOutput = "Not selected"
    @Published public var djResponseText = ""
    @Published public var logLevel = "info"
    @Published public var language = "nl"
    @Published public var voiceEnabled = true
    @Published public var localResponseAudioEnabled = true

    public let identity: DJConnectIdentity

    private let defaults: UserDefaults
    private let tokenStore: DJConnectTokenStore
    private let appVersion = "3.0.0"
    private let installIDKey = "DJConnectInstallID"
    private let homeAssistantURLKey = "DJConnectHomeAssistantURL"

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

    public init(
        playback: DJConnectPlayback? = nil,
        defaults: UserDefaults = .standard,
        tokenStore: DJConnectTokenStore? = nil
    ) {
        self.defaults = defaults
        let resolvedTokenStore = tokenStore ?? DJConnectKeychainTokenStore(service: Self.keychainService)
        self.tokenStore = resolvedTokenStore
        self.identity = Self.makeIdentity(defaults: defaults)
        self.playback = playback
        self.homeAssistantURL = defaults.string(forKey: homeAssistantURLKey) ?? ""
        if let existingToken = try? resolvedTokenStore.loadToken(), !existingToken.isEmpty {
            pairingStatus = .paired
            isConnected = true
        }
    }

    public func pair() async {
        let trimmedURL = homeAssistantURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPairingToken = pairingToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let baseURL = URL(string: trimmedURL), baseURL.scheme?.isEmpty == false else {
            pairingMessage = "Enter a valid Home Assistant URL."
            pairingStatus = .unpaired
            isConnected = false
            return
        }

        guard !trimmedPairingToken.isEmpty else {
            pairingMessage = "Enter the DJConnect pairing token from Home Assistant."
            pairingStatus = .unpaired
            isConnected = false
            return
        }

        isPairing = true
        pairingStatus = .pairing
        pairingMessage = "Pairing with Home Assistant..."
        defer { isPairing = false }

        do {
            let client = DJConnectClient(baseURL: baseURL, identity: identity, tokenStore: tokenStore)
            _ = try await client.pair(DJConnectPairingPayload(identity: identity, pairingToken: trimmedPairingToken))
            pairingToken = ""
            pairingStatus = .paired
            isConnected = true
            pairingMessage = "Paired with Home Assistant."
            try await refreshStatus(client: client)
        } catch let error as DJConnectError {
            apply(error: error)
            isConnected = false
            if case let .pairingFailed(message) = error {
                pairingMessage = message ?? "Pairing failed."
            } else if case let .network(message) = error {
                pairingMessage = message
            } else {
                pairingMessage = "Pairing failed."
            }
        } catch {
            pairingStatus = .unpaired
            isConnected = false
            pairingMessage = error.localizedDescription
        }
    }

    public func resetPairing() {
        try? tokenStore.clearToken()
        defaults.removeObject(forKey: installIDKey)
        pairingToken = ""
        pairingStatus = .unpaired
        isConnected = false
        pairingMessage = "Pairing reset."
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

    private func refreshStatus(client: DJConnectClient) async throws {
        do {
            let response = try await client.postStatus(
                DJConnectStatusPayload(
                    identity: identity,
                    haPairingStatus: .paired,
                    language: language,
                    logLevel: logLevel,
                    localAudioSupported: true,
                    voiceSupported: voiceEnabled
                )
            )
            apply(playback: response.playback)
            backendAvailable = response.backendAvailable ?? backendAvailable
        } catch let error as DJConnectError {
            apply(error: error)
            if case .backendUnavailable = error {
                pairingStatus = .paired
                isConnected = true
            } else {
                throw error
            }
        }
    }

    private static var keychainService: String {
        Bundle.main.bundleIdentifier.map { "\($0).djconnect" } ?? "nl.pcvantol.djconnect.djconnect"
    }

    private static func makeIdentity(defaults: UserDefaults) -> DJConnectIdentity {
        let installIDKey = "DJConnectInstallID"
        let installID: String
        if let existing = defaults.string(forKey: installIDKey), !existing.isEmpty {
            installID = existing
        } else {
            installID = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            defaults.set(installID, forKey: installIDKey)
        }

        #if os(macOS)
        return DJConnectIdentity(
            deviceID: "djconnect-macos-\(installID.prefix(12))",
            deviceName: "DJConnect Mac",
            clientType: .macos,
            firmware: "3.0.0",
            appVersion: "3.0.0",
            platform: .macos
        )
        #else
        return DJConnectIdentity(
            deviceID: "djconnect-ios-\(installID.prefix(12))",
            deviceName: "DJConnect iPhone",
            clientType: .ios,
            firmware: "3.0.0",
            appVersion: "3.0.0",
            platform: .ios
        )
        #endif
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
