import Foundation

/// Closed Core-proxy request DATA. Parsing or correlation is never an original
/// purpose, native enrollment, clock qualification or dispatch permission.
struct CoreHostWakeProxyRequest: Sendable {
    enum Operation: String, CaseIterable, Sendable {
        case prepare, nativeChallenge = "native/challenge", nativeComplete = "native/complete"
        case nativeStatus = "native/status", register, status, withdraw
        var path: String { "/api/djconnect/v1/session/rich/push/" + rawValue }
    }
    let operation: Operation
    let fields: [String: DirectRichWireJSON]
    let body: Data
    let correlationPreimage: Data
    let sha256: String

    init(operation: Operation, originalBody: Data) throws {
        let node = try CoreHostWakeProxyDataJSON.parse(originalBody)
        let identity: Set<String> = ["contract_version", "device_id", "client_type", "session_id", "surface", "purpose_id", "operation_id"]
        let additional: Set<String>
        switch operation {
        case .prepare: additional = ["target", "platform", "apns_environment", "native_key_id_b64", "native_token_sha256"]
        case .nativeComplete: additional = ["challenge_id", "native_proof"]
        case .nativeStatus: additional = ["challenge_id"]
        case .register: additional = ["challenge_id", "native_token_b64"]
        default: additional = []
        }
        guard let f = node.object, Set(f.keys) == identity.union(additional),
              f["contract_version"] == .integer(1), f["client_type"] == .string("ios"),
              DirectRichRequest.matches(f["device_id"]?.string, "djconnect-ios-[A-Za-z0-9]{12}"),
              DirectRichRequest.matches(f["session_id"]?.string, "[A-Za-z0-9_-]{1,128}"),
              ["widget", "live_activity"].contains(f["surface"]?.string ?? ""),
              DirectRichRequest.isUUID(f["purpose_id"]?.string), DirectRichRequest.isUUID(f["operation_id"]?.string) else { throw DJConnectError.invalidResponse }
        if additional.contains("challenge_id"), !DirectRichRequest.isUUID(f["challenge_id"]?.string) { throw DJConnectError.invalidResponse }
        switch operation {
        case .prepare:
            guard let t = f["target"]?.object, Set(t.keys) == ["host_bundle_id", "installation_id"],
                  let host = t["host_bundle_id"]?.string, host.utf8.count <= 200,
                  DirectRichRequest.matches(host, "[A-Za-z0-9-]+(?:\\.[A-Za-z0-9-]+)+"),
                  DirectRichRequest.matches(t["installation_id"]?.string, "[A-Za-z0-9_-]{1,128}"),
                  ["ios", "ipados"].contains(f["platform"]?.string ?? ""),
                  ["sandbox", "production"].contains(f["apns_environment"]?.string ?? ""),
                  DirectRichRequest.matches(f["native_token_sha256"]?.string, "[a-f0-9]{64}") else { throw DJConnectError.invalidResponse }
            _ = try Self.base64(f["native_key_id_b64"], decoded: 1...1024)
        case .nativeComplete:
            guard let proof = f["native_proof"]?.object, Set(proof.keys) == ["kind", "bytes_b64"],
                  ["app_attest_attestation", "app_attest_assertion"].contains(proof["kind"]?.string ?? "") else { throw DJConnectError.invalidResponse }
            _ = try Self.base64(proof["bytes_b64"], decoded: 1...9216)
        case .register: _ = try Self.base64(f["native_token_b64"], decoded: 16...2048)
        default: break
        }
        let preimage = DirectRichWireJSON.array([.string("DJC-HOST-WAKE-CORE-REQUEST-V1"), .string("POST"), .string(operation.path), node])
        self.operation = operation; fields = f; body = try node.canonicalData()
        guard body.count <= 16384 else { throw DJConnectError.invalidResponse }
        correlationPreimage = try preimage.canonicalData(); sha256 = try preimage.digest()
    }

    /// Canonical DATA decoding, not actual SDK key/proof enrollment validation.
    private static func base64(_ value: DirectRichWireJSON?, decoded bounds: ClosedRange<Int>) throws -> Data {
        guard let string = value?.string, string.utf8.count <= ((bounds.upperBound + 2) / 3) * 4,
              let bytes = Data(base64Encoded: string), bounds.contains(bytes.count), bytes.base64EncodedString() == string else { throw DJConnectError.invalidResponse }
        return bytes
    }
}
