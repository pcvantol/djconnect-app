import Foundation

/// Structural receipt only. This type is not Codable/persistable and cannot
/// grant publication. The actual authenticated channel, original owner/clock
/// capture and native SDK handle are mandatory independent inputs.
enum DirectRichResponse {
    struct Original: Sendable {
        let operationID: String; let purposeID: String; let surface: String; let sessionID: String
        let issuedMS: Int64; let expiresMS: Int64; let generation: String
        let readCredential: String; let assetCredential: String
        fileprivate init(operationID: String, purposeID: String, surface: String, sessionID: String,
                         issuedMS: Int64, expiresMS: Int64, generation: String,
                         readCredential: String, assetCredential: String) {
            self.operationID = operationID; self.purposeID = purposeID; self.surface = surface; self.sessionID = sessionID
            self.issuedMS = issuedMS; self.expiresMS = expiresMS; self.generation = generation
            self.readCredential = readCredential; self.assetCredential = assetCredential
        }
    }
    struct Active: Sendable { let original: Original; let frame: DirectRichFrame }
    struct Management: Sendable {
        let operationID: String; let purposeID: String; let surface: String
        let state: String; let issuedMS: Int64; let expiresMS: Int64
    }

    static func active(_ body: Data, request: DirectRichRequest, original: Original? = nil) throws -> Active {
        let authorize = request.operation == .authorize
        guard authorize || request.operation == .read, authorize == (original == nil) else { throw invalid() }
        let base: Set<String> = ["success", "contract_version", "profile_id", "operation_id", "request_sha256", "purpose_id", "surface", "state", "purpose_issued_at_ms", "purpose_expires_at_ms", "frame"]
        let fields = try DirectRichFrameShape.object(DirectRichWireJSON.parse(body, maximumBytes: 16384),
            authorize ? base.union(["read_credential", "asset_credential"]) : base)
        try common(fields)
        guard fields["state"] == .string("active"), fields["request_sha256"] == .string(request.sha256),
              let purpose = fields["purpose_id"]?.string, DirectRichRequest.isUUID(purpose),
              let operation = fields["operation_id"]?.string, DirectRichRequest.isUUID(operation),
              let surface = fields["surface"]?.string, ["widget", "live_activity"].contains(surface) else { throw invalid() }
        let (issued, expires) = try bounds(fields)
        let session: String
        if authorize {
            guard fields["operation_id"] == request.fields["operation_id"], fields["surface"] == request.fields["surface"],
                  request.fields["enabled"] == .bool(true), request.fields["os_snapshot_cache"] == .bool(true),
                  surface != "live_activity" || request.fields["locked_display"] == .bool(true),
                  let selected = request.fields["session_id"]?.string else { throw invalid() }
            session = selected
        } else {
            guard let original, purpose == original.purposeID, operation == original.operationID,
                  surface == original.surface, issued == original.issuedMS, expires == original.expiresMS,
                  request.fields["purpose_id"] == .string(purpose) else { throw invalid() }
            session = original.sessionID
        }
        let frame = try DirectRichFrameShape.validate(try required(fields["frame"]), purpose: purpose, session: session, purposeExpiry: expires)
        let receipt: Original
        if let original {
            guard frame.generation == original.generation else { throw invalid() }; receipt = original
        } else {
            guard let read = fields["read_credential"]?.string, let asset = fields["asset_credential"]?.string,
                  credential(read, family: "read"), credential(asset, family: "asset") else { throw invalid() }
            receipt = Original(operationID: operation, purposeID: purpose, surface: surface, sessionID: session,
                issuedMS: issued, expiresMS: expires, generation: frame.generation, readCredential: read, assetCredential: asset)
        }
        return Active(original: receipt, frame: frame)
    }

    static func management(_ body: Data, request: DirectRichRequest) throws -> Management {
        guard [.status, .withdraw].contains(request.operation) else { throw invalid() }
        let fields = try DirectRichFrameShape.object(DirectRichWireJSON.parse(body, maximumBytes: 16384),
            ["success", "contract_version", "profile_id", "operation_id", "purpose_id", "surface", "state", "purpose_issued_at_ms", "purpose_expires_at_ms"])
        try common(fields)
        guard fields["operation_id"] == request.fields["operation_id"], fields["surface"] == request.fields["surface"],
              let operation = fields["operation_id"]?.string, let purpose = fields["purpose_id"]?.string,
              DirectRichRequest.isUUID(purpose), let surface = fields["surface"]?.string,
              let state = fields["state"]?.string, ["active", "withdrawn", "expired", "unknown"].contains(state),
              request.operation != .withdraw || state == "withdrawn" else { throw invalid() }
        let (issued, expires) = try bounds(fields)
        return Management(operationID: operation, purposeID: purpose, surface: surface, state: state, issuedMS: issued, expiresMS: expires)
    }

    private static func common(_ fields: [String: DirectRichWireJSON]) throws {
        guard fields["success"] == .bool(true), fields["contract_version"] == .integer(1),
              fields["profile_id"] == .string("djconnect-direct-rich-v1") else { throw invalid() }
    }
    private static func bounds(_ fields: [String: DirectRichWireJSON]) throws -> (Int64, Int64) {
        let issued = try DirectRichFrameShape.integer(fields["purpose_issued_at_ms"], minimum: 1)
        let expires = try DirectRichFrameShape.integer(fields["purpose_expires_at_ms"], minimum: 1)
        guard expires > issued, expires - issued <= 28800000 else { throw invalid() }
        return (issued, expires)
    }
    private static func credential(_ value: String, family: String) -> Bool {
        let prefix = "djcrich\(family)_"
        return value.hasPrefix(prefix) && DirectRichRequest.matches(String(value.dropFirst(prefix.count)), "[A-Za-z0-9_-]{43}") &&
            value.last.map { "AEIMQUYcgkosw048".contains($0) } == true
    }
    private static func required<T>(_ value: T?) throws -> T { guard let value else { throw invalid() }; return value }
    private static func invalid() -> DJConnectError { .invalidResponse }
}
