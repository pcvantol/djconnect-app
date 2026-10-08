import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

private struct MomentReceipt: Decodable {
    let producerSHA: String
    let runtime: DJConnectSessionRuntime
    let snapshot: DJConnectBroadcastState
    let events: [DJConnectSessionBroadcastEvent]
    let updatedSnapshot: DJConnectBroadcastState
    enum CodingKeys: String, CodingKey {
        case runtime, snapshot, events
        case producerSHA = "producer_sha", updatedSnapshot = "updated_snapshot"
    }
}

private func receiptData() throws -> Data {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try Data(contentsOf: root.appendingPathComponent("Fixtures/moment-contract-receipt.json"))
}

@Test func producerReceiptSnapshotAndEventsPreserveMomentsFlowAndPresentation() throws {
    let receipt = try JSONDecoder().decode(MomentReceipt.self, from: receiptData())
    #expect(receipt.producerSHA == "ee05c9422cd7a7a08bbe769925248632fa651961")
    var runtime = receipt.runtime.applying(broadcastState: receipt.snapshot)
    for event in receipt.events { runtime = runtime.applying(broadcastEvent: event) }
    #expect(runtime.broadcast == receipt.updatedSnapshot)
    #expect(runtime.broadcast.djMoments.count == 2)
    #expect(Set(runtime.broadcast.djMoments.map(\.id)).count == 2)
    #expect(Set(runtime.broadcast.djMoments.map(\.type)) == ["track", "genre"])
    #expect(runtime.broadcast.djMoments.last?.content == "The bass and percussion leave space for the melody.")
    #expect(runtime.broadcast.djMoments.last?.presentationIntent.djPersona == "home_dj")
    #expect(runtime.broadcast.djMoments.last?.sourceReferences == ["track_insight"])
    #expect(runtime.broadcast.djMoments.last?.actions.contains(where: { $0.actionType == "tell_me_more" }) == true)
    #expect(runtime.broadcast.presentations.count == 2)
    #expect(runtime.broadcast.presentations.last?.momentID == runtime.broadcast.djMoments.last?.id)
    #expect(runtime.broadcast.sessionFlow.items.compactMap(\.momentID) == runtime.broadcast.djMoments.map(\.id))
    #expect(runtime.broadcast.playback?.title == "Current")
}

@Test func lateSnapshotDuplicateEventsAndPreviousSessionCannotRollbackProducerState() throws {
    let receipt = try JSONDecoder().decode(MomentReceipt.self, from: receiptData())
    var runtime = receipt.runtime.applying(broadcastState: receipt.updatedSnapshot)
    let latest = runtime
    runtime = runtime.applying(broadcastState: receipt.snapshot)
    for event in receipt.events { runtime = runtime.applying(broadcastEvent: event) }
    #expect(runtime == latest)
    var foreign = receipt.events.last!
    foreign.sessionID = "previous-session"
    foreign.deliverySequence = 99999
    #expect(runtime.applying(broadcastEvent: foreign) == latest)
}

@Test func malformedOptionalMomentCannotDiscardSessionOrOtherAuthorizedMoments() throws {
    let receipt = try JSONDecoder().decode(MomentReceipt.self, from: receiptData())
    var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt.updatedSnapshot)) as? [String: Any])
    var moments = try #require(json["dj_moments"] as? [[String: Any]])
    moments.append(["moment_id": "invalid", "content": 123])
    moments.append(moments[1]) // duplicate snapshot identity
    var wrongSession = moments[1]
    wrongSession["session_id"] = "previous-session"
    moments.append(wrongSession)
    moments[0]["artwork"] = ["url": 123]
    moments[0]["actions"] = [["action_type": "future", "label": "Server supplied"], ["action_type": 123]]
    moments[0]["type"] = "future_type"
    json["dj_moments"] = moments
    let decoded = try JSONDecoder().decode(DJConnectBroadcastState.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(decoded.session == receipt.snapshot.session)
    #expect(decoded.djMoments.count == 2)
    #expect(decoded.djMoments.first?.type == "future_type")
    #expect(decoded.djMoments.first?.artwork == nil)
    #expect(decoded.djMoments.first?.actions.count == 1)
    let event = #"{"event_type":"dj_moment_published","session_id":"test","delivery_sequence":2,"payload":{"dj_moment":{"content":123}}}"#
    #expect(try JSONDecoder().decode(DJConnectSessionBroadcastEvent.self, from: Data(event.utf8)).payload.djMoment == nil)
}

// Opt-in network acceptance against Tools/moment_contract_server.js.
// This uses the same client, owner WebSocket, state reducer as the native app.
@Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_MOMENT_NETWORK_TEST"] == "1")) @MainActor func ownerHTTPAndWebSocketDriveAppStateAcrossReconnectAndEnd() async throws {
    guard ProcessInfo.processInfo.environment["DJCONNECT_MOMENT_NETWORK_TEST"] == "1" else { return }
    let base = URL(string: "http://127.0.0.1:18787")!
    let defaults = UserDefaults(suiteName: "moment-network-contract-test")!
    defaults.removePersistentDomain(forName: "moment-network-contract-test")
    defaults.set(base.absoluteString, forKey: "DJConnectHomeAssistantURL")
    defaults.set(base.absoluteString, forKey: "DJConnectHALocalURL")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(token: "local-moment-contract-fixture"), startBackgroundTasks: false)
    await model.refreshActiveDJSession()
    #expect(model.activeDJSession?.broadcast.djMoments.count == 1)
    try await Task.sleep(for: .seconds(1))
    _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/advance"))
    try await Task.sleep(for: .seconds(1))
    #expect(model.activeDJSession?.broadcast.djMoments.count == 2)
    let activeID = model.activeDJSession?.id
    _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/reconnect"))
    try await Task.sleep(for: .seconds(2))
    #expect(model.activeDJSession?.id == activeID)
    #expect(model.activeDJSession?.broadcast.djMoments.count == 2)
    await model.endDJSession()
    #expect(model.activeDJSession == nil)
    let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/metrics"))
    let metrics = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(metrics["playbackMutations"] as? Int == 0)
    #expect(metrics["ended"] as? Bool == true)
    defaults.removePersistentDomain(forName: "moment-network-contract-test")
}
