import Foundation
import CoreFoundation

/// Core e84ffd25 / passive contract af201f6a. These are comparison DATA,
/// never a native SDK admission, registration receipt or display grant.
public enum DJConnectAutomaticSurfaceRole: String, CaseIterable, Sendable {
    case widget = "widget_transport"
    case statusActivity = "status_activity_transport"
    public var statePath: String { "/api/djconnect/v1/surface_registration/\(rawValue)/state" }
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
    static func identifier(_ s: String) -> Bool {
        (1...128).contains(s.utf8.count) && s.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || [45, 46, 58, 95].contains($0)
        }
    }
    static func fields(_ object: [String: Any], specs: [(String, Kind)], original: Data) throws -> [String: Value] {
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
                    let b = Array(s.utf8)
                    guard b.count == 36, b[14] == 52, [56, 57, 97, 98].contains(b[19]),
                          UUID(uuidString: s)?.uuidString.lowercased() == s else { throw DJConnectError.invalidResponse }
                }
                result[name] = .string(s)
            }
        }
        // Field order and original lexical bytes are part of this new contract.
        let canonical = "{" + specs.map { "\"\($0.0)\":" + result[$0.0]!.json }.joined(separator: ",") + "}"
        guard Data(canonical.utf8) == original else { throw DJConnectError.invalidResponse }
        return result
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
        guard request.httpMethod == "GET", request.httpBody == nil,
              let url = request.url, let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              ["http", "https"].contains(c.scheme), c.host?.isEmpty == false,
              c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
              c.percentEncodedPath == role.statePath, isCurrent() else { throw DJConnectError.invalidResponse }
        let result = try await DJConnectBoundedHTTPTransport.send(request, using: session, maximumBytes: 16384,
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
        let state = try DJConnectAutomaticSurfaceState.decode(result.data, role: role, scope: scope)
        guard (result.mime == "503") == (state == .unavailable) else { throw DJConnectError.invalidResponse }
        return state
    }
}
