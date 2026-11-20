import Foundation
import Combine
import DJConnectCore

/// Only presentation/uncertain-operation state lives here. Core owns every contribution and retention decision.
@MainActor final class AskDJMomentsController: ObservableObject {
    struct Scope: Equatable, Sendable {
        let profileID, sessionID, binding, settingsGeneration, voiceRevision: String
        let historyEpoch, connection: UUID
        let revision: Int
    }
    private final class OperationHandle: @unchecked Sendable {
        private let lock = NSLock()
        private var value: String?
        func set(_ value: String) { lock.withLock { self.value = value } }
        var id: String? { lock.withLock { value } }
    }
    @Published private(set) var presentation = AskDJMomentsPresentation()
    @Published private(set) var inventory: DJConnectAskDJMoments.Inventory?
    @Published private(set) var accepted: DJConnectAskDJMoments.Result?
    @Published private(set) var noticeText: String?
    @Published private(set) var pendingText: String?
    @Published private(set) var loading = false
    @Published private(set) var checkingCancellation = false
    @Published private(set) var outcomeUnknown = false
    private var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    private weak var model: DJConnectAppModel?
    private var testClient: DJConnectClient?
    private var testScope: (() -> Scope?)?
    // The injected client still runs the actual paired Hybrid transport; tests can
    // suspend its wire while exercising this exact controller, not a second reducer.
    init(testClient: DJConnectClient, scope: @escaping () -> Scope?, now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.testClient = testClient; self.testScope = scope; self.now = now
    }
    private func currentScope() -> Scope? { testScope?() ?? model?.askDJMomentsScope() }
    private func withClient<T: Sendable>(_ action: (DJConnectClient) async throws -> T) async throws -> T {
        if let testClient { return try await action(testClient) }
        guard let model else { throw CancellationError() }
        return try await model.withHomeAssistantClient(allowsOperationReplay: false, action)
    }
    private var scope: Scope?
    private var item: DJConnectAskDJMoments.Item?
    private var request: DJConnectAskDJMoments.Request?
    private var handle: OperationHandle?
    private var requestTask: Task<Void, Never>?
    private var statusPollTask: Task<Void, Never>?
    private var acceptedStatusTask: Task<Void, Never>?
    private var terminalAccepted = false
    init(model: DJConnectAppModel? = nil) { self.model = model }
    var isActive: Bool { presentation.phase != .idle }
    var hasPriority: Bool { isActive && valid }
    var generation: UUID { presentation.generation }
    var operationID: String? { handle?.id }
    var currentResult: DJConnectAskDJMoments.Result? {
        guard case .presenting = presentation.phase, valid, let accepted,
              model?.sessionHistory.contentMomentWasWithdrawn(sessionID: accepted.moment.sessionID, momentID: accepted.moment.id) != true,
              accepted.admission.admits(moment: accepted.moment, at: Date()) else { return nil }
        return accepted
    }
    private var valid: Bool { scope != nil && currentScope() == scope }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: "ui.ask_moments." + key, language: model?.language ?? "en") }
    func open() {
        if isActive && !valid { close() }
        guard !hasPriority, let captured = currentScope() else { return }
        model?.prepareRequestedMomentPresentation()
        scope = captured; inventory = nil; accepted = nil; request = nil; handle = nil; item = nil
        terminalAccepted = false; noticeText = nil; pendingText = nil; checkingCancellation = false; outcomeUnknown = false
        presentation.choose(); let generation = generation
        loading = true
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await withClient { client in
                    try await client.askDJMomentsInventory(sessionID: captured.sessionID, isCurrent: { [weak self] in self?.matches(generation) == true })
                }
                guard matches(generation), presentation.phase == .choosing else { return }
                inventory = response; loading = false
            } catch {
                guard matches(generation), presentation.phase == .choosing else { return }
                loading = false; noticeText = text("unavailable")
            }
        }
    }
    func select(_ selected: DJConnectAskDJMoments.Item) {
        guard valid, presentation.phase == .choosing, selected.available,
              inventory?.types.contains(selected) == true, let scope else { return }
        item = selected; request = .init(sessionID: scope.sessionID, item: selected)
        guard let request else { return }
        let generation = generation, operation = OperationHandle(); handle = operation
        presentation.request(generation: generation); pendingText = selected.pendingText; noticeText = nil
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await withClient { client in
                    try await client.requestDJMoment(request, isCurrent: { [weak self] in self?.matches(generation) == true },
                        onOperationID: { [weak self] id in
                            operation.set(id)
                            Task { @MainActor [weak self] in
                                guard self?.matches(generation) == true else { return }
                                self?.objectWillChange.send()
                            }
                        })
                }
                receive(response, generation: generation, mayAutoplay: true)
                if matches(generation), presentation.phase == .pending { startStatusPolling(generation: generation) }
            } catch {
                guard matches(generation), !terminalAccepted else { return }
                if authorityWasWithdrawn(error) { close(); return }
                // The original operation can already have committed. Never generate another ID.
                outcomeUnknown = true; noticeText = text("temporary")
                if operation.id != nil { startStatusPolling(generation: generation) }
                else { presentation.notice(generation: generation) }
            }
        }
    }
    func checkStatus() {
        guard valid, operationID != nil, !terminalAccepted else { return }
        let generation = generation
        startStatusPolling(generation: generation)
    }
    private func startStatusPolling(generation: UUID) {
        statusPollTask?.cancel()
        statusPollTask = Task { [weak self] in await self?.poll(generation: generation) }
    }
    private func poll(generation: UUID) async {
        for attempt in 0..<60 {
            guard matches(generation), !terminalAccepted, let request, let id = operationID else { return }
            if attempt > 0 { do { try await Task.sleep(for: .seconds(2)) } catch { return } }
            do {
                let response = try await withClient { client in
                    try await client.requestedDJMomentStatus(request, operationID: id, isCurrent: { [weak self] in self?.matches(generation) == true })
                }
                receive(response, generation: generation, mayAutoplay: false)
                if presentation.phase != .pending { return }
            } catch {
                guard matches(generation), !terminalAccepted else { return }
                if authorityWasWithdrawn(error) { close(); return }
                outcomeUnknown = true; noticeText = text("temporary")
                return // Explicit status control retains the SAME original operation.
            }
        }
        if matches(generation), !terminalAccepted { outcomeUnknown = true; noticeText = text("temporary") }
    }
    func cancel() {
        guard matches(generation), !terminalAccepted, let request, let id = operationID else { return }
        let generation = generation
        checkingCancellation = true; noticeText = text("cancel_checking")
        // Do not cancel the request task: its accepted response may win this race.
        Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await withClient { client in
                    try await client.cancelRequestedDJMoment(request, operationID: id, isCurrent: { [weak self] in self?.matches(generation) == true })
                }
                receive(response, generation: generation, mayAutoplay: false, cancellation: true)
            } catch {
                guard matches(generation), !terminalAccepted else { return }
                outcomeUnknown = true; noticeText = text("cancel_checking")
                startStatusPolling(generation: generation)
            }
        }
    }
    private func receive(_ response: DJConnectAskDJMoments.Response, generation: UUID, mayAutoplay: Bool, cancellation: Bool = false) {
        guard matches(generation), let request, let item, let id = operationID,
              response.matches(request, originalID: id, checksReceipt: !cancellation) else { return }
        if response.state == .acceptedResultUnavailable {
            close(); return // Rights withdrawal wins even after acceptance.
        }
        guard !terminalAccepted else { return }
        outcomeUnknown = false
        if response.state != .pending { checkingCancellation = false }
        switch response.state {
        case .accepted:
            guard response.success, let result = response.result,
                  result.admits(request: request, item: item, operationID: id, at: Date()) else {
                noticeText = text("unavailable"); presentation.notice(generation: generation); return
            }
            terminalAccepted = true; accepted = result; pendingText = nil; noticeText = nil
            presentation.present(momentID: result.moment.id, entryID: result.entryID, generation: generation)
            acceptedStatusTask = Task { [weak self] in await self?.watchAccepted(generation: generation) }
            if let model {
                if mayAutoplay { model.autoplayRequestedDJMoment(result) }
                Task { _ = await model.sessionHistory.refreshVisibleTimeline(request.sessionID, anchor: nil) }
            }
        case .pending:
            pendingText = response.pendingText
            if !checkingCancellation { noticeText = nil }
        case .cancelled:
            noticeText = response.message ?? text("cancelled"); presentation.notice(generation: generation)
        case .notFound, .temporarilyUnavailable, .denied:
            noticeText = response.message ?? text(response.state == .denied ? "denied" : "no_result")
            presentation.notice(generation: generation)
        case .acceptedResultUnavailable: break
        }
    }
    private func watchAccepted(generation: UUID) async {
        while matches(generation), currentResult != nil {
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard matches(generation), let request, let id = operationID else { return }
            do {
                let response = try await withClient { client in
                    try await client.requestedDJMomentStatus(request, operationID: id, isCurrent: { [weak self] in self?.matches(generation) == true })
                }
                // The terminal latch ignores duplicate accepted/pending/error results;
                // only explicit original-owner withdrawal can take accepted content away.
                receive(response, generation: generation, mayAutoplay: false)
            } catch {
                guard matches(generation) else { return }
                if authorityWasWithdrawn(error) { close(); return }
                // A transient status failure does not erase still-admitted text.
            }
        }
    }
    private func authorityWasWithdrawn(_ error: Error) -> Bool {
        if let error = error as? DJConnectHybridTransportError {
            switch error {
            case .authority, .installationMismatch, .untrustedRoute: return true
            default: break
            }
        }
        if let error = error as? DJConnectError {
            switch error {
            case .missingToken, .authStale, .profile, .clientTypeMismatch: return true
            default: break
            }
        }
        return false
    }
    private func matches(_ generation: UUID) -> Bool { self.generation == generation && valid && !Task.isCancelled }
    func close() {
        let old = accepted?.moment
        requestTask?.cancel(); requestTask = nil; statusPollTask?.cancel(); statusPollTask = nil; acceptedStatusTask?.cancel(); acceptedStatusTask = nil; presentation.dismiss(); accepted = nil; inventory = nil; pendingText = nil
        scope = nil; noticeText = nil; checkingCancellation = false
        if let old { model?.stopRequestedMomentSpeech(old) }
    }
    func tick() {
        guard isActive else { return }
        guard valid else { close(); return }
        let generation = generation
        if let result = accepted {
            let withdrawn = model?.sessionHistory.contentMomentWasWithdrawn(sessionID: result.moment.sessionID, momentID: result.moment.id) == true
            let exploringOriginal = model?.sessionHistory.pendingTurns.contains {
                $0.context.selectedMoment?.momentID == result.moment.id && $0.context.selectedMoment?.sessionID == result.moment.sessionID && $0.blocksContributionResubmission
            } == true
            presentation.hold(.interaction, active: exploringOriginal, at: now(), generation: generation)
            if let model { observeSpeech(reference: model.sharedSpeechReference, preparing: model.sharedSpeechIsPreparing, playing: model.sharedSpeechIsPlaying) }
            presentation.advance(at: now(), generation: generation,
                rightsValid: !withdrawn && result.admission.admits(moment: result.moment, at: Date()))
            if presentation.phase == .idle { close() }
        }
    }
    func observeSpeech(reference: DJConnectSpeechReference?, preparing: Bool, playing: Bool) {
        guard let result = currentResult else { return }
        let owns = reference == .moment(sessionID: result.moment.sessionID, momentID: result.moment.id)
        let generation = generation
        presentation.hold(.preparation, active: owns && preparing, at: now(), generation: generation)
        presentation.hold(.narration, active: owns && playing, at: now(), generation: generation)
    }
    func visibility(_ visible: Bool, generation: UUID) {
        guard matches(generation) else { return }
        presentation.visibility(visible, at: now(), generation: generation)
    }
    func hold(_ hold: AskDJMomentsPresentation.Hold, _ active: Bool, generation: UUID) {
        guard matches(generation) else { return }
        presentation.hold(hold, active: active, at: now(), generation: generation)
    }
    func owns(_ provenance: DJConnectAskDJMoments.Provenance?, sessionID: String) -> Bool {
        guard hasPriority, let operationID, let request, let provenance else { return false }
        return sessionID == scope?.sessionID && provenance.contractVersion == 1 &&
            provenance.operationID == operationID && provenance.typeID == request.typeID &&
            provenance.subjectReference == request.subjectReference
    }
    func owns(_ moment: DJConnectMoment) -> Bool { owns(moment.userRequested, sessionID: moment.sessionID) }
}
