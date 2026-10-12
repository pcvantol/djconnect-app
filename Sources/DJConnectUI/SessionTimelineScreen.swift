import SwiftUI
import DJConnectCore

struct SavedSessionsView: View {
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject private var history: DJConnectSessionHistoryModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshing = false
    @State private var statusToast: DJConnectVisualNotice?
    @State private var openedSessionID: String?
    private let embedsNavigationStack: Bool
    init(model: DJConnectAppModel, embedsNavigationStack: Bool = true) {
        self.model = model; history = model.sessionHistory; self.embedsNavigationStack = embedsNavigationStack
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    @ViewBuilder var body: some View {
        if embedsNavigationStack { NavigationStack { content } }
        else { content }
    }
    private var content: some View {
            List {
                VStack(alignment: .leading, spacing: 16) {
                    if model.isDemoMode { Label(text("demo.session.notice"), systemImage: "sparkles").font(.caption).accessibilityIdentifier("session-demo-notice") }
                    if history.listLoading || history.preparing { ProgressView().accessibilityLabel(text("ui.session.history.loading")) }

                }
                .frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity).padding(.horizontal, 20)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                    ForEach(history.sessions) { session in
                        Button { openedSessionID = session.id } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title2.weight(.medium)).foregroundStyle(djConnectAccent)
                                    .frame(width: 52, height: 52)
                                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(SessionArchiveSummary.text(session, language: model.language))
                                        .font(.body.weight(.medium)).multilineTextAlignment(.leading)
                                    Text(text(session.lifecycleStatus == "INTERRUPTED" ? "ui.session.history.interrupted" : "ui.session.history.ended"))
                                        .font(.caption2.weight(.medium)).foregroundStyle(.secondary.opacity(0.82))
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.body.weight(.semibold)).foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 9)
                            .modifier(DJConnectMediaRowSurface())
                        }
                        .buttonStyle(DJConnectMediaRowButtonStyle())
                        .accessibilityIdentifier("saved-session-" + session.id)
                        .frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    if history.listNextCursor != nil {
                        Button(text("ui.session.history.more")) { Task { await history.loadSessions(more: true) } }
                            .disabled(history.listLoading)
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("saved-sessions-list")
            .background(DJConnectCanvasBackground())
            .overlay {
                if let emptyTitle {
                    VStack(spacing: 18) {
                        DJConnectEmptyState(title: emptyTitle, systemImage: "clock.arrow.circlepath")
                            .allowsHitTesting(false)
                        if history.listErrorKey != nil && model.pairingStatus == .paired && !model.isDemoMode {
                            Button(text("ui.retry")) { Task { await refresh() } }
                                .disabled(refreshing)
                        }
                    }
                    .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("saved-sessions-empty-state")
                }
            }
            .navigationDestination(item: $openedSessionID) { sessionID in
                SessionTimelineScreen(model: model, sessionID: sessionID)
                    .navigationTitle(text("ui.session.history.title"))
            }
            .navigationTitle(text("ui.session.history.title"))
            .scrollBounceBehavior(.always)
            .refreshable { await refresh() }
            .toolbar {
                Button { Task { await refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(refreshing || model.isDemoMode || model.pairingStatus != .paired)
                    .accessibilityLabel(text("ui.session.history.refresh"))
                    .accessibilityIdentifier("saved-sessions-refresh")
                    .help(text("ui.session.history.refresh"))
            }
            .djStatusToastOverlay(statusToast)
            .task { await history.restoreVisibleSessions() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await history.restoreVisibleSessions() } }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("screen-saved-sessions")
    }
    private var emptyTitle: String? {
        guard history.sessions.isEmpty, !history.listLoading, !history.preparing else { return nil }
        if let error = history.listErrorKey { return text(error) }
        return text(history.available ? "ui.session.history.empty" : "ui.session.history.unavailable")
    }
    private func refresh() async {
        guard !refreshing, !model.isDemoMode, model.pairingStatus == .paired else { return }
        refreshing = true
        defer { refreshing = false }
        statusToast = DJConnectVisualNotice(text: text("ui.session.history.loading"), systemImage: "arrow.clockwise")
        await history.prepare()
        let succeeded = await history.loadSessions()
        let notice = DJConnectVisualNotice(text: text(succeeded ? "ui.session.history.updated" : "ui.session.history.unavailable"),
                                          systemImage: succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
        statusToast = notice
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if statusToast?.id == notice.id { statusToast = nil }
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
    @State private var showingHandoff = false
    @State private var viewportHeight: CGFloat = 600
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
        history.acceptedSearchSessionID == sessionID && history.acceptedSearchQuery == query ? history.searchMatches.reversed().filter { $0.isRetained() } : []
    }
    private var selectedIndex: Int { matches.firstIndex(where: { $0.id == selectedMatchID }) ?? 0 }
    private var canSend: Bool {
        (model.isDemoMode ? model.canUseAskDJFeatures : history.profileScopeActive && model.canUseProfileConversation) && !model.isSendingAskDJText &&
        !model.askDJDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if model.isDemoMode && activeSession == nil { Label(text("demo.session.notice"), systemImage: "sparkles").font(.caption).padding(8).accessibilityIdentifier("session-demo-notice") }
                TimelineView(SessionEntryRefreshSchedule(deadlines: timeline.entries.compactMap { DJConnectHistoryEntry.date($0.retainedUntil) })) { clock in
                    ScrollView {
                        DJSessionGlassGroup {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            Color.clear.frame(height: 1).id("current")
                            if activeSession == nil {
                                Label(text("ui.session.history.readonly"), systemImage: "lock")
                                    .font(.headline).accessibilityAddTraits(.isHeader)
                            }
                            if positionUnavailable { Text(text("ui.session.history.changed")) }
                            if let error = model.djSessionErrorMessage, activeSession != nil {
                                Text(error).foregroundStyle(.red)
                            }
                            if timeline.loading && timeline.entries.isEmpty { ProgressView() }
                            if let key = timeline.errorKey {
                                Text(text(key)); Button(text("ui.retry")) { Task { await history.loadTimeline(sessionID, window: .tail) } }
                            }
                            ForEach(history.pendingTurns.reversed().filter { $0.context.sessionID == sessionID }) { turn in
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
                                .djSessionFrostedSurface()
                                .id("pending-" + turn.id)
                            }
                            ForEach(timeline.entries.reversed().filter { $0.isRetained(at: clock.date) }) { entry in
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
                                Button(text("ui.session.history.earlier")) { Task { await history.loadTimeline(sessionID, preserveLoadedEntries: true) } }
                                    .disabled(timeline.loading)
                            }
                            Color.clear.frame(height: 1).id("tail")
                        }
                        .frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity).padding(20)
                        .scrollTargetLayout()
                        }
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            if let activeSession { pinnedCurrent(activeSession) }
                            if searching {
                                TimelineView(SessionEntryRefreshSchedule(deadlines: history.searchMatches.compactMap { DJConnectHistoryEntry.date($0.retainedUntil) })) { _ in searchBar(proxy: proxy) }
                            }
                        }
                    }
                    .scrollPosition(id: $visibleEntry, anchor: .top)
                    .refreshable { await history.refreshConversation(); await history.refreshVisibleTimeline(sessionID, anchor: visibleEntry) }
                }
                if activeSession != nil {
                    if hasNewEntries {
                        Button(text("ui.session.history.new_entries")) {
                            jump(timeline.entries.last?.id ?? "current", proxy: proxy)
                            hasNewEntries = false
                        }
                        .font(.footnote).padding(.horizontal, 20).padding(.vertical, 8)
                    }
                    AskDJInputBar(model: model, canSend: canSend,
                                  canUseVoiceInput: (model.isDemoMode || model.canUseProfileConversation) && model.voiceEnabled,
                                  isInputFocused: $inputFocused)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
            .background(DJConnectCanvasBackground())
            .toolbar {
                if let activeSession {
                    SessionConnectionToolbarButton(model: model)
                    ActiveSessionMoodToolbar(model: model, session: activeSession)
                }
                if activeSession != nil {
                    SessionEndToolbarButton(model: model)
                }
                Button {
                    if searching { closeSearch(proxy: proxy) }
                    else { priorSearchPosition = visibleEntry; searching = true; searchFocused = true }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(searching ? djConnectAccent : .primary)
                }
                    .disabled(!history.searchAvailable)
                    .accessibilityLabel(text("ui.session.history.search"))
                    .accessibilityIdentifier("session-search-toggle")
                    .keyboardShortcut("f", modifiers: .command)
                if let activeSession, !model.isDemoMode {
                    Button { showingHandoff.toggle() } label: {
                        Image(systemName: "tv.badge.wifi")
                    }
                    .accessibilityLabel(text("ui.vibecast.handoff.title"))
                    .accessibilityIdentifier("session-handoff-toggle")
                    .help(text("ui.vibecast.handoff.title"))
                    .popover(isPresented: $showingHandoff) {
                        VStack(spacing: 0) {
                            HStack {
                                Spacer()
                                Button { showingHandoff = false } label: { Image(systemName: "xmark") }
                                    .accessibilityLabel(text("ui.close"))
                                    .accessibilityIdentifier("session-handoff-close")
                                    .keyboardShortcut(.cancelAction)
                            }.padding(12)
                            ScrollView {
                                ActiveDJSessionView(model: model, session: activeSession,
                                                    openQueueAction: openQueueAction, showsMoments: false)
                            }
                        }
                        .frame(idealWidth: 400, idealHeight: 300)
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .task(id: sessionID) {
                let restoreGeneration = anchorGeneration
                await history.prepare(); await history.loadTimeline(sessionID, window: .tail)
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
            .onChange(of: activeSession?.id) { showingHandoff = false }
            .onChange(of: history.profileScopeActive) { showingHandoff = false }
            .onChange(of: query) { _, value in sceneRestoreTask?.cancel(); anchorGeneration = UUID(); history.search(sessionID: sessionID, query: value) }
            .onChange(of: history.searchMatches) {
                guard searching, !matches.isEmpty else { return }
                if !matches.contains(where: { $0.id == selectedMatchID }) {
                    selectedMatchID = matches.first?.id
                    if let id = selectedMatchID { Task { await selectAnchor(id, proxy: proxy, searchRequest: true) } }
                }
            }
            .onChange(of: timeline.entries.last?.id) { old, new in
                if old != nil, old != new, visibleEntry != "current", visibleEntry != new { hasNewEntries = true }
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

    private func pinnedCurrent(_ session: DJConnectSessionRuntime) -> some View {
        let limit = max(60, viewportHeight * 0.4)
        let header = VStack(alignment: .leading, spacing: 12) {
            if model.isDemoMode {
                Label(text("demo.session.notice"), systemImage: "sparkles")
                    .font(.caption).frame(maxWidth: .infinity).padding(.bottom, 8)
                    .accessibilityIdentifier("session-demo-notice")
            }
            NativeSessionMomentsView(session: session, language: model.language,
            isRecovering: model.djSessionIsRecovering,
            isLiveUnavailable: model.djSessionLiveUnavailable,
            retryConnection: { Task { await model.retryDJSessionConnection() } },
            artworkBaseURL: URL(string: model.haLocalURL.isEmpty ? model.homeAssistantURL : model.haLocalURL),
            showsFlow: false, playbackOutputName: model.sessionPlaybackOutputName, playbackModel: model)
        }.padding(20).fixedSize(horizontal: false, vertical: true)
        return ViewThatFits(in: .vertical) {
            header
            ScrollView { header }.frame(height: limit)
        }
        .frame(maxHeight: limit, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .background(DJSessionPinnedMoodBackground(mood: session.selectedMood))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("session-pinned-current")
    }

    private func jump(_ id: String, proxy: ScrollViewProxy) {
        sceneRestoreTask?.cancel()
        anchorGeneration = UUID()
        // One scroll controller: mixing proxy animation with the bound target can
        // let a layout/keyboard measurement overwrite the requested anchor.
        let target = id == "tail" ? (timeline.entries.last?.id ?? "current") : id
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { visibleEntry = target }
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
            AskDJSearchBar(language: model.language, scopeName: text("ui.session.history.title"),
                           fieldIdentifier: "session-search-field", countIdentifier: "session-search-count",
                           isLoading: history.searchLoading, text: $query, isFocused: $searchFocused,
                           resultCount: history.acceptedSearchQuery == query ? matches.count : 0,
                           selectedIndex: selectedIndex,
                           previousAction: { moveMatch(-1, proxy: proxy) },
                           nextAction: { moveMatch(1, proxy: proxy) },
                           closeAction: { closeSearch(proxy: proxy) },
                           submitAction: {
                               #if os(iOS)
                               searchFocused = false
                               #endif
                               moveMatch(1, proxy: proxy)
                           })
            if let key = history.searchErrorKey {
                Text(text(key))
                Button(text("ui.retry")) { history.search(sessionID: sessionID, query: query) }
            } else if !query.isEmpty && !history.searchLoading && history.acceptedSearchQuery == query {
                HStack {
                    Text(matches.isEmpty && history.searchComplete ? text("ui.session.history.no_match") :
                         text(history.searchComplete ? "ui.session.history.complete" : "ui.session.history.partial"))
                        .font(.caption).foregroundStyle(.secondary)
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
        .font(.callout).padding(.horizontal, 20).padding(.vertical, 10)
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
            result[lower..<upper].backgroundColor = djConnectAccent.opacity(0.48)
            result[lower..<upper].foregroundColor = .white
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
                        serverHighlights: highlights, contextQuestionAction: askAction,
                        contextQuestionSelected: selected, contextQuestionID: "ask-entry-" + entry.id)
                    if entry.inputType == "voice" { Label(text("ui.session.history.voice"), systemImage: "mic.fill").font(.caption) }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(text(entry.kind == .djMoment ? "ui.session.moment.generic" : "ui.session.history.playback"),
                              systemImage: entry.kind == .djMoment ? "sparkles" : "music.note")
                            .font(.caption.weight(.semibold)).padding(.trailing, 40)
                        SessionHighlightedText(text: entry.text ?? "", highlights: highlights).font(.title3)
                        SessionTimestampText(value: entry.occurredAt, language: language).font(.caption).foregroundStyle(.secondary)
                        ForEach(sourceURLs, id: \.absoluteString) { url in
                            let key = url.absoluteString == entry.sourceAttribution?["url_previous"] ? "ui.session.source_previous" : "ui.session.source_current"
                            Link((entry.sourceAttribution?["provider"] ?? url.host ?? "") + " · " + text(key), destination: url)
                                .accessibilityValue(url.absoluteString)
                        }
                        if entry.requiresSpotifyAttribution == true, let logo = spotifyAttributionLogo,
                           let url = sourceURLs.first {
                            Link(destination: url) { logo.resizable().scaledToFit().frame(width: 70, height: 20).padding(10).frame(minHeight: 44).contentShape(Rectangle()) }
                                .accessibilityLabel("Spotify")
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .topTrailing) { askButton.padding(8) }
                    .djSessionFrostedSurface(cornerRadius: DJConnectCardAppearance.conversationCornerRadius)
                }
            }
        }
        .padding(4)
    }
    private var askButton: some View {
        Button(action: askAction) {
            Image(systemName: selected ? "checkmark.bubble" : "bubble.left.and.bubble.right")
                .font(.system(size: 16))
                .foregroundStyle(selected ? djConnectAccent : .secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text("ui.session.history.ask_entry"))
        .accessibilityValue(selected ? text("ui.session.history.selected_context") : "")
        .accessibilityIdentifier("ask-entry-" + entry.id)
        .help(text(selected ? "ui.session.history.selected_context" : "ui.session.history.ask_entry"))
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
                    Link(destination: url) { logo.resizable().scaledToFit().frame(width: 70, height: 20).padding(10).frame(minHeight: 44).contentShape(Rectangle()) }
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
                .djSessionFrostedSurface(cornerRadius: DJConnectCardAppearance.conversationCornerRadius)
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
        if history.profileScopeActive || model.isDemoMode {
            if history.selectedEntry != nil {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(text("ui.session.history.selected_context"), systemImage: "quote.bubble")
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            Text(history.selectedEntryPreview ?? text("ui.session.history.changed")).lineLimit(3)
                        }
                    }
                    Spacer()
                    Button { history.selectedEntry = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(text("ui.close"))
                    .help(text("ui.close"))
                    .accessibilityIdentifier("clear-session-question-context")
                }.font(.caption)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("session-question-context")
            }
            if let error = model.voiceErrorMessage {
                Text(error).font(.caption).foregroundStyle(.red).accessibilityIdentifier("session-voice-error")
                Text(text("ui.hold.to.record.a.voice.request.for.ask.dj")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}


/// Display only server-confirmed timestamps; never infer an end from playback or last entry.
enum SessionArchiveSummary {
    static func text(_ session: DJConnectSavedSession, language: String,
                     timeZone: TimeZone = .current) -> String {
        guard let created = DJConnectHistoryEntry.date(session.createdAt) else { return "" }
        let locale = Locale(identifier: language)
        let date = DateFormatter()
        date.locale = locale; date.timeZone = timeZone
        date.setLocalizedDateFormatFromTemplate("EEE d MMMM yyyy")
        let time = DateFormatter()
        time.locale = locale; time.timeZone = timeZone; time.dateFormat = "HH:mm"
        let endValue = session.endedAt.isEmpty && session.lifecycleStatus == "INTERRUPTED" ? session.interruptedAt : session.endedAt
        guard let start = DJConnectHistoryEntry.date(session.startedAt) else {
            let endLabel = DJConnectHistoryEntry.date(endValue).map { date.string(from: $0) + " " + time.string(from: $0) }
                ?? DJConnectLocalization.localized(key: "ui.session.history.end_unknown", language: language)
            return date.string(from: created) + " (" + DJConnectLocalization.localized(key: "ui.session.history.start_unknown", language: language) + " – " + endLabel + ")"
        }
        guard let end = DJConnectHistoryEntry.date(endValue), end >= start else {
            return date.string(from: start) + " (" + time.string(from: start) + " – " +
                DJConnectLocalization.localized(key: "ui.session.history.end_unknown", language: language) + ")"
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale; calendar.timeZone = timeZone
        let duration = DateComponentsFormatter()
        duration.calendar = calendar; duration.unitsStyle = .full
        duration.allowedUnits = end.timeIntervalSince(start) >= 3600 ? [.hour, .minute] : [.minute]
        duration.zeroFormattingBehavior = .dropAll
        let elapsed = end.timeIntervalSince(start)
        let length = elapsed < 60
            ? DJConnectLocalization.localized(key: "ui.session.history.less_than_minute", language: language)
            : duration.string(from: floor(elapsed / 60) * 60) ?? ""
        let endLabel = calendar.isDate(start, inSameDayAs: end) ? time.string(from: end) : date.string(from: end) + " " + time.string(from: end)
        return date.string(from: start) + " – " + length + " (" + time.string(from: start) + " – " + endLabel + ")"
    }
}

struct ActiveSessionMoodToolbar: View {
    @ObservedObject var model: DJConnectAppModel
    let session: DJConnectSessionRuntime
    @Environment(\.scenePhase) private var scenePhase
    private struct MoodIntent: Identifiable {
        let id = UUID()
        let sessionID: String
        let epoch: UUID
    }
    @State private var moodIntent: MoodIntent?
    #if os(macOS)
    @FocusState private var moodPopoverFocused: Bool
    #endif
    @ObservedObject private var history: DJConnectSessionHistoryModel
    init(model: DJConnectAppModel, session: DJConnectSessionRuntime) {
        self.model = model; self.session = session; history = model.sessionHistory
    }
    private let moods = ["chill", "groove", "energy", "party"]
    private var selectedIndex: Int { moods.firstIndex(of: session.selectedMood) ?? 0 }
    private var canChange: Bool { model.activeMoodAvailable && !model.activeMoodPending && session.confirmedMoodRevision != nil }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    var body: some View {
        Button {
            if moodIntent != nil { moodIntent = nil }
            else { moodIntent = MoodIntent(sessionID: session.id, epoch: history.responseEpoch) }
        } label: {
            Image(systemName: askDJMoodIcon(for: selectedIndex))
        }
        .accessibilityLabel(text("ui.session.select_mood"))
        .accessibilityValue(text("ui.session.mood." + moods[selectedIndex]))
        .accessibilityIdentifier("session-mood-toggle")
        .help(text("ui.session.select_mood"))
        .popover(item: $moodIntent) { intent in
            VStack(alignment: .leading, spacing: 12) {
                MoodModeControl(steps: moods.enumerated().map { (text("ui.session.mood." + $0.element), $0.offset) },
                                selectedIndex: selectedIndex, language: model.language,
                                caption: text("ui.session.select_mood"),
                                selectableLabels: true,
                                commitsOnDragEnd: true, showsCardBackground: false) { index in
                    guard canChange, moods.indices.contains(index) else { return }
                    Task { await model.changeActiveSessionMood(moods[index], expectedSessionID: intent.sessionID, expectedEpoch: intent.epoch) }
                }
                .disabled(!canChange)
                .accessibilityIdentifier("active-session-mood")
                if model.activeMoodPending { ProgressView(text("ui.session.mood.updating")) }
                if let error = model.activeMoodError { Text(error).font(.caption).foregroundStyle(.secondary) }
            }
            .padding(12).frame(idealWidth: 360)
            #if os(macOS)
            .focusable()
            .focusEffectDisabled()
            .focused($moodPopoverFocused)
            .onAppear { moodPopoverFocused = true }
            .onChange(of: selectedIndex) { moodPopoverFocused = true }
            .onDisappear { moodPopoverFocused = false }
            .onKeyPress(.escape) { moodIntent = nil; return .handled }
            .onExitCommand { moodIntent = nil }
            #endif
            .presentationCompactAdaptation(.popover)
        }
        .task(id: session.id) { await model.refreshActiveMoodCapability() }
        .onChange(of: session.id) { moodIntent = nil }
        .onChange(of: history.responseEpoch) { moodIntent = nil }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refreshActiveMoodCapability() } }
            else { moodIntent = nil }
        }
    }
}

/// Refresh relative timestamps once per minute, but expire authorized entries
/// exactly at their server deadline rather than delaying revocation to a tick.
struct SessionEntryRefreshSchedule: TimelineSchedule {
    let deadlines: [Date]
    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnySequence<Date> {
        let future = deadlines.filter { $0 > startDate }.sorted()
        return AnySequence {
            var index = 0
            var first = true
            var nextMinute = Date(timeIntervalSince1970: (floor(startDate.timeIntervalSince1970 / 60) + 1) * 60)
            return AnyIterator<Date> {
                if first { first = false; return startDate }
                if index < future.count, future[index] <= nextMinute {
                    let deadline = future[index]
                    while index < future.count && future[index] == deadline { index += 1 }
                    if deadline == nextMinute { nextMinute = nextMinute.addingTimeInterval(60) }
                    return deadline
                }
                let tick = nextMinute; nextMinute = nextMinute.addingTimeInterval(60)
                return tick
            }
        }
    }
}

/// Bind confirmation to the session that was visible when the owner clicked End.
struct SessionEndToolbarButton: View {
    @ObservedObject var model: DJConnectAppModel
    @State private var confirming = false
    @State private var requestedSessionID: String?

    private func text(_ key: String) -> String {
        DJConnectLocalization.localized(key: key, language: model.language)
    }

    var body: some View {
        Button(role: .destructive) {
            requestedSessionID = model.activeDJSession?.id
            confirming = requestedSessionID != nil
        } label: {
            Image(systemName: "xmark.circle")
        }
        .disabled(model.isLoadingDJSession || model.activeDJSession == nil)
        .accessibilityLabel(text("ui.session.end"))
        .accessibilityIdentifier("session-end-button")
        .help(text("ui.session.end"))
        .alert(text("ui.session.end.confirm"), isPresented: $confirming) {
            Button(text("ui.session.end"), role: .destructive) {
                let expectedSessionID = requestedSessionID
                requestedSessionID = nil
                Task { @MainActor in
                    guard let expectedSessionID, model.activeDJSession?.id == expectedSessionID else { return }
                    await model.endDJSession()
                }
            }
            .accessibilityIdentifier("session-end-confirm")
            Button(text("ui.cancel"), role: .cancel) { requestedSessionID = nil }
        }
        .onChange(of: model.activeDJSession?.id) { _, _ in
            confirming = false
            requestedSessionID = nil
        }
    }
}

struct SessionConnectionToolbarButton: View {
    @ObservedObject var model: DJConnectAppModel
    @State private var showingStatus = false
    private func text(_ key: String) -> String {
        DJConnectLocalization.localized(key: key, language: model.language)
    }
    private var status: SessionConnectionStatus {
        .resolve(demo: model.isDemoMode, pairing: model.pairingStatus, mode: model.haConnectionMode,
                 backendAvailable: model.backendAvailable, recovering: model.djSessionIsRecovering,
                 liveUnavailable: model.djSessionLiveUnavailable)
    }
    var body: some View {
        Button { showingStatus.toggle() } label: {
            Circle().fill(status.color).frame(width: 12, height: 12)
                .overlay { Circle().stroke(.white.opacity(0.35), lineWidth: 1) }
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(text("ui.connection.status"))
        .accessibilityValue(text(status.key))
        .accessibilityIdentifier("session-connection-toggle")
        .help(text(status.key))
        .popover(isPresented: $showingStatus) {
            VStack(alignment: .leading, spacing: 12) {
                Text(text("ui.connection.status")).font(.headline)
                if [.offline, .recovering, .liveUnavailable, .backendUnavailable].contains(status) && !model.isDemoMode {
                    Label(text(status.key), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(status.color)
                }
                if model.isDemoMode {
                    Label(text(status.key), systemImage: "play.circle.fill")
                } else {
                    #if os(iOS)
                    IOSConnectionCard(model: model)
                    #else
                    SetupStatusView(model: model)
                    #endif
                }
            }
            .padding(16).frame(idealWidth: 340, maxWidth: 420)
            .presentationCompactAdaptation(.popover)
        }
    }
}

/// Presentation only: pairing is retained across outages, so it is not a health signal.
enum SessionConnectionStatus: Equatable {
    case demo, ready, pairing, setupPending, stale, offline, recovering, liveUnavailable, backendUnavailable, connected
    static func resolve(demo: Bool, pairing: DJConnectPairingStatus, mode: DJConnectHAConnectionMode,
                        backendAvailable: Bool, recovering: Bool, liveUnavailable: Bool) -> Self {
        if demo { return .demo }
        switch pairing {
        case .unpaired: return .ready
        case .pairing: return .pairing
        case .waitingForHomeAssistantCompletion: return .setupPending
        case .stale: return .stale
        case .paired:
            if mode == .offline { return .offline }
            if !backendAvailable { return .backendUnavailable }
            if recovering { return .recovering }
            if liveUnavailable { return .liveUnavailable }
            return .connected
        }
    }
    var key: String {
        switch self {
        case .demo: "ui.app.store.preview.without.home.assistant"
        case .ready: "ui.ready.to.pair"
        case .pairing: "ui.pairing.with.home.assistant"
        case .setupPending: "ui.finish.setup.in.home.assistant"
        case .stale: "ui.not.connected.to.home.assistant"
        case .offline: "ui.connection.offline"
        case .recovering: "ui.connection.recovering"
        case .liveUnavailable: "ui.session.unavailable"
        case .backendUnavailable: "ui.connection.backend_unavailable"
        case .connected: "ui.paired"
        }
    }
    var color: Color {
        switch self {
        case .demo: .purple
        case .connected: .green
        case .ready: .secondary
        case .offline, .backendUnavailable: .red
        case .pairing, .setupPending, .stale, .recovering, .liveUnavailable: .orange
        }
    }
}
