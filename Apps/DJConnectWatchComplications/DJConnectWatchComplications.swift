import DJConnectCore
import SwiftUI
import WidgetKit

private let appGroupIdentifier = "group.dev.djconnect"
private let accentBlue = Color(red: 0.16, green: 0.56, blue: 1.0)
private let accentPurple = Color(red: 0.84, green: 0.18, blue: 1.0)

private func localizedKey(_ key: String, arguments: CVarArg...) -> String {
    DJConnectLocalization.localized(key: key, arguments: arguments)
}

private func defaults() -> UserDefaults? {
    UserDefaults(suiteName: appGroupIdentifier)
}

private func loadSnapshot<T: Decodable>(_ type: T.Type, key: String) -> T? {
    guard let data = defaults()?.data(forKey: key) else {
        return nil
    }
    return try? JSONDecoder().decode(T.self, from: data)
}

private func percent(_ value: Double?) -> String? {
    value.map { "\(Int(($0 * 100).rounded()))%" }
}

private struct NowPlayingSnapshot: Decodable {
    static let key = "DJConnectNowPlayingWidgetSnapshot"

    var updatedAt: Date
    var title: String
    var artist: String
    var progressMS: Int?
    var durationMS: Int?
    var isPlaying: Bool
    var deviceName: String?

    var progress: Double {
        guard let progressMS, let durationMS, durationMS > 0 else {
            return 0
        }
        return min(1, max(0, Double(progressMS) / Double(durationMS)))
    }
}

private struct QueueSnapshot: Decodable {
    static let key = "DJConnectQueueWidgetSnapshot"

    var updatedAt: Date
    var items: [QueueItem]
    var totalCount: Int
}

private struct QueueItem: Decodable, Identifiable {
    var id: String
    var title: String
    var artist: String?
}

private struct PlaylistsSnapshot: Decodable {
    static let key = "DJConnectPlaylistsWidgetSnapshot"

    var updatedAt: Date
    var items: [PlaylistItem]
    var totalCount: Int
}

private struct PlaylistItem: Decodable, Identifiable {
    var id: String
    var name: String
    var subtitle: String?
}

private struct TrackInsightSnapshot: Decodable {
    static let key = "DJConnectTrackInsightWidgetSnapshot"

    var updatedAt: Date
    var title: String
    var artist: String
    var genre: String?
    var mood: String?
    var energy: Double?
    var progress: Double?
    var duration: Double?
}

private struct AskDJSnapshot: Decodable {
    static let key = "DJConnectAskDJWidgetSnapshot"

    var updatedAt: Date
    var prompt: String
    var response: String
    var context: String
    var trackTitle: String?
    var artist: String?
}

private struct ComplicationEntry<Value>: TimelineEntry {
    let date: Date
    let value: Value?
}

private struct SnapshotProvider<Value: Decodable>: TimelineProvider {
    let key: String
    let placeholderValue: Value

    func placeholder(in context: Context) -> ComplicationEntry<Value> {
        ComplicationEntry(date: Date(), value: placeholderValue)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry<Value>) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry<Value>>) -> Void) {
        let entry = currentEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func currentEntry() -> ComplicationEntry<Value> {
        let snapshot = loadSnapshot(Value.self, key: key)
        return ComplicationEntry(date: Date(), value: snapshot)
    }
}

private struct DJConnectLauncherEntry: TimelineEntry {
    let date: Date
}

private struct DJConnectLauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> DJConnectLauncherEntry {
        DJConnectLauncherEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (DJConnectLauncherEntry) -> Void) {
        completion(DJConnectLauncherEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DJConnectLauncherEntry>) -> Void) {
        completion(Timeline(entries: [DJConnectLauncherEntry(date: Date())], policy: .after(Date().addingTimeInterval(3_600))))
    }
}

private struct ComplicationShell<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct DJConnectLauncherView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        ComplicationShell {
            switch family {
            case .accessoryRectangular:
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("DJConnect").font(.headline)
                        Text(localizedKey("watch.complication.open.music.control"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "music.note.house.fill")
                }
            case .accessoryInline:
                Label("DJConnect", systemImage: "music.note.house.fill")
            case .accessoryCorner:
                Image(systemName: "music.note.house.fill")
                    .widgetLabel { Text("DJConnect") }
            default:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .widgetAccentable()
                }
            }
        }
    }
}

private struct NowPlayingComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ComplicationEntry<NowPlayingSnapshot>

    private var snapshot: NowPlayingSnapshot? { entry.value }
    private var title: String { snapshot?.title.isEmpty == false ? snapshot!.title : localizedKey("watch.complication.nothing.playing") }
    private var artist: String { snapshot?.artist.isEmpty == false ? snapshot!.artist : "DJConnect" }
    private var isPlaying: Bool { snapshot?.isPlaying == true }

    var body: some View {
        ComplicationShell {
            switch family {
            case .accessoryRectangular:
                HStack(spacing: 7) {
                    Image(systemName: isPlaying ? "play.circle.fill" : "pause.circle")
                        .font(.title3.weight(.semibold))
                        .widgetAccentable()
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.headline).lineLimit(1)
                        Text(artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        ProgressView(value: snapshot?.progress ?? 0)
                            .tint(accentPurple)
                    }
                }
            case .accessoryInline:
                Label(title, systemImage: isPlaying ? "play.fill" : "music.note")
            case .accessoryCorner:
                Image(systemName: isPlaying ? "play.fill" : "music.note")
                    .widgetLabel { Text(title) }
            default:
                Gauge(value: snapshot?.progress ?? 0) {
                    Image(systemName: isPlaying ? "play.fill" : "music.note")
                        .widgetAccentable()
                }
                .gaugeStyle(.accessoryCircularCapacity)
            }
        }
    }
}

private struct QueueComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ComplicationEntry<QueueSnapshot>

    private var first: QueueItem? { entry.value?.items.first }
    private var count: Int { entry.value?.totalCount ?? 0 }
    private var title: String { first?.title ?? localizedKey("watch.complication.queue") }

    var body: some View {
        ComplicationShell {
            switch family {
            case .accessoryRectangular:
                HStack(spacing: 7) {
                    Image(systemName: "music.note.list")
                        .font(.title3.weight(.semibold))
                        .widgetAccentable()
                    VStack(alignment: .leading, spacing: 1) {
                        Text(localizedKey("watch.complication.queue")).font(.headline).lineLimit(1)
                        Text(first.map { "\($0.title) - \($0.artist ?? "DJConnect")" } ?? localizedKey("watch.complication.no.queue.snapshot"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            case .accessoryInline:
                Label(count > 0 ? "\(count) \(localizedKey("watch.complication.queued"))" : localizedKey("watch.complication.queue"), systemImage: "music.note.list")
            case .accessoryCorner:
                Image(systemName: "music.note.list")
                    .widgetLabel { Text("\(count)") }
            default:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 1) {
                        Image(systemName: "music.note.list").font(.system(size: 14, weight: .bold))
                        Text("\(count)").font(.caption2.weight(.bold))
                    }
                    .widgetAccentable()
                }
            }
        }
    }
}

private struct PlaylistsComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ComplicationEntry<PlaylistsSnapshot>

    private var first: PlaylistItem? { entry.value?.items.first }
    private var count: Int { entry.value?.totalCount ?? 0 }

    var body: some View {
        ComplicationShell {
            switch family {
            case .accessoryRectangular:
                HStack(spacing: 7) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.title3.weight(.semibold))
                        .widgetAccentable()
                    VStack(alignment: .leading, spacing: 1) {
                        Text(localizedKey("watch.complication.playlists")).font(.headline).lineLimit(1)
                        Text(first?.name ?? localizedKey("watch.complication.no.playlist.snapshot"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            case .accessoryInline:
                Label(first?.name ?? localizedKey("watch.complication.playlists"), systemImage: "rectangle.stack.fill")
            case .accessoryCorner:
                Image(systemName: "rectangle.stack.fill")
                    .widgetLabel { Text("\(count)") }
            default:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 1) {
                        Image(systemName: "rectangle.stack.fill").font(.system(size: 14, weight: .bold))
                        Text("\(count)").font(.caption2.weight(.bold))
                    }
                    .widgetAccentable()
                }
            }
        }
    }
}

private struct TrackInsightComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ComplicationEntry<TrackInsightSnapshot>

    private var snapshot: TrackInsightSnapshot? { entry.value }
    private var title: String { snapshot?.title.isEmpty == false ? snapshot!.title : "Track Insight" }
    private var detail: String {
        return snapshot?.mood ?? snapshot?.genre ?? "DJConnect"
    }

    var body: some View {
        ComplicationShell {
            switch family {
            case .accessoryRectangular:
                HStack(spacing: 7) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.title3.weight(.semibold))
                        .widgetAccentable()
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.headline).lineLimit(1)
                        Text([detail, percent(snapshot?.energy)].compactMap { $0 }.joined(separator: " - "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            case .accessoryInline:
                Label(detail, systemImage: "waveform.path.ecg")
            case .accessoryCorner:
                Image(systemName: "waveform.path.ecg")
                    .widgetLabel { Text(detail) }
            default:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 17, weight: .semibold))
                        .widgetAccentable()
                }
            }
        }
    }
}

private struct AskDJComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ComplicationEntry<AskDJSnapshot>

    private var snapshot: AskDJSnapshot? { entry.value }

    var body: some View {
        ComplicationShell {
            switch family {
            case .accessoryRectangular:
                HStack(spacing: 7) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.title3.weight(.semibold))
                        .widgetAccentable()
                    VStack(alignment: .leading, spacing: 1) {
                        Text(localizedKey("widget.ask.dj")).font(.headline).lineLimit(1)
                        Text(snapshot?.prompt ?? localizedKey("watch.complication.open.ask.dj"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            case .accessoryInline:
                Label(localizedKey("widget.ask.dj"), systemImage: "bubble.left.and.bubble.right")
            case .accessoryCorner:
                Image(systemName: "bubble.left.and.bubble.right")
                    .widgetLabel { Text(localizedKey("widget.ask.dj")) }
            default:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 17, weight: .semibold))
                        .widgetAccentable()
                }
            }
        }
    }
}

struct DJConnectComplicationWidget: Widget {
    let kind = "DJConnectComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DJConnectLauncherProvider()) { _ in
            DJConnectLauncherView()
        }
        .configurationDisplayName("DJConnect")
        .description(localizedKey("watch.complication.djconnect.description"))
        .supportedFamilies(supportedFamilies)
    }
}

struct DJConnectNowPlayingComplicationWidget: Widget {
    let kind = "DJConnectNowPlayingComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: SnapshotProvider(key: NowPlayingSnapshot.key, placeholderValue: NowPlayingSnapshot(
                updatedAt: Date(),
                title: "Midnight City",
                artist: "M83",
                progressMS: 138_000,
                durationMS: 200_000,
                isPlaying: true,
                deviceName: "DJConnect"
            ))
        ) { entry in
            NowPlayingComplicationView(entry: entry)
        }
        .configurationDisplayName(localizedKey("widget.now.playing"))
        .description(localizedKey("watch.complication.now.playing.description"))
        .supportedFamilies(supportedFamilies)
    }
}

struct DJConnectQueueComplicationWidget: Widget {
    let kind = "DJConnectQueueComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: SnapshotProvider(key: QueueSnapshot.key, placeholderValue: QueueSnapshot(
                updatedAt: Date(),
                items: [QueueItem(id: "0", title: "Sweet Disposition", artist: "The Temper Trap")],
                totalCount: 4
            ))
        ) { entry in
            QueueComplicationView(entry: entry)
        }
        .configurationDisplayName(localizedKey("watch.complication.queue"))
        .description(localizedKey("watch.complication.queue.description"))
        .supportedFamilies(supportedFamilies)
    }
}

struct DJConnectPlaylistsComplicationWidget: Widget {
    let kind = "DJConnectPlaylistsComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: SnapshotProvider(key: PlaylistsSnapshot.key, placeholderValue: PlaylistsSnapshot(
                updatedAt: Date(),
                items: [PlaylistItem(id: "0", name: "Friday Night", subtitle: "DJConnect")],
                totalCount: 6
            ))
        ) { entry in
            PlaylistsComplicationView(entry: entry)
        }
        .configurationDisplayName(localizedKey("watch.complication.playlists"))
        .description(localizedKey("watch.complication.playlists.description"))
        .supportedFamilies(supportedFamilies)
    }
}

struct DJConnectTrackInsightComplicationWidget: Widget {
    let kind = "DJConnectTrackInsightComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: SnapshotProvider(key: TrackInsightSnapshot.key, placeholderValue: TrackInsightSnapshot(
                updatedAt: Date(),
                title: "Midnight City",
                artist: "M83",
                genre: "Synthpop",
                mood: localizedKey("widget.preview.mood.nostalgic"),
                energy: 0.76,
                progress: 138,
                duration: 200
            ))
        ) { entry in
            TrackInsightComplicationView(entry: entry)
        }
        .configurationDisplayName(localizedKey("watch.complication.track.insight"))
        .description(localizedKey("watch.complication.track.insight.description"))
        .supportedFamilies(supportedFamilies)
    }
}

struct DJConnectAskDJComplicationWidget: Widget {
    let kind = "DJConnectAskDJComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: SnapshotProvider(key: AskDJSnapshot.key, placeholderValue: AskDJSnapshot(
                updatedAt: Date(),
                prompt: localizedKey("widget.ask.dj"),
                response: localizedKey("watch.complication.ready"),
                context: "DJConnect",
                trackTitle: "Midnight City",
                artist: "M83"
            ))
        ) { entry in
            AskDJComplicationView(entry: entry)
        }
        .configurationDisplayName(localizedKey("widget.ask.dj"))
        .description(localizedKey("watch.complication.ask.dj.description"))
        .supportedFamilies(supportedFamilies)
    }
}

private var supportedFamilies: [WidgetFamily] {
    [
        .accessoryCircular,
        .accessoryRectangular,
        .accessoryInline,
        .accessoryCorner
    ]
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
