import Foundation
import Combine
import DJConnectCore

/// In-memory presentation state, owned by the existing Apple application model.
/// Entry identity, ordering, rights, search and conversation context remain Core-owned.
@MainActor
public final class DJConnectSessionHistoryModel: ObservableObject {
    /// Ephemeral UI memory: a started Session must not regain its first-play helper.
    @Published private(set) var sessionsWithObservedPlayback: Set<String> = []

    func rememberObservedPlayback(sessionID: String) {
        guard !sessionsWithObservedPlayback.contains(sessionID) else { return }
        sessionsWithObservedPlayback.insert(sessionID)
    }

    func hasPlaybackForFirstPlayHelper(_ session: DJConnectSessionRuntime) -> Bool {
        let playback = session.broadcast.playback
        return sessionsWithObservedPlayback.contains(session.id)
            || playback?.itemID?.isEmpty == false || playback?.title?.isEmpty == false
            || playback?.state == "playing" || playback?.state == "paused"
            || timelines[session.id]?.entries.contains { $0.kind == .playbackObserved } == true
    }
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
        public var createdAt = Date()
        public var failed = false
        public var contextChanged = false
        public var failureKey: String?

        func questionMessage(in messages: [DJConnectAskDJMessage]) -> DJConnectAskDJMessage {
            if let original = messages.first(where: { $0.id == localMessageID && $0.role == .user }) { return original }
            return .init(id: localMessageID ?? UUID(uuidString: id) ?? UUID(), clientMessageID: id,
                role: .user, text: text, status: failed ? .failed : .sending, createdAt: createdAt)
        }
    }

    @Published public private(set) var artworkAvailable = false
    @Published public private(set) var artworkPreparing: Set<DJConnectSessionEntryReference> = []
    @Published public private(set) var artworkFailed: Set<DJConnectSessionEntryReference> = []
    private var artworkQueue: [DJConnectSessionEntryReference] = []
    private var artworkQueueTask: Task<Void, Never>?
    private var artworkQueueGeneration = UUID()
    private var artworkAttempts: [DJConnectSessionEntryReference: Date] = [:]

    public func cancelArtworkQueue() {
        artworkQueueGeneration = UUID()
        artworkQueueTask?.cancel(); artworkQueueTask = nil
        artworkQueue = []; artworkAttempts = [:]
    }

    /// Visible rows first; one neighboring media contribution on either side.
    /// Never scans/prepares the whole loaded history or performs a provider lookup.
    static func artworkWindow(entries: [DJConnectHistoryEntry], visibleIDs: Set<String>, at now: Date = Date()) -> [DJConnectSessionEntryReference] {
        guard !visibleIDs.isEmpty else { return [] }
        // Identify visible positions before parsing rights/retention. Offscreen
        // history must not be revalidated in full on every visibility callback.
        let rows = entries
        let visible = rows.indices.filter { visibleIDs.contains(rows[$0].id) && rows[$0].isRetained(at: now) }
        guard let first = visible.first, let last = visible.last else { return [] }
        let eligible: (DJConnectHistoryEntry) -> Bool = { [.playbackObserved, .djMoment].contains($0.kind) && $0.isRetained(at: now) }
        var indices = visible.filter { eligible(rows[$0]) }
        if let before = rows.indices.prefix(first).last(where: { eligible(rows[$0]) }) { indices.append(before) }
        if let after = rows.indices.dropFirst(last + 1).first(where: { eligible(rows[$0]) }) { indices.append(after) }
        return indices.map { rows[$0].reference }
    }

    public func prefetchArtwork(sessionID: String, visibleIDs: Set<String>) {
        guard artworkAvailable, host?.canRefreshSessionHistory == true,
              let rows = timelines[sessionID]?.entries else { return }
        artworkQueue = Self.artworkWindow(entries: rows, visibleIDs: visibleIDs)
        guard artworkQueueTask == nil, !artworkQueue.isEmpty else { return }
        let captured = epoch
        let generation = artworkQueueGeneration
        artworkQueueTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if captured == epoch, generation == artworkQueueGeneration { artworkQueueTask = nil } }
            while captured == epoch, generation == artworkQueueGeneration, !Task.isCancelled, !artworkQueue.isEmpty {
                let ref = artworkQueue.removeFirst()
                guard let row = timelines[ref.sessionID]?.entries.first(where: { $0.reference == ref }),
                      row.isRetained(), !artworkPreparing.contains(ref) else { continue }
                let now = Date()
                if let media = row.sessionMedia {
                    let audience: DJConnectSessionMedia.Audience = media.artwork.historicalDisplayAllowed ? .history : .activeFlow
                    if media.admittedArtwork(session: ref.sessionID, target: .entry(ref.entryID), audience: audience, at: now) != nil { continue }
                }
                guard artworkAttempts[ref].map({ now.timeIntervalSince($0) >= 30 }) ?? true else { continue }
                artworkAttempts = artworkAttempts.filter { now.timeIntervalSince($0.value) < 30 }
                artworkAttempts[ref] = now
                await refreshArtwork(for: row)
            }
        }
    }

    @Published public private(set) var available = false
    @Published public private(set) var summaryAvailable = false
    @Published public private(set) var bulkDeletionAvailable = false
    @Published public private(set) var bulkDeletionBusy = false
    private var archiveGeneration = UUID()
    @Published public private(set) var archiveResponseEpoch = UUID()
    @Published public private(set) var deletionAvailable = false
    @Published public private(set) var deletingSessionID: String?
    private var deletionGeneration = UUID()
    @Published public private(set) var preparing = false
    @Published public private(set) var searchAvailable = false
    @Published public private(set) var momentInsightAvailable = false
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
        let deadline: Date?
        let message: DJConnectAskDJMessage
    }
    @Published private var liveResponses: [String: LiveResponse] = [:]
    private weak var host: DJConnectAppModel?
    public private(set) var historyContractVersion = 1
    @Published public private(set) var historyNeedsUpgrade = false
    private var epoch = UUID()
    @Published private var ownerScope: String? {
        didSet { if ownerScope != oldValue { host?.activeVoiceOwnerDidChange() } }
    }
    var authorizedProfileID: String? { ownerScope }
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

    func discardLiveResponses() {
        liveResponses = [:]
        host?.withdrawLiveConversationPresentations()
        host?.invalidateConversationResultLeases()
    }

    /// Only a directly accepted response supplies live actions; history reads never do.
    func retainLiveResponse(_ response: DJConnectSessionConversationResponse) {
        guard let host, ownerScope == response.ownerScope,
              let sessionID = response.conversation.context.sessionID,
              host.activeDJSession?.id == sessionID,
              let assistant = response.base.assistantMessage, assistant.role == .assistant,
              assistant.messageKind != .system else { return }
        liveResponses = [:]
        liveResponses[assistant.id] = LiveResponse(sessionID: sessionID,
            deadline: host.resolveConversationPresentationDeadline(response.base), message: host.sessionResponseMessage(assistant))
    }

    func liveMessage(for entry: DJConnectHistoryEntry, activeSessionID: String?) -> DJConnectAskDJMessage? {
        guard let host, host.canRefreshSessionHistory, ownerScope != nil,
              let activeSessionID, activeSessionID == host.activeDJSession?.id,
              entry.sessionID == activeSessionID, entry.kind == .conversationDJ,
              entry.isContractValid, entry.isRetained(),
              let origin = entry.originMessageID, let live = liveResponses[origin],
              live.sessionID == activeSessionID, live.deadline.map({ $0 > Date() }) ?? true,
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
            selectedEntry = nil
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
        var captured = epoch
        do {
            let caps = try await host.withHomeAssistantClient { try await $0.sessionHistoryCapabilities() }
            guard captured == epoch, host.canRefreshSessionHistory, !Task.isCancelled else { return }
            if historyContractVersion != caps.historyContractVersion {
                // A cursor and its cached projection cannot cross representations.
                suspend(preservingVoicePreference: true, cancelPreparation: false)
                historyContractVersion = caps.historyContractVersion
                historyNeedsUpgrade = false
                captured = epoch
            }
            artworkAvailable = caps.artworkAvailable
            summaryAvailable = caps.summaryAvailable
            deletionAvailable = caps.deletionAvailable
            bulkDeletionAvailable = caps.bulkDeletionAvailable
            available = caps.available; searchAvailable = caps.searchAvailable; momentInsightAvailable = caps.momentInsightAvailable
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
        summaryAvailable = false
        deletionAvailable = false; bulkDeletionAvailable = false; bulkDeletionBusy = false; archiveGeneration = UUID(); archiveResponseEpoch = archiveGeneration; deletingSessionID = nil; deletionGeneration = UUID()
        historyContractVersion = 1
        historyNeedsUpgrade = false
        sessionsWithObservedPlayback = []
        host?.discardActiveVoicePreference()
        host?.invalidateSessionPlaybackActions()
        host?.withdrawLiveConversationPresentations()
        host?.invalidateConversationResultLeases()
        host?.dismissMomentTrackInsight()
        preparationTask?.cancel(); preparationTask = nil; preparationID = UUID(); preparing = false
        liveResponses = [:]
        cancelArtworkQueue()
        artworkAvailable = false; artworkPreparing = []; artworkFailed = []
        epoch = UUID(); searchGeneration = UUID(); listGeneration = UUID(); navigationGeneration = UUID()
        searchTask?.cancel(); searchTask = nil
        available = false; searchAvailable = false; momentInsightAvailable = false; profileScopeActive = false; ownerScope = nil
        sessions = []; timelines = [:]; historicalMatches = [:]; pendingTurns = []; readingAnchors = [:]
        host?.setProfileConversationSending(false)
        selectedEntry = nil; openTarget = nil; voiceContext = nil; voiceClientID = nil; voicePayload = nil
        listNextCursor = nil; listRevision = nil; listLoading = false; listErrorKey = nil
        clearSearch(); navigationErrorKey = nil; timelineGenerations = [:]; timelineNavigations = [:]
    }

    public func suspend(preservingVoicePreference: Bool = false, cancelPreparation: Bool = true) {
        summaryAvailable = false
        deletionAvailable = false; bulkDeletionAvailable = false; bulkDeletionBusy = false; archiveGeneration = UUID(); archiveResponseEpoch = archiveGeneration; deletingSessionID = nil; deletionGeneration = UUID()
        if preservingVoicePreference { host?.invalidateActiveVoiceInventory() }
        else { host?.discardActiveVoicePreference() }
        host?.invalidateSessionPlaybackActions()
        host?.withdrawLiveConversationPresentations()
        host?.invalidateConversationResultLeases()
        host?.dismissMomentTrackInsight()
        if cancelPreparation {
            preparationTask?.cancel(); preparationTask = nil; preparationID = UUID(); preparing = false
        }
        liveResponses = [:]
        cancelArtworkQueue()
        artworkAvailable = false; artworkPreparing = []; artworkFailed = []
        epoch = UUID(); ownerScope = nil
        listGeneration = UUID(); timelineGenerations = [:]; timelineNavigations = [:]; navigationGeneration = UUID()
        listLoading = false; listNextCursor = nil; listRevision = nil
        searchTask?.cancel(); searchTask = nil
        timelines = [:]; sessions = []; historicalMatches = [:]; searchMatches = []; readingAnchors = [:]
        selectedEntry = nil; openTarget = nil; voiceContext = nil; voiceClientID = nil; voicePayload = nil
        clearSearch()
        pendingTurns = []; host?.setProfileConversationSending(false)
    }

    /// An admitted clear changes content/epoch, not the authenticated Profile.
    /// Authority errors and lifecycle changes still use suspend() directly.
    func invalidateClearedConversation() {
        let admittedOwner = ownerScope
        suspend()
        ownerScope = admittedOwner
    }

    public var canPrepareBulkDeletion: Bool {
        bulkDeletionAvailable && !bulkDeletionBusy && deletingSessionID == nil && !historyNeedsUpgrade
            && ownerScope != nil && host?.canRefreshSessionHistory == true
    }

    public func prepareBulkDeletion(expectedEpoch: UUID) async -> DJConnectSessionDeleteSnapshot? {
        guard expectedEpoch == epoch, canPrepareBulkDeletion, let host, let ownerScope else { return nil }
        bulkDeletionBusy = true
        defer { if expectedEpoch == epoch { bulkDeletionBusy = false } }
        do {
            let snapshot = try await host.withHomeAssistantClient {
                try await $0.prepareSavedSessionsDeletion(expectedOwner: ownerScope)
            }
            guard expectedEpoch == epoch, self.ownerScope == ownerScope, host.canRefreshSessionHistory,
                  snapshot.admits(owner: ownerScope), !Task.isCancelled else { return nil }
            if snapshot.targetCount == 0 { await loadSessions() }
            return snapshot
        } catch {
            if expectedEpoch == epoch { _ = withdrawAuthority(for: error) }
            return nil
        }
    }

    @discardableResult public func deleteAllSessions(_ snapshot: DJConnectSessionDeleteSnapshot, expectedEpoch: UUID) async -> Bool {
        guard expectedEpoch == epoch, canPrepareBulkDeletion, let host, let ownerScope,
              snapshot.admits(owner: ownerScope), snapshot.targetCount > 0 else { return false }
        bulkDeletionBusy = true
        defer { if expectedEpoch == epoch { bulkDeletionBusy = false } }
        let operationID = DJConnectOperationIdentity.uuidV7(milliseconds: Int(Date().timeIntervalSince1970 * 1000))
        do {
            let receipt = try await host.withHomeAssistantClient(allowsOperationReplay: false) {
                try await $0.deleteAllSavedSessions(snapshot: snapshot, expectedOwner: ownerScope, operationID: operationID)
            }
            guard expectedEpoch == epoch, self.ownerScope == ownerScope, host.canRefreshSessionHistory,
                  receipt.admits(snapshot: snapshot, operationID: operationID, owner: ownerScope), !Task.isCancelled else { return false }
            invalidateArchiveProjections()
            return true
        } catch {
            if expectedEpoch == epoch { _ = withdrawAuthority(for: error) }
            return false
        }
    }

    private func invalidateArchiveProjections() {
        let activeID = host?.activeDJSession?.id
        var archives = Set(sessions.filter { $0.readOnly }.map(\.id))
        archives.formUnion(timelines.keys.filter { $0 != activeID })
        archives.formUnion(historicalMatches.values.flatMap { $0 }.filter { $0.sessionID != activeID }.map(\.sessionID))
        archives.formUnion(searchMatches.filter { $0.sessionID != activeID }.map(\.sessionID))
        for id in archives {
            let entries = (timelines[id]?.entries ?? []) + historicalMatches.values.flatMap { $0.filter { $0.sessionID == id } }
                + searchMatches.filter { $0.sessionID == id }
            host?.withdrawDeletedSessionPresentation(id, entries: entries, invalidatingAllLeases: false)
        }
        archiveGeneration = UUID(); archiveResponseEpoch = archiveGeneration; listGeneration = UUID(); listLoading = false; listNextCursor = nil; listRevision = nil
        sessions.removeAll { $0.readOnly }
        timelines = timelines.filter { $0.key == activeID }
        timelineGenerations = timelineGenerations.filter { $0.key == activeID }
        timelineNavigations = timelineNavigations.filter { $0.key == activeID }
        if !timelineNavigations.values.contains(navigationGeneration) { navigationGeneration = UUID() }
        readingAnchors = readingAnchors.filter { $0.key == activeID }
        historicalMatches = historicalMatches.mapValues { $0.filter { $0.sessionID == activeID } }
        artworkQueue = artworkQueue.filter { $0.sessionID == activeID }
        artworkPreparing = artworkPreparing.filter { $0.sessionID == activeID }
        artworkFailed = artworkFailed.filter { $0.sessionID == activeID }
        if selectedEntry?.sessionID != activeID { selectedEntry = nil }
        if openTarget?.sessionID != activeID { openTarget = nil }
        if acceptedSearchSessionID != activeID { clearSearch() }
        let captured = epoch, archiveToken = archiveGeneration
        Task { @MainActor [weak self] in
            guard let self, self.epoch == captured, self.archiveGeneration == archiveToken else { return }
            await self.loadSessions()
            guard self.epoch == captured, self.archiveGeneration == archiveToken else { return }
            await self.refreshConversation()
        }
    }

    public func canDeleteSession(_ sessionID: String) -> Bool {
        guard deletionAvailable, !bulkDeletionBusy, !historyNeedsUpgrade, ownerScope != nil, let host,
              host.canRefreshSessionHistory, host.activeDJSession?.id != sessionID,
              let session = timelines[sessionID]?.session ?? sessions.first(where: { $0.id == sessionID }) else { return false }
        return session.isContractValid && session.readOnly && ["ENDED", "INTERRUPTED"].contains(session.lifecycleStatus)
    }

    @discardableResult public func deleteSession(_ sessionID: String, expectedRevision: String, expectedEpoch: UUID) async -> Bool {
        guard expectedEpoch == epoch, deletingSessionID == nil, canDeleteSession(sessionID), let host, let ownerScope,
              let session = timelines[sessionID]?.session ?? sessions.first(where: { $0.id == sessionID }),
              session.revision.value == expectedRevision else { return false }
        let generation = UUID(); deletionGeneration = generation; deletingSessionID = sessionID
        defer { if deletionGeneration == generation { deletingSessionID = nil } }
        let action = DJConnectSessionDeleteRequest(sessionID: sessionID, expectedRevision: expectedRevision)
        do {
            let receipt = try await host.withHomeAssistantClient(allowsOperationReplay: false) {
                try await $0.deleteSavedSession(action, expectedOwner: ownerScope)
            }
            guard expectedEpoch == epoch, generation == deletionGeneration, self.ownerScope == ownerScope,
                  host.canRefreshSessionHistory, host.activeDJSession?.id != sessionID,
                  receipt.admits(action, owner: ownerScope), !Task.isCancelled else { return false }
            invalidateDeletedSessions([sessionID])
            return true
        } catch {
            guard expectedEpoch == epoch, generation == deletionGeneration else { return false }
            if withdrawAuthority(for: error) { return false }
            // No automatic mutation retry, including ambiguous delivery outcomes.
            return false
        }
    }

    private func invalidateDeletedSessions(_ sessionIDs: Set<String>) {
        for sessionID in sessionIDs {
            let removed = (timelines[sessionID]?.entries ?? []) + searchMatches.filter { $0.sessionID == sessionID }
                + historicalMatches.values.flatMap { $0.filter { $0.sessionID == sessionID } }
            host?.withdrawDeletedSessionPresentation(sessionID, entries: removed)
        }
        // Reject already-running reads/prepares, preserving other confirmed projections.
        epoch = UUID(); listGeneration = UUID(); navigationGeneration = UUID(); timelineGenerations = [:]; timelineNavigations = [:]
        cancelArtworkQueue()
        listLoading = false; listNextCursor = nil; listRevision = nil
        sessions.removeAll { sessionIDs.contains($0.id) }
        for sessionID in sessionIDs { timelines[sessionID] = nil; readingAnchors[sessionID] = nil }
        for id in Array(timelines.keys) { timelines[id]?.loading = false }
        historicalMatches = historicalMatches.mapValues { $0.filter { !sessionIDs.contains($0.sessionID) } }
        if let selectedEntry, sessionIDs.contains(selectedEntry.sessionID) { self.selectedEntry = nil }
        if let openTarget, sessionIDs.contains(openTarget.sessionID) { self.openTarget = nil }
        clearSearch()
        let refreshedEpoch = epoch
        Task { @MainActor [weak self] in
            guard let self, self.epoch == refreshedEpoch else { return }
            await self.loadSessions()
            guard self.epoch == refreshedEpoch else { return }
            await self.refreshConversation()
        }
    }

    @discardableResult
    public func refreshConversation() async -> Bool {
        guard profileScopeActive, let host, host.canRefreshSessionHistory else { return false }
        let captured = epoch, archives = archiveGeneration
        do {
            let response = try await host.withHomeAssistantClient { try await $0.profileConversationHistory() }
            guard captured == epoch, archives == archiveGeneration, !response.ownerScope.isEmpty else { return false }
            let scope = response.ownerScope
            if let ownerScope, ownerScope != scope {
                suspend(); host.enterProfileConversationScope()
            }
            ownerScope = scope
            guard host.applyProfileConversationHistory(response.base) else { return false }
            historicalMatches = response.historicalMatches
            reconcilePending(with: response.base)
            return true
        } catch {
            guard !Task.isCancelled, !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return false }
            guard captured == epoch else { return false }
            // A transient history read must not erase a confirmed conversation
            // or its still-valid presentation. Explicit authority errors revoke it.
            _ = withdrawAuthority(for: error)
        }
        return false
    }

    /// Exact-entry preparation, coordinated separately from pure history reads.
    /// Viewport loading and prefetch share the same owner/retention fences.
    public func refreshArtwork(for original: DJConnectHistoryEntry) async {
        let ref = original.reference
        guard artworkAvailable, let host, host.canRefreshSessionHistory,
              [.playbackObserved, .djMoment].contains(original.kind), original.isRetained(),
              artworkPreparing.count < 2, !artworkPreparing.contains(ref),
              timelines[ref.sessionID]?.entries.contains(original) == true else { return }
        let captured = epoch
        artworkPreparing.insert(ref); artworkFailed.remove(ref)
        defer { if captured == epoch { artworkPreparing.remove(ref) } }
        do {
            let response = try await host.withHomeAssistantClient(allowsOperationReplay: false) {
                try await $0.prepareSessionArtwork(sessionID: ref.sessionID, targets: [.entry(ref.entryID)])
            }
            guard captured == epoch, host.canRefreshSessionHistory, !Task.isCancelled,
                  timelines[ref.sessionID]?.entries.contains(original) == true, original.isRetained() else { return }
            guard let media = response.first(where: { $0.target == .entry(ref.entryID) }) else {
                artworkFailed.insert(ref); return
            }
            func patch(_ rows: [DJConnectHistoryEntry]) -> [DJConnectHistoryEntry] {
                rows.map { row in
                    guard row.reference == ref else { return row }
                    var copy = row; copy.sessionMedia = media; return copy
                }
            }
            if var timeline = timelines[ref.sessionID] {
                timeline.entries = patch(timeline.entries); timelines[ref.sessionID] = timeline
            }
            historicalMatches = historicalMatches.mapValues(patch)
            searchMatches = patch(searchMatches)
            let audience: DJConnectSessionMedia.Audience = media.artwork.historicalDisplayAllowed ? .history : .activeFlow
            if media.admittedArtwork(session: ref.sessionID, target: .entry(ref.entryID), audience: audience) == nil {
                artworkFailed.insert(ref)
            }
        } catch {
            guard captured == epoch, !Task.isCancelled, host.canRefreshSessionHistory,
                  timelines[ref.sessionID]?.entries.contains(original) == true else { return }
            // Failed revalidation must not leave the old image shown.
            // Clear only this still-matching target; preserve text and any newer grant.
            func clear(_ rows: [DJConnectHistoryEntry]) -> [DJConnectHistoryEntry] {
                rows.map { row in
                    guard row.reference == ref else { return row }
                    var copy = row; copy.sessionMedia = nil; return copy
                }
            }
            if var timeline = timelines[ref.sessionID] {
                timeline.entries = clear(timeline.entries); timelines[ref.sessionID] = timeline
            }
            historicalMatches = historicalMatches.mapValues(clear)
            searchMatches = clear(searchMatches)
            artworkFailed.insert(ref)
        }
    }

    @discardableResult
    public func loadNextSessionsPage(expectedCursor: String) async -> Bool {
        // A disappearing/replaced footer must not consume a newer page, and a
        // failed page must not become an automatic retry loop on view updates.
        guard listNextCursor == expectedCursor, listErrorKey == nil else { return false }
        return await loadSessions(more: true)
    }

    @discardableResult
    public func loadSessions(more: Bool = false) async -> Bool {
        if host?.isDemoMode == true { return available }
        guard available, !historyNeedsUpgrade, !(more && listLoading), let host, host.canRefreshSessionHistory else { return false }
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
            guard cursor == nil || page.nextCursor != cursor else { throw DJConnectError.invalidResponse }
            let old = cursor == nil ? [] : sessions
            sessions = mergeSessions(old, page.sessions.filter { $0.readOnly })
            listRevision = page.revision.value; listNextCursor = page.nextCursor
            return true
        } catch {
            guard !Task.isCancelled, !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return false }
            guard captured == epoch, generation == listGeneration else { return false }
            if requireHistoryUpgrade(for: error) { return false }
            if withdrawAuthority(for: error) { return false }
            // Keep the last confirmed readonly list on a transient read failure.
            // Authority withdrawal above still removes all private projections.
            listErrorKey = errorKey(error)
            return false
        }
    }

    @discardableResult
    public func loadTimeline(_ sessionID: String, more: Bool = false, window: DJConnectHistoryWindow? = nil,
                             anchorEntryID: String? = nil, limit: Int = 20, preserveLoadedEntries: Bool = false) async -> Bool {
        if host?.isDemoMode == true { return false }
        guard available, !historyNeedsUpgrade, let host, host.canRefreshSessionHistory, !(timelines[sessionID]?.loading ?? false),
              timelineNavigations[sessionID] == nil else { return false }
        let cursor = more ? timelines[sessionID]?.nextCursor : nil
        if more && cursor == nil { return false }
        let captured = epoch; let generation = UUID(); timelineGenerations[sessionID] = generation
        timelines[sessionID, default: Timeline()].loading = true
        // Starting a read is not recovery. Keep the previous failure visible
        // until success so background retries do not collapse/reinsert its row.
        defer { if timelineGenerations[sessionID] == generation { timelines[sessionID]?.loading = false } }
        do {
            let page = try await host.withHomeAssistantClient {
                try await $0.sessionTimeline(sessionID: sessionID, cursor: cursor, window: window, anchorEntryID: anchorEntryID, limit: limit)
            }
            guard captured == epoch, timelineGenerations[sessionID] == generation else { return false }
            guard cursor == nil || timelines[sessionID]?.revision == page.revision.value else { throw DJConnectError.invalidResponse }
            var previous = cursor == nil && window == nil && !preserveLoadedEntries ? [] : timelines[sessionID]?.entries ?? []
            if window != nil, let lower = page.scannedOrderMin, let upper = page.scannedOrderMax {
                previous.removeAll { $0.order >= lower && $0.order <= upper }
            }
            let entries = try mergeEntries(previous, page.entries.filter { $0.isRetained() })
            let nextCursor = window != nil && timelines[sessionID]?.revision == page.revision.value ? timelines[sessionID]?.nextCursor : page.nextCursor
            timelines[sessionID] = Timeline(session: page.session, entries: entries, nextCursor: nextCursor,
                                            revision: page.revision.value, loading: false, errorKey: nil, windowed: window != nil)
            return true
        } catch {
            guard !Task.isCancelled, !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return false }
            guard captured == epoch, timelineGenerations[sessionID] == generation else { return false }
            if requireHistoryUpgrade(for: error) {
                timelines[sessionID] = Timeline(errorKey: "ui.session.history.update_required")
                return false
            }
            if withdrawAuthority(for: error) { return false }
            // A failed read cannot revoke already confirmed retained entries.
            // Explicit owner withdrawal above still removes every private row.
            var retained = timelines[sessionID] ?? Timeline()
            retained.entries.removeAll { !$0.isRetained() }
            retained.loading = false; retained.errorKey = errorKey(error)
            timelines[sessionID] = retained
        }
        return false
    }

    /// A live journal gap is repaired from canonical retained history, not by
    /// replaying commands or assuming that a Broadcast snapshot contains history.
    @discardableResult
    func recoverContributions(_ sessionID: String) async -> Bool {
        let captured = epoch
        for attempt in 0..<3 {
            guard captured == epoch, !Task.isCancelled, host?.canRefreshSessionHistory == true else { return false }
            if attempt > 0 {
                do { try await Task.sleep(for: .milliseconds(attempt * 500)) } catch { return false }
            }
            await prepare()
            guard captured == epoch, !Task.isCancelled, hasAuthorizedOwner else { return false }
            // prepare() already refreshes the authorized conversation projection.
            await loadTimeline(sessionID, window: .tail)
            guard captured == epoch, !Task.isCancelled else { return false }
            if let timeline = timelines[sessionID], !timeline.loading, timeline.errorKey == nil,
               timeline.session != nil { return true }
        }
        return false
    }

    @discardableResult
    public func refreshVisibleTimeline(_ sessionID: String, anchor: String?) async -> Bool {
        let captured = epoch
        func waitForRead() async -> Bool {
            while timelines[sessionID]?.loading == true {
                guard captured == epoch, !Task.isCancelled else { return false }
                do { try await Task.sleep(for: .milliseconds(25)) } catch { return false }
            }
            return captured == epoch && !Task.isCancelled
        }
        guard await waitForRead() else { return false }
        var anchorSucceeded = true
        if let anchor, !["current", "tail"].contains(anchor), !anchor.hasPrefix("pending-") {
            anchorSucceeded = await loadTimeline(sessionID, window: .anchor, anchorEntryID: anchor)
        }
        guard await waitForRead() else { return false }
        let tailSucceeded = await loadTimeline(sessionID, window: .tail)
        return anchorSucceeded && tailSucceeded
    }

    /// Every known navigation target is revalidated before displaying an anchor.
    @discardableResult public func open(_ action: DJConnectSessionOpenAction, navigate: Bool = true) async -> Bool {
        if host?.isDemoMode == true {
            guard available, timelines[action.sessionID]?.entries.contains(where: { $0.reference == action.reference && $0.isRetained() }) == true else { return false }
            if navigate { openTarget = action.reference }
            return true
        }
        guard available, !historyNeedsUpgrade, let host, host.canRefreshSessionHistory else { return false }
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
            if requireHistoryUpgrade(for: error) { return false }
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
        guard searchAvailable, !historyNeedsUpgrade, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let generation = searchGeneration
        searchLoading = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            await self.loadSearch(sessionID: sessionID, query: query, cursor: nil, generation: generation)
        }
    }

    public func moreSearch(expectedCursor: String? = nil) async {
        guard !searchLoading, !searchComplete, let cursor = searchNextCursor,
              expectedCursor == nil || expectedCursor == cursor else { return }
        await loadSearch(sessionID: acceptedSearchSessionID, query: acceptedSearchQuery, cursor: cursor, generation: searchGeneration)
    }

    private func loadSearch(sessionID: String, query: String, cursor: String?, generation: UUID) async {
        guard !historyNeedsUpgrade, let host else { return }
        let captured = epoch; searchLoading = true
        defer { if generation == searchGeneration { searchLoading = false } }
        do {
            let page = try await host.withHomeAssistantClient { try await $0.searchSession(sessionID: sessionID, query: query, cursor: cursor) }
            guard captured == epoch, generation == searchGeneration, !Task.isCancelled else { return }
            guard cursor == nil || (searchRevision == page.revision.value && page.nextCursor != cursor) else { throw DJConnectError.invalidResponse }
            searchMatches = try mergeEntries(cursor == nil ? [] : searchMatches, page.matches.filter { $0.isRetained() })
            searchRevision = page.revision.value; acceptedSearchQuery = query; acceptedSearchSessionID = sessionID
            searchNextCursor = page.nextCursor; searchComplete = page.complete
            searchTotal = page.totalCount; searchErrorKey = nil
        } catch {
            guard !Task.isCancelled, !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
            guard captured == epoch, generation == searchGeneration, !Task.isCancelled else { return }
            if requireHistoryUpgrade(for: error) { return }
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
        guard let capturedOwner = ownerScope else { host.failProfileConversationText(id: nil, errorKey: "ui.ask_dj.answer.unavailable"); return }
        let text = host.askDJDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let id = UUID().uuidString
        let localID = host.beginProfileConversationText(text: text, clientMessageID: id)
        let context = currentContext()
        let turn = PendingTurn(id: id, text: text, context: context, localMessageID: localID,
            payload: host.profileConversationPayload(text: text, clientMessageID: id, context: context), requestEpoch: epoch, ownerScope: capturedOwner)
        pendingTurns.append(turn)
        selectedEntry = nil
        Task { await submit(turn) }
    }

    public func retry(_ turn: PendingTurn) {
        guard turn.failed, !turn.contextChanged, let host, host.canUseProfileConversation, !host.isSendingAskDJText,
              turn.requestEpoch == epoch, ownerScope == turn.ownerScope, pendingTurns.contains(where: { $0.id == turn.id }) else { return }
        pendingTurns.removeAll { $0.id == turn.id }; pendingTurns.append(PendingTurn(
            id: turn.id, text: turn.text, context: turn.context, localMessageID: turn.localMessageID, payload: turn.payload,
            requestEpoch: turn.requestEpoch, ownerScope: turn.ownerScope, createdAt: turn.createdAt))
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
                pendingTurns[index].failureKey = "ui.ask_dj.answer.unavailable"
            }
            host.failProfileConversationText(id: turn.localMessageID, errorKey: "ui.ask_dj.answer.unavailable")
            return
        }
        let captured = turn.requestEpoch, archives = archiveGeneration
        do {
            let payload = turn.payload
            let response = try await host.withHomeAssistantClient { try await $0.sendSessionConversation(payload) }
            guard captured == epoch, ownerScope == turn.ownerScope, host.canUseProfileConversation,
                  pendingTurns.contains(where: { $0.id == turn.id }) else { return }
            try await accept(response, fallback: turn.localMessageID, requestContext: turn.context, historicalGeneration: archives)
            pendingTurns.removeAll { $0.id == turn.id }
        } catch {
            guard captured == epoch, ownerScope == turn.ownerScope,
                  pendingTurns.contains(where: { $0.id == turn.id }) else { return }
            if withdrawAuthority(for: error) { return }
            if case DJConnectHybridTransportError.outcome(let receipt) = error, receipt.phase == "confirmed" {
                pendingTurns.removeAll { $0.id == turn.id }
                host.confirmProfileConversationText(id: turn.localMessageID)
                host.setProfileConversationSending(false)
                await refreshConversation()
                return
            }
            if let index = pendingTurns.firstIndex(where: { $0.id == turn.id }) {
                pendingTurns[index].failed = true
                pendingTurns[index].contextChanged = isConflict(error) || error is DJConnectHybridTransportError
                pendingTurns[index].failureKey = Self.conversationErrorKey(error)
            }
            host.failProfileConversationText(id: turn.localMessageID,
                errorKey: Self.conversationErrorKey(error))
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
        let captured = epoch, archives = archiveGeneration
        if selectedEntry == context.selectedEntry { selectedEntry = nil }
        do {
            defer { if voiceClientID == id { cancelVoiceContext() } }
            let response = try await host.withHomeAssistantClient {
                try await host.requireHADeviceSpeech(client: $0, language: payload.language ?? "en")
                guard !host.deviceSTTEnabled, captured == self.epoch, self.voiceClientID == id,
                      !Task.isCancelled else { throw CancellationError() }
                return try await $0.sendSessionVoice(wavData: data, context: context, clientMessageID: id, language: payload.language ?? "en",
                                              mood: payload.mood, djStyle: payload.djStyle, musicDNAKey: payload.musicDNAKey)
            }
            guard captured == epoch else { throw CancellationError() }
            try await accept(response, fallback: nil, requestContext: context, historicalGeneration: archives)
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
            invalidateClearedConversation()
            host.applyConfirmedProfileConversationClear(response.base)
        } catch {
            if captured == epoch { _ = withdrawAuthority(for: error) }
            throw error
        }
    }

    public func fetchExistingHistory() async throws -> DJConnectAskDJHistoryResponse {
        guard let host, host.canRefreshSessionHistory else { throw CancellationError() }
        let captured = epoch, archives = archiveGeneration
        do {
            let response = try await host.withHomeAssistantClient { try await $0.profileConversationHistory() }
            guard captured == epoch, archives == archiveGeneration, !response.ownerScope.isEmpty else { throw CancellationError() }
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
        let captured = epoch, archives = archiveGeneration
        do {
            let payload = host.profileConversationPayload(text: text, clientMessageID: clientMessageID, context: currentContext())
            selectedEntry = nil
            let response = try await host.withHomeAssistantClient { try await $0.sendSessionConversation(payload) }
            guard captured == epoch else { throw CancellationError() }
            try await accept(response, fallback: nil, apply: false, historicalGeneration: archives)
            return response.base
        } catch {
            if captured == epoch { _ = withdrawAuthority(for: error) }
            throw error
        }
    }

    private func accept(_ response: DJConnectSessionConversationResponse, fallback: UUID?, apply: Bool = true, requestContext: DJConnectConversationContext? = nil, historicalGeneration: UUID? = nil) async throws {
        guard let host, ownerScope == response.ownerScope else {
            suspend(); await refreshConversation(); throw DJConnectError.invalidResponse
        }
        if apply && !host.applyProfileConversationResponse(response.base, fallback: fallback, sessionID: requestContext?.sessionID ?? response.conversation.context.sessionID) {
            throw DJConnectError.server(statusCode: 409, message: nil)
        }
        let acceptedEpoch = epoch
        retainLiveResponse(response)
        host.autoplayAcceptedDJResponse(response.base)
        let matches = historicalGeneration == nil || historicalGeneration == archiveGeneration
            ? response.historicalMatches : response.historicalMatches.filter { $0.sessionID == host.activeDJSession?.id }
        for message in response.base.messages where message.role != .user { historicalMatches[message.id] = matches }
        if let id = response.base.assistantMessage?.id { historicalMatches[id] = matches }
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
        if !active, let anchor, !["current", "tail"].contains(anchor), !anchor.hasPrefix("pending-") {
            await loadTimeline(sessionID, window: .anchor, anchorEntryID: anchor)
            if timelines[sessionID]?.entries.contains(where: { $0.id == anchor && $0.isRetained() }) == true { return }
        }
        await loadTimeline(sessionID, window: .tail)
    }
    private func requireHistoryUpgrade(for error: Error) -> Bool {
        guard error is DJConnectSessionHistoryUpgradeRequired else { return false }
        suspend(preservingVoicePreference: true)
        historyNeedsUpgrade = true
        listErrorKey = "ui.session.history.update_required"
        navigationErrorKey = "ui.session.history.update_required"
        return true
    }

    private func errorKey(_ error: Error) -> String {
        isConflict(error) ? "ui.session.history.changed" : "ui.session.history.unavailable"
    }

    static func conversationErrorKey(_ error: Error) -> String {
        if let hybrid = error as? DJConnectHybridTransportError { return hybrid.localizationKey }
        if case .server(let status, _) = error as? DJConnectError, status == 409 { return "ui.ask_dj.answer.context_changed" }
        if error is URLError { return "ui.ask_dj.answer.connection" }
        if case .network = error as? DJConnectError { return "ui.ask_dj.answer.connection" }
        return "ui.ask_dj.answer.unavailable"
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
