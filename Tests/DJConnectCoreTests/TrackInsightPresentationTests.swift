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
    if language == "nl" { #expect(display == "Voor dit nummer zijn geen audiometingen beschikbaar. Achtergrondinformatie en duiding staan los van audiometingen.") }
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
    #expect(restored.displaySummary(language: "nl") == "Voor dit nummer zijn geen audiometingen beschikbaar. Achtergrondinformatie en duiding staan los van audiometingen.")
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

@Test func partialInsightShowsOnlySuppliedMetricsAndKeepsRealZero() throws {
    let data = Data(#"{"track":{"title":"Partial","artist":"Artist","genres":["Ambient"]},"analysis":{"energy":0,"danceability":null,"intensity":null,"mood":"  Calm  ","vibe":"  ","texture":null,"summary":"Server interpretation"}}"#.utf8)
    let insight = try #require(TrackInsightParser.parse(data: data))
    let shown = insight.displayMetrics
    #expect(shown.energy == 0 && shown.numericCount == 1)
    #expect(shown.danceability == nil && shown.intensity == nil)
    #expect(shown.genre == "Ambient" && shown.mood == "Calm")
    #expect(shown.vibe == nil && shown.texture == nil && !shown.isEmpty)
    let widget = DJConnectTrackInsightWidgetSnapshot(insight: insight)
    #expect(widget.energy == 0 && widget.danceability == nil && widget.intensity == nil)
}

@Test(arguments: ["unmeasured_metadata_only_v1", "qualified_credit_and_interpretation_v1", "unknown_future_basis"])
@MainActor func nonAudioInsightBasisCannotGrantMetricsOrSharedLabels(_ basis: String) throws {
    // Deliberately contaminated values must never become measurements just
    // because a credit, unknown basis or cached legacy field is present.
    var insight = TrackInsight(title: "Credit", artist: "Artist", genre: "Pop", energy: 0.8,
        danceability: 0, intensity: 1, mood: "not-a-measurement", vibe: "not-a-measurement", texture: "not-a-measurement",
        summary: "Producer explanation", rawAnalysisText: "Original evidence", analysisBasis: basis)
    #expect(insight.displayMetrics.numericCount == 0)
    #expect(insight.displayMetrics.mood == nil && insight.displayMetrics.vibe == nil && insight.displayMetrics.texture == nil)
    #expect(insight.displayMetrics.genre == "Pop") // Real playback metadata stays separate.
    let widget = DJConnectTrackInsightWidgetSnapshot(insight: insight)
    #expect(widget.energy == nil && widget.danceability == nil && widget.intensity == nil && widget.mood == nil)
    #expect(!TrackInsightShareService.shareText(for: insight).contains("not-a-measurement"))
    insight.genre = nil
    #expect(insight.displayMetrics.isEmpty)
    let restored = try JSONDecoder().decode(TrackInsight.self, from: JSONEncoder().encode(insight))
    #expect(restored.displayMetrics.isEmpty && restored.rawAnalysisText == "Original evidence")
}

@Test(arguments: [Double.nan, .infinity, -.infinity, -0.01, 1.01])
func directOrCachedInvalidMetricCannotRenderAsZeroOrOne(_ invalid: Double) {
    let insight = TrackInsight(title: "Invalid", artist: "Artist", energy: invalid, danceability: invalid,
        intensity: invalid, summary: "Interpretation", rawAnalysisText: "")
    #expect(insight.displayMetrics.isEmpty)
    #expect(DJConnectTrackInsightWidgetSnapshot(insight: insight).energy == nil)
    let snapshot = DJConnectTrackInsightWidgetSnapshot(title: "Invalid", artist: "Artist",
        energy: invalid, danceability: invalid, intensity: invalid, summary: "Supplied")
    #expect(snapshot.energy == nil && snapshot.danceability == nil && snapshot.intensity == nil)
}

@Test(arguments: [-1.0, 101.0, 10000.0])
func parserRejectsOutOfDomainMetricsInsteadOfClamping(_ invalid: Double) throws {
    let data = try JSONSerialization.data(withJSONObject: ["title": "Invalid", "artist": "Artist",
        "analysis": ["energy": invalid, "danceability": invalid, "intensity": invalid, "summary": "Supplied"]])
    let insight = try #require(TrackInsightParser.parse(data: data))
    #expect(insight.energy == nil && insight.danceability == nil && insight.intensity == nil)
    #expect(insight.displayMetrics.isEmpty)
}

@Test func unmeasuredFlagAndEmptyFieldsCannotCreateLayoutRows() throws {
    var insight = TrackInsight(title: "Empty", artist: "Artist", genre: " \n", mood: " ", vibe: "\n", texture: " ",
        summary: "No audio measurements were supplied for this recording.", rawAnalysisText: "Original")
    #expect(insight.displayMetrics.isEmpty)
    insight.energy = 0
    #expect(insight.displayMetrics.numericCount == 1)
    insight.measuredAudio = false
    #expect(insight.displayMetrics.isEmpty)
    insight.analysisBasis = "unmeasured_metadata_only_v1"
    #expect(insight.displaySummary(language: "en") == insight.summary) // Keep producer's explanation.
}

#if os(macOS)
import AppKit
import SwiftUI

@Test(.isolatedAppKitResources) @MainActor
func nativeInsightGridOmitsEmptyRowsAndRendersPartialZero() throws {
    _ = NSApplication.shared
    let empty = TrackInsight(title: "Empty", artist: "Artist", summary: "Metadata only", rawAnalysisText: "")
    let partial = TrackInsight(title: "Partial", artist: "Artist", energy: 0,
        summary: "Server supplied zero", rawAnalysisText: "")
    let label = TrackInsight(title: "Genre", artist: "Artist", genre: "Ambient",
        summary: "Metadata only", rawAnalysisText: "", analysisBasis: "unmeasured_metadata_only_v1")
    for width: CGFloat in [430, 820, 1200] {
        func height(_ insight: TrackInsight) -> CGFloat {
            let host = NSHostingView(rootView: TrackInsightMetricsGrid(insight: insight, language: "nl", moodStepIndex: 2)
                .transaction { $0.disablesAnimations = true }
                .frame(width: width).fixedSize(horizontal: false, vertical: true))
            return host.fittingSize.height
        }
        #expect(height(empty) <= 1)
        #expect(height(partial) >= 150)
        #expect(height(label) >= 96 && height(label) < height(partial))
    }
}

@Test(.isolatedAppKitResources) @MainActor
func nativeInsightCreditLayoutPreservesSourceAndInterpretation() throws {
    _ = NSApplication.shared
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let producer = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/moment-insight-core-producer.json"))) as? [String: Any])
    let body = try #require((producer["fixtures"] as? [[String: Any]])?.first { $0["case"] as? String == "active-detail-miss" }?["body"] as? [String: Any])
    let insight = try #require(TrackInsightParser.parse(data: JSONSerialization.data(withJSONObject: body)))
    #expect(insight.verifiedCredit != nil && insight.hasUnmeasuredAudio)
    #expect(insight.displayMetrics.numericCount == 0)
    let folder = ProcessInfo.processInfo.environment["DJCONNECT_TRACK_INSIGHT_RENDER_DIR"].map { URL(fileURLWithPath: $0) }
    if let folder { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
    for language in ["nl", "en", "de", "fr", "es"] {
        for width: CGFloat in [430, 820, 1200] {
            let content = VStack(alignment: .leading, spacing: 16) {
                Text(insight.title).font(.title.bold())
                Text(insight.artist)
                TrackInsightAnalysisCard(insight: insight, language: language)
                TrackInsightMetricsGrid(insight: insight, language: language, moodStepIndex: 2)
            }
            .padding(20).frame(width: width)
            .transaction { $0.disablesAnimations = true }
            .environment(\.dynamicTypeSize, .accessibility1)
            .environment(\.colorScheme, .dark)
            .foregroundStyle(.white).background(Color(red: 0.07, green: 0.08, blue: 0.18))
            // Snapshot the native host: ImageRenderer cannot draw AppKit's Link.
            let host = NSHostingView(rootView: content)
            let height = ceil(host.fittingSize.height)
            #expect(height > 200)
            let window = NSWindow(contentRect: CGRect(x: -20000, y: -20000, width: width, height: height),
                styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = host
            window.orderBack(nil)
            host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            window.close()
            if let folder {
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: folder.appendingPathComponent("credit-\(language)-\(Int(width)).png"))
            }
        }
    }
}
#endif
