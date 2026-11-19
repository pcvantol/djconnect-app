import Foundation

/// Closed operation selection, independent of the legacy widget task owners.
/// An accepted request is only an intention; it grants no source/native rights.
struct DirectRichRequest: Sendable {
    enum Operation: String, CaseIterable, Sendable { case authorize, read, asset, status, withdraw }
    let operation: Operation
    let body: Data
    let sha256: String
    let fields: [String: DirectRichWireJSON]

    init(operation: Operation, originalBody: Data) throws {
        let node = try DirectRichWireJSON.parse(originalBody, maximumBytes: 8192)
        guard let fields = node.object else { throw DJConnectError.invalidResponse }
        let identity: Set<String> = ["contract_version", "device_id", "client_type", "session_id", "surface", "operation_id"]
        let expected: Set<String>
        switch operation {
        case .authorize: expected = identity.union(["enabled", "os_snapshot_cache", "locked_display"])
        case .status, .withdraw: expected = identity
        case .read: expected = ["contract_version", "purpose_id"]
        case .asset: expected = ["contract_version", "purpose_id", "frame_id", "asset_id"]
        }
        guard Set(fields.keys) == expected, fields["contract_version"] == .integer(1) else { throw DJConnectError.invalidResponse }
        switch operation {
        case .authorize, .status, .withdraw:
            guard let device = fields["device_id"]?.string,
                  Self.matches(device, "djconnect-(ios|macos)-[A-Za-z0-9]{12}"),
                  let client = fields["client_type"]?.string, ["ios", "macos"].contains(client),
                  device.hasPrefix("djconnect-\(client)-"),
                  let session = fields["session_id"]?.string, Self.matches(session, "[A-Za-z0-9_-]{1,128}"),
                  let surface = fields["surface"]?.string, ["widget", "live_activity"].contains(surface),
                  surface != "live_activity" || client == "ios",
                  Self.isUUID(fields["operation_id"]?.string) else { throw DJConnectError.invalidResponse }
            if operation == .authorize {
                for key in ["enabled", "os_snapshot_cache", "locked_display"] {
                    guard case .bool = fields[key] else { throw DJConnectError.invalidResponse }
                }
            }
        case .read, .asset:
            guard Self.isUUID(fields["purpose_id"]?.string) else { throw DJConnectError.invalidResponse }
            if operation == .asset {
                guard Self.matches(fields["frame_id"]?.string, "[a-f0-9]{64}"),
                      Self.matches(fields["asset_id"]?.string, "[A-Za-z0-9_-]{32}") else { throw DJConnectError.invalidResponse }
            }
        }
        self.operation = operation; self.fields = fields
        body = try node.canonicalData(); sha256 = try node.digest()
    }

    static func matches(_ string: String?, _ pattern: String) -> Bool {
        guard let string else { return false }
        return string.range(of: "\\A(?:" + pattern + ")\\z", options: .regularExpression) != nil
    }
    static func isUUID(_ string: String?) -> Bool {
        matches(string, "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}")
    }
}

/// A fixed server denial, never a parent-device unpair instruction. In
/// particular frameUnavailable preserves the original purpose, while
/// unavailable permanently retires it. Neither permits reauthorization.
enum DirectRichServerError: String, Error, Sendable, CaseIterable {
    case invalidRequest = "invalid_request", unauthorized
    case notAllowed = "rich_not_allowed", historyUnknown = "rich_history_unknown"
    case assetUnavailable = "rich_asset_unavailable", purposeConsumed = "rich_purpose_consumed"
    case frameChanged = "rich_frame_changed", capacity = "rich_capacity"
    case unavailable = "rich_unavailable", frameUnavailable = "rich_frame_unavailable"

    var status: Int {
        switch self {
        case .invalidRequest: 400
        case .unauthorized: 401
        case .notAllowed: 403
        case .historyUnknown, .assetUnavailable: 404
        case .purposeConsumed, .frameChanged, .capacity: 409
        case .unavailable, .frameUnavailable: 503
        }
    }
    static func decode(_ body: Data, status: Int) throws -> Self {
        let node = try DirectRichWireJSON.parse(body, maximumBytes: 16384)
        guard let fields = node.object, Set(fields.keys) == ["success", "contract_version", "error"],
              fields["success"] == .bool(false), fields["contract_version"] == .integer(1),
              let code = fields["error"]?.string, let error = Self(rawValue: code), error.status == status else {
            throw DJConnectError.invalidResponse
        }
        return error
    }
}
