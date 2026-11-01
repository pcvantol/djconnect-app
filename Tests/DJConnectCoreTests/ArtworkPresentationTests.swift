import SwiftUI
import Testing
@testable import DJConnectUI

#if os(macOS)
/// Scroll containers propose a width without a height. The fallback must reserve
/// a square even when there are no downloaded pixels to establish its size.
@MainActor
@Test(arguments: [54, 190, 270, 358])
func vinylArtworkReservesSquareInWidthOnlyScrollLayout(side: Int) throws {
    let renderer = ImageRenderer(content:
        AlbumArtworkPlaceholder(tint: .purple, isPlaying: false)
            .environment(\.scenePhase, .active)
    )
    renderer.proposedSize = ProposedViewSize(width: CGFloat(side), height: nil)
    let image = try #require(renderer.cgImage)
    #expect(image.width == side)
    #expect(image.height == side)
}
#endif

#if os(macOS)
import AppKit
import DJConnectCore

/// Render the actual playback component without a paired owner or provider call.
@MainActor @Test func playbackHeroNativeWideAndNarrowPreview() throws {
    guard let output = ProcessInfo.processInfo.environment["DJCONNECT_PLAYBACK_HERO_PREVIEW_DIR"] else { return }
    let folder = URL(fileURLWithPath: output)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let suite = "playback-hero-preview-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    model.isDemoMode = true
    model.language = "nl"
    model.playback = try JSONDecoder().decode(DJConnectPlayback.self, from: Data(#"{"is_playing":false,"track_name":"Voorbeeldnummer","artist_name":"Voorbeeldartiest","duration_ms":240000,"progress_ms":60000}"#.utf8))
    var heights: [Int] = []
    for width in [960, 520] {
        let renderer = ImageRenderer(content: TrackSummaryView(model: model)
            .padding(20).background(Color(red: 0.07, green: 0.06, blue: 0.18))
            .environment(\.scenePhase, .inactive)
            .environment(\.colorScheme, .dark)
            .environment(\.djConnectGlassEffectsEnabled, false))
        renderer.proposedSize = ProposedViewSize(width: CGFloat(width), height: nil)
        let image = try #require(renderer.cgImage)
        #expect(image.width == width)
        heights.append(image.height)
        let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try png.write(to: folder.appendingPathComponent("playback-\(width).png"), options: .withoutOverwriting)
    }
    #expect(heights[0] < heights[1], "Wide playback uses one row; narrow playback retains its vertical layout")
}
#endif
