import SwiftUI
import DJConnectCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension View {
    func djSessionFrostedSurface(cornerRadius: CGFloat = DJConnectCardAppearance.cornerRadius) -> some View {
        modifier(DJSessionGlassSurface(cornerRadius: cornerRadius))
    }

    func djAlbumArtworkGlassCard() -> some View {
        let inset: CGFloat = 8
        return self
            .clipShape(RoundedRectangle(cornerRadius: DJConnectCardAppearance.cornerRadius - inset, style: .continuous))
            .padding(inset)
            .djSessionFrostedSurface()
    }

    @ViewBuilder func djSessionNavigationTitleStyle(compactPhone: Bool = false) -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(compactPhone && UIDevice.current.userInterfaceIdiom == .phone ? .inline : .large)
        #else
        self
        #endif
    }
}

private struct DJSessionGlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let bordered = content.overlay {
            shape.stroke(.white.opacity(DJConnectCardAppearance.borderOpacity), lineWidth: DJConnectCardAppearance.borderWidth)
        }
        if #available(iOS 26, macOS 26, watchOS 26, tvOS 26, *) {
            if reduceTransparency { bordered.background(.regularMaterial, in: shape) }
            else { bordered.glassEffect(.regular, in: shape) }
        } else { bordered.background(.ultraThinMaterial, in: shape) }
    }
}

/// Share the glass compositor across visible cards without merging separated bubbles.
struct DJSessionGlassGroup<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        if #available(iOS 26, macOS 26, watchOS 26, tvOS 26, *), !reduceTransparency {
            GlassEffectContainer(spacing: 0) { content }
        } else {
            content
        }
    }
}

/// One native projection shared by Compact and Expanded Apple surfaces.
struct NativeSessionMomentsView: View {
    let session: DJConnectSessionRuntime
    let language: String
    var isRecovering = false
    var isLiveUnavailable = false
    var retryConnection: () -> Void = {}
    var artworkBaseURL: URL? = nil
    var playbackOutputName: String? = nil
    var playbackModel: DJConnectAppModel? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func text(_ key: String) -> String {
        DJConnectLocalization.localized(key: key, language: language)
    }

    private var stacksCurrentOnPhone: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { clock in
            let current = currentMoment(at: clock.date)
            VStack(alignment: .leading, spacing: 24) {
                SessionCurrentColumns(stacked: true) {
                    musicContext
                    currentCard(current)
                        .accessibilityIdentifier("session-current-card")
                }
                .accessibilityElement(children: .contain)
                .id("native-session-current")
                .animation(djSessionReducedMotion(reduceMotion) ? nil : .easeInOut(duration: 0.2), value: current?.id)

            }
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: Binding(get: { playbackModel?.momentTrackInsightTarget != nil }, set: { if !$0 { playbackModel?.dismissMomentTrackInsight() } })) {
            if let model = playbackModel {
                #if os(macOS)
                TrackInsightView(model: model, explicitMoment: true).frame(minWidth: 640, minHeight: 600)
                #else
                TrackInsightView(model: model, explicitMoment: true)
                #endif
            }
        }
        .accessibilityIdentifier("session-moment-content")
        #if DEBUG
        .overlay(alignment: .bottomTrailing) {
            if ProcessInfo.processInfo.arguments.contains("--uitesting"), djSessionReducedMotion(reduceMotion) {
                Text("uitest-renderer-reduce-motion-on").font(.caption2).accessibilityIdentifier("uitest-renderer-reduce-motion-on")
            }
        }
        #endif
    }

    private func currentMoment(at date: Date) -> DJConnectMoment? { session.broadcast.nativeCurrentMoment(at: date, spotifyAttributionAvailable: spotifyAttributionLogo != nil) }

    private func kind(_ moment: DJConnectMoment) -> String {
        let mapped = ["track": "track_context", "artist": "artist_story", "album": "album_story", "genre": "genre_story", "session": "session_direction"][moment.type] ?? moment.type
        let key = "ui.session.moment.\(mapped)"
        let value = text(key)
        return value == key ? text("ui.session.moment.generic") : value
    }

    private func presentation(for moment: DJConnectMoment) -> DJConnectPresentation? {
        session.broadcast.presentations.last { $0.momentID == moment.id }
    }

    @ViewBuilder private func currentCard(_ moment: DJConnectMoment?) -> some View {
        if isLiveUnavailable {
            VStack(alignment: .leading, spacing: 12) {
                Text(text("ui.session.live_unavailable")).font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Button(text("ui.retry"), action: retryConnection)
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .djSessionFrostedSurface()
        } else if isRecovering {
            VStack(alignment: .leading, spacing: 12) {
                ProgressView()
                Text(text("ui.session.reconnecting")).font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .djSessionFrostedSurface()
        } else if session.runtimeState == "active", session.broadcast.playback?.state == "paused" {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(text("ui.paused")).font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(text("ui.session.playback_paused_detail"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .djSessionFrostedSurface()
            .accessibilityIdentifier("session-playback-paused")
        } else if let moment {
            MomentCard(moment: moment, kind: kind(moment), presentation: presentation(for: moment), language: language,
                navigationLabel: insightOffer(for: moment)?.label,
                openInsight: { if let offer = insightOffer(for: moment) { playbackModel?.openMomentTrackInsight(offer) } })
                .id(moment.id)
                .transition(.opacity)
                .accessibilityIdentifier("session-current-moment")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "sparkles").font(.title).accessibilityHidden(true)
                Text(text("ui.session.quiet")).font(.title2.weight(.semibold))
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .djSessionFrostedSurface()
        }
    }

    private func insightOffer(for moment: DJConnectMoment) -> DJConnectMomentInsightNavigation? {
        guard playbackModel?.sessionHistory.momentInsightAvailable == true,
              let offer = session.broadcast.nativeCurrentInsightNavigation(at: Date()), offer.reference.momentID == moment.id else { return nil }
        return offer
    }

    private var musicArtworkURL: URL? {
        guard let raw = session.broadcast.playback?.artworkURL,
              let url = URL(string: raw, relativeTo: artworkBaseURL)?.absoluteURL,
              ["http", "https"].contains(url.scheme) else { return nil }
        return url
    }

    private var musicContext: some View {
        Group {
            if let url = musicArtworkURL {
                SessionCurrentColumns(stacked: stacksCurrentOnPhone) {
                    AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { Image(systemName: "music.note") }
                        .aspectRatio(1, contentMode: .fit)
                        .djAlbumArtworkGlassCard()
                        .frame(maxWidth: 270)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("session-music-artwork")
                    musicDetails
                }
            } else {
                musicDetails
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("session-music-context")
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var musicDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let playback = session.broadcast.playback {
                Text(playback.title ?? text("ui.nothing.playing")).font(.headline)
                if let artist = playback.artist { Text(artist).foregroundStyle(.secondary) }
                if let album = playback.album { Text(album).font(.caption).foregroundStyle(.secondary) }
                if let duration = playback.durationMS, duration > 0, let position = playbackModel?.displayedSessionPositionMS(session) ?? playback.positionMS {
                    let current = max(0, min(position, duration))
                    ProgressView(value: Double(current), total: Double(duration))
                        .accessibilityLabel(text("ui.session.music_progress"))
                    HStack(alignment: .center, spacing: 8) {
                        if let playbackModel, playbackModel.canToggleSessionFavorite(session) {
                            FavoriteTrackButton(model: playbackModel, identifier: "session-favorite-button", sessionContext: session)
                                .disabled(!playbackModel.canUsePlaybackFeatures || playbackModel.isRefreshing)
                        }
                        Spacer(minLength: 0)
                        Text("\(sessionPlaybackTime(current)) / \(sessionPlaybackTime(duration))")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            .accessibilityLabel(text("ui.session.music_duration"))
                            .accessibilityValue("\(sessionPlaybackTime(current)) / \(sessionPlaybackTime(duration))")
                    }
                }
                if let playbackOutputName {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Label(playbackOutputName, systemImage: "hifispeaker.fill")
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel(text("ui.output.device"))
                            .accessibilityValue(playbackOutputName)
                            .accessibilityIdentifier("session-playback-output")
                        Spacer(minLength: 0)
                        if let rawVolume = playbackModel?.playback?.volumePercent {
                            let volume = max(0, min(100, rawVolume))
                            Label("\(volume)%", systemImage: volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .fixedSize()
                                .accessibilityLabel(text("watch.volume"))
                                .accessibilityValue("\(volume)%")
                                .accessibilityIdentifier("session-playback-volume")
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("session-music-details")
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Keeps music on the left even at compact widths and larger text sizes.
/// Each column measures its full text height, so the pinned header can scroll
/// vertically without changing the relationship between artwork and DJ content.
private struct SessionCurrentColumns: Layout {
    var stacked = false
    private func widths(_ proposal: ProposedViewSize) -> (CGFloat, CGFloat, CGFloat) {
        let width = max(0, proposal.width ?? 800)
        let gap: CGFloat = width < 600 ? 12 : 24
        let music = min(270, width * 0.375)
        return (music, max(0, width - music - gap), gap)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        if stacked {
            let width = max(0, proposal.width ?? 400)
            let top = subviews[0].sizeThatFits(.init(width: width, height: nil))
            let bottom = subviews[1].sizeThatFits(.init(width: width, height: nil))
            return CGSize(width: width, height: top.height + 16 + bottom.height)
        }
        let (music, card, gap) = widths(proposal)
        let left = subviews[0].sizeThatFits(.init(width: music, height: nil))
        let right = subviews[1].sizeThatFits(.init(width: card, height: nil))
        return CGSize(width: music + card + gap, height: max(left.height, right.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        if stacked {
            let top = subviews[0].sizeThatFits(.init(width: bounds.width, height: nil))
            subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: .init(width: bounds.width, height: nil))
            subviews[1].place(at: CGPoint(x: bounds.minX, y: bounds.minY + top.height + 16), anchor: .topLeading,
                              proposal: .init(width: bounds.width, height: nil))
            return
        }
        let (music, card, gap) = widths(.init(width: bounds.width, height: nil))
        subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: .init(width: music, height: nil))
        subviews[1].place(at: CGPoint(x: bounds.minX + music + gap, y: bounds.minY), anchor: .topLeading,
                          proposal: .init(width: card, height: nil))
    }
}

struct MomentCard: View {
    let moment: DJConnectMoment
    let kind: String
    let presentation: DJConnectPresentation?
    let language: String
    var navigationLabel: String? = nil
    var openInsight: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(kind).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            if !moment.title.isEmpty { Text(moment.title).font(.title2.bold()).accessibilityAddTraits(.isHeader) }
            Text(moment.content).font(.title3).fixedSize(horizontal: false, vertical: true)
            if let speech = presentation?.speech {
                ForEach(speech.segments.filter { !(["dj", "primary_dj"].contains($0.speakerRole) && $0.text == moment.content) }.sorted { $0.ordinal < $1.ordinal }, id: \.ordinal) { segment in
                    Text(segment.text).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let label = navigationLabel, let openInsight {
                Button(action: openInsight) { Label(label, systemImage: "waveform.path.ecg") }
                    .tint(djConnectAccent)
                    .accessibilityIdentifier("moment-open-track-insight")
            }
            if moment.sourceAttribution?["provider"] == "Spotify",
               let logo = spotifyAttributionLogo, let url = moment.nativeSourceURLs.first {
                Link(destination: url) {
                    logo.resizable().scaledToFit().frame(width: 70, height: 20)
                        .padding(10).frame(minHeight: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Spotify")
                .accessibilityValue(url.absoluteString)
                .accessibilityIdentifier("session-spotify-attribution")
            }
            ForEach(moment.nativeSourceURLs, id: \.absoluteString) { url in
                Link(sourceLabel(url), destination: url)
                    .foregroundStyle(djConnectAccent)
                    .tint(djConnectAccent)
                    .accessibilityValue(url.absoluteString)
                    .accessibilityIdentifier("moment-source-" + url.absoluteString)
            }
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .djSessionFrostedSurface()
        .accessibilityElement(children: .contain)
    }
    private func sourceLabel(_ url: URL) -> String {
        if moment.sourceAttribution?["provider"] == "Spotify" { return "Spotify" }
        let key = url.absoluteString == moment.sourceAttribution?["url_previous"] ? "ui.session.source_previous" : "ui.session.source_current"
        let provider = moment.sourceAttribution?["provider"] ?? url.host ?? ""
        return provider + " · " + DJConnectLocalization.localized(key: key, language: language)
    }
}

var spotifyAttributionLogo: Image? {
    #if os(iOS)
    UIImage(named: "SpotifyAttribution").map { Image(uiImage: $0) }
    #elseif os(macOS)
    NSImage(named: NSImage.Name("SpotifyAttribution")).map { Image(nsImage: $0) }
    #else
    nil
    #endif
}

func djSessionReducedMotion(_ systemPreference: Bool) -> Bool {
    #if DEBUG
    return systemPreference || ProcessInfo.processInfo.arguments.contains("--uitest-reduce-motion")
    #else
    return systemPreference
    #endif
}

func sessionPlaybackTime(_ milliseconds: Int) -> String {
    let seconds = max(0, milliseconds) / 1000
    return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
}
