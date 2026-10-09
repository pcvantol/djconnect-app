import SwiftUI
import DJConnectCore

struct SavedSessionsView: View {
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject private var history: DJConnectSessionHistoryModel
    @Environment(\.scenePhase) private var scenePhase
    init(model: DJConnectAppModel) { self.model = model; history = model.sessionHistory }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if history.listLoading || history.preparing { ProgressView().accessibilityLabel(text("ui.session.history.loading")) }
                    if let key = history.listErrorKey {
                        Text(text(key)); Button(text("ui.retry")) { Task { await history.prepare(); await history.loadSessions() } }
                    } else if !history.available && !history.preparing {
                        Text(text("ui.session.history.unavailable"))
                    } else if history.sessions.isEmpty && !history.listLoading && !history.preparing {
                        Text(text("ui.session.history.empty"))
                    }
                    ForEach(history.sessions) { session in
                        NavigationLink {
                            SessionTimelineScreen(model: model, sessionID: session.id)
                                .navigationTitle(text("ui.session.history.title"))
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    SessionTimestampText(value: session.startedAt.isEmpty ? session.createdAt : session.startedAt, language: model.language)
                                        .font(.headline).multilineTextAlignment(.leading)
                                    Text(text(session.lifecycleStatus == "INTERRUPTED" ? "ui.session.history.interrupted" : "ui.session.history.ended"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(); Image(systemName: "chevron.right")
                            }
                            .padding(16).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("saved-session-" + session.id)
                    }
                    if history.listNextCursor != nil {
                        Button(text("ui.session.history.more")) { Task { await history.loadSessions(more: true) } }
                            .disabled(history.listLoading)
                    }
                }
                .frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity).padding(20)
            }
            .background(DJConnectCanvasBackground())
            .navigationTitle(text("ui.session.history.title"))
            .refreshable { await history.prepare(); await history.loadSessions() }
            .task { await history.restoreVisibleSessions() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await history.restoreVisibleSessions() } }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("screen-saved-sessions")
        }
    }
}

/// The same native timeline surface serves the active Session and readonly archive.
struct SessionTimelineScreen: View {
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject private var history: DJConnectSessionHistoryModel
    let sessionID: String
    var activeSession: DJConnectSessionRuntime?
    var initialAnchor: String?
    var openQueueAction: () -> Void = {}
    @State private var visibleEntry: String?
    @State private var priorSearchPosition: String?
    @State private var query = ""
    @State private var searching = false
    @State private var selectedMatchID: String?
    @State private var hasNewEntries = false
    @State private var positionUnavailable = false
    @State private var resumePosition: String?
    @State private var anchorGeneration = UUID()
    @State private var sceneRestoreTask: Task<Void, Never>?
    @FocusState private var inputFocused: Bool
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init(model: DJConnectAppModel, sessionID: String, activeSession: DJConnectSessionRuntime? = nil,
         initialAnchor: String? = nil, openQueueAction: @escaping () -> Void = {}) {
        self.model = model; history = model.sessionHistory; self.sessionID = sessionID
        self.activeSession = activeSession; self.initialAnchor = initialAnchor; self.openQueueAction = openQueueAction
    }
    private var timeline: DJConnectSessionHistoryModel.Timeline { history.timelines[sessionID] ?? .init() }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    private var matches: [DJConnectHistoryEntry] {
        history.acceptedSearchSessionID == sessionID && history.acceptedSearchQuery == query ? history.searchMatches.filter { $0.isRetained() } : []
    }
    private var selectedIndex: Int { matches.firstIndex(where: { $0.id == selectedMatchID }) ?? 0 }
    private var canSend: Bool {
        history.profileScopeActive && model.canUseProfileConversation && !model.isSendingAskDJText &&
        !model.askDJDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if searching { TimelineView(.periodic(from: .now, by: 1)) { _ in searchBar(proxy: proxy) } }
                TimelineView(.periodic(from: .now, by: 1)) { clock in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            if let activeSession {
                                NativeSessionMomentsView(session: activeSession, language: model.language,
                                    isRecovering: model.djSessionIsRecovering,
                                    isLiveUnavailable: model.djSessionLiveUnavailable,
                                    retryConnection: { Task { await model.retryDJSessionConnection() } },
                                    artworkBaseURL: URL(string: model.haLocalURL.isEmpty ? model.homeAssistantURL : model.haLocalURL),
                                    returnToCurrent: { jump("current", proxy: proxy) }, showsFlow: false)
                                    .id("current")
                            } else {
                                Label(text("ui.session.history.readonly"), systemImage: "lock")
                                    .font(.headline).accessibilityAddTraits(.isHeader)
                            }
                            if positionUnavailable { Text(text("ui.session.history.changed")) }
                            if timeline.loading { ProgressView() }
                            if let key = timeline.errorKey {
                                Text(text(key)); Button(text("ui.retry")) { Task { await history.loadTimeline(sessionID) } }
                            }
                            ForEach(timeline.entries.filter { $0.isRetained(at: clock.date) }) { entry in
                                SessionEntryView(entry: entry, language: model.language,
                                    highlights: matches.first(where: { $0.id == entry.id && $0.text == entry.text })?.highlights ?? [],
                                    isSelectedMatch: selectedMatchID == entry.id || initialAnchor == entry.id,
                                    selected: history.selectedEntry == entry.reference) {
                                        history.selectedEntry = entry.reference
                                        if activeSession == nil {
                                            history.openTarget = nil
                                            model.performHomeScreenAction(.askDJ)
                                        } else { inputFocused = true }
                                    }
                                    .id(entry.id).accessibilityElement(children: .contain).accessibilityIdentifier("session-entry-" + entry.id)
                            }
                            if timeline.entries.isEmpty && !timeline.loading && timeline.errorKey == nil {
                                Text(text(activeSession == nil ? "ui.session.history.no_entries" : "ui.session.history.no_entries_active"))
                            }
                            if timeline.nextCursor != nil {
                                Button(text("ui.session.history.more")) { Task { await history.loadTimeline(sessionID, more: true) } }
                                    .disabled(timeline.loading)
                            } else if timeline.windowed {
                                Button(text("ui.session.history.earlier")) { Task { await history.loadTimeline(sessionID) } }
                                    .disabled(timeline.loading)
                            }
                            ForEach(history.pendingTurns.filter { $0.context.sessionID == sessionID }) { turn in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(turn.text).fixedSize(horizontal: false, vertical: true)
                                    if turn.failed {
                                        Text(text(turn.contextChanged ? "ui.session.history.changed" : "ui.session.history.unavailable"))
                                        Button(text(turn.contextChanged ? "ui.session.history.current_context" : "ui.retry")) {
                                            if turn.contextChanged { history.useCurrentContext(turn) }
                                            else { history.retry(turn) }
                                        }
                                    } else { Label(text("ui.session.history.awaiting"), systemImage: "ellipsis.bubble") }
                                }
                                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .id("pending-" + turn.id)
                            }
                            if let activeSession {
                                ActiveDJSessionView(model: model, session: activeSession, openQueueAction: openQueueAction, showsMoments: false)
                            }
                            Color.clear.frame(height: 1).id("tail")
                        }
                        .frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity).padding(20)
                        .scrollTargetLayout()
                    }
                    .scrollPosition(id: $visibleEntry, anchor: .top)
                    .refreshable { await history.refreshConversation(); await history.loadTimeline(sessionID) }
                }
                if activeSession != nil {
                    HStack {
                        Button(text("ui.session.back_current")) { jump("current", proxy: proxy) }
                        Spacer()
                        if hasNewEntries {
                            Button(text("ui.session.history.new_entries")) { jump("tail", proxy: proxy); hasNewEntries = false }
                        }
                    }.font(.footnote).padding(.horizontal, 20).padding(.vertical, 8)
                    AskDJInputBar(model: model, canSend: canSend,
                                  canUseVoiceInput: model.canUseProfileConversation && model.voiceEnabled,
                                  isInputFocused: $inputFocused)
                }
            }
            .background(DJConnectCanvasBackground())
            .toolbar {
                if activeSession != nil {
                    Button(role: .destructive) { Task { await model.endDJSession() } } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .disabled(model.isLoadingDJSession)
                    .accessibilityLabel(text("ui.session.end"))
                    .accessibilityIdentifier("session-end-button")
                    .help(text("ui.session.end"))
                }
                Button {
                    if searching { closeSearch(proxy: proxy) }
                    else { priorSearchPosition = visibleEntry; searching = true; searchFocused = true }
                } label: { Image(systemName: "magnifyingglass") }
                    .disabled(!history.searchAvailable)
                    .accessibilityLabel(text("ui.session.history.search"))
                    .accessibilityIdentifier("session-search-toggle")
                    .keyboardShortcut("f", modifiers: .command)
            }
            .task(id: sessionID) {
                let restoreGeneration = anchorGeneration
                await history.prepare(); await history.loadTimeline(sessionID, window: activeSession == nil ? nil : .tail)
                guard !Task.isCancelled, restoreGeneration == anchorGeneration else { return }
                if let initialAnchor { await selectAnchor(initialAnchor, proxy: proxy, restoreRequest: true) }
                else if let anchor = history.readingAnchor(sessionID: sessionID) {
                    if ["current", "tail"].contains(anchor) { jump(anchor, proxy: proxy) }
                    else { await selectAnchor(anchor, proxy: proxy, restoreRequest: true) }
                }
            }
            .task(id: activeSession?.id) {
                guard activeSession != nil else { return }
                while !Task.isCancelled {
                    if model.canRefreshSessionHistory {
                        await history.refreshConversation()
                        await history.refreshVisibleTimeline(sessionID, anchor: visibleEntry)
                    }
                    try? await Task.sleep(for: .seconds(10))
                }
            }
            .onChange(of: query) { _, value in sceneRestoreTask?.cancel(); anchorGeneration = UUID(); history.search(sessionID: sessionID, query: value) }
            .onChange(of: history.searchMatches) {
                guard searching, !matches.isEmpty else { return }
                if !matches.contains(where: { $0.id == selectedMatchID }) {
                    selectedMatchID = matches.first?.id
                    if let id = selectedMatchID { Task { await selectAnchor(id, proxy: proxy, searchRequest: true) } }
                }
            }
            .onChange(of: timeline.entries.last?.id) { old, new in
                if old != nil, old != new { hasNewEntries = true }
            }
            .onChange(of: timeline.revision) {
                if searching && !query.isEmpty { history.search(sessionID: sessionID, query: query) }
            }
            .onChange(of: scenePhase) {
                if scenePhase == .inactive { resumePosition = visibleEntry }
                if scenePhase == .active {
                    sceneRestoreTask?.cancel()
                    let restoreGeneration = anchorGeneration
                    sceneRestoreTask = Task {
                        await history.restoreVisibleTimeline(sessionID, active: activeSession != nil, anchor: resumePosition)
                        guard !Task.isCancelled, restoreGeneration == anchorGeneration else { return }
                        guard let resumePosition else {
                            if let initialAnchor { await selectAnchor(initialAnchor, proxy: proxy, restoreRequest: true) }
                            else if activeSession != nil { jump("current", proxy: proxy) }
                            return
                        }
                        if resumePosition.hasPrefix("pending-") {
                            if history.pendingTurns.contains(where: { "pending-" + $0.id == resumePosition }) { jump(resumePosition, proxy: proxy) }
                            else if activeSession != nil { jump("current", proxy: proxy) }
                        } else if !["current", "tail"].contains(resumePosition) {
                            await selectAnchor(resumePosition, proxy: proxy, restoreRequest: true)
                        } else if activeSession != nil { jump("current", proxy: proxy) }
                    }
                }
            }
            .onDisappear {
                history.rememberReadingAnchor(visibleEntry, sessionID: sessionID)
                sceneRestoreTask?.cancel(); anchorGeneration = UUID(); history.clearSearch()
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(activeSession == nil ? "screen-history-timeline" : "screen-session-conversation")
        }
    }

    private func jump(_ id: String, proxy: ScrollViewProxy) {
        sceneRestoreTask?.cancel()
        anchorGeneration = UUID()
        // One scroll controller: mixing proxy animation with the bound target can
        // let a layout/keyboard measurement overwrite the requested anchor.
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { visibleEntry = id }
    }
    private func selectAnchor(_ id: String, proxy: ScrollViewProxy, searchRequest: Bool = false, restoreRequest: Bool = false) async {
        guard !id.hasPrefix("pending-"), !["current", "tail"].contains(id), !searchRequest || searching else { return }
        if !restoreRequest { sceneRestoreTask?.cancel() }
        let generation = UUID(); anchorGeneration = generation
        let capturedQuery = query
        let action = DJConnectSessionOpenAction(reference: .init(sessionID: sessionID, entryID: id))
        let accepted = await history.open(action, navigate: false)
        // Publish the canonical row before asking SwiftUI to position it.
        await Task.yield()
        guard accepted, generation == anchorGeneration, !searchRequest || (searching && capturedQuery == query && selectedMatchID == id), timeline.entries.contains(where: { $0.id == id && $0.isRetained() }) else { return }
        jump(id, proxy: proxy)
    }
    private func closeSearch(proxy: ScrollViewProxy) {
        anchorGeneration = UUID(); searching = false; searchFocused = false; query = ""; selectedMatchID = nil; history.clearSearch()
        if let priorSearchPosition {
            if ["current", "tail"].contains(priorSearchPosition) || timeline.entries.contains(where: { $0.id == priorSearchPosition && $0.isRetained() }) {
                jump(priorSearchPosition, proxy: proxy)
            } else { positionUnavailable = true }
        }
    }
    private func moveMatch(_ delta: Int, proxy: ScrollViewProxy) {
        guard !matches.isEmpty else { return }
        let index = (selectedIndex + delta + matches.count) % matches.count
        selectedMatchID = matches[index].id
        let id = matches[index].id
        Task { await selectAnchor(id, proxy: proxy, searchRequest: true) }
    }
    @ViewBuilder private func searchBar(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(text("ui.session.history.search"), text: $query)
                    .textFieldStyle(.roundedBorder).focused($searchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        #if os(iOS)
                        searchFocused = false
                        #endif
                        moveMatch(1, proxy: proxy)
                    }
                    .accessibilityIdentifier("session-search-field")
                if history.searchLoading { ProgressView() }
                Button { moveMatch(-1, proxy: proxy) } label: { Image(systemName: "chevron.up") }
                    .disabled(matches.isEmpty).accessibilityLabel(text("ui.previous.result"))
                Button { moveMatch(1, proxy: proxy) } label: { Image(systemName: "chevron.down") }
                    .disabled(matches.isEmpty).accessibilityLabel(text("ui.next.result"))
                Button { closeSearch(proxy: proxy) } label: { Image(systemName: "xmark") }
                    .accessibilityLabel(text("ui.close.search"))
            }
            if let key = history.searchErrorKey {
                Text(text(key))
                Button(text("ui.retry")) { history.search(sessionID: sessionID, query: query) }
            } else if !query.isEmpty && !history.searchLoading && history.acceptedSearchQuery == query {
                HStack {
                    Text(matches.isEmpty && history.searchComplete ? text("ui.session.history.no_match") :
                         "\(matches.isEmpty ? 0 : selectedIndex + 1)/\(matches.count) · " + text(history.searchComplete ? "ui.session.history.complete" : "ui.session.history.partial"))
                        .accessibilityIdentifier("session-search-count")
                    if history.searchNextCursor != nil {
                        Button(text("ui.session.history.more")) { Task { await history.moreSearch() } }
                    }
                }
            }
        }
        .onChange(of: matches.map(\.id)) {
            if let selectedMatchID, !matches.contains(where: { $0.id == selectedMatchID }) {
                anchorGeneration = UUID(); self.selectedMatchID = nil; positionUnavailable = true
            }
        }
        .font(.callout).padding(16).background(.thinMaterial)
        .onKeyPress(.escape) { closeSearch(proxy: proxy); return .handled }
        .onKeyPress(.upArrow) { moveMatch(-1, proxy: proxy); return .handled }
        .onKeyPress(.downArrow) { moveMatch(1, proxy: proxy); return .handled }
    }
}

struct SessionHighlightedText: View {
    let text: String
    let highlights: [DJConnectHistoryHighlight]
    private var attributed: AttributedString {
        var result = AttributedString(text)
        for mark in highlights {
            guard let range = mark.safeRange(in: text), let stringRange = Range(range, in: text),
                  let lower = AttributedString.Index(stringRange.lowerBound, within: result),
                  let upper = AttributedString.Index(stringRange.upperBound, within: result) else { continue }
            result[lower..<upper].backgroundColor = .yellow
            result[lower..<upper].foregroundColor = .black
        }
        return result
    }
    var body: some View { Text(attributed).fixedSize(horizontal: false, vertical: true).textSelection(.enabled) }
}

struct SessionTimestampText: View {
    let value: String
    let language: String
    var body: some View {
        if let date = DJConnectHistoryEntry.date(value) {
            Text(date.formatted(.dateTime.locale(Locale(identifier: language)).year().month(.abbreviated).day().hour().minute()))
        }
    }
}

struct SessionEntryView: View {
    let entry: DJConnectHistoryEntry
    let language: String
    var highlights: [DJConnectHistoryHighlight] = []
    var isSelectedMatch = false
    var selected = false
    var askAction: () -> Void = {}
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entry.requiresSpotifyAttribution == true && spotifyAttributionLogo == nil {
                Text(text("ui.session.history.unavailable"))
            } else {
                if entry.kind == .conversationUser || entry.kind == .conversationDJ {
                    AskDJMessageBubble(message: DJConnectAskDJMessage(
                        serverID: entry.originMessageID, clientMessageID: entry.clientMessageID,
                        role: entry.kind == .conversationUser ? .user : .dj,
                        text: entry.text ?? "", createdAt: DJConnectHistoryEntry.date(entry.occurredAt) ?? .distantPast),
                        language: language, isStaleHistory: false, isAudioLoading: false, isAudioPlaying: false,
                        isRetryDisabled: true, playingActionID: nil, currentMood: nil,
                        isSearchResult: !highlights.isEmpty, isActiveSearchResult: isSelectedMatch, searchText: "",
                        retryAction: {}, playAction: { _ in }, audioAction: {}, trackInsightAction: {},
                        openLink: { _ in }, feedbackAction: { _ in }, setPromptAction: { _ in }, isReadOnly: true,
                        serverHighlights: highlights)
                    if entry.inputType == "voice" { Label(text("ui.session.history.voice"), systemImage: "mic.fill").font(.caption) }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(text(entry.kind == .djMoment ? "ui.session.moment.generic" : "ui.session.history.playback"),
                              systemImage: entry.kind == .djMoment ? "sparkles" : "music.note")
                            .font(.caption.weight(.semibold))
                        SessionHighlightedText(text: entry.text ?? "", highlights: highlights).font(.title3)
                        SessionTimestampText(value: entry.occurredAt, language: language).font(.caption).foregroundStyle(.secondary)
                        ForEach(sourceURLs, id: \.absoluteString) { url in
                            let key = url.absoluteString == entry.sourceAttribution?["url_previous"] ? "ui.session.source_previous" : "ui.session.source_current"
                            Link((entry.sourceAttribution?["provider"] ?? url.host ?? "") + " · " + text(key), destination: url)
                                .accessibilityValue(url.absoluteString)
                        }
                        if entry.requiresSpotifyAttribution == true, let logo = spotifyAttributionLogo,
                           let url = sourceURLs.first {
                            Link(destination: url) { logo.resizable().scaledToFit().frame(width: 110, height: 31).padding(16) }
                                .accessibilityLabel("Spotify")
                        }
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .djSessionFrostedSurface(cornerRadius: 20)
                }
                Button(text(selected ? "ui.session.history.selected_context" : "ui.session.history.ask_entry"), action: askAction)
                    .font(.caption).accessibilityIdentifier("ask-entry-" + entry.id)
            }
        }
        .padding(4).overlay(RoundedRectangle(cornerRadius: 20).stroke(isSelectedMatch ? Color.yellow : .clear, lineWidth: 2))
    }
    private var sourceURLs: [URL] {
        [entry.playback?.sourceURL, entry.sourceAttribution?["url"], entry.sourceAttribution?["url_previous"]]
            .compactMap { raw in
                guard let raw, let url = URL(string: raw), ["http", "https"].contains(url.scheme), url.user == nil, url.password == nil else { return nil }
                return url
            }
    }
}

struct SessionHistoryMatchCard: View {
    let entry: DJConnectHistoryEntry
    let language: String
    let open: (DJConnectSessionOpenAction) -> Void
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { clock in
        if entry.kind == .playbackObserved, entry.isRetained(at: clock.date),
           entry.playback?.coverage == "observed_playing_not_full_listen",
           entry.requiresSpotifyAttribution != true || spotifyAttributionLogo != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.text ?? "").font(.headline)
                SessionTimestampText(value: entry.occurredAt, language: language).font(.caption)
                Text(text("ui.session.history.observed")).font(.caption).foregroundStyle(.secondary)
                if entry.requiresSpotifyAttribution == true, let logo = spotifyAttributionLogo,
                   let raw = entry.playback?.sourceURL, let url = URL(string: raw), url.scheme == "https", url.host == "open.spotify.com" {
                    Link(destination: url) { logo.resizable().scaledToFit().frame(width: 110, height: 31).padding(16) }
                        .accessibilityLabel("Spotify")
                }
                if let action = entry.openAction, action.reference == entry.reference {
                    Button(text("ui.session.history.open")) { open(action) }
                        .buttonStyle(.plain)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("open-session-" + entry.id)
                }
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .djSessionFrostedSurface(cornerRadius: 14)
        }
        }
    }
}


struct SessionComposerContext: View {
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject private var history: DJConnectSessionHistoryModel
    init(model: DJConnectAppModel) { self.model = model; history = model.sessionHistory }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    var body: some View {
        if history.profileScopeActive {
            if history.selectedEntry != nil {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(text("ui.session.history.selected_context"), systemImage: "quote.bubble")
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            Text(history.selectedEntryPreview ?? text("ui.session.history.changed")).lineLimit(3)
                        }
                    }
                    Spacer()
                    Button(text("ui.close")) { history.selectedEntry = nil }
                        .accessibilityIdentifier("clear-session-question-context")
                }.font(.caption).accessibilityIdentifier("session-question-context")
            }
            if let error = model.voiceErrorMessage {
                Text(error).font(.caption).foregroundStyle(.red).accessibilityIdentifier("session-voice-error")
                Text(text("ui.hold.to.record.a.voice.request.for.ask.dj")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
