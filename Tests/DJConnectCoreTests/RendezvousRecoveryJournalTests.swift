import CryptoKit
import XCTest
@testable import DJConnectCore

final class RendezvousRecoveryJournalTests: XCTestCase {
    private final class Store: RendezvousRepairStorage, @unchecked Sendable {
        enum Failure: Error { case unavailable }
        private let lock = NSLock()
        private var data: Data?
        private var failRead = false, failWrite = false, afterCommit = false
        func faults(read: Bool = false, write: Bool = false, committed: Bool = false) {
            lock.withLock { failRead = read; failWrite = write; afterCommit = committed }
        }
        func read() throws -> Data? { try lock.withLock { if failRead { throw Failure.unavailable }; return data } }
        func write(_ bytes: Data) throws {
            try lock.withLock {
                if failWrite { throw Failure.unavailable }
                data = bytes
                if afterCommit { throw Failure.unavailable }
            }
        }
        func inject(_ bytes: Data) { lock.withLock { data = bytes } }
    }
    private let key = Data(repeating: 7, count: 32).base64EncodedString()
    private let nonce = Data(repeating: 9, count: 32)
    private var challenge: String { url(Data(repeating: 8, count: 32)) }
    private let assertion = Data([1, 2, 3]) // Synthetic only, not an Apple fixture.
    private func url(_ bytes: Data) -> String {
        bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    private func original(deadline: Int64 = 120_000) -> Data {
        // Deliberately unsorted, with whitespace/escaped key. Preserve these exact bytes.
        Data(" {\n\"action\":\"recover-key\",\"v\":\"djc-rendezvous/1\",\"key_id\":\"\(key)\",\"challenge_id\":\"\(challenge)\",\"challenge\":\"\(url(nonce))\",\"expires_at\":\(deadline),\"service_\\u006frigin\":\"\(DJConnectRendezvousQR.serviceOrigin)\" }\n".utf8)
    }
    private func begin(_ subject: RendezvousRecoveryJournal, bytes: Data? = nil) async throws -> UUID {
        try await subject.begin(keyIdentifier: key, challengeIdentifier: challenge, nonce: nonce,
                                clientData: bytes ?? original(), admittedAtMS: 0, deadlineMS: 120_000)
    }
    private func prepare(_ subject: RendezvousRecoveryJournal, bytes: Data? = nil) async throws -> UUID {
        let id = try await begin(subject, bytes: bytes)
        let call = try await subject.reserveAssertion(attemptIdentifier: id, at: 0)
        XCTAssertEqual(call.clientDataHash, Data(SHA256.hash(data: bytes ?? original())))
        XCTAssertEqual(call.keyIdentifier, key)
        XCTAssertEqual(call.deadlineMS, 120_000)
        try await subject.completeAssertion(attemptIdentifier: id, reservation: call.reservation, result: .received(assertion), at: 1)
        return id
    }

    func testOriginalNoncanonicalServerBytesAndExactRequestSurviveRetriesAndRestarts() async throws {
        let store = Store(), subject = RendezvousRecoveryJournal(storage: store)
        let id = try await prepare(subject)
        let first = try await subject.reserveSubmission(attemptIdentifier: id, at: 1)
        let object = try JSONSerialization.jsonObject(with: first.body) as! [String: String]
        XCTAssertEqual(object, ["v":"djc-rendezvous/1", "key_id":key, "challenge_id":challenge, "client_data":url(original()), "assertion":url(assertion)])
        try await subject.completeSubmission(attemptIdentifier: id, reservation: first.reservation, outcome: .responseLost, at: 100, retryNotBeforeMS: 3_000)
        let restored = RendezvousRecoveryJournal(storage: store)
        do { _ = try await restored.reserveSubmission(attemptIdentifier: id, at: 2_999); XCTFail() } catch {}
        let second = try await restored.reserveSubmission(attemptIdentifier: id, at: 3_000)
        XCTAssertEqual(second.body, first.body)
        try await restored.completeSubmission(attemptIdentifier: id, reservation: second.reservation, outcome: .responseLost, at: 3_100)
        do { _ = try await restored.reserveSubmission(attemptIdentifier: id, at: 8_099); XCTFail() } catch {}
        let third = try await restored.reserveSubmission(attemptIdentifier: id, at: 8_100)
        XCTAssertEqual(third.body, first.body)
        XCTAssertEqual(third.deadlineMS, 120_000)
        try await restored.completeSubmission(attemptIdentifier: id, reservation: third.reservation, outcome: .responseLost, at: 8_200)
        let state = try await restored.snapshot(at: 8_200)
        XCTAssertEqual(state?.phase, .recoveryPaused)
        XCTAssertEqual(state?.callsStarted, 3)
        XCTAssertEqual(state?.keyIdentifier, key)
        do { _ = try await begin(restored); XCTFail() } catch {}
    }

    func testStrictClientDataRejectsForeignFieldsDuplicateDecodedKeysAndInvalidSyntax() async throws {
        let text = String(decoding: original(), as: UTF8.self)
        let malformed = [
            text.replacingOccurrences(of: "recover-key", with: "delete-key"),
            text.replacingOccurrences(of: "recover-key", with: "submit"),
            text.replacingOccurrences(of: "recover-key", with: "recover-\\qkey"),
            text.replacingOccurrences(of: DJConnectRendezvousQR.serviceOrigin, with: "https://evil.example"),
            text.replacingOccurrences(of: key, with: Data(repeating: 4, count: 32).base64EncodedString()),
            text.replacingOccurrences(of: challenge, with: url(Data(repeating: 3, count: 32))),
            text.replacingOccurrences(of: url(nonce), with: url(Data(repeating: 2, count: 32))),
            text.replacingOccurrences(of: "120000", with: "120001"),
            text.replacingOccurrences(of: "120000", with: "true"),
            text.replacingOccurrences(of: "120000", with: "120000.5"),
            text.replacingOccurrences(of: "120000", with: "9007199254740992"),
            text.replacingOccurrences(of: "120000", with: "-1"),
            text.replacingOccurrences(of: "120000", with: "0120000"),
            text.replacingOccurrences(of: "120000", with: "null"),
            text.replacingOccurrences(of: "120000", with: "[]"),
            text.replacingOccurrences(of: " }", with: ",\"extra\":\"x\" }"),
            text.replacingOccurrences(of: " }", with: ",\"a\\u0063tion\":\"recover-key\" }"),
            text.replacingOccurrences(of: " }", with: ", }"),
            text + "{}", "[]", "{}", "{\"action\":\"unterminated\\", ""
        ].map { Data($0.utf8) } + [Data([0xff]), Data(repeating: 32, count: 2_049)]
        for (index, bytes) in malformed.enumerated() {
            let store = Store(), subject = RendezvousRecoveryJournal(storage: store)
            do { _ = try await begin(subject, bytes: bytes); XCTFail("malformed case \(index)") }
            catch RendezvousRecoveryJournal.Failure.invalidMaterial {}
            catch { XCTFail("Parser must return a redacted typed error, case \(index)") }
            XCTAssertNil(try store.read())
        }
    }

    func testRestoredAssertionReservationNeverAuthorizesSecondSignatureOrWrongCallback() async throws {
        let store = Store(), subject = RendezvousRecoveryJournal(storage: store)
        let id = try await begin(subject)
        let call = try await subject.reserveAssertion(attemptIdentifier: id, at: 0)
        let restored = RendezvousRecoveryJournal(storage: store)
        do { _ = try await restored.reserveAssertion(attemptIdentifier: id, at: 1); XCTFail() } catch {}
        do { _ = try await restored.reserveSubmission(attemptIdentifier: id, at: 1); XCTFail() } catch {}
        do { try await restored.completeAssertion(attemptIdentifier: UUID(), reservation: call.reservation, result: .received(assertion), at: 1); XCTFail() } catch {}
        do { try await restored.completeAssertion(attemptIdentifier: id, reservation: UUID(), result: .received(assertion), at: 1); XCTFail() } catch {}
        let state = try await restored.snapshot(at: 1)
        XCTAssertEqual(state?.assertionReservation, call.reservation)
        XCTAssertEqual(state?.phase, .assertionPending)
        XCTAssertEqual(state?.assertionStarted, true)
        try await restored.completeAssertion(attemptIdentifier: id, reservation: call.reservation, result: .received(assertion), at: 1)
        do { try await restored.completeAssertion(attemptIdentifier: id, reservation: call.reservation, result: .received(Data([99])), at: 2); XCTFail() } catch {}
    }

    func testAssertionFailureAndInvalidProofPauseWithoutAnotherSignature() async throws {
        for result: RendezvousRecoveryJournal.AssertionResult in [.failed, .received(Data()), .received(Data(repeating: 1, count: 4_097))] {
            let store = Store(), subject = RendezvousRecoveryJournal(storage: store)
            let id = try await begin(subject)
            let call = try await subject.reserveAssertion(attemptIdentifier: id, at: 0)
            do { try await subject.completeAssertion(attemptIdentifier: id, reservation: call.reservation, result: result, at: 1) } catch {}
            let state = try await RendezvousRecoveryJournal(storage: store).snapshot(at: 1)
            XCTAssertEqual(state?.phase, .recoveryPaused)
            XCTAssertTrue(try XCTUnwrap(state?.assertionStarted))
            XCTAssertNil(state?.assertionReservation)
            do { _ = try await subject.reserveAssertion(attemptIdentifier: id, at: 2); XCTFail() } catch {}
            try verifyPurged(store)
        }
    }

    private func verifyPurged(_ store: Store) throws {
        let object = try JSONSerialization.jsonObject(with: store.read()!) as! [String: Any]
        for field in ["challenge", "nonce", "clientData", "clientDataHash", "request", "requestHash"] { XCTAssertNil(object[field]) }
    }
    func testExpiryEqualityPurgesBothPhasesAndRejectsLateCompletions() async throws {
        for prepared in [false, true] {
            let store = Store(), subject = RendezvousRecoveryJournal(storage: store)
            let id = try await begin(subject)
            let call = try await subject.reserveAssertion(attemptIdentifier: id, at: 0)
            if prepared { try await subject.completeAssertion(attemptIdentifier: id, reservation: call.reservation, result: .received(assertion), at: 119_999) }
            do { try await subject.completeAssertion(attemptIdentifier: id, reservation: call.reservation, result: .received(assertion), at: 120_000); XCTFail() } catch {}
            let state = try await RendezvousRecoveryJournal(storage: store).snapshot(at: 120_000)
            XCTAssertEqual(state?.phase, .recoveryPaused)
            XCTAssertEqual(state?.assertionReservation, prepared ? nil : call.reservation)
            XCTAssertEqual(state?.deadlineMS, 120_000)
            try verifyPurged(store)
            do { _ = try await subject.reserveSubmission(attemptIdentifier: id, at: 120_001); XCTFail() } catch {}
        }
    }

    func testSavedInFlightTransportAndWrongIDsDoNotPermitReplay() async throws {
        let store = Store(), subject = RendezvousRecoveryJournal(storage: store)
        let id = try await prepare(subject)
        let call = try await subject.reserveSubmission(attemptIdentifier: id, at: 1)
        let restored = RendezvousRecoveryJournal(storage: store)
        do { _ = try await restored.reserveSubmission(attemptIdentifier: id, at: 2); XCTFail() } catch {}
        do { try await restored.completeSubmission(attemptIdentifier: id, reservation: UUID(), outcome: .succeeded, at: 2); XCTFail() } catch {}
        let state = try await restored.snapshot(at: 2)
        XCTAssertEqual(state?.reservation, call.reservation)
        XCTAssertEqual(state?.callsStarted, 1)
    }

    func testTerminalTransportAndSuccessPurgeWithoutResettingAttempt() async throws {
        for outcome: RendezvousRetryWindow.Outcome in [.terminalFailure, .appleServerUnavailable, .succeeded] {
            let store = Store(), subject = RendezvousRecoveryJournal(storage: store)
            let id = try await prepare(subject)
            let call = try await subject.reserveSubmission(attemptIdentifier: id, at: 1)
            try await subject.completeSubmission(attemptIdentifier: id, reservation: call.reservation, outcome: outcome, at: 2)
            let state = try await RendezvousRecoveryJournal(storage: store).snapshot(at: 2)
            let success: Bool = if case .succeeded = outcome { true } else { false }
            XCTAssertEqual(state?.phase, success ? .completed : .recoveryPaused)
            XCTAssertEqual(state?.callsStarted, 1)
            try verifyPurged(store)
            do { _ = try await begin(subject); XCTFail() } catch {}
        }
    }

    func testFailedAndAmbiguousWritesNeverReleaseAssertionOrSubmissionParameters() async throws {
        for stage in 0..<3 {
            for committed in [false, true] {
                let store = Store(), subject = RendezvousRecoveryJournal(storage: store)
                if stage == 0 {
                    store.faults(write: !committed, committed: committed)
                    do { _ = try await begin(subject); XCTFail() } catch {}
                    store.faults()
                    let state = try await subject.snapshot(at: 0)
                    XCTAssertEqual(state == nil, !committed)
                    continue
                }
                let id = try await begin(subject)
                if stage == 2 {
                    let call = try await subject.reserveAssertion(attemptIdentifier: id, at: 0)
                    try await subject.completeAssertion(attemptIdentifier: id, reservation: call.reservation, result: .received(assertion), at: 1)
                }
                store.faults(write: !committed, committed: committed)
                var externalCalls = 0
                do {
                    if stage == 1 { _ = try await subject.reserveAssertion(attemptIdentifier: id, at: 1) }
                    else { _ = try await subject.reserveSubmission(attemptIdentifier: id, at: 1) }
                    externalCalls += 1; XCTFail()
                } catch {}
                XCTAssertEqual(externalCalls, 0)
                store.faults()
                let state = try await RendezvousRecoveryJournal(storage: store).snapshot(at: 1)
                if stage == 1 { XCTAssertEqual(state?.assertionStarted, committed) }
                else { XCTAssertEqual(state?.callsStarted, committed ? 1 : 0) }
            }
        }
    }

    func testAmbiguousAssertionCompletionCannotCreateSecondSignature() async throws {
        for committed in [false, true] {
            let store = Store(), subject = RendezvousRecoveryJournal(storage: store)
            let id = try await begin(subject)
            let call = try await subject.reserveAssertion(attemptIdentifier: id, at: 0)
            store.faults(write: !committed, committed: committed)
            do { try await subject.completeAssertion(attemptIdentifier: id, reservation: call.reservation, result: .received(assertion), at: 1); XCTFail() } catch {}
            store.faults()
            let restored = RendezvousRecoveryJournal(storage: store)
            let state = try await restored.snapshot(at: 1)
            XCTAssertEqual(state?.phase, committed ? .prepared : .assertionPending)
            do { _ = try await restored.reserveAssertion(attemptIdentifier: id, at: 1); XCTFail() } catch {}
        }
    }

    func testUnavailableReadPurgeFailureAndClockRollbackNeverResetState() async throws {
        let store = Store(), subject = RendezvousRecoveryJournal(storage: store)
        let id = try await begin(subject)
        store.faults(read: true)
        do { _ = try await subject.reserveAssertion(attemptIdentifier: id, at: 0); XCTFail() } catch {}
        do { _ = try await begin(subject); XCTFail() } catch {}
        store.faults()
        _ = try await subject.snapshot(at: 2)
        do { _ = try await subject.snapshot(at: 1); XCTFail() } catch {}
        store.faults(write: true)
        do { _ = try await subject.snapshot(at: 120_000); XCTFail() } catch {}
        do { _ = try await subject.reserveAssertion(attemptIdentifier: id, at: 120_000); XCTFail() } catch {}
        store.faults()
        let state = try await subject.snapshot(at: 120_000)
        XCTAssertEqual(state?.phase, .recoveryPaused)
    }

    func testMaximumOriginalClientDataAndAssertionFitProtectedItem() async throws {
        let store = Store(), subject = RendezvousRecoveryJournal(storage: store)
        let bytes = original() + Data(repeating: 32, count: 2_048 - original().count)
        let id = try await begin(subject, bytes: bytes)
        let call = try await subject.reserveAssertion(attemptIdentifier: id, at: 0)
        XCTAssertEqual(call.clientDataHash, Data(SHA256.hash(data: bytes)))
        try await subject.completeAssertion(attemptIdentifier: id, reservation: call.reservation, result: .received(Data(repeating: 255, count: 4_096)), at: 1)
        let submission = try await subject.reserveSubmission(attemptIdentifier: id, at: 1)
        XCTAssertLessThanOrEqual(submission.body.count, 16_384)
        XCTAssertLessThanOrEqual(try store.read()!.count, 24_576)
    }

    func testCorruptPersistenceCannotChangeBindingsAccountingOrRequestBytes() async throws {
        let store = Store(), subject = RendezvousRecoveryJournal(storage: store)
        _ = try await prepare(subject)
        let bytes = try store.read()!
        for kind in 0..<10 {
            var object = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
            switch kind {
            case 0: object["schemaVersion"] = 2
            case 1: object["assertionStarted"] = false
            case 2: object["clientDataHash"] = Data(repeating: 0, count: 32).base64EncodedString()
            case 3: object["requestHash"] = Data(repeating: 0, count: 32).base64EncodedString()
            case 4: object["assertionReservation"] = UUID().uuidString
            case 5: object["key"] = "bad-key"
            case 6: var window = object["window"] as! [String: Any]; window["kind"] = "registration"; object["window"] = window
            case 7: object["lastObservedMS"] = -1
            default:
                var request = try JSONSerialization.jsonObject(with: Data(base64Encoded: object["request"] as! String)!) as! [String: Any]
                request[kind == 8 ? "client_data" : "extra"] = "foreign"
                let changed = try JSONSerialization.data(withJSONObject: request)
                object["request"] = changed.base64EncodedString(); object["requestHash"] = Data(SHA256.hash(data: changed)).base64EncodedString()
            }
            store.inject(try JSONSerialization.data(withJSONObject: object))
            do { _ = try await subject.snapshot(at: 1); XCTFail("corrupt \(kind)") } catch {}
        }
        store.inject(Data(repeating: 0, count: 24_577))
        do { _ = try await subject.snapshot(at: 1); XCTFail() } catch {}
    }

    func testConcurrentAssertionReservationsHaveExactlyOnePersistedWinner() async throws {
        let store = Store(), subject = RendezvousRecoveryJournal(storage: store)
        let id = try await begin(subject)
        let winners = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    do { _ = try await subject.reserveAssertion(attemptIdentifier: id, at: 0); return true }
                    catch { return false }
                }
            }
            var count = 0
            for await result in group { if result { count += 1 } }
            return count
        }
        XCTAssertEqual(winners, 1)
    }
}
