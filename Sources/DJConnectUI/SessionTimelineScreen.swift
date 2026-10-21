import SwiftUI
import DJConnectCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
func savedSessionNavigationTitle(_ sessionID: String, history: DJConnectSessionHistoryModel, language: String) -> String {
    let session = history.sessions.first(where: { $0.id == sessionID }) ?? history.timelines[sessionID]?.session
    guard let session,
          let date = DJConnectHistoryEntry.date(session.startedAt) ?? DJConnectHistoryEntry.date(session.createdAt) else {
        return DJConnectLocalization.localized(key: "ui.session.history.detail.label", language: language)
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: language)
    formatter.timeZone = .current
    formatter.setLocalizedDateFormatFromTemplate("d MMM")
    return String(format: DJConnectLocalization.localized(key: "ui.session.history.detail.title", language: language), formatter.string(from: date))
}

struct SavedSessionsView: View {
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject private var history: DJConnectSessionHistoryModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var manualRefresh = DJConnectManualRefreshController()
    private var refreshing: Bool { manualRefresh.isRefreshing }
    @State private var initialLoadFinished = false
    @State private var localOpenedSessionID: String?
    @State private var isSearchVisible = false
    @State private var searchText = ""
    @State private var selectedSearchIndex = 0
    @FocusState private var isSearchFocused: Bool
    private let externalOpenedSessionID: Binding<String?>?
    private var openedSessionID: Binding<String?> { externalOpenedSessionID ?? $localOpenedSessionID }
    private let embedsNavigationStack: Bool
    init(model: DJConnectAppModel, embedsNavigationStack: Bool = true, openedSessionID: Binding<String?>? = nil) {
        self.model = model; history = model.sessionHistory; self.embedsNavigationStack = embedsNavigationStack
        externalOpenedSessionID = openedSessionID
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    private var searchQuery: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var filteredSessions: [DJConnectSavedSession] {
        guard !searchQuery.isEmpty else { return history.sessions }
        return history.sessions.filter { session in
            let status = session.lifecycleStatus == "INTERRUPTED" ? text("ui.session.history.interrupted") : ""
            return (SessionArchiveSummary.text(session, language: model.language) + " " + status)
                .localizedStandardContains(searchQuery)
        }
    }
    private func closeSearch() {
        isSearchFocused = false
        searchText = ""
        isSearchVisible = false
        selectedSearchIndex = 0
    }
    private func moveSearch(by offset: Int, proxy: ScrollViewProxy) {
        guard !filteredSessions.isEmpty else { return }
        selectedSearchIndex = (selectedSearchIndex + offset + filteredSessions.count) % filteredSessions.count
        withAnimation { proxy.scrollTo(filteredSessions[selectedSearchIndex].id, anchor: .center) }
    }
    private var rowMaxWidth: CGFloat {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad ? .infinity : 1000
        #else
        1000
        #endif
    }
    @ViewBuilder var body: some View {
        if embedsNavigationStack { NavigationStack { content } }
        else { content }
    }
    private var showsListHeader: Bool {
        if history.hasUnconfirmedDeletion { return true }
        #if os(macOS)
        return !initialLoadFinished || history.listLoading || history.preparing
        #else
        // Keep the iOS native refresh bridge mounted even after loading.
        return true
        #endif
    }
    private var content: some View {
        ScrollViewReader { proxy in
            savedSessionsContainer {
                if showsListHeader {
                VStack(alignment: .leading, spacing: 16) {
                    if history.hasUnconfirmedDeletion {
                        ContentDeletionPendingNotice(model: model)
                    }
                    #if !os(iOS)
                    if !initialLoadFinished || history.listLoading || history.preparing {
                        ProgressView().controlSize(.large).tint(.white)
                            .accessibilityLabel(text("ui.session.history.loading"))
                    }
                    #endif

                }
                .frame(maxWidth: rowMaxWidth, alignment: .leading).frame(maxWidth: .infinity).padding(.horizontal, 20)
                #if os(iOS)
                .background(SessionRefreshIndicatorBridge(
                    isRefreshing: !initialLoadFinished || refreshing || history.listLoading || history.preparing))
                #endif
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                }
                    if let error = history.listErrorKey, !history.sessions.isEmpty {
                        HStack(spacing: 12) {
                            Text(text(error)).font(.callout).foregroundStyle(.secondary)
                            Spacer()
                            Button(text("ui.retry")) { Task { await refresh() } }
                                .disabled(refreshing || history.listLoading)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        .accessibilityIdentifier("saved-sessions-refresh-error")
                    }
                    ForEach(filteredSessions) { session in
                        HStack(spacing: 8) {
                        Button { openedSessionID.wrappedValue = session.id } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title2.weight(.medium)).foregroundStyle(djConnectAccent)
                                    .frame(width: 52, height: 52)
                                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: DJConnectListTileStyle.cornerRadius, style: .continuous))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(SessionArchiveSummary.text(session, language: model.language))
                                        .font(.body.weight(.medium)).foregroundStyle(.white).multilineTextAlignment(.leading)
                                    if session.lifecycleStatus == "INTERRUPTED" {
                                        Text(text("ui.session.history.interrupted"))
                                            .font(.caption2.weight(.medium)).foregroundStyle(.white.opacity(0.78))
                                    }
                                    if history.summaryAvailable, let summary = session.summary {
                                        SessionHistorySummaryView(summary: summary, language: model.language, compact: true)
                                    }
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
                        .id(session.id)
                        .frame(maxWidth: .infinity)
                        if history.deletionAvailable {
                            SavedSessionDeleteButton(history: history, language: model.language, sessionID: session.id)
                        }
                        }
                        .frame(maxWidth: rowMaxWidth, alignment: .leading).frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    if let cursor = history.listNextCursor {
                        ZStack {
                            Color.clear
                            if history.listLoading {
                                ProgressView().tint(.white)
                                    .accessibilityLabel(text("ui.session.history.loading"))
                            }
                        }
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                            .accessibilityIdentifier("saved-sessions-pagination")
                            // A new footer belongs to the next cursor. Lazy List/
                            // LazyVStack mounts it only when approaching the end.
                            .task(id: cursor) {
                                await history.loadNextSessionsPage(expectedCursor: cursor)
                            }
                            .id(cursor)
                    }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("saved-sessions-list")
            .background(DJConnectCanvasBackground())
            .safeAreaInset(edge: .top) {
                if isSearchVisible {
                    AskDJSearchBar(language: model.language,
                        scopeName: text("ui.session.history.title"),
                        promptKey: "ui.session.history.search_loaded",
                        fieldIdentifier: "saved-sessions-search-field",
                        countIdentifier: "saved-sessions-search-count",
                        isLoading: history.listLoading || history.preparing,
                        text: $searchText, isFocused: $isSearchFocused,
                        resultCount: searchQuery.isEmpty ? 0 : filteredSessions.count,
                        selectedIndex: selectedSearchIndex,
                        previousAction: { moveSearch(by: -1, proxy: proxy) },
                        nextAction: { moveSearch(by: 1, proxy: proxy) },
                        closeAction: closeSearch)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                }
            }
            .overlay {
                if let emptyTitle {
                    VStack(spacing: 18) {
                        DJConnectEmptyState(title: emptyTitle, systemImage: "clock.arrow.circlepath")
                            .allowsHitTesting(false)
                        if history.listErrorKey != nil && model.pairingStatus == .paired && !model.isDemoMode {
                            Button(text("ui.retry")) { Task { await refresh() } }
                                .djConnectButtonStyle(DJConnectButtonStyle())
                                .disabled(refreshing)
                        }
                    }
                    .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("saved-sessions-empty-state")
                    .allowsHitTesting(history.listErrorKey != nil)
                }
            }
            .navigationDestination(item: openedSessionID) { sessionID in
                SessionTimelineScreen(model: model, sessionID: sessionID)
                    .navigationTitle(detailTitle(sessionID: sessionID))
            }
            .navigationTitle(text("ui.session.history.title") + (model.isDemoMode ? " (demo)" : ""))
            .scrollBounceBehavior(.always)
            .djContentRefreshable(enabled: !model.isDemoMode && model.pairingStatus == .paired) { await refresh() }
            .toolbar {
                ToolbarItemGroup(placement: djConnectSearchToolbarPlacement) {
                    Button {
                        if isSearchVisible { closeSearch() }
                        else { isSearchVisible = true; isSearchFocused = true }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(isSearchVisible ? djConnectAccent : .white)
                    }
                    .accessibilityLabel(text("ui.session.history.search_sessions"))
                    .accessibilityIdentifier("saved-sessions-search-toggle")
                    .help(text("ui.session.history.search_sessions"))
                    if history.bulkDeletionAvailable {
                        SavedSessionsDeleteAllButton(language: model.language,
                            isEnabled: history.canPrepareBulkDeletion,
                            hasUnconfirmedDeletion: history.hasUnconfirmedDeletion,
                            contextEpoch: history.responseEpoch, archiveEpoch: history.archiveResponseEpoch) {
                            isSearchFocused = false
                            let epoch = history.responseEpoch
                            guard let snapshot = await history.prepareBulkDeletion(expectedEpoch: epoch) else { return nil }
                            return .init(count: snapshot.targetCount, perform: {
                                await history.deleteAllSessions(snapshot, expectedEpoch: epoch)
                            })
                        }
                    }
                }
                ToolbarItem(placement: djConnectRefreshToolbarPlacement) {
                    Button { Task { await refresh() } } label: {
                        Image(systemName: "arrow.clockwise").foregroundStyle(.white)
                    }
                    .tint(.white)
                    .disabled(refreshing || model.isDemoMode || model.pairingStatus != .paired)
                    .accessibilityLabel(text("ui.session.history.refresh"))
                    .accessibilityIdentifier("saved-sessions-refresh")
                    .help(text("ui.session.history.refresh"))
                }
            }
            .onChange(of: history.archiveResponseEpoch) { _, _ in
                openedSessionID.wrappedValue = nil
                closeSearch()
            }
            .djStatusToastOverlay(manualRefresh.notice, screenImage: "clock.arrow.circlepath")
            .task(id: model.isDemoMode || model.canRefreshSessionHistory) {
                initialLoadFinished = false
                await history.restoreVisibleSessions()
                guard !Task.isCancelled else { return }
                initialLoadFinished = true
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await history.restoreVisibleSessions() } }
            }
            .onChange(of: searchText) { _, _ in
                selectedSearchIndex = 0
                if let first = filteredSessions.first { proxy.scrollTo(first.id, anchor: .top) }
            }
            .onChange(of: filteredSessions.map(\.id)) { _, _ in
                selectedSearchIndex = min(selectedSearchIndex, max(0, filteredSessions.count - 1))
            }
            .onChange(of: history.responseEpoch) { _, _ in closeSearch() }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("screen-saved-sessions")
        }
    }
    @ViewBuilder private func savedSessionsContainer<Rows: View>(@ViewBuilder rows: () -> Rows) -> some View {
        #if os(macOS)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) { rows() }
                .padding(.horizontal, 20)
                .padding(.vertical, djConnectScreenVerticalPadding)
        }
        .scrollIndicators(.visible)
        #else
        List { rows() }
        #endif
    }

    private func detailTitle(sessionID: String) -> String {
        savedSessionNavigationTitle(sessionID, history: history, language: model.language)
    }

    private var emptyTitle: String? {
        if initialLoadFinished, !searchQuery.isEmpty, filteredSessions.isEmpty, !history.sessions.isEmpty {
            if let error = history.listErrorKey { return text(error) }
            guard history.listNextCursor == nil, !history.listLoading else { return nil }
            return text("ui.no.search.results")
        }
        guard initialLoadFinished, history.sessions.isEmpty, !history.listLoading, !history.preparing else { return nil }
        if let error = history.listErrorKey { return text(error) }
        return text(history.available ? "ui.session.history.empty" : "ui.session.history.unavailable")
    }
    private func refresh() async {
        await manualRefresh.run(model: model, systemImage: "clock.arrow.circlepath") {
            guard !model.isDemoMode, model.pairingStatus == .paired else { return text("ui.session.history.unavailable") }
            await history.prepare()
            let succeeded = await history.loadSessions()
            return text(succeeded ? "ui.session.history.updated" : "ui.session.history.unavailable")
        }
    }

}

/// The same native timeline surface serves the active Session and readonly archive.
struct SessionTimelineScreen: View {
    @StateObject private var manualRefresh = DJConnectManualRefreshController()
    @State private var deleteConfirmation: SessionDeleteConfirmation?
    @State private var confirmingDelete = false
    @State private var preparingDelete = false
    @State private var deletePreparationFailed = false
    @State private var deletePreparationGeneration = UUID()
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject private var history: DJConnectSessionHistoryModel
    let sessionID: String
    var activeSession: DJConnectSessionRuntime?
    var initialAnchor: String?
    var openQueueAction: () -> Void = {}
    var refreshAction: (() async -> Bool)?
    @StateObject private var renderCache = SessionTimelineRenderCache()
    @State private var sessionControlIntent: SessionControlIntent?
    @State private var showingDJVoice = false
    @State private var feedbackMessage: DJConnectAskDJMessage?
    @State private var menuFrames: [SessionControlIntent.Kind: CGRect] = [:]
    @State private var currentHeaderVisible = true
    @State private var composerKeyboardVisible = false
    private var composerBottomPadding: CGFloat {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            return composerKeyboardVisible ? 6 : 8
        }
        #endif
        return 8
    }
    @State private var floatingComposerHeight: CGFloat = 96
    @State private var oldestEntriesVisible = false
    @State private var artworkVisibleIDs: Set<String> = []
    @State private var pagingTask: Task<Void, Never>?
    @State private var visibleEntry: String?
    @State private var scrollAnchor: UnitPoint = .top
    @State private var submittedQuestion: SessionSubmittedQuestion?
    @State private var priorSearchPosition: String?
    @State private var query = ""
    @State private var showsForecast = false
    @State private var forecastPosition: String?
    @State private var forecastQuery = ""
    @State private var searching = false
    @State private var selectedMatchID: String?
    private var retryRefreshing: Bool { manualRefresh.isRefreshing }
    @State private var pullRefreshing = false
    @State private var resumePosition: String?
    @State private var anchorGeneration = UUID()
    @State private var sceneRestoreTask: Task<Void, Never>?
    @FocusState private var inputFocused: Bool
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init(model: DJConnectAppModel, sessionID: String, activeSession: DJConnectSessionRuntime? = nil,
         initialAnchor: String? = nil, openQueueAction: @escaping () -> Void = {}, refreshAction: (() async -> Bool)? = nil) {
        self.model = model; history = model.sessionHistory; self.sessionID = sessionID
        self.activeSession = activeSession; self.initialAnchor = initialAnchor; self.openQueueAction = openQueueAction
        self.refreshAction = refreshAction
    }
    private func refreshTimeline() async {
        await manualRefresh.run(model: model, systemImage: DJConnectFeatureSymbols.djSession) {
            let sessionSucceeded = await refreshAction?() ?? true
            let conversationSucceeded = history.profileScopeActive ? await history.refreshConversation() : true
            let timelineSucceeded = await history.refreshVisibleTimeline(sessionID, anchor: visibleEntry)
            let succeeded = sessionSucceeded && conversationSucceeded && timelineSucceeded
            return text(succeeded ? "ui.refresh.updated" : "ui.refresh.failed")
        }
    }

    private var usesFloatingComposer: Bool {
        #if os(iOS)
        activeSession != nil
        #else
        false
        #endif
    }
    private var allowsHandoffPresentation: Bool {
        guard activeSession != nil else { return false }
        #if DEBUG
        // Native presentation proof uses the real button; Demo still cannot approve.
        if model.isDemoMode, ProcessInfo.processInfo.arguments.contains("--uitesting"),
           ProcessInfo.processInfo.arguments.contains("--uitest-vibecast-dialog") { return true }
        #endif
        return !model.isDemoMode
    }

    private var usesExpandedToolbar: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }
    private var displayingForecast: Bool { showsForecast && activeSession != nil }
    private var timeline: DJConnectSessionHistoryModel.Timeline { history.timelines[sessionID] ?? .init() }
    private struct SubmittedTurnNavigation: Equatable {
        let target: String?
        let showsForecast: Bool
        let searching: Bool
    }
    private var submittedTurnNavigation: SubmittedTurnNavigation {
        .init(target: submittedQuestionTarget, showsForecast: showsForecast, searching: searching)
    }
    private var submittedQuestionTarget: String? {
        submittedQuestion?.target(sessionID: sessionID, pending: history.pendingTurns,
            entries: timeline.entries, current: model.currentSessionConversationMessages(sessionID: sessionID))
    }
    private var startMetadata: String? {
        let startedAt = activeSession.flatMap { $0.id == sessionID ? $0.startedAt : nil }
            ?? timeline.session.flatMap { $0.id == sessionID ? $0.startedAt : nil }
            ?? history.sessions.first(where: { $0.id == sessionID })?.startedAt
        return startedAt.flatMap { SessionStartMetadata.text(startedAt: $0, language: model.language) }
    }
    @ViewBuilder private var sessionBackground: some View {
        if let activeSession {
            DJSessionPinnedMoodBackground(mood: activeSession.selectedMood).ignoresSafeArea(.container)
        } else { DJConnectCanvasBackground() }
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    private var matches: [DJConnectHistoryEntry] {
        history.acceptedSearchSessionID == sessionID && history.acceptedSearchQuery == query ? history.searchMatches.reversed().filter { $0.isRetained() } : []
    }
    private var selectedIndex: Int { matches.firstIndex(where: { $0.id == selectedMatchID }) ?? 0 }
    private var canSend: Bool {
        (model.isDemoMode ? model.canUseAskDJFeatures : history.profileScopeActive && model.canUseProfileConversation) && !model.isSendingAskDJText &&
        !model.askDJDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasSessionPlayback: Bool {
        activeSession.map { history.hasPlaybackForFirstPlayHelper($0) } ?? false
    }
    private var showsFirstPlayHelper: Bool {
        activeSession?.runtimeState == "active" && !hasSessionPlayback
            && !history.sessionsWithObservedPlayback.contains(sessionID)
            && !model.djSessionIsRecovering && !model.djSessionLiveUnavailable
    }

    private func sendComposerQuestion() {
        guard model.activeDJSession?.id == sessionID, canSend else { return }
        let previous = model.askDJMessages.last(where: { $0.role == .user })?.id
        model.sendAskDJText()
        guard let question = model.askDJMessages.last(where: { $0.role == .user }), question.id != previous else { return }
        submittedQuestion = SessionSubmittedQuestion(sessionID: sessionID, localID: question.id, clientID: question.clientMessageID)
    }

    private func setConversationPrompt(_ prompt: String) {
        guard activeSession != nil, model.activeDJSession?.id == sessionID else { return }
        model.askDJDraft = prompt
        inputFocused = true
    }

    private func reportConversation(_ message: DJConnectAskDJMessage) {
        guard activeSession != nil, model.activeDJSession?.id == sessionID else { return }
        inputFocused = false
        feedbackMessage = message
    }

    var body: some View {
        let retentionDeadlines = renderCache.snapshot(timeline.entries, sessionID: sessionID, epoch: history.responseEpoch).compactMap(\.deadline)
            + timeline.entries.compactMap { $0.sessionMedia?.artwork.expiresAt.flatMap(DJConnectHistoryEntry.date) }
        let matchMap = matches.reduce(into: [String: DJConnectHistoryEntry]()) { result, entry in
            if result[entry.id] == nil { result[entry.id] = entry }
        }
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if activeSession != nil {
                    SessionModeToggleButtons(showsForecast: $showsForecast, language: model.language)
                        .padding(.horizontal, 20)
                        #if os(iOS)
                        .padding(.top, 4).padding(.bottom, 10)
                        #else
                        .padding(.vertical, 10)
                        #endif
                }
                TimelineView(SessionEntryRefreshSchedule(deadlines: retentionDeadlines)) { clock in
                    let preparedEntries = renderCache.snapshot(timeline.entries, sessionID: sessionID, epoch: history.responseEpoch, at: clock.date)
                    ZStack {
                    ScrollView {
                        DJSessionGlassGroup {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            if let activeSession {
                                scrollingCurrent(activeSession).id("current")
                            }
                            if displayingForecast {
                                SessionForecastContent(model: model, query: $forecastQuery)
                            } else {
                                if activeSession != nil {
                                    searchBar(proxy: proxy).id("flow-search")
                                }
                                if activeSession == nil {
                                    VStack(alignment: .leading, spacing: 6) {
                                        if let session = timeline.session ?? history.sessions.first(where: { $0.id == sessionID }) {
                                            Text(SessionArchiveSummary.text(session, language: model.language))
                                                .font(.headline).accessibilityAddTraits(.isHeader)
                                                .accessibilityIdentifier("session-archive-summary")
                                            if session.lifecycleStatus == "INTERRUPTED" {
                                                Text(text("ui.session.history.interrupted"))
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                            if history.summaryAvailable, let summary = session.summary {
                                                SessionHistorySummaryView(summary: summary, language: model.language)
                                            }
                                        }
                                        Label(text("ui.session.history.readonly"), systemImage: "lock")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 20)
                                    .id("current")
                                }
                                if let key = timeline.errorKey, activeSession == nil || history.available {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text(text(key)).fixedSize(horizontal: false, vertical: true)
                                            .foregroundStyle(.white.opacity(0.82))
                                        Button {
                                            Task { await refreshTimeline() }
                                        } label: {
                                            Label(text("ui.refresh.page"), systemImage: "arrow.clockwise")
                                        }
                                        .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, usesLiveGlass: false))
                                        .disabled(retryRefreshing || timeline.loading)
                                        .accessibilityIdentifier("session-timeline-retry")
                                    }
                                    .padding(.horizontal, 20).padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityIdentifier("session-timeline-error")
                                }
                                ForEach(history.pendingTurns.reversed().filter { $0.context.sessionID == sessionID }) { turn in
                                    SessionPendingConversationBubble(model: model, history: history, turn: turn,
                                        setPromptAction: setConversationPrompt, feedbackAction: reportConversation)
                                    .padding(.horizontal, 20)
                                    .id("pending-" + turn.id)
                                }
                                if activeSession != nil {
                                    ForEach(model.currentSessionConversationMessages(sessionID: sessionID, at: clock.date).reversed()) { message in
                                        SessionCurrentConversationBubble(model: model, message: message,
                                            setPromptAction: setConversationPrompt, feedbackAction: reportConversation)
                                            .padding(.horizontal, 20)
                                            .id("current-conversation-" + message.id.uuidString)
                                    }
                                }
                                // Match Ask DJ: newest retained contribution first; current remains the top anchor.
                                ForEach(preparedEntries.reversed().filter { $0.isRetained(at: clock.date) }) { prepared in
                                    let entry = prepared.entry
                                    let liveMessage = history.liveMessage(for: entry, activeSessionID: activeSession?.id)
                                    let actionEpoch = history.responseEpoch
                                    SessionEntryView(entry: entry, language: model.language,
                                        messageAdapter: liveMessage ?? prepared.message, contextEpoch: actionEpoch,
                                        opensActiveComposer: activeSession != nil,
                                        allowsPlaybackActions: liveMessage != nil,
                                        playingActionID: model.playingAskDJActionID,
                                        artworkModel: model,
                                        setPromptAction: { prompt in
                                            guard history.responseEpoch == actionEpoch, entry.isRetained() else { return }
                                            setConversationPrompt(prompt)
                                        },
                                        feedbackAction: { message in
                                            guard history.responseEpoch == actionEpoch, entry.isRetained() else { return }
                                            reportConversation(message)
                                        },
                                        playAction: { action in history.playLiveAction(action, for: entry, expectedEpoch: actionEpoch) },
                                        highlights: matchMap[entry.id]?.text == entry.text ? (matchMap[entry.id]?.highlights ?? []) : [],
                                        isSelectedMatch: selectedMatchID == entry.id || initialAnchor == entry.id,
                                        selected: history.selectedEntry == entry.reference) {
                                            history.selectedEntry = entry.reference
                                            if activeSession == nil {
                                                history.openTarget = nil
                                                model.performHomeScreenAction(.askDJ)
                                            } else { inputFocused = true }
                                        }
                                        .equatable()
                                            .modifier(SessionRowFade(selected: selectedMatchID == entry.id || initialAnchor == entry.id || history.selectedEntry == entry.reference))
                                        .padding(.horizontal, 20)
                                        .id(entry.id).accessibilityElement(children: .contain).accessibilityIdentifier("session-entry-" + entry.id)
                                        .onAppear {
                                            if matchMap[entry.id] != nil {
                                                Task { await loadMoreSearchIfNeeded(visibleMatchID: entry.id) }
                                            }
                                        }
                                }
                                if history.available && timeline.revision != nil && timeline.entries.isEmpty && timeline.errorKey == nil {
                                    Text(text(activeSession == nil ? "ui.session.history.no_entries" : "ui.session.history.no_entries_active")).padding(.horizontal, 20)
                                }
                                if let startMetadata {
                                    Label(startMetadata, systemImage: "clock")
                                        .font(.callout).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                        .djSessionFrostedSurface()
                                        .padding(.horizontal, 20)
                                        .accessibilityIdentifier("session-start-metadata")
                                }
                                Color.clear.frame(height: 1).id("tail")
                            }
                        }
                        .frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity)
                        .padding(.top, activeSession != nil ? 0 : archivedTopPadding).padding(.bottom, 20)
                        .scrollTargetLayout()
                        // Background updates never reveal pull-to-refresh or move the scroll offset.
                        }
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            if history.hasUnconfirmedDeletion {
                                ContentDeletionPendingNotice(model: model)
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                            }
                            if searching && activeSession == nil {
                                TimelineView(SessionEntryRefreshSchedule(deadlines: history.searchMatches.compactMap { DJConnectHistoryEntry.date($0.retainedUntil) })) { _ in searchBar(proxy: proxy) }
                            }
                        }
                    }
                    .onScrollTargetVisibilityChange(idType: String.self, threshold: 0.01) { visibleIDs in
                        artworkVisibleIDs = Set(visibleIDs)
                        history.prefetchArtwork(sessionID: sessionID, visibleIDs: artworkVisibleIDs)
                        currentHeaderVisible = visibleIDs.contains("current")
                        oldestEntriesVisible = visibleIDs.contains("tail") || timeline.entries.first.map { visibleIDs.contains($0.id) } == true
                        if oldestEntriesVisible { loadEarlierIfNeeded() }
                    }
                    .onChange(of: history.artworkAvailable) { _, _ in
                        history.prefetchArtwork(sessionID: sessionID, visibleIDs: artworkVisibleIDs)
                    }
                    .onChange(of: clock.date) { _, _ in
                        history.prefetchArtwork(sessionID: sessionID, visibleIDs: artworkVisibleIDs)
                    }
                    .onScrollPhaseChange { _, phase in
                        if phase == .tracking || phase == .interacting { submittedQuestion = nil }
                        if phase.isScrolling {
                            history.prefetchArtwork(sessionID: sessionID, visibleIDs: artworkVisibleIDs)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if !currentHeaderVisible {
                            Button {
                                jump("current", proxy: proxy)
                            } label: { Image(systemName: "arrow.up") }
                            .djConnectButtonStyle(DJConnectButtonStyle(shape: .icon))
                            .accessibilityLabel(text(activeSession == nil ? "ui.session.history.back_top" : "ui.session.back_current"))
                            .help(text(activeSession == nil ? "ui.session.history.back_top" : "ui.session.back_current"))
                            .accessibilityIdentifier("session-jump-top")
                            .padding(16)
                            .padding(.bottom, !searching && usesFloatingComposer ? floatingComposerHeight + 8 : 8)
                        }
                    }
                    .defaultScrollAnchor(.top, for: .initialOffset)
                    .scrollPosition(id: displayingForecast ? $forecastPosition : $visibleEntry,
                                    anchor: displayingForecast ? .top : scrollAnchor)
                    .task(id: submittedTurnNavigation) {
                        guard let target = submittedQuestionTarget else { return }
                        await Task.yield()
                        guard !Task.isCancelled, submittedQuestionTarget == target, !searching, !showsForecast else { return }
                        sceneRestoreTask?.cancel(); anchorGeneration = UUID()
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                            scrollAnchor = .bottom
                            visibleEntry = target
                        }
                    }
                    .djContentRefreshable(enabled: !showsForecast && !model.isDemoMode && model.pairingStatus == .paired) {
                        pullRefreshing = true
                        defer { pullRefreshing = false }
                        await refreshTimeline()
                    }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if usesFloatingComposer && (!searching || showsForecast) {
                            Color.clear.frame(height: floatingComposerHeight + composerBottomPadding + 8)
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if usesFloatingComposer && (!searching || showsForecast) {
                            sessionComposer(floating: true)
                                .djFloatingAskDJWidth(maximum: 1000)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { floatingComposerHeight = $0 }
                                .padding(.horizontal, 12)
                                .padding(.bottom, composerBottomPadding)
                        }
                    }
                }
                if activeSession != nil && !usesFloatingComposer && (!searching || showsForecast) {
                    sessionComposer(floating: false)
                }
            }
            .background(sessionBackground)
            .onChange(of: activeSession == nil) { _, ended in
                if ended { showsForecast = false }
            }
            .onChange(of: showsForecast) { _, value in
                if value { inputFocused = false; searchFocused = false }
            }
            .overlay {
                if activeSession != nil {
                    PersonaReactionOverlay(controller: model.personaReactions, language: model.language, avatarFrame: model.personaAvatarFrame)
                }
            }
            .djStatusToastOverlay(model.personaReactionNotice, screenImage: DJConnectFeatureSymbols.djSession)
            .onDisappear { model.personaReactions.cancel(.dismissed) }
            .djStatusToastOverlay(manualRefresh.notice, screenImage: DJConnectFeatureSymbols.djSession)
            .sheet(item: $feedbackMessage) { message in
                AskDJFeedbackPromptView(model: model, message: message)
                #if os(iOS)
                    .presentationDetents([.large])
                    .presentationSizing(.page)
                #endif
            }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            composerKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            composerKeyboardVisible = false
        }
        #endif
            .background {
                if activeSession != nil {
                    // Retain Command-F without an additional visible search control.
                    Button {
                        showsForecast = false
                        inputFocused = false
                        proxy.scrollTo("flow-search", anchor: .top)
                        searchFocused = true
                    } label: { EmptyView() }
                    .keyboardShortcut("f", modifiers: .command)
                    .disabled(!history.searchAvailable)
                    .hidden()
                    .accessibilityHidden(true)
                }
            }
            .toolbar {
                #if os(macOS)
                ToolbarItemGroup(placement: .navigation) {
                    if activeSession == nil { sessionSearchToolbarButton(proxy: proxy) }
                    sessionToolbarActions(proxy: proxy)
                    if allowsHandoffPresentation {
                        Button { model.isShowingVibeCastSessionStart = true } label: {
                            Image(systemName: "tv.badge.wifi")
                                .foregroundStyle(model.vibeCastHandoffApproved ? djConnectAccent : .white)
                        }
                        .accessibilityLabel(text("ui.vibecast.handoff.title"))
                        .accessibilityIdentifier("session-handoff-toggle")
                        .help(text("ui.vibecast.handoff.title"))
                    }
                }
                if activeSession != nil {
                    if #available(macOS 26.0, *) { ToolbarSpacer(.fixed, placement: .navigation) }
                    ToolbarItem(placement: .navigation) {
                        SessionEndToolbarButton(model: model)
                    }
                }
                #endif
                #if os(iOS)
                if activeSession == nil {
                    ToolbarItem(placement: .topBarLeading) {
                        sessionSearchToolbarButton(proxy: proxy)
                    }
                } else if usesExpandedToolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        sessionToolbarActions(proxy: proxy)
                    }
                } else {
                    // One bounded native item prevents automatic toolbar overflow
                    // from hiding the separate connection/refresh group.
                    ToolbarItem(placement: .topBarLeading) {
                        HStack(spacing: 0) {
                            sessionToolbarActions(proxy: proxy)
                                .frame(width: 44, height: 44)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .labelStyle(.iconOnly)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if activeSession == nil, history.deletionAvailable { archiveDeleteButton }
                    if activeSession != nil { SessionConnectionToolbarButton(model: model) }
                    if activeSession == nil || refreshAction != nil {
                        RefreshButton(model: model, action: { Task { await refreshTimeline() } }, isLoading: timeline.loading || retryRefreshing)
                    }
                }
                #endif
                #if os(macOS)
                if activeSession == nil, history.deletionAvailable {
                    ToolbarItem(placement: .confirmationAction) { archiveDeleteButton }
                }
                if activeSession != nil {
                    ToolbarItemGroup(placement: .confirmationAction) {
                        SessionConnectionToolbarButton(model: model)
                        if refreshAction != nil { RefreshButton(model: model, action: { Task { await refreshTimeline() } }, isLoading: timeline.loading || retryRefreshing) }
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        RefreshButton(model: model, action: { Task { await refreshTimeline() } }, isLoading: timeline.loading || retryRefreshing)
                    }
                }
                #endif
            }
            .modifier(SessionArchiveDeletionConfirmation(history: history, language: model.language,
                confirmation: $deleteConfirmation, isPresented: $confirmingDelete))
            #if os(iOS)
            .overlay(alignment: .topTrailing) {
                SessionControlPopoverHost(model: model, intent: $sessionControlIntent, showsHandoff: allowsHandoffPresentation)

            }
            #endif
            .onAppear {
                guard activeSession != nil, initialAnchor == nil else { return }
                positionCurrentWithoutAnimation()
            }
            .task(id: sessionID) {
                if activeSession != nil, initialAnchor == nil { positionCurrentWithoutAnimation() }
                let restoreGeneration = anchorGeneration
                await history.prepare(); await history.loadTimeline(sessionID, window: .tail)
                guard !Task.isCancelled, restoreGeneration == anchorGeneration else { return }
                if let initialAnchor { await selectAnchor(initialAnchor, proxy: proxy, restoreRequest: true) }
                else if activeSession != nil { return } // Content refresh never repositions the active screen.
                else if let anchor = history.readingAnchor(sessionID: sessionID) {
                    if ["current", "tail"].contains(anchor) { jump(anchor, proxy: proxy) }
                    else { await selectAnchor(anchor, proxy: proxy, restoreRequest: true) }
                }
            }
            .task(id: activeSession?.id) {
                guard activeSession != nil else { return }
                while !Task.isCancelled {
                    if scenePhase == .active, model.canRefreshSessionHistory {
                        await history.refreshConversation()
                        guard !Task.isCancelled, scenePhase == .active else { continue }
                        await history.refreshVisibleTimeline(sessionID, anchor: visibleEntry)
                    }
                    try? await Task.sleep(for: .seconds(10))
                }
            }
            .onChange(of: activeSession?.id) { model.isShowingVibeCastSessionStart = false }
            .onChange(of: history.profileScopeActive) { model.isShowingVibeCastSessionStart = false }
            .onChange(of: history.responseEpoch) {
                feedbackMessage = nil
                model.isShowingVibeCastSessionStart = false
                submittedQuestion = nil
            }
            .onChange(of: query) { _, value in
                sceneRestoreTask?.cancel(); anchorGeneration = UUID()
                if activeSession != nil {
                    if !searching && !value.isEmpty { priorSearchPosition = visibleEntry }
                    searching = !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    if !searching { selectedMatchID = nil }
                }
                history.search(sessionID: sessionID, query: value)
            }
            .onChange(of: history.searchMatches) {
                guard searching, !matches.isEmpty else { return }
                if !matches.contains(where: { $0.id == selectedMatchID }) {
                    // Keep the inline field visible while typing. Navigation to
                    // a Flow result is explicit through Return or the arrows.
                    if activeSession != nil { selectedMatchID = nil; return }
                    selectedMatchID = matches.first?.id
                    if let id = selectedMatchID { Task { await selectAnchor(id, proxy: proxy, searchRequest: true) } }
                }
            }
            .onChange(of: timeline.nextCursor) { if oldestEntriesVisible { loadEarlierIfNeeded() } }
            .onChange(of: timeline.windowed) { if oldestEntriesVisible { loadEarlierIfNeeded() } }
            .onChange(of: timeline.revision) {
                if searching && !query.isEmpty { history.search(sessionID: sessionID, query: query) }
            }
            .onChange(of: scenePhase) {
                if scenePhase != .active {
                    sceneRestoreTask?.cancel(); sceneRestoreTask = nil
                    anchorGeneration = UUID()
                    if activeSession != nil {
                        pagingTask?.cancel(); pagingTask = nil
                        searching = false; searchFocused = false; query = ""; selectedMatchID = nil
                        history.clearSearch()
                        resumePosition = "current"
                        positionCurrentWithoutAnimation()
                    } else if scenePhase == .inactive { resumePosition = visibleEntry }
                } else {
                    sceneRestoreTask?.cancel()
                    let active = activeSession != nil
                    // Position before networking. There is deliberately no active
                    // Session jump/open after the background read completes.
                    if active { positionCurrentWithoutAnimation() }
                    let restoreGeneration = anchorGeneration
                    sceneRestoreTask = Task {
                        await history.restoreVisibleTimeline(sessionID, active: active, anchor: active ? nil : resumePosition)
                        guard !Task.isCancelled, restoreGeneration == anchorGeneration, !active else { return }
                        guard let resumePosition else {
                            if let initialAnchor { await selectAnchor(initialAnchor, proxy: proxy, restoreRequest: true) }
                            return
                        }
                        if !["current", "tail"].contains(resumePosition), !resumePosition.hasPrefix("pending-") {
                            await selectAnchor(resumePosition, proxy: proxy, restoreRequest: true)
                        }
                    }
                }
            }
            .onDisappear(perform: timelineDidDisappear)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(activeSession == nil ? "screen-history-timeline" : "screen-session-conversation")
        }
    }

    private func timelineDidDisappear() {
        deletePreparationGeneration = UUID()
        preparingDelete = false
        clearReadingState()
        history.cancelArtworkQueue()
    }

    private var archiveDeleteButton: some View {
        Button(role: .destructive) {
            guard history.canDeleteSession(sessionID), !preparingDelete else { return }
            inputFocused = false; searchFocused = false
            let epoch = history.responseEpoch, generation = UUID()
            deletePreparationGeneration = generation
            preparingDelete = true
            Task { @MainActor in
                let revision = await history.prepareSessionDeletion(sessionID, expectedEpoch: epoch)
                guard generation == deletePreparationGeneration else { return }
                preparingDelete = false
                guard epoch == history.responseEpoch, !Task.isCancelled else { return }
                guard let revision else { deletePreparationFailed = true; return }
                deleteConfirmation = .init(sessionID: sessionID, revision: revision, epoch: epoch)
                confirmingDelete = true
            }
        } label: {
            Image(systemName: "trash").foregroundStyle(.red)
        }
        .disabled(preparingDelete || !history.canDeleteSession(sessionID) || history.deletingSessionID != nil)
        .alert(text("ui.session.history.delete.failed"), isPresented: $deletePreparationFailed) {
            Button(text("ui.close"), role: .cancel) {}
        }
        .accessibilityLabel(text("ui.session.history.delete.title"))
        .accessibilityIdentifier("session-delete-button")
        .help(text("ui.session.history.delete.title"))
    }

    @ViewBuilder private func sessionToolbarActions(proxy: ScrollViewProxy) -> some View {
        Group {
            #if os(iOS)
            if !usesExpandedToolbar {
                Button {
                    sessionControlIntent = SessionControlIntent(kind: .more, sessionID: sessionID, epoch: history.responseEpoch, sourceRect: menuFrames[.more] ?? .zero)
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(.white)
                }
                .accessibilityLabel(text("ui.more"))
                .accessibilityIdentifier("session-more-menu")
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { menuFrames[.more] = $0 }
            }
            #endif
            if let activeSession {
                #if os(iOS)
                ActiveSessionMoodToolbar(model: model, session: activeSession, requestPresentation: {
                    sessionControlIntent = SessionControlIntent(kind: .mood, sessionID: activeSession.id, epoch: history.responseEpoch, sourceRect: menuFrames[.mood] ?? .zero)
                })
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { menuFrames[.mood] = $0 }
                ActiveSessionPresenceToolbar(model: model, session: activeSession, requestPresentation: {
                    sessionControlIntent = SessionControlIntent(kind: .presence, sessionID: activeSession.id, epoch: history.responseEpoch, sourceRect: menuFrames[.presence] ?? .zero)
                })
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { menuFrames[.presence] = $0 }
                #else
                ActiveSessionMoodToolbar(model: model, session: activeSession)
                ActiveSessionPresenceToolbar(model: model, session: activeSession)
                #endif
                #if os(iOS)
                ActiveSessionPersonaToolbar(model: model, session: activeSession, requestPresentation: {
                    sessionControlIntent = SessionControlIntent(kind: .persona, sessionID: activeSession.id, epoch: history.responseEpoch, sourceRect: menuFrames[.persona] ?? .zero)
                })
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { menuFrames[.persona] = $0 }
                #else
                ActiveSessionPersonaToolbar(model: model, session: activeSession)
                #endif
            }
            #if !os(macOS)
            if !usesExpandedToolbar, activeSession != nil {
                SessionEndToolbarButton(model: model)
            }
            #endif
            #if os(macOS)
            if activeSession != nil {
                Button { showingDJVoice.toggle() } label: {
                    Label(text("ui.dj_settings.title"), systemImage: "speaker.wave.2")
                }
                .accessibilityIdentifier("session-voice-toggle")
                .help(text("ui.dj_settings.title"))
                .popover(isPresented: $showingDJVoice) {
                    ProfileDJSettingsEditor(model: model).equatable().frame(idealWidth: 360)
                }
                .onChange(of: activeSession?.id) { showingDJVoice = false }
                .onChange(of: history.responseEpoch) { showingDJVoice = false }
                .onChange(of: scenePhase) { if scenePhase != .active { showingDJVoice = false } }
            }
            #else
            if usesExpandedToolbar {
                if let activeSession {
                    Button {
                        sessionControlIntent = SessionControlIntent(kind: .voice, sessionID: activeSession.id,
                            epoch: history.responseEpoch, sourceRect: menuFrames[.voice] ?? .zero)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                            .foregroundStyle(.white).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(text("ui.dj_settings.title"))
                    .accessibilityIdentifier("session-voice-toggle")
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { menuFrames[.voice] = $0 }
                }
                if allowsHandoffPresentation {
                    Button { model.isShowingVibeCastSessionStart = true } label: {
                        Image(systemName: "tv.badge.wifi")
                            .foregroundStyle(model.vibeCastHandoffApproved ? djConnectAccent : .white)
                    }
                    .accessibilityLabel(text("ui.vibecast.handoff.title"))
                    .accessibilityIdentifier("session-handoff-toggle")
                }
                if activeSession != nil { SessionEndToolbarButton(model: model) }
            }
            #endif
        }
    }

    private func toggleFlowSearch(proxy: ScrollViewProxy) {
        let returningFromForecast = showsForecast
        showsForecast = false
        if searching && !returningFromForecast { closeSearch(proxy: proxy); return }
        if !searching { priorSearchPosition = visibleEntry }
        inputFocused = false
        searching = true
        searchFocused = true
    }

    private func sessionSearchToolbarButton(proxy: ScrollViewProxy) -> some View {
        Button {
            toggleFlowSearch(proxy: proxy)
        } label: {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(searching ? djConnectAccent : .primary)
        }
            .disabled(!history.searchAvailable)
            .accessibilityLabel(text("ui.session.history.search"))
            .accessibilityIdentifier("session-search-toggle")
            .keyboardShortcut("f", modifiers: .command)
    }

    private func clearReadingState() {
        submittedQuestion = nil
        history.rememberReadingAnchor(visibleEntry, sessionID: sessionID)
        pagingTask?.cancel(); pagingTask = nil
        renderCache.clear()
        sceneRestoreTask?.cancel(); anchorGeneration = UUID(); history.clearSearch()
    }

    private func currentHeader(_ session: DJConnectSessionRuntime) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            NativeSessionMomentsView(session: session, language: model.language,
            isRecovering: model.djSessionIsRecovering,
            isLiveUnavailable: model.djSessionLiveUnavailable,
            retryConnection: { Task { await model.retryDJSessionConnection() } },
            artworkBaseURL: URL(string: model.haLocalURL.isEmpty ? model.homeAssistantURL : model.haLocalURL),
            playbackOutputName: model.sessionPlaybackOutputName, playbackModel: model)
            if showsFirstPlayHelper {
                Button {
                    guard model.activeDJSession?.id == sessionID,
                          !model.isSendingAskDJText, !model.isRecordingVoice,
                          model.askDJDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    model.askDJDraft = text("ui.surprise.me.with.new.music")
                    sendComposerQuestion()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "quote.opening")
                            .font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.54)).frame(width: 18)
                        Text(text("ui.surprise.me.with.new.music"))
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.86))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        Image(systemName: "plus").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.50))
                    }
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .frame(maxWidth: 480, alignment: .leading)
                    .background(DJConnectCardAppearance.shape.fill(.white.opacity(0.09)))
                    .overlay(DJConnectCardAppearance.shape.stroke(.white.opacity(DJConnectCardAppearance.borderOpacity), lineWidth: DJConnectCardAppearance.borderWidth))
                }
                .djConnectPlainButtonStyle()
                .disabled(model.isSendingAskDJText || model.isRecordingVoice ||
                    !(model.isDemoMode ? model.canUseAskDJFeatures : history.profileScopeActive && model.canUseProfileConversation) ||
                    !model.askDJDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("session-first-play-suggestion")
                .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: hasSessionPlayback, initial: true) { _, observed in
            if observed { history.rememberObservedPlayback(sessionID: sessionID) }
        }
        #if os(macOS)
        .padding(.horizontal, 20)
        .padding(.top, djConnectScreenVerticalPadding)
        .padding(.bottom, 20)
        #else
        .padding(20)
        #endif
        .fixedSize(horizontal: false, vertical: true)
    }

    private var archivedTopPadding: CGFloat {
        #if os(macOS)
        djConnectScreenVerticalPadding
        #else
        20
        #endif
    }

    private func scrollingCurrent(_ session: DJConnectSessionRuntime) -> some View {
        currentHeader(session)
            #if !os(macOS)
            .padding(.top, 12)
            #endif
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("session-pinned-current")
    }

    private func loadEarlierIfNeeded() {
        guard pagingTask == nil, oldestEntriesVisible, !timeline.loading, timeline.errorKey == nil,
              timeline.nextCursor != nil || timeline.windowed else { return }
        let more = timeline.nextCursor != nil
        pagingTask = Task {
            await history.loadTimeline(sessionID, more: more, preserveLoadedEntries: true)
            pagingTask = nil
        }
    }

    private func positionCurrentWithoutAnimation() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            submittedQuestion = nil
            scrollAnchor = .top
            visibleEntry = "current"
            currentHeaderVisible = true
            oldestEntriesVisible = false
            artworkVisibleIDs = []
        }
    }

    private func jump(_ id: String, proxy: ScrollViewProxy) {
        submittedQuestion = nil
        sceneRestoreTask?.cancel()
        anchorGeneration = UUID()
        // One scroll controller: mixing proxy animation with the bound target can
        // let a layout/keyboard measurement overwrite the requested anchor.
        let target = id == "tail" ? (timeline.entries.last?.id ?? "current") : id
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            scrollAnchor = .top
            visibleEntry = target
        }
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
            } else { jump("current", proxy: proxy) }
        }
    }
    private func loadMoreSearchIfNeeded(visibleMatchID: String? = nil) async {
        guard searching, history.acceptedSearchSessionID == sessionID,
              history.acceptedSearchQuery == query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              history.searchErrorKey == nil, let cursor = history.searchNextCursor else { return }
        let visibleIndex = visibleMatchID.flatMap { id in matches.firstIndex { $0.id == id } } ?? 0
        // Fill a modest search buffer automatically; after that, prefetch only
        // when scrolling to or navigating near the end of the known matches.
        guard matches.count < 100 || max(selectedIndex, visibleIndex) >= matches.count - 3 else { return }
        await history.moreSearch(expectedCursor: cursor)
    }

    private func moveMatch(_ delta: Int, proxy: ScrollViewProxy) {
        guard !matches.isEmpty else { return }
        let index = selectedMatchID == nil
            ? (delta < 0 ? matches.count - 1 : 0)
            : (selectedIndex + delta + matches.count) % matches.count
        selectedMatchID = matches[index].id
        let id = matches[index].id
        Task { await selectAnchor(id, proxy: proxy, searchRequest: true) }
    }
    private func sessionComposer(floating: Bool) -> some View {
        AskDJInputBar(model: model, canSend: canSend,
                      canUseVoiceInput: (model.isDemoMode || model.canUseProfileConversation) && model.canUseVoiceInputRoute,
                      isInputFocused: $inputFocused, sendAction: sendComposerQuestion,
                      floating: floating, placeholderKey: "ui.session.chat.placeholder",
                      surfaceColors: activeSession.map { DJConnectSessionMoodPalette(mood: $0.selectedMood).colors })
        .sessionIntroductionTarget("chat")
    }

    @ViewBuilder private func searchBar(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if activeSession != nil {
                TextField(text("ui.session.history.search"), text: $query)
                    .textFieldStyle(.plain).padding(12).djSessionFrostedSurface()
                    .focused($searchFocused)
                    .accessibilityLabel(text("ui.session.history.search"))
                    .accessibilityIdentifier("session-search-field")
                    .disabled(!history.searchAvailable)
                    .onSubmit { moveMatch(1, proxy: proxy) }
                if searching {
                    HStack {
                        if history.searchLoading { ProgressView().controlSize(.small) }
                        Text("\(history.acceptedSearchSessionID == sessionID && history.acceptedSearchQuery == query ? matches.count : 0)").monospacedDigit()
                            .accessibilityIdentifier("session-search-count")
                        Spacer()
                        Button { moveMatch(-1, proxy: proxy) } label: { Image(systemName: "chevron.up") }
                            .accessibilityLabel(text("ui.previous.result"))
                            .disabled(matches.isEmpty)
                        Button { moveMatch(1, proxy: proxy) } label: { Image(systemName: "chevron.down") }
                            .accessibilityLabel(text("ui.next.result"))
                            .disabled(matches.isEmpty)
                        Button { closeSearch(proxy: proxy) } label: { Image(systemName: "xmark") }
                            .accessibilityLabel(text("ui.close"))
                    }
                    .font(.caption)
                }
            } else {
            AskDJSearchBar(language: model.language, promptKey: "ui.session.history.search",
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
            }
            if let key = history.searchErrorKey {
                Text(text(key))
                Button(text("ui.retry")) { history.search(sessionID: sessionID, query: query) }
            } else if !query.isEmpty && !history.searchLoading && history.acceptedSearchQuery == query {
                HStack {
                    Text(matches.isEmpty && history.searchComplete ? text("ui.session.history.no_match") :
                         text(history.searchComplete ? "ui.session.history.complete" : "ui.session.history.partial"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .task(id: history.searchNextCursor) { await loadMoreSearchIfNeeded() }
        .task(id: selectedMatchID) { await loadMoreSearchIfNeeded() }
        .onChange(of: matches.map(\.id)) {
            if let selectedMatchID, !matches.contains(where: { $0.id == selectedMatchID }) {
                anchorGeneration = UUID(); self.selectedMatchID = nil
            }
        }
        .font(.callout).padding(.horizontal, 20).padding(.vertical, 10)
        .onKeyPress(.escape) { closeSearch(proxy: proxy); return .handled }
        .onKeyPress(.upArrow) { moveMatch(-1, proxy: proxy); return .handled }
        .onKeyPress(.downArrow) { moveMatch(1, proxy: proxy); return .handled }
    }
}

struct SessionModeToggleButtons: View {
    @Binding var showsForecast: Bool
    let language: String

    var body: some View {
        HStack(spacing: 4) {
            modeButton(forecast: false, key: "ui.session.forecast.flow")
            modeButton(forecast: true, key: "ui.session.forecast.tab")
        }
        .padding(DJConnectCardAppearance.segmentedContentInset)
        .djSessionFrostedSurface()
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("session-flow-forecast-picker")
    }

    private func modeButton(forecast: Bool, key: String) -> some View {
        let selected = showsForecast == forecast
        return Button {
            DJConnectHaptics.selection()
            showsForecast = forecast
        } label: {
            Text(DJConnectLocalization.localized(key: key, language: language))
                .font(.headline)
                .foregroundStyle(.white.opacity(selected ? 1 : 0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.74)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .djConnectButtonStyle(DJConnectButtonStyle(
            emphasis: selected ? .selected : .secondary,
            shape: .segmented, expands: true, usesLiveGlass: true,
            foregroundColor: .white.opacity(selected ? 1 : 0.78),
            selectionTint: djConnectAccent
        ))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(forecast ? "session-forecast-toggle" : "session-flow-toggle")
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
            result[lower..<upper].backgroundColor = DJConnectCardAppearance.searchMatchBackground
            result[lower..<upper].foregroundColor = DJConnectCardAppearance.searchMatchForeground
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


struct SessionEntryView: View, Equatable {
    @Environment(\.openURL) private var openURL
    let entry: DJConnectHistoryEntry
    let language: String
    var messageAdapter: DJConnectAskDJMessage? = nil
    var contextEpoch: UUID? = nil
    var opensActiveComposer = false
    var allowsPlaybackActions = false
    var playingActionID: String? = nil
    var artworkModel: DJConnectAppModel? = nil
    var setPromptAction: (String) -> Void = { _ in }
    var feedbackAction: (DJConnectAskDJMessage) -> Void = { _ in }
    var playAction: (DJConnectAskDJPlaybackAction) -> Void = { _ in }
    var highlights: [DJConnectHistoryHighlight] = []
    var isSelectedMatch = false
    var selected = false
    var askAction: () -> Void = {}
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.entry == rhs.entry && lhs.language == rhs.language && lhs.messageAdapter == rhs.messageAdapter &&
        lhs.contextEpoch == rhs.contextEpoch && lhs.opensActiveComposer == rhs.opensActiveComposer &&
        lhs.allowsPlaybackActions == rhs.allowsPlaybackActions && lhs.playingActionID == rhs.playingActionID &&
        lhs.artworkModel === rhs.artworkModel && lhs.highlights == rhs.highlights && lhs.isSelectedMatch == rhs.isSelectedMatch && lhs.selected == rhs.selected
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entry.requiresSpotifyAttribution == true && spotifyAttributionLogo == nil {
                Text(text("ui.session.history.unavailable"))
            } else {
                if entry.isPublicationReceipt {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(text(entry.kind == .djSilence ? "ui.session.history.silence" : "ui.session.history.contribution_unavailable"),
                              systemImage: entry.kind == .djSilence ? "speaker.slash" : "text.bubble")
                            .font(.callout).foregroundStyle(.secondary)
                        SessionTimestampText(value: entry.occurredAt, language: language)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .djSessionFrostedSurface(cornerRadius: DJConnectCardAppearance.conversationCornerRadius)
                } else if entry.kind == .conversationUser || entry.kind == .conversationDJ {
                    AskDJMessageBubble(message: messageAdapter ?? DJConnectAskDJMessage(
                        serverID: entry.originMessageID, clientMessageID: entry.clientMessageID,
                        role: entry.kind == .conversationUser ? .user : .dj,
                        text: entry.text ?? "", createdAt: DJConnectHistoryEntry.date(entry.occurredAt) ?? .distantPast),
                        language: language, isStaleHistory: false, isAudioLoading: false, isAudioPlaying: false,
                        isRetryDisabled: true, playingActionID: playingActionID, currentMood: nil,
                        isSearchResult: !highlights.isEmpty, isActiveSearchResult: isSelectedMatch, searchText: "",
                        retryAction: {}, playAction: playAction, audioAction: {}, trackInsightAction: {},
                        openLink: { link in
                            let url = link.url
                            guard ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                                  url.user == nil, url.password == nil else { return }
                            openURL(url)
                        }, feedbackAction: feedbackAction, setPromptAction: setPromptAction, isReadOnly: true,
                        allowsConversationMenu: opensActiveComposer, allowsSessionPlaybackActions: allowsPlaybackActions,
                        serverHighlights: highlights, contextQuestionAction: askAction,
                        contextQuestionSelected: selected, contextQuestionID: "ask-entry-" + entry.id,
                        sharedSpeechActions: artworkModel.map { model in
                            { AnyView(SharedDJSpeechActions(model: model, speech: entry.sessionSpeech, acceptedText: entry.text ?? "", retainedEntry: entry)) }
                        })
                    if entry.inputType == "voice" { Label(text("ui.session.history.voice"), systemImage: "mic.fill").font(.caption) }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        if horizontalPlayback {
                            HStack(alignment: .top, spacing: 16) {
                                entryArtwork
                                playbackDescription
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.trailing, 40)
                        } else {
                            entryArtwork
                            entryHeading
                            SessionHighlightedText(text: entry.text ?? "", highlights: highlights).font(.title3)
                        }
                        SessionTimestampText(value: entry.occurredAt, language: language).font(.caption).foregroundStyle(.secondary)
                        ForEach(sourceURLs, id: \.absoluteString) { url in
                            Link(sourceLabel(for: url), destination: url)
                                .foregroundStyle(.white)
                                .tint(.white)
                                .accessibilityValue(url.absoluteString)
                        }
                        if entry.requiresSpotifyAttribution == true, let logo = spotifyAttributionLogo,
                           let url = spotifyFooterURL {
                            Link(destination: url) { logo.resizable().scaledToFit().frame(width: 70, height: 20).padding(10).frame(minHeight: 44).contentShape(Rectangle()) }
                                .accessibilityLabel("Spotify")
                        }
                        if let model = artworkModel {
                            SharedDJSpeechActions(model: model, speech: entry.sessionSpeech, acceptedText: entry.text ?? "", retainedEntry: entry)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .topTrailing) { askButton.padding(8) }
                    .overlay {
                        if isSelectedMatch {
                            RoundedRectangle(cornerRadius: DJConnectCardAppearance.conversationCornerRadius, style: .continuous)
                                .stroke(DJConnectCardAppearance.searchFocusGradient, lineWidth: DJConnectCardAppearance.searchFocusWidth)
                                .allowsHitTesting(false)
                        } else if !highlights.isEmpty {
                            RoundedRectangle(cornerRadius: DJConnectCardAppearance.conversationCornerRadius, style: .continuous)
                                .stroke(.white.opacity(0.36), lineWidth: 1)
                                .allowsHitTesting(false)
                        }
                    }
                    .djSessionFrostedSurface(cornerRadius: DJConnectCardAppearance.conversationCornerRadius)
                    .accessibilityAddTraits(isSelectedMatch ? [.isSelected] : [])
                }
            }
        }
        .padding(4)
        .djContentDeletion(model: artworkModel, target: entry.isRetained() &&
            [DJConnectHistoryEntry.Kind.djMoment, .conversationUser, .conversationDJ].contains(entry.kind)
            ? .init(kind: "entry", sessionID: entry.sessionID, targetID: entry.id) : nil)
    }
    private var horizontalPlayback: Bool {
        guard entry.kind == .playbackObserved else { return false }
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return true
        #endif
    }
    @ViewBuilder private var entryArtwork: some View {
        if let media = entry.sessionMedia, let model = artworkModel {
            SessionArtworkView(media: media, target: .entry(entry.id),
                audience: media.artwork.historicalDisplayAllowed ? .history : .activeFlow,
                language: language, model: model, showsAttribution: spotifyFooterURL == nil)
        }
    }
    private var entryHeading: some View {
        Label(text(entry.kind == .djMoment ? "ui.session.moment.generic" : "ui.session.history.playback"),
              systemImage: entry.kind == .djMoment ? "sparkles" : "music.note")
            .font(.caption.weight(.semibold))
    }
    private var playbackDescription: some View {
        VStack(alignment: .leading, spacing: 6) {
            entryHeading
            if let playback = entry.playback, [playback.title, playback.artist, playback.album].contains(where: { $0?.isEmpty == false }) {
                if let title = playback.title, !title.isEmpty { playbackField(title).font(.title3) }
                if let artist = playback.artist, !artist.isEmpty { playbackField(artist).font(.body) }
                if let album = playback.album, !album.isEmpty { playbackField(album).font(.callout).foregroundStyle(.secondary) }
            } else {
                SessionHighlightedText(text: entry.text ?? "", highlights: highlights).font(.title3)
            }
        }
    }
    private func playbackField(_ value: String) -> some View {
        SessionHighlightedText(text: value, highlights: SessionPlaybackHighlights.project(highlights, source: entry.text ?? "", field: value))
    }
    private var spotifyFooterURL: URL? {
        guard entry.requiresSpotifyAttribution == true else { return nil }
        if let media = entry.sessionMedia,
           let grant = media.admittedArtwork(session: entry.sessionID, target: .entry(entry.id),
                audience: media.artwork.historicalDisplayAllowed ? .history : .activeFlow),
           let raw = grant.sourceURL, let url = URL(string: raw) { return url }
        return sourceURLs.first { $0.scheme == "https" && $0.host?.lowercased() == "open.spotify.com" }
    }
    private var askButton: some View {
        Button { DJConnectHaptics.selection(); askAction() } label: {
            Image(systemName: selected ? "checkmark.bubble" : "bubble.left.and.bubble.right")
                .font(.system(size: 16))
                .foregroundStyle(selected ? djConnectAccent : .secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .djConnectPlainButtonStyle()
        .accessibilityLabel(text("ui.session.history.ask_entry"))
        .accessibilityValue(selected ? text("ui.session.history.selected_context") : "")
        .accessibilityIdentifier("ask-entry-" + entry.id)
        .help(text(selected ? "ui.session.history.selected_context" : "ui.session.history.ask_entry"))
    }
    private var sourceURLs: [URL] {
        var seen = Set<URL>()
        return ([entry.playback?.sourceURL] + sourceAttributions.flatMap { [$0["url"], $0["url_previous"], $0["revision_url"]] })
            .compactMap { raw in
                guard let raw, let url = URL(string: raw), ["http", "https"].contains(url.scheme), url.user == nil, url.password == nil else { return nil }
                return seen.insert(url).inserted ? url : nil
            }
    }
    private var sourceAttributions: [[String: String]] {
        (entry.sourceAttribution.map { [$0] } ?? []) + (entry.sources ?? [])
    }
    private func sourceLabel(for url: URL) -> String {
        guard let source = sourceAttributions.first(where: { [$0["url"], $0["url_previous"], $0["revision_url"]].contains(url.absoluteString) }) else {
            return url.host ?? ""
        }
        let label = [source["provider"], source["license"]].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return source["revision_url"] == url.absoluteString ? label + " · " + text("ui.session.history.source_revision") : label
    }
}

enum SessionPlaybackHighlights {
    static func project(_ highlights: [DJConnectHistoryHighlight], source: String, field: String) -> [DJConnectHistoryHighlight] {
        guard !field.isEmpty else { return [] }
        let range = (source as NSString).range(of: field)
        guard range.location != NSNotFound else { return [] }
        return highlights.compactMap { highlight in
            guard let safe = highlight.safeRange(in: source) else { return nil }
            let intersection = NSIntersectionRange(safe, range)
            guard intersection.length > 0 else { return nil }
            return DJConnectHistoryHighlight(startUTF16: intersection.location - range.location, lengthUTF16: intersection.length)
        }
    }
}

struct SessionHistoryMatchCard: View {
    let entry: DJConnectHistoryEntry
    let language: String
    let open: (DJConnectSessionOpenAction) -> Void
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
    var body: some View {
        TimelineView(SessionEntryRefreshSchedule(deadlines: [DJConnectHistoryEntry.date(entry.retainedUntil)].compactMap { $0 })) { clock in
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
                    Button(text("ui.session.history.open")) { DJConnectHaptics.selection(); open(action) }
                        .djConnectPlainButtonStyle()
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
                    Button { DJConnectHaptics.selection(); history.selectedEntry = nil } label: {
                        Image(systemName: "xmark")
                    }
                    .djConnectButtonStyle(DJConnectButtonStyle(
                        emphasis: .secondary,
                        shape: .icon,
                        usesLiveGlass: false,
                        iconDiameter: 44
                    ))
                    .tint(.white)
                    .foregroundStyle(.white)
                    .accessibilityLabel(text("ui.close"))
                    .help(text("ui.close"))
                    .accessibilityIdentifier("clear-session-question-context")
                }.font(.caption)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("session-question-context")
            }
            if let error = model.voiceErrorMessage {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error).font(.caption).foregroundStyle(.red)
                            .accessibilityIdentifier("session-voice-error")
                        Text(text("ui.hold.to.record.a.voice.request.for.ask.dj"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button { DJConnectHaptics.selection(); model.voiceErrorMessage = nil } label: {
                        Image(systemName: "xmark").foregroundStyle(.white)
                    }
                    .djConnectButtonStyle(DJConnectButtonStyle(
                        emphasis: .secondary, shape: .icon, usesLiveGlass: false, iconDiameter: 44
                    ))
                    .accessibilityLabel(text("ui.close"))
                    .help(text("ui.close"))
                    .accessibilityIdentifier("dismiss-session-voice-error")
                }
            }
        }
    }
}


/// Display only server-confirmed timestamps; never infer an end from playback or last entry.
enum SessionStartMetadata {
    static func text(startedAt: String, language: String, timeZone: TimeZone = .current) -> String? {
        guard let start = DJConnectHistoryEntry.date(startedAt) else { return nil }
        let locale = Locale(identifier: language)
        let date = DateFormatter()
        date.locale = locale; date.timeZone = timeZone
        date.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        let time = DateFormatter()
        time.locale = locale; time.timeZone = timeZone; time.dateFormat = "HH:mm"
        return String(format: DJConnectLocalization.localized(key: "ui.session.start_metadata", language: language),
                      locale: locale, time.string(from: start), date.string(from: start))
    }
}

enum SessionArchiveSummary {
    static func text(_ session: DJConnectSavedSession, language: String,
                     timeZone: TimeZone = .current, compact: Bool = false) -> String {
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
        if compact { return date.string(from: start) + " – " + length }
        let endLabel = calendar.isDate(start, inSameDayAs: end) ? time.string(from: end) : date.string(from: end) + " " + time.string(from: end)
        return date.string(from: start) + " – " + length + " (" + time.string(from: start) + " – " + endLabel + ")"
    }

}

/// Native presentation only: all writes, pending intent and confirmation belong to AppModel.
struct SessionControlIntent: Identifiable {
    enum Kind: Hashable { case mood, presence, persona, voice, connection, more, visualMood }
    let id = UUID()
    let kind: Kind
    let sessionID: String
    let epoch: UUID
    var sourceRect: CGRect = .zero
}

#if os(iOS)
struct SessionControlPopoverHost: View {
    @ObservedObject var model: DJConnectAppModel
    @Binding var intent: SessionControlIntent?
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var history: DJConnectSessionHistoryModel
    let showsHandoff: Bool
    let visualMoodSelection: Binding<Int>?
    let searchAction: (() -> Void)?
    let refreshAction: (() -> Void)?
    @State private var pendingAction: (SessionControlIntent, MoreAction)?
    private enum MoreAction { case handoff, refresh, voice, search }
    init(model: DJConnectAppModel, intent: Binding<SessionControlIntent?>, showsHandoff: Bool = false, refreshAction: (() -> Void)? = nil, searchAction: (() -> Void)? = nil, visualMoodSelection: Binding<Int>? = nil) {
        self.model = model; _intent = intent; history = model.sessionHistory
        self.showsHandoff = showsHandoff; self.refreshAction = refreshAction; self.searchAction = searchAction; self.visualMoodSelection = visualMoodSelection
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    private func queue(_ action: MoreAction, captured: SessionControlIntent) {
        pendingAction = (captured, action)
        intent = nil
    }
    private func finishDismissal(_ id: UUID) {
        guard let (captured, action) = pendingAction, captured.id == id else { return }
        pendingAction = nil
        guard scenePhase == .active, captured.epoch == history.responseEpoch else { return }
        switch action {
        case .handoff:
            guard showsHandoff, captured.sessionID == model.activeDJSession?.id else { return }
            model.isShowingVibeCastSessionStart = true
        case .voice:
            guard captured.sessionID == model.activeDJSession?.id else { return }
            intent = SessionControlIntent(kind: .voice, sessionID: captured.sessionID, epoch: captured.epoch, sourceRect: captured.sourceRect)
        case .search:
            guard history.searchAvailable else { return }
            searchAction?()
        case .refresh:
            guard !model.isDemoMode, model.pairingStatus == .paired else { return }
            refreshAction?()
        }
    }
    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .global)
            let source = intent?.sourceRect ?? .zero
            let anchor = source.isEmpty
                ? CGRect(x: max(0, geometry.size.width - 24), y: 0, width: 1, height: 1)
                : CGRect(x: source.midX - frame.minX, y: source.maxY - frame.minY + 4, width: 1, height: 1)
            Color.clear.frame(width: 1, height: 1)
            .popover(item: $intent, attachmentAnchor: .rect(.rect(anchor)), arrowEdge: .top) { captured in
                Group {
                    if captured.kind == .voice {
                        ProfileDJSettingsEditor(model: model).equatable().frame(idealWidth: 360)
                    } else if captured.kind == .connection {
                        SessionConnectionPopoverContent(model: model) { intent = nil }
                            .padding(16).frame(idealWidth: 360, maxWidth: 420)
                            .fixedSize(horizontal: false, vertical: true)
                            .ignoresSafeArea(.keyboard)
                    } else {
                ScrollView {
                    Group {
                        switch captured.kind {
                        case .mood:
                            SessionMoodPopoverContent(model: model, sessionID: captured.sessionID, epoch: captured.epoch)
                        case .persona:
                            ActiveSessionPersonaControl(model: model, sessionID: captured.sessionID, epoch: captured.epoch)
                        case .presence:
                            ActiveSessionPresenceControl(model: model, sessionID: captured.sessionID, epoch: captured.epoch)
                        case .visualMood:
                            if let visualMoodSelection {
                                SessionGlassChoiceSelector(
                                    steps: ["chill", "groove", "energy", "party"].enumerated().map {
                                        (text("ui.session.mood." + $0.element), $0.offset)
                                    }, selectedIndex: visualMoodSelection.wrappedValue, language: model.language
                                ) { visualMoodSelection.wrappedValue = $0 }
                            }
                        case .voice:
                            EmptyView()
                        case .connection:
                            EmptyView() // Presented above without the expanding menu ScrollView.
                        case .more:
                            VStack(alignment: .leading, spacing: 16) {
                                if searchAction != nil {
                                    Button { queue(.search, captured: captured) } label: {
                                        Label(text("ui.session.history.search"), systemImage: "magnifyingglass")
                                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    }
                                    .disabled(!history.searchAvailable)
                                    .accessibilityIdentifier("session-search-toggle")
                                }
                                if captured.sessionID == model.activeDJSession?.id {
                                    Button { queue(.voice, captured: captured) } label: {
                                        Label(text("ui.dj_settings.title"), systemImage: "speaker.wave.2")
                                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    }.accessibilityIdentifier("session-voice-toggle")
                                }
                                if showsHandoff {
                                    Button { queue(.handoff, captured: captured) } label: {
                                        Label(text("ui.vibecast.handoff.title"), systemImage: "tv.badge.wifi")
                                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    }.accessibilityIdentifier("session-handoff-toggle")
                                }
                                if refreshAction != nil {
                                    Button { queue(.refresh, captured: captured) } label: {
                                        HStack {
                                            RefreshStatusIcon(isLoading: model.isRefreshing || history.timelines[captured.sessionID]?.loading == true)
                                            Text(text("ui.refresh"))
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    }
                                    .disabled(model.isDemoMode || model.pairingStatus != .paired)
                                    .accessibilityIdentifier("screen-refresh")
                                }
                            }.buttonStyle(.plain).foregroundStyle(.white)
                        }
                    }.padding(captured.kind == .voice ? 0 : 16)
                }
                .frame(idealWidth: 360, maxHeight: 620)
                    }
                }
                .background(SessionPopoverDismissalObserver { finishDismissal(captured.id) })
                .presentationCompactAdaptation(.popover)
                .djConnectPresentationSurface()
            }
            .task(id: intent?.id) {
                guard let captured = intent, captured.kind != .connection, captured.kind != .more, captured.kind != .visualMood, !Task.isCancelled, scenePhase == .active,
                      model.isDemoMode || model.pairingStatus == .paired else { return }
                model.recordPresentationState("screen-menu-open")
                await model.refreshActiveDJSession()
                guard !Task.isCancelled, intent?.id == captured.id,
                      captured.epoch == history.responseEpoch, captured.sessionID == model.activeDJSession?.id else { return }
                await model.refreshActiveMoodCapability()
            }
            .onChange(of: intent?.id) { if intent == nil { model.recordPresentationState("screen-menu-dismissed") } }
            .onChange(of: history.responseEpoch) { model.recordPresentationState("screen-menu-epoch-changed"); intent = nil; pendingAction = nil }
            .onChange(of: model.activeDJSession?.id) { model.recordPresentationState("screen-menu-session-changed"); intent = nil; pendingAction = nil }
            .onChange(of: scenePhase) { if scenePhase != .active { model.recordPresentationState("screen-menu-scene-inactive"); intent = nil; pendingAction = nil } }
            .onDisappear { model.recordPresentationState("screen-menu-host-disappeared"); intent = nil; pendingAction = nil }
        }
    }
}

// Wait for native dismissal completion before presenting the handoff sheet.
private struct SessionPopoverDismissalObserver: UIViewControllerRepresentable {
    let onDismiss: () -> Void
    final class Controller: UIViewController {
        var onDismiss: (() -> Void)?
        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            onDismiss?()
        }
    }
    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller(); controller.onDismiss = onDismiss
        controller.view.backgroundColor = .clear
        return controller
    }
    func updateUIViewController(_ controller: Controller, context: Context) { controller.onDismiss = onDismiss }
}

private struct SessionMoodPopoverContent: View {
    @ObservedObject var model: DJConnectAppModel
    let sessionID: String
    let epoch: UUID
    private let moods = ["chill", "groove", "energy", "party"]
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    private var session: DJConnectSessionRuntime? { model.activeDJSession?.id == sessionID ? model.activeDJSession : nil }
    private var canChange: Bool {
        epoch == model.sessionHistory.responseEpoch && (model.isDemoMode || model.sessionHistory.hasAuthorizedOwner) &&
        model.activeMoodAvailable && !model.activeMoodPending && session?.confirmedMoodRevision != nil
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SessionGlassChoiceSelector(steps: moods.enumerated().map { (text("ui.session.mood." + $0.element), $0.offset) },
                                      selectedIndex: moods.firstIndex(of: session?.selectedMood ?? "") ?? 0,
                                      language: model.language, preservesAppearanceWhileDisabled: true) { index in
                guard canChange, moods.indices.contains(index) else { return }
                Task { await model.changeActiveSessionMood(moods[index], expectedSessionID: sessionID, expectedEpoch: epoch) }
            }
            .disabled(!canChange || (model.profileDJSettings.negotiated && !model.profileDJSettings.canEdit))
            .accessibilityIdentifier("active-session-mood")
            if let error = model.activeMoodError { Text(error).font(.caption).foregroundStyle(.secondary) }
            else if !canChange && !model.activeMoodPending { Text(text("ui.session.mood.unavailable")).font(.caption).foregroundStyle(.secondary) }
        }
    }
}
#endif

struct ActiveSessionPresenceToolbar: View {
    @ObservedObject var model: DJConnectAppModel
    let session: DJConnectSessionRuntime
    let requestPresentation: (() -> Void)?
    @ObservedObject private var history: DJConnectSessionHistoryModel
    @Environment(\.scenePhase) private var scenePhase
    private struct Scope: Identifiable {
        let id = UUID()
        let sessionID: String
        let epoch: UUID
    }
    @State private var scope: Scope?
    #if os(macOS)
    @FocusState private var presencePopoverFocused: Bool
    #endif
    init(model: DJConnectAppModel, session: DJConnectSessionRuntime, requestPresentation: (() -> Void)? = nil) {
        self.model = model; self.session = session; self.requestPresentation = requestPresentation; history = model.sessionHistory
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    private func trace(_ event: String) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--uitesting"),
              ProcessInfo.processInfo.environment["DJCONNECT_PRESENCE_TRACE"] == "1" else { return }
        let sessionMatches = scope.map { $0.sessionID == model.activeDJSession?.id } ?? false
        let epochMatches = scope.map { $0.epoch == history.responseEpoch } ?? false
        #if os(macOS)
        let nativeActive = NSApp.isActive
        #else
        let nativeActive = scenePhase == .active
        #endif
        NSLog("%@", "[PresenceUITest] event=\(event) scope=\(scope != nil) phase=\(scenePhase) nativeActive=\(nativeActive) foreground=\(model.isAppInForegroundForTests) sessionMatches=\(sessionMatches) epochMatches=\(epochMatches)")
        #endif
    }
    var body: some View {
        Button {
            if let requestPresentation { requestPresentation(); return }
            model.recordPresentationState("presence-toggle")
            trace("toggle-before")
            if scope != nil { scope = nil }
            else { scope = Scope(sessionID: session.id, epoch: history.responseEpoch) }
            trace("toggle-after")
        } label: {
            Image(systemName: session.confirmedPresence?.selectedPresence.choiceGlyph ?? "waveform.badge.mic")
                .foregroundStyle(.white)
        }
        .accessibilityLabel(text("ui.session.presence.title"))
        .accessibilityValue(session.confirmedPresence.map { text($0.selectedPresence.localizationKey) } ?? text("ui.session.presence.unavailable"))
        .accessibilityIdentifier("session-presence-toggle")
        .help(text("ui.session.presence.title"))
        .popover(item: $scope) { captured in
            ScrollView {
                ActiveSessionPresenceControl(model: model, sessionID: captured.sessionID, epoch: captured.epoch)
                    .padding(16)
            }
            .onAppear { model.recordPresentationState("presence-appeared") }
            .onDisappear { model.recordPresentationState("presence-disappeared") }
            .accessibilityIdentifier("session-presence-scroll")
            .frame(idealWidth: 400)
            #if os(macOS)
            .focusable()
            .focusEffectDisabled()
            .focused($presencePopoverFocused)
            .onAppear { presencePopoverFocused = true }
            .onDisappear { presencePopoverFocused = false }
            .onKeyPress(.escape) { scope = nil; return .handled }
            .onExitCommand { scope = nil }
            #endif
            .presentationCompactAdaptation(.popover)
                .djConnectPresentationSurface()
        }
        .onAppear { trace("toolbar-appeared") }
        .onDisappear { trace("toolbar-disappeared"); scope = nil }
        .task(id: scope?.id) {
            guard let captured = scope else { return }
            guard !Task.isCancelled, scenePhase == .active, model.pairingStatus == .paired else { return }
            trace("active-read-start")
            await model.refreshActiveDJSession()
            trace("active-read-finished")
            guard !Task.isCancelled, model.activeDJSession?.id == captured.sessionID,
                  history.responseEpoch == captured.epoch, scope?.id == captured.id,
                  scenePhase == .active else { return }
            await model.refreshActiveMoodCapability()
        }

        .onChange(of: session.id) { trace("session-changed"); scope = nil }
        .onChange(of: history.responseEpoch) { trace("owner-epoch-changed"); scope = nil }
        .onChange(of: scenePhase) { trace("scene-changed"); if scenePhase != .active { scope = nil } }
    }
}

extension DJConnectSessionPresenceValue {
    /// Current UI choices. Historical wire values remain decodable; Core owns migration and dosing.
    var choiceGlyph: String {
        switch self {
        case .musicOnly: return "music.note"
        case .occasional: return "bubble.left"
        case .balanced: return "bubble.left.and.bubble.right"
        case .talkative: return "waveform"
        case .presenter: return "mic.fill"
        }
    }
}

struct ActiveSessionPresenceControl: View {
    @ObservedObject var model: DJConnectAppModel
    let sessionID: String
    let epoch: UUID
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var preview = -1.0
    @State private var dragging = false
    private let values = DJConnectSessionPresenceValue.selectableChoices
    private var confirmed: DJConnectSessionPresenceSnapshot? {
        model.activeDJSession?.id == sessionID ? model.activeDJSession?.confirmedPresence : nil
    }
    private var enabled: Bool { model.activePresenceAvailable && confirmed != nil && (model.isDemoMode || model.pairingStatus == .paired) && model.sessionHistory.responseEpoch == epoch }
    private var unavailableKey: String {
        guard model.activeDJSession?.id == sessionID, model.isDemoMode || model.pairingStatus == .paired,
              model.sessionHistory.responseEpoch == epoch else { return "ui.session.presence.no_active_session" }
        switch model.activePresenceCapabilityStatus {
        case .notLoaded, .loading: return "ui.session.presence.loading"
        case .temporarilyUnavailable: return "ui.session.presence.temporarily_unavailable"
        case .incompatibleResponse: return "ui.session.presence.incompatible_response"
        case .unsupported: return "ui.session.presence.unsupported"
        case .supported: return "ui.session.presence.invalid_state"
        }
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    private func commit(_ index: Double) {
        let offset = min(values.count - 1, max(0, Int(index.rounded())))
        model.selectActiveSessionPresence(values[offset], expectedSessionID: sessionID, expectedEpoch: epoch)
    }
    private func syncPreview() {
        if !dragging {
            preview = Double((model.activePresenceDesired ?? confirmed?.selectedPresence)
                .flatMap { values.firstIndex(of: $0) } ?? -1)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if enabled {
                SessionGlassChoiceSelector(steps: values.enumerated().map { (text($0.element.localizationKey), $0.offset) },
                                           selectedIndex: values.indices.contains(Int(preview.rounded())) ? Int(preview.rounded()) : -1,
                                           language: model.language,
                                           glyphs: values.map(\.choiceGlyph),
                                           titleKey: "ui.session.presence.title",
                                           accessibilityLabelKey: "ui.session.presence.title",
                                           optionIDs: values.map { "session-presence-choice-" + $0.rawValue }) { index in
                    preview = Double(index); commit(preview)
                }
                .accessibilityIdentifier("session-presence-slider")
                .disabled(model.activePresencePending || (model.profileDJSettings.negotiated && !model.profileDJSettings.canEdit))
                .accessibilityValue(confirmed.map { text($0.selectedPresence.localizationKey) } ?? text("ui.session.presence.invalid_state"))
            } else {
                if model.activePresenceCapabilityStatus == .loading || model.activePresenceCapabilityStatus == .notLoaded {
                    ProgressView().tint(.white)
                }
                Text(text(unavailableKey)).font(.body).foregroundStyle(.white.opacity(0.88))
                    .accessibilityIdentifier("session-presence-availability")
            }
            if let error = model.activePresenceError {
                Text(error).font(.caption).accessibilityIdentifier("session-presence-error")
            }
            if model.activePresenceRequiresDecision, enabled, !model.activePresencePending {
                Button(text("ui.session.presence.accept_current")) { model.acceptCurrentSessionPresence(expectedSessionID: sessionID, expectedEpoch: epoch) }
                    .djConnectButtonStyle(DJConnectButtonStyle())
                if let desired = model.activePresenceDesired, values.contains(desired) {
                    Button(text("ui.session.presence.apply_choice") + ": " + text(desired.localizationKey)) { commit(preview) }
                        .djConnectButtonStyle(DJConnectButtonStyle())
                }
            }
        }
        .onAppear { syncPreview() }
        .onChange(of: confirmed) { syncPreview() }
        .onChange(of: model.activePresenceDesired) { syncPreview() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("active-session-presence")
    }
}

struct ActiveSessionMoodToolbar: View {
    @ObservedObject var model: DJConnectAppModel
    let session: DJConnectSessionRuntime
    let requestPresentation: (() -> Void)?
    @Environment(\.scenePhase) private var scenePhase
    private struct MoodIntent: Identifiable {
        let id = UUID()
        let sessionID: String
        let epoch: UUID
    }
    private struct CapabilityScope: Hashable {
        let sessionID: String
        let epoch: UUID
        let authorized: Bool
    }
    @State private var moodIntent: MoodIntent?
    #if os(macOS)
    @FocusState private var moodPopoverFocused: Bool
    #endif
    @ObservedObject private var history: DJConnectSessionHistoryModel
    init(model: DJConnectAppModel, session: DJConnectSessionRuntime, requestPresentation: (() -> Void)? = nil) {
        self.model = model; self.session = session; self.requestPresentation = requestPresentation; history = model.sessionHistory
    }
    private let moods = ["chill", "groove", "energy", "party"]
    private var selectedIndex: Int { moods.firstIndex(of: session.selectedMood) ?? 0 }
    private var canChange: Bool { (model.isDemoMode || history.hasAuthorizedOwner) && model.activeMoodAvailable && !model.activeMoodPending && session.confirmedMoodRevision != nil }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    var body: some View {
        Button {
            if let requestPresentation { requestPresentation(); return }
            model.recordPresentationState("mood-toggle")
            if moodIntent != nil { moodIntent = nil }
            else { moodIntent = MoodIntent(sessionID: session.id, epoch: history.responseEpoch) }
        } label: {
            Image(systemName: askDJMoodIcon(for: selectedIndex)).foregroundStyle(.white)
        }
        .accessibilityLabel(text("ui.session.select_mood"))
        .accessibilityValue(text("ui.session.mood." + moods[selectedIndex]))
        .accessibilityIdentifier("session-mood-toggle")
        .sessionIntroductionTarget("toolbar-mood")
        .help(text("ui.session.select_mood"))
        .popover(item: $moodIntent) { intent in
            VStack(alignment: .leading, spacing: 12) {
                SessionGlassChoiceSelector(steps: moods.enumerated().map { (text("ui.session.mood." + $0.element), $0.offset) },
                                         selectedIndex: selectedIndex, language: model.language,
                                         preservesAppearanceWhileDisabled: true) { index in
                    guard canChange, moods.indices.contains(index) else { return }
                    Task { await model.changeActiveSessionMood(moods[index], expectedSessionID: intent.sessionID, expectedEpoch: intent.epoch) }
                }
                .disabled(!canChange || (model.profileDJSettings.negotiated && !model.profileDJSettings.canEdit))
                .accessibilityIdentifier("active-session-mood")
                if let error = model.activeMoodError {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                } else if !canChange && !model.activeMoodPending {
                    Text(text("ui.session.mood.unavailable")).font(.caption).foregroundStyle(.secondary)
                }
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
                .djConnectPresentationSurface()
        }
        .task(id: CapabilityScope(sessionID: session.id, epoch: history.responseEpoch, authorized: model.pairingStatus == .paired)) {
            if model.isDemoMode || model.pairingStatus == .paired { await model.refreshActiveMoodCapability() }
        }
        .onDisappear { moodIntent = nil }
        .task(id: moodIntent?.id) {
            guard let intent = moodIntent else { return }
            guard !Task.isCancelled, scenePhase == .active,
                  model.isDemoMode || model.pairingStatus == .paired else { return }
            await model.refreshActiveDJSession()
            guard !Task.isCancelled, moodIntent?.id == intent.id,
                  model.activeDJSession?.id == intent.sessionID,
                  history.responseEpoch == intent.epoch, scenePhase == .active else { return }
            await model.refreshActiveMoodCapability()
        }

        .onChange(of: session.id) { moodIntent = nil }
        .onChange(of: history.responseEpoch) { moodIntent = nil }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && (model.isDemoMode || model.pairingStatus == .paired) { Task { await model.refreshActiveMoodCapability() } }
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
            Image(systemName: "xmark.circle").foregroundStyle(.red)
        }
        .disabled(model.isLoadingDJSession || model.activeDJSession == nil)
        .accessibilityLabel(text("ui.session.end"))
        .accessibilityIdentifier("session-end-button")
        .help(text("ui.session.end"))
        .alert(text("ui.session.end.confirm"), isPresented: $confirming) {
            Button(text("ui.cancel"), role: .cancel) { requestedSessionID = nil }
            Button(text("ui.session.end.action"), role: .destructive) {
                let expectedSessionID = requestedSessionID
                requestedSessionID = nil
                Task { @MainActor in
                    guard let expectedSessionID, model.activeDJSession?.id == expectedSessionID else { return }
                    await model.endDJSession()
                }
            }
            .accessibilityIdentifier("session-end-confirm")
        } message: {
            Text(text("ui.session.end.saved_in_profile"))
        }
        .tint(.white)
        .onChange(of: model.activeDJSession?.id) { _, _ in
            confirming = false
            requestedSessionID = nil
        }
    }
}

/// The same trailing status action on live product pages. Archive pages omit it.
struct ConnectionStatusToolbar: ToolbarContent {
    let model: DJConnectAppModel
    var body: some ToolbarContent {
        #if os(macOS)
        ToolbarItem(placement: .confirmationAction) { SessionConnectionToolbarButton(model: model) }
        #else
        ToolbarItem(placement: .topBarTrailing) { SessionConnectionToolbarButton(model: model) }
        #endif
    }
}

struct SessionConnectionToolbarButton: View {
    @ObservedObject var model: DJConnectAppModel
    var requestPresentation: (() -> Void)? = nil
    @State private var showingStatus = false
    private func text(_ key: String) -> String {
        DJConnectLocalization.localized(key: key, language: model.language)
    }
    private var status: SessionConnectionStatus { model.connectionPresentation }
    var body: some View {
        Button {
            #if os(iOS)
            // Preserve the search query, but release keyboard focus before presenting.
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            #endif
            model.recordPresentationState("connection-toggle")
            if let requestPresentation { requestPresentation() }
            else { showingStatus.toggle() }
        } label: {
            Image(systemName: status.icon).font(.system(size: 18, weight: .semibold))
                .foregroundStyle(status.color).frame(width: 44, height: 44)
        }
        .accessibilityLabel(text("ui.connection.status"))
        .accessibilityValue(text(status.key))
        .accessibilityIdentifier("session-connection-toggle")
        .sessionIntroductionTarget("toolbar-connection")
        .help(text(status.key))
        .popover(isPresented: $showingStatus) {
            SessionConnectionPopoverContent(model: model) { showingStatus = false }
                .padding(16).frame(idealWidth: 340, maxWidth: 420)
                .fixedSize(horizontal: false, vertical: true)
                .ignoresSafeArea(.keyboard)
                .presentationCompactAdaptation(.popover)
                .djConnectPresentationSurface()
        }
    }
}

struct SessionConnectionPopoverContent: View {
    @ObservedObject var model: DJConnectAppModel
    var dismiss: () -> Void
    private func text(_ key: String) -> String {
        DJConnectLocalization.localized(key: key, language: model.language)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text("ui.connection.status")).font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            if model.isDemoMode {
                SessionConnectionAboutLink(model: model, action: openAbout)
            } else {
                #if os(iOS)
                IOSConnectionCard(model: model, openAbout: openAbout)
                #else
                SetupStatusView(model: model, openAbout: openAbout)
                #endif
            }
        }
    }

    private func openAbout() {
        dismiss()
        model.performHomeScreenAction(.about)
    }
}

/// One full-width navigation target, including its trailing information icon.
struct SessionConnectionAboutLink: View {
    @ObservedObject var model: DJConnectAppModel
    var subtitle: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: model.connectionPresentation.icon)
                    .font(.headline)
                    .foregroundStyle(model.connectionPresentation.color)
                    .frame(width: 28, height: 28)
                    .background(model.connectionPresentation.color.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(DJConnectLocalization.localized(key: model.connectionPresentation.key, language: model.language))
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .layoutPriority(1)
                Spacer(minLength: 12)
                Image(systemName: "info.circle")
                    .font(.headline)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityHint(DJConnectLocalization.localized(key: "ui.about", language: model.language))
        .accessibilityIdentifier("connection-about-link")
    }
}

/// Presentation only: pairing is retained across outages, so it is not a health signal.
enum SessionConnectionStatus: String, CaseIterable, Equatable {
    case demo, ready, pairing, setupPending, stale, networkUnavailable, offline, connecting
    case recovering, liveUnavailable, backendUnavailable, updateRequired, connected, remote
    static func resolve(demo: Bool, pairing: DJConnectPairingStatus, mode: DJConnectHAConnectionMode,
                        backendAvailable: Bool, recovering: Bool, liveUnavailable: Bool,
                        connected: Bool = true, compatible: Bool = true, networkAvailable: Bool = true,
                        reconnecting: Bool = false) -> Self {
        if demo { return .demo }
        switch pairing {
        case .unpaired: return .ready
        case .pairing: return .pairing
        case .waitingForHomeAssistantCompletion: return .setupPending
        case .stale: return .stale
        case .paired:
            if !networkAvailable { return .networkUnavailable }
            if !compatible { return .updateRequired }
            if !connected || mode == .offline { return reconnecting ? .connecting : .offline }
            if !backendAvailable { return .backendUnavailable }
            if liveUnavailable { return .liveUnavailable }
            if recovering { return .recovering }
            return mode == .remote ? .remote : .connected
        }
    }
    var key: String { "ui.connection.combined." + rawValue }
    var icon: String {
        switch self {
        case .demo: "globe"
        case .ready: "link.badge.plus"
        case .pairing, .connecting, .recovering: "arrow.triangle.2.circlepath"
        case .setupPending: "person.crop.circle.badge.exclamationmark"
        case .stale: "lock.trianglebadge.exclamationmark"
        case .networkUnavailable: "wifi.slash"
        case .offline: "wifi.exclamationmark"
        case .backendUnavailable: "music.note.slash"
        case .liveUnavailable: "exclamationmark.bubble.fill"
        case .updateRequired: "arrow.down.app.fill"
        case .connected: "house.fill"
        case .remote: "globe"
        }
    }
    var color: Color {
        switch self {
        case .demo: .purple
        case .connected: .green
        case .remote: .teal
        case .ready: .secondary
        case .offline, .networkUnavailable: .red
        case .pairing, .connecting: .blue
        case .setupPending, .stale, .recovering, .liveUnavailable, .backendUnavailable, .updateRequired: .orange
        }
    }
}

extension DJConnectAppModel {
    var connectionPopoverDetail: String? {
        guard let message = pairingMessage,
              message != DJConnectLocalization.localized(key: "appModel.home.assistant.is.unreachable", language: language) else { return nil }
        return message
    }

    static func resolvedConnectionMode(statusMode: DJConnectHAConnectionMode, hybrid: DJConnectHybridDiagnostics?) -> DJConnectHAConnectionMode {
        switch hybrid?.state {
        case .localReady: return .local
        case .remoteReady: return .remote
        case .terminalAuthorityWithdrawn: return .offline
        // Session WS recovery is independent of a successful authenticated HTTP
        // status read; it cannot withdraw the working general HA connection.
        case .recoveringOffline, .localDegraded, nil: return statusMode
        }
    }
    var actualConnectionMode: DJConnectHAConnectionMode {
        guard pairingStatus == .paired, isConnected, !isOfflineModeActive else { return .offline }
        let statusMode: DJConnectHAConnectionMode
        if let origin = authenticatedStatusOrigin {
            statusMode = (DJConnectHybridTransport.isLocalTransportCandidate(origin) ||
                DJConnectHomeAssistantWebSocketFastPath.isLocalHomeAssistantURL(origin)) ? .local : .remote
        } else { statusMode = hybridConnectionDiagnostics == nil ? haConnectionMode : .offline }
        return Self.resolvedConnectionMode(statusMode: statusMode, hybrid: hybridConnectionDiagnostics)
    }
    var connectionPresentation: SessionConnectionStatus {
        let effectiveMode = actualConnectionMode
        return .resolve(demo: isDemoMode, pairing: pairingStatus, mode: effectiveMode,
                 backendAvailable: backendAvailable, recovering: djSessionIsRecovering,
                 liveUnavailable: djSessionLiveUnavailable, connected: isConnected,
                 compatible: isRuntimeCompatible, networkAvailable: !isOfflineModeActive,
                 reconnecting: isRefreshing)
    }
}

#if os(iOS)
/// Reuse the ScrollView's native pull-to-refresh indicator for explicit retries.
private struct SessionRefreshIndicatorBridge: UIViewRepresentable {
    let isRefreshing: Bool

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: Probe, context: Context) {
        view.shouldRefresh = isRefreshing
        view.scheduleUpdate()
    }

    static func dismantleUIView(_ view: Probe, coordinator: ()) {
        view.finishOwnedRefresh()
    }

    final class Probe: UIView {
        var shouldRefresh = false
        private weak var ownedControl: UIRefreshControl?
        private weak var scrollView: UIScrollView?
        private var updateScheduled = false
        private var restingTop: CGFloat?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            scheduleUpdate()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            scheduleUpdate()
        }

        func scheduleUpdate() {
            guard !updateScheduled else { return }
            updateScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.updateScheduled = false
                self.applyRefreshState()
            }
        }

        private func applyRefreshState() {
            var ancestor = superview
            while let view = ancestor, !(view is UIScrollView) { ancestor = view.superview }
            guard let scroll = ancestor as? UIScrollView,
                  let control = scroll.refreshControl else { return }
            control.tintColor = .white
            control.accessibilityIdentifier = "session-native-refresh"
            scrollView = scroll
            if shouldRefresh {
                guard !control.isRefreshing else { return }
                ownedControl = control
                restingTop = -scroll.adjustedContentInset.top
                control.beginRefreshing()
                let indicatorHeight = max(control.bounds.height, 60)
                scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x,
                    y: (restingTop ?? -scroll.adjustedContentInset.top) - indicatorHeight), animated: false)
            } else {
                finishOwnedRefresh()
            }
        }

        func finishOwnedRefresh() {
            guard let control = ownedControl else { return }
            ownedControl = nil
            control.endRefreshing()
            if let scroll = scrollView, let top = restingTop, scroll.contentOffset.y < top {
                scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: top), animated: true)
            }
            restingTop = nil
        }
    }
}
#endif

/// Local delivery status uses the same right-aligned question as admitted chat.
/// It is never persisted or presented as a generated assistant answer.
private struct SessionPendingConversationBubble: View {
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject var history: DJConnectSessionHistoryModel
    let turn: DJConnectSessionHistoryModel.PendingTurn
    let setPromptAction: (String) -> Void
    let feedbackAction: (DJConnectAskDJMessage) -> Void
    private func text(_ key: String) -> String {
        DJConnectLocalization.localized(key: key, language: model.language)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 10) {
                        if turn.failed {
                            Text(text(turn.failureKey ?? "ui.ask_dj.answer.unavailable"))
                                .fixedSize(horizontal: false, vertical: true)
                            Button(text(turn.contextChanged ? "ui.session.history.current_context" : "ui.retry")) {
                                DJConnectHaptics.impact()
                                if turn.contextChanged { history.useCurrentContext(turn) }
                                else { history.retry(turn) }
                            }
                            .disabled(model.isSendingAskDJText)
                        } else {
                            Label(text("ui.session.history.awaiting"), systemImage: "ellipsis.bubble")
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .djSessionFrostedSurface()
                    Text("Ask DJ").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 6)
                }
                .frame(maxWidth: 560, alignment: .leading)
                Spacer(minLength: 42)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("session-conversation-delivery-status")
            SessionCurrentConversationBubble(model: model, message: turn.questionMessage(in: model.askDJMessages),
                setPromptAction: setPromptAction, feedbackAction: feedbackAction)
        }
    }
}

/// A direct response is presentation state, separate from retained server entries.
private struct SessionCurrentConversationBubble: View {
    @ObservedObject var model: DJConnectAppModel
    let message: DJConnectAskDJMessage
    let setPromptAction: (String) -> Void
    let feedbackAction: (DJConnectAskDJMessage) -> Void
    @Environment(\.openURL) private var openURL
    var body: some View {
        AskDJMessageBubble(message: message, language: model.language,
            isStaleHistory: false, isAudioLoading: false, isAudioPlaying: false,
            isRetryDisabled: true, playingActionID: model.playingAskDJActionID,
            currentMood: model.confirmedSessionMoodInt, isSearchResult: false,
            isActiveSearchResult: false, searchText: "", retryAction: {},
            playAction: { model.playAskDJRecommendation($0) }, audioAction: {}, trackInsightAction: {},
            openLink: { openURL($0.url) }, feedbackAction: feedbackAction,
            setPromptAction: setPromptAction, isReadOnly: true, allowsConversationMenu: true, allowsSessionPlaybackActions: true,
            speechEnabled: model.sharedDJSpeechAllowed,
            sharedSpeechActions: { AnyView(SharedDJSpeechActions(model: model, speech: message.sessionSpeech, acceptedText: message.text)) })
            .djContentDeletion(model: model, target: model.sessionHistory.contentDeletionTarget(for: message))
    }
}

/// Follows one submitted question across its pending, current-only and retained rows.
/// Background refreshes and assistant replies cannot select a different question.
struct SessionSubmittedQuestion: Equatable {
    let sessionID: String
    let localID: UUID
    let clientID: String?

    func target(sessionID: String, pending: [DJConnectSessionHistoryModel.PendingTurn],
                entries: [DJConnectHistoryEntry], current: [DJConnectAskDJMessage], at now: Date = Date()) -> String? {
        guard sessionID == self.sessionID else { return nil }
        if let clientID, let entry = entries.first(where: {
            $0.sessionID == sessionID && $0.kind == .conversationUser && $0.clientMessageID == clientID && $0.isContractValid && $0.isRetained(at: now)
        }) { return entry.id }
        if let question = current.first(where: {
            $0.role == .user && ($0.id == localID || (clientID != nil && $0.clientMessageID == clientID))
        }) { return "current-conversation-" + question.id.uuidString }
        if let turn = pending.first(where: {
            $0.context.sessionID == sessionID && ($0.localMessageID == localID || (clientID != nil && $0.id == clientID))
        }) { return "pending-" + turn.id }
        return nil
    }
}


private struct SessionDeleteConfirmation {
    let sessionID: String
    let revision: String
    let epoch: UUID
}

private struct SessionArchiveDeletionConfirmation: ViewModifier {
    @ObservedObject var history: DJConnectSessionHistoryModel
    let language: String
    @Binding var confirmation: SessionDeleteConfirmation?
    @Binding var isPresented: Bool
    var dismissOnSuccess: Bool = true
    @State private var failed = false
    @State private var presentationGeneration = UUID()
    @Environment(\.dismiss) private var dismiss
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
    func body(content: Content) -> some View {
        content
            .alert(text("ui.session.history.delete.confirm"), isPresented: $isPresented, presenting: confirmation) { request in
                Button(text("ui.cancel"), role: .cancel) { confirmation = nil }
                Button(text("ui.session.history.delete.action"), role: .destructive) {
                    confirmation = nil
                    let generation = presentationGeneration
                    Task { @MainActor in
                        let deleted = await history.deleteSession(request.sessionID, expectedRevision: request.revision,
                                                                  expectedEpoch: request.epoch)
                        guard generation == presentationGeneration else { return }
                        if deleted { if dismissOnSuccess { dismiss() } }
                        else if request.epoch == history.responseEpoch { failed = true }
                    }
                }
                .accessibilityIdentifier("session-delete-confirm")
            } message: { _ in Text(text("ui.session.history.delete.message")) }
            .alert(text(history.hasUnconfirmedDeletion ? "ui.session.history.delete.unconfirmed" : "ui.session.history.delete.failed"), isPresented: $failed) {
                Button(text("ui.close"), role: .cancel) {}
            }
            .tint(.white)
            .onChange(of: history.responseEpoch) { _, _ in
                isPresented = false; confirmation = nil; failed = false
            }
            .onChange(of: history.archiveResponseEpoch) { _, _ in
                presentationGeneration = UUID(); isPresented = false; confirmation = nil; failed = false
            }
            .onDisappear { presentationGeneration = UUID(); isPresented = false; confirmation = nil }
    }
}

/// A separate row action avoids nesting destructive controls in the open button.
private struct SavedSessionDeleteButton: View {
    @ObservedObject var history: DJConnectSessionHistoryModel
    let language: String
    let sessionID: String
    @State private var preparing = false
    @State private var preparationGeneration = UUID()
    @State private var confirmation: SessionDeleteConfirmation?
    @State private var confirming = false
    @State private var failed = false
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
    var body: some View {
        Button(role: .destructive) {
            guard !preparing, history.canDeleteSession(sessionID) else { return }
            let epoch = history.responseEpoch, generation = UUID()
            preparationGeneration = generation; preparing = true
            Task { @MainActor in
                let revision = await history.prepareSessionDeletion(sessionID, expectedEpoch: epoch)
                guard generation == preparationGeneration else { return }
                preparing = false
                guard epoch == history.responseEpoch, !Task.isCancelled else { return }
                guard let revision else { failed = true; return }
                confirmation = .init(sessionID: sessionID, revision: revision, epoch: epoch)
                confirming = true
            }
        } label: {
            Image(systemName: "trash").foregroundStyle(.red)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .disabled(preparing || !history.canDeleteSession(sessionID) || history.deletingSessionID != nil)
        .opacity(!preparing && history.canDeleteSession(sessionID) && history.deletingSessionID == nil ? 1 : 0.4)
        .accessibilityLabel(text("ui.session.history.delete.title"))
        .accessibilityIdentifier("saved-session-delete-" + sessionID)
        .help(text("ui.session.history.delete.title"))
        .modifier(SessionArchiveDeletionConfirmation(history: history, language: language,
            confirmation: $confirmation, isPresented: $confirming, dismissOnSuccess: false))
        .alert(text("ui.session.history.delete.failed"), isPresented: $failed) {
            Button(text("ui.close"), role: .cancel) {}
        }
        .onChange(of: history.responseEpoch) { _, _ in preparationGeneration = UUID(); preparing = false; failed = false }
        .onDisappear { preparationGeneration = UUID(); preparing = false }
    }
}

/// The list's destructive action captures an authorized server snapshot before confirmation.
private struct SavedSessionsDeleteAllButton: View {
    typealias ConfirmedAction = @MainActor () async -> Bool
    struct PreparedAction {
        let count: Int
        let perform: ConfirmedAction
    }
    let language: String
    let isEnabled: Bool
    let hasUnconfirmedDeletion: Bool
    let contextEpoch: UUID
    let archiveEpoch: UUID
    let prepareDeletion: @MainActor () async -> PreparedAction?
    @State private var pendingAction: ConfirmedAction?
    @State private var targetCount = 0
    @State private var confirming = false
    @State private var failed = false
    @State private var working = false
    @State private var presentationGeneration = UUID()
    private func text(_ suffix: String) -> String {
        DJConnectLocalization.localized(key: "ui.session.history.delete_all." + suffix, language: language)
    }
    var body: some View {
        Button(role: .destructive) {
            working = true
            let generation = presentationGeneration
            Task { @MainActor in
                let action = await prepareDeletion()
                working = false
                guard generation == presentationGeneration else { return }
                guard let action else { failed = true; return }
                targetCount = action.count
                pendingAction = action.count > 0 ? action.perform : nil
                confirming = action.count > 0
            }
        } label: {
            Image(systemName: "trash").foregroundStyle(.red)
        }
        .disabled(!isEnabled || working)
        .accessibilityLabel(text("title"))
        .accessibilityIdentifier("saved-sessions-delete-all-button")
        .help(text("title"))
        .alert(text("confirm"), isPresented: $confirming) {
            Button(DJConnectLocalization.localized(key: "ui.cancel", language: language), role: .cancel) { pendingAction = nil }
            Button(text("action"), role: .destructive) {
                guard let action = pendingAction else { return }
                pendingAction = nil; working = true
                let generation = presentationGeneration
                Task { @MainActor in
                    let success = await action()
                    working = false
                    guard generation == presentationGeneration else { return }
                    if !success { failed = true }
                }
            }
            .accessibilityIdentifier("saved-sessions-delete-all-confirm")
        } message: { Text(String(format: text("message"), Int64(targetCount))) }
        .alert(hasUnconfirmedDeletion ? DJConnectLocalization.localized(key: "ui.session.history.delete.unconfirmed", language: language) : text("failed"), isPresented: $failed) {
            Button(DJConnectLocalization.localized(key: "ui.close", language: language), role: .cancel) {}
        }
        .tint(.white)
        .onChange(of: contextEpoch) { _, _ in resetConfirmation() }
        .onChange(of: archiveEpoch) { _, _ in resetConfirmation() }
        .onDisappear { resetConfirmation() }
    }
    private func resetConfirmation() {
        presentationGeneration = UUID(); confirming = false; pendingAction = nil; failed = false
    }
}
