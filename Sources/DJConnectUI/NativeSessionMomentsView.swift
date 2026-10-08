import SwiftUI
import DJConnectCore

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
                ForEach(flowMoments) { moment in
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
                    MomentCard(moment: selected, kind: kind(selected), presentation: presentation(for: selected))
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

    // Only already committed server Flow links can expose previous content.
    // Source-card historical native-display rights remain a producer admission gate.
    private var flowMoments: [DJConnectMoment] {
        var seen = Set<String>()
        return session.broadcast.sessionFlow.items.compactMap { item in
            guard item.itemType == "dj_moment", let id = item.momentID, seen.insert(id).inserted else { return nil }
            return session.broadcast.djMoments.first { $0.id == id && permitted($0) && !requiresSourceQualification($0) }
        }
    }

    private func requiresSourceQualification(_ moment: DJConnectMoment) -> Bool {
        moment.sourceAttribution != nil || (moment.generationMetadata?["provider"].map { $0 != "track_insight" } ?? false)
    }

    private func permitted(_ moment: DJConnectMoment) -> Bool {
        moment.sessionID == session.id && moment.type != "silence"
            && ["owner_only", "session_shared", "public_broadcast"].contains(moment.presentationIntent.visibility)
            && !moment.content.isEmpty
    }

    private func currentMoment(at date: Date) -> DJConnectMoment? {
        session.broadcast.djMoments.last { moment in
            guard permitted(moment), !requiresSourceQualification(moment),
                  let created = momentDate(moment.createdAt), created <= date,
                  let duration = moment.presentationIntent.maximumDurationSeconds, duration > 0 else { return false }
            if let item = session.broadcast.playback?.itemID, !item.isEmpty, moment.playbackItemID != item { return false }
            return date.timeIntervalSince(created) < Double(min(duration, 90))
        }
    }

    private func momentDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

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
            MomentCard(moment: moment, kind: kind(moment), presentation: presentation(for: moment))
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
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(kind).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            if !moment.title.isEmpty { Text(moment.title).font(.title2.bold()) }
            Text(moment.content).font(.title3).fixedSize(horizontal: false, vertical: true)
            if let speech = presentation?.speech {
                ForEach(speech.segments.filter { $0.text != moment.content }.sorted { $0.ordinal < $1.ordinal }, id: \.ordinal) { segment in
                    Text(segment.text).fixedSize(horizontal: false, vertical: true)
                }
            }
            ForEach(moment.sourceReferences.filter { safeSourceURL($0) != nil }, id: \.self) { reference in
                if let url = safeSourceURL(reference) { Link(url.host ?? reference, destination: url) }
            }
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .contain)
    }
    private func safeSourceURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw), url.scheme == "https", url.user == nil, url.password == nil, url.host != nil else { return nil }
        return url
    }
}
