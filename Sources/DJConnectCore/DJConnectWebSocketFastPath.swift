import Foundation

public enum DJConnectFastPathRoute: String, CaseIterable, Sendable {
    case command = "djconnect/command"
    case askDJMessage = "djconnect/ask_dj/message"
    case trackInsight = "djconnect/track_insight"
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
    func supports(_ route: DJConnectFastPathRoute) async -> Bool
    func command<T: Decodable & Sendable>(_ payload: DJConnectCommandPayload, token: String, responseType: T.Type) async throws -> T
    func askDJMessage(_ payload: DJConnectAskDJRequest, token: String) async throws -> DJConnectAskDJMessageResponse
    func trackInsight(_ payload: DJConnectTrackInsightRequest, identity: DJConnectIdentity, token: String) async throws -> TrackInsight
}

public actor DJConnectHomeAssistantWebSocketFastPath: DJConnectWebSocketFastPathTransport {
    public let baseURL: URL

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var task: URLSessionWebSocketTask?
    private var nextID = 1
    private var commands: Set<String> = []
    private var capabilitiesLoadedAt: Date?
    private var unhealthyUntil: Date?
    private var lastError: String?

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
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

    public func supports(_ route: DJConnectFastPathRoute) async -> Bool {
        commands.contains(route.rawValue)
    }

    public func command<T: Decodable & Sendable>(
        _ payload: DJConnectCommandPayload,
        token: String,
        responseType: T.Type
    ) async throws -> T {
        guard try await ensureCapabilities(token: token).contains(.command) else {
            throw DJConnectError.routeMissing(message: "WebSocket command capability unavailable")
        }
        let request = DJConnectWebSocketCommandMessage(id: allocateID(), payload: payload, deviceToken: token)
        return try await sendResult(request, timeout: Self.timeout(for: payload.command), responseType: T.self)
    }

    public func askDJMessage(_ payload: DJConnectAskDJRequest, token: String) async throws -> DJConnectAskDJMessageResponse {
        guard try await ensureCapabilities(token: token).contains(.askDJMessage) else {
            throw DJConnectError.routeMissing(message: "WebSocket Ask DJ capability unavailable")
        }
        let request = DJConnectWebSocketAskDJMessage(id: allocateID(), payload: payload, deviceToken: token)
        return try await sendResult(request, timeout: 15, responseType: DJConnectAskDJMessageResponse.self)
    }

    public func trackInsight(
        _ payload: DJConnectTrackInsightRequest,
        identity: DJConnectIdentity,
        token: String
    ) async throws -> TrackInsight {
        guard try await ensureCapabilities(token: token).contains(.trackInsight) else {
            throw DJConnectError.routeMissing(message: "WebSocket Track Insight capability unavailable")
        }
        let request = DJConnectWebSocketTrackInsightMessage(id: allocateID(), identity: identity, payload: payload, deviceToken: token)
        let response: TrackInsightEndpointResponse = try await sendResult(request, timeout: 15, responseType: TrackInsightEndpointResponse.self)
        guard response.success != false, let insight = response.trackInsightValue else {
            throw DJConnectError.trackInsightUnavailable(code: response.error, message: response.message)
        }
        return insight
    }

    private func ensureCapabilities(token: String) async throws -> Set<DJConnectFastPathRoute> {
        if let unhealthyUntil, unhealthyUntil > Date() {
            throw DJConnectError.network(message: "WebSocket fast path is backing off")
        }
        if let capabilitiesLoadedAt, Date().timeIntervalSince(capabilitiesLoadedAt) < 60 {
            return Set(commands.compactMap(DJConnectFastPathRoute.init(rawValue:)))
        }
        try await connectIfNeeded(token: token)
        let request = DJConnectWebSocketTypeMessage(id: allocateID(), type: "djconnect/capabilities")
        let response: DJConnectWebSocketCapabilitiesResponse = try await sendResult(request, timeout: 5, responseType: DJConnectWebSocketCapabilitiesResponse.self)
        commands = Set(response.commands)
        capabilitiesLoadedAt = Date()
        return Set(response.commands.compactMap(DJConnectFastPathRoute.init(rawValue:)))
    }

    private func connectIfNeeded(token: String) async throws {
        if task != nil {
            return
        }
        do {
            let websocketURL = try Self.websocketURL(from: baseURL)
            let task = session.webSocketTask(with: websocketURL)
            self.task = task
            task.resume()
            let authRequired: DJConnectWebSocketAuthMessage = try await receive(timeout: 5)
            guard authRequired.type == "auth_required" else {
                throw DJConnectError.invalidResponse
            }
            try await send(DJConnectWebSocketAuthRequest(type: "auth", accessToken: token))
            let authResponse: DJConnectWebSocketAuthMessage = try await receive(timeout: 5)
            guard authResponse.type == "auth_ok" else {
                throw DJConnectError.authStale(statusCode: 401, message: "WebSocket auth failed")
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
                data = Data(text.utf8)
            case let .data(value):
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

    private static func redactedError(_ error: Error) -> String {
        let raw = error.localizedDescription
        return raw
            .replacingOccurrences(of: #"Bearer\s+[A-Za-z0-9._~+/=-]+"#, with: "Bearer [redacted]", options: .regularExpression)
            .replacingOccurrences(of: #"(device_token|access_token|token)[^,\s]*"#, with: "$1=[redacted]", options: .regularExpression)
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
    var commands: [String]
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
    var deviceID: String
    var clientType: DJConnectClientType
    var clientID: String
    var deviceName: String
    var deviceToken: String
    var command: String
    var value: DJConnectCommandValue?
    var play: Bool?

    init(id: Int, payload: DJConnectCommandPayload, deviceToken: String) {
        self.id = id
        deviceID = payload.deviceID
        clientType = payload.clientType
        clientID = payload.clientID
        deviceName = payload.deviceName
        self.deviceToken = deviceToken
        command = payload.command
        value = payload.value
        play = payload.play
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case deviceID = "device_id"
        case clientType = "client_type"
        case clientID = "client_id"
        case deviceName = "device_name"
        case deviceToken = "device_token"
        case command
        case value
        case play
    }
}

private struct DJConnectWebSocketAskDJMessage: Encodable {
    var id: Int
    var type = DJConnectFastPathRoute.askDJMessage.rawValue
    var deviceID: String
    var clientType: DJConnectClientType
    var clientID: String
    var deviceName: String
    var deviceToken: String
    var clientMessageID: String?
    var text: String
    var mood: Int?
    var musicDNAKey: String?
    var audioResponse: DJConnectAskDJRequest.AudioResponse?

    init(id: Int, payload: DJConnectAskDJRequest, deviceToken: String) {
        self.id = id
        deviceID = payload.deviceID
        clientType = payload.clientType
        clientID = payload.clientID
        deviceName = payload.deviceName
        self.deviceToken = deviceToken
        clientMessageID = payload.clientMessageID
        text = payload.text
        mood = payload.mood
        musicDNAKey = payload.musicDNAKey
        audioResponse = payload.audioResponse
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
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
    }
}

private struct DJConnectWebSocketTrackInsightMessage: Encodable {
    var id: Int
    var type = DJConnectFastPathRoute.trackInsight.rawValue
    var deviceID: String
    var clientType: DJConnectClientType
    var clientID: String
    var deviceName: String
    var deviceToken: String
    var title: String?
    var artist: String?
    var album: String?
    var entityID: String?
    var playerID: String?
    var musicBackend: String?
    var locale: String?
    var forceRefresh: Bool
    var includeVisualProfile: Bool

    init(id: Int, identity: DJConnectIdentity, payload: DJConnectTrackInsightRequest, deviceToken: String) {
        self.id = id
        deviceID = identity.deviceID
        clientType = identity.clientType
        clientID = identity.deviceID
        deviceName = identity.deviceName
        self.deviceToken = deviceToken
        title = payload.title
        artist = payload.artist
        album = payload.album
        entityID = payload.entityID
        playerID = payload.playerID
        musicBackend = payload.musicBackend
        locale = payload.locale
        forceRefresh = payload.forceRefresh
        includeVisualProfile = payload.includeVisualProfile
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case deviceID = "device_id"
        case clientType = "client_type"
        case clientID = "client_id"
        case deviceName = "device_name"
        case deviceToken = "device_token"
        case title
        case artist
        case album
        case entityID = "entity_id"
        case playerID = "player_id"
        case musicBackend = "music_backend"
        case locale
        case forceRefresh = "force_refresh"
        case includeVisualProfile = "include_visual_profile"
    }
}
