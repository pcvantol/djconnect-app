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
        public let requestEpoch: UUID
        public let ownerScope: String
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
    private struct LiveResponse {
        let sessionID: String
        let message: DJConnectAskDJMessage
    }
    @Published private var liveResponses: [String: LiveResponse] = [:]
    private weak var host: DJConnectAppModel?
    private var epoch = UUID()
    private var ownerScope: String?
    private var listRevision: String?
    private var listGeneration = UUID()
    private var timelineGenerations: [String: UUID] = [:]
    private var timelineNavigations: [String: UUID] = [:]
    private var readingAnchors: [String: String] = [:]
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

    /// Resolve only a retained, server-owned answer identity; never infer an entry from its text.
    func contextEntry(for message: DJConnectAskDJMessage) -> DJConnectHistoryEntry? {
        guard profileScopeActive || host?.isDemoMode == true else { return nil }
        return Self.contextEntry(for: message, entries: timelines.values.flatMap(\.entries)
            + historicalMatches.values.flatMap { $0 })
    }

    nonisolated static func contextEntry(for message: DJConnectAskDJMessage,
                                         entries: [DJConnectHistoryEntry], at date: Date = Date()) -> DJConnectHistoryEntry? {
        guard message.role == .dj, message.messageKind == .assistant,
              let serverID = message.serverID, !serverID.isEmpty else { return nil }
        let matches = entries.filter {
            $0.kind == .conversationDJ && $0.originMessageID == serverID
                && $0.isContractValid && $0.isRetained(at: date)
        }
        guard let entry = matches.first, matches.allSatisfy({ $0.reference == entry.reference }) else { return nil }
        return entry
    }

    func discardLiveResponses() { liveResponses = [:] }

    /// Only a directly accepted response supplies live actions; history reads never do.
    func retainLiveResponse(_ response: DJConnectSessionConversationResponse) {
        guard let host, ownerScope == response.ownerScope,
              let sessionID = response.conversation.context.sessionID,
              host.activeDJSession?.id == sessionID,
              let assistant = response.base.assistantMessage, assistant.role == .assistant,
              assistant.messageKind != .system else { return }
        liveResponses = liveResponses.filter { $0.value.sessionID == sessionID }
        liveResponses[assistant.id] = LiveResponse(sessionID: sessionID,
            message: host.sessionResponseMessage(assistant))
    }

    func liveMessage(for entry: DJConnectHistoryEntry, activeSessionID: String?) -> DJConnectAskDJMessage? {
        guard let host, host.canRefreshSessionHistory, ownerScope != nil,
              let activeSessionID, activeSessionID == host.activeDJSession?.id,
              entry.sessionID == activeSessionID, entry.kind == .conversationDJ,
              entry.isContractValid, entry.isRetained(),
              let origin = entry.originMessageID, let live = liveResponses[origin],
              live.sessionID == activeSessionID,
              live.message.clientMessageID == entry.clientMessageID,
              live.message.text == entry.text else { return nil }
        var message = live.message
        message.playbackActions = message.playbackActions.filter {
            !$0.isFavoriteCurrentTrackControlAction && !$0.isAskDJMessageAction
        }
        if let current = host.askDJMessages.first(where: { $0.serverID == origin }) {
            message.playbackActions = message.playbackActions.map { original in
                current.playbackActions.first(where: { $0.id == original.id }) ?? original
            }
        }
        return message
    }

    func playLiveAction(_ action: DJConnectAskDJPlaybackAction, for entry: DJConnectHistoryEntry,
                        expectedEpoch: UUID) {
        guard expectedEpoch == epoch, let host,
              let message = liveMessage(for: entry, activeSessionID: host.activeDJSession?.id),
              message.playbackActions.contains(action) else { return }
        host.playAskDJRecommendation(action, isStillValid: { [weak self] in
            guard let self, self.epoch == expectedEpoch,
                  let current = self.liveMessage(for: entry, activeSessionID: host.activeDJSession?.id) else { return false }
            guard current.playbackActions.contains(where: { $0.id == action.id }),
                  let offered = self.liveResponses[entry.originMessageID ?? ""]?.message.playbackActions.first(where: { $0.id == action.id }) else { return false }
            var submitted = action
            submitted.active = offered.active // Completion/output selection changes presentation only.
            return offered == submitted
        })
    }

    init(host: DJConnectAppModel) { self.host = host }

    /// Explicit, ephemeral review examples; never an owner grant or backend history.
    func installDemo(_ data: DJConnectDemoSessionData, preservingArchives: Bool = false) {
        guard host?.isDemoMode == true else { return }
        let archived = preservingArchives ? sessions.filter { $0.readOnly && $0.id.hasPrefix("demo-active-") } : []
        let oldTimelines = timelines.filter { archived.map(\.id).contains($0.key) }
        reset()
        available = true; searchAvailable = true; ownerScope = nil
        sessions = archived + data.sessions; timelines = data.timelines
        timelines.merge(oldTimelines) { _, old in old }
    }

    func recordDemoPlayback(title: String, artist: String) {
        guard let host, host.isDemoMode, let id = host.activeDJSession?.id, var timeline = timelines[id] else { return }
        do {
            let order = (timeline.entries.last?.order ?? 0) + 1
            timeline.entries.append(try DJConnectDemoSessionData.observed(id: id, order: order, title: title, artist: artist, at: Date()))
            timelines[id] = timeline
        } catch { return }
    }

    func recordDemoTurn(question: String, answer: String, inputType: String = "text") {
        guard let host, host.isDemoMode, let id = host.activeDJSession?.id, var timeline = timelines[id] else { return }
        do {
            let next = (timeline.entries.last?.order ?? 0) + 1
            let entries = try DJConnectDemoSessionData.turn(sessionID: id, order: next, question: question, answer: answer,
                                                          inputType: inputType, selected: selectedEntry, at: Date())
            timeline.entries += entries; timelines[id] = timeline
        } catch { return }
    }

    func archiveDemoSession(_ sessionID: String) {
        guard host?.isDemoMode == true, var timeline = timelines[sessionID], let session = timeline.session else { return }
        do {
            let archived = try DJConnectDemoSessionData.saved(id: sessionID, start: DJConnectHistoryEntry.date(session.startedAt) ?? Date(), end: Date())
            timeline.session = archived; timelines[sessionID] = timeline
            sessions.insert(archived, at: 0)
        } catch { return }
    }

    func rememberReadingAnchor(_ anchor: String?, sessionID: String) {
        guard hasAuthorizedOwner || host?.isDemoMode == true, let anchor, !anchor.hasPrefix("pending-") else { return }
        readingAnchors[sessionID] = anchor
    }
    func readingAnchor(sessionID: String) -> String? { (hasAuthorizedOwner || host?.isDemoMode == true) ? readingAnchors[sessionID] : nil }

    public func prepare() async {
        if host?.isDemoMode == true { return }
        if let preparationTask { await preparationTask.value; return }
        let id = UUID(); preparationID = id
        let task = Task<Void, Never> { [weak self] in await self?.performPreparation() }
        preparationTask = task
        await task.value
        if preparationID == id { preparationTask = nil }
    }

    private func performPreparation() async {
        guard let host, host.canRefreshSessionHistory else { return }
        let operation = preparationID
        preparing = true
        defer { if preparationID == operation { preparing = false } }
        let captured = epoch
        do {
            let caps = try await host.withHomeAssistantClient { try await $0.sessionHistoryCapabilities() }
            guard captured == epoch, host.canRefreshSessionHistory, !Task.isCancelled else { return }
            available = caps.available; searchAvailable = caps.searchAvailable
            if available && !profileScopeActive {
                while host.isSendingAskDJText || host.isRecordingVoice || host.voiceStatus == .processing {
                    try await Task.sleep(for: .milliseconds(50))
                    guard captured == epoch, host.canRefreshSessionHistory, !Task.isCancelled else { return }
                }
                profileScopeActive = true
                host.enterProfileConversationScope()
            }
            if available { await refreshConversation() }
        } catch {
            guard !Task.isCancelled, !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
            guard captured == epoch else { return }
            if withdrawAuthority(for: error) { return }
            listErrorKey = "ui.session.history.unavailable"
        }
    }

    public func reset() {
        host?.invalidateSessionPlaybackActions()
        preparationTask?.cancel(); preparationTask = nil; preparationID = UUID(); preparing = false
        liveResponses = [:]
        epoch = UUID(); searchGeneration = UUID(); listGeneration = UUID(); navigationGeneration = UUID()
        searchTask?.cancel(); searchTask = nil
        available = false; searchAvailable = false; profileScopeActive = false; ownerScope = nil
        sessions = []; timelines = [:]; historicalMatches = [:]; pendingTurns = []; readingAnchors = [:]
        host?.setProfileConversationSending(false)
        selectedEntry = nil; openTarget = nil; voiceContext = nil; voiceClientID = nil; voicePayload = nil
        listNextCursor = nil; listRevision = nil; listLoading = false; listErrorKey = nil
        clearSearch(); navigationErrorKey = nil; timelineGenerations = [:]; timelineNavigations = [:]
    }

    public func suspend() {
        host?.invalidateSessionPlaybackActions()
        preparationTask?.cancel(); preparationTask = nil; preparationID = UUID(); preparing = false
        liveResponses = [:]
        epoch = UUID(); ownerScope = nil
        listGeneration = UUID(); timelineGenerations = [:]; timelineNavigations = [:]; navigationGeneration = UUID()
        listLoading = false; listNextCursor = nil; listRevision = nil
        searchTask?.cancel(); searchTask = nil
        timelines = [:]; sessions = []; historicalMatches = [:]; searchMatches = []; readingAnchors = [:]
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
            guard !Task.isCancelled, !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
            guard captured == epoch else { return }
            historicalMatches = [:]
            host.clearProfileConversationDisplay()
            _ = withdrawAuthority(for: error)
        }
    }

    @discardableResult
    public func loadSessions(more: Bool = false) async -> Bool {
        if host?.isDemoMode == true { return available }
        guard available, !(more && listLoading), let host, host.canRefreshSessionHistory else { return false }
        let cursor = more ? listNextCursor : nil
        if more && cursor == nil { return false }
        let generation = UUID(); listGeneration = generation
        let captured = epoch
        listLoading = true; listErrorKey = nil
        defer { if generation == listGeneration { listLoading = false } }
        do {
            let page = try await host.withHomeAssistantClient { try await $0.savedSessions(cursor: cursor) }
            guard captured == epoch, generation == listGeneration else { return false }
            guard cursor == nil || listRevision == page.revision.value else { throw DJConnectError.invalidResponse }
            let old = cursor == nil ? [] : sessions
            sessions = mergeSessions(old, page.sessions.filter { $0.readOnly })
            listRevision = page.revision.value; listNextCursor = page.nextCursor
            return true
        } catch {
            guard !Task.isCancelled, !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return false }
            guard captured == epoch, generation == listGeneration else { return false }
            if withdrawAuthority(for: error) { return false }
            sessions = []; listNextCursor = nil
            listErrorKey = errorKey(error)
            return false
        }
    }

    public func loadTimeline(_ sessionID: String, more: Bool = false, window: DJConnectHistoryWindow? = nil,
                             anchorEntryID: String? = nil, limit: Int = 20, preserveLoadedEntries: Bool = false) async {
        if host?.isDemoMode == true { return }
        guard available, let host, host.canRefreshSessionHistory, !(timelines[sessionID]?.loading ?? false),
              timelineNavigations[sessionID] == nil else { return }
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
            var previous = cursor == nil && window == nil && !preserveLoadedEntries ? [] : timelines[sessionID]?.entries ?? []
            if window != nil, let lower = page.scannedOrderMin, let upper = page.scannedOrderMax {
                previous.removeAll { $0.order >= lower && $0.order <= upper }
            }
            let entries = try mergeEntries(previous, page.entries.filter { $0.isRetained() })
            let nextCursor = window != nil && timelines[sessionID]?.revision == page.revision.value ? timelines[sessionID]?.nextCursor : page.nextCursor
            timelines[sessionID] = Timeline(session: page.session, entries: entries, nextCursor: nextCursor,
                                            revision: page.revision.value, loading: false, errorKey: nil, windowed: window != nil)
        } catch {
            guard !Task.isCancelled, !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
            guard captured == epoch, timelineGenerations[sessionID] == generation else { return }
            if withdrawAuthority(for: error) { return }
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
        if host?.isDemoMode == true {
            guard available, timelines[action.sessionID]?.entries.contains(where: { $0.reference == action.reference && $0.isRetained() }) == true else { return false }
            if navigate { openTarget = action.reference }
            return true
        }
        guard available, let host, host.canRefreshSessionHistory else { return false }
        navigationErrorKey = nil
        let captured = epoch; let generation = UUID(); navigationGeneration = generation
        timelineGenerations[action.sessionID] = generation
        timelineNavigations[action.sessionID] = generation
        defer { if timelineNavigations[action.sessionID] == generation { timelineNavigations[action.sessionID] = nil } }
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
            if withdrawAuthority(for: error) { return false }
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
        if host?.isDemoMode == true {
            clearSearch()
            acceptedSearchQuery = query; acceptedSearchSessionID = sessionID
            searchMatches = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : (timelines[sessionID]?.entries ?? []).filter {
                ($0.text ?? $0.playback?.title ?? "").localizedCaseInsensitiveContains(query) && $0.isRetained()
            }
            searchComplete = true; searchTotal = searchMatches.count
            return
        }
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
            guard !Task.isCancelled, !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
            guard captured == epoch, generation == searchGeneration, !Task.isCancelled else { return }
            if withdrawAuthority(for: error) { return }
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
        if host?.isDemoMode == true { host?.sendAskDJText(); return }
        guard profileScopeActive, let host, host.canUseProfileConversation, !host.isSendingAskDJText else { return }
        guard let capturedOwner = ownerScope else { host.failProfileConversationText(id: nil, errorKey: "ui.session.history.unavailable"); return }
        let text = host.askDJDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let id = UUID().uuidString
        let localID = host.beginProfileConversationText(text: text, clientMessageID: id)
        let context = currentContext()
        let turn = PendingTurn(id: id, text: text, context: context, localMessageID: localID,
            payload: host.profileConversationPayload(text: text, clientMessageID: id, context: context), requestEpoch: epoch, ownerScope: capturedOwner)
        pendingTurns.append(turn)
        Task { await submit(turn) }
    }

    public func retry(_ turn: PendingTurn) {
        guard turn.failed, !turn.contextChanged, let host, host.canUseProfileConversation, !host.isSendingAskDJText,
              turn.requestEpoch == epoch, ownerScope == turn.ownerScope, pendingTurns.contains(where: { $0.id == turn.id }) else { return }
        pendingTurns.removeAll { $0.id == turn.id }; pendingTurns.append(PendingTurn(
            id: turn.id, text: turn.text, context: turn.context, localMessageID: turn.localMessageID, payload: turn.payload,
            requestEpoch: turn.requestEpoch, ownerScope: turn.ownerScope))
        host.setProfileConversationSending(true)
        Task { await submit(turn) }
    }

    public func useCurrentContext(_ turn: PendingTurn) {
        guard let host else { return }
        pendingTurns.removeAll { $0.id == turn.id }; selectedEntry = nil
        host.askDJDraft = turn.text
    }

    private func submit(_ turn: PendingTurn) async {
        guard let host, turn.requestEpoch == epoch, ownerScope == turn.ownerScope,
              pendingTurns.contains(where: { $0.id == turn.id }) else { return }
        guard host.canUseProfileConversation else {
            if let index = pendingTurns.firstIndex(where: { $0.id == turn.id }) {
                pendingTurns[index].failed = true
            }
            host.failProfileConversationText(id: turn.localMessageID, errorKey: "ui.session.history.unavailable")
            return
        }
        let captured = turn.requestEpoch
        do {
            let payload = turn.payload
            let response = try await host.withHomeAssistantClient { try await $0.sendSessionConversation(payload) }
            guard captured == epoch, ownerScope == turn.ownerScope, host.canUseProfileConversation,
                  pendingTurns.contains(where: { $0.id == turn.id }) else { return }
            try await accept(response, fallback: turn.localMessageID)
            pendingTurns.removeAll { $0.id == turn.id }
        } catch {
            guard captured == epoch, ownerScope == turn.ownerScope,
                  pendingTurns.contains(where: { $0.id == turn.id }) else { return }
            if withdrawAuthority(for: error) { return }
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
        do {
            defer { if voiceClientID == id { cancelVoiceContext() } }
            let response = try await host.withHomeAssistantClient {
                try await $0.sendSessionVoice(wavData: data, context: context, clientMessageID: id, language: payload.language ?? "en",
                                              mood: payload.mood, djStyle: payload.djStyle, musicDNAKey: payload.musicDNAKey)
            }
            guard captured == epoch else { throw CancellationError() }
            try await accept(response, fallback: nil)
        } catch {
            if captured == epoch { _ = withdrawAuthority(for: error) }
            throw error
        }
    }

    public func clearExistingHistory() async throws {
        guard profileScopeActive, let host, host.canUseProfileConversation, let scope = ownerScope else { throw CancellationError() }
        let captured = epoch
        do {
            let response = try await host.withHomeAssistantClient { try await $0.clearProfileConversationHistory() }
            guard captured == epoch, ownerScope == scope, response.ownerScope == scope else { throw CancellationError() }
            guard response.base.isClearAcknowledged else { throw DJConnectError.invalidResponse }
            suspend(); ownerScope = scope
            host.applyConfirmedProfileConversationClear(response.base)
        } catch {
            if captured == epoch { _ = withdrawAuthority(for: error) }
            throw error
        }
    }

    public func fetchExistingHistory() async throws -> DJConnectAskDJHistoryResponse {
        guard let host, host.canRefreshSessionHistory else { throw CancellationError() }
        let captured = epoch
        do {
            let response = try await host.withHomeAssistantClient { try await $0.profileConversationHistory() }
            guard captured == epoch, !response.ownerScope.isEmpty else { throw CancellationError() }
            let scope = response.ownerScope
            if ownerScope != nil && ownerScope != scope { suspend(); host.enterProfileConversationScope() }
            ownerScope = scope
            guard host.applyProfileConversationHistory(response.base) else { throw DJConnectError.server(statusCode: 409, message: nil) }
            historicalMatches = response.historicalMatches
            reconcilePending(with: response.base)
            if let sessionID = host.activeDJSession?.sessionID, timelines[sessionID] == nil {
                await loadTimeline(sessionID, window: .tail, preserveLoadedEntries: true)
            }
            return response.base
        } catch {
            if captured == epoch { _ = withdrawAuthority(for: error) }
            throw error
        }
    }

    public func sendExistingText(_ text: String, clientMessageID: String) async throws -> DJConnectAskDJMessageResponse {
        guard let host, host.canUseProfileConversation, ownerScope != nil else { throw CancellationError() }
        let captured = epoch
        do {
            let payload = host.profileConversationPayload(text: text, clientMessageID: clientMessageID, context: currentContext())
            let response = try await host.withHomeAssistantClient { try await $0.sendSessionConversation(payload) }
            guard captured == epoch else { throw CancellationError() }
            try await accept(response, fallback: nil, apply: false)
            return response.base
        } catch {
            if captured == epoch { _ = withdrawAuthority(for: error) }
            throw error
        }
    }

    private func accept(_ response: DJConnectSessionConversationResponse, fallback: UUID?, apply: Bool = true) async throws {
        guard let host, ownerScope == response.ownerScope else {
            suspend(); await refreshConversation(); throw DJConnectError.invalidResponse
        }
        if apply && !host.applyProfileConversationResponse(response.base, fallback: fallback) {
            throw DJConnectError.server(statusCode: 409, message: nil)
        }
        let acceptedEpoch = epoch
        retainLiveResponse(response)
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
    @discardableResult func withdrawAuthority(for error: Error) -> Bool {
        guard (error as? DJConnectError)?.invalidatesSessionAuthority == true else { return false }
        suspend()
        host?.revokeProfileConversationAuthority()
        listErrorKey = "ui.session.history.unavailable"
        navigationErrorKey = "ui.session.history.unavailable"
        return true
    }

    public func restoreVisibleSessions() async {
        await prepare()
        await loadSessions()
    }

    public func restoreVisibleTimeline(_ sessionID: String, active: Bool, anchor: String?) async {
        await prepare()
        guard hasAuthorizedOwner || host?.isDemoMode == true, !Task.isCancelled else { return }
        if let anchor, !["current", "tail"].contains(anchor), !anchor.hasPrefix("pending-") {
            await loadTimeline(sessionID, window: .anchor, anchorEntryID: anchor)
            if timelines[sessionID]?.entries.contains(where: { $0.id == anchor && $0.isRetained() }) == true { return }
        }
        await loadTimeline(sessionID, window: .tail)
    }
    private func errorKey(_ error: Error) -> String {
        isConflict(error) ? "ui.session.history.changed" : "ui.session.history.unavailable"
    }
}

/// Curated App Store review data. Only constructed after explicit Demo Mode activation.
/// This does not mint server authority, contact providers or persist personal history.
struct DJConnectDemoSessionData {
    let active: DJConnectSessionRuntime
    let sessions: [DJConnectSavedSession]
    let timelines: [String: DJConnectSessionHistoryModel.Timeline]

    private static func decode<T: Decodable>(_ object: [String: Any], as: T.Type = T.self) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
    }
    private static func stamp(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
    static func saved(id: String, start: Date, end: Date?) throws -> DJConnectSavedSession {
        try decode(["session_id": id, "lifecycle_status": end == nil ? "ACTIVE" : "ENDED", "created_at": stamp(start),
                    "started_at": stamp(start), "ended_at": end.map(stamp) ?? "", "interrupted_at": "",
                    "revision": "demo-1", "read_only": end != nil, "history_coverage": "retained_entries_only"])
    }
    private static func entry(_ id: String, order: Int, kind: String, at: Date, values: [String: Any]) throws -> DJConnectHistoryEntry {
        var object: [String: Any] = ["entry_id": id + "-entry-" + String(order), "session_id": id, "order": order,
            "kind": kind, "occurred_at": stamp(at), "retained_until": stamp(at.addingTimeInterval(365 * 86400)),
            "historical_view_only": true, "current_display_allowed": false]
        object.merge(values) { _, new in new }
        return try decode(object)
    }
    static func observed(id: String, order: Int, title: String, artist: String, at: Date) throws -> DJConnectHistoryEntry {
        try entry(id, order: order, kind: "playback_observed", at: at, values: ["text": title + " · " + artist,
            "playback": ["title": title, "artist": artist, "provider": "Demo", "coverage": "observed_playing_not_full_listen"]])
    }
    static func turn(sessionID id: String, order: Int, question: String, answer: String, inputType: String,
                     selected: DJConnectSessionEntryReference? = nil, at: Date) throws -> [DJConnectHistoryEntry] {
        var context: [String: Any] = ["session_id": id]
        if let selected { context["selected_entry"] = ["session_id": selected.sessionID, "entry_id": selected.entryID] }
        let turn = UUID().uuidString
        var common: [String: Any] = ["turn_id": "demo-turn-" + turn, "client_message_id": "demo-request-" + turn,
                                    "input_type": inputType, "context": context]
        common["role"] = "user"; common["text"] = question; common["origin_message_id"] = "demo-user-" + turn
        let user = try entry(id, order: order, kind: "conversation_user", at: at, values: common)
        common["role"] = "assistant"; common["text"] = answer; common["origin_message_id"] = "demo-dj-" + turn
        return [user, try entry(id, order: order + 1, kind: "conversation_dj", at: at.addingTimeInterval(1), values: common)]
    }
    static func make(language: String, mood: String = "groove", now: Date = Date()) throws -> Self {
        let selectedMood = ["chill", "groove", "energy", "party"].contains(mood) ? mood : "groove"
        func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
        let id = "demo-active-" + UUID().uuidString
        let start = now.addingTimeInterval(-1200)
        let expiry = stamp(now.addingTimeInterval(86400))
        let momentID = id + "-direction"
        let moment: [String: Any] = ["moment_id": momentID, "session_id": id, "type": "session", "created_at": stamp(now),
            "title": text("demo.session.title"), "summary": text("demo.session.direction"), "content": text("demo.session.direction"),
            "playback_item_id": "demo-0", "source_references": ["session_direction"],
            "knowledge_intent": ["type": "session_direction"], "generation_metadata": ["context_source": "session_direction", "validated": "true"],
            "presentation_intent": ["visibility": "owner_only", "dj_persona": "home_dj", "source_session_mood": selectedMood]]
        let broadcast: [String: Any] = ["session": ["session_id": id, "runtime_state": "active", "selected_mood": selectedMood, "mood_revision": 0],
            "planner": ["planning_state": "ready", "planning_horizon_minutes": 15, "current_direction": "maintaining_energy"],
            "session_flow": ["flow_id": id + "-flow", "planning_horizon_minutes": 15, "created_at": stamp(start), "items": []],
            "playback": ["state": "playing", "item_id": "demo-0", "title": "Midnight City", "artist": "M83",
                         "album": "Hurry Up, We're Dreaming", "duration_ms": 244000, "position_ms": 48000, "updated_at": stamp(now)],
            "dj_moments": [moment], "presentations": [],
            "native_delivery": ["schema_version": 1, "session_id": id, "revision": "demo-1", "current_moment_id": momentID,
                "active_flow_moment_ids": [], "revocation_scope": "session", "admissions": [["moment_id": momentID, "qualification": "qualified",
                    "current_display_allowed": true, "active_flow_display_allowed": false, "source_expires_at": NSNull(),
                    "display_expires_at": expiry, "executable_actions": [], "requires_spotify_attribution": false]]]]
        let runtime: DJConnectSessionRuntime = try decode(["session_id": id, "room": "", "selected_mood": selectedMood, "mood_revision": 0,
            "music_backend": "demo", "runtime_state": "active", "started_at": stamp(start),
            "planner": ["planning_horizon_minutes": 15], "broadcast": broadcast])
        var timelines: [String: DJConnectSessionHistoryModel.Timeline] = [:]
        var sessions: [DJConnectSavedSession] = []
        let examples: [(String, Date, Date?, String, String)] = [
            (id, start, nil, "Midnight City", "M83"),
            ("demo-evening", now.addingTimeInterval(-86400 - 4200), now.addingTimeInterval(-86400), "Electric Feel", "MGMT"),
            ("demo-morning", now.addingTimeInterval(-172800 - 1800), now.addingTimeInterval(-172800), "Sweet Disposition", "The Temper Trap")]
        for (sessionID, began, ended, track, artist) in examples {
            let summary = try saved(id: sessionID, start: began, end: ended)
            if ended != nil { sessions.append(summary) }
            let playback = try entry(sessionID, order: 1, kind: "playback_observed", at: began, values: [
                "text": track + " · " + artist, "playback": ["title": track, "artist": artist, "provider": "Demo",
                    "coverage": "observed_playing_not_full_listen"]])
            let direction = try entry(sessionID, order: 2, kind: "dj_moment", at: began.addingTimeInterval(60), values: [
                "text": text(ended == nil ? "demo.session.direction" : "demo.session.archive_direction"),
                "moment_id": sessionID + "-example-direction", "moment_type": "session", "persona": "home_dj",
                "archive_basis": "runtime_authored_direction_v1"])
            let typed = try turn(sessionID: sessionID, order: 3, question: text("demo.session.question"),
                                 answer: text("demo.session.answer"), inputType: "text", selected: direction.reference, at: began.addingTimeInterval(120))
            let voice = try turn(sessionID: sessionID, order: 5, question: text("demo.session.voice_question"),
                                 answer: text("demo.session.voice_answer"), inputType: "voice", at: began.addingTimeInterval(240))
            timelines[sessionID] = .init(session: summary, entries: [playback, direction] + typed + voice, revision: "demo-1")
        }
        return .init(active: runtime, sessions: sessions, timelines: timelines)
    }
}
