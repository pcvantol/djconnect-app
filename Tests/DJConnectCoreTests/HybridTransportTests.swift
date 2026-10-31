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
    var socketURLs: [URL] = []
    let localContext: HybridObject?
    let waitsDuringExecute: Bool
    var executing = false
    var cancelledExecute = false
    let pendingStatuses: Int
    let expiredStatus: Bool
    var statusReads = 0
    let install: String
    let failExecute: Bool
    let unavailableBody: Bool
    let failedLocal: Bool
    let withdrawExecute: Bool
    let socketValue: (any DJConnectHybridSocket)?
    init(install: String = "test-install", failExecute: Bool = false, unavailableBody: Bool = false,
         failedLocal: Bool = false, socket: (any DJConnectHybridSocket)? = nil, withdrawExecute: Bool = false, localContext: HybridObject? = nil,
         pendingStatuses: Int = 0, expiredStatus: Bool = false, waitsDuringExecute: Bool = false) {
        self.install = install; self.failExecute = failExecute; self.unavailableBody = unavailableBody
        self.withdrawExecute = withdrawExecute
        self.localContext = localContext
        self.failedLocal = failedLocal; self.socketValue = socket
        self.pendingStatuses = pendingStatuses; self.expiredStatus = expiredStatus
        self.waitsDuringExecute = waitsDuringExecute
    }
    func http(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        if failedLocal, request.url?.host == "ha.local" { throw URLError(.cannotConnectToHost) }
        let body = try JSONDecoder().decode(HybridObject.self, from: request.httpBody ?? Data("{}".utf8))
        if request.url!.path.hasSuffix("/context") {
            let context = request.url?.scheme == "http" ? localContext ?? hybridContext(install: install) : hybridContext(install: install)
            return (try JSONEncoder().encode(context), 200)
        }
        if request.url!.path.hasSuffix("/active") { return (Data(#"{"success":true}"#.utf8), 200) }
        if withdrawExecute, request.url?.host == "ha.local", request.url!.path.hasSuffix("/operation") {
            return (Data(#"{"error":"transport_security_required"}"#.utf8), 426)
        }
        if request.url!.path.hasSuffix("/operation"), waitsDuringExecute {
            executing = true
            do { try await Task.sleep(for: .seconds(30)) }
            catch { cancelledExecute = true; throw error }
        }
        if request.url!.path.hasSuffix("/operation"), failExecute { throw URLError(.networkConnectionLost) }
        let status = request.url!.path.hasSuffix("/status")
        if status {
            statusReads += 1
            if statusReads <= pendingStatuses {
                var receipt = hybridReceipt(body, available: false, phase: "accepted")
                if expiredStatus { receipt["expires_at_ms"] = .int(Int(Date().timeIntervalSince1970*1000)-1) }
                return (try JSONEncoder().encode(["success": DJConnectJSONValue.bool(true), "result_available": .bool(false),
                                                 "operation_receipt": .object(receipt)]),202)
            }
        }
        let available = !status && !unavailableBody
        return (try JSONEncoder().encode(["success": DJConnectJSONValue.bool(true), "result_available": .bool(available),
                                         "operation_receipt": .object(hybridReceipt(body, available: available))]), 200)
    }
    func socket(_ url: URL) async throws -> any DJConnectHybridSocket {
        socketURLs.append(url)
        guard let socketValue else { throw URLError(.cannotConnectToHost) }; return socketValue
    }
    func recorded() -> [URLRequest] { requests }
    func openedSockets() -> [URL] { socketURLs }
}
private actor HybridTestSocket: DJConnectHybridSocket {
    enum Mode { case reverseTwo, silent, wrongConnection, rejectRouteAuth, withdrawAfterSend }
    let mode: Mode
    let localContext: HybridObject?
    var frames: [Data] = []
    var waiter: CheckedContinuation<Data, Error>?
    var sent: [HybridObject] = []
    var closed = false
    init(_ mode: Mode, localContext: HybridObject? = nil) {
        self.localContext = localContext
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
            var context = localContext ?? hybridContext()
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
private func hybridCoordinator(_ wire: any DJConnectHybridWire, local: URL? = nil) -> DJConnectHybridTransport {
    DJConnectHybridTransport(localURL: local, remoteURL: URL(string: "https://remote.example"), expectedInstallID: "test-install",
                             identity: hybridIdentity(), tokenStore: DJConnectInMemoryTokenStore(token: "paired-test-token"), wire: wire)
}

@Test(.isolatedClientResources) func hybridUUIDV7RetainsCreationTimeAndMakesDistinctIntents() {
    let first = DJConnectOperationIdentity.uuidV7(milliseconds: 1_792_053_890_000)
    let second = DJConnectOperationIdentity.uuidV7(milliseconds: 1_792_053_890_000)
    #expect(first != second); #expect(UUID(uuidString: first) != nil)
    #expect(first.split(separator: "-")[2].first == "7")
    #expect(first.replacingOccurrences(of: "-", with: "").prefix(12) == String(format: "%012llx", 1_792_053_890_000))
}

@Test(.isolatedClientResources) func hybridSlowConversationReconcilesPastThreePendingReadsWithoutResending() async throws {
    let wire = HybridTestWire(failExecute: true, pendingStatuses: 4)
    let coordinator = hybridCoordinator(wire)
    var request = try hybridRequest()
    request.url = URL(string: "https://remote.example/api/djconnect/v1/ask_dj/message")!
    request.httpBody = Data(#"{"message":"Synthetic information question","client_message_id":"original-message"}"#.utf8)
    do { _ = try await coordinator.perform(request); Issue.record("Expected confirmed receipt-only outcome") }
    catch DJConnectHybridTransportError.outcome(let receipt) { #expect(receipt.phase == "confirmed") }
    let requests = await wire.recorded()
    let executes = requests.filter { $0.url?.path.hasSuffix("/operation") == true }
    let statuses = requests.filter { $0.url?.path.hasSuffix("/status") == true }
    #expect(executes.count == 1 && statuses.count == 5)
    #expect(executes.first?.timeoutInterval == 120)
    let original = try JSONDecoder().decode(HybridObject.self, from: #require(executes.first?.httpBody))
    for status in statuses {
        let observed = try JSONDecoder().decode(HybridObject.self, from: #require(status.httpBody))
        #expect(observed["operation_id"] == original["operation_id"])
        #expect(observed["operation_epoch"] == original["operation_epoch"])
        #expect(observed["payload"] == nil)
    }
}

@Test(.isolatedClientResources) func hybridConversationStopsAtOriginalReceiptExpiryWithoutAnotherExecution() async throws {
    let wire = HybridTestWire(failExecute: true, pendingStatuses: 5, expiredStatus: true)
    let coordinator = hybridCoordinator(wire)
    var request = try hybridRequest()
    request.url = URL(string: "https://remote.example/api/djconnect/v1/ask_dj/message")!
    await #expect(throws: DJConnectHybridTransportError.deliveryUnknown) { try await coordinator.perform(request) }
    let requests = await wire.recorded()
    #expect(requests.filter { $0.url?.path.hasSuffix("/operation") == true }.count == 1)
    #expect(requests.filter { $0.url?.path.hasSuffix("/status") == true }.count == 1)
}

@Test(.isolatedClientResources) func hybridConversationReconciliationStopsWhenAppBackgrounds() async throws {
    let wire = HybridTestWire(failExecute: true, pendingStatuses: 100)
    let coordinator = hybridCoordinator(wire)
    var request = try hybridRequest()
    request.url = URL(string: "https://remote.example/api/djconnect/v1/ask_dj/message")!
    let operation = Task { try await coordinator.perform(request) }
    for _ in 0..<100 where await wire.recorded().filter({ $0.url?.path.hasSuffix("/status") == true }).isEmpty {
        try await Task.sleep(for: .milliseconds(5))
    }
    await coordinator.lifecycle(foreground: false)
    do { _ = try await operation.value; Issue.record("Expected lifecycle cancellation") }
    catch is CancellationError { }
    let requests = await wire.recorded()
    #expect(requests.filter { $0.url?.path.hasSuffix("/operation") == true }.count == 1)
    #expect(requests.filter { $0.url?.path.hasSuffix("/status") == true }.count <= 1)
}
@Test(.isolatedClientResources) func hybridPinnedCoreFixtureDecodesWithoutRewritingReceipts() throws {
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
@Test(.isolatedClientResources) func hybridRejectsPlaintextAndCredentialsInOriginsBeforeAnyRequest() async throws {
    for raw in ["http://ha.local", "https://user:secret@ha.local", "https://ha.local?token=x"] {
        #expect(!DJConnectHybridTransport.trustedOrigin(URL(string: raw)!))
    }
    let wire = HybridTestWire()
    let coordinator = DJConnectHybridTransport(localURL: nil, remoteURL: URL(string: "http://ha.local"),
        expectedInstallID: "test-install", identity: hybridIdentity(), tokenStore: DJConnectInMemoryTokenStore(token: "secret"), wire: wire)
    await #expect(throws: DJConnectHybridTransportError.self) { try await coordinator.perform(hybridRequest()) }
    #expect(await wire.recorded().isEmpty)
}
@Test(.isolatedClientResources) func hybridWrongInstallStopsBeforeEffectAndDoesNotTryAnotherAccount() async throws {
    let wire = HybridTestWire(install: "wrong-install")
    let coordinator = hybridCoordinator(wire, local: URL(string: "https://ha.local"))
    await #expect(throws: DJConnectHybridTransportError.installationMismatch) { try await coordinator.perform(hybridRequest()) }
    let requests = await wire.recorded()
    #expect(requests.count == 1); #expect(requests[0].url?.path.hasSuffix("/context") == true)
}
@Test(.isolatedClientResources) func hybridAfterPossibleHTTPSendOnlyReconcilesOriginalIdentity() async throws {
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
@Test(.isolatedClientResources) func hybridConfirmedMissingBodyNeverRegeneratesAndDeliberateActionsHaveNewIDs() async throws {
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
@Test(.isolatedClientResources) func hybridRemoteReadinessSharesOneProbeAndDoesNotPayLANTimeoutPerAction() async throws {
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
@Test(.isolatedClientResources) func hybridSocketDemultiplexesOutOfOrderRepliesAndUsesOneReader() async throws {
    let socket = HybridTestSocket(.reverseTwo), wire = HybridTestWire(socket: socket)
    let connection = DJConnectPairedActionConnection(baseURL: URL(string: "https://ha.local")!, expectedInstallID: "test-install",
        identity: hybridIdentity(), tokenStore: DJConnectInMemoryTokenStore(token: "secret"), wire: wire)
    async let a = connection.request(type: "djconnect/read", body: ["operation": .string("session/active"), "payload": .object([:])])
    async let b = connection.request(type: "djconnect/read", body: ["operation": .string("session/active"), "payload": .object([:])])
    let results = try await [a, b].map { try JSONDecoder().decode(HybridObject.self, from: $0.0)["request"] }
    #expect(Set(results.compactMap { $0?.hybridInt }) == [1, 2]); await connection.stop()
}
@Test(.isolatedClientResources) func hybridWrongConnectionCannotCompleteNewRequest() async throws {
    let socket = HybridTestSocket(.wrongConnection), wire = HybridTestWire(socket: socket)
    let connection = DJConnectPairedActionConnection(baseURL: URL(string: "https://ha.local")!, expectedInstallID: "test-install",
        identity: hybridIdentity(), tokenStore: DJConnectInMemoryTokenStore(token: "secret"), wire: wire)
    await #expect(throws: DJConnectHybridTransportError.self) { try await connection.request(type: "djconnect/read", body: [:]) }
    await connection.stop()
}

@Test(.isolatedClientResources) func hybridCapacityAndBackgroundCancellationDoNotDispatchHTTPFallback() async throws {
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
@Test(.isolatedClientResources) func hybridLegacyUploadsAndMutationsCannotUseBlindHTTPFallback() throws {
    var request = try hybridRequest()
    #expect(!DJConnectHybridTransport.canReplayLegacy(request))
    request.httpBody = Data(#"{"command":"status"}"#.utf8)
    #expect(DJConnectHybridTransport.canReplayLegacy(request))
    for path in ["voice", "music_discovery/refresh", "music_dna/clear", "ask_dj/history/clear"] {
        request.url = URL(string: "https://ha.local/api/djconnect/v1/" + path)
        #expect(!DJConnectHybridTransport.canReplayLegacy(request))
    }
}
@Test(.isolatedClientResources) func hybridNormalizesIdentifiedPayloadWithoutCopyingBearerIntoOperation() async throws {
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

@Test(.isolatedClientResources) func hybridRouteWithdrawalBeforeSendNeverDispatchesFallbackOrClearsToken() async throws {
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
@Test(.isolatedClientResources) func hybridRouteWithdrawalAfterSendOnlyReconcilesOriginalIDOnTrustedTLS() async throws {
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

@Test(.isolatedClientResources) func hybridHTTP426AfterDispatchReconcilesInsteadOfReexecutingOrResettingPairing() async throws {
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
@Test(.isolatedClientResources) func hybridReadWithdrawalRecoversThroughTrustedTLSWithoutMutation() async throws {
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

private func hybridQualifiedLocalContext() -> HybridObject {
    var context = hybridContext()
    context["requires_authenticated_tls"] = .bool(false)
    context["transport_security"] = .object([
        "policy_version": .int(1), "deployment_qualification_required": .bool(true),
        "external": .string("authenticated_tls"), "local_plaintext": .string("qualified_direct_only"),
        "peer_policy": .string("enabled_interface_subnet_or_loopback"), "internal_origin_required": .bool(true),
        "forwarded_plaintext": .string("forbidden"), "mode": .string("qualified_direct_http")])
    return context
}
@Test(.isolatedClientResources) func hybridQualifiedLocalHTTPContextAndAuthUseWSWithDemultiplexedReads() async throws {
    let context = hybridQualifiedLocalContext()
    let socket = HybridTestSocket(.reverseTwo, localContext: context)
    let wire = HybridTestWire(socket: socket, localContext: context)
    let coordinator = hybridCoordinator(wire, local: URL(string: "http://ha.local:8123"))
    let request = URLRequest(url: URL(string: "http://ha.local:8123/api/djconnect/v1/session/active")!)
    async let first = coordinator.perform(request)
    async let second = coordinator.perform(request)
    let results = try await [first, second]
    #expect(results.count == 2)
    let urls = await wire.openedSockets()
    #expect(urls == [URL(string: "ws://ha.local:8123/api/djconnect/v1/actions/paired")!])
    #expect(await coordinator.snapshot().state == .localReady)
    await coordinator.lifecycle(foreground: false)
}
@Test(.isolatedClientResources) func hybridUnqualifiedHTTPContextFallsBackOnlyToTrustedTLS() async throws {
    let wire = HybridTestWire()
    let coordinator = hybridCoordinator(wire, local: URL(string: "http://ha.local:8123"))
    #expect(try await coordinator.authorizedBaseURL() == URL(string: "https://remote.example"))
    #expect(await wire.openedSockets().isEmpty)
}
@Test(.isolatedClientResources) func hybridSocketAuthCannotDowngradeAQualifiedContext() async throws {
    let socket = HybridTestSocket(.reverseTwo)
    let wire = HybridTestWire(socket: socket, localContext: hybridQualifiedLocalContext())
    let coordinator = hybridCoordinator(wire, local: URL(string: "http://ha.local:8123"))
    await #expect(throws: DJConnectHybridTransportError.routeWithdrawn) { try await coordinator.perform(hybridRequest()) }
    #expect(await socket.count() == 0)
    let requests = await wire.recorded()
    let executes = requests.filter { $0.url?.path.hasSuffix("/operation") == true }
    #expect(executes.isEmpty)
}

@Test(.isolatedClientResources) func hybridDiagnosticsReportActualSchemeAndClearUnqualifiedOrigin() {
    var status = DJConnectHybridDiagnostics()
    #expect(status.transportDisplayName == nil)
    status.activeOrigin = URL(string: "http://ha.local:8123")
    #expect(status.transportDisplayName == "HTTP · LAN")
    status.websocketConnected = true
    #expect(status.transportDisplayName == "WS · LAN")
    status.activeOrigin = URL(string: "https://remote.example")
    #expect(status.transportDisplayName == "WSS · TLS")
    status.websocketConnected = false
    #expect(status.transportDisplayName == "HTTPS · TLS")
    status.activeOrigin = nil
    #expect(status.transportDisplayName == nil)
}

@Test(.isolatedClientResources) func hybridRepeatedActiveDoesNotWithdrawQualifiedRouteOrProbeAgain() async throws {
    let wire = HybridTestWire()
    let coordinator = DJConnectHybridTransport(localURL: URL(string: "https://ha.local"),
        remoteURL: URL(string: "https://remote.example"), expectedInstallID: "test-install",
        identity: hybridIdentity(), tokenStore: DJConnectInMemoryTokenStore(token: "test-token"), wire: wire)
    let original = try await coordinator.authorizedBaseURL()
    await coordinator.lifecycle(foreground: true)
    #expect(try await coordinator.authorizedBaseURL() == original)
    #expect(await wire.recorded().count == 1)
    #expect(await coordinator.snapshot().state == .localReady)
    await coordinator.lifecycle(foreground: false)
    await coordinator.lifecycle(foreground: true)
    #expect(try await coordinator.authorizedBaseURL() == original)
    #expect(await wire.recorded().count == 2)
}

@Test(.isolatedClientResources) func hybridLANQualificationIsBoundedBeforeAuthenticatedTLSFallback() async throws {
    let wire = HybridTestWire(failedLocal: true)
    let coordinator = DJConnectHybridTransport(localURL: URL(string: "https://ha.local"),
        remoteURL: URL(string: "https://remote.example"), expectedInstallID: "test-install",
        identity: hybridIdentity(), tokenStore: DJConnectInMemoryTokenStore(token: "test-token"), wire: wire)
    #expect(try await coordinator.authorizedBaseURL().host == "remote.example")
    let requests = await wire.recorded()
    #expect(requests.count == 2)
    #expect(requests[0].timeoutInterval == 2)
    #expect(requests[1].timeoutInterval == 8)
    #expect(await coordinator.snapshot().state == .remoteReady)
}


private actor PersonaTouchHybridWire: DJConnectHybridWire {
    var requests: [URLRequest] = []
    let supported: Bool
    let loseExecute: Bool
    init(supported: Bool, loseExecute: Bool = false) { self.supported = supported; self.loseExecute = loseExecute }
    func socket(_ url: URL) async throws -> any DJConnectHybridSocket { throw URLError(.cannotConnectToHost) }
    func http(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        if request.url!.path.hasSuffix("/context") {
            var context = hybridContext()
            if supported {
                context["http_operations"] = .array([.string(DJConnectPersonaReactionOperation.request.rawValue), .string(DJConnectPersonaReactionOperation.cancel.rawValue)])
            }
            return (try JSONEncoder().encode(context), 200)
        }
        let body = try JSONDecoder().decode(HybridObject.self, from: request.httpBody!)
        if loseExecute, request.url!.path.hasSuffix("/operation") { throw URLError(.networkConnectionLost) }
        return (try JSONEncoder().encode(["success": DJConnectJSONValue.bool(true), "result_available": .bool(!loseExecute),
                                         "operation_receipt": .object(hybridReceipt(body, available: !loseExecute))]), 200)
    }
    func recorded() -> [URLRequest] { requests }
}

@Test(.isolatedClientResources, arguments: [DJConnectPersonaReactionOperation.request, .cancel])
func personaTouchUsesOnlyAdvertisedOrdinaryOperationAndOriginalRecoveryIdentity(operation: DJConnectPersonaReactionOperation) async throws {
    for supported in [false, true] {
        let wire = PersonaTouchHybridWire(supported: supported, loseExecute: true)
        let transport = DJConnectHybridTransport(localURL: nil, remoteURL: URL(string: "https://remote.example"), expectedInstallID: "test-install",
            identity: hybridIdentity(), tokenStore: DJConnectInMemoryTokenStore(token: "synthetic"), wire: wire)
        do {
            _ = try await transport.performPersonaReaction(operation, payload: Data(#"{"contract_version":1}"#.utf8))
            Issue.record("Lost content must not be invented")
        } catch DJConnectHybridTransportError.outcome(let receipt) { #expect(supported && receipt.phase == "confirmed") }
        catch { #expect(!supported) }
        let requests = await wire.recorded()
        let executes = requests.filter { $0.url!.path.hasSuffix("/operation") }
        let statuses = requests.filter { $0.url!.path.hasSuffix("/status") }
        #expect(executes.count == (supported ? 1 : 0))
        if supported {
            let execute = try JSONDecoder().decode(HybridObject.self, from: #require(executes.first?.httpBody))
            let status = try JSONDecoder().decode(HybridObject.self, from: #require(statuses.first?.httpBody))
            #expect(execute["operation"] == .string(operation.rawValue))
            #expect(execute["operation_id"] == status["operation_id"] && execute["operation_epoch"] == status["operation_epoch"])
        }
        #expect(!requests.contains { $0.url!.path.hasSuffix("/session/persona/reaction") })
    }
}

private final class AskDJTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = ProcessInfo.processInfo.systemUptime
    func now() -> TimeInterval { lock.withLock { value } }
    func advance(_ seconds: TimeInterval) { lock.withLock { value += seconds } }
    var timing: DJConnectOperationTiming {
        .init(now: { self.now() }, sleep: { self.advance($0); await Task.yield() })
    }
}
private actor AskDJBudgetWire: DJConnectHybridWire {
    enum Scenario { case late, many, sticky }
    let scenario: Scenario
    let clock: AskDJTestClock
    var requests: [URLRequest] = []
    var statuses = 0
    init(_ scenario: Scenario, clock: AskDJTestClock) { self.scenario = scenario; self.clock = clock }
    func http(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        if request.url!.path.hasSuffix("/context") { return (try JSONEncoder().encode(hybridContext()), 200) }
        let body = try JSONDecoder().decode(HybridObject.self, from: request.httpBody!)
        if request.url!.path.hasSuffix("/operation") {
            if scenario == .late { clock.advance(130) }
            throw URLError(.timedOut) // May have executed; never retry the payload.
        }
        statuses += 1
        let id = body["operation_id"]!.hybridString!.replacingOccurrences(of: "-", with: "")
        let created = Int(id.prefix(12), radix: 16)!
        var receipt = hybridReceipt(body, available: false, phase: "accepted")
        receipt["expires_at_ms"] = .int(created + (scenario == .sticky && statuses == 1 ? 600 : 300_000))
        switch scenario {
        case .late:
            clock.advance(statuses == 1 ? 60 : 70)
            if statuses == 2 { receipt["phase"] = .string("confirmed") }
        case .many:
            if statuses == 71 { receipt["phase"] = .string("confirmed") }
        case .sticky: break
        }
        return (try JSONEncoder().encode(["operation_receipt": DJConnectJSONValue.object(receipt), "result_available": .bool(false)]), 202)
    }
    func socket(_ url: URL) async throws -> any DJConnectHybridSocket { throw URLError(.cannotConnectToHost) }
    func recorded() -> [URLRequest] { requests }
}

@Test(.isolatedClientResources) func askDJOriginalBudgetReceivesLateConfirmationWithoutSecondExecute() async throws {
    let clock = AskDJTestClock()
    // Use the same clock for routing, operation expiry and scripted network waits.
    let shared = AskDJBudgetWire(.late, clock: clock)
    let coordinator = hybridCoordinator(shared)
    await coordinator.setOperationTiming(clock.timing)
    var request = try hybridRequest(); request.url = URL(string: "https://remote.example/api/djconnect/v1/ask_dj/message")!
    do { _ = try await coordinator.perform(request); Issue.record("Expected receipt-only confirmation") }
    catch DJConnectHybridTransportError.outcome(let receipt) { #expect(receipt.phase == "confirmed") }
    let requests = await shared.recorded()
    #expect(requests.filter { $0.url!.path.hasSuffix("/operation") }.count == 1)
    #expect(requests.filter { $0.url!.path.hasSuffix("/status") }.count == 2)
}

@Test(.isolatedClientResources) func askDJContinuationCanPass64ReadsWithoutRenewingOrResending() async throws {
    let clock = AskDJTestClock(), wireClock = AskDJTestClock()
    let wire = AskDJBudgetWire(.many, clock: wireClock)
    let coordinator = hybridCoordinator(wire)
    await coordinator.setOperationTiming(clock.timing)
    var request = try hybridRequest(); request.url = URL(string: "https://remote.example/api/djconnect/v1/ask_dj/message")!
    do { _ = try await coordinator.perform(request); Issue.record("Expected receipt") }
    catch DJConnectHybridTransportError.outcome(let receipt) { #expect(receipt.phase == "confirmed") }
    let requests = await wire.recorded()
    #expect(requests.filter { $0.url!.path.hasSuffix("/operation") }.count == 1)
    #expect(requests.filter { $0.url!.path.hasSuffix("/status") }.count == 71)
}

@Test(.isolatedClientResources) func askDJEarlierReceiptExpiryCannotBeRenewedByLaterReceipt() async throws {
    let clock = AskDJTestClock(), wire = AskDJBudgetWire(.sticky, clock: AskDJTestClock())
    let coordinator = hybridCoordinator(wire)
    await coordinator.setOperationTiming(clock.timing)
    var request = try hybridRequest(); request.url = URL(string: "https://remote.example/api/djconnect/v1/ask_dj/message")!
    await #expect(throws: DJConnectHybridTransportError.deliveryUnknown) { try await coordinator.perform(request) }
    let requests = await wire.recorded()
    #expect(requests.filter { $0.url!.path.hasSuffix("/operation") }.count == 1)
    #expect(requests.filter { $0.url!.path.hasSuffix("/status") }.count == 2)
}

@Test(.isolatedClientResources) func askDJDeadlineCancelsUnderlyingWaitAndRejectsLateValue() async throws {
    actor Cleanup { var cancelled = false; func mark() { cancelled = true } }
    let cleanup = Cleanup()
    await #expect(throws: DJConnectHybridTransportError.deliveryUnknown) {
        try await DJConnectOperationDeadline(seconds: 0.02).run {
            do { try await Task.sleep(for: .seconds(30)); return 1 }
            catch { await cleanup.mark(); throw error }
        }
    }
    while !(await cleanup.cancelled) { await Task.yield() }
    #expect(await cleanup.cancelled)
}

@Test(.isolatedClientResources) func askDJCommandAliasPreservesItsEnvelopeAndOneOriginalOperation() async throws {
    let clock = AskDJTestClock()
    let wire = AskDJBudgetWire(.late, clock: clock)
    let coordinator = hybridCoordinator(wire)
    await coordinator.setOperationTiming(clock.timing)
    var request = try hybridRequest(command: "ask_dj_message")
    request.httpBody = Data(#"{"command":"ask_dj_message","value":{"text":"Synthetic question"}}"#.utf8)
    #expect(DJConnectHybridTransport.operation(for: request) == "command")
    do { _ = try await coordinator.perform(request); Issue.record("Expected confirmation only") }
    catch DJConnectHybridTransportError.outcome(let receipt) { #expect(receipt.phase == "confirmed") }
    let executes = await wire.recorded().filter { $0.url!.path.hasSuffix("/operation") }
    #expect(executes.count == 1)
    let envelope = try JSONDecoder().decode(HybridObject.self, from: #require(executes.first?.httpBody))
    #expect(envelope["operation"] == .string("command"))
    #expect(envelope["payload"]?.hybridObject?["command"] == .string("ask_dj_message"))
}

@Test(.isolatedClientResources) func askDJBackgroundCancelsTheActualExecuteWaitWithoutReplayingOrReadingStatus() async throws {
    let wire = HybridTestWire(waitsDuringExecute: true)
    let coordinator = hybridCoordinator(wire)
    var request = try hybridRequest(); request.url = URL(string: "https://remote.example/api/djconnect/v1/ask_dj/message")!
    let task = Task { try await coordinator.perform(request) }
    while !(await wire.executing) { await Task.yield() }
    await coordinator.lifecycle(foreground: false)
    await #expect(throws: CancellationError.self) { try await task.value }
    while !(await wire.cancelledExecute) { await Task.yield() }
    let requests = await wire.recorded()
    #expect(requests.filter { $0.url!.path.hasSuffix("/operation") }.count == 1)
    #expect(requests.filter { $0.url!.path.hasSuffix("/status") }.isEmpty)
}

private actor AskDJLegacyContextWire: DJConnectHybridWire {
    let status: Int
    var paths: [String] = []
    init(_ status: Int) { self.status = status }
    func http(_ request: URLRequest) async throws -> (Data, Int) {
        paths.append(request.url!.path)
        #expect(request.url!.path.hasSuffix("/context"))
        let code = status == 426 ? "transport_security_required" : status == 403 ? "profile_device_mismatch" : "unavailable"
        return (try JSONEncoder().encode(["error": code]), status)
    }
    func socket(_ url: URL) async throws -> any DJConnectHybridSocket { throw URLError(.cannotConnectToHost) }
}

@Test(.isolatedClientResources) func askDJMissingContextPreselectsLegacyOnlyOnTheExactOriginBeforeExecute() async throws {
    let origin = URL(string: "https://remote.example")!
    let wire = AskDJLegacyContextWire(404)
    let coordinator = hybridCoordinator(wire)
    var request = try hybridRequest(); request.url = origin.appendingPathComponent("api/djconnect/v1/ask_dj/message")
    let selected = try await coordinator.dispatchAskDJ(request, legacyOrigin: origin)
    guard case .legacy(let deadline) = selected else { Issue.record("Expected preselected legacy attempt"); return }
    #expect(deadline.remaining > 290 && deadline.remaining <= 300)
    #expect(await wire.paths == ["/api/djconnect/v1/transport/context"])
    await #expect(throws: DJConnectHybridTransportError.unavailable) {
        try await coordinator.dispatchAskDJ(request, legacyOrigin: URL(string: "https://another.example")!)
    }
}

@Test(.isolatedClientResources, arguments: [401, 403, 426, 500])
func askDJLegacyChoiceNeverDowngradesAuthSecurityOrInvalidContext(_ status: Int) async throws {
    let wire = AskDJLegacyContextWire(status)
    let coordinator = hybridCoordinator(wire)
    var request = try hybridRequest(); request.url = URL(string: "https://remote.example/api/djconnect/v1/ask_dj/message")!
    do {
        _ = try await coordinator.dispatchAskDJ(request, legacyOrigin: URL(string: "https://remote.example")!)
        Issue.record("A missing authority/trust qualification must not select legacy")
    } catch { }
    #expect(await wire.paths.allSatisfy { $0.hasSuffix("/context") })
}

/// Exactly the Root counterexample: the read that captures remaining time
/// returns zero-origin time, then advances beyond end before the child starts.
final class AskDJChildStartClock: @unchecked Sendable {
    private let lock = NSLock()
    private let triggerRead: Int
    private let expires: Bool
    private let onTrigger: @Sendable () -> Void
    private var reads = 0
    private var time: TimeInterval = 0
    private var invocations = 0
    init(triggerRead: Int = 3, expires: Bool = true, onTrigger: @escaping @Sendable () -> Void = {}) {
        self.triggerRead = triggerRead; self.expires = expires; self.onTrigger = onTrigger
    }
    func now() -> TimeInterval {
        let (value, trigger) = lock.withLock { () -> (TimeInterval, Bool) in
            reads += 1; let value = time
            if reads == triggerRead, expires { time = 301 }
            return (value, reads == triggerRead)
        }
        if trigger { onTrigger() }
        return value
    }
    func invoke() { lock.withLock { invocations += 1 } }
    var count: Int { lock.withLock { invocations } }
}

@Test(.isolatedClientResources) func askDJChildStartingAfterOriginalDeadlineCannotInvokeItsOperation() async throws {
    let clock = AskDJChildStartClock()
    let deadline = DJConnectOperationDeadline(timing: .init(now: { clock.now() }))
    await #expect(throws: DJConnectHybridTransportError.deliveryUnknown) {
        try await deadline.run { clock.invoke(); return 1 }
    }
    #expect(clock.count == 0)
}

@Test(.isolatedClientResources) @MainActor func askDJCancellationBeforeChildDispatchCannotInvokeItsOperation() async throws {
    final class CancellationSlot: @unchecked Sendable {
        let lock = NSLock()
        private var cancellation: (@Sendable () -> Void)?
        func install(_ value: @escaping @Sendable () -> Void) { lock.withLock { cancellation = value } }
        func cancel() { lock.withLock { cancellation }?() }
    }
    let slot = CancellationSlot()
    let clock = AskDJChildStartClock(expires: false, onTrigger: { slot.cancel() })
    let deadline = DJConnectOperationDeadline(timing: .init(now: { clock.now() }))
    let task = Task { try await deadline.run { clock.invoke(); return 1 } }
    slot.install { task.cancel() } // Installed before this actor yields to its child.
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(clock.count == 0)
}

@Test(.isolatedClientResources) func askDJOriginalAbsoluteEndCannotBeRenewedByADelayedRunWithAStalledLogicalClock() async throws {
    let counter = AskDJChildStartClock(triggerRead: Int.max, expires: false)
    let deadline = DJConnectOperationDeadline(seconds: 0.02, timing: .init(now: { 0 }))
    try await Task.sleep(for: .milliseconds(40))
    await #expect(throws: DJConnectHybridTransportError.deliveryUnknown) {
        try await deadline.run { counter.invoke(); return 1 }
    }
    #expect(counter.count == 0)
}

private actor AskDJDelayedContextWire: DJConnectHybridWire {
    let clock: AskDJTestClock
    let serverTime = Int(Date().timeIntervalSince1970 * 1000)
    var requests: [URLRequest] = []
    var statuses = 0
    var contexts = 0
    let started: TimeInterval
    init(clock: AskDJTestClock) { self.clock = clock; started = clock.now() }
    func http(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        if request.url!.path.hasSuffix("/context") {
            var context = hybridContext()
            context["server_time_ms"] = .int(serverTime + Int((clock.now() - started) * 1000))
            contexts += 1
            if contexts == 1 { clock.advance(5) } // Only the initial qualification is delayed.
            return (try JSONEncoder().encode(context), 200)
        }
        if request.url!.path.hasSuffix("/operation") { throw URLError(.timedOut) }
        statuses += 1
        let body = try JSONDecoder().decode(HybridObject.self, from: request.httpBody!)
        var receipt = hybridReceipt(body, available: false, phase: "accepted")
        receipt["expires_at_ms"] = .int(serverTime + 10_000)
        // The second result is too late for the earlier server expiry. Mapping
        // the timestamp from response arrival would wrongly admit it at t=12.
        if statuses == 2 { clock.advance(6.75); receipt["phase"] = .string("confirmed") }
        return (try JSONEncoder().encode(["operation_receipt": DJConnectJSONValue.object(receipt), "result_available": .bool(false)]), 202)
    }
    func socket(_ url: URL) async throws -> any DJConnectHybridSocket { throw URLError(.cannotConnectToHost) }
    func recorded() -> [URLRequest] { requests }
}

@Test(.isolatedClientResources) func askDJDelayedContextCannotExtendEarlierServerReceiptExpiry() async throws {
    let clock = AskDJTestClock(), wire = AskDJDelayedContextWire(clock: clock)
    let coordinator = hybridCoordinator(wire)
    await coordinator.setOperationTiming(clock.timing)
    var request = try hybridRequest(); request.url = URL(string: "https://remote.example/api/djconnect/v1/ask_dj/message")!
    await #expect(throws: DJConnectHybridTransportError.deliveryUnknown) { try await coordinator.perform(request) }
    let requests = await wire.recorded()
    #expect(requests.filter { $0.url!.path.hasSuffix("/operation") }.count == 1)
    #expect(requests.filter { $0.url!.path.hasSuffix("/status") }.count == 2)
}
