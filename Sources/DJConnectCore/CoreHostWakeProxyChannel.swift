import Foundation

/// Core-only paired HTTPS operation transport. Replies remain DATA: this
/// channel never enrolls a key, grants native publication or retries a stage.
@MainActor final class CoreHostWakeProxyChannel {
    struct Reply: Sendable { let body: Data; let status: Int }
    private let origin: URL
    private let session: URLSession
    private let tokenStore: any DJConnectTokenStore
    private let originalToken: String
    private let identity: DJConnectIdentity

    convenience init(client: DJConnectClient) throws {
        try self.init(pairedOrigin: client.baseURL, identity: client.identity, tokenStore: client.tokenStore)
    }
    init(pairedOrigin: URL, identity: DJConnectIdentity, tokenStore: any DJConnectTokenStore) throws {
        origin = try Self.checkedOrigin(pairedOrigin)
        guard identity.clientType == .ios else { throw DJConnectError.invalidResponse }
        self.identity = identity
        self.tokenStore = tokenStore
        guard let token = try tokenStore.loadToken(), Self.pairedCredential(token) else { throw DJConnectError.invalidResponse }
        originalToken = token
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil; configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil; configuration.httpAdditionalHeaders = [:]
        configuration.timeoutIntervalForRequest = 15; configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
    }
    /// Synthetic transport injection supplies no genuine receiving witness.
    init(testOrigin: URL, session: URLSession, tokenStore: any DJConnectTokenStore, identity: DJConnectIdentity) throws {
        guard identity.clientType == .ios else { throw DJConnectError.invalidResponse }
        self.identity = identity
        origin = try Self.checkedOrigin(testOrigin); self.session = session; self.tokenStore = tokenStore
        guard let token = try tokenStore.loadToken(), Self.pairedCredential(token) else { throw DJConnectError.invalidResponse }
        originalToken = token
    }
    deinit { session.invalidateAndCancel() }

    func send(_ intention: CoreHostWakeProxyRequest,
              beforeDispatch: @escaping @MainActor @Sendable () throws -> Void,
              isCurrent: @escaping @Sendable () -> Bool) async throws -> Reply {
        try Task.checkCancellation()
        guard isCurrent(), intention.fields["device_id"] == .string(identity.deviceID),
              intention.fields["client_type"] == .string(identity.clientType.rawValue),
              try tokenStore.loadToken() == originalToken else { throw CancellationError() }
        var request = URLRequest(url: origin.appendingPathComponent(String(intention.operation.path.dropFirst())))
        request.httpMethod = "POST"; request.httpBody = intention.body
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer " + originalToken, forHTTPHeaderField: "Authorization")
        request.setValue(intention.fields["device_id"]!.string!, forHTTPHeaderField: "X-DJConnect-Device-ID")
        request.setValue("ios", forHTTPHeaderField: "X-DJConnect-Client-Type")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        let metadata = Status()
        let reply = try await DJConnectBoundedHTTPTransport.send(request, using: session,
            maximumBytes: 16384, beforeDispatch: { [self] in
                guard try tokenStore.loadToken() == originalToken else { throw CancellationError() }
                try beforeDispatch()
            }, isBodyCurrent: isCurrent, validateResponse: { response in
                guard [200, 400, 401, 403, 404, 409, 413, 503].contains(response.statusCode),
                      response.mimeType?.lowercased() == "application/json",
                      response.value(forHTTPHeaderField: "Cache-Control")?.lowercased().split(separator: ",")
                        .map({ $0.trimmingCharacters(in: .whitespaces) }).contains("no-store") == true,
                      response.value(forHTTPHeaderField: "X-Content-Type-Options")?.lowercased() == "nosniff",
                      response.value(forHTTPHeaderField: "Referrer-Policy")?.lowercased() == "no-referrer",
                      response.value(forHTTPHeaderField: "Content-Encoding") == nil || response.value(forHTTPHeaderField: "Content-Encoding")?.lowercased() == "identity",
                      response.expectedContentLength <= 16384, metadata.capture(response.statusCode) else { throw DJConnectError.invalidResponse }
                return "application/json"
            })
        try Task.checkCancellation()
        guard isCurrent(), try tokenStore.loadToken() == originalToken, let status = metadata.value else { throw CancellationError() }
        _ = try CoreHostWakeProxyDataJSON.parse(reply.data)
        return Reply(body: reply.data, status: status) // HTTP200 is never native/enrollment success.
    }
    private static func checkedOrigin(_ url: URL) throws -> URL {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false), c.scheme == "https", c.host?.isEmpty == false,
              c.user == nil, c.password == nil, c.query == nil, c.fragment == nil, ["", "/"].contains(c.percentEncodedPath),
              c.port == nil || (1...65535).contains(c.port!) else { throw DJConnectError.invalidResponse }
        return url
    }
    private static func pairedCredential(_ token: String) -> Bool {
        !token.isEmpty && token.utf8.count <= 4096 && !token.hasPrefix("djcrich") && !token.hasPrefix("djchw_") &&
            token.utf8.allSatisfy { (33...126).contains($0) }
    }
    private final class Status: @unchecked Sendable {
        private let lock = NSLock(); private var status: Int?
        var value: Int? { lock.withLock { status } }
        func capture(_ value: Int) -> Bool { lock.withLock { guard status == nil else { return false }; status = value; return true } }
    }
}
