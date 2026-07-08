import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(DJConnectCore)
import DJConnectCore
#endif

private enum DJConnectWidgetDeepLink {
    static let nowPlaying = URL(string: "djconnect://now-playing")!
    static let queue = URL(string: "djconnect://queue")!
    static let trackInsight = URL(string: "djconnect://track-insight")!
    static let askDJ = URL(string: "djconnect://ask-dj")!
}

private enum DJConnectWidgetIcon {
    static let queue = "music.note.list"
    static let askDJ = "bubble.left.and.bubble.right"
}

private struct DJConnectWidgetMoodPalette {
    let colors: [Color]
    let backgroundColors: [Color]
    let glow: Double

    init(stepIndex: Int) {
        switch max(0, min(3, stepIndex)) {
        case 0:
            colors = [
                Color(red: 0.07, green: 0.19, blue: 0.31),
                Color(red: 0.10, green: 0.42, blue: 0.48),
                Color(red: 0.32, green: 0.72, blue: 0.62)
            ]
            backgroundColors = [
                Color(red: 0.01, green: 0.04, blue: 0.08),
                Color(red: 0.04, green: 0.13, blue: 0.21),
                Color(red: 0.07, green: 0.30, blue: 0.34),
                Color(red: 0.19, green: 0.46, blue: 0.40)
            ]
            glow = 0.38
        case 1:
            colors = [
                Color(red: 0.10, green: 0.14, blue: 0.30),
                Color(red: 0.24, green: 0.38, blue: 0.72),
                Color(red: 0.76, green: 0.50, blue: 0.22)
            ]
            backgroundColors = [
                Color(red: 0.02, green: 0.04, blue: 0.10),
                Color(red: 0.07, green: 0.10, blue: 0.25),
                Color(red: 0.17, green: 0.25, blue: 0.50),
                Color(red: 0.42, green: 0.29, blue: 0.17)
            ]
            glow = 0.52
        case 2:
            colors = [
                Color(red: 0.17, green: 0.10, blue: 0.31),
                Color(red: 0.58, green: 0.24, blue: 0.72),
                Color(red: 0.20, green: 0.76, blue: 0.82)
            ]
            backgroundColors = [
                Color(red: 0.03, green: 0.03, blue: 0.10),
                Color(red: 0.10, green: 0.07, blue: 0.28),
                Color(red: 0.34, green: 0.13, blue: 0.44),
                Color(red: 0.09, green: 0.44, blue: 0.50)
            ]
            glow = 0.68
        default:
            colors = [
                Color(red: 0.30, green: 0.08, blue: 0.20),
                Color(red: 0.92, green: 0.22, blue: 0.44),
                Color(red: 1.00, green: 0.68, blue: 0.18)
            ]
            backgroundColors = [
                Color(red: 0.08, green: 0.02, blue: 0.06),
                Color(red: 0.24, green: 0.06, blue: 0.16),
                Color(red: 0.54, green: 0.12, blue: 0.25),
                Color(red: 0.62, green: 0.36, blue: 0.08)
            ]
            glow = 0.86
        }
    }

    var accentGradient: LinearGradient {
        LinearGradient(colors: [colors[1], colors[2]], startPoint: .leading, endPoint: .trailing)
    }
}

private enum DJConnectWidgetMood {
    static let storageKey = "DJConnectAskDJMood"

    static var currentStepIndex: Int {
        let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier)
        let mood = defaults?.object(forKey: storageKey) == nil ? 50.0 : defaults?.double(forKey: storageKey) ?? 50.0
        switch max(0, min(100, Int(mood.rounded()))) {
        case 0...24:
            return 0
        case 25...59:
            return 1
        case 60...84:
            return 2
        default:
            return 3
        }
    }
}

private func DJConnectWidgetImage(data: Data) -> Image? {
    #if canImport(UIKit)
    guard let image = UIImage(data: data) else { return nil }
    return Image(uiImage: image)
    #elseif canImport(AppKit)
    guard let image = NSImage(data: data) else { return nil }
    return Image(nsImage: image)
    #else
    return nil
    #endif
}

struct DJConnectNowPlayingWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let artist: String
    let artworkURL: URL?
    let artworkData: Data?
    let progress: Double
    let progressMS: Int?
    let durationMS: Int?
    let isPlaying: Bool
    let deviceName: String
    let hasSnapshot: Bool

    init(
        date: Date,
        title: String,
        artist: String,
        artworkURL: URL?,
        artworkData: Data? = nil,
        progress: Double,
        progressMS: Int? = nil,
        durationMS: Int? = nil,
        isPlaying: Bool,
        deviceName: String,
        hasSnapshot: Bool
    ) {
        self.date = date
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.artworkData = artworkData
        self.progress = max(0, min(1, progress))
        self.progressMS = progressMS.map { max(0, $0) }
        self.durationMS = durationMS.map { max(0, $0) }
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
        artworkData = snapshot.artworkData
        self.progress = max(0, min(1, progress))
        progressMS = snapshot.progressMS
        durationMS = snapshot.durationMS
        isPlaying = snapshot.isPlaying
        deviceName = snapshot.deviceName ?? DJConnectLocalization.localized(key: "widget.djconnect")
        hasSnapshot = true
    }
#endif

    func progress(at date: Date) -> Double {
        guard let durationMS, durationMS > 0 else {
            return progress
        }
        let baseProgressMS = progressMS ?? Int(progress * Double(durationMS))
        let elapsedMS = isPlaying ? max(0, Int(date.timeIntervalSince(self.date) * 1_000)) : 0
        return max(0, min(1, Double(baseProgressMS + elapsedMS) / Double(durationMS)))
    }
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
        .containerBackground(for: .widget) {
            DJConnectNowPlayingWidgetBackground(entry: entry)
        }
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
        VStack(alignment: .leading, spacing: 9) {
            smallPlaybackStatus
            Spacer(minLength: 0)
            DJConnectNowPlayingArtwork(entry: entry)
                .frame(width: 64, height: 64)
            Spacer(minLength: 0)
            titleBlock(lineLimit: 1)
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
                nowPlayingProgressBar
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
            nowPlayingProgressBar
                .frame(height: 7)
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

    private var nowPlayingProgressBar: some View {
        TimelineView(.periodic(from: entry.date, by: 30)) { timeline in
            DJConnectNowPlayingProgressBar(progress: entry.progress(at: timeline.date))
        }
    }

    private var smallPlaybackStatus: some View {
        Label(
            entry.isPlaying
                ? DJConnectLocalization.localized(key: "widget.playing")
                : DJConnectLocalization.localized(key: "widget.paused"),
            systemImage: entry.isPlaying ? "play.fill" : "pause.fill"
        )
        .font(.caption.weight(.bold))
        .textCase(.uppercase)
        .foregroundStyle(.white.opacity(0.84))
        .lineLimit(1)
        .minimumScaleFactor(0.78)
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
    var allowsRemoteArtwork = true

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
            if let artworkData = entry.artworkData,
               let image = DJConnectWidgetImage(data: artworkData) {
                image
                    .resizable()
                    .scaledToFill()
            } else if allowsRemoteArtwork, let artworkURL = entry.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        DJConnectNowPlayingArtworkFallback()
                    }
                }
            } else {
                DJConnectNowPlayingArtworkFallback()
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
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                LinearGradient(
                    colors: palette.backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        palette.colors[2].opacity(0.42),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 2,
                    endRadius: max(32, side * 1.5)
                )
                DJConnectMusicPlayArtworkIcon()
                    .frame(width: max(14, side * 0.72), height: max(14, side * 0.72))
                    .shadow(color: palette.colors[1].opacity(0.36), radius: max(4, side * 0.18), x: 0, y: max(1, side * 0.08))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DJConnectMusicPlayArtworkIcon: View {
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle()
                    .fill(.white.opacity(0.14))
                Circle()
                    .stroke(palette.accentGradient, lineWidth: max(1.5, side * 0.035))
                Image(systemName: "music.note")
                    .font(.system(size: side * 0.52, weight: .semibold))
                    .foregroundStyle(palette.accentGradient)
                    .offset(x: -side * 0.09, y: -side * 0.07)
                Image(systemName: "play.fill")
                    .font(.system(size: side * 0.31, weight: .black))
                    .foregroundStyle(.white.opacity(0.94))
                    .offset(x: side * 0.21, y: side * 0.19)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct DJConnectNowPlayingProgressBar: View {
    let progress: Double
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.18))
                Capsule()
                    .fill(palette.accentGradient)
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
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

    var body: some View {
        LinearGradient(
            colors: palette.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct DJConnectNowPlayingWidget: Widget {
    let kind = DJConnectNowPlayingWidgetSnapshot.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DJConnectNowPlayingWidgetProvider()) { entry in
            DJConnectNowPlayingWidgetView(entry: entry)
        }
        .configurationDisplayName(DJConnectLocalization.localized(key: "widget.now.playing"))
        .description(DJConnectLocalization.localized(key: "widget.now.playing.description"))
        .supportedFamilies(supportedFamilies)
        .contentMarginsDisabled()
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
        .containerBackground(for: .widget) {
            DJConnectQueueWidgetBackground()
        }
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
            Label(accessoryInlineTitle, systemImage: DJConnectWidgetIcon.queue)
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
            Image(systemName: DJConnectWidgetIcon.queue)
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
            Image(systemName: DJConnectWidgetIcon.queue)
                .font(.system(size: 17, weight: .semibold))
                .widgetAccentable()
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: DJConnectWidgetIcon.queue)
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
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: palette.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if let artworkData = item.artworkData,
               let image = DJConnectWidgetImage(data: artworkData) {
                image
                    .resizable()
                    .scaledToFill()
            } else if let artworkURL = item.artworkURL {
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
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.colors[1].opacity(0.34),
                            palette.colors[2].opacity(0.34)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: DJConnectWidgetIcon.queue)
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
        }
    }
}

private struct DJConnectQueueWidgetBackground: View {
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

    var body: some View {
        LinearGradient(
            colors: palette.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct DJConnectQueueWidget: Widget {
    let kind = DJConnectQueueWidgetSnapshot.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DJConnectQueueWidgetProvider()) { entry in
            DJConnectQueueWidgetView(entry: entry)
        }
        .configurationDisplayName(DJConnectLocalization.localized(key: "widget.queue"))
        .description(DJConnectLocalization.localized(key: "widget.queue.description"))
        .supportedFamilies(supportedFamilies)
        .contentMarginsDisabled()
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
    let energy: Double
    let danceability: Double
    let intensity: Double
    let progress: TimeInterval?
    let duration: TimeInterval?
    let artworkURL: URL?
    let artworkData: Data?
    let summary: String
    let hasSnapshot: Bool

    init(
        date: Date,
        title: String,
        artist: String,
        genre: String,
        mood: String,
        vibe: String,
        energy: Double,
        danceability: Double,
        intensity: Double,
        progress: TimeInterval?,
        duration: TimeInterval?,
        artworkURL: URL? = nil,
        artworkData: Data? = nil,
        summary: String,
        hasSnapshot: Bool
    ) {
        self.date = date
        self.title = title
        self.artist = artist
        self.genre = genre
        self.mood = mood
        self.vibe = vibe
        self.energy = energy
        self.danceability = danceability
        self.intensity = intensity
        self.progress = progress
        self.duration = duration
        self.artworkURL = artworkURL
        self.artworkData = artworkData
        self.summary = summary
        self.hasSnapshot = hasSnapshot
    }

    static let placeholder = DJConnectTrackInsightWidgetEntry(
        date: Date(),
        title: "Neon Skyline",
        artist: "DJConnect Radio",
        genre: "Deep House",
        mood: DJConnectLocalization.localized(key: "widget.preview.mood.dreamy"),
        vibe: "Cinematic",
        energy: 0.65,
        danceability: 0.72,
        intensity: 0.58,
        progress: 138,
        duration: 200,
        artworkURL: nil,
        artworkData: nil,
        summary: DJConnectLocalization.localized(key: "widget.track.insight.placeholder.summary"),
        hasSnapshot: true
    )

    static let empty = DJConnectTrackInsightWidgetEntry(
        date: Date(),
        title: DJConnectLocalization.localized(key: "widget.no.track.insight.yet"),
        artist: DJConnectLocalization.localized(key: "widget.open.djconnect"),
        genre: DJConnectLocalization.localized(key: "widget.private"),
        mood: DJConnectLocalization.localized(key: "widget.ready"),
        vibe: DJConnectLocalization.localized(key: "widget.on.device"),
        energy: 0.5,
        danceability: 0.5,
        intensity: 0.5,
        progress: nil,
        duration: nil,
        artworkURL: nil,
        artworkData: nil,
        summary: DJConnectLocalization.localized(key: "widget.run.track.insight.in.the.app.to.update.this"),
        hasSnapshot: false
    )

#if canImport(DJConnectCore)
    init(snapshot: DJConnectTrackInsightWidgetSnapshot, fallbackArtworkURL: URL? = nil, fallbackArtworkData: Data? = nil) {
        date = snapshot.updatedAt
        title = snapshot.title
        artist = snapshot.artist
        genre = snapshot.genre ?? DJConnectLocalization.localized(key: "widget.unknown.genre")
        mood = snapshot.mood ?? DJConnectLocalization.localized(key: "widget.evolving")
        vibe = snapshot.vibe ?? DJConnectLocalization.localized(key: "widget.fresh")
        energy = snapshot.energy ?? 0.5
        danceability = snapshot.danceability ?? 0.5
        intensity = snapshot.intensity ?? 0.5
        progress = snapshot.progress
        duration = snapshot.duration
        artworkURL = snapshot.artworkURL ?? fallbackArtworkURL
        artworkData = snapshot.artworkData ?? fallbackArtworkData
        summary = snapshot.summary
        hasSnapshot = true
    }

    func withCurrentTrackArtwork(url artworkURL: URL?, data artworkData: Data?) -> DJConnectTrackInsightWidgetEntry {
        DJConnectTrackInsightWidgetEntry(
            date: date,
            title: title,
            artist: artist,
            genre: genre,
            mood: mood,
            vibe: vibe,
            energy: energy,
            danceability: danceability,
            intensity: intensity,
            progress: progress,
            duration: duration,
            artworkURL: artworkURL,
            artworkData: artworkData,
            summary: summary,
            hasSnapshot: hasSnapshot
        )
    }
#endif
}

struct DJConnectTrackInsightWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DJConnectTrackInsightWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DJConnectTrackInsightWidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder : Self.currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DJConnectTrackInsightWidgetEntry>) -> Void) {
        let entry = Self.currentEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private static func currentEntry() -> DJConnectTrackInsightWidgetEntry {
#if canImport(DJConnectCore)
        if let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier) {
            let nowPlaying = DJConnectNowPlayingWidgetSnapshot.load(from: defaults)
            if let snapshot = DJConnectTrackInsightWidgetSnapshot.load(from: defaults) {
                return DJConnectTrackInsightWidgetEntry(
                    snapshot: snapshot,
                    fallbackArtworkURL: nowPlaying?.artworkURL,
                    fallbackArtworkData: nowPlaying?.artworkData
                )
            }
            return DJConnectTrackInsightWidgetEntry.empty.withCurrentTrackArtwork(
                url: nowPlaying?.artworkURL,
                data: nowPlaying?.artworkData
            )
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
        .containerBackground(for: .widget) {
            DJConnectTrackInsightWidgetBackground(entry: entry)
        }
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
            DJConnectTrackInsightArtwork(entry: entry)
                .frame(width: 58, height: 58)
            Spacer(minLength: 0)
            titleBlock(lineLimit: 1)
            progressOrMetricRow
        }
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            DJConnectTrackInsightArtwork(entry: entry)
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
                DJConnectTrackInsightArtwork(entry: entry)
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
            if entry.hasSnapshot {
                DJConnectTrackInsightMeterRow(entry: entry)
            }
            Spacer(minLength: 0)
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
                Text(progressLabel ?? (entry.hasSnapshot ? entry.genre : entry.summary))
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
            Text(entry.hasSnapshot && compact ? "Insight" : "Track Insight")
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
        Group {
            if entry.hasSnapshot {
                Text(entry.genre)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
            }
        }
    }

    private var progressOrMetricRow: some View {
        Group {
            if let progressLabel {
                Text(progressLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
            } else if entry.hasSnapshot {
                Text(entry.genre)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
            }
        }
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
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

    var body: some View {
        LinearGradient(
            colors: palette.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
                    let seed = Double((index * 37 + spectrumSeed) % 100) / 100
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

    private var spectrumSeed: Int {
        "\(entry.title)|\(entry.artist)|\(entry.genre)".unicodeScalars.reduce(0) {
            (($0 &* 31) &+ Int($1.value)) & 0x7fffffff
        }
    }
}

private struct DJConnectTrackInsightOrb: View {
    let entry: DJConnectTrackInsightWidgetEntry
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .black.opacity(0.10),
                            palette.colors[0].opacity(0.96),
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
                                palette.colors[1],
                                palette.colors[2],
                                palette.colors[0],
                                palette.colors[1]
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

private struct DJConnectTrackInsightArtwork: View {
    let entry: DJConnectTrackInsightWidgetEntry
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.11))
                .blur(radius: 14)
                .scaleEffect(1.12)
            artwork
            DJConnectTrackInsightArtworkSpectrum(entry: entry)
                .padding(.horizontal, 11)
                .padding(.bottom, 10)
                .frame(maxHeight: .infinity, alignment: .bottom)
            LinearGradient(
                colors: [.clear, .black.opacity(0.34)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: palette.colors[1].opacity(0.24 + palette.glow * 0.12), radius: 16, x: 0, y: 10)
    }

    @ViewBuilder
    private var artwork: some View {
        if let artworkData = entry.artworkData,
           let image = DJConnectWidgetImage(data: artworkData) {
            image
                .resizable()
                .scaledToFill()
        } else if let artworkURL = entry.artworkURL {
            AsyncImage(url: artworkURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    fallback
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: palette.backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            DJConnectTrackInsightOrb(entry: entry)
                .padding(12)
        }
    }
}

private struct DJConnectTrackInsightArtworkSpectrum: View {
    let entry: DJConnectTrackInsightWidgetEntry
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

    var body: some View {
        GeometryReader { geometry in
            let count = 18
            let spacing: CGFloat = 2
            let spectrumWidth = geometry.size.width * 0.86
            let barWidth = max(2, (spectrumWidth - CGFloat(count - 1) * spacing) / CGFloat(count))
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(0..<count, id: \.self) { index in
                    let value = spectrumValue(index: index, count: count)
                    RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    palette.colors[1].opacity(0.88),
                                    palette.colors[2].opacity(0.94)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: barWidth, height: max(4, geometry.size.height * value))
                }
            }
            .frame(width: spectrumWidth)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 26)
        .allowsHitTesting(false)
    }

    private func spectrumValue(index: Int, count: Int) -> CGFloat {
        let position = Double(index) / Double(max(count - 1, 1))
        let wave = (sin(Double(index) * 0.74 + Double(spectrumSeed) * 0.03) + 1) * 0.5
        let centerLift = max(0, 1 - abs(position - 0.54) * 2.4)
        return CGFloat(min(1, 0.18 + entry.energy * 0.24 + entry.intensity * 0.18 + wave * 0.24 + centerLift * 0.18))
    }

    private var spectrumSeed: Int {
        "\(entry.title)|\(entry.artist)|\(entry.genre)".unicodeScalars.reduce(0) {
            (($0 &* 31) &+ Int($1.value)) & 0x7fffffff
        }
    }
}

private struct DJConnectTrackInsightMeterRow: View {
    let entry: DJConnectTrackInsightWidgetEntry
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

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
                        .fill(palette.accentGradient)
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
        .configurationDisplayName(DJConnectLocalization.localized(key: "widget.track.insight"))
        .description(DJConnectLocalization.localized(key: "widget.track.insight.description"))
        .supportedFamilies(supportedFamilies)
        .contentMarginsDisabled()
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
    let artworkURL: URL?
    let artworkData: Data?
    let hasSnapshot: Bool

    init(
        date: Date,
        prompt: String,
        response: String,
        mood: String,
        trackTitle: String,
        artist: String,
        artworkURL: URL?,
        artworkData: Data? = nil,
        hasSnapshot: Bool
    ) {
        self.date = date
        self.prompt = prompt
        self.response = response
        self.mood = mood
        self.trackTitle = trackTitle
        self.artist = artist
        self.artworkURL = artworkURL
        self.artworkData = artworkData
        self.hasSnapshot = hasSnapshot
    }

    static let placeholder = DJConnectAskDJWidgetEntry(
        date: Date(),
        prompt: DJConnectLocalization.localized(key: "widget.ask.dj.example.why.does.this.vibe.work"),
        response: DJConnectLocalization.localized(key: "widget.ask.dj.placeholder.response"),
        mood: DJConnectLocalization.localized(key: "widget.private.on.device.music.dna"),
        trackTitle: "Neon Skyline",
        artist: "DJConnect Radio",
        artworkURL: nil,
        hasSnapshot: true
    )

    static let empty = DJConnectAskDJWidgetEntry(
        date: Date(),
        prompt: DJConnectLocalization.localized(key: "widget.ask.dj"),
        response: DJConnectLocalization.localized(key: "widget.ask.dj.in.the.app.to.update.this.widget"),
        mood: DJConnectLocalization.localized(key: "widget.private.on.device"),
        trackTitle: DJConnectLocalization.localized(key: "widget.no.ask.dj.snapshot.yet"),
        artist: "DJConnect",
        artworkURL: nil,
        hasSnapshot: false
    )

#if canImport(DJConnectCore)
    init(snapshot: DJConnectAskDJWidgetSnapshot, artworkURL: URL?, artworkData: Data?) {
        date = snapshot.updatedAt
        prompt = snapshot.prompt
        response = snapshot.response
        mood = snapshot.context
        trackTitle = snapshot.trackTitle ?? DJConnectLocalization.localized(key: "widget.ask.dj")
        artist = snapshot.artist ?? DJConnectLocalization.localized(key: "widget.ready")
        self.artworkURL = artworkURL
        self.artworkData = artworkData
        hasSnapshot = true
    }
#endif

    func withCurrentTrackArtwork(url artworkURL: URL?, data artworkData: Data?) -> DJConnectAskDJWidgetEntry {
        DJConnectAskDJWidgetEntry(
            date: date,
            prompt: prompt,
            response: response,
            mood: mood,
            trackTitle: trackTitle,
            artist: artist,
            artworkURL: artworkURL,
            artworkData: artworkData,
            hasSnapshot: hasSnapshot
        )
    }

    static func emptyForCurrentTrack(_ nowPlaying: DJConnectNowPlayingWidgetSnapshot) -> DJConnectAskDJWidgetEntry {
        DJConnectAskDJWidgetEntry(
            date: nowPlaying.updatedAt,
            prompt: DJConnectLocalization.localized(key: "widget.ask.dj"),
            response: DJConnectLocalization.localized(key: "widget.ask.dj.in.the.app.to.update.this.widget"),
            mood: DJConnectLocalization.localized(key: "widget.private.on.device"),
            trackTitle: nowPlaying.title.isEmpty ? DJConnectLocalization.localized(key: "widget.ask.dj") : nowPlaying.title,
            artist: nowPlaying.artist.isEmpty ? DJConnectLocalization.localized(key: "widget.ready") : nowPlaying.artist,
            artworkURL: nowPlaying.artworkURL,
            artworkData: nowPlaying.artworkData,
            hasSnapshot: false
        )
    }
}

struct DJConnectAskDJWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DJConnectAskDJWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DJConnectAskDJWidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder : Self.currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DJConnectAskDJWidgetEntry>) -> Void) {
        let entry = Self.currentEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private static func currentEntry() -> DJConnectAskDJWidgetEntry {
#if canImport(DJConnectCore)
        if let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier) {
            let nowPlaying = DJConnectNowPlayingWidgetSnapshot.load(from: defaults)
            let artworkURL = nowPlaying?.artworkURL
            let artworkData = nowPlaying?.artworkData
            if let snapshot = DJConnectAskDJWidgetSnapshot.load(from: defaults) {
                return DJConnectAskDJWidgetEntry(snapshot: snapshot, artworkURL: artworkURL, artworkData: artworkData)
            }
            if let nowPlaying {
                return DJConnectAskDJWidgetEntry.emptyForCurrentTrack(nowPlaying)
            }
            return .empty
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
        .containerBackground(for: .widget) {
            DJConnectAskDJWidgetBackground()
        }
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
            Label(localizedKey("widget.ask.dj"), systemImage: "bubble.left.and.bubble.right")
        default:
            medium
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(compact: true)
            Spacer(minLength: 0)
            DJConnectAskDJArtwork(entry: entry)
                .frame(width: 62, height: 62)
            Spacer(minLength: 0)
            Text(localizedKey("widget.ask.dj"))
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
            DJConnectAskDJArtwork(entry: entry)
                .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 8) {
                header(compact: false)
                Text(entry.response)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 14) {
            header(compact: false)
            HStack(alignment: .center, spacing: 16) {
                DJConnectAskDJArtwork(entry: entry)
                    .frame(width: 124, height: 124)
                VStack(alignment: .leading, spacing: 7) {
                    Text(entry.trackTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(entry.artist)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(2)
                }
            }
            if entry.hasSnapshot {
                DJConnectAskDJLatestMessagePanel(entry: entry)
            } else {
                DJConnectAskDJPromptRow(entry: entry)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: DJConnectWidgetIcon.askDJ)
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text(localizedKey("widget.ask.dj"))
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
            Image(systemName: DJConnectWidgetIcon.askDJ)
                .font(.system(size: 18, weight: .semibold))
                .widgetAccentable()
        }
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: DJConnectWidgetIcon.askDJ)
                .font(.caption.weight(.bold))
            Text(localizedKey("widget.ask.dj"))
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white.opacity(0.84))
    }

    private func localizedKey(_ key: String) -> String {
        DJConnectLocalization.localized(key: key)
    }
}

private struct DJConnectAskDJWidgetBackground: View {
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

    var body: some View {
        LinearGradient(
            colors: palette.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct DJConnectAskDJOrb: View {
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: palette.colors,
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

private struct DJConnectAskDJArtwork: View {
    let entry: DJConnectAskDJWidgetEntry

    var body: some View {
        ZStack {
            if let artworkData = entry.artworkData,
               let image = DJConnectWidgetImage(data: artworkData) {
                image
                    .resizable()
                    .scaledToFill()
            } else if let artworkURL = entry.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        DJConnectAskDJOrb()
                    }
                }
            } else {
                DJConnectAskDJOrb()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 1)
        )
    }
}

private struct DJConnectAskDJPromptRow: View {
    let entry: DJConnectAskDJWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            prompt(localizedKey("widget.ask.dj.example.analyze.this.track"), systemImage: "waveform.path.ecg")
            prompt(localizedKey("widget.ask.dj.example.why.does.this.vibe.work"), systemImage: "bubble.left.and.bubble.right")
            prompt(localizedKey("widget.ask.dj.example.what.should.play.next"), systemImage: "music.note.list")
        }
    }

    private func localizedKey(_ key: String) -> String {
        DJConnectLocalization.localized(key: key)
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

private struct DJConnectAskDJLatestMessagePanel: View {
    let entry: DJConnectAskDJWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            messageLine(
                text: entry.response,
                systemImage: "sparkles",
                font: .callout.weight(.semibold),
                opacity: 0.90,
                lineLimit: 5
            )
            if !entry.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messageLine(
                    text: entry.prompt,
                    systemImage: "quote.opening",
                    font: .caption.weight(.semibold),
                    opacity: 0.62,
                    lineLimit: 2
                )
            }
        }
    }

    private func messageLine(
        text: String,
        systemImage: String,
        font: Font,
        opacity: Double,
        lineLimit: Int
    ) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage)
                .frame(width: 18)
                .padding(.top, 1)
            Text(text)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(font)
        .foregroundStyle(.white.opacity(opacity))
        .padding(.vertical, 8)
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
        .configurationDisplayName(DJConnectLocalization.localized(key: "widget.ask.dj"))
        .description(DJConnectLocalization.localized(key: "widget.ask.dj.description"))
        .supportedFamilies(supportedFamilies)
        .contentMarginsDisabled()
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
                .containerBackground(for: .widget) {
                    DJConnectNowPlayingLiveActivityBackground(state: context.state)
                }
                .activityBackgroundTint(DJConnectLiveActivityMoodBackgroundTint())
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    DJConnectNowPlayingLiveActivityExpandedHeaderView(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    DJConnectNowPlayingLiveActivityCompactPlaybackIcon(state: context.state)
                        .font(.title3.weight(.black))
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DJConnectNowPlayingLiveActivityExpandedIslandView(state: context.state)
                }
            } compactLeading: {
                DJConnectNowPlayingLiveActivityCompactArtwork(state: context.state)
            } compactTrailing: {
                DJConnectNowPlayingLiveActivityCompactPlaybackIcon(state: context.state)
            } minimal: {
                DJConnectNowPlayingLiveActivityCompactPlaybackIcon(state: context.state)
            }
            .keylineTint(DJConnectLiveActivityMoodKeylineColor())
        }
        .contentMarginsDisabled()
    }
}

@available(iOS 16.1, *)
private struct DJConnectNowPlayingLiveActivityCompactArtwork: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        DJConnectNowPlayingLiveActivityArtwork(state: state, cornerRadius: 10)
            .frame(width: 22, height: 22)
            .shadow(color: DJConnectLiveActivityMoodKeylineColor().opacity(0.36), radius: 5, x: 0, y: 2)
            .accessibilityHidden(true)
    }
}

@available(iOS 16.1, *)
private struct DJConnectNowPlayingLiveActivityArtwork: View {
    let state: TrackInsightLiveActivityAttributes.ContentState
    var cornerRadius: CGFloat = 18

    private var entry: DJConnectNowPlayingWidgetEntry {
        state.widgetEntry
    }

    var body: some View {
        ZStack {
            if let artworkData = entry.artworkData,
               let image = DJConnectWidgetImage(data: artworkData) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                DJConnectNowPlayingLiveActivityArtworkFallback()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 1)
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectNowPlayingLiveActivityArtworkFallback: View {
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                LinearGradient(
                    colors: palette.backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        palette.colors[2].opacity(0.46),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 2,
                    endRadius: max(24, side * 1.45)
                )
                Circle()
                    .fill(.white.opacity(0.13))
                    .frame(width: side * 0.74, height: side * 0.74)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [palette.colors[1], palette.colors[2]],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1.4, side * 0.035)
                    )
                    .frame(width: side * 0.74, height: side * 0.74)
                Image(systemName: "music.note")
                    .font(.system(size: side * 0.36, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [palette.colors[1], palette.colors[2]],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectNowPlayingLiveActivityLockScreenView: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            DJConnectNowPlayingLiveActivityArtwork(state: state)
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
            DJConnectNowPlayingLiveActivityBackground(state: state)
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectNowPlayingLiveActivityExpandedIslandView: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            DJConnectNowPlayingProgressBar(progress: state.progress)
                .frame(height: 6)
            DJConnectNowPlayingLiveActivityDescriptorRow(state: state)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 286, alignment: .leading)
        .background {
            Color.white.opacity(0.10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectNowPlayingLiveActivityExpandedTitleView: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(DJConnectLocalization.localized(key: "widget.now.playing"), systemImage: state.isPlaying ? "music.note" : "pause.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
                .textCase(.uppercase)
                .lineLimit(1)
            Text(state.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Text(state.artist)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

@available(iOS 16.1, *)
private struct DJConnectNowPlayingLiveActivityExpandedHeaderView: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 9) {
            DJConnectNowPlayingLiveActivityArtwork(state: state, cornerRadius: 17)
                .frame(width: 38, height: 38)
                .shadow(color: DJConnectLiveActivityMoodKeylineColor().opacity(0.28), radius: 8, x: 0, y: 4)
                .accessibilityHidden(true)
            DJConnectNowPlayingLiveActivityExpandedTitleView(state: state)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(width: 338, alignment: .leading)
        .background {
            DJConnectNowPlayingLiveActivityBackground(state: state)
                .frame(width: 338, height: 152)
                .offset(y: 4)
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
        .minimumScaleFactor(0.76)
    }
}

@available(iOS 16.1, *)
private struct DJConnectNowPlayingLiveActivityCompactPlaybackIcon: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        Image(systemName: state.isPlaying ? "play.fill" : "pause.fill")
            .font(.caption.weight(.black))
            .foregroundStyle(DJConnectLiveActivityAccentGradient())
            .accessibilityLabel(
                state.isPlaying
                    ? DJConnectLocalization.localized(key: "widget.playing")
                    : DJConnectLocalization.localized(key: "widget.paused")
            )
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
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

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
                    let color = palette.colors[index % palette.colors.count]
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
private struct DJConnectLiveActivityAccentGradient: ShapeStyle {
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        LinearGradient(
            colors: [palette.colors[1], palette.colors[2]],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

@available(iOS 16.1, *)
private func DJConnectLiveActivityMoodKeylineColor() -> Color {
    DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex).colors[1]
}

@available(iOS 16.1, *)
private func DJConnectLiveActivityMoodBackgroundTint() -> Color {
    DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex).backgroundColors[1]
}

@available(iOS 16.1, *)
private struct DJConnectLiveActivityGradient: View {
    private let palette = DJConnectWidgetMoodPalette(stepIndex: DJConnectWidgetMood.currentStepIndex)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: palette.backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [
                    palette.colors[2].opacity(0.26 + palette.glow * 0.16),
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
        let cachedSnapshot = matchingNowPlayingSnapshot
        return DJConnectNowPlayingWidgetEntry(
            date: Date(),
            title: title,
            artist: artist,
            artworkURL: cachedSnapshot?.artworkURL ?? artworkURL,
            artworkData: cachedSnapshot?.artworkData,
            progress: progress,
            isPlaying: isPlaying,
            deviceName: deviceName ?? "DJConnect",
            hasSnapshot: true
        )
    }

    private var matchingNowPlayingSnapshot: DJConnectNowPlayingWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier),
              let snapshot = DJConnectNowPlayingWidgetSnapshot.load(from: defaults),
              Self.matchesNowPlayingSnapshot(snapshot, title: title, artist: artist, artworkURL: artworkURL) else {
            return nil
        }
        return snapshot
    }

    private static func matchesNowPlayingSnapshot(_ snapshot: DJConnectNowPlayingWidgetSnapshot, title: String, artist: String, artworkURL: URL?) -> Bool {
        if let artworkURL,
           snapshot.artworkURL == artworkURL {
            return true
        }

        let snapshotTitle = normalizedTrackIdentity(snapshot.title)
        let stateTitle = normalizedTrackIdentity(title)
        guard !snapshotTitle.isEmpty,
              snapshotTitle == stateTitle else {
            return false
        }

        let snapshotArtist = normalizedTrackIdentity(snapshot.artist)
        let stateArtist = normalizedTrackIdentity(artist)
        return snapshotArtist.isEmpty || stateArtist.isEmpty || snapshotArtist == stateArtist
    }

    private static func normalizedTrackIdentity(_ value: String?) -> String {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) ?? ""
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
        DJConnectTrackInsightWidget()
        DJConnectAskDJWidget()
        #if canImport(ActivityKit) && os(iOS)
        if #available(iOS 16.1, *) {
            DJConnectTrackInsightLiveActivityWidget()
        }
        #endif
    }
}
