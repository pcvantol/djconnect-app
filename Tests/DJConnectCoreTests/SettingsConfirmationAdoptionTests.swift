import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

private func confirmationFixture() throws -> [String: Any] {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/settings-confirmation-core-20261022.json"))) as? [String: Any])
}
private func confirmationDecode<T: Decodable>(_ value: Any, as type: T.Type) throws -> T {
    try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: value))
}
private func confirmationBroadcast(_ example: [String: Any]) throws -> DJConnectBroadcastState {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let old = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/moment-contract-receipt.json"))) as? [String: Any])
    var broadcast = (old["runtime"] as! [String: Any])["broadcast"] as! [String: Any]
    let moment = example["moment"] as! [String: Any]
    let intent = moment["presentation_intent"] as! [String: Any]
    broadcast["session"] = ["session_id": moment["session_id"]!, "runtime_state": "active",
        "selected_mood": intent["source_session_mood"]!, "selected_presence": "music_only"]
    broadcast["playback"] = NSNull()
    broadcast["dj_moments"] = [moment]
    broadcast["native_delivery"] = example["native_delivery"]
    broadcast["session_flow"] = ["flow_id": "fixture-flow", "planning_horizon_minutes": 15,
        "created_at": moment["created_at"]!, "items": [["item_id": "fixture-item", "item_type": "dj_moment",
            "position": "now", "label": "Confirmation", "moment_id": moment["moment_id"]!]]]
    return try confirmationDecode(broadcast, as: DJConnectBroadcastState.self)
}

@Test func settingsConfirmationDisplaysOnceWithoutPlaybackAndKeepsOriginalDeadline() throws {
    for example in try confirmationFixture()["examples"] as! [[String: Any]] {
        let response = try confirmationDecode(example["response"]!, as: DJConnectProfileDJSettingsResponse.self)
        #expect(response.isValid && response.settings_confirmation_contract?.isSupported == true)
        #expect(response.settings_confirmation?.validates(response.snapshot) == true)
        let broadcast = try confirmationBroadcast(example)
        let moment = try #require(broadcast.djMoments.first)
        let at = try #require(DJConnectHistoryEntry.date(moment.createdAt)).addingTimeInterval(1)
        #expect(moment.isSettingsConfirmation)
        #expect(broadcast.nativeCurrentMoment(at: at)?.id == moment.id)
        #expect(broadcast.nativeFlowMoments(at: at).isEmpty) // no current + Flow duplicate
        var paused = broadcast
        paused.playback = try confirmationDecode(["state": "paused"], as: DJConnectSessionPlayback.self)
        #expect(paused.nativeCurrentMoment(at: at)?.id == moment.id)
        let deadline = try #require(broadcast.nativeDelivery?.admissions.first?.displayExpiresAt.flatMap(DJConnectHistoryEntry.date))
        #expect(broadcast.nativeCurrentMoment(at: deadline) == nil)
        #expect(broadcast.nativeFlowMoments(at: deadline).isEmpty)
        var denied = broadcast; denied.nativeDelivery = nil
        #expect(denied.nativeCurrentMoment(at: at) == nil)
        denied = broadcast; denied.djMoments[0].settingsConfirmation = nil
        #expect(denied.nativeCurrentMoment(at: at) == nil)
        denied = broadcast; denied.djMoments[0].visibility = "public_broadcast"
        #expect(denied.nativeCurrentMoment(at: at) == nil)
        denied = broadcast; denied.nativeDelivery?.currentSilenceMomentID = "silence"
        #expect(denied.nativeCurrentMoment(at: at) == nil)
    }
}

@Test @MainActor func profileOnlyConfirmationComesFromAcceptedOperationNeverFromGETOrReplay() async throws {
    let fixture = try confirmationFixture()
    let original = fixture["profile_only_response"] as! [String: Any]
    let model = ProfileDJSettingsModel(); model.bind(owner: "fixture-owner", active: true)
    let read = try confirmationDecode(original, as: DJConnectProfileDJSettingsResponse.self)
    let services = ProfileDJSettingsModel.Services(read: { read }, update: { _, _, id in
        var accepted = original; accepted["operation_id"] = id
        return try confirmationDecode(accepted, as: DJConnectProfileDJSettingsResponse.self)
    }, receipt: { _, _ in throw CancellationError() })
    await model.refresh(services)
    #expect(model.takeOperationConfirmation() == nil)
    _ = await model.change(.init(mood: read.snapshot.effective.mood), using: services)
    #expect(model.takeOperationConfirmation()?.text == read.settings_confirmation?.text)
    #expect(model.takeOperationConfirmation() == nil)
    await model.refresh(services)
    #expect(model.takeOperationConfirmation() == nil)
    _ = await model.change(.init(mood: read.snapshot.effective.mood), using: services)
    #expect(model.takeOperationConfirmation() == nil) // original identity, not regenerated copy
    model.withdrawAuthority()
    #expect(model.takeOperationConfirmation() == nil)
}

@Test func settingsConfirmationSnapshotMismatchAndUnsupportedContractAreInert() throws {
    let original = try confirmationFixture()["profile_only_response"] as! [String: Any]
    var value = original
    var confirmation = value["settings_confirmation"] as! [String: Any]
    confirmation["defaults_revision"] = -1; value["settings_confirmation"] = confirmation
    let mismatch = try confirmationDecode(value, as: DJConnectProfileDJSettingsResponse.self)
    #expect(mismatch.settings_confirmation?.validates(mismatch.snapshot) == false)
    var contract = original["settings_confirmation_contract"] as! [String: Any]
    contract["version"] = 2
    #expect(try confirmationDecode(contract, as: DJConnectSettingsConfirmationContract.self).isSupported == false)
}

@Test func settingsConfirmationSpeechIdentityDoesNotAutoplayAgainOnABA() {
    var admission = SessionSpeechAutoplayAdmission()
    _ = admission.observe(sessionID: "session", momentIDs: [], readyIDs: [], enabled: true)
    #expect(admission.observe(sessionID: "session", momentIDs: ["confirmation-A"], readyIDs: ["confirmation-A"], enabled: true) == ["confirmation-A"])
    #expect(admission.observe(sessionID: "session", momentIDs: ["confirmation-B"], readyIDs: ["confirmation-B"], enabled: true) == ["confirmation-B"])
    #expect(admission.observe(sessionID: "session", momentIDs: ["confirmation-A"], readyIDs: ["confirmation-A"], enabled: true).isEmpty)
}

@Test @MainActor func activeSettingsResponseDoesNotManufactureSecondLiveCard() async throws {
    let example = try confirmationFixture()["examples"] as! [[String: Any]]
    let original = example[0]["response"] as! [String: Any]
    let read = try confirmationDecode(original, as: DJConnectProfileDJSettingsResponse.self)
    let model = ProfileDJSettingsModel(); model.bind(owner: "fixture-owner", active: true)
    let services = ProfileDJSettingsModel.Services(read: { read }, update: { _, _, id in
        var accepted = original; accepted["operation_id"] = id
        return try confirmationDecode(accepted, as: DJConnectProfileDJSettingsResponse.self)
    }, receipt: { _, _ in throw CancellationError() })
    await model.refresh(services)
    _ = await model.change(.init(mood: "party"), using: services)
    #expect(model.takeOperationConfirmation() == nil)
}

@Test func settingsConfirmationCapabilityRequiresExactAdvertisedVersion() throws {
    for version in [0, 1, 2] {
        let value: [String: Any] = ["capabilities": ["settings_confirmation_moment": true],
            "contract_versions": ["settings_confirmation_moment": version]]
        let caps = try confirmationDecode(value, as: DJConnectActiveMoodCapabilities.self)
        #expect(caps.settingsConfirmationAvailable == (version == 1))
    }
}

@Test @MainActor func lostSettingsReplyUsesOriginalReceiptWithoutRepeatingWrite() async throws {
    let original = try confirmationFixture()["profile_only_response"] as! [String: Any]
    let read = try confirmationDecode(original, as: DJConnectProfileDJSettingsResponse.self)
    let model = ProfileDJSettingsModel(); model.bind(owner: "fixture-owner", active: true)
    var writes = 0, receipts = 0
    let services = ProfileDJSettingsModel.Services(read: { read }, update: { _, _, _ in
        writes += 1; throw CancellationError()
    }, receipt: { _, id in
        receipts += 1
        let receipt: [String: Any] = ["accepted": true, "operation_id": id,
            "snapshot": original["snapshot"]!, "expires_ms": original["expires_ms"]!,
            "settings_confirmation": original["settings_confirmation"]!]
        return try confirmationDecode(["success": true, "contract_version": 3, "phase": "accepted",
            "cache_policy": "private,no-store", "receipt": receipt], as: DJConnectProfileDJSettingsOperation.self)
    })
    await model.refresh(services)
    _ = await model.change(.init(mood: read.snapshot.effective.mood), using: services)
    #expect(writes == 1 && receipts == 1)
    #expect(model.takeOperationConfirmation()?.confirmation_id == read.settings_confirmation?.confirmation_id)
    _ = await model.reconcile(services)
    #expect(model.takeOperationConfirmation() == nil)
    #expect(writes == 1 && receipts == 1)
}
