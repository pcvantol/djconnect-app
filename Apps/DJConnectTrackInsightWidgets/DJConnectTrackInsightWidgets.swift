import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(DJConnectCore)
import DJConnectCore
#endif

private enum DJConnectWidgetDeepLink {
    static let nowPlaying = URL(string: "djconnect://now-playing")!
    static let queue = URL(string: "djconnect://queue")!
    static let playlists = URL(string: "djconnect://playlists")!
    static let trackInsight = URL(string: "djconnect://track-insight")!
    static let askDJ = URL(string: "djconnect://ask-dj")!
}

struct DJConnectNowPlayingWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let artist: String
    let artworkURL: URL?
    let progress: Double
    let isPlaying: Bool
    let deviceName: String
    let hasSnapshot: Bool

    init(
        date: Date,
        title: String,
        artist: String,
        artworkURL: URL?,
        progress: Double,
        isPlaying: Bool,
        deviceName: String,
        hasSnapshot: Bool
    ) {
        self.date = date
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.progress = max(0, min(1, progress))
        self.isPlaying = isPlaying
        self.deviceName = deviceName
        self.hasSnapshot = hasSnapshot
    }

    static let placeholder = DJConnectNowPlayingWidgetEntry(
        date: Date(),
        title: "Midnight City",
        artist: "M83",
        artworkURL: nil,
        progress: 0.42,
        isPlaying: true,
        deviceName: "Living Room",
        hasSnapshot: true
    )

    static let empty = DJConnectNowPlayingWidgetEntry(
        date: Date(),
        title: DJConnectLocalization.localized(key: "widget.nothing.playing"),
        artist: DJConnectLocalization.localized(key: "widget.open.djconnect"),
        artworkURL: nil,
        progress: 0,
        isPlaying: false,
        deviceName: DJConnectLocalization.localized(key: "widget.ready"),
        hasSnapshot: false
    )

#if canImport(DJConnectCore)
    init(snapshot: DJConnectNowPlayingWidgetSnapshot) {
        let duration = max(1, snapshot.durationMS ?? 0)
        let progress = snapshot.durationMS == nil ? 0 : Double(snapshot.progressMS ?? 0) / Double(duration)
        date = snapshot.updatedAt
        title = snapshot.title.isEmpty ? DJConnectLocalization.localized(key: "widget.unknown.track") : snapshot.title
        artist = snapshot.artist.isEmpty ? DJConnectLocalization.localized(key: "widget.unknown.artist") : snapshot.artist
        artworkURL = snapshot.artworkURL
        self.progress = max(0, min(1, progress))
        isPlaying = snapshot.isPlaying
        deviceName = snapshot.deviceName ?? DJConnectLocalization.localized(key: "widget.djconnect")
        hasSnapshot = true
    }
#endif
}

struct DJConnectNowPlayingWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DJConnectNowPlayingWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DJConnectNowPlayingWidgetEntry) -> Void) {
        completion(Self.currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DJConnectNowPlayingWidgetEntry>) -> Void) {
        let entry = Self.currentEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: entry.isPlaying ? 5 : 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private static func currentEntry() -> DJConnectNowPlayingWidgetEntry {
#if canImport(DJConnectCore)
        if let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier),
           let snapshot = DJConnectNowPlayingWidgetSnapshot.load(from: defaults) {
            return DJConnectNowPlayingWidgetEntry(snapshot: snapshot)
        }
#endif
        return .empty
    }
}

struct DJConnectNowPlayingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DJConnectNowPlayingWidgetEntry

    var body: some View {
        ZStack {
            DJConnectNowPlayingWidgetBackground(entry: entry)
            content
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(DJConnectWidgetDeepLink.nowPlaying)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            small
        case .systemMedium:
            medium
        case .systemLarge, .systemExtraLarge:
            large
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryCircular:
            accessoryCircular
        case .accessoryInline:
            Label(entry.title, systemImage: entry.isPlaying ? "play.fill" : "pause.fill")
        default:
            medium
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(compact: true)
            Spacer(minLength: 0)
            DJConnectNowPlayingArtwork(entry: entry)
                .frame(width: 64, height: 64)
            Spacer(minLength: 0)
            titleBlock(lineLimit: 1)
            DJConnectNowPlayingProgressBar(progress: entry.progress)
                .frame(height: 5)
        }
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            DJConnectNowPlayingArtwork(entry: entry)
                .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 9) {
                header(compact: false)
                titleBlock(lineLimit: 2)
                DJConnectNowPlayingProgressBar(progress: entry.progress)
                    .frame(height: 6)
                statusLine
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 14) {
            header(compact: false)
            HStack(alignment: .center, spacing: 16) {
                DJConnectNowPlayingArtwork(entry: entry)
                    .frame(width: 128, height: 128)
                VStack(alignment: .leading, spacing: 9) {
                    titleBlock(lineLimit: 3)
                    statusLine
                }
            }
            DJConnectNowPlayingProgressBar(progress: entry.progress)
                .frame(height: 7)
            DJConnectNowPlayingWaveform(entry: entry)
                .frame(height: 66)
            Spacer(minLength: 0)
            Text(DJConnectLocalization.localized(key: "widget.updated.from.djconnect"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(18)
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.isPlaying ? "play.circle.fill" : "pause.circle")
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.artist)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: entry.isPlaying ? "play.fill" : "music.note")
                .font(.system(size: 17, weight: .semibold))
                .widgetAccentable()
        }
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: entry.isPlaying ? "music.note" : "pause.fill")
                .font(.caption.weight(.bold))
            Text(compact ? DJConnectLocalization.localized(key: "widget.now") : DJConnectLocalization.localized(key: "widget.now.playing"))
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white.opacity(0.84))
    }

    private func titleBlock(lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(lineLimit)
            Text(entry.artist)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
        }
    }

    private var statusLine: some View {
        Label(
            entry.hasSnapshot ? entry.deviceName : DJConnectLocalization.localized(key: "widget.open.the.app.to.refresh"),
            systemImage: entry.isPlaying ? "speaker.wave.2.fill" : "pause.circle"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.70))
        .lineLimit(1)
    }
}

private struct DJConnectNowPlayingArtwork: View {
    let entry: DJConnectNowPlayingWidgetEntry

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.10, blue: 0.24),
                            Color(red: 0.29, green: 0.16, blue: 0.44),
                            Color(red: 0.06, green: 0.38, blue: 0.56)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if let artworkURL = entry.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        DJConnectNowPlayingArtworkFallback(entry: entry)
                    }
                }
            } else {
                DJConnectNowPlayingArtworkFallback(entry: entry)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct DJConnectNowPlayingArtworkFallback: View {
    let entry: DJConnectNowPlayingWidgetEntry

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: entry.isPlaying ? "music.note" : "music.note.list")
                .font(.system(size: 26, weight: .bold))
            Text("DJ")
                .font(.caption.weight(.black))
        }
        .foregroundStyle(.white.opacity(0.82))
    }
}

private struct DJConnectNowPlayingProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.18))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.24, green: 0.64, blue: 1.0),
                                Color(red: 0.86, green: 0.23, blue: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(geometry.size.width * progress, progress > 0 ? 5 : 0))
            }
        }
    }
}

private struct DJConnectNowPlayingWaveform: View {
    let entry: DJConnectNowPlayingWidgetEntry

    var body: some View {
        Canvas { context, size in
            let bars = 30
            let barWidth = size.width / CGFloat(bars)
            let seedBase = entry.title.count * 11 + entry.artist.count * 7
            let opacity = entry.isPlaying ? 0.72 : 0.36
            for index in 0..<bars {
                let seedValue = (index * 23 + seedBase) % 100
                let seed = Double(seedValue) / 100.0
                let activeLevel = 0.18 + seed * 0.76
                let inactiveLevel = 0.12 + seed * 0.20
                let level = entry.isPlaying ? activeLevel : inactiveLevel
                let height = size.height * CGFloat(level)
                let rect = CGRect(
                    x: CGFloat(index) * barWidth,
                    y: size.height - height,
                    width: max(2, barWidth * 0.52),
                    height: height
                )
                let hue = 0.54 + Double(index) / Double(bars) * 0.28
                let color = Color(hue: hue, saturation: 0.86, brightness: 1)
                let path = Path(roundedRect: rect, cornerRadius: 2)
                context.fill(path, with: .color(color.opacity(opacity)))
            }
        }
    }
}

private struct DJConnectNowPlayingWidgetBackground: View {
    let entry: DJConnectNowPlayingWidgetEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.10),
                    Color(red: 0.08, green: 0.09, blue: 0.30),
                    Color(red: 0.15, green: 0.26, blue: 0.43)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            DJConnectNowPlayingWaveform(entry: entry)
                .opacity(0.20)
                .padding(.top, 48)
        }
    }
}

struct DJConnectNowPlayingWidget: Widget {
    let kind = DJConnectNowPlayingWidgetSnapshot.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DJConnectNowPlayingWidgetProvider()) { entry in
            DJConnectNowPlayingWidgetView(entry: entry)
        }
        .configurationDisplayName("Now Playing")
        .description("Shows the current DJConnect track, artist, playback state and progress.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ]
        #else
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge
        ]
        #endif
    }
}

struct DJConnectQueueWidgetEntry: TimelineEntry {
    let date: Date
    let items: [DJConnectQueueWidgetItem]
    let totalCount: Int
    let hasSnapshot: Bool

    static let placeholder = DJConnectQueueWidgetEntry(
        date: Date(),
        items: [
            DJConnectQueueWidgetItem(id: "0", title: "Midnight City", artist: "M83", album: "Hurry Up, We're Dreaming", durationMS: 244_000),
            DJConnectQueueWidgetItem(id: "1", title: "Sweet Disposition", artist: "The Temper Trap", album: "Conditions", durationMS: 232_000),
            DJConnectQueueWidgetItem(id: "2", title: "Electric Feel", artist: "MGMT", album: "Oracular Spectacular", durationMS: 229_000),
            DJConnectQueueWidgetItem(id: "3", title: "Innerbloom", artist: "RUFUS DU SOL", album: "Bloom", durationMS: 540_000)
        ],
        totalCount: 4,
        hasSnapshot: true
    )

    static let empty = DJConnectQueueWidgetEntry(
        date: Date(),
        items: [],
        totalCount: 0,
        hasSnapshot: false
    )

#if canImport(DJConnectCore)
    init(snapshot: DJConnectQueueWidgetSnapshot) {
        date = snapshot.updatedAt
        items = snapshot.items
        totalCount = snapshot.totalCount
        hasSnapshot = true
    }
#endif

    init(date: Date, items: [DJConnectQueueWidgetItem], totalCount: Int, hasSnapshot: Bool) {
        self.date = date
        self.items = items
        self.totalCount = totalCount
        self.hasSnapshot = hasSnapshot
    }
}

struct DJConnectQueueWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DJConnectQueueWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DJConnectQueueWidgetEntry) -> Void) {
        completion(Self.currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DJConnectQueueWidgetEntry>) -> Void) {
        let entry = Self.currentEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private static func currentEntry() -> DJConnectQueueWidgetEntry {
#if canImport(DJConnectCore)
        if let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier),
           let snapshot = DJConnectQueueWidgetSnapshot.load(from: defaults) {
            return DJConnectQueueWidgetEntry(snapshot: snapshot)
        }
#endif
        return .empty
    }
}

struct DJConnectQueueWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DJConnectQueueWidgetEntry

    var body: some View {
        ZStack {
            DJConnectQueueWidgetBackground()
            content
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(DJConnectWidgetDeepLink.queue)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            small
        case .systemMedium:
            medium
        case .systemLarge:
            queueList(limit: 5, includeFooter: true)
                .padding(16)
        case .systemExtraLarge:
            queueList(limit: 5, includeFooter: true)
                .padding(20)
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryCircular:
            accessoryCircular
        case .accessoryInline:
            Label(accessoryInlineTitle, systemImage: "text.line.first.and.arrowtriangle.forward")
        default:
            medium
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Spacer(minLength: 0)
            if let first = entry.items.first {
                DJConnectQueueArtwork(item: first)
                    .frame(width: 62, height: 62)
                Text(first.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(first.artist ?? queueCountText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
            } else {
                emptyState
            }
        }
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            if let first = entry.items.first {
                DJConnectQueueArtwork(item: first)
                    .frame(width: 92, height: 92)
            } else {
                DJConnectQueueEmptyIcon()
                    .frame(width: 92, height: 92)
            }
            VStack(alignment: .leading, spacing: 8) {
                header
                if entry.items.isEmpty {
                    emptyText
                } else {
                    ForEach(Array(entry.items.prefix(3).enumerated()), id: \.element.id) { index, item in
                        queueRow(item: item, index: index + 1, showArtwork: false)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private func queueList(limit: Int, includeFooter: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if entry.items.isEmpty {
                Spacer(minLength: 0)
                emptyState
                Spacer(minLength: 0)
            } else {
                ForEach(Array(entry.items.prefix(limit).enumerated()), id: \.element.id) { index, item in
                    queueRow(item: item, index: index + 1, showArtwork: true)
                }
                Spacer(minLength: 0)
                if includeFooter {
                    Text(queueCountText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }
            }
        }
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.line.first.and.arrowtriangle.forward")
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text(DJConnectLocalization.localized(key: "widget.queue"))
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.items.first?.title ?? DJConnectLocalization.localized(key: "widget.no.queue"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "text.line.first.and.arrowtriangle.forward")
                .font(.system(size: 17, weight: .semibold))
                .widgetAccentable()
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "text.line.first.and.arrowtriangle.forward")
                .font(.caption.weight(.bold))
            Text(DJConnectLocalization.localized(key: "widget.queue"))
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
            Spacer(minLength: 0)
            if entry.hasSnapshot {
                Text("\(entry.totalCount)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.14), in: Capsule())
            }
        }
        .foregroundStyle(.white.opacity(0.84))
    }

    private func queueRow(item: DJConnectQueueWidgetItem, index: Int, showArtwork: Bool) -> some View {
        HStack(spacing: 9) {
            if showArtwork {
                DJConnectQueueArtwork(item: item)
                    .frame(width: 42, height: 42)
            } else {
                Text("\(index)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 18)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.artist ?? item.album ?? DJConnectLocalization.localized(key: "widget.queued"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let duration = item.durationMS {
                Text(formattedDuration(duration))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.52))
                    .monospacedDigit()
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            DJConnectQueueEmptyIcon()
                .frame(width: 62, height: 62)
            emptyText
        }
    }

    private var emptyText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(DJConnectLocalization.localized(key: "widget.no.queue"))
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text(DJConnectLocalization.localized(key: "widget.open.djconnect.to.refresh"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(2)
        }
    }

    private var queueCountText: String {
        if entry.totalCount == 1 {
            return DJConnectLocalization.localized(key: "widget.1.track.queued")
        }
        return DJConnectLocalization.localized(key: "widget.value.tracks.queued", arguments: entry.totalCount)
    }

    private var accessoryInlineTitle: String {
        entry.items.first?.title ?? DJConnectLocalization.localized(key: "widget.queue")
    }

    private func formattedDuration(_ milliseconds: Int) -> String {
        let seconds = max(0, milliseconds / 1_000)
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

private struct DJConnectQueueArtwork: View {
    let item: DJConnectQueueWidgetItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.12, blue: 0.26),
                            Color(red: 0.21, green: 0.16, blue: 0.42),
                            Color(red: 0.07, green: 0.34, blue: 0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if let artworkURL = item.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "music.note.list")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white.opacity(0.80))
                    }
                }
            } else {
                Image(systemName: "music.note.list")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.80))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct DJConnectQueueEmptyIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.12))
            Image(systemName: "text.line.first.and.arrowtriangle.forward")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
        }
    }
}

private struct DJConnectQueueWidgetBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.10),
                    Color(red: 0.08, green: 0.12, blue: 0.30),
                    Color(red: 0.07, green: 0.28, blue: 0.36)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Canvas { context, size in
                let rows = 5
                for row in 0..<rows {
                    let y = size.height * (0.22 + CGFloat(row) * 0.14)
                    let rect = CGRect(x: size.width * 0.10, y: y, width: size.width * 0.78, height: 2)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(.white.opacity(0.08)))
                }
            }
        }
    }
}

struct DJConnectQueueWidget: Widget {
    let kind = DJConnectQueueWidgetSnapshot.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DJConnectQueueWidgetProvider()) { entry in
            DJConnectQueueWidgetView(entry: entry)
        }
        .configurationDisplayName("Queue")
        .description("Shows the upcoming DJConnect queue in compact and detailed widget sizes.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ]
        #else
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge
        ]
        #endif
    }
}

struct DJConnectPlaylistsWidgetEntry: TimelineEntry {
    let date: Date
    let items: [DJConnectPlaylistWidgetItem]
    let totalCount: Int
    let hasSnapshot: Bool

    static let placeholder = DJConnectPlaylistsWidgetEntry(
        date: Date(),
        items: [
            DJConnectPlaylistWidgetItem(id: "0", name: "Friday Night", subtitle: "DJConnect"),
            DJConnectPlaylistWidgetItem(id: "1", name: "Dinner Vibes", subtitle: "Home"),
            DJConnectPlaylistWidgetItem(id: "2", name: "Late Drive", subtitle: "Road"),
            DJConnectPlaylistWidgetItem(id: "3", name: "Deep Focus", subtitle: "Work")
        ],
        totalCount: 4,
        hasSnapshot: true
    )

    static let empty = DJConnectPlaylistsWidgetEntry(date: Date(), items: [], totalCount: 0, hasSnapshot: false)

#if canImport(DJConnectCore)
    init(snapshot: DJConnectPlaylistsWidgetSnapshot) {
        date = snapshot.updatedAt
        items = snapshot.items
        totalCount = snapshot.totalCount
        hasSnapshot = true
    }
#endif

    init(date: Date, items: [DJConnectPlaylistWidgetItem], totalCount: Int, hasSnapshot: Bool) {
        self.date = date
        self.items = items
        self.totalCount = totalCount
        self.hasSnapshot = hasSnapshot
    }
}

struct DJConnectPlaylistsWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DJConnectPlaylistsWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DJConnectPlaylistsWidgetEntry) -> Void) {
        completion(Self.currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DJConnectPlaylistsWidgetEntry>) -> Void) {
        let entry = Self.currentEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private static func currentEntry() -> DJConnectPlaylistsWidgetEntry {
#if canImport(DJConnectCore)
        if let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier),
           let snapshot = DJConnectPlaylistsWidgetSnapshot.load(from: defaults) {
            return DJConnectPlaylistsWidgetEntry(snapshot: snapshot)
        }
#endif
        return .empty
    }
}

struct DJConnectPlaylistsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DJConnectPlaylistsWidgetEntry

    var body: some View {
        ZStack {
            DJConnectPlaylistsWidgetBackground()
            content
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(DJConnectWidgetDeepLink.playlists)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            small
        case .systemMedium:
            medium
        case .systemLarge:
            playlistsList(limit: 5, includeFooter: true)
                .padding(16)
        case .systemExtraLarge:
            playlistsList(limit: 5, includeFooter: true)
                .padding(20)
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryCircular:
            accessoryCircular
        case .accessoryInline:
            Label(accessoryInlineTitle, systemImage: "music.note.list")
        default:
            medium
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Spacer(minLength: 0)
            if let first = entry.items.first {
                DJConnectPlaylistArtwork(item: first)
                    .frame(width: 62, height: 62)
                Text(first.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(first.subtitle ?? playlistsCountText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
            } else {
                emptyState
            }
        }
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            DJConnectPlaylistStackPreview(items: Array(entry.items.prefix(3)))
                .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 8) {
                header
                if entry.items.isEmpty {
                    emptyText
                } else {
                    ForEach(Array(entry.items.prefix(3).enumerated()), id: \.element.id) { index, item in
                        playlistRow(item: item, index: index + 1, showArtwork: false)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private func playlistsList(limit: Int, includeFooter: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if entry.items.isEmpty {
                Spacer(minLength: 0)
                emptyState
                Spacer(minLength: 0)
            } else {
                ForEach(Array(entry.items.prefix(limit).enumerated()), id: \.element.id) { index, item in
                    playlistRow(item: item, index: index + 1, showArtwork: true)
                }
                Spacer(minLength: 0)
                if includeFooter {
                    Text(playlistsCountText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }
            }
        }
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text(DJConnectLocalization.localized(key: "widget.playlists"))
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.items.first?.name ?? DJConnectLocalization.localized(key: "widget.no.playlists"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "music.note.list")
                .font(.system(size: 17, weight: .semibold))
                .widgetAccentable()
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "music.note.list")
                .font(.caption.weight(.bold))
            Text(DJConnectLocalization.localized(key: "widget.playlists"))
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
            Spacer(minLength: 0)
            if entry.hasSnapshot {
                Text("\(entry.totalCount)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.14), in: Capsule())
            }
        }
        .foregroundStyle(.white.opacity(0.84))
    }

    private func playlistRow(item: DJConnectPlaylistWidgetItem, index: Int, showArtwork: Bool) -> some View {
        HStack(spacing: 9) {
            if showArtwork {
                DJConnectPlaylistArtwork(item: item)
                    .frame(width: 42, height: 42)
            } else {
                Text("\(index)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 18)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.subtitle ?? DJConnectLocalization.localized(key: "widget.playlist"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "play.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.46))
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            DJConnectPlaylistEmptyIcon()
                .frame(width: 62, height: 62)
            emptyText
        }
    }

    private var emptyText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(DJConnectLocalization.localized(key: "widget.no.playlists"))
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text(DJConnectLocalization.localized(key: "widget.open.djconnect.to.refresh"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(2)
        }
    }

    private var playlistsCountText: String {
        if entry.totalCount == 1 {
            return DJConnectLocalization.localized(key: "widget.1.playlist")
        }
        return DJConnectLocalization.localized(key: "widget.value.playlists", arguments: entry.totalCount)
    }

    private var accessoryInlineTitle: String {
        entry.items.first?.name ?? DJConnectLocalization.localized(key: "widget.playlists")
    }
}

private struct DJConnectPlaylistStackPreview: View {
    let items: [DJConnectPlaylistWidgetItem]

    var body: some View {
        ZStack {
            if items.isEmpty {
                DJConnectPlaylistEmptyIcon()
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    DJConnectPlaylistArtwork(item: item)
                        .frame(width: 62, height: 62)
                        .offset(x: CGFloat(index) * 10 - 10, y: CGFloat(index) * -6 + 6)
                }
            }
        }
    }
}

private struct DJConnectPlaylistArtwork: View {
    let item: DJConnectPlaylistWidgetItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.11, green: 0.10, blue: 0.28),
                            Color(red: 0.30, green: 0.12, blue: 0.42),
                            Color(red: 0.08, green: 0.30, blue: 0.48)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if let imageURL = item.imageURL {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "music.note.list")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white.opacity(0.80))
                    }
                }
            } else {
                Image(systemName: "music.note.list")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.80))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct DJConnectPlaylistEmptyIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.12))
            Image(systemName: "music.note.list")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
        }
    }
}

private struct DJConnectPlaylistsWidgetBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.04, blue: 0.10),
                    Color(red: 0.10, green: 0.08, blue: 0.30),
                    Color(red: 0.18, green: 0.14, blue: 0.44)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Canvas { context, size in
                for index in 0..<18 {
                    let column = index % 6
                    let row = index / 6
                    let rect = CGRect(
                        x: size.width * 0.10 + CGFloat(column) * size.width * 0.14,
                        y: size.height * 0.24 + CGFloat(row) * size.height * 0.18,
                        width: size.width * 0.08,
                        height: size.width * 0.08
                    )
                    context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(.white.opacity(0.08)))
                }
            }
        }
    }
}

struct DJConnectPlaylistsWidget: Widget {
    let kind = DJConnectPlaylistsWidgetSnapshot.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DJConnectPlaylistsWidgetProvider()) { entry in
            DJConnectPlaylistsWidgetView(entry: entry)
        }
        .configurationDisplayName("Playlists")
        .description("Shows DJConnect playlists in compact and detailed widget sizes.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ]
        #else
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge
        ]
        #endif
    }
}

struct DJConnectTrackInsightWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let artist: String
    let genre: String
    let mood: String
    let vibe: String
    let bpm: Int
    let key: String
    let energy: Double
    let danceability: Double
    let intensity: Double
    let progress: TimeInterval?
    let duration: TimeInterval?
    let summary: String
    let hasSnapshot: Bool

    init(
        date: Date,
        title: String,
        artist: String,
        genre: String,
        mood: String,
        vibe: String,
        bpm: Int,
        key: String,
        energy: Double,
        danceability: Double,
        intensity: Double,
        progress: TimeInterval?,
        duration: TimeInterval?,
        summary: String,
        hasSnapshot: Bool
    ) {
        self.date = date
        self.title = title
        self.artist = artist
        self.genre = genre
        self.mood = mood
        self.vibe = vibe
        self.bpm = bpm
        self.key = key
        self.energy = energy
        self.danceability = danceability
        self.intensity = intensity
        self.progress = progress
        self.duration = duration
        self.summary = summary
        self.hasSnapshot = hasSnapshot
    }

    static let placeholder = DJConnectTrackInsightWidgetEntry(
        date: Date(),
        title: "Innerbloom",
        artist: "RUFUS DU SOL",
        genre: "Deep House",
        mood: "Dreamy",
        vibe: "Cinematic",
        bpm: 122,
        key: "F# minor",
        energy: 0.65,
        danceability: 0.72,
        intensity: 0.58,
        progress: 138,
        duration: 200,
        summary: "A slow-building journey with glowing synth textures and a hypnotic groove.",
        hasSnapshot: true
    )

    static let empty = DJConnectTrackInsightWidgetEntry(
        date: Date(),
        title: DJConnectLocalization.localized(key: "widget.no.track.insight.yet"),
        artist: DJConnectLocalization.localized(key: "widget.open.djconnect"),
        genre: DJConnectLocalization.localized(key: "widget.private"),
        mood: DJConnectLocalization.localized(key: "widget.ready"),
        vibe: DJConnectLocalization.localized(key: "widget.on.device"),
        bpm: 0,
        key: "-",
        energy: 0.5,
        danceability: 0.5,
        intensity: 0.5,
        progress: nil,
        duration: nil,
        summary: DJConnectLocalization.localized(key: "widget.run.track.insight.in.the.app.to.update.this"),
        hasSnapshot: false
    )

#if canImport(DJConnectCore)
    init(snapshot: DJConnectTrackInsightWidgetSnapshot) {
        date = snapshot.updatedAt
        title = snapshot.title
        artist = snapshot.artist
        genre = snapshot.genre ?? DJConnectLocalization.localized(key: "widget.unknown.genre")
        mood = snapshot.mood ?? DJConnectLocalization.localized(key: "widget.evolving")
        vibe = snapshot.vibe ?? DJConnectLocalization.localized(key: "widget.fresh")
        bpm = snapshot.bpm ?? 0
        key = snapshot.key ?? "-"
        energy = snapshot.energy ?? 0.5
        danceability = snapshot.danceability ?? 0.5
        intensity = snapshot.intensity ?? 0.5
        progress = snapshot.progress
        duration = snapshot.duration
        summary = snapshot.summary
        hasSnapshot = true
    }
#endif
}

struct DJConnectTrackInsightWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DJConnectTrackInsightWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DJConnectTrackInsightWidgetEntry) -> Void) {
        completion(Self.currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DJConnectTrackInsightWidgetEntry>) -> Void) {
        let entry = Self.currentEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private static func currentEntry() -> DJConnectTrackInsightWidgetEntry {
#if canImport(DJConnectCore)
        if let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier),
           let snapshot = DJConnectTrackInsightWidgetSnapshot.load(from: defaults) {
            return DJConnectTrackInsightWidgetEntry(snapshot: snapshot)
        }
#endif
        return .empty
    }
}

struct DJConnectTrackInsightWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DJConnectTrackInsightWidgetEntry

    var body: some View {
        ZStack {
            DJConnectTrackInsightWidgetBackground(entry: entry)
            content
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(DJConnectWidgetDeepLink.trackInsight)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            small
        case .systemMedium:
            medium
        case .systemLarge, .systemExtraLarge:
            large
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryCircular:
            accessoryCircular
        case .accessoryInline:
            Label(entry.title, systemImage: "waveform.path.ecg")
        default:
            medium
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(compact: true)
            Spacer(minLength: 0)
            DJConnectTrackInsightOrb(entry: entry)
                .frame(width: 58, height: 58)
            Spacer(minLength: 0)
            titleBlock(lineLimit: 1)
            progressOrMetricRow
        }
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            DJConnectTrackInsightOrb(entry: entry)
                .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 8) {
                header(compact: false)
                titleBlock(lineLimit: 1)
                Text(entry.summary)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(2)
                if let progressLabel {
                    Text(progressLabel)
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(1)
                }
                metricRow
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 14) {
            header(compact: false)
            HStack(alignment: .center, spacing: 16) {
                DJConnectTrackInsightOrb(entry: entry)
                    .frame(width: 126, height: 126)
                VStack(alignment: .leading, spacing: 8) {
                    titleBlock(lineLimit: 2)
                    if let progressLabel {
                        Text(progressLabel)
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(1)
                    }
                    Text(entry.summary)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(3)
                }
            }
            DJConnectTrackInsightMeterRow(entry: entry)
            Spacer(minLength: 0)
            Text(DJConnectLocalization.localized(key: "widget.rendered.privately.on.device"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(18)
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(progressLabel ?? (entry.hasSnapshot ? "\(entry.genre) - \(entry.bpm) BPM" : entry.summary))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 18, weight: .semibold))
                .widgetAccentable()
        }
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform.path.ecg")
                .font(.caption.weight(.bold))
            Text(entry.hasSnapshot ? (compact ? "Insight" : "Track Insight") : DJConnectLocalization.localized(key: "widget.ready"))
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white.opacity(0.82))
    }

    private func titleBlock(lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(lineLimit)
            Text(entry.artist)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
        }
    }

    private var metricRow: some View {
        Text(entry.hasSnapshot ? [entry.genre, bpmLabel, entry.key].filter { !$0.isEmpty }.joined(separator: " - ") : entry.vibe)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.70))
            .lineLimit(1)
    }

    private var progressOrMetricRow: some View {
        Text(progressLabel ?? (entry.hasSnapshot ? [entry.genre, bpmLabel, entry.key].filter { !$0.isEmpty }.joined(separator: " - ") : entry.vibe))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.70))
            .lineLimit(1)
    }

    private var bpmLabel: String {
        entry.hasSnapshot && entry.bpm > 0 ? "\(entry.bpm) BPM" : ""
    }

    private var progressLabel: String? {
        guard let duration = entry.duration, duration > 0 else {
            return nil
        }
        let progress = min(max(entry.progress ?? 0, 0), duration)
        return "\(formatTime(progress)) / \(formatTime(duration))"
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(Int(seconds.rounded()), 0)
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }

}

private struct DJConnectTrackInsightWidgetBackground: View {
    let entry: DJConnectTrackInsightWidgetEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.11),
                    Color(red: 0.10, green: 0.08, blue: 0.31),
                    Color(red: 0.38, green: 0.12, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            DJConnectTrackInsightWavefield(entry: entry)
                .opacity(0.92)
        }
    }
}

private struct DJConnectTrackInsightWavefield: View {
    let entry: DJConnectTrackInsightWidgetEntry

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let rows = 7
                for row in 0..<rows {
                    var path = Path()
                    let baseY = size.height * (0.28 + CGFloat(row) * 0.085)
                    let amplitude = size.height * (0.025 + CGFloat(entry.intensity) * 0.035)
                    let phase = CGFloat(row) * 0.72
                    let step = max(size.width / 34, 4)
                    var x: CGFloat = -step
                    var first = true
                    while x <= size.width + step {
                        let progress = x / max(size.width, 1)
                        let wave = sin(progress * .pi * 3.2 + phase) * amplitude
                        let point = CGPoint(x: x, y: baseY + wave)
                        if first {
                            path.move(to: point)
                            first = false
                        } else {
                            path.addLine(to: point)
                        }
                        x += step
                    }
                    let color = Color(
                        hue: 0.58 + Double(row) * 0.045,
                        saturation: 0.82,
                        brightness: 1.0
                    )
                    context.stroke(path, with: .color(color.opacity(0.32)), lineWidth: 1.2)
                }

                let barCount = 34
                let width = size.width / CGFloat(barCount)
                for index in 0..<barCount {
                    let seed = Double((index * 37 + entry.bpm) % 100) / 100
                    let height = size.height * (0.05 + (0.18 * seed + 0.16 * entry.energy))
                    let rect = CGRect(
                        x: CGFloat(index) * width,
                        y: size.height - height - 8,
                        width: max(1.5, width * 0.52),
                        height: height
                    )
                    let color = Color(hue: 0.58 + Double(index) / Double(barCount) * 0.28, saturation: 0.88, brightness: 1.0)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color.opacity(0.58)))
                }
            }
        }
    }
}

private struct DJConnectTrackInsightOrb: View {
    let entry: DJConnectTrackInsightWidgetEntry

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .black.opacity(0.10),
                            Color(red: 0.17, green: 0.07, blue: 0.28).opacity(0.96),
                            Color(red: 0.02, green: 0.03, blue: 0.07).opacity(0.98)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 80
                    )
                )
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .trim(from: 0.06 * CGFloat(ring), to: min(0.96, CGFloat(entry.energy + Double(ring) * 0.08)))
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(red: 0.31, green: 0.63, blue: 1.0),
                                Color(red: 0.75, green: 0.36, blue: 1.0),
                                Color(red: 1.0, green: 0.35, blue: 0.42),
                                Color(red: 0.31, green: 0.63, blue: 1.0)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: CGFloat(3 - ring) + 1, lineCap: .round)
                    )
                    .rotationEffect(.degrees(Double(ring) * 42))
                    .padding(CGFloat(ring) * 8 + 5)
                    .opacity(0.92 - Double(ring) * 0.16)
            }
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
        }
    }
}

private struct DJConnectTrackInsightMeterRow: View {
    let entry: DJConnectTrackInsightWidgetEntry

    var body: some View {
        HStack(spacing: 10) {
            meter(title: DJConnectLocalization.localized(key: "widget.energy"), value: entry.energy)
            meter(title: DJConnectLocalization.localized(key: "widget.dance"), value: entry.danceability)
            meter(title: DJConnectLocalization.localized(key: "widget.intensity"), value: entry.intensity)
        }
    }

    private func meter(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.16))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.28, green: 0.65, blue: 1.0),
                                    Color(red: 0.82, green: 0.25, blue: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * max(0.06, min(1, value)))
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DJConnectTrackInsightWidget: Widget {
    let kind = DJConnectTrackInsightWidgetSnapshot.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DJConnectTrackInsightWidgetProvider()) { entry in
            DJConnectTrackInsightWidgetView(entry: entry)
        }
        .configurationDisplayName("Track Insight")
        .description("DJConnect Track Insight visualization for your current vibe.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ]
        #else
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge
        ]
        #endif
    }
}

struct DJConnectAskDJWidgetEntry: TimelineEntry {
    let date: Date
    let prompt: String
    let response: String
    let mood: String
    let trackTitle: String
    let artist: String
    let hasSnapshot: Bool

    init(date: Date, prompt: String, response: String, mood: String, trackTitle: String, artist: String, hasSnapshot: Bool) {
        self.date = date
        self.prompt = prompt
        self.response = response
        self.mood = mood
        self.trackTitle = trackTitle
        self.artist = artist
        self.hasSnapshot = hasSnapshot
    }

    static let placeholder = DJConnectAskDJWidgetEntry(
        date: Date(),
        prompt: "Ask DJ",
        response: "Vraag om de vibe, ontdek waarom een track werkt of laat DJConnect een volgende stap voorstellen.",
        mood: "Private - On device - Music DNA",
        trackTitle: "Innerbloom",
        artist: "RUFUS DU SOL",
        hasSnapshot: true
    )

    static let empty = DJConnectAskDJWidgetEntry(
        date: Date(),
        prompt: DJConnectLocalization.localized(key: "widget.ask.dj"),
        response: DJConnectLocalization.localized(key: "widget.ask.dj.in.the.app.to.update.this.widget"),
        mood: DJConnectLocalization.localized(key: "widget.private.on.device"),
        trackTitle: DJConnectLocalization.localized(key: "widget.no.ask.dj.snapshot.yet"),
        artist: "DJConnect",
        hasSnapshot: false
    )

#if canImport(DJConnectCore)
    init(snapshot: DJConnectAskDJWidgetSnapshot) {
        date = snapshot.updatedAt
        prompt = snapshot.prompt
        response = snapshot.response
        mood = snapshot.context
        trackTitle = snapshot.trackTitle ?? DJConnectLocalization.localized(key: "widget.ask.dj")
        artist = snapshot.artist ?? DJConnectLocalization.localized(key: "widget.ready")
        hasSnapshot = true
    }
#endif
}

struct DJConnectAskDJWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DJConnectAskDJWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DJConnectAskDJWidgetEntry) -> Void) {
        completion(Self.currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DJConnectAskDJWidgetEntry>) -> Void) {
        let entry = Self.currentEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private static func currentEntry() -> DJConnectAskDJWidgetEntry {
#if canImport(DJConnectCore)
        if let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier),
           let snapshot = DJConnectAskDJWidgetSnapshot.load(from: defaults) {
            return DJConnectAskDJWidgetEntry(snapshot: snapshot)
        }
#endif
        return .empty
    }
}

struct DJConnectAskDJWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DJConnectAskDJWidgetEntry

    var body: some View {
        ZStack {
            DJConnectAskDJWidgetBackground()
            content
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(DJConnectWidgetDeepLink.askDJ)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            small
        case .systemMedium:
            medium
        case .systemLarge, .systemExtraLarge:
            large
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryCircular:
            accessoryCircular
        case .accessoryInline:
            Label("Ask DJ", systemImage: "bubble.left.and.bubble.right")
        default:
            medium
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(compact: true)
            Spacer(minLength: 0)
            DJConnectAskDJOrb()
                .frame(width: 62, height: 62)
            Spacer(minLength: 0)
            Text("Ask DJ")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(entry.prompt)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.70))
                .lineLimit(1)
        }
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            DJConnectAskDJOrb()
                .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 8) {
                header(compact: false)
                Text(entry.response)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                Text(entry.mood)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 14) {
            header(compact: false)
            HStack(alignment: .center, spacing: 16) {
                DJConnectAskDJOrb()
                    .frame(width: 124, height: 124)
                VStack(alignment: .leading, spacing: 7) {
                    Text(entry.prompt)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(entry.response)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(4)
                }
            }
            DJConnectAskDJPromptRow(entry: entry)
            Spacer(minLength: 0)
            Text(entry.mood)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.60))
                .lineLimit(1)
        }
        .padding(18)
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text("Ask DJ")
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.prompt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .widgetAccentable()
        }
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.bold))
            Text(compact ? "Ask DJ" : "DJConnect Ask DJ")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white.opacity(0.84))
    }
}

private struct DJConnectAskDJWidgetBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.10),
                    Color(red: 0.09, green: 0.08, blue: 0.29),
                    Color(red: 0.24, green: 0.08, blue: 0.36)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Canvas { context, size in
                for index in 0..<42 {
                    let x = size.width * CGFloat((index * 19) % 43) / 42
                    let y = size.height * CGFloat((index * 31) % 47) / 46
                    let radius = CGFloat((index % 4) + 1)
                    let rect = CGRect(x: x, y: y, width: radius, height: radius)
                    let color = Color(hue: 0.58 + Double(index % 12) * 0.025, saturation: 0.82, brightness: 1)
                    context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.44)))
                }

                var path = Path()
                let baseY = size.height * 0.68
                let step = max(size.width / 28, 4)
                var x: CGFloat = -step
                var first = true
                while x <= size.width + step {
                    let progress = x / max(size.width, 1)
                    let point = CGPoint(
                        x: x,
                        y: baseY + sin(progress * .pi * 4.2) * size.height * 0.045
                    )
                    if first {
                        path.move(to: point)
                        first = false
                    } else {
                        path.addLine(to: point)
                    }
                    x += step
                }
                context.stroke(path, with: .color(.white.opacity(0.18)), lineWidth: 1.4)
            }
        }
    }
}

private struct DJConnectAskDJOrb: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.29, green: 0.62, blue: 1.0),
                            Color(red: 0.49, green: 0.34, blue: 1.0),
                            Color(red: 0.82, green: 0.28, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.20), lineWidth: 1)
                )
            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}

private struct DJConnectAskDJPromptRow: View {
    let entry: DJConnectAskDJWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            prompt("Analyze this track", systemImage: "waveform.path.ecg")
            prompt("Why does this vibe work?", systemImage: "bubble.left.and.bubble.right")
            prompt("What should play next?", systemImage: "music.note.list")
        }
    }

    private func prompt(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .frame(width: 18)
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.78))
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct DJConnectAskDJWidget: Widget {
    let kind = "DJConnectAskDJWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DJConnectAskDJWidgetProvider()) { entry in
            DJConnectAskDJWidgetView(entry: entry)
        }
        .configurationDisplayName("Ask DJ")
        .description("DJConnect Ask DJ widget for quick music questions and vibe context.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ]
        #else
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge
        ]
        #endif
    }
}

#if canImport(ActivityKit) && os(iOS)
@available(iOS 16.1, *)
struct DJConnectTrackInsightLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrackInsightLiveActivityAttributes.self) { context in
            DJConnectNowPlayingLiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(Color(red: 0.02, green: 0.04, blue: 0.10))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DJConnectNowPlayingArtwork(entry: context.state.widgetEntry)
                        .frame(width: 54, height: 54)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    DJConnectNowPlayingLiveActivityStatusStack(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DJConnectNowPlayingLiveActivityExpandedBottom(state: context.state)
                }
            } compactLeading: {
                Image(systemName: context.state.isPlaying ? "music.note" : "pause.fill")
                    .foregroundStyle(.white)
            } compactTrailing: {
                Text(context.state.compactProgress)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "music.note")
                    .foregroundStyle(.white)
            }
            .keylineTint(Color(red: 0.24, green: 0.64, blue: 1.0))
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectNowPlayingLiveActivityLockScreenView: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        let entry = state.widgetEntry
        HStack(spacing: 14) {
            DJConnectNowPlayingArtwork(entry: entry)
                .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 6) {
                Label(DJConnectLocalization.localized(key: "widget.now.playing"), systemImage: state.isPlaying ? "music.note" : "pause.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.84))
                    .textCase(.uppercase)
                Text(state.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(state.artist)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
                DJConnectNowPlayingLiveActivityDescriptorRow(state: state)
                DJConnectNowPlayingProgressBar(progress: state.progress)
                    .frame(height: 6)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background {
            DJConnectNowPlayingWidgetBackground(entry: entry)
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectNowPlayingLiveActivityExpandedBottom: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        let entry = state.widgetEntry
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(state.title)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                Text(state.artist)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            DJConnectNowPlayingLiveActivityDescriptorRow(state: state)
            DJConnectNowPlayingProgressBar(progress: state.progress)
                .frame(height: 6)
            DJConnectNowPlayingWaveform(entry: entry)
                .frame(height: 24)
        }
        .padding(10)
        .background {
            DJConnectNowPlayingWidgetBackground(entry: entry)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectNowPlayingLiveActivityDescriptorRow: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            Label(state.isPlaying ? DJConnectLocalization.localized(key: "widget.playing") : DJConnectLocalization.localized(key: "widget.paused"), systemImage: state.isPlaying ? "play.fill" : "pause.fill")
            if let compactProgress = state.progressText {
                Text(compactProgress)
            }
            if let deviceName = state.deviceName, !deviceName.isEmpty {
                Text(deviceName)
            }
            if let volumePercent = state.volumePercent {
                Text("\(volumePercent)%")
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white.opacity(0.72))
        .lineLimit(1)
    }
}

@available(iOS 16.1, *)
private struct DJConnectNowPlayingLiveActivityStatusStack: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Image(systemName: state.isPlaying ? "speaker.wave.2.fill" : "pause.circle")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(red: 0.24, green: 0.64, blue: 1.0))
            if let volumePercent = state.volumePercent {
                Text("\(volumePercent)%")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
            Text(state.deviceName ?? "DJConnect")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectNowPlayingLiveActivityOrb: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.2)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.18, green: 0.09, blue: 0.32),
                                Color(red: 0.02, green: 0.03, blue: 0.08)
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: 54
                        )
                    )
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .trim(from: 0.08, to: 0.74 + CGFloat(ring) * 0.06)
                        .stroke(
                            AngularGradient(
                                colors: [
                                Color(red: 0.30, green: 0.63, blue: 1.0),
                                Color(red: 0.78, green: 0.34, blue: 1.0),
                                Color(red: 0.16, green: 0.92, blue: 0.84),
                                Color(red: 0.30, green: 0.63, blue: 1.0)
                            ],
                            center: .center
                            ),
                            style: StrokeStyle(lineWidth: CGFloat(4 - ring), lineCap: .round)
                        )
                        .rotationEffect(.degrees(phase * (18 + Double(ring) * 7) + Double(state.animationSeed % 120)))
                        .padding(CGFloat(ring) * 7 + 5)
                        .opacity(0.92 - Double(ring) * 0.18)
                }
                Image(systemName: state.isPlaying ? "play.fill" : "pause.fill")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectNowPlayingLiveActivityWaveform: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let bars = 26
                let barWidth = size.width / CGFloat(bars)
                let energy = state.isPlaying ? 0.78 : 0.42
                for index in 0..<bars {
                    let seed = Double((index * 29 + state.animationSeed) % 97) / 97
                    let pulse = state.isPlaying ? (sin(phase * 1.7 + Double(index) * 0.45) + 1) / 2 : 0.28
                    let height = size.height * (0.18 + 0.52 * seed * energy + 0.22 * pulse)
                    let rect = CGRect(
                        x: CGFloat(index) * barWidth,
                        y: size.height - height,
                        width: max(2, barWidth * 0.48),
                        height: height
                    )
                    let color = Color(hue: 0.58 + Double(index) / Double(bars) * 0.24, saturation: 0.86, brightness: 1)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color.opacity(0.78)))
                }
            }
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectNowPlayingLiveActivityBackground: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        ZStack {
            DJConnectLiveActivityGradient()
            DJConnectNowPlayingLiveActivityWaveform(state: state)
                .opacity(0.20)
                .padding(.top, 48)
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectLiveActivityGradient: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.34),
                    Color(red: 0.24, green: 0.18, blue: 0.58),
                    Color(red: 0.73, green: 0.22, blue: 0.96),
                    Color(red: 0.08, green: 0.74, blue: 0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 4,
                endRadius: 260
            )
            LinearGradient(
                colors: [
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.46)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

@available(iOS 16.1, *)
private extension TrackInsightLiveActivityAttributes.ContentState {
    var widgetEntry: DJConnectNowPlayingWidgetEntry {
        DJConnectNowPlayingWidgetEntry(
            date: Date(),
            title: title,
            artist: artist,
            artworkURL: nil,
            progress: progress,
            isPlaying: isPlaying,
            deviceName: deviceName ?? "DJConnect",
            hasSnapshot: true
        )
    }

    var compactProgress: String {
        progressText ?? (isPlaying ? DJConnectLocalization.localized(key: "widget.on") : DJConnectLocalization.localized(key: "widget.off"))
    }

    var progressText: String? {
        guard let progressMS, let durationMS, durationMS > 0 else {
            return nil
        }
        return "\(formatTime(progressMS))/\(formatTime(durationMS))"
    }

    private func formatTime(_ milliseconds: Int) -> String {
        let seconds = max(0, milliseconds / 1_000)
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}
#endif

@main
struct DJConnectTrackInsightWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DJConnectNowPlayingWidget()
        DJConnectQueueWidget()
        DJConnectPlaylistsWidget()
        DJConnectTrackInsightWidget()
        DJConnectAskDJWidget()
        #if canImport(ActivityKit) && os(iOS)
        if #available(iOS 16.1, *) {
            DJConnectTrackInsightLiveActivityWidget()
        }
        #endif
    }
}
