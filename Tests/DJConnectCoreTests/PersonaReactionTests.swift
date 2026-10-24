import Foundation
import Testing
import SwiftUI
@testable import DJConnectCore
@testable import DJConnectUI
#if os(macOS)
import AppKit
#endif

private func touchJSON(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value) }
private func touchFixture(_ name: String) throws -> [String: Any] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/" + name)
    return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
}
private func touchCase(native: Bool = true, output: DJAnnouncementOutput = .clientDevice, now: Date = Date(),
                       mutate: (inout [String: Any]) -> Void = { _ in }) throws -> (DJConnectPersonaReactionRequest, DJConnectProfileDJSettingsResponse, DJConnectPersonaReactionResult) {
    let cases = try #require(touchFixture("persona-touch-core-37a574c9.json")["transport_receipts"] as? [[String: Any]])
    var body = try #require(cases[native ? 0 : 5]["body"] as? [String: Any])
    var reaction = try #require(body["persona_reaction"] as? [String: Any])
    let context = try #require(reaction["session"] as? [String: Any])
    let root = try touchFixture("profile-settings3-core-1329ad1.json")
    let settingsCases = try #require(root["cases"] as? [[String: Any]])
    var raw = try #require(settingsCases.first { $0["case"] as? String == "active_atomic_all_five_and_replay" }?["response"] as? [String: Any])
    var snapshot = try #require(raw["snapshot"] as? [String: Any])
    var chosen = try #require(snapshot["defaults"] as? [String: Any])
    chosen["persona"] = reaction["persona"]; chosen["mood"] = reaction["mood"]; chosen["voice"] = ["kind": "provider_default"]
    chosen["announcement_output"] = output.rawValue
    snapshot["defaults"] = chosen; snapshot["defaults_revision"] = 1
    var session = context; session["settings"] = chosen; session["defaults_revision"] = 1
    snapshot["session"] = session; raw["snapshot"] = snapshot
    var allowed = try #require(raw["allowed_values"] as? [String: Any])
    allowed["presence"] = ["music_only", "occasional", "balanced", "presenter"]; raw["allowed_values"] = allowed
    let settings = try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self, from: touchJSON(raw))
    #expect(settings.isValid)
    let request = try DJConnectPersonaReactionRequest(settings: settings, kind: .playful, language: "en", processor: native ? .localOnDevice : .haConfigured)
    let expiry = ISO8601DateFormatter().string(from: now.addingTimeInterval(20))
    reaction["expires_at"] = expiry
    var speech = try #require(reaction["speech"] as? [String: Any]); speech["expires_at"] = expiry
    reaction["speech"] = speech
    // Only temporal admission is rebased in this synthetic derivative. The
    // immutable imported producer text/context/descriptors are unchanged.
    mutate(&reaction); body["persona_reaction"] = reaction
    var receipt = try #require(body["operation_receipt"] as? [String: Any])
    receipt["expires_at_ms"] = Int(now.addingTimeInterval(300).timeIntervalSince1970 * 1000); body["operation_receipt"] = receipt
    return (request, settings, try JSONDecoder().decode(DJConnectPersonaReactionResult.self, from: touchJSON(body)))
}

@Test(arguments: [true, false]) func personaTouchAdmitsExactProducerReactionWithoutInventingAChatTurn(native: Bool) throws {
    let now = Date()
    let (request, settings, result) = try touchCase(native: native, now: now)
    #expect(result.persona_reaction.admits(request: request, settings: settings, receipt: result.operation_receipt, started: now, at: now))
    #expect(result.persona_reaction.admitsSpeech(request: request, settings: settings, at: now))
    let body = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
    #expect(Set(body.keys) == ["contract_version", "session", "kind", "language", "processor"])
    #expect(Set((body["session"] as? [String: Any] ?? [:]).keys) == ["session_id", "generation", "revision"])
    #expect(!result.persona_reaction.history_publication)
    #expect((try? JSONDecoder().decode(DJConnectSpeechReference.self, from: touchJSON(["reaction_id": result.persona_reaction.id, "session_id": request.session.session_id]))) == nil)
}

@Test(arguments: ["session", "generation", "revision", "kind", "locale", "persona", "mood", "expiry", "renewal", "history", "cache", "basis", "id"])
func personaTouchRejectsForeignStaleAndRepublishedContent(fault: String) throws {
    let now = Date()
    let (request, settings, result) = try touchCase(now: now) { value in
        switch fault {
        case "session", "generation", "revision":
            var context = value["session"] as! [String: Any]
            context[fault == "session" ? "session_id" : fault] = fault == "revision" ? 99 : "foreign"
            value["session"] = context
        case "kind": value["kind"] = "check_in"
        case "locale": value["locale"] = "nl"
        case "persona": value["persona"] = "home_dj"
        case "mood": value["mood"] = "chill"
        case "expiry": value["expires_at"] = ISO8601DateFormatter().string(from: now.addingTimeInterval(-1))
        case "renewal": value["expires_at"] = ISO8601DateFormatter().string(from: now.addingTimeInterval(31))
        case "history": value["history_publication"] = true
        case "cache": value["cache_policy"] = "public"
        case "basis": value["content_basis"] = "caller_text"
        default: value["reaction_id"] = UUID().uuidString
        }
    }
    #expect(!result.persona_reaction.admits(request: request, settings: settings, receipt: result.operation_receipt, started: now, at: now))
}

@Test(arguments: ["text", "source", "reference", "settings", "processor", "ready", "audio", "deadline"])
func personaTouchNeverSubstitutesSpeechForInvalidOrDifferentEvidence(fault: String) throws {
    let (request, settings, result) = try touchCase { reaction in
        var speech = reaction["speech"] as! [String: Any]
        switch fault {
        case "text": speech["segments"] = [["ordinal": 1, "speaker_role": "dj", "text": "invented text"]]
        case "source": speech["source_kind"] = "accepted_ask_dj"
        case "reference": speech["reference"] = ["reaction_id": "foreign", "session_id": "foreign"]
        case "settings": speech["settings_revision"] = []
        case "processor": speech["processor"] = "ha_configured"
        case "ready": speech["audio_state"] = "ready"
        case "audio": speech["audio_reference"] = ["asset_id": "unexpected", "path": "/api/djconnect/v1/speech/audio", "method": "POST"]
        default: speech["expires_at"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(25))
        }
        reaction["speech"] = speech
    }
    #expect(!result.persona_reaction.admitsSpeech(request: request, settings: settings))
}

@Test(arguments: [DJAnnouncementOutput.textOnly, .haSpeaker, .both])
func personaTouchRespectsOutputWithoutSubstitutingClientAudio(output: DJAnnouncementOutput) throws {
    let (request, settings, result) = try touchCase(output: output)
    #expect(result.persona_reaction.admitsSpeech(request: request, settings: settings) == (output == .both))
}

@MainActor private func touchEventually(_ predicate: () -> Bool) async -> Bool {
    for _ in 0..<100 {
        if predicate() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return predicate()
}

@MainActor private func touchObservation(_ result: DJConnectPersonaReactionResult) async throws -> DJConnectPersonaReactionObservation {
    let observation = DJConnectPersonaReactionObservation(result: result, close: {})
    try observation.accept(touchJSON(["contract_version": 1, "observation_id": 1,
        "reaction_id": result.persona_reaction.id, "session_id": result.persona_reaction.session.session_id,
        "state": "valid", "expires_at": result.persona_reaction.expires_at, "cache_policy": "private,no-store"]), requestID: 1, initial: true)
    return observation
}

@Test @MainActor func personaTouchCancellationBeforeDispatchFencesLateResultAndCancelsOriginalID() async throws {
    let (_, _, result) = try touchCase()
    let controller = PersonaReactionController()
    var continuation: CheckedContinuation<DJConnectPersonaReactionResult, Error>?
    var dispatched: (@Sendable (String) -> Void)?
    var cancels: [(String, DJConnectPersonaReactionCancellation)] = []
    var plays = 0, stops = 0, requests = 0, feedback = 0
    let services = PersonaReactionController.Services(request: { callback in
        requests += 1; dispatched = callback
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }, cancel: { cancels.append(($0, $1)) }, current: { true }, admitsSpeech: { _ in true },
    play: { _, _ in plays += 1; return true }, stop: { _ in stops += 1 }, failure: {}, notice: nil, admittedFeedback: { feedback += 1 })
    controller.start(services)
    #expect(await touchEventually { continuation != nil })
    controller.start(services) // A second gesture cannot create a queue.
    controller.cancel(.background)
    dispatched?(result.persona_reaction.id)
    continuation?.resume(returning: result)
    #expect(await touchEventually { !cancels.isEmpty })
    #expect(requests == 1 && plays == 0 && stops == 1 && feedback == 0)
    #expect(cancels.count == 1 && cancels[0].0 == result.persona_reaction.id && cancels[0].1 == .background)
    #expect(controller.reaction == nil && !controller.preparing && !controller.speaking)
}

@Test @MainActor func personaTouchOnlyActualAudioCallbackSpeaksAndLateCallbacksCannotReviveIt() async throws {
    let (_, _, result) = try touchCase()
    let controller = PersonaReactionController()
    var observed: (@MainActor (Bool) -> Void)?
    var completion: CheckedContinuation<Bool, Error>?
    var feedback = 0
    controller.start(.init(request: { _ in result }, cancel: { _, _ in }, current: { true }, admitsSpeech: { _ in true },
        play: { _, report in observed = report; return try await withCheckedThrowingContinuation { completion = $0 } },
        stop: { _ in }, failure: {}, notice: nil, admittedFeedback: { feedback += 1 }, observe: touchObservation))
    #expect(await touchEventually { observed != nil })
    #expect(feedback == 1)
    #expect(controller.preparing && !controller.speaking)
    observed?(true)
    #expect(controller.speaking && !controller.preparing)
    observed?(false)
    #expect(!controller.speaking)
    controller.cancel(.speechConflict)
    observed?(true); completion?.resume(returning: true)
    await Task.yield()
    #expect(!controller.speaking && !controller.isActive && controller.reaction == nil)
    #expect(feedback == 1, "Audio callbacks and cancellation cannot repeat admission feedback")
}

@MainActor private final class TouchTestAuthority { var current = true }

@Test @MainActor func personaTouchOwnerChangeWithdrawsTextAndActualOutputWithoutRestart() async throws {
    let (_, _, result) = try touchCase()
    let controller = PersonaReactionController()
    let authority = TouchTestAuthority()
    var plays = 0, stopped = 0
    var completion: CheckedContinuation<Bool, Error>?
    controller.start(.init(request: { _ in result }, cancel: { _, _ in }, current: { authority.current }, admitsSpeech: { _ in true },
        play: { _, observed in plays += 1; observed(true); return try await withCheckedThrowingContinuation { completion = $0 } },
        stop: { _ in stopped += 1 }, failure: {}, notice: nil, observe: touchObservation))
    #expect(await touchEventually { controller.speaking })
    authority.current = false
    #expect(await touchEventually { !controller.isActive })
    authority.current = true; completion?.resume(returning: true)
    await Task.yield()
    #expect(plays == 1 && stopped == 1 && controller.reaction == nil && !controller.speaking)
}

@Test @MainActor func personaTouchTextOnlyNeverRequestsAudioAndKeepsOriginalExpiry() async throws {
    let (_, _, result) = try touchCase(output: .textOnly)
    let controller = PersonaReactionController()
    var plays = 0
    controller.start(.init(request: { _ in result }, cancel: { _, _ in }, current: { true }, admitsSpeech: { _ in false },
        play: { _, _ in plays += 1; return true }, stop: { _ in }, failure: {}, notice: "ui.session.reaction.text_only", observe: touchObservation))
    #expect(await touchEventually { controller.reaction != nil })
    #expect(plays == 0 && !controller.preparing && !controller.speaking)
    #expect(controller.reaction?.expires_at == result.persona_reaction.expires_at)
    #expect(controller.notice == "ui.session.reaction.text_only")
    controller.cancel(.dismissed)
}

#if os(macOS)
@Test(arguments: [CGFloat(320), CGFloat(620)]) @MainActor func personaTouchBubbleRendersCompactAndWideWithoutExtraAvatar(width: CGFloat) throws {
    let view = PersonaReactionBubble(text: "Die tik verdient een klein feestje: denk de confetti er gerust bij.",
                                    notice: "Deze reactie speelt alleen op dit apparaat.", closeLabel: "Sluiten", dismiss: {})
        .environment(\.djConnectGlassEffectsEnabled, false).frame(width: width).padding(24).background(.black)
    let renderer = ImageRenderer(content: view); renderer.scale = 2
    let image = try #require(renderer.nsImage)
    #expect(image.size.width == width + 48 && image.size.height >= 130)
    if let folder = ProcessInfo.processInfo.environment["DJCONNECT_AVATAR_ARTIFACT_DIR"] {
        let tiff = try #require(image.tiffRepresentation)
        let rep = try #require(NSBitmapImageRep(data: tiff))
        try #require(rep.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: folder).appendingPathComponent("touch-bubble-\(Int(width)).png"))
    }
}
#endif


@Test(arguments: ["valid", "missing", "version", "owner", "speaker", "queue", "lifecycle", "malformed"])
func personaTouchRequiresItsOwnDiscoveryWithoutBreakingBasePersona(fault: String) throws {
    var root = try touchFixture("persona-touch-discovery-installed-20261019.json")
    var persona = root["active_session_persona"] as! [String: Any]
    var touch = persona["touch_reaction"] as! [String: Any]
    // Synthetic derivative of the immutable older discovery fixture, using the
    // public withdrawal/tombstone metadata on Core main83744790.
    touch["withdrawal_contract"] = ["version": 1, "transport": "paired_owner_actions",
        "command": "djconnect/persona/reaction/observe", "event": "session/persona/reaction/withdrawn",
        "required_for_display_and_playback": true, "maximum_observers_per_reaction": 1,
        "server_guard_recheck_seconds": 0.25, "on_connection_loss": "withdraw_and_stop", "deadline_renewal": false]
    touch["cancel_before_admission"] = "durable_original_uuidv7_fence_until_operation_deadline"
    switch fault {
    case "version": touch["version"] = 2
    case "owner": touch["owner_only"] = false
    case "speaker": touch["ha_speaker_target"] = true
    case "queue": touch["queue"] = true
    case "lifecycle": touch["client_cancel_on_lifecycle_required"] = false
    default: break
    }
    if fault == "missing" { persona.removeValue(forKey: "touch_reaction") }
    else if fault == "malformed" { persona["touch_reaction"] = ["version": "unknown"] }
    else { persona["touch_reaction"] = touch }
    root["active_session_persona"] = persona
    let result = try JSONDecoder().decode(DJConnectActiveMoodCapabilities.self, from: touchJSON(root))
    #expect(result.personaAvailable)
    #expect(result.personaReactionAvailable == (fault == "valid"))
}

@Test @MainActor func personaTouchOriginalExpiryClosesTextWithoutAnyLocalRenewal() async throws {
    let now = Date()
    let (_, _, result) = try touchCase(now: now)
    let clock = TouchTestClock(now)
    let controller = PersonaReactionController()
    var stopped = 0
    controller.start(.init(request: { _ in result }, cancel: { _, _ in }, current: { true }, admitsSpeech: { _ in false },
        play: { _, _ in Issue.record("Text has no playback grant"); return false }, stop: { _ in stopped += 1 }, failure: {}, notice: "text", observe: touchObservation, now: { clock.value }))
    #expect(await touchEventually { controller.reaction != nil })
    #expect(controller.reaction?.expires_at == result.persona_reaction.expires_at)
    clock.value = try #require(result.persona_reaction.deadline).addingTimeInterval(1)
    #expect(await touchEventually { !controller.isActive })
    #expect(controller.reaction == nil && stopped == 1)
}

@Test func personaTouchHasNoLegacyEndpointFallback() async throws {
    let (request, settings, result) = try touchCase()
    let client = DJConnectClient(baseURL: URL(string: "https://never-sent.invalid")!,
        identity: .init(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Touch test", clientType: .ios, firmware: "4.0.0", platform: .ios),
        tokenStore: DJConnectInMemoryTokenStore(token: "synthetic"))
    await #expect(throws: DJConnectHybridTransportError.unavailable) {
        try await client.requestPersonaReaction(request, settings: settings, onOperationID: { _ in Issue.record("No dispatch without ordinary operation owner") })
    }
    await #expect(throws: DJConnectError.invalidResponse) {
        try await client.personaReactionAudio(result.persona_reaction, request: request, settings: settings)
    }
}


@Test @MainActor func personaTouchFailedAudioStartReleasesOutputImmediatelyButRetainsText() async throws {
    let (_, _, result) = try touchCase()
    let controller = PersonaReactionController()
    var stopped = 0, cancellations = 0
    controller.start(.init(request: { _ in result }, cancel: { _, _ in cancellations += 1 }, current: { true }, admitsSpeech: { _ in true },
        play: { _, _ in false }, stop: { _ in stopped += 1 }, failure: {}, notice: nil, observe: touchObservation))
    #expect(await touchEventually { controller.notice != nil })
    #expect(stopped == 1 && controller.isActive && controller.reaction?.id == result.persona_reaction.id)
    #expect(!controller.preparing && !controller.speaking && cancellations == 0)
    controller.cancel(.dismissed)
}

@Test @MainActor func personaTouchStaleResponseCannotEmitAdmissionFeedback() async throws {
    let (_, _, result) = try touchCase()
    let controller = PersonaReactionController()
    let authority = TouchTestAuthority()
    var continuation: CheckedContinuation<DJConnectPersonaReactionResult, Error>?
    var feedback = 0
    controller.start(.init(request: { _ in
        try await withCheckedThrowingContinuation { continuation = $0 }
    }, cancel: { _, _ in }, current: { authority.current }, admitsSpeech: { _ in false },
    play: { _, _ in false }, stop: { _ in }, failure: {}, notice: nil, admittedFeedback: { feedback += 1 }, observe: touchObservation))
    #expect(await touchEventually { continuation != nil })
    authority.current = false
    continuation?.resume(returning: result)
    for _ in 0..<20 { await Task.yield() }
    #expect(feedback == 0 && controller.reaction == nil)
    controller.cancel(.dismissed)
}

@Test func personaTouchOlderProducerWithoutWithdrawalCannotActivateTaps() throws {
    let root = try touchFixture("persona-touch-discovery-installed-20261019.json")
    let result = try JSONDecoder().decode(DJConnectActiveMoodCapabilities.self, from: touchJSON(root))
    #expect(result.personaAvailable)
    #expect(!result.personaReactionAvailable)
}

@Test func personaTouchObservationNeverRenewsOrReadmitsWithdrawnReaction() async throws {
    let (_, _, result) = try touchCase()
    let observation = DJConnectPersonaReactionObservation(result: result, close: {})
    let snapshot: [String: Any] = ["contract_version": 1, "observation_id": 1,
        "reaction_id": result.persona_reaction.id, "session_id": result.persona_reaction.session.session_id,
        "state": "valid", "expires_at": result.persona_reaction.expires_at, "cache_policy": "private,no-store"]
    #expect(!observation.isValid)
    try observation.accept(touchJSON(snapshot), requestID: 1, initial: true)
    #expect(observation.isValid)
    observation.invalidate()
    #expect(!observation.isValid)
    try observation.accept(touchJSON(snapshot), requestID: 1, initial: true)
    #expect(!observation.isValid)
    for field in ["reaction_id", "session_id", "expires_at", "cache_policy"] {
        let other = DJConnectPersonaReactionObservation(result: result, close: {})
        var mismatch = snapshot; mismatch[field] = "wrong"
        #expect(throws: (any Error).self) { try other.accept(touchJSON(mismatch), requestID: 1, initial: true) }
        #expect(!other.isValid)
    }
    await observation.close()
}

@Test @MainActor func personaTouchRemoteWithdrawalRemovesTextAndStopsOwnedOutput() async throws {
    let (_, _, result) = try touchCase()
    let observation = DJConnectPersonaReactionObservation(result: result, close: {})
    try observation.accept(touchJSON(["contract_version": 1, "observation_id": 1,
        "reaction_id": result.persona_reaction.id, "session_id": result.persona_reaction.session.session_id,
        "state": "valid", "expires_at": result.persona_reaction.expires_at, "cache_policy": "private,no-store"]), requestID: 1, initial: true)
    let controller = PersonaReactionController()
    var stops = 0
    controller.start(.init(request: { _ in result }, cancel: { _, _ in }, current: { true },
        admitsSpeech: { _ in false }, play: { _, _ in false }, stop: { _ in stops += 1 },
        failure: {}, notice: nil, observe: { _ in observation }))
    for _ in 0..<50 { if controller.reaction != nil { break }; await Task.yield() }
    #expect(controller.reaction?.id == result.persona_reaction.id)
    observation.invalidate()
    for _ in 0..<50 { if !controller.isActive { break }; await Task.yield() }
    #expect(!controller.isActive && controller.reaction == nil)
    #expect(stops == 1)
}

@Test @MainActor func personaTouchMissingObserverCannotPresentOrPlayEvenValidReaction() async throws {
    let (_, _, result) = try touchCase()
    let controller = PersonaReactionController()
    var failures = 0, plays = 0
    controller.start(.init(request: { _ in result }, cancel: { _, _ in }, current: { true },
        admitsSpeech: { _ in true }, play: { _, _ in plays += 1; return true }, stop: { _ in },
        failure: { failures += 1 }, notice: nil))
    #expect(await touchEventually { failures == 1 })
    #expect(controller.reaction == nil && !controller.isActive && plays == 0)
}


@MainActor private final class TouchTestClock {
    var value: Date
    init(_ value: Date) { self.value = value }
}

@Test @MainActor func personaTouchAlreadyExpiredResultClosesOriginalRunAndLateOperationCallback() async throws {
    let (_, _, result) = try touchCase()
    let clock = TouchTestClock(try #require(result.persona_reaction.deadline).addingTimeInterval(1))
    let controller = PersonaReactionController()
    var cancels: [(String, DJConnectPersonaReactionCancellation)] = []
    var requests = 0, stops = 0, observations = 0, feedback = 0
    controller.start(.init(request: { dispatched in
        requests += 1
        dispatched(result.persona_reaction.id)
        return result
    }, cancel: { cancels.append(($0, $1)) }, current: { true }, admitsSpeech: { _ in false },
        play: { _, _ in Issue.record("An expired response cannot play"); return false },
        stop: { _ in stops += 1 }, failure: {}, notice: nil, admittedFeedback: { feedback += 1 },
        observe: { value in observations += 1; return try await touchObservation(value) }, now: { clock.value }))
    #expect(await touchEventually { !controller.isActive && cancels.count == 1 })
    #expect(requests == 1 && stops == 1 && observations == 0 && feedback == 0)
    #expect(controller.reaction == nil && !controller.preparing && !controller.speaking)
    #expect(cancels.count == 1 && cancels[0].0 == result.persona_reaction.id && cancels[0].1 == .dismissed)
}
