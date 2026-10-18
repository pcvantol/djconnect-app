import XCTest
import CryptoKit
#if SWIFT_PACKAGE
@testable import VibeCastBindingQualification
#endif

final class BindingTests: XCTestCase {
    let epoch: Int64 = 1_800_000_000_000
    func token(_ n: UInt8) -> String { base64url(Data(repeating: n, count: 32)) }
    func scan() -> ScanContext { .init(transaction: "12345678-1234-4123-8123-123456789abc", generation: 7,
                                      browserThumbprint: token(1), deadlineMS: epoch + 120_000) }
    func scope() -> LocalScope { .init(installation: "synthetic-install", pairingGeneration: 2, profileGeneration: 3,
        routeGeneration: 4, displayURL: "https://ha.example/djconnect/vibecast/display", issuerEpoch: token(2)) }
    func expected(_ action: ClientDataExpectation.Action = .submit) -> ClientDataExpectation {
        .init(action: action, keyID: Data(repeating: 255, count: 32).base64EncodedString(),
              challengeID: token(3), challenge: token(4), deadlineMS: epoch + 30_000,
              scan: action == .submit ? scan() : nil, envelopeDigest: action == .submit ? token(5) : nil)
    }
    func wire(_ fields: [String: FlatValue]) throws -> Data {
        let raw: [String: Any] = fields.mapValues { v in
            switch v { case .string(let s): return s; case .integer(let n): return n }
        }
        return try JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys, .withoutEscapingSlashes])
    }
    func testOriginalBytesHashWithoutReserializationAndActionSeparation() throws {
        for action in [ClientDataExpectation.Action.submit, .deleteKey, .recoverKey] {
            let expectation = expected(action), compact = try wire(expectation.fields())
            let formatted = Data(([UInt8(32), 10] + Array(compact) + [10]))
            let result = try expectation.validate(formatted, at: epoch)
            XCTAssertEqual(result.bytes, formatted)
            XCTAssertEqual(result.hash, Data(SHA256.hash(data: formatted)))
            XCTAssertNotEqual(result.hash, Data(SHA256.hash(data: compact)))
            for other in [ClientDataExpectation.Action.submit, .deleteKey, .recoverKey] where other != action {
                XCTAssertThrowsError(try expected(other).validate(formatted, at: epoch))
            }
        }
    }
    func testEveryCapturedFieldIsBoundAndClosed() throws {
        for action in [ClientDataExpectation.Action.submit, .deleteKey, .recoverKey] {
            let expectation = expected(action), original = try expectation.fields()
            for key in original.keys.sorted() {
                var changed = original
                switch changed[key]! { case .string(let s): changed[key] = .string(s + "x"); case .integer(let n): changed[key] = .integer(n + 1) }
                XCTAssertThrowsError(try expectation.validate(wire(changed), at: epoch), key)
                changed = original; changed.removeValue(forKey: key)
                XCTAssertThrowsError(try expectation.validate(wire(changed), at: epoch), key)
            }
            var extra = original; extra["profile_id"] = .string("never-release")
            XCTAssertThrowsError(try expectation.validate(wire(extra), at: epoch))
        }
    }
    func testHostileJSONAndDuplicateDecodedKeys() throws {
        let candidates = ["{\"a\":1,\"a\":2}", "{\"a\":1,\"\\u0061\":2}", "{\"a\":true}", "{\"a\":null}",
            "{\"a\":[]}", "{\"a\":{}}", "{\"a\":1.0}", "{\"a\":1e0}", "{\"a\":-1}", "{\"a\":01}",
            "{\"a\":9007199254740992}", "{\"a\":1,}", "{\"a\":\"\\q\"}", "{\"a\":\"\\\"}", "{}{}", "[]", "{} false"]
        for candidate in candidates { XCTAssertThrowsError(try FlatObject.parse(Data(candidate.utf8)), candidate) }
        XCTAssertThrowsError(try FlatObject.parse(Data([123, 34, 255, 34, 58, 48, 125])))
        XCTAssertThrowsError(try FlatObject.parse(Data(repeating: 32, count: 2049)))
        XCTAssertEqual(try FlatObject.parse(Data("{\"a\":\"escaped \\\" quote \\u0062\"}".utf8))["a"], .string("escaped \" quote b"))
    }
    func testOriginalDeadlinesAndCanonicalIdentifiers() throws {
        let expectation = expected(), bytes = try wire(expectation.fields())
        _ = try expectation.validate(bytes, at: expectation.deadlineMS - 1)
        for now in [-1, expectation.deadlineMS, expectation.deadlineMS + 1] { XCTAssertThrowsError(try expectation.validate(bytes, at: now)) }
        XCTAssertFalse(ClientDataExpectation.opaque(token(1) + "="))
        XCTAssertFalse(ClientDataExpectation.standardKey(token(255)))
        XCTAssertTrue(ClientDataExpectation.standardKey(expectation.keyID))
        XCTAssertFalse(ClientDataExpectation.opaque(String(repeating: "_", count: 43))) // noncanonical padding bits
    }
    func testCanonicalEncodedClientDataRetainsExactBytes() throws {
        let expectation = expected(), original = try wire(expectation.fields())
        let encoded = base64url(original)
        XCTAssertEqual(try expectation.validateEncoded(encoded, at: epoch).bytes, original)
        for bad in [encoded + "=", encoded + "\n", "%" + encoded, "A", "", String(repeating: "A", count: 2732)] {
            XCTAssertThrowsError(try expectation.validateEncoded(bad, at: epoch))
        }
    }
    func testCancellationRotationBackgroundAndScopeABACannotRevive() throws {
        for _ in ["cancel", "background", "profile", "pairing", "route", "QR rotation"] {
            var fence = FlowFence(); let old = try fence.begin(scope: scope(), scan: scan())
            try fence.check(old, currentScope: scope(), nowMS: epoch)
            fence.invalidate(); _ = try fence.begin(scope: scope(), scan: scan())
            XCTAssertThrowsError(try fence.check(old, currentScope: scope(), nowMS: epoch))
        }
        var fence = FlowFence(); let ticket = try fence.begin(scope: scope(), scan: scan())
        XCTAssertThrowsError(try fence.check(ticket, currentScope: scope(), nowMS: scan().deadlineMS))
        let changed = LocalScope(installation: "other", pairingGeneration: 2, profileGeneration: 3, routeGeneration: 4,
                                 displayURL: scope().displayURL, issuerEpoch: scope().issuerEpoch)
        XCTAssertThrowsError(try fence.check(ticket, currentScope: changed, nowMS: epoch))
    }
    @MainActor func testInvalidatedDuringSignerAwaitNeverReleasesAssertion() async throws {
        let harness = ActionBindingHarness(), expectation = expected()
        let ticket = try harness.fence.begin(scope: scope(), scan: scan())
        do {
            _ = try await harness.sign(ticket: ticket, expectation: expectation, original: wire(expectation.fields()),
                scope: { self.scope() }, keyID: { expectation.keyID }, now: { self.epoch }) { hash in
                    XCTAssertEqual(hash.count, 32)
                    await Task.yield(); harness.fence.invalidate()
                    return Data([1, 2, 3])
                }
            XCTFail("Old assertion must never escape an invalidated flow")
        } catch is BindingFailure { }
    }
    @MainActor func testValidSignerAndNestedConcurrentActionGate() async throws {
        let harness = ActionBindingHarness(), expectation = expected()
        let ticket = try harness.fence.begin(scope: scope(), scan: scan()), bytes = try wire(expectation.fields())
        var calls = 0
        let result = try await harness.sign(ticket: ticket, expectation: expectation, original: bytes,
            scope: { self.scope() }, keyID: { expectation.keyID }, now: { self.epoch }) { _ in
                calls += 1
                do {
                    _ = try await harness.sign(ticket: ticket, expectation: expectation, original: bytes,
                        scope: { self.scope() }, keyID: { expectation.keyID }, now: { self.epoch }, signer: { _ in
                            calls += 1; return Data([9])
                        })
                    XCTFail("Concurrent use must not reach signer")
                } catch is BindingFailure { }
                return Data([1])
            }
        XCTAssertEqual(calls, 1); XCTAssertEqual(result, Data([1]))
    }
    @MainActor func testKeyExpiryAndProofBoundsRecheckedAfterAwait() async throws {
        for mode in ["key", "expiry", "empty", "oversize"] {
            let harness = ActionBindingHarness(), expectation = expected()
            let ticket = try harness.fence.begin(scope: scope(), scan: scan())
            var key = expectation.keyID, time = epoch
            do {
                _ = try await harness.sign(ticket: ticket, expectation: expectation, original: wire(expectation.fields()),
                    scope: { self.scope() }, keyID: { key }, now: { time }) { _ in
                        await Task.yield()
                        if mode == "key" { key = "changed" }
                        if mode == "expiry" { time = expectation.deadlineMS }
                        return Data(repeating: 1, count: mode == "empty" ? 0 : mode == "oversize" ? 4097 : 1)
                    }
                XCTFail(mode)
            } catch is BindingFailure { }
        }
    }
    @MainActor func testInvalidInputNeverCallsSignerAndFailureReleasesGate() async throws {
        let harness = ActionBindingHarness(), expectation = expected()
        let ticket = try harness.fence.begin(scope: scope(), scan: scan())
        var calls = 0
        for bytes in [Data("{}".utf8), try wire(expected(.deleteKey).fields())] {
            do {
                _ = try await harness.sign(ticket: ticket, expectation: expectation, original: bytes,
                    scope: { self.scope() }, keyID: { expectation.keyID }, now: { self.epoch }) { _ in calls += 1; return Data([1]) }
                XCTFail("Must reject before signer")
            } catch is BindingFailure { }
        }
        XCTAssertEqual(calls, 0)
        for _ in 0..<2 {
            do {
                _ = try await harness.sign(ticket: ticket, expectation: expectation, original: wire(expectation.fields()),
                    scope: { self.scope() }, keyID: { expectation.keyID }, now: { self.epoch }) { _ in
                        calls += 1; throw BindingFailure.rejected
                    }
                XCTFail("Signer failure must escape")
            } catch is BindingFailure { }
        }
        XCTAssertEqual(calls, 2)
    }
}
