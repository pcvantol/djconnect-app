import Foundation

/// The one live, authenticated owner transport for a DJ Session Broadcast.
/// It reconnects after transient socket failures and always reapplies the
/// server snapshot before delivering incremental Broadcast events.
public actor DJConnectSessionBroadcastTransport {
    public typealias SnapshotHandler = @Sendable (DJConnectSessionBroadcastSubscription) -> Void
    public typealias EventHandler = @Sendable (DJConnectSessionBroadcastEvent) -> Void
    public typealias TerminationHandler = @Sendable () -> Void

    private let baseURL: URL
    private let auth: DJConnectHomeAssistantWebSocketAuth
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var socket: URLSessionWebSocketTask?
    private var runTask: Task<Void, Never>?
    private var shouldRun = false

    public init(
        baseURL: URL,
        auth: DJConnectHomeAssistantWebSocketAuth,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.auth = auth
        self.session = session
    }

    public func start(
        sessionID: String,
        identity: DJConnectAPIIdentity,
        onSnapshot: @escaping SnapshotHandler,
        onEvent: @escaping EventHandler,
        onTerminated: @escaping TerminationHandler
    ) {
        stop()
        shouldRun = true
        runTask = Task { [weak self] in
            await self?.run(
                sessionID: sessionID,
                identity: identity,
                onSnapshot: onSnapshot,
                onEvent: onEvent,
                onTerminated: onTerminated
            )
        }
    }

    public func stop() {
        shouldRun = false
        runTask?.cancel()
        runTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    private func run(
        sessionID: String,
        identity: DJConnectAPIIdentity,
        onSnapshot: @escaping SnapshotHandler,
        onEvent: @escaping EventHandler,
        onTerminated: @escaping TerminationHandler
    ) async {
        var retryDelay: UInt64 = 1_000_000_000
        while shouldRun, !Task.isCancelled {
            do {
                try await connect()
                let subscription = try await subscribe(sessionID: sessionID, identity: identity)
                onSnapshot(subscription)
                retryDelay = 1_000_000_000
                while shouldRun, !Task.isCancelled {
                    let event = try await receiveEvent()
                    onEvent(event)
                    if event.eventType == "runtime_ended" || event.eventType == "broadcast_stopped" {
                        stop()
                        onTerminated()
                        return
                    }
                }
            } catch {
                socket?.cancel(with: .goingAway, reason: nil)
                socket = nil
                if error is DJConnectSessionBroadcastEndedError {
                    stop()
                    onTerminated()
                    return
                }
                guard shouldRun, !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: retryDelay)
                retryDelay = min(retryDelay * 2, 15_000_000_000)
            }
        }
    }

    private func connect() async throws {
        guard socket == nil else { return }
        guard let token = try await auth.accessToken()?
            .trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            throw DJConnectError.routeMissing(message: "Home Assistant WebSocket auth token is unavailable")
        }
        let task = session.webSocketTask(with: try DJConnectHomeAssistantWebSocketFastPath.websocketURL(from: baseURL))
        socket = task
        task.resume()
        let required: DJConnectSessionBroadcastAuthMessage = try await receive(DJConnectSessionBroadcastAuthMessage.self)
        guard required.type == "auth_required" else { throw DJConnectError.invalidResponse }
        try await send(DJConnectSessionBroadcastAuthRequest(type: "auth", accessToken: token))
        let accepted: DJConnectSessionBroadcastAuthMessage = try await receive(DJConnectSessionBroadcastAuthMessage.self)
        guard accepted.type == "auth_ok" else { throw DJConnectError.network(message: "Home Assistant WebSocket auth failed") }
    }

    private func subscribe(sessionID: String, identity: DJConnectAPIIdentity) async throws -> DJConnectSessionBroadcastSubscription {
        try await send(DJConnectSessionBroadcastSubscribeRequest(sessionID: sessionID, identity: identity))
        let envelope: DJConnectSessionBroadcastResultEnvelope<DJConnectSessionBroadcastSubscription> = try await receive()
        guard envelope.success, let result = envelope.result else {
            if envelope.error?.code == "active_session_not_found" {
                throw DJConnectSessionBroadcastEndedError()
            }
            throw DJConnectError.server(statusCode: 200, message: envelope.error?.message ?? envelope.error?.code)
        }
        return result
    }

    private func receiveEvent() async throws -> DJConnectSessionBroadcastEvent {
        let envelope: DJConnectSessionBroadcastEventEnvelope = try await receive()
        guard envelope.type == "event", envelope.event?.eventType == "djconnect/session/broadcast", let event = envelope.event?.data else {
            throw DJConnectError.invalidResponse
        }
        return event
    }

    private func send<T: Encodable>(_ value: T) async throws {
        guard let socket else { throw DJConnectError.network(message: "WebSocket is not connected") }
        let data = try encoder.encode(value)
        try await socket.send(.data(data))
    }

    private func receive<T: Decodable>(_ type: T.Type = T.self) async throws -> T {
        guard let socket else { throw DJConnectError.network(message: "WebSocket is not connected") }
        let message = try await socket.receive()
        let data: Data
        switch message {
        case let .data(value): data = value
        case let .string(value): data = Data(value.utf8)
        @unknown default: throw DJConnectError.invalidResponse
        }
        return try decoder.decode(T.self, from: data)
    }
}

private struct DJConnectSessionBroadcastAuthMessage: Decodable { var type: String }
private struct DJConnectSessionBroadcastAuthRequest: Encodable {
    var type: String
    var accessToken: String
    enum CodingKeys: String, CodingKey { case type; case accessToken = "access_token" }
}
private struct DJConnectSessionBroadcastSubscribeRequest: Encodable {
    let id = 1
    let type = "djconnect/session/broadcast/subscribe"
    var sessionID: String
    var identity: DJConnectAPIIdentity
    var deviceID: String
    var clientType: DJConnectClientType
    var clientID: String
    var deviceName: String
    var deviceToken: String?
    init(sessionID: String, identity: DJConnectAPIIdentity) {
        self.sessionID = sessionID; self.identity = identity; deviceID = identity.deviceID; clientType = identity.clientType; clientID = identity.clientID; deviceName = identity.deviceName; deviceToken = identity.deviceToken
    }
    enum CodingKeys: String, CodingKey { case id, type, identity; case sessionID = "session_id"; case deviceID = "device_id"; case clientType = "client_type"; case clientID = "client_id"; case deviceName = "device_name"; case deviceToken = "device_token" }
}
private struct DJConnectSessionBroadcastError: Decodable { var code: String?; var message: String? }
private struct DJConnectSessionBroadcastEndedError: Error {}
private struct DJConnectSessionBroadcastResultEnvelope<Result: Decodable>: Decodable { var success: Bool; var result: Result?; var error: DJConnectSessionBroadcastError? }
private struct DJConnectSessionBroadcastEventEnvelope: Decodable { struct Event: Decodable { var eventType: String; var data: DJConnectSessionBroadcastEvent; enum CodingKeys: String, CodingKey { case eventType = "event_type"; case data } }; var type: String; var event: Event? }
