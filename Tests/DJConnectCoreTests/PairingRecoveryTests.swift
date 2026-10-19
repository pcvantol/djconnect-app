import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

private final class PairingRecoveryWire: @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var wires: [String: PairingRecoveryWire] = [:]
    let host = UUID().uuidString.lowercased() + ".invalid"
    let handler: @Sendable (URLRequest, Int) async throws -> (Int, Data)
    private var routes: [String] = []
    init(_ handler: @escaping @Sendable (URLRequest, Int) async throws -> (Int, Data)) {
        self.handler = handler
        Self.lock.withLock { Self.wires[host] = self }
    }
    func close() { _ = Self.lock.withLock { Self.wires.removeValue(forKey: host) } }
    func next(_ path: String) -> Int { Self.lock.withLock { routes.append(path); return routes.count } }
    var requests: [String] { Self.lock.withLock { routes } }
    func session() -> URLSession {
        let c = URLSessionConfiguration.ephemeral
        c.protocolClasses = [PairingRecoveryURLProtocol.self]
        return URLSession(configuration: c)
    }
}
private final class PairingRecoveryURLProtocol: URLProtocol, @unchecked Sendable {
    private var operation: Task<Void, Never>?
    override class func canInit(with request: URLRequest) -> Bool {
        PairingRecoveryWire.lock.withLock { PairingRecoveryWire.wires[request.url?.host ?? ""] != nil }
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let wire = PairingRecoveryWire.lock.withLock({ PairingRecoveryWire.wires[request.url?.host ?? ""] }) else { return }
        operation = Task {
            do {
                let (status, data) = try await wire.handler(request, wire.next(request.url!.path))
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
    }
    override func stopLoading() { operation?.cancel() }
}
private let pairingStatusSuccess = Data(#"{"success":true,"ha_install_id":"fixture-install","backend_available":true}"#.utf8)

@MainActor private func pendingPairingModel(_ session: URLSession) throws -> (DJConnectAppModel, UserDefaults, DJConnectInMemoryTokenStore, String) {
    let suite = "pairing-recovery-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.set(true, forKey: "DJConnectWelcomeSeen")
    let token = DJConnectInMemoryTokenStore(token: "accepted-fixture-token")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: token, urlSession: session, startBackgroundTasks: false)
    model.apply(pairingResponse: .init(success: true, haLocalURL: "http://pairing-fixture.invalid:8123", haInstallID: "fixture-install"), fallbackBaseURL: URL(string: "http://pairing-fixture.invalid:8123")!)
    defaults.set(true, forKey: "DJConnectHomeAssistantSetupPending")
    model.pairingStatus = .waitingForHomeAssistantCompletion
    model.isPairing = true
    model.language = "nl"
    return (model, defaults, token, suite)
}
private func pairingRecoveryClient(_ wire: PairingRecoveryWire, token: DJConnectInMemoryTokenStore) -> DJConnectClient {
    DJConnectClient(baseURL: URL(string: "http://" + wire.host)!, identity: .init(deviceID: "djconnect-macos-ABCDEF123456", deviceName: "Pairing fixture", clientType: .macos, firmware: "4.0.0", platform: .macos), tokenStore: token, session: wire.session())
}

@Test @MainActor func pairingCompletionSurvivesConversationEpochChangeWithoutAnotherPairPost() async throws {
    let wire = PairingRecoveryWire { _, _ in (200, pairingStatusSuccess) }
    defer { wire.close() }
    let (model, defaults, token, suite) = try pendingPairingModel(wire.session())
    defer { defaults.removePersistentDomain(forName: suite) }
    let scoped = PairingRecoveryWire { _, _ in
        await MainActor.run { model.sessionHistory.suspend() }
        return (200, pairingStatusSuccess)
    }
    defer { scoped.close() }
    try await model.waitForHomeAssistantPairingCompletion(client: pairingRecoveryClient(scoped, token: token))
    #expect(model.pairingStatus == .paired && model.isShowingPairingSuccess)
    #expect(!defaults.bool(forKey: "DJConnectHomeAssistantSetupPending"))
    #expect(try token.loadToken() == "accepted-fixture-token")
    #expect(scoped.requests == ["/api/djconnect/v1/status"])
}

@Test @MainActor func pairingCompletionRetriesTransportCancellationAsStatusOnly() async throws {
    let wire = PairingRecoveryWire { _, attempt in
        if attempt == 1 { throw URLError(.cancelled) }
        return (200, pairingStatusSuccess)
    }
    defer { wire.close() }
    let (model, defaults, token, suite) = try pendingPairingModel(wire.session())
    defer { defaults.removePersistentDomain(forName: suite) }
    try await model.waitForHomeAssistantPairingCompletion(client: pairingRecoveryClient(wire, token: token))
    #expect(model.pairingStatus == .paired && model.isShowingPairingSuccess)
    #expect(wire.requests == Array(repeating: "/api/djconnect/v1/status", count: 2))
    #expect(model.pairingMessage?.contains("CancellationError") == false)
}

@Test @MainActor func pairingCompletionRejectsLateCredentialOrOperationReplacement() async throws {
    for replacement in ["token", "operation", "endpoint", "installation"] {
        let bootstrap = PairingRecoveryWire { _, _ in (200, pairingStatusSuccess) }
        defer { bootstrap.close() }
        let (model, defaults, token, suite) = try pendingPairingModel(bootstrap.session())
        defer { defaults.removePersistentDomain(forName: suite) }
        var operationIsCurrent = true
        let wire = PairingRecoveryWire { _, _ in
            await MainActor.run {
                switch replacement {
                case "token": try? token.saveToken("replacement-fixture-token")
                case "endpoint": model.apply(pairingResponse: .init(success: true, haLocalURL: "http://replacement.invalid:8123"), fallbackBaseURL: URL(string: "http://replacement.invalid:8123")!)
                case "installation": UserDefaults(suiteName: suite)?.set("replacement-install", forKey: "DJConnectHAInstallID")
                default: operationIsCurrent = false
                }
            }
            return (200, pairingStatusSuccess)
        }
        defer { wire.close() }
        try await model.waitForHomeAssistantPairingCompletion(client: pairingRecoveryClient(wire, token: token), isCurrentOperation: { operationIsCurrent })
        #expect(model.pairingStatus == .waitingForHomeAssistantCompletion)
        #expect(!model.isShowingPairingSuccess && defaults.bool(forKey: "DJConnectHomeAssistantSetupPending"))
        #expect(wire.requests.count == 1)
    }
}

@Test @MainActor func pairingCompletionHonorsTerminalRejectionWithoutRetry() async throws {
    let wire = PairingRecoveryWire { _, _ in (401, Data(#"{"success":false,"error":"unauthorized"}"#.utf8)) }
    defer { wire.close() }
    let (model, defaults, token, suite) = try pendingPairingModel(wire.session())
    defer { defaults.removePersistentDomain(forName: suite) }
    try await model.waitForHomeAssistantPairingCompletion(client: pairingRecoveryClient(wire, token: token))
    #expect(model.pairingStatus != .paired && !model.isShowingPairingSuccess)
    #expect(!defaults.bool(forKey: "DJConnectHomeAssistantSetupPending"))
    #expect(try token.loadToken() == nil)
    #expect(wire.requests.count == 1)
}

@Test @MainActor func pairingCompletionAdoptsFinalInstallationOnlyForAcceptedPendingCredential() async throws {
    let finalStatus = Data(#"{"success":true,"ha_install_id":"final-install","backend_available":false}"#.utf8)
    let wire = PairingRecoveryWire { _, _ in (200, finalStatus) }
    defer { wire.close() }
    let (model, defaults, token, suite) = try pendingPairingModel(wire.session())
    defer { defaults.removePersistentDomain(forName: suite) }
    try await model.waitForHomeAssistantPairingCompletion(client: pairingRecoveryClient(wire, token: token))
    #expect(model.pairingStatus == .paired && model.isShowingPairingSuccess)
    #expect(defaults.string(forKey: "DJConnectHAInstallID") == "final-install")
    #expect(!defaults.bool(forKey: "DJConnectHomeAssistantSetupPending"))
    #expect(!model.backendAvailable)
    #expect(try token.loadToken() == "accepted-fixture-token")
    #expect(wire.requests == ["/api/djconnect/v1/status"])
}

@Test @MainActor func pairingCompletionDoesNotAdmitIncompatibleIntegrationVersion() async throws {
    let wire = PairingRecoveryWire { _, _ in
        (200, Data(#"{"success":true,"ha_install_id":"final-install","ha_major_minor":"3.2"}"#.utf8))
    }
    defer { wire.close() }
    let (model, defaults, token, suite) = try pendingPairingModel(wire.session())
    defer { defaults.removePersistentDomain(forName: suite) }
    try await model.waitForHomeAssistantPairingCompletion(client: pairingRecoveryClient(wire, token: token))
    #expect(model.pairingStatus != .paired && !model.isShowingPairingSuccess)
    #expect(model.updateRequiredMessage != nil)
    #expect(defaults.string(forKey: "DJConnectHAInstallID") == "fixture-install")
    #expect(try token.loadToken() == "accepted-fixture-token")
}
