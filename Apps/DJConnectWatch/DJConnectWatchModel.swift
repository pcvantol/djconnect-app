@preconcurrency import AVFoundation
import CryptoKit
import DJConnectCore
import Network
import OSLog
#if canImport(Security)
import Security
#endif
#if canImport(Speech)
import Speech
#endif
import SwiftUI
@preconcurrency import UserNotifications
import WatchKit
#if canImport(WatchConnectivity)
@preconcurrency import WatchConnectivity
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

struct DJConnectWatchPushNotificationStatus: Equatable {
    enum State: Equatable {
        case registered
        case unavailable
        case actionNeeded
        case inactive
    }

    var state: State = .inactive
    var environment: DJConnectPushEnvironment?
    var lastError: String?
}

struct DJConnectWatchAskDJMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user
        case dj
    }

    enum CodingKeys: String, CodingKey {
        case id
        case serverID
        case clientMessageID
        case role
        case text
        case images
        case links
        case playbackActions
        case intentInfo = "intent"
        case items
        case audioURL
        case announcement
        case messageKind = "message_kind"
        case origin
        case textSource = "text_source"
        case isGeneratedText = "is_generated_text"
        case mood
        case createdAt
    }

    var id: UUID
    var serverID: String?
    var clientMessageID: String?
    var role: Role
    var text: String
    var images: [DJConnectResponseImage]
    var links: [DJConnectResponseLink]
    var playbackActions: [DJConnectAskDJPlaybackAction]
    var intentInfo: DJConnectAskDJIntentInfo?
    var items: [DJConnectAskDJHistoryItem]
    var audioURL: URL?
    var announcement: DJAnnouncement?
    var messageKind: DJConnectAskDJMessageKind
    var origin: String?
    var textSource: String?
    var isGeneratedText: Bool?
    var mood: Int?
    var createdAt: Date

    var renderablePlaybackActions: [DJConnectAskDJPlaybackAction] {
        playbackActions
    }

    init(
        id: UUID = UUID(),
        serverID: String? = nil,
        clientMessageID: String? = nil,
        role: Role,
        text: String,
        images: [DJConnectResponseImage] = [],
        links: [DJConnectResponseLink] = [],
        playbackActions: [DJConnectAskDJPlaybackAction] = [],
        intentInfo: DJConnectAskDJIntentInfo? = nil,
        items: [DJConnectAskDJHistoryItem] = [],
        audioURL: URL? = nil,
        announcement: DJAnnouncement? = nil,
        messageKind: DJConnectAskDJMessageKind = .assistant,
        origin: String? = nil,
        textSource: String? = nil,
        isGeneratedText: Bool? = nil,
        mood: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.serverID = serverID
        self.clientMessageID = clientMessageID
        self.role = role
        self.text = text
        self.images = images
        self.links = links
        self.playbackActions = playbackActions
        self.intentInfo = intentInfo
        self.items = items
        self.announcement = announcement
        self.audioURL = announcement?.clientReplayAudioURL ?? audioURL
        self.messageKind = messageKind
        self.origin = origin
        self.textSource = textSource
        self.isGeneratedText = isGeneratedText
        self.mood = mood.map { max(0, min(100, $0)) }
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        serverID = try container.decodeIfPresent(String.self, forKey: .serverID)
        clientMessageID = try container.decodeIfPresent(String.self, forKey: .clientMessageID)
        role = try container.decode(Role.self, forKey: .role)
        text = try container.decode(String.self, forKey: .text)
        images = try container.decodeIfPresent([DJConnectResponseImage].self, forKey: .images) ?? []
        links = try container.decodeIfPresent([DJConnectResponseLink].self, forKey: .links) ?? []
        playbackActions = try container.decodeIfPresent([DJConnectAskDJPlaybackAction].self, forKey: .playbackActions) ?? []
        intentInfo = try container.decodeIfPresent(DJConnectAskDJIntentInfo.self, forKey: .intentInfo)
        items = try container.decodeIfPresent([DJConnectAskDJHistoryItem].self, forKey: .items) ?? []
        audioURL = try container.decodeIfPresent(URL.self, forKey: .audioURL)
        announcement = try container.decodeIfPresent(DJAnnouncement.self, forKey: .announcement)
        if let announcement {
            audioURL = announcement.clientReplayAudioURL
        }
        messageKind = try container.decodeIfPresent(DJConnectAskDJMessageKind.self, forKey: .messageKind) ?? .assistant
        origin = try container.decodeIfPresent(String.self, forKey: .origin)
        textSource = try container.decodeIfPresent(String.self, forKey: .textSource)
        isGeneratedText = try container.decodeIfPresent(Bool.self, forKey: .isGeneratedText)
        mood = try container.decodeIfPresent(Int.self, forKey: .mood).map { max(0, min(100, $0)) }
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(serverID, forKey: .serverID)
        try container.encodeIfPresent(clientMessageID, forKey: .clientMessageID)
        try container.encode(role, forKey: .role)
        try container.encode(text, forKey: .text)
        try container.encode(images, forKey: .images)
        try container.encode(links, forKey: .links)
        try container.encode(playbackActions, forKey: .playbackActions)
        try container.encodeIfPresent(intentInfo, forKey: .intentInfo)
        try container.encode(items, forKey: .items)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encodeIfPresent(announcement, forKey: .announcement)
        try container.encode(messageKind, forKey: .messageKind)
        try container.encodeIfPresent(origin, forKey: .origin)
        try container.encodeIfPresent(textSource, forKey: .textSource)
        try container.encodeIfPresent(isGeneratedText, forKey: .isGeneratedText)
        try container.encodeIfPresent(mood, forKey: .mood)
        try container.encode(createdAt, forKey: .createdAt)
    }

}

struct DJConnectWatchToast: Identifiable, Equatable {
    let id = UUID()
    var text: String
}

struct DJConnectWatchLogLine: Identifiable, Equatable {
    let id = UUID()
    var text: String
}

enum DJConnectWatchAudioPlaybackState: Equatable {
    case idle
    case loading(URL)
    case playing(URL)
}

enum DJConnectWatchLogLevel: String, CaseIterable, Identifiable {
    case debug
    case info
    case warning
    case error

    var id: String { rawValue }

    func title(language: String) -> String {
        switch self {
        case .debug:
            return "Debug"
        case .info:
            return "Info"
        case .warning:
            return DJConnectLocalization.localized(key: "watch.warnings", language: language)
        case .error:
            return DJConnectLocalization.localized(key: "watch.errors", language: language)
        }
    }

    var priority: Int {
        switch self {
        case .debug:
            return 0
        case .info:
            return 1
        case .warning:
            return 2
        case .error:
            return 3
        }
    }
}

#if canImport(WatchConnectivity)
extension DJConnectWatchModel: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                companionPairingStatus = "iPhone companion niet beschikbaar"
                appendDiagnosticLog("Companion sessie activatie mislukt: \(error.localizedDescription)", level: .warning)
                return
            }
            companionPairingStatus = session.isReachable ? "iPhone verbonden" : "Open DJConnect op je iPhone"
            isCompanionReachable = session.isReachable
            sendCompanionPairingRegistration()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            companionPairingStatus = session.isReachable ? "iPhone verbonden" : "Open DJConnect op je iPhone"
            isCompanionReachable = session.isReachable
            if session.isReachable {
                sendCompanionPairingRegistration()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: message, requiringSecureCoding: false) else {
            return
        }
        Task { @MainActor in
            guard let message = Self.unarchiveCompanionMessage(data) else {
                return
            }
            handleCompanionMessage(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: userInfo, requiringSecureCoding: false) else {
            return
        }
        Task { @MainActor in
            guard let userInfo = Self.unarchiveCompanionMessage(data) else {
                return
            }
            handleCompanionMessage(userInfo)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: applicationContext, requiringSecureCoding: false) else {
            return
        }
        Task { @MainActor in
            guard let applicationContext = Self.unarchiveCompanionMessage(data) else {
                return
            }
            handleCompanionMessage(applicationContext)
        }
    }

    private static func unarchiveCompanionMessage(_ data: Data) -> [String: Any]? {
        let classes: [AnyClass] = [
            NSDictionary.self,
            NSArray.self,
            NSString.self,
            NSNumber.self,
            NSData.self
        ]
        return try? NSKeyedUnarchiver.unarchivedObject(ofClasses: classes, from: data) as? [String: Any]
    }
}
#endif

@MainActor
final class DJConnectWatchModel: NSObject, ObservableObject {
    private static let logger = Logger(subsystem: "dev.djconnect.watch", category: "runtime")

    enum ConnectionState: Equatable {
        case unpaired
        case pairing
        case paired
        case failed(String)
    }

    enum VoiceState: Equatable {
        case idle
        case recording
        case processing
        case failed(String)
    }

    enum VoiceActivationStatus: Equatable {
        case paused
        case listening
        case microphoneRequired
        case unavailable

        var title: String {
            switch self {
            case .paused:
                return "Gepauzeerd"
            case .listening:
                return "Luistert"
            case .microphoneRequired:
                return "Microfoon vereist"
            case .unavailable:
                return "Niet beschikbaar"
            }
        }
    }

    @AppStorage("haBaseURL") var haBaseURL = "http://homeassistant.local:8123"
    @AppStorage("apiBase") var apiBase = ""
    @AppStorage("voicePath") var voicePath = ""
    @AppStorage("statusPath") var statusPath = ""
    @AppStorage("eventPath") var eventPath = ""
    @AppStorage("askDJSupported") var askDJSupported = false
    @AppStorage("askDJVoiceSupported") var askDJVoiceSupported = false
    @AppStorage("askDJAudioResponseSupported") var askDJAudioResponseSupported = false
    @AppStorage("pairingCode") var pairingCode = DJConnectWatchModel.makePairingCode()
    @AppStorage("stableInstallID") private var stableInstallID = DJConnectWatchModel.makeStableInstallID()
    @AppStorage("paired") private var paired = false
    @AppStorage("demoMode") private var storedDemoMode = false
    @AppStorage("askDJMood") var askDJMood = 50.0
    @AppStorage("watchLogLevel") var watchLogLevel = DJConnectWatchLogLevel.info.rawValue
    @AppStorage("askDJHistoryRevision") private var askDJHistoryRevision = 0
    @AppStorage("askDJClearRevision") private var askDJClearRevision = 0
    @AppStorage("DJConnectWatchWelcomeSeen") private var welcomeSeen = false
    @AppStorage("watchVoiceActivationEnabled") private var storedVoiceActivationEnabled = false
    @AppStorage("DJConnectWatchMusicDNAOptInPromptSeen") private var musicDNAOptInPromptSeen = false
    @AppStorage("DJConnectWatchDemoMusicDNAEnabled") private var storedDemoMusicDNAEnabled = false
    @AppStorage("DJConnectWatchDemoMusicDNAOptInPromptSeen") private var demoMusicDNAOptInPromptSeen = false
    @Published private(set) var appLanguageOverrideCode = DJConnectLocalization.languageOverrideCode(
        UserDefaults.standard.string(forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
    )

    var language: String {
        DJConnectLocalization.resolvedLanguageCode(override: appLanguageOverrideCode)
    }

    var currentRequestLocale: String {
        DJConnectLocalization.bcp47LocaleIdentifier(for: language)
    }

    private var localizedDemoTrackInsights: [TrackInsight] {
        DemoTrackInsightService.localizedDefaultTracks(language: language)
    }

    @Published private(set) var connectionState: ConnectionState = .unpaired
    @Published private(set) var voiceState: VoiceState = .idle
    @Published private(set) var playback: DJConnectPlayback?
    @Published private(set) var currentTrackInsight: TrackInsight?
    @Published private(set) var isRefreshingStatus = false
    @Published private(set) var isRefreshingTrackInsight = false
    @Published private(set) var queueItems: [DJConnectQueueItem] = []
    @Published private(set) var queueContext: String?
    @Published private(set) var isLoadingQueue = false
    @Published private(set) var loadingQueueItemIndex: Int?
    @Published private(set) var availableOutputs: [DJConnectOutputDevice] = []
    @Published private(set) var selectedOutput = "Geen uitvoerapparaat geselecteerd"
    @Published private(set) var isLoadingOutputs = false
    @Published private(set) var loadingOutputID: String?
    @Published private(set) var playlistItems: [DJConnectPlaylist] = []
    @Published private(set) var isLoadingPlaylists = false
    @Published private(set) var loadingPlaylistID: String?
    @Published private(set) var responseImages: [DJConnectResponseImage] = []
    @Published private(set) var askDJMessages: [DJConnectWatchAskDJMessage] = []
    @Published private(set) var transientAskDJMoodMessage: DJConnectWatchAskDJMessage?
    @Published private(set) var askDJScrollRequestID: UUID?
    @Published private(set) var isCheckingAskDJHistoryState = true
    @Published private(set) var isClearingAskDJHistory = false
    @Published private(set) var isRequestingAskDJIdleSuggestion = false
    @Published private(set) var isLoadingMusicDNAConsent = false
    @Published private(set) var isUpdatingMusicDNAConsent = false
    @Published private(set) var musicDNAProfileResponse: DJConnectMusicDNAProfileResponse?
    @Published private(set) var isLoadingMusicDNA = false
    @Published private(set) var isUpdatingMusicDNA = false
    @Published private(set) var musicDNAErrorMessage: String?
    @Published private(set) var demoMusicDNAEnabled = false
    @Published private(set) var musicDiscoveryResponse: DJConnectMusicDiscoveryResponse?
    @Published private(set) var isLoadingMusicDiscovery = false
    @Published private(set) var isRefreshingMusicDiscovery = false
    @Published private(set) var musicDiscoveryErrorMessage: String?
    @Published private(set) var playingMusicDiscoveryItemID: String?
    @Published var isShowingMusicDNAOptInPrompt = false
    @Published private(set) var playingAskDJActionID: String?
    @Published private(set) var isSavingCurrentTrack = false
    @Published private(set) var askDJToast: DJConnectWatchToast?
    @Published private(set) var askDJAudioPlaybackState: DJConnectWatchAudioPlaybackState = .idle
    @Published private(set) var isShowingPairingSuccess = false
    @Published private(set) var isDemoMode = false
    @Published private(set) var diagnosticLogLines: [DJConnectWatchLogLine] = []
    @Published private(set) var companionPairingStatus = "iPhone companion zoeken..."
    @Published private(set) var iPhoneConnectionMode: DJConnectHAConnectionMode = .offline
    @Published private(set) var pushNotificationStatus = DJConnectWatchPushNotificationStatus()
    @Published private(set) var musicBackendSummary = DJConnectMusicBackendSummary()
    @Published private(set) var remoteSupported = false
    @Published private(set) var isWiFiAvailable = false
    @Published private(set) var hasEvaluatedNetwork = false
    @Published private(set) var isCompanionReachable = false
    @Published var isShowingMicrophonePermissionExplanation = false
    @Published var isShowingVoiceActivationPermissionExplanation = false
    @Published var isShowingAskDJNotificationPermissionExplanation = false
    @Published var isShowingWelcome = false
    @Published var statusMessage = "Niet gekoppeld"
    @Published private(set) var voiceActivationStatus: VoiceActivationStatus = .paused
    @Published private(set) var isAppForeground = true

    private let askDJMessagesKey = "DJConnectWatchAskDJMessages"
    private let legacyPushTokenKey = "DJConnectWatchPushToken"
    private let registeredPushTokenKey = "DJConnectWatchRegisteredPushToken"
    private let registeredPushTokenHashKey = "DJConnectWatchRegisteredPushTokenHash"
    private let registeredPushEnvironmentKey = "DJConnectWatchRegisteredPushEnvironment"
    private let registeredPushSignatureKey = "DJConnectWatchRegisteredPushSignature"
    private let pushSupportedKey = "DJConnectWatchPushSupported"
    private let pushRegisteredKey = "DJConnectWatchPushRegistered"
    private let pushEnvironmentStatusKey = "DJConnectWatchPushEnvironmentStatus"
    private let lastPushErrorKey = "DJConnectWatchLastPushError"
    private let maxDiagnosticLogLines = 80
    private let maxInteractiveWatchProxyRequestBytes = 55_000
    private let maxWatchVoiceWAVBytes = 32_000
    private let maxWatchVoiceRecordingDuration: TimeInterval = 4
    private let tokenStore = DJConnectUserDefaultsTokenStore(key: "DJConnectWatchDeviceToken")
    private let monkeyTestingMode: Bool
    private var networkMonitor: NWPathMonitor?
    private let networkMonitorQueue = DispatchQueue(label: "dev.djconnect.watch.network")
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var player: AVPlayer?
    private var audioPlaybackTask: Task<Void, Never>?
    private var runtimeDiagnosticsTask: Task<Void, Never>?
    private var speechSynthesizer: AVSpeechSynthesizer?
    private let askDJHistorySyncInterval: UInt64 = 20_000_000_000
    private var hasRequestedAskDJIdleSuggestion = false
    private var volumeCommandTask: Task<Void, Never>?
    private var playbackBeatSignature: String?
    private var lastMainScreenRefreshAt: Date?
    private var hasRequestedAskDJNotificationPermission = false
    private var pendingAskDJNotificationAuthorizationContinuation: CheckedContinuation<Bool, Never>?
    private var currentAPNsPushToken: String?
    private var shouldBypassMicrophonePermissionExplanationOnce = false
    private var shouldBypassVoiceActivationPermissionExplanationOnce = false
    private var voiceActivationAudioEngine: AVAudioEngine?
    private var voiceActivationCaptureTask: Task<Void, Never>?
    private var voiceActivationRestartTask: Task<Void, Never>?
    private var voiceActivationListenTimeoutTask: Task<Void, Never>?
    private var lastRuntimeMemoryLogBucket = -1
    private var hasAppliedDemoState = false
    #if canImport(WatchConnectivity)
    private var hasActivatedCompanionSession = false
    private var companionPairingRegistrationRetryTask: Task<Void, Never>?
    private var companionPairingRegistrationWatchdogTask: Task<Void, Never>?
    private var hasReceivedCompanionPairingReady = false
    private var pendingWatchProxyHARequests: [String: CheckedContinuation<DJConnectWatchProxyResponse, Never>] = [:]
    #endif
    #if canImport(Speech)
    private var voiceActivationRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var voiceActivationRecognitionTask: SFSpeechRecognitionTask?
    #endif

    init(monkeyTestingMode: Bool = false) {
        self.monkeyTestingMode = monkeyTestingMode
        super.init()
        pushNotificationStatus = Self.pushNotificationStatus()
        syncAppLanguageOverrideToSharedDefaults()
        demoMusicDNAEnabled = storedDemoMusicDNAEnabled
        askDJMessages = Self.loadAskDJMessages(key: askDJMessagesKey)
        isShowingWelcome = !welcomeSeen && !monkeyTestingMode
        if monkeyTestingMode {
            storedDemoMode = false
            isDemoMode = true
            welcomeSeen = true
            isShowingWelcome = false
            applyDemoState()
            appendDiagnosticLog("Watch gestart in monkey test demo modus")
        } else if storedDemoMode {
            isDemoMode = true
            applyDemoState()
            appendDiagnosticLog("Watch gestart in demo modus")
        } else {
            connectionState = paired ? .paired : .unpaired
            statusMessage = paired ? "Gereed" : "Niet gekoppeld"
            appendDiagnosticLog(paired ? "Watch gestart met bestaande koppeling" : "Watch gestart zonder koppeling")
            if paired {
                requestRemoteNotificationRegistration()
            } else {
                activateCompanionSession()
                sendCompanionPairingRegistration()
            }
        }
        appendDiagnosticLog("Version metadata: release_version=\(DJConnectApplicationVersion.releaseVersion); build_version=\(DJConnectApplicationVersion.buildVersion); protocol_version=\(DJConnectProtocolVersion.current)")
        if !isDemoMode {
            startNetworkMonitor()
        }
        if !isDemoMode {
            startRuntimeDiagnosticsMonitor()
        }
    }

    func setAppLanguageOverride(_ value: String) {
        let normalizedOverride = DJConnectLocalization.languageOverrideCode(value)
        guard normalizedOverride != appLanguageOverrideCode else {
            syncAppLanguageOverrideToSharedDefaults()
            return
        }
        appLanguageOverrideCode = normalizedOverride
        if normalizedOverride.isEmpty {
            UserDefaults.standard.removeObject(forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
        } else {
            UserDefaults.standard.set(normalizedOverride, forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
        }
        syncAppLanguageOverrideToSharedDefaults()
        reloadComplicationTimelinesForLanguageChange()
    }

    private func syncAppLanguageOverrideToSharedDefaults() {
        guard let sharedDefaults = UserDefaults(suiteName: DJConnectLocalization.appGroupIdentifier) else {
            return
        }
        if appLanguageOverrideCode.isEmpty {
            sharedDefaults.removeObject(forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
        } else {
            sharedDefaults.set(appLanguageOverrideCode, forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
        }
    }

    private func reloadComplicationTimelinesForLanguageChange() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    deinit {
        networkMonitor?.cancel()
        runtimeDiagnosticsTask?.cancel()
        companionPairingRegistrationRetryTask?.cancel()
        companionPairingRegistrationWatchdogTask?.cancel()
        voiceActivationCaptureTask?.cancel()
        voiceActivationRestartTask?.cancel()
        voiceActivationListenTimeoutTask?.cancel()
    }

    func requestRemoteNotificationRegistration() {
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            logPush("init platform=\(identity.platform.rawValue) client_type=\(identity.clientType.rawValue) bundle_id=\(Bundle.main.bundleIdentifier ?? "<missing>") app_version=\(identity.appVersion ?? "<missing>") app_build=\(DJConnectApplicationVersion.buildVersion) protocol_version=\(identity.protocolVersion ?? identity.firmware) env=\(Self.pushEnvironment.rawValue)")
            let authorized = await requestRemoteNotificationAuthorizationIfNeeded(center: center)
            guard authorized else {
                logPush("remote notification registration not started permission_granted=false", level: .warning)
                return
            }
            logPush("starting system remote notification registration")
            WKApplication.shared().registerForRemoteNotifications()
        }
    }

    func handleRemoteNotificationDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        guard !token.isEmpty else {
            logPush("received empty APNs token", level: .warning)
            return
        }
        currentAPNsPushToken = token
        UserDefaults.standard.removeObject(forKey: legacyPushTokenKey)
        logPush("received APNs token bytes=\(deviceToken.count) hex_length=\(token.count) token=\(Self.redactedPushToken(token))", level: .info)
        registerStoredPushTokenIfPossible()
    }

    func handleRemoteNotificationRegistrationError(_ error: Error) {
        logPush("system remote notification registration failed error=\(error.localizedDescription)", level: .warning)
    }

    func clearDiagnosticLog() {
        diagnosticLogLines.removeAll()
        appendDiagnosticLog("Logs gewist")
    }

    func dismissWelcome() {
        welcomeSeen = true
        isShowingWelcome = false
        appendDiagnosticLog("Welkom scherm gesloten", level: .debug)
    }

    func setWatchLogLevel(_ level: DJConnectWatchLogLevel) {
        guard watchLogLevel != level.rawValue else {
            return
        }
        watchLogLevel = level.rawValue
    }

    var isVoiceActivationEnabled: Bool {
        storedVoiceActivationEnabled
    }

    var voiceActivationStatusText: String {
        guard storedVoiceActivationEnabled else {
            return "Gepauzeerd"
        }
        return voiceActivationStatus.title
    }

    var voiceActivationDetailText: String {
        if !storedVoiceActivationEnabled {
            return "Geen wake word buiten de app. Zet stemactivatie aan om in de open Watch app met Hey DJ te starten."
        }
        switch voiceActivationStatus {
        case .listening:
            return "Alleen actief zolang DJConnect zichtbaar is."
        case .paused:
            return isAppForeground ? "Gepauzeerd tijdens opname, verwerking of wanneer Home Assistant niet beschikbaar is." : "Gepauzeerd omdat DJConnect niet zichtbaar is."
        case .microphoneRequired:
            return "Microfoon- en spraakherkenningstoestemming zijn nodig."
        case .unavailable:
            return "Stemactivatie is op deze Watch niet beschikbaar."
        }
    }

    func setVoiceActivationEnabled(_ enabled: Bool) {
        if enabled {
            enableVoiceActivation()
        } else {
            storedVoiceActivationEnabled = false
            shouldBypassVoiceActivationPermissionExplanationOnce = false
            cancelVoiceActivationScheduledTasks()
            stopVoiceActivationListening(status: .paused)
            appendDiagnosticLog("Stemactivatie uitgeschakeld")
        }
    }

    func handleAppForegroundChange(_ foreground: Bool) {
        guard isAppForeground != foreground else {
            if foreground {
                Task { await refreshStatus() }
            }
            return
        }
        isAppForeground = foreground
        if foreground {
            if !isDemoMode {
                startNetworkMonitor()
                startRuntimeDiagnosticsMonitor()
            }
            activateCompanionSession()
            sendCompanionPairingRegistration()
            updateVoiceActivationListening()
            Task { await refreshStatus() }
        } else {
            runtimeDiagnosticsTask?.cancel()
            runtimeDiagnosticsTask = nil
            stopNetworkMonitor()
            volumeCommandTask?.cancel()
            volumeCommandTask = nil
            cancelVoiceActivationScheduledTasks()
            stopVoiceActivationListening(status: .paused)
            cancelRecording(reason: "Opname gestopt omdat de Watch app niet meer zichtbaar is")
        }
    }

    private func appendDiagnosticLog(_ message: String, level: DJConnectWatchLogLevel = .info) {
        let message = DJConnectLogRedactor.redactText(message)
        switch level {
        case .debug:
            Self.logger.debug("\(message, privacy: .public)")
        case .info:
            Self.logger.info("\(message, privacy: .public)")
        case .warning:
            Self.logger.warning("\(message, privacy: .public)")
        case .error:
            Self.logger.error("\(message, privacy: .public)")
        }

        let configuredLevel = DJConnectWatchLogLevel(rawValue: watchLogLevel) ?? .info
        guard level.priority >= configuredLevel.priority else {
            return
        }
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        diagnosticLogLines.insert(DJConnectWatchLogLine(text: "\(timestamp) \(message)"), at: 0)
        if diagnosticLogLines.count > maxDiagnosticLogLines {
            diagnosticLogLines.removeLast(diagnosticLogLines.count - maxDiagnosticLogLines)
        }
    }

    private func startRuntimeDiagnosticsMonitor() {
        runtimeDiagnosticsTask?.cancel()
        runtimeDiagnosticsTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else {
                    return
                }
                self?.sampleRuntimeDiagnostics()
            }
        }
    }

    private func sampleRuntimeDiagnostics() {
        guard let memoryMB = Self.currentMemoryFootprintMB() else {
            return
        }
        let bucket = Int(memoryMB / 10)
        if bucket != lastRuntimeMemoryLogBucket || memoryMB >= 80 {
            lastRuntimeMemoryLogBucket = bucket
            appendDiagnosticLog(
                "Runtime geheugen: \(Int(memoryMB.rounded())) MB; wakeword=\(storedVoiceActivationEnabled ? "aan" : "uit"); voice=\(voiceActivationStatusText); paired=\(canUseBackend ? "ja" : "nee"); askdj=\(askDJMessages.count); logs=\(diagnosticLogLines.count)",
                level: memoryMB >= 80 ? .warning : .debug
            )
        }
        guard memoryMB >= 80, voiceActivationAudioEngine != nil else {
            return
        }
        storedVoiceActivationEnabled = false
        cancelVoiceActivationScheduledTasks()
        stopVoiceActivationListening(status: .paused)
        appendDiagnosticLog("Stemactivatie automatisch gestopt door hoge geheugendruk", level: .warning)
    }

    private static func currentMemoryFootprintMB() -> Double? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), reboundPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return nil
        }
        return Double(info.phys_footprint) / 1_048_576
    }

    private func startNetworkMonitor() {
        guard networkMonitor == nil else {
            return
        }
        let networkMonitor = NWPathMonitor()
        self.networkMonitor = networkMonitor
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isLocalNetworkReachable = path.status == .satisfied && !path.usesInterfaceType(.cellular)
            Task { @MainActor in
                guard let self else {
                    return
                }
                guard self.isWiFiAvailable != isLocalNetworkReachable || !self.hasEvaluatedNetwork else {
                    return
                }
                self.hasEvaluatedNetwork = true
                self.isWiFiAvailable = isLocalNetworkReachable
                if isLocalNetworkReachable {
                    self.appendDiagnosticLog("Lokaal netwerk beschikbaar")
                    if self.statusMessage == "Lokaal netwerk vereist voor koppelen"
                        || self.statusMessage == "WiFi vereist voor koppelen" {
                        self.statusMessage = self.paired ? "Gereed" : "Niet gekoppeld"
                    }
                } else {
                    self.appendDiagnosticLog("Lokaal netwerk niet beschikbaar", level: .warning)
                    if !self.isDemoMode {
                        self.statusMessage = "Lokaal netwerk vereist"
                    }
                }
            }
        }
        networkMonitor.start(queue: networkMonitorQueue)
    }

    private func stopNetworkMonitor() {
        networkMonitor?.cancel()
        networkMonitor = nil
    }

    var identity: DJConnectIdentity {
        return DJConnectIdentity(
            deviceID: "djconnect-watchos-\(stableInstallID)",
            deviceName: WKInterfaceDevice.current().name,
            clientType: .watchos,
            firmware: DJConnectProtocolVersion.current,
            appVersion: DJConnectApplicationVersion.releaseVersion,
            protocolVersion: DJConnectProtocolVersion.current,
            platform: .watchos
        )
    }

    var canUseBackend: Bool {
        guard !isDemoMode else {
            return false
        }
        guard case .paired = connectionState else {
            return false
        }
        return isCompanionPairingAvailable
    }

    var isOfflineModeActive: Bool {
        !isDemoMode && hasEvaluatedNetwork && !isWiFiAvailable && !isCompanionReachable
    }

    var canUseLocalPairingAPI: Bool {
        isCompanionPairingAvailable
    }

    var networkRequirementMessage: String? {
        canUseLocalPairingAPI ? nil : "Open DJConnect op je gekoppelde iPhone om deze Watch te koppelen."
    }

    var isCompanionPairingAvailable: Bool {
        #if canImport(WatchConnectivity)
        WCSession.isSupported() && isCompanionReachable
        #else
        false
        #endif
    }

    var volume: Double {
        get {
            DJConnectVolumeNormalizer.normalized(fromBackendPercent: currentPlaybackVolumePercent) ?? 0
        }
        set {
            let value = DJConnectVolumeNormalizer.backendPercent(fromNormalized: newValue)
            if playback == nil {
                playback = DJConnectPlayback()
            }
            playback?.volumePercent = value
            if playback?.device != nil {
                playback?.device?.volumePercent = value
            }
        }
    }

    var currentPlaybackVolumePercent: Int? {
        DJConnectVolumeNormalizer.validBackendPercent(playback?.volumePercent)
            ?? DJConnectVolumeNormalizer.validBackendPercent(playback?.device?.volumePercent)
    }

    var askDJMoodInt: Int {
        max(0, min(100, Int(askDJMood.rounded())))
    }

    var askDJMoodStepIndex: Int {
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

    var askDJMoodSteps: [(label: String, value: Int)] {
        [
            ("Chill", 0),
            ("Groove", 35),
            ("Energy", 70),
            ("Party", 100)
        ]
    }

    var askDJMoodLabel: String {
        askDJMoodSteps[askDJMoodStepIndex].label
    }

    func setAskDJMoodStep(_ index: Int) {
        let clampedIndex = max(0, min(askDJMoodSteps.count - 1, index))
        guard clampedIndex != askDJMoodStepIndex else {
            return
        }
        playMoodHaptic(stepIndex: clampedIndex)
        askDJMood = Double(askDJMoodSteps[clampedIndex].value)
        showMoodChangedMessage()
    }

    private func showMoodChangedMessage() {
        transientAskDJMoodMessage = DJConnectWatchAskDJMessage(
            role: .dj,
            text: "Mood ingesteld op \(askDJMoodLabel).",
            origin: "local_mood_change"
        )
        requestAskDJScrollToBottom()
    }

    var djStyle: String {
        "warm_radio_dj"
    }

    var musicDNAKey: String {
        identity.deviceID
    }

    private func activateCompanionSession() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported(), !hasActivatedCompanionSession else {
            return
        }
        hasActivatedCompanionSession = true
        WCSession.default.delegate = self
        WCSession.default.activate()
        isCompanionReachable = WCSession.default.isReachable
        companionPairingStatus = WCSession.default.isReachable ? "iPhone verbonden" : "Open DJConnect op je iPhone"
        #endif
    }

    func refreshNetworkAvailability() {
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            activateCompanionSession()
            isCompanionReachable = WCSession.default.activationState == .activated && WCSession.default.isReachable
            companionPairingStatus = isCompanionReachable ? "iPhone verbonden" : "Open DJConnect op je iPhone"
            if isCompanionReachable {
                sendCompanionPairingRegistration()
            }
        }
        #endif
        appendDiagnosticLog(
            isOfflineModeActive ? "Netwerkcheck: offline" : "Netwerkcheck: verbinding beschikbaar"
        )
    }

    private func sendCompanionPairingRegistration() {
        #if canImport(WatchConnectivity)
        activateCompanionSession()
        guard WCSession.default.activationState == .activated else {
            companionPairingStatus = "iPhone companion wordt geactiveerd..."
            scheduleCompanionPairingRegistrationRetry()
            return
        }
        companionPairingRegistrationRetryTask?.cancel()
        companionPairingRegistrationRetryTask = nil
        let identity = identity
        let message: [String: Any] = [
            "type": "watch_proxy_register",
            "device_id": identity.deviceID,
            "device_name": identity.deviceName,
            "client_type": identity.clientType.rawValue,
            "firmware": identity.firmware,
            "app_version": identity.appVersion ?? identity.firmware,
            "protocol_version": identity.protocolVersion ?? identity.firmware,
            "platform": identity.platform.rawValue,
            "pair_code": pairingCode,
            "paired": paired
        ]
        if !paired {
            hasReceivedCompanionPairingReady = false
            scheduleCompanionPairingRegistrationWatchdog()
        }
        do {
            try WCSession.default.updateApplicationContext(message)
        } catch {
            appendDiagnosticLog("Companion context kon niet worden bijgewerkt: \(error.localizedDescription)", level: .warning)
        }
        companionPairingStatus = WCSession.default.isReachable
            ? "Pairinggegevens naar iPhone gestuurd"
            : "Open DJConnect op je iPhone"
        if !WCSession.default.isReachable {
            WCSession.default.transferUserInfo(message)
        }
        #endif
    }

    private func scheduleCompanionPairingRegistrationRetry() {
        companionPairingRegistrationRetryTask?.cancel()
        companionPairingRegistrationRetryTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            await MainActor.run {
                guard let self, !self.paired, !Task.isCancelled else {
                    return
                }
                self.sendCompanionPairingRegistration()
            }
        }
    }

    private func scheduleCompanionPairingRegistrationWatchdog() {
        companionPairingRegistrationWatchdogTask?.cancel()
        companionPairingRegistrationWatchdogTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                guard let self, !self.paired, !self.hasReceivedCompanionPairingReady, !Task.isCancelled else {
                    return
                }
                self.sendCompanionPairingRegistration()
            }
        }
    }

    private func cancelCompanionPairingRegistrationWatchdog() {
        companionPairingRegistrationWatchdogTask?.cancel()
        companionPairingRegistrationWatchdogTask = nil
    }

    private func handleCompanionMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else {
            return
        }
        switch type {
        case "watch_proxy_ready":
            hasReceivedCompanionPairingReady = true
            cancelCompanionPairingRegistrationWatchdog()
            applyCompanionSummary(message)
            if paired {
                companionPairingStatus = WCSession.default.isReachable ? "Gekoppeld via iPhone" : "Open DJConnect op je iPhone"
                connectionState = .paired
                statusMessage = "Gereed"
            } else {
                companionPairingStatus = "Klaar om te koppelen"
                connectionState = .pairing
                statusMessage = "Wachten op Home Assistant via iPhone..."
            }
        case "watch_proxy_pair_result":
            hasReceivedCompanionPairingReady = true
            cancelCompanionPairingRegistrationWatchdog()
            applyCompanionPairingResult(message)
        case "watch_proxy_pair_request":
            companionPairingStatus = "iPhone koppelt Watch met Home Assistant..."
            statusMessage = companionPairingStatus
            connectionState = .pairing
        case "watch_proxy_forget":
            resetPairing()
        case "watch_proxy_ha_response":
            handleCompanionHAResponse(message)
        default:
            break
        }
    }

    private func applyCompanionSummary(_ message: [String: Any]) {
        if let rawMode = message["connection_mode"] as? String,
           let mode = DJConnectHAConnectionMode(rawValue: rawMode) {
            iPhoneConnectionMode = mode
        }
        if let supported = message["remote_supported"] as? Bool {
            remoteSupported = supported
        }
        musicBackendSummary = DJConnectMusicBackendSummary(
            musicBackend: nonEmptyString(message["music_backend"]),
            musicBackendName: nonEmptyString(message["music_backend_name"]),
            musicBackendAvailable: message["music_backend_available"] as? Bool,
            musicBackendRevision: (message["music_backend_revision"] as? NSNumber)?.intValue,
            musicBackendCapabilities: musicBackendSummary.musicBackendCapabilities,
            musicTargetPlayer: nonEmptyString(message["music_target_player_name"]).map {
                DJConnectMusicTargetPlayer(id: nil, name: $0)
            } ?? musicBackendSummary.musicTargetPlayer,
            musicBackendError: nonEmptyString(message["music_backend_error"])
        )
    }

    private func nonEmptyString(_ value: Any?) -> String? {
        let trimmed = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func applyCompanionPairingResult(_ message: [String: Any]) {
        guard let token = message["device_token"] as? String, !token.isEmpty else {
            companionPairingStatus = (message["message"] as? String) ?? "iPhone kon Watch-token niet ontvangen"
            statusMessage = companionPairingStatus
            return
        }
        do {
            try tokenStore.saveToken(token)
        } catch {
            companionPairingStatus = "Watch kon device-token niet opslaan"
            statusMessage = companionPairingStatus
            appendDiagnosticLog("Companion pairing token opslaan mislukt: \(error.localizedDescription)", level: .error)
            return
        }
        if let haURL = message["ha_base_url"] as? String, !haURL.isEmpty {
            haBaseURL = haURL
        }
        apiBase = nonEmptyString(message["api_base"]) ?? apiBase
        voicePath = nonEmptyString(message["voice_path"]) ?? voicePath
        statusPath = nonEmptyString(message["status_path"]) ?? statusPath
        eventPath = nonEmptyString(message["event_path"]) ?? eventPath
        if let supported = message["ask_dj_supported"] as? Bool {
            askDJSupported = supported
        }
        if let supported = message["ask_dj_voice_supported"] as? Bool {
            askDJVoiceSupported = supported
        }
        if let supported = message["ask_dj_audio_response_supported"] as? Bool {
            askDJAudioResponseSupported = supported
        }
        applyCompanionSummary(message)
        paired = true
        connectionState = .paired
        isShowingPairingSuccess = true
        statusMessage = "Succesvol gekoppeld via iPhone"
        companionPairingStatus = "Gekoppeld via iPhone"
        requestRemoteNotificationRegistration()
        Task { await refreshStatus() }
    }

    private func handleCompanionHAResponse(_ message: [String: Any]) {
        #if canImport(WatchConnectivity)
        guard let correlationID = message["correlation_id"] as? String,
              let continuation = pendingWatchProxyHARequests.removeValue(forKey: correlationID),
              let data = message["response"] as? Data,
              let response = try? JSONDecoder().decode(DJConnectWatchProxyResponse.self, from: data) else {
            return
        }
        continuation.resume(returning: response)
        #endif
    }

    private func sendCompanionHARequest<Response: Decodable>(
        _ operation: DJConnectWatchProxyOperation,
        payload: (any Encodable)? = nil,
        responseType: Response.Type = Response.self
    ) async throws -> Response {
        #if canImport(WatchConnectivity)
        activateCompanionSession()
        guard WCSession.default.activationState == .activated, WCSession.default.isReachable else {
            throw DJConnectError.invalidConfiguration("Open DJConnect op je iPhone.")
        }
        let payloadData: Data?
        if let payload {
            payloadData = try JSONEncoder().encode(AnyEncodable(payload))
        } else {
            payloadData = nil
        }
        let request = DJConnectWatchProxyRequest(operation: operation, payload: payloadData)
        let requestData = try JSONEncoder().encode(request)
        if operation == .voice, requestData.count > maxInteractiveWatchProxyRequestBytes {
            appendDiagnosticLog("Stemverzoek te groot voor iPhone proxy: \(requestData.count) bytes", level: .warning)
            throw DJConnectError.invalidConfiguration("Opname is te lang. Probeer een kortere Ask DJ opname.")
        }
        let correlationID = UUID().uuidString
        let response = await withCheckedContinuation { continuation in
            pendingWatchProxyHARequests[correlationID] = continuation
            WCSession.default.sendMessage(
                [
                    "type": "watch_proxy_ha_request",
                    "correlation_id": correlationID,
                    "request": requestData
                ],
                replyHandler: nil
            ) { [weak self] error in
                DispatchQueue.main.async { [weak self] in
                    guard let self,
                          let continuation = self.pendingWatchProxyHARequests.removeValue(forKey: correlationID) else {
                        return
                    }
                    let message = Self.watchProxySendFailureMessage(for: error)
                    self.appendDiagnosticLog("iPhone proxy niet bereikbaar: \(error.localizedDescription)", level: .warning)
                    continuation.resume(returning: DJConnectWatchProxyResponse(
                        success: false,
                        error: Self.watchProxySendFailureCode(for: error),
                        message: message
                    ))
                }
            }
        }
        guard response.success, let data = response.payload else {
            throw Self.errorFromCompanionProxy(response)
        }
        return try JSONDecoder().decode(Response.self, from: data)
        #else
        throw DJConnectError.invalidConfiguration("Open DJConnect op je iPhone.")
        #endif
    }

    private static func watchProxySendFailureCode(for error: Error) -> String {
        let nsError = error as NSError
        #if canImport(WatchConnectivity)
        if nsError.domain == WCError.errorDomain,
           nsError.code == WCError.Code.payloadTooLarge.rawValue {
            return "payload_too_large"
        }
        #endif
        return "iphone_unreachable"
    }

    private static func watchProxySendFailureMessage(for error: Error) -> String {
        let nsError = error as NSError
        #if canImport(WatchConnectivity)
        if nsError.domain == WCError.errorDomain,
           nsError.code == WCError.Code.payloadTooLarge.rawValue {
            return "Opname is te lang. Probeer een kortere Ask DJ opname."
        }
        #endif
        return "Open DJConnect op je iPhone."
    }

    private struct AnyEncodable: Encodable {
        let value: any Encodable

        init(_ value: any Encodable) {
            self.value = value
        }

        func encode(to encoder: Encoder) throws {
            try value.encode(to: encoder)
        }
    }

    private static func errorFromCompanionProxy(_ response: DJConnectWatchProxyResponse) -> DJConnectError {
        switch response.error {
        case "version_mismatch":
            return .versionMismatch(DJConnectVersionMismatch(message: response.message))
        case "auth_stale":
            return .authStale(statusCode: 401, message: response.message)
        case "backend_unavailable":
            return .backendUnavailable(message: response.message)
        case "route_missing":
            return .routeMissing(message: response.message)
        case "missing_token":
            return .missingToken
        case "not_configured":
            return .notConfigured(message: response.message)
        case "invalid_configuration", "iphone_unreachable":
            return .invalidConfiguration(response.message ?? "Open DJConnect op je iPhone.")
        default:
            return .network(message: response.message ?? "iPhone niet bereikbaar.")
        }
    }

    private var hasActiveNowPlaying: Bool {
        playback?.hasPlayback == true
            || playback?.isPlaying == true
            || playback?.trackName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func pair() async {
        guard !isDemoMode else {
            appendDiagnosticLog("Koppelen overgeslagen: demo modus actief", level: .debug)
            return
        }
        guard !paired else {
            connectionState = .paired
            return
        }
        activateCompanionSession()
        connectionState = .pairing
        isShowingPairingSuccess = false
        statusMessage = "Wachten op iPhone..."
        companionPairingStatus = "iPhone companion bereidt Watch-koppeling voor."
        sendCompanionPairingRegistration()
    }

    func dismissPairingSuccess() {
        isShowingPairingSuccess = false
        statusMessage = "Gereed"
    }

    func startDemoMode() {
        appendDiagnosticLog("Demo modus starten")
        cancelVoiceActivationScheduledTasks()
        stopVoiceActivationListening(status: .paused)
        stopNetworkMonitor()
        storedDemoMode = true
        isDemoMode = true
        runtimeDiagnosticsTask?.cancel()
        runtimeDiagnosticsTask = nil
        lastRuntimeMemoryLogBucket = -1
        paired = false
        isShowingPairingSuccess = false
        voiceState = .idle
        applyDemoState()
    }

    func stopDemoMode() {
        appendDiagnosticLog("Demo modus stoppen")
        cancelVoiceActivationScheduledTasks()
        stopVoiceActivationListening(status: .paused)
        storedDemoMode = false
        isDemoMode = false
        hasAppliedDemoState = false
        playback = nil
        playbackBeatSignature = nil
        currentTrackInsight = nil
        responseImages = []
        voiceState = .idle
        paired = false
        isShowingPairingSuccess = false
        connectionState = .unpaired
        statusMessage = "Demo modus gestopt"
        startRuntimeDiagnosticsMonitor()
        startNetworkMonitor()
        activateCompanionSession()
        sendCompanionPairingRegistration()
    }

    func refreshStatus(confirmAskDJBeat: Bool = false) async {
        guard !isDemoMode else {
            if !hasAppliedDemoState {
                applyDemoState()
            }
            return
        }
        guard isAppForeground else {
            appendDiagnosticLog("Status vernieuwen overgeslagen: app niet zichtbaar", level: .debug)
            return
        }
        guard canUseBackend else {
            appendDiagnosticLog("Status vernieuwen overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        guard !isRefreshingStatus else {
            appendDiagnosticLog("Status vernieuwen overgeslagen: refresh loopt al", level: .debug)
            return
        }
        isRefreshingStatus = true
        defer { isRefreshingStatus = false }
        appendDiagnosticLog("Status vernieuwen")
        do {
            let response: DJConnectEnvelope<DJConnectPlayback> = try await sendCompanionHARequest(
                .status,
                payload: statusPayload(screenState: "now_playing")
            )
            applyBackendSummary(response.musicBackendSummary)
            if let playback = response.playback ?? response.data,
               Self.hasMeaningfulPlaybackSnapshot(playback) {
                applyPlayback(playback, confirmAskDJBeat: confirmAskDJBeat)
            } else {
                appendDiagnosticLog("Status response bevatte geen playback snapshot", level: .debug)
            }
            statusMessage = "Bijgewerkt"
            appendDiagnosticLog("Status vernieuwd")
            registerStoredPushTokenIfPossible()
        } catch {
            statusMessage = Self.userMessage(for: error)
            appendDiagnosticLog("Status vernieuwen mislukt: \(statusMessage)", level: .error)
        }
    }

    func refreshTrackInsight() async {
        guard !isRefreshingTrackInsight else {
            return
        }
        if isDemoMode {
            if !hasAppliedDemoState {
                applyDemoState()
            } else if let playback {
                let demoTracks = localizedDemoTrackInsights
                currentTrackInsight = demoTracks.first { insight in
                    insight.title == playback.trackName && insight.artist == playback.artistName
                } ?? demoTracks.first
            } else {
                currentTrackInsight = localizedDemoTrackInsights.first
            }
            return
        }
        guard isAppForeground else {
            appendDiagnosticLog("Track Insight vernieuwen overgeslagen: app niet zichtbaar", level: .debug)
            return
        }
        guard canUseBackend else {
            appendDiagnosticLog("Track Insight vernieuwen overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        isRefreshingTrackInsight = true
        defer { isRefreshingTrackInsight = false }
        appendDiagnosticLog("Track Insight vernieuwen")
        do {
            let request = DJConnectTrackInsightRequest(
                title: playback?.trackName,
                artist: playback?.artistName,
                artworkURL: playback?.albumImageURL,
                durationMS: playback?.durationMS,
                progressMS: playback?.progressMS,
                entityID: nil,
                playerID: playback?.device?.id,
                musicBackend: musicBackendSummary.musicBackend,
                clientType: identity.clientType.rawValue,
                forceRefresh: true,
                locale: language,
                mood: askDJMoodInt,
                includeVisualProfile: true,
                includeRawResponse: true
            )
            currentTrackInsight = try await sendCompanionHARequest(.trackInsight, payload: request)
            statusMessage = "Track Insight bijgewerkt"
            appendDiagnosticLog("Track Insight vernieuwd")
        } catch {
            statusMessage = Self.userMessage(for: error)
            appendDiagnosticLog("Track Insight vernieuwen mislukt: \(statusMessage)", level: .error)
        }
    }

    func refreshMainScreenStatusIfNeeded() async {
        guard canUseBackend else {
            return
        }
        let now = Date()
        if let lastMainScreenRefreshAt,
           now.timeIntervalSince(lastMainScreenRefreshAt) < 5 {
            return
        }
        lastMainScreenRefreshAt = now
        await refreshStatus()
    }

    func sendCommand(_ command: String) async {
        if command == "play" || command == "pause" {
            playPlaybackToggleHaptic(isStarting: command == "play")
        }
        if isDemoMode {
            applyDemoCommand(command, value: nil)
            appendDiagnosticLog("Demo opdracht: \(command)")
            return
        }
        guard canUseBackend else {
            appendDiagnosticLog("Opdracht \(command) overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        appendDiagnosticLog("Opdracht verzenden: \(command)")
        do {
            let response: DJConnectCommandResponse = try await sendCompanionHARequest(
                .command,
                payload: DJConnectCommandPayload(identity: identity, command: command, language: currentRequestLocale, mood: askDJMoodInt)
            )
            applyBackendSummary(response.musicBackendSummary)
            if !Self.shouldDeferPlaybackSnapshotUntilRefresh(command) {
                applyPlayback(response.playback)
            }
            statusMessage = "Verzonden"
            appendDiagnosticLog("Opdracht gelukt: \(command)")
            if Self.shouldRefreshPlaybackAfterCommand(command) {
                await refreshStatus()
                if Self.shouldRefreshPlaybackAgainAfterCommand(command) {
                    try? await Task.sleep(nanoseconds: 850_000_000)
                    guard !Task.isCancelled else {
                        return
                    }
                    await refreshStatus()
                }
            }
        } catch {
            statusMessage = Self.userMessage(for: error)
            appendDiagnosticLog("Opdracht mislukt: \(command) - \(statusMessage)", level: .error)
        }
    }

    func saveCurrentTrack() async {
        guard !isSavingCurrentTrack else {
            return
        }
        let shouldFavorite = playback?.currentTrackFavoriteStatus != true
        if isDemoMode {
            applyDemoCommand("set_current_track_favorite", value: .bool(shouldFavorite))
            statusMessage = shouldFavorite ? "Toegevoegd aan favorieten" : "Uit favorieten gehaald"
            appendDiagnosticLog("Demo favoriet bijgewerkt")
            return
        }
        guard canUseBackend else {
            statusMessage = "Koppel eerst met Home Assistant."
            appendDiagnosticLog("Favoriet opslaan overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        isSavingCurrentTrack = true
        defer { isSavingCurrentTrack = false }
        appendDiagnosticLog(shouldFavorite ? "Favoriet opslaan" : "Favoriet verwijderen")
        do {
            let response: DJConnectCommandResponse = try await sendCompanionHARequest(
                .command,
                payload: DJConnectCommandPayload(
                    identity: identity,
                    command: "set_current_track_favorite",
                    value: .bool(shouldFavorite),
                    language: currentRequestLocale,
                    mood: askDJMoodInt
                )
            )
            applyBackendSummary(response.musicBackendSummary)
            if !Self.shouldDeferPlaybackSnapshotUntilRefresh("set_current_track_favorite") {
                applyPlayback(response.playback)
            }
            if response.success {
                statusMessage = shouldFavorite ? "Toegevoegd aan favorieten" : "Uit favorieten gehaald"
                appendDiagnosticLog("Favoriet bijgewerkt")
            } else {
                statusMessage = "Favorietstatus kon niet worden aangepast"
                appendDiagnosticLog("Favoriet aanpassen geweigerd: \(response.error ?? response.message ?? "onbekend")", level: .warning)
            }
        } catch {
            statusMessage = Self.userMessage(for: error)
            appendDiagnosticLog("Favoriet opslaan mislukt: \(statusMessage)", level: .error)
        }
    }

    func commitVolume() {
        let value = DJConnectVolumeNormalizer.backendPercent(fromNormalized: volume)
        volumeCommandTask?.cancel()
        volumeCommandTask = Task { [weak self] in
            await self?.sendVolume(value)
        }
    }

    private func sendVolume(_ value: Int) async {
        let value = DJConnectVolumeNormalizer.clampBackendPercent(value)
        if isDemoMode {
            await MainActor.run {
                self.volume = Double(value) / 100.0
                self.statusMessage = "Volume \(value)%"
                self.appendDiagnosticLog("Demo volume ingesteld: \(value)%")
            }
            return
        }
        guard canUseBackend else {
            appendDiagnosticLog("Volume instellen overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        appendDiagnosticLog("Volume instellen: \(value)%")
        do {
            let response: DJConnectCommandResponse = try await sendCompanionHARequest(
                .command,
                payload: DJConnectCommandPayload(
                    identity: identity,
                    command: "set_volume",
                    value: .int(value),
                    play: true,
                    language: currentRequestLocale,
                    mood: askDJMoodInt
                )
            )
            applyBackendSummary(response.musicBackendSummary)
            applyPlayback(response.playback)
            if playback?.volumePercent == nil {
                playback?.volumePercent = value
            }
            statusMessage = "Volume \(value)%"
            appendDiagnosticLog("Volume ingesteld: \(value)%")
            try? await Task.sleep(nanoseconds: 850_000_000)
            guard !Task.isCancelled else {
                return
            }
            await refreshStatus()
        } catch {
            statusMessage = Self.userMessage(for: error)
            appendDiagnosticLog("Volume instellen mislukt: \(statusMessage)", level: .error)
        }
    }

    func loadPlaylists() async {
        if isDemoMode {
            applyDemoPlaylists()
            appendDiagnosticLog("Demo afspeellijsten geladen")
            return
        }
        guard canUseBackend else {
            appendDiagnosticLog("Afspeellijsten laden overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        guard !isLoadingPlaylists else {
            return
        }
        appendDiagnosticLog("Afspeellijsten laden")
        isLoadingPlaylists = true
        defer { isLoadingPlaylists = false }
        do {
            let response: DJConnectCommandResponse = try await sendCompanionHARequest(
                .command,
                payload: DJConnectCommandPayload(identity: identity, command: "playlists", limit: 100, language: currentRequestLocale, mood: askDJMoodInt)
            )
            applyBackendSummary(response.musicBackendSummary)
            playlistItems = normalizedPlaylists(response.playlists ?? [])
            statusMessage = playlistItems.isEmpty ? "Geen afspeellijsten" : "Afspeellijsten bijgewerkt"
            appendDiagnosticLog("Afspeellijsten bijgewerkt: \(playlistItems.count) items")
        } catch {
            statusMessage = Self.userMessage(for: error)
            appendDiagnosticLog("Afspeellijsten laden mislukt: \(statusMessage)", level: .error)
        }
    }

    func loadQueue() async {
        if isDemoMode {
            applyDemoQueue()
            appendDiagnosticLog("Demo wachtrij geladen")
            return
        }
        guard canUseBackend else {
            appendDiagnosticLog("Wachtrij laden overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        guard !isLoadingQueue else {
            return
        }
        appendDiagnosticLog("Wachtrij laden")
        isLoadingQueue = true
        defer { isLoadingQueue = false }
        do {
            let response: DJConnectCommandResponse = try await sendCompanionHARequest(
                .command,
                payload: DJConnectCommandPayload(identity: identity, command: "queue", limit: 100, language: currentRequestLocale, mood: askDJMoodInt)
            )
            applyBackendSummary(response.musicBackendSummary)
            queueItems = normalizedQueueItems(response.queue ?? [])
            if let responseQueueContext = response.queueContext?.trimmingCharacters(in: .whitespacesAndNewlines),
               !responseQueueContext.isEmpty {
                queueContext = responseQueueContext
            }
            statusMessage = queueItems.isEmpty ? "Geen wachtrij" : "Wachtrij bijgewerkt"
            appendDiagnosticLog("Wachtrij bijgewerkt: \(queueItems.count) items")
        } catch {
            statusMessage = Self.userMessage(for: error)
            appendDiagnosticLog("Wachtrij laden mislukt: \(statusMessage)", level: .error)
        }
    }

    private func normalizedQueueItems(_ items: [DJConnectQueueItem]) -> [DJConnectQueueItem] {
        var seenCounts: [String: Int] = [:]
        return items.map { item in
            var item = item
            item.albumImageURL = resolvedArtworkURL(item.albumImageURL)
            let signature = queueItemSignature(item)
            let occurrence = seenCounts[signature, default: 0]
            seenCounts[signature] = occurrence + 1
            if occurrence > 0 {
                item.id = "\(item.id)#\(occurrence + 1)"
            }
            return item
        }
    }

    private func normalizedPlaylists(_ playlists: [DJConnectPlaylist]) -> [DJConnectPlaylist] {
        playlists.map { playlist in
            var playlist = playlist
            playlist.imageURL = resolvedArtworkURL(playlist.imageURL)
            return playlist
        }
    }

    private func queueItemSignature(_ item: DJConnectQueueItem) -> String {
        [
            item.uri,
            item.title,
            item.artist,
            item.album,
            item.durationMS.map(String.init)
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .joined(separator: "|")
    }

    func loadOutputs() async {
        if isDemoMode {
            applyDemoOutputs()
            appendDiagnosticLog("Demo uitvoerapparaten geladen")
            return
        }
        guard canUseBackend else {
            appendDiagnosticLog("Uitvoerapparaten laden overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        guard !isLoadingOutputs else {
            return
        }
        appendDiagnosticLog("Uitvoerapparaten laden")
        isLoadingOutputs = true
        defer { isLoadingOutputs = false }
        do {
            let response: DJConnectCommandResponse = try await sendCompanionHARequest(
                .command,
                payload: DJConnectCommandPayload(identity: identity, command: "devices", language: currentRequestLocale, mood: askDJMoodInt)
            )
            applyBackendSummary(response.musicBackendSummary)
            applyOutputs(response.devices ?? [])
            statusMessage = availableOutputs.count <= 1 ? "Geen uitvoerapparaten" : "Uitvoer bijgewerkt"
            appendDiagnosticLog("Uitvoerapparaten bijgewerkt: \(max(availableOutputs.count - 1, 0)) gevonden")
        } catch {
            statusMessage = Self.userMessage(for: error)
            appendDiagnosticLog("Uitvoerapparaten laden mislukt: \(statusMessage)", level: .error)
        }
    }

    func selectOutput(_ output: DJConnectOutputDevice) async {
        appendDiagnosticLog("Uitvoer geselecteerd: \(output.name)")
        selectedOutput = output.name
        if Self.isSyntheticOutput(output) {
            availableOutputs = availableOutputs.map { candidate in
                var updated = candidate
                updated.active = candidate.id == output.id || candidate.name == output.name
                return updated
            }
            return
        }
        if isDemoMode {
            loadingOutputID = output.id
            applyDemoCommand("set_output", value: .string(output.name))
            loadingOutputID = nil
            appendDiagnosticLog("Demo uitvoer ingesteld: \(output.name)")
            return
        }
        guard canUseBackend else {
            appendDiagnosticLog("Uitvoer instellen overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        loadingOutputID = output.id
        defer { loadingOutputID = nil }
        do {
            let response: DJConnectCommandResponse = try await sendCompanionHARequest(
                .command,
                payload: DJConnectCommandPayload(
                    identity: identity,
                    command: "set_output",
                    value: .string(output.name),
                    play: true,
                    language: currentRequestLocale,
                    mood: askDJMoodInt
                )
            )
            applyBackendSummary(response.musicBackendSummary)
            applyPlayback(response.playback)
            guard response.success else {
                statusMessage = cachedSpotifyOutputFailureMessage(for: output)
                appendDiagnosticLog("Uitvoer instellen mislukt: \(statusMessage)", level: .error)
                return
            }
            statusMessage = "Uitvoer ingesteld"
            appendDiagnosticLog("Uitvoer ingesteld: \(output.name)")
        } catch {
            statusMessage = output.isCachedSpotifyOutput ? cachedSpotifyOutputFailureMessage(for: output) : Self.userMessage(for: error)
            appendDiagnosticLog("Uitvoer instellen mislukt: \(statusMessage)", level: .error)
        }
    }

    func canStartQueueItem(_ item: DJConnectQueueItem) -> Bool {
        item.uri?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func startQueueItem(_ item: DJConnectQueueItem, at index: Int) async {
        guard let uri = item.uri?.trimmingCharacters(in: .whitespacesAndNewlines), !uri.isEmpty else {
            appendDiagnosticLog("Wachtrij-item starten overgeslagen: geen URI", level: .warning)
            return
        }
        playQueueItemStartHaptic()
        if isDemoMode {
            loadingQueueItemIndex = index
            applyDemoCommand("play_context_at", value: .object(queueStartPayload(for: item, uri: uri, index: index)))
            removeStartedQueueItem(item, at: index)
            loadingQueueItemIndex = nil
            appendDiagnosticLog("Demo wachtrij-item gestart: \(item.title)")
            return
        }
        guard canUseBackend else {
            appendDiagnosticLog("Wachtrij-item starten overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        appendDiagnosticLog("Wachtrij-item starten: \(item.title)")
        loadingQueueItemIndex = index
        defer { loadingQueueItemIndex = nil }
        do {
            let response: DJConnectCommandResponse = try await sendCompanionHARequest(
                .command,
                payload: DJConnectCommandPayload(
                    identity: identity,
                    command: "play_context_at",
                    value: .object(queueStartPayload(for: item, uri: uri, index: index)),
                    play: true,
                    language: currentRequestLocale,
                    mood: askDJMoodInt
                )
            )
            applyBackendSummary(response.musicBackendSummary)
            applyPlayback(response.playback)
            removeStartedQueueItem(item, at: index)
            statusMessage = "Nummer gestart"
            try? await Task.sleep(nanoseconds: 650_000_000)
            await loadQueue()
        } catch {
            statusMessage = Self.userMessage(for: error)
            appendDiagnosticLog("Wachtrij-item starten mislukt: \(statusMessage)", level: .error)
        }
    }

    func startPlaylist(_ playlist: DJConnectPlaylist) async {
        playPlaylistStartHaptic()
        if isDemoMode {
            loadingPlaylistID = playlist.id
            applyDemoCommand("start_playlist", value: .string(playlist.commandValue))
            loadingPlaylistID = nil
            appendDiagnosticLog("Demo afspeellijst gestart: \(playlist.name)")
            return
        }
        guard canUseBackend else {
            appendDiagnosticLog("Afspeellijst starten overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        appendDiagnosticLog("Afspeellijst starten: \(playlist.name)")
        loadingPlaylistID = playlist.id
        defer { loadingPlaylistID = nil }
        do {
            let response: DJConnectCommandResponse = try await sendCompanionHARequest(
                .command,
                payload: DJConnectCommandPayload(
                    identity: identity,
                    command: "start_playlist",
                    value: .string(playlist.commandValue),
                    play: true,
                    language: currentRequestLocale,
                    mood: askDJMoodInt
                )
            )
            applyBackendSummary(response.musicBackendSummary)
            applyPlayback(response.playback)
            statusMessage = "Afspeellijst gestart"
            appendDiagnosticLog("Afspeellijst gestart: \(playlist.name)")
        } catch {
            statusMessage = Self.userMessage(for: error)
            appendDiagnosticLog("Afspeellijst starten mislukt: \(statusMessage)", level: .error)
        }
    }

    func toggleRecording() {
        switch voiceState {
        case .recording:
            stopRecordingAndSend()
        case .idle, .failed:
            startRecording()
        case .processing:
            break
        }
    }

    func resetPairing() {
        appendDiagnosticLog("Koppeling resetten")
        cancelVoiceActivationScheduledTasks()
        stopVoiceActivationListening(status: .paused)
        unregisterPushNotifications()
        try? tokenStore.clearToken()
        currentAPNsPushToken = nil
        UserDefaults.standard.removeObject(forKey: legacyPushTokenKey)
        UserDefaults.standard.removeObject(forKey: registeredPushTokenKey)
        UserDefaults.standard.removeObject(forKey: registeredPushTokenHashKey)
        UserDefaults.standard.removeObject(forKey: registeredPushEnvironmentKey)
        UserDefaults.standard.removeObject(forKey: registeredPushSignatureKey)
        UserDefaults.standard.removeObject(forKey: pushRegisteredKey)
        UserDefaults.standard.removeObject(forKey: pushEnvironmentStatusKey)
        UserDefaults.standard.removeObject(forKey: lastPushErrorKey)
        refreshPushNotificationStatus()
        apiBase = ""
        voicePath = ""
        statusPath = ""
        eventPath = ""
        askDJSupported = false
        askDJVoiceSupported = false
        askDJAudioResponseSupported = false
        paired = false
        storedDemoMode = false
        isDemoMode = false
        pairingCode = Self.makePairingCode()
        playback = nil
        playbackBeatSignature = nil
        currentTrackInsight = nil
        isRefreshingStatus = false
        queueItems = []
        queueContext = nil
        loadingQueueItemIndex = nil
        isLoadingQueue = false
        availableOutputs = []
        selectedOutput = Self.noOutputName
        loadingOutputID = nil
        isLoadingOutputs = false
        playlistItems = []
        loadingPlaylistID = nil
        isLoadingPlaylists = false
        responseImages = []
        clearAskDJHistoryLocally()
        connectionState = .unpaired
        voiceState = .idle
        isShowingPairingSuccess = false
        statusMessage = "Niet gekoppeld"
        companionPairingStatus = "iPhone companion zoeken..."
        activateCompanionSession()
        sendCompanionPairingRegistration()
    }

    private func applyOutputs(_ devices: [DJConnectOutputDevice]) {
        let normalizedDevices = normalizedOutputDevices(devicesApplyingCurrentPlayback(to: devices))
        availableOutputs = normalizedDevices
        if let active = normalizedDevices.first(where: { $0.active == true }) {
            selectedOutput = active.name
        } else if selectedOutput == "Not selected" || selectedOutput == "No output selected" {
            selectedOutput = Self.noOutputName
        }
    }

    private func normalizedOutputDevices(_ devices: [DJConnectOutputDevice]) -> [DJConnectOutputDevice] {
        let backendDevices = devices.filter { $0.id != Self.syntheticNoOutputID && $0.name != Self.noOutputName }
        let backendHasActiveDevice = backendDevices.contains { $0.active == true }
        var localNone = DJConnectOutputDevice(
            id: Self.syntheticNoOutputID,
            name: Self.noOutputName,
            type: "local",
            active: !backendHasActiveDevice && selectedOutput == Self.noOutputName
        )
        localNone.supportsVolume = false
        return [localNone] + backendDevices
    }

    private func devicesApplyingCurrentPlayback(to devices: [DJConnectOutputDevice]) -> [DJConnectOutputDevice] {
        guard let playbackDevice = playback?.device else {
            return devices
        }
        let playbackID = playbackDevice.id?.trimmingCharacters(in: .whitespacesAndNewlines)
        let playbackName = playbackDevice.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard playbackID?.isEmpty == false || playbackName?.isEmpty == false else {
            return devices
        }
        return devices.map { output in
            var updated = output
            if output.matchesPlaybackDevice(id: playbackID, name: playbackName) {
                updated.active = true
            }
            return updated
        }
    }

    private func cachedSpotifyOutputFailureMessage(for output: DJConnectOutputDevice) -> String {
        output.isCachedSpotifyOutput
            ? DJConnectLocalization.localized(key: "appModel.cached.spotify.output.unavailable", language: language)
            : "Home Assistant gaf geen antwoord."
    }

    private static let syntheticNoOutputID = "djconnect-output-none"
    private static let noOutputName = "Geen uitvoerapparaat geselecteerd"

    private static func isSyntheticOutput(_ output: DJConnectOutputDevice) -> Bool {
        output.id == syntheticNoOutputID
    }

    private func queueStartPayload(for item: DJConnectQueueItem, uri: String, index: Int) -> [String: String] {
        var payload = [
            "uri": uri,
            "title": item.title,
            "index": String(index)
        ]
        if let artist = item.artist, !artist.isEmpty {
            payload["artist"] = artist
        }
        if let contextURI = resolvedQueueContext, !contextURI.isEmpty {
            payload["context_uri"] = contextURI
            if Self.queueContextSupportsOffset(contextURI) {
                payload["offset_uri"] = uri
            }
        }
        return payload
    }

    private func removeStartedQueueItem(_ item: DJConnectQueueItem, at index: Int) {
        if queueItems.indices.contains(index), queueItems[index].id == item.id {
            queueItems.remove(at: index)
            return
        }
        queueItems.removeAll { $0.id == item.id }
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

    private func applyPlayback(_ nextPlayback: DJConnectPlayback?, confirmAskDJBeat: Bool = false) {
        let previousSignature = playbackBeatSignature ?? Self.playbackBeatSignature(for: playback)
        var sanitizedPlayback = DJConnectVolumeNormalizer.sanitizedPlayback(nextPlayback)
        let resolvedAlbumImageURL = resolvedArtworkURL(sanitizedPlayback?.albumImageURL)
        sanitizedPlayback?.albumImageURL = resolvedAlbumImageURL
        playback = sanitizedPlayback
        if !hasActiveNowPlaying || !currentTrackInsightMatchesPlayback() {
            currentTrackInsight = nil
        }
        applyActiveOutput(from: sanitizedPlayback)
        let nextSignature = Self.playbackBeatSignature(for: sanitizedPlayback)
        playbackBeatSignature = nextSignature

        guard confirmAskDJBeat,
              let nextSignature,
              nextSignature != previousSignature else {
            return
        }
        playAskDJBeatConfirmHaptic()
            appendDiagnosticLog("Ask DJ beat confirm")
    }

    private func currentTrackInsightMatchesPlayback() -> Bool {
        guard let insight = currentTrackInsight else {
            return true
        }
        return trackInsightMatchesPlayback(insight)
    }

    private func trackInsightMatchesPlayback(_ insight: TrackInsight) -> Bool {
        guard let playback else {
            return false
        }
        return Self.normalizedTrackIdentity(insight.title) == Self.normalizedTrackIdentity(playback.trackName)
            && Self.normalizedTrackIdentity(insight.artist) == Self.normalizedTrackIdentity(playback.artistName)
    }

    private static func normalizedTrackIdentity(_ value: String?) -> String {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) ?? ""
    }

    private func applyActiveOutput(from playback: DJConnectPlayback?) {
        guard let device = playback?.device else {
            return
        }
        let deviceName = device.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let deviceID = device.id?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard deviceName?.isEmpty == false || deviceID?.isEmpty == false else {
            return
        }

        if let deviceName, !deviceName.isEmpty {
            selectedOutput = deviceName
        }

        guard !availableOutputs.isEmpty else {
            return
        }
        var didMatchOutput = false
        availableOutputs = availableOutputs.map { output in
            var updated = output
            let matchesID = deviceID?.isEmpty == false && output.id == deviceID
            let matchesName = deviceName?.isEmpty == false && output.name == deviceName
            updated.active = matchesID || matchesName
            didMatchOutput = didMatchOutput || updated.active == true
            return updated
        }

        if !didMatchOutput, let deviceName, !deviceName.isEmpty, selectedOutput == deviceName {
            appendDiagnosticLog("Actief uitvoerapparaat uit playback: \(deviceName)", level: .debug)
        }
    }

    private func applyBackendSummary(_ summary: DJConnectMusicBackendSummary) {
        musicBackendSummary = summary
        if summary.musicBackendAvailable == false {
            statusMessage = summary.musicBackendError ?? "Muziekbackend niet beschikbaar"
        }
    }

    private static func hasMeaningfulPlaybackSnapshot(_ playback: DJConnectPlayback) -> Bool {
        playback.hasPlayback != nil
            || playback.isPlaying != nil
            || playback.trackName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || playback.artistName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || playback.albumImageURL != nil
            || playback.progressMS != nil
            || playback.durationMS != nil
            || playback.volumePercent != nil
            || playback.shuffle != nil
            || playback.repeatState != nil
            || playback.device != nil
            || playback.contextURI?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private static func shouldRefreshPlaybackAfterCommand(_ command: String) -> Bool {
        switch command {
        case "play", "pause", "next", "previous", "set_output", "start_playlist", "start_liked_proxy", "play_context_at", "set_current_track_favorite", "save_current_track":
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

    private static func shouldDeferPlaybackSnapshotUntilRefresh(_ command: String) -> Bool {
        switch command {
        case "next", "previous":
            true
        default:
            false
        }
    }

    private func playAskDJBeatConfirmHaptic() {
        playWatchHaptic(.click)
    }

    private func playVoiceHaptic(_ haptic: VoiceHaptic) {
        switch haptic {
        case .startListening:
            playWatchHaptic(.start)
        case .stopListening:
            playWatchHaptic(.stop)
        case .response:
            playWatchHaptic(.success)
        }
    }

    private func playMoodHaptic(stepIndex: Int) {
        switch stepIndex {
        case 0:
            playWatchHaptic(.click)
        case 1:
            playWatchHaptic(.directionUp)
        case 2:
            playWatchHaptic(.start)
        default:
            playWatchHaptic(.success)
        }
    }

    private func playPlaybackToggleHaptic(isStarting: Bool) {
        playWatchHaptic(isStarting ? .start : .click)
    }

    private func playQueueItemStartHaptic() {
        playWatchHaptic(.directionUp)
    }

    private func playPlaylistStartHaptic() {
        playWatchHaptic(.start)
    }

    private func playMusicDiscoveryStartHaptic() {
        playWatchHaptic(.start)
    }

    private func playAskDJSendHaptic() {
        playWatchHaptic(.click)
    }

    private func playAskDJActionHaptic() {
        playWatchHaptic(.directionUp)
    }

    private func playAskDJResponseHaptic() {
        playWatchHaptic(.success)
    }

    private func playWatchHaptic(_ haptic: WKHapticType) {
        #if targetEnvironment(simulator)
        return
        #else
        WKInterfaceDevice.current().play(haptic)
        #endif
    }

    private enum VoiceHaptic {
        case startListening
        case stopListening
        case response
    }

    private static func playbackBeatSignature(for playback: DJConnectPlayback?) -> String? {
        let parts = [
            playback?.trackName,
            playback?.artistName,
            playback?.contextURI
        ]
        .compactMap { value -> String? in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed.lowercased()
        }

        guard !parts.isEmpty else {
            return nil
        }
        return parts.joined(separator: "|")
    }

    private static func queueContextSupportsOffset(_ contextURI: String) -> Bool {
        contextURI.hasPrefix("spotify:playlist:")
            || contextURI.hasPrefix("spotify:album:")
            || contextURI.hasPrefix("spotify:show:")
    }

    func clearAskDJHistory() async {
        guard !isClearingAskDJHistory else {
            return
        }
        guard canUseBackend else {
            clearAskDJHistoryLocally()
            return
        }
        isClearingAskDJHistory = true
        defer { isClearingAskDJHistory = false }
        do {
            let response: DJConnectAskDJHistoryResponse = try await sendCompanionHARequest(
                .clearAskDJHistory,
                payload: DJConnectAskDJClearHistoryRequest(identity: identity, musicDNAKey: musicDNAKey)
            )
            clearAskDJHistoryLocally()
            applyAskDJHistory(response, forceClear: response.isClearAcknowledged)
        } catch {
            statusMessage = Self.userMessage(for: error)
            showAskDJToast(Self.askDJToastText(for: error))
        }
    }

    func prepareAskDJHistoryForDisplay() async {
        guard canUseBackend else {
            isCheckingAskDJHistoryState = false
            return
        }
        isCheckingAskDJHistoryState = true
        defer { isCheckingAskDJHistoryState = false }
        await syncAskDJHistory(showErrors: true)
    }

    func prepareMusicDNAConsentPromptIfNeeded() async {
        let promptSeen = isDemoMode ? demoMusicDNAOptInPromptSeen : musicDNAOptInPromptSeen
        guard (isDemoMode || canUseBackend),
              !promptSeen,
              !isShowingMusicDNAOptInPrompt,
              !isLoadingMusicDNAConsent,
              !isUpdatingMusicDNAConsent else {
            return
        }
        if isDemoMode {
            applyDemoMusicDNAProfile()
            if musicDNAProfileResponse?.enabled == true {
                demoMusicDNAOptInPromptSeen = true
            } else {
                isShowingMusicDNAOptInPrompt = true
            }
            return
        }
        isLoadingMusicDNAConsent = true
        defer { isLoadingMusicDNAConsent = false }
        do {
            let response: DJConnectMusicDNAProfileResponse = try await sendCompanionHARequest(
                .musicDNAProfile,
                payload: DJConnectMusicDNAIdentityRequest(identity: identity, mood: askDJMoodInt)
            )
            applyMusicDNAProfile(response)
            if response.enabled {
                musicDNAOptInPromptSeen = true
            } else {
                isShowingMusicDNAOptInPrompt = true
            }
        } catch {
            appendDiagnosticLog("Music DNA consent status ophalen mislukt: \(Self.userMessage(for: error))", level: .warning)
        }
    }

    func refreshMusicDNAProfile() async {
        if isDemoMode {
            applyDemoMusicDNAProfile()
            return
        }
        guard canUseBackend else {
            musicDNAProfileResponse = nil
            musicDNAErrorMessage = nil
            isLoadingMusicDNA = false
            return
        }
        isLoadingMusicDNA = true
        musicDNAErrorMessage = nil
        defer { isLoadingMusicDNA = false }
        do {
            let response: DJConnectMusicDNAProfileResponse = try await sendCompanionHARequest(
                .musicDNAProfile,
                payload: DJConnectMusicDNAIdentityRequest(identity: identity, mood: askDJMoodInt)
            )
            applyMusicDNAProfile(response)
            if response.enabled {
                musicDNAOptInPromptSeen = true
            }
        } catch {
            musicDNAProfileResponse = nil
            musicDNAErrorMessage = Self.userMessage(for: error)
        }
    }

    func acceptMusicDNAOptInPrompt() {
        guard !isUpdatingMusicDNAConsent else {
            return
        }
        isShowingMusicDNAOptInPrompt = false
        musicDNAOptInPromptSeen = true
        Task { @MainActor in
            await setMusicDNAEnabledFromPrompt(true)
        }
    }

    func dismissMusicDNAOptInPrompt() {
        if isDemoMode {
            demoMusicDNAOptInPromptSeen = true
        } else {
            musicDNAOptInPromptSeen = true
        }
        isShowingMusicDNAOptInPrompt = false
    }

    func showMusicDNAOptInPrompt() {
        isShowingMusicDNAOptInPrompt = true
    }

    private func setMusicDNAEnabledFromPrompt(_ enabled: Bool) async {
        await setMusicDNAEnabled(enabled)
    }

    func setMusicDNAEnabled(_ enabled: Bool) async {
        if isDemoMode {
            setDemoMusicDNAEnabled(enabled)
            return
        }
        guard canUseBackend else {
            return
        }
        isUpdatingMusicDNA = true
        isUpdatingMusicDNAConsent = true
        musicDNAErrorMessage = nil
        defer {
            isUpdatingMusicDNA = false
            isUpdatingMusicDNAConsent = false
        }
        do {
            let response: DJConnectMusicDNAProfileResponse = try await sendCompanionHARequest(
                .musicDNASettings,
                payload: DJConnectMusicDNASettingsRequest(identity: identity, enabled: enabled, mood: askDJMoodInt)
            )
            applyMusicDNAProfile(response)
            musicDNAOptInPromptSeen = true
            showAskDJToast(enabled ? "Music DNA geactiveerd" : "Music DNA uitgeschakeld")
        } catch {
            statusMessage = Self.userMessage(for: error)
            musicDNAErrorMessage = Self.userMessage(for: error)
            showAskDJToast(Self.askDJToastText(for: error))
        }
    }

    func clearMusicDNA() async {
        if isDemoMode {
            musicDNAErrorMessage = nil
            return
        }
        guard canUseBackend else {
            return
        }
        isUpdatingMusicDNA = true
        musicDNAErrorMessage = nil
        defer { isUpdatingMusicDNA = false }
        do {
            let response: DJConnectMusicDNAProfileResponse = try await sendCompanionHARequest(
                .clearMusicDNA,
                payload: DJConnectMusicDNAIdentityRequest(identity: identity, mood: askDJMoodInt)
            )
            applyMusicDNAProfile(response)
            showAskDJToast("Music DNA gewist")
        } catch {
            musicDNAErrorMessage = Self.userMessage(for: error)
            showAskDJToast(Self.askDJToastText(for: error))
        }
    }

    private func setDemoMusicDNAEnabled(_ enabled: Bool) {
        storedDemoMusicDNAEnabled = enabled
        demoMusicDNAEnabled = enabled
        demoMusicDNAOptInPromptSeen = true
        applyDemoMusicDNAProfile()
    }

    private func applyDemoMusicDNAProfile() {
        musicDNAProfileResponse = demoMusicDNAEnabled ? Self.demoMusicDNAProfileResponse(language: language) : Self.disabledMusicDNAProfileResponse()
        musicDiscoveryResponse = demoMusicDNAEnabled ? Self.demoMusicDiscoveryResponse() : Self.disabledMusicDiscoveryResponse()
        musicDNAErrorMessage = nil
        musicDiscoveryErrorMessage = nil
        isLoadingMusicDNA = false
        isUpdatingMusicDNA = false
        isUpdatingMusicDNAConsent = false
        isLoadingMusicDiscovery = false
        isRefreshingMusicDiscovery = false
    }

    private func applyMusicDNAProfile(_ response: DJConnectMusicDNAProfileResponse) {
        musicDNAProfileResponse = response
        musicDNAErrorMessage = nil
        if response.enabled, musicDiscoveryResponse?.isMusicDNADisabled == true {
            musicDiscoveryResponse = nil
        }
    }

    func loadMusicDiscovery(force: Bool = false) async {
        if isDemoMode {
            musicDiscoveryResponse = demoMusicDNAEnabled ? Self.demoMusicDiscoveryResponse() : Self.disabledMusicDiscoveryResponse()
            musicDiscoveryErrorMessage = nil
            isLoadingMusicDiscovery = false
            isRefreshingMusicDiscovery = false
            return
        }
        guard canUseBackend else {
            musicDiscoveryResponse = nil
            musicDiscoveryErrorMessage = nil
            isLoadingMusicDiscovery = false
            isRefreshingMusicDiscovery = false
            return
        }
        if !force, musicDiscoveryResponse != nil {
            return
        }
        isLoadingMusicDiscovery = true
        musicDiscoveryErrorMessage = nil
        defer { isLoadingMusicDiscovery = false }
        do {
            let response: DJConnectMusicDiscoveryResponse = try await sendCompanionHARequest(
                .musicDiscovery,
                payload: DJConnectMusicDNAIdentityRequest(
                    identity: identity,
                    mood: askDJMoodInt,
                    musicDNAKey: musicDNAKey,
                    language: language,
                    locale: currentRequestLocale
                )
            )
            applyMusicDiscovery(response)
        } catch {
            musicDiscoveryResponse = nil
            musicDiscoveryErrorMessage = Self.userMessage(for: error)
        }
    }

    func refreshMusicDiscovery() async {
        if isDemoMode {
            let revision = (musicDiscoveryResponse?.revision ?? 12) + 1
            musicDiscoveryResponse = demoMusicDNAEnabled ? Self.demoMusicDiscoveryResponse(revision: revision) : Self.disabledMusicDiscoveryResponse()
            musicDiscoveryErrorMessage = nil
            return
        }
        guard canUseBackend else {
            return
        }
        isRefreshingMusicDiscovery = true
        musicDiscoveryErrorMessage = nil
        defer { isRefreshingMusicDiscovery = false }
        do {
            let response: DJConnectMusicDiscoveryResponse = try await sendCompanionHARequest(
                .musicDiscoveryRefresh,
                payload: DJConnectMusicDNAIdentityRequest(
                    identity: identity,
                    mood: askDJMoodInt,
                    musicDNAKey: musicDNAKey,
                    language: language,
                    locale: currentRequestLocale
                )
            )
            applyMusicDiscovery(response)
        } catch {
            musicDiscoveryErrorMessage = Self.userMessage(for: error)
            await loadMusicDiscovery(force: true)
        }
    }

    func playMusicDiscoveryItem(_ item: DJConnectMusicDiscoveryItem, sectionID: String) async {
        guard item.isDisplayable, playingMusicDiscoveryItemID == nil else {
            return
        }
        playMusicDiscoveryStartHaptic()
        playingMusicDiscoveryItemID = item.id
        musicDiscoveryErrorMessage = nil
        defer { playingMusicDiscoveryItemID = nil }
        if isDemoMode {
            try? await Task.sleep(for: .milliseconds(160))
            return
        }
        guard canUseBackend else {
            return
        }
        do {
            let payload = DJConnectMusicDiscoveryPlayRequest(
                discoveryItemID: item.id,
                sectionID: sectionID,
                identity: identity,
                musicDNAKey: musicDNAKey
            )
            let _: DJConnectCommandResponse = try await sendCompanionHARequest(.musicDiscoveryPlay, payload: payload)
        } catch {
            musicDiscoveryErrorMessage = Self.userMessage(for: error)
        }
    }

    private func applyMusicDiscovery(_ response: DJConnectMusicDiscoveryResponse) {
        musicDiscoveryResponse = response
        musicDiscoveryErrorMessage = nil
    }

    func runAskDJHistorySyncLoop() async {
        guard canUseBackend else {
            isCheckingAskDJHistoryState = false
            return
        }
        if isAppForeground {
            isCheckingAskDJHistoryState = true
            await syncAskDJHistory(showErrors: true)
            isCheckingAskDJHistoryState = false
            await requestAskDJIdleSuggestionIfNeeded()
        } else {
            isCheckingAskDJHistoryState = false
        }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: askDJHistorySyncInterval)
            if Task.isCancelled {
                return
            }
            guard isAppForeground else {
                continue
            }
            await syncAskDJHistory(showErrors: false)
        }
    }

    func syncAskDJHistoryFromPush() async {
        guard canUseBackend else {
            return
        }
        await syncAskDJHistory(showErrors: false)
    }

    func playAskDJRecommendation(_ action: DJConnectAskDJPlaybackAction) async {
        guard playingAskDJActionID == nil, canUseBackend else {
            return
        }
        if action.isFavoriteCurrentTrackControlAction {
            await saveCurrentTrackFromAskDJ(action)
            return
        }
        if action.isAskDJMessageAction {
            await sendAskDJFollowUpAction(action)
            return
        }
        if action.isOutputAction {
            await switchAskDJOutput(action)
            return
        }
        if let actionRevision = action.musicBackendRevision,
           let currentRevision = musicBackendSummary.musicBackendRevision,
           actionRevision < currentRevision {
            showAskDJToast("Aanbeveling verlopen. Vraag opnieuw.")
            return
        }
        guard action.command?.isEmpty == false
            || action.isRecommendationAction
            || action.isConfirmationAction else {
            showAskDJToast("Deze aanbeveling kan nog niet worden afgespeeld")
            return
        }
        playingAskDJActionID = action.id
        playAskDJActionHaptic()
        defer { playingAskDJActionID = nil }
        do {
            let command = action.command?.isEmpty == false ? action.command! : Self.defaultAskDJCommand(for: action)
            let response: DJConnectCommandResponse = try await sendCompanionHARequest(
                .command,
                payload: DJConnectCommandPayload(
                    identity: identity,
                    command: command,
                    value: Self.askDJCommandValue(for: action, command: command),
                    play: command == "ask_dj_play_recommendation",
                    musicBackendRevision: action.musicBackendRevision ?? musicBackendSummary.musicBackendRevision,
                    language: currentRequestLocale,
                    mood: askDJMoodInt,
                    djAnnouncementOutput: .clientDevice
                )
            )
            applyBackendSummary(response.musicBackendSummary)
            if response.success {
                if renderAskDJCommandPlaybackActions(response) {
                    playAskDJResponseHaptic()
                    await refreshStatus(confirmAskDJBeat: true)
                    return
                }
                showAskDJToast("Aanbeveling afspelen")
                playAskDJResponseHaptic()
                await refreshStatus(confirmAskDJBeat: true)
            } else {
                if handleBackendActionError(response) {
                    return
                }
                if renderAskDJCommandPlaybackActions(response) {
                    return
                }
                showAskDJToast(response.error ?? response.message ?? "Afspelen mislukt")
            }
        } catch {
            showAskDJToast(Self.askDJToastText(for: error))
        }
    }

    private func sendAskDJFollowUpAction(_ action: DJConnectAskDJPlaybackAction) async {
        guard let text = action.resolvedAskDJMessageText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            showAskDJToast("Deze aanbeveling kan nog niet worden afgespeeld")
            return
        }
        playingAskDJActionID = action.id
        playAskDJSendHaptic()
        defer { playingAskDJActionID = nil }
        let clientMessageID = UUID().uuidString
        appendAskDJMessage(role: .user, text: text)
        do {
            let response: DJConnectAskDJMessageResponse = try await sendCompanionHARequest(
                .askDJMessage,
                payload: DJConnectAskDJRequest(
                    identity: identity,
                    text: text,
                    clientMessageID: clientMessageID,
                    inputType: "text",
                    mood: askDJMoodInt,
                    djStyle: djStyle,
                    musicDNAKey: musicDNAKey,
                    audioResponse: .auto,
                    djAnnouncementOutput: .clientDevice,
                    language: currentRequestLocale
                )
            )
            applyAskDJMessageResponse(response)
            playAskDJResponseHaptic()
            await refreshStatus(confirmAskDJBeat: true)
        } catch {
            showAskDJToast(Self.askDJToastText(for: error))
        }
    }

    private func saveCurrentTrackFromAskDJ(_ action: DJConnectAskDJPlaybackAction) async {
        playingAskDJActionID = action.id
        playAskDJActionHaptic()
        defer { playingAskDJActionID = nil }
        do {
            let command = action.command?.isEmpty == false ? action.command! : "set_current_track_favorite"
            let value = action.commandValue ?? .bool(Self.boolValue(from: action.value) ?? action.favoriteStatus.map { !$0 } ?? true)
            let response: DJConnectCommandResponse = try await sendCompanionHARequest(
                .command,
                payload: DJConnectCommandPayload(
                    identity: identity,
                    command: command,
                    value: value,
                    musicBackendRevision: action.musicBackendRevision ?? musicBackendSummary.musicBackendRevision,
                    language: currentRequestLocale,
                    mood: askDJMoodInt
                )
            )
            applyBackendSummary(response.musicBackendSummary)
            if response.success {
                applyPlayback(response.playback)
                markAskDJActionCompleted(action.id)
                showAskDJToast("Favorietstatus bijgewerkt")
                playAskDJResponseHaptic()
            } else {
                if handleBackendActionError(response) {
                    return
                }
                showAskDJToast(response.error ?? response.message ?? "Favorietstatus kon niet worden aangepast")
            }
        } catch {
            showAskDJToast(Self.askDJToastText(for: error))
        }
    }

    private static func boolValue(from value: DJConnectJSONValue?) -> Bool? {
        guard case let .bool(value) = value else {
            return nil
        }
        return value
    }

    private static func askDJCommandValue(for action: DJConnectAskDJPlaybackAction, command: String) -> DJConnectCommandValue {
        switch command {
        case "ask_dj_play_request_on_output", "ask_dj_play_recommendation_on_output", "set_output":
            return action.commandValue ?? action.fullActionCommandValue
        default:
            return action.fullActionCommandValue
        }
    }

    private func switchAskDJOutput(_ action: DJConnectAskDJPlaybackAction) async {
        guard let outputDeviceID = action.outputDeviceID else {
            showAskDJToast("Deze uitvoer kan nog niet worden geselecteerd")
            return
        }
        playingAskDJActionID = action.id
        playAskDJActionHaptic()
        defer { playingAskDJActionID = nil }
        do {
            let command = action.command?.isEmpty == false ? action.command! : "set_output"
            let response: DJConnectCommandResponse = try await sendCompanionHARequest(
                .command,
                payload: DJConnectCommandPayload(
                    identity: identity,
                    command: command,
                    value: Self.askDJCommandValue(for: action, command: command),
                    musicBackendRevision: action.musicBackendRevision ?? musicBackendSummary.musicBackendRevision,
                    language: currentRequestLocale,
                    mood: askDJMoodInt
                )
            )
            applyBackendSummary(response.musicBackendSummary)
            if response.success {
                applyPlayback(response.playback)
                markAskDJOutputActionActive(outputDeviceID)
                showAskDJToast("Uitvoer gewijzigd")
                playAskDJResponseHaptic()
                await refreshStatus(confirmAskDJBeat: true)
            } else {
                if handleBackendActionError(response) {
                    return
                }
                showAskDJToast(response.error ?? response.message ?? "Uitvoer wijzigen mislukt")
            }
        } catch {
            showAskDJToast(Self.askDJToastText(for: error))
        }
    }

    @discardableResult
    private func renderAskDJCommandPlaybackActions(_ response: DJConnectCommandResponse) -> Bool {
        guard let actions = response.playbackActions, !actions.isEmpty else {
            return false
        }
        appendAskDJMessage(
            role: .dj,
            text: response.message ?? "Kies een speaker om verder te gaan.",
            playbackActions: actions
        )
        return true
    }

    private func handleBackendActionError(_ response: DJConnectCommandResponse) -> Bool {
        switch response.error {
        case "stale_backend_action":
            showAskDJToast("Aanbeveling verlopen. Vraag opnieuw.")
            return true
        case "unsupported_backend_capability":
            showAskDJToast(response.message ?? "Deze actie wordt niet ondersteund door de muziekbackend.")
            return true
        default:
            return false
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

    private func markAskDJActionCompleted(_ actionID: String) {
        askDJMessages = askDJMessages.map { message in
            var updatedMessage = message
            updatedMessage.playbackActions = message.playbackActions.map { action in
                guard action.id == actionID else {
                    return action
                }
                var updatedAction = action
                updatedAction.active = true
                return updatedAction
            }
            return updatedMessage
        }
        saveAskDJMessages()
    }

    private func syncAskDJHistory(showErrors: Bool) async {
        guard canUseBackend else {
            return
        }
        do {
            let response: DJConnectAskDJHistoryResponse = try await sendCompanionHARequest(.askDJHistory)
            applyAskDJHistory(response)
        } catch {
            if showErrors {
                statusMessage = Self.userMessage(for: error)
                showAskDJToast(Self.askDJToastText(for: error))
            }
        }
    }

    private func requestAskDJIdleSuggestionIfNeeded() async {
        guard canUseBackend,
              !hasRequestedAskDJIdleSuggestion,
              !isRequestingAskDJIdleSuggestion,
              !hasActiveNowPlaying else {
            return
        }
        hasRequestedAskDJIdleSuggestion = true
        isRequestingAskDJIdleSuggestion = true
        defer { isRequestingAskDJIdleSuggestion = false }
        do {
            let response: DJConnectAskDJMessageResponse = try await sendCompanionHARequest(
                .askDJIdleSuggestion,
                payload: DJConnectAskDJIdleSuggestionRequest(
                    identity: identity,
                    clientMessageID: UUID().uuidString,
                    mood: askDJMoodInt,
                    djStyle: djStyle,
                    musicDNAKey: musicDNAKey
                )
            )
            applyAskDJMessageResponse(response)
        } catch {
            statusMessage = Self.userMessage(for: error)
        }
    }

    private func applyAskDJMessageResponse(_ response: DJConnectAskDJMessageResponse) {
        var nextMessages = askDJMessages
        if let userMessage = response.userMessage {
            upsertAskDJHistoryMessage(userMessage, into: &nextMessages)
        }
        if let assistantMessage = response.assistantMessage {
            upsertAskDJHistoryMessage(assistantMessage, into: &nextMessages)
        }
        applyCurrentTrackInsight(from: response)
        applyAskDJTrim(response.historyTrimmedBefore, to: &nextMessages)
        coalesceAskDJMessages(&nextMessages)
        askDJMessages = sortedAskDJMessages(nextMessages)
        askDJHistoryRevision = response.historyRevision
        askDJClearRevision = response.clearRevision
        saveAskDJMessages()
    }

    private func clearAskDJHistoryLocally() {
        askDJMessages = []
        currentTrackInsight = nil
        UserDefaults.standard.removeObject(forKey: askDJMessagesKey)
        askDJHistoryRevision = 0
        askDJClearRevision = 0
    }

    private func applyAskDJHistory(_ response: DJConnectAskDJHistoryResponse, forceClear: Bool = false) {
        if forceClear || response.clearRevision > askDJClearRevision {
            askDJMessages = []
        }
        var nextMessages = askDJMessages
        for message in response.messages {
            upsertAskDJHistoryMessage(message, into: &nextMessages)
        }
        applyCurrentTrackInsight(from: response.messages)
        applyAskDJTrim(response.historyTrimmedBefore, to: &nextMessages)
        coalesceAskDJMessages(&nextMessages)
        askDJMessages = sortedAskDJMessages(nextMessages)
        askDJHistoryRevision = response.historyRevision
        askDJClearRevision = response.clearRevision
        saveAskDJMessages()
    }

    private func upsertAskDJHistoryMessage(
        _ historyMessage: DJConnectAskDJHistoryMessage,
        into messages: inout [DJConnectWatchAskDJMessage]
    ) {
        let role: DJConnectWatchAskDJMessage.Role = historyMessage.role == .user ? .user : .dj
        let existingIndex = messages.firstIndex { localMessage in
            localMessage.serverID == historyMessage.id
                || (
                    localMessage.role == role
                        && historyMessage.clientMessageID != nil
                        && localMessage.clientMessageID == historyMessage.clientMessageID
                )
        }
        let existing = existingIndex.map { messages[$0] }
        let serverText = historyMessage.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingText = existing?.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let mapped = DJConnectWatchAskDJMessage(
            id: existing?.id ?? UUID(uuidString: historyMessage.id) ?? UUID(),
            serverID: historyMessage.id,
            clientMessageID: historyMessage.clientMessageID,
            role: role,
            text: serverText.isEmpty ? (existingText ?? "") : historyMessage.text,
            images: proxiedResponseImages(historyMessage.images),
            links: safeResponseLinks(historyMessage.links),
            playbackActions: historyMessage.playbackActions + historyMessage.confirmationActions,
            intentInfo: historyMessage.intentInfo,
            items: historyMessage.items,
            audioURL: resolvedAudioURL(historyMessage.audioURL),
            announcement: resolvedAnnouncement(historyMessage.announcement),
            messageKind: historyMessage.role == .user ? .assistant : historyMessage.messageKind,
            origin: historyMessage.role == .user ? nil : historyMessage.origin,
            textSource: historyMessage.role == .user ? nil : historyMessage.textSource,
            isGeneratedText: historyMessage.role == .user ? nil : historyMessage.isGeneratedText,
            mood: historyMessage.role == .user ? nil : historyMessage.mood,
            createdAt: historyMessage.createdAt
        )
        if let existingIndex {
            messages[existingIndex] = mapped
        } else {
            messages.append(mapped)
        }
    }

    private func resolvedAnnouncement(_ announcement: DJAnnouncement?) -> DJAnnouncement? {
        guard var announcement else {
            return nil
        }
        announcement.audioURL = resolvedAudioURL(announcement.audioURL)
        return announcement
    }

    private func applyCurrentTrackInsight(from response: DJConnectAskDJMessageResponse) {
        if let insight = response.trackInsight ?? response.assistantMessage?.trackInsight {
            applyCurrentTrackInsightIfMatchingPlayback(insight)
        }
    }

    private func applyCurrentTrackInsight(from messages: [DJConnectAskDJHistoryMessage]) {
        if let insight = messages
            .filter({ $0.role != .user })
            .sorted(by: { $0.createdAt < $1.createdAt })
            .compactMap(\.trackInsight)
            .last {
            applyCurrentTrackInsightIfMatchingPlayback(insight)
        }
    }

    private func applyCurrentTrackInsightIfMatchingPlayback(_ insight: TrackInsight) {
        guard trackInsightMatchesPlayback(insight) else {
            return
        }
        currentTrackInsight = insight
    }

    private static func redactedDeviceID(_ deviceID: String) -> String {
        guard deviceID.count > 6 else {
            return "..."
        }
        return "...\(deviceID.suffix(6))"
    }

    private func applyDemoState() {
        guard !hasAppliedDemoState else {
            connectionState = .paired
            isShowingPairingSuccess = false
            statusMessage = "Demo modus actief"
            return
        }
        hasAppliedDemoState = true
        connectionState = .paired
        isShowingPairingSuccess = false
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
                id: "demo-living-room",
                name: "Woonkamer",
                type: "speaker",
                active: true,
                supportsVolume: true,
                volumePercent: 42
            ),
            contextURI: "spotify:playlist:djconnect-demo"
        )
        currentTrackInsight = localizedDemoTrackInsights.first
        applyDemoOutputs()
        applyDemoQueue()
        applyDemoPlaylists()
        responseImages = []
        statusMessage = "Demo modus actief"
    }

    private func applyDemoOutputs() {
        let outputs = [
            DJConnectOutputDevice(id: "demo-living-room", name: "Woonkamer", type: "speaker", active: true, supportsVolume: true, volumePercent: 42),
            DJConnectOutputDevice(id: "demo-kitchen", name: "Keuken", type: "speaker", active: false, supportsVolume: true, volumePercent: 35),
            DJConnectOutputDevice(id: "demo-headphones", name: "Koptelefoon", type: "headphones", active: false, supportsVolume: true, volumePercent: 28)
        ]
        applyOutputs(outputs)
    }

    private func applyDemoQueue() {
        queueContext = "spotify:playlist:djconnect-demo"
        queueItems = [
            DJConnectQueueItem(id: "demo-queue-1", title: "Midnight City", artist: "M83", album: "Hurry Up, We're Dreaming", uri: "spotify:track:demo-0", durationMS: 244_000),
            DJConnectQueueItem(id: "demo-queue-2", title: "Sweet Disposition", artist: "The Temper Trap", album: "Conditions", uri: "spotify:track:demo-1", durationMS: 232_000),
            DJConnectQueueItem(id: "demo-queue-3", title: "Electric Feel", artist: "MGMT", album: "Oracular Spectacular", uri: "spotify:track:demo-2", durationMS: 229_000)
        ]
    }

    private func applyDemoPlaylists() {
        playlistItems = [
            DJConnectPlaylist(id: "demo-playlist-1", name: "Vrijdagavond", uri: "spotify:playlist:djconnect-demo", subtitle: "Demo playlist"),
            DJConnectPlaylist(id: "demo-playlist-2", name: "Dinner vibes", uri: "spotify:playlist:djconnect-dinner", subtitle: "Rustig en warm"),
            DJConnectPlaylist(id: "demo-playlist-3", name: "Late night drive", uri: "spotify:playlist:djconnect-drive", subtitle: "Synth en neon")
        ]
    }

    private func applyDemoCommand(_ command: String, value: DJConnectCommandValue?) {
        if playback == nil {
            applyDemoState()
        }
        switch command {
        case "play", "start_playlist":
            playback?.isPlaying = true
            if command == "start_playlist" {
                if case let .string(commandValue) = value {
                    playback?.contextURI = commandValue
                    if commandValue.contains("dinner") {
                        playback?.trackName = "Sweet Disposition"
                        playback?.artistName = "The Temper Trap"
                    } else if commandValue.contains("drive") {
                        playback?.trackName = "Electric Feel"
                        playback?.artistName = "MGMT"
                    } else {
                        playback?.trackName = "Midnight City"
                        playback?.artistName = "M83"
                    }
                }
                statusMessage = "Afspeellijst gestart"
            } else {
                statusMessage = "Demo speelt"
            }
        case "play_context_at":
            playback?.isPlaying = true
            if case let .object(payload) = value {
                playback?.trackName = payload["title"] ?? playback?.trackName
                playback?.artistName = payload["artist"] ?? playback?.artistName
                playback?.contextURI = payload["context_uri"] ?? playback?.contextURI
                playback?.progressMS = 0
            }
            statusMessage = "Nummer gestart"
        case "set_output":
            guard case let .string(name) = value else {
                statusMessage = "Demo opdracht ontvangen"
                return
            }
            availableOutputs = availableOutputs.map { output in
                var output = output
                output.active = output.name == name || output.id == name
                return output
            }
            selectedOutput = name
            if let activeOutput = availableOutputs.first(where: { $0.active == true }) {
                playback?.device = DJConnectPlaybackDevice(
                    id: activeOutput.id,
                    name: activeOutput.name,
                    type: activeOutput.type,
                    active: true,
                    supportsVolume: activeOutput.supportsVolume,
                    volumePercent: activeOutput.volumePercent
                )
                playback?.volumePercent = activeOutput.volumePercent
            }
            statusMessage = "Uitvoer ingesteld"
        case "pause":
            playback?.isPlaying = false
            statusMessage = "Demo gepauzeerd"
        case "next":
            applyDemoQueueItem(relativeOffset: 1)
            statusMessage = "Volgend demo nummer"
        case "previous":
            applyDemoQueueItem(relativeOffset: -1)
            statusMessage = "Vorig demo nummer"
        case "seek_relative":
            if case let .int(delta) = value {
                let currentProgress = playback?.progressMS ?? 0
                let duration = max(playback?.durationMS ?? currentProgress, 0)
                playback?.progressMS = min(max(currentProgress + delta, 0), duration)
            }
            statusMessage = "Demo positie bijgewerkt"
        case "set_current_track_favorite", "save_current_track":
            if command == "save_current_track" {
                playback?.favoriteStatus = true
                playback?.isLiked = true
                statusMessage = "Toegevoegd aan favorieten"
            } else if case let .bool(isFavorite) = value {
                playback?.favoriteStatus = isFavorite
                playback?.isLiked = isFavorite
                statusMessage = isFavorite ? "Toegevoegd aan favorieten" : "Uit favorieten gehaald"
            } else {
                statusMessage = "Favorietstatus bijgewerkt"
            }
        default:
            statusMessage = "Demo opdracht ontvangen"
        }
    }

    private func applyDemoQueueItem(relativeOffset: Int) {
        guard !queueItems.isEmpty else {
            return
        }
        let currentIndex = currentDemoQueueIndex() ?? 0
        let targetIndex = min(max(currentIndex + relativeOffset, 0), queueItems.count - 1)
        applyDemoQueueItem(at: targetIndex)
    }

    private func applyDemoQueueItem(at index: Int) {
        guard queueItems.indices.contains(index) else {
            return
        }
        let item = queueItems[index]
        let activeDevice = playback?.device
        let volumePercent = playback?.volumePercent ?? 42
        playback = DJConnectPlayback(
            hasPlayback: true,
            isPlaying: true,
            trackName: item.title,
            artistName: item.artist,
            albumImageURL: item.albumImageURL,
            progressMS: 0,
            durationMS: item.durationMS,
            volumePercent: volumePercent,
            shuffle: playback?.shuffle ?? false,
            repeatState: playback?.repeatState ?? .off,
            device: activeDevice,
            contextURI: queueContext
        )
        currentTrackInsight = localizedDemoTrackInsights.first { insight in
            insight.title == item.title && insight.artist == item.artist
        }
    }

    private func currentDemoQueueIndex() -> Int? {
        guard let playback else {
            return nil
        }
        return queueItems.firstIndex { item in
            item.title == playback.trackName && item.artist == playback.artistName
        }
    }

    private func sendDemoVoiceResponse() {
        voiceState = .processing
        statusMessage = "Demo verwerkt..."
        appendAskDJMessage(role: .user, text: "Stemverzoek")
        let response = "Ja hoor. Ik zou nu Midnight City van M83 aankondigen: glanzende synths, avondlucht, en precies genoeg energie om de kamer op te tillen."
        currentTrackInsight = localizedDemoTrackInsights.first
        appendAskDJMessage(role: .dj, text: response)
        notifyAskDJResponse(response)
        voiceState = .idle
        statusMessage = response
        speechSynthesizer?.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: response)
        utterance.voice = AVSpeechSynthesisVoice(language: currentRequestLocale)
        utterance.rate = 0.48
        let synthesizer = AVSpeechSynthesizer()
        speechSynthesizer = synthesizer
        synthesizer.speak(utterance)
    }

    private func statusPayload(screenState: String) -> DJConnectStatusPayload {
        DJConnectStatusPayload(
            identity: identity,
            haPairingStatus: canUseBackend ? .paired : .unpaired,
            batteryPercent: Int(WKInterfaceDevice.current().batteryLevel * 100),
            language: currentRequestLocale,
            osVersion: WKInterfaceDevice.current().systemVersion,
            appBuild: DJConnectApplicationVersion.buildVersion,
            localAudioSupported: true,
            voiceSupported: true,
            screenState: screenState,
            networkType: "wifi",
            haLocalURL: nil,
            voiceEnabled: true,
            wakewordEnabled: storedVoiceActivationEnabled,
            wakewordPhrase: "Hey DJ",
            wakewordStatus: "foreground_only_\(voiceActivationStatusText.lowercased().replacingOccurrences(of: " ", with: "_"))",
            mood: askDJMoodInt,
            djStyle: djStyle,
            musicDNAKey: musicDNAKey
        )
    }

    private func startRecording() {
        cancelVoiceActivationScheduledTasks()
        stopVoiceActivationListening(status: .paused)
        if isDemoMode {
            sendDemoVoiceResponse()
            return
        }
        guard canUseBackend else {
            voiceState = .failed("Koppel eerst met Home Assistant.")
            return
        }
        if Self.microphonePermissionNeedsPrompt,
           !shouldBypassMicrophonePermissionExplanationOnce {
            isShowingMicrophonePermissionExplanation = true
            appendDiagnosticLog("Microfoon uitleg getoond", level: .debug)
            return
        }
        shouldBypassMicrophonePermissionExplanationOnce = false
        Task {
            let granted = await requestMicrophoneAccess()
            guard granted else {
                voiceState = .failed("Microfoontoegang is nodig.")
                updateVoiceActivationListening()
                return
            }
            do {
                #if !targetEnvironment(simulator)
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .spokenAudio)
                try session.setActive(true)
                #endif

                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("djconnect-watch-\(UUID().uuidString)")
                    .appendingPathExtension("wav")
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatLinearPCM),
                    AVSampleRateKey: 8_000,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: 8,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false
                ]
                let recorder = try AVAudioRecorder(url: url, settings: settings)
                recorder.record(forDuration: maxWatchVoiceRecordingDuration)
                self.recorder = recorder
                self.recordingURL = url
                self.voiceState = .recording
                self.statusMessage = "Luistert"
                self.playVoiceHaptic(.startListening)
            } catch {
                self.voiceState = .failed(Self.userMessage(for: error))
                self.updateVoiceActivationListening()
            }
        }
    }

    private func startVoiceActivationCapture() {
        shouldBypassMicrophonePermissionExplanationOnce = true
        startRecording()
        voiceActivationCaptureTask?.cancel()
        voiceActivationCaptureTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled, voiceState == .recording else {
                return
            }
            stopRecordingAndSend()
        }
    }

    func continueAfterMicrophonePermissionExplanation() {
        isShowingMicrophonePermissionExplanation = false
        shouldBypassMicrophonePermissionExplanationOnce = true
        startRecording()
    }

    func cancelMicrophonePermissionExplanation() {
        isShowingMicrophonePermissionExplanation = false
        shouldBypassMicrophonePermissionExplanationOnce = false
        appendDiagnosticLog("Microfoon uitleg geannuleerd", level: .debug)
    }

    private func stopRecordingAndSend() {
        recorder?.stop()
        recorder = nil
        let url = recordingURL
        recordingURL = nil
        playVoiceHaptic(.stopListening)

        Task {
            await Task.yield()
            voiceState = .processing
            statusMessage = "Verwerken..."
            defer {
                #if !targetEnvironment(simulator)
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                #endif
                if let url {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            guard let url else {
                voiceState = .idle
                updateVoiceActivationListening()
                return
            }
            do {
                let data = try DJConnectAudioFileLoader.loadVoiceWAVData(
                    from: url,
                    maxBytes: maxWatchVoiceWAVBytes
                )
                appendAskDJMessage(role: .user, text: "Stemverzoek")
                let response: DJConnectVoiceResponse = try await sendCompanionHARequest(
                    .voice,
                    payload: DJConnectWatchProxyVoicePayload(
                        wavData: data,
                        mood: askDJMoodInt,
                        djStyle: djStyle,
                        musicDNAKey: musicDNAKey,
                        language: currentRequestLocale
                    )
                )
                voiceState = .idle
                statusMessage = response.djText ?? response.text ?? "DJ antwoord ontvangen"
                responseImages = proxiedResponseImages(response.images)
                appendAskDJMessage(
                    role: .dj,
                    text: statusMessage,
                    images: responseImages,
                    links: safeResponseLinks(response.links),
                    audioURL: resolvedAudioURL(response.audioURL)
                )
                notifyAskDJResponse(statusMessage)
                await playVoiceResponse(response)
                await syncAskDJHistory(showErrors: false)
                await refreshStatus(confirmAskDJBeat: true)
                updateVoiceActivationListening()
            } catch {
                voiceState = .failed(Self.userMessage(for: error))
                showAskDJToast(Self.askDJToastText(for: error))
                appendAskDJMessage(role: .dj, text: Self.userMessage(for: error))
                updateVoiceActivationListening()
            }
        }
    }

    private func cancelRecording(reason: String) {
        voiceActivationCaptureTask?.cancel()
        voiceActivationCaptureTask = nil
        recorder?.stop()
        recorder = nil
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
        if voiceState == .recording || voiceState == .processing {
            voiceState = .idle
            statusMessage = reason
        }
        #if !targetEnvironment(simulator)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func applyAskDJTrim(_ trimmedBefore: Date?, to messages: inout [DJConnectWatchAskDJMessage]) {
        guard let trimmedBefore else {
            return
        }
        messages.removeAll { message in
            guard message.createdAt < trimmedBefore else {
                return false
            }
            return !Self.isClientAskDJExchangeMessage(message)
        }
    }

    private static func isClientAskDJExchangeMessage(_ message: DJConnectWatchAskDJMessage) -> Bool {
        message.clientMessageID?.isEmpty == false
    }

    private func coalesceAskDJMessages(_ messages: inout [DJConnectWatchAskDJMessage]) {
        var coalesced: [DJConnectWatchAskDJMessage] = []
        for message in sortedAskDJMessages(messages) {
            if let existingIndex = coalesced.firstIndex(where: { existing in
                Self.askDJMessagesRepresentSameBubble(existing, message)
            }) {
                coalesced[existingIndex] = mergedAskDJMessage(preferred: message, fallback: coalesced[existingIndex])
            } else {
                coalesced.append(message)
            }
        }
        messages = coalesced
    }

    private static func askDJMessagesRepresentSameBubble(
        _ lhs: DJConnectWatchAskDJMessage,
        _ rhs: DJConnectWatchAskDJMessage
    ) -> Bool {
        if let lhsServerID = lhs.serverID, let rhsServerID = rhs.serverID, lhsServerID == rhsServerID {
            return true
        }
        guard lhs.role == rhs.role,
              let lhsClientID = lhs.clientMessageID,
              let rhsClientID = rhs.clientMessageID,
              !lhsClientID.isEmpty,
              lhsClientID == rhsClientID else {
            return false
        }
        return true
    }

    private func mergedAskDJMessage(
        preferred: DJConnectWatchAskDJMessage,
        fallback: DJConnectWatchAskDJMessage
    ) -> DJConnectWatchAskDJMessage {
        var merged = preferred
        if merged.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            merged.text = fallback.text
        }
        if merged.serverID == nil {
            merged.serverID = fallback.serverID
        }
        if merged.clientMessageID == nil {
            merged.clientMessageID = fallback.clientMessageID
        }
        if merged.announcement == nil {
            merged.announcement = fallback.announcement
        }
        if merged.audioURL == nil, merged.announcement == nil {
            merged.audioURL = fallback.audioURL
        }
        if merged.intentInfo == nil {
            merged.intentInfo = fallback.intentInfo
        }
        if merged.items.isEmpty {
            merged.items = fallback.items
        }
        merged.createdAt = min(preferred.createdAt, fallback.createdAt)
        return merged
    }

    private func sortedAskDJMessages(_ messages: [DJConnectWatchAskDJMessage]) -> [DJConnectWatchAskDJMessage] {
        messages.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            if lhs.clientMessageID != rhs.clientMessageID {
                return (lhs.clientMessageID ?? "") < (rhs.clientMessageID ?? "")
            }
            if lhs.role != rhs.role {
                return lhs.role == .user
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func appendAskDJMessage(
        role: DJConnectWatchAskDJMessage.Role,
        text: String,
        images: [DJConnectResponseImage] = [],
        links: [DJConnectResponseLink] = [],
        playbackActions: [DJConnectAskDJPlaybackAction] = [],
        audioURL: URL? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !images.isEmpty || !links.isEmpty || !playbackActions.isEmpty || audioURL != nil else {
            return
        }
        askDJMessages.append(DJConnectWatchAskDJMessage(
            role: role,
            text: trimmed,
            images: images,
            links: links,
            playbackActions: playbackActions,
            audioURL: audioURL
        ))
        saveAskDJMessages()
        requestAskDJScrollToBottom()
    }

    private func requestAskDJScrollToBottom() {
        askDJScrollRequestID = UUID()
    }

    private func saveAskDJMessages() {
        if let data = try? JSONEncoder().encode(askDJMessages) {
            UserDefaults.standard.set(data, forKey: askDJMessagesKey)
        }
    }

    private func notifyAskDJResponse(_ text: String) {
        playVoiceHaptic(.response)
        let preview = Self.notificationPreview(from: text)
        Task {
            let center = UNUserNotificationCenter.current()
            guard await requestAskDJNotificationAuthorizationIfNeeded(center: center) else {
                appendDiagnosticLog("Ask DJ notificatie overgeslagen: geen toestemming", level: .debug)
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Ask DJ heeft geantwoord"
            content.body = preview.isEmpty ? "Je DJ-antwoord staat klaar." : preview
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
                appendDiagnosticLog("Ask DJ notificatie gepland", level: .debug)
            } catch {
                appendDiagnosticLog("Ask DJ notificatie mislukt: \(error.localizedDescription)", level: .warning)
            }
        }
    }

    private func requestAskDJNotificationAuthorizationIfNeeded(center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            guard !hasRequestedAskDJNotificationPermission else {
                return false
            }
            let shouldRequestSystemPermission = await withCheckedContinuation { continuation in
                pendingAskDJNotificationAuthorizationContinuation?.resume(returning: false)
                pendingAskDJNotificationAuthorizationContinuation = continuation
                isShowingAskDJNotificationPermissionExplanation = true
            }
            guard shouldRequestSystemPermission else {
                return false
            }
            return await requestAskDJNotificationAuthorization(center: center)
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func continueAfterAskDJNotificationPermissionExplanation() {
        isShowingAskDJNotificationPermissionExplanation = false
        hasRequestedAskDJNotificationPermission = true
        pendingAskDJNotificationAuthorizationContinuation?.resume(returning: true)
        pendingAskDJNotificationAuthorizationContinuation = nil
    }

    func cancelAskDJNotificationPermissionExplanation() {
        isShowingAskDJNotificationPermissionExplanation = false
        appendDiagnosticLog("Ask DJ notificatie uitleg geannuleerd", level: .debug)
        pendingAskDJNotificationAuthorizationContinuation?.resume(returning: false)
        pendingAskDJNotificationAuthorizationContinuation = nil
    }

    private func requestAskDJNotificationAuthorization(center: UNUserNotificationCenter) async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            if granted {
                WKApplication.shared().registerForRemoteNotifications()
            }
            return granted
        } catch {
            appendDiagnosticLog("Notificatie toestemming mislukt: \(error.localizedDescription)", level: .warning)
            return false
        }
    }

    private func requestRemoteNotificationAuthorizationIfNeeded(center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()
        logPush("notification permission status=\(Self.notificationAuthorizationStatusName(settings.authorizationStatus))")
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            logPush("notification permission explanation requested by remote registration")
            return await requestAskDJNotificationAuthorizationIfNeeded(center: center)
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func registerStoredPushTokenIfPossible() {
        guard !isDemoMode,
              paired,
              canUseBackend,
              let token = currentAPNsPushToken ?? UserDefaults.standard.string(forKey: legacyPushTokenKey),
              !token.isEmpty else {
            return
        }
        currentAPNsPushToken = token
        UserDefaults.standard.removeObject(forKey: legacyPushTokenKey)
        let environment = Self.pushEnvironment
        let tokenHash = Self.pushTokenHash(token)
        let appBundleID = Bundle.main.bundleIdentifier ?? "dev.djconnect.watch"
        let locale = Locale.current.identifier
        let bootstrapProof: String? = nil
        let categories = DJConnectPushRegistrationRequest.defaultNotificationCategories
        let registrationSignature = pushRegistrationSignature(
            pushToken: token,
            pushEnvironment: environment,
            appBundleID: appBundleID,
            locale: locale,
            bootstrapProof: bootstrapProof
        )
        if UserDefaults.standard.string(forKey: registeredPushTokenHashKey) == tokenHash,
           UserDefaults.standard.string(forKey: registeredPushEnvironmentKey) == environment.rawValue,
           UserDefaults.standard.string(forKey: registeredPushSignatureKey) == registrationSignature,
           UserDefaults.standard.bool(forKey: pushRegisteredKey) {
            return
        }
        Task { @MainActor in
            do {
                let authPresent = (try? tokenStore.loadToken())?.isEmpty == false
                logPush("register payload endpoint=/api/djconnect/v1/push/register ha_host=\(Self.hostForLog(from: haBaseURL)) device_id=\(identity.deviceID) client_type=\(identity.clientType.rawValue) env=\(environment.rawValue) app_bundle_id=\(appBundleID) app_version=\(identity.appVersion ?? "<missing>") locale=\(locale) categories=\(categories) push_token_present=\(!token.isEmpty) token=\(DJConnectLogRedactor.redactSecret(token)) bootstrap_proof_present=\(bootstrapProof?.isEmpty == false) bootstrap_proof=\(DJConnectLogRedactor.redactSecret(bootstrapProof)) auth_present=\(authPresent)")
                let response: DJConnectCommandResponse = try await sendCompanionHARequest(
                    .pushRegister,
                    payload: DJConnectPushRegistrationRequest(
                        identity: identity,
                        pushToken: token,
                        pushEnvironment: environment,
                        appBundleID: appBundleID,
                        appVersion: identity.appVersion,
                        locale: locale,
                        notificationCategories: categories,
                        bootstrapProof: bootstrapProof
                    )
                )
                applyPushRegistrationStatus(from: response)
                let responseError = Self.redactedPushFailureReason(response.lastPushError ?? response.error ?? "<missing>")
                let responseEnvironment = response.pushEnvironment
                let canonicalEnvironment = responseEnvironment ?? environment
                let environmentMatches = environment.isCompatible(with: responseEnvironment)
                logPush("register response http_status=decoded success=\(response.success) push_supported=\(Self.optionalBoolForLog(response.pushSupported)) push_registered=\(Self.optionalBoolForLog(response.pushRegistered)) client_type=\(identity.clientType.rawValue) canonical_push_environment=\(canonicalEnvironment.rawValue) push_environment=\(responseEnvironment?.rawValue ?? "<missing>") last_push_error=\(responseError)")
                guard response.success, response.pushRegistered != false, environmentMatches else {
                    let reason = response.error ?? response.lastPushError ?? response.message ?? "onbekend"
                    UserDefaults.standard.set(false, forKey: pushRegisteredKey)
                    UserDefaults.standard.removeObject(forKey: registeredPushSignatureKey)
                    if Self.isInvalidBootstrapProof(reason) {
                        UserDefaults.standard.set(Self.redactedPushFailureReason(reason), forKey: lastPushErrorKey)
                        logPush("registration recovery_required=true reason=invalid_bootstrap_proof message=pair_with_home_assistant_again push_registered=false", level: .warning)
                    } else if !environmentMatches {
                        let responseValue = responseEnvironment?.rawValue ?? "<missing>"
                        UserDefaults.standard.set("push_environment_mismatch", forKey: lastPushErrorKey)
                        logPush("registration rejected push_environment_mismatch expected=\(environment.rawValue) response=\(responseValue) push_registered=false", level: .warning)
                    } else {
                        appendDiagnosticLog("Push registratie niet geaccepteerd door Home Assistant: \(Self.redactedPushFailureReason(reason))", level: .warning)
                    }
                    refreshPushNotificationStatus()
                    return
                }
                UserDefaults.standard.removeObject(forKey: registeredPushTokenKey)
                UserDefaults.standard.set(tokenHash, forKey: registeredPushTokenHashKey)
                UserDefaults.standard.set(environment.rawValue, forKey: registeredPushEnvironmentKey)
                UserDefaults.standard.set(registrationSignature, forKey: registeredPushSignatureKey)
                UserDefaults.standard.set(true, forKey: pushRegisteredKey)
                UserDefaults.standard.removeObject(forKey: lastPushErrorKey)
                refreshPushNotificationStatus()
                logPush("registered with Home Assistant client_type=\(identity.clientType.rawValue) env=\(canonicalEnvironment.rawValue) push_registered=true", level: .info)
            } catch let error as DJConnectError {
                if case .routeMissing = error {
                    logPush("registration skipped route_missing=true")
                } else if Self.isInvalidBootstrapProof(Self.userMessage(for: error)) {
                    UserDefaults.standard.set(false, forKey: pushRegisteredKey)
                    UserDefaults.standard.removeObject(forKey: registeredPushSignatureKey)
                    UserDefaults.standard.set("invalid_bootstrap_proof", forKey: lastPushErrorKey)
                    refreshPushNotificationStatus()
                    logPush("registration recovery_required=true reason=invalid_bootstrap_proof message=pair_with_home_assistant_again push_registered=false", level: .warning)
                } else {
                    logPush("registration failed error=\(Self.userMessage(for: error))", level: .warning)
                }
            } catch {
                logPush("registration failed error=\(error.localizedDescription)", level: .warning)
            }
        }
    }

    private func unregisterPushNotifications() {
        guard let token = currentAPNsPushToken ?? UserDefaults.standard.string(forKey: legacyPushTokenKey),
              !token.isEmpty,
              canUseBackend else {
            return
        }
        currentAPNsPushToken = nil
        UserDefaults.standard.removeObject(forKey: legacyPushTokenKey)
        UserDefaults.standard.removeObject(forKey: registeredPushTokenKey)
        UserDefaults.standard.removeObject(forKey: registeredPushTokenHashKey)
        UserDefaults.standard.removeObject(forKey: registeredPushEnvironmentKey)
        UserDefaults.standard.removeObject(forKey: registeredPushSignatureKey)
        UserDefaults.standard.removeObject(forKey: pushRegisteredKey)
        UserDefaults.standard.removeObject(forKey: pushEnvironmentStatusKey)
        UserDefaults.standard.removeObject(forKey: lastPushErrorKey)
        refreshPushNotificationStatus()
        Task { @MainActor in
            do {
                let _: DJConnectCommandResponse = try await sendCompanionHARequest(
                    .pushUnregister,
                    payload: DJConnectPushUnregistrationRequest(
                        identity: identity,
                        pushToken: token
                    )
                )
                appendDiagnosticLog("APNs token afgemeld bij Home Assistant")
            } catch let error as DJConnectError {
                if case .routeMissing = error {
                    appendDiagnosticLog("Push afmelden overgeslagen: route ontbreekt in Home Assistant", level: .debug)
                } else {
                    appendDiagnosticLog("Push afmelden mislukt: \(Self.userMessage(for: error))", level: .warning)
                }
            } catch {
                appendDiagnosticLog("Push afmelden mislukt: \(Self.redactedPushFailureReason(error.localizedDescription))", level: .warning)
            }
        }
    }

    private func pushRegistrationSignature(
        pushToken: String,
        pushEnvironment: DJConnectPushEnvironment,
        appBundleID: String,
        locale: String,
        bootstrapProof: String?
    ) -> String {
        [
            identity.deviceID,
            identity.clientType.rawValue,
            Self.pushTokenHash(pushToken),
            pushEnvironment.rawValue,
            appBundleID,
            identity.appVersion ?? "",
            locale,
            bootstrapProof ?? "",
            haBaseURL
        ].joined(separator: "|")
    }

    private func applyPushRegistrationStatus(from response: DJConnectCommandResponse) {
        if let pushSupported = response.pushSupported {
            UserDefaults.standard.set(pushSupported, forKey: pushSupportedKey)
        }
        if let pushRegistered = response.pushRegistered {
            UserDefaults.standard.set(pushRegistered, forKey: pushRegisteredKey)
            if !pushRegistered {
                UserDefaults.standard.removeObject(forKey: registeredPushSignatureKey)
            }
        }
        if let pushEnvironment = response.pushEnvironment {
            UserDefaults.standard.set(pushEnvironment.rawValue, forKey: pushEnvironmentStatusKey)
        }
        if let lastPushError = response.lastPushError, !lastPushError.isEmpty {
            UserDefaults.standard.set(Self.redactedPushFailureReason(lastPushError), forKey: lastPushErrorKey)
        } else if response.pushRegistered == true {
            UserDefaults.standard.removeObject(forKey: lastPushErrorKey)
        }
        refreshPushNotificationStatus()
        logPush("status push_supported=\(Self.optionalBoolForLog(response.pushSupported)) push_registered=\(Self.optionalBoolForLog(response.pushRegistered)) push_environment=\(response.pushEnvironment?.rawValue ?? "<missing>") last_push_error=\(Self.redactedPushFailureReason(response.lastPushError ?? "<missing>"))")
    }

    private func refreshPushNotificationStatus() {
        pushNotificationStatus = Self.pushNotificationStatus()
    }

    private static func pushNotificationStatus(defaults: UserDefaults = .standard) -> DJConnectWatchPushNotificationStatus {
        let hasSupportedValue = defaults.object(forKey: "DJConnectWatchPushSupported") != nil
        let supported = defaults.bool(forKey: "DJConnectWatchPushSupported")
        let registered = defaults.bool(forKey: "DJConnectWatchPushRegistered")
        let environment = defaults
            .string(forKey: "DJConnectWatchPushEnvironmentStatus")
            .flatMap(DJConnectPushEnvironment.init(rawValue:))
        let error = defaults.string(forKey: "DJConnectWatchLastPushError")
        if hasSupportedValue, !supported {
            return DJConnectWatchPushNotificationStatus(state: .unavailable, environment: environment, lastError: error)
        }
        if registered {
            return DJConnectWatchPushNotificationStatus(state: .registered, environment: environment, lastError: nil)
        }
        if let error, !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return DJConnectWatchPushNotificationStatus(state: .actionNeeded, environment: environment, lastError: error)
        }
        return DJConnectWatchPushNotificationStatus(state: .inactive, environment: environment, lastError: nil)
    }

    private static var pushEnvironment: DJConnectPushEnvironment {
        pushEnvironment(apsEnvironment: apsEnvironmentEntitlement)
    }

    static func pushEnvironment(apsEnvironment: String?) -> DJConnectPushEnvironment {
        switch apsEnvironment?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "development", "sandbox":
            return .sandbox
        case "production":
            return .production
        default:
            #if DEBUG
            return .sandbox
            #else
            return .production
            #endif
        }
    }

    private static var apsEnvironmentEntitlement: String? {
        #if os(macOS) && canImport(Security)
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "aps-environment" as CFString, nil) else {
            return nil
        }
        return value as? String
        #else
        return nil
        #endif
    }

    private func logPush(_ message: String, level: DJConnectWatchLogLevel = .debug) {
        appendDiagnosticLog("[DJConnectPush] \(message)", level: level)
    }

    private static func redactedPushToken(_ token: String) -> String {
        DJConnectLogRedactor.redactSecret(token)
    }

    private static func pushTokenHash(_ token: String) -> String {
        SHA256.hash(data: Data(token.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func hostForLog(from urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host, !host.isEmpty else {
            return "<missing>"
        }
        return host
    }

    private static func optionalBoolForLog(_ value: Bool?) -> String {
        value.map(String.init) ?? "<missing>"
    }

    private static func notificationAuthorizationStatusName(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            "not_determined"
        case .denied:
            "denied"
        case .authorized:
            "authorized"
        case .provisional:
            "provisional"
        case .ephemeral:
            "ephemeral"
        @unknown default:
            "unknown"
        }
    }

    private static func redactedPushFailureReason(_ reason: String) -> String {
        DJConnectLogRedactor.redactText(reason)
    }

    private static func isInvalidBootstrapProof(_ reason: String) -> Bool {
        reason.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().contains("invalid_bootstrap_proof")
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

    private static func loadAskDJMessages(key: String) -> [DJConnectWatchAskDJMessage] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([DJConnectWatchAskDJMessage].self, from: data)) ?? []
    }

    private func playVoiceResponse(_ response: DJConnectVoiceResponse) async {
        await playResponseAudio(response.audioURL, fallbackText: response.djText ?? response.text)
    }

    func replayAskDJAudio(_ audioURL: URL?) {
        let resolvedURL = resolvedAudioURL(audioURL)
        Task {
            await playResponseAudio(resolvedURL, fallbackText: nil)
        }
    }

    func stopAskDJAudio() {
        audioPlaybackTask?.cancel()
        audioPlaybackTask = nil
        player?.pause()
        player = nil
        speechSynthesizer?.stopSpeaking(at: .immediate)
        speechSynthesizer = nil
        askDJAudioPlaybackState = .idle
    }

    func isLoadingAskDJAudio(_ audioURL: URL?) -> Bool {
        guard let resolvedURL = resolvedAudioURL(audioURL) else {
            return false
        }
        if case let .loading(currentURL) = askDJAudioPlaybackState {
            return currentURL == resolvedURL
        }
        return false
    }

    func isPlayingAskDJAudio(_ audioURL: URL?) -> Bool {
        guard let resolvedURL = resolvedAudioURL(audioURL) else {
            return false
        }
        if case let .playing(currentURL) = askDJAudioPlaybackState {
            return currentURL == resolvedURL
        }
        return false
    }

    private func playResponseAudio(_ audioURL: URL?, fallbackText: String?) async {
        speechSynthesizer?.stopSpeaking(at: .immediate)
        audioPlaybackTask?.cancel()
        player?.pause()

        if let audioURL = resolvedAudioURL(audioURL) {
            guard Self.isSupportedResponseAudioURL(audioURL) else {
                askDJAudioPlaybackState = .idle
                if let text = fallbackText {
                    speakResponseFallback(text)
                }
                return
            }
            do {
                askDJAudioPlaybackState = .loading(audioURL)
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
                try AVAudioSession.sharedInstance().setActive(true)
                let item = AVPlayerItem(url: audioURL)
                let player = AVPlayer(playerItem: item)
                self.player = player
                player.play()
                askDJAudioPlaybackState = .playing(audioURL)
                audioPlaybackTask = Task { @MainActor [weak self] in
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
                        self?.player?.pause()
                        self?.player = nil
                        self?.audioPlaybackTask = nil
                    }
                }
                return
            } catch {
                askDJAudioPlaybackState = .idle
                statusMessage = Self.userMessage(for: error)
                showAskDJToast("Audio kon niet opnieuw worden afgespeeld")
            }
        }

        guard let text = fallbackText else {
            return
        }
        speakResponseFallback(text)
    }

    private static func isSupportedResponseAudioURL(_ audioURL: URL) -> Bool {
        let pathExtension = audioURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return pathExtension == "mp3" || pathExtension == "wav"
    }

    private func speakResponseFallback(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: currentRequestLocale)
        let synthesizer = AVSpeechSynthesizer()
        speechSynthesizer = synthesizer
        synthesizer.speak(utterance)
    }

    private func resolvedAudioURL(_ audioURL: URL?) -> URL? {
        guard let audioURL else {
            return nil
        }
        if audioURL.scheme?.isEmpty == false {
            return audioURL
        }
        return URL(string: audioURL.absoluteString, relativeTo: URL(string: haBaseURL))?.absoluteURL
    }

    private func resolvedArtworkURL(_ artworkURL: URL?) -> URL? {
        guard let artworkURL else {
            return nil
        }
        if let scheme = artworkURL.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            return artworkURL
        }
        guard artworkURL.host == nil else {
            return nil
        }
        return URL(string: artworkURL.relativeString, relativeTo: URL(string: haBaseURL))?.absoluteURL
    }

    private func proxiedResponseImages(_ images: [DJConnectResponseImage]?) -> [DJConnectResponseImage] {
        guard let images, !images.isEmpty, let baseURL = URL(string: haBaseURL), let allowedHost = baseURL.host?.lowercased() else {
            return []
        }
        return images.compactMap { image in
            guard let resolvedURL = resolvedResponseImageURL(image.url, baseURL: baseURL, allowedHost: allowedHost) else {
                return nil
            }
            var updatedImage = image
            updatedImage.url = resolvedURL
            if let thumbnailURL = image.thumbnailURL {
                updatedImage.thumbnailURL = resolvedResponseImageURL(thumbnailURL, baseURL: baseURL, allowedHost: allowedHost)
            }
            return updatedImage
        }
    }

    private func resolvedResponseImageURL(_ url: URL, baseURL: URL, allowedHost: String) -> URL? {
        if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            return url.host?.lowercased() == allowedHost ? url : nil
        }
        guard url.host == nil else {
            return nil
        }
        return URL(string: url.relativeString, relativeTo: baseURL)?.absoluteURL
    }

    private func safeResponseLinks(_ links: [DJConnectResponseLink]?) -> [DJConnectResponseLink] {
        guard let links else {
            return []
        }
        return links.filter { link in
            guard let scheme = link.url.scheme?.lowercased() else {
                return false
            }
            return scheme == "https" || scheme == "http"
        }
    }

    private func showAskDJToast(_ text: String) {
        askDJToast = DJConnectWatchToast(text: text)
    }

    private static func askDJToastText(for error: Error) -> String {
        guard let error = error as? DJConnectError else {
            return "Ask DJ niet bereikbaar"
        }
        switch error {
        case .backendUnavailable:
            return "De muziekbackend in Home Assistant is tijdelijk niet beschikbaar. DJConnect probeert automatisch opnieuw."
        case .server, .decodingFailed, .invalidResponse, .payloadTooLarge:
            return "Home Assistant gaf geen antwoord"
        case .trackInsightUnavailable:
            return "Track Insight niet beschikbaar"
        case .network, .routeMissing, .notConfigured, .invalidConfiguration, .missingToken, .pairingFailed, .clientTypeMismatch, .authStale, .versionMismatch, .profile:
            return "Ask DJ niet bereikbaar"
        }
    }

    private func enableVoiceActivation() {
        guard canUseBackend else {
            voiceActivationStatus = .paused
            statusMessage = "Koppel eerst met Home Assistant."
            appendDiagnosticLog("Stemactivatie niet gestart: niet gekoppeld", level: .warning)
            return
        }
        guard isAppForeground else {
            storedVoiceActivationEnabled = true
            voiceActivationStatus = .paused
            return
        }
        if Self.microphonePermissionNeedsPrompt,
           !shouldBypassVoiceActivationPermissionExplanationOnce {
            isShowingVoiceActivationPermissionExplanation = true
            appendDiagnosticLog("Stemactivatie uitleg getoond", level: .debug)
            return
        }
        shouldBypassVoiceActivationPermissionExplanationOnce = false
        Task {
            let microphoneGranted = await requestMicrophoneAccess()
            let speechGranted = await requestVoiceActivationSpeechAccessIfAvailable()
            guard microphoneGranted else {
                storedVoiceActivationEnabled = false
                voiceActivationStatus = .microphoneRequired
                appendDiagnosticLog("Stemactivatie toestemming ontbreekt", level: .warning)
                return
            }
            guard speechGranted else {
                storedVoiceActivationEnabled = false
                voiceActivationStatus = .unavailable
                return
            }
            storedVoiceActivationEnabled = true
            appendDiagnosticLog("Stemactivatie ingeschakeld")
            updateVoiceActivationListening()
        }
    }

    func continueAfterVoiceActivationPermissionExplanation() {
        isShowingVoiceActivationPermissionExplanation = false
        shouldBypassVoiceActivationPermissionExplanationOnce = true
        enableVoiceActivation()
    }

    func cancelVoiceActivationPermissionExplanation() {
        isShowingVoiceActivationPermissionExplanation = false
        shouldBypassVoiceActivationPermissionExplanationOnce = false
        appendDiagnosticLog("Stemactivatie uitleg geannuleerd", level: .debug)
    }

    private func updateVoiceActivationListening() {
        voiceActivationRestartTask?.cancel()
        voiceActivationRestartTask = nil
        guard storedVoiceActivationEnabled else {
            voiceActivationListenTimeoutTask?.cancel()
            voiceActivationListenTimeoutTask = nil
            stopVoiceActivationListening(status: .paused)
            return
        }
        guard isAppForeground, canUseBackend, voiceState == .idle else {
            voiceActivationListenTimeoutTask?.cancel()
            voiceActivationListenTimeoutTask = nil
            stopVoiceActivationListening(status: .paused)
            return
        }
        startVoiceActivationListening()
    }

    private func startVoiceActivationListening() {
        #if canImport(Speech)
        guard voiceActivationAudioEngine == nil else {
            voiceActivationStatus = .listening
            return
        }
        guard AVAudioApplication.shared.recordPermission == .granted,
              SFSpeechRecognizer.authorizationStatus() == .authorized else {
            voiceActivationStatus = .microphoneRequired
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "nl_NL")), recognizer.isAvailable else {
            voiceActivationStatus = .unavailable
            appendDiagnosticLog("Stemactivatie spraakherkenning niet beschikbaar", level: .warning)
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)

            let engine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true

            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
                request.append(buffer)
            }

            engine.prepare()
            try engine.start()

            voiceActivationAudioEngine = engine
            voiceActivationRecognitionRequest = request
            voiceActivationStatus = .listening
            statusMessage = "Stemactivatie luistert"
            appendDiagnosticLog("Stemactivatie luistert")

            voiceActivationRecognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else {
                        return
                    }
                    if let transcript = result?.bestTranscription.formattedString,
                       self.transcriptContainsWakePhrase(transcript) {
                        self.appendDiagnosticLog("Stemactivatie wake word herkend")
                        self.stopVoiceActivationListening(status: .paused)
                        self.startVoiceActivationCapture()
                        return
                    }
                    if error != nil {
                        self.stopVoiceActivationListening(status: .paused)
                        self.scheduleVoiceActivationRestart()
                    }
                }
            }
            scheduleVoiceActivationListenTimeout()
        } catch {
            voiceActivationStatus = .unavailable
            appendDiagnosticLog("Stemactivatie start mislukt: \(error.localizedDescription)", level: .error)
            stopVoiceActivationListening(status: .unavailable)
        }
        #else
        voiceActivationStatus = .unavailable
        #endif
    }

    private func scheduleVoiceActivationRestart(after delay: TimeInterval = 3) {
        voiceActivationRestartTask?.cancel()
        guard storedVoiceActivationEnabled, isAppForeground, canUseBackend, voiceState == .idle else {
            return
        }
        voiceActivationRestartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else {
                return
            }
            self?.voiceActivationRestartTask = nil
            self?.updateVoiceActivationListening()
        }
    }

    private func scheduleVoiceActivationListenTimeout() {
        voiceActivationListenTimeoutTask?.cancel()
        voiceActivationListenTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard !Task.isCancelled, let self, self.voiceActivationAudioEngine != nil else {
                return
            }
            self.appendDiagnosticLog("Stemactivatie luistervenster gepauzeerd", level: .debug)
            self.stopVoiceActivationListening(status: .paused)
            self.scheduleVoiceActivationRestart(after: 18)
        }
    }

    private func cancelVoiceActivationScheduledTasks() {
        voiceActivationRestartTask?.cancel()
        voiceActivationRestartTask = nil
        voiceActivationListenTimeoutTask?.cancel()
        voiceActivationListenTimeoutTask = nil
    }

    private func stopVoiceActivationListening(status: VoiceActivationStatus) {
        voiceActivationListenTimeoutTask?.cancel()
        voiceActivationListenTimeoutTask = nil
        #if canImport(Speech)
        if let voiceActivationAudioEngine {
            voiceActivationAudioEngine.inputNode.removeTap(onBus: 0)
            voiceActivationAudioEngine.stop()
        }
        voiceActivationAudioEngine = nil
        voiceActivationRecognitionRequest?.endAudio()
        voiceActivationRecognitionRequest = nil
        voiceActivationRecognitionTask?.cancel()
        voiceActivationRecognitionTask = nil
        #endif
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        voiceActivationStatus = status
    }

    private func requestVoiceActivationSpeechAccessIfAvailable() async -> Bool {
        #if canImport(Speech)
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        @unknown default:
            return false
        }
        #else
        voiceActivationStatus = .unavailable
        appendDiagnosticLog("Stemactivatie niet beschikbaar: spraakherkenning ontbreekt op deze Watch", level: .warning)
        return false
        #endif
    }

    private func transcriptContainsWakePhrase(_ transcript: String) -> Bool {
        let normalized = Self.normalizedVoiceActivationText(transcript)
        return normalized.contains("hey dj")
            || normalized.contains("hey dee jay")
            || normalized.contains("hey deejay")
            || normalized.contains("hey d j")
    }

    private static func normalizedVoiceActivationText(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private static var microphonePermissionNeedsPrompt: Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            return true
        case .granted, .denied:
            return false
        @unknown default:
            return true
        }
    }

    private static func makePairingCode() -> String {
        String(Int.random(in: 100_000...999_999))
    }

    private static func makeStableInstallID() -> String {
        UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .prefix(12)
            .uppercased()
    }

    private static func disabledMusicDNAProfileResponse() -> DJConnectMusicDNAProfileResponse {
        DJConnectMusicDNAProfileResponse(
            success: true,
            enabled: false,
            profile: DJConnectMusicDNAProfile()
        )
    }

    private static func disabledMusicDiscoveryResponse() -> DJConnectMusicDiscoveryResponse {
        DJConnectMusicDiscoveryResponse(
            success: true,
            enabled: false,
            reason: "music_dna_disabled",
            sections: []
        )
    }

    private static func demoMusicDiscoveryResponse(revision: Int = 12) -> DJConnectMusicDiscoveryResponse {
        DJConnectMusicDiscoveryResponse(
            success: true,
            enabled: true,
            revision: revision,
            generatedAt: Date(),
            ttlSeconds: 86_400,
            source: "music_dna",
            sections: [
                DJConnectMusicDiscoverySection(
                    id: "new_for_you",
                    title: "Nieuw voor jou",
                    items: [
                        DJConnectMusicDiscoveryItem(
                            id: "watch-demo-discovery-1",
                            kind: .track,
                            title: "Midnight Relay",
                            subtitle: "Luna Vale",
                            uri: "spotify:track:watch-demo-discovery-1",
                            reason: "Past bij je smaakankers: neon downtempo, Luna Vale en late-night synth grooves.",
                            reasonSources: ["taste_anchors", "favorite_artists"],
                            confidence: .high
                        ),
                        DJConnectMusicDiscoveryItem(
                            id: "watch-demo-discovery-2",
                            kind: .track,
                            title: "Harbor Afterglow",
                            subtitle: "Nova Harbor",
                            uri: "spotify:track:watch-demo-discovery-2",
                            reason: "Sluit aan op je recente favorieten met warm baswerk en melodische avondenergie.",
                            reasonSources: ["recent_favorite_tracks", "mood_mix"],
                            confidence: .medium
                        )
                    ]
                ),
                DJConnectMusicDiscoverySection(
                    id: "accepted_recommendations",
                    title: "Omdat je eerder iets koos",
                    items: [
                        DJConnectMusicDiscoveryItem(
                            id: "watch-demo-discovery-3",
                            kind: .playlist,
                            title: "Neon Drive",
                            subtitle: "Playlist",
                            uri: "spotify:playlist:watch-demo-discovery-3",
                            reason: "Gebouwd rond je groove-zone met genoeg energie om de set vooruit te duwen.",
                            reasonSources: ["mood_mix", "energy_profile"],
                            confidence: .high
                        )
                    ]
                )
            ]
        )
    }

    private static func demoMusicDNAProfileResponse(language: String = DJConnectLocalization.defaultDisplayLanguageCode()) -> DJConnectMusicDNAProfileResponse {
        DJConnectMusicDNAProfileResponse(
            success: true,
            musicDNAKey: "demo:music-dna",
            enabled: true,
            generation: 3,
            profile: DJConnectMusicDNAProfile(
                summary: DJConnectLocalization.localized(key: "demo.music.dna.watch.summary", language: language),
                favoriteGenres: [
                    DJConnectMusicDNANameValue(name: "Neon downtempo"),
                    DJConnectMusicDNANameValue(name: "Velvet electro"),
                    DJConnectMusicDNANameValue(name: "Skyline pop")
                ],
                favoriteArtists: [
                    DJConnectMusicDNANameValue(name: "Luna Vale"),
                    DJConnectMusicDNANameValue(name: "Nova Harbor"),
                    DJConnectMusicDNANameValue(name: "Echo Parade")
                ],
                recentTracks: [
                    DJConnectMusicDNATrack(title: "Glass Avenue", artist: "Luna Vale"),
                    DJConnectMusicDNATrack(title: "Afterglow Signals", artist: "Nova Harbor"),
                    DJConnectMusicDNATrack(title: "Silver Static", artist: "Echo Parade")
                ],
                recentFavoriteTracks: [
                    DJConnectMusicDNATrack(title: "Neon Bloom", artist: "Luna Vale", album: "Night Map", uri: "spotify:track:demo-favorite-1"),
                    DJConnectMusicDNATrack(title: "Velvet Room", artist: "Nova Harbor", album: "Harbor Lights", uri: "spotify:track:demo-favorite-2")
                ],
                topTracksByRange: [
                    "week": [
                        DJConnectMusicDNATrack(title: "Glass Avenue", artist: "Luna Vale"),
                        DJConnectMusicDNATrack(title: "Afterglow Signals", artist: "Nova Harbor")
                    ]
                ],
                topArtistsByRange: [
                    "week": [
                        DJConnectMusicDNANameValue(name: "Luna Vale"),
                        DJConnectMusicDNANameValue(name: "Nova Harbor")
                    ]
                ],
                mood: DJConnectMusicDNAMood(
                    value: 68,
                    zone: "energy",
                    promptHint: DJConnectLocalization.localized(key: "demo.music.dna.mood.promptHint", language: language),
                    sampleCount: 3,
                    average: 57,
                    averageZone: "groove",
                    averagePromptHint: DJConnectLocalization.localized(key: "demo.music.dna.mood.averagePromptHint", language: language),
                    zoneCounts: ["chill": 1, "groove": 1, "energy": 1]
                ),
                energyProfile: DJConnectMusicDNAEnergyProfile(
                    sampleCount: 2,
                    energy: 0.70,
                    energyPercent: 70,
                    zone: "energy",
                    promptHint: DJConnectLocalization.localized(key: "demo.music.dna.energy.promptHint", language: language),
                    danceability: 0.54,
                    danceabilityPercent: 54,
                    intensity: 0.62,
                    intensityPercent: 62,
                    recentSignals: [
                        DJConnectMusicDNAEnergySignal(title: "Glass Avenue", artist: "Luna Vale", album: "Night Map"),
                        DJConnectMusicDNAEnergySignal(title: "Afterglow Signals", artist: "Nova Harbor", album: "Harbor Lights")
                    ]
                ),
                playtime: DJConnectMusicDNAPlaytime(
                    totalSeconds: 12_840,
                    totalHours: 3.57,
                    formattedTotal: "3u 34m",
                    topArtists: [
                        DJConnectMusicDNAPlaytimeArtist(name: "Luna Vale", seconds: 4_800, hours: 1.33, formatted: "1u 20m"),
                        DJConnectMusicDNAPlaytimeArtist(name: "Nova Harbor", seconds: 3_240, hours: 0.90, formatted: "54m"),
                        DJConnectMusicDNAPlaytimeArtist(name: "Echo Parade", seconds: 2_100, hours: 0.58, formatted: "35m")
                    ],
                    topAlbums: [
                        DJConnectMusicDNAPlaytimeArtist(name: "Night Map", seconds: 3_900, hours: 1.08, formatted: "1u 5m"),
                        DJConnectMusicDNAPlaytimeArtist(name: "Harbor Lights", seconds: 2_700, hours: 0.75, formatted: "45m"),
                        DJConnectMusicDNAPlaytimeArtist(name: "Signal Garden", seconds: 1_560, hours: 0.43, formatted: "26m")
                    ]
                ),
                listeningRhythm: DJConnectMusicDNAListeningRhythm(
                    sampleCount: 6,
                    topDaypart: DJConnectLocalization.localized(key: "demo.music.dna.daypart.evening", language: language),
                    topWeekday: DJConnectLocalization.localized(key: "demo.music.dna.weekday.friday", language: language),
                    dayparts: [
                        DJConnectMusicDNAListeningRhythmItem(daypart: DJConnectLocalization.localized(key: "demo.music.dna.daypart.evening", language: language), count: 4, percent: 66.7),
                        DJConnectMusicDNAListeningRhythmItem(daypart: DJConnectLocalization.localized(key: "demo.music.dna.daypart.afternoon", language: language), count: 2, percent: 33.3)
                    ],
                    weekdays: [
                        DJConnectMusicDNAListeningRhythmItem(weekday: DJConnectLocalization.localized(key: "demo.music.dna.weekday.friday", language: language), count: 3, percent: 50),
                        DJConnectMusicDNAListeningRhythmItem(weekday: DJConnectLocalization.localized(key: "demo.music.dna.weekday.saturday", language: language), count: 2, percent: 33.3),
                        DJConnectMusicDNAListeningRhythmItem(weekday: DJConnectLocalization.localized(key: "demo.music.dna.weekday.thursday", language: language), count: 1, percent: 16.7)
                    ]
                ),
                moodMix: DJConnectMusicDNAMoodMix(
                    sampleCount: 5,
                    average: 63,
                    topZone: "groove",
                    zones: [
                        DJConnectMusicDNAMoodMixZone(zone: "chill", count: 1, percent: 20),
                        DJConnectMusicDNAMoodMixZone(zone: "groove", count: 2, percent: 40),
                        DJConnectMusicDNAMoodMixZone(zone: "energy", count: 2, percent: 40)
                    ]
                ),
                repeatMagnets: DJConnectMusicDNARepeatMagnets(
                    eligible: true,
                    items: [
                        DJConnectMusicDNARepeatMagnetItem(kind: "artist", name: "Luna Vale", count: 5),
                        DJConnectMusicDNARepeatMagnetItem(kind: "album", name: "Night Map", seconds: 3_900, formatted: "1u 5m"),
                        DJConnectMusicDNARepeatMagnetItem(kind: "artist", name: "Nova Harbor", count: 3)
                    ]
                ),
                explicitPositives: DJConnectMusicDNAExplicitPositives(
                    eligible: true,
                    signalCount: 4,
                    favoriteTracks: [
                        DJConnectMusicDNAFavoriteTrackSignal(title: "Neon Bloom", artist: "Luna Vale", uri: "spotify:track:demo-favorite-1"),
                        DJConnectMusicDNAFavoriteTrackSignal(title: "Velvet Room", artist: "Nova Harbor", uri: "spotify:track:demo-favorite-2")
                    ],
                    acceptedRecommendations: [
                        DJConnectMusicDNAAcceptedRecommendationSignal(title: "Glass Avenue", subtitle: DJConnectLocalization.localized(key: "demo.music.dna.accepted.warmSynthGroove", language: language), uri: "spotify:track:demo-accepted-1", reason: "matches_music_dna"),
                        DJConnectMusicDNAAcceptedRecommendationSignal(title: "Silver Static", subtitle: DJConnectLocalization.localized(key: "demo.music.dna.accepted.brightLateNightPulse", language: language), uri: "spotify:track:demo-accepted-2", reason: "expands_music_dna")
                    ]
                ),
                tasteAnchors: DJConnectMusicDNATasteAnchors(
                    eligible: true,
                    items: [
                        DJConnectMusicDNATasteAnchorItem(kind: "artist", name: "Luna Vale", playCount: 7, formatted: "1u 20m"),
                        DJConnectMusicDNATasteAnchorItem(kind: "genre", name: "Neon downtempo"),
                        DJConnectMusicDNATasteAnchorItem(kind: "genre", name: "Velvet electro"),
                        DJConnectMusicDNATasteAnchorItem(kind: "artist", name: "Nova Harbor", playCount: 4, formatted: "54m"),
                        DJConnectMusicDNATasteAnchorItem(kind: "genre", name: "Skyline pop")
                    ]
                ),
                timePatterns: [
                    DJConnectMusicDNASignal(title: DJConnectLocalization.localized(key: "demo.music.dna.time.eveningListening", language: language), kind: "time", value: "20:00-23:00"),
                    DJConnectMusicDNASignal(title: DJConnectLocalization.localized(key: "demo.music.dna.time.weekendDiscovery", language: language), kind: "pattern", value: DJConnectLocalization.localized(key: "demo.music.dna.time.newArtists", language: language)),
                    DJConnectMusicDNASignal(title: DJConnectLocalization.localized(key: "demo.music.dna.time.fridayLift", language: language), kind: "pattern", value: DJConnectLocalization.localized(key: "demo.music.dna.time.higherEnergy", language: language))
                ],
                recommendationSignals: [
                    DJConnectMusicDNASignal(title: DJConnectLocalization.localized(key: "demo.music.dna.signal.brightSynthHooks", language: language), kind: "sound"),
                    DJConnectMusicDNASignal(title: DJConnectLocalization.localized(key: "demo.music.dna.signal.warmRollingBass", language: language), kind: "texture"),
                    DJConnectMusicDNASignal(title: DJConnectLocalization.localized(key: "demo.music.dna.signal.playfulVocalFragments", language: language), kind: "mood")
                ],
                blockedArtists: [],
                blockedItems: []
            )
        )
    }

    private static func userMessage(for error: Error) -> String {
        if let error = error as? DJConnectError {
            switch error {
            case .missingToken:
                return "Koppel eerst met Home Assistant."
            case .backendUnavailable:
                return "De muziekbackend in Home Assistant is tijdelijk niet beschikbaar. DJConnect probeert automatisch opnieuw."
            case .server, .decodingFailed, .invalidResponse, .payloadTooLarge:
                return "Home Assistant gaf geen antwoord."
            case .trackInsightUnavailable:
                return "Track Insight niet beschikbaar."
            case .network,
                 .authStale,
                 .notConfigured,
                 .pairingFailed,
                 .clientTypeMismatch,
                 .routeMissing,
                 .profile:
                return "Ask DJ niet bereikbaar."
            case let .versionMismatch(mismatch):
                return mismatch.message ?? "Werk DJConnect bij."
            case let .invalidConfiguration(message):
                return message
            }
        }
        return error.localizedDescription
    }
}
