import Foundation
import CryptoKit
import Testing
@testable import DJConnectCore

private final class RichSurfaceFixtureAnchor: NSObject {}

@Suite struct RichSurfaceFragmentTests {
    typealias Codec = DJConnectRichSurfaceFragments

    private func fixtures() throws -> [String: [String: String]] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: RichSurfaceFixtureAnchor.self)
        #endif
        let url = try #require(bundle.url(forResource: "rich-surface-original-encoder-v1", withExtension: "json", subdirectory: "Fixtures") ?? bundle.url(forResource: "rich-surface-original-encoder-v1", withExtension: "json"))
        let body = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return try #require(body["files"] as? [String: [String: String]])
    }
    private func original(_ name: String) throws -> Data {
        let record = try #require(fixtures()[name + ".json"])
        let encoded = try #require(record["utf8_b64"])
        let bytes = try #require(Data(base64Encoded: encoded))
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        #expect(digest == record["sha256"])
        return bytes
    }
    private func b64(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    private func carrier(attributes: Data? = nil, state: Data? = nil) throws -> Data {
        let a = try attributes ?? original("attributes_original_uuid")
        let s = try state ?? original("state_rich_both")
        return Data("{\"schema_version\":1,\"profile_id\":\"djconnect-session-rich-v1\",\"attributes_utf8_b64u\":\"\(b64(a))\",\"content_state_utf8_b64u\":\"\(b64(s))\",\"source_observed_at_ms\":1000,\"source_expires_at_ms\":2000}".utf8)
    }
    private func reject(_ state: Data, attributes: Data? = nil) throws {
        let bytes = try carrier(attributes: attributes, state: state)
        #expect(throws: (any Error).self) { try Codec.decode(bytes) }
    }
    private func replacing(_ data: Data, _ from: String, _ to: String) -> Data {
        Data(String(decoding: data, as: UTF8.self).replacingOccurrences(of: from, with: to).utf8)
    }

    @Test func genuineOriginalEncoderFragmentsKeepExactBytesAndDates() throws {
        let originals = try fixtures()
        #expect(originals.count == 33) // 28 encoder outputs plus five decoder inputs.
        for name in originals.keys where name.hasPrefix("state_") && !name.contains(".input.") &&
            !name.contains("empty_rich") && !name.contains("extended_deadline") {
            let state = try original(String(name.dropLast(5)))
            let attributes = try original("attributes_original_uuid")
            let value = try Codec.decode(carrier(attributes: attributes, state: state))
            #expect(value.attributes == attributes); #expect(value.contentState == state)
            let typed = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: state)
            #expect(value.snapshot == typed)
            #expect(value.sourceObservedMS == 1000); #expect(value.sourceExpiresMS == 2000)
        }
        // Format-only accepts a String, not a native identity or creation grant.
        let unicode = try original("attributes_unicode_codec_only")
        #expect(try Codec.decode(carrier(attributes: unicode)).attributes == unicode)
    }

    @Test func originalUnsafeDecoderCounterexamplesAreRejected() throws {
        for name in ["state_unknown_key_codec_only.input", "state_optional_null.input",
                     "state_empty_rich_codec_only", "state_empty_rich_codec_only.input",
                     "state_same_pin_extended_deadline_codec_only", "state_same_pin_extended_deadline_codec_only.input"] {
            try reject(original(name))
        }
        let legacy = try original("state_legacy_missing_playbackState.input")
        #expect(try Codec.decode(carrier(state: legacy)).snapshot.rich?.playbackState == nil)
    }

    @Test func richCombinedAndCarrierByteBudgetsAreIndependentAndInclusive() throws {
        let rich = try original("rich_bytes_2800")
        let richTooLarge = try original("rich_bytes_2801")
        let state = Data(("{\"observedAt\":821692800.125,\"expiresAt\":821692830.125,\"rich\":" + String(decoding: rich, as: UTF8.self) + "}").utf8)
        _ = try Codec.decode(carrier(state: state))
        try reject(replacing(state, String(decoding: rich, as: UTF8.self), String(decoding: richTooLarge, as: UTF8.self)))
        let base = try original("attributes_original_uuid")
        let padded = base + Data(repeating: 32, count: 4096 - base.count - state.count)
        #expect(padded.count + state.count == 4096)
        _ = try Codec.decode(carrier(attributes: padded, state: state))
        try reject(state, attributes: padded + Data([32]))
        let wire = try carrier()
        _ = try Codec.decode(wire + Data(repeating: 32, count: 16_384 - wire.count))
        #expect(throws: (any Error).self) { try Codec.decode(wire + Data(repeating: 32, count: 16_385 - wire.count)) }
    }

    @Test func integerTokensCannotRoundFractionExponentUnderflowOrOverflowIntoAuthority() throws {
        let data = try carrier()
        let bad = ["true", "null", "\"1000\"", "1000.0", "1e3", "1E+3", "-1", "-0", "01", "+1",
                   "999.999999999999999999999", "1000.000000000000000000001", "1e-9999", "1e9999",
                   "9007199254740992", "9223372036854775808"]
        for token in bad {
            for pair in [("\"source_observed_at_ms\":1000", "\"source_observed_at_ms\":"),
                         ("\"source_expires_at_ms\":2000", "\"source_expires_at_ms\":"),
                         ("\"schema_version\":1", "\"schema_version\":")] {
                let mutated = replacing(data, pair.0, pair.1 + token)
                #expect(throws: (any Error).self) { try Codec.decode(mutated) }
            }
        }
        for token in ["true", "68.0", "6.8e1", "67.999999999999999999999", "-1", "-0", "9007199254740992"] {
            try reject(replacing(try original("state_rich_both"), "\"sequence\":68", "\"sequence\":" + token))
        }
        let equal = replacing(data, "\"source_expires_at_ms\":2000", "\"source_expires_at_ms\":1000")
        #expect(throws: (any Error).self) { try Codec.decode(equal) }
    }

    @Test func closedKeysDuplicatesTypesAndUnsafeUnicodeFailAtEveryDepth() throws {
        let bytes = try original("state_rich_both")
        for pair in [("{", "{\"extra\":1,"),
                     ("\"rich\":{", "\"rich\":{\"owner\":true,"),
                     ("\"contribution\":{", "\"contribution\":{\"text\":\"duplicate\","),
                     ("\"nowPlaying\":{", "\"nowPlaying\":{\"item_id\":\"duplicate\","),
                     ("\"rich\":{", "\"rich\":{\"received\\u0041t\":1,"),
                     ("\"receivedUptime\":1000503.756441875", "\"receivedUptime\":true"),
                     ("\"observedAt\":821692800.125", "\"observedAt\":\"2027-01-15T08:00:00.125Z\""),
                     ("\"theme\":\"groove\"", "\"theme\":null"),
                     ("\"theme\":\"groove\"", "\"theme\":\"\\uD800\""),
                     ("\"theme\":\"groove\"", "\"theme\":\"unknown\"")] {
            try reject(replacing(bytes, pair.0, pair.1))
        }
        for state in [Data(), Data([0xff]), Data("[]".utf8), Data("{}".utf8), bytes + bytes] { try reject(state) }
        for attributes in [Data(), Data("{}".utf8), Data("{\"presentationID\":null}".utf8),
                           Data("{\"presentationID\":\"a\",\"presentation\\u0049D\":\"b\"}".utf8),
                           Data("{\"presentationID\":\"a\",\"generation\":1}".utf8)] { try reject(bytes, attributes: attributes) }
    }

    @Test func carrierIsClosedAndBase64MustBeCanonicalNotJustDecodable() throws {
        let data = try carrier()
        for key in ["schema_version", "profile_id", "attributes_utf8_b64u", "content_state_utf8_b64u", "source_observed_at_ms", "source_expires_at_ms"] {
            var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any]); object.removeValue(forKey: key)
            let missing = try JSONSerialization.data(withJSONObject: object)
            #expect(throws: (any Error).self) { try Codec.decode(missing) }
        }
        for prefix in ["\"extra\":1,", "\"schema_version\":1,", "\"schema\\u005fversion\":1,"] {
            let duplicate = Data(("{" + prefix + String(decoding: data, as: UTF8.self).dropFirst()).utf8)
            #expect(throws: (any Error).self) { try Codec.decode(duplicate) }
        }
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for invalid in ["", "e30=", "e30\n", "+/8", "e31", "A", "===="] {
            object["attributes_utf8_b64u"] = invalid
            let wire = try JSONSerialization.data(withJSONObject: object)
            #expect(throws: (any Error).self) { try Codec.decode(wire) }
        }
        let old = replacing(data, "djconnect-session-rich-v1", "status8")
        #expect(throws: (any Error).self) { try Codec.decode(old) }
    }

    @Test func everyRequiredNestedFieldAndOptionalNullIsRejectedRatherThanNormalized() throws {
        let original = try self.original("state_rich_both")
        let object = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
        let rich = try #require(object["rich"] as? [String: Any])
        for key in ["bindingID", "generation", "sequence", "receivedAt", "receivedUptime", "expiresAt"] {
            var state = object; var fields = rich; fields.removeValue(forKey: key); state["rich"] = fields
            try reject(JSONSerialization.data(withJSONObject: state))
        }
        for slot in ["contribution", "nowPlaying"] {
            let field = try #require(rich[slot] as? [String: Any])
            for key in field.keys {
                var state = object; var fields = rich; var missing = field
                missing.removeValue(forKey: key); fields[slot] = missing; state["rich"] = fields
                try reject(JSONSerialization.data(withJSONObject: state))
            }
            var state = object; var fields = rich; var extra = field
            extra["permission"] = true; fields[slot] = extra; state["rich"] = fields
            try reject(JSONSerialization.data(withJSONObject: state))
        }
        for key in ["contribution", "nowPlaying", "playbackState"] {
            var state = object; var fields = rich; fields[key] = NSNull(); state["rich"] = fields
            try reject(JSONSerialization.data(withJSONObject: state))
        }
        for key in ["observedAt", "expiresAt", "theme", "rich"] {
            var state = object; state[key] = NSNull()
            try reject(JSONSerialization.data(withJSONObject: state))
        }
    }

    @Test func independentlyCurrentFieldDatesCannotBeReplacedByAggregateCurrentness() throws {
        let original = try self.original("state_rich_both")
        // Already-expired, not-yet-observed and same-pin extended fields.
        for pair in [("2027-01-15T08:00:30.125Z", "2027-01-15T08:00:00.125Z"),
                     ("2027-01-15T08:01:00.125Z", "2027-01-15T08:00:00.125Z"),
                     ("\"published_at\":\"2027-01-15T08:00:00.125Z\"", "\"published_at\":\"2027-01-15T08:00:01.125Z\""),
                     ("\"observed_at\":\"2027-01-15T08:00:00.125Z\"", "\"observed_at\":\"2027-01-15T08:00:01.125Z\""),
                     ("\"receivedAt\":821692800.125", "\"receivedAt\":821692801.125"),
                     ("\"receivedUptime\":1000503.756441875", "\"receivedUptime\":-1")] {
            try reject(replacing(original, pair.0, pair.1))
        }
        for field in ["observedAt", "expiresAt"] {
            for token in ["true", "false", "null", "1e9999", "NaN", "Infinity", "\"821692800.125\""] {
                let old = field == "observedAt" ? "821692800.125" : "821692830.125"
                try reject(replacing(original, "\"\(field)\":\(old)", "\"\(field)\":\(token)"))
            }
        }
        // Same carrier integers tell us nothing about original native bytes or
        // UTC/clock/owner authority: no positive publication API exists here.
        let maxSafe = replacing(try carrier(), "\"source_expires_at_ms\":2000", "\"source_expires_at_ms\":9007199254740991")
        #expect(try Codec.decode(maxSafe).sourceExpiresMS == 9_007_199_254_740_991)
    }
}
