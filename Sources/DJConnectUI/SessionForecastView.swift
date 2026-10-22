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
                    Text(section.title).font(.title3.bold()).foregroundStyle(.white).accessibilityAddTraits(.isHeader)
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
    @Binding var query: String
    @State private var searchExpanded = false
    @State private var searchBounds = CGRect.zero
    @Environment(\.scenePhase) private var scenePhase
    init(model: DJConnectAppModel, viewport: SessionForecastViewport, query: Binding<String>, @ViewBuilder header: () -> Header) {
        self.model = model; self.header = header()
        self.viewport = viewport; _query = query
        // The panel is removed while Flow is selected. Restore its device-local
        // viewport even when no authored text ID intersects the top edge.
        _position = State(initialValue: ScrollPosition(y: viewport.offset))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                SessionForecastContent(model: model, query: $query, searchExpanded: $searchExpanded,
                                       searchBoundsChanged: { searchBounds = $0 })
            }
        }
        .scrollPosition($position)
        .simultaneousGesture(SpatialTapGesture(coordinateSpace: .global).onEnded { tap in
            if searchExpanded && !searchBounds.contains(tap.location) {
                searchExpanded = false; query = ""
            }
        })
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, value in viewport.record(value) }
    }
}

enum SessionForecastSearchPosition {
    static func target(fieldBounds: CGRect) -> String {
        fieldBounds.isEmpty ? "forecast-content" : "forecast-search"
    }
}

/// Lower content only: playback, artwork and persona stay owned by the Session.
struct SessionForecastContent: View {
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject private var history: DJConnectSessionHistoryModel
    @Binding var query: String
    @Binding var searchExpanded: Bool
    var focusRequest: UUID?
    var searchBoundsChanged: (CGRect) -> Void
    @State private var selectedSearchID: String?
    @FocusState private var searchFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    init(model: DJConnectAppModel, query: Binding<String>, searchExpanded: Binding<Bool>, focusRequest: UUID? = nil, searchBoundsChanged: @escaping (CGRect) -> Void) {
        self.model = model; history = model.sessionHistory; _query = query
        self.focusRequest = focusRequest
        _searchExpanded = searchExpanded; self.searchBoundsChanged = searchBoundsChanged
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
            ScrollViewReader { proxy in
                let resultIDs = scenePhase == .active && !query.isEmpty
                    ? (model.visibleSessionForecast(at: clock.date)?.sections.filter {
                        ($0.title + " " + $0.text).localizedCaseInsensitiveContains(query)
                    }.map(\.id) ?? []) : []
                VStack(alignment: .leading, spacing: 12) {
                    Text(text("ui.session.forecast.title")).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    Text(text("ui.session.forecast.notice")).font(.callout).foregroundStyle(.secondary)
                    if searchExpanded {
                    SessionCollapsibleSearch(expanded: searchExpanded, label: text("ui.session.forecast.search"),
                                             identifier: "session-forecast-search-toggle", open: { searchExpanded = true },
                                             boundsChanged: searchBoundsChanged) {
                    AskDJSearchBar(language: model.language, promptKey: "ui.session.forecast.search",
                                   fieldIdentifier: "session-forecast-search-field", countIdentifier: "session-forecast-search-count",
                                   closeLabelKey: "ui.close.search",
                                   focusRequest: focusRequest, text: $query, isFocused: $searchFocused,
                                   resultCount: resultIDs.count,
                                   selectedIndex: selectedSearchID.flatMap { resultIDs.firstIndex(of: $0) } ?? 0,
                                   previousAction: { moveSearch(-1, resultIDs: resultIDs, proxy: proxy) },
                                   nextAction: { moveSearch(1, resultIDs: resultIDs, proxy: proxy) },
                                   closeAction: { searchExpanded = false },
                                   submitAction: { moveSearch(1, resultIDs: resultIDs, proxy: proxy) })
                    }.id("forecast-search")
                    }
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
                            .disabled(model.forecastLoading || !model.canRefreshSessionForecast)
                    }
                }.padding(.horizontal, 20).padding(.bottom, 16)
                    .scrollTargetLayout()
            }
        }
        .onChange(of: query) { selectedSearchID = nil }
        .onChange(of: searchExpanded) { _, expanded in
            searchFocused = expanded
            if !expanded { query = ""; selectedSearchID = nil }
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
    private func moveSearch(_ delta: Int, resultIDs: [String], proxy: ScrollViewProxy) {
        guard !resultIDs.isEmpty else { return }
        let current = selectedSearchID.flatMap { resultIDs.firstIndex(of: $0) }
        let next = current.map { ($0 + delta + resultIDs.count) % resultIDs.count }
            ?? (delta < 0 ? resultIDs.count - 1 : 0)
        selectedSearchID = resultIDs[next]
        proxy.scrollTo(resultIDs[next], anchor: .top)
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
