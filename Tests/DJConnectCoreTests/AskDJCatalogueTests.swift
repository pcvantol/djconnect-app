import Foundation
import Testing
@testable import DJConnectCore

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
    context.descriptor = try askDJDecode(DJConnectAskDJCatalogue.Descriptor.self, #require(raw["catalogue"]))
    context.contracts = try #require(raw["contracts"] as? [String: Int])
    context.slots = raw["slots"] as? [String: String] ?? [:]
    for (key, value) in raw where value is Bool { context.flags[key] = value as? Bool }
    context.ownerEpoch = "owner-a"
    if context.flags["current_track"] == true { context.trackID = "track-a" }
    if context.flags["active_session"] == true { context.sessionID = "session-a" }
    return context
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
    #expect(cursor.suggestions == original.filter { catalogue.retains($0, context: context, surface: .askDJ, language: "nl") })
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
    #expect(cursor.suggestions == shown.filter { $0.trackID == nil })
    #expect(!shown.filter { $0.trackID != nil }.contains { catalogue.retains($0, context: context, surface: .session, language: "en") })
    context.sessionID = "session-b"
    #expect(!shown.contains { catalogue.retains($0, context: context, surface: .session, language: "en") })
}
