import SwiftUI
import DJConnectCore

/// Device-local voice intent. Menu reads and selections never prepare or play speech.
struct ActiveSessionVoiceToolbar: View {
    @ObservedObject var model: DJConnectAppModel
    let session: DJConnectSessionRuntime
    @ObservedObject private var history: DJConnectSessionHistoryModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showing = false
    @State private var menuScope: DJConnectSpeechVoiceScope?
    @State private var menuEpoch: UUID?

    init(model: DJConnectAppModel, session: DJConnectSessionRuntime) {
        self.model = model; self.session = session; history = model.sessionHistory
    }
    private func text(_ suffix: String) -> String {
        DJConnectLocalization.localized(key: "ui.session.voice." + suffix, language: model.language)
    }
    private var current: Bool {
        scenePhase == .active && model.activeVoiceIsCurrent && model.activeDJSession?.id == session.id &&
        menuEpoch == history.responseEpoch && menuScope == model.activeVoicePreference.scope
    }
    private var options: DJConnectSpeechVoiceOptions? { current ? model.activeVoicePreference.options : nil }
    private func choose(_ voice: String?) {
        guard current, let menuScope, let menuEpoch else { return }
        model.selectActiveVoice(voice, expectedScope: menuScope, expectedEpoch: menuEpoch)
    }
    private func chooseGender(_ preference: DJConnectVoicePreference) {
        guard current, let menuScope, let menuEpoch else { return }
        model.selectActiveVoiceGender(preference, expectedScope: menuScope, expectedEpoch: menuEpoch)
    }
    private func refresh() async {
        await model.refreshActiveVoiceOptions()
        guard showing, scenePhase == .active, model.activeDJSession?.id == session.id else { return }
        menuScope = model.activeVoicePreference.scope
        menuEpoch = history.responseEpoch
    }
    var body: some View {
        Button { showing = true } label: {
            Label { Text(text("title")) } icon: {
                Image(systemName: "speaker.wave.2").foregroundStyle(.white)
            }
        }
            .foregroundStyle(.white)
            .tint(.white)
            .accessibilityIdentifier("session-voice-toggle")
            .popover(isPresented: $showing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(text("title")).font(.headline).accessibilityAddTraits(.isHeader)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(text("scope")).font(.caption).fixedSize(horizontal: false, vertical: true)
                        if model.activeVoicePreference.refreshing {
                            ProgressView(text("loading"))
                        }
                        if let options {
                            SessionVoiceGenderSelector(language: model.language, values: options.selectableGenders,
                                selected: model.activeVoicePreference.selectedGender,
                                enabled: current && !model.activeVoicePreference.refreshing, onSelect: chooseGender)
                            voicePicker(options)
                            if let voice = options.providerVoice {
                                Text(text("configured") + ": " + voice.voiceName + " · " + voice.locale)
                                    .font(.caption).fixedSize(horizontal: false, vertical: true)
                            }
                            if let notice = options.notification ?? options.providerStatus?.notification,
                               notice.isValid, notice.locale == model.language {
                                Text(notice.title).font(.headline)
                                Text(notice.message).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if !model.activeVoicePreference.refreshing && (!current || model.activeVoicePreference.resolution == .unavailable) {
                            Text(model.activeVoiceError ?? text("unavailable"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Divider()
                        SessionVoiceAutoplayControl(model: model)
                        Button { Task { await refresh() } } label: {
                            Label(text("refresh"), systemImage: "arrow.clockwise").frame(minHeight: 44)
                        }
                        .disabled(model.activeVoicePreference.refreshing)
                        .accessibilityIdentifier("session-voice-refresh")
                    }.padding(16)
                }
                .frame(idealWidth: 340, maxHeight: 500)
                .presentationBackground(.ultraThinMaterial)
                .presentationCompactAdaptation(.popover)
                .task {
                    model.setActiveVoiceMenuOpen(true)
                    menuEpoch = history.responseEpoch
                    await refresh()
                }
                .onDisappear { model.setActiveVoiceMenuOpen(false); menuScope = nil; menuEpoch = nil }
            }
            .onChange(of: session.id) { showing = false }
            .onChange(of: history.responseEpoch) { showing = false }
            .onChange(of: scenePhase) { _, phase in if phase != .active { showing = false } }
    }
    private func voicePicker(_ options: DJConnectSpeechVoiceOptions) -> some View {
        Picker(text("choice"), selection: Binding<String?>(
            get: { model.activeVoicePreference.selectedVoiceID },
            set: { choose($0) }
        )) {
            Text(text("default")).tag(Optional<String>.none)
                .disabled(!options.supports(.default))
            ForEach(options.selectableVoices, id: \.voiceID) { voice in
                Text(voice.name).tag(Optional(voice.voiceID))
            }
            // Keep unavailable intent represented. SwiftUI must not display the
            // default as if a removed voice had been silently replaced.
            if let selected = model.activeVoicePreference.selectedVoiceID, !options.supportsVoice(selected) {
                Text(text("selection_unavailable")).tag(Optional(selected)).disabled(true)
            }
        }
        .pickerStyle(.menu)
        .frame(minHeight: 44)
        .disabled(!current || model.activeVoicePreference.refreshing ||
                  (!options.supports(.default) && options.selectableVoices.isEmpty))
        .accessibilityIdentifier("session-voice-picker")
    }
}
