import Foundation
import Testing
import UIKit
import SwiftUI
@testable import DJConnectCore
@testable import DJConnectUI

private final class SummaryFixtureBundle: NSObject {}

@Suite(.serialized) @MainActor struct NativeHistorySummaryTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_NATIVE_SUMMARY_DIR"] != nil))
    func actualNativeSummaryRendering() async throws {
        func fixture(_ name: String) throws -> [String: Any] {
            let url = try #require(Bundle(for: SummaryFixtureBundle.self).url(forResource: name, withExtension: "json"))
            return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        }
        func decode(_ body: [String: Any]) throws -> DJConnectSessionHistorySummary {
            let row = try #require((body["sessions"] as? [[String: Any]])?.first)
            let session = try JSONDecoder().decode(DJConnectSavedSession.self, from: JSONSerialization.data(withJSONObject: row))
            #expect(session.isContractValid)
            return try #require(session.summary)
        }
        let final = try decode(#require(fixture("session-history-summary-final-list")["body"] as? [String: Any]))
        let examples = try #require(fixture("session-history-summary-summary-states")["examples"] as? [[String: Any]])
        let states = try examples.map { try decode(#require($0["body"] as? [String: Any])) }
        try #require(states.count == 4)
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["DJCONNECT_NATIVE_SUMMARY_DIR"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var observations: [[String: Any]] = []
        func render(_ summary: DJConnectSessionHistorySummary, name: String, language: String = "nl",
                    compact: Bool = false, scale: DynamicTypeSize = .large) async throws -> CGFloat {
            let root = SessionHistorySummaryView(summary: summary, language: language, compact: compact)
                .frame(width: 358, alignment: .leading).padding(16)
                .environment(\.colorScheme, .dark).environment(\.dynamicTypeSize, scale)
            let controller = UIHostingController(rootView: root)
            controller.safeAreaRegions = [] // Component host, not full-screen navigation.
            let measured = controller.sizeThatFits(in: CGSize(width: 390, height: 10000))
            #expect(measured.width.isFinite && measured.height.isFinite)
            #expect(measured.width <= 390.5 && measured.height > 0 && measured.height < 4000)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: max(400, ceil(measured.height) + 64)))
            window.backgroundColor = .black; window.overrideUserInterfaceStyle = .dark
            window.rootViewController = controller; window.makeKeyAndVisible()
            defer { window.isHidden = true; window.rootViewController = nil }
            try await Task.sleep(for: .milliseconds(150))
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in window.layer.render(in: context.cgContext) }
            try #require(image.pngData()).write(to: folder.appendingPathComponent(name + ".png"))
            observations.append(["stage": name, "language": language, "compact": compact,
                "dynamic_type": String(describing: scale), "measured_width": measured.width,
                "measured_height": measured.height, "window_height": window.bounds.height,
                "lines": SessionHistorySummaryPresentation.lines(summary, language: language)])
            return measured.height
        }
        _ = try await render(final, name: "summary-01-compact", compact: true)
        let normal = try await render(final, name: "summary-02-detail")
        let large = try await render(final, name: "summary-03-accessibility5", scale: .accessibility5)
        #expect(large > normal)
        _ = try await render(final, name: "summary-04-french-accessibility5", language: "fr", scale: .accessibility5)
        for (index, name) in ["zero", "partial", "withdrawn", "unknown"].enumerated() {
            _ = try await render(states[index], name: "summary-0\(index + 5)-" + name)
        }
        try JSONSerialization.data(withJSONObject: observations, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("native-summary-layout.json"))
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_NATIVE_DETAIL_SUMMARY_DIR"] != nil))
    func actualNativeDetailSummaryRendering() async throws {
        let url = try #require(Bundle(for: SummaryFixtureBundle.self).url(forResource: "session-history-summary-final-detail", withExtension: "json"))
        let fixture = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let body = try #require(fixture["body"] as? [String: Any])
        let header = try #require(body["session"] as? [String: Any])
        // Admit the unchanged detail header; this is not a full timeline-page test.
        let session = try JSONDecoder().decode(DJConnectSavedSession.self, from: JSONSerialization.data(withJSONObject: header))
        try #require(session.isContractValid)
        let summary = try #require(session.summary)
        #expect(session.revision.value == "6:ENDED:0:0:8cd62b0bb1b22dcb")
        #expect(summary.tracksObserved.value == 2 && summary.momentsPublished.value == 2 && summary.mood.value == "energy")
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["DJCONNECT_NATIVE_DETAIL_SUMMARY_DIR"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var observations: [[String: Any]] = []
        func render(_ name: String, width: CGFloat, language: String, scale: DynamicTypeSize) async throws -> CGFloat {
            let root = SessionHistorySummaryView(summary: summary, language: language, compact: false)
                .frame(width: width - 32, alignment: .leading).padding(16)
                .environment(\.colorScheme, .dark).environment(\.dynamicTypeSize, scale)
            let controller = UIHostingController(rootView: root)
            controller.safeAreaRegions = []
            let size = controller.sizeThatFits(in: CGSize(width: width, height: 10000))
            #expect(size.width.isFinite && size.height.isFinite && size.width <= width + 0.5)
            #expect(size.height > 0 && size.height < 4000)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: max(400, ceil(size.height) + 64)))
            window.backgroundColor = .black; window.overrideUserInterfaceStyle = .dark
            window.rootViewController = controller; window.makeKeyAndVisible()
            defer { window.isHidden = true; window.rootViewController = nil }
            try await Task.sleep(for: .milliseconds(150)); window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { window.layer.render(in: $0.cgContext) }
            try #require(image.pngData()).write(to: folder.appendingPathComponent(name + ".png"))
            observations.append(["stage": name, "width": width, "height": size.height,
                "window_height": window.bounds.height, "language": language,
                "dynamic_type": String(describing: scale), "revision": session.revision.value,
                "lines": SessionHistorySummaryPresentation.lines(summary, language: language)])
            return size.height
        }
        let normal = try await render("detail-01-dutch", width: 390, language: "nl", scale: .large)
        let large = try await render("detail-02-dutch-accessibility5", width: 390, language: "nl", scale: .accessibility5)
        #expect(large > normal)
        _ = try await render("detail-03-narrow-french-accessibility5", width: 320, language: "fr", scale: .accessibility5)
        try JSONSerialization.data(withJSONObject: observations, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("native-detail-summary-layout.json"))
    }

}
