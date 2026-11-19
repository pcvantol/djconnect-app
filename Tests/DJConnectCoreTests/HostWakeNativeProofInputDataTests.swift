import Foundation
import Testing
@testable import DJConnectCore

/// Public-shape fixture and DATA adapter tests only. No genuine parent,
/// enrolled key, signed policy, clock supplier or native SDK call is created.
@Suite struct HostWakeNativeProofInputDataTests {
    private struct Vector: Decodable {
        let original: DirectRichWireJSON
        let canonical_transcript_utf8: String
        let client_data_sha256: String
        let native_proof_kind: String
        let native_token_b64: String
    }
    private func vector() throws -> Vector {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: NativeProofInputFixtureAnchor.self)
        #endif
        let url = try #require(bundle.url(forResource: "host-wake-native-sdk-input-api-03323cd", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "host-wake-native-sdk-input-api-03323cd", withExtension: "json"))
        return try JSONDecoder().decode(Vector.self, from: Data(contentsOf: url))
    }
    private func input(_ v: Vector, kind: String? = nil) throws -> HostWakeNativeProofInputData {
        try .init(preparedOriginal: v.original.canonicalData(), preparedKind: kind ?? v.native_proof_kind,
            challengeTranscript: Data(v.canonical_transcript_utf8.utf8), challengeKind: kind ?? v.native_proof_kind,
            advertisedHash: v.client_data_sha256, suppliedSDKKeyIdentifier: #require(v.original.object?["native_key_id_b64"]?.string),
            originalToken: #require(Data(base64Encoded: v.native_token_b64)))
    }
    @Test func reproducesFrozenAPI03323cdSigningBytesWithoutPrivatePolicyFields() throws {
        let v = try vector(), value = try input(v)
        #expect(value.clientData == Data("DJC-HOST-APP-WAKE-TARGET-REGISTER-V1\n".utf8) + Data(v.canonical_transcript_utf8.utf8))
        #expect(value.clientDataHash.map { String(format: "%02x", $0) }.joined() == "c0ad2efea348cbe2c0e88be04148ccd0d9d5ed459b15a62dba2c74ec59ed12f3")
        #expect(value.keyIdentifier == v.original.object?["native_key_id_b64"]?.string)
        #expect(v.original.object?["native_key_ref"] == nil)
        #expect(value.kind.sdkOperation == .attestKey)
    }
    @Test(arguments: ["app_attest_attestation", "app_attest_assertion"])
    func onlyRetainedServerKindSelectsSDKMethodAndOpaqueProofKind(_ kind: String) throws {
        let v = try vector(), value = try input(v, kind: kind)
        #expect(value.kind.sdkOperation == (kind == "app_attest_attestation" ? .attestKey : .generateAssertion))
        let bytes = Data([0, 255, 1, 2, 128]), proof = try value.proofData(bytes)
        #expect(proof.object?.keys.sorted() == ["bytes_b64", "kind"])
        #expect(proof.object?["kind"]?.string == kind)
        #expect(Data(base64Encoded: try #require(proof.object?["bytes_b64"]?.string)) == bytes)
        #expect(value.clientData == (try input(v)).clientData) // Kind is outside frozen R31 bytes.
    }
    @Test(arguments: ["kindFlip", "unknownKind", "keySwap", "keyPadBits", "keySize", "tokenHex", "originalSwap", "transcriptWhitespace", "hashSwap", "privateKeyRef"])
    func rejectsSubstitutionBeforeAnyNativeDispatch(_ variant: String) throws {
        let v = try vector()
        var original = try v.original.canonicalData(), transcript = Data(v.canonical_transcript_utf8.utf8)
        var preparedKind = v.native_proof_kind, challengeKind = preparedKind, hash = v.client_data_sha256
        var key = try #require(v.original.object?["native_key_id_b64"]?.string), token = try #require(Data(base64Encoded: v.native_token_b64))
        switch variant {
        case "kindFlip": challengeKind = "app_attest_assertion"
        case "unknownKind": preparedKind = "automatic"; challengeKind = preparedKind
        case "keySwap": key = Data(repeating: 42, count: 32).base64EncodedString()
        case "keyPadBits": key = String(key.dropLast(2)) + "9="
        case "keySize": key = Data(repeating: 42, count: 31).base64EncodedString()
        case "tokenHex": token = Data(token.map { String(format: "%02x", $0) }.joined().utf8)
        case "originalSwap":
            var changed = try #require(v.original.object); changed["core_purpose_id"] = .string("different-purpose")
            original = try DirectRichWireJSON.object(changed).canonicalData()
        case "transcriptWhitespace": transcript = Data([32]) + transcript
        case "hashSwap": hash = String(repeating: "0", count: 64)
        default:
            var root = try #require(DirectRichWireJSON.parse(transcript, maximumBytes: 8192).object)
            var changed = try #require(root["original"]?.object); changed["native_key_ref"] = .string("private-not-public")
            root["original"] = .object(changed); transcript = try DirectRichWireJSON.object(root).canonicalData()
        }
        #expect(throws: (any Error).self) {
            _ = try HostWakeNativeProofInputData(preparedOriginal: original, preparedKind: preparedKind,
                challengeTranscript: transcript, challengeKind: challengeKind, advertisedHash: hash,
                suppliedSDKKeyIdentifier: key, originalToken: token)
        }
    }
    @Test(arguments: [1, 9216]) func exactOpaqueProofByteBoundsArePreserved(_ size: Int) throws {
        let value = try input(vector()), bytes = Data((0..<size).map { UInt8($0 % 256) })
        let proof = try value.proofData(bytes), b64 = try #require(proof.object?["bytes_b64"]?.string)
        #expect(Data(base64Encoded: b64) == bytes && b64 == bytes.base64EncodedString() && b64.utf8.count <= 12288)
    }
    @Test func emptyOversizeAndUnknownKindCannotProduceAProofBody() throws {
        for size in [0, 9217] {
            #expect(throws: (any Error).self) {
                _ = try HostWakeNativeProofInputData.proofData(kind: "app_attest_attestation", opaqueSDKBytes: Data(repeating: 0, count: size))
            }
        }
        #expect(throws: (any Error).self) { _ = try HostWakeNativeProofInputData.proofData(kind: "local-key-exists", opaqueSDKBytes: Data([1])) }
    }
}
private final class NativeProofInputFixtureAnchor: NSObject {}
