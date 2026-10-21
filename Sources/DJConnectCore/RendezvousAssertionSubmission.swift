import Foundation
#if os(iOS) && canImport(DeviceCheck)
import DeviceCheck
#endif

@MainActor protocol RendezvousAssertionSDK {
    var isSupported: Bool { get }
    func assertion(key: String, hash: Data, deadline: TimeInterval) async throws -> Data
}

/// Full per-key sign→submit, using only a previously verified active key and the
/// original server clientData bytes. This never generates or re-attests a key.
@MainActor public final class RendezvousAssertionSubmission {
    public enum Failure: Error, Sendable {
        case unsupported, staleContext, noActiveKey, invalidBinding, sdkFailed, uncertainOutcome
    }
    public struct Receipt: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
        public let operationIdentifier: String
        public var description: String { "RendezvousAcceptedOperation(redacted)" }
        public var debugDescription: String { description }
    }
    private let sdk: any RendezvousAssertionSDK
    private let service: DJConnectRendezvousService
    private let journal: RendezvousSubmissionJournal
    private let lifecycle: RendezvousKeyLifecycleJournal
    public init() {
        sdk = SystemRendezvousAssertionSDK(); service = .init()
        journal = .shared; lifecycle = .shared
    }
    init(sdk: any RendezvousAssertionSDK, service: DJConnectRendezvousService,
         journal: RendezvousSubmissionJournal, lifecycle: RendezvousKeyLifecycleJournal) {
        self.sdk = sdk; self.service = service; self.journal = journal; self.lifecycle = lifecycle
    }

    public func submit(qr: DJConnectRendezvousQR, envelope: DJConnectRendezvousDestination.Envelope,
                       appContext: Data, isCurrent: @escaping @MainActor @Sendable () -> Bool) async throws -> Receipt {
        try validate(qr: qr, isCurrent: isCurrent)
        guard let key = try await lifecycle.activeKey(appContext: appContext, at: Self.now()) else { throw Failure.noActiveKey }
        try validate(qr: qr, isCurrent: isCurrent)
        return try await RendezvousAppKeyOperations.shared.perform(keyIdentifier: key) { [self] in
            try await self.perform(key: key, qr: qr, envelope: envelope, appContext: appContext, isCurrent: isCurrent)
        }
    }
    private func perform(key: String, qr: DJConnectRendezvousQR, envelope: DJConnectRendezvousDestination.Envelope,
                         appContext: Data, isCurrent: @escaping @MainActor @Sendable () -> Bool) async throws -> Receipt {
        try validate(qr: qr, isCurrent: isCurrent)
        let handles = try await lifecycle.snapshot(appContext: appContext, at: Self.now())
        guard let handle = handles.first(where: { $0.phase == .active && $0.keyIdentifier == key }),
              let keyExpiry = handle.originalExpiryMS else { throw Failure.noActiveKey }
        func current() -> Bool { isCurrent() && Self.now() < keyExpiry }
        try validate(qr: qr, isCurrent: current)
        try await journal.requireAvailable(appContext: appContext, at: Self.now())
        try validate(qr: qr, isCurrent: current)
        let challenge = try await service.submitChallenge(qr: qr, keyID: key, envelope: envelope)
        try validate(qr: qr, challenge: challenge, isCurrent: current)
        let attempt = try await journal.begin(keyIdentifier: key, qr: qr, challenge: challenge,
                                              envelope: envelope, appContext: appContext, at: Self.now())
        try validate(qr: qr, challenge: challenge, isCurrent: current)
        let call = try await journal.reserveAssertion(attempt, appContext: appContext, at: Self.now())
        try validate(qr: qr, challenge: challenge, isCurrent: current)
        guard call.keyIdentifier == key, call.clientDataHash == challenge.clientDataHash,
              call.deadlineMS == challenge.expiresAtMS else { throw Failure.invalidBinding }
        let remaining = Double(min(qr.expiresAtMS, challenge.expiresAtMS, keyExpiry)-Self.now())/1000
        guard remaining > 0 else { throw Failure.staleContext }
        let deadline = min(qr.originalMonotonicDeadline, challenge.originalMonotonicDeadline,
            ProcessInfo.processInfo.systemUptime + min(remaining, 120))
        do {
            let proof = try await sdk.assertion(key: key, hash: call.clientDataHash, deadline: deadline)
            try validate(qr: qr, challenge: challenge, isCurrent: current)
            try await journal.completeAssertion(attempt, reservation: call.reservation, proof: proof,
                                                appContext: appContext, at: Self.now())
        } catch {
            // This write is cleanup only; its success cannot authorize anything.
            // Unknown SDK/completion results keep the consumed operation closed.
            try? await journal.completeAssertion(attempt, reservation: call.reservation, proof: nil,
                                                 appContext: appContext, at: Self.now())
            throw Failure.uncertainOutcome
        }
        try validate(qr: qr, challenge: challenge, isCurrent: current)
        let request = try await journal.reserveSubmission(attempt, appContext: appContext, at: Self.now())
        do {
            try validate(qr: qr, challenge: challenge, isCurrent: current)
            try await service.submit(originalBody: request.body, qr: qr, challenge: challenge,
                                     beforeDispatch: { [self] in
                try validate(qr: qr, challenge: challenge, isCurrent: current)
            })
            try validate(qr: qr, challenge: challenge, isCurrent: current)
        } catch {
            try? await journal.completeSubmission(attempt, reservation: request.reservation, accepted: false,
                                                  appContext: appContext, at: Self.now())
            throw Failure.uncertainOutcome
        }
        // A failed/uncertain completion write must not be retried or reported as
        // success. The original reserved operation remains recoverable evidence.
        try await journal.completeSubmission(attempt, reservation: request.reservation, accepted: true,
                                              appContext: appContext, at: Self.now())
        try validate(qr: qr, challenge: challenge, isCurrent: current)
        return Receipt(operationIdentifier: challenge.identifier)
    }
    private func validate(qr: DJConnectRendezvousQR, challenge: DJConnectRendezvousSubmitChallenge? = nil,
                          isCurrent: @MainActor () -> Bool) throws {
        try Task.checkCancellation()
        guard sdk.isSupported else { throw Failure.unsupported }
        guard isCurrent(), qr.isCurrent(), challenge.map({$0.isCurrent()}) ?? true else { throw Failure.staleContext }
    }
    private static func now() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}

/// The UI may stop waiting at its original deadline, but an actual late SDK
/// callback still owns this key. Do not start another assertion until it returns.
@MainActor final class RendezvousAssertionOccupancy {
    private var occupied: [String: UUID] = [:]
    func reserve(_ key: String) throws -> UUID {
        guard DJConnectRendezvousSubmitChallenge.canonicalKeyID(key), occupied[key] == nil else {
            throw RendezvousAssertionSubmission.Failure.sdkFailed
        }
        let id = UUID(); occupied[key] = id; return id
    }
    func complete(_ key: String, call: UUID) {
        if occupied[key] == call { occupied.removeValue(forKey: key) }
    }
}
@MainActor private final class SystemRendezvousAssertionSDK: RendezvousAssertionSDK {
    private static let occupancy = RendezvousAssertionOccupancy()
    var isSupported: Bool {
        #if os(iOS) && canImport(DeviceCheck)
        DCAppAttestService.shared.isSupported
        #else
        false
        #endif
    }
    func assertion(key: String, hash: Data, deadline: TimeInterval) async throws -> Data {
        guard isSupported else { throw RendezvousAssertionSubmission.Failure.unsupported }
        #if os(iOS) && canImport(DeviceCheck)
        let reply = RendezvousSDKReply()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, any Error>) in
                reply.start(continuation, deadline: deadline)
                guard reply.isWaiting, !Task.isCancelled else { reply.finish(.failure(.sdkFailed)); return }
                let call: UUID
                do { call = try Self.occupancy.reserve(key) }
                catch { reply.finish(.failure(.sdkFailed)); return }
                DCAppAttestService.shared.generateAssertion(key, clientDataHash: hash) { proof, error in
                    Task { @MainActor in
                        Self.occupancy.complete(key, call: call)
                        if error == nil, let proof, !proof.isEmpty, proof.count <= 4096 {
                            reply.finish(.success(proof))
                        } else { reply.finish(.failure(.sdkFailed)) }
                    }
                }
            }
        } onCancel: { Task { @MainActor in reply.finish(.failure(.sdkFailed)) } }
        #else
        throw RendezvousAssertionSubmission.Failure.unsupported
        #endif
    }
}
