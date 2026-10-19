import SwiftUI
import AVFoundation
import DJConnectCore

/// Same device-local controls on phone, tablet, Mac and Watch; no Profile writes.
public struct DeviceSpeechSettingsView: View {
    let language: String
    @Binding var preferences: DJConnectDeviceSpeechPreferences
    let previewAllowed: Bool
    let isSpeaking: Bool
    let preview: () -> Void
    let stop: () -> Void
    @State private var voices: [DJConnectDeviceSpeechVoice] = []
    public init(language: String, preferences: Binding<DJConnectDeviceSpeechPreferences>, previewAllowed: Bool,
                isSpeaking: Bool, preview: @escaping () -> Void, stop: @escaping () -> Void) {
        self.language = language; _preferences = preferences; self.previewAllowed = previewAllowed
        self.isSpeaking = isSpeaking; self.preview = preview; self.stop = stop
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: "ui.device_speech." + key, language: language) }
    private var matching: [DJConnectDeviceSpeechVoice] {
        voices.filter { $0.language.lowercased().split(separator: "-").first == language.lowercased().split(separator: "-").first &&
            (preferences.gender == .default || preferences.gender == $0.gender) }
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(text("enabled"), isOn: $preferences.enabled).accessibilityIdentifier("device-speech-enabled")
            Text(text("explanation")).font(.caption).foregroundStyle(.secondary)
            if preferences.enabled {
                Picker(text("gender"), selection: Binding(get: { preferences.gender }, set: { preferences.gender = $0; preferences.voiceID = nil })) {
                    Text(text("system")).tag(DJConnectVoicePreference.default)
                    if voices.contains(where: { $0.gender == .female }) { Text(text("female")).tag(DJConnectVoicePreference.female) }
                    if voices.contains(where: { $0.gender == .male }) { Text(text("male")).tag(DJConnectVoicePreference.male) }
                }
                Picker(text("voice"), selection: Binding(get: { preferences.voiceID ?? "" }, set: { preferences.voiceID = $0.isEmpty ? nil : $0 })) {
                    Text(text("system")).tag("")
                    if let id = preferences.voiceID, !matching.contains(where: { $0.id == id }) { Text(text("unavailable")).tag(id) }
                    ForEach(matching) { voice in Text("\(voice.name) (\(voice.language))").tag(voice.id) }
                }.accessibilityIdentifier("device-speech-voice")
                Text(text("rate"))
                Slider(value: $preferences.rate, in: 0...1).accessibilityLabel(text("rate"))
                Text(text("pitch"))
                Slider(value: $preferences.pitch, in: 0.5...2).accessibilityLabel(text("pitch"))
                Button(isSpeaking ? text("stop") : text("preview"), action: isSpeaking ? stop : preview)
                    #if os(watchOS)
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    #else
                    .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .selected, selectionTint: .purple))
                    #endif
                    .disabled(!isSpeaking && (!previewAllowed || matching.isEmpty))
                    .accessibilityIdentifier("device-speech-preview")
            }
        }
        .task { voices = DJConnectAppleSpeechRenderer.voices() }
        .onReceive(NotificationCenter.default.publisher(for: AVSpeechSynthesizer.availableVoicesDidChangeNotification)) { _ in
            stop(); voices = DJConnectAppleSpeechRenderer.voices()
        }
        .onDisappear { stop() }
    }
}
