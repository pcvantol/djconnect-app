import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
import DJConnectCore
import DJConnectUI

/// Actual shipping Smart Stack component only; no Activity request, enrollment,
/// token operation, mirrored OS presentation or APNs delivery is performed.
@Suite @MainActor struct WatchSessionActivityPresentationTests {
    @Test(arguments: ["playing", "paused", "stopped", "unknown"])
    func originalObservationRendersAtWatchSizes(_ state: String) throws {
        let originalMS: Int64 = 1793500000123
        let bytes = Data("{\"playback_state\":\"\(state)\",\"observed_at_ms\":\(originalMS)}".utf8)
        let value = try JSONDecoder().decode(DJConnectSessionPlaybackObservation.self, from: bytes)
        for language in ["nl", "en", "de", "fr", "es"] {
            for width in [156, 172, 184] {
                let view = DJConnectSessionWatchObservationView(observation: value, language: language)
                let renderer = ImageRenderer(content: view.padding(8).frame(width: CGFloat(width), height: 84)
                    .background(Color(red: 0.08, green: 0.08, blue: 0.16)))
                renderer.scale = 2
                let image = try #require(renderer.cgImage)
                #expect(image.width == width * 2 && image.height == 168)
                #expect(value.observedAtMilliseconds == originalMS)
                if state == "playing", language == "nl", width == 172,
                   let path = ProcessInfo.processInfo.environment["DJCONNECT_WATCH_ACTIVITY_RENDER_PATH"] {
                    let destination = try #require(CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL,
                        UTType.png.identifier as CFString, 1, nil))
                    CGImageDestinationAddImage(destination, image, nil)
                    #expect(CGImageDestinationFinalize(destination))
                }
            }
        }
    }
}
