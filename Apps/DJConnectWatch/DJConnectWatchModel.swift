import AVFoundation
import DJConnectCore
import SwiftUI
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

enum DJConnectWatchAudioPlaybackState: Equatable {
    case idle
    case loading(URL)
    case playing(URL)
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
    @AppStorage("askDJHistoryRevision") private var askDJHistoryRevision = 0
    @AppStorage("askDJClearRevision") private var askDJClearRevision = 0

    @Published private(set) var connectionState: ConnectionState = .unpaired
    @Published private(set) var voiceState: VoiceState = .idle
    @Published private(set) var playback: DJConnectPlayback?
    @Published private(set) var responseImages: [DJConnectResponseImage] = []
    @Published private(set) var askDJMessages: [DJConnectWatchAskDJMessage] = []
    @Published private(set) var isCheckingAskDJHistoryState = true
    @Published private(set) var isClearingAskDJHistory = false
    @Published private(set) var isRequestingAskDJIdleSuggestion = false
    @Published private(set) var playingAskDJActionID: String?
    @Published private(set) var askDJToast: DJConnectWatchToast?
    @Published private(set) var askDJAudioPlaybackState: DJConnectWatchAudioPlaybackState = .idle
    @Published private(set) var isShowingPairingSuccess = false
    @Published private(set) var isDemoMode = false
    @Published var statusMessage = "Niet gekoppeld"

    private let askDJMessagesKey = "DJConnectWatchAskDJMessages"
    private let tokenStore = DJConnectKeychainTokenStore(service: "dev.djconnect.watch")
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

    init(monkeyTestingMode: Bool = false) {
        self.monkeyTestingMode = monkeyTestingMode
        super.init()
        askDJMessages = Self.loadAskDJMessages(key: askDJMessagesKey)
        if monkeyTestingMode {
            storedDemoMode = false
            isDemoMode = true
            applyDemoState()
        } else if storedDemoMode {
            isDemoMode = true
            applyDemoState()
        } else {
            connectionState = paired ? .paired : .unpaired
            statusMessage = paired ? "Gereed" : "Niet gekoppeld"
            startLocalDeviceAPI()
        }
    }

    deinit {
        localDeviceAPI?.stop()
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

    var askDJMoodInt: Int {
        max(0, min(100, Int(askDJMood.rounded())))
    }

    var askDJMoodLabel: String {
        switch askDJMoodInt {
        case 0...24:
            return "Chill"
        case 25...59:
            return "Groove"
        case 60...84:
            return "Energy"
        default:
            return "Party"
        }
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
        storedDemoMode = false
        isDemoMode = false
        playback = nil
        responseImages = []
        voiceState = .idle
        connectionState = paired ? .paired : .unpaired
        statusMessage = paired ? "Gereed" : "Demo modus gestopt"
        if !paired {
            startLocalDeviceAPI()
        }
    }

    func refreshStatus() async {
        guard !isDemoMode else {
            applyDemoState()
            return
        }
        guard let client, canUseBackend else {
            return
        }
        do {
            let response = try await client.postStatus(statusPayload(screenState: "now_playing"))
            playback = response.data ?? response.playback
            statusMessage = "Bijgewerkt"
        } catch {
            statusMessage = Self.userMessage(for: error)
        }
    }

    func sendCommand(_ command: String) async {
        if isDemoMode {
            applyDemoCommand(command)
            return
        }
        guard let client, canUseBackend else {
            return
        }
        do {
            let response = try await client.sendCommand(
                DJConnectCommandPayload(identity: identity, command: command)
            )
            playback = response.data ?? response.playback
            statusMessage = "Verzonden"
        } catch {
            statusMessage = Self.userMessage(for: error)
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
        try? tokenStore.clearToken()
        paired = false
        storedDemoMode = false
        isDemoMode = false
        pairingCode = Self.makePairingCode()
        playback = nil
        responseImages = []
        clearAskDJHistoryLocally()
        connectionState = .unpaired
        voiceState = .idle
        isShowingPairingSuccess = false
        statusMessage = "Niet gekoppeld"
        localDeviceAPI?.setBonjourAdvertisingEnabled(true)
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
                await refreshStatus()
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
        var nextMessages: [DJConnectWatchAskDJMessage] = []
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
            logHandler: { _ in },
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
        responseImages = []
        statusMessage = "Demo modus actief"
    }

    private func applyDemoCommand(_ command: String) {
        if playback == nil {
            applyDemoState()
        }
        switch command {
        case "play":
            playback?.isPlaying = true
            statusMessage = "Demo speelt"
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
                await playVoiceResponse(response)
                await syncAskDJHistory(showErrors: false)
                await refreshStatus()
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
    }

    private func saveAskDJMessages() {
        if let data = try? JSONEncoder().encode(askDJMessages) {
            UserDefaults.standard.set(data, forKey: askDJMessagesKey)
        }
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
            case let .network(message):
                return message
            case let .authStale(_, message),
                 let .backendUnavailable(message),
                 let .notConfigured(message),
                 let .pairingFailed(message),
                 let .routeMissing(message),
                 let .server(_, message):
                return message ?? "Home Assistant is niet bereikbaar."
            case let .versionMismatch(mismatch):
                return mismatch.message ?? "Werk DJConnect bij."
            case let .decodingFailed(_, _, message):
                return message ?? "Onverwacht antwoord."
            case .invalidResponse:
                return "Ongeldig antwoord."
            case let .invalidConfiguration(message):
                return message
            }
        }
        return error.localizedDescription
    }
}
