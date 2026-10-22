import CryptoKit
import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

private func bulletinFixture() throws -> [String: Any] {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let bytes = try Data(contentsOf: root.appendingPathComponent("Fixtures/dj-bulletin-v1-core-3b458934-wire.json"))
    #expect(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() == "aac3b59b6ecce6d7d3a1ca979db6edc08cad4376268c0806d88e06a78ff900b9")
    return try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
}
private func bulletinDecode<T: Decodable>(_ value: Any, as type: T.Type = T.self) throws -> T {
    try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: value))
}
private func bulletinSample() throws -> [String: Any] { try #require(bulletinFixture()["sample"] as? [String: Any]) }
private func bulletinBroadcast() throws -> DJConnectBroadcastState { try bulletinDecode(bulletinSample()["owner_snapshot"]!) }
private func bulletinDate(_ raw: String) throws -> Date { try #require(DJConnectHistoryEntry.date(raw)) }

@Test func bulletinCoreWireAddsOneOrdinaryMomentAndPreservesOriginalSourceDeadlines() throws {
    let broadcast = try bulletinBroadcast()
    let moment = try #require(broadcast.djMoments.first)
    let now = try bulletinDate(moment.createdAt).addingTimeInterval(1)
    #expect(moment.isBulletinV1 && moment.isSupportedNativeType)
    #expect(moment.sources.map(\.provider) == ["CBS", "KNMI"])
    #expect(moment.nativeSourceURLs == moment.sources.compactMap(\.destination))
    #expect(moment.presentationIntent.sourceSessionMood == "groove")
    #expect(moment.presentationIntent.djPersona == "home_dj")
    #expect(moment.actions.isEmpty && moment.artwork == nil)
    #expect(broadcast.nativeCurrentMoment(at: now)?.id == moment.id)
    #expect(broadcast.nativeFlowMoments(at: now).isEmpty) // exactly one current/Flow bubble
    let admission = try #require(broadcast.nativeDelivery?.admissions.first)
    let displayEnd = try bulletinDate(try #require(admission.displayExpiresAt))
    #expect(broadcast.nativeCurrentMoment(at: displayEnd) == nil)
    #expect(broadcast.nativeFlowMoments(at: displayEnd).map(\.id) == [moment.id])
    let sourceEnd = try bulletinDate(try #require(admission.sourceExpiresAt))
    #expect(broadcast.nativeCurrentMoment(at: sourceEnd) == nil)
    #expect(broadcast.nativeFlowMoments(at: sourceEnd).isEmpty)
    let roundtrip = try JSONDecoder().decode(DJConnectBroadcastState.self, from: JSONEncoder().encode(broadcast))
    #expect(roundtrip.nativeDelivery?.admissions.first?.sourceExpiresAt == admission.sourceExpiresAt)
    #expect(roundtrip.nativeFlowMoments(at: sourceEnd).isEmpty) // no renewal on read/encode
}

@Test func bulletinNeedsExactVersionPrivateShapeAndExplicitOriginalAdmission() throws {
    let original = try bulletinBroadcast()
    let now = try bulletinDate(try #require(original.djMoments.first).createdAt).addingTimeInterval(1)
    for mutation in 0..<10 {
        var value = original
        switch mutation {
        case 0: value.nativeDelivery = nil
        case 1: value.nativeDelivery?.admissions[0].qualification = "unqualified"
        case 2: value.nativeDelivery?.admissions[0].sourceExpiresAt = nil
        case 3: value.djMoments[0].generationMetadata?["bulletin_schema"] = "2"
        case 4: value.djMoments[0].visibility = "public_broadcast"
        case 5: value.djMoments[0].deliveryChannels = ["owner", "shared"]
        case 6: value.djMoments[0].sourceReferences = ["MusicBrainz"]
        case 7: value.nativeDelivery?.admissions[0].requiresSpotifyAttribution = true
        case 8: value.nativeDelivery?.admissions[0].currentDisplayAllowed = false
                value.nativeDelivery?.admissions[0].activeFlowDisplayAllowed = false
        default: value.djMoments[0].type = "future_bulletin"
        }
        #expect(value.nativeCurrentMoment(at: now) == nil)
        #expect(value.nativeFlowMoments(at: now).isEmpty)
    }
    var revoked = original
    revoked.nativeDelivery = try bulletinDecode(bulletinFixture()["revoked_native_delivery"]!)
    #expect(revoked.nativeCurrentMoment(at: now) == nil && revoked.nativeFlowMoments(at: now).isEmpty)
    var unrelated = original; unrelated.session.sessionID = "another-owner-session"
    #expect(unrelated.nativeCurrentMoment(at: now) == nil)
}

@Test func bulletinMalformedSourcesDoNotDestroySurroundingKnownMoments() throws {
    let sample = try bulletinSample()
    var owner = try #require(sample["owner_snapshot"] as? [String: Any])
    var bad = try #require((owner["dj_moments"] as? [[String: Any]])?.first)
    var sources = try #require(bad["sources"] as? [[String: Any]])
    sources[0]["url"] = "javascript:forbidden"; bad["sources"] = sources
    owner["dj_moments"] = [bad]
    let rejected: DJConnectBroadcastState = try bulletinDecode(owner)
    let now = try bulletinDate(try #require(rejected.djMoments.first).createdAt)
    #expect(rejected.nativeCurrentMoment(at: now) == nil)
    sources[0]["provider"] = ["malformed": true]; bad["sources"] = sources
    var future = bad; future["moment_id"] = "future"; future["type"] = "future_unknown"
    owner["dj_moments"] = [bad, future]
    let isolated: DJConnectBroadcastState = try bulletinDecode(owner)
    #expect(isolated.djMoments.map(\.id) == ["future"])
    #expect(isolated.djMoments.first?.isSupportedNativeType == false)
    #expect(isolated.nativeCurrentMoment(at: now) == nil)
}

@Test func bulletinAutoplayUsesExistingToggleAndOriginalSpeechAuthorization() throws {
    let sample = try bulletinSample(), broadcast = try bulletinBroadcast()
    let moment = try #require(broadcast.djMoments.first)
    let now = try bulletinDate(moment.createdAt).addingTimeInterval(1)
    let on: DJConnectSessionSpeech = try bulletinDecode(sample["speech_on"]!)
    let off: DJConnectSessionSpeech = try bulletinDecode(sample["speech_off"]!)
    #expect(on.autoplayEligible && !off.autoplayEligible)
    #expect(on.admits(reference: on.reference, text: moment.content, at: now))
    #expect(off.admits(reference: off.reference, text: moment.content, at: now)) // manual remains authorized
    #expect(on.sourceExpiresAt == off.sourceExpiresAt && on.expiresAt == off.expiresAt)
    #expect(!on.admits(reference: on.reference, text: moment.content, at: try bulletinDate(try #require(on.sourceExpiresAt))))
    var state = SessionSpeechAutoplayAdmission()
    _ = state.observe(sessionID: moment.sessionID, momentIDs: [], readyIDs: [], enabled: true, now: now)
    #expect(state.observe(sessionID: moment.sessionID, momentIDs: [moment.id], readyIDs: [], enabled: true, now: now).isEmpty)
    #expect(state.observe(sessionID: moment.sessionID, momentIDs: [moment.id], readyIDs: [moment.id], enabled: true, now: now) == [moment.id])
    #expect(state.observe(sessionID: moment.sessionID, momentIDs: [moment.id], readyIDs: [moment.id], enabled: true, now: now).isEmpty)
    state.reset() // reconnect/restart establishes a silent restored baseline
    #expect(state.observe(sessionID: moment.sessionID, momentIDs: [moment.id], readyIDs: [moment.id], enabled: true, now: now).isEmpty)
    state.reset()
    _ = state.observe(sessionID: moment.sessionID, momentIDs: [], readyIDs: [], enabled: false, now: now)
    #expect(state.observe(sessionID: moment.sessionID, momentIDs: [moment.id], readyIDs: [moment.id], enabled: false, now: now).isEmpty)
    #expect(state.observe(sessionID: moment.sessionID, momentIDs: [moment.id], readyIDs: [moment.id], enabled: true, now: now).isEmpty)
}

@Test func bulletinVoiceBeforeTextAndWithdrawalABAOrPendingExpiryNeverRepeatOrResume() {
    let now = Date(timeIntervalSince1970: 1000)
    var state = SessionSpeechAutoplayAdmission()
    _ = state.observe(sessionID: "session", momentIDs: [], readyIDs: ["bulletin"], enabled: true, now: now)
    #expect(state.observe(sessionID: "session", momentIDs: ["bulletin"], readyIDs: ["bulletin"], enabled: true, now: now) == ["bulletin"])
    state.reset()
    _ = state.observe(sessionID: "session", momentIDs: [], readyIDs: [], enabled: true, now: now)
    _ = state.observe(sessionID: "session", momentIDs: ["bulletin"], readyIDs: [], enabled: true, now: now)
    _ = state.observe(sessionID: "session", momentIDs: ["bulletin"], readyIDs: [], enabled: true, now: now, revokedIDs: ["bulletin"])
    #expect(state.observe(sessionID: "session", momentIDs: ["bulletin"], readyIDs: ["bulletin"], enabled: true, now: now).isEmpty)
    _ = state.observe(sessionID: "session", momentIDs: ["gone"], readyIDs: [], enabled: true, now: now)
    _ = state.observe(sessionID: "session", momentIDs: [], readyIDs: [], enabled: true, now: now)
    #expect(state.observe(sessionID: "session", momentIDs: ["gone"], readyIDs: ["gone"], enabled: true, now: now).isEmpty)
    _ = state.observe(sessionID: "session", momentIDs: ["expired"], readyIDs: [], enabled: true, now: now)
    #expect(state.observe(sessionID: "session", momentIDs: ["expired"], readyIDs: ["expired"], enabled: true, now: now.addingTimeInterval(120)).isEmpty)
    #expect(state.observe(sessionID: "other", momentIDs: ["expired"], readyIDs: ["expired"], enabled: true, now: now).isEmpty)
}

@Test func bulletinLiveFlowRowsAreStableChronologicalAndDeduplicated() throws {
    let broadcast = try bulletinBroadcast()
    let first = try #require(broadcast.djMoments.first)
    var next = first; next.momentID += "-later"; next.createdAt = ISO8601DateFormatter().string(from: try bulletinDate(first.createdAt).addingTimeInterval(1))
    let rows = SessionTimelineLiveRow.merge(retained: [], bulletins: [first, next, first], at: try bulletinDate(first.createdAt))
    #expect(rows.map(\.id) == ["live-moment-" + next.id, "live-moment-" + first.id])
    #expect(SessionTimelineLiveRow.merge(retained: [], bulletins: [], at: try bulletinDate(first.createdAt)).isEmpty)
}

@Test func bulletinStaticTypeLabelsExistInAllFiveLocales() {
    for language in ["nl", "en", "de", "fr", "es"] {
        let label = DJConnectLocalization.localized(key: "ui.session.moment.dj_bulletin", language: language)
        #expect(!label.isEmpty && label != "ui.session.moment.dj_bulletin")
    }
}


@Test func bulletinQueuedAutoplayCannotBecomeLateManualSpeechAfterCurrentWithdrawal() throws {
    let broadcast = try bulletinBroadcast(), moment = try #require(broadcast.djMoments.first)
    let reference = DJConnectSpeechReference.moment(sessionID: moment.sessionID, momentID: moment.id)
    let now = try bulletinDate(moment.createdAt).addingTimeInterval(1)
    #expect(broadcast.nativeMomentSpeechIsAdmitted(reference, at: now, automatic: true))
    let displayEnd = try bulletinDate(try #require(broadcast.nativeDelivery?.admissions.first?.displayExpiresAt))
    #expect(!broadcast.nativeMomentSpeechIsAdmitted(reference, at: displayEnd, automatic: true))
    #expect(broadcast.nativeMomentSpeechIsAdmitted(reference, at: displayEnd, automatic: false))
    let sourceEnd = try bulletinDate(try #require(broadcast.nativeDelivery?.admissions.first?.sourceExpiresAt))
    #expect(!broadcast.nativeMomentSpeechIsAdmitted(reference, at: sourceEnd, automatic: false))
    var revoked = broadcast
    revoked.nativeDelivery = try bulletinDecode(bulletinFixture()["revoked_native_delivery"]!)
    #expect(!revoked.nativeMomentSpeechIsAdmitted(reference, at: now, automatic: true))
    #expect(!revoked.nativeMomentSpeechIsAdmitted(reference, at: now, automatic: false))
}

@Test func bulletinCannotTravelThroughExistingWatchCompanionProjection() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let old = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/moment-contract-receipt.json"))) as? [String: Any])
    var runtime: DJConnectSessionRuntime = try bulletinDecode(old["runtime"]!)
    let broadcast = try bulletinBroadcast(), moment = try #require(broadcast.djMoments.first)
    runtime.sessionID = moment.sessionID; runtime.broadcast = broadcast
    let settingsFixture = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/profile-settings3-core-1329ad1.json"))) as? [String: Any])
    let cases = try #require(settingsFixture["cases"] as? [[String: Any]])
    let settings: DJConnectProfileDJSettingsResponse = try bulletinDecode(try #require(cases.first { $0["case"] as? String == "active_atomic_all_five_and_replay" }?["response"]))
    let watch = DJConnectWatchSessionSnapshot(settings: settings, session: runtime, at: try bulletinDate(moment.createdAt))
    #expect(watch.session?.broadcast.djMoments.isEmpty == true)
    #expect(watch.speechSources.isEmpty && watch.session?.broadcast.sessionSpeech.isEmpty == true)
    let bytes = String(decoding: try JSONEncoder().encode(watch), as: UTF8.self)
    #expect(!bytes.contains(moment.content) && !bytes.contains("fixed_rss_metadata_v1"))
}


@Test func bulletinInvalidActionOrArtworkShapeIsNotSilentlyErasedIntoAnAllowedBulletin() throws {
    let sample = try bulletinSample()
    let original = try #require(sample["owner_snapshot"] as? [String: Any])
    let moment = try #require((original["dj_moments"] as? [[String: Any]])?.first)
    for malformed in 0..<3 {
        var value = original, changed = moment
        switch malformed {
        case 0: changed["actions"] = [["action_type": "play", "label": "Invalid", "payload": 7]]
        case 1: changed["actions"] = "not-an-array"
        default: changed["artwork"] = "not-a-descriptor"
        }
        value["dj_moments"] = [changed]
        let result: DJConnectBroadcastState = try bulletinDecode(value)
        #expect(result.djMoments.isEmpty)
    }
}

@Test func bulletinPreparedAndCommittedSourceFixturesStayCompatibleWithoutRuntimeClaim() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    for (file, sha) in [("dj-bulletin-v1-core-preparatory-wire.json", "909f525e609af7daf07653099a1c34b688cfd1e171b75d24c9225e34fceccc2f"),
                        ("dj-bulletin-v1-core-3b458934-wire.json", "aac3b59b6ecce6d7d3a1ca979db6edc08cad4376268c0806d88e06a78ff900b9")] {
        let bytes = try Data(contentsOf: root.appendingPathComponent("Fixtures/" + file))
        #expect(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() == sha)
        let fixture = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        let sample = try #require(fixture["sample"] as? [String: Any])
        let broadcast: DJConnectBroadcastState = try bulletinDecode(try #require(sample["owner_snapshot"]))
        let moment = try #require(broadcast.djMoments.first)
        let date = try bulletinDate(moment.createdAt).addingTimeInterval(1)
        #expect(moment.isBulletinV1 && broadcast.nativeCurrentMoment(at: date)?.id == moment.id)
        let source = try #require(broadcast.nativeDelivery?.admissions.first?.sourceExpiresAt)
        let expiry = try bulletinDate(source)
        #expect(broadcast.nativeCurrentMoment(at: expiry) == nil && broadcast.nativeFlowMoments(at: expiry).isEmpty)
        #expect(fixture["native"] as? String == "NOT_RUN")
    }
}
