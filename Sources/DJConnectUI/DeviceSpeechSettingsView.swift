import SwiftUI
import AVFoundation
import DJConnectCore

/// Explicit full-width alignment also works outside native Form containers.
struct SpeechPreferenceRow<Control: View>: View {
    let label: String
    @ViewBuilder var control: () -> Control

    var body: some View {
        #if os(watchOS)
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .fixedSize(horizontal: false, vertical: true)
            control()
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        #else
        HStack(alignment: .center, spacing: 16) {
            Text(label)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            control()
                .labelsHidden()
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        #endif
    }
}

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
        Group {
            #if os(watchOS)
            List { speechRows }
                .listStyle(.plain)
                .watchStandardBackground()
            #else
            VStack(alignment: .leading, spacing: 12) { speechRows }
            #endif
        }
        .task { refreshVoices() }
        .onReceive(NotificationCenter.default.publisher(for: AVSpeechSynthesizer.availableVoicesDidChangeNotification)) { _ in
            stop(); refreshVoices()
        }
        .onDisappear { stop() }
    }

    private func refreshVoices() { voices = DJConnectAppleSpeechRenderer.voices() }

    @ViewBuilder private var speechRows: some View {
        SpeechPreferenceRow(label: text("enabled")) {
            Toggle(text("enabled"), isOn: $preferences.enabled)
                .accessibilityIdentifier("device-speech-enabled")
        }
        Text(text("explanation")).font(.caption).foregroundStyle(.secondary)
        if preferences.enabled {
            speechChoiceRows
            SpeechPreferenceRow(label: text("rate")) {
                Slider(value: $preferences.rate, in: 0...1)
                    #if !os(watchOS)
                    .frame(minWidth: 60, idealWidth: 160, maxWidth: 160)
                    #endif
                    .accessibilityLabel(text("rate"))
            }
            SpeechPreferenceRow(label: text("pitch")) {
                Slider(value: $preferences.pitch, in: 0.5...2)
                    #if !os(watchOS)
                    .frame(minWidth: 60, idealWidth: 160, maxWidth: 160)
                    #endif
                    .accessibilityLabel(text("pitch"))
            }
            Button(isSpeaking ? text("stop") : text("preview"), action: isSpeaking ? stop : preview)
                #if os(watchOS)
                .listRowBackground(Color.clear)
                #else
                .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .selected, selectionTint: .purple))
                #endif
                .disabled(!isSpeaking && (!previewAllowed || matching.isEmpty))
                .accessibilityIdentifier("device-speech-preview")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder private var speechChoiceRows: some View {
        let gender = Binding(get: { preferences.gender }, set: {
            preferences.gender = $0
            preferences.voiceID = nil
        })
        let voice = Binding(get: { preferences.voiceID ?? "" }, set: {
            preferences.voiceID = $0.isEmpty ? nil : $0
        })
        let genders: [(DJConnectVoicePreference, String)] = [(.default, text("system"))] +
            [(DJConnectVoicePreference.female, text("female")), (.male, text("male"))].filter { choice in
                voices.contains { $0.gender == choice.0 }
            }
        let unavailable: [(String, String)] = if let id = preferences.voiceID, !matching.contains(where: { $0.id == id }) {
            [(id, text("unavailable"))]
        } else {
            []
        }
        let voiceOptions = [("", text("system"))] + unavailable + matching.map { ($0.id, "\($0.name) (\($0.language))") }

        choiceRow(label: text("gender"), selection: gender, choices: genders)
        choiceRow(label: text("voice"), selection: voice, choices: voiceOptions)
            .accessibilityIdentifier("device-speech-voice")
    }

    @ViewBuilder private func choiceRow<Value: Hashable>(label: String, selection: Binding<Value>,
                                                         choices: [(Value, String)]) -> some View {
        #if os(watchOS)
        NavigationLink {
            List {
                ForEach(choices, id: \.0) { choice in
                    Button { selection.wrappedValue = choice.0 } label: {
                        HStack {
                            Text(choice.1)
                            Spacer()
                            if selection.wrappedValue == choice.0 {
                                Image(systemName: "checkmark").accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection.wrappedValue == choice.0 ? .isSelected : [])
                }
            }
            .watchStandardBackground()
            .navigationTitle(label)
        } label: {
            LabeledContent(label, value: choices.first { $0.0 == selection.wrappedValue }?.1 ?? "")
        }
        #else
        SpeechPreferenceRow(label: label) {
            Picker(label, selection: selection) {
                ForEach(choices, id: \.0) { choice in Text(choice.1).tag(choice.0) }
            }
        }
        #endif
    }
}
