import SwiftUI
import DJConnectCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension View {
    @ViewBuilder func djSessionNavigationTitleStyle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.large)
        #else
        self
        #endif
    }
}

/// One native projection shared by Compact and Expanded Apple surfaces.
struct NativeSessionMomentsView: View {
    let session: DJConnectSessionRuntime
    let language: String
    var artworkBaseURL: URL? = nil
    var returnToCurrent: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedMomentID: String?

    private func text(_ key: String) -> String {
        DJConnectLocalization.localized(key: key, language: language)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { clock in
            let current = currentMoment(at: clock.date)
            VStack(alignment: .leading, spacing: 24) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 24) {
                        currentCard(current).frame(minWidth: 380, maxWidth: .infinity)
                        musicContext.frame(width: 260)
                    }
                    VStack(alignment: .leading, spacing: 20) {
                        currentCard(current)
                        musicContext
                    }
                }
                .id("native-session-current")
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: current?.id)
                Text(text("ui.session.flow")).font(.title2.bold())
                ForEach(flowItems) { item in
                    if let moment = flowMoments.first(where: { $0.id == item.momentID }) {
                    Button {
                        selectedMomentID = moment.id
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(kind(moment)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                Text(moment.title.isEmpty ? moment.summary : moment.title).multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: moment.id == current?.id ? "sparkles" : "chevron.right")
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("session-flow-\(moment.id)")
                    } else {
                        Text(item.label).font(.callout).foregroundStyle(.secondary)
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("session-moment-content")
        .sheet(item: Binding(
            get: { flowMoments.first { $0.id == selectedMomentID } },
            set: { selectedMomentID = $0?.id }
        )) { selected in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TimelineView(.periodic(from: .now, by: 1)) { clock in
                        if session.broadcast.nativeFlowMoments(at: clock.date).contains(where: { $0.id == selected.id }) {
                            MomentCard(moment: selected, kind: kind(selected), presentation: presentation(for: selected), language: language)
                        } else { Text(text("ui.session.quiet")) }
                    }
                    Button(text("ui.session.back_current")) {
                        selectedMomentID = nil
                        returnToCurrent()
                    }
                }
                .padding(24)
            }
            #if os(macOS)
            .frame(minWidth: 380, idealWidth: 600, minHeight: 400, idealHeight: 600)
            #else
            .presentationDetents([.medium, .large])
            #endif
        }
    }

    private var flowMoments: [DJConnectMoment] { session.broadcast.nativeFlowMoments(at: Date()) }
    private var flowItems: [DJConnectSessionFlowItem] {
        flowMoments.compactMap { moment in
            session.broadcast.sessionFlow.items.first { $0.itemType == "dj_moment" && $0.momentID == moment.id }
        }
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
        if let moment {
            MomentCard(moment: moment, kind: kind(moment), presentation: presentation(for: moment), language: language)
                .id(moment.id)
                .transition(.opacity)
                .accessibilityIdentifier("session-current-moment")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "sparkles").font(.title)
                Text(text("ui.session.quiet")).font(.title2.weight(.semibold))
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    private var musicContext: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let playback = session.broadcast.playback {
                if let raw = playback.artworkURL, let url = URL(string: raw, relativeTo: artworkBaseURL)?.absoluteURL, ["http", "https"].contains(url.scheme) {
                    AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { Image(systemName: "music.note") }
                        .frame(maxWidth: 180, maxHeight: 180).clipShape(RoundedRectangle(cornerRadius: 16))
                }
                Text(playback.title ?? text("ui.nothing.playing")).font(.headline)
                if let artist = playback.artist { Text(artist).foregroundStyle(.secondary) }
                if let album = playback.album { Text(album).font(.caption).foregroundStyle(.secondary) }
                if let duration = playback.durationMS, duration > 0, let position = playback.positionMS {
                    ProgressView(value: Double(max(0, min(position, duration))), total: Double(duration))
                        .accessibilityLabel(text("ui.session.music_progress"))
                }
            }
        }
        .accessibilityIdentifier("session-music-context")
    }
}

private struct MomentCard: View {
    let moment: DJConnectMoment
    let kind: String
    let presentation: DJConnectPresentation?
    let language: String
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(kind).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            if !moment.title.isEmpty { Text(moment.title).font(.title2.bold()) }
            Text(moment.content).font(.title3).fixedSize(horizontal: false, vertical: true)
            if let speech = presentation?.speech {
                ForEach(speech.segments.filter { !(["dj", "primary_dj"].contains($0.speakerRole) && $0.text == moment.content) }.sorted { $0.ordinal < $1.ordinal }, id: \.ordinal) { segment in
                    Text(segment.text).fixedSize(horizontal: false, vertical: true)
                }
            }
            if moment.sourceAttribution?["provider"] == "Spotify",
               let logo = spotifyAttributionLogo, let url = moment.nativeSourceURLs.first {
                Link(destination: url) {
                    logo.resizable().scaledToFit().frame(width: 110, height: 31)
                        .padding(16).background(Color.black, in: RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("Spotify")
                .accessibilityValue(url.absoluteString)
                .accessibilityIdentifier("session-spotify-attribution")
            }
            ForEach(moment.nativeSourceURLs, id: \.absoluteString) { url in
                Link(sourceLabel(url), destination: url)
                    .accessibilityValue(url.absoluteString)
                    .accessibilityIdentifier("moment-source-" + url.absoluteString)
            }
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .contain)
    }
    private func sourceLabel(_ url: URL) -> String {
        if moment.sourceAttribution?["provider"] == "Spotify" { return "Spotify" }
        let key = url.absoluteString == moment.sourceAttribution?["url_previous"] ? "ui.session.source_previous" : "ui.session.source_current"
        let provider = moment.sourceAttribution?["provider"] ?? url.host ?? ""
        return provider + " · " + DJConnectLocalization.localized(key: key, language: language)
    }
}

private var spotifyAttributionLogo: Image? {
    #if os(iOS)
    UIImage(named: "SpotifyAttribution").map { Image(uiImage: $0) }
    #elseif os(macOS)
    NSImage(named: NSImage.Name("SpotifyAttribution")).map { Image(nsImage: $0) }
    #else
    nil
    #endif
}
