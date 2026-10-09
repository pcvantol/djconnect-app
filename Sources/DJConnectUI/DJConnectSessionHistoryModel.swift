import Foundation
import Combine
import DJConnectCore

/// In-memory presentation state, owned by the existing Apple application model.
/// Entry identity, ordering, rights, search and conversation context remain Core-owned.
@MainActor
public final class DJConnectSessionHistoryModel: ObservableObject {
    public struct Timeline: Equatable {
        public var session: DJConnectSavedSession?
        public var entries: [DJConnectHistoryEntry] = []
        public var nextCursor: String?
        public var revision: String?
        public var loading = false
        public var errorKey: String?
        public var windowed = false
    }
    public struct PendingTurn: Identifiable, Equatable {
        public let id: String
        public let text: String
        public let context: DJConnectConversationContext
        public let localMessageID: UUID?
        public let payload: DJConnectAskDJRequest
        public var failed = false
        public var contextChanged = false
    }

    @Published public private(set) var available = false
    @Published public private(set) var preparing = false
    @Published public private(set) var searchAvailable = false
    @Published public private(set) var profileScopeActive = false
    @Published public private(set) var sessions: [DJConnectSavedSession] = []
    @Published public private(set) var listLoading = false
    @Published public private(set) var listErrorKey: String?
    @Published public private(set) var listNextCursor: String?
    @Published public private(set) var timelines: [String: Timeline] = [:]
    @Published public private(set) var historicalMatches: [String: [DJConnectHistoryEntry]] = [:]
    @Published public private(set) var pendingTurns: [PendingTurn] = []
    @Published public var selectedEntry: DJConnectSessionEntryReference?
    @Published public var openTarget: DJConnectSessionEntryReference?
    @Published public private(set) var navigationErrorKey: String?
    @Published public private(set) var searchMatches: [DJConnectHistoryEntry] = []
    @Published public private(set) var searchLoading = false
    @Published public private(set) var searchErrorKey: String?
    @Published public private(set) var searchComplete = false
    @Published public private(set) var searchTotal: Int?
    @Published public private(set) var searchNextCursor: String?
    @Published public private(set) var acceptedSearchQuery = ""
    @Published public private(set) var acceptedSearchSessionID = ""
    private weak var host: DJConnectAppModel?
    private var epoch = UUID()
    private var ownerScope: String?
    private var listRevision: String?
    private var listGeneration = UUID()
    private var timelineGenerations: [String: UUID] = [:]
    private var searchGeneration = UUID()
    private var searchRevision: String?
    private var searchTask: Task<Void, Never>?
    private var voiceContext: DJConnectConversationContext?
    private var voiceClientID: String?
    private var voicePayload: DJConnectAskDJRequest?
    private var preparationTask: Task<Void, Never>?
    private var preparationID = UUID()
    private var navigationGeneration = UUID()

    var responseEpoch: UUID { epoch }
    var hasAuthorizedOwner: Bool { ownerScope != nil }
    public var selectedEntryPreview: String? {
        guard let reference = selectedEntry else { return nil }
        return (timelines[reference.sessionID]?.entries ?? []).first { $0.reference == reference && $0.isRetained() }?.text
            ?? historicalMatches.values.flatMap { $0 }.first { $0.reference == reference && $0.isRetained() }?.text
    }

    init(host: DJConnectAppModel) { self.host = host }

    public func prepare() async {
        if let preparationTask { await preparationTask.value; return }
        let id = UUID(); preparationID = id
        let task = Task<Void, Never> { [weak self] in await self?.performPreparation() }
        preparationTask = task
        await task.value
        if preparationID == id { preparationTask = nil }
    }

    private func performPreparation() async {
        guard let host, host.canRefreshSessionHistory else { return }
        preparing = true
        defer { preparing = false }
        let captured = epoch
        do {
            let caps = try await host.withHomeAssistantClient { try await $0.sessionHistoryCapabilities() }
            guard captured == epoch else { return }
            available = caps.available; searchAvailable = caps.searchAvailable
            if available && !profileScopeActive {
                while host.isSendingAskDJText || host.isRecordingVoice || host.voiceStatus == .processing {
                    try await Task.sleep(for: .milliseconds(50))
                    guard captured == epoch, !Task.isCancelled else { return }
                }
                profileScopeActive = true
                host.enterProfileConversationScope()
            }
            if available { await refreshConversation() }
        } catch {
            guard captured == epoch else { return }
            listErrorKey = "ui.session.history.unavailable"
        }
    }

    public func reset() {
        preparationTask?.cancel(); preparationTask = nil; preparationID = UUID(); preparing = false
        epoch = UUID(); searchGeneration = UUID(); listGeneration = UUID(); navigationGeneration = UUID()
        searchTask?.cancel(); searchTask = nil
        available = false; searchAvailable = false; profileScopeActive = false; ownerScope = nil
        sessions = []; timelines = [:]; historicalMatches = [:]; pendingTurns = []
        selectedEntry = nil; openTarget = nil; voiceContext = nil; voiceClientID = nil; voicePayload = nil
        listNextCursor = nil; listRevision = nil; listLoading = false; listErrorKey = nil
        clearSearch(); navigationErrorKey = nil; timelineGenerations = [:]
    }

    public func suspend() {
        epoch = UUID(); searchTask?.cancel(); searchTask = nil
        timelines = [:]; sessions = []; historicalMatches = [:]; searchMatches = []
        selectedEntry = nil; openTarget = nil; voiceContext = nil; voiceClientID = nil; voicePayload = nil
        clearSearch()
        pendingTurns = []; host?.setProfileConversationSending(false)
    }

    public func refreshConversation() async {
        guard profileScopeActive, let host, host.canRefreshSessionHistory else { return }
        let captured = epoch
        do {
            let response = try await host.withHomeAssistantClient { try await $0.profileConversationHistory() }
            guard captured == epoch, !response.ownerScope.isEmpty else { return }
            let scope = response.ownerScope
            if let ownerScope, ownerScope != scope {
                suspend(); host.enterProfileConversationScope()
            }
            ownerScope = scope
            guard host.applyProfileConversationHistory(response.base) else { return }
            historicalMatches = response.historicalMatches
            reconcilePending(with: response.base)
        } catch {
            guard captured == epoch else { return }
            historicalMatches = [:]
            host.clearProfileConversationDisplay()
            if isAuthorizationFailure(error) { suspend() }
        }
    }

    public func loadSessions(more: Bool = false) async {
        guard available, !listLoading, let host, host.canRefreshSessionHistory else { return }
        let cursor = more ? listNextCursor : nil
        if more && cursor == nil { return }
        let generation = UUID(); listGeneration = generation
        let captured = epoch
        listLoading = true; listErrorKey = nil
        defer { if generation == listGeneration { listLoading = false } }
        do {
            let page = try await host.withHomeAssistantClient { try await $0.savedSessions(cursor: cursor) }
            guard captured == epoch, generation == listGeneration else { return }
            guard cursor == nil || listRevision == page.revision.value else { throw DJConnectError.invalidResponse }
            let old = cursor == nil ? [] : sessions
            sessions = mergeSessions(old, page.sessions.filter { $0.readOnly })
            listRevision = page.revision.value; listNextCursor = page.nextCursor
        } catch {
            guard captured == epoch, generation == listGeneration else { return }
            sessions = []; listNextCursor = nil
            listErrorKey = errorKey(error)
        }
    }

    public func loadTimeline(_ sessionID: String, more: Bool = false, window: DJConnectHistoryWindow? = nil,
                             anchorEntryID: String? = nil, limit: Int = 20) async {
        guard available, let host, host.canRefreshSessionHistory, !(timelines[sessionID]?.loading ?? false) else { return }
        let cursor = more ? timelines[sessionID]?.nextCursor : nil
        if more && cursor == nil { return }
        let captured = epoch; let generation = UUID(); timelineGenerations[sessionID] = generation
        timelines[sessionID, default: Timeline()].loading = true
        timelines[sessionID]?.errorKey = nil
        defer { if timelineGenerations[sessionID] == generation { timelines[sessionID]?.loading = false } }
        do {
            let page = try await host.withHomeAssistantClient {
                try await $0.sessionTimeline(sessionID: sessionID, cursor: cursor, window: window, anchorEntryID: anchorEntryID, limit: limit)
            }
            guard captured == epoch, timelineGenerations[sessionID] == generation else { return }
            guard cursor == nil || timelines[sessionID]?.revision == page.revision.value else { throw DJConnectError.invalidResponse }
            var previous = cursor == nil && window == nil ? [] : timelines[sessionID]?.entries ?? []
            if window != nil, let lower = page.scannedOrderMin, let upper = page.scannedOrderMax {
                previous.removeAll { $0.order >= lower && $0.order <= upper }
            }
            let entries = try mergeEntries(previous, page.entries.filter { $0.isRetained() })
            let nextCursor = window != nil && timelines[sessionID]?.revision == page.revision.value ? timelines[sessionID]?.nextCursor : page.nextCursor
            timelines[sessionID] = Timeline(session: page.session, entries: entries, nextCursor: nextCursor,
                                            revision: page.revision.value, loading: false, errorKey: nil, windowed: window != nil)
        } catch {
            guard captured == epoch, timelineGenerations[sessionID] == generation else { return }
            timelines[sessionID] = Timeline(errorKey: errorKey(error))
        }
    }

    public func refreshVisibleTimeline(_ sessionID: String, anchor: String?) async {
        if let anchor, !["current", "tail"].contains(anchor), !anchor.hasPrefix("pending-") {
            await loadTimeline(sessionID, window: .anchor, anchorEntryID: anchor)
        }
        await loadTimeline(sessionID, window: .tail)
    }

    /// Every known navigation target is revalidated before displaying an anchor.
    @discardableResult public func open(_ action: DJConnectSessionOpenAction, navigate: Bool = true) async -> Bool {
        guard available, let host, host.canRefreshSessionHistory else { return false }
        navigationErrorKey = nil
        let captured = epoch; let generation = UUID(); navigationGeneration = generation
        timelineGenerations[action.sessionID] = generation
        do {
            let response = try await host.withHomeAssistantClient { try await $0.openSavedSession(action) }
            guard captured == epoch, generation == navigationGeneration, timelineGenerations[action.sessionID] == generation, response.entry.isRetained() else { return false }
            var timeline = timelines[action.sessionID] ?? Timeline()
            if navigate && timeline.revision != response.session.revision.value { timeline.entries = [] }
            timeline.session = response.session; timeline.revision = response.session.revision.value
            timeline.entries = try mergeEntries(timeline.entries, [response.entry])
            timeline.loading = false
            timelines[action.sessionID] = timeline
            if navigate { openTarget = action.reference }
            return true
        } catch {
            guard captured == epoch, generation == navigationGeneration, timelineGenerations[action.sessionID] == generation else { return false }
            timelines[action.sessionID] = nil
            searchMatches.removeAll { $0.sessionID == action.sessionID && $0.id == action.entryID }
            historicalMatches = historicalMatches.mapValues { $0.filter { $0.reference != action.reference } }
            if navigate { openTarget = nil }
            navigationErrorKey = errorKey(error)
            clearSearchResults(); searchErrorKey = errorKey(error)
            return false
        }
    }

    public func search(sessionID: String, query: String) {
        searchTask?.cancel(); searchGeneration = UUID(); searchLoading = false
        clearSearchResults()
        guard searchAvailable, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let generation = searchGeneration
        searchLoading = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            await self.loadSearch(sessionID: sessionID, query: query, cursor: nil, generation: generation)
        }
    }

    public func moreSearch() async {
        guard !searchLoading, let cursor = searchNextCursor else { return }
        await loadSearch(sessionID: acceptedSearchSessionID, query: acceptedSearchQuery, cursor: cursor, generation: searchGeneration)
    }

    private func loadSearch(sessionID: String, query: String, cursor: String?, generation: UUID) async {
        guard let host else { return }
        let captured = epoch; searchLoading = true
        defer { if generation == searchGeneration { searchLoading = false } }
        do {
            let page = try await host.withHomeAssistantClient { try await $0.searchSession(sessionID: sessionID, query: query, cursor: cursor) }
            guard captured == epoch, generation == searchGeneration, !Task.isCancelled else { return }
            guard cursor == nil || searchRevision == page.revision.value else { throw DJConnectError.invalidResponse }
            searchMatches = try mergeEntries(cursor == nil ? [] : searchMatches, page.matches.filter { $0.isRetained() })
            searchRevision = page.revision.value; acceptedSearchQuery = query; acceptedSearchSessionID = sessionID
            searchNextCursor = page.nextCursor; searchComplete = page.complete
            searchTotal = page.totalCount; searchErrorKey = nil
        } catch {
            guard captured == epoch, generation == searchGeneration, !Task.isCancelled else { return }
            clearSearchResults(); searchErrorKey = errorKey(error)
        }
    }

    public func clearSearch() {
        searchTask?.cancel(); searchGeneration = UUID(); clearSearchResults(); searchLoading = false
    }
    private func clearSearchResults() {
        searchMatches = []; searchNextCursor = nil; searchTotal = nil; searchComplete = false
        searchErrorKey = nil; searchRevision = nil; acceptedSearchQuery = ""; acceptedSearchSessionID = ""
    }

    public func sendText() {
        guard profileScopeActive, let host, host.canUseProfileConversation, !host.isSendingAskDJText else { return }
        guard ownerScope != nil else { host.failProfileConversationText(id: nil, errorKey: "ui.session.history.unavailable"); return }
        let text = host.askDJDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let id = UUID().uuidString
        let localID = host.beginProfileConversationText(text: text, clientMessageID: id)
        let context = currentContext()
        let turn = PendingTurn(id: id, text: text, context: context, localMessageID: localID,
            payload: host.profileConversationPayload(text: text, clientMessageID: id, context: context))
        pendingTurns.append(turn)
        Task { await submit(turn) }
    }

    public func retry(_ turn: PendingTurn) {
        guard turn.failed, !turn.contextChanged, let host, !host.isSendingAskDJText else { return }
        pendingTurns.removeAll { $0.id == turn.id }; pendingTurns.append(PendingTurn(
            id: turn.id, text: turn.text, context: turn.context, localMessageID: turn.localMessageID, payload: turn.payload))
        host.setProfileConversationSending(true)
        Task { await submit(turn) }
    }

    public func useCurrentContext(_ turn: PendingTurn) {
        guard let host else { return }
        pendingTurns.removeAll { $0.id == turn.id }; selectedEntry = nil
        host.askDJDraft = turn.text
    }

    private func submit(_ turn: PendingTurn) async {
        guard let host else { return }
        let captured = epoch
        do {
            let payload = turn.payload
            let response = try await host.withHomeAssistantClient { try await $0.sendSessionConversation(payload) }
            guard captured == epoch else { return }
            try await accept(response, fallback: turn.localMessageID)
            pendingTurns.removeAll { $0.id == turn.id }
        } catch {
            guard captured == epoch else { return }
            if let index = pendingTurns.firstIndex(where: { $0.id == turn.id }) {
                pendingTurns[index].failed = true; pendingTurns[index].contextChanged = isConflict(error)
            }
            host.failProfileConversationText(id: turn.localMessageID, errorKey: errorKey(error))
        }
    }

    public func captureVoiceContext() {
        guard voiceContext == nil else { return }
        voiceContext = currentContext(); voiceClientID = UUID().uuidString
        if let host, let voiceContext, let voiceClientID {
            voicePayload = host.profileConversationPayload(text: "", clientMessageID: voiceClientID, context: voiceContext)
        }
    }
    public func cancelVoiceContext() { voiceContext = nil; voiceClientID = nil; voicePayload = nil }
    public func uploadVoice(_ data: Data) async throws {
        guard let host, let context = voiceContext, let id = voiceClientID, let payload = voicePayload else { throw DJConnectError.invalidResponse }
        let captured = epoch
        defer { if voiceClientID == id { cancelVoiceContext() } }
        let response = try await host.withHomeAssistantClient {
            try await $0.sendSessionVoice(wavData: data, context: context, clientMessageID: id, language: payload.language ?? "en",
                                          mood: payload.mood, djStyle: payload.djStyle, musicDNAKey: payload.musicDNAKey)
        }
        guard captured == epoch else { throw CancellationError() }
        try await accept(response, fallback: nil)
    }

    public func clearExistingHistory() async throws {
        guard profileScopeActive, let host, let scope = ownerScope else { throw CancellationError() }
        let captured = epoch
        let response = try await host.withHomeAssistantClient { try await $0.clearProfileConversationHistory() }
        guard captured == epoch, ownerScope == scope, response.ownerScope == scope else { throw CancellationError() }
        guard response.base.isClearAcknowledged else { throw DJConnectError.invalidResponse }
        suspend()
        host.applyConfirmedProfileConversationClear(response.base)
    }

    public func fetchExistingHistory() async throws -> DJConnectAskDJHistoryResponse {
        guard let host else { throw DJConnectError.invalidResponse }
        let captured = epoch
        let response = try await host.withHomeAssistantClient { try await $0.profileConversationHistory() }
        guard captured == epoch, !response.ownerScope.isEmpty else { throw CancellationError() }
        let scope = response.ownerScope
        if ownerScope != nil && ownerScope != scope { suspend(); host.enterProfileConversationScope() }
        ownerScope = scope
        guard host.applyProfileConversationHistory(response.base) else { throw DJConnectError.server(statusCode: 409, message: nil) }
        historicalMatches = response.historicalMatches
        reconcilePending(with: response.base)
        return response.base
    }

    public func sendExistingText(_ text: String, clientMessageID: String) async throws -> DJConnectAskDJMessageResponse {
        guard let host else { throw DJConnectError.invalidResponse }
        let captured = epoch
        let payload = host.profileConversationPayload(text: text, clientMessageID: clientMessageID, context: currentContext())
        let response = try await host.withHomeAssistantClient { try await $0.sendSessionConversation(payload) }
        guard captured == epoch else { throw CancellationError() }
        try await accept(response, fallback: nil, apply: false)
        return response.base
    }

    private func accept(_ response: DJConnectSessionConversationResponse, fallback: UUID?, apply: Bool = true) async throws {
        guard let host, ownerScope == response.ownerScope else {
            suspend(); await refreshConversation(); throw DJConnectError.invalidResponse
        }
        if apply && !host.applyProfileConversationResponse(response.base, fallback: fallback) {
            throw DJConnectError.server(statusCode: 409, message: nil)
        }
        let acceptedEpoch = epoch
        for message in response.base.messages where message.role != .user {
            historicalMatches[message.id] = response.historicalMatches
        }
        if let id = response.base.assistantMessage?.id { historicalMatches[id] = response.historicalMatches }
        if let sessionID = response.conversation.context.sessionID {
            await loadTimeline(sessionID, window: .tail)
            guard acceptedEpoch == epoch else { throw CancellationError() }
            for entryID in response.conversation.entryIDs {
                let action = DJConnectSessionOpenAction(reference: .init(sessionID: sessionID, entryID: entryID))
                _ = await open(action, navigate: false)
                guard acceptedEpoch == epoch else { throw CancellationError() }
            }
        }
    }

    private func currentContext() -> DJConnectConversationContext {
        .init(sessionID: host?.activeDJSession?.sessionID, selectedEntry: selectedEntry)
    }
    public func clearNavigationError() { navigationErrorKey = nil }
    private func reconcilePending(with response: DJConnectAskDJHistoryResponse) {
        let completed = Set(response.messages.filter { $0.role != .user && $0.messageKind != .system }.compactMap(\.clientMessageID))
        let hadPending = !pendingTurns.isEmpty
        pendingTurns.removeAll { completed.contains($0.id) }
        if hadPending && !pendingTurns.contains(where: { !$0.failed }) { host?.setProfileConversationSending(false) }
    }
    private func mergeEntries(_ old: [DJConnectHistoryEntry], _ new: [DJConnectHistoryEntry]) throws -> [DJConnectHistoryEntry] {
        var byID = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        for entry in new { byID[entry.id] = entry }
        let result = byID.values.sorted { $0.order < $1.order }
        guard Set(result.map(\.order)).count == result.count else { throw DJConnectError.invalidResponse }
        return result
    }
    private func mergeSessions(_ old: [DJConnectSavedSession], _ new: [DJConnectSavedSession]) -> [DJConnectSavedSession] {
        var seen = Set<String>(); return (old + new).filter { seen.insert($0.id).inserted }
    }
    private func isConflict(_ error: Error) -> Bool {
        if case DJConnectError.server(let status, _) = error { return status == 409 }
        return false
    }
    private func isAuthorizationFailure(_ error: Error) -> Bool {
        if case DJConnectError.authStale = error { return true }; return false
    }
    private func errorKey(_ error: Error) -> String {
        isConflict(error) ? "ui.session.history.changed" : "ui.session.history.unavailable"
    }
}
