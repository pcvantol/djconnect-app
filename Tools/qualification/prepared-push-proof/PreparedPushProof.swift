import Foundation
import CoreFoundation
import CryptoKit

// Uncomposed PRIVATE R9/v2/R2 preparation. No shipping import, native SDK,
// transport, consent, clock witness or operational admission constructor.
enum PreparedPushProof {
    enum Invalid: Error { case data }
    indirect enum Value: Equatable {
        case object([String: Value]), string(String), integer(Int64), null
        static func == (a: Value, b: Value) -> Bool {
            switch (a, b) {
            case (.null, .null): return true
            case (.integer(let x), .integer(let y)): return x == y
            case (.string(let x), .string(let y)): return x.utf8.elementsEqual(y.utf8)
            case (.object(let x), .object(let y)): return x == y
            default: return false
            }
        }
        var string: String? { if case .string(let s) = self { return s }; return nil }
        var object: [String: Value]? { if case .object(let o) = self { return o }; return nil }
        var integer: Int64? { if case .integer(let n) = self { return n }; return nil }
        static func from(_ any: Any) throws -> Value {
            if any is NSNull { return .null }
            if let s = any as? String { return .string(s) }
            if let n = any as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() { return .integer(n.int64Value) }
            if let o = any as? [String: Any] { return .object(try o.mapValues(from)) }
            throw Invalid.data
        }
        var canonical: String {
            switch self {
            case .null: return "null"
            case .integer(let n): return String(n)
            case .string(let s):
                var r = "\""
                for c in s.unicodeScalars {
                    switch c.value {
                    case 34: r += "\\\""
                    case 92: r += "\\\\"
                    case 8: r += "\\b"
                    case 12: r += "\\f"
                    case 10: r += "\\n"
                    case 13: r += "\\r"
                    case 9: r += "\\t"
                    case 0..<32: r += String(format: "\\u%04x", c.value)
                    default: r.unicodeScalars.append(c)
                    }
                }
                return r + "\""
            case .object(let o):
                return "{" + o.keys.sorted().map { Value.string($0).canonical + ":" + o[$0]!.canonical }.joined(separator: ",") + "}"
            }
        }
    }
    static let uuid = "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
    static let hex = "^[0-9a-f]{64}$"
    static let profile = "090b8c9cd0d0b74622cd8ce00accaaecd816feb9d762f0554a9709bbf6342517"
    static let domains = ["new_key_attestation": "DJC-PUSH-STATUS-KEY-ATTEST-V1\n", "existing_key_assertion": "DJC-PUSH-STATUS-KEY-REUSE-V1\n", "target_registration_assertion": "DJC-PUSH-STATUS-TARGET-REGISTER-V1\n"]
    static let common: Set<String> = ["contract_version", "proof_variant", "proof_port_audience", "proof_job_id", "bootstrap_id", "operation_id", "nonce_b64url", "candidate_sha256", "source_selection_sha256", "owner_approval_binding_sha256", "paired_subject_binding_sha256", "selected_ha_origin", "client_type", "token_role", "identity_policy_sha256", "deployment_policy_sha256", "profile_identity_sha256", "expected_target_generation", "prospective_activity_identity", "bootstrap_deadline_unix_ms", "original_grant_expires_at_unix_ms", "apple_key_id_b64"]
    // Exactly the values the original client can independently know. API-only
    // digests/key references are shape-checked and pinned, never guessed authority.
    static let knownKeys: Set<String> = ["bootstrap_id", "operation_id", "nonce_b64url", "candidate_sha256", "source_selection_sha256", "selected_ha_origin", "client_type", "token_role", "profile_identity_sha256", "expected_target_generation", "prospective_activity_identity", "bootstrap_deadline_unix_ms", "original_grant_expires_at_unix_ms", "apple_key_id_b64"]
    struct Expected: Equatable {
        let requestID: String
        let variant: String
        let known: [String: Value]
        // Only target preparation has a previously verified actual target/hash.
        let nativeTarget: Value?
        let nativeTokenHash: String?
        let verifiedKeyRef: String?
    }
    struct Parsed {
        let originalBytes: Data
        let clientDataHash: Data
        let job: String
        let opaqueBindings: [String: Value]
        let handle: String
        let preparedKeyRef: String?
    }
    static func matches(_ s: String?, _ pattern: String) -> Bool {
        guard let s else { return false }
        // Foundation $ also admits before a final newline: require full range.
        return s.range(of: pattern, options: .regularExpression) == s.startIndex..<s.endIndex
    }
    static func hash(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }
    static func require(_ b: Bool) throws { if !b { throw Invalid.data } }
    static func object(_ bytes: Data, max: Int) throws -> [String: Value] {
        try require(bytes.count <= max)
        try DJConnectSurfacePushJSON.validate(bytes) // BEFORE map decoding at every depth.
        guard case .object(let o) = try Value.from(JSONSerialization.jsonObject(with: bytes)) else { throw Invalid.data }
        return o
    }
    static func base64(_ s: String, count: ClosedRange<Int>) throws -> Data {
        guard s.utf8.count <= 5464, let d = Data(base64Encoded: s), count.contains(d.count), d.base64EncodedString() == s else { throw Invalid.data }
        return d
    }
    static func nonce(_ s: String?) throws {
        try require(matches(s, "^[A-Za-z0-9_-]{43}$"))
        let d = try base64(s!.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") + "=", count: 32...32)
        try require(d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") == s)
    }
    static func transcript(_ o: [String: Value], variant: String) throws {
        var keys = common
        if variant != "new_key_attestation" { keys.insert("verified_key_ref") }
        if variant == "target_registration_assertion" { keys.formUnion(["native_target", "native_token_sha256"]) }
        try require(domains[variant] != nil && Set(o.keys) == keys && o["contract_version"] == .integer(1) && o["proof_variant"] == .string(variant) && o["proof_port_audience"] == .string("djc-push-status-native-proof/1"))
        for k in ["proof_job_id", "bootstrap_id", "operation_id"] + (variant == "new_key_attestation" ? [] : ["verified_key_ref"]) { try require(matches(o[k]?.string, uuid)) }
        for k in ["candidate_sha256", "source_selection_sha256", "owner_approval_binding_sha256", "paired_subject_binding_sha256", "identity_policy_sha256", "deployment_policy_sha256"] + (variant == "target_registration_assertion" ? ["native_token_sha256"] : []) { try require(matches(o[k]?.string, hex)) }
        for k in ["bootstrap_deadline_unix_ms", "original_grant_expires_at_unix_ms"] { try require(o[k]?.integer.map { (1...9_007_199_254_740_991).contains($0) } ?? false) }
        try nonce(o["nonce_b64url"]?.string)
        guard let key = o["apple_key_id_b64"]?.string else { throw Invalid.data }
        _ = try base64(key, count: 32...32)
        guard let origin = o["selected_ha_origin"]?.string else { throw Invalid.data }
        try require((1...2048).contains(origin.unicodeScalars.count))
        try require(o["expected_target_generation"] == .null || matches(o["expected_target_generation"]?.string, uuid))
        let activity = o["token_role"] == .string("live_activity_update")
        try require([Value.string("ios"), .string("macos")].contains(o["client_type"]) && [Value.string("widget"), .string("live_activity_update")].contains(o["token_role"]) && !(activity && o["client_type"] == .string("macos")))
        if activity {
            guard let p = o["prospective_activity_identity"]?.object else { throw Invalid.data }
            try require(Set(p.keys) == ["presentation_id", "presentation_generation"] && p.values.allSatisfy { matches($0.string, uuid) } && o["profile_identity_sha256"] == .string(profile))
        } else { try require(o["profile_identity_sha256"] == .null && o["prospective_activity_identity"] == .null) }
        if variant == "target_registration_assertion" {
            guard let t = o["native_target"]?.object else { throw Invalid.data }
            let tkeys: Set<String> = activity ? ["kind", "app_bundle_id", "native_activity_id", "native_attributes_type", "presentation_id", "presentation_generation", "profile_id", "profile_identity_sha256"] : ["kind", "app_bundle_id", "extension_bundle_id", "widget_kind"]
            try require(Set(t.keys) == tkeys && t["kind"] == o["token_role"])
            for k in activity ? ["app_bundle_id", "native_activity_id"] : ["app_bundle_id", "extension_bundle_id", "widget_kind"] { try require(t[k]?.string.map { (1...200).contains($0.unicodeScalars.count) } ?? false) }
            if activity {
                let p = o["prospective_activity_identity"]!.object!
                try require(t["native_attributes_type"] == .string("DJConnectRemotePlaybackStatusActivityAttributesV1") && t["profile_id"] == .string("remote-playback-status-v1") && t["profile_identity_sha256"] == .string(profile) && t["presentation_id"] == p["presentation_id"] && t["presentation_generation"] == p["presentation_generation"])
            }
        }
    }
    static func decode(_ bytes: Data, expected e: Expected, boundJob: String? = nil, boundOpaque: [String: Value]? = nil) throws -> Parsed {
        let o = try object(bytes, max: 8192), target = e.variant == "target_registration_assertion"
        let op = target ? "target_operation_id" : "key_operation_id", handle = target ? "target_verification_handle" : "key_verification_handle"
        let keys: Set<String> = ["contract_version", "request_id", "bootstrap_id", "outcome", op, "proof_job_id", "proof_variant", "domain_prefix_utf8", "canonical_transcript_b64", "client_data_hash_sha256", "prepared_transcript_sha256", handle, "bootstrap_deadline_unix_ms", "original_grant_expires_at_unix_ms"]
        try require(Set(o.keys) == keys && Set(e.known.keys) == knownKeys && matches(e.requestID, uuid) && o["request_id"] == .string(e.requestID) && o["contract_version"] == .integer(1) && o["proof_variant"] == .string(e.variant) && o["outcome"] == .string(target ? "target_proof_prepared" : "key_proof_prepared"))
        guard let domain = domains[e.variant], o["domain_prefix_utf8"] == .string(domain), let b64 = o["canonical_transcript_b64"]?.string else { throw Invalid.data }
        let original = try base64(b64, count: 1...4096), t = try object(original, max: 4096)
        try require(Data(Value.object(t).canonical.utf8) == original) // Compare only; never replace signing bytes.
        try transcript(t, variant: e.variant)
        for (k, v) in e.known { try require(t[k] == v) }
        try require(o["bootstrap_id"] == t["bootstrap_id"] && o[op] == t["operation_id"] && o["proof_job_id"] == t["proof_job_id"] && o["bootstrap_deadline_unix_ms"] == t["bootstrap_deadline_unix_ms"] && o["original_grant_expires_at_unix_ms"] == t["original_grant_expires_at_unix_ms"])
        if target { try require(e.nativeTarget != nil && e.nativeTokenHash != nil && matches(e.verifiedKeyRef, uuid) && t["verified_key_ref"] == e.verifiedKeyRef.map(Value.string) && t["native_target"] == e.nativeTarget && t["native_token_sha256"] == e.nativeTokenHash.map(Value.string)) }
        else { try require(e.nativeTarget == nil && e.nativeTokenHash == nil && (e.verifiedKeyRef == nil || t["verified_key_ref"] == e.verifiedKeyRef.map(Value.string))) }
        let preimage = Data(domain.utf8) + original
        try require(o["prepared_transcript_sha256"] == .string(hash(original)) && o["client_data_hash_sha256"] == .string(hash(preimage)))
        try nonce(o[handle]?.string)
        let opaque = t.filter { ["proof_port_audience", "owner_approval_binding_sha256", "paired_subject_binding_sha256", "identity_policy_sha256", "deployment_policy_sha256"].contains($0.key) }
        let job = t["proof_job_id"]!.string!
        try require(boundJob.map { $0 == job } ?? true)
        try require(boundOpaque.map { $0 == opaque } ?? true)
        return Parsed(originalBytes: original, clientDataHash: Data(SHA256.hash(data: preimage)), job: job, opaqueBindings: opaque, handle: o[handle]!.string!, preparedKeyRef: t["verified_key_ref"]?.string)
    }

    // Logical lifecycle model ONLY. Integer ticks are synthetic controls, not a
    // qualified native/Core/API clock or authority. No callback can cause effects.
    final class ModelFlow {
        private let originalScope: String
        private let originalDeadline: Int64
        private let originalKey: Expected
        private let originalTarget: Expected
        private(set) var retired = false
        private(set) var job: String?
        private var opaque: [String: Value]?
        private var keyConsumed = false
        private var targetConsumed = false
        private var preparedKeyRef: String?
        private var verifiedKeyRef: String?
        private var lastTick: Int64 = 0
        init(scope: String, originalDeadline: Int64, originalKey: Expected, originalTarget: Expected) {
            originalScope = scope; self.originalDeadline = originalDeadline
            self.originalKey = originalKey; self.originalTarget = originalTarget
        }
        func observeScope(_ s: String) { if !s.utf8.elementsEqual(originalScope.utf8) { retired = true } }
        func loseReply() { retired = true }
        func observeSyntheticKeyVerification(ref: String, tick: Int64) throws {
            do {
                try require(!retired && keyConsumed && verifiedKeyRef == nil && tick >= lastTick && tick < originalDeadline && matches(ref, uuid) && (preparedKeyRef == nil || preparedKeyRef == ref))
                lastTick = tick; verifiedKeyRef = ref
            } catch { retired = true; throw error }
        }
        func consume(_ bytes: Data, expected: Expected, tick: Int64) throws -> Parsed {
            do {
                let target = expected.variant == "target_registration_assertion"
                try require(expected == (target ? originalTarget : originalKey))
                try require(!retired && tick >= lastTick && tick < originalDeadline && (target ? verifiedKeyRef != nil && verifiedKeyRef == expected.verifiedKeyRef && !targetConsumed : !keyConsumed))
                let p = try decode(bytes, expected: expected, boundJob: job, boundOpaque: opaque)
                job = p.job; opaque = p.opaqueBindings; lastTick = tick
                if target { targetConsumed = true } else { keyConsumed = true; preparedKeyRef = p.preparedKeyRef }
                return p
            } catch { retired = true; throw error }
        }
    }
}
