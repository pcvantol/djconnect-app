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
    let trackChangeEvents: [DJConnectSessionBroadcastEvent]
    let trackChangeSnapshot: DJConnectBroadcastState
    enum CodingKeys: String, CodingKey {
        case runtime, snapshot, events
        case producerSHA = "producer_sha", updatedSnapshot = "updated_snapshot"
        case trackChangeEvents = "track_change_events", trackChangeSnapshot = "track_change_snapshot"
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
    let previousItem = runtime.broadcast.playback?.itemID
    for event in receipt.trackChangeEvents { runtime = runtime.applying(broadcastEvent: event) }
    var visibleSnapshot = receipt.trackChangeSnapshot
    // Silence is represented by committed Flow/Presentation, not a visual
    // dj_moment_published event. Do not manufacture a missing Moment locally.
    visibleSnapshot.djMoments.removeAll { $0.type == "silence" }
    #expect(runtime.broadcast == visibleSnapshot)
    #expect(runtime.broadcast.playback?.title == "Next")
    #expect(runtime.broadcast.playback?.itemID != previousItem)
    #expect(runtime.broadcast.djMoments.allSatisfy { $0.playbackItemID != runtime.broadcast.playback?.itemID })
    #expect(runtime.broadcast.sessionFlow.items.last?.momentType == "silence")
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
    var session = try #require(json["session"] as? [String: Any])
    session["locale"] = 123
    json["session"] = session
    var flow = try #require(json["session_flow"] as? [String: Any])
    flow["flow_revision"] = "invalid"
    var items = try #require(flow["items"] as? [[String: Any]])
    items[0]["moment_id"] = 123
    items[0]["moment_type"] = 123
    flow["items"] = items
    json["session_flow"] = flow
    let decoded = try JSONDecoder().decode(DJConnectBroadcastState.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(decoded.session.sessionID == receipt.snapshot.session.sessionID)
    #expect(decoded.session.locale == nil)
    #expect(decoded.sessionFlow.flowRevision == nil)
    #expect(decoded.sessionFlow.items.first?.label == receipt.snapshot.sessionFlow.items.first?.label)
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
    _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/reset"))
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

@Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_MOMENT_NETWORK_TEST"] == "1")) @MainActor
func rejectedOwnerSubscriptionRemovesPrivateProjectionWithoutClaimingRuntimeEnd() async throws {
    let base = URL(string: "http://127.0.0.1:18787")!
    _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/reset"))
    let defaults = UserDefaults(suiteName: "moment-owner-rejection-test")!
    defaults.removePersistentDomain(forName: "moment-owner-rejection-test")
    defaults.set(base.absoluteString, forKey: "DJConnectHomeAssistantURL")
    defaults.set(base.absoluteString, forKey: "DJConnectHALocalURL")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(token: "local-moment-contract-fixture"), startBackgroundTasks: false)
    await model.refreshActiveDJSession()
    #expect(model.activeDJSession != nil)
    try await Task.sleep(for: .seconds(1))
    _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/reject_owner"))
    try await Task.sleep(for: .seconds(2))
    #expect(model.activeDJSession == nil)
    #expect(model.djSessionErrorMessage != nil)
    let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/metrics"))
    let metrics = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(metrics["ended"] as? Bool == false)
    #expect(metrics["playbackMutations"] as? Int == 0)
    defaults.removePersistentDomain(forName: "moment-owner-rejection-test")
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_MOMENT_NETWORK_TEST"] == "1"))
func ownerSessionTextNeverEntersParentURLCacheEvenWithCacheableResponse() async throws {
    let base = URL(string: "http://127.0.0.1:18787")!
    _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/reset"))
    _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/cacheable"))
    let cache = URLCache(memoryCapacity: 1_048_576, diskCapacity: 0, diskPath: nil)
    let configuration = URLSessionConfiguration.default
    configuration.urlCache = cache
    let parent = URLSession(configuration: configuration)
    defer { parent.invalidateAndCancel(); cache.removeAllCachedResponses() }
    let client = DJConnectClient(baseURL: base, identity: DJConnectIdentity(deviceID: "djconnect-ios-8F3A2C91B45D", deviceName: "Test", clientType: .ios, firmware: "4.0.0-rc.1", platform: .ios), tokenStore: DJConnectInMemoryTokenStore(token: "local-moment-contract-fixture"), session: parent)
    let request = try client.activeSessionRequest()
    let response = try await client.activeSession()
    #expect(response.resolvedSession?.broadcast.djMoments.isEmpty == false)
    try await Task.sleep(for: .milliseconds(200))
    #expect(cache.cachedResponse(for: request) == nil)
    // Calibrate the memory-only cache with the same deliberately cacheable
    // response. CFNetwork may choose not to automatically cache auth responses.
    let (data, rawResponse) = try await parent.data(for: request)
    let httpResponse = try #require(rawResponse as? HTTPURLResponse)
    #expect(httpResponse.value(forHTTPHeaderField: "Cache-Control")?.contains("public") == true)
    cache.storeCachedResponse(CachedURLResponse(response: rawResponse, data: data, storagePolicy: .allowedInMemoryOnly), for: request)
    #expect(cache.cachedResponse(for: request) != nil)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_MOMENT_NETWORK_TEST"] == "1"))
func sessionDecodeFailureOmitsPrivateMomentBodyFromDiagnostics() async throws {
    let base = URL(string: "http://127.0.0.1:18787")!
    _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/reset"))
    _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/malformed"))
    let client = DJConnectClient(baseURL: base, identity: DJConnectIdentity(deviceID: "djconnect-ios-8F3A2C91B45D", deviceName: "Test", clientType: .ios, firmware: "4.0.0-rc.1", platform: .ios), tokenStore: DJConnectInMemoryTokenStore(token: "local-moment-contract-fixture"))
    do {
        _ = try await client.activeSession()
        Issue.record("The malformed required Session field must fail decoding.")
    } catch let error as DJConnectError {
        guard case let .decodingFailed(_, _, message) = error else { Issue.record("Expected a classified decode failure."); return }
        #expect(message?.contains("response_body=<omitted>") == true)
        #expect(message?.contains("genrecontext") == false)
        #expect(message?.contains("Current") == false)
    }
}
