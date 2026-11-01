import Foundation

/// One process-local resource window, captured by the real read owner before
/// its first authorize. Never a remote-expiry conversion or an SDK permit.
@MainActor final class DirectRichOriginalLocalResources {
    let started: ContinuousClock.Instant
    let ceiling: ContinuousClock.Instant
    private let clock: ContinuousClock
    private var closed = false
    private init() {
        let clock = ContinuousClock()
        self.clock = clock
        let started = clock.now
        self.started = started
        // Independent local resource policy; NOT a duration received from Core.
        ceiling = started.advanced(by: .seconds(28_800))
    }
    static func captureBeforeAuthorize() -> DirectRichOriginalLocalResources { .init() }
    var isCurrent: Bool { !closed && Self.contains(started: started, ceiling: ceiling, now: clock.now) }
    func close() { closed = true }
    static func contains(started: ContinuousClock.Instant, ceiling: ContinuousClock.Instant,
                         now: ContinuousClock.Instant) -> Bool {
        started < ceiling && started <= now && now < ceiling
    }
}

/// One actual warm direct-read lifetime. No native SDK calls, persistent
/// secrets, recovery authorization or default clock qualification. The actual
/// AppModel/native owner must still join a genuine original clock supplier.
@MainActor final class DirectRichReadCustody {
    enum State: Equatable { case idle, authorizing, active, suspended, closed, unknown }
    /// A candidate can only be minted by this live receiver after its own
    /// guarded exchange. Its frame becomes inaccessible after replacement or
    /// withdrawal. It is NOT a native start/update permit.
    @MainActor final class Candidate {
        /// The exact receiving port for the still-required original clock
        /// supplier, BEFORE native request/update/staging. No public/Data init.
        /// Having this input does not itself qualify any cross-clock rate.
        @MainActor struct NativeInputs {
            let operationID: String; let purposeID: String; let surface: String; let sessionID: String
            let issuedMS: Int64; let expiresMS: Int64
            let originalCapture: DJConnectNativeSurfaceClockCapture
            let receivingContext: DirectRichHTTPSChannel.ReceivingContext
            private let candidate: Candidate
            fileprivate init(candidate: Candidate, original: DirectRichResponse.Original,
                             capture: DJConnectNativeSurfaceClockCapture, context: DirectRichHTTPSChannel.ReceivingContext) {
                operationID = original.operationID; purposeID = original.purposeID
                surface = original.surface; sessionID = original.sessionID
                issuedMS = original.issuedMS; expiresMS = original.expiresMS
                originalCapture = capture; receivingContext = context; self.candidate = candidate
            }
            var isCurrent: Bool { candidate.isCurrent && receivingContext.isLive }
            var frame: DirectRichFrame? { isCurrent ? candidate.frame : nil }
        }
        private weak var owner: DirectRichReadCustody?
        private let frameID: String
        private let epoch: UUID
        private let attemptCurrent: @MainActor @Sendable () -> Bool
        let readCapture: DJConnectNativeSurfaceClockCapture
        fileprivate init(owner: DirectRichReadCustody, frameID: String,
                         capture: DJConnectNativeSurfaceClockCapture,
                         attemptCurrent: @escaping @MainActor @Sendable () -> Bool) {
            self.owner = owner; self.frameID = frameID; epoch = owner.candidateEpoch
            readCapture = capture; self.attemptCurrent = attemptCurrent
        }
        var isCurrent: Bool {
            guard let owner else { return false }
            return !Task.isCancelled && owner.fence.isLive && owner.state == .active && owner.originalLocalResourcesAreCurrent && owner.ownerIsCurrent() && owner.pairCurrent() &&
                owner.currentFrame?.frame_id == frameID && owner.candidateEpoch == epoch && attemptCurrent()
        }
        var frame: DirectRichFrame? { isCurrent ? owner?.currentFrame : nil }
        var originalCapture: DJConnectNativeSurfaceClockCapture? { isCurrent ? owner?.originalCapture : nil }
        var genuineReceivingContext: DirectRichHTTPSChannel.ReceivingContext? {
            guard isCurrent, let context = owner?.channel.receivingContext, context.isLive else { return nil }; return context
        }
        var nativeQualificationInputs: NativeInputs? {
            guard isCurrent, let original = owner?.original, let capture = owner?.originalCapture,
                  let context = genuineReceivingContext else { return nil }
            return NativeInputs(candidate: self, original: original, capture: capture, context: context)
        }
        fileprivate func belongs(to expected: DirectRichReadCustody) -> Bool { owner === expected && isCurrent }
    }

    /// Actual warm parent lifetime, separate from any current frame. This
    /// object carries original source custody only, NOT clock/SDK admission.
    @MainActor final class OriginalPurposeContext {
        private weak var owner: DirectRichReadCustody?
        private let receiving: DirectRichHTTPSChannel.ReceivingContext
        let operationID: String; let purposeID: String; let surface: String; let sessionID: String
        let generation: String; let issuedMS: Int64; let expiresMS: Int64
        let originalCapture: DJConnectNativeSurfaceClockCapture
        let pairedOrigin: URL; let pairedIdentity: DJConnectIdentity
        let originalBodyIsLive: @Sendable () -> Bool
        private var proxy: CoreHostWakeProxyCustody?
        fileprivate init(owner: DirectRichReadCustody, original: DirectRichResponse.Original,
                         capture: DJConnectNativeSurfaceClockCapture, receiving: DirectRichHTTPSChannel.ReceivingContext,
                         origin: URL, identity: DJConnectIdentity) {
            self.owner = owner; self.receiving = receiving
            operationID = original.operationID; purposeID = original.purposeID; surface = original.surface; sessionID = original.sessionID
            generation = original.generation; issuedMS = original.issuedMS; expiresMS = original.expiresMS
            originalCapture = capture; pairedOrigin = origin; pairedIdentity = identity
            let lifetime = owner.fence
            originalBodyIsLive = { lifetime.isLive }
        }
        var isRetained: Bool {
            guard !Task.isCancelled, let owner, owner.fence.isLive, owner.originalLocalResourcesAreCurrent,
                  [.active, .suspended].contains(owner.state), let original = owner.original,
                  original.operationID == operationID, original.purposeID == purposeID,
                  original.sessionID == sessionID, original.surface == surface, original.generation == generation,
                  original.issuedMS == issuedMS, original.expiresMS == expiresMS,
                  owner.originalCapture?.continuous == originalCapture.continuous else { return false }
            guard receiving.isLive, receiving.pairedOrigin == pairedOrigin, owner.ownerIsCurrent(), owner.pairCurrent() else {
                owner.retire(); return false // Observed owning loss is terminal; no ABA revival.
            }
            return true // Suspension retains only negative/history custody.
        }
        var isActive: Bool { isRetained && owner?.state == .active }
        var canManageNegative: Bool {
            guard !Task.isCancelled, let owner, receiving.isLive, receiving.pairedOrigin == pairedOrigin else { return false }
            let paired = owner.pairCurrent()
            if !paired || !owner.ownerIsCurrent() { owner.retire() }
            return paired // No frame/read secret or active Session is recovered.
        }
        /// Raw DATA transport only. The owning adapter still must retain and
        /// recheck this parent at dispatch/completion and bind body cancellation;
        /// constructing a channel is never lasting or native SDK permission.
        func makeProxyChannel() throws -> CoreHostWakeProxyChannel {
            guard isActive, let owner, pairedIdentity.clientType == .ios else { throw CancellationError() }
            // Reuse actual original metadata; do not construct a general
            // DJConnectClient and its unrelated transport/session resources.
            return try CoreHostWakeProxyChannel(pairedOrigin: pairedOrigin, identity: pairedIdentity, tokenStore: owner.tokenStore)
        }
        func proxyCustody() throws -> CoreHostWakeProxyCustody {
            if let proxy { return proxy } // Includes uncertain/retired: never reconstruct a child.
            guard isActive else { throw CancellationError() }
            let value = try CoreHostWakeProxyCustody(parent: self)
            proxy = value
            return value
        }
        func claimProxyOperation() throws -> (operationID: String, cancellation: CoreHostWakeProxyCancellation) {
            guard isActive, let owner, owner.proxyCancellation == nil else { throw CancellationError() }
            let operation = UUID(), id = operation.uuidString.lowercased()
            guard id != operationID else { throw DJConnectError.invalidResponse }
            let cancellation = CoreHostWakeProxyCancellation()
            owner.proxyCancellation = cancellation // Irreversible claim before any await; no refund.
            owner.fence.attach(operation) { cancellation.cancelPositive() }
            return (id, cancellation)
        }
        fileprivate func retireProxy() { proxy?.retire() }
        fileprivate var existingProxyForWithdrawal: CoreHostWakeProxyCustody? {
            guard let proxy, proxy.prepareWasStarted else { return nil }; return proxy
        }
    }
    private var originalContextCache: OriginalPurposeContext?
    private var proxyCancellation: CoreHostWakeProxyCancellation?
    var originalPurposeContext: OriginalPurposeContext? {
        if let context = originalContextCache { return context.isRetained ? context : nil }
        guard !Task.isCancelled, [.active, .suspended].contains(state), fence.isLive,
              let original, let capture = originalCapture else { return nil }
        // Observe negative owning facts before checking whether the positive
        // shipping port can exist. A missing port must not hide an observed
        // owner/pair loss and allow A→B→A to revive the original read purpose.
        guard ownerIsCurrent(), pairCurrent() else { retire(); return nil }
        guard let identity = originalClientIdentity, let receiving = channel.receivingContext,
              let origin = receiving.pairedOrigin else { return nil }
        let context = OriginalPurposeContext(owner: self, original: original, capture: capture, receiving: receiving, origin: origin, identity: identity)
        guard context.isRetained else { return nil }
        originalContextCache = context
        return context
    }

    private(set) var state: State = .idle
    private(set) var authorizationWasStarted = false
    private let channel: DirectRichHTTPSChannel
    private let authorization: DirectRichRequest
    private let tokenStore: any DJConnectTokenStore
    private let originalPairedToken: String
    private let originalClientIdentity: DJConnectIdentity?
    private let pairedIsCurrent: @MainActor @Sendable () -> Bool
    fileprivate let ownerIsCurrent: @MainActor @Sendable () -> Bool
    private let captureAttempt: @MainActor @Sendable () -> (@MainActor @Sendable () -> Bool)
    private let fence = LiveFence()
    private var frameFence = LiveFence()
    private var candidateEpoch = UUID()
    private var work: Task<Candidate, any Error>?
    private var workResult: DirectRichSharedResult<Candidate>?
    private var workID: UUID?
    private var artworkWork: Task<[String: Data], Never>?
    private var artworkResult: DirectRichSharedResult<[String: Data]>?
    private var artworkWorkID: UUID?
    private var original: DirectRichResponse.Original?
    private var originalCapture: DJConnectNativeSurfaceClockCapture?
    private(set) var originalLocalResources: DirectRichOriginalLocalResources?
    private var originalLocalResourcesAreCurrent: Bool {
        guard originalLocalResources?.isCurrent == true else {
            if state != .idle { retire(unknown: state == .unknown) }
            return false
        }
        return true
    }
    private var currentFrame: DirectRichFrame?
    private var lastAccepted: (sequence: Int64, observedMS: Int64, state: String)?
    private var knownPurpose: String?
    private var knownBounds: (issued: Int64, expires: Int64)?
    // Read-only runtime resource observations; not permission/clock inputs.
    var pendingReadWaiterCount: Int { workResult?.pendingCount ?? 0 }

    /// The one operation is generated synchronously before any task/await.
    /// Booleans below are request intentions only. Source permission comes
    /// exclusively from the guarded original Core exchange, never this init.
    init(client: DJConnectClient, sessionID: String, surface: DJConnectPassiveSurface, lockedDisplay: Bool,
         pairedIsCurrent: @escaping @MainActor @Sendable () -> Bool,
         ownerIsCurrent: @escaping @MainActor @Sendable () -> Bool,
         captureAttempt: @escaping @MainActor @Sendable () -> (@MainActor @Sendable () -> Bool)) throws {
        originalClientIdentity = client.identity
        channel = try DirectRichHTTPSChannel(pairedHTTPSOrigin: client.baseURL)
        authorization = try Self.intention(identity: client.identity, sessionID: sessionID, surface: surface, locked: lockedDisplay)
        tokenStore = client.tokenStore
        guard let token = try client.tokenStore.loadToken(), !token.isEmpty else { throw DJConnectError.invalidResponse }
        originalPairedToken = token
        self.pairedIsCurrent = pairedIsCurrent; self.ownerIsCurrent = ownerIsCurrent; self.captureAttempt = captureAttempt
    }

    /// Synthetic HTTP tests cannot acquire a genuine ReceivingContext.
    init(testChannel: DirectRichHTTPSChannel, originalAuthorization: DirectRichRequest,
         testTokenStore: any DJConnectTokenStore,
         pairedIsCurrent: @escaping @MainActor @Sendable () -> Bool,
         ownerIsCurrent: @escaping @MainActor @Sendable () -> Bool,
         captureAttempt: @escaping @MainActor @Sendable () -> (@MainActor @Sendable () -> Bool)) throws {
        guard originalAuthorization.operation == .authorize, let token = try testTokenStore.loadToken() else { throw DJConnectError.invalidResponse }
        originalClientIdentity = nil // Synthetic transport cannot create a genuine original parent.
        channel = testChannel; authorization = originalAuthorization; tokenStore = testTokenStore; originalPairedToken = token
        self.pairedIsCurrent = pairedIsCurrent; self.ownerIsCurrent = ownerIsCurrent; self.captureAttempt = captureAttempt
    }

    deinit {
        proxyCancellation?.cancelAll()
        fence.close(); workResult?.complete(.failure(CancellationError())); artworkResult?.complete(.success([:]))
        work?.cancel(); artworkWork?.cancel()
    }

    func authorize() async throws -> Candidate {
        try Task.checkCancellation()
        guard fence.isLive else { retire(unknown: state == .unknown); throw CancellationError() }
        guard state == .idle, pairCurrent(), ownerIsCurrent() else { throw DJConnectError.invalidResponse }
        authorizationWasStarted = true
        state = .authorizing
        originalLocalResources = .captureBeforeAuthorize() // Before task creation or any authorize await.
        let capture = DJConnectNativeSurfaceClockCapture.capture(), current = captureAttempt()
        originalCapture = capture
        let id = UUID(); workID = id
        let shared = DirectRichSharedResult<Candidate>(); workResult = shared
        let task = Task { @MainActor [self] in
            do {
                let reply = try await exchange(authorization, credential: originalPairedToken, attemptCurrent: current)
                let accepted = try DirectRichResponse.active(reply.bytes, request: authorization)
                guard state == .authorizing, originalLocalResourcesAreCurrent, ownerIsCurrent(), pairCurrent(), current() else { throw CancellationError() }
                original = accepted.original; knownPurpose = accepted.original.purposeID
                knownBounds = (accepted.original.issuedMS, accepted.original.expiresMS)
                state = .active; try accept(accepted.frame)
                let candidate = Candidate(owner: self, frameID: accepted.frame.frame_id, capture: capture, attemptCurrent: current)
                shared.complete(.success(candidate)); return candidate
            } catch {
                // A possible/lost authorize reply cannot recover credentials,
                // reset this operation or generate another original purpose.
                if state != .closed { retire(unknown: true) }
                shared.complete(.failure(error)); throw error
            }
        }
        work = task
        fence.attach(id) { task.cancel() }
        defer { fence.detach(id); if workID == id { work = nil; workID = nil; workResult = nil } }
        let candidate = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
        try Task.checkCancellation()
        guard candidate.belongs(to: self) else { throw CancellationError() }
        return candidate
    }

    func read() async throws -> Candidate {
        try Task.checkCancellation()
        guard fence.isLive else { retire(unknown: state == .unknown); throw CancellationError() }
        guard [.active, .suspended].contains(state), original != nil, originalLocalResourcesAreCurrent else { throw DJConnectError.invalidResponse }
        if let shared = workResult {
            let current = captureAttempt()
            guard current(), ownerIsCurrent(), pairCurrent() else { throw CancellationError() }
            // This waiter does not own/cancel the shared request. Its own
            // cancellation and actual currentness still gate the joined result.
            let candidate = try await shared.value()
            try Task.checkCancellation()
            guard current(), candidate.belongs(to: self) else { throw CancellationError() }
            return candidate
        }
        guard ownerIsCurrent(), pairCurrent() else { retire(); throw CancellationError() }
        let capture = DJConnectNativeSurfaceClockCapture.capture(), current = captureAttempt()
        let id = UUID(); workID = id
        let shared = DirectRichSharedResult<Candidate>(); workResult = shared
        let task = Task { @MainActor [self] in
            do {
                guard let original else { throw CancellationError() }
                let request = try DirectRichRequest(operation: .read, originalBody: DirectRichWireJSON.object([
                    "contract_version": .integer(1), "purpose_id": .string(original.purposeID)]).canonicalData())
                let reply = try await exchange(request, credential: original.readCredential, attemptCurrent: current)
                let accepted = try DirectRichResponse.active(reply.bytes, request: request, original: original)
                guard fence.isLive, self.original != nil, originalLocalResourcesAreCurrent, ownerIsCurrent(), pairCurrent(), current() else { throw CancellationError() }
                try accept(accepted.frame); state = .active
                let candidate = Candidate(owner: self, frameID: accepted.frame.frame_id, capture: capture, attemptCurrent: current)
                shared.complete(.success(candidate)); return candidate
            } catch {
                clearFrame()
                if !ownerIsCurrent() || !pairCurrent() { retire() }
                else if let code = error as? DirectRichServerError, code == .frameUnavailable || code == .frameChanged {
                    if state != .closed && state != .unknown { state = .suspended }
                } else if error is CancellationError {
                    if state != .closed && state != .unknown { state = .suspended }
                } else if state != .closed { retire(unknown: true) }
                shared.complete(.failure(error)); throw error
            }
        }
        work = task
        fence.attach(id) { task.cancel() }
        defer { fence.detach(id); if workID == id { work = nil; workID = nil; workResult = nil } }
        let candidate = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
        try Task.checkCancellation()
        guard candidate.belongs(to: self) else { throw CancellationError() }
        return candidate
    }

    /// Negative management does not depend on an active Session or retained
    /// read credential. Local fencing/scrubbing happens BEFORE the first await.
    func withdraw() async throws -> DirectRichResponse.Management {
        retire()
        return try await management(.withdraw)
    }
    /// Only an already-owned child may be withdrawn. Do not recapture an active
    /// parent or call proxyCustody(), which could allocate a new operation.
    func withdrawExistingPushChild() async throws {
        guard let child = originalContextCache?.existingProxyForWithdrawal else { return }
        _ = try await child.withdraw()
    }
    func status() async throws -> DirectRichResponse.Management {
        do {
            let value = try await management(.status)
            return value // An active history reply still never rearms a scope.
        } catch {
            if let code = error as? DirectRichServerError,
               [.historyUnknown, .unavailable, .unauthorized, .notAllowed].contains(code) { retire(unknown: true) }
            throw error
        }
    }

    /// At most two independent original covers are received concurrently.
    /// Bad bytes clear only their slot; no provider URL fetch/recode occurs.
    /// Nothing is staged into the OS cache by this method.
    func artwork(for candidate: Candidate) async -> [String: Data] {
        guard candidate.belongs(to: self), let frame = candidate.frame, let original else { return [:] }
        let frameFence = frameFence
        if let shared = artworkResult {
            guard let pixels = try? await shared.value() else { return [:] }
            return !Task.isCancelled && candidate.belongs(to: self) && frameFence.isLive ? pixels : [:]
        }
        let id = UUID(); artworkWorkID = id
        let shared = DirectRichSharedResult<[String: Data]>(); artworkResult = shared
        let task = Task { @MainActor [self] in
            let pixels = await withTaskGroup(of: (String, Data?).self) { group in
                for descriptor in frame.artwork {
                    group.addTask { [self] in
                        let data = await asset(descriptor, frameID: frame.frame_id, purpose: original.purposeID,
                            credential: original.assetCredential, candidate: candidate, frameFence: frameFence)
                        return (descriptor.slot, data)
                    }
                }
                var result: [String: Data] = [:]
                for await (slot, bytes) in group {
                    if let bytes, candidate.belongs(to: self), frameFence.isLive { result[slot] = bytes }
                }
                return !Task.isCancelled && candidate.belongs(to: self) && frameFence.isLive ? result : [:]
            }
            shared.complete(.success(pixels)); return pixels
        }
        artworkWork = task
        fence.attach(id) { task.cancel() }
        defer { fence.detach(id); if artworkWorkID == id { artworkWork = nil; artworkWorkID = nil; artworkResult = nil } }
        let pixels = await withTaskCancellationHandler(operation: { await task.value }, onCancel: { task.cancel() })
        return !Task.isCancelled && candidate.belongs(to: self) && frameFence.isLive ? pixels : [:]
    }

    /// Resource cancellation only, callable by the real outer owner's deinit.
    /// No actor/currentness/clock boolean is converted into a positive permit.
    nonisolated func cancelOwnedResources() { fence.close() }

    /// Foreground loss stops current positive work without manufacturing a
    /// replacement purpose. An in-flight authorization has an uncertain result;
    /// an acknowledged parent retains only negative/history custody until a
    /// later guarded read under the SAME original purpose.
    func suspend() {
        guard [.authorizing, .active, .suspended].contains(state) else { return }
        if state == .authorizing { retire(unknown: true); return }
        proxyCancellation?.cancelPositive()
        originalContextCache?.retireProxy()
        clearFrame(); state = .suspended
        workResult?.complete(.failure(CancellationError()))
        work?.cancel()
        // Keep the old worker slot until its original defer releases it.
        // A quick resume may join its failure, never overlap a new read.
    }

    func retire(unknown: Bool = false) {
        originalLocalResources?.close() // Terminal; a later read cannot capture a new C0.
        proxyCancellation?.cancelPositive()
        originalContextCache?.retireProxy()
        fence.close(); state = unknown ? .unknown : .closed
        clearFrame(); original = nil; originalCapture = nil
        workResult?.complete(.failure(CancellationError())); workResult = nil
        work?.cancel(); work = nil; workID = nil
    }

    private func asset(_ descriptor: DirectRichFrame.Artwork, frameID: String, purpose: String, credential: String,
                       candidate: Candidate, frameFence: LiveFence) async -> Data? {
        do {
            guard candidate.belongs(to: self), frameFence.isLive else { return nil }
            let request = try DirectRichRequest(operation: .asset, originalBody: DirectRichWireJSON.object([
                "contract_version": .integer(1), "purpose_id": .string(purpose), "frame_id": .string(frameID),
                "asset_id": .string(descriptor.asset_id)]).canonicalData())
            let fence = fence
            let reply = try await channel.send(request, credential: credential, beforeDispatch: { [self] in
                guard candidate.belongs(to: self), pairCurrent(), frameFence.isLive else { throw CancellationError() }
            }, isCurrent: { fence.isLive && frameFence.isLive }, onServerError: { [self] code in
                if [.unavailable, .notAllowed, .unauthorized].contains(code) { retire(unknown: true) }
            })
            guard candidate.belongs(to: self), reply.mime == descriptor.mime_type, frameFence.isLive else { return nil }
            let expected = DirectRichOriginalArtwork.Expected(sha256: descriptor.bytes_sha256,
                byteLength: descriptor.byte_length, mimeType: descriptor.mime_type, width: descriptor.width, height: descriptor.height)
            // ImageIO decoding/hashing does not occupy the UI actor. This
            // detached child is owned, cancelled and joined before returning.
            let validation = Task.detached(priority: .utility) {
                try Task.checkCancellation()
                let value = try DirectRichOriginalArtwork.validate(reply.bytes, matching: expected)
                try Task.checkCancellation(); return value
            }
            let value = try await withTaskCancellationHandler(operation: { try await validation.value }, onCancel: { validation.cancel() })
            guard !Task.isCancelled, candidate.belongs(to: self), frameFence.isLive else { return nil }
            return value.bytes
        } catch {
            if let code = error as? DirectRichServerError, [.unavailable, .notAllowed, .unauthorized].contains(code) { retire(unknown: true) }
            return nil
        }
    }

    private func exchange(_ request: DirectRichRequest, credential: String,
                          attemptCurrent: @escaping @MainActor @Sendable () -> Bool) async throws -> DirectRichHTTPSChannel.Reply {
        let fence = fence
        return try await channel.send(request, credential: credential, beforeDispatch: { [self] in
            guard fence.isLive, originalLocalResourcesAreCurrent, pairCurrent(), ownerIsCurrent(), attemptCurrent() else { throw CancellationError() }
        }, isCurrent: { fence.isLive }, onServerError: { [self] code in
            if [.unavailable, .notAllowed, .unauthorized].contains(code) { retire(unknown: true) }
            else if request.operation == .read && [.frameUnavailable, .frameChanged].contains(code) {
                clearFrame(); if state == .active { state = .suspended }
            }
        })
    }

    private func management(_ operation: DirectRichRequest.Operation) async throws -> DirectRichResponse.Management {
        guard pairCurrent() else { throw CancellationError() }
        var fields = authorization.fields
        for key in ["enabled", "os_snapshot_cache", "locked_display"] { fields.removeValue(forKey: key) }
        let request = try DirectRichRequest(operation: operation, originalBody: DirectRichWireJSON.object(fields).canonicalData())
        let store = tokenStore, token = originalPairedToken
        let reply = try await channel.send(request, credential: token, beforeDispatch: { [self] in
            guard pairCurrent() else { throw CancellationError() }
        }, isCurrent: { (try? store.loadToken()) == token }, onServerError: { [self] code in
            if [.historyUnknown, .unavailable, .unauthorized, .notAllowed].contains(code) { retire(unknown: true) }
        })
        guard pairCurrent() else { throw CancellationError() }
        let value: DirectRichResponse.Management
        do {
            value = try DirectRichResponse.management(reply.bytes, request: request)
            guard knownPurpose == nil || knownPurpose == value.purposeID else { throw DJConnectError.invalidResponse }
            if let knownBounds {
                guard value.issuedMS == knownBounds.issued, value.expiresMS == knownBounds.expires else { throw DJConnectError.invalidResponse }
            }
        } catch { retire(unknown: true); throw error }
        if value.state != "active" { retire(unknown: value.state == "unknown") }
        // This return value never restores original/read secrets/currentFrame.
        return value
    }
    private func pairCurrent() -> Bool { pairedIsCurrent() && (try? tokenStore.loadToken()) == originalPairedToken }
    private func accept(_ frame: DirectRichFrame) throws {
        if let old = lastAccepted {
            guard frame.delivery_sequence >= old.sequence, frame.observed_at_ms >= old.observedMS else { throw DJConnectError.invalidResponse }
            // Broadcast sequence is NOT a unique observation/version. Genuine
            // same-content observations (and sub-ms source changes) may keep
            // it while changing the frame hash. These DATA checks do not prove
            // a new observation or map a clock: the required original source/
            // native qualification must still do that under the SAME purpose.
            // A stale original observation cannot itself become active again.
            if old.state == "stale", frame.state == "active", frame.observed_at_ms == old.observedMS { throw DJConnectError.invalidResponse }
        }
        clearFrame()
        frameFence = LiveFence()
        lastAccepted = (frame.delivery_sequence, frame.observed_at_ms, frame.state); currentFrame = frame
    }
    private func clearFrame() {
        frameFence.close(); candidateEpoch = UUID(); currentFrame = nil
        artworkResult?.complete(.success([:])); artworkResult = nil
        artworkWork?.cancel(); artworkWork = nil; artworkWorkID = nil
    }
    private static func intention(identity: DJConnectIdentity, sessionID: String, surface: DJConnectPassiveSurface, locked: Bool) throws -> DirectRichRequest {
        try DirectRichRequest(operation: .authorize, originalBody: DirectRichWireJSON.object([
            "contract_version": .integer(1), "operation_id": .string(UUID().uuidString.lowercased()),
            "device_id": .string(identity.deviceID), "client_type": .string(identity.clientType.rawValue),
            "session_id": .string(sessionID), "surface": .string(surface.rawValue),
            "enabled": .bool(true), "os_snapshot_cache": .bool(true), "locked_display": .bool(locked)]).canonicalData())
    }
}

private final class LiveFence: @unchecked Sendable {
    private let lock = NSLock(); private var live = true
    private var tasks: [UUID: @Sendable () -> Void] = [:]
    var isLive: Bool { lock.withLock { live } }
    func attach(_ id: UUID, cancel: @escaping @Sendable () -> Void) {
        let closed = lock.withLock { if !live { return true }; tasks[id] = cancel; return false }
        if closed { cancel() }
    }
    func detach(_ id: UUID) { _ = lock.withLock { tasks.removeValue(forKey: id) } }
    func close() {
        let cancelled = lock.withLock {
            live = false; let values = Array(tasks.values); tasks.removeAll(); return values
        }
        for cancel in cancelled { cancel() }
    }
}

/// Resource coordination only, never permission or a clock/lease supplier.
/// The existing owned worker publishes its outcome once. A joiner's cancellation
/// resumes/removes only that waiter; no observer task or additional IO is made.
private final class DirectRichSharedResult<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Value, any Error>?
    private var waiters: [UUID: Waiter] = [:]
    // Local pending caller cap, independent of any server send/purpose budget.
    private let maximumWaiters = 64
    var pendingCount: Int { lock.withLock { waiters.count } }

    func value() async throws -> Value {
        let id = UUID(), waiter = Waiter()
        let value = try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                waiter.install(continuation)
                let ready = lock.withLock { () -> Result<Value, any Error>? in
                    if let result { return result }
                    if waiter.isFinished { return nil }
                    guard waiters.count < maximumWaiters else { return .failure(DJConnectError.invalidResponse) }
                    waiters[id] = waiter; return nil
                }
                if let ready { waiter.complete(ready) }
            }
        }, onCancel: { [self] in
            waiter.complete(.failure(CancellationError()))
            _ = lock.withLock { waiters.removeValue(forKey: id) }
        })
        try Task.checkCancellation()
        return value
    }

    func complete(_ outcome: Result<Value, any Error>) {
        let pending = lock.withLock { () -> [Waiter] in
            guard result == nil else { return [] }
            result = outcome; let pending = Array(waiters.values); waiters = [:]; return pending
        }
        for waiter in pending { waiter.complete(outcome) }
    }

    private final class Waiter: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Value, any Error>?
        private var result: Result<Value, any Error>?
        var isFinished: Bool { lock.withLock { result != nil } }
        func install(_ value: CheckedContinuation<Value, any Error>) {
            let ready = lock.withLock { () -> Result<Value, any Error>? in
                if let result { return result }; continuation = value; return nil
            }
            if let ready { value.resume(with: ready) }
        }
        func complete(_ outcome: Result<Value, any Error>) {
            let waiting = lock.withLock { () -> CheckedContinuation<Value, any Error>? in
                guard result == nil else { return nil }
                result = outcome; let waiting = continuation; continuation = nil; return waiting
            }
            waiting?.resume(with: outcome)
        }
    }
}
