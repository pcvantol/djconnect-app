import DJConnectCore
import SwiftUI
import WidgetKit

private struct SessionEntry: TimelineEntry {
    let date: Date
    let destination: DJConnectWatchStackEntry.Destination?
}
private struct SessionProvider: TimelineProvider {
    func placeholder(in context: Context) -> SessionEntry { .init(date: Date(), destination: nil) }
    func getSnapshot(in context: Context, completion: @escaping (SessionEntry) -> Void) {
        let now = Date()
        completion(.init(date: now, destination: confirmedEntry(at: now)?.destination))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionEntry>) -> Void) {
        let now = Date()
        let confirmed = confirmedEntry(at: now)
        var entries = [SessionEntry(date: now, destination: confirmed?.destination)]
        if let confirmed {
            entries.append(.init(date: confirmed.expiresAt, destination: nil))
        }
        let refresh = confirmed?.expiresAt ?? now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
    private func confirmedEntry(at now: Date) -> DJConnectWatchStackEntry? {
        UserDefaults(suiteName: DJConnectLocalization.appGroupIdentifier)
            .flatMap { DJConnectWatchStackEntry.load(from: $0, at: now) }
    }
}
private struct SessionComplicationView: View {
    let entry: SessionEntry
    @Environment(\.widgetFamily) private var family
    private var title: String {
        entry.destination == .askDJ ? DJConnectLocalization.localized(key: "watch.v2.widget.ask_dj") : "DJConnect"
    }
    private var subtitle: String {
        let key = switch entry.destination {
        case .session: "watch.v2.widget.open_session"
        case .askDJ: "ui.askdj.help.catalogue.title"
        case nil: "widget.open.djconnect"
        }
        return DJConnectLocalization.localized(key: key)
    }
    private var icon: String {
        switch entry.destination {
        case .session: "opticaldisc"
        case .askDJ: "bubble.left"
        case nil: "waveform"
        }
    }
    var body: some View {
        Group {
            if family == .accessoryRectangular {
                HStack(spacing: 6) {
                    Image("BrandHeadset")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title).font(.headline)
                        Text(subtitle).font(.caption2)
                    }
                    .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
            } else if family == .accessoryInline {
                Label(entry.destination == .session ? subtitle : title, systemImage: icon)
            } else {
                Image(systemName: icon).accessibilityLabel(entry.destination == .session ? subtitle : title)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        // The app confirms the current destination again; this URL carries no Session authority.
        .widgetURL(entry.destination?.url ?? URL(string: "djconnect://"))
    }
}
@MainActor
private func configuration(_ kind: String) -> some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SessionProvider()) { SessionComplicationView(entry: $0) }
        .configurationDisplayName("DJConnect")
        .description(DJConnectLocalization.localized(key: "surface.session.description"))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
}
// Legacy identifiers are migration aliases, all backed by one Session provider.
struct DJConnectComplicationWidget: Widget {
    var body: some WidgetConfiguration { configuration("DJConnectComplication") }
}
struct DJConnectNowPlayingComplicationWidget: Widget {
    var body: some WidgetConfiguration { configuration("DJConnectNowPlayingComplication") }
}
struct DJConnectQueueComplicationWidget: Widget {
    var body: some WidgetConfiguration { configuration("DJConnectQueueComplication") }
}
struct DJConnectPlaylistsComplicationWidget: Widget {
    var body: some WidgetConfiguration { configuration("DJConnectPlaylistsComplication") }
}
struct DJConnectTrackInsightComplicationWidget: Widget {
    var body: some WidgetConfiguration { configuration("DJConnectTrackInsightComplication") }
}
struct DJConnectAskDJComplicationWidget: Widget {
    var body: some WidgetConfiguration { configuration("DJConnectAskDJComplication") }
}
@main
struct DJConnectWatchComplicationsBundle: WidgetBundle {
    var body: some Widget {
        DJConnectComplicationWidget()
        DJConnectNowPlayingComplicationWidget()
        DJConnectQueueComplicationWidget()
        DJConnectPlaylistsComplicationWidget()
        DJConnectTrackInsightComplicationWidget()
        DJConnectAskDJComplicationWidget()
    }
}
