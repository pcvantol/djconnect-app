import Foundation
import SwiftUI
import Testing
import DJConnectCore
import DJConnectUI

/// The component compiled into both shipping widget targets and the existing
/// Session Activity. Rendering DATA here does not create an Activity or owner.
@Suite @MainActor struct StatusObservationRenderingTests {
    @Test(arguments: ["nl", "en", "de", "fr", "es"])
    func shippingComponentRendersOriginalStatusAtWidgetAndActivitySizes(_ language: String) throws {
        for state in ["playing", "paused", "stopped", "unknown"] {
            let original = Data("{\"playback_state\":\"\(state)\",\"observed_at_ms\":1793500000123}".utf8)
            let value = try JSONDecoder().decode(DJConnectSessionPlaybackObservation.self, from: original)
            for (width, height, compact, header) in [(160, 160, true, true), (360, 170, false, true),
                                                      (360, 360, false, true), (360, 130, true, false),
                                                      (620, 180, false, true)] {
                let view = DJConnectSessionPlaybackObservationView(observation: value, compact: compact,
                                                                  showsHeader: header, language: language)
                let renderer = ImageRenderer(content: view.frame(width: CGFloat(width), height: CGFloat(height)))
                renderer.scale = 1
                let rendered = try #require(renderer.cgImage)
                #expect(rendered.width == width && rendered.height == height)
                #expect(value.observedAtMilliseconds == 1793500000123)
                let key = "surface.playback.observed." + state
                #expect(DJConnectLocalization.localized(key: key, language: language) != key)
            }
        }
    }
}
