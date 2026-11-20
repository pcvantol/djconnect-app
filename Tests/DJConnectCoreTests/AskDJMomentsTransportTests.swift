import Foundation
import Testing
@testable import DJConnectCore

private actor MomentsReadWire: DJConnectHybridWire {
    let inventory: Data
    let capability: DJConnectJSONValue
    let pauseContext: Bool
    var contextStarted = false
    var contextWaiter: CheckedContinuation<Void, Never>?
    var requests: [URLRequest] = []
    init(pauseContext: Bool = false) throws {
        let url = try #require(askDJMomentsFixtureURL("producer-final"))
        let fixture = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        inventory = try JSONSerialization.data(withJSONObject: try #require(fixture["inventory"]))
        capability = try JSONDecoder().decode(DJConnectJSONValue.self, from: JSONSerialization.data(withJSONObject: try #require(fixture["capability"])))
        self.pauseContext = pauseContext
    }
    func http(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        if request.url?.path.hasSuffix("/context") == true {
            contextStarted = true
            if pauseContext { await withCheckedContinuation { contextWaiter = $0 } }
            let context: HybridObject = ["success": .bool(true), "contract_version": .int(1), "ha_install_id": .string("moments-test-install"),
                "operation_epoch": .string("boot-fixture"), "server_time_ms": .int(Int(Date().timeIntervalSince1970 * 1000)),
                "operation_lifetime_ms": .int(300_000), "requires_authenticated_tls": .bool(true),
                "http_operations": .array([.string("ask_dj/moments/request"), .string("ask_dj/moments/cancel")]),
                "action_operations": .array([]), "read_operations": .array([.string("ask_dj/moments"), .string("ask_dj/moments/status")]),
                "ask_dj_moments": capability]
            return (try JSONEncoder().encode(context), 200)
        }
        guard request.url?.path == "/api/djconnect/v1/transport/read" else { throw DJConnectError.invalidResponse }
        return (inventory, 200)
    }
    func socket(_ url: URL) async throws -> any DJConnectHybridSocket { throw URLError(.cannotConnectToHost) }
    func resumeContext() { contextWaiter?.resume(); contextWaiter = nil }
    func paths() -> [String] { requests.compactMap { $0.url?.path } }
    func bodies() -> [Data] { requests.compactMap(\.httpBody) }
}
@MainActor private final class MomentsOwner { var current = true }
private func momentsTransport(_ wire: MomentsReadWire) -> DJConnectHybridTransport {
    DJConnectHybridTransport(localURL: nil, remoteURL: URL(string: "https://paired.example"), expectedInstallID: "moments-test-install",
        identity: .init(deviceID: "djconnect-ios-fixture", deviceName: "Fixture", clientType: .ios, firmware: "4.1.0", appVersion: "4.1.0", platform: .ios),
        tokenStore: DJConnectInMemoryTokenStore(token: "declared-fixture-token"), wire: wire)
}

@Test @MainActor func momentsMenuReadsUseDeclaredPairedReadWithoutProducerExecution() async throws {
    let wire = try MomentsReadWire(), owner = MomentsOwner(), transport = momentsTransport(wire)
    let payload = Data(#"{"contract_version":1,"session_id":"original-session"}"#.utf8)
    _ = try await transport.readAskDJMoments(.inventory, payload: payload, isCurrent: { owner.current })
    _ = try await transport.readAskDJMoments(.status, payload: payload, isCurrent: { owner.current })
    let paths = await wire.paths()
    #expect(paths.filter { $0 == "/api/djconnect/v1/transport/read" }.count == 2)
    #expect(!paths.contains("/api/djconnect/v1/transport/operation"))
    let bodies = try await wire.bodies().map { try JSONDecoder().decode(HybridObject.self, from: $0) }
    let reads = bodies.filter { $0["operation"] != nil }
    #expect(reads.map { $0["operation"]?.hybridString } == ["ask_dj/moments", "ask_dj/moments/status"])
    #expect(reads.allSatisfy { $0["operation_id"] == nil })
}

@Test @MainActor func momentsOwnerSwitchDuringRoutePreflightPreventsReadAndActionDispatch() async throws {
    for action in [false, true] {
        let wire = try MomentsReadWire(pauseContext: true), owner = MomentsOwner(), transport = momentsTransport(wire)
        let task = Task {
            if action {
                _ = try await transport.performAskDJMoments(.request, payload: Data("{}".utf8), isCurrent: { owner.current })
            } else {
                _ = try await transport.readAskDJMoments(.inventory, payload: Data("{}".utf8), isCurrent: { owner.current })
            }
        }
        for _ in 0..<1000 {
            if await wire.contextStarted { break }
            await Task.yield()
        }
        #expect(await wire.contextStarted)
        owner.current = false
        await wire.resumeContext()
        do { try await task.value; Issue.record("An old owner dispatched after route preflight") }
        catch { }
        #expect(await wire.paths() == ["/api/djconnect/v1/transport/context"])
    }
}
