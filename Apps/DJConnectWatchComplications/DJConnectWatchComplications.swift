import DJConnectCore
import SwiftUI
import WidgetKit
import ImageIO

private struct SessionEntry: TimelineEntry {
    let date: Date
    let destination: DJConnectWatchStackEntry.Destination?
    var playback: DJConnectWatchWidgetCache? = nil
}
private struct SessionProvider: TimelineProvider {
    func placeholder(in context: Context) -> SessionEntry { .init(date: Date(), destination: nil) }
    func getSnapshot(in context: Context, completion: @escaping (SessionEntry) -> Void) {
        let now = Date()
        completion(.init(date: now, destination: confirmedEntry(at: now)?.destination, playback: playback(at: now)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionEntry>) -> Void) {
        let now = Date()
        let confirmed = confirmedEntry(at: now)
        let cache = playback(at: now)
        var entries = [SessionEntry(date: now, destination: confirmed?.destination, playback: cache)]
        let deadlines = [confirmed?.expiresAt, cache.flatMap { DJConnectHistoryEntry.date($0.projection.expires_at) },
            cache?.projection.now_playing.flatMap { DJConnectHistoryEntry.date($0.expires_at) },
            cache?.projection.artwork.first.flatMap { DJConnectHistoryEntry.date($0.expires_at) }]
            .compactMap { $0 }.filter { $0 > now }
        for deadline in Set(deadlines).sorted() {
            entries.append(.init(date: deadline,
                destination: confirmed.map { deadline < $0.expiresAt ? $0.destination : nil } ?? nil,
                playback: cache.flatMap { $0.isCurrent(at: deadline) ? $0 : nil }))
        }
        let refresh = deadlines.min() ?? now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
    private func playback(at now: Date) -> DJConnectWatchWidgetCache? {
        UserDefaults(suiteName: DJConnectLocalization.appGroupIdentifier)
            .flatMap { DJConnectWatchWidgetCache.load(from: $0, at: now) }
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
                if let cache = entry.playback, cache.isCurrent(at: entry.date),
                   let track = cache.projection.currentTrack(at: entry.date) {
                    HStack(spacing: 8) {
                        WatchWidgetCover(cache: cache, date: entry.date)
                            .frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.track).font(.headline).lineLimit(2)
                                .truncationMode(.tail)
                            Text("Spotify").font(.system(size: 8)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                } else {
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
                }
            } else if family == .accessoryInline {
                Label(entry.destination == .session ? subtitle : title, systemImage: icon)
            } else {
                Image(systemName: icon).accessibilityLabel(entry.destination == .session ? subtitle : title)
            }
        }
        .containerBackground(for: .widget) {
            let mood = entry.playback.flatMap { $0.isCurrent(at: entry.date) ? $0.projection.mood.value : nil }
            let colors = DJConnectSessionMoodTheme(sessionMood: mood).colorValues.map { value in
                Color(red: Double((value >> 16) & 255) / 255,
                    green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255).opacity(0.35)
            }
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        // The app confirms the current destination again; this URL carries no Session authority.
        .widgetURL(entry.destination?.url ?? URL(string: "djconnect://"))
    }
}
private struct WatchWidgetCover: View {
    let cache: DJConnectWatchWidgetCache
    let date: Date
    private var cover: CGImage? {
        guard cache.projection.currentArtwork(at: date) != nil, let bytes = cache.image,
              bytes.count <= 24_000, let source = CGImageSourceCreateWithData(bytes as CFData, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0,
            [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 160] as CFDictionary)
    }
    var body: some View {
        Group {
            if let cover {
                Image(decorative: cover, scale: 1).resizable()
                    .widgetAccentedRenderingMode(.fullColor).scaledToFit()
            } else { Image(systemName: "music.note").foregroundStyle(.secondary) }
        }
        .padding(3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.35), lineWidth: 1) }
        .accessibilityHidden(true)
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
