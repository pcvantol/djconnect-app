import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

/// Deliberately suspended HTTP, exercising the production controller + operation journal.
/// Source/model content is the declared Core fixture, not a live provider acceptance test.
private actor MomentsControllerWire: DJConnectHybridWire {
    private var fixture: [String: Any]
    private var originalID = ""
    private var ownerDenied = false
    private var releaseOriginal = false
    private var lateStatus: CheckedContinuation<Void, Never>?
    private let lateFailure: Bool
    private(set) var lateStatusReturned = false
    private(set) var originalStarted = false
    private(set) var originalCancelled = false
    private(set) var requestCount = 0
    private(set) var cancelCount = 0
    private(set) var statusCount = 0
    init(lateFailure: Bool) throws {
        self.lateFailure = lateFailure
        let url = try #require(askDJMomentsFixtureURL("producer-final"))
        let value = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        // Shift the declared fixture's clock as one unit, without changing identity/content.
        let captured = try #require(value["captured_at"] as? String)
        let delta = Date().timeIntervalSince(try #require(DJConnectHistoryEntry.date(captured)))
        func shift(_ value: Any) -> Any {
            if let dictionary = value as? [String: Any] { return dictionary.mapValues(shift) }
            if let array = value as? [Any] { return array.map(shift) }
            if let text = value as? String, let date = DJConnectHistoryEntry.date(text), text.contains("T") {
                return ISO8601DateFormatter().string(from: date.addingTimeInterval(delta))
            }
            return value
        }
        fixture = try #require(shift(value) as? [String: Any])
    }
    private func data(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value) }
    func http(_ request: URLRequest) async throws -> (Data, Int) {
        let body = try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data("{}".utf8)) as? [String: Any])
        let path = request.url?.path ?? ""
        if path.hasSuffix("/context") {
            return (try data(["success": true, "contract_version": 1, "ha_install_id": "controller-fixture-install",
                "operation_epoch": "fixture-boot", "server_time_ms": Int(Date().timeIntervalSince1970 * 1000),
                "operation_lifetime_ms": 300000, "requires_authenticated_tls": true,
                "http_operations": ["ask_dj/moments/request", "ask_dj/moments/cancel"], "action_operations": [],
                "read_operations": ["ask_dj/moments", "ask_dj/moments/status"], "ask_dj_moments": try #require(fixture["capability"])]), 200)
        }
        if path.hasSuffix("/operation/status") {
            let receipt: [String: Any] = ["contract_version": 1, "operation_id": try #require(body["operation_id"]),
                "operation_epoch": "fixture-boot", "phase": "unknown", "expires_at_ms": Int(Date().timeIntervalSince1970 * 1000)+300000,
                "result_available": false, "response_status": 200, "error": NSNull()]
            return (try data(["success": false, "result_available": false, "operation_receipt": receipt]), 200)
        }
        if path.hasSuffix("/transport/read") {
            if body["operation"] as? String == "ask_dj/moments" { return (try data(try #require(fixture["inventory"])), 200) }
            if ownerDenied { return (try data(["success": false, "error": "profile_unavailable"]), 403) }
            statusCount += 1
            let isLate = statusCount == 2
            if isLate { await withCheckedContinuation { lateStatus = $0 } }
            var pending = try #require(fixture["accepted_http_response"] as? [String: Any])
            pending["operation_id"] = originalID; pending["state"] = "pending"; pending["result"] = NSNull()
            pending.removeValue(forKey: "operation_receipt"); pending.removeValue(forKey: "result_available")
            if isLate {
                lateStatusReturned = true
                if lateFailure { pending["state"] = "denied"; pending["success"] = false; pending["error"] = "declared_fixture_late_error" }
            }
            return (try data(pending), 200)
        }
        guard path.hasSuffix("/operation") else { throw DJConnectError.invalidResponse }
        if body["operation"] as? String == "ask_dj/moments/cancel" {
            cancelCount += 1; throw URLError(.networkConnectionLost)
        }
        requestCount += 1; originalStarted = true; originalID = try #require(body["operation_id"] as? String)
        do { while !releaseOriginal { try await Task.sleep(for: .milliseconds(5)) } }
        catch { originalCancelled = true; throw error }
        var accepted = try #require(fixture["accepted_http_response"] as? [String: Any])
        accepted["operation_id"] = originalID
        var receipt = try #require(accepted["operation_receipt"] as? [String: Any])
        receipt["operation_id"] = originalID; receipt["operation_epoch"] = "fixture-boot"
        receipt["expires_at_ms"] = Int(Date().timeIntervalSince1970 * 1000)+300000
        accepted["operation_receipt"] = receipt
        var result = try #require(accepted["result"] as? [String: Any])
        var moment = try #require(result["moment"] as? [String: Any])
        var provenance = try #require(moment["user_requested"] as? [String: Any]); provenance["operation_id"] = originalID
        moment["user_requested"] = provenance; result["moment"] = moment; accepted["result"] = result
        return (try data(accepted), 200)
    }
    func socket(_ url: URL) async throws -> any DJConnectHybridSocket { throw URLError(.cannotConnectToHost) }
    func denyOwner() { ownerDenied = true }
    func release() { releaseOriginal = true }
    func releaseLateStatus() { lateStatus?.resume(); lateStatus = nil }
}

@Test(arguments: [false, true]) @MainActor func momentsStatusAfterLostCancelCannotCancelOriginalPostOrEraseAcceptedResult(lateFailure: Bool) async throws {
    let wire = try MomentsControllerWire(lateFailure: lateFailure)
    let identity = DJConnectIdentity(deviceID: "declared-controller-fixture", deviceName: "Fixture", clientType: .ios, firmware: "4.1.0", appVersion: "4.1.0", platform: .ios)
    let store = DJConnectInMemoryTokenStore(token: "declared-fixture-token")
    let url = try #require(URL(string: "https://paired.example"))
    let hybrid = DJConnectHybridTransport(localURL: nil, remoteURL: url, expectedInstallID: "controller-fixture-install", identity: identity, tokenStore: store, wire: wire)
    let client = DJConnectClient(baseURL: url, identity: identity, tokenStore: store, hybridTransport: hybrid)
    let fixtureURL = try #require(askDJMomentsFixtureURL("producer-final"))
    let fixture = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL)) as? [String: Any])
    let rawInventory = try JSONSerialization.data(withJSONObject: try #require(fixture["inventory"]))
    let inventory = try JSONDecoder().decode(DJConnectAskDJMoments.Inventory.self, from: rawInventory)
    var owner: AskDJMomentsController.Scope? = .init(profileID: "declared-fixture-profile", sessionID: inventory.sessionID, binding: "fixture-binding", settingsGeneration: "fixture-generation", voiceRevision: "fixture-voice", historyEpoch: UUID(), connection: UUID(), revision: 1)
    var presentationTime: TimeInterval = 0
    let controller = AskDJMomentsController(testClient: client, scope: { owner }, now: { presentationTime })
    controller.open()
    for _ in 0..<1000 { if controller.inventory != nil { break }; try await Task.sleep(for: .milliseconds(2)) }
    let item = try #require(controller.inventory?.types.first { $0.typeID == "artist_story" })
    controller.select(item)
    let generation = controller.generation
    for _ in 0..<1000 { if await wire.originalStarted { break }; try await Task.sleep(for: .milliseconds(2)) }
    #expect(await wire.originalStarted)
    let originalOperation = try #require(controller.operationID)
    controller.cancel()
    for _ in 0..<1000 { if await wire.statusCount > 0 { break }; try await Task.sleep(for: .milliseconds(2)) }
    #expect(controller.checkingCancellation)
    controller.checkStatus()
    for _ in 0..<1000 { if await wire.statusCount > 1 { break }; try await Task.sleep(for: .milliseconds(2)) }
    #expect(controller.checkingCancellation)
    #expect(!(await wire.originalCancelled))
    await wire.release()
    for _ in 0..<1000 { if controller.currentResult != nil { break }; try await Task.sleep(for: .milliseconds(2)) }
    let result = try #require(controller.currentResult)
    #expect(result.moment.userRequested?.operationID == originalOperation)
    #expect(controller.generation == generation)
    #expect(await wire.requestCount == 1)
    #expect(await wire.cancelCount == 1)
    #expect(!controller.checkingCancellation)
    await wire.releaseLateStatus()
    for _ in 0..<1000 { if await wire.lateStatusReturned { break }; try await Task.sleep(for: .milliseconds(2)) }
    for _ in 0..<10 { await Task.yield() }
    #expect(controller.currentResult?.moment.id == result.moment.id)
    #expect(controller.presentation.momentID == result.moment.id)
    controller.checkStatus() // Terminal accepted state cannot become pending/notice again.
    #expect(controller.currentResult?.moment.id == result.moment.id)
    let reference = DJConnectSpeechReference.moment(sessionID: result.moment.sessionID, momentID: result.moment.id)
    controller.visibility(true, generation: generation)
    presentationTime = 19; controller.tick()
    controller.observeSpeech(reference: reference, preparing: true, playing: false)
    presentationTime = 80; controller.tick()
    #expect(controller.currentResult?.moment.id == result.moment.id)
    #expect(controller.presentation.holds.contains(.preparation))
    #expect(!controller.presentation.holds.contains(.narration))
    controller.observeSpeech(reference: .moment(sessionID: result.moment.sessionID, momentID: "different-contribution"), preparing: true, playing: true)
    presentationTime = 80.25; controller.tick()
    #expect(controller.presentation.remainingVisibleSeconds == 0.75)
    controller.observeSpeech(reference: reference, preparing: false, playing: true)
    presentationTime = 160; controller.tick()
    #expect(controller.presentation.remainingVisibleSeconds == 0.75)
    #expect(controller.presentation.holds.contains(.narration))
    controller.observeSpeech(reference: reference, preparing: false, playing: false)
    presentationTime = 160.25; controller.tick()
    #expect(controller.presentation.remainingVisibleSeconds == 0.5)
    controller.observeSpeech(reference: reference, preparing: true, playing: false)
    if lateFailure {
        controller.hold(.reading, true, generation: generation)
        await wire.denyOwner()
        for _ in 0..<2000 { if controller.presentation.phase == .idle { break }; try await Task.sleep(for: .milliseconds(2)) }
    } else { owner = nil; controller.tick() }
    #expect(controller.currentResult == nil)
    #expect(controller.presentation.phase == .idle)
}
