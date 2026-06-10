import Combine
import DJConnectCore
import Foundation
import OSLog

#if canImport(AVFoundation)
import AVFoundation
#endif

public enum DJConnectAppLogLevel: String, CaseIterable, Sendable {
    case debug
    case info
    case warning
    case error

    var priority: Int {
        switch self {
        case .debug:
            0
        case .info:
            1
        case .warning:
            2
        case .error:
            3
        }
    }

    static func parse(_ rawValue: String) -> DJConnectAppLogLevel {
        DJConnectAppLogLevel(rawValue: rawValue.lowercased()) ?? .info
    }
}

public struct DJConnectDiagnosticLogLine: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String

    public init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

@MainActor
public final class DJConnectAppModel: ObservableObject {
    @Published public var homeAssistantURL = "" {
        didSet { defaults.set(homeAssistantURL, forKey: homeAssistantURLKey) }
    }
    @Published public private(set) var haLocalURL = ""
    @Published public private(set) var assistPipelineID = ""
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
    @Published public var availableOutputs: [DJConnectOutputDevice] = []
    @Published public var queueItems: [DJConnectQueueItem] = []
    @Published public var playlistItems: [DJConnectPlaylist] = []
    @Published public var selectedOutput = "Not selected"
    @Published public var djResponseText = ""
    @Published public var isRecordingVoice = false
    @Published public var voiceErrorMessage: String?
    @Published public var logLevel = "info" {
        didSet {
            defaults.set(logLevel, forKey: logLevelKey)
            log(.info, "Log level changed to \(logLevel)")
        }
    }
    @Published public var language = "nl" {
        didSet { defaults.set(language, forKey: languageKey) }
    }
    @Published public var voiceEnabled = true
    @Published public var localResponseAudioEnabled = true
    @Published public private(set) var localDeviceAPIURL: String?
    @Published public private(set) var diagnosticLogLines: [DJConnectDiagnosticLogLine] = []

    @Published public private(set) var identity: DJConnectIdentity

    private let logger: Logger
    private var pairingTask: Task<Void, Never>?
    private var scheduledPairingTask: Task<Void, Never>?
    private var volumeCommandTask: Task<Void, Never>?
    private var localDeviceAPI: DJConnectLocalDeviceAPI?
    #if canImport(AVFoundation)
    private var voiceRecorder: AVAudioRecorder?
    private var voiceRecordingURL: URL?
    #endif
    private let defaults: UserDefaults
    private let tokenStore: DJConnectTokenStore
    private static let protocolVersion = "3.1.3"
    private let appVersion = DJConnectAppModel.protocolVersion
    private let installIDKey = "DJConnectInstallID"
    private let homeAssistantURLKey = "DJConnectHomeAssistantURL"
    private let haLocalURLKey = "DJConnectHALocalURL"
    private let assistPipelineIDKey = "DJConnectAssistPipelineID"
    private let pairingTokenKey = "DJConnectPairingToken"
    private let languageKey = "DJConnectLanguage"
    private let logLevelKey = "DJConnectLogLevel"
    private let maxDiagnosticLogLines = 120

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
        self.logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "nl.pcvantol.djconnect",
            category: "DJConnectApp"
        )
        self.playback = playback
        self.homeAssistantURL = defaults.string(forKey: homeAssistantURLKey) ?? ""
        self.haLocalURL = defaults.string(forKey: haLocalURLKey) ?? ""
        self.assistPipelineID = defaults.string(forKey: assistPipelineIDKey) ?? ""
        self.pairingToken = defaults.string(forKey: pairingTokenKey) ?? Self.generatePairingToken()
        self.language = defaults.string(forKey: languageKey) ?? "nl"
        self.logLevel = defaults.string(forKey: logLevelKey) ?? "info"
        defaults.set(pairingToken, forKey: pairingTokenKey)
        if let existingToken = try? resolvedTokenStore.loadToken(), !existingToken.isEmpty {
            pairingStatus = .paired
            isConnected = true
            log(.info, "App started with existing DJConnect bearer token for \(identity.clientType.rawValue)")
        } else {
            log(.info, "App started without DJConnect bearer token for \(identity.clientType.rawValue)")
        }
        startLocalDeviceAPI()
    }

    deinit {
        scheduledPairingTask?.cancel()
        pairingTask?.cancel()
        volumeCommandTask?.cancel()
        localDeviceAPI?.stop()
    }

    public func schedulePairingWait() {
        guard pairingStatus != .paired else {
            log(.debug, "Ignoring scheduled pairing because device is already paired")
            return
        }

        log(.debug, "Scheduling pairing retry after URL edit")
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
            log(.debug, "Ignoring pairing wait because device is already paired")
            return
        }

        scheduledPairingTask?.cancel()
        scheduledPairingTask = nil
        pairingTask?.cancel()

        guard let baseURL = Self.normalizedHomeAssistantURL(from: homeAssistantURL) else {
            log(.warning, "Pairing wait cannot start because the Home Assistant URL is invalid")
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

        log(.info, "Starting pairing wait against \(Self.redactedURL(baseURL))")
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
            log(.info, "Pairing wait stopped")
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
        log(.info, "Polling Home Assistant pairing endpoint")
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
                let response = try await client.pair(DJConnectPairingPayload(
                    identity: identity,
                    pairingToken: pairingToken,
                    haLocalURL: Self.normalizedHomeAssistantURL(from: homeAssistantURL).map(Self.redactedURL)
                ))
                apply(pairingResponse: response, fallbackBaseURL: baseURL)
                log(.info, "Pairing accepted by Home Assistant")
                pairingStatus = .paired
                isConnected = true
                isPairing = false
                restartLocalDeviceAPI()
                pairingMessage = localized(
                    english: "Paired with Home Assistant.",
                    dutch: "Gekoppeld met Home Assistant."
                )
                try await refreshStatus(client: client)
                return
            } catch let error as DJConnectError {
                logPairingError(error)
                applyPairingWait(error: error, pairingToken: pairingToken)
                if isTerminalPairingError(error) {
                    log(.error, "Pairing stopped because Home Assistant rejected the current app code")
                    return
                }
            } catch {
                log(.error, "Unexpected pairing error: \(error.localizedDescription)")
                isConnected = false
                pairingMessage = error.localizedDescription
            }

            try? await Task.sleep(for: .seconds(2))
        }
    }

    public func resetPairing() {
        log(.warning, "Resetting pairing and clearing local token")
        scheduledPairingTask?.cancel()
        scheduledPairingTask = nil
        pairingTask?.cancel()
        pairingTask = nil
        try? tokenStore.clearToken()
        clearStoredHomeAssistantURLs()
        defaults.removeObject(forKey: installIDKey)
        identity = Self.makeIdentity(defaults: defaults)
        _ = newPairingToken()
        restartLocalDeviceAPI()
        pairingStatus = .unpaired
        isConnected = false
        isPairing = false
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
        log(.info, "Generated a new pairing code")
        return token
    }

    public func rotatePairingTokenAndWait() {
        guard pairingStatus != .paired else {
            return
        }
        _ = newPairingToken()
        pairingStatus = .unpaired
        pairingMessage = localized(
            english: "Enter the new app code in Home Assistant.",
            dutch: "Vul de nieuwe app-code in Home Assistant in."
        )
        startPairingWait()
    }

    public func refresh() {
        log(.debug, "Manual refresh requested")
        Task {
            do {
                try await refreshStatusWithFallback()
                await refreshBackendCollections()
            } catch let error as DJConnectError {
                log(.warning, "Refresh failed: \(Self.describe(error))")
                apply(error: error)
            } catch {
                log(.error, "Refresh failed unexpectedly: \(error.localizedDescription)")
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
            log(.warning, "Command \(command) blocked because an app/integration update is required")
            return
        }
        log(.info, "Sending playback command: \(command)")
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

    public func loadOutputs() {
        log(.info, "Loading playback outputs")
        Task {
            await performCommand("devices")
        }
    }

    public func loadQueue() {
        log(.info, "Loading queue")
        Task {
            await performCommand("queue")
        }
    }

    public func loadPlaylists() {
        log(.info, "Loading playlists")
        Task {
            await performCommand("playlists")
        }
    }

    public func selectOutput(_ output: DJConnectOutputDevice) {
        selectedOutput = output.name
        log(.info, "Selecting output \(output.name)")
        sendPlaybackCommand("set_output", value: .string(output.name), play: true)
    }

    public func startPlaylist(_ playlist: DJConnectPlaylist) {
        log(.info, "Starting playlist \(playlist.name)")
        sendPlaybackCommand("start_playlist", value: .string(playlist.commandValue), play: true)
    }

    public func startLikedProxy() {
        log(.info, "Starting liked proxy flow")
        sendPlaybackCommand("start_liked_proxy", play: true)
    }

    public func toggleVoiceRecording() {
        isRecordingVoice ? stopVoiceRecordingAndUpload() : startVoiceRecording()
    }

    public func startVoiceRecording() {
        guard voiceEnabled else {
            log(.warning, "Voice recording ignored because voice is disabled")
            return
        }
        guard pairingStatus == .paired else {
            voiceErrorMessage = localized(
                english: "Pair with Home Assistant before using voice.",
                dutch: "Koppel eerst met Home Assistant voordat je voice gebruikt."
            )
            log(.warning, "Voice recording ignored because app is not paired")
            return
        }

        Task {
            let granted = await requestMicrophoneAccess()
            guard granted else {
                voiceErrorMessage = localized(
                    english: "Microphone access is required for push-to-talk.",
                    dutch: "Microfoontoegang is nodig voor push-to-talk."
                )
                log(.warning, "Microphone permission was not granted")
                return
            }
            beginVoiceRecording()
        }
    }

    public func stopVoiceRecordingAndUpload() {
        guard isRecordingVoice else {
            return
        }

        #if canImport(AVFoundation)
        let url = voiceRecordingURL
        voiceRecorder?.stop()
        voiceRecorder = nil
        voiceRecordingURL = nil
        isRecordingVoice = false
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif

        guard let url else {
            log(.warning, "Voice upload skipped because recording URL is missing")
            return
        }

        Task {
            do {
                let data = try Data(contentsOf: url)
                try? FileManager.default.removeItem(at: url)
                log(.info, "Uploading voice recording WAV (\(data.count) bytes)")
                let response = try await sendVoiceWithFallback(wavData: data)
                djResponseText = response.djText ?? response.text ?? localized(
                    english: "Voice request completed.",
                    dutch: "Voice-request afgerond."
                )
                voiceErrorMessage = nil
                log(.info, "Voice request completed")
            } catch let error as DJConnectError {
                voiceErrorMessage = Self.describe(error)
                log(.warning, "Voice upload failed: \(Self.describe(error))")
                apply(error: error)
            } catch {
                voiceErrorMessage = error.localizedDescription
                log(.error, "Voice upload failed unexpectedly: \(error.localizedDescription)")
            }
        }
        #else
        isRecordingVoice = false
        voiceErrorMessage = localized(
            english: "Voice recording is not available on this platform.",
            dutch: "Voice-opname is niet beschikbaar op dit platform."
        )
        #endif
    }

    public func apply(playback: DJConnectPlayback?) {
        self.playback = playback
        selectedOutput = playback?.device?.name ?? selectedOutput
        backendAvailable = true
        updateRequiredMessage = nil
        if let playback {
            let playing = playback.isPlaying.map(String.init) ?? "unknown"
            let volume = playback.volumePercent.map(String.init) ?? "unknown"
            log(.debug, "Applied playback snapshot: playing=\(playing), volume=\(volume)")
        } else {
            log(.debug, "Applied empty playback snapshot")
        }
    }

    public func apply(commandResponse response: DJConnectCommandResponse) {
        if let playback = response.playback {
            apply(playback: playback)
        }
        backendAvailable = response.backendAvailable ?? backendAvailable
        if let devices = response.devices {
            availableOutputs = devices
            if let active = devices.first(where: { $0.active == true }) {
                selectedOutput = active.name
            } else if selectedOutput == "Not selected", let first = devices.first {
                selectedOutput = first.name
            }
        }
        if let responseQueue = response.queue {
            queueItems = responseQueue
            queue = responseQueue.map(\.displayTitle)
        }
        if let responsePlaylists = response.playlists {
            playlistItems = responsePlaylists
            playlists = responsePlaylists.map(\.name)
        }
        if let message = response.message, !message.isEmpty {
            djResponseText = message
        }
    }

    public func apply(pairingResponse response: DJConnectPairingResponse, fallbackBaseURL: URL) {
        let localURL = response.haLocalURL.flatMap(Self.normalizedHomeAssistantURL(from:))
            ?? Self.normalizedHomeAssistantURL(from: homeAssistantURL)
            ?? fallbackBaseURL
        haLocalURL = Self.redactedURL(localURL)
        homeAssistantURL = haLocalURL
        defaults.set(haLocalURL, forKey: haLocalURLKey)
        defaults.removeObject(forKey: "DJConnectHARemoteURL")
        defaults.removeObject(forKey: "DJConnectHAActiveURL")
        if let pipelineID = response.assistPipelineID, !pipelineID.isEmpty {
            assistPipelineID = pipelineID
            defaults.set(pipelineID, forKey: assistPipelineIDKey)
        }
        if let responseLanguage = response.deviceLanguage ?? response.language, !responseLanguage.isEmpty {
            language = responseLanguage
        }
    }

    public func apply(localDJResponse response: DJConnectLocalDJResponseRequest) {
        if let text = response.djText ?? response.text, !text.isEmpty {
            djResponseText = text
        }
        if let audioURL = response.audioURL, !audioURL.isEmpty {
            log(.info, "Received DJ response audio URL from Home Assistant")
        }
    }

    public func apply(error: DJConnectError) {
        log(.warning, "Applying app error state: \(Self.describe(error))")
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
                english: "Missing DJConnect bearer token. Reset pairing to set up again.",
                dutch: "DJConnect bearer-token ontbreekt. Reset pairing om opnieuw te koppelen."
            )
        default:
            break
        }
    }

    func applyPairingWait(error: DJConnectError, pairingToken: String) {
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
        case let .authStale(_, message):
            pairingStatus = .stale
            isPairing = false
            pairingMessage = localized(
                english: message.map { "\($0) Enter the app code shown here again in Home Assistant." }
                    ?? "Home Assistant rejected this app code. Enter the code shown here again in Home Assistant.",
                dutch: message.map { "\($0) Vul de app-code die hier staat opnieuw in Home Assistant in." }
                    ?? "Home Assistant weigert deze app-code. Vul de code die hier staat opnieuw in Home Assistant in."
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

    func isTerminalPairingError(_ error: DJConnectError) -> Bool {
        if case .authStale = error {
            return true
        }
        return false
    }

    private func refreshStatus(client: DJConnectClient) async throws {
        do {
            log(.debug, "Posting status to Home Assistant")
            let response = try await client.postStatus(
                DJConnectStatusPayload(
                    identity: identity,
                    haPairingStatus: .paired,
                    language: language,
                    logLevel: logLevel,
                    localAudioSupported: true,
                    voiceSupported: voiceEnabled,
                    haLocalURL: haLocalURL.isEmpty ? nil : haLocalURL,
                    localURL: localDeviceAPIURL
                )
            )
            apply(playback: response.playback)
            backendAvailable = response.backendAvailable ?? backendAvailable
            log(.debug, "Status refresh succeeded")
        } catch let error as DJConnectError {
            log(.warning, "Status refresh failed: \(Self.describe(error))")
            apply(error: error)
            if case .backendUnavailable = error {
                pairingStatus = .paired
                isConnected = true
            } else {
                throw error
            }
        }
    }

    private func refreshBackendCollections() async {
        await performCommand("devices")
        await performCommand("queue")
        await performCommand("playlists")
    }

    private func refreshStatusWithFallback() async throws {
        try await refreshStatus(client: try makeClient())
    }

    private func sendVoiceWithFallback(wavData: Data) async throws -> DJConnectVoiceResponse {
        try await makeClient().sendVoice(wavData: wavData)
    }

    private func performCommand(
        _ command: String,
        value: DJConnectCommandValue? = nil,
        play: Bool? = nil
    ) async {
        guard updateRequiredMessage == nil else {
            log(.warning, "Command \(command) skipped because update is required")
            return
        }
        do {
            let client = try makeClient()
            log(.debug, "Posting command \(command) to Home Assistant")
            let response = try await client.sendCommandResponse(
                DJConnectCommandPayload(
                    identity: identity,
                    command: command,
                    value: value,
                    play: play
                )
            )
            apply(commandResponse: response)
            log(.debug, "Command \(command) succeeded")
        } catch let error as DJConnectError {
            log(.warning, "Command \(command) failed: \(Self.describe(error))")
            apply(error: error)
        } catch {
            log(.error, "Command \(command) failed unexpectedly: \(error.localizedDescription)")
            pairingMessage = error.localizedDescription
        }
    }

    private func makeClient() throws -> DJConnectClient {
        guard let baseURL = Self.normalizedHomeAssistantURL(from: localHomeAssistantURL()) else {
            log(.warning, "Cannot create Home Assistant client because URL is invalid")
            throw DJConnectError.network(message: localized(
                english: "Enter your Home Assistant URL, for example 192.168.1.10:8123.",
                dutch: "Vul je Home Assistant URL in, bijvoorbeeld 192.168.1.10:8123."
            ))
        }
        return DJConnectClient(baseURL: baseURL, identity: identity, tokenStore: tokenStore)
    }

    private func startLocalDeviceAPI() {
        localDeviceAPI = DJConnectLocalDeviceAPI(
            infoProvider: { [weak self] in
                if let self {
                    return await self.localDeviceAPIInfo()
                }
                return DJConnectLocalDeviceAPIInfo(
                    identity: DJConnectIdentity(
                        deviceID: "djconnect-macos-unavailable",
                        deviceName: "DJConnect",
                        clientType: .macos,
                        firmware: "3.1.3",
                        appVersion: "3.1.3",
                        platform: .macos
                    ),
                    pairingToken: "",
                    pairingStatus: .unpaired
                )
            },
            tokenProvider: { [weak self] in
                await self?.loadDeviceToken()
            },
            pairHandler: { [weak self] request in
                await self?.handleLocalPair(request) ?? DJConnectLocalDeviceAPIResponse(
                    success: false,
                    error: "unavailable",
                    message: "DJConnect app model is unavailable."
                )
            },
            commandHandler: { [weak self] request in
                await self?.handleLocalCommand(request) ?? DJConnectLocalDeviceAPIResponse(
                    success: false,
                    error: "unavailable",
                    message: "DJConnect app model is unavailable."
                )
            },
            djResponseHandler: { [weak self] request in
                await self?.handleLocalDJResponse(request) ?? DJConnectLocalDeviceAPIResponse(
                    success: false,
                    error: "unavailable",
                    message: "DJConnect app model is unavailable."
                )
            },
            forgetHandler: { [weak self] in
                await self?.handleLocalForget() ?? DJConnectLocalDeviceAPIResponse(
                    success: false,
                    error: "unavailable",
                    message: "DJConnect app model is unavailable."
                )
            },
            urlHandler: { [weak self] url in
                await MainActor.run {
                    self?.localDeviceAPIURL = url
                }
            },
            logHandler: { [weak self] message in
                await MainActor.run {
                    self?.log(.info, message)
                }
            }
        )
        localDeviceAPI?.start()
    }

    private func restartLocalDeviceAPI() {
        localDeviceAPI?.stop()
        localDeviceAPI = nil
        startLocalDeviceAPI()
    }

    private func localDeviceAPIInfo() -> DJConnectLocalDeviceAPIInfo {
        DJConnectLocalDeviceAPIInfo(
            identity: identity,
            pairingToken: pairingToken,
            pairingStatus: pairingStatus,
            localURL: localDeviceAPIURL
        )
    }

    private func loadDeviceToken() -> String? {
        try? tokenStore.loadToken()
    }

    private func handleLocalPair(_ request: DJConnectLocalPairRequest) -> DJConnectLocalDeviceAPIResponse {
        guard request.deviceID == identity.deviceID else {
            log(.warning, "Local pair rejected because device_id \(request.deviceID ?? "missing") does not match \(identity.deviceID)")
            return DJConnectLocalDeviceAPIResponse(success: false, error: "wrong_device_id", message: "Pair request is for a different DJConnect device.")
        }
        guard request.clientType == identity.clientType else {
            log(.warning, "Local pair rejected because client_type \(request.clientType?.rawValue ?? "missing") does not match \(identity.clientType.rawValue)")
            return DJConnectLocalDeviceAPIResponse(success: false, error: "wrong_client_type", message: "Pair request is for a different DJConnect client type.")
        }
        guard request.resolvedPairCode == pairingToken else {
            log(.warning, "Local pair rejected because pair_code does not match the visible app code")
            return DJConnectLocalDeviceAPIResponse(success: false, error: "pair_code_mismatch", message: "Pairing code does not match this app.")
        }
        guard let token = request.resolvedDeviceToken, !token.isEmpty else {
            log(.warning, "Local pair rejected because Home Assistant did not send a device token")
            return DJConnectLocalDeviceAPIResponse(success: false, error: "missing_token", message: "Pair request did not include a device token.")
        }

        do {
            try tokenStore.saveToken(token)
        } catch {
            log(.error, "Local device API failed to store device token: \(error.localizedDescription)")
            return DJConnectLocalDeviceAPIResponse(success: false, error: "token_store_failed", message: "Could not store device token.")
        }

        let fallbackURL = Self.normalizedHomeAssistantURL(from: request.haLocalURL ?? homeAssistantURL)
            ?? URL(string: "http://homeassistant.local:8123")!
        apply(pairingResponse: DJConnectPairingResponse(
            success: true,
            deviceToken: token,
            token: nil,
            bearerToken: nil,
            message: nil,
            deviceID: request.deviceID,
            clientType: request.clientType,
            haLocalURL: request.haLocalURL,
            haRemoteURL: nil,
            deviceLanguage: request.deviceLanguage,
            language: request.language,
            assistPipelineID: request.assistPipelineID
        ), fallbackBaseURL: fallbackURL)
        pairingStatus = .paired
        isConnected = true
        isPairing = false
        restartLocalDeviceAPI()
        pairingMessage = localized(english: "Paired with Home Assistant.", dutch: "Gekoppeld met Home Assistant.")
        log(.info, "Local device API completed pairing from Home Assistant")
        refresh()
        return DJConnectLocalDeviceAPIResponse(
            success: true,
            message: "paired",
            deviceID: identity.deviceID,
            clientType: identity.clientType.rawValue,
            paired: true
        )
    }

    private func handleLocalCommand(_ request: DJConnectLocalCommandRequest) -> DJConnectLocalDeviceAPIResponse {
        if let language = request.language, !language.isEmpty {
            self.language = language
        }
        if let logLevel = request.logLevel, !logLevel.isEmpty {
            self.logLevel = logLevel
        }
        if let voiceEnabled = request.voiceEnabled {
            self.voiceEnabled = voiceEnabled
        }
        if let localResponseAudioEnabled = request.localResponseAudioEnabled {
            self.localResponseAudioEnabled = localResponseAudioEnabled
        }

        guard let command = request.command, !command.isEmpty else {
            return DJConnectLocalDeviceAPIResponse(success: true, message: "settings_applied")
        }

        switch command {
        case "status":
            refresh()
        case "set_language":
            if case let .string(value) = request.value {
                language = value
            }
        case "set_log_level":
            if case let .string(value) = request.value {
                logLevel = value
            }
        case "set_voice_enabled":
            if case let .bool(value) = request.value {
                voiceEnabled = value
            }
        case "set_local_response_audio_enabled":
            if case let .bool(value) = request.value {
                localResponseAudioEnabled = value
            }
        case "diagnostics_export":
            return DJConnectLocalDeviceAPIResponse(success: true, message: diagnosticExportText())
        case "play", "pause", "next", "previous", "set_volume", "set_shuffle", "set_repeat", "start_liked_proxy", "start_playlist", "set_output":
            sendPlaybackCommand(command, value: request.value, play: request.play)
        default:
            return DJConnectLocalDeviceAPIResponse(success: false, error: "unsupported_command", message: "Unsupported local app command.")
        }
        log(.info, "Local device API handled command \(command)")
        return DJConnectLocalDeviceAPIResponse(success: true, message: "accepted")
    }

    private func handleLocalDJResponse(_ request: DJConnectLocalDJResponseRequest) -> DJConnectLocalDeviceAPIResponse {
        apply(localDJResponse: request)
        return DJConnectLocalDeviceAPIResponse(success: true, message: "accepted")
    }

    private func handleLocalForget() -> DJConnectLocalDeviceAPIResponse {
        resetPairing()
        return DJConnectLocalDeviceAPIResponse(success: true, message: "forgotten")
    }

    private func localHomeAssistantURL() -> String {
        if !haLocalURL.isEmpty {
            return haLocalURL
        }
        return homeAssistantURL
    }

    private func clearStoredHomeAssistantURLs() {
        haLocalURL = ""
        defaults.removeObject(forKey: haLocalURLKey)
        defaults.removeObject(forKey: "DJConnectHARemoteURL")
        defaults.removeObject(forKey: "DJConnectHAActiveURL")
        assistPipelineID = ""
        defaults.removeObject(forKey: assistPipelineIDKey)
    }

    public func clearDiagnosticLog() {
        diagnosticLogLines.removeAll()
        log(.info, "Diagnostic log cleared")
    }

    public func diagnosticExportText() -> String {
        let tokenState = ((try? tokenStore.loadToken())?.isEmpty == false) ? "present" : "missing"
        let url = Self.normalizedHomeAssistantURL(from: homeAssistantURL)
            .map(Self.redactedURL)
            ?? "invalid"
        let lines = diagnosticLogLines.map { Self.redactSensitive($0.text) }.joined(separator: "\n")
        return """
        DJConnect Diagnostics
        version: \(appVersion)
        client_type: \(identity.clientType.rawValue)
        device_id: \(identity.deviceID)
        pairing_status: \(pairingStatus.rawValue)
        bearer_token: \(tokenState)
        home_assistant_url: \(url)
        ha_local_url: \(haLocalURL.isEmpty ? "missing" : Self.redactSensitive(haLocalURL))
        assist_pipeline_id: \(assistPipelineID.isEmpty ? "missing" : "present")
        local_device_api_url: \(localDeviceAPIURL ?? "missing")
        backend_available: \(backendAvailable)
        selected_output: \(selectedOutput)
        language: \(language)
        log_level: \(logLevel)
        voice_enabled: \(voiceEnabled)
        local_response_audio_enabled: \(localResponseAudioEnabled)

        Logs
        \(lines.isEmpty ? "none" : lines)
        """
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

    private func logPairingError(_ error: DJConnectError) {
        switch error {
        case .pairingFailed:
            log(.debug, "Pairing is still pending in Home Assistant")
        case .network:
            log(.warning, "Pairing network error: \(Self.describe(error))")
        case .routeMissing:
            log(.warning, "Pairing route is missing in Home Assistant")
        case .versionMismatch:
            log(.error, "Pairing blocked by version mismatch: \(Self.describe(error))")
        default:
            log(.warning, "Pairing poll failed: \(Self.describe(error))")
        }
    }

    private func log(_ level: DJConnectAppLogLevel, _ message: String) {
        let configuredLevel = DJConnectAppLogLevel.parse(logLevel)
        guard level.priority >= configuredLevel.priority else {
            return
        }

        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let line = "[\(formatter.string(from: Date()))] \(level.rawValue.uppercased()) \(message)"
        diagnosticLogLines.append(DJConnectDiagnosticLogLine(text: line))
        if diagnosticLogLines.count > maxDiagnosticLogLines {
            diagnosticLogLines.removeFirst(diagnosticLogLines.count - maxDiagnosticLogLines)
        }
    }

    private static func describe(_ error: DJConnectError) -> String {
        switch error {
        case let .backendUnavailable(message):
            "backend unavailable\(message.map { ": \($0)" } ?? "")"
        case let .authStale(statusCode, message):
            "auth stale HTTP \(statusCode)\(message.map { ": \($0)" } ?? "")"
        case let .routeMissing(message):
            "route missing\(message.map { ": \($0)" } ?? "")"
        case let .versionMismatch(mismatch):
            "version mismatch HA \(mismatch.haMajorMinor ?? "?") app \(mismatch.firmwareMajorMinor ?? "?")"
        case let .notConfigured(message):
            "not configured\(message.map { ": \($0)" } ?? "")"
        case let .server(statusCode, message):
            "server HTTP \(statusCode)\(message.map { ": \($0)" } ?? "")"
        case let .network(message):
            "network: \(message)"
        case .invalidResponse:
            "invalid response"
        case let .invalidConfiguration(message):
            "invalid configuration: \(message)"
        case .missingToken:
            "missing DJConnect bearer token"
        case let .pairingFailed(message):
            "pairing pending\(message.map { ": \($0)" } ?? "")"
        }
    }

    private static func redactedURL(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let scheme = components?.scheme {
            components?.scheme = scheme.lowercased()
        }
        components?.user = nil
        components?.password = nil
        components?.query = nil
        components?.fragment = nil
        return components?.string ?? "\(url.scheme ?? "http")://\(url.host ?? "unknown")"
    }

    private static func redactSensitive(_ value: String) -> String {
        value
            .replacingOccurrences(
                of: #"Bearer\s+[A-Za-z0-9._~+/=-]+"#,
                with: "Bearer [redacted]",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b\d{6}\b"#,
                with: "[pair-code]",
                options: .regularExpression
            )
    }

    private func requestMicrophoneAccess() async -> Bool {
        #if canImport(AVFoundation)
        #if os(iOS)
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        #elseif os(macOS)
        return await AVCaptureDevice.requestAccess(for: .audio)
        #else
        return false
        #endif
        #else
        return false
        #endif
    }

    private func beginVoiceRecording() {
        #if canImport(AVFoundation)
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            #endif

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("djconnect-voice-\(UUID().uuidString)")
                .appendingPathExtension("wav")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            recorder.record()
            voiceRecorder = recorder
            voiceRecordingURL = url
            voiceErrorMessage = nil
            isRecordingVoice = true
            log(.info, "Voice recording started")
        } catch {
            isRecordingVoice = false
            voiceErrorMessage = error.localizedDescription
            log(.error, "Voice recording failed: \(error.localizedDescription)")
        }
        #else
        voiceErrorMessage = localized(
            english: "Voice recording is not available on this platform.",
            dutch: "Voice-opname is niet beschikbaar op dit platform."
        )
        #endif
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
            clientName: "DJConnect Mac",
            deviceID: "djconnect-macos-\(installID.prefix(12))",
            deviceName: "DJConnect Mac",
            clientType: .macos,
            firmware: protocolVersion,
            appVersion: protocolVersion,
            platform: .macos
        )
        #else
        return DJConnectIdentity(
            clientName: "DJConnect iPhone",
            deviceID: "djconnect-ios-\(installID.prefix(12))",
            deviceName: "DJConnect iPhone",
            clientType: .ios,
            firmware: protocolVersion,
            appVersion: protocolVersion,
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
