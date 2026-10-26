// Compile/render preparation only. No @main, Activity request or shipping bundle entry.
import Foundation
import SwiftUI
import DJConnectCore

enum StatusOnlyLanguage: String, CaseIterable {
    case nl, en, de, fr, es
    var heading: String {
        switch self { case .nl: "Laatst waargenomen"; case .en: "Last observed"; case .de: "Zuletzt beobachtet"
        case .fr: "Dernière observation"; case .es: "Última observación" }
    }
    func label(_ state: StatusOnlyCandidate.Playback) -> String {
        switch (self, state) {
        case (.nl, .playing): "Speelde af"; case (.en, .playing): "Was playing"; case (.de, .playing): "Wurde abgespielt"
        case (.fr, .playing): "Lecture observée"; case (.es, .playing): "Reproduciendo al observar"
        case (.nl, .paused): "Gepauzeerd"; case (.en, .paused): "Paused"; case (.de, .paused): "Pausiert"
        case (.fr, .paused): "En pause"; case (.es, .paused): "En pausa"
        case (.nl, .stopped): "Gestopt"; case (.en, .stopped): "Stopped"; case (.de, .stopped): "Gestoppt"
        case (.fr, .stopped): "Arrêtée"; case (.es, .stopped): "Detenido"
        case (.nl, .unknown): "Onbekend"; case (.en, .unknown): "Unknown"; case (.de, .unknown): "Unbekannt"
        case (.fr, .unknown): "Inconnu"; case (.es, .unknown): "Desconocido"
        }
    }
    func timestamp(_ originalMS: Int64, zone: TimeZone, compact: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: rawValue)
        formatter.timeZone = zone
        formatter.setLocalizedDateFormatFromTemplate(compact ? "MMddHHmm" : "yMMMdHHmm")
        return formatter.string(from: Date(timeIntervalSince1970: Double(originalMS) / 1000))
    } // Original observation formatting only. Never Date.now/arrival/expiry authority.
}

private func statusSymbol(_ state: StatusOnlyCandidate.Playback?) -> String {
    switch state { case .playing: "play.fill"; case .paused: "pause.fill"; case .stopped: "stop.fill"
    case .unknown: "questionmark"; case nil: "clock" }
}

struct StatusOnlyCandidateBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.07, green: 0.16, blue: 0.36), Color(red: 0.25, green: 0.07, blue: 0.35)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Canvas { context, size in
                    for line in 0..<8 {
                        var path = Path()
                        for step in 0...80 {
                            let x = size.width * CGFloat(step) / 80
                            let y = size.height * 0.5 + CGFloat(line) * 7 + CGFloat(sin(Double(step) * 0.12 + Double(line) * 0.2)) * 12
                            if step == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        context.stroke(path, with: .color(.cyan.opacity(0.10)), lineWidth: 0.8)
                    }
                }
            }
    } // Static brand-only VibeScape drawing, no timeline, animation or personal theme.
}

struct StatusOnlyLastObservedView: View {
    let value: StatusOnlyDisplayValue
    let language: StatusOnlyLanguage
    let zone: TimeZone
    init(state: StatusOnlyActivityState, language: StatusOnlyLanguage, zone: TimeZone) {
        value = .init(activity: state); self.language = language; self.zone = zone
    }
    init(observation: StatusOnlyWidgetResponse.Observation, language: StatusOnlyLanguage, zone: TimeZone) {
        value = .init(observation: observation); self.language = language; self.zone = zone
    }
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: statusSymbol(value.playback)).font(.title2).frame(width: 34)
            VStack(alignment: .leading, spacing: 7) {
                Text(language.heading).font(.caption.weight(.medium)).opacity(0.8)
                if let playback = value.playback {
                    Text(language.label(playback)).font(.title3.weight(.semibold)).lineLimit(2)
                } else {
                    Text("—").font(.title3) // Neutral ended shape, never unknown-as-authority-fallback.
                }
                Text(language.timestamp(value.originalObservedMS, zone: zone)).font(.caption).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.65)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white).padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background { StatusOnlyCandidateBackground() }
    }
}

#if os(iOS)
import WidgetKit
import ActivityKit

struct CandidatePlaybackStatusActivityWidget: Widget {
    private var language: StatusOnlyLanguage {
        StatusOnlyLanguage(rawValue: DJConnectLocalization.defaultDisplayLanguageCode()) ?? .en
    }
    private func matches(_ context: ActivityViewContext<DJConnectRemotePlaybackStatusActivityAttributesV1>) -> Bool {
        context.state.presentation_id == context.attributes.presentation_id &&
            context.state.presentation_generation == context.attributes.presentation_generation
    } // Data identity only; not admission, ordering, currentness or retention consent.
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DJConnectRemotePlaybackStatusActivityAttributesV1.self) { context in
            if matches(context) {
                StatusOnlyLastObservedView(state: context.state, language: language, zone: .current)
                    .activityBackgroundTint(.clear).activitySystemActionForegroundColor(.white)
            } else { Image(systemName: "clock").foregroundStyle(.white) }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    if matches(context) {
                        StatusOnlyLastObservedView(state: context.state, language: language, zone: .current)
                    } else { Image(systemName: "clock") }
                }
            } compactLeading: {
                Image(systemName: matches(context) ? statusSymbol(context.state.playback_state) : "clock")
            } compactTrailing: {
                if matches(context) {
                    Text(language.timestamp(context.state.observed_at_unix_ms, zone: .current, compact: true))
                        .font(.caption2).lineLimit(1).minimumScaleFactor(0.6)
                } else { Image(systemName: "clock") }
            } minimal: {
                Image(systemName: "clock") // No visible timestamp fits: neutral, not an apparent live playstate.
            }
            .keylineTint(.purple)
        }
    }
}
#endif
