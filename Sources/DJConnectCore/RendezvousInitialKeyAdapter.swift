import Foundation
#if os(iOS) && canImport(DeviceCheck)
import DeviceCheck
#endif

@MainActor protocol RendezvousGenerationSDK {
    var isSupported:Bool { get }
    func generate(deadline:TimeInterval) async throws -> String
}

/// Source-only initial-generation bridge; not wired to product preparation.
/// A caller must independently admit this app/environment and physical effect.
/// The shared installation slot spans legacy checks through initial enrollment.
/// This initial-only adapter never repairs, rotates, resets or adopts a lease.
@MainActor public final class RendezvousInitialKeyAdapter {
    public enum Failure:Error,Sendable { case unsupported, staleContext, legacyOccupancy, generationFailed }
    private let sdk:any RendezvousGenerationSDK
    private let historicalStateClear:@MainActor @Sendable () throws->Bool
    public init() {
        sdk = SystemRendezvousGenerationSDK()
        historicalStateClear = Self.noHistoricalDiagnosticState
    }
    init(sdk:any RendezvousGenerationSDK,
         historicalStateClear:@escaping @MainActor @Sendable () throws->Bool = { true }) {
        self.sdk = sdk; self.historicalStateClear = historicalStateClear
    }

    /// The caller's admission includes qualified stable app/environment, current
    /// foreground consent and the genuine effect grant. A fresh QR is not a grant.
    /// Any occupied/malformed/unreadable older journal blocks initial generation.
    /// There is no public injection of an empty legacy-occupancy result.
    public func generateInitialAndFinishEnrollment(
        qr:DJConnectRendezvousQR,appContext:Data,
        isAdmitted:@escaping @MainActor @Sendable ()->Bool,
        finishEnrollment:@escaping @MainActor @Sendable (UUID,String) async throws->Void
    ) async throws {
        try await generate(qr:qr,appContext:appContext,lifecycle:.shared,
            registration:.shared,recovery:.shared,repair:.shared,
            isAdmitted:isAdmitted,finishEnrollment:finishEnrollment)
    }
    func generate(qr:DJConnectRendezvousQR,appContext:Data,
        lifecycle:RendezvousKeyLifecycleJournal,registration:RendezvousRegistrationJournal,
        recovery:RendezvousRecoveryJournal,repair:RendezvousRepairJournal,
        isAdmitted:@escaping @MainActor @Sendable ()->Bool,
        finishEnrollment:@escaping @MainActor @Sendable (UUID,String) async throws->Void
    ) async throws {
        guard sdk.isSupported else { throw Failure.unsupported }
        guard RendezvousAppKeyOperations.initialEnrollmentLease == nil else { throw Failure.staleContext }
        // Not a key handle: fixed non-base64 namespace for installation-level
        // initial generation, separate from the eventual canonical per-key slot.
        try await RendezvousAppKeyOperations.shared.perform(
            keyIdentifier:RendezvousAppKeyOperations.installationAdmissionSlot) { [self] in
            let (identifier,key) = try await perform(qr:qr,appContext:appContext,lifecycle:lifecycle,
                registration:registration,recovery:recovery,repair:repair,isAdmitted:isAdmitted)
            try await finishInitialEnrollment(identifier:identifier,key:key,qr:qr,
                isAdmitted:isAdmitted,finishEnrollment:finishEnrollment)
        }
    }
    private func finishInitialEnrollment(identifier:UUID,key:String,qr:DJConnectRendezvousQR,
        isAdmitted:@escaping @MainActor @Sendable ()->Bool,
        finishEnrollment:@escaping @MainActor @Sendable (UUID,String) async throws->Void) async throws {
        try Task.checkCancellation()
        guard sdk.isSupported,isAdmitted(),qr.isCurrent() else { throw Failure.staleContext }
        let lease = RendezvousInitialEnrollmentLease(key:key,qr:qr)
        defer { lease.close() }
        // Keep already-queued legacy writers behind this enrollment. Only its
        // exact-key registration creation can reenter the held installation slot.
        try await RendezvousAppKeyOperations.$initialEnrollmentLease.withValue(lease) {
            try await finishEnrollment(identifier,key)
        }
        try Task.checkCancellation()
        guard sdk.isSupported,isAdmitted(),qr.isCurrent() else { throw Failure.staleContext }
    }
    private func perform(qr:DJConnectRendezvousQR,appContext:Data,
        lifecycle:RendezvousKeyLifecycleJournal,registration:RendezvousRegistrationJournal,
        recovery:RendezvousRecoveryJournal,repair:RendezvousRepairJournal,
        isAdmitted:@escaping @MainActor @Sendable ()->Bool
    ) async throws -> (UUID,String) {
        func validate() throws {
            try Task.checkCancellation()
            guard sdk.isSupported,isAdmitted(),qr.isCurrent() else { throw Failure.staleContext }
        }
        try validate()
        guard try await registration.snapshot(at:Self.now()) == nil else { throw Failure.legacyOccupancy }
        try validate()
        guard try await recovery.snapshot(at:Self.now()) == nil else { throw Failure.legacyOccupancy }
        try validate()
        guard try await repair.snapshot() == nil else { throw Failure.legacyOccupancy }
        try validate()
        guard try historicalStateClear() else { throw Failure.legacyOccupancy }
        try validate()
        let reservation = try await lifecycle.reserveGeneration(purpose:.initial,appContext:appContext,
            foreground:true,at:Self.now())
        // Durable occupancy exists before the SDK. Owner loss during persistence
        // leaves it occupied even if the subsequent SDK call never starts.
        try validate()
        let remaining = Double(qr.expiresAtMS-Self.now())/1000
        guard remaining > 0 else { throw Failure.staleContext }
        let deadline = min(qr.originalMonotonicDeadline,ProcessInfo.processInfo.systemUptime+min(remaining,120))
        let key:String
        do {
            key = try await sdk.generate(deadline:deadline)
            guard DJConnectRendezvousSubmitChallenge.canonicalKeyID(key) else { throw Failure.generationFailed }
        } catch {
            // No retry, fresh key or namespace reset after an unknown callback.
            // A failed cleanup write also leaves the original slot consumed.
            try await lifecycle.pauseRecovery(reservation.identifier,appContext:appContext,at:Self.now())
            throw Failure.generationFailed
        }
        // Preserve a known callback handle even when the UI owner was lost.
        // This is install-local accounting, not enrollment/active-key adoption.
        try await lifecycle.completeGeneration(reservation.identifier,keyIdentifier:key,appContext:appContext,at:Self.now())
        try validate()
        return (reservation.identifier,key)
    }
    // Preserve the historical host's stable occupied-attempt namespace. Presence
    // of any item (including a symlink), or an unreadable path, blocks generation.
    // Never copy, migrate, delete or reinterpret its private contents here.
    private static func noHistoricalDiagnosticState() throws -> Bool {
        guard let support = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first else {
            throw Failure.legacyOccupancy
        }
        return try historicalStateIsClear(at:support)
    }
    static func historicalStateIsClear(at support:URL) throws -> Bool {
        for (index,component) in ["DJConnect","DJConnect/APIBinaryQualification40380"].enumerated() {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath:support.appendingPathComponent(component).path)
                // Do not follow an unexpected parent link to another ledger.
                guard index == 0,attributes[.type] as? FileAttributeType == .typeDirectory else { return false }
            } catch let error as NSError {
                guard error.domain == NSCocoaErrorDomain,
                      [NSFileNoSuchFileError,NSFileReadNoSuchFileError].contains(error.code) else {
                    throw Failure.legacyOccupancy
                }
                return true
            }
        }
        return false
    }
    private static func now()->Int64 { Int64(Date().timeIntervalSince1970*1000) }
}

@MainActor private final class SystemRendezvousGenerationSDK:RendezvousGenerationSDK {
    var isSupported:Bool {
        #if os(iOS) && canImport(DeviceCheck)
        DCAppAttestService.shared.isSupported
        #else
        false
        #endif
    }
    func generate(deadline:TimeInterval) async throws -> String {
        guard isSupported else { throw RendezvousInitialKeyAdapter.Failure.unsupported }
        #if os(iOS) && canImport(DeviceCheck)
        let reply = RendezvousSDKReply()
        let data = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                reply.start(continuation,deadline:deadline)
                guard reply.isWaiting,!Task.isCancelled else { reply.finish(.failure(.sdkFailed)); return }
                DCAppAttestService.shared.generateKey { key,error in
                    let result:Result<Data,RendezvousAppAttestAdapter.Failure>
                    if error == nil,let key,DJConnectRendezvousSubmitChallenge.canonicalKeyID(key) {
                        result = .success(Data(key.utf8))
                    } else { result = .failure(.sdkFailed) }
                    Task { @MainActor in reply.finish(result) }
                }
            }
        } onCancel: { Task { @MainActor in reply.finish(.failure(.sdkFailed)) } }
        guard let key = String(data:data,encoding:.utf8),DJConnectRendezvousSubmitChallenge.canonicalKeyID(key) else {
            throw RendezvousInitialKeyAdapter.Failure.generationFailed
        }
        return key
        #else
        throw RendezvousInitialKeyAdapter.Failure.unsupported
        #endif
    }
}
