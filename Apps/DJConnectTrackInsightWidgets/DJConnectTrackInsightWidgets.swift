import SwiftUI
import WidgetKit
import DJConnectCore
#if os(iOS) && canImport(ActivityKit)
import ActivityKit
#endif

private let sessionURL = URL(string: "djconnect://dj-session")!
private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key) }

struct DJConnectSessionWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: DJConnectSessionSurfaceSnapshot?
    var isActive: Bool { snapshot?.isCurrent(at: date) == true }
}

struct DJConnectSessionWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DJConnectSessionWidgetEntry {
        .init(date: Date(), snapshot: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (DJConnectSessionWidgetEntry) -> Void) {
        completion(current())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DJConnectSessionWidgetEntry>) -> Void) {
        let entry = current()
        var entries = [entry]
        if let expiry = entry.snapshot?.expiresAt {
            // Remove active status at the original deadline even when the app
            // is suspended; no network request and no renewed local lease.
            entries.append(.init(date: expiry, snapshot: nil))
        }
        completion(Timeline(entries: entries, policy: .after(Date().addingTimeInterval(15 * 60))))
    }
    private func current() -> DJConnectSessionWidgetEntry {
        let now = Date()
        let snapshot = UserDefaults(suiteName: DJConnectLocalization.appGroupIdentifier)
            .flatMap { DJConnectSessionSurfaceSnapshot.load(from: $0, at: now) }
        return .init(date: now, snapshot: snapshot)
    }
}

/// One rendering model for every configured size and all migrated kinds.
/// Rich content is intentionally absent until passive-surface grants exist.
struct DJConnectSessionSurfaceView: View {
    let isActive: Bool
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            HStack(spacing: 10) {
                Image(systemName: "opticaldisc")
                    .font(compact ? .title2 : .largeTitle)
                    .foregroundStyle(.white)
                    .padding(compact ? 8 : 12)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                if !compact {
                    Text(text("ui.session.title")).font(.headline)
                }
            }
            Text(text(isActive ? "surface.session.active" : "surface.session.open"))
                .font(.headline).lineLimit(3).minimumScaleFactor(0.8)
            if !compact {
                Text(text("surface.session.open.app"))
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8)).lineLimit(2)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct DJConnectSessionWidgetView: View {
    let entry: DJConnectSessionWidgetEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        DJConnectSessionSurfaceView(isActive: entry.isActive, compact: family == .systemSmall)
            .containerBackground(for: .widget) {
                LinearGradient(colors: [Color(red: 0.08, green: 0.17, blue: 0.40),
                                        Color(red: 0.24, green: 0.06, blue: 0.39)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .widgetURL(sessionURL)
    }
}

@MainActor
private func sessionConfiguration(kind: String) -> some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: DJConnectSessionWidgetProvider()) {
        DJConnectSessionWidgetView(entry: $0)
    }
    .configurationDisplayName(text("ui.session.title"))
    .description(text("surface.session.description"))
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
}

struct DJConnectSessionWidget: Widget {
    var body: some WidgetConfiguration { sessionConfiguration(kind: DJConnectSessionSurfaceSnapshot.widgetKind) }
}
// Preserve configured identifiers. These are migration aliases of the same
// provider/view, never independent Queue/Insight/chat data pipelines.
struct DJConnectNowPlayingWidget: Widget {
    var body: some WidgetConfiguration { sessionConfiguration(kind: "DJConnectNowPlayingWidget") }
}
struct DJConnectQueueWidget: Widget {
    var body: some WidgetConfiguration { sessionConfiguration(kind: "DJConnectQueueWidget") }
}
struct DJConnectTrackInsightWidget: Widget {
    var body: some WidgetConfiguration { sessionConfiguration(kind: "DJConnectTrackInsightWidget") }
}
struct DJConnectAskDJWidget: Widget {
    var body: some WidgetConfiguration { sessionConfiguration(kind: "DJConnectAskDJWidget") }
}

#if os(iOS) && canImport(ActivityKit)
struct DJConnectSessionActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DJConnectSessionLiveActivityAttributes.self) { context in
            DJConnectSessionSurfaceView(isActive: !context.isStale)
                .padding(16)
                .activityBackgroundTint(Color(red: 0.11, green: 0.10, blue: 0.30))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(sessionURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: "opticaldisc").foregroundStyle(.white) }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(text(context.isStale ? "surface.session.open" : "surface.session.active"))
                        .font(.headline).foregroundStyle(.white)
                }
            } compactLeading: {
                Image(systemName: "opticaldisc").foregroundStyle(.white)
            } compactTrailing: {
                Image(systemName: context.isStale ? "arrow.up.forward" : "music.note").foregroundStyle(.white)
            } minimal: {
                Image(systemName: "opticaldisc").foregroundStyle(.white)
            }
            .widgetURL(sessionURL)
            .keylineTint(.purple)
        }
    }
}
#endif

@main
struct DJConnectTrackInsightWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DJConnectSessionWidget()
        DJConnectNowPlayingWidget()
        DJConnectQueueWidget()
        DJConnectTrackInsightWidget()
        DJConnectAskDJWidget()
        #if os(iOS) && canImport(ActivityKit)
        DJConnectSessionActivityWidget()
        #endif
    }
}
