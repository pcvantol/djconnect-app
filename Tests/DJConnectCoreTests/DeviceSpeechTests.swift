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
        #expect(DJConnectDeviceSpeechRouting.serverTarget(for: .local, nativeOverride: true, settings: speaker) == nil)
        #expect(DJConnectDeviceSpeechRouting.serverTarget(for: .both, nativeOverride: false, settings: speaker) == .both)
    }
    for target: DJConnectSharedSpeechTarget in [.local, .haSpeaker, .both] {
        for native in [false, true] {
            #expect(DJConnectDeviceSpeechRouting.serverTarget(for: target, nativeOverride: native, settings: textOnly) == nil)
            let routed = DJConnectDeviceSpeechRouting.serverTarget(for: target, nativeOverride: native, settings: allowed)
            if !allowed.allowsSpeech(target) { #expect(routed == nil) }
            else if !native { #expect(routed == target) }
            else { #expect(routed == (target == .local ? nil : .haSpeaker)) }
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
    #expect(payload().audioResponse == .never) // no native + server double synthesis
    model.deviceSpeechPreferences.enabled = false
    #expect(model.localResponseAudioEnabled)
    #expect(payload().audioResponse == .always)
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
