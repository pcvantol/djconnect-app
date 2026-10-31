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

@Test(.isolatedClientResources) @MainActor func watchForegroundSessionRequiresOwnContextAndNeverResurrectsAfterResumeOrABA() async throws {
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

@Test(.isolatedClientResources) func watchSettingsCompanionRoundTripPreservesCASAndDoesNotCarryBearerOrPassiveGrant() throws {
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

@Test(.isolatedClientResources) @MainActor func watchCompanionTimeoutMalformedCancellationAndLateRepliesAlwaysFinishOnce() async throws {
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

@Test(.isolatedClientResources) @MainActor func watchCompanionBoundsConcurrentWorkAndDoesNotReplayTimedOutWrites() async {
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

@Test(.isolatedClientResources) func watchSessionCopyExistsInEveryLanguage() {
    for language in DJConnectLocalization.supportedLanguageCodes {
        for key in ["watch.session.loading", "watch.session.unavailable", "watch.session.waiting", "watch.session.settings"] {
            #expect(DJConnectLocalization.localized(key: key, language: language) != key)
        }
    }
}

@Test(.isolatedClientResources) func watchForegroundCardsRetainNativeDeadlinesAndRejectMixedProfileSessionBindings() throws {
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

@Test(.isolatedClientResources) @MainActor func watchSettingsRejectionKeepsReachableRouteAndNeverReplaysThePatch() async throws {
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

@Test(.isolatedClientResources) @MainActor func watchSessionLostWriteOnlyReadsAndCannotReplayAcrossForegroundChanges() async throws {
    let idle = DJConnectWatchSessionSnapshot(settings: try watchSettings(), session: nil)
    let state = DJConnectWatchForegroundSession()
    state.bind(owner: "watch-a", active: true)
    await state.refresh { idle }
    var writes = 0
    var reads = 0
    await state.change(language: "nl", write: { intent in
        writes += 1
        #expect(intent.sessionID == nil && intent.matches(idle))
        throw DJConnectError.network(message: "reply lost")
    }, read: { reads += 1; return idle })
    #expect(writes == 1 && reads == 1 && state.outcomeUnknown && !state.isChanging)
    await state.change(language: "nl", write: { _ in writes += 1 }, read: { idle })
    state.bind(owner: "watch-a", active: false)
    state.bind(owner: "watch-a", active: true)
    await state.refresh { idle }
    await state.change(language: "nl", write: { _ in writes += 1 }, read: { idle })
    #expect(writes == 1 && state.outcomeUnknown)
    state.bind(owner: "watch-b", active: true)
    #expect(!state.outcomeUnknown && state.current() == nil)
}

@Test(.isolatedClientResources) @MainActor func watchSessionDoesNotAdmitConcurrentWritesOrPublishAnOldOwnerCompletion() async throws {
    let idle = DJConnectWatchSessionSnapshot(settings: try watchSettings(), session: nil)
    let state = DJConnectWatchForegroundSession()
    state.bind(owner: "watch-a", active: true)
    await state.refresh { idle }
    var finish: CheckedContinuation<Void, Never>?
    var writes = 0
    let action = Task { await state.change(language: "nl", write: { _ in
        writes += 1
        await withCheckedContinuation { finish = $0 }
    }, read: { idle }) }
    while finish == nil { await Task.yield() }
    await state.refresh(force: true) { Issue.record("A refresh must not race a write"); return idle }
    await state.change(language: "nl", write: { _ in writes += 1 }, read: { idle })
    #expect(writes == 1 && state.isChanging)
    state.bind(owner: "watch-a", active: false)
    state.bind(owner: "watch-a", active: true)
    finish?.resume(); await action.value
    #expect(state.current() == nil && state.outcomeUnknown && !state.isChanging)
}

@Test(.isolatedClientResources) @MainActor func watchSessionReadFailureOffersRecoveryAndSuccessfulReadClearsIt() async throws {
    let state = DJConnectWatchForegroundSession()
    state.bind(owner: "watch", active: true)
    await state.refresh { throw DJConnectError.missingToken }
    #expect(state.failureKey == "watch.session.pair_again")
    await state.refresh(force: true) { throw DJConnectError.invalidConfiguration("phone") }
    #expect(state.failureKey == "watch.session.connect_phone")
    await state.refresh(force: true) { throw DJConnectError.invalidResponse }
    #expect(state.failureKey == "watch.session.retry")
    await state.refresh(force: true) { DJConnectWatchSessionSnapshot(settings: try watchSettings(), session: nil) }
    #expect(!state.unavailable && state.failureKey == nil && state.current() != nil)
}

@Test(.isolatedClientResources) @MainActor func watchSessionExplicitRecoveryOnlyAcceptsAValidatedCurrentRead() async throws {
    let idle = DJConnectWatchSessionSnapshot(settings: try watchSettings(), session: nil)
    let state = DJConnectWatchForegroundSession()
    state.bind(owner: "watch", active: true)
    await state.refresh { idle }
    var writes = 0
    await state.change(language: "nl", write: { _ in writes += 1; throw DJConnectError.invalidResponse }, read: { idle })
    await state.useCurrent { throw DJConnectError.missingToken }
    #expect(state.outcomeUnknown)
    await state.useCurrent { idle }
    #expect(!state.outcomeUnknown && state.current() != nil && writes == 1)
}

@Test(.isolatedClientResources) @MainActor func watchSessionCoherentReadIsBoundedAndNeverAdmitsAnUnsuccessfulRuntime() async throws {
    let settings = try watchSettings()
    let data = Data("{\"success\":true,\"session\":null}".utf8)
    let idle = try JSONDecoder().decode(DJConnectSessionResponse.self, from: data)
    var settingsReads = 0
    let value = try await DJConnectWatchSessionSnapshot.read(settings: { settingsReads += 1; return settings }, session: { idle })
    #expect(value.isValid && settingsReads == 2)
    let rejected = try JSONDecoder().decode(DJConnectSessionResponse.self, from: Data("{\"success\":false}".utf8))
    do {
        _ = try await DJConnectWatchSessionSnapshot.read(settings: { settings }, session: { rejected })
        Issue.record("A failed read must not become an idle Session")
    } catch { #expect(error as? DJConnectError == .invalidResponse) }
}

@Test(.isolatedClientResources) func watchInstallationPersistsBeforeCompanionRegistrationAndSurvivesNewModels() throws {
    let name = "watch-installation-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let first = DJConnectWatchInstallation.load(defaults: defaults, makeID: { "FIRST" }, makeCode: { "123456" })
    let second = DJConnectWatchInstallation.load(defaults: defaults,
        makeID: { Issue.record("An existing Watch must not receive a new identity"); return "SECOND" },
        makeCode: { Issue.record("A model rebuild must preserve its pairing code"); return "654321" })
    #expect(first.id == second.id && first.code == second.code)
    let restored = try #require(UserDefaults(suiteName: name))
    #expect(restored.string(forKey: "stableInstallID") == "FIRST")
    #expect(restored.string(forKey: "pairingCode") == "123456")
}


@Test(.isolatedClientResources) @MainActor func watchSessionWriteRejectsProfileSwitchBetweenOwnerReadsWithNoActiveSession() async throws {
    let original = try watchSettings()
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
    object["binding"] = String(repeating: "a", count: 64)
    let changed = try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(changed.isValid && changed.binding != original.binding)
    let idle = try JSONDecoder().decode(DJConnectSessionResponse.self, from: Data("{\"success\":true,\"session\":null}".utf8))
    let intent = DJConnectWatchSessionAction(snapshot: .init(settings: original, session: nil), language: "nl")
    var reads = 0, writes = 0
    do {
        try await intent.perform(settings: { reads += 1; return reads == 1 ? original : changed },
            session: { idle }, write: { _ in writes += 1; return true })
        Issue.record("A split owner read must not write into the new Profile")
    } catch { #expect(error as? DJConnectError == .invalidResponse) }
    #expect(writes == 0)
}

@Test(.isolatedClientResources) @MainActor func watchSessionWriteUsesOneCoherentReadAndNeverRetriesAnUncertainWrite() async throws {
    let original = try watchSettings()
    let idle = try JSONDecoder().decode(DJConnectSessionResponse.self, from: Data("{\"success\":true,\"session\":null}".utf8))
    let intent = DJConnectWatchSessionAction(snapshot: .init(settings: original, session: nil), language: "nl")
    var reads = 0, writes = 0
    try await intent.perform(settings: { reads += 1; return original }, session: { idle }, write: { submitted in
        writes += 1; #expect(submitted.binding == original.binding); return true
    })
    #expect(reads == 2 && writes == 1)
    do {
        try await intent.perform(settings: { original }, session: { idle }, write: { _ in
            writes += 1; throw DJConnectError.network(message: "synthetic lost response")
        })
        Issue.record("An uncertain response cannot become success")
    } catch { #expect(writes == 2) }
}

@Test(.isolatedClientResources) @MainActor func watchTextReplyUsesItsOwnBoundWithoutRetryingOrChangingOtherRequests() async throws {
    let pending = DJConnectWatchProxyRequests(timeout: .milliseconds(5))
    let payload = try JSONEncoder().encode(["command": "ask_dj_message"])
    #expect(DJConnectWatchProxyRequest(operation: .askDJMessage).isAskDJTextSubmission)
    #expect(DJConnectWatchProxyRequest(operation: .command, payload: payload).isAskDJTextSubmission)
    #expect(!DJConnectWatchProxyRequest(operation: .command, payload: Data("bad".utf8)).isAskDJTextSubmission)
    var sends = 0
    var original: String?
    let task = Task { await pending.request(timeout: .seconds(1)) { id in sends += 1; original = id } }
    while original == nil { await Task.yield() }
    try await Task.sleep(for: .milliseconds(30))
    #expect(pending.count == 1 && sends == 1)
    pending.receive(id: original!, data: try JSONEncoder().encode(DJConnectWatchProxyResponse(success: true, payload: Data())))
    #expect(await task.value.success && pending.count == 0 && sends == 1)
}
