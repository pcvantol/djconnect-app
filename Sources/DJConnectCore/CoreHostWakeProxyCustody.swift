import Foundation
import CryptoKit

/// Resource cancellation, not permission. The actual parent closes positive
/// work synchronously; its deinit also closes negative management work.
final class CoreHostWakeProxyCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var positiveClosed = false, allClosed = false
    private var active: (UUID, Bool, (@Sendable () -> Void)?)?
    var positivesClosed: Bool { lock.withLock { positiveClosed || allClosed } }
    func install(_ id: UUID, positive: Bool, cancel: @escaping @Sendable () -> Void) throws {
        try lock.withLock {
            guard active == nil, !allClosed, !positive || !positiveClosed else { throw CancellationError() }
            active = (id, positive, cancel)
        }
    }
    func reserve(_ id: UUID, positive: Bool) throws {
        try lock.withLock {
            guard active == nil, !allClosed, !positive || !positiveClosed else { throw CancellationError() }
            active = (id, positive, nil)
        }
    }
    func attach(_ id: UUID, cancel: @escaping @Sendable () -> Void) throws {
        let attached = lock.withLock {
            guard !allClosed, let value = active, value.0 == id, value.2 == nil, !value.1 || !positiveClosed else { return false }
            active = (value.0, value.1, cancel); return true
        }
        if !attached { cancel(); throw CancellationError() }
    }
    func isCurrent(_ id: UUID) -> Bool { lock.withLock { !allClosed && active?.0 == id && (active?.1 != true || !positiveClosed) } }
    func finish(_ id: UUID) { lock.withLock { if active?.0 == id { active = nil } } }
    func cancelPositive() {
        let cancel = lock.withLock { () -> (@Sendable () -> Void)? in
            positiveClosed = true
            guard active?.1 == true else { return nil }
            let value = active?.2; active = nil; return value
        }
        cancel?()
    }
    func cancelAll() {
        let cancel = lock.withLock { () -> (@Sendable () -> Void)? in
            allClosed = true; positiveClosed = true
            let value = active?.2; active = nil; return value
        }
        cancel?()
    }
    func cancelCurrent() {
        let cancel = lock.withLock { () -> (@Sendable () -> Void)? in
            let value = active?.2; active = nil; return value
        }
        cancel?()
    }
}

/// Local stage coordination DATA only. Tests can exercise this book without
/// creating a genuine parent, HTTP owner, key, clock witness or SDK permission.
struct CoreHostWakeProxyStageBook {
    enum Phase: Equatable { case idle, preparing, prepared, challenging, challengeReady, completing, verifying, nativeVerified, registering, registerPending, registered, uncertain, withdrawn }
    struct Ticket: Equatable { let id = UUID(); let operation: CoreHostWakeProxyRequest.Operation }
    private(set) var phase = Phase.idle
    private var inFlight: Ticket?
    static func isPositive(_ operation: CoreHostWakeProxyRequest.Operation) -> Bool {
        [.prepare, .nativeChallenge, .nativeComplete, .register].contains(operation)
    }
    mutating func begin(_ operation: CoreHostWakeProxyRequest.Operation) throws -> Ticket {
        guard inFlight == nil else { throw CancellationError() }
        if operation == .withdraw { phase = .withdrawn }
        if Self.isPositive(operation) {
            let expected: Phase = operation == .prepare ? .idle : operation == .nativeChallenge ? .prepared : operation == .nativeComplete ? .challengeReady : .nativeVerified
            guard phase == expected else { throw CancellationError() }
            phase = operation == .prepare ? .preparing : operation == .nativeChallenge ? .challenging : operation == .nativeComplete ? .completing : .registering
        }
        let ticket = Ticket(operation: operation); inFlight = ticket; return ticket
    }
    func isCurrent(_ ticket: Ticket) -> Bool { inFlight == ticket }
    mutating func accept(_ ticket: Ticket, state: String) throws {
        guard isCurrent(ticket) else { throw CancellationError() }
        inFlight = nil
        if state == "unknown" { if phase != .withdrawn { phase = .uncertain }; return }
        if ["withdrawn", "expired"].contains(state) { retire(); return }
        switch ticket.operation {
        case .prepare: guard state == "prepared" else { failClosed(); throw CancellationError() }; phase = .prepared
        case .nativeChallenge: guard state == "pending" else { failClosed(); throw CancellationError() }; phase = .challengeReady
        case .nativeComplete:
            guard ["pending", "native_verified"].contains(state) else { failClosed(); throw CancellationError() }
            phase = state == "native_verified" ? .nativeVerified : .verifying
        case .register:
            guard ["pending", "registered"].contains(state) else { failClosed(); throw CancellationError() }
            phase = state == "registered" ? .registered : .registerPending
        case .status, .nativeStatus, .withdraw: break // History alone never restores a phase.
        }
    }
    /// Called only by the real owner AFTER retaining the same active parent.
    /// Resolves a known acknowledged pending job; NEVER uncertain/cold history.
    mutating func resolveKnownPending(_ operation: CoreHostWakeProxyRequest.Operation, state: String) {
        if operation == .nativeStatus, phase == .verifying, state == "native_verified" { phase = .nativeVerified }
        if operation == .status, phase == .registerPending, state == "registered" { phase = .registered }
    }
    mutating func fail(_ ticket: Ticket) {
        guard isCurrent(ticket) else { return }
        inFlight = nil
        if phase != .withdrawn { phase = .uncertain }
    }
    mutating func retire() {
        phase = .withdrawn
        if let ticket = inFlight, Self.isPositive(ticket.operation) { inFlight = nil }
    }
    mutating func withdraw() { phase = .withdrawn; inFlight = nil }
    private mutating func failClosed() { inFlight = nil; phase = .uncertain }
}

/// Ticket-owned secret bytes and finalization only; neither type can create
/// a genuine parent or native permission. Shared with causal MODEL controls.
struct CoreHostWakeProxyTokenSlot {
    private(set) var owner: UUID?
    private(set) var value: Data?
    mutating func retain(_ bytes: Data, owner: UUID) { self.owner = owner; value = bytes }
    mutating func clear(ifOwnedBy id: UUID?) {
        guard let id, owner == id else { return }; clear()
    }
    mutating func clear() { owner = nil; value = nil }
}
@MainActor final class CoreHostWakeProxySubmission {
    let request: CoreHostWakeProxyRequest
    let ticket: CoreHostWakeProxyStageBook.Ticket
    let positive: Bool
    let prepared: CoreHostWakeProxyReplyData?
    let tokenOwner: UUID?
    var completed = false
    init(request: CoreHostWakeProxyRequest, ticket: CoreHostWakeProxyStageBook.Ticket,
         positive: Bool, prepared: CoreHostWakeProxyReplyData?, tokenOwner: UUID?) {
        self.request = request; self.ticket = ticket; self.positive = positive
        self.prepared = prepared; self.tokenOwner = tokenOwner
    }
    func finish(book: inout CoreHostWakeProxyStageBook, token: inout CoreHostWakeProxyTokenSlot, cancellation: CoreHostWakeProxyCancellation) {
        if !completed { book.fail(ticket); if positive { token.clear(ifOwnedBy: tokenOwner) } }
        cancellation.finish(ticket.id) // Cannot remove a later ticket's reservation.
    }
}

/// Actual Core-management owner. Its constructor requires the private genuine
/// warm parent port; DTOs/test transports/caller booleans cannot create one.
/// It never calls an SDK, generates a key or grants native clock/publication.
@MainActor final class CoreHostWakeProxyCustody {
    struct NativeIntentData {
        let token: Data; let hostBundleID: String; let installationID: String
        let platform: String; let environment: String; let nativeKeyID: String
        /// DATA bounds only, checked before base64/JSON allocations. This is
        /// not evidence that the key, token, platform or environment is admitted.
        func tokenSnapshot() throws -> Data {
            guard (16...2048).contains(token.count), nativeKeyID.utf8.count == 44,
                  let key = Data(base64Encoded: nativeKeyID), key.count == 32, key.base64EncodedString() == nativeKeyID,
                  hostBundleID.utf8.count <= 200, DirectRichRequest.matches(hostBundleID, "[A-Za-z0-9-]+(?:\\.[A-Za-z0-9-]+)+"),
                  DirectRichRequest.matches(installationID, "[A-Za-z0-9_-]{1,128}"),
                  ["ios", "ipados"].contains(platform), ["sandbox", "production"].contains(environment) else { throw DJConnectError.invalidResponse }
            return Data(Array(token))
        }
    }
    private weak var parent: DirectRichReadCustody.OriginalPurposeContext?
    private let channel: CoreHostWakeProxyChannel
    private let cancellation: CoreHostWakeProxyCancellation
    private let originalBodyIsLive: @Sendable () -> Bool
    let operationID: String
    private let identity: [String: DirectRichWireJSON]
    private var book = CoreHostWakeProxyStageBook()
    // Negative cleanup may skip a definitively unsubmitted local child. This
    // is an IO observation, never original/native authority or a retry grant.
    private(set) var prepareWasStarted = false
    private var prepared: CoreHostWakeProxyReplyData?
    private var challengeID: String?
    private var challengeReply: CoreHostWakeProxyReplyData?
    private var token = CoreHostWakeProxyTokenSlot()
    private var work: Task<CoreHostWakeProxyReplyData, any Error>?
    private var workID: UUID?
    private var workPositive = false
    private var registeredReadLive = false
    private var registeredReadTransferred = false
    var phase: CoreHostWakeProxyStageBook.Phase { cancellation.positivesClosed ? .withdrawn : book.phase }

    /// Negative continuity fence for a ONE-WAY registered read transfer. Only
    /// the genuine parent calls this after its same child has ACKed register.
    /// Retiring foreground SDK work does not itself withdraw that prior read.
    func transferRegisteredReadLiveness() throws -> @MainActor @Sendable () -> Bool {
        guard phase == .registered, registeredReadLive, !registeredReadTransferred,
              parent?.isActive == true else { throw CancellationError() }
        registeredReadTransferred = true
        return { [weak self] in self?.registeredReadLive == true }
    }

    init(parent: DirectRichReadCustody.OriginalPurposeContext) throws {
        try Task.checkCancellation()
        guard parent.isActive, parent.pairedIdentity.clientType == .ios else { throw CancellationError() }
        channel = try parent.makeProxyChannel()
        let claim = try parent.claimProxyOperation() // Synchronous, before ANY await; never refunded.
        operationID = claim.operationID; cancellation = claim.cancellation
        self.parent = parent; originalBodyIsLive = parent.originalBodyIsLive
        identity = ["contract_version": .integer(1), "device_id": .string(parent.pairedIdentity.deviceID), "client_type": .string("ios"),
            "session_id": .string(parent.sessionID), "surface": .string(parent.surface), "purpose_id": .string(parent.purposeID), "operation_id": .string(claim.operationID)]
    }
    deinit { cancellation.cancelAll(); work?.cancel() }

    func prepare(_ intent: NativeIntentData) async throws -> CoreHostWakeProxyReplyData {
        try Task.checkCancellation()
        guard workID == nil, book.phase == .idle, current(positive: true) else { throw CancellationError() }
        let snapshot = try intent.tokenSnapshot()
        let request = try request(.prepare, additional: ["target": .object(["host_bundle_id": .string(intent.hostBundleID), "installation_id": .string(intent.installationID)]),
            "platform": .string(intent.platform), "apns_environment": .string(intent.environment), "native_key_id_b64": .string(intent.nativeKeyID),
            "native_token_sha256": .string(SHA256.hash(data: snapshot).map { String(format: "%02x", $0) }.joined())])
        let submission = try begin(request, tokenSnapshot: snapshot)
        prepareWasStarted = true
        defer { finish(submission) } // Installed before the FIRST async call, including entry cancellation.
        return try await exchange(submission)
    }
    func challenge() async throws -> CoreHostWakeProxyReplyData {
        let submission = try begin(request(.nativeChallenge))
        defer { finish(submission) }
        return try await exchange(submission)
    }
    /// A synchronous snapshot of the retained original SDK input DATA. The
    /// actual parent/stage must still be live, but even that is not SDK/clock
    /// admission. No public wrapper or native invocation factory is added.
    func nativeProofInputData(suppliedSDKKeyIdentifier: String) throws -> HostWakeNativeProofInputData {
        try Task.checkCancellation()
        guard workID == nil, book.phase == .challengeReady, current(positive: true),
              let prepared, let original = prepared.original, let preparedKind = prepared.proofKind,
              let challengeReply, let transcript = challengeReply.transcript, let kind = challengeReply.proofKind,
              let hash = challengeReply.fields["client_data_sha256"]?.string, let token = token.value else { throw CancellationError() }
        return try .init(preparedOriginal: original.canonicalData(), preparedKind: preparedKind,
            challengeTranscript: transcript.canonicalBytes, challengeKind: kind, advertisedHash: hash,
            suppliedSDKKeyIdentifier: suppliedSDKKeyIdentifier, originalToken: token)
    }
    /// Transfers proof bytes supplied by the separately admitted native owner.
    /// Selected proof kind is immutable Core metadata, never a local guess.
    func complete(proof: Data) async throws -> CoreHostWakeProxyReplyData {
        try Task.checkCancellation()
        guard (1...9216).contains(proof.count) else { throw DJConnectError.invalidResponse }
        guard let challengeID, let kind = prepared?.proofKind else { throw CancellationError() }
        let submission = try begin(request(.nativeComplete, additional: ["challenge_id": .string(challengeID),
            "native_proof": try HostWakeNativeProofInputData.proofData(kind: kind, opaqueSDKBytes: proof)]))
        defer { finish(submission) }
        return try await exchange(submission)
    }
    func register() async throws -> CoreHostWakeProxyReplyData {
        guard let challengeID, let token = token.value else { throw CancellationError() }
        let submission = try begin(request(.register, additional: ["challenge_id": .string(challengeID), "native_token_b64": .string(token.base64EncodedString())]))
        defer { finish(submission) }
        return try await exchange(submission)
    }
    func status() async throws -> CoreHostWakeProxyReplyData {
        let submission = try begin(request(.status))
        defer { finish(submission) }
        return try await exchange(submission)
    }
    func nativeStatus() async throws -> CoreHostWakeProxyReplyData {
        guard let challengeID else { throw CancellationError() }
        let submission = try begin(request(.nativeStatus, additional: ["challenge_id": .string(challengeID)]))
        defer { finish(submission) }
        return try await exchange(submission)
    }
    func withdraw() async throws -> CoreHostWakeProxyReplyData {
        registeredReadLive = false
        retire() // Local positive cancellation/scrubbing precedes the first await.
        cancellation.cancelCurrent(); work?.cancel(); work = nil; workID = nil; workPositive = false
        book.withdraw() // An older history response cannot win over explicit withdrawal either.
        let submission = try begin(request(.withdraw))
        defer { finish(submission) }
        return try await exchange(submission)
    }
    func retire() {
        cancellation.cancelPositive(); book.retire(); token.clear(); challengeReply = nil
        if workPositive { work?.cancel(); work = nil; workID = nil; workPositive = false }
    }
    private func request(_ operation: CoreHostWakeProxyRequest.Operation, additional: [String: DirectRichWireJSON] = [:]) throws -> CoreHostWakeProxyRequest {
        var fields = identity
        for (key, value) in additional { fields[key] = value }
        return try CoreHostWakeProxyRequest(operation: operation, originalBody: DirectRichWireJSON.object(fields).canonicalData())
    }
    private func current(positive: Bool) -> Bool {
        guard let parent else { return false }
        return positive ? !cancellation.positivesClosed && parent.isActive : parent.canManageNegative
    }
    /// Synchronous stage AND resource reservation. No secret retention or async
    /// call precedes this claim; begin's own catch covers failures before return.
    private func begin(_ request: CoreHostWakeProxyRequest, tokenSnapshot: Data? = nil) throws -> CoreHostWakeProxySubmission {
        try Task.checkCancellation()
        let positive = CoreHostWakeProxyStageBook.isPositive(request.operation)
        guard workID == nil, current(positive: positive) else { throw CancellationError() }
        let ticket = try book.begin(request.operation)
        let submission = CoreHostWakeProxySubmission(request: request, ticket: ticket, positive: positive, prepared: prepared,
            tokenOwner: tokenSnapshot == nil ? token.owner : ticket.id)
        do {
            try cancellation.reserve(ticket.id, positive: positive)
            workID = ticket.id; workPositive = positive
            if let tokenSnapshot { token.retain(tokenSnapshot, owner: ticket.id) }
            try Task.checkCancellation()
            guard current(positive: positive), cancellation.isCurrent(ticket.id) else { throw CancellationError() }
            return submission
        } catch { finish(submission); throw error }
    }
    private func finish(_ submission: CoreHostWakeProxySubmission) {
        submission.finish(book: &book, token: &token, cancellation: cancellation)
        if workID == submission.ticket.id { work = nil; workID = nil; workPositive = false }
        if cancellation.positivesClosed { book.retire() }
    }
    private func exchange(_ submission: CoreHostWakeProxySubmission) async throws -> CoreHostWakeProxyReplyData {
        try Task.checkCancellation()
        let request = submission.request, ticket = submission.ticket, positive = submission.positive
        guard workID == ticket.id, book.isCurrent(ticket), current(positive: positive), cancellation.isCurrent(ticket.id) else { throw CancellationError() }
        let capturedPrepared = submission.prepared, cancellation = cancellation, sourceLive = originalBodyIsLive
        let worker = Task { @MainActor [self] in
            guard book.isCurrent(ticket), current(positive: positive) else { throw CancellationError() }
            let result = try await channel.send(request, beforeDispatch: { [self] in
                guard book.isCurrent(ticket), current(positive: positive) else { throw CancellationError() }
            }, isCurrent: { cancellation.isCurrent(ticket.id) && (!positive || sourceLive()) })
            try Task.checkCancellation()
            guard book.isCurrent(ticket), current(positive: positive), cancellation.isCurrent(ticket.id) else { throw CancellationError() }
            let value = try CoreHostWakeProxyReplyData.decode(result.body, status: result.status, request: request, prepared: capturedPrepared)
            guard let parent else { throw CancellationError() }
            if positive {
                guard value.fields["generation"] == .string(parent.generation),
                      let issued = value.fields["original_wake_issued_at_ms"]?.integer, issued >= parent.issuedMS,
                      let expiry = value.fields["original_wake_expires_at_ms"]?.integer, expiry <= parent.expiresMS,
                      let display = value.fields["original_display_expires_at_ms"]?.integer, display <= parent.expiresMS else { throw DJConnectError.invalidResponse }
            }
            return value // Still DATA; there is no SDK dispatch or clock permit.
        }
        try cancellation.attach(ticket.id, cancel: { worker.cancel() })
        work = worker
        do {
            let value = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
            try Task.checkCancellation()
            guard book.isCurrent(ticket), cancellation.isCurrent(ticket.id), current(positive: positive) else { throw CancellationError() }
            if request.operation == .prepare { prepared = value }
            if request.operation == .nativeChallenge {
                guard let transcript = value.transcript, let original = prepared?.original, let token = token.value,
                      let id = transcript.challenge.object?["challenge_id"]?.string,
                      let hash = value.fields["client_data_sha256"]?.string else { throw DJConnectError.invalidResponse }
                try transcript.compareData(originalCanonicalBytes: original.canonicalData(), nativeToken: token, advertisedHash: hash)
                challengeID = id
                challengeReply = value
            }
            // Commit the retained DATA and phase together, with no await before
            // returning. A canceled consumer never leaves an advanced stage.
            try book.accept(ticket, state: value.state)
            if parent?.isActive == true { book.resolveKnownPending(request.operation, state: value.state) }
            if book.phase == .registered { registeredReadLive = true }
            if ["withdrawn", "expired", "unknown"].contains(value.state) { registeredReadLive = false }
            if book.phase == .withdrawn { retire() }
            if book.phase == .uncertain { token.clear(ifOwnedBy: submission.tokenOwner) }
            submission.completed = true
            return value
        } catch {
            // Push denial/unknown never unpairs or retires the parent display.
            throw error
        }
    }
}
