import Foundation

/// Source-only enrollment completion. Product UI admission and active-key
/// adoption remain separate. No key generation, automatic retry or journal reset.
@MainActor public final class RendezvousEnrollmentRegistration {
    public enum Failure: Error, Sendable { case staleContext, invalidBinding, uncertainOutcome }
    public struct Receipt: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
        public let attemptIdentifier: UUID
        public let keyIdentifier: String
        public let originalKeyExpiryMS: Int64
        public var description: String { "RendezvousEnrollmentReceipt(redacted)" }
        public var debugDescription: String { description }
    }
    private let adapter: RendezvousAppAttestAdapter
    private let service: DJConnectRendezvousService
    public init() { adapter = .init(); service = .init() }
    init(adapter:RendezvousAppAttestAdapter,service:DJConnectRendezvousService) {
        self.adapter = adapter; self.service = service
    }

    /// Consumes an already-created exact registration attempt (including the
    /// initial adapter's committed attempt). Holds the canonical key slot across
    /// SDK, original-byte HTTP and durable completion; never reacquires it inside
    /// the completion closure. Caller must already qualify app/env/key admission.
    public func enrollExistingKey(keyIdentifier:String,attemptIdentifier:UUID,
        qr:DJConnectRendezvousQR,challenge:DJConnectRendezvousEnrollmentChallenge,
        journal:RendezvousRegistrationJournal,
        isCurrent:@escaping @MainActor @Sendable ()->Bool) async throws -> Receipt {
        let result = Completion()
        try await adapter.attestExistingKeyAndFinishRegistration(keyIdentifier:keyIdentifier,
            attemptIdentifier:attemptIdentifier,qr:qr,challenge:challenge,journal:journal,
            isCurrent:isCurrent,finishRegistration:{ [self] in
                result.receipt = try await complete(keyIdentifier:keyIdentifier,attemptIdentifier:attemptIdentifier,
                    qr:qr,challenge:challenge,journal:journal,isCurrent:isCurrent)
            })
        try Self.validate(qr:qr,challenge:challenge,isCurrent:isCurrent)
        guard let receipt = result.receipt else { throw Failure.uncertainOutcome }
        return receipt
    }

    private func complete(keyIdentifier:String,attemptIdentifier:UUID,qr:DJConnectRendezvousQR,
        challenge:DJConnectRendezvousEnrollmentChallenge,journal:RendezvousRegistrationJournal,
        isCurrent:@escaping @MainActor @Sendable ()->Bool) async throws -> Receipt {
        try Self.validate(qr:qr,challenge:challenge,isCurrent:isCurrent)
        // Persist consumption before transport. A failed/uncertain write returns
        // no bytes and cannot start network I/O. No request is reconstructed.
        let call = try await journal.reserveSubmission(attemptIdentifier:attemptIdentifier,at:Self.now())
        let expiry:Int64
        do {
            try Self.validate(qr:qr,challenge:challenge,isCurrent:isCurrent)
            guard call.attemptIdentifier == attemptIdentifier, call.keyIdentifier == keyIdentifier,
                  call.deadlineMS == challenge.expiresAtMS else { throw Failure.invalidBinding }
            expiry = try await service.register(originalBody:call.body,qr:qr,beforeDispatch:{
                try Self.validate(qr:qr,challenge:challenge,isCurrent:isCurrent)
            },isResponseCurrent:{challenge.isCurrent()})
            try Self.validate(qr:qr,challenge:challenge,isCurrent:isCurrent)
            let now = Self.now(), maximumLifetime:Int64 = 30 * 86_400_000
            guard expiry > now, expiry - now <= maximumLifetime,
                  expiry <= challenge.expiresAtMS + maximumLifetime else { throw Failure.invalidBinding }
        } catch {
            // Generic transport/schema/503 failures do not establish response
            // loss eligible for replay. Close this submission as uncertain;
            // retain the handle for separately admitted same-key recovery.
            // A failed cleanup write also grants no receipt or new dispatch.
            try? await journal.completeSubmission(attemptIdentifier:attemptIdentifier,
                reservation:call.reservation,outcome:.terminalFailure,at:Self.now())
            throw Failure.uncertainOutcome
        }
        // Do not retry a completion write, even when it committed before error.
        try await journal.completeSubmission(attemptIdentifier:attemptIdentifier,
            reservation:call.reservation,outcome:.succeeded,at:Self.now())
        try Self.validate(qr:qr,challenge:challenge,isCurrent:isCurrent)
        return Receipt(attemptIdentifier:attemptIdentifier,keyIdentifier:keyIdentifier,originalKeyExpiryMS:expiry)
    }
    private static func validate(qr:DJConnectRendezvousQR,challenge:DJConnectRendezvousEnrollmentChallenge,
        isCurrent:@MainActor @Sendable ()->Bool) throws {
        try Task.checkCancellation()
        guard isCurrent(),qr.isCurrent(),challenge.isCurrent() else { throw Failure.staleContext }
    }
    private static func now()->Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    private final class Completion { var receipt:Receipt? }
}
