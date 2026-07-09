import Foundation

public enum DJConnectFastPathRoute: String, CaseIterable, Sendable {
    case command = "djconnect/command"
    case askDJMessage = "djconnect/ask_dj/message"
    case askDJHistory = "djconnect/ask_dj/history"
    case askDJHistoryClear = "djconnect/ask_dj/history/clear"
    case askDJHistoryState = "djconnect/ask_dj/history/state"
    case musicDNAProfile = "djconnect/music_dna/profile"
    case musicDNASettings = "djconnect/music_dna/settings"
    case musicDNAClear = "djconnect/music_dna/clear"
    case musicDiscoveryFeed = "djconnect/music_discovery/feed"
    case musicDiscoveryRefresh = "djconnect/music_discovery/refresh"
    case musicDiscoveryPlay = "djconnect/music_discovery/play"
    case musicDiscoveryFeedback = "djconnect/music_discovery/feedback"
    case trackInsight = "djconnect/track_insight"
    case vibeCast = "djconnect/vibecast"
}

public struct DJConnectHomeAssistantWebSocketAuth: Sendable {
    public var accessToken: @Sendable () async throws -> String?

    public init(accessToken: @escaping @Sendable () async throws -> String?) {
        self.accessToken = accessToken
    }
}

public struct DJConnectFastPathDiagnostics: Equatable, Sendable {
    public var fastPathTransport: String
    public var websocketConnected: Bool
    public var lastWebSocketError: String?
    public var lastCapabilityRefresh: Date?
    public var websocketCommands: [String]

    public init(
        fastPathTransport: String = "http",
        websocketConnected: Bool = false,
        lastWebSocketError: String? = nil,
        lastCapabilityRefresh: Date? = nil,
        websocketCommands: [String] = []
    ) {
        self.fastPathTransport = fastPathTransport
        self.websocketConnected = websocketConnected
        self.lastWebSocketError = lastWebSocketError
        self.lastCapabilityRefresh = lastCapabilityRefresh
        self.websocketCommands = websocketCommands
    }
}

public protocol DJConnectWebSocketFastPathTransport: Sendable {
    var diagnostics: DJConnectFastPathDiagnostics { get async }
    func prepare() async throws
    func supports(_ route: DJConnectFastPathRoute) async -> Bool
    func command<T: Decodable & Sendable>(_ payload: DJConnectCommandPayload, identity: DJConnectAPIIdentity, responseType: T.Type) async throws -> T
    func askDJMessage(_ payload: DJConnectAskDJRequest, identity: DJConnectAPIIdentity) async throws -> DJConnectAskDJMessageResponse
    func askDJHistory(identity: DJConnectAPIIdentity, sinceRevision: Int?) async throws -> DJConnectAskDJHistoryResponse
    func clearAskDJHistory(identity: DJConnectAPIIdentity, musicDNAKey: String?) async throws -> DJConnectAskDJHistoryResponse
    func musicDNAProfile(identity: DJConnectAPIIdentity, mood: Int?, musicDNAKey: String?, language: String?) async throws -> DJConnectMusicDNAProfileResponse
    func setMusicDNAEnabled(_ enabled: Bool, identity: DJConnectAPIIdentity, mood: Int?, musicDNAKey: String?, language: String?) async throws -> DJConnectMusicDNAProfileResponse
    func clearMusicDNA(identity: DJConnectAPIIdentity, mood: Int?, musicDNAKey: String?, language: String?) async throws -> DJConnectMusicDNAProfileResponse
    func musicDiscoveryFeed(identity: DJConnectAPIIdentity, musicDNAKey: String?, language: String?) async throws -> DJConnectMusicDiscoveryResponse
    func refreshMusicDiscovery(identity: DJConnectAPIIdentity, musicDNAKey: String?, language: String?) async throws -> DJConnectMusicDiscoveryResponse
    func playMusicDiscoveryItem(_ payload: DJConnectMusicDiscoveryPlayRequest, identity: DJConnectAPIIdentity) async throws -> DJConnectCommandResponse
    func sendMusicDiscoveryFeedback(_ payload: DJConnectMusicDiscoveryFeedbackRequest, identity: DJConnectAPIIdentity) async throws -> DJConnectCommandResponse
    func trackInsight(_ payload: DJConnectTrackInsightRequest, identity: DJConnectAPIIdentity) async throws -> TrackInsight
    func vibeCast(_ payload: DJConnectVibeCastRequest, identity: DJConnectAPIIdentity) async throws -> DJConnectVibeCastResponse
}

public actor DJConnectHomeAssistantWebSocketFastPath: DJConnectWebSocketFastPathTransport {
    public let baseURL: URL

    private let session: URLSession
    private let homeAssistantAuth: DJConnectHomeAssistantWebSocketAuth
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var task: URLSessionWebSocketTask?
    private var nextID = 1
    private var commands: Set<String> = []
    private var capabilitiesLoadedAt: Date?
    private var unhealthyUntil: Date?
    private var lastError: String?

    public init(
        baseURL: URL,
        homeAssistantAuth: DJConnectHomeAssistantWebSocketAuth,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.homeAssistantAuth = homeAssistantAuth
        self.session = session
    }

    public var diagnostics: DJConnectFastPathDiagnostics {
        DJConnectFastPathDiagnostics(
            fastPathTransport: task == nil ? "http" : "websocket",
            websocketConnected: task != nil,
            lastWebSocketError: lastError,
            lastCapabilityRefresh: capabilitiesLoadedAt,
            websocketCommands: commands.sorted()
        )
    }

    public func prepare() async throws {
        _ = try await ensureCapabilities()
    }

    public func supports(_ route: DJConnectFastPathRoute) async -> Bool {
        commands.contains(route.rawValue)
    }

    public func command<T: Decodable & Sendable>(
        _ payload: DJConnectCommandPayload,
        identity: DJConnectAPIIdentity,
        responseType: T.Type
    ) async throws -> T {
        guard try await ensureCapabilities().contains(.command) else {
            throw DJConnectError.routeMissing(message: "WebSocket command capability unavailable")
        }
        let request = DJConnectWebSocketCommandMessage(id: allocateID(), identity: identity, payload: payload)
        return try await sendResult(request, timeout: Self.timeout(for: payload.command), responseType: T.self)
    }

    public func askDJMessage(_ payload: DJConnectAskDJRequest, identity: DJConnectAPIIdentity) async throws -> DJConnectAskDJMessageResponse {
        guard try await ensureCapabilities().contains(.askDJMessage) else {
            throw DJConnectError.routeMissing(message: "WebSocket Ask DJ capability unavailable")
        }
        let request = DJConnectWebSocketAskDJMessage(id: allocateID(), identity: identity, payload: payload)
        return try await sendResult(request, timeout: 15, responseType: DJConnectAskDJMessageResponse.self)
    }

    public func askDJHistory(
        identity: DJConnectAPIIdentity,
        sinceRevision: Int?
    ) async throws -> DJConnectAskDJHistoryResponse {
        guard try await ensureCapabilities().contains(.askDJHistory) else {
            throw DJConnectError.routeMissing(message: "WebSocket Ask DJ history capability unavailable")
        }
        let request = DJConnectWebSocketAskDJHistoryMessage(
            id: allocateID(),
            type: DJConnectFastPathRoute.askDJHistory.rawValue,
            identity: identity,
            sinceRevision: sinceRevision,
            musicDNAKey: nil
        )
        return try await sendResult(request, timeout: 10, responseType: DJConnectAskDJHistoryResponse.self)
    }

    public func clearAskDJHistory(
        identity: DJConnectAPIIdentity,
        musicDNAKey: String?
    ) async throws -> DJConnectAskDJHistoryResponse {
        guard try await ensureCapabilities().contains(.askDJHistoryClear) else {
            throw DJConnectError.routeMissing(message: "WebSocket Ask DJ clear-history capability unavailable")
        }
        let request = DJConnectWebSocketAskDJHistoryMessage(
            id: allocateID(),
            type: DJConnectFastPathRoute.askDJHistoryClear.rawValue,
            identity: identity,
            sinceRevision: nil,
            musicDNAKey: musicDNAKey
        )
        return try await sendResult(request, timeout: 10, responseType: DJConnectAskDJHistoryResponse.self)
    }

    public func musicDNAProfile(
        identity: DJConnectAPIIdentity,
        mood: Int?,
        musicDNAKey: String?,
        language: String?
    ) async throws -> DJConnectMusicDNAProfileResponse {
        guard try await ensureCapabilities().contains(.musicDNAProfile) else {
            throw DJConnectError.routeMissing(message: "WebSocket Music DNA profile capability unavailable")
        }
        let payload = DJConnectMusicDNAFastPathPayload(mood: mood, musicDNAKey: musicDNAKey, language: language)
        let request = DJConnectWebSocketMusicDNARequestMessage(
            id: allocateID(),
            type: DJConnectFastPathRoute.musicDNAProfile.rawValue,
            identity: identity,
            payload: payload
        )
        return try await sendResult(request, timeout: 10, responseType: DJConnectMusicDNAProfileResponse.self)
    }

    public func setMusicDNAEnabled(
        _ enabled: Bool,
        identity: DJConnectAPIIdentity,
        mood: Int?,
        musicDNAKey: String?,
        language: String?
    ) async throws -> DJConnectMusicDNAProfileResponse {
        guard try await ensureCapabilities().contains(.musicDNASettings) else {
            throw DJConnectError.routeMissing(message: "WebSocket Music DNA settings capability unavailable")
        }
        let payload = DJConnectMusicDNAFastPathPayload(enabled: enabled, mood: mood, musicDNAKey: musicDNAKey, language: language)
        let request = DJConnectWebSocketMusicDNARequestMessage(
            id: allocateID(),
            type: DJConnectFastPathRoute.musicDNASettings.rawValue,
            identity: identity,
            payload: payload
        )
        return try await sendResult(request, timeout: 10, responseType: DJConnectMusicDNAProfileResponse.self)
    }

    public func clearMusicDNA(
        identity: DJConnectAPIIdentity,
        mood: Int?,
        musicDNAKey: String?,
        language: String?
    ) async throws -> DJConnectMusicDNAProfileResponse {
        guard try await ensureCapabilities().contains(.musicDNAClear) else {
            throw DJConnectError.routeMissing(message: "WebSocket Music DNA clear capability unavailable")
        }
        let payload = DJConnectMusicDNAFastPathPayload(mood: mood, musicDNAKey: musicDNAKey, language: language)
        let request = DJConnectWebSocketMusicDNARequestMessage(
            id: allocateID(),
            type: DJConnectFastPathRoute.musicDNAClear.rawValue,
            identity: identity,
            payload: payload
        )
        return try await sendResult(request, timeout: 10, responseType: DJConnectMusicDNAProfileResponse.self)
    }

    public func musicDiscoveryFeed(
        identity: DJConnectAPIIdentity,
        musicDNAKey: String?,
        language: String?
    ) async throws -> DJConnectMusicDiscoveryResponse {
        guard try await ensureCapabilities().contains(.musicDiscoveryFeed) else {
            throw DJConnectError.routeMissing(message: "WebSocket Music Discovery feed capability unavailable")
        }
        let request = DJConnectWebSocketMusicDiscoveryRequestMessage(
            id: allocateID(),
            type: DJConnectFastPathRoute.musicDiscoveryFeed.rawValue,
            identity: identity,
            musicDNAKey: musicDNAKey,
            language: language
        )
        return try await sendResult(request, timeout: 10, responseType: DJConnectMusicDiscoveryResponse.self)
    }

    public func refreshMusicDiscovery(
        identity: DJConnectAPIIdentity,
        musicDNAKey: String?,
        language: String?
    ) async throws -> DJConnectMusicDiscoveryResponse {
        guard try await ensureCapabilities().contains(.musicDiscoveryRefresh) else {
            throw DJConnectError.routeMissing(message: "WebSocket Music Discovery refresh capability unavailable")
        }
        let request = DJConnectWebSocketMusicDiscoveryRequestMessage(
            id: allocateID(),
            type: DJConnectFastPathRoute.musicDiscoveryRefresh.rawValue,
            identity: identity,
            musicDNAKey: musicDNAKey,
            language: language
        )
        return try await sendResult(request, timeout: 10, responseType: DJConnectMusicDiscoveryResponse.self)
    }

    public func playMusicDiscoveryItem(
        _ payload: DJConnectMusicDiscoveryPlayRequest,
        identity: DJConnectAPIIdentity
    ) async throws -> DJConnectCommandResponse {
        guard try await ensureCapabilities().contains(.musicDiscoveryPlay) else {
            throw DJConnectError.routeMissing(message: "WebSocket Music Discovery play capability unavailable")
        }
        let request = DJConnectWebSocketMusicDiscoveryActionMessage(
            id: allocateID(),
            type: DJConnectFastPathRoute.musicDiscoveryPlay.rawValue,
            identity: identity,
            payload: payload
        )
        return try await sendResult(request, timeout: 10, responseType: DJConnectCommandResponse.self)
    }

    public func sendMusicDiscoveryFeedback(
        _ payload: DJConnectMusicDiscoveryFeedbackRequest,
        identity: DJConnectAPIIdentity
    ) async throws -> DJConnectCommandResponse {
        guard try await ensureCapabilities().contains(.musicDiscoveryFeedback) else {
            throw DJConnectError.routeMissing(message: "WebSocket Music Discovery feedback capability unavailable")
        }
        let request = DJConnectWebSocketMusicDiscoveryActionMessage(
            id: allocateID(),
            type: DJConnectFastPathRoute.musicDiscoveryFeedback.rawValue,
            identity: identity,
            payload: payload
        )
        return try await sendResult(request, timeout: 10, responseType: DJConnectCommandResponse.self)
    }

    public func trackInsight(
        _ payload: DJConnectTrackInsightRequest,
        identity: DJConnectAPIIdentity
    ) async throws -> TrackInsight {
        guard try await ensureCapabilities().contains(.trackInsight) else {
            throw DJConnectError.routeMissing(message: "WebSocket Track Insight capability unavailable")
        }
        let request = DJConnectWebSocketTrackInsightMessage(id: allocateID(), identity: identity, payload: payload)
        let response: TrackInsightEndpointResponse = try await sendResult(request, timeout: 15, responseType: TrackInsightEndpointResponse.self)
        guard response.success != false, let insight = response.trackInsightValue(
            fallbackTitle: payload.title,
            fallbackArtist: payload.artist,
            fallbackArtwork: payload.artworkURL,
            fallbackDurationMS: payload.durationMS,
            fallbackProgressMS: payload.progressMS
        ) else {
            throw DJConnectError.trackInsightUnavailable(code: response.error, message: response.message)
        }
        return insight
    }

    public func vibeCast(
        _ payload: DJConnectVibeCastRequest,
        identity: DJConnectAPIIdentity
    ) async throws -> DJConnectVibeCastResponse {
        guard try await ensureCapabilities().contains(.vibeCast) else {
            throw DJConnectError.routeMissing(message: "WebSocket VibeCast capability unavailable")
        }
        let request = DJConnectWebSocketVibeCastMessage(id: allocateID(), identity: identity, payload: payload)
        return try await sendResult(request, timeout: 10, responseType: DJConnectVibeCastResponse.self)
    }

    private func ensureCapabilities() async throws -> Set<DJConnectFastPathRoute> {
        if let unhealthyUntil, unhealthyUntil > Date() {
            throw DJConnectError.network(message: "WebSocket fast path is backing off")
        }
        if let capabilitiesLoadedAt, Date().timeIntervalSince(capabilitiesLoadedAt) < 60 {
            return Set(commands.compactMap(DJConnectFastPathRoute.init(rawValue:)))
        }
        try await connectIfNeeded()
        let request = DJConnectWebSocketTypeMessage(id: allocateID(), type: "djconnect/capabilities")
        let response: DJConnectWebSocketCapabilitiesResponse = try await sendResult(request, timeout: 5, responseType: DJConnectWebSocketCapabilitiesResponse.self)
        guard response.websocketSupported == true, response.transports?.websocket == true else {
            throw DJConnectError.routeMissing(message: "Home Assistant did not advertise DJConnect WebSocket transport support")
        }
        commands = Set(response.advertisedCommands)
        capabilitiesLoadedAt = Date()
        return Set(response.advertisedCommands.compactMap(DJConnectFastPathRoute.init(rawValue:)))
    }

    private func connectIfNeeded() async throws {
        if task != nil {
            return
        }
        do {
            guard Self.isLocalHomeAssistantURL(baseURL) else {
                throw DJConnectError.routeMissing(message: "WebSocket fast path is local-only")
            }
            guard let homeAssistantToken = try await homeAssistantAuth.accessToken()?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !homeAssistantToken.isEmpty else {
                throw DJConnectError.routeMissing(message: "Home Assistant WebSocket auth token is unavailable")
            }
            let websocketURL = try Self.websocketURL(from: baseURL)
            let task = session.webSocketTask(with: websocketURL)
            self.task = task
            task.resume()
            let authRequired: DJConnectWebSocketAuthMessage = try await receive(timeout: 5)
            guard authRequired.type == "auth_required" else {
                throw DJConnectError.invalidResponse
            }
            try await send(DJConnectWebSocketAuthRequest(type: "auth", accessToken: homeAssistantToken))
            let authResponse: DJConnectWebSocketAuthMessage = try await receive(timeout: 5)
            guard authResponse.type == "auth_ok" else {
                throw DJConnectError.network(message: "Home Assistant WebSocket auth failed")
            }
        } catch {
            markUnhealthy(error)
            throw error
        }
    }

    private func sendResult<T: Encodable, U: Decodable & Sendable>(
        _ message: T,
        timeout: TimeInterval,
        responseType: U.Type
    ) async throws -> U {
        do {
            guard task != nil else {
                throw DJConnectError.network(message: "WebSocket is not connected")
            }
            try await send(message)
            let envelope: DJConnectWebSocketResultEnvelope<U> = try await receive(timeout: timeout)
            guard envelope.success else {
                throw DJConnectError.server(statusCode: 200, message: envelope.error?.message ?? envelope.error?.code)
            }
            guard let result = envelope.result else {
                throw DJConnectError.invalidResponse
            }
            return result
        } catch {
            markUnhealthy(error)
            throw error
        }
    }

    private func send<T: Encodable>(_ value: T) async throws {
        guard let task else {
            throw DJConnectError.network(message: "WebSocket is not connected")
        }
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw DJConnectError.invalidResponse
        }
        try await task.send(.string(text))
    }

    private func receive<T: Decodable & Sendable>(_ type: T.Type = T.self, timeout: TimeInterval) async throws -> T {
        try await withTimeout(seconds: timeout) {
            guard let task = await self.task else {
                throw DJConnectError.network(message: "WebSocket is not connected")
            }
            let message = try await task.receive()
            let data: Data
            switch message {
            case let .string(text):
                try DJConnectIncomingPayloadLimiter.validate(text)
                data = Data(text.utf8)
            case let .data(value):
                try DJConnectIncomingPayloadLimiter.validate(value)
                data = value
            @unknown default:
                throw DJConnectError.invalidResponse
            }
            return try self.decoder.decode(T.self, from: data)
        }
    }

    private func allocateID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    private func markUnhealthy(_ error: Error) {
        lastError = Self.redactedError(error)
        unhealthyUntil = Date().addingTimeInterval(10)
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        commands = []
        capabilitiesLoadedAt = nil
    }

    private static func timeout(for command: String) -> TimeInterval {
        switch command {
        case "play", "pause", "next", "previous", "set_volume", "volume_delta", "set_shuffle", "set_repeat", "set_output":
            2
        default:
            5
        }
    }

    public static func websocketURL(from baseURL: URL) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw DJConnectError.invalidConfiguration("Invalid Home Assistant URL")
        }
        switch components.scheme?.lowercased() {
        case "http":
            components.scheme = "ws"
        case "https":
            components.scheme = "wss"
        default:
            throw DJConnectError.invalidConfiguration("Unsupported Home Assistant URL scheme")
        }
        components.path = "/api/websocket"
        components.query = nil
        guard let url = components.url else {
            throw DJConnectError.invalidConfiguration("Invalid Home Assistant WebSocket URL")
        }
        return url
    }

    public static func isLocalHomeAssistantURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), !host.isEmpty else {
            return false
        }
        if host == "localhost" || host == "homeassistant.local" || host.hasSuffix(".local") {
            return true
        }
        if host.hasPrefix("10.") || host.hasPrefix("192.168.") {
            return true
        }
        let parts = host.split(separator: ".").compactMap { Int($0) }
        if parts.count == 4, parts[0] == 172, (16...31).contains(parts[1]) {
            return true
        }
        if host.hasPrefix("127.") || host == "::1" {
            return true
        }
        return false
    }

    private static func redactedError(_ error: Error) -> String {
        if let error = error as? DJConnectError {
            return DJConnectLogRedactor.redactText(describe(error))
        }
        return DJConnectLogRedactor.redactText(error.localizedDescription)
    }

    private static func describe(_ error: DJConnectError) -> String {
        switch error {
        case let .backendUnavailable(message):
            message ?? "Backend unavailable"
        case let .authStale(statusCode, message):
            message ?? "Authentication stale (HTTP \(statusCode))"
        case let .routeMissing(message):
            message ?? "Route missing"
        case let .versionMismatch(mismatch):
            "Version mismatch: \(mismatch)"
        case let .notConfigured(message):
            message ?? "DJConnect is not configured"
        case let .server(statusCode, message):
            message ?? "Server error (HTTP \(statusCode))"
        case let .decodingFailed(statusCode, endpoint, message):
            message ?? "Decoding failed for \(endpoint) (HTTP \(statusCode))"
        case let .network(message):
            message
        case .invalidResponse:
            "Invalid response"
        case let .invalidConfiguration(message):
            message
        case .missingToken:
            "Missing token"
        case let .pairingFailed(message):
            message ?? "Pairing failed"
        case let .clientTypeMismatch(message, expectedClientType, receivedClientType):
            message ?? "Client type mismatch expected=\(expectedClientType ?? "unknown") received=\(receivedClientType ?? "unknown")"
        case let .trackInsightUnavailable(code, message):
            message ?? code ?? "Track Insight unavailable"
        case let .payloadTooLarge(limitBytes, actualBytes):
            "Payload too large limit=\(limitBytes) actual=\(actualBytes.map(String.init) ?? "unknown")"
        }
    }
}

private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw DJConnectError.network(message: "WebSocket timeout")
        }
        guard let result = try await group.next() else {
            throw DJConnectError.network(message: "WebSocket timeout")
        }
        group.cancelAll()
        return result
    }
}

private struct DJConnectWebSocketAuthMessage: Decodable {
    var type: String
}

private struct DJConnectWebSocketAuthRequest: Encodable {
    var type: String
    var accessToken: String

    enum CodingKeys: String, CodingKey {
        case type
        case accessToken = "access_token"
    }
}

private struct DJConnectWebSocketTypeMessage: Encodable {
    var id: Int
    var type: String
}

private struct DJConnectWebSocketCapabilitiesResponse: Decodable {
    var websocketSupported: Bool?
    var transports: DJConnectWebSocketTransports?
    var commands: [String]
    var features: DJConnectWebSocketFeatures?
    var fallbacks: [String: DJConnectWebSocketFallback]?

    enum CodingKeys: String, CodingKey {
        case websocketSupported = "websocket_supported"
        case transports
        case commands
        case features
        case fallbacks
    }

    var advertisedCommands: [String] {
        var values = Set(commands)
        if features?.musicDiscovery == true || fallbacks?["music_discovery"]?.hasHTTPPath == true {
            values.insert(DJConnectFastPathRoute.musicDiscoveryFeed.rawValue)
            values.insert(DJConnectFastPathRoute.musicDiscoveryRefresh.rawValue)
            values.insert(DJConnectFastPathRoute.musicDiscoveryPlay.rawValue)
        }
        if features?.musicDiscoveryFeedback == true || fallbacks?["music_discovery_feedback"]?.hasHTTPPath == true {
            values.insert(DJConnectFastPathRoute.musicDiscoveryFeedback.rawValue)
        }
        if features?.musicDNA == true || fallbacks?["music_dna"]?.hasHTTPPath == true {
            values.insert(DJConnectFastPathRoute.musicDNAProfile.rawValue)
            values.insert(DJConnectFastPathRoute.musicDNASettings.rawValue)
            values.insert(DJConnectFastPathRoute.musicDNAClear.rawValue)
        }
        return values.sorted()
    }
}

private struct DJConnectWebSocketTransports: Decodable {
    var websocket: Bool?
}

private struct DJConnectWebSocketFeatures: Decodable {
    var musicDNA: Bool?
    var musicDiscovery: Bool?
    var musicDiscoveryFeedback: Bool?

    enum CodingKeys: String, CodingKey {
        case musicDNA = "music_dna"
        case musicDiscovery = "music_discovery"
        case musicDiscoveryFeedback = "music_discovery_feedback"
    }
}

private struct DJConnectWebSocketFallback: Decodable {
    var httpPath: String?
    var httpPaths: [String]?

    enum CodingKeys: String, CodingKey {
        case httpPath = "http_path"
        case httpPaths = "http_paths"
    }

    var hasHTTPPath: Bool {
        httpPath?.isEmpty == false || httpPaths?.isEmpty == false
    }
}

private struct DJConnectWebSocketError: Decodable, Sendable {
    var code: String?
    var message: String?
}

private struct DJConnectWebSocketResultEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    var id: Int?
    var type: String?
    var success: Bool
    var result: T?
    var error: DJConnectWebSocketError?
}

private struct DJConnectWebSocketCommandMessage: Encodable {
    var id: Int
    var type = DJConnectFastPathRoute.command.rawValue
    var identity: DJConnectAPIIdentity
    var payload: DJConnectIdentifiedRequestPayload<DJConnectCommandPayload>
    var deviceID: String
    var clientType: DJConnectClientType
    var clientID: String
    var deviceName: String
    var deviceToken: String?
    var command: String
    var value: DJConnectCommandValue?
    var play: Bool?
    var language: String?

    init(id: Int, identity: DJConnectAPIIdentity, payload: DJConnectCommandPayload) {
        self.id = id
        self.identity = identity
        self.payload = DJConnectIdentifiedRequestPayload(identity: identity, payload: payload, includeNestedPayload: false)
        deviceID = payload.deviceID
        clientType = payload.clientType
        clientID = payload.clientID
        deviceName = payload.deviceName
        deviceToken = identity.deviceToken
        command = payload.command
        value = payload.value
        play = payload.play
        language = payload.language
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case identity
        case payload
        case deviceID = "device_id"
        case clientType = "client_type"
        case clientID = "client_id"
        case deviceName = "device_name"
        case deviceToken = "device_token"
        case command
        case value
        case play
        case language
    }
}

private struct DJConnectWebSocketAskDJMessage: Encodable {
    var id: Int
    var type = DJConnectFastPathRoute.askDJMessage.rawValue
    var identity: DJConnectAPIIdentity
    var payload: DJConnectIdentifiedRequestPayload<DJConnectAskDJRequest>
    var deviceID: String
    var clientType: DJConnectClientType
    var clientID: String
    var deviceName: String
    var deviceToken: String?
    var clientMessageID: String?
    var text: String
    var mood: Int?
    var musicDNAKey: String?
    var audioResponse: DJConnectAskDJRequest.AudioResponse?
    var language: String?

    init(id: Int, identity: DJConnectAPIIdentity, payload: DJConnectAskDJRequest) {
        self.id = id
        self.identity = identity
        self.payload = DJConnectIdentifiedRequestPayload(identity: identity, payload: payload, includeNestedPayload: false)
        deviceID = payload.deviceID
        clientType = payload.clientType
        clientID = payload.clientID
        deviceName = payload.deviceName
        deviceToken = identity.deviceToken
        clientMessageID = payload.clientMessageID
        text = payload.text
        mood = payload.mood
        musicDNAKey = payload.musicDNAKey
        audioResponse = payload.audioResponse
        language = payload.language
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case identity
        case payload
        case deviceID = "device_id"
        case clientType = "client_type"
        case clientID = "client_id"
        case deviceName = "device_name"
        case deviceToken = "device_token"
        case clientMessageID = "client_message_id"
        case text
        case mood
        case musicDNAKey = "music_dna_key"
        case audioResponse = "audio_response"
        case language
    }
}

private struct DJConnectWebSocketAskDJHistoryMessage: Encodable {
    var id: Int
    var type: String
    var identity: DJConnectAPIIdentity
    var payload: DJConnectIdentifiedRequestPayload<DJConnectAskDJHistorySyncPayload>
    var deviceID: String
    var clientType: DJConnectClientType
    var clientID: String
    var deviceName: String
    var deviceToken: String?
    var sinceRevision: Int?
    var musicDNAKey: String?

    init(
        id: Int,
        type: String,
        identity: DJConnectAPIIdentity,
        sinceRevision: Int?,
        musicDNAKey: String?
    ) {
        self.id = id
        self.type = type
        self.identity = identity
        let syncPayload = DJConnectAskDJHistorySyncPayload(sinceRevision: sinceRevision, musicDNAKey: musicDNAKey)
        payload = DJConnectIdentifiedRequestPayload(identity: identity, payload: syncPayload, includeNestedPayload: false)
        deviceID = identity.deviceID
        clientType = identity.clientType
        clientID = identity.deviceID
        deviceName = identity.deviceName
        deviceToken = identity.deviceToken
        self.sinceRevision = sinceRevision
        self.musicDNAKey = musicDNAKey
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case identity
        case payload
        case deviceID = "device_id"
        case clientType = "client_type"
        case clientID = "client_id"
        case deviceName = "device_name"
        case deviceToken = "device_token"
        case sinceRevision = "since_revision"
        case musicDNAKey = "music_dna_key"
    }
}

private struct DJConnectAskDJHistorySyncPayload: Encodable {
    var sinceRevision: Int?
    var musicDNAKey: String?

    enum CodingKeys: String, CodingKey {
        case sinceRevision = "since_revision"
        case musicDNAKey = "music_dna_key"
    }
}

private struct DJConnectWebSocketMusicDiscoveryRequestMessage: Encodable {
    var id: Int
    var type: String
    var identity: DJConnectAPIIdentity
    var payload: DJConnectIdentifiedRequestPayload<DJConnectMusicDiscoveryRefreshPayload>
    var deviceID: String
    var clientType: DJConnectClientType
    var clientID: String
    var deviceName: String
    var deviceToken: String?
    var musicDNAKey: String?
    var language: String?

    init(id: Int, type: String, identity: DJConnectAPIIdentity, musicDNAKey: String?, language: String?) {
        self.id = id
        self.type = type
        self.identity = identity
        let refreshPayload = DJConnectMusicDiscoveryRefreshPayload(musicDNAKey: musicDNAKey, language: language)
        payload = DJConnectIdentifiedRequestPayload(identity: identity, payload: refreshPayload, includeNestedPayload: false)
        deviceID = identity.deviceID
        clientType = identity.clientType
        clientID = identity.clientID
        deviceName = identity.deviceName
        deviceToken = identity.deviceToken
        self.musicDNAKey = musicDNAKey
        self.language = language
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case identity
        case payload
        case deviceID = "device_id"
        case clientType = "client_type"
        case clientID = "client_id"
        case deviceName = "device_name"
        case deviceToken = "device_token"
        case musicDNAKey = "music_dna_key"
        case language
    }
}

private struct DJConnectWebSocketMusicDNARequestMessage<Payload: Encodable>: Encodable {
    var id: Int
    var type: String
    var identity: DJConnectAPIIdentity
    var payload: DJConnectIdentifiedRequestPayload<Payload>
    var deviceID: String
    var clientType: DJConnectClientType
    var clientID: String
    var deviceName: String
    var deviceToken: String?

    init(id: Int, type: String, identity: DJConnectAPIIdentity, payload: Payload) {
        self.id = id
        self.type = type
        self.identity = identity
        self.payload = DJConnectIdentifiedRequestPayload(identity: identity, payload: payload, includeNestedPayload: false)
        deviceID = identity.deviceID
        clientType = identity.clientType
        clientID = identity.clientID
        deviceName = identity.deviceName
        deviceToken = identity.deviceToken
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case identity
        case payload
        case deviceID = "device_id"
        case clientType = "client_type"
        case clientID = "client_id"
        case deviceName = "device_name"
        case deviceToken = "device_token"
    }
}

private struct DJConnectMusicDNAFastPathPayload: Encodable {
    var enabled: Bool?
    var mood: Int?
    var musicDNAKey: String?
    var language: String?

    enum CodingKeys: String, CodingKey {
        case enabled
        case mood
        case musicDNAKey = "music_dna_key"
        case language
    }
}

private struct DJConnectMusicDiscoveryRefreshPayload: Encodable {
    var musicDNAKey: String?
    var language: String?

    enum CodingKeys: String, CodingKey {
        case musicDNAKey = "music_dna_key"
        case language
    }
}

private struct DJConnectWebSocketMusicDiscoveryActionMessage<Payload: Encodable>: Encodable {
    var id: Int
    var type: String
    var identity: DJConnectAPIIdentity
    var payload: DJConnectIdentifiedRequestPayload<Payload>
    var deviceID: String
    var clientType: DJConnectClientType
    var clientID: String
    var deviceName: String
    var deviceToken: String?

    init(id: Int, type: String, identity: DJConnectAPIIdentity, payload: Payload) {
        self.id = id
        self.type = type
        self.identity = identity
        self.payload = DJConnectIdentifiedRequestPayload(identity: identity, payload: payload, includeNestedPayload: false)
        deviceID = identity.deviceID
        clientType = identity.clientType
        clientID = identity.clientID
        deviceName = identity.deviceName
        deviceToken = identity.deviceToken
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case identity
        case payload
        case deviceID = "device_id"
        case clientType = "client_type"
        case clientID = "client_id"
        case deviceName = "device_name"
        case deviceToken = "device_token"
    }
}

private struct DJConnectWebSocketTrackInsightMessage: Encodable {
    var id: Int
    var type = DJConnectFastPathRoute.trackInsight.rawValue
    var identity: DJConnectAPIIdentity
    var payload: DJConnectIdentifiedRequestPayload<DJConnectTrackInsightRequest>
    var deviceID: String
    var clientType: DJConnectClientType
    var clientID: String
    var deviceName: String
    var deviceToken: String?
    var title: String?
    var trackName: String?
    var artist: String?
    var artistName: String?
    var album: String?
    var albumName: String?
    var artworkURL: URL?
    var durationMS: Int?
    var progressMS: Int?
    var entityID: String?
    var playerID: String?
    var musicBackend: String?
    var locale: String?
    var mood: Int?
    var forceRefresh: Bool
    var includeVisualProfile: Bool
    var includeRawResponse: Bool

    init(id: Int, identity: DJConnectAPIIdentity, payload: DJConnectTrackInsightRequest) {
        let normalizedPayload = payload.normalizedForSend(identity: identity)
        self.id = id
        self.identity = identity
        self.payload = DJConnectIdentifiedRequestPayload(identity: identity, payload: normalizedPayload, includeNestedPayload: false)
        deviceID = identity.deviceID
        clientType = identity.clientType
        clientID = identity.deviceID
        deviceName = identity.deviceName
        deviceToken = identity.deviceToken
        title = normalizedPayload.title
        trackName = normalizedPayload.title
        artist = normalizedPayload.artist
        artistName = normalizedPayload.artist
        album = normalizedPayload.album
        albumName = normalizedPayload.album
        artworkURL = normalizedPayload.artworkURL
        durationMS = normalizedPayload.durationMS
        progressMS = normalizedPayload.progressMS
        entityID = normalizedPayload.entityID
        playerID = normalizedPayload.playerID
        musicBackend = normalizedPayload.musicBackend
        locale = normalizedPayload.locale
        mood = normalizedPayload.mood
        forceRefresh = normalizedPayload.forceRefresh
        includeVisualProfile = normalizedPayload.includeVisualProfile
        includeRawResponse = normalizedPayload.includeRawResponse
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case identity
        case payload
        case deviceID = "device_id"
        case clientType = "client_type"
        case clientID = "client_id"
        case deviceName = "device_name"
        case deviceToken = "device_token"
        case title
        case trackName = "track_name"
        case artist
        case artistName = "artist_name"
        case album
        case albumName = "album_name"
        case artworkURL = "artwork_url"
        case durationMS = "duration_ms"
        case progressMS = "progress_ms"
        case entityID = "entity_id"
        case playerID = "player_id"
        case musicBackend = "music_backend"
        case locale
        case mood
        case forceRefresh = "force_refresh"
        case includeVisualProfile = "include_visual_profile"
        case includeRawResponse = "include_raw_response"
    }
}

private struct DJConnectWebSocketVibeCastMessage: Encodable {
    var id: Int
    var type = DJConnectFastPathRoute.vibeCast.rawValue
    var identity: DJConnectAPIIdentity
    var payload: DJConnectIdentifiedRequestPayload<DJConnectVibeCastRequest>
    var deviceID: String
    var clientType: DJConnectClientType
    var clientID: String
    var deviceName: String
    var deviceToken: String?
    var locale: String?
    var language: String?
    var timezone: String?
    var capabilities: [String]

    init(id: Int, identity: DJConnectAPIIdentity, payload: DJConnectVibeCastRequest) {
        self.id = id
        self.identity = identity
        self.payload = DJConnectIdentifiedRequestPayload(identity: identity, payload: payload, includeNestedPayload: false)
        deviceID = identity.deviceID
        clientType = identity.clientType
        clientID = identity.clientID
        deviceName = identity.deviceName
        deviceToken = identity.deviceToken
        locale = payload.locale
        language = payload.language
        timezone = payload.timezone
        capabilities = payload.capabilities
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case identity
        case payload
        case deviceID = "device_id"
        case clientType = "client_type"
        case clientID = "client_id"
        case deviceName = "device_name"
        case deviceToken = "device_token"
        case locale
        case language
        case timezone
        case capabilities
    }
}
