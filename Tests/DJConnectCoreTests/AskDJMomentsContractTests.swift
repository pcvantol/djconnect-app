import Foundation
import Testing
@testable import DJConnectCore

func askDJMomentsFixtureBundle() -> Bundle {
    #if SWIFT_PACKAGE
    Bundle.module
    #else
    Bundle(for: AskDJMomentsFixtureAnchor.self)
    #endif
}
private final class AskDJMomentsFixtureAnchor: NSObject {}

/// Core's actual Hybrid -> producer -> narrator -> SQL -> Flow serializer.
/// Research/model inputs are synthetic fixtures; these tests make no live/editorial claim.
private func momentFixture(_ name: String) throws -> [String: Any] {
    let url = try #require(askDJMomentsFixtureBundle().url(forResource: name, withExtension: "json", subdirectory: "Fixtures/ask-dj-moments")
        ?? askDJMomentsFixtureBundle().url(forResource: name, withExtension: "json"))
    return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
}
private func decodeMomentValue<T: Decodable>(_ value: Any, as: T.Type = T.self) throws -> T {
    try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: value))
}

@Test func askDJMomentsActualCoreCatalogueAndOriginalAcceptedIdentity() throws {
    let fixture = try momentFixture("producer-final")
    let capability: DJConnectAskDJMoments.Capability = try decodeMomentValue(try #require(fixture["capability"]))
    let inventory: DJConnectAskDJMoments.Inventory = try decodeMomentValue(try #require(fixture["inventory"]))
    let response: DJConnectAskDJMoments.Response = try decodeMomentValue(try #require(fixture["accepted_http_response"]))
    let envelope = try #require(fixture["request_envelope"] as? [String: Any])
    let request: DJConnectAskDJMoments.Request = try decodeMomentValue(try #require(envelope["payload"]))
    let item = try #require(inventory.types.first { $0.typeID == request.typeID })
    let result = try #require(response.result)
    let now = try #require(DJConnectHistoryEntry.date(result.moment.createdAt)).addingTimeInterval(1)
    #expect(capability.admits(client: .ios))
    #expect(capability.admits(client: .macos))
    #expect(!capability.admits(client: .watchos))
    #expect(inventory.admits(session: request.sessionID, capability: capability))
    #expect(inventory.orderedTypes.count == 10)
    #expect(response.matches(request, originalID: response.operationID))
    #expect(result.admits(request: request, item: item, operationID: response.operationID, at: now))
    #expect(!result.admits(request: request, item: item, operationID: "01a1fa00-a9ac-7000-8000-000000000002", at: now))
    #expect(!result.admits(request: request, item: item, operationID: response.operationID, at: now.addingTimeInterval(3600)))
    let history: DJConnectHistoryEntry = try decodeMomentValue(try #require(fixture["history_entry"]))
    #expect(history.momentID == result.moment.id)
    #expect(history.id == result.entryID)
    #expect(history.userRequested == result.moment.userRequested)
    #expect(history.text == result.moment.content)
    #expect(result.moment.nativeSourceURLs.count == 3)
    let roundtrip = try JSONDecoder().decode(DJConnectMoment.self, from: JSONEncoder().encode(result.moment))
    #expect(roundtrip.userRequested == result.moment.userRequested)
    #expect(roundtrip.researchSources == result.moment.researchSources)
    #expect(roundtrip.nativeSourceURLs == result.moment.nativeSourceURLs)
    let restored = try JSONDecoder().decode(DJConnectHistoryEntry.self, from: JSONEncoder().encode(history))
    #expect(restored.userRequested == history.userRequested)
    let status: DJConnectAskDJMoments.Response = try decodeMomentValue(try #require(fixture["status_response"]))
    #expect(status.result?.moment == result.moment)
    #expect(status.result?.sessionSpeech?.moments.allSatisfy { !$0.autoplayEligible } == true)
}

@Test func askDJMomentsCatalogueRejectsMissingFamilyDuplicateAndMismatchedRenderer() throws {
    let fixture = try momentFixture("producer-final")
    let capability: DJConnectAskDJMoments.Capability = try decodeMomentValue(try #require(fixture["capability"]))
    var raw = try #require(fixture["inventory"] as? [String: Any])
    let types = try #require(raw["types"] as? [[String: Any]])
    raw["types"] = Array(types.dropLast())
    let missing: DJConnectAskDJMoments.Inventory = try decodeMomentValue(raw)
    #expect(!missing.admits(session: missing.sessionID, capability: capability))
    var duplicate = types; duplicate[1] = duplicate[0]; raw["types"] = duplicate
    let repeated: DJConnectAskDJMoments.Inventory = try decodeMomentValue(raw)
    #expect(!repeated.admits(session: repeated.sessionID, capability: capability))
    let response: DJConnectAskDJMoments.Response = try decodeMomentValue(try #require(fixture["accepted_http_response"]))
    let envelope = try #require(fixture["request_envelope"] as? [String: Any])
    let request: DJConnectAskDJMoments.Request = try decodeMomentValue(try #require(envelope["payload"]))
    var row = try #require(types.first { $0["type_id"] as? String == request.typeID })
    row["moment_type"] = "live_impression"
    let wrongFamily: DJConnectAskDJMoments.Item = try decodeMomentValue(row)
    let result = try #require(response.result)
    let now = try #require(DJConnectHistoryEntry.date(result.moment.createdAt)).addingTimeInterval(1)
    #expect(!result.admits(request: request, item: wrongFamily, operationID: response.operationID, at: now))
}

@Test func askDJMomentsActualFailureDoesNotBecomeAcceptedRichSuccess() throws {
    let fixture = try momentFixture("not-found-final")
    let response: DJConnectAskDJMoments.Response = try decodeMomentValue(try #require(fixture["not_found_response"]))
    let envelope = try #require(fixture["request_envelope"] as? [String: Any])
    let request: DJConnectAskDJMoments.Request = try decodeMomentValue(try #require(envelope["payload"]))
    #expect(response.matches(request, originalID: response.operationID))
    #expect(response.state == .notFound)
    #expect(response.result == nil)
    #expect(response.message?.isEmpty == false)
}

@Test(arguments: ["live-final", "bulletin-final"])
func askDJMomentsActualRichFamilyAndSourceSpecificRetention(name: String) throws {
    let fixture = try momentFixture(name)
    let capability: DJConnectAskDJMoments.Capability = try decodeMomentValue(try #require(fixture["capability"]))
    let inventory: DJConnectAskDJMoments.Inventory = try decodeMomentValue(try #require(fixture["inventory"]))
    let response: DJConnectAskDJMoments.Response = try decodeMomentValue(try #require(fixture["accepted_http_response"]))
    let envelope = try #require(fixture["request_envelope"] as? [String: Any])
    let request: DJConnectAskDJMoments.Request = try decodeMomentValue(try #require(envelope["payload"]))
    let item = try #require(inventory.types.first { $0.typeID == request.typeID })
    let captured = try #require(fixture["captured_at"] as? String)
    let now = try #require(DJConnectHistoryEntry.date(captured))
    let result = try #require(response.result)
    #expect(inventory.admits(session: request.sessionID, capability: capability))
    #expect(response.matches(request, originalID: response.operationID))
    #expect(result.admits(request: request, item: item, operationID: response.operationID, at: now))
    if name == "live-final" {
        #expect(result.moment.isLiveImpressionV1)
        #expect(result.sessionMedia.count == 1)
        #expect(result.sessionMedia.first?.target == .moment(result.moment.id))
        #expect(result.moment.liveImpression?.photos.count == 1)
        #expect(result.historyState == "content_retained")
    } else {
        #expect(result.moment.isBulletinV1)
        #expect(result.retention == "not_retained")
        #expect(result.historyState == "receipt_only")
        #expect(result.entryID != nil)
        #expect(result.sessionSpeech?.moments.allSatisfy { !$0.autoplayEligible } == true)
    }
}

@Test func askDJMomentsActualPendingCancelKeepsOriginalOperationIdentity() throws {
    let fixture = try momentFixture("pending-cancel-final")
    let envelope = try #require(fixture["request_envelope"] as? [String: Any])
    let request: DJConnectAskDJMoments.Request = try decodeMomentValue(try #require(envelope["payload"]))
    let pending: DJConnectAskDJMoments.Response = try decodeMomentValue(try #require(fixture["pending_response"]))
    let cancelled: DJConnectAskDJMoments.Response = try decodeMomentValue(try #require(fixture["cancel_response"]))
    #expect(pending.matches(request, originalID: pending.operationID))
    #expect(pending.state == .pending)
    #expect(cancelled.matches(request, originalID: pending.operationID, checksReceipt: false))
    #expect(cancelled.state == .cancelled)
    #expect(cancelled.result == nil)
}

@Test func malformedOptionalRequestedProvenanceKeepsHistoryButCannotPromoteCurrent() throws {
    let fixture = try momentFixture("producer-final")
    var history = try #require(fixture["history_entry"] as? [String: Any])
    let original: DJConnectHistoryEntry = try decodeMomentValue(history)
    history["user_requested"] = ["operation_id": 7]
    let retained: DJConnectHistoryEntry = try decodeMomentValue(history)
    #expect(retained.id == original.id)
    #expect(retained.text == original.text)
    #expect(retained.userRequested == nil)
    let response = try #require(fixture["accepted_http_response"] as? [String: Any])
    let result = try #require(response["result"] as? [String: Any])
    var moment = try #require(result["moment"] as? [String: Any])
    moment["user_requested"] = ["operation_id": 7]
    let unqualified: DJConnectMoment = try decodeMomentValue(moment)
    #expect(unqualified.userRequested == nil)
    #expect(unqualified.hasUserRequestedProvenance)
}

@Test func askDJMomentsOptionalMediaFailureCannotEraseAcceptedOriginalStory() throws {
    let fixture = try momentFixture("producer-final")
    var response = try #require(fixture["accepted_http_response"] as? [String: Any])
    let original: DJConnectAskDJMoments.Response = try decodeMomentValue(response)
    var result = try #require(response["result"] as? [String: Any])
    result["session_speech"] = ["schema_version": 1, "moments": [["user_requested": "not-a-permission"]]]
    result["session_media"] = [["unavailable": true]]
    response["result"] = result
    let retained: DJConnectAskDJMoments.Response = try decodeMomentValue(response)
    #expect(retained.result?.moment == original.result?.moment)
    #expect(retained.result?.entryID == original.result?.entryID)
    #expect(retained.result?.admission == original.result?.admission)
    #expect(retained.result?.sessionMedia.isEmpty == true)
    #expect(retained.result?.speech == nil)
}

@Test func askDJMomentsActualRestartedHistoryTextOnlyManualGrantRequiresMarkerAndCurrentSettingsFence() throws {
    let fixture = try momentFixture("retained-manual-text-only-final")
    let settings: DJConnectProfileDJSettingsResponse = try decodeMomentValue(try #require(fixture["current_settings_response"]))
    let history: DJConnectHistoryEntry = try decodeMomentValue(try #require(fixture["history_entry"]))
    let preparation: DJConnectSharedSpeechResult = try decodeMomentValue(try #require(fixture["manual_prepare_response"]))
    let captured = try #require(fixture["captured_at"] as? String)
    let now = try #require(DJConnectHistoryEntry.date(captured))
    let source = try #require(history.sessionSpeech)
    let text = try #require(history.text)
    let prepared = preparation.session_speech
    let reference = DJConnectSpeechReference.entry(sessionID: history.sessionID, entryID: history.id)
    #expect(settings.isValid)
    #expect(settings.snapshot.session == nil)
    #expect(settings.snapshot.effective.announcement_output == .textOnly)
    #expect(source.userRequested == true)
    #expect(source.admits(reference: reference, text: text, at: now))
    #expect(!source.autoplayEligible)
    #expect(!settings.allowsSpeech(.local, manualMomentType: history.momentType))
    #expect(settings.allowsSpeech(.local, manualMomentType: history.momentType, requestedSpeech: source))
    #expect(!settings.allowsSpeech(.haSpeaker, manualMomentType: history.momentType, requestedSpeech: source))
    #expect(!settings.allowsSpeech(.both, manualMomentType: history.momentType, requestedSpeech: source))
    #expect(prepared.textRevision == source.textRevision)
    #expect(prepared.presentationRevision == source.presentationRevision)
    #expect(prepared.attribution == source.attribution)
    #expect(DJConnectNativeSpeechAdmission.admits(prepared, reference: reference, text: text, settings: settings, at: now))
    var noMarker = prepared; noMarker.userRequested = nil
    #expect(!DJConnectNativeSpeechAdmission.admits(noMarker, reference: reference, text: text, settings: settings, at: now))
    #expect(!DJConnectNativeSpeechAdmission.admits(prepared, reference: reference, text: text + " altered", settings: settings, at: now))
    let oldSettings: DJConnectProfileDJSettingsResponse = try decodeMomentValue(try #require(fixture["settings_response"]))
    #expect(!DJConnectNativeSpeechAdmission.admits(prepared, reference: reference, text: text, settings: oldSettings, at: now))
}

@Test func askDJMomentsCoreReasonLabelsFollowClientLocaleWithoutChangingOriginalSubjectOrStory() throws {
    let fixture = try momentFixture("producer-final")
    let inventory: DJConnectAskDJMoments.Inventory = try decodeMomentValue(try #require(fixture["inventory"]))
    let unavailable = try #require(inventory.types.first { !$0.available })
    for language in ["en", "nl", "de", "fr", "es"] {
        #expect(unavailable.reasonLabels?[language]?.isEmpty == false)
        #expect(unavailable.unavailableReason(language: language) == unavailable.reasonLabels?[language])
        #expect(unavailable.title(language: language) == unavailable.label[language])
    }
    #expect(inventory.types.first { $0.typeID == "album_continuity" }?.momentType == "track")
    #expect(inventory.types.first { $0.typeID == "dj_bulletin" }?.subject.title.hasPrefix("session-") == false)
}

@Test func askDJMomentsActualTemporaryFailureDoesNotProduceOrRetainRichContent() throws {
    let fixture = try momentFixture("temporary-failure-final")
    let response: DJConnectAskDJMoments.Response = try decodeMomentValue(try #require(fixture["failure_response"]))
    #expect(response.state == .temporarilyUnavailable)
    #expect(response.result == nil)
    #expect(response.message?.isEmpty == false)
}
