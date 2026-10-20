import Foundation
import Testing
@testable import DJConnectCore

private final class EnrollmentFlag:@unchecked Sendable {
    private let lock = NSLock(); private var current = true
    func get()->Bool { lock.withLock { current } }
    func withdraw() { lock.withLock { current = false } }
}
private final class EnrollmentStore:RendezvousRepairStorage,@unchecked Sendable {
    enum Failure:Error { case unavailable }
    private let lock = NSLock(); private var data:Data?; private var writes = 0
    var failAt:Int?; var commitThenError = false
    var onWrite:(@Sendable (Int)->Void)?
    func read() throws -> Data? { lock.withLock { data } }
    func write(_ bytes:Data) throws {
        try lock.withLock {
            writes += 1
            if writes == failAt && !commitThenError { throw Failure.unavailable }
            data = bytes; onWrite?(writes)
            if writes == failAt { throw Failure.unavailable }
        }
    }
}
@MainActor private final class EnrollmentSDK:RendezvousAttestationSDK {
    let isSupported = true; var calls = 0
    func attest(key:String,hash:Data,deadline:TimeInterval) async throws -> Data {
        calls += 1; return Data([1,2,3])
    }
}
private final class EnrollmentWire:URLProtocol,@unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var bodies:[Data] = []
    nonisolated(unsafe) private static var states:[Data] = []
    nonisolated(unsafe) private static var store:EnrollmentStore?
    nonisolated(unsafe) private static var status = 201
    nonisolated(unsafe) private static var body = Data()
    nonisolated(unsafe) private static var received:(@Sendable ()->Void)?
    nonisolated(unsafe) private static var headers = ["Content-Type":"application/json"]
    nonisolated(unsafe) private static var hold = false
    static func configure(store:EnrollmentStore,status:Int = 201,body:Data,received:(@Sendable ()->Void)? = nil,
        headers:[String:String] = ["Content-Type":"application/json"],hold:Bool = false) {
        lock.withLock { self.store = store; self.status = status; self.body = body; self.received = received
            self.headers = headers; self.hold = hold; bodies = []; states = [] }
    }
    static var requests:[Data] { lock.withLock { bodies } }
    static var snapshots:[Data] { lock.withLock { states } }
    override class func canInit(with request:URLRequest)->Bool { true }
    override class func canonicalRequest(for request:URLRequest)->URLRequest { request }
    override func startLoading() {
        let (status,body,callback,headers,hold) = Self.lock.withLock { ()->(Int,Data,(@Sendable ()->Void)?,[String:String],Bool) in
            var data = request.httpBody ?? Data()
            if let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating:0,count:2048)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer,maxLength:buffer.count)
                    if count <= 0 { break }; data.append(contentsOf:buffer.prefix(count))
                }
            }
            Self.bodies.append(data)
            if let state = try? Self.store?.read() { Self.states.append(state) }
            return (Self.status,Self.body,Self.received,Self.headers,Self.hold)
        }
        #expect(request.url?.absoluteString == "https://api.djconnect.dev/v1/rendezvous/attestation/register")
        #expect(request.value(forHTTPHeaderField:"Authorization") == nil)
        callback?()
        if hold { return }
        client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,
            headerFields:headers)!,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:body); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
private let enrollmentKey = Data(repeating:9,count:32).base64EncodedString()
@MainActor private func enrollmentSetup(store:EnrollmentStore) async throws ->
    (RendezvousEnrollmentRegistration,RendezvousRegistrationJournal,UUID,DJConnectRendezvousQR,DJConnectRendezvousEnrollmentChallenge,EnrollmentSDK) {
    let now = Int64(Date().timeIntervalSince1970*1000), up = ProcessInfo.processInfo.systemUptime
    let token = String(repeating:"A",count:43)
    let qr = try DJConnectRendezvousQR.parse(String(decoding:JSONSerialization.data(withJSONObject:[
        "type":"djc-rendezvous-qr","v":"djc-rendezvous/1","service_origin":DJConnectRendezvousQR.serviceOrigin,
        "transaction_id":"00000000-0000-4000-8000-000000000001","generation":1,
        "expires_at":now+120000,"browser_key_thumbprint":token,"qr_capability":token]),as:UTF8.self),at:now,uptime:up)
    let challenge = try DJConnectRendezvousEnrollmentChallenge.parse(JSONSerialization.data(withJSONObject:[
        "v":"djc-rendezvous/1","challenge_id":token,"challenge":token,"expires_at":now+120000]),
        requestedAtMS:now,requestedUptime:up,nowMS:now,uptime:up)
    let journal = RendezvousRegistrationJournal(storage:store)
    let id = try await journal.beginAttestation(keyIdentifier:enrollmentKey,challengeIdentifier:challenge.identifier,
        nonce:challenge.nonce,admittedAtMS:now,deadlineMS:challenge.expiresAtMS)
    let sdk = EnrollmentSDK(), config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [EnrollmentWire.self]
    return (.init(adapter:.init(sdk:sdk),service:.init(configuration:config)),journal,id,qr,challenge,sdk)
}
private func enrollmentResponse(expiry:Int64) throws -> Data {
    try JSONSerialization.data(withJSONObject:["v":"djc-rendezvous/1","key_expires_at":expiry])
}

@Suite(.serialized) @MainActor struct RendezvousEnrollmentRegistrationTests {
    @Test func originalBytesPersistedBeforeHTTPAndCompletionRequired() async throws {
        let store = EnrollmentStore()
        let (subject,journal,id,qr,challenge,sdk) = try await enrollmentSetup(store:store)
        let expiry = Int64(Date().timeIntervalSince1970*1000)+86_400_000
        EnrollmentWire.configure(store:store,body:try enrollmentResponse(expiry:expiry))
        let receipt = try await subject.enrollExistingKey(keyIdentifier:enrollmentKey,attemptIdentifier:id,
            qr:qr,challenge:challenge,journal:journal,isCurrent:{true})
        #expect(receipt.attemptIdentifier == id && receipt.keyIdentifier == enrollmentKey && receipt.originalKeyExpiryMS == expiry)
        #expect(sdk.calls == 1 && EnrollmentWire.requests.count == 1)
        let snapshotBytes = try #require(EnrollmentWire.snapshots.first)
        let state = try #require(JSONSerialization.jsonObject(with:snapshotBytes) as? [String:Any])
        let window = try #require(state["window"] as? [String:Any])
        #expect(window["callsStarted"] as? Int == 1 && window["reservation"] != nil)
        let stored = try #require((state["request"] as? String).flatMap { Data(base64Encoded:$0) })
        #expect(EnrollmentWire.requests == [stored])
        #expect(try await journal.snapshot(at:Int64(Date().timeIntervalSince1970*1000))?.phase == .completed)
        await #expect(throws:(any Error).self) {
            _ = try await subject.enrollExistingKey(keyIdentifier:enrollmentKey,attemptIdentifier:id,
                qr:qr,challenge:challenge,journal:journal,isCurrent:{true})
        }
        #expect(sdk.calls == 1 && EnrollmentWire.requests.count == 1)
    }
    @Test func failedOrUncertainReservationCannotDispatch() async throws {
        for commit in [false,true] {
            let store = EnrollmentStore()
            let (subject,journal,id,qr,challenge,_) = try await enrollmentSetup(store:store)
            store.failAt = 4; store.commitThenError = commit
            EnrollmentWire.configure(store:store,body:try enrollmentResponse(expiry:challenge.expiresAtMS+1000))
            await #expect(throws:(any Error).self) {
                _ = try await subject.enrollExistingKey(keyIdentifier:enrollmentKey,attemptIdentifier:id,
                    qr:qr,challenge:challenge,journal:journal,isCurrent:{true})
            }
            #expect(EnrollmentWire.requests.isEmpty)
        }
    }
    @Test func ownerLostDuringReservationCannotDispatch() async throws {
        let store = EnrollmentStore(), flag = EnrollmentFlag()
        let (subject,journal,id,qr,challenge,_) = try await enrollmentSetup(store:store)
        store.onWrite = { if $0 == 4 { flag.withdraw() } }
        EnrollmentWire.configure(store:store,body:try enrollmentResponse(expiry:challenge.expiresAtMS+1000))
        await #expect(throws:(any Error).self) {
            _ = try await subject.enrollExistingKey(keyIdentifier:enrollmentKey,attemptIdentifier:id,
                qr:qr,challenge:challenge,journal:journal,isCurrent:{flag.get()})
        }
        #expect(EnrollmentWire.requests.isEmpty)
    }
    @Test func unavailableMalformedOrExcessiveLeaseIsUncertainWithoutReplay() async throws {
        for mode in ["503","malformed","expired","extended"] {
            let store = EnrollmentStore()
            let (subject,journal,id,qr,challenge,_) = try await enrollmentSetup(store:store)
            let now = Int64(Date().timeIntervalSince1970*1000)
            let data = mode == "malformed" ? Data("{}".utf8) : try enrollmentResponse(
                expiry:mode == "expired" ? now-1 : now+(mode == "extended" ? 31 : 1)*86_400_000)
            EnrollmentWire.configure(store:store,status:mode == "503" ? 503 : 201,body:data)
            await #expect(throws:(any Error).self) {
                _ = try await subject.enrollExistingKey(keyIdentifier:enrollmentKey,attemptIdentifier:id,
                    qr:qr,challenge:challenge,journal:journal,isCurrent:{true})
            }
            #expect(EnrollmentWire.requests.count == 1)
            #expect(try await journal.snapshot(at:Int64(Date().timeIntervalSince1970*1000))?.phase == .registrationUncertain)
            await #expect(throws:(any Error).self) { _ = try await journal.reserveSubmission(attemptIdentifier:id,at:Int64(Date().timeIntervalSince1970*1000)) }
        }
    }
    @Test func completionStorageUncertaintyReturnsNoReceiptAndDoesNotResend() async throws {
        for commit in [false,true] {
            let store = EnrollmentStore()
            let (subject,journal,id,qr,challenge,sdk) = try await enrollmentSetup(store:store)
            store.failAt = 5; store.commitThenError = commit
            EnrollmentWire.configure(store:store,body:try enrollmentResponse(expiry:challenge.expiresAtMS+1000))
            await #expect(throws:(any Error).self) {
                _ = try await subject.enrollExistingKey(keyIdentifier:enrollmentKey,attemptIdentifier:id,
                    qr:qr,challenge:challenge,journal:journal,isCurrent:{true})
            }
            #expect(sdk.calls == 1 && EnrollmentWire.requests.count == 1)
            let snapshot = try #require(await journal.snapshot(at:Int64(Date().timeIntervalSince1970*1000)))
            #expect(commit ? snapshot.phase == .completed : snapshot.reservation != nil)
        }
    }
    @Test func ownerLostAfterServerReplyReturnsNoReceipt() async throws {
        let store = EnrollmentStore(), flag = EnrollmentFlag()
        let (subject,journal,id,qr,challenge,_) = try await enrollmentSetup(store:store)
        EnrollmentWire.configure(store:store,body:try enrollmentResponse(expiry:challenge.expiresAtMS+1000),received:{flag.withdraw()})
        await #expect(throws:(any Error).self) {
            _ = try await subject.enrollExistingKey(keyIdentifier:enrollmentKey,attemptIdentifier:id,
                qr:qr,challenge:challenge,journal:journal,isCurrent:{flag.get()})
        }
        #expect(EnrollmentWire.requests.count == 1)
        #expect(try await journal.snapshot(at:Int64(Date().timeIntervalSince1970*1000))?.phase == .registrationUncertain)
    }
    @Test func serviceRechecksAuthorityAtDispatch() async throws {
        let store = EnrollmentStore()
        let (_,_,_,qr,challenge,_) = try await enrollmentSetup(store:store)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [EnrollmentWire.self]
        let service = DJConnectRendezvousService(configuration:config)
        EnrollmentWire.configure(store:store,body:try enrollmentResponse(expiry:challenge.expiresAtMS+1000))
        var checked = false
        await #expect(throws:(any Error).self) {
            _ = try await service.register(originalBody:Data("{}".utf8),qr:qr,beforeDispatch:{
                checked = true; throw CancellationError()
            })
        }
        #expect(checked && EnrollmentWire.requests.isEmpty)
    }
    @Test func ownerLostDuringSuccessfulCompletionCannotReceiveReceipt() async throws {
        let store = EnrollmentStore(), flag = EnrollmentFlag()
        let (subject,journal,id,qr,challenge,_) = try await enrollmentSetup(store:store)
        store.onWrite = { if $0 == 5 { flag.withdraw() } }
        EnrollmentWire.configure(store:store,body:try enrollmentResponse(expiry:challenge.expiresAtMS+1000))
        await #expect(throws:(any Error).self) {
            _ = try await subject.enrollExistingKey(keyIdentifier:enrollmentKey,attemptIdentifier:id,
                qr:qr,challenge:challenge,journal:journal,isCurrent:{flag.get()})
        }
        #expect(EnrollmentWire.requests.count == 1)
        #expect(try await journal.snapshot(at:Int64(Date().timeIntervalSince1970*1000))?.phase == .completed)
    }
    @Test func taskIsCreatedAndResumedBeforeNextMainActorTurn() async throws {
        let store = EnrollmentStore()
        let (_,_,_,qr,challenge,_) = try await enrollmentSetup(store:store)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [EnrollmentWire.self]
        var observedTask:URLSessionDataTask?
        let service = DJConnectRendezvousService(configuration:config,taskCreated:{observedTask = $0})
        EnrollmentWire.configure(store:store,body:try enrollmentResponse(expiry:challenge.expiresAtMS+1000))
        var probe:Task<Void,Never>?
        _ = try await service.register(originalBody:Data("{}".utf8),qr:qr,beforeDispatch:{
            #expect(observedTask?.state == .suspended)
            probe = Task { @MainActor in
                // This is exactly where a queued UI owner cancellation runs.
                // Foundation's task must already exist and have been resumed.
                guard let task = observedTask else { Issue.record("No task before actor release"); return }
                #expect(task.state != .suspended)
            }
        })
        await probe?.value
        #expect(EnrollmentWire.requests.count == 1)
    }
    @Test func streamedBodyExceedingBoundIsRejected() async throws {
        let store = EnrollmentStore()
        let (subject,journal,id,qr,challenge,_) = try await enrollmentSetup(store:store)
        EnrollmentWire.configure(store:store,body:Data(repeating:32,count:4097))
        await #expect(throws:(any Error).self) {
            _ = try await subject.enrollExistingKey(keyIdentifier:enrollmentKey,attemptIdentifier:id,
                qr:qr,challenge:challenge,journal:journal,isCurrent:{true})
        }
        #expect(EnrollmentWire.requests.count == 1)
        #expect(try await journal.snapshot(at:Int64(Date().timeIntervalSince1970*1000))?.phase == .registrationUncertain)
    }
    @Test func streamingResponsePreservesHeaderAndLengthGuards() async throws {
        for headers in [["Content-Type":"application/json","Content-Length":"4097"],
                        ["Content-Type":"application/json","Content-Encoding":"gzip"],
                        ["Content-Type":"text/plain"],
                        ["Content-Type":"application/json","Content-Length":"1000"]] {
            let store = EnrollmentStore()
            let (subject,journal,id,qr,challenge,_) = try await enrollmentSetup(store:store)
            EnrollmentWire.configure(store:store,body:try enrollmentResponse(expiry:challenge.expiresAtMS+1000),headers:headers)
            await #expect(throws:(any Error).self) {
                _ = try await subject.enrollExistingKey(keyIdentifier:enrollmentKey,attemptIdentifier:id,
                    qr:qr,challenge:challenge,journal:journal,isCurrent:{true})
            }
            #expect(EnrollmentWire.requests.count == 1)
            #expect(try await journal.snapshot(at:Int64(Date().timeIntervalSince1970*1000))?.phase == .registrationUncertain)
        }
    }
    @Test func cancellationFinishesWithoutWaitingForServerCallback() async throws {
        let store = EnrollmentStore()
        let (_,_,_,qr,_,_) = try await enrollmentSetup(store:store)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [EnrollmentWire.self]
        let service = DJConnectRendezvousService(configuration:config)
        EnrollmentWire.configure(store:store,body:Data(),hold:true)
        let work = Task { try await service.register(originalBody:Data("{}".utf8),qr:qr,beforeDispatch:{}) }
        let clock = ContinuousClock(), deadline = clock.now.advanced(by:.seconds(1))
        while EnrollmentWire.requests.isEmpty && clock.now < deadline { try await Task.sleep(for:.milliseconds(1)) }
        #expect(EnrollmentWire.requests.count == 1)
        work.cancel()
        await #expect(throws:(any Error).self) { _ = try await work.value }
        #expect(EnrollmentWire.requests.count == 1)
    }
}
