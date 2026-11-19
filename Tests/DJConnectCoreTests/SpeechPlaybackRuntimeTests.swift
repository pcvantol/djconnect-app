import Foundation
import Testing
@testable import DJConnectCore

@MainActor
private final class SpeechRuntimeClock { var now = Date() }

@MainActor
private final class SpeechRuntimeHarness {
    let runtime: DJConnectSpeechPlaybackRuntime
    let clock = SpeechRuntimeClock()
    var optionsCalls = 0, prepareCalls = 0, audioCalls = 0, plays = 0, stops = 0
    var completions: [@MainActor () -> Void] = []
    var blockedStage: String?
    var continuation: CheckedContinuation<Void, Never>?
    var failure = false
    var preparedOverride: DJConnectSessionSpeech?
    var bytes = Data([1, 2, 3])
    let descriptor: DJConnectSessionSpeech
    var inventory: DJConnectSpeechVoiceOptions
    var text: String { descriptor.segments.map(\.text).joined() }
    var scope: DJConnectSpeechVoiceScope { .init(installationID: "ha", profileID: "profile", sessionID: descriptor.sessionID!, deviceID: "device")! }

    init() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures")
        let fixture = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("session-speech-processor-core-323a3db4.json"))) as! [String: Any]
        let cases = fixture["cases"] as! [String: Any]
        var value = (cases["ha_configured_audio"] as! [String: Any])["session_speech"] as! [String: Any]
        value["expires_at"] = ISO8601DateFormatter().string(from: clock.now.addingTimeInterval(30))
        descriptor = try JSONDecoder().decode(DJConnectSessionSpeech.self, from: JSONSerialization.data(withJSONObject: value))
        let options = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("provider-voice-gender-coreff507c8.http.json"))) as! [String: Any]
        let row = (options["rows"] as! [[String: Any]])[0]
        inventory = try JSONDecoder().decode(DJConnectSpeechVoiceOptions.self, from: JSONSerialization.data(withJSONObject: (row["options"] as! [String: Any])["speech_voice_options"]!))
        let clock = self.clock
        runtime = DJConnectSpeechPlaybackRuntime(now: { clock.now })
        runtime.updateContext(.init(scope: scope, epoch: UUID(), selection: UUID()))
    }

    func wait(_ stage: String) async {
        if blockedStage == stage { await withCheckedContinuation { continuation = $0 } }
    }
    func resume() { let c = continuation; continuation = nil; c?.resume() }
    func services() -> DJConnectSpeechPlaybackRuntime.Services {
        .init(options: { [self] in
            optionsCalls += 1; await wait("options")
            if failure { throw DJConnectError.invalidResponse }
            return inventory
        }, prepare: { [self] original, text, context, options in
            prepareCalls += 1; await wait("prepare"); return preparedOverride ?? descriptor
        }, audio: { [self] _, _ in
            audioCalls += 1; await wait("audio"); return bytes
        }, play: { [self] _, done in plays += 1; completions.append(done) }, stop: { [self] in stops += 1 })
    }
    func listen(text override: String? = nil) -> Bool {
        runtime.listen(descriptor, reference: descriptor.reference, acceptedText: override ?? text, services: services())
    }
    func revised(_ fields: [String: Any]) throws -> DJConnectSessionSpeech {
        var value = try JSONSerialization.jsonObject(with: JSONEncoder().encode(descriptor)) as! [String: Any]
        for (key, replacement) in fields { value[key] = replacement }
        return try JSONDecoder().decode(DJConnectSessionSpeech.self, from: JSONSerialization.data(withJSONObject: value))
    }
    func settle(_ predicate: () -> Bool) async {
        for _ in 0..<1000 {
            if predicate() { return }
            await Task.yield()
        }
        #expect(predicate())
    }
}

@MainActor
struct SpeechPlaybackRuntimeTests {
    @Test func contextAndReadsAloneNeverSynthesize() async throws {
        let h = try SpeechRuntimeHarness()
        h.runtime.updateContext(h.runtime.context)
        await Task.yield()
        #expect(h.optionsCalls == 0 && h.prepareCalls == 0 && h.plays == 0)
        h.runtime.stop()
    }

    @Test func manualListenWorksWhenAutoplayIsNotEligibleAndCompletesOnce() async throws {
        let h = try SpeechRuntimeHarness()
        #expect(!h.descriptor.autoplayEligible)
        #expect(h.listen())
        await h.settle { h.plays == 1 }
        #expect(h.optionsCalls == 1 && h.prepareCalls == 1 && h.audioCalls == 1)
        #expect(h.runtime.state == .playing)
        h.completions[0]()
        #expect(h.runtime.state == .idle && h.stops == 1)
        h.completions[0]()
        #expect(h.stops == 1)
    }

    @Test func stopBeforeTaskStartsPreventsEveryRequest() async throws {
        let h = try SpeechRuntimeHarness()
        #expect(h.listen())
        h.runtime.stop()
        await Task.yield()
        #expect(h.optionsCalls == 0 && h.prepareCalls == 0 && h.plays == 0)
    }

    @Test(arguments: ["options", "prepare", "audio"])
    func stopAtEveryAwaitRejectsLateCompletion(_ stage: String) async throws {
        let h = try SpeechRuntimeHarness(); h.blockedStage = stage
        #expect(h.listen())
        await h.settle { h.continuation != nil }
        h.runtime.stop(); h.resume()
        await Task.yield(); await Task.yield()
        #expect(h.plays == 0 && h.runtime.state == .idle && h.runtime.retryAfter == nil)
        #expect(h.prepareCalls == (stage == "options" ? 0 : 1))
        #expect(h.audioCalls == (stage == "audio" ? 1 : 0))
    }

    @Test(arguments: ["scope", "epoch", "selection", "voice", "background"])
    func changedContextCancelsPendingAudio(_ kind: String) async throws {
        let h = try SpeechRuntimeHarness(); h.blockedStage = "audio"
        #expect(h.listen()); await h.settle { h.continuation != nil }
        let old = try #require(h.runtime.context)
        let scope = kind == "scope" ? DJConnectSpeechVoiceScope(installationID: "other", profileID: "profile", sessionID: "session", deviceID: "device")! : old.scope
        h.runtime.updateContext(kind == "background" ? nil : .init(scope: scope,
            epoch: kind == "epoch" ? UUID() : old.epoch,
            selection: kind == "selection" ? UUID() : old.selection,
            voiceID: kind == "voice" ? "JennyNeural" : nil))
        h.resume(); await Task.yield(); await Task.yield()
        #expect(h.plays == 0 && h.runtime.state == .idle)
    }

    @Test func replacementAndLateCompletionCannotStopCurrentOutput() async throws {
        let h = try SpeechRuntimeHarness()
        #expect(h.listen()); await h.settle { h.plays == 1 }
        #expect(h.listen()); await h.settle { h.plays == 2 }
        #expect(h.stops == 1)
        h.completions[0]()
        #expect(h.runtime.state == .playing && h.stops == 1)
        h.completions[1]()
        #expect(h.runtime.state == .idle && h.stops == 2)
    }

    @Test func differentTextOrMissingContextNeverDispatches() async throws {
        let h = try SpeechRuntimeHarness()
        #expect(!h.listen(text: "Locally invented replacement"))
        h.runtime.updateContext(nil)
        #expect(!h.listen())
        await Task.yield()
        #expect(h.optionsCalls == 0 && h.prepareCalls == 0)
    }

    @Test func withdrawnSelectionNeverFallsBackToConfiguredDefault() async throws {
        let h = try SpeechRuntimeHarness()
        h.runtime.updateContext(.init(scope: h.scope, epoch: UUID(), selection: UUID(), voiceID: "missing-voice"))
        #expect(h.listen()); await h.settle { h.runtime.state == .unavailable }
        #expect(h.prepareCalls == 0 && h.plays == 0 && h.runtime.retryAfter != nil)
        #expect(!h.listen())
        #expect(h.optionsCalls == 1)
    }

    @Test func failedRequestHasNoAutomaticRetry() async throws {
        let h = try SpeechRuntimeHarness(); h.failure = true
        #expect(h.listen()); await h.settle { h.runtime.state == .unavailable }
        #expect(!h.listen())
        await Task.yield()
        #expect(h.optionsCalls == 1 && h.prepareCalls == 0 && h.plays == 0)
        h.runtime.updateContext(nil)
        h.runtime.updateContext(.init(scope: h.scope, epoch: UUID(), selection: UUID()))
        #expect(!h.listen())
        #expect(h.optionsCalls == 1)
        h.clock.now = h.clock.now.addingTimeInterval(61)
        // A retry interval cannot renew the expired original contribution.
        #expect(!h.listen())
    }

    @Test(arguments: ["options", "prepare", "audio"])
    func originalDeadlineStillAppliesAfterEachAwait(_ stage: String) async throws {
        let h = try SpeechRuntimeHarness(); h.blockedStage = stage
        #expect(h.listen()); await h.settle { h.continuation != nil }
        h.clock.now = h.clock.now.addingTimeInterval(40)
        h.resume()
        // A resumed continuation need not finish within two scheduler yields.
        // Observe expiry handling itself before asserting its no-audio result.
        await h.settle { h.runtime.state == .idle }
        #expect(h.plays == 0 && h.runtime.state == .idle)
    }

    @Test(arguments: ["text_revision", "presentation_revision", "persona", "session_id", "expires_at"])
    func prepareCannotReplaceOriginalIdentityOrExtendDeadline(_ field: String) async throws {
        let h = try SpeechRuntimeHarness()
        h.preparedOverride = try h.revised([field: field == "expires_at" ? ISO8601DateFormatter().string(from: h.clock.now.addingTimeInterval(60)) : "replacement"])
        #expect(h.listen()); await h.settle { h.runtime.state != .preparing }
        #expect(h.audioCalls == 0 && h.plays == 0)
    }

    @Test(arguments: [0, 2 * 1024 * 1024 + 1])
    func invalidByteBoundsNeverReachOutput(_ count: Int) async throws {
        let h = try SpeechRuntimeHarness(); h.bytes = Data(repeating: 0, count: count)
        #expect(h.listen()); await h.settle { h.runtime.state == .unavailable }
        #expect(h.plays == 0)
    }

    @Test func everyExplicitListenRefreshesInventory() async throws {
        let h = try SpeechRuntimeHarness()
        #expect(h.listen()); await h.settle { h.plays == 1 }
        h.runtime.stop()
        #expect(h.listen()); await h.settle { h.plays == 2 }
        #expect(h.optionsCalls == 2 && h.prepareCalls == 2)
        h.runtime.stop()
    }
}
