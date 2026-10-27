import Foundation

/// Protocol1 paired_owner_actions. One reader and one serialized, bounded writer.
/// It never asks Home Assistant for an HA-wide access token.
actor DJConnectPairedActionConnection {
    private let baseURL: URL
    private let qualifiedLocalHTTP: Bool
    private let expectedInstallID: String
    private let identity: DJConnectIdentity
    private let tokenStore: DJConnectTokenStore
    private let wire: any DJConnectHybridWire
    private let reportClosed: (@Sendable (DJConnectHybridTransportError?) async -> Void)?
    private var socket: (any DJConnectHybridSocket)?
    private var connectionID: String?
    private var commands: Set<String> = []
    private var generation = UUID()
    private var connecting: Task<Void, Error>?
    private var reader: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    private var writer: Task<Void, Error>?
    private var reactionObservation: DJConnectPersonaReactionObservation?
    private var nextID = 1
    private var openedAt: TimeInterval = 0
    private var pending: [Int: CheckedContinuation<(Data, Int), Error>] = [:]
    private var timeouts: [Int: Task<Void, Never>] = [:]

    init(baseURL: URL, expectedInstallID: String, identity: DJConnectIdentity,
         tokenStore: DJConnectTokenStore, wire: any DJConnectHybridWire,
         qualifiedLocalHTTP: Bool = false,
         reportClosed: (@Sendable (DJConnectHybridTransportError?) async -> Void)? = nil) {
        self.qualifiedLocalHTTP = qualifiedLocalHTTP
        self.baseURL = baseURL; self.expectedInstallID = expectedInstallID
        self.identity = identity; self.tokenStore = tokenStore; self.wire = wire
        self.reportClosed = reportClosed
    }
    func stop(reason: DJConnectHybridTransportError? = nil) async {
        generation = UUID()
        reactionObservation?.invalidate(); reactionObservation = nil
        connecting?.cancel(); connecting = nil
        reader?.cancel(); reader = nil; heartbeat?.cancel(); heartbeat = nil
        writer?.cancel(); writer = nil
        let old = socket; socket = nil; connectionID = nil; nextID = 1
        failPending(reason ?? DJConnectHybridTransportError.deliveryUnknown)
        await old?.close()
        await reportClosed?(reason)
    }
    func prepare() async throws {
        if let connecting { try await connecting.value; return }
        if socket != nil, connectionID != nil, nextID <= 256,
           ProcessInfo.processInfo.systemUptime - openedAt < 285 { return }
        guard pending.isEmpty else { throw DJConnectHybridTransportError.capacity }
        // Install the shared connection task before the first await, including replacement.
        let old = socket
        generation = UUID(); let epoch = generation
        socket = nil; connectionID = nil; nextID = 1
        reader?.cancel(); heartbeat?.cancel(); writer?.cancel()
        let task = Task {
            await old?.close()
            try Task.checkCancellation()
            guard epoch == self.generation else { throw CancellationError() }
            try await self.open(epoch: epoch)
        }
        connecting = task
        defer { if generation == epoch { connecting = nil } }
        do { try await task.value }
        catch DJConnectHybridTransportError.routeWithdrawn {
            if generation == epoch { await stop(reason: .routeWithdrawn) }
            throw DJConnectHybridTransportError.routeWithdrawn
        }
        catch { if generation == epoch { await stop() }; throw DJConnectHybridTransportError.notSent }
    }
    private func open(epoch: UUID) async throws {
        guard DJConnectHybridTransport.trustedOrigin(baseURL) || (qualifiedLocalHTTP && DJConnectHybridLocalPolicy.isLocalCandidate(baseURL)),
              var url = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { throw DJConnectHybridTransportError.untrustedRoute }
        url.scheme = baseURL.scheme == "http" ? "ws" : "wss"; url.path = "/api/djconnect/v1/actions/paired"; url.query = nil; url.fragment = nil
        let channel = try await wire.socket(url.url!)
        // Closing the socket is what makes a pending Foundation receive terminate.
        let deadline = Task { try? await Task.sleep(for: .seconds(5)); if !Task.isCancelled { await channel.close() } }
        defer { deadline.cancel() }
        do {
        let required = try await frame(channel)
        guard required["type"] == .string("auth_required"), required["protocol_version"] == .int(1),
              required["audience"] == .string("paired_owner_actions"), epoch == generation,
              let token = try tokenStore.loadToken(), !token.isEmpty else { await channel.close(); throw DJConnectHybridTransportError.notSent }
        let auth: HybridObject = ["type": .string("auth"), "protocol_version": .int(1), "audience": .string("paired_owner_actions"),
                                  "device_id": .string(identity.deviceID), "client_type": .string(identity.clientType.rawValue), "device_token": .string(token)]
        try await channel.send(JSONEncoder().encode(auth))
        let accepted = try await frame(channel)
        if Self.isRouteWithdrawal(accepted) { throw DJConnectHybridTransportError.routeWithdrawn }
        if accepted["type"] == .string("auth_ok"),
           !DJConnectHybridLocalPolicy.acceptsContext(accepted, origin: baseURL, pairedLocalOrigin: qualifiedLocalHTTP ? baseURL : nil) {
            throw DJConnectHybridTransportError.routeWithdrawn
        }
        guard epoch == generation, accepted["type"] == .string("auth_ok"), accepted["protocol_version"] == .int(1),
              accepted["audience"] == .string("paired_owner_actions"), accepted["lease_seconds"] == .int(300),
              accepted["ha_install_id"] == .string(expectedInstallID),
              let id = accepted["connection_id"]?.hybridString, !id.isEmpty,
              Set(["djconnect/read", "djconnect/operation/execute", "djconnect/operation/status"]).isSubset(of: Set(accepted["commands"]?.hybridStrings ?? [])),
              Set(accepted["commands"]?.hybridStrings ?? []).isSubset(of: Set(["djconnect/read", "djconnect/operation/execute", "djconnect/operation/status", "djconnect/profile/settings/update", "djconnect/profile/settings/subscribe", "djconnect/persona/reaction/observe"])) else {
            await channel.close(); throw DJConnectHybridTransportError.notSent
        }
        commands = Set(accepted["commands"]?.hybridStrings ?? [])
        socket = channel; connectionID = id; openedAt = ProcessInfo.processInfo.systemUptime
        reader = Task { await self.readLoop(channel, epoch: epoch) }
        heartbeat = Task { await self.keepAlive(channel, epoch: epoch) }
        } catch { await channel.close(); throw error }
    }
    private func frame(_ channel: any DJConnectHybridSocket) async throws -> HybridObject {
        let data = try await channel.receive()
        guard data.count <= 65_536 else { throw DJConnectHybridTransportError.invalidFrame }
        return try JSONDecoder().decode(HybridObject.self, from: data)
    }
    func request(type: String, body: HybridObject, timeout: TimeInterval? = nil) async throws -> (Data, Int) {
        try Task.checkCancellation()
        try await prepare()
        guard pending.count < 8, nextID <= 256, let socket, let connectionID else { throw DJConnectHybridTransportError.capacity }
        let id = nextID; nextID += 1
        let epoch = generation
        var object = body; object["id"] = .int(id); object["type"] = .string(type)
        let data = try JSONEncoder().encode(object)
        guard data.count <= 65_536 else { throw DJConnectHybridTransportError.notSent }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                // Registered before enqueue/send, including immediate mock replies.
                pending[id] = continuation
                let previous = writer
                writer = Task {
                    do {
                        if let previous { try await previous.value }
                        try Task.checkCancellation()
                        try await self.sendPending(data, id: id, epoch: epoch, channel: socket, connectionID: connectionID)
                    } catch {
                        self.finish(id, epoch: epoch, error: DJConnectHybridTransportError.deliveryUnknown)
                        throw error
                    }
                }
                timeouts[id] = Task {
                    let seconds = timeout ?? (type == "djconnect/operation/execute" && body["operation"] == .string("ask_dj/message") ? 120 : 30)
                    do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
                    self.finish(id, epoch: epoch, error: DJConnectHybridTransportError.deliveryUnknown)
                }
            }
        } onCancel: { Task { await self.finish(id, epoch: epoch, error: CancellationError()) } }
    }
    func observePersonaReaction(_ result: DJConnectPersonaReactionResult) async throws -> DJConnectPersonaReactionObservation {
        try await prepare()
        guard commands.contains("djconnect/persona/reaction/observe"), reactionObservation == nil else {
            throw DJConnectHybridTransportError.unavailable
        }
        let observation = DJConnectPersonaReactionObservation(result: result, close: { [weak self] in await self?.stop() })
        reactionObservation = observation
        let requestID = nextID
        do {
            let (data, status) = try await request(type: "djconnect/persona/reaction/observe", body: [
                "contract_version": .int(1), "operation_id": .string(result.operation_receipt.operationID),
                "operation_epoch": .string(result.operation_receipt.operationEpoch),
                "session_id": .string(result.persona_reaction.session.session_id)
            ])
            struct Reply: Decodable { let success: Bool; let reaction_observation: DJConnectJSONValue }
            let reply = try JSONDecoder().decode(Reply.self, from: data)
            guard status == 200, reply.success else { throw DJConnectError.invalidResponse }
            try observation.accept(JSONEncoder().encode(reply.reaction_observation), requestID: requestID, initial: true)
            guard observation.isValid, !Task.isCancelled else { throw CancellationError() }
            return observation
        } catch { await stop(); throw error }
    }

    private func sendPending(_ data: Data, id: Int, epoch: UUID, channel: any DJConnectHybridSocket, connectionID: String) async throws {
        guard epoch == generation, self.connectionID == connectionID, pending[id] != nil else { return }
        do { try await channel.send(data) }
        catch { finish(id, epoch: epoch, error: DJConnectHybridTransportError.deliveryUnknown); throw error }
    }
    private func readLoop(_ channel: any DJConnectHybridSocket, epoch: UUID) async {
        do {
            while epoch == generation, !Task.isCancelled {
                let object = try await frame(channel)
                guard epoch == generation else { return }
                if Self.isRouteWithdrawal(object) { throw DJConnectHybridTransportError.routeWithdrawn }
                if object["type"] == .string("event"), let observation = reactionObservation {
                    guard object["event"] == .string("session/persona/reaction/withdrawn"),
                          object["connection_id"] == .string(connectionID ?? ""), object["id"] == .int(0),
                          object["reaction_observation"]?.hybridObject != nil else { throw DJConnectHybridTransportError.invalidFrame }
                    // A withdrawal event can race the initial result; never re-admit it.
                    observation.invalidate()
                    continue
                }
                guard object["type"] == .string("result"), object["connection_id"] == .string(connectionID ?? ""),
                      let id = object["id"]?.hybridInt, id > 0, id < nextID,
                      let status = object["status"]?.hybridInt, let result = object["result"] else {
                    throw DJConnectHybridTransportError.invalidFrame
                }
                // Replies to cancelled/timed-out requests are ignored, never shifted to another caller.
                guard let continuation = pending.removeValue(forKey: id) else { continue }
                timeouts.removeValue(forKey: id)?.cancel()
                continuation.resume(returning: (try JSONEncoder().encode(result), status))
            }
        } catch {
            guard epoch == generation else { return }
            await stop(reason: error as? DJConnectHybridTransportError)
        }
    }
    private static func isRouteWithdrawal(_ frame: HybridObject) -> Bool {
        frame["type"] == .string("auth_invalid") && frame["code"] == .string("transport_security_required")
    }
    private func keepAlive(_ channel: any DJConnectHybridSocket, epoch: UUID) async {
        while epoch == generation, !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            guard epoch == generation else { return }
            if ProcessInfo.processInfo.systemUptime - openedAt >= 285 { await stop(); return }
            let deadline = Task { try? await Task.sleep(for: .seconds(5)); if !Task.isCancelled { await channel.close() } }
            do { try await channel.ping(); deadline.cancel() }
            catch { deadline.cancel(); if epoch == generation { await stop() }; return }
        }
    }
    private func finish(_ id: Int, epoch: UUID, error: Error) {
        guard generation == epoch else { return }
        timeouts.removeValue(forKey: id)?.cancel()
        pending.removeValue(forKey: id)?.resume(throwing: error)
    }
    private func failPending(_ error: Error) {
        for timeout in timeouts.values { timeout.cancel() }; timeouts.removeAll()
        let values = pending.values; pending.removeAll()
        for continuation in values { continuation.resume(throwing: error) }
    }
}
