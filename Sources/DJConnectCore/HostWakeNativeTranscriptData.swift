import Foundation
import CryptoKit

/// Closed host-wake transcript DATA only. No SDK call, key enrollment, clock
/// qualification or permission is produced by parsing or comparing this value.
/// Source-preparation counterpart of API receiving wire e7f0964436fb6362.
struct HostWakeNativeTranscriptData: Sendable {
    static let domain = Data("DJC-HOST-APP-WAKE-TARGET-REGISTER-V1\n".utf8)
    let original: DirectRichWireJSON
    let challenge: DirectRichWireJSON
    let canonicalBytes: Data
    let clientData: Data
    var clientDataHash: Data { Data(SHA256.hash(data: clientData)) }

    init(canonicalTranscript bytes: Data) throws {
        let root = try DirectRichWireJSON.parse(bytes, maximumBytes: 8192)
        let envelope = try Self.exact(root, ["original", "challenge"])
        let original = envelope["original"]!, challenge = envelope["challenge"]!
        let values = try Self.validateOriginalData(original)
        try Self.validateChallenge(challenge, original: values)
        // Compare original bytes, BEFORE returning any signing preimage. The
        // older shared Core parser intentionally remains unchanged; this new
        // boundary rejects -0, floats, escaped keys, BOM, whitespace and order.
        guard try root.canonicalData() == bytes else { throw DJConnectError.invalidResponse }
        let clientData = Self.domain + bytes
        guard clientData.count <= 8192 else { throw DJConnectError.invalidResponse }
        self.original = original; self.challenge = challenge
        canonicalBytes = bytes; self.clientData = clientData
    }

    /// Equality to caller-supplied DATA, not an admission or native dispatch
    /// permit. The eventual owner must supply genuine immutable prepare/native
    /// observations and independently recheck lifetime/currentness at final use.
    func compareData(originalCanonicalBytes: Data, nativeToken: Data, advertisedHash: String) throws {
        guard try original.canonicalData() == originalCanonicalBytes,
              (16...2048).contains(nativeToken.count),
              original.object?["native_token_sha256"]?.string == Self.hex(Data(SHA256.hash(data: nativeToken))),
              Self.matches(advertisedHash, "[a-f0-9]{64}"),
              Self.hex(clientDataHash) == advertisedHash else { throw DJConnectError.invalidResponse }
    }

    private static let hashes = ["paired_subject_binding_sha256", "owner_binding", "device_binding", "source_binding",
                                 "selected_ha_origin_sha256", "identity_policy_sha256", "deployment_policy_sha256", "native_token_sha256"]
    /// Shared structural DATA checks; this is not an enrollment/permission port.
    static func validateOriginalData(_ value: DirectRichWireJSON) throws -> [String: DirectRichWireJSON] {
        let v = try exact(value, ["version", "core_purpose_id", "operation_id", "generation", "revision", "token_role", "target",
            "platform", "apns_environment", "native_key_id_b64", "original_wake_issued_at_ms", "original_wake_expires_at_ms",
            "original_display_expires_at_ms"] + hashes)
        guard v["version"]?.string == "djc-host-app-wake-native/1", v["token_role"]?.string == "host_app_wake",
              ["ios", "ipados"].contains(v["platform"]?.string ?? ""),
              ["sandbox", "production"].contains(v["apns_environment"]?.string ?? "") else { throw DJConnectError.invalidResponse }
        for key in ["core_purpose_id", "generation"] { try string(v[key], pattern: "[A-Za-z0-9_-]{1,128}") }
        try uuid(v["operation_id"])
        for key in hashes { try string(v[key], pattern: "[a-f0-9]{64}") }
        let target = try exact(v["target"]!, ["host_bundle_id", "installation_id"])
        try string(target["installation_id"], pattern: "[A-Za-z0-9_-]{1,128}")
        try string(target["host_bundle_id"], pattern: "[A-Za-z0-9-]+(?:\\.[A-Za-z0-9-]+)+")
        guard target["host_bundle_id"]!.string!.utf8.count <= 200 else { throw DJConnectError.invalidResponse }
        _ = try integer(v["revision"], minimum: 1, maximum: 256)
        let issued = try integer(v["original_wake_issued_at_ms"])
        let expiry = try integer(v["original_wake_expires_at_ms"], minimum: issued + 1)
        _ = try integer(v["original_display_expires_at_ms"], minimum: expiry)
        guard expiry - issued <= 28_800_000 else { throw DJConnectError.invalidResponse }
        // Generic DATA bounds match API, not the selected App Attest policy.
        // Real App Attest enrollment separately requires the actual SDK key ID
        // (SHA256/public-key identity, 32 decoded bytes) and original custody.
        guard let key = v["native_key_id_b64"]?.string, key.utf8.count <= 1368,
              let decoded = Data(base64Encoded: key), (1...1024).contains(decoded.count),
              decoded.base64EncodedString() == key else { throw DJConnectError.invalidResponse }
        return v
    }

    private static func validateChallenge(_ value: DirectRichWireJSON, original: [String: DirectRichWireJSON]) throws {
        let v = try exact(value, ["challenge_id", "nonce_b64url", "captured_at_ms", "expires_at_ms"])
        try uuid(v["challenge_id"])
        try string(v["nonce_b64url"], pattern: "[A-Za-z0-9_-]{43}")
        let nonce = v["nonce_b64url"]!.string!
        guard let decoded = Data(base64Encoded: nonce.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") + "="),
              decoded.count == 32,
              decoded.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "") == nonce else { throw DJConnectError.invalidResponse }
        let captured = try integer(v["captured_at_ms"], minimum: original["original_wake_issued_at_ms"]!.integer!)
        let expiry = try integer(v["expires_at_ms"], minimum: captured + 1, maximum: original["original_wake_expires_at_ms"]!.integer!)
        guard expiry - captured <= 30_000 else { throw DJConnectError.invalidResponse }
    }

    private static func exact(_ value: DirectRichWireJSON, _ keys: [String]) throws -> [String: DirectRichWireJSON] {
        guard let v = value.object, Set(v.keys) == Set(keys) else { throw DJConnectError.invalidResponse }; return v
    }
    private static func integer(_ value: DirectRichWireJSON?, minimum: Int64 = 0, maximum: Int64 = 9_007_199_254_740_991) throws -> Int64 {
        guard let v = value?.integer, v >= minimum, v <= maximum else { throw DJConnectError.invalidResponse }; return v
    }
    private static func string(_ value: DirectRichWireJSON?, pattern: String) throws {
        guard let v = value?.string, matches(v, pattern) else { throw DJConnectError.invalidResponse }
    }
    private static func uuid(_ value: DirectRichWireJSON?) throws {
        try string(value, pattern: "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}")
    }
    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: "\\A(?:" + pattern + ")\\z", options: .regularExpression) != nil
    }
    private static func hex(_ bytes: Data) -> String { bytes.map { String(format: "%02x", $0) }.joined() }
}
