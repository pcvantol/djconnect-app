import Foundation

/// The one live, authenticated owner transport for a DJ Session Broadcast.
/// It reconnects after transient socket failures and always reapplies the
/// server snapshot before delivering incremental Broadcast events.
public actor DJConnectSessionBroadcastTransport {
    public typealias SnapshotHandler = @Sendable (DJConnectSessionBroadcastSubscription) async -> Void
    public typealias EventHandler = @Sendable (DJConnectSessionBroadcastEvent) async -> Void
    public typealias TerminationHandler = @Sendable () async -> Void
    public typealias AuthorityHandler = @Sendable (String) async -> Void

    private let baseURL: URL
    private let auth: DJConnectHomeAssistantWebSocketAuth?
    private let discover: (@Sendable () async throws -> DJConnectPairedOwnerLiveCapability?)?
    private let pairedToken: (@Sendable () throws -> String?)?
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
        self.discover = nil; self.pairedToken = nil
        self.session = session
    }

    /// Production paired mode never falls back to an HA credential issuer.
    public init(baseURL: URL, session: URLSession = .shared,
                discover: @escaping @Sendable () async throws -> DJConnectPairedOwnerLiveCapability?,
                pairedToken: @escaping @Sendable () throws -> String?) {
        self.baseURL = baseURL; self.session = pairedLiveCredentialFreeSession(from: session)
        self.auth = nil; self.discover = discover; self.pairedToken = pairedToken
    }

    deinit { if discover != nil { session.invalidateAndCancel() } }

    public func start(
        sessionID: String,
        identity: DJConnectAPIIdentity,
        onSnapshot: @escaping SnapshotHandler,
        onEvent: @escaping EventHandler,
        onTerminated: @escaping TerminationHandler,
        onUnavailable: @escaping TerminationHandler = {},
        onDisconnected: @escaping TerminationHandler = {},
        onConnectionUnavailable: @escaping TerminationHandler = {},
        onAuthorityWithdrawn: AuthorityHandler? = nil
    ) {
        stop()
        shouldRun = true
        runTask = Task { [weak self] in
            await self?.run(
                sessionID: sessionID,
                identity: identity,
                onSnapshot: onSnapshot,
                onEvent: onEvent,
                onTerminated: onTerminated,
                onUnavailable: onUnavailable,
                onDisconnected: onDisconnected,
                onConnectionUnavailable: onConnectionUnavailable,
                onAuthorityWithdrawn: onAuthorityWithdrawn
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
        onTerminated: @escaping TerminationHandler,
        onUnavailable: @escaping TerminationHandler,
        onDisconnected: @escaping TerminationHandler,
        onConnectionUnavailable: @escaping TerminationHandler,
        onAuthorityWithdrawn: AuthorityHandler?
    ) async {
        var retryDelay: UInt64 = 1_000_000_000
        while shouldRun, !Task.isCancelled {
            do {
                try await connect(identity: identity)
                let subscription = try await subscribe(sessionID: sessionID, identity: identity)
                guard shouldRun, !Task.isCancelled else { return }
                await onSnapshot(subscription)
                retryDelay = 1_000_000_000
                while shouldRun, !Task.isCancelled {
                    let event = try await receiveEvent()
                    guard shouldRun, !Task.isCancelled else { return }
                    guard event.sessionID == sessionID else { throw DJConnectSessionBroadcastUnavailableError() }
                    if event.deliverySequence == nil && !["runtime_ended", "broadcast_stopped"].contains(event.eventType) {
                        throw DJConnectError.invalidResponse
                    }
                    await onEvent(event)
                    if event.eventType == "runtime_ended" || event.eventType == "broadcast_stopped" {
                        stop()
                        if event.payload.nativeDelivery?.revocationScope == "subscription" {
                            await onDisconnected()
                        } else { await onTerminated() }
                        return
                    }
                }
            } catch {
                guard shouldRun, !Task.isCancelled else { return }
                let hadSocket = socket != nil
                socket?.cancel(with: .goingAway, reason: nil)
                socket = nil
                // Missing auth issuance is not a transient socket disconnect.
                if !hadSocket, case .routeMissing = error as? DJConnectError {
                    stop()
                    await onConnectionUnavailable()
                    return
                }
                await onDisconnected()
                if let revoked = error as? DJConnectPairedOwnerAuthorityWithdrawnError {
                    stop()
                    if let onAuthorityWithdrawn { await onAuthorityWithdrawn(revoked.code) }
                    else { await onUnavailable() }
                    return
                }
                if error is DJConnectSessionBroadcastEndedError {
                    stop()
                    await onTerminated()
                    return
                }
                if error is DJConnectSessionBroadcastUnavailableError || (error as? DJConnectError)?.invalidatesSessionAuthority == true {
                    stop()
                    await onUnavailable()
                    return
                }
                try? await Task.sleep(nanoseconds: retryDelay)
                retryDelay = min(retryDelay * 2, 15_000_000_000)
            }
        }
    }

    private func connect(identity: DJConnectAPIIdentity) async throws {
        guard socket == nil else { return }
        if let discover, let pairedToken {
            guard let capability = try await discover() else {
                throw DJConnectError.routeMissing(message: "Paired live capability unavailable")
            }
            let url = try capability.websocketURL(baseURL: baseURL, clientType: identity.clientType)
            guard let token = try pairedToken(), !token.isEmpty else { throw DJConnectSessionBroadcastUnavailableError() }
            guard shouldRun, !Task.isCancelled else { throw CancellationError() }
            let task = session.webSocketTask(with: url)
            socket = task; task.resume()
            let required: DJConnectSessionBroadcastAuthMessage = try await receiveHandshake()
            // No credential is sent until the exact trusted-origin challenge is validated.
            guard pairedLiveUpgradeMatches(task.response?.url ?? task.currentRequest?.url, expected: url), required.type == "auth_required", required.protocolVersion == 1 else {
                throw DJConnectSessionBroadcastUnavailableError()
            }
            guard shouldRun, !Task.isCancelled else { throw CancellationError() }
            try await send(DJConnectPairedOwnerAuthRequest(deviceID: identity.deviceID, clientType: identity.clientType, deviceToken: token))
            let accepted: DJConnectSessionBroadcastAuthMessage = try await receiveHandshake()
            guard accepted.type == "auth_ok", accepted.protocolVersion == 1,
                  accepted.leaseSeconds == 300, accepted.audience == "active_owner_broadcast",
                  accepted.commands?.count == 2,
                  Set(accepted.commands ?? []) == [DJConnectPairedOwnerLiveCapability.subscribe, DJConnectPairedOwnerLiveCapability.recover] else {
                throw DJConnectSessionBroadcastUnavailableError()
            }
        } else {
            guard let token = try await auth?.accessToken()?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
                throw DJConnectError.routeMissing(message: "Explicit HA WebSocket auth unavailable")
            }
            guard shouldRun, !Task.isCancelled else { throw CancellationError() }
            let task = session.webSocketTask(with: try DJConnectHomeAssistantWebSocketFastPath.websocketURL(from: baseURL))
            socket = task; task.resume()
            let required: DJConnectSessionBroadcastAuthMessage = try await receiveHandshake()
            guard required.type == "auth_required" else { throw DJConnectError.invalidResponse }
            try await send(DJConnectSessionBroadcastAuthRequest(type: "auth", accessToken: token))
            let accepted: DJConnectSessionBroadcastAuthMessage = try await receiveHandshake()
            guard accepted.type == "auth_ok" else { throw DJConnectSessionBroadcastUnavailableError() }
        }
    }

    private func subscribe(sessionID: String, identity: DJConnectAPIIdentity) async throws -> DJConnectSessionBroadcastSubscription {
        // A new connection always gets a fresh authoritative snapshot. Old Moment
        // authority was withdrawn on close; replay alone cannot re-grant it.
        if discover != nil { try await send(DJConnectPairedOwnerSubscribeRequest(sessionID: sessionID)) }
        else { try await send(DJConnectSessionBroadcastSubscribeRequest(sessionID: sessionID, identity: identity)) }
        let envelope: DJConnectSessionBroadcastResultEnvelope<DJConnectSessionBroadcastSubscription> = try await receive()
        guard envelope.type == "result", envelope.id == 1 else { throw DJConnectSessionBroadcastUnavailableError() }
        guard envelope.success, let result = envelope.result else {
            if envelope.error?.code == "active_session_not_found" {
                throw DJConnectSessionBroadcastEndedError()
            }
            throw DJConnectSessionBroadcastUnavailableError()
        }
        guard result.success, result.sessionID == sessionID, result.snapshot.session.sessionID == sessionID else {
            throw DJConnectSessionBroadcastUnavailableError()
        }
        return result
    }

    private func receiveEvent() async throws -> DJConnectSessionBroadcastEvent {
        let envelope: DJConnectSessionBroadcastEventEnvelope = try await receive()
        if discover != nil {
            guard envelope.type == "event", envelope.eventType == "djconnect/session/broadcast", let event = envelope.data else {
                throw DJConnectError.invalidResponse
            }
            return event
        }
        guard envelope.type == "event", envelope.event?.eventType == "djconnect/session/broadcast", let event = envelope.event?.data else {
            throw DJConnectError.invalidResponse
        }
        return event
    }

    private func send<T: Encodable>(_ value: T) async throws {
        guard let socket else { throw DJConnectError.network(message: "WebSocket is not connected") }
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else { throw DJConnectError.invalidResponse }
        try await socket.send(.string(text))
    }

    private func receiveHandshake() async throws -> DJConnectSessionBroadcastAuthMessage {
        guard let task = socket else { throw DJConnectError.invalidResponse }
        return try await withThrowingTaskGroup(of: DJConnectSessionBroadcastAuthMessage.self) { group in
            group.addTask { [self] in try await receive(DJConnectSessionBroadcastAuthMessage.self) }
            group.addTask {
                try await Task.sleep(for: .seconds(5))
                task.cancel(with: .goingAway, reason: nil)
                throw DJConnectError.network(message: "Live handshake timed out")
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw CancellationError() }
            return result
        }
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
        try DJConnectIncomingPayloadLimiter.validate(data)
        if let authFrame = try? decoder.decode(DJConnectSessionBroadcastAuthMessage.self, from: data), authFrame.type == "auth_invalid" {
            if authFrame.code == "auth_expired" || authFrame.code == "slow_consumer" {
                throw DJConnectError.network(message: "Paired live connection expired")
            }
            if discover != nil { throw DJConnectPairedOwnerAuthorityWithdrawnError(code: authFrame.code ?? "invalid_auth") }
            throw DJConnectSessionBroadcastUnavailableError()
        }
        return try decoder.decode(T.self, from: data)
    }
}

private struct DJConnectSessionBroadcastAuthMessage: Decodable {
    var type: String; var protocolVersion: Int?; var leaseSeconds: Int?
    var audience: String?; var commands: [String]?; var code: String?
    enum CodingKeys: String, CodingKey {
        case type, audience, commands, code
        case protocolVersion = "protocol_version", leaseSeconds = "lease_seconds"
    }
}
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
private struct DJConnectSessionBroadcastUnavailableError: Error {}
private struct DJConnectSessionBroadcastResultEnvelope<Result: Decodable>: Decodable { var id: Int; var type: String; var success: Bool; var result: Result?; var error: DJConnectSessionBroadcastError? }
private struct DJConnectSessionBroadcastEventEnvelope: Decodable { struct Event: Decodable { var eventType: String; var data: DJConnectSessionBroadcastEvent; enum CodingKeys: String, CodingKey { case eventType = "event_type"; case data } }; var type: String; var event: Event?; var eventType: String?; var data: DJConnectSessionBroadcastEvent?; enum CodingKeys: String, CodingKey { case type, event, data; case eventType = "event_type" } }

private struct DJConnectPairedOwnerAuthorityWithdrawnError: Error { let code: String }
