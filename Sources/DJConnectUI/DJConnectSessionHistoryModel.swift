import Foundation
import Combine
import DJConnectCore

/// Ephemeral row positions only. Always resolve the current source row and
/// evaluate the caller's current retention/media checks; never cache admission.
struct SessionHistoryEntryIndex<Source: Hashable> {
    private struct Position {
        let source: Source
        let offset: Int
    }
    private var positions: [DJConnectSessionEntryReference: [Position]] = [:]

    init(_ sources: [Source: [DJConnectHistoryEntry]]) {
        for (source, rows) in sources {
            for (offset, row) in rows.enumerated() {
                positions[row.reference, default: []].append(.init(source: source, offset: offset))
            }
        }
    }

    func contains(_ reference: DJConnectSessionEntryReference,
                  entryAt: (Source, Int) -> DJConnectHistoryEntry?,
                  matching predicate: (DJConnectHistoryEntry) -> Bool) -> Bool {
        (positions[reference] ?? []).contains { position in
            guard let row = entryAt(position.source, position.offset), row.reference == reference else { return false }
            return predicate(row)
        }
    }
}

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
        public var preservesOriginalSelection = false
        public var createdAt = Date()
        public var failed = false
        public var contextChanged = false
        public var deliveryUncertain = false
        public var failureKey: String?
        public var canRetry: Bool { failed && !contextChanged && !deliveryUncertain }
        // While this operation is unresolved, another content tap must not mint
        // a new ID. The explicit safe retry still uses the original payload/ID.
        var blocksContributionResubmission: Bool { preservesOriginalSelection }

        func questionMessage(in messages: [DJConnectAskDJMessage]) -> DJConnectAskDJMessage {
            if let original = messages.first(where: { $0.id == localMessageID && $0.role == .user }) { return original }
            return .init(id: localMessageID ?? UUID(uuidString: id) ?? UUID(), clientMessageID: id,
                role: .user, text: text, status: failed ? .failed : .sending, createdAt: createdAt)
        }
    }

    @Published public private(set) var replyArtworkAvailable = false
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
    static func artworkWindow(entries: [DJConnectHistoryEntry], visibleIDs: Set<String>, at now: Date = Date(), includeReplies: Bool = false) -> [DJConnectSessionEntryReference] {
        guard !visibleIDs.isEmpty else { return [] }
        // Identify visible positions before parsing rights/retention. Offscreen
        // history must not be revalidated in full on every visibility callback.
        let rows = entries
        let visible = rows.indices.filter { visibleIDs.contains(rows[$0].id) && rows[$0].isRetained(at: now) }
        guard let first = visible.first, let last = visible.last else { return [] }
        let eligible: (DJConnectHistoryEntry) -> Bool = {
            ([.playbackObserved, .djMoment].contains($0.kind) || (includeReplies && $0.kind == .conversationDJ)) && $0.isRetained(at: now)
        }
        var indices = visible.filter { eligible(rows[$0]) }
        if let before = rows.indices.prefix(first).last(where: { eligible(rows[$0]) }) { indices.append(before) }
        if let after = rows.indices.dropFirst(last + 1).first(where: { eligible(rows[$0]) }) { indices.append(after) }
        return indices.map { rows[$0].reference }
    }

    public func prefetchArtwork(sessionID: String, visibleIDs: Set<String>) {
        guard artworkAvailable, host?.canRefreshSessionHistory == true,
              let rows = timelines[sessionID]?.entries else { return }
        artworkQueue = Self.artworkWindow(entries: rows, visibleIDs: visibleIDs, includeReplies: replyArtworkAvailable)
        startArtworkQueue()
    }

    /// Existing exact retained-reply preparation, shared bounded queue. A busy
    /// transport must not silently discard all but the first visible answers.
    func enqueueReplyArtwork(for entry: DJConnectHistoryEntry) {
        guard replyArtworkAvailable, artworkAvailable, host?.canRefreshSessionHistory == true,
              entry.kind == .conversationDJ, entry.isRetained(),
              timelines[entry.sessionID]?.entries.contains(entry) == true else { return }
        if !artworkQueue.contains(entry.reference), artworkQueue.count < 32 { artworkQueue.append(entry.reference) }
        startArtworkQueue()
    }

    private func startArtworkQueue() {
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
                    let audience: DJConnectSessionMedia.Audience = media.entryAudience
                    if media.admittedArtwork(session: ref.sessionID, target: .entry(ref.entryID), audience: audience, at: now) != nil { continue }
                }
                guard artworkAttempts[ref].map({ now.timeIntervalSince($0) >= 30 }) ?? true else { continue }
                artworkAttempts = artworkAttempts.filter { now.timeIntervalSince($0.value) < 30 }
                artworkAttempts[ref] = now
                await refreshArtwork(for: row)
            }
        }
    }

    @Published public private(set) var available = false {
        didSet { if oldValue != available { host?.invalidateAskDJHelpObservationContext() } }
    }
    @Published private var contributionExploration: DJConnectContributionExploration?
    @Published public private(set) var summaryAvailable = false
    @Published public private(set) var bulkDeletionAvailable = false
    @Published public private(set) var bulkDeletionBusy = false
    @Published public private(set) var contentDeletionAvailable = false
    @Published public private(set) var contentDeletionBusy = false {
        didSet { if oldValue != contentDeletionBusy { host?.invalidateAskDJHelpObservationContext() } }
    }
    @Published private(set) var contentRemovalRevision = UUID()
    var showsUnconfirmedDeletionNotice: Bool {
        hasUnconfirmedDeletion && !contentDeletionBusy && !bulkDeletionBusy && deletingSessionID == nil
    }
    struct PendingContentDeletion: Codable {
        let owner, scope, binding: String
        let prepared: DJConnectContentDeleteScope
        let request: DJConnectContentDeleteRequest
        var isValid: Bool {
            !owner.isEmpty && scope.count == 64 && binding.count == 64 && request.isValid &&
            prepared.owner_profile_id == owner && prepared.confirmation_id == request.confirmation_id
        }
    }
    @Published private var contentDeletionJournal: [String: PendingContentDeletion] = [:]
    private var invalidContentDeletionJournal = false
    private var contentDeletionReadback: (owner: String, archiveEpoch: UUID)?
    @Published private var withdrawnContentMoments: Set<String> = []
    private var archiveGeneration = UUID()
    @Published public private(set) var archiveResponseEpoch = UUID()
    @Published public private(set) var deletionAvailable = false
    @Published public private(set) var deletingSessionID: String?
    private var deletionGeneration = UUID()
    struct PendingDeletion: Codable {
        let owner, scope, binding, operationID: String
        let single: DJConnectSessionDeleteRequest?
        let bulk: DJConnectSessionDeleteSnapshot?
        var isValid: Bool {
            !owner.isEmpty && scope.count == 64 && binding.count == 64 && UUID(uuidString: operationID) != nil &&
            ((single?.isValid == true && single?.operationID == operationID && bulk == nil) ||
             (single == nil && bulk?.ownerProfileID == owner && (bulk?.targetCount ?? 0) > 0))
        }
    }
    @Published private var deletionJournal: [String: PendingDeletion] = [:]
    private var invalidDeletionJournal = false
    public var hasUnconfirmedDeletion: Bool {
        guard let host, let ownerScope else { return false }
        let scope = host.historyDeletionScope(owner: ownerScope)
        return invalidDeletionJournal || invalidContentDeletionJournal || deletionJournal[scope] != nil || contentDeletionJournal[scope] != nil
    }
    private func saveDeletionJournal() -> Bool {
        guard let host, let data = try? JSONEncoder().encode(deletionJournal), data.count <= 262_144 else { return false }
        return host.storeHistoryDeletionJournal(data) && host.historyDeletionJournalData == data
    }
    private func retainDeletion(owner: String, operationID: String, single: DJConnectSessionDeleteRequest? = nil,
                                bulk: DJConnectSessionDeleteSnapshot? = nil) -> PendingDeletion? {
        guard let host, !invalidDeletionJournal, deletionJournal.count < 32 else { return nil }
        let scope = host.historyDeletionScope(owner: owner)
        guard deletionJournal[scope] == nil else { return nil }
        let record = PendingDeletion(owner: owner, scope: scope, binding: host.historyDeletionScope(owner: owner, bindCredential: true),
                                     operationID: operationID, single: single, bulk: bulk)
        guard record.isValid else { return nil }
        deletionJournal[scope] = record
        guard saveDeletionJournal() else { invalidDeletionJournal = true; return nil }
        return record
    }
    private func finishDeletion(_ record: PendingDeletion) {
        guard deletionJournal[record.scope]?.operationID == record.operationID else { return }
        deletionJournal[record.scope] = nil
        if !saveDeletionJournal() { invalidDeletionJournal = true }
    }
    private func deletionWasDefinitivelyRejected(_ error: Error) -> Bool {
        switch error as? DJConnectError {
        case .server(let status, _): return [400, 409].contains(status)
        case .authStale, .routeMissing: return true
        case .profile(_, let status, _): return [400, 401, 403, 409].contains(status)
        default: return false
        }
    }
    @Published public private(set) var preparing = false
    @Published public private(set) var searchAvailable = false
    @Published public private(set) var momentInsightAvailable = false
    @Published public private(set) var profileScopeActive = false {
        didSet { if oldValue != profileScopeActive { host?.invalidateAskDJHelpObservationContext() } }
    }
    @Published public private(set) var sessions: [DJConnectSavedSession] = []
    @Published public private(set) var listLoading = false
    @Published public private(set) var listErrorKey: String?
    @Published public private(set) var listNextCursor: String?
    @Published public private(set) var timelines: [String: Timeline] = [:]
    private var conversationMessageContexts: [String: DJConnectConversationContext] = [:]
    @Published public private(set) var historicalMatches: [String: [DJConnectHistoryEntry]] = [:] {
        didSet { historicalArtworkIndex = nil }
    }
    @Published public private(set) var pendingTurns: [PendingTurn] = []
    @Published public var selectedEntry: DJConnectSessionEntryReference?
    @Published public var openTarget: DJConnectSessionEntryReference?
    @Published public private(set) var navigationErrorKey: String?
    @Published public private(set) var searchMatches: [DJConnectHistoryEntry] = [] {
        didSet { searchArtworkIndex = nil }
    }
    private var historicalArtworkIndex: SessionHistoryEntryIndex<String>?
    private var searchArtworkIndex: SessionHistoryEntryIndex<Int>?

    func containsHistoricalArtworkEntry(_ reference: DJConnectSessionEntryReference,
                                       matching predicate: (DJConnectHistoryEntry) -> Bool) -> Bool {
        if historicalArtworkIndex == nil { historicalArtworkIndex = .init(historicalMatches) }
        if historicalArtworkIndex?.contains(reference, entryAt: { source, offset in
            guard let rows = historicalMatches[source], rows.indices.contains(offset) else { return nil }
            return rows[offset]
        }, matching: predicate) == true { return true }
        if searchArtworkIndex == nil { searchArtworkIndex = .init([0: searchMatches]) }
        return searchArtworkIndex?.contains(reference, entryAt: { _, offset in
            guard searchMatches.indices.contains(offset) else { return nil }
            return searchMatches[offset]
        }, matching: predicate) == true
    }
    @Published public private(set) var searchLoading = false
    @Published public private(set) var searchErrorKey: String?
    @Published public private(set) var searchComplete = false
    @Published public private(set) var searchTotal: Int?
    @Published public private(set) var searchNextCursor: String?
    @Published public private(set) var acceptedSearchQuery = ""
    @Published public private(set) var acceptedSearchSessionID = ""
    @Published public private(set) var archiveSearchSessions: [DJConnectSavedSession] = []
    @Published public private(set) var archiveSearchQuery = ""
    @Published public private(set) var archiveSearchLoading = false
    @Published public private(set) var archiveSearchComplete = false
    @Published public private(set) var archiveSearchErrorKey: String?
    private var archiveSearchGeneration = UUID()
    private struct LiveResponse {
        let sessionID: String
        let deadline: Date?
        let message: DJConnectAskDJMessage
    }
    @Published private var liveResponses: [String: LiveResponse] = [:]
    private weak var host: DJConnectAppModel?
    public private(set) var historyContractVersion = 1
    @Published public private(set) var historyNeedsUpgrade = false
    private var pendingSubmissionTasks: [UUID: Task<Void, Never>] = [:]
    var activeTextSubmissionCount: Int { pendingSubmissionTasks.count }
    func cancelTextSubmissions() {
        pendingSubmissionTasks.values.forEach { $0.cancel() }; pendingSubmissionTasks = [:]
        host?.cancelAskDJTextSubmissions()
    }
    private func launchSubmission(_ turn: PendingTurn) {
        let id = UUID()
        pendingSubmissionTasks[id] = Task {
            defer { pendingSubmissionTasks.removeValue(forKey: id) }
            await submit(turn)
        }
    }
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
        guard let serverID = message.serverID else { return nil }
        let candidates = timelines.values.flatMap { $0.entries.filter { $0.originMessageID == serverID } }
            + historicalMatches.values.flatMap { $0.filter { $0.originMessageID == serverID } }
        return Self.contextEntry(for: message, entries: candidates)
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

    init(host: DJConnectAppModel) {
        self.host = host
        if let data = host.contentDeletionJournalData {
            if data.count <= 262_144,
               let records = try? JSONDecoder().decode([String: PendingContentDeletion].self, from: data),
               records.count <= 32, records.allSatisfy({ $0.key == $0.value.scope && $0.value.isValid }) {
                contentDeletionJournal = records
            } else { invalidContentDeletionJournal = true }
        }
        if let data = host.historyDeletionJournalData {
            if data.count <= 262_144, let records = try? JSONDecoder().decode([String: PendingDeletion].self, from: data),
               records.count <= 32, records.allSatisfy({ $0.key == $0.value.scope && $0.value.isValid }) {
                deletionJournal = records
            } else { invalidDeletionJournal = true }
        }
    }

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
        contributionExploration = nil
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
            replyArtworkAvailable = caps.replyArtworkAvailable
            summaryAvailable = caps.summaryAvailable
            deletionAvailable = caps.deletionAvailable
            bulkDeletionAvailable = caps.bulkDeletionAvailable
            contentDeletionAvailable = caps.contentDeletionAvailable
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
            guard captured == epoch, host.canRefreshSessionHistory, available, ownerScope != nil else { return }
            contributionExploration = caps.contributionExploration
        } catch {
            guard !Task.isCancelled, !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
            guard captured == epoch else { return }
            if withdrawAuthority(for: error) { return }
            listErrorKey = "ui.session.history.unavailable"
        }
    }

    public func reset() {
        cancelTextSubmissions()
        contributionExploration = nil
        contentDeletionAvailable = false
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
        liveResponses = [:]; conversationMessageContexts = [:]
        cancelArtworkQueue()
        replyArtworkAvailable = false; artworkAvailable = false; artworkPreparing = []; artworkFailed = []
        epoch = UUID(); searchGeneration = UUID(); listGeneration = UUID(); navigationGeneration = UUID()
        searchTask?.cancel(); searchTask = nil
        available = false; searchAvailable = false; momentInsightAvailable = false; profileScopeActive = false; ownerScope = nil
        sessions = []; timelines = [:]; historicalMatches = [:]; pendingTurns = []; readingAnchors = [:]
        host?.setProfileConversationSending(false)
        selectedEntry = nil; openTarget = nil; voiceContext = nil; voiceClientID = nil; voicePayload = nil
        listNextCursor = nil; listRevision = nil; listLoading = false; listErrorKey = nil
        clearSearch(); navigationErrorKey = nil; timelineGenerations = [:]; timelineNavigations = [:]
    }

    public func suspend(preservingVoicePreference: Bool = false, cancelPreparation: Bool = true,
                        preservingArchiveNavigation: Bool = false) {
        cancelTextSubmissions()
        contributionExploration = nil
        contentDeletionAvailable = false
        summaryAvailable = false
        deletionAvailable = false; bulkDeletionAvailable = false; bulkDeletionBusy = false
        archiveGeneration = UUID()
        if !preservingArchiveNavigation { archiveResponseEpoch = archiveGeneration }
        deletingSessionID = nil; deletionGeneration = UUID()
        if preservingVoicePreference { host?.invalidateActiveVoiceInventory() }
        else { host?.discardActiveVoicePreference() }
        host?.invalidateSessionPlaybackActions()
        host?.withdrawLiveConversationPresentations()
        host?.invalidateConversationResultLeases()
        host?.dismissMomentTrackInsight()
        if cancelPreparation {
            preparationTask?.cancel(); preparationTask = nil; preparationID = UUID(); preparing = false
        }
        liveResponses = [:]; conversationMessageContexts = [:]
        cancelArtworkQueue()
        replyArtworkAvailable = false; artworkAvailable = false; artworkPreparing = []; artworkFailed = []
        epoch = UUID(); ownerScope = nil
        listGeneration = UUID(); timelineGenerations = [:]; timelineNavigations = [:]; navigationGeneration = UUID()
        listLoading = false; listNextCursor = nil; listRevision = nil
        searchTask?.cancel(); searchTask = nil
        timelines = [:]; sessions = []; historicalMatches = [:]; searchMatches = []; readingAnchors = [:]
        selectedEntry = nil
        if !preservingArchiveNavigation { openTarget = nil }
        voiceContext = nil; voiceClientID = nil; voicePayload = nil
        clearSearch()
        clearArchiveSearch()
        pendingTurns = []; host?.setProfileConversationSending(false)
    }

    /// Only the readback of a server-confirmed scoped deletion may preserve
    /// unrelated presentation identities across its clear-revision advance.
    var preservesRowsForConfirmedContentDeletion: Bool {
        guard let ownerScope else { return false }
        return contentDeletionReadback.map {
            $0.owner == ownerScope && $0.archiveEpoch == archiveResponseEpoch
        } ?? false
    }

    /// An admitted clear changes content/epoch, not the authenticated Profile.
    /// Authority errors and lifecycle changes still use suspend() directly.
    func invalidateClearedConversation() {
        let admittedOwner = ownerScope
        // A confirmed single-contribution deletion can also advance the Profile
        // clear revision. Its readback must not turn that data fence into a pop.
        // Ordinary clears and authority/lifecycle invalidation retain their fences.
        if preservesRowsForConfirmedContentDeletion {
            // This clear belongs to an admitted scoped deletion. Retire stale
            // work and grants, keeping unrelated rows and the viewport mounted.
            fenceContentDeletionReadback(cancelPreparation: false)
        } else {
            suspend()
        }
        ownerScope = admittedOwner
    }

    public var canPrepareBulkDeletion: Bool {
        bulkDeletionAvailable && !contentDeletionBusy && !bulkDeletionBusy && deletingSessionID == nil && !historyNeedsUpgrade && !hasUnconfirmedDeletion
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
        guard let pending = retainDeletion(owner: ownerScope, operationID: operationID, bulk: snapshot) else { return false }
        do {
            let receipt = try await host.withHomeAssistantClient(allowsOperationReplay: false) {
                try await $0.deleteAllSavedSessions(snapshot: snapshot, expectedOwner: ownerScope, operationID: operationID)
            }
            guard expectedEpoch == epoch, self.ownerScope == ownerScope, host.canRefreshSessionHistory,
                  pending.binding == host.historyDeletionScope(owner: ownerScope, bindCredential: true),
                  receipt.admits(snapshot: snapshot, operationID: operationID, owner: ownerScope), !Task.isCancelled else { return false }
            finishDeletion(pending)
            invalidateArchiveProjections(expectedOwner: ownerScope)
            return true
        } catch {
            if deletionWasDefinitivelyRejected(error) { finishDeletion(pending) }
            if expectedEpoch == epoch { _ = withdrawAuthority(for: error) }
            return false
        }
    }

    private func invalidateArchiveProjections(expectedOwner: String) {
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
            await self.reloadArchiveAfterDeletion(expectedOwner: expectedOwner)
        }
    }

    func contentDeletionTarget(for message: DJConnectAskDJMessage) -> DJConnectContentDeleteTarget? {
        if let entry = contextEntry(for: message) {
            return .init(kind: "entry", sessionID: entry.sessionID, targetID: entry.id)
        }
        if let id = message.serverID, !id.isEmpty, let context = conversationMessageContexts[id] {
            // Use the message's original server context, including explicit
            // standalone scope. The current Session is never a substitute.
            return .init(kind: "message", sessionID: context.sessionID ?? "", targetID: id)
        }
        if let turn = pendingTurns.first(where: { $0.id == message.clientMessageID }) {
            return .init(kind: "request", sessionID: turn.context.sessionID ?? "", targetID: turn.id)
        }
        return nil
    }
    func canDeleteContent(_ target: DJConnectContentDeleteTarget) -> Bool {
        target.isValid && contentDeletionAvailable && !contentDeletionBusy && !hasUnconfirmedDeletion &&
        !bulkDeletionBusy && deletingSessionID == nil && hasAuthorizedOwner && host?.canRefreshSessionHistory == true && host?.isDemoMode == false
        && contentDeletionPreservesOtherWork(target)
    }
    private func contentDeletionPreservesOtherWork(_ target: DJConnectContentDeleteTarget) -> Bool {
        // The cache epoch fence must not discard an unrelated request in flight.
        pendingTurns.allSatisfy { target.kind == "request" && $0.id == target.target_id } &&
        host?.isRecordingVoice == false && host?.voiceStatus != .processing
    }
    func contentMomentWasWithdrawn(sessionID: String, momentID: String) -> Bool {
        guard let ownerScope, let host else { return false }
        return withdrawnContentMoments.contains(host.historyDeletionScope(owner: ownerScope) + "\u{0}" + sessionID + "\u{0}" + momentID)
    }
    func prepareContentDeletion(_ target: DJConnectContentDeleteTarget, expectedEpoch: UUID) async -> DJConnectContentDeleteScope? {
        guard expectedEpoch == epoch, canDeleteContent(target), let owner = ownerScope, let host else { return nil }
        let binding = host.historyDeletionScope(owner: owner, bindCredential: true)
        do {
            let scope = try await host.withHomeAssistantClient(allowsOperationReplay: false) {
                try await $0.prepareContentDeletion(target, expectedOwner: owner)
            }
            guard epoch == expectedEpoch, ownerScope == owner, canDeleteContent(target),
                  binding == host.historyDeletionScope(owner: owner, bindCredential: true),
                  scope.admits(target: target, owner: owner), !Task.isCancelled else { return nil }
            return scope
        } catch { return nil }
    }
    private func saveContentDeletionJournal() -> Bool {
        guard let host, let data = try? JSONEncoder().encode(contentDeletionJournal), data.count <= 262_144 else { return false }
        return host.storeContentDeletionJournal(data) && host.contentDeletionJournalData == data
    }
    @discardableResult func deleteContent(_ prepared: DJConnectContentDeleteScope, expectedEpoch: UUID) async -> Bool {
        guard expectedEpoch == epoch, canDeleteContent(prepared.target), let owner = ownerScope, let host,
              prepared.admits(target: prepared.target, owner: owner), contentDeletionJournal.count < 32 else { return false }
        let key = host.historyDeletionScope(owner: owner)
        let record = PendingContentDeletion(owner: owner, scope: key,
            binding: host.historyDeletionScope(owner: owner, bindCredential: true), prepared: prepared,
            request: .init(identity: host.identity, confirmationID: prepared.confirmation_id))
        guard record.isValid, contentDeletionJournal[key] == nil else { return false }
        contentDeletionJournal[key] = record
        guard saveContentDeletionJournal() else { invalidContentDeletionJournal = true; return false }
        contentDeletionBusy = true
        defer { contentDeletionBusy = false }
        do {
            let receipt = try await host.withHomeAssistantClient(allowsOperationReplay: false) {
                try await $0.deleteContent(record.request, scope: prepared, expectedOwner: owner)
            }
            guard expectedEpoch == epoch, ownerScope == owner, host.canRefreshSessionHistory,
                  record.binding == host.historyDeletionScope(owner: owner, bindCredential: true),
                  receipt.admits(scope: prepared, request: record.request, owner: owner), !Task.isCancelled else { return false }
            return await finishContentDeletion(record, receipt: receipt)
        } catch {
            if deletionWasDefinitivelyRejected(error) {
                contentDeletionJournal[key] = nil
                if !saveContentDeletionJournal() { invalidContentDeletionJournal = true }
            }
            return false
        }
    }

    var canCheckContentDeletionStatus: Bool {
        guard contentDeletionAvailable, !contentDeletionBusy, let host, let ownerScope,
              let record = contentDeletionJournal[host.historyDeletionScope(owner: ownerScope)] else { return false }
        return host.canRefreshSessionHistory && contentDeletionPreservesOtherWork(record.prepared.target) &&
            record.binding == host.historyDeletionScope(owner: ownerScope, bindCredential: true)
    }
    @discardableResult func checkContentDeletionStatus() async -> Bool {
        guard canCheckContentDeletionStatus, let host, let owner = ownerScope,
              let record = contentDeletionJournal[host.historyDeletionScope(owner: owner)] else { return false }
        let captured = epoch
        contentDeletionBusy = true; defer { contentDeletionBusy = false }
        do {
            let status = try await host.withHomeAssistantClient(allowsOperationReplay: false) {
                try await $0.contentDeletionStatus(record.request, scope: record.prepared, expectedOwner: owner)
            }
            guard epoch == captured, ownerScope == owner, host.canRefreshSessionHistory,
                  record.binding == host.historyDeletionScope(owner: owner, bindCredential: true),
                  status.admits(scope: record.prepared, request: record.request, owner: owner),
                  status.state == "completed", let receipt = status.receipt, !Task.isCancelled else { return false }
            return await finishContentDeletion(record, receipt: receipt)
        } catch { return false } // A failed read never settles an earlier unknown POST.
    }
    private func finishContentDeletion(_ record: PendingContentDeletion, receipt: DJConnectContentDeleteReceipt) async -> Bool {
        guard let host, ownerScope == record.owner,
              receipt.admits(scope: record.prepared, request: record.request, owner: record.owner) else { return false }
        for moment in record.prepared.affected_moments {
            withdrawnContentMoments.insert(record.scope + "\u{0}" + moment.session_id + "\u{0}" + moment.moment_id)
        }
        let activeID = host.activeDJSession?.id
        let affected = Set(receipt.affected_entries.map {
            DJConnectSessionEntryReference(sessionID: $0.session_id, entryID: $0.entry_id)
        })
        // Remove only acknowledged content immediately. Server-retained unavailable
        // placeholders, if any, are supplied by the subsequent authoritative read.
        func unaffected(_ entries: [DJConnectHistoryEntry]) -> [DJConnectHistoryEntry] {
            entries.filter { !affected.contains($0.reference) }
        }
        for id in Array(timelines.keys) { timelines[id]?.entries = unaffected(timelines[id]?.entries ?? []) }
        historicalMatches = historicalMatches.mapValues(unaffected)
        searchMatches = unaffected(searchMatches)
        if let selectedEntry, affected.contains(selectedEntry) { self.selectedEntry = nil }
        if let openTarget, affected.contains(openTarget) { self.openTarget = nil }
        host.withdrawDeletedContentPresentation(receipt, target: record.prepared.target)
        fenceContentDeletionReadback(cancelPreparation: true)
        contentRemovalRevision = UUID()
        contentDeletionReadback = (record.owner, archiveResponseEpoch)
        defer { contentDeletionReadback = nil }
        await prepare()
        guard ownerScope == record.owner, host.canRefreshSessionHistory, !Task.isCancelled else { return false }
        guard await loadSessions() else { return false }
        for id in Set(receipt.affected_entries.map(\.session_id)) {
            guard await loadTimeline(id, preserveLoadedEntries: true) else { return false }
        }
        if activeID != nil { guard await host.refreshActiveDJSession() else { return false } }
        guard ownerScope == record.owner,
              record.binding == host.historyDeletionScope(owner: record.owner, bindCredential: true),
              contentDeletionJournal[record.scope]?.request == record.request else { return false }
        contentDeletionJournal[record.scope] = nil
        guard saveContentDeletionJournal() else { invalidContentDeletionJournal = true; return false }
        return true
    }

    /// A scoped erasure retires in-flight work/commands, not unrelated history.
    /// Existing rows retain their original owner and source/retention deadlines.
    private func fenceContentDeletionReadback(cancelPreparation: Bool) {
        cancelTextSubmissions()
        host?.invalidateSessionPlaybackActions()
        host?.withdrawLiveConversationPresentations()
        host?.invalidateConversationResultLeases()
        host?.dismissMomentTrackInsight()
        liveResponses = [:]
        cancelArtworkQueue(); artworkPreparing = []
        if cancelPreparation {
            preparationTask?.cancel(); preparationTask = nil; preparationID = UUID(); preparing = false
        }
        epoch = UUID(); archiveGeneration = UUID()
        listGeneration = UUID(); listLoading = false; listNextCursor = nil; listRevision = nil
        timelineGenerations = [:]; timelineNavigations = [:]; navigationGeneration = UUID()
        for id in Array(timelines.keys) {
            timelines[id]?.loading = false
            timelines[id]?.nextCursor = nil
        }
        searchTask?.cancel(); searchTask = nil; searchGeneration = UUID()
        searchLoading = false; searchNextCursor = nil; searchRevision = nil
        clearArchiveSearch()
        pendingTurns = []; host?.setProfileConversationSending(false)
        voiceContext = nil; voiceClientID = nil; voicePayload = nil
    }

    public func canDeleteSession(_ sessionID: String) -> Bool {
        guard deletionAvailable, !contentDeletionBusy, !bulkDeletionBusy, !historyNeedsUpgrade, !hasUnconfirmedDeletion, ownerScope != nil, let host,
              host.canRefreshSessionHistory, host.activeDJSession?.id != sessionID,
              let session = timelines[sessionID]?.session ?? sessions.first(where: { $0.id == sessionID }) else { return false }
        return session.isContractValid && session.readOnly && ["ENDED", "INTERRUPTED"].contains(session.lifecycleStatus)
    }

    /// A list revision or previously loaded detail is not fresh deletion consent.
    public func prepareSessionDeletion(_ sessionID: String, expectedEpoch: UUID) async -> String? {
        guard expectedEpoch == epoch, canDeleteSession(sessionID), let owner = ownerScope else { return nil }
        guard await loadTimeline(sessionID, preserveLoadedEntries: true), expectedEpoch == epoch,
              ownerScope == owner, canDeleteSession(sessionID), !Task.isCancelled,
              let detail = timelines[sessionID]?.session else { return nil }
        return detail.revision.value
    }

    @discardableResult public func deleteSession(_ sessionID: String, expectedRevision: String, expectedEpoch: UUID) async -> Bool {
        guard expectedEpoch == epoch, deletingSessionID == nil, canDeleteSession(sessionID), let host, let ownerScope,
              let session = timelines[sessionID]?.session ?? sessions.first(where: { $0.id == sessionID }),
              session.revision.value == expectedRevision else { return false }
        let generation = UUID(); deletionGeneration = generation; deletingSessionID = sessionID
        defer { if deletionGeneration == generation { deletingSessionID = nil } }
        let action = DJConnectSessionDeleteRequest(sessionID: sessionID, expectedRevision: expectedRevision)
        guard let pending = retainDeletion(owner: ownerScope, operationID: action.operationID, single: action) else { return false }
        do {
            let receipt = try await host.withHomeAssistantClient(allowsOperationReplay: false) {
                try await $0.deleteSavedSession(action, expectedOwner: ownerScope)
            }
            guard expectedEpoch == epoch, generation == deletionGeneration, self.ownerScope == ownerScope,
                  pending.binding == host.historyDeletionScope(owner: ownerScope, bindCredential: true),
                  host.canRefreshSessionHistory, host.activeDJSession?.id != sessionID,
                  receipt.admits(action, owner: ownerScope), !Task.isCancelled else { return false }
            finishDeletion(pending)
            invalidateDeletedSessions([sessionID], expectedOwner: ownerScope)
            return true
        } catch {
            if deletionWasDefinitivelyRejected(error) { finishDeletion(pending) }
            guard expectedEpoch == epoch, generation == deletionGeneration else { return false }
            if withdrawAuthority(for: error) { return false }
            // No automatic mutation retry, including ambiguous delivery outcomes.
            return false
        }
    }

    private func invalidateDeletedSessions(_ sessionIDs: Set<String>, expectedOwner: String) {
        cancelTextSubmissions()
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
            await self.reloadArchiveAfterDeletion(expectedOwner: expectedOwner)
        }
    }

    /// Settle the deletion's conversation clear before publishing the fresh list.
    /// A higher clear revision suspends old projections, including that list.
    private func reloadArchiveAfterDeletion(expectedOwner: String) async {
        guard ownerScope == expectedOwner, host?.canRefreshSessionHistory == true else { return }
        // An older preparation may still be awaiting a pre-deletion read.
        preparationTask?.cancel(); preparationTask = nil; preparationID = UUID(); preparing = false
        let beforePreparation = epoch
        await prepare()
        guard ownerScope == expectedOwner, host?.canRefreshSessionHistory == true,
              !Task.isCancelled else { return }
        if epoch != beforePreparation {
            // The admitted clear also retires negotiated feature flags. Re-read
            // them once for this same owner, so another deletion remains usable.
            await prepare()
        }
        guard ownerScope == expectedOwner, host?.canRefreshSessionHistory == true,
              !Task.isCancelled else { return }
        await loadSessions()
    }

    @discardableResult
    public func refreshConversation() async -> Bool {
        guard profileScopeActive, let host, host.canRefreshSessionHistory else { return false }
        let captured = epoch, archives = archiveGeneration
        do {
            let response = try await host.withHomeAssistantClient(allowsOperationReplay: false) { try await $0.profileConversationHistory() }
            guard !Task.isCancelled, host.isAskDJPresentationActive, captured == epoch, archives == archiveGeneration, !response.ownerScope.isEmpty else { return false }
            let scope = response.ownerScope
            if let ownerScope, ownerScope != scope {
                suspend(); host.enterProfileConversationScope()
            }
            ownerScope = scope
            guard host.applyProfileConversationHistory(response.base) else { return false }
            historicalMatches = response.historicalMatches
            conversationMessageContexts = response.messageContexts
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
              ([.playbackObserved, .djMoment].contains(original.kind) || (replyArtworkAvailable && original.kind == .conversationDJ)), original.isRetained(),
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
            let audience: DJConnectSessionMedia.Audience = media.entryAudience
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
        guard available, !historyNeedsUpgrade, let owner = ownerScope, !owner.isEmpty,
              !(more && listLoading), let host, host.canRefreshSessionHistory else { return false }
        let cursor = more ? listNextCursor : nil
        if more && cursor == nil { return false }
        let generation = UUID(); listGeneration = generation
        let captured = epoch
        listLoading = true; listErrorKey = nil
        defer { if generation == listGeneration { listLoading = false } }
        do {
            let page = try await host.withHomeAssistantClient { try await $0.savedSessions(cursor: cursor) }
            guard captured == epoch, ownerScope == owner, generation == listGeneration else { return false }
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
        guard available, !historyNeedsUpgrade, let owner = ownerScope, !owner.isEmpty,
              let host, host.canRefreshSessionHistory, !(timelines[sessionID]?.loading ?? false),
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
            guard captured == epoch, ownerScope == owner, timelineGenerations[sessionID] == generation else { return false }
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
        guard available, !historyNeedsUpgrade, let owner = ownerScope, !owner.isEmpty,
              let host, host.canRefreshSessionHistory else { return false }
        navigationErrorKey = nil
        let captured = epoch; let generation = UUID(); navigationGeneration = generation
        timelineGenerations[action.sessionID] = generation
        timelineNavigations[action.sessionID] = generation
        defer { if timelineNavigations[action.sessionID] == generation { timelineNavigations[action.sessionID] = nil } }
        do {
            let response = try await host.withHomeAssistantClient { try await $0.openSavedSession(action) }
            guard captured == epoch, ownerScope == owner, generation == navigationGeneration, timelineGenerations[action.sessionID] == generation, response.entry.isRetained() else { return false }
            var timeline = timelines[action.sessionID] ?? Timeline()
            if navigate && timeline.revision != response.session.revision.value { timeline.entries = [] }
            timeline.session = response.session; timeline.revision = response.session.revision.value
            timeline.entries = try mergeEntries(timeline.entries, [response.entry])
            timeline.loading = false
            timelines[action.sessionID] = timeline
            if navigate { openTarget = action.reference }
            return true
        } catch {
            guard captured == epoch, ownerScope == owner, generation == navigationGeneration, timelineGenerations[action.sessionID] == generation else { return false }
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

    public func clearArchiveSearch() {
        archiveSearchGeneration = UUID()
        archiveSearchSessions = []; archiveSearchQuery = ""
        archiveSearchLoading = false; archiveSearchComplete = false; archiveSearchErrorKey = nil
    }

    /// Query existing owner-scoped server search, not a client copy of every
    /// timeline. A first retained hit is enough to include an archived session.
    public func searchArchivedSessions(query rawQuery: String) async {
        clearArchiveSearch()
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        archiveSearchQuery = query
        let generation = archiveSearchGeneration, captured = epoch, capturedOwner = ownerScope
        func current() -> Bool {
            generation == archiveSearchGeneration && captured == epoch && ownerScope == capturedOwner && !Task.isCancelled
                && available && searchAvailable && !historyNeedsUpgrade && self.host?.canRefreshSessionHistory == true
        }
        guard let host else { return }
        func headerMatches(_ session: DJConnectSavedSession) -> Bool {
            let status = session.lifecycleStatus == "INTERRUPTED"
                ? DJConnectLocalization.localized(key: "ui.session.history.interrupted", language: host.language) : ""
            return (SessionArchiveSummary.text(session, language: host.language) + " " + status).localizedStandardContains(query)
        }
        if host.isDemoMode {
            archiveSearchSessions = sessions.filter { session in
                headerMatches(session) || (timelines[session.id]?.entries ?? []).contains { entry in
                    entry.isRetained() && [entry.text, entry.playback?.title, entry.playback?.artist, entry.playback?.album]
                        .compactMap { $0 }.joined(separator: " ").localizedStandardContains(query)
                }
            }
            archiveSearchComplete = true
            return
        }
        guard available, searchAvailable, !historyNeedsUpgrade, let owner = capturedOwner, !owner.isEmpty,
              host.canRefreshSessionHistory else {
            archiveSearchErrorKey = "ui.session.history.unavailable"; return
        }
        archiveSearchLoading = true
        defer { if generation == archiveSearchGeneration { archiveSearchLoading = false } }
        do {
            try await Task.sleep(for: .milliseconds(300))
            guard current() else { return }
            var listCursor: String?, listRevision: String?
            var listCursors = Set<String>(), seenSessions = Set<String>()
            repeat {
                let page = try await host.withHomeAssistantClient { try await $0.savedSessions(cursor: listCursor) }
                guard current() else { return }
                guard listRevision == nil || listRevision == page.revision.value else { throw DJConnectError.invalidResponse }
                listRevision = page.revision.value
                for session in page.sessions where session.readOnly && seenSessions.insert(session.id).inserted {
                    var matches = headerMatches(session)
                    if !matches {
                        var cursor: String?, revision: String?
                        var cursors = Set<String>()
                        repeat {
                            let result = try await host.withHomeAssistantClient {
                                try await $0.searchSession(sessionID: session.id, query: query, cursor: cursor)
                            }
                            guard current() else { return }
                            guard revision == nil || revision == result.revision.value else { throw DJConnectError.invalidResponse }
                            revision = result.revision.value
                            matches = result.matches.contains { $0.isRetained() }
                            if matches || result.complete { break }
                            guard let next = result.nextCursor, cursors.insert(next).inserted else { throw DJConnectError.invalidResponse }
                            cursor = next
                        } while true
                    }
                    guard current() else { return }
                    if matches { archiveSearchSessions.append(session) }
                }
                guard let next = page.nextCursor else { break }
                guard listCursors.insert(next).inserted else { throw DJConnectError.invalidResponse }
                listCursor = next
            } while true
            guard current() else { return }
            archiveSearchComplete = true
        } catch {
            guard current(), !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
            if requireHistoryUpgrade(for: error) || withdrawAuthority(for: error) { return }
            archiveSearchErrorKey = errorKey(error)
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
        guard searchAvailable, !historyNeedsUpgrade, let owner = ownerScope, !owner.isEmpty,
              host?.canRefreshSessionHistory == true, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
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
        guard !historyNeedsUpgrade, let owner = ownerScope, !owner.isEmpty,
              let host, host.canRefreshSessionHistory else { return }
        let captured = epoch; searchLoading = true
        defer { if generation == searchGeneration { searchLoading = false } }
        do {
            let page = try await host.withHomeAssistantClient { try await $0.searchSession(sessionID: sessionID, query: query, cursor: cursor) }
            guard captured == epoch, ownerScope == owner, generation == searchGeneration, !Task.isCancelled else { return }
            guard cursor == nil || (searchRevision == page.revision.value && page.nextCursor != cursor) else { throw DJConnectError.invalidResponse }
            searchMatches = try mergeEntries(cursor == nil ? [] : searchMatches, page.matches.filter { $0.isRetained() })
            searchRevision = page.revision.value; acceptedSearchQuery = query; acceptedSearchSessionID = sessionID
            searchNextCursor = page.nextCursor; searchComplete = page.complete
            searchTotal = page.totalCount; searchErrorKey = nil
        } catch {
            guard !Task.isCancelled, !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
            guard captured == epoch, ownerScope == owner, generation == searchGeneration, !Task.isCancelled else { return }
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
        guard let host else { return }
        _ = enqueueText(host.askDJDraft, context: currentContext(), preservingComposer: false)
    }

    var contributionQuestion: String? {
        guard let host, !host.isDemoMode, host.canUseAskDJFeatures,
              !pendingTurns.contains(where: \.blocksContributionResubmission),
              !host.isSendingAskDJText, !host.isRecordingVoice, host.voiceStatus != .processing else { return nil }
        return contributionExploration?.question(language: host.language)
    }

    /// The ordinary sender captures current destination/style once. Its separate
    /// selected reference remains the original contribution, including an archive.
    @discardableResult
    func exploreContribution(_ entry: DJConnectHistoryEntry, expectedEpoch: UUID) -> Bool {
        guard expectedEpoch == epoch, let question = contributionQuestion,
              entry.isContractValid, entry.isRetained(), !entry.isPublicationReceipt,
              Self.validSelectionIDs([entry.sessionID, entry.id]),
              [entry.text, entry.playback?.title, entry.playback?.artist, entry.playback?.album].contains(where: {
                  $0?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
              }),
              [.djMoment, .playbackObserved, .conversationDJ].contains(entry.kind),
              timelines[entry.sessionID]?.entries.contains(entry) == true || historicalMatches.values.contains(where: { $0.contains(entry) }) else { return false }
        return enqueueText(question, context: .init(sessionID: host?.activeDJSession?.sessionID, selectedEntry: entry.reference),
                           preservingComposer: true, preservingSelection: true)
    }

    @discardableResult
    func exploreContribution(_ moment: DJConnectMoment, expectedEpoch: UUID) -> Bool {
        guard expectedEpoch == epoch, let question = contributionQuestion,
              let host, !host.djSessionIsRecovering, !host.djSessionLiveUnavailable,
              let session = host.activeDJSession, session.id == moment.sessionID, moment.type != "silence",
              Self.validSelectionIDs([moment.sessionID, moment.id]),
              !contentMomentWasWithdrawn(sessionID: session.id, momentID: moment.id),
              session.broadcast.nativeCurrentMoment(at: Date()) == moment || session.broadcast.nativeFlowMoments(at: Date()).contains(moment) else { return false }
        return enqueueText(question, context: .init(sessionID: session.id,
            selectedMoment: .init(sessionID: moment.sessionID, momentID: moment.id)), preservingComposer: true, preservingSelection: true)
    }

    private static func validSelectionIDs(_ values: [String]) -> Bool {
        values.allSatisfy { !$0.isEmpty && $0.unicodeScalars.count <= 128 && $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    @discardableResult
    func requestSessionSpeakerChoice(sessionID: String) -> Bool {
        guard let host, !host.isDemoMode, host.canUsePlaybackFeatures,
              !host.djSessionIsRecovering, !host.djSessionLiveUnavailable,
              host.activeDJSession?.id == sessionID, host.activeDJSession?.runtimeState == "active",
              host.needsSessionPlaybackOutputSelection else { return false }
        return enqueueText(DJConnectLocalization.localized(key: "ui.session.playback.speaker_question", language: host.language),
                           context: .init(sessionID: sessionID, selectedEntry: nil), preservingComposer: true)
    }

    private func enqueueText(_ original: String, context: DJConnectConversationContext, preservingComposer: Bool,
                             preservingSelection: Bool = false) -> Bool {
        guard profileScopeActive, let host, host.canUseProfileConversation, !host.isSendingAskDJText else { return false }
        guard let capturedOwner = ownerScope else { host.failProfileConversationText(id: nil, errorKey: "ui.ask_dj.answer.unavailable"); return false }
        let text = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let draft = host.askDJDraft
        let id = UUID().uuidString
        let localID = host.beginProfileConversationText(text: text, clientMessageID: id)
        if preservingComposer { host.askDJDraft = draft }
        let turn = PendingTurn(id: id, text: text, context: context, localMessageID: localID,
            payload: host.profileConversationPayload(text: text, clientMessageID: id, context: context), requestEpoch: epoch, ownerScope: capturedOwner,
            preservesOriginalSelection: preservingSelection)
        pendingTurns.append(turn)
        if !preservingComposer { selectedEntry = nil }
        launchSubmission(turn)
        return true
    }

    public func retry(_ turn: PendingTurn) {
        guard turn.canRetry, let host, host.canUseProfileConversation, !host.isSendingAskDJText,
              !turn.preservesOriginalSelection || contributionExploration?.isSupported == true,
              turn.requestEpoch == epoch, ownerScope == turn.ownerScope, pendingTurns.contains(where: { $0.id == turn.id }) else { return }
        pendingTurns.removeAll { $0.id == turn.id }; pendingTurns.append(PendingTurn(
            id: turn.id, text: turn.text, context: turn.context, localMessageID: turn.localMessageID, payload: turn.payload,
            requestEpoch: turn.requestEpoch, ownerScope: turn.ownerScope, preservesOriginalSelection: turn.preservesOriginalSelection, createdAt: turn.createdAt))
        host.setProfileConversationSending(true)
        launchSubmission(turn)
    }

    public func useCurrentContext(_ turn: PendingTurn) {
        guard !turn.preservesOriginalSelection, let host, turn.requestEpoch == epoch, ownerScope == turn.ownerScope,
              pendingTurns.contains(where: {
                  $0.id == turn.id && $0.requestEpoch == turn.requestEpoch && $0.ownerScope == turn.ownerScope
              }) else { return }
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
            let response = try await host.withHomeAssistantClient(allowsOperationReplay: false, notifiesTransportFailure: false) {
                try await $0.sendSessionConversation(payload)
            }
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
                let retained = await refreshConversation()
                guard captured == epoch, ownerScope == turn.ownerScope else { return }
                if !retained || !host.askDJMessages.contains(where: { $0.role == .dj && $0.clientMessageID == turn.id }) {
                    host.showRetainedAskDJAnswerUnavailable()
                }
                return
            }
            if let index = pendingTurns.firstIndex(where: { $0.id == turn.id }) {
                pendingTurns[index].failed = true
                pendingTurns[index].contextChanged = isConflict(error)
                pendingTurns[index].deliveryUncertain = error is DJConnectHybridTransportError
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
            let response = try await host.withHomeAssistantClient(allowsOperationReplay: false) { try await $0.profileConversationHistory() }
            guard !Task.isCancelled, host.isAskDJPresentationActive, captured == epoch, archives == archiveGeneration, !response.ownerScope.isEmpty else { throw CancellationError() }
            let scope = response.ownerScope
            if ownerScope != nil && ownerScope != scope { suspend(); host.enterProfileConversationScope() }
            ownerScope = scope
            guard host.applyProfileConversationHistory(response.base) else { throw DJConnectError.server(statusCode: 409, message: nil) }
            historicalMatches = response.historicalMatches
            conversationMessageContexts = response.messageContexts
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
            let response = try await host.withHomeAssistantClient(allowsOperationReplay: false) { try await $0.sendSessionConversation(payload) }
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
        conversationMessageContexts.merge(response.messageContexts) { _, incoming in incoming }
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
        guard hasAuthorizedOwner, !Task.isCancelled else { return }
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
        if let hybrid = error as? DJConnectHybridTransportError {
            switch hybrid {
            case .outcome, .deliveryUnknown: return "ui.ask_dj.answer.delivery_unknown"
            default: return hybrid.localizationKey
            }
        }
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
