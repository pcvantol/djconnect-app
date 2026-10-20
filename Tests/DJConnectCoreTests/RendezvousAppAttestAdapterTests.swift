import Foundation
import Testing
@testable import DJConnectCore

private final class AdapterFlag:@unchecked Sendable {
    private let lock = NSLock(); private var value = true
    func set(_ value:Bool) { lock.withLock { self.value = value } }
    func get()->Bool { lock.withLock { value } }
}
private final class AdapterStore:RendezvousRepairStorage,@unchecked Sendable {
    enum Failure:Error { case unavailable }
    private let lock = NSLock(); private var bytes:Data?
    private var failing = false; private var uncertain = false
    private var onWrite:(@Sendable ()->Void)?
    func fault(failing:Bool = false, uncertain:Bool = false, onWrite:(@Sendable ()->Void)? = nil) {
        lock.withLock { self.failing = failing; self.uncertain = uncertain; self.onWrite = onWrite }
    }
    func read() throws -> Data? { lock.withLock { bytes } }
    func write(_ data:Data) throws {
        try lock.withLock {
            if failing { throw Failure.unavailable }
            bytes = data; onWrite?()
            if uncertain { throw Failure.unavailable }
        }
    }
}
@MainActor private final class AdapterSDK:RendezvousAttestationSDK {
    var isSupported = true; var calls = 0
    var hashes:[Data] = []; var keys:[String] = []; var deadlines:[TimeInterval] = []
    var result:Result<Data,RendezvousAppAttestAdapter.Failure> = .success(Data([1,2,3]))
    var callback:(@MainActor ()->Void)?
    var delay:Duration?
    func attest(key:String,hash:Data,deadline:TimeInterval) async throws -> Data {
        calls += 1; hashes.append(hash); keys.append(key); deadlines.append(deadline)
        #expect(deadline > ProcessInfo.processInfo.systemUptime)
        callback?(); if let delay { try await Task.sleep(for:delay) }; return try result.get()
    }
}
private func adapterChallenge() throws -> (DJConnectRendezvousQR,DJConnectRendezvousEnrollmentChallenge) {
    let now = Int64(Date().timeIntervalSince1970*1000), up = ProcessInfo.processInfo.systemUptime
    let token = String(repeating:"A",count:43)
    let qr = try DJConnectRendezvousQR.parse(String(decoding:JSONSerialization.data(withJSONObject:[
        "type":"djc-rendezvous-qr","v":"djc-rendezvous/1","service_origin":DJConnectRendezvousQR.serviceOrigin,
        "transaction_id":"00000000-0000-4000-8000-000000000001","generation":1,
        "expires_at":now+120000,"browser_key_thumbprint":token,"qr_capability":token]),as:UTF8.self),at:now,uptime:up)
    let challenge = try DJConnectRendezvousEnrollmentChallenge.parse(JSONSerialization.data(withJSONObject:[
        "v":"djc-rendezvous/1","challenge_id":token,"challenge":token,"expires_at":now+120000]),
        requestedAtMS:now,requestedUptime:up,nowMS:now,uptime:up)
    return (qr,challenge)
}
private let adapterKey = Data(repeating:7,count:32).base64EncodedString()
private func beginAdapter(_ journal:RendezvousRegistrationJournal,_ challenge:DJConnectRendezvousEnrollmentChallenge,
                          nonce:Data? = nil) async throws -> UUID {
    try await journal.beginAttestation(keyIdentifier:adapterKey,challengeIdentifier:challenge.identifier,
        nonce:nonce ?? challenge.nonce,admittedAtMS:Int64(Date().timeIntervalSince1970*1000),deadlineMS:challenge.expiresAtMS)
}

@Test @MainActor func rendezvousSDKAdapterPersistsBeforeCallAndDoesNotReplay() async throws {
    let (qr,challenge) = try adapterChallenge(), store = AdapterStore()
    let journal = RendezvousRegistrationJournal(storage:store), sdk = AdapterSDK()
    let id = try await beginAdapter(journal,challenge)
    sdk.callback = {
        let data = try? store.read()
        #expect(data != nil)
        let fields = data.flatMap { try? JSONSerialization.jsonObject(with:$0) as? [String:Any] }
        let sdkWindow = fields?["attestationWindow"] as? [String:Any]
        #expect((sdkWindow?["callsStarted"] as? Int) == 1)
        #expect(sdkWindow?["reservation"] != nil)
    }
    let adapter = RendezvousAppAttestAdapter(sdk:sdk)
    try await adapter.attestExistingKeyAndFinishRegistration(keyIdentifier:adapterKey,attemptIdentifier:id,qr:qr,challenge:challenge,journal:journal,isCurrent:{true},finishRegistration:{})
    #expect(sdk.calls == 1); #expect(sdk.keys == [adapterKey])
    #expect(try #require(sdk.deadlines.first) <= min(qr.originalMonotonicDeadline,challenge.originalMonotonicDeadline))
    let snapshot = try #require(await journal.snapshot(at:Int64(Date().timeIntervalSince1970*1000)))
    #expect(snapshot.phase == .prepared); #expect(snapshot.attestationCallsStarted == 1)
    await #expect(throws:(any Error).self) {
        try await adapter.attestExistingKeyAndFinishRegistration(keyIdentifier:adapterKey,attemptIdentifier:id,qr:qr,challenge:challenge,journal:journal,isCurrent:{true},finishRegistration:{})
    }
    #expect(sdk.calls == 1)
}

@Test @MainActor func rendezvousSDKAdapterRejectsStorageUncertaintyBeforeSDK() async throws {
    for uncertain in [false,true] {
        let (qr,challenge) = try adapterChallenge(), store = AdapterStore()
        let journal = RendezvousRegistrationJournal(storage:store), sdk = AdapterSDK()
        let id = try await beginAdapter(journal,challenge)
        store.fault(failing:!uncertain,uncertain:uncertain)
        await #expect(throws:(any Error).self) {
            try await RendezvousAppAttestAdapter(sdk:sdk).attestExistingKeyAndFinishRegistration(keyIdentifier:adapterKey,
                attemptIdentifier:id,qr:qr,challenge:challenge,journal:journal,isCurrent:{true},finishRegistration:{})
        }
        #expect(sdk.calls == 0)
        store.fault()
        if uncertain {
            // Simulated restart sees the committed reservation, never a new call.
            let restored = RendezvousRegistrationJournal(storage:store)
            await #expect(throws:(any Error).self) {
                try await RendezvousAppAttestAdapter(sdk:sdk).attestExistingKeyAndFinishRegistration(keyIdentifier:adapterKey,
                    attemptIdentifier:id,qr:qr,challenge:challenge,journal:restored,isCurrent:{true},finishRegistration:{})
            }
            #expect(sdk.calls == 0)
        }
    }
}

@Test @MainActor func rendezvousSDKAdapterFencesOwnerAcrossPersistenceAndCallback() async throws {
    for duringCallback in [false,true] {
        let (qr,challenge) = try adapterChallenge(), store = AdapterStore(), flag = AdapterFlag()
        let journal = RendezvousRegistrationJournal(storage:store), sdk = AdapterSDK()
        let id = try await beginAdapter(journal,challenge)
        if duringCallback { sdk.callback = { flag.set(false) } }
        else { store.fault(onWrite:{ flag.set(false) }) }
        await #expect(throws:(any Error).self) {
            try await RendezvousAppAttestAdapter(sdk:sdk).attestExistingKeyAndFinishRegistration(keyIdentifier:adapterKey,
                attemptIdentifier:id,qr:qr,challenge:challenge,journal:journal,isCurrent:{flag.get()},finishRegistration:{})
        }
        #expect(sdk.calls == (duringCallback ? 1 : 0))
        let state = try #require(await journal.snapshot(at:Int64(Date().timeIntervalSince1970*1000)))
        #expect(state.phase != .prepared)
        #expect(state.attestationCallsStarted == 1)
    }
}

@Test @MainActor func rendezvousSDKAdapterBindsNonceAndPreservesSameKeyRetryWindow() async throws {
    for wrongNonce in [true,false] {
        let (qr,challenge) = try adapterChallenge(), store = AdapterStore()
        let journal = RendezvousRegistrationJournal(storage:store), sdk = AdapterSDK()
        let id = try await beginAdapter(journal,challenge,nonce:wrongNonce ? Data(repeating:8,count:32) : nil)
        sdk.result = .failure(.sdkUnavailable)
        let adapter = RendezvousAppAttestAdapter(sdk:sdk)
        await #expect(throws:(any Error).self) {
            try await adapter.attestExistingKeyAndFinishRegistration(keyIdentifier:adapterKey,attemptIdentifier:id,
                qr:qr,challenge:challenge,journal:journal,isCurrent:{true},finishRegistration:{})
        }
        #expect(sdk.calls == (wrongNonce ? 0 : 1))
        await #expect(throws:(any Error).self) {
            try await adapter.attestExistingKeyAndFinishRegistration(keyIdentifier:adapterKey,attemptIdentifier:id,
                qr:qr,challenge:challenge,journal:journal,isCurrent:{true},finishRegistration:{})
        }
        #expect(sdk.calls == (wrongNonce ? 0 : 1))
    }
}

@Test @MainActor func rendezvousSDKUnsupportedOrStaleContextNeverConsumesReservation() async throws {
    for unsupported in [true,false] {
        let (qr,challenge) = try adapterChallenge(), store = AdapterStore()
        let journal = RendezvousRegistrationJournal(storage:store), sdk = AdapterSDK()
        let id = try await beginAdapter(journal,challenge)
        sdk.isSupported = !unsupported
        await #expect(throws:(any Error).self) {
            try await RendezvousAppAttestAdapter(sdk:sdk).attestExistingKeyAndFinishRegistration(keyIdentifier:adapterKey,
                attemptIdentifier:id,qr:qr,challenge:challenge,journal:journal,isCurrent:{unsupported},finishRegistration:{})
        }
        #expect(sdk.calls == 0)
        let state = try #require(await journal.snapshot(at:Int64(Date().timeIntervalSince1970*1000)))
        #expect(state.attestationCallsStarted == 0)
    }
}

@Test @MainActor func rendezvousSDKReplyCompletesOnceAndBoundsMissingCallback() async throws {
    let reply = RendezvousSDKReply()
    let data:Data = try await withCheckedThrowingContinuation { continuation in
        reply.start(continuation,deadline:ProcessInfo.processInfo.systemUptime+1)
        reply.finish(.success(Data([9])))
        reply.finish(.failure(.sdkFailed))
    }
    #expect(data == Data([9])); #expect(!reply.isWaiting)
    let timed = RendezvousSDKReply()
    await #expect(throws:(any Error).self) {
        let _:Data = try await withCheckedThrowingContinuation { continuation in
            timed.start(continuation,deadline:ProcessInfo.processInfo.systemUptime+0.02)
        }
    }
    timed.finish(.success(Data([9]))) // A callback after timeout is discarded.
    #expect(!timed.isWaiting)
    let cancelled = RendezvousSDKReply()
    cancelled.finish(.failure(.sdkFailed))
    await #expect(throws:(any Error).self) {
        let _:Data = try await withCheckedThrowingContinuation { continuation in
            cancelled.start(continuation,deadline:ProcessInfo.processInfo.systemUptime+1)
        }
    }
    #expect(!cancelled.isWaiting)
}

@Test @MainActor func rendezvousSDKAdapterRejectsDifferentChallengeWithSameNonce() async throws {
    let (qr,challenge) = try adapterChallenge(), store = AdapterStore()
    let journal = RendezvousRegistrationJournal(storage:store), sdk = AdapterSDK()
    let id = try await beginAdapter(journal,challenge)
    let now = Int64(Date().timeIntervalSince1970*1000), up = ProcessInfo.processInfo.systemUptime
    let different = try DJConnectRendezvousEnrollmentChallenge.parse(JSONSerialization.data(withJSONObject:[
        "v":"djc-rendezvous/1","challenge_id":String(repeating:"A",count:42)+"E",
        "challenge":String(repeating:"A",count:43),"expires_at":challenge.expiresAtMS]),
        requestedAtMS:now,requestedUptime:up,nowMS:now,uptime:up)
    await #expect(throws:(any Error).self) {
        try await RendezvousAppAttestAdapter(sdk:sdk).attestExistingKeyAndFinishRegistration(keyIdentifier:adapterKey,
            attemptIdentifier:id,qr:qr,challenge:different,journal:journal,isCurrent:{true},finishRegistration:{})
    }
    #expect(sdk.calls == 0)
}

@Test @MainActor func rendezvousSDKAdapterCancellationKeepsConsumedCallAndRejectsLateProof() async throws {
    let (qr,challenge) = try adapterChallenge(), store = AdapterStore()
    let journal = RendezvousRegistrationJournal(storage:store), sdk = AdapterSDK()
    let id = try await beginAdapter(journal,challenge)
    sdk.delay = .seconds(1)
    let adapter = RendezvousAppAttestAdapter(sdk:sdk)
    let operation = Task { @MainActor in
        try await adapter.attestExistingKeyAndFinishRegistration(keyIdentifier:adapterKey,attemptIdentifier:id,
            qr:qr,challenge:challenge,journal:journal,isCurrent:{true},finishRegistration:{})
    }
    while sdk.calls == 0 { await Task.yield() }
    operation.cancel()
    await #expect(throws:(any Error).self) { try await operation.value }
    let state = try #require(await journal.snapshot(at:Int64(Date().timeIntervalSince1970*1000)))
    #expect(state.phase == .registrationUncertain)
    #expect(state.attestationCallsStarted == 1)
    await #expect(throws:(any Error).self) {
        try await adapter.attestExistingKeyAndFinishRegistration(keyIdentifier:adapterKey,attemptIdentifier:id,
            qr:qr,challenge:challenge,journal:journal,isCurrent:{true},finishRegistration:{})
    }
    #expect(sdk.calls == 1)
}

@MainActor private final class AdapterRegistrationFence {
    private var completion:CheckedContinuation<Void,Never>?
    var entered = false
    func hold() async {
        entered = true
        await withCheckedContinuation { completion = $0 }
    }
    func release() { completion?.resume(); completion = nil }
}
@Test @MainActor func rendezvousSDKAdapterHoldsKeyThroughRegistrationCompletion() async throws {
    let (qr,challenge) = try adapterChallenge(), firstStore = AdapterStore(), secondStore = AdapterStore()
    let firstJournal = RendezvousRegistrationJournal(storage:firstStore)
    let secondJournal = RendezvousRegistrationJournal(storage:secondStore)
    let firstID = try await beginAdapter(firstJournal,challenge), secondID = try await beginAdapter(secondJournal,challenge)
    let sdk = AdapterSDK(), adapter = RendezvousAppAttestAdapter(sdk:sdk), fence = AdapterRegistrationFence()
    let first = Task { @MainActor in
        try await adapter.attestExistingKeyAndFinishRegistration(keyIdentifier:adapterKey,attemptIdentifier:firstID,
            qr:qr,challenge:challenge,journal:firstJournal,isCurrent:{true},finishRegistration:{await fence.hold()})
    }
    while !fence.entered { await Task.yield() }
    let second = Task { @MainActor in
        try await adapter.attestExistingKeyAndFinishRegistration(keyIdentifier:adapterKey,attemptIdentifier:secondID,
            qr:qr,challenge:challenge,journal:secondJournal,isCurrent:{true},finishRegistration:{})
    }
    while await RendezvousAppKeyOperations.shared.waitingOperationCount(for:adapterKey) == 0 { await Task.yield() }
    #expect(sdk.calls == 1) // Second SDK call cannot cross the held registration.
    fence.release()
    try await first.value; try await second.value
    #expect(sdk.calls == 2)
}

@Test @MainActor func rendezvousSDKCompletionWriteUncertaintyCannotStartRegistration() async throws {
    let (qr,challenge) = try adapterChallenge(), store = AdapterStore(), registrationNotCalled = AdapterFlag()
    let journal = RendezvousRegistrationJournal(storage:store), sdk = AdapterSDK()
    let id = try await beginAdapter(journal,challenge)
    sdk.callback = { store.fault(uncertain:true) }
    let adapter = RendezvousAppAttestAdapter(sdk:sdk)
    await #expect(throws:(any Error).self) {
        try await adapter.attestExistingKeyAndFinishRegistration(keyIdentifier:adapterKey,
            attemptIdentifier:id,qr:qr,challenge:challenge,journal:journal,isCurrent:{true},
            finishRegistration:{registrationNotCalled.set(false)})
    }
    #expect(registrationNotCalled.get()); #expect(sdk.calls == 1)
    store.fault()
    await #expect(throws:(any Error).self) {
        try await adapter.attestExistingKeyAndFinishRegistration(keyIdentifier:adapterKey,
            attemptIdentifier:id,qr:qr,challenge:challenge,journal:journal,isCurrent:{true},
            finishRegistration:{registrationNotCalled.set(false)})
    }
    #expect(registrationNotCalled.get()); #expect(sdk.calls == 1)
}
