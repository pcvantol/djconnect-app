import CryptoKit
import XCTest
#if SWIFT_PACKAGE
@testable import VibeCastBindingQualification
#endif

final class BinarySDKIntakeTests: XCTestCase {
    let start: Int64 = 1_800_000_000_000
    let key = Data(repeating: 7, count: 32).base64EncodedString()
    func token(_ value: UInt8) -> String { base64url(Data(repeating: value, count: 32)) }
    func expectation(_ action: ClientDataExpectation.Action) -> ClientDataExpectation {
        .init(action: action, keyID: key, challengeID: token(8), challenge: token(9), deadlineMS: start + 120_000,
              scan: action == .submit ? .init(transaction: "12345678-1234-4123-8123-123456789abc", generation: 1, browserThumbprint: token(1), deadlineMS: start + 120_000) : nil,
              envelopeDigest: action == .submit ? token(2) : nil)
    }
    func json(_ fields: [String: FlatValue]) throws -> Data {
        try JSONSerialization.data(withJSONObject: fields.mapValues { v -> Any in
            switch v { case .string(let s): return s; case .integer(let i): return i }
        }, options: [.sortedKeys, .withoutEscapingSlashes])
    }
    func response(_ original: Data? = nil) throws -> Data {
        var fields: [String: FlatValue] = ["v":.string("djc-rendezvous/1"), "challenge_id":.string(token(8)), "challenge":.string(token(9)), "expires_at":.integer(start + 120_000)]
        if let original { fields["client_data"] = .string(base64url(original)) }
        return try json(fields)
    }
    func registration() throws -> BinarySDKInput { try .registration(response: response(), keyID: key, requestedAtMS: start, nowMS: start) }

    func testRegistrationHashesDecodedNonceNotBase64UTF8() throws {
        let input = try registration()
        XCTAssertEqual(input.original, Data(repeating: 9, count: 32))
        XCTAssertEqual(input.hash, Data(SHA256.hash(data: Data(repeating: 9, count: 32))))
        XCTAssertNotEqual(input.hash, Data(SHA256.hash(data: Data(token(9).utf8))))
        XCTAssertEqual(input.challengeID, token(8)); XCTAssertEqual(input.action, "register")
    }
    func testAllActionInputsPreserveExactServerBytesAndSeparateActions() throws {
        for action in [ClientDataExpectation.Action.submit, .deleteKey, .recoverKey] {
            let expected = expectation(action), canonical = try json(expected.fields())
            let original = Data(" \n".utf8) + canonical + Data(" \n".utf8)
            let input = try BinarySDKInput.action(response: response(original), expectation: expected, requestedAtMS: start, nowMS: start)
            XCTAssertEqual(input.original, original)
            XCTAssertEqual(input.hash, Data(SHA256.hash(data: original)))
            XCTAssertNotEqual(input.hash, Data(SHA256.hash(data: canonical)))
            XCTAssertEqual(input.action, action.rawValue)
            for other in [ClientDataExpectation.Action.submit, .deleteKey, .recoverKey] where other != action {
                XCTAssertThrowsError(try BinarySDKInput.action(response: response(original), expectation: expectation(other), requestedAtMS: start, nowMS: start))
            }
        }
    }
    func testResponseAndClientDataBoundsAreSeparate() throws {
        let expected = expectation(.submit), compact = try json(expected.fields())
        let maximum = compact + Data(repeating: 32, count: 2_048 - compact.count)
        let wire = try response(maximum)
        XCTAssertGreaterThan(wire.count, 2_048)
        let input = try BinarySDKInput.action(response: wire, expectation: expected, requestedAtMS: start, nowMS: start)
        XCTAssertEqual(input.original, maximum)
        XCTAssertThrowsError(try BinarySDKInput.action(response: response(maximum + Data([32])), expectation: expected, requestedAtMS: start, nowMS: start))
    }
    func testRegistrationRejectsAliasesForeignFieldsDuplicatesAndNon32ByteNonce() throws {
        let valid = try FlatObject.parse(response())
        for field in valid.keys {
            var changed = valid; changed.removeValue(forKey: field)
            XCTAssertThrowsError(try BinarySDKInput.registration(response: json(changed), keyID: key, requestedAtMS: start, nowMS: start))
        }
        for bad in [token(9) + "=", token(9) + "\n", String(repeating: "_", count: 43), base64url(Data(repeating: 1, count: 31)), base64url(Data(repeating: 1, count: 33))] {
            var changed = valid; changed["challenge"] = .string(bad)
            XCTAssertThrowsError(try BinarySDKInput.registration(response: json(changed), keyID: key, requestedAtMS: start, nowMS: start))
        }
        let text = String(decoding: try response(), as: UTF8.self)
        for suffix in [",\"extra\":1}", ",\"\\u0076\":\"djc-rendezvous/1\"}"] {
            XCTAssertThrowsError(try BinarySDKInput.registration(response: Data((String(text.dropLast()) + suffix).utf8), keyID: key, requestedAtMS: start, nowMS: start))
        }
        XCTAssertThrowsError(try BinarySDKInput.registration(response: response(Data("{}".utf8)), keyID: key, requestedAtMS: start, nowMS: start))
        XCTAssertThrowsError(try BinarySDKInput.registration(response: response(), keyID: token(7), requestedAtMS: start, nowMS: start))
    }
    func testEveryResponseBindingAndOriginalDeadlineMustMatch() throws {
        let expected = expectation(.recoverKey), original = try json(expected.fields())
        for field in ["challenge_id", "challenge", "expires_at", "v"] {
            var fields = try FlatObject.parse(response(original))
            fields[field] = field == "expires_at" ? .integer(start + 119_999) : .string("changed")
            XCTAssertThrowsError(try BinarySDKInput.action(response: json(fields), expectation: expected, requestedAtMS: start, nowMS: start))
        }
        for requested in [-1, start - 1, start + 120_000] {
            XCTAssertThrowsError(try BinarySDKInput.action(response: response(original), expectation: expected, requestedAtMS: requested, nowMS: start))
        }
        XCTAssertThrowsError(try BinarySDKInput.action(response: response(original), expectation: expected, requestedAtMS: start, nowMS: start + 120_000))
    }
    func testMalformedJSONErrorsAreRedacted() throws {
        let invalid = Data("{\"v\":\"\\q\"}".utf8)
        do { _ = try BinarySDKInput.registration(response: invalid, keyID: key, requestedAtMS: start, nowMS: start); XCTFail() }
        catch BindingFailure.rejected {} catch { XCTFail("Raw parser error escaped") }
    }
    @MainActor func testSDKReceivesOriginalHashOnlyAfterPersistence() async throws {
        let runner = BinarySDKIntake(), input = try registration()
        var stored = false, calls = 0
        let proof = try await runner.perform(input, keyID: { self.key }, now: { self.start }, current: { true }, persist: { original, hash in
            XCTAssertEqual(original, Data(repeating: 9, count: 32)); XCTAssertEqual(hash, input.hash); stored = true
        }, sdk: { key, hash in
            XCTAssertTrue(stored); XCTAssertEqual(key, self.key); XCTAssertEqual(hash, input.hash); calls += 1
            return Data([1])
        })
        XCTAssertEqual(proof, Data([1])); XCTAssertEqual(calls, 1)
    }
    @MainActor func testNoSDKDispatchAfterFailedSaveChangedContextOrExpiry() async throws {
        let input = try registration()
        for mode in ["save", "key", "context", "expiry"] {
            let runner = BinarySDKIntake(); var time = start, current = true, selectedKey = key, calls = 0
            do {
                _ = try await runner.perform(input, keyID: { selectedKey }, now: { time }, current: { current }, persist: { _, _ in
                    if mode == "save" { throw NSError(domain: "private-synthetic-error", code: 1) }
                    if mode == "key" { selectedKey = "changed" }
                    if mode == "context" { current = false }
                    if mode == "expiry" { time = input.deadlineMS }
                }, sdk: { _, _ in calls += 1; return Data([1]) }); XCTFail(mode)
            } catch BindingFailure.rejected {} catch { XCTFail("Raw error escaped") }
            XCTAssertEqual(calls, 0)
        }
    }
    @MainActor func testLateWrongKeyInvalidProofAndSDKErrorNeverEscape() async throws {
        let input = try registration()
        for mode in ["expiry", "key", "context", "empty", "oversize", "error"] {
            let runner = BinarySDKIntake(); var time = start, keyID = key, current = true
            do {
                _ = try await runner.perform(input, keyID: { keyID }, now: { time }, current: { current }, persist: { _, _ in }, sdk: { _, _ in
                    await Task.yield()
                    if mode == "expiry" { time = input.deadlineMS }
                    if mode == "key" { keyID = "changed" }
                    if mode == "context" { current = false }
                    if mode == "error" { throw NSError(domain: "private-synthetic-error", code: 1) }
                    return Data(repeating: 1, count: mode == "empty" ? 0 : mode == "oversize" ? 32_769 : 1)
                }); XCTFail(mode)
            } catch BindingFailure.rejected {} catch { XCTFail("Raw error escaped") }
        }
    }
    @MainActor func testOneSDKOperationIncludesNestedRejectionAndRecoversAfterCompletion() async throws {
        let runner = BinarySDKIntake(), input = try registration(); var calls = 0
        _ = try await runner.perform(input, keyID: { self.key }, now: { self.start }, current: { true }, persist: { _, _ in }, sdk: { _, _ in
            calls += 1
            do {
                _ = try await runner.perform(input, keyID: { self.key }, now: { self.start }, current: { true }, persist: { _, _ in }, sdk: { _, _ in calls += 1; return Data([2]) }); XCTFail()
            } catch BindingFailure.rejected {}
            return Data([1])
        })
        _ = try await runner.perform(input, keyID: { self.key }, now: { self.start }, current: { true }, persist: { _, _ in }, sdk: { _, _ in calls += 1; return Data([3]) })
        XCTAssertEqual(calls, 2)
    }
    @MainActor func testActionProofLimitIs4096AndContextCheckedAfterSDK() async throws {
        let expected = expectation(.recoverKey)
        let original = try json(expected.fields())
        let input = try BinarySDKInput.action(response: response(original), expectation: expected, requestedAtMS: start, nowMS: start)
        let runner = BinarySDKIntake()
        for size in [4_096, 4_097] {
            do {
                let proof = try await runner.perform(input, keyID: { self.key }, now: { self.start }, current: { true }, persist: { bytes, hash in
                    XCTAssertEqual(bytes, original); XCTAssertEqual(hash, input.hash)
                }, sdk: { _, hash in XCTAssertEqual(hash, input.hash); return Data(repeating: 1, count: size) })
                XCTAssertEqual(size, 4_096); XCTAssertEqual(proof.count, size)
            } catch BindingFailure.rejected { XCTAssertEqual(size, 4_097) }
        }
    }
    @MainActor func testCancellationRetainsSlotUntilActualCallbackAndDiscardsLateResult() async throws {
        let runner = BinarySDKIntake(), input = try registration()
        var callback: CheckedContinuation<Data, Never>?
        let task = Task { @MainActor in
            try await runner.perform(input, keyID: { self.key }, now: { self.start }, current: { true }, persist: { _, _ in }, sdk: { _, _ in
                await withCheckedContinuation { callback = $0 }
            })
        }
        while callback == nil { await Task.yield() }
        task.cancel()
        var extraCalls = 0
        do {
            _ = try await runner.perform(input, keyID: { self.key }, now: { self.start }, current: { true }, persist: { _, _ in }, sdk: { _, _ in extraCalls += 1; return Data([1]) }); XCTFail()
        } catch BindingFailure.rejected {}
        XCTAssertEqual(extraCalls, 0)
        callback?.resume(returning: Data([1]))
        do { _ = try await task.value; XCTFail("Cancelled result must not escape") } catch BindingFailure.rejected {}
        _ = try await runner.perform(input, keyID: { self.key }, now: { self.start }, current: { true }, persist: { _, _ in }, sdk: { _, _ in Data([1]) })
    }
}
