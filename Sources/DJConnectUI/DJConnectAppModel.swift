import Combine
import CryptoKit
import DJConnectCore
import Foundation
import ImageIO
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
    case off
    case debug
    case info
    case warning
    case error

    var priority: Int {
        switch self {
        case .off:
            Int.max
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
        DJConnectAppLogLevel(rawValue: rawValue.lowercased()) ?? .off
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

public typealias DJConnectWebSocketFastPathFactory = @Sendable (
    _ baseURL: URL,
    _ localURL: URL?,
    _ configuration: DJConnectTransportConfiguration
) -> (any DJConnectWebSocketFastPathTransport)?

public enum DJConnectPermissionExplanationKind: Equatable, Sendable {
    case notifications
    case microphone
}

private enum DJConnectPendingPermissionRequest {
    case appPermissions
    case voiceRecording
}

public enum DJConnectHomeScreenAction: String, Equatable, Sendable {
    case djSession = "dev.djconnect.action.dj-session"
    case nowPlaying = "dev.djconnect.action.now-playing"
    case queue = "dev.djconnect.action.queue"
    case askDJ = "dev.djconnect.action.ask-dj"
    case trackInsight = "dev.djconnect.action.track-insight"
    case discovery = "dev.djconnect.action.discovery"
    case playlists = "dev.djconnect.action.playlists"
    case about = "dev.djconnect.action.about"

    public init?(deepLinkURL url: URL) {
        guard url.scheme?.lowercased() == "djconnect" else {
            return nil
        }
        let host = url.host?.lowercased()
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let target = path.isEmpty ? host : path
        switch target {
        case "dj-session":
            self = .djSession
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
    public var systemImage: String? = nil
    public var displayDuration: Duration = .seconds(2)
}

public struct DJConnectVisualNotice: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public var text: String
    public var systemImage: String
}

/// One user-triggered refresh per screen, independent of the SwiftUI gesture task.
@MainActor
final class DJConnectManualRefreshController: ObservableObject {
    @Published private(set) var notice: DJConnectVisualNotice?
    @Published private(set) var isRefreshing = false
    private var task: Task<Void, Never>?
    private var dismissal: Task<Void, Never>?

    func run(model: DJConnectAppModel, systemImage: String,
             isBusy: @escaping @MainActor () -> Bool = { false },
             operation: @escaping @MainActor () async -> String?) async {
        let epoch = model.sessionHistory.responseEpoch
        await run(language: model.language, systemImage: systemImage,
                  isCurrent: { model.sessionHistory.responseEpoch == epoch },
                  isBusy: isBusy, operation: operation)
    }

    func run(language: String, systemImage: String,
             isCurrent: @escaping @MainActor () -> Bool = { true },
             isBusy: @escaping @MainActor () -> Bool = { false },
             operation: @escaping @MainActor () async -> String?) async {
        if let task { await task.value; return }
        let pending = Task { @MainActor in
            dismissal?.cancel()
            isRefreshing = true
            defer { isRefreshing = false }
            notice = DJConnectVisualNotice(text: DJConnectLocalization.localized(key: "ui.refresh.loading", language: language), systemImage: systemImage)
            while isBusy() {
                guard isCurrent() else { notice = nil; return }
                try? await Task.sleep(for: .milliseconds(25))
            }
            guard isCurrent() else { notice = nil; return }
            let result = await operation()
            guard isCurrent(), let result else { notice = nil; return }
            let completed = DJConnectVisualNotice(text: result, systemImage: systemImage)
            notice = completed
            dismissal = Task { @MainActor in
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                if notice?.id == completed.id { notice = nil }
            }
        }
        task = pending
        await pending.value
        task = nil
    }
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
    public var announcement: DJAnnouncement?
    public var status: DJConnectAskDJMessageStatus?
    public var createdAt: Date
    public var intentInfo: DJConnectAskDJIntentInfo?
    public var trackInsight: TrackInsight?
    public var items: [DJConnectAskDJHistoryItem]
    public var sessionSpeech: DJConnectSessionSpeech? = nil

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
        announcement: DJAnnouncement? = nil,
        status: DJConnectAskDJMessageStatus? = nil,
        createdAt: Date = Date(),
        intentInfo: DJConnectAskDJIntentInfo? = nil,
        trackInsight: TrackInsight? = nil,
        items: [DJConnectAskDJHistoryItem] = [],
        sessionSpeech: DJConnectSessionSpeech? = nil
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
        self.announcement = announcement
        self.audioURL = announcement == nil ? audioURL : announcement?.clientReplayAudioURL
        self.status = status
        self.createdAt = createdAt
        self.intentInfo = intentInfo
        self.trackInsight = trackInsight
        self.items = items
        self.sessionSpeech = sessionSpeech
    }

    public var renderablePlaybackActions: [DJConnectAskDJPlaybackAction] {
        playbackActions
    }

    /// Match only an explicit server action; a history URI alone grants no playback.
    func playbackAction(forHistoryItem item: DJConnectAskDJHistoryItem) -> DJConnectAskDJPlaybackAction? {
        guard let uri = item.uri, !uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              item.kind?.lowercased() == "track" else { return nil }
        let matches = renderablePlaybackActions.filter {
            $0.kind?.lowercased() == "track" && $0.uri == uri && $0.hasConsistentResultIdentity
        }
        return matches.count == 1 ? matches.first : nil
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
        case announcement
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
        announcement = try container.decodeIfPresent(DJAnnouncement.self, forKey: .announcement)
        if let announcement {
            audioURL = announcement.clientReplayAudioURL
        }
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
        try container.encodeIfPresent(announcement, forKey: .announcement)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(intentInfo, forKey: .intentInfo)
        try container.encodeIfPresent(trackInsight, forKey: .trackInsight)
        try container.encode(items, forKey: .items)
    }

}

/// Only startup delivery metadata is buffered, never notification prose or secrets.
/// Tokens/errors are RAM-only and latest-wins; known event kinds bound the queue.
@MainActor
public struct DJConnectPushStartupBuffer {
    public struct Delivery {
        public let eventType: String
        public var openedFromTap: Bool
        public var userInfo: [AnyHashable: Any] { ["event_type": eventType] }
    }
    public struct Batch {
        public let token: Data?
        public let error: Error?
        public let deliveries: [Delivery]
    }
    private var token: Data?
    private var error: Error?
    private var deliveries: [Delivery] = []
    public init() {}
    public mutating func received(token: Data) {
        guard !token.isEmpty else { return }
        self.token = token; error = nil
    }
    public mutating func failed(_ error: Error) { self.error = error; token = nil }
    @discardableResult
    public mutating func enqueue(_ userInfo: [AnyHashable: Any], openedFromTap: Bool = false) -> Bool {
        let nested = userInfo["data"] as? [String: Any]
        let kind = userInfo["event_type"] as? String ?? userInfo["eventType"] as? String
            ?? nested?["event_type"] as? String ?? nested?["eventType"] as? String
            ?? (openedFromTap ? "ask_dj_response" : "")
        guard ["ask_dj_response", "ask_dj_confirm", "music_discovery_ready"].contains(kind) else { return false }
        let old = deliveries.firstIndex { $0.eventType == kind }
        let tapped = openedFromTap || old.map { deliveries[$0].openedFromTap } == true
        if let old { deliveries.remove(at: old) }
        deliveries.append(Delivery(eventType: kind, openedFromTap: tapped))
        return true
    }
    public mutating func drain() -> Batch {
        let batch = Batch(token: token, error: error, deliveries: deliveries)
        token = nil; error = nil; deliveries.removeAll()
        return batch
    }
}

@MainActor
public struct DJConnectPushNotificationStatus: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case registered
        case unavailable
        case actionNeeded
        case inactive
    }

    public var state: State
    public var environment: DJConnectPushEnvironment?
    public var lastError: String?

    public enum FailureKind: Equatable, Sendable { case configuration, environment, apns, transport, other }
    public var failureKind: FailureKind {
        let error = lastError?.lowercased() ?? ""
        if error.contains("bootstrap") || error.contains("issuer") { return .configuration }
        if error.contains("environment") { return .environment }
        if error.contains("apns_registration") { return .apns }
        if error.contains("network") || error.contains("route_unavailable") { return .transport }
        return .other
    }
    public var titleKey: String {
        switch state {
        case .registered: "ui.registered"
        case .unavailable: "ui.not.supported"
        case .inactive: "ui.not.active"
        case .actionNeeded: failureKind == .configuration ? "ui.push.configuration_needed" : "ui.push.registration_failed"
        }
    }
    public var explanationKey: String {
        if state == .registered { return "ui.push.registration_confirmed_detail" }
        if state == .inactive { return "ui.push.registration_pending_detail" }
        switch failureKind {
        case .configuration: return "ui.push.configuration_detail"
        case .environment: return "ui.push.environment_detail"
        case .apns: return "ui.push.apns_detail"
        case .transport: return "ui.push.transport_detail"
        case .other: return "ui.push.registration_pending_detail"
        }
    }

    public init(
        state: State = .inactive,
        environment: DJConnectPushEnvironment? = nil,
        lastError: String? = nil
    ) {
        self.state = state
        self.environment = environment
        self.lastError = lastError
    }
}

public enum DJConnectActivePresenceCapabilityStatus: Equatable, Sendable {
    case notLoaded, loading, supported, unsupported, temporarilyUnavailable, incompatibleResponse
}

/// Ephemeral hardware presentation. Never stored in a Profile or sent to HA.
struct DJConnectLocalAudioRoute: Equatable, Sendable {
    var localDeviceName = ""
    var bluetoothPortNames: [String] = []
    var hasOtherOutputs = false

    var bluetoothName: String? {
        let names = bluetoothPortNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !hasOtherOutputs, !names.isEmpty, names.allSatisfy({ !$0.isEmpty }),
              Set(names).count == 1 else { return nil }
        return names.first
    }
}

@MainActor
public final class DJConnectAppModel: ObservableObject {
    public lazy var sessionHistory = DJConnectSessionHistoryModel(host: self)
    public let passiveSurfaces = PassiveSessionSurfaceModel()
    private var passiveSurfaceObservation: AnyCancellable?
    public let profileDJSettings = ProfileDJSettingsModel()
    private let profileDJChoiceScheduler = ProfileDJChoiceScheduler()
    @Published public private(set) var isSchedulingProfileDJChoice = false
    let personaReactions = PersonaReactionController()
    @Published private(set) var personaReactionNotice: DJConnectVisualNotice?
    var personaAvatarFrame: CGRect = .zero
    @Published private(set) var activePersonaReactionAvailable = false
    private var personaReactionObservation: AnyCancellable?
    private var personaReactionNoticeTask: Task<Void, Never>?
    private var personaReactionScope: PersonaObservationScope?
    private var personaReactionOutputReserved = false
    private var personaReactionInterruptedWake = false
    #if canImport(AVFoundation)
    private lazy var personaReactionRenderer = DJConnectAppleSpeechRenderer()
    private var personaReactionPlayer: AVAudioPlayer?
    #if os(iOS)
    private var personaReactionOwnsAudioSession = false
    #endif
    #endif
    private var profileDJSettingsObservation: AnyCancellable?
    private var localAudioRouteObservation: AnyCancellable?
    private var personaReactionInterruption: AnyCancellable?
    @Published var localAudioRoute = DJConnectLocalAudioRoute()
    private var profileDJSettingsReadInProgress = false
    private var profileSettingsOwnerFence = DJConnectProfileSettingsOwnerFence()
    @Published public private(set) var sharedSpeechReference: DJConnectSpeechReference?
    @Published public private(set) var sharedSpeechDelivery: [String: String] = [:]
    @Published public private(set) var sharedSpeechIsPlaying = false
    @Published public private(set) var sharedSpeechIsPreparing = false

    private var profileConversationClearRevision = 0
    private var profileConversationHistoryRevision = 0
    private var voiceOperationGeneration = UUID()
    var voiceOperationID: UUID { voiceOperationGeneration }
    public var canRefreshSessionHistory: Bool { isAppInForeground && pairingStatus == .paired && !isDemoMode }
    public var canUseProfileConversation: Bool {
        sessionHistory.available && sessionHistory.profileScopeActive && sessionHistory.hasAuthorizedOwner &&
        canRefreshSessionHistory && isRuntimeCompatible && haConnectionMode != .offline
    }
    public var canUseAskDJFeatures: Bool {
        sessionHistory.profileScopeActive ? canUseProfileConversation : canUsePlaybackFeatures
    }
    @Published public var homeAssistantURL = "" {
        didSet { defaults.set(homeAssistantURL, forKey: homeAssistantURLKey) }
    }
    @Published public private(set) var haLocalURL = ""
    @Published public private(set) var haRemoteURL = ""
    @Published public private(set) var haConnectionMode: DJConnectHAConnectionMode = .offline
    @Published public private(set) var pushNotificationStatus = DJConnectPushNotificationStatus()
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
    @Published public private(set) var djAnnouncementCapabilities = DJAnnouncementCapabilities()
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
                refreshWebSocketFastPathStatus()
            } else if pairingStatus != .paired {
                passiveSurfaces.bind(owner: nil, sessionID: nil, foreground: false)
                stopResponsePlayback(clearText: false)
                if let old = hybridTransport { Task { await old.lifecycle(foreground: false) } }
                pairedIdentityRecoveryTask?.cancel(); pairedIdentityRecoveryTask = nil
                pairedIdentityRecoveryGeneration = UUID()
                hybridTransport = nil; hybridTransportKey = nil
                hybridConnectionDiagnostics = nil
                authenticatedStatusOrigin = nil
                invalidateSessionRequest()
                activeDJSession = nil
                stopSessionBroadcast()
                nowPlayingPollTask?.cancel()
                nowPlayingPollTask = nil
                refreshScheduler.cancelPairedRefresh()
                stopWakeWordListening()
                webSocketFastPathCache.removeAll()
                fastPathDiagnostics = DJConnectFastPathDiagnostics()
            }
            updateWakeWordListeningForAvailability()
        }
    }
    @Published public var isConnected = false {
        didSet { updateWakeWordListeningForAvailability() }
    }
    @Published public var isPairing = false
    private var manualRefreshTask: Task<Bool, Never>?
    @Published public var isRefreshing = false
    @Published public private(set) var isLoadingOutputs = false
    @Published public private(set) var pendingOutputSelectionID: String?
    @Published public private(set) var isLoadingQueue = false
    @Published public private(set) var isLoadingPlaylists = false
    @Published public var backendAvailable = true {
        didSet {
            if backendAvailable {
                refreshScheduler.cancelBackendRecovery()
            }
            updateWakeWordListeningForAvailability()
        }
    }
    @Published public var updateRequiredMessage: String?
    @Published public var pairingMessage: String?
    @Published public var userNotice: DJConnectUserNotice?
    @Published public var playback: DJConnectPlayback? { didSet { syncDemoSessionPlayback() } }
    @Published public private(set) var activeDJSession: DJConnectSessionRuntime? {
        didSet {
            if oldValue?.id != activeDJSession?.id ||
                (oldValue?.runtimeState == "active" && activeDJSession?.runtimeState != "active") {
                stopResponsePlayback(clearText: false)
                resetActivePersonaState()
                discardActiveVoicePreference()
            }
            if oldValue?.id != activeDJSession?.id {
                sessionSurfaceIdentity = nil
                sessionSurfaceSnapshot = nil
            }
            reconcileMomentTrackInsight()
            if oldValue?.id != activeDJSession?.id {
                resetActiveMoodState()
                invalidateSessionPlaybackActions()
                sessionHistory.discardLiveResponses()
            }
            syncSessionSurfaces(observedSession: true)
            observeSessionSpeechAutoplay()
        }
    }
    @Published public private(set) var activeVoicePreference = DJConnectSpeechVoicePreferenceState()
    @Published public private(set) var activeVoiceError: String?
    private var activeVoiceMenuOpen = false
    private var activeVoiceRetryAfter: Date?

    private var personaOperationGeneration = UUID()
    @Published public private(set) var activePersonaAvailable = false
    @Published public private(set) var activePersonaPending = false
    @Published public private(set) var activePersonaError: String?
    private var moodOperationGeneration = UUID()
    private var moodCapabilityGeneration = UUID()
    @Published public private(set) var activeMoodAvailable = false
    @Published public private(set) var activeMoodPending = false
    @Published public private(set) var activeMoodError: String?
    @Published public private(set) var activePresenceAvailable = false
    @Published public private(set) var activePresenceCapabilityStatus: DJConnectActivePresenceCapabilityStatus = .notLoaded
    @Published public private(set) var activePresenceDesired: DJConnectSessionPresenceValue?
    @Published public private(set) var activePresencePending = false
    @Published public private(set) var activePresenceRequiresDecision = false
    @Published public private(set) var activePresenceError: String?
    private var presenceTask: Task<Void, Never>?
    private var presenceGeneration = UUID()
    private var presenceIntent = UUID()
    private var activeSharedSettingsRequired = false
    @Published private var demoSessionMood = "groove"
    public var selectedSessionMood: String {
        get { isDemoMode ? demoSessionMood : profileDJSettings.response?.snapshot.defaults.mood ?? "groove" }
        set {
            if isDemoMode { demoSessionMood = newValue }
            else { scheduleProfileDJChoice(.init(mood: newValue)) }
        }
    }
    @Published public private(set) var isLoadingDJSession = false
    @Published public private(set) var isSessionIntroductionPresented = false
    @Published public private(set) var djSessionErrorMessage: String?
    @Published public private(set) var djSessionIsRecovering = false
    private var sessionRecoveryCursor: String?
    private var sessionRecoveryCursorSessionID: String?
    @Published public private(set) var hybridConnectionDiagnostics: DJConnectHybridDiagnostics?
    /// Origin of a successful, authority-checked status response in this foreground.
    @Published public private(set) var authenticatedStatusOrigin: URL?
    private var lastHybridRouteState: DJConnectHybridDiagnostics.State?
    @Published public private(set) var djSessionLiveUnavailable = false
    @Published public private(set) var isLoadingVibeCastHandoff = false
    @Published public private(set) var vibeCastHandoffApproved = false
    @Published public private(set) var vibeCastHandoffFailed = false
    @Published public private(set) var vibeCastHandoffErrorKey: String?
    private var vibeCastHandoffGeneration = UUID()
    @Published public private(set) var momentTrackInsightTarget: DJConnectMomentInsightReference?
    @Published public private(set) var momentTrackInsight: TrackInsight?
    @Published public private(set) var momentTrackInsightErrorMessage: String?
    @Published public private(set) var isLoadingMomentTrackInsight = false
    private var momentInsightGeneration = UUID()
    private var momentInsightDeadline: Date?
    private var momentInsightStyle = ""
    private var momentInsightMediaIdentity: String?
    private var momentInsightRetryAllowed = true
    private var momentInsightTask: Task<Void, Never>?
    private var momentInsightExpiryTask: Task<Void, Never>?

    @Published public private(set) var currentTrackInsight: TrackInsight?
    @Published public private(set) var trackInsightHistory: [TrackInsight] = []
    @Published public private(set) var isLoadingTrackInsight = false
    @Published public private(set) var trackInsightErrorMessage: String?
    @Published public private(set) var vibeCastResponse: DJConnectVibeCastResponse?
    @Published public private(set) var vibeCastItems: [DJConnectVibeCastResponse.Item] = []
    @Published public private(set) var vibeCastDisabledReason: String?
    @Published public private(set) var isVibeCastStreamingActive = false
    @Published public private(set) var musicDNAProfileResponse: DJConnectMusicDNAProfileResponse?
    private var musicDNARefreshGeneration = UUID()
    @Published public private(set) var musicDNAProfileNeedsRecovery = false
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
    @Published public private(set) var supportsMusicDiscoveryFeedback = false
    private var pendingMusicDNAEnabled: Bool?
    private var pendingMusicDNAEnabledAt: Date?
    private var resolvedMusicDNAKey: String?
    #if DEBUG
    public private(set) var isMusicDNAPreviewMode = false
    #endif
    @Published public var autoTrackInsightEnabled = false {
        didSet { defaults.set(autoTrackInsightEnabled, forKey: autoTrackInsightEnabledKey) }
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
    /// Playback response authority only; pending selections and normalized output lists are excluded.
    var sessionPlaybackOutputName: String? {
        guard activeDJSession?.runtimeState == "active", !djSessionIsRecovering,
              !djSessionLiveUnavailable, isDemoMode || (isConnected && backendAvailable),
              let device = playback?.device, device.active != false, device.cached != true,
              device.id != Self.syntheticNoOutputID,
              let name = device.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
        return currentPlaybackBluetoothDeviceName ?? name
    }

    var currentPlaybackOutputDisplayName: String? {
        guard let device = playback?.device, device.active != false, device.cached != true else { return nil }
        return currentPlaybackBluetoothDeviceName ?? device.name
    }
    @Published public var djResponseText = ""
    @Published public private(set) var askDJMessages: [DJConnectAskDJMessage] = []
    @Published public private(set) var askDJScrollRequestID: UUID?
    private var composerDraft = ""
    public private(set) var askDJDraftRevision = 0
    public var askDJDraft: String {
        get { composerDraft }
        set {
            guard composerDraft != newValue else { return }
            objectWillChange.send()
            composerDraft = newValue
            askDJDraftRevision &+= 1
        }
    }

    /// Native editors own ordinary character updates; app actions still publish draft replacement.
    public func setAskDJDraftFromEditor(_ value: String) {
        guard composerDraft != value else { return }
        let wasEmpty = composerDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isEmpty = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if wasEmpty != isEmpty { objectWillChange.send() }
        composerDraft = value
    }
    @Published public private(set) var isSendingAskDJText = false
    @Published public private(set) var isRequestingAskDJIdleSuggestion = false
    @Published public private(set) var playingAskDJActionID: String?
    private var askDJPlayOperation = UUID()
    private var askDJPlayIsSessionScoped = false
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
    @Published public var logLevel = "off" {
        didSet {
            defaults.set(logLevel, forKey: logLevelKey)
            log(.info, "Log level changed to \(logLevel)")
        }
    }
    public var isDiagnosticLoggingEnabled: Bool {
        DJConnectAppLogLevel.parse(logLevel) != .off
    }
    @Published public var language = "en"
    @Published public private(set) var appLanguageOverrideCode = ""
    @Published private var deviceSpeechAvailability: DJConnectDeviceSpeechAvailability?
    private var deviceSpeechContext: [String] = []
    private var currentDeviceSpeechContext: [String] {
        [haLocalURL, haRemoteURL, defaults.string(forKey: haInstallIDKey) ?? "",
         (try? tokenStore.loadToken()) ?? "", sessionHistory.authorizedProfileID ?? "",
         currentRequestLocale]
    }
    private var currentDeviceSpeechAvailability: DJConnectDeviceSpeechAvailability? {
        guard !isDemoMode, pairingStatus == .paired, isAppInForeground,
              deviceSpeechContext == currentDeviceSpeechContext else { return nil }
        return deviceSpeechAvailability
    }
    public var canUseVoiceInputRoute: Bool {
        voiceEnabled && (isRecordingVoice || isDemoMode || deviceSTTEnabled ||
            currentDeviceSpeechAvailability?.allowsHAInput(locale: currentRequestLocale) == true)
    }
    public var canUseLocalDJSpeechOutput: Bool {
        deviceSpeechPreferences.enabled || canUseHASpeechOutput(.local)
    }

    public func canUseHASpeechOutput(_ target: DJConnectSharedSpeechTarget) -> Bool {
        isDemoMode || currentDeviceSpeechAvailability?.allowsHAOutput(target, locale: currentRequestLocale) == true
    }

    @Published public var voiceEnabled = true {
        didSet { updateWakeWordListeningForAvailability() }
    }
    @Published public var deviceSpeechPreferences = DJConnectDeviceSpeechPreferences() {
        didSet {
            guard deviceSpeechPreferences != oldValue else { return }
            guard deviceSpeechPreferences.isValid else { deviceSpeechPreferences = oldValue; return }
            deviceSpeechPreferences.save(to: defaults)
            stopResponsePlayback(clearText: false)
        }
    }
    /// Installation-local input preference, never sent to a Profile or shared defaults.
    @Published public var deviceSTTEnabled = false {
        didSet {
            guard deviceSTTEnabled != oldValue else { return }
            stopWakeWordListening()
            cancelVoiceRecording()
            defaults.set(deviceSTTEnabled, forKey: "DJConnectDeviceSTTEnabled.v1")
            if startBackgroundTasks && !deviceSTTEnabled {
                Task { await refreshHAInputAvailabilityIfNeeded() }
            }
            resumeWakeWordListeningIfNeeded()
        }
    }
    @Published public private(set) var deviceSpeechPreviewIsPlaying = false
    @Published public var localResponseAudioEnabled = false {
        didSet {
            guard oldValue != localResponseAudioEnabled else {
                return
            }
            if !localResponseAudioEnabled { stopResponsePlayback(clearText: false) }
            // Enabling autoplay applies to future contributions, never a backlog.
            observeSessionSpeechAutoplay()
            defaults.set(localResponseAudioEnabled, forKey: localResponseAudioEnabledKey)
            log(.info, "Ask DJ response audio auto play \(localResponseAudioEnabled ? "enabled" : "disabled")")
        }
    }
    @Published public var djAnnouncementOutput: DJAnnouncementOutput = .clientDevice {
        didSet {
            guard oldValue != djAnnouncementOutput else {
                return
            }
            if !isDJAnnouncementOutputSelectable(djAnnouncementOutput) {
                djAnnouncementOutput = oldValue
                return
            }
            defaults.set(djAnnouncementOutput.rawValue, forKey: djAnnouncementOutputKey)
        }
    }
    @Published public var isDemoMode = false
    @Published public private(set) var isMonkeyTestingMode = false
    @Published public private(set) var isUITestRuntimeFixtureActive = false
    @Published public private(set) var uiTestRuntimeFixtureScenario: String?
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
    @Published public var isShowingVibeCastSessionStart = false
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
    private var pairedIdentityRecoveryTask: Task<Void, Never>?
    private var pairedIdentityRecoveryGeneration = UUID()
    private var pairingTask: Task<Void, Never>?
    private var pairingTaskGeneration = UUID()
    private var scheduledPairingTask: Task<Void, Never>?
    private var volumeCommandTask: Task<Void, Never>?
    private var playbackProgressTask: Task<Void, Never>?
    private var nowPlayingPollTask: Task<Void, Never>?
    private let refreshScheduler = DJConnectRefreshScheduler()
    private let permissionCoordinator = DJConnectPermissionCoordinator()
    private var openPermissionSettingsTask: Task<Void, Never>?
    private var outputSelectionGeneration = 0
    private var playbackOutputObservation = 0
    private struct LiveConversationPresentation {
        let epoch: UUID
        let deadline: Date?
        let message: DJConnectAskDJMessage
        let isPrivateEphemeral: Bool
        let questionID: UUID?
        let sessionID: String?
    }
    private struct ConversationResultLease {
        let epoch: UUID
        let deadline: Date
    }
    private var conversationResultLeases: [String: ConversationResultLease] = [:]
    private var conversationResultLeaseOrder: [String] = []
    // Ephemeral renderer observations. Never persisted or exported to passive surfaces.
    private struct PersonaObservationScope: Equatable {
        let sessionID: String
        let epoch: UUID
        let connection: UUID
        let settingsBinding: String
    }
    private struct PersonaSpeechObservation {
        let scope: PersonaObservationScope
        let reference: DJConnectSpeechReference
        let deadline: Date
    }
    private var personaRequestScope: PersonaObservationScope?
    private var personaVoiceScope: PersonaObservationScope?
    private var personaSpeechObservation: PersonaSpeechObservation?
    private var personaReplyScope: PersonaObservationScope?
    private var personaReplyMomentID: String?
    private var personaReplySilenceMomentID: String?
    private var liveConversationPresentations: [String: LiveConversationPresentation] = [:]
    private var liveConversationExpiryTask: Task<Void, Never>?
    private var pendingSelectedOutput: String?
    private var pendingSelectedOutputIsCachedSpotify = false
    private var pendingVolumePercent: Int?
    private var pendingSeekTargetMS: Int?
    private var seekCommandTask: Task<Void, Never>?
    private var isAppInForeground = true
    private var speechAutoplayAdmission = SessionSpeechAutoplayAdmission()
    private var automaticSpeechQueue: [(speech: DJConnectSessionSpeech, text: String, epoch: UUID)] = []
    private var automaticSpeechClaims = Set<DJConnectSpeechReference>()
    private var automaticSpeechTask: Task<Void, Never>?
    private var automaticSpeechGeneration = UUID()
    private var automaticSpeechOwner: UUID?
    private var lastFullRefreshAt: Date?
    private var lastBackendCollectionsRefreshAt: Date?
    private var lastBackendUnavailableNoticeAt: Date?
    private var sessionSurfaceSnapshot: DJConnectSessionSurfaceSnapshot?
    private var lastSessionWidgetReloadAt: Date?
    private var lastPublishedPassiveRevision: UUID?
    private var lastPublishedWidgetRich: DJConnectPassiveSurfaceCache?
    private var sessionSurfaceIdentity: String?
    private var sessionSurfaceGeneration = UUID()
    private var sessionSurfaceActivityTask: Task<Void, Never>?
    private var sessionSurfaceExpiryTask: Task<Void, Never>?
    private var sessionSurfaceBinding: String?
    private var automaticPassiveTask: Task<Void, Never>?
    private var automaticPassiveTaskID = UUID()
    private var automaticPassiveContext: String?
    private var lastAutomaticPassiveQueryAt: Date?
    private var lastActivitySurfaceSnapshot: DJConnectSessionSurfaceSnapshot?
    private var lastActivitySurfaceIdentity: String?
    private var hasSyncedSessionSurfaceActivity = false
    private var hasObservedSessionSurfaceAuthority = false
    #if os(iOS) && canImport(WatchConnectivity)
    @Published private var watchProxyRegistration: DJConnectWatchProxyRegistration?
    private var watchProxySessionDelegate: DJConnectWatchProxySessionDelegate?
    private var pendingWatchProxyPairingPayload: DJConnectPairingDeepLink?
    #endif
    private let networkMonitor = NWPathMonitor()
    private let networkMonitorQueue = DispatchQueue(label: "dev.djconnect.app.network")
    private var shouldShowWakeWordPromptAfterPairingScreen = false
    private var currentAPNsPushToken: String?
    private var remoteNotificationRegistrationRequestedThisLaunch = false
    private var pushRegistrationInFlightSignature: String?
    private var pushRegistrationAttemptEpoch: UUID?
    private var discoveryArtworkRenewalTask: Task<Void, Never>?
    private var retriedExpiredDiscoveryArtwork = false
    private var discoveryResponseGeneration = UUID()
    private var discoveryLoadGeneration = UUID()
    private var discoveryRefreshGeneration = UUID()
    private var manualDiscoveryRefreshTask: Task<Bool, Never>?
    private var musicDiscoveryPushRefreshes: [String: Date] = [:]
    private var webSocketFastPathCache: [String: any DJConnectWebSocketFastPathTransport] = [:]
    private var sessionBroadcastTransport: DJConnectSessionBroadcastTransport?
    private var hybridTransport: DJConnectHybridTransport?
    private var hybridTransportKey: String?
    private var localTransportProbeAfter: Date?
    private var sessionBroadcastGeneration = UUID()
    private var sessionContributionRecoveryNeeded = true
    private var sessionContributionRecoveryTask: Task<Void, Never>?
    private var sessionBroadcastSessionID: String?
    private var sessionRequestGeneration = UUID()
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
    private lazy var responsePlaybackCoordinator = DJConnectAudioPlaybackCoordinator { [weak self] in
        self?.clearResponsePlaybackOutput()
    }
    private var responseAudioPlayer: AVPlayer?
    private var sharedResponseDataPlayer: AVAudioPlayer?
    private var responseAudioPlaybackTask: Task<Void, Never>?
    private var responseSpeechSynthesizer: AVSpeechSynthesizer?
    private lazy var deviceSpeechRenderer = DJConnectAppleSpeechRenderer()
    #endif
    #if canImport(Speech) && canImport(AVFoundation)
    private lazy var deviceSTTTranscriber = DJConnectAppleSpeechTranscriber()
    private var deviceSTTTask: Task<Void, Never>?
    private var voiceUsesDeviceSTT = false
    private var voiceSTTContext: DJConnectConversationContext?
    private var voiceSTTDraft = ""
    private var voiceSTTLanguage = ""
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
    private let trustedPairingIssuerBaseURL: URL?
    private let homeAssistantWebSocketAuth: DJConnectHomeAssistantWebSocketAuth?
    private let webSocketFastPathFactory: DJConnectWebSocketFastPathFactory
    private let startBackgroundTasks: Bool
    private let monkeyTestingMode: Bool
    private let diagnosticLogFileURL: URL?
    nonisolated private static let protocolVersion = DJConnectProtocolVersion.current
    nonisolated private static let maxWidgetArtworkDataBytes = 750_000
    private static let defaultHomeAssistantURL = "http://homeassistant.local:8123"
    private let appVersion = DJConnectApplicationVersion.releaseVersion
    private let buildVersion = DJConnectApplicationVersion.buildVersion
    private let installIDKey = DJConnectAppModel.installIDKey
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
    private let haInstallIDKey = "DJConnectHAInstallID"
    private let integrationVersionKey = "DJConnectIntegrationVersion"
    private let pairingSessionIDKey = "DJConnectPairingSessionID"
    private let pairingTokenKey = "DJConnectPairingToken"
    private let pendingHomeAssistantSetupKey = "DJConnectHomeAssistantSetupPending"
    private let watchProxyDeviceIDKey = "DJConnectWatchProxyDeviceID"
    private let watchProxyDeviceNameKey = "DJConnectWatchProxyDeviceName"
    private let watchProxyPairCodeKey = "DJConnectWatchProxyPairCode"
    private let watchProxyFirmwareKey = "DJConnectWatchProxyFirmware"
    private let watchProxyAppVersionKey = "DJConnectWatchProxyAppVersion"
    private let watchProxyProtocolVersionKey = "DJConnectWatchProxyProtocolVersion"
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
    private let localResponseAudioEnabledKey = "DJConnectLocalResponseAudioEnabled"
    private let djAnnouncementOutputKey = "DJConnectDJAnnouncementOutput"
    private let autoTrackInsightEnabledKey = "DJConnectAutoTrackInsightEnabled"
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
    private let backendUnavailableNoticeInterval: TimeInterval = 20
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

    @Published private var volumeRejectedOutputKey: String?

    private var volumeOutputKey: String? {
        let device = playback?.device
        guard let id = device?.id ?? device?.name else { return nil }
        return "\(musicBackendSummary.musicBackendRevision ?? 0):\(outputSelectionGeneration):\(id)"
    }

    public var currentPlaybackUsesLocalBluetooth: Bool {
        guard !isDemoMode, isConnected, backendAvailable,
              !localAudioRoute.bluetoothPortNames.isEmpty,
              let device = playback?.device, device.active != false, device.cached != true,
              let id = device.id, let name = device.name else { return false }
        let type = device.type ?? availableOutputs.first { $0.id == id }?.type
        let candidates = Set(availableOutputs.filter {
            $0.cached != true && ["phone", "smartphone", "tablet"].contains($0.type?.lowercased() ?? "") &&
            $0.name.localizedCaseInsensitiveCompare(localAudioRoute.localDeviceName) == .orderedSame
        }.map(\.id))
        guard candidates.isEmpty || candidates == [id] else { return false }
        let localOutput = DJConnectOutputDevice(id: id, name: name, type: type, active: true)
        return localOutput.usesLocalBluetoothRoute(localDeviceName: localAudioRoute.localDeviceName,
            playbackDeviceID: id, hasBluetoothRoute: true)
    }

    var currentPlaybackBluetoothDeviceName: String? {
        currentPlaybackUsesLocalBluetooth ? localAudioRoute.bluetoothName : nil
    }

    func outputUsesLocalBluetooth(_ output: DJConnectOutputDevice) -> Bool {
        currentPlaybackUsesLocalBluetooth && output.cached != true &&
        output.usesLocalBluetoothRoute(localDeviceName: localAudioRoute.localDeviceName,
            playbackDeviceID: playback?.device?.id, hasBluetoothRoute: true)
    }

    func outputDisplayName(_ output: DJConnectOutputDevice) -> String {
        if outputUsesLocalBluetooth(output), let name = currentPlaybackBluetoothDeviceName { return name }
        return output.displayName(language: language)
    }

    private func refreshLocalAudioRoute() {
        #if os(iOS)
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let bluetooth = outputs.filter { [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains($0.portType) }
        let next = DJConnectLocalAudioRoute(localDeviceName: UIDevice.current.name,
            bluetoothPortNames: bluetooth.map(\.portName), hasOtherOutputs: outputs.count != bluetooth.count)
        if localAudioRoute != next { localAudioRoute = next }
        #endif
    }

    public var currentPlaybackVolumePercent: Int? {
        guard canControlPlaybackVolume, playback?.device?.active != false else { return nil }
        return DJConnectVolumeNormalizer.validBackendPercent(playback?.volumePercent)
            ?? DJConnectVolumeNormalizer.validBackendPercent(playback?.device?.volumePercent)
    }

    public var canControlPlaybackVolume: Bool {
        let device = playback?.device
        guard !currentPlaybackUsesLocalBluetooth else { return false }
        let output = availableOutputs.first { output in
            if let id = device?.id { return output.id == id }
            if let name = device?.name { return output.name == name }
            return output.active == true
        }
        guard device?.supportsVolume != false, output?.supportsVolume != false else { return false }
        if let key = volumeOutputKey, key == volumeRejectedOutputKey { return false }
        return device?.supportsVolume == true || output?.supportsVolume == true
            || playback?.volumePercent != nil || device?.volumePercent != nil
    }

    private static func isVolumeControlUnavailable(_ message: String?) -> Bool {
        message?.lowercased().contains("cannot control device volume") == true
    }

    public func outputVolumeLabel(_ output: DJConnectOutputDevice) -> String {
        if output.active == true, output.matchesPlaybackDevice(id: playback?.device?.id, name: playback?.device?.name),
           !canControlPlaybackVolume { return "-" }
        return output.reportedVolumePercent.map { "\($0)%" } ?? "-"
    }

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

    /// Project confirmed server-owned Session mood; omit it when no Session is active.
    public var confirmedSessionMoodInt: Int? {
        guard let mood = activeDJSession?.selectedMood,
              let index = ["chill", "groove", "energy", "party"].firstIndex(of: mood) else { return nil }
        return [0, 35, 70, 100][index]
    }

    /// Neutral presentation outside a Session never reuses the old Ask DJ slider value.
    public var playbackMoodStepIndex: Int {
        guard let mood = confirmedSessionMoodInt else { return 1 }
        return Self.askDJMoodStepIndex(for: Double(mood))
    }

    public var askDJMoodStepIndex: Int {
        if let mood = profileDJSettings.effective?.mood,
           let index = ["chill", "groove", "energy", "party"].firstIndex(of: mood) { return index }
        return Self.askDJMoodStepIndex(for: askDJMood)
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
        if !isDemoMode {
            let moods = ["chill", "groove", "energy", "party"]
            guard moods.indices.contains(index) else { return }
            Task { await changeProfileDJSettings(.init(mood: moods[index])) }
            return
        }
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
        #if DEBUG
        if isUITestRuntimeFixtureActive && uiTestRuntimeFixtureScenario != "review_demo" {
            switch uiTestRuntimeFixtureScenario {
            case "pairing_success", "stale_auth":
                return !isShowingWelcome
                    && !isShowingCrashReportPrompt
                    && !isShowingTokenStorageError
            default:
                return false
            }
        }
        #endif
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
        trustedPairingIssuerBaseURL: URL? = nil,
        homeAssistantWebSocketAuth: DJConnectHomeAssistantWebSocketAuth? = nil,
        webSocketFastPathFactory: @escaping DJConnectWebSocketFastPathFactory = DJConnectFastPathPolicy.makeFastPath,
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
        let hasExistingInstallID = Self.hasExistingInstallID(defaults: defaults)
        if !hasExistingInstallID && !monkeyTestingMode && resolvedTokenStore is DJConnectUserDefaultsTokenStore {
            try? resolvedTokenStore.clearToken()
        }
        self.tokenStore = resolvedTokenStore
        self.urlSession = urlSession
        self.trustedPairingIssuerBaseURL = trustedPairingIssuerBaseURL ?? DJConnectAppModel.defaultTrustedPairingIssuerBaseURL()
        self.identity = Self.makeIdentity(defaults: defaults)
        self.webSocketFastPathFactory = webSocketFastPathFactory
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
        self.pushNotificationStatus = Self.pushNotificationStatus(defaults: defaults)
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
        self.logLevel = DJConnectAppLogLevel.parse(defaults.string(forKey: logLevelKey) ?? "off").rawValue
        self.askDJMood = defaults.object(forKey: askDJMoodKey) == nil ? 50.0 : defaults.double(forKey: askDJMoodKey)
        Self.syncAskDJMoodToSharedDefaults(self.askDJMood)
        self.localResponseAudioEnabled = defaults.bool(forKey: localResponseAudioEnabledKey)
        self.deviceSpeechPreferences = DJConnectDeviceSpeechPreferences.load(from: defaults)
        self.deviceSTTEnabled = defaults.bool(forKey: "DJConnectDeviceSTTEnabled.v1")
        self.djAnnouncementOutput = defaults.string(forKey: djAnnouncementOutputKey).flatMap(DJAnnouncementOutput.init(rawValue:)) ?? .clientDevice
        self.autoTrackInsightEnabled = defaults.bool(forKey: autoTrackInsightEnabledKey)
        self.webSocketFastPathEnabled = false
        defaults.removeObject(forKey: webSocketFastPathEnabledKey)
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
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
        if isUITesting {
            defaults.set(true, forKey: cleanShutdownKey)
            defaults.set(false, forKey: crashPromptPendingKey)
        }
        prepareWhatsNewPrompt()
        let previousLaunchMayHaveCrashed = defaults.object(forKey: cleanShutdownKey) != nil
            && defaults.bool(forKey: cleanShutdownKey) == false
        self.isShowingCrashReportPrompt = !Self.isRunningUnderDebugger
            && (previousLaunchMayHaveCrashed || defaults.bool(forKey: crashPromptPendingKey))
        if monkeyTestingMode || isUITesting {
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
                if startBackgroundTasks, pairingStatus == .paired {
                    schedulePairedRefresh(reason: "Refreshing initial Home Assistant state")
                }
                if !Self.isRunningUnderSwiftPMTests {
                    requestRemoteNotificationRegistration()
                }
            } else if isDemoMode {
                applyDemoState()
                log(.info, "App started in demo mode")
            } else {
                defaults.removeObject(forKey: pendingHomeAssistantSetupKey)
                clearPairingToken()
                log(.info, "App started without DJConnect bearer token for \(identity.clientType.rawValue)")
            }
        } catch {
            applyTokenStorageFailure(error)
        }
        passiveSurfaceObservation = passiveSurfaces.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        passiveSurfaces.onChange = { [weak self] in self?.syncSessionSurfaces() }
        passiveSurfaces.onDiagnostic = { [weak self] event in self?.log(.info, "Passive surface " + event) }
        // Prior-process grants are not authority. Neutralize any old rich cache
        // before a new explicit foreground Session choice can authorize it.
        if startBackgroundTasks, !monkeyTestingMode, !isUITesting,
           let shared = UserDefaults(suiteName: DJConnectLocalization.appGroupIdentifier) {
            for surface in DJConnectPassiveSurface.allCases { try? DJConnectPassiveSurfaceCache.replace(nil, surface: surface, in: shared) }
        }
        profileDJSettingsObservation = profileDJSettings.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
        personaReactionObservation = personaReactions.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        profileDJChoiceScheduler.pendingChanged = { [weak self] in self?.isSchedulingProfileDJChoice = $0 }
        refreshLocalAudioRoute()
        #if os(iOS)
        localAudioRouteObservation = NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] note in
                let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                let physicalChange = raw.map { [AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue,
                    AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue, AVAudioSession.RouteChangeReason.override.rawValue,
                    AVAudioSession.RouteChangeReason.routeConfigurationChange.rawValue,
                    AVAudioSession.RouteChangeReason.noSuitableRouteForCategory.rawValue].contains($0) } == true
                Task { @MainActor [weak self] in
                    if physicalChange { self?.personaReactions.cancel(.speechConflict) }
                    self?.refreshLocalAudioRoute()
                }
            }
        #endif
        #if os(iOS)
        personaReactionInterruption = NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] _ in Task { @MainActor [weak self] in self?.personaReactions.cancel(.speechConflict) } }
        #endif
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
            Task { @MainActor in
                self.isCheckingForUpdates = false
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
                updateNotesBody = updates.reversed().map { update in
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
        guard releaseNotesLanguageCode == "nl" else {
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
                if startBackgroundTasks, pairingStatus == .paired {
                    schedulePairedRefresh(reason: "Refreshing after token storage restore")
                }
            } else {
                isShowingTokenStorageError = false
                defaults.removeObject(forKey: pendingHomeAssistantSetupKey)
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
        if defaults.bool(forKey: pendingHomeAssistantSetupKey) {
            pairingStatus = .waitingForHomeAssistantCompletion
            isConnected = false
            isPairing = false
            pairingMessage = localized(key: "appModel.waiting.for.setup.to.be.completed.in.home.assistant")
            resumePendingHomeAssistantPairingIfNeeded()
            return
        }
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
        cancelVoiceRecording()
        clearSessionProjection()
        sessionHistory.reset()
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
        cancelVoiceRecording()
        clearAskDJHistoryLocally()
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
        endpointStatusRefreshAt = nil
        isAppInForeground = true
        refreshLocalAudioRoute()
        lastAutomaticPassiveQueryAt = nil
        // Resume the coordinator before dependent reads. Repeated active signals
        // must not cancel a route qualification that is already in progress.
        Task {
            if let hybridTransport { await hybridTransport.lifecycle(foreground: true) }
            guard isAppInForeground, !Task.isCancelled else { return }
            await refreshProfileDJSettings()
            guard isAppInForeground, !Task.isCancelled else { return }
            await refreshActiveDJSession()
            if activeDJSession != nil { await refreshActiveMoodCapability() }
            if startBackgroundTasks { await refreshHAInputAvailabilityIfNeeded() }
        }
        // Preserve the failed-LAN cooldown across short interruptions. A real
        // network change clears it and immediately schedules a new status read.
        defaults.set(false, forKey: cleanShutdownKey)
        refreshPermissionStatuses()
        resumeWakeWordListeningIfNeeded()
        updatePlaybackProgressTimer()
        updateNowPlayingPollTimer()
        if let discovery = musicDiscoveryResponse, pairingStatus == .paired, !isDemoMode {
            if discovery.sections.flatMap(\.items).contains(where: { $0.imageURL != nil && ($0.imageExpiresAt.map { $0 <= Date() } ?? false) }) {
                Task { await loadMusicDiscovery(force: true) }
            } else { scheduleDiscoveryArtworkRenewal(discovery) }
        }
        syncTrackInsightLiveActivity(reason: "App became active")
        #if DEBUG
        guard !isUITestRuntimeFixtureActive else {
            return
        }
        #endif
        guard pairingStatus == .paired, !isDemoMode else {
            return
        }
        refreshWebSocketFastPathStatus()
        log(.debug, "App became active; scheduling playback refresh")
        schedulePairedRefresh(
            reason: "Resume Now Playing refresh completed",
            allowThrottle: false,
            refreshCollections: false,
            runFollowUpRefresh: false
        )
    }

    public func markInactiveSession(enteringBackground: Bool = true) {
        personaReactions.cancel(.background)
        isAppInForeground = false
        passiveSurfaces.suspend()
        automaticPassiveTask?.cancel(); automaticPassiveTask = nil
        automaticPassiveTaskID = UUID(); lastAutomaticPassiveQueryAt = nil
        pairedIdentityRecoveryTask?.cancel(); pairedIdentityRecoveryTask = nil
        pairedIdentityRecoveryGeneration = UUID()
        dismissMomentTrackInsight()
        if enteringBackground && !isDemoMode {
            if deviceSTTEnabled || sessionHistory.profileScopeActive { cancelVoiceRecording() }
            if sessionHistory.profileScopeActive {
                clearAskDJHistoryLocally()
            }
            sessionHistory.suspend(preservingVoicePreference: true)
        }
        invalidateActiveVoiceInventory()
        invalidateSessionRequest()
        isLoadingDJSession = false
        speechAutoplayAdmission.reset()
        cancelAutomaticSpeech()
        authenticatedStatusOrigin = nil
        bindProfileDJSettings(active: false)
        if let hybridTransport { Task { await hybridTransport.lifecycle(foreground: false) } }
        discoveryArtworkRenewalTask?.cancel(); discoveryArtworkRenewalTask = nil
        discoveryResponseGeneration = UUID()
        discoveryLoadGeneration = UUID(); discoveryRefreshGeneration = UUID()
        isLoadingMusicDiscovery = false; isRefreshingMusicDiscovery = false
        stopSessionBroadcast()
        scheduledPairingTask?.cancel()
        scheduledPairingTask = nil
        refreshScheduler.cancelAll()
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
            URLQueryItem(name: "title", value: localized(key: "ui.feedback.issue.title")),
            URLQueryItem(name: "body", value: feedbackIssueBody())
        ]
        return components?.url
    }

    public func feedbackIssueBody() -> String {
        """
        \(localized(key: "ui.feedback.issue.title"))

        \(localized(key: "ui.feedback.issue.intro"))

        ```text
        release_version: \(appVersion)
        build_version: \(buildVersion)
        protocol_version: \(Self.protocolVersion)
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
                "release_version": appVersion,
                "build_version": buildVersion,
                "protocol_version": Self.protocolVersion,
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

    nonisolated private static var platformName: String {
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

    nonisolated private static var installIDKey: String {
        "DJConnectInstallID-\(platformName)"
    }

    nonisolated private static let legacyInstallIDKey = "DJConnectInstallID"

    private static func hasExistingInstallID(defaults: UserDefaults) -> Bool {
        if defaults.string(forKey: installIDKey)?.isEmpty == false {
            return true
        }
        return defaults.string(forKey: legacyInstallIDKey)?.isEmpty == false
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
        pairedIdentityRecoveryTask?.cancel()
        volumeCommandTask?.cancel()
        seekCommandTask?.cancel()
        playbackProgressTask?.cancel()
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
        pairingFlowTarget = .appleWatch
        pendingWatchProxyPairingPayload = payload
        guard watchProxyRegistration != nil else {
            watchPairingMessage = localized(key: "appModel.open.djconnect.on.apple.watch.first.then.scan.the")
            pairingMessage = watchPairingMessage
            log(.warning, "Watch pairing link accepted but no Watch proxy registration is available")
            return
        }
        startPendingWatchProxyPairingIfPossible()
    }

    private func startPendingWatchProxyPairingIfPossible() {
        guard let payload = pendingWatchProxyPairingPayload,
              var registration = watchProxyRegistration else {
            return
        }
        pendingWatchProxyPairingPayload = nil
        registration.pairCode = payload.pairCode
        registration.paired = false
        watchProxyRegistration = registration
        persistWatchProxyRegistration()
        watchPairingMessage = localized(key: "appModel.pair.apple.watch.sending.pairing.request.to.home.assistant")
        pairingMessage = watchPairingMessage
        if !WCSession.default.isReachable {
            log(.debug, "Watch pairing accepted while WatchConnectivity is not reachable; continuing with iPhone Home Assistant proxy request")
        }
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
        guard !isDemoMode, pairingStatus != .paired else {
            return
        }
        if pairingStatus == .waitingForHomeAssistantCompletion {
            resumePendingHomeAssistantPairingIfNeeded()
            return
        }
        startPairingWait()
    }

    private func resumePendingHomeAssistantPairingIfNeeded() {
        guard startBackgroundTasks,
              defaults.bool(forKey: pendingHomeAssistantSetupKey),
              pairingStatus == .waitingForHomeAssistantCompletion,
              pairingTask == nil,
              let baseURL = Self.normalizedHomeAssistantURL(from: localHomeAssistantURL()) else {
            return
        }
        log(.info, "Resuming Home Assistant setup completion check")
        isPairing = true
        let generation = UUID(); pairingTaskGeneration = generation
        pairingTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if pairingTaskGeneration == generation {
                    pairingTask = nil
                    if pairingStatus != .paired { isPairing = false }
                }
            }
            do {
                try await self.waitForHomeAssistantPairingCompletion(client: self.makeClient(baseURL: baseURL),
                    isCurrentOperation: { self.pairingTaskGeneration == generation })
            } catch {
                guard !Task.isCancelled, pairingTaskGeneration == generation else { return }
                self.log(.warning, "Home Assistant setup completion check failed: \(error.localizedDescription)")
                self.pairingMessage = self.localized(key: "appModel.home.assistant.could.not.complete.pairing.check.the.url")
            }
        }
    }

    public func startPairingWait() {
        guard !isDemoMode else {
            log(.debug, "Ignoring pairing wait because demo mode is active")
            return
        }
        if pairingStatus == .waitingForHomeAssistantCompletion {
            resumePendingHomeAssistantPairingIfNeeded()
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
        let generation = UUID(); pairingTaskGeneration = generation
        pairingTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if pairingTaskGeneration == generation {
                    pairingTask = nil
                    if pairingStatus != .paired { isPairing = false }
                }
            }
            await pairWithHomeAssistant(baseURL: baseURL, pairCode: pairCode, generation: generation)
        }
    }

    public func stopPairingWait() {
        scheduledPairingTask?.cancel()
        scheduledPairingTask = nil
        pairingTask?.cancel()
        pairingTask = nil
        if pairingStatus == .pairing || pairingStatus == .waitingForHomeAssistantCompletion {
            log(.info, "Pairing wait stopped")
            if defaults.bool(forKey: pendingHomeAssistantSetupKey) {
                defaults.removeObject(forKey: pendingHomeAssistantSetupKey)
                try? tokenStore.clearToken()
            }
            pairingStatus = .unpaired
            isPairing = false
            pairingMessage = localized(key: "appModel.pairing.wait.stopped")
        }
    }

    private func pairWithHomeAssistant(baseURL: URL, pairCode: String, generation: UUID) async {
        isPairing = true
        log(.info, "Posting pairing request to Home Assistant client_type=\(identity.clientType.rawValue)")
        pairingMessage = localized(key: "appModel.pairing.with.home.assistant")

        let client = makeClient(baseURL: baseURL)
        do {
            if baseURL.scheme?.lowercased() == "https",
               !DJConnectPairingURLPolicy.isWhitelistedDevelopmentTunnelURL(baseURL) {
                throw DJConnectError.invalidConfiguration(localized(key: "appModel.pairing.must.be.completed.on.the.same.local.network"))
            }
            let response = try await client.pair(DJConnectPairingPayload(
                identity: identity,
                pairingToken: pairCode,
                haLocalURL: Self.normalizedHomeAssistantURL(from: homeAssistantURL).map(Self.redactedURL),
                assistPipelineID: assistPipelineID.isEmpty ? nil : assistPipelineID
            ))
            guard !Task.isCancelled, pairingTaskGeneration == generation else { return }
            apply(pairingResponse: response, fallbackBaseURL: baseURL)
            log(.info, "Pairing accepted by Home Assistant")
            if response.setupPending == false {
                completeHomeAssistantPairing()
                return
            }
            defaults.set(true, forKey: pendingHomeAssistantSetupKey)
            pairingStatus = .waitingForHomeAssistantCompletion
            isConnected = false
            pairingMessage = localized(key: "appModel.home.assistant.recognized.this.device.finish.setup.in.home")
            if startBackgroundTasks {
                try await waitForHomeAssistantPairingCompletion(client: client,
                    isCurrentOperation: { self.pairingTaskGeneration == generation })
            }
        } catch let error as DJConnectError {
            guard !Task.isCancelled, pairingTaskGeneration == generation else { return }
            logPairingError(error)
            applyPairingWait(error: error, pairingToken: pairCode)
        } catch {
            guard !Task.isCancelled, pairingTaskGeneration == generation else { return }
            log(.error, "Unexpected pairing error: \(error.localizedDescription)")
            isConnected = false
            pairingMessage = localized(key: "appModel.home.assistant.could.not.complete.pairing.check.the.url")
        }
    }

    func waitForHomeAssistantPairingCompletion(client: DJConnectClient,
        isCurrentOperation: @escaping @MainActor () -> Bool = { true }) async throws {
        let expectedToken = try tokenStore.loadToken()
        let expectedContext = [haLocalURL, haRemoteURL, defaults.string(forKey: haInstallIDKey) ?? "", identity.deviceID]
        func current() -> Bool {
            !Task.isCancelled && isCurrentOperation() &&
            (try? tokenStore.loadToken()) == expectedToken &&
            expectedContext == [haLocalURL, haRemoteURL, defaults.string(forKey: haInstallIDKey) ?? "", identity.deviceID]
        }
        let initialDelays: [UInt64] = [0, 2, 3, 5, 5, 5]
        var attempt = 0
        while current() && pairingStatus == .waitingForHomeAssistantCompletion {
            let delay = initialDelays[min(attempt, initialDelays.count - 1)]
            attempt += 1
            if delay > 0 {
                try await Task.sleep(for: .seconds(delay))
            }
            guard current(), pairingStatus == .waitingForHomeAssistantCompletion else {
                return
            }
            do {
                // Pairing completion belongs to this accepted credential and
                // installation, independently of conversation/UI suspension.
                let response = try await client.postPairingCompletionStatus(DJConnectStatusPayload(
                    identity: identity, haPairingStatus: .paired, language: currentRequestLocale,
                    logLevel: logLevel, appBuild: buildVersion, localAudioSupported: true,
                    voiceSupported: voiceEnabled, haLocalURL: haLocalURL.isEmpty ? nil : haLocalURL,
                    voiceEnabled: voiceEnabled, wakewordEnabled: wakeWordEnabled,
                    wakewordPhrase: wakeWordPhrase, wakewordStatus: "\(wakeWordStatus)",
                    mood: confirmedSessionMoodInt, musicDNAKey: askDJMusicDNAKey))
                guard current(), pairingStatus == .waitingForHomeAssistantCompletion else { return }
                guard validateHomeAssistantVersion(haVersion: response.haVersion,
                    haMajorMinor: response.haMajorMinor, message: response.message) else { return }
                // The setup flow's installation ID is provisional. Only this
                // credential-bound completion read may adopt the runtime ID.
                // There are no suspension points between admission and commit.
                applyBootstrapContext(haInstallID: response.haInstallID,
                    integrationVersion: response.integrationVersion, pairingSessionID: response.pairingSessionID)
                apply(musicBackendSummary: response.musicBackendSummary)
                apply(djAnnouncementCapabilities: response.djAnnouncement)
                if let playback = response.playback { apply(playback: playback) }
                backendAvailable = response.backendAvailable ?? true
                authenticatedStatusOrigin = client.baseURL
                completeHomeAssistantPairing()
                return
            } catch is CancellationError {
                guard current(), pairingStatus == .waitingForHomeAssistantCompletion else { return }
                pairingMessage = localized(key: "appModel.waiting.for.setup.to.be.completed.in.home.assistant")
                // Only the idempotent status read is retried; never pair again.
                continue
            } catch let error as DJConnectError {
                guard current() else { return }
                if isWaitingForHomeAssistantCompletion(error) {
                    pairingStatus = .waitingForHomeAssistantCompletion
                    pairingMessage = localized(key: "appModel.waiting.for.setup.to.be.completed.in.home.assistant")
                    log(.debug, "Waiting for Home Assistant setup completion: \(Self.describe(error))")
                    continue
                }
                if isPairingTokenRejectedAfterPair(error) {
                    defaults.removeObject(forKey: pendingHomeAssistantSetupKey)
                    try? tokenStore.clearToken()
                    applyPairingWait(error: error, pairingToken: pairingToken)
                    return
                }
                throw error
            }
        }
    }

    private func completeHomeAssistantPairing() {
        defaults.removeObject(forKey: pendingHomeAssistantSetupKey)
        pairingStatus = .paired
        isConnected = true
        isPairing = false
        pairingMessage = localized(key: "appModel.pairing.complete")
        presentPairingSuccessScreenAfterPairing()
        presentWakeWordActivationPromptAfterPairing()
        if !Self.isRunningUnderSwiftPMTests {
            requestRemoteNotificationRegistration()
        }
        registerStoredPushTokenIfPossible()
    }

    private func isWaitingForHomeAssistantCompletion(_ error: DJConnectError) -> Bool {
        switch error {
        case .notConfigured, .routeMissing:
            return true
        case .network, .backendUnavailable:
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
        defaults.removeObject(forKey: pendingHomeAssistantSetupKey)
        isDemoMode = false
        defaults.removeObject(forKey: demoModeKey)
        clearStoredHomeAssistantURLs()
        defaults.removeObject(forKey: installIDKey)
        defaults.removeObject(forKey: Self.legacyInstallIDKey)
        currentAPNsPushToken = nil
        defaults.removeObject(forKey: legacyPushTokenKey)
        defaults.removeObject(forKey: registeredPushTokenKey)
        defaults.removeObject(forKey: registeredPushTokenHashKey)
        defaults.removeObject(forKey: registeredPushEnvironmentKey)
        defaults.removeObject(forKey: registeredPushSignatureKey)
        defaults.removeObject(forKey: pushRegisteredKey)
        defaults.removeObject(forKey: pushEnvironmentStatusKey)
        defaults.removeObject(forKey: lastPushErrorKey)
        refreshPushNotificationStatus()
        identity = Self.makeIdentity(defaults: defaults)
        clearRuntimeState()
        clearAskDJHistoryLocally()
        isShowingTokenStorageError = false
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
        guard !isUITestRuntimeFixtureActive else {
            log(.debug, "Refresh ignored because a UI test runtime fixture is active")
            return
        }
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
        if let manualRefreshTask { return await manualRefreshTask.value }
        // A pull gesture may cancel its SwiftUI task while the request is still useful.
        // Share the operation with toolbar refreshes and wait for background refreshes.
        let generation = pairedIdentityRecoveryGeneration
        let task = Task { @MainActor in
            while isRefreshing {
                do { try await Task.sleep(for: .milliseconds(25)) }
                catch { return false }
                guard pairedIdentityRecoveryGeneration == generation else { return false }
            }
            guard !Task.isCancelled, pairedIdentityRecoveryGeneration == generation else { return false }
            return await runRefresh(reason: "Refresh completed", notifyUserOnError: true, forceCollections: true)
        }
        manualRefreshTask = task
        let result = await task.value
        manualRefreshTask = nil
        return result
    }

    public func refreshWebSocketFastPathStatus() {
        if let hybrid = sharedHybridTransport() {
            Task {
                let snapshot = await hybrid.snapshot()
                fastPathDiagnostics = DJConnectFastPathDiagnostics(fastPathTransport: snapshot.transportName ?? "offline",
                    websocketConnected: snapshot.websocketConnected, lastCapabilityRefresh: Date())
            }
            return
        }
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
        } catch is CancellationError {
            // A superseded snapshot is not a lost connection.
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
        guard !isOfflineModeActive else {
            log(.debug, "Paired refresh skipped because device network is offline")
            refreshScheduler.cancelPairedRefresh()
            return
        }
        refreshScheduler.schedulePairedRefresh(
            runFollowUpRefresh: runFollowUpRefresh,
            isStillValid: { [weak self] in
                guard let self else {
                    return false
                }
                return !self.isOfflineModeActive
            },
            refresh: { [weak self] in
                _ = await self?.runRefresh(
                    reason: reason,
                    allowThrottle: allowThrottle,
                    refreshCollections: refreshCollections
                )
            },
            followUpRefresh: { [weak self] in
                _ = await self?.runRefresh(reason: "Startup Now Playing refresh completed", allowThrottle: true)
            }
        )
    }

    private func scheduleBackendRecoveryRefresh(reason: String) {
        guard startBackgroundTasks, !isDemoMode, pairingStatus == .paired, !backendAvailable, !isOfflineModeActive else {
            return
        }
        refreshScheduler.scheduleBackendRecovery(
            isStillNeeded: { [weak self] in
                guard let self else {
                    return false
                }
                return self.pairingStatus == .paired
                    && !self.isDemoMode
                    && !self.backendAvailable
                    && !self.isOfflineModeActive
            },
            refresh: { [weak self] in
                guard let self else {
                    return
                }
                self.log(.debug, reason)
                _ = await self.runRefresh(
                    reason: "Playback backend recovery refresh completed",
                    allowThrottle: true,
                    refreshCollections: false
                )
            }
        )
    }

    private func scheduleCommandRefresh(
        reason: String,
        delay: Duration = .milliseconds(850),
        includeQueue: Bool = false,
        cleanup: (@MainActor () -> Void)? = nil
    ) {
        refreshScheduler.scheduleCommandRefresh(
            delay: delay,
            includeQueue: includeQueue,
            cleanup: cleanup,
            isStillValid: { [weak self] in
                guard let self else {
                    return false
                }
                return self.isAppInForeground
                    && self.pairingStatus == .paired
                    && !self.isOfflineModeActive
            },
            refresh: { [weak self] includeQueue in
                guard let self else {
                    return
                }
                // A successful playback selection invalidates the queue even
                // when a recent status/collection refresh would be throttled.
                if includeQueue {
                    // Let a pre-selection read finish before requesting the
                    // post-selection queue; otherwise the invalidation is lost.
                    while self.isLoadingQueue {
                        do { try await Task.sleep(for: .milliseconds(50)) }
                        catch { return }
                        guard !Task.isCancelled, self.isAppInForeground,
                              self.pairingStatus == .paired, !self.isOfflineModeActive else { return }
                    }
                    guard !Task.isCancelled, self.isAppInForeground,
                          self.pairingStatus == .paired, !self.isOfflineModeActive else { return }
                    _ = await self.refreshQueue()
                }
                guard !Task.isCancelled, self.isAppInForeground,
                      self.pairingStatus == .paired, !self.isOfflineModeActive else { return }
                _ = await self.runRefresh(
                    reason: reason,
                    allowThrottle: true,
                    refreshCollections: false
                )
            }
        )
    }

    public func sendPlaybackCommand(
        _ command: String,
        value: DJConnectCommandValue? = nil,
        play: Bool? = nil,
        expectedOutputSelectionGeneration: Int? = nil,
        onConfirmed: (@MainActor () -> Void)? = nil,
        onUnconfirmed: (@MainActor () -> Void)? = nil
    ) {
        guard isRuntimeCompatible else {
            log(.warning, "Command \(command) blocked because an app/integration update is required")
            onUnconfirmed?()
            return
        }
        if shouldBlockPlaybackStart(command: command, play: play) {
            log(.warning, "Command \(command) blocked because no output device is selected")
            userNotice = DJConnectUserNotice(text: localized(key: "appModel.select.an.output.device.first"))
            onUnconfirmed?()
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
            if onConfirmed == nil && onUnconfirmed == nil {
                await performCommand(command, value: value, play: play,
                                     expectedOutputSelectionGeneration: expectedOutputSelectionGeneration)
            } else {
                var confirmed = false
                await performCommand(command, value: value, play: play,
                                     expectedOutputSelectionGeneration: expectedOutputSelectionGeneration,
                                     onConfirmed: { confirmed = true; onConfirmed?() })
                if !confirmed, !Task.isCancelled { onUnconfirmed?() }
            }
        }
    }

    public func togglePlayback() {
        log(.debug, "User action: toggle playback")
        playPlaybackToggleHaptic(isStarting: !isPlaying)
        sendPlaybackCommand(isPlaying ? "pause" : "play")
    }

    public func commitVolumeChange() {
        guard canControlPlaybackVolume else { pendingVolumePercent = nil; return }
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
            guard self.canControlPlaybackVolume else { self.pendingVolumePercent = nil; return }
            await self.performCommand("set_volume", value: .int(value))
            self.scheduleCommandRefresh(reason: "Volume command Now Playing refresh completed") {
                if self.pendingVolumePercent == value {
                    self.pendingVolumePercent = nil
                }
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
            self.scheduleCommandRefresh(reason: "Seek command Now Playing refresh completed") {
                if self.pendingSeekTargetMS == target {
                    self.pendingSeekTargetMS = nil
                }
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

    /// The refresh button reads both the device inventory and actual playback.
    /// Neither read transfers playback or depends on the full-refresh spinner.
    @discardableResult
    public func refreshOutputDevicesAndPlayback() async -> Bool {
        guard !isLoadingOutputs else { return false }
        isLoadingOutputs = true
        defer { isLoadingOutputs = false }
        let generation = outputSelectionGeneration
        let devicesRead = await performCommand("devices", expectedOutputSelectionGeneration: generation)
        guard !Task.isCancelled, generation == outputSelectionGeneration else { return false }
        if isDemoMode { return devicesRead }
        do {
            try await refreshStatusWithFallback(isStillValid: { [weak self] in
                self?.outputSelectionGeneration == generation
            })
            return true
        } catch is CancellationError { return false }
        catch let error as DJConnectError {
            if error.invalidatesSessionAuthority { apply(error: error) }
            log(.warning, "Output refresh playback read failed: \(Self.describe(error))")
            return devicesRead
        } catch {
            log(.warning, "Output refresh playback read unavailable")
            return devicesRead
        }
    }

    public func loadQueue() {
        guard !isUITestRuntimeFixtureActive else {
            log(.debug, "Queue load ignored because a UI test runtime fixture is active")
            return
        }
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
        guard !isUITestRuntimeFixtureActive else {
            log(.debug, "Playlist load ignored because a UI test runtime fixture is active")
            return
        }
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
        guard !Self.isSyntheticOutput(output), !Self.legacyNoOutputNames.contains(output.name),
              output.name != noOutputName() else { return }
        // A pending choice already owns its one write; another tap is not a retry.
        guard pendingOutputSelectionID != output.id else { return }
        guard output.active != true || pendingOutputSelectionID != nil else { return }
        DJConnectHaptics.selection()
        log(.debug, "User action: select output")
        outputSelectionGeneration += 1
        let selectionGeneration = outputSelectionGeneration
        selectedOutput = output.name
        pendingSelectedOutput = output.name
        pendingSelectedOutputIsCachedSpotify = output.isCachedSpotifyOutput
        pendingOutputSelectionID = output.id
        Task {
            let accepted = await performCommand("set_output", value: .string(output.id), play: true,
                                                expectedOutputSelectionGeneration: selectionGeneration)
            guard selectionGeneration == outputSelectionGeneration else { return }
            let confirmed = availableOutputs.contains { candidate in
                candidate.active == true && candidate.id == output.id
            }
            pendingOutputSelectionID = nil
            pendingSelectedOutput = nil
            pendingSelectedOutputIsCachedSpotify = false
            if let active = availableOutputs.first(where: { $0.active == true }) {
                selectedOutput = active.name
            } else if let name = playback?.device?.name {
                selectedOutput = name
            }
            if accepted && !confirmed {
                userNotice = DJConnectUserNotice(text: localized(key: "ui.output.switch.unconfirmed"))
            }
        }
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
            scheduleCommandRefresh(
                reason: "Playlist Now Playing refresh completed",
                delay: .milliseconds(1_100)
            ) {
                self.loadingPlaylistID = nil
            }
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

    /// A Session heart must represent the same current playback that the existing command targets.
    func canToggleSessionFavorite(_ session: DJConnectSessionRuntime) -> Bool {
        guard canUsePlaybackFeatures, !djSessionIsRecovering, !djSessionLiveUnavailable,
              activeDJSession?.id == session.id,
              let expected = session.broadcast.playback,
              let currentSessionPlayback = activeDJSession?.broadcast.playback,
              let current = playback, current.hasPlayback != false else { return false }
        func normalized(_ value: String?) -> String { value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
        let title = normalized(expected.title), artist = normalized(expected.artist)
        guard !title.isEmpty, !artist.isEmpty,
              title == normalized(current.trackName), artist == normalized(current.artistName),
              title == normalized(currentSessionPlayback.title), artist == normalized(currentSessionPlayback.artist),
              expected.itemID == currentSessionPlayback.itemID else { return false }
        if let expectedDuration = expected.durationMS, let duration = current.durationMS,
           expectedDuration != duration { return false }
        return true
    }

    func displayedSessionPositionMS(_ session: DJConnectSessionRuntime) -> Int? {
        guard canToggleSessionFavorite(session) else { return session.broadcast.playback?.positionMS }
        return pendingSeekTargetMS ?? playback?.progressMS ?? session.broadcast.playback?.positionMS
    }

    func toggleSessionFavorite(_ session: DJConnectSessionRuntime) {
        guard canToggleSessionFavorite(session) else { return }
        toggleCurrentTrackFavorite(expectedSession: session)
    }

    public func toggleCurrentTrackFavorite() { toggleCurrentTrackFavorite(expectedSession: nil) }

    private func toggleCurrentTrackFavorite(expectedSession: DJConnectSessionRuntime?) {
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
            if let expectedSession, !canToggleSessionFavorite(expectedSession) { return }
            let didToggle = await sendSetCurrentTrackFavoriteCommand(shouldFavorite)
            userNotice = DJConnectUserNotice(text: didToggle ? localized(
                key: shouldFavorite ? "appModel.saved.to.favorites" : "appModel.removed.from.favorites"
            ) : localized(key: "appModel.favorite.status.could.not.be.changed"),
                systemImage: didToggle ? (shouldFavorite ? "heart.fill" : "heart") : "exclamationmark.triangle")
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
            scheduleCommandRefresh(
                reason: "Queue item Now Playing refresh completed",
                delay: .milliseconds(1_100),
                includeQueue: true
            ) {
                self.loadingQueueItemID = nil
                self.loadingQueueItemIndex = nil
            }
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

    func enterProfileConversationScope() {
        clearAskDJHistoryLocally()
        profileConversationClearRevision = 0
        profileConversationHistoryRevision = 0
        isSendingAskDJText = false
    }
    func clearProfileConversationDisplay() { clearAskDJHistoryLocally() }
    func revokeProfileConversationAuthority() {
        profileDJSettings.withdrawAuthority()
        stopResponsePlayback(clearText: false)
        cancelVoiceRecording()
        clearAskDJHistoryLocally()
        clearSessionProjection()
    }
    func applyConfirmedProfileConversationClear(_ response: DJConnectAskDJHistoryResponse) {
        clearAskDJHistoryLocally(); applyAskDJHistory(response, forceClear: response.isClearAcknowledged)
    }
    func profileConversationPayload(text: String, clientMessageID: String, context: DJConnectConversationContext) -> DJConnectAskDJRequest {
        // Core604b80f8 common Profile turns always defer synthesis. With contract3,
        // audioResponse requests autoplay eligibility only; actual prepare3 below
        // performs fresh device-speech admission. Do not erase that source intent.
        var payload = DJConnectAskDJRequest(identity: identity, text: text, clientMessageID: clientMessageID,
            inputType: "text", mood: confirmedSessionMoodInt, djStyle: "warm_radio_dj", musicDNAKey: askDJMusicDNAKey,
            audioResponse: profileDJSettings.negotiated && localResponseAudioEnabled && sharedDJSpeechAllowed &&
                profileDJSettings.effective?.announcement_output.allowsClientAudio == true ? .always : .never,
            djAnnouncementOutput: profileDJSettings.effective?.announcement_output ?? djAnnouncementOutput, language: currentRequestLocale)
        payload.conversationContext = context
        payload.speechContractVersion = profileDJSettings.negotiated ? 3 : nil
        return payload
    }

    var presentsPersonaReactionControl: Bool {
        PersonaReactionConsumerGate.isQualified && activePersonaReactionAvailable && currentPersonaScope() != nil && !isDemoMode &&
        profileDJSettings.response?.snapshot.session?.session_id == activeDJSession?.id &&
        profileDJSettings.response?.snapshot.activated == true && profileDJSettings.response?.snapshot.accepted_contract_version == 3 &&
        profileDJSettings.response?.snapshot.output_choice_confirmed == true
    }
    var canStartPersonaReaction: Bool {
        presentsPersonaReactionControl && !personaReactions.isActive && !isSendingAskDJText && !isRecordingVoice && voiceStatus != .processing &&
        !sharedSpeechIsPreparing && !sharedSpeechIsPlaying && !deviceSpeechPreviewIsPlaying &&
        !profileDJSettings.hasUncertainOperation && profileDJSettings.response?.requiresSelection == false &&
        profileDJSettings.response?.snapshot.activated == true && profileDJSettings.response?.snapshot.accepted_contract_version == 3 &&
        profileDJSettings.response?.snapshot.output_choice_confirmed == true
    }
    func requestPersonaReaction(_ kind: DJConnectPersonaReactionKind) {
        guard canStartPersonaReaction, let scope = currentPersonaScope(), let settings = profileDJSettings.response,
              let request = try? DJConnectPersonaReactionRequest(settings: settings, kind: kind, language: language,
                  processor: deviceSpeechPreferences.enabled ? .localOnDevice : .haConfigured) else { return }
        let preferences = deviceSpeechPreferences
        let voiceRevision = settings.voice_revision
        stopResponsePlayback(clearText: false)
        personaReactionScope = scope
        personaReplyScope = nil
        personaReactionNotice = nil
        let current: @MainActor () -> Bool = { [weak self] in
            guard let self else { return false }
            return self.currentPersonaScope() == scope && self.activePersonaReactionAvailable && !self.profileDJSettings.hasUncertainOperation &&
                self.profileDJSettings.response?.voice_revision == voiceRevision && self.deviceSpeechPreferences == preferences &&
                !self.isSendingAskDJText && !self.isRecordingVoice && self.voiceStatus != .processing &&
                !self.sharedSpeechIsPreparing && !self.sharedSpeechIsPlaying && !self.deviceSpeechPreviewIsPlaying
        }
        let notice: String?
        switch settings.snapshot.effective.announcement_output {
        case .textOnly: notice = "ui.session.reaction.text_only"
        case .haSpeaker: notice = "ui.session.reaction.speaker_unavailable"
        case .both: notice = "ui.session.reaction.speaker_partial"
        default: notice = nil
        }
        personaReactions.start(.init(request: { [weak self] dispatched in
            guard let self, current() else { throw CancellationError() }
            return try await self.withHomeAssistantClient(allowsOperationReplay: false) {
                if request.processor == .haConfigured && settings.snapshot.effective.announcement_output.allowsClientAudio {
                    try await self.requireHADeviceSpeech(client: $0, language: request.language, target: .local)
                    guard current(), !Task.isCancelled else { throw CancellationError() }
                }
                return try await $0.requestPersonaReaction(request, settings: settings, onOperationID: dispatched)
            }
        }, cancel: { [weak self] id, reason in
            guard let self else { return }
            try? await self.withHomeAssistantClient(allowsOperationReplay: false) {
                try await $0.cancelPersonaReaction(sessionID: request.session.session_id, reactionID: id, reason: reason)
            }
        }, current: current, admitsSpeech: { $0.admitsSpeech(request: request, settings: settings) },
        play: { [weak self] reaction, observed in
            guard let self, current() else { throw CancellationError() }
            return try await self.playPersonaReaction(reaction, request: request, settings: settings,
                                                     preferences: preferences, current: current, observed: observed)
        }, stop: { [weak self] reason in self?.stopPersonaReactionOutput(reason) }, failure: { [weak self] in
            guard let self else { return }
            let notice = DJConnectVisualNotice(text: self.localized(key: "ui.session.reaction.unavailable"), systemImage: "sparkles")
            self.personaReactionNotice = notice
            self.personaReactionNoticeTask?.cancel()
            self.personaReactionNoticeTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, self?.personaReactionNotice?.id == notice.id else { return }
                self?.personaReactionNotice = nil
            }
        }, notice: notice))
    }
    private func stopPersonaReactionOutput(_ reason: DJConnectPersonaReactionCancellation) {
        #if canImport(AVFoundation)
        personaReactionRenderer.stop()
        personaReactionRenderer.onPlaybackStateChange = nil; personaReactionRenderer.onPlaybackFinished = nil
        personaReactionPlayer?.stop(); personaReactionPlayer = nil
        #if os(iOS)
        if personaReactionOwnsAudioSession {
            personaReactionOwnsAudioSession = false
            // Release only this output's session, before another owner can
            // activate capture/playback; avoid leaving music ducked after a tap.
            if !isRecordingVoice && !sharedSpeechIsPreparing && !sharedSpeechIsPlaying && !deviceSpeechPreviewIsPlaying {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
        #endif
        #endif
        personaReactionOutputReserved = false
        resumePersonaInterruptedWakeIfNeeded()
    }
    private func resumePersonaInterruptedWakeIfNeeded() {
        guard personaReactionInterruptedWake, !personaReactionOutputReserved,
              !sharedSpeechIsPreparing, !sharedSpeechIsPlaying, !deviceSpeechPreviewIsPlaying else { return }
        resumeWakeWordListeningIfNeeded()
    }
    private func playPersonaReaction(_ reaction: DJConnectPersonaReaction, request: DJConnectPersonaReactionRequest,
                                    settings: DJConnectProfileDJSettingsResponse, preferences: DJConnectDeviceSpeechPreferences,
                                    current: @escaping @MainActor () -> Bool, observed: @escaping @MainActor (Bool) -> Void) async throws -> Bool {
        #if canImport(AVFoundation)
        personaReactionInterruptedWake = personaReactionInterruptedWake || wakeWordStatus == .listening
        personaReactionOutputReserved = true
        stopWakeWordListening()
        #if os(iOS)
        try await configureDJConnectAudioSession(category: .playback, mode: .spokenAudio, options: [.duckOthers])
        guard current(), !Task.isCancelled else { throw CancellationError() }
        try await setDJConnectAudioSessionActive(true)
        personaReactionOwnsAudioSession = true
        #endif
        guard current(), !Task.isCancelled else {
            stopPersonaReactionOutput(.speechConflict)
            throw CancellationError()
        }
        if request.processor == .localOnDevice {
            var started = false, finished = false
            personaReactionRenderer.onPlaybackStateChange = { playing in
                if playing { started = true }; observed(playing)
            }
            personaReactionRenderer.onPlaybackFinished = { finished = $0 }
            guard personaReactionRenderer.speak(reaction.text, locale: Self.speechLocaleIdentifier(for: reaction.locale),
                                               preferences: preferences, completion: {}) else { return false }
            while personaReactionRenderer.isSpeaking {
                guard current(), !Task.isCancelled else { throw CancellationError() }
                try await Task.sleep(for: .milliseconds(100))
            }
            return started && finished
        }
        let bytes = try await withHomeAssistantClient(allowsOperationReplay: false) {
            try await self.requireHADeviceSpeech(client: $0, language: request.language, target: .local)
            guard current(), !Task.isCancelled, reaction.deadline.map({ $0 > Date() }) == true else { throw CancellationError() }
            return try await $0.personaReactionAudio(reaction, request: request, settings: settings)
        }
        guard current(), !Task.isCancelled, reaction.deadline.map({ $0 > Date() }) == true else { throw CancellationError() }
        let player = try AVAudioPlayer(data: bytes)
        guard player.prepareToPlay(), player.play(), player.isPlaying else { return false }
        personaReactionPlayer = player
        observed(true)
        while player.isPlaying {
            guard current(), !Task.isCancelled else { throw CancellationError() }
            try await Task.sleep(for: .milliseconds(100))
        }
        observed(false); personaReactionPlayer = nil
        return true
        #else
        return false
        #endif
    }

    private func currentPersonaScope() -> PersonaObservationScope? {
        guard isAppInForeground, sessionHistory.hasAuthorizedOwner, isConnected, backendAvailable,
              !djSessionIsRecovering, !djSessionLiveUnavailable,
              let session = activeDJSession, session.runtimeState == "active",
              let binding = profileDJSettings.response?.binding else { return nil }
        return .init(sessionID: session.id, epoch: sessionHistory.responseEpoch,
                     connection: sessionBroadcastGeneration, settingsBinding: binding)
    }

    /// The supplied Moment has already passed native delivery/source/attribution admission.
    /// This does not grant speech rights or read the optimistic playback/capture flags.
    func personaEvidence(for session: DJConnectSessionRuntime, admittedMoment: DJConnectMoment?, at now: Date = Date()) -> DJPersonaActivity.Evidence {
        var evidence = DJPersonaActivity.Evidence()
        guard let scope = currentPersonaScope(), scope.sessionID == session.id else { return evidence }
        evidence.authorized = true
        let pending = sessionHistory.pendingTurns.contains {
            $0.requestEpoch == scope.epoch && !$0.failed && !$0.contextChanged &&
            $0.context.sessionID == scope.sessionID && $0.context.selectedEntry == nil
        }
        evidence.pending = personaRequestScope == scope && isSendingAskDJText && pending
        if personaVoiceScope == scope {
            #if canImport(AVFoundation)
            evidence.capturing = voiceRecorder?.isRecording == true
            #endif
            evidence.pending = evidence.pending || voiceStatus == .processing
        }
        if let observation = personaSpeechObservation, observation.scope == scope, observation.deadline > now {
            evidence.pending = evidence.pending || sharedSpeechIsPreparing
            #if canImport(AVFoundation)
            evidence.speaking = sharedResponseDataPlayer?.isPlaying == true || deviceSpeechRenderer.isActuallySpeaking
            #endif
            if case .moment(_, let id) = observation.reference { evidence.spokenMomentID = id }
        }
        if session.selectedPresence != .musicOnly, let moment = admittedMoment, moment.sessionID == scope.sessionID,
           session.broadcast.nativeDelivery?.currentMomentID == moment.id,
           session.broadcast.nativeDelivery?.currentSilenceMomentID == nil,
           DJPersonaActivity.isObservedAnnouncement(moment) {
            evidence.announcementID = moment.id
        }
        if personaReactionScope == scope && personaReactions.isActive {
            evidence.pending = evidence.pending || personaReactions.preparing
            if personaReactions.speaking { evidence.speaking = true; evidence.spokenMomentID = nil }
            evidence.explicitReply = personaReactions.reaction != nil
        }
        evidence.explicitReply = evidence.explicitReply || (personaReplyScope == scope &&
            personaReplyMomentID == session.broadcast.nativeDelivery?.currentMomentID &&
            personaReplySilenceMomentID == session.broadcast.nativeDelivery?.currentSilenceMomentID &&
            liveConversationPresentations.values.contains {
                $0.epoch == scope.epoch && $0.sessionID == scope.sessionID && ($0.deadline == nil || $0.deadline! > now)
            })
        return evidence
    }

    func beginProfileConversationText(text: String, clientMessageID: String) -> UUID? {
        personaReactions.cancel(.askDJForeground)
        personaReplyScope = nil
        personaRequestScope = sessionHistory.selectedEntry == nil ? currentPersonaScope() : nil
        playAskDJSendHaptic()
        askDJDraft = ""; askDJErrorMessage = nil; isSendingAskDJText = true
        return appendAskDJMessage(role: .user, text: text, clientMessageID: clientMessageID, status: .sending)
    }
    func setProfileConversationSending(_ value: Bool) {
        if value {
            personaReactions.cancel(.askDJForeground)
            personaReplyScope = nil
            let scope = currentPersonaScope()
            personaRequestScope = sessionHistory.pendingTurns.contains {
                !$0.failed && !$0.contextChanged && $0.requestEpoch == scope?.epoch &&
                $0.context.sessionID == scope?.sessionID && $0.context.selectedEntry == nil
            } ? scope : nil
        }
        if !value { personaRequestScope = nil }
        isSendingAskDJText = value
    }
    func failProfileConversationText(id: UUID?, errorKey: String) {
        personaRequestScope = nil
        isSendingAskDJText = false; askDJErrorMessage = localized(key: errorKey)
        if let id { updateAskDJMessageStatus(id: id, status: .failed) }
    }
    /// Follow-up selections inherit the original frozen result lifetime. An
    /// omitted result_set is not permission to mint a fresh or unlimited lease.
    func resolveConversationPresentationDeadline(_ response: DJConnectAskDJMessageResponse, now: Date = Date()) -> Date? {
        var actions = (response.playbackActions ?? []) + (response.confirmationActions ?? [])
        for message in response.messages { actions += message.playbackActions + message.confirmationActions }
        if let assistant = response.assistantMessage { actions += assistant.playbackActions + assistant.confirmationActions }
        let frozen = actions.filter { $0.resultSetID != nil || $0.actionID != nil }
        guard frozen.allSatisfy(\.hasConsistentResultIdentity) else { return .distantPast }
        let ids = Set(frozen.compactMap(\.resultSetID))
        let epoch = sessionHistory.responseEpoch
        if let result = response.resultSet {
            guard ids.isEmpty || ids == [result.resultSetID],
                  let proposed = conversationPresentationDeadline(response, now: now), proposed > now else {
                if !result.resultSetID.isEmpty, result.resultSetID.count <= 256 {
                    recordConversationResultLease(id: result.resultSetID, deadline: .distantPast, epoch: epoch)
                }
                return .distantPast
            }
            var deadline = proposed
            if let original = conversationResultLeases[result.resultSetID], original.epoch == epoch {
                deadline = min(original.deadline, proposed)
            }
            recordConversationResultLease(id: result.resultSetID, deadline: deadline, epoch: epoch)
            return deadline
        }
        guard !frozen.isEmpty else { return nil }
        let known = ids.compactMap { conversationResultLeases[$0] }
        guard known.count == ids.count, !known.isEmpty, known.allSatisfy({ $0.epoch == epoch }) else { return .distantPast }
        return known.map(\.deadline).min()
    }

    private func recordConversationResultLease(id: String, deadline: Date, epoch: UUID) {
        if conversationResultLeases[id] == nil { conversationResultLeaseOrder.append(id) }
        conversationResultLeases[id] = .init(epoch: epoch, deadline: deadline)
        while conversationResultLeaseOrder.count > 32 {
            conversationResultLeases.removeValue(forKey: conversationResultLeaseOrder.removeFirst())
        }
    }

    func invalidateConversationResultLeases() {
        conversationResultLeases = [:]; conversationResultLeaseOrder = []
    }

    func withdrawDeletedSessionPresentation(_ sessionID: String, entries: [DJConnectHistoryEntry], invalidatingAllLeases: Bool = true) {
        let messageIDs = Set(entries.compactMap(\.originMessageID))
        let localIDs = Set(askDJMessages.filter { $0.serverID.map(messageIDs.contains) == true }.map(\.id))
        askDJMessages.removeAll { localIDs.contains($0.id) }
        liveConversationPresentations = liveConversationPresentations.filter { !messageIDs.contains($0.key) }
        switch sharedSpeechReference {
        case .entry(let sourceSession, _), .moment(let sourceSession, _):
            if sourceSession == sessionID { stopResponsePlayback(clearText: false) }
        default: break
        }
        if invalidatingAllLeases { invalidateConversationResultLeases() }
    }

    @discardableResult func applyProfileConversationResponse(_ response: DJConnectAskDJMessageResponse, fallback: UUID?, sessionID: String? = nil) -> Bool {
        guard response.isPrivateEphemeralResponse || (response.historyRevision >= profileConversationHistoryRevision
              && response.clearRevision >= profileConversationClearRevision) else { return false }
        personaReactions.cancel(.askDJForeground)
        if !response.isPrivateEphemeralResponse, response.clearRevision > profileConversationClearRevision {
            sessionHistory.invalidateClearedConversation(); clearAskDJHistoryLocally()
        }
        withdrawLiveConversationPresentations()
        applyAskDJMessageResponse(response, fallbackUserMessageID: fallback)
        let deadline = resolveConversationPresentationDeadline(response)
        for incoming in response.messages where incoming.role == .assistant {
            guard let rendered = askDJMessages.first(where: { $0.serverID == incoming.id }) else { continue }
            liveConversationPresentations[incoming.id] = .init(epoch: sessionHistory.responseEpoch, deadline: deadline, message: rendered,
                isPrivateEphemeral: response.isPrivateEphemeralResponse, questionID: fallback, sessionID: sessionID)
        }
        if let deadline, deadline <= Date() {
            withdrawLiveConversationPresentations()
        } else if let deadline {
            let epoch = sessionHistory.responseEpoch
            liveConversationExpiryTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow))) } catch { return }
                guard let self, epoch == self.sessionHistory.responseEpoch else { return }
                self.withdrawLiveConversationPresentations()
            }
        }
        let currentScope = currentPersonaScope()
        if currentScope != nil, (personaRequestScope == currentScope || (personaVoiceScope == currentScope && voiceStatus == .processing)),
           sessionID == activeDJSession?.id, !liveConversationPresentations.isEmpty {
            personaReplyScope = currentPersonaScope()
            personaReplyMomentID = activeDJSession?.broadcast.nativeDelivery?.currentMomentID
            personaReplySilenceMomentID = activeDJSession?.broadcast.nativeDelivery?.currentSilenceMomentID
        }
        personaRequestScope = nil
        if voiceStatus == .processing { personaVoiceScope = nil }
        isSendingAskDJText = false; askDJErrorMessage = nil
        djResponseText = userFacingDJResponseText(response.assistantMessage?.text ?? response.djText ?? response.text) ?? ""
        return true
    }
    @discardableResult func applyProfileConversationHistory(_ response: DJConnectAskDJHistoryResponse) -> Bool {
        guard response.historyRevision >= profileConversationHistoryRevision,
              response.clearRevision >= profileConversationClearRevision else { return false }
        applyAskDJHistory(response)
        return true
    }

    public func sendAskDJText() {
        if sessionHistory.profileScopeActive {
            sessionHistory.sendText()
            return
        }
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
            sessionHistory.recordDemoTurn(question: text, answer: demoAskDJResponse)
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

    private var canReadMomentTrackInsight: Bool {
        momentInsightRetryAllowed && momentTrackInsightTarget != nil && isRuntimeCompatible && !isOfflineModeActive
            && isAppInForeground && pairingStatus == .paired && (momentInsightDeadline.map { $0 > Date() } ?? false)
    }
    public var canRetryMomentTrackInsight: Bool { canReadMomentTrackInsight && !isLoadingMomentTrackInsight }

    private var currentMomentInsightStyle: String {
        [language, activeDJSession?.selectedMood ?? "", String(activeDJSession?.moodRevision ?? -1),
         activeDJSession?.selectedPresence?.rawValue ?? "", String(activeDJSession?.presenceRevision ?? -1)].joined(separator: "|")
    }

    public func openMomentTrackInsight(_ offer: DJConnectMomentInsightNavigation) {
        guard !isDemoMode, pairingStatus == .paired, isAppInForeground, isRuntimeCompatible, !isOfflineModeActive,
              sessionHistory.momentInsightAvailable,
              let session = activeDJSession,
              session.broadcast.nativeCurrentInsightNavigation(at: Date()) == offer,
              let deadline = session.broadcast.originalInsightDeadline(for: offer.reference), deadline > Date() else { return }
        dismissMomentTrackInsight()
        momentTrackInsightTarget = offer.reference
        momentInsightDeadline = deadline
        momentInsightStyle = currentMomentInsightStyle
        momentInsightRetryAllowed = true
        isLoadingMomentTrackInsight = true
        scheduleMomentInsightExpiry()
        momentInsightTask = Task { [weak self] in _ = await self?.loadMomentTrackInsight(initial: true) }
    }

    @discardableResult public func refreshMomentTrackInsight() async -> Bool {
        await loadMomentTrackInsight(initial: false)
    }

    private func loadMomentTrackInsight(initial: Bool) async -> Bool {
        guard !Task.isCancelled else { return false }
        guard canReadMomentTrackInsight, initial || !isLoadingMomentTrackInsight, let reference = momentTrackInsightTarget,
              activeDJSession?.id == reference.sessionID, activeDJSession?.runtimeState == "active" else {
            if initial, momentTrackInsightTarget != nil {
                isLoadingMomentTrackInsight = false
                momentTrackInsightErrorMessage = localized(key: "ui.session.insight.unavailable")
            }
            return false
        }
        let request = UUID(), epoch = sessionHistory.responseEpoch, source = musicDiscoveryPushCoalescingKey()
        let style = currentMomentInsightStyle, started = Date()
        momentInsightGeneration = request; momentInsightStyle = style
        isLoadingMomentTrackInsight = true; momentTrackInsightErrorMessage = nil
        // A retry withdraws the previous private rendering before reading again.
        momentTrackInsight = nil
        defer { if momentInsightGeneration == request { isLoadingMomentTrackInsight = false } }
        let valid = { self.momentInsightGeneration == request && self.momentTrackInsightTarget == reference
            && self.sessionHistory.responseEpoch == epoch && self.musicDiscoveryPushCoalescingKey() == source
            && self.isAppInForeground && self.pairingStatus == .paired && self.isRuntimeCompatible && !self.isOfflineModeActive
            && self.activeDJSession?.id == reference.sessionID
            && self.activeDJSession?.runtimeState == "active" && self.currentMomentInsightStyle == style
            && self.momentInsightDeadline.map({ $0 > Date() }) == true && !Task.isCancelled }
        do {
            let detail = try await withHomeAssistantClient(allowsOperationReplay: false) {
                try await $0.momentTrackInsight(reference, language: self.language, mood: self.confirmedSessionMoodInt)
            }
            guard valid() else { return false }
            guard momentInsightMediaIdentity == nil || momentInsightMediaIdentity == detail.subject.mediaIdentity else {
                withdrawMomentTrackInsight(key: "ui.session.insight.unavailable", retryAllowed: false); return false
            }
            guard let originalDeadline = momentInsightDeadline else { return false }
            let deadline = min(originalDeadline, started.addingTimeInterval(detail.subject.expiresIn))
            guard deadline > Date() else {
                withdrawMomentTrackInsight(key: "ui.session.insight.expired", retryAllowed: false); return false
            }
            momentInsightDeadline = deadline
            momentInsightMediaIdentity = detail.subject.mediaIdentity
            momentTrackInsight = detail.insight
            scheduleMomentInsightExpiry()
            return true
        } catch {
            guard valid() else { return false }
            if Self.isCancellation(error) { return false }
            if case let DJConnectError.server(status, _) = error, status == 403 || status == 410 {
                withdrawMomentTrackInsight(key: "ui.session.insight.expired", retryAllowed: false)
            } else if (error as? DJConnectError)?.invalidatesSessionAuthority == true {
                dismissMomentTrackInsight()
                _ = sessionHistory.withdrawAuthority(for: error)
            } else {
                momentTrackInsightErrorMessage = localized(key: "ui.session.insight.unavailable")
            }
            return false
        }
    }

    public func dismissMomentTrackInsight() {
        momentInsightGeneration = UUID()
        momentInsightTask?.cancel(); momentInsightTask = nil
        momentInsightExpiryTask?.cancel(); momentInsightExpiryTask = nil
        momentTrackInsight = nil; momentTrackInsightTarget = nil; momentTrackInsightErrorMessage = nil
        momentInsightDeadline = nil; momentInsightMediaIdentity = nil; isLoadingMomentTrackInsight = false
    }

    private func withdrawMomentTrackInsight(key: String, retryAllowed: Bool) {
        momentInsightGeneration = UUID(); momentInsightRetryAllowed = retryAllowed
        momentInsightTask?.cancel(); momentInsightTask = nil
        momentTrackInsight = nil; isLoadingMomentTrackInsight = false
        momentTrackInsightErrorMessage = localized(key: key)
    }

    private func scheduleMomentInsightExpiry() {
        momentInsightExpiryTask?.cancel()
        guard let deadline = momentInsightDeadline else { return }
        let reference = momentTrackInsightTarget
        momentInsightExpiryTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow))) } catch { return }
            guard let self, self.momentTrackInsightTarget == reference else { return }
            self.withdrawMomentTrackInsight(key: "ui.session.insight.expired", retryAllowed: false)
        }
    }

    private func reconcileMomentTrackInsight() {
        guard let target = momentTrackInsightTarget else { return }
        guard let session = activeDJSession, session.id == target.sessionID, session.runtimeState == "active",
              session.broadcast.nativeDelivery != nil else { dismissMomentTrackInsight(); return }
        if let admission = session.broadcast.nativeDelivery?.admissions.first(where: { $0.momentID == target.momentID }),
           admission.qualification != "qualified" {
            withdrawMomentTrackInsight(key: "ui.session.insight.expired", retryAllowed: false)
        } else if currentMomentInsightStyle != momentInsightStyle {
            momentInsightStyle = currentMomentInsightStyle
            withdrawMomentTrackInsight(key: "ui.session.insight.context_changed", retryAllowed: true)
        }
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

    /// Screen entry is an explicit request; redraws and existing results do not regenerate.
    public func loadTrackInsightOnOpen() async {
        guard !Task.isCancelled, isAppInForeground, hasPlayingNow, canStartTrackInsightAnalysis,
              momentTrackInsightTarget == nil,
              currentTrackInsight == nil || !currentTrackInsightMatchesPlayback(),
              beginTrackInsightRefresh(open: false) else { return }
        let epoch = sessionHistory.responseEpoch, source = musicDiscoveryPushCoalescingKey()
        let playbackID = Self.playbackAutoInsightIdentity(playback), requestedLanguage = language
        defer { isLoadingTrackInsight = false }
        await performTrackInsightRefresh(open: false, forceRefresh: false, canAccept: {
            self.isAppInForeground && self.hasPlayingNow && self.canStartTrackInsightAnalysis
                && self.sessionHistory.responseEpoch == epoch && self.musicDiscoveryPushCoalescingKey() == source
                && Self.playbackAutoInsightIdentity(self.playback) == playbackID && self.language == requestedLanguage
                && self.momentTrackInsightTarget == nil
        })
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
    private func performTrackInsightRefresh(open: Bool, forceRefresh: Bool, canAccept: () -> Bool = { true }) async -> Bool {
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
                    mood: confirmedSessionMoodInt,
                    musicDNAKey: askDJMusicDNAKey,
                    includeVisualProfile: true,
                    includeRawResponse: true
                )
                insight = try await withHomeAssistantClient { client in
                    try await client.trackInsight(payload)
                }
            }
            guard !Task.isCancelled, canAccept() else { return false }
            applyTrackInsight(insight, open: open)
            return true
        } catch let error as DJConnectError {
            guard !Task.isCancelled, canAccept(), !Self.isCancellation(error) else { return false }
            trackInsightErrorMessage = trackInsightErrorMessage(for: error)
            log(.warning, "Track Insight failed: \(trackInsightFailureLogDetails(for: error))")
            return false
        } catch {
            guard !Task.isCancelled, canAccept(), !Self.isCancellation(error) else { return false }
            trackInsightErrorMessage = trackInsightErrorMessage(for: error)
            log(.warning, "Track Insight failed: \(trackInsightFailureLogDetails(for: error))")
            return false
        }
    }

    public func retryAskDJMessage(_ message: DJConnectAskDJMessage) {
        if sessionHistory.profileScopeActive {
            if let pending = sessionHistory.pendingTurns.first(where: { $0.localMessageID == message.id }) {
                sessionHistory.retry(pending)
            }
            return
        }
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
        case .djSession, .nowPlaying, .queue, .discovery, .playlists, .about:
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

    public func playAskDJRecommendation(_ action: DJConnectAskDJPlaybackAction,
                                        isStillValid: (@MainActor () -> Bool)? = nil) {
        guard isStillValid?() != false, playingAskDJActionID == nil, action.hasConsistentResultIdentity,
              action.resultSetID == nil || liveConversationActionIsCurrent(action) else {
            return
        }
        if action.isFavoriteCurrentTrackControlAction {
            guard isStillValid == nil else { return }
            setCurrentTrackFavoriteFromAskDJ(action)
            return
        }
        if action.isAskDJMessageAction {
            guard isStillValid == nil else { return }
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

        let operation = UUID(); askDJPlayOperation = operation
        askDJPlayIsSessionScoped = isStillValid != nil
        let valid: @MainActor () -> Bool = { [weak self] in
            self?.askDJPlayOperation == operation && !Task.isCancelled && isStillValid?() != false
                && (action.resultSetID == nil || self?.liveConversationActionIsCurrent(action) == true)
        }
        playingAskDJActionID = action.id
        askDJErrorMessage = nil
        playAskDJActionHaptic()
        log(.info, "Sending Ask DJ Play Now recommendation action")

        Task {
            defer {
                if askDJPlayOperation == operation {
                    playingAskDJActionID = nil; askDJPlayIsSessionScoped = false
                }
            }
            guard valid() else { return }
            do {
                let response = try await playAskDJRecommendationWithFallback(action, isStillValid: valid)
                guard valid() else { return }
                apply(commandResponse: response)
                if applyAskDJPlayNowCommandResponse(response) {
                    if response.success {
                        showAskDJToast(localized(key: "appModel.playing.recommendation"))
                        playAskDJResponseHaptic()
                        await refreshAfterDJResponse(isStillValid: valid)
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
                    await refreshAfterDJResponse(isStillValid: valid)
                    return
                }
                if action.isOutputAction, let outputDeviceID = action.outputDeviceID {
                    markAskDJOutputActionActive(outputDeviceID)
                    showAskDJToast(localized(key: "appModel.output.changed"))
                } else {
                    showAskDJToast(localized(key: "appModel.playing.recommendation"))
                }
                playAskDJResponseHaptic()
                await refreshAfterDJResponse(isStillValid: valid)
                log(.info, "Ask DJ action completed")
            } catch let error as DJConnectError {
                guard valid() else { return }
                askDJErrorMessage = askDJErrorText(for: error)
                showAskDJToast(for: error)
                log(.warning, "Ask DJ action failed: \(Self.describe(error))")
            } catch {
                guard valid() else { return }
                askDJErrorMessage = askDJUnavailableText()
                showAskDJToast(localized(key: "appModel.ask.dj.is.unreachable"))
                log(.error, "Ask DJ action failed unexpectedly: \(error.localizedDescription)")
            }
        }
    }

    func invalidateSessionPlaybackActions() {
        guard askDJPlayIsSessionScoped else { return }
        askDJPlayOperation = UUID(); askDJPlayIsSessionScoped = false
        playingAskDJActionID = nil
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
        playAskDJActionHaptic()
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
                if response.assistantMessage?.sessionSpeech != nil { autoplayAcceptedDJResponse(response) }
                else { Task { await playResponseAudioIfNeeded(resolvedAskDJResponseAudioURL(response)) } }
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
            } catch let outcome as DJConnectHybridTransportError {
                askDJErrorMessage = localized(key: outcome.localizationKey)
                if case .outcome(let receipt) = outcome, receipt.phase == "confirmed" {
                    if let userMessageID { updateAskDJMessageStatus(id: userMessageID, status: .sent) }
                    await syncAskDJHistory(showErrors: false)
                }
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
        DJConnectHaptics.selection()
        if isDemoMode {
            clearAskDJHistoryLocally()
            return
        }
        isClearingAskDJHistory = true
        askDJErrorMessage = nil
        log(.info, "Clearing Ask DJ chat history")

        let profileScope = sessionHistory.profileScopeActive
        let capturedEpoch = sessionHistory.responseEpoch
        Task {
            defer { isClearingAskDJHistory = false }
            do {
                let response: DJConnectAskDJHistoryResponse
                if profileScope { try await sessionHistory.clearExistingHistory(); return }
                else {
                    response = try await clearAskDJHistoryWithFallback()
                    guard capturedEpoch == sessionHistory.responseEpoch, !sessionHistory.profileScopeActive else { return }
                }
                clearAskDJHistoryLocally()
                applyAskDJHistory(response, forceClear: response.isClearAcknowledged)
            } catch is CancellationError {
                return
            } catch let error as DJConnectError {
                guard capturedEpoch == sessionHistory.responseEpoch else { return }
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
        guard canUseAskDJFeatures else {
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
        if isDemoMode { playDemoVoiceExample(); return }
        guard !isRecordingVoice, voiceStatus != .processing else {
            return
        }
        voiceOperationGeneration = UUID()
        personaReplyScope = nil
        personaVoiceScope = sessionHistory.selectedEntry == nil ? currentPersonaScope() : nil
        stopResponsePlayback(clearText: true)
        stopWakeWordListening()
        guard voiceEnabled else {
            dismissWakeWordListeningMessage()
            voiceStatus = .unavailable
            log(.warning, "Voice recording ignored because voice is disabled")
            resumeWakeWordListeningIfNeeded()
            return
        }
        if sessionHistory.profileScopeActive { sessionHistory.captureVoiceContext() }
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
            playDemoVoiceExample()
            return
        }
        guard pairingStatus == .paired else {
            dismissWakeWordListeningMessage()
            voiceStatus = .unavailable
            sessionHistory.cancelVoiceContext()
            voiceErrorMessage = localized(key: "appModel.pair.with.home.assistant.before.using.voice")
            log(.warning, "Voice recording ignored because app is not paired")
            resumeWakeWordListeningIfNeeded()
            return
        }

        #if canImport(Speech) && canImport(AVFoundation)
        voiceUsesDeviceSTT = deviceSTTEnabled
        voiceSTTContext = .init(sessionID: activeDJSession?.sessionID, selectedEntry: sessionHistory.selectedEntry)
        voiceSTTDraft = askDJDraft
        voiceSTTLanguage = language
        #endif
        voiceStartTask?.cancel()
        isRecordingVoice = true
        voiceStatus = .listening
        voiceErrorMessage = nil

        voiceStartTask = Task { @MainActor in
            if !deviceSTTEnabled {
                do {
                    try await withHomeAssistantClient { client in
                        try await self.requireHADeviceSpeech(client: client, language: self.currentRequestLocale)
                    }
                    guard !Task.isCancelled, isRecordingVoice else { return }
                } catch {
                    guard !Task.isCancelled, isRecordingVoice else { return }
                    cancelVoiceRecording()
                    _ = sessionHistory.withdrawAuthority(for: error)
                    voiceStatus = .unavailable
                    voiceErrorMessage = localized(key: "ui.voice.requests.unavailable")
                    return
                }
            }
            let granted = await requestMicrophoneAccess()
            guard !Task.isCancelled, isRecordingVoice else {
                return
            }
            guard granted else {
                isRecordingVoice = false
                sessionHistory.cancelVoiceContext()
                dismissWakeWordListeningMessage()
                voiceStatus = .unavailable
                voiceErrorMessage = localized(key: "appModel.microphone.access.is.required.for.push.to.talk")
                log(.warning, "Microphone permission was not granted")
                resumeWakeWordListeningIfNeeded()
                return
            }
            #if canImport(Speech) && canImport(AVFoundation)
            if voiceUsesDeviceSTT {
                let speechGranted = await requestSpeechAccess()
                guard !Task.isCancelled, isRecordingVoice else { return }
                guard speechGranted,
                      DJConnectAppleSpeechTranscriber.isAvailable(language: Self.speechLocaleIdentifier(for: language)) else {
                    cancelVoiceRecording()
                    voiceStatus = .unavailable
                    voiceErrorMessage = localized(key: "ui.device_stt.unavailable")
                    return
                }
            }
            #endif
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

    /// Scripted and explicitly labelled; Demo Mode never records or uploads audio.
    private func playDemoVoiceExample() {
        guard isDemoMode, voiceEnabled else { return }
        cancelVoiceRecording()
        let question = localized(key: "demo.session.voice_question")
        let answer = localized(key: "demo.session.voice_answer")
        voiceErrorMessage = nil; voiceStatus = .idle; djResponseText = answer
        appendAskDJMessage(role: .user, text: question)
        appendAskDJMessage(role: .dj, text: answer)
        sessionHistory.recordDemoTurn(question: question, answer: answer, inputType: "voice")
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
        cancelVoiceRecording()
    }

    /// Leaving a composer discards an unfinished capture rather than creating
    /// a conversation turn as a side effect of navigation.
    public func cancelVoiceRecording() {
        personaVoiceScope = nil
        voiceOperationGeneration = UUID()
        #if canImport(Speech) && canImport(AVFoundation)
        deviceSTTTask?.cancel(); deviceSTTTask = nil
        deviceSTTTranscriber.cancel()
        voiceSTTContext = nil
        #endif
        sessionHistory.cancelVoiceContext()
        if case .voiceRecording = pendingPermissionRequest {
            pendingPermissionRequest = nil
            isShowingPermissionExplanation = false
        }
        if voiceStatus == .processing {
            voiceStatus = .idle
            voiceErrorMessage = nil
        }
        guard isRecordingVoice else { return }
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
        log(.info, "Unfinished voice capture discarded")
        resumeWakeWordListeningIfNeeded()
        #endif
    }

    /// Shared real capture submission; keeping operation identity prevents old uploads changing a new capture.
    func uploadRecordedVoiceWAV(_ data: Data, operation: UUID, historyEpoch: UUID) async {
        guard !isDemoMode else { return }
        // Defense in depth: a local-STT selection can never fall through to HA audio.
        guard !deviceSTTEnabled else { return }
        do {
            guard operation == voiceOperationGeneration, historyEpoch == sessionHistory.responseEpoch else { return }
            voiceStatus = .processing
            if sessionHistory.profileScopeActive {
                log(.info, "Uploading profile conversation voice WAV (\(data.count) bytes)")
                try await sessionHistory.uploadVoice(data)
                guard operation == voiceOperationGeneration, historyEpoch == sessionHistory.responseEpoch else { return }
                voiceErrorMessage = nil
                voiceStatus = .idle
                log(.info, "Profile conversation voice request confirmed")
                resumeWakeWordListeningIfNeeded()
                return
            }
            log(.info, "Uploading voice recording WAV (\(data.count) bytes)")
            let response = try await sendVoiceWithFallback(wavData: data)
            guard operation == voiceOperationGeneration, historyEpoch == sessionHistory.responseEpoch else { return }
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
            guard operation == voiceOperationGeneration, historyEpoch == sessionHistory.responseEpoch else { return }
            voiceErrorMessage = nil
            voiceStatus = .idle
            log(.info, "Voice request completed")
            resumeWakeWordListeningIfNeeded()
        } catch is CancellationError {
            return
        } catch let error as DJConnectError {
            guard operation == voiceOperationGeneration, historyEpoch == sessionHistory.responseEpoch else { return }
            if sessionHistory.profileScopeActive {
                if case .server(let status, _) = error {
                    log(.warning, "Profile conversation voice request failed: HTTP \(status)")
                } else {
                    log(.warning, "Profile conversation voice request failed before confirmation")
                }
                sessionHistory.cancelVoiceContext()
                if case .server(let status, _) = error, status == 409 {
                    voiceErrorMessage = localized(key: "ui.session.history.changed")
                } else { voiceErrorMessage = localized(key: "ui.session.history.unavailable") }
                voiceStatus = .unavailable
                resumeWakeWordListeningIfNeeded()
                return
            }
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
            guard operation == voiceOperationGeneration, historyEpoch == sessionHistory.responseEpoch else { return }
            voiceErrorMessage = localized(key: "ui.session.history.voice_failed")
            showAskDJToast(localized(key: "appModel.ask.dj.is.unreachable"))
            voiceStatus = .unavailable
            log(.error, "Voice upload failed unexpectedly: \(error.localizedDescription)")
            resumeWakeWordListeningIfNeeded()
        }
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
        log(.info, "Voice recording stopped for submission")
        dismissWakeWordListeningMessage()
        #if os(iOS)
        Task {
            try? await setDJConnectAudioSessionActive(false, options: .notifyOthersOnDeactivation)
        }
        #endif
        playVoiceCue(.stopListening)
        playVoiceHaptic(.stopListening)

        guard let url else {
            sessionHistory.cancelVoiceContext()
            voiceStatus = .idle
            log(.debug, "Voice recording stopped before the recorder was ready")
            resumeWakeWordListeningIfNeeded()
            return
        }

        let operation = voiceOperationGeneration
        let historyEpoch = sessionHistory.responseEpoch
        #if canImport(Speech) && canImport(AVFoundation)
        if voiceUsesDeviceSTT {
            let context = voiceSTTContext, draft = voiceSTTDraft, captureLanguage = voiceSTTLanguage
            deviceSTTTask = Task { @MainActor in
                defer { try? FileManager.default.removeItem(at: url) }
                do {
                    let transcript = try await deviceSTTTranscriber.transcribe(url: url, language: Self.speechLocaleIdentifier(for: captureLanguage))
                    guard !Task.isCancelled else { return }
                    acceptDeviceSTTTranscript(transcript, operation: operation, historyEpoch: historyEpoch,
                        context: context, originalDraft: draft, captureLanguage: captureLanguage)
                } catch is CancellationError { return }
                catch {
                    guard operation == voiceOperationGeneration, historyEpoch == sessionHistory.responseEpoch else { return }
                    sessionHistory.cancelVoiceContext()
                    voiceStatus = .unavailable
                    voiceErrorMessage = localized(key: "ui.device_stt.failed")
                    resumeWakeWordListeningIfNeeded()
                }
            }
            return
        }
        #endif
        Task {
            defer { try? FileManager.default.removeItem(at: url) }
            do {
                let data = try DJConnectAudioFileLoader.loadVoiceWAVData(from: url)
                await uploadRecordedVoiceWAV(data, operation: operation, historyEpoch: historyEpoch)
            } catch {
                guard operation == voiceOperationGeneration, historyEpoch == sessionHistory.responseEpoch else { return }
                sessionHistory.cancelVoiceContext()
                voiceErrorMessage = localized(key: "ui.session.history.voice_failed")
                voiceStatus = .unavailable
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

    func acceptDeviceSTTTranscript(_ transcript: String, operation: UUID, historyEpoch: UUID,
        context: DJConnectConversationContext?, originalDraft: String, captureLanguage: String) {
        guard deviceSTTEnabled, operation == voiceOperationGeneration,
              historyEpoch == sessionHistory.responseEpoch else { return }
        sessionHistory.cancelVoiceContext()
        voiceStatus = .idle
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, language == captureLanguage, askDJDraft == originalDraft,
              context == DJConnectConversationContext(sessionID: activeDJSession?.sessionID, selectedEntry: sessionHistory.selectedEntry),
              !isSendingAskDJText else {
            voiceErrorMessage = localized(key: "ui.device_stt.failed")
            resumeWakeWordListeningIfNeeded()
            return
        }
        voiceOperationGeneration = UUID() // consume this recognition result exactly once
        voiceErrorMessage = nil
        askDJDraft = text
        sendAskDJText()
        resumeWakeWordListeningIfNeeded()
    }

    public func apply(playback: DJConnectPlayback?) {
        guard isRuntimeCompatible else {
            log(.debug, "Ignoring playback snapshot because Home Assistant integration version is incompatible")
            return
        }
        var normalizedPlayback = DJConnectVolumeNormalizer.sanitizedPlayback(playback)
        let resolvedAlbumImageURL = resolvedArtworkURL(normalizedPlayback?.albumImageURL)
        normalizedPlayback?.albumImageURL = resolvedAlbumImageURL
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
        playbackOutputObservation += 1
        if normalizedPlayback?.device != nil {
            availableOutputs = normalizedOutputDevices(outputRowsMatchingCurrentPlayback(availableOutputs))
        }
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
            let matchesPending = pendingOutputSelectionID.map { $0 == normalizedPlayback?.device?.id } ?? true
            if matchesPending {
                selectedOutput = deviceName
                pendingSelectedOutput = nil
                pendingSelectedOutputIsCachedSpotify = false
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

    private func apply(commandResponse response: DJConnectCommandResponse, command: String?, reconcilePlaybackOutput: Bool = false) {
        guard validateHomeAssistantVersion(
            haVersion: response.haVersion,
            haMajorMinor: response.haMajorMinor,
            message: response.message
        ) else {
            return
        }
        applyPushRegistrationStatus(from: response)
        applyBootstrapContext(
            haInstallID: response.haInstallID,
            integrationVersion: response.integrationVersion,
            pairingSessionID: response.pairingSessionID
        )
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
        if response.success == false, Self.isVolumeControlUnavailable(response.message) {
            userNotice = DJConnectUserNotice(text: localized(key: "appModel.device.volume.control.unavailable"))
        } else if response.success == false {
            switch response.error {
            case "backend_unavailable", "playback_backend_unavailable":
                apply(error: .backendUnavailable(message: response.message))
                if shouldEmitBackendUnavailableNotice() {
                    userNotice = DJConnectUserNotice(text: backendUnavailableRecoveryMessage(for: response.message))
                }
            case "stale_backend_action":
                userNotice = DJConnectUserNotice(text: localized(key: "appModel.this.action.belongs.to.a.previous.music.backend.ask"))
            case "unsupported_backend_capability":
                userNotice = DJConnectUserNotice(text: response.message ?? localized(key: "appModel.this.music.backend.does.not.support.that.action"))
            default:
                if command == "set_output", pendingSelectedOutputIsCachedSpotify {
                    userNotice = DJConnectUserNotice(text: localized(key: "appModel.cached.spotify.output.unavailable"))
                }
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
            let projectedDevices = response.playback != nil || reconcilePlaybackOutput
                ? outputRowsMatchingCurrentPlayback(devices) : devicesApplyingCurrentPlayback(to: devices)
            let normalizedDevices = normalizedOutputDevices(projectedDevices)
            availableOutputs = normalizedDevices
            if let active = normalizedDevices.first(where: { $0.active == true }) {
                if pendingSelectedOutput == nil || pendingSelectedOutput == active.name {
                    selectedOutput = active.name
                    pendingSelectedOutput = nil
                    pendingSelectedOutputIsCachedSpotify = false
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
            if command == "queue" {
                let distinctTracks = Set(responseQueue.map(queueItemSignature)).count
                log(.info, "Queue snapshot decoded_count=\(responseQueue.count) normalized_count=\(normalizedQueue.count) distinct_tracks=\(distinctTracks) distinct_row_ids=\(Set(normalizedQueue.map(\.id)).count)")
            }
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
        if let message = response.message, !message.isEmpty, !Self.isMusicBackendUnavailableText(response.error) {
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
        // Stable identities are unique SwiftUI row identities as well as command
        // targets. Prefer the live observation over an old cached duplicate.
        var uniqueDevices: [DJConnectOutputDevice] = []
        for output in devices where !output.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            output.id != Self.syntheticNoOutputID && output.name != noOutputName() &&
            !Self.legacyNoOutputNames.contains(output.name) {
            if let index = uniqueDevices.firstIndex(where: { $0.id == output.id }) {
                if uniqueDevices[index].cached == true && output.cached != true { uniqueDevices[index] = output }
            } else { uniqueDevices.append(output) }
        }
        let backendDevices = uniqueDevices.map { output in
            var result = output
            if output.matchesPlaybackDevice(id: playback?.device?.id, name: playback?.device?.name),
               playback?.device?.supportsVolume == false {
                result.supportsVolume = false
                result.volumePercent = nil
            }
            if !result.hasDisplayName {
                // Resolve only the exact stable identity; never join by an opaque label.
                let known = availableOutputs.first { $0.id == output.id && $0.hasDisplayName }
                if let known { result.name = known.name }
                else if playback?.device?.id == output.id,
                        let name = playback?.device?.name,
                        DJConnectOutputDevice(id: output.id, name: name).hasDisplayName {
                    result.name = name
                }
            }
            return result
        }
        return backendDevices
    }

    /// A newly observed current playback device updates the selected row too.
    /// No device is invented when it is absent from the available inventory.
    private func outputRowsMatchingCurrentPlayback(_ devices: [DJConnectOutputDevice]) -> [DJConnectOutputDevice] {
        guard let device = playback?.device,
              device.id?.isEmpty == false || device.name?.isEmpty == false else { return devices }
        // An ambiguous legacy display name cannot identify one physical device.
        if device.id?.isEmpty != false,
           devices.filter({ $0.matchesPlaybackDevice(id: nil, name: device.name) }).count > 1 { return devices }
        return devices.map { output in
            var result = output
            result.active = output.matchesPlaybackDevice(id: device.id, name: device.name)
            return result
        }
    }

    private func devicesApplyingCurrentPlayback(to devices: [DJConnectOutputDevice]) -> [DJConnectOutputDevice] {
        // Explicit device flags belong to this response. An older playback
        // snapshot must not reactivate the previously selected speaker.
        guard !devices.contains(where: { $0.active != nil }) else { return devices }
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

    private func normalizedQueueItems(_ items: [DJConnectQueueItem]) -> [DJConnectQueueItem] {
        // Identity must be unique even when the same URI carries different
        // metadata, and generated suffixes must not collide with real IDs.
        let reserved = Set(items.map(\.id))
        var used = Set<String>()
        var nextSuffix: [String: Int] = [:]
        return items.map { original in
            var item = original
            if used.contains(item.id) {
                var suffix = nextSuffix[original.id, default: 2]
                var candidate = "\(original.id)#\(suffix)"
                while reserved.contains(candidate) || used.contains(candidate) {
                    suffix += 1
                    candidate = "\(original.id)#\(suffix)"
                }
                item.id = candidate
                nextSuffix[original.id] = suffix + 1
            }
            used.insert(item.id)
            return item
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
        applyBootstrapContext(
            haInstallID: response.haInstallID,
            integrationVersion: response.integrationVersion,
            pairingSessionID: response.pairingSessionID
        )
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
        apply(djAnnouncementCapabilities: response.djAnnouncement)
    }

    private func applyBootstrapContext(
        haInstallID: String?,
        integrationVersion: String?,
        pairingSessionID: String?
    ) {
        storeNonEmpty(haInstallID, forKey: haInstallIDKey)
        storeNonEmpty(integrationVersion, forKey: integrationVersionKey)
        storeNonEmpty(pairingSessionID, forKey: pairingSessionIDKey)
    }

    private func storeNonEmpty(_ value: String?, forKey key: String) {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return
        }
        defaults.set(trimmed, forKey: key)
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
            voiceErrorMessage = backendUnavailableRecoveryMessage()
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
            } else if pairingStatus == .paired {
                // An integration reload temporarily removes its runtime; it does
                // not prove the persisted device credential was revoked.
                clearRuntimeState(backendAvailableAfterClear: false)
                isConnected = false
                pairingMessage = message ?? localized(key: "appModel.not.connected.to.home.assistant")
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
        defaults.removeObject(forKey: pendingHomeAssistantSetupKey)
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
        let isBackendUnavailable = error.map { Self.isMusicBackendUnavailableError($0) } == true
        if isBackendUnavailable, !shouldEmitBackendUnavailableNotice() {
            return
        }
        let text = isBackendUnavailable
            ? backendUnavailableRecoveryMessage()
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
        authenticatedStatusOrigin = nil
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
        case .backendUnavailable, .server, .network, .decodingFailed, .invalidResponse, .routeMissing, .payloadTooLarge:
            true
        case .authStale, .versionMismatch, .notConfigured, .invalidConfiguration, .missingToken, .pairingFailed, .clientTypeMismatch, .trackInsightUnavailable, .profile:
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
            pairingMessage = safePairingMessage(from: message)
        default:
            pairingStatus = .unpaired
            pairingMessage = localized(key: "appModel.home.assistant.could.not.complete.pairing.check.the.url")
        }
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

    @discardableResult
    public func refreshActiveDJSession() async -> Bool {
        guard !Task.isCancelled else { return false }
        if isDemoMode { return true }
        guard isAppInForeground, pairingStatus == .paired, !isLoadingDJSession else { return false }
        let request = UUID()
        sessionRequestGeneration = request
        isLoadingDJSession = true
        defer { if request == sessionRequestGeneration { isLoadingDJSession = false } }
        do {
            let response = try await withHomeAssistantClient { client in
                try await client.activeSession()
            }
            guard !Task.isCancelled, request == sessionRequestGeneration, pairingStatus == .paired else { return false }
            guard response.success else {
                clearSessionProjection()
                djSessionErrorMessage = localized(key: "ui.session.unavailable")
                return false
            }
            if let incoming = response.resolvedSession, incoming.broadcast.session.sessionID != incoming.sessionID {
                clearSessionProjection()
                djSessionErrorMessage = localized(key: "ui.session.unavailable")
                return false
            }
            if activeDJSession?.sessionID != response.resolvedSession?.sessionID {
                vibeCastHandoffApproved = false
                vibeCastHandoffFailed = false
            }
            if let old = activeDJSession, let incoming = response.resolvedSession, old.id == incoming.id {
                activeDJSession = old.applying(broadcastState: incoming.personaSafeBroadcast)
            } else {
                activeDJSession = response.resolvedSession
            }
            djSessionErrorMessage = nil
            startSessionBroadcastIfNeeded()
            return true
        } catch {
            guard !Task.isCancelled, !(error is CancellationError),
                  (error as? URLError)?.code != .cancelled else { return false }
            guard request == sessionRequestGeneration else { return false }
            if (error as? DJConnectError)?.invalidatesSessionAuthority == true {
                _ = sessionHistory.withdrawAuthority(for: error)
                await recoverAfterPairedAuthorityWithdrawal((error as? DJConnectError).map {
                    if case .profile = $0 { return "profile_changed" }; return "unauthorized"
                } ?? "unauthorized")
            }
            guard request == sessionRequestGeneration else { return false }
            djSessionErrorMessage = localized(key: "ui.session.unavailable")
            return false
        }
    }

    public func refreshActiveMoodCapability() async {
        guard !Task.isCancelled else { return }
        if isDemoMode {
            activePersonaReactionAvailable = false
            activePersonaAvailable = false
            activeMoodAvailable = activeDJSession != nil
            activePresenceAvailable = activeDJSession?.confirmedPresence != nil
            activePresenceCapabilityStatus = activePresenceAvailable ? .supported : .unsupported
            return
        }
        let previous = (mood: activeMoodAvailable, persona: activePersonaAvailable, presence: activePresenceAvailable, status: activePresenceCapabilityStatus, shared: activeSharedSettingsRequired, reaction: activePersonaReactionAvailable)
        activePersonaReactionAvailable = false
        activeMoodAvailable = false
        activePersonaAvailable = false
        activePresenceAvailable = false
        guard isAppInForeground, pairingStatus == .paired else {
            activePresenceCapabilityStatus = .notLoaded
            return
        }
        activePresenceCapabilityStatus = .loading
        let generation = UUID(); moodCapabilityGeneration = generation
        let epoch = sessionHistory.responseEpoch
        var cancelledRead = false
        defer {
            // Closing a menu cancels its GET, not the confirmed capability or owner.
            // A newer read / owner transition always wins over this restoration.
            if (Task.isCancelled || cancelledRead), generation == moodCapabilityGeneration,
               epoch == sessionHistory.responseEpoch, isAppInForeground, pairingStatus == .paired {
                activePersonaReactionAvailable = previous.reaction
                activeSharedSettingsRequired = previous.shared
                activeMoodAvailable = previous.mood
                activePersonaAvailable = previous.persona
                activePresenceAvailable = previous.presence
                activePresenceCapabilityStatus = previous.status == .loading ? .notLoaded : previous.status
            }
        }
        do {
            let caps = try await withHomeAssistantClient { try await $0.activeSessionMoodCapabilities() }
            guard generation == moodCapabilityGeneration, epoch == sessionHistory.responseEpoch, isAppInForeground, pairingStatus == .paired else { return }
            guard !Task.isCancelled else { return }
            activePersonaReactionAvailable = caps.personaReactionAvailable
            activeSharedSettingsRequired = caps.sharedSettingsAvailable
            // Explicit legacy producer support only. A producer advertising
            // settings3 must never fall back to a legacy write after a failed read.
            activeMoodAvailable = caps.sharedSettingsAvailable || caps.available
            activePersonaAvailable = caps.sharedSettingsAvailable || caps.personaAvailable
            activePresenceAvailable = caps.sharedSettingsAvailable || caps.presenceAvailable
            activePresenceCapabilityStatus = activePresenceAvailable ? .supported : .unsupported
        } catch {
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                cancelledRead = true
                return
            }
            guard generation == moodCapabilityGeneration, epoch == sessionHistory.responseEpoch,
                  isAppInForeground, pairingStatus == .paired else { return }
            if sessionHistory.withdrawAuthority(for: error) { return }
            switch error {
            case DJConnectError.decodingFailed, DJConnectError.invalidResponse, DJConnectError.versionMismatch:
                activePresenceCapabilityStatus = .incompatibleResponse
            case is DecodingError:
                activePresenceCapabilityStatus = .incompatibleResponse
            default:
                activePresenceCapabilityStatus = .temporarilyUnavailable
            }
        }
    }

    /// One active-Session writer; rapid deliberate choices replace the queued intent.
    /// Confirmation comes exclusively from the server projection, never from this queue.
    public func selectActiveSessionPresence(_ value: DJConnectSessionPresenceValue,
                                           expectedSessionID: String, expectedEpoch: UUID) {
        if isDemoMode {
            guard expectedSessionID == activeDJSession?.id, expectedEpoch == sessionHistory.responseEpoch,
                  let current = activeDJSession, let confirmed = current.confirmedPresence else { return }
            activeDJSession = current.applying(presence: .init(sessionID: current.id, selectedPresence: value,
                presenceRevision: confirmed.presenceRevision + (confirmed.selectedPresence == value ? 0 : 1)))
            activePresenceDesired = nil; activePresenceError = nil; activePresenceRequiresDecision = false
            return
        }
        if activeSharedSettingsRequired || profileDJSettings.negotiated {
            guard expectedSessionID == activeDJSession?.id, expectedEpoch == sessionHistory.responseEpoch,
                  profileDJSettings.response?.snapshot.session?.session_id == expectedSessionID,
                  profileDJSettings.canEdit else { return }
            scheduleProfileDJChoice(.init(presence: value))
            return
        }
        guard expectedSessionID == activeDJSession?.id, expectedEpoch == sessionHistory.responseEpoch,
              activePresenceAvailable, isAppInForeground, pairingStatus == .paired,
              activeDJSession?.confirmedPresence != nil else { return }
        activePresenceDesired = value; presenceIntent = UUID()
        activePresenceError = nil; activePresenceRequiresDecision = false
        guard presenceTask == nil else { return }
        let generation = presenceGeneration
        activePresencePending = true
        presenceTask = Task { await drainPresence(sessionID: expectedSessionID, epoch: expectedEpoch, generation: generation) }
    }

    public func acceptCurrentSessionPresence(expectedSessionID: String, expectedEpoch: UUID) {
        guard expectedSessionID == activeDJSession?.id, expectedEpoch == sessionHistory.responseEpoch,
              !activePresencePending else { return }
        activePresenceDesired = nil; activePresenceRequiresDecision = false; activePresenceError = nil
    }

    private func drainPresence(sessionID: String, epoch: UUID, generation: UUID) async {
        func isCurrent() -> Bool {
            generation == presenceGeneration && epoch == sessionHistory.responseEpoch &&
            activeDJSession?.id == sessionID && isAppInForeground && pairingStatus == .paired &&
            !Task.isCancelled
        }
        defer {
            if generation == presenceGeneration { activePresencePending = false; presenceTask = nil }
        }
        while isCurrent(), activePresenceAvailable, !activePresenceRequiresDecision,
              let desired = activePresenceDesired, let current = activeDJSession?.confirmedPresence {
            if desired == current.selectedPresence { activePresenceDesired = nil; return }
            let intent = presenceIntent
            do {
                let response = try await withHomeAssistantClient(allowsOperationReplay: false) {
                    try await $0.updateSessionPresence(sessionID: sessionID, presence: desired,
                                                       expectedRevision: current.presenceRevision)
                }
                guard isCurrent(), let latest = activeDJSession else { return }
                activeDJSession = latest.applying(presence: response.snapshot)
                // A newer live event can supersede this reply. Never erase a newer gesture.
                if intent == presenceIntent {
                    if activeDJSession?.confirmedPresence?.selectedPresence == desired { activePresenceDesired = nil }
                    else { activePresenceRequiresDecision = true; activePresenceError = localized(key: "ui.session.presence.conflict") }
                }
            } catch {
                guard isCurrent() else { return }
                if let conflict = error as? DJConnectSessionPresenceConflict {
                    if let latest = activeDJSession { activeDJSession = latest.applying(presence: conflict.current) }
                    activePresenceRequiresDecision = true
                    activePresenceError = localized(key: "ui.session.presence.conflict")
                    return
                }
                if (error as? DJConnectError)?.invalidatesSessionAuthority == true {
                    _ = sessionHistory.withdrawAuthority(for: error)
                    let code: String
                    if case .profile = error as? DJConnectError { code = "profile_changed" } else { code = "unauthorized" }
                    await recoverAfterPairedAuthorityWithdrawal(code)
                    return
                }
                // Even a transport error may follow a successful CAS. Reconcile once;
                // the ordinary read may use fallback, but the write never replays.
                _ = await refreshActiveDJSession()
                guard isCurrent() else { return }
                if activeDJSession?.confirmedPresence?.selectedPresence == activePresenceDesired {
                    activePresenceDesired = nil
                } else {
                    activePresenceRequiresDecision = true
                    activePresenceError = localized(key: "ui.session.presence.uncertain")
                }
                return
            }
        }
    }

    func bindProfileDJSettings(active: Bool) {
        let installation = defaults.string(forKey: haInstallIDKey) ?? ""
        let boundary = installation.isEmpty ? homeAssistantURL : installation
        let context: String? = !isDemoMode && pairingStatus == .paired
            ? [identity.deviceID, boundary].joined(separator: "|") : nil
        let owner = profileSettingsOwnerFence.owner(context: context,
            confirmedProfile: sessionHistory.authorizedProfileID)
        profileDJSettings.bind(owner: owner, active: active)
    }

    var profileDJSettingsServices: ProfileDJSettingsModel.Services {
        .init(read: { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.withHomeAssistantClient { try await $0.profileDJSettings() } },
              update: { [weak self] current, patch, id in
                  guard let self else { throw CancellationError() }
                  return try await self.withHomeAssistantClient(allowsOperationReplay: false) {
                      try await $0.updateProfileDJSettings(current, patch: patch, operationID: id)
                  }
              }, receipt: { [weak self] binding, id in
                  guard let self else { throw CancellationError() }
                  return try await self.withHomeAssistantClient { try await $0.profileDJSettingsOperation(binding: binding, operationID: id) }
              })
    }

    public func refreshProfileDJSettings() async {
        guard !profileDJSettingsReadInProgress, isAppInForeground, pairingStatus == .paired, !isDemoMode else { return }
        profileDJSettingsReadInProgress = true
        defer { profileDJSettingsReadInProgress = false }
        bindProfileDJSettings(active: isAppInForeground)
        guard profileDJSettings.active else { return }
        do {
            if !profileDJSettings.negotiated {
                let capability = try await withHomeAssistantClient { try await $0.activeSessionMoodCapabilities() }
                guard capability.sharedSettingsAvailable else { return }
            }
            let before = profileDJSettings.response
            await profileDJSettings.refresh(profileDJSettingsServices)
            if profileDJSettings.hasUncertainOperation {
                presentProfileSettingsRejection(await profileDJSettings.reconcile(profileDJSettingsServices))
            }
            syncSessionSurfaces()
            if before != nil && (before?.binding != profileDJSettings.response?.binding || before?.snapshot != profileDJSettings.response?.snapshot || before?.voice_revision != profileDJSettings.response?.voice_revision) {
                stopResponsePlayback(clearText: false)
                discardActiveVoicePreference()
            }
            startAutomaticSpeechIfNeeded()
        } catch { }
    }

    public func changeProfileDJSettings(_ patch: DJConnectProfileDJSettings.Patch) async {
        bindProfileDJSettings(active: isAppInForeground)
        guard profileDJSettings.canEdit else { return }
        stopResponsePlayback(clearText: false)
        let rejected = await profileDJSettings.change(patch, using: profileDJSettingsServices)
        presentProfileSettingsRejection(rejected)
        syncSessionSurfaces()
        // Rendering reads active Session from its existing owner; no separate write.
        _ = await refreshActiveDJSession()
    }

    private func presentProfileSettingsRejection(_ rejected: DJConnectProfileDJSettingsFailure?) {
        if let rejected {
            let code = rejected.error.range(of: "^[a-z0-9_]{1,80}$", options: .regularExpression) != nil ? rejected.error : "unclassified"
            log(.warning, "Profile DJ settings choice rejected code=\(code)")
            userNotice = DJConnectUserNotice(text: localized(key: "ui.dj_settings.conflict"))
        }
    }

    func reconcileProfileDJSettingsChoice() async {
        presentProfileSettingsRejection(await profileDJSettings.reconcile(profileDJSettingsServices))
        syncSessionSurfaces()
    }

    func scheduleProfileDJChoice(_ patch: DJConnectProfileDJSettings.Patch) {
        guard !isDemoMode, isAppInForeground, pairingStatus == .paired,
              profileDJSettings.canEdit, let binding = profileDJSettings.response?.binding else { return }
        let session = activeDJSession?.id, epoch = sessionHistory.responseEpoch
        profileDJChoiceScheduler.schedule(patch, context: binding + ":" + (session ?? "") + ":" + epoch.uuidString,
            isCurrent: { [weak self] in
                guard let self else { return false }
                return self.isAppInForeground && self.pairingStatus == .paired && self.profileDJSettings.canEdit &&
                    self.profileDJSettings.response?.binding == binding && self.activeDJSession?.id == session &&
                    self.sessionHistory.responseEpoch == epoch
            }, perform: { [weak self] proposed in
                guard let self, let current = self.profileDJSettings.effective else { return }
                var patch = proposed
                if patch.mood == current.mood { patch.mood = nil }
                if patch.persona == current.persona { patch.persona = nil }
                if patch.presence == current.presence { patch.presence = nil }
                guard patch.isValid else { return }
                await self.changeProfileDJSettings(patch)
            })
    }

    private func cancelAutomaticSpeech() {
        automaticSpeechGeneration = UUID()
        automaticSpeechTask?.cancel(); automaticSpeechTask = nil
        automaticSpeechQueue.removeAll()
    }

    private func observeSessionSpeechAutoplay() {
        guard let active = activeDJSession, active.runtimeState == "active", isAppInForeground else {
            speechAutoplayAdmission.reset(); cancelAutomaticSpeech(); return
        }
        let ready = active.broadcast.sessionSpeech.filter { speech in
            speech.autoplayEligible && active.broadcast.djMoments.contains { speech.reference == .moment(sessionID: active.id, momentID: $0.id)
                && speech.admits(reference: speech.reference, text: $0.content) }
        }
        let readyIDs = Set(ready.compactMap { speech -> String? in
            if case .moment(_, let id) = speech.reference { return id }; return nil
        })
        let incoming = speechAutoplayAdmission.observe(sessionID: active.id,
            momentIDs: active.broadcast.djMoments.map(\.id), readyIDs: readyIDs,
            enabled: localResponseAudioEnabled)
        for id in incoming {
            guard let moment = active.broadcast.djMoments.first(where: { $0.id == id }),
                  let speech = ready.first(where: { $0.reference == .moment(sessionID: active.id, momentID: id) }) else { continue }
            enqueueAutomaticSpeech(speech, text: moment.content)
        }
    }

    func autoplayAcceptedDJResponse(_ response: DJConnectAskDJMessageResponse) {
        guard let message = response.assistantMessage, message.role == .assistant,
              message.messageKind != .system, let speech = message.sessionSpeech else { return }
        enqueueAutomaticSpeech(speech, text: message.text)
    }

    private func enqueueAutomaticSpeech(_ speech: DJConnectSessionSpeech, text: String) {
        if automaticSpeechOwner != sessionHistory.responseEpoch {
            cancelAutomaticSpeech(); automaticSpeechClaims.removeAll()
            automaticSpeechOwner = sessionHistory.responseEpoch
        }
        if let output = profileDJSettings.effective?.announcement_output, !output.allowsClientAudio { return }
        guard localResponseAudioEnabled, isAppInForeground, !isDemoMode,
              speech.autoplayEligible, speech.admits(reference: speech.reference, text: text),
              sharedSpeechSourceIsCurrent(speech, text: text),
              automaticSpeechClaims.insert(speech.reference).inserted else { return }
        if automaticSpeechClaims.count > 512 { automaticSpeechClaims = [speech.reference] }
        if automaticSpeechQueue.count >= 16 { automaticSpeechQueue.removeFirst() }
        automaticSpeechQueue.append((speech, text, sessionHistory.responseEpoch))
        startAutomaticSpeechIfNeeded()
    }

    private func startAutomaticSpeechIfNeeded() {
        guard automaticSpeechTask == nil, !automaticSpeechQueue.isEmpty,
              isAppInForeground, localResponseAudioEnabled, sharedDJSpeechAllowed,
              profileDJSettings.effective?.announcement_output.allowsClientAudio == true else { return }
        let generation = automaticSpeechGeneration
        automaticSpeechTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if automaticSpeechGeneration == generation { automaticSpeechTask = nil } }
            while !automaticSpeechQueue.isEmpty, !Task.isCancelled, automaticSpeechGeneration == generation {
                // Do not interrupt another contribution or a manual replay.
                while sharedSpeechIsPreparing || sharedSpeechIsPlaying || deviceSpeechPreviewIsPlaying {
                    do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                    guard automaticSpeechGeneration == generation else { return }
                }
                guard isAppInForeground, localResponseAudioEnabled, sharedDJSpeechAllowed,
                      profileDJSettings.effective?.announcement_output.allowsClientAudio == true else { return }
                let item = automaticSpeechQueue.removeFirst()
                guard item.epoch == sessionHistory.responseEpoch,
                      sharedSpeechSourceIsCurrent(item.speech, text: item.text) else { continue }
                log(.info, "Automatically preparing new DJ contribution audio")
                guard let deadline = item.speech.expiresAt.flatMap(DJConnectHistoryEntry.date) else { continue }
                playSharedDJSpeech(reference: item.speech.reference, acceptedText: item.text, sourceDeadline: deadline,
                    target: .local, original: item.speech, automatic: true,
                    sourceIsCurrent: { [weak self] in self?.sharedSpeechSourceIsCurrent(item.speech, text: item.text) == true })
                #if canImport(AVFoundation)
                let playbackTask = responseAudioPlaybackTask
                await playbackTask?.value
                #endif
            }
        }
    }

    public func replaySharedDJSpeech(_ source: DJConnectSessionSpeech, acceptedText: String, target: DJConnectSharedSpeechTarget) {
        guard let deadline = source.expiresAt.flatMap(DJConnectHistoryEntry.date) else { return }
        playSharedDJSpeech(reference: source.reference, acceptedText: acceptedText, sourceDeadline: deadline, target: target,
            original: source, sourceIsCurrent: { [weak self] in self?.sharedSpeechSourceIsCurrent(source, text: acceptedText) == true })
    }

    func retainedSpeechSourceIsCurrent(_ original: DJConnectHistoryEntry) -> Bool {
        guard sessionHistory.hasAuthorizedOwner, original.isRetained(),
              [.djMoment, .conversationDJ].contains(original.kind),
              original.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return false }
        let rows = (sessionHistory.timelines[original.sessionID]?.entries ?? []) + sessionHistory.searchMatches
            + sessionHistory.historicalMatches.values.flatMap { $0 }
        return rows.contains { $0.reference == original.reference && $0.kind == original.kind && $0.text == original.text
            && $0.occurredAt == original.occurredAt && $0.retainedUntil == original.retainedUntil && $0.isRetained() }
    }

    public func replayRetainedEntrySpeech(_ entry: DJConnectHistoryEntry) {
        guard retainedSpeechSourceIsCurrent(entry), let deadline = DJConnectHistoryEntry.date(entry.retainedUntil), let text = entry.text else { return }
        // Prepare3 reauthorizes this exact retained entry and synthesizes on demand.
        // An expired/missing previous audio asset is never used as the source grant.
        playSharedDJSpeech(reference: .entry(sessionID: entry.sessionID, entryID: entry.id), acceptedText: text,
            sourceDeadline: deadline, target: .local, original: nil,
            sourceIsCurrent: { [weak self] in self?.retainedSpeechSourceIsCurrent(entry) == true })
    }

    private func playSharedDJSpeech(reference: DJConnectSpeechReference, acceptedText: String, sourceDeadline: Date,
        target requestedTarget: DJConnectSharedSpeechTarget, original: DJConnectSessionSpeech?, automatic: Bool = false, sourceIsCurrent: @escaping @MainActor () -> Bool) {
        guard sharedDJSpeechAllowed, let settings = profileDJSettings.response, settings.allowsSpeech(requestedTarget), sourceIsCurrent() else { return }
        let unavailableLocalOverride = deviceSpeechPreferences.enabled && requestedTarget == .both
        // Native output uses the same prepare3 source/settings admission; never
        // speak visible bubble text or bypass it with a legacy preparation.
        guard let target = DJConnectDeviceSpeechRouting.serverTarget(for: requestedTarget, nativeOverride: deviceSpeechPreferences.enabled, settings: settings) else {
            stopResponsePlayback(clearText: false)
            sharedSpeechReference = reference; sharedSpeechDelivery["local"] = "unavailable"
            return
        }
        let preferences = deviceSpeechPreferences
        let nativeLocal = preferences.enabled && target == .local
        #if canImport(AVFoundation)
        personaReactions.cancel(.speechConflict)
        let attemptDeadline = min(sourceDeadline, Date().addingTimeInterval(300))
        guard sourceDeadline > Date(),
              let ticket = responsePlaybackCoordinator.begin(deadline: attemptDeadline) else { return }
        let epoch = sessionHistory.responseEpoch
        // Both manual replay and autoplay enter here. A turn must also belong
        // to a currently accepted live Session response; history alone is insufficient.
        if let scope = currentPersonaScope() {
            let belongs: Bool
            switch reference {
            case .moment(let id, _), .entry(let id, _): belongs = id == scope.sessionID
            case .turn:
                belongs = personaReplyScope == scope && liveConversationPresentations.values.contains {
                    $0.epoch == scope.epoch && $0.sessionID == scope.sessionID && $0.message.sessionSpeech?.reference == reference
                }
            }
            if belongs { personaSpeechObservation = .init(scope: scope, reference: reference, deadline: attemptDeadline) }
        }
        sharedSpeechReference = reference
        sharedSpeechIsPreparing = true
        sharedSpeechDelivery = [target == .haSpeaker ? "ha_speaker" : "local": "preparing"]
        if unavailableLocalOverride { sharedSpeechDelivery["local"] = "unavailable" }
        func current() -> Bool {
            sharedDJSpeechAllowed && epoch == sessionHistory.responseEpoch && isAppInForeground &&
            deviceSpeechPreferences == preferences &&
            profileDJSettings.response?.binding == settings.binding &&
            profileDJSettings.response?.speechFence == settings.speechFence &&
            profileDJSettings.response?.voice_revision == settings.voice_revision &&
            sourceIsCurrent() && responsePlaybackCoordinator.isCurrent(ticket)
        }
        responseAudioPlaybackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { responsePlaybackCoordinator.finish(ticket) }
            guard current(), !Task.isCancelled else { return }
            var stage = "prepare"
            do {
                let result = try await withHomeAssistantClient(allowsOperationReplay: false) {
                    if !nativeLocal {
                        try await self.requireHADeviceSpeech(client: $0, language: self.currentRequestLocale, target: target)
                    }
                    guard current(), !Task.isCancelled else { throw CancellationError() }
                    return try await $0.prepareSharedDJSpeech(reference: reference, acceptedText: acceptedText, settings: settings,
                        target: target, automatic: automatic, processor: nativeLocal ? .localOnDevice : .haConfigured)
                }
                guard current(), !Task.isCancelled else { return }
                sharedSpeechDelivery = result.delivery ?? [:]
                if unavailableLocalOverride { sharedSpeechDelivery["local"] = "unavailable" }
                if target == .haSpeaker {
                    sharedSpeechDelivery["ha_speaker"] = result.delivery?["ha_speaker"] ?? "unknown"
                    responsePlaybackCoordinator.finish(ticket)
                    return
                }
                let prepared = result.session_speech
                guard (nativeLocal ? DJConnectNativeSpeechAdmission.admits(prepared, reference: reference, text: acceptedText, settings: settings) : prepared.audioState == "ready"),
                      prepared.admits(reference: reference, text: acceptedText),
                      original == nil || (prepared.textRevision == original?.textRevision && prepared.presentationRevision == original?.presentationRevision &&
                      prepared.persona == original?.persona && prepared.personaRevision == original?.personaRevision &&
                      prepared.locale == original?.locale && prepared.attribution == original?.attribution),
                      let newDeadline = prepared.expiresAt.flatMap(DJConnectHistoryEntry.date),
                      responsePlaybackCoordinator.shortenDeadline(min(newDeadline, attemptDeadline), for: ticket) else {
                    let reason = prepared.reason.flatMap { value in
                        value.range(of: "^[a-z_]{1,64}$", options: .regularExpression) != nil ? value : nil
                    } ?? "prepared_source_rejected"
                    log(.warning, "Session speech unavailable reason=\(reason)")
                    sharedSpeechDelivery["local"] = "unavailable"; responsePlaybackCoordinator.finish(ticket); return
                }
                if nativeLocal {
                    stage = "native_output"
                    guard let locale = prepared.locale else { throw DJConnectError.invalidResponse }
                    #if os(iOS)
                    try await configureDJConnectAudioSession(category: .playback, mode: .spokenAudio, options: [.duckOthers])
                    guard current(), !Task.isCancelled else { return }
                    try await setDJConnectAudioSessionActive(true)
                    #endif
                    guard current(), !Task.isCancelled else { return }
                    var completed = false
                    deviceSpeechRenderer.onStateChange = nil
                    deviceSpeechRenderer.onPlaybackStateChange = { [weak self] playing in
                        guard let self, self.responsePlaybackCoordinator.isCurrent(ticket),
                              self.isAppInForeground, self.sessionHistory.responseEpoch == epoch else { return }
                        self.sharedSpeechIsPreparing = false
                        self.sharedSpeechIsPlaying = playing
                        self.sharedSpeechDelivery["local"] = playing ? "playing" : "ready"
                    }
                    let started = deviceSpeechRenderer.speak(prepared.segments.map(\.text).joined(), locale: locale,
                        preferences: preferences) { completed = true }
                    guard started else { throw DJConnectError.invalidResponse }
                    log(.info, "Playing admitted DJ contribution with Apple speech")
                    while deviceSpeechRenderer.isSpeaking && current() && !Task.isCancelled {
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    guard current(), !Task.isCancelled else { return }
                    sharedSpeechDelivery["local"] = completed ? "finished" : "failed"
                    log(.info, "Apple DJ contribution playback finished")
                    return
                }
                stage = "audio_fetch"
                let bytes = try await withHomeAssistantClient(allowsOperationReplay: false) {
                    try await $0.speechAudio(prepared, acceptedText: acceptedText)
                }
                guard current(), !Task.isCancelled, prepared.admits(reference: reference, text: acceptedText) else { return }
                stage = "audio_output"
                #if os(iOS)
                try await configureDJConnectAudioSession(category: .playback, mode: .spokenAudio, options: [.duckOthers])
                guard current(), !Task.isCancelled else { return }
                try await setDJConnectAudioSessionActive(true)
                #endif
                guard current(), !Task.isCancelled else { return }
                let player = try AVAudioPlayer(data: bytes)
                guard player.prepareToPlay(), current(), player.play() else { throw DJConnectError.invalidResponse }
                sharedResponseDataPlayer = player; sharedSpeechIsPreparing = false; sharedSpeechIsPlaying = true
                sharedSpeechDelivery["local"] = "playing"
                log(.info, "Playing DJ contribution audio from configured Home Assistant provider")
                while player.isPlaying && current() && !Task.isCancelled { try await Task.sleep(for: .milliseconds(100)) }
                guard current(), !Task.isCancelled else { return }
                sharedSpeechDelivery["local"] = "finished"
                log(.info, "DJ contribution audio playback finished")
                responsePlaybackCoordinator.finish(ticket)
            } catch {
                guard current() else { return }
                let failure = error as NSError
                log(.warning, "Session speech failed stage=\(stage) domain=\(failure.domain) code=\(failure.code)")
                sharedSpeechDelivery[target == .haSpeaker ? "ha_speaker" : "local"] =
                    (error as? DJConnectHybridTransportError) == .deliveryUnknown ? "unknown" : "failed"
                responsePlaybackCoordinator.finish(ticket)
            }
        }
        #endif
    }

    func sharedSpeechSourceIsCurrent(_ speech: DJConnectSessionSpeech, text: String) -> Bool {
        guard speech.admits(reference: speech.reference, text: text), sessionHistory.hasAuthorizedOwner else { return false }
        switch speech.reference {
        case .moment(let session, let id):
            guard let active = activeDJSession, active.id == session, active.runtimeState == "active" else { return false }
            return active.broadcast.sessionSpeech.contains { $0.reference == speech.reference && $0.textRevision == speech.textRevision && $0.presentationRevision == speech.presentationRevision }
                && active.broadcast.djMoments.contains { $0.id == id && $0.content == text }
        case .entry(let session, let id):
            let rows = (sessionHistory.timelines[session]?.entries ?? []) + sessionHistory.searchMatches
                + sessionHistory.historicalMatches.values.flatMap { $0 }
            return rows.contains { $0.sessionID == session && $0.id == id && $0.text == text && $0.isRetained()
                && $0.sessionSpeech?.textRevision == speech.textRevision && $0.sessionSpeech?.presentationRevision == speech.presentationRevision }
        case .turn:
            return askDJMessages.contains { $0.text == text && $0.sessionSpeech?.reference == speech.reference
                && $0.sessionSpeech?.textRevision == speech.textRevision && $0.sessionSpeech?.presentationRevision == speech.presentationRevision }
        }
    }

    public var sharedDJSpeechAllowed: Bool {
        if isDemoMode { return true }
        guard let response = profileDJSettings.response else { return false }
        return profileDJSettings.active && ![.idle, .loading, .saving, .unavailable, .uncertain].contains(profileDJSettings.phase) &&
            !response.requiresSelection && response.voice_availability.available &&
            response.snapshot.effective.announcement_output != .textOnly && !profileDJSettings.hasUncertainOperation
    }

    private var currentVoiceScope: DJConnectSpeechVoiceScope? {
        guard !isDemoMode, pairingStatus == .paired, isAppInForeground,
              let profileID = sessionHistory.authorizedProfileID,
              let session = activeDJSession, session.runtimeState == "active",
              let installationID = defaults.string(forKey: haInstallIDKey) else { return nil }
        return DJConnectSpeechVoiceScope(installationID: installationID, profileID: profileID,
                                         sessionID: session.id, deviceID: identity.deviceID)
    }

    var activeVoiceIsCurrent: Bool {
        currentVoiceScope != nil && activeVoicePreference.scope == currentVoiceScope
    }

    func discardActiveVoicePreference() {
        activeVoicePreference.discard(); activeVoiceError = nil; activeVoiceRetryAfter = nil
    }

    func invalidateActiveVoiceInventory() {
        activeVoicePreference.invalidateInventory(); activeVoiceError = nil
    }

    func activeVoiceOwnerDidChange() {
        bindProfileDJSettings(active: isAppInForeground)
        bindPassiveSessionSurfaces()
        guard sessionHistory.hasAuthorizedOwner else { invalidateActiveVoiceInventory(); return }
        if let scope = currentVoiceScope {
            if activeVoicePreference.scope != scope { activeVoiceRetryAfter = nil }
            activeVoicePreference.bind(scope)
        }
        if activeVoiceMenuOpen { Task { await refreshActiveVoiceOptions() } }
    }

    func setActiveVoiceMenuOpen(_ open: Bool) { activeVoiceMenuOpen = open }

    public func refreshActiveVoiceOptions() async {
        guard let scope = currentVoiceScope else { invalidateActiveVoiceInventory(); return }
        if activeVoicePreference.scope != scope { activeVoiceRetryAfter = nil }
        activeVoicePreference.bind(scope)
        guard !activeVoicePreference.refreshing else { return }
        guard activeVoiceRetryAfter.map({ $0 <= Date() }) ?? true else { return }
        let epoch = sessionHistory.responseEpoch
        guard let refresh = activeVoicePreference.beginRefresh() else { return }
        activeVoiceError = nil
        do {
            let options = try await withHomeAssistantClient { try await $0.speechVoiceOptions() }
            guard currentVoiceScope == scope, epoch == sessionHistory.responseEpoch,
                  activeVoicePreference.isCurrentRefresh(refresh) else { return }
            guard activeVoicePreference.completeRefresh(refresh, options: options) else {
                activeVoiceError = localized(key: "ui.session.voice.unavailable"); return
            }
            let delay = max(options.providerStatus?.retryAfterSeconds ?? 0, options.notification?.retryAfterSeconds ?? 0)
            activeVoiceRetryAfter = delay > 0 ? Date().addingTimeInterval(Double(delay)) : nil
        } catch {
            guard currentVoiceScope == scope, epoch == sessionHistory.responseEpoch,
                  activeVoicePreference.isCurrentRefresh(refresh) else { return }
            _ = activeVoicePreference.completeRefresh(refresh, options: nil)
            if sessionHistory.withdrawAuthority(for: error) { return }
            activeVoiceError = localized(key: "ui.session.voice.unavailable")
        }
    }

    public func selectActiveVoice(_ voiceID: String?, expectedScope: DJConnectSpeechVoiceScope, expectedEpoch: UUID) {
        guard currentVoiceScope == expectedScope, activeVoicePreference.scope == expectedScope,
              expectedEpoch == sessionHistory.responseEpoch else { return }
        if profileDJSettings.negotiated, let inventory = profileDJSettings.response?.allowed_values.voice {
            let voice = voiceID.map { DJConnectProfileDJSettings.Voice(kind: .providerVoice, providerID: inventory.provider_id, voiceID: $0) } ?? .init()
            Task { await changeProfileDJSettings(.init(voice: voice)) }
            return
        }
        _ = activeVoicePreference.select(voiceID)
    }

    public func selectActiveVoiceGender(_ preference: DJConnectVoicePreference, expectedScope: DJConnectSpeechVoiceScope, expectedEpoch: UUID) {
        guard currentVoiceScope == expectedScope, activeVoicePreference.scope == expectedScope,
              expectedEpoch == sessionHistory.responseEpoch else { return }
        if profileDJSettings.negotiated {
            Task { await changeProfileDJSettings(.init(gender: preference)) }
            return
        }
        _ = activeVoicePreference.selectGender(preference)
    }

    public func changeActiveSessionPersona(_ persona: DJConnectSessionPersonaValue, expectedSessionID: String, expectedEpoch: UUID) async {
        if activeSharedSettingsRequired || profileDJSettings.negotiated {
            guard expectedSessionID == activeDJSession?.id, expectedEpoch == sessionHistory.responseEpoch,
                  profileDJSettings.response?.snapshot.session?.session_id == expectedSessionID,
                  profileDJSettings.canEdit else { return }
            scheduleProfileDJChoice(.init(persona: persona))
            return
        }
        guard !isDemoMode, activePersonaAvailable, !activePersonaPending, isAppInForeground,
              pairingStatus == .paired, sessionHistory.hasAuthorizedOwner,
              expectedEpoch == sessionHistory.responseEpoch,
              let current = activeDJSession, current.id == expectedSessionID, current.runtimeState == "active",
              let confirmed = current.confirmedPersona else { return }
        let generation = UUID(); personaOperationGeneration = generation
        activePersonaPending = true; activePersonaError = nil
        defer { if generation == personaOperationGeneration { activePersonaPending = false } }
        func valid() -> Bool {
            generation == personaOperationGeneration && expectedEpoch == sessionHistory.responseEpoch &&
            pairingStatus == .paired && isAppInForeground && sessionHistory.hasAuthorizedOwner &&
            activeDJSession?.id == expectedSessionID && activeDJSession?.runtimeState == "active"
        }
        do {
            let response = try await withHomeAssistantClient(allowsOperationReplay: false) {
                try await $0.updateSessionPersona(sessionID: expectedSessionID, persona: persona, expectedRevision: confirmed.personaRevision)
            }
            guard valid(), let latest = activeDJSession else { return }
            activeDJSession = latest.applying(persona: response.snapshot)
        } catch let conflict as DJConnectSessionPersonaConflict {
            guard valid(), let latest = activeDJSession else { return }
            activeDJSession = latest.applying(persona: conflict.current)
            activePersonaError = localized(key: "ui.session.persona.conflict")
        } catch {
            guard valid() else { return }
            if sessionHistory.withdrawAuthority(for: error) { return }
            // A lost reply may follow a commit. Reread once; never repeat the write.
            _ = await refreshActiveDJSession()
            guard valid() else { return }
            activePersonaError = localized(key: "ui.session.persona.failed")
        }
    }

    public func changeActiveSessionMood(_ mood: String, expectedSessionID: String? = nil, expectedEpoch: UUID? = nil) async {
        guard expectedSessionID == nil || activeDJSession?.id == expectedSessionID,
              expectedEpoch == nil || sessionHistory.responseEpoch == expectedEpoch else { return }
        if isDemoMode {
            guard var demo = activeDJSession, ["chill", "groove", "energy", "party"].contains(mood) else { return }
            let revision = (demo.confirmedMoodRevision ?? 0) + (demo.selectedMood == mood ? 0 : 1)
            demo.selectedMood = mood; demo.moodRevision = revision
            demo.broadcast.session.selectedMood = mood; demo.broadcast.session.moodRevision = revision
            activeDJSession = demo; return
        }
        if activeSharedSettingsRequired || profileDJSettings.negotiated {
            guard profileDJSettings.response?.snapshot.session?.session_id == activeDJSession?.id,
                  profileDJSettings.canEdit else { return }
            scheduleProfileDJChoice(.init(mood: mood))
            return
        }
        guard activeMoodAvailable, !activeMoodPending, isAppInForeground, pairingStatus == .paired,
              let current = activeDJSession, let revision = current.confirmedMoodRevision,
              ["chill", "groove", "energy", "party"].contains(mood) else { return }
        let epoch = sessionHistory.responseEpoch
        let generation = UUID(); moodOperationGeneration = generation
        activeMoodPending = true; activeMoodError = nil
        defer { if generation == moodOperationGeneration { activeMoodPending = false } }
        do {
            let response = try await withHomeAssistantClient(allowsOperationReplay: false) { try await $0.updateSessionMood(sessionID: current.id, mood: mood, expectedRevision: revision) }
            guard generation == moodOperationGeneration, epoch == sessionHistory.responseEpoch, pairingStatus == .paired, isAppInForeground,
                  let latest = activeDJSession, latest.id == current.id else { return }
            activeDJSession = latest.applying(mood: response)
        } catch {
            guard generation == moodOperationGeneration, epoch == sessionHistory.responseEpoch, activeDJSession?.id == current.id else { return }
            if sessionHistory.withdrawAuthority(for: error) { return }
            else {
                // Conflict or a lost reply: reread once, never replay the stale write.
                _ = await refreshActiveDJSession()
            }
            guard generation == moodOperationGeneration, epoch == sessionHistory.responseEpoch, activeDJSession?.id == current.id else { return }
            activeMoodError = localized(key: "ui.session.mood.failed")
        }
    }

    public func startDJSession() async {
        if isDemoMode {
            if activeDJSession == nil { applyDemoSessionExamples() }
            presentSessionIntroductionIfNeeded()
            return
        }
        guard pairingStatus == .paired, canUsePlaybackFeatures, !isLoadingDJSession else { return }
        let request = UUID()
        sessionRequestGeneration = request
        isLoadingDJSession = true
        defer { if request == sessionRequestGeneration { isLoadingDJSession = false } }
        do {
            let response = try await withHomeAssistantClient(allowsOperationReplay: false, notifiesTransportFailure: false) { client in
                try await client.startSession(
                    DJConnectSessionStartRequest(
                        mood: selectedSessionMood,
                        language: currentRequestLocale
                    )
                )
            }
            guard request == sessionRequestGeneration, pairingStatus == .paired else { return }
            guard response.success else { djSessionErrorMessage = localized(key: "ui.session.unavailable"); return }
            guard let incoming = response.resolvedSession, incoming.broadcast.session.sessionID == incoming.sessionID else {
                clearSessionProjection()
                djSessionErrorMessage = localized(key: "ui.session.unavailable")
                return
            }
            vibeCastHandoffApproved = false
            vibeCastHandoffFailed = false
            activeDJSession = incoming
            djSessionErrorMessage = response.resolvedSession == nil ? localized(key: "ui.session.unavailable") : nil
            startSessionBroadcastIfNeeded()
            presentSessionIntroductionIfNeeded()
        } catch let outcome as DJConnectHybridTransportError {
            guard request == sessionRequestGeneration else { return }
            switch outcome {
            case .outcome, .deliveryUnknown:
                // A missing acknowledgement is not proof that Start failed.
                // Read the canonical state; never replay a potentially accepted Start.
                log(.info, "Session start acknowledgement unavailable; reading canonical state")
                isLoadingDJSession = false
                let recovered = await refreshActiveDJSession()
                if recovered, activeDJSession != nil { presentSessionIntroductionIfNeeded() }
                else if djSessionErrorMessage == nil { djSessionErrorMessage = localized(key: "ui.session.unavailable") }
            default:
                djSessionErrorMessage = localized(key: outcome.localizationKey)
            }
        } catch {
            guard request == sessionRequestGeneration else { return }
            djSessionErrorMessage = localized(key: "ui.session.unavailable")
        }
    }

    private func presentSessionIntroductionIfNeeded() {
        guard activeDJSession != nil, !defaults.bool(forKey: "DJConnectSessionIntroductionSeenV1") else { return }
        // Client UI onboarding belongs to this installation, never to a profile.
        defaults.set(true, forKey: "DJConnectSessionIntroductionSeenV1")
        isSessionIntroductionPresented = true
    }

    public func dismissSessionIntroduction() {
        isSessionIntroductionPresented = false
    }

    public func retryDJSessionConnection() async {
        stopSessionBroadcast()
        await refreshActiveDJSession()
    }

    public func endDJSession() async {
        if isDemoMode {
            if let id = activeDJSession?.id {
                sessionHistory.archiveDemoSession(id)
            }
            activeDJSession = nil; activeMoodAvailable = false; djSessionErrorMessage = nil; return
        }
        guard let sessionID = activeDJSession?.sessionID, !isLoadingDJSession else { return }
        let request = UUID()
        sessionRequestGeneration = request
        isLoadingDJSession = true
        defer { if request == sessionRequestGeneration { isLoadingDJSession = false } }
        do {
            let response = try await withHomeAssistantClient(allowsOperationReplay: false) { client in
                try await client.endSession(DJConnectSessionEndRequest(sessionID: sessionID))
            }
            guard request == sessionRequestGeneration, activeDJSession?.id == sessionID else { return }
            guard response.success else { throw DJConnectError.invalidResponse }
            activeDJSession = nil
            djSessionErrorMessage = nil
            vibeCastHandoffApproved = false
            vibeCastHandoffFailed = false
            stopSessionBroadcast()
            isLoadingDJSession = false

        } catch {
            guard request == sessionRequestGeneration else { return }
            if (error as? DJConnectError)?.invalidatesSessionAuthority == true { clearSessionProjection() }
            djSessionErrorMessage = localized(key: "ui.session.unavailable")
        }
    }

    public func approveVibeCastHandoff(code: String) async {
        guard !isLoadingVibeCastHandoff else { return }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAppInForeground, pairingStatus == .paired,
              let sessionID = activeDJSession?.sessionID,
              normalized.count == 6,
              normalized.unicodeScalars.allSatisfy({ $0.value >= 48 && $0.value <= 57 }) else {
            vibeCastHandoffApproved = false; vibeCastHandoffFailed = true
            vibeCastHandoffErrorKey = "ui.vibecast.handoff.failed"
            return
        }
        let request = UUID(), epoch = sessionHistory.responseEpoch
        vibeCastHandoffGeneration = request
        let valid = { self.vibeCastHandoffGeneration == request && self.sessionHistory.responseEpoch == epoch
            && self.activeDJSession?.id == sessionID && self.isAppInForeground && self.pairingStatus == .paired }
        isLoadingVibeCastHandoff = true
        vibeCastHandoffApproved = false; vibeCastHandoffFailed = false; vibeCastHandoffErrorKey = nil
        defer { if vibeCastHandoffGeneration == request { isLoadingVibeCastHandoff = false } }
        do {
            // A code can be consumed before its response is lost. Never replay
            // this approval automatically on another route.
            let response = try await withHomeAssistantClient(allowsOperationReplay: false) { client in
                try await client.approveVibeCastHandoff(
                    DJConnectVibeCastHandoffApprovalRequest(sessionID: sessionID, code: normalized))
            }
            guard valid() else { return }
            vibeCastHandoffApproved = response.success && response.handoff == "approved" && response.sessionID == sessionID
            vibeCastHandoffFailed = !vibeCastHandoffApproved
            if vibeCastHandoffFailed {
                vibeCastHandoffErrorKey = response.error == "handoff_code_unavailable"
                    ? "ui.vibecast.handoff.code_unavailable" : "ui.vibecast.handoff.unconfirmed"
            }
        } catch {
            guard valid() else { return }
            vibeCastHandoffFailed = true
            vibeCastHandoffErrorKey = (error as? DJConnectError).map(Self.describe)?.contains("handoff_code_unavailable") == true
                ? "ui.vibecast.handoff.code_unavailable" : "ui.vibecast.handoff.unconfirmed"
        }
    }

    private func startSessionBroadcastIfNeeded() {
        guard let session = activeDJSession,
              let baseURL = homeAssistantBaseURLs().first,
              let deviceToken = try? tokenStore.loadToken() else {
            stopSessionBroadcast()
            return
        }
        guard isAppInForeground, pairingStatus == .paired else { stopSessionBroadcast(); return }
        guard sessionBroadcastSessionID != session.id || sessionBroadcastTransport == nil else { return }
        sessionContributionRecoveryTask?.cancel(); sessionContributionRecoveryTask = nil
        sessionContributionRecoveryNeeded = true
        sessionBroadcastGeneration = UUID()
        let generation = sessionBroadcastGeneration
        sessionBroadcastSessionID = session.id
        if sessionRecoveryCursorSessionID != session.id {
            sessionRecoveryCursor = nil; sessionRecoveryCursorSessionID = session.id
        }
        Task { [self] in
        var baseURL = baseURL
        if let hybrid = sharedHybridTransport() {
            do { baseURL = try await hybrid.authorizedBaseURL() }
            catch { return }
        }
        guard sessionBroadcastGeneration == generation, isAppInForeground, pairingStatus == .paired else { return }
        let transport: DJConnectSessionBroadcastTransport
        if let auth = homeAssistantWebSocketAuth {
            // Explicit legacy/test HA credentials only; no automatic issuer fallback.
            transport = DJConnectSessionBroadcastTransport(baseURL: baseURL, auth: auth, session: urlSession)
        } else {
            let client = DJConnectClient(baseURL: baseURL, identity: identity, tokenStore: tokenStore, session: urlSession)
            let store = tokenStore
            transport = DJConnectSessionBroadcastTransport(baseURL: baseURL, session: urlSession,
                discover: { try await client.pairedOwnerLiveCapability() }, pairedToken: { try store.loadToken() },
                httpRecovery: { [weak self] in
                    guard let self else { throw CancellationError() }
                    if let hybrid = await self.sharedHybridTransport(), let cursor = await self.sessionRecoveryCursor {
                        let recovery = try await hybrid.broadcastRecovery(sessionID: session.sessionID, cursor: cursor)
                        await MainActor.run {
                            guard self.sessionBroadcastGeneration == generation else { return }
                            self.sessionRecoveryCursor = recovery.recoveryCursor
                            if recovery.recovery == "snapshot_required" { self.sessionContributionRecoveryNeeded = true }
                            for event in recovery.events ?? [] { self.applySessionBroadcastEvent(event) }
                        }
                        if let snapshot = recovery.snapshot { return snapshot }
                    }
                    let response = try await self.withHomeAssistantClient { try await $0.activeSession() }
                    guard response.success else { throw DJConnectError.invalidResponse }
                    return response.resolvedSession?.personaSafeBroadcast
                })
        }
        let previousTransport = sessionBroadcastTransport
        sessionBroadcastTransport = transport
        Task { await previousTransport?.stop() }
        let apiIdentity = DJConnectAPIIdentity(identity: identity, deviceToken: deviceToken)
            guard sessionBroadcastGeneration == generation else { return }
            await transport.start(
                sessionID: session.sessionID,
                identity: apiIdentity,
                onSnapshot: { [weak self] subscription in
                    await MainActor.run {
                        guard let self, self.sessionBroadcastGeneration == generation else { return }
                        self.sessionRecoveryCursor = subscription.recoveryCursor
                        self.applySessionBroadcastSnapshot(subscription.snapshot)
                        self.recoverSessionContributionsIfNeeded(sessionID: session.sessionID, generation: generation)
                    }
                },
                onEvent: { [weak self] event in
                    await MainActor.run {
                        guard let self, self.sessionBroadcastGeneration == generation else { return }
                        self.applySessionBroadcastEvent(event)
                    }
                },
                onTerminated: { [weak self] in
                    await MainActor.run {
                        guard let self, self.sessionBroadcastGeneration == generation else { return }
                        self.invalidateSessionRequest()
                        self.activeDJSession = nil
                        self.djSessionErrorMessage = nil
                        self.vibeCastHandoffApproved = false
                        self.vibeCastHandoffFailed = false
                        self.stopSessionBroadcast()
                    }
                },
                onUnavailable: { [weak self] in
                    await MainActor.run {
                        guard let self, self.sessionBroadcastGeneration == generation else { return }
                        self.clearSessionProjection()
                        self.djSessionErrorMessage = self.localized(key: "ui.session.unavailable")
                    }
                },
                onDisconnected: { [weak self] in
                    await MainActor.run {
                        guard let self, self.sessionBroadcastGeneration == generation else { return }
                        self.activeDJSession?.broadcast.clearNativeAuthority()
                        self.sessionContributionRecoveryNeeded = true
                        self.djSessionIsRecovering = self.activeDJSession != nil
                    }
                },
                onConnectionUnavailable: { [weak self] in
                    await MainActor.run {
                        guard let self, self.sessionBroadcastGeneration == generation else { return }
                        // The optional live route is absent, not revoked. The
                        // authenticated HTTP snapshot retains its original grants;
                        // HTTP recovery still withdraws on actual owner refusal.
                        if self.homeAssistantWebSocketAuth != nil {
                            // Explicit legacy/test transport has no HTTP recovery.
                            self.activeDJSession?.broadcast.clearNativeAuthority()
                            self.djSessionIsRecovering = false
                            self.djSessionLiveUnavailable = self.activeDJSession != nil
                        } else {
                            self.djSessionIsRecovering = self.activeDJSession != nil && self.activeDJSession?.broadcast.nativeDelivery == nil
                            self.djSessionLiveUnavailable = false
                            self.log(.info, "Optional session live subscription unavailable; using owner HTTP recovery")
                        }
                    }
                },
                onAuthorityWithdrawn: { [weak self] code in
                    await self?.handlePairedAuthorityWithdrawal(code, broadcastGeneration: generation)
                },
                onHTTPSnapshot: { [weak self] snapshot in
                    await MainActor.run {
                        guard let self, self.sessionBroadcastGeneration == generation else { return }
                        self.applySessionBroadcastSnapshot(snapshot)
                        self.recoverSessionContributionsIfNeeded(sessionID: session.sessionID, generation: generation)
                    }
                }
            )
        }
    }

    private func recoverSessionContributionsIfNeeded(sessionID: String, generation: UUID) {
        guard sessionContributionRecoveryNeeded, sessionContributionRecoveryTask == nil,
              sessionBroadcastGeneration == generation, activeDJSession?.id == sessionID,
              isAppInForeground, pairingStatus == .paired else { return }
        let epoch = sessionHistory.responseEpoch
        sessionContributionRecoveryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if sessionBroadcastGeneration == generation { sessionContributionRecoveryTask = nil } }
            let recovered = await sessionHistory.recoverContributions(sessionID)
            guard !Task.isCancelled, sessionBroadcastGeneration == generation,
                  sessionHistory.responseEpoch == epoch, activeDJSession?.id == sessionID else { return }
            if recovered { sessionContributionRecoveryNeeded = false }
        }
    }

    private func handlePairedAuthorityWithdrawal(_ code: String, broadcastGeneration: UUID) async {
        guard sessionBroadcastGeneration == broadcastGeneration else { return }
        await recoverAfterPairedAuthorityWithdrawal(code)
    }

    func recoverAfterPairedAuthorityWithdrawal(_ code: String) async {
        cancelVoiceRecording()
        clearAskDJHistoryLocally()
        clearRuntimeState(backendAvailableAfterClear: false)
        voiceErrorMessage = nil
        if ["invalid_auth", "invalid_identity", "unauthorized", "pairing_revoked"].contains(code) {
            // Core currently also emits pairing_revoked on runtime replacement.
            // Private projections are already withdrawn; retain the credential
            // until an independent HTTP response proves it is invalid.
            isConnected = false
            guard canRefreshSessionHistory, let token = try? tokenStore.loadToken(), !token.isEmpty else { return }
            pairedIdentityRecoveryTask?.cancel()
            let generation = UUID(); pairedIdentityRecoveryGeneration = generation
            let task = Task { @MainActor [weak self] in
                guard let self else { return }
                await self.revalidatePairedIdentity(expectedToken: token, generation: generation)
            }
            pairedIdentityRecoveryTask = task
            await task.value
            if pairedIdentityRecoveryGeneration == generation { pairedIdentityRecoveryTask = nil }
            return
        }
        guard code == "profile_changed", canRefreshSessionHistory else {
            djSessionErrorMessage = localized(key: "ui.session.unavailable")
            return
        }
        let request = sessionRequestGeneration
        let epoch = sessionHistory.responseEpoch
        await sessionHistory.prepare()
        guard request == sessionRequestGeneration, epoch == sessionHistory.responseEpoch,
              canRefreshSessionHistory, !Task.isCancelled else { return }
        await refreshActiveDJSession()
    }

    private func revalidatePairedIdentity(expectedToken: String, generation: UUID) async {
        let configuration = [homeAssistantURL, haRemoteURL, defaults.string(forKey: haInstallIDKey) ?? ""]
        func current() -> Bool {
            canRefreshSessionHistory && pairedIdentityRecoveryGeneration == generation &&
            configuration == [homeAssistantURL, haRemoteURL, defaults.string(forKey: haInstallIDKey) ?? ""] &&
            (try? tokenStore.loadToken()) == expectedToken && !Task.isCancelled
        }
        // Only bounded status reads; never repeat push registration or a mutation.
        for attempt in 0..<3 {
            guard current() else { return }
            do {
                try await withHomeAssistantClient { try await $0.validatePairedIdentity() }
                guard current() else { return }
                isConnected = true
                log(.info, "Paired live withdrawal revalidated_http=true retained_pairing=true")
                if startBackgroundTasks { schedulePairedRefresh(reason: "Paired live runtime replaced") }
                return
            } catch let error as DJConnectError {
                guard current() else { return }
                if case .authStale = error {
                    log(.warning, "Paired identity rejected by canonical HTTP; withdrawing pairing")
                    apply(error: error)
                    return
                }
                let retryable: Bool
                switch error {
                case .network, .notConfigured: retryable = true
                case .server(let status, _): retryable = status == 503
                default: retryable = false
                }
                if !retryable || attempt == 2 { break }
                do { try await Task.sleep(for: .milliseconds(attempt == 0 ? 250 : 750)) }
                catch { return }
            } catch { break }
        }
        guard current() else { return }
        log(.warning, "Paired live recovery pending; credential retained and private state unavailable")
        djSessionErrorMessage = localized(key: "ui.transport.recovering")
    }

    private func resetActivePersonaState() {
        personaOperationGeneration = UUID()
        activePersonaReactionAvailable = false
        activePersonaAvailable = false; activePersonaPending = false; activePersonaError = nil
    }

    private func resetActiveMoodState() {
        activeSharedSettingsRequired = false
        presenceGeneration = UUID(); presenceIntent = UUID()
        presenceTask?.cancel(); presenceTask = nil
        activePresenceAvailable = false; activePresencePending = false
        activePresenceCapabilityStatus = .notLoaded
        activePresenceDesired = nil; activePresenceRequiresDecision = false; activePresenceError = nil
        resetActivePersonaState()
        moodOperationGeneration = UUID(); moodCapabilityGeneration = UUID()
        activeMoodAvailable = false; activeMoodPending = false; activeMoodError = nil
    }

    private func invalidateSessionRequest() {
        resetActiveMoodState()
        sessionRequestGeneration = UUID()
        isLoadingDJSession = false
    }

    private func clearSessionProjection() {
        invalidateSessionRequest()
        activeDJSession = nil
        sessionRecoveryCursor = nil
        vibeCastHandoffApproved = false
        vibeCastHandoffFailed = false
        stopSessionBroadcast()
    }

    private func stopSessionBroadcast() {
        sessionContributionRecoveryTask?.cancel(); sessionContributionRecoveryTask = nil
        sessionContributionRecoveryNeeded = true
        guard !isDemoMode else { return }
        djSessionLiveUnavailable = false
        djSessionIsRecovering = activeDJSession != nil
        activeDJSession?.broadcast.clearNativeAuthority()
        sessionBroadcastGeneration = UUID()
        sessionBroadcastSessionID = nil
        let transport = sessionBroadcastTransport
        sessionBroadcastTransport = nil
        Task { await transport?.stop() }
    }

    private func applySessionBroadcastSnapshot(_ snapshot: DJConnectBroadcastState) {
        guard let active = activeDJSession, active.sessionID == snapshot.session.sessionID else { return }
        activeDJSession = active.applying(broadcastState: snapshot)
        djSessionIsRecovering = false
        djSessionLiveUnavailable = false
    }

    private func applySessionBroadcastEvent(_ event: DJConnectSessionBroadcastEvent) {
        guard let active = activeDJSession, active.sessionID == event.sessionID else { return }
        if event.eventType == "runtime_ended" || event.eventType == "broadcast_stopped" {
            if event.payload.nativeDelivery?.revocationScope == "subscription" {
                invalidateSessionRequest()
                activeDJSession = active.applying(broadcastEvent: event)
                stopSessionBroadcast()
                return
            }
            invalidateSessionRequest()
            activeDJSession = nil
            djSessionErrorMessage = nil
            vibeCastHandoffApproved = false
            vibeCastHandoffFailed = false
            stopSessionBroadcast()
            return
        }
        activeDJSession = active.applying(broadcastEvent: event)
        if let hint = event.payload.passiveSurfaceInvalidation, hint.validates(sessionID: active.id) {
            passiveSurfaces.invalidate(sequence: hint.delivery_sequence, services: passiveSurfaceServices)
        }
    }

    private var endpointStatusRefreshAt: Date?
    private var endpointStatusRefreshInProgress = false

    /// Only an authenticated, current status response may amend paired routes.
    @discardableResult
    func applyStatusEndpoints(_ response: DJConnectEnvelope<DJConnectPlayback>, expectedLocal: String, expectedRemote: String, expectedInstall: String?) -> Bool {
        guard response.success, !isDemoMode, pairingStatus == .paired,
              haLocalURL == expectedLocal, haRemoteURL == expectedRemote,
              defaults.string(forKey: haInstallIDKey) == expectedInstall,
              expectedInstall?.isEmpty == false, response.haInstallID == expectedInstall else { return false }
        defer {
            deviceSpeechContext = currentDeviceSpeechContext
            deviceSpeechAvailability = response.deviceSpeech
        }
        func endpoint(_ value: String?, remote: Bool) -> String? {
            guard let value, let c = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
                  c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
                  c.path.isEmpty || c.path == "/", let url = c.url,
                  DJConnectHybridTransport.trustedOrigin(url) || (!remote && DJConnectHybridTransport.isLocalTransportCandidate(url)) else { return nil }
            return Self.redactedURL(url).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        let local = endpoint(response.haLocalURL, remote: false) ?? haLocalURL
        let remote = response.remoteSupported == false ? "" : (endpoint(response.haRemoteURL, remote: true) ?? haRemoteURL)
        guard local != haLocalURL || remote != haRemoteURL else { return false }
        haLocalURL = local; haRemoteURL = remote
        if !local.isEmpty { homeAssistantURL = local }
        defaults.set(local, forKey: haLocalURLKey)
        defaults.set(remote, forKey: haRemoteURLKey)
        if let supported = response.remoteSupported { remoteSupported = supported }
        else if !remote.isEmpty { remoteSupported = true }
        localTransportProbeAfter = nil
        defaults.removeObject(forKey: "DJConnectHAActiveURL")
        hybridTransportKey = nil
        _ = sharedHybridTransport()
        if startBackgroundTasks, isAppInForeground, activeDJSession != nil {
            stopSessionBroadcast(); startSessionBroadcastIfNeeded()
        }
        return true
    }

    func refreshConnectionEndpointsIfNeeded(client: DJConnectClient) async throws {
        guard !endpointStatusRefreshInProgress,
              endpointStatusRefreshAt.map({ Date().timeIntervalSince($0) >= 60 }) ?? true else { return }
        endpointStatusRefreshInProgress = true
        deviceSpeechAvailability = nil
        let speechContext = currentDeviceSpeechContext
        defer { endpointStatusRefreshInProgress = false }
        let local = haLocalURL, remote = haRemoteURL, install = defaults.string(forKey: haInstallIDKey)
        let epoch = sessionHistory.responseEpoch
        endpointStatusRefreshAt = Date()
        do {
            let response = try await client.postStatus(DJConnectStatusPayload(identity: identity, haPairingStatus: .paired,
                language: currentRequestLocale, logLevel: logLevel, appBuild: buildVersion,
                localAudioSupported: true, voiceSupported: voiceEnabled, haLocalURL: local.isEmpty ? nil : local,
                voiceEnabled: voiceEnabled, wakewordEnabled: wakeWordEnabled, wakewordPhrase: wakeWordPhrase,
                wakewordStatus: "\(wakeWordStatus)", mood: confirmedSessionMoodInt, musicDNAKey: askDJMusicDNAKey))
            guard !Task.isCancelled, epoch == sessionHistory.responseEpoch, isAppInForeground,
                  speechContext == currentDeviceSpeechContext else { return }
            _ = applyStatusEndpoints(response, expectedLocal: local, expectedRemote: remote, expectedInstall: install)
        } catch {
            if (error as? DJConnectError)?.invalidatesSessionAuthority == true { throw error }
            // Metadata failure cannot discard a successful playback snapshot.
            log(.debug, "Connection metadata refresh deferred")
        }
    }

    private func refreshStatus(client: DJConnectClient, bindToHistoryEpoch: Bool = true,
                               isStillValid: (@MainActor () -> Bool)? = nil) async throws {
        let local = haLocalURL, remote = haRemoteURL, install = defaults.string(forKey: haInstallIDKey)
        let epoch = sessionHistory.responseEpoch
        deviceSpeechAvailability = nil
        let speechContext = currentDeviceSpeechContext
        do {
            guard isStillValid?() != false else { throw CancellationError() }
            log(.debug, "Posting status to Home Assistant")
            let response = try await client.postStatus(
                DJConnectStatusPayload(
                    identity: identity,
                    haPairingStatus: .paired,
                    language: currentRequestLocale,
                    logLevel: logLevel,
                    appBuild: buildVersion,
                    localAudioSupported: true,
                    voiceSupported: voiceEnabled,
                    haLocalURL: haLocalURL.isEmpty ? nil : haLocalURL,
                    voiceEnabled: voiceEnabled,
                    wakewordEnabled: wakeWordEnabled,
                    wakewordPhrase: wakeWordPhrase,
                    wakewordStatus: "\(wakeWordStatus)",
                    mood: confirmedSessionMoodInt,
                    musicDNAKey: askDJMusicDNAKey
                )
            )
            guard isStillValid?() != false else { throw CancellationError() }
            guard validateHomeAssistantVersion(
                haVersion: response.haVersion,
                haMajorMinor: response.haMajorMinor,
                message: response.message
            ) else {
                return
            }
            guard speechContext == currentDeviceSpeechContext,
                  (!bindToHistoryEpoch || epoch == sessionHistory.responseEpoch), haLocalURL == local, haRemoteURL == remote,
                  defaults.string(forKey: haInstallIDKey) == install,
                  install == nil || response.haInstallID == nil || response.haInstallID == install else { throw CancellationError() }
            _ = applyStatusEndpoints(response, expectedLocal: local, expectedRemote: remote, expectedInstall: install)
            endpointStatusRefreshAt = Date()
            applyBootstrapContext(
                haInstallID: response.haInstallID,
                integrationVersion: response.integrationVersion,
                pairingSessionID: response.pairingSessionID
            )
            apply(musicBackendSummary: response.musicBackendSummary)
            apply(djAnnouncementCapabilities: response.djAnnouncement)
            let hasPlaybackSnapshot = response.playback != nil
            if let playback = response.playback {
                apply(playback: playback)
            } else {
                log(.debug, "Status response did not include a playback snapshot")
            }
            if !Self.isRunningUnderSwiftPMTests, !defaults.bool(forKey: pushRegisteredKey) {
                requestRemoteNotificationRegistration()
            }
            registerStoredPushTokenIfPossible()
            authenticatedStatusOrigin = client.baseURL
            markHomeAssistantReachable(backendAvailableAfterResponse: hasPlaybackSnapshot ? true : (response.backendAvailable ?? true))
            if backendAvailable {
                clearRecoverableVoiceErrorIfNeeded()
            }
            log(.debug, "Status refresh succeeded")
        } catch let error as DJConnectError {
            guard isStillValid?() != false else { throw CancellationError() }
            log(.warning, "Status refresh failed: \(Self.describe(error))")
            switch error {
            case .backendUnavailable:
                apply(error: error)
                pairingStatus = .paired
                isConnected = true
            case let .routeMissing(message):
                if pairingStatus == .waitingForHomeAssistantCompletion {
                    throw error
                }
                applyConnectionUnavailableState(message: message ?? Self.describe(error))
                pairingStatus = .paired
                isConnected = false
            default:
                apply(error: error)
                throw error
            }
        }
    }

    private func refreshBackendCollections(force: Bool = false, isStillValid: (@MainActor () -> Bool)? = nil) async {
        guard isStillValid?() != false else { return }
        if !force, let lastBackendCollectionsRefreshAt, Date().timeIntervalSince(lastBackendCollectionsRefreshAt) < backendCollectionsRefreshInterval {
            log(.debug, "Backend collection refresh throttled")
            return
        }

        guard pairingStatus == .paired else {
            log(.warning, "Backend collection refresh skipped because app is not paired")
            return
        }
        guard isRuntimeCompatible else {
            log(.warning, "Backend collection refresh skipped because update is required")
            return
        }

        do {
            let devicesPayload = backendCollectionCommandPayload(command: "devices")
            let queuePayload = backendCollectionCommandPayload(command: "queue")
            let playlistsPayload = backendCollectionCommandPayload(command: "playlists")
            let results = try await withHomeAssistantClient { client in
                guard isStillValid?() != false else { throw CancellationError() }
                async let devices = Self.fetchBackendCollectionCommand(
                    client: client,
                    payload: devicesPayload
                )
                async let queue = Self.fetchBackendCollectionCommand(
                    client: client,
                    payload: queuePayload
                )
                async let playlists = Self.fetchBackendCollectionCommand(
                    client: client,
                    payload: playlistsPayload
                )
                return await [devices, queue, playlists]
            }

            guard isStillValid?() != false else { return }
            let didLoadAnyCollection = applyBackendCollectionCommandResults(results)
            if didLoadAnyCollection {
                lastBackendCollectionsRefreshAt = Date()
            } else {
                log(.debug, "Backend collection refresh did not update throttle because all collection commands failed")
            }
        } catch let error as DJConnectError {
            log(.warning, "Backend collection refresh failed: \(Self.describe(error))")
        } catch {
            log(.error, "Backend collection refresh failed unexpectedly: \(error.localizedDescription)")
        }
    }

    private func backendCollectionCommandPayload(command: String) -> DJConnectCommandPayload {
        DJConnectCommandPayload(
            identity: identity,
            command: command,
            limit: Self.commandLimit(for: command),
            language: currentRequestLocale,
            mood: confirmedSessionMoodInt,
            musicDNAKey: askDJMusicDNAKey
        )
    }

    private struct BackendCollectionCommandResult: Sendable {
        let command: String
        let response: DJConnectCommandResponse?
        let errorDescription: String?
    }

    private static func fetchBackendCollectionCommand(
        client: DJConnectClient,
        payload: DJConnectCommandPayload
    ) async -> BackendCollectionCommandResult {
        do {
            let response = try await client.sendCommandResponse(payload)
            return BackendCollectionCommandResult(
                command: payload.command,
                response: response,
                errorDescription: nil
            )
        } catch let error as DJConnectError {
            return BackendCollectionCommandResult(
                command: payload.command,
                response: nil,
                errorDescription: Self.describe(error)
            )
        } catch {
            return BackendCollectionCommandResult(
                command: payload.command,
                response: nil,
                errorDescription: error.localizedDescription
            )
        }
    }

    private func applyBackendCollectionCommandResults(_ results: [BackendCollectionCommandResult]) -> Bool {
        var didLoadAnyCollection = false
        for result in results {
            if let response = result.response {
                apply(commandResponse: response, command: result.command)
                didLoadAnyCollection = true
            } else {
                log(.warning, "Backend collection command \(result.command) failed: \(result.errorDescription ?? "unknown error")")
            }
        }
        return didLoadAnyCollection
    }

    private func refreshStatusWithFallback(isStillValid: (@MainActor () -> Bool)? = nil) async throws {
        try await withHomeAssistantClient { client in
            try await refreshPlaybackSnapshot(client: client, isStillValid: isStillValid)
        }
    }

    private func refreshPlaybackSnapshot(client: DJConnectClient, isStillValid: (@MainActor () -> Bool)? = nil) async throws {
        let outputGeneration = outputSelectionGeneration
        let acceptsSnapshot: @MainActor () -> Bool = { [weak self] in
            self?.outputSelectionGeneration == outputGeneration && isStillValid?() != false
        }
        do {
            guard acceptsSnapshot() else { throw CancellationError() }
            log(.debug, "Loading Now Playing snapshot")
            let response = try await client.sendCommandResponse(
                DJConnectCommandPayload(
                    identity: identity,
                    command: "status",
                    language: currentRequestLocale,
                    mood: confirmedSessionMoodInt,
                    musicDNAKey: askDJMusicDNAKey
                )
            )
            guard acceptsSnapshot() else { throw CancellationError() }
            apply(commandResponse: response)
            if response.playback == nil {
                try await refreshStatus(client: client, isStillValid: acceptsSnapshot)
            } else {
                try await refreshConnectionEndpointsIfNeeded(client: client)
            }
        } catch let error as DJConnectError {
            if case .routeMissing = error {
                try await refreshStatus(client: client, isStillValid: acceptsSnapshot)
            } else {
                throw error
            }
        }
    }

    private func refreshAfterDJResponse(isStillValid: (@MainActor () -> Bool)? = nil) async {
        guard isStillValid?() != false, pairingStatus == .paired else {
            return
        }

        do {
            log(.debug, "Refreshing Home Assistant state after DJ response")
            try await refreshStatusWithFallback(isStillValid: isStillValid)
            guard isStillValid?() != false else { return }
            await refreshBackendCollections(force: true, isStillValid: isStillValid)
        } catch let error as DJConnectError {
            guard isStillValid?() != false else { return }
            log(.warning, "DJ response refresh failed: \(Self.describe(error))")
            apply(error: error)
        } catch {
            guard isStillValid?() != false else { return }
            log(.error, "DJ response refresh failed unexpectedly: \(error.localizedDescription)")
        }
    }

    private func clearRuntimeState(backendAvailableAfterClear: Bool = true) {
        profileDJSettings.bind(owner: nil, active: false)
        if sessionHistory.profileScopeActive { clearAskDJHistoryLocally() }
        sessionHistory.reset()
        invalidateSessionRequest()
        activeDJSession = nil
        stopSessionBroadcast()
        vibeCastHandoffApproved = false
        vibeCastHandoffFailed = false
        playbackProgressTask?.cancel()
        playbackProgressTask = nil
        volumeCommandTask?.cancel()
        volumeCommandTask = nil
        outputSelectionGeneration += 1
        pendingOutputSelectionID = nil
        pendingSelectedOutput = nil
        pendingSelectedOutputIsCachedSpotify = false
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
        personaReactions.cancel(.speechConflict)
        cancelAutomaticSpeech()
        if clearText {
            djResponseText = ""
        }
        #if canImport(AVFoundation)
        responsePlaybackCoordinator.stop()
        #endif
    }

    #if canImport(AVFoundation)
    private func clearResponsePlaybackOutput() {
        personaSpeechObservation = nil
        deviceSpeechRenderer.stop(); deviceSpeechPreviewIsPlaying = false
        responseAudioPlaybackTask?.cancel()
        responseAudioPlaybackTask = nil
        sharedResponseDataPlayer?.stop(); sharedResponseDataPlayer = nil
        sharedSpeechIsPlaying = false; sharedSpeechIsPreparing = false
        if let status = sharedSpeechDelivery["local"], ["preparing", "playing", "ready"].contains(status) {
            sharedSpeechDelivery["local"] = "unavailable"
        }
        responseAudioPlayer?.pause()
        responseAudioPlayer = nil
        askDJAudioPlaybackState = .idle
        responseSpeechSynthesizer?.stopSpeaking(at: .immediate)
        responseSpeechSynthesizer = nil
        resumePersonaInterruptedWakeIfNeeded()
    }
    #endif

    public var canPreviewDeviceSpeech: Bool {
        isAppInForeground && profileDJSettings.active && profileDJSettings.response?.allowsSpeech(.local) == true &&
        ![.idle, .loading, .saving, .unavailable, .uncertain].contains(profileDJSettings.phase)
    }
    public func stopDeviceSpeechPreview() {
        #if canImport(AVFoundation)
        if deviceSpeechPreviewIsPlaying { responsePlaybackCoordinator.stop() }
        #endif
    }
    public func previewDeviceSpeech() {
        #if canImport(AVFoundation)
        guard deviceSpeechPreferences.enabled, canPreviewDeviceSpeech else { return }
        personaReactions.cancel(.speechConflict)
        let preferences = deviceSpeechPreferences, epoch = sessionHistory.responseEpoch
        guard let ticket = responsePlaybackCoordinator.begin(deadline: Date().addingTimeInterval(30)) else { return }
        // Own pending activation too: Stop/view dismissal can cancel before the
        // asynchronous audio session activation returns.
        deviceSpeechPreviewIsPlaying = true
        responseAudioPlaybackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            @MainActor func current() -> Bool { !Task.isCancelled && self.canPreviewDeviceSpeech &&
                self.deviceSpeechPreferences == preferences && self.sessionHistory.responseEpoch == epoch && self.responsePlaybackCoordinator.isCurrent(ticket) }
            do {
                #if os(iOS)
                try await configureDJConnectAudioSession(category: .playback, mode: .spokenAudio, options: [.duckOthers])
                guard current() else { responsePlaybackCoordinator.finish(ticket); return }
                try await setDJConnectAudioSessionActive(true)
                #endif
                guard current() else { responsePlaybackCoordinator.finish(ticket); return }
                deviceSpeechRenderer.onStateChange = { [weak self] speaking in self?.deviceSpeechPreviewIsPlaying = speaking }
                let started = deviceSpeechRenderer.speak(localized(key: "ui.device_speech.sample"), locale: language, preferences: preferences) { [weak self] in
                    self?.responsePlaybackCoordinator.finish(ticket)
                }
                guard started else { responsePlaybackCoordinator.finish(ticket); return }
                while deviceSpeechRenderer.isSpeaking && current() { try await Task.sleep(for: .milliseconds(100)) }
                responsePlaybackCoordinator.finish(ticket)
            } catch { responsePlaybackCoordinator.finish(ticket) }
        }
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
                await self?.refreshForegroundStateFromPollTimer()
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

    // One foreground coordinator discovers profile-owned sessions even when this
    // client has never started one. Session discovery must not depend on playback
    // or music-backend availability; those are separate platform capabilities.
    func refreshForegroundStateFromPollTimer() async {
        guard isAppInForeground, pairingStatus == .paired, !isDemoMode,
              !isOfflineModeActive, !isRefreshing else { return }
        await refreshProfileDJSettings()
        let previousSessionID = activeDJSession?.sessionID
        let refreshed = await refreshActiveDJSession()
        guard isAppInForeground, pairingStatus == .paired, !Task.isCancelled else { return }
        if refreshed, activeDJSession != nil, previousSessionID != activeDJSession?.sessionID {
            await refreshActiveMoodCapability()
        }
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

    /// Requalify the input presentation when returning from native STT or a
    /// menu interruption. Capture still performs its own fresh admission.
    @discardableResult
    func refreshHAInputAvailabilityIfNeeded() async -> Bool {
        guard !deviceSTTEnabled, !isDemoMode, pairingStatus == .paired, isAppInForeground else { return false }
        do {
            try await withHomeAssistantClient { client in
                try await self.requireHADeviceSpeech(client: client, language: self.currentRequestLocale)
            }
            return !deviceSTTEnabled && canUseVoiceInputRoute
        } catch {
            log(.debug, "HA voice input availability could not be refreshed")
            return false
        }
    }

    /// A fresh same-client read is configuration admission only. Prepare3/source rights
    /// and actual runtime processing remain authoritative; no preference is rewritten.
    func requireHADeviceSpeech(client: DJConnectClient, language: String,
                                       target: DJConnectSharedSpeechTarget? = nil) async throws {
        let context = currentDeviceSpeechContext, epoch = sessionHistory.responseEpoch
        let updatesPresentation = client.identity.deviceID == identity.deviceID && language == currentRequestLocale
        if updatesPresentation { deviceSpeechAvailability = nil }
        let snapshot = try await client.currentDeviceSpeech(language: language, expectedInstallationID: defaults.string(forKey: haInstallIDKey) ?? "")
        guard !Task.isCancelled, context == currentDeviceSpeechContext,
              epoch == sessionHistory.responseEpoch, pairingStatus == .paired, isAppInForeground else { throw CancellationError() }
        // A Watch locale may differ; it cannot overwrite this device's presentation.
        if updatesPresentation {
            deviceSpeechContext = context
            deviceSpeechAvailability = snapshot
        }
        guard let snapshot,
              target.map({ snapshot.allowsHAOutput($0, locale: language) }) ?? snapshot.allowsHAInput(locale: language)
        else { throw DJConnectError.invalidResponse }
    }

    private func sendVoiceWithFallback(wavData: Data) async throws -> DJConnectVoiceResponse {
        let operation = voiceOperationGeneration, epoch = sessionHistory.responseEpoch
        return try await withHomeAssistantClient { client in
            try await self.requireHADeviceSpeech(client: client, language: self.currentRequestLocale)
            guard !self.deviceSTTEnabled, operation == self.voiceOperationGeneration,
                  epoch == self.sessionHistory.responseEpoch else { throw CancellationError() }
            return try await client.sendVoice(
                wavData: wavData,
                mood: confirmedSessionMoodInt,
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
        resolvedMusicDNAKey ?? "djconnect_\(identity.clientType.rawValue)_\(identity.deviceID)"
    }

    private var demoAskDJResponse: String {
        localized(key: "demo.session.answer")
    }

    public var selectableDJAnnouncementOutputs: [DJAnnouncementOutput] {
        djAnnouncementCapabilities.effectiveSupportedOutputs.filter { !djAnnouncementCapabilities.lockedOutputs.contains($0) }
    }

    public var djAnnouncementSpeakerDisplayName: String {
        djAnnouncementCapabilities.speakerName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? djAnnouncementCapabilities.speakerName!
            : "Home Assistant speaker"
    }

    public func isDJAnnouncementOutputSelectable(_ output: DJAnnouncementOutput) -> Bool {
        selectableDJAnnouncementOutputs.contains(output)
    }

    private func apply(djAnnouncementCapabilities capabilities: DJAnnouncementCapabilities?) {
        guard !profileDJSettings.negotiated else { return }
        guard let capabilities else {
            return
        }
        djAnnouncementCapabilities = capabilities
        if defaults.object(forKey: djAnnouncementOutputKey) == nil,
           let defaultOutput = capabilities.defaultOutput,
           isDJAnnouncementOutputSelectable(defaultOutput) {
            djAnnouncementOutput = defaultOutput
            return
        }
        let currentOutput = djAnnouncementOutput
        if isDJAnnouncementOutputSelectable(currentOutput) {
            return
        }
        let fallback = capabilities.defaultOutput.flatMap { isDJAnnouncementOutputSelectable($0) ? $0 : nil }
            ?? capabilities.output.flatMap { isDJAnnouncementOutputSelectable($0) ? $0 : nil }
            ?? selectableDJAnnouncementOutputs.first
            ?? .clientDevice
        djAnnouncementOutput = fallback
    }

    func sendAskDJTextWithFallback(_ text: String, clientMessageID: String) async throws -> DJConnectAskDJMessageResponse {
        if sessionHistory.profileScopeActive {
            return try await sessionHistory.sendExistingText(text, clientMessageID: clientMessageID)
        }
        return try await withHomeAssistantClient { client in
            try await client.sendAskDJMessage(DJConnectAskDJRequest(
                identity: identity,
                text: text,
                clientMessageID: clientMessageID,
                inputType: "text",
                mood: confirmedSessionMoodInt,
                djStyle: "warm_radio_dj",
                musicDNAKey: askDJMusicDNAKey,
                // Unnegotiated compatibility text must not request inline HA synthesis.
                audioResponse: .never,
                djAnnouncementOutput: profileDJSettings.effective?.announcement_output ?? djAnnouncementOutput,
                language: currentRequestLocale
            ))
        }
    }

    private func clearAskDJHistoryWithFallback() async throws -> DJConnectAskDJHistoryResponse {
        if sessionHistory.profileScopeActive {
            return try await withHomeAssistantClient { try await $0.clearProfileConversationHistory().base }
        }
        return try await withHomeAssistantClient { client in
            try await client.clearAskDJHistory(musicDNAKey: askDJMusicDNAKey)
        }
    }

    private func fetchAskDJHistory(sinceRevision: Int?) async throws -> DJConnectAskDJHistoryResponse {
        if sessionHistory.profileScopeActive {
            return try await sessionHistory.fetchExistingHistory()
        }
        return try await withHomeAssistantClient { client in
            try await client.askDJHistory(sinceRevision: sinceRevision)
        }
    }

    @discardableResult
    public func refreshMusicDNAProfile(showToast: Bool = false) async -> Bool {
        await refreshMusicDNAProfile(showToast: showToast, retryDelays: [.seconds(1), .seconds(3), .seconds(8)])
    }

    @discardableResult
    func refreshMusicDNAProfile(showToast: Bool = false, retryDelays: [Duration]) async -> Bool {
        if isDemoMode {
            applyDemoMusicDNAProfile()
            musicDNAProfileNeedsRecovery = false
            if showToast { showMusicDNAToast(localized(key: "appModel.music.dna.updated"), systemImage: "heart") }
            return true
        }
        guard pairingStatus == .paired, isRuntimeCompatible else {
            clearMusicDNADisplay()
            return false
        }
        guard isAppInForeground, !isLoadingMusicDNA else { return false }
        let epoch = sessionHistory.responseEpoch
        let generation = UUID(); musicDNARefreshGeneration = generation
        isLoadingMusicDNA = true
        musicDNAErrorMessage = nil
        defer { if musicDNARefreshGeneration == generation { isLoadingMusicDNA = false } }
        for attempt in 0...retryDelays.count {
            guard !Task.isCancelled, isAppInForeground, pairingStatus == .paired, !isDemoMode, isRuntimeCompatible,
                  musicDNARefreshGeneration == generation, epoch == sessionHistory.responseEpoch else { return false }
            do {
                let response = try await withHomeAssistantClient { client in
                    try await client.musicDNAProfile(mood: confirmedSessionMoodInt, musicDNAKey: askDJMusicDNAKey, language: language)
                }
                guard !Task.isCancelled, isAppInForeground, !isDemoMode, musicDNARefreshGeneration == generation,
                      epoch == sessionHistory.responseEpoch else { return false }
                apply(musicDNAProfile: response)
                musicDNAProfileNeedsRecovery = false
                if showToast { showMusicDNAToast(localized(key: "appModel.music.dna.updated"), systemImage: "heart") }
                return true
            } catch {
                guard !Self.isCancellation(error), !Task.isCancelled, !isDemoMode,
                      musicDNARefreshGeneration == generation, epoch == sessionHistory.responseEpoch else { return false }
                // A context fence rejects the previous projection, not Music DNA consent.
                // Withdraw its data before a bounded new read; never reuse its artwork.
                let contextChanged = Self.isMusicDNAContextChanged(error)
                if contextChanged { clearMusicDNADisplay(preservingRefreshGeneration: generation) }
                let transient: Bool
                if contextChanged { transient = true }
                else if let error = error as? DJConnectError {
                    switch error {
                    case .network, .backendUnavailable: transient = true
                    case let .server(code, _): transient = code == 408 || code == 429 || (500...599).contains(code)
                    default: transient = false
                    }
                } else { transient = false }
                musicDNAProfileNeedsRecovery = transient
                if transient {
                    musicDNAErrorMessage = localized(key: "ui.music.dna.recovering")
                    guard attempt < retryDelays.count else { return false }
                    do { try await Task.sleep(for: retryDelays[attempt]) } catch { return false }
                } else {
                    if let typed = error as? DJConnectError {
                        handleMusicDNAError(typed)
                        switch typed {
                        case .authStale, .notConfigured, .missingToken, .versionMismatch: break
                        case .profile:
                            clearMusicDNADisplay()
                            musicDNAErrorMessage = localized(key: "ui.music.dna.profile_access")
                        default: musicDNAErrorMessage = localized(key: "ui.music.dna.processing_failed")
                        }
                    } else {
                        musicDNAErrorMessage = localized(key: "ui.music.dna.processing_failed")
                    }
                    log(.warning, "Music DNA profile refresh stopped: \(error.localizedDescription)")
                    if showToast, let message = musicDNAErrorMessage { showMusicDNAToast(message, systemImage: "exclamationmark.triangle.fill") }
                    return false
                }
            }
        }
        return false
    }

    private static func isMusicDNAContextChanged(_ error: Error) -> Bool {
        guard case let DJConnectError.server(statusCode, message) = error,
              statusCode == 409, let message else { return false }
        if message == "music_dna_context_changed" { return true }
        guard let data = message.data(using: .utf8),
              let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return body["error"] as? String == "music_dna_context_changed"
    }

    private func showMusicDNAToast(_ text: String, systemImage: String) {
        musicDNAToast = DJConnectVisualNotice(text: text, systemImage: systemImage)
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

    public func acceptMusicDNAOptInPrompt() async {
        await setMusicDNAEnabled(true)
        if musicDNAProfileResponse?.enabled == true && musicDNAErrorMessage == nil {
            dismissMusicDNAOptInPrompt()
        }
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
                try await client.setMusicDNAEnabled(enabled, mood: confirmedSessionMoodInt, musicDNAKey: askDJMusicDNAKey, language: language)
            }
            apply(musicDNAProfile: response)
            pendingMusicDNAEnabled = enabled
            pendingMusicDNAEnabledAt = Date()
            try Task.checkCancellation()
            if enabled, response.success, response.enabled {
                _ = await refreshMusicDiscovery()
            }
            try Task.checkCancellation()
            let refreshed = try await withHomeAssistantClient { client in
                try await client.musicDNAProfile(mood: confirmedSessionMoodInt, musicDNAKey: askDJMusicDNAKey, language: language)
            }
            apply(musicDNAProfile: refreshed)
        } catch let error as DJConnectError {
            handleMusicDNAError(error)
        } catch is CancellationError {
        } catch {
            musicDNAErrorMessage = localized(key: "ui.music.dna.temporarily_unavailable")
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
                try await client.clearMusicDNA(mood: confirmedSessionMoodInt, musicDNAKey: askDJMusicDNAKey, language: language)
            }
            try Task.checkCancellation()
            let refreshed = try await withHomeAssistantClient { client in
                try await client.musicDNAProfile(mood: confirmedSessionMoodInt, musicDNAKey: askDJMusicDNAKey, language: language)
            }
            apply(musicDNAProfile: refreshed)
        } catch let error as DJConnectError {
            handleMusicDNAError(error)
        } catch is CancellationError {
        } catch {
            musicDNAErrorMessage = localized(key: "ui.music.dna.temporarily_unavailable")
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
            try await client.importMusicDNA(preview.profile, mood: confirmedSessionMoodInt, musicDNAKey: askDJMusicDNAKey, language: language)
        }
        apply(musicDNAProfile: response)
    }

    public func loadMusicDiscovery(force: Bool = false, showToast: Bool = false) async {
        if isDemoMode {
            musicDiscoveryResponse = demoMusicDNAEnabled ? Self.demoMusicDiscoveryResponse() : Self.disabledMusicDiscoveryResponse()
            musicDiscoveryErrorMessage = nil
            isLoadingMusicDiscovery = false
            isRefreshingMusicDiscovery = false
            supportsMusicDiscoveryFeedback = demoMusicDNAEnabled
            return
        }
        guard isAppInForeground else { return }
        guard pairingStatus == .paired, isRuntimeCompatible else {
            musicDiscoveryResponse = nil
            musicDiscoveryErrorMessage = nil
            supportsMusicDiscoveryFeedback = false
            return
        }
        if !force, let response = musicDiscoveryResponse, !isMusicDiscoveryExpired(response),
           !response.sections.flatMap(\.items).contains(where: { $0.imageURL != nil && ($0.imageExpiresAt.map { $0 <= Date() } ?? false) }),
           !response.enabled || !response.visibleSections.isEmpty {
            scheduleDiscoveryArtworkRenewal(response)
            return
        }
        let request = UUID(), epoch = sessionHistory.responseEpoch, source = musicDiscoveryPushCoalescingKey()
        discoveryResponseGeneration = request; discoveryLoadGeneration = request
        let valid = { self.discoveryResponseGeneration == request && self.sessionHistory.responseEpoch == epoch
            && self.musicDiscoveryPushCoalescingKey() == source && self.isAppInForeground && self.pairingStatus == .paired && !Task.isCancelled }
        isLoadingMusicDiscovery = true
        defer { if discoveryLoadGeneration == request { isLoadingMusicDiscovery = false } }
        musicDiscoveryErrorMessage = nil
        do {
            let response = try await withHomeAssistantClient { client in
                let supports = await client.supportsMusicDiscoveryFeedback()
                guard valid() else { throw CancellationError() }
                supportsMusicDiscoveryFeedback = supports
                return try await client.musicDiscoveryFeed(musicDNAKey: askDJMusicDNAKey, language: language)
            }
            guard valid() else { return }
            apply(musicDiscovery: response)
        } catch let error as DJConnectError {
            guard valid() else { return }
            handleMusicDiscoveryError(error)
            if showToast {
                showMusicDNAToast(messageForMusicDiscoveryFailure(error), systemImage: "exclamationmark.triangle.fill")
            }
        } catch {
            guard valid() else { return }
            musicDiscoveryErrorMessage = localized(key: "ui.discovery.could.not.be.loaded")
            log(.warning, "Music Discovery load failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    public func refreshMusicDiscovery() async -> Bool {
        if let manualDiscoveryRefreshTask { return await manualDiscoveryRefreshTask.value }
        let epoch = sessionHistory.responseEpoch
        let source = musicDiscoveryPushCoalescingKey()
        // SwiftUI can cancel the pull gesture before the backend finishes.
        // Keep one manual request alive for both the gesture and toolbar button.
        let task = Task { @MainActor in
            guard sessionHistory.responseEpoch == epoch,
                  musicDiscoveryPushCoalescingKey() == source else { return false }
            return await refreshMusicDiscovery(coalesce: false)
        }
        manualDiscoveryRefreshTask = task
        let result = await task.value
        manualDiscoveryRefreshTask = nil
        return result
    }

    @discardableResult
    public func refreshMusicDiscoveryFromPush() async -> Bool {
        let source = musicDiscoveryPushCoalescingKey()
        let refreshed = await refreshMusicDiscovery(coalesce: true)
        // Receive and tap can straddle a slow request. Start the quiet window
        // after completion too, so that one notification does not regenerate twice.
        if refreshed, source == musicDiscoveryPushCoalescingKey(), isAppInForeground {
            musicDiscoveryPushRefreshes[source] = Date()
        }
        return refreshed
    }

    @discardableResult
    private func refreshMusicDiscovery(coalesce: Bool) async -> Bool {
        if isDemoMode {
            musicDiscoveryResponse = demoMusicDNAEnabled ? Self.demoMusicDiscoveryResponse(revision: (musicDiscoveryResponse?.revision ?? 12) + 1) : Self.disabledMusicDiscoveryResponse()
            musicDiscoveryErrorMessage = nil
            return true
        }
        guard isAppInForeground, pairingStatus == .paired, isRuntimeCompatible else {
            return false
        }
        if coalesce, shouldCoalesceMusicDiscoveryPushRefresh() {
            logPush("music_discovery_ready refresh coalesced")
            return true
        }
        let request = UUID(), epoch = sessionHistory.responseEpoch, source = musicDiscoveryPushCoalescingKey()
        discoveryResponseGeneration = request; discoveryRefreshGeneration = request
        let valid = { self.discoveryResponseGeneration == request && self.sessionHistory.responseEpoch == epoch
            && self.musicDiscoveryPushCoalescingKey() == source && self.isAppInForeground && self.pairingStatus == .paired && !Task.isCancelled }
        isRefreshingMusicDiscovery = true
        musicDiscoveryErrorMessage = nil
        defer { if discoveryRefreshGeneration == request { isRefreshingMusicDiscovery = false } }
        do {
            let refreshResponse = try await withHomeAssistantClient { client in
                let supports = await client.supportsMusicDiscoveryFeedback()
                guard valid() else { throw CancellationError() }
                supportsMusicDiscoveryFeedback = supports
                return try await client.refreshMusicDiscovery(musicDNAKey: askDJMusicDNAKey, language: language)
            }
            guard valid() else { return false }
            apply(musicDiscovery: refreshResponse, preservesVisibleRecommendationsOnEmptyEnabledResponse: coalesce)
            return true
        } catch let error as DJConnectError {
            guard valid() else { return false }
            if shouldLoadMusicDiscoveryFeedAfterRefreshError(error) {
                do {
                    let response = try await withHomeAssistantClient { client in
                        let supports = await client.supportsMusicDiscoveryFeedback()
                guard valid() else { throw CancellationError() }
                supportsMusicDiscoveryFeedback = supports
                        return try await client.musicDiscoveryFeed(musicDNAKey: askDJMusicDNAKey, language: language)
                    }
                    guard valid() else { return false }
                    apply(musicDiscovery: response, preservesVisibleRecommendationsOnEmptyEnabledResponse: coalesce)
                    return true
                } catch let fallbackError as DJConnectError {
                    guard valid() else { return false }
                    handleMusicDiscoveryError(fallbackError)
                } catch {
                    guard valid() else { return false }
                    musicDiscoveryErrorMessage = localized(key: "ui.discovery.could.not.be.loaded")
                    log(.warning, "Music Discovery refresh fallback feed failed: \(error.localizedDescription)")
                }
                return false
            }
            handleMusicDiscoveryError(error)
        } catch is CancellationError {
        } catch {
            guard valid() else { return false }
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

    @discardableResult
    public func playMusicDiscoveryItem(_ item: DJConnectMusicDiscoveryItem, sectionID: String) async -> Bool {
        guard item.isDisplayable, item.isPlayable else { return false }
        if isDemoMode {
            playMusicDiscoveryStartHaptic()
            playingMusicDiscoveryItemID = item.id
            try? await Task.sleep(for: .milliseconds(120))
            playingMusicDiscoveryItemID = nil
            return true
        }
        guard pairingStatus == .paired, isRuntimeCompatible else {
            return false
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
            let response = try await withHomeAssistantClient(allowsOperationReplay: false) { client in
                try await client.playMusicDiscoveryItem(payload)
            }
            apply(commandResponse: response, command: "music_discovery_play")
            guard response.success else {
                musicDiscoveryErrorMessage = response.message ?? localized(key: "appModel.this.recommendation.cannot.be.played.yet")
                playingMusicDiscoveryItemID = nil
                return false
            }
            scheduleCommandRefresh(reason: "Discovery play confirmation refresh completed", delay: .zero)
            _ = await refreshMusicDiscovery()
            playingMusicDiscoveryItemID = nil
            return true
        } catch let error as DJConnectError {
            handleMusicDiscoveryPlayError(error)
        } catch is CancellationError {
        } catch {
            musicDiscoveryErrorMessage = localized(key: "appModel.this.recommendation.cannot.be.played.yet")
            log(.warning, "Music Discovery play failed: \(error.localizedDescription)")
        }
        playingMusicDiscoveryItemID = nil
        return false
    }

    public func sendMusicDiscoveryFeedback(
        _ feedback: DJConnectMusicDiscoveryFeedback,
        item: DJConnectMusicDiscoveryItem,
        sectionID: String
    ) async {
        guard item.isDisplayable, supportsMusicDiscoveryFeedback else { return }
        if isDemoMode {
            removeMusicDiscoveryItem(id: item.id, sectionID: sectionID)
            return
        }
        guard pairingStatus == .paired, isRuntimeCompatible else {
            return
        }
        removeMusicDiscoveryItem(id: item.id, sectionID: sectionID)
        do {
            let payload = DJConnectMusicDiscoveryFeedbackRequest(
                discoveryItemID: item.id,
                sectionID: sectionID,
                feedback: feedback,
                identity: identity,
                musicDNAKey: askDJMusicDNAKey
            )
            _ = try await withHomeAssistantClient { client in
                try await client.sendMusicDiscoveryFeedback(payload)
            }
            _ = await refreshMusicDiscovery()
        } catch let error as DJConnectError {
            handleMusicDiscoveryError(error)
            await loadMusicDiscovery(force: true)
        } catch is CancellationError {
        } catch {
            musicDiscoveryErrorMessage = localized(key: "ui.discovery.could.not.be.loaded")
            log(.warning, "Music Discovery feedback failed: \(error.localizedDescription)")
            await loadMusicDiscovery(force: true)
        }
    }

    private func removeMusicDiscoveryItem(id: String, sectionID: String) {
        guard var response = musicDiscoveryResponse else { return }
        response.sections = response.sections.map { section in
            guard section.id == sectionID else { return section }
            var updated = section
            updated.items.removeAll { $0.id == id }
            return updated
        }
        musicDiscoveryResponse = response
    }

    private func handleMusicDiscoveryPlayError(_ error: DJConnectError) {
        musicDiscoveryErrorMessage = localized(key: "appModel.this.recommendation.cannot.be.played.yet")
        log(.warning, "Music Discovery play failed: \(Self.describe(error))")
    }

    private func apply(
        musicDiscovery response: DJConnectMusicDiscoveryResponse,
        preservesVisibleRecommendationsOnEmptyEnabledResponse: Bool = false
    ) {
        if preservesVisibleRecommendationsOnEmptyEnabledResponse,
           response.enabled,
           response.visibleSections.isEmpty,
           musicDiscoveryResponse?.visibleSections.isEmpty == false {
            musicDiscoveryErrorMessage = nil
            log(.debug, "Music Discovery empty enabled refresh ignored to keep visible recommendations")
            return
        }
        musicDiscoveryResponse = response
        scheduleDiscoveryArtworkRenewal(response)
        musicDiscoveryErrorMessage = nil
        let sectionCount = response.sections.count
        let itemCount = response.sections.reduce(0) { $0 + $1.items.count }
        let visibleSectionCount = response.visibleSections.count
        let visibleItemCount = response.visibleSections.reduce(0) { $0 + $1.visibleItems.count }
        log(.debug, "Music Discovery refreshed enabled=\(response.enabled) revision=\(response.revision ?? 0) sections=\(sectionCount) items=\(itemCount) visible_sections=\(visibleSectionCount) visible_items=\(visibleItemCount)")
    }

    private func scheduleDiscoveryArtworkRenewal(_ response: DJConnectMusicDiscoveryResponse) {
        discoveryArtworkRenewalTask?.cancel()
        guard response.enabled, isAppInForeground,
              let deadline = response.visibleSections.flatMap(\.visibleItems)
                .filter({ $0.imageURL != nil }).compactMap(\.imageExpiresAt).min() else { return }
        // A short lease can expire while the feed is in flight. Renew once;
        // repeatedly expired producer responses must not create a polling loop.
        if deadline <= Date() {
            guard !retriedExpiredDiscoveryArtwork else { return }
            retriedExpiredDiscoveryArtwork = true
        } else { retriedExpiredDiscoveryArtwork = false }
        let key = musicDiscoveryPushCoalescingKey(), epoch = sessionHistory.responseEpoch
        discoveryArtworkRenewalTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(max(1, deadline.timeIntervalSinceNow + 0.2))) }
            catch { return }
            guard let self, !Task.isCancelled, self.isAppInForeground,
                  self.pairingStatus == .paired, self.musicDiscoveryPushCoalescingKey() == key,
                  self.sessionHistory.responseEpoch == epoch else { return }
            // Feed TTL is not artwork-lease TTL. Renew through the existing GET,
            // once at the next deadline, never through a per-card polling loop.
            await self.loadMusicDiscovery(force: true)
        }
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
        case .backendUnavailable, .server, .network, .decodingFailed, .invalidResponse, .payloadTooLarge:
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
        case let .profile(_, _, message):
            return message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? message!
                : localized(key: "ui.discovery.could.not.be.loaded")
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
        if let musicDNAKey = response.musicDNAKey?.trimmingCharacters(in: .whitespacesAndNewlines),
           !musicDNAKey.isEmpty {
            resolvedMusicDNAKey = musicDNAKey
        }
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
                    id: "new_for_you",
                    title: "Nieuw voor jou",
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
                    id: "accepted_recommendations",
                    title: "Omdat je eerder iets koos",
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

    private func clearMusicDNADisplay(preservingRefreshGeneration generation: UUID? = nil) {
        discoveryResponseGeneration = UUID()
        retriedExpiredDiscoveryArtwork = false
        discoveryArtworkRenewalTask?.cancel(); discoveryArtworkRenewalTask = nil
        musicDiscoveryResponse = nil; supportsMusicDiscoveryFeedback = false
        musicDNARefreshGeneration = generation ?? UUID()
        musicDNAProfileNeedsRecovery = false
        musicDNAProfileResponse = nil
        musicDNAErrorMessage = nil
        isLoadingMusicDNA = generation != nil
        isUpdatingMusicDNA = false
        resolvedMusicDNAKey = nil
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
            musicDNAErrorMessage = localized(key: "ui.music.dna.temporarily_unavailable")
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
                mood: confirmedSessionMoodInt,
                djStyle: "warm_radio_dj",
                musicDNAKey: askDJMusicDNAKey
            ))
        }
    }

    private func playAskDJRecommendationWithFallback(_ action: DJConnectAskDJPlaybackAction,
                                                       isStillValid: @escaping @MainActor () -> Bool) async throws -> DJConnectCommandResponse {
        let command = action.command?.isEmpty == false ? action.command! : Self.defaultAskDJCommand(for: action)
        return try await withHomeAssistantClient(allowsOperationReplay: false) { client in
            guard isStillValid() else { throw CancellationError() }
            return try await client.sendCommandResponse(DJConnectCommandPayload(
                identity: identity,
                command: command,
                value: Self.askDJCommandValue(for: action, command: command),
                play: command == "ask_dj_play_recommendation",
                musicBackendRevision: action.musicBackendRevision ?? musicBackendSummary.musicBackendRevision,
                language: currentRequestLocale,
                mood: confirmedSessionMoodInt,
                musicDNAKey: askDJMusicDNAKey,
                djAnnouncementOutput: profileDJSettings.effective?.announcement_output ?? djAnnouncementOutput
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
                    mood: confirmedSessionMoodInt,
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
                    mood: confirmedSessionMoodInt,
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

    func confirmProfileConversationText(id: UUID?) {
        if let id { updateAskDJMessageStatus(id: id, status: .sent) }
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
        guard canUseAskDJFeatures else {
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
        guard !sessionHistory.profileScopeActive, canUsePlaybackFeatures,
              !hasRequestedAskDJIdleSuggestion,
              !isRequestingAskDJIdleSuggestion,
              !hasActiveNowPlaying else {
            return
        }
        hasRequestedAskDJIdleSuggestion = true
        isRequestingAskDJIdleSuggestion = true
        defer { isRequestingAskDJIdleSuggestion = false }
        let capturedEpoch = sessionHistory.responseEpoch
        do {
            let response = try await requestAskDJIdleSuggestion()
            guard capturedEpoch == sessionHistory.responseEpoch, !sessionHistory.profileScopeActive, canRefreshSessionHistory else { return }
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
        if !response.isPrivateEphemeralResponse {
            persistAskDJRevisions(historyRevision: response.historyRevision, clearRevision: response.clearRevision)
        }
        saveAskDJMessages()
        if fallbackUserMessageID != nil {
            requestAskDJScrollToBottom()
        }
        if shouldPlayResponseHaptic {
            playAskDJResponseHaptic()
        }
        applyTrackInsightIfNeeded(from: response, open: false)
    }

    private func resolvedAskDJResponseAudioURL(_ response: DJConnectAskDJMessageResponse) -> URL? {
        if let announcement = response.assistantMessage?.announcement ?? response.announcement {
            return resolvedAudioURL(from: announcement.clientReplayAudioURL)
        }
        return resolvedAudioURL(from: response.assistantMessage?.audioURL ?? response.audioURL)
    }

    private func responseContainsAssistantMessage(_ response: DJConnectAskDJMessageResponse) -> Bool {
        if response.assistantMessage != nil {
            return true
        }
        return response.messages.contains { $0.role != .user }
    }

    func applyAskDJHistory(_ response: DJConnectAskDJHistoryResponse, forceClear: Bool = false) {
        if sessionHistory.profileScopeActive {
            guard response.historyRevision >= profileConversationHistoryRevision,
                  response.clearRevision >= profileConversationClearRevision else { return }
            if response.clearRevision > profileConversationClearRevision { sessionHistory.invalidateClearedConversation() }
            let allowed = Set(response.messages.map(\.id))
            askDJMessages.removeAll { message in
                if liveConversationPresentations.values.contains(where: {
                    $0.isPrivateEphemeral && $0.questionID == message.id && $0.epoch == sessionHistory.responseEpoch
                        && ($0.deadline.map { $0 > Date() } ?? true)
                }) { return false }
                if let id = message.serverID {
                    if let live = liveConversationPresentations[id], live.isPrivateEphemeral,
                       live.epoch == sessionHistory.responseEpoch, live.deadline.map({ $0 > Date() }) ?? true { return false }
                    return !allowed.contains(id)
                }
                return message.status != .sending && message.status != .failed
            }
        }
        let localClearRevision = sessionHistory.profileScopeActive ? profileConversationClearRevision : defaults.integer(forKey: askDJClearRevisionKey)
        if forceClear || response.clearRevision > localClearRevision {
            askDJMessages.removeAll()
        }
        var nextMessages = askDJMessages
        for message in response.messages {
            upsertAskDJHistoryMessage(message, into: &nextMessages, fallbackID: nil)
        }
        applyAskDJTrim(response.historyTrimmedBefore, to: &nextMessages)
        coalesceAskDJMessages(&nextMessages)
        askDJMessages = sortedAskDJMessages(nextMessages).map { original in
            var message = original
            if sessionHistory.profileScopeActive {
                message.images = []; message.links = []; message.items = []; message.playbackActions = []
                message.trackInsight = nil
            }
            guard let id = message.serverID, let live = liveConversationPresentations[id],
                  live.epoch == sessionHistory.responseEpoch, live.deadline.map({ $0 > Date() }) ?? true,
                  live.message.clientMessageID == message.clientMessageID,
                  live.message.text == message.text else { return message }
            var result = message
            result.images = live.message.images; result.links = live.message.links
            result.items = live.message.items; result.trackInsight = live.message.trackInsight
            result.playbackActions = live.message.playbackActions
            return result
        }
        liveConversationPresentations = liveConversationPresentations.filter { id, live in
            askDJMessages.contains(where: { $0.serverID == id && $0.text == live.message.text })
        }
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

    // Compatibility callers no longer publish separate personal snapshots.
    private func saveTrackInsightWidgetSnapshot(for insight: TrackInsight) { syncSessionSurfaces() }
    private func clearTrackInsightWidgetSnapshot(reason: String) { syncSessionSurfaces() }
    private func updateNowPlayingWidgetSnapshot(playback: DJConnectPlayback?) { syncSessionSurfaces() }
    private func clearNowPlayingWidgetSnapshot(reason: String) { syncSessionSurfaces() }
    private func updateQueueWidgetSnapshot(items: [DJConnectQueueItem]) { syncSessionSurfaces() }
    private func clearQueueWidgetSnapshot(reason: String) { syncSessionSurfaces() }
    private func syncTrackInsightLiveActivity(reason: String) { syncSessionSurfaces() }

    private var standaloneWidgetTheme: DJConnectSessionMoodTheme?
    private var standaloneWidgetThemeEpoch: UUID?
    public func setTrackInsightWidgetMood(step: Int) {
        let moods: [DJConnectSessionMoodTheme] = [.chill, .groove, .energy, .party]
        guard moods.indices.contains(step) else { return }
        standaloneWidgetTheme = moods[step]
        standaloneWidgetThemeEpoch = sessionHistory.responseEpoch
        syncSessionSurfaces()
    }

    private func bindPassiveSessionSurfaces() {
        guard !isDemoMode, pairingStatus == .paired, activeDJSession?.runtimeState == "active" else {
            passiveSurfaces.bind(owner: nil, sessionID: nil, foreground: false); return
        }
        guard isAppInForeground else { passiveSurfaces.suspend(); return }
        guard let settings = profileDJSettings.response, settings.isValid else {
            passiveSurfaces.pauseForRevalidation(); return
        }
        // Independent of history's suspension epoch. Actual Profile/installation
        // replacement changes the opaque Core binding; the grant read checks ABA.
        passiveSurfaces.bind(owner: settings.binding, sessionID: activeDJSession?.id, foreground: true)
    }
    var passiveSurfaceServices: PassiveSessionSurfaceModel.Services {
        .init(available: { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.withHomeAssistantClient { try await $0.passiveSurfaceAvailable() }
        }, authorize: { [weak self] session, surface, enabled in
            guard let self else { throw CancellationError() }
            return try await self.withHomeAssistantClient(allowsOperationReplay: false) {
                try await $0.authorizePassiveSurface(sessionID: session, surface: surface, enabled: enabled)
            }
        }, read: { [weak self] session, surface, grant in
            guard let self else { throw CancellationError() }
            return try await self.withHomeAssistantClient {
                try await $0.readPassiveSurface(sessionID: session, surface: surface, grantID: grant)
            }
        }, image: { [weak self] artwork, response in
            guard let self else { throw CancellationError() }
            let image = try await self.withHomeAssistantClient {
                try await $0.passiveSurfaceImage(artwork, response: response)
            }
            let bytes = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(bytes, "public.png" as CFString, 1, nil) else { throw DJConnectError.invalidResponse }
            CGImageDestinationAddImage(destination, image.image, nil)
            guard CGImageDestinationFinalize(destination), bytes.length <= DJConnectPassiveSurfaceCache.maximumImageBytes else { throw DJConnectError.invalidResponse }
            return bytes as Data
        })
    }
    public func preparePassiveSurfaceControls() async {
        if !profileDJSettings.negotiated { await refreshProfileDJSettings() }
        bindPassiveSessionSurfaces()
        await passiveSurfaces.discover(passiveSurfaceServices)
    }
    public func setPassiveSurface(_ surface: DJConnectPassiveSurface, enabled: Bool) async {
        bindPassiveSessionSurfaces()
        await passiveSurfaces.setEnabled(enabled, surface: surface, services: passiveSurfaceServices)
    }

    private func scheduleAutomaticPassiveSessionSurfaces() {
        guard isAppInForeground, !isDemoMode, pairingStatus == .paired,
              activeDJSession?.runtimeState == "active", hasObservedSessionSurfaceAuthority,
              profileDJSettings.active, let settings = profileDJSettings.response, settings.isValid,
              let sessionID = activeDJSession?.id else { return }
        let context = settings.binding + ":" + sessionID
        if automaticPassiveContext != context {
            automaticPassiveTask?.cancel(); automaticPassiveTask = nil
            automaticPassiveTaskID = UUID(); lastAutomaticPassiveQueryAt = nil
            automaticPassiveContext = context
        }
        guard automaticPassiveTask == nil,
              lastAutomaticPassiveQueryAt.map({ Date().timeIntervalSince($0) >= 30 }) != false else { return }
        lastAutomaticPassiveQueryAt = Date()
        let request = UUID(); automaticPassiveTaskID = request
        automaticPassiveTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if automaticPassiveTaskID == request { automaticPassiveTask = nil } }
            var surfaces: Set<DJConnectPassiveSurface> = []
            #if canImport(WidgetKit)
            do {
                let configured = try await WidgetCenter.shared.currentConfigurations()
                let kinds = Set([DJConnectSessionSurfaceSnapshot.widgetKind] + DJConnectSessionSurfaceSnapshot.legacyKinds)
                if configured.contains(where: { kinds.contains($0.kind) }) { surfaces.insert(.widget) }
            } catch { return } // Unknown OS state never creates or revokes a grant.
            #endif
            #if os(iOS) && canImport(ActivityKit)
            if ActivityAuthorizationInfo().areActivitiesEnabled { surfaces.insert(.liveActivity) }
            #endif
            guard !Task.isCancelled, isAppInForeground, !isDemoMode, pairingStatus == .paired,
                  activeDJSession?.id == sessionID, activeDJSession?.runtimeState == "active",
                  profileDJSettings.active, profileDJSettings.response?.binding == settings.binding else { return }
            await passiveSurfaces.reconcileAutomatic(surfaces: surfaces, services: passiveSurfaceServices)
        }
    }

    private func syncSessionSurfaces(observedSession: Bool = false) {
        // Isolated fixtures/Demo must never touch the installed shared group.
        guard startBackgroundTasks, !monkeyTestingMode,
              !DJConnectLocalization.isQualificationProcess else { return }
        bindPassiveSessionSurfaces()
        if observedSession { hasObservedSessionSurfaceAuthority = true }
        scheduleAutomaticPassiveSessionSurfaces()
        passiveSurfaces.refresh(passiveSurfaceServices)
        let now = Date()
        let epoch = sessionHistory.responseEpoch
        // Conversation suspension changes history's epoch on every background
        // transition. Only the independently confirmed Profile/install binding
        // may withdraw these already granted, short-lived OS presentations.
        let binding = profileDJSettings.response?.binding
        let changedSubject = sessionSurfaceBinding != binding
        sessionSurfaceBinding = binding
        if changedSubject {
            sessionSurfaceIdentity = nil; sessionSurfaceSnapshot = nil
            if standaloneWidgetThemeEpoch != epoch { standaloneWidgetTheme = nil }
        }
        let confirmed = !isDemoMode && pairingStatus == .paired && activeDJSession?.runtimeState == "active"
        if !confirmed {
            sessionSurfaceSnapshot = nil
            sessionSurfaceIdentity = nil
            if observedSession { DJConnectSessionSurfacePresentation.end(in: defaults) }
        } else if observedSession && isAppInForeground {
            // Identity stays local. Neither Profile nor backend session IDs are
            // exported to passive surfaces. A new subject gets a new marker.
            if sessionSurfaceIdentity == nil {
                if let sessionID = activeDJSession?.id {
                    sessionSurfaceIdentity = DJConnectSessionSurfacePresentation.identity(for: sessionID, in: defaults)
                }
            }
            sessionSurfaceSnapshot = .observe(runtimeState: activeDJSession?.runtimeState,
                                               authorized: pairingStatus == .paired, isDemo: isDemoMode,
                                               confirmedMood: activeDJSession?.selectedMood, at: now)
        } else {
            // A contribution/cover deadline withdraws that content, not the
            // separately confirmed Session within its original 120s lease.
            sessionSurfaceSnapshot = sessionSurfaceSnapshot?.neutral(at: now)
        }
        if let cache = passiveSurfaces.caches[.liveActivity], let rich = DJConnectPassiveActivityContent(cache: cache),
           let neutral = sessionSurfaceSnapshot {
            sessionSurfaceSnapshot = .init(observedAt: neutral.observedAt, theme: neutral.theme, rich: rich)
        } else if let previous = sessionSurfaceSnapshot, previous.rich != nil {
            sessionSurfaceSnapshot = .init(observedAt: previous.observedAt, theme: previous.theme)
        }
        let snapshot = sessionSurfaceSnapshot
        guard let shared = UserDefaults(suiteName: DJConnectLocalization.appGroupIdentifier) else { return }
        let richWidget = passiveSurfaces.caches[.widget].flatMap { $0.isCurrent(at: now) ? $0.removingExpiredFields(at: now) : nil }
        var richChanged = false
        if lastPublishedPassiveRevision != passiveSurfaces.renderingRevision {
            richChanged = !(lastPublishedWidgetRich?.hasSameDisplayContent(as: richWidget) ?? (richWidget == nil))
            for surface in DJConnectPassiveSurface.allCases {
                let value = passiveSurfaces.caches[surface].flatMap { $0.isCurrent(at: now) ? $0.removingExpiredFields(at: now) : nil }
                try? DJConnectPassiveSurfaceCache.replace(value, surface: surface, in: shared)
            }
            lastPublishedPassiveRevision = passiveSurfaces.renderingRevision
            lastPublishedWidgetRich = richWidget
        }
        let previousPalette = DJConnectWidgetPaletteSnapshot.load(from: shared, at: now)
        let profileMood = profileDJSettings.active && ![.unavailable, .uncertain, .loading].contains(profileDJSettings.phase)
            ? profileDJSettings.response?.snapshot.defaults.mood : nil
        let theme = DJConnectWidgetPaletteSnapshot.resolve(session: snapshot?.theme?.rawValue,
            trackInsight: standaloneWidgetTheme, profile: profileMood)
        let palette = DJConnectWidgetPaletteSnapshot(theme: isDemoMode ? .brand : theme, at: now)
        if let encoded = try? JSONEncoder().encode(palette) { shared.set(encoded, forKey: DJConnectWidgetPaletteSnapshot.storageKey) }
        let paletteChanged = previousPalette?.theme != palette.theme
        let previous = DJConnectSessionSurfaceSnapshot.load(from: shared, at: now)
        let changed: Bool
        do { changed = try DJConnectSessionSurfaceSnapshot.replace(snapshot, in: shared) }
        catch { log(.warning, "Session surface snapshot could not be saved"); return }
        #if canImport(WidgetKit)
        // No progress tick reloads. Freshness renewal is bounded; OS budgets
        // still own actual rendering and background scheduling.
        let paletteRenewalDue = palette.theme != .brand && lastSessionWidgetReloadAt.map { now.timeIntervalSince($0) >= 60 } != false
        if richChanged || paletteChanged || paletteRenewalDue || (changed && snapshot == nil) || DJConnectSessionSurfaceSnapshot.needsWidgetReload(
            current: snapshot, previous: previous, lastReloadAt: lastSessionWidgetReloadAt, at: now) {
            lastSessionWidgetReloadAt = now
            for kind in [DJConnectSessionSurfaceSnapshot.widgetKind] + DJConnectSessionSurfaceSnapshot.legacyKinds {
                WidgetCenter.shared.reloadTimelines(ofKind: kind)
            }
        }
        #endif
        if !hasSyncedSessionSurfaceActivity || lastActivitySurfaceSnapshot != snapshot ||
            lastActivitySurfaceIdentity != sessionSurfaceIdentity { sessionSurfaceGeneration = UUID() }
        let generation = sessionSurfaceGeneration
        sessionSurfaceExpiryTask?.cancel()
        if let snapshot {
            sessionSurfaceExpiryTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(0, snapshot.expiresAt.timeIntervalSinceNow)))
                guard !Task.isCancelled, let self, self.sessionSurfaceGeneration == generation else { return }
                self.syncSessionSurfaces()
            }
        }
        #if os(iOS) && canImport(ActivityKit)
        if #available(iOS 16.1, *),
           hasObservedSessionSurfaceAuthority || pairingStatus != .paired || isDemoMode,
           !hasSyncedSessionSurfaceActivity || lastActivitySurfaceSnapshot != snapshot || lastActivitySurfaceIdentity != sessionSurfaceIdentity {
            hasSyncedSessionSurfaceActivity = true
            lastActivitySurfaceSnapshot = snapshot
            lastActivitySurfaceIdentity = sessionSurfaceIdentity
            let previousTask = sessionSurfaceActivityTask
            let identity = sessionSurfaceIdentity
            let canStart = isAppInForeground
            sessionSurfaceActivityTask = Task { [weak self] in
                await previousTask?.value
                guard let self, self.sessionSurfaceGeneration == generation else { return }
                if let status = await DJConnectSessionSurfaceActivityController.sync(snapshot: snapshot, presentationID: identity,
                    canStart: canStart, endReason: changedSubject ? "subject_changed" : (!confirmed ? "session_inactive" : "snapshot_expired")) {
                    self.log(.info, status)
                }
            }
        }
        #endif
    }

    /// Route public playback covers through the confirmed HA connection, including Session headers.
    func resolvedArtworkURL(_ artworkURL: URL?) -> URL? {
        let preferred: URL?
        switch haConnectionMode {
        case .remote: preferred = Self.normalizedHomeAssistantURL(from: haRemoteURL)
        case .local: preferred = Self.normalizedHomeAssistantURL(from: localHomeAssistantURL())
        case .offline: preferred = nil
        }
        return DJConnectArtworkRoute.resolve(artworkURL, knownOrigins: homeAssistantBaseURLs(), preferredOrigin: preferred)
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
        case let .profile(_, _, message):
            return userFacingTrackInsightErrorText(message)
                ?? localized(key: "appModel.track.insight.is.unavailable.for.this.track")
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
        case .payloadTooLarge:
            return localized(key: "appModel.home.assistant.returned.an.unexpected.track.insight.response")
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

    /// Reuse the common response projection for ephemeral active-Session rendering.
    func sessionResponseMessage(_ message: DJConnectAskDJHistoryMessage) -> DJConnectAskDJMessage {
        makeAskDJMessage(from: message, existing: nil, fallbackID: nil)
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
            announcement: resolvedAnnouncement(historyMessage.announcement),
            status: status,
            createdAt: historyMessage.createdAt,
            intentInfo: historyMessage.intentInfo,
            trackInsight: historyMessage.trackInsight,
            items: proxiedAskDJHistoryItems(historyMessage.items),
            sessionSpeech: historyMessage.sessionSpeech
        )
    }

    private func resolvedAnnouncement(_ announcement: DJAnnouncement?) -> DJAnnouncement? {
        guard var announcement else {
            return nil
        }
        announcement.audioURL = resolvedAudioURL(from: announcement.audioURL)
        return announcement
    }

    private func persistAskDJRevisions(historyRevision: Int, clearRevision: Int) {
        if sessionHistory.profileScopeActive {
            profileConversationHistoryRevision = max(profileConversationHistoryRevision, historyRevision)
            profileConversationClearRevision = max(profileConversationClearRevision, clearRevision)
            return
        }
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
            if sessionHistory.profileScopeActive { return message.serverID != nil }
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
        if merged.announcement == nil {
            merged.announcement = fallback.announcement
        }
        if merged.audioURL == nil, merged.announcement == nil {
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
        guard !isDemoMode else { return }
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

    private func requestRemoteNotificationAuthorizationIfNeeded(
        center: UNUserNotificationCenter,
        allowSystemPrompt: Bool = false
    ) async -> Bool {
        let settings = await center.notificationSettings()
        logPush("notification permission status=\(Self.notificationAuthorizationStatusName(settings.authorizationStatus))")
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            guard allowSystemPrompt else {
                logPush("notification permission deferred reason=app_consent_required")
                return false
            }
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
        logPush("starting system remote notification registration", level: .info)
        #if os(iOS) && canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #elseif os(macOS) && canImport(AppKit)
        NSApplication.shared.registerForRemoteNotifications()
        #else
        logPush("system remote notification registration unavailable on this platform")
        #endif
    }

    private func registerStoredPushTokenIfPossible(recoveringOwnerTransition: Bool = false) {
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
        let categories = DJConnectPushRegistrationRequest.defaultNotificationCategories
        let registrationSignature = pushRegistrationSignature(
            pushToken: token,
            pushEnvironment: environment,
            appBundleID: appBundleID,
            locale: locale
        )
        if defaults.string(forKey: registeredPushTokenHashKey) == tokenHash,
           defaults.string(forKey: registeredPushEnvironmentKey) == environment.rawValue,
           defaults.string(forKey: registeredPushSignatureKey) == registrationSignature,
           defaults.bool(forKey: pushRegisteredKey) {
            return
        }
        if pushRegistrationInFlightSignature == registrationSignature {
            logPush("registration skipped in_flight=true")
            return
        }
        pushRegistrationInFlightSignature = registrationSignature
        pushRegistrationAttemptEpoch = sessionHistory.responseEpoch
        Task { @MainActor in
            var handledCurrentRegistrationFailure = false
            defer {
                let retryOwnerTransition = !handledCurrentRegistrationFailure && !recoveringOwnerTransition && isAppInForeground
                    && pushRegistrationAttemptEpoch != sessionHistory.responseEpoch
                    && isCurrentPushRegistration(registrationSignature, requiringCurrentOwnerEpoch: false)
                if pushRegistrationInFlightSignature == registrationSignature {
                    pushRegistrationInFlightSignature = nil
                    pushRegistrationAttemptEpoch = nil
                }
                if retryOwnerTransition {
                    registerStoredPushTokenIfPossible(recoveringOwnerTransition: true)
                }
            }
            do {
                let response = try await registerPushTokenWithHomeAssistant(
                    token: token,
                    pushEnvironment: environment,
                    appBundleID: appBundleID,
                    locale: locale,
                    categories: categories,
                    bootstrapProof: nil
                )
                guard isCurrentPushRegistration(registrationSignature) else { return }
                try await handlePushRegistrationResponse(
                    response,
                    token: token,
                    tokenHash: tokenHash,
                    pushEnvironment: environment,
                    appBundleID: appBundleID,
                    locale: locale,
                    categories: categories,
                    registrationSignature: registrationSignature
                )
            } catch let error as DJConnectError {
                guard isCurrentPushRegistration(registrationSignature) else { return }
                // Error handling may itself withdraw private projections/advance
                // the owner epoch before verifying pairing with read-only HTTP.
                // That self-induced epoch is not a new registration opportunity.
                handledCurrentRegistrationFailure = true
                await handlePushRegistrationError(
                    error,
                    token: token,
                    tokenHash: tokenHash,
                    pushEnvironment: environment,
                    appBundleID: appBundleID,
                    locale: locale,
                    categories: categories,
                    registrationSignature: registrationSignature
                )
            } catch {
                guard isCurrentPushRegistration(registrationSignature), !(error is CancellationError) else { return }
                recordPushRegistrationFailure("push_registration_failed")
                logPush("registration failed error=\(error.localizedDescription)", level: .warning)
            }
        }
    }

    private func registerPushTokenWithHomeAssistant(
        token: String,
        pushEnvironment: DJConnectPushEnvironment,
        appBundleID: String,
        locale: String,
        categories: [String],
        bootstrapProof: String?
    ) async throws -> DJConnectCommandResponse {
        let authPresent = (try? tokenStore.loadToken())?.isEmpty == false
        logPush(
            "register payload endpoint=/api/djconnect/v1/push/register ha_host=\(Self.hostForLog(from: localHomeAssistantURL())) device_id_present=\(!identity.deviceID.isEmpty) client_type=\(identity.clientType.rawValue) env=\(pushEnvironment.rawValue) app_bundle_id=\(appBundleID) app_version=\(appVersion) locale=\(locale) categories=\(categories) push_token_present=\(!token.isEmpty) bootstrap_proof_present=\(bootstrapProof?.isEmpty == false) auth_present=\(authPresent)"
        )
        let response = try await withHomeAssistantClient { client in
            try await client.registerPushNotifications(DJConnectPushRegistrationRequest(
                identity: identity,
                pushToken: token,
                pushEnvironment: pushEnvironment,
                appBundleID: appBundleID,
                appVersion: appVersion,
                locale: locale,
                notificationCategories: categories,
                bootstrapProof: bootstrapProof
            ))
        }
        logPushRegistrationResponse(response, expectedEnvironment: pushEnvironment)
        return response
    }

    private func handlePushRegistrationResponse(
        _ response: DJConnectCommandResponse,
        token: String,
        tokenHash: String,
        pushEnvironment: DJConnectPushEnvironment,
        appBundleID: String,
        locale: String,
        categories: [String],
        registrationSignature: String
    ) async throws {
        applyPushRegistrationStatus(from: response)
        let responseEnvironment = response.pushEnvironment
        let canonicalEnvironment = responseEnvironment ?? pushEnvironment
        let environmentMatches = pushEnvironment.isCompatible(with: responseEnvironment)
        guard response.success, response.pushRegistered == true, response.pushSupported != false, environmentMatches else {
            let reason = response.error ?? response.lastPushError ?? (response.pushRegistered == nil ? "push_registration_unconfirmed" : response.message ?? "unknown")
            if Self.isMissingBootstrapProof(reason) {
                try await retryPushRegistrationAfterBootstrap(
                    reason: reason,
                    token: token,
                    tokenHash: tokenHash,
                    pushEnvironment: pushEnvironment,
                    appBundleID: appBundleID,
                    locale: locale,
                    categories: categories,
                    registrationSignature: registrationSignature
                )
                return
            }
            rejectPushRegistration(reason: reason, environmentMatches: environmentMatches, responseEnvironment: responseEnvironment, expectedEnvironment: pushEnvironment)
            return
        }
        acceptPushRegistration(
            tokenHash: tokenHash,
            pushEnvironment: pushEnvironment,
            canonicalEnvironment: canonicalEnvironment,
            registrationSignature: registrationSignature
        )
    }

    private func handlePushRegistrationError(
        _ error: DJConnectError,
        token: String,
        tokenHash: String,
        pushEnvironment: DJConnectPushEnvironment,
        appBundleID: String,
        locale: String,
        categories: [String],
        registrationSignature: String
    ) async {
        guard isCurrentPushRegistration(registrationSignature) else { return }
        let reason = Self.describe(error)
        if Self.isStalePairingPushError(error) {
            recordPushRegistrationFailure("push_registration_failed")
            logPush("registration pairing_verification_required=true error=\(reason)", level: .warning)
            await recoverAfterPairedAuthorityWithdrawal("unauthorized")
            return
        }
        if Self.isMissingBootstrapProof(reason) {
            do {
                try await retryPushRegistrationAfterBootstrap(
                    reason: reason,
                    token: token,
                    tokenHash: tokenHash,
                    pushEnvironment: pushEnvironment,
                    appBundleID: appBundleID,
                    locale: locale,
                    categories: categories,
                    registrationSignature: registrationSignature
                )
            } catch let retryError as DJConnectError {
                guard isCurrentPushRegistration(registrationSignature) else { return }
                if Self.isStalePairingPushError(retryError) {
                    logPush("registration pairing_verification_required=true error=\(Self.describe(retryError))", level: .warning)
                    await recoverAfterPairedAuthorityWithdrawal("unauthorized")
                } else if case .routeMissing = retryError {
                    logPush("bootstrap skipped route_missing=true", level: .warning)
                } else {
                    markPushRegistrationBootstrapRecoveryFailed(reason: Self.describe(retryError))
                }
            } catch {
                guard isCurrentPushRegistration(registrationSignature), !(error is CancellationError) else { return }
                markPushRegistrationBootstrapRecoveryFailed(reason: error.localizedDescription)
            }
            return
        }
        if case .routeMissing = error {
            recordPushRegistrationFailure("push_route_unavailable")
            logPush("registration skipped route_missing=true")
        } else {
            recordPushRegistrationFailure("push_registration_failed")
            logPush("registration failed error=\(reason)", level: .warning)
        }
    }

    private func retryPushRegistrationAfterBootstrap(
        reason: String,
        token: String,
        tokenHash: String,
        pushEnvironment: DJConnectPushEnvironment,
        appBundleID: String,
        locale: String,
        categories: [String],
        registrationSignature: String
    ) async throws {
        guard isCurrentPushRegistration(registrationSignature) else { throw CancellationError() }
        defaults.set(false, forKey: pushRegisteredKey)
        defaults.removeObject(forKey: registeredPushSignatureKey)
        logPush("registration bootstrap_required=true reason=\(Self.bootstrapProofFailureCode(reason))", level: .warning)
        let bootstrapProof: String?
        do {
            bootstrapProof = try await fetchBootstrapProofForPushRegistration(
                identity: identity,
                pushEnvironment: pushEnvironment,
                appBundleID: appBundleID,
                isStillCurrent: { self.isCurrentPushRegistration(registrationSignature) }
            )
        } catch let error as DJConnectError {
            guard isCurrentPushRegistration(registrationSignature) else { throw CancellationError() }
            markPushRegistrationBootstrapRecoveryFailed(reason: Self.describe(error))
            return
        } catch {
            guard isCurrentPushRegistration(registrationSignature), !(error is CancellationError) else { throw CancellationError() }
            markPushRegistrationBootstrapRecoveryFailed(reason: error.localizedDescription)
            return
        }
        guard isCurrentPushRegistration(registrationSignature) else { throw CancellationError() }
        guard let bootstrapProof else {
            if let issuerError = defaults.string(forKey: lastPushErrorKey),
               issuerError != "missing_bootstrap_proof" {
                if issuerError == "bootstrap_proof_unavailable" {
                    markPushRegistrationBootstrapUnavailable()
                } else {
                    logPush("registration recovery_required=true reason=\(issuerError) message=issuer_rejected_bootstrap_context push_registered=false", level: .warning)
                }
            } else if defaults.string(forKey: lastPushErrorKey) == "bootstrap_proof_unavailable" {
                markPushRegistrationBootstrapUnavailable()
            } else {
                markPushRegistrationBootstrapRecoveryFailed(reason: reason)
            }
            return
        }
        logPush("registration retry_with_bootstrap_proof=true bootstrap_proof_present=true")
        let retryResponse = try await registerPushTokenWithHomeAssistant(
            token: token,
            pushEnvironment: pushEnvironment,
            appBundleID: appBundleID,
            locale: locale,
            categories: categories,
            bootstrapProof: bootstrapProof
        )
        guard isCurrentPushRegistration(registrationSignature) else { throw CancellationError() }
        applyPushRegistrationStatus(from: retryResponse)
        let retryReason = retryResponse.error ?? retryResponse.lastPushError ?? retryResponse.message ?? ""
        if Self.isBootstrapProofUnavailable(retryReason) {
            markPushRegistrationBootstrapUnavailable()
            return
        }
        if Self.isInvalidBootstrapProof(retryReason) {
            markPushRegistrationBootstrapRecoveryFailed(reason: "invalid_bootstrap_proof")
            return
        }
        try await handleFinalPushRegistrationRecoveryResponse(
            retryResponse,
            tokenHash: tokenHash,
            pushEnvironment: pushEnvironment,
            registrationSignature: registrationSignature
        )
    }

    private func handleFinalPushRegistrationRecoveryResponse(
        _ response: DJConnectCommandResponse,
        tokenHash: String,
        pushEnvironment: DJConnectPushEnvironment,
        registrationSignature: String
    ) async throws {
        let responseEnvironment = response.pushEnvironment
        let canonicalEnvironment = responseEnvironment ?? pushEnvironment
        let environmentMatches = pushEnvironment.isCompatible(with: responseEnvironment)
        guard response.success, response.pushRegistered == true, response.pushSupported != false, environmentMatches else {
            let retryReason = response.error ?? response.lastPushError ?? (response.pushRegistered == nil ? "push_registration_unconfirmed" : response.message ?? "unknown")
            if Self.isBootstrapProofUnavailable(retryReason) {
                markPushRegistrationBootstrapUnavailable()
            } else if Self.requiresBootstrapProof(retryReason) {
                markPushRegistrationBootstrapRecoveryFailed(reason: retryReason)
            } else {
                rejectPushRegistration(reason: retryReason, environmentMatches: environmentMatches, responseEnvironment: responseEnvironment, expectedEnvironment: pushEnvironment)
            }
            return
        }
        acceptPushRegistration(
            tokenHash: tokenHash,
            pushEnvironment: pushEnvironment,
            canonicalEnvironment: canonicalEnvironment,
            registrationSignature: registrationSignature
        )
    }

    private func fetchBootstrapProofForPushRegistration(
        identity: DJConnectIdentity,
        pushEnvironment: DJConnectPushEnvironment,
        appBundleID: String,
        isStillCurrent: () -> Bool
    ) async throws -> String? {
        guard isStillCurrent() else {
            logPush("bootstrap cancelled current_context=false", level: .info)
            throw CancellationError()
        }
        guard let issuerBaseURL = trustedPairingIssuerBaseURL else {
            recordPushRegistrationFailure("trusted_issuer_not_configured")
            logPush("bootstrap issuer unavailable reason=trusted_issuer_not_configured", level: .warning)
            return nil
        }

        let payload = DJConnectPairingBootstrapProofRequest(
            haInstallID: defaults.string(forKey: haInstallIDKey),
            integrationVersion: defaults.string(forKey: integrationVersionKey),
            identity: identity,
            pairingSessionID: defaults.string(forKey: pairingSessionIDKey),
            appBundleID: appBundleID,
            pushEnvironment: pushEnvironment
        )
        logPush("bootstrap issuer_request endpoint=/v1/pairing/bootstrap-proof issuer_host=\(Self.hostForLog(from: issuerBaseURL.absoluteString)) device_id_present=\(!identity.deviceID.isEmpty) client_type=\(identity.clientType.rawValue) env=\(pushEnvironment.rawValue) app_bundle_id=\(appBundleID)")
        let response = try await requestTrustedIssuerBootstrapProof(baseURL: issuerBaseURL, payload: payload)
        guard isStillCurrent() else { throw CancellationError() }
        guard response.success else {
            let reason = response.error ?? response.message ?? "bootstrap_proof_unavailable"
            logPush("bootstrap issuer_unavailable issuer_error_code=\(Self.bootstrapProofFailureCode(reason)) bootstrap_proof_present=false", level: .warning)
            if Self.isBootstrapProofUnavailable(reason) || Self.isKnownBootstrapIssuerClientError(reason) {
                defaults.set(Self.bootstrapProofFailureCode(reason), forKey: lastPushErrorKey)
            }
            return nil
        }
        let proof = try Self.validatedIssuerBootstrapProof(response)
        logPush("bootstrap issuer_received bootstrap_proof_present=true expires_at_present=\(response.expiresAt?.isEmpty == false)")
        return proof
    }

    private func requestTrustedIssuerBootstrapProof(
        baseURL: URL,
        payload: DJConnectPairingBootstrapProofRequest
    ) async throws -> DJConnectPairingBootstrapProofResponse {
        let endpoint = baseURL.appendingPathComponent("v1/pairing/bootstrap-proof")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DJConnectError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            logPush("bootstrap issuer_http_failed status=\(httpResponse.statusCode)", level: .warning)
            return DJConnectPairingBootstrapProofResponse(success: false, error: "issuer_http_\(httpResponse.statusCode)")
        }
        return try JSONDecoder().decode(DJConnectPairingBootstrapProofResponse.self, from: data)
    }

    private func logPushRegistrationResponse(_ response: DJConnectCommandResponse, expectedEnvironment: DJConnectPushEnvironment) {
        let responseError = Self.redactedPushFailureReason(response.lastPushError ?? response.error ?? "<missing>")
        let responseEnvironment = response.pushEnvironment
        let canonicalEnvironment = responseEnvironment ?? expectedEnvironment
        logPush("register response http_status=decoded success=\(response.success) push_supported=\(Self.optionalBoolForLog(response.pushSupported)) push_registered=\(Self.optionalBoolForLog(response.pushRegistered)) client_type=\(identity.clientType.rawValue) canonical_push_environment=\(canonicalEnvironment.rawValue) push_environment=\(responseEnvironment?.rawValue ?? "<missing>") last_push_error=\(responseError)")
    }

    private func acceptPushRegistration(
        tokenHash: String,
        pushEnvironment: DJConnectPushEnvironment,
        canonicalEnvironment: DJConnectPushEnvironment,
        registrationSignature: String
    ) {
        defaults.removeObject(forKey: registeredPushTokenKey)
        defaults.set(tokenHash, forKey: registeredPushTokenHashKey)
        defaults.set(pushEnvironment.rawValue, forKey: registeredPushEnvironmentKey)
        defaults.set(registrationSignature, forKey: registeredPushSignatureKey)
        defaults.set(true, forKey: pushRegisteredKey)
        defaults.removeObject(forKey: lastPushErrorKey)
        refreshPushNotificationStatus()
        logPush("registered with Home Assistant client_type=\(identity.clientType.rawValue) env=\(canonicalEnvironment.rawValue) push_registered=true", level: .info)
    }

    private func rejectPushRegistration(
        reason: String,
        environmentMatches: Bool,
        responseEnvironment: DJConnectPushEnvironment?,
        expectedEnvironment: DJConnectPushEnvironment
    ) {
        defaults.set(false, forKey: pushRegisteredKey)
        defaults.removeObject(forKey: registeredPushSignatureKey)
        if !environmentMatches {
            let responseValue = responseEnvironment?.rawValue ?? "<missing>"
            defaults.set("push_environment_mismatch", forKey: lastPushErrorKey)
            logPush("registration rejected push_environment_mismatch expected=\(expectedEnvironment.rawValue) response=\(responseValue) push_registered=false", level: .warning)
        } else {
            defaults.set(Self.redactedPushFailureReason(reason), forKey: lastPushErrorKey)
            log(.warning, "Push registration was not accepted by Home Assistant: \(Self.redactedPushFailureReason(reason))")
        }
        refreshPushNotificationStatus()
    }

    private func markPushRegistrationBootstrapRecoveryFailed(reason: String) {
        defaults.set(false, forKey: pushRegisteredKey)
        defaults.removeObject(forKey: registeredPushSignatureKey)
        let code = Self.bootstrapProofFailureCode(reason)
        defaults.set(code, forKey: lastPushErrorKey)
        refreshPushNotificationStatus()
        logPush("registration recovery_required=true reason=\(code) message=pair_with_home_assistant_again push_registered=false", level: .warning)
    }

    private func markPushRegistrationBootstrapUnavailable() {
        defaults.set(false, forKey: pushRegisteredKey)
        defaults.removeObject(forKey: registeredPushSignatureKey)
        defaults.set("bootstrap_proof_unavailable", forKey: lastPushErrorKey)
        refreshPushNotificationStatus()
        logPush("bootstrap unavailable reason=bootstrap_proof_unavailable message=push_bootstrap_not_available_for_home_assistant_installation push_registered=false", level: .warning)
    }

    private func isCurrentPushRegistration(_ signature: String, requiringCurrentOwnerEpoch: Bool = true) -> Bool {
        guard !Task.isCancelled, pairingStatus == .paired,
              pushRegistrationInFlightSignature == signature,
              (!requiringCurrentOwnerEpoch || pushRegistrationAttemptEpoch == sessionHistory.responseEpoch),
              let token = currentAPNsPushToken else { return false }
        return signature == pushRegistrationSignature(
            pushToken: token, pushEnvironment: Self.pushEnvironment,
            appBundleID: Bundle.main.bundleIdentifier ?? "dev.djconnect.\(identity.clientType.rawValue)",
            locale: Locale.current.identifier
        )
    }

    private func pushRegistrationSignature(
        pushToken: String,
        pushEnvironment: DJConnectPushEnvironment,
        appBundleID: String,
        locale: String
    ) -> String {
        [
            identity.deviceID,
            identity.clientType.rawValue,
            Self.pushTokenHash(pushToken),
            pushEnvironment.rawValue,
            appBundleID,
            appVersion,
            locale,
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
        refreshPushNotificationStatus()
        logPush("status push_supported=\(Self.optionalBoolForLog(response.pushSupported)) push_registered=\(Self.optionalBoolForLog(response.pushRegistered)) push_environment=\(response.pushEnvironment?.rawValue ?? "<missing>") last_push_error=\(Self.redactedPushFailureReason(response.lastPushError ?? "<missing>"))")
    }

    private func recordPushRegistrationFailure(_ code: String) {
        defaults.set(false, forKey: pushRegisteredKey)
        defaults.removeObject(forKey: registeredPushSignatureKey)
        defaults.set(code, forKey: lastPushErrorKey)
        refreshPushNotificationStatus()
    }

    public func retryPushNotificationRegistration() {
        guard pairingStatus == .paired, !isDemoMode else { return }
        defaults.removeObject(forKey: registeredPushSignatureKey)
        requestRemoteNotificationRegistration(allowSystemPrompt: true)
    }

    public func openNotificationSettings() {
        #if canImport(AppKit)
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
        #elseif canImport(UIKit)
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            Task { await UIApplication.shared.open(url) }
        }
        #endif
    }

    private func refreshPushNotificationStatus() {
        pushNotificationStatus = Self.pushNotificationStatus(defaults: defaults)
    }

    private static func pushNotificationStatus(defaults: UserDefaults) -> DJConnectPushNotificationStatus {
        let hasSupportedValue = defaults.object(forKey: "DJConnectPushSupported") != nil
        let supported = defaults.bool(forKey: "DJConnectPushSupported")
        let registered = defaults.bool(forKey: "DJConnectPushRegistered")
        let environment = defaults
            .string(forKey: "DJConnectPushEnvironmentStatus")
            .flatMap(DJConnectPushEnvironment.init(rawValue:))
        let error = defaults.string(forKey: "DJConnectLastPushError")
        if hasSupportedValue, !supported {
            return DJConnectPushNotificationStatus(state: .unavailable, environment: environment, lastError: error)
        }
        if registered {
            return DJConnectPushNotificationStatus(state: .registered, environment: environment, lastError: nil)
        }
        if let error, !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return DJConnectPushNotificationStatus(state: .actionNeeded, environment: environment, lastError: error)
        }
        return DJConnectPushNotificationStatus(state: .inactive, environment: environment, lastError: nil)
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

    private func logPush(_ message: String, level: DJConnectAppLogLevel = .debug) {
        log(level, "[DJConnectPush] \(message)")
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
        DJConnectLogRedactor.redactText(reason)
    }

    private static func defaultTrustedPairingIssuerBaseURL() -> URL? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "DJConnectTrustedPairingIssuerBaseURL") as? String else {
            return nil
        }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return URL(string: trimmed)
    }

    private static func validatedIssuerBootstrapProof(
        _ response: DJConnectPairingBootstrapProofResponse,
        now: Date = Date()
    ) throws -> String {
        let proof = response.bootstrapProof?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !proof.isEmpty, proof.hasPrefix("djcboot_") else {
            throw DJConnectError.invalidConfiguration("trusted_issuer_invalid_bootstrap_proof")
        }
        guard let expiresAt = response.expiresAt?.trimmingCharacters(in: .whitespacesAndNewlines), !expiresAt.isEmpty else {
            throw DJConnectError.invalidConfiguration("trusted_issuer_missing_bootstrap_proof_expiry")
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        guard let expiry = formatter.date(from: expiresAt) ?? fallbackFormatter.date(from: expiresAt) else {
            throw DJConnectError.invalidConfiguration("trusted_issuer_invalid_bootstrap_proof_expiry")
        }
        guard expiry > now else {
            throw DJConnectError.invalidConfiguration("trusted_issuer_expired_bootstrap_proof")
        }
        guard expiry.timeIntervalSince(now) <= 15 * 60 else {
            throw DJConnectError.invalidConfiguration("trusted_issuer_excessive_bootstrap_proof_lifetime")
        }
        return proof
    }

    private static func isInvalidBootstrapProof(_ reason: String) -> Bool {
        reason.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().contains("invalid_bootstrap_proof")
    }

    private static func isMissingBootstrapProof(_ reason: String) -> Bool {
        reason.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().contains("missing_bootstrap_proof")
    }

    private static func requiresBootstrapProof(_ reason: String) -> Bool {
        isMissingBootstrapProof(reason)
    }

    private static func isBootstrapProofUnavailable(_ reason: String) -> Bool {
        let normalizedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedReason.contains("bootstrap_proof_unavailable")
            || normalizedReason.contains("bootstrap_rate_limited")
    }

    private static func isKnownBootstrapIssuerClientError(_ reason: String) -> Bool {
        let normalizedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedReason.contains("invalid_client_type")
            || normalizedReason.contains("invalid_app_bundle_id")
            || normalizedReason.contains("invalid_push_environment")
    }

    private static func bootstrapProofFailureCode(_ reason: String) -> String {
        let normalizedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedReason.contains("trusted_issuer_invalid_bootstrap_proof") {
            return "trusted_issuer_invalid_bootstrap_proof"
        }
        if normalizedReason.contains("trusted_issuer_expired_bootstrap_proof") {
            return "trusted_issuer_expired_bootstrap_proof"
        }
        if normalizedReason.contains("trusted_issuer_missing_bootstrap_proof_expiry") {
            return "trusted_issuer_missing_bootstrap_proof_expiry"
        }
        if normalizedReason.contains("trusted_issuer_invalid_bootstrap_proof_expiry") {
            return "trusted_issuer_invalid_bootstrap_proof_expiry"
        }
        if normalizedReason.contains("trusted_issuer_excessive_bootstrap_proof_lifetime") {
            return "trusted_issuer_excessive_bootstrap_proof_lifetime"
        }
        if normalizedReason.contains("bootstrap_rate_limited") {
            return "bootstrap_rate_limited"
        }
        if normalizedReason.contains("invalid_client_type") {
            return "invalid_client_type"
        }
        if normalizedReason.contains("invalid_app_bundle_id") {
            return "invalid_app_bundle_id"
        }
        if normalizedReason.contains("invalid_push_environment") {
            return "invalid_push_environment"
        }
        if isBootstrapProofUnavailable(reason) {
            return "bootstrap_proof_unavailable"
        }
        if isInvalidBootstrapProof(reason) {
            return "invalid_bootstrap_proof"
        }
        if isMissingBootstrapProof(reason) {
            return "missing_bootstrap_proof"
        }
        return redactedPushFailureReason(reason)
    }

    private static func isStalePairingPushError(_ error: DJConnectError) -> Bool {
        switch error {
        case .authStale:
            return true
        case let .server(statusCode, message):
            guard statusCode == 401 || statusCode == 403 else {
                return false
            }
            if let message, requiresBootstrapProof(message) {
                return false
            }
            return true
        default:
            return false
        }
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

    public func resolvedMusicDNAArtworkURL(_ imageURL: String?, uri: String?, artist: Bool) -> URL? {
        let direct = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let reference = direct?.isEmpty == false ? direct : currentMusicDNAArtworkReference(
            discovery: musicDiscoveryResponse, profileID: musicDNAProfileResponse?.profileID,
            uri: uri, artist: artist)
        return resolvedMusicDiscoveryImageURL(reference)
    }

    /// Discovery may reference public Spotify artwork, without sending app credentials.
    public func resolvedMusicDiscoveryImageURL(_ rawValue: String?) -> URL? {
        guard let raw = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: raw), url.user == nil, url.password == nil else { return nil }
        if url.scheme?.lowercased() == "https", url.host?.lowercased() == "i.scdn.co",
           url.port == nil || url.port == 443 {
            return url
        }
        return resolvedHomeAssistantImageURL(raw)
    }

    public func resolvedHomeAssistantImageURL(_ rawValue: String?) -> URL? {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
            return nil
        }
        guard let url = URL(string: rawValue) else {
            return nil
        }
        let baseURLs = homeAssistantBaseURLs()
        let allowedHosts = Set(baseURLs.compactMap { $0.host?.lowercased() })
        guard let primaryBaseURL = baseURLs.first else {
            return url
        }
        if allowedHosts.isEmpty {
            return URL(string: rawValue, relativeTo: primaryBaseURL)?.absoluteURL
        }
        return resolvedResponseImageURL(url, baseURL: primaryBaseURL, allowedHosts: allowedHosts)
    }

    private func resolvedResponseImageURL(_ url: URL, baseURL: URL, allowedHosts: Set<String>) -> URL? {
        if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            guard let host = url.host?.lowercased(), allowedHosts.contains(host) else {
                return nil
            }
            return resolvedArtworkURL(url)
        }
        guard url.host == nil else {
            return nil
        }
        guard url.scheme == nil else { return nil }
        return resolvedArtworkURL(url)
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
        case .backendUnavailable:
            guard shouldEmitBackendUnavailableNotice() else {
                return
            }
            showAskDJToast(backendUnavailableRecoveryMessage())
        case let .server(_, message):
            showAskDJToast(userFacingDJResponseText(message) ?? localized(key: "appModel.home.assistant.did.not.respond"))
        case let .decodingFailed(_, _, message):
            showAskDJToast(userFacingDJResponseText(message) ?? localized(key: "appModel.home.assistant.did.not.respond"))
        case .invalidResponse, .payloadTooLarge:
            showAskDJToast(localized(key: "appModel.home.assistant.did.not.respond"))
        case .network, .routeMissing, .notConfigured, .invalidConfiguration, .missingToken, .pairingFailed, .clientTypeMismatch:
            showAskDJToast(localized(key: "appModel.ask.dj.is.unreachable"))
        case .authStale, .versionMismatch, .trackInsightUnavailable, .profile:
            showAskDJToast(localized(key: "appModel.ask.dj.is.unreachable"))
        }
    }

    private func showAskDJToast(_ text: String) {
        askDJToast = DJConnectUserNotice(text: text)
    }

    private func askDJErrorText(for error: DJConnectError) -> String {
        switch error {
        case .backendUnavailable:
            backendUnavailableRecoveryMessage()
        case let .server(_, message):
            userFacingDJResponseText(message) ?? localized(key: "appModel.home.assistant.did.not.respond")
        case let .decodingFailed(_, _, message):
            userFacingDJResponseText(message) ?? localized(key: "appModel.home.assistant.did.not.respond")
        case .invalidResponse, .payloadTooLarge:
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
             .trackInsightUnavailable,
             .profile:
            askDJUnavailableText()
        }
    }

    private func askDJUnavailableText() -> String {
        localized(key: "appModel.ask.dj.is.unreachable")
    }

    private func liveConversationActionIsCurrent(_ action: DJConnectAskDJPlaybackAction) -> Bool {
        liveConversationPresentations.values.contains {
            $0.epoch == sessionHistory.responseEpoch && ($0.deadline.map { $0 > Date() } ?? true)
                && $0.message.playbackActions.contains(action)
        }
    }

    /// Current-only replies have no durable timeline entry. Render the directly
    /// accepted turn in its request surface without manufacturing history IDs.
    func currentSessionConversationMessages(sessionID: String, at date: Date = Date()) -> [DJConnectAskDJMessage] {
        let live = liveConversationPresentations.values.filter {
            $0.isPrivateEphemeral && $0.sessionID == sessionID && $0.epoch == sessionHistory.responseEpoch
                && ($0.deadline.map { $0 > date } ?? true)
        }
        let ids = Set(live.flatMap { [$0.message.id] + [$0.questionID].compactMap { $0 } })
        return askDJMessages.filter { ids.contains($0.id) }
    }

    func withdrawLiveConversationPresentations() {
        personaReplyScope = nil
        let ids = Set(liveConversationPresentations.keys)
        let ephemeralIDs = Set(liveConversationPresentations.filter { $0.value.isPrivateEphemeral }.keys)
        let questionIDs = Set(liveConversationPresentations.values.filter { $0.isPrivateEphemeral }.compactMap(\.questionID))
        askDJMessages.removeAll { questionIDs.contains($0.id) || ($0.serverID.map(ephemeralIDs.contains) ?? false) }
        liveConversationPresentations = [:]
        liveConversationExpiryTask?.cancel(); liveConversationExpiryTask = nil
        askDJMessages = askDJMessages.map { original in
            guard let id = original.serverID, ids.contains(id) else { return original }
            var message = original
            message.images = []; message.links = []; message.items = []; message.playbackActions = []
            message.trackInsight = nil
            return message
        }
    }

    private func clearAskDJHistoryLocally() {
        personaReplyScope = nil
        invalidateConversationResultLeases()
        liveConversationPresentations = [:]
        liveConversationExpiryTask?.cancel(); liveConversationExpiryTask = nil
        askDJMessages = []
        guard !isDemoMode else { return }
        defaults.removeObject(forKey: askDJMessagesKey)
        defaults.removeObject(forKey: askDJHistoryRevisionKey)
        defaults.removeObject(forKey: askDJClearRevisionKey)
        clearAskDJWidgetSnapshot(reason: "Ask DJ history cleared")
    }

    private func saveAskDJMessages() {
        guard !isDemoMode, !sessionHistory.profileScopeActive else { return }
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

    private func saveAskDJWidgetSnapshot() { syncSessionSurfaces() }
    private func clearAskDJWidgetSnapshot(reason: String) { syncSessionSurfaces() }

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
        if Self.isVolumeControlUnavailable(text) {
            return localized(key: "appModel.device.volume.control.unavailable")
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
        if Self.looksLikeHTMLDocument(normalized) {
            log(.warning, "Suppressed HTML response in pairing message")
            return localized(key: "appModel.home.assistant.could.not.complete.pairing.check.the.url")
        }
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

    private func safePairingMessage(from text: String?) -> String {
        guard let text else {
            return localized(key: "appModel.home.assistant.could.not.complete.pairing.check.the.url")
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return localized(key: "appModel.home.assistant.could.not.complete.pairing.check.the.url")
        }
        if let message = Self.extractServerJSONMessage(from: trimmed) {
            return userFacingPairingMessage(from: message)
                ?? localized(key: "appModel.home.assistant.could.not.complete.pairing.check.the.url")
        }
        if Self.looksLikeHTMLDocument(trimmed.lowercased()) {
            log(.warning, "Suppressed HTML response in raw pairing message")
            return localized(key: "appModel.home.assistant.could.not.complete.pairing.check.the.url")
        }
        return trimmed
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
        let shouldClearDJResponse = isRecoverableVoiceErrorText(djResponseText)
        let shouldClearVoiceError = voiceErrorMessage.map(isRecoverableVoiceErrorText) == true
        guard shouldClearDJResponse || shouldClearVoiceError else {
            return
        }
        if shouldClearDJResponse {
            djResponseText = ""
        }
        if shouldClearVoiceError {
            voiceErrorMessage = nil
        }
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
            || normalized == backendUnavailableRecoveryMessage().lowercased()
            || normalized == "the music backend in home assistant is temporarily unavailable. djconnect will retry automatically."
            || normalized == "de muziekbackend in home assistant is tijdelijk niet beschikbaar. djconnect probeert automatisch opnieuw."
    }

    public var backendUnavailableRecoveryText: String {
        backendUnavailableRecoveryMessage()
    }

    private func backendUnavailableRecoveryMessage() -> String {
        localized(key: "appModel.music.backend.temporarily.unavailable.retrying")
    }

    private func backendUnavailableRecoveryMessage(for message: String?) -> String {
        if let userFacingMessage = userFacingDJResponseText(message ?? ""),
           !Self.isMusicBackendUnavailableText(userFacingMessage) {
            return userFacingMessage
        }
        return backendUnavailableRecoveryMessage()
    }

    private func shouldEmitBackendUnavailableNotice(now: Date = Date()) -> Bool {
        if let lastBackendUnavailableNoticeAt,
           now.timeIntervalSince(lastBackendUnavailableNoticeAt) < backendUnavailableNoticeInterval {
            return false
        }
        lastBackendUnavailableNoticeAt = now
        return true
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
        guard let resolvedURL = resolvedAudioURL(from: audioURL), Self.isSupportedResponseAudioURL(resolvedURL) else { return }
        #if canImport(AVFoundation)
        // Claim ownership before scheduling: Stop can arrive before this Task starts.
        guard let ticket = responsePlaybackCoordinator.begin(deadline: Date().addingTimeInterval(120)) else { return }
        Task { await playResponseAudio(resolvedURL, ticket: ticket) }
        #else
        Task { await playResponseAudio(resolvedURL) }
        #endif
    }

    public func requestRemoteNotificationRegistration(allowSystemPrompt: Bool = false) {
        #if canImport(UserNotifications)
        guard !remoteNotificationRegistrationRequestedThisLaunch else {
            if currentAPNsPushToken == nil && (defaults.string(forKey: legacyPushTokenKey)?.isEmpty ?? true) {
                logPush("retrying system remote notification registration token_present=false", level: .info)
                registerForSystemRemoteNotifications()
            } else {
                registerStoredPushTokenIfPossible()
            }
            return
        }
        remoteNotificationRegistrationRequestedThisLaunch = true
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            logPush("init platform=\(identity.platform.rawValue) client_type=\(identity.clientType.rawValue) bundle_id=\(Bundle.main.bundleIdentifier ?? "<missing>") app_version=\(appVersion) app_build=\(buildVersion) protocol_version=\(Self.protocolVersion) env=\(Self.pushEnvironment.rawValue)", level: .info)
            let authorized = await requestRemoteNotificationAuthorizationIfNeeded(
                center: center,
                allowSystemPrompt: allowSystemPrompt
            )
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
        logPush("received APNs token bytes=\(deviceToken.count) hex_length=\(token.count) push_token_present=true", level: .info)
        registerStoredPushTokenIfPossible()
    }

    public func handleRemoteNotificationRegistrationError(_ error: Error) {
        recordPushRegistrationFailure("apns_registration_failed")
        logPush("system remote notification registration failed error=\(error.localizedDescription)", level: .warning)
    }

    @discardableResult
    public func handleRemoteNotificationPayload(_ userInfo: [AnyHashable: Any], openedFromTap: Bool = false) async -> Bool {
        let event = Self.pushEventType(in: userInfo)
        guard event == "music_discovery_ready" else {
            guard event == "ask_dj_response" || event == "ask_dj_confirm" || (event == nil && openedFromTap) else { return false }
            if openedFromTap { performHomeScreenAction(.askDJ) }
            await refreshAskDJHistory()
            return true
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
        defaults.removeObject(forKey: lastPushErrorKey)
        refreshPushNotificationStatus()
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
        if sharedSpeechIsPreparing || sharedSpeechIsPlaying { sharedSpeechDelivery["local"] = "stopped" }
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

    private static func isSupportedResponseAudioURL(_ audioURL: URL) -> Bool {
        let pathExtension = audioURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return pathExtension == "mp3" || pathExtension == "wav"
    }

    private func playResponseAudioIfNeeded(_ audioURL: URL?) async {
        guard sharedDJSpeechAllowed else { return }
        guard localResponseAudioEnabled else {
            log(.debug, "Skipping DJ response audio because local response audio is disabled")
            return
        }
        await playResponseAudio(audioURL)
    }

    private func playResponseAudio(_ audioURL: URL?, ticket pendingTicket: DJConnectAudioPlaybackCoordinator.Ticket? = nil) async {
        guard sharedDJSpeechAllowed else { return }
        guard let audioURL else {
            return
        }
        guard Self.isSupportedResponseAudioURL(audioURL) else {
            log(.warning, "Skipping unsupported DJ response audio type")
            return
        }
        #if canImport(AVFoundation)
        guard let ticket = pendingTicket ?? responsePlaybackCoordinator.begin(deadline: Date().addingTimeInterval(120)),
              responsePlaybackCoordinator.isCurrent(ticket) else { return }
        do {
            askDJAudioPlaybackState = .loading(audioURL)
            log(.info, "Loading DJ response audio from Home Assistant")
            #if os(iOS)
            try await configureDJConnectAudioSession(category: .playback, mode: .spokenAudio, options: [.duckOthers])
            guard responsePlaybackCoordinator.isCurrent(ticket) else { return }
            guard !Task.isCancelled else { responsePlaybackCoordinator.finish(ticket); return }
            try await setDJConnectAudioSessionActive(true)
            #endif
            guard responsePlaybackCoordinator.isCurrent(ticket) else { return }
            guard !Task.isCancelled else { responsePlaybackCoordinator.finish(ticket); return }
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
                guard !Task.isCancelled else { return }
                self?.responsePlaybackCoordinator.finish(ticket)
            }
        } catch {
            guard responsePlaybackCoordinator.isCurrent(ticket) else { return }
            responsePlaybackCoordinator.finish(ticket)
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
        applyErrorState: Bool = true,
        expectedOutputSelectionGeneration: Int? = nil,
        onConfirmed: (@MainActor () -> Void)? = nil
    ) async -> Bool {
        if (command == "set_volume" || command == "volume_delta"), !canControlPlaybackVolume { return false }
        let volumeKeyAtStart = volumeOutputKey
        let outputObservationAtStart = playbackOutputObservation
        let outputGeneration = expectedOutputSelectionGeneration ?? outputSelectionGeneration
        if (command == "devices" || command == "set_output"), outputGeneration != outputSelectionGeneration { return false }
        if isDemoMode {
            applyDemoCommand(command, value: value, play: play)
            if isAppInForeground { onConfirmed?() }
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
        var refreshOutputsAfterAcceptance = false
        var outputAccepted = true
        var explicitlyConfirmed = false
        do {
            try await withHomeAssistantClient(allowsOperationReplay: command != "set_output") { client in
                // Reads may use fallback; a transfer write is never replayed.
                if (command == "devices" || command == "set_output"), outputGeneration != outputSelectionGeneration {
                    throw CancellationError()
                }
                log(.debug, "Posting command \(command) to Home Assistant")
                let response = try await client.sendCommandResponse(
                    DJConnectCommandPayload(
                        identity: identity,
                        command: command,
                        value: value,
                        play: play,
                        limit: Self.commandLimit(for: command),
                        language: currentRequestLocale,
                        mood: confirmedSessionMoodInt,
                        musicDNAKey: askDJMusicDNAKey
                    )
                )
                if command == "devices" || command == "set_output" {
                    guard outputGeneration == outputSelectionGeneration else { throw CancellationError() }
                }
                if (command == "set_volume" || command == "volume_delta"),
                   response.success == false, Self.isVolumeControlUnavailable(response.message),
                   volumeOutputKey == volumeKeyAtStart {
                    volumeRejectedOutputKey = volumeKeyAtStart
                    pendingVolumePercent = nil
                }
                if command == "set_output", !response.success {
                    outputAccepted = false
                    userNotice = DJConnectUserNotice(text: playbackCommandFailureFallback(command: command))
                    return
                }
                apply(commandResponse: response, command: command,
                      reconcilePlaybackOutput: command == "devices" && playbackOutputObservation != outputObservationAtStart)
                outputAccepted = response.success != false
                explicitlyConfirmed = response.hasExplicitSuccess && response.success
                refreshOutputsAfterAcceptance = command == "set_output" && outputAccepted
            }
            if command == "set_output", !outputAccepted {
                if userNotice == nil { userNotice = DJConnectUserNotice(text: playbackCommandFailureFallback(command: command)) }
                return false
            }
            if refreshOutputsAfterAcceptance, outputGeneration == outputSelectionGeneration {
                // Transfer acceptance can precede the backend's active-device update.
                // Retry only the read, never the playback-transfer command.
                for attempt in 0..<4 {
                    if attempt > 0 {
                        try await Task.sleep(for: .milliseconds(350 * (1 << (attempt - 1))))
                    }
                    guard !Task.isCancelled, outputGeneration == outputSelectionGeneration else { return false }
                    if attempt == 1 {
                        // Some backends omit device flags and need a new playback
                        // snapshot. Keep that read local and finish with devices.
                        try? await refreshStatusWithFallback(isStillValid: { [weak self] in
                            self?.outputSelectionGeneration == outputGeneration
                        })
                    }
                    let read = await performCommand("devices", notifyUserOnError: false,
                                                    expectedOutputSelectionGeneration: outputGeneration)
                    if !read { break }
                    if read {
                        if case let .string(targetName) = value {
                            if availableOutputs.contains(where: { candidate in
                                guard candidate.active == true else { return false }
                                if let targetID = pendingOutputSelectionID { return candidate.id == targetID }
                                return candidate.id == targetName || candidate.name == targetName
                            }) { break }
                        } else {
                            // Backend-authored structured actions keep their own
                            // target contract; do not infer a speaker name locally.
                            break
                        }
                    }
                }
            }
            if Self.shouldRefreshPlaybackAfterCommand(command) {
                scheduleCommandRefresh(
                    reason: "Command \(command) Now Playing refresh completed",
                    delay: Self.shouldRefreshPlaybackAgainAfterCommand(command) ? .milliseconds(850) : .milliseconds(350)
                )
            }
            if onConfirmed != nil { recordPresentationState("artwork-ack-explicit-\(explicitlyConfirmed)-foreground-\(isAppInForeground)") }
            if explicitlyConfirmed, isAppInForeground, !Task.isCancelled { onConfirmed?() }
            log(.debug, "Command \(command) succeeded")
            return true
        } catch let error as DJConnectError {
            if (command == "devices" || command == "set_output"), outputGeneration != outputSelectionGeneration { return false }
            log(.warning, "Command \(command) failed: \(Self.describe(error))")
            if (command == "set_volume" || command == "volume_delta"),
               Self.isVolumeControlUnavailable(Self.describe(error)), volumeOutputKey == volumeKeyAtStart {
                volumeRejectedOutputKey = volumeKeyAtStart
                pendingVolumePercent = nil
            }
            let outputTargetFailure = command == "set_output" && Self.isOutputTransferFailure(error)
            if applyErrorState, !outputTargetFailure, !Self.isVolumeControlUnavailable(Self.describe(error)) {
                apply(error: error)
            }
            if outputTargetFailure {
                if notifyUserOnError { userNotice = DJConnectUserNotice(text: playbackCommandFailureFallback(command: command)) }
                return false
            }
            if notifyUserOnError {
                if case .backendUnavailable = error, !shouldEmitBackendUnavailableNotice() {
                    return false
                }
                userNotice = DJConnectUserNotice(text: playbackCommandFailureMessage(command: command, error: error))
            }
            return false
        } catch let outcome as DJConnectHybridTransportError {
            if (command == "devices" || command == "set_output"), outputGeneration != outputSelectionGeneration { return false }
            userNotice = DJConnectUserNotice(text: localized(key: outcome.localizationKey))
            if case .outcome(let receipt) = outcome, receipt.phase == "confirmed" {
                if isAppInForeground, !Task.isCancelled { onConfirmed?() }
                return true
            }
            return false
        } catch {
            if (command == "devices" || command == "set_output"), outputGeneration != outputSelectionGeneration { return false }
            log(.error, "Command \(command) failed unexpectedly: \(error.localizedDescription)")
            pairingMessage = error.localizedDescription
            if notifyUserOnError {
                userNotice = DJConnectUserNotice(text: playbackCommandFailureFallback(command: command))
            }
            return false
        }
    }

    /// A rejected Spotify/device transfer is local to that action. Availability
    /// remains owned by independent status reads, not this failed target write.
    /// Authentication, Profile authority and actual transport failures still use
    /// the ordinary recovery path.
    private static func isOutputTransferFailure(_ error: DJConnectError) -> Bool {
        switch error {
        case .backendUnavailable: return true
        case .server(let status, _): return [400, 404, 409, 422].contains(status) || (500...599).contains(status)
        default: return false
        }
    }

    private func playbackCommandFailureMessage(command: String, error: DJConnectError) -> String {
        switch error {
        case let .backendUnavailable(message):
            return backendUnavailableRecoveryMessage(for: message)
        case let .server(_, message),
             let .decodingFailed(_, _, message):
            if let message = userFacingDJResponseText(message ?? Self.describe(error)) {
                return message
            }
        default:
            break
        }

        if Self.isMusicBackendUnavailableError(error) {
            return backendUnavailableRecoveryMessage()
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
            if pendingSelectedOutputIsCachedSpotify {
                return localized(key: "appModel.cached.spotify.output.unavailable")
            }
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

    private func syncDemoSessionPlayback() {
        guard isDemoMode, var session = activeDJSession, var context = session.broadcast.playback, let playback else { return }
        let changed = context.title != playback.trackName || context.artist != playback.artistName
        context.title = playback.trackName; context.artist = playback.artistName
        context.state = playback.isPlaying == true ? "playing" : "paused"
        context.positionMS = playback.progressMS; context.durationMS = playback.durationMS
        context.artworkURL = playback.albumImageURL?.absoluteString
        session.broadcast.playback = context
        activeDJSession = session
        if changed { sessionHistory.recordDemoPlayback(title: playback.trackName ?? "", artist: playback.artistName ?? "") }
    }

    private func applyDemoSessionExamples() {
        guard isDemoMode else { return }
        do {
            let data = try DJConnectDemoSessionData.make(language: language, mood: selectedSessionMood)
            activeDJSession = data.active.applying(presence: .init(sessionID: data.active.id,
                selectedPresence: .balanced, presenceRevision: 0))
            activePresenceAvailable = true; activePresenceCapabilityStatus = .supported
            sessionHistory.installDemo(data, preservingArchives: true)
            syncDemoSessionPlayback()
            activeMoodAvailable = true
            djSessionErrorMessage = nil
        } catch {
            activeDJSession = nil; sessionHistory.reset()
            log(.warning, "Demo session examples unavailable")
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
        applyDemoSessionExamples()
        djResponseText = localized(key: "appModel.tap.the.microphone.icon.to.hear.a.sample.announcement")
        backendAvailable = true
        updateRequiredMessage = nil
        if startBackgroundTasks {
            updatePlaybackProgressTimer()
        }
    }

    #if DEBUG
    /// A missing lab credential must leave the normal auth fallback available.
    public static func sessionHistoryTestWebSocketAuth(token: String?) -> DJConnectHomeAssistantWebSocketAuth? {
        guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return nil }
        return DJConnectHomeAssistantWebSocketAuth { token }
    }

    static func allowsSessionHistoryTestEndpoint(_ value: String, environment: [String: String], arguments: [String]) -> Bool {
        guard let url = URL(string: value), let host = url.host, url.user == nil, url.password == nil else { return false }
        if ["127.0.0.1", "localhost"].contains(host) { return true }
        guard arguments.contains("--physical-session-history-test"), url.scheme == "http", url.port == 18192,
              environment["DJCONNECT_UITEST_PHYSICAL_HISTORY_HOST"] == host else { return false }
        let components = host.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 4 else { return false }
        let octets = components.compactMap { UInt8($0) }
        guard octets.count == 4 else { return false }
        return octets[0] == 10 || (octets[0] == 172 && (16...31).contains(octets[1])) || (octets[0] == 192 && octets[1] == 168)
    }

    public func applyUITestRuntimeFixture(_ rawScenario: String, physicalTestHost: String? = nil) {
        let scenario = rawScenario.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        isUITestRuntimeFixtureActive = true
        uiTestRuntimeFixtureScenario = scenario
        defaults.set(true, forKey: welcomeSeenKey)
        defaults.set(appVersion, forKey: lastSeenAppVersionKey)
        isShowingWelcome = false
        isShowingWhatsNew = false
        isLoadingWhatsNew = false
        isShowingCrashReportPrompt = false
        isShowingTokenStorageError = false
        isDemoMode = false
        isMonkeyTestingMode = false
        pairingFlowTarget = .iPhone
        pairingStatus = .paired
        isConnected = true
        isPairing = false
        isPairingScreenDismissed = scenario != "pairing_success"
        isShowingPairingSuccess = scenario == "pairing_success"
        pairingMessage = nil
        backendAvailable = true
        updateRequiredMessage = nil
        if scenario == "review_demo" { startDemoMode(); return }
        if scenario == "session_history_contract" || scenario == "paired_owner_contract" {
            var environment = ProcessInfo.processInfo.environment
            var arguments = ProcessInfo.processInfo.arguments
            if let physicalTestHost {
                environment["DJCONNECT_UITEST_PHYSICAL_HISTORY_HOST"] = physicalTestHost
                arguments.append("--physical-session-history-test")
            }
            guard Self.allowsSessionHistoryTestEndpoint(homeAssistantURL, environment: environment, arguments: arguments) else {
                pairingStatus = .unpaired; isConnected = false; return
            }
            webSocketFastPathEnabled = ProcessInfo.processInfo.environment["DJCONNECT_UITEST_HISTORY_TRANSPORT"] == "websocket"
            if scenario == "paired_owner_contract" {
                guard let url = URL(string: homeAssistantURL), ["127.0.0.1", "localhost"].contains(url.host),
                      url.scheme == "http", url.user == nil, url.password == nil, url.query == nil,
                      homeAssistantWebSocketAuth == nil else {
                    pairingStatus = .unpaired; isConnected = false; return
                }
                // Empty local test store, then actual ordinary pairing. No token override/HA credential.
                try? tokenStore.clearToken()
                pairingStatus = .unpaired; isConnected = false
                playback = nil; queueItems = []; playlistItems = []; askDJMessages = []
                Task {
                    do {
                        let client = DJConnectClient(baseURL: url, identity: identity, tokenStore: tokenStore, session: urlSession)
                        let response = try await client.pair(DJConnectPairingPayload(identity: identity,
                            pairingToken: identity.clientType == .macos ? "654321" : "123456"))
                        apply(musicBackendSummary: response.musicBackendSummary)
                        pairingStatus = .paired; isConnected = true
                        await sessionHistory.prepare(); await refreshActiveDJSession()
                    } catch { pairingStatus = .unpaired; isConnected = false; log(.warning, "Paired native test setup failed") }
                }
                return
            }
            try? tokenStore.saveToken("synthetic-fixture-token")
            playback = nil; queueItems = []; playlistItems = []; askDJMessages = []
            isAppInForeground = true; voiceStatus = .idle; voiceErrorMessage = nil
            Task { await sessionHistory.prepare(); await refreshActiveDJSession() }
            return
        }
        let fixtureResponse = Self.uiTestRuntimeCommandResponse
        apply(commandResponse: fixtureResponse)
        if let playback = fixtureResponse.playback {
            self.playback = playback
        }
        if let devices = fixtureResponse.devices {
            availableOutputs = normalizedOutputDevices(devices)
            selectedOutput = availableOutputs.first(where: { $0.active == true })?.name ?? noOutputName()
        }
        if let fixtureQueue = fixtureResponse.queue {
            queueItems = normalizedQueueItems(fixtureQueue)
            queue = queueItems.map(\.displayTitle)
            queueContext = fixtureResponse.queueContext
        }
        if let fixturePlaylists = fixtureResponse.playlists {
            playlistItems = fixturePlaylists
            playlists = fixturePlaylists.map(\.name)
        }
        djResponseText = "Ask DJ fixture response: backend text stays sanitized."
        voiceStatus = .idle
        voiceErrorMessage = nil

        switch scenario {
        case "moment_contract":
            try? tokenStore.saveToken("local-moment-contract-fixture")
            updateRequiredMessage = nil
            isAppInForeground = true
            Task { await refreshActiveDJSession() }
        case "pairing_success":
            isPairingScreenDismissed = false
            isShowingPairingSuccess = true
            pairingMessage = localized(key: "appModel.pairing.complete")
        case "offline_network":
            hasEvaluatedDeviceNetwork = true
            isDeviceNetworkAvailable = false
        case "backend_unavailable":
            apply(error: .backendUnavailable(message: "Fixture playback backend unavailable"))
            userNotice = nil
        case "stale_auth":
            apply(error: .authStale(statusCode: 401, message: "Fixture stale pairing"))
        case "version_mismatch":
            apply(error: .versionMismatch(DJConnectVersionMismatch(
                message: "Fixture update required",
                haVersion: "3.3.0",
                haMajorMinor: "3.3",
                firmware: Self.protocolVersion,
                firmwareMajorMinor: "3.2"
            )))
            isPairingScreenDismissed = true
        case "voice_unavailable":
            apply(error: .backendUnavailable(message: "Fixture voice backend unavailable"))
            djResponseText = "Ask DJ fixture response: backend text stays sanitized."
            userNotice = nil
        default:
            break
        }
    }

    private static var uiTestRuntimeCommandResponse: DJConnectCommandResponse {
        let output = DJConnectOutputDevice(
            id: "fixture-living-room",
            name: "Fixture Living Room",
            type: "speaker",
            active: true,
            supportsVolume: true,
            volumePercent: 54
        )
        return DJConnectCommandResponse(
            success: true,
            message: "Fixture runtime loaded",
            backendAvailable: true,
            haVersion: protocolVersion,
            haMajorMinor: "3.2",
            musicBackend: "music_assistant",
            musicBackendName: "Music Assistant",
            musicBackendAvailable: true,
            playback: DJConnectPlayback(
                hasPlayback: true,
                isPlaying: true,
                trackName: "Fixture Track",
                artistName: "Fixture Artist",
                progressMS: 42_000,
                durationMS: 210_000,
                volumePercent: 54,
                shuffle: true,
                repeatState: .off,
                device: DJConnectPlaybackDevice(
                    id: output.id,
                    name: output.name,
                    type: output.type,
                    active: true,
                    supportsVolume: true,
                    volumePercent: output.volumePercent
                ),
                contextURI: "spotify:playlist:fixture",
                isLiked: false,
                favoriteStatus: false
            ),
            devices: [
                output,
                DJConnectOutputDevice(
                    id: "fixture-kitchen",
                    name: "Fixture Kitchen",
                    type: "speaker",
                    active: false,
                    supportsVolume: true,
                    volumePercent: 35
                )
            ],
            queue: [
                DJConnectQueueItem(
                    id: "fixture-queue-1",
                    title: "Fixture Track",
                    artist: "Fixture Artist",
                    album: "Fixture Album",
                    uri: "spotify:track:fixture-1",
                    durationMS: 210_000
                ),
                DJConnectQueueItem(
                    id: "fixture-queue-2",
                    title: "Fixture Next",
                    artist: "Fixture Artist Two",
                    album: "Fixture Album Two",
                    uri: "spotify:track:fixture-2",
                    durationMS: 190_000
                )
            ],
            queueContext: "spotify:playlist:fixture",
            playlists: [
                DJConnectPlaylist(
                    id: "fixture-playlist-1",
                    name: "Fixture Playlist",
                    uri: "spotify:playlist:fixture",
                    subtitle: "Home Assistant fixture"
                ),
                DJConnectPlaylist(
                    id: "fixture-playlist-2",
                    name: "Fixture Dinner",
                    uri: "spotify:playlist:fixture-dinner",
                    subtitle: "Recorded fixture"
                )
            ]
        )
    }
    #endif

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
                applyDemoVolume(volume, to: &updated)
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
                applyDemoOutput(name, to: &updated)
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

    private func applyDemoVolume(_ volume: Int, to playback: inout DJConnectPlayback) {
        playback.volumePercent = volume
        availableOutputs = availableOutputs.map { device in
            var device = device
            if device.active == true {
                device.volumePercent = volume
            }
            return device
        }
    }

    private func applyDemoOutput(_ name: String, to playback: inout DJConnectPlayback) {
        selectedOutput = availableOutputs.first { $0.id == name || $0.name == name }?.name ?? name
        availableOutputs = availableOutputs.map { device in
            var device = device
            device.active = device.name == name || device.id == name
            return device
        }
        playback.device = availableOutputs.first(where: { $0.active == true }).map {
            DJConnectPlaybackDevice(id: $0.id, name: $0.name, type: $0.type, active: true, supportsVolume: $0.supportsVolume, volumePercent: $0.volumePercent)
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
        case "play", "pause", "next", "previous", "start_playlist", "start_liked_proxy", "play_context_at", "set_current_track_favorite", "save_current_track":
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
            hybridTransport: sharedHybridTransport(),
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
            },
            historyContractVersion: sessionHistory.historyContractVersion
        )
    }

    private func logAPIFailure(_ details: DJConnectAPIFailureLogDetails) {
        log(
            .warning,
            "Home Assistant API failure route=\(details.route) http_status=\(details.httpStatus.map(String.init) ?? "none") ws_code=\(details.websocketCode ?? "none") error=\(details.serverError) message=\((details.serverMessage ?? "none").replacingOccurrences(of: "\n", with: "\\n")) identity_present=\(details.identityPresent) token_present=\(details.tokenPresent) client_type=\(details.clientType) client_id=\(details.redactedClientID)"
        )
    }

    private func webSocketFastPathIfLocal(_ baseURL: URL) -> (any DJConnectWebSocketFastPathTransport)? {
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
        let configuration = transportConfiguration(webSocketBaseURL: baseURL)
        guard let fastPath = webSocketFastPathFactory(baseURL, localURL, configuration) else {
            return nil
        }
        webSocketFastPathCache[key] = fastPath
        return fastPath
    }

    private func transportConfiguration(
        allowsRemoteHTTPFallback: Bool = true,
        webSocketBaseURL: URL? = nil
    ) -> DJConnectTransportConfiguration {
        DJConnectTransportConfiguration(
            webSocketFastPathEnabled: webSocketFastPathEnabled,
            homeAssistantWebSocketAuth: homeAssistantWebSocketAuth,
            allowsRemoteHTTPFallback: allowsRemoteHTTPFallback
        )
    }

    private func sharedHybridTransport() -> DJConnectHybridTransport? {
        guard !isDemoMode, pairingStatus == .paired,
              let install = defaults.string(forKey: haInstallIDKey), !install.isEmpty else { return nil }
        let remote = Self.normalizedHomeAssistantURL(from: haRemoteURL)
        let local = hasEvaluatedLocalNetwork && !isLocalNetworkAvailable && remote != nil
            ? nil : Self.normalizedHomeAssistantURL(from: localHomeAssistantURL())
        guard local.map({ DJConnectHybridTransport.trustedOrigin($0) || DJConnectHybridTransport.isLocalTransportCandidate($0) }) == true
            || remote.map(DJConnectHybridTransport.trustedOrigin) == true else { return nil }
        let key = [local?.absoluteString ?? "", remote?.absoluteString ?? "", install, identity.deviceID].joined(separator: "|")
        if hybridTransportKey == key, let hybridTransport { return hybridTransport }
        if let old = hybridTransport { Task { await old.lifecycle(foreground: false) } }
        let transport = DJConnectHybridTransport(localURL: local, remoteURL: remote, expectedInstallID: install,
            identity: identity, tokenStore: tokenStore, wire: DJConnectHybridURLWire(session: urlSession),
            report: { [weak self] snapshot in Task { @MainActor in
                guard let self, self.hybridTransportKey == key else { return }
                self.hybridConnectionDiagnostics = snapshot
                let previous = self.lastHybridRouteState
                self.lastHybridRouteState = snapshot.state
                if previous != snapshot.state {
                    self.invalidateActiveVoiceInventory()
                    if self.activeVoiceMenuOpen, [.localReady, .remoteReady].contains(snapshot.state) {
                        Task { await self.refreshActiveVoiceOptions() }
                    }
                }
                if previous != nil, previous != snapshot.state,
                   [.localReady, .remoteReady].contains(snapshot.state), self.sessionBroadcastTransport != nil {
                    self.stopSessionBroadcast(); self.startSessionBroadcastIfNeeded()
                }
                self.fastPathDiagnostics = DJConnectFastPathDiagnostics(fastPathTransport: snapshot.transportName ?? "offline",
                    websocketConnected: snapshot.websocketConnected, lastCapabilityRefresh: Date(),
                    websocketCommands: snapshot.websocketConnected ? ["djconnect/read", "djconnect/operation/execute", "djconnect/operation/status"] : [])
            } })
        hybridTransportKey = key; hybridTransport = transport
        return transport
    }

    private func updateFastPathDiagnostics(from client: DJConnectClient) async {
        if hybridTransport != nil { return }
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

    func withHomeAssistantClient<T: Sendable>(allowsOperationReplay: Bool = true, notifiesTransportFailure: Bool = true, _ operation: (DJConnectClient) async throws -> T) async throws -> T {
        let remoteURL = Self.normalizedHomeAssistantURL(from: haRemoteURL)
        let localURL = hasEvaluatedLocalNetwork && !isLocalNetworkAvailable && remoteURL != nil
            ? nil : (Self.normalizedHomeAssistantURL(from: localHomeAssistantURL())
                ?? Self.normalizedHomeAssistantURL(from: homeAssistantURL))
        guard localURL != nil || remoteURL != nil else {
            throw DJConnectError.network(message: localized(key: "appModel.enter.your.home.assistant.url.for.example.192.168"))
        }

        let localFastPath = localURL.flatMap { webSocketFastPathIfLocal($0) }
        let hybrid = sharedHybridTransport()
        let configuration = transportConfiguration(allowsRemoteHTTPFallback: identity.clientType != .watchos)
        let historyContractVersion = sessionHistory.historyContractVersion
        // After an actual LAN failure, remote reads must not wait for the same
        // local timeout every two seconds. Periodically probe LAN again so
        // returning home restores the preferred local connection automatically.
        let now = Date()
        let prefersRemote = haConnectionMode == .remote && (localTransportProbeAfter.map { $0 > now } ?? false)
        if haConnectionMode == .remote && !prefersRemote {
            localTransportProbeAfter = now.addingTimeInterval(15)
        }
        let transport = DJConnectHATransportManager(
            localURL: localURL,
            remoteURL: remoteURL,
            allowsRemoteFallback: configuration.allowsRemoteHTTPFallback,
            prefersRemote: prefersRemote,
            clientFactory: { [weak self, identity, tokenStore, urlSession, localURL, localFastPath, hybrid] baseURL in
                let fastPath = DJConnectFastPathPolicy.isEligible(baseURL: baseURL, localURL: localURL) ? localFastPath : nil
                return DJConnectClient(
                    baseURL: baseURL,
                    identity: identity,
                    tokenStore: tokenStore,
                    session: urlSession,
                    hybridTransport: hybrid,
                    webSocketFastPath: fastPath,
                    failureLogger: { details in
                        Task { @MainActor in
                            self?.logAPIFailure(details)
                        }
                    },
                    historyContractVersion: historyContractVersion
                )
            },
            modeReporter: { [weak self] mode, baseURL in
                Task { @MainActor in
                    self?.recordConnectionMode(mode, baseURL: baseURL)
                }
            }
        )
        do {
        return try await transport.perform(allowsOperationReplay: allowsOperationReplay) { client in
            do {
                let result = try await operation(client)
                await updateFastPathDiagnostics(from: client)
                return result
            } catch {
                await updateFastPathDiagnostics(from: client)
                throw error
            }
        }
        } catch let outcome as DJConnectHybridTransportError {
            if notifiesTransportFailure { userNotice = DJConnectUserNotice(text: localized(key: outcome.localizationKey)) }
            throw outcome
        }
    }

    func recordConnectionMode(_ mode: DJConnectHAConnectionMode, baseURL: URL?) {
        if mode == .local { localTransportProbeAfter = nil }
        else if mode == .remote && localTransportProbeAfter == nil {
            localTransportProbeAfter = Date().addingTimeInterval(15)
        }
        haConnectionMode = mode
        // The reporter may arrive after playback was applied. Rebind only the
        // public proxy URL now, so a working external status never leaves the
        // cover retrying the unavailable local address until another track.
        if var current = playback, let resolved = resolvedArtworkURL(current.albumImageURL), resolved != current.albumImageURL {
            current.albumImageURL = resolved; playback = current
        }
        defaults.set(mode.rawValue, forKey: haConnectionModeKey)
        if mode == .local, let baseURL,
           Self.normalizedHomeAssistantURL(from: localHomeAssistantURL()) == baseURL {
            // A late reporter from the old route must not undo a status update.
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
                self.localTransportProbeAfter = nil
                if isDeviceNetwork, self.isAppInForeground, self.pairingStatus == .paired, !self.isDemoMode {
                    self.schedulePairedRefresh(reason: "Network change status refresh completed", allowThrottle: false,
                                               refreshCollections: false, runFollowUpRefresh: false)
                }
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
            startPendingWatchProxyPairingIfPossible()
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
        let protocolVersion = message["protocol_version"] as? String ?? firmware
        let identity = DJConnectIdentity(
            deviceID: deviceID,
            deviceName: message["device_name"] as? String ?? "DJConnect Watch",
            clientType: .watchos,
            firmware: firmware,
            appVersion: appVersion,
            protocolVersion: protocolVersion,
            platform: .watchos
        )
        watchProxyRegistration = DJConnectWatchProxyRegistration(
            identity: identity,
            pairCode: pairCode,
            paired: (message["paired"] as? Bool) ?? defaults.bool(forKey: watchProxyPairedKey)
        )
        persistWatchProxyRegistration()
        sendWatchProxyReady()
        startPendingWatchProxyPairingIfPossible()
        log(.info, "Watch proxy registered \(Self.redactedDJConnectDeviceID(deviceID))")
    }

    private func restoreWatchProxyRegistration() {
        guard let deviceID = defaults.string(forKey: watchProxyDeviceIDKey), !deviceID.isEmpty,
              let pairCode = defaults.string(forKey: watchProxyPairCodeKey), !pairCode.isEmpty else {
            return
        }
        let firmware = defaults.string(forKey: watchProxyFirmwareKey) ?? appVersion
        let protocolVersion = defaults.string(forKey: watchProxyProtocolVersionKey) ?? firmware
        watchProxyRegistration = DJConnectWatchProxyRegistration(
            identity: DJConnectIdentity(
                deviceID: deviceID,
                deviceName: defaults.string(forKey: watchProxyDeviceNameKey) ?? "DJConnect Watch",
                clientType: .watchos,
                firmware: firmware,
                appVersion: defaults.string(forKey: watchProxyAppVersionKey) ?? firmware,
                protocolVersion: protocolVersion,
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
        defaults.set(registration.identity.protocolVersion, forKey: watchProxyProtocolVersionKey)
        defaults.set(registration.pairCode, forKey: watchProxyPairCodeKey)
        defaults.set(registration.paired, forKey: watchProxyPairedKey)
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
                assistPipelineID: assistPipelineID.isEmpty ? nil : assistPipelineID
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
                    mood: confirmedSessionMoodInt,
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
        guard let requestData = message["request"] as? Data, requestData.count < 42_000,
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
            let encoded = try await withWatchProxyHomeAssistantClient(identity: registration.identity, token: token,
                allowsOperationReplay: request.operation != .updateProfileDJSettings && request.operation != .prepareSessionSpeech) { client in
                try await self.performWatchProxyOperation(request, client: client)
            }
            guard encoded.count < 42_000 else { throw DJConnectError.payloadTooLarge(limitBytes: 42_000, actualBytes: encoded.count) }
            return DJConnectWatchProxyResponse(success: true, payload: encoded)
        } catch let rejection as DJConnectProfileDJSettingsFailure {
            return DJConnectWatchProxyResponse(success: false, payload: try? JSONEncoder().encode(rejection), error: "settings_rejected")
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
        case .prepareSessionSpeech:
            let intent = try decoder.decode(DJConnectWatchMomentSpeechRequest.self, from: request.payload ?? Data())
            let before = try await client.profileDJSettings()
            let runtime = try await client.activeSession()
            let source = DJConnectWatchSessionSnapshot(settings: before, session: runtime.resolvedSession)
            guard runtime.success, intent.matches(source) else { throw DJConnectError.invalidResponse }
            let prepared = try await client.prepareSharedDJSpeech(reference: intent.reference,
                acceptedText: intent.moment.content, settings: before, processor: .localOnDevice)
            // Re-read both owners before crossing the companion boundary. Reads
            // cannot refresh the original speech grant or manufacture publication.
            let after = try await client.profileDJSettings()
            let latest = try await client.activeSession()
            guard latest.success, intent.matches(.init(settings: after, session: latest.resolvedSession)),
                  intent.source.matches(prepared.session_speech),
                  DJConnectNativeSpeechAdmission.admits(prepared.session_speech, reference: intent.reference,
                    text: intent.moment.content, settings: after) else { throw DJConnectError.invalidResponse }
            return try encoder.encode(prepared)
        case .foregroundSession:
            // Read with the Watch bearer, and fence Profile/Session changes
            // across the two independent frozen owner contracts.
            let before = try await client.profileDJSettings()
            let runtime = try await client.activeSession()
            let after = try await client.profileDJSettings()
            guard before.binding == after.binding, before.snapshot == after.snapshot,
                  runtime.success else { throw DJConnectError.invalidResponse }
            let value = DJConnectWatchSessionSnapshot(settings: after, session: runtime.resolvedSession)
            guard value.isValid else { throw DJConnectError.invalidResponse }
            return try encoder.encode(value)
        case .profileDJSettings:
            return try encoder.encode(try await client.profileDJSettings())
        case .updateProfileDJSettings:
            let payload = try decoder.decode(DJConnectWatchSettingsUpdate.self, from: request.payload ?? Data())
            return try encoder.encode(try await client.updateProfileDJSettings(payload.current, patch: payload.patch, operationID: payload.operationID))
        case .profileDJSettingsOperation:
            let payload = try decoder.decode(DJConnectWatchSettingsReceipt.self, from: request.payload ?? Data())
            return try encoder.encode(try await client.profileDJSettingsOperation(binding: payload.binding, operationID: payload.operationID))
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
            var payload = try decoder.decode(DJConnectAskDJRequest.self, from: request.payload ?? Data())
            payload.audioResponse = .never // legacy Watch text has no negotiated deferred speech grant
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
        case .musicDiscovery:
            let payload = request.payload.flatMap {
                try? decoder.decode(DJConnectMusicDNAIdentityRequest.self, from: $0)
            }
            let response = try await client.musicDiscoveryFeed(
                musicDNAKey: payload?.musicDNAKey,
                language: payload?.language
            )
            return try encoder.encode(response)
        case .musicDiscoveryRefresh:
            let payload = request.payload.flatMap {
                try? decoder.decode(DJConnectMusicDNAIdentityRequest.self, from: $0)
            }
            let response = try await client.refreshMusicDiscovery(
                musicDNAKey: payload?.musicDNAKey,
                language: payload?.language
            )
            return try encoder.encode(response)
        case .musicDiscoveryPlay:
            let payload = try decoder.decode(DJConnectMusicDiscoveryPlayRequest.self, from: request.payload ?? Data())
            let response = try await client.playMusicDiscoveryItem(payload)
            return try encoder.encode(response)
        case .voice:
            let payload = try decoder.decode(DJConnectWatchProxyVoicePayload.self, from: request.payload ?? Data())
            // Interactive Watch work has its own bearer/lifecycle. The phone
            // foreground/Profile context must not gate or receive its discovery.
            let locale = payload.language ?? currentRequestLocale
            let watchID = watchProxyRegistration?.identity.deviceID
            let watchToken = defaults.string(forKey: watchProxyDeviceTokenKey)
            let install = defaults.string(forKey: haInstallIDKey) ?? ""
            guard client.identity.clientType == .watchos, client.identity.deviceID == watchID,
                  watchToken?.isEmpty == false, try client.tokenStore.loadToken() == watchToken else { throw CancellationError() }
            let availability = try await client.currentDeviceSpeech(language: locale, expectedInstallationID: install)
            guard !Task.isCancelled, watchProxyRegistration?.identity.deviceID == watchID,
                  defaults.string(forKey: watchProxyDeviceTokenKey) == watchToken,
                  defaults.string(forKey: haInstallIDKey) == install,
                  availability?.allowsHAInput(locale: locale) == true else { throw DJConnectError.invalidResponse }
            let response = try await client.sendVoice(
                wavData: payload.wavData,
                mood: payload.mood,
                djStyle: payload.djStyle,
                musicDNAKey: payload.musicDNAKey,
                language: locale
            )
            return try encoder.encode(response)
        case .pushRegister:
            let payload = try decoder.decode(DJConnectPushRegistrationRequest.self, from: request.payload ?? Data())
            return try await performWatchProxyPushRegistration(payload, client: client)
        case .pushUnregister:
            let payload = try decoder.decode(DJConnectPushUnregistrationRequest.self, from: request.payload ?? Data())
            let response = try await client.unregisterPushNotifications(payload)
            return try encoder.encode(response)
        }
    }

    private func performWatchProxyPushRegistration(
        _ payload: DJConnectPushRegistrationRequest,
        client: DJConnectClient
    ) async throws -> Data {
        let encoder = JSONEncoder()
        let epoch = sessionHistory.responseEpoch
        let route = localHomeAssistantURL()
        let isStillCurrent = { !Task.isCancelled && self.pairingStatus == .paired
            && self.sessionHistory.responseEpoch == epoch && self.localHomeAssistantURL() == route }
        let response = try await client.registerPushNotifications(payload)
        guard isStillCurrent() else { throw CancellationError() }
        let responseEnvironment = response.pushEnvironment
        let environmentMatches = payload.pushEnvironment.isCompatible(with: responseEnvironment)
        guard !response.success || response.pushRegistered == false || !environmentMatches else {
            return try encoder.encode(response)
        }
        let reason = response.error ?? response.lastPushError ?? response.message ?? "unknown"
        guard Self.isMissingBootstrapProof(reason), payload.bootstrapProof?.isEmpty != false else {
            return try encoder.encode(response)
        }
        let watchIdentity = DJConnectIdentity(
            deviceID: payload.deviceID,
            deviceName: "DJConnect Watch",
            clientType: payload.clientType,
            firmware: DJConnectProtocolVersion.current,
            appVersion: payload.appVersion,
            protocolVersion: DJConnectProtocolVersion.current,
            platform: .watchos
        )
        guard let bootstrapProof = try await fetchBootstrapProofForPushRegistration(
            identity: watchIdentity,
            pushEnvironment: payload.pushEnvironment,
            appBundleID: payload.appBundleID,
            isStillCurrent: isStillCurrent
        ) else {
            return try encoder.encode(DJConnectCommandResponse(
                success: false,
                error: "bootstrap_proof_unavailable",
                message: "Watch push bootstrap proof unavailable.",
                pushSupported: response.pushSupported,
                pushRegistered: false,
                pushEnvironment: response.pushEnvironment,
                lastPushError: "bootstrap_proof_unavailable"
            ))
        }
        var retryPayload = payload
        retryPayload.bootstrapProof = bootstrapProof
        logPush("watch_proxy registration retry_with_bootstrap_proof=true device_id_present=\(!payload.deviceID.isEmpty) client_type=\(payload.clientType.rawValue) env=\(payload.pushEnvironment.rawValue)")
        let retryResponse = try await client.registerPushNotifications(retryPayload)
        guard isStillCurrent() else { throw CancellationError() }
        return try encoder.encode(retryResponse)
    }

    private func withWatchProxyHomeAssistantClient<T: Sendable>(
        identity: DJConnectIdentity,
        token: String,
        allowsOperationReplay: Bool = true,
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
            prefersRemote: haConnectionMode == .remote,
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
                    // This route belongs to the Watch bearer. It must not
                    // overwrite the iPhone owner connection state.
                    self?.sendWatchProxyReady()
                }
            }
        )
        return try await transport.perform(allowsOperationReplay: allowsOperationReplay, operation)
    }

    private func sendWatchProxyHAResponse(_ response: DJConnectWatchProxyResponse, correlationID: String?) {
        // HA responses can contain owner-only content. Never put them in the
        // durable application context or transferUserInfo background queue.
        guard let correlationID, WCSession.default.isReachable,
              let data = try? JSONEncoder().encode(response), data.count <= 60_000 else { return }
        WCSession.default.sendMessage([
            "type": "watch_proxy_ha_response", "correlation_id": correlationID, "response": data
        ], replyHandler: nil, errorHandler: { _ in })
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
        case .payloadTooLarge:
            return "payload_too_large"
        case .profile:
            return "profile_error"
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
        defaults.removeObject(forKey: haInstallIDKey)
        defaults.removeObject(forKey: integrationVersionKey)
        defaults.removeObject(forKey: pairingSessionIDKey)
    }

    public func clearDiagnosticLog() {
        diagnosticLogLines.removeAll()
        deletePersistentDiagnosticLog()
        log(.info, "Diagnostic log cleared")
    }

    /// Called only after the user confirms disabling and deleting app logs.
    public func disableDiagnosticLoggingAndClear() throws {
        if let diagnosticLogFileURL,
           FileManager.default.fileExists(atPath: diagnosticLogFileURL.path) {
            try FileManager.default.removeItem(at: diagnosticLogFileURL)
        }
        logLevel = "off"
        diagnosticLogLines.removeAll()
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
        release_version: \(appVersion)
        build_version: \(buildVersion)
        protocol_version: \(Self.protocolVersion)
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
        active_session_present: \(activeDJSession != nil)
        session_live_unavailable: \(djSessionLiveUnavailable)
        session_recovering: \(djSessionIsRecovering)
        session_history_available: \(sessionHistory.available)
        profile_conversation_scope: \(sessionHistory.profileScopeActive)
        profile_conversation_authorized: \(sessionHistory.hasAuthorizedOwner)
        selected_output: \(selectedOutput)
        language: \(language)
        log_level: \(logLevel)
        microphone_permission: \(microphonePermissionStatus.rawValue)
        speech_permission: \(speechPermissionStatus.rawValue)
        notification_permission: \(notificationPermissionStatus.rawValue)
        local_network_permission: \(localNetworkPermissionStatus.rawValue)
        voice_enabled: \(voiceEnabled)
        voice_recording: \(isRecordingVoice)
        voice_status: \(voiceStatus)
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

    /// Local, bounded presentation metadata; never captures view text or account data.
    func recordPresentationState(_ event: String) {
        #if DEBUG && canImport(UIKit)
        guard isDiagnosticLoggingEnabled else { return }
        var rows: [String] = []
        var seen = Set<ObjectIdentifier>()
        func visit(_ controller: UIViewController) {
            guard rows.count < 24, seen.insert(ObjectIdentifier(controller)).inserted else { return }
            let name = String(describing: type(of: controller)).split(separator: "<", maxSplits: 1).first.map(String.init) ?? "UIViewController"
            rows.append("\(name):presenting=\(controller.isBeingPresented),dismissing=\(controller.isBeingDismissed),visible=\(controller.viewIfLoaded?.window != nil)")
            if let presented = controller.presentedViewController { visit(presented) }
            for child in controller.children { visit(child) }
        }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) where scene.activationState == .foregroundActive {
            for window in scene.windows where !window.isHidden {
                if let root = window.rootViewController { visit(root) }
            }
        }
        // Do not publish diagnosticLogLines here: observing presentation must not
        // cause another SwiftUI update while UIKit is presenting/dismissing.
        let message = "Presentation \(event) " + rows.joined(separator: " | ")
        logger.info("\(message, privacy: .public)")
        appendPersistentDiagnosticLogLine(message)
        #endif
    }

    private func log(_ level: DJConnectAppLogLevel, _ message: String) {
        let configuredLevel = DJConnectAppLogLevel.parse(logLevel)
        guard configuredLevel != .off, level != .off, level.priority >= configuredLevel.priority else {
            return
        }
        let message = DJConnectLogRedactor.redactText(message)

        switch level {
        case .off:
            return
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
        diagnosticLogLines.insert(DJConnectDiagnosticLogLine(text: line), at: 0)
        if diagnosticLogLines.count > maxDiagnosticLogLines {
            diagnosticLogLines.removeLast(diagnosticLogLines.count - maxDiagnosticLogLines)
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
        diagnosticLogLines = lines.reversed().map { DJConnectDiagnosticLogLine(text: $0) }
    }

    private func appendPersistentDiagnosticLogLine(_ line: String) {
        guard isDiagnosticLoggingEnabled, let diagnosticLogFileURL else {
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
        case .off:
            "OFF"
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
        case .payloadTooLarge:
            return "Home Assistant gaf te veel data terug."
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
        case let .profile(_, _, message):
            return message ?? "Profielinstellingen ontbreken in Home Assistant."
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
        case let .payloadTooLarge(limitBytes, actualBytes):
            "payload too large limit=\(limitBytes) actual=\(actualBytes.map(String.init) ?? "unknown")"
        case let .profile(code, statusCode, message):
            "profile \(code.rawValue) HTTP \(statusCode)\(message.map { ": \($0)" } ?? "")"
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
        case .payloadTooLarge:
            return "payload_too_large"
        case let .profile(code, _, _):
            return code.rawValue
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
            case let .profile(_, _, value):
                message = value
            case let .invalidConfiguration(value):
                message = value
            case .versionMismatch:
                message = "version_mismatch"
            case .invalidResponse:
                message = "invalid_response"
            case .missingToken:
                message = "missing_token"
            case let .payloadTooLarge(limitBytes, actualBytes):
                message = "payload_too_large limit=\(limitBytes) actual=\(actualBytes.map(String.init) ?? "unknown")"
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
        microphonePermissionStatus = permissionCoordinator.currentMicrophonePermissionStatus()
        speechPermissionStatus = permissionCoordinator.currentSpeechPermissionStatus()
        localNetworkPermissionStatus = .unknown
        log(.debug, "Permission status refreshed: microphone=\(microphonePermissionStatus.rawValue) speech=\(speechPermissionStatus.rawValue) notifications=\(notificationPermissionStatus.rawValue) local_network=\(localNetworkPermissionStatus.rawValue)")
        if retryWakeWord, wakeWordEnabled, wakeWordStatus == .unavailable, microphonePermissionStatus == .granted, speechPermissionStatus == .granted {
            log(.info, "Retrying wakeword listening after permission status refresh")
            resumeWakeWordListeningIfNeeded()
        }
        Task { @MainActor in
            notificationPermissionStatus = await permissionCoordinator.currentNotificationPermissionStatus()
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
            && !personaReactionOutputReserved
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
        if case .voiceRecording = pendingPermissionRequest { sessionHistory.cancelVoiceContext() }
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
            notificationGranted = await requestRemoteNotificationAuthorizationIfNeeded(
                center: UNUserNotificationCenter.current(),
                allowSystemPrompt: true
            )
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
        DJConnectPermissionCoordinator.requestAction(
            microphone: microphone,
            speech: speech,
            notifications: notifications
        )
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

    private func requestMicrophoneAccess() async -> Bool {
        #if canImport(AVFoundation)
        switch permissionCoordinator.currentMicrophonePermissionStatus() {
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

    private func startWakeWordListening() {
        // A reaction can hand focus to another speech owner. Restore only the
        // wake listener it interrupted, after that owner's output has ended.
        if personaReactionInterruptedWake && (sharedSpeechIsPreparing || sharedSpeechIsPlaying || deviceSpeechPreviewIsPlaying) { return }
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
        personaReactionInterruptedWake = false
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
            if permissionCoordinator.currentMicrophonePermissionStatus() == .granted {
                microphoneGranted = true
            } else {
                microphoneGranted = await requestMicrophoneAccess()
            }
            let speechGranted: Bool
            if permissionCoordinator.currentSpeechPermissionStatus() == .granted {
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
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable,
              !deviceSTTEnabled || recognizer.supportsOnDeviceRecognition else {
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
            request.requiresOnDeviceRecognition = deviceSTTEnabled
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
            guard recorder.prepareToRecord(), recorder.record(), recorder.isRecording else {
                try? FileManager.default.removeItem(at: url)
                throw DJConnectError.invalidResponse
            }
            voiceRecorder = recorder
            voiceRecordingURL = url
            voiceErrorMessage = nil
            isRecordingVoice = true
            voiceStatus = .listening
            log(.info, "Voice recording started")
        } catch {
            isRecordingVoice = false
            sessionHistory.cancelVoiceContext()
            dismissWakeWordListeningMessage()
            voiceStatus = .unavailable
            voiceErrorMessage = localized(key: "ui.session.history.voice_failed")
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
        let code = language.lowercased().split(separator: "-", maxSplits: 1).first.map(String.init) ?? language.lowercased()
        switch code {
        case "nl", "de", "fr", "es":
            return code
        default:
            return "en"
        }
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
        let installID: String
        if let existing = defaults.string(forKey: installIDKey), !existing.isEmpty {
            installID = existing
        } else if let legacy = defaults.string(forKey: legacyInstallIDKey), !legacy.isEmpty {
            installID = legacy
            defaults.set(legacy, forKey: installIDKey)
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
            appVersion: DJConnectApplicationVersion.releaseVersion,
            protocolVersion: protocolVersion,
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
            appVersion: DJConnectApplicationVersion.releaseVersion,
            protocolVersion: protocolVersion,
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

/// Reuse only an exact, current same-Profile identity; names never grant artwork.
func currentMusicDNAArtworkReference(discovery: DJConnectMusicDiscoveryResponse?, profileID: String?,
                                     uri: String?, artist: Bool, at date: Date = Date()) -> String? {
    guard let discovery, discovery.success, let profileID, !profileID.isEmpty,
          discovery.profileID == profileID, let uri, !uri.isEmpty else { return nil }
    let references = Set(discovery.visibleSections.flatMap(\.visibleItems).filter {
        $0.uri == uri && $0.kind == (artist ? .artist : .track)
            && ($0.imageExpiresAt.map { $0 > date } ?? true)
    }.compactMap { $0.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    return references.count == 1 ? references.first : nil
}

func conversationPresentationDeadline(_ response: DJConnectAskDJMessageResponse, now: Date = Date()) -> Date? {
    guard let result = response.resultSet else { return nil }
    guard result.schemaVersion == 1, !result.resultSetID.isEmpty, result.resultSetID.count <= 256,
          result.expiresIn.isFinite, result.expiresIn > 0, result.expiresIn <= 600 else { return .distantPast }
    return min(response.serverTime ?? now, now).addingTimeInterval(result.expiresIn)
}
