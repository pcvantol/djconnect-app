import SwiftUI
import DJConnectCore

extension DJConnectAppModel {
    func forecastImageIsCurrent(_ image: DJConnectSessionForecast.Imagery, projection: DJConnectSessionForecast) -> Bool {
        visibleSessionForecast(at: Date()) == projection && projection.current_anchor != nil && projection.imagery.contains(image) &&
            image.admittedPath(sessionID: projection.session_id, at: Date()) != nil
    }
    func loadForecastImage(_ image: DJConnectSessionForecast.Imagery, projection: DJConnectSessionForecast) async throws -> DJConnectSessionArtworkImage {
        let epoch = sessionHistory.responseEpoch
        guard forecastImageIsCurrent(image, projection: projection) else { throw CancellationError() }
        let result = try await withHomeAssistantClient(allowsOperationReplay: false) {
            try await $0.sessionForecastArtwork(image, sessionID: projection.session_id)
        }
        guard !Task.isCancelled, epoch == sessionHistory.responseEpoch,
              forecastImageIsCurrent(image, projection: projection) else { throw CancellationError() }
        return result
    }
}

/// Authored text is independent of optional imagery. No generated local claims.
struct SessionForecastTextView: View {
    let projection: DJConnectSessionForecast
    let language: String
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(projection.sections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        if let glyph = ["current": "play.fill", "guidance": "clock", "aim": "target"][section.id] {
                            Image(systemName: glyph)
                                .symbolRenderingMode(.monochrome)
                                .font(.title3.weight(.semibold))
                                .accessibilityHidden(true)
                        }
                        Text(section.title).font(.title3.bold()).accessibilityAddTraits(.isHeader)
                    }
                    .foregroundStyle(.white)
                    Text(text("ui.session.forecast.claim." + section.claim_type))
                        .font(.caption).foregroundStyle(.white.opacity(0.78))
                    sectionText(section)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    if section.id != "current", let source = section.source_url.flatMap(URL.init(string:)) {
                        Link(destination: source) {
                            Text(text("ui.session.forecast.source")).underline().foregroundStyle(.white)
                        }.frame(minHeight: 44)
                    }
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .djSessionFrostedSurface().id(section.id)
            }
        }
        .scrollTargetLayout()
        .accessibilityIdentifier("session-forecast-text")
    }

    @ViewBuilder private func sectionText(_ section: DJConnectSessionForecast.Section) -> some View {
        if section.id == "guidance", let guidance = queueGuidance(section.text) {
            VStack(alignment: .leading, spacing: 12) {
                Text(guidance.intro)
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(guidance.tracks.indices, id: \.self) { index in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•").accessibilityHidden(true)
                            Text(guidance.tracks[index])
                        }
                    }
                }
                Text(guidance.note)
            }
        } else {
            Text(section.text).lineSpacing(3)
        }
    }

    // Queue guidance v1 is authored as prose. Recognize only its quoted-track
    // format and keep unrecognized producer text intact.
    private func queueGuidance(_ value: String) -> (intro: String, tracks: [String], note: String)? {
        guard let firstTrack = value.range(of: ": “"),
              let noteStart = value.range(
                of: #"\. (?=(?:De rode draad zoek ik|Zo ziet de wachtrij|I’ll look for a musical thread|That is the queue|Den musikalischen Faden|So sieht die Warteschlange|Je chercherai le fil musical|Voilà la file actuelle|Buscaré el hilo musical|Así está la cola))"#,
                options: .regularExpression, range: firstTrack.upperBound..<value.endIndex
              ) else { return nil }
        let start = value.index(before: firstTrack.upperBound)
        let tracks = value[start..<noteStart.lowerBound]
            .replacingOccurrences(of: #"(?:, | (?:and|en|und|et|y) )(?=“[^”]+” — )"#,
                                  with: "\n", options: .regularExpression)
            .components(separatedBy: "\n")
        guard (1...5).contains(tracks.count),
              tracks.allSatisfy({ $0.range(of: #"^“[^”]+” — .+$"#, options: .regularExpression) != nil }) else { return nil }
        return (String(value[..<start]).trimmingCharacters(in: .whitespaces),
                tracks, String(value[noteStart.upperBound...]))
    }
}

/// Standalone scroll host used by isolated component qualification.
/// The live Session embeds only SessionForecastContent below its shared header.
/// Transient viewport state belongs to the native screen, not a Profile.
/// Recording geometry must not invalidate the full Flow for every scroll pixel.
@MainActor final class SessionForecastViewport {
    private(set) var offset: CGFloat = 0
    func record(_ value: CGFloat) {
        guard value.isFinite else { return }
        offset = max(0, value)
    }
}

struct SessionForecastPanel<Header: View>: View {
    @ObservedObject var model: DJConnectAppModel
    let header: Header
    let viewport: SessionForecastViewport
    @State private var position: ScrollPosition
    @Environment(\.scenePhase) private var scenePhase
    init(model: DJConnectAppModel, viewport: SessionForecastViewport, @ViewBuilder header: () -> Header) {
        self.model = model; self.header = header()
        self.viewport = viewport
        // The panel is removed while Flow is selected. Restore its device-local
        // viewport even when no authored text ID intersects the top edge.
        _position = State(initialValue: ScrollPosition(y: viewport.offset))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                SessionForecastContent(model: model)
            }
        }
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, value in viewport.record(value) }
    }
}

/// Lower content only: playback, artwork and persona stay owned by the Session.
struct SessionForecastContent: View {
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject private var history: DJConnectSessionHistoryModel
    @State private var readProgress = ReadProgress()
    @Environment(\.scenePhase) private var scenePhase
    init(model: DJConnectAppModel) {
        self.model = model; history = model.sessionHistory
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    private var deadlines: [Date] {
        [model.forecastCursor?.projection?.valid_until.flatMap(DJConnectSessionForecast.timestamp)].compactMap { $0 }
            + (model.forecastCursor?.projection?.imagery.compactMap { DJConnectSessionForecast.timestamp($0.expires_at) } ?? [])
    }
    struct RefreshContext: Equatable {
        let scope: DJConnectAppModel.ForecastScope?
        let ownerEpoch: UUID
        let ownerReady: Bool
        let authority: UUID
        let recovering: Bool
        let unavailable: Bool
        let phase: ScenePhase
    }
    var contextKey: RefreshContext {
        .init(scope: model.sessionForecastRefreshScope, ownerEpoch: history.responseEpoch, ownerReady: history.hasAuthorizedOwner,
              authority: model.forecastAuthorityGeneration, recovering: model.djSessionIsRecovering,
              unavailable: model.djSessionLiveUnavailable, phase: scenePhase)
    }
    // The task starts after the first paint. Idle for a new admitted context is
    // still pending, not a backend denial. Reset on mounting a new Horizon view.
    struct ReadProgress {
        var completedContext: RefreshContext?
        func showsLoading(context: RefreshContext, canRead: Bool, readInFlight: Bool) -> Bool {
            readInFlight || (context.phase == .active && canRead && completedContext != context)
        }
    }
    private var showsLoading: Bool {
        readProgress.showsLoading(context: contextKey, canRead: model.canRefreshSessionForecast,
                                  readInFlight: model.forecastLoading)
    }
    var body: some View {
        TimelineView(SessionEntryRefreshSchedule(deadlines: deadlines)) { clock in
            VStack(alignment: .leading, spacing: 12) {
                SessionHorizonHero()
                Text(text("ui.session.forecast.title")).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Text(text("ui.session.forecast.notice")).font(.callout).foregroundStyle(.secondary)
                if scenePhase == .active, let projection = model.visibleSessionForecast(at: clock.date) {
                    ForEach(Array(projection.imagery.enumerated()), id: \.offset) { _, image in
                        SessionForecastArtwork(model: model, projection: projection, artwork: image)
                    }
                    SessionForecastTextView(projection: projection, language: model.language)
                } else {
                    Text(text(showsLoading ? "ui.session.forecast.loading" : "ui.session.forecast.unavailable"))
                        .fixedSize(horizontal: false, vertical: true)
                    Button(text("ui.refresh.page")) { Task { await model.refreshSessionForecast() } }
                        .buttonStyle(.plain)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(minHeight: 44, alignment: .leading)
                        .disabled(showsLoading || !model.canRefreshSessionForecast)
                }
            }.padding(.horizontal, 20).padding(.bottom, 16)
                .scrollTargetLayout()
        }
        .accessibilityIdentifier("session-forecast-panel")
        .task(id: contextKey) {
            let context = contextKey
            guard context.phase == .active else { return }
            while !Task.isCancelled {
                await model.refreshSessionForecast()
                guard !Task.isCancelled, contextKey == context else { return }
                readProgress.completedContext = context
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
            }
        }
    }
}

private struct SessionHorizonHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private final class ShaderBundleToken {}

    private static let shaders: ShaderLibrary = {
        #if SWIFT_PACKAGE
        ShaderLibrary.bundle(.module)
        #else
        ShaderLibrary.bundle(Bundle(for: ShaderBundleToken.self))
        #endif
    }()

    var body: some View {
        GeometryReader { geometry in
            let artwork = Image("HorizonHero")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
            if !reduceMotion && scenePhase == .active {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { clock in
                    let seconds = clock.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 12)
                    artwork.distortionEffect(
                        Self.shaders.horizonWave(.boundingRect, .float(Float(seconds * 2 * .pi / 12))),
                        maxSampleOffset: CGSize(width: 0, height: 2)
                    )
                }
            } else {
                artwork
            }
        }
        .frame(height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(8)
        .djSessionFrostedSurface(
            cornerRadius: 22,
            surfaceTint: Color(red: 0.52, green: 0.26, blue: 0.72)
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Keeps the search row in place while revealing the shared glass field.
struct SessionCollapsibleSearch<Content: View>: View {
    let expanded: Bool
    let label: String
    let identifier: String
    let open: () -> Void
    let boundsChanged: (CGRect) -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            if expanded {
                content()
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
            } else {
                Button(action: open) {
                    Image(systemName: "magnifyingglass")
                        .font(.body.weight(.semibold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                .accessibilityIdentifier(identifier)
                .transition(.opacity)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: expanded)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { boundsChanged($0) }
    }
}

private struct SessionForecastArtwork: View {
    @ObservedObject var model: DJConnectAppModel
    let projection: DJConnectSessionForecast
    let artwork: DJConnectSessionForecast.Imagery
    @Environment(\.scenePhase) private var scenePhase
    @State private var pixels: DJConnectSessionArtworkImage?
    @State private var loadedKey: String?
    @State private var generation = UUID()
    private var permitted: Bool {
        scenePhase == .active && model.forecastImageIsCurrent(artwork, projection: projection)
    }
    private var requestKey: String {
        [projection.session_id, String(projection.revision), artwork.url,
         String(describing: model.sessionHistory.responseEpoch), String(permitted)].joined(separator: "|")
    }
    var body: some View {
        Group {
            if permitted, loadedKey == requestKey, let pixels, let logo = spotifyAttributionLogo,
               let source = URL(string: artwork.source_url) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(decorative: pixels.image, scale: 1).resizable().scaledToFit()
                        .frame(maxWidth: 480, maxHeight: 360)
                        .accessibilityLabel(artwork.subject.name)
                    Link(destination: source) {
                        HStack {
                            logo.resizable().scaledToFit().frame(width: 80, height: 24)
                            Text(artwork.subject.name)
                        }.frame(minHeight: 44)
                    }.accessibilityLabel("Spotify · " + artwork.subject.name)
                }.padding(16).frame(maxWidth: .infinity, alignment: .center).djSessionFrostedSurface()
            }
        }
        .task(id: requestKey) {
            let key = requestKey
            let request = UUID(); generation = request
            pixels = nil; loadedKey = nil
            guard permitted, spotifyAttributionLogo != nil,
                  let until = DJConnectSessionForecast.timestamp(projection.valid_until),
                  let imageUntil = DJConnectSessionForecast.timestamp(artwork.expires_at) else { return }
            defer { if generation == request { pixels = nil; loadedKey = nil } }
            do {
                let result = try await model.loadForecastImage(artwork, projection: projection)
                guard !Task.isCancelled, permitted, key == requestKey, generation == request else { return }
                pixels = result; loadedKey = key
                try await Task.sleep(for: .seconds(max(0, min(until, imageUntil).timeIntervalSinceNow)))
            } catch { /* Optional art failure never suppresses authored text. */ }
        }
        .onDisappear { generation = UUID(); pixels = nil; loadedKey = nil }
    }
}
