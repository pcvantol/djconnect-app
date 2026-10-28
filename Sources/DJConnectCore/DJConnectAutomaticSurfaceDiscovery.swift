import Foundation
import CoreFoundation
import CryptoKit

/// Core e84ffd25 / passive contract af201f6a. These are comparison DATA,
/// never a native SDK admission, registration receipt or display grant.
public enum DJConnectAutomaticSurfaceRole: String, CaseIterable, Sendable {
    case widget = "widget_transport"
    case statusActivity = "status_activity_transport"
    public var statePath: String { "/api/djconnect/v1/surface_registration/\(rawValue)/state" }
    public var childIndexPath: String { "/api/djconnect/v1/surface_registration/\(rawValue)/children" }
    public static func childStatePath(_ id: String) -> String? {
        AutomaticSurfaceWire.uuid(id) ? "/api/djconnect/v1/surface_registration/children/\(id)/state" : nil
    }
    public static func childReceiptPath(_ id: String) -> String? {
        AutomaticSurfaceWire.uuid(id) ? "/api/djconnect/v1/surface_registration/children/\(id)/receipt" : nil
    }
}

/// Actual paired device coordinates. Deliberately independent of Session/Profile.
public struct DJConnectAutomaticSurfaceScope: Equatable, Sendable {
    public let installationID: String
    public let deviceID: String
    public let clientType: String
    public let platform: String
    public let applicationID: String
    public init?(installationID: String, deviceID: String, clientType: String,
                 platform: String, applicationID: String) {
        guard [installationID, deviceID, applicationID].allSatisfy(AutomaticSurfaceWire.identifier),
              ["ios": "ios", "ipados": "ios", "macos": "macos", "watchos": "watchos"][platform] == clientType else { return nil }
        self.installationID = installationID; self.deviceID = deviceID
        self.clientType = clientType; self.platform = platform; self.applicationID = applicationID
    }
}

public struct DJConnectAutomaticSurfaceCoordinate: Equatable, Sendable {
    public let pairingEpoch: String
    public let authorityID: String
    public let authorityRevision: Int64
    public let originalOperationID: String
    public let parentID: String
    public let parentGeneration: Int64
    public let originalBodySHA256: String
    fileprivate init(_ v: [String: AutomaticSurfaceWire.Value]) {
        pairingEpoch = v["pairing_epoch"]!.text; authorityID = v["push_authority_id"]!.text
        authorityRevision = v["push_authority_revision"]!.integer
        originalOperationID = v["original_operation_id"]!.text; parentID = v["parent_enrollment_id"]!.text
        parentGeneration = v["parent_enrollment_generation"]!.integer; originalBodySHA256 = v["A_body_sha256"]!.text
    }
}

public struct DJConnectAutomaticSurfaceDescriptor: Equatable, Sendable {
    public let coordinate: DJConnectAutomaticSurfaceCoordinate
    public let scope: DJConnectAutomaticSurfaceScope
    public let role: DJConnectAutomaticSurfaceRole
    public let authGeneration: String
    public let operationDeadlineMS: Int64
    public let parentExpiryMS: Int64
    // Retain every original comparison field. Do not rebuild an A receipt from
    // these data or confuse its body digest with verified original body bytes.
    fileprivate let fields: [String: AutomaticSurfaceWire.Value]
    fileprivate init(_ v: [String: AutomaticSurfaceWire.Value], scope: DJConnectAutomaticSurfaceScope,
                     role: DJConnectAutomaticSurfaceRole) {
        coordinate = .init(v); self.scope = scope; self.role = role; fields = v
        authGeneration = v["auth_generation"]!.text
        operationDeadlineMS = v["operation_deadline_unix_ms"]!.integer
        parentExpiryMS = v["device_enrollment_expires_at_unix_ms"]!.integer
    }
}

public enum DJConnectAutomaticSurfaceState: Equatable, Sendable {
    case waitingAuthority, unavailable
    case current(DJConnectAutomaticSurfaceDescriptor)
    case retired(DJConnectAutomaticSurfaceCoordinate)
    case unknown(DJConnectAutomaticSurfaceCoordinate)

    public static func decode(_ bytes: Data, role: DJConnectAutomaticSurfaceRole,
                              scope: DJConnectAutomaticSurfaceScope) throws -> Self {
        guard !bytes.isEmpty, bytes.count <= 16384 else { throw DJConnectError.invalidResponse }
        try DJConnectSurfacePushJSON.validate(bytes)
        guard let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let state = object["state"] as? String else { throw DJConnectError.invalidResponse }
        let specs: [(String, AutomaticSurfaceWire.Kind)]
        switch state {
        case "WAITING_AUTHORITY", "UNAVAILABLE": specs = AutomaticSurfaceWire.common
        case "RETIRED", "UNKNOWN": specs = AutomaticSurfaceWire.common + AutomaticSurfaceWire.coordinate
        case "AUTHORITY_CURRENT": specs = AutomaticSurfaceWire.common + AutomaticSurfaceWire.descriptor
        default: throw DJConnectError.invalidResponse
        }
        let v = try AutomaticSurfaceWire.fields(object, specs: specs, original: bytes)
        guard v["version"] == .number(1) else { throw DJConnectError.invalidResponse }
        switch state {
        case "WAITING_AUTHORITY": return .waitingAuthority
        case "UNAVAILABLE": return .unavailable
        case "RETIRED": return .retired(.init(v))
        case "UNKNOWN": return .unknown(.init(v))
        default:
            guard v["installation_id"]?.text == scope.installationID,
                  v["device_id"]?.text == scope.deviceID, v["client_id"]?.text == scope.deviceID,
                  v["client_type"]?.text == scope.clientType, v["device_platform"]?.text == scope.platform,
                  v["application_id"]?.text == scope.applicationID, v["transport_role"]?.text == role.rawValue,
                  v["issued_at_unix_ms"]!.integer < v["operation_deadline_unix_ms"]!.integer,
                  v["operation_deadline_unix_ms"]!.integer <= v["device_enrollment_expires_at_unix_ms"]!.integer else {
                throw DJConnectError.invalidResponse
            }
            return .current(.init(v, scope: scope, role: role))
        }
    }
}

/// Original child comparison coordinates, not a verified B grant.
public struct DJConnectAutomaticSurfaceChildState: Equatable, Sendable {
    public enum Outcome: String, Sendable { case current = "CURRENT", retired = "RETIRED", expired = "EXPIRED", unknown = "UNKNOWN", suppressed = "COMMITTED_BUT_SUPPRESSED" }
    public let parent: DJConnectAutomaticSurfaceCoordinate
    public let childID: String
    public let revision: Int64
    public let originalBodySHA256: String
    public let outcome: Outcome
    fileprivate let fields: [String: AutomaticSurfaceWire.Value]
    fileprivate init(_ v: [String: AutomaticSurfaceWire.Value], outcome: Outcome) {
        parent = .init(v); childID = v["child_id"]!.text; revision = v["child_revision"]!.integer
        originalBodySHA256 = v["B_body_sha256"]!.text; self.outcome = outcome; fields = v
    }
    fileprivate static func parse(_ object: [String: Any], parent: DJConnectAutomaticSurfaceCoordinate) throws -> Self {
        let v = try AutomaticSurfaceWire.fields(object, specs: AutomaticSurfaceWire.child)
        guard v["version"] == .number(1), v["state"] == .string("CHILD_STATE"),
              DJConnectAutomaticSurfaceCoordinate(v) == parent,
              let outcome = Outcome(rawValue: v["outcome"]!.text) else { throw DJConnectError.invalidResponse }
        return .init(v, outcome: outcome)
    }
}

public enum DJConnectAutomaticSurfaceChildRead: Equatable, Sendable {
    case unavailable, state(DJConnectAutomaticSurfaceChildState)
    public static func decode(_ bytes: Data, parent: DJConnectAutomaticSurfaceCoordinate) throws -> Self {
        let object = try AutomaticSurfaceWire.object(bytes, limit: 16384)
        if try AutomaticSurfaceWire.unavailable(object, original: bytes) { return .unavailable }
        let child = try DJConnectAutomaticSurfaceChildState.parse(object, parent: parent)
        guard AutomaticSurfaceWire.json(child.fields, specs: AutomaticSurfaceWire.child) == String(data: bytes, encoding: .utf8) else { throw DJConnectError.invalidResponse }
        return .state(child)
    }
}

public struct DJConnectAutomaticSurfaceChildIndex: Equatable, Sendable {
    public let parent: DJConnectAutomaticSurfaceCoordinate
    public let children: [DJConnectAutomaticSurfaceChildState]
    fileprivate init(parent: DJConnectAutomaticSurfaceCoordinate, children: [DJConnectAutomaticSurfaceChildState]) {
        self.parent = parent; self.children = children
    }
}

public enum DJConnectAutomaticSurfaceChildIndexRead: Equatable, Sendable {
    case unavailable, index(DJConnectAutomaticSurfaceChildIndex)
    /// The finite required bound is caller-supplied parser policy, never a new
    /// grant, admission default, or authority inferred from the child list.
    public static func decode(_ bytes: Data, parent: DJConnectAutomaticSurfaceCoordinate,
                              maximumChildren: Int) throws -> Self {
        guard maximumChildren > 0, Int64(maximumChildren) <= 9_007_199_254_740_991 else { throw DJConnectError.invalidResponse }
        let object = try AutomaticSurfaceWire.object(bytes, limit: 65536)
        if try AutomaticSurfaceWire.unavailable(object, original: bytes) { return .unavailable }
        guard Set(object.keys) == Set(AutomaticSurfaceWire.index.map(\.0) + ["children"]),
              let entries = object["children"] as? [[String: Any]], entries.count <= maximumChildren else { throw DJConnectError.invalidResponse }
        var metadata = object; metadata.removeValue(forKey: "children")
        let v = try AutomaticSurfaceWire.fields(metadata, specs: AutomaticSurfaceWire.index)
        guard v["version"] == .number(1), v["state"] == .string("CHILD_INDEX"),
              v["pairing_epoch"]?.text == parent.pairingEpoch, v["parent_enrollment_id"]?.text == parent.parentID,
              v["parent_enrollment_generation"]?.integer == parent.parentGeneration,
              v["A_body_sha256"]?.text == parent.originalBodySHA256 else { throw DJConnectError.invalidResponse }
        let children = try entries.map { try DJConnectAutomaticSurfaceChildState.parse($0, parent: parent) }
        let ids = children.map(\.childID)
        guard ids == ids.sorted(), Set(ids).count == ids.count else { throw DJConnectError.invalidResponse }
        let prefix = String(AutomaticSurfaceWire.json(v, specs: AutomaticSurfaceWire.index).dropLast())
        let canonical = prefix + ",\"children\":[" + children.map { AutomaticSurfaceWire.json($0.fields, specs: AutomaticSurfaceWire.child) }.joined(separator: ",") + "]}"
        guard Data(canonical.utf8) == bytes else { throw DJConnectError.invalidResponse }
        return .index(.init(parent: parent, children: children))
    }
}

/// B body/signature bytes with an exact original hash join only. This type
/// deliberately has no signature verifier, trusted principal or native port.
public struct DJConnectUnverifiedSurfaceChildReceipt: Equatable, Sendable {
    public let classification = "UNVERIFIED_RECEIPT_DATA_ONLY"
    public let child: DJConnectAutomaticSurfaceChildState
    public let body: Data
    public let signature: Data
    fileprivate init(child: DJConnectAutomaticSurfaceChildState, body: Data, signature: Data) {
        self.child = child; self.body = body; self.signature = signature
    }
}

public enum DJConnectAutomaticSurfaceChildReceiptRead: Equatable, Sendable {
    case unavailable, data(DJConnectUnverifiedSurfaceChildReceipt)
    public static func decode(_ bytes: Data, child: DJConnectAutomaticSurfaceChildState) throws -> Self {
        let object = try AutomaticSurfaceWire.object(bytes, limit: 16384)
        if try AutomaticSurfaceWire.unavailable(object, original: bytes) { return .unavailable }
        guard child.outcome == .current, Set(object.keys) == ["version", "state", "B_body_b64url", "B_signature_b64url"],
              let encodedBody = object["B_body_b64url"] as? String,
              let encodedSignature = object["B_signature_b64url"] as? String else { throw DJConnectError.invalidResponse }
        let common = try AutomaticSurfaceWire.fields(object.filter { ["version", "state"].contains($0.key) }, specs: AutomaticSurfaceWire.common)
        guard common["version"] == .number(1), common["state"] == .string("CHILD_RECEIPT") else { throw DJConnectError.invalidResponse }
        let body = try AutomaticSurfaceWire.base64(encodedBody, limit: 8192)
        let signature = try AutomaticSurfaceWire.base64(encodedSignature, limit: 64)
        guard signature.count == 64,
              SHA256.hash(data: body).map({ String(format: "%02x", $0) }).joined() == child.originalBodySHA256 else { throw DJConnectError.invalidResponse }
        let canonical = "{\"version\":1,\"state\":\"CHILD_RECEIPT\",\"B_body_b64url\":\"\(encodedBody)\",\"B_signature_b64url\":\"\(encodedSignature)\"}"
        guard Data(canonical.utf8) == bytes else { throw DJConnectError.invalidResponse }
        return .data(.init(child: child, body: body, signature: signature))
    }
}

private enum AutomaticSurfaceWire {
    enum Value: Equatable, Sendable {
        case string(String), number(Int64)
        var text: String { if case .string(let v) = self { return v }; return "" }
        var integer: Int64 { if case .number(let v) = self { return v }; return 0 }
        var json: String { if case .string(let v) = self { return "\"\(v)\"" }; return String(integer) }
    }
    enum Kind { case id, uuid, hash, number }
    static let common: [(String, Kind)] = [("version", .number), ("state", .id)]
    static let coordinate: [(String, Kind)] = [
        ("pairing_epoch", .id), ("push_authority_id", .id), ("push_authority_revision", .number),
        ("original_operation_id", .uuid), ("parent_enrollment_id", .uuid),
        ("parent_enrollment_generation", .number), ("A_body_sha256", .hash)
    ]
    static let descriptor: [(String, Kind)] = [
        ("core_instance_id", .id), ("installation_id", .id), ("entry_id", .id), ("device_id", .id),
        ("client_id", .id), ("client_type", .id), ("auth_generation", .id), ("pairing_digest_sha256", .hash)
    ] + coordinate + [
        ("device_platform", .id), ("application_id", .id), ("transport_role", .id),
        ("policy_id", .id), ("policy_revision", .number), ("policy_sha256", .hash),
        ("clock_witness_sha256", .hash), ("issued_at_unix_ms", .number),
        ("operation_deadline_unix_ms", .number), ("device_enrollment_expires_at_unix_ms", .number)
    ]
    static let child: [(String, Kind)] = common + coordinate + [("child_id", .uuid), ("child_revision", .number), ("B_body_sha256", .hash), ("outcome", .id)]
    static let index: [(String, Kind)] = common + [("pairing_epoch", .id), ("parent_enrollment_id", .uuid), ("parent_enrollment_generation", .number), ("A_body_sha256", .hash)]
    static func object(_ bytes: Data, limit: Int) throws -> [String: Any] {
        guard !bytes.isEmpty, bytes.count <= limit else { throw DJConnectError.invalidResponse }
        try DJConnectSurfacePushJSON.validate(bytes)
        guard let result = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw DJConnectError.invalidResponse }
        return result
    }
    static func unavailable(_ object: [String: Any], original: Data) throws -> Bool {
        guard object["state"] as? String == "UNAVAILABLE" else { return false }
        let values = try fields(object, specs: common, original: original)
        guard values["version"] == .number(1) else { throw DJConnectError.invalidResponse }
        return true
    }
    static func uuid(_ s: String) -> Bool {
        guard s.utf8.count == 36 else { return false }
        let b = Array(s.utf8)
        return b[14] == 52 && [56, 57, 97, 98].contains(b[19]) && UUID(uuidString: s)?.uuidString.lowercased() == s
    }
    static func base64(_ value: String, limit: Int) throws -> Data {
        guard !value.isEmpty, value.utf8.count <= (limit * 4 + 2) / 3,
              value.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || [45, 95].contains($0) }) else { throw DJConnectError.invalidResponse }
        let padded = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") + String(repeating: "=", count: (4 - value.utf8.count % 4) % 4)
        guard let data = Data(base64Encoded: padded), data.count <= limit,
              data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") == value else { throw DJConnectError.invalidResponse }
        return data
    }
    static func identifier(_ s: String) -> Bool {
        (1...128).contains(s.utf8.count) && s.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || [45, 46, 58, 95].contains($0)
        }
    }
    static func fields(_ object: [String: Any], specs: [(String, Kind)], original: Data? = nil) throws -> [String: Value] {
        guard Set(object.keys) == Set(specs.map(\.0)) else { throw DJConnectError.invalidResponse }
        var result: [String: Value] = [:]
        for (name, kind) in specs {
            switch kind {
            case .number:
                guard let n = object[name] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(),
                      (1...9_007_199_254_740_991).contains(n.int64Value) else { throw DJConnectError.invalidResponse }
                result[name] = .number(n.int64Value)
            default:
                guard let s = object[name] as? String, identifier(s) else { throw DJConnectError.invalidResponse }
                if kind == .hash {
                    guard s.utf8.count == 64, s.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw DJConnectError.invalidResponse }
                } else if kind == .uuid {
                    guard uuid(s) else { throw DJConnectError.invalidResponse }
                }
                result[name] = .string(s)
            }
        }
        // Field order and original lexical bytes are part of this new contract.
        if let original { guard Data(json(result, specs: specs).utf8) == original else { throw DJConnectError.invalidResponse } }
        return result
    }
    static func json(_ values: [String: Value], specs: [(String, Kind)]) -> String {
        "{" + specs.map { "\"\($0.0)\":" + values[$0.0]!.json }.joined(separator: ",") + "}"
    }
}

/// A bounded GET transport only. No generic route, fallback, cached credentials,
/// receipt verification, token collection, registration or SDK/native factory.
@MainActor final class DJConnectAutomaticSurfaceHTTP {
    private let session: URLSession
    init(configuration: URLSessionConfiguration) {
        configuration.httpAdditionalHeaders = nil; configuration.urlCache = nil
        configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil; configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 10; configuration.timeoutIntervalForResource = 10
        session = URLSession(configuration: configuration)
    }
    deinit { session.invalidateAndCancel() }
    func read(_ request: URLRequest, role: DJConnectAutomaticSurfaceRole,
              scope: DJConnectAutomaticSurfaceScope,
              isCurrent: @escaping @MainActor @Sendable () -> Bool) async throws -> DJConnectAutomaticSurfaceState {
        let result = try await response(request, exactPath: role.statePath, maximumBytes: 16384, isCurrent: isCurrent)
        let state = try DJConnectAutomaticSurfaceState.decode(result.data, role: role, scope: scope)
        try Self.checkStatus(result, unavailable: state == .unavailable)
        return state
    }
    func index(_ request: URLRequest, parent: DJConnectAutomaticSurfaceDescriptor, maximumChildren: Int,
               isCurrent: @escaping @MainActor @Sendable () -> Bool) async throws -> DJConnectAutomaticSurfaceChildIndexRead {
        guard maximumChildren > 0, Int64(maximumChildren) <= 9_007_199_254_740_991 else { throw DJConnectError.invalidResponse }
        let result = try await response(request, exactPath: parent.role.childIndexPath, maximumBytes: 65536, isCurrent: isCurrent)
        let index = try DJConnectAutomaticSurfaceChildIndexRead.decode(result.data, parent: parent.coordinate, maximumChildren: maximumChildren)
        try Self.checkStatus(result, unavailable: index == .unavailable)
        return index
    }
    func child(_ request: URLRequest, parent: DJConnectAutomaticSurfaceDescriptor, childID: String,
               isCurrent: @escaping @MainActor @Sendable () -> Bool) async throws -> DJConnectAutomaticSurfaceChildRead {
        guard let path = DJConnectAutomaticSurfaceRole.childStatePath(childID) else { throw DJConnectError.invalidResponse }
        let result = try await response(request, exactPath: path, maximumBytes: 16384, isCurrent: isCurrent)
        let child = try DJConnectAutomaticSurfaceChildRead.decode(result.data, parent: parent.coordinate)
        if case .state(let value) = child { guard value.childID == childID else { throw DJConnectError.invalidResponse } }
        try Self.checkStatus(result, unavailable: child == .unavailable)
        return child
    }
    func receipt(_ request: URLRequest, parent: DJConnectAutomaticSurfaceDescriptor, child: DJConnectAutomaticSurfaceChildState,
                 isCurrent: @escaping @MainActor @Sendable () -> Bool) async throws -> DJConnectAutomaticSurfaceChildReceiptRead {
        guard child.parent == parent.coordinate, child.outcome == .current,
              let path = DJConnectAutomaticSurfaceRole.childReceiptPath(child.childID) else { throw DJConnectError.invalidResponse }
        let result = try await response(request, exactPath: path, maximumBytes: 16384, isCurrent: isCurrent)
        let receipt = try DJConnectAutomaticSurfaceChildReceiptRead.decode(result.data, child: child)
        try Self.checkStatus(result, unavailable: receipt == .unavailable)
        return receipt
    }
    private static func checkStatus(_ response: DJConnectBoundedHTTPTransport.Response, unavailable: Bool) throws {
        // The shared transport's validated result tag retains the HTTP code;
        // response MIME is checked separately before any body bytes are read.
        guard (response.mime == "503") == unavailable else { throw DJConnectError.invalidResponse }
    }
    private func response(_ request: URLRequest, exactPath: String, maximumBytes: Int,
                          isCurrent: @escaping @MainActor @Sendable () -> Bool) async throws -> DJConnectBoundedHTTPTransport.Response {
        guard request.httpMethod == "GET", request.httpBody == nil,
              let url = request.url, let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              ["http", "https"].contains(c.scheme), c.host?.isEmpty == false,
              c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
              c.percentEncodedPath == exactPath, isCurrent() else { throw DJConnectError.invalidResponse }
        let result = try await DJConnectBoundedHTTPTransport.send(request, using: session, maximumBytes: maximumBytes,
            beforeDispatch: { guard isCurrent() else { throw CancellationError() } }, validateResponse: { response in
                switch response.statusCode {
                case 200, 503: break
                case 401: throw DJConnectError.authStale(statusCode: 401, message: nil)
                case 403: throw DJConnectError.profile(code: .profileAccessDenied, statusCode: 403, message: nil)
                default: throw DJConnectError.server(statusCode: response.statusCode, message: nil)
                }
                guard response.mimeType?.lowercased() == "application/json",
                      response.textEncodingName.map({ ["utf-8", "utf8"].contains($0.lowercased()) }) ?? true,
                      response.value(forHTTPHeaderField: "Content-Encoding").map({ $0.lowercased() == "identity" }) ?? true,
                      response.value(forHTTPHeaderField: "Cache-Control")?.lowercased().split(separator: ",").contains(where: { $0.trimmingCharacters(in: .whitespaces) == "no-store" }) == true else { throw DJConnectError.invalidResponse }
                return String(response.statusCode)
            })
        guard isCurrent(), !Task.isCancelled else { throw CancellationError() }
        return result
    }
}
