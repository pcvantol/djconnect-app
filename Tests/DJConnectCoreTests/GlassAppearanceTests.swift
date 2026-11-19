import SwiftUI
import Testing
@testable import DJConnectUI

#if os(macOS)
/// Render the real backgrounds against two contrasting pages. An opaque
/// fallback must cover both identically. Apple's read-only accessibility
/// preference is not changed or spoofed by this test.
@MainActor
@Test(arguments: [false, true], [false, true])
func disabledGlassCoversContrastingPages(session: Bool, scrolling: Bool) throws {
    func pixels(over page: Color) throws -> Data {
        let card = Group {
            if session {
                Color.clear.djSessionFrostedSurface(cornerRadius: 8)
            } else {
                Rectangle().fill(DJConnectMaterial(.ultraThin))
            }
        }
        .frame(width: 64, height: 64)
        .background(page)
        .environment(\.djConnectGlassEffectsEnabled, false)
        .environment(\.djConnectScrollingSurface, scrolling)
        let renderer = ImageRenderer(content: card)
        let image = try #require(renderer.cgImage)
        #expect(image.width == 64 && image.height == 64)
        let center = try #require(image.cropping(to: CGRect(x: 16, y: 16, width: 32, height: 32)))
        return try #require(center.dataProvider?.data) as Data
    }
    let light = try pixels(over: .white)
    let dark = try pixels(over: .black)
    #expect(light == dark, "Disabled glass must not blend the page into the card")
}
#endif
