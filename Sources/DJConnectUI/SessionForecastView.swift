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
    var query = ""
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(projection.summary).font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled).id("forecast-summary")
            ForEach(projection.sections.filter { query.isEmpty || ($0.title + " " + $0.text).localizedCaseInsensitiveContains(query) }) { section in
                VStack(alignment: .leading, spacing: 10) {
                    Text(section.title).font(.headline).foregroundStyle(.white).accessibilityAddTraits(.isHeader)
                    Text(text("ui.session.forecast.claim." + section.claim_type))
                        .font(.caption).foregroundStyle(.white.opacity(0.78))
                    Text(section.text).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    if let source = section.source_url.flatMap(URL.init(string:)) {
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
}

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
    @ObservedObject private var history: DJConnectSessionHistoryModel
    let header: Header
    let viewport: SessionForecastViewport
    @State private var position: ScrollPosition
    @Binding var query: String
    @Environment(\.scenePhase) private var scenePhase
    init(model: DJConnectAppModel, viewport: SessionForecastViewport, query: Binding<String>, @ViewBuilder header: () -> Header) {
        self.model = model; history = model.sessionHistory; self.header = header()
        self.viewport = viewport; _query = query
        // The panel is removed while Flow is selected. Restore its device-local
        // viewport even when no authored text ID intersects the top edge.
        _position = State(initialValue: ScrollPosition(y: viewport.offset))
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
    var body: some View {
        TimelineView(SessionEntryRefreshSchedule(deadlines: deadlines)) { clock in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(text("ui.session.forecast.title")).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        Text(text("ui.session.forecast.notice")).font(.callout).foregroundStyle(.secondary)
                        TextField(text("ui.session.forecast.search"), text: $query)
                            .textFieldStyle(.plain).padding(12).djSessionFrostedSurface()
                            .accessibilityLabel(text("ui.session.forecast.search"))
                        if scenePhase == .active, let projection = model.visibleSessionForecast(at: clock.date) {
                            ForEach(Array(projection.imagery.enumerated()), id: \.offset) { _, image in
                                SessionForecastArtwork(model: model, projection: projection, artwork: image)
                            }
                            SessionForecastTextView(projection: projection, language: model.language, query: query)
                        } else {
                            Text(text(model.forecastLoading ? "ui.session.forecast.loading" : "ui.session.forecast.unavailable"))
                                .fixedSize(horizontal: false, vertical: true)
                            Button(text("ui.refresh.page")) { Task { await model.refreshSessionForecast() } }
                                .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, usesLiveGlass: false))
                                .disabled(model.forecastLoading || !model.canRefreshSessionHistory)
                        }
                    }.padding(.horizontal, 20)
                }.padding(.vertical, 16)
            }
            .scrollPosition($position)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, value in
                viewport.record(value)
            }
        }
        .accessibilityIdentifier("session-forecast-panel")
        .task(id: contextKey) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await model.refreshSessionForecast()
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
            }
        }
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
