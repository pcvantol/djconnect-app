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
    private func refresh() async {
        await model.refreshActiveVoiceOptions()
        guard showing, scenePhase == .active, model.activeDJSession?.id == session.id else { return }
        menuScope = model.activeVoicePreference.scope
        menuEpoch = history.responseEpoch
    }
    var body: some View {
        Button { showing = true } label: { Label(text("title"), systemImage: "speaker.wave.2") }
            .foregroundStyle(.white)
            .accessibilityIdentifier("session-voice-toggle")
            .popover(isPresented: $showing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(text("title")).font(.headline).accessibilityAddTraits(.isHeader)
                        Toggle(isOn: $model.localResponseAudioEnabled) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(DJConnectLocalization.localized(key: "ui.auto.play.dj.answers", language: model.language))
                                Text(DJConnectLocalization.localized(key: "ui.play.dj.answer.audio.as.soon.as.it.arrives", language: model.language))
                                    .font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("session-voice-autoplay")
                        Divider()
                        Text(text("scope")).font(.caption).fixedSize(horizontal: false, vertical: true)
                        if model.activeVoicePreference.refreshing {
                            ProgressView(text("loading"))
                        }
                        if let options {
                            voiceRow(text("default"), selected: model.activeVoicePreference.selectedVoiceID == nil,
                                     enabled: options.supports(.default), identifier: "default") { choose(nil) }
                            ForEach(options.selectableVoices, id: \.voiceID) { voice in
                                voiceRow(voice.name, selected: model.activeVoicePreference.selectedVoiceID == voice.voiceID,
                                         enabled: true, identifier: voice.voiceID) { choose(voice.voiceID) }
                            }
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
                        Button { Task { await refresh() } } label: {
                            Label(text("refresh"), systemImage: "arrow.clockwise").frame(minHeight: 44)
                        }
                        .disabled(model.activeVoicePreference.refreshing)
                        .accessibilityIdentifier("session-voice-refresh")
                    }.padding(16)
                }
                .frame(idealWidth: 340, maxHeight: 500)
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
    private func voiceRow(_ title: String, selected: Bool, enabled: Bool, identifier: String,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).fixedSize(horizontal: false, vertical: true)
                Spacer()
                if selected { Image(systemName: "checkmark") }
            }.frame(minHeight: 44).contentShape(Rectangle())
        }
        .disabled(!current || !enabled || model.activeVoicePreference.refreshing)
        .accessibilityValue(selected ? text("selected") : "")
        .accessibilityIdentifier("session-voice-" + identifier)
    }
}
