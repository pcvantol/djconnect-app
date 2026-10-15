import Foundation
import Testing
@testable import DJConnectCore

private func hybridIdentity() -> DJConnectIdentity {
    DJConnectIdentity(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Hybrid test", clientType: .ios,
                      firmware: "4.0.0", appVersion: "4.0.0", platform: .ios)
}
private func hybridContext(install: String = "test-install") -> HybridObject {
    ["success": .bool(true), "contract_version": .int(1), "ha_install_id": .string(install),
     "operation_epoch": .string("boot-1"), "server_time_ms": .int(Int(Date().timeIntervalSince1970 * 1000)),
     "operation_lifetime_ms": .int(300_000), "requires_authenticated_tls": .bool(true),
     "http_operations": .array(["command", "ask_dj/message", "track_insight", "session/start", "session/end", "session/mood", "session/presence"].map(DJConnectJSONValue.string)),
     "action_operations": .array(["command", "ask_dj/message", "track_insight", "session/mood", "session/presence"].map(DJConnectJSONValue.string)),
     "read_operations": .array([.string("session/active")])]
}
private func hybridReceipt(_ request: HybridObject, available: Bool, phase: String = "confirmed") -> HybridObject {
    ["contract_version": .int(1), "operation_id": request["operation_id"]!, "operation_epoch": request["operation_epoch"]!,
     "phase": .string(phase), "expires_at_ms": .int(Int(Date().timeIntervalSince1970 * 1000) + 300_000),
     "result_available": .bool(available), "response_status": .int(200), "error": .null]
}
private func hybridRequest(command: String = "next") throws -> URLRequest {
    var r = URLRequest(url: URL(string: "https://remote.example/api/djconnect/v1/command")!)
    r.httpMethod = "POST"; r.httpBody = try JSONEncoder().encode(["command": DJConnectJSONValue.string(command)])
    return r
}
private actor HybridTestWire: DJConnectHybridWire {
    var requests: [URLRequest] = []
    let install: String
    let failExecute: Bool
    let unavailableBody: Bool
    let failedLocal: Bool
    let withdrawExecute: Bool
    let socketValue: (any DJConnectHybridSocket)?
    init(install: String = "test-install", failExecute: Bool = false, unavailableBody: Bool = false,
         failedLocal: Bool = false, socket: (any DJConnectHybridSocket)? = nil, withdrawExecute: Bool = false) {
        self.install = install; self.failExecute = failExecute; self.unavailableBody = unavailableBody
        self.withdrawExecute = withdrawExecute
        self.failedLocal = failedLocal; self.socketValue = socket
    }
    func http(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        if failedLocal, request.url?.host == "ha.local" { throw URLError(.cannotConnectToHost) }
        let body = try JSONDecoder().decode(HybridObject.self, from: request.httpBody ?? Data("{}".utf8))
        if request.url!.path.hasSuffix("/context") { return (try JSONEncoder().encode(hybridContext(install: install)), 200) }
        if request.url!.path.hasSuffix("/active") { return (Data(#"{"success":true}"#.utf8), 200) }
        if withdrawExecute, request.url?.host == "ha.local", request.url!.path.hasSuffix("/operation") {
            return (Data(#"{"error":"transport_security_required"}"#.utf8), 426)
        }
        if request.url!.path.hasSuffix("/operation"), failExecute { throw URLError(.networkConnectionLost) }
        let status = request.url!.path.hasSuffix("/status")
        let available = !status && !unavailableBody
        return (try JSONEncoder().encode(["success": DJConnectJSONValue.bool(true), "result_available": .bool(available),
                                         "operation_receipt": .object(hybridReceipt(body, available: available))]), 200)
    }
    func socket(_ url: URL) async throws -> any DJConnectHybridSocket {
        guard let socketValue else { throw URLError(.cannotConnectToHost) }; return socketValue
    }
    func recorded() -> [URLRequest] { requests }
}
private actor HybridTestSocket: DJConnectHybridSocket {
    enum Mode { case reverseTwo, silent, wrongConnection, rejectRouteAuth, withdrawAfterSend }
    let mode: Mode
    var frames: [Data] = []
    var waiter: CheckedContinuation<Data, Error>?
    var sent: [HybridObject] = []
    var closed = false
    init(_ mode: Mode) {
        self.mode = mode
        frames = [try! JSONEncoder().encode(["type": DJConnectJSONValue.string("auth_required"), "protocol_version": .int(1), "audience": .string("paired_owner_actions")])]
    }
    func enqueue(_ value: HybridObject) throws {
        let data = try JSONEncoder().encode(value)
        if let waiter { self.waiter = nil; waiter.resume(returning: data) } else { frames.append(data) }
    }
    func send(_ data: Data) async throws {
        let body = try JSONDecoder().decode(HybridObject.self, from: data)
        if body["type"] == .string("auth") {
            if mode == .rejectRouteAuth {
                try enqueue(["type": .string("auth_invalid"), "code": .string("transport_security_required")]); return
            }
            var context = hybridContext()
            context["type"] = .string("auth_ok"); context["protocol_version"] = .int(1)
            context["audience"] = .string("paired_owner_actions"); context["connection_id"] = .string("connection-A")
            context["lease_seconds"] = .int(300)
            context["commands"] = .array(["djconnect/read", "djconnect/operation/execute", "djconnect/operation/status"].map(DJConnectJSONValue.string))
            try enqueue(context); return
        }
        sent.append(body)
        if mode == .withdrawAfterSend {
            try enqueue(["type": .string("auth_invalid"), "code": .string("transport_security_required")]); return
        }
        func result(_ id: DJConnectJSONValue, connection: String = "connection-A") -> HybridObject {
            ["type": .string("result"), "connection_id": .string(connection), "id": id, "status": .int(200),
             "result": .object(["request": id])]
        }
        if mode == .reverseTwo, sent.count == 2 {
            try enqueue(result(sent[1]["id"]!)); try enqueue(result(sent[0]["id"]!))
        } else if mode == .wrongConnection { try enqueue(result(body["id"]!, connection: "old-connection")) }
    }
    func receive() async throws -> Data {
        if !frames.isEmpty { return frames.removeFirst() }
        if closed { throw URLError(.networkConnectionLost) }
        return try await withCheckedThrowingContinuation { waiter = $0 }
    }
    func ping() async throws { if closed { throw URLError(.networkConnectionLost) } }
    func close() async { closed = true; waiter?.resume(throwing: URLError(.networkConnectionLost)); waiter = nil }
    func count() -> Int { sent.count }
    func operationEnvelope() -> HybridObject? { sent.first }
}
private func hybridCoordinator(_ wire: HybridTestWire, local: URL? = nil) -> DJConnectHybridTransport {
    DJConnectHybridTransport(localURL: local, remoteURL: URL(string: "https://remote.example"), expectedInstallID: "test-install",
                             identity: hybridIdentity(), tokenStore: DJConnectInMemoryTokenStore(token: "paired-test-token"), wire: wire)
}

@Test func hybridUUIDV7RetainsCreationTimeAndMakesDistinctIntents() {
    let first = DJConnectOperationIdentity.uuidV7(milliseconds: 1_792_053_890_000)
    let second = DJConnectOperationIdentity.uuidV7(milliseconds: 1_792_053_890_000)
    #expect(first != second); #expect(UUID(uuidString: first) != nil)
    #expect(first.split(separator: "-")[2].first == "7")
    #expect(first.replacingOccurrences(of: "-", with: "").prefix(12) == String(format: "%012llx", 1_792_053_890_000))
}
@Test func hybridPinnedCoreFixtureDecodesWithoutRewritingReceipts() throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/hybrid_transport_v1_core_f0a7ff4.json")
    let fixture = try JSONDecoder().decode(HybridObject.self, from: Data(contentsOf: url))
    guard case let .array(cases) = fixture["transport_receipts"] else { Issue.record("Missing pinned cases"); return }
    var count = 0
    for item in cases {
        if let value = item.hybridObject?["body"]?.hybridObject?["operation_receipt"] {
            let receipt = try JSONDecoder().decode(DJConnectOperationReceipt.self, from: JSONEncoder().encode(value))
            #expect(receipt.contractVersion == 1); count += 1
        }
    }
    #expect(count >= 14)
}
@Test func hybridRejectsPlaintextAndCredentialsInOriginsBeforeAnyRequest() async throws {
    for raw in ["http://ha.local", "https://user:secret@ha.local", "https://ha.local?token=x"] {
        #expect(!DJConnectHybridTransport.trustedOrigin(URL(string: raw)!))
    }
    let wire = HybridTestWire()
    let coordinator = DJConnectHybridTransport(localURL: URL(string: "http://ha.local"), remoteURL: nil,
        expectedInstallID: "test-install", identity: hybridIdentity(), tokenStore: DJConnectInMemoryTokenStore(token: "secret"), wire: wire)
    await #expect(throws: DJConnectHybridTransportError.self) { try await coordinator.perform(hybridRequest()) }
    #expect(await wire.recorded().isEmpty)
}
@Test func hybridWrongInstallStopsBeforeEffectAndDoesNotTryAnotherAccount() async throws {
    let wire = HybridTestWire(install: "wrong-install")
    let coordinator = hybridCoordinator(wire, local: URL(string: "https://ha.local"))
    await #expect(throws: DJConnectHybridTransportError.installationMismatch) { try await coordinator.perform(hybridRequest()) }
    let requests = await wire.recorded()
    #expect(requests.count == 1); #expect(requests[0].url?.path.hasSuffix("/context") == true)
}
@Test func hybridAfterPossibleHTTPSendOnlyReconcilesOriginalIdentity() async throws {
    let wire = HybridTestWire(failExecute: true)
    let coordinator = hybridCoordinator(wire)
    do { _ = try await coordinator.perform(hybridRequest()); Issue.record("Expected receipt-only outcome") }
    catch DJConnectHybridTransportError.outcome(let receipt) { #expect(receipt.phase == "confirmed"); #expect(!receipt.resultAvailable) }
    let requests = await wire.recorded()
    let executes = requests.filter { $0.url?.path.hasSuffix("/operation") == true }
    let statuses = requests.filter { $0.url?.path.hasSuffix("/status") == true }
    #expect(executes.count == 1); #expect(statuses.count == 1)
    let execute = try JSONDecoder().decode(HybridObject.self, from: #require(executes.first?.httpBody))
    let status = try JSONDecoder().decode(HybridObject.self, from: #require(statuses.first?.httpBody))
    #expect(execute["operation_id"] == status["operation_id"])
    #expect(execute["operation_epoch"] == status["operation_epoch"])
}
@Test func hybridConfirmedMissingBodyNeverRegeneratesAndDeliberateActionsHaveNewIDs() async throws {
    let wire = HybridTestWire(unavailableBody: true), coordinator = hybridCoordinator(wire)
    for _ in 0..<2 {
        do { _ = try await coordinator.perform(hybridRequest()); Issue.record("Expected confirmed receipt") }
        catch DJConnectHybridTransportError.outcome(let r) { #expect(r.phase == "confirmed"); #expect(await coordinator.retainedReceipt(r.operationID) == r) }
    }
    let requests = await wire.recorded().filter { $0.url?.path.hasSuffix("/operation") == true }
    #expect(requests.count == 2)
    let ids = try requests.map { try JSONDecoder().decode(HybridObject.self, from: $0.httpBody!)["operation_id"] }
    #expect(ids[0] != ids[1])
}
@Test func hybridRemoteReadinessSharesOneProbeAndDoesNotPayLANTimeoutPerAction() async throws {
    let wire = HybridTestWire(failedLocal: true), coordinator = hybridCoordinator(wire, local: URL(string: "https://ha.local"))
    async let a = coordinator.perform(hybridRequest()); async let b = coordinator.perform(hybridRequest())
    _ = try await (a, b)
    let requests = await wire.recorded()
    #expect(requests.filter { $0.url?.host == "ha.local" }.count == 1)
    #expect(requests.filter { $0.url?.host == "remote.example" && $0.url?.path.hasSuffix("/context") == true }.count == 1)
    #expect(await coordinator.snapshot().state == .remoteReady)
    #expect(await coordinator.snapshot().activeOrigin == URL(string: "https://remote.example"))
    await coordinator.lifecycle(foreground: false)
    #expect(await coordinator.snapshot().activeOrigin == nil)
    #expect(await coordinator.snapshot().state == .recoveringOffline)
    #expect(await coordinator.snapshot().websocketConnected == false)
}
@Test func hybridSocketDemultiplexesOutOfOrderRepliesAndUsesOneReader() async throws {
    let socket = HybridTestSocket(.reverseTwo), wire = HybridTestWire(socket: socket)
    let connection = DJConnectPairedActionConnection(baseURL: URL(string: "https://ha.local")!, expectedInstallID: "test-install",
        identity: hybridIdentity(), tokenStore: DJConnectInMemoryTokenStore(token: "secret"), wire: wire)
    async let a = connection.request(type: "djconnect/read", body: ["operation": .string("session/active"), "payload": .object([:])])
    async let b = connection.request(type: "djconnect/read", body: ["operation": .string("session/active"), "payload": .object([:])])
    let results = try await [a, b].map { try JSONDecoder().decode(HybridObject.self, from: $0.0)["request"] }
    #expect(Set(results.compactMap { $0?.hybridInt }) == [1, 2]); await connection.stop()
}
@Test func hybridWrongConnectionCannotCompleteNewRequest() async throws {
    let socket = HybridTestSocket(.wrongConnection), wire = HybridTestWire(socket: socket)
    let connection = DJConnectPairedActionConnection(baseURL: URL(string: "https://ha.local")!, expectedInstallID: "test-install",
        identity: hybridIdentity(), tokenStore: DJConnectInMemoryTokenStore(token: "secret"), wire: wire)
    await #expect(throws: DJConnectHybridTransportError.self) { try await connection.request(type: "djconnect/read", body: [:]) }
    await connection.stop()
}

@Test func hybridCapacityAndBackgroundCancellationDoNotDispatchHTTPFallback() async throws {
    let socket = HybridTestSocket(.silent), wire = HybridTestWire(socket: socket)
    let coordinator = hybridCoordinator(wire, local: URL(string: "https://ha.local"))
    let tasks = (0..<8).map { _ in Task { try await coordinator.perform(hybridRequest()) } }
    for _ in 0..<200 where await socket.count() < 8 { try await Task.sleep(for: .milliseconds(2)) }
    #expect(await socket.count() == 8)
    await #expect(throws: DJConnectHybridTransportError.capacity) { try await coordinator.perform(hybridRequest()) }
    await coordinator.lifecycle(foreground: false)
    for task in tasks { _ = await task.result }
    #expect(await wire.recorded().filter { $0.url?.path.hasSuffix("/operation") == true }.isEmpty)
}
@Test func hybridLegacyUploadsAndMutationsCannotUseBlindHTTPFallback() throws {
    var request = try hybridRequest()
    #expect(!DJConnectHybridTransport.canReplayLegacy(request))
    request.httpBody = Data(#"{"command":"status"}"#.utf8)
    #expect(DJConnectHybridTransport.canReplayLegacy(request))
    for path in ["voice", "music_discovery/refresh", "music_dna/clear", "ask_dj/history/clear"] {
        request.url = URL(string: "https://ha.local/api/djconnect/v1/" + path)
        #expect(!DJConnectHybridTransport.canReplayLegacy(request))
    }
}
@Test func hybridNormalizesIdentifiedPayloadWithoutCopyingBearerIntoOperation() async throws {
    let wire = HybridTestWire(), coordinator = hybridCoordinator(wire)
    var request = try hybridRequest()
    request.httpBody = Data(#"{"command":"next","device_token":"secret","identity":{"device_token":"secret"},"payload":{"command":"next","device_token":"secret","device_id":"djconnect-ios-ABCDEF123456","client_type":"ios","identity":{"device_token":"secret"}}}"#.utf8)
    _ = try await coordinator.perform(request)
    let execute = try #require(await wire.recorded().first { $0.url?.path.hasSuffix("/operation") == true })
    let body = try JSONDecoder().decode(HybridObject.self, from: #require(execute.httpBody))
    let payload = try #require(body["payload"]?.hybridObject)
    #expect(payload["device_token"] == nil); #expect(payload["identity"] == nil)
    #expect(payload["command"] == .string("next"))
}

@Test func hybridRouteWithdrawalBeforeSendNeverDispatchesFallbackOrClearsToken() async throws {
    let socket = HybridTestSocket(.rejectRouteAuth), wire = HybridTestWire(socket: socket)
    let store = DJConnectInMemoryTokenStore(token: "paired-test-token")
    let coordinator = DJConnectHybridTransport(localURL: URL(string: "https://ha.local"),
        remoteURL: URL(string: "https://remote.example"), expectedInstallID: "test-install",
        identity: hybridIdentity(), tokenStore: store, wire: wire)
    await #expect(throws: DJConnectHybridTransportError.routeWithdrawn) { try await coordinator.perform(hybridRequest()) }
    #expect(await socket.count() == 0)
    #expect(await wire.recorded().filter { $0.url?.path.hasSuffix("/operation") == true }.isEmpty)
    #expect(try store.loadToken() == "paired-test-token")
    #expect(await coordinator.snapshot().state != .terminalAuthorityWithdrawn)
    #expect(try await coordinator.authorizedBaseURL() == URL(string: "https://remote.example"))
}
@Test func hybridRouteWithdrawalAfterSendOnlyReconcilesOriginalIDOnTrustedTLS() async throws {
    let socket = HybridTestSocket(.withdrawAfterSend), wire = HybridTestWire(socket: socket)
    let coordinator = hybridCoordinator(wire, local: URL(string: "https://ha.local"))
    do { _ = try await coordinator.perform(hybridRequest()); Issue.record("Expected receipt-only outcome") }
    catch DJConnectHybridTransportError.outcome(let receipt) { #expect(receipt.phase == "confirmed") }
    #expect(await socket.count() == 1)
    let requests = await wire.recorded()
    let blindExecutions = requests.filter { $0.url?.path.hasSuffix("/operation") == true }
    #expect(blindExecutions.isEmpty)
    let status = try #require(requests.first { $0.url?.path.hasSuffix("/status") == true })
    #expect(status.url?.host == "remote.example")
    let submitted = try #require(await socket.operationEnvelope())
    let queried = try JSONDecoder().decode(HybridObject.self, from: #require(status.httpBody))
    #expect(submitted["operation_id"] == queried["operation_id"])
    #expect(submitted["operation_epoch"] == queried["operation_epoch"])
}

@Test func hybridHTTP426AfterDispatchReconcilesInsteadOfReexecutingOrResettingPairing() async throws {
    let wire = HybridTestWire(withdrawExecute: true)
    let coordinator = hybridCoordinator(wire, local: URL(string: "https://ha.local"))
    do { _ = try await coordinator.perform(hybridRequest()); Issue.record("Expected receipt-only outcome") }
    catch DJConnectHybridTransportError.outcome(let receipt) { #expect(receipt.phase == "confirmed") }
    let requests = await wire.recorded()
    let executes = requests.filter { $0.url?.path.hasSuffix("/operation") == true }
    let statuses = requests.filter { $0.url?.path.hasSuffix("/status") == true }
    #expect(executes.count == 1); #expect(statuses.count == 1)
    #expect(statuses.first?.url?.host == "remote.example")
    let first = try JSONDecoder().decode(HybridObject.self, from: #require(executes.first?.httpBody))
    let recovered = try JSONDecoder().decode(HybridObject.self, from: #require(statuses.first?.httpBody))
    #expect(first["operation_id"] == recovered["operation_id"])
    #expect(first["operation_epoch"] == recovered["operation_epoch"])
    #expect(await coordinator.snapshot().state != .terminalAuthorityWithdrawn)
}
@Test func hybridReadWithdrawalRecoversThroughTrustedTLSWithoutMutation() async throws {
    let socket = HybridTestSocket(.rejectRouteAuth), wire = HybridTestWire(socket: socket)
    let coordinator = hybridCoordinator(wire, local: URL(string: "https://ha.local"))
    let request = URLRequest(url: URL(string: "https://ha.local/api/djconnect/v1/session/active")!)
    let response = try await coordinator.perform(request)
    #expect(response.1 == 200)
    let requests = await wire.recorded()
    let reads = requests.filter { $0.url?.path.hasSuffix("/active") == true }
    let mutations = requests.filter { $0.url?.path.hasSuffix("/operation") == true }
    #expect(reads.count == 1); #expect(reads.first?.url?.host == "remote.example")
    #expect(mutations.isEmpty); #expect(await socket.count() == 0)
}
