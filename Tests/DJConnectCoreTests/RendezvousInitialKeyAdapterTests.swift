import Foundation
import CryptoKit
import Testing
@testable import DJConnectCore

private final class InitialAdmission:@unchecked Sendable {
    private let lock = NSLock(); private var value = true
    func get()->Bool { lock.withLock { value } }
    func lose() { lock.withLock { value = false } }
}
private final class InitialStore:RendezvousRepairStorage,@unchecked Sendable {
    enum Failure:Error { case unavailable }
    private let lock = NSLock()
    private var bytes:Data?
    var beforeWrite = false
    var afterWrite = false
    var onWrite:(@Sendable ()->Void)?
    func read() throws -> Data? { lock.withLock { bytes } }
    func write(_ data:Data) throws {
        try lock.withLock {
            if beforeWrite { throw Failure.unavailable }
            bytes = data; onWrite?()
            if afterWrite { throw Failure.unavailable }
        }
    }
}
@MainActor private final class InitialSDK:RendezvousGenerationSDK {
    var isSupported = true
    var calls = 0
    var result:Result<String,any Error> = .success(Data(repeating:3,count:32).base64EncodedString())
    var callback:(()->Void)?
    var beforeReturn:(() async throws->Void)?
    func generate(deadline:TimeInterval) async throws -> String {
        calls += 1; #expect(deadline > ProcessInfo.processInfo.systemUptime)
        callback?(); try await beforeReturn?(); return try result.get()
    }
}
@MainActor private final class InitialFixture {
    let context = Data(repeating:6,count:32)
    let store = InitialStore(), registrationStore = InitialStore()
    let recoveryStore = InitialStore(), repairStore = InitialStore()
    let sdk = InitialSDK()
    var admitted = true
    let admission = InitialAdmission()
    var finishFails = false
    var finishes = 0
    let qr:DJConnectRendezvousQR
    init() throws {
        let now = Int64(Date().timeIntervalSince1970*1000)
        let token = String(repeating:"A",count:43)
        qr = try DJConnectRendezvousQR.parse(String(decoding:JSONSerialization.data(withJSONObject:[
            "type":"djc-rendezvous-qr","v":"djc-rendezvous/1","service_origin":DJConnectRendezvousQR.serviceOrigin,
            "transaction_id":"00000000-0000-4000-8000-000000000001","generation":1,
            "expires_at":now+120000,"browser_key_thumbprint":token,"qr_capability":token]),as:UTF8.self))
    }
    func challenge() throws -> DJConnectRendezvousEnrollmentChallenge {
        let now = Int64(Date().timeIntervalSince1970*1000), up = ProcessInfo.processInfo.systemUptime
        return try .parse(JSONSerialization.data(withJSONObject:["v":"djc-rendezvous/1",
            "challenge_id":String(repeating:"A",count:43),"challenge":String(repeating:"A",count:43),
            "expires_at":min(now+120000,qr.expiresAtMS)]),requestedAtMS:now,requestedUptime:up,nowMS:now,uptime:up)
    }
    func run() async throws {
        try await RendezvousInitialKeyAdapter(sdk:sdk).generate(qr:qr,appContext:context,
            lifecycle:RendezvousKeyLifecycleJournal(storage:store),
            registration:RendezvousRegistrationJournal(storage:registrationStore),
            recovery:RendezvousRecoveryJournal(storage:recoveryStore),
            repair:RendezvousRepairJournal(storage:repairStore),
            isAdmitted:{ self.admitted && self.admission.get() },prepareEnrollment:{_,_ in try self.challenge()},finishEnrollment:{ _,key,_,_ in
                #expect(key == Data(repeating:3,count:32).base64EncodedString()); self.finishes += 1
                if self.finishFails { throw InitialStore.Failure.unavailable }
            })
    }
    func handles() async throws -> [RendezvousKeyLifecycleJournal.Handle] {
        try await RendezvousKeyLifecycleJournal(storage:store).snapshot(appContext:context,at:Int64(Date().timeIntervalSince1970*1000))
    }
}
@Test(.isolatedClientResources) @MainActor func rendezvousInitialGenerationPersistsBeforeSDKAndCannotReplay() async throws {
    let f = try InitialFixture()
    f.sdk.callback = { #expect((try? f.store.read()) != nil) }
    try await f.run()
    #expect(f.sdk.calls == 1 && f.finishes == 1)
    #expect(try await f.handles().first?.phase == .enrollmentPending)
    await #expect(throws:(any Error).self) { try await f.run() }
    #expect(f.sdk.calls == 1)
}
@Test(.isolatedClientResources) @MainActor func rendezvousInitialGenerationRejectsUnsupportedAndMissingAdmission() async throws {
    let f = try InitialFixture(); f.sdk.isSupported = false
    await #expect(throws:(any Error).self) { try await f.run() }
    f.sdk.isSupported = true; f.admitted = false
    await #expect(throws:(any Error).self) { try await f.run() }
    #expect(f.sdk.calls == 0 && f.finishes == 0)
    #expect(try await f.handles().isEmpty)
}
@Test(.isolatedClientResources) @MainActor func rendezvousInitialGenerationRejectsUncertainStorageBeforeSDK() async throws {
    for committed in [false,true] {
        let f = try InitialFixture(); f.store.beforeWrite = !committed; f.store.afterWrite = committed
        await #expect(throws:(any Error).self) { try await f.run() }
        #expect(f.sdk.calls == 0)
        f.store.beforeWrite = false; f.store.afterWrite = false
        if committed {
            await #expect(throws:(any Error).self) { try await f.run() }
            #expect(f.sdk.calls == 0)
        }
    }
}
@Test(.isolatedClientResources) @MainActor func rendezvousInitialGenerationOwnerLossDuringCallbackRetainsKnownHandle() async throws {
    let f = try InitialFixture()
    f.sdk.callback = { f.admitted = false }
    await #expect(throws:(any Error).self) { try await f.run() }
    #expect(f.sdk.calls == 1 && f.finishes == 0)
    #expect(try await f.handles().first?.keyIdentifier != nil)
    #expect(try await f.handles().first?.phase == .enrollmentPending)
    await #expect(throws:(any Error).self) { try await f.run() }
    #expect(f.sdk.calls == 1)
}
@Test(.isolatedClientResources) @MainActor func rendezvousInitialGenerationUnknownResultRetainsSlotAcrossRestart() async throws {
    let f = try InitialFixture(); f.sdk.result = .failure(InitialStore.Failure.unavailable)
    await #expect(throws:(any Error).self) { try await f.run() }
    #expect(try await f.handles().first?.phase == .generationUnknown)
    await #expect(throws:(any Error).self) { try await f.run() }
    #expect(f.sdk.calls == 1 && f.finishes == 0)
}
@Test(.isolatedClientResources) @MainActor func rendezvousInitialGenerationAnyLegacyOccupancyBlocksNewKey() async throws {
    let f = try InitialFixture()
    // A valid older enrollment attempt must block even though the new lifecycle
    // account is empty; no diagnostic marker/handle is silently adopted/reset.
    let now = Int64(Date().timeIntervalSince1970*1000)
    _ = try await RendezvousRegistrationJournal(storage:f.registrationStore).beginAttestation(
        keyIdentifier:Data(repeating:4,count:32).base64EncodedString(),
        challengeIdentifier:String(repeating:"A",count:43),nonce:Data(repeating:0,count:32),
        admittedAtMS:now,deadlineMS:now+120000)
    await #expect(throws:(any Error).self) { try await f.run() }
    #expect(f.sdk.calls == 0 && f.finishes == 0)
    #expect(try await f.handles().isEmpty)
}

@Test(.isolatedClientResources) @MainActor func rendezvousInitialGenerationOwnerLossDuringPersistencePreventsSDK() async throws {
    let f = try InitialFixture(), admission = InitialAdmission()
    f.store.onWrite = { admission.lose() }
    await #expect(throws:(any Error).self) {
    try await RendezvousInitialKeyAdapter(sdk:f.sdk).generate(qr:f.qr,appContext:f.context,
        lifecycle:RendezvousKeyLifecycleJournal(storage:f.store),
        registration:RendezvousRegistrationJournal(storage:f.registrationStore),
        recovery:RendezvousRecoveryJournal(storage:InitialStore()),repair:RendezvousRepairJournal(storage:InitialStore()),
        isAdmitted:{ admission.get() },prepareEnrollment:{_,_ in try f.challenge()},finishEnrollment:{ _,_,_,_ in Issue.record("Must not enroll") })
    }
    #expect(f.sdk.calls == 0)
    #expect(try await f.handles().first?.phase == .generationPending)
}

@Test(.isolatedClientResources) @MainActor func rendezvousInitialGenerationEnrollmentFailureDoesNotGenerateAgain() async throws {
    let f = try InitialFixture(); f.finishFails = true
    await #expect(throws:(any Error).self) { try await f.run() }
    #expect(f.sdk.calls == 1 && f.finishes == 1)
    #expect(try await f.handles().first?.phase == .enrollmentPending)
    await #expect(throws:(any Error).self) { try await f.run() }
    #expect(f.sdk.calls == 1)
}
@Test(.isolatedClientResources) @MainActor func rendezvousInitialGenerationMalformedCallbackDoesNotFreeSlot() async throws {
    let f = try InitialFixture(); f.sdk.result = .success("invalid-key")
    await #expect(throws:(any Error).self) { try await f.run() }
    #expect(try await f.handles().first?.phase == .generationUnknown)
    await #expect(throws:(any Error).self) { try await f.run() }
    #expect(f.sdk.calls == 1 && f.finishes == 0)
}

@Test(.isolatedClientResources, arguments:["registration","recovery","repair"])
@MainActor func rendezvousInitialGenerationUnreadableLegacyStateBlocksSDK(kind:String) async throws {
    let f = try InitialFixture()
    let store = kind == "registration" ? f.registrationStore : (kind == "recovery" ? f.recoveryStore : f.repairStore)
    try store.write(Data("not-a-journal".utf8))
    await #expect(throws:(any Error).self) { try await f.run() }
    #expect(f.sdk.calls == 0 && f.finishes == 0)
    #expect(try await f.handles().isEmpty)
}
@Test(.isolatedClientResources) @MainActor func rendezvousInitialGenerationCallbackStorageUncertaintyBlocksEnrollment() async throws {
    let f = try InitialFixture()
    f.sdk.callback = { f.store.afterWrite = true }
    await #expect(throws:(any Error).self) { try await f.run() }
    #expect(f.sdk.calls == 1 && f.finishes == 0)
    f.store.afterWrite = false
    #expect(try await f.handles().first?.keyIdentifier != nil)
    await #expect(throws:(any Error).self) { try await f.run() }
    #expect(f.sdk.calls == 1)
}

@Test(.isolatedClientResources) @MainActor func rendezvousInitialGenerationHistoricalDiagnosticOccupancyBlocksSDK() async throws {
    let f = try InitialFixture()
    for unavailable in [false,true] {
        await #expect(throws:(any Error).self) {
            try await RendezvousInitialKeyAdapter(sdk:f.sdk,historicalStateClear:{
                if unavailable { throw InitialStore.Failure.unavailable }; return false
            }).generate(qr:f.qr,appContext:f.context,lifecycle:RendezvousKeyLifecycleJournal(storage:f.store),
                registration:RendezvousRegistrationJournal(storage:f.registrationStore),
                recovery:RendezvousRecoveryJournal(storage:f.recoveryStore),repair:RendezvousRepairJournal(storage:f.repairStore),
                isAdmitted:{true},prepareEnrollment:{_,_ in try f.challenge()},finishEnrollment:{_,_,_,_ in Issue.record("No enrollment")})
        }
    }
    #expect(f.sdk.calls == 0 && f.finishes == 0)
    #expect(try await f.handles().isEmpty)
}

@Test(.isolatedClientResources) @MainActor func rendezvousInitialGenerationHistoricalPathGuardUsesPresenceNotContents() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.appendingPathComponent("djc-initial-path-"+UUID().uuidString)
    try manager.createDirectory(at:root,withIntermediateDirectories:false)
    defer { try? manager.removeItem(at:root) } // Only this test's fresh synthetic subtree.
    #expect(try RendezvousInitialKeyAdapter.historicalStateIsClear(at:root))
    let parent = root.appendingPathComponent("DJConnect")
    try manager.createDirectory(at:parent,withIntermediateDirectories:false)
    #expect(try RendezvousInitialKeyAdapter.historicalStateIsClear(at:root))
    let marker = parent.appendingPathComponent("APIBinaryQualification40380")
    try Data("synthetic-occupied".utf8).write(to:marker)
    #expect(try !RendezvousInitialKeyAdapter.historicalStateIsClear(at:root))
    try manager.removeItem(at:marker)
    try manager.createSymbolicLink(at:marker,withDestinationURL:root.appendingPathComponent("missing"))
    #expect(try !RendezvousInitialKeyAdapter.historicalStateIsClear(at:root))
    try manager.removeItem(at:parent)
    try manager.createSymbolicLink(at:parent,withDestinationURL:root.appendingPathComponent("missing-parent"))
    #expect(try !RendezvousInitialKeyAdapter.historicalStateIsClear(at:root))
}

@MainActor private final class InitialSerializationGate {
    var entered = false
    var completed = 0
    private var continuation:CheckedContinuation<Void,Never>?
    func hold() async { entered = true; await withCheckedContinuation { continuation = $0 } }
    func release() { continuation?.resume(); continuation = nil }
}
@Test(.isolatedClientResources) @MainActor func rendezvousLegacyCreationWaitsForInitialGenerationBoundary() async throws {
    let gate = InitialSerializationGate(), key = Data(repeating:3,count:32).base64EncodedString()
    let token = String(repeating:"A",count:43), now:Int64 = 1000, expiry:Int64 = 121000
    let stores = (0..<4).map { _ in InitialStore() }
    let owner = Task {
        try await RendezvousAppKeyOperations.shared.perform(keyIdentifier:RendezvousAppKeyOperations.installationAdmissionSlot) {
            await gate.hold()
        }
    }
    for _ in 0..<1000 { if gate.entered { break }; await Task.yield() }
    #expect(gate.entered)
    let first = Task {
        _ = try await RendezvousRegistrationJournal(storage:stores[0]).beginAttestation(keyIdentifier:key,
            challengeIdentifier:token,nonce:Data(repeating:0,count:32),admittedAtMS:now,deadlineMS:expiry)
        gate.completed += 1
    }
    let second = Task {
        _ = try await RendezvousRegistrationJournal(storage:stores[1]).prepare(keyIdentifier:key,
            challengeIdentifier:token,nonce:Data(repeating:0,count:32),attestation:Data([1]),admittedAtMS:now,deadlineMS:expiry)
        gate.completed += 1
    }
    let third = Task {
        let bytes = try JSONSerialization.data(withJSONObject:["v":"djc-rendezvous/1","action":"recover-key",
            "service_origin":DJConnectRendezvousQR.serviceOrigin,"key_id":key,"challenge_id":token,
            "challenge":token,"expires_at":expiry])
        _ = try await RendezvousRecoveryJournal(storage:stores[2]).begin(keyIdentifier:key,
            challengeIdentifier:token,nonce:Data(repeating:0,count:32),clientData:bytes,admittedAtMS:now,deadlineMS:expiry)
        gate.completed += 1
    }
    let fourth = Task {
        _ = try await RendezvousRepairJournal(storage:stores[3]).beginPause(keyIdentifier:key,at:now)
        gate.completed += 1
    }
    for _ in 0..<2000 {
        if await RendezvousAppKeyOperations.shared.waitingOperationCount(for:RendezvousAppKeyOperations.installationAdmissionSlot) == 4 { break }
        await Task.yield()
    }
    #expect(gate.completed == 0)
    for store in stores { #expect(try store.read() == nil) }
    gate.release()
    try await owner.value
    try await first.value; try await second.value; try await third.value; try await fourth.value
    #expect(gate.completed == 4)
}
@Test(.isolatedClientResources) @MainActor func rendezvousInitialGenerationCommitsExactAttemptBeforeEnrollmentContinuation() async throws {
    let f = try InitialFixture()
    let operation = Task {
            try await RendezvousInitialKeyAdapter(sdk:f.sdk).generate(qr:f.qr,appContext:f.context,
                lifecycle:RendezvousKeyLifecycleJournal(storage:f.store),
                registration:RendezvousRegistrationJournal(storage:f.registrationStore),
                recovery:RendezvousRecoveryJournal(storage:f.recoveryStore),repair:RendezvousRepairJournal(storage:f.repairStore),
                isAdmitted:{true},prepareEnrollment:{_,_ in try f.challenge()},finishEnrollment:{_,key,attempt,challenge in
                    let now = Int64(Date().timeIntervalSince1970*1000)
                    let enrollment = RendezvousRegistrationJournal(storage:f.registrationStore)
                    let call = try await RendezvousAppKeyOperations.shared.perform(keyIdentifier:key) {
                        try await enrollment.reserveAttestation(attemptIdentifier:attempt,at:now)
                    }
                    #expect(call.keyIdentifier == key && call.challengeIdentifier == challenge.identifier)
                    #expect(call.deadlineMS == challenge.expiresAtMS)
                    f.finishes += 1
                })
    }
    let watchdog = Task {
        do { try await Task.sleep(for:.seconds(2)) } catch { return }
        operation.cancel()
    }
    defer { watchdog.cancel() }
    try await operation.value
    #expect(f.sdk.calls == 1 && f.finishes == 1)
}

@Test(.isolatedClientResources) @MainActor func rendezvousInitialEnrollmentPrecedesAlreadyQueuedLegacyWriter() async throws {
    let f = try InitialFixture()
    let journal = RendezvousRegistrationJournal(storage:f.registrationStore)
    let token = String(repeating:"A",count:43), otherKey = Data(repeating:4,count:32).base64EncodedString()
    var legacy:Task<UUID,any Error>?
    f.sdk.beforeReturn = {
        legacy = Task {
            let now = Int64(Date().timeIntervalSince1970*1000)
            return try await journal.beginAttestation(keyIdentifier:otherKey,challengeIdentifier:token,
                nonce:Data(repeating:0,count:32),admittedAtMS:now,deadlineMS:now+120000)
        }
        for _ in 0..<2000 {
            if await RendezvousAppKeyOperations.shared.waitingOperationCount(for:RendezvousAppKeyOperations.installationAdmissionSlot) == 1 { break }
            await Task.yield()
        }
        #expect(await RendezvousAppKeyOperations.shared.waitingOperationCount(for:RendezvousAppKeyOperations.installationAdmissionSlot) == 1)
        let stored = try f.registrationStore.read()
        #expect(stored == nil)
    }
    try await RendezvousInitialKeyAdapter(sdk:f.sdk).generate(qr:f.qr,appContext:f.context,
        lifecycle:RendezvousKeyLifecycleJournal(storage:f.store),registration:journal,
        recovery:RendezvousRecoveryJournal(storage:f.recoveryStore),repair:RendezvousRepairJournal(storage:f.repairStore),
        isAdmitted:{true},prepareEnrollment:{_,_ in try f.challenge()},finishEnrollment:{_,key,attempt,challenge in
            let now = Int64(Date().timeIntervalSince1970*1000)
            let state = try #require(await journal.snapshot(at:now))
            #expect(state.keyIdentifier == key && state.attemptIdentifier == attempt)
            #expect(state.deadlineMS == challenge.expiresAtMS)
            f.finishes += 1
        })
    let task = try #require(legacy)
    await #expect(throws:(any Error).self) { try await task.value }
    let state = try #require(await journal.snapshot(at:Int64(Date().timeIntervalSince1970*1000)))
    #expect(state.keyIdentifier == Data(repeating:3,count:32).base64EncodedString())
    #expect(f.sdk.calls == 1 && f.finishes == 1)
}
@Test(.isolatedClientResources) @MainActor func rendezvousInitialEnrollmentLeaseRejectsWrongKeyAndClosedScope() async throws {
    let f = try InitialFixture(), key = Data(repeating:3,count:32).base64EncodedString()
    let lease = RendezvousInitialEnrollmentLease(key:key,qr:f.qr)
    let journal = RendezvousRegistrationJournal(storage:f.registrationStore)
    await RendezvousAppKeyOperations.$initialEnrollmentLease.withValue(lease) {
        let now = Int64(Date().timeIntervalSince1970*1000)
        await #expect(throws:(any Error).self) {
            try await journal.beginAttestation(keyIdentifier:Data(repeating:4,count:32).base64EncodedString(),
                challengeIdentifier:String(repeating:"A",count:43),nonce:Data(repeating:0,count:32),
                admittedAtMS:now,deadlineMS:now+120000)
        }
        lease.close()
        await #expect(throws:(any Error).self) {
            try await journal.beginAttestation(keyIdentifier:key,challengeIdentifier:String(repeating:"A",count:43),
                nonce:Data(repeating:0,count:32),admittedAtMS:now,deadlineMS:now+120000)
        }
    }
    #expect(try f.registrationStore.read() == nil)
}
@Test(.isolatedClientResources) @MainActor func rendezvousInitialEnrollmentNeverWaitsForAnOccupiedPerKeySlot() async throws {
    let f = try InitialFixture(), key = Data(repeating:3,count:32).base64EncodedString()
    let gate = InitialSerializationGate()
    let owner = Task { try await RendezvousAppKeyOperations.shared.perform(keyIdentifier:key) { await gate.hold() } }
    for _ in 0..<1000 { if gate.entered { break }; await Task.yield() }
    #expect(gate.entered)
    let lease = RendezvousInitialEnrollmentLease(key:key,qr:f.qr)
    await #expect(throws:(any Error).self) {
        try await RendezvousAppKeyOperations.$initialEnrollmentLease.withValue(lease) {
            try await RendezvousAppKeyOperations.shared.perform(keyIdentifier:key) { Issue.record("Must not acquire occupied key") }
        }
    }
    lease.close(); gate.release(); try await owner.value
}

@Test(.isolatedClientResources) @MainActor func rendezvousInitialEnrollmentInheritedChildCannotCreateAfterScopeCloses() async throws {
    let f = try InitialFixture(), key = Data(repeating:3,count:32).base64EncodedString()
    let lease = RendezvousInitialEnrollmentLease(key:key,qr:f.qr), gate = InitialSerializationGate()
    let journal = RendezvousRegistrationJournal(storage:f.registrationStore)
    let child = RendezvousAppKeyOperations.$initialEnrollmentLease.withValue(lease) {
        Task {
            await gate.hold()
            let now = Int64(Date().timeIntervalSince1970*1000)
            return try await journal.beginAttestation(keyIdentifier:key,challengeIdentifier:String(repeating:"A",count:43),
                nonce:Data(repeating:0,count:32),admittedAtMS:now,deadlineMS:now+120000)
        }
    }
    for _ in 0..<1000 { if gate.entered { break }; await Task.yield() }
    #expect(gate.entered)
    lease.close(); gate.release()
    await #expect(throws:(any Error).self) { try await child.value }
    #expect(try f.registrationStore.read() == nil)
}
@Test(.isolatedClientResources) @MainActor func rendezvousInitialEnrollmentLeaseCannotReenterRecoveryOrRepair() async throws {
    let f = try InitialFixture(), key = Data(repeating:3,count:32).base64EncodedString()
    let token = String(repeating:"A",count:43), lease = RendezvousInitialEnrollmentLease(key:key,qr:f.qr)
    let bytes = try JSONSerialization.data(withJSONObject:["v":"djc-rendezvous/1","action":"recover-key",
        "service_origin":DJConnectRendezvousQR.serviceOrigin,"key_id":key,"challenge_id":token,
        "challenge":token,"expires_at":121000])
    await RendezvousAppKeyOperations.$initialEnrollmentLease.withValue(lease) {
        await #expect(throws:(any Error).self) {
            try await RendezvousRecoveryJournal(storage:f.recoveryStore).begin(keyIdentifier:key,
                challengeIdentifier:token,nonce:Data(repeating:0,count:32),clientData:bytes,admittedAtMS:1000,deadlineMS:121000)
        }
        await #expect(throws:(any Error).self) {
            try await RendezvousRepairJournal(storage:f.repairStore).beginPause(keyIdentifier:key,at:1000)
        }
    }
    lease.close()
    #expect(try f.recoveryStore.read() == nil)
    #expect(try f.repairStore.read() == nil)
}

@Test(.isolatedClientResources) @MainActor func rendezvousInitialEnrollmentChildrenCannotSelectDifferentAttempt() async throws {
    let f = try InitialFixture(), journal = RendezvousRegistrationJournal(storage:InitialStore())
    let wrongToken = Data(repeating:1,count:32).base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")
    var intended:DJConnectRendezvousEnrollmentChallenge?
    try await RendezvousInitialKeyAdapter(sdk:f.sdk).generate(qr:f.qr,appContext:f.context,
        lifecycle:RendezvousKeyLifecycleJournal(storage:f.store),registration:journal,
        recovery:RendezvousRecoveryJournal(storage:f.recoveryStore),repair:RendezvousRepairJournal(storage:f.repairStore),
        isAdmitted:{true},prepareEnrollment:{_,key in
            let challenge = try f.challenge(); intended = challenge
            let now = Int64(Date().timeIntervalSince1970*1000)
            let child = Task {
                try await journal.beginAttestation(keyIdentifier:key,challengeIdentifier:wrongToken,
                    nonce:Data(repeating:1,count:32),admittedAtMS:now,deadlineMS:challenge.expiresAtMS)
            }
            let preparedChild = Task {
                try await journal.prepare(keyIdentifier:key,challengeIdentifier:wrongToken,nonce:Data(repeating:1,count:32),
                    attestation:Data([1]),admittedAtMS:now,deadlineMS:challenge.expiresAtMS)
            }
            await #expect(throws:(any Error).self) { try await child.value }
            await #expect(throws:(any Error).self) { try await preparedChild.value }
            return challenge
        },finishEnrollment:{_,key,attempt,challenge in
            #expect(challenge.identifier == intended?.identifier)
            let call = try await journal.reserveAttestation(attemptIdentifier:attempt,at:Int64(Date().timeIntervalSince1970*1000))
            #expect(call.keyIdentifier == key && call.challengeIdentifier == challenge.identifier)
            #expect(call.clientDataHash == Data(SHA256.hash(data:challenge.nonce)))
            #expect(call.deadlineMS == challenge.expiresAtMS)
            f.finishes += 1
        })
    #expect(f.sdk.calls == 1 && f.finishes == 1)
}
@Test(.isolatedClientResources) @MainActor func rendezvousInitialEnrollmentAdmissionIsOneShotAcrossJournals() async throws {
    let f = try InitialFixture(), firstStore = InitialStore(), secondStore = InitialStore()
    let key = Data(repeating:3,count:32).base64EncodedString(), challenge = try f.challenge()
    let cap = RendezvousInitialRegistrationAdmission(key:key,challenge:challenge,qr:f.qr,at:Int64(Date().timeIntervalSince1970*1000))
    let first = RendezvousRegistrationJournal(storage:firstStore), second = RendezvousRegistrationJournal(storage:secondStore)
    let id = try await first.beginInitialAttestation(cap)
    let call = try await first.reserveAttestation(attemptIdentifier:id,at:Int64(Date().timeIntervalSince1970*1000))
    #expect(call.challengeIdentifier == challenge.identifier && call.clientDataHash == Data(SHA256.hash(data:challenge.nonce)))
    await #expect(throws:(any Error).self) { try await second.beginInitialAttestation(cap) }
    #expect(try secondStore.read() == nil)
}
@Test(.isolatedClientResources) @MainActor func rendezvousInitialEnrollmentAdmissionFailureNeverRefundsClaim() async throws {
    for committed in [false,true] {
        let f = try InitialFixture(), store = InitialStore(), secondStore = InitialStore()
        let key = Data(repeating:3,count:32).base64EncodedString(), challenge = try f.challenge()
        let cap = RendezvousInitialRegistrationAdmission(key:key,challenge:challenge,qr:f.qr,at:Int64(Date().timeIntervalSince1970*1000))
        store.beforeWrite = !committed; store.afterWrite = committed
        await #expect(throws:(any Error).self) {
            try await RendezvousRegistrationJournal(storage:store).beginInitialAttestation(cap)
        }
        store.beforeWrite = false; store.afterWrite = false
        await #expect(throws:(any Error).self) {
            try await RendezvousRegistrationJournal(storage:secondStore).beginInitialAttestation(cap)
        }
        #expect(try secondStore.read() == nil)
        if committed {
            #expect(try await RendezvousRegistrationJournal(storage:store).snapshot(at:Int64(Date().timeIntervalSince1970*1000))?.keyIdentifier == key)
        }
    }
}
@Test(.isolatedClientResources) @MainActor func rendezvousInitialEnrollmentOwnerLossAfterChallengeNeverCreatesAttempt() async throws {
    let f = try InitialFixture()
    await #expect(throws:(any Error).self) {
        try await RendezvousInitialKeyAdapter(sdk:f.sdk).generate(qr:f.qr,appContext:f.context,
            lifecycle:RendezvousKeyLifecycleJournal(storage:f.store),registration:RendezvousRegistrationJournal(storage:f.registrationStore),
            recovery:RendezvousRecoveryJournal(storage:f.recoveryStore),repair:RendezvousRepairJournal(storage:f.repairStore),
            isAdmitted:{f.admitted},prepareEnrollment:{_,_ in f.admitted = false; return try f.challenge()},
            finishEnrollment:{_,_,_,_ in Issue.record("Must not enroll")})
    }
    #expect(f.sdk.calls == 1 && f.finishes == 0)
    #expect(try f.registrationStore.read() == nil)
    #expect(try await f.handles().first?.keyIdentifier != nil)
}
