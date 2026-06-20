import Combine
import DJConnectCore
import Foundation
import Network
import OSLog

#if canImport(UserNotifications)
import UserNotifications
#endif
#if DEBUG && canImport(Darwin)
import Darwin
#endif

#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(Speech)
import Speech
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
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

private struct DJConnectReleaseNotes: Decodable {
    let name: String?
    let body: String?
}

private struct DJConnectReleaseNotesFetchResult {
    let release: DJConnectReleaseNotes
    let url: URL
    let statusCode: Int
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

public enum DJConnectPermissionRequestAction: Equatable, Sendable {
    case alreadyGranted
    case requestSystemPrompt
    case openSystemSettings
}

private enum DJConnectPendingPermissionRequest {
    case appPermissions
    case voiceRecording
}

public struct DJConnectUserNotice: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public var text: String
}

public enum DJConnectAskDJMessageRole: String, Codable, Equatable, Sendable {
    case user
    case dj
}

public enum DJConnectAskDJMessageStatus: String, Codable, Equatable, Sendable {
    case sending
    case sent
    case failed
}

public enum DJConnectAskDJLocalMessageKind: String, Codable, Equatable, Sendable {
    case assistant
    case system
}

public enum DJConnectAskDJAudioPlaybackState: Equatable, Sendable {
    case idle
    case loading(URL)
    case playing(URL)
}

public struct DJConnectAskDJMessage: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var serverID: String?
    public var clientMessageID: String?
    public var role: DJConnectAskDJMessageRole
    public var messageKind: DJConnectAskDJLocalMessageKind
    public var origin: String?
    public var text: String
    public var images: [DJConnectResponseImage]
    public var links: [DJConnectResponseLink]
    public var playbackActions: [DJConnectAskDJPlaybackAction]
    public var audioURL: URL?
    public var status: DJConnectAskDJMessageStatus?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        serverID: String? = nil,
        clientMessageID: String? = nil,
        role: DJConnectAskDJMessageRole,
        messageKind: DJConnectAskDJLocalMessageKind = .assistant,
        origin: String? = nil,
        text: String,
        images: [DJConnectResponseImage] = [],
        links: [DJConnectResponseLink] = [],
        playbackActions: [DJConnectAskDJPlaybackAction] = [],
        audioURL: URL? = nil,
        status: DJConnectAskDJMessageStatus? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.serverID = serverID
        self.clientMessageID = clientMessageID
        self.role = role
        self.messageKind = messageKind
        self.origin = origin
        self.text = text
        self.images = images
        self.links = links
        self.playbackActions = playbackActions
        self.audioURL = audioURL
        self.status = status
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case serverID = "server_id"
        case clientMessageID = "client_message_id"
        case role
        case messageKind = "message_kind"
        case origin
        case text
        case images
        case links
        case playbackActions = "playback_actions"
        case audioURL = "audio_url"
        case status
        case createdAt = "created_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        serverID = try container.decodeIfPresent(String.self, forKey: .serverID)
        clientMessageID = try container.decodeIfPresent(String.self, forKey: .clientMessageID)
        role = try container.decode(DJConnectAskDJMessageRole.self, forKey: .role)
        messageKind = try container.decodeIfPresent(DJConnectAskDJLocalMessageKind.self, forKey: .messageKind) ?? .assistant
        origin = try container.decodeIfPresent(String.self, forKey: .origin)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        images = try container.decodeIfPresent([DJConnectResponseImage].self, forKey: .images) ?? []
        links = try container.decodeIfPresent([DJConnectResponseLink].self, forKey: .links) ?? []
        playbackActions = try container.decodeIfPresent([DJConnectAskDJPlaybackAction].self, forKey: .playbackActions) ?? []
        audioURL = try container.decodeIfPresent(URL.self, forKey: .audioURL)
        status = try container.decodeIfPresent(DJConnectAskDJMessageStatus.self, forKey: .status)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(serverID, forKey: .serverID)
        try container.encodeIfPresent(clientMessageID, forKey: .clientMessageID)
        try container.encode(role, forKey: .role)
        try container.encode(messageKind, forKey: .messageKind)
        try container.encodeIfPresent(origin, forKey: .origin)
        try container.encode(text, forKey: .text)
        try container.encode(images, forKey: .images)
        try container.encode(links, forKey: .links)
        try container.encode(playbackActions, forKey: .playbackActions)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
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
    @Published public var pairingStatus: DJConnectPairingStatus = .unpaired {
        didSet {
            updateBonjourAdvertisingState()
            if startBackgroundTasks, oldValue != .paired, pairingStatus == .paired {
                schedulePairedRefresh(reason: "Pairing became online")
                updateNowPlayingPollTimer()
            } else if pairingStatus != .paired {
                nowPlayingPollTask?.cancel()
                nowPlayingPollTask = nil
                stopWakeWordListening()
            }
            updateWakeWordListeningForAvailability()
        }
    }
    @Published public var isConnected = false {
        didSet { updateWakeWordListeningForAvailability() }
    }
    @Published public var isPairing = false {
        didSet { updateBonjourAdvertisingState() }
    }
    @Published public var isRefreshing = false
    @Published public private(set) var isLoadingOutputs = false
    @Published public private(set) var isLoadingQueue = false
    @Published public private(set) var isLoadingPlaylists = false
    @Published public var backendAvailable = true {
        didSet {
            if backendAvailable {
                backendRecoveryTask?.cancel()
                backendRecoveryTask = nil
            }
            updateWakeWordListeningForAvailability()
        }
    }
    @Published public var updateRequiredMessage: String?
    @Published public var pairingMessage: String?
    @Published public var userNotice: DJConnectUserNotice?
    @Published public var playback: DJConnectPlayback?
    @Published public var queue: [String] = []
    @Published public var playlists: [String] = []
    @Published public var availableOutputs: [DJConnectOutputDevice] = []
    @Published public var queueItems: [DJConnectQueueItem] = []
    @Published public private(set) var loadingQueueItemID: String?
    @Published public private(set) var loadingQueueItemIndex: Int?
    @Published public private(set) var loadingPlaylistID: String?
    @Published public var queueContext: String?
    @Published public var playlistItems: [DJConnectPlaylist] = []
    @Published public var selectedOutput = "Not selected"
    @Published public var djResponseText = ""
    @Published public private(set) var askDJMessages: [DJConnectAskDJMessage] = []
    @Published public private(set) var askDJScrollRequestID: UUID?
    @Published public var askDJDraft = ""
    @Published public private(set) var isSendingAskDJText = false
    @Published public private(set) var isRequestingAskDJIdleSuggestion = false
    @Published public private(set) var playingAskDJActionID: String?
    @Published public private(set) var isClearingAskDJHistory = false
    @Published public private(set) var isCheckingAskDJHistoryState = true
    @Published public var askDJErrorMessage: String?
    @Published public private(set) var askDJToast: DJConnectUserNotice?
    @Published public private(set) var askDJAudioPlaybackState: DJConnectAskDJAudioPlaybackState = .idle
    @Published public private(set) var transientAskDJListeningMessage: DJConnectAskDJMessage?
    @Published public private(set) var transientAskDJMoodMessage: DJConnectAskDJMessage?
    @Published public var askDJMood = 50.0 {
        didSet { defaults.set(askDJMood, forKey: askDJMoodKey) }
    }
    @Published public var isRecordingVoice = false
    @Published public var voiceStatus: DJConnectVoiceStatus = .idle
    @Published public var voiceErrorMessage: String?
    @Published public var logLevel = "info" {
        didSet {
            defaults.set(logLevel, forKey: logLevelKey)
            log(.info, "Log level changed to \(logLevel)")
        }
    }
    @Published public var language = "en"
    @Published public var voiceEnabled = true {
        didSet { updateWakeWordListeningForAvailability() }
    }
    @Published public var localResponseAudioEnabled = true
    @Published public var isDemoMode = false {
        didSet { updateBonjourAdvertisingState() }
    }
    @Published public private(set) var isMonkeyTestingMode = false
    @Published public var wakeWordEnabled = false {
        didSet {
            wakeWordEnabled ? startWakeWordListening() : stopWakeWordListening()
        }
    }
    @Published public var wakeWordPhrase = "Hey DJ" {
        didSet {
            defaults.set(wakeWordPhrase, forKey: wakeWordPhraseKey)
            if wakeWordEnabled, wakeWordStatus == .listening {
                scheduleWakeWordPhraseRestart()
            }
        }
    }
    @Published public private(set) var wakeWordStatus: DJConnectWakeWordStatus = .idle
    @Published public private(set) var microphonePermissionStatus: DJConnectPermissionStatus = .unknown
    @Published public private(set) var speechPermissionStatus: DJConnectPermissionStatus = .unknown
    @Published public private(set) var notificationPermissionStatus: DJConnectPermissionStatus = .unknown
    @Published public private(set) var localNetworkPermissionStatus: DJConnectPermissionStatus = .unknown
    @Published public private(set) var isRequestingPermissions = false
    @Published public var isShowingPermissionExplanation = false
    @Published public var isShowingWelcome = false
    @Published public var isShowingCrashReportPrompt = false
    @Published public var isShowingWakeWordActivationPrompt = false
    @Published public var isShowingTokenStorageError = false
    @Published public var isShowingWhatsNew = false
    @Published public private(set) var whatsNewTitle = ""
    @Published public private(set) var whatsNewBody = ""
    @Published public private(set) var isLoadingWhatsNew = false
    @Published public private(set) var isShowingPairingSuccess = false
    @Published public private(set) var isPairingScreenDismissed = false
    @Published public private(set) var localDeviceAPIURL: String?
    @Published public private(set) var isLocalNetworkAvailable = false
    @Published public private(set) var hasEvaluatedLocalNetwork = false
    @Published public private(set) var diagnosticLogLines: [DJConnectDiagnosticLogLine] = []

    @Published public private(set) var identity: DJConnectIdentity

    private let logger: Logger
    private var pairingTask: Task<Void, Never>?
    private var scheduledPairingTask: Task<Void, Never>?
    private var volumeCommandTask: Task<Void, Never>?
    private var playbackProgressTask: Task<Void, Never>?
    private var nowPlayingPollTask: Task<Void, Never>?
    private var startupRefreshTask: Task<Void, Never>?
    private var backendRecoveryTask: Task<Void, Never>?
    private var pendingSelectedOutput: String?
    private var pendingVolumePercent: Int?
    private var pendingSeekTargetMS: Int?
    private var seekCommandTask: Task<Void, Never>?
    private var isAppInForeground = true
    private var lastFullRefreshAt: Date?
    private var lastBackendCollectionsRefreshAt: Date?
    private var localDeviceAPI: DJConnectLocalDeviceAPI?
    private var askDJOnAirHLSDirectory: URL?
    private let networkMonitor = NWPathMonitor()
    private let networkMonitorQueue = DispatchQueue(label: "dev.djconnect.app.network")
    private var shouldShowWakeWordPromptAfterPairingScreen = false
    #if canImport(AVFoundation)
    private var voiceRecorder: AVAudioRecorder?
    private var voiceRecordingURL: URL?
    private var voiceStartTask: Task<Void, Never>?
    private var responseAudioPlayer: AVPlayer?
    private var responseAudioPlaybackTask: Task<Void, Never>?
    private var responseSpeechSynthesizer: AVSpeechSynthesizer?
    #endif
    #if canImport(Speech) && canImport(AVFoundation)
    private var wakeAudioEngine: AVAudioEngine?
    private var wakeRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var wakeRecognitionTask: SFSpeechRecognitionTask?
    private var wakeWordRestartTask: Task<Void, Never>?
    private var wakeWordPhraseRestartTask: Task<Void, Never>?
    private var wakeWordCaptureTask: Task<Void, Never>?
    private var isStoppingWakeWord = false
    #endif
    private let defaults: UserDefaults
    private let tokenStore: DJConnectTokenStore
    private let startLocalAPI: Bool
    private let startBackgroundTasks: Bool
    private let monkeyTestingMode: Bool
    private let diagnosticLogFileURL: URL?
    private static let protocolVersion = "3.1.42"
    private static let defaultHomeAssistantURL = "http://homeassistant.local:8123"
    private let appVersion = DJConnectAppModel.protocolVersion
    private let installIDKey = "DJConnectInstallID"
    private let homeAssistantURLKey = "DJConnectHomeAssistantURL"
    private let haLocalURLKey = "DJConnectHALocalURL"
    private let assistPipelineIDKey = "DJConnectAssistPipelineID"
    private let pairingTokenKey = "DJConnectPairingToken"
    private let localDeviceAPIURLKey = "DJConnectLocalDeviceAPIURL"
    private let logLevelKey = "DJConnectLogLevel"
    private let demoModeKey = "DJConnectDemoMode"
    private let askDJMoodKey = "DJConnectAskDJMood"
    private let wakeWordPhraseKey = "DJConnectWakeWordPhrase"
    private let askDJMessagesKey = "DJConnectAskDJMessages"
    private let askDJHistoryRevisionKey = "DJConnectAskDJHistoryRevision"
    private let askDJClearRevisionKey = "DJConnectAskDJClearRevision"
    private let askDJAudioResponseModeKey = "DJConnectAskDJAudioResponseMode"
    private let pushTokenKey = "DJConnectPushToken"
    private let registeredPushTokenKey = "DJConnectRegisteredPushToken"
    private let registeredPushEnvironmentKey = "DJConnectRegisteredPushEnvironment"
    private let wakeWordPromptDismissedKey = "DJConnectWakeWordPromptDismissed"
    private let welcomeSeenKey = "DJConnectWelcomeSeen"
    private let lastSeenAppVersionKey = "DJConnectLastSeenAppVersion"
    private let cleanShutdownKey = "DJConnectCleanShutdown"
    private let crashPromptPendingKey = "DJConnectCrashPromptPending"
    private let maxDiagnosticLogLines = 120
    private let maxPersistentDiagnosticLogLines = 500
    private let maxPersistentDiagnosticLogFileBytes = 128 * 1024
    private let minimumAutomaticRefreshInterval: TimeInterval = 8
    private let backendCollectionsRefreshInterval: TimeInterval = 30
    private let nowPlayingPollInterval: UInt64 = 10
    private let progressTimerNetworkRefreshInterval = 60
    private let askDJHistorySyncInterval: UInt64 = 8_000_000_000
    private var hasRequestedAskDJIdleSuggestion = false
    private var hasRequestedAskDJNotificationPermission = false
    private var pendingPermissionRequest: DJConnectPendingPermissionRequest?
    private var shouldBypassPermissionExplanationOnce = false

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

    public var askDJMoodInt: Int {
        max(0, min(100, Int(askDJMood.rounded())))
    }

    public var askDJMoodStepIndex: Int {
        switch askDJMoodInt {
        case 0...24:
            return 0
        case 25...59:
            return 1
        case 60...84:
            return 2
        default:
            return 3
        }
    }

    public var askDJMoodSteps: [(label: String, value: Int)] {
        [
            ("Chill", 0),
            ("Groove", 35),
            ("Energy", 70),
            ("Party", 100)
        ]
    }

    public var askDJMoodLabel: String {
        askDJMoodSteps[askDJMoodStepIndex].label
    }

    public func setAskDJMoodStep(_ index: Int) {
        let clampedIndex = max(0, min(askDJMoodSteps.count - 1, index))
        guard clampedIndex != askDJMoodStepIndex else {
            return
        }
        askDJMood = Double(askDJMoodSteps[clampedIndex].value)
        showMoodChangedMessage()
    }

    private var hasActiveNowPlaying: Bool {
        playback?.hasPlayback == true
            || playback?.isPlaying == true
            || playback?.trackName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    public var version: String {
        appVersion
    }

    private var releaseNotesLanguageCode: String {
        Self.normalizedReleaseNotesLanguageCode(language)
    }

    public var hasStoredPairingToken: Bool {
        if pairingStatus == .paired || isShowingTokenStorageError {
            return true
        }
        return (try? tokenStore.loadToken())?.isEmpty == false
    }

    public var isRuntimeCompatible: Bool {
        updateRequiredMessage == nil
    }

    public var canUsePlaybackFeatures: Bool {
        isDemoMode || (pairingStatus == .paired && backendAvailable && isRuntimeCompatible && (!hasEvaluatedLocalNetwork || isLocalNetworkAvailable))
    }

    public var localNetworkRequirementMessage: String? {
        (!hasEvaluatedLocalNetwork || isLocalNetworkAvailable) ? nil : localized(
            english: "Local Wi-Fi/LAN is required. Connect this device to the same local network as Home Assistant.",
            dutch: "Lokaal WiFi/LAN is vereist. Verbind dit apparaat met hetzelfde lokale netwerk als Home Assistant."
        )
    }

    public var shouldShowPairingScreen: Bool {
        !isDemoMode
            && !isShowingWelcome
            && !isShowingCrashReportPrompt
            && !isShowingTokenStorageError
            && !isPairingScreenDismissed
            && (pairingStatus != .paired || isShowingPairingSuccess)
    }

    public init(
        playback: DJConnectPlayback? = nil,
        defaults: UserDefaults = .standard,
        tokenStore: DJConnectTokenStore? = nil,
        startLocalAPI: Bool = true,
        startBackgroundTasks: Bool = true,
        monkeyTestingMode: Bool = false,
        diagnosticLogDirectory: URL? = nil
    ) {
        self.defaults = defaults
        self.startLocalAPI = startLocalAPI
        self.startBackgroundTasks = startBackgroundTasks
        self.monkeyTestingMode = monkeyTestingMode
        self.isMonkeyTestingMode = monkeyTestingMode
        self.diagnosticLogFileURL = (diagnosticLogDirectory ?? Self.defaultDiagnosticLogDirectory())?
            .appendingPathComponent("djconnect.log")
        let resolvedTokenStore = tokenStore ?? DJConnectUserDefaultsTokenStore()
        let hasExistingInstallID = defaults.string(forKey: "DJConnectInstallID")?.isEmpty == false
        if !hasExistingInstallID && !monkeyTestingMode && resolvedTokenStore is DJConnectUserDefaultsTokenStore {
            try? resolvedTokenStore.clearToken()
        }
        self.tokenStore = resolvedTokenStore
        self.identity = Self.makeIdentity(defaults: defaults)
        self.logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "dev.djconnect",
            category: "DJConnectApp"
        )
        self.playback = playback
        self.homeAssistantURL = defaults.string(forKey: homeAssistantURLKey) ?? Self.defaultHomeAssistantURL
        self.haLocalURL = defaults.string(forKey: haLocalURLKey) ?? ""
        self.assistPipelineID = defaults.string(forKey: assistPipelineIDKey) ?? ""
        self.localDeviceAPIURL = defaults.string(forKey: localDeviceAPIURLKey)
        self.pairingToken = defaults.string(forKey: pairingTokenKey) ?? Self.generatePairingToken()
        self.language = Self.defaultLanguage()
        self.selectedOutput = Self.noOutputName(for: language)
        self.logLevel = defaults.string(forKey: logLevelKey) ?? "info"
        self.askDJMood = defaults.object(forKey: askDJMoodKey) == nil ? 50.0 : defaults.double(forKey: askDJMoodKey)
        self.askDJMessages = Self.loadAskDJMessages(defaults: defaults, key: askDJMessagesKey)
        loadPersistentDiagnosticLog()
        defaults.removeObject(forKey: demoModeKey)
        self.isDemoMode = false
        if monkeyTestingMode {
            self.isDemoMode = true
            self.isShowingWelcome = false
            defaults.set(true, forKey: welcomeSeenKey)
        }
        self.wakeWordEnabled = false
        self.wakeWordPhrase = defaults.string(forKey: wakeWordPhraseKey) ?? "Hey DJ"
        if !monkeyTestingMode {
            self.isShowingWelcome = !defaults.bool(forKey: welcomeSeenKey)
        }
        prepareWhatsNewPrompt()
        let previousLaunchMayHaveCrashed = defaults.object(forKey: cleanShutdownKey) != nil
            && defaults.bool(forKey: cleanShutdownKey) == false
        self.isShowingCrashReportPrompt = !Self.isRunningUnderDebugger
            && (previousLaunchMayHaveCrashed || defaults.bool(forKey: crashPromptPendingKey))
        if monkeyTestingMode {
            self.isShowingCrashReportPrompt = false
        }
        defaults.set(false, forKey: cleanShutdownKey)
        defaults.set(isShowingCrashReportPrompt, forKey: crashPromptPendingKey)
        defaults.set(pairingToken, forKey: pairingTokenKey)
        do {
            if monkeyTestingMode {
                clearAskDJHistoryLocally()
                applyDemoState()
                log(.info, "App started in non-destructive monkey test mode")
            } else if let existingToken = try resolvedTokenStore.loadToken(), !existingToken.isEmpty {
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
            applyTokenStorageFailure(error)
        }
        refreshPermissionStatuses()
        registerStoredPushTokenIfPossible()
        if startLocalAPI, !monkeyTestingMode {
            startLocalDeviceAPI()
        }
        startNetworkMonitor()
    }

    private func prepareWhatsNewPrompt() {
        guard !monkeyTestingMode else {
            defaults.set(appVersion, forKey: lastSeenAppVersionKey)
            return
        }
        guard defaults.bool(forKey: welcomeSeenKey) else {
            defaults.set(appVersion, forKey: lastSeenAppVersionKey)
            return
        }
        guard defaults.string(forKey: lastSeenAppVersionKey) != appVersion else {
            return
        }

        whatsNewTitle = localized(english: "What's New in DJConnect \(appVersion)", dutch: "Wat is er nieuw in DJConnect \(appVersion)")
        whatsNewBody = localized(
            english: "Loading release notes...",
            dutch: "Release notes laden..."
        )
        isShowingWhatsNew = true
        if startBackgroundTasks {
            Task { [weak self] in
                await self?.loadWhatsNewReleaseNotes()
            }
        }
    }

    public func dismissWhatsNew() {
        defaults.set(appVersion, forKey: lastSeenAppVersionKey)
        isShowingWhatsNew = false
    }

    public func loadWhatsNewReleaseNotes() async {
        await MainActor.run {
            isLoadingWhatsNew = true
        }
        let fallback = localized(
            english: "Release notes could not be loaded. See https://djconnect.dev for more information.",
            dutch: "Release notes konden niet worden geladen. Bekijk https://djconnect.dev voor meer informatie."
        )

        let candidateURLs = [
            DJConnectAppModel.publicReleaseNotesURL(version: appVersion, clientType: identity.clientType, language: releaseNotesLanguageCode),
            DJConnectAppModel.publicReleaseNotesURL(version: appVersion, clientType: identity.clientType),
            DJConnectAppModel.githubReleaseNotesURL(version: appVersion, clientType: identity.clientType)
        ].compactMap { $0 }

        guard !candidateURLs.isEmpty else {
            await MainActor.run {
                whatsNewBody = fallback
                isLoadingWhatsNew = false
            }
            return
        }

        do {
            let result = try await fetchReleaseNotes(from: candidateURLs)
            log(.debug, "Release notes loaded from \(result.url.host ?? "unknown host")\(result.url.path) -> HTTP \(result.statusCode)")
            let body = (result.release.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let title = (result.release.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let localizedBody = localizedReleaseNotesBody(body)
            await MainActor.run {
                whatsNewTitle = title.isEmpty
                    ? whatsNewTitle
                    : title
                whatsNewBody = localizedBody.isEmpty ? fallback : localizedBody
                isLoadingWhatsNew = false
            }
        } catch {
            log(.warning, "Release notes fetch failed: \(error.localizedDescription)")
            await MainActor.run {
                whatsNewBody = fallback
                isLoadingWhatsNew = false
            }
        }
    }

    private func fetchReleaseNotes(from urls: [URL]) async throws -> DJConnectReleaseNotesFetchResult {
        var lastError: Error?
        for url in urls {
            do {
                var request = URLRequest(url: url)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 8
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                log(.debug, "Release notes GET \(url.path) -> HTTP \(httpResponse.statusCode)")
                guard (200..<300).contains(httpResponse.statusCode) else {
                    throw DJConnectError.server(statusCode: httpResponse.statusCode, message: "release notes unavailable")
                }
                let release = try JSONDecoder().decode(DJConnectReleaseNotes.self, from: data)
                return DJConnectReleaseNotesFetchResult(release: release, url: url, statusCode: httpResponse.statusCode)
            } catch {
                lastError = error
                log(.debug, "Release notes candidate failed: \(url.absoluteString) - \(error.localizedDescription)")
            }
        }
        throw lastError ?? DJConnectError.backendUnavailable(message: "release notes unavailable")
    }

    private func localizedReleaseNotesBody(_ body: String) -> String {
        guard releaseNotesLanguageCode == "nl", appVersion == "3.1.30" else {
            return body
        }
        let normalizedBody = body.lowercased()
        guard normalizedBody.contains("### changed")
            || normalizedBody.contains("added community documentation")
            || normalizedBody.contains("renamed the chat bootstrap") else {
            return body
        }
        return """
        ### Gewijzigd

        - Community-documentatie toegevoegd met een Code of Conduct en een privé beveiligingsmeldpunt via `security@djconnect.dev`.
        - De releasecyclus aangescherpt: de Codex chat-bootstrap moet bij iedere release actueel blijven.
        - De chat-bootstrap hernoemd naar `CHAT_BOOTSTRAP.md`, zodat nieuwe repo-sessies duidelijker starten.
        """
    }

    public func dismissWelcome() {
        defaults.set(true, forKey: welcomeSeenKey)
        isShowingWelcome = false
    }

    public func retryTokenStorageAccess() {
        do {
            if let existingToken = try tokenStore.loadToken(), !existingToken.isEmpty {
                isShowingTokenStorageError = false
                pairingStatus = .paired
                isConnected = true
                backendAvailable = true
                pairingMessage = localized(
                    english: "DJConnect token restored.",
                    dutch: "DJConnect-token hersteld."
                )
                log(.info, "Token storage access restored")
                if startBackgroundTasks {
                    schedulePairedRefresh(reason: "Refreshing after token storage restore")
                }
            } else {
                isShowingTokenStorageError = false
                pairingStatus = .unpaired
                isConnected = false
                pairingMessage = localized(
                    english: "No DJConnect token found. Pair again to continue.",
                    dutch: "Geen DJConnect-token gevonden. Koppel opnieuw om door te gaan."
                )
                log(.warning, "Token storage access restored but no DJConnect bearer token was found")
            }
        } catch {
            applyTokenStorageFailure(error)
        }
    }

    private func applyTokenStorageFailure(_ error: Error) {
        isShowingTokenStorageError = true
        isConnected = false
        pairingStatus = .stale
        backendAvailable = false
        pairingMessage = localized(
            english: "DJConnect could not read the saved device token.",
            dutch: "DJConnect kon het opgeslagen device-token niet lezen."
        )
        log(.error, "Token storage failed: \(error.localizedDescription)")
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
        clearAskDJHistoryLocally()
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
        isAppInForeground = true
        defaults.set(false, forKey: cleanShutdownKey)
        restartLocalDeviceAPIAfterForegroundResumeIfNeeded()
        refreshPermissionStatuses()
        resumeWakeWordListeningIfNeeded()
        updatePlaybackProgressTimer()
        updateNowPlayingPollTimer()
        guard pairingStatus == .paired, !isDemoMode else {
            return
        }
        log(.debug, "App became active; scheduling playback refresh")
        schedulePairedRefresh(reason: "Resume Now Playing refresh completed")
    }

    public func markInactiveSession() {
        isAppInForeground = false
        scheduledPairingTask?.cancel()
        scheduledPairingTask = nil
        startupRefreshTask?.cancel()
        startupRefreshTask = nil
        backendRecoveryTask?.cancel()
        backendRecoveryTask = nil
        pausePairingWaitForBackgroundIfNeeded()
        playbackProgressTask?.cancel()
        playbackProgressTask = nil
        nowPlayingPollTask?.cancel()
        nowPlayingPollTask = nil
        stopWakeWordListening()
        stopLocalDeviceAPIForBackgroundIfNeeded()
        markCleanShutdown()
        log(.debug, "App left foreground; paused wakeword, refresh tasks, local progress timer, Now Playing poll, and iOS local API when applicable")
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

    public func feedbackIssueURL() -> URL? {
        var components = URLComponents(string: "https://github.com/pcvantol/djconnect/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: "DJConnect app feedback"),
            URLQueryItem(name: "body", value: feedbackIssueBody())
        ]
        return components?.url
    }

    public func feedbackIssueBody() -> String {
        """
        ## DJConnect app feedback

        Please describe your feedback or feature request:


        ```text
        version: \(appVersion)
        client_type: \(identity.clientType.rawValue)
        device_id: \(identity.deviceID)
        pairing_status: \(pairingStatus.rawValue)
        demo_mode: \(isDemoMode)
        language: \(language)
        ```
        """
    }

    deinit {
        networkMonitor.cancel()
        scheduledPairingTask?.cancel()
        pairingTask?.cancel()
        volumeCommandTask?.cancel()
        seekCommandTask?.cancel()
        playbackProgressTask?.cancel()
        startupRefreshTask?.cancel()
        localDeviceAPI?.stop()
    }

    public func stopLocalDeviceAPI() {
        localDeviceAPI?.stop()
        localDeviceAPI = nil
    }

    private var shouldPauseLocalDeviceAPIWhenInactive: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    private func restartLocalDeviceAPIAfterForegroundResumeIfNeeded() {
        guard shouldPauseLocalDeviceAPIWhenInactive, startLocalAPI, !monkeyTestingMode else {
            return
        }
        guard localDeviceAPI == nil else {
            return
        }
        log(.debug, "Restarting local device API after foreground resume")
        startLocalDeviceAPI()
    }

    private func stopLocalDeviceAPIForBackgroundIfNeeded() {
        guard shouldPauseLocalDeviceAPIWhenInactive else {
            return
        }
        guard localDeviceAPI != nil else {
            return
        }
        log(.debug, "Stopping local device API while iOS app is backgrounded")
        stopLocalDeviceAPI()
    }

    private func pausePairingWaitForBackgroundIfNeeded() {
        guard shouldPauseLocalDeviceAPIWhenInactive else {
            return
        }
        pairingTask?.cancel()
        pairingTask = nil
        guard pairingStatus == .pairing else {
            return
        }
        isPairing = false
        pairingStatus = .unpaired
        pairingMessage = localized(
            english: "Pairing paused while DJConnect is in the background.",
            dutch: "Koppeling gepauzeerd terwijl DJConnect op de achtergrond staat."
        )
    }

    public func schedulePairingWait() {
        guard pairingStatus != .paired else {
            log(.debug, "Ignoring scheduled pairing because device is already paired")
            return
        }

        log(.debug, "Scheduling pairing retry after Home Assistant URL edit")
        scheduledPairingTask?.cancel()
        scheduledPairingTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                guard let self else { return }
                self.restartLocalDeviceAPI()
                self.startPairingWait()
            }
        }
    }

    public func confirmPairingHomeAssistantURL() {
        guard pairingStatus != .paired else {
            log(.debug, "Ignoring Home Assistant URL confirmation because device is already paired")
            return
        }
        log(.info, "User action: confirm Home Assistant URL for pairing")
        restartLocalDeviceAPI()
        startPairingWait()
    }

    public func recoverPairingClientAPIIfNeeded() {
        guard !isDemoMode, pairingStatus != .paired else {
            return
        }
        guard localDeviceAPI == nil || localDeviceAPIURL?.isEmpty != false else {
            startPairingWait()
            return
        }
        log(.warning, "Recovering pairing screen because Client address is missing")
        restartLocalDeviceAPI()
        startPairingWait()
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
        guard !hasEvaluatedLocalNetwork || isLocalNetworkAvailable else {
            log(.warning, "Pairing wait cannot start because local network is unavailable")
            pairingStatus = .unpaired
            isConnected = false
            isPairing = false
            pairingMessage = localNetworkRequirementMessage
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
            english: "Waiting for Home Assistant to accept code \(pairingToken). If the client is not discovered, allow incoming local network connections for DJConnect in macOS firewall or security software.",
            dutch: "Wachten tot Home Assistant code \(pairingToken) accepteert. Wordt de client niet gevonden, sta inkomende lokale netwerkverbindingen voor DJConnect toe in macOS firewall of beveiligingssoftware."
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
                registerStoredPushTokenIfPossible()
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
        unregisterPushNotifications()
        try? tokenStore.clearToken()
        isDemoMode = false
        defaults.removeObject(forKey: demoModeKey)
        clearStoredHomeAssistantURLs()
        clearPinnedLocalDeviceAPIURL()
        defaults.removeObject(forKey: installIDKey)
        defaults.removeObject(forKey: pushTokenKey)
        defaults.removeObject(forKey: registeredPushTokenKey)
        defaults.removeObject(forKey: registeredPushEnvironmentKey)
        identity = Self.makeIdentity(defaults: defaults)
        clearRuntimeState()
        clearAskDJHistoryLocally()
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
            await runRefresh(reason: "Refresh completed", notifyUserOnError: true, forceCollections: true)
        }
    }

    private func runRefresh(
        reason: String,
        notifyUserOnError: Bool = false,
        forceCollections: Bool = false,
        allowThrottle: Bool = false
    ) async {
        guard !isRefreshing else {
            log(.debug, "Refresh ignored because one is already running")
            return
        }
        if allowThrottle, let lastFullRefreshAt, Date().timeIntervalSince(lastFullRefreshAt) < minimumAutomaticRefreshInterval {
            log(.debug, "Automatic refresh throttled")
            return
        }
        if isDemoMode {
            log(.debug, "Demo refresh requested")
            isRefreshing = true
            applyDemoState()
            isRefreshing = false
            lastFullRefreshAt = Date()
            log(.info, reason)
            return
        }
        log(.debug, "Manual refresh requested")
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await refreshStatusWithFallback()
            lastFullRefreshAt = Date()
            await refreshBackendCollections(force: forceCollections)
            log(.info, reason)
        } catch let error as DJConnectError {
            log(.warning, "Refresh failed: \(Self.describe(error))")
            apply(error: error)
            if notifyUserOnError {
                emitUserConnectionNotice(for: error)
            }
        } catch {
            log(.error, "Refresh failed unexpectedly: \(error.localizedDescription)")
            applyConnectionUnavailableState(message: error.localizedDescription)
            if notifyUserOnError {
                emitUserConnectionNotice()
            }
        }
    }

    private func schedulePairedRefresh(reason: String) {
        startupRefreshTask?.cancel()
        startupRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else {
                return
            }
            await self?.runRefresh(reason: reason, allowThrottle: true)
            try? await Task.sleep(for: .milliseconds(1_200))
            guard !Task.isCancelled, self?.pairingStatus == .paired else {
                return
            }
            await self?.runRefresh(reason: "Startup Now Playing refresh completed", allowThrottle: true)
        }
    }

    private func scheduleBackendRecoveryRefresh(reason: String) {
        guard startBackgroundTasks, !isDemoMode, pairingStatus == .paired, !backendAvailable else {
            return
        }
        guard backendRecoveryTask == nil else {
            return
        }
        backendRecoveryTask = Task { [weak self] in
            var delay: UInt64 = 2_000_000_000
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled, let self else {
                    return
                }
                guard self.pairingStatus == .paired, !self.isDemoMode, !self.backendAvailable else {
                    self.backendRecoveryTask = nil
                    return
                }
                self.log(.debug, reason)
                await self.runRefresh(reason: "Playback backend recovery refresh completed")
                delay = min(delay * 2, 10_000_000_000)
            }
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
        if shouldBlockPlaybackStart(command: command, play: play) {
            log(.warning, "Command \(command) blocked because no output device is selected")
            userNotice = DJConnectUserNotice(text: localized(
                english: "Select an output device first",
                dutch: "Kies eerst een uitvoerapparaat"
            ))
            return
        }
        log(.info, "Sending playback command: \(command)")
        if command == "next" || command == "previous" {
            pendingSeekTargetMS = nil
            if var updated = playback {
                updated.progressMS = 0
                playback = updated
            }
        }
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

    public func commitSeek(to milliseconds: Int) {
        let duration = max(playback?.durationMS ?? milliseconds, 0)
        let target = min(max(milliseconds, 0), duration)
        let currentProgress = playback?.progressMS ?? 0
        let delta = target - currentProgress
        guard abs(delta) >= 500 else {
            return
        }
        log(.debug, "User action: seek to \(target)ms")
        pendingSeekTargetMS = target
        var updated = playback ?? DJConnectPlayback()
        updated.progressMS = target
        playback = updated
        seekCommandTask?.cancel()
        seekCommandTask = Task { [weak self] in
            guard let self else {
                return
            }
            await self.performCommand("seek_relative", value: .int(delta))
            try? await Task.sleep(for: .milliseconds(850))
            guard !Task.isCancelled else {
                return
            }
            await self.performCommand("status")
            if self.pendingSeekTargetMS == target {
                self.pendingSeekTargetMS = nil
            }
        }
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
        if Self.isSyntheticOutput(output) {
            log(.info, "Selecting local output option \(output.name)")
            pendingSelectedOutput = nil
            return
        }
        log(.info, "Selecting output \(output.name)")
        sendPlaybackCommand("set_output", value: .string(output.name), play: true)
    }

    public func startPlaylist(_ playlist: DJConnectPlaylist) {
        log(.debug, "User action: start playlist")
        log(.info, "Starting playlist \(playlist.name)")
        loadingPlaylistID = playlist.id
        Task {
            let didStart = await performCommand("start_playlist", value: .string(playlist.commandValue), play: true)
            guard didStart, pairingStatus == .paired else {
                loadingPlaylistID = nil
                return
            }
            try? await Task.sleep(for: .milliseconds(1_100))
            guard pairingStatus == .paired else {
                loadingPlaylistID = nil
                return
            }
            await runRefresh(reason: "Playlist Now Playing refresh completed")
            loadingPlaylistID = nil
        }
    }

    public func startLikedProxy() {
        log(.debug, "User action: start liked songs")
        log(.info, "Starting liked proxy flow")
        sendPlaybackCommand("start_liked_proxy", play: true)
    }

    public func canStartQueueItem(_ item: DJConnectQueueItem) -> Bool {
        item.uri?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    public func startQueueItem(_ item: DJConnectQueueItem, at index: Int? = nil) {
        log(.debug, "User action: start queue item")
        guard let uri = item.uri, !uri.isEmpty else {
            log(.warning, "Queue item \(item.title) cannot start because it has no URI")
            return
        }
        var payload = [
            "uri": uri,
            "title": item.title
        ]
        if let contextURI = resolvedQueueContext, !contextURI.isEmpty {
            payload["context_uri"] = contextURI
            if Self.queueContextSupportsOffset(contextURI) {
                payload["offset_uri"] = uri
            }
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
            await refreshQueue()
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

    public func sendAskDJText() {
        let text = askDJDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSendingAskDJText else {
            return
        }
        if isDemoMode {
            askDJDraft = ""
            askDJErrorMessage = nil
            appendAskDJMessage(role: .user, text: text, status: .sent)
            appendAskDJMessage(role: .dj, text: demoAskDJResponse)
            notifyAskDJResponse(demoAskDJResponse)
            return
        }
        guard canUsePlaybackFeatures else {
            askDJErrorMessage = localized(
                english: "Pair with Home Assistant before using Ask DJ.",
                dutch: "Koppel eerst met Home Assistant voordat je Ask DJ gebruikt."
            )
            return
        }

        askDJDraft = ""
        askDJErrorMessage = nil
        let clientMessageID = UUID().uuidString
        let messageID = appendAskDJMessage(role: .user, text: text, clientMessageID: clientMessageID, status: .sending)
        submitAskDJText(text, userMessageID: messageID, clientMessageID: clientMessageID)
    }

    public func retryAskDJMessage(_ message: DJConnectAskDJMessage) {
        guard message.role == .user, message.status == .failed, !isSendingAskDJText else {
            return
        }
        let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }
        if isDemoMode {
            updateAskDJMessageStatus(id: message.id, status: .sent)
            appendAskDJMessage(role: .dj, text: demoAskDJResponse)
            notifyAskDJResponse(demoAskDJResponse)
            return
        }
        askDJErrorMessage = nil
        updateAskDJMessageStatus(id: message.id, status: .sending)
        submitAskDJText(text, userMessageID: message.id, clientMessageID: message.clientMessageID ?? UUID().uuidString)
    }

    public func playAskDJRecommendation(_ action: DJConnectAskDJPlaybackAction) {
        guard playingAskDJActionID == nil else {
            return
        }
        if action.isOutputAction {
            switchAskDJOutput(action)
            return
        }
        guard canUsePlaybackFeatures else {
            askDJErrorMessage = localized(
                english: "Pair with Home Assistant before playing recommendations.",
                dutch: "Koppel eerst met Home Assistant om aanbevelingen af te spelen."
            )
            return
        }
        guard action.uri?.isEmpty == false
            || action.contextURI?.isEmpty == false
            || !action.uris.isEmpty
            || action.responseValue?.isEmpty == false else {
            showAskDJToast(localized(
                english: "This recommendation cannot be played yet",
                dutch: "Deze aanbeveling kan nog niet worden afgespeeld"
            ))
            return
        }

        playingAskDJActionID = action.id
        askDJErrorMessage = nil
        log(.info, "Sending Ask DJ Play Now recommendation action")

        Task {
            defer { playingAskDJActionID = nil }
            do {
                let response = try await playAskDJRecommendationWithFallback(action)
                apply(commandResponse: response)
                showAskDJToast(localized(english: "Playing recommendation", dutch: "Aanbeveling afspelen"))
                await refreshAfterDJResponse()
                log(.info, "Ask DJ recommendation playback started")
            } catch let error as DJConnectError {
                askDJErrorMessage = askDJErrorText(for: error)
                showAskDJToast(for: error)
                log(.warning, "Ask DJ recommendation playback failed: \(Self.describe(error))")
            } catch {
                askDJErrorMessage = askDJUnavailableText()
                showAskDJToast(localized(english: "Ask DJ is unreachable", dutch: "Ask DJ niet bereikbaar"))
                log(.error, "Ask DJ recommendation playback failed unexpectedly: \(error.localizedDescription)")
            }
        }
    }

    private func switchAskDJOutput(_ action: DJConnectAskDJPlaybackAction) {
        guard let outputDeviceID = action.outputDeviceID else {
            showAskDJToast(localized(
                english: "This output cannot be selected yet",
                dutch: "Deze uitvoer kan nog niet worden geselecteerd"
            ))
            return
        }
        guard canUsePlaybackFeatures else {
            askDJErrorMessage = localized(
                english: "Pair with Home Assistant before changing output.",
                dutch: "Koppel eerst met Home Assistant om de uitvoer te wijzigen."
            )
            return
        }

        playingAskDJActionID = action.id
        askDJErrorMessage = nil
        log(.info, "Sending Ask DJ output switch action")

        Task {
            defer { playingAskDJActionID = nil }
            do {
                let response = try await withHomeAssistantClient { client in
                    try await client.sendCommandResponse(DJConnectCommandPayload(
                        identity: identity,
                        command: "set_output",
                        value: .string(outputDeviceID)
                    ))
                }
                guard response.success else {
                    showAskDJToast(response.error ?? response.message ?? localized(
                        english: "Output could not be changed",
                        dutch: "Uitvoer kon niet worden gewijzigd"
                    ))
                    log(.warning, "Ask DJ output switch was rejected by Home Assistant")
                    return
                }
                apply(commandResponse: response)
                markAskDJOutputActionActive(outputDeviceID)
                showAskDJToast(localized(
                    english: "Output changed",
                    dutch: "Uitvoer gewijzigd"
                ))
                await refreshAfterDJResponse()
                log(.info, "Ask DJ output switch completed")
            } catch let error as DJConnectError {
                askDJErrorMessage = askDJErrorText(for: error)
                showAskDJToast(for: error)
                log(.warning, "Ask DJ output switch failed: \(Self.describe(error))")
            } catch {
                askDJErrorMessage = askDJUnavailableText()
                showAskDJToast(localized(english: "Output could not be changed", dutch: "Uitvoer kon niet worden gewijzigd"))
                log(.error, "Ask DJ output switch failed unexpectedly: \(error.localizedDescription)")
            }
        }
    }

    private func submitAskDJText(_ text: String, userMessageID: UUID?, clientMessageID: String) {
        guard !text.isEmpty else {
            return
        }

        isSendingAskDJText = true
        log(.info, "Sending Ask DJ text request")
        Task {
            defer { isSendingAskDJText = false }
            do {
                let response = try await sendAskDJTextWithFallback(text, clientMessageID: clientMessageID)
                applyAskDJMessageResponse(response, fallbackUserMessageID: userMessageID)
                let assistant = response.assistantMessage
                let responseText = userFacingDJResponseText(assistant?.text)
                    ?? localized(english: "Ask DJ completed.", dutch: "Ask DJ afgerond.")
                djResponseText = responseText
                notifyAskDJResponse(responseText)
                Task {
                    await playResponseAudioIfNeeded(resolvedAudioURL(from: assistant?.audioURL ?? response.audioURL))
                }
                await syncAskDJHistory(showErrors: false)
                await refreshAfterDJResponse()
                log(.info, "Ask DJ text request completed")
            } catch let error as DJConnectError {
                let describedError = Self.describe(error)
                askDJErrorMessage = askDJErrorText(for: error)
                showAskDJToast(for: error)
                if let userMessageID {
                    updateAskDJMessageStatus(id: userMessageID, status: .failed)
                }
                log(.warning, "Ask DJ text request failed: \(describedError)")
                if case .backendUnavailable = error {
                    await refreshAfterDJResponse()
                } else {
                    apply(error: error)
                }
            } catch {
                askDJErrorMessage = askDJUnavailableText()
                showAskDJToast(localized(english: "Ask DJ is unreachable", dutch: "Ask DJ niet bereikbaar"))
                if let userMessageID {
                    updateAskDJMessageStatus(id: userMessageID, status: .failed)
                }
                log(.error, "Ask DJ text request failed unexpectedly: \(error.localizedDescription)")
            }
        }
    }

    public func clearAskDJHistory() {
        guard !isClearingAskDJHistory else {
            return
        }
        if isDemoMode {
            clearAskDJHistoryLocally()
            return
        }
        isClearingAskDJHistory = true
        askDJErrorMessage = nil
        log(.info, "Clearing Ask DJ chat history")

        Task {
            defer { isClearingAskDJHistory = false }
            do {
                let response = try await clearAskDJHistoryWithFallback()
                applyAskDJHistory(response)
            } catch let error as DJConnectError {
                askDJErrorMessage = askDJErrorText(for: error)
                showAskDJToast(for: error)
                log(.warning, "Ask DJ clear request failed: \(Self.describe(error))")
            } catch {
                askDJErrorMessage = askDJUnavailableText()
                showAskDJToast(localized(english: "Ask DJ is unreachable", dutch: "Ask DJ niet bereikbaar"))
                log(.error, "Ask DJ clear request failed unexpectedly: \(error.localizedDescription)")
            }
        }
    }

    public func prepareAskDJHistoryForDisplay() {
        guard !isClearingAskDJHistory else {
            return
        }
        if isDemoMode {
            isCheckingAskDJHistoryState = false
            return
        }
        guard canUsePlaybackFeatures else {
            isCheckingAskDJHistoryState = false
            return
        }
        isCheckingAskDJHistoryState = true
        askDJErrorMessage = nil
        log(.debug, "Syncing Ask DJ history before display")

        Task {
            defer { isCheckingAskDJHistoryState = false }
            await syncAskDJHistory(showErrors: true)
        }
    }

    public func runAskDJHistorySyncLoop() async {
        guard !isDemoMode else {
            isCheckingAskDJHistoryState = false
            return
        }
        guard canUsePlaybackFeatures else {
            isCheckingAskDJHistoryState = false
            return
        }
        isCheckingAskDJHistoryState = true
        askDJErrorMessage = nil
        await syncAskDJHistory(showErrors: true)
        isCheckingAskDJHistoryState = false
        await requestAskDJIdleSuggestionIfNeeded()
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: askDJHistorySyncInterval)
            if Task.isCancelled {
                return
            }
            await syncAskDJHistory(showErrors: false)
        }
    }

    public func refreshAskDJHistory() async {
        guard !isDemoMode else {
            askDJErrorMessage = nil
            return
        }
        guard canUsePlaybackFeatures else {
            return
        }
        askDJErrorMessage = nil
        log(.debug, "Refreshing Ask DJ history from pull-to-refresh")
        await syncAskDJHistory(showErrors: true)
        await requestAskDJIdleSuggestionIfNeeded()
    }

    public func startVoiceRecording() {
        guard !isRecordingVoice, voiceStatus != .processing else {
            return
        }
        stopResponsePlayback(clearText: true)
        if isDemoMode {
            voiceStatus = .processing
            let demoResponse = "Ja ja, daar is hij dan, de knaller van Pearl Jam, Alive!"
            djResponseText = demoResponse
            appendAskDJMessage(role: .user, text: localized(english: "Voice request", dutch: "Stemverzoek"))
            appendAskDJMessage(role: .dj, text: demoResponse)
            notifyAskDJResponse(demoResponse)
            speakDemoResponse(demoResponse)
            voiceStatus = .idle
            log(.info, "Demo voice request completed")
            return
        }
        stopWakeWordListening()
        guard voiceEnabled else {
            dismissWakeWordListeningMessage()
            voiceStatus = .unavailable
            log(.warning, "Voice recording ignored because voice is disabled")
            resumeWakeWordListeningIfNeeded()
            return
        }
        refreshPermissionStatuses()
        if microphonePermissionStatus == .unknown, !shouldBypassPermissionExplanationOnce {
            dismissWakeWordListeningMessage()
            pendingPermissionRequest = .voiceRecording
            isShowingPermissionExplanation = true
            log(.debug, "Showing microphone permission explanation before voice recording")
            return
        }
        shouldBypassPermissionExplanationOnce = false
        guard pairingStatus == .paired else {
            dismissWakeWordListeningMessage()
            voiceStatus = .unavailable
            voiceErrorMessage = localized(
                english: "Pair with Home Assistant before using voice.",
                dutch: "Koppel eerst met Home Assistant voordat je voice gebruikt."
            )
            log(.warning, "Voice recording ignored because app is not paired")
            resumeWakeWordListeningIfNeeded()
            return
        }

        voiceStartTask?.cancel()
        isRecordingVoice = true
        voiceStatus = .listening
        voiceErrorMessage = nil

        voiceStartTask = Task { @MainActor in
            let granted = await requestMicrophoneAccess()
            guard !Task.isCancelled, isRecordingVoice else {
                return
            }
            guard granted else {
                isRecordingVoice = false
                dismissWakeWordListeningMessage()
                voiceStatus = .unavailable
                voiceErrorMessage = localized(
                    english: "Microphone access is required for push-to-talk.",
                    dutch: "Microfoontoegang is nodig voor push-to-talk."
                )
                log(.warning, "Microphone permission was not granted")
                resumeWakeWordListeningIfNeeded()
                return
            }
            playVoiceCue(.startListening)
            playVoiceHaptic(.startListening)
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled, isRecordingVoice else {
                return
            }
            beginVoiceRecording()
            voiceStartTask = nil
        }
    }

    private func showWakeWordListeningMessage() {
        transientAskDJListeningMessage = DJConnectAskDJMessage(
            role: .dj,
            origin: "wakeword_listening",
            text: localized(english: "I'm listening", dutch: "Ik luister")
        )
        askDJScrollRequestID = UUID()
    }

    private func dismissWakeWordListeningMessage() {
        transientAskDJListeningMessage = nil
    }

    private func showMoodChangedMessage() {
        transientAskDJMoodMessage = DJConnectAskDJMessage(
            role: .dj,
            origin: "local_mood_change",
            text: localized(
                english: "Mood set to \(askDJMoodLabel).",
                dutch: "Mood ingesteld op \(askDJMoodLabel)."
            )
        )
        askDJScrollRequestID = UUID()
    }

    private func cancelWakeWordVoiceRecordingAfterSilence() {
        #if canImport(AVFoundation)
        voiceStartTask?.cancel()
        voiceStartTask = nil
        let url = voiceRecordingURL
        voiceRecorder?.stop()
        voiceRecorder = nil
        voiceRecordingURL = nil
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
        isRecordingVoice = false
        voiceStatus = .idle
        dismissWakeWordListeningMessage()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        log(.info, "Wakeword voice capture dismissed after silence")
        resumeWakeWordListeningIfNeeded()
        #endif
    }

    public func stopVoiceRecordingAndUpload() {
        guard isRecordingVoice else {
            return
        }

        #if canImport(AVFoundation)
        voiceStartTask?.cancel()
        voiceStartTask = nil
        let url = voiceRecordingURL
        voiceRecorder?.stop()
        voiceRecorder = nil
        voiceRecordingURL = nil
        isRecordingVoice = false
        voiceStatus = .processing
        dismissWakeWordListeningMessage()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        playVoiceCue(.stopListening)
        playVoiceHaptic(.stopListening)

        guard let url else {
            voiceStatus = .idle
            log(.debug, "Voice recording stopped before the recorder was ready")
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
                appendAskDJMessage(role: .user, text: localized(english: "Voice request", dutch: "Stemverzoek"))
                appendAskDJMessage(
                    role: .dj,
                    text: djResponseText,
                    images: proxiedResponseImages(response.images),
                    links: safeResponseLinks(response.links),
                    playbackActions: response.playbackActions ?? [],
                    audioURL: resolvedAudioURL(from: response.audioURL)
                )
                notifyAskDJResponse(djResponseText)
                Task {
                    await playResponseAudioIfNeeded(resolvedAudioURL(from: response.audioURL))
                }
                await syncAskDJHistory(showErrors: false)
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
                showAskDJToast(for: error)
                voiceStatus = .unavailable
                log(.warning, "Voice upload failed: \(describedError)")
                if case .backendUnavailable = error {
                    await refreshAfterDJResponse()
                } else {
                    apply(error: error)
                }
                resumeWakeWordListeningIfNeeded()
            } catch {
                voiceErrorMessage = error.localizedDescription
                showAskDJToast(localized(english: "Ask DJ is unreachable", dutch: "Ask DJ niet bereikbaar"))
                voiceStatus = .unavailable
                log(.error, "Voice upload failed unexpectedly: \(error.localizedDescription)")
                resumeWakeWordListeningIfNeeded()
            }
        }
        #else
        isRecordingVoice = false
        voiceStatus = .unavailable
        dismissWakeWordListeningMessage()
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
        if let pendingSeekTargetMS {
            if abs((normalizedPlayback?.progressMS ?? pendingSeekTargetMS) - pendingSeekTargetMS) <= 1_500 {
                self.pendingSeekTargetMS = nil
            } else {
                normalizedPlayback?.progressMS = pendingSeekTargetMS
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
        markHomeAssistantReachable(backendAvailableAfterResponse: true)
        clearRecoverableVoiceErrorIfNeeded()
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
        let hasPlaybackSnapshot = response.playback != nil
        if let playback = response.playback {
            apply(playback: playback)
        }
        markHomeAssistantReachable(backendAvailableAfterResponse: hasPlaybackSnapshot ? true : (response.backendAvailable ?? true))
        if backendAvailable, voiceStatus == .unavailable, voiceErrorMessage == nil {
            voiceStatus = .idle
        }
        if backendAvailable {
            clearRecoverableVoiceErrorIfNeeded()
        }
        if let devices = response.devices {
            let normalizedDevices = normalizedOutputDevices(devices)
            availableOutputs = normalizedDevices
            if let active = normalizedDevices.first(where: { $0.active == true }) {
                if pendingSelectedOutput == nil || pendingSelectedOutput == active.name {
                    selectedOutput = active.name
                    pendingSelectedOutput = nil
                } else if let pendingSelectedOutput {
                    selectedOutput = pendingSelectedOutput
                }
            } else if selectedOutput == "Not selected" {
                selectedOutput = noOutputName()
            }
        }
        if let responseQueue = response.queue {
            let normalizedQueue = normalizedQueueItems(responseQueue)
            queueItems = normalizedQueue
            queue = normalizedQueue.map(\.displayTitle)
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

    private func normalizedOutputDevices(_ devices: [DJConnectOutputDevice]) -> [DJConnectOutputDevice] {
        let backendDevices = devices.filter { $0.id != Self.syntheticNoOutputID && $0.name != noOutputName() }
        let backendHasActiveDevice = backendDevices.contains { $0.active == true }
        var localNone = DJConnectOutputDevice(
            id: Self.syntheticNoOutputID,
            name: noOutputName(),
            type: "local",
            active: !backendHasActiveDevice && selectedOutput == noOutputName()
        )
        localNone.supportsVolume = false

        return [localNone] + backendDevices
    }

    private func normalizedQueueItems(_ items: [DJConnectQueueItem]) -> [DJConnectQueueItem] {
        var seen: Set<String> = []
        return items.filter { item in
            let signature = queueItemSignature(item)
            guard !seen.contains(signature) else {
                return false
            }
            seen.insert(signature)
            return true
        }
    }

    private func queueItemSignature(_ item: DJConnectQueueItem) -> String {
        [
            item.uri,
            item.title,
            item.artist,
            item.album,
            item.durationMS.map(String.init),
            item.albumImageURL?.absoluteString
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .joined(separator: "|")
    }

    private static let syntheticNoOutputID = "djconnect-output-none"

    private static func isSyntheticOutput(_ output: DJConnectOutputDevice) -> Bool {
        output.id == syntheticNoOutputID
    }

    private func noOutputName() -> String {
        Self.noOutputName(for: language)
    }

    private static func noOutputName(for language: String) -> String {
        language == "nl" ? "Geen" : "None"
    }

    private var isNoOutputSelected: Bool {
        selectedOutput == noOutputName()
    }

    private func shouldBlockPlaybackStart(command: String, play: Bool?) -> Bool {
        guard isNoOutputSelected else {
            return false
        }
        if play == true {
            return true
        }
        return [
            "play",
            "start_playlist",
            "start_liked_proxy",
            "play_context_at"
        ].contains(command)
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
            scheduleBackendRecoveryRefresh(reason: "Retrying playback backend while Home Assistant is reachable")
        case let .network(message):
            applyConnectionUnavailableState(message: message)
        case let .versionMismatch(mismatch):
            clearRuntimeState()
            backendAvailable = false
            updateRequiredMessage = mismatch.message ?? localized(
                english: "Update the DJConnect app or Home Assistant integration.",
                dutch: "Werk de DJConnect app of Home Assistant-integratie bij."
            )
        case let .authStale(_, message):
            recoverFromStalePairing(message: message)
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
                english: "Not connected to Home Assistant.",
                dutch: "Niet gekoppeld aan Home Assistant."
            )
        case let .server(_, message):
            if let userFacingError = userFacingDJResponseText(message ?? Self.describe(error)) {
                djResponseText = userFacingError
            }
        case .missingToken:
            recoverFromStalePairing(message: localized(
                english: "Missing DJConnect bearer token. Reset pairing to set up again.",
                dutch: "DJConnect bearer-token ontbreekt. Reset de pairing om opnieuw te koppelen."
            ))
        default:
            break
        }
    }

    private func recoverFromStalePairing(message: String?) {
        pairingTask?.cancel()
        pairingTask = nil
        scheduledPairingTask?.cancel()
        scheduledPairingTask = nil
        try? tokenStore.clearToken()
        clearPinnedLocalDeviceAPIURL()
        pairingStatus = .stale
        isConnected = false
        isPairing = false
        isPairingScreenDismissed = false
        isShowingPairingSuccess = false
        pairingMessage = message ?? localized(
            english: "Pairing is stale. Open Home Assistant setup and use the code shown here.",
            dutch: "Pairing is verlopen. Open Home Assistant setup en gebruik de code die hier staat."
        )
        restartLocalDeviceAPI()
        updateBonjourAdvertisingState()
        startPairingWait()
    }

    public func emitUserConnectionNotice(for error: DJConnectError? = nil) {
        if let error, !Self.shouldShowConnectionNotice(for: error) {
            return
        }
        userNotice = DJConnectUserNotice(text: localized(
            english: "No connection to Home Assistant",
            dutch: "Geen verbinding met Home Assistant"
        ))
    }

    private func markHomeAssistantReachable(backendAvailableAfterResponse: Bool) {
        pairingStatus = .paired
        isConnected = true
        backendAvailable = backendAvailableAfterResponse
        pairingMessage = nil
        if !backendAvailableAfterResponse {
            scheduleBackendRecoveryRefresh(reason: "Retrying playback backend after unavailable status")
        }
    }

    private func applyConnectionUnavailableState(message: String? = nil) {
        clearRuntimeState(backendAvailableAfterClear: false)
        isConnected = false
        if pairingStatus == .paired {
            pairingMessage = localized(
                english: "Home Assistant is unreachable.",
                dutch: "Home Assistant is niet bereikbaar."
            )
        }
        if let message, !message.isEmpty {
            log(.warning, "Home Assistant unavailable: \(message)")
        }
    }

    private static func shouldShowConnectionNotice(for error: DJConnectError) -> Bool {
        switch error {
        case .backendUnavailable, .server, .network, .decodingFailed, .invalidResponse, .routeMissing:
            true
        case .authStale, .versionMismatch, .notConfigured, .invalidConfiguration, .missingToken, .pairingFailed:
            false
        }
    }

    func applyPairingWait(error: DJConnectError, pairingToken: String) {
        isConnected = false

        switch error {
        case .pairingFailed:
            pairingStatus = .pairing
            pairingMessage = localized(
                english: "Waiting for Home Assistant to accept code \(pairingToken). If the client is not discovered, allow incoming local network connections for DJConnect in macOS firewall or security software.",
                dutch: "Wachten tot Home Assistant code \(pairingToken) accepteert. Wordt de client niet gevonden, sta inkomende lokale netwerkverbindingen voor DJConnect toe in macOS firewall of beveiligingssoftware."
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
                dutch: "Wachten op koppeling."
            )
        case let .server(_, message):
            pairingStatus = .pairing
            pairingMessage = userFacingPairingMessage(from: message) ?? localized(
                english: "Waiting for Home Assistant to finish pairing.",
                dutch: "Wachten tot Home Assistant pairing afrondt."
            )
        case let .authStale(_, message):
            pairingStatus = .stale
            isPairing = false
            pairingMessage = userFacingPairingMessage(from: message) ?? localized(
                english: "Not paired yet. Open DJConnect in Home Assistant and enter the current code from this screen.",
                dutch: "Nog niet gekoppeld. Open DJConnect in Home Assistant en vul de huidige code uit dit scherm in."
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
                    localURL: localDeviceAPIURL,
                    voiceEnabled: voiceEnabled,
                    wakewordEnabled: wakeWordEnabled,
                    wakewordPhrase: wakeWordPhrase,
                    wakewordStatus: "\(wakeWordStatus)",
                    mood: askDJMoodInt
                )
            )
            guard validateHomeAssistantVersion(
                haVersion: response.haVersion,
                haMajorMinor: response.haMajorMinor,
                message: response.message
            ) else {
                return
            }
            let hasPlaybackSnapshot = response.playback != nil
            if let playback = response.playback {
                apply(playback: playback)
            } else {
                log(.debug, "Status response did not include a playback snapshot")
            }
            registerStoredPushTokenIfPossible()
            markHomeAssistantReachable(backendAvailableAfterResponse: hasPlaybackSnapshot ? true : (response.backendAvailable ?? true))
            if backendAvailable {
                clearRecoverableVoiceErrorIfNeeded()
            }
            log(.debug, "Status refresh succeeded")
        } catch let error as DJConnectError {
            log(.warning, "Status refresh failed: \(Self.describe(error))")
            switch error {
            case .backendUnavailable:
                apply(error: error)
                pairingStatus = .paired
                isConnected = true
            case let .routeMissing(message):
                applyConnectionUnavailableState(message: message ?? Self.describe(error))
                pairingStatus = .paired
                isConnected = false
            default:
                apply(error: error)
                throw error
            }
        }
    }

    private func refreshBackendCollections(force: Bool = false) async {
        if !force, let lastBackendCollectionsRefreshAt, Date().timeIntervalSince(lastBackendCollectionsRefreshAt) < backendCollectionsRefreshInterval {
            log(.debug, "Backend collection refresh throttled")
            return
        }
        lastBackendCollectionsRefreshAt = Date()
        await performCommand("devices", notifyUserOnError: false, applyErrorState: false)
        await performCommand("queue", notifyUserOnError: false, applyErrorState: false)
        await performCommand("playlists", notifyUserOnError: false, applyErrorState: false)
    }

    private func refreshStatusWithFallback() async throws {
        try await withHomeAssistantClient { client in
            try await refreshPlaybackSnapshot(client: client)
        }
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
            await refreshBackendCollections(force: true)
        } catch let error as DJConnectError {
            log(.warning, "DJ response refresh failed: \(Self.describe(error))")
            apply(error: error)
        } catch {
            log(.error, "DJ response refresh failed unexpectedly: \(error.localizedDescription)")
        }
    }

    private func clearRuntimeState(backendAvailableAfterClear: Bool = true) {
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
        loadingPlaylistID = nil
        isLoadingQueue = false
        isLoadingPlaylists = false
        queueContext = nil
        playlistItems = []
        selectedOutput = noOutputName()
        djResponseText = ""
        voiceStatus = .idle
        backendAvailable = backendAvailableAfterClear
        updateRequiredMessage = nil
        isRefreshing = false
        isLoadingOutputs = false
        stopResponsePlayback(clearText: false)
    }

    private func stopResponsePlayback(clearText: Bool) {
        if clearText {
            djResponseText = ""
        }
        #if canImport(AVFoundation)
        responseAudioPlaybackTask?.cancel()
        responseAudioPlaybackTask = nil
        responseAudioPlayer?.pause()
        responseAudioPlayer = nil
        askDJAudioPlaybackState = .idle
        responseSpeechSynthesizer?.stopSpeaking(at: .immediate)
        responseSpeechSynthesizer = nil
        #endif
    }

    private func speakDemoResponse(_ text: String) {
        guard localResponseAudioEnabled else {
            log(.debug, "Skipping demo DJ response audio because local response audio is disabled")
            return
        }
        #if canImport(AVFoundation)
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            log(.warning, "Demo DJ response audio session could not be configured: \(error.localizedDescription)")
        }
        #endif
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language == "nl" ? "nl-NL" : "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        responseSpeechSynthesizer = synthesizer
        synthesizer.speak(utterance)
        log(.info, "Playing demo DJ response audio")
        #else
        log(.warning, "Demo DJ response audio is not available on this platform")
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
        guard isAppInForeground, playback?.isPlaying == true else {
            return
        }

        playbackProgressTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else {
                    return
                }
                tick += 1
                let shouldRefresh = self?.advancePlaybackProgress() ?? false
                if shouldRefresh || tick >= (self?.progressTimerNetworkRefreshInterval ?? 60) {
                    tick = 0
                    await self?.refreshNowPlayingFromProgressTimer()
                }
            }
        }
    }

    private func updateNowPlayingPollTimer() {
        nowPlayingPollTask?.cancel()
        guard startBackgroundTasks, isAppInForeground, pairingStatus == .paired, !isDemoMode else {
            return
        }

        nowPlayingPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.nowPlayingPollInterval ?? 10))
                guard !Task.isCancelled else {
                    return
                }
                await self?.refreshNowPlayingFromPollTimer()
            }
        }
    }

    @discardableResult
    private func advancePlaybackProgress() -> Bool {
        guard var currentPlayback = playback, currentPlayback.isPlaying == true else {
            playbackProgressTask?.cancel()
            playbackProgressTask = nil
            return false
        }

        let currentProgress = currentPlayback.progressMS ?? 0
        if let duration = currentPlayback.durationMS, duration > 0 {
            currentPlayback.progressMS = min(currentProgress + 1_000, duration)
            playback = currentPlayback
            return currentProgress + 1_000 >= duration
        } else {
            currentPlayback.progressMS = currentProgress + 1_000
            playback = currentPlayback
            return false
        }
    }

    private func refreshNowPlayingFromProgressTimer() async {
        guard pairingStatus == .paired, !isDemoMode, !isRefreshing, isRuntimeCompatible else {
            return
        }
        do {
            let client = try makeClient()
            try await refreshPlaybackSnapshot(client: client)
            log(.debug, "Playback timer refreshed Now Playing snapshot")
        } catch let error as DJConnectError {
            log(.debug, "Playback timer refresh skipped: \(Self.describe(error))")
        } catch {
            log(.debug, "Playback timer refresh skipped: \(error.localizedDescription)")
        }
    }

    private func refreshNowPlayingFromPollTimer() async {
        guard pairingStatus == .paired, !isDemoMode, !isRefreshing, isRuntimeCompatible else {
            return
        }
        do {
            let client = try makeClient()
            try await refreshPlaybackSnapshot(client: client)
            log(.debug, "Now Playing poll refreshed playback controls")
        } catch let error as DJConnectError {
            log(.debug, "Now Playing poll skipped: \(Self.describe(error))")
        } catch {
            log(.debug, "Now Playing poll skipped: \(error.localizedDescription)")
        }
    }

    private func sendVoiceWithFallback(wavData: Data) async throws -> DJConnectVoiceResponse {
        try await withHomeAssistantClient { client in
            try await client.sendVoice(wavData: wavData, mood: askDJMoodInt, djStyle: "warm_radio_dj", memoryKey: askDJMemoryKey)
        }
    }

    private var askDJMemoryKey: String {
        "djconnect_\(identity.clientType.rawValue)_\(identity.deviceID)"
    }

    private var demoAskDJResponse: String {
        localized(
            english: "Ask DJ gives real answers as soon as DJConnect is paired with Home Assistant.",
            dutch: "Ask DJ geeft echte antwoorden zodra DJConnect is gekoppeld met Home Assistant."
        )
    }

    private var askDJAudioResponseMode: DJConnectAskDJRequest.AudioResponse {
        guard let rawValue = defaults.string(forKey: askDJAudioResponseModeKey) else {
            return .auto
        }
        return DJConnectAskDJRequest.AudioResponse(rawValue: rawValue) ?? .auto
    }

    private func sendAskDJTextWithFallback(_ text: String, clientMessageID: String) async throws -> DJConnectAskDJMessageResponse {
        try await withHomeAssistantClient { client in
            try await client.sendAskDJMessage(DJConnectAskDJRequest(
                identity: identity,
                text: text,
                clientMessageID: clientMessageID,
                inputType: "text",
                mood: askDJMoodInt,
                djStyle: "warm_radio_dj",
                memoryKey: askDJMemoryKey,
                audioResponse: askDJAudioResponseMode
            ))
        }
    }

    private func clearAskDJHistoryWithFallback() async throws -> DJConnectAskDJHistoryResponse {
        try await withHomeAssistantClient { client in
            try await client.clearAskDJHistory(memoryKey: askDJMemoryKey)
        }
    }

    private func fetchAskDJHistory(sinceRevision: Int?) async throws -> DJConnectAskDJHistoryResponse {
        try await withHomeAssistantClient { client in
            try await client.askDJHistory(sinceRevision: sinceRevision)
        }
    }

    private func requestAskDJIdleSuggestion() async throws -> DJConnectAskDJMessageResponse {
        try await withHomeAssistantClient { client in
            try await client.askDJIdleSuggestion(DJConnectAskDJIdleSuggestionRequest(
                identity: identity,
                clientMessageID: UUID().uuidString,
                mood: askDJMoodInt,
                djStyle: "warm_radio_dj",
                memoryKey: askDJMemoryKey
            ))
        }
    }

    private func playAskDJRecommendationWithFallback(_ action: DJConnectAskDJPlaybackAction) async throws -> DJConnectCommandResponse {
        var value: [String: DJConnectJSONValue] = [
            "title": .string(action.title),
            "memory_key": .string(askDJMemoryKey)
        ]
        if let subtitle = action.subtitle, !subtitle.isEmpty {
            value["subtitle"] = .string(subtitle)
        }
        if let uri = action.uri, !uri.isEmpty {
            value["uri"] = .string(uri)
        }
        if !action.uris.isEmpty {
            value["uris"] = .array(action.uris.map { .string($0) })
        }
        if let contextURI = action.contextURI, !contextURI.isEmpty {
            value["context_uri"] = .string(contextURI)
        }
        if let offsetURI = action.offsetURI, !offsetURI.isEmpty {
            value["offset_uri"] = .string(offsetURI)
        }
        if let kind = action.kind, !kind.isEmpty {
            value["kind"] = .string(kind)
        }
        if let reason = action.reason, !reason.isEmpty {
            value["reason"] = .string(reason)
        }
        if let responseValue = action.responseValue, !responseValue.isEmpty {
            value["response_value"] = .string(responseValue)
        }

        let command = action.command?.isEmpty == false ? action.command! : Self.defaultAskDJCommand(for: action)
        return try await withHomeAssistantClient { client in
            try await client.sendCommandResponse(DJConnectCommandPayload(
                identity: identity,
                command: command,
                value: .jsonObject(value),
                play: command == "ask_dj_play_recommendation"
            ))
        }
    }

    private static func defaultAskDJCommand(for action: DJConnectAskDJPlaybackAction) -> String {
        if action.isOutputAction {
            return "set_output"
        }
        if action.responseValue?.isEmpty == false
            || action.kind?.localizedCaseInsensitiveContains("confirmation") == true
            || action.actionStyle?.localizedCaseInsensitiveContains("confirmation") == true {
            return "ask_dj_followup_response"
        }
        return "ask_dj_play_recommendation"
    }

    private func markAskDJOutputActionActive(_ outputDeviceID: String) {
        askDJMessages = askDJMessages.map { message in
            var updatedMessage = message
            updatedMessage.playbackActions = message.playbackActions.map { action in
                guard action.isOutputAction else {
                    return action
                }
                var updatedAction = action
                updatedAction.active = action.outputDeviceID == outputDeviceID
                return updatedAction
            }
            return updatedMessage
        }
        availableOutputs = availableOutputs.map { output in
            var updatedOutput = output
            updatedOutput.active = output.id == outputDeviceID || output.name == outputDeviceID
            return updatedOutput
        }
        selectedOutput = availableOutputs.first { $0.active == true }?.name ?? selectedOutput
        saveAskDJMessages()
    }

    @discardableResult
    private func appendAskDJMessage(
        role: DJConnectAskDJMessageRole,
        text: String,
        serverID: String? = nil,
        clientMessageID: String? = nil,
        messageKind: DJConnectAskDJLocalMessageKind = .assistant,
        origin: String? = nil,
        images: [DJConnectResponseImage] = [],
        links: [DJConnectResponseLink] = [],
        playbackActions: [DJConnectAskDJPlaybackAction] = [],
        audioURL: URL? = nil,
        status: DJConnectAskDJMessageStatus? = nil
    ) -> UUID? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !images.isEmpty || !links.isEmpty || !playbackActions.isEmpty || audioURL != nil else {
            return nil
        }
        let message = DJConnectAskDJMessage(
            serverID: serverID,
            clientMessageID: clientMessageID,
            role: role,
            messageKind: role == .user ? .assistant : messageKind,
            origin: role == .user ? nil : origin,
            text: trimmed,
            images: images,
            links: links,
            playbackActions: playbackActions,
            audioURL: audioURL,
            status: status
        )
        askDJMessages.append(message)
        saveAskDJMessages()
        requestAskDJScrollToBottom()
        return message.id
    }

    private func requestAskDJScrollToBottom() {
        askDJScrollRequestID = UUID()
    }

    private func updateAskDJMessageStatus(id: UUID, status: DJConnectAskDJMessageStatus) {
        guard let index = askDJMessages.firstIndex(where: { $0.id == id }) else {
            return
        }
        askDJMessages[index].status = status
        saveAskDJMessages()
    }

    private func syncAskDJHistory(showErrors: Bool) async {
        guard canUsePlaybackFeatures else {
            return
        }
        do {
            let response = try await fetchAskDJHistory(sinceRevision: nil)
            applyAskDJHistory(response)
            log(.debug, "Ask DJ history synced to revision \(response.historyRevision)")
        } catch let error as DJConnectError {
            guard !Self.isCancellation(error) else {
                log(.debug, "Ask DJ history sync cancelled")
                return
            }
            if showErrors {
                askDJErrorMessage = askDJErrorText(for: error)
                showAskDJToast(for: error)
            }
            log(.warning, "Ask DJ history sync failed: \(Self.describe(error))")
        } catch {
            guard !Self.isCancellation(error) else {
                log(.debug, "Ask DJ history sync cancelled")
                return
            }
            if showErrors {
                askDJErrorMessage = askDJUnavailableText()
                showAskDJToast(localized(english: "Ask DJ is unreachable", dutch: "Ask DJ niet bereikbaar"))
            }
            log(.error, "Ask DJ history sync failed unexpectedly: \(error.localizedDescription)")
        }
    }

    private func requestAskDJIdleSuggestionIfNeeded() async {
        guard canUsePlaybackFeatures,
              !hasRequestedAskDJIdleSuggestion,
              !isRequestingAskDJIdleSuggestion,
              !hasActiveNowPlaying else {
            return
        }
        hasRequestedAskDJIdleSuggestion = true
        isRequestingAskDJIdleSuggestion = true
        defer { isRequestingAskDJIdleSuggestion = false }
        do {
            let response = try await requestAskDJIdleSuggestion()
            applyAskDJMessageResponse(response, fallbackUserMessageID: nil)
            log(.info, "Ask DJ idle suggestion loaded")
        } catch let error as DJConnectError {
            if case .routeMissing = error {
                log(.debug, "Ask DJ idle suggestion skipped because Home Assistant does not support the route yet")
            } else {
                log(.warning, "Ask DJ idle suggestion failed: \(Self.describe(error))")
            }
        } catch {
            log(.debug, "Ask DJ idle suggestion failed unexpectedly: \(error.localizedDescription)")
        }
    }

    private func applyAskDJMessageResponse(_ response: DJConnectAskDJMessageResponse, fallbackUserMessageID: UUID?) {
        var nextMessages = askDJMessages
        if let userMessage = response.userMessage {
            upsertAskDJHistoryMessage(userMessage, into: &nextMessages, fallbackID: fallbackUserMessageID)
        } else if let fallbackUserMessageID {
            updateAskDJMessageStatus(id: fallbackUserMessageID, status: .sent)
        }
        if let assistantMessage = response.assistantMessage {
            upsertAskDJHistoryMessage(assistantMessage, into: &nextMessages, fallbackID: nil)
        }
        applyAskDJTrim(response.historyTrimmedBefore, to: &nextMessages)
        askDJMessages = nextMessages.sorted { $0.createdAt < $1.createdAt }
        persistAskDJRevisions(historyRevision: response.historyRevision, clearRevision: response.clearRevision)
        saveAskDJMessages()
        if fallbackUserMessageID != nil {
            requestAskDJScrollToBottom()
        }
    }

    private func applyAskDJHistory(_ response: DJConnectAskDJHistoryResponse) {
        let localClearRevision = defaults.integer(forKey: askDJClearRevisionKey)
        if response.clearRevision > localClearRevision {
            askDJMessages = []
        }
        var nextMessages = askDJMessages
        for message in response.messages {
            upsertAskDJHistoryMessage(message, into: &nextMessages, fallbackID: nil)
        }
        applyAskDJTrim(response.historyTrimmedBefore, to: &nextMessages)
        askDJMessages = nextMessages.sorted { $0.createdAt < $1.createdAt }
        persistAskDJRevisions(historyRevision: response.historyRevision, clearRevision: response.clearRevision)
        saveAskDJMessages()
    }

    private func upsertAskDJHistoryMessage(
        _ historyMessage: DJConnectAskDJHistoryMessage,
        into messages: inout [DJConnectAskDJMessage],
        fallbackID: UUID?
    ) {
        let existingIndex = messages.firstIndex { localMessage in
            localMessage.serverID == historyMessage.id
                || (historyMessage.clientMessageID != nil && localMessage.clientMessageID == historyMessage.clientMessageID)
        }
        let existing = existingIndex.map { messages[$0] }
        let mapped = makeAskDJMessage(from: historyMessage, existing: existing, fallbackID: fallbackID)
        if let existingIndex {
            messages[existingIndex] = mapped
        } else {
            messages.append(mapped)
        }
    }

    private func makeAskDJMessage(
        from historyMessage: DJConnectAskDJHistoryMessage,
        existing: DJConnectAskDJMessage?,
        fallbackID: UUID?
    ) -> DJConnectAskDJMessage {
        let role: DJConnectAskDJMessageRole = historyMessage.role == .user ? .user : .dj
        let status: DJConnectAskDJMessageStatus? = role == .user ? .sent : nil
        let messageKind: DJConnectAskDJLocalMessageKind = historyMessage.messageKind == .system ? .system : .assistant
        return DJConnectAskDJMessage(
            id: existing?.id ?? fallbackID ?? UUID(uuidString: historyMessage.id) ?? UUID(),
            serverID: historyMessage.id,
            clientMessageID: historyMessage.clientMessageID,
            role: role,
            messageKind: role == .user ? .assistant : messageKind,
            origin: role == .user ? nil : historyMessage.origin,
            text: historyMessage.text,
            images: proxiedResponseImages(historyMessage.images),
            links: safeResponseLinks(historyMessage.links),
            playbackActions: historyMessage.playbackActions + historyMessage.confirmationActions,
            audioURL: resolvedAudioURL(from: historyMessage.audioURL),
            status: status,
            createdAt: historyMessage.createdAt
        )
    }

    private func persistAskDJRevisions(historyRevision: Int, clearRevision: Int) {
        defaults.set(historyRevision, forKey: askDJHistoryRevisionKey)
        defaults.set(clearRevision, forKey: askDJClearRevisionKey)
    }

    private func applyAskDJTrim(_ trimmedBefore: Date?, to messages: inout [DJConnectAskDJMessage]) {
        guard let trimmedBefore else {
            return
        }
        messages.removeAll { $0.createdAt < trimmedBefore }
    }

    private func notifyAskDJResponse(_ text: String) {
        playVoiceHaptic(.response)
        #if canImport(UserNotifications)
        guard !Self.isRunningUnderSwiftPMTests else {
            return
        }
        let preview = Self.notificationPreview(from: text)
        Task {
            let center = UNUserNotificationCenter.current()
            guard await requestAskDJNotificationAuthorizationIfNeeded(center: center) else {
                log(.debug, "Ask DJ notification skipped because notifications are not authorized")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = localized(english: "Ask DJ answered", dutch: "Ask DJ heeft geantwoord")
            content.body = preview.isEmpty ? localized(english: "Your DJ response is ready.", dutch: "Je DJ-antwoord staat klaar.") : preview
            content.sound = .default
            content.threadIdentifier = "djconnect.askdj"
            content.categoryIdentifier = "DJCONNECT_ASK_DJ_RESPONSE"

            let request = UNNotificationRequest(
                identifier: "djconnect.askdj.\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            do {
                try await center.add(request)
                log(.debug, "Ask DJ local notification scheduled")
            } catch {
                log(.warning, "Ask DJ local notification failed: \(error.localizedDescription)")
            }
        }
        #endif
    }

    private static var isRunningUnderSwiftPMTests: Bool {
        let processInfo = ProcessInfo.processInfo
        return Bundle.main.bundleURL.path.contains("/swift/pm")
            || processInfo.arguments.contains { $0.contains("swiftpm-testing-helper") || $0.contains(".xctest") }
            || processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    #if canImport(UserNotifications)
    private func requestAskDJNotificationAuthorizationIfNeeded(center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            guard !hasRequestedAskDJNotificationPermission else {
                return false
            }
            hasRequestedAskDJNotificationPermission = true
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                log(.warning, "Ask DJ notification permission failed: \(error.localizedDescription)")
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func requestRemoteNotificationAuthorizationIfNeeded(center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                log(.warning, "Remote notification permission failed: \(error.localizedDescription)")
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
    #endif

    private func registerForSystemRemoteNotifications() {
        #if os(iOS) && canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #elseif os(macOS) && canImport(AppKit)
        NSApplication.shared.registerForRemoteNotifications()
        #else
        log(.debug, "System remote notification registration is not available on this platform")
        #endif
    }

    private func registerStoredPushTokenIfPossible() {
        guard !isDemoMode,
              pairingStatus == .paired,
              let token = defaults.string(forKey: pushTokenKey),
              !token.isEmpty else {
            return
        }
        let environment = Self.pushEnvironment
        if defaults.string(forKey: registeredPushTokenKey) == token,
           defaults.string(forKey: registeredPushEnvironmentKey) == environment.rawValue {
            return
        }
        Task { @MainActor in
            do {
                let appBundleID = Bundle.main.bundleIdentifier ?? "dev.djconnect.\(identity.clientType.rawValue)"
                let locale = Locale.current.identifier
                _ = try await withHomeAssistantClient { client in
                    try await client.registerPushNotifications(DJConnectPushRegistrationRequest(
                        identity: identity,
                        pushToken: token,
                        pushEnvironment: environment,
                        appBundleID: appBundleID,
                        appVersion: appVersion,
                        locale: locale
                    ))
                }
                defaults.set(token, forKey: registeredPushTokenKey)
                defaults.set(environment.rawValue, forKey: registeredPushEnvironmentKey)
                log(.info, "Registered APNs token \(Self.redactedPushToken(token)) with Home Assistant (\(environment.rawValue))")
            } catch let error as DJConnectError {
                if case .routeMissing = error {
                    log(.debug, "Push registration skipped because Home Assistant does not support the route yet")
                } else {
                    log(.warning, "Push registration failed: \(Self.describe(error))")
                }
            } catch {
                log(.warning, "Push registration failed: \(error.localizedDescription)")
            }
        }
    }

    private static var pushEnvironment: DJConnectPushEnvironment {
        #if DEBUG
        .sandbox
        #else
        .production
        #endif
    }

    private static func redactedPushToken(_ token: String) -> String {
        guard token.count > 12 else {
            return "[redacted]"
        }
        return "\(token.prefix(6))...\(token.suffix(6))"
    }

    private static func notificationPreview(from text: String) -> String {
        let compact = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard compact.count > 120 else {
            return compact
        }
        return String(compact.prefix(117)) + "..."
    }

    private func proxiedResponseImages(_ images: [DJConnectResponseImage]?) -> [DJConnectResponseImage] {
        guard let images, !images.isEmpty else {
            return []
        }
        let baseURLs = homeAssistantBaseURLs()
        let allowedHosts = Set(baseURLs.compactMap { $0.host?.lowercased() })
        guard let primaryBaseURL = baseURLs.first, !allowedHosts.isEmpty else {
            return []
        }
        return images.compactMap { image in
            guard let resolvedURL = resolvedResponseImageURL(image.url, baseURL: primaryBaseURL, allowedHosts: allowedHosts) else {
                return nil
            }
            var updatedImage = image
            updatedImage.url = resolvedURL
            if let thumbnailURL = image.thumbnailURL {
                updatedImage.thumbnailURL = resolvedResponseImageURL(thumbnailURL, baseURL: primaryBaseURL, allowedHosts: allowedHosts)
            }
            return updatedImage
        }
    }

    private func resolvedResponseImageURL(_ url: URL, baseURL: URL, allowedHosts: Set<String>) -> URL? {
        if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            guard let host = url.host?.lowercased(), allowedHosts.contains(host) else {
                return nil
            }
            return url
        }
        guard url.host == nil else {
            return nil
        }
        return URL(string: url.relativeString, relativeTo: baseURL)?.absoluteURL
    }

    private func safeResponseLinks(_ links: [DJConnectResponseLink]?) -> [DJConnectResponseLink] {
        guard let links, !links.isEmpty else {
            return []
        }
        return links.filter { link in
            guard let scheme = link.url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
                return false
            }
            return true
        }
    }

    private func showAskDJToast(for error: DJConnectError) {
        switch error {
        case .backendUnavailable, .server, .decodingFailed, .invalidResponse:
            showAskDJToast(localized(
                english: "Home Assistant did not respond",
                dutch: "Home Assistant gaf geen antwoord"
            ))
        case .network, .routeMissing, .notConfigured, .invalidConfiguration, .missingToken, .pairingFailed:
            showAskDJToast(localized(
                english: "Ask DJ is unreachable",
                dutch: "Ask DJ niet bereikbaar"
            ))
        case .authStale, .versionMismatch:
            showAskDJToast(localized(
                english: "Ask DJ is unreachable",
                dutch: "Ask DJ niet bereikbaar"
            ))
        }
    }

    private func showAskDJToast(_ text: String) {
        askDJToast = DJConnectUserNotice(text: text)
    }

    private func askDJErrorText(for error: DJConnectError) -> String {
        switch error {
        case .backendUnavailable, .server, .decodingFailed, .invalidResponse:
            localized(
                english: "Home Assistant did not respond",
                dutch: "Home Assistant gaf geen antwoord"
            )
        case .network,
             .routeMissing,
             .notConfigured,
             .invalidConfiguration,
             .missingToken,
             .pairingFailed,
             .authStale,
             .versionMismatch:
            askDJUnavailableText()
        }
    }

    private func askDJUnavailableText() -> String {
        localized(english: "Ask DJ is unreachable", dutch: "Ask DJ niet bereikbaar")
    }

    private func clearAskDJHistoryLocally() {
        askDJMessages = []
        defaults.removeObject(forKey: askDJMessagesKey)
        defaults.removeObject(forKey: askDJHistoryRevisionKey)
        defaults.removeObject(forKey: askDJClearRevisionKey)
    }


    public func seedAskDJOnAirDemoMessagesForTesting() {
        clearAskDJHistoryLocally()
        appendAskDJMessage(
            role: .user,
            text: localized(english: "Surprise the living room with a track", dutch: "Verras de woonkamer met een track"),
            status: .sent
        )
        appendAskDJMessage(
            role: .dj,
            text: localized(
                english: "Ask DJ is On Air! Midnight City is playing in the living room and Ask DJ is ready for the next request.",
                dutch: "Ask DJ is On Air! Midnight City speelt in de woonkamer en Ask DJ is klaar voor het volgende verzoek."
            )
        )
    }

    public func showAskDJOnAirStatusIfNeeded() {
        let text = "Ask DJ is On Air!"
        appendAskDJStatusMessageIfNeeded(text: text, origin: "airplay_route")
    }

    public func showAskDJOnAirNeedsDisplayNoticeIfNeeded() {
        let text = localized(
            english: "Ask DJ could not start the On Air video stream. Try AirPlay again in a moment.",
            dutch: "Ask DJ kon de On Air-videostream niet starten. Probeer AirPlay zo opnieuw."
        )
        appendAskDJStatusMessageIfNeeded(text: text, origin: "airplay_display_unavailable")
    }

    public func prepareAskDJOnAirStream(directory: URL) -> URL? {
        askDJOnAirHLSDirectory = directory
        guard let localDeviceAPIURL, let baseURL = URL(string: localDeviceAPIURL) else {
            log(.warning, "On Air HLS stream cannot use HTTP because the local device API URL is missing")
            return nil
        }
        let playlistURL = baseURL
            .appendingPathComponent("on-air")
            .appendingPathComponent("index.m3u8")
        log(.info, "On Air HLS stream prepared at \(playlistURL.absoluteString)")
        return playlistURL
    }

    public func logAskDJOnAirStream(_ message: String) {
        log(.info, "On Air HLS: \(message)")
    }

    private func appendAskDJStatusMessageIfNeeded(text: String, origin: String) {
        let recentCutoff = Date().addingTimeInterval(-300)
        guard !askDJMessages.contains(where: { message in
            message.role == .dj && message.text == text && message.createdAt >= recentCutoff
        }) else {
            return
        }
        appendAskDJMessage(
            role: .dj,
            text: text,
            messageKind: .system,
            origin: origin
        )
    }

    private func saveAskDJMessages() {
        do {
            let data = try JSONEncoder().encode(askDJMessages)
            defaults.set(data, forKey: askDJMessagesKey)
        } catch {
            log(.warning, "Ask DJ chat cache could not be saved: \(error.localizedDescription)")
        }
    }

    private static func loadAskDJMessages(defaults: UserDefaults, key: String) -> [DJConnectAskDJMessage] {
        guard let data = defaults.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([DJConnectAskDJMessage].self, from: data)) ?? []
    }

    private func userFacingDJResponseText(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if let message = Self.extractServerJSONMessage(from: text) {
            return userFacingDJResponseText(message) ?? message
        }
        let normalized = text.lowercased()
        if Self.looksLikeHTMLDocument(normalized) {
            log(.warning, "Suppressed HTML response in DJ request message")
            return localized(
                english: "No connection to Home Assistant",
                dutch: "Geen verbinding met Home Assistant"
            )
        }
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
        if normalized.contains("player command failed")
            && normalized.contains("no active device found") {
            log(.warning, "Playback command failed because Spotify has no active device")
            return localized(
                english: "No active playback device found",
                dutch: "Geen actief afspeelapparaat gevonden"
            )
        }
        return text
    }

    private static func looksLikeHTMLDocument(_ normalizedText: String) -> Bool {
        normalizedText.contains("<!doctype html")
            || normalizedText.contains("<html")
            || normalizedText.contains("<head")
            || normalizedText.contains("<body")
            || normalizedText.contains("</html>")
            || normalizedText.contains("text/html")
            || normalizedText.contains("assets.ngrok.com")
    }

    private func userFacingPairingMessage(from text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if let message = Self.extractServerJSONMessage(from: text) {
            return userFacingPairingMessage(from: message)
        }
        let normalized = text.lowercased()
        if normalized.contains("pairing code")
            || normalized.contains("app code")
            || normalized.contains("does not match")
            || normalized.contains("invalid code") {
            return localized(
                english: "Not paired yet. Open DJConnect in Home Assistant and enter the current code from this screen.",
                dutch: "Nog niet gekoppeld. Open DJConnect in Home Assistant en vul de huidige code uit dit scherm in."
            )
        }
        if normalized.contains("token")
            || normalized.contains("bearer")
            || normalized.contains("unauthorized")
            || normalized.contains("forbidden") {
            return localized(
                english: "Home Assistant rejected this app. Pair DJConnect again from Home Assistant.",
                dutch: "Home Assistant weigert deze app. Koppel DJConnect opnieuw vanuit Home Assistant."
            )
        }
        return localized(
            english: "Pairing could not be completed. Check Home Assistant and enter the app code again.",
            dutch: "Koppelen is niet gelukt. Controleer Home Assistant en vul de app-code opnieuw in."
        )
    }

    private func clearRecoverableVoiceErrorIfNeeded() {
        guard isRecoverableVoiceErrorText(djResponseText) else {
            return
        }
        djResponseText = ""
        voiceErrorMessage = nil
        if voiceStatus == .unavailable {
            voiceStatus = .idle
        }
        log(.debug, "Cleared recoverable DJ request message after backend became available")
    }

    private func isRecoverableVoiceErrorText(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "refresh the spotify connection in home assistant"
            || normalized == "ververs spotify koppeling in home assistant"
            || normalized == "playback backend unavailable"
            || normalized == "playback backend niet beschikbaar"
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

    public func replayAskDJAudio(_ audioURL: URL?) {
        let resolvedURL = resolvedAudioURL(from: audioURL)
        Task {
            await playResponseAudio(resolvedURL)
        }
    }

    public func requestRemoteNotificationRegistration() {
        #if canImport(UserNotifications)
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let authorized = await requestRemoteNotificationAuthorizationIfNeeded(center: center)
            refreshPermissionStatuses()
            guard authorized else {
                log(.warning, "Remote notification permission was not granted")
                return
            }
            registerForSystemRemoteNotifications()
        }
        #else
        notificationPermissionStatus = .unavailable
        #endif
    }

    public func handleRemoteNotificationDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        guard !token.isEmpty else {
            return
        }
        defaults.set(token, forKey: pushTokenKey)
        log(.info, "Received APNs token \(Self.redactedPushToken(token))")
        registerStoredPushTokenIfPossible()
    }

    public func handleRemoteNotificationRegistrationError(_ error: Error) {
        log(.warning, "Remote notification registration failed: \(error.localizedDescription)")
    }

    public func unregisterPushNotifications() {
        guard let token = defaults.string(forKey: pushTokenKey), !token.isEmpty else {
            return
        }
        guard let bearerToken = try? tokenStore.loadToken(), !bearerToken.isEmpty else {
            return
        }
        defaults.removeObject(forKey: pushTokenKey)
        defaults.removeObject(forKey: registeredPushTokenKey)
        defaults.removeObject(forKey: registeredPushEnvironmentKey)
        let authStore = DJConnectInMemoryTokenStore(token: bearerToken)
        let baseURLs = homeAssistantBaseURLs()
        Task { @MainActor in
            do {
                guard !baseURLs.isEmpty else {
                    return
                }
                var lastError: Error?
                for baseURL in baseURLs {
                    do {
                        let client = DJConnectClient(baseURL: baseURL, identity: identity, tokenStore: authStore)
                        _ = try await client.unregisterPushNotifications(DJConnectPushUnregistrationRequest(
                            identity: identity,
                            pushToken: token
                        ))
                        log(.info, "Unregistered APNs token \(Self.redactedPushToken(token))")
                        return
                    } catch {
                        lastError = error
                    }
                }
                if let lastError {
                    throw lastError
                }
            } catch let error as DJConnectError {
                if case .routeMissing = error {
                    log(.debug, "Push unregister skipped because Home Assistant does not support the route yet")
                } else {
                    log(.warning, "Push unregister failed: \(Self.describe(error))")
                }
            } catch {
                log(.warning, "Push unregister failed: \(error.localizedDescription)")
            }
        }
    }


    public func playAskDJOnAirAudioIfNeeded(for message: DJConnectAskDJMessage?) {
        guard let message, message.role != .user else {
            return
        }
        let resolvedURL = resolvedAudioURL(from: message.audioURL)
        guard let resolvedURL else {
            return
        }
        if isLoadingAskDJAudio(resolvedURL) || isPlayingAskDJAudio(resolvedURL) {
            return
        }
        Task {
            await playResponseAudioIfNeeded(resolvedURL)
        }
    }

    public func stopAskDJAudio() {
        stopResponsePlayback(clearText: false)
    }

    public func isLoadingAskDJAudio(_ audioURL: URL?) -> Bool {
        guard let resolvedURL = resolvedAudioURLForState(from: audioURL) else {
            return false
        }
        if case let .loading(currentURL) = askDJAudioPlaybackState {
            return currentURL == resolvedURL
        }
        return false
    }

    public func isPlayingAskDJAudio(_ audioURL: URL?) -> Bool {
        guard let resolvedURL = resolvedAudioURLForState(from: audioURL) else {
            return false
        }
        if case let .playing(currentURL) = askDJAudioPlaybackState {
            return currentURL == resolvedURL
        }
        return false
    }

    private func resolvedAudioURLForState(from audioURL: URL?) -> URL? {
        guard let audioURL else {
            return nil
        }
        if audioURL.scheme?.isEmpty == false {
            return audioURL
        }
        guard let baseURL = Self.normalizedHomeAssistantURL(from: localHomeAssistantURL()) else {
            return nil
        }
        return URL(string: audioURL.absoluteString, relativeTo: baseURL)?.absoluteURL
    }

    private func playResponseAudioIfNeeded(_ audioURL: URL?) async {
        guard localResponseAudioEnabled else {
            log(.debug, "Skipping DJ response audio because local response audio is disabled")
            return
        }
        await playResponseAudio(audioURL)
    }

    private func playResponseAudio(_ audioURL: URL?) async {
        guard let audioURL else {
            return
        }
        #if canImport(AVFoundation)
        do {
            responseAudioPlaybackTask?.cancel()
            responseAudioPlayer?.pause()
            askDJAudioPlaybackState = .loading(audioURL)
            log(.info, "Loading DJ response audio from Home Assistant")
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
            let item = AVPlayerItem(url: audioURL)
            let player = AVPlayer(playerItem: item)
            responseAudioPlayer = player
            player.play()
            askDJAudioPlaybackState = .playing(audioURL)
            log(.info, "Playing DJ response audio from Home Assistant")
            responseAudioPlaybackTask = Task { @MainActor [weak self] in
                let endNotifications = NotificationCenter.default.notifications(
                    named: .AVPlayerItemDidPlayToEndTime,
                    object: item
                )
                let failedNotifications = NotificationCenter.default.notifications(
                    named: .AVPlayerItemFailedToPlayToEndTime,
                    object: item
                )
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await _ in endNotifications {
                            break
                        }
                    }
                    group.addTask {
                        for await _ in failedNotifications {
                            break
                        }
                    }
                    group.addTask {
                        try? await Task.sleep(for: .seconds(120))
                    }
                    await group.next()
                    group.cancelAll()
                }
                if case let .playing(currentURL) = self?.askDJAudioPlaybackState, currentURL == audioURL {
                    self?.askDJAudioPlaybackState = .idle
                    self?.responseAudioPlayer?.pause()
                    self?.responseAudioPlayer = nil
                    self?.responseAudioPlaybackTask = nil
                    self?.log(.info, "DJ response audio playback ended")
                }
            }
        } catch {
            askDJAudioPlaybackState = .idle
            log(.warning, "DJ response audio could not be played: \(error.localizedDescription)")
            showAskDJToast(localized(
                english: "Audio could not be played again",
                dutch: "Audio kon niet opnieuw worden afgespeeld"
            ))
        }
        #else
        log(.warning, "DJ response audio is not available on this platform")
        showAskDJToast(localized(
            english: "Audio could not be played again",
            dutch: "Audio kon niet opnieuw worden afgespeeld"
        ))
        #endif
    }

    @discardableResult
    private func performCommand(
        _ command: String,
        value: DJConnectCommandValue? = nil,
        play: Bool? = nil,
        notifyUserOnError: Bool = true,
        applyErrorState: Bool = true
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
            try await withHomeAssistantClient { client in
                log(.debug, "Posting command \(command) to Home Assistant")
                let response = try await client.sendCommandResponse(
                    DJConnectCommandPayload(
                        identity: identity,
                        command: command,
                        value: value,
                        play: play,
                        limit: Self.commandLimit(for: command)
                    )
                )
                apply(commandResponse: response)
                if Self.shouldRefreshPlaybackAfterCommand(command) {
                    try await refreshPlaybackSnapshot(client: client)
                    if Self.shouldRefreshPlaybackAgainAfterCommand(command) {
                        try? await Task.sleep(for: .milliseconds(850))
                        guard pairingStatus == .paired else {
                            return
                        }
                        try await refreshPlaybackSnapshot(client: client)
                    }
                }
            }
            log(.debug, "Command \(command) succeeded")
            return true
        } catch let error as DJConnectError {
            log(.warning, "Command \(command) failed: \(Self.describe(error))")
            if applyErrorState {
                apply(error: error)
            }
            if notifyUserOnError {
                emitUserConnectionNotice(for: error)
            }
            return false
        } catch {
            log(.error, "Command \(command) failed unexpectedly: \(error.localizedDescription)")
            pairingMessage = error.localizedDescription
            if notifyUserOnError {
                emitUserConnectionNotice()
            }
            return false
        }
    }

    static func commandLimit(for command: String) -> Int? {
        switch command {
        case "queue":
            return 100
        case "playlists":
            return 100
        default:
            return nil
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
            english: "Tap the microphone icon to hear a sample announcement.",
            dutch: "Druk op het microfoon icoon om een voorbeeld aankondiging te beluisteren."
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
        guard let baseURL = homeAssistantBaseURLs().first else {
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

    private func homeAssistantBaseURLs() -> [URL] {
        var urls: [URL] = []
        var seen: Set<String> = []
        for rawURL in [localHomeAssistantURL(), homeAssistantURL, haLocalURL] {
            guard let url = Self.normalizedHomeAssistantURL(from: rawURL) else {
                continue
            }
            let key = Self.redactedURL(url).lowercased()
            guard !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            urls.append(url)
        }
        return urls
    }

    private func withHomeAssistantClient<T: Sendable>(_ operation: (DJConnectClient) async throws -> T) async throws -> T {
        let baseURLs = homeAssistantBaseURLs()
        guard !baseURLs.isEmpty else {
            throw DJConnectError.network(message: localized(
                english: "Enter your Home Assistant URL, for example 192.168.1.10:8123.",
                dutch: "Vul je Home Assistant URL in, bijvoorbeeld 192.168.1.10:8123."
            ))
        }

        var lastError: Error?
        for (index, baseURL) in baseURLs.enumerated() {
            do {
                let result = try await operation(makeClient(baseURL: baseURL))
                if index > 0 {
                    pinLocalDeviceAPIURLIfNeeded(baseURL)
                    log(.info, "Recovered Home Assistant connection via fallback URL")
                }
                return result
            } catch let error as DJConnectError {
                lastError = error
                guard index + 1 < baseURLs.count, Self.isRetryableHomeAssistantConnectionError(error) else {
                    throw error
                }
                log(.warning, "Home Assistant URL \(Self.redactedURL(baseURL)) failed, trying fallback: \(Self.describe(error))")
            } catch {
                lastError = error
                guard index + 1 < baseURLs.count else {
                    throw error
                }
                log(.warning, "Home Assistant URL \(Self.redactedURL(baseURL)) failed unexpectedly, trying fallback: \(error.localizedDescription)")
            }
        }
        throw lastError ?? DJConnectError.network(message: "Home Assistant unavailable")
    }

    private func pinLocalDeviceAPIURLIfNeeded(_ baseURL: URL) {
        let url = Self.redactedURL(baseURL)
        guard haLocalURL != url else {
            return
        }
        haLocalURL = url
        defaults.set(url, forKey: haLocalURLKey)
    }

    private static func isRetryableHomeAssistantConnectionError(_ error: DJConnectError) -> Bool {
        switch error {
        case .network, .invalidResponse:
            true
        default:
            false
        }
    }

    private func startNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isLocalNetwork = path.status == .satisfied
                && (path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet))
            Task { @MainActor in
                guard let self else {
                    return
                }
                let didChange = self.isLocalNetworkAvailable != isLocalNetwork || !self.hasEvaluatedLocalNetwork
                guard didChange else {
                    return
                }
                self.hasEvaluatedLocalNetwork = true
                self.isLocalNetworkAvailable = isLocalNetwork
                if isLocalNetwork {
                    self.log(.info, "Local Wi-Fi/LAN available")
                    if self.pairingMessage?.localizedCaseInsensitiveContains("WiFi") == true
                        || self.pairingMessage?.localizedCaseInsensitiveContains("Wi-Fi") == true
                        || self.pairingMessage?.localizedCaseInsensitiveContains("LAN") == true {
                        self.pairingMessage = nil
                    }
                    self.schedulePairingWait()
                } else {
                    self.log(.warning, "Local Wi-Fi/LAN unavailable")
                    if !self.isDemoMode {
                        self.pairingMessage = self.localNetworkRequirementMessage
                    }
                }
            }
        }
        networkMonitor.start(queue: networkMonitorQueue)
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
                        firmware: "3.1.42",
                        appVersion: "3.1.42",
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
            fileHandler: { [weak self] path in
                await MainActor.run {
                    self?.localOnAirFileResponse(path: path)
                }
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
            preferredPort: pinnedLocalDeviceAPIPort(),
            advertiseBonjour: shouldAdvertiseBonjour
        )
        localDeviceAPI?.start()
    }

    private func localOnAirFileResponse(path: String) -> DJConnectLocalDeviceAPI.FileResponse? {
        guard path.hasPrefix("/on-air/"), let askDJOnAirHLSDirectory else {
            return nil
        }
        let filename = String(path.dropFirst("/on-air/".count))
        guard !filename.isEmpty,
              !filename.contains("/"),
              !filename.contains("..") else {
            return nil
        }
        let fileURL = askDJOnAirHLSDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        let contentType: String
        switch fileURL.pathExtension.lowercased() {
        case "m3u8":
            contentType = "application/vnd.apple.mpegurl"
        case "mp4", "m4s":
            contentType = "video/mp4"
        default:
            contentType = "application/octet-stream"
        }
        return DJConnectLocalDeviceAPI.FileResponse(data: data, contentType: contentType)
    }

    private func restartLocalDeviceAPI() {
        localDeviceAPI?.stop()
        localDeviceAPI = nil
        startLocalDeviceAPI()
    }

    private var shouldAdvertiseBonjour: Bool {
        !isDemoMode && pairingStatus != .paired
    }

    var isBonjourAdvertisingPreferredForTests: Bool {
        shouldAdvertiseBonjour
    }

    var isAppInForegroundForTests: Bool {
        isAppInForeground
    }

    var isLocalDeviceAPIRunningForTests: Bool {
        localDeviceAPI != nil
    }

    private func updateBonjourAdvertisingState() {
        localDeviceAPI?.setBonjourAdvertisingEnabled(shouldAdvertiseBonjour)
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
            applyTokenStorageFailure(error)
            pairingMessage = localized(
                english: "DJConnect could not save the device token.",
                dutch: "DJConnect kon het device-token niet opslaan."
            )
            return DJConnectLocalDeviceAPIResponse(
                success: false,
                error: "token_store_failed",
                message: "Could not store device token."
            )
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
        if pairingStatus == .paired, let pinnedURL = defaults.string(forKey: localDeviceAPIURLKey), !pinnedURL.isEmpty {
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
        log(.info, "Pinned Client address for current pairing")
    }

    private func clearPinnedLocalDeviceAPIURL() {
        localDeviceAPIURL = nil
        defaults.removeObject(forKey: localDeviceAPIURLKey)
    }

    private func pinnedLocalDeviceAPIPort() -> UInt16? {
        guard pairingStatus == .paired else {
            return nil
        }
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
        deletePersistentDiagnosticLog()
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
        appendPersistentDiagnosticLogLine(line)
    }

    private func loadPersistentDiagnosticLog() {
        guard
            let diagnosticLogFileURL,
            let data = try? Data(contentsOf: diagnosticLogFileURL),
            let text = String(data: data, encoding: .utf8)
        else {
            return
        }

        let lines = text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .suffix(maxDiagnosticLogLines)
        diagnosticLogLines = lines.map { DJConnectDiagnosticLogLine(text: $0) }
    }

    private func appendPersistentDiagnosticLogLine(_ line: String) {
        guard let diagnosticLogFileURL else {
            return
        }

        do {
            let fileManager = FileManager.default
            let directory = diagnosticLogFileURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            var lines: [String] = []
            if
                let data = try? Data(contentsOf: diagnosticLogFileURL),
                let text = String(data: data, encoding: .utf8)
            {
                lines = text.split(whereSeparator: \.isNewline).map(String.init)
            }

            lines.append(Self.redactSensitive(line))
            lines = Array(lines.suffix(maxPersistentDiagnosticLogLines))

            var output = lines.joined(separator: "\n")
            if !output.isEmpty {
                output.append("\n")
            }

            while output.utf8.count > maxPersistentDiagnosticLogFileBytes, lines.count > 1 {
                lines.removeFirst(max(1, lines.count / 10))
                output = lines.joined(separator: "\n")
                if !output.isEmpty {
                    output.append("\n")
                }
            }

            try Data(output.utf8).write(to: diagnosticLogFileURL, options: .atomic)
        } catch {
            logger.warning("Persistent diagnostic log write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deletePersistentDiagnosticLog() {
        guard let diagnosticLogFileURL else {
            return
        }
        try? FileManager.default.removeItem(at: diagnosticLogFileURL)
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
        case let .decodingFailed(statusCode, endpoint, message):
            "decode failed HTTP \(statusCode) \(endpoint)\(message.map { ": \($0)" } ?? "")"
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

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        if let djConnectError = error as? DJConnectError,
           case let .network(message) = djConnectError {
            let lowercasedMessage = message.lowercased()
            return lowercasedMessage.contains("cancelled")
                || lowercasedMessage.contains("canceled")
                || lowercasedMessage.contains("geannuleerd")
        }
        return false
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
                of: #"(?i)(token|access_token|refresh_token|device_token|bearer_token)=([^&\s]+)"#,
                with: "$1=[redacted]",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b\d{6}\b"#,
                with: "[pair-code]",
                options: .regularExpression
            )
    }

    private static func defaultDiagnosticLogDirectory() -> URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("DJConnect", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
    }

    public func refreshPermissionStatuses() {
        microphonePermissionStatus = Self.currentMicrophonePermissionStatus()
        speechPermissionStatus = Self.currentSpeechPermissionStatus()
        Task { @MainActor in
            notificationPermissionStatus = await Self.currentNotificationPermissionStatus()
        }
        localNetworkPermissionStatus = .unknown
        log(.debug, "Permission status refreshed: microphone=\(microphonePermissionStatus.rawValue) speech=\(speechPermissionStatus.rawValue) notifications=\(notificationPermissionStatus.rawValue) local_network=\(localNetworkPermissionStatus.rawValue)")
        if wakeWordEnabled, wakeWordStatus == .unavailable, microphonePermissionStatus == .granted, speechPermissionStatus == .granted {
            log(.info, "Retrying wakeword listening after permission status refresh")
            startWakeWordListening()
        }
    }

    public func setWakeWordEnabled(_ enabled: Bool) {
        refreshPermissionStatuses()
        wakeWordEnabled = enabled
    }

    private var canListenForWakeWord: Bool {
        wakeWordEnabled
            && voiceEnabled
            && pairingStatus == .paired
            && isConnected
            && backendAvailable
    }

    #if os(iOS) && canImport(AVFoundation)
    private static let bluetoothAudioSessionOption = AVAudioSession.CategoryOptions(rawValue: 0x4)
    #endif

    private func updateWakeWordListeningForAvailability() {
        guard wakeWordEnabled else {
            return
        }
        if canListenForWakeWord {
            resumeWakeWordListeningIfNeeded()
        } else {
            stopWakeWordListening()
        }
    }

    public func requestAppPermissions() {
        guard !isRequestingPermissions else {
            log(.debug, "Ignoring permission request because one is already running")
            return
        }
        log(.debug, "User action: request app permissions")
        refreshPermissionStatuses()
        let action = Self.permissionRequestAction(
            microphone: microphonePermissionStatus,
            speech: speechPermissionStatus,
            notifications: notificationPermissionStatus
        )
        switch action {
        case .alreadyGranted:
            log(.info, "App permissions already granted")
            registerForSystemRemoteNotifications()
            refreshPermissionStatuses()
            return
        case .openSystemSettings:
            log(.info, "Opening system settings because a permission was denied or restricted")
            openAppPermissionSettings()
            schedulePermissionStatusRefreshes()
            return
        case .requestSystemPrompt:
            break
        }
        pendingPermissionRequest = .appPermissions
        isShowingPermissionExplanation = true
    }

    public func continueAfterPermissionExplanation() {
        let pending = pendingPermissionRequest
        pendingPermissionRequest = nil
        isShowingPermissionExplanation = false
        switch pending {
        case .appPermissions:
            requestAppPermissionsAfterExplanation()
        case .voiceRecording:
            shouldBypassPermissionExplanationOnce = true
            startVoiceRecording()
        case nil:
            break
        }
    }

    public func cancelPermissionExplanation() {
        pendingPermissionRequest = nil
        isShowingPermissionExplanation = false
        log(.debug, "User cancelled permission explanation")
    }

    private func requestAppPermissionsAfterExplanation() {
        guard !isRequestingPermissions else {
            return
        }
        isRequestingPermissions = true
        Task { @MainActor in
            log(.debug, "Permission request started: microphone_status=\(microphonePermissionStatus.rawValue) speech_status=\(speechPermissionStatus.rawValue)")
            log(.debug, "Permission request step: microphone begin")
            let microphoneGranted: Bool
            if microphonePermissionStatus == .granted {
                microphoneGranted = true
            } else {
                microphoneGranted = await requestMicrophoneAccess()
            }
            log(.debug, "Permission request step: microphone completed granted=\(microphoneGranted)")
            log(.debug, "Permission request step: speech begin")
            let speechGranted: Bool
            if speechPermissionStatus == .granted {
                speechGranted = true
            } else {
                speechGranted = await requestSpeechAccessIfAvailable()
            }
            log(.debug, "Permission request step: speech completed granted=\(speechGranted)")
            log(.debug, "Permission request step: notifications begin")
            let notificationGranted: Bool
            #if canImport(UserNotifications)
            notificationGranted = await requestRemoteNotificationAuthorizationIfNeeded(center: UNUserNotificationCenter.current())
            if notificationGranted {
                registerForSystemRemoteNotifications()
            }
            #else
            notificationGranted = false
            #endif
            log(.debug, "Permission request step: notifications completed granted=\(notificationGranted)")
            refreshPermissionStatuses()
            isRequestingPermissions = false
            if microphoneGranted, speechGranted {
                log(.info, "App permissions granted")
            } else {
                log(.warning, "App permissions are incomplete")
            }
        }
    }

    public static func permissionRequestAction(
        microphone: DJConnectPermissionStatus,
        speech: DJConnectPermissionStatus,
        notifications: DJConnectPermissionStatus = .granted
    ) -> DJConnectPermissionRequestAction {
        if microphone == .granted, speech == .granted, notifications == .granted {
            return .alreadyGranted
        }
        if microphone == .denied
            || microphone == .restricted
            || speech == .denied
            || speech == .restricted
            || notifications == .denied
            || notifications == .restricted {
            return .openSystemSettings
        }
        return .requestSystemPrompt
    }

    private func openAppPermissionSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            log(.warning, "Could not create iOS Settings URL")
            return
        }
        UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    private func schedulePermissionStatusRefreshes() {
        Task { @MainActor in
            for delay in [500, 1_500, 3_000] {
                try? await Task.sleep(for: .milliseconds(delay))
                refreshPermissionStatuses()
            }
        }
    }

    private static func currentMicrophonePermissionStatus() -> DJConnectPermissionStatus {
        #if canImport(AVFoundation)
        #if os(iOS)
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .undetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
        #endif
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
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

    private static func currentNotificationPermissionStatus() async -> DJConnectPermissionStatus {
        #if canImport(UserNotifications)
        guard !isRunningUnderSwiftPMTests else {
            return .unavailable
        }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .granted
        case .notDetermined:
            return .unknown
        case .denied:
            return .denied
        @unknown default:
            return .unavailable
        }
        #else
        return .unavailable
        #endif
    }

    private func requestMicrophoneAccess() async -> Bool {
        #if canImport(AVFoundation)
        switch Self.currentMicrophonePermissionStatus() {
        case .granted:
            log(.debug, "Microphone permission already granted; skipping system prompt")
            return true
        case .denied, .restricted:
            log(.warning, "Microphone permission is denied or restricted; opening system settings")
            openAppPermissionSettings()
            schedulePermissionStatusRefreshes()
            return false
        case .unavailable:
            log(.debug, "Microphone permission unavailable on this platform")
            return false
        case .unknown:
            break
        }
        return await withCheckedContinuation { continuation in
            let resumeOnMainQueue: @Sendable (Bool) -> Void = { granted in
                Task { @MainActor in
                    continuation.resume(returning: granted)
                }
            }
            #if os(iOS)
            log(.debug, "Requesting microphone permission using AVAudioApplication")
            AVAudioApplication.requestRecordPermission(completionHandler: resumeOnMainQueue)
            #elseif os(macOS)
            log(.debug, "Requesting microphone permission using AVCaptureDevice")
            AVCaptureDevice.requestAccess(for: .audio, completionHandler: resumeOnMainQueue)
            #else
            log(.debug, "Microphone permission unavailable on this platform")
            resumeOnMainQueue(false)
            #endif
        }
        #else
        log(.debug, "Microphone permission unavailable because AVFoundation is missing")
        return false
        #endif
    }

    private func requestSpeechAccessIfAvailable() async -> Bool {
        #if canImport(Speech) && canImport(AVFoundation)
        await requestSpeechAccess()
        #else
        log(.debug, "Speech permission unavailable on this platform")
        false
        #endif
    }

    private func startWakeWordListening() {
        guard wakeWordEnabled else {
            wakeWordStatus = .idle
            return
        }
        guard isAppInForeground else {
            wakeWordStatus = .idle
            log(.debug, "Wakeword listening deferred while app is not foreground")
            return
        }
        guard !isDemoMode else {
            wakeWordStatus = .unavailable
            log(.info, "Wakeword is disabled in demo mode")
            return
        }
        guard canListenForWakeWord, !isRecordingVoice, voiceStatus != .processing else {
            wakeWordStatus = .idle
            if wakeWordEnabled, pairingStatus == .paired, (!isConnected || !backendAvailable) {
                log(.debug, "Wakeword listening paused while Home Assistant or playback backend is unavailable")
            }
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
            let microphoneGranted: Bool
            if Self.currentMicrophonePermissionStatus() == .granted {
                microphoneGranted = true
            } else {
                microphoneGranted = await requestMicrophoneAccess()
            }
            let speechGranted: Bool
            if Self.currentSpeechPermissionStatus() == .granted {
                speechGranted = true
            } else {
                speechGranted = await requestSpeechAccess()
            }
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
        wakeWordPhraseRestartTask?.cancel()
        wakeWordPhraseRestartTask = nil
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

    private func scheduleWakeWordPhraseRestart() {
        #if canImport(Speech) && canImport(AVFoundation)
        wakeWordPhraseRestartTask?.cancel()
        wakeWordPhraseRestartTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else {
                return
            }
            restartWakeWordListening()
        }
        #else
        restartWakeWordListening()
        #endif
    }

    private func resumeWakeWordListeningIfNeeded(after delay: Duration = .milliseconds(500)) {
        guard !isDemoMode else {
            wakeWordStatus = .unavailable
            return
        }
        guard canListenForWakeWord else {
            return
        }
        guard isAppInForeground else {
            wakeWordStatus = .idle
            return
        }
        #if canImport(Speech) && canImport(AVFoundation)
        wakeWordRestartTask?.cancel()
        wakeWordRestartTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
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
        guard !isDemoMode, canListenForWakeWord, !isRecordingVoice else {
            return
        }
        log(.info, "Wakeword detected")
        wakeWordStatus = .detected
        stopWakeWordListening()
        showWakeWordListeningMessage()
        startVoiceRecording()
        #if canImport(Speech) && canImport(AVFoundation)
        wakeWordCaptureTask?.cancel()
        wakeWordCaptureTask = Task { @MainActor in
            await stopWakeWordCaptureAfterSilence()
        }
        #endif
    }

    #if canImport(Speech) && canImport(AVFoundation)
    private func stopWakeWordCaptureAfterSilence() async {
        let startedAt = Date()
        var heardSpeech = false
        var silentSince: Date?
        while !Task.isCancelled, isRecordingVoice {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled, isRecordingVoice else {
                return
            }
            guard let recorder = voiceRecorder else {
                if Date().timeIntervalSince(startedAt) > 6 {
                    cancelWakeWordVoiceRecordingAfterSilence()
                    return
                }
                continue
            }
            recorder.updateMeters()
            let level = recorder.averagePower(forChannel: 0)
            let now = Date()
            if level > -42 {
                heardSpeech = true
                silentSince = nil
            } else if silentSince == nil {
                silentSince = now
            }
            let elapsed = now.timeIntervalSince(startedAt)
            if heardSpeech, let silentSince, now.timeIntervalSince(silentSince) >= 1.0, elapsed >= 1.0 {
                stopVoiceRecordingAndUpload()
                return
            }
            if !heardSpeech, elapsed >= 1.8 {
                cancelWakeWordVoiceRecordingAfterSilence()
                return
            }
            if elapsed >= 6.0 {
                if heardSpeech {
                    stopVoiceRecordingAndUpload()
                } else {
                    cancelWakeWordVoiceRecordingAfterSilence()
                }
                return
            }
        }
    }
    #endif

    #if canImport(Speech) && canImport(AVFoundation)
    private func requestSpeechAccess() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            log(.debug, "Speech recognition permission already granted; skipping system prompt")
            return true
        case .denied, .restricted:
            log(.warning, "Speech recognition permission is denied or restricted; opening system settings")
            openAppPermissionSettings()
            return false
        case .notDetermined:
            break
        @unknown default:
            log(.warning, "Speech recognition permission returned an unknown status: \(status.rawValue)")
            return false
        }

        log(.debug, "Requesting speech recognition permission; current_status=\(status.rawValue)")
        let authorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authorizationStatus in
                Task { @MainActor in
                    continuation.resume(returning: authorizationStatus)
                }
            }
        }
        let granted = authorizationStatus == .authorized
        log(.debug, "Speech recognition permission callback status=\(authorizationStatus.rawValue) granted=\(granted)")
        refreshPermissionStatuses()
        if !granted, authorizationStatus == .denied || authorizationStatus == .restricted {
            openAppPermissionSettings()
            schedulePermissionStatusRefreshes()
        }
        return granted
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
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, Self.bluetoothAudioSessionOption, .duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            #endif

            let engine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            let inputNode = engine.inputNode
            Self.installWakeWordAudioTap(on: inputNode, request: request)
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
                        self.log(.debug, "Wakeword transcript: \(transcript)")
                        if self.transcriptContainsWakeWord(transcript) {
                            self.triggerWakeWordCapture()
                            return
                        }
                    }
                    if let error {
                        self.log(.warning, "Wakeword listening failed: \(error.localizedDescription)")
                        self.stopWakeWordListening()
                        if let retryDelay = self.wakeWordRetryDelay(after: error) {
                            self.resumeWakeWordListeningIfNeeded(after: retryDelay)
                        } else {
                            self.wakeWordStatus = .unavailable
                        }
                    }
                }
            }
        } catch {
            wakeWordStatus = .unavailable
            log(.error, "Wakeword listening could not start: \(error.localizedDescription)")
        }
    }

    private nonisolated static func installWakeWordAudioTap(
        on inputNode: AVAudioInputNode,
        request: SFSpeechAudioBufferRecognitionRequest
    ) {
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    private func wakeWordRetryDelay(after error: Error) -> Duration? {
        let message = error.localizedDescription.lowercased()
        if message.contains("siri and dictation are disabled") {
            log(.warning, "Wakeword listening stopped because Siri and Dictation are disabled in macOS settings")
            return nil
        }
        if message.contains("no speech detected") {
            return .seconds(2)
        }
        return .milliseconds(500)
    }
    #endif

    private func transcriptContainsWakeWord(_ transcript: String) -> Bool {
        let normalizedTranscript = Self.normalizedWakeWordText(transcript)
        let wakeWordCandidates = Self.normalizedWakeWordCandidates(for: wakeWordPhrase)
        guard !wakeWordCandidates.isEmpty else {
            return false
        }
        return wakeWordCandidates.contains { normalizedTranscript.contains($0) }
    }

    static func normalizedWakeWordCandidates(for phrase: String) -> [String] {
        let normalizedPhrase = normalizedWakeWordText(phrase)
        guard !normalizedPhrase.isEmpty else {
            return []
        }

        var candidates = Set([normalizedPhrase])
        if normalizedPhrase.contains("dj") {
            candidates.insert(normalizedPhrase.replacingOccurrences(of: "dj", with: "dee jay"))
            candidates.insert(normalizedPhrase.replacingOccurrences(of: "dj", with: "deejay"))
            candidates.insert(normalizedPhrase.replacingOccurrences(of: "dj", with: "d j"))
        }
        if normalizedPhrase.contains("d j") {
            candidates.insert(normalizedPhrase.replacingOccurrences(of: "d j", with: "dj"))
            candidates.insert(normalizedPhrase.replacingOccurrences(of: "d j", with: "dee jay"))
            candidates.insert(normalizedPhrase.replacingOccurrences(of: "d j", with: "deejay"))
        }
        candidates = expandWakeWordToken(candidates, token: "okay", replacements: ["ok", "oke"])
        candidates = expandWakeWordToken(candidates, token: "ok", replacements: ["okay", "oke"])
        candidates = expandWakeWordToken(candidates, token: "oke", replacements: ["ok", "okay"])
        candidates = expandWakeWordToken(candidates, token: "nabu", replacements: ["naboo", "na boo", "nah boo"])
        candidates = expandWakeWordToken(candidates, token: "naboo", replacements: ["nabu", "na boo", "nah boo"])
        return candidates.sorted()
    }

    private static func expandWakeWordToken(
        _ candidates: Set<String>,
        token: String,
        replacements: [String]
    ) -> Set<String> {
        var output = candidates
        for candidate in candidates {
            let words = candidate.split(separator: " ").map(String.init)
            guard words.contains(token) else {
                continue
            }
            for replacement in replacements {
                output.insert(words.map { $0 == token ? replacement : $0 }.joined(separator: " "))
            }
        }
        return output
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
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, Self.bluetoothAudioSessionOption])
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
            recorder.isMeteringEnabled = true
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
            dismissWakeWordListeningMessage()
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

    private enum VoiceCue {
        case startListening
        case stopListening
    }

    private enum VoiceHaptic {
        case startListening
        case stopListening
        case response
    }

    private func playVoiceCue(_ cue: VoiceCue) {
        #if canImport(AudioToolbox) && os(iOS)
        let soundID: SystemSoundID
        switch cue {
        case .startListening:
            soundID = 1113
        case .stopListening:
            soundID = 1114
        }
        AudioServicesPlaySystemSound(soundID)
        #elseif canImport(AppKit) && os(macOS)
        let soundName: NSSound.Name
        switch cue {
        case .startListening:
            soundName = NSSound.Name("Pop")
        case .stopListening:
            soundName = NSSound.Name("Tink")
        }
        if let sound = NSSound(named: soundName) {
            sound.play()
        } else {
            NSSound.beep()
        }
        #else
        _ = cue
        #endif
    }

    private func playVoiceHaptic(_ haptic: VoiceHaptic) {
        #if canImport(UIKit) && os(iOS)
        switch haptic {
        case .startListening:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .stopListening:
            UISelectionFeedbackGenerator().selectionChanged()
        case .response:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #else
        _ = haptic
        #endif
    }

    nonisolated static func publicReleaseTag(version: String, clientType: DJConnectClientType) -> String {
        "\(clientType.rawValue)/v\(version)"
    }

    nonisolated static func publicReleaseNotesURL(version: String, clientType: DJConnectClientType) -> URL? {
        URL(string: "https://djconnect.dev/release-notes/\(clientType.rawValue)/v\(version).json")
    }

    nonisolated static func publicReleaseNotesURL(version: String, clientType: DJConnectClientType, language: String) -> URL? {
        let normalizedLanguage = normalizedReleaseNotesLanguageCode(language)
        return URL(string: "https://djconnect.dev/release-notes/\(clientType.rawValue)/\(normalizedLanguage)/v\(version).json")
    }

    nonisolated static func normalizedReleaseNotesLanguageCode(_ language: String) -> String {
        language.lowercased().hasPrefix("nl") ? "nl" : "en"
    }

    nonisolated static func githubReleaseNotesURL(version: String, clientType: DJConnectClientType) -> URL? {
        let encodedTag = publicReleaseTag(version: version, clientType: clientType)
            .replacingOccurrences(of: "/", with: "%2F")
        return URL(string: "https://api.github.com/repos/pcvantol/djconnect-app-releases/releases/tags/\(encodedTag)")
    }

    nonisolated static func publicDownloadsURL(clientType: DJConnectClientType) -> URL? {
        switch clientType {
        case .ios:
            URL(string: "https://djconnect.dev/ios#downloads")
        case .macos:
            URL(string: "https://djconnect.dev/macos#downloads")
        case .watchos:
            nil
        case .esp32:
            URL(string: "https://djconnect.dev")
        case .raspberryPi:
            nil
        }
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
