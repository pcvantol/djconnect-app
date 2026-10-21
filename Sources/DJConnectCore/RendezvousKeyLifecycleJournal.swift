import Foundation

/// Install-local lifecycle accounting, not SDK permission or proof of enrollment.
/// No hardware call, key adoption from a bare handle, HTTP or journal reset.
/// The owner must separately qualify app/environment and actual server receipts.
/// An empty lifecycle row does not prove legacy journals/handles are empty;
/// the future orchestrator must reconcile those before initial generation.
public actor RendezvousKeyLifecycleJournal {
    public static let shared = RendezvousKeyLifecycleJournal(storage:RendezvousRepairKeychainStorage(
        service:RendezvousBuildProfile.storageNamespace + ".key-lifecycle",account:"key-lifecycle-v1"))
    public enum Purpose:String,Codable,Sendable { case initial, replacement, rollover }
    public enum Phase:String,Codable,Sendable {
        case generationPending, generationUnknown, enrollmentPending, registrationUncertain, recoveryPaused, active, expired
    }
    public enum Failure:Error,Sendable { case invalidData, invalidMaterial, contextChanged, unavailable, wrongAttempt, cooldown, capacity, staleClock }
    public struct Generation:Sendable,CustomStringConvertible,CustomDebugStringConvertible {
        public let identifier:UUID
        public let purpose:Purpose
        public var description:String { "RendezvousKeyGeneration(redacted)" }
        public var debugDescription:String { description }
    }
    public struct Handle:Sendable,CustomStringConvertible,CustomDebugStringConvertible {
        public let identifier:UUID
        public let keyIdentifier:String?
        public let phase:Phase
        public let originalExpiryMS:Int64?
        public var description:String { "RendezvousKeyHandle(redacted)" }
        public var debugDescription:String { description }
    }
    private let storage:any RendezvousRepairStorage
    private static let maximumBytes = 16_384
    init(storage:any RendezvousRepairStorage) { self.storage = storage }

    /// appContext is an already-qualified app/environment policy digest, not a
    /// user/Profile/device/HA identifier or a source of environment authority.
    /// Use the reviewed stable app identity/environment policy, not transient QR,
    /// Profile, route or build values; a valid app update preserves that binding.
    /// One fixed storage address refuses a changed digest; changing context must
    /// not manufacture a new empty ledger. All starts require foreground work.
    public func reserveGeneration(purpose:Purpose,appContext:Data,foreground:Bool,
                                  explicitRepair:Bool = false,at nowMS:Int64) throws -> Generation {
        try LifecycleRecord.checkTime(nowMS)
        guard appContext.count == 32, foreground else { throw Failure.invalidMaterial }
        guard var record = try read() else {
            guard purpose == .initial else { throw Failure.unavailable }
            let record = LifecycleRecord(context:appContext,at:nowMS)
            try persist(record)
            return .init(identifier:record.handles[0].id,purpose:.initial)
        }
        try record.observe(context:appContext,at:nowMS)
        let result = Result<Generation,any Error> {
            guard purpose != .initial else { throw Failure.unavailable }
            guard record.handles.count == 1 else { throw Failure.capacity }
            let old = record.handles[0]
            switch purpose {
            case .initial: throw Failure.unavailable
            case .replacement:
                guard explicitRepair, old.phase == .recoveryPaused || old.phase == .generationUnknown,
                      let paused = old.pausedAtMS else { throw Failure.unavailable }
                guard nowMS - paused >= LifecycleRecord.day,
                      record.lastReplacementAtMS.map({nowMS - $0 >= LifecycleRecord.day}) ?? true else { throw Failure.cooldown }
                // Consume the replacement allowance BEFORE any SDK generation,
                // including when the subsequent call never returns a handle.
                record.lastReplacementAtMS = nowMS
            case .rollover:
                guard old.phase == .active || old.phase == .expired, let expiry = old.expiryMS,
                      nowMS >= expiry - 3 * LifecycleRecord.day else { throw Failure.unavailable }
            }
            let handle = LifecycleHandle(purpose:purpose,at:nowMS)
            record.handles.append(handle)
            return .init(identifier:handle.id,purpose:purpose)
        }
        try persist(record)
        return try result.get()
    }

    /// Record only the callback of the original consumed generation reservation.
    /// A crash/unknown callback leaves that reservation occupied across restart.
    public func completeGeneration(_ id:UUID,keyIdentifier:String,appContext:Data,at nowMS:Int64) throws {
        try mutate(id,context:appContext,at:nowMS) { record,index in
            guard record.handles[index].phase == .generationPending,
                  DJConnectRendezvousSubmitChallenge.canonicalKeyID(keyIdentifier),
                  !record.handles.contains(where:{$0.key == keyIdentifier}) else { throw Failure.invalidMaterial }
            record.handles[index].key = keyIdentifier
            record.handles[index].phase = .enrollmentPending
        }
    }

    /// Bind the one original enrollment window. Re-entry may echo the same
    /// deadline but cannot replace it with another challenge/later deadline.
    /// The enrollment journal owns the exact nonce/ID/request and SDK accounting.
    public func bindEnrollment(_ id:UUID,deadlineMS:Int64,appContext:Data,at nowMS:Int64) throws {
        try mutate(id,context:appContext,at:nowMS) { record,index in
            guard record.handles[index].phase == .enrollmentPending,
                  deadlineMS > nowMS, deadlineMS - nowMS <= 120_000,
                  record.handles[index].enrollmentDeadlineMS.map({$0 == deadlineMS}) ?? true else { throw Failure.invalidMaterial }
            record.handles[index].enrollmentDeadlineMS = deadlineMS
            if record.handles[index].enrollmentBoundAtMS == nil { record.handles[index].enrollmentBoundAtMS = nowMS }
        }
    }
    public func markRegistrationUncertain(_ id:UUID,appContext:Data,at nowMS:Int64) throws {
        try mutate(id,context:appContext,at:nowMS) { record,index in
            guard [.enrollmentPending,.registrationUncertain].contains(record.handles[index].phase),
                  record.handles[index].enrollmentDeadlineMS != nil else { throw Failure.unavailable }
            record.handles[index].phase = .registrationUncertain
        }
    }

    /// Called after qualified recovery failure (or an unknown generation result),
    /// never inferred from a generic sender-proof rejection. Re-entry preserves
    /// the original pause. Explicit same-key repair attempts remain separately
    /// bounded by RendezvousRepairJournal; this method grants none of them.
    public func pauseRecovery(_ id:UUID,appContext:Data,at nowMS:Int64) throws {
        try mutate(id,context:appContext,at:nowMS) { record,index in
            switch record.handles[index].phase {
            case .generationPending, .generationUnknown:
                record.handles[index].phase = .generationUnknown
            case .registrationUncertain, .recoveryPaused, .active:
                record.handles[index].phase = .recoveryPaused
            default: throw Failure.unavailable
            }
            if record.handles[index].pausedAtMS == nil { record.handles[index].pausedAtMS = nowMS }
        }
    }

    /// Caller-reported independently validated registration/recovery receipt.
    /// No bare SDK handle/attestation can activate a key. A known original expiry
    /// is immutable; an uncertain enrollment recovery is bounded by its original
    /// enrollment window plus the server's maximum30-day lifetime.
    public func recordVerifiedActivation(_ id:UUID,originalExpiryMS:Int64,recovered:Bool,
                                         appContext:Data,at nowMS:Int64) throws {
        try mutate(id,context:appContext,at:nowMS) { record,index in
            var handle = record.handles[index]
            guard let deadline = handle.enrollmentDeadlineMS, handle.key != nil,
                  originalExpiryMS > nowMS,
                  originalExpiryMS - nowMS <= 30 * LifecycleRecord.day,
                  originalExpiryMS <= deadline + 30 * LifecycleRecord.day,
                  handle.expiryMS.map({$0 == originalExpiryMS}) ?? true else { throw Failure.invalidMaterial }
            if recovered {
                guard [.registrationUncertain,.recoveryPaused,.active].contains(handle.phase) else { throw Failure.unavailable }
            } else {
                guard handle.phase == .enrollmentPending, nowMS < deadline else { throw Failure.unavailable }
            }
            handle.phase = .active; handle.expiryMS = originalExpiryMS
            if handle.firstVerifiedAtMS == nil { handle.firstVerifiedAtMS = nowMS }
            // Acknowledged replacement retires the old LOCAL reference only.
            // This is not remote revocation or hardware key erasure. Keep the
            // global replacement timestamp so another pause cannot reset it.
            if index == record.handles.count - 1 { record.handles = [handle] }
            else { record.handles[index] = handle } // Recovery of old key cannot discard an unresolved replacement.
        }
    }
    public func snapshot(appContext:Data,at nowMS:Int64) throws -> [Handle] {
        try LifecycleRecord.checkTime(nowMS)
        guard appContext.count == 32 else { throw Failure.invalidMaterial }
        guard var record = try read() else { return [] }
        try record.observe(context:appContext,at:nowMS)
        try persist(record)
        return record.handles.map { .init(identifier:$0.id,keyIdentifier:$0.key,phase:$0.phase,originalExpiryMS:$0.expiryMS) }
    }
    public func activeKey(appContext:Data,at nowMS:Int64) throws -> String? {
        try snapshot(appContext:appContext,at:nowMS).first(where:{$0.phase == .active})?.keyIdentifier
    }

    private func mutate(_ id:UUID,context:Data,at nowMS:Int64,
                        operation:(inout LifecycleRecord,Int)throws->Void) throws {
        guard var record = try read() else { throw Failure.unavailable }
        try record.observe(context:context,at:nowMS)
        let result = Result<Void,any Error> {
            guard let index = record.handles.firstIndex(where:{$0.id == id}) else { throw Failure.wrongAttempt }
            try operation(&record,index)
        }
        // Persist observations/expiry even when an operation is refused. Never
        // return a reservation or adopted key after a failed/uncertain write.
        try persist(record)
        try result.get()
    }
    private func read() throws -> LifecycleRecord? {
        guard let data = try storage.read() else { return nil }
        guard !data.isEmpty, data.count <= Self.maximumBytes else { throw Failure.invalidData }
        do {
            let record = try JSONDecoder().decode(LifecycleRecord.self,from:data)
            try record.validate(); return record
        } catch { throw Failure.invalidData }
    }
    private func persist(_ record:LifecycleRecord) throws {
        try record.validate()
        let data = try JSONEncoder().encode(record)
        guard data.count <= Self.maximumBytes else { throw Failure.invalidData }
        try storage.write(data)
    }
}

private struct LifecycleHandle:Codable {
    let id:UUID
    let purpose:RendezvousKeyLifecycleJournal.Purpose
    let generatedAtMS:Int64
    var phase:RendezvousKeyLifecycleJournal.Phase = .generationPending
    var key:String?
    var enrollmentDeadlineMS:Int64?
    var enrollmentBoundAtMS:Int64?
    var firstVerifiedAtMS:Int64?
    var expiryMS:Int64?
    var pausedAtMS:Int64?
    init(purpose:RendezvousKeyLifecycleJournal.Purpose,at nowMS:Int64) {
        id = UUID(); self.purpose = purpose; generatedAtMS = nowMS
    }
}
private struct LifecycleRecord:Codable {
    static let day:Int64 = 86_400_000
    private let schemaVersion:Int
    let context:Data
    let firstGenerationAtMS:Int64
    var lastObservedMS:Int64
    var lastReplacementAtMS:Int64?
    var handles:[LifecycleHandle]
    init(context:Data,at nowMS:Int64) {
        schemaVersion = 1; self.context = context; firstGenerationAtMS = nowMS; lastObservedMS = nowMS
        handles = [.init(purpose:.initial,at:nowMS)]
    }
    static func checkTime(_ value:Int64) throws {
        // Leave arithmetic headroom for the fixed30-day upper bound.
        guard value >= 0, value <= 9_007_199_254_740_991 - 31 * day else { throw RendezvousKeyLifecycleJournal.Failure.invalidMaterial }
    }
    mutating func observe(context:Data,at nowMS:Int64) throws {
        try Self.checkTime(nowMS)
        guard context == self.context else { throw RendezvousKeyLifecycleJournal.Failure.contextChanged }
        guard nowMS >= lastObservedMS else { throw RendezvousKeyLifecycleJournal.Failure.staleClock }
        lastObservedMS = nowMS
        for index in handles.indices {
            if handles[index].phase == .enrollmentPending,
               let deadline = handles[index].enrollmentDeadlineMS, nowMS >= deadline {
                handles[index].phase = .registrationUncertain
            }
            if let expiry = handles[index].expiryMS, nowMS >= expiry {
                handles[index].phase = .expired
                handles[index].key = nil // Local reference disposal, not hardware erasure.
            }
        }
    }
    func validate() throws {
        func require(_ value:Bool) throws { if !value { throw RendezvousKeyLifecycleJournal.Failure.invalidData } }
        try require(schemaVersion == 1 && context.count == 32 && (1...2).contains(handles.count))
        try Self.checkTime(firstGenerationAtMS); try Self.checkTime(lastObservedMS)
        try require(lastObservedMS >= firstGenerationAtMS && Set(handles.map(\.id)).count == handles.count)
        if let replacement = lastReplacementAtMS { try require(replacement >= firstGenerationAtMS && replacement <= lastObservedMS) }
        let keys = handles.compactMap(\.key)
        try require(Set(keys).count == keys.count)
        try require(handles.filter({$0.phase == .active}).count <= 1)
        // Bound every persisted timestamp before subtraction/addition, including
        // malformed records that would otherwise overflow Int64 during validation.
        for handle in handles {
            try Self.checkTime(handle.generatedAtMS)
            for value in [handle.enrollmentDeadlineMS,handle.enrollmentBoundAtMS,
                          handle.firstVerifiedAtMS,handle.expiryMS,handle.pausedAtMS].compactMap({$0}) {
                try Self.checkTime(value)
            }
        }
        if handles.count == 2 {
            try require(handles[1].purpose != .initial && handles[1].expiryMS == nil)
            switch handles[1].purpose {
            case .initial: throw RendezvousKeyLifecycleJournal.Failure.invalidData
            case .replacement:
                try require(handles[0].pausedAtMS != nil)
                try require(handles[1].generatedAtMS - handles[0].pausedAtMS! >= Self.day)
            case .rollover:
                try require(handles[0].expiryMS != nil && handles[1].generatedAtMS >= handles[0].expiryMS! - 3 * Self.day)
            }
        }
        var previous = firstGenerationAtMS
        for handle in handles {
            try require(handle.generatedAtMS >= previous && handle.generatedAtMS <= lastObservedMS)
            previous = handle.generatedAtMS
            if let key = handle.key { try require(DJConnectRendezvousSubmitChallenge.canonicalKeyID(key)) }
            if let pause = handle.pausedAtMS { try require(pause >= handle.generatedAtMS && pause <= lastObservedMS) }
            try require((handle.enrollmentDeadlineMS == nil) == (handle.enrollmentBoundAtMS == nil))
            try require((handle.expiryMS == nil) == (handle.firstVerifiedAtMS == nil))
            if let deadline = handle.enrollmentDeadlineMS, let bound = handle.enrollmentBoundAtMS {
                try require(bound >= handle.generatedAtMS && bound <= lastObservedMS &&
                    deadline > bound && deadline - bound <= 120_000)
            }
            if let verified = handle.firstVerifiedAtMS {
                try require(verified >= handle.generatedAtMS && verified <= lastObservedMS &&
                    handle.expiryMS! > verified && handle.expiryMS! - verified <= 30 * Self.day)
            }
            if let expiry = handle.expiryMS {
                try require(handle.enrollmentDeadlineMS != nil && expiry > handle.generatedAtMS &&
                    expiry <= handle.enrollmentDeadlineMS! + 30 * Self.day)
            }
            switch handle.phase {
            case .generationPending:
                try require(handle.key == nil && handle.enrollmentDeadlineMS == nil && handle.expiryMS == nil && handle.pausedAtMS == nil)
            case .generationUnknown:
                try require(handle.key == nil && handle.enrollmentDeadlineMS == nil && handle.expiryMS == nil && handle.pausedAtMS != nil)
            case .enrollmentPending:
                try require(handle.key != nil && handle.expiryMS == nil && handle.pausedAtMS == nil)
            case .registrationUncertain:
                try require(handle.key != nil && handle.enrollmentDeadlineMS != nil && handle.expiryMS == nil)
            case .recoveryPaused:
                try require(handle.key != nil && handle.enrollmentDeadlineMS != nil && handle.pausedAtMS != nil)
            case .active:
                try require(handle.key != nil && handle.expiryMS.map({$0 > lastObservedMS}) == true)
            case .expired:
                try require(handle.key == nil && handle.expiryMS.map({$0 <= lastObservedMS}) == true)
            }
            if handle.purpose == .replacement {
                try require(lastReplacementAtMS.map({$0 >= handle.generatedAtMS}) == true)
            }
        }
    }
}
