import AVFoundation
import DJConnectCore
import SwiftUI
import WatchKit

struct DJConnectWatchAskDJMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user
        case dj
    }

    var id: UUID
    var role: Role
    var text: String
    var images: [DJConnectResponseImage]
    var links: [DJConnectResponseLink]
    var audioURL: URL?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        images: [DJConnectResponseImage] = [],
        links: [DJConnectResponseLink] = [],
        audioURL: URL? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.images = images
        self.links = links
        self.audioURL = audioURL
        self.createdAt = createdAt
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
    @AppStorage("askDJMood") var askDJMood = 50.0

    @Published private(set) var connectionState: ConnectionState = .unpaired
    @Published private(set) var voiceState: VoiceState = .idle
    @Published private(set) var playback: DJConnectPlayback?
    @Published private(set) var responseImages: [DJConnectResponseImage] = []
    @Published private(set) var askDJMessages: [DJConnectWatchAskDJMessage] = []
    @Published private(set) var isCheckingAskDJHistoryState = true
    @Published private(set) var isClearingAskDJHistory = false
    @Published private(set) var askDJToast: DJConnectWatchToast?
    @Published private(set) var askDJAudioPlaybackState: DJConnectWatchAudioPlaybackState = .idle
    @Published var statusMessage = "Niet gekoppeld"

    private let askDJMessagesKey = "DJConnectWatchAskDJMessages"
    private let tokenStore = DJConnectKeychainTokenStore(service: "dev.djconnect.watch")
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var player: AVAudioPlayer?
    private var audioPlaybackTask: Task<Void, Never>?
    private var speechSynthesizer: AVSpeechSynthesizer?

    override init() {
        super.init()
        askDJMessages = Self.loadAskDJMessages(key: askDJMessagesKey)
        connectionState = paired ? .paired : .unpaired
        statusMessage = paired ? "Gereed" : "Niet gekoppeld"
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

    func pair() async {
        guard let client else {
            connectionState = .failed("Controleer het Client adres.")
            return
        }
        connectionState = .pairing
        statusMessage = "Koppelen..."
        do {
            let response = try await client.pair(
                DJConnectPairingPayload(
                    identity: identity,
                    pairingToken: pairingCode,
                    haLocalURL: haBaseURL
                )
            )
            if let returnedURL = response.haLocalURL, !returnedURL.isEmpty {
                haBaseURL = returnedURL
            }
            paired = true
            connectionState = .paired
            statusMessage = "Gekoppeld"
            await refreshStatus()
        } catch {
            connectionState = .failed(Self.userMessage(for: error))
            statusMessage = "Koppelen mislukt"
        }
    }

    func refreshStatus() async {
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
        pairingCode = Self.makePairingCode()
        playback = nil
        responseImages = []
        clearAskDJHistoryLocally()
        connectionState = .unpaired
        voiceState = .idle
        statusMessage = "Niet gekoppeld"
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
            let response = try await client.sendCommandResponse(DJConnectCommandPayload(
                identity: identity,
                command: "clear_ask_dj_history",
                value: .object(["memory_key": memoryKey])
            ))
            if response.success {
                clearAskDJHistoryLocally()
            } else {
                statusMessage = response.error ?? response.message ?? "Wissen mislukt"
            }
        } catch {
            statusMessage = Self.userMessage(for: error)
        }
    }

    func prepareAskDJHistoryForDisplay() async {
        guard let client, canUseBackend else {
            isCheckingAskDJHistoryState = false
            return
        }
        isCheckingAskDJHistoryState = true
        defer { isCheckingAskDJHistoryState = false }
        do {
            let response = try await client.sendCommandResponse(DJConnectCommandPayload(
                identity: identity,
                command: "ask_dj_history_state",
                value: .object(["memory_key": memoryKey])
            ))
            if response.askDJClearRequired == true {
                clearAskDJHistoryLocally()
            }
        } catch {
            statusMessage = Self.userMessage(for: error)
        }
    }

    private func clearAskDJHistoryLocally() {
        askDJMessages = []
        UserDefaults.standard.removeObject(forKey: askDJMessagesKey)
    }

    private var client: DJConnectClient? {
        guard let url = URL(string: haBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return DJConnectClient(baseURL: url, identity: identity, tokenStore: tokenStore)
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
