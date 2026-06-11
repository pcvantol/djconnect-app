import Combine
import DJConnectCore
import Foundation
import OSLog

#if DEBUG && canImport(Darwin)
import Darwin
#endif

#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(Speech)
import Speech
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

public enum DJConnectVoiceStatus: Equatable, Sendable {
    case idle
    case listening
    case processing
    case unavailable
}

public enum DJConnectWakeWordStatus: Equatable, Sendable {
    case idle
    case listening
    case detected
    case unavailable
}

public enum DJConnectPermissionStatus: String, Equatable, Sendable {
    case unknown
    case granted
    case denied
    case restricted
    case unavailable
}

@MainActor
public final class DJConnectAppModel: ObservableObject {
    @Published public var homeAssistantURL = "" {
        didSet { defaults.set(homeAssistantURL, forKey: homeAssistantURLKey) }
    }
    @Published public private(set) var haLocalURL = ""
    @Published public private(set) var assistPipelineID = ""
    @Published public var pairingToken = ""
    @Published public var pairingStatus: DJConnectPairingStatus = .unpaired {
        didSet {
            if startBackgroundTasks, oldValue != .paired, pairingStatus == .paired {
                schedulePairedRefresh(reason: "Pairing became online")
            } else if pairingStatus != .paired {
                stopWakeWordListening()
            }
        }
    }
    @Published public var isConnected = false
    @Published public var isPairing = false
    @Published public var isRefreshing = false
    @Published public private(set) var isLoadingOutputs = false
    @Published public private(set) var isLoadingQueue = false
    @Published public private(set) var isLoadingPlaylists = false
    @Published public var backendAvailable = true
    @Published public var updateRequiredMessage: String?
    @Published public var pairingMessage: String?
    @Published public var playback: DJConnectPlayback?
    @Published public var queue: [String] = []
    @Published public var playlists: [String] = []
    @Published public var availableOutputs: [DJConnectOutputDevice] = []
    @Published public var queueItems: [DJConnectQueueItem] = []
    @Published public private(set) var loadingQueueItemID: String?
    @Published public private(set) var loadingQueueItemIndex: Int?
    @Published public var queueContext: String?
    @Published public var playlistItems: [DJConnectPlaylist] = []
    @Published public var selectedOutput = "Not selected"
    @Published public var djResponseText = ""
    @Published public var isRecordingVoice = false
    @Published public var voiceStatus: DJConnectVoiceStatus = .idle
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
    @Published public var isDemoMode = false
    @Published public var wakeWordEnabled = false {
        didSet {
            wakeWordEnabled ? startWakeWordListening() : stopWakeWordListening()
        }
    }
    @Published public var wakeWordPhrase = "Hey DJ" {
        didSet {
            defaults.set(wakeWordPhrase, forKey: wakeWordPhraseKey)
            if wakeWordEnabled, wakeWordStatus == .listening {
                restartWakeWordListening()
            }
        }
    }
    @Published public private(set) var wakeWordStatus: DJConnectWakeWordStatus = .idle
    @Published public private(set) var microphonePermissionStatus: DJConnectPermissionStatus = .unknown
    @Published public private(set) var speechPermissionStatus: DJConnectPermissionStatus = .unknown
    @Published public private(set) var localNetworkPermissionStatus: DJConnectPermissionStatus = .unknown
    @Published public private(set) var isRequestingPermissions = false
    @Published public var isShowingWelcome = false
    @Published public var isShowingCrashReportPrompt = false
    @Published public var isShowingWakeWordActivationPrompt = false
    @Published public var isShowingKeychainAccessRequired = false
    @Published public private(set) var isShowingPairingSuccess = false
    @Published public private(set) var isPairingScreenDismissed = false
    @Published public private(set) var localDeviceAPIURL: String?
    @Published public private(set) var diagnosticLogLines: [DJConnectDiagnosticLogLine] = []

    @Published public private(set) var identity: DJConnectIdentity

    private let logger: Logger
    private var pairingTask: Task<Void, Never>?
    private var scheduledPairingTask: Task<Void, Never>?
    private var volumeCommandTask: Task<Void, Never>?
    private var playbackProgressTask: Task<Void, Never>?
    private var startupRefreshTask: Task<Void, Never>?
    private var pendingSelectedOutput: String?
    private var pendingVolumePercent: Int?
    private var localDeviceAPI: DJConnectLocalDeviceAPI?
    private var shouldShowWakeWordPromptAfterPairingScreen = false
    #if canImport(AVFoundation)
    private var voiceRecorder: AVAudioRecorder?
    private var voiceRecordingURL: URL?
    private var responseAudioPlayer: AVAudioPlayer?
    #endif
    #if canImport(Speech) && canImport(AVFoundation)
    private var wakeAudioEngine: AVAudioEngine?
    private var wakeRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var wakeRecognitionTask: SFSpeechRecognitionTask?
    private var wakeWordRestartTask: Task<Void, Never>?
    private var wakeWordCaptureTask: Task<Void, Never>?
    private var isStoppingWakeWord = false
    #endif
    private let defaults: UserDefaults
    private let tokenStore: DJConnectTokenStore
    private let startBackgroundTasks: Bool
    private static let protocolVersion = "3.1.9"
    private let appVersion = DJConnectAppModel.protocolVersion
    private let installIDKey = "DJConnectInstallID"
    private let homeAssistantURLKey = "DJConnectHomeAssistantURL"
    private let haLocalURLKey = "DJConnectHALocalURL"
    private let assistPipelineIDKey = "DJConnectAssistPipelineID"
    private let pairingTokenKey = "DJConnectPairingToken"
    private let localDeviceAPIURLKey = "DJConnectLocalDeviceAPIURL"
    private let languageKey = "DJConnectLanguage"
    private let logLevelKey = "DJConnectLogLevel"
    private let demoModeKey = "DJConnectDemoMode"
    private let wakeWordPhraseKey = "DJConnectWakeWordPhrase"
    private let wakeWordPromptDismissedKey = "DJConnectWakeWordPromptDismissed"
    private let welcomeSeenKey = "DJConnectWelcomeSeen"
    private let cleanShutdownKey = "DJConnectCleanShutdown"
    private let crashPromptPendingKey = "DJConnectCrashPromptPending"
    private let maxDiagnosticLogLines = 120

    public var volume: Double {
        get { Double(pendingVolumePercent ?? playback?.volumePercent ?? 0) }
        set {
            let value = Int(newValue.rounded())
            pendingVolumePercent = value
            var updated = playback ?? DJConnectPlayback()
            updated.volumePercent = value
            playback = updated
        }
    }

    public var isPlaying: Bool {
        playback?.isPlaying ?? false
    }

    public var version: String {
        appVersion
    }

    public var hasStoredPairingToken: Bool {
        if pairingStatus == .paired || isShowingKeychainAccessRequired {
            return true
        }
        return (try? tokenStore.loadToken())?.isEmpty == false
    }

    public var isRuntimeCompatible: Bool {
        updateRequiredMessage == nil
    }

    public var canUsePlaybackFeatures: Bool {
        isDemoMode || (pairingStatus == .paired && backendAvailable && isRuntimeCompatible)
    }

    public var shouldShowPairingScreen: Bool {
        !isDemoMode
            && !isShowingWelcome
            && !isShowingCrashReportPrompt
            && !isShowingKeychainAccessRequired
            && !isPairingScreenDismissed
            && (pairingStatus != .paired || isShowingPairingSuccess)
    }

    public init(
        playback: DJConnectPlayback? = nil,
        defaults: UserDefaults = .standard,
        tokenStore: DJConnectTokenStore? = nil,
        startLocalAPI: Bool = true,
        startBackgroundTasks: Bool = true
    ) {
        self.defaults = defaults
        self.startBackgroundTasks = startBackgroundTasks
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
        self.localDeviceAPIURL = defaults.string(forKey: localDeviceAPIURLKey)
        self.pairingToken = defaults.string(forKey: pairingTokenKey) ?? Self.generatePairingToken()
        self.language = defaults.string(forKey: languageKey) ?? Self.defaultLanguage()
        self.logLevel = defaults.string(forKey: logLevelKey) ?? "info"
        defaults.removeObject(forKey: demoModeKey)
        self.isDemoMode = false
        self.wakeWordEnabled = false
        self.wakeWordPhrase = defaults.string(forKey: wakeWordPhraseKey) ?? "Hey DJ"
        self.isShowingWelcome = !defaults.bool(forKey: welcomeSeenKey)
        let previousLaunchMayHaveCrashed = defaults.object(forKey: cleanShutdownKey) != nil
            && defaults.bool(forKey: cleanShutdownKey) == false
        self.isShowingCrashReportPrompt = !Self.isRunningUnderDebugger
            && (previousLaunchMayHaveCrashed || defaults.bool(forKey: crashPromptPendingKey))
        defaults.set(false, forKey: cleanShutdownKey)
        defaults.set(isShowingCrashReportPrompt, forKey: crashPromptPendingKey)
        defaults.set(pairingToken, forKey: pairingTokenKey)
        do {
            if let existingToken = try resolvedTokenStore.loadToken(), !existingToken.isEmpty {
                pairingStatus = .paired
                isConnected = true
                log(.info, "App started with existing DJConnect bearer token for \(identity.clientType.rawValue)")
                if startBackgroundTasks {
                    schedulePairedRefresh(reason: "Refreshing initial Home Assistant state")
                }
            } else if isDemoMode {
                applyDemoState()
                log(.info, "App started in demo mode")
            } else {
                log(.info, "App started without DJConnect bearer token for \(identity.clientType.rawValue)")
            }
        } catch {
            applyKeychainAccessFailure(error)
        }
        refreshPermissionStatuses()
        if startLocalAPI {
            startLocalDeviceAPI()
        }
    }

    public func dismissWelcome() {
        defaults.set(true, forKey: welcomeSeenKey)
        isShowingWelcome = false
    }

    public func retryKeychainAccess() {
        do {
            if let existingToken = try tokenStore.loadToken(), !existingToken.isEmpty {
                isShowingKeychainAccessRequired = false
                pairingStatus = .paired
                isConnected = true
                backendAvailable = true
                pairingMessage = localized(
                    english: "Keychain access restored.",
                    dutch: "Sleutelhanger-toegang hersteld."
                )
                log(.info, "Keychain access restored")
                if startBackgroundTasks {
                    schedulePairedRefresh(reason: "Refreshing after Keychain access restore")
                }
            } else {
                isShowingKeychainAccessRequired = false
                pairingStatus = .unpaired
                isConnected = false
                pairingMessage = localized(
                    english: "No DJConnect token found. Pair again to continue.",
                    dutch: "Geen DJConnect-token gevonden. Koppel opnieuw om door te gaan."
                )
                log(.warning, "Keychain access restored but no DJConnect bearer token was found")
            }
        } catch {
            applyKeychainAccessFailure(error)
        }
    }

    private func applyKeychainAccessFailure(_ error: Error) {
        isShowingKeychainAccessRequired = true
        isConnected = false
        pairingStatus = .stale
        backendAvailable = false
        pairingMessage = localized(
            english: "Keychain access is required to read the DJConnect token.",
            dutch: "Sleutelhanger-toegang is nodig om het DJConnect-token te lezen."
        )
        if let keychainError = error as? DJConnectKeychainError, keychainError.requiresUserAction {
            log(.warning, "Keychain access was denied or cancelled")
        } else {
            log(.error, "Keychain access failed: \(error.localizedDescription)")
        }
    }

    public func completePairingScreen() {
        guard pairingStatus == .paired else {
            return
        }
        log(.debug, "User action: dismiss pairing success screen")
        isShowingPairingSuccess = false
        isPairingScreenDismissed = true
        if shouldShowWakeWordPromptAfterPairingScreen {
            shouldShowWakeWordPromptAfterPairingScreen = false
            presentWakeWordActivationPromptAfterPairing()
        }
    }

    public func startDemoMode() {
        log(.debug, "User action: start demo mode")
        stopPairingWait()
        isDemoMode = true
        isShowingPairingSuccess = false
        isPairingScreenDismissed = true
        shouldShowWakeWordPromptAfterPairingScreen = false
        pairingStatus = .unpaired
        isConnected = false
        isPairing = false
        backendAvailable = true
        updateRequiredMessage = nil
        pairingMessage = localized(
            english: "Demo mode active. Home Assistant is not connected.",
            dutch: "Demo modus actief. Home Assistant is niet gekoppeld."
        )
        applyDemoState()
        log(.info, "Demo mode started")
    }

    public func stopDemoMode() {
        log(.debug, "User action: stop demo mode")
        isDemoMode = false
        defaults.removeObject(forKey: demoModeKey)
        isPairingScreenDismissed = false
        clearRuntimeState()
        pairingMessage = localized(
            english: "Demo mode stopped. Pair with Home Assistant to continue.",
            dutch: "Demo modus gestopt. Koppel met Home Assistant om door te gaan."
        )
        log(.info, "Demo mode stopped")
    }

    func presentPairingSuccessScreenAfterPairing() {
        isShowingPairingSuccess = true
        isPairingScreenDismissed = false
    }

    public func markCleanShutdown() {
        defaults.set(true, forKey: cleanShutdownKey)
    }

    public func markActiveSession() {
        defaults.set(false, forKey: cleanShutdownKey)
    }

    public func dismissCrashReportPrompt() {
        defaults.set(false, forKey: crashPromptPendingKey)
        defaults.set(true, forKey: cleanShutdownKey)
        isShowingCrashReportPrompt = false
    }

    public func activateWakeWordFromPrompt() {
        log(.debug, "User action: activate wakeword from prompt")
        defaults.set(true, forKey: wakeWordPromptDismissedKey)
        isShowingWakeWordActivationPrompt = false
        wakeWordEnabled = true
        log(.info, "Wakeword enabled from post-pairing prompt")
    }

    public func dismissWakeWordActivationPrompt() {
        log(.debug, "User action: dismiss wakeword prompt")
        defaults.set(true, forKey: wakeWordPromptDismissedKey)
        isShowingWakeWordActivationPrompt = false
        log(.info, "Wakeword activation prompt dismissed")
    }

    func presentWakeWordActivationPromptAfterPairing() {
        guard !wakeWordEnabled else {
            return
        }
        guard !defaults.bool(forKey: wakeWordPromptDismissedKey) else {
            return
        }
        guard isPairingScreenDismissed else {
            shouldShowWakeWordPromptAfterPairingScreen = true
            return
        }
        isShowingWakeWordActivationPrompt = true
        log(.info, "Showing post-pairing wakeword activation prompt")
    }

    public func crashIssueURL() -> URL? {
        var components = URLComponents(string: "https://github.com/pcvantol/djconnect/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: "DJConnect app crash report"),
            URLQueryItem(name: "body", value: crashIssueBody())
        ]
        return components?.url
    }

    public func crashIssueBody() -> String {
        """
        ## DJConnect app crash report

        The app detected that the previous session may not have closed cleanly.

        Please describe what you were doing before the crash:


        ```text
        \(diagnosticExportText())
        ```
        """
    }

    deinit {
        scheduledPairingTask?.cancel()
        pairingTask?.cancel()
        volumeCommandTask?.cancel()
        playbackProgressTask?.cancel()
        startupRefreshTask?.cancel()
        localDeviceAPI?.stop()
    }

    public func stopLocalDeviceAPI() {
        localDeviceAPI?.stop()
        localDeviceAPI = nil
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
        guard !isDemoMode else {
            log(.debug, "Ignoring pairing wait because demo mode is active")
            return
        }
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
            let client = makeClient(baseURL: baseURL)
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
                presentPairingSuccessScreenAfterPairing()
                presentWakeWordActivationPromptAfterPairing()
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
        log(.debug, "User action: reset pairing")
        log(.warning, "Resetting pairing and clearing local token")
        scheduledPairingTask?.cancel()
        scheduledPairingTask = nil
        pairingTask?.cancel()
        pairingTask = nil
        try? tokenStore.clearToken()
        isDemoMode = false
        defaults.removeObject(forKey: demoModeKey)
        clearStoredHomeAssistantURLs()
        clearPinnedLocalDeviceAPIURL()
        defaults.removeObject(forKey: installIDKey)
        identity = Self.makeIdentity(defaults: defaults)
        clearRuntimeState()
        isShowingWakeWordActivationPrompt = false
        isShowingPairingSuccess = false
        isPairingScreenDismissed = false
        shouldShowWakeWordPromptAfterPairingScreen = false
        defaults.set(false, forKey: wakeWordPromptDismissedKey)
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
        log(.debug, "User action: refresh")
        Task {
            await runRefresh(reason: "Refresh completed")
        }
    }

    private func runRefresh(reason: String) async {
        guard !isRefreshing else {
            log(.debug, "Refresh ignored because one is already running")
            return
        }
        if isDemoMode {
            log(.debug, "Demo refresh requested")
            isRefreshing = true
            applyDemoState()
            isRefreshing = false
            log(.info, reason)
            return
        }
        log(.debug, "Manual refresh requested")
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await refreshStatusWithFallback()
            await refreshBackendCollections()
            log(.info, reason)
        } catch let error as DJConnectError {
            log(.warning, "Refresh failed: \(Self.describe(error))")
            apply(error: error)
        } catch {
            log(.error, "Refresh failed unexpectedly: \(error.localizedDescription)")
            pairingMessage = error.localizedDescription
        }
    }

    private func schedulePairedRefresh(reason: String) {
        startupRefreshTask?.cancel()
        startupRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else {
                return
            }
            await self?.runRefresh(reason: reason)
            try? await Task.sleep(for: .milliseconds(1_200))
            guard !Task.isCancelled, self?.pairingStatus == .paired else {
                return
            }
            await self?.runRefresh(reason: "Startup Now Playing refresh completed")
        }
    }

    public func sendPlaybackCommand(
        _ command: String,
        value: DJConnectCommandValue? = nil,
        play: Bool? = nil
    ) {
        guard isRuntimeCompatible else {
            log(.warning, "Command \(command) blocked because an app/integration update is required")
            return
        }
        log(.info, "Sending playback command: \(command)")
        Task {
            await performCommand(command, value: value, play: play)
        }
    }

    public func togglePlayback() {
        log(.debug, "User action: toggle playback")
        sendPlaybackCommand(isPlaying ? "pause" : "play")
    }

    public func commitVolumeChange() {
        volumeCommandTask?.cancel()
        let value = Int(volume.rounded())
        log(.debug, "User action: commit volume \(value)")
        pendingVolumePercent = value
        volumeCommandTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else {
                return
            }
            guard let self else {
                return
            }
            await self.performCommand("set_volume", value: .int(value))
            try? await Task.sleep(for: .milliseconds(850))
            guard !Task.isCancelled else {
                return
            }
            await self.performCommand("status")
            if self.pendingVolumePercent == value {
                self.pendingVolumePercent = nil
            }
        }
    }

    public func setShuffle(_ value: Bool) {
        log(.debug, "User action: set shuffle \(value)")
        sendPlaybackCommand("set_shuffle", value: .bool(value))
    }

    public func setRepeat(_ value: DJConnectRepeatState) {
        log(.debug, "User action: set repeat \(value.rawValue)")
        sendPlaybackCommand("set_repeat", value: .string(value.rawValue))
    }

    public func seekRelative(milliseconds: Int) {
        log(.debug, "User action: seek relative \(milliseconds)ms")
        sendPlaybackCommand("seek_relative", value: .int(milliseconds))
    }

    public func loadOutputs() {
        log(.debug, "User action: load outputs")
        log(.info, "Loading playback outputs")
        Task {
            guard !isLoadingOutputs else {
                return
            }
            isLoadingOutputs = true
            defer {
                isLoadingOutputs = false
            }
            await performCommand("devices")
        }
    }

    public func loadQueue() {
        log(.debug, "User action: load queue")
        Task {
            await refreshQueue()
        }
    }

    @discardableResult
    public func refreshQueue() async -> Bool {
        guard !isLoadingQueue else {
            return false
        }
        isLoadingQueue = true
        defer {
            isLoadingQueue = false
        }
        log(.info, "Loading queue")
        return await performCommand("queue")
    }

    public func loadPlaylists() {
        log(.debug, "User action: load playlists")
        Task {
            await refreshPlaylists()
        }
    }

    @discardableResult
    public func refreshPlaylists() async -> Bool {
        guard !isLoadingPlaylists else {
            return false
        }
        isLoadingPlaylists = true
        defer {
            isLoadingPlaylists = false
        }
        log(.info, "Loading playlists")
        return await performCommand("playlists")
    }

    public func selectOutput(_ output: DJConnectOutputDevice) {
        log(.debug, "User action: select output")
        selectedOutput = output.name
        pendingSelectedOutput = output.name
        availableOutputs = availableOutputs.map { candidate in
            var updated = candidate
            updated.active = candidate.id == output.id || candidate.name == output.name
            return updated
        }
        log(.info, "Selecting output \(output.name)")
        sendPlaybackCommand("set_output", value: .string(output.name), play: true)
    }

    public func startPlaylist(_ playlist: DJConnectPlaylist) {
        log(.debug, "User action: start playlist")
        log(.info, "Starting playlist \(playlist.name)")
        sendPlaybackCommand("start_playlist", value: .string(playlist.commandValue), play: true)
    }

    public func startLikedProxy() {
        log(.debug, "User action: start liked songs")
        log(.info, "Starting liked proxy flow")
        sendPlaybackCommand("start_liked_proxy", play: true)
    }

    public func canStartQueueItem(_ item: DJConnectQueueItem) -> Bool {
        item.uri?.isEmpty == false && resolvedQueueContext?.isEmpty == false
    }

    public func startQueueItem(_ item: DJConnectQueueItem, at index: Int? = nil) {
        log(.debug, "User action: start queue item")
        guard let uri = item.uri, !uri.isEmpty else {
            log(.warning, "Queue item \(item.title) cannot start because it has no URI")
            return
        }
        guard let contextURI = resolvedQueueContext, !contextURI.isEmpty else {
            log(.warning, "Queue item \(item.title) cannot start because Home Assistant did not provide playback context")
            pairingMessage = localized(
                english: "Queue playback needs a playback context. Refresh Now Playing and queue, then try again.",
                dutch: "Wachtrij afspelen heeft een playback-context nodig. Vernieuw Speelt Nu en de wachtrij en probeer opnieuw."
            )
            return
        }
        var payload = [
            "uri": uri,
            "title": item.title,
            "context_uri": contextURI
        ]
        if Self.queueContextSupportsOffset(contextURI) {
            payload["offset_uri"] = uri
        }
        if let index {
            payload["index"] = String(index)
        } else if let index = queueItems.firstIndex(where: { $0.id == item.id }) {
            payload["index"] = String(index)
        }
        if let artist = item.artist, !artist.isEmpty {
            payload["artist"] = artist
        }
        log(.info, "Starting queue item \(item.title)")
        loadingQueueItemID = item.id
        loadingQueueItemIndex = index
        Task {
            let didStart = await performCommand("play_context_at", value: .object(payload), play: true)
            guard didStart, pairingStatus == .paired else {
                loadingQueueItemID = nil
                loadingQueueItemIndex = nil
                return
            }
            try? await Task.sleep(for: .milliseconds(1100))
            guard pairingStatus == .paired else {
                loadingQueueItemID = nil
                loadingQueueItemIndex = nil
                return
            }
            await runRefresh(reason: "Queue item Now Playing refresh completed")
            loadingQueueItemID = nil
            loadingQueueItemIndex = nil
        }
    }

    private var resolvedQueueContext: String? {
        let queueContext = queueContext?.trimmingCharacters(in: .whitespacesAndNewlines)
        if queueContext?.isEmpty == false {
            return queueContext
        }
        let playbackContext = playback?.contextURI?.trimmingCharacters(in: .whitespacesAndNewlines)
        if playbackContext?.isEmpty == false {
            return playbackContext
        }
        return nil
    }

    private static func queueContextSupportsOffset(_ contextURI: String) -> Bool {
        contextURI.hasPrefix("spotify:playlist:")
            || contextURI.hasPrefix("spotify:album:")
            || contextURI.hasPrefix("spotify:show:")
    }

    public func toggleVoiceRecording() {
        log(.debug, "User action: toggle voice recording")
        isRecordingVoice ? stopVoiceRecordingAndUpload() : startVoiceRecording()
    }

    public func startVoiceRecording() {
        guard !isRecordingVoice, voiceStatus != .processing else {
            return
        }
        if isDemoMode {
            voiceStatus = .processing
            djResponseText = localized(
                english: "Demo DJ: this is where your personal music DJ responds after your music request.",
                dutch: "Demo DJ: hier reageert je persoonlijke muziek DJ na je muziek verzoek."
            )
            voiceStatus = .idle
            log(.info, "Demo voice request completed")
            return
        }
        stopWakeWordListening()
        guard voiceEnabled else {
            voiceStatus = .unavailable
            log(.warning, "Voice recording ignored because voice is disabled")
            resumeWakeWordListeningIfNeeded()
            return
        }
        guard pairingStatus == .paired else {
            voiceStatus = .unavailable
            voiceErrorMessage = localized(
                english: "Pair with Home Assistant before using voice.",
                dutch: "Koppel eerst met Home Assistant voordat je voice gebruikt."
            )
            log(.warning, "Voice recording ignored because app is not paired")
            resumeWakeWordListeningIfNeeded()
            return
        }

        Task { @MainActor in
            let granted = await requestMicrophoneAccess()
            guard granted else {
                voiceStatus = .unavailable
                voiceErrorMessage = localized(
                    english: "Microphone access is required for push-to-talk.",
                    dutch: "Microfoontoegang is nodig voor push-to-talk."
                )
                log(.warning, "Microphone permission was not granted")
                resumeWakeWordListeningIfNeeded()
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
        voiceStatus = .processing
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif

        guard let url else {
            voiceStatus = .unavailable
            log(.warning, "Voice upload skipped because recording URL is missing")
            resumeWakeWordListeningIfNeeded()
            return
        }

        Task {
            do {
                let data = try Data(contentsOf: url)
                try? FileManager.default.removeItem(at: url)
                log(.info, "Uploading voice recording WAV (\(data.count) bytes)")
                let response = try await sendVoiceWithFallback(wavData: data)
                djResponseText = userFacingDJResponseText(response.djText ?? response.text) ?? localized(
                    english: "Voice request completed.",
                    dutch: "Voice-request afgerond."
                )
                Task {
                    await playResponseAudioIfNeeded(resolvedAudioURL(from: response.audioURL))
                }
                await refreshAfterDJResponse()
                voiceErrorMessage = nil
                voiceStatus = .idle
                log(.info, "Voice request completed")
                resumeWakeWordListeningIfNeeded()
            } catch let error as DJConnectError {
                let describedError = Self.describe(error)
                if let userFacingError = userFacingDJResponseText(describedError) {
                    djResponseText = userFacingError
                    voiceErrorMessage = userFacingError
                } else {
                    voiceErrorMessage = describedError
                }
                voiceStatus = .unavailable
                log(.warning, "Voice upload failed: \(describedError)")
                apply(error: error)
                resumeWakeWordListeningIfNeeded()
            } catch {
                voiceErrorMessage = error.localizedDescription
                voiceStatus = .unavailable
                log(.error, "Voice upload failed unexpectedly: \(error.localizedDescription)")
                resumeWakeWordListeningIfNeeded()
            }
        }
        #else
        isRecordingVoice = false
        voiceStatus = .unavailable
        voiceErrorMessage = localized(
            english: "Voice recording is not available on this platform.",
            dutch: "Voice-opname is niet beschikbaar op dit platform."
        )
        #endif
    }

    public func apply(playback: DJConnectPlayback?) {
        guard isRuntimeCompatible else {
            log(.debug, "Ignoring playback snapshot because Home Assistant integration version is incompatible")
            return
        }
        var normalizedPlayback = playback
        let deviceVolume = normalizedPlayback?.device?.volumePercent
        if normalizedPlayback?.volumePercent == nil, let deviceVolume {
            normalizedPlayback?.volumePercent = deviceVolume
        }
        if let pendingVolumePercent {
            if normalizedPlayback?.volumePercent == pendingVolumePercent {
                self.pendingVolumePercent = nil
            } else {
                normalizedPlayback?.volumePercent = pendingVolumePercent
            }
        }
        self.playback = normalizedPlayback
        if startBackgroundTasks {
            updatePlaybackProgressTimer()
        }
        if let deviceName = normalizedPlayback?.device?.name, !deviceName.isEmpty {
            if pendingSelectedOutput == nil || pendingSelectedOutput == deviceName {
                selectedOutput = deviceName
                pendingSelectedOutput = nil
            }
        }
        backendAvailable = true
        updateRequiredMessage = nil
        if let normalizedPlayback {
            let playing = normalizedPlayback.isPlaying.map(String.init) ?? "unknown"
            let volume = normalizedPlayback.volumePercent.map(String.init) ?? "unknown"
            log(.debug, "Applied playback snapshot: playing=\(playing), volume=\(volume)")
        } else {
            log(.debug, "Applied empty playback snapshot")
        }
    }

    public func apply(commandResponse response: DJConnectCommandResponse) {
        guard validateHomeAssistantVersion(
            haVersion: response.haVersion,
            haMajorMinor: response.haMajorMinor,
            message: response.message
        ) else {
            return
        }
        if let playback = response.playback {
            apply(playback: playback)
        }
        backendAvailable = response.backendAvailable ?? backendAvailable
        if backendAvailable, voiceStatus == .unavailable, voiceErrorMessage == nil {
            voiceStatus = .idle
        }
        if let devices = response.devices {
            availableOutputs = devices
            if let active = devices.first(where: { $0.active == true }) {
                if pendingSelectedOutput == nil || pendingSelectedOutput == active.name {
                    selectedOutput = active.name
                    pendingSelectedOutput = nil
                } else if let pendingSelectedOutput {
                    selectedOutput = pendingSelectedOutput
                }
            } else if selectedOutput == "Not selected", let first = devices.first {
                selectedOutput = first.name
            }
        }
        if let responseQueue = response.queue {
            queueItems = responseQueue
            queue = responseQueue.map(\.displayTitle)
        }
        if response.queueContext != nil || response.queue != nil {
            queueContext = response.queueContext
        }
        if let responsePlaylists = response.playlists {
            playlistItems = responsePlaylists
            playlists = responsePlaylists.map(\.name)
        }
        if let message = response.message, !message.isEmpty {
            djResponseText = userFacingDJResponseText(message) ?? message
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
            djResponseText = userFacingDJResponseText(text) ?? text
        }
        if let audioURL = response.audioURL, !audioURL.isEmpty {
            log(.info, "Received DJ response audio URL from Home Assistant")
            Task {
                await playResponseAudioIfNeeded(resolvedAudioURL(from: URL(string: audioURL)))
            }
        }
        Task {
            await refreshAfterDJResponse()
        }
    }

    public func apply(error: DJConnectError) {
        log(.warning, "Applying app error state: \(Self.describe(error))")
        switch error {
        case let .backendUnavailable(message):
            backendAvailable = false
            voiceStatus = .unavailable
            if let message, !message.isEmpty {
                log(.warning, "Backend unavailable: \(message)")
            }
        case let .versionMismatch(mismatch):
            clearRuntimeState()
            backendAvailable = false
            updateRequiredMessage = mismatch.message ?? localized(
                english: "Update the DJConnect app or Home Assistant integration.",
                dutch: "Werk de DJConnect app of Home Assistant-integratie bij."
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
        case let .server(_, message):
            if let userFacingError = userFacingDJResponseText(message ?? Self.describe(error)) {
                djResponseText = userFacingError
            }
        case .missingToken:
            pairingStatus = .stale
            isConnected = false
            pairingMessage = localized(
                english: "Missing DJConnect bearer token. Reset pairing to set up again.",
                dutch: "DJConnect bearer-token ontbreekt. Reset de pairing om opnieuw te koppelen."
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
            guard validateHomeAssistantVersion(
                haVersion: response.haVersion,
                haMajorMinor: response.haMajorMinor,
                message: response.message
            ) else {
                return
            }
            if let playback = response.playback {
                apply(playback: playback)
            } else {
                log(.debug, "Status response did not include a playback snapshot")
            }
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
        let client = try makeClient()
        try await refreshPlaybackSnapshot(client: client)
    }

    private func refreshPlaybackSnapshot(client: DJConnectClient) async throws {
        do {
            log(.debug, "Loading Now Playing snapshot")
            let response = try await client.sendCommandResponse(
                DJConnectCommandPayload(
                    identity: identity,
                    command: "status"
                )
            )
            apply(commandResponse: response)
            if response.playback == nil {
                try await refreshStatus(client: client)
            }
        } catch let error as DJConnectError {
            if case .routeMissing = error {
                try await refreshStatus(client: client)
            } else {
                throw error
            }
        }
    }

    private func refreshAfterDJResponse() async {
        guard pairingStatus == .paired else {
            return
        }

        do {
            log(.debug, "Refreshing Home Assistant state after DJ response")
            try await refreshStatusWithFallback()
            await refreshBackendCollections()
        } catch let error as DJConnectError {
            log(.warning, "DJ response refresh failed: \(Self.describe(error))")
            apply(error: error)
        } catch {
            log(.error, "DJ response refresh failed unexpectedly: \(error.localizedDescription)")
        }
    }

    private func clearRuntimeState() {
        playbackProgressTask?.cancel()
        playbackProgressTask = nil
        volumeCommandTask?.cancel()
        volumeCommandTask = nil
        pendingSelectedOutput = nil
        pendingVolumePercent = nil
        playback = nil
        queue = []
        playlists = []
        availableOutputs = []
        queueItems = []
        loadingQueueItemID = nil
        loadingQueueItemIndex = nil
        isLoadingQueue = false
        isLoadingPlaylists = false
        queueContext = nil
        playlistItems = []
        selectedOutput = "Not selected"
        djResponseText = ""
        voiceStatus = .idle
        backendAvailable = true
        updateRequiredMessage = nil
        isRefreshing = false
        isLoadingOutputs = false
        #if canImport(AVFoundation)
        responseAudioPlayer?.stop()
        responseAudioPlayer = nil
        #endif
    }

    private func validateHomeAssistantVersion(
        haVersion: String?,
        haMajorMinor: String?,
        message: String?
    ) -> Bool {
        let resolvedVersion = haVersion ?? haMajorMinor
        guard let resolvedVersion, !resolvedVersion.isEmpty else {
            return true
        }
        guard Self.isCompatibleHomeAssistantVersion(resolvedVersion) else {
            let requiredRange = Self.requiredHomeAssistantVersionRangeDescription()
            clearRuntimeState()
            backendAvailable = false
            updateRequiredMessage = message ?? localized(
                english: "Update the DJConnect app or Home Assistant integration to \(requiredRange).",
                dutch: "Werk de DJConnect app of Home Assistant-integratie bij naar \(requiredRange)."
            )
            log(.error, "Home Assistant integration version \(resolvedVersion) is incompatible with app \(appVersion); required \(requiredRange)")
            return false
        }
        updateRequiredMessage = nil
        return true
    }

    private static func isCompatibleHomeAssistantVersion(_ version: String) -> Bool {
        guard let parsed = parsedVersion(version),
              let app = parsedVersion(protocolVersion)
        else {
            return true
        }
        return parsed.major == app.major && parsed.minor == app.minor
    }

    private static func requiredHomeAssistantVersionRangeDescription() -> String {
        guard let app = parsedVersion(protocolVersion) else {
            return "the matching \(protocolVersion) release"
        }
        return "\(app.major).\(app.minor).x (>=\(app.major).\(app.minor).0, <\(app.major).\(app.minor + 1).0)"
    }

    private static func defaultLanguage() -> String {
        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferredLanguage.hasPrefix("nl") ? "nl" : "en"
    }

    private static func parsedVersion(_ version: String) -> (major: Int, minor: Int, patch: Int)? {
        let cleanedVersion = version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("v")
        guard let numericPrefix = cleanedVersion
            .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            .first
        else {
            return nil
        }
        let parts = numericPrefix.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2 else {
            return nil
        }
        return (
            major: parts[0],
            minor: parts[1],
            patch: parts.count >= 3 ? parts[2] : 0
        )
    }

    private func updatePlaybackProgressTimer() {
        playbackProgressTask?.cancel()
        guard playback?.isPlaying == true else {
            return
        }

        playbackProgressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else {
                    return
                }
                self?.advancePlaybackProgress()
            }
        }
    }

    private func advancePlaybackProgress() {
        guard var currentPlayback = playback, currentPlayback.isPlaying == true else {
            playbackProgressTask?.cancel()
            playbackProgressTask = nil
            return
        }

        let currentProgress = currentPlayback.progressMS ?? 0
        if let duration = currentPlayback.durationMS, duration > 0 {
            currentPlayback.progressMS = min(currentProgress + 1_000, duration)
        } else {
            currentPlayback.progressMS = currentProgress + 1_000
        }
        playback = currentPlayback
    }

    private func sendVoiceWithFallback(wavData: Data) async throws -> DJConnectVoiceResponse {
        try await makeClient().sendVoice(wavData: wavData)
    }

    private func userFacingDJResponseText(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if let message = Self.extractServerJSONMessage(from: text) {
            return userFacingDJResponseText(message) ?? message
        }
        let normalized = text.lowercased()
        if normalized.contains("did not return recognized text")
            || normalized.contains("recognitionstatus") {
            log(.info, "HA Assist STT did not recognize the input")
            return localized(english: "Input not recognized", dutch: "Invoer niet herkend")
        }
        if normalized.contains("not recognized") || normalized.contains("not_recognized") {
            log(.info, "STT response was not recognized")
            return localized(english: "Not recognized", dutch: "Niet herkend")
        }
        if normalized.contains("spotify authorization")
            || normalized.contains("reauthorize djconnect")
            || normalized.contains("start_spotify_oauth")
            || normalized.contains("spotify oauth") {
            log(.warning, "Spotify authorization needs refresh: \(text)")
            return localized(
                english: "Refresh the Spotify connection in Home Assistant",
                dutch: "Ververs Spotify koppeling in Home Assistant"
            )
        }
        return text
    }

    private static func extractServerJSONMessage(from text: String) -> String? {
        guard let jsonStart = text.firstIndex(of: "{") else {
            return nil
        }
        let jsonText = String(text[jsonStart...])
        guard let data = jsonText.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return findMessage(in: object)
    }

    private static func findMessage(in object: Any) -> String? {
        if let dictionary = object as? [String: Any] {
            if let message = dictionary["message"] as? String, !message.isEmpty {
                return message
            }
            for value in dictionary.values {
                if let message = findMessage(in: value) {
                    return message
                }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let message = findMessage(in: value) {
                    return message
                }
            }
        }
        return nil
    }

    private func resolvedAudioURL(from audioURL: URL?) -> URL? {
        guard let audioURL else {
            log(.warning, "DJ response did not include an audio URL")
            return nil
        }
        if audioURL.scheme?.isEmpty == false {
            return audioURL
        }
        guard let baseURL = Self.normalizedHomeAssistantURL(from: localHomeAssistantURL()) else {
            log(.warning, "DJ response audio URL is relative but Home Assistant URL is invalid")
            return nil
        }
        return URL(string: audioURL.absoluteString, relativeTo: baseURL)?.absoluteURL
    }

    private func playResponseAudioIfNeeded(_ audioURL: URL?) async {
        guard localResponseAudioEnabled else {
            log(.debug, "Skipping DJ response audio because local response audio is disabled")
            return
        }
        guard let audioURL else {
            return
        }
        #if canImport(AVFoundation)
        do {
            log(.info, "Loading DJ response audio from Home Assistant")
            let (data, response) = try await URLSession.shared.data(from: audioURL)
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                log(.warning, "DJ response audio failed with HTTP \(httpResponse.statusCode)")
                return
            }
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
            let player = try AVAudioPlayer(data: data)
            player.prepareToPlay()
            responseAudioPlayer = player
            player.play()
            log(.info, "Playing DJ response audio")
        } catch {
            log(.warning, "DJ response audio could not be played: \(error.localizedDescription)")
        }
        #else
        log(.warning, "DJ response audio is not available on this platform")
        #endif
    }

    @discardableResult
    private func performCommand(
        _ command: String,
        value: DJConnectCommandValue? = nil,
        play: Bool? = nil
    ) async -> Bool {
        if isDemoMode {
            applyDemoCommand(command, value: value, play: play)
            return true
        }
        guard pairingStatus == .paired else {
            log(.warning, "Command \(command) skipped because app is not paired")
            return false
        }
        guard isRuntimeCompatible else {
            log(.warning, "Command \(command) skipped because update is required")
            return false
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
            if Self.shouldRefreshPlaybackAfterCommand(command) {
                try await refreshPlaybackSnapshot(client: client)
                if Self.shouldRefreshPlaybackAgainAfterCommand(command) {
                    try? await Task.sleep(for: .milliseconds(850))
                    guard pairingStatus == .paired else {
                        return true
                    }
                    try await refreshPlaybackSnapshot(client: client)
                }
            }
            log(.debug, "Command \(command) succeeded")
            return true
        } catch let error as DJConnectError {
            log(.warning, "Command \(command) failed: \(Self.describe(error))")
            apply(error: error)
            return false
        } catch {
            log(.error, "Command \(command) failed unexpectedly: \(error.localizedDescription)")
            pairingMessage = error.localizedDescription
            return false
        }
    }

    private func applyDemoState() {
        let output = DJConnectOutputDevice(
            id: "demo-living-room",
            name: localized(english: "Living Room", dutch: "Woonkamer"),
            type: "speaker",
            active: true,
            supportsVolume: true,
            volumePercent: 42
        )
        availableOutputs = [
            output,
            DJConnectOutputDevice(
                id: "demo-kitchen",
                name: localized(english: "Kitchen", dutch: "Keuken"),
                type: "speaker",
                active: false,
                supportsVolume: true,
                volumePercent: 35
            )
        ]
        selectedOutput = output.name
        playback = DJConnectPlayback(
            hasPlayback: true,
            isPlaying: true,
            trackName: "Midnight City",
            artistName: "M83",
            albumImageURL: nil,
            progressMS: 48_000,
            durationMS: 244_000,
            volumePercent: 42,
            shuffle: false,
            repeatState: .off,
            device: DJConnectPlaybackDevice(
                id: output.id,
                name: output.name,
                type: output.type,
                active: true,
                supportsVolume: true,
                volumePercent: output.volumePercent
            ),
            contextURI: "spotify:playlist:djconnect-demo"
        )
        queueItems = [
            DJConnectQueueItem(id: "demo-0", title: "Midnight City", artist: "M83", album: "Hurry Up, We're Dreaming", uri: "spotify:track:demo-0", durationMS: 244_000),
            DJConnectQueueItem(id: "demo-1", title: "Sweet Disposition", artist: "The Temper Trap", album: "Conditions", uri: "spotify:track:demo-1", durationMS: 232_000),
            DJConnectQueueItem(id: "demo-2", title: "Electric Feel", artist: "MGMT", album: "Oracular Spectacular", uri: "spotify:track:demo-2", durationMS: 229_000)
        ]
        queue = queueItems.map(\.displayTitle)
        queueContext = "spotify:playlist:djconnect-demo"
        playlistItems = [
            DJConnectPlaylist(id: "demo-playlist-1", name: localized(english: "Friday Night", dutch: "Vrijdagavond"), uri: "spotify:playlist:djconnect-demo"),
            DJConnectPlaylist(id: "demo-playlist-2", name: localized(english: "Dinner Vibes", dutch: "Dinner vibes"), uri: "spotify:playlist:djconnect-dinner")
        ]
        playlists = playlistItems.map(\.name)
        djResponseText = localized(
            english: "DJ request is not available in Demo Mode. Exit Demo Mode in Settings.",
            dutch: "DJ verzoek is niet beschikbaar in demo modus. Verlaat demo mode via Instellingen."
        )
        backendAvailable = true
        updateRequiredMessage = nil
        if startBackgroundTasks {
            updatePlaybackProgressTimer()
        }
    }

    private func applyDemoCommand(_ command: String, value: DJConnectCommandValue? = nil, play: Bool? = nil) {
        log(.info, "Demo command: \(command)")
        var updated = playback ?? DJConnectPlayback()
        switch command {
        case "play", "start_playlist", "start_liked_proxy":
            updated.isPlaying = true
        case "play_context_at":
            if case let .object(payload) = value, let rawIndex = payload["index"], let index = Int(rawIndex) {
                applyDemoQueueItem(at: index)
                return
            }
            updated.isPlaying = true
        case "pause":
            updated.isPlaying = false
        case "next":
            applyDemoQueueItem(at: 1)
            return
        case "previous":
            applyDemoQueueItem(at: 0)
            return
        case "set_volume":
            if case let .int(volume) = value {
                updated.volumePercent = volume
                availableOutputs = availableOutputs.map { device in
                    var device = device
                    if device.active == true {
                        device.volumePercent = volume
                    }
                    return device
                }
            }
        case "set_shuffle":
            if case let .bool(shuffle) = value {
                updated.shuffle = shuffle
            }
        case "set_repeat":
            if case let .string(repeatValue) = value {
                updated.repeatState = DJConnectRepeatState(rawValue: repeatValue) ?? .off
            }
        case "seek_relative":
            if case let .int(delta) = value {
                let currentProgress = updated.progressMS ?? 0
                let duration = updated.durationMS ?? max(currentProgress + delta, 0)
                updated.progressMS = min(max(currentProgress + delta, 0), max(duration, 0))
            }
        case "set_output":
            if case let .string(name) = value {
                selectedOutput = name
                availableOutputs = availableOutputs.map { device in
                    var device = device
                    device.active = device.name == name || device.id == name
                    return device
                }
                updated.device = availableOutputs.first(where: { $0.active == true }).map {
                    DJConnectPlaybackDevice(id: $0.id, name: $0.name, type: $0.type, active: true, supportsVolume: $0.supportsVolume, volumePercent: $0.volumePercent)
                }
            }
        case "queue", "playlists", "devices", "status":
            break
        default:
            break
        }
        playback = updated
        if startBackgroundTasks {
            updatePlaybackProgressTimer()
        }
    }

    private func applyDemoQueueItem(at index: Int) {
        guard queueItems.indices.contains(index) else {
            return
        }
        let item = queueItems[index]
        playback = DJConnectPlayback(
            hasPlayback: true,
            isPlaying: true,
            trackName: item.title,
            artistName: item.artist,
            albumImageURL: item.albumImageURL,
            progressMS: 0,
            durationMS: item.durationMS,
            volumePercent: playback?.volumePercent ?? 42,
            shuffle: playback?.shuffle ?? false,
            repeatState: playback?.repeatState ?? .off,
            device: playback?.device,
            contextURI: queueContext
        )
        if startBackgroundTasks {
            updatePlaybackProgressTimer()
        }
    }

    private static func shouldRefreshPlaybackAfterCommand(_ command: String) -> Bool {
        switch command {
        case "play", "pause", "next", "previous", "set_output", "start_playlist", "start_liked_proxy", "play_context_at":
            true
        default:
            false
        }
    }

    private static func shouldRefreshPlaybackAgainAfterCommand(_ command: String) -> Bool {
        switch command {
        case "play", "pause", "next", "previous", "play_context_at":
            true
        default:
            false
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
        return makeClient(baseURL: baseURL)
    }

    private func makeClient(baseURL: URL) -> DJConnectClient {
        DJConnectClient(baseURL: baseURL, identity: identity, tokenStore: tokenStore) { [weak self] requestSummary, statusCode in
            Task { @MainActor in
                self?.log(.debug, "Home Assistant API \(requestSummary) -> HTTP \(statusCode)")
            }
        }
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
                        firmware: "3.1.9",
                        appVersion: "3.1.9",
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
                    self?.applyLocalDeviceAPIURL(url)
                }
            },
            logHandler: { [weak self] message in
                await MainActor.run {
                    self?.log(.info, message)
                }
            },
            preferredPort: pinnedLocalDeviceAPIPort()
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
        if let localDeviceAPIURL, !localDeviceAPIURL.isEmpty {
            pinLocalDeviceAPIURL(localDeviceAPIURL)
        }
        pairingStatus = .paired
        isConnected = true
        isPairing = false
        pairingMessage = localized(english: "Paired with Home Assistant.", dutch: "Gekoppeld met Home Assistant.")
        log(.info, "Local device API completed pairing from Home Assistant")
        presentPairingSuccessScreenAfterPairing()
        presentWakeWordActivationPromptAfterPairing()
        if startBackgroundTasks {
            refresh()
        }
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
        case "play", "pause", "next", "previous", "set_volume", "set_shuffle", "set_repeat", "start_liked_proxy", "start_playlist", "play_context_at", "set_output":
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

    private func applyLocalDeviceAPIURL(_ url: String?) {
        if let pinnedURL = defaults.string(forKey: localDeviceAPIURLKey), !pinnedURL.isEmpty {
            localDeviceAPIURL = pinnedURL
            return
        }
        localDeviceAPIURL = url
        if pairingStatus == .paired, let url, !url.isEmpty {
            pinLocalDeviceAPIURL(url)
        }
    }

    private func pinLocalDeviceAPIURL(_ url: String) {
        localDeviceAPIURL = url
        defaults.set(url, forKey: localDeviceAPIURLKey)
        log(.info, "Pinned Client API url for current pairing")
    }

    private func clearPinnedLocalDeviceAPIURL() {
        localDeviceAPIURL = nil
        defaults.removeObject(forKey: localDeviceAPIURLKey)
    }

    private func pinnedLocalDeviceAPIPort() -> UInt16? {
        guard
            let urlString = defaults.string(forKey: localDeviceAPIURLKey),
            let port = URL(string: urlString)?.port,
            port > 0,
            port <= Int(UInt16.max)
        else {
            return nil
        }
        return UInt16(port)
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
        demo_mode: \(isDemoMode)
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
        wakeword_enabled: \(wakeWordEnabled)
        wakeword_phrase: \(wakeWordPhrase)
        wakeword_status: \(wakeWordStatus)
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
        let line = "[\(formatter.string(from: Date()))] \(Self.logAbbreviation(for: level)) \(message)"
        diagnosticLogLines.append(DJConnectDiagnosticLogLine(text: line))
        if diagnosticLogLines.count > maxDiagnosticLogLines {
            diagnosticLogLines.removeFirst(diagnosticLogLines.count - maxDiagnosticLogLines)
        }
    }

    private static func logAbbreviation(for level: DJConnectAppLogLevel) -> String {
        switch level {
        case .debug:
            "DBG"
        case .info:
            "INF"
        case .warning:
            "WRN"
        case .error:
            "ERR"
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

    public func refreshPermissionStatuses() {
        microphonePermissionStatus = Self.currentMicrophonePermissionStatus()
        speechPermissionStatus = Self.currentSpeechPermissionStatus()
        localNetworkPermissionStatus = .unknown
    }

    public func requestAppPermissions() {
        guard !isRequestingPermissions else {
            return
        }
        isRequestingPermissions = true
        Task { @MainActor in
            let microphoneGranted = await requestMicrophoneAccess()
            let speechGranted = await requestSpeechAccessIfAvailable()
            refreshPermissionStatuses()
            isRequestingPermissions = false
            if microphoneGranted, speechGranted {
                log(.info, "App permissions granted")
            } else {
                log(.warning, "App permissions are incomplete")
            }
        }
    }

    private static func currentMicrophonePermissionStatus() -> DJConnectPermissionStatus {
        #if canImport(AVFoundation)
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            .granted
        case .denied:
            .denied
        case .restricted:
            .restricted
        case .notDetermined:
            .unknown
        @unknown default:
            .unknown
        }
        #else
        .unavailable
        #endif
    }

    private static func currentSpeechPermissionStatus() -> DJConnectPermissionStatus {
        #if canImport(Speech)
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            .granted
        case .denied:
            .denied
        case .restricted:
            .restricted
        case .notDetermined:
            .unknown
        @unknown default:
            .unknown
        }
        #else
        .unavailable
        #endif
    }

    private func requestMicrophoneAccess() async -> Bool {
        #if canImport(AVFoundation)
        return await withCheckedContinuation { continuation in
            let resumeOnMainQueue: @Sendable (Bool) -> Void = { granted in
                DispatchQueue.main.async {
                    continuation.resume(returning: granted)
                }
            }
            #if os(iOS)
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission(completionHandler: resumeOnMainQueue)
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission(resumeOnMainQueue)
            }
            #elseif os(macOS)
            AVCaptureDevice.requestAccess(for: .audio, completionHandler: resumeOnMainQueue)
            #else
            resumeOnMainQueue(false)
            #endif
        }
        #else
        return false
        #endif
    }

    private func requestSpeechAccessIfAvailable() async -> Bool {
        #if canImport(Speech) && canImport(AVFoundation)
        await requestSpeechAccess()
        #else
        false
        #endif
    }

    private func startWakeWordListening() {
        guard wakeWordEnabled else {
            wakeWordStatus = .idle
            return
        }
        guard !isDemoMode else {
            wakeWordStatus = .unavailable
            log(.info, "Wakeword is disabled in demo mode")
            return
        }
        guard voiceEnabled, pairingStatus == .paired, !isRecordingVoice, voiceStatus != .processing else {
            wakeWordStatus = .idle
            return
        }
        #if canImport(Speech) && canImport(AVFoundation)
        #if os(iOS) && targetEnvironment(simulator)
        wakeWordStatus = .unavailable
        log(.warning, "Wakeword listening is disabled on iOS Simulator because simulator speech/audio capture is unstable")
        return
        #else
        guard wakeAudioEngine == nil else {
            return
        }
        Task { @MainActor in
            let microphoneGranted = await requestMicrophoneAccess()
            let speechGranted = await requestSpeechAccess()
            guard microphoneGranted, speechGranted else {
                wakeWordStatus = .unavailable
                log(.warning, "Wakeword listening unavailable because microphone or speech permission was not granted")
                return
            }
            beginWakeWordListening()
        }
        #endif
        #else
        wakeWordStatus = .unavailable
        log(.warning, "Wakeword listening is not available on this platform")
        #endif
    }

    private func stopWakeWordListening() {
        #if canImport(Speech) && canImport(AVFoundation)
        guard !isStoppingWakeWord else {
            return
        }
        isStoppingWakeWord = true
        defer {
            isStoppingWakeWord = false
        }
        wakeWordRestartTask?.cancel()
        wakeWordRestartTask = nil
        wakeRecognitionTask?.cancel()
        wakeRecognitionTask = nil
        wakeRecognitionRequest?.endAudio()
        wakeRecognitionRequest = nil
        if let wakeAudioEngine {
            wakeAudioEngine.inputNode.removeTap(onBus: 0)
            wakeAudioEngine.stop()
        }
        wakeAudioEngine = nil
        #endif
        wakeWordStatus = .idle
    }

    private func restartWakeWordListening() {
        stopWakeWordListening()
        resumeWakeWordListeningIfNeeded()
    }

    private func resumeWakeWordListeningIfNeeded() {
        guard !isDemoMode else {
            wakeWordStatus = .unavailable
            return
        }
        guard wakeWordEnabled, pairingStatus == .paired else {
            return
        }
        #if canImport(Speech) && canImport(AVFoundation)
        wakeWordRestartTask?.cancel()
        wakeWordRestartTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else {
                return
            }
            startWakeWordListening()
        }
        #else
        wakeWordStatus = .unavailable
        #endif
    }

    private func triggerWakeWordCapture() {
        guard !isDemoMode, wakeWordEnabled, pairingStatus == .paired, !isRecordingVoice else {
            return
        }
        log(.info, "Wakeword detected")
        wakeWordStatus = .detected
        stopWakeWordListening()
        startVoiceRecording()
        #if canImport(Speech) && canImport(AVFoundation)
        wakeWordCaptureTask?.cancel()
        wakeWordCaptureTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, isRecordingVoice else {
                return
            }
            stopVoiceRecordingAndUpload()
        }
        #endif
    }

    #if canImport(Speech) && canImport(AVFoundation)
    private func requestSpeechAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    private func beginWakeWordListening() {
        guard wakeAudioEngine == nil else {
            return
        }
        guard !isStoppingWakeWord else {
            return
        }
        let locale = Locale(identifier: language == "nl" ? "nl-NL" : "en-US")
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            wakeWordStatus = .unavailable
            log(.warning, "Wakeword speech recognizer is unavailable for \(locale.identifier)")
            return
        }
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            #endif

            let engine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()
            wakeAudioEngine = engine
            wakeRecognitionRequest = request
            wakeWordStatus = .listening
            log(.info, "Wakeword listening started for \(wakeWordPhrase)")

            wakeRecognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        let transcript = result.bestTranscription.formattedString
                        if self.transcriptContainsWakeWord(transcript) {
                            self.triggerWakeWordCapture()
                            return
                        }
                    }
                    if let error {
                        self.log(.warning, "Wakeword listening failed: \(error.localizedDescription)")
                        self.stopWakeWordListening()
                        self.resumeWakeWordListeningIfNeeded()
                    }
                }
            }
        } catch {
            wakeWordStatus = .unavailable
            log(.error, "Wakeword listening could not start: \(error.localizedDescription)")
        }
    }
    #endif

    private func transcriptContainsWakeWord(_ transcript: String) -> Bool {
        let normalizedTranscript = Self.normalizedWakeWordText(transcript)
        let normalizedWakeWord = Self.normalizedWakeWordText(wakeWordPhrase)
        guard !normalizedWakeWord.isEmpty else {
            return false
        }
        return normalizedTranscript.contains(normalizedWakeWord)
    }

    private static func normalizedWakeWordText(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func beginVoiceRecording() {
        #if canImport(AVFoundation)
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
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
            voiceStatus = .listening
            log(.info, "Voice recording started")
        } catch {
            isRecordingVoice = false
            voiceStatus = .unavailable
            voiceErrorMessage = error.localizedDescription
            log(.error, "Voice recording failed: \(error.localizedDescription)")
        }
        #else
        voiceStatus = .unavailable
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

    private static var isRunningUnderDebugger: Bool {
        #if DEBUG && canImport(Darwin)
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let result = name.withUnsafeMutableBufferPointer { pointer in
            sysctl(pointer.baseAddress, u_int(pointer.count), &info, &size, nil, 0)
        }
        guard result == 0 else {
            return false
        }
        return (info.kp_proc.p_flag & P_TRACED) != 0
        #else
        return false
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
