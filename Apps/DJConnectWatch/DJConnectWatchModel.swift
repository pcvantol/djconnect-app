import AVFoundation
import DJConnectCore
import SwiftUI
import UserNotifications
import WatchKit

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
        case audioURL
        case messageKind = "message_kind"
        case origin
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
    var audioURL: URL?
    var messageKind: DJConnectAskDJMessageKind
    var origin: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        serverID: String? = nil,
        clientMessageID: String? = nil,
        role: Role,
        text: String,
        images: [DJConnectResponseImage] = [],
        links: [DJConnectResponseLink] = [],
        playbackActions: [DJConnectAskDJPlaybackAction] = [],
        audioURL: URL? = nil,
        messageKind: DJConnectAskDJMessageKind = .assistant,
        origin: String? = nil,
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
        self.audioURL = audioURL
        self.messageKind = messageKind
        self.origin = origin
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
        audioURL = try container.decodeIfPresent(URL.self, forKey: .audioURL)
        messageKind = try container.decodeIfPresent(DJConnectAskDJMessageKind.self, forKey: .messageKind) ?? .assistant
        origin = try container.decodeIfPresent(String.self, forKey: .origin)
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
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encode(messageKind, forKey: .messageKind)
        try container.encodeIfPresent(origin, forKey: .origin)
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

    var title: String {
        switch self {
        case .debug:
            return "Debug"
        case .info:
            return "Info"
        case .warning:
            return "Waarschuwingen"
        case .error:
            return "Fouten"
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

@MainActor
final class DJConnectWatchModel: NSObject, ObservableObject {
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

    @AppStorage("haBaseURL") var haBaseURL = "http://homeassistant.local:8123"
    @AppStorage("pairingCode") var pairingCode = DJConnectWatchModel.makePairingCode()
    @AppStorage("stableInstallID") private var stableInstallID = DJConnectWatchModel.makeStableInstallID()
    @AppStorage("paired") private var paired = false
    @AppStorage("demoMode") private var storedDemoMode = false
    @AppStorage("askDJMood") var askDJMood = 50.0
    @AppStorage("watchLogLevel") var watchLogLevel = DJConnectWatchLogLevel.info.rawValue
    @AppStorage("askDJHistoryRevision") private var askDJHistoryRevision = 0
    @AppStorage("askDJClearRevision") private var askDJClearRevision = 0

    @Published private(set) var connectionState: ConnectionState = .unpaired
    @Published private(set) var voiceState: VoiceState = .idle
    @Published private(set) var playback: DJConnectPlayback?
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
    @Published private(set) var askDJScrollRequestID: UUID?
    @Published private(set) var isCheckingAskDJHistoryState = true
    @Published private(set) var isClearingAskDJHistory = false
    @Published private(set) var isRequestingAskDJIdleSuggestion = false
    @Published private(set) var playingAskDJActionID: String?
    @Published private(set) var askDJToast: DJConnectWatchToast?
    @Published private(set) var askDJAudioPlaybackState: DJConnectWatchAudioPlaybackState = .idle
    @Published private(set) var isShowingPairingSuccess = false
    @Published private(set) var isDemoMode = false
    @Published private(set) var diagnosticLogLines: [DJConnectWatchLogLine] = []
    @Published var statusMessage = "Niet gekoppeld"

    private let askDJMessagesKey = "DJConnectWatchAskDJMessages"
    private let maxDiagnosticLogLines = 80
    private let tokenStore = DJConnectUserDefaultsTokenStore(key: "DJConnectWatchDeviceToken")
    private let monkeyTestingMode: Bool
    private var localDeviceAPI: DJConnectLocalDeviceAPI?
    private var localDeviceAPIURL: String?
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var player: AVAudioPlayer?
    private var audioPlaybackTask: Task<Void, Never>?
    private var speechSynthesizer: AVSpeechSynthesizer?
    private let askDJHistorySyncInterval: UInt64 = 20_000_000_000
    private var hasRequestedAskDJIdleSuggestion = false
    private var volumeCommandTask: Task<Void, Never>?
    private var playbackBeatSignature: String?
    private var hasRequestedAskDJNotificationPermission = false

    init(monkeyTestingMode: Bool = false) {
        self.monkeyTestingMode = monkeyTestingMode
        super.init()
        askDJMessages = Self.loadAskDJMessages(key: askDJMessagesKey)
        if monkeyTestingMode {
            storedDemoMode = false
            isDemoMode = true
            applyDemoState()
            appendDiagnosticLog("Watch gestart in monkey test demo modus")
        } else if storedDemoMode {
            isDemoMode = true
            applyDemoState()
            appendDiagnosticLog("Watch gestart in demo modus")
        } else {
            connectionState = paired ? .paired : .unpaired
            statusMessage = paired ? "Gereed" : "Niet gekoppeld"
            startLocalDeviceAPI()
            appendDiagnosticLog(paired ? "Watch gestart met bestaande koppeling" : "Watch gestart zonder koppeling")
        }
    }

    deinit {
        localDeviceAPI?.stop()
    }

    func clearDiagnosticLog() {
        diagnosticLogLines.removeAll()
        appendDiagnosticLog("Logs gewist")
    }

    func setWatchLogLevel(_ level: DJConnectWatchLogLevel) {
        watchLogLevel = level.rawValue
        appendDiagnosticLog("Logniveau ingesteld: \(level.title)", level: .info)
    }

    private func appendDiagnosticLog(_ message: String, level: DJConnectWatchLogLevel = .info) {
        let configuredLevel = DJConnectWatchLogLevel(rawValue: watchLogLevel) ?? .info
        guard level.priority >= configuredLevel.priority else {
            return
        }
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        diagnosticLogLines.append(DJConnectWatchLogLine(text: "\(timestamp) \(message)"))
        if diagnosticLogLines.count > maxDiagnosticLogLines {
            diagnosticLogLines.removeFirst(diagnosticLogLines.count - maxDiagnosticLogLines)
        }
    }

    var identity: DJConnectIdentity {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        return DJConnectIdentity(
            deviceID: "djconnect-watchos-\(stableInstallID)",
            deviceName: WKInterfaceDevice.current().name,
            clientType: .watchos,
            firmware: version,
            appVersion: version,
            platform: .watchos
        )
    }

    var canUseBackend: Bool {
        guard !isDemoMode else {
            return false
        }
        if case .paired = connectionState {
            return true
        }
        return false
    }

    var volume: Double {
        get { Double(playback?.volumePercent ?? playback?.device?.volumePercent ?? 0) }
        set {
            let value = max(0, min(60, Int(newValue.rounded())))
            if playback == nil {
                playback = DJConnectPlayback()
            }
            playback?.volumePercent = value
            playback?.device?.volumePercent = value
        }
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
        askDJMood = Double(askDJMoodSteps[clampedIndex].value)
    }

    var djStyle: String {
        "warm_radio_dj"
    }

    var memoryKey: String {
        identity.deviceID
    }

    private var hasActiveNowPlaying: Bool {
        playback?.hasPlayback == true
            || playback?.isPlaying == true
            || playback?.trackName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func pair() async {
        guard !paired else {
            connectionState = .paired
            return
        }
        connectionState = .pairing
        isShowingPairingSuccess = false
        statusMessage = "Wachten op Home Assistant..."
        localDeviceAPI?.setBonjourAdvertisingEnabled(true)
    }

    func dismissPairingSuccess() {
        isShowingPairingSuccess = false
        statusMessage = "Gereed"
    }

    func startDemoMode() {
        appendDiagnosticLog("Demo modus starten")
        localDeviceAPI?.stop()
        localDeviceAPI = nil
        storedDemoMode = true
        isDemoMode = true
        paired = false
        isShowingPairingSuccess = false
        voiceState = .idle
        applyDemoState()
    }

    func stopDemoMode() {
        appendDiagnosticLog("Demo modus stoppen")
        storedDemoMode = false
        isDemoMode = false
        playback = nil
        playbackBeatSignature = nil
        responseImages = []
        voiceState = .idle
        connectionState = paired ? .paired : .unpaired
        statusMessage = paired ? "Gereed" : "Demo modus gestopt"
        if !paired {
            startLocalDeviceAPI()
        }
    }

    func refreshStatus(confirmAskDJBeat: Bool = false) async {
        guard !isDemoMode else {
            applyDemoState()
            appendDiagnosticLog("Demo status bijgewerkt")
            return
        }
        guard let client, canUseBackend else {
            appendDiagnosticLog("Status vernieuwen overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        appendDiagnosticLog("Status vernieuwen")
        do {
            let response = try await client.postStatus(statusPayload(screenState: "now_playing"))
            applyPlayback(response.data ?? response.playback, confirmAskDJBeat: confirmAskDJBeat)
            statusMessage = "Bijgewerkt"
            appendDiagnosticLog("Status vernieuwd")
        } catch {
            statusMessage = Self.userMessage(for: error)
            appendDiagnosticLog("Status vernieuwen mislukt: \(statusMessage)", level: .error)
        }
    }

    func sendCommand(_ command: String) async {
        if isDemoMode {
            applyDemoCommand(command, value: nil)
            appendDiagnosticLog("Demo opdracht: \(command)")
            return
        }
        guard let client, canUseBackend else {
            appendDiagnosticLog("Opdracht \(command) overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        appendDiagnosticLog("Opdracht verzenden: \(command)")
        do {
            let response = try await client.sendCommand(
                DJConnectCommandPayload(identity: identity, command: command)
            )
            applyPlayback(response.data ?? response.playback)
            statusMessage = "Verzonden"
            appendDiagnosticLog("Opdracht gelukt: \(command)")
        } catch {
            statusMessage = Self.userMessage(for: error)
            appendDiagnosticLog("Opdracht mislukt: \(command) - \(statusMessage)", level: .error)
        }
    }

    func commitVolume() {
        let value = max(0, min(60, Int(volume.rounded())))
        volumeCommandTask?.cancel()
        volumeCommandTask = Task { [weak self] in
            await self?.sendVolume(value)
        }
    }

    private func sendVolume(_ value: Int) async {
        if isDemoMode {
            await MainActor.run {
                self.volume = Double(value)
                self.statusMessage = "Volume \(value)%"
                self.appendDiagnosticLog("Demo volume ingesteld: \(value)%")
            }
            return
        }
        guard let client, canUseBackend else {
            appendDiagnosticLog("Volume instellen overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        appendDiagnosticLog("Volume instellen: \(value)%")
        do {
            let response = try await client.sendCommand(
                DJConnectCommandPayload(identity: identity, command: "set_volume", value: .int(value))
            )
            applyPlayback(response.data ?? response.playback)
            if playback?.volumePercent == nil {
                playback?.volumePercent = value
            }
            statusMessage = "Volume \(value)%"
            appendDiagnosticLog("Volume ingesteld: \(value)%")
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
        guard let client, canUseBackend else {
            appendDiagnosticLog("Afspeellijsten laden overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        appendDiagnosticLog("Afspeellijsten laden")
        isLoadingPlaylists = true
        defer { isLoadingPlaylists = false }
        do {
            let response = try await client.sendCommandResponse(
                DJConnectCommandPayload(identity: identity, command: "playlists", limit: 100)
            )
            playlistItems = response.playlists ?? []
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
        guard let client, canUseBackend else {
            appendDiagnosticLog("Wachtrij laden overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        appendDiagnosticLog("Wachtrij laden")
        isLoadingQueue = true
        defer { isLoadingQueue = false }
        do {
            let response = try await client.sendCommandResponse(
                DJConnectCommandPayload(identity: identity, command: "queue", limit: 100)
            )
            queueItems = response.queue ?? []
            queueContext = response.queueContext
            statusMessage = queueItems.isEmpty ? "Geen wachtrij" : "Wachtrij bijgewerkt"
            appendDiagnosticLog("Wachtrij bijgewerkt: \(queueItems.count) items")
        } catch {
            statusMessage = Self.userMessage(for: error)
            appendDiagnosticLog("Wachtrij laden mislukt: \(statusMessage)", level: .error)
        }
    }

    func loadOutputs() async {
        if isDemoMode {
            applyDemoOutputs()
            appendDiagnosticLog("Demo uitvoerapparaten geladen")
            return
        }
        guard let client, canUseBackend else {
            appendDiagnosticLog("Uitvoerapparaten laden overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        appendDiagnosticLog("Uitvoerapparaten laden")
        isLoadingOutputs = true
        defer { isLoadingOutputs = false }
        do {
            let response = try await client.sendCommandResponse(
                DJConnectCommandPayload(identity: identity, command: "devices")
            )
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
        availableOutputs = availableOutputs.map { candidate in
            var updated = candidate
            updated.active = candidate.id == output.id || candidate.name == output.name
            return updated
        }
        if Self.isSyntheticOutput(output) {
            return
        }
        if isDemoMode {
            loadingOutputID = output.id
            applyDemoCommand("set_output", value: .string(output.name))
            loadingOutputID = nil
            appendDiagnosticLog("Demo uitvoer ingesteld: \(output.name)")
            return
        }
        guard let client, canUseBackend else {
            appendDiagnosticLog("Uitvoer instellen overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        loadingOutputID = output.id
        defer { loadingOutputID = nil }
        do {
            let response = try await client.sendCommand(
                DJConnectCommandPayload(
                    identity: identity,
                    command: "set_output",
                    value: .string(output.name),
                    play: true
                )
            )
            applyPlayback(response.data ?? response.playback)
            statusMessage = "Uitvoer ingesteld"
            appendDiagnosticLog("Uitvoer ingesteld: \(output.name)")
        } catch {
            statusMessage = Self.userMessage(for: error)
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
        if isDemoMode {
            loadingQueueItemIndex = index
            applyDemoCommand("play_context_at", value: .object(queueStartPayload(for: item, uri: uri, index: index)))
            loadingQueueItemIndex = nil
            appendDiagnosticLog("Demo wachtrij-item gestart: \(item.title)")
            return
        }
        guard let client, canUseBackend else {
            appendDiagnosticLog("Wachtrij-item starten overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        appendDiagnosticLog("Wachtrij-item starten: \(item.title)")
        loadingQueueItemIndex = index
        defer { loadingQueueItemIndex = nil }
        do {
            let response = try await client.sendCommand(
                DJConnectCommandPayload(
                    identity: identity,
                    command: "play_context_at",
                    value: .object(queueStartPayload(for: item, uri: uri, index: index)),
                    play: true
                )
            )
            applyPlayback(response.data ?? response.playback)
            statusMessage = "Nummer gestart"
            await loadQueue()
        } catch {
            statusMessage = Self.userMessage(for: error)
            appendDiagnosticLog("Wachtrij-item starten mislukt: \(statusMessage)", level: .error)
        }
    }

    func startPlaylist(_ playlist: DJConnectPlaylist) async {
        if isDemoMode {
            loadingPlaylistID = playlist.id
            applyDemoCommand("start_playlist", value: .string(playlist.commandValue))
            loadingPlaylistID = nil
            appendDiagnosticLog("Demo afspeellijst gestart: \(playlist.name)")
            return
        }
        guard let client, canUseBackend else {
            appendDiagnosticLog("Afspeellijst starten overgeslagen: niet gekoppeld", level: .warning)
            return
        }
        appendDiagnosticLog("Afspeellijst starten: \(playlist.name)")
        loadingPlaylistID = playlist.id
        defer { loadingPlaylistID = nil }
        do {
            let response = try await client.sendCommand(
                DJConnectCommandPayload(
                    identity: identity,
                    command: "start_playlist",
                    value: .string(playlist.commandValue),
                    play: true
                )
            )
            applyPlayback(response.data ?? response.playback)
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
        try? tokenStore.clearToken()
        paired = false
        storedDemoMode = false
        isDemoMode = false
        pairingCode = Self.makePairingCode()
        playback = nil
        playbackBeatSignature = nil
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
        localDeviceAPI?.setBonjourAdvertisingEnabled(true)
    }

    private func applyOutputs(_ devices: [DJConnectOutputDevice]) {
        let normalizedDevices = normalizedOutputDevices(devices)
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
        playback = nextPlayback
        let nextSignature = Self.playbackBeatSignature(for: nextPlayback)
        playbackBeatSignature = nextSignature

        guard confirmAskDJBeat,
              let nextSignature,
              nextSignature != previousSignature else {
            return
        }
        playAskDJBeatConfirmHaptic()
        appendDiagnosticLog("Ask DJ beat confirm")
    }

    private func playAskDJBeatConfirmHaptic() {
        WKInterfaceDevice.current().play(.click)
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
        guard let client, canUseBackend else {
            clearAskDJHistoryLocally()
            return
        }
        isClearingAskDJHistory = true
        defer { isClearingAskDJHistory = false }
        do {
            let response = try await client.clearAskDJHistory(memoryKey: memoryKey)
            applyAskDJHistory(response)
        } catch {
            statusMessage = Self.userMessage(for: error)
            showAskDJToast(Self.askDJToastText(for: error))
        }
    }

    func prepareAskDJHistoryForDisplay() async {
        guard client != nil, canUseBackend else {
            isCheckingAskDJHistoryState = false
            return
        }
        isCheckingAskDJHistoryState = true
        defer { isCheckingAskDJHistoryState = false }
        await syncAskDJHistory(showErrors: true)
    }

    func runAskDJHistorySyncLoop() async {
        guard client != nil, canUseBackend else {
            isCheckingAskDJHistoryState = false
            return
        }
        isCheckingAskDJHistoryState = true
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

    func playAskDJRecommendation(_ action: DJConnectAskDJPlaybackAction) async {
        guard playingAskDJActionID == nil, let client, canUseBackend else {
            return
        }
        guard action.uri?.isEmpty == false || action.contextURI?.isEmpty == false else {
            showAskDJToast("Deze aanbeveling kan nog niet worden afgespeeld")
            return
        }
        playingAskDJActionID = action.id
        defer { playingAskDJActionID = nil }
        do {
            var value = [
                "title": action.title,
                "memory_key": memoryKey
            ]
            if let subtitle = action.subtitle, !subtitle.isEmpty {
                value["subtitle"] = subtitle
            }
            if let uri = action.uri, !uri.isEmpty {
                value["uri"] = uri
            }
            if let contextURI = action.contextURI, !contextURI.isEmpty {
                value["context_uri"] = contextURI
            }
            if let offsetURI = action.offsetURI, !offsetURI.isEmpty {
                value["offset_uri"] = offsetURI
            }
            if let kind = action.kind, !kind.isEmpty {
                value["kind"] = kind
            }
            if let reason = action.reason, !reason.isEmpty {
                value["reason"] = reason
            }
            let response = try await client.sendCommandResponse(DJConnectCommandPayload(
                identity: identity,
                command: action.command?.isEmpty == false ? action.command! : "ask_dj_play_recommendation",
                value: .object(value),
                play: true
            ))
            if response.success {
                showAskDJToast("Aanbeveling afspelen")
                await refreshStatus(confirmAskDJBeat: true)
            } else {
                showAskDJToast(response.error ?? response.message ?? "Afspelen mislukt")
            }
        } catch {
            showAskDJToast(Self.askDJToastText(for: error))
        }
    }

    private func syncAskDJHistory(showErrors: Bool) async {
        guard let client, canUseBackend else {
            return
        }
        do {
            let response = try await client.askDJHistory()
            applyAskDJHistory(response)
        } catch {
            if showErrors {
                statusMessage = Self.userMessage(for: error)
                showAskDJToast(Self.askDJToastText(for: error))
            }
        }
    }

    private func requestAskDJIdleSuggestionIfNeeded() async {
        guard let client, canUseBackend,
              !hasRequestedAskDJIdleSuggestion,
              !isRequestingAskDJIdleSuggestion,
              !hasActiveNowPlaying else {
            return
        }
        hasRequestedAskDJIdleSuggestion = true
        isRequestingAskDJIdleSuggestion = true
        defer { isRequestingAskDJIdleSuggestion = false }
        do {
            let response = try await client.askDJIdleSuggestion(DJConnectAskDJIdleSuggestionRequest(
                identity: identity,
                clientMessageID: UUID().uuidString,
                mood: askDJMoodInt,
                djStyle: djStyle,
                memoryKey: memoryKey
            ))
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
        askDJMessages = nextMessages.sorted { $0.createdAt < $1.createdAt }
        askDJHistoryRevision = response.historyRevision
        askDJClearRevision = response.clearRevision
        saveAskDJMessages()
    }

    private func clearAskDJHistoryLocally() {
        askDJMessages = []
        UserDefaults.standard.removeObject(forKey: askDJMessagesKey)
        askDJHistoryRevision = 0
        askDJClearRevision = 0
    }

    private func applyAskDJHistory(_ response: DJConnectAskDJHistoryResponse) {
        if response.clearRevision > askDJClearRevision {
            askDJMessages = []
        }
        var nextMessages = askDJMessages
        for message in response.messages {
            upsertAskDJHistoryMessage(message, into: &nextMessages)
        }
        askDJMessages = nextMessages.sorted { $0.createdAt < $1.createdAt }
        askDJHistoryRevision = response.historyRevision
        askDJClearRevision = response.clearRevision
        saveAskDJMessages()
    }

    private func upsertAskDJHistoryMessage(
        _ historyMessage: DJConnectAskDJHistoryMessage,
        into messages: inout [DJConnectWatchAskDJMessage]
    ) {
        let existingIndex = messages.firstIndex { localMessage in
            localMessage.serverID == historyMessage.id
                || (historyMessage.clientMessageID != nil && localMessage.clientMessageID == historyMessage.clientMessageID)
        }
        let existing = existingIndex.map { messages[$0] }
        let mapped = DJConnectWatchAskDJMessage(
            id: existing?.id ?? UUID(uuidString: historyMessage.id) ?? UUID(),
            serverID: historyMessage.id,
            clientMessageID: historyMessage.clientMessageID,
            role: historyMessage.role == .user ? .user : .dj,
            text: historyMessage.text,
            images: proxiedResponseImages(historyMessage.images),
            links: safeResponseLinks(historyMessage.links),
            playbackActions: historyMessage.playbackActions,
            audioURL: resolvedAudioURL(historyMessage.audioURL),
            messageKind: historyMessage.role == .user ? .assistant : historyMessage.messageKind,
            origin: historyMessage.role == .user ? nil : historyMessage.origin,
            createdAt: historyMessage.createdAt
        )
        if let existingIndex {
            messages[existingIndex] = mapped
        } else {
            messages.append(mapped)
        }
    }

    private var client: DJConnectClient? {
        guard let url = URL(string: haBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return DJConnectClient(baseURL: url, identity: identity, tokenStore: tokenStore)
    }

    private func startLocalDeviceAPI() {
        guard !isDemoMode, !monkeyTestingMode else {
            return
        }
        localDeviceAPI?.stop()
        localDeviceAPI = DJConnectLocalDeviceAPI(
            infoProvider: { [weak self] in
                if let self {
                    return await DJConnectLocalDeviceAPIInfo(
                        identity: self.identity,
                        pairingToken: self.pairingCode,
                        pairingStatus: self.canUseBackend ? .paired : .unpaired,
                        localURL: self.localDeviceAPIURL
                    )
                }
                return DJConnectLocalDeviceAPIInfo(
                    identity: DJConnectIdentity(
                        deviceID: "djconnect-watchos-unavailable",
                        deviceName: "DJConnect Watch",
                        clientType: .watchos,
                        firmware: "0.0.0",
                        appVersion: "0.0.0",
                        platform: .watchos
                    ),
                    pairingToken: "",
                    pairingStatus: .unpaired
                )
            },
            tokenProvider: { [weak self] in
                try? self?.tokenStore.loadToken()
            },
            pairHandler: { [weak self] request in
                await self?.handleLocalPair(request) ?? DJConnectLocalDeviceAPIResponse(
                    success: false,
                    error: "unavailable",
                    message: "DJConnect Watch is unavailable."
                )
            },
            commandHandler: { [weak self] request in
                await self?.handleLocalCommand(request) ?? DJConnectLocalDeviceAPIResponse(
                    success: false,
                    error: "unavailable",
                    message: "DJConnect Watch is unavailable."
                )
            },
            djResponseHandler: { _ in
                DJConnectLocalDeviceAPIResponse(success: true, message: "accepted")
            },
            forgetHandler: { [weak self] in
                await self?.handleLocalForget() ?? DJConnectLocalDeviceAPIResponse(
                    success: false,
                    error: "unavailable",
                    message: "DJConnect Watch is unavailable."
                )
            },
            urlHandler: { [weak self] url in
                await MainActor.run {
                    self?.localDeviceAPIURL = url
                }
            },
            logHandler: { [weak self] message in
                await MainActor.run {
                    self?.appendDiagnosticLog(message)
                }
            },
            advertiseBonjour: !paired
        )
        localDeviceAPI?.start()
    }

    private func applyDemoState() {
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
            playback?.trackName = "Sweet Disposition"
            playback?.artistName = "The Temper Trap"
            playback?.isPlaying = true
            statusMessage = "Volgend demo nummer"
        case "previous":
            playback?.trackName = "Midnight City"
            playback?.artistName = "M83"
            playback?.isPlaying = true
            statusMessage = "Vorig demo nummer"
        default:
            statusMessage = "Demo opdracht ontvangen"
        }
    }

    private func sendDemoVoiceResponse() {
        voiceState = .processing
        statusMessage = "Demo verwerkt..."
        appendAskDJMessage(role: .user, text: "Stemverzoek")
        let response = "Ja hoor. Ik zou nu Midnight City van M83 aankondigen: glanzende synths, avondlucht, en precies genoeg energie om de kamer op te tillen."
        appendAskDJMessage(role: .dj, text: response)
        notifyAskDJResponse(response)
        voiceState = .idle
        statusMessage = response
        speechSynthesizer?.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: response)
        utterance.voice = AVSpeechSynthesisVoice(language: "nl-NL")
        utterance.rate = 0.48
        let synthesizer = AVSpeechSynthesizer()
        speechSynthesizer = synthesizer
        synthesizer.speak(utterance)
    }

    private func handleLocalPair(_ request: DJConnectLocalPairRequest) async -> DJConnectLocalDeviceAPIResponse {
        guard request.deviceID == identity.deviceID else {
            return DJConnectLocalDeviceAPIResponse(success: false, error: "wrong_device_id", message: "Pair request is for a different DJConnect device.")
        }
        guard request.clientType == identity.clientType else {
            return DJConnectLocalDeviceAPIResponse(success: false, error: "wrong_client_type", message: "Pair request is for a different DJConnect client type.")
        }
        guard request.resolvedPairCode == pairingCode else {
            return DJConnectLocalDeviceAPIResponse(success: false, error: "pair_code_mismatch", message: "Pairing code does not match this Watch.")
        }
        guard let token = request.resolvedDeviceToken, !token.isEmpty else {
            return DJConnectLocalDeviceAPIResponse(success: false, error: "missing_token", message: "Pair request did not include a device token.")
        }

        do {
            try tokenStore.saveToken(token)
        } catch {
            return DJConnectLocalDeviceAPIResponse(success: false, error: "token_store_failed", message: "Could not store device token.")
        }

        if let returnedURL = request.haLocalURL, !returnedURL.isEmpty {
            haBaseURL = returnedURL
        }
        paired = true
        connectionState = .paired
        isShowingPairingSuccess = true
        statusMessage = "Succesvol gekoppeld"
        localDeviceAPI?.setBonjourAdvertisingEnabled(false)
        await refreshStatus()
        return DJConnectLocalDeviceAPIResponse(
            success: true,
            message: "paired",
            deviceID: identity.deviceID,
            clientType: identity.clientType.rawValue,
            paired: true
        )
    }

    private func handleLocalCommand(_ request: DJConnectLocalCommandRequest) async -> DJConnectLocalDeviceAPIResponse {
        guard let command = request.command, !command.isEmpty else {
            return DJConnectLocalDeviceAPIResponse(success: false, error: "missing_command", message: "Missing command.")
        }
        await sendCommand(command)
        return DJConnectLocalDeviceAPIResponse(success: true, message: "accepted")
    }

    private func handleLocalForget() async -> DJConnectLocalDeviceAPIResponse {
        resetPairing()
        return DJConnectLocalDeviceAPIResponse(success: true, message: "forgotten")
    }

    private func statusPayload(screenState: String) -> DJConnectStatusPayload {
        DJConnectStatusPayload(
            identity: identity,
            haPairingStatus: canUseBackend ? .paired : .unpaired,
            batteryPercent: Int(WKInterfaceDevice.current().batteryLevel * 100),
            language: Locale.current.language.languageCode?.identifier,
            osVersion: WKInterfaceDevice.current().systemVersion,
            localAudioSupported: true,
            voiceSupported: true,
            screenState: screenState,
            networkType: "watch",
            haLocalURL: haBaseURL,
            voiceEnabled: true,
            wakewordEnabled: false,
            wakewordPhrase: "Hey DJ",
            wakewordStatus: "foreground_only_not_enabled",
            mood: askDJMoodInt,
            djStyle: djStyle,
            memoryKey: memoryKey
        )
    }

    private func startRecording() {
        if isDemoMode {
            sendDemoVoiceResponse()
            return
        }
        guard canUseBackend else {
            voiceState = .failed("Koppel eerst met Home Assistant.")
            return
        }
        Task {
            let granted = await requestMicrophoneAccess()
            guard granted else {
                voiceState = .failed("Microfoontoegang is nodig.")
                return
            }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .spokenAudio)
                try session.setActive(true)

                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("djconnect-watch-\(UUID().uuidString)")
                    .appendingPathExtension("wav")
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatLinearPCM),
                    AVSampleRateKey: 16_000,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false
                ]
                let recorder = try AVAudioRecorder(url: url, settings: settings)
                recorder.record()
                self.recorder = recorder
                self.recordingURL = url
                self.voiceState = .recording
                self.statusMessage = "Luistert"
            } catch {
                self.voiceState = .failed(Self.userMessage(for: error))
            }
        }
    }

    private func stopRecordingAndSend() {
        recorder?.stop()
        recorder = nil
        let url = recordingURL
        recordingURL = nil
        voiceState = .processing
        statusMessage = "Verwerken..."

        Task {
            defer {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                if let url {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            guard let url, let client else {
                voiceState = .idle
                return
            }
            do {
                let data = try Data(contentsOf: url)
                appendAskDJMessage(role: .user, text: "Stemverzoek")
                let response = try await client.sendVoice(
                    wavData: data,
                    mood: askDJMoodInt,
                    djStyle: djStyle,
                    memoryKey: memoryKey
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
            } catch {
                voiceState = .failed(Self.userMessage(for: error))
                showAskDJToast(Self.askDJToastText(for: error))
                appendAskDJMessage(role: .dj, text: Self.userMessage(for: error))
            }
        }
    }

    private func appendAskDJMessage(
        role: DJConnectWatchAskDJMessage.Role,
        text: String,
        images: [DJConnectResponseImage] = [],
        links: [DJConnectResponseLink] = [],
        audioURL: URL? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !images.isEmpty || !links.isEmpty || audioURL != nil else {
            return
        }
        askDJMessages.append(DJConnectWatchAskDJMessage(
            role: role,
            text: trimmed,
            images: images,
            links: links,
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
            hasRequestedAskDJNotificationPermission = true
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                appendDiagnosticLog("Notificatie toestemming mislukt: \(error.localizedDescription)", level: .warning)
                return false
            }
        case .denied:
            return false
        @unknown default:
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
        player?.stop()
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
        player?.stop()

        if let audioURL = resolvedAudioURL(audioURL) {
            do {
                askDJAudioPlaybackState = .loading(audioURL)
                let (audio, _) = try await URLSession.shared.data(from: audioURL)
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
                try AVAudioSession.sharedInstance().setActive(true)
                let player = try AVAudioPlayer(data: audio)
                self.player = player
                player.play()
                askDJAudioPlaybackState = .playing(audioURL)
                let duration = max(0.2, player.duration)
                audioPlaybackTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(duration))
                    guard !Task.isCancelled else {
                        return
                    }
                    if case let .playing(currentURL) = self?.askDJAudioPlaybackState, currentURL == audioURL {
                        self?.askDJAudioPlaybackState = .idle
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
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "nl-NL")
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

    private func proxiedResponseImages(_ images: [DJConnectResponseImage]?) -> [DJConnectResponseImage] {
        guard let images, let allowedHost = URL(string: haBaseURL)?.host?.lowercased() else {
            return []
        }
        return images.filter { $0.url.host?.lowercased() == allowedHost }
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
        case .backendUnavailable, .server, .decodingFailed, .invalidResponse:
            return "Home Assistant gaf geen antwoord"
        case .network, .routeMissing, .notConfigured, .invalidConfiguration, .missingToken, .pairingFailed, .authStale, .versionMismatch:
            return "Ask DJ niet bereikbaar"
        }
    }

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
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

    private static func userMessage(for error: Error) -> String {
        if let error = error as? DJConnectError {
            switch error {
            case .missingToken:
                return "Koppel eerst met Home Assistant."
            case .backendUnavailable, .server, .decodingFailed, .invalidResponse:
                return "Home Assistant gaf geen antwoord."
            case .network,
                 .authStale,
                 .notConfigured,
                 .pairingFailed,
                 .routeMissing:
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
