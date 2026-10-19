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

    private func begin(_ journal: RendezvousRegistrationJournal) async throws -> UUID {
        try await journal.beginAttestation(keyIdentifier: key, challengeIdentifier: challenge,
                                           nonce: nonce, admittedAtMS: 0, deadlineMS: 120_000)
    }

    func testSDKRetriesKeepOriginalHashDeadlineAndSeparateRegistrationBudgetAcrossRestart() async throws {
        let store = Store(), subject = RendezvousRegistrationJournal(storage: store)
        let id = try await begin(subject)
        let first = try await subject.reserveAttestation(attemptIdentifier: id, at: 0)
        XCTAssertEqual(first.clientDataHash, Data(SHA256.hash(data: nonce)))
        XCTAssertEqual(first.keyIdentifier, key)
        try await subject.completeAttestation(attemptIdentifier: id, reservation: first.reservation, result: .serverUnavailable, at: 100)
        let restored = RendezvousRegistrationJournal(storage: store)
        do { _ = try await restored.reserveAttestation(attemptIdentifier: id, at: 2_099); XCTFail() } catch {}
        let second = try await restored.reserveAttestation(attemptIdentifier: id, at: 2_100)
        XCTAssertEqual(second.clientDataHash, first.clientDataHash)
        try await restored.completeAttestation(attemptIdentifier: id, reservation: second.reservation, result: .serverUnavailable, at: 2_200)
        do { _ = try await restored.reserveAttestation(attemptIdentifier: id, at: 7_199); XCTFail() } catch {}
        let third = try await restored.reserveAttestation(attemptIdentifier: id, at: 7_200)
        XCTAssertEqual(third.clientDataHash, first.clientDataHash)
        XCTAssertEqual(third.deadlineMS, 120_000)
        try await restored.completeAttestation(attemptIdentifier: id, reservation: third.reservation,
                                               result: .received(Data(repeating: 255, count: 32_768)), at: 7_300)
        let prepared = try await RendezvousRegistrationJournal(storage: store).snapshot(at: 7_300)
        XCTAssertEqual(prepared?.phase, .prepared)
        XCTAssertEqual(prepared?.attestationCallsStarted, 3)
        XCTAssertEqual(prepared?.callsStarted, 0)
        let submission = try await restored.reserveSubmission(attemptIdentifier: id, at: 7_300)
        XCTAssertEqual(submission.deadlineMS, 120_000)
        let body = try JSONSerialization.jsonObject(with: submission.body) as! [String: String]
        XCTAssertEqual(body["attestation"], url(Data(repeating: 255, count: 32_768)))
        XCTAssertEqual(body["challenge_id"], challenge)
        XCTAssertLessThanOrEqual(try store.read()!.count, 98_304)
        try await restored.completeSubmission(attemptIdentifier: id, reservation: submission.reservation, outcome: .succeeded, at: 7_301)
        let done = try await restored.snapshot(at: 7_301)
        XCTAssertEqual(done?.phase, .completed)
        XCTAssertEqual(done?.attestationCallsStarted, 3)
        XCTAssertEqual(done?.callsStarted, 1)
    }

    func testRestoredSDKInFlightAndWrongCallbacksCannotReleaseOrReplaceAttempt() async throws {
        let store = Store(), subject = RendezvousRegistrationJournal(storage: store)
        let id = try await begin(subject)
        let call = try await subject.reserveAttestation(attemptIdentifier: id, at: 0)
        let restored = RendezvousRegistrationJournal(storage: store)
        do { _ = try await restored.reserveAttestation(attemptIdentifier: id, at: 1); XCTFail() } catch {}
        do { _ = try await restored.reserveSubmission(attemptIdentifier: id, at: 1); XCTFail() } catch {}
        do { try await restored.completeAttestation(attemptIdentifier: UUID(), reservation: call.reservation, result: .received(proof), at: 1); XCTFail() } catch {}
        do { try await restored.completeAttestation(attemptIdentifier: id, reservation: UUID(), result: .received(proof), at: 1); XCTFail() } catch {}
        do { _ = try await begin(restored); XCTFail() } catch {}
        do { _ = try await prepare(restored); XCTFail() } catch {}
        let state = try await restored.snapshot(at: 1)
        XCTAssertEqual(state?.phase, .attestationPending)
        XCTAssertEqual(state?.attestationCallsStarted, 1)
        XCTAssertEqual(state?.attestationReservation, call.reservation)
        XCTAssertEqual(state?.callsStarted, 0)
    }

    func testSDKExhaustionAndTerminalFailurePurgeMaterialButRetainHandleAndCount() async throws {
        for terminal in [false, true] {
            let store = Store(), subject = RendezvousRegistrationJournal(storage: store)
            let id = try await begin(subject)
            for (index, at): (Int, Int64) in [0, 2_001, 7_002].enumerated() {
                let call = try await subject.reserveAttestation(attemptIdentifier: id, at: at)
                try await subject.completeAttestation(attemptIdentifier: id, reservation: call.reservation,
                                                      result: terminal ? .terminalFailure : .serverUnavailable, at: at + 1)
                if terminal || index == 2 {
                    let state = try await subject.snapshot(at: at + 1)
                    XCTAssertEqual(state?.phase, .registrationUncertain)
                    XCTAssertEqual(state?.attestationCallsStarted, index + 1)
                    XCTAssertEqual(state?.keyIdentifier, key)
                    let object = try JSONSerialization.jsonObject(with: store.read()!) as! [String: Any]
                    for field in ["challenge", "nonce", "nonceHash", "request", "requestHash"] { XCTAssertNil(object[field]) }
                    do { _ = try await subject.reserveAttestation(attemptIdentifier: id, at: at + 2); XCTFail() } catch {}
                    break
                }
            }
        }
    }

    func testLateSDKProofCannotBeSavedOrSubmittedAtDeadlineEquality() async throws {
        let store = Store(), subject = RendezvousRegistrationJournal(storage: store)
        let id = try await begin(subject)
        let call = try await subject.reserveAttestation(attemptIdentifier: id, at: 0)
        do { try await subject.completeAttestation(attemptIdentifier: id, reservation: call.reservation, result: .received(proof), at: 120_000); XCTFail() } catch {}
        let state = try await RendezvousRegistrationJournal(storage: store).snapshot(at: 120_001)
        XCTAssertEqual(state?.phase, .registrationUncertain)
        XCTAssertEqual(state?.attestationCallsStarted, 1)
        // Cancellation is not assumed: the consumed SDK reservation remains known.
        XCTAssertEqual(state?.attestationReservation, call.reservation)
        let object = try JSONSerialization.jsonObject(with: store.read()!) as! [String: Any]
        for field in ["challenge", "nonce", "nonceHash", "request", "requestHash"] { XCTAssertNil(object[field]) }
        do { _ = try await subject.reserveSubmission(attemptIdentifier: id, at: 120_001); XCTFail() } catch {}
    }

    func testSDKSuccessDoesNotRenewDeadlineOrAcceptDuplicateProof() async throws {
        let store = Store(), subject = RendezvousRegistrationJournal(storage: store)
        let id = try await begin(subject)
        let call = try await subject.reserveAttestation(attemptIdentifier: id, at: 119_998)
        try await subject.completeAttestation(attemptIdentifier: id, reservation: call.reservation, result: .received(proof), at: 119_999)
        do { try await subject.completeAttestation(attemptIdentifier: id, reservation: call.reservation, result: .received(Data([99])), at: 119_999); XCTFail() } catch {}
        let submission = try await subject.reserveSubmission(attemptIdentifier: id, at: 119_999)
        let body = try JSONSerialization.jsonObject(with: submission.body) as! [String: String]
        XCTAssertEqual(body["attestation"], url(proof))
        do { _ = try await subject.reserveAttestation(attemptIdentifier: id, at: 119_999); XCTFail() } catch {}
        let state = try await subject.snapshot(at: 120_000)
        XCTAssertEqual(state?.phase, .registrationUncertain)
        XCTAssertEqual(state?.deadlineMS, 120_000)
    }

    func testInvalidSDKProofClosesAttemptInsteadOfGrantingAnotherCall() async throws {
        for bytes in [Data(), Data(repeating: 1, count: 32_769)] {
            let store = Store(), subject = RendezvousRegistrationJournal(storage: store)
            let id = try await begin(subject)
            let call = try await subject.reserveAttestation(attemptIdentifier: id, at: 0)
            do { try await subject.completeAttestation(attemptIdentifier: id, reservation: call.reservation, result: .received(bytes), at: 1); XCTFail() } catch {}
            let state = try await subject.snapshot(at: 1)
            XCTAssertEqual(state?.phase, .registrationUncertain)
            XCTAssertEqual(state?.attestationCallsStarted, 1)
            XCTAssertNil(state?.attestationReservation)
            do { _ = try await subject.reserveAttestation(attemptIdentifier: id, at: 2_001); XCTFail() } catch {}
        }
    }

    func testFailedSDKBeginningsAndReservationWritesDoNotPermitCalls() async throws {
        for committed in [false, true] {
            let store = Store(), subject = RendezvousRegistrationJournal(storage: store)
            store.faults(write: !committed, afterCommit: committed)
            do { _ = try await begin(subject); XCTFail() } catch {}
            store.faults()
            if committed { do { _ = try await begin(subject); XCTFail() } catch {} }
            else { _ = try await begin(subject) }
            let state = try await subject.snapshot(at: 0)
            let id = try XCTUnwrap(state?.attemptIdentifier)
            store.faults(write: !committed, afterCommit: committed)
            var calls = 0
            do { _ = try await subject.reserveAttestation(attemptIdentifier: id, at: 0); calls += 1; XCTFail() } catch {}
            XCTAssertEqual(calls, 0)
            store.faults()
            let restored = RendezvousRegistrationJournal(storage: store)
            let saved = try await restored.snapshot(at: 0)
            XCTAssertEqual(saved?.attestationCallsStarted, committed ? 1 : 0)
            if committed { do { _ = try await restored.reserveAttestation(attemptIdentifier: id, at: 1); XCTFail() } catch {} }
        }
    }

    func testAmbiguousSDKCompletionWriteCannotReopenSDKOrRegenerateProof() async throws {
        for committed in [false, true] {
            let store = Store(), subject = RendezvousRegistrationJournal(storage: store)
            let id = try await begin(subject)
            let call = try await subject.reserveAttestation(attemptIdentifier: id, at: 0)
            store.faults(write: !committed, afterCommit: committed)
            do { try await subject.completeAttestation(attemptIdentifier: id, reservation: call.reservation, result: .received(proof), at: 1); XCTFail() } catch {}
            store.faults()
            let restored = RendezvousRegistrationJournal(storage: store)
            let state = try await restored.snapshot(at: 1)
            XCTAssertEqual(state?.phase, committed ? .prepared : .attestationPending)
            do { _ = try await restored.reserveAttestation(attemptIdentifier: id, at: 1); XCTFail() } catch {}
            if !committed { do { _ = try await restored.reserveSubmission(attemptIdentifier: id, at: 1); XCTFail() } catch {} }
        }
    }

    func testVersionOneMigrationPreservesOriginalRequestAndInFlightRegistrationBudget() async throws {
        for phase in ["prepared", "registrationUncertain", "completed"] {
            let store = Store(), subject = RendezvousRegistrationJournal(storage: store)
            let id = try await prepare(subject)
            let call = try await subject.reserveSubmission(attemptIdentifier: id, at: 0)
            if phase != "prepared" {
                try await subject.completeSubmission(attemptIdentifier: id, reservation: call.reservation,
                                                     outcome: phase == "completed" ? .succeeded : .terminalFailure, at: 1)
            }
            var object = try JSONSerialization.jsonObject(with: store.read()!) as! [String: Any]
            object["schemaVersion"] = 1
            object.removeValue(forKey: "admission")
            store.inject(try JSONSerialization.data(withJSONObject: object))
            let restored = RendezvousRegistrationJournal(storage: store)
            let state = try await restored.snapshot(at: 1)
            XCTAssertEqual(state?.phase.rawValue, phase)
            XCTAssertEqual(state?.callsStarted, 1)
            XCTAssertEqual(state?.reservation, phase == "prepared" ? call.reservation : nil)
            var migrated = try JSONSerialization.jsonObject(with: store.read()!) as! [String: Any]
            XCTAssertEqual(migrated["schemaVersion"] as? Int, 2)
            XCTAssertEqual(migrated["admission"] as? String, "preparedImport")
            XCTAssertEqual(migrated["request"] as? String, object["request"] as? String)
            do { _ = try await begin(restored); XCTFail() } catch {}
            if phase == "prepared" {
                try await restored.completeSubmission(attemptIdentifier: id, reservation: call.reservation, outcome: .responseLost, at: 2)
                let retry = try await restored.reserveSubmission(attemptIdentifier: id, at: 2_002)
                XCTAssertEqual(retry.body, call.body)
                migrated = try JSONSerialization.jsonObject(with: store.read()!) as! [String: Any]
                XCTAssertEqual((migrated["window"] as? [String: Any])?["callsStarted"] as? Int, 2)
            }
        }
    }

    func testMalformedSDKRecordCannotDropAccountingChangeHashOrSmugglePreparedBytes() async throws {
        let store = Store(), subject = RendezvousRegistrationJournal(storage: store)
        let id = try await begin(subject)
        let call = try await subject.reserveAttestation(attemptIdentifier: id, at: 0)
        let bytes = try store.read()!
        for kind in 0..<11 {
            var object = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
            var sdk = object["attestationWindow"] as! [String: Any]
            switch kind {
            case 0: object.removeValue(forKey: "admission")
            case 1: object.removeValue(forKey: "attestationWindow")
            case 2: object["admission"] = "preparedImport"
            case 3: sdk["kind"] = "registration"
            case 4: sdk["deadlineMS"] = 119_999
            case 5: object["nonceHash"] = Data(repeating: 0, count: 32).base64EncodedString()
            case 6: object["request"] = Data([99]).base64EncodedString()
            case 7: object["schemaVersion"] = 1
            case 8: object["phase"] = "prepared"
            case 9: sdk["lastObservedMS"] = 1 // journal clock cannot trail its nested window
            default: var window = object["window"] as! [String: Any]; window["callsStarted"] = 1; window["reservation"] = UUID().uuidString; object["window"] = window
            }
            if kind != 1 { object["attestationWindow"] = sdk }
            store.inject(try JSONSerialization.data(withJSONObject: object))
            do { _ = try await subject.snapshot(at: 1); XCTFail("malformed SDK case \(kind)") } catch {}
        }
        store.inject(bytes)
        try await subject.completeAttestation(attemptIdentifier: id, reservation: call.reservation, result: .received(proof), at: 1)
        var object = try JSONSerialization.jsonObject(with: store.read()!) as! [String: Any]
        object.removeValue(forKey: "attestationWindow")
        store.inject(try JSONSerialization.data(withJSONObject: object))
        do { _ = try await subject.snapshot(at: 1); XCTFail() } catch {}
    }

    func testConcurrentSDKReservationsHaveOnePersistedWinner() async throws {
        let store = Store(), subject = RendezvousRegistrationJournal(storage: store)
        let id = try await begin(subject)
        let winners = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    do { _ = try await subject.reserveAttestation(attemptIdentifier: id, at: 0); return true }
                    catch { return false }
                }
            }
            var count = 0
            for await won in group { if won { count += 1 } }
            return count
        }
        XCTAssertEqual(winners, 1)
        let state = try await subject.snapshot(at: 0)
        XCTAssertEqual(state?.attestationCallsStarted, 1)
        XCTAssertEqual(state?.callsStarted, 0)
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
            case 0: object["schemaVersion"] = 3
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
