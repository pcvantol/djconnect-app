import CryptoKit
import Foundation
import Testing
@testable import DJConnectCore

/// All providers and HTTP responses in this suite are synthetic/in-memory.
/// These are actual coordinator/journal/transport executions, not native proof.
@MainActor private final class FlowSDK: RendezvousGenerationSDK, RendezvousAttestationSDK, RendezvousAssertionSDK {
    let key: String
    var isSupported = true
    var generationCalls = 0
    var attestationHashes: [Data] = []
    var assertionHashes: [Data] = []
    var onAssertion: (() -> Void)?
    var holdAssertion = false
    var pendingAssertion: CheckedContinuation<Void, Never>?
    init(key: String) { self.key = key }
    func generate(deadline: TimeInterval) async throws -> String { generationCalls += 1; return key }
    func attest(key: String, hash: Data, deadline: TimeInterval) async throws -> Data {
        #expect(key == self.key); attestationHashes.append(hash); return Data([11,12])
    }
    func assertion(key: String, hash: Data, deadline: TimeInterval) async throws -> Data {
        #expect(key == self.key); assertionHashes.append(hash); onAssertion?()
        if holdAssertion { await withCheckedContinuation { pendingAssertion = $0 } }
        return Data([21,22])
    }
}
private final class FlowWire: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var fixture: SubmissionFixture?
    nonisolated(unsafe) private static var fixtures: [String: SubmissionFixture] = [:]
    nonisolated(unsafe) private static var paths: [String] = []
    nonisolated(unsafe) private static var loseRegistration = false
    nonisolated(unsafe) private static var loseSubmission = false
    static let enrollmentNonce = Data(repeating: 25, count: 32)
    static func install(_ value: SubmissionFixture, registrationLost: Bool = false, submissionLost: Bool = false) {
        lock.withLock { fixture = value; fixtures = [value.qr.transactionID:value]; paths = []
            loseRegistration = registrationLost; loseSubmission = submissionLost }
    }
    static func add(_ value: SubmissionFixture) { lock.withLock { fixtures[value.qr.transactionID] = value } }
    static var requests: [String] { lock.withLock { paths } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let path = request.url!.path
            var bodyBytes = request.httpBody
            if bodyBytes == nil, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var bytes = Data(), buffer = [UInt8](repeating:0,count:512)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer,maxLength:buffer.count)
                    guard count >= 0, bytes.count + count <= 32768 else { throw URLError(.badServerResponse) }
                    if count == 0 { break }; bytes.append(contentsOf:buffer.prefix(count))
                }
                bodyBytes = bytes
            }
            let fields = try JSONSerialization.jsonObject(with: bodyBytes ?? Data()) as? [String:Any]
            let transaction = fields?["transaction_id"] as? String
            let (fixture, lostRegistration, lostSubmission) = try Self.lock.withLock {
                Self.paths.append(path)
                return (try #require(transaction.flatMap { Self.fixtures[$0] } ?? Self.fixture), Self.loseRegistration, Self.loseSubmission)
            }
            #expect(request.url?.host == URL(string:DJConnectRendezvousQR.serviceOrigin)?.host)
            #expect(request.value(forHTTPHeaderField:"Authorization") == nil)
            #expect(request.value(forHTTPHeaderField:"Cookie") == nil)
            let body: Data, status: Int
            switch path {
            case "/v1/rendezvous/attestation/challenge":
                status = 200
                body = try JSONSerialization.data(withJSONObject:["v":"djc-rendezvous/1",
                    "challenge_id":String(repeating:"A",count:43),
                    "challenge":submissionB64(Self.enrollmentNonce), "expires_at":fixture.qr.expiresAtMS])
            case "/v1/rendezvous/attestation/register":
                if lostRegistration { throw URLError(.networkConnectionLost) }
                status = 201
                body = try JSONSerialization.data(withJSONObject:["v":"djc-rendezvous/1",
                    "key_expires_at":fixture.now + 29 * 86_400_000])
            case "/v1/rendezvous/submit-challenge": status = 200; body = fixture.response
            case "/v1/rendezvous/submit":
                if lostSubmission { throw URLError(.networkConnectionLost) }
                status = 202
                body = try JSONSerialization.data(withJSONObject:["v":"djc-rendezvous/1",
                    "accepted":true, "operation_id":fixture.challenge.identifier])
            default: throw URLError(.badURL)
            }
            client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,
                headerFields:["Content-Type":"application/json"])!,cacheStoragePolicy:.notAllowed)
            client?.urlProtocol(self,didLoad:body); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self,didFailWithError:URLError(.networkConnectionLost)) }
    }
    override func stopLoading() {}
}
@MainActor private final class FlowHarness {
    let sdk: FlowSDK
    let lifecycle = RendezvousKeyLifecycleJournal(storage:SubmissionStore())
    let registration = RendezvousRegistrationJournal(storage:SubmissionStore())
    let recovery = RendezvousRecoveryJournal(storage:SubmissionStore())
    let repair = RendezvousRepairJournal(storage:SubmissionStore())
    let submission = RendezvousSubmissionJournal(storage:SubmissionStore())
    let coordinator: RendezvousConnectionCoordinator
    init(_ fixture: SubmissionFixture) {
        sdk = FlowSDK(key:fixture.key)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FlowWire.self]
        let service = DJConnectRendezvousService(configuration:configuration)
        let initial = RendezvousInitialKeyAdapter(sdk:sdk)
        let enrollment = RendezvousEnrollmentRegistration(adapter:.init(sdk:sdk),service:service)
        let send = RendezvousAssertionSubmission(sdk:sdk,service:service,journal:submission,lifecycle:lifecycle)
        coordinator = .init(initial:initial,enrollment:enrollment,submission:send,service:service,
            lifecycle:lifecycle,registration:registration,recovery:recovery,repair:repair,submissionJournal:submission)
    }
    func connect(_ fixture: SubmissionFixture, current: @escaping @MainActor @Sendable () -> Bool = {true}) async throws
        -> RendezvousAssertionSubmission.Receipt {
        try await coordinator.connect(qr:fixture.qr,envelope:fixture.envelope,appContext:fixture.context,isCurrent:current)
    }
}

@Suite(.serialized) @MainActor struct RendezvousNativeFlowTests {
    @Test func initialEnrollmentUsesBinaryNonceThenExactClientDataAndReusesActiveKey() async throws {
        let fixture = try SubmissionFixture(), harness = FlowHarness(fixture)
        FlowWire.install(fixture)
        let receipt = try await harness.connect(fixture)
        #expect(receipt.operationIdentifier == fixture.challenge.identifier)
        #expect(harness.sdk.generationCalls == 1)
        #expect(harness.sdk.attestationHashes == [Data(SHA256.hash(data:FlowWire.enrollmentNonce))])
        #expect(harness.sdk.assertionHashes == [Data(SHA256.hash(data:fixture.original))])
        #expect(try await harness.lifecycle.activeKey(appContext:fixture.context,at:submissionNow()) == fixture.key)
        #expect(FlowWire.requests == ["/v1/rendezvous/attestation/challenge","/v1/rendezvous/attestation/register",
                                     "/v1/rendezvous/submit-challenge","/v1/rendezvous/submit"])
        let next = try SubmissionFixture(transaction:"00000000-0000-4000-8000-000000000002")
        FlowWire.install(next)
        _ = try await harness.connect(next)
        #expect(harness.sdk.generationCalls == 1 && harness.sdk.attestationHashes.count == 1)
        #expect(harness.sdk.assertionHashes.count == 2)
        #expect(FlowWire.requests == ["/v1/rendezvous/submit-challenge","/v1/rendezvous/submit"])
    }

    @Test func lostRegistrationDoesNotActivateOrCreateAnotherKey() async throws {
        let fixture = try SubmissionFixture(), harness = FlowHarness(fixture)
        FlowWire.install(fixture,registrationLost:true)
        await #expect(throws:(any Error).self) { try await harness.connect(fixture) }
        #expect(try await harness.lifecycle.activeKey(appContext:fixture.context,at:submissionNow()) == nil)
        await #expect(throws:(any Error).self) { try await harness.connect(fixture) }
        #expect(harness.sdk.generationCalls == 1 && harness.sdk.assertionHashes.isEmpty)
        #expect(!FlowWire.requests.contains("/v1/rendezvous/submit"))
    }

    @Test func lostSubmissionCannotReturnSuccessOrAutomaticallyResignAndResend() async throws {
        let fixture = try SubmissionFixture(), harness = FlowHarness(fixture)
        FlowWire.install(fixture,submissionLost:true)
        await #expect(throws:(any Error).self) { try await harness.connect(fixture) }
        #expect(try await harness.submission.snapshot(at:submissionNow())?.phase == .uncertain)
        await #expect(throws:(any Error).self) { try await harness.connect(fixture) }
        #expect(harness.sdk.assertionHashes.count == 1 && harness.sdk.generationCalls == 1)
        #expect(FlowWire.requests.filter {$0 == "/v1/rendezvous/submit"}.count == 1)
        #expect(FlowWire.requests.filter {$0 == "/v1/rendezvous/submit-challenge"}.count == 1)
    }

    @Test func withdrawnOwnerAfterSigningNeverSendsDestination() async throws {
        let fixture = try SubmissionFixture(), harness = FlowHarness(fixture), owner = FlowOwner()
        FlowWire.install(fixture)
        harness.sdk.onAssertion = { owner.current = false }
        await #expect(throws:(any Error).self) { try await harness.connect(fixture,current:{owner.current}) }
        #expect(harness.sdk.assertionHashes.count == 1)
        #expect(!FlowWire.requests.contains("/v1/rendezvous/submit"))
    }

    @Test func unsupportedSDKNeverGeneratesOrCallsHTTP() async throws {
        let fixture = try SubmissionFixture(), harness = FlowHarness(fixture)
        harness.sdk.isSupported = false
        FlowWire.install(fixture)
        await #expect(throws:(any Error).self) { try await harness.connect(fixture) }
        #expect(harness.sdk.generationCalls == 0 && FlowWire.requests.isEmpty)
    }

    @Test func twoScansSerializeWholeChallengeSignAndSubmit() async throws {
        let first = try SubmissionFixture(), harness = FlowHarness(first)
        FlowWire.install(first); _ = try await harness.connect(first)
        let second = try SubmissionFixture(transaction:"00000000-0000-4000-8000-000000000002")
        let third = try SubmissionFixture(transaction:"00000000-0000-4000-8000-000000000003")
        FlowWire.install(second); FlowWire.add(third)
        harness.sdk.holdAssertion = true
        let firstSend = Task { try await harness.connect(second) }
        defer { firstSend.cancel(); harness.sdk.pendingAssertion?.resume(); harness.sdk.pendingAssertion = nil }
        try await waitForFlow { harness.sdk.pendingAssertion != nil }
        let secondSend = Task { try await harness.connect(third) }
        defer { secondSend.cancel() }
        try await waitForFlow { await RendezvousAppKeyOperations.shared.waitingOperationCount(for:first.key) > 0 }
        #expect(harness.sdk.assertionHashes.count == 2)
        #expect(FlowWire.requests == ["/v1/rendezvous/submit-challenge"])
        harness.sdk.holdAssertion = false
        harness.sdk.pendingAssertion?.resume(); harness.sdk.pendingAssertion = nil
        _ = try await firstSend.value; _ = try await secondSend.value
        #expect(FlowWire.requests == ["/v1/rendezvous/submit-challenge","/v1/rendezvous/submit",
                                     "/v1/rendezvous/submit-challenge","/v1/rendezvous/submit"])
    }

    @Test func lateDuplicateCallbackCannotReleaseANewerSDKCall() throws {
        let fixture = try SubmissionFixture(), occupancy = RendezvousAssertionOccupancy()
        let original = try occupancy.reserve(fixture.key)
        #expect(throws:(any Error).self) { try occupancy.reserve(fixture.key) }
        // A UI timeout/cancellation does not complete the actual SDK callback.
        occupancy.complete(fixture.key,call:UUID())
        #expect(throws:(any Error).self) { try occupancy.reserve(fixture.key) }
        occupancy.complete(fixture.key,call:original)
        let next = try occupancy.reserve(fixture.key)
        occupancy.complete(fixture.key,call:original)
        #expect(throws:(any Error).self) { try occupancy.reserve(fixture.key) }
        occupancy.complete(fixture.key,call:next)
        _ = try occupancy.reserve(fixture.key)
    }
}
@MainActor private final class FlowOwner { var current = true }
private enum FlowWaitFailure: Error { case deadline }
@MainActor private func waitForFlow(_ condition: @MainActor () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(10))
    while !(await condition()) {
        guard ContinuousClock.now < deadline else { throw FlowWaitFailure.deadline }
        try await Task.sleep(for: .milliseconds(2))
    }
}
