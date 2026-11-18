import Foundation
import CryptoKit
import Testing
@testable import DJConnectCore

func nativeWatchFixtureCases() throws -> [String: Any] {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures")
    let bytes = try Data(contentsOf: root.appendingPathComponent("session-speech-local-settings-core-bc6e080e.json"))
    #expect(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() == "813182572537911fe519e487c434b4a5b78a905b19d8d49bb097dfb8715a756b")
    return try #require((JSONSerialization.jsonObject(with: bytes) as? [String: Any])?["cases"] as? [String: Any])
}
func nativeWatchSettings(_ speech: DJConnectSessionSpeech, output: DJAnnouncementOutput = .clientDevice) throws -> DJConnectProfileDJSettingsResponse {
    let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/profile-settings3-core-1329ad1.json")
    let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
    let cases = try #require(root["cases"] as? [[String: Any]])
    var raw = try #require(cases.first { $0["case"] as? String == "paired_no_session_all_five" }?["response"] as? [String: Any])
    var snapshot = try #require(raw["snapshot"] as? [String: Any])
    var defaults = try #require(snapshot["defaults"] as? [String: Any])
    defaults["announcement_output"] = output.rawValue; defaults["mood"] = "groove"
    let fence = try #require(speech.settingsRevision)
    let revision = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(fence)) as? [Any])
    snapshot["defaults"] = defaults; snapshot["defaults_revision"] = revision[0]
    if let session = revision[1] as? [Any] {
        snapshot["session"] = ["session_id": session[0], "generation": session[1], "revision": session[2],
            "defaults_revision": revision[0], "settings": defaults, "selection_required": false]
    } else { snapshot["session"] = NSNull() }
    raw["snapshot"] = snapshot
    return try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self, from: JSONSerialization.data(withJSONObject: raw))
}
func nativeWatchSpeechFixture(expiresIn: TimeInterval = 60) throws -> (DJConnectSharedSpeechResult, DJConnectWatchMomentSpeechRequest, DJConnectWatchSessionSnapshot) {
    let cases = try nativeWatchFixtureCases()
    var response = try #require((cases["live_and_retained"] as? [[String: Any]])?.first?["response"] as? [String: Any])
    var raw = try #require(response["session_speech"] as? [String: Any])
    let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    // Modeled runtime race context only; immutable actual producer fixtures above
    // are separately tested at their original dates, never presented as live grants.
    let expiry = formatter.string(from: Date().addingTimeInterval(expiresIn))
    raw["expires_at"] = expiry; raw["source_expires_at"] = expiry; response["session_speech"] = raw
    let result = try JSONDecoder().decode(DJConnectSharedSpeechResult.self, from: JSONSerialization.data(withJSONObject: response))
    let speech = result.session_speech, settings = try nativeWatchSettings(speech)
    let sessionID = try #require(speech.sessionID)
    let momentObject: [String: Any] = ["moment_id": speech.sourceID!, "session_id": sessionID,
        "created_at": formatter.string(from: Date()), "type": "artist", "title": "DJ", "summary": "",
        "content": speech.segments.map(\.text).joined(), "presentation_intent": ["visibility": "owner_only"],
        "source_attribution": speech.attribution!.first!, "source_references": [], "actions": []]
    let moment = try JSONDecoder().decode(DJConnectMoment.self, from: JSONSerialization.data(withJSONObject: momentObject))
    var broadcast = DJConnectBroadcastState(session: .init(sessionID: sessionID, runtimeState: "active", selectedMood: "groove"),
        planner: .init(planningState: "ready", planningHorizonMinutes: 5, currentDirection: ""),
        sessionFlow: .init(flowID: "fixture-flow", planningHorizonMinutes: 5, createdAt: moment.createdAt,
            items: [.init(itemID: "row", itemType: "dj_moment", position: "now", label: "DJ", momentID: moment.id)]))
    broadcast.djMoments = [moment]; broadcast.sessionSpeech = [speech]
    let authority: [String: Any] = ["schema_version": 1, "session_id": sessionID, "revision": "fixture",
        "current_moment_id": NSNull(), "active_flow_moment_ids": [moment.id], "revocation_scope": "session",
        "admissions": [["moment_id": moment.id, "qualification": "qualified", "current_display_allowed": false,
            "active_flow_display_allowed": true, "source_expires_at": expiry, "display_expires_at": NSNull(),
            "executable_actions": [], "requires_spotify_attribution": false]]]
    broadcast.nativeDelivery = try JSONDecoder().decode(DJConnectNativeMomentDelivery.self, from: JSONSerialization.data(withJSONObject: authority))
    let runtime = DJConnectSessionRuntime(sessionID: sessionID, room: "fixture", selectedMood: "groove",
        selectedPresence: settings.snapshot.effective.presence, selectedPersona: settings.snapshot.effective.persona,
        musicBackend: "fixture", runtimeState: "active", startedAt: moment.createdAt,
        planner: .init(planningHorizonMinutes: 5), broadcast: broadcast)
    let snapshot = DJConnectWatchSessionSnapshot(settings: settings, session: runtime)
    let source = try #require(snapshot.speechSources.first)
    return (result, .init(settings: settings, moment: moment, source: source), snapshot)
}

@Test(.isolatedClientResources) func frozenNativeSettingsSpeechPreservesAllActualProducerGrantsAndOutputDenials() throws {
    let cases = try nativeWatchFixtureCases()
    let rows = try #require(cases["output_intent_target_matrix"] as? [[String: Any]])
    #expect(rows.count == 24)
    for row in rows where row["status"] as? Int == 200 {
        let value = try #require(row["response"] as? [String: Any])
        let response = try JSONDecoder().decode(DJConnectSharedSpeechResult.self, from: JSONSerialization.data(withJSONObject: value))
        let speech = response.session_speech
        let request = try #require(row["request"] as? [String: Any])
        let allowed = request["target"] as? String == "local" && row["output"] as? String != "text_only" &&
            !(row["output"] as? String == "ha_speaker" && request["intent"] as? String == "automatic")
        #expect((speech.state == "available") == allowed)
        if !allowed {
            #expect(!speech.manualAllowed && !speech.autoplayEligible && speech.segments.isEmpty && speech.audioReference == nil)
            continue
        }
        let settings = try nativeWatchSettings(speech, output: DJAnnouncementOutput(rawValue: row["output"] as! String)!)
        let at = try #require(speech.expiresAt.flatMap(DJConnectHistoryEntry.date)).addingTimeInterval(-1)
        #expect(DJConnectNativeSpeechAdmission.admits(speech, reference: speech.reference, text: speech.segments.map(\.text).joined(), settings: settings, at: at))
        #expect(!speech.autoplayEligible) // prepare is NOT a new publication
        #expect(speech.effectiveVoice == nil && speech.audioReference == nil)
    }
    for name in ["live_and_retained", "unavailable_ha_voice"] {
        let entries = (cases[name] as? [[String: Any]]) ?? [cases[name] as! [String: Any]]
        for entry in entries {
            let result = try JSONDecoder().decode(DJConnectSharedSpeechResult.self, from: JSONSerialization.data(withJSONObject: entry["response"]!))
            let speech = result.session_speech
            let at = try #require(speech.expiresAt.flatMap(DJConnectHistoryEntry.date)).addingTimeInterval(-1)
            #expect(DJConnectNativeSpeechAdmission.admits(speech, reference: speech.reference, text: speech.segments.map(\.text).joined(), settings: try nativeWatchSettings(speech), at: at))
        }
    }
}

@Test(.isolatedClientResources) func nativeGrantRejectsAssetsWrongProcessorSettingsTextAndExpiredOrWithdrawnSource() throws {
    let (result, request, _) = try nativeWatchSpeechFixture()
    let original = result.session_speech
    let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
    let badFields: [(String, Any)] = [("processor", "ha_configured"), ("processor", NSNull()),
        ("audio_state", "ready"), ("audio_reference", ["asset_id": "forbidden", "path": "/api/djconnect/v1/speech/audio", "method": "POST"]), ("processor_qualification_required", false), ("settings_revision", []),
        ("voice_preference", "default"), ("state", "withdrawn"), ("expires_at", "2020-01-01T00:00:00Z"),
        ("effective_voice", ["processor":"ha_configured","engine":"ha","provider":"ha","locale":"en","voice_selection":"provider_default"])]
    for (field, value) in badFields {
        var raw = encoded; raw[field] = value
        let speech = try JSONDecoder().decode(DJConnectSessionSpeech.self, from: JSONSerialization.data(withJSONObject: raw))
        #expect(!DJConnectNativeSpeechAdmission.admits(speech, reference: request.reference, text: request.moment.content, settings: request.settings))
    }
    #expect(!DJConnectNativeSpeechAdmission.admits(original, reference: request.reference, text: request.moment.content + "!", settings: request.settings))
    #expect(!DJConnectNativeSpeechAdmission.admits(original, reference: request.reference, text: request.moment.content, settings: try nativeWatchSettings(original, output: .textOnly)))
}

@Test(.isolatedClientResources) func watchSpeechBridgeContainsOnlyVisibleOriginalRevisionsAndRejectsSourceWithdrawal() throws {
    let (_, request, snapshot) = try nativeWatchSpeechFixture()
    #expect(snapshot.isValid && request.matches(snapshot))
    let bytes = try JSONEncoder().encode(snapshot)
    #expect(bytes.count < 42_000)
    let decoded = try JSONDecoder().decode(DJConnectWatchSessionSnapshot.self, from: bytes)
    #expect(request.matches(decoded))
    #expect(decoded.session?.broadcast.sessionSpeech.isEmpty == true)
    let json = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    let sources = try #require(json["speech_sources"] as? [[String: Any]])
    #expect(sources.allSatisfy { $0["segments"] == nil && $0["audio_reference"] == nil })
    var runtime = try #require(snapshot.session); runtime.broadcast.clearNativeAuthority()
    #expect(!request.matches(.init(settings: snapshot.settings, session: runtime)))
    runtime = try #require(snapshot.session); runtime.broadcast.djMoments[0].content += "changed"
    #expect(!request.matches(.init(settings: snapshot.settings, session: runtime)))
    var raw = json; raw["speech_sources"] = []
    #expect(!request.matches(try JSONDecoder().decode(DJConnectWatchSessionSnapshot.self, from: JSONSerialization.data(withJSONObject: raw))))
    raw.removeValue(forKey: "speech_sources") // older companion still renders cards, never speaks
    let old = try JSONDecoder().decode(DJConnectWatchSessionSnapshot.self, from: JSONSerialization.data(withJSONObject: raw))
    #expect(old.isValid && old.speechSources.isEmpty && !request.matches(old))
}

@MainActor private final class WatchSpeechOwner { var current = true }

@MainActor private func watchEventually(_ predicate: () -> Bool) async -> Bool {
    for _ in 0..<100 { if predicate() { return true }; try? await Task.sleep(for: .milliseconds(10)) }
    return false
}

@Test(.isolatedClientResources) @MainActor func watchNativeSpeechNeverStartsAfterStopOrOwnerLossAndLateCompletionCannotStopReplacement() async throws {
    let (result, request, _) = try nativeWatchSpeechFixture()
    var stops = 0, starts = 0, prepares = 0
    let player = DJConnectWatchSessionSpeech { stops += 1 }
    var preferences = DJConnectDeviceSpeechPreferences()
    player.play(request, preferences: preferences, prepare: { prepares += 1; return result }, isCurrent: { true }, start: { _, _ in starts += 1; return true })
    #expect(prepares == 0 && starts == 0)
    preferences.enabled = true
    var pending: CheckedContinuation<DJConnectSharedSpeechResult, any Error>?
    player.play(request, preferences: preferences, prepare: { try await withCheckedThrowingContinuation { pending = $0 } }, isCurrent: { true }, start: { _, _ in starts += 1; return true })
    #expect(await watchEventually { pending != nil })
    player.stop(); pending?.resume(returning: result)
    for _ in 0..<5 { await Task.yield() }
    #expect(starts == 0 && player.state == .idle)
    let owner = WatchSpeechOwner(); var finishes: [() -> Void] = []
    for _ in 0..<2 {
        player.play(request, preferences: preferences, prepare: { result }, isCurrent: { owner.current }, start: { _, done in starts += 1; finishes.append(done); return true })
        #expect(await watchEventually { player.state == .playing })
    }
    #expect(starts == 2 && finishes.count == 2)
    finishes[0]()
    #expect(player.state == .playing)
    owner.current = false
    #expect(await watchEventually { player.state == .idle })
    #expect(stops > 0)
}

@Test(.isolatedClientResources) @MainActor func watchNativeSpeechFailureRemainsClearAndDoesNotSubstituteVisibleText() async throws {
    let (_, request, _) = try nativeWatchSpeechFixture()
    var preferences = DJConnectDeviceSpeechPreferences(); preferences.enabled = true
    let player = DJConnectWatchSessionSpeech(stopOutput: {})
    var starts = 0
    player.play(request, preferences: preferences, prepare: { throw DJConnectError.invalidResponse }, isCurrent: { true }, start: { _, _ in starts += 1; return true })
    #expect(await watchEventually { player.state == .unavailable })
    #expect(player.momentID == request.moment.id && starts == 0)
    player.stop()
    #expect(player.state == .idle && player.momentID == nil)
}

@Test(.isolatedClientResources) @MainActor func watchNativeSpeechExpiresWithoutRenewalAndRejectsRevisedPrepare() async throws {
    let (result, request, snapshot) = try nativeWatchSpeechFixture(expiresIn: 0.4)
    var preferences = DJConnectDeviceSpeechPreferences(); preferences.enabled = true
    var starts = 0
    let player = DJConnectWatchSessionSpeech(stopOutput: {})
    player.play(request, preferences: preferences, prepare: { result }, isCurrent: { request.matches(snapshot) },
        start: { _, _ in starts += 1; return true })
    #expect(await watchEventually { player.state == .playing })
    #expect(await watchEventually { player.state == .idle })
    #expect(starts == 1 && !request.matches(snapshot))
    let (fresh, intent, _) = try nativeWatchSpeechFixture()
    var raw = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(fresh)) as? [String: Any])
    var speech = try #require(raw["session_speech"] as? [String: Any])
    speech["presentation_revision"] = "replacement-revision"; raw["session_speech"] = speech
    let replacement = try JSONDecoder().decode(DJConnectSharedSpeechResult.self, from: JSONSerialization.data(withJSONObject: raw))
    player.play(intent, preferences: preferences, prepare: { replacement }, isCurrent: { true },
        start: { _, _ in starts += 1; return true })
    #expect(await watchEventually { player.state == .unavailable })
    #expect(starts == 1)
}
