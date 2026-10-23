import Foundation

/// Closed request bytes captured once by the owning registration attempt.
/// No operation ID, consent, purpose or native token is created here.
public struct DJConnectSurfacePushRequest: Sendable {
    let bytes: Data
    public let deviceID: String
    public let clientType: String
    public let sessionID: String
    public let tokenRole: String
    public let instanceID: String
    public init?(identity: DJConnectIdentity, sessionID: String, operationID: String,
                 platform: String, osVersion: String, target: [String: String], token: Data,
                 environment: String, consent: [String: Bool], expected: DJConnectSurfacePushCoordinate?) {
        let id = DJConnectSurfacePushCoordinate.identifier
        let role = target["widget_kind"] == nil ? "live_activity_update" : "widget"
        let fields: Set<String> = role == "widget"
            ? ["instance_id", "app_bundle_id", "extension_bundle_id", "widget_kind"]
            : ["instance_id", "app_bundle_id", "activity_id", "attributes_type"]
        let consentFields: Set<String> = ["background_read", "os_snapshot_cache", "locked_display", "external_push_content", "allow_remote_start"]
        let version = osVersion.split(separator: ".").compactMap { Int($0) }
        guard id(sessionID), id(identity.deviceID), identity.deviceID.hasPrefix(platform == "macos" ? "djconnect-macos-" : "djconnect-ios-"), let instance = target["instance_id"], id(instance),
              operationID.range(of: "^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", options: .regularExpression) != nil,
              ["ios", "ipados", "macos"].contains(platform),
              identity.clientType.rawValue == (platform == "macos" ? "macos" : "ios"),
              osVersion.range(of: "^[1-9][0-9]?(?:\\.[0-9]{1,2}){1,2}$", options: .regularExpression) != nil,
              version.count >= 2, role == "widget" ? version[0] >= 26 :
                (platform != "macos" && (version[0] > (platform == "ipados" ? 17 : 16) ||
                    (version[0] == (platform == "ipados" ? 17 : 16) && version[1] >= (platform == "ipados" ? 0 : 1)))),
              (16...2048).contains(token.count), ["sandbox", "production"].contains(environment),
              Set(target.keys) == fields, target.allSatisfy({ key, value in
                  value.utf8.count <= 200 && (key.hasSuffix("bundle_id")
                      ? value.range(of: "^[A-Za-z0-9-]+(?:\\.[A-Za-z0-9-]+)+$", options: .regularExpression) != nil : id(value))
              }), Set(consent.keys) == consentFields, consent["os_snapshot_cache"] == true,
              consent["allow_remote_start"] == false,
              role == "widget" ? (consent["background_read"] == true && consent["external_push_content"] == false) :
                (consent["locked_display"] == true && consent["external_push_content"] == true),
              expected?.isValid ?? true else { return nil }
        var body: [String: Any] = ["contract_version":1,"device_id":identity.deviceID,"client_type":identity.clientType.rawValue,
            "session_id":sessionID,"operation_id":operationID,"platform":platform,"os_version":osVersion,
            "token_role":role,"target":target,"apns_token":token.map { String(format:"%02x",$0) }.joined(),
            "apns_environment":environment,"consent":consent,"expected_registration":NSNull()]
        if let expected { body["expected_registration"] = ["registration_id":expected.registration_id,"generation":expected.generation,"revision":expected.revision] }
        guard let bytes = try? JSONSerialization.data(withJSONObject:body,options:[.sortedKeys]), bytes.count <= 16384 else { return nil }
        self.bytes = bytes; deviceID = identity.deviceID; clientType = identity.clientType.rawValue
        self.sessionID = sessionID; tokenRole = role; instanceID = instance
    }
}

public struct DJConnectSurfacePushContext: Decodable, Sendable {
    public let success: Bool
    public let contract_version: Int
    public let available: Bool
    public let expires_at_ms: Int64
    public let cache_policy: String
    /// Discovery metadata only; this is not an original owner/purpose witness.
    public var hasValidShape: Bool {
        success && contract_version == 1 && available && expires_at_ms > 0 &&
        expires_at_ms <= 9_007_199_254_740_991 && cache_policy == "private,no-store"
    }
}

public struct DJConnectSurfacePushStatus: Decodable, Sendable {
    public let success: Bool
    public let contract_version: Int
    public let registration: DJConnectSurfacePushReceipt
}

/// A fixed HA POST only. No WS/HTTP fallback, retry, redirects, cookie/auth
/// storage, ambient headers, credential minting or persistent response cache.
@MainActor final class DJConnectSurfacePushHTTP {
    private static var active = 0
    private let session: URLSession
    nonisolated init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.httpAdditionalHeaders = nil; configuration.urlCache = nil
        configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil; configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 10; configuration.timeoutIntervalForResource = 10
        session = URLSession(configuration: configuration)
    }
    deinit { session.invalidateAndCancel() }
    func send(_ request: URLRequest, isCurrent: @escaping @MainActor @Sendable () -> Bool) async throws -> Data {
        guard Self.active < 2, request.httpMethod == "POST", let bytes = request.httpBody, bytes.count <= 16384,
              let url = request.url, let c = URLComponents(url:url,resolvingAgainstBaseURL:false),
              ["https","http"].contains(c.scheme), c.host?.isEmpty == false,
              c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
              isCurrent(), !Task.isCancelled else { throw DJConnectError.invalidResponse }
        Self.active += 1; defer { Self.active -= 1 }
        let result = try await DJConnectBoundedHTTPTransport.send(request,using:session,maximumBytes:65536,
            beforeDispatch:{ guard isCurrent() else { throw CancellationError() } },validateResponse:{ response in
                switch response.statusCode {
                case 200: break
                case 401: throw DJConnectError.authStale(statusCode:401,message:nil)
                case 403: throw DJConnectError.profile(code:.profileAccessDenied,statusCode:403,message:nil)
                default: throw DJConnectError.server(statusCode:response.statusCode,message:nil)
                }
                guard response.mimeType?.lowercased() == "application/json",
                      response.textEncodingName.map({ ["utf-8","utf8"].contains($0.lowercased()) }) ?? true,
                      response.value(forHTTPHeaderField:"Content-Encoding").map({ $0.lowercased() == "identity" }) ?? true,
                      response.value(forHTTPHeaderField:"Cache-Control")?.lowercased().split(separator:",").contains(where:{ $0.trimmingCharacters(in:.whitespaces) == "no-store" }) == true,
                      response.value(forHTTPHeaderField:"Referrer-Policy")?.lowercased() == "no-referrer",
                      response.value(forHTTPHeaderField:"X-Content-Type-Options")?.lowercased() == "nosniff"
                else { throw DJConnectError.invalidResponse }
                return "application/json"
            })
        guard isCurrent(), !Task.isCancelled else { throw CancellationError() }
        try DJConnectSurfacePushJSON.validate(result.data)
        return result.data
    }
}

/// This client owns no paired token store. Its only request authentication is
/// the separately scoped original read credential, never an app/issuer bearer.
@MainActor public final class DJConnectSurfaceBackgroundHTTP {
    private let url: URL
    private let transport: DJConnectSurfacePushHTTP
    private let nowMS: @MainActor @Sendable () -> Int64
    public convenience init(baseURL: URL) throws { try self.init(baseURL:baseURL,configuration:.ephemeral) }
    init(baseURL: URL, configuration: URLSessionConfiguration, nowMS: @escaping @MainActor @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }) throws {
        guard let c = URLComponents(url:baseURL,resolvingAgainstBaseURL:false),
              ["https","http"].contains(c.scheme), c.host?.isEmpty == false,
              c.user == nil, c.password == nil, c.query == nil, c.fragment == nil else { throw DJConnectError.invalidResponse }
        url = baseURL.appendingPathComponent("api/djconnect/v1/push/surface/read")
        transport = DJConnectSurfacePushHTTP(configuration:configuration)
        self.nowMS = nowMS
    }
    public func read(_ original: DJConnectSurfaceBackgroundRead,
                     isCurrent: @escaping @MainActor @Sendable () -> Bool) async throws -> DJConnectSurfacePushReadResponse {
        guard original.credential.range(of:"^djcsurface_[A-Za-z0-9_-]{43}$",options:.regularExpression) != nil,
              original.scope == "exact_original_surface_read_only", original.cache_policy == "private,no-store",
              DJConnectSurfacePushCoordinate.identifier(original.registration_id),
              original.expires_at_ms > nowMS(), original.expires_at_ms <= 9_007_199_254_740_991 else { throw DJConnectError.invalidResponse }
        var request = URLRequest(url:url)
        request.httpMethod = "POST"; request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer " + original.credential,forHTTPHeaderField:"Authorization")
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.setValue("application/json",forHTTPHeaderField:"Accept")
        request.setValue("identity",forHTTPHeaderField:"Accept-Encoding")
        request.setValue("no-store",forHTTPHeaderField:"Cache-Control")
        request.httpBody = try JSONSerialization.data(withJSONObject:["contract_version":1,"registration_id":original.registration_id])
        let data = try await transport.send(request,isCurrent:{ isCurrent() && self.nowMS() < original.expires_at_ms })
        guard let response = try? JSONDecoder().decode(DJConnectSurfacePushReadResponse.self,from:data) else { throw DJConnectError.invalidResponse }
        return response // Original admission, IDs/rights/deadlines still checked by the owner.
    }
}
