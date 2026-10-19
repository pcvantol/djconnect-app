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

@Test @MainActor func personaTouchCancellationBeforeDispatchFencesLateResultAndCancelsOriginalID() async throws {
    let (_, _, result) = try touchCase()
    let controller = PersonaReactionController()
    var continuation: CheckedContinuation<DJConnectPersonaReactionResult, Error>?
    var dispatched: (@Sendable (String) -> Void)?
    var cancels: [(String, DJConnectPersonaReactionCancellation)] = []
    var plays = 0, stops = 0, requests = 0
    let services = PersonaReactionController.Services(request: { callback in
        requests += 1; dispatched = callback
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }, cancel: { cancels.append(($0, $1)) }, current: { true }, admitsSpeech: { _ in true },
    play: { _, _ in plays += 1; return true }, stop: { _ in stops += 1 }, failure: {}, notice: nil)
    controller.start(services)
    #expect(await touchEventually { continuation != nil })
    controller.start(services) // A second gesture cannot create a queue.
    controller.cancel(.background)
    dispatched?(result.persona_reaction.id)
    continuation?.resume(returning: result)
    #expect(await touchEventually { !cancels.isEmpty })
    #expect(requests == 1 && plays == 0 && stops == 1)
    #expect(cancels.count == 1 && cancels[0].0 == result.persona_reaction.id && cancels[0].1 == .background)
    #expect(controller.reaction == nil && !controller.preparing && !controller.speaking)
}

@Test @MainActor func personaTouchOnlyActualAudioCallbackSpeaksAndLateCallbacksCannotReviveIt() async throws {
    let (_, _, result) = try touchCase()
    let controller = PersonaReactionController()
    var observed: (@MainActor (Bool) -> Void)?
    var completion: CheckedContinuation<Bool, Error>?
    controller.start(.init(request: { _ in result }, cancel: { _, _ in }, current: { true }, admitsSpeech: { _ in true },
        play: { _, report in observed = report; return try await withCheckedThrowingContinuation { completion = $0 } },
        stop: { _ in }, failure: {}, notice: nil))
    #expect(await touchEventually { observed != nil })
    #expect(controller.preparing && !controller.speaking)
    observed?(true)
    #expect(controller.speaking && !controller.preparing)
    observed?(false)
    #expect(!controller.speaking)
    controller.cancel(.speechConflict)
    observed?(true); completion?.resume(returning: true)
    await Task.yield()
    #expect(!controller.speaking && !controller.isActive && controller.reaction == nil)
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
        stop: { _ in stopped += 1 }, failure: {}, notice: nil))
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
        play: { _, _ in plays += 1; return true }, stop: { _ in }, failure: {}, notice: "ui.session.reaction.text_only"))
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
    let (_, _, result) = try touchCase { reaction in
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        reaction["expires_at"] = formatter.string(from: Date().addingTimeInterval(0.25))
    }
    let controller = PersonaReactionController()
    var stopped = 0
    controller.start(.init(request: { _ in result }, cancel: { _, _ in }, current: { true }, admitsSpeech: { _ in false },
        play: { _, _ in Issue.record("Text has no playback grant"); return false }, stop: { _ in stopped += 1 }, failure: {}, notice: "text"))
    #expect(await touchEventually { controller.reaction != nil })
    #expect(controller.reaction?.expires_at == result.persona_reaction.expires_at)
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
        play: { _, _ in false }, stop: { _ in stopped += 1 }, failure: {}, notice: nil))
    #expect(await touchEventually { controller.notice != nil })
    #expect(stopped == 1 && controller.isActive && controller.reaction?.id == result.persona_reaction.id)
    #expect(!controller.preparing && !controller.speaking && cancellations == 0)
    controller.cancel(.dismissed)
}
