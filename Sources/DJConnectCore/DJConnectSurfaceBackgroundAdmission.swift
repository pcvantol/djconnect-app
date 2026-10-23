import Foundation

/// RAM-only admission for an original widget registration. It does not acquire
/// a purpose, store a credential for an extension, or enable a native surface.
@MainActor public final class DJConnectSurfaceBackgroundAdmission {
    public struct Snapshot: Sendable {
        public let projection: DJConnectBackgroundSession
        public let registration: DJConnectSurfacePushCoordinate
        public let originalGrantExpiry: Date
        public let monotonicDeadline: ContinuousClock.Instant
        // Distinct from the earlier deadline of an individual content field.
        let observationDeadline: ContinuousClock.Instant
    }

    public struct Services {
        /// Includes the original installation/owner/Session/token witness.
        public let isCurrent: @MainActor (DJConnectSurfacePushWitness) -> Bool
        /// Only the original foreground registration continuation may bootstrap.
        public let canBootstrap: @MainActor (DJConnectSurfacePushWitness) -> Bool
        public let now: @MainActor () -> Date
        public let monotonicNow: @MainActor () -> ContinuousClock.Instant
        /// The separately scoped credential is the only authentication input.
        public let read: @MainActor (DJConnectSurfaceBackgroundRead) async throws -> DJConnectSurfacePushReadResponse

        public init(isCurrent: @escaping @MainActor (DJConnectSurfacePushWitness) -> Bool,
                    canBootstrap: @escaping @MainActor (DJConnectSurfacePushWitness) -> Bool,
                    now: @escaping @MainActor () -> Date,
                    monotonicNow: @escaping @MainActor () -> ContinuousClock.Instant,
                    read: @escaping @MainActor (DJConnectSurfaceBackgroundRead) async throws -> DJConnectSurfacePushReadResponse) {
            self.isCurrent = isCurrent; self.canBootstrap = canBootstrap
            self.now = now; self.monotonicNow = monotonicNow; self.read = read
        }
    }

    public enum State: Equatable { case idle, reading, ready, withdrawn }
    public private(set) var state: State = .idle
    private let original: DJConnectSurfacePushWitness
    private let receipt: DJConnectSurfacePushReceipt
    private var credential: DJConnectSurfaceBackgroundRead?
    private var snapshot: Snapshot?
    private var digest: Data?
    private var epoch = UUID()

    /// Input must come from the original owner's admitted registration attempt,
    /// never a saved status receipt or a different foreground/passive grant.
    public init?(original: DJConnectSurfacePushWitness, registration: DJConnectSurfacePushResponse) {
        guard registration.success, registration.operation.phase == "confirmed",
              let receipt = registration.registration, receipt.coordinate.isValid,
              receipt.state == "registered", receipt.token_role == "widget", original.tokenRole == "widget",
              receipt.platform == original.platform, receipt.cache_policy == "private,no-store",
              receipt.expires_at_ms == original.originalExpiryMS,
              original.originalExpiryMS > 0, original.originalExpiryMS <= 9_007_199_254_740_991,
              let read = registration.background_read, read.matches(receipt) else { return nil }
        self.original = original; self.receipt = receipt; credential = read
    }

    /// Withdrawal is terminal for this original registration. A late read cannot
    /// repopulate either its local projection or its scrubbed scoped credential.
    public func withdraw() {
        epoch = UUID(); credential = nil; snapshot = nil; digest = nil; state = .withdrawn
    }

    private var grantExpiry: Date { Date(timeIntervalSince1970: Double(original.originalExpiryMS) / 1000) }
    private func originalIsCurrent(_ services: Services) -> Bool {
        !Task.isCancelled && services.isCurrent(original) &&
        services.now() < grantExpiry && services.monotonicNow() < original.originalMonotonicDeadline &&
        !Task.isCancelled
    }

    /// No background caller can learn initial IDs from a newly encountered read.
    /// A pin is created only inside the original foreground registration attempt.
    @discardableResult public func bootstrap(services: Services) async -> Snapshot? {
        guard state == .idle else { return nil }
        guard services.canBootstrap(original), originalIsCurrent(services) else { withdraw(); return nil }
        return await read(bootstrap: true, services: services)
    }

    @discardableResult public func refresh(services: Services) async -> Snapshot? {
        guard state == .ready else { return nil }
        return await read(bootstrap: false, services: services)
    }

    public func current(services: Services) -> Snapshot? {
        guard state == .ready, let snapshot else { return nil }
        let captured = epoch
        guard originalIsCurrent(services), epoch == captured, state == .ready else {
            withdraw(); return nil
        }
        let displayable = services.monotonicNow() < snapshot.monotonicDeadline &&
            snapshot.projection.isCurrent(at: services.now(), originalGrantExpiry: grantExpiry)
        guard epoch == captured, state == .ready, !Task.isCancelled else { withdraw(); return nil }
        return displayable ? snapshot : nil
    }

    private func read(bootstrap: Bool, services: Services) async -> Snapshot? {
        guard originalIsCurrent(services), let credential else { withdraw(); return nil }
        let attempt = epoch
        let startedWall = services.now(), startedMono = services.monotonicNow()
        let previous = snapshot, previousDigest = digest
        state = .reading
        do {
            guard originalIsCurrent(services), (!bootstrap || services.canBootstrap(original)),
                  !Task.isCancelled, epoch == attempt, state == .reading else { withdraw(); return nil }
            let response = try await services.read(credential)
            guard epoch == attempt else { return nil }
            // Check original authority after the final await, before pinning any
            // server IDs. Transport generation is NOT projection purpose generation.
            guard originalIsCurrent(services), (!bootstrap || services.canBootstrap(original)),
                  !Task.isCancelled, response.success, response.contract_version == 1,
                  response.cache_policy == "private,no-store",
                  response.registration.coordinate == receipt.coordinate,
                  response.registration.state == "registered",
                  response.registration.expires_at_ms == receipt.expires_at_ms,
                  response.registration.token_role == receipt.token_role,
                  response.registration.platform == receipt.platform,
                  response.registration.cache_policy == "private,no-store",
                  response.passive_session.fields.session_id == original.session,
                  response.passive_session.hasValidFields,
                  let readAt = DJConnectHistoryEntry.date(response.passive_session.fields.as_of),
                  readAt <= services.now(),
                  !bootstrap || response.passive_session.isCurrent(at: services.now(), originalGrantExpiry: grantExpiry),
                  let nextDigest = response.passive_session.semanticDigest,
                  let expiry = DJConnectHistoryEntry.date(response.passive_session.fields.expires_at),
                  epoch == attempt, state == .reading, !Task.isCancelled
            else { withdraw(); return nil }
            let frame = response.passive_session.fields
            if let previous {
                let pinned = previous.projection.fields
                guard frame.binding_id == pinned.binding_id, frame.generation == pinned.generation,
                      frame.delivery_sequence >= pinned.delivery_sequence else { withdraw(); return nil }
                if frame.delivery_sequence == pinned.delivery_sequence {
                    guard nextDigest == previousDigest else { withdraw(); return nil }
                    // Even a valid as_of-only duplicate keeps the original frame
                    // and monotonic deadline. A read never renews its own pin.
                    snapshot = previous; state = .ready
                    return current(services: services)
                }
            } else if !bootstrap { withdraw(); return nil }
            // Anchor at the original pre-await clocks, not as_of/response arrival.
            let contentExpiries = [frame.contribution?.expires_at, frame.now_playing?.expires_at]
                .compactMap { $0 }.compactMap(DJConnectHistoryEntry.date)
            let effectiveExpiry = contentExpiries.reduce(expiry, min)
            let remaining = max(0, min(120, expiry.timeIntervalSince(startedWall)))
            let contentRemaining = max(0, min(120, effectiveExpiry.timeIntervalSince(startedWall)))
            guard remaining.isFinite, contentRemaining.isFinite else { withdraw(); return nil }
            var observationDeadline = min(original.originalMonotonicDeadline, startedMono.advanced(by: .seconds(remaining)))
            if let previous,
               let previousExpiry = DJConnectHistoryEntry.date(previous.projection.fields.expires_at),
               expiry <= previousExpiry {
                observationDeadline = min(observationDeadline, previous.observationDeadline)
            }
            let deadline = min(observationDeadline, startedMono.advanced(by: .seconds(contentRemaining)))
            guard originalIsCurrent(services), (!bootstrap || services.monotonicNow() < deadline),
                  (!bootstrap || services.canBootstrap(original)), !Task.isCancelled,
                  epoch == attempt, state == .reading else { withdraw(); return nil }
            let accepted = Snapshot(projection: response.passive_session, registration: receipt.coordinate,
                                    originalGrantExpiry: grantExpiry, monotonicDeadline: deadline,
                                    observationDeadline: observationDeadline)
            snapshot = accepted; digest = nextDigest; state = .ready
            return current(services: services)
        } catch {
            guard epoch == attempt else { return nil }
            // A known connection failure conveys no new content or revocation.
            // Keep only the original pin/deadlines; never retry this read here.
            if previous != nil, let error = error as? URLError,
               [.timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet,
                .dnsLookupFailed, .cannotFindHost].contains(error.code), originalIsCurrent(services),
               epoch == attempt, state == .reading {
                state = .ready
                return current(services: services)
            }
            withdraw()
            return nil
        }
    }
}
