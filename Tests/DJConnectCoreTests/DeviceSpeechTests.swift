import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

@Test func deviceSpeechPreferencesAreOptInBoundedAndInstallationLocal() throws {
    let a = "device-speech-a-" + UUID().uuidString, b = "device-speech-b-" + UUID().uuidString
    let first = UserDefaults(suiteName: a)!, second = UserDefaults(suiteName: b)!
    defer { first.removePersistentDomain(forName: a); second.removePersistentDomain(forName: b) }
    #expect(!DJConnectDeviceSpeechPreferences.load(from: first).enabled)
    var preferences = DJConnectDeviceSpeechPreferences(); preferences.enabled = true
    preferences.voiceID = "actual-os-voice-selection"; preferences.gender = .female; preferences.pitch = 1.2; preferences.rate = 0.4
    preferences.save(to: first)
    #expect(DJConnectDeviceSpeechPreferences.load(from: first) == preferences)
    #expect(!DJConnectDeviceSpeechPreferences.load(from: second).enabled)
    #expect(first.object(forKey: "DJConnectLocalResponseAudioEnabled") == nil) // never enables autoplay
    for invalid in [-Double.infinity, Double.nan, -0.1, 1.1] {
        var bad = preferences; bad.rate = invalid
        #expect(!bad.isValid); bad.save(to: first)
        #expect(DJConnectDeviceSpeechPreferences.load(from: first) == preferences)
    }
    first.set(Data("corrupt".utf8), forKey: DJConnectDeviceSpeechPreferences.storageKey)
    #expect(!DJConnectDeviceSpeechPreferences.load(from: first).enabled)
}

@Test func localSpeechRoutingPreservesHAAndNeverBypassesSettings3() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/profile-settings3-core-1329ad1.json")
    let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root)) as? [String: Any])
    let rows = try #require(object["cases"] as? [[String: Any]])
    func settings(_ name: String) throws -> DJConnectProfileDJSettingsResponse {
        let value = try #require(rows.first { $0["case"] as? String == name }?["response"])
        return try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self, from: JSONSerialization.data(withJSONObject: value))
    }
    let allowed = try settings("paired_no_session_all_five")
    let textOnly = try settings("text_only_zero_synthesis_old_audio_denied_and_owner_controls_removed")
    // Existing output enum matrix, not a new speech-grant format.
    for output in [DJAnnouncementOutput.haSpeaker, .both] {
        var raw = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(allowed)) as? [String: Any])
        var snapshot = try #require(raw["snapshot"] as? [String: Any])
        var defaults = try #require(snapshot["defaults"] as? [String: Any])
        defaults["announcement_output"] = output.rawValue; snapshot["defaults"] = defaults; raw["snapshot"] = snapshot
        let speaker = try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self, from: JSONSerialization.data(withJSONObject: raw))
        #expect(speaker.isValid)
        #expect(DJConnectDeviceSpeechRouting.serverTarget(for: .both, nativeOverride: true, settings: speaker) == .haSpeaker)
        #expect(DJConnectDeviceSpeechRouting.serverTarget(for: .haSpeaker, nativeOverride: true, settings: speaker) == .haSpeaker)
        #expect(DJConnectDeviceSpeechRouting.serverTarget(for: .local, nativeOverride: true, settings: speaker) == .local)
        #expect(DJConnectDeviceSpeechRouting.serverTarget(for: .both, nativeOverride: false, settings: speaker) == .both)
    }
    for target: DJConnectSharedSpeechTarget in [.local, .haSpeaker, .both] {
        for native in [false, true] {
            #expect(DJConnectDeviceSpeechRouting.serverTarget(for: target, nativeOverride: native, settings: textOnly) == nil)
            let routed = DJConnectDeviceSpeechRouting.serverTarget(for: target, nativeOverride: native, settings: allowed)
            if !allowed.allowsSpeech(target) { #expect(routed == nil) }
            else if !native { #expect(routed == target) }
            else { #expect(routed == (target == .local ? .local : .haSpeaker)) }
        }
    }
}

#if canImport(AVFoundation)
@Test @MainActor func deviceVoiceSelectionUsesRealInventoryAndNeverReplacesMissingExplicitVoice() {
    var preferences = DJConnectDeviceSpeechPreferences(); preferences.enabled = true
    let voices = DJConnectAppleSpeechRenderer.voices()
    #expect(Set(voices.map(\.id)).count == voices.count)
    preferences.voiceID = "missing-voice-" + UUID().uuidString
    #expect(DJConnectAppleSpeechRenderer.selectedVoice(locale: "nl", preferences: preferences) == nil)
    let renderer = DJConnectAppleSpeechRenderer()
    #expect(!renderer.speak("fixture", locale: "nl", preferences: preferences, completion: {}))
    #expect(!renderer.isSpeaking)
    renderer.stop()
}
#endif

@Test @MainActor func deviceSpeechOverrideDoesNotEnableAutoplayOrRequestServerSynthesis() async throws {
    let suite = "native-override-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    #expect(!model.deviceSpeechPreferences.enabled && !model.localResponseAudioEnabled)
    #expect(!model.canPreviewDeviceSpeech)
    model.deviceSpeechPreferences.enabled = true
    #expect(!model.localResponseAudioEnabled)
    model.previewDeviceSpeech() // unknown output policy: zero synthesis
    #expect(!model.deviceSpeechPreviewIsPlaying)
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/profile-settings3-core-1329ad1.json")
    let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root)) as? [String: Any])
    let cases = try #require(object["cases"] as? [[String: Any]])
    func snapshot(_ name: String) throws -> DJConnectProfileDJSettingsResponse {
        let value = try #require(cases.first { $0["case"] as? String == name }?["response"])
        return try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self, from: JSONSerialization.data(withJSONObject: value))
    }
    model.profileDJSettings.bind(owner: "native-preview-test", active: true)
    var current = try snapshot("paired_no_session_all_five")
    await model.profileDJSettings.refresh(.init(read: { current }, update: { _, _, _ in throw CancellationError() }, receipt: { _, _ in throw CancellationError() }))
    #expect(model.canPreviewDeviceSpeech)
    model.previewDeviceSpeech()
    #expect(model.deviceSpeechPreviewIsPlaying)
    model.stopDeviceSpeechPreview() // cancel before the queued activation starts
    #expect(!model.deviceSpeechPreviewIsPlaying)
    for _ in 0..<3 { await Task.yield() }
    #expect(!model.deviceSpeechPreviewIsPlaying)
    model.localResponseAudioEnabled = true
    func payload() -> DJConnectAskDJRequest { model.profileConversationPayload(text: "test", clientMessageID: UUID().uuidString, context: .init(sessionID: nil)) }
    #expect(payload().audioResponse == .always) // contract3 defers output; prepare selects exactly one processor
    #expect(payload().speechContractVersion == 3)
    model.deviceSpeechPreferences.enabled = false
    #expect(model.localResponseAudioEnabled)
    #expect(payload().audioResponse == .always)
    #expect(payload().speechContractVersion == 3) // deferred autoplay intent, never inline synthesis
    #expect(!model.canUseHASpeechOutput(.local)) // real prepare still needs fresh discovery
    var unavailable = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any])
    unavailable["voice_availability"] = ["available": false, "reason": "voice_unavailable"]
    current = try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self, from: JSONSerialization.data(withJSONObject: unavailable))
    await model.profileDJSettings.refresh(.init(read: { current }, update: { _, _, _ in throw CancellationError() }, receipt: { _, _ in throw CancellationError() }))
    #expect(!model.sharedDJSpeechAllowed && payload().audioResponse == .never)
    model.deviceSpeechPreferences.enabled = true
    #expect(model.sharedDJSpeechAllowed && model.canUseLocalDJSpeechOutput)
    #expect(payload().audioResponse == .always) // native grant does not need an HA provider voice
    #expect(!model.canUseHASpeechOutput(.local)) // no HA configuration admission is fabricated
    model.deviceSpeechPreferences.voiceID = "removed-apple-voice"
    #expect(!model.canUseLocalDJSpeechOutput && !model.sharedDJSpeechAllowed)
    #expect(payload().audioResponse == .never)
    model.deviceSpeechPreferences.voiceID = nil
    #expect(model.canUseLocalDJSpeechOutput && model.sharedDJSpeechAllowed)
    current = try snapshot("text_only_zero_synthesis_old_audio_denied_and_owner_controls_removed")
    await model.profileDJSettings.refresh(.init(read: { current }, update: { _, _, _ in throw CancellationError() }, receipt: { _, _ in throw CancellationError() }))
    model.deviceSpeechPreferences.enabled = true
    #expect(!model.canPreviewDeviceSpeech)
    model.previewDeviceSpeech()
    #expect(!model.deviceSpeechPreviewIsPlaying && payload().audioResponse == .never)
    model.profileDJSettings.withdrawAuthority()
    #expect(!model.canPreviewDeviceSpeech)
    #expect(DJConnectDeviceSpeechPreferences.load(from: defaults).enabled)
}

@Test @MainActor func deviceSTTPreferenceIsLocalOptInAndCancelsCurrentCapture() throws {
    let firstName = "device-stt-" + UUID().uuidString, secondName = "device-stt-" + UUID().uuidString
    let first = try #require(UserDefaults(suiteName: firstName)), second = try #require(UserDefaults(suiteName: secondName))
    defer { first.removePersistentDomain(forName: firstName); second.removePersistentDomain(forName: secondName) }
    let model = DJConnectAppModel(defaults: first, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    #expect(!model.deviceSTTEnabled)
    let operation = model.voiceOperationID
    model.deviceSTTEnabled = true
    #expect(model.voiceOperationID != operation)
    #expect(first.bool(forKey: "DJConnectDeviceSTTEnabled.v1"))
    let restored = DJConnectAppModel(defaults: first, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    let other = DJConnectAppModel(defaults: second, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    #expect(restored.deviceSTTEnabled && !other.deviceSTTEnabled)
    #expect(!model.deviceSpeechPreferences.enabled && !model.localResponseAudioEnabled)
}

private func availabilityCases() throws -> [[String: Any]] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/device-speech-core-604b80f8.json")
    let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    return try #require(root["cases"] as? [[String: Any]])
}
private func availability(_ json: [String: Any]) throws -> DJConnectDeviceSpeechAvailability {
    try JSONDecoder().decode(DJConnectDeviceSpeechAvailability.self, from: JSONSerialization.data(withJSONObject: json))
}

@Test func deviceSpeechUsesOriginalProducerCasesAndIndependentRoutes() throws {
    let cases = try availabilityCases()
    #expect(cases.count == 15)
    for item in cases {
        guard let json = item["snapshot"] as? [String: Any] else { continue }
        let value = try availability(json)
        let stt = try #require(json["ha_stt"] as? [String: Any])
        let tts = try #require(json["ha_tts"] as? [String: Any])
        let speaker = try #require(json["ha_speaker_target"] as? [String: Any])
        #expect(value.allowsHAInput(locale: value.locale ?? "en") == (stt["available"] as? Bool == true))
        let retry = (tts["operational"] as? [String: Any])?["retry_after_seconds"] as? Int ?? 0
        #expect(value.allowsHAOutput(.local, locale: value.locale ?? "en") == (tts["available"] as? Bool == true && retry <= 0))
        #expect(value.allowsHAOutput(.haSpeaker, locale: value.locale ?? "en") == (tts["available"] as? Bool == true && retry <= 0 && speaker["available"] as? Bool == true))
        #expect(!value.allowsHAInput(locale: "und"))
    }
}

@Test func deviceSpeechRejectsFutureVersionsStatesAndContradictoryAvailability() throws {
    let original = try #require(availabilityCases().first?["snapshot"] as? [String: Any])
    for version in [0, 2, 999] {
        var json = original; json["schema_version"] = version
        let value = try availability(json)
        #expect(!value.allowsHAOutput(.local, locale: value.locale ?? "en"))
        #expect(!value.allowsHAInput(locale: value.locale ?? "en"))
    }
    for state in ["unknown", "unsupported", "unavailable", "unconfigured", "future"] {
        var json = original
        var route = try #require(json["ha_tts"] as? [String: Any])
        route["state"] = state; route["available"] = true; route["configured"] = true
        json["ha_tts"] = route
        let value = try availability(json)
        #expect(!value.allowsHAOutput(.local, locale: value.locale ?? "en"))
    }
}

@Test func deviceSpeechLegacySupportFlagsCannotQualifyRoutes() throws {
    let decoder = JSONDecoder()
    let absent = try decoder.decode(DJConnectEnvelope<DJConnectPlayback>.self,
        from: Data(#"{"success":true,"voice_supported":true,"ask_dj_voice_supported":true}"#.utf8))
    #expect(absent.deviceSpeech == nil)
    var body: [String: Any] = ["success": true, "device_speech": try #require(availabilityCases().first?["snapshot"])]
    let present = try decoder.decode(DJConnectEnvelope<DJConnectPlayback>.self, from: JSONSerialization.data(withJSONObject: body))
    #expect(present.deviceSpeech?.ha_tts.isAvailable == true)
    body["device_speech"] = nil
    let pair = try decoder.decode(DJConnectPairingResponse.self, from: JSONSerialization.data(withJSONObject: body))
    #expect(pair.deviceSpeech == nil)
}

@Test func deviceSpeechMatchesProducerLocaleFamilyWithoutBorrowingAnotherLanguage() throws {
    let original = try #require(availabilityCases().first?["snapshot"] as? [String: Any])
    let value = try availability(original)
    #expect(value.qualifies(locale: "en-US"))
    #expect(value.qualifies(locale: "en_GB"))
    #expect(!value.qualifies(locale: "nl-NL"))
    #expect(!value.qualifies(locale: ""))
    #expect(!value.qualifies(locale: "-en"))
}

@Test func deviceSpeechMalformedDiscoveryDoesNotBreakOrdinaryStatus() throws {
    for value: Any in ["future", ["schema_version": 2], ["schema_version": 1, "ha_stt": "changed"]] {
        let body: [String: Any] = ["success": true, "device_speech": value, "ha_install_id": "same"]
        let status = try JSONDecoder().decode(DJConnectEnvelope<DJConnectPlayback>.self,
            from: JSONSerialization.data(withJSONObject: body))
        #expect(status.success && status.haInstallID == "same")
        #expect(status.deviceSpeech == nil)
    }
}

@Test func deviceSpeechRequiresKnownOperationalEvidenceAndRetriesExpiredFailure() throws {
    let original = try #require(availabilityCases().first?["snapshot"] as? [String: Any])
    var route = try #require(original["ha_tts"] as? [String: Any])
    route["operational"] = nil
    var missing = original; missing["ha_tts"] = route
    let unavailable = try availability(missing)
    #expect(unavailable.ha_tts.isAvailable) // configuration remains independently valid
    #expect(!unavailable.allowsHAOutput(.local, locale: "en-US"))
    for state in ["not_tested", "succeeded", "failed", "unknown", "future"] {
        for retry in [-1, 0, 1, 60] {
            route["operational"] = ["synthesis_state": state, "retry_after_seconds": retry]
            var json = original; json["ha_tts"] = route
            let value = try availability(json)
            #expect(value.ha_tts.isAvailable)
            #expect(value.allowsHAOutput(.local, locale: "en-US") == (["not_tested", "succeeded", "failed"].contains(state) && retry == 0))
        }
    }
}

@Test func deviceSpeechRequiresCompatibleCaptureAndCurrentRouteMetadata() throws {
    let item = try #require(availabilityCases().first { $0["case"] as? String == "configuration_stt_True_tts_True" })
    let original = try #require(item["snapshot"] as? [String: Any])
    for key in ["audio", "locale"] {
        var json = original; var stt = try #require(json["ha_stt"] as? [String: Any]); stt[key] = nil; json["ha_stt"] = stt
        #expect(!(try availability(json)).allowsHAInput(locale: "en-US"))
    }
    for key in ["operational", "locale", "configuration_revision"] {
        var json = original; var tts = try #require(json["ha_tts"] as? [String: Any]); tts[key] = nil; json["ha_tts"] = tts
        #expect(!(try availability(json)).allowsHAOutput(.local, locale: "en-US"))
    }
    var json = original; var stt = try #require(json["ha_stt"] as? [String: Any])
    var audio = try #require(stt["audio"] as? [String: Any]); audio["sample_rate"] = 48000
    stt["audio"] = audio; json["ha_stt"] = stt
    #expect(!(try availability(json)).allowsHAInput(locale: "en-US"))
    #expect((try availability(json)).allowsHAOutput(.local, locale: "en-US"))
}
