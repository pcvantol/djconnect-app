import Foundation

/// Explicit foreground repair of an existing uncertain enrollment. It cannot
/// generate, re-attest, replace or rotate a key, renew a QR, or consent to B.
@MainActor public final class RendezvousSameKeyRecovery {
    public enum Failure: Error, Sendable { case staleContext, unavailable, uncertainOutcome }
    private let requiresNativeAdmission: Bool
    private let sdk: any RendezvousAssertionSDK
    private let service: DJConnectRendezvousService
    private let lifecycle: RendezvousKeyLifecycleJournal
    private let journal: RendezvousRecoveryJournal
    private let repair: RendezvousRepairJournal
    public init() {
        requiresNativeAdmission = true; sdk = SystemRendezvousAssertionSDK(); service = .init()
        lifecycle = .shared; journal = .shared; repair = .shared
    }
    init(sdk: any RendezvousAssertionSDK, service: DJConnectRendezvousService,
         lifecycle: RendezvousKeyLifecycleJournal, journal: RendezvousRecoveryJournal, repair: RendezvousRepairJournal) {
        requiresNativeAdmission = false; self.sdk = sdk; self.service = service
        self.lifecycle = lifecycle; self.journal = journal; self.repair = repair
    }
    private func validate(_ isCurrent: @MainActor () -> Bool) throws {
        try Task.checkCancellation()
        guard isCurrent(), sdk.isSupported,
              !requiresNativeAdmission || RendezvousNativeAdmission.canContinueInFlight else { throw Failure.staleContext }
    }
    /// Prepare only local accounting after an admitted uncertain enrollment.
    /// No challenge, SDK or HTTP; repeated detection preserves the original pause.
    public func prepare(appContext: Data, isCurrent: @escaping @MainActor @Sendable () -> Bool) async throws {
        if requiresNativeAdmission { try RendezvousNativeAdmission.require() }
        try validate(isCurrent)
        let handles = try await lifecycle.snapshot(appContext: appContext, at: Self.now())
        try validate(isCurrent)
        guard handles.count == 1, let handle = handles.first,
              [.registrationUncertain, .recoveryPaused].contains(handle.phase),
              let key = handle.keyIdentifier else { throw Failure.unavailable }
        try await lifecycle.pauseRecovery(handle.identifier, appContext: appContext, at: Self.now())
        try validate(isCurrent)
        _ = try await repair.beginPause(keyIdentifier: key, at: Self.now())
        try validate(isCurrent)
    }
    /// Called only by a separate repair button. A scan, visit or resume must
    /// never call this method. Reservations survive cancellation and restart.
    public func recover(appContext: Data, isCurrent: @escaping @MainActor @Sendable () -> Bool) async throws {
        if requiresNativeAdmission { try RendezvousNativeAdmission.require() }
        try validate(isCurrent)
        let handles = try await lifecycle.snapshot(appContext: appContext, at: Self.now())
        try validate(isCurrent)
        guard handles.count == 1, let handle = handles.first,
              [.registrationUncertain, .recoveryPaused].contains(handle.phase),
              let key = handle.keyIdentifier,
              handle.originalExpiryMS.map({ Self.now() < $0 }) ?? true else { throw Failure.unavailable }
        try await RendezvousAppKeyOperations.shared.perform(keyIdentifier: key) { [self] in
            try await perform(handle: handle, key: key, appContext: appContext, isCurrent: isCurrent)
        }
    }
    private func perform(handle: RendezvousKeyLifecycleJournal.Handle, key: String, appContext: Data,
                         isCurrent: @escaping @MainActor @Sendable () -> Bool) async throws {
        try validate(isCurrent)
        let current = try await lifecycle.snapshot(appContext: appContext, at: Self.now())
        try validate(isCurrent)
        guard current.count == 1, current[0].identifier == handle.identifier,
              [.registrationUncertain, .recoveryPaused].contains(current[0].phase) else { throw Failure.unavailable }
        try await lifecycle.pauseRecovery(handle.identifier, appContext: appContext, at: Self.now())
        try validate(isCurrent)
        _ = try await repair.beginPause(keyIdentifier: key, at: Self.now())
        try validate(isCurrent)
        // An earlier live challenge is not replaced by a new repair click.
        if let previous = try await journal.snapshot(at: Self.now()),
           previous.keyIdentifier != key || Self.now() < previous.deadlineMS {
            throw Failure.unavailable
        }
        try validate(isCurrent)
        let reservation = try await repair.reserveExplicitRecovery(keyIdentifier: key, at: Self.now())
        do {
            try validate(isCurrent)
            let challenge = try await service.recoveryChallenge(keyID: key, isCurrent: isCurrent)
            try validate(isCurrent)
            guard challenge.keyIdentifier == key, challenge.isCurrent() else { throw Failure.unavailable }
            let attempt = try await journal.beginExplicitRepair(challenge: challenge, repair: repair,
                                                               reservation: reservation, at: Self.now())
            try validate(isCurrent)
            guard challenge.isCurrent() else { throw Failure.staleContext }
            let call = try await journal.reserveAssertion(attemptIdentifier: attempt, at: Self.now())
            try validate(isCurrent)
            guard challenge.isCurrent(), call.keyIdentifier == key,
                  call.clientDataHash == challenge.clientDataHash, call.deadlineMS == challenge.expiresAtMS else { throw Failure.unavailable }
            do {
                let proof = try await sdk.assertion(key: key, hash: call.clientDataHash,
                                                   deadline: challenge.originalMonotonicDeadline)
                try validate(isCurrent)
                guard challenge.isCurrent() else { throw Failure.staleContext }
                try await journal.completeAssertion(attemptIdentifier: attempt, reservation: call.reservation,
                                                    result: .received(proof), at: Self.now())
            } catch {
                try? await journal.completeAssertion(attemptIdentifier: attempt, reservation: call.reservation,
                                                     result: .failed, at: Self.now())
                throw Failure.uncertainOutcome
            }
            try validate(isCurrent)
            guard challenge.isCurrent() else { throw Failure.staleContext }
            let request = try await journal.reserveSubmission(attemptIdentifier: attempt, at: Self.now())
            let expiry: Int64
            do {
                try validate(isCurrent)
                expiry = try await service.recover(originalBody: request.body, challenge: challenge,
                    expectedOriginalExpiryMS: handle.originalExpiryMS, isCurrent: isCurrent)
                try validate(isCurrent)
                guard challenge.isCurrent() else { throw Failure.staleContext }
            } catch {
                // A generic HTTP/SDK failure does not qualify an automatic retry.
                try? await journal.completeSubmission(attemptIdentifier: attempt, reservation: request.reservation,
                    outcome: .terminalFailure, at: Self.now())
                throw error
            }
            try await journal.completeSubmission(attemptIdentifier: attempt, reservation: request.reservation,
                                                outcome: .succeeded, at: Self.now())
            try validate(isCurrent)
            guard challenge.isCurrent() else { throw Failure.staleContext }
            try await lifecycle.recordVerifiedActivation(handle.identifier, originalExpiryMS: expiry, recovered: true,
                                                         appContext: appContext, at: Self.now())
            try validate(isCurrent)
            try await repair.complete(keyIdentifier: key, reservation: reservation, outcome: .recovered, at: Self.now())
            try validate(isCurrent)
        } catch {
            let notBeforeMS: Int64?
            if case let DJConnectRendezvousService.Failure.retryAfter(until) = error { notBeforeMS = until }
            else { notBeforeMS = nil }
            // A failed atomic cleanup keeps the original reservation occupied;
            // never independently release it after uncertain pacing persistence.
            try await repair.complete(keyIdentifier: key, reservation: reservation,
                                      outcome: .paused, notBeforeMS: notBeforeMS, at: Self.now())
            throw error
        }
    }
    private static func now() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}
