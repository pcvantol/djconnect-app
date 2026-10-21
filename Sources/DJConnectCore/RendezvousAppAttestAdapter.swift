import CryptoKit
import Foundation
#if os(iOS) && canImport(DeviceCheck)
import DeviceCheck
#endif

// Internal qualification seam; the public adapter always uses Apple's SDK.
@MainActor protocol RendezvousAttestationSDK {
    var isSupported: Bool { get }
    func attest(key: String, hash: Data, deadline: TimeInterval) async throws -> Data
}

/// Connects the existing persisted enrollment journal to the genuine SDK.
/// Does not create/adopt keys, allocate challenges, submit HTTP, reset journals
/// or authorize a physical run. The caller must already admit this exact key.
@MainActor public final class RendezvousAppAttestAdapter {
    public enum Failure: Error, Sendable { case unsupported, staleContext, invalidReservation, sdkUnavailable, sdkFailed }
    private let sdk: any RendezvousAttestationSDK
    public init() { sdk = SystemRendezvousAttestationSDK() }
    init(sdk: any RendezvousAttestationSDK) { self.sdk = sdk }
    public var isSupported: Bool { sdk.isSupported }

    /// No SDK invocation escapes a failed/uncertain reservation write. The slot
    /// remains held through callback handling and durable completion, including
    /// cancellation cleanup and the required registration completion closure.
    /// That closure owns original-byte HTTP accounting/outcome reconciliation;
    /// it must not recursively acquire this same key slot. No automatic retry.
    public func attestExistingKeyAndFinishRegistration(
        keyIdentifier: String, attemptIdentifier: UUID,
        qr: DJConnectRendezvousQR, challenge: DJConnectRendezvousEnrollmentChallenge,
        journal: RendezvousRegistrationJournal,
        isCurrent: @escaping @MainActor @Sendable () -> Bool,
        finishRegistration: @escaping @MainActor @Sendable () async throws -> Void
    ) async throws {
        guard sdk.isSupported else { throw Failure.unsupported }
        try await RendezvousAppKeyOperations.shared.perform(keyIdentifier:keyIdentifier) { [self] in
            try await self.performAttestation(keyIdentifier:keyIdentifier, attemptIdentifier:attemptIdentifier,
                qr:qr, challenge:challenge, journal:journal, isCurrent:isCurrent, finishRegistration:finishRegistration)
        }
    }

    private func performAttestation(keyIdentifier:String, attemptIdentifier:UUID,
        qr:DJConnectRendezvousQR, challenge:DJConnectRendezvousEnrollmentChallenge,
        journal:RendezvousRegistrationJournal, isCurrent:@MainActor @Sendable ()->Bool,
        finishRegistration:@MainActor @Sendable () async throws->Void) async throws {
        func validate() throws {
            try Task.checkCancellation()
            guard sdk.isSupported, isCurrent(), qr.isCurrent(), challenge.isCurrent() else { throw Failure.staleContext }
        }
        try validate()
        let call = try await journal.reserveAttestation(attemptIdentifier:attemptIdentifier,at:Self.now())
        // Recheck after the persistence actor hop, immediately before SDK I/O.
        try validate()
        guard call.keyIdentifier == keyIdentifier, call.attemptIdentifier == attemptIdentifier,
              call.challengeIdentifier == challenge.identifier, call.deadlineMS == challenge.expiresAtMS,
              call.clientDataHash == Data(SHA256.hash(data:challenge.nonce)),
              DJConnectRendezvousSubmitChallenge.canonicalKeyID(call.keyIdentifier) else { throw Failure.invalidReservation }
        let remaining = Double(min(qr.expiresAtMS,challenge.expiresAtMS)-Self.now())/1000
        guard remaining > 0 else { throw Failure.staleContext }
        // The typed challenges separately enforce their original monotonic and
        // rollback fences before and after the callback. This is only a callback
        // wait bound, never a fresh challenge or validity extension.
        let deadline = min(qr.originalMonotonicDeadline,challenge.originalMonotonicDeadline,
            ProcessInfo.processInfo.systemUptime + min(remaining,120))
        let result: RendezvousRegistrationJournal.AttestationResult
        var sdkFailure: Failure?
        do {
            let proof = try await sdk.attest(key:call.keyIdentifier,hash:call.clientDataHash,deadline:deadline)
            try validate()
            result = .received(proof)
        } catch {
            let valid = !Task.isCancelled && isCurrent() && qr.isCurrent() && challenge.isCurrent()
            if valid, case Failure.sdkUnavailable = error {
                result = .serverUnavailable; sdkFailure = .sdkUnavailable
            } else {
                result = .terminalFailure; sdkFailure = .sdkFailed
            }
        }
        // A failed completion write propagates. It never authorizes a second
        // call or returns proof to the caller. Late/unknown callbacks cannot reset
        // the already-persisted consumed reservation.
        try await journal.completeAttestation(attemptIdentifier:call.attemptIdentifier,
            reservation:call.reservation,result:result,at:Self.now())
        if let sdkFailure { throw sdkFailure }
        try validate()
        try await finishRegistration()
        try validate()
    }
    private static func now()->Int64 { Int64(Date().timeIntervalSince1970*1000) }
}

@MainActor private final class SystemRendezvousAttestationSDK: RendezvousAttestationSDK {
    var isSupported:Bool {
        #if os(iOS) && canImport(DeviceCheck)
        RendezvousNativeAdmission.isAdmitted && DCAppAttestService.shared.isSupported
        #else
        false
        #endif
    }
    func attest(key:String,hash:Data,deadline:TimeInterval) async throws -> Data {
        guard isSupported else { throw RendezvousAppAttestAdapter.Failure.unsupported }
        #if os(iOS) && canImport(DeviceCheck)
        let reply = RendezvousSDKReply()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                reply.start(continuation,deadline:deadline)
                guard reply.isWaiting, !Task.isCancelled else { reply.finish(.failure(.sdkFailed)); return }
                do {
                    try RendezvousNativeAdmission.perform {
                        DCAppAttestService.shared.attestKey(key,clientDataHash:hash) { data,error in
                            // Do not retain/forward arbitrary SDK error metadata.
                            let result:Result<Data,RendezvousAppAttestAdapter.Failure>
                            if let error = error as NSError? {
                                result = .failure(error.domain == DCErrorDomain && error.code == DCError.serverUnavailable.rawValue ? .sdkUnavailable : .sdkFailed)
                            } else if let data, !data.isEmpty, data.count <= 32768 {
                                result = .success(data)
                            } else { result = .failure(.sdkFailed) }
                            Task { @MainActor in reply.finish(result) }
                        }
                    }
                } catch { reply.finish(.failure(.sdkFailed)) }
            }
        } onCancel: { Task { @MainActor in reply.finish(.failure(.sdkFailed)) } }
        #else
        throw RendezvousAppAttestAdapter.Failure.unsupported
        #endif
    }
}

/// Single completion for cancellation/timeout/SDK callback races. A consumed
/// journal reservation stays consumed even if the SDK never calls back.
@MainActor final class RendezvousSDKReply {
    private var continuation:CheckedContinuation<Data,any Error>?
    private var timeout:Task<Void,Never>?
    private var finished = false
    var isWaiting:Bool { !finished && continuation != nil }
    func start(_ continuation:CheckedContinuation<Data,any Error>,deadline:TimeInterval) {
        guard !finished else { continuation.resume(throwing:RendezvousAppAttestAdapter.Failure.sdkFailed); return }
        self.continuation = continuation
        let remaining = deadline-ProcessInfo.processInfo.systemUptime
        guard remaining.isFinite, remaining > 0, remaining <= 120 else { finish(.failure(.sdkFailed)); return }
        timeout = Task { [weak self] in
            do { try await Task.sleep(for:.seconds(remaining)) } catch { return }
            self?.finish(.failure(.sdkFailed))
        }
    }
    func finish(_ result:Result<Data,RendezvousAppAttestAdapter.Failure>) {
        guard !finished else { return }; finished = true
        timeout?.cancel(); timeout = nil
        let pending = continuation; continuation = nil
        switch result {
        case .success(let data): pending?.resume(returning:data)
        case .failure(let error): pending?.resume(throwing:error)
        }
    }
}
