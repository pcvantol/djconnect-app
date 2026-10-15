import SwiftUI
import WidgetKit
import DJConnectCore
#if os(iOS) && canImport(ActivityKit)
import ActivityKit
#endif

private let sessionURL = URL(string: "djconnect://dj-session")!
private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key) }

private extension DJConnectSessionMoodTheme {
    var colors: [Color] {
        colorValues.map { value in
            Color(red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
        }
    }
    var accent: Color { colors[1] }
    var darkTint: Color {
        let value = colorValues[0]
        return Color(red: Double((value >> 16) & 255) / 255 * 0.22,
                     green: Double((value >> 8) & 255) / 255 * 0.22,
                     blue: Double(value & 255) / 255 * 0.22)
    }
}
private struct SessionMoodBackground: View {
    let theme: DJConnectSessionMoodTheme
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.12)
            LinearGradient(colors: theme.colors.map { $0.opacity(0.34) },
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct DJConnectSessionWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: DJConnectSessionSurfaceSnapshot?
    var isActive: Bool { snapshot?.isCurrent(at: date) == true }
    var theme: DJConnectSessionMoodTheme { snapshot?.renderingTheme(at: date) ?? .brand }
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
    var theme: DJConnectSessionMoodTheme = .brand
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            HStack(spacing: 10) {
                Image(systemName: "opticaldisc")
                    .font(compact ? .title2 : .largeTitle)
                    .foregroundStyle(theme.accent)
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
        DJConnectSessionSurfaceView(isActive: entry.isActive, compact: family == .systemSmall, theme: entry.theme)
            .containerBackground(for: .widget) {
                SessionMoodBackground(theme: entry.theme)
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
            DJConnectSessionSurfaceView(isActive: !context.isStale, theme: context.isStale ? .brand : (context.state.theme ?? .brand))
                .padding(16)
                .background { SessionMoodBackground(theme: context.isStale ? .brand : (context.state.theme ?? .brand)) }
                .activityBackgroundTint((context.isStale ? DJConnectSessionMoodTheme.brand : (context.state.theme ?? .brand)).darkTint)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(sessionURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: "opticaldisc").foregroundStyle((context.isStale ? DJConnectSessionMoodTheme.brand : (context.state.theme ?? .brand)).accent) }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(text(context.isStale ? "surface.session.open" : "surface.session.active"))
                        .font(.headline).foregroundStyle(.white)
                }
            } compactLeading: {
                Image(systemName: "opticaldisc").foregroundStyle((context.isStale ? DJConnectSessionMoodTheme.brand : (context.state.theme ?? .brand)).accent)
            } compactTrailing: {
                Image(systemName: context.isStale ? "arrow.up.forward" : "music.note").foregroundStyle(.white)
            } minimal: {
                Image(systemName: "opticaldisc").foregroundStyle((context.isStale ? DJConnectSessionMoodTheme.brand : (context.state.theme ?? .brand)).accent)
            }
            .widgetURL(sessionURL)
            .keylineTint((context.isStale ? DJConnectSessionMoodTheme.brand : (context.state.theme ?? .brand)).accent)
        }
    }
}
#endif

// MARK: - Rich presentation preparation
// Pure presentation only: not Codable, not a wire contract, no cache/network
// reads and no production caller. Connect only after Core qualifies passive
// content, artwork and locked-display lifetime/revocation rights.
enum SessionMomentLayoutSize { case small, medium, large, activity, island }

struct SessionMomentLayout<Artwork: View>: View {
    typealias Size = SessionMomentLayoutSize
    let size: Size
    let moment: String
    let track: String
    let artist: String
    let album: String
    let attribution: String
    @ViewBuilder let artwork: () -> Artwork

    private var isSmall: Bool { size == .small }
    private var isLarge: Bool { size == .large }

    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 8 : 12) {
            if isSmall {
                artworkTile(side: 46)
                contribution(lines: 3)
            } else {
                HStack(alignment: .top, spacing: 14) {
                    artworkTile(side: isLarge ? 88 : (size == .island ? 40 : 64))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(text("ui.session.title"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                        if isLarge {
                            Text(track).font(.headline).lineLimit(2)
                            Text(artist).font(.subheadline).lineLimit(1)
                            Text(album).font(.caption).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                        } else {
                            contribution(lines: size == .medium ? 2 : 3)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if isLarge { contribution(lines: 5) }
                if size == .medium {
                    Text([track, artist, album].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                }
            }
            if !attribution.isEmpty {
                Text(attribution)
                    .font(.caption2).foregroundStyle(.white.opacity(0.65))
                    .lineLimit(isLarge ? 2 : 1)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    private func contribution(lines: Int) -> some View {
        Text(moment).font(isSmall ? .subheadline.weight(.medium) : .headline)
            .lineLimit(lines).multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func artworkTile(side: CGFloat) -> some View {
        artwork()
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: side * 0.22, style: .continuous))
            .accessibilityHidden(true)
    }
}

#if DEBUG
// Synthetic visual fixtures only. Never serialized into App Group/ActivityKit.
private struct SessionMomentLayoutPreview: View {
    let size: SessionMomentLayoutSize
    let theme: DJConnectSessionMoodTheme
    var body: some View {
        SessionMomentLayout(size: size, moment: "Een warme baslijn geeft dit nummer ruimte om te ademen.",
                            track: "Nachtlicht", artist: "Voorbeeldartiest", album: "Onderweg",
                            attribution: "Voorbeeldbijdrage · geen live sessie") {
            ZStack {
                LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "opticaldisc").font(.system(size: 34)).foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(16)
        .background { SessionMoodBackground(theme: theme) }
    }
}

#Preview("Small · Chill") {
    SessionMomentLayoutPreview(size: .small, theme: .chill).frame(width: 170, height: 170)
}
#Preview("Medium · Groove") {
    SessionMomentLayoutPreview(size: .medium, theme: .groove).frame(width: 360, height: 170)
}
#Preview("Large · Party") {
    SessionMomentLayoutPreview(size: .large, theme: .party).frame(width: 360, height: 360)
}
#Preview("Live Activity · Energy") {
    SessionMomentLayoutPreview(size: .activity, theme: .energy).frame(width: 380, height: 170)
}
#Preview("Expanded Island · Brand") {
    SessionMomentLayoutPreview(size: .island, theme: .brand).frame(width: 340, height: 150)
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
