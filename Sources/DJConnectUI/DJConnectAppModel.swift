import Combine
import CryptoKit
import DJConnectCore
import Foundation
import Network
import OSLog
#if canImport(Security)
import Security
#endif

#if os(iOS) && canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(UserNotifications)
@preconcurrency import UserNotifications
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
#if canImport(WidgetKit)
import WidgetKit
#endif
#if os(iOS) && canImport(WatchConnectivity)
@preconcurrency import WatchConnectivity
#endif

#if os(iOS) && canImport(AVFoundation)
private func configureDJConnectAudioSession(
    category: AVAudioSession.Category,
    mode: AVAudioSession.Mode,
    options: AVAudioSession.CategoryOptions = []
) async throws {
    let rawCategory = category.rawValue
    let rawMode = mode.rawValue
    let rawOptions = options.rawValue
    try await Task.detached(priority: .userInitiated) {
        try AVAudioSession.sharedInstance().setCategory(
            AVAudioSession.Category(rawValue: rawCategory),
            mode: AVAudioSession.Mode(rawValue: rawMode),
            options: AVAudioSession.CategoryOptions(rawValue: rawOptions)
        )
    }.value
}

private func setDJConnectAudioSessionActive(
    _ isActive: Bool,
    options: AVAudioSession.SetActiveOptions = []
) async throws {
    let rawOptions = options.rawValue
    try await Task.detached(priority: .userInitiated) {
        try AVAudioSession.sharedInstance().setActive(
            isActive,
            options: AVAudioSession.SetActiveOptions(rawValue: rawOptions)
        )
    }.value
}
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

public enum DJConnectPairingFlowTarget: String, Sendable {
    case iPhone
    case appleWatch
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
    let tagName: String?
    let version: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case body
        case tagName = "tag_name"
        case version
    }
}

private struct DJConnectReleaseNotesFetchResult {
    let release: DJConnectReleaseNotes
    let url: URL
    let statusCode: Int
}

private struct DJConnectReleaseNotesManifest: Decodable {
    let latestVersion: String?
    let version: String?
    let releases: [DJConnectReleaseNotesManifestRelease]?

    private enum CodingKeys: String, CodingKey {
        case latestVersion = "latest_version"
        case version
        case releases
    }
}

private struct DJConnectReleaseNotesManifestRelease: Decodable {
    let version: String?
}

private struct DJConnectVersion: Comparable, Equatable, Hashable {
    let major: Int
    let minor: Int
    let patch: Int

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        let parts = cleaned.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2 else {
            return nil
        }
        major = parts[0]
        minor = parts[1]
        patch = parts.count >= 3 ? parts[2] : 0
    }

    var stringValue: String {
        "\(major).\(minor).\(patch)"
    }

    static func < (lhs: DJConnectVersion, rhs: DJConnectVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}

private extension String {
    var trimmingPrefixV: String {
        hasPrefix("v") ? String(dropFirst()) : self
    }
}

private struct DJConnectAvailableUpdate: Identifiable, Equatable {
    let id: String
    let version: String
    let title: String
    let body: String
}

public enum DJConnectMusicDNATransferError: Error, Equatable, Sendable {
    case noProfileAvailable
    case invalidDocument
    case homeAssistantUnavailable
}

public struct DJConnectMusicDNAImportPreview: Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var profile: DJConnectMusicDNAProfileResponse
    public var exportedAt: Date?
    public var exportedByClientType: String?
    public var appVersion: String?
}

#if os(iOS) && canImport(WatchConnectivity)
private struct DJConnectWatchProxyRegistration: Sendable {
    var identity: DJConnectIdentity
    var pairCode: String
    var paired: Bool
}

private final class DJConnectWatchProxySessionDelegate: NSObject, WCSessionDelegate, @unchecked Sendable {
    weak var model: DJConnectAppModel?

    init(model: DJConnectAppModel) {
        self.model = model
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            self?.model?.handleWatchProxyActivation(state: activationState, error: error)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.model?.handleWatchProxyReachabilityChange()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: message, requiringSecureCoding: false) else {
            return
        }
        Task { @MainActor [weak self] in
            guard let message = Self.unarchiveWatchProxyMessage(data) else {
                return
            }
            self?.model?.handleWatchProxyMessage(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: userInfo, requiringSecureCoding: false) else {
            return
        }
        Task { @MainActor [weak self] in
            guard let userInfo = Self.unarchiveWatchProxyMessage(data) else {
                return
            }
            self?.model?.handleWatchProxyMessage(userInfo)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: applicationContext, requiringSecureCoding: false) else {
            return
        }
        Task { @MainActor [weak self] in
            guard let applicationContext = Self.unarchiveWatchProxyMessage(data) else {
                return
            }
            self?.model?.handleWatchProxyMessage(applicationContext)
        }
    }

    private static func unarchiveWatchProxyMessage(_ data: Data) -> [String: Any]? {
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

public enum DJConnectPermissionExplanationKind: Equatable, Sendable {
    case notifications
    case microphone
}

private enum DJConnectPendingPermissionRequest {
    case appPermissions
    case voiceRecording
}

public enum DJConnectHomeScreenAction: String, Equatable, Sendable {
    case nowPlaying = "dev.djconnect.action.now-playing"
    case queue = "dev.djconnect.action.queue"
    case askDJ = "dev.djconnect.action.ask-dj"
    case trackInsight = "dev.djconnect.action.track-insight"
    case discovery = "dev.djconnect.action.discovery"
    case playlists = "dev.djconnect.action.playlists"

    public init?(deepLinkURL url: URL) {
        guard url.scheme?.lowercased() == "djconnect" else {
            return nil
        }
        let host = url.host?.lowercased()
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let target = path.isEmpty ? host : path
        switch target {
        case "now-playing", "nowplaying", "speelt-nu":
            self = .nowPlaying
        case "queue", "wachtrij":
            self = .queue
        case "ask-dj", "askdj":
            self = .askDJ
        case "track-insight", "trackinsight":
            self = .trackInsight
        case "discover", "discovery", "ontdek", "music-discovery", "music_discovery", "musicdiscovery":
            self = .discovery
        case "playlists", "afspeellijsten":
            self = .playlists
        default:
            return nil
        }
    }
}

public struct DJConnectHomeScreenActionRequest: Equatable, Sendable {
    public let id: UUID
    public let action: DJConnectHomeScreenAction

    public init(action: DJConnectHomeScreenAction, id: UUID = UUID()) {
        self.id = id
        self.action = action
    }
}

private extension DJConnectAskDJMessageResponse {
    var shouldOpenTrackInsight: Bool {
        let openTarget = openScreen?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let type = responseType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let intent = intentInfo?.intent?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let action = intentInfo?.action?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return openTarget == "track_insight"
            || type == "track_insight"
            || intent == "track_insight"
            || action == "track_insight"
    }
}

public struct DJConnectUserNotice: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public var text: String
}

public struct DJConnectVisualNotice: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public var text: String
    public var systemImage: String
}

public enum DJConnectAskDJMessageRole: String, Codable, Equatable, Sendable {
    case user
    case dj
}

public enum DJConnectAskDJMessageStatus: String, Codable, Equatable, Sendable {
    case sending
    case sent
    case delivered
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
    public var exchangeID: String?
    public var exchangeOrder: Int?
    public var role: DJConnectAskDJMessageRole
    public var messageKind: DJConnectAskDJLocalMessageKind
    public var origin: String?
    public var textSource: String?
    public var isGeneratedText: Bool?
    public var mood: Int?
    public var text: String
    public var images: [DJConnectResponseImage]
    public var links: [DJConnectResponseLink]
    public var playbackActions: [DJConnectAskDJPlaybackAction]
    public var audioURL: URL?
    public var status: DJConnectAskDJMessageStatus?
    public var createdAt: Date
    public var intentInfo: DJConnectAskDJIntentInfo?
    public var trackInsight: TrackInsight?
    public var items: [DJConnectAskDJHistoryItem]

    public init(
        id: UUID = UUID(),
        serverID: String? = nil,
        clientMessageID: String? = nil,
        exchangeID: String? = nil,
        exchangeOrder: Int? = nil,
        role: DJConnectAskDJMessageRole,
        messageKind: DJConnectAskDJLocalMessageKind = .assistant,
        origin: String? = nil,
        textSource: String? = nil,
        isGeneratedText: Bool? = nil,
        mood: Int? = nil,
        text: String,
        images: [DJConnectResponseImage] = [],
        links: [DJConnectResponseLink] = [],
        playbackActions: [DJConnectAskDJPlaybackAction] = [],
        audioURL: URL? = nil,
        status: DJConnectAskDJMessageStatus? = nil,
        createdAt: Date = Date(),
        intentInfo: DJConnectAskDJIntentInfo? = nil,
        trackInsight: TrackInsight? = nil,
        items: [DJConnectAskDJHistoryItem] = []
    ) {
        self.id = id
        self.serverID = serverID
        self.clientMessageID = clientMessageID
        self.exchangeID = exchangeID
        self.exchangeOrder = exchangeOrder
        self.role = role
        self.messageKind = messageKind
        self.origin = origin
        self.textSource = textSource
        self.isGeneratedText = isGeneratedText
        self.mood = mood.map { max(0, min(100, $0)) }
        self.text = text
        self.images = images
        self.links = links
        self.playbackActions = playbackActions
        self.audioURL = audioURL
        self.status = status
        self.createdAt = createdAt
        self.intentInfo = intentInfo
        self.trackInsight = trackInsight
        self.items = items
    }

    public var renderablePlaybackActions: [DJConnectAskDJPlaybackAction] {
        playbackActions
    }

    enum CodingKeys: String, CodingKey {
        case id
        case serverID = "server_id"
        case clientMessageID = "client_message_id"
        case exchangeID = "exchange_id"
        case exchangeOrder = "exchange_order"
        case role
        case messageKind = "message_kind"
        case origin
        case textSource = "text_source"
        case isGeneratedText = "is_generated_text"
        case mood
        case text
        case images
        case links
        case playbackActions = "playback_actions"
        case audioURL = "audio_url"
        case status
        case createdAt = "created_at"
        case intentInfo = "intent"
        case trackInsight = "track_insight"
        case items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        serverID = try container.decodeIfPresent(String.self, forKey: .serverID)
        clientMessageID = try container.decodeIfPresent(String.self, forKey: .clientMessageID)
        exchangeID = try container.decodeIfPresent(String.self, forKey: .exchangeID)
        exchangeOrder = try container.decodeIfPresent(Int.self, forKey: .exchangeOrder)
        role = try container.decode(DJConnectAskDJMessageRole.self, forKey: .role)
        messageKind = try container.decodeIfPresent(DJConnectAskDJLocalMessageKind.self, forKey: .messageKind) ?? .assistant
        origin = try container.decodeIfPresent(String.self, forKey: .origin)
        textSource = try container.decodeIfPresent(String.self, forKey: .textSource)
        isGeneratedText = try container.decodeIfPresent(Bool.self, forKey: .isGeneratedText)
        mood = try container.decodeIfPresent(Int.self, forKey: .mood).map { max(0, min(100, $0)) }
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        images = try container.decodeIfPresent([DJConnectResponseImage].self, forKey: .images) ?? []
        links = try container.decodeIfPresent([DJConnectResponseLink].self, forKey: .links) ?? []
        playbackActions = try container.decodeIfPresent([DJConnectAskDJPlaybackAction].self, forKey: .playbackActions) ?? []
        audioURL = try container.decodeIfPresent(URL.self, forKey: .audioURL)
        status = try container.decodeIfPresent(DJConnectAskDJMessageStatus.self, forKey: .status)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        intentInfo = try container.decodeIfPresent(DJConnectAskDJIntentInfo.self, forKey: .intentInfo)
        trackInsight = try container.decodeIfPresent(TrackInsight.self, forKey: .trackInsight)
        items = try container.decodeIfPresent([DJConnectAskDJHistoryItem].self, forKey: .items) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(serverID, forKey: .serverID)
        try container.encodeIfPresent(clientMessageID, forKey: .clientMessageID)
        try container.encodeIfPresent(exchangeID, forKey: .exchangeID)
        try container.encodeIfPresent(exchangeOrder, forKey: .exchangeOrder)
        try container.encode(role, forKey: .role)
        try container.encode(messageKind, forKey: .messageKind)
        try container.encodeIfPresent(origin, forKey: .origin)
        try container.encodeIfPresent(textSource, forKey: .textSource)
        try container.encodeIfPresent(isGeneratedText, forKey: .isGeneratedText)
        try container.encodeIfPresent(mood, forKey: .mood)
        try container.encode(text, forKey: .text)
        try container.encode(images, forKey: .images)
        try container.encode(links, forKey: .links)
        try container.encode(playbackActions, forKey: .playbackActions)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(intentInfo, forKey: .intentInfo)
        try container.encodeIfPresent(trackInsight, forKey: .trackInsight)
        try container.encode(items, forKey: .items)
    }

}

@MainActor
public final class DJConnectAppModel: ObservableObject {
    @Published public var homeAssistantURL = "" {
        didSet { defaults.set(homeAssistantURL, forKey: homeAssistantURLKey) }
    }
    @Published public private(set) var haLocalURL = ""
    @Published public private(set) var haRemoteURL = ""
    @Published public private(set) var haConnectionMode: DJConnectHAConnectionMode = .offline
    @Published public private(set) var remoteSupported = false
    @Published public private(set) var musicBackendSummary = DJConnectMusicBackendSummary()
    @Published public private(set) var assistPipelineID = ""
    @Published public private(set) var apiBase = ""
    @Published public private(set) var voicePath = ""
    @Published public private(set) var statusPath = ""
    @Published public private(set) var eventPath = ""
    @Published public private(set) var askDJSupported = false
    @Published public private(set) var askDJVoiceSupported = false
    @Published public private(set) var askDJAudioResponseSupported = false
    @Published public private(set) var watchPairingMessage: String?
    @Published public var pairingToken = "" {
        didSet {
            if pairingToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                defaults.removeObject(forKey: pairingTokenKey)
            } else {
                defaults.set(pairingToken, forKey: pairingTokenKey)
            }
        }
    }
    @Published public var pairingStatus: DJConnectPairingStatus = .unpaired {
        didSet {
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
    @Published public var isPairing = false
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
    @Published public private(set) var currentTrackInsight: TrackInsight?
    @Published public private(set) var trackInsightHistory: [TrackInsight] = []
    @Published public private(set) var isLoadingTrackInsight = false
    @Published public private(set) var trackInsightErrorMessage: String?
    @Published public private(set) var vibeCastResponse: DJConnectVibeCastResponse?
    @Published public private(set) var vibeCastItems: [DJConnectVibeCastResponse.Item] = []
    @Published public private(set) var vibeCastDisabledReason: String?
    @Published public private(set) var isVibeCastStreamingActive = false
    @Published public private(set) var musicDNAProfileResponse: DJConnectMusicDNAProfileResponse?
    @Published public private(set) var isLoadingMusicDNA = false
    @Published public private(set) var isUpdatingMusicDNA = false
    @Published public private(set) var musicDNAErrorMessage: String?
    @Published public private(set) var musicDNAToast: DJConnectVisualNotice?
    @Published public var isShowingMusicDNAOptInPrompt = false
    @Published public private(set) var demoMusicDNAEnabled = false
    @Published public private(set) var musicDiscoveryResponse: DJConnectMusicDiscoveryResponse?
    @Published public private(set) var isLoadingMusicDiscovery = false
    @Published public private(set) var isRefreshingMusicDiscovery = false
    @Published public private(set) var musicDiscoveryErrorMessage: String?
    @Published public private(set) var playingMusicDiscoveryItemID: String?
    private var pendingMusicDNAEnabled: Bool?
    private var pendingMusicDNAEnabledAt: Date?
    #if DEBUG
    public private(set) var isMusicDNAPreviewMode = false
    #endif
    @Published public var autoTrackInsightEnabled = false {
        didSet { defaults.set(autoTrackInsightEnabled, forKey: autoTrackInsightEnabledKey) }
    }
    @Published public var showVisualizerOnAirPlay = false {
        didSet { defaults.set(showVisualizerOnAirPlay, forKey: showVisualizerOnAirPlayKey) }
    }
    @Published public private(set) var trackInsightNavigationRequestID: UUID?
    @Published public private(set) var homeScreenActionRequest: DJConnectHomeScreenActionRequest?
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
    @Published public private(set) var isSavingCurrentTrack = false
    @Published public private(set) var isClearingAskDJHistory = false
    @Published public private(set) var isCheckingAskDJHistoryState = true
    @Published public var askDJErrorMessage: String?
    @Published public private(set) var askDJToast: DJConnectUserNotice?
    @Published public private(set) var askDJAudioPlaybackState: DJConnectAskDJAudioPlaybackState = .idle
    @Published public private(set) var transientAskDJListeningMessage: DJConnectAskDJMessage?
    @Published public private(set) var transientAskDJMoodMessage: DJConnectAskDJMessage?
    @Published public var askDJMood = 50.0 {
        didSet {
            defaults.set(askDJMood, forKey: askDJMoodKey)
            Self.syncAskDJMoodToSharedDefaults(askDJMood)
            if Self.askDJMoodStepIndex(for: oldValue) != Self.askDJMoodStepIndex(for: askDJMood) {
                reloadWidgetTimelinesForMoodChange()
            }
        }
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
    @Published public private(set) var appLanguageOverrideCode = ""
    @Published public var voiceEnabled = true {
        didSet { updateWakeWordListeningForAvailability() }
    }
    @Published public var localResponseAudioEnabled = true
    @Published public var isDemoMode = false
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
    @Published public private(set) var permissionExplanationKind: DJConnectPermissionExplanationKind = .notifications
    @Published public var isShowingWelcome = false
    @Published public var isShowingCrashReportPrompt = false
    @Published public var isShowingWakeWordActivationPrompt = false
    @Published public var isShowingTokenStorageError = false
    @Published public var isShowingWhatsNew = false
    @Published public private(set) var whatsNewTitle = ""
    @Published public private(set) var whatsNewBody = ""
    @Published public private(set) var isLoadingWhatsNew = false
    @Published public private(set) var isCheckingForUpdates = false
    @Published public private(set) var updateCheckMessage: String?
    @Published public private(set) var updateNotesTitle = ""
    @Published public private(set) var updateNotesBody = ""
    @Published public var isShowingUpdateNotes = false
    @Published public private(set) var isShowingPairingSuccess = false
    @Published public private(set) var isPairingScreenDismissed = false
    @Published public private(set) var pairingFlowTarget: DJConnectPairingFlowTarget = .iPhone
    @Published public private(set) var isLocalNetworkAvailable = false
    @Published public private(set) var hasEvaluatedLocalNetwork = false
    @Published public private(set) var isDeviceNetworkAvailable = false
    @Published public private(set) var hasEvaluatedDeviceNetwork = false
    @Published public private(set) var networkRefreshRequestID = UUID()
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
    private var openPermissionSettingsTask: Task<Void, Never>?
    private var pendingSelectedOutput: String?
    private var pendingVolumePercent: Int?
    private var pendingSeekTargetMS: Int?
    private var seekCommandTask: Task<Void, Never>?
    private var isAppInForeground = true
    private var lastFullRefreshAt: Date?
    private var lastBackendCollectionsRefreshAt: Date?
    #if os(iOS) && canImport(WatchConnectivity)
    @Published private var watchProxyRegistration: DJConnectWatchProxyRegistration?
    private var watchProxySessionDelegate: DJConnectWatchProxySessionDelegate?
    #endif
    private let networkMonitor = NWPathMonitor()
    private let networkMonitorQueue = DispatchQueue(label: "dev.djconnect.app.network")
    private var shouldShowWakeWordPromptAfterPairingScreen = false
    private var currentAPNsPushToken: String?
    private var musicDiscoveryPushRefreshes: [String: Date] = [:]
    private var webSocketFastPathCache: [String: any DJConnectWebSocketFastPathTransport] = [:]
    @Published public private(set) var fastPathDiagnostics = DJConnectFastPathDiagnostics()
    @Published public var webSocketFastPathEnabled = false {
        didSet {
            guard oldValue != webSocketFastPathEnabled else {
                return
            }
            defaults.set(webSocketFastPathEnabled, forKey: webSocketFastPathEnabledKey)
            webSocketFastPathCache.removeAll()
            fastPathDiagnostics = DJConnectFastPathDiagnostics()
            log(.info, "WebSocket fast path \(webSocketFastPathEnabled ? "enabled" : "disabled")")
            if webSocketFastPathEnabled {
                refreshWebSocketFastPathStatus()
            }
        }
    }
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
    private let urlSession: URLSession
    private let homeAssistantWebSocketAuth: DJConnectHomeAssistantWebSocketAuth?
    private let startBackgroundTasks: Bool
    private let monkeyTestingMode: Bool
    private let diagnosticLogFileURL: URL?
    nonisolated private static let protocolVersion = "3.2.22"
    private static let defaultHomeAssistantURL = "http://homeassistant.local:8123"
    private let appVersion = DJConnectAppModel.protocolVersion
    private let installIDKey = "DJConnectInstallID"
    private let homeAssistantURLKey = "DJConnectHomeAssistantURL"
    private let haLocalURLKey = "DJConnectHALocalURL"
    private let haRemoteURLKey = "DJConnectHARemoteURL"
    private let haConnectionModeKey = "DJConnectHAConnectionMode"
    private let assistPipelineIDKey = "DJConnectAssistPipelineID"
    private let apiBaseKey = "DJConnectAPIBase"
    private let voicePathKey = "DJConnectVoicePath"
    private let statusPathKey = "DJConnectStatusPath"
    private let eventPathKey = "DJConnectEventPath"
    private let askDJSupportedKey = "DJConnectAskDJSupported"
    private let askDJVoiceSupportedKey = "DJConnectAskDJVoiceSupported"
    private let askDJAudioResponseSupportedKey = "DJConnectAskDJAudioResponseSupported"
    private let pairingTokenKey = "DJConnectPairingToken"
    private let watchProxyDeviceIDKey = "DJConnectWatchProxyDeviceID"
    private let watchProxyDeviceNameKey = "DJConnectWatchProxyDeviceName"
    private let watchProxyPairCodeKey = "DJConnectWatchProxyPairCode"
    private let watchProxyFirmwareKey = "DJConnectWatchProxyFirmware"
    private let watchProxyAppVersionKey = "DJConnectWatchProxyAppVersion"
    private let watchProxyPairedKey = "DJConnectWatchProxyPaired"
    private let watchProxyDeviceTokenKey = "DJConnectWatchProxyDeviceToken"
    private let watchProxyLocalURLKey = "DJConnectWatchProxyLocalURL"
    private let watchProxyAPIBaseKey = "DJConnectWatchProxyAPIBase"
    private let watchProxyVoicePathKey = "DJConnectWatchProxyVoicePath"
    private let watchProxyStatusPathKey = "DJConnectWatchProxyStatusPath"
    private let watchProxyEventPathKey = "DJConnectWatchProxyEventPath"
    private let watchProxyAskDJSupportedKey = "DJConnectWatchProxyAskDJSupported"
    private let watchProxyAskDJVoiceSupportedKey = "DJConnectWatchProxyAskDJVoiceSupported"
    private let watchProxyAskDJAudioResponseSupportedKey = "DJConnectWatchProxyAskDJAudioResponseSupported"
    private let logLevelKey = "DJConnectLogLevel"
    private let appLanguageOverrideKey = DJConnectLocalization.appLanguageOverrideDefaultsKey
    private let demoModeKey = "DJConnectDemoMode"
    private let askDJMoodKey = "DJConnectAskDJMood"
    private let wakeWordPhraseKey = "DJConnectWakeWordPhrase"
    private let askDJMessagesKey = "DJConnectAskDJMessages"
    private let askDJHistoryRevisionKey = "DJConnectAskDJHistoryRevision"
    private let askDJClearRevisionKey = "DJConnectAskDJClearRevision"
    private let askDJAudioResponseModeKey = "DJConnectAskDJAudioResponseMode"
    private let autoTrackInsightEnabledKey = "DJConnectAutoTrackInsightEnabled"
    private let showVisualizerOnAirPlayKey = "DJConnectShowVisualizerOnAirPlay"
    private let webSocketFastPathEnabledKey = "DJConnectWebSocketFastPathEnabled"
    private let legacyPushTokenKey = "DJConnectPushToken"
    private let registeredPushTokenKey = "DJConnectRegisteredPushToken"
    private let registeredPushTokenHashKey = "DJConnectRegisteredPushTokenHash"
    private let registeredPushEnvironmentKey = "DJConnectRegisteredPushEnvironment"
    private let registeredPushSignatureKey = "DJConnectRegisteredPushSignature"
    private let pushSupportedKey = "DJConnectPushSupported"
    private let pushRegisteredKey = "DJConnectPushRegistered"
    private let pushEnvironmentStatusKey = "DJConnectPushEnvironmentStatus"
    private let lastPushErrorKey = "DJConnectLastPushError"
    private let wakeWordPromptDismissedKey = "DJConnectWakeWordPromptDismissed"
    private let musicDNAOptInPromptSeenKey = "DJConnectMusicDNAOptInPromptSeen"
    private let demoMusicDNAEnabledKey = "DJConnectDemoMusicDNAEnabled"
    private let demoMusicDNAOptInPromptSeenKey = "DJConnectDemoMusicDNAOptInPromptSeen"
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
    private let progressTimerNetworkRefreshInterval = 5
    private let askDJHistorySyncInterval: UInt64 = 8_000_000_000
    private var hasRequestedAskDJIdleSuggestion = false
    private var hasRequestedAskDJNotificationPermission = false
    private var pendingAskDJNotificationPreview: String?
    private var pendingPermissionRequest: DJConnectPendingPermissionRequest?
    private var shouldBypassPermissionExplanationOnce = false
    private var lastVibeCastContextID: String?
    private var lastVibeCastRevision: Int?
    private var lastVibeCastItemsSignature: String?
    private var lastVibeCastAutoInsightPlaybackID: String?

    public var volume: Double {
        get { Double(pendingVolumePercent ?? playback?.volumePercent ?? 0) }
        set {
            let value = DJConnectVolumeNormalizer.clampBackendPercent(Int(newValue.rounded()))
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
        Self.askDJMoodStepIndex(for: askDJMood)
    }

    private static func askDJMoodStepIndex(for mood: Double) -> Int {
        switch max(0, min(100, Int(mood.rounded()))) {
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
        playMoodHaptic(stepIndex: clampedIndex)
        askDJMood = Double(askDJMoodSteps[clampedIndex].value)
        showMoodChangedMessage()
        scheduleMusicDNAProfileRefresh(reason: "Mood changed")
    }

    public func setAppLanguageOverride(_ value: String) {
        let normalizedOverride = DJConnectLocalization.languageOverrideCode(value)
        guard normalizedOverride != appLanguageOverrideCode else {
            Self.syncAppLanguageOverrideToSharedDefaults(normalizedOverride)
            return
        }
        let oldNoOutputName = Self.noOutputName(for: language)
        appLanguageOverrideCode = normalizedOverride
        if normalizedOverride.isEmpty {
            defaults.removeObject(forKey: appLanguageOverrideKey)
        } else {
            defaults.set(normalizedOverride, forKey: appLanguageOverrideKey)
        }
        Self.syncAppLanguageOverrideToSharedDefaults(normalizedOverride)
        language = Self.resolvedLanguage(defaults: defaults)
        if selectedOutput == oldNoOutputName || Self.legacyNoOutputNames.contains(selectedOutput) {
            selectedOutput = Self.noOutputName(for: language)
        }
        refreshReleaseNotesIfNeeded()
        reloadWidgetTimelinesForLanguageChange()
    }

    private var hasActiveNowPlaying: Bool {
        playback?.hasPlayback == true
            || playback?.isPlaying == true
            || playback?.trackName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var hasPlayingNow: Bool {
        playback?.isPlaying == true
    }

    public var version: String {
        appVersion
    }

    public var appLanguageSelectionCode: String {
        get { appLanguageOverrideCode }
        set { setAppLanguageOverride(newValue) }
    }

    private var releaseNotesLanguageCode: String {
        Self.normalizedReleaseNotesLanguageCode(language)
    }

    public var currentRequestLocale: String {
        DJConnectLocalization.bcp47LocaleIdentifier(for: language)
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
        isDemoMode || (pairingStatus == .paired && backendAvailable && isRuntimeCompatible && haConnectionMode != .offline && !isOfflineModeActive)
    }

    public var canStartTrackInsightAnalysis: Bool {
        isDemoMode || (canUsePlaybackFeatures && hasActiveNowPlaying)
    }

    public var localNetworkRequirementMessage: String? {
        (!hasEvaluatedLocalNetwork || isLocalNetworkAvailable) ? nil : localized(key: "appModel.local.wi.fi.lan.is.required.connect.this.device")
    }

    public var isOfflineModeActive: Bool {
        !isDemoMode && hasEvaluatedDeviceNetwork && !isDeviceNetworkAvailable
    }

    public var shouldShowPairingWiFiSettingsLink: Bool {
        !isDemoMode && hasEvaluatedLocalNetwork && !isLocalNetworkAvailable
    }

    public var shouldShowPairingScreen: Bool {
        let shouldShowAppleWatchPairing = pairingFlowTarget == .appleWatch
            && (isAppleWatchPairingPending || isShowingPairingSuccess)
        let shouldShowIPhonePairing = !isDemoMode
            && (pairingStatus != .paired || isShowingPairingSuccess)

        return !isShowingWelcome
            && !isShowingCrashReportPrompt
            && !isShowingTokenStorageError
            && !isPairingScreenDismissed
            && (shouldShowIPhonePairing || shouldShowAppleWatchPairing)
    }

    public var isAppleWatchPairingPending: Bool {
        #if os(iOS) && canImport(WatchConnectivity)
        if let registration = watchProxyRegistration {
            return !registration.paired
        }
        #endif
        return false
    }

    public var shouldShowAppleWatchPairingReminder: Bool {
        pairingStatus == .paired && isAppleWatchPairingPending
    }

    public init(
        playback: DJConnectPlayback? = nil,
        defaults: UserDefaults = .standard,
        tokenStore: DJConnectTokenStore? = nil,
        urlSession: URLSession = .shared,
        homeAssistantWebSocketAuth: DJConnectHomeAssistantWebSocketAuth? = nil,
        startBackgroundTasks: Bool = true,
        monkeyTestingMode: Bool = false,
        diagnosticLogDirectory: URL? = nil
    ) {
        self.defaults = defaults
        self.startBackgroundTasks = startBackgroundTasks
        self.monkeyTestingMode = monkeyTestingMode
        self.homeAssistantWebSocketAuth = homeAssistantWebSocketAuth
        self.isMonkeyTestingMode = monkeyTestingMode
        self.diagnosticLogFileURL = (diagnosticLogDirectory ?? Self.defaultDiagnosticLogDirectory())?
            .appendingPathComponent("djconnect.log")
        let resolvedTokenStore = tokenStore ?? DJConnectUserDefaultsTokenStore()
        let hasExistingInstallID = defaults.string(forKey: "DJConnectInstallID")?.isEmpty == false
        if !hasExistingInstallID && !monkeyTestingMode && resolvedTokenStore is DJConnectUserDefaultsTokenStore {
            try? resolvedTokenStore.clearToken()
        }
        self.tokenStore = resolvedTokenStore
        self.urlSession = urlSession
        self.identity = Self.makeIdentity(defaults: defaults)
        self.logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "dev.djconnect",
            category: "DJConnectApp"
        )
        self.playback = playback
        self.homeAssistantURL = defaults.string(forKey: homeAssistantURLKey) ?? Self.defaultHomeAssistantURL
        self.haLocalURL = defaults.string(forKey: haLocalURLKey) ?? ""
        self.haRemoteURL = defaults.string(forKey: haRemoteURLKey) ?? ""
        if let storedMode = defaults.string(forKey: haConnectionModeKey).flatMap(DJConnectHAConnectionMode.init(rawValue:)) {
            self.haConnectionMode = storedMode
        }
        self.assistPipelineID = defaults.string(forKey: assistPipelineIDKey) ?? ""
        self.apiBase = defaults.string(forKey: apiBaseKey) ?? ""
        self.voicePath = defaults.string(forKey: voicePathKey) ?? ""
        self.statusPath = defaults.string(forKey: statusPathKey) ?? ""
        self.eventPath = defaults.string(forKey: eventPathKey) ?? ""
        self.askDJSupported = defaults.bool(forKey: askDJSupportedKey)
        self.askDJVoiceSupported = defaults.bool(forKey: askDJVoiceSupportedKey)
        self.askDJAudioResponseSupported = defaults.bool(forKey: askDJAudioResponseSupportedKey)
        self.pairingToken = defaults.string(forKey: pairingTokenKey) ?? ""
        self.appLanguageOverrideCode = Self.appLanguageOverride(defaults: defaults)
        self.language = Self.resolvedLanguage(defaults: defaults)
        Self.syncAppLanguageOverrideToSharedDefaults(self.appLanguageOverrideCode)
        self.selectedOutput = Self.noOutputName(for: language)
        self.logLevel = defaults.string(forKey: logLevelKey) ?? "info"
        self.askDJMood = defaults.object(forKey: askDJMoodKey) == nil ? 50.0 : defaults.double(forKey: askDJMoodKey)
        Self.syncAskDJMoodToSharedDefaults(self.askDJMood)
        self.autoTrackInsightEnabled = defaults.bool(forKey: autoTrackInsightEnabledKey)
        self.webSocketFastPathEnabled = defaults.bool(forKey: webSocketFastPathEnabledKey)
        self.showVisualizerOnAirPlay = defaults.bool(forKey: showVisualizerOnAirPlayKey)
        self.demoMusicDNAEnabled = defaults.bool(forKey: demoMusicDNAEnabledKey)
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
        do {
            if monkeyTestingMode {
                clearAskDJHistoryLocally()
                applyDemoState()
                log(.info, "App started in non-destructive monkey test mode")
            } else if let existingToken = try resolvedTokenStore.loadToken(), !existingToken.isEmpty {
                beginStoredPairingValidation()
                log(.info, "App started with existing DJConnect bearer token for \(identity.clientType.rawValue)")
                if startBackgroundTasks {
                    schedulePairedRefresh(reason: "Refreshing initial Home Assistant state")
                }
                if !Self.isRunningUnderSwiftPMTests {
                    requestRemoteNotificationRegistration()
                }
            } else if isDemoMode {
                applyDemoState()
                log(.info, "App started in demo mode")
            } else {
                clearPairingToken()
                log(.info, "App started without DJConnect bearer token for \(identity.clientType.rawValue)")
            }
        } catch {
            applyTokenStorageFailure(error)
        }
        refreshPermissionStatuses()
        registerStoredPushTokenIfPossible()
        #if os(iOS) && canImport(WatchConnectivity)
        restoreWatchProxyRegistration()
        activateWatchProxySession()
        #endif
        if startBackgroundTasks {
            startNetworkMonitor()
        }
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

        whatsNewTitle = localized(key: "appModel.what.s.new.in.djconnect.value", arguments: appVersion)
        whatsNewBody = localized(key: "appModel.loading.release.notes")
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

    private func refreshReleaseNotesIfNeeded() {
        guard isShowingWhatsNew else {
            return
        }
        Task { [weak self] in
            await self?.loadWhatsNewReleaseNotes()
        }
    }

    public func loadWhatsNewReleaseNotes() async {
        await MainActor.run {
            isLoadingWhatsNew = true
        }
        let fallback = localized(key: "appModel.release.notes.could.not.be.loaded.see.https.djconnect")

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

    public func checkForUpdates() {
        guard !isCheckingForUpdates else {
            return
        }
        updateCheckMessage = nil
        Task { [weak self] in
            await self?.loadAvailableUpdates()
        }
    }

    private func loadAvailableUpdates() async {
        await MainActor.run {
            isCheckingForUpdates = true
            updateCheckMessage = localized(key: "ui.checking.for.updates")
        }
        defer {
            Task { @MainActor [weak self] in
                self?.isCheckingForUpdates = false
            }
        }

        do {
            let updates = try await availableUpdates()
            await MainActor.run {
                if updates.isEmpty {
                    updateCheckMessage = localized(key: "ui.djconnect.is.up.to.date")
                    return
                }
                let newestVersion = updates.last?.version ?? appVersion
                updateNotesTitle = localized(key: "appModel.update.available.value", arguments: newestVersion)
                updateNotesBody = updates.map { update in
                    """
                    ### \(update.title.isEmpty ? "DJConnect \(update.version)" : update.title)

                    \(update.body)
                    """
                }.joined(separator: "\n\n")
                updateCheckMessage = localized(
                    key: "appModel.update.available.from.value.to.value",
                    arguments: appVersion,
                    newestVersion
                )
                isShowingUpdateNotes = true
            }
        } catch {
            log(.warning, "Update check failed: \(error.localizedDescription)")
            await MainActor.run {
                updateCheckMessage = localized(key: "appModel.update.check.failed")
            }
        }
    }

    private func availableUpdates() async throws -> [DJConnectAvailableUpdate] {
        guard let currentVersion = DJConnectVersion(appVersion) else {
            return []
        }
        var candidateVersions = try await releaseManifestVersions()
            .compactMap(DJConnectVersion.init)
            .filter { $0 > currentVersion }

        if let newestManifestVersion = candidateVersions
            .filter({ $0.major == currentVersion.major && $0.minor == currentVersion.minor })
            .max(), newestManifestVersion.patch > currentVersion.patch {
            candidateVersions.append(contentsOf: ((currentVersion.patch + 1)...newestManifestVersion.patch).map {
                DJConnectVersion(major: currentVersion.major, minor: currentVersion.minor, patch: $0)
            })
        }

        if candidateVersions.isEmpty {
            candidateVersions = (1...40).map {
                DJConnectVersion(major: currentVersion.major, minor: currentVersion.minor, patch: currentVersion.patch + $0)
            }
        }

        var updates: [DJConnectAvailableUpdate] = []
        var consecutiveMisses = 0
        for version in Array(Set(candidateVersions)).sorted() {
            guard version.major == currentVersion.major, version.minor == currentVersion.minor else {
                continue
            }
            if let update = try await fetchAvailableUpdate(version: version.stringValue) {
                updates.append(update)
                consecutiveMisses = 0
            } else {
                consecutiveMisses += 1
                if updates.isEmpty == false, consecutiveMisses >= 6 {
                    break
                }
            }
        }
        return updates.sorted { lhs, rhs in
            (DJConnectVersion(lhs.version) ?? currentVersion) < (DJConnectVersion(rhs.version) ?? currentVersion)
        }
    }

    private func releaseManifestVersions() async throws -> [String] {
        let candidateURLs = [
            DJConnectAppModel.publicReleaseManifestURL(clientType: identity.clientType, language: releaseNotesLanguageCode),
            DJConnectAppModel.publicReleaseManifestURL(clientType: identity.clientType)
        ].compactMap { $0 }

        var versions: [String] = []
        for url in candidateURLs {
            do {
                var request = URLRequest(url: url)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 5
                let (data, response) = try await urlSession.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                    continue
                }
                let manifest = try JSONDecoder().decode(DJConnectReleaseNotesManifest.self, from: data)
                versions.append(contentsOf: [
                    manifest.latestVersion,
                    manifest.version
                ].compactMap { $0 })
                versions.append(contentsOf: manifest.releases?.compactMap(\.version) ?? [])
            } catch {
                log(.debug, "Release manifest candidate failed: \(url.absoluteString) - \(error.localizedDescription)")
            }
        }
        return versions
    }

    private func fetchAvailableUpdate(version: String) async throws -> DJConnectAvailableUpdate? {
        let candidateURLs = [
            DJConnectAppModel.publicReleaseNotesURL(version: version, clientType: identity.clientType, language: releaseNotesLanguageCode),
            DJConnectAppModel.publicReleaseNotesURL(version: version, clientType: identity.clientType)
        ].compactMap { $0 }

        do {
            let result = try await fetchReleaseNotes(from: candidateURLs)
            let body = localizedReleaseNotesBody((result.release.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
            guard !body.isEmpty else {
                return nil
            }
            let title = (result.release.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedVersion = result.release.version
                ?? result.release.tagName?.split(separator: "/").last.map(String.init)?.trimmingPrefixV
                ?? version
            return DJConnectAvailableUpdate(
                id: resolvedVersion,
                version: resolvedVersion,
                title: title,
                body: body
            )
        } catch {
            return nil
        }
    }

    private func fetchReleaseNotes(from urls: [URL]) async throws -> DJConnectReleaseNotesFetchResult {
        var lastError: Error?
        for url in urls {
            do {
                var request = URLRequest(url: url)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 8
                let (data, response) = try await urlSession.data(for: request)
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
                beginStoredPairingValidation()
                pairingMessage = localized(key: "appModel.djconnect.token.restored.checking.home.assistant.pairing")
                log(.info, "Token storage access restored")
                if startBackgroundTasks {
                    schedulePairedRefresh(reason: "Refreshing after token storage restore")
                }
            } else {
                isShowingTokenStorageError = false
                pairingStatus = .unpaired
                isConnected = false
                pairingMessage = localized(key: "appModel.no.djconnect.token.found.pair.again.to.continue")
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
        pairingMessage = localized(key: "appModel.djconnect.could.not.read.the.saved.device.token")
        log(.error, "Token storage failed: \(error.localizedDescription)")
    }

    private func beginStoredPairingValidation() {
        pairingStatus = .paired
        isConnected = true
        isPairing = false
        backendAvailable = true
        isShowingPairingSuccess = false
        pairingMessage = localized(key: "appModel.checking.saved.home.assistant.pairing")
    }

    public func completePairingScreen() {
        guard pairingStatus == .paired || pairingFlowTarget == .appleWatch else {
            return
        }
        log(.debug, "User action: dismiss pairing success screen")
        isShowingPairingSuccess = false
        isPairingScreenDismissed = pairingStatus == .paired
        pairingFlowTarget = .iPhone
        if shouldShowWakeWordPromptAfterPairingScreen {
            shouldShowWakeWordPromptAfterPairingScreen = false
            presentWakeWordActivationPromptAfterPairing()
        }
    }

    public func dismissAppleWatchPairingForNow() {
        guard isAppleWatchPairingPending else {
            return
        }
        log(.debug, "User action: dismiss Apple Watch pairing for now")
        isShowingPairingSuccess = false
        isPairingScreenDismissed = true
        pairingFlowTarget = .iPhone
    }

    public func presentAppleWatchPairingScreen() {
        guard shouldShowAppleWatchPairingReminder else {
            return
        }
        log(.debug, "User action: reopen Apple Watch pairing screen")
        pairingFlowTarget = .appleWatch
        pairingToken = ""
        isShowingPairingSuccess = false
        isPairingScreenDismissed = false
        pairingMessage = localized(key: "appModel.apple.watch.is.ready.scan.the.apple.watch.qr")
    }

    public func startDemoMode() {
        log(.debug, "User action: start demo mode")
        stopPairingWait()
        isDemoMode = true
        isShowingPairingSuccess = false
        isPairingScreenDismissed = true
        pairingFlowTarget = .iPhone
        shouldShowWakeWordPromptAfterPairingScreen = false
        pairingStatus = .unpaired
        isConnected = false
        isPairing = false
        backendAvailable = true
        updateRequiredMessage = nil
        pairingMessage = localized(key: "appModel.demo.mode.active.home.assistant.is.not.connected")
        clearAskDJHistoryLocally()
        applyDemoState()
        applyDemoMusicDNAProfile()
        log(.info, "Demo mode started")
    }

    public func stopDemoMode() {
        log(.debug, "User action: stop demo mode")
        isDemoMode = false
        defaults.removeObject(forKey: demoModeKey)
        isPairingScreenDismissed = false
        clearRuntimeState()
        pairingMessage = localized(key: "appModel.demo.mode.stopped.pair.with.home.assistant.to.continue")
        log(.info, "Demo mode stopped")
    }

    func presentPairingSuccessScreenAfterPairing() {
        pairingFlowTarget = .iPhone
        isShowingPairingSuccess = true
        isPairingScreenDismissed = false
    }

    public func markCleanShutdown() {
        defaults.set(true, forKey: cleanShutdownKey)
    }

    public func markActiveSession() {
        isAppInForeground = true
        defaults.set(false, forKey: cleanShutdownKey)
        refreshPermissionStatuses()
        resumeWakeWordListeningIfNeeded()
        updatePlaybackProgressTimer()
        updateNowPlayingPollTimer()
        syncTrackInsightLiveActivity(reason: "App became active")
        guard pairingStatus == .paired, !isDemoMode else {
            return
        }
        log(.debug, "App became active; scheduling playback refresh")
        schedulePairedRefresh(
            reason: "Resume Now Playing refresh completed",
            allowThrottle: false,
            refreshCollections: false,
            runFollowUpRefresh: false
        )
    }

    public func markInactiveSession() {
        isAppInForeground = false
        scheduledPairingTask?.cancel()
        scheduledPairingTask = nil
        startupRefreshTask?.cancel()
        startupRefreshTask = nil
        backendRecoveryTask?.cancel()
        backendRecoveryTask = nil
        volumeCommandTask?.cancel()
        volumeCommandTask = nil
        seekCommandTask?.cancel()
        seekCommandTask = nil
        pendingVolumePercent = nil
        pendingSeekTargetMS = nil
        pausePairingWaitForBackgroundIfNeeded()
        playbackProgressTask?.cancel()
        playbackProgressTask = nil
        nowPlayingPollTask?.cancel()
        nowPlayingPollTask = nil
        stopWakeWordListening()
        markCleanShutdown()
        log(.debug, "App left foreground; paused wakeword, pending refresh tasks, local progress timer, and Now Playing poll")
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
        log(.info, "Wakeword enabled from voice activation prompt")
    }

    public func dismissWakeWordActivationPrompt() {
        log(.debug, "User action: dismiss wakeword prompt")
        defaults.set(true, forKey: wakeWordPromptDismissedKey)
        isShowingWakeWordActivationPrompt = false
        log(.info, "Wakeword activation prompt dismissed")
    }

    func presentWakeWordActivationPromptAfterPairing() {
        shouldShowWakeWordPromptAfterPairingScreen = false
        log(.debug, "Skipping automatic wakeword activation prompt after pairing")
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
        DJConnect app crash report

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
        DJConnect app feedback

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

    public func askDJFeedbackIssueURL(for message: DJConnectAskDJMessage, body: String? = nil) -> URL? {
        var components = URLComponents(string: "https://github.com/pcvantol/djconnect/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: askDJFeedbackIssueTitle(for: message)),
            URLQueryItem(name: "body", value: body ?? askDJFeedbackIssueBody(for: message))
        ]
        return components?.url
    }

    public func askDJFeedbackIssueTitle(for message: DJConnectAskDJMessage) -> String {
        let question = askDJFeedbackQuestion(for: message)?.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = question?.isEmpty == false
            ? Self.truncateIssueText(question ?? "", limit: 72)
            : Self.truncateIssueText(message.text, limit: 72)
        return "Ask DJ feedback: \(summary.isEmpty ? "unexpected answer" : summary)"
    }

    public func askDJFeedbackIssueBody(for message: DJConnectAskDJMessage, userNote: String = "") -> String {
        let question = askDJFeedbackQuestion(for: message)
        let relatedMessages = askDJFeedbackRelatedMessages(for: message, question: question)
        let payload = askDJFeedbackPayload(for: message, question: question, relatedMessages: relatedMessages)
        let note = userNote.trimmingCharacters(in: .whitespacesAndNewlines)

        return """
        Ask DJ antwoord-feedback

        Wat voldeed niet aan de verwachting?
        \(note.isEmpty ? "_Vul hier kort in wat er miste, verkeerd was of onverwacht gebeurde._" : note)

        Privacy:
        - Deze draft is lokaal gegenereerd en wordt pas verstuurd als je hem zelf indient.
        - Tokens, client/device-id's, lokale adressen en Home Assistant URL's zijn weggelaten of geredigeerd.
        - Controleer de tekst nog even op persoonlijke informatie voordat je de issue verstuurt.

        ```json
        \(Self.prettyIssueJSON(payload))
        ```
        """
    }

    private func askDJFeedbackQuestion(for message: DJConnectAskDJMessage) -> DJConnectAskDJMessage? {
        let messages = askDJMessages.sorted(by: askDJFeedbackMessagePrecedes)
        if let exchangeID = message.exchangeID, !exchangeID.isEmpty,
           let question = messages.last(where: { candidate in
               candidate.role == .user
                   && candidate.exchangeID == exchangeID
                   && askDJFeedbackMessagePrecedes(candidate, message)
           }) {
            return question
        }
        if let clientMessageID = message.clientMessageID, !clientMessageID.isEmpty,
           let question = messages.last(where: { candidate in
               candidate.role == .user
                   && candidate.clientMessageID == clientMessageID
                   && askDJFeedbackMessagePrecedes(candidate, message)
           }) {
            return question
        }
        return messages.last(where: { candidate in
            candidate.role == .user && askDJFeedbackMessagePrecedes(candidate, message)
        })
    }

    private func askDJFeedbackRelatedMessages(
        for message: DJConnectAskDJMessage,
        question: DJConnectAskDJMessage?
    ) -> [DJConnectAskDJMessage] {
        let messages = askDJMessages.sorted(by: askDJFeedbackMessagePrecedes)
        let anchors = Set([message.id, question?.id].compactMap { $0 })
        let matchingExchange = message.exchangeID?.isEmpty == false ? message.exchangeID : nil
        let matchingClientID = message.clientMessageID?.isEmpty == false ? message.clientMessageID : nil
        let exchangeMessages = messages.filter { candidate in
            guard !anchors.contains(candidate.id) else {
                return false
            }
            return (matchingExchange != nil && candidate.exchangeID == matchingExchange)
                || (matchingClientID != nil && candidate.clientMessageID == matchingClientID)
        }
        if !exchangeMessages.isEmpty {
            return Array(exchangeMessages.prefix(6))
        }
        guard let currentIndex = messages.firstIndex(where: { $0.id == message.id }) else {
            return []
        }
        let lowerBound = max(messages.startIndex, currentIndex - 2)
        let upperBound = min(messages.endIndex, currentIndex + 3)
        return messages[lowerBound..<upperBound].filter { !anchors.contains($0.id) }
    }

    private func askDJFeedbackPayload(
        for message: DJConnectAskDJMessage,
        question: DJConnectAskDJMessage?,
        relatedMessages: [DJConnectAskDJMessage]
    ) -> [String: Any] {
        [
            "app": [
                "version": appVersion,
                "client_type": identity.clientType.rawValue,
                "platform": Self.platformName,
                "pairing_status": pairingStatus.rawValue,
                "demo_mode": isDemoMode,
                "language": language
            ],
            "ask_dj": [
                "question": askDJFeedbackMessageSummary(question),
                "answer": askDJFeedbackMessageSummary(message),
                "follow_up_context": relatedMessages.map(askDJFeedbackMessageSummary(_:)),
                "intent": askDJFeedbackIntentSummary(message.intentInfo),
                "actions": message.playbackActions.map(Self.askDJFeedbackActionSummary(_:)),
                "items": message.items.map(Self.askDJFeedbackItemSummary(_:)),
                "images": message.images.map(Self.askDJFeedbackImageSummary(_:)),
                "links": message.links.map(Self.askDJFeedbackLinkSummary(_:))
            ],
            "playback_snapshot": Self.askDJFeedbackPlaybackSummary(playback)
        ]
    }

    private func askDJFeedbackMessageSummary(_ message: DJConnectAskDJMessage?) -> [String: Any] {
        guard let message else {
            return ["available": false]
        }
        return [
            "available": true,
            "role": message.role.rawValue,
            "kind": message.messageKind.rawValue,
            "origin": message.origin ?? NSNull(),
            "created_at": Self.issueDateFormatter.string(from: message.createdAt),
            "text": Self.truncateIssueText(message.text, limit: 2_500),
            "intent": askDJFeedbackIntentSummary(message.intentInfo),
            "item_count": message.items.count,
            "action_count": message.playbackActions.count,
            "has_audio": message.audioURL != nil
        ]
    }

    private func askDJFeedbackIntentSummary(_ intentInfo: DJConnectAskDJIntentInfo?) -> [String: Any] {
        [
            "intent": intentInfo?.intent ?? NSNull(),
            "action": intentInfo?.action ?? NSNull(),
            "item_type": intentInfo?.itemType ?? NSNull()
        ]
    }

    private func askDJFeedbackMessagePrecedes(_ lhs: DJConnectAskDJMessage, _ rhs: DJConnectAskDJMessage) -> Bool {
        if let lhsExchangeID = lhs.exchangeID,
           let rhsExchangeID = rhs.exchangeID,
           lhsExchangeID == rhsExchangeID {
            let lhsOrder = lhs.exchangeOrder ?? (lhs.role == .user ? 0 : 1)
            let rhsOrder = rhs.exchangeOrder ?? (rhs.role == .user ? 0 : 1)
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            if lhs.role != rhs.role {
                return lhs.role == .user
            }
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func askDJFeedbackActionSummary(_ action: DJConnectAskDJPlaybackAction) -> [String: Any] {
        [
            "id": truncateIssueText(action.id, limit: 160),
            "kind": action.kind ?? NSNull(),
            "command": action.command ?? NSNull(),
            "title": truncateIssueText(action.title, limit: 220),
            "subtitle": truncateOptionalIssueText(action.subtitle, limit: 220) as Any,
            "button_label": truncateOptionalIssueText(action.buttonLabel, limit: 120) as Any,
            "active": action.active as Any? ?? NSNull(),
            "uri": redactIssueURI(action.uri) as Any,
            "uris": action.uris.map { redactIssueURI($0) },
            "context_uri": redactIssueURI(action.contextURI) as Any,
            "offset_uri": redactIssueURI(action.offsetURI) as Any,
            "has_device_name": action.deviceName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            "reason": truncateOptionalIssueText(action.reason, limit: 360) as Any,
            "response_value": truncateOptionalIssueText(action.responseValue, limit: 240) as Any,
            "value": issueJSONValue(action.value)
        ]
    }

    private static func askDJFeedbackItemSummary(_ item: DJConnectAskDJHistoryItem) -> [String: Any] {
        [
            "kind": item.kind ?? NSNull(),
            "title": truncateIssueText(item.title, limit: 220),
            "subtitle": truncateOptionalIssueText(item.subtitle, limit: 220) as Any,
            "uri": redactIssueURI(item.uri) as Any,
            "played_at_label": truncateOptionalIssueText(item.playedAtLabel, limit: 120) as Any,
            "has_image": item.imageURL != nil || item.thumbnailURL != nil
        ]
    }

    private static func askDJFeedbackImageSummary(_ image: DJConnectResponseImage) -> [String: Any] {
        [
            "kind": image.kind ?? NSNull(),
            "source": image.source ?? NSNull(),
            "title": truncateOptionalIssueText(image.title, limit: 180) as Any,
            "subtitle": truncateOptionalIssueText(image.subtitle, limit: 180) as Any,
            "url": safeIssueURLDescription(image.url),
            "thumbnail_url": safeIssueURLDescription(image.thumbnailURL) as Any
        ]
    }

    private static func askDJFeedbackLinkSummary(_ link: DJConnectResponseLink) -> [String: Any] {
        [
            "kind": link.kind ?? NSNull(),
            "source": link.source ?? NSNull(),
            "title": truncateOptionalIssueText(link.title, limit: 180) as Any,
            "subtitle": truncateOptionalIssueText(link.subtitle, limit: 180) as Any,
            "url": safeIssueURLDescription(link.url)
        ]
    }

    private static func askDJFeedbackPlaybackSummary(_ playback: DJConnectPlayback?) -> [String: Any] {
        guard let playback else {
            return ["available": false]
        }
        return [
            "available": true,
            "has_playback": playback.hasPlayback as Any? ?? NSNull(),
            "is_playing": playback.isPlaying as Any? ?? NSNull(),
            "track_name": truncateOptionalIssueText(playback.trackName, limit: 220) as Any,
            "artist_name": truncateOptionalIssueText(playback.artistName, limit: 220) as Any,
            "progress_ms": playback.progressMS as Any? ?? NSNull(),
            "duration_ms": playback.durationMS as Any? ?? NSNull(),
            "volume_percent_known": DJConnectVolumeNormalizer.validBackendPercent(playback.volumePercent) != nil,
            "shuffle": playback.shuffle as Any? ?? NSNull(),
            "repeat_state": playback.repeatState?.rawValue ?? NSNull(),
            "context_uri": redactIssueURI(playback.contextURI) as Any,
            "device": [
                "has_name": playback.device?.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                "type": playback.device?.type ?? NSNull(),
                "active": optionalIssueBool(playback.device?.active),
                "supports_volume": optionalIssueBool(playback.device?.supportsVolume)
            ]
        ]
    }

    private static func optionalIssueBool(_ value: Bool?) -> Any {
        value ?? NSNull()
    }

    private static func issueJSONValue(_ value: DJConnectJSONValue?) -> Any {
        guard let value else {
            return NSNull()
        }
        switch value {
        case let .bool(value):
            return value
        case let .int(value):
            return value
        case let .double(value):
            return value
        case let .string(value):
            return truncateIssueText(value, limit: 500)
        case let .array(values):
            return values.prefix(20).map(issueJSONValue(_:))
        case let .object(object):
            return object.reduce(into: [String: Any]()) { result, pair in
                result[pair.key] = issueJSONValue(pair.value)
            }
        case .null:
            return NSNull()
        }
    }

    private static func prettyIssueJSON(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private static func truncateIssueText(_ value: String, limit: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else {
            return trimmed
        }
        let index = trimmed.index(trimmed.startIndex, offsetBy: limit)
        return String(trimmed[..<index]) + "..."
    }

    private static func truncateOptionalIssueText(_ value: String?, limit: Int) -> Any {
        guard let value else {
            return NSNull()
        }
        return truncateIssueText(value, limit: limit)
    }

    private static func redactIssueURI(_ value: String?) -> Any {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return NSNull()
        }
        if value.lowercased().hasPrefix("spotify:") {
            return value
        }
        if let url = URL(string: value) {
            return safeIssueURLDescription(url)
        }
        return truncateIssueText(value, limit: 240)
    }

    private static func safeIssueURLDescription(_ url: URL?) -> Any {
        guard let url else {
            return NSNull()
        }
        guard let host = url.host, !host.isEmpty else {
            return truncateIssueText(url.absoluteString, limit: 240)
        }
        if isPrivateIssueHost(host) {
            return "[redacted local URL]"
        }
        var components = URLComponents()
        components.scheme = url.scheme
        components.host = host
        components.path = url.path
        return truncateIssueText(components.string ?? host, limit: 240)
    }

    private static func isPrivateIssueHost(_ host: String) -> Bool {
        let lowered = host.lowercased()
        if lowered == "localhost" || lowered.hasSuffix(".local") {
            return true
        }
        if lowered.hasPrefix("10.") || lowered.hasPrefix("192.168.") || lowered.hasPrefix("127.") {
            return true
        }
        let parts = lowered.split(separator: ".").compactMap { Int($0) }
        return parts.count == 4 && parts[0] == 172 && (16...31).contains(parts[1])
    }

    private static var platformName: String {
        #if os(macOS)
        "macOS"
        #elseif os(watchOS)
        "watchOS"
        #elseif os(iOS)
        "iOS"
        #else
        "unknown"
        #endif
    }

    private static var expectedPairingFlowName: String {
        #if os(macOS)
        "macOS"
        #elseif os(watchOS)
        "Apple Watch"
        #elseif os(iOS)
        "iPhone/iPad"
        #else
        "this app"
        #endif
    }

    private static let issueDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let musicDNAFilenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private static func musicDNATransferDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) {
                return date
            }
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            if let date = fallback.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date")
        }
        return decoder
    }

    deinit {
        networkMonitor.cancel()
        scheduledPairingTask?.cancel()
        pairingTask?.cancel()
        volumeCommandTask?.cancel()
        seekCommandTask?.cancel()
        playbackProgressTask?.cancel()
        startupRefreshTask?.cancel()
    }

    private func pausePairingWaitForBackgroundIfNeeded() {
        pairingTask?.cancel()
        pairingTask = nil
        guard pairingStatus == .pairing else {
            return
        }
        isPairing = false
        pairingStatus = .unpaired
        pairingMessage = localized(key: "appModel.pairing.paused.while.djconnect.is.in.the.background")
    }

    public func schedulePairingWait() {
        guard pairingStatus != .paired, pairingStatus != .waitingForHomeAssistantCompletion else {
            log(.debug, "Ignoring scheduled pairing because device pairing is already active")
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
                self.startPairingWait()
            }
        }
    }

    public func confirmPairingHomeAssistantURL() {
        guard pairingStatus != .paired, pairingStatus != .waitingForHomeAssistantCompletion else {
            log(.debug, "Ignoring Home Assistant URL confirmation because device pairing is already active")
            return
        }
        pairingFlowTarget = .iPhone
        log(.info, "User action: confirm Home Assistant URL for pairing")
        startPairingWait()
    }

    public func confirmAppleWatchPairingHomeAssistantURL() {
        #if os(iOS) && canImport(WatchConnectivity)
        guard var registration = watchProxyRegistration else {
            pairingFlowTarget = .appleWatch
            watchPairingMessage = localized(key: "appModel.open.djconnect.on.apple.watch.first.then.enter.the")
            pairingMessage = watchPairingMessage
            return
        }
        guard let baseURL = Self.normalizedHomeAssistantURL(from: homeAssistantURL) else {
            pairingFlowTarget = .appleWatch
            pairingMessage = localized(key: "appModel.enter.the.local.home.assistant.url.for.apple.watch")
            return
        }
        let code = pairingToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count == 6, code.allSatisfy(\.isNumber) else {
            pairingFlowTarget = .appleWatch
            pairingMessage = localized(key: "appModel.enter.the.6.digit.apple.watch.pair.code.shown")
            return
        }
        pairingFlowTarget = .appleWatch
        registration.pairCode = code
        registration.paired = false
        watchProxyRegistration = registration
        persistWatchProxyRegistration()
        watchPairingMessage = localized(key: "appModel.pair.apple.watch.sending.pairing.request.to.home.assistant")
        pairingMessage = watchPairingMessage
        sendWatchProxyMessage([
            "type": "watch_proxy_pair_request",
            "ha_url": Self.redactedURL(baseURL),
            "pair_code": code,
            "pair_path": DJConnectPairingDeepLink.canonicalPairPath
        ])
        Task { @MainActor in
            await self.pairWatchProxy(registration: registration, homeAssistantURL: Self.redactedURL(baseURL), pairCode: code)
        }
        #else
        confirmPairingHomeAssistantURL()
        #endif
    }

    @discardableResult
    public func handlePairingDeepLink(_ url: URL) -> Bool {
        if handleWatchPairingDeepLink(url) {
            return true
        }
        guard pairingStatus != .paired else {
            log(.debug, "Ignoring pairing link because device is already paired")
            return false
        }
        do {
            let payload = try DJConnectPairingDeepLink.parse(url, expectedClientType: identity.clientType)
            pairingFlowTarget = .iPhone
            homeAssistantURL = payload.homeAssistantURL
            pairingToken = payload.pairCode
            pairingMessage = localized(key: "appModel.pairing.link.accepted.pairing.with.home.assistant")
            log(.info, "Accepted DJConnect pairing link for \(identity.clientType.rawValue)")
            startPairingWait()
            return true
        } catch let error as DJConnectError {
            applyInvalidPairingLink(error)
            return false
        } catch {
            applyInvalidPairingLink(nil)
            return false
        }
    }

    @discardableResult
    public func handlePairingQRCode(_ value: String) -> Bool {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            pairingStatus = .unpaired
            isPairing = false
            pairingMessage = localized(key: "appModel.invalid.djconnect.pairing.qr.code")
            log(.warning, "Rejected invalid DJConnect pairing QR code")
            return false
        }
        if handleWatchPairingDeepLink(url) {
            return true
        }
        return handlePairingDeepLink(url)
    }

    private func applyInvalidPairingLink(_ error: DJConnectError?) {
        pairingStatus = .unpaired
        isPairing = false
        pairingMessage = userFacingPairingMessage(from: error.map(Self.describe) ?? "") ?? localized(key: "appModel.invalid.djconnect.pairing.qr.code.or.link")
        log(.warning, "Rejected invalid DJConnect pairing link")
    }

    private func handleWatchPairingDeepLink(_ url: URL) -> Bool {
        #if os(iOS) && canImport(WatchConnectivity)
        do {
            let payload = try DJConnectPairingDeepLink.parse(url, expectedClientType: .watchos)
            pairingFlowTarget = .appleWatch
            isShowingPairingSuccess = false
            isPairingScreenDismissed = false
            startWatchProxyPairing(payload)
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    public func handleWatchPairingQRCode(_ value: String) {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              handleWatchPairingDeepLink(url) else {
            watchPairingMessage = localized(key: "appModel.invalid.apple.watch.pairing.qr.code")
            pairingMessage = watchPairingMessage
            log(.warning, "Rejected invalid Watch pairing QR code")
            return
        }
    }

    #if os(iOS) && canImport(WatchConnectivity)
    private func startWatchProxyPairing(_ payload: DJConnectPairingDeepLink) {
        activateWatchProxySession()
        homeAssistantURL = payload.homeAssistantURL
        pairingToken = payload.pairCode
        guard WCSession.default.activationState == .activated, WCSession.default.isReachable else {
            watchPairingMessage = localized(key: "appModel.apple.watch.is.not.reachable.open.djconnect.on.the")
            pairingMessage = watchPairingMessage
            log(.warning, "Watch pairing link accepted but WatchConnectivity is not reachable")
            return
        }
        guard var registration = watchProxyRegistration else {
            watchPairingMessage = localized(key: "appModel.open.djconnect.on.apple.watch.first.then.scan.the")
            pairingMessage = watchPairingMessage
            log(.warning, "Watch pairing link accepted but no Watch proxy registration is available")
            return
        }
        registration.pairCode = payload.pairCode
        registration.paired = false
        watchProxyRegistration = registration
        persistWatchProxyRegistration()
        watchPairingMessage = localized(key: "appModel.pair.apple.watch.sending.pairing.request.to.home.assistant")
        pairingMessage = watchPairingMessage
        sendWatchProxyMessage([
            "type": "watch_proxy_pair_request",
            "ha_url": payload.homeAssistantURL,
            "pair_code": payload.pairCode,
            "pair_path": payload.pairPath
        ])
        Task { @MainActor in
            await self.pairWatchProxy(registration: registration, homeAssistantURL: payload.homeAssistantURL, pairCode: payload.pairCode)
        }
    }
    #endif

    public func recoverPairingClientAPIIfNeeded() {
        guard !isDemoMode, pairingStatus != .paired, pairingStatus != .waitingForHomeAssistantCompletion else {
            return
        }
        startPairingWait()
    }

    public func startPairingWait() {
        guard !isDemoMode else {
            log(.debug, "Ignoring pairing wait because demo mode is active")
            return
        }
        guard pairingStatus != .paired, pairingStatus != .waitingForHomeAssistantCompletion else {
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

        guard let baseURL = Self.normalizedHomeAssistantURL(from: homeAssistantURL),
              DJConnectPairingURLPolicy.isAllowedPairingURL(baseURL) else {
            log(.warning, "Pairing wait cannot start because the Home Assistant URL is invalid")
            pairingMessage = localized(key: "appModel.enter.your.home.assistant.url.for.example.192.168")
            pairingStatus = .unpaired
            isConnected = false
            isPairing = false
            return
        }

        guard let pairCode = self.normalizedPairCode(from: pairingToken) else {
            log(.warning, "Pairing cannot start because the Home Assistant pair code is invalid")
            pairingMessage = localized(key: "appModel.enter.the.6.digit.pair.code.shown.by.home")
            pairingStatus = .unpaired
            isConnected = false
            isPairing = false
            return
        }

        log(.info, "Starting pairing wait against \(Self.redactedURL(baseURL))")
        pairingStatus = .pairing
        isPairing = true
        pairingTask = Task { [weak self] in
            await self?.pairWithHomeAssistant(baseURL: baseURL, pairCode: pairCode)
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
            pairingMessage = localized(key: "appModel.pairing.wait.stopped")
        }
    }

    private func pairWithHomeAssistant(baseURL: URL, pairCode: String) async {
        isPairing = true
        log(.info, "Posting pairing request to Home Assistant client_type=\(identity.clientType.rawValue)")
        pairingMessage = localized(key: "appModel.pairing.with.home.assistant")
        defer {
            if pairingStatus != .paired {
                isPairing = false
            }
        }

        let client = makeClient(baseURL: baseURL)
        do {
            if baseURL.scheme?.lowercased() == "https",
               !DJConnectPairingURLPolicy.isWhitelistedDevelopmentTunnelURL(baseURL) {
                throw DJConnectError.invalidConfiguration(localized(key: "appModel.pairing.must.be.completed.on.the.same.local.network"))
            }
            let response = try await client.pair(DJConnectPairingPayload(
                identity: identity,
                pairingToken: pairCode,
                haLocalURL: Self.normalizedHomeAssistantURL(from: homeAssistantURL).map(Self.redactedURL)
            ))
            apply(pairingResponse: response, fallbackBaseURL: baseURL)
            log(.info, "Pairing accepted by Home Assistant")
            pairingStatus = .waitingForHomeAssistantCompletion
            isConnected = false
            pairingMessage = localized(key: "appModel.home.assistant.recognized.this.device.finish.setup.in.home")
            if startBackgroundTasks {
                try await waitForHomeAssistantPairingCompletion(client: client)
            }
        } catch let error as DJConnectError {
            logPairingError(error)
            applyPairingWait(error: error, pairingToken: pairCode)
        } catch {
            log(.error, "Unexpected pairing error: \(error.localizedDescription)")
            isConnected = false
            pairingMessage = error.localizedDescription
        }
    }

    private func waitForHomeAssistantPairingCompletion(client: DJConnectClient) async throws {
        let delays: [UInt64] = [0, 2, 3, 5, 5, 5]
        for delay in delays {
            if delay > 0 {
                try await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else {
                return
            }
            do {
                try await refreshStatus(client: client)
                pairingStatus = .paired
                isConnected = true
                isPairing = false
                pairingMessage = localized(key: "appModel.pairing.complete")
                presentPairingSuccessScreenAfterPairing()
                presentWakeWordActivationPromptAfterPairing()
                registerStoredPushTokenIfPossible()
                return
            } catch let error as DJConnectError {
                if isWaitingForHomeAssistantCompletion(error) {
                    pairingStatus = .waitingForHomeAssistantCompletion
                    pairingMessage = localized(key: "appModel.waiting.for.setup.to.be.completed.in.home.assistant")
                    log(.debug, "Waiting for Home Assistant setup completion: \(Self.describe(error))")
                    continue
                }
                if isPairingTokenRejectedAfterPair(error) {
                    applyPairingWait(error: error, pairingToken: pairingToken)
                    return
                }
                throw error
            }
        }
        pairingStatus = .waitingForHomeAssistantCompletion
        isConnected = false
        isPairing = false
        pairingMessage = localized(key: "appModel.not.completed.in.home.assistant.yet.finish.setup.there")
    }

    private func isWaitingForHomeAssistantCompletion(_ error: DJConnectError) -> Bool {
        switch error {
        case .notConfigured, .routeMissing:
            return true
        case let .server(statusCode, message):
            return statusCode == 503 || message?.lowercased().contains("not_configured") == true
        default:
            return false
        }
    }

    private func isPairingTokenRejectedAfterPair(_ error: DJConnectError) -> Bool {
        switch error {
        case .authStale:
            return true
        case let .server(statusCode, _):
            return statusCode == 401 || statusCode == 403
        default:
            return false
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
        defaults.removeObject(forKey: installIDKey)
        currentAPNsPushToken = nil
        defaults.removeObject(forKey: legacyPushTokenKey)
        defaults.removeObject(forKey: registeredPushTokenKey)
        defaults.removeObject(forKey: registeredPushTokenHashKey)
        defaults.removeObject(forKey: registeredPushEnvironmentKey)
        defaults.removeObject(forKey: registeredPushSignatureKey)
        defaults.removeObject(forKey: pushRegisteredKey)
        defaults.removeObject(forKey: pushEnvironmentStatusKey)
        defaults.removeObject(forKey: lastPushErrorKey)
        identity = Self.makeIdentity(defaults: defaults)
        clearRuntimeState()
        clearAskDJHistoryLocally()
        isShowingWakeWordActivationPrompt = false
        isShowingPairingSuccess = false
        isPairingScreenDismissed = false
        shouldShowWakeWordPromptAfterPairingScreen = false
        defaults.set(false, forKey: wakeWordPromptDismissedKey)
        clearPairingToken()
        pairingStatus = .unpaired
        isConnected = false
        isPairing = false
        pairingMessage = localized(key: "appModel.pairing.reset")
    }

    public func clearPairingToken() {
        pairingToken = ""
        defaults.removeObject(forKey: pairingTokenKey)
        log(.info, "Cleared local pairing code placeholder")
    }

    public func rotatePairingTokenAndWait() {
        guard pairingStatus != .paired else {
            return
        }
        clearPairingToken()
        pairingStatus = .unpaired
        pairingMessage = localized(key: "appModel.enter.the.new.pair.code.from.home.assistant")
        startPairingWait()
    }

    public func refresh() {
        log(.debug, "User action: refresh")
        Task {
            await refreshNowPlaying()
        }
    }

    public func refreshNetworkAvailability() {
        log(.debug, "User action: network availability refresh")
        networkRefreshRequestID = UUID()
        updateNowPlayingPollTimer()
        updatePlaybackProgressTimer()
        if !isOfflineModeActive {
            schedulePairingWait()
        }
    }

    @discardableResult
    public func refreshNowPlaying() async -> Bool {
        await runRefresh(reason: "Refresh completed", notifyUserOnError: true, forceCollections: true)
    }

    public func refreshWebSocketFastPathStatus() {
        guard webSocketFastPathEnabled, pairingStatus == .paired else {
            fastPathDiagnostics = DJConnectFastPathDiagnostics()
            return
        }
        Task {
            do {
                try await withHomeAssistantClient { client in
                    try await client.prepareFastPath()
                }
                log(.info, "WebSocket fast path status refreshed")
            } catch let error as DJConnectError {
                log(.warning, "WebSocket fast path status refresh failed: \(Self.describe(error))")
            } catch {
                log(.warning, "WebSocket fast path status refresh failed: \(error.localizedDescription)")
            }
        }
    }

    private func runRefresh(
        reason: String,
        notifyUserOnError: Bool = false,
        forceCollections: Bool = false,
        allowThrottle: Bool = false,
        refreshCollections: Bool = true
    ) async -> Bool {
        guard !isRefreshing else {
            log(.debug, "Refresh ignored because one is already running")
            return false
        }
        if allowThrottle, let lastFullRefreshAt, Date().timeIntervalSince(lastFullRefreshAt) < minimumAutomaticRefreshInterval {
            log(.debug, "Automatic refresh throttled")
            return false
        }
        if isDemoMode {
            log(.debug, "Demo refresh requested")
            isRefreshing = true
            refreshDemoCollections()
            isRefreshing = false
            lastFullRefreshAt = Date()
            log(.info, reason)
            return true
        }
        guard !isOfflineModeActive else {
            log(.debug, "Refresh skipped because device network is offline")
            return false
        }
        log(.debug, "Manual refresh requested")
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await refreshStatusWithFallback()
            lastFullRefreshAt = Date()
            if refreshCollections {
                await refreshBackendCollections(force: forceCollections)
            }
            log(.info, reason)
            return true
        } catch let error as DJConnectError {
            log(.warning, "Refresh failed: \(Self.describe(error))")
            apply(error: error)
            if notifyUserOnError {
                emitUserConnectionNotice(for: error)
            }
            return false
        } catch {
            log(.error, "Refresh failed unexpectedly: \(error.localizedDescription)")
            applyConnectionUnavailableState(message: error.localizedDescription)
            if notifyUserOnError {
                emitUserConnectionNotice()
            }
            return false
        }
    }

    private func schedulePairedRefresh(
        reason: String,
        allowThrottle: Bool = true,
        refreshCollections: Bool = true,
        runFollowUpRefresh: Bool = true
    ) {
        startupRefreshTask?.cancel()
        guard !isOfflineModeActive else {
            log(.debug, "Paired refresh skipped because device network is offline")
            return
        }
        startupRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else {
                return
            }
            _ = await self?.runRefresh(
                reason: reason,
                allowThrottle: allowThrottle,
                refreshCollections: refreshCollections
            )
            guard runFollowUpRefresh else {
                return
            }
            try? await Task.sleep(for: .milliseconds(1_200))
            guard !Task.isCancelled, self?.pairingStatus == .paired else {
                return
            }
            _ = await self?.runRefresh(reason: "Startup Now Playing refresh completed", allowThrottle: true)
        }
    }

    private func scheduleBackendRecoveryRefresh(reason: String) {
        guard startBackgroundTasks, !isDemoMode, pairingStatus == .paired, !backendAvailable, !isOfflineModeActive else {
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
                guard self.pairingStatus == .paired, !self.isDemoMode, !self.backendAvailable, !self.isOfflineModeActive else {
                    self.backendRecoveryTask = nil
                    return
                }
                self.log(.debug, reason)
                _ = await self.runRefresh(reason: "Playback backend recovery refresh completed")
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
            userNotice = DJConnectUserNotice(text: localized(key: "appModel.select.an.output.device.first"))
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
        playPlaybackToggleHaptic(isStarting: !isPlaying)
        sendPlaybackCommand(isPlaying ? "pause" : "play")
    }

    public func commitVolumeChange() {
        volumeCommandTask?.cancel()
        let value = DJConnectVolumeNormalizer.clampBackendPercent(Int(volume.rounded()))
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
            guard self.isAppInForeground else {
                if self.pendingVolumePercent == value {
                    self.pendingVolumePercent = nil
                }
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
        if isDemoMode {
            let currentProgress = playback?.progressMS ?? 0
            commitSeek(to: currentProgress + milliseconds)
            return
        }
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
        if isDemoMode {
            applyDemoSeek(to: target)
            return
        }
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
            guard self.isAppInForeground else {
                if self.pendingSeekTargetMS == target {
                    self.pendingSeekTargetMS = nil
                }
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
        Task {
            guard !isLoadingOutputs else {
                return
            }
            log(.info, "Loading playback outputs")
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
        playPlaylistStartHaptic()
        loadingPlaylistID = playlist.id
        Task {
            let didStart = await performCommand("start_playlist", value: .string(playlist.commandValue), play: true)
            guard didStart, pairingStatus == .paired else {
                loadingPlaylistID = nil
                return
            }
            try? await Task.sleep(for: .milliseconds(1_100))
            guard pairingStatus == .paired, isAppInForeground else {
                loadingPlaylistID = nil
                return
            }
            _ = await runRefresh(reason: "Playlist Now Playing refresh completed")
            loadingPlaylistID = nil
        }
    }

    public func startLikedProxy() {
        log(.debug, "User action: start liked songs")
        log(.info, "Starting liked proxy flow")
        sendPlaybackCommand("start_liked_proxy", play: true)
    }

    public func saveCurrentTrack() {
        toggleCurrentTrackFavorite()
    }

    public func toggleCurrentTrackFavorite() {
        guard !isSavingCurrentTrack else {
            return
        }
        guard canUsePlaybackFeatures else {
            userNotice = DJConnectUserNotice(text: localized(key: "appModel.pair.with.home.assistant.before.saving.tracks"))
            return
        }
        isSavingCurrentTrack = true
        let shouldFavorite = playback?.currentTrackFavoriteStatus != true
        log(.info, shouldFavorite ? "Adding current track to favorites" : "Removing current track from favorites")
        Task {
            defer { isSavingCurrentTrack = false }
            let didToggle = await sendSetCurrentTrackFavoriteCommand(shouldFavorite)
            userNotice = DJConnectUserNotice(text: didToggle ? localized(
                key: shouldFavorite ? "appModel.saved.to.favorites" : "appModel.removed.from.favorites"
            ) : localized(key: "appModel.favorite.status.could.not.be.changed"))
        }
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
        playQueueItemStartHaptic()
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
            guard pairingStatus == .paired, isAppInForeground else {
                loadingQueueItemID = nil
                loadingQueueItemIndex = nil
                return
            }
            _ = await runRefresh(reason: "Queue item Now Playing refresh completed")
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
        playAskDJSendHaptic()
        if isDemoMode {
            askDJDraft = ""
            askDJErrorMessage = nil
            appendAskDJMessage(role: .user, text: text, status: .sent)
            appendAskDJMessage(role: .dj, text: demoAskDJResponse)
            playAskDJResponseHaptic()
            notifyAskDJResponse(demoAskDJResponse)
            return
        }
        guard canUsePlaybackFeatures else {
            askDJErrorMessage = localized(key: "appModel.pair.with.home.assistant.before.using.ask.dj")
            return
        }

        askDJDraft = ""
        askDJErrorMessage = nil
        let clientMessageID = UUID().uuidString
        let messageID = appendAskDJMessage(role: .user, text: text, clientMessageID: clientMessageID, status: .sending)
        submitAskDJText(text, userMessageID: messageID, clientMessageID: clientMessageID)
    }

    public func analyzeCurrentTrack(open: Bool = true, forceRefresh: Bool = false) {
        guard beginTrackInsightRefresh(open: open) else {
            return
        }
        Task {
            defer { isLoadingTrackInsight = false }
            await performTrackInsightRefresh(open: open, forceRefresh: forceRefresh)
        }
    }

    @discardableResult
    public func refreshTrackInsight(open: Bool = true, forceRefresh: Bool = false) async -> Bool {
        guard beginTrackInsightRefresh(open: open) else {
            return false
        }
        defer { isLoadingTrackInsight = false }
        return await performTrackInsightRefresh(open: open, forceRefresh: forceRefresh)
    }

    private func beginTrackInsightRefresh(open: Bool) -> Bool {
        guard !isLoadingTrackInsight else {
            if open {
                trackInsightNavigationRequestID = UUID()
            }
            return false
        }
        isLoadingTrackInsight = true
        trackInsightErrorMessage = nil
        return true
    }

    @discardableResult
    private func performTrackInsightRefresh(open: Bool, forceRefresh: Bool) async -> Bool {
        do {
            let insight: TrackInsight
            if isDemoMode {
                insight = try await DemoTrackInsightService(
                    tracks: DemoTrackInsightService.localizedDefaultTracks(language: language)
                )
                .insight(for: playback)
            } else {
                guard canUsePlaybackFeatures else {
                    throw DJConnectError.invalidConfiguration(
                        localized(key: "appModel.pair.with.home.assistant.before.using.track.insight")
                    )
                }
                let payload = DJConnectTrackInsightRequest(
                    title: playback?.trackName,
                    artist: playback?.artistName,
                    artworkURL: playback?.albumImageURL,
                    durationMS: playback?.durationMS,
                    progressMS: playback?.progressMS,
                    entityID: nil,
                    playerID: playback?.device?.id,
                    musicBackend: musicBackendSummary.musicBackend,
                    clientType: identity.clientType.rawValue,
                    forceRefresh: forceRefresh,
                    locale: language,
                    mood: askDJMoodInt,
                    musicDNAKey: askDJMusicDNAKey,
                    includeVisualProfile: true,
                    includeRawResponse: true
                )
                insight = try await withHomeAssistantClient { client in
                    try await client.trackInsight(payload)
                }
            }
            applyTrackInsight(insight, open: open)
            return true
        } catch let error as DJConnectError {
            trackInsightErrorMessage = trackInsightErrorMessage(for: error)
            log(.warning, "Track Insight failed: \(trackInsightFailureLogDetails(for: error))")
            return false
        } catch {
            trackInsightErrorMessage = trackInsightErrorMessage(for: error)
            log(.warning, "Track Insight failed: \(trackInsightFailureLogDetails(for: error))")
            return false
        }
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

    public func openTrackInsight() {
        if currentTrackInsight != nil || isDemoMode {
            trackInsightNavigationRequestID = UUID()
        } else {
            analyzeCurrentTrack(open: true)
        }
    }

    public func performHomeScreenAction(_ action: DJConnectHomeScreenAction) {
        homeScreenActionRequest = DJConnectHomeScreenActionRequest(action: action)
        switch action {
        case .nowPlaying, .queue, .discovery, .playlists:
            break
        case .askDJ:
            prepareAskDJHistoryForDisplay()
        case .trackInsight:
            openTrackInsight()
        }
    }

    @discardableResult
    public func handleAppNavigationDeepLink(_ url: URL) -> Bool {
        guard let action = DJConnectHomeScreenAction(deepLinkURL: url) else {
            return false
        }
        performHomeScreenAction(action)
        return true
    }

    public func clearHomeScreenActionRequest(_ request: DJConnectHomeScreenActionRequest) {
        if homeScreenActionRequest?.id == request.id {
            homeScreenActionRequest = nil
        }
    }

    public func playAskDJRecommendation(_ action: DJConnectAskDJPlaybackAction) {
        guard playingAskDJActionID == nil else {
            return
        }
        if action.isFavoriteCurrentTrackControlAction {
            setCurrentTrackFavoriteFromAskDJ(action)
            return
        }
        if action.isAskDJMessageAction {
            sendAskDJFollowUpAction(action)
            return
        }
        guard canUsePlaybackFeatures else {
            askDJErrorMessage = localized(key: "appModel.pair.with.home.assistant.before.playing.recommendations")
            return
        }
        guard action.command?.isEmpty == false
            || action.isOutputAction
            || action.isRecommendationAction
            || action.isConfirmationAction else {
            showAskDJToast(localized(key: "appModel.this.recommendation.cannot.be.played.yet"))
            return
        }

        playingAskDJActionID = action.id
        askDJErrorMessage = nil
        playAskDJActionHaptic()
        log(.info, "Sending Ask DJ Play Now recommendation action")

        Task {
            defer { playingAskDJActionID = nil }
            do {
                let response = try await playAskDJRecommendationWithFallback(action)
                apply(commandResponse: response)
                if applyAskDJPlayNowCommandResponse(response) {
                    if response.success {
                        showAskDJToast(localized(key: "appModel.playing.recommendation"))
                        playAskDJResponseHaptic()
                        await refreshAfterDJResponse()
                        log(.info, "Ask DJ Play Now assistant response rendered")
                        return
                    }
                }
                guard response.success else {
                    if renderAskDJCommandPlaybackActions(response) {
                        return
                    }
                    showAskDJToast(response.error ?? response.message ?? localized(key: "appModel.action.could.not.be.completed"))
                    log(.warning, "Ask DJ action was rejected by Home Assistant")
                    return
                }
                if renderAskDJCommandPlaybackActions(response) {
                    playAskDJResponseHaptic()
                    await refreshAfterDJResponse()
                    return
                }
                if action.isOutputAction, let outputDeviceID = action.outputDeviceID {
                    markAskDJOutputActionActive(outputDeviceID)
                    showAskDJToast(localized(key: "appModel.output.changed"))
                } else {
                    showAskDJToast(localized(key: "appModel.playing.recommendation"))
                }
                playAskDJResponseHaptic()
                await refreshAfterDJResponse()
                log(.info, "Ask DJ action completed")
            } catch let error as DJConnectError {
                askDJErrorMessage = askDJErrorText(for: error)
                showAskDJToast(for: error)
                log(.warning, "Ask DJ action failed: \(Self.describe(error))")
            } catch {
                askDJErrorMessage = askDJUnavailableText()
                showAskDJToast(localized(key: "appModel.ask.dj.is.unreachable"))
                log(.error, "Ask DJ action failed unexpectedly: \(error.localizedDescription)")
            }
        }
    }

    private func sendAskDJFollowUpAction(_ action: DJConnectAskDJPlaybackAction) {
        guard canUsePlaybackFeatures else {
            askDJErrorMessage = localized(key: "appModel.pair.with.home.assistant.before.using.ask.dj")
            return
        }
        guard let text = action.resolvedAskDJMessageText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            showAskDJToast(localized(key: "appModel.this.recommendation.cannot.be.played.yet"))
            return
        }
        playingAskDJActionID = action.id
        askDJErrorMessage = nil
        playAskDJSendHaptic()
        let clientMessageID = UUID().uuidString
        let messageID = appendAskDJMessage(role: .user, text: text, clientMessageID: clientMessageID, status: .sending)
        log(.info, "Sending Ask DJ follow-up action")
        Task {
            defer { playingAskDJActionID = nil }
            do {
                let response = try await sendAskDJTextWithFallback(text, clientMessageID: clientMessageID)
                applyAskDJMessageResponse(response, fallbackUserMessageID: messageID)
                if let messageID {
                    updateAskDJMessageStatus(id: messageID, status: .sent)
                }
                requestAskDJScrollToBottom()
                await refreshAfterDJResponse()
            } catch let error as DJConnectError {
                if let messageID {
                    updateAskDJMessageStatus(id: messageID, status: .failed)
                }
                askDJErrorMessage = askDJErrorText(for: error)
                showAskDJToast(for: error)
                log(.warning, "Ask DJ follow-up action failed: \(Self.describe(error))")
            } catch {
                if let messageID {
                    updateAskDJMessageStatus(id: messageID, status: .failed)
                }
                askDJErrorMessage = askDJUnavailableText()
                showAskDJToast(localized(key: "appModel.ask.dj.is.unreachable"))
                log(.error, "Ask DJ follow-up action failed unexpectedly: \(error.localizedDescription)")
            }
        }
    }

    @discardableResult
    func applyAskDJPlayNowCommandResponse(_ response: DJConnectCommandResponse) -> Bool {
        guard let assistantMessage = response.assistantMessage else {
            return false
        }
        let role: DJConnectAskDJMessageRole = assistantMessage.role == .user ? .user : .dj
        guard role == .dj else {
            return false
        }
        var nextMessages = askDJMessages
        upsertAskDJHistoryMessage(assistantMessage, into: &nextMessages, fallbackID: nil)
        coalesceAskDJMessages(&nextMessages)
        askDJMessages = sortedAskDJMessages(nextMessages)
        saveAskDJMessages()
        requestAskDJScrollToBottom()
        return true
    }

    @discardableResult
    private func renderAskDJCommandPlaybackActions(_ response: DJConnectCommandResponse) -> Bool {
        guard let actions = response.playbackActions, !actions.isEmpty else {
            return false
        }
        appendAskDJMessage(
            role: .dj,
            text: response.message ?? localized(key: "appModel.choose.a.speaker.to.continue"),
            playbackActions: actions
        )
        askDJScrollRequestID = UUID()
        return true
    }

    private func setCurrentTrackFavoriteFromAskDJ(_ action: DJConnectAskDJPlaybackAction) {
        guard canUsePlaybackFeatures else {
            askDJErrorMessage = localized(key: "appModel.pair.with.home.assistant.before.saving.tracks")
            return
        }
        playingAskDJActionID = action.id
        askDJErrorMessage = nil
        log(.info, "Sending Ask DJ favorite-current-track control action")
        Task {
            defer { playingAskDJActionID = nil }
            let didToggle = await sendFavoriteActionCommand(action)
            if didToggle {
                markAskDJActionCompleted(action.id)
                showAskDJToast(localized(key: "appModel.favorite.status.updated"))
            } else {
                showAskDJToast(localized(key: "appModel.favorite.status.could.not.be.changed"))
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
                applyTrackInsightIfNeeded(from: response, open: true)
                let assistant = response.assistantMessage
                let responseText = userFacingDJResponseText(assistant?.text)
                    ?? localized(key: "appModel.ask.dj.completed")
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
                if isDeferredAskDJTimeout(error) {
                    askDJErrorMessage = nil
                    showAskDJToast(localized(key: "appModel.ask.dj.is.processing"))
                    if let userMessageID {
                        updateAskDJMessageStatus(id: userMessageID, status: .sent)
                    }
                    await syncAskDJHistoryAfterDeferredAskDJResponse()
                    await refreshAfterDJResponse()
                } else {
                    askDJErrorMessage = askDJErrorText(for: error)
                    showAskDJToast(for: error)
                    if let userMessageID {
                        updateAskDJMessageStatus(id: userMessageID, status: .failed)
                    }
                    if case .backendUnavailable = error {
                        await refreshAfterDJResponse()
                    } else {
                        apply(error: error)
                    }
                }
                log(.warning, "Ask DJ text request failed: \(describedError)")
            } catch {
                if isDeferredAskDJTimeout(error) {
                    askDJErrorMessage = nil
                    showAskDJToast(localized(key: "appModel.ask.dj.is.processing"))
                    if let userMessageID {
                        updateAskDJMessageStatus(id: userMessageID, status: .sent)
                    }
                    await syncAskDJHistoryAfterDeferredAskDJResponse()
                    await refreshAfterDJResponse()
                } else {
                    askDJErrorMessage = askDJUnavailableText()
                    showAskDJToast(localized(key: "appModel.ask.dj.is.unreachable"))
                    if let userMessageID {
                        updateAskDJMessageStatus(id: userMessageID, status: .failed)
                    }
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
                clearAskDJHistoryLocally()
                applyAskDJHistory(response, forceClear: response.isClearAcknowledged)
            } catch let error as DJConnectError {
                askDJErrorMessage = askDJErrorText(for: error)
                showAskDJToast(for: error)
                log(.warning, "Ask DJ clear request failed: \(Self.describe(error))")
            } catch {
                askDJErrorMessage = askDJUnavailableText()
                showAskDJToast(localized(key: "appModel.ask.dj.is.unreachable"))
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
        if isAppInForeground {
            isCheckingAskDJHistoryState = true
            askDJErrorMessage = nil
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
            guard isAppInForeground else {
                continue
            }
            await syncAskDJHistory(showErrors: false)
        }
    }

    @discardableResult
    public func refreshAskDJHistory(showToast: Bool = false) async -> Bool {
        guard !isDemoMode else {
            askDJErrorMessage = nil
            log(.debug, "Ask DJ refresh skipped in demo mode")
            return false
        }
        guard canUsePlaybackFeatures else {
            log(.warning, "Ask DJ refresh skipped because playback features are unavailable")
            if showToast {
                showAskDJToast(localized(key: "appModel.ask.dj.is.unreachable"))
            }
            return false
        }
        askDJErrorMessage = nil
        isCheckingAskDJHistoryState = true
        defer { isCheckingAskDJHistoryState = false }
        log(.info, "Refreshing Ask DJ history from user action")
        let didSync = await syncAskDJHistory(showErrors: true)
        await requestAskDJIdleSuggestionIfNeeded()
        if didSync, showToast {
            showAskDJToast(localized(key: "appModel.ask.dj.updated"))
        }
        return didSync
    }

    public func startVoiceRecording() {
        guard !isRecordingVoice, voiceStatus != .processing else {
            return
        }
        stopResponsePlayback(clearText: true)
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
            permissionExplanationKind = .microphone
            isShowingPermissionExplanation = true
            log(.debug, "Showing microphone permission explanation before voice recording")
            return
        }
        shouldBypassPermissionExplanationOnce = false
        if isDemoMode {
            startDemoVoiceRequestAfterPermission()
            return
        }
        guard pairingStatus == .paired else {
            dismissWakeWordListeningMessage()
            voiceStatus = .unavailable
            voiceErrorMessage = localized(key: "appModel.pair.with.home.assistant.before.using.voice")
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
                voiceErrorMessage = localized(key: "appModel.microphone.access.is.required.for.push.to.talk")
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
            await beginVoiceRecording()
            voiceStartTask = nil
        }
    }

    private func startDemoVoiceRequestAfterPermission() {
        voiceStartTask?.cancel()
        isRecordingVoice = true
        voiceStatus = .listening
        voiceErrorMessage = nil

        voiceStartTask = Task { @MainActor in
            let granted = await requestMicrophoneAccess()
            guard !Task.isCancelled, isRecordingVoice else {
                return
            }
            isRecordingVoice = false
            voiceStartTask = nil
            guard granted else {
                dismissWakeWordListeningMessage()
                voiceStatus = .unavailable
                voiceErrorMessage = localized(key: "appModel.microphone.access.is.required.for.push.to.talk")
                log(.warning, "Demo voice request ignored because microphone permission was not granted")
                resumeWakeWordListeningIfNeeded()
                return
            }
            voiceStatus = .processing
            let demoResponse = "Ja ja, daar is hij dan, de knaller van Luna Vale, Neonregen!"
            djResponseText = demoResponse
            appendAskDJMessage(role: .user, text: localized(key: "appModel.voice.request"))
            appendAskDJMessage(role: .dj, text: demoResponse)
            notifyAskDJResponse(demoResponse)
            speakDemoResponse(demoResponse)
            voiceStatus = .idle
            log(.info, "Demo voice request completed")
        }
    }

    private func showWakeWordListeningMessage() {
        transientAskDJListeningMessage = DJConnectAskDJMessage(
            role: .dj,
            origin: "wakeword_listening",
            text: localized(key: "appModel.i.m.listening")
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
            text: localized(key: "appModel.mood.set.to.value", arguments: askDJMoodLabel)
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
        Task {
            try? await setDJConnectAudioSessionActive(false, options: .notifyOthersOnDeactivation)
        }
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
        Task {
            try? await setDJConnectAudioSessionActive(false, options: .notifyOthersOnDeactivation)
        }
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
                djResponseText = userFacingDJResponseText(response.djText ?? response.text) ?? localized(key: "appModel.voice.request.completed")
                appendAskDJMessage(role: .user, text: localized(key: "appModel.voice.request"))
                appendAskDJMessage(
                    role: .dj,
                    text: djResponseText,
                    images: proxiedResponseImages(response.images),
                    links: safeResponseLinks(response.links),
                    playbackActions: proxiedPlaybackActions(response.playbackActions ?? []),
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
                showAskDJToast(localized(key: "appModel.ask.dj.is.unreachable"))
                voiceStatus = .unavailable
                log(.error, "Voice upload failed unexpectedly: \(error.localizedDescription)")
                resumeWakeWordListeningIfNeeded()
            }
        }
        #else
        isRecordingVoice = false
        voiceStatus = .unavailable
        dismissWakeWordListeningMessage()
        voiceErrorMessage = localized(key: "appModel.voice.recording.is.not.available.on.this.platform")
        #endif
    }

    public func apply(playback: DJConnectPlayback?) {
        guard isRuntimeCompatible else {
            log(.debug, "Ignoring playback snapshot because Home Assistant integration version is incompatible")
            return
        }
        var normalizedPlayback = DJConnectVolumeNormalizer.sanitizedPlayback(playback)
        let deviceVolume = DJConnectVolumeNormalizer.validBackendPercent(normalizedPlayback?.device?.volumePercent)
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
        updateNowPlayingWidgetSnapshot(playback: normalizedPlayback)
        if !hasActiveNowPlaying || !currentTrackInsightMatchesPlayback() {
            currentTrackInsight = nil
            clearTrackInsightWidgetSnapshot(reason: "No matching active playback")
        }
        scheduleVibeCastAutoTrackInsightIfNeeded(reason: "Playback snapshot changed")
        syncTrackInsightLiveActivity(reason: normalizedPlayback == nil ? "Empty playback snapshot" : "Playback snapshot changed")
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
            let progress = normalizedPlayback.progressMS.map(String.init) ?? "unknown"
            let duration = normalizedPlayback.durationMS.map(String.init) ?? "unknown"
            log(.debug, "Applied playback snapshot: playing=\(playing), volume=\(volume), progress=\(progress), duration=\(duration)")
        } else {
            log(.debug, "Applied empty playback snapshot")
        }
    }

    public func apply(commandResponse response: DJConnectCommandResponse) {
        apply(commandResponse: response, command: nil)
    }

    private func apply(commandResponse response: DJConnectCommandResponse, command: String?) {
        guard validateHomeAssistantVersion(
            haVersion: response.haVersion,
            haMajorMinor: response.haMajorMinor,
            message: response.message
        ) else {
            return
        }
        applyPushRegistrationStatus(from: response)
        apply(musicBackendSummary: DJConnectMusicBackendSummary(
            remoteSupported: response.remoteSupported,
            musicBackend: response.musicBackend,
            musicBackendName: response.musicBackendName,
            musicBackendAvailable: response.musicBackendAvailable,
            musicBackendRevision: response.musicBackendRevision,
            musicBackendCapabilities: response.musicBackendCapabilities,
            musicTargetPlayer: response.musicTargetPlayer,
            musicBackendError: response.musicBackendError
        ))
        if response.success == false {
            switch response.error {
            case "stale_backend_action":
                userNotice = DJConnectUserNotice(text: localized(key: "appModel.this.action.belongs.to.a.previous.music.backend.ask"))
            case "unsupported_backend_capability":
                userNotice = DJConnectUserNotice(text: response.message ?? localized(key: "appModel.this.music.backend.does.not.support.that.action"))
            default:
                break
            }
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
        let shouldApplyQueue = command == nil || command == "queue"
        let shouldApplyPlaylists = command == nil || command == "playlists"
        if shouldApplyQueue, let responseQueue = response.queue {
            let normalizedQueue = normalizedQueueItems(responseQueue)
            queueItems = normalizedQueue
            queue = normalizedQueue.map(\.displayTitle)
            updateQueueWidgetSnapshot(items: normalizedQueue)
        }
        if shouldApplyQueue, response.queueContext != nil || response.queue != nil {
            queueContext = response.queueContext
        }
        if shouldApplyPlaylists, let responsePlaylists = response.playlists {
            playlistItems = responsePlaylists
            playlists = responsePlaylists.map(\.name)
        }
        if let message = response.message, !message.isEmpty {
            djResponseText = userFacingDJResponseText(message) ?? message
        }
        if response.success != false, Self.shouldRefreshMusicDNAAfterCommand(command) {
            scheduleMusicDNAProfileRefresh(reason: command.map { "playback command \($0)" } ?? "playback response")
        }
    }

    private static func shouldRefreshMusicDNAAfterCommand(_ command: String?) -> Bool {
        guard let command = command?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !command.isEmpty else {
            return false
        }
        return command.contains("play")
            || command == "next"
            || command == "previous"
            || command == "skip"
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
            item.durationMS.map(String.init)
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
        DJConnectLocalization.localized(key: "ui.no.output.device.selected", language: language)
    }

    private static let legacyNoOutputNames: Set<String> = [
        "Geen",
        "None",
        "Geen uitvoerapparaat geselecteerd",
        "No output device selected"
    ]

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
        if let remoteURL = response.haRemoteURL.flatMap(Self.normalizedHomeAssistantURL(from:)) {
            haRemoteURL = Self.redactedURL(remoteURL)
            defaults.set(haRemoteURL, forKey: haRemoteURLKey)
        } else {
            haRemoteURL = ""
            defaults.removeObject(forKey: haRemoteURLKey)
        }
        remoteSupported = response.remoteSupported ?? !haRemoteURL.isEmpty
        apply(musicBackendSummary: DJConnectMusicBackendSummary(
            remoteSupported: response.remoteSupported,
            musicBackend: response.musicBackend,
            musicBackendName: response.musicBackendName,
            musicBackendAvailable: response.musicBackendAvailable,
            musicBackendRevision: response.musicBackendRevision,
            musicBackendCapabilities: response.musicBackendCapabilities,
            musicTargetPlayer: response.musicTargetPlayer,
            musicBackendError: response.musicBackendError
        ))
        defaults.removeObject(forKey: "DJConnectHAActiveURL")
        if let pipelineID = response.assistPipelineID, !pipelineID.isEmpty {
            assistPipelineID = pipelineID
            defaults.set(pipelineID, forKey: assistPipelineIDKey)
        }
        apply(pairingContract: response)
    }

    private func apply(pairingContract response: DJConnectPairingResponse) {
        if let value = response.apiBase {
            apiBase = value
            defaults.set(value, forKey: apiBaseKey)
        }
        if let value = response.voicePath {
            voicePath = value
            defaults.set(value, forKey: voicePathKey)
        }
        if let value = response.statusPath {
            statusPath = value
            defaults.set(value, forKey: statusPathKey)
        }
        if let value = response.eventPath {
            eventPath = value
            defaults.set(value, forKey: eventPathKey)
        }
        if let value = response.askDJSupported {
            askDJSupported = value
            defaults.set(value, forKey: askDJSupportedKey)
        }
        if let value = response.askDJVoiceSupported {
            askDJVoiceSupported = value
            defaults.set(value, forKey: askDJVoiceSupportedKey)
        }
        if let value = response.askDJAudioResponseSupported {
            askDJAudioResponseSupported = value
            defaults.set(value, forKey: askDJAudioResponseSupportedKey)
        }
    }

    public func apply(musicBackendSummary summary: DJConnectMusicBackendSummary) {
        musicBackendSummary = summary
        if let remoteSupported = summary.remoteSupported {
            self.remoteSupported = remoteSupported
        }
        if summary.musicBackendAvailable == false {
            backendAvailable = false
        }
    }

    public func apply(watchProxyDJResponse response: DJConnectWatchProxyDJResponseRequest) {
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
            updateRequiredMessage = mismatch.message ?? localized(key: "appModel.update.the.djconnect.app.or.home.assistant.integration")
        case let .authStale(_, message):
            recoverFromStalePairing(message: message)
        case let .routeMissing(message):
            clearMusicDNADisplay()
            pairingStatus = .stale
            isConnected = false
            pairingMessage = message ?? localized(key: "appModel.djconnect.route.missing.in.home.assistant.check.the.integration")
        case let .notConfigured(message):
            if isPairingFlowActive {
                isConnected = false
                pairingMessage = localized(key: "appModel.waiting.for.setup.to.be.completed.in.home.assistant")
            } else {
                recoverFromStalePairing(message: message ?? localized(key: "appModel.not.connected.to.home.assistant"))
            }
        case let .server(_, message):
            if let userFacingError = userFacingDJResponseText(message ?? Self.describe(error)) {
                djResponseText = userFacingError
            }
        case .missingToken:
            recoverFromStalePairing(message: localized(key: "appModel.missing.djconnect.bearer.token.reset.pairing.to.set.up"))
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
        clearPairingToken()
        clearAskDJHistoryLocally()
        clearMusicDNADisplay()
        pairingStatus = .stale
        isConnected = false
        isPairing = false
        isPairingScreenDismissed = false
        isShowingPairingSuccess = false
        pairingMessage = message ?? localized(key: "appModel.pairing.is.stale.open.home.assistant.setup.and.enter")
    }

    private var isPairingFlowActive: Bool {
        isPairing || pairingStatus == .pairing || pairingStatus == .waitingForHomeAssistantCompletion
    }

    public func emitUserConnectionNotice(for error: DJConnectError? = nil) {
        if let error, !Self.shouldShowConnectionNotice(for: error) {
            return
        }
        let text = error.map { Self.isMusicBackendUnavailableError($0) } == true
            ? localized(key: "appModel.music.backend.unavailable")
            : localized(key: "appModel.no.connection.to.home.assistant")
        userNotice = DJConnectUserNotice(text: text)
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
            pairingMessage = localized(key: "appModel.home.assistant.is.unreachable")
        }
        if let message, !message.isEmpty {
            log(.warning, "Home Assistant unavailable: \(message)")
        }
    }

    private static func shouldShowConnectionNotice(for error: DJConnectError) -> Bool {
        switch error {
        case .backendUnavailable, .server, .network, .decodingFailed, .invalidResponse, .routeMissing:
            true
        case .authStale, .versionMismatch, .notConfigured, .invalidConfiguration, .missingToken, .pairingFailed, .clientTypeMismatch, .trackInsightUnavailable:
            false
        }
    }

    func applyPairingWait(error: DJConnectError, pairingToken: String) {
        isConnected = false

        switch error {
        case .pairingFailed:
            pairingStatus = .unpaired
            pairingMessage = pairingCodeRejectedMessage()
        case let .clientTypeMismatch(_, expectedClientType, receivedClientType):
            pairingStatus = .unpaired
            isPairing = false
            pairingMessage = DJConnectErrorPresentation.userMessage(
                for: error,
                language: language,
                context: .pairing(expectedPairingFlowName: Self.expectedPairingFlowName)
            ) ?? pairingClientTypeMismatchMessage()
            log(
                .debug,
                "Pairing client_type_mismatch expected=\(expectedClientType ?? "<missing>") received=\(receivedClientType ?? "<missing>")"
            )
        case let .network(message):
            pairingStatus = .unpaired
            pairingMessage = userFacingPairingNetworkMessage(from: message)
        case .routeMissing:
            pairingStatus = .unpaired
            pairingMessage = DJConnectErrorPresentation.userMessage(
                for: error,
                language: language,
                context: .pairing(expectedPairingFlowName: Self.expectedPairingFlowName)
            )
        case let .server(_, message):
            pairingStatus = .unpaired
            pairingMessage = DJConnectErrorPresentation.userMessage(
                for: error,
                language: language,
                context: .pairing(expectedPairingFlowName: Self.expectedPairingFlowName)
            )
                ?? userFacingPairingHTTPMessage(from: error)
                ?? userFacingPairingMessage(from: message) ?? localized(key: "appModel.home.assistant.could.not.complete.pairing.check.the.pair")
        case let .authStale(_, message):
            pairingStatus = .unpaired
            isPairing = false
            pairingMessage = DJConnectErrorPresentation.userMessage(
                for: error,
                language: language,
                context: .pairing(expectedPairingFlowName: Self.expectedPairingFlowName)
            )
                ?? userFacingPairingHTTPMessage(from: error)
                ?? userFacingPairingMessage(from: message) ?? localized(key: "appModel.home.assistant.rejected.this.pair.code.generate.a.fresh")
            if let message, !message.isEmpty {
                log(.debug, "Home Assistant rejected pairing code: \(message)")
            }
        case let .versionMismatch(mismatch):
            pairingStatus = .unpaired
            updateRequiredMessage = mismatch.message ?? localized(key: "appModel.djconnect.update.required")
        case let .notConfigured(message):
            pairingStatus = .unpaired
            pairingMessage = DJConnectErrorPresentation.userMessage(
                for: error,
                language: language,
                context: .pairing(expectedPairingFlowName: Self.expectedPairingFlowName)
            ) ?? userFacingPairingMessage(from: message) ?? pairingCodeRejectedMessage()
        case let .invalidConfiguration(message):
            pairingStatus = .unpaired
            pairingMessage = message
        default:
            pairingStatus = .unpaired
            pairingMessage = localized(key: "appModel.home.assistant.could.not.complete.pairing.check.the.url")
        }
    }

    private func pairingWaitMessage(pairingToken: String) -> String {
        localized(key: "appModel.enter.the.6.digit.pair.code.shown.by.home")
    }

    private func pairingCodeRejectedMessage() -> String {
        localized(key: "appModel.pair.code.is.incorrect.check.the.code.in.home")
    }

    private func wrongPairingClientTypeMessage() -> String {
        DJConnectLocalization.localized(
            key: "pairing.error.invalidClientType",
            language: language,
            arguments: Self.expectedPairingFlowName
        )
    }

    private func pairingClientTypeMismatchMessage() -> String {
        DJConnectLocalization.localized(
            key: "pairing.error.clientTypeMismatch",
            language: language,
            arguments: Self.expectedPairingFlowName
        )
    }

    private func trackInsightClientTypeMessage() -> String {
        localized(
            key: "appModel.home.assistant.expected.a.different.djconnect.app.type.choose",
            arguments: Self.expectedPairingFlowName
        )
    }

    private func isClientTypeErrorText(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return normalized.contains("invalid_client_type")
            || normalized.contains("client_type_mismatch")
            || normalized.contains("valid djconnect client_type")
            || normalized.contains("invalid client type")
            || normalized.contains("client type")
            || normalized.contains("client_type")
    }

    func isTerminalPairingError(_ error: DJConnectError) -> Bool {
        return false
    }

    private func refreshStatus(client: DJConnectClient) async throws {
        do {
            log(.debug, "Posting status to Home Assistant")
            let response = try await client.postStatus(
                DJConnectStatusPayload(
                    identity: identity,
                    haPairingStatus: .paired,
                    language: currentRequestLocale,
                    logLevel: logLevel,
                    localAudioSupported: true,
                    voiceSupported: voiceEnabled,
                    haLocalURL: haLocalURL.isEmpty ? nil : haLocalURL,
                    voiceEnabled: voiceEnabled,
                    wakewordEnabled: wakeWordEnabled,
                    wakewordPhrase: wakeWordPhrase,
                    wakewordStatus: "\(wakeWordStatus)",
                    mood: askDJMoodInt,
                    musicDNAKey: askDJMusicDNAKey
                )
            )
            guard validateHomeAssistantVersion(
                haVersion: response.haVersion,
                haMajorMinor: response.haMajorMinor,
                message: response.message
            ) else {
                return
            }
            apply(musicBackendSummary: response.musicBackendSummary)
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
        let didLoadDevices = await performCommand("devices", notifyUserOnError: false, applyErrorState: false)
        let didLoadQueue = await performCommand("queue", notifyUserOnError: false, applyErrorState: false)
        let didLoadPlaylists = await performCommand("playlists", notifyUserOnError: false, applyErrorState: false)
        if didLoadDevices || didLoadQueue || didLoadPlaylists {
            lastBackendCollectionsRefreshAt = Date()
        } else {
            log(.debug, "Backend collection refresh did not update throttle because all collection commands failed")
        }
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
                    command: "status",
                    language: currentRequestLocale,
                    mood: askDJMoodInt,
                    musicDNAKey: askDJMusicDNAKey
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
        currentTrackInsight = nil
        clearMusicDNADisplay()
        clearNowPlayingWidgetSnapshot(reason: "Runtime state cleared")
        clearTrackInsightWidgetSnapshot(reason: "Runtime state cleared")
        clearAskDJWidgetSnapshot(reason: "Runtime state cleared")
        syncTrackInsightLiveActivity(reason: "Runtime state cleared")
        queue = []
        playlists = []
        availableOutputs = []
        queueItems = []
        clearQueueWidgetSnapshot(reason: "Runtime state cleared")
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
        Task {
            do {
                try await configureDJConnectAudioSession(category: .playback, mode: .spokenAudio, options: [.duckOthers])
                try await setDJConnectAudioSessionActive(true)
            } catch {
                log(.warning, "Demo DJ response audio session could not be configured: \(error.localizedDescription)")
            }
        }
        #endif
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.speechLocaleIdentifier(for: language))
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
                key: "appModel.update.the.djconnect.app.or.home.assistant.integration.to",
                arguments: requiredRange
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

    private static func appLanguageOverride(defaults: UserDefaults) -> String {
        DJConnectLocalization.languageOverrideCode(
            defaults.string(forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
        )
    }

    private static func resolvedLanguage(defaults: UserDefaults) -> String {
        DJConnectLocalization.resolvedLanguageCode(
            override: defaults.string(forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
        )
    }

    private static func syncAppLanguageOverrideToSharedDefaults(_ overrideCode: String) {
        guard let sharedDefaults = UserDefaults(suiteName: DJConnectLocalization.appGroupIdentifier) else {
            return
        }
        if overrideCode.isEmpty {
            sharedDefaults.removeObject(forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
        } else {
            sharedDefaults.set(overrideCode, forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
        }
    }

    private static func syncAskDJMoodToSharedDefaults(_ mood: Double) {
        guard let sharedDefaults = UserDefaults(suiteName: DJConnectLocalization.appGroupIdentifier) else {
            return
        }
        sharedDefaults.set(max(0, min(100, mood)), forKey: "DJConnectAskDJMood")
    }

    private func reloadWidgetTimelinesForMoodChange() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func reloadWidgetTimelinesForLanguageChange() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func speechLocaleIdentifier(for language: String) -> String {
        DJConnectLocalization.bcp47LocaleIdentifier(for: language)
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
        guard isAppInForeground, playback?.isPlaying == true, !isOfflineModeActive else {
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
                if self?.isDemoMode == true {
                    continue
                }
                if shouldRefresh || tick >= (self?.progressTimerNetworkRefreshInterval ?? 60) {
                    tick = 0
                    await self?.refreshNowPlayingFromProgressTimer()
                }
            }
        }
    }

    private func updateNowPlayingPollTimer() {
        nowPlayingPollTask?.cancel()
        guard startBackgroundTasks, isAppInForeground, pairingStatus == .paired, !isDemoMode, !isOfflineModeActive else {
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
        guard pairingStatus == .paired, !isDemoMode, !isRefreshing, isRuntimeCompatible, isConnected, backendAvailable, !isOfflineModeActive else {
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
        guard pairingStatus == .paired, !isDemoMode, !isRefreshing, isRuntimeCompatible, isConnected, backendAvailable, !isOfflineModeActive else {
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
            try await client.sendVoice(
                wavData: wavData,
                mood: askDJMoodInt,
                djStyle: "warm_radio_dj",
                musicDNAKey: askDJMusicDNAKey,
                language: currentRequestLocale
            )
        }
    }

    public func runVibeCastPolling() async {
        isVibeCastStreamingActive = true
        scheduleVibeCastAutoTrackInsightIfNeeded(reason: "VibeCast started")
        defer {
            isVibeCastStreamingActive = false
            lastVibeCastAutoInsightPlaybackID = nil
        }
        while !Task.isCancelled {
            let delay = await refreshVibeCastFeed()
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
        }
    }

    @discardableResult
    public func refreshVibeCastFeed() async -> Int {
        if isDemoMode {
            applyDemoVibeCastFeed()
            return 30
        }
        guard pairingStatus == .paired, canUsePlaybackFeatures, isAppInForeground else {
            clearVibeCastFeed(reason: pairingStatus == .paired ? "playback_inactive" : "unauthorized")
            return 30
        }
        do {
            let response = try await withHomeAssistantClient { client in
                try await client.vibeCast(DJConnectVibeCastRequest(
                    locale: currentRequestLocale,
                    language: language,
                    timezone: TimeZone.current.identifier
                ))
            }
            apply(vibeCastResponse: response)
            return response.effectivePollAfterSeconds
        } catch let error as DJConnectError {
            clearVibeCastFeed(reason: Self.vibeCastReason(for: error))
            log(.debug, "VibeCast refresh skipped: \(Self.describe(error))")
            return 30
        } catch {
            clearVibeCastFeed(reason: "provider_unavailable")
            log(.debug, "VibeCast refresh skipped: \(error.localizedDescription)")
            return 30
        }
    }

    private func apply(vibeCastResponse response: DJConnectVibeCastResponse) {
        vibeCastResponse = response
        vibeCastDisabledReason = response.enabled ? nil : response.reason
        guard response.enabled else {
            vibeCastItems = []
            lastVibeCastContextID = response.context?.trackID
            lastVibeCastRevision = response.revision
            lastVibeCastItemsSignature = nil
            return
        }
        let contextParts = [response.context?.title, response.context?.artist, response.context?.album]
            .compactMap { Self.nonBlank($0) }
        let contextID = Self.nonBlank(response.context?.trackID)
            ?? Self.nonBlank(contextParts.joined(separator: "|"))
        if let contextID, lastVibeCastContextID != nil, contextID != lastVibeCastContextID {
            vibeCastItems = []
        }
        let nextItems = response.items.filter { !$0.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let nextItemsSignature = Self.vibeCastItemsSignature(nextItems)
        if response.revision != lastVibeCastRevision
            || contextID != lastVibeCastContextID
            || nextItemsSignature != lastVibeCastItemsSignature {
            vibeCastItems = nextItems
        }
        lastVibeCastContextID = contextID
        lastVibeCastRevision = response.revision
        lastVibeCastItemsSignature = nextItemsSignature
    }

    private func clearVibeCastFeed(reason: String?) {
        vibeCastResponse = DJConnectVibeCastResponse(enabled: false, reason: reason, ttlSeconds: 30, pollAfterSeconds: 30, items: [])
        vibeCastItems = []
        vibeCastDisabledReason = reason
        lastVibeCastContextID = nil
        lastVibeCastRevision = nil
        lastVibeCastItemsSignature = nil
    }

    private static func vibeCastItemsSignature(_ items: [DJConnectVibeCastResponse.Item]) -> String {
        items.map { item in
            let textSignature = item.text
                .map { "\($0.type.rawValue)=\($0.value)" }
                .joined(separator: "\u{1E}")
            return [item.id, item.kind.rawValue, textSignature].joined(separator: "\u{1F}")
        }
        .joined(separator: "\u{1D}")
    }

    private func applyDemoVibeCastFeed() {
        let title = Self.nonBlank(playback?.trackName) ?? currentTrackInsight?.title ?? "Midnight City"
        let artist = Self.nonBlank(playback?.artistName) ?? currentTrackInsight?.artist ?? "M83"
        let context = DJConnectVibeCastResponse.Context(
            trackID: "demo-\(title)-\(artist)",
            title: title,
            artist: artist,
            album: currentTrackInsight?.album,
            musicBackend: "demo",
            musicBackendName: "Demo Mode",
            genreBadge: Self.demoVibeCastGenreBadge(from: currentTrackInsight)
        )
        apply(vibeCastResponse: DJConnectVibeCastResponse(
            enabled: true,
            revision: 1,
            ttlSeconds: 45,
            pollAfterSeconds: 30,
            context: context,
            items: [
                DJConnectVibeCastResponse.Item(
                    id: "demo-vibe-\(title)",
                    kind: .moodNote,
                    tone: "playful",
                    priority: 80,
                    displaySeconds: 8,
                    placementHint: "side",
                    text: [
                        .init(type: .emoji, value: "♪"),
                        .init(type: .text, value: "VibeCast follows "),
                        .init(type: .strong, value: title),
                        .init(type: .text, value: " with live side bubbles.")
                    ],
                    source: .init(kind: "demo", confidence: "high")
                ),
                DJConnectVibeCastResponse.Item(
                    id: "demo-tip-\(artist)",
                    kind: .listeningTip,
                    tone: "warm",
                    priority: 60,
                    displaySeconds: 8,
                    placementHint: "side",
                    text: [
                        .init(type: .emoji, value: "🎧"),
                        .init(type: .text, value: "Listen for the "),
                        .init(type: .magnify, value: "pulse"),
                        .init(type: .text, value: " behind \(artist).")
                    ],
                    source: .init(kind: "demo", confidence: "high")
                )
            ],
            cache: .init(hit: false)
        ))
    }

    private static func demoVibeCastGenreBadge(from insight: TrackInsight?) -> DJConnectVibeCastResponse.Context.GenreBadge? {
        guard let label = nonBlank(insight?.genre) ?? nonBlank(insight?.subgenre) else {
            return nil
        }
        let canonical = label
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return DJConnectVibeCastResponse.Context.GenreBadge(
            label: label,
            genre: canonical.isEmpty ? nil : canonical,
            placement: "top_trailing"
        )
    }

    private static func vibeCastReason(for error: DJConnectError) -> String {
        switch error {
        case .authStale:
            return "unauthorized"
        case .clientTypeMismatch:
            return "client_type_mismatch"
        case .routeMissing:
            return "feature_disabled"
        case .backendUnavailable, .notConfigured:
            return "provider_unavailable"
        default:
            return "provider_unavailable"
        }
    }

    private static func nonBlank(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func scheduleVibeCastAutoTrackInsightIfNeeded(reason: String) {
        guard isVibeCastStreamingActive, hasPlayingNow, canStartTrackInsightAnalysis else {
            if !hasPlayingNow {
                lastVibeCastAutoInsightPlaybackID = nil
            }
            return
        }
        guard !isLoadingTrackInsight else {
            return
        }
        let playbackID = Self.playbackAutoInsightIdentity(playback)
        guard !playbackID.isEmpty else {
            return
        }
        if currentTrackInsightMatchesPlayback() && currentTrackInsight != nil {
            lastVibeCastAutoInsightPlaybackID = playbackID
            return
        }
        guard lastVibeCastAutoInsightPlaybackID != playbackID else {
            return
        }
        lastVibeCastAutoInsightPlaybackID = playbackID
        log(.debug, "VibeCast auto-analyzing Track Insight: \(reason)")
        analyzeCurrentTrack(open: false, forceRefresh: false)
    }

    private static func playbackAutoInsightIdentity(_ playback: DJConnectPlayback?) -> String {
        [
            normalizedTrackIdentity(playback?.trackName),
            normalizedTrackIdentity(playback?.artistName),
            playback?.durationMS.map(String.init) ?? ""
        ].joined(separator: "|")
    }

    private var askDJMusicDNAKey: String {
        "djconnect_\(identity.clientType.rawValue)_\(identity.deviceID)"
    }

    private var demoAskDJResponse: String {
        localized(key: "appModel.ask.dj.gives.real.answers.as.soon.as.djconnect")
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
                musicDNAKey: askDJMusicDNAKey,
                audioResponse: askDJAudioResponseMode,
                language: currentRequestLocale
            ))
        }
    }

    private func clearAskDJHistoryWithFallback() async throws -> DJConnectAskDJHistoryResponse {
        try await withHomeAssistantClient { client in
            try await client.clearAskDJHistory(musicDNAKey: askDJMusicDNAKey)
        }
    }

    private func fetchAskDJHistory(sinceRevision: Int?) async throws -> DJConnectAskDJHistoryResponse {
        try await withHomeAssistantClient { client in
            try await client.askDJHistory(sinceRevision: sinceRevision)
        }
    }

    public func refreshMusicDNAProfile(showToast: Bool = false) async {
        if isDemoMode {
            applyDemoMusicDNAProfile()
            if showToast {
                showMusicDNAToast(localized(key: "appModel.music.dna.updated"), systemImage: "heart")
            }
            return
        }
        guard pairingStatus == .paired, !isDemoMode, isRuntimeCompatible else {
            clearMusicDNADisplay()
            if showToast {
                showMusicDNAToast(localized(key: "appModel.no.connection.to.home.assistant"), systemImage: "exclamationmark.triangle.fill")
            }
            return
        }
        isLoadingMusicDNA = true
        musicDNAErrorMessage = nil
        do {
            let response = try await withHomeAssistantClient { client in
                try await client.musicDNAProfile(mood: askDJMoodInt, musicDNAKey: askDJMusicDNAKey, language: language)
            }
            apply(musicDNAProfile: response)
            if showToast {
                showMusicDNAToast(localized(key: "appModel.music.dna.updated"), systemImage: "heart")
            }
        } catch let error as DJConnectError {
            handleMusicDNAError(error)
            if showToast {
                showMusicDNAToast(messageForMusicDNARefreshFailure(error), systemImage: "exclamationmark.triangle.fill")
            }
        } catch {
            musicDNAErrorMessage = error.localizedDescription
            log(.warning, "Music DNA profile refresh failed: \(error.localizedDescription)")
            if showToast {
                showMusicDNAToast(localized(key: "appModel.music.dna.update.failed"), systemImage: "exclamationmark.triangle.fill")
            }
        }
        isLoadingMusicDNA = false
    }

    private func showMusicDNAToast(_ text: String, systemImage: String) {
        musicDNAToast = DJConnectVisualNotice(text: text, systemImage: systemImage)
    }

    private func messageForMusicDNARefreshFailure(_ error: DJConnectError) -> String {
        if Self.isMusicBackendUnavailableError(error) {
            return localized(key: "appModel.music.backend.unavailable")
        }
        if let message = userFacingDJResponseText(Self.describe(error)) {
            return message
        }
        if Self.shouldShowConnectionNotice(for: error) {
            return localized(key: "appModel.no.connection.to.home.assistant")
        }
        return musicDNAErrorMessage?.isEmpty == false
            ? musicDNAErrorMessage!
            : localized(key: "appModel.music.dna.update.failed")
    }

    public func presentMusicDNAOptInPromptIfNeeded() {
        #if DEBUG
        guard !isMusicDNAPreviewMode else { return }
        #endif
        let promptSeenKey = isDemoMode ? demoMusicDNAOptInPromptSeenKey : musicDNAOptInPromptSeenKey
        guard (isDemoMode || pairingStatus == .paired),
              !defaults.bool(forKey: promptSeenKey),
              !isShowingMusicDNAOptInPrompt else {
            return
        }
        if musicDNAProfileResponse?.enabled == true {
            defaults.set(true, forKey: promptSeenKey)
            return
        }
        guard musicDNAProfileResponse?.enabled == false else {
            return
        }
        isShowingMusicDNAOptInPrompt = true
    }

    public func dismissMusicDNAOptInPrompt() {
        defaults.set(true, forKey: isDemoMode ? demoMusicDNAOptInPromptSeenKey : musicDNAOptInPromptSeenKey)
        isShowingMusicDNAOptInPrompt = false
    }

    public func showMusicDNAOptInPrompt() {
        isShowingMusicDNAOptInPrompt = true
    }

    public func acceptMusicDNAOptInPrompt() {
        dismissMusicDNAOptInPrompt()
        Task { await setMusicDNAEnabled(true) }
    }

    public func setMusicDNAEnabled(_ enabled: Bool) async {
        if isDemoMode {
            setDemoMusicDNAEnabled(enabled)
            return
        }
        guard pairingStatus == .paired, !isDemoMode, isRuntimeCompatible else {
            return
        }
        isUpdatingMusicDNA = true
        musicDNAErrorMessage = nil
        do {
            let response = try await withHomeAssistantClient { client in
                try await client.setMusicDNAEnabled(enabled, mood: askDJMoodInt, musicDNAKey: askDJMusicDNAKey, language: language)
            }
            apply(musicDNAProfile: response)
            pendingMusicDNAEnabled = enabled
            pendingMusicDNAEnabledAt = Date()
            try Task.checkCancellation()
            let refreshed = try await withHomeAssistantClient { client in
                try await client.musicDNAProfile(mood: askDJMoodInt, musicDNAKey: askDJMusicDNAKey, language: language)
            }
            apply(musicDNAProfile: refreshed)
        } catch let error as DJConnectError {
            handleMusicDNAError(error)
        } catch is CancellationError {
        } catch {
            musicDNAErrorMessage = error.localizedDescription
            log(.warning, "Music DNA settings update failed: \(error.localizedDescription)")
        }
        isUpdatingMusicDNA = false
    }

    public func clearMusicDNA() async {
        if isDemoMode {
            musicDNAErrorMessage = nil
            return
        }
        guard pairingStatus == .paired, !isDemoMode, isRuntimeCompatible else {
            return
        }
        isUpdatingMusicDNA = true
        musicDNAErrorMessage = nil
        do {
            _ = try await withHomeAssistantClient { client in
                try await client.clearMusicDNA(mood: askDJMoodInt, musicDNAKey: askDJMusicDNAKey, language: language)
            }
            try Task.checkCancellation()
            let refreshed = try await withHomeAssistantClient { client in
                try await client.musicDNAProfile(mood: askDJMoodInt, musicDNAKey: askDJMusicDNAKey, language: language)
            }
            apply(musicDNAProfile: refreshed)
        } catch let error as DJConnectError {
            handleMusicDNAError(error)
        } catch is CancellationError {
        } catch {
            musicDNAErrorMessage = error.localizedDescription
            log(.warning, "Music DNA clear failed: \(error.localizedDescription)")
        }
        isUpdatingMusicDNA = false
    }

    public func musicDNAExportFilename(now: Date = Date()) -> String {
        let timestamp = Self.musicDNAFilenameDateFormatter.string(from: now)
        return "djconnect-music-dna-\(identity.clientType.rawValue)-\(timestamp).json"
    }

    public func askDJHistoryExportFilename(now: Date = Date()) -> String {
        let timestamp = Self.musicDNAFilenameDateFormatter.string(from: now)
        return "djconnect-ask-dj-history-\(identity.clientType.rawValue)-\(timestamp).json"
    }

    public func exportAskDJHistoryData() async throws -> Data {
        guard pairingStatus == .paired, isConnected, !isDemoMode else {
            throw DJConnectMusicDNATransferError.homeAssistantUnavailable
        }
        do {
            return try await withHomeAssistantClient { client in
                try await client.exportAskDJHistoryData()
            }
        } catch let error as DJConnectError {
            handleAskDJHistoryExportError(error)
            throw error
        }
    }

    public func exportMusicDNAProfileData() async throws -> Data {
        guard pairingStatus == .paired, isConnected, !isDemoMode else {
            throw DJConnectMusicDNATransferError.homeAssistantUnavailable
        }
        do {
            return try await withHomeAssistantClient { client in
                try await client.exportMusicDNAData(musicDNAKey: askDJMusicDNAKey, language: language)
            }
        } catch let error as DJConnectError {
            handleMusicDNAError(error)
            throw error
        }
    }

    public func previewMusicDNAImport(data: Data) throws -> DJConnectMusicDNAImportPreview {
        let decoder = Self.musicDNATransferDecoder()
        if let envelope = try? decoder.decode(DJConnectMusicDNAExportResponse.self, from: data),
           envelope.format == "djconnect.music_dna.export" {
            return DJConnectMusicDNAImportPreview(
                profile: envelope.profile,
                exportedAt: envelope.exportedAt,
                exportedByClientType: envelope.exportedByClientType,
                appVersion: envelope.appVersion
            )
        }
        if let response = try? decoder.decode(DJConnectMusicDNAProfileResponse.self, from: data) {
            return DJConnectMusicDNAImportPreview(
                profile: response,
                exportedAt: response.updatedAt,
                exportedByClientType: nil,
                appVersion: nil
            )
        }
        throw DJConnectMusicDNATransferError.invalidDocument
    }

    public func uploadMusicDNAImport(_ preview: DJConnectMusicDNAImportPreview) async throws {
        guard pairingStatus == .paired, isConnected, !isDemoMode else {
            throw DJConnectMusicDNATransferError.homeAssistantUnavailable
        }
        isUpdatingMusicDNA = true
        musicDNAErrorMessage = nil
        defer { isUpdatingMusicDNA = false }
        let response = try await withHomeAssistantClient { client in
            try await client.importMusicDNA(preview.profile, mood: askDJMoodInt, musicDNAKey: askDJMusicDNAKey, language: language)
        }
        apply(musicDNAProfile: response)
    }

    public func loadMusicDiscovery(force: Bool = false, showToast: Bool = false) async {
        if isDemoMode {
            musicDiscoveryResponse = demoMusicDNAEnabled ? Self.demoMusicDiscoveryResponse() : Self.disabledMusicDiscoveryResponse()
            musicDiscoveryErrorMessage = nil
            isLoadingMusicDiscovery = false
            isRefreshingMusicDiscovery = false
            return
        }
        guard pairingStatus == .paired, isRuntimeCompatible else {
            musicDiscoveryResponse = nil
            musicDiscoveryErrorMessage = nil
            return
        }
        if !force, let response = musicDiscoveryResponse, !isMusicDiscoveryExpired(response) {
            return
        }
        isLoadingMusicDiscovery = true
        musicDiscoveryErrorMessage = nil
        do {
            let response = try await withHomeAssistantClient { client in
                try await client.musicDiscoveryFeed(musicDNAKey: askDJMusicDNAKey, language: language)
            }
            apply(musicDiscovery: response)
        } catch let error as DJConnectError {
            handleMusicDiscoveryError(error)
            if showToast {
                showMusicDNAToast(messageForMusicDiscoveryFailure(error), systemImage: "exclamationmark.triangle.fill")
            }
        } catch {
            musicDiscoveryErrorMessage = localized(key: "ui.discovery.could.not.be.loaded")
            log(.warning, "Music Discovery load failed: \(error.localizedDescription)")
        }
        isLoadingMusicDiscovery = false
    }

    @discardableResult
    public func refreshMusicDiscovery() async -> Bool {
        await refreshMusicDiscovery(coalesce: false)
    }

    @discardableResult
    public func refreshMusicDiscoveryFromPush() async -> Bool {
        await refreshMusicDiscovery(coalesce: true)
    }

    @discardableResult
    private func refreshMusicDiscovery(coalesce: Bool) async -> Bool {
        if isDemoMode {
            musicDiscoveryResponse = demoMusicDNAEnabled ? Self.demoMusicDiscoveryResponse(revision: (musicDiscoveryResponse?.revision ?? 12) + 1) : Self.disabledMusicDiscoveryResponse()
            musicDiscoveryErrorMessage = nil
            return true
        }
        guard pairingStatus == .paired, isRuntimeCompatible else {
            return false
        }
        if coalesce, shouldCoalesceMusicDiscoveryPushRefresh() {
            logPush("music_discovery_ready refresh coalesced")
            return true
        }
        isRefreshingMusicDiscovery = true
        musicDiscoveryErrorMessage = nil
        defer { isRefreshingMusicDiscovery = false }
        do {
            let refreshResponse = try await withHomeAssistantClient { client in
                try await client.refreshMusicDiscovery(musicDNAKey: askDJMusicDNAKey, language: language)
            }
            try Task.checkCancellation()
            apply(musicDiscovery: refreshResponse)
            return true
        } catch let error as DJConnectError {
            if shouldLoadMusicDiscoveryFeedAfterRefreshError(error) {
                do {
                    let response = try await withHomeAssistantClient { client in
                        try await client.musicDiscoveryFeed(musicDNAKey: askDJMusicDNAKey, language: language)
                    }
                    apply(musicDiscovery: response)
                    return true
                } catch let fallbackError as DJConnectError {
                    handleMusicDiscoveryError(fallbackError)
                } catch {
                    musicDiscoveryErrorMessage = localized(key: "ui.discovery.could.not.be.loaded")
                    log(.warning, "Music Discovery refresh fallback feed failed: \(error.localizedDescription)")
                }
                return false
            }
            handleMusicDiscoveryError(error)
        } catch is CancellationError {
        } catch {
            musicDiscoveryErrorMessage = localized(key: "ui.discovery.could.not.be.loaded")
            log(.warning, "Music Discovery refresh failed: \(error.localizedDescription)")
        }
        return false
    }

    private func shouldCoalesceMusicDiscoveryPushRefresh(now: Date = Date()) -> Bool {
        let key = musicDiscoveryPushCoalescingKey()
        if let lastRefresh = musicDiscoveryPushRefreshes[key], now.timeIntervalSince(lastRefresh) < 8 {
            return true
        }
        musicDiscoveryPushRefreshes[key] = now
        return false
    }

    private func musicDiscoveryPushCoalescingKey() -> String {
        [
            localHomeAssistantURL(),
            askDJMusicDNAKey,
            identity.clientType.rawValue
        ].joined(separator: "|")
    }

    private func shouldLoadMusicDiscoveryFeedAfterRefreshError(_ error: DJConnectError) -> Bool {
        switch error {
        case .routeMissing, .backendUnavailable:
            return true
        case let .server(statusCode, message):
            return statusCode == 429
                || statusCode == 503
                || Self.containsAny(message, ["rate_limited", "rate limited", "unavailable"])
        default:
            return false
        }
    }

    public func playMusicDiscoveryItem(_ item: DJConnectMusicDiscoveryItem, sectionID: String) async {
        guard item.isDisplayable else { return }
        if isDemoMode {
            playMusicDiscoveryStartHaptic()
            playingMusicDiscoveryItemID = item.id
            try? await Task.sleep(for: .milliseconds(120))
            playingMusicDiscoveryItemID = nil
            return
        }
        guard pairingStatus == .paired, isRuntimeCompatible else {
            return
        }
        playMusicDiscoveryStartHaptic()
        playingMusicDiscoveryItemID = item.id
        musicDiscoveryErrorMessage = nil
        do {
            let payload = DJConnectMusicDiscoveryPlayRequest(
                discoveryItemID: item.id,
                sectionID: sectionID,
                identity: identity,
                musicDNAKey: askDJMusicDNAKey
            )
            _ = try await withHomeAssistantClient { client in
                try await client.playMusicDiscoveryItem(payload)
            }
        } catch let error as DJConnectError {
            handleMusicDiscoveryError(error)
        } catch is CancellationError {
        } catch {
            musicDiscoveryErrorMessage = localized(key: "appModel.this.recommendation.cannot.be.played.yet")
            log(.warning, "Music Discovery play failed: \(error.localizedDescription)")
        }
        playingMusicDiscoveryItemID = nil
    }

    private func apply(musicDiscovery response: DJConnectMusicDiscoveryResponse) {
        musicDiscoveryResponse = response
        musicDiscoveryErrorMessage = nil
        let sectionCount = response.sections.count
        let itemCount = response.sections.reduce(0) { $0 + $1.items.count }
        let visibleSectionCount = response.visibleSections.count
        let visibleItemCount = response.visibleSections.reduce(0) { $0 + $1.visibleItems.count }
        log(.debug, "Music Discovery refreshed enabled=\(response.enabled) revision=\(response.revision ?? 0) sections=\(sectionCount) items=\(itemCount) visible_sections=\(visibleSectionCount) visible_items=\(visibleItemCount)")
    }

    private func isMusicDiscoveryExpired(_ response: DJConnectMusicDiscoveryResponse) -> Bool {
        guard let generatedAt = response.generatedAt, let ttlSeconds = response.ttlSeconds else {
            return true
        }
        return Date().timeIntervalSince(generatedAt) >= Double(ttlSeconds)
    }

    private func handleMusicDiscoveryError(_ error: DJConnectError) {
        musicDiscoveryErrorMessage = messageForMusicDiscoveryFailure(error)
        log(.warning, "Music Discovery request failed: \(Self.describe(error))")
        if Self.shouldShowConnectionNotice(for: error) {
            musicDiscoveryResponse = nil
        }
    }

    private func messageForMusicDiscoveryFailure(_ error: DJConnectError) -> String {
        switch error {
        case .routeMissing:
            return localized(key: "appModel.djconnect.route.missing.in.home.assistant.check.the.integration")
        case .backendUnavailable, .server, .network, .decodingFailed, .invalidResponse:
            return localized(key: "ui.discovery.could.not.be.loaded")
        case .missingToken:
            return localized(key: "appModel.missing.djconnect.bearer.token.reset.pairing.to.set.up")
        case .authStale, .notConfigured:
            return localized(key: "appModel.not.connected.to.home.assistant")
        case .versionMismatch:
            return localized(key: "appModel.update.the.djconnect.app.or.home.assistant.integration")
        case .clientTypeMismatch:
            return localized(key: "pairing.error.clientTypeMismatch")
        case .invalidConfiguration:
            return localized(key: "appModel.no.connection.to.home.assistant")
        case .pairingFailed:
            return localized(key: "appModel.not.connected.to.home.assistant")
        case .trackInsightUnavailable:
            return localized(key: "ui.discovery.could.not.be.loaded")
        }
    }

    private func scheduleMusicDNAProfileRefresh(reason: String) {
        #if DEBUG
        guard !isMusicDNAPreviewMode else { return }
        #endif
        guard pairingStatus == .paired,
              !isDemoMode,
              isRuntimeCompatible,
              !isLoadingMusicDNA,
              !isUpdatingMusicDNA else {
            return
        }
        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await self.refreshMusicDNAProfile()
            self.log(.debug, "Music DNA profile refresh scheduled after \(reason)")
        }
    }

    private func apply(musicDNAProfile response: DJConnectMusicDNAProfileResponse) {
        if let pendingEnabled = pendingMusicDNAEnabled {
            let age = pendingMusicDNAEnabledAt.map { Date().timeIntervalSince($0) } ?? 0
            if response.enabled == pendingEnabled || age > 60 {
                pendingMusicDNAEnabled = nil
                pendingMusicDNAEnabledAt = nil
            } else {
                musicDNAProfileResponse = DJConnectMusicDNAProfileResponse(
                    success: response.success,
                    musicDNAKey: response.musicDNAKey,
                    enabled: pendingEnabled,
                    generation: response.generation,
                    clearRequestedAt: response.clearRequestedAt,
                    updatedAt: response.updatedAt,
                    profile: musicDNAProfileResponse?.profile ?? response.profile,
                    sources: response.sources,
                    error: response.error,
                    message: response.message
                )
                if pendingEnabled, musicDiscoveryResponse?.isMusicDNADisabled == true {
                    musicDiscoveryResponse = nil
                }
                musicDNAErrorMessage = nil
                log(.debug, "Music DNA profile refresh kept pending enabled=\(pendingEnabled) over stale enabled=\(response.enabled)")
                return
            }
        }
        musicDNAProfileResponse = response
        if response.enabled, musicDiscoveryResponse?.isMusicDNADisabled == true {
            musicDiscoveryResponse = nil
        }
        musicDNAErrorMessage = nil
        log(.debug, "Music DNA profile refreshed enabled=\(response.enabled) generation=\(response.generation ?? 0)")
    }

    private func applyDemoMusicDNAProfile() {
        musicDNAProfileResponse = demoMusicDNAEnabled ? Self.demoMusicDNAProfileResponse(language: language) : Self.disabledMusicDNAProfileResponse()
        musicDiscoveryResponse = demoMusicDNAEnabled ? Self.demoMusicDiscoveryResponse() : Self.disabledMusicDiscoveryResponse()
        musicDNAErrorMessage = nil
        musicDiscoveryErrorMessage = nil
        isLoadingMusicDNA = false
        isUpdatingMusicDNA = false
        isLoadingMusicDiscovery = false
        isRefreshingMusicDiscovery = false
    }

    private func setDemoMusicDNAEnabled(_ enabled: Bool) {
        demoMusicDNAEnabled = enabled
        defaults.set(enabled, forKey: demoMusicDNAEnabledKey)
        defaults.set(true, forKey: demoMusicDNAOptInPromptSeenKey)
        applyDemoMusicDNAProfile()
    }

    public static func disabledMusicDNAProfileResponse() -> DJConnectMusicDNAProfileResponse {
        DJConnectMusicDNAProfileResponse(
            success: true,
            enabled: false,
            profile: DJConnectMusicDNAProfile()
        )
    }

    public static func disabledMusicDiscoveryResponse() -> DJConnectMusicDiscoveryResponse {
        DJConnectMusicDiscoveryResponse(
            success: true,
            enabled: false,
            reason: "music_dna_disabled",
            sections: []
        )
    }

    public static func demoMusicDiscoveryResponse(revision: Int = 12) -> DJConnectMusicDiscoveryResponse {
        DJConnectMusicDiscoveryResponse(
            success: true,
            enabled: true,
            revision: revision,
            generatedAt: Date(),
            ttlSeconds: 86_400,
            source: "music_dna",
            sections: [
                DJConnectMusicDiscoverySection(
                    id: "because_you_like",
                    title: "Omdat je dit vaak luistert",
                    items: [
                        DJConnectMusicDiscoveryItem(
                            id: "demo-disc-track-1",
                            kind: .track,
                            title: "Midnight Relay",
                            subtitle: "Luna Vale",
                            uri: "spotify:track:demo-discovery-1",
                            imageURL: "https://example.test/djconnect/demo-discovery-1.jpg",
                            reason: "Past bij je smaakankers: Neon downtempo, Luna Vale en late-night synth grooves.",
                            reasonSources: ["taste_anchors", "favorite_artists", "favorite_genres"],
                            confidence: .high
                        ),
                        DJConnectMusicDiscoveryItem(
                            id: "demo-disc-track-2",
                            kind: .track,
                            title: "Harbor Afterglow",
                            subtitle: "Nova Harbor",
                            uri: "spotify:track:demo-discovery-2",
                            imageURL: "https://example.test/djconnect/demo-discovery-2.jpg",
                            reason: "Sluit aan op je recente favorieten met warm baswerk en melodische avondenergie.",
                            reasonSources: ["recent_favorite_tracks", "mood_mix"],
                            confidence: .medium
                        ),
                        DJConnectMusicDiscoveryItem(
                            id: "demo-disc-album-1",
                            kind: .album,
                            title: "Signal Garden",
                            subtitle: "Echo Parade",
                            uri: "spotify:album:demo-discovery-1",
                            imageURL: "https://example.test/djconnect/demo-discovery-album-1.jpg",
                            reason: "Je playtime-profiel laat Echo Parade terugkomen bij energieke, glanzende tracks.",
                            reasonSources: ["playtime", "repeat_magnets"],
                            confidence: .medium
                        )
                    ]
                ),
                DJConnectMusicDiscoverySection(
                    id: "fresh_for_your_mood",
                    title: "Nieuw voor je mood",
                    items: [
                        DJConnectMusicDiscoveryItem(
                            id: "demo-disc-playlist-1",
                            kind: .playlist,
                            title: "Neon Drive",
                            subtitle: "Playlist",
                            uri: "spotify:playlist:demo-discovery-1",
                            imageURL: "https://example.test/djconnect/demo-discovery-playlist-1.jpg",
                            reason: "Gebouwd rond je groove-zone met genoeg energie om de set vooruit te duwen.",
                            reasonSources: ["mood_mix", "energy_profile"],
                            confidence: .high
                        ),
                        DJConnectMusicDiscoveryItem(
                            id: "demo-disc-artist-1",
                            kind: .artist,
                            title: "Mira Sol",
                            subtitle: "Artist",
                            uri: "spotify:artist:demo-discovery-1",
                            imageURL: "https://example.test/djconnect/demo-discovery-artist-1.jpg",
                            reason: "Ligt dicht bij je skyline pop en velvet electro signalen zonder dezelfde artiesten te herhalen.",
                            reasonSources: ["favorite_genres", "taste_anchors"],
                            confidence: .low
                        )
                    ]
                )
            ]
        )
    }

    public static func demoMusicDNAProfileResponse(language: String = DJConnectLocalization.defaultDisplayLanguageCode()) -> DJConnectMusicDNAProfileResponse {
        DJConnectMusicDNAProfileResponse(
            success: true,
            musicDNAKey: "demo:music-dna",
            enabled: true,
            generation: 3,
            profile: DJConnectMusicDNAProfile(
                summary: DJConnectLocalization.localized(key: "demo.music.dna.summary", language: language),
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
            ),
            sources: [
                DJConnectResponseLink(
                    url: URL(string: "https://djconnect.dev")!,
                    title: "Music DNA Demo",
                    subtitle: DJConnectLocalization.localized(key: "demo.music.dna.source.subtitle", language: language),
                    source: "djconnect_demo"
                )
            ]
        )
    }

    private func clearMusicDNADisplay() {
        musicDNAProfileResponse = nil
        musicDNAErrorMessage = nil
        isLoadingMusicDNA = false
        isUpdatingMusicDNA = false
    }

    #if DEBUG
    public func setMusicDNAPreviewResponse(_ response: DJConnectMusicDNAProfileResponse?) {
        isMusicDNAPreviewMode = true
        musicDNAProfileResponse = response
        musicDNAErrorMessage = nil
        isLoadingMusicDNA = false
        isUpdatingMusicDNA = false
    }

    public func setMusicDNAPreviewErrorMessage(_ message: String?) {
        isMusicDNAPreviewMode = true
        musicDNAErrorMessage = message
        isLoadingMusicDNA = false
        isUpdatingMusicDNA = false
    }
    #endif

    private func handleMusicDNAError(_ error: DJConnectError) {
        log(.warning, "Music DNA request failed: \(Self.describe(error))")
        switch error {
        case .authStale, .notConfigured, .missingToken:
            clearMusicDNADisplay()
            apply(error: error)
        case .versionMismatch:
            clearMusicDNADisplay()
            apply(error: error)
        default:
            musicDNAErrorMessage = userFacingDJResponseText(Self.describe(error)) ?? Self.describe(error)
        }
    }

    private func handleAskDJHistoryExportError(_ error: DJConnectError) {
        log(.warning, "Ask DJ history export failed: \(Self.describe(error))")
        switch error {
        case .authStale, .notConfigured, .missingToken, .versionMismatch:
            apply(error: error)
        default:
            break
        }
    }

    private func requestAskDJIdleSuggestion() async throws -> DJConnectAskDJMessageResponse {
        try await withHomeAssistantClient { client in
            try await client.askDJIdleSuggestion(DJConnectAskDJIdleSuggestionRequest(
                identity: identity,
                clientMessageID: UUID().uuidString,
                mood: askDJMoodInt,
                djStyle: "warm_radio_dj",
                musicDNAKey: askDJMusicDNAKey
            ))
        }
    }

    private func playAskDJRecommendationWithFallback(_ action: DJConnectAskDJPlaybackAction) async throws -> DJConnectCommandResponse {
        let command = action.command?.isEmpty == false ? action.command! : Self.defaultAskDJCommand(for: action)
        return try await withHomeAssistantClient { client in
            try await client.sendCommandResponse(DJConnectCommandPayload(
                identity: identity,
                command: command,
                value: Self.askDJCommandValue(for: action, command: command),
                play: command == "ask_dj_play_recommendation",
                musicBackendRevision: action.musicBackendRevision ?? musicBackendSummary.musicBackendRevision,
                language: currentRequestLocale,
                mood: askDJMoodInt,
                musicDNAKey: askDJMusicDNAKey
            ))
        }
    }

    @discardableResult
    private func sendSetCurrentTrackFavoriteCommand(_ shouldFavorite: Bool) async -> Bool {
        if isDemoMode {
            applyDemoCommand("set_current_track_favorite", value: .bool(shouldFavorite), play: nil)
            return true
        }
        guard pairingStatus == .paired, isRuntimeCompatible else {
            return false
        }
        do {
            let response = try await withHomeAssistantClient { client in
                try await client.sendCommandResponse(DJConnectCommandPayload(
                    identity: identity,
                    command: "set_current_track_favorite",
                    value: .bool(shouldFavorite),
                    language: currentRequestLocale,
                    mood: askDJMoodInt,
                    musicDNAKey: askDJMusicDNAKey
                ))
            }
            apply(commandResponse: response, command: "set_current_track_favorite")
            guard response.success else {
                log(.warning, "Favorite current track command was rejected by Home Assistant")
                return false
            }
            log(.info, "Current track favorite status updated")
            return true
        } catch let error as DJConnectError {
            log(.warning, "Favorite current track command failed: \(Self.describe(error))")
            apply(error: error)
            return false
        } catch {
            log(.error, "Favorite current track command failed unexpectedly: \(error.localizedDescription)")
            pairingMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    private func sendFavoriteActionCommand(_ action: DJConnectAskDJPlaybackAction) async -> Bool {
        if action.command?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "save_current_track" {
            return await sendSetCurrentTrackFavoriteCommand(true)
        }
        if isDemoMode {
            let value = action.commandValue ?? .bool(Self.boolValue(from: action.value) ?? true)
            applyDemoCommand("set_current_track_favorite", value: value, play: nil)
            return true
        }
        guard pairingStatus == .paired, isRuntimeCompatible else {
            return false
        }
        let command = action.command?.isEmpty == false ? action.command! : "set_current_track_favorite"
        let value = action.commandValue ?? .bool(Self.boolValue(from: action.value) ?? action.favoriteStatus.map { !$0 } ?? true)
        do {
            let response = try await withHomeAssistantClient { client in
                try await client.sendCommandResponse(DJConnectCommandPayload(
                    identity: identity,
                    command: command,
                    value: value,
                    language: currentRequestLocale,
                    mood: askDJMoodInt,
                    musicDNAKey: askDJMusicDNAKey
                ))
            }
            apply(commandResponse: response, command: command)
            guard response.success else {
                log(.warning, "Ask DJ favorite action was rejected by Home Assistant")
                return false
            }
            return true
        } catch let error as DJConnectError {
            log(.warning, "Ask DJ favorite action failed: \(Self.describe(error))")
            apply(error: error)
            return false
        } catch {
            log(.error, "Ask DJ favorite action failed unexpectedly: \(error.localizedDescription)")
            pairingMessage = error.localizedDescription
            return false
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

    @discardableResult
    private func appendAskDJMessage(
        role: DJConnectAskDJMessageRole,
        text: String,
        serverID: String? = nil,
        clientMessageID: String? = nil,
        exchangeID: String? = nil,
        exchangeOrder: Int? = nil,
        messageKind: DJConnectAskDJLocalMessageKind = .assistant,
        origin: String? = nil,
        textSource: String? = nil,
        isGeneratedText: Bool? = nil,
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
            exchangeID: exchangeID,
            exchangeOrder: exchangeOrder ?? (role == .user && clientMessageID != nil ? 0 : nil),
            role: role,
            messageKind: role == .user ? .assistant : messageKind,
            origin: role == .user ? nil : origin,
            textSource: role == .user ? nil : textSource,
            isGeneratedText: role == .user ? nil : isGeneratedText,
            text: trimmed,
            images: images,
            links: links,
            playbackActions: proxiedPlaybackActions(playbackActions),
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

    @discardableResult
    private func syncAskDJHistory(showErrors: Bool) async -> Bool {
        guard canUsePlaybackFeatures else {
            return false
        }
        do {
            let response = try await fetchAskDJHistory(sinceRevision: nil)
            applyAskDJHistory(response)
            log(.debug, "Ask DJ history synced to revision \(response.historyRevision)")
            return true
        } catch let error as DJConnectError {
            guard !Self.isCancellation(error) else {
                log(.debug, "Ask DJ history sync cancelled")
                return false
            }
            if showErrors {
                askDJErrorMessage = askDJErrorText(for: error)
                showAskDJToast(for: error)
            }
            log(.warning, "Ask DJ history sync failed: \(Self.describe(error))")
            return false
        } catch {
            guard !Self.isCancellation(error) else {
                log(.debug, "Ask DJ history sync cancelled")
                return false
            }
            if showErrors {
                askDJErrorMessage = askDJUnavailableText()
                showAskDJToast(localized(key: "appModel.ask.dj.is.unreachable"))
            }
            log(.error, "Ask DJ history sync failed unexpectedly: \(error.localizedDescription)")
            return false
        }
    }

    private func syncAskDJHistoryAfterDeferredAskDJResponse() async {
        for attempt in 0..<4 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
            await syncAskDJHistory(showErrors: false)
        }
    }

    private func isDeferredAskDJTimeout(_ error: Error) -> Bool {
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return true
        }
        guard let djConnectError = error as? DJConnectError,
              case let .network(message) = djConnectError else {
            return false
        }
        let normalized = message.lowercased()
        return normalized.contains("timed out")
            || normalized.contains("timeout")
            || normalized.contains("time-out")
            || normalized.contains("time out")
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

    func applyAskDJMessageResponse(_ response: DJConnectAskDJMessageResponse, fallbackUserMessageID: UUID?) {
        let shouldPlayResponseHaptic = fallbackUserMessageID != nil && responseContainsAssistantMessage(response)
        var nextMessages = askDJMessages
        if response.messages.isEmpty {
            if let userMessage = response.userMessage {
                upsertAskDJHistoryMessage(userMessage, into: &nextMessages, fallbackID: fallbackUserMessageID)
            } else if let fallbackUserMessageID {
                updateAskDJMessageStatus(id: fallbackUserMessageID, status: .delivered, in: &nextMessages)
            }
            if let assistantMessage = response.assistantMessage {
                upsertAskDJHistoryMessage(assistantMessage, into: &nextMessages, fallbackID: nil)
            }
        } else {
            var usedFallbackUserID = false
            for message in response.messages {
                let role: DJConnectAskDJMessageRole = message.role == .user ? .user : .dj
                let fallbackID = !usedFallbackUserID && role == .user ? fallbackUserMessageID : nil
                upsertAskDJHistoryMessage(message, into: &nextMessages, fallbackID: fallbackID)
                if fallbackID != nil {
                    usedFallbackUserID = true
                }
            }
            if !usedFallbackUserID, let fallbackUserMessageID {
                updateAskDJMessageStatus(id: fallbackUserMessageID, status: .delivered, in: &nextMessages)
            }
        }
        applyAskDJTrim(response.historyTrimmedBefore, to: &nextMessages)
        coalesceAskDJMessages(&nextMessages)
        askDJMessages = sortedAskDJMessages(nextMessages)
        persistAskDJRevisions(historyRevision: response.historyRevision, clearRevision: response.clearRevision)
        saveAskDJMessages()
        if fallbackUserMessageID != nil {
            requestAskDJScrollToBottom()
        }
        if shouldPlayResponseHaptic {
            playAskDJResponseHaptic()
        }
        applyTrackInsightIfNeeded(from: response, open: false)
    }

    private func responseContainsAssistantMessage(_ response: DJConnectAskDJMessageResponse) -> Bool {
        if response.assistantMessage != nil {
            return true
        }
        return response.messages.contains { $0.role != .user }
    }

    func applyAskDJHistory(_ response: DJConnectAskDJHistoryResponse, forceClear: Bool = false) {
        let localClearRevision = defaults.integer(forKey: askDJClearRevisionKey)
        if forceClear || response.clearRevision > localClearRevision {
            askDJMessages.removeAll()
        }
        var nextMessages = askDJMessages
        for message in response.messages {
            upsertAskDJHistoryMessage(message, into: &nextMessages, fallbackID: nil)
        }
        applyAskDJTrim(response.historyTrimmedBefore, to: &nextMessages)
        coalesceAskDJMessages(&nextMessages)
        askDJMessages = sortedAskDJMessages(nextMessages)
        persistAskDJRevisions(historyRevision: response.historyRevision, clearRevision: response.clearRevision)
        saveAskDJMessages()
        if let newestInsight = askDJMessages.last(where: { $0.trackInsight != nil })?.trackInsight {
            applyTrackInsight(newestInsight, open: false)
        }
    }

    private func applyTrackInsightIfNeeded(from response: DJConnectAskDJMessageResponse, open: Bool) {
        guard let insight = response.trackInsight ?? response.assistantMessage?.trackInsight else {
            return
        }
        applyTrackInsight(insight, open: open || response.shouldOpenTrackInsight)
    }

    private func applyTrackInsight(_ insight: TrackInsight, open: Bool) {
        currentTrackInsight = insight
        saveTrackInsightWidgetSnapshot(for: insight)
        syncTrackInsightLiveActivity(reason: "Track Insight changed")
        trackInsightHistory.removeAll { $0.id == insight.id }
        trackInsightHistory.insert(insight, at: 0)
        if trackInsightHistory.count > 25 {
            trackInsightHistory.removeLast(trackInsightHistory.count - 25)
        }
        trackInsightErrorMessage = nil
        if open {
            trackInsightNavigationRequestID = UUID()
        }
        scheduleMusicDNAProfileRefresh(reason: "Track Insight changed")
        if isDemoMode, isVibeCastStreamingActive {
            applyDemoVibeCastFeed()
        }
    }

    private func saveTrackInsightWidgetSnapshot(for insight: TrackInsight) {
        guard let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier) else {
            log(.warning, "Track Insight widget snapshot skipped: App Group storage is unavailable.")
            return
        }
        do {
            let snapshot = DJConnectTrackInsightWidgetSnapshot(insight: insight)
            try snapshot.save(to: defaults)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: DJConnectTrackInsightWidgetSnapshot.widgetKind)
            #endif
            Task { [snapshot] in
                await updateTrackInsightWidgetSnapshotArtwork(snapshot: snapshot)
            }
        } catch {
            log(.warning, "Track Insight widget snapshot failed: \(error.localizedDescription)")
        }
    }

    private func updateTrackInsightWidgetSnapshotArtwork(snapshot: DJConnectTrackInsightWidgetSnapshot) async {
        guard let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier),
              let artworkURL = snapshot.artworkURL,
              let artworkData = await widgetArtworkData(from: artworkURL) else {
            return
        }
        guard var currentSnapshot = DJConnectTrackInsightWidgetSnapshot.load(from: defaults),
              currentSnapshot.artworkURL == artworkURL,
              currentSnapshot.title == snapshot.title,
              currentSnapshot.artist == snapshot.artist else {
            return
        }
        currentSnapshot.artworkData = artworkData
        do {
            try currentSnapshot.save(to: defaults)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: DJConnectTrackInsightWidgetSnapshot.widgetKind)
            #endif
        } catch {
            log(.debug, "Track Insight widget artwork cache failed: \(error.localizedDescription)")
        }
    }

    private func clearTrackInsightWidgetSnapshot(reason: String) {
        guard let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier) else {
            return
        }
        DJConnectTrackInsightWidgetSnapshot.remove(from: defaults)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: DJConnectTrackInsightWidgetSnapshot.widgetKind)
        #endif
        log(.debug, "Cleared Track Insight widget snapshot: \(reason)")
    }

    private func updateNowPlayingWidgetSnapshot(playback: DJConnectPlayback?) {
        guard let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier) else {
            log(.warning, "Now Playing widget snapshot skipped: App Group storage is unavailable.")
            return
        }
        guard let playback, let snapshot = DJConnectNowPlayingWidgetSnapshot(playback: playback) else {
            DJConnectNowPlayingWidgetSnapshot.remove(from: defaults)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: DJConnectNowPlayingWidgetSnapshot.widgetKind)
            WidgetCenter.shared.reloadTimelines(ofKind: DJConnectAskDJWidgetSnapshot.widgetKind)
            #endif
            log(.debug, "Cleared Now Playing widget snapshot: empty playback")
            return
        }
        do {
            try snapshot.save(to: defaults)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: DJConnectNowPlayingWidgetSnapshot.widgetKind)
            WidgetCenter.shared.reloadTimelines(ofKind: DJConnectAskDJWidgetSnapshot.widgetKind)
            #endif
            Task { [snapshot] in
                await updateNowPlayingWidgetSnapshotArtwork(snapshot: snapshot)
            }
        } catch {
            log(.warning, "Now Playing widget snapshot failed: \(error.localizedDescription)")
        }
    }

    private func updateNowPlayingWidgetSnapshotArtwork(snapshot: DJConnectNowPlayingWidgetSnapshot) async {
        guard let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier),
              let artworkURL = snapshot.artworkURL,
              let artworkData = await widgetArtworkData(from: artworkURL) else {
            return
        }
        guard var currentSnapshot = DJConnectNowPlayingWidgetSnapshot.load(from: defaults),
              currentSnapshot.artworkURL == artworkURL,
              currentSnapshot.title == snapshot.title,
              currentSnapshot.artist == snapshot.artist else {
            return
        }
        currentSnapshot.artworkData = artworkData
        do {
            try currentSnapshot.save(to: defaults)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: DJConnectNowPlayingWidgetSnapshot.widgetKind)
            WidgetCenter.shared.reloadTimelines(ofKind: DJConnectAskDJWidgetSnapshot.widgetKind)
            #endif
            syncTrackInsightLiveActivity(reason: "Now Playing widget artwork cached")
        } catch {
            log(.debug, "Now Playing widget artwork cache failed: \(error.localizedDescription)")
        }
    }

    private func widgetArtworkData(from url: URL) async -> Data? {
        do {
            let (data, response) = try await urlSession.data(from: url)
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                return nil
            }
            guard data.count <= 750_000 else {
                log(.debug, "Widget artwork cache skipped: image too large")
                return nil
            }
            return data
        } catch {
            log(.debug, "Widget artwork cache failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func clearNowPlayingWidgetSnapshot(reason: String) {
        guard let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier) else {
            return
        }
        DJConnectNowPlayingWidgetSnapshot.remove(from: defaults)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: DJConnectNowPlayingWidgetSnapshot.widgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: DJConnectAskDJWidgetSnapshot.widgetKind)
        #endif
        log(.debug, "Cleared Now Playing widget snapshot: \(reason)")
    }

    private func updateQueueWidgetSnapshot(items: [DJConnectQueueItem]) {
        guard let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier) else {
            log(.warning, "Queue widget snapshot skipped: App Group storage is unavailable.")
            return
        }
        guard !items.isEmpty else {
            DJConnectQueueWidgetSnapshot.remove(from: defaults)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: DJConnectQueueWidgetSnapshot.widgetKind)
            #endif
            log(.debug, "Cleared Queue widget snapshot: empty queue")
            return
        }
        do {
            let snapshot = DJConnectQueueWidgetSnapshot(items: items)
            try snapshot.save(to: defaults)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: DJConnectQueueWidgetSnapshot.widgetKind)
            #endif
            Task { [snapshot] in
                await updateQueueWidgetSnapshotArtwork(snapshot: snapshot)
            }
        } catch {
            log(.warning, "Queue widget snapshot failed: \(error.localizedDescription)")
        }
    }

    private func updateQueueWidgetSnapshotArtwork(snapshot: DJConnectQueueWidgetSnapshot) async {
        let artworkPairs = await withTaskGroup(of: (String, URL, Data)?.self) { group in
            for item in snapshot.items {
                guard let artworkURL = item.artworkURL else { continue }
                let itemID = item.id
                group.addTask { [weak self] in
                    guard let self,
                          let artworkData = await self.widgetArtworkData(from: artworkURL) else {
                        return nil
                    }
                    return (itemID, artworkURL, artworkData)
                }
            }

            var pairs: [(String, URL, Data)] = []
            for await pair in group {
                if let pair {
                    pairs.append(pair)
                }
            }
            return pairs
        }

        guard !artworkPairs.isEmpty,
              let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier),
              var currentSnapshot = DJConnectQueueWidgetSnapshot.load(from: defaults),
              currentSnapshot.items.map(\.id) == snapshot.items.map(\.id) else {
            return
        }

        var didUpdateArtwork = false
        for (itemID, artworkURL, artworkData) in artworkPairs {
            guard let index = currentSnapshot.items.firstIndex(where: { $0.id == itemID && $0.artworkURL == artworkURL }) else {
                continue
            }
            currentSnapshot.items[index].artworkData = artworkData
            didUpdateArtwork = true
        }

        guard didUpdateArtwork else { return }
        do {
            try currentSnapshot.save(to: defaults)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: DJConnectQueueWidgetSnapshot.widgetKind)
            #endif
        } catch {
            log(.debug, "Queue widget artwork cache failed: \(error.localizedDescription)")
        }
    }

    private func clearQueueWidgetSnapshot(reason: String) {
        guard let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier) else {
            return
        }
        DJConnectQueueWidgetSnapshot.remove(from: defaults)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: DJConnectQueueWidgetSnapshot.widgetKind)
        #endif
        log(.debug, "Cleared Queue widget snapshot: \(reason)")
    }

    private func syncTrackInsightLiveActivity(reason: String) {
        #if os(iOS) && canImport(ActivityKit)
        guard #available(iOS 16.1, *) else {
            return
        }
        if currentTrackInsight != nil, (!hasActiveNowPlaying || !currentTrackInsightMatchesPlayback()) {
            currentTrackInsight = nil
        }
        let activityPlayback = hasPlayingNow ? playback : nil
        Task {
            await TrackInsightLiveActivityController.sync(playback: activityPlayback)
        }
        log(.debug, "Synced Now Playing Live Activity: \(reason), playback=\(activityPlayback == nil ? "none" : "present")")
        #endif
    }

    private func currentTrackInsightMatchesPlayback() -> Bool {
        guard let insight = currentTrackInsight else {
            return true
        }
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

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func trackInsightFailureLogDetails(for error: Error) -> String {
        let tokenPresent = (try? tokenStore.loadToken())?.isEmpty == false
        let fields: [String] = [
            "error=\(Self.trackInsightFailureCode(for: error))",
            "message=\(Self.trackInsightFailureMessage(for: error))",
            "transport=\(Self.trackInsightFailureTransport(for: error))",
            "http_status=\(Self.trackInsightFailureHTTPStatus(for: error) ?? "none")",
            "identity_present=true",
            "client_type=\(identity.clientType.rawValue)",
            "client_id_present=\(!identity.deviceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)",
            "device_id_present=\(!identity.deviceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)",
            "device_name_present=\(!identity.deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)",
            "token_present=\(tokenPresent)",
            "track_present=\(!(playback?.trackName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))",
            "artist_present=\(!(playback?.artistName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))",
            "artwork_present=\(playback?.albumImageURL != nil)",
            "duration_present=\(playback?.durationMS != nil)",
            "progress_present=\(playback?.progressMS != nil)"
        ]
        return fields.joined(separator: " ")
    }

    private func trackInsightErrorMessage(for error: Error) -> String {
        guard let djConnectError = error as? DJConnectError else {
            return localized(key: "appModel.track.insight.is.unavailable.for.this.track")
        }

        switch djConnectError {
        case let .trackInsightUnavailable(code, message):
            let normalizedCode = code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalizedCode == "invalid_client_type" || normalizedCode == "client_type_mismatch" {
                return trackInsightClientTypeMessage()
            }
            if normalizedCode == "no_track_playing" {
                return localized(key: "appModel.start.playback.before.opening.track.insight")
            }
            if normalizedCode == "rate_limited" {
                return localized(key: "appModel.track.insight.rate.limited.try.again.later")
            }
            if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if isClientTypeErrorText(message) {
                    return trackInsightClientTypeMessage()
                }
                return userFacingTrackInsightErrorText(message) ?? message
            }
            return localized(key: "appModel.track.insight.is.unavailable.for.this.track")
        case let .routeMissing(message):
            return userFacingTrackInsightErrorText(message)
                ?? localized(key: "appModel.track.insight.is.not.available.in.this.home.assistant")
        case let .notConfigured(message):
            return userFacingTrackInsightErrorText(message)
                ?? localized(key: "appModel.finish.the.djconnect.setup.in.home.assistant.before.using")
        case let .backendUnavailable(message):
            return userFacingTrackInsightErrorText(message)
                ?? localized(key: "appModel.the.music.backend.in.home.assistant.is.not.available")
        case .clientTypeMismatch:
            return trackInsightClientTypeMessage()
        case let .server(statusCode, message):
            if statusCode == 404 {
                return localized(key: "appModel.start.playback.before.opening.track.insight")
            }
            if statusCode == 429 {
                return localized(key: "appModel.track.insight.rate.limited.try.again.later")
            }
            if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if isClientTypeErrorText(message) {
                    return trackInsightClientTypeMessage()
                }
                return userFacingTrackInsightErrorText(message) ?? message
            }
            return localized(key: "appModel.home.assistant.could.not.create.track.insight.http.value", arguments: statusCode)
        case let .decodingFailed(_, _, message):
            if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return localized(key: "appModel.home.assistant.returned.an.unexpected.track.insight.response")
            }
            return localized(key: "appModel.home.assistant.returned.an.unreadable.track.insight.response")
        case let .network(message):
            return localized(key: "appModel.home.assistant.is.unreachable.for.track.insight.value", arguments: message)
        case .authStale, .missingToken:
            return localized(key: "appModel.pair.with.home.assistant.again.before.using.track.insight")
        case .invalidResponse:
            return localized(key: "appModel.home.assistant.returned.an.invalid.track.insight.response")
        case let .invalidConfiguration(message):
            return message
        case let .pairingFailed(message):
            return message ?? localized(key: "appModel.pair.with.home.assistant.before.using.track.insight")
        case let .versionMismatch(mismatch):
            return mismatch.message ?? localized(key: "appModel.update.the.djconnect.app.or.home.assistant.integration.before")
        }
    }

    private func userFacingTrackInsightErrorText(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if let message = Self.extractServerJSONMessage(from: text) {
            return userFacingTrackInsightErrorText(message) ?? message
        }
        if Self.looksLikeHTMLDocument(text.lowercased()) {
            log(.warning, "Suppressed HTML response in Track Insight error")
            return localized(key: "appModel.no.connection.to.home.assistant")
        }
        let normalized = text.lowercased()
        if Self.isSpotifyAuthorizationErrorText(normalized) {
            log(.warning, "Spotify authorization needs refresh for Track Insight: \(text)")
            return localized(key: "appModel.refresh.the.spotify.connection.in.home.assistant")
        }
        if normalized.contains("no_track_playing")
            || normalized.contains("no currently playing track")
            || normalized.contains("no current track")
            || normalized.contains("no track playing")
            || normalized.contains("nothing is playing") {
            return localized(key: "appModel.start.playback.before.opening.track.insight")
        }
        if normalized.contains("backend_unavailable")
            || normalized.contains("playback_backend_unavailable")
            || normalized.contains("music backend")
            || normalized == "backend unavailable"
            || normalized == "playback backend unavailable" {
            return localized(key: "appModel.the.music.backend.in.home.assistant.is.not.available")
        }
        if normalized.contains("not_configured")
            || normalized.contains("not configured")
            || normalized.contains("setup flow")
            || normalized.contains("config flow") {
            return localized(key: "appModel.finish.the.djconnect.setup.in.home.assistant.before.using")
        }
        return text
    }

    private func upsertAskDJHistoryMessage(
        _ historyMessage: DJConnectAskDJHistoryMessage,
        into messages: inout [DJConnectAskDJMessage],
        fallbackID: UUID?
    ) {
        let role: DJConnectAskDJMessageRole = historyMessage.role == .user ? .user : .dj
        let existingIndex = messages.firstIndex { localMessage in
            localMessage.serverID == historyMessage.id
                || (
                    localMessage.role == role
                        && historyMessage.clientMessageID != nil
                        && localMessage.clientMessageID == historyMessage.clientMessageID
                )
                || (
                    localMessage.role == role
                        && historyMessage.exchangeID != nil
                        && historyMessage.exchangeOrder != nil
                        && localMessage.exchangeID == historyMessage.exchangeID
                        && localMessage.exchangeOrder == historyMessage.exchangeOrder
                )
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
        let status: DJConnectAskDJMessageStatus? = role == .user ? .delivered : nil
        let messageKind: DJConnectAskDJLocalMessageKind = historyMessage.messageKind == .system ? .system : .assistant
        let serverText = historyMessage.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingText = existing?.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return DJConnectAskDJMessage(
            id: existing?.id ?? fallbackID ?? UUID(uuidString: historyMessage.id) ?? UUID(),
            serverID: historyMessage.id,
            clientMessageID: historyMessage.clientMessageID,
            exchangeID: historyMessage.exchangeID,
            exchangeOrder: historyMessage.exchangeOrder,
            role: role,
            messageKind: role == .user ? .assistant : messageKind,
            origin: role == .user ? nil : historyMessage.origin,
            textSource: role == .user ? nil : historyMessage.textSource,
            isGeneratedText: role == .user ? nil : historyMessage.isGeneratedText,
            mood: role == .user ? nil : historyMessage.mood,
            text: serverText.isEmpty ? (existingText ?? "") : historyMessage.text,
            images: proxiedResponseImages(historyMessage.images),
            links: safeResponseLinks(historyMessage.links),
            playbackActions: proxiedPlaybackActions(historyMessage.playbackActions + historyMessage.confirmationActions),
            audioURL: resolvedAudioURL(from: historyMessage.audioURL),
            status: status,
            createdAt: historyMessage.createdAt,
            intentInfo: historyMessage.intentInfo,
            trackInsight: historyMessage.trackInsight,
            items: proxiedAskDJHistoryItems(historyMessage.items)
        )
    }

    private func combinedResponseLinks(
        _ links: [DJConnectResponseLink]?,
        _ sources: [DJConnectResponseLink]?
    ) -> [DJConnectResponseLink] {
        safeResponseLinks((links ?? []) + (sources ?? []))
    }

    private func persistAskDJRevisions(historyRevision: Int, clearRevision: Int) {
        defaults.set(historyRevision, forKey: askDJHistoryRevisionKey)
        defaults.set(clearRevision, forKey: askDJClearRevisionKey)
    }

    private func applyAskDJTrim(_ trimmedBefore: Date?, to messages: inout [DJConnectAskDJMessage]) {
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

    private func updateAskDJMessageStatus(
        id: UUID,
        status: DJConnectAskDJMessageStatus,
        in messages: inout [DJConnectAskDJMessage]
    ) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else {
            return
        }
        messages[index].status = status
    }

    private static func isClientAskDJExchangeMessage(_ message: DJConnectAskDJMessage) -> Bool {
        message.clientMessageID?.isEmpty == false
    }

    private func coalesceAskDJMessages(_ messages: inout [DJConnectAskDJMessage]) {
        var coalesced: [DJConnectAskDJMessage] = []
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

    private static func askDJMessagesRepresentSameBubble(_ lhs: DJConnectAskDJMessage, _ rhs: DJConnectAskDJMessage) -> Bool {
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
        preferred: DJConnectAskDJMessage,
        fallback: DJConnectAskDJMessage
    ) -> DJConnectAskDJMessage {
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
        if merged.exchangeID == nil {
            merged.exchangeID = fallback.exchangeID
        }
        if merged.exchangeOrder == nil {
            merged.exchangeOrder = fallback.exchangeOrder
        }
        if merged.audioURL == nil {
            merged.audioURL = fallback.audioURL
        }
        if merged.status == nil {
            merged.status = fallback.status
        }
        if merged.intentInfo == nil {
            merged.intentInfo = fallback.intentInfo
        }
        if merged.trackInsight == nil {
            merged.trackInsight = fallback.trackInsight
        }
        if merged.items.isEmpty {
            merged.items = fallback.items
        }
        merged.createdAt = min(preferred.createdAt, fallback.createdAt)
        return merged
    }

    private func sortedAskDJMessages(_ messages: [DJConnectAskDJMessage]) -> [DJConnectAskDJMessage] {
        messages.sorted { lhs, rhs in
            if let lhsExchangeID = lhs.exchangeID,
               let rhsExchangeID = rhs.exchangeID,
               lhsExchangeID == rhsExchangeID {
                if lhs.exchangeOrder != rhs.exchangeOrder {
                    return (lhs.exchangeOrder ?? roleFallbackExchangeOrder(lhs)) < (rhs.exchangeOrder ?? roleFallbackExchangeOrder(rhs))
                }
                if lhs.role != rhs.role {
                    return lhs.role == .user
                }
            }
            if let lhsClientID = lhs.clientMessageID,
               let rhsClientID = rhs.clientMessageID,
               !lhsClientID.isEmpty,
               lhsClientID == rhsClientID,
               lhs.role != rhs.role {
                return lhs.role == .user
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            if lhs.clientMessageID != rhs.clientMessageID {
                return (lhs.clientMessageID ?? "") < (rhs.clientMessageID ?? "")
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func roleFallbackExchangeOrder(_ message: DJConnectAskDJMessage) -> Int {
        message.role == .user ? 0 : 1
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
            guard await requestAskDJNotificationAuthorizationIfNeeded(center: center, preview: preview) else {
                log(.debug, "Ask DJ notification skipped because notifications are not authorized")
                return
            }
            await scheduleAskDJLocalNotification(center: center, preview: preview)
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
    private func requestAskDJNotificationAuthorizationIfNeeded(center: UNUserNotificationCenter, preview: String) async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            guard !hasRequestedAskDJNotificationPermission else {
                return false
            }
            await MainActor.run {
                pendingAskDJNotificationPreview = preview
                requestAppPermissions()
            }
            return false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func scheduleAskDJLocalNotification(center: UNUserNotificationCenter, preview: String) async {
        let content = UNMutableNotificationContent()
        content.title = localized(key: "appModel.ask.dj.answered")
        content.body = preview.isEmpty ? localized(key: "appModel.your.dj.response.is.ready") : preview
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

    private func requestRemoteNotificationAuthorizationIfNeeded(center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()
        logPush("notification permission status=\(Self.notificationAuthorizationStatusName(settings.authorizationStatus))")
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                let updatedSettings = await center.notificationSettings()
                logPush("notification permission requested granted=\(granted) status=\(Self.notificationAuthorizationStatusName(updatedSettings.authorizationStatus))")
                return granted
            } catch {
                logPush("notification permission failed error=\(error.localizedDescription)", level: .warning)
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
        logPush("starting system remote notification registration")
        #if os(iOS) && canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #elseif os(macOS) && canImport(AppKit)
        NSApplication.shared.registerForRemoteNotifications()
        #else
        logPush("system remote notification registration unavailable on this platform")
        #endif
    }

    private func registerStoredPushTokenIfPossible() {
        guard !isDemoMode,
              pairingStatus == .paired,
              let token = currentAPNsPushToken ?? defaults.string(forKey: legacyPushTokenKey),
              !token.isEmpty else {
            return
        }
        currentAPNsPushToken = token
        defaults.removeObject(forKey: legacyPushTokenKey)
        let environment = Self.pushEnvironment
        let tokenHash = Self.pushTokenHash(token)
        let appBundleID = Bundle.main.bundleIdentifier ?? "dev.djconnect.\(identity.clientType.rawValue)"
        let locale = Locale.current.identifier
        let bootstrapProof = currentBootstrapProofForPushRegistration()
        let categories = DJConnectPushRegistrationRequest.defaultNotificationCategories
        let registrationSignature = pushRegistrationSignature(
            pushToken: token,
            pushEnvironment: environment,
            appBundleID: appBundleID,
            locale: locale,
            bootstrapProof: bootstrapProof
        )
        if defaults.string(forKey: registeredPushTokenHashKey) == tokenHash,
           defaults.string(forKey: registeredPushEnvironmentKey) == environment.rawValue,
           defaults.string(forKey: registeredPushSignatureKey) == registrationSignature,
           defaults.bool(forKey: pushRegisteredKey) {
            return
        }
        Task { @MainActor in
            do {
                let authPresent = (try? tokenStore.loadToken())?.isEmpty == false
                logPush(
                    "register payload endpoint=/api/djconnect/v1/push/register ha_host=\(Self.hostForLog(from: localHomeAssistantURL())) device_id=\(identity.deviceID) client_type=\(identity.clientType.rawValue) env=\(environment.rawValue) app_bundle_id=\(appBundleID) app_version=\(appVersion) locale=\(locale) categories=\(categories) push_token_present=\(!token.isEmpty) token=\(DJConnectLogRedactor.redactSecret(token)) bootstrap_proof_present=\(bootstrapProof?.isEmpty == false) bootstrap_proof=\(DJConnectLogRedactor.redactSecret(bootstrapProof)) auth_present=\(authPresent)"
                )
                let response = try await withHomeAssistantClient { client in
                    try await client.registerPushNotifications(DJConnectPushRegistrationRequest(
                        identity: identity,
                        pushToken: token,
                        pushEnvironment: environment,
                        appBundleID: appBundleID,
                        appVersion: appVersion,
                        locale: locale,
                        notificationCategories: categories,
                        bootstrapProof: bootstrapProof
                    ))
                }
                applyPushRegistrationStatus(from: response)
                let responseError = Self.redactedPushFailureReason(response.lastPushError ?? response.error ?? "<missing>")
                let responseEnvironment = response.pushEnvironment
                let canonicalEnvironment = responseEnvironment ?? environment
                let environmentMatches = environment.isCompatible(with: responseEnvironment)
                logPush("register response http_status=decoded success=\(response.success) push_supported=\(Self.optionalBoolForLog(response.pushSupported)) push_registered=\(Self.optionalBoolForLog(response.pushRegistered)) client_type=\(identity.clientType.rawValue) canonical_push_environment=\(canonicalEnvironment.rawValue) push_environment=\(responseEnvironment?.rawValue ?? "<missing>") last_push_error=\(responseError)")
                guard response.success, response.pushRegistered != false, environmentMatches else {
                    let reason = response.error ?? response.lastPushError ?? response.message ?? "unknown"
                    defaults.set(false, forKey: pushRegisteredKey)
                    defaults.removeObject(forKey: registeredPushSignatureKey)
                    if Self.isInvalidBootstrapProof(reason) {
                        defaults.set(Self.redactedPushFailureReason(reason), forKey: lastPushErrorKey)
                        logPush("registration recovery_required=true reason=invalid_bootstrap_proof message=pair_with_home_assistant_again push_registered=false", level: .warning)
                    } else if !environmentMatches {
                        let responseValue = responseEnvironment?.rawValue ?? "<missing>"
                        defaults.set("push_environment_mismatch", forKey: lastPushErrorKey)
                        logPush("registration rejected push_environment_mismatch expected=\(environment.rawValue) response=\(responseValue) push_registered=false", level: .warning)
                    } else {
                        log(.warning, "Push registration was not accepted by Home Assistant: \(Self.redactedPushFailureReason(reason))")
                    }
                    return
                }
                defaults.removeObject(forKey: registeredPushTokenKey)
                defaults.set(tokenHash, forKey: registeredPushTokenHashKey)
                defaults.set(environment.rawValue, forKey: registeredPushEnvironmentKey)
                defaults.set(registrationSignature, forKey: registeredPushSignatureKey)
                defaults.set(true, forKey: pushRegisteredKey)
                defaults.removeObject(forKey: lastPushErrorKey)
                logPush("registered with Home Assistant client_type=\(identity.clientType.rawValue) env=\(canonicalEnvironment.rawValue) push_registered=true", level: .info)
            } catch let error as DJConnectError {
                if case .routeMissing = error {
                    logPush("registration skipped route_missing=true")
                } else if Self.isInvalidBootstrapProof(Self.describe(error)) {
                    defaults.set(false, forKey: pushRegisteredKey)
                    defaults.removeObject(forKey: registeredPushSignatureKey)
                    defaults.set("invalid_bootstrap_proof", forKey: lastPushErrorKey)
                    logPush("registration recovery_required=true reason=invalid_bootstrap_proof message=pair_with_home_assistant_again push_registered=false", level: .warning)
                } else {
                    logPush("registration failed error=\(Self.describe(error))", level: .warning)
                }
            } catch {
                logPush("registration failed error=\(error.localizedDescription)", level: .warning)
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
            appVersion,
            locale,
            bootstrapProof ?? "",
            localHomeAssistantURL()
        ].joined(separator: "|")
    }

    private static func pushTokenHash(_ token: String) -> String {
        SHA256.hash(data: Data(token.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func applyPushRegistrationStatus(from response: DJConnectCommandResponse) {
        if let pushSupported = response.pushSupported {
            defaults.set(pushSupported, forKey: pushSupportedKey)
        }
        if let pushRegistered = response.pushRegistered {
            defaults.set(pushRegistered, forKey: pushRegisteredKey)
            if !pushRegistered {
                defaults.removeObject(forKey: registeredPushSignatureKey)
            }
        }
        if let pushEnvironment = response.pushEnvironment {
            defaults.set(pushEnvironment.rawValue, forKey: pushEnvironmentStatusKey)
        }
        if let lastPushError = response.lastPushError, !lastPushError.isEmpty {
            defaults.set(Self.redactedPushFailureReason(lastPushError), forKey: lastPushErrorKey)
        } else if response.pushRegistered == true {
            defaults.removeObject(forKey: lastPushErrorKey)
        }
        logPush("status push_supported=\(Self.optionalBoolForLog(response.pushSupported)) push_registered=\(Self.optionalBoolForLog(response.pushRegistered)) push_environment=\(response.pushEnvironment?.rawValue ?? "<missing>") last_push_error=\(Self.redactedPushFailureReason(response.lastPushError ?? "<missing>"))")
    }

    static var pushEnvironment: DJConnectPushEnvironment {
        pushEnvironment(apsEnvironment: apsEnvironmentEntitlement)
    }

    nonisolated static func pushEnvironment(apsEnvironment: String?) -> DJConnectPushEnvironment {
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
        guard let task = SecTaskCreateFromSelf(nil) else {
            return nil
        }
        return SecTaskCopyValueForEntitlement(task, "com.apple.developer.aps-environment" as CFString, nil) as? String
            ?? SecTaskCopyValueForEntitlement(task, "aps-environment" as CFString, nil) as? String
        #else
        return nil
        #endif
    }

    private func currentBootstrapProofForPushRegistration() -> String? {
        nil
    }

    private func logPush(_ message: String, level: DJConnectAppLogLevel = .debug) {
        log(level, "[DJConnectPush] \(message)")
    }

    private static func redactedPushToken(_ token: String) -> String {
        DJConnectLogRedactor.redactSecret(token)
    }

    private static func hostForLog(from urlString: String) -> String {
        guard let url = normalizedHomeAssistantURL(from: urlString), let host = url.host, !host.isEmpty else {
            return "<missing>"
        }
        return host
    }

    private static func optionalBoolForLog(_ value: Bool?) -> String {
        value.map(String.init) ?? "<missing>"
    }

    #if canImport(UserNotifications)
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
    #endif

    private static func redactedPushFailureReason(_ reason: String) -> String {
        reason
            .replacingOccurrences(
                of: #"Bearer\s+[A-Za-z0-9._~+/=-]+"#,
                with: "Bearer [redacted]",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(djci_[A-Za-z0-9._~+/=-]+|[A-Fa-f0-9]{32,}|[A-Za-z0-9_-]{80,})"#,
                with: "[redacted]",
                options: .regularExpression
            )
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

    private func proxiedAskDJHistoryItems(_ items: [DJConnectAskDJHistoryItem]) -> [DJConnectAskDJHistoryItem] {
        guard !items.isEmpty else {
            return []
        }
        let baseURLs = homeAssistantBaseURLs()
        let allowedHosts = Set(baseURLs.compactMap { $0.host?.lowercased() })
        guard let primaryBaseURL = baseURLs.first, !allowedHosts.isEmpty else {
            return items
        }
        return items.map { item in
            var updatedItem = item
            if let imageURL = item.imageURL {
                updatedItem.imageURL = resolvedResponseImageURL(imageURL, baseURL: primaryBaseURL, allowedHosts: allowedHosts)
            }
            if let thumbnailURL = item.thumbnailURL {
                updatedItem.thumbnailURL = resolvedResponseImageURL(thumbnailURL, baseURL: primaryBaseURL, allowedHosts: allowedHosts)
            }
            return updatedItem
        }
    }

    private func proxiedPlaybackActions(_ actions: [DJConnectAskDJPlaybackAction]) -> [DJConnectAskDJPlaybackAction] {
        guard !actions.isEmpty else {
            return []
        }
        let baseURLs = homeAssistantBaseURLs()
        let allowedHosts = Set(baseURLs.compactMap { $0.host?.lowercased() })
        guard let primaryBaseURL = baseURLs.first, !allowedHosts.isEmpty else {
            return actions
        }
        return actions.map { action in
            guard let imageURL = action.imageURL,
                  let resolvedURL = resolvedResponseImageURL(imageURL, baseURL: primaryBaseURL, allowedHosts: allowedHosts) else {
                return action
            }
            var updatedAction = action
            updatedAction.imageURL = resolvedURL
            return updatedAction
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
        case let .backendUnavailable(message):
            showAskDJToast(userFacingDJResponseText(message) ?? localized(key: "appModel.home.assistant.did.not.respond"))
        case let .server(_, message):
            showAskDJToast(userFacingDJResponseText(message) ?? localized(key: "appModel.home.assistant.did.not.respond"))
        case let .decodingFailed(_, _, message):
            showAskDJToast(userFacingDJResponseText(message) ?? localized(key: "appModel.home.assistant.did.not.respond"))
        case .invalidResponse:
            showAskDJToast(localized(key: "appModel.home.assistant.did.not.respond"))
        case .network, .routeMissing, .notConfigured, .invalidConfiguration, .missingToken, .pairingFailed, .clientTypeMismatch:
            showAskDJToast(localized(key: "appModel.ask.dj.is.unreachable"))
        case .authStale, .versionMismatch, .trackInsightUnavailable:
            showAskDJToast(localized(key: "appModel.ask.dj.is.unreachable"))
        }
    }

    private func showAskDJToast(_ text: String) {
        askDJToast = DJConnectUserNotice(text: text)
    }

    private func askDJErrorText(for error: DJConnectError) -> String {
        switch error {
        case let .backendUnavailable(message):
            userFacingDJResponseText(message) ?? localized(key: "appModel.home.assistant.did.not.respond")
        case let .server(_, message):
            userFacingDJResponseText(message) ?? localized(key: "appModel.home.assistant.did.not.respond")
        case let .decodingFailed(_, _, message):
            userFacingDJResponseText(message) ?? localized(key: "appModel.home.assistant.did.not.respond")
        case .invalidResponse:
            localized(key: "appModel.home.assistant.did.not.respond")
        case .network,
             .routeMissing,
             .notConfigured,
             .invalidConfiguration,
             .missingToken,
             .pairingFailed,
             .clientTypeMismatch,
             .authStale,
             .versionMismatch,
             .trackInsightUnavailable:
            askDJUnavailableText()
        }
    }

    private func askDJUnavailableText() -> String {
        localized(key: "appModel.ask.dj.is.unreachable")
    }

    private func clearAskDJHistoryLocally() {
        askDJMessages = []
        defaults.removeObject(forKey: askDJMessagesKey)
        defaults.removeObject(forKey: askDJHistoryRevisionKey)
        defaults.removeObject(forKey: askDJClearRevisionKey)
        clearAskDJWidgetSnapshot(reason: "Ask DJ history cleared")
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
            if askDJMessages.isEmpty {
                clearAskDJWidgetSnapshot(reason: "Ask DJ history empty")
            } else {
                saveAskDJWidgetSnapshot()
            }
        } catch {
            log(.warning, "Ask DJ chat cache could not be saved: \(error.localizedDescription)")
        }
    }

    private func saveAskDJWidgetSnapshot() {
        let latestPrompt = askDJMessages.last(where: { $0.role == .user })?.text
        let latestResponse = askDJMessages.last(where: { $0.role == .dj && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.text
        guard latestPrompt != nil || latestResponse != nil else {
            return
        }
        let trackTitle = currentTrackInsight?.title ?? playback?.trackName
        let artist = currentTrackInsight?.artist ?? playback?.artistName
        let context: String
        if let trackTitle, !trackTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context = artist?.isEmpty == false ? "\(trackTitle) - \(artist ?? "")" : trackTitle
        } else {
            context = localized(key: "appModel.private.music.dna.context")
        }
        guard let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier) else {
            log(.warning, "Ask DJ widget snapshot skipped: App Group storage is unavailable.")
            return
        }
        do {
            try DJConnectAskDJWidgetSnapshot(
                prompt: latestPrompt ?? localized(key: "appModel.ask.dj"),
                response: latestResponse ?? localized(key: "appModel.ask.dj.is.ready"),
                context: context,
                trackTitle: trackTitle,
                artist: artist
            ).save(to: defaults)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: DJConnectAskDJWidgetSnapshot.widgetKind)
            #endif
        } catch {
            log(.warning, "Ask DJ widget snapshot failed: \(error.localizedDescription)")
        }
    }

    private func clearAskDJWidgetSnapshot(reason: String) {
        guard let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier) else {
            return
        }
        DJConnectAskDJWidgetSnapshot.remove(from: defaults)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: DJConnectAskDJWidgetSnapshot.widgetKind)
        #endif
        log(.debug, "Cleared Ask DJ widget snapshot: \(reason)")
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
            return localized(key: "appModel.no.connection.to.home.assistant")
        }
        if normalized.contains("did not return recognized text")
            || normalized.contains("recognitionstatus") {
            log(.info, "HA Assist STT did not recognize the input")
            return localized(key: "appModel.input.not.recognized")
        }
        if normalized.contains("not recognized") || normalized.contains("not_recognized") {
            log(.info, "STT response was not recognized")
            return localized(key: "appModel.not.recognized")
        }
        if Self.isSpotifyAuthorizationErrorText(normalized) {
            log(.warning, "Spotify authorization needs refresh: \(text)")
            return localized(key: "appModel.refresh.the.spotify.connection.in.home.assistant")
        }
        if normalized.contains("player command failed")
            && normalized.contains("no active device found") {
            log(.warning, "Playback command failed because Spotify has no active device")
            return localized(key: "appModel.no.active.playback.device.found")
        }
        if normalized.contains("player command failed")
            && normalized.contains("restriction violated") {
            log(.warning, "Playback command failed because the active player rejected the command")
            return localized(key: "appModel.active.player.rejected.this.command")
        }
        return text
    }

    private static func isSpotifyAuthorizationErrorText(_ normalizedText: String) -> Bool {
        normalizedText.contains("spotify authorization")
            || normalizedText.contains("reauthorize djconnect")
            || normalizedText.contains("start_spotify_oauth")
            || normalizedText.contains("spotify oauth")
            || (normalizedText.contains("expired or was revoked") && normalizedText.contains("spotify"))
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
        if normalized.contains("missing_pair_data") {
            return localized(key: "appModel.enter.the.home.assistant.url.and.pair.code")
        }
        if normalized.contains("invalid_client_type")
            || normalized.contains("invalid client type")
            || normalized.contains("client type")
            || normalized.contains("client_type")
            || normalized.contains("wrong app")
            || normalized.contains("wrong device type")
            || normalized.contains("selected ios")
            || normalized.contains("selected macos")
            || normalized.contains("selected watchos") {
            return wrongPairingClientTypeMessage()
        }
        if normalized.contains("invalid_pair_code") {
            return localized(key: "appModel.pair.code.is.incorrect.check.the.code.in.home")
        }
        if normalized.contains("not_configured")
            || normalized.contains("not configured")
            || normalized.contains("config flow")
            || normalized.contains("setup flow") {
            return pairingCodeRejectedMessage()
        }
        if normalized.contains("pairing code")
            || normalized.contains("app code")
            || normalized.contains("does not match")
            || normalized.contains("invalid code") {
            return localized(key: "appModel.not.paired.yet.open.djconnect.in.home.assistant.and")
        }
        if normalized.contains("token")
            || normalized.contains("bearer")
            || normalized.contains("unauthorized")
            || normalized.contains("forbidden") {
            return localized(key: "appModel.home.assistant.rejected.this.app.pair.djconnect.again.from")
        }
        return localized(key: "appModel.pairing.could.not.be.completed.check.home.assistant.and")
    }

    private func userFacingPairingNetworkMessage(from message: String) -> String {
        let normalized = message.lowercased()
        if normalized.contains("app transport security")
            || normalized.contains("secure connection")
            || normalized.contains("requires the use of a secure connection")
            || normalized.contains("ats") {
            return localized(key: "appModel.home.assistant.refused.the.connection.because.this.address.is")
        }
        if normalized.contains("could not find the server")
            || normalized.contains("server with the specified hostname")
            || normalized.contains("cannot find host")
            || normalized.contains("dns")
            || normalized.contains("name or service not known") {
            return localized(key: "appModel.home.assistant.was.not.found.at.this.address.check")
        }
        if normalized.contains("timed out") || normalized.contains("timeout") {
            return localized(key: "appModel.home.assistant.did.not.respond.in.time.check.that")
        }
        if normalized.contains("not connected to the internet")
            || normalized.contains("network connection was lost")
            || normalized.contains("offline") {
            return localized(key: "appModel.no.network.connection.to.home.assistant.check.wi.fi")
        }
        return localized(key: "appModel.home.assistant.is.unreachable.on.this.local.network.check")
    }

    private func userFacingPairingHTTPMessage(from error: DJConnectError) -> String? {
        let statusCode: Int
        switch error {
        case let .server(code, _), let .authStale(code, _):
            statusCode = code
        default:
            return nil
        }

        switch statusCode {
        case 400:
            if case let .server(_, message) = error, let userMessage = userFacingPairingMessage(from: message) {
                return userMessage
            }
            return localized(key: "appModel.enter.the.home.assistant.url.and.pair.code")
        case 401, 403:
            return localized(key: "appModel.pair.code.is.incorrect.check.the.code.in.home")
        case 404:
            return localized(key: "appModel.djconnect.was.not.found.in.home.assistant.open.the")
        case 409:
            return localized(key: "appModel.home.assistant.says.this.pairing.request.is.no.longer")
        case 426:
            return localized(key: "appModel.djconnect.and.home.assistant.are.not.on.the.same")
        case 429:
            return localized(key: "appModel.home.assistant.received.too.many.pairing.attempts.wait.a")
        case 500...599:
            if statusCode == 503,
               case let .server(_, message) = error,
               message?.lowercased().contains("not_configured") == true {
                return pairingCodeRejectedMessage()
            }
            return localized(key: "appModel.home.assistant.had.an.internal.error.while.pairing.check")
        default:
            return localized(key: "appModel.home.assistant.could.not.complete.pairing.check.the.url")
        }
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
        return normalized.contains("spotify authorization has expired")
            || normalized.contains("spotify-autorisatie is verlopen")
            || normalized == "check the music service authorization in home assistant"
            || normalized == "controleer de muziekdienst-autorisatie in home assistant"
            || normalized == "refresh the spotify connection in home assistant"
            || normalized == "ververs spotify koppeling in home assistant"
            || normalized == "refresh the music service connection in home assistant"
            || normalized == "ververs de muziekdienst-koppeling in home assistant"
            || normalized == "playback backend unavailable"
            || normalized == "playback backend niet beschikbaar"
    }

    private static func isMusicBackendUnavailableError(_ error: DJConnectError) -> Bool {
        switch error {
        case .backendUnavailable:
            return true
        case let .server(_, message), let .decodingFailed(_, _, message):
            return isMusicBackendUnavailableText(message)
        default:
            return isMusicBackendUnavailableText(describe(error))
        }
    }

    private static func isMusicBackendUnavailableText(_ text: String?) -> Bool {
        guard let text else {
            return false
        }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.contains("backend_unavailable")
            || normalized.contains("playback_backend_unavailable")
            || normalized.contains("music backend")
            || normalized.contains("muziekbackend")
            || normalized == "backend unavailable"
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

    private static func pushEventType(in userInfo: [AnyHashable: Any]) -> String? {
        if let eventType = userInfo["event_type"] as? String {
            return eventType
        }
        if let eventType = userInfo["eventType"] as? String {
            return eventType
        }
        if let data = userInfo["data"] as? [String: Any] {
            return data["event_type"] as? String ?? data["eventType"] as? String
        }
        return nil
    }

    private static func containsAny(_ message: String?, _ needles: [String]) -> Bool {
        guard let message = message?.lowercased() else {
            return false
        }
        return needles.contains { message.contains($0.lowercased()) }
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
            logPush("init platform=\(identity.platform.rawValue) client_type=\(identity.clientType.rawValue) bundle_id=\(Bundle.main.bundleIdentifier ?? "<missing>") app_version=\(appVersion) app_build=\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "<missing>") env=\(Self.pushEnvironment.rawValue)")
            let authorized = await requestRemoteNotificationAuthorizationIfNeeded(center: center)
            refreshPermissionStatuses()
            guard authorized else {
                logPush("remote notification registration not started permission_granted=false", level: .warning)
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
            logPush("received empty APNs token", level: .warning)
            return
        }
        currentAPNsPushToken = token
        defaults.removeObject(forKey: legacyPushTokenKey)
        logPush("received APNs token bytes=\(deviceToken.count) hex_length=\(token.count) token=\(Self.redactedPushToken(token))", level: .info)
        registerStoredPushTokenIfPossible()
    }

    public func handleRemoteNotificationRegistrationError(_ error: Error) {
        logPush("system remote notification registration failed error=\(error.localizedDescription)", level: .warning)
    }

    @discardableResult
    public func handleRemoteNotificationPayload(_ userInfo: [AnyHashable: Any], openedFromTap: Bool = false) async -> Bool {
        guard Self.pushEventType(in: userInfo) == "music_discovery_ready" else {
            await refreshAskDJHistory()
            return false
        }
        logPush("received music_discovery_ready opened_from_tap=\(openedFromTap)")
        if openedFromTap {
            performHomeScreenAction(.discovery)
        }
        _ = await refreshMusicDiscoveryFromPush()
        return true
    }

    public func unregisterPushNotifications() {
        guard let token = currentAPNsPushToken ?? defaults.string(forKey: legacyPushTokenKey), !token.isEmpty else {
            return
        }
        guard let bearerToken = try? tokenStore.loadToken(), !bearerToken.isEmpty else {
            return
        }
        currentAPNsPushToken = nil
        defaults.removeObject(forKey: legacyPushTokenKey)
        defaults.removeObject(forKey: registeredPushTokenKey)
        defaults.removeObject(forKey: registeredPushTokenHashKey)
        defaults.removeObject(forKey: registeredPushEnvironmentKey)
        defaults.removeObject(forKey: registeredPushSignatureKey)
        defaults.removeObject(forKey: pushRegisteredKey)
        defaults.removeObject(forKey: pushEnvironmentStatusKey)
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
                        log(.info, "Unregistered APNs token")
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
            try await configureDJConnectAudioSession(category: .playback, mode: .spokenAudio, options: [.duckOthers])
            try await setDJConnectAudioSessionActive(true)
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
            showAskDJToast(localized(key: "appModel.audio.could.not.be.played.again"))
        }
        #else
        log(.warning, "DJ response audio is not available on this platform")
        showAskDJToast(localized(key: "appModel.audio.could.not.be.played.again"))
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
                        limit: Self.commandLimit(for: command),
                        language: currentRequestLocale,
                        mood: askDJMoodInt,
                        musicDNAKey: askDJMusicDNAKey
                    )
                )
                apply(commandResponse: response, command: command)
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
                userNotice = DJConnectUserNotice(text: playbackCommandFailureMessage(command: command, error: error))
            }
            return false
        } catch {
            log(.error, "Command \(command) failed unexpectedly: \(error.localizedDescription)")
            pairingMessage = error.localizedDescription
            if notifyUserOnError {
                userNotice = DJConnectUserNotice(text: playbackCommandFailureFallback(command: command))
            }
            return false
        }
    }

    private func playbackCommandFailureMessage(command: String, error: DJConnectError) -> String {
        switch error {
        case let .backendUnavailable(message),
             let .server(_, message),
             let .decodingFailed(_, _, message):
            if let message = userFacingDJResponseText(message ?? Self.describe(error)) {
                return message
            }
        default:
            break
        }

        if Self.isMusicBackendUnavailableError(error) {
            return localized(key: "appModel.music.backend.unavailable")
        }
        if Self.shouldShowConnectionNotice(for: error) {
            return localized(key: "appModel.no.connection.to.home.assistant")
        }

        return playbackCommandFailureFallback(command: command)
    }

    private func playbackCommandFailureFallback(command: String) -> String {
        switch command {
        case "set_shuffle":
            return localized(key: "appModel.shuffle.could.not.be.changed")
        case "set_repeat":
            return localized(key: "appModel.repeat.could.not.be.changed")
        case "set_volume", "volume_delta":
            return localized(key: "appModel.volume.could.not.be.changed")
        case "seek_relative":
            return localized(key: "appModel.seek.could.not.be.changed")
        case "next", "previous":
            return localized(key: "appModel.track.could.not.be.changed")
        case "play", "pause", "start_playlist", "start_liked_proxy", "play_context_at":
            return localized(key: "appModel.playback.could.not.be.changed")
        case "set_output":
            return localized(key: "appModel.output.could.not.be.changed")
        default:
            return localized(key: "appModel.action.could.not.be.completed")
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
            name: localized(key: "appModel.living.room"),
            type: "speaker",
            active: true,
            supportsVolume: true,
            volumePercent: 42
        )
        availableOutputs = [
            output,
            DJConnectOutputDevice(
                id: "demo-kitchen",
                name: localized(key: "appModel.kitchen"),
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
            DJConnectPlaylist(id: "demo-playlist-1", name: localized(key: "appModel.friday.night"), uri: "spotify:playlist:djconnect-demo"),
            DJConnectPlaylist(id: "demo-playlist-2", name: localized(key: "appModel.dinner.vibes"), uri: "spotify:playlist:djconnect-dinner")
        ]
        playlists = playlistItems.map(\.name)
        updateDemoWidgetSnapshots()
        djResponseText = localized(key: "appModel.tap.the.microphone.icon.to.hear.a.sample.announcement")
        backendAvailable = true
        updateRequiredMessage = nil
        if startBackgroundTasks {
            updatePlaybackProgressTimer()
        }
    }

    private func refreshDemoCollections() {
        let currentPlayback = playback
        applyDemoState()
        if let currentPlayback {
            playback = currentPlayback
            updateDemoWidgetSnapshots()
            if startBackgroundTasks {
                updatePlaybackProgressTimer()
            }
        }
    }

    private func updateDemoWidgetSnapshots() {
        updateNowPlayingWidgetSnapshot(playback: playback)
        updateQueueWidgetSnapshot(items: queueItems)
        if let currentTrackInsight {
            saveTrackInsightWidgetSnapshot(for: currentTrackInsight)
        } else {
            clearTrackInsightWidgetSnapshot(reason: "Demo Track Insight empty")
        }
        if !askDJMessages.isEmpty {
            saveAskDJWidgetSnapshot()
        } else {
            clearAskDJWidgetSnapshot(reason: "Demo Ask DJ history empty")
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
            applyDemoQueueItem(relativeOffset: 1)
            return
        case "previous":
            applyDemoQueueItem(relativeOffset: -1)
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
        case "set_current_track_favorite", "save_current_track":
            if command == "save_current_track" {
                updated.favoriteStatus = true
                updated.isLiked = true
            } else if case let .bool(isFavorite) = value {
                updated.favoriteStatus = isFavorite
                updated.isLiked = isFavorite
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
        updateDemoWidgetSnapshots()
        if startBackgroundTasks {
            updatePlaybackProgressTimer()
        }
    }

    private func applyDemoSeek(to milliseconds: Int) {
        pendingSeekTargetMS = nil
        seekCommandTask?.cancel()
        seekCommandTask = nil
        var updated = playback ?? DJConnectPlayback()
        let duration = max(updated.durationMS ?? milliseconds, 0)
        updated.progressMS = min(max(milliseconds, 0), duration)
        playback = updated
        updateDemoWidgetSnapshots()
        syncTrackInsightLiveActivity(reason: "Demo seek changed")
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
        currentTrackInsight = nil
        updateDemoWidgetSnapshots()
        syncTrackInsightLiveActivity(reason: "Demo playback changed")
        scheduleVibeCastAutoTrackInsightIfNeeded(reason: "Demo playback changed")
        if startBackgroundTasks {
            updatePlaybackProgressTimer()
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

    private func currentDemoQueueIndex() -> Int? {
        guard let playback else {
            return nil
        }
        return queueItems.firstIndex { item in
            item.title == playback.trackName && item.artist == playback.artistName
        }
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

    private func makeClient() throws -> DJConnectClient {
        guard let baseURL = homeAssistantBaseURLs().first else {
            log(.warning, "Cannot create Home Assistant client because URL is invalid")
            throw DJConnectError.network(message: localized(key: "appModel.enter.your.home.assistant.url.for.example.192.168"))
        }
        return makeClient(baseURL: baseURL)
    }

    private func makeClient(baseURL: URL) -> DJConnectClient {
        DJConnectClient(
            baseURL: baseURL,
            identity: identity,
            tokenStore: tokenStore,
            session: urlSession,
            webSocketFastPath: webSocketFastPathIfLocal(baseURL),
            responseLogger: { [weak self] requestSummary, statusCode in
                Task { @MainActor in
                    self?.log(.debug, "Home Assistant API \(requestSummary) -> HTTP \(statusCode)")
                }
            },
            failureLogger: { [weak self] details in
                Task { @MainActor in
                    self?.logAPIFailure(details)
                }
            }
        )
    }

    private func logAPIFailure(_ details: DJConnectAPIFailureLogDetails) {
        log(
            .warning,
            "Home Assistant API failure route=\(details.route) http_status=\(details.httpStatus.map(String.init) ?? "none") ws_code=\(details.websocketCode ?? "none") error=\(details.serverError) message=\((details.serverMessage ?? "none").replacingOccurrences(of: "\n", with: "\\n")) identity_present=\(details.identityPresent) token_present=\(details.tokenPresent) client_type=\(details.clientType) client_id=\(details.redactedClientID)"
        )
    }

    private func webSocketFastPathIfLocal(_ baseURL: URL) -> (any DJConnectWebSocketFastPathTransport)? {
        let configuration = transportConfiguration()
        let localURL = Self.normalizedHomeAssistantURL(from: localHomeAssistantURL())
            ?? Self.normalizedHomeAssistantURL(from: homeAssistantURL)
            ?? Self.normalizedHomeAssistantURL(from: haLocalURL)
        guard DJConnectFastPathPolicy.isEligible(baseURL: baseURL, localURL: localURL) else {
            return nil
        }
        let key = DJConnectFastPathPolicy.cacheKey(for: baseURL)
        if let cached = webSocketFastPathCache[key] {
            return cached
        }
        guard let fastPath = DJConnectFastPathPolicy.makeFastPath(
            baseURL: baseURL,
            localURL: localURL,
            configuration: configuration
        ) else {
            return nil
        }
        webSocketFastPathCache[key] = fastPath
        return fastPath
    }

    private func transportConfiguration(allowsRemoteHTTPFallback: Bool = true) -> DJConnectTransportConfiguration {
        DJConnectTransportConfiguration(
            webSocketFastPathEnabled: webSocketFastPathEnabled,
            homeAssistantWebSocketAuth: homeAssistantWebSocketAuth,
            allowsRemoteHTTPFallback: allowsRemoteHTTPFallback
        )
    }

    private func updateFastPathDiagnostics(from client: DJConnectClient) async {
        fastPathDiagnostics = await client.fastPathDiagnostics
    }

    private func homeAssistantBaseURLs() -> [URL] {
        var urls: [URL] = []
        var seen: Set<String> = []
        for rawURL in [localHomeAssistantURL(), homeAssistantURL, haLocalURL, haRemoteURL] {
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
        let localURL = Self.normalizedHomeAssistantURL(from: localHomeAssistantURL())
            ?? Self.normalizedHomeAssistantURL(from: homeAssistantURL)
        let remoteURL = Self.normalizedHomeAssistantURL(from: haRemoteURL)
        guard localURL != nil || remoteURL != nil else {
            throw DJConnectError.network(message: localized(key: "appModel.enter.your.home.assistant.url.for.example.192.168"))
        }

        let localFastPath = localURL.flatMap { webSocketFastPathIfLocal($0) }
        let configuration = transportConfiguration(allowsRemoteHTTPFallback: identity.clientType != .watchos)
        let transport = DJConnectHATransportManager(
            localURL: localURL,
            remoteURL: remoteURL,
            allowsRemoteFallback: configuration.allowsRemoteHTTPFallback,
            clientFactory: { [weak self, identity, tokenStore, urlSession, localURL, localFastPath] baseURL in
                let fastPath = DJConnectFastPathPolicy.isEligible(baseURL: baseURL, localURL: localURL) ? localFastPath : nil
                return DJConnectClient(
                    baseURL: baseURL,
                    identity: identity,
                    tokenStore: tokenStore,
                    session: urlSession,
                    webSocketFastPath: fastPath,
                    failureLogger: { details in
                        Task { @MainActor in
                            self?.logAPIFailure(details)
                        }
                    }
                )
            },
            modeReporter: { [weak self] mode, baseURL in
                Task { @MainActor in
                    self?.recordConnectionMode(mode, baseURL: baseURL)
                }
            }
        )
        return try await transport.perform { client in
            do {
                let result = try await operation(client)
                await updateFastPathDiagnostics(from: client)
                return result
            } catch {
                await updateFastPathDiagnostics(from: client)
                throw error
            }
        }
    }

    private func recordConnectionMode(_ mode: DJConnectHAConnectionMode, baseURL: URL?) {
        haConnectionMode = mode
        defaults.set(mode.rawValue, forKey: haConnectionModeKey)
        if mode == .local, let baseURL {
            pinLocalHomeAssistantURLIfNeeded(baseURL)
        }
        if mode == .remote {
            log(.info, "Using remote Home Assistant connection")
        }
    }

    private func pinLocalHomeAssistantURLIfNeeded(_ baseURL: URL) {
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
            let isDeviceNetwork = path.status == .satisfied
            let isLocalNetwork = path.status == .satisfied
                && (path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet))
            Task { @MainActor in
                guard let self else {
                    return
                }
                let didChange = self.isDeviceNetworkAvailable != isDeviceNetwork
                    || self.isLocalNetworkAvailable != isLocalNetwork
                    || !self.hasEvaluatedDeviceNetwork
                    || !self.hasEvaluatedLocalNetwork
                guard didChange else {
                    return
                }
                self.hasEvaluatedDeviceNetwork = true
                self.hasEvaluatedLocalNetwork = true
                self.isDeviceNetworkAvailable = isDeviceNetwork
                self.isLocalNetworkAvailable = isLocalNetwork
                self.updateNowPlayingPollTimer()
                self.updatePlaybackProgressTimer()
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

    var isAppInForegroundForTests: Bool {
        isAppInForeground
    }

    #if os(iOS) && canImport(WatchConnectivity)
    private func activateWatchProxySession() {
        guard WCSession.isSupported() else {
            return
        }
        if watchProxySessionDelegate == nil {
            watchProxySessionDelegate = DJConnectWatchProxySessionDelegate(model: self)
        }
        WCSession.default.delegate = watchProxySessionDelegate
        WCSession.default.activate()
    }

    fileprivate func handleWatchProxyActivation(state: WCSessionActivationState, error: Error?) {
        if let error {
            log(.warning, "Watch proxy session activation failed: \(error.localizedDescription)")
            return
        }
        log(.debug, "Watch proxy session activation state=\(state.rawValue)")
        handleWatchProxyMessage(WCSession.default.receivedApplicationContext)
        if watchProxyRegistration != nil {
            sendWatchProxyReady()
        }
    }

    fileprivate func handleWatchProxyReachabilityChange() {
        if WCSession.default.isReachable, watchProxyRegistration != nil {
            sendWatchProxyReady()
        }
    }

    fileprivate func handleWatchProxyMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else {
            return
        }
        switch type {
        case "watch_proxy_register":
            registerWatchProxy(message)
        case "watch_proxy_ha_request":
            handleWatchProxyHARequest(message)
        default:
            break
        }
    }

    private func registerWatchProxy(_ message: [String: Any]) {
        guard let deviceID = message["device_id"] as? String, deviceID.hasPrefix("djconnect-watchos-"),
              let pairCode = message["pair_code"] as? String, !pairCode.isEmpty else {
            log(.warning, "Watch proxy registration ignored because device_id or pair_code is missing")
            return
        }
        let clientType = DJConnectClientType(rawValue: (message["client_type"] as? String ?? "").lowercased()) ?? .watchos
        guard clientType == .watchos else {
            log(.warning, "Watch proxy registration ignored because client_type is \(clientType.rawValue)")
            return
        }
        let firmware = message["firmware"] as? String ?? appVersion
        let appVersion = message["app_version"] as? String ?? firmware
        let identity = DJConnectIdentity(
            deviceID: deviceID,
            deviceName: message["device_name"] as? String ?? "DJConnect Watch",
            clientType: .watchos,
            firmware: firmware,
            appVersion: appVersion,
            platform: .watchos
        )
        watchProxyRegistration = DJConnectWatchProxyRegistration(
            identity: identity,
            pairCode: pairCode,
            paired: (message["paired"] as? Bool) ?? defaults.bool(forKey: watchProxyPairedKey)
        )
        persistWatchProxyRegistration()
        sendWatchProxyReady()
        log(.info, "Watch proxy registered \(Self.redactedDJConnectDeviceID(deviceID))")
    }

    private func restoreWatchProxyRegistration() {
        guard let deviceID = defaults.string(forKey: watchProxyDeviceIDKey), !deviceID.isEmpty,
              let pairCode = defaults.string(forKey: watchProxyPairCodeKey), !pairCode.isEmpty else {
            return
        }
        let firmware = defaults.string(forKey: watchProxyFirmwareKey) ?? appVersion
        watchProxyRegistration = DJConnectWatchProxyRegistration(
            identity: DJConnectIdentity(
                deviceID: deviceID,
                deviceName: defaults.string(forKey: watchProxyDeviceNameKey) ?? "DJConnect Watch",
                clientType: .watchos,
                firmware: firmware,
                appVersion: defaults.string(forKey: watchProxyAppVersionKey) ?? firmware,
                platform: .watchos
            ),
            pairCode: pairCode,
            paired: defaults.bool(forKey: watchProxyPairedKey)
        )
    }

    private func persistWatchProxyRegistration() {
        guard let registration = watchProxyRegistration else {
            return
        }
        defaults.set(registration.identity.deviceID, forKey: watchProxyDeviceIDKey)
        defaults.set(registration.identity.deviceName, forKey: watchProxyDeviceNameKey)
        defaults.set(registration.identity.firmware, forKey: watchProxyFirmwareKey)
        defaults.set(registration.identity.appVersion, forKey: watchProxyAppVersionKey)
        defaults.set(registration.pairCode, forKey: watchProxyPairCodeKey)
        defaults.set(registration.paired, forKey: watchProxyPairedKey)
    }

    private func attemptWatchProxyPairingIfNeeded() {
        guard let registration = watchProxyRegistration, !registration.paired else {
            return
        }
        Task { @MainActor in
            await self.pollWatchProxyPairing(registration)
        }
    }

    private func pollWatchProxyPairing(_ registration: DJConnectWatchProxyRegistration) async {
        guard let baseURL = Self.normalizedHomeAssistantURL(from: localHomeAssistantURL())
            ?? Self.normalizedHomeAssistantURL(from: homeAssistantURL) else {
            sendWatchProxyMessage([
                "type": "watch_proxy_ready",
                "device_id": registration.identity.deviceID,
                "client_type": registration.identity.clientType.rawValue,
                "message": localized(key: "appModel.open.djconnect.on.iphone.and.pair.with.local.home")
            ])
            return
        }
        await pairWatchProxy(registration: registration, homeAssistantURL: Self.redactedURL(baseURL), pairCode: registration.pairCode)
    }

    private func pairWatchProxy(registration: DJConnectWatchProxyRegistration, homeAssistantURL: String, pairCode: String) async {
        guard let baseURL = Self.normalizedHomeAssistantURL(from: homeAssistantURL) else {
            watchPairingMessage = localized(key: "appModel.invalid.local.home.assistant.url.for.apple.watch.pairing")
            pairingMessage = watchPairingMessage
            return
        }
        let tokenStore = DJConnectInMemoryTokenStore()
        let client = DJConnectClient(baseURL: baseURL, identity: registration.identity, tokenStore: tokenStore)
        do {
            let response = try await client.pair(DJConnectPairingPayload(
                identity: registration.identity,
                pairingToken: pairCode,
                haLocalURL: Self.redactedURL(baseURL),
                assistPipelineID: assistPipelineID.isEmpty ? nil : assistPipelineID,
                bootstrapProof: pairCode
            ))
            guard let token = try tokenStore.loadToken(), !token.isEmpty else {
                return
            }
            defaults.set(token, forKey: watchProxyDeviceTokenKey)
            persistWatchPairingContract(response)
            apply(musicBackendSummary: response.musicBackendSummary)
            remoteSupported = response.remoteSupported ?? remoteSupported
            watchPairingMessage = localized(key: "appModel.home.assistant.recognized.apple.watch.finish.setup.in.home")
            pairingFlowTarget = .appleWatch
            pairingStatus = .waitingForHomeAssistantCompletion
            isShowingPairingSuccess = false
            isPairingScreenDismissed = false
            pairingMessage = watchPairingMessage
            try await waitForWatchProxyPairingCompletion(
                client: client,
                registration: registration,
                response: response,
                token: token,
                baseURL: baseURL,
                pairCode: pairCode
            )
            log(.info, "Watch proxy paired through iPhone for \(Self.redactedDJConnectDeviceID(registration.identity.deviceID))")
        } catch let error as DJConnectError {
            if case .pairingFailed = error {
                watchPairingMessage = localized(key: "appModel.home.assistant.did.not.accept.the.apple.watch.pair")
                pairingMessage = watchPairingMessage
            } else if case .versionMismatch = error {
                sendWatchProxyMessage([
                    "type": "watch_proxy_ready",
                    "device_id": registration.identity.deviceID,
                    "client_type": registration.identity.clientType.rawValue,
                    "message": Self.watchProxyUserMessage(for: error)
                ])
            } else {
                if case .authStale = error {
                    clearWatchProxyPairingState()
                } else if case .notConfigured = error {
                    clearWatchProxyPairingState()
                }
                log(.debug, "Watch proxy pairing pending: \(Self.describe(error))")
            }
        } catch {
            log(.debug, "Watch proxy pairing pending: \(error.localizedDescription)")
        }
    }

    private func waitForWatchProxyPairingCompletion(
        client: DJConnectClient,
        registration: DJConnectWatchProxyRegistration,
        response: DJConnectPairingResponse,
        token: String,
        baseURL: URL,
        pairCode: String
    ) async throws {
        let delays: [UInt64] = [0, 2, 3, 5, 5, 5]
        for delay in delays {
            if delay > 0 {
                try await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else {
                return
            }
            do {
                _ = try await client.postStatus(DJConnectStatusPayload(
                    identity: registration.identity,
                    haPairingStatus: .paired,
                    language: currentRequestLocale,
                    logLevel: logLevel,
                    localAudioSupported: false,
                    voiceSupported: true,
                    haLocalURL: response.haLocalURL ?? Self.redactedURL(baseURL),
                    voiceEnabled: voiceEnabled,
                    wakewordEnabled: false,
                    wakewordPhrase: "",
                    wakewordStatus: "\(wakeWordStatus)",
                    mood: askDJMoodInt,
                    musicDNAKey: askDJMusicDNAKey
                ))
            } catch let error as DJConnectError {
                if isWaitingForHomeAssistantCompletion(error) {
                    watchPairingMessage = localized(key: "appModel.waiting.for.setup.to.be.completed.in.home.assistant")
                    pairingMessage = watchPairingMessage
                    log(.debug, "Waiting for Home Assistant Watch setup completion: \(Self.describe(error))")
                    continue
                }
                throw error
            }
            var updated = registration
            updated.paired = true
            updated.pairCode = pairCode
            watchProxyRegistration = updated
            persistWatchProxyRegistration()
            watchPairingMessage = localized(key: "appModel.apple.watch.paired.with.home.assistant")
            pairingStatus = .paired
            pairingFlowTarget = .appleWatch
            isShowingPairingSuccess = true
            isPairingScreenDismissed = false
            pairingMessage = watchPairingMessage
            sendWatchProxyMessage([
                "type": "watch_proxy_pair_result",
                "device_token": token,
                "ha_base_url": response.haLocalURL ?? Self.redactedURL(baseURL),
                "connection_mode": haConnectionMode.rawValue,
                "remote_supported": remoteSupported,
                "music_backend": musicBackendSummary.musicBackend ?? "",
                "music_backend_name": musicBackendSummary.displayName,
                "music_backend_available": musicBackendSummary.musicBackendAvailable ?? true,
                "music_backend_revision": musicBackendSummary.musicBackendRevision ?? 0,
                "music_backend_error": musicBackendSummary.musicBackendError ?? "",
                "music_target_player_name": musicBackendSummary.musicTargetPlayer?.name ?? "",
                "assist_pipeline_id": response.assistPipelineID ?? assistPipelineID,
                "api_base": response.apiBase ?? "",
                "voice_path": response.voicePath ?? "",
                "status_path": response.statusPath ?? "",
                "event_path": response.eventPath ?? "",
                "ask_dj_supported": response.askDJSupported ?? true,
                "ask_dj_voice_supported": response.askDJVoiceSupported ?? true,
                "ask_dj_audio_response_supported": response.askDJAudioResponseSupported ?? true
            ])
            return
        }
        watchPairingMessage = localized(key: "appModel.not.completed.in.home.assistant.yet.finish.setup.there")
        pairingMessage = watchPairingMessage
    }

    private func persistWatchPairingContract(_ response: DJConnectPairingResponse) {
        if let value = response.apiBase {
            defaults.set(value, forKey: watchProxyAPIBaseKey)
        }
        if let value = response.voicePath {
            defaults.set(value, forKey: watchProxyVoicePathKey)
        }
        if let value = response.statusPath {
            defaults.set(value, forKey: watchProxyStatusPathKey)
        }
        if let value = response.eventPath {
            defaults.set(value, forKey: watchProxyEventPathKey)
        }
        if let value = response.askDJSupported {
            defaults.set(value, forKey: watchProxyAskDJSupportedKey)
        }
        if let value = response.askDJVoiceSupported {
            defaults.set(value, forKey: watchProxyAskDJVoiceSupportedKey)
        }
        if let value = response.askDJAudioResponseSupported {
            defaults.set(value, forKey: watchProxyAskDJAudioResponseSupportedKey)
        }
    }

    private func clearWatchProxyPairingState() {
        defaults.removeObject(forKey: watchProxyDeviceTokenKey)
        defaults.removeObject(forKey: watchProxyAPIBaseKey)
        defaults.removeObject(forKey: watchProxyVoicePathKey)
        defaults.removeObject(forKey: watchProxyStatusPathKey)
        defaults.removeObject(forKey: watchProxyEventPathKey)
        defaults.removeObject(forKey: watchProxyAskDJSupportedKey)
        defaults.removeObject(forKey: watchProxyAskDJVoiceSupportedKey)
        defaults.removeObject(forKey: watchProxyAskDJAudioResponseSupportedKey)
        if var registration = watchProxyRegistration {
            registration.paired = false
            watchProxyRegistration = registration
            persistWatchProxyRegistration()
        }
    }

    private func clearWatchProxyRegistration() {
        watchProxyRegistration = nil
        for key in [
            watchProxyDeviceIDKey,
            watchProxyDeviceNameKey,
            watchProxyPairCodeKey,
            watchProxyFirmwareKey,
            watchProxyAppVersionKey,
            watchProxyPairedKey,
            watchProxyDeviceTokenKey,
            watchProxyLocalURLKey,
            watchProxyAPIBaseKey,
            watchProxyVoicePathKey,
            watchProxyStatusPathKey,
            watchProxyEventPathKey,
            watchProxyAskDJSupportedKey,
            watchProxyAskDJVoiceSupportedKey,
            watchProxyAskDJAudioResponseSupportedKey
        ] {
            defaults.removeObject(forKey: key)
        }
    }

    private func sendWatchProxyReady() {
        guard let registration = watchProxyRegistration else {
            return
        }
        sendWatchProxyMessage([
            "type": "watch_proxy_ready",
            "device_id": registration.identity.deviceID,
            "client_type": registration.identity.clientType.rawValue,
            "connection_mode": haConnectionMode.rawValue,
            "remote_supported": remoteSupported,
            "music_backend": musicBackendSummary.musicBackend ?? "",
            "music_backend_name": musicBackendSummary.displayName,
            "music_backend_available": musicBackendSummary.musicBackendAvailable ?? true,
            "music_backend_revision": musicBackendSummary.musicBackendRevision ?? 0,
            "music_backend_error": musicBackendSummary.musicBackendError ?? "",
            "music_target_player_name": musicBackendSummary.musicTargetPlayer?.name ?? ""
        ])
    }

    private func handleWatchProxyHARequest(_ message: [String: Any]) {
        guard let requestData = message["request"] as? Data,
              let request = try? JSONDecoder().decode(DJConnectWatchProxyRequest.self, from: requestData) else {
            sendWatchProxyHAResponse(
                DJConnectWatchProxyResponse(success: false, error: "bad_request", message: "Invalid Watch proxy request."),
                correlationID: message["correlation_id"] as? String
            )
            return
        }
        let correlationID = message["correlation_id"] as? String
        Task { @MainActor in
            let response = await self.performWatchProxyHARequest(request)
            self.sendWatchProxyHAResponse(response, correlationID: correlationID)
        }
    }

    private func performWatchProxyHARequest(_ request: DJConnectWatchProxyRequest) async -> DJConnectWatchProxyResponse {
        guard let registration = watchProxyRegistration else {
            return DJConnectWatchProxyResponse(success: false, error: "watch_proxy_unavailable", message: "No Watch registered with this iPhone.")
        }
        guard let token = defaults.string(forKey: watchProxyDeviceTokenKey), !token.isEmpty else {
            return DJConnectWatchProxyResponse(success: false, error: "missing_token", message: "Watch is not paired with Home Assistant.")
        }
        do {
            let encoded = try await withWatchProxyHomeAssistantClient(identity: registration.identity, token: token) { client in
                try await self.performWatchProxyOperation(request, client: client)
            }
            return DJConnectWatchProxyResponse(success: true, payload: encoded)
        } catch let error as DJConnectError {
            if case .authStale = error {
                clearWatchProxyPairingState()
            } else if case .notConfigured = error {
                clearWatchProxyPairingState()
            }
            return DJConnectWatchProxyResponse(success: false, error: Self.watchProxyErrorCode(for: error), message: Self.watchProxyUserMessage(for: error))
        } catch {
            return DJConnectWatchProxyResponse(success: false, error: Self.watchProxyErrorCode(for: error), message: Self.watchProxyUserMessage(for: error))
        }
    }

    private func performWatchProxyOperation(_ request: DJConnectWatchProxyRequest, client: DJConnectClient) async throws -> Data {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        switch request.operation {
        case .status:
            let payload = try decoder.decode(DJConnectStatusPayload.self, from: request.payload ?? Data())
            let response = try await client.postStatus(payload)
            return try encoder.encode(response)
        case .command:
            let payload = try decoder.decode(DJConnectCommandPayload.self, from: request.payload ?? Data())
            let response = try await client.sendCommandResponse(payload)
            return try encoder.encode(response)
        case .trackInsight:
            let payload = try decoder.decode(DJConnectTrackInsightRequest.self, from: request.payload ?? Data())
            let response = try await client.trackInsight(payload)
            return try encoder.encode(response)
        case .askDJHistory:
            let response = try await client.askDJHistory()
            return try encoder.encode(response)
        case .clearAskDJHistory:
            let payload = try decoder.decode(DJConnectAskDJClearHistoryRequest.self, from: request.payload ?? Data())
            let response = try await client.clearAskDJHistory(musicDNAKey: payload.musicDNAKey)
            return try encoder.encode(response)
        case .askDJMessage:
            let payload = try decoder.decode(DJConnectAskDJRequest.self, from: request.payload ?? Data())
            let response = try await client.sendAskDJMessage(payload)
            return try encoder.encode(response)
        case .askDJIdleSuggestion:
            let payload = try decoder.decode(DJConnectAskDJIdleSuggestionRequest.self, from: request.payload ?? Data())
            let response = try await client.askDJIdleSuggestion(payload)
            return try encoder.encode(response)
        case .musicDNAProfile:
            let payload = request.payload.flatMap {
                try? decoder.decode(DJConnectMusicDNAIdentityRequest.self, from: $0)
            }
            let response = try await client.musicDNAProfile(mood: payload?.mood)
            return try encoder.encode(response)
        case .musicDNASettings:
            let payload = try decoder.decode(DJConnectMusicDNASettingsRequest.self, from: request.payload ?? Data())
            let response = try await client.setMusicDNAEnabled(payload.enabled, mood: payload.mood)
            return try encoder.encode(response)
        case .clearMusicDNA:
            let payload = request.payload.flatMap {
                try? decoder.decode(DJConnectMusicDNAIdentityRequest.self, from: $0)
            }
            let response = try await client.clearMusicDNA(mood: payload?.mood)
            return try encoder.encode(response)
        case .voice:
            let payload = try decoder.decode(DJConnectWatchProxyVoicePayload.self, from: request.payload ?? Data())
            let response = try await client.sendVoice(
                wavData: payload.wavData,
                mood: payload.mood,
                djStyle: payload.djStyle,
                musicDNAKey: payload.musicDNAKey,
                language: payload.language ?? currentRequestLocale
            )
            return try encoder.encode(response)
        case .pushRegister:
            let payload = try decoder.decode(DJConnectPushRegistrationRequest.self, from: request.payload ?? Data())
            let response = try await client.registerPushNotifications(payload)
            return try encoder.encode(response)
        case .pushUnregister:
            let payload = try decoder.decode(DJConnectPushUnregistrationRequest.self, from: request.payload ?? Data())
            let response = try await client.unregisterPushNotifications(payload)
            return try encoder.encode(response)
        }
    }

    private func withWatchProxyHomeAssistantClient<T: Sendable>(
        identity: DJConnectIdentity,
        token: String,
        _ operation: (DJConnectClient) async throws -> T
    ) async throws -> T {
        let localURL = Self.normalizedHomeAssistantURL(from: localHomeAssistantURL())
            ?? Self.normalizedHomeAssistantURL(from: homeAssistantURL)
        let remoteURL = Self.normalizedHomeAssistantURL(from: haRemoteURL)
        let tokenStore = DJConnectInMemoryTokenStore(token: token)
        let configuration = transportConfiguration()
        let transport = DJConnectHATransportManager(
            localURL: localURL,
            remoteURL: remoteURL,
            allowsRemoteFallback: configuration.allowsRemoteHTTPFallback,
            clientFactory: { [localURL, configuration] baseURL in
                DJConnectClient(
                    baseURL: baseURL,
                    identity: identity,
                    tokenStore: tokenStore,
                    webSocketFastPath: DJConnectFastPathPolicy.makeFastPath(
                        baseURL: baseURL,
                        localURL: localURL,
                        configuration: configuration
                    )
                )
            },
            modeReporter: { [weak self] mode, baseURL in
                Task { @MainActor in
                    self?.recordConnectionMode(mode, baseURL: baseURL)
                    self?.sendWatchProxyReady()
                }
            }
        )
        return try await transport.perform(operation)
    }

    private func sendWatchProxyHAResponse(_ response: DJConnectWatchProxyResponse, correlationID: String?) {
        guard let correlationID,
              let data = try? JSONEncoder().encode(response) else {
            return
        }
        sendWatchProxyMessage([
            "type": "watch_proxy_ha_response",
            "correlation_id": correlationID,
            "response": data
        ])
    }

    private static func watchProxyErrorCode(for error: Error) -> String {
        guard let error = error as? DJConnectError else {
            return "failed"
        }
        switch error {
        case .versionMismatch:
            return "version_mismatch"
        case .authStale:
            return "auth_stale"
        case .backendUnavailable:
            return "backend_unavailable"
        case .routeMissing:
            return "route_missing"
        case .network:
            return "network"
        case .notConfigured:
            return "not_configured"
        case .missingToken:
            return "missing_token"
        case .invalidConfiguration:
            return "invalid_configuration"
        case .pairingFailed:
            return "pairing_failed"
        case .clientTypeMismatch:
            return "client_type_mismatch"
        case .trackInsightUnavailable:
            return "track_insight_unavailable"
        case .server, .decodingFailed, .invalidResponse:
            return "server"
        }
    }

    private func sendWatchProxyMessage(_ message: [String: Any]) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else {
            return
        }
        do {
            try WCSession.default.updateApplicationContext(message)
        } catch {
            log(.warning, "Watch proxy application context failed: \(error.localizedDescription)")
        }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.log(.warning, "Watch proxy message failed: \(error.localizedDescription)")
                }
            }
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }

    nonisolated private static func redactedDJConnectDeviceID(_ deviceID: String) -> String {
        guard deviceID.count > 6 else {
            return "..."
        }
        return "...\(deviceID.suffix(6))"
    }
    #endif

    private func localHomeAssistantURL() -> String {
        if !haLocalURL.isEmpty {
            return haLocalURL
        }
        return homeAssistantURL
    }

    private func clearStoredHomeAssistantURLs() {
        haLocalURL = ""
        haRemoteURL = ""
        haConnectionMode = .offline
        defaults.removeObject(forKey: haLocalURLKey)
        defaults.removeObject(forKey: haRemoteURLKey)
        defaults.removeObject(forKey: haConnectionModeKey)
        defaults.removeObject(forKey: "DJConnectHAActiveURL")
        assistPipelineID = ""
        defaults.removeObject(forKey: assistPipelineIDKey)
        clearPairingContractState()
    }

    private func clearPairingContractState() {
        apiBase = ""
        voicePath = ""
        statusPath = ""
        eventPath = ""
        askDJSupported = false
        askDJVoiceSupported = false
        askDJAudioResponseSupported = false
        defaults.removeObject(forKey: apiBaseKey)
        defaults.removeObject(forKey: voicePathKey)
        defaults.removeObject(forKey: statusPathKey)
        defaults.removeObject(forKey: eventPathKey)
        defaults.removeObject(forKey: askDJSupportedKey)
        defaults.removeObject(forKey: askDJVoiceSupportedKey)
        defaults.removeObject(forKey: askDJAudioResponseSupportedKey)
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
        let activeOutput = availableOutputs.first { $0.active == true }
        return """
        DJConnect Diagnostics
        version: \(appVersion)
        client_type: \(identity.clientType.rawValue)
        device_id: \(identity.deviceID)
        bundle_id: \(Bundle.main.bundleIdentifier ?? "unknown")
        locale: \(Locale.current.identifier)
        pairing_status: \(pairingStatus.rawValue)
        demo_mode: \(isDemoMode)
        app_store_review_demo_available: true
        bearer_token: \(tokenState)
        home_assistant_url: \(url)
        ha_local_url: \(haLocalURL.isEmpty ? "missing" : Self.redactSensitive(haLocalURL))
        ha_remote_url: \(haRemoteURL.isEmpty ? "missing" : Self.redactSensitive(haRemoteURL))
        ha_connection_mode: \(haConnectionMode.rawValue)
        remote_supported: \(remoteSupported)
        protocol_version: \(appVersion)
        music_backend: \(musicBackendSummary.musicBackend ?? "missing")
        music_backend_name: \(musicBackendSummary.musicBackendName ?? "missing")
        music_backend_available: \(musicBackendSummary.musicBackendAvailable.map(String.init) ?? "unknown")
        music_backend_revision: \(musicBackendSummary.musicBackendRevision.map(String.init) ?? "missing")
        music_target_player: \(musicBackendSummary.musicTargetPlayer?.name ?? "missing") / \(musicBackendSummary.musicTargetPlayer?.id ?? "missing")
        music_backend_error: \(musicBackendSummary.musicBackendError ?? "none")
        playback_features_enabled: \(canUsePlaybackFeatures)
        playback_has_active_snapshot: \(playback?.hasPlayback.map(String.init) ?? "unknown")
        playback_is_playing: \(playback?.isPlaying.map(String.init) ?? "unknown")
        playback_track_present: \((playback?.trackName?.isEmpty == false) ? "true" : "false")
        output_count: \(availableOutputs.count)
        active_output: \(activeOutput?.name ?? "missing") / \(activeOutput?.id ?? "missing")
        assist_pipeline_id: \(assistPipelineID.isEmpty ? "missing" : "present")
        backend_available: \(backendAvailable)
        selected_output: \(selectedOutput)
        language: \(language)
        log_level: \(logLevel)
        microphone_permission: \(microphonePermissionStatus.rawValue)
        speech_permission: \(speechPermissionStatus.rawValue)
        notification_permission: \(notificationPermissionStatus.rawValue)
        local_network_permission: \(localNetworkPermissionStatus.rawValue)
        voice_enabled: \(voiceEnabled)
        wakeword_enabled: \(wakeWordEnabled)
        wakeword_phrase: \(wakeWordPhrase)
        wakeword_status: \(wakeWordStatus)
        local_response_audio_enabled: \(localResponseAudioEnabled)
        fast_path_transport: \(fastPathDiagnostics.fastPathTransport)
        fast_path_websocket_connected: \(fastPathDiagnostics.websocketConnected)
        fast_path_last_capability_refresh: \(fastPathDiagnostics.lastCapabilityRefresh?.description ?? "missing")
        fast_path_websocket_commands: \(fastPathDiagnostics.websocketCommands.isEmpty ? "none" : fastPathDiagnostics.websocketCommands.joined(separator: ","))
        fast_path_last_error: \(fastPathDiagnostics.lastWebSocketError ?? "none")

        Logs
        \(lines.isEmpty ? "none" : lines)
        """
    }

    public func localized(key: String, arguments: CVarArg...) -> String {
        String(
            format: DJConnectLocalization.localized(key: key, language: language),
            locale: Locale(identifier: DJConnectLocalization.supportedLanguageCode(language)),
            arguments: arguments
        )
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

    private func normalizedPairCode(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 6, trimmed.allSatisfy(\.isNumber) else {
            return nil
        }
        return trimmed
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

    private static func watchProxyUserMessage(for error: Error) -> String {
        guard let error = error as? DJConnectError else {
            return "iPhone kon Home Assistant niet bereiken."
        }
        switch error {
        case let .versionMismatch(mismatch):
            return mismatch.message ?? "Werk DJConnect bij."
        case .backendUnavailable, .server, .decodingFailed, .invalidResponse:
            return "Home Assistant gaf geen antwoord."
        case .trackInsightUnavailable:
            return "Track Insight is niet beschikbaar voor dit nummer."
        case .network, .routeMissing, .notConfigured:
            return "Ask DJ niet bereikbaar."
        case .authStale, .missingToken:
            return "Koppel opnieuw via iPhone."
        case let .invalidConfiguration(message):
            return message
        case let .pairingFailed(message):
            return message ?? "Koppelen via iPhone is nog niet klaar."
        case let .clientTypeMismatch(message, _, _):
            return message ?? "Verkeerd app-type gekozen in Home Assistant."
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
        case let .clientTypeMismatch(message, expectedClientType, receivedClientType):
            "client type mismatch expected=\(expectedClientType ?? "?") received=\(receivedClientType ?? "?")\(message.map { ": \($0)" } ?? "")"
        case let .trackInsightUnavailable(code, message):
            "track insight unavailable\(code.map { " \($0)" } ?? "")\(message.map { ": \($0)" } ?? "")"
        }
    }

    private static func trackInsightFailureCode(for error: Error) -> String {
        guard let error = error as? DJConnectError else {
            return "unknown"
        }
        switch error {
        case let .trackInsightUnavailable(code, _):
            return trimmedNonEmpty(code) ?? "track_insight_unavailable"
        case .backendUnavailable:
            return "backend_unavailable"
        case .authStale:
            return "auth_stale"
        case .routeMissing:
            return "route_missing"
        case .versionMismatch:
            return "version_mismatch"
        case .notConfigured:
            return "not_configured"
        case .server:
            return "server"
        case .decodingFailed:
            return "decoding_failed"
        case .network:
            return "network"
        case .invalidResponse:
            return "invalid_response"
        case .invalidConfiguration:
            return "invalid_configuration"
        case .missingToken:
            return "missing_token"
        case .pairingFailed:
            return "pairing_failed"
        case .clientTypeMismatch:
            return "client_type_mismatch"
        }
    }

    private static func trackInsightFailureMessage(for error: Error) -> String {
        let message: String?
        if let error = error as? DJConnectError {
            switch error {
            case let .backendUnavailable(value),
                 let .routeMissing(value),
                 let .notConfigured(value),
                 let .trackInsightUnavailable(_, value):
                message = value
            case let .authStale(_, value),
                 let .server(_, value),
                 let .decodingFailed(_, _, value),
                 let .pairingFailed(value),
                 let .clientTypeMismatch(value, _, _):
                message = value
            case let .network(value):
                message = value
            case let .invalidConfiguration(value):
                message = value
            case .versionMismatch:
                message = "version_mismatch"
            case .invalidResponse:
                message = "invalid_response"
            case .missingToken:
                message = "missing_token"
            }
        } else {
            message = error.localizedDescription
        }
        return (trimmedNonEmpty(message) ?? "none").replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func trackInsightFailureTransport(for error: Error) -> String {
        guard let error = error as? DJConnectError else {
            return "unknown"
        }
        switch error {
        case .server, .authStale, .decodingFailed:
            return "http_or_ws"
        case .network:
            return "network"
        default:
            return "client_or_server"
        }
    }

    private static func trackInsightFailureHTTPStatus(for error: Error) -> String? {
        guard let error = error as? DJConnectError else {
            return nil
        }
        switch error {
        case let .authStale(statusCode, _),
             let .server(statusCode, _),
             let .decodingFailed(statusCode, _, _):
            return String(statusCode)
        default:
            return nil
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

    public func refreshPermissionStatuses(retryWakeWord: Bool = true) {
        microphonePermissionStatus = Self.currentMicrophonePermissionStatus()
        speechPermissionStatus = Self.currentSpeechPermissionStatus()
        Task { @MainActor in
            notificationPermissionStatus = await Self.currentNotificationPermissionStatus()
        }
        localNetworkPermissionStatus = .unknown
        log(.debug, "Permission status refreshed: microphone=\(microphonePermissionStatus.rawValue) speech=\(speechPermissionStatus.rawValue) notifications=\(notificationPermissionStatus.rawValue) local_network=\(localNetworkPermissionStatus.rawValue)")
        if retryWakeWord, wakeWordEnabled, wakeWordStatus == .unavailable, microphonePermissionStatus == .granted, speechPermissionStatus == .granted {
            log(.info, "Retrying wakeword listening after permission status refresh")
            resumeWakeWordListeningIfNeeded()
        }
    }

    public func setWakeWordEnabled(_ enabled: Bool) {
        refreshPermissionStatuses()
        if enabled,
           !wakeWordEnabled,
           (microphonePermissionStatus == .unknown || speechPermissionStatus == .unknown) {
            isShowingWakeWordActivationPrompt = true
            log(.debug, "Showing voice activation prompt from settings")
            return
        }
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
        switch notificationPermissionStatus {
        case .granted:
            log(.info, "Notification permission already granted")
            registerForSystemRemoteNotifications()
            refreshPermissionStatuses()
            return
        case .denied, .restricted:
            log(.info, "Opening system settings because notification permission was denied or restricted")
            openAppPermissionSettings()
            schedulePermissionStatusRefreshes()
            return
        case .unknown, .unavailable:
            break
        }
        pendingPermissionRequest = .appPermissions
        permissionExplanationKind = .notifications
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
        if pendingAskDJNotificationPreview != nil {
            pendingAskDJNotificationPreview = nil
            hasRequestedAskDJNotificationPermission = true
        }
        isShowingPermissionExplanation = false
        log(.debug, "User cancelled permission explanation")
    }

    private func requestAppPermissionsAfterExplanation() {
        guard !isRequestingPermissions else {
            return
        }
        isRequestingPermissions = true
        Task { @MainActor in
            log(.debug, "Notification permission request started: notifications_status=\(notificationPermissionStatus.rawValue)")
            log(.debug, "Permission request step: notifications begin")
            let notificationGranted: Bool
            #if canImport(UserNotifications)
            notificationGranted = await requestRemoteNotificationAuthorizationIfNeeded(center: UNUserNotificationCenter.current())
            let askDJNotificationPreview = pendingAskDJNotificationPreview
            if askDJNotificationPreview != nil {
                pendingAskDJNotificationPreview = nil
                hasRequestedAskDJNotificationPermission = true
            }
            if notificationGranted {
                registerForSystemRemoteNotifications()
                if let preview = askDJNotificationPreview {
                    await scheduleAskDJLocalNotification(center: UNUserNotificationCenter.current(), preview: preview)
                }
            }
            #else
            notificationGranted = false
            #endif
            log(.debug, "Permission request step: notifications completed granted=\(notificationGranted)")
            refreshPermissionStatuses()
            isRequestingPermissions = false
            if notificationGranted {
                log(.info, "Notification permission granted")
            } else {
                log(.warning, "Notification permission is incomplete")
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
        openPermissionSettingsTask?.cancel()
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            log(.warning, "Could not create iOS Settings URL")
            return
        }
        openPermissionSettingsTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else {
                return
            }
            await UIApplication.shared.open(url)
        }
        #elseif canImport(AppKit)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            openPermissionSettingsTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else {
                    return
                }
                NSWorkspace.shared.open(url)
            }
        }
        #endif
    }

    private func schedulePermissionStatusRefreshes() {
        Task { @MainActor in
            for delay in [500, 1_500, 3_000] {
                try? await Task.sleep(for: .milliseconds(delay))
                refreshPermissionStatuses(retryWakeWord: false)
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
        #else
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
        #endif
        #else
        return .unavailable
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
            await beginWakeWordListening()
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

    private func beginWakeWordListening() async {
        guard wakeAudioEngine == nil else {
            return
        }
        guard !isStoppingWakeWord else {
            return
        }
        let locale = Locale(identifier: Self.speechLocaleIdentifier(for: language))
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            wakeWordStatus = .unavailable
            log(.warning, "Wakeword speech recognizer is unavailable for \(locale.identifier)")
            return
        }
        do {
            #if os(iOS)
            try await configureDJConnectAudioSession(
                category: .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, Self.bluetoothAudioSessionOption, .duckOthers]
            )
            try await setDJConnectAudioSessionActive(true, options: .notifyOthersOnDeactivation)
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

    private func beginVoiceRecording() async {
        #if canImport(AVFoundation)
        do {
            #if os(iOS)
            try await configureDJConnectAudioSession(
                category: .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, Self.bluetoothAudioSessionOption]
            )
            try await setDJConnectAudioSessionActive(true)
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
        voiceErrorMessage = localized(key: "appModel.voice.recording.is.not.available.on.this.platform")
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

    private func playMoodHaptic(stepIndex: Int) {
        #if canImport(UIKit) && os(iOS)
        switch stepIndex {
        case 0:
            UISelectionFeedbackGenerator().selectionChanged()
        case 1:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case 2:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        default:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1.0)
        }
        #elseif canImport(AppKit) && os(macOS)
        let performer = NSHapticFeedbackManager.defaultPerformer
        switch stepIndex {
        case 0:
            performer.perform(.alignment, performanceTime: .now)
        case 1:
            performer.perform(.levelChange, performanceTime: .now)
        case 2:
            performer.perform(.generic, performanceTime: .now)
        default:
            performer.perform(.generic, performanceTime: .now)
            performer.perform(.levelChange, performanceTime: .now)
        }
        #else
        _ = stepIndex
        #endif
    }

    private func playPlaybackToggleHaptic(isStarting: Bool) {
        #if canImport(UIKit) && os(iOS)
        if isStarting {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        #elseif canImport(AppKit) && os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(isStarting ? .levelChange : .alignment, performanceTime: .now)
        #else
        _ = isStarting
        #endif
    }

    private func playQueueItemStartHaptic() {
        #if canImport(UIKit) && os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #elseif canImport(AppKit) && os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }

    private func playPlaylistStartHaptic() {
        #if canImport(UIKit) && os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #elseif canImport(AppKit) && os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        #endif
    }

    private func playMusicDiscoveryStartHaptic() {
        #if canImport(UIKit) && os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #elseif canImport(AppKit) && os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        #endif
    }

    private func playAskDJSendHaptic() {
        #if canImport(UIKit) && os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #elseif canImport(AppKit) && os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }

    private func playAskDJActionHaptic() {
        #if canImport(UIKit) && os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #elseif canImport(AppKit) && os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }

    private func playAskDJResponseHaptic() {
        #if canImport(UIKit) && os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #elseif canImport(AppKit) && os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
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

    nonisolated static func publicReleaseManifestURL(clientType: DJConnectClientType) -> URL? {
        URL(string: "https://djconnect.dev/release-notes/\(clientType.rawValue)/latest.json")
    }

    nonisolated static func publicReleaseManifestURL(clientType: DJConnectClientType, language: String) -> URL? {
        let normalizedLanguage = normalizedReleaseNotesLanguageCode(language)
        return URL(string: "https://djconnect.dev/release-notes/\(clientType.rawValue)/\(normalizedLanguage)/latest.json")
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
        case .windows:
            URL(string: "https://djconnect.dev/windows#downloads")
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
        let deviceName = iosIdentityDeviceName()
        return DJConnectIdentity(
            clientName: deviceName,
            deviceID: "djconnect-ios-\(installID.prefix(12))",
            deviceName: deviceName,
            clientType: .ios,
            firmware: protocolVersion,
            appVersion: protocolVersion,
            platform: .ios
        )
        #endif
    }

    #if os(iOS)
    private static func iosIdentityDeviceName() -> String {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            return "DJConnect iPad"
        case .phone:
            return "DJConnect iPhone"
        default:
            return "DJConnect iOS"
        }
    }
    #endif

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
