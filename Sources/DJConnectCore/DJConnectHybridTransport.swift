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

// A local observation budget never renews the server operation. All branches
// check it again after awaits; expiry cancels the actual Foundation task/waiter.
struct DJConnectOperationTiming: Sendable {
    private static let origin = ContinuousClock.now
    private static func seconds() -> TimeInterval {
        let elapsed = origin.duration(to: ContinuousClock.now).components
        return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
    }
    // ContinuousClock also advances across system suspension. UI foreground
    // cancellation and original server expiry remain independent fences.
    var now: @Sendable () -> TimeInterval = { DJConnectOperationTiming.seconds() }
    var sleep: @Sendable (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }
}
struct DJConnectOperationDeadline: Sendable {
    let end: TimeInterval
    let timing: DJConnectOperationTiming
    init(seconds: TimeInterval = 300, timing: DJConnectOperationTiming = .init()) {
        self.timing = timing; end = timing.now() + seconds
    }
    init(end: TimeInterval, timing: DJConnectOperationTiming) { self.end = end; self.timing = timing }
    var remaining: TimeInterval { max(0, end - timing.now()) }
    func check() throws {
        try Task.checkCancellation()
        guard remaining > 0 else { throw DJConnectHybridTransportError.deliveryUnknown }
    }
    func run<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try check()
        let race = DJConnectDeadlineRace<T>()
        let seconds = remaining
        let value = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                race.start(continuation, seconds: seconds, operation: operation)
            }
        } onCancel: { race.finish(.failure(CancellationError())) }
        try check()
        return value
    }
}
// Continuation ownership is independent of a shared route/connection task's
// cooperative cancellation. A late child is cancelled and cannot dispatch after
// its next deadline check; it cannot retain or return a private result to caller.
private final class DJConnectDeadlineRace<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?
    private var result: Result<T, Error>?
    private var tasks: [Task<Void, Never>] = []
    func start(_ next: CheckedContinuation<T, Error>, seconds: TimeInterval,
               operation: @escaping @Sendable () async throws -> T) {
        let ready = lock.withLock { () -> Result<T, Error>? in
            if let result { return result }; continuation = next; return nil
        }
        if let ready { next.resume(with: ready); return }
        let work = Task {
            do { try Task.checkCancellation(); self.finish(.success(try await operation())) }
            catch { self.finish(.failure(error)) }
        }
        let timer = Task {
            do { try await Task.sleep(for: .seconds(seconds)) }
            catch { return }
            self.finish(.failure(DJConnectHybridTransportError.deliveryUnknown))
        }
        let cancel = lock.withLock { () -> Bool in
            guard result == nil else { return true }; tasks = [work, timer]; return false
        }
        if cancel { work.cancel(); timer.cancel() }
    }
    func finish(_ value: Result<T, Error>) {
        let owned = lock.withLock { () -> (CheckedContinuation<T, Error>?, [Task<Void, Never>]) in
            guard result == nil else { return (nil, []) }
            result = value; let next = continuation; continuation = nil
            let old = tasks; tasks = []; return (next, old)
        }
        owned.1.forEach { $0.cancel() }; owned.0?.resume(with: value)
    }
}

enum DJConnectAskDJDispatchResult: Sendable {
    case response(Data, Int)
    case legacy(DJConnectOperationDeadline)
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
        c.timeoutIntervalForResource = 300
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
    private var conversationTasks: [UUID: @Sendable () -> Void] = [:]
    private var legacyContextAbsent: [URL: TimeInterval] = [:]
    private var offlineRetryAfter: TimeInterval = 0
    private var action: DJConnectPairedActionConnection?
    private var actionURL: URL?
    private var reactionObserver: DJConnectPairedActionConnection?
    private var actionGeneration = UUID()
    private var receipts: [String: DJConnectOperationReceipt] = [:]
    private var timing = DJConnectOperationTiming()
    // Internal deterministic test seam; configured before starting any operation.
    func setOperationTiming(_ value: DJConnectOperationTiming) { timing = value }
    // Compact uncertainty metadata only; payload/result bodies never survive a call.
    private var pendingIntents: [String: (epoch: String, expires: Int, deadline: TimeInterval)] = [:]
    private var receiptEnds: [String: TimeInterval] = [:]

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
        conversationTasks.values.forEach { $0() }; conversationTasks = [:]
        legacyContextAbsent = [:]
        retryLocalAfter = 0; offlineRetryAfter = 0
        await action?.stop(); action = nil; actionURL = nil
        await reactionObserver?.stop(); reactionObserver = nil
        diagnostics.activeOrigin = nil
        state(.recoveringOffline)
        if foreground, !pendingIntents.isEmpty { Task { await self.reconcilePending() } }
    }
    public func reconcilePending() async {
        guard foreground else { return }
        let epoch = generation
        for (id, intent) in Array(pendingIntents.prefix(8)) {
            do {
                let deadline = DJConnectOperationDeadline(end: min(intent.deadline, receiptEnds[id] ?? intent.deadline), timing: timing)
                let route = try await deadline.run { try await self.readyRoute() }
                try deadline.check()
                guard epoch == generation, foreground, !Task.isCancelled else { return }
                let body: HybridObject = ["contract_version": .int(1), "operation_id": .string(id), "operation_epoch": .string(intent.epoch)]
                var request = try protectedRequest(route.url, path: "/api/djconnect/v1/transport/operation/status", body: body)
                request.timeoutInterval = min(request.timeoutInterval, deadline.remaining)
                let fixed = request
                let result = try await deadline.run { try await self.wire.http(fixed) }
                _ = try accept(result, id: id, operationEpoch: intent.epoch, epoch: epoch, receiptClock: route)
            } catch DJConnectHybridTransportError.authority { return }
            catch { /* Retain uncertainty; resume never executes the original payload. */ }
        }
    }
    static func isAskDJText(_ request: URLRequest) -> Bool {
        guard request.httpMethod == "POST" else { return false }
        if request.url?.path.hasSuffix("/ask_dj/message") == true { return true }
        guard request.url?.path.hasSuffix("/command") == true, let data = request.httpBody,
              let body = try? JSONDecoder().decode(HybridObject.self, from: data) else { return false }
        return body["command"] == .string("ask_dj_message")
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
            ? (urlIsLocal(base) ? 2 : 8)
            : (body["operation"] == .string("ask_dj/message") ? 120 : 15)
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
        legacyContextAbsent.removeValue(forKey: url)
        let (data, status) = try await wire.http(protectedRequest(url, path: "/api/djconnect/v1/transport/context", body: ["contract_version": .int(1)]))
        try Task.checkCancellation()
        // A real missing transport endpoint is compatibility evidence only.
        // Network errors, malformed context, 401/403/426 and trust failures
        // never authorize a downgrade to legacy execution.
        if status == 404 {
            legacyContextAbsent[url] = timing.now()
            throw DJConnectHybridTransportError.unavailable
        }
        let body = try JSONDecoder().decode(HybridObject.self, from: data)
        try checkAuthority(body, status: status)
        guard status == 200, body["success"] == .bool(true), body["contract_version"] == .int(1),
              DJConnectHybridLocalPolicy.acceptsContext(body, origin: url, pairedLocalOrigin: local ? localURL : nil), body["operation_lifetime_ms"] == .int(300_000),
              body["operation_epoch"]?.hybridString?.isEmpty == false, let clock = body["server_time_ms"]?.hybridInt else { throw DJConnectHybridTransportError.unavailable }
        guard body["ha_install_id"] == .string(expectedInstallID) else { throw DJConnectHybridTransportError.installationMismatch }
        return Route(url: url, local: local && (Self.isLocalTransportCandidate(url) || DJConnectHomeAssistantWebSocketFastPath.isLocalHomeAssistantURL(url)), context: body, clock: clock, anchor: timing.now())
    }
    private func readyRoute() async throws -> Route {
        guard foreground else { throw CancellationError() }
        let now = timing.now()
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
            if (withdrawnOrigins[url] ?? 0) > timing.now() { continue }
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
        offlineRetryAfter = timing.now() + min(60, retryDelay)
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
        withdrawnOrigins[url] = timing.now() + 60
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
        if Self.isAskDJText(request) {
            let deadline = DJConnectOperationDeadline(timing: timing)
            return try await boundedConversation(deadline) {
                try await self.perform(request, operation: nil, payload: nil, onOperationID: nil, deadline: deadline)
            }
        }
        return try await perform(request, operation: nil, payload: nil, onOperationID: nil)
    }
    private func boundedConversation<T: Sendable>(_ deadline: DJConnectOperationDeadline,
        operation: @escaping @Sendable () async throws -> T) async throws -> T {
        guard conversationTasks.count < 8 else { throw DJConnectHybridTransportError.capacity }
        let id = UUID()
        let task = Task { try await deadline.run(operation) }
        conversationTasks[id] = { task.cancel() }
        defer { conversationTasks.removeValue(forKey: id) }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }
    /// The only downgrade is chosen BEFORE execute and only for a configured
    /// origin with an actual absent context endpoint. Carry the original budget
    /// to the client's single legacy attempt; never catch post-execute failures.
    func dispatchAskDJ(_ request: URLRequest, legacyOrigin: URL) async throws -> DJConnectAskDJDispatchResult {
        guard Self.isAskDJText(request) else { throw DJConnectHybridTransportError.unavailable }
        let deadline = DJConnectOperationDeadline(timing: timing), epoch = generation
        return try await boundedConversation(deadline) {
            try await self.selectAskDJDispatch(request, legacyOrigin: legacyOrigin, deadline: deadline, epoch: epoch)
        }
    }
    private func selectAskDJDispatch(_ request: URLRequest, legacyOrigin: URL,
        deadline: DJConnectOperationDeadline, epoch: UUID) async throws -> DJConnectAskDJDispatchResult {
        // A previous absence is never a new submission's proof. Permit a new
        // explicit preflight on an older server despite ordinary offline backoff.
        if legacyContextAbsent.removeValue(forKey: legacyOrigin) != nil { offlineRetryAfter = 0 }
        do { _ = try await readyRoute() }
        catch DJConnectHybridTransportError.unavailable {
            try deadline.check()
            guard epoch == generation, foreground,
                  let observed = legacyContextAbsent[legacyOrigin], observed >= deadline.end - 300,
                  timing.now() - observed < 30,
                  (withdrawnOrigins[legacyOrigin] ?? 0) <= timing.now() else { throw DJConnectHybridTransportError.unavailable }
            return .legacy(deadline)
        }
        try deadline.check()
        guard epoch == generation, foreground else { throw CancellationError() }
        let (data, status) = try await perform(request, operation: nil, payload: nil, onOperationID: nil, deadline: deadline)
        return .response(data, status)
    }
    /// These operations have no legacy endpoint. Preserve the ordinary operation
    /// owner's identity, capacity, route qualification and uncertain-send recovery.
    public func observePersonaReaction(_ result: DJConnectPersonaReactionResult) async throws -> DJConnectPersonaReactionObservation {
        let route = try await readyRoute(), epoch = generation
        await reactionObserver?.stop()
        let observer = DJConnectPairedActionConnection(baseURL: route.url, expectedInstallID: expectedInstallID,
            identity: identity, tokenStore: tokenStore, wire: wire,
            qualifiedLocalHTTP: route.url.scheme == "http" && DJConnectHybridLocalPolicy.acceptsContext(route.context, origin: route.url, pairedLocalOrigin: localURL))
        reactionObserver = observer
        do {
            let observation = try await observer.observePersonaReaction(result)
            guard generation == epoch, foreground, !Task.isCancelled else { await observation.close(); throw CancellationError() }
            return observation
        } catch { await observer.stop(); throw error }
    }

    public func performPersonaReaction(_ operation: DJConnectPersonaReactionOperation, payload: Data,
                                      onOperationID: (@Sendable (String) -> Void)? = nil) async throws -> (Data, Int) {
        guard payload.count <= 60_000 else { throw DJConnectHybridTransportError.capacity }
        let body = try JSONDecoder().decode(HybridObject.self, from: payload)
        return try await perform(nil, operation: operation.rawValue, payload: body, onOperationID: onOperationID)
    }
    private func perform(_ request: URLRequest?, operation suppliedOperation: String?, payload suppliedPayload: HybridObject?,
                         onOperationID: (@Sendable (String) -> Void)?, deadline originalDeadline: DJConnectOperationDeadline? = nil) async throws -> (Data, Int) {
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
        try originalDeadline?.check()
        let nowMS = route.clock + Int((timing.now() - route.anchor) * 1000)
        let operationStarted = timing.now()
        if receipts.count >= 256, let expired = receipts.values.filter({ $0.expiresAtMS <= nowMS }).min(by: { $0.expiresAtMS < $1.expiresAtMS }) { receipts.removeValue(forKey: expired.operationID); receiptEnds.removeValue(forKey: expired.operationID) }
        pendingIntents = pendingIntents.filter { $0.value.expires > nowMS }
        guard receipts.count + pendingIntents.count < 256 else { throw DJConnectHybridTransportError.capacity }
        let id = DJConnectOperationIdentity.uuidV7(milliseconds: nowMS)
        let operationEpoch = route.context["operation_epoch"]!.hybridString!
        onOperationID?(id)
        let envelope: HybridObject = ["contract_version": .int(1), "operation_id": .string(id), "operation_epoch": .string(operationEpoch), "operation": .string(operation), "payload": .object(payload)]
        pendingIntents[id] = (operationEpoch, nowMS + 300_000, originalDeadline?.end ?? operationStarted + 300)
        var response: (Data, Int)?
        var possibleSend = false
        var routeWithdrawn = false
        if canUseActions(route), route.context["action_operations"]?.hybridStrings.contains(operation) == true {
            do {
                let socket = try await connection(route)
                try await socket.prepare()
                try originalDeadline?.check()
                guard epoch == generation, foreground, !Task.isCancelled else { throw CancellationError() }
                possibleSend = true
                response = try await socket.request(type: "djconnect/operation/execute", body: envelope, timeout: originalDeadline.map { min(120, $0.remaining) })
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
            do {
                try originalDeadline?.check()
                var execute = try protectedRequest(route.url, path: "/api/djconnect/v1/transport/operation", body: envelope)
                if let originalDeadline { execute.timeoutInterval = min(execute.timeoutInterval, originalDeadline.remaining) }
                response = try await wire.http(execute)
            }
            catch is CancellationError { throw CancellationError() }
            catch { response = nil }
        }
        try originalDeadline?.check()
        if let response {
            do { return try accept(response, id: id, operationEpoch: operationEpoch, epoch: epoch, receiptClock: originalDeadline == nil ? nil : route) }
            catch DJConnectHybridTransportError.outcome(let receipt) where ["accepted", "sent_unknown"].contains(receipt.phase) { }
            catch DJConnectHybridTransportError.routeWithdrawn { withdrawOrigin(route.url) }
        }
        diagnostics.reconciliations += 1; diagnostics.websocketConnected = false
        let oldAction = action
        action = nil; actionURL = nil; actionGeneration = UUID(); self.route = nil
        // Closing a spent socket is not a new lease or part of the result wait.
        Task { await oldAction?.stop() }
        // Deliberately no second execute. Reconcile original ID/epoch, even across restart.
        let statusBody: HybridObject = ["contract_version": .int(1), "operation_id": .string(id), "operation_epoch": .string(operationEpoch)]
        let isConversation = originalDeadline != nil
        let reconciliationDeadline = originalDeadline?.end ?? min(operationStarted + 300, timing.now() + 120)
        var attempt = 0
        while isConversation || attempt < 3 {
            guard epoch == generation, foreground, !Task.isCancelled else { throw CancellationError() }
            let receiptDeadline = receiptEnds[id] ?? receipts[id].map { route.anchor + Double($0.expiresAtMS-route.clock)/1000 } ?? operationStarted + 300
            let deadline = min(reconciliationDeadline, receiptDeadline)
            if isConversation, timing.now() >= deadline { break }
            if attempt > 0 {
                let delay = isConversation ? min(2.0, Double(attempt)*0.25) : Double(attempt)*0.25
                let remaining = deadline-timing.now()
                if isConversation, remaining <= 0 { break }
                try await timing.sleep(isConversation ? min(delay,remaining) : delay)
            }
            attempt += 1
            do {
                let bounded = DJConnectOperationDeadline(end: deadline, timing: timing)
                let recovered = isConversation ? try await bounded.run { try await self.readyRoute() } : try await readyRoute()
                if isConversation { try bounded.check() }
                var request = try protectedRequest(recovered.url, path: "/api/djconnect/v1/transport/operation/status", body: statusBody)
                if isConversation {
                    let remaining = deadline-timing.now()
                    guard remaining > 0 else { break }
                    request.timeoutInterval = min(request.timeoutInterval,remaining)
                }
                let result: (Data, Int)
                if isConversation {
                    let bounded = DJConnectOperationDeadline(end: deadline, timing: timing)
                    let fixed = request
                    result = try await bounded.run { try await self.wire.http(fixed) }
                } else { result = try await wire.http(request) }
                try originalDeadline?.check()
                guard !isConversation || timing.now() < deadline else { throw DJConnectHybridTransportError.deliveryUnknown }
                return try accept(result, id: id, operationEpoch: operationEpoch, epoch: epoch, receiptClock: originalDeadline == nil ? nil : route)
            } catch let error as DJConnectHybridTransportError {
                switch error {
                case .outcome(let receipt) where ["accepted", "sent_unknown"].contains(receipt.phase):
                    // Status is a read of this original operation, never a new
                    // execution or a fresh lease. Keep awaiting its outcome.
                    continue
                case .outcome, .authority, .installationMismatch, .untrustedRoute, .invalidFrame: throw error
                default: break
                }
            } catch is CancellationError { throw CancellationError() }
            catch { }
        }
        throw DJConnectHybridTransportError.deliveryUnknown
    }
    private func accept(_ result: (Data, Int), id: String, operationEpoch: String, epoch: UUID, receiptClock: Route? = nil) throws -> (Data, Int) {
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
        if let receiptClock {
            let expires = receiptClock.anchor + Double(receipt.expiresAtMS - receiptClock.clock) / 1000
            let original = pendingIntents[id]?.deadline ?? expires
            let end = min(receiptEnds[id] ?? original, expires)
            receiptEnds[id] = end // Earlier expiry is sticky; a later receipt never renews it.
            guard end > timing.now() else { throw DJConnectHybridTransportError.deliveryUnknown }
        }
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
