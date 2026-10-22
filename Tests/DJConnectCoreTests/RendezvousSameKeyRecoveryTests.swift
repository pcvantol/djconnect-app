import CryptoKit
import Foundation
import Testing
@testable import DJConnectCore

private final class RecoveryFlowStore: RendezvousRepairStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var bytes: Data?
    private var writeFailure: Bool?
    enum Failure: Error { case injected }
    func failNextWrite(afterCommit: Bool) { lock.withLock { writeFailure = afterCommit } }
    func read() throws -> Data? { lock.withLock { bytes } }
    func write(_ data: Data) throws {
        try lock.withLock {
            if let afterCommit = writeFailure {
                writeFailure = nil
                if afterCommit { bytes = data }
                throw Failure.injected
            }
            bytes = data
        }
    }
}
@MainActor private final class RecoveryFlowSDK: RendezvousAssertionSDK {
    var isSupported = true
    var hashes: [Data] = []
    var onAssertion: (() -> Void)?
    func assertion(key: String, hash: Data, deadline: TimeInterval) async throws -> Data {
        hashes.append(hash); onAssertion?(); return Data([10, 20, 30])
    }
}
private func recoveryB64(_ bytes: Data) -> String {
    bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}
private func recoveryChallenge(key: String, at now: Int64, idByte: UInt8 = 3) throws -> DJConnectRendezvousRecoveryChallenge {
    let id = recoveryB64(Data(repeating: idByte, count: 32)), nonce = recoveryB64(Data(repeating: 4, count: 32))
    let fields: [String: Any] = ["v": "djc-rendezvous/1", "action": "recover-key", "key_id": key,
        "service_origin": DJConnectRendezvousQR.serviceOrigin, "challenge_id": id, "challenge": nonce, "expires_at": now + 20_000]
    // Whitespace/order are deliberate: the actual original bytes must be signed.
    let original = Data((" \n" + String(decoding: try JSONSerialization.data(withJSONObject: fields), as: UTF8.self) + "\t").utf8)
    let response = try JSONSerialization.data(withJSONObject: ["v": "djc-rendezvous/1", "challenge_id": id,
        "challenge": nonce, "expires_at": now + 20_000, "client_data": recoveryB64(original)])
    return try .parse(response, keyIdentifier: key, requestedAtMS: now, requestedUptime: ProcessInfo.processInfo.systemUptime,
                      nowMS: now, uptime: ProcessInfo.processInfo.systemUptime)
}

@Test func sameKeyRepairJournalRequiresDurableBudgetAndRetainsBothExplicitAttempts() async throws {
    let key = Data(repeating: 6, count: 32).base64EncodedString()
    let repairStore = RecoveryFlowStore(), recoveryStore = RecoveryFlowStore()
    let repair = RendezvousRepairJournal(storage: repairStore), journal = RendezvousRecoveryJournal(storage: recoveryStore)
    _ = try await repair.beginPause(keyIdentifier: key, at: 1_000)
    let first = try await repair.reserveExplicitRecovery(keyIdentifier: key, at: 61_000)
    let c1 = try recoveryChallenge(key: key, at: 61_000)
    let a1 = try await journal.beginExplicitRepair(challenge: c1, repair: repair, reservation: first, at: 61_000)
    let call = try await journal.reserveAssertion(attemptIdentifier: a1, at: 61_000)
    try await journal.completeAssertion(attemptIdentifier: a1, reservation: call.reservation, result: .failed, at: 61_001)
    try await repair.complete(keyIdentifier: key, reservation: first, outcome: .paused, at: 61_001)
    let second = try await repair.reserveExplicitRecovery(keyIdentifier: key, at: 121_000)
    let c2 = try recoveryChallenge(key: key, at: 121_000, idByte: 7)
    let a2 = try await journal.beginExplicitRepair(challenge: c2, repair: repair, reservation: second, at: 121_000)
    #expect(a1 != a2)
    let restored = RendezvousRecoveryJournal(storage: recoveryStore)
    #expect(try await restored.snapshot(at: 121_001)?.attemptIdentifier == a2)
    await #expect(throws: (any Error).self) {
        try await restored.beginExplicitRepair(challenge: c2, repair: repair, reservation: second, at: 121_001)
    }
    let storedBytes = try recoveryStore.read()
    let bytes = try #require(storedBytes)
    let object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    #expect((object["history"] as? [String])?.count == 1)
    let c = try await restored.reserveAssertion(attemptIdentifier: a2, at: 121_002)
    try await restored.completeAssertion(attemptIdentifier: a2, reservation: c.reservation, result: .failed, at: 121_003)
    try await repair.complete(keyIdentifier: key, reservation: second, outcome: .paused, at: 121_003)
    await #expect(throws: (any Error).self) { try await repair.reserveExplicitRecovery(keyIdentifier: key, at: 181_000) }
}

@Test func sameKeyRepairCannotOverwriteALiveChallengeOrUseAnotherReservation() async throws {
    let key = Data(repeating: 6, count: 32).base64EncodedString()
    let repair = RendezvousRepairJournal(storage: RecoveryFlowStore())
    let journal = RendezvousRecoveryJournal(storage: RecoveryFlowStore())
    _ = try await repair.beginPause(keyIdentifier: key, at: 1_000)
    let reservation = try await repair.reserveExplicitRecovery(keyIdentifier: key, at: 61_000)
    let challenge = try recoveryChallenge(key: key, at: 61_000)
    await #expect(throws: (any Error).self) {
        try await journal.beginExplicitRepair(challenge: challenge, repair: repair, reservation: UUID(), at: 61_000)
    }
    #expect(try await journal.snapshot(at: 61_000) == nil)
    _ = try await journal.beginExplicitRepair(challenge: challenge, repair: repair, reservation: reservation, at: 61_000)
    await #expect(throws: (any Error).self) {
        try await journal.beginExplicitRepair(challenge: challenge, repair: repair, reservation: reservation, at: 61_001)
    }
}

/// No real service, key, App Attest effect or Keychain is used by this transport.
private final class RecoveryFlowWire: URLProtocol, @unchecked Sendable {
    static let key = Data(repeating: 6, count: 32).base64EncodedString()
    private static let lock = NSLock()
    nonisolated(unsafe) private static var rawClientData = Data()
    nonisolated(unsafe) private static var paths: [String] = []
    nonisolated(unsafe) private static var loseResponse = false
    nonisolated(unsafe) private static var extendedExpiry = false
    nonisolated(unsafe) private static var pacing = false
    nonisolated(unsafe) private static var onPacingReply: (@Sendable () -> Void)?
    static func reset(lost: Bool = false, extended: Bool = false, pacing: Bool = false,
                      onPacingReply: (@Sendable () -> Void)? = nil) {
        lock.withLock {
            paths = []; rawClientData = Data(); loseResponse = lost; extendedExpiry = extended
            Self.pacing = pacing; Self.onPacingReply = onPacingReply
        }
    }
    static var requests: [String] { lock.withLock { paths } }
    static var hash: Data { lock.withLock { Data(SHA256.hash(data: rawClientData)) } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let path = request.url!.path
            Self.lock.withLock { Self.paths.append(path) }
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            if Self.lock.withLock({ Self.pacing }) {
                let callback = Self.lock.withLock { Self.onPacingReply }
                callback?()
                client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 429,
                    httpVersion: nil, headerFields: ["Content-Type": "application/json", "Retry-After": "900"])!,
                    cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data("{}".utf8))
                client?.urlProtocolDidFinishLoading(self)
                return
            }
            let data: Data
            if path.hasSuffix("/challenge") {
                let challenge = try recoveryChallenge(key: Self.key, at: now)
                Self.lock.withLock { Self.rawClientData = challenge.originalClientData }
                data = try JSONSerialization.data(withJSONObject: ["v": "djc-rendezvous/1", "challenge_id": challenge.identifier,
                    "challenge": recoveryB64(challenge.nonce), "expires_at": challenge.expiresAtMS,
                    "client_data": recoveryB64(challenge.originalClientData)])
            } else {
                if Self.lock.withLock({ Self.loseResponse }) { throw URLError(.networkConnectionLost) }
                let extra: Int64 = Self.lock.withLock { Self.extendedExpiry ? 31 : 1 }
                data = try JSONSerialization.data(withJSONObject: ["v": "djc-rendezvous/1", "key_expires_at": now + extra * 86_400_000])
            }
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
@Suite(.serialized) @MainActor struct RendezvousSameKeyRecoveryTests {
    private func fixture(repairStore: RecoveryFlowStore = RecoveryFlowStore()) async throws -> (RendezvousSameKeyRecovery, RecoveryFlowSDK, RendezvousKeyLifecycleJournal, RendezvousRepairJournal) {
        let lifecycle = RendezvousKeyLifecycleJournal(storage: RecoveryFlowStore()), repair = RendezvousRepairJournal(storage: repairStore)
        let context = Data(repeating: 9, count: 32), now = Int64(Date().timeIntervalSince1970 * 1000)
        let start = now - 180_000
        let handle = try await lifecycle.reserveGeneration(purpose: .initial, appContext: context, foreground: true, at: start)
        try await lifecycle.completeGeneration(handle.identifier, keyIdentifier: RecoveryFlowWire.key, appContext: context, at: start + 1)
        try await lifecycle.bindEnrollment(handle.identifier, deadlineMS: start + 120_000, appContext: context, at: start + 2)
        try await lifecycle.markRegistrationUncertain(handle.identifier, appContext: context, at: start + 3)
        _ = try await repair.beginPause(keyIdentifier: RecoveryFlowWire.key, at: now - 120_000)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [RecoveryFlowWire.self]
        let sdk = RecoveryFlowSDK()
        let subject = RendezvousSameKeyRecovery(sdk: sdk, service: DJConnectRendezvousService(configuration: config),
            lifecycle: lifecycle, journal: RendezvousRecoveryJournal(storage: RecoveryFlowStore()), repair: repair)
        return (subject, sdk, lifecycle, repair)
    }
    @Test func explicitRecoverySignsOriginalBytesAndRestoresOnlyTheRetainedHandle() async throws {
        RecoveryFlowWire.reset()
        let (subject, sdk, lifecycle, repair) = try await fixture()
        try await subject.recover(appContext: Data(repeating: 9, count: 32), isCurrent: { true })
        #expect(sdk.hashes == [RecoveryFlowWire.hash])
        #expect(RecoveryFlowWire.requests.count == 2)
        #expect(RecoveryFlowWire.requests.last?.hasSuffix("/recover") == true)
        #expect(try await lifecycle.activeKey(appContext: Data(repeating: 9, count: 32), at: Int64(Date().timeIntervalSince1970 * 1000)) == RecoveryFlowWire.key)
        #expect(try await repair.snapshot()?.isResolved == true)
    }
    @Test func lostReceiptOrInvalidExpiryNeverReplaysOrAdoptsAKey() async throws {
        for extended in [false, true] {
            RecoveryFlowWire.reset(lost: !extended, extended: extended)
            let (subject, sdk, lifecycle, repair) = try await fixture()
            await #expect(throws: (any Error).self) { try await subject.recover(appContext: Data(repeating: 9, count: 32), isCurrent: { true }) }
            #expect(sdk.hashes.count == 1 && RecoveryFlowWire.requests.count == 2)
            #expect(try await lifecycle.activeKey(appContext: Data(repeating: 9, count: 32), at: Int64(Date().timeIntervalSince1970 * 1000)) == nil)
            #expect(try await repair.snapshot()?.attemptsStarted == 1)
        }
    }
    @Test func challengeServerPacingCannotBeLostWhenCompletionStorageFails() async throws {
        for afterCommit in [false, true] {
            let store = RecoveryFlowStore()
            RecoveryFlowWire.reset(pacing: true, onPacingReply: { store.failNextWrite(afterCommit: afterCommit) })
            let (subject, sdk, _, repair) = try await fixture(repairStore: store)
            await #expect(throws: RecoveryFlowStore.Failure.self) {
                try await subject.recover(appContext: Data(repeating: 9, count: 32), isCurrent: { true })
            }
            #expect(sdk.hashes.isEmpty && RecoveryFlowWire.requests.count == 1)
            #expect(try await repair.snapshot()?.attemptsStarted == 1)
            let restarted = RendezvousRepairJournal(storage: store)
            await #expect(throws: (any Error).self) {
                try await restarted.reserveExplicitRecovery(keyIdentifier: RecoveryFlowWire.key,
                    at: Int64(Date().timeIntervalSince1970 * 1000) + 60_001)
            }
        }
    }
    @Test func defaultNativeRecoveryRemainsClosedBeforeAnyEffect() async {
        await #expect(throws: (any Error).self) { try await RendezvousSameKeyRecovery().recover(appContext: Data(repeating: 9, count: 32), isCurrent: { true }) }
    }
}

@Test func rendezvousServerRetryAfterOnlyDelaysExplicitRepair() {
    #expect(DJConnectRendezvousService.retryNotBefore("900", status: 429, at: 1000) == 901_000)
    #expect(DJConnectRendezvousService.retryNotBefore("broken", status: 503, at: 1000) == 86_401_000)
    #expect(DJConnectRendezvousService.retryNotBefore("-1", status: 429, at: 1000) == 86_401_000)
    #expect(DJConnectRendezvousService.retryNotBefore("900", status: 200, at: 1000) == nil)
    #expect(DJConnectRendezvousService.retryNotBefore(nil, status: 429, at: 1000) == nil)
}


@Test func sameKeyRepairChallengeFailureDoesNotConsumeTheSecondChallengeSlot() async throws {
    let key = Data(repeating: 6, count: 32).base64EncodedString()
    let repairStore = RecoveryFlowStore(), recoveryStore = RecoveryFlowStore()
    var repair = RendezvousRepairJournal(storage: repairStore)
    _ = try await repair.beginPause(keyIdentifier: key, at: 1_000)
    let first = try await repair.reserveExplicitRecovery(keyIdentifier: key, at: 61_000)
    // The first challenge failed before any RecoveryRecord could be created.
    try await repair.complete(keyIdentifier: key, reservation: first, outcome: .paused, at: 61_001)
    let recovery = RendezvousRecoveryJournal(storage: recoveryStore)
    #expect(try await recovery.snapshot(at: 61_001) == nil)
    repair = RendezvousRepairJournal(storage: repairStore) // Restart retains spent budget.
    await #expect(throws: (any Error).self) {
        try await repair.reserveExplicitRecovery(keyIdentifier: key, at: 120_999)
    }
    let second = try await repair.reserveExplicitRecovery(keyIdentifier: key, at: 121_000)
    let challenge = try recoveryChallenge(key: key, at: 121_000)
    let attempt = try await recovery.beginExplicitRepair(challenge: challenge, repair: repair,
                                                        reservation: second, at: 121_000)
    #expect(try await recovery.snapshot(at: 121_001)?.attemptIdentifier == attempt)
    #expect(try await repair.snapshot()?.attemptsStarted == 2)
    try await repair.complete(keyIdentifier: key, reservation: second, outcome: .paused, at: 121_002)
    await #expect(throws: (any Error).self) {
        try await repair.reserveExplicitRecovery(keyIdentifier: key, at: 181_000)
    }
}

@Test func sameKeyRepairServerPacingAndCompletionPersistAtomically() async throws {
    let key = Data(repeating: 6, count: 32).base64EncodedString()
    for afterCommit in [false, true] {
        let store = RecoveryFlowStore()
        let repair = RendezvousRepairJournal(storage: store)
        _ = try await repair.beginPause(keyIdentifier: key, at: 1_000)
        let reservation = try await repair.reserveExplicitRecovery(keyIdentifier: key, at: 61_000)
        store.failNextWrite(afterCommit: afterCommit)
        await #expect(throws: RecoveryFlowStore.Failure.self) {
            try await repair.complete(keyIdentifier: key, reservation: reservation,
                outcome: .paused, notBeforeMS: 961_001, at: 61_001)
        }
        let restarted = RendezvousRepairJournal(storage: store)
        #expect(try await restarted.snapshot()?.attemptsStarted == 1)
        if !afterCommit { #expect(try await restarted.snapshot()?.reservation == reservation) }
        else { #expect(try await restarted.snapshot()?.reservation == nil) }
        await #expect(throws: (any Error).self) {
            try await restarted.reserveExplicitRecovery(keyIdentifier: key, at: 121_000)
        }
        if afterCommit {
            await #expect(throws: (any Error).self) {
                try await restarted.reserveExplicitRecovery(keyIdentifier: key, at: 961_000)
            }
            _ = try await restarted.reserveExplicitRecovery(keyIdentifier: key, at: 961_001)
        }
    }
    let repair = RendezvousRepairJournal(storage: RecoveryFlowStore())
    _ = try await repair.beginPause(keyIdentifier: key, at: 1_000)
    let reservation = try await repair.reserveExplicitRecovery(keyIdentifier: key, at: 61_000)
    try await repair.complete(keyIdentifier: key, reservation: reservation, outcome: .paused,
                              notBeforeMS: 961_001, at: 61_001)
    await #expect(throws: (any Error).self) {
        try await repair.reserveExplicitRecovery(keyIdentifier: key, at: 121_000)
    }
    _ = try await repair.reserveExplicitRecovery(keyIdentifier: key, at: 961_001)
}
