import Foundation

/// Exact content-pinned Core paired-owner contract v1. Discovery is not authority.
public struct DJConnectPairedOwnerLiveCapability: Decodable, Sendable {
    public let available: Bool
    public let path: String
    public let version: Int
    public let auth: String
    public let audience: String
    public let clientTypes: [String]
    public let commands: [String]
    public let leaseSeconds: Int
    public let authTimeoutSeconds: Int
    public let revocationCheckSeconds: Int
    public let haCredentialsIssued: Bool
    public static let subscribe = "djconnect/session/broadcast/subscribe"
    public static let recover = "djconnect/session/broadcast/recover"
    enum CodingKeys: String, CodingKey {
        case available, path, version, auth, audience, commands
        case clientTypes = "client_types", leaseSeconds = "lease_seconds"
        case authTimeoutSeconds = "auth_timeout_seconds", revocationCheckSeconds = "revocation_check_seconds"
        case haCredentialsIssued = "ha_credentials_issued"
    }
    public func websocketURL(baseURL: URL, clientType: DJConnectClientType) throws -> URL {
        guard available, version == 1, path == "/api/djconnect/v1/session/broadcast/paired",
              auth == "paired_device_first_frame", audience == "active_owner_broadcast",
              clientTypes.contains(clientType.rawValue), leaseSeconds == 300, authTimeoutSeconds == 5,
              revocationCheckSeconds == 1, !haCredentialsIssued,
              commands.count == 2, Set(commands) == [Self.subscribe, Self.recover],
              var url = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              ["http", "https"].contains(url.scheme), url.host != nil,
              url.user == nil, url.password == nil else {
            throw DJConnectError.routeMissing(message: "Supported paired owner live contract is unavailable")
        }
        url.scheme = url.scheme == "https" ? "wss" : "ws"
        url.path = path; url.query = nil; url.fragment = nil
        guard let value = url.url else { throw DJConnectError.invalidResponse }
        return value
    }
}

struct DJConnectPairedOwnerLiveDiscovery: Decodable {
    struct Broadcast: Decodable {
        let pairedOwnerWebsocket: DJConnectPairedOwnerLiveCapability?
        enum CodingKeys: String, CodingKey { case pairedOwnerWebsocket = "paired_owner_websocket" }
    }
    let sessionBroadcast: Broadcast?
    enum CodingKeys: String, CodingKey { case sessionBroadcast = "session_broadcast" }
}

struct DJConnectPairedOwnerAuthRequest: Encodable {
    let type = "auth"
    let protocolVersion = 1
    let deviceID: String
    let clientType: DJConnectClientType
    let deviceToken: String
    enum CodingKeys: String, CodingKey {
        case type; case protocolVersion = "protocol_version", deviceID = "device_id"
        case clientType = "client_type", deviceToken = "device_token"
    }
}

struct DJConnectPairedOwnerSubscribeRequest: Encodable {
    let id = 1
    let type = DJConnectPairedOwnerLiveCapability.subscribe
    let sessionID: String
    enum CodingKeys: String, CodingKey { case id, type; case sessionID = "session_id" }
}

/// Public discovery cannot use cached credentials, headers or redirects.
final class DJConnectPublicDiscoveryDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let original: (any URLSessionDelegate)?
    init(original: (any URLSessionDelegate)?) { self.original = original }
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil); return
        }
        if let original = original as? any URLSessionTaskDelegate,
           original.responds(to: #selector(URLSessionTaskDelegate.urlSession(_:task:didReceive:completionHandler:))) {
            original.urlSession?(session, task: task, didReceive: challenge, completionHandler: completionHandler)
        } else { self.urlSession(session, didReceive: challenge, completionHandler: completionHandler) }
    }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil); return
        }
        if let original, original.responds(to: #selector(URLSessionDelegate.urlSession(_:didReceive:completionHandler:))) {
            original.urlSession?(session, didReceive: challenge, completionHandler: completionHandler)
        } else { completionHandler(.performDefaultHandling, nil) }
    }
}

/// Foundation exposes a WebSocket upgrade using HTTP(S) on some supported OS versions.
func pairedLiveUpgradeMatches(_ current: URL?, expected: URL) -> Bool {
    guard let current, let a = URLComponents(url: current, resolvingAgainstBaseURL: false),
          let b = URLComponents(url: expected, resolvingAgainstBaseURL: false),
          a.user == nil, a.password == nil, a.query == nil, a.fragment == nil else { return false }
    func scheme(_ value: String?) -> String? {
        switch value?.lowercased() { case "ws", "http": return "http"; case "wss", "https": return "https"; default: return nil }
    }
    guard let left = scheme(a.scheme), left == scheme(b.scheme) else { return false }
    let defaultPort = left == "https" ? 443 : 80
    return a.host?.lowercased() == b.host?.lowercased() && (a.port ?? defaultPort) == (b.port ?? defaultPort) && a.percentEncodedPath == b.percentEncodedPath
}

func pairedLiveCredentialFreeSession(from original: URLSession) -> URLSession {
    let configuration = original.configuration
    configuration.httpAdditionalHeaders = nil; configuration.urlCredentialStorage = nil
    configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
    configuration.urlCache = nil
    return URLSession(configuration: configuration, delegate: DJConnectPublicDiscoveryDelegate(original: original.delegate), delegateQueue: nil)
}
