import Foundation
import Combine
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

private func settingsFixture(_ name: String, operationID: String? = nil) throws -> DJConnectProfileDJSettingsResponse {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/profile-settings3-core-1329ad1.json")
    let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let cases = try #require(root["cases"] as? [[String: Any]])
    var response = try #require(cases.first(where: { $0["case"] as? String == name })?["response"] as? [String: Any])
    if let operationID { response["operation_id"] = operationID }
    return try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self, from: JSONSerialization.data(withJSONObject: response))
}
private let noSessionSettingsCase = "paired_no_session_all_five"
private let activeSettingsCase = "active_atomic_all_five_and_replay"

@Test @MainActor func voiceMenuIgnoresClockRefreshButUpdatesForTextOnlyAndWithdrawal() async throws {
    let model = ProfileDJSettingsModel(); model.bind(owner: "ProfileA", active: true)
    var current = try settingsFixture(noSessionSettingsCase)
    let services = ProfileDJSettingsModel.Services(read: { current }, update: { _, _, _ in throw CancellationError() },
        receipt: { _, _ in throw CancellationError() })
    await model.refresh(services)
    let presentation = ProfileDJSettingsEditorState(model)
    var publications = 0
    let observation = presentation.$value.dropFirst().sink { _ in publications += 1 }
    defer { observation.cancel() }
    for second in 0..<20 {
        var value = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any])
        value["as_of"] = String(format: "2026-10-17T14:00:%02dZ", second)
        current = try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self, from: JSONSerialization.data(withJSONObject: value))
        await model.refresh(services)
        for _ in 0..<4 { await Task.yield() }
        #expect(model.response?.as_of == current.as_of) // writes keep the fresh producer clock
        #expect(presentation.value.canEdit)
    }
    #expect(publications == 0)
    current = try settingsFixture("text_only_zero_synthesis_old_audio_denied_and_owner_controls_removed")
    await model.refresh(services)
    for _ in 0..<4 { await Task.yield() }
    #expect(publications == 1 && presentation.value.response?.snapshot.effective.announcement_output == .textOnly)
    current = try settingsFixture("automatic_mood_default_preserved_and_provider_withdrawal")
    await model.refresh(services)
    for _ in 0..<4 { await Task.yield() }
    #expect(publications == 2 && presentation.value.response?.voice_availability.available == false)
    model.withdrawAuthority()
    for _ in 0..<4 { await Task.yield() }
    #expect(publications == 3 && presentation.value.response == nil && !presentation.value.canEdit)
}

@Test(arguments: [false, true]) @MainActor
func voiceChoiceDuringFreshnessReadFencesLateSnapshotOrRejection(rejectLateRead: Bool) async throws {
    let model = ProfileDJSettingsModel(); model.bind(owner: "ProfileA", active: true)
    let old = try settingsFixture(noSessionSettingsCase)
    var current = old
    var reads = 0, writes = 0
    var completion: CheckedContinuation<DJConnectProfileDJSettingsResponse, Error>?
    let services = ProfileDJSettingsModel.Services(read: {
        reads += 1
        if reads == 2 { return try await withCheckedThrowingContinuation { completion = $0 } }
        return current
    }, update: { original, patch, id in
        writes += 1
        #expect(original == old && patch.mood == "party")
        current = try settingsFixture(activeSettingsCase, operationID: id)
        return current
    }, receipt: { _, _ in throw CancellationError() })
    await model.refresh(services)
    let refresh = Task { await model.refresh(services) }
    while completion == nil { await Task.yield() }
    #expect(model.canEdit && model.phase == .ready)
    await model.change(.init(mood: "party"), using: services)
    #expect(writes == 1 && model.effective?.mood == "party")
    if rejectLateRead { completion?.resume(throwing: DJConnectError.authStale(statusCode: 401, message: nil)) }
    else { completion?.resume(returning: old) }
    await refresh.value
    #expect(model.canEdit && model.active && model.phase == .saved && model.effective?.mood == "party")
}

@Test @MainActor func voiceChoiceWaitsForCurrentMutationReadbackBeforeAnotherWrite() async throws {
    let model = ProfileDJSettingsModel(); model.bind(owner: "ProfileA", active: true)
    var current = try settingsFixture(noSessionSettingsCase)
    var reads = 0, writes = 0
    var completion: CheckedContinuation<DJConnectProfileDJSettingsResponse, Error>?
    let services = ProfileDJSettingsModel.Services(read: {
        reads += 1
        if reads == 2 { return try await withCheckedThrowingContinuation { completion = $0 } }
        return current
    }, update: { _, _, id in
        writes += 1; current = try settingsFixture(activeSettingsCase, operationID: id); return current
    }, receipt: { _, _ in throw CancellationError() })
    await model.refresh(services)
    let save = Task { await model.change(.init(mood: "party"), using: services) }
    while completion == nil { await Task.yield() }
    #expect(!model.canEdit)
    await model.change(.init(mood: "chill"), using: services)
    #expect(writes == 1)
    completion?.resume(returning: current)
    await save.value
    #expect(model.canEdit && model.effective?.mood == "party" && writes == 1)
}

@Test @MainActor func voiceMenuIdentityIgnoresUnrelatedPlaybackTicks() throws {
    let suite = "voice-menu-identity-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    let before = ProfileDJSettingsEditor(model: model)
    model.playback = DJConnectPlayback(trackName: "Another track", progressMS: 1000)
    #expect(before == ProfileDJSettingsEditor(model: model))
    model.language = model.language == "en" ? "nl" : "en"
    #expect(before != ProfileDJSettingsEditor(model: model))
}
private func settingsOperation(_ phase: String, id: String) throws -> DJConnectProfileDJSettingsOperation {
    var value: [String: Any] = ["success": true, "contract_version": 3, "phase": phase, "cache_policy": "private,no-store", "operation_id": id]
    if phase == "accepted" {
        let fixture = try settingsFixture(activeSettingsCase, operationID: id)
        // Receipt carries a historical snapshot; tests ensure it never becomes current state.
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/profile-settings3-core-1329ad1.json")
        let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let cases = try #require(root["cases"] as? [[String: Any]])
        let response = try #require(cases.first(where: { $0["case"] as? String == activeSettingsCase })?["response"] as? [String: Any])
        value["receipt"] = ["accepted": true, "operation_id": id, "expires_ms": fixture.expires_ms!, "snapshot": response["snapshot"]!]
    }
    return try JSONDecoder().decode(DJConnectProfileDJSettingsOperation.self, from: JSONSerialization.data(withJSONObject: value))
}

@Test @MainActor func choiceBurstCoalescesLastValuePerFieldBeforeOneSend() async throws {
    let scheduler = ProfileDJChoiceScheduler()
    var sent: [DJConnectProfileDJSettings.Patch] = []
    var pending: [Bool] = []
    scheduler.pendingChanged = { pending.append($0) }
    let perform: (DJConnectProfileDJSettings.Patch) async -> Void = { sent.append($0) }
    for index in 0..<30 {
        scheduler.schedule(.init(mood: index == 29 ? "party" : "chill"), context: "A", isCurrent: { true }, perform: perform)
        scheduler.schedule(.init(presence: .presenter), context: "A", isCurrent: { true }, perform: perform)
        scheduler.schedule(.init(persona: .clubDJ), context: "A", isCurrent: { true }, perform: perform)
    }
    #expect(scheduler.hasPending && sent.isEmpty)
    try await Task.sleep(for: .milliseconds(350))
    #expect(sent == [.init(persona: .clubDJ, mood: "party", presence: .presenter)])
    #expect(!scheduler.hasPending && pending == [true, false])
}

@Test @MainActor func queuedChoiceDropsOnScopeChangeAndDoesNotMergePreviousOwner() async throws {
    let scheduler = ProfileDJChoiceScheduler()
    var current = true
    var sent: [DJConnectProfileDJSettings.Patch] = []
    let perform: (DJConnectProfileDJSettings.Patch) async -> Void = { sent.append($0) }
    scheduler.schedule(.init(persona: .clubDJ), context: "A", isCurrent: { current }, perform: perform)
    current = false
    try await Task.sleep(for: .milliseconds(350))
    #expect(sent.isEmpty && !scheduler.hasPending)
    scheduler.schedule(.init(persona: .clubDJ), context: "A", isCurrent: { false }, perform: perform)
    scheduler.schedule(.init(mood: "party"), context: "B", isCurrent: { true }, perform: perform)
    try await Task.sleep(for: .milliseconds(350))
    #expect(sent == [.init(mood: "party")])
}

@Test(arguments: [false, true]) @MainActor
func confirmedSettingsReadClearsStickyConflictButReturnsRealRejection(readFails: Bool) async throws {
    let model = ProfileDJSettingsModel(); model.bind(owner: "A", active: true)
    let current = try settingsFixture(noSessionSettingsCase)
    var reads = 0, writes = 0
    let rejection = try JSONDecoder().decode(DJConnectProfileDJSettingsFailure.self,
        from: Data(#"{"error":"settings_revision_conflict"}"#.utf8))
    let services = ProfileDJSettingsModel.Services(read: {
        reads += 1
        if reads > 1 && readFails { throw URLError(.timedOut) }
        return current
    }, update: { _, _, _ in writes += 1; throw rejection }, receipt: { _, _ in throw CancellationError() })
    await model.refresh(services)
    let result = await model.change(.init(mood: "party"), using: services)
    #expect(result == rejection && writes == 1)
    if readFails {
        #expect(model.phase == .unavailable && !model.canEdit)
    } else {
        #expect(model.phase == .ready && model.errorCode == nil && model.canEdit)
        await model.refresh(services)
        #expect(model.phase == .ready && model.errorCode == nil && writes == 1)
    }
}

@Test @MainActor func rejectedReceiptIsReportedOnceWithoutReplayingOrStickyConflict() async throws {
    let model = ProfileDJSettingsModel(); model.bind(owner: "A", active: true)
    let current = try settingsFixture(noSessionSettingsCase)
    var writes = 0, receipts = 0
    let services = ProfileDJSettingsModel.Services(read: { current }, update: { _, _, _ in
        writes += 1; throw URLError(.timedOut)
    }, receipt: { _, id in receipts += 1; return try settingsOperation("not_accepted", id: id) })
    await model.refresh(services)
    let rejection = await model.change(.init(mood: "party"), using: services)
    #expect(rejection?.error == "settings_not_accepted")
    #expect(model.phase == .ready && model.errorCode == nil && model.canEdit)
    let duplicate = await model.reconcile(services)
    #expect(duplicate == nil && writes == 1 && receipts == 1)
}

@Suite("Profile settings3") struct ProfileDJSettingsContractTests {
    @Test func exactProducerSnapshotsAndUnavailableChoices() throws {
        let initial = try settingsFixture("ordinary_legacy_HTTP_start_unknown_mood_askdj1_prepare1_settings_read")
        #expect(initial.isValid && initial.requiresSelection)
        #expect(initial.snapshot.session?.settings == nil)
        #expect(initial.snapshot.defaults.mood == "groove") // proposal, never invented active Mood
        for name in [noSessionSettingsCase, "accepted_legacy_retirement_preserves_binding_and_defaults", activeSettingsCase,
                     "automatic_mood_default_preserved_and_provider_withdrawal", "text_only_zero_synthesis_old_audio_denied_and_owner_controls_removed"] {
            #expect(try settingsFixture(name).isValid)
        }
        let withdrawn = try settingsFixture("automatic_mood_default_preserved_and_provider_withdrawal")
        #expect(!withdrawn.voice_availability.available)
        #expect(withdrawn.snapshot.effective.voice.voice_id == "GuyNeural")
        let textOnly = try settingsFixture("text_only_zero_synthesis_old_audio_denied_and_owner_controls_removed")
        #expect(textOnly.snapshot.effective.announcement_output == .textOnly)
        #expect(textOnly.snapshot.effective.voice.voice_id == "GuyNeural")
    }

    @Test func patchContainsOnlyExplicitFieldsAndFullReviewIsSix() throws {
        let patch = DJConnectProfileDJSettings.Patch(mood: "party")
        let data = try JSONEncoder().encode(patch)
        let dict = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(dict.keys) == ["mood"])
        #expect(patch.isValid && !patch.isComplete)
        #expect(DJConnectProfileDJSettings.Patch(try settingsFixture(noSessionSettingsCase).snapshot.defaults).isComplete)
        #expect(!DJConnectProfileDJSettings.Patch(mood: "invented").isValid)
    }

    @Test @MainActor func noSessionEditUsesOneAtomicWriteAndCurrentRead() async throws {
        let model = ProfileDJSettingsModel(); model.bind(owner: "ProfileA-device", active: true)
        var current = try settingsFixture(noSessionSettingsCase)
        var writes = 0
        let services = ProfileDJSettingsModel.Services(read: { current }, update: { original, patch, id in
            writes += 1
            #expect(original.snapshot.session == nil)
            #expect(patch.mood == "party" && patch.persona == nil)
            current = try settingsFixture(activeSettingsCase, operationID: id)
            return current
        }, receipt: { _, id in try settingsOperation("unknown", id: id) })
        await model.refresh(services)
        #expect(model.effective?.mood == "energy")
        await model.change(.init(mood: "party"), using: services)
        #expect(writes == 1 && model.phase == .saved)
        #expect(model.effective?.mood == "party")
    }

    @Test @MainActor func lostReplyReadsReceiptWithoutReplayingPatch() async throws {
        let model = ProfileDJSettingsModel(); model.bind(owner: "ProfileA", active: true)
        var current = try settingsFixture(noSessionSettingsCase)
        var writes = 0, receipts = 0
        let services = ProfileDJSettingsModel.Services(read: { current }, update: { _, _, id in
            writes += 1; current = try settingsFixture(activeSettingsCase, operationID: id)
            throw URLError(.timedOut)
        }, receipt: { _, id in receipts += 1; return try settingsOperation("accepted", id: id) })
        await model.refresh(services)
        await model.change(.init(presence: .musicOnly), using: services)
        #expect(writes == 1 && receipts == 1 && model.phase == .saved)
        #expect(model.effective?.presence == .musicOnly)
    }

    @Test @MainActor func expiredUnknownOutcomeStaysUnknownAndNeverResends() async throws {
        let model = ProfileDJSettingsModel(); model.bind(owner: "ProfileA", active: true)
        let current = try settingsFixture(noSessionSettingsCase)
        var writes = 0
        let services = ProfileDJSettingsModel.Services(read: { current }, update: { _, _, _ in
            writes += 1; throw URLError(.networkConnectionLost)
        }, receipt: { _, id in try settingsOperation("unknown", id: id) })
        await model.refresh(services)
        await model.change(.init(mood: "party"), using: services)
        await model.change(.init(mood: "chill"), using: services)
        #expect(writes == 1 && model.hasUncertainOperation && !model.canEdit)
        await model.useCurrentSettings(services)
        #expect(model.phase == .ready && model.canEdit && writes == 1)
    }

    @Test @MainActor func ownerABALateReadCannotRestoreOldProfile() async throws {
        let model = ProfileDJSettingsModel(); model.bind(owner: "ProfileA", active: true)
        let current = try settingsFixture(noSessionSettingsCase)
        var continuation: CheckedContinuation<DJConnectProfileDJSettingsResponse, Error>?
        let services = ProfileDJSettingsModel.Services(read: {
            try await withCheckedThrowingContinuation { continuation = $0 }
        }, update: { _, _, _ in current }, receipt: { _, id in try settingsOperation("unknown", id: id) })
        let task = Task { await model.refresh(services) }
        while continuation == nil { await Task.yield() }
        model.bind(owner: "ProfileB", active: true)
        model.bind(owner: "ProfileA", active: true)
        continuation?.resume(returning: current)
        await task.value
        #expect(model.response == nil && !model.negotiated)
    }

    @Test @MainActor func migrationPartialPatchDoesNotWriteOrActivate() async throws {
        let model = ProfileDJSettingsModel(); model.bind(owner: "ProfileA", active: true)
        let current = try settingsFixture("ordinary_legacy_HTTP_start_unknown_mood_askdj1_prepare1_settings_read")
        var writes = 0
        let services = ProfileDJSettingsModel.Services(read: { current }, update: { _, _, _ in writes += 1; return current },
            receipt: { _, id in try settingsOperation("unknown", id: id) })
        await model.refresh(services)
        await model.change(.init(mood: "party"), using: services)
        #expect(writes == 0 && model.response?.requiresSelection == true)
    }
    @Test @MainActor func backgroundDuringSaveReconcilesOriginalOperationWithoutReplay() async throws {
        let model = ProfileDJSettingsModel(); model.bind(owner: "ProfileA", active: true)
        var current = try settingsFixture(noSessionSettingsCase)
        var completion: CheckedContinuation<DJConnectProfileDJSettingsResponse, Error>?
        var operationID: String?; var writes = 0; var receipts = 0
        let services = ProfileDJSettingsModel.Services(read: { current }, update: { _, _, id in
            operationID = id; writes += 1
            return try await withCheckedThrowingContinuation { completion = $0 }
        }, receipt: { _, id in
            receipts += 1; #expect(id == operationID)
            return try settingsOperation("accepted", id: id)
        })
        await model.refresh(services)
        let saving = Task { await model.change(.init(mood: "party"), using: services) }
        while completion == nil { await Task.yield() }
        model.bind(owner: "ProfileA", active: false)
        #expect(model.phase == .uncertain && !model.canEdit)
        current = try settingsFixture(activeSettingsCase, operationID: operationID)
        completion?.resume(returning: current)
        await saving.value
        model.bind(owner: "ProfileA", active: true)
        await model.refresh(services)
        #expect(model.hasUncertainOperation) // Same values alone are not an operation receipt.
        await model.reconcile(services)
        #expect(writes == 1 && receipts == 1 && model.phase == .saved && model.canEdit)
        #expect(model.effective?.mood == "party")
    }

    @Test @MainActor func malformedReadLeavesLoadingAndCannotBecomeEditable() async throws {
        let model = ProfileDJSettingsModel(); model.bind(owner: "ProfileA", active: true)
        var object = try #require(JSONSerialization.jsonObject(with: settingsRawFixture(noSessionSettingsCase)) as? [String: Any])
        object["cache_policy"] = "public"
        let invalid = try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self, from: JSONSerialization.data(withJSONObject: object))
        let services = ProfileDJSettingsModel.Services(read: { invalid }, update: { _, _, _ in invalid },
            receipt: { _, id in try settingsOperation("unknown", id: id) })
        await model.refresh(services)
        #expect(model.phase == .unavailable && model.response == nil && !model.canEdit)
    }

}

private final class SettingsWire: @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var wires: [String: SettingsWire] = [:]
    let host = UUID().uuidString.lowercased() + ".invalid"
    let handler: @Sendable (URLRequest) throws -> (Int, Data)
    let mimeType: String
    init(mimeType: String = "application/json", _ handler: @escaping @Sendable (URLRequest) throws -> (Int, Data)) {
        self.handler = handler
        self.mimeType = mimeType
        Self.lock.withLock { Self.wires[host] = self }
    }
    func close() { Self.lock.withLock { Self.wires.removeValue(forKey: host) } }
    func client() -> DJConnectClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SettingsURLProtocol.self]
        return DJConnectClient(baseURL: URL(string: "https://" + host)!,
            identity: .init(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Settings test", clientType: .ios, firmware: "4.0.0", platform: .ios),
            tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-settings-token"), session: URLSession(configuration: configuration))
    }
}
private final class SettingsURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { SettingsWire.lock.withLock { SettingsWire.wires[request.url?.host ?? ""] != nil } }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let wire = SettingsWire.lock.withLock({ SettingsWire.wires[request.url?.host ?? ""] }) else { return }
        do {
            let (status, data) = try wire.handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": wire.mimeType, "Content-Length": String(data.count)])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@Test @MainActor func settingsColdStartDoesNotRequireConversationHistoryCapabilityOrRead() async throws {
    let raw = try settingsRawFixture(noSessionSettingsCase)
    let wire = SettingsWire { request in
        switch request.url?.path {
        case "/api/djconnect/v1/capabilities":
            return (200, Data(#"{"capabilities":{"profile_session_settings":true},"contract_versions":{"profile_session_settings":3}}"#.utf8))
        case "/api/djconnect/v1/profile/settings": return (200, raw)
        default:
            Issue.record("Settings startup made an unrelated request")
            throw DJConnectError.invalidResponse
        }
    }
    defer { wire.close() }
    let suite = "settings-startup-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set("https://" + wire.host, forKey: "DJConnectHomeAssistantURL")
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [SettingsURLProtocol.self]
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(token: "fixture-only"),
        urlSession: URLSession(configuration: config), startBackgroundTasks: false)
    await model.refreshProfileDJSettings()
    #expect(model.profileDJSettings.negotiated)
    #expect(model.profileDJSettings.effective == (try settingsFixture(noSessionSettingsCase)).snapshot.effective)
    #expect(!model.sessionHistory.hasAuthorizedOwner && !model.sessionHistory.profileScopeActive)
    let before = model.profileDJSettings.response
    model.bindProfileDJSettings(active: false)
    model.bindProfileDJSettings(active: true)
    #expect(model.profileDJSettings.response == before)
}

@Test func settingsOwnerFenceIgnoresHistoryAvailabilityButFencesRealProfileAndPairingABA() throws {
    var fence = DJConnectProfileSettingsOwnerFence()
    let absent = fence.owner(context: nil, confirmedProfile: nil)
    #expect(absent == nil)
    let candidate = fence.owner(context: "paired-device-installation", confirmedProfile: nil)
    let first = try #require(candidate)
    let learned = fence.owner(context: "paired-device-installation", confirmedProfile: "profile-a")
    let suspended = fence.owner(context: "paired-device-installation", confirmedProfile: nil)
    #expect(learned == first && suspended == first)
    let second = fence.owner(context: "paired-device-installation", confirmedProfile: "profile-b")
    let third = fence.owner(context: "paired-device-installation", confirmedProfile: "profile-a")
    #expect(first != second && first != third && second != third)
    let cleared = fence.owner(context: nil, confirmedProfile: nil)
    let rebound = fence.owner(context: "paired-device-installation", confirmedProfile: "profile-a")
    #expect(cleared == nil && rebound != third)
}

@Test @MainActor func settingsRevocationRetainsUncertaintyButAChangedServerBindingCannotReplayIt() async throws {
    let initial = try settingsFixture(noSessionSettingsCase)
    var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(initial)) as? [String: Any])
    json["binding"] = String(repeating: initial.binding.first == "a" ? "b" : "a", count: 64)
    let changed = try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self, from: JSONSerialization.data(withJSONObject: json))
    var current = initial
    var writes = 0
    let services = ProfileDJSettingsModel.Services(read: { current }, update: { _, _, _ in
        writes += 1; throw URLError(.timedOut)
    }, receipt: { _, _ in throw URLError(.cannotConnectToHost) })
    let model = ProfileDJSettingsModel(); model.bind(owner: "paired-context", active: true)
    await model.refresh(services)
    await model.change(.init(mood: "groove"), using: services)
    #expect(model.hasUncertainOperation && writes == 1)
    model.withdrawAuthority()
    model.bind(owner: "paired-context", active: true)
    current = changed
    await model.refresh(services)
    #expect(model.response?.binding == changed.binding)
    #expect(!model.hasUncertainOperation && writes == 1)
    #expect(model.errorCode == "settings_binding_changed")
}
private func settingsRequestBody(_ request: URLRequest) throws -> [String: Any] {
    var data = request.httpBody ?? Data()
    if data.isEmpty, let stream = request.httpBodyStream {
        stream.open(); defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
    }
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}
private func settingsRawFixture(_ name: String, operationID: String? = nil) throws -> Data {
    let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/profile-settings3-core-1329ad1.json")
    let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
    let cases = try #require(root["cases"] as? [[String: Any]])
    var response = try #require(cases.first(where: { $0["case"] as? String == name })?["response"] as? [String: Any])
    if let operationID { response["operation_id"] = operationID }
    return try JSONSerialization.data(withJSONObject: response)
}

extension ProfileDJSettingsContractTests {
    @Test func HTTPReadHasExactOwnerQueryAndNoCache() async throws {
        let fixture = try settingsRawFixture(noSessionSettingsCase)
        let wire = SettingsWire { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path == "/api/djconnect/v1/profile/settings")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            #expect(Set(query.map(\.name)) == ["contract_version", "device_id", "client_type"])
            #expect(query.first(where: { $0.name == "contract_version" })?.value == "3")
            #expect(request.value(forHTTPHeaderField: "Cache-Control") == "no-store")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-settings-token")
            #expect(request.httpBody == nil)
            return (200, fixture)
        }
        defer { wire.close() }
        let result = try await wire.client().profileDJSettings()
        #expect(result.isValid && result.snapshot.session == nil)
    }

    @Test func HTTPPatchSendsExplicitNullSessionAndOnlyOneField() async throws {
        let current = try settingsFixture(noSessionSettingsCase)
        let id = DJConnectOperationIdentity.uuidV7(milliseconds: 1_792_178_000_000)
        let reply = try settingsRawFixture(activeSettingsCase, operationID: id)
        let wire = SettingsWire { request in
            #expect(request.httpMethod == "PATCH")
            let body = try settingsRequestBody(request)
            #expect(Set(body.keys) == ["contract_version", "device_id", "client_type", "binding", "operation_id", "patch", "expected_defaults_revision", "expected_session"])
            #expect(body["expected_session"] is NSNull)
            #expect(body["binding"] as? String == current.binding)
            #expect((body["patch"] as? [String: String]) == ["mood": "party"])
            #expect(body["device_token"] == nil && body["profile_id"] == nil)
            return (200, reply)
        }
        defer { wire.close() }
        _ = try await wire.client().updateProfileDJSettings(current, patch: .init(mood: "party"), operationID: id)
    }

    @Test func HTTPConflictIsTypedAndDoesNotResend() async throws {
        let wire = SettingsWire { _ in (409, Data(#"{"success":false,"error":"settings_revision_conflict"}"#.utf8)) }
        defer { wire.close() }
        do {
            _ = try await wire.client().updateProfileDJSettings(try settingsFixture(noSessionSettingsCase), patch: .init(mood: "party"), operationID: DJConnectOperationIdentity.uuidV7(milliseconds: 1_792_178_000_000))
            Issue.record("Conflict must not become accepted settings")
        } catch let error as DJConnectProfileDJSettingsFailure { #expect(error.error == "settings_revision_conflict") }
    }

    @Test func textOnlyDisallowsAllSpeechWithoutARequest() async throws {
        let textOnly = try settingsFixture("text_only_zero_synthesis_old_audio_denied_and_owner_controls_removed")
        for target in [DJConnectSharedSpeechTarget.local, .haSpeaker, .both] { #expect(!textOnly.allowsSpeech(target)) }
        let wire = SettingsWire { _ in Issue.record("Text only must make zero speech requests"); return (500, Data()) }
        defer { wire.close() }
        do {
            _ = try await wire.client().prepareSharedDJSpeech(reference: .turn("synthetic-turn"), acceptedText: "Existing text", settings: textOnly)
            Issue.record("Text only must deny preparation")
        } catch { #expect(error is DJConnectError) }
    }
}

private func sharedSpeechFixture(settings: DJConnectProfileDJSettingsResponse, override: [String: Any] = [:]) throws -> (Data, DJConnectSessionSpeech) {
    let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/session-speech-processor-core-323a3db4.json")
    let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
    let cases = try #require(root["cases"] as? [String: Any])
    let ready = try #require(cases["ha_configured_audio"] as? [String: Any])
    var speech = try #require(ready["session_speech"] as? [String: Any])
    speech["expires_at"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(90))
    speech["settings_contract_version"] = 3
    speech["settings_revision"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings.speechFence))
    var voice = try #require(speech["effective_voice"] as? [String: Any])
    voice["engine"] = settings.snapshot.effective.voice.provider_id ?? settings.allowed_values.voice.provider_id
    voice["voice_id"] = settings.snapshot.effective.voice.voice_id
    if settings.snapshot.effective.voice.kind == .providerDefault { voice["voice_selection"] = "provider_default" }
    speech["effective_voice"] = voice
    speech.merge(override) { _, value in value }
    let data = try JSONSerialization.data(withJSONObject: ["success": true, "session_speech": speech])
    let source = try JSONDecoder().decode(DJConnectSessionSpeech.self, from: JSONSerialization.data(withJSONObject: speech))
    return (data, source)
}

extension ProfileDJSettingsContractTests {
    @Test(arguments: [false, true]) func sharedPrepareUsesExactContract3PayloadWithoutVoiceOverrides(automatic: Bool) async throws {
        let settings = try settingsFixture(noSessionSettingsCase)
        let (data, speech) = try sharedSpeechFixture(settings: settings)
        #expect(speech.effectiveVoice?.hasQualifiedSelection == true)
        let wire = SettingsWire { request in
            #expect(request.url?.path == "/api/djconnect/v1/speech/prepare")
            let body = try settingsRequestBody(request)
            #expect(Set(body.keys) == ["contract_version", "device_id", "client_type", "processor", "intent", "target", "reference"])
            #expect(body["contract_version"] as? Int == 3)
            #expect(body["intent"] as? String == (automatic ? "automatic" : "manual") && body["target"] as? String == "local")
            #expect(body["processor"] as? String == "ha_configured")
            #expect(body["text"] == nil && body["voice_id"] == nil && body["voice_preference"] == nil)
            return (200, data)
        }
        defer { wire.close() }
        let text = speech.segments.map(\.text).joined()
        for _ in 0..<2 {
            let result = try await wire.client().prepareSharedDJSpeech(reference: speech.reference, acceptedText: text, settings: settings, automatic: automatic)
            #expect(result.session_speech.settingsRevision == settings.speechFence)
        }
    }

    @Test(arguments: ["fence", "text", "provider", "version"])
    func sharedPrepareRejectsWrongSettingsTextOrProvider(_ fault: String) async throws {
        let settings = try settingsFixture(noSessionSettingsCase)
        var override: [String: Any] = [:]
        if fault == "fence" { override["settings_revision"] = [] }
        if fault == "version" { override["settings_contract_version"] = 2 }
        if fault == "text" { override["segments"] = [["ordinal": 1, "speaker_role": "dj", "text": "Another contribution"]] }
        let (original, source) = try sharedSpeechFixture(settings: settings)
        var (data, _) = try sharedSpeechFixture(settings: settings, override: override)
        if fault == "provider" {
            var object = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
            var speech = try #require(object["session_speech"] as? [String: Any])
            var voice = try #require(speech["effective_voice"] as? [String: Any]); voice["engine"] = "another-provider"
            speech["effective_voice"] = voice; object["session_speech"] = speech
            data = try JSONSerialization.data(withJSONObject: object)
        }
        let reply = data
        let wire = SettingsWire { _ in (200, reply) }; defer { wire.close() }
        await #expect(throws: DJConnectError.invalidResponse) {
            try await wire.client().prepareSharedDJSpeech(reference: source.reference, acceptedText: source.segments.map(\.text).joined(), settings: settings)
        }
    }

    @Test @MainActor func retainedSpeechDeadlineStartsBoundedPlayerInsteadOfSilentlyRefusing() throws {
        let settings = try settingsFixture(noSessionSettingsCase)
        let now = Date()
        let (_, speech) = try sharedSpeechFixture(settings: settings, override: ["expires_at": ISO8601DateFormatter().string(from: now.addingTimeInterval(30 * 86400))])
        let deadline = try #require(speech.playbackDeadline(at: now))
        #expect(deadline == now.addingTimeInterval(300))
        let coordinator = DJConnectAudioPlaybackCoordinator(now: { now }, stopOutput: {})
        let ticket = try #require(coordinator.begin(deadline: deadline))
        #expect(coordinator.isCurrent(ticket))
        // Core issues its asset after the request began. Its fresh 300s grant
        // can exceed the already running local ticket by network/prepare time.
        let preparedExpiry = now.addingTimeInterval(301)
        #expect(coordinator.shortenDeadline(min(preparedExpiry, deadline), for: ticket))
        #expect(coordinator.isCurrent(ticket))
        #expect(coordinator.shortenDeadline(now.addingTimeInterval(60), for: ticket))
        coordinator.finish(ticket)
        #expect(!coordinator.isCurrent(ticket))
    }
}


extension ProfileDJSettingsContractTests {
    @Test(arguments: ["provider_default", "configured"])
    func providerWithoutInventoryRequiresExplicitDefaultEvidence(selection: String) async throws {
        var object = try #require(JSONSerialization.jsonObject(with: settingsRawFixture(noSessionSettingsCase)) as? [String: Any])
        var snapshot = try #require(object["snapshot"] as? [String: Any])
        var defaults = try #require(snapshot["defaults"] as? [String: Any])
        defaults["voice"] = ["kind": "provider_default"]
        snapshot["defaults"] = defaults; object["snapshot"] = snapshot
        let settings = try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self, from: JSONSerialization.data(withJSONObject: object))
        let (data, _) = try sharedSpeechFixture(settings: settings, override: ["effective_voice": [
            "processor": "ha_configured", "engine": "tts.user_server", "provider": "user_server",
            "locale": "en-US", "voice_id": NSNull(), "voice_name": NSNull(), "voice_selection": selection]])
        let speech = try JSONDecoder().decode(DJConnectSharedSpeechResult.self, from: data).session_speech
        let wire = SettingsWire { _ in (200, data) }; defer { wire.close() }
        if selection == "provider_default" {
            let result = try await wire.client().prepareSharedDJSpeech(reference: speech.reference,
                acceptedText: speech.segments.map(\.text).joined(), settings: settings)
            #expect(result.session_speech.effectiveVoice?.voiceID == nil)
            #expect(result.session_speech.effectiveVoice?.hasQualifiedSelection == true)
            // A ready default-voice grant must reach the private byte endpoint;
            // accepting prepare while rejecting its missing voice ID is insufficient.
            var wav = Data("RIFF".utf8)
            func appendLE(_ value: UInt32, bytes: Int) {
                for index in 0..<bytes { wav.append(UInt8(truncatingIfNeeded: value >> (index * 8))) }
            }
            appendLE(38, bytes: 4); wav.append(Data("WAVEfmt ".utf8)); appendLE(16, bytes: 4)
            appendLE(1, bytes: 2); appendLE(1, bytes: 2); appendLE(8000, bytes: 4)
            appendLE(8000, bytes: 4); appendLE(1, bytes: 2); appendLE(8, bytes: 2)
            wav.append(Data("data".utf8)); appendLE(2, bytes: 4); wav.append(contentsOf: [128, 128])
            let audio = wav
            let audioWire = SettingsWire(mimeType: "audio/wav") { request in
                #expect(request.url?.path == "/api/djconnect/v1/speech/audio")
                let body = try settingsRequestBody(request)
                #expect(body["voice_id"] == nil && body["text"] == nil)
                return (200, audio)
            }
            defer { audioWire.close() }
            let bytes = try await audioWire.client().speechAudio(result.session_speech,
                acceptedText: speech.segments.map(\.text).joined())
            #expect(bytes == audio)
        } else {
            await #expect(throws: DJConnectError.invalidResponse) {
                try await wire.client().prepareSharedDJSpeech(reference: speech.reference,
                    acceptedText: speech.segments.map(\.text).joined(), settings: settings)
            }
        }
    }
}

@Test @MainActor func sharedConversationNegotiatesSpeech3AndAutoplayOnlyWhenEnabled() async throws {
    let suite = "autoplay-request-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    let snapshot = try settingsFixture(noSessionSettingsCase)
    model.profileDJSettings.bind(owner: "test-owner", active: true)
    await model.profileDJSettings.refresh(.init(read: { snapshot }, update: { _, _, _ in throw CancellationError() }, receipt: { _, _ in throw CancellationError() }))
    #expect(model.sharedDJSpeechAllowed)
    #expect(snapshot.snapshot.effective.announcement_output.allowsClientAudio)
    for enabled in [false, true] {
        model.localResponseAudioEnabled = enabled
        let payload = model.profileConversationPayload(text: "test", clientMessageID: UUID().uuidString, context: .init(sessionID: nil))
        #expect(payload.speechContractVersion == 3)
        #expect(payload.audioResponse == (enabled ? .always : .never))
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        #expect(encoded["speech_contract_version"] as? Int == 3)
    }
}
