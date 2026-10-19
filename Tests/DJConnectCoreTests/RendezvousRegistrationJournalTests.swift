import CryptoKit
import XCTest
@testable import DJConnectCore

final class RendezvousRegistrationJournalTests: XCTestCase {
    private final class Store: RendezvousRepairStorage, @unchecked Sendable {
        enum Failure: Error { case unavailable }
        private let lock = NSLock()
        private var data: Data?
        private var failRead = false
        private var failWrite = false
        private var commitThenFail = false
        func faults(read: Bool = false, write: Bool = false, afterCommit: Bool = false) {
            lock.withLock { failRead = read; failWrite = write; commitThenFail = afterCommit }
        }
        func read() throws -> Data? { try lock.withLock { if failRead { throw Failure.unavailable }; return data } }
        func write(_ bytes: Data) throws {
            try lock.withLock {
                if failWrite { throw Failure.unavailable }
                data = bytes
                if commitThenFail { throw Failure.unavailable }
            }
        }
        func inject(_ bytes: Data) { lock.withLock { data = bytes } }
    }
    private let key = Data(repeating: 7, count: 32).base64EncodedString()
    private var challenge: String { url(Data(repeating: 8, count: 32)) }
    private let nonce = Data(repeating: 9, count: 32)
    private let proof = Data([0x83, 0x01, 0x02]) // Synthetic bytes, not an Apple attestation.
    private func url(_ value: Data) -> String {
        value.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    private func prepare(_ journal: RendezvousRegistrationJournal) async throws -> UUID {
        try await journal.prepare(keyIdentifier: key, challengeIdentifier: challenge, nonce: nonce,
                                  attestation: proof, admittedAtMS: 0, deadlineMS: 120_000)
    }

    func testRetriesAcrossRestartsReturnByteIdenticalClosedRegistrationBody() async throws {
        let store = Store()
        let journal = RendezvousRegistrationJournal(storage: store)
        let id = try await prepare(journal)
        let a = try await journal.reserveSubmission(attemptIdentifier: id, at: 0)
        let body = try JSONSerialization.jsonObject(with: a.body) as! [String: String]
        XCTAssertEqual(body, ["v": "djc-rendezvous/1", "key_id": key, "challenge_id": challenge, "attestation": url(proof)])
        XCTAssertEqual(a.keyIdentifier, key)
        XCTAssertEqual(a.deadlineMS, 120_000)
        try await journal.completeSubmission(attemptIdentifier: id, reservation: a.reservation, outcome: .responseLost, at: 100)
        let restored = RendezvousRegistrationJournal(storage: store)
        do { _ = try await restored.reserveSubmission(attemptIdentifier: id, at: 2_099); XCTFail() } catch {}
        let b = try await restored.reserveSubmission(attemptIdentifier: id, at: 2_100)
        XCTAssertEqual(a.body, b.body)
        try await restored.completeSubmission(attemptIdentifier: id, reservation: b.reservation, outcome: .responseLost, at: 2_200)
        do { _ = try await restored.reserveSubmission(attemptIdentifier: id, at: 7_199); XCTFail() } catch {}
        let c = try await restored.reserveSubmission(attemptIdentifier: id, at: 7_200)
        XCTAssertEqual(a.body, c.body)
        try await restored.completeSubmission(attemptIdentifier: id, reservation: c.reservation, outcome: .responseLost, at: 7_300)
        let final = try await restored.snapshot(at: 7_300)
        XCTAssertEqual(final?.phase, .registrationUncertain)
        XCTAssertEqual(final?.callsStarted, 3)
        do { _ = try await restored.reserveSubmission(attemptIdentifier: id, at: 8_000); XCTFail() } catch {}
    }

    func testRestoredInFlightReservationAndWrongCompletionsCannotBeReplayed() async throws {
        let store = Store()
        let subject = RendezvousRegistrationJournal(storage: store)
        let id = try await prepare(subject)
        let submission = try await subject.reserveSubmission(attemptIdentifier: id, at: 0)
        let restored = RendezvousRegistrationJournal(storage: store)
        do { _ = try await restored.reserveSubmission(attemptIdentifier: id, at: 1); XCTFail() } catch {}
        do { _ = try await restored.reserveSubmission(attemptIdentifier: UUID(), at: 1); XCTFail() } catch {}
        do { try await restored.completeSubmission(attemptIdentifier: id, reservation: UUID(), outcome: .succeeded, at: 2); XCTFail() } catch {}
        let state = try await restored.snapshot(at: 2)
        XCTAssertEqual(state?.reservation, submission.reservation)
        XCTAssertEqual(state?.callsStarted, 1)
    }

    func testExpiryEqualityPurgesProofAndNonceButRetainsUncertainHandle() async throws {
        let store = Store()
        let journal = RendezvousRegistrationJournal(storage: store)
        let id = try await prepare(journal)
        let submission = try await journal.reserveSubmission(attemptIdentifier: id, at: 0)
        let expired = try await journal.snapshot(at: 120_000)
        XCTAssertEqual(expired?.keyIdentifier, key)
        XCTAssertEqual(expired?.phase, .registrationUncertain)
        let object = try JSONSerialization.jsonObject(with: store.read()!) as! [String: Any]
        for field in ["challenge", "nonce", "nonceHash", "request", "requestHash"] { XCTAssertNil(object[field]) }
        do { try await journal.completeSubmission(attemptIdentifier: id, reservation: submission.reservation, outcome: .succeeded, at: 120_001); XCTFail() } catch {}
        do { _ = try await journal.reserveSubmission(attemptIdentifier: id, at: 120_002); XCTFail() } catch {}
    }

    func testSuccessPurgesSensitiveMaterialAndCannotAdmitNewEnrollment() async throws {
        let store = Store()
        let subject = RendezvousRegistrationJournal(storage: store)
        let id = try await prepare(subject)
        let submission = try await subject.reserveSubmission(attemptIdentifier: id, at: 0)
        try await subject.completeSubmission(attemptIdentifier: id, reservation: submission.reservation, outcome: .succeeded, at: 1)
        let done = try await subject.snapshot(at: 1)
        XCTAssertEqual(done?.phase, .completed)
        XCTAssertEqual(done?.callsStarted, 1)
        let object = try JSONSerialization.jsonObject(with: store.read()!) as! [String: Any]
        XCTAssertNil(object["request"])
        do { _ = try await prepare(subject); XCTFail() } catch {}
    }

    func testFailedAndAmbiguousWritesNeverReleaseRequestBytes() async throws {
        for committed in [false, true] {
            let store = Store()
            let subject = RendezvousRegistrationJournal(storage: store)
            let id = try await prepare(subject)
            store.faults(write: !committed, afterCommit: committed)
            var externalCalls = 0
            do { _ = try await subject.reserveSubmission(attemptIdentifier: id, at: 0); externalCalls += 1; XCTFail() } catch {}
            XCTAssertEqual(externalCalls, 0)
            store.faults()
            let state = try await subject.snapshot(at: 0)
            XCTAssertEqual(state?.callsStarted, committed ? 1 : 0)
            if committed { do { _ = try await subject.reserveSubmission(attemptIdentifier: id, at: 1); XCTFail() } catch {} }
            }
    }

    func testReadFailureAndFailedExpiryPurgeNeverResetOrReleaseState() async throws {
        let store = Store()
        let subject = RendezvousRegistrationJournal(storage: store)
        let id = try await prepare(subject)
        store.faults(read: true)
        do { _ = try await subject.reserveSubmission(attemptIdentifier: id, at: 0); XCTFail() } catch {}
        do { _ = try await prepare(subject); XCTFail() } catch {}
        store.faults(write: true)
        do { _ = try await subject.snapshot(at: 120_000); XCTFail() } catch {}
        do { _ = try await subject.reserveSubmission(attemptIdentifier: id, at: 120_000); XCTFail() } catch {}
        store.faults()
        let state = try await subject.snapshot(at: 120_000)
        XCTAssertEqual(state?.phase, .registrationUncertain)
    }

    func testServerDelayAndClockObservationsPersistWithoutRenewingDeadline() async throws {
        let store = Store(), subject = RendezvousRegistrationJournal(storage: store)
        let id = try await prepare(subject)
        let submission = try await subject.reserveSubmission(attemptIdentifier: id, at: 0)
        try await subject.completeSubmission(attemptIdentifier: id, reservation: submission.reservation, outcome: .responseLost, at: 100, retryNotBeforeMS: 9_000)
        _ = try await subject.snapshot(at: 2_000)
        do { _ = try await subject.snapshot(at: 1_999); XCTFail() } catch {}
        let restored = RendezvousRegistrationJournal(storage: store)
        do { _ = try await restored.reserveSubmission(attemptIdentifier: id, at: 8_999); XCTFail() } catch {}
        let second = try await restored.reserveSubmission(attemptIdentifier: id, at: 9_000)
        XCTAssertEqual(second.body, submission.body)
        XCTAssertEqual(second.deadlineMS, 120_000)
    }

    func testClosedKindAndTerminalFailureStopWithoutNewKeyOrProofRetention() async throws {
        for outcome: RendezvousRetryWindow.Outcome in [.terminalFailure, .appleServerUnavailable] {
            let store = Store(), subject = RendezvousRegistrationJournal(storage: store)
            let id = try await prepare(subject)
            let a = try await subject.reserveSubmission(attemptIdentifier: id, at: 0)
            try await subject.completeSubmission(attemptIdentifier: id, reservation: a.reservation, outcome: outcome, at: 1)
            let state = try await subject.snapshot(at: 1)
            XCTAssertEqual(state?.phase, .registrationUncertain)
            XCTAssertEqual(state?.keyIdentifier, key)
            XCTAssertEqual(state?.callsStarted, 1)
        }
    }

    func testInvalidInputsAndMaximumAttestationSize() async throws {
        for kind in 0..<6 {
            let subject = RendezvousRegistrationJournal(storage: Store())
            do {
                _ = try await subject.prepare(keyIdentifier: kind == 0 ? "bad-key" : key,
                    challengeIdentifier: kind == 1 ? challenge + "=" : challenge,
                    nonce: kind == 2 ? Data() : nonce,
                    attestation: kind == 3 ? Data() : kind == 4 ? Data(repeating: 1, count: 32_769) : proof,
                    admittedAtMS: 0, deadlineMS: kind == 5 ? 120_001 : 120_000)
                XCTFail()
            } catch {}
        }
        let store = Store(), subject = RendezvousRegistrationJournal(storage: store)
        let id = try await subject.prepare(keyIdentifier: key, challengeIdentifier: challenge, nonce: nonce,
                                          attestation: Data(repeating: 255, count: 32_768), admittedAtMS: 0, deadlineMS: 120_000)
        let submission = try await subject.reserveSubmission(attemptIdentifier: id, at: 0)
        XCTAssertLessThanOrEqual(submission.body.count, 65_536)
        XCTAssertLessThanOrEqual(try store.read()!.count, 98_304)
    }

    func testCorruptPersistenceCannotChangeBindingsBudgetOrInjectForeignFields() async throws {
        let store = Store(), original = RendezvousRegistrationJournal(storage: store)
        _ = try await prepare(original)
        let bytes = try store.read()!
        for kind in 0..<10 {
            var object = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
            switch kind {
            case 0: object["schemaVersion"] = 2
            case 1: object["key"] = "bad-key"
            case 2: object["nonceHash"] = Data(repeating: 0, count: 32).base64EncodedString()
            case 3: object["phase"] = "completed"
            case 4: object["requestHash"] = Data(repeating: 0, count: 32).base64EncodedString()
            case 5: object["lastObservedMS"] = -1
            case 6: var window = object["window"] as! [String: Any]; window["kind"] = "recovery"; object["window"] = window
            default:
                var body = try JSONSerialization.jsonObject(with: Data(base64Encoded: object["request"] as! String)!) as! [String: Any]
                if kind == 7 { body["Authorization"] = "not-a-real-token" }
                if kind == 8 { body["challenge_id"] = url(Data(repeating: 5, count: 32)) }
                let changed = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes]) + (kind == 9 ? Data(" ".utf8) : Data())
                object["request"] = changed.base64EncodedString()
                object["requestHash"] = Data(SHA256.hash(data: changed)).base64EncodedString()
            }
            store.inject(try JSONSerialization.data(withJSONObject: object))
            do { _ = try await original.snapshot(at: 0); XCTFail("corrupt case \(kind)") } catch {}
        }
        store.inject(Data(repeating: 0, count: 98_305))
        do { _ = try await original.snapshot(at: 0); XCTFail() } catch {}
    }

    func testMissingStateCannotAllocateSubmission() async throws {
        let store = Store(), journal = RendezvousRegistrationJournal(storage: store)
        do { _ = try await journal.reserveSubmission(attemptIdentifier: UUID(), at: 0); XCTFail() } catch {}
        XCTAssertNil(try store.read())
    }

    func testConcurrentReservationsHaveOneStoredWinner() async throws {
        let store = Store(), subject = RendezvousRegistrationJournal(storage: store)
        let id = try await prepare(subject)
        let winners = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    do { _ = try await subject.reserveSubmission(attemptIdentifier: id, at: 0); return true }
                    catch { return false }
                }
            }
            var count = 0
            for await won in group { if won { count += 1 } }
            return count
        }
        XCTAssertEqual(winners, 1)
        let state = try await subject.snapshot(at: 0)
        XCTAssertEqual(state?.callsStarted, 1)
    }
}
