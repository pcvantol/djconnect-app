import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

private func askDJGolden() throws -> [String: Any] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/askdj-catalogue-selector-golden-v1.json")
    return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
}
private func askDJDecode<T: Decodable>(_ type: T.Type, _ value: Any) throws -> T {
    try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: value))
}
private func askDJContext(_ raw: [String: Any]) throws -> DJConnectAskDJCatalogue.Context {
    var context = DJConnectAskDJCatalogue.Context()
    var descriptor = try #require(raw["catalogue"] as? [String: Any])
    // Preserve the historical 70-vector bytes; bind their synthetic descriptor
    // to the current presentation pin without qualifying their draft revision.
    descriptor["sha256"] = DJConnectAskDJCatalogue.pinnedSHA256
    context.descriptor = try askDJDecode(DJConnectAskDJCatalogue.Descriptor.self, descriptor)
    context.contracts = try #require(raw["contracts"] as? [String: Int])
    context.slots = raw["slots"] as? [String: String] ?? [:]
    for (key, value) in raw where value is Bool { context.flags[key] = value as? Bool }
    context.ownerEpoch = "owner-a"
    if context.flags["current_track"] == true { context.trackID = "track-a" }
    if context.flags["active_session"] == true { context.sessionID = "session-a" }
    return context
}

private func fullHelpFixture() throws -> (DJConnectAskDJCatalogue, DJConnectAskDJCatalogue.Context, Set<String>) {
    let raw = try askDJGolden()
    let catalogue = try askDJDecode(DJConnectAskDJCatalogue.self, #require(raw["synthetic_catalogue"]))
    let vector = try #require((raw["cases"] as? [[String: Any]])?.first)
    var context = try askDJContext(#require(vector["context"] as? [String: Any]))
    for entry in catalogue.entries {
        for required in entry.requires { context.flags[required] = true }
        for (key, value) in entry.contracts { context.contracts[key] = value }
    }
    context.sessionID = "session-a"; context.trackID = "track-a"
    context.slots = [:]
    return (catalogue, context, Set(catalogue.entries.map(\.id)))
}

@Test func fullHelpKeepsAllEligibleEntriesAndGenericInputsWithoutChipSlots() throws {
    let (catalogue, context, ids) = try fullHelpFixture()
    for language in ["en", "nl", "de", "fr", "es"] {
        let items = catalogue.catalogueSections(context, surface: .askDJ, language: language, eligibleIDs: ids).flatMap(\.items)
        #expect(items.count == ids.count)
        let artist = try #require(items.first { $0.id == "play.artist" })
        #expect(artist.requiresInput)
        let range = try #require(artist.inputRange)
        #expect((artist.prompt as NSString).substring(with: range).hasPrefix("["))
        #expect(!catalogue.select(context, surface: .askDJ, language: language, epoch: "no-slots").contains { $0.id == artist.id })
        #expect(items.first { $0.id == "listen.current" }?.requiresInput == false)
        #expect(catalogue.catalogueSections(context, surface: .askDJ, language: language, eligibleIDs: []).isEmpty)
        #expect(catalogue.catalogueSections(context, surface: .askDJ, language: language, eligibleIDs: [artist.id]).flatMap(\.items) == [artist])
    }
    let shipped = try #require(DJConnectAskDJCatalogue.bundled)
    #expect(shipped.catalogueSections(context, surface: .askDJ, language: "nl", eligibleIDs: ids).isEmpty)
}

@Test @MainActor func fullHelpReadClosesWithoutProducerAndPreservesOriginalRequestDeadline() async throws {
    let (catalogue, context, ids) = try fullHelpFixture()
    var instant = ContinuousClock.now
    let model = AskDJHelpCatalogueModel(now: { instant })
    let unavailable = await model.read(catalogue: catalogue, surface: .askDJ, language: "nl", context: { context }, reader: nil)
    #expect(unavailable == nil && model.sections.isEmpty)
    let late = await model.read(catalogue: catalogue, surface: .askDJ, language: "nl", context: { context }, reader: { _, _, _, originalDeadline in
        #expect(originalDeadline == instant.advanced(by: .seconds(15)))
        instant = instant.advanced(by: .seconds(15))
        return .init(ids: ids, trackID: context.trackID)
    })
    #expect(late == nil && model.sections.isEmpty && !model.isCurrent)
    let fresh = await model.read(catalogue: catalogue, surface: .askDJ, language: "nl", context: { context }, reader: { _, _, _, _ in .init(ids: ids, trackID: context.trackID) })
    #expect(fresh?.flatMap(\.items).count == ids.count && model.isCurrent)
    instant = instant.advanced(by: .seconds(15))
    #expect(!model.isCurrent)
    model.close()
}

@Test @MainActor func fullHelpInvalidationDuringReadCannotResurrectAnEarlierOwnerOrObservation() async throws {
    let (catalogue, initial, ids) = try fullHelpFixture()
    var context = initial
    let model = AskDJHelpCatalogueModel()
    let changed = await model.read(catalogue: catalogue, surface: .session, language: "en", context: { context }, reader: { _, _, _, _ in
        context.ownerEpoch = "other-owner"
        return .init(ids: ids, trackID: context.trackID)
    })
    #expect(changed == nil && model.sections.isEmpty)
    context = initial
    let aba = await model.read(catalogue: catalogue, surface: .session, language: "en", context: { context }, reader: { _, _, _, _ in
        model.close()
        return .init(ids: ids, trackID: context.trackID)
    })
    #expect(aba == nil && model.sections.isEmpty)
}

@Test @MainActor func fullHelpFailedFreshClickReadCannotRetainPreviousPositiveObservation() async throws {
    let (catalogue, context, ids) = try fullHelpFixture()
    let model = AskDJHelpCatalogueModel()
    _ = await model.read(catalogue: catalogue, surface: .askDJ, language: "en", context: { context }, reader: { _, _, _, _ in .init(ids: ids, trackID: context.trackID) })
    #expect(model.isCurrent && !model.sections.isEmpty)
    let failed = await model.read(catalogue: catalogue, surface: .askDJ, language: "en", context: { context }, reader: { _, _, _, _ in
        throw URLError(.notConnectedToInternet)
    })
    #expect(failed == nil && !model.isCurrent && model.sections.isEmpty && !model.busy)
}

@Test @MainActor func fullHelpNullProducerTrackKeepsGenericArtistDraftButCannotFillChipsFromLocalMetadata() async throws {
    let (catalogue, initial, ids) = try fullHelpFixture()
    var context = initial; context.slots["artist"] = "Original observed artist"
    #expect(context.trackID != nil && context.slots["artist"] != nil)
    let model = AskDJHelpCatalogueModel()
    let sections = await model.read(catalogue: catalogue, surface: .askDJ, language: "en", context: { context },
        reader: { _, _, _, _ in .init(ids: ids, trackID: nil) })
    let admitted = try #require(model.admittedContext)
    #expect(admitted.trackID == nil && admitted.slots.isEmpty)
    #expect(sections?.flatMap(\.items).contains(where: { $0.id == "play.artist" && $0.requiresInput }) == true)
    #expect(!catalogue.select(admitted, surface: .askDJ, language: "en", epoch: "null-track").contains(where: { $0.id == "play.artist" }))
    #expect(sections?.flatMap(\.items).contains(where: { $0.id == "listen.current" }) == false)
}

@MainActor private final class HelpPendingReadGate {
    var continuation: CheckedContinuation<AskDJHelpCatalogueModel.Observation, Never>?
    func wait() async -> AskDJHelpCatalogueModel.Observation {
        await withCheckedContinuation { continuation = $0 }
    }
}

@Test @MainActor func fullHelpObservedBusyContextABANeverReadmitsTheOriginalReply() async throws {
    let (catalogue, original, ids) = try fullHelpFixture()
    for kind in ["artist", "album", "capabilities", "settings", "owner"] {
        var context = original
        context.slots["artist"] = "Artist A"
        let captured = context, model = AskDJHelpCatalogueModel(), gate = HelpPendingReadGate()
        let task = Task { await model.read(catalogue: catalogue, surface: .askDJ, language: "en", context: { context },
            reader: { _, _, _, _ in await gate.wait() }) }
        for _ in 0..<1000 { if gate.continuation != nil { break }; await Task.yield() }
        let continuation = try #require(gate.continuation)
        #expect(model.busy)
        switch kind {
        case "artist": context.slots["artist"] = "Artist B"
        case "album": context.flags["current_album"] = false
        case "capabilities": context.contracts["ask_dj_examples"] = 99
        case "settings": context.settingsIdentity = "new observed settings"
        default: context.ownerEpoch = "new-owner"
        }
        model.contextChanged(to: context) // Retirement applies while reader is pending.
        context = captured
        model.contextChanged(to: context)
        continuation.resume(returning: .init(ids: ids, trackID: context.trackID))
        let result = await task.value
        #expect(result == nil && model.sections.isEmpty && model.admittedContext == nil)
    }
}

@Test @MainActor func fullHelpOwnCapturedContextPublicationDoesNotCancelItsRead() async throws {
    let (catalogue, context, ids) = try fullHelpFixture()
    let model = AskDJHelpCatalogueModel(), gate = HelpPendingReadGate()
    let task = Task { await model.read(catalogue: catalogue, surface: .askDJ, language: "en", context: { context },
        reader: { _, _, _, _ in await gate.wait() }) }
    for _ in 0..<1000 { if gate.continuation != nil { break }; await Task.yield() }
    let continuation = try #require(gate.continuation)
    model.contextChanged(to: context) // Delayed view callback for already-captured discovery.
    #expect(model.busy)
    continuation.resume(returning: .init(ids: ids, trackID: context.trackID))
    let result = await task.value
    #expect(result?.isEmpty == false && !model.sections.isEmpty)
    model.contextChanged(to: context) // Published admitted mask is not the base context.
    #expect(!model.sections.isEmpty && model.isCurrent)
    model.close()
}

@Test @MainActor func fullHelpRetiredBusyReplyCannotClearANewerSuccessfulRead() async throws {
    let (catalogue, original, ids) = try fullHelpFixture()
    var context = original
    let model = AskDJHelpCatalogueModel(), gate = HelpPendingReadGate()
    let old = Task { await model.read(catalogue: catalogue, surface: .askDJ, language: "en", context: { context }, reader: { _, _, _, _ in await gate.wait() }) }
    for _ in 0..<1000 { if gate.continuation != nil { break }; await Task.yield() }
    let continuation = try #require(gate.continuation)
    context.ownerEpoch = "new-owner"
    model.contextChanged(to: context)
    let fresh = await model.read(catalogue: catalogue, surface: .askDJ, language: "en", context: { context }, reader: { _, _, _, _ in .init(ids: ids, trackID: context.trackID) })
    #expect(fresh?.isEmpty == false)
    continuation.resume(returning: .init(ids: ids, trackID: original.trackID))
    let retired = await old.value
    #expect(retired == nil && !model.sections.isEmpty && model.admittedContext?.ownerEpoch == "new-owner")
    model.close()
}

@Test @MainActor func fullHelpCancellationReachesOwnedReaderAndLateCompletionCannotPublish() async throws {
    let (catalogue, context, ids) = try fullHelpFixture()
    let model = AskDJHelpCatalogueModel(), gate = HelpPendingReadGate()
    var childCancelled = false
    let task = Task { await model.read(catalogue: catalogue, surface: .askDJ, language: "en", context: { context }, reader: { _, _, _, _ in
        let value = await gate.wait(); childCancelled = Task.isCancelled; return value
    }) }
    for _ in 0..<1000 { if gate.continuation != nil { break }; await Task.yield() }
    let continuation = try #require(gate.continuation)
    task.cancel()
    continuation.resume(returning: .init(ids: ids, trackID: context.trackID))
    let result = await task.value
    #expect(result == nil && childCancelled && model.sections.isEmpty)
}

@Test @MainActor func fullHelpDelayedOwnedChildChecksOriginalDeadlineBeforeCallingReader() async throws {
    let (catalogue, context, ids) = try fullHelpFixture()
    let started = ContinuousClock.now
    var clockCalls = 0, readerCalls = 0
    let model = AskDJHelpCatalogueModel(now: {
        clockCalls += 1
        return started.advanced(by: .seconds(clockCalls == 1 ? 0 : 15))
    })
    let result = await model.read(catalogue: catalogue, surface: .askDJ, language: "en", context: { context }, reader: { _, _, _, _ in
        readerCalls += 1; return .init(ids: ids, trackID: context.trackID)
    })
    #expect(result == nil && readerCalls == 0 && model.sections.isEmpty)
}

@Test @MainActor func helpActualAppModelBackendCapabilityABARetiresTheOldGeneration() throws {
    let name = "help-backend-aba-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(token: nil), startBackgroundTasks: false)
    var summary = DJConnectMusicBackendSummary(musicBackend: "spotify_direct", musicBackendRevision: 3,
        musicBackendCapabilities: .init(supportsSearch: true, supportsQueue: true))
    model.apply(musicBackendSummary: summary)
    let original = model.askDJExampleContext().ownerEpoch
    model.apply(musicBackendSummary: summary)
    #expect(model.askDJExampleContext().ownerEpoch == original)
    summary.musicBackendCapabilities?.supportsSearch = false; model.apply(musicBackendSummary: summary)
    summary.musicBackendCapabilities?.supportsSearch = true; model.apply(musicBackendSummary: summary)
    #expect(model.askDJExampleContext().ownerEpoch != original)
}

@Test @MainActor func helpActualAppModelSameTrackMetadataAndFreshnessRetireButProgressDoesNot() throws {
    let name = "help-playback-aba-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(token: nil), startBackgroundTasks: false)
    model.startDemoMode() // Existing memory-only path; no Profile/HA/native authority.
    defer { model.stopDemoMode() }
    var snapshot = try #require(model.activeDJSession?.broadcast)
    _ = try #require(snapshot.playback)
    snapshot.playback?.updatedAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-2))
    model.applySessionBroadcastSnapshot(snapshot)
    let baseline = model.askDJExampleContext().ownerEpoch
    let nextPosition = (snapshot.playback?.positionMS ?? 0) + 1000
    snapshot.playback?.positionMS = nextPosition
    snapshot.playback?.updatedAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1))
    model.applySessionBroadcastSnapshot(snapshot)
    #expect(model.askDJExampleContext().ownerEpoch == baseline)
    for field in ["artist", "album", "state", "freshness"] {
        let before = model.askDJExampleContext().ownerEpoch
        let original = snapshot.playback
        switch field {
        case "artist": snapshot.playback?.artist = "Changed artist, same item"
        case "album": snapshot.playback?.album = "Changed album, same item"
        case "state": snapshot.playback?.state = "paused"
        default: snapshot.playback?.updatedAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-40))
        }
        model.applySessionBroadcastSnapshot(snapshot)
        snapshot.playback = original; model.applySessionBroadcastSnapshot(snapshot)
        #expect(model.askDJExampleContext().ownerEpoch != before)
    }
}

@Test func askDJShippingDraftNeverAdvertisesCandidateCommandsAndBytesArePinned() throws {
    let catalogue = try #require(DJConnectAskDJCatalogue.bundled)
    let data = try askDJGolden()
    let vector = try #require((data["cases"] as? [[String: Any]])?.first)
    let context = try askDJContext(#require(vector["context"] as? [String: Any]))
    #expect(!catalogue.compatible(context))
    #expect(catalogue.select(context, surface: .askDJ, language: "nl", epoch: "draft").isEmpty)
    #expect(catalogue.helpSections(context, language: "nl").isEmpty)
    #expect(DJConnectAskDJCatalogue.verified(data: Data("{}".utf8)) == nil)
    // Even changing all qualification flags cannot pass the shipping byte pin.
    let synthetic = try JSONSerialization.data(withJSONObject: #require(data["synthetic_catalogue"]))
    #expect(DJConnectAskDJCatalogue.verified(data: synthetic) == nil)
}

@Test func askDJSelectorAndCompactHelpMatchSeventyIndependentCoreReferenceVectors() throws {
    let fixture = try askDJGolden()
    // Test-only decode. Production exclusively uses byte-verified bundled data.
    let catalogue = try askDJDecode(DJConnectAskDJCatalogue.self, #require(fixture["synthetic_catalogue"]))
    let cases = try #require(fixture["cases"] as? [[String: Any]])
    #expect(cases.count == 70)
    for vector in cases {
        let context = try askDJContext(#require(vector["context"] as? [String: Any]))
        let language = try #require(vector["language"] as? String)
        let surfaceName = try #require(vector["surface"] as? String)
        let surface = try #require(DJConnectAskDJCatalogue.Surface(rawValue: surfaceName))
        let selected = catalogue.select(context, surface: surface, language: language,
                                        epoch: try #require(vector["epoch"] as? String), recent: vector["recent"] as? [String] ?? [])
        let expected = try #require(vector["expected"] as? [[String: Any]])
        #expect(selected.map(\.id) == expected.compactMap { $0["id"] as? String })
        #expect(selected.map(\.prompt) == expected.compactMap { $0["prompt"] as? String })
        #expect(selected.isEmpty || selected.count == 3)
        #expect(Set(selected.map(\.intent)).count == selected.count)
        #expect(selected.allSatisfy { !$0.prompt.contains("[") && !$0.prompt.contains("{") })
        let help = catalogue.helpSections(context, language: language)
        let expectedHelp = try #require(vector["help"] as? [[Any]])
        #expect(help.count == expectedHelp.count && help.count <= 3)
        for (section, expected) in zip(help, expectedHelp) {
            #expect(section.title == expected.first as? String)
            #expect(section.examples == expected.last as? [String])
            #expect(section.examples.count <= 2)
        }
    }
}

@Test func askDJEditingOnlyWithdrawsAndOwnerChangeCannotResurrectSuggestions() throws {
    let fixture = try askDJGolden()
    let catalogue = try askDJDecode(DJConnectAskDJCatalogue.self, #require(fixture["synthetic_catalogue"]))
    let vector = try #require((fixture["cases"] as? [[String: Any]])?.first)
    var context = try askDJContext(#require(vector["context"] as? [String: Any]))
    var cursor = DJConnectAskDJSuggestionCursor()
    cursor.update(catalogue: catalogue, context: context, surface: .askDJ, language: "nl", frozen: false, visit: true, epoch: "visit")
    let original = cursor.suggestions
    #expect(original.count == 3)
    // Same semantic context, even another render/position tick epoch, does nothing.
    cursor.update(catalogue: catalogue, context: context, surface: .askDJ, language: "nl", frozen: false, epoch: "tick")
    #expect(cursor.suggestions == original)
    context.flags["current_track"] = false
    context.slots = [:]
    cursor.update(catalogue: catalogue, context: context, surface: .askDJ, language: "nl", frozen: true, epoch: "editing")
    let retained = original.filter { catalogue.retains($0, context: context, surface: .askDJ, language: "nl") }
    #expect(cursor.suggestions == (retained.count == 3 ? retained : []))
    context.ownerEpoch = "owner-b"; context.descriptor = nil
    cursor.update(catalogue: catalogue, context: context, surface: .askDJ, language: "nl", frozen: true)
    #expect(cursor.suggestions.isEmpty)
    cursor.update(catalogue: catalogue, context: context, surface: .askDJ, language: "nl", frozen: false)
    #expect(cursor.suggestions.isEmpty)
}

@Test func askDJUnknownContractsLocaleAndUnsafeSlotsDoNotCreateExecutableTemplates() throws {
    let fixture = try askDJGolden()
    let catalogue = try askDJDecode(DJConnectAskDJCatalogue.self, #require(fixture["synthetic_catalogue"]))
    let vector = try #require((fixture["cases"] as? [[String: Any]])?.first)
    var context = try askDJContext(#require(vector["context"] as? [String: Any]))
    #expect(catalogue.select(context, surface: .askDJ, language: "xx", epoch: "x").isEmpty)
    for invalid in ["", " [artist]", "{artist}", "a\nb", String(repeating: "a", count: 161)] {
        context.slots["artist"] = invalid
        #expect(!DJConnectAskDJCatalogue.safeSlot(invalid))
        #expect(!catalogue.select(context, surface: .askDJ, language: "en", epoch: "x").contains { $0.id.hasPrefix("play.artist") || $0.id.hasPrefix("discover.artist") })
    }
    context.contracts["ask_dj_examples"] = 2
    #expect(catalogue.select(context, surface: .askDJ, language: "en", epoch: "x").isEmpty)
    #expect(catalogue.helpSections(context, language: "en").isEmpty)
    let malformed = Data(#"{"success":true,"ask_dj_examples":{"schema_version":true},"contract_versions":{"ask_dj_examples":true}}"#.utf8)
    let decoded = try JSONDecoder().decode(DJConnectAskDJCatalogue.Capabilities.self, from: malformed)
    #expect(decoded.success && decoded.ask_dj_examples == nil && decoded.contract_versions == nil)
}

@Test func askDJCurrentSongPromptCannotSilentlyRetargetWhileReading() throws {
    let fixture = try askDJGolden()
    let catalogue = try askDJDecode(DJConnectAskDJCatalogue.self, #require(fixture["synthetic_catalogue"]))
    let vector = try #require((fixture["cases"] as? [[String: Any]])?.first)
    var context = try askDJContext(#require(vector["context"] as? [String: Any]))
    var cursor = DJConnectAskDJSuggestionCursor()
    cursor.update(catalogue: catalogue, context: context, surface: .session, language: "en", frozen: false, visit: true, epoch: "read")
    let shown = cursor.suggestions
    #expect(shown.count == 3 && shown.contains { $0.trackID != nil })
    context.trackID = "track-b"
    cursor.update(catalogue: catalogue, context: context, surface: .session, language: "en", frozen: true)
    #expect(shown.filter { $0.trackID == nil }.count < 3)
    #expect(cursor.suggestions.isEmpty)
    #expect(!shown.filter { $0.trackID != nil }.contains { catalogue.retains($0, context: context, surface: .session, language: "en") })
    context.sessionID = "session-b"
    #expect(!shown.contains { catalogue.retains($0, context: context, surface: .session, language: "en") })
}

@Test func askDJSessionHelpUsesItsOwnSurfaceEligibility() throws {
    let fixture = try askDJGolden()
    var raw = try #require(fixture["synthetic_catalogue"] as? [String: Any])
    var entries = try #require(raw["entries"] as? [[String: Any]])
    // Synthetic-only catalogue: no route becomes production-qualified.
    for i in entries.indices { entries[i]["surfaces"] = ["active_session"] }
    raw["entries"] = entries
    let catalogue = try askDJDecode(DJConnectAskDJCatalogue.self, raw)
    let vector = try #require((fixture["cases"] as? [[String: Any]])?.first)
    let context = try askDJContext(#require(vector["context"] as? [String: Any]))
    #expect(catalogue.helpSections(context, surface: .askDJ, language: "nl").isEmpty)
    #expect(!catalogue.helpSections(context, surface: .session, language: "nl").isEmpty)
}

@Test func askDJHelpWithdrawsTrackSessionAndUnavailableRoutesInEveryLocale() throws {
    let fixture = try askDJGolden()
    let catalogue = try askDJDecode(DJConnectAskDJCatalogue.self, #require(fixture["synthetic_catalogue"]))
    let vector = try #require((fixture["cases"] as? [[String: Any]])?.first)
    let initial = try askDJContext(#require(vector["context"] as? [String: Any]))
    for language in ["nl", "en", "de", "fr", "es"] {
        for surface in [DJConnectAskDJCatalogue.Surface.askDJ, .session] {
            let before = catalogue.helpSections(initial, surface: surface, language: language)
            #expect(before.count == 3 && before.first?.id == "listen")
            var expired = initial
            for key in ["current_track", "current_album", "forecast_ready"] { expired.flags[key] = false }
            expired.trackID = nil; expired.slots = [:]
            let after = catalogue.helpSections(expired, surface: surface, language: language)
            #expect(!after.isEmpty && after.first?.id == "play")
            let oldTrackExamples = try #require(before.first).examples
            #expect(!after.flatMap(\.examples).contains { oldTrackExamples.contains($0) })
            #expect(after.count <= 3 && after.allSatisfy { $0.examples.count <= 2 })
            expired.flags["active_session"] = false; expired.sessionID = nil
            #expect(catalogue.helpSections(expired, surface: .session, language: language).isEmpty)
            #expect(!catalogue.helpSections(expired, surface: .askDJ, language: language).isEmpty)
            for flag in ["paired", "online", "backend_available"] {
                var unavailable = initial; unavailable.flags[flag] = false
                #expect(catalogue.helpSections(unavailable, surface: surface, language: language).isEmpty)
            }
            var unadvertised = initial; unadvertised.descriptor = nil
            #expect(catalogue.helpSections(unadvertised, surface: surface, language: language).isEmpty)
        }
    }
}

@Test @MainActor func composerHelpRetiresAutomaticPreferenceAndKeepsManualRequestsTransient() throws {
    let name = "help-manual-test-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(true, forKey: "DJConnectAutomaticHelpHidden")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(token: nil), startBackgroundTasks: false)
    #expect(defaults.object(forKey: "DJConnectAutomaticHelpHidden") == nil)
    #expect(model.askDJHelpOpenRequest == nil && model.askDJHelpCatalogueReader != nil)
    model.askDJHelpOpenRequest = .init(surface: .askDJ)
    #expect(model.askDJHelpOpenRequest?.surface == .askDJ)
    #expect(defaults.object(forKey: "DJConnectAutomaticHelpHidden") == nil)
    for language in DJConnectLocalization.supportedLanguageCodes {
        for key in ["ui.askdj.suggestions.title", "ui.ask_dj.answer.retained_unavailable"] {
            #expect(DJConnectLocalization.localized(key: key, language: language) != key)
        }
    }
}
