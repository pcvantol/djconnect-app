import Foundation

/// The native A handoff: initial enrollment when genuinely empty, verified
/// active-key reuse, then one exact-byte assertion/submission. HA B screen
/// approval remains an independent explicit owner action.
@MainActor public final class RendezvousConnectionCoordinator {
    public enum Failure: Error, Sendable { case staleContext, requiresRepair, inconsistentState }
    private let requiresNativeAdmission: Bool
    private let initial: RendezvousInitialKeyAdapter
    private let enrollment: RendezvousEnrollmentRegistration
    private let submission: RendezvousAssertionSubmission
    private let service: DJConnectRendezvousService
    private let lifecycle: RendezvousKeyLifecycleJournal
    private let registration: RendezvousRegistrationJournal
    private let recovery: RendezvousRecoveryJournal
    private let repair: RendezvousRepairJournal
    private let submissionJournal: RendezvousSubmissionJournal
    public init() {
        requiresNativeAdmission = true
        initial = .init(); enrollment = .init(); submission = .init(); service = .init()
        lifecycle = .shared; registration = .shared; recovery = .shared
        repair = .shared; submissionJournal = .shared
    }
    init(initial: RendezvousInitialKeyAdapter, enrollment: RendezvousEnrollmentRegistration,
         submission: RendezvousAssertionSubmission, service: DJConnectRendezvousService,
         lifecycle: RendezvousKeyLifecycleJournal, registration: RendezvousRegistrationJournal,
         recovery: RendezvousRecoveryJournal, repair: RendezvousRepairJournal,
         submissionJournal: RendezvousSubmissionJournal) {
        requiresNativeAdmission = false // Internal synthetic provider seam, never public admission.
        self.initial = initial; self.enrollment = enrollment; self.submission = submission; self.service = service
        self.lifecycle = lifecycle; self.registration = registration; self.recovery = recovery
        self.repair = repair; self.submissionJournal = submissionJournal
    }

    public func connect(qr: DJConnectRendezvousQR, envelope: DJConnectRendezvousDestination.Envelope,
                        appContext: Data, isCurrent: @escaping @MainActor @Sendable () -> Bool) async throws
        -> RendezvousAssertionSubmission.Receipt {
        if requiresNativeAdmission { try RendezvousNativeAdmission.require() }
        try Self.validate(qr, isCurrent)
        let handles = try await lifecycle.snapshot(appContext: appContext, at: Self.now())
        try Self.validate(qr, isCurrent)
        if !handles.contains(where: {$0.phase == .active}) {
            // Neither an unknown result, expiry, a new QR nor a changed Profile
            // authorizes a replacement key. Retain existing repair/lifecycle state.
            guard handles.isEmpty else { throw Failure.requiresRepair }
            guard try await submissionJournal.snapshot(at: Self.now()) == nil else { throw Failure.inconsistentState }
            try Self.validate(qr, isCurrent)
            try await enrollInitial(qr: qr, appContext: appContext, isCurrent: isCurrent)
        }
        try Self.validate(qr, isCurrent)
        return try await submission.submit(qr: qr, envelope: envelope, appContext: appContext, isCurrent: isCurrent)
    }

    private func enrollInitial(qr: DJConnectRendezvousQR, appContext: Data,
                               isCurrent: @escaping @MainActor @Sendable () -> Bool) async throws {
        let attempt = EnrollmentAttempt()
        do {
            try await initial.generate(qr: qr, appContext: appContext, lifecycle: lifecycle,
                registration: registration, recovery: recovery, repair: repair, isAdmitted: isCurrent,
                prepareEnrollment: { [self] identifier, key in
                    attempt.identifier = identifier
                    try Self.validate(qr, isCurrent)
                    let challenge = try await service.registrationChallenge(keyID: key, qr: qr)
                    try Self.validate(qr, isCurrent)
                    return challenge
                }, finishEnrollment: { [self] identifier, key, registrationID, challenge in
                    try Self.validate(qr, isCurrent)
                    let receipt = try await enrollment.enrollExistingKey(keyIdentifier: key,
                        attemptIdentifier: registrationID, qr: qr, challenge: challenge,
                        journal: registration, isCurrent: isCurrent)
                    try Self.validate(qr, isCurrent)
                    guard receipt.keyIdentifier == key, receipt.attemptIdentifier == registrationID else {
                        throw Failure.inconsistentState
                    }
                    // Only the exact verified registration201 and its original
                    // expiry can activate this persisted generation reservation.
                    try await lifecycle.recordVerifiedActivation(identifier,
                        originalExpiryMS: receipt.originalKeyExpiryMS, recovered: false,
                        appContext: appContext, at: Self.now())
                    try Self.validate(qr, isCurrent)
                })
        } catch {
            if let identifier = attempt.identifier {
                // A rejected cleanup is harmless: it grants no new SDK attempt.
                try? await lifecycle.markRegistrationUncertain(identifier, appContext: appContext, at: Self.now())
            }
            throw error
        }
    }
    private static func validate(_ qr: DJConnectRendezvousQR, _ isCurrent: @MainActor () -> Bool) throws {
        try Task.checkCancellation()
        guard isCurrent(), qr.isCurrent() else { throw Failure.staleContext }
    }
    private static func now() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    private final class EnrollmentAttempt { var identifier: UUID? }
}
