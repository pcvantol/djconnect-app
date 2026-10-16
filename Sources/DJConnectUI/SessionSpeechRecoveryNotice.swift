import SwiftUI
import DJConnectCore

/// Presentation only. The speech owner must supply current authority/backoff
/// eligibility and a reference-bound retry action after producer qualification.
/// This view never selects a provider, requests audio or repeats an Ask DJ turn.
struct SessionSpeechRecoveryNotice: View {
    enum State { case unavailable, checking, backoff }

    let language: String
    let state: State
    let retryAllowed: Bool
    let retry: (() -> Void)?
    @State private var showsInstructions = false

    private func text(_ suffix: String) -> String {
        DJConnectLocalization.localized(key: "ui.session.speech.recovery." + suffix, language: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(text("title"), systemImage: "speaker.slash")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(text("retained"))
                .fixedSize(horizontal: false, vertical: true)
            DisclosureGroup(isExpanded: $showsInstructions) {
                Text(text("body"))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            } label: {
                Text(text("help"))
            }
            .accessibilityIdentifier("session-speech-recovery-help")

            if state == .checking {
                Label(text("checking"), systemImage: "arrow.triangle.2.circlepath")
                    .fixedSize(horizontal: false, vertical: true)
            } else if state == .backoff {
                Text(text("retry_later"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let retry {
                Button(action: retry) {
                    Label(text("retry"), systemImage: "speaker.wave.2")
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 44)
                }
                .disabled(!retryAllowed || state != .unavailable)
                .accessibilityIdentifier("session-speech-recovery-retry")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .djSessionFrostedSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("session-speech-recovery-notice")
    }
}
