import SwiftUI
import DJConnectCore

/// Status/timestamp whitelist shared by the existing widget and Activity. No
/// cache lookup, artwork, source text or session palette is used by this view.
public struct DJConnectSessionPlaybackObservationView: View {
    let observation: DJConnectSessionPlaybackObservation
    var compact = false
    var showsHeader = true
    private let language: String
    public init(observation: DJConnectSessionPlaybackObservation, compact: Bool = false,
                showsHeader: Bool = true, language: String = DJConnectLocalization.defaultDisplayLanguageCode()) {
        self.observation = observation; self.compact = compact
        self.showsHeader = showsHeader; self.language = language
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
    public var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 12) {
            if showsHeader {
                HStack(spacing: 10) {
                    DJPersonaAvatarView(confirmedMood: DJConnectSessionMoodTheme.brand.rawValue, language: language)
                        .frame(width: compact ? 32 : 48, height: compact ? 32 : 48)
                    if !compact { Text(text("ui.session.title")).font(.headline) }
                }
            }
            Label(text("surface.playback.observed." + observation.playbackState.rawValue),
                  systemImage: observation.playbackState.symbolName)
                .font(compact ? .headline : .title3.weight(.semibold))
                .lineLimit(2).minimumScaleFactor(0.75)
            VStack(alignment: .leading, spacing: 3) {
                Text(text("surface.playback.last.observed"))
                Text(observation.observedAt, style: .time)
            }
            .font(compact ? .caption2 : .caption).foregroundStyle(.white.opacity(0.8))
        }
        .foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}


/// Smart Stack presentation of the same whitelisted observation, never a new
/// Session/Activity variant. The playstate glyph is an observation, not a control.
public struct DJConnectSessionWatchObservationView: View {
    private let observation: DJConnectSessionPlaybackObservation
    private let language: String
    public init(observation: DJConnectSessionPlaybackObservation,
                language: String = DJConnectLocalization.defaultDisplayLanguageCode()) {
        self.observation = observation; self.language = language
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
    public var body: some View {
        HStack(spacing: 8) {
            DJPersonaAvatarView(confirmedMood: DJConnectSessionMoodTheme.brand.rawValue, language: language)
                .frame(width: 28, height: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(text("ui.session.title")).font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                Label(text("surface.playback.observed." + observation.playbackState.rawValue),
                      systemImage: observation.playbackState.symbolName)
                    .font(.caption.weight(.semibold)).lineLimit(2).minimumScaleFactor(0.8)
                HStack(spacing: 3) {
                    Text(text("surface.playback.last.observed"))
                    Text(observation.observedAt, style: .time)
                }
                .font(.caption2).foregroundStyle(.white.opacity(0.75))
                .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }
}
