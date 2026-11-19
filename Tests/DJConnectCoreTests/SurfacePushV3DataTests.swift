import Foundation
import Testing
@testable import DJConnectCore

private final class SurfacePushV3FixtureAnchor: NSObject {}

@Suite struct SurfacePushV3DataTests {
    typealias Codec = DJConnectSurfacePushV3Data
    private func fixture(_ name: String) throws -> [String: Any] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: SurfacePushV3FixtureAnchor.self)
        #endif
        let url = try #require(bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") ?? bundle.url(forResource: name, withExtension: "json"))
        return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }
    private func cases() throws -> [[String: Any]] { try #require(fixture("surface-push-v3-actual-ha-wire")["cases"] as? [[String: Any]]) }
    private func bytes(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) }
    private func contextBody() throws -> [String: Any] { try #require(cases()[14]["response_body"] as? [String: Any]) }
    private func registrationBody() throws -> [String: Any] { try #require(cases()[18]["response_body"] as? [String: Any]) }
    private func context(_ object: [String: Any]? = nil) throws -> Codec.Context {
        let body = try object ?? contextBody()
        return try Codec.decodeContext(bytes(body), matchingOperation: #require(body["operation_id"] as? String))
    }
    private func rejectContext(_ body: [String: Any]) throws {
        let data = try bytes(body); let operation = try #require(contextBody()["operation_id"] as? String)
        #expect(throws: (any Error).self) { try Codec.decodeContext(data, matchingOperation: operation) }
    }
    private func rejectRegistration(_ body: [String: Any]) throws {
        let data = try bytes(body); let original = try context()
        #expect(throws: (any Error).self) { try Codec.decodeRegistration(data, matchingContext: original) }
    }

    @Test func originalActualContextRepliesRemainDataWithNoClockConversion() throws {
        let bodies = try cases().filter { $0["kind"] as? String == "context" }
            .compactMap { $0["response_body"] as? [String: Any] }.filter { $0["contract_version"] as? Int == 3 }
        let extra = try #require(fixture("surface-push-v3-actual-ha-original-clock-context")["context_replies"] as? [[String: Any]])
        #expect(bodies.count == 5); #expect(extra.count == 5)
        for body in bodies + extra {
            let value = try context(body)
            #expect(value.purposeExpiryMS == body["expires_at_ms"] as? Int64)
            #expect(value.contextExpiryMS == body["context_expires_at_ms"] as? Int64)
            #expect(value.purposeRemainingAtOriginalStartMS == body["purpose_remaining_at_original_start_ms"] as? Int64)
            #expect(value == (try context(body)))
        }
    }

    @Test func actualConfirmedAndUnknownRepliesStayDistinct() throws {
        let all = try cases(); var confirmed = 0; var unconfirmed = 0
        for entry in all where entry["kind"] as? String == "register" {
            guard let body = entry["response_body"] as? [String: Any], body["contract_version"] as? Int == 3 else { continue }
            let source = try #require(all.first { e in
                guard e["kind"] as? String == "context", let b = e["response_body"] as? [String: Any] else { return false }
                return b["operation_id"] as? String == body["operation_id"] as? String
            }?["response_body"] as? [String: Any])
            switch try Codec.decodeRegistration(bytes(body), matchingContext: context(source)) {
            case .confirmed(let value):
                confirmed += 1; #expect(body["success"] as? Bool == true)
                #expect(value.receipt.expires_at_ms == value.background.expires_at_ms)
                #expect(value.operation.result_available == false)
            case .unconfirmed(let value):
                unconfirmed += 1; #expect(body["success"] as? Bool == false)
                #expect(value.operation.phase == "unknown")
            }
        }
        #expect(confirmed == 4); #expect(unconfirmed == 2)
    }

    @Test func contextSchemaIsClosedAndNeverUpgradesV2() throws {
        let original = try contextBody()
        for key in original.keys { var body = original; body.removeValue(forKey: key); try rejectContext(body) }
        for key in ["rho_min", "background_read", "purpose", "extra"] { var body = original; body[key] = true; try rejectContext(body) }
        var old = original; old["contract_version"] = 2; try rejectContext(old)
        old.removeValue(forKey: "purpose_remaining_at_original_start_ms"); old.removeValue(forKey: "context_remaining_at_original_start_ms"); try rejectContext(old)
        let data = try bytes(original)
        #expect(throws: (any Error).self) { try Codec.decodeContext(data, matchingOperation: "01a16dde-5982-7000-8000-000000000099") }
    }

    @Test func contextRejectsInvalidTypesRangesAndOpaqueAliases() throws {
        let mutations: [(String, [Any])] = [
            ("contract_version", [0, 1, 2, 4, true, "3", NSNull()]),
            ("success", [false, 1, "true", NSNull()]), ("available", [false, 1, NSNull()]),
            ("expires_at_ms", [0, -1, 9_007_199_254_740_992 as Int64, true, "1792845250881", NSNull()]),
            ("context_expires_at_ms", [0, -1, 9_007_199_254_740_991 as Int64, true, NSNull()]),
            ("purpose_remaining_at_original_start_ms", [0, -1, 28_800_001, 29_999, true, "30000", NSNull()]),
            ("context_remaining_at_original_start_ms", [0, -1, 30_001, true, "30000", NSNull()]),
            ("context_handle", ["djcctx_" + String(repeating: "A", count: 42), "djcctx_" + String(repeating: "A", count: 42) + "B", "djcpref_" + String(repeating: "A", count: 43)]),
            ("purpose_ref", ["djcctx_" + String(repeating: "A", count: 43), "djcpref_" + String(repeating: "A", count: 42) + "B"]),
            ("cache_policy", ["public", "private", NSNull()])]
        for (key, values) in mutations { for value in values { var body = try contextBody(); body[key] = value; try rejectContext(body) } }
    }

    @Test func originalIntegerLexemesDuplicateAliasesAndBoundsFailBeforeProjection() throws {
        let original = String(decoding: try bytes(contextBody()), as: UTF8.self)
        for token in ["3.0", "3e0", "3E+0", "true", "\"3\"", "null", "NaN", "Infinity"] {
            let data = Data(original.replacingOccurrences(of: "\"contract_version\":3", with: "\"contract_version\":" + token).utf8)
            let op = try #require(contextBody()["operation_id"] as? String)
            #expect(throws: (any Error).self) { try Codec.decodeContext(data, matchingOperation: op) }
        }
        for injected in ["\"contract_version\":3,", "\"contract\\u005fversion\":3,"] {
            let data = Data(("{" + injected + original.dropFirst()).utf8)
            let op = try #require(contextBody()["operation_id"] as? String)
            #expect(throws: (any Error).self) { try Codec.decodeContext(data, matchingOperation: op) }
        }
        let op = try #require(contextBody()["operation_id"] as? String)
        for data in [Data(), Data(repeating: 32, count: 65_537), Data([0xff]), Data((original + "{}").utf8)] {
            #expect(throws: (any Error).self) { try Codec.decodeContext(data, matchingOperation: op) }
        }
    }

    @Test func validBoundaryDataDoesNotPretendToBeCurrentOrAnAuthority() throws {
        var body = try contextBody(); body["expires_at_ms"] = 1; body["context_expires_at_ms"] = 1
        body["purpose_remaining_at_original_start_ms"] = 1; body["context_remaining_at_original_start_ms"] = 1
        let historical = try context(body); #expect(historical.purposeExpiryMS == 1)
        // The decoder has no wall/monotonic sample, C0, rate or admission output.
        body["expires_at_ms"] = 9_007_199_254_740_991 as Int64; body["context_expires_at_ms"] = 9_007_199_254_740_991 as Int64
        body["purpose_remaining_at_original_start_ms"] = 28_800_000; body["context_remaining_at_original_start_ms"] = 30_000
        #expect(try context(body).purposeRemainingAtOriginalStartMS == 28_800_000)
    }

    @Test func registrationRequiresClosedOuterAndNestedObjects() throws {
        let original = try registrationBody()
        for key in original.keys { var b = original; b.removeValue(forKey: key); try rejectRegistration(b) }
        var b = original; b["extra"] = true; try rejectRegistration(b)
        for parent in ["operation", "registration", "background_read"] {
            let nested = try #require(original[parent] as? [String: Any])
            for key in nested.keys { var n = nested; n.removeValue(forKey: key); b = original; b[parent] = n; try rejectRegistration(b) }
            var n = nested; n["extra"] = true; b = original; b[parent] = n; try rejectRegistration(b)
        }
        for key in ["context_handle", "operation_id", "purpose_ref"] { b = original; b[key] = "wrong"; try rejectRegistration(b) }
        for key in ["registration", "background_read", "operation"] { b = original; b[key] = NSNull(); try rejectRegistration(b) }
    }

    @Test func confirmedReceiptNeverUsesSubmitExpiryOrMismatchedBackground() throws {
        let original = try registrationBody()
        for (parent, key, bad) in [
            ("registration", "expires_at_ms", 1792844680882 as Any),
            ("registration", "revision", true as Any), ("registration", "revision", 0 as Any),
            ("registration", "token_role", "live_activity_update" as Any), ("registration", "platform", "watchos" as Any),
            ("registration", "state", "unknown" as Any), ("registration", "last_error", "surface_relay_outcome_unknown" as Any),
            ("background_read", "registration_id", "other" as Any), ("background_read", "expires_at_ms", 1 as Any),
            ("background_read", "credential", "bearer" as Any), ("background_read", "scope", "session" as Any),
            ("operation", "contract_version", 3 as Any), ("operation", "result_available", true as Any),
            ("operation", "operation_id", "other" as Any), ("operation", "response_status", 503 as Any),
            ("operation", "phase", "unknown" as Any), ("operation", "error", "error" as Any)] {
            var b = original; var n = try #require(b[parent] as? [String: Any]); n[key] = bad; b[parent] = n; try rejectRegistration(b)
        }
    }

    @Test func unconfirmedOldOrAbsentRowNeverBecomesConfirmed() throws {
        let entries = try cases(); var body = try #require(entries[32]["response_body"] as? [String: Any])
        let source = try #require(entries[31]["response_body"] as? [String: Any]); let original = try context(source)
        var receipt = try #require(body["registration"] as? [String: Any]); receipt["expires_at_ms"] = 1; body["registration"] = receipt
        guard case .unconfirmed = try Codec.decodeRegistration(bytes(body), matchingContext: original) else { Issue.record("Old failure row became success"); return }
        body["registration"] = NSNull(); var operation = try #require(body["operation"] as? [String: Any])
        operation["phase"] = "confirmed"; operation["response_status"] = 200; operation["error"] = NSNull(); body["operation"] = operation
        guard case .unconfirmed(let value) = try Codec.decodeRegistration(bytes(body), matchingContext: original) else { Issue.record("Absent failure row became success"); return }
        #expect(value.receipt == nil)
        body["background_read"] = NSNull(); let data = try bytes(body)
        #expect(throws: (any Error).self) { try Codec.decodeRegistration(data, matchingContext: original) }
    }

    @Test func escapedNestedDuplicatesAndOriginalErrorFamilyAreNotSuccess() throws {
        let original = String(decoding: try bytes(registrationBody()), as: UTF8.self)
        let duplicate = original.replacingOccurrences(of: "\"operation\":{", with: "\"operation\":{\"result\\u005favailable\":false,")
        let ctx = try context()
        #expect(throws: (any Error).self) { try Codec.decodeRegistration(Data(duplicate.utf8), matchingContext: ctx) }
        var errors = 0
        for entry in try cases() {
            guard let b = entry["response_body"] as? [String: Any], Set(b.keys) == ["success", "error"] else { continue }
            let data = try bytes(b); errors += 1
            #expect(throws: (any Error).self) { try Codec.decodeContext(data, matchingOperation: ctx.operationID) }
            #expect(throws: (any Error).self) { try Codec.decodeRegistration(data, matchingContext: ctx) }
        }
        #expect(errors > 0)
    }
}
