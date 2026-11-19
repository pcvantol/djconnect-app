import SwiftUI
import DJConnectCore

/// The existing device autoplay preference, shared by the complete Voice menu
/// and the current DJ voice menu. Opening it never starts audio.
struct SessionVoiceAutoplayControl: View {
    @ObservedObject var model: DJConnectAppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            SpeechPreferenceRow(label: DJConnectLocalization.localized(key: "ui.auto.play.dj.answers", language: model.language)) {
                Toggle(DJConnectLocalization.localized(key: "ui.auto.play.dj.answers", language: model.language),
                       isOn: $model.localResponseAudioEnabled)
                    .accessibilityIdentifier("session-voice-autoplay")
            }
            Text(DJConnectLocalization.localized(key: "ui.play.dj.answer.audio.as.soon.as.it.arrives", language: model.language))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .toggleStyle(SwitchToggleStyle(tint: DJConnectGlassAppearance.toggleTint))
        .frame(minHeight: 44)
    }
}
