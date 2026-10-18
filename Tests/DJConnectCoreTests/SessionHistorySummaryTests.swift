import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

private func summaryFixture(_ name: String) throws -> [String: Any] {
    let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/session-history-summary-" + name + ".json")
    return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
}
private func summaryDecode(_ session: [String: Any]) throws -> DJConnectSavedSession {
    try JSONDecoder().decode(DJConnectSavedSession.self, from: JSONSerialization.data(withJSONObject: session))
}
private func summaryListSession() throws -> [String: Any] {
    let body = try #require(summaryFixture("final-list")["body"] as? [String: Any])
    return try #require((body["sessions"] as? [[String: Any]])?.first)
}

@Test func historySummaryConsumesPinnedListAndOpaqueDetailWithoutCountingRows() throws {
    let list = try summaryDecode(summaryListSession())
    let body = try #require(summaryFixture("final-detail")["body"] as? [String: Any])
    let detail = try summaryDecode(#require(body["session"] as? [String: Any]))
    for session in [list, detail] {
        let summary = try #require(session.summary)
        #expect(session.isContractValid)
        #expect(summary.tracksObserved.value == 2)
        #expect(summary.momentsPublished.value == 2)
        #expect(summary.mood.value == "energy")
        #expect(summary.state == "final")
        let roundtrip = try JSONDecoder().decode(DJConnectSavedSession.self, from: JSONEncoder().encode(session))
        #expect(roundtrip.summary == summary)
    }
    // Route-specific opaque revisions must never be ordered or merged.
    #expect(list.revision.value != detail.revision.value)
}

@Test func historySummaryPreservesProducerZeroPartialWithdrawnAndLegacyUnknown() throws {
    let examples = try #require(summaryFixture("summary-states")["examples"] as? [[String: Any]])
    var summaries: [DJConnectSessionHistorySummary] = []
    for example in examples {
        let body = try #require(example["body"] as? [String: Any])
        let session = try summaryDecode(#require((body["sessions"] as? [[String: Any]])?.first))
        let summary = try #require(session.summary)
        summaries.append(summary)
        let roundtrip = try JSONDecoder().decode(DJConnectSavedSession.self, from: JSONEncoder().encode(session))
        #expect(roundtrip.summary == summary)
    }
    #expect(summaries.count == 4)
    #expect(summaries[0].tracksObserved.value == 0)
    #expect(summaries[1].tracksObserved.value == 8191)
    #expect(summaries[1].tracksObserved.coverage == "partial")
    #expect(summaries[2].tracksObserved.value == nil)
    #expect(summaries[2].tracksObserved.coverage == "withdrawn")
    #expect(summaries[3].tracksObserved.value == nil)
    #expect(summaries[3].mood.value == nil)
    #expect(summaries[3].state == "final")
    for language in ["nl", "en", "de", "fr", "es"] {
        let lines = summaries.map { SessionHistorySummaryPresentation.lines($0, language: language) }
        #expect(lines[0][0].contains("0"))
        #expect(lines[0][0] != lines[2][0])
        #expect(lines[2][0] != lines[3][0])
        #expect(lines[1][0].contains(DJConnectLocalization.localized(key: "ui.session.summary.partial", language: language)))
        #expect(lines.flatMap { $0 }.allSatisfy { !$0.contains("ui.session.summary.") })
    }
}

@Test(arguments: ["absent", "null", "unsupported", "malformed", "header-revision", "scalar-type", "metric-revision", "metric-as-of", "state", "basis", "scope", "negative", "fraction", "missing-value", "unknown-with-value", "withdrawn-with-value", "partial-mood", "unknown-mood"])
func historySummaryRejectsIncoherentOptionalDataWithoutLosingSession(_ fault: String) throws {
    var session = try summaryListSession()
    var summary = try #require(session["summary"] as? [String: Any])
    var tracks = try #require(summary["tracks_observed"] as? [String: Any])
    var mood = try #require(summary["mood"] as? [String: Any])
    switch fault {
    case "unsupported": summary["schema_version"] = "djconnect-session-history-summary/99"
    case "header-revision": session["revision"] = 7
    case "scalar-type": session["revision"] = "6"
    case "metric-revision": tracks["revision"] = 7
    case "metric-as-of": tracks["as_of"] = "2026-10-13T10:00:00Z"
    case "state": tracks["state"] = "provisional"
    case "basis": tracks["basis"] = "invented_listening_total"
    case "scope": tracks["observation_scope"] = "exact_plays"
    case "negative": tracks["value"] = -1
    case "fraction": tracks["value"] = 1.5
    case "missing-value": tracks.removeValue(forKey: "value")
    case "unknown-with-value": tracks["coverage"] = "unknown"
    case "withdrawn-with-value": tracks["coverage"] = "withdrawn"
    case "partial-mood": mood["coverage"] = "partial"
    case "unknown-mood": mood["value"] = "future_mood"
    default: break
    }
    summary["tracks_observed"] = tracks; summary["mood"] = mood
    session["summary"] = summary
    if fault == "absent" { session.removeValue(forKey: "summary") }
    if fault == "null" { session["summary"] = NSNull() }
    if fault == "malformed" { session["summary"] = ["value": true] }
    let decoded = try summaryDecode(session)
    #expect(decoded.summary == nil)
    #expect(decoded.isContractValid)
    #expect(decoded.lifecycleStatus == "ENDED")
}

@Test(arguments: [0, 1, 2]) func historySummaryCapabilityRequiresExactSupportedVersion(_ version: Int) throws {
    let data = Data("{\"capabilities\":{\"session_conversation_history\":true,\"session_history_summary\":true},\"contract_versions\":{\"session_conversation_history\":1,\"session_history_summary\":\(version)}}".utf8)
    let caps = try JSONDecoder().decode(DJConnectSessionHistoryCapabilities.self, from: data)
    #expect(caps.summaryAvailable == (version == 1))
}

@Test func historySummaryRetainedSubsetNeverSubstitutesForUnknownPublicationTotal() throws {
    var session = try summaryListSession()
    var summary = try #require(session["summary"] as? [String: Any])
    var published = try #require(summary["moments_published"] as? [String: Any])
    var retained = published
    published["value"] = NSNull(); published["coverage"] = "unknown"
    retained["value"] = 1; retained["coverage"] = "partial"; retained["basis"] = "retained_readable_entries"
    summary["moments_published"] = published; summary["moments_retained"] = retained
    session["summary"] = summary
    let decoded = try #require(summaryDecode(session).summary)
    #expect(decoded.momentsPublished.value == nil)
    #expect(decoded.momentsRetained?.value == 1)
    let lines = SessionHistorySummaryPresentation.lines(decoded, language: "nl")
    #expect(lines[1] == "Gepubliceerde DJ-bijdragen: Onbekend")
    #expect(lines[2] == "Bewaarde DJ-bijdragen: 1 · Gedeeltelijk geregistreerd")
}

@Test(arguments: ["chill", "groove", "energy", "party", "mixed"])
func historySummaryAllQualifiedMoodsUseLocalizedLabels(_ value: String) throws {
    var session = try summaryListSession()
    var summary = try #require(session["summary"] as? [String: Any])
    var mood = try #require(summary["mood"] as? [String: Any]); mood["value"] = value
    summary["mood"] = mood; session["summary"] = summary
    let decoded = try #require(summaryDecode(session).summary)
    for language in ["nl", "en", "de", "fr", "es"] {
        let key = value == "mixed" ? "ui.session.summary.mixed" : "ui.session.mood." + value
        #expect(SessionHistorySummaryPresentation.lines(decoded, language: language)[2].hasSuffix(
            DJConnectLocalization.localized(key: key, language: language)))
    }
}
