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
    @State private var refreshing = false
    @State private var initialLoadFinished = false
    @State private var statusToast: DJConnectVisualNotice?
    @State private var localOpenedSessionID: String?
    private let externalOpenedSessionID: Binding<String?>?
    private var openedSessionID: Binding<String?> { externalOpenedSessionID ?? $localOpenedSessionID }
    private let embedsNavigationStack: Bool
    init(model: DJConnectAppModel, embedsNavigationStack: Bool = true, openedSessionID: Binding<String?>? = nil) {
        self.model = model; history = model.sessionHistory; self.embedsNavigationStack = embedsNavigationStack
        externalOpenedSessionID = openedSessionID
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    @ViewBuilder var body: some View {
        if embedsNavigationStack { NavigationStack { content } }
        else { content }
    }
    private var showsListHeader: Bool {
        #if os(macOS)
        model.isDemoMode || !initialLoadFinished || history.listLoading || history.preparing
        #else
        // Keep the iOS native refresh bridge mounted even after loading.
        true
        #endif
    }
    private var content: some View {
            savedSessionsContainer {
                if showsListHeader {
                VStack(alignment: .leading, spacing: 16) {
                    if model.isDemoMode { Label(text("demo.session.notice"), systemImage: "sparkles").font(.caption).accessibilityIdentifier("session-demo-notice") }
                    #if !os(iOS)
                    if !initialLoadFinished || history.listLoading || history.preparing {
                        ProgressView().controlSize(.large).tint(.white)
                            .accessibilityLabel(text("ui.session.history.loading"))
                    }
                    #endif

                }
                .frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity).padding(.horizontal, 20)
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
                    ForEach(history.sessions) { session in
                        Button { openedSessionID.wrappedValue = session.id } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title2.weight(.medium)).foregroundStyle(djConnectAccent)
                                    .frame(width: 52, height: 52)
                                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(SessionArchiveSummary.text(session, language: model.language))
                                        .font(.body.weight(.medium)).foregroundStyle(.white).multilineTextAlignment(.leading)
                                    Text(text(session.lifecycleStatus == "INTERRUPTED" ? "ui.session.history.interrupted" : "ui.session.history.ended"))
                                        .font(.caption2.weight(.medium)).foregroundStyle(.white.opacity(0.78))
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
                            .task { await history.loadNextSessionsPage(expectedCursor: cursor) }
                            .id(cursor)
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
                                .djConnectButtonStyle(DJConnectButtonStyle())
                                .disabled(refreshing)
                        }
                    }
                    .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("saved-sessions-empty-state")
                }
            }
            .navigationDestination(item: openedSessionID) { sessionID in
                SessionTimelineScreen(model: model, sessionID: sessionID)
                    .navigationTitle(detailTitle(sessionID: sessionID))
            }
            .navigationTitle(text("ui.session.history.title"))
            .scrollBounceBehavior(.always)
            .refreshable { await refresh() }
            .toolbar {
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
            .djStatusToastOverlay(statusToast, screenImage: "clock.arrow.circlepath")
            .task(id: model.isDemoMode || model.canRefreshSessionHistory) {
                initialLoadFinished = false
                await history.restoreVisibleSessions()
                guard !Task.isCancelled else { return }
                initialLoadFinished = true
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await history.restoreVisibleSessions() } }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("screen-saved-sessions")
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
        guard initialLoadFinished, history.sessions.isEmpty, !history.listLoading, !history.preparing else { return nil }
        if let error = history.listErrorKey { return text(error) }
        return text(history.available ? "ui.session.history.empty" : "ui.session.history.unavailable")
    }
    private func refresh() async {
        guard !refreshing, !model.isDemoMode, model.pairingStatus == .paired else { return }
        refreshing = true
        defer { refreshing = false }
        statusToast = DJConnectVisualNotice(text: text("ui.session.history.loading"), systemImage: "clock.arrow.circlepath")
        let epoch = history.responseEpoch
        await history.prepare()
        let succeeded = await history.loadSessions()
        guard !Task.isCancelled, epoch == history.responseEpoch else { statusToast = nil; return }
        // A superseded/cancelled read has no authoritative failure. The current
        // request owns the list indicator and any actual error presentation.
        guard succeeded || !history.available || history.listErrorKey != nil else { statusToast = nil; return }
        let notice = DJConnectVisualNotice(text: text(succeeded ? "ui.session.history.updated" : "ui.session.history.unavailable"),
                                          systemImage: "clock.arrow.circlepath")
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
    var refreshAction: (() -> Void)?
    @StateObject private var renderCache = SessionTimelineRenderCache()
    @State private var sessionControlIntent: SessionControlIntent?
    @State private var menuFrames: [SessionControlIntent.Kind: CGRect] = [:]
    @State private var currentHeaderVisible = true
    @State private var composerKeyboardVisible = false
    private var composerBottomPadding: CGFloat {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            return composerKeyboardVisible ? 6 : 21
        }
        #endif
        return 8
    }
    @State private var floatingComposerHeight: CGFloat = 96
    @State private var oldestEntriesVisible = false
    @State private var pagingTask: Task<Void, Never>?
    @State private var visibleEntry: String?
    @State private var priorSearchPosition: String?
    @State private var query = ""
    @State private var searching = false
    @State private var selectedMatchID: String?
    @State private var retryRefreshing = false
    @State private var pullRefreshing = false
    @State private var resumePosition: String?
    @State private var anchorGeneration = UUID()
    @State private var sceneRestoreTask: Task<Void, Never>?
    @FocusState private var inputFocused: Bool
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init(model: DJConnectAppModel, sessionID: String, activeSession: DJConnectSessionRuntime? = nil,
         initialAnchor: String? = nil, openQueueAction: @escaping () -> Void = {}, refreshAction: (() -> Void)? = nil) {
        self.model = model; history = model.sessionHistory; self.sessionID = sessionID
        self.activeSession = activeSession; self.initialAnchor = initialAnchor; self.openQueueAction = openQueueAction
        self.refreshAction = refreshAction
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
    private var timeline: DJConnectSessionHistoryModel.Timeline { history.timelines[sessionID] ?? .init() }
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

    var body: some View {
        let retentionDeadlines = renderCache.snapshot(timeline.entries, sessionID: sessionID, epoch: history.responseEpoch).compactMap(\.deadline)
        let matchMap = matches.reduce(into: [String: DJConnectHistoryEntry]()) { result, entry in
            if result[entry.id] == nil { result[entry.id] = entry }
        }
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if model.isDemoMode && activeSession == nil { Label(text("demo.session.notice"), systemImage: "sparkles").font(.caption).padding(8).accessibilityIdentifier("session-demo-notice") }
                TimelineView(SessionEntryRefreshSchedule(deadlines: retentionDeadlines)) { clock in
                    let preparedEntries = renderCache.snapshot(timeline.entries, sessionID: sessionID, epoch: history.responseEpoch, at: clock.date)
                    ScrollView {
                        DJSessionGlassGroup {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            if let activeSession {
                                scrollingCurrent(activeSession).id("current")
                            }
                            if activeSession == nil {
                                VStack(alignment: .leading, spacing: 6) {
                                    if let session = timeline.session ?? history.sessions.first(where: { $0.id == sessionID }) {
                                        Text(SessionArchiveSummary.text(session, language: model.language))
                                            .font(.headline).accessibilityAddTraits(.isHeader)
                                            .accessibilityIdentifier("session-archive-summary")
                                        Text(text(session.lifecycleStatus == "INTERRUPTED" ? "ui.session.history.interrupted" : "ui.session.history.ended"))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Label(text("ui.session.history.readonly"), systemImage: "lock")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 20)
                                .id("current")
                            }
                            if let error = model.djSessionErrorMessage, activeSession != nil {
                                Text(error).foregroundStyle(.red).padding(.horizontal, 20)
                            }
                            if !history.available && activeSession != nil {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(text("ui.session.history.unavailable"))
                                        .foregroundStyle(.white.opacity(0.82))
                                    Button {
                                        Task {
                                            await history.prepare()
                                            await history.loadTimeline(sessionID, window: .tail)
                                        }
                                    } label: {
                                        Label(text("ui.refresh.page"), systemImage: "arrow.clockwise")
                                    }
                                    .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, usesLiveGlass: false))
                                    .disabled(history.preparing)
                                }
                                .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                                .djSessionFrostedSurface().padding(.horizontal, 20)
                                .accessibilityIdentifier("session-history-unavailable")
                            }
                            if let key = timeline.errorKey {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text(text(key)).fixedSize(horizontal: false, vertical: true)
                                        .foregroundStyle(.white.opacity(0.82))
                                    Button {
                                        guard !retryRefreshing else { return }
                                        Task { @MainActor in
                                            retryRefreshing = true
                                            defer { retryRefreshing = false }
                                            await history.loadTimeline(sessionID, window: .tail)
                                        }
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
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(turn.text).fixedSize(horizontal: false, vertical: true)
                                    if turn.failed {
                                        Text(text(turn.contextChanged ? "ui.session.history.changed" : "ui.session.history.unavailable"))
                                        Button(text(turn.contextChanged ? "ui.session.history.current_context" : "ui.retry")) {
                                            DJConnectHaptics.impact()
                                            if turn.contextChanged { history.useCurrentContext(turn) }
                                            else { history.retry(turn) }
                                        }
                                    } else { Label(text("ui.session.history.awaiting"), systemImage: "ellipsis.bubble") }
                                }
                                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                .djSessionFrostedSurface()
                                .padding(.horizontal, 20)
                                .id("pending-" + turn.id)
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
                                    artworkPreparing: history.artworkPreparing.contains(entry.reference),
                                    artworkFailed: history.artworkFailed.contains(entry.reference),
                                    refreshArtwork: history.artworkAvailable ? { Task { await history.refreshArtwork(for: entry) } } : nil,
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
                            }
                            if history.available && timeline.entries.isEmpty && !timeline.loading && timeline.errorKey == nil {
                                Text(text(activeSession == nil ? "ui.session.history.no_entries" : "ui.session.history.no_entries_active")).padding(.horizontal, 20)
                            }
                            Color.clear.frame(height: 1).id("tail")
                        }
                        .frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity)
                        .padding(.top, activeSession != nil ? 0 : archivedTopPadding).padding(.bottom, 20)
                        .scrollTargetLayout()
                        // Background updates never reveal pull-to-refresh or move the scroll offset.
                        }
                    }
                    .contentMargins(.bottom, usesFloatingComposer && !searching ? floatingComposerHeight + composerBottomPadding + 8 : 0, for: .scrollContent)
                    .overlay(alignment: .bottom) {
                        if usesFloatingComposer && !searching {
                            sessionComposer(floating: true)
                                .djFloatingAskDJWidth(maximum: 1000)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { floatingComposerHeight = $0 }
                                .padding(.horizontal, 12)
                                .padding(.bottom, composerBottomPadding)
                        }
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            if searching {
                                TimelineView(SessionEntryRefreshSchedule(deadlines: history.searchMatches.compactMap { DJConnectHistoryEntry.date($0.retainedUntil) })) { _ in searchBar(proxy: proxy) }
                            }
                        }
                    }
                    .onScrollTargetVisibilityChange(idType: String.self, threshold: 0.01) { visibleIDs in
                        currentHeaderVisible = visibleIDs.contains("current")
                        oldestEntriesVisible = visibleIDs.contains("tail") || timeline.entries.first.map { visibleIDs.contains($0.id) } == true
                        if oldestEntriesVisible { loadEarlierIfNeeded() }
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
                    .scrollPosition(id: $visibleEntry, anchor: .top)
                    .refreshable {
                        pullRefreshing = true
                        defer { pullRefreshing = false }
                        await history.refreshConversation()
                        await history.refreshVisibleTimeline(sessionID, anchor: visibleEntry)
                    }
                }
                if activeSession != nil && !usesFloatingComposer && !searching {
                    sessionComposer(floating: false)
                }
            }
            .background(sessionBackground)
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            composerKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            composerKeyboardVisible = false
        }
        #endif
            .toolbar {
                #if os(macOS)
                ToolbarItemGroup(placement: djConnectRefreshToolbarPlacement) {
                    if let refreshAction { RefreshButton(model: model, action: refreshAction, isLoading: timeline.loading || retryRefreshing) }
                    sessionSearchToolbarButton(proxy: proxy)
                }
                #endif
                #if os(iOS)
                if usesExpandedToolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        if activeSession != nil { SessionConnectionToolbarButton(model: model) }
                        sessionSearchToolbarButton(proxy: proxy)
                    }
                }
                #endif
                #if os(iOS)
                if usesExpandedToolbar {
                    ToolbarItemGroup(placement: djConnectRefreshToolbarPlacement) {
                        sessionToolbarActions(proxy: proxy)
                    }
                } else {
                    // Keep our More menu directly on the bar: system overflow
                    // must not wrap it inside another ellipsis submenu.
                    ToolbarItem(placement: djConnectRefreshToolbarPlacement) {
                        HStack(spacing: 0) {
                            sessionToolbarActions(proxy: proxy)
                                .frame(minWidth: 40, minHeight: 44)
                        }
                        .labelStyle(.iconOnly)
                    }
                }
                #else
                ToolbarItemGroup(placement: djConnectRefreshToolbarPlacement) {
                    sessionToolbarActions(proxy: proxy)
                }
                #endif
                #if os(macOS)
                if activeSession != nil {
                    ToolbarItemGroup(placement: .confirmationAction) {
                        SessionConnectionToolbarButton(model: model)
                        SessionEndToolbarButton(model: model)
                    }
                }
                #endif
            }
            #if os(iOS)
            .overlay(alignment: .topTrailing) {
                SessionControlPopoverHost(model: model, intent: $sessionControlIntent, showsHandoff: allowsHandoffPresentation, refreshAction: refreshAction)

            }
            #endif
            .onAppear {
                guard activeSession != nil, initialAnchor == nil else { return }
                Task { @MainActor in
                    await Task.yield()
                    jump("current", proxy: proxy)
                    currentHeaderVisible = true
                }
            }
            .task(id: sessionID) {
                let restoreGeneration = anchorGeneration
                await history.prepare(); await history.loadTimeline(sessionID, window: .tail)
                guard !Task.isCancelled, restoreGeneration == anchorGeneration else { return }
                if let initialAnchor { await selectAnchor(initialAnchor, proxy: proxy, restoreRequest: true) }
                else if activeSession != nil { jump("current", proxy: proxy) }
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
            .onChange(of: activeSession?.id) { model.isShowingVibeCastSessionStart = false }
            .onChange(of: history.profileScopeActive) { model.isShowingVibeCastSessionStart = false }
            .onChange(of: history.responseEpoch) { model.isShowingVibeCastSessionStart = false }
            .onChange(of: query) { _, value in sceneRestoreTask?.cancel(); anchorGeneration = UUID(); history.search(sessionID: sessionID, query: value) }
            .onChange(of: history.searchMatches) {
                guard searching, !matches.isEmpty else { return }
                if !matches.contains(where: { $0.id == selectedMatchID }) {
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
            .onDisappear(perform: clearReadingState)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(activeSession == nil ? "screen-history-timeline" : "screen-session-conversation")
        }
    }

    @ViewBuilder private func sessionToolbarActions(proxy: ScrollViewProxy) -> some View {
        Group {
            if let activeSession {
                #if !os(macOS)
                if !usesExpandedToolbar { SessionConnectionToolbarButton(model: model) }
                #endif
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
                ActiveSessionPersonaToolbar(model: model, session: activeSession)
                ActiveSessionVoiceToolbar(model: model, session: activeSession)
            }
            #if !os(macOS)
            if !usesExpandedToolbar, activeSession != nil {
                SessionEndToolbarButton(model: model)
            }
            #endif
            #if !os(macOS)
            if !usesExpandedToolbar { sessionSearchToolbarButton(proxy: proxy) }
            #endif
            #if os(macOS)
            if allowsHandoffPresentation {
                Button { model.isShowingVibeCastSessionStart = true } label: {
                    Image(systemName: "tv.badge.wifi")
                        .foregroundStyle(model.vibeCastHandoffApproved ? djConnectAccent : .white)
                }
                .accessibilityLabel(text("ui.vibecast.handoff.title"))
                .accessibilityIdentifier("session-handoff-toggle")
                .help(text("ui.vibecast.handoff.title"))
            }
            #else
            if usesExpandedToolbar {
                if allowsHandoffPresentation {
                    Button { model.isShowingVibeCastSessionStart = true } label: {
                        Image(systemName: "tv.badge.wifi")
                            .foregroundStyle(model.vibeCastHandoffApproved ? djConnectAccent : .white)
                    }
                    .accessibilityLabel(text("ui.vibecast.handoff.title"))
                    .accessibilityIdentifier("session-handoff-toggle")
                }
                if activeSession != nil { SessionEndToolbarButton(model: model) }
                if let refreshAction {
                    RefreshButton(model: model, action: refreshAction, isLoading: timeline.loading || retryRefreshing)
                }
            } else if allowsHandoffPresentation || refreshAction != nil {
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
        }
    }

    private func sessionSearchToolbarButton(proxy: ScrollViewProxy) -> some View {
        Button {
            if searching { closeSearch(proxy: proxy) }
            else { priorSearchPosition = visibleEntry; inputFocused = false; searching = true; searchFocused = true }
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
        history.rememberReadingAnchor(visibleEntry, sessionID: sessionID)
        pagingTask?.cancel(); pagingTask = nil
        renderCache.clear()
        sceneRestoreTask?.cancel(); anchorGeneration = UUID(); history.clearSearch()
    }

    private func currentHeader(_ session: DJConnectSessionRuntime) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isDemoMode {
                Label(text("demo.session.notice"), systemImage: "sparkles")
                    .font(.caption).frame(maxWidth: .infinity).padding(.bottom, 8)
                    .accessibilityIdentifier("session-demo-notice")
            }
            if model.djSessionRecoveryGap {
                Label(text("ui.transport.snapshot_gap"), systemImage: "arrow.clockwise")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("session-recovery-coverage-gap")
            }
            NativeSessionMomentsView(session: session, language: model.language,
            isRecovering: model.djSessionIsRecovering,
            isLiveUnavailable: model.djSessionLiveUnavailable,
            retryConnection: { Task { await model.retryDJSessionConnection() } },
            artworkBaseURL: URL(string: model.haLocalURL.isEmpty ? model.homeAssistantURL : model.haLocalURL),
            playbackOutputName: model.sessionPlaybackOutputName, playbackModel: model)
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
            } else { jump("current", proxy: proxy) }
        }
    }
    private func moveMatch(_ delta: Int, proxy: ScrollViewProxy) {
        guard !matches.isEmpty else { return }
        let index = (selectedIndex + delta + matches.count) % matches.count
        selectedMatchID = matches[index].id
        let id = matches[index].id
        Task { await selectAnchor(id, proxy: proxy, searchRequest: true) }
    }
    private func sessionComposer(floating: Bool) -> some View {
        AskDJInputBar(model: model, canSend: canSend,
                      canUseVoiceInput: (model.isDemoMode || model.canUseProfileConversation) && model.voiceEnabled,
                      isInputFocused: $inputFocused, floating: floating, placeholderKey: "ui.session.chat.placeholder",
                      surfaceColors: activeSession.map { DJConnectSessionMoodPalette(mood: $0.selectedMood).colors })
        .sessionIntroductionTarget("chat")
    }

    @ViewBuilder private func searchBar(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                anchorGeneration = UUID(); self.selectedMatchID = nil
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
    var artworkPreparing = false
    var artworkFailed = false
    var refreshArtwork: (() -> Void)? = nil
    var playAction: (DJConnectAskDJPlaybackAction) -> Void = { _ in }
    var highlights: [DJConnectHistoryHighlight] = []
    var isSelectedMatch = false
    var selected = false
    var askAction: () -> Void = {}
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.entry == rhs.entry && lhs.language == rhs.language && lhs.messageAdapter == rhs.messageAdapter &&
        lhs.contextEpoch == rhs.contextEpoch && lhs.opensActiveComposer == rhs.opensActiveComposer &&
        lhs.allowsPlaybackActions == rhs.allowsPlaybackActions && lhs.playingActionID == rhs.playingActionID &&
        lhs.artworkModel === rhs.artworkModel && lhs.artworkPreparing == rhs.artworkPreparing &&
        lhs.artworkFailed == rhs.artworkFailed && (lhs.refreshArtwork == nil) == (rhs.refreshArtwork == nil) && lhs.highlights == rhs.highlights && lhs.isSelectedMatch == rhs.isSelectedMatch && lhs.selected == rhs.selected
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entry.requiresSpotifyAttribution == true && spotifyAttributionLogo == nil {
                Text(text("ui.session.history.unavailable"))
            } else {
                if entry.kind == .conversationUser || entry.kind == .conversationDJ {
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
                        }, feedbackAction: { _ in }, setPromptAction: { _ in }, isReadOnly: true, allowsSessionPlaybackActions: allowsPlaybackActions,
                        serverHighlights: highlights, contextQuestionAction: askAction,
                        contextQuestionSelected: selected, contextQuestionID: "ask-entry-" + entry.id)
                    if entry.inputType == "voice" { Label(text("ui.session.history.voice"), systemImage: "mic.fill").font(.caption) }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        if let media = entry.sessionMedia, let model = artworkModel {
                            SessionArtworkView(media: media, target: .entry(entry.id),
                                audience: media.artwork.historicalDisplayAllowed ? .history : .activeFlow,
                                language: language, model: model)
                        }
                        Label(text(entry.kind == .djMoment ? "ui.session.moment.generic" : "ui.session.history.playback"),
                              systemImage: entry.kind == .djMoment ? "sparkles" : "music.note")
                            .font(.caption.weight(.semibold)).padding(.trailing, 40)
                        if let refreshArtwork {
                            Button(action: refreshArtwork) {
                                HStack(spacing: 6) {
                                    if artworkPreparing { ProgressView().controlSize(.small) }
                                    else { Image(systemName: "arrow.clockwise") }
                                    Text(text("ui.session.artwork.refresh"))
                                }
                            }
                            .buttonStyle(.bordered).controlSize(.small)
                            .disabled(artworkPreparing)
                            .accessibilityIdentifier("session-artwork-refresh-" + entry.id)
                            if artworkFailed {
                                Text(text("ui.session.artwork.unavailable")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        SessionHighlightedText(text: entry.text ?? "", highlights: highlights).font(.title3)
                        SessionTimestampText(value: entry.occurredAt, language: language).font(.caption).foregroundStyle(.secondary)
                        ForEach(sourceURLs, id: \.absoluteString) { url in
                            let key = url.absoluteString == entry.sourceAttribution?["url_previous"] ? "ui.session.source_previous" : "ui.session.source_current"
                            Link((entry.sourceAttribution?["provider"] ?? url.host ?? "") + " · " + text(key), destination: url)
                                .foregroundStyle(.white)
                                .tint(.white)
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

/// Native presentation only: all writes, pending intent and confirmation belong to AppModel.
struct SessionControlIntent: Identifiable {
    enum Kind: Hashable { case mood, presence, connection, more, visualMood }
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
    let refreshAction: (() -> Void)?
    @State private var pendingAction: (SessionControlIntent, MoreAction)?
    private enum MoreAction { case handoff, refresh }
    init(model: DJConnectAppModel, intent: Binding<SessionControlIntent?>, showsHandoff: Bool = false, refreshAction: (() -> Void)? = nil, visualMoodSelection: Binding<Int>? = nil) {
        self.model = model; _intent = intent; history = model.sessionHistory
        self.showsHandoff = showsHandoff; self.refreshAction = refreshAction; self.visualMoodSelection = visualMoodSelection
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
                ScrollView {
                    Group {
                        switch captured.kind {
                        case .mood:
                            SessionMoodPopoverContent(model: model, sessionID: captured.sessionID, epoch: captured.epoch)
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
                        case .connection:
                            SessionConnectionPopoverContent(model: model) { intent = nil }
                        case .more:
                            VStack(alignment: .leading, spacing: 16) {
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
                    }.padding(16)
                }
                .frame(idealWidth: 360)
                .background(SessionPopoverDismissalObserver { finishDismissal(captured.id) })
                .presentationCompactAdaptation(.popover)
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
                                      language: model.language) { index in
                guard canChange, moods.indices.contains(index) else { return }
                Task { await model.changeActiveSessionMood(moods[index], expectedSessionID: sessionID, expectedEpoch: epoch) }
            }
            .disabled(!canChange)
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
            Image(systemName: "waveform.badge.mic").foregroundStyle(.white)
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

struct ActiveSessionPresenceControl: View {
    @ObservedObject var model: DJConnectAppModel
    let sessionID: String
    let epoch: UUID
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var preview = 2.0
    @State private var dragging = false
    private let values = DJConnectSessionPresenceValue.allCases
    private var confirmed: DJConnectSessionPresenceSnapshot? {
        model.activeDJSession?.id == sessionID ? model.activeDJSession?.confirmedPresence : nil
    }
    private var enabled: Bool { model.activePresenceAvailable && confirmed != nil && model.pairingStatus == .paired && model.sessionHistory.responseEpoch == epoch }
    private var unavailableKey: String {
        guard model.activeDJSession?.id == sessionID, model.pairingStatus == .paired,
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
        if !dragging, let choice = model.activePresenceDesired ?? confirmed?.selectedPresence,
           let index = values.firstIndex(of: choice) { preview = Double(index) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if enabled {
                SessionGlassChoiceSelector(steps: values.enumerated().map { (text($0.element.localizationKey), $0.offset) },
                                           selectedIndex: min(values.count - 1, max(0, Int(preview.rounded()))),
                                           language: model.language,
                                           glyphs: ["music.note", "bubble.left", "bubble.left.and.bubble.right", "waveform", "mic.fill"],
                                           titleKey: "ui.session.presence.title",
                                           accessibilityLabelKey: "ui.session.presence.title",
                                           optionIDs: values.map { "session-presence-choice-" + $0.rawValue }) { index in
                    preview = Double(index); commit(preview)
                }
                .accessibilityIdentifier("session-presence-slider")
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
                if let desired = model.activePresenceDesired {
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
                                         selectedIndex: selectedIndex, language: model.language) { index in
                    guard canChange, moods.indices.contains(index) else { return }
                    Task { await model.changeActiveSessionMood(moods[index], expectedSessionID: intent.sessionID, expectedEpoch: intent.epoch) }
                }
                .disabled(!canChange)
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
                .presentationCompactAdaptation(.popover)
        }
    }
}

struct SessionConnectionPopoverContent: View {
    @ObservedObject var model: DJConnectAppModel
    var dismiss: () -> Void
    private var status: SessionConnectionStatus { model.connectionPresentation }
    private func text(_ key: String) -> String {
        DJConnectLocalization.localized(key: key, language: model.language)
    }
    var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(text("ui.connection.status")).font(.headline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                if model.isDemoMode {
                    Label(text(status.key), systemImage: status.icon)
                } else {
                    #if os(iOS)
                    IOSConnectionCard(model: model)
                    #else
                    SetupStatusView(model: model)
                    #endif
                }
                if status.showsConnectionDetails {
                    Button {
                        dismiss()
                        model.performHomeScreenAction(.about)
                    } label: {
                        Label(text("ui.connection.details"), systemImage: "info.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("connection-details-link")
                }
            }
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
    var showsConnectionDetails: Bool { self != .connected }
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
    var connectionPresentation: SessionConnectionStatus {
        let hybrid = hybridConnectionDiagnostics
        let effectiveMode: DJConnectHAConnectionMode
        switch hybrid?.state {
        case .localReady, .localDegraded: effectiveMode = .local
        case .remoteReady: effectiveMode = .remote
        case .recoveringOffline, .terminalAuthorityWithdrawn: effectiveMode = .offline
        case nil: effectiveMode = haConnectionMode
        }
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
