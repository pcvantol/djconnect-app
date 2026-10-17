import Foundation
import Testing
@testable import DJConnectCore

private func watchSettings() throws -> DJConnectProfileDJSettingsResponse {
    let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/profile-settings3-core-1329ad1.json")
    let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
    let cases = try #require(root["cases"] as? [[String: Any]])
    let value = try #require(cases.first { $0["case"] as? String == "paired_no_session_all_five" }?["response"])
    return try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self, from: JSONSerialization.data(withJSONObject: value))
}

@Test @MainActor func watchForegroundSessionRequiresOwnContextAndNeverResurrectsAfterResumeOrABA() async throws {
    let value = DJConnectWatchSessionSnapshot(settings: try watchSettings(), session: nil)
    #expect(value.isValid)
    let state = DJConnectWatchForegroundSession()
    var calls = 0
    await state.refresh { calls += 1; return value }
    #expect(calls == 0)
    state.bind(owner: "own-paired-watch", active: true)
    await state.refresh { calls += 1; return value }
    #expect(state.current()?.settings.binding == value.settings.binding)
    await state.refresh { calls += 1; return value }
    #expect(calls == 1) // Coalesced foreground refresh, no background poll.
    #expect(state.current(at: Date().addingTimeInterval(-60)) == nil)
    #expect(state.current(uptime: ProcessInfo.processInfo.systemUptime + 30) == nil)
    state.bind(owner: "own-paired-watch", active: false)
    #expect(state.snapshot == nil)
    state.bind(owner: "own-paired-watch", active: true)
    #expect(state.current() == nil)
    var old: CheckedContinuation<DJConnectWatchSessionSnapshot, any Error>?
    let task = Task { await state.refresh { try await withCheckedThrowingContinuation { old = $0 } } }
    while old == nil { await Task.yield() }
    state.bind(owner: "other-watch", active: true)
    state.bind(owner: "own-paired-watch", active: true)
    old?.resume(returning: value); await task.value
    #expect(state.snapshot == nil)
    await state.refresh { value }
    #expect(state.current() != nil)
    await state.refresh(force: true) { throw DJConnectError.authStale(statusCode: 401, message: nil) }
    #expect(state.current() == nil && state.unavailable)
}

@Test func watchSettingsCompanionRoundTripPreservesCASAndDoesNotCarryBearerOrPassiveGrant() throws {
    let current = try watchSettings()
    let update = DJConnectWatchSettingsUpdate(current: current, patch: .init(mood: "groove"), operationID: UUID().uuidString)
    let encoded = try JSONEncoder().encode(update)
    let decoded = try JSONDecoder().decode(DJConnectWatchSettingsUpdate.self, from: encoded)
    #expect(decoded.current == current)
    #expect(decoded.patch == update.patch && decoded.operationID == update.operationID)
    let text = String(decoding: encoded, as: UTF8.self).lowercased()
    for forbidden in ["bearer", "device_token", "grant_id", "passive_surface"] { #expect(!text.contains(forbidden)) }
    #expect(encoded.count < 42_000)
}

@Test @MainActor func watchCompanionTimeoutMalformedCancellationAndLateRepliesAlwaysFinishOnce() async throws {
    let pending = DJConnectWatchProxyRequests(timeout: .milliseconds(20))
    let timedOut = await pending.request { _ in }
    #expect(!timedOut.success && timedOut.error == "outcome_unknown" && pending.count == 0)
    let malformed = await pending.request { id in pending.receive(id: id, data: Data("bad json".utf8)) }
    #expect(malformed.error == "invalid_response" && pending.count == 0)
    var original: String?
    let task = Task { await pending.request { original = $0 } }
    while original == nil { await Task.yield() }
    pending.cancelAll()
    let response = await task.value
    #expect(response.error == "outcome_unknown")
    pending.receive(id: original!, data: try JSONEncoder().encode(DJConnectWatchProxyResponse(success: true)))
    #expect(pending.count == 0)
    let cancelled = Task { await pending.request { _ in } }
    while pending.count == 0 { await Task.yield() }
    cancelled.cancel()
    #expect(await cancelled.value.error == "outcome_unknown")
    #expect(pending.count == 0)
}

@Test @MainActor func watchCompanionBoundsConcurrentWorkAndDoesNotReplayTimedOutWrites() async {
    let pending = DJConnectWatchProxyRequests(timeout: .seconds(2))
    var sends = 0
    let tasks = (0..<8).map { _ in Task { await pending.request { _ in sends += 1 } } }
    while pending.count < 8 { await Task.yield() }
    let overflow = await pending.request { _ in sends += 1 }
    #expect(overflow.error == "outcome_unknown" && sends == 8)
    pending.cancelAll()
    for task in tasks { #expect(await task.value.error == "outcome_unknown") }
    #expect(pending.count == 0)
}

@Test func watchSessionCopyExistsInEveryLanguage() {
    for language in DJConnectLocalization.supportedLanguageCodes {
        for key in ["watch.session.loading", "watch.session.unavailable", "watch.session.waiting", "watch.session.settings"] {
            #expect(DJConnectLocalization.localized(key: key, language: language) != key)
        }
    }
}

@Test func watchForegroundCardsRetainNativeDeadlinesAndRejectMixedProfileSessionBindings() throws {
    let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures")
    let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: fixtures.appendingPathComponent("native-moment-receipt.json"))) as? [String: Any])
    let after = try #require(root["after"] as? [String: Any])
    let response = try #require(after["http_shared_producer"] as? [String: Any])
    let broadcast = try JSONDecoder().decode(DJConnectBroadcastState.self, from: JSONSerialization.data(withJSONObject: response["snapshot"]!))
    let now = try #require(broadcast.djMoments.last?.createdAt).flatMapDate()
    let cases = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: fixtures.appendingPathComponent("profile-settings3-core-1329ad1.json"))) as? [String: Any])["cases"] as! [[String: Any]]
    var settingsObject = cases.first { $0["case"] as? String == "active_atomic_all_five_and_replay" }!["response"] as! [String: Any]
    var snapshotObject = settingsObject["snapshot"] as! [String: Any]
    var sessionObject = snapshotObject["session"] as! [String: Any]
    sessionObject["session_id"] = broadcast.session.sessionID
    snapshotObject["session"] = sessionObject; settingsObject["snapshot"] = snapshotObject
    // Bind two independent producer fixtures only for this modeled consumer test.
    let settings = try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self, from: JSONSerialization.data(withJSONObject: settingsObject))
    let effective = settings.snapshot.effective
    var runtime = DJConnectSessionRuntime(sessionID: broadcast.session.sessionID, room: "fixture",
        selectedMood: effective.mood, selectedPresence: effective.presence, selectedPersona: effective.persona,
        musicBackend: "spotify", runtimeState: "active", startedAt: broadcast.djMoments.first!.createdAt,
        planner: .init(planningHorizonMinutes: 5), broadcast: broadcast)
    let visible = DJConnectWatchSessionSnapshot(settings: settings, session: runtime, at: now)
    #expect(visible.isValid)
    #expect(visible.session?.broadcast.nativeCurrentMoment(at: now)?.id == broadcast.nativeCurrentMoment(at: now)?.id)
    #expect(visible.session?.broadcast.nativeFlowMoments(at: now).map(\.id) == broadcast.nativeFlowMoments(at: now).map(\.id))
    #expect(visible.session?.broadcast.sessionMedia.isEmpty == true)
    #expect(visible.session?.broadcast.presentations.isEmpty == true)
    #expect(visible.session?.broadcast.djMoments.allSatisfy { $0.actions.isEmpty && $0.artwork == nil } == true)
    let roundTrip = try JSONDecoder().decode(DJConnectWatchSessionSnapshot.self, from: JSONEncoder().encode(visible))
    #expect(roundTrip.session?.broadcast.nativeDelivery == visible.session?.broadcast.nativeDelivery)
    var nullable = broadcast.nativeDelivery!
    nullable.currentMomentID = nil
    nullable.admissions[0].displayExpiresAt = nil
    let nullableRoundTrip = try JSONDecoder().decode(DJConnectNativeMomentDelivery.self, from: JSONEncoder().encode(nullable))
    #expect(nullableRoundTrip == nullable) // Required nulls must not disappear in the companion bridge.
    let deadline = try #require(broadcast.nativeDelivery?.admissions.last?.sourceExpiresAt).flatMapDate()
    #expect(visible.session?.broadcast.nativeCurrentMoment(at: deadline) == nil)
    runtime.sessionID = "different-session"
    #expect(!DJConnectWatchSessionSnapshot(settings: settings, session: runtime, at: now).isValid)
    #expect(!DJConnectWatchSessionSnapshot(settings: settings, session: nil).isValid)
}

private extension String {
    func flatMapDate() throws -> Date { try #require(DJConnectHistoryEntry.date(self)) }
}

@Test @MainActor func watchSettingsRejectionKeepsReachableRouteAndNeverReplaysThePatch() async throws {
    let store = DJConnectInMemoryTokenStore(token: "fixture-only")
    let identity = DJConnectIdentity(deviceID: "djconnect-watch-test", deviceName: "Watch", clientType: .watchos, firmware: DJConnectProtocolVersion.current, platform: .watchos)
    let manager = DJConnectHATransportManager(localURL: URL(string: "http://fixture.invalid"), remoteURL: URL(string: "https://remote.invalid"), allowsRemoteFallback: true,
        clientFactory: { DJConnectClient(baseURL: $0, identity: identity, tokenStore: store) })
    var calls = 0
    do {
        let _: Bool = try await manager.perform { _ in
            calls += 1
            throw DJConnectProfileDJSettingsFailure(error: "settings_conflict")
        }
        Issue.record("A rejected settings mutation must remain rejected")
    } catch let rejection as DJConnectProfileDJSettingsFailure { #expect(rejection.error == "settings_conflict") }
    #expect(calls == 1)
}
