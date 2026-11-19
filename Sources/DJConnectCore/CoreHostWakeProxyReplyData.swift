import Foundation

/// Correlated route-specific DATA. No state here can authorize SDK publication,
/// generate a key, qualify a clock or restore a lost original RAM owner.
struct CoreHostWakeProxyReplyData: Sendable {
    let operation: CoreHostWakeProxyRequest.Operation
    let fields: [String: DirectRichWireJSON]
    let original: DirectRichWireJSON?
    let transcript: HostWakeNativeTranscriptData?
    var state: String { fields["state"]!.string! }
    var proofKind: String? { fields["native_proof_kind"]?.string }
    private init(operation: CoreHostWakeProxyRequest.Operation, fields: [String: DirectRichWireJSON], original: DirectRichWireJSON?, transcript: HostWakeNativeTranscriptData?) {
        self.operation = operation; self.fields = fields; self.original = original; self.transcript = transcript
    }
    static func decode(_ bytes: Data, status: Int, request: CoreHostWakeProxyRequest, prepared: Self? = nil) throws -> Self {
        let node = try CoreHostWakeProxyDataJSON.parse(bytes)
        if status != 200 { throw try CoreHostWakeProxyServerError.decode(node, status: status) }
        let common: Set<String> = ["success", "contract_version", "profile_id", "operation_id", "request_sha256", "purpose_id", "surface", "generation", "revision", "state", "original_wake_issued_at_ms", "original_wake_expires_at_ms", "original_display_expires_at_ms"]
        let extra: Set<String> = request.operation == .prepare ? ["original", "native_proof_kind"] : request.operation == .nativeChallenge ? ["original", "native_proof_kind", "challenge", "canonical_transcript_utf8", "client_data_sha256"] : []
        guard let f = node.object, Set(f.keys) == common.union(extra), f["success"] == .bool(true), f["contract_version"] == .integer(1),
              f["profile_id"] == .string("djconnect-direct-rich-host-wake-v1"), f["request_sha256"] == .string(request.sha256),
              ["operation_id", "purpose_id", "surface"].allSatisfy({ f[$0] == request.fields[$0] }),
              DirectRichRequest.matches(f["generation"]?.string, "[A-Za-z0-9_-]{1,128}"),
              let revision = f["revision"]?.integer, (1...256).contains(revision),
              let issued = f["original_wake_issued_at_ms"]?.integer, issued >= 0,
              let expiry = f["original_wake_expires_at_ms"]?.integer, expiry > issued, expiry - issued <= 28800000,
              let display = f["original_display_expires_at_ms"]?.integer, display >= expiry,
              let state = f["state"]?.string else { throw DJConnectError.invalidResponse }
        let states: [String]
        switch request.operation {
        case .prepare: states = ["prepared"]
        case .nativeChallenge: states = ["pending"]
        case .nativeComplete, .nativeStatus: states = ["pending", "native_verified", "withdrawn", "expired", "unknown"]
        case .register, .status: states = ["pending", "registered", "withdrawn", "expired", "unknown"]
        case .withdraw: states = ["pending", "withdrawn", "expired", "unknown"]
        }
        guard states.contains(state) else { throw DJConnectError.invalidResponse }
        if let prepared {
            guard prepared.operation == .prepare else { throw DJConnectError.invalidResponse }
            for key in ["operation_id", "purpose_id", "surface", "generation", "revision", "original_wake_issued_at_ms", "original_wake_expires_at_ms", "original_display_expires_at_ms"] {
                guard f[key] == prepared.fields[key] else { throw DJConnectError.invalidResponse }
            }
        }
        var original: DirectRichWireJSON?, transcript: HostWakeNativeTranscriptData?
        if !extra.isEmpty {
            guard let value = f["original"], ["app_attest_attestation", "app_attest_assertion"].contains(f["native_proof_kind"]?.string ?? "") else { throw DJConnectError.invalidResponse }
            let v = try HostWakeNativeTranscriptData.validateOriginalData(value)
            for key in ["operation_id", "generation", "revision", "original_wake_issued_at_ms", "original_wake_expires_at_ms", "original_display_expires_at_ms"] {
                guard v[key] == f[key] else { throw DJConnectError.invalidResponse }
            }
            guard v["core_purpose_id"] == f["purpose_id"] else { throw DJConnectError.invalidResponse }
            if request.operation == .prepare {
                for key in ["target", "platform", "apns_environment", "native_key_id_b64", "native_token_sha256"] {
                    guard v[key] == request.fields[key] else { throw DJConnectError.invalidResponse }
                }
            } else {
                guard let prepared, value == prepared.original, f["native_proof_kind"] == prepared.fields["native_proof_kind"],
                      let canonical = f["canonical_transcript_utf8"]?.string, let hash = f["client_data_sha256"]?.string else { throw DJConnectError.invalidResponse }
                let parsed = try HostWakeNativeTranscriptData(canonicalTranscript: Data(canonical.utf8))
                guard parsed.original == value, parsed.challenge == f["challenge"],
                      parsed.clientDataHash.map({ String(format: "%02x", $0) }).joined() == hash else { throw DJConnectError.invalidResponse }
                transcript = parsed
            }
            original = value
        }
        return Self(operation: request.operation, fields: f, original: original, transcript: transcript)
    }
}

enum CoreHostWakeProxyServerError: String, Error, CaseIterable, Sendable {
    case invalidRequest = "invalid_request", unauthorized
    case notAllowed = "rich_push_not_allowed", historyUnknown = "rich_push_history_unknown"
    case consumed = "rich_push_consumed", capacity = "rich_push_capacity", stageMismatch = "rich_push_stage_mismatch"
    case bodyTooLarge = "rich_push_body_too_large", unavailable = "rich_push_unavailable", pending = "rich_push_pending"
    var status: Int {
        switch self {
        case .invalidRequest: 400
        case .unauthorized: 401
        case .notAllowed: 403
        case .historyUnknown: 404
        case .consumed, .capacity, .stageMismatch: 409
        case .bodyTooLarge: 413
        case .unavailable, .pending: 503
        }
    }
    static func decode(_ node: DirectRichWireJSON, status: Int) throws -> Self {
        guard let f = node.object, Set(f.keys) == ["success", "contract_version", "error"], f["success"] == .bool(false),
              f["contract_version"] == .integer(1), let code = f["error"]?.string, let error = Self(rawValue: code), error.status == status else { throw DJConnectError.invalidResponse }
        return error // A push denial is never an instruction to unpair the parent.
    }
}

/// New route preflight: preserve the old Core parser, add lexical -0 rejection
/// outside strings. HTTP envelopes need not reuse signing-transcript whitespace.
enum CoreHostWakeProxyDataJSON {
    static func parse(_ bytes: Data) throws -> DirectRichWireJSON {
        let node = try DirectRichWireJSON.parse(bytes, maximumBytes: 16384)
        var string = false, escaped = false
        let values = Array(bytes)
        for i in values.indices {
            let byte = values[i]
            if string {
                if escaped { escaped = false }
                else if byte == 92 { escaped = true }
                else if byte == 34 { string = false }
            } else if byte == 34 { string = true }
            else if byte == 45, i + 1 < values.count, values[i + 1] == 48 { throw DJConnectError.invalidResponse }
        }
        return node
    }
}
