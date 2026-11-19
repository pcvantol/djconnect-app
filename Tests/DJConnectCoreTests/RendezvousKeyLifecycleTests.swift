import Foundation
import Testing
@testable import DJConnectCore

private final class LifecycleStore:RendezvousRepairStorage,@unchecked Sendable {
    enum Failure:Error { case unavailable }
    private let lock = NSLock()
    private var data:Data?
    private var failWrite = false
    private var commitThenFail = false
    func faults(before:Bool = false,after:Bool = false) { lock.withLock { failWrite = before; commitThenFail = after } }
    func read() throws -> Data? { lock.withLock { data } }
    func write(_ value:Data) throws {
        try lock.withLock {
            if failWrite { throw Failure.unavailable }
            data = value
            if commitThenFail { throw Failure.unavailable }
        }
    }
    func change(_ operation:(inout [String:Any])->Void) throws {
        try lock.withLock {
            var object = try JSONSerialization.jsonObject(with:#require(data)) as! [String:Any]
            operation(&object); data = try JSONSerialization.data(withJSONObject:object)
        }
    }
}
private let lifecycleContext = Data(repeating:9,count:32)
private let lifecycleDay:Int64 = 86_400_000
private func lifecycleKey(_ number:UInt8)->String { Data(repeating:number,count:32).base64EncodedString() }
private func lifecycleEnroll(_ subject:RendezvousKeyLifecycleJournal,_ generation:RendezvousKeyLifecycleJournal.Generation,
                             key:UInt8 = 1,at now:Int64 = 1000) async throws {
    try await subject.completeGeneration(generation.identifier,keyIdentifier:lifecycleKey(key),appContext:lifecycleContext,at:now+1)
    try await subject.bindEnrollment(generation.identifier,deadlineMS:now+120000,appContext:lifecycleContext,at:now+2)
}
private func lifecycleActive(_ subject:RendezvousKeyLifecycleJournal) async throws -> (UUID,Int64) {
    let initial = try await subject.reserveGeneration(purpose:.initial,appContext:lifecycleContext,foreground:true,at:1000)
    try await lifecycleEnroll(subject,initial)
    let expiry:Int64 = 2000+30*lifecycleDay
    try await subject.recordVerifiedActivation(initial.identifier,originalExpiryMS:expiry,recovered:false,appContext:lifecycleContext,at:2000)
    return (initial.identifier,expiry)
}

@Test func rendezvousLifecycleInitialReservationSurvivesRestartAndUnknownCallback() async throws {
    let store = LifecycleStore(), subject = RendezvousKeyLifecycleJournal(storage:store)
    let reservation = try await subject.reserveGeneration(purpose:.initial,appContext:lifecycleContext,foreground:true,at:1000)
    let restored = RendezvousKeyLifecycleJournal(storage:store)
    await #expect(throws:(any Error).self) {
        try await restored.reserveGeneration(purpose:.initial,appContext:lifecycleContext,foreground:true,at:1001)
    }
    #expect(try await restored.activeKey(appContext:lifecycleContext,at:1001) == nil)
    let state = try await restored.snapshot(appContext:lifecycleContext,at:1002)
    #expect(state.count == 1); #expect(state[0].identifier == reservation.identifier)
    #expect(state[0].phase == .generationPending)
    #expect(!state[0].description.contains(lifecycleKey(1)))
}
@Test func rendezvousLifecycleUncertainWriteDoesNotReleaseAnotherGeneration() async throws {
    for uncertain in [false,true] {
        let store = LifecycleStore(), subject = RendezvousKeyLifecycleJournal(storage:store)
        store.faults(before:!uncertain,after:uncertain)
        await #expect(throws:(any Error).self) {
            try await subject.reserveGeneration(purpose:.initial,appContext:lifecycleContext,foreground:true,at:1000)
        }
        store.faults()
        let restored = RendezvousKeyLifecycleJournal(storage:store)
        if uncertain {
            await #expect(throws:(any Error).self) {
                try await restored.reserveGeneration(purpose:.initial,appContext:lifecycleContext,foreground:true,at:1001)
            }
            #expect(try await restored.snapshot(appContext:lifecycleContext,at:1002).count == 1)
        } else {
            #expect(try await restored.snapshot(appContext:lifecycleContext,at:1001).isEmpty)
        }
    }
}
@Test func rendezvousLifecycleHandleAloneCannotActivateOrChangeAppContext() async throws {
    let subject = RendezvousKeyLifecycleJournal(storage:LifecycleStore())
    let initial = try await subject.reserveGeneration(purpose:.initial,appContext:lifecycleContext,foreground:true,at:1000)
    try await subject.completeGeneration(initial.identifier,keyIdentifier:lifecycleKey(1),appContext:lifecycleContext,at:1001)
    await #expect(throws:(any Error).self) {
        try await subject.recordVerifiedActivation(initial.identifier,originalExpiryMS:30*lifecycleDay,recovered:false,appContext:lifecycleContext,at:1002)
    }
    await #expect(throws:(any Error).self) {
        try await subject.completeGeneration(initial.identifier,keyIdentifier:lifecycleKey(2),appContext:lifecycleContext,at:1003)
    }
    await #expect(throws:(any Error).self) {
        try await subject.snapshot(appContext:Data(repeating:8,count:32),at:1004)
    }
    #expect(try await subject.snapshot(appContext:lifecycleContext,at:1004)[0].keyIdentifier == lifecycleKey(1))
}
@Test func rendezvousLifecycleEnrollmentDeadlineIsImmutableAndExpiryDoesNotRenew() async throws {
    let subject = RendezvousKeyLifecycleJournal(storage:LifecycleStore())
    let initial = try await subject.reserveGeneration(purpose:.initial,appContext:lifecycleContext,foreground:true,at:1000)
    try await lifecycleEnroll(subject,initial)
    await #expect(throws:(any Error).self) {
        try await subject.bindEnrollment(initial.identifier,deadlineMS:122000,appContext:lifecycleContext,at:2000)
    }
    await #expect(throws:(any Error).self) {
        try await subject.recordVerifiedActivation(initial.identifier,originalExpiryMS:30*lifecycleDay,recovered:false,appContext:lifecycleContext,at:121000)
    }
    #expect(try await subject.snapshot(appContext:lifecycleContext,at:121000)[0].phase == .registrationUncertain)
    try await subject.recordVerifiedActivation(initial.identifier,originalExpiryMS:30*lifecycleDay,recovered:true,appContext:lifecycleContext,at:121001)
    await #expect(throws:(any Error).self) {
        try await subject.recordVerifiedActivation(initial.identifier,originalExpiryMS:30*lifecycleDay+1,recovered:true,appContext:lifecycleContext,at:121002)
    }
    #expect(try await subject.snapshot(appContext:lifecycleContext,at:121003)[0].originalExpiryMS == 30*lifecycleDay)
}
@Test func rendezvousLifecycleRolloverStartsOnlyAtDay27ForegroundAndKeepsOldKey() async throws {
    let subject = RendezvousKeyLifecycleJournal(storage:LifecycleStore())
    let (_,expiry) = try await lifecycleActive(subject)
    let eligible = expiry-3*lifecycleDay
    await #expect(throws:(any Error).self) {
        try await subject.reserveGeneration(purpose:.rollover,appContext:lifecycleContext,foreground:true,at:eligible-1)
    }
    await #expect(throws:(any Error).self) {
        try await subject.reserveGeneration(purpose:.rollover,appContext:lifecycleContext,foreground:false,at:eligible)
    }
    let rollover = try await subject.reserveGeneration(purpose:.rollover,appContext:lifecycleContext,foreground:true,at:eligible)
    #expect(rollover.purpose == .rollover)
    #expect(try await subject.activeKey(appContext:lifecycleContext,at:eligible) == lifecycleKey(1))
    #expect(try await subject.snapshot(appContext:lifecycleContext,at:eligible).count == 2)
    await #expect(throws:(any Error).self) {
        try await subject.reserveGeneration(purpose:.rollover,appContext:lifecycleContext,foreground:true,at:eligible+1)
    }
}
@Test func rendezvousLifecycleDay30DisposesLocalReferenceWithoutRenewal() async throws {
    let subject = RendezvousKeyLifecycleJournal(storage:LifecycleStore())
    let (_,expiry) = try await lifecycleActive(subject)
    #expect(try await subject.activeKey(appContext:lifecycleContext,at:expiry-1) == lifecycleKey(1))
    #expect(try await subject.activeKey(appContext:lifecycleContext,at:expiry) == nil)
    let state = try await subject.snapshot(appContext:lifecycleContext,at:expiry)
    #expect(state[0].phase == .expired); #expect(state[0].keyIdentifier == nil)
    _ = try await subject.reserveGeneration(purpose:.rollover,appContext:lifecycleContext,foreground:true,at:expiry+1)
}
@Test func rendezvousLifecyclePauseAndReplacementDoNotResetAcrossRestart() async throws {
    let store = LifecycleStore(), subject = RendezvousKeyLifecycleJournal(storage:store)
    let first = try await subject.reserveGeneration(purpose:.initial,appContext:lifecycleContext,foreground:true,at:1000)
    try await subject.pauseRecovery(first.identifier,appContext:lifecycleContext,at:2000)
    try await subject.pauseRecovery(first.identifier,appContext:lifecycleContext,at:3000)
    await #expect(throws:(any Error).self) {
        try await subject.completeGeneration(first.identifier,keyIdentifier:lifecycleKey(1),appContext:lifecycleContext,at:3001)
    }
    let restored = RendezvousKeyLifecycleJournal(storage:store)
    await #expect(throws:(any Error).self) {
        try await restored.reserveGeneration(purpose:.replacement,appContext:lifecycleContext,foreground:true,explicitRepair:true,at:2000+lifecycleDay-1)
    }
    await #expect(throws:(any Error).self) {
        try await restored.reserveGeneration(purpose:.replacement,appContext:lifecycleContext,foreground:true,at:2000+lifecycleDay)
    }
    let second = try await restored.reserveGeneration(purpose:.replacement,appContext:lifecycleContext,foreground:true,explicitRepair:true,at:2000+lifecycleDay)
    try await restored.pauseRecovery(second.identifier,appContext:lifecycleContext,at:2001+lifecycleDay)
    await #expect(throws:(any Error).self) {
        try await restored.reserveGeneration(purpose:.replacement,appContext:lifecycleContext,foreground:true,explicitRepair:true,at:4000+3*lifecycleDay)
    }
    #expect(try await restored.snapshot(appContext:lifecycleContext,at:4001+3*lifecycleDay).count == 2)
}
@Test func rendezvousLifecycleOldKeyRecoveryCannotDiscardUnresolvedReplacement() async throws {
    let subject = RendezvousKeyLifecycleJournal(storage:LifecycleStore())
    let (old,expiry) = try await lifecycleActive(subject)
    try await subject.pauseRecovery(old,appContext:lifecycleContext,at:3000)
    let next = try await subject.reserveGeneration(purpose:.replacement,appContext:lifecycleContext,foreground:true,explicitRepair:true,at:3000+lifecycleDay)
    try await subject.recordVerifiedActivation(old,originalExpiryMS:expiry,recovered:true,appContext:lifecycleContext,at:3001+lifecycleDay)
    let state = try await subject.snapshot(appContext:lifecycleContext,at:3002+lifecycleDay)
    #expect(state.count == 2); #expect(state[1].identifier == next.identifier)
    #expect(try await subject.activeKey(appContext:lifecycleContext,at:3002+lifecycleDay) == lifecycleKey(1))
    await #expect(throws:(any Error).self) {
        try await subject.reserveGeneration(purpose:.rollover,appContext:lifecycleContext,foreground:true,at:expiry-2*lifecycleDay)
    }
}
@Test func rendezvousLifecycleAcknowledgedReplacementRetiresOnlyOldLocalReference() async throws {
    let subject = RendezvousKeyLifecycleJournal(storage:LifecycleStore())
    let (old,_) = try await lifecycleActive(subject)
    try await subject.pauseRecovery(old,appContext:lifecycleContext,at:3000)
    let started = 3000+lifecycleDay
    let next = try await subject.reserveGeneration(purpose:.replacement,appContext:lifecycleContext,foreground:true,explicitRepair:true,at:started)
    try await lifecycleEnroll(subject,next,key:2,at:started)
    let expiry = started+1000+30*lifecycleDay
    try await subject.recordVerifiedActivation(next.identifier,originalExpiryMS:expiry,recovered:false,appContext:lifecycleContext,at:started+1000)
    let state = try await subject.snapshot(appContext:lifecycleContext,at:started+1001)
    #expect(state.count == 1); #expect(state[0].keyIdentifier == lifecycleKey(2))
    try await subject.pauseRecovery(next.identifier,appContext:lifecycleContext,at:started+1002)
    await #expect(throws:(any Error).self) {
        try await subject.reserveGeneration(purpose:.replacement,appContext:lifecycleContext,foreground:true,explicitRepair:true,at:started+lifecycleDay-1)
    }
}
@Test func rendezvousLifecycleRejectsRollbackAndMalformedPersistence() async throws {
    let store = LifecycleStore(), subject = RendezvousKeyLifecycleJournal(storage:store)
    _ = try await subject.reserveGeneration(purpose:.initial,appContext:lifecycleContext,foreground:true,at:1000)
    _ = try await subject.snapshot(appContext:lifecycleContext,at:2000)
    await #expect(throws:(any Error).self) { try await subject.snapshot(appContext:lifecycleContext,at:1999) }
    try store.change { $0["schemaVersion"] = 2 }
    await #expect(throws:(any Error).self) { try await subject.snapshot(appContext:lifecycleContext,at:2001) }
}

@Test(arguments:["schema","third-handle","unbounded-enrollment","extended-lease","future-pause"])
func rendezvousLifecycleRefusesStructurallyForgedStoredHistory(caseName:String) async throws {
    let store = LifecycleStore(), subject = RendezvousKeyLifecycleJournal(storage:store)
    _ = try await lifecycleActive(subject)
    try store.change { object in
        var handles = object["handles"] as! [[String:Any]]
        switch caseName {
        case "schema": object["schemaVersion"] = 2
        case "third-handle":
            var second = handles[0]; second["id"] = UUID().uuidString
            var third = handles[0]; third["id"] = UUID().uuidString
            object["handles"] = handles + [second,third]
        case "unbounded-enrollment":
            handles[0]["enrollmentDeadlineMS"] = Int64(9_000_000_000_000)
            object["handles"] = handles
        case "extended-lease":
            handles[0]["expiryMS"] = Int64(2001+30*lifecycleDay)
            object["handles"] = handles
        default:
            handles[0]["phase"] = "recoveryPaused"; handles[0]["pausedAtMS"] = 9999
            object["handles"] = handles
        }
    }
    let restored = RendezvousKeyLifecycleJournal(storage:store)
    await #expect(throws:(any Error).self) { try await restored.snapshot(appContext:lifecycleContext,at:3000) }
}
@Test func rendezvousLifecycleActivationWriteUncertaintyCannotReturnActiveKey() async throws {
    let store = LifecycleStore(), subject = RendezvousKeyLifecycleJournal(storage:store)
    let initial = try await subject.reserveGeneration(purpose:.initial,appContext:lifecycleContext,foreground:true,at:1000)
    try await lifecycleEnroll(subject,initial)
    store.faults(after:true)
    await #expect(throws:(any Error).self) {
        try await subject.recordVerifiedActivation(initial.identifier,originalExpiryMS:2000+30*lifecycleDay,
            recovered:false,appContext:lifecycleContext,at:2000)
    }
    await #expect(throws:(any Error).self) { try await subject.activeKey(appContext:lifecycleContext,at:2001) }
    store.faults()
    let restored = RendezvousKeyLifecycleJournal(storage:store)
    #expect(try await restored.activeKey(appContext:lifecycleContext,at:2002) == lifecycleKey(1))
    await #expect(throws:(any Error).self) {
        try await restored.reserveGeneration(purpose:.initial,appContext:lifecycleContext,foreground:true,at:2003)
    }
}

@Test func rendezvousLifecycleChangedContextAndBackgroundCannotAllocate() async throws {
    let subject = RendezvousKeyLifecycleJournal(storage:LifecycleStore())
    await #expect(throws:(any Error).self) {
        try await subject.reserveGeneration(purpose:.initial,appContext:lifecycleContext,foreground:false,at:1000)
    }
    #expect(try await subject.snapshot(appContext:lifecycleContext,at:1000).isEmpty)
    _ = try await subject.reserveGeneration(purpose:.initial,appContext:lifecycleContext,foreground:true,at:1001)
    await #expect(throws:(any Error).self) {
        try await subject.reserveGeneration(purpose:.initial,appContext:Data(repeating:7,count:32),foreground:true,at:1002)
    }
    #expect(try await subject.snapshot(appContext:lifecycleContext,at:1002).count == 1)
}
@Test func rendezvousLifecycleUncertainEnrollmentDoesNotGrantReplacement() async throws {
    let subject = RendezvousKeyLifecycleJournal(storage:LifecycleStore())
    let first = try await subject.reserveGeneration(purpose:.initial,appContext:lifecycleContext,foreground:true,at:1000)
    try await lifecycleEnroll(subject,first)
    try await subject.markRegistrationUncertain(first.identifier,appContext:lifecycleContext,at:2000)
    await #expect(throws:(any Error).self) {
        try await subject.reserveGeneration(purpose:.replacement,appContext:lifecycleContext,foreground:true,
            explicitRepair:true,at:2000+2*lifecycleDay)
    }
    #expect(try await subject.snapshot(appContext:lifecycleContext,at:2001+2*lifecycleDay).count == 1)
}
@Test(arguments:[Int64(-1),2000,2000+30*lifecycleDay+1,Int64.max])
func rendezvousLifecycleRejectsInvalidServerExpiry(expiry:Int64) async throws {
    let subject = RendezvousKeyLifecycleJournal(storage:LifecycleStore())
    let first = try await subject.reserveGeneration(purpose:.initial,appContext:lifecycleContext,foreground:true,at:1000)
    try await lifecycleEnroll(subject,first)
    await #expect(throws:(any Error).self) {
        try await subject.recordVerifiedActivation(first.identifier,originalExpiryMS:expiry,recovered:false,
            appContext:lifecycleContext,at:2000)
    }
    #expect(try await subject.activeKey(appContext:lifecycleContext,at:2001) == nil)
}

@Test(arguments:["generatedAtMS","enrollmentDeadlineMS","enrollmentBoundAtMS","firstVerifiedAtMS","expiryMS","pausedAtMS"])
func rendezvousLifecycleRejectsOverflowingStoredTimestamps(field:String) async throws {
    let store = LifecycleStore(), subject = RendezvousKeyLifecycleJournal(storage:store)
    let first = try await subject.reserveGeneration(purpose:.initial,appContext:lifecycleContext,foreground:true,at:1000)
    try await lifecycleEnroll(subject,first)
    try store.change { object in
        var handles = object["handles"] as! [[String:Any]]
        handles[0][field] = Int64.max
        object["handles"] = handles
    }
    await #expect(throws:(any Error).self) { try await subject.snapshot(appContext:lifecycleContext,at:3000) }
}
