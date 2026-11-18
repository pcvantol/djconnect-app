import Foundation
import CryptoKit
import Testing
@testable import DJConnectCore

@Test func watchPlaylistReplyFitsCompanionBudgetWithoutDroppingRows() throws {
    let artwork = try #require(URL(string: "https://example.com/" + String(repeating: "a", count: 1500)))
    let playlists = (1...39).map {
        DJConnectPlaylist(name: "Playlist \($0)", uri: "spotify:playlist:\($0)", imageURL: artwork)
    }
    let response = DJConnectCommandResponse(success: true, musicBackendAvailable: true, playlists: playlists)
    #expect(try JSONEncoder().encode(response).count >= 42_000)

    let data = try response.encodedWatchPlaylists()
    #expect(data.count < 42_000)
    let decoded = try JSONDecoder().decode(DJConnectCommandResponse.self, from: data)
    #expect(decoded.playlists?.map(\.commandValue) == playlists.map(\.commandValue))
    #expect(decoded.playlists?.map(\.name) == playlists.map(\.name))
    #expect(decoded.musicBackendAvailable == true)

    let small = DJConnectCommandResponse(success: true, playlists: [playlists[0]])
    let smallData = try small.encodedWatchPlaylists()
    #expect(try JSONDecoder().decode(DJConnectCommandResponse.self, from: smallData).playlists?.first?.imageURL == artwork)
}

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

@Test(.isolatedClientResources) @MainActor func watchStackUsesOnlyConfirmedWatchSessionState() async throws {
    let active = try nativeWatchSpeechFixture().2
    let idle = DJConnectWatchSessionSnapshot(settings: try watchSettings(), session: nil)
    let state = DJConnectWatchForegroundSession()
    #expect(state.stackEntry() == nil)

    state.bind(owner: "watch-a", active: true)
    await state.refresh { active }
    let entry = try #require(state.stackEntry())
    #expect(entry.destination == .session)
    #expect(entry.destination.url.absoluteString == "djconnect://watch/session")
    let suite = "WatchStackTests." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let data = try JSONEncoder().encode(entry)
    let wire = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(Set(wire.keys) == ["destination", "observedAt"])
    defaults.set(data, forKey: DJConnectWatchStackEntry.storageKey)
    #expect(DJConnectWatchStackEntry.load(from: defaults, at: entry.observedAt) == entry)
    #expect(DJConnectWatchStackEntry.load(from: defaults, at: entry.observedAt.addingTimeInterval(-1)) == nil)
    #expect(DJConnectWatchStackEntry.load(from: defaults, at: entry.expiresAt) == nil)

    await state.refresh(force: true) { idle }
    #expect(state.stackEntry()?.destination == .askDJ)
    await state.refresh(force: true) { throw DJConnectError.authStale(statusCode: 401, message: nil) }
    #expect(state.stackEntry() == nil)
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

@Test(.isolatedClientResources) @MainActor func watchSpeechReplayAssemblesBoundedForegroundChunks() async {
    let pending = DJConnectWatchProxyRequests(timeout: .milliseconds(20))
    let first = Data(repeating: 17, count: DJConnectWatchProxyRequests.replayChunkBytes)
    let last = Data([18, 19])

    let assembled = await pending.request(allowsReplayChunks: true) { id in
        pending.receiveReplayChunk(id: id, index: 1, count: 2, bytes: last)
        pending.receiveReplayChunk(id: id, index: 0, count: 2, bytes: first)
    }
    #expect(assembled.payload == first + last && pending.count == 0)

    let invalid = await pending.request(allowsReplayChunks: true) { id in
        pending.receiveReplayChunk(id: id, index: 0, count: 2, bytes: last)
    }
    #expect(invalid.error == "invalid_response" && pending.count == 0)

    let unrelated = await pending.request { id in
        pending.receiveReplayChunk(id: id, index: 0, count: 1, bytes: last)
    }
    #expect(unrelated.error == "outcome_unknown" && pending.count == 0)
}

@Test(.isolatedClientResources) @MainActor
func watchSpeechReplayRejectsOversizeFinalChunkBeforeWaitingForOtherChunks() async {
    let requests = DJConnectWatchProxyRequests(timeout: .seconds(1))
    let chunkBytes = DJConnectWatchProxyRequests.replayChunkBytes
    let limit = DJConnectWatchProxyRequests.maximumReplayBytes
    let fullChunks = (limit - 1) / chunkBytes
    let lastChunkBytes = limit - fullChunks * chunkBytes

    let rejected = await requests.request(allowsReplayChunks: true) { id in
        requests.receiveReplayChunk(
            id: id, index: fullChunks, count: fullChunks + 1,
            bytes: Data(repeating: 1, count: lastChunkBytes + 1)
        )
    }
    #expect(rejected.error == "invalid_response")
    #expect(requests.count == 0)

    let accepted = await requests.request(allowsReplayChunks: true) { id in
        requests.receiveReplayChunk(
            id: id, index: fullChunks, count: fullChunks + 1,
            bytes: Data(repeating: 1, count: lastChunkBytes)
        )
        let chunk = Data(repeating: 0, count: chunkBytes)
        for index in 0..<fullChunks {
            requests.receiveReplayChunk(id: id, index: index, count: fullChunks + 1, bytes: chunk)
        }
    }
    #expect(accepted.payload?.count == limit)
    #expect(accepted.payload?.last == 1)
    #expect(requests.count == 0)
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
    let active = try nativeWatchSpeechFixture().2
    let state = DJConnectWatchForegroundSession()
    state.bind(owner: "watch-a", active: true)
    await state.refresh { active }
    var writes = 0
    var reads = 0
    await state.change(language: "nl", write: { intent in
        writes += 1
        #expect(intent.sessionID == active.session?.id && intent.matches(active))
        throw DJConnectError.network(message: "reply lost")
    }, read: { reads += 1; return active })
    #expect(writes == 1 && reads == 1 && state.outcomeUnknown && !state.isChanging)
    await state.change(language: "nl", write: { _ in writes += 1 }, read: { active })
    state.bind(owner: "watch-a", active: false)
    state.bind(owner: "watch-a", active: true)
    await state.refresh { active }
    await state.change(language: "nl", write: { _ in writes += 1 }, read: { active })
    #expect(writes == 1 && state.outcomeUnknown)
    state.bind(owner: "watch-b", active: true)
    #expect(!state.outcomeUnknown && state.current() == nil)
}

@Test(.isolatedClientResources) @MainActor func watchSessionDoesNotAdmitConcurrentWritesOrPublishAnOldOwnerCompletion() async throws {
    let active = try nativeWatchSpeechFixture().2
    let state = DJConnectWatchForegroundSession()
    state.bind(owner: "watch-a", active: true)
    await state.refresh { active }
    var finish: CheckedContinuation<Void, Never>?
    var writes = 0
    let action = Task { await state.change(language: "nl", write: { _ in
        writes += 1
        await withCheckedContinuation { finish = $0 }
    }, read: { active }) }
    while finish == nil { await Task.yield() }
    await state.refresh(force: true) { Issue.record("A refresh must not race a write"); return active }
    await state.change(language: "nl", write: { _ in writes += 1 }, read: { active })
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
    let active = try nativeWatchSpeechFixture().2
    let state = DJConnectWatchForegroundSession()
    state.bind(owner: "watch", active: true)
    await state.refresh { active }
    var writes = 0
    await state.change(language: "nl", write: { _ in writes += 1; throw DJConnectError.invalidResponse }, read: { active })
    await state.useCurrent { throw DJConnectError.missingToken }
    #expect(state.outcomeUnknown)
    await state.useCurrent { active }
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
    let active = try nativeWatchSpeechFixture().2
    let original = active.settings
    let runtime = try #require(active.session)
    let data = try JSONSerialization.data(withJSONObject: ["success": true, "session": JSONSerialization.jsonObject(with: JSONEncoder().encode(runtime))])
    let idle = try JSONDecoder().decode(DJConnectSessionResponse.self, from: data)
    let intent = DJConnectWatchSessionAction(snapshot: active, language: "nl")
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


@Test(.isolatedClientResources) @MainActor func watchNeverStartsSessionFromIdleOrLegacyIntent() async throws {
    let idle = DJConnectWatchSessionSnapshot(settings: try watchSettings(), session: nil)
    let state = DJConnectWatchForegroundSession(); state.bind(owner: "watch", active: true)
    await state.refresh { idle }
    var writes = 0, reads = 0
    await state.change(language: "nl", write: { _ in writes += 1 }, read: { reads += 1; return idle })
    #expect(writes == 0 && reads == 0 && !state.outcomeUnknown)
    do {
        try await DJConnectWatchSessionAction(snapshot: idle, language: "nl").perform(
            settings: { reads += 1; return idle.settings }, session: { reads += 1; throw DJConnectError.invalidResponse },
            write: { _ in writes += 1; return true })
        Issue.record("Legacy no-Session action must be rejected")
    } catch { }
    #expect(writes == 0 && reads == 0)
}

@Test func watchMomentAlertLocatorRejectsOtherFamiliesAndNeverCarriesAuthority() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let payload: [AnyHashable: Any] = ["version": "djc-watch-moment/1", "event_type": "dj_moment_published",
        "event_id": "publication-original", "open_target": "dj_moment", "session_id": "session-original",
        "moment_id": "moment-original", "transport_expires_at_ms": 1_700_000_060_000 as Int64,
        "aps": ["category": "DJCONNECT_MOMENT_V1"]]
    let original = try DJConnectWatchMomentOpenIntent(notification: payload, at: now)
    #expect(original.sessionID == "session-original" && original.momentID == "moment-original")
    #expect(original.isPending(at: now) && !original.isPending(at: now.addingTimeInterval(61)))
    for (key, value) in [("version", "activity/1"), ("open_target", "https://example.com"),
                          ("event_type", "ask_dj_response"), ("moment_id", ""), ("session_id", "bad\nidentifier")] {
        var invalid = payload; invalid[key] = value
        #expect(throws: (any Error).self) { try DJConnectWatchMomentOpenIntent(notification: invalid, at: now) }
    }
    for deadline: Any in [true, 1_700_000_360_000 as Int64, 1_699_999_999_000 as Int64, 1_700_000_060_000.5] {
        var invalid = payload; invalid["transport_expires_at_ms"] = deadline
        #expect(throws: (any Error).self) { try DJConnectWatchMomentOpenIntent(notification: invalid, at: now) }
    }
    let stored = try JSONEncoder().encode(original)
    #expect(try JSONDecoder().decode(DJConnectWatchMomentOpenIntent.self, from: stored) == original)
    let keys = try #require(JSONSerialization.jsonObject(with: stored) as? [String: Any])
    #expect(Set(keys.keys) == ["eventID", "sessionID", "momentID", "transportExpiresAtMS"])
}

@Test func watchVoiceCompanionFreezesExplicitOriginalContextAndOperationID() throws {
    let original = DJConnectConversationContext(sessionID: "original-session")
    let request = DJConnectWatchProxyVoicePayload(wavData: Data([1, 2]), language: "nl-NL",
        conversationContext: original, clientMessageID: "one-explicit-gesture")
    let decoded = try JSONDecoder().decode(DJConnectWatchProxyVoicePayload.self, from: JSONEncoder().encode(request))
    #expect(decoded.conversationContext == original && decoded.clientMessageID == "one-explicit-gesture")
    let legacy = try JSONDecoder().decode(DJConnectWatchProxyVoicePayload.self, from: Data(#"{"wavData":"AQI="}"#.utf8))
    #expect(legacy.conversationContext == nil && legacy.clientMessageID == nil)
}

/// Optional native qualification input only. These modeled clocks are not an
/// installation receipt, passive surface grant or evidence of provider delivery.
@Test(.isolatedClientResources) func watchV2ExportsModeledNativeFixtureOnlyWhenRequested() throws {
    let snapshot = try nativeWatchSpeechFixture(expiresIn: 600).2
    #expect(snapshot.isValid)
    let roundTrip = try JSONDecoder().decode(DJConnectWatchSessionSnapshot.self, from: JSONEncoder().encode(snapshot))
    #expect(roundTrip.isValid)
    guard let path = ProcessInfo.processInfo.environment["DJCONNECT_WATCH_V2_RENDER_FIXTURE"] else { return }
    try JSONEncoder().encode(snapshot).write(to: URL(fileURLWithPath: path), options: .atomic)
}

private func watchVoiceWAV(samples: Int = 96_000) -> Data {
    var data = Data("RIFF".utf8)
    func little(_ value: Int, _ count: Int) { for i in 0..<count { data.append(UInt8(truncatingIfNeeded: value >> (8 * i))) } }
    little(36 + samples * 2, 4); data.append(Data("WAVEfmt ".utf8)); little(16, 4)
    little(1, 2); little(1, 2); little(16_000, 4); little(32_000, 4); little(2, 2); little(16, 2)
    data.append(Data("data".utf8)); little(samples * 2, 4); data.append(Data(repeating: 0, count: samples * 2))
    return data
}
@Test @MainActor func watchVoiceChunksProduceOneOriginalRequestWithoutNestedBase64Limit() throws {
    let source = watchVoiceWAV()
    let context = DJConnectConversationContext(sessionID: "original-session")
    let metadata = DJConnectWatchProxyVoicePayload(wavData: Data(), language: "nl-NL", conversationContext: context, clientMessageID: "1:original-turn")
    let header = try JSONEncoder().encode(metadata)
    let assembly = DJConnectWatchVoiceAssembly(); assembly.bind(owner: "original-watch-owner")
    let size = DJConnectWatchVoiceAssembly.chunkBytes, total = (source.count + size - 1) / size
    var completions = 0
    for index in 0..<total {
        let bytes = source.subdata(in: (index * size)..<min((index + 1) * size, source.count))
        let message: [String: Any] = ["header": header, "bytes": bytes, "index": index, "total": total, "operation_id": "1:original-turn"]
        #expect(try PropertyListSerialization.data(fromPropertyList: message, format: .binary, options: 0).count < 42_000)
        let result = try assembly.receive(id: "1:original-turn", sequence: 1, header: header, index: index, total: total, bytes: bytes, uptime: 10 + Double(index) / 10)
        if let result {
            completions += 1
            #expect(index == total - 1 && result.wavData == source)
            #expect(result.conversationContext == context && result.clientMessageID == "1:original-turn")
        }
    }
    #expect(completions == 1)
    #expect(throws: (any Error).self) { try assembly.receive(id: "1:original-turn", sequence: 1, header: header, index: 0, total: total, bytes: source.prefix(size), uptime: 12) }
}
@Test @MainActor func watchVoiceTransfer257CompletesAndOriginalReplayNeverDispatches() throws {
    let assembly = DJConnectWatchVoiceAssembly()
    assembly.bind(owner: "same-watch-owner")
    let wav = watchVoiceWAV(samples: 1)
    var dispatches = 0

    func transfer(_ sequence: Int, total: Int, at uptime: TimeInterval) throws {
        let id = "\(sequence):turn"
        let metadata = DJConnectWatchProxyVoicePayload(wavData: Data(),
            conversationContext: .init(sessionID: nil), clientMessageID: id)
        let header = try JSONEncoder().encode(metadata)
        if try assembly.receive(id: id, sequence: sequence, header: header, index: 0,
                                total: total, bytes: wav, uptime: uptime) != nil {
            dispatches += 1
        }
    }

    try transfer(1, total: 1, at: 0)
    for sequence in 2...256 {
        try transfer(sequence, total: 2, at: Double(sequence) * 21)
    }
    try transfer(257, total: 1, at: 257 * 21)
    #expect(dispatches == 2)
    #expect(throws: (any Error).self) { try transfer(1, total: 1, at: 258 * 21) }
    #expect(throws: (any Error).self) { try transfer(256, total: 2, at: 258 * 21) }
    #expect(throws: (any Error).self) { try transfer(257, total: 1, at: 258 * 21) }
    #expect(dispatches == 2)
}

@Test @MainActor func watchVoiceTwoSendAttemptsForOneRecordingAssembleOnce() throws {
    let assembly = DJConnectWatchVoiceAssembly()
    assembly.bind(owner: "same-watch-owner")
    let recording = DJConnectWatchVoiceOperation(sequence: 1)
    let payload = DJConnectWatchProxyVoicePayload(wavData: watchVoiceWAV(samples: 1),
        conversationContext: .init(sessionID: nil))
    var completions = 0

    func send(_ recording: DJConnectWatchVoiceOperation, sequence: Int) throws {
        let header = try recording.header(for: payload)
        if try assembly.receive(id: recording.id, sequence: sequence, header: header,
                                index: 0, total: 1, bytes: payload.wavData, uptime: 10) != nil {
            completions += 1
        }
    }

    try send(recording, sequence: recording.sequence)
    #expect(throws: (any Error).self) { try send(recording, sequence: recording.sequence) }
    #expect(throws: (any Error).self) { try send(recording, sequence: recording.sequence + 1) }
    #expect(completions == 1)
    let nextRecording = DJConnectWatchVoiceOperation(sequence: 2)
    try send(nextRecording, sequence: nextRecording.sequence)
    #expect(completions == 2)
}

@Test @MainActor func watchVoicePartialReorderedExpiredOwnerAndMalformedAudioNeverDispatch() throws {
    let metadata = DJConnectWatchProxyVoicePayload(wavData: Data(), conversationContext: .init(sessionID: nil), clientMessageID: "1:original")
    let header = try JSONEncoder().encode(metadata), bytes = Data(repeating: 0, count: 100)
    let assembly = DJConnectWatchVoiceAssembly(); assembly.bind(owner: "A")
    #expect(try assembly.receive(id: "1:original", sequence: 1, header: header, index: 0, total: 3, bytes: bytes, uptime: 10) == nil)
    #expect(throws: (any Error).self) { try assembly.receive(id: "1:original", sequence: 1, header: header, index: 2, total: 3, bytes: bytes, uptime: 11) }
    #expect(throws: (any Error).self) { try assembly.receive(id: "1:original", sequence: 1, header: header, index: 1, total: 3, bytes: bytes, uptime: 31) }
    assembly.bind(owner: "B")
    #expect(throws: (any Error).self) { try assembly.receive(id: "1:original", sequence: 1, header: header, index: 1, total: 3, bytes: bytes, uptime: 12) }
    #expect(throws: (any Error).self) { try assembly.receive(id: "1:original", sequence: 1, header: header, index: 0, total: 1, bytes: bytes, uptime: 12) }
    // Failed final validation spent this original stream before any await.
    #expect(throws: (any Error).self) { try assembly.receive(id: "1:original", sequence: 1, header: header, index: 0, total: 1, bytes: watchVoiceWAV(samples: 1), uptime: 13) }
    assembly.bind(owner: nil)
    #expect(throws: (any Error).self) { try assembly.receive(id: "1:original", sequence: 1, header: header, index: 0, total: 1, bytes: bytes, uptime: 14) }
}

@Test func watchMomentOpenConsumesExactPinnedAPIProposalWithoutClaimingLiveAuthority() throws {
    let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/watch-moment-alert-proposal-api-e245258.json")
    let bytes = try Data(contentsOf: path)
    #expect(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() == "236f9a840015463e8d2f6962c7f759bb6bc24999c373ec697a076b9632da982c")
    let proposal = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    #expect(proposal["status"] as? String == "PROPOSED_NOT_ADOPTED_BY_CORE_OR_APPLE")
    let fixture = try #require(proposal["shared_synthetic_fixture"] as? [String: Any])
    let apns = try #require(fixture["expected_apns"] as? [String: Any])
    let body = try #require(apns["body"] as? [String: Any])
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let locator = try DJConnectWatchMomentOpenIntent(notification: body, at: now)
    #expect(locator.sessionID == "example-session" && locator.momentID == "example-moment")
    #expect(!locator.isPending(at: now.addingTimeInterval(61)))
    #expect(throws: (any Error).self) { try DJConnectWatchMomentOpenIntent(notification: body, at: now.addingTimeInterval(61)) }
}
