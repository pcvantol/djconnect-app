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
    public var onStateChange: ((Bool) -> Void)?
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
    public func stop() {
        utteranceID = nil; completion = nil
        synthesizer.stopSpeaking(at: .immediate)
        if isSpeaking { isSpeaking = false; onStateChange?(false) }
    }
    private func finished(_ id: ObjectIdentifier) {
        guard utteranceID == id else { return }
        let done = completion; stop(); done?()
    }
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.finished(id) }
    }
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.finished(id) }
    }
}
#endif
