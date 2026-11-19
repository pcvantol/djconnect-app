import SwiftUI
import DJConnectCore

/// Owner-only history UI. This is never a passive/shared surface projection.
struct SessionHistorySummaryView: View {
    let summary: DJConnectSessionHistorySummary
    let language: String
    var compact = false
    var showsMood = true
    private var moodIcon: String? {
        guard summary.mood.coverage == "complete", let value = summary.mood.value,
              let index = ["chill", "groove", "energy", "party"].firstIndex(of: value) else { return nil }
        return askDJMoodIcon(for: index)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 6) {
            ForEach(Array(SessionHistorySummaryPresentation.lines(summary, language: language, includesMood: showsMood).enumerated()), id: \.offset) { index, line in
                HStack(spacing: 5) {
                    Text(line).fixedSize(horizontal: false, vertical: true)
                    if showsMood, index == (summary.momentsRetained == nil ? 2 : 3), let moodIcon {
                        Image(systemName: moodIcon)
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .font(compact ? .caption : .callout)
        .foregroundStyle(.white.opacity(0.82))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("session-history-summary-metrics")
    }
}

enum SessionHistorySummaryPresentation {
    static func lines(_ summary: DJConnectSessionHistorySummary, language: String, includesMood: Bool = true) -> [String] {
        func text(_ suffix: String) -> String {
            DJConnectLocalization.localized(key: "ui.session.summary." + suffix, language: language)
        }
        func count(_ metric: DJConnectSessionHistorySummary.Metric<Int>) -> String {
            switch metric.coverage {
            case "withdrawn": return text("withdrawn")
            case "unknown": return text("unknown")
            default:
                guard let value = metric.value else { return text("unknown") }
                let formatter = NumberFormatter(); formatter.locale = Locale(identifier: language); formatter.numberStyle = .decimal
                let number = formatter.string(from: NSNumber(value: value)) ?? String(value)
                return metric.coverage == "partial" ? number + " · " + text("partial") : number
            }
        }
        var result = [text("tracks") + ": " + count(summary.tracksObserved),
                      text("moments") + ": " + count(summary.momentsPublished)]
        if let retained = summary.momentsRetained { result.append(text("retained") + ": " + count(retained)) }
        let mood: String
        if summary.mood.coverage == "withdrawn" { mood = text("withdrawn") }
        else if let value = summary.mood.value {
            mood = value == "mixed" ? text("mixed") : DJConnectLocalization.localized(key: "ui.session.mood." + value, language: language)
        } else { mood = text("unknown") }
        if includesMood { result.append(text("mood") + ": " + mood) }
        if summary.state == "provisional" { result.append(text("provisional")) }
        return result
    }
}
