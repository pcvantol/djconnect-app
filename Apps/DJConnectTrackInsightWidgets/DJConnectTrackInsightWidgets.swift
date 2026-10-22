import SwiftUI
import WidgetKit
import ImageIO
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
/// The same vector identity as the app, using only the admitted surface palette.
/// No capture, pending-request or speech activity is inferred in an extension.
private struct SessionSurfaceAvatar: View {
    let theme: DJConnectSessionMoodTheme
    let side: CGFloat
    var body: some View {
        DJPersonaAvatarView(confirmedMood: theme.rawValue,
                            language: DJConnectLocalization.defaultDisplayLanguageCode())
            .frame(width: side, height: side)
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
    var palette: DJConnectWidgetPaletteSnapshot? = nil
    var rich: DJConnectPassiveSurfaceCache? = nil
    var theme: DJConnectSessionMoodTheme { isActive ? (snapshot?.renderingTheme(at: date) ?? .brand) : (palette?.renderingTheme(at: date) ?? .brand) }
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
        let deadlines = Set([entry.snapshot?.expiresAt, entry.palette?.expiresAt].compactMap { $0 } + (entry.rich?.projection.deadlines ?? [])).sorted()
        for expiry in deadlines {
            entries.append(.init(date: expiry, snapshot: entry.snapshot, palette: entry.palette, rich: entry.rich))
        }
        completion(Timeline(entries: entries, policy: .after(Date().addingTimeInterval(15 * 60))))
    }
    private func current() -> DJConnectSessionWidgetEntry {
        let now = Date()
        let shared = UserDefaults(suiteName: DJConnectLocalization.appGroupIdentifier)
        let snapshot = shared.flatMap { DJConnectSessionSurfaceSnapshot.load(from: $0, at: now) }
        let palette = shared.flatMap { DJConnectWidgetPaletteSnapshot.load(from: $0, at: now) }
        let rich = shared.flatMap { DJConnectPassiveSurfaceCache.load(surface: .widget, from: $0, at: now) }
        return .init(date: now, snapshot: snapshot, palette: palette, rich: rich)
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
                SessionSurfaceAvatar(theme: theme, side: compact ? 40 : 64)
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
        let now = max(entry.date, Date())
        let rich = entry.rich.flatMap { $0.isCurrent(at: now) ? $0 : nil }
        let theme = DJConnectSessionSurfaceSnapshot.widgetTheme(confirmedSession: entry.snapshot,
            passiveMood: rich?.projection.mood.value, fallback: entry.theme, at: now)
        Group {
            if let rich {
                PassiveSessionContentView(contribution: rich.projection.currentContribution(at: now),
                    playback: rich.projection.currentPlayback(at: now), cache: rich,
                    compact: family == .systemSmall, large: family == .systemLarge, theme: theme, date: now)
            } else {
                DJConnectSessionSurfaceView(isActive: entry.isActive, compact: family == .systemSmall, theme: theme)
            }
        }
        .containerBackground(for: .widget) {
            SessionMoodBackground(theme: theme)
                .overlay { SessionWidgetVibeScapeArtwork(colors: theme.colors) }
        }
        .widgetURL(sessionURL)
    }
}

@MainActor
private func sessionConfiguration(kind: String) -> some WidgetConfiguration {
    let configuration = StaticConfiguration(kind: kind, provider: DJConnectSessionWidgetProvider()) {
        DJConnectSessionWidgetView(entry: $0)
    }
    .configurationDisplayName(text("ui.session.title"))
    .description(text("surface.session.description"))
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    #if os(macOS)
    return configuration.pushHandler(DJConnectSessionWidgetPushHandler.self)
    #else
    return configuration
    #endif
}

#if os(macOS)
struct DJConnectSessionWidgetPushHandler: WidgetPushHandler {
    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {
        guard !DJConnectLocalization.isQualificationProcess,
              let bundleID = Bundle.main.bundleIdentifier,
              let shared = UserDefaults(suiteName: DJConnectLocalization.appGroupIdentifier) else { return }
        let value = DJConnectWidgetPushToken(token: pushInfo.token, extensionBundleID: bundleID,
                                            widgetKinds: widgets.map(\.kind))
        // Never send this token through ordinary app/Ask DJ registration.
        // Core must negotiate its widget delivery/background-read contract first.
        try? DJConnectWidgetPushToken.replace(value, in: shared)
    }
}
#endif

struct DJConnectSessionWidget: Widget {
    var body: some WidgetConfiguration { sessionConfiguration(kind: DJConnectSessionSurfaceSnapshot.widgetKind) }
}
#if os(iOS) && canImport(ActivityKit)
struct DJConnectSessionActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DJConnectSessionLiveActivityAttributes.self) { context in
            PassiveActivityBody(snapshot: context.state, stale: context.isStale)
                .padding(12)
                .background {
                    let theme = context.isStale ? DJConnectSessionMoodTheme.brand : context.state.renderingTheme(at: Date())
                    SessionMoodBackground(theme: theme)
                        .overlay { SessionWidgetVibeScapeArtwork(colors: theme.colors).opacity(0.75) }
                }
                .activityBackgroundTint((context.isStale ? DJConnectSessionMoodTheme.brand : context.state.renderingTheme(at: Date())).darkTint)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(sessionURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        SessionSurfaceAvatar(theme: context.isStale ? .brand : context.state.renderingTheme(at: Date()), side: 28)
                        Text(text("ui.session.title"))
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .bottom, spacing: 12) {
                        PassiveActivityBody(snapshot: context.state, stale: context.isStale,
                                            showsSpotifyCredit: false, showsHeader: false)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(intent: DJConnectSessionNextTrackIntent(presentationID: context.attributes.presentationID)) {
                            Image(systemName: "forward.end.fill")
                                .font(.title3.weight(.semibold)).foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.white.opacity(0.14), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(context.isStale || !context.state.isCurrent(at: Date()))
                        .accessibilityLabel(text("ui.next.track"))
                        .accessibilityIdentifier("session-island-next-track")
                    }
                    .padding(.horizontal, 12).padding(.bottom, 8)
                }
            } compactLeading: {
                SessionSurfaceAvatar(theme: context.isStale ? .brand : context.state.renderingTheme(at: Date()), side: 22)
            } compactTrailing: {
                Image(systemName: context.isStale ? "arrow.up.forward" : "music.note").foregroundStyle(.white)
            } minimal: {
                SessionSurfaceAvatar(theme: context.isStale ? .brand : context.state.renderingTheme(at: Date()), side: 20)
            }
            .widgetURL(sessionURL)
            .keylineTint((context.isStale ? DJConnectSessionMoodTheme.brand : context.state.renderingTheme(at: Date())).accent)
        }
    }
}
#endif

// Rich content comes only from the separate passive grant, never the foreground
// owner Moment cache. Contribution and current music retain independent slots.
private struct PassiveSessionContentView: View {
    let contribution: DJConnectPassiveSession.Contribution?
    let playback: DJConnectPassiveSession.NowPlaying?
    let cache: DJConnectPassiveSurfaceCache?
    var compact = false
    var large = false
    var activity = false
    var playbackState: String? = nil
    var showsSpotifyCredit = true
    var showsHeader = true
    var theme: DJConnectSessionMoodTheme = .brand
    let date: Date
    var body: some View {
        Group {
            if large, playback != nil, contribution == nil {
                GeometryReader { geometry in
                    content(artworkSide: min(156, max(80, geometry.size.height - 190)))
                }
            } else { content(artworkSide: nil) }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: activity ? nil : .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
    }
    private func content(artworkSide: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: activity || compact ? 6 : 8) {
            if showsHeader {
            HStack(spacing: 8) {
                SessionSurfaceAvatar(theme: theme, side: activity || compact ? 24 : 36)
                Text(text("ui.session.title"))
                    .font((large ? Font.subheadline : .caption).weight(.semibold)).foregroundStyle(.white.opacity(0.85))
            }
            }
            if let playback {
                if let artworkSide {
                    spaciousPlayback(playback, artworkSide: artworkSide)
                } else {
                HStack(alignment: .top, spacing: compact ? 6 : 12) {
                    if cache?.projection.currentArtwork(slot: "now_playing", at: date) != nil {
                        cover(slot: "now_playing")
                            .frame(width: activity ? 64 : large ? 104 : compact ? 32 : 56,
                                   height: activity ? 64 : large ? 104 : compact ? 32 : 56)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        if !compact {
                            Text(text(!activity || playbackState == "playing" ? "ui.now.playing" : playbackState == "paused" ? "ui.paused" : "ui.playback")).font(.caption2).foregroundStyle(.white.opacity(0.7))
                        }
                        Text(playback.track).font((activity ? Font.headline : large ? .title3 : .subheadline).weight(.semibold)).lineLimit(activity ? 1 : large ? 3 : compact ? 1 : 2)
                        Text(playback.artist).font(activity ? .subheadline : large ? .callout : .caption).foregroundStyle(.white.opacity(0.85)).lineLimit(large ? 2 : 1)
                        if (large || activity) && !playback.album.isEmpty { Text(playback.album).font(.caption).foregroundStyle(.white.opacity(0.7)).lineLimit(activity ? 1 : 2) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                }
                credit(playback.attribution)
            }
            if let contribution, !activity || playback == nil {
                if playback != nil { Divider().overlay(.white.opacity(0.15)) }
                HStack(alignment: .top, spacing: 10) {
                    if !compact, cache?.projection.currentArtwork(slot: "contribution", at: date) != nil {
                        cover(slot: "contribution").frame(width: 56, height: 56)
                    }
                    Text(contribution.text).font(compact ? .caption : .subheadline.weight(.medium))
                        .lineLimit(large ? 6 : compact && playback != nil ? 2 : 3)
                        .accessibilityLabel(contribution.text)
                }
                credit(contribution.source_attribution)
            }
            if contribution == nil && playback == nil {
                Text(text("surface.session.active")).font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func spaciousPlayback(_ playback: DJConnectPassiveSession.NowPlaying, artworkSide: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let cover = decodedCover(slot: "now_playing", side: artworkSide) {
                    Image(cover.image, scale: 3, label: Text(cover.label))
                        .resizable().scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.white.opacity(0.05))
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: artworkSide * 0.36, weight: .light))
                                .foregroundStyle(.white.opacity(0.30))
                        }
                        .accessibilityHidden(true)
                }
            }
            .frame(width: artworkSide, height: artworkSide)
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 3) {
                Text(text("ui.now.playing")).font(.caption).foregroundStyle(.white.opacity(0.70))
                Text(playback.track).font(.title2.bold()).lineLimit(2).minimumScaleFactor(0.8)
                Text(playback.artist).font(.body).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                if !playback.album.isEmpty {
                    Text(playback.album).font(.caption).foregroundStyle(.white.opacity(0.70)).lineLimit(1)
                }
            }
        }
    }
    @ViewBuilder private func credit(_ attribution: [String: String]) -> some View {
        if attribution["mark"] == "spotify" {
            if showsSpotifyCredit, let source = attribution["url"], let url = URL(string: source) {
                Link(destination: url) {
                    Image("SpotifyAttribution").resizable().scaledToFit().frame(width: 70, height: 21)
                        .accessibilityLabel("Spotify")
                }
            }
        } else if let provider = attribution["provider"], !provider.isEmpty {
            if let source = attribution["url"], let url = URL(string: source) {
                Link(provider, destination: url).font(.caption2).foregroundStyle(.white.opacity(0.85))
            } else { Text(provider).font(.caption2).foregroundStyle(.white.opacity(0.85)) }
        }
    }
    @ViewBuilder private func cover(slot: String) -> some View {
        if let cover = decodedCover(slot: slot, side: activity ? 64 : large ? 104 : compact ? 32 : 56) {
            Image(cover.image, scale: 3, label: Text(cover.label))
                .resizable().scaledToFit()
        }
    }
    private func decodedCover(slot: String, side: CGFloat) -> (image: CGImage, label: String)? {
        guard let cache, cache.isCurrent(at: date),
              let artwork = cache.projection.currentArtwork(slot: slot, at: date), let data = cache.pixels[slot],
              data.count <= DJConnectPassiveSurfaceCache.maximumImageBytes,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) == 1,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(side * 3)
              ] as CFDictionary) else { return nil }
        return (image, artwork.alt_text[DJConnectLocalization.defaultDisplayLanguageCode()] ?? artwork.alt_text["en"] ?? "")
    }
}

#if os(iOS) && canImport(ActivityKit)
private struct PassiveActivityBody: View {
    let snapshot: DJConnectSessionSurfaceSnapshot
    let stale: Bool
    var showsSpotifyCredit = true
    var showsHeader = true
    var body: some View {
        let now = Date()
        if !stale, snapshot.isCurrent(at: now), let rich = snapshot.rich, rich.isCurrent(at: now) {
            let cache = UserDefaults(suiteName: DJConnectLocalization.appGroupIdentifier)
                .flatMap { DJConnectPassiveSurfaceCache.load(surface: .liveActivity, from: $0, at: now) }
                .flatMap { value in
                    value.projection.binding_id == rich.bindingID && value.projection.generation == rich.generation &&
                    value.projection.delivery_sequence == rich.sequence && value.projection.contribution == rich.contribution &&
                    value.projection.now_playing == rich.nowPlaying ? value : nil
                }
            PassiveSessionContentView(contribution: rich.contribution, playback: rich.nowPlaying, cache: cache,
                                      activity: true, playbackState: rich.playbackState,
                                      showsSpotifyCredit: showsSpotifyCredit, showsHeader: showsHeader && rich.nowPlaying == nil,
                                      theme: snapshot.renderingTheme(at: now), date: now)
        } else if !showsHeader {
            // The expanded Island already supplies its small leading header.
            // Keep the fallback within its bottom region instead of inserting
            // the full Lock Screen layout (duplicate avatar/title, clipped text).
            Text(text(!stale && snapshot.isCurrent(at: now) ? "surface.session.active" : "surface.session.open.app"))
                .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
        } else {
            DJConnectSessionSurfaceView(isActive: !stale && snapshot.isCurrent(at: now), theme: stale ? .brand : snapshot.renderingTheme(at: now))
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
                SessionSurfaceAvatar(theme: theme, side: 46)
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
        #if os(iOS) && canImport(ActivityKit)
        DJConnectSessionActivityWidget()
        #endif
    }
}
