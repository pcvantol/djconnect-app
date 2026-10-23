import Foundation
import CryptoKit

/// An original RAM pin, established by the paired Core v2 context response.
/// It is neither a persisted credential nor permission to create a surface.
public struct DJConnectSurfacePushPurposePin: Sendable, Equatable {
    public let purposeReference: String
    public let originalExpiryMS: Int64
    public let originalMonotonicDeadline: ContinuousClock.Instant
    let installation: String
    let ownerEpoch: UUID
    let session: String
    let deviceID: String
    let clientType: String
    let targetInstance: String
    let platform: String
    fileprivate init(reference: String, expiry: Int64, deadline: ContinuousClock.Instant,
                     installation: String, ownerEpoch: UUID, session: String, deviceID: String, clientType: String, targetInstance: String, platform: String) {
        purposeReference = reference; originalExpiryMS = expiry
        originalMonotonicDeadline = deadline; self.installation = installation
        self.ownerEpoch = ownerEpoch; self.session = session
        self.deviceID = deviceID; self.clientType = clientType; self.targetInstance = targetInstance; self.platform = platform
    }
}

/// Immutable pre-context capture. In particular, context and register share the
/// original operation UUID, native token, target and owner epoch.
public struct DJConnectSurfacePushContextAttempt: Sendable {
    let original: DJConnectSurfacePushRequest
    let operationID: String
    let installation: String
    let ownerEpoch: UUID
    let startedMS: Int64
    let startedMono: ContinuousClock.Instant
    let previousPurpose: DJConnectSurfacePushPurposePin?
    let contextBytes: Data
    let platform: String
    let tokenDigest: Data

    public init?(original: DJConnectSurfacePushRequest, installation: String, ownerEpoch: UUID,
                 previousPurpose: DJConnectSurfacePushPurposePin? = nil) {
        // Sample monotonic first so preemption between clock samples can only
        // shorten the original budget.
        let startedMono = ContinuousClock.now
        let startedMS = Int64(Date().timeIntervalSince1970 * 1000)
        self.init(original: original, installation: installation, ownerEpoch: ownerEpoch,
                  previousPurpose: previousPurpose, nowMS: startedMS, monotonicNow: startedMono)
    }
    init?(original: DJConnectSurfacePushRequest, installation: String, ownerEpoch: UUID,
          previousPurpose: DJConnectSurfacePushPurposePin?, nowMS: Int64,
          monotonicNow: ContinuousClock.Instant) {
        guard original.tokenRole == "widget", !installation.isEmpty, installation.utf8.count <= 2048,
              nowMS >= 0, let body = try? JSONSerialization.jsonObject(with: original.bytes) as? [String: Any],
              let operation = body["operation_id"] as? String,
              let platform = body["platform"] as? String,
              let encodedToken = body["apns_token"] as? String else { return nil }
        let hex = Array(encodedToken.utf8)
        guard !hex.isEmpty, hex.count.isMultiple(of: 2) else { return nil }
        var token = Data()
        for index in stride(from: 0, to: hex.count, by: 2) {
            guard let byte = UInt8(String(decoding: hex[index..<index+2], as: UTF8.self), radix: 16) else { return nil }
            token.append(byte)
        }
        if let previousPurpose {
            guard previousPurpose.installation == installation, previousPurpose.ownerEpoch == ownerEpoch,
                  previousPurpose.session == original.sessionID,
                  previousPurpose.deviceID == original.deviceID,
                  previousPurpose.clientType == original.clientType,
                  previousPurpose.targetInstance == original.instanceID,
                  previousPurpose.platform == platform,
                  nowMS < previousPurpose.originalExpiryMS,
                  monotonicNow < previousPurpose.originalMonotonicDeadline else { return nil }
        }
        let context: [String: Any] = ["contract_version": 2, "device_id": original.deviceID,
            "client_type": original.clientType, "session_id": original.sessionID, "operation_id": operation]
        guard let bytes = try? JSONSerialization.data(withJSONObject: context, options: [.sortedKeys]) else { return nil }
        self.original = original; operationID = operation; self.installation = installation
        self.ownerEpoch = ownerEpoch; startedMS = nowMS; startedMono = monotonicNow
        self.previousPurpose = previousPurpose; contextBytes = bytes
        self.platform = platform; tokenDigest = Data(SHA256.hash(data: token))
    }

    func canRequest(nowMS: Int64, monotonicNow: ContinuousClock.Instant) -> Bool {
        guard nowMS >= startedMS, nowMS - startedMS < 30_000,
              monotonicNow >= startedMono, monotonicNow < startedMono.advanced(by: .seconds(30)) else { return false }
        return previousPurpose.map { nowMS < $0.originalExpiryMS && monotonicNow < $0.originalMonotonicDeadline } ?? true
    }

    /// Only the original paired-response continuation may create these values.
    /// A later context for the same purpose retains the first monotonic deadline.
    func admit(_ data: Data, nowMS: Int64, monotonicNow: ContinuousClock.Instant) throws -> DJConnectSurfacePushContinuation {
        try DJConnectSurfacePushJSON.validate(data)
        let keys: Set<String> = ["success", "contract_version", "available", "context_handle", "operation_id",
                                 "purpose_ref", "expires_at_ms", "context_expires_at_ms", "cache_policy"]
        guard let body = try JSONSerialization.jsonObject(with: data) as? [String: Any], Set(body.keys) == keys,
              let response = try? JSONDecoder().decode(ContextResponse.self, from: data),
              response.success, response.available, response.contract_version == 2,
              response.operation_id == operationID, response.cache_policy == "private,no-store",
              Self.opaque(response.context_handle, prefix: "djcctx_"),
              Self.opaque(response.purpose_ref, prefix: "djcpref_"),
              response.expires_at_ms <= 9_007_199_254_740_991,
              response.context_expires_at_ms <= response.expires_at_ms,
              response.context_expires_at_ms > startedMS, response.context_expires_at_ms > nowMS,
              response.expires_at_ms > nowMS, nowMS >= startedMS, monotonicNow >= startedMono else {
            throw DJConnectError.invalidResponse
        }
        // Bound the arithmetic. Core's original registration grant is eight
        // hours; a full day also leaves room for the original operation skew.
        let grantRemaining = response.expires_at_ms - startedMS
        guard grantRemaining > 0, grantRemaining <= 86_400_000 else { throw DJConnectError.invalidResponse }
        // A client operation may be shorter than the server window, never
        // longer: latency and wall rollback cannot renew the original budget.
        let contextDeadline = startedMono.advanced(by: .milliseconds(min(30_000, response.context_expires_at_ms - startedMS)))
        guard monotonicNow < contextDeadline else { throw DJConnectError.invalidResponse }
        let purpose: DJConnectSurfacePushPurposePin
        if let previousPurpose {
            guard previousPurpose.purposeReference == response.purpose_ref,
                  previousPurpose.originalExpiryMS == response.expires_at_ms,
                  nowMS < previousPurpose.originalExpiryMS,
                  monotonicNow < previousPurpose.originalMonotonicDeadline else { throw DJConnectError.invalidResponse }
            purpose = previousPurpose // Never reanchor on rotation or wall rollback.
        } else {
            purpose = .init(reference: response.purpose_ref, expiry: response.expires_at_ms,
                deadline: startedMono.advanced(by: .milliseconds(grantRemaining)),
                installation: installation, ownerEpoch: ownerEpoch, session: original.sessionID,
                deviceID: original.deviceID, clientType: original.clientType, targetInstance: original.instanceID, platform: platform)
        }
        guard monotonicNow < purpose.originalMonotonicDeadline else { throw DJConnectError.invalidResponse }
        guard var register = try JSONSerialization.jsonObject(with: original.bytes) as? [String: Any] else { throw DJConnectError.invalidResponse }
        register["contract_version"] = 2; register["context_handle"] = response.context_handle
        let bytes = try JSONSerialization.data(withJSONObject: register, options: [.sortedKeys])
        return .init(attempt: self, contextHandle: response.context_handle,
                     contextExpiryMS: response.context_expires_at_ms, contextDeadline: contextDeadline,
                     purpose: purpose, registerBytes: bytes)
    }
    private static func opaque(_ value: String, prefix: String) -> Bool {
        value.hasPrefix(prefix) && DJConnectRendezvousQR.canonicalToken(String(value.dropFirst(prefix.count)))
    }
    private struct ContextResponse: Decodable {
        let success: Bool; let contract_version: Int; let available: Bool
        let context_handle: String; let operation_id: String; let purpose_ref: String
        let expires_at_ms: Int64; let context_expires_at_ms: Int64; let cache_policy: String
    }
}

/// Context handle and read credential remain distinct. This RAM value is not a
/// shipping registration factory, extension escrow or API issuer admission.
public struct DJConnectSurfacePushContinuation: Sendable {
    public let purpose: DJConnectSurfacePushPurposePin
    let attempt: DJConnectSurfacePushContextAttempt
    let contextHandle: String
    let contextExpiryMS: Int64
    let contextDeadline: ContinuousClock.Instant
    let registerBytes: Data
    fileprivate init(attempt: DJConnectSurfacePushContextAttempt, contextHandle: String,
                     contextExpiryMS: Int64, contextDeadline: ContinuousClock.Instant,
                     purpose: DJConnectSurfacePushPurposePin, registerBytes: Data) {
        self.attempt = attempt; self.contextHandle = contextHandle
        self.contextExpiryMS = contextExpiryMS; self.contextDeadline = contextDeadline
        self.purpose = purpose; self.registerBytes = registerBytes
    }
    func canSubmit(nowMS: Int64, monotonicNow: ContinuousClock.Instant) -> Bool {
        nowMS >= attempt.startedMS && nowMS < contextExpiryMS && nowMS < purpose.originalExpiryMS &&
        monotonicNow >= attempt.startedMono && monotonicNow < contextDeadline &&
        monotonicNow < purpose.originalMonotonicDeadline
    }
    /// The original caller supplies its existing runtime owner; no witness is
    /// reconstructed from a status receipt, cache, or a background read.
    public var witness: DJConnectSurfacePushWitness {
        return .init(installation: attempt.installation, ownerEpoch: attempt.ownerEpoch,
            session: attempt.original.sessionID, purposeGeneration: purpose.purposeReference,
            targetInstance: attempt.original.instanceID, platform: attempt.platform,
            tokenRole: "widget", tokenDigest: attempt.tokenDigest,
            originalExpiryMS: purpose.originalExpiryMS, originalMonotonicDeadline: purpose.originalMonotonicDeadline)
    }
    func admitRegistration(_ data: Data) throws -> DJConnectSurfacePushResponse {
        try DJConnectSurfacePushJSON.validate(data)
        guard let body = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = try? JSONDecoder().decode(RegistrationResponse.self, from: data),
              response.contract_version == 2, response.context_handle == contextHandle,
              response.operation_id == attempt.operationID, response.purpose_ref == purpose.purposeReference else {
            throw DJConnectError.invalidResponse
        }
        let common: Set<String> = ["contract_version", "context_handle", "operation_id", "purpose_ref",
                                   "success", "replayed", "operation", "registration"]
        guard Set(body.keys) == (response.success ? common.union(["background_read"]) : common),
              let result = try? JSONDecoder().decode(DJConnectSurfacePushResponse.self, from: data),
              !response.success || (result.registration?.expires_at_ms == purpose.originalExpiryMS &&
                  result.registration.map({ result.background_read?.matches($0) == true }) == true)
        else { throw DJConnectError.invalidResponse }
        return result // Existing registration lifecycle still checks coordinates/ACK phase.
    }
    private struct RegistrationResponse: Decodable {
        let contract_version: Int; let context_handle: String; let operation_id: String
        let purpose_ref: String; let success: Bool
    }
}
