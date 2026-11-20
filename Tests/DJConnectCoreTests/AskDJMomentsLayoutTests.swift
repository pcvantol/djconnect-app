import Foundation
import SwiftUI
import Testing
@testable import DJConnectCore
@testable import DJConnectUI
#if os(macOS)
import AppKit

/// Actual shared catalogue/card geometry; original Core content remains Dutch.
/// Five client chrome locales are not five real-model narration acceptance claims.
@Test(.isolatedAppKitResources) @MainActor func momentsNativeCatalogueRendersPhoneWideAndAccessibleTypeInFiveClientLocales() async throws {
    _ = NSApplication.shared
    let url = try #require(askDJMomentsFixtureURL("producer-final"))
    let packet = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let raw = try JSONSerialization.data(withJSONObject: try #require(packet["inventory"]))
    let inventory = try JSONDecoder().decode(DJConnectAskDJMoments.Inventory.self, from: raw)
    for language in ["en", "nl", "de", "fr", "es"] {
        for width: CGFloat in [390, 960] {
            let content = SessionCurrentDJCard(sessionID: inventory.sessionID, state: .expanded, mood: nil) {
                DJPersonaAvatarView(confirmedMood: nil, language: language).frame(width: 80, height: 80)
            } detail: {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Ask DJ: Moments").font(.headline)
                    AskDJMomentsCatalogue(inventory: inventory, language: language,
                        unavailableLabel: DJConnectLocalization.localized(key: "ui.ask_moments.unavailable", language: language), select: { _ in })
                    Button(DJConnectLocalization.localized(key: "ui.ask_moments.close", language: language)) {}
                }
            }
            .environment(\.dynamicTypeSize, .accessibility2)
            .environment(\.djConnectGlassEffectsEnabled, false)
            .frame(width: width).padding(12).foregroundStyle(.white).background(Color.indigo)
            // Native hosting is required: ImageRenderer omits AppKit scroll content.
            let host = NSHostingView(rootView: content.environment(\.colorScheme, .dark))
            let height = ceil(host.fittingSize.height)
            #expect(height > 400 && height < 1200)
            let window = NSWindow(contentRect: .init(x: -20000, y: -20000, width: width + 24, height: height),
                styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .darkAqua); window.contentView = host
            window.orderBack(nil)
            try await Task.sleep(for: .milliseconds(50))
            host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
            #expect(host.bounds.width == width + 24)
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            window.close()
            if let folder = ProcessInfo.processInfo.environment["DJCONNECT_ASK_MOMENTS_ARTIFACT_DIR"] {
                let directory = URL(fileURLWithPath: folder)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: directory.appendingPathComponent("moments-catalogue-\(language)-\(Int(width)).png"))
            }
        }
    }
}
#endif
