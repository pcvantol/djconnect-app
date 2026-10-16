import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

private let technicalUnavailableSummary = "Er is geen gekwalificeerde muzikale analyse voor deze opname beschikbaar. Playbackmetadata staat apart; de audio is niet gemeten."

@Test(arguments: ["nl", "en", "de", "fr", "es"])
@MainActor func trackInsightUnavailableUsesLocalizedPresentationWithoutChangingEvidence(language: String) throws {
    let wire = try JSONSerialization.data(withJSONObject: [
        "track": ["title": "Example", "artist": "Artist"],
        "analysis": ["basis": "unmeasured_metadata_only_v1", "measured_audio": false,
                     "summary": technicalUnavailableSummary, "full_text": technicalUnavailableSummary]
    ])
    let insight = try #require(TrackInsightParser.parse(data: wire))
    #expect(insight.analysisBasis == "unmeasured_metadata_only_v1")
    #expect(insight.hasUnavailableAnalysis)
    #expect(insight.summary == technicalUnavailableSummary && insight.rawAnalysisText == technicalUnavailableSummary)
    #expect(insight.energy == nil && insight.danceability == nil && insight.intensity == nil && insight.confidence == nil)
    let display = insight.displaySummary(language: language)
    #expect(display == DJConnectLocalization.localized(key: "ui.trackInsight.analysis.unavailable", language: language))
    #expect(display != technicalUnavailableSummary && !display.hasPrefix("ui."))
    if language == "nl" { #expect(display == "Voor dit nummer is nog geen muziekanalyse beschikbaar.") }
    let restored = try JSONDecoder().decode(TrackInsight.self, from: JSONEncoder().encode(insight))
    #expect(restored.analysisBasis == insight.analysisBasis && restored.displaySummary(language: language) == display)
    #expect(TrackInsightShareService.shareText(for: insight, language: language).contains(display))
    #expect(!TrackInsightShareService.shareText(for: insight, language: language).contains(technicalUnavailableSummary))
    #expect(DJConnectTrackInsightWidgetSnapshot(insight: insight).summary == insight.displaySummary())
}

@Test func legacyTrackInsightCacheAndWidgetDoNotExposeTechnicalFallback() throws {
    let insight = TrackInsight(title: "Example", artist: "Artist", summary: technicalUnavailableSummary, rawAnalysisText: technicalUnavailableSummary)
    var old = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(insight)) as? [String: Any])
    old.removeValue(forKey: "analysisBasis")
    let restored = try JSONDecoder().decode(TrackInsight.self, from: JSONSerialization.data(withJSONObject: old))
    #expect(restored.analysisBasis == nil && restored.hasUnavailableAnalysis)
    #expect(restored.displaySummary(language: "nl") == "Voor dit nummer is nog geen muziekanalyse beschikbaar.")
    let name = "track-insight-copy-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    var snapshot = DJConnectTrackInsightWidgetSnapshot(insight: restored)
    snapshot.summary = technicalUnavailableSummary // Old persisted widget payload, before the presentation repair.
    defaults.set(try JSONEncoder().encode(snapshot), forKey: DJConnectTrackInsightWidgetSnapshot.storageKey)
    #expect(DJConnectTrackInsightWidgetSnapshot.load(from: defaults)?.summary == restored.displaySummary())
}

@Test @MainActor func legitimateTrackInsightDescriptionsRemainVerbatimEvenWithoutMetrics() throws {
    let text = "De productie zet de zang naast droge drums; de energie komt uit de opbouw."
    let insight = TrackInsight(title: "Example", artist: "Artist", summary: text, rawAnalysisText: text)
    #expect(!insight.hasUnavailableAnalysis && insight.displaySummary(language: "nl") == text)
    #expect(TrackInsightShareService.shareText(for: insight, language: "nl").contains(text))
    #expect(DJConnectTrackInsightWidgetSnapshot(insight: insight).summary == text)
}
