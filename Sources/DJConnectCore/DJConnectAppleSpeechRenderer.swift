#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import Foundation

public struct DJConnectDeviceSpeechVoice: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let language: String
    public let gender: DJConnectVoicePreference
}
private final class DeviceSpeechObservations {
    var tokens: [NSObjectProtocol] = []
    deinit { for token in tokens { NotificationCenter.default.removeObserver(token) } }
}

/// One native utterance, no queue, stored text, network synthesis or fallback.
@MainActor public final class DJConnectAppleSpeechRenderer: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var utteranceID: ObjectIdentifier?
    private var completion: (() -> Void)?
    private let observations = DeviceSpeechObservations()
    /// Request activity remains compatible with preview controls. Actual output
    /// is separately confirmed by identity-fenced AVSpeechSynthesizer delegates.
    public var onStateChange: ((Bool) -> Void)?
    public var onPlaybackStateChange: ((Bool) -> Void)?
    public var onPlaybackFinished: ((Bool) -> Void)?
    public private(set) var isActuallySpeaking = false
    public private(set) var isSpeaking = false
    public override init() {
        super.init(); synthesizer.delegate = self
        var names: [Notification.Name] = [AVSpeechSynthesizer.availableVoicesDidChangeNotification]
        #if os(iOS) || os(watchOS)
        names += [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification]
        #endif
        for name in names {
            observations.tokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.stop() }
            })
        }
    }
    public static func voices() -> [DJConnectDeviceSpeechVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { !$0.voiceTraits.contains(.isPersonalVoice) }.map { voice in
            .init(id: voice.identifier, name: voice.name, language: voice.language,
                  gender: voice.gender == .male ? .male : voice.gender == .female ? .female : .default)
        }.sorted { ($0.language, $0.name, $0.id) < ($1.language, $1.name, $1.id) }
    }
    public static func selectedVoice(locale: String, preferences: DJConnectDeviceSpeechPreferences) -> DJConnectDeviceSpeechVoice? {
        guard preferences.isValid else { return nil }
        let language = locale.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-").first
        let matching = voices().filter {
            $0.language.lowercased().split(separator: "-").first == language &&
            (preferences.gender == .default || $0.gender == preferences.gender)
        }
        if let id = preferences.voiceID { return matching.first { $0.id == id } }
        if preferences.gender == .default, let system = AVSpeechSynthesisVoice(language: locale), let voice = matching.first(where: { $0.id == system.identifier }) { return voice }
        return matching.first
    }
    @discardableResult public func speak(_ text: String, locale: String, preferences: DJConnectDeviceSpeechPreferences,
                                        completion: @escaping () -> Void) -> Bool {
        stop()
        guard preferences.enabled, !text.isEmpty, text.unicodeScalars.count <= 4000,
              let selected = Self.selectedVoice(locale: locale, preferences: preferences),
              let voice = AVSpeechSynthesisVoice(identifier: selected.id) else { return false }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice; utterance.rate = Float(preferences.rate)
        utterance.pitchMultiplier = Float(preferences.pitch)
        utteranceID = ObjectIdentifier(utterance); self.completion = completion
        isSpeaking = true; onStateChange?(true); synthesizer.speak(utterance)
        return true
    }
    public func stop() { end(completed: false) }
    private func end(completed: Bool) {
        let wasActive = utteranceID != nil
        utteranceID = nil; completion = nil
        synthesizer.stopSpeaking(at: .immediate)
        if isActuallySpeaking { isActuallySpeaking = false; onPlaybackStateChange?(false) }
        if isSpeaking { isSpeaking = false; onStateChange?(false) }
        if wasActive { onPlaybackFinished?(completed) }
    }
    private func observed(_ id: ObjectIdentifier, playing: Bool) {
        guard utteranceID == id, isActuallySpeaking != playing else { return }
        isActuallySpeaking = playing; onPlaybackStateChange?(playing)
    }
    private func finished(_ id: ObjectIdentifier, completed: Bool) {
        guard utteranceID == id else { return }
        let done = completion; end(completed: completed); done?()
    }
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.observed(id, playing: true) }
    }
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.observed(id, playing: true) }
    }
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.observed(id, playing: false) }
    }
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.finished(id, completed: true) }
    }
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.finished(id, completed: false) }
    }
}
#endif

#if canImport(Speech) && (os(iOS) || os(macOS))
@preconcurrency import Speech
import Foundation

public enum DJConnectDeviceSTTError: Error, Sendable {
    case permission, unavailable, failed, empty
}

/// Transient file recognition. Audio must stay on this device; no network fallback.
@MainActor public final class DJConnectAppleSpeechTranscriber {
    private var recognition: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, Error>?
    private var timeout: Task<Void, Never>?
    private var generation = UUID()
    public init() {}

    public static func isAvailable(language: String) -> Bool {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)) else { return false }
        return recognizer.isAvailable && recognizer.supportsOnDeviceRecognition
    }
    public func cancel() {
        finish(generation, result: .failure(CancellationError()))
    }
    public func transcribe(url: URL, language: String) async throws -> String {
        cancel()
        try Task.checkCancellation()
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { throw DJConnectDeviceSTTError.permission }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else { throw DJConnectDeviceSTTError.unavailable }
        let id = UUID(); generation = id
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { pending in
                continuation = pending
                let request = SFSpeechURLRecognitionRequest(url: url)
                request.requiresOnDeviceRecognition = true
                request.shouldReportPartialResults = false
                request.taskHint = .dictation
                recognition = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    let text = result?.isFinal == true ? result?.bestTranscription.formattedString : nil
                    let failed = error != nil
                    Task { @MainActor [weak self] in
                        if let text {
                            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            self?.finish(id, result: trimmed.isEmpty ? .failure(DJConnectDeviceSTTError.empty) : .success(trimmed))
                        } else if failed { self?.finish(id, result: .failure(DJConnectDeviceSTTError.failed)) }
                    }
                }
                timeout = Task { @MainActor [weak self] in
                    do { try await Task.sleep(for: .seconds(30)) } catch { return }
                    self?.finish(id, result: .failure(DJConnectDeviceSTTError.failed))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish(id, result: .failure(CancellationError())) }
        }
    }
    private func finish(_ id: UUID, result: Result<String, Error>) {
        guard id == generation else { return }
        generation = UUID()
        let pending = continuation; continuation = nil
        timeout?.cancel(); timeout = nil
        recognition?.cancel(); recognition = nil
        pending?.resume(with: result)
    }
}
#endif
