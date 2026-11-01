import Foundation
import Testing
@testable import DJConnectCore

/// Synthetic native DATA only. Dates/uptime/attributes below are intentionally
/// not a qualified original clock, source permission or genuine SDK target.
@Suite struct DirectLocalPresentationV2Tests {
    private func file(_ name: String) throws -> Data {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: DirectLocalPresentationFixtureAnchor.self)
        #endif
        let url = try #require(bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") ?? bundle.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
    private func encoder() -> JSONEncoder { let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return e }
    private let attrs = Data(#"{"presentationID":"00000000-0000-4000-8000-000000000001"}"#.utf8)
    private func fixture(research: Bool = true, story: String = "Original narrative.") throws -> DJConnectSessionSurfaceSnapshot {
        let packet = try #require(DirectRichWireJSON.parse(file("direct-rich-synthetic-responses"), maximumBytes: 65536).object)
        let raw = try #require(packet["authorize_response"]?.object?["frame"])
        let frame = try JSONDecoder().decode(DirectRichFrame.self, from: raw.canonicalData())
        let original = try #require(frame.contribution)
        let contribution = DJConnectPassiveSession.Contribution(moment_id: original.moment_id, published_at: original.published_at,
            text: story, persona: original.persona, source_attribution: research ? original.source_attribution : [:],
            usage_basis: research ? original.usage_basis : "runtime_authored_direction", expires_at: original.expires_at)
        let attribution = research ? DJConnectDirectResearchAttribution(momentID: original.moment_id,
            sources: try #require(original.sources), expressionLicense: try #require(original.expression_license)) : nil
        let observed = Date(timeIntervalSince1970: 1793440800)
        let rich = DJConnectPassiveActivityContent(directLocalBinding: frame.binding_id, generation: frame.generation,
            sequence: 1, receivedAt: observed, receivedUptime: 1000, expiresAt: observed.addingTimeInterval(120),
            contribution: contribution, nowPlaying: frame.now_playing, playbackState: "playing", researchAttribution: attribution)
        return DJConnectSessionSurfaceSnapshot(observedAt: observed, theme: .groove, rich: rich)
    }

    @Test func sameAliasPreservesAllResearchInsideRichAndV1RejectsV2() throws {
        let input = try fixture()
        let value = try DJConnectDirectLocalPresentationV2.prepare(attributes: attrs, snapshot: input)
        #expect(!value.contributionOmitted)
        #expect(value.snapshot == input)
        #expect(value.snapshot.rich?.researchAttribution?.sources == input.rich?.researchAttribution?.sources)
        #expect(value.snapshot.rich?.researchAttribution?.expressionLicense == input.rich?.researchAttribution?.expressionLicense)
        let rich = try #require(value.snapshot.rich)
        #expect(try encoder().encode(rich).count <= 2800)
        #expect(value.attributes.count + value.contentState.count <= 4096)
        #expect(throws: (any Error).self) { _ = try DJConnectRichSurfaceFragments.preflight(attributes: attrs, state: value.contentState) }
    }

    // The genuine fixtures explicitly record noncanonical default key order.
    // Compare actual old/new Codable shapes with identical sortedKeys options;
    // the separate v1 tests continue preserving the original unsorted bytes.
    private struct OriginalLegacyRich: Codable {
        let bindingID: String; let generation: String; let sequence: Int
        let receivedAt: Date; let receivedUptime: TimeInterval; let expiresAt: Date
        let contribution: DJConnectPassiveSession.Contribution?
        let nowPlaying: DJConnectPassiveSession.NowPlaying?
        let playbackState: String?
    }
    private struct OriginalLegacySnapshot: Codable {
        let observedAt: Date; let expiresAt: Date
        let theme: DJConnectSessionMoodTheme?; let rich: OriginalLegacyRich?
    }
    @Test func nilExtrasKeepOriginalLegacyModelEncodingByteIdentical() throws {
        let packet = try #require(JSONSerialization.jsonObject(with: file("rich-surface-original-encoder-v1")) as? [String: Any])
        let files = try #require(packet["files"] as? [String: [String: String]])
        for name in ["state_rich_both.json", "state_rich_unicode_escaping.json", "state_rich_contribution_only.json", "state_rich_playback_only.json"] {
            let base64 = try #require(files[name]?["utf8_b64"])
            let data = try #require(Data(base64Encoded: base64))
            let snapshot = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: data)
            let legacy = try JSONDecoder().decode(OriginalLegacySnapshot.self, from: data)
            #expect(snapshot.rich?.directLocalVersion == nil && snapshot.rich?.researchAttribution == nil)
            #expect(try encoder().encode(snapshot) == encoder().encode(legacy))
        }
    }

    @Test(arguments: ["missing", "mismatched", "no-marker", "float-marker", "unknown-source"])
    func unsupportedAttributionNeverSilentlyBecomesV1(_ failure: String) throws {
        let original = try fixture()
        var root = try #require(JSONSerialization.jsonObject(with: encoder().encode(original)) as? [String: Any])
        var rich = try #require(root["rich"] as? [String: Any])
        var attribution = try #require(rich["researchAttribution"] as? [String: Any])
        switch failure {
        case "missing": rich.removeValue(forKey: "researchAttribution")
        case "mismatched": attribution["momentID"] = "different-moment"; rich["researchAttribution"] = attribution
        case "no-marker": rich.removeValue(forKey: "directLocalVersion")
        case "float-marker": break // Exact lexeme inserted after serialization.
        default:
            var sources = try #require(attribution["sources"] as? [[String: Any]])
            sources[0]["extra"] = "discard-me"; attribution["sources"] = sources; rich["researchAttribution"] = attribution
        }
        root["rich"] = rich
        var data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        if failure == "float-marker" { data = Data(String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"directLocalVersion\":2", with: "\"directLocalVersion\":2.0").utf8) }
        #expect(throws: (any Error).self) { _ = try DJConnectDirectLocalPresentationV2.preflight(attributes: attrs, state: data) }
        if failure != "unknown-source" && failure != "float-marker" {
            let typed = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: data)
            #expect(typed.rich?.currentContribution(at: typed.observedAt, uptime: 1000) == nil)
            #expect(typed.rich?.currentPlayback(at: typed.observedAt, uptime: 1000) != nil)
        }
    }

    @Test func unsupportedStoryClearsOnlyItsSlotWithoutExtendingBounds() throws {
        let original = try fixture(story: String(repeating: "x", count: 641))
        let value = try DJConnectDirectLocalPresentationV2.prepare(attributes: attrs, snapshot: original)
        #expect(value.contributionOmitted && value.snapshot.rich?.contribution == nil && value.snapshot.rich?.researchAttribution == nil)
        #expect(value.snapshot.rich?.nowPlaying == original.rich?.nowPlaying)
        #expect(value.snapshot.observedAt == original.observedAt && value.snapshot.expiresAt == original.expiresAt)
        #expect(value.snapshot.rich?.receivedAt == original.rich?.receivedAt && value.snapshot.rich?.receivedUptime == original.rich?.receivedUptime)
    }

    @Test func whole4096BoundaryCountsActualEncodedAttribution() throws {
        let original = try fixture()
        let state = try encoder().encode(original)
        let overhead = Data(#"{"presentationID":""}"#.utf8).count
        let padding = 4096 - state.count - overhead
        #expect(padding > 0)
        let exact = Data(("{\"presentationID\":\"" + String(repeating: "a", count: padding) + "\"}").utf8)
        #expect(exact.count + state.count == 4096)
        _ = try DJConnectDirectLocalPresentationV2.preflight(attributes: exact, state: state)
        let tooLarge = Data(("{\"presentationID\":\"" + String(repeating: "a", count: padding + 1) + "\"}").utf8)
        #expect(throws: (any Error).self) { _ = try DJConnectDirectLocalPresentationV2.preflight(attributes: tooLarge, state: state) }
    }

    @Test func rich2800BoundaryIncludesAttributionAnd2801DropsOnlyStory() throws {
        let original = try fixture(research: false)
        func padded(_ count: Int) throws -> DJConnectSessionSurfaceSnapshot {
            var root = try #require(JSONSerialization.jsonObject(with: encoder().encode(original)) as? [String: Any])
            var rich = try #require(root["rich"] as? [String: Any])
            var contribution = try #require(rich["contribution"] as? [String: Any])
            contribution["usage_basis"] = "cc0_facts_authored_expression"
            contribution["source_attribution"] = ["provider": "MusicBrainz", "license": "CC0-1.0", "url": "https://source.invalid/" + String(repeating: "a", count: count)]
            rich["contribution"] = contribution; root["rich"] = rich
            return try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        }
        let baseline = try #require(padded(0).rich)
        let padding = 2800 - (try encoder().encode(baseline).count)
        #expect(padding > 0 && padding < 2000)
        let exact = try padded(padding), overflow = try padded(padding + 1)
        let exactRich = try #require(exact.rich), overflowRich = try #require(overflow.rich)
        #expect(try encoder().encode(exactRich).count == 2800)
        #expect(try encoder().encode(overflowRich).count == 2801)
        #expect(try !DJConnectDirectLocalPresentationV2.prepare(attributes: attrs, snapshot: exact).contributionOmitted)
        let omitted = try DJConnectDirectLocalPresentationV2.prepare(attributes: attrs, snapshot: overflow)
        #expect(omitted.contributionOmitted && omitted.snapshot.rich?.contribution == nil)
        #expect(omitted.snapshot.rich?.nowPlaying == overflow.rich?.nowPlaying)
    }
}
private final class DirectLocalPresentationFixtureAnchor: NSObject {}
