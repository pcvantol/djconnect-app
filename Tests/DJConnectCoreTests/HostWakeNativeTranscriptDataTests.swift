import Foundation
import CryptoKit
import Testing
@testable import DJConnectCore

@Suite struct HostWakeNativeTranscriptDataTests {
    private struct Vector: Decodable {
        let canonical_utf8: String; let client_data_hex: String; let client_data_sha256: String
        let native_token_hex: String; let native_token_sha256: String; let wrong_hex_text_token_sha256: String
    }
    private func vector() throws -> Vector {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: HostWakeFixtureAnchor.self)
        #endif
        let url = try #require(bundle.url(forResource: "host-wake-native-transcript-api-0d686be", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "host-wake-native-transcript-api-0d686be", withExtension: "json"))
        return try JSONDecoder().decode(Vector.self, from: Data(contentsOf: url))
    }
    private func hex(_ bytes: Data) -> String { bytes.map { String(format: "%02x", $0) }.joined() }
    private func edited(_ edit: (inout [String: DirectRichWireJSON], inout [String: DirectRichWireJSON]) throws -> Void) throws -> Data {
        let value = try vector(), parsed = try DirectRichWireJSON.parse(Data(value.canonical_utf8.utf8), maximumBytes: 8192)
        var original = try #require(parsed.object?["original"]?.object), challenge = try #require(parsed.object?["challenge"]?.object)
        try edit(&original, &challenge)
        return try DirectRichWireJSON.object(["original": .object(original), "challenge": .object(challenge)]).canonicalData()
    }

    @Test func independentlyMatchesPythonBytesDomainAndTokenDigest() throws {
        let v = try vector(), transcript = try HostWakeNativeTranscriptData(canonicalTranscript: Data(v.canonical_utf8.utf8))
        #expect(hex(transcript.clientData) == v.client_data_hex)
        #expect(hex(transcript.clientDataHash) == v.client_data_sha256)
        #expect(transcript.clientData.starts(with: Data("DJC-HOST-APP-WAKE-TARGET-REGISTER-V1\n{".utf8)))
        let token = Data(0..<32) // Original fixture token bytes, not their hexadecimal text.
        #expect(hex(token) == v.native_token_hex)
        #expect(hex(Data(SHA256.hash(data: token))) == v.native_token_sha256)
        #expect(hex(Data(SHA256.hash(data: Data(v.native_token_hex.utf8)))) == v.wrong_hex_text_token_sha256)
        try transcript.compareData(originalCanonicalBytes: transcript.original.canonicalData(), nativeToken: token, advertisedHash: v.client_data_sha256)
        #expect(throws: (any Error).self) {
            try transcript.compareData(originalCanonicalBytes: transcript.original.canonicalData(), nativeToken: Data(v.native_token_hex.utf8), advertisedHash: v.client_data_sha256)
        }
        #expect(hex(Data(SHA256.hash(data: Data("DJC-HOST-APP-WAKE-TARGET-REGISTER-V1\\n".utf8) + transcript.canonicalBytes))) != v.client_data_sha256)
    }

    @Test func rejectsNoncanonicalOriginalBytesBeforeReturningPreimage() throws {
        let raw = try vector().canonical_utf8
        let changed = [" " + raw, raw + "\n", "\u{FEFF}" + raw,
            raw.replacingOccurrences(of: "\"revision\":1", with: "\"revision\":1.0"),
            raw.replacingOccurrences(of: "\"revision\":1", with: "\"revision\":1e0"),
            raw.replacingOccurrences(of: "\"revision\":1", with: "\"revision\":-0"),
            raw.replacingOccurrences(of: "\"captured_at_ms\":1800000000000", with: "\"captured_at_ms\":-0"),
            raw.replacingOccurrences(of: "\"revision\":1", with: "\"revision\":9007199254740992"),
            raw.replacingOccurrences(of: "\"revision\":1", with: "\"revision\":1,\"revision\":1"),
            raw.replacingOccurrences(of: "\"revision\"", with: "\"revi\\u0073ion\""),
            raw.replacingOccurrences(of: ":", with: ": ")]
        for bytes in changed {
            #expect(bytes != raw)
            #expect(throws: (any Error).self) { _ = try HostWakeNativeTranscriptData(canonicalTranscript: Data(bytes.utf8)) }
        }
        #expect(throws: (any Error).self) { _ = try HostWakeNativeTranscriptData(canonicalTranscript: Data([0xff])) }
        #expect(throws: (any Error).self) { _ = try HostWakeNativeTranscriptData(canonicalTranscript: Data(repeating: 32, count: 8193)) }
        // Semantically valid zero bounds make -0 rejection depend on the new
        // canonical-byte boundary, not merely on the timestamp range checks.
        let zero = try edited { o, c in
            o["original_wake_issued_at_ms"] = .integer(0)
            o["original_wake_expires_at_ms"] = .integer(3600000)
            o["original_display_expires_at_ms"] = .integer(7200000)
            c["captured_at_ms"] = .integer(0); c["expires_at_ms"] = .integer(30000)
        }
        _ = try HostWakeNativeTranscriptData(canonicalTranscript: zero)
        let minusZero = String(decoding: zero, as: UTF8.self).replacingOccurrences(of: "\"captured_at_ms\":0", with: "\"captured_at_ms\":-0")
        #expect(throws: (any Error).self) { _ = try HostWakeNativeTranscriptData(canonicalTranscript: Data(minusZero.utf8)) }
    }

    @Test(arguments: ["extra", "apiID", "role", "platform", "environment", "revision", "operation", "target", "key", "nonce", "challenge", "before", "after", "long", "wake", "display"])
    func rejectsClosedShapeOrOriginalBounds(_ kind: String) throws {
        let bytes = try edited { o, c in
            switch kind {
            case "extra": o["extra"] = .bool(true)
            case "apiID": o["core_install_token_record_id"] = .string("not-public")
            case "role": o["token_role"] = .string("widget")
            case "platform": o["platform"] = .string("macos")
            case "environment": o["apns_environment"] = .string("development")
            case "revision": o["revision"] = .integer(257)
            case "operation": o["operation_id"] = .string("11111111-1111-1111-8111-111111111111")
            case "target": o["target"] = .object(["host_bundle_id": .string("fixture"), "installation_id": .string("install")])
            case "key": o["native_key_id_b64"] = .string("YR==") // Nonzero pad bits.
            case "nonce": c["nonce_b64url"] = .string(String(repeating: "A", count: 42) + "B")
            case "challenge": c["challenge_id"] = .string("22222222-2222-4222-7222-222222222222")
            case "before": c["captured_at_ms"] = .integer(1799999999999)
            case "after": c["expires_at_ms"] = .integer(1800003600001)
            case "long": c["expires_at_ms"] = .integer(1800000030001)
            case "wake": o["original_wake_expires_at_ms"] = .integer(1800028800001); o["original_display_expires_at_ms"] = .integer(1800028800001)
            default: o["original_display_expires_at_ms"] = .integer(1800003599999)
            }
        }
        #expect(throws: (any Error).self) { _ = try HostWakeNativeTranscriptData(canonicalTranscript: bytes) }
    }

    @Test func validReplacementStillCannotMatchOriginalDataOrAdvertisedHash() throws {
        let v = try vector(), initial = try HostWakeNativeTranscriptData(canonicalTranscript: Data(v.canonical_utf8.utf8))
        for kind in ["nonce", "target", "expiry", "operation"] {
            let bytes = try edited { o, c in
                if kind == "nonce" { c["nonce_b64url"] = .string("BA" + String(repeating: "A", count: 41)) }
                else if kind == "target" { o["target"] = .object(["host_bundle_id": .string("example.changed.host"), "installation_id": .string("fixture-native-install")]) }
                else if kind == "expiry" { c["expires_at_ms"] = .integer(1800000029999) }
                else { o["operation_id"] = .string("33333333-3333-4333-8333-333333333333") }
            }
            let replaced = try HostWakeNativeTranscriptData(canonicalTranscript: bytes)
            #expect(replaced.clientDataHash != initial.clientDataHash)
            #expect(throws: (any Error).self) {
                try replaced.compareData(originalCanonicalBytes: initial.original.canonicalData(), nativeToken: Data(0..<32), advertisedHash: v.client_data_sha256)
            }
        }
    }

    @Test func standardBase64PlusSlashIsNotBase64URLOrReencoded() throws {
        let bytes = try edited { o, _ in o["native_key_id_b64"] = .string(Data([251, 255]).base64EncodedString()) }
        let transcript = try HostWakeNativeTranscriptData(canonicalTranscript: bytes)
        #expect(String(decoding: transcript.canonicalBytes, as: UTF8.self).contains("\"native_key_id_b64\":\"+/8=\""))
        #expect(throws: (any Error).self) { _ = try HostWakeNativeTranscriptData(canonicalTranscript: Data(String(decoding: bytes, as: UTF8.self).replacingOccurrences(of: "+/8=", with: "+\\/8=").utf8)) }
        let url = try edited { o, _ in o["native_key_id_b64"] = .string("-_8") }
        #expect(throws: (any Error).self) { _ = try HostWakeNativeTranscriptData(canonicalTranscript: url) }
    }
}
private final class HostWakeFixtureAnchor: NSObject {}
