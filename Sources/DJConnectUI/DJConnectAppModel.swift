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

    private var pairingTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private let tokenStore: DJConnectTokenStore
    private let appVersion = "3.0.0"
    private let installIDKey = "DJConnectInstallID"
    private let homeAssistantURLKey = "DJConnectHomeAssistantURL"
    private let pairingTokenKey = "DJConnectPairingToken"

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
        self.pairingToken = defaults.string(forKey: pairingTokenKey) ?? Self.generatePairingToken()
        defaults.set(pairingToken, forKey: pairingTokenKey)
        if let existingToken = try? resolvedTokenStore.loadToken(), !existingToken.isEmpty {
            pairingStatus = .paired
            isConnected = true
        }
    }

    deinit {
        pairingTask?.cancel()
    }

    public func startPairingWait() {
        guard pairingStatus != .paired else {
            return
        }

        pairingTask?.cancel()

        let trimmedURL = homeAssistantURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = URL(string: trimmedURL), baseURL.scheme?.isEmpty == false else {
            pairingMessage = "Enter your Home Assistant URL to start waiting."
            pairingStatus = .unpaired
            isConnected = false
            isPairing = false
            return
        }

        let trimmedPairingToken = pairingToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let appPairingToken = trimmedPairingToken.isEmpty ? newPairingToken() : trimmedPairingToken

        pairingTask = Task { [weak self] in
            await self?.waitForHomeAssistantPairing(baseURL: baseURL, pairingToken: appPairingToken)
        }
    }

    public func stopPairingWait() {
        pairingTask?.cancel()
        pairingTask = nil
        if pairingStatus == .pairing {
            pairingStatus = .unpaired
            isPairing = false
            pairingMessage = "Pairing wait stopped."
        }
    }

    private func waitForHomeAssistantPairing(baseURL: URL, pairingToken: String) async {
        isPairing = true
        pairingStatus = .pairing
        pairingMessage = "Waiting for Home Assistant to accept code \(pairingToken)."
        defer {
            if pairingStatus != .paired {
                isPairing = false
            }
        }

        while !Task.isCancelled && pairingStatus != .paired {
            let client = DJConnectClient(baseURL: baseURL, identity: identity, tokenStore: tokenStore)
            do {
                _ = try await client.pair(DJConnectPairingPayload(identity: identity, pairingToken: pairingToken))
                pairingStatus = .paired
                isConnected = true
                isPairing = false
                pairingMessage = "Paired with Home Assistant."
                try await refreshStatus(client: client)
                return
            } catch let error as DJConnectError {
                applyPairingWait(error: error, pairingToken: pairingToken)
            } catch {
                isConnected = false
                pairingMessage = error.localizedDescription
            }

            try? await Task.sleep(for: .seconds(2))
        }
    }

    public func resetPairing() {
        pairingTask?.cancel()
        pairingTask = nil
        try? tokenStore.clearToken()
        defaults.removeObject(forKey: installIDKey)
        _ = newPairingToken()
        pairingStatus = .unpaired
        isConnected = false
        pairingMessage = "Pairing reset."
    }

    @discardableResult
    public func newPairingToken() -> String {
        let token = Self.generatePairingToken()
        pairingToken = token
        defaults.set(token, forKey: pairingTokenKey)
        return token
    }

    public func rotatePairingTokenAndWait() {
        guard pairingStatus != .paired else {
            return
        }
        _ = newPairingToken()
        startPairingWait()
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

    private func applyPairingWait(error: DJConnectError, pairingToken: String) {
        isConnected = false

        switch error {
        case .pairingFailed:
            pairingStatus = .pairing
            pairingMessage = "Waiting for Home Assistant to accept code \(pairingToken)."
        case let .network(message):
            pairingStatus = .pairing
            pairingMessage = "Waiting for Home Assistant: \(message)"
        case .routeMissing:
            pairingStatus = .pairing
            pairingMessage = "Waiting for the DJConnect pairing route in Home Assistant."
        case let .server(_, message):
            pairingStatus = .pairing
            pairingMessage = message ?? "Waiting for Home Assistant to finish pairing."
        case let .versionMismatch(mismatch):
            pairingStatus = .pairing
            updateRequiredMessage = mismatch.message ?? "DJConnect update required"
        default:
            pairingStatus = .pairing
            pairingMessage = "Waiting for Home Assistant to finish pairing."
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

    private static func generatePairingToken() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
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
