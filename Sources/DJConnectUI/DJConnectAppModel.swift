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
    @Published public var logLevel = "info" {
        didSet { defaults.set(logLevel, forKey: logLevelKey) }
    }
    @Published public var language = "nl" {
        didSet { defaults.set(language, forKey: languageKey) }
    }
    @Published public var voiceEnabled = true
    @Published public var localResponseAudioEnabled = true

    public let identity: DJConnectIdentity

    private var pairingTask: Task<Void, Never>?
    private var scheduledPairingTask: Task<Void, Never>?
    private var volumeCommandTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private let tokenStore: DJConnectTokenStore
    private let appVersion = "3.0.0"
    private let installIDKey = "DJConnectInstallID"
    private let homeAssistantURLKey = "DJConnectHomeAssistantURL"
    private let pairingTokenKey = "DJConnectPairingToken"
    private let languageKey = "DJConnectLanguage"
    private let logLevelKey = "DJConnectLogLevel"

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
        self.language = defaults.string(forKey: languageKey) ?? "nl"
        self.logLevel = defaults.string(forKey: logLevelKey) ?? "info"
        defaults.set(pairingToken, forKey: pairingTokenKey)
        if let existingToken = try? resolvedTokenStore.loadToken(), !existingToken.isEmpty {
            pairingStatus = .paired
            isConnected = true
        }
    }

    deinit {
        scheduledPairingTask?.cancel()
        pairingTask?.cancel()
        volumeCommandTask?.cancel()
    }

    public func schedulePairingWait() {
        guard pairingStatus != .paired else {
            return
        }

        scheduledPairingTask?.cancel()
        scheduledPairingTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else {
                return
            }
            self?.startPairingWait()
        }
    }

    public func startPairingWait() {
        guard pairingStatus != .paired else {
            return
        }

        scheduledPairingTask?.cancel()
        scheduledPairingTask = nil
        pairingTask?.cancel()

        guard let baseURL = Self.normalizedHomeAssistantURL(from: homeAssistantURL) else {
            pairingMessage = localized(
                english: "Enter your Home Assistant URL, for example 192.168.1.10:8123.",
                dutch: "Vul je Home Assistant URL in, bijvoorbeeld 192.168.1.10:8123."
            )
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
        scheduledPairingTask?.cancel()
        scheduledPairingTask = nil
        pairingTask?.cancel()
        pairingTask = nil
        if pairingStatus == .pairing {
            pairingStatus = .unpaired
            isPairing = false
            pairingMessage = localized(
                english: "Pairing wait stopped.",
                dutch: "Wachten op pairing gestopt."
            )
        }
    }

    private func waitForHomeAssistantPairing(baseURL: URL, pairingToken: String) async {
        isPairing = true
        pairingStatus = .pairing
        pairingMessage = localized(
            english: "Waiting for Home Assistant to accept code \(pairingToken).",
            dutch: "Wachten tot Home Assistant code \(pairingToken) accepteert."
        )
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
                pairingMessage = localized(
                    english: "Paired with Home Assistant.",
                    dutch: "Gekoppeld met Home Assistant."
                )
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
        pairingMessage = localized(
            english: "Pairing reset.",
            dutch: "Pairing gereset."
        )
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

    public func refresh() {
        Task {
            do {
                try await refreshStatus(client: try makeClient())
            } catch let error as DJConnectError {
                apply(error: error)
            } catch {
                pairingMessage = error.localizedDescription
            }
        }
    }

    public func sendPlaybackCommand(
        _ command: String,
        value: DJConnectCommandValue? = nil,
        play: Bool? = nil
    ) {
        guard updateRequiredMessage == nil else {
            return
        }
        Task {
            await performCommand(command, value: value, play: play)
        }
    }

    public func togglePlayback() {
        sendPlaybackCommand(isPlaying ? "pause" : "play")
    }

    public func commitVolumeChange() {
        volumeCommandTask?.cancel()
        let value = Int(volume.rounded())
        volumeCommandTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else {
                return
            }
            await self?.performCommand("set_volume", value: .int(value))
        }
    }

    public func setShuffle(_ value: Bool) {
        sendPlaybackCommand("set_shuffle", value: .bool(value))
    }

    public func setRepeat(_ value: DJConnectRepeatState) {
        sendPlaybackCommand("set_repeat", value: .string(value.rawValue))
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
            djResponseText = message ?? localized(
                english: "Playback backend unavailable",
                dutch: "Playback-backend niet beschikbaar"
            )
        case let .versionMismatch(mismatch):
            updateRequiredMessage = mismatch.message ?? localized(
                english: "DJConnect update required",
                dutch: "DJConnect update vereist"
            )
        case let .authStale(_, message):
            pairingStatus = .stale
            isConnected = false
            pairingMessage = message ?? localized(
                english: "Pairing is stale. Open Home Assistant setup or reset pairing.",
                dutch: "Pairing is verlopen. Open Home Assistant setup of reset pairing."
            )
        case let .routeMissing(message):
            pairingStatus = .stale
            isConnected = false
            pairingMessage = message ?? localized(
                english: "DJConnect route missing in Home Assistant. Check the integration setup.",
                dutch: "DJConnect route ontbreekt in Home Assistant. Controleer de integratie."
            )
        case let .notConfigured(message):
            pairingStatus = .stale
            isConnected = false
            pairingMessage = message ?? localized(
                english: "DJConnect is not configured in Home Assistant.",
                dutch: "DJConnect is niet geconfigureerd in Home Assistant."
            )
        case .missingToken:
            pairingStatus = .stale
            isConnected = false
            pairingMessage = localized(
                english: "Missing DJConnect device token. Reset pairing to set up again.",
                dutch: "DJConnect device-token ontbreekt. Reset pairing om opnieuw te koppelen."
            )
        default:
            break
        }
    }

    private func applyPairingWait(error: DJConnectError, pairingToken: String) {
        isConnected = false

        switch error {
        case .pairingFailed:
            pairingStatus = .pairing
            pairingMessage = localized(
                english: "Waiting for Home Assistant to accept code \(pairingToken).",
                dutch: "Wachten tot Home Assistant code \(pairingToken) accepteert."
            )
        case let .network(message):
            pairingStatus = .pairing
            pairingMessage = localized(
                english: "Waiting for Home Assistant: \(message)",
                dutch: "Wachten op Home Assistant: \(message)"
            )
        case .routeMissing:
            pairingStatus = .pairing
            pairingMessage = localized(
                english: "Waiting for the DJConnect pairing route in Home Assistant.",
                dutch: "Wachten op de DJConnect pairing-route in Home Assistant."
            )
        case let .server(_, message):
            pairingStatus = .pairing
            pairingMessage = message ?? localized(
                english: "Waiting for Home Assistant to finish pairing.",
                dutch: "Wachten tot Home Assistant pairing afrondt."
            )
        case let .versionMismatch(mismatch):
            pairingStatus = .pairing
            updateRequiredMessage = mismatch.message ?? localized(
                english: "DJConnect update required",
                dutch: "DJConnect update vereist"
            )
        default:
            pairingStatus = .pairing
            pairingMessage = localized(
                english: "Waiting for Home Assistant to finish pairing.",
                dutch: "Wachten tot Home Assistant pairing afrondt."
            )
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

    private func performCommand(
        _ command: String,
        value: DJConnectCommandValue? = nil,
        play: Bool? = nil
    ) async {
        guard updateRequiredMessage == nil else {
            return
        }
        do {
            let client = try makeClient()
            let response = try await client.sendCommand(
                DJConnectCommandPayload(
                    identity: identity,
                    command: command,
                    value: value,
                    play: play
                )
            )
            apply(playback: response.playback)
            backendAvailable = response.backendAvailable ?? backendAvailable
        } catch let error as DJConnectError {
            apply(error: error)
        } catch {
            pairingMessage = error.localizedDescription
        }
    }

    private func makeClient() throws -> DJConnectClient {
        guard let baseURL = Self.normalizedHomeAssistantURL(from: homeAssistantURL) else {
            throw DJConnectError.network(message: localized(
                english: "Enter your Home Assistant URL, for example 192.168.1.10:8123.",
                dutch: "Vul je Home Assistant URL in, bijvoorbeeld 192.168.1.10:8123."
            ))
        }
        return DJConnectClient(baseURL: baseURL, identity: identity, tokenStore: tokenStore)
    }

    public func localized(english: String, dutch: String) -> String {
        language == "nl" ? dutch : english
    }

    public static func normalizedHomeAssistantURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let candidate = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard
            let url = URL(string: candidate),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host?.isEmpty == false
        else {
            return nil
        }

        return url
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
