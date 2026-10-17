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
