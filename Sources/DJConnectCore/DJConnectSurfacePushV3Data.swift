import Foundation

/// Closed DATA ONLY projections of Core's paired outer v3 responses. No clock,
/// deadline, owner witness, registration permission or transport is constructed.
/// Matching caller coordinates is comparison, never authenticated provenance.
enum DJConnectSurfacePushV3Data {
    struct Context: Equatable, Sendable {
        let contextHandle: String
        let operationID: String
        let purposeReference: String
        let purposeExpiryMS: Int64
        let contextExpiryMS: Int64
        let purposeRemainingAtOriginalStartMS: Int64
        let contextRemainingAtOriginalStartMS: Int64

        fileprivate init(_ wire: ContextWire) {
            contextHandle = wire.context_handle; operationID = wire.operation_id
            purposeReference = wire.purpose_ref; purposeExpiryMS = wire.expires_at_ms
            contextExpiryMS = wire.context_expires_at_ms
            purposeRemainingAtOriginalStartMS = wire.purpose_remaining_at_original_start_ms
            contextRemainingAtOriginalStartMS = wire.context_remaining_at_original_start_ms
        }
    }

    enum Registration: Equatable, Sendable {
        case confirmed(Confirmed)
        case unconfirmed(Unconfirmed)
    }
    struct Confirmed: Equatable, Sendable {
        let replayed: Bool
        let operation: Operation
        let receipt: Receipt
        let background: Background
        fileprivate init(_ wire: RegistrationWire, receipt: Receipt, background: Background) {
            replayed = wire.replayed; operation = wire.operation
            self.receipt = receipt; self.background = background
        }
    }
    struct Unconfirmed: Equatable, Sendable {
        let replayed: Bool
        let operation: Operation
        let receipt: Receipt?
        fileprivate init(_ wire: RegistrationWire) {
            replayed = wire.replayed; operation = wire.operation; receipt = wire.registration
        }
    }

    // These immutable inner data values deliberately do not conform to or
    // construct the existing callable background credential / lifecycle types.
    struct Operation: Decodable, Equatable, Sendable {
        let contract_version: Int
        let operation_id: String
        let operation_epoch: String
        let phase: String
        let expires_at_ms: Int64
        let result_available: Bool
        let response_status: Int?
        let error: String?
        fileprivate static let keys: Set<String> = ["contract_version", "operation_id", "operation_epoch", "phase", "expires_at_ms", "result_available", "response_status", "error"]
    }
    struct Receipt: Decodable, Equatable, Sendable {
        let registration_id: String
        let generation: String
        let revision: Int64
        let state: String
        let expires_at_ms: Int64
        let token_role: String
        let platform: String
        let last_error: String?
        let cache_policy: String
        fileprivate static let keys: Set<String> = ["registration_id", "generation", "revision", "state", "expires_at_ms", "token_role", "platform", "last_error", "cache_policy"]
    }
    struct Background: Decodable, Equatable, Sendable {
        let credential: String
        let expires_at_ms: Int64
        let registration_id: String
        let scope: String
        let cache_policy: String
        fileprivate static let keys: Set<String> = ["credential", "expires_at_ms", "registration_id", "scope", "cache_policy"]
    }

    static func decodeContext(_ data: Data, matchingOperation operation: String) throws -> Context {
        let body = try object(data)
        guard Set(body.keys) == ContextWire.keys else { throw DJConnectError.invalidResponse }
        let wire = try JSONDecoder().decode(ContextWire.self, from: data)
        guard wire.success, wire.available, wire.contract_version == 3,
              validOperation(operation), wire.operation_id == operation,
              opaque(wire.context_handle, prefix: "djcctx_"), opaque(wire.purpose_ref, prefix: "djcpref_"),
              safePositive(wire.expires_at_ms), safePositive(wire.context_expires_at_ms),
              wire.context_expires_at_ms <= wire.expires_at_ms,
              (1...28_800_000).contains(wire.purpose_remaining_at_original_start_ms),
              (1...30_000).contains(wire.context_remaining_at_original_start_ms),
              wire.context_remaining_at_original_start_ms <= wire.purpose_remaining_at_original_start_ms,
              wire.cache_policy == "private,no-store" else { throw DJConnectError.invalidResponse }
        return Context(wire)
    }

    static func decodeRegistration(_ data: Data, matchingContext context: Context) throws -> Registration {
        let body = try object(data)
        let wire = try JSONDecoder().decode(RegistrationWire.self, from: data)
        guard Set(body.keys) == (wire.success ? RegistrationWire.keys.union(["background_read"]) : RegistrationWire.keys),
              wire.contract_version == 3, wire.context_handle == context.contextHandle,
              wire.operation_id == context.operationID, wire.purpose_ref == context.purposeReference,
              exactObject(body["operation"], keys: Operation.keys), valid(wire.operation, operation: context.operationID)
        else { throw DJConnectError.invalidResponse }
        if let receipt = wire.registration {
            guard exactObject(body["registration"], keys: Receipt.keys), valid(receipt) else { throw DJConnectError.invalidResponse }
        } else {
            guard body["registration"] is NSNull else { throw DJConnectError.invalidResponse }
        }
        if !wire.success {
            // The original operation may be confirmed while its retained row
            // is now absent/changed/withdrawn. Keep failure as failure data.
            return .unconfirmed(Unconfirmed(wire))
        }
        guard let receipt = wire.registration, let background = wire.background_read,
              exactObject(body["background_read"], keys: Background.keys),
              wire.operation.phase == "confirmed", wire.operation.response_status == 200, wire.operation.error == nil,
              receipt.state == "registered", receipt.last_error == nil,
              receipt.expires_at_ms == context.purposeExpiryMS,
              background.credential.range(of: "^djcsurface_[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil,
              background.registration_id == receipt.registration_id,
              background.expires_at_ms == receipt.expires_at_ms,
              background.scope == "exact_original_surface_read_only", background.cache_policy == "private,no-store"
        else { throw DJConnectError.invalidResponse }
        return .confirmed(Confirmed(wire, receipt: receipt, background: background))
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        try DJConnectSurfacePushJSON.validate(data)
        guard let body = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw DJConnectError.invalidResponse }
        return body
    }
    private static func exactObject(_ value: Any?, keys: Set<String>) -> Bool {
        guard let object = value as? [String: Any] else { return false }
        return Set(object.keys) == keys
    }
    private static func safePositive(_ n: Int64) -> Bool { (1...9_007_199_254_740_991).contains(n) }
    private static func identifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128 && value.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil
    }
    private static func optionalIdentifier(_ value: String?) -> Bool { value.map(identifier) ?? true }
    private static func validOperation(_ value: String) -> Bool {
        value.range(of: "^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", options: .regularExpression) != nil
    }
    private static func opaque(_ value: String, prefix: String) -> Bool {
        value.hasPrefix(prefix) && DJConnectRendezvousQR.canonicalToken(String(value.dropFirst(prefix.count)))
    }
    private static func valid(_ operation: Operation, operation expected: String) -> Bool {
        operation.contract_version == 1 && operation.operation_id == expected && identifier(operation.operation_epoch) &&
        ["accepted", "sent_unknown", "confirmed", "rejected", "cancelled", "unknown"].contains(operation.phase) &&
        safePositive(operation.expires_at_ms) && !operation.result_available &&
        (operation.response_status.map({ (100...599).contains($0) }) ?? true) && optionalIdentifier(operation.error)
    }
    private static func valid(_ receipt: Receipt) -> Bool {
        identifier(receipt.registration_id) && identifier(receipt.generation) &&
        (1..<9_007_199_254_740_991).contains(receipt.revision) && identifier(receipt.state) && safePositive(receipt.expires_at_ms) &&
        receipt.token_role == "widget" && ["ios", "ipados", "macos"].contains(receipt.platform) &&
        optionalIdentifier(receipt.last_error) && receipt.cache_policy == "private,no-store"
    }

    fileprivate struct ContextWire: Decodable {
        let success: Bool; let contract_version: Int; let available: Bool
        let context_handle: String; let operation_id: String; let purpose_ref: String
        let expires_at_ms: Int64; let context_expires_at_ms: Int64
        let purpose_remaining_at_original_start_ms: Int64; let context_remaining_at_original_start_ms: Int64
        let cache_policy: String
        static let keys: Set<String> = ["success", "contract_version", "available", "context_handle", "operation_id", "purpose_ref", "expires_at_ms", "context_expires_at_ms", "purpose_remaining_at_original_start_ms", "context_remaining_at_original_start_ms", "cache_policy"]
    }
    fileprivate struct RegistrationWire: Decodable {
        let contract_version: Int; let context_handle: String; let operation_id: String; let purpose_ref: String
        let success: Bool; let replayed: Bool
        let operation: Operation; let registration: Receipt?; let background_read: Background?
        static let keys: Set<String> = ["contract_version", "context_handle", "operation_id", "purpose_ref", "success", "replayed", "operation", "registration"]
    }
}
