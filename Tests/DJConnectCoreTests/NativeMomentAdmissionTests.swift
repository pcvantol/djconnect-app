import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

private func nativeReceipt() throws -> [String: Any] {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/native-moment-receipt.json"))) as? [String: Any])
}
private func decodeSnapshot(_ object: Any) throws -> DJConnectBroadcastState {
    try JSONDecoder().decode(DJConnectBroadcastState.self, from: JSONSerialization.data(withJSONObject: object))
}
private func nativeDate(_ raw: String) throws -> Date {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return try #require(f.date(from: raw))
}
@Test func pinnedNativeOwnerReceiptPreservesCurrentRecallBothLinksAndOriginalDeadlines() throws {
    let receipt = try nativeReceipt()
    #expect(receipt["producer_sha"] as? String == "3d17994d28c71402a9076c0082c490820204ccda")
    let after = try #require(receipt["after"] as? [String: Any])
    let initial = try decodeSnapshot((after["http_initial"] as! [String: Any])["snapshot"]!)
    let shared = try decodeSnapshot((after["http_shared_producer"] as! [String: Any])["snapshot"]!)
    let first = try #require(initial.djMoments.first)
    let second = try #require(shared.djMoments.last)
    let firstDate = try nativeDate(first.createdAt)
    let secondDate = try nativeDate(second.createdAt)
    #expect(initial.nativeCurrentMoment(at: firstDate)?.id == first.id)
    #expect(shared.nativeCurrentMoment(at: secondDate)?.id == second.id)
    #expect(shared.nativeFlowMoments(at: secondDate).map(\.id) == [first.id])
    #expect(second.nativeSourceURLs.count == 2)
    #expect(second.nativeSourceURLs.map(\.absoluteString) == [second.sourceAttribution!["url"]!, second.sourceAttribution!["url_previous"]!])
    #expect(second.presentationIntent.djPersona == "home_dj")
    #expect(shared.nativeDelivery?.admissions.last?.sourceExpiresAt == initial.nativeDelivery?.admissions.first?.sourceExpiresAt)
    let sourceExpiry = try nativeDate(shared.nativeDelivery!.admissions.last!.sourceExpiresAt!)
    #expect(shared.nativeCurrentMoment(at: sourceExpiry) == nil)
    #expect(shared.nativeFlowMoments(at: sourceExpiry).isEmpty)
    let displayExpiry = try nativeDate(shared.nativeDelivery!.admissions.last!.displayExpiresAt!)
    #expect(shared.nativeCurrentMoment(at: displayExpiry) == nil)
    #expect(shared.nativeFlowMoments(at: displayExpiry).map(\.id) == [first.id,second.id])
    var unknown = shared; unknown.nativeDelivery?.schemaVersion = 99
    #expect(unknown.nativeCurrentMoment(at: secondDate) == nil)
    #expect(unknown.nativeFlowMoments(at: secondDate).isEmpty)
    var missing = shared; missing.nativeDelivery?.admissions[1].sourceExpiresAt = nil
    #expect(missing.nativeCurrentMoment(at: secondDate) == nil)
    var spotify = shared; spotify.nativeDelivery?.admissions[1].requiresSpotifyAttribution = true
    #expect(spotify.nativeCurrentMoment(at: secondDate) == nil)
    var malformedLink = shared; malformedLink.djMoments[1].sourceAttribution?["url_previous"] = "javascript:invalid"
    #expect(malformedLink.nativeCurrentMoment(at: secondDate) == nil)
    var missingAuthority = shared; missingAuthority.nativeDelivery = nil
    #expect(missingAuthority.nativeFlowMoments(at: secondDate).isEmpty)
    #expect(missingAuthority.nativeCurrentMoment(at: secondDate) == nil)
}
@Test func ownerEventsReplaceAdmissionExpiryAndTerminalDenialPrecedesOrdering() throws {
    let receipt = try nativeReceipt(); let after = receipt["after"] as! [String: Any]
    let initial = try decodeSnapshot((after["http_initial"] as! [String: Any])["snapshot"]!)
    let events = try JSONDecoder().decode([DJConnectSessionBroadcastEvent].self, from: JSONSerialization.data(withJSONObject: after["events"]!))
    let old = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/moment-contract-receipt.json")
    let object = try JSONSerialization.jsonObject(with:Data(contentsOf:old)) as! [String: Any]
    var runtime = try JSONDecoder().decode(DJConnectSessionRuntime.self, from:JSONSerialization.data(withJSONObject:object["runtime"]!))
    runtime.sessionID = initial.session.sessionID; runtime.broadcast = initial
    for event in events.prefix(5) { runtime = runtime.applying(broadcastEvent:event) }
    let shared = try decodeSnapshot((after["http_shared_producer"] as! [String: Any])["snapshot"]!)
    #expect(runtime.broadcast.nativeDelivery == shared.nativeDelivery)
    #expect(runtime.broadcast.djMoments == shared.djMoments)
    for event in events.dropFirst(5).prefix(2) { runtime = runtime.applying(broadcastEvent:event) }
    #expect(runtime.broadcast.nativeDelivery == (try decodeSnapshot(after["expired"]!)).nativeDelivery)
    #expect(runtime.broadcast.djMoments.isEmpty)
    var denial = try #require(events.last)
    denial.deliverySequence = nil
    runtime.broadcast.delivery = .init(snapshotWatermark: 999)
    runtime = runtime.applying(broadcastEvent:denial)
    #expect(runtime.broadcast.nativeDelivery == nil)
    #expect(runtime.runtimeState == "ended")
    #expect(runtime.broadcast.djMoments.isEmpty)
    runtime.broadcast = shared; runtime.runtimeState = "active"
    denial.payload.nativeDelivery?.revocationScope = "subscription"
    runtime = runtime.applying(broadcastEvent:denial)
    #expect(runtime.runtimeState == "active")
    #expect(runtime.broadcast.nativeDelivery == nil)
    #expect(runtime.broadcast.djMoments.isEmpty)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_NATIVE_NETWORK_TEST"] == "1")) @MainActor
func nativeOwnerHTTPWebSocketBackgroundExpiryReconnectAndUnsequencedTerminal() async throws {
    let base = URL(string: "http://127.0.0.1:18787")!
    _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/native_reset"))
    let defaults = UserDefaults(suiteName: "native-owner-contract-test")!
    defaults.removePersistentDomain(forName: "native-owner-contract-test")
    defaults.set(base.absoluteString, forKey: "DJConnectHomeAssistantURL")
    defaults.set(base.absoluteString, forKey: "DJConnectHALocalURL")
    let model = DJConnectUI.DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(token: "local-moment-contract-fixture"), startBackgroundTasks: false)
    await model.refreshActiveDJSession()
    try await Task.sleep(for: .seconds(1))
    #expect(model.activeDJSession?.broadcast.nativeCurrentMoment(at: Date())?.nativeSourceURLs.count == 1)
    _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/advance"))
    try await Task.sleep(for: .seconds(1))
    #expect(model.activeDJSession?.broadcast.nativeCurrentMoment(at: Date())?.nativeSourceURLs.count == 2)
    #expect(model.activeDJSession?.broadcast.nativeFlowMoments(at: Date()).count == 1)
    _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/delay_active"))
    let lateHTTP = Task { await model.refreshActiveDJSession() }
    try await Task.sleep(for: .milliseconds(100))
    model.markInactiveSession()
    await lateHTTP.value
    #expect(model.activeDJSession?.broadcast.nativeDelivery == nil)
    #expect(model.activeDJSession?.broadcast.djMoments.isEmpty == true)
    model.markActiveSession()
    await model.refreshActiveDJSession()
    try await Task.sleep(for: .seconds(1))
    #expect(model.activeDJSession?.broadcast.nativeCurrentMoment(at: Date())?.nativeSourceURLs.count == 2)
    _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/expire"))
    try await Task.sleep(for: .seconds(1))
    #expect(model.activeDJSession?.broadcast.djMoments.isEmpty == true)
    #expect(model.activeDJSession?.broadcast.nativeCurrentMoment(at: Date()) == nil)
    _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/reconnect"))
    try await Task.sleep(for: .seconds(2))
    #expect(model.activeDJSession?.broadcast.nativeFlowMoments(at: Date()).isEmpty == true)
    _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/terminal_denial"))
    try await Task.sleep(for: .seconds(1))
    #expect(model.activeDJSession == nil)
    model.markInactiveSession()
    defaults.removePersistentDomain(forName: "native-owner-contract-test")
}
