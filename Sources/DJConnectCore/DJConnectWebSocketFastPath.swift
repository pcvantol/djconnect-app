import Foundation

public enum DJConnectFastPathRoute: String, CaseIterable, Sendable {
    case command = "djconnect/command"
    case askDJMessage = "djconnect/ask_dj/message"
    case askDJHistory = "djconnect/ask_dj/history"
    case askDJHistoryClear = "djconnect/ask_dj/history/clear"
    case askDJHistoryState = "djconnect/ask_dj/history/state"
    case askDJIdleSuggestion = "djconnect/ask_dj/idle_suggestion"
    case musicDNAProfile = "djconnect/music_dna/profile"
    case musicDNASettings = "djconnect/music_dna/settings"
    case musicDNAClear = "djconnect/music_dna/clear"
    case musicDNAImport = "djconnect/music_dna/import"
    case musicDNAExport = "djconnect/music_dna/export"
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

/// `routeMissing` means the operation was not dispatched. After native dispatch,
/// mutations must report `deliveryUnknown` rather than permit an HTTP replay.
public protocol DJConnectWebSocketFastPathTransport: Sendable {
    var diagnostics: DJConnectFastPathDiagnostics { get async }
    func prepare() async throws
    func supports(_ route: DJConnectFastPathRoute) async -> Bool
    func command<T: Decodable & Sendable>(_ payload: DJConnectCommandPayload, identity: DJConnectAPIIdentity, responseType: T.Type) async throws -> T
    func askDJMessage(_ payload: DJConnectAskDJRequest, identity: DJConnectAPIIdentity) async throws -> DJConnectAskDJMessageResponse
    func askDJHistory(identity: DJConnectAPIIdentity, sinceRevision: Int?) async throws -> DJConnectAskDJHistoryResponse
    func profileConversationHistory(identity: DJConnectAPIIdentity) async throws -> DJConnectProfileConversationHistory
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

public extension DJConnectWebSocketFastPathTransport {
    func profileConversationHistory(identity: DJConnectAPIIdentity) async throws -> DJConnectProfileConversationHistory {
        throw DJConnectError.routeMissing(message: "Scoped Profile history is unavailable")
    }
}

public actor DJConnectHomeAssistantWebSocketFastPath: DJConnectWebSocketFastPathTransport {
    public let baseURL: URL

    private let session: URLSession
    private let homeAssistantAuth: DJConnectHomeAssistantWebSocketAuth
    private let timing: DJConnectWebSocketRuntimeTiming
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var task: URLSessionWebSocketTask?
    private var nextID = 1
    private static let maximumPendingRequests = 8
    private var socketEpoch = UUID()
    private var authenticated = false
    private var readerTask: Task<Void, Never>?
    private var negotiationID: UUID?
    private var negotiationTask: Task<Void, Never>?
    private var negotiationTimer: Task<Void, Never>?
    private var negotiationClosed = false
    private var negotiationWaiters: [UUID: CheckedContinuation<Set<DJConnectFastPathRoute>, Error>] = [:]
    private struct Pending {
        let epoch: UUID
        let continuation: CheckedContinuation<Data, Error>
        var sender: Task<Void, Never>?
        var timer: Task<Void, Never>?
        var dispatched = false
        var sendCompleted = false
    }
    private var pending: [Int: Pending] = [:]
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
        self.timing = .live
    }

    init(baseURL: URL, homeAssistantAuth: DJConnectHomeAssistantWebSocketAuth,
         session: URLSession, timing: DJConnectWebSocketRuntimeTiming, firstRequestID: Int = 1) {
        self.baseURL = baseURL; self.homeAssistantAuth = homeAssistantAuth
        self.session = session; self.timing = timing; self.nextID = firstRequestID
    }

    deinit {
        readerTask?.cancel(); negotiationTask?.cancel(); negotiationTimer?.cancel()
        task?.cancel(with: .goingAway, reason: nil) // Never invalidate the supplied URLSession.
    }

    var startupIsActive: Bool { negotiationID != nil }

    private var ignoredReplies = 0
    var inFlightCounts: (startup: Int, requests: Int, sending: Int, ignored: Int) {
        (negotiationWaiters.count, pending.count, pending.values.filter { $0.dispatched && !$0.sendCompleted }.count, ignoredReplies)
    }

    public var diagnostics: DJConnectFastPathDiagnostics {
        DJConnectFastPathDiagnostics(
            fastPathTransport: authenticated && task != nil ? "websocket" : "http",
            websocketConnected: authenticated && task != nil,
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
        guard try await operationCapabilities().contains(.command) else {
            throw DJConnectError.routeMissing(message: "WebSocket command capability unavailable")
        }
        let request = DJConnectWebSocketCommandMessage(id: try allocateID(), identity: identity, payload: payload)
        return try await sendResult(request, timeout: Self.timeout(for: payload.command), responseType: T.self, replaySafe: DJConnectHybridTransport.canReplayLegacyCommand(payload.command))
    }

    public func askDJMessage(_ payload: DJConnectAskDJRequest, identity: DJConnectAPIIdentity) async throws -> DJConnectAskDJMessageResponse {
        guard try await operationCapabilities().contains(.askDJMessage) else {
            throw DJConnectError.routeMissing(message: "WebSocket Ask DJ capability unavailable")
        }
        let request = DJConnectWebSocketAskDJMessage(id: try allocateID(), identity: identity, payload: payload)
        return try await sendResult(request, timeout: 15, responseType: DJConnectAskDJMessageResponse.self)
    }

    public func profileConversationHistory(identity: DJConnectAPIIdentity) async throws -> DJConnectProfileConversationHistory {
        guard try await operationCapabilities().contains(.askDJHistory) else {
            throw DJConnectError.routeMissing(message: "Scoped Profile history is unavailable")
        }
        let request = DJConnectWebSocketProfileHistoryMessage(id: try allocateID(), identity: identity)
        return try await sendResult(request, timeout: 10, responseType: DJConnectProfileConversationHistory.self, privateResponse: true, replaySafe: true)
    }

    public func askDJHistory(
        identity: DJConnectAPIIdentity,
        sinceRevision: Int?
    ) async throws -> DJConnectAskDJHistoryResponse {
        guard try await operationCapabilities().contains(.askDJHistory) else {
            throw DJConnectError.routeMissing(message: "WebSocket Ask DJ history capability unavailable")
        }
        let request = DJConnectWebSocketAskDJHistoryMessage(
            id: try allocateID(),
            type: DJConnectFastPathRoute.askDJHistory.rawValue,
            identity: identity,
            sinceRevision: sinceRevision,
            musicDNAKey: nil
        )
        return try await sendResult(request, timeout: 10, responseType: DJConnectAskDJHistoryResponse.self, replaySafe: true)
    }

    public func clearAskDJHistory(
        identity: DJConnectAPIIdentity,
        musicDNAKey: String?
    ) async throws -> DJConnectAskDJHistoryResponse {
        guard try await operationCapabilities().contains(.askDJHistoryClear) else {
            throw DJConnectError.routeMissing(message: "WebSocket Ask DJ clear-history capability unavailable")
        }
        let request = DJConnectWebSocketAskDJHistoryMessage(
            id: try allocateID(),
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
        guard try await operationCapabilities().contains(.musicDNAProfile) else {
            throw DJConnectError.routeMissing(message: "WebSocket Music DNA profile capability unavailable")
        }
        let payload = DJConnectMusicDNAFastPathPayload(mood: mood, musicDNAKey: musicDNAKey, language: language)
        let request = DJConnectWebSocketMusicDNARequestMessage(
            id: try allocateID(),
            type: DJConnectFastPathRoute.musicDNAProfile.rawValue,
            identity: identity,
            payload: payload
        )
        return try await sendResult(request, timeout: 10, responseType: DJConnectMusicDNAProfileResponse.self, replaySafe: true)
    }

    public func setMusicDNAEnabled(
        _ enabled: Bool,
        identity: DJConnectAPIIdentity,
        mood: Int?,
        musicDNAKey: String?,
        language: String?
    ) async throws -> DJConnectMusicDNAProfileResponse {
        guard try await operationCapabilities().contains(.musicDNASettings) else {
            throw DJConnectError.routeMissing(message: "WebSocket Music DNA settings capability unavailable")
        }
        let payload = DJConnectMusicDNAFastPathPayload(enabled: enabled, mood: mood, musicDNAKey: musicDNAKey, language: language)
        let request = DJConnectWebSocketMusicDNARequestMessage(
            id: try allocateID(),
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
        guard try await operationCapabilities().contains(.musicDNAClear) else {
            throw DJConnectError.routeMissing(message: "WebSocket Music DNA clear capability unavailable")
        }
        let payload = DJConnectMusicDNAFastPathPayload(mood: mood, musicDNAKey: musicDNAKey, language: language)
        let request = DJConnectWebSocketMusicDNARequestMessage(
            id: try allocateID(),
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
        guard try await operationCapabilities().contains(.musicDiscoveryFeed) else {
            throw DJConnectError.routeMissing(message: "WebSocket Music Discovery feed capability unavailable")
        }
        let request = DJConnectWebSocketMusicDiscoveryRequestMessage(
            id: try allocateID(),
            type: DJConnectFastPathRoute.musicDiscoveryFeed.rawValue,
            identity: identity,
            musicDNAKey: musicDNAKey,
            language: language
        )
        return try await sendResult(request, timeout: 10, responseType: DJConnectMusicDiscoveryResponse.self, replaySafe: true)
    }

    public func refreshMusicDiscovery(
        identity: DJConnectAPIIdentity,
        musicDNAKey: String?,
        language: String?
    ) async throws -> DJConnectMusicDiscoveryResponse {
        guard try await operationCapabilities().contains(.musicDiscoveryRefresh) else {
            throw DJConnectError.routeMissing(message: "WebSocket Music Discovery refresh capability unavailable")
        }
        let request = DJConnectWebSocketMusicDiscoveryRequestMessage(
            id: try allocateID(),
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
        guard try await operationCapabilities().contains(.musicDiscoveryPlay) else {
            throw DJConnectError.routeMissing(message: "WebSocket Music Discovery play capability unavailable")
        }
        let request = DJConnectWebSocketMusicDiscoveryActionMessage(
            id: try allocateID(),
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
        guard try await operationCapabilities().contains(.musicDiscoveryFeedback) else {
            throw DJConnectError.routeMissing(message: "WebSocket Music Discovery feedback capability unavailable")
        }
        let request = DJConnectWebSocketMusicDiscoveryActionMessage(
            id: try allocateID(),
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
        guard try await operationCapabilities().contains(.trackInsight) else {
            throw DJConnectError.routeMissing(message: "WebSocket Track Insight capability unavailable")
        }
        let request = DJConnectWebSocketTrackInsightMessage(id: try allocateID(), identity: identity, payload: payload)
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
        guard try await operationCapabilities().contains(.vibeCast) else {
            throw DJConnectError.routeMissing(message: "WebSocket VibeCast capability unavailable")
        }
        let request = DJConnectWebSocketVibeCastMessage(id: try allocateID(), identity: identity, payload: payload)
        return try await sendResult(request, timeout: 10, responseType: DJConnectVibeCastResponse.self)
    }

    // Startup only negotiates transport support; no business operation has
    // been dispatched. Preserve that fact across the common client fallback.
    private func operationCapabilities() async throws -> Set<DJConnectFastPathRoute> {
        do { return try await ensureCapabilities() }
        catch {
            if error is CancellationError || Task.isCancelled || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            if error is URLError { throw DJConnectWebSocketPreDispatchFailure(error: error) }
            if let typed = error as? DJConnectError {
                switch typed {
                case .network, .invalidResponse: throw DJConnectWebSocketPreDispatchFailure(error: typed)
                default: throw typed
                }
            }
            // Foundation may expose POSIX/CFNetwork errors directly during
            // the handshake. This is still before business dispatch; export
            // neither an arbitrary SDK description nor credential context.
            throw DJConnectWebSocketPreDispatchFailure(error: DJConnectError.network(message: "WebSocket startup failed"))
        }
    }

    private func ensureCapabilities() async throws -> Set<DJConnectFastPathRoute> {
        try Task.checkCancellation()
        if let unhealthyUntil, unhealthyUntil > timing.now() {
            throw DJConnectError.network(message: "WebSocket fast path is backing off")
        }
        if let loaded = capabilitiesLoadedAt, timing.now().timeIntervalSince(loaded) < 60 {
            return Set(commands.compactMap(DJConnectFastPathRoute.init(rawValue:)))
        }
        guard !negotiationClosed, negotiationWaiters.count < Self.maximumPendingRequests else {
            throw DJConnectError.routeMissing(message: "WebSocket negotiation capacity unavailable")
        }
        let waiter = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(throwing: CancellationError()); return }
                negotiationWaiters[waiter] = continuation
                if negotiationID == nil {
                    let id = UUID(); negotiationID = id
                    let sleep = timing.sleep
                    negotiationTimer = Task { [weak self] in
                        do { try await sleep(15); await self?.expireNegotiation(id: id) } catch { }
                    }
                    negotiationTask = Task { [weak self] in await self?.negotiate(id: id) }
                }
            }
        } onCancel: { Task { await self.cancelNegotiation(waiter: waiter) } }
    }

    private func negotiate(id: UUID) async {
        do {
            try await connectIfNeeded(negotiation: id)
            guard negotiationID == id else { return }
            try Task.checkCancellation()
            let epoch = socketEpoch
            let request = DJConnectWebSocketTypeMessage(id: try allocateID(), type: "djconnect/capabilities")
            let response: DJConnectWebSocketCapabilitiesResponse = try await sendResult(request, timeout: 5,
                responseType: DJConnectWebSocketCapabilitiesResponse.self, replaySafe: true)
            guard negotiationID == id else { return }
            try Task.checkCancellation()
            guard socketEpoch == epoch, authenticated else { throw DJConnectError.network(message: "WebSocket startup retired") }
            guard response.websocketSupported == true, response.transports?.websocket == true else {
                throw DJConnectError.routeMissing(message: "Home Assistant did not advertise DJConnect WebSocket transport support")
            }
            commands = Set(response.advertisedCommands); capabilitiesLoadedAt = timing.now()
            finishNegotiation(id: id, result: .success(Set(commands.compactMap(DJConnectFastPathRoute.init(rawValue:)))))
        } catch {
            guard negotiationID == id else { return }
            // An old startup completion must never retire a replacement socket.
            if !authenticated { retireSocket(epoch: socketEpoch, error: error, backoff: !(error is CancellationError)) }
            finishNegotiation(id: id, result: .failure(error))
        }
    }

    private func finishNegotiation(id: UUID, result: Result<Set<DJConnectFastPathRoute>, Error>) {
        guard negotiationID == id else { return }
        negotiationID = nil; negotiationTask = nil; negotiationClosed = false
        negotiationTimer?.cancel(); negotiationTimer = nil
        let waiters = negotiationWaiters; negotiationWaiters.removeAll()
        for continuation in waiters.values { continuation.resume(with: result) }
    }

    private func cancelNegotiation(waiter: UUID) {
        guard let continuation = negotiationWaiters.removeValue(forKey: waiter) else { return }
        continuation.resume(throwing: CancellationError())
        guard negotiationWaiters.isEmpty else { return } // Other consumers still own shared startup.
        // Retain one cancelled startup slot until a possibly non-cooperative
        // token provider returns. Never fan out replacement credential reads.
        negotiationClosed = true; negotiationTask?.cancel()
        negotiationTimer?.cancel(); negotiationTimer = nil
        // An established socket may still serve unrelated in-flight requests
        // during a capability refresh. Their ownership is independent.
        if pending.isEmpty || !authenticated {
            retireSocket(epoch: socketEpoch, error: CancellationError(), backoff: false)
        }
    }

    private func expireNegotiation(id: UUID) {
        guard negotiationID == id, !negotiationClosed else { return }
        negotiationClosed = true; negotiationTask?.cancel()
        let values = negotiationWaiters; negotiationWaiters.removeAll()
        for value in values.values { value.resume(throwing: DJConnectError.network(message: "WebSocket startup timeout")) }
        if !authenticated { retireSocket(epoch: socketEpoch, error: DJConnectError.network(message: "WebSocket startup timeout"), backoff: true) }
    }

    private func connectIfNeeded(negotiation id: UUID) async throws {
        if authenticated, task != nil { return }
        guard Self.isLocalHomeAssistantURL(baseURL) else {
            throw DJConnectError.routeMissing(message: "WebSocket fast path is local-only")
        }
        let token = try await homeAssistantAuth.accessToken()?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard negotiationID == id, !Task.isCancelled else { throw CancellationError() }
        guard let token, !token.isEmpty else {
            throw DJConnectError.routeMissing(message: "Home Assistant WebSocket auth token is unavailable")
        }
        let socket = session.webSocketTask(with: try Self.websocketURL(from: baseURL))
        socket.maximumMessageSize = min(socket.maximumMessageSize, DJConnectIncomingPayloadLimiter.defaultMaxPayloadBytes)
        let epoch = UUID(); socketEpoch = epoch; task = socket; authenticated = false
        socket.resume()
        let required: DJConnectWebSocketAuthMessage = try await receiveHandshake(socket, timeout: 5)
        guard socketEpoch == epoch, negotiationID == id, required.type == "auth_required" else { throw DJConnectError.invalidResponse }
        let bytes = try encoder.encode(DJConnectWebSocketAuthRequest(type: "auth", accessToken: token))
        try await socket.send(.string(String(decoding: bytes, as: UTF8.self)))
        let auth: DJConnectWebSocketAuthMessage = try await receiveHandshake(socket, timeout: 5)
        guard socketEpoch == epoch, negotiationID == id, !Task.isCancelled else { throw CancellationError() }
        guard auth.type == "auth_ok" else { throw DJConnectError.network(message: "Home Assistant WebSocket auth failed") }
        authenticated = true
        // Auth's sole receiver has finished. Only this loop receives from here.
        let beforeFailure = timing.beforeReaderFailure, afterFailure = timing.afterReaderFailure
        readerTask = Task { [weak self, socket] in
            do {
                while !Task.isCancelled {
                    let message = try await socket.receive()
                    await self?.route(message, epoch: epoch)
                }
            } catch {
                await beforeFailure()
                await self?.readerFailed(epoch: epoch)
                await afterFailure()
            }
        }
    }

    private func receiveHandshake<T: Decodable & Sendable>(_ socket: URLSessionWebSocketTask, timeout: TimeInterval) async throws -> T {
        try await withTimeout(seconds: timeout, sleep: timing.sleep) {
            try await withTaskCancellationHandler {
                let message = try await socket.receive()
                return try JSONDecoder().decode(T.self, from: Self.messageData(message))
            } onCancel: { socket.cancel(with: .goingAway, reason: nil) }
        }
    }

    private func sendResult<T: Encodable, U: Decodable & Sendable>(
        _ message: T, timeout: TimeInterval, responseType: U.Type,
        privateResponse: Bool = false, replaySafe: Bool = false
    ) async throws -> U {
        let data = try encoder.encode(message)
        // Reserving bounded bytes/capacity/ID precedes any native send.
        guard data.count <= DJConnectIncomingPayloadLimiter.defaultMaxPayloadBytes else {
            throw DJConnectError.routeMissing(message: "WebSocket request capacity unavailable")
        }
        let header = try decoder.decode(DJConnectWebSocketRequestHeader.self, from: data)
        let epoch = socketEpoch
        do {
            let raw = try await exchange(id: header.id, data: data, timeout: timeout, epoch: epoch)
            let status = try decoder.decode(DJConnectWebSocketResultStatus.self, from: raw)
            guard status.success else {
                throw DJConnectError.server(statusCode: 200, message: status.error?.message ?? status.error?.code)
            }
            let envelope = try decoder.decode(DJConnectWebSocketResultEnvelope<U>.self, from: raw)
            guard let result = envelope.result else { throw DJConnectError.invalidResponse }
            return result
        } catch {
            if Task.isCancelled || error is CancellationError { throw CancellationError() }
            if let wire = error as? DJConnectWebSocketWireFailure {
                if wire.dispatched && !replaySafe { throw DJConnectHybridTransportError.deliveryUnknown }
                let safe = sanitizedTransportError(wire.error, privateResponse: privateResponse)
                if !wire.dispatched {
                    if let typed = safe as? DJConnectError, case .routeMissing = typed { throw typed }
                    throw DJConnectWebSocketPreDispatchFailure(error: safe)
                }
                throw safe
            }
            // A received error is authoritative; do not replay it. A successful
            // envelope whose body cannot be decoded leaves a write uncertain.
            if let typed = error as? DJConnectError, case .server = typed {
                let safe = sanitizedTransportError(typed, privateResponse: privateResponse)
                if socketEpoch == epoch { lastError = Self.redactedError(safe) }
                throw safe
            }
            if !replaySafe { throw DJConnectHybridTransportError.deliveryUnknown }
            throw sanitizedTransportError(error, privateResponse: privateResponse)
        }
    }

    private func exchange(id: Int, data: Data, timeout: TimeInterval, epoch: UUID) async throws -> Data {
        try Task.checkCancellation()
        guard authenticated, let socket = task, socketEpoch == epoch else {
            throw DJConnectWebSocketWireFailure(dispatched: false, error: DJConnectError.network(message: "WebSocket is not connected"))
        }
        guard id > 0, pending[id] == nil, pending.count < Self.maximumPendingRequests else {
            throw DJConnectWebSocketWireFailure(dispatched: false, error: DJConnectError.routeMissing(message: "WebSocket request capacity unavailable"))
        }
        let sleep = timing.sleep
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(throwing: CancellationError()); return }
                pending[id] = Pending(epoch: epoch, continuation: continuation)
                pending[id]?.timer = Task { [weak self] in
                    do { try await sleep(timeout); await self?.expire(id: id, epoch: epoch) }
                    catch { }
                }
                pending[id]?.sender = Task { [weak self, socket] in
                    await self?.dispatch(id: id, data: data, socket: socket, epoch: epoch)
                }
            }
        } onCancel: { Task { await self.cancelPending(id: id, epoch: epoch) } }
    }

    private func dispatch(id: Int, data: Data, socket: URLSessionWebSocketTask, epoch: UUID) async {
        guard pending[id]?.epoch == epoch, socketEpoch == epoch, !Task.isCancelled else { return }
        pending[id]?.dispatched = true // Conservative native boundary; never infer notSent from a later error.
        do {
            try await socket.send(.string(String(decoding: data, as: UTF8.self)))
            if pending[id]?.epoch == epoch { pending[id]?.sendCompleted = true }
        } catch {
            guard pending[id]?.epoch == epoch, socketEpoch == epoch else { return }
            retireSocket(epoch: epoch, error: DJConnectError.network(message: "WebSocket send failed"), backoff: true)
        }
    }

    private func route(_ message: URLSessionWebSocketTask.Message, epoch: UUID) {
        guard socketEpoch == epoch, authenticated else { return }
        do {
            let data = try Self.messageData(message)
            let header = try decoder.decode(DJConnectWebSocketResultHeader.self, from: data)
            guard header.id > 0, header.type == "result" else { throw DJConnectError.invalidResponse }
            // Unknown/late/duplicate IDs cannot satisfy a later request. IDs do
            // not wrap or get reused within this adapter's lifetime.
            guard pending[header.id]?.epoch == epoch else {
                if ignoredReplies < Int.max { ignoredReplies += 1 }
                return
            }
            finishPending(id: header.id, result: .success(data))
        } catch { retireSocket(epoch: epoch, error: DJConnectError.invalidResponse, backoff: true) }
    }

    private func readerFailed(epoch: UUID) {
        retireSocket(epoch: epoch, error: DJConnectError.network(message: "WebSocket connection failed"), backoff: true)
    }

    private func finishPending(id: Int, result: Result<Data, Error>) {
        guard let value = pending.removeValue(forKey: id) else { return }
        value.timer?.cancel()
        if case .failure = result { value.sender?.cancel() }
        value.continuation.resume(with: result)
    }

    private func cancelPending(id: Int, epoch: UUID) {
        guard let value = pending[id], value.epoch == epoch else { return }
        finishPending(id: id, result: .failure(CancellationError()))
        if value.dispatched && !value.sendCompleted {
            retireSocket(epoch: epoch, error: DJConnectError.network(message: "WebSocket send cancelled"), backoff: false)
        }
    }

    private func expire(id: Int, epoch: UUID) {
        guard let value = pending[id], value.epoch == epoch else { return }
        finishPending(id: id, result: .failure(DJConnectWebSocketWireFailure(dispatched: value.dispatched,
            error: DJConnectError.network(message: "WebSocket timeout"))))
        if value.dispatched && !value.sendCompleted {
            retireSocket(epoch: epoch, error: DJConnectError.network(message: "WebSocket send expired"), backoff: true)
        }
    }

    private func retireSocket(epoch: UUID, error: Error, backoff: Bool) {
        guard socketEpoch == epoch else { return }
        socketEpoch = UUID(); authenticated = false
        readerTask?.cancel(); readerTask = nil; task?.cancel(with: .goingAway, reason: nil); task = nil
        commands = []; capabilitiesLoadedAt = nil
        if backoff { unhealthyUntil = timing.now().addingTimeInterval(10); lastError = Self.redactedError(error) }
        let values = pending; pending.removeAll()
        for value in values.values {
            value.timer?.cancel(); value.sender?.cancel()
            value.continuation.resume(throwing: DJConnectWebSocketWireFailure(dispatched: value.dispatched, error: error))
        }
    }

    private nonisolated static func messageData(_ message: URLSessionWebSocketTask.Message) throws -> Data {
        let data: Data
        switch message {
        case .string(let text): try DJConnectIncomingPayloadLimiter.validate(text); data = Data(text.utf8)
        case .data(let bytes): data = bytes
        @unknown default: throw DJConnectError.invalidResponse
        }
        try DJConnectIncomingPayloadLimiter.validate(data)
        return data
    }

    private func allocateID() throws -> Int {
        guard nextID > 0, nextID < Int.max else { throw DJConnectError.routeMissing(message: "WebSocket request IDs exhausted") }
        defer { nextID += 1 }
        return nextID
    }

    private func markUnhealthy(_ error: Error) {
        retireSocket(epoch: socketEpoch, error: error, backoff: true)
    }

    private func sanitizedTransportError(_ error: Error, privateResponse: Bool) -> Error {
        guard privateResponse else { return error }
        guard let typed = error as? DJConnectError else { return DJConnectError.network(message: "Scoped Profile history request failed") }
        switch typed {
        case let .authStale(status, _): return DJConnectError.authStale(statusCode: status, message: nil)
        case let .profile(code, status, _): return DJConnectError.profile(code: code, statusCode: status, message: nil)
        case let .server(status, _): return DJConnectError.server(statusCode: status, message: nil)
        case .backendUnavailable: return DJConnectError.backendUnavailable(message: nil)
        case .routeMissing: return DJConnectError.routeMissing(message: nil)
        case .missingToken, .invalidResponse: return typed
        default: return DJConnectError.network(message: "Scoped Profile history request failed")
        }
    }

    /// Existing internal diagnostic boundary, also used by privacy regressions.
    @discardableResult
    func recordTransportFailure(_ error: Error, privateResponse: Bool) -> Error {
        if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled { return CancellationError() }
        let safe = sanitizedTransportError(error, privateResponse: privateResponse)
        markUnhealthy(privateResponse ? DJConnectError.network(message: "Scoped Profile history request failed") : safe)
        return safe
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
        case let .profile(code, statusCode, message):
            message ?? "Profile error \(code.rawValue) (HTTP \(statusCode))"
        }
    }
}

private func withTimeout<T: Sendable>(seconds: TimeInterval,
    sleep: @escaping @Sendable (TimeInterval) async throws -> Void,
    operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await sleep(seconds)
            throw DJConnectError.network(message: "WebSocket timeout")
        }
        defer { group.cancelAll() }
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
            values.insert(DJConnectFastPathRoute.musicDNAImport.rawValue)
            values.insert(DJConnectFastPathRoute.musicDNAExport.rawValue)
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

struct DJConnectWebSocketFallback: Decodable {
    var httpPath: String?
    var httpPaths: [String]?

    enum CodingKeys: String, CodingKey {
        case httpPath = "http_path"
        case httpPaths = "http_paths"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        httpPath = try container.decodeIfPresent(String.self, forKey: .httpPath)
        if try !container.contains(.httpPaths) || container.decodeNil(forKey: .httpPaths) {
            httpPaths = nil
        } else if let paths = try? container.decode([String].self, forKey: .httpPaths) {
            httpPaths = paths
        } else {
            // Core publishes operation-to-path maps; retain support for older arrays.
            let paths = try container.decode([String: String].self, forKey: .httpPaths)
            httpPaths = paths.keys.sorted().compactMap { paths[$0] }
        }
    }

    var hasHTTPPath: Bool {
        httpPath?.isEmpty == false || httpPaths?.contains(where: { !$0.isEmpty }) == true
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

struct DJConnectWebSocketProfileHistoryMessage: Encodable {
    let id: Int
    let type = DJConnectFastPathRoute.askDJHistory.rawValue
    let identity: DJConnectAPIIdentity
    let payload = ["conversation_scope": "profile"]
}

private struct DJConnectWebSocketRequestHeader: Decodable { let id: Int }
private struct DJConnectWebSocketResultHeader: Decodable { let id: Int; let type: String }
private struct DJConnectWebSocketResultStatus: Decodable { let success: Bool; let error: DJConnectWebSocketError? }
private struct DJConnectWebSocketWireFailure: Error { let dispatched: Bool; let error: Error }

/// Only local transport scheduling. This is not a producer/admission clock.
struct DJConnectWebSocketRuntimeTiming: Sendable {
    var now: @Sendable () -> Date
    var sleep: @Sendable (TimeInterval) async throws -> Void
    var beforeReaderFailure: @Sendable () async -> Void = {}
    var afterReaderFailure: @Sendable () async -> Void = {}
    static let live = Self(now: { Date() }, sleep: { try await Task.sleep(for: .seconds($0)) })
}

/// Internal proof from the native adapter that a business operation never
/// crossed the SDK send boundary. A generic network error is not such proof.
struct DJConnectWebSocketPreDispatchFailure: Error { let error: Error }
