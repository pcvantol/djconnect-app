import Foundation

// Producer: pcvantol/djconnect 0f92b74e76ae055efdbf2b375d95c58e86328e27 (local policy v1).
// Transport state is ephemeral. No prompts, private results or media enter a journal.
typealias HybridObject = [String: DJConnectJSONValue]
extension DJConnectJSONValue {
    var hybridString: String? { if case let .string(v) = self { v } else { nil } }
    var hybridInt: Int? { if case let .int(v) = self { v } else { nil } }
    var hybridObject: HybridObject? { if case let .object(v) = self { v } else { nil } }
    var hybridStrings: [String] { if case let .array(v) = self { v.compactMap(\.hybridString) } else { [] } }
}

public struct DJConnectOperationReceipt: Codable, Equatable, Sendable {
    public let contractVersion: Int
    public let operationID: String
    public let operationEpoch: String
    public let phase: String
    public let expiresAtMS: Int
    public let resultAvailable: Bool
    public let responseStatus: Int?
    public let error: String?
    enum CodingKeys: String, CodingKey {
        case phase, error
        case contractVersion = "contract_version", operationID = "operation_id", operationEpoch = "operation_epoch"
        case expiresAtMS = "expires_at_ms", resultAvailable = "result_available", responseStatus = "response_status"
    }
}

public enum DJConnectHybridTransportError: Error, Equatable, Sendable {
    case unavailable
    case untrustedRoute
    case installationMismatch
    case capacity
    case invalidFrame
    case notSent
    case deliveryUnknown
    case routeWithdrawn
    case outcome(DJConnectOperationReceipt)
    case authority(String)
}

public struct DJConnectHybridDiagnostics: Equatable, Sendable {
    public enum State: String, Sendable { case localReady, localDegraded, remoteReady, recoveringOffline, terminalAuthorityWithdrawn }
    public var state: State = .recoveringOffline
    public var websocketConnected = false
    public var activeOrigin: URL?
    public var probes = 0
    public var reconciliations = 0
    public var receivedSnapshotGap = false
    public var transportName: String? {
        switch activeOrigin?.scheme {
        case "http": return websocketConnected ? "paired_ws" : "http"
        case "https": return websocketConnected ? "paired_wss" : "https"
        default: return nil
        }
    }
    public var transportDisplayName: String? {
        switch transportName {
        case "paired_ws": return "WS · LAN"
        case "http": return "HTTP · LAN"
        case "paired_wss": return "WSS · TLS"
        case "https": return "HTTPS · TLS"
        default: return nil
        }
    }
    public init() {}
}

public protocol DJConnectHybridSocket: Sendable {
    func send(_ data: Data) async throws
    func receive() async throws -> Data
    func ping() async throws
    func close() async
}

public protocol DJConnectHybridWire: Sendable {
    func http(_ request: URLRequest) async throws -> (Data, Int)
    func socket(_ url: URL) async throws -> any DJConnectHybridSocket
}

private final class HybridURLSocket: DJConnectHybridSocket, @unchecked Sendable {
    let task: URLSessionWebSocketTask
    init(_ task: URLSessionWebSocketTask) { self.task = task; task.maximumMessageSize = 65_536; task.resume() }
    func send(_ data: Data) async throws { try await task.send(.string(String(decoding: data, as: UTF8.self))) }
    func receive() async throws -> Data {
        switch try await task.receive() {
        case let .string(value): return Data(value.utf8)
        case .data: throw DJConnectHybridTransportError.invalidFrame
        @unknown default: throw DJConnectHybridTransportError.invalidFrame
        }
    }
    func ping() async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            task.sendPing { error in if let error { c.resume(throwing: error) } else { c.resume() } }
        }
    }
    func close() async { task.cancel(with: .goingAway, reason: nil) }
}

/// No cookies, cached authorization, redirects or certificate bypass on the new route.
public final class DJConnectHybridURLWire: DJConnectHybridWire, @unchecked Sendable {
    private let session: URLSession
    public init(session original: URLSession = .shared) {
        let c = original.configuration
        c.httpAdditionalHeaders = nil; c.urlCache = nil; c.urlCredentialStorage = nil
        c.httpCookieStorage = nil; c.httpShouldSetCookies = false
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.timeoutIntervalForRequest = 15
        session = URLSession(configuration: c, delegate: DJConnectPublicDiscoveryDelegate(original: nil), delegateQueue: nil)
    }
    deinit { session.invalidateAndCancel() }
    public func http(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.url == request.url else {
            throw DJConnectHybridTransportError.untrustedRoute
        }
        try DJConnectIncomingPayloadLimiter.validate(data)
        guard !(300..<400).contains(response.statusCode) else { throw DJConnectHybridTransportError.untrustedRoute }
        return (data, response.statusCode)
    }
    public func socket(_ url: URL) async throws -> any DJConnectHybridSocket { HybridURLSocket(session.webSocketTask(with: url)) }
}

public enum DJConnectOperationIdentity {
    public static func uuidV7(milliseconds: Int) -> String {
        var bytes = withUnsafeBytes(of: UUID().uuid) { Array($0) }
        let ms = UInt64(max(0, milliseconds))
        for i in 0..<6 { bytes[i] = UInt8(truncatingIfNeeded: ms >> ((5 - i) * 8)) }
        bytes[6] = (bytes[6] & 0x0f) | 0x70; bytes[8] = (bytes[8] & 0x3f) | 0x80
        let raw = bytes.map { String(format: "%02x", $0) }.joined()
        let chars = Array(raw)
        return [String(chars[0..<8]), String(chars[8..<12]), String(chars[12..<16]), String(chars[16..<20]), String(chars[20..<32])].joined(separator: "-")
    }
}

/// One coordinator per paired client/configuration, shared by all short-lived HTTP clients.
public actor DJConnectHybridTransport {
    struct Route: Sendable { let url: URL; let local: Bool; let context: HybridObject; let clock: Int; let anchor: TimeInterval }
    private let localURL: URL?
    private let remoteURL: URL?
    private let expectedInstallID: String
    private let identity: DJConnectIdentity
    private let tokenStore: DJConnectTokenStore
    private let wire: any DJConnectHybridWire
    private let report: (@Sendable (DJConnectHybridDiagnostics) -> Void)?
    private var diagnostics = DJConnectHybridDiagnostics()
    private var route: Route?
    private var withdrawnOrigins: [URL: TimeInterval] = [:]
    private var routeTask: Task<Route, Error>?
    private var generation = UUID()
    private var retryLocalAfter: TimeInterval = 0
    private var retryDelay: TimeInterval = 15
    private var foreground = true
    private var inFlight = 0
    private var offlineRetryAfter: TimeInterval = 0
    private var action: DJConnectPairedActionConnection?
    private var actionURL: URL?
    private var actionGeneration = UUID()
    private var receipts: [String: DJConnectOperationReceipt] = [:]
    // Compact uncertainty metadata only; payload/result bodies never survive a call.
    private var pendingIntents: [String: (epoch: String, expires: Int)] = [:]

    public init(localURL: URL?, remoteURL: URL?, expectedInstallID: String, identity: DJConnectIdentity,
                tokenStore: DJConnectTokenStore, wire: any DJConnectHybridWire = DJConnectHybridURLWire(),
                report: (@Sendable (DJConnectHybridDiagnostics) -> Void)? = nil) {
        self.localURL = localURL; self.remoteURL = remoteURL; self.expectedInstallID = expectedInstallID
        self.identity = identity; self.tokenStore = tokenStore; self.wire = wire; self.report = report
    }
    public func snapshot() -> DJConnectHybridDiagnostics { diagnostics }
    public func authorizedBaseURL() async throws -> URL { try await readyRoute().url }
    public func broadcastRecovery(sessionID: String, cursor: String) async throws -> DJConnectBroadcastRecovery {
        guard !sessionID.isEmpty, !cursor.isEmpty else { throw DJConnectHybridTransportError.invalidFrame }
        let epoch = generation, route = try await readyRoute()
        let request = try protectedRequest(route.url, path: "/api/djconnect/v1/session/broadcast/recovery",
            body: ["contract_version": .int(1), "session_id": .string(sessionID), "recovery_cursor": .string(cursor)])
        let (data, status) = try await wire.http(request)
        let raw = try JSONDecoder().decode(HybridObject.self, from: data)
        try checkAuthority(raw, status: status)
        guard epoch == generation, foreground, status == 200 else { throw DJConnectHybridTransportError.unavailable }
        let recovery = try JSONDecoder().decode(DJConnectBroadcastRecovery.self, from: data)
        guard recovery.success, recovery.sessionID == sessionID,
              ["snapshot_required", "replayed"].contains(recovery.recovery),
              recovery.snapshot.map({ $0.session.sessionID == sessionID }) ?? true,
              recovery.events?.allSatisfy({ $0.sessionID == sessionID }) ?? true else { throw DJConnectHybridTransportError.invalidFrame }
        if recovery.recovery == "snapshot_required" { diagnostics.receivedSnapshotGap = true; report?(diagnostics) }
        return recovery
    }
    public func retainedReceipt(_ id: String) -> DJConnectOperationReceipt? { receipts[id] }
    public func lifecycle(foreground: Bool) async {
        guard self.foreground != foreground else { return }
        self.foreground = foreground
        generation = UUID(); routeTask?.cancel(); routeTask = nil; route = nil
        retryLocalAfter = 0; offlineRetryAfter = 0
        await action?.stop(); action = nil; actionURL = nil
        diagnostics.activeOrigin = nil
        state(.recoveringOffline)
        if foreground, !pendingIntents.isEmpty { Task { await self.reconcilePending() } }
    }
    public func reconcilePending() async {
        guard foreground else { return }
        let epoch = generation
        for (id, intent) in Array(pendingIntents.prefix(8)) {
            do {
                let route = try await readyRoute()
                guard epoch == generation, foreground, !Task.isCancelled else { return }
                let body: HybridObject = ["contract_version": .int(1), "operation_id": .string(id), "operation_epoch": .string(intent.epoch)]
                let result = try await wire.http(protectedRequest(route.url, path: "/api/djconnect/v1/transport/operation/status", body: body))
                _ = try accept(result, id: id, operationEpoch: intent.epoch, epoch: epoch)
            } catch DJConnectHybridTransportError.authority { return }
            catch { /* Retain uncertainty; resume never executes the original payload. */ }
        }
    }
    public static func canReplayLegacy(_ request: URLRequest) -> Bool {
        if ["GET", "HEAD"].contains(request.httpMethod ?? "GET") { return true }
        let path = request.url?.path ?? ""
        if ["/status", "/music_dna/profile", "/session/history/open"].contains(where: path.hasSuffix) { return true }
        if path.hasSuffix("/command"), let data = request.httpBody,
           let body = try? JSONDecoder().decode(HybridObject.self, from: data), let name = body["command"]?.hybridString {
            return ["status", "devices", "queue", "playlists", "search_playlists", "search_tracks", "search_albums", "search_media", "recently_played", "artist_recommendations", "listening_profile"].contains(name)
        }
        return false
    }
    public static func trustedOrigin(_ url: URL) -> Bool {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        return c.scheme == "https" && c.host?.isEmpty == false && c.user == nil && c.password == nil && c.query == nil && c.fragment == nil
    }
    /// Classifies a configured local candidate; it does not grant transport authority.
    public static func isLocalTransportCandidate(_ url: URL) -> Bool {
        DJConnectHybridLocalPolicy.isLocalCandidate(url)
    }
    private func eligibleOrigin(_ url: URL) -> Bool {
        Self.trustedOrigin(url) || (url == localURL && Self.isLocalTransportCandidate(url))
    }
    public static func operation(for request: URLRequest) -> String? {
        guard request.httpMethod == "POST", let path = request.url?.path,
              let prefix = path.range(of: "/api/djconnect/v1/") else { return nil }
        let name = String(path[prefix.upperBound...])
        if name == "command" {
            guard let data = request.httpBody, let body = try? JSONDecoder().decode(HybridObject.self, from: data),
                  let command = body["command"]?.hybridString,
                  ["set_output", "play", "play_uris", "pause", "next", "previous", "set_volume", "volume_delta", "save_current_track", "set_current_track_favorite", "toggle_current_track_favorite", "set_shuffle", "set_repeat", "seek_relative", "ask_dj_play_recommendation", "ask_dj_play_recommendation_on_output", "ask_dj_play_request_on_output", "ask_dj_followup_response", "ask_dj_message"].contains(command) else { return nil }
        }
        return ["command", "ask_dj/message", "track_insight", "session/start", "session/end", "session/mood", "session/presence", "session/speech/play"].contains(name) ? name : nil
    }
    public static func isActiveRead(_ request: URLRequest) -> Bool {
        request.httpMethod == "GET" && request.url?.path.hasSuffix("/api/djconnect/v1/session/active") == true
    }
    private func state(_ state: DJConnectHybridDiagnostics.State) {
        diagnostics.state = state
        if state == .recoveringOffline || state == .terminalAuthorityWithdrawn {
            diagnostics.activeOrigin = nil; diagnostics.websocketConnected = false
        }
        report?(diagnostics)
    }
    private func urlIsLocal(_ url: URL) -> Bool {
        url == localURL && (Self.isLocalTransportCandidate(url) || DJConnectHomeAssistantWebSocketFastPath.isLocalHomeAssistantURL(url))
    }
    private func protectedRequest(_ base: URL, path: String, body: HybridObject) throws -> URLRequest {
        guard eligibleOrigin(base), !expectedInstallID.isEmpty else { throw DJConnectHybridTransportError.untrustedRoute }
        var c = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        c.path = path; c.query = nil; c.fragment = nil
        var request = URLRequest(url: c.url!); request.httpMethod = "POST"
        request.timeoutInterval = path.hasSuffix("/transport/context")
            ? (urlIsLocal(base) ? 2 : 8) : 15
        guard let token = try tokenStore.loadToken(), !token.isEmpty else { throw DJConnectError.missingToken }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(identity.deviceID, forHTTPHeaderField: "X-DJConnect-Device-ID")
        request.setValue(identity.clientType.rawValue, forHTTPHeaderField: "X-DJConnect-Client-Type")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        var body = body
        body["identity"] = .object(["device_id": .string(identity.deviceID), "client_type": .string(identity.clientType.rawValue)])
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
    private func checkAuthority(_ body: HybridObject, status: Int) throws {
        let code = body["error"]?.hybridString ?? "transport_unavailable"
        if status == 426, code == "transport_security_required" {
            throw DJConnectHybridTransportError.routeWithdrawn
        }
        if ["unauthorized", "pairing_revoked", "profile_unavailable", "profile_device_mismatch", "operation_context_changed"].contains(code), [401,403].contains(status) {
            state(.terminalAuthorityWithdrawn)
            throw DJConnectHybridTransportError.authority(code)
        }
        // An unqualified 401/socket lease/proxy failure is never a pairing-reset instruction.
    }
    private func qualify(_ url: URL, local: Bool) async throws -> Route {
        diagnostics.probes += 1
        let (data, status) = try await wire.http(protectedRequest(url, path: "/api/djconnect/v1/transport/context", body: ["contract_version": .int(1)]))
        try Task.checkCancellation()
        let body = try JSONDecoder().decode(HybridObject.self, from: data)
        try checkAuthority(body, status: status)
        guard status == 200, body["success"] == .bool(true), body["contract_version"] == .int(1),
              DJConnectHybridLocalPolicy.acceptsContext(body, origin: url, pairedLocalOrigin: local ? localURL : nil), body["operation_lifetime_ms"] == .int(300_000),
              body["operation_epoch"]?.hybridString?.isEmpty == false, let clock = body["server_time_ms"]?.hybridInt else { throw DJConnectHybridTransportError.unavailable }
        guard body["ha_install_id"] == .string(expectedInstallID) else { throw DJConnectHybridTransportError.installationMismatch }
        return Route(url: url, local: local && (Self.isLocalTransportCandidate(url) || DJConnectHomeAssistantWebSocketFastPath.isLocalHomeAssistantURL(url)), context: body, clock: clock, anchor: ProcessInfo.processInfo.systemUptime)
    }
    private func readyRoute() async throws -> Route {
        guard foreground else { throw CancellationError() }
        let now = ProcessInfo.processInfo.systemUptime
        if let route, now - route.anchor < 60, route.local || now < retryLocalAfter { return route }
        if let routeTask { return try await routeTask.value }
        guard now >= offlineRetryAfter else { throw DJConnectHybridTransportError.unavailable }
        let epoch = generation
        let task = Task { try await self.selectRoute() }
        routeTask = task
        defer { if generation == epoch { routeTask = nil } }
        let chosen = try await task.value
        guard generation == epoch, foreground else { throw CancellationError() }
        route = chosen
        diagnostics.activeOrigin = chosen.url
        if chosen.local { retryDelay = 15; state(.localReady) }
        else { retryLocalAfter = now + retryDelay; retryDelay = min(60, retryDelay * 2); state(.remoteReady) }
        return chosen
    }
    private func selectRoute() async throws -> Route {
        var candidates: [(URL, Bool)] = []
        if let localURL, eligibleOrigin(localURL) { candidates.append((localURL, true)) }
        if let remoteURL, Self.trustedOrigin(remoteURL), remoteURL != localURL { candidates.append((remoteURL, false)) }
        for (url, local) in candidates {
            if (withdrawnOrigins[url] ?? 0) > ProcessInfo.processInfo.systemUptime { continue }
            do { return try await qualify(url, local: local) }
            catch let error as DJConnectHybridTransportError {
                if case .routeWithdrawn = error { withdrawOrigin(url) }
                if case .authority = error { throw error }
                if error == .installationMismatch || error == .untrustedRoute { throw error }
            } catch is CancellationError { throw CancellationError() }
            catch { /* Only pre-operation reachability loss permits trying another configured origin. */ }
            if local { state(.localDegraded) }
        }
        try Task.checkCancellation()
        offlineRetryAfter = ProcessInfo.processInfo.systemUptime + min(60, retryDelay)
        retryDelay = min(60, retryDelay * 2)
        state(.recoveringOffline); throw DJConnectHybridTransportError.unavailable
    }
    private func connection(_ route: Route) async throws -> DJConnectPairedActionConnection {
        if actionURL == route.url, let action { return action }
        await action?.stop()
        let connectionEpoch = UUID(); actionGeneration = connectionEpoch
        let next = DJConnectPairedActionConnection(baseURL: route.url, expectedInstallID: expectedInstallID,
            identity: identity, tokenStore: tokenStore, wire: wire,
            qualifiedLocalHTTP: route.url.scheme == "http" && DJConnectHybridLocalPolicy.acceptsContext(route.context, origin: route.url, pairedLocalOrigin: localURL),
            reportClosed: { [weak self] reason in await self?.actionClosed(connectionEpoch, reason: reason) })
        action = next; actionURL = route.url
        return next
    }
    private func withdrawOrigin(_ url: URL) {
        withdrawnOrigins[url] = ProcessInfo.processInfo.systemUptime + 60
        if route?.url == url { route = nil }
        diagnostics.activeOrigin = nil
        diagnostics.websocketConnected = false
        state(.recoveringOffline)
    }
    private func actionClosed(_ epoch: UUID, reason: DJConnectHybridTransportError?) {
        guard actionGeneration == epoch else { return }
        if reason == .routeWithdrawn, let url = actionURL { withdrawOrigin(url) }
        diagnostics.websocketConnected = false
        report?(diagnostics)
    }
    private func canUseActions(_ route: Route) -> Bool {
        route.local
    }
    /// Returns the original handler body/status. Receipt-only acceptance is a typed outcome,
    /// never decoded as a second answer or converted to another execute request.
    public func perform(_ request: URLRequest) async throws -> (Data, Int) {
        try await perform(request, operation: nil, payload: nil, onOperationID: nil)
    }
    /// These operations have no legacy endpoint. Preserve the ordinary operation
    /// owner's identity, capacity, route qualification and uncertain-send recovery.
    public func performPersonaReaction(_ operation: DJConnectPersonaReactionOperation, payload: Data,
                                      onOperationID: (@Sendable (String) -> Void)? = nil) async throws -> (Data, Int) {
        guard payload.count <= 60_000 else { throw DJConnectHybridTransportError.capacity }
        let body = try JSONDecoder().decode(HybridObject.self, from: payload)
        return try await perform(nil, operation: operation.rawValue, payload: body, onOperationID: onOperationID)
    }
    private func perform(_ request: URLRequest?, operation suppliedOperation: String?, payload suppliedPayload: HybridObject?,
                         onOperationID: (@Sendable (String) -> Void)?) async throws -> (Data, Int) {
        try Task.checkCancellation()
        guard inFlight < 8 else { throw DJConnectHybridTransportError.capacity }
        inFlight += 1
        defer { inFlight -= 1 }
        let epoch = generation
        let route = try await readyRoute()
        guard epoch == generation, foreground, !Task.isCancelled else { throw CancellationError() }
        if let request, Self.isActiveRead(request) { return try await activeRead(request, route: route, epoch: epoch) }
        guard let operation = suppliedOperation ?? request.flatMap(Self.operation(for:)),
              route.context["http_operations"]?.hybridStrings.contains(operation) == true,
              var payload = suppliedPayload ?? request?.httpBody.flatMap({ try? JSONDecoder().decode(HybridObject.self, from: $0) }) else { throw DJConnectHybridTransportError.unavailable }
        // Existing identified envelopes may include device_token; the transport owns authentication.
        if let originalPayload = payload["payload"]?.hybridObject { payload = originalPayload }
        for key in ["device_token", "identity", "client_id", "device_name"] { payload.removeValue(forKey: key) }
        guard (try JSONEncoder().encode(payload)).count <= 60_000 else { throw DJConnectHybridTransportError.capacity }
        let nowMS = route.clock + Int((ProcessInfo.processInfo.systemUptime - route.anchor) * 1000)
        if receipts.count >= 256, let expired = receipts.values.filter({ $0.expiresAtMS <= nowMS }).min(by: { $0.expiresAtMS < $1.expiresAtMS }) { receipts.removeValue(forKey: expired.operationID) }
        pendingIntents = pendingIntents.filter { $0.value.expires > nowMS }
        guard receipts.count + pendingIntents.count < 256 else { throw DJConnectHybridTransportError.capacity }
        let id = DJConnectOperationIdentity.uuidV7(milliseconds: nowMS)
        let operationEpoch = route.context["operation_epoch"]!.hybridString!
        onOperationID?(id)
        let envelope: HybridObject = ["contract_version": .int(1), "operation_id": .string(id), "operation_epoch": .string(operationEpoch), "operation": .string(operation), "payload": .object(payload)]
        pendingIntents[id] = (operationEpoch, nowMS + 300_000)
        var response: (Data, Int)?
        var possibleSend = false
        var routeWithdrawn = false
        if canUseActions(route), route.context["action_operations"]?.hybridStrings.contains(operation) == true {
            do {
                let socket = try await connection(route)
                try await socket.prepare()
                guard epoch == generation, foreground, !Task.isCancelled else { throw CancellationError() }
                possibleSend = true
                response = try await socket.request(type: "djconnect/operation/execute", body: envelope)
                diagnostics.websocketConnected = true; report?(diagnostics)
            } catch DJConnectHybridTransportError.routeWithdrawn {
                withdrawOrigin(route.url); routeWithdrawn = true
            } catch DJConnectHybridTransportError.notSent { possibleSend = false }
            catch DJConnectHybridTransportError.capacity { possibleSend = false }
            catch is CancellationError { throw CancellationError() }
            catch { if possibleSend { response = nil } }
        }
        if routeWithdrawn, !possibleSend {
            pendingIntents.removeValue(forKey: id)
            throw DJConnectHybridTransportError.routeWithdrawn
        }
        if response == nil, !possibleSend {
            guard epoch == generation, foreground, !Task.isCancelled else { throw CancellationError() }
            // Once handed to URLSession, even an apparent pre-connect error is conservatively uncertain.
            possibleSend = true
            do { response = try await wire.http(protectedRequest(route.url, path: "/api/djconnect/v1/transport/operation", body: envelope)) }
            catch is CancellationError { throw CancellationError() }
            catch { response = nil }
        }
        if let response {
            do { return try accept(response, id: id, operationEpoch: operationEpoch, epoch: epoch) }
            catch DJConnectHybridTransportError.outcome(let receipt) where ["accepted", "sent_unknown"].contains(receipt.phase) { }
            catch DJConnectHybridTransportError.routeWithdrawn { withdrawOrigin(route.url) }
        }
        diagnostics.reconciliations += 1; diagnostics.websocketConnected = false
        await action?.stop(); action = nil; actionURL = nil; self.route = nil
        // Deliberately no second execute. Reconcile original ID/epoch, even across restart.
        let statusBody: HybridObject = ["contract_version": .int(1), "operation_id": .string(id), "operation_epoch": .string(operationEpoch)]
        for attempt in 0..<3 {
            guard epoch == generation, foreground, !Task.isCancelled else { throw CancellationError() }
            if attempt > 0 { try await Task.sleep(for: .milliseconds(250 * attempt)) }
            do {
                let recovered = try await readyRoute()
                let result = try await wire.http(protectedRequest(recovered.url, path: "/api/djconnect/v1/transport/operation/status", body: statusBody))
                if result.1 == 202 { continue }
                return try accept(result, id: id, operationEpoch: operationEpoch, epoch: epoch)
            } catch let error as DJConnectHybridTransportError {
                switch error { case .outcome, .authority, .installationMismatch, .untrustedRoute: throw error; default: break }
            } catch is CancellationError { throw CancellationError() }
            catch { }
        }
        throw DJConnectHybridTransportError.deliveryUnknown
    }
    private func accept(_ result: (Data, Int), id: String, operationEpoch: String, epoch: UUID) throws -> (Data, Int) {
        guard epoch == generation, foreground, !Task.isCancelled else { throw CancellationError() }
        let body = try JSONDecoder().decode(HybridObject.self, from: result.0)
        try checkAuthority(body, status: result.1)
        guard let value = body["operation_receipt"] else {
            if let known = receipts[id], known.phase == "confirmed" { throw DJConnectHybridTransportError.outcome(known) }
            if result.1 >= 400 { return result }
            throw DJConnectHybridTransportError.deliveryUnknown
        }
        let receipt = try JSONDecoder().decode(DJConnectOperationReceipt.self, from: JSONEncoder().encode(value))
        guard receipt.contractVersion == 1, receipt.operationID == id, receipt.operationEpoch == operationEpoch,
              ["accepted", "sent_unknown", "confirmed", "rejected", "cancelled", "unknown"].contains(receipt.phase) else { throw DJConnectHybridTransportError.invalidFrame }
        if receipts[id]?.phase != "confirmed" { receipts[id] = receipt }
        if !["accepted", "sent_unknown"].contains(receipt.phase) { pendingIntents.removeValue(forKey: id) }
        guard receipt.resultAvailable, body["result_available"] == .bool(true) else { throw DJConnectHybridTransportError.outcome(receipts[id] ?? receipt) }
        return result
    }
    private func activeRead(_ original: URLRequest, route: Route, epoch: UUID) async throws -> (Data, Int) {
        if canUseActions(route), route.context["read_operations"]?.hybridStrings.contains("session/active") == true {
            do {
                let socket = try await connection(route)
                let result = try await socket.request(type: "djconnect/read", body: ["operation": .string("session/active"), "payload": .object([:])])
                guard epoch == generation, foreground, !Task.isCancelled else { throw CancellationError() }
                diagnostics.websocketConnected = true; report?(diagnostics)
                return result
            } catch is CancellationError { throw CancellationError() }
            catch DJConnectHybridTransportError.routeWithdrawn {
                withdrawOrigin(route.url)
                let recovered = try await readyRoute()
                return try await activeRead(original, route: recovered, epoch: epoch)
            }
            catch { diagnostics.websocketConnected = false }
        }
        var r = try protectedRequest(route.url, path: "/api/djconnect/v1/session/active", body: [:])
        r.httpMethod = "GET"; r.httpBody = nil
        var url = URLComponents(url: r.url!, resolvingAgainstBaseURL: false)!
        url.queryItems = [URLQueryItem(name: "device_id", value: identity.deviceID), URLQueryItem(name: "client_type", value: identity.clientType.rawValue)]
        r.url = url.url
        let result = try await wire.http(r)
        guard epoch == generation, foreground, !Task.isCancelled else { throw CancellationError() }
        if result.1 == 426, let body = try? JSONDecoder().decode(HybridObject.self, from: result.0),
           body["error"] == .string("transport_security_required") {
            withdrawOrigin(route.url)
            let recovered = try await readyRoute()
            return try await activeRead(original, route: recovered, epoch: epoch)
        }
        return result
    }
}

extension DJConnectHybridTransportError: LocalizedError {
    public var localizationKey: String {
        switch self {
        case .outcome(let receipt) where receipt.phase == "confirmed": return "ui.transport.confirmed_no_body"
        case .outcome, .deliveryUnknown: return "ui.transport.uncertain"
        case .installationMismatch, .untrustedRoute: return "ui.transport.untrusted"
        default: return "ui.transport.recovering"
        }
    }
    public var errorDescription: String? { DJConnectLocalization.localized(key: localizationKey, language: Locale.current.language.languageCode?.identifier ?? "en") }
}
