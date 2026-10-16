import SwiftUI
import DJConnectCore

/// Same segmented glass surface and selected styling as Mood; current qualified values only.
struct SessionVoiceGenderSelector: View {
    let language: String
    let values: [DJConnectVoicePreference]
    let selected: DJConnectVoicePreference
    let enabled: Bool
    let onSelect: (DJConnectVoicePreference) -> Void
    private var choices: [DJConnectVoicePreference] { [.male, .female].filter(values.contains) }
    private func text(_ suffix: String) -> String {
        DJConnectLocalization.localized(key: "ui.session.voice." + suffix, language: language)
    }
    var body: some View {
        if !choices.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(text("gender")).font(.headline)
                HStack(spacing: 4) {
                    ForEach(choices, id: \.self) { preference in
                        Button { guard enabled else { return }; onSelect(preference) } label: {
                            Text(text(preference.rawValue)).font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .djConnectButtonStyle(DJConnectButtonStyle(
                            emphasis: preference == selected ? .selected : .secondary,
                            shape: .segmented, expands: true, usesLiveGlass: false))
                        .disabled(!enabled)
                        .accessibilityAddTraits(preference == selected ? .isSelected : [])
                        .accessibilityIdentifier("session-voice-gender-" + preference.rawValue)
                    }
                }
                .padding(DJConnectCardAppearance.segmentedContentInset)
                .djSessionFrostedSurface(cornerRadius: 32)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("session-voice-gender")
        }
    }
}
