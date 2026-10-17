import DJConnectCore
import SwiftUI
import WidgetKit

private struct SessionEntry: TimelineEntry {
    let date: Date
    let snapshot: DJConnectSessionSurfaceSnapshot?
}
private struct SessionProvider: TimelineProvider {
    func placeholder(in context: Context) -> SessionEntry { .init(date: Date(), snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (SessionEntry) -> Void) { completion(current()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionEntry>) -> Void) {
        let entry = current()
        var entries = [entry]
        if let expiry = entry.snapshot?.expiresAt { entries.append(.init(date: expiry, snapshot: nil)) }
        completion(Timeline(entries: entries, policy: .after(Date().addingTimeInterval(15 * 60))))
    }
    private func current() -> SessionEntry {
        let now = Date()
        // Watch has a separate App Group container. No phone payload is copied
        // implicitly. Without an admitted Watch Session producer this is neutral.
        let snapshot = UserDefaults(suiteName: DJConnectLocalization.appGroupIdentifier)
            .flatMap { DJConnectSessionSurfaceSnapshot.load(from: $0, at: now) }
        return .init(date: now, snapshot: snapshot)
    }
}
private struct SessionComplicationView: View {
    let entry: SessionEntry
    @Environment(\.widgetFamily) private var family
    private var title: String {
        DJConnectLocalization.localized(key: entry.snapshot?.isCurrent(at: entry.date) == true
                                        ? "surface.session.active" : "widget.open.djconnect")
    }
    private var accent: Color {
        let theme = entry.snapshot?.renderingTheme(at: entry.date) ?? .brand
        let value = theme.colorValues[1]
        return Color(red: Double((value >> 16) & 255) / 255,
                     green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
    var body: some View {
        Group {
            if family == .accessoryRectangular {
                Label(title, systemImage: "opticaldisc").font(.headline).lineLimit(2)
            } else if family == .accessoryInline {
                Label(title, systemImage: "opticaldisc")
            } else {
                Image(systemName: "opticaldisc").accessibilityLabel(title)
            }
        }
        .tint(accent)
        .containerBackground(.fill.tertiary, for: .widget)
        // Neutral launch, no fabricated native Watch Session route or mutation.
        .widgetURL(URL(string: "djconnect://"))
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
