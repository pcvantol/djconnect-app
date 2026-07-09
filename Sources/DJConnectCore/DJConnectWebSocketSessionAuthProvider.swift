import Foundation

public actor DJConnectWebSocketSessionAuthProvider {
    private struct CachedSession: Sendable {
        var accessToken: String
        var expiresAt: Date?

        func isValid(now: Date) -> Bool {
            guard let expiresAt else {
                return true
            }
            return expiresAt.timeIntervalSince(now) > 60
        }
    }

    private let baseURL: URL
    private let identity: DJConnectIdentity
    private let tokenStore: DJConnectTokenStore
    private let session: URLSession
    private var cachedSession: CachedSession?

    public init(
        baseURL: URL,
        identity: DJConnectIdentity,
        tokenStore: DJConnectTokenStore,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.identity = identity
        self.tokenStore = tokenStore
        self.session = session
    }

    public func accessToken() async throws -> String? {
        let now = Date()
        if let cachedSession, cachedSession.isValid(now: now) {
            return cachedSession.accessToken
        }

        let client = DJConnectClient(
            baseURL: baseURL,
            identity: identity,
            tokenStore: tokenStore,
            session: session,
            webSocketFastPath: nil
        )
        let response = try await client.webSocketSession()
        guard let accessToken = response.resolvedAccessToken else {
            return nil
        }
        cachedSession = CachedSession(accessToken: accessToken, expiresAt: response.resolvedExpiryDate)
        return accessToken
    }

    public func invalidate() {
        cachedSession = nil
    }

    public nonisolated var auth: DJConnectHomeAssistantWebSocketAuth {
        DJConnectHomeAssistantWebSocketAuth { [weak self] in
            try await self?.accessToken()
        }
    }
}
