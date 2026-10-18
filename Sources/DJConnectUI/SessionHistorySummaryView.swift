import SwiftUI
import DJConnectCore

/// Owner-only history UI. This is never a passive/shared surface projection.
struct SessionHistorySummaryView: View {
    let summary: DJConnectSessionHistorySummary
    let language: String
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 6) {
            ForEach(SessionHistorySummaryPresentation.lines(summary, language: language), id: \.self) { line in
                Text(line).fixedSize(horizontal: false, vertical: true)
            }
            if !compact {
                Text(DJConnectLocalization.localized(key: "ui.session.summary.scope", language: language))
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(compact ? .caption : .callout)
        .foregroundStyle(.white.opacity(0.82))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("session-history-summary-metrics")
    }
}

enum SessionHistorySummaryPresentation {
    static func lines(_ summary: DJConnectSessionHistorySummary, language: String) -> [String] {
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
        result.append(text("mood") + ": " + mood)
        result.append(text(summary.state))
        return result
    }
}
