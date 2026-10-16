import SwiftUI
import DJConnectCore

/// The existing device autoplay preference, shared by the complete Voice menu
/// and the selectively installable autoplay-only menu. Opening it never starts audio.
struct SessionVoiceAutoplayControl: View {
    @ObservedObject var model: DJConnectAppModel
    var body: some View {
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
    }
}

/// Selective installation boundary: only the already working autoplay preference.
/// Concrete provider selection stays out until prepare/audio integration is qualified.
struct ActiveSessionAutoplayToolbar: View {
    @ObservedObject var model: DJConnectAppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showing = false
    private var title: String { DJConnectLocalization.localized(key: "ui.session.voice.title", language: model.language) }
    var body: some View {
        Button { showing = true } label: { Label(title, systemImage: "speaker.wave.2") }
            .foregroundStyle(.white)
            .accessibilityIdentifier("session-voice-toggle")
            .popover(isPresented: $showing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                        SessionVoiceAutoplayControl(model: model)
                    }.padding(16)
                }
                .frame(width: 340, height: 180)
                .presentationBackground(.ultraThinMaterial)
                .presentationCompactAdaptation(.popover)
            }
            .onChange(of: model.activeDJSession?.id) { showing = false }
            .onChange(of: scenePhase) { _, phase in if phase != .active { showing = false } }
    }
}
