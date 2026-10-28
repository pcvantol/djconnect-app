import Foundation
import Testing
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import DJConnectCore
import DJConnectUI

/// Isolated rendering of actual shipping modules; never an Activity/token call.
@Suite(.serialized) @MainActor struct ShippingStatusRenderTests {
    @Test func fiveLanguagesRenderOriginalObservation() throws {
        let bytes = Data(#"{"contract_version":1,"presentation_id":"00000000-0000-4000-8000-000000000001","presentation_generation":"00000000-0000-4000-8000-000000000002","sequence":1,"observed_at_unix_ms":1793052000000,"display_mode":"last_observed","phase":"active","playback_state":"paused"}"#.utf8)
        let state = try DJConnectStatusActivityState.decodeOriginalWire(bytes)
        #expect(state.matchesPresentation("00000000-0000-4000-8000-000000000001", generation: "00000000-0000-4000-8000-000000000002"))
        #expect(!state.matchesPresentation(state.presentation_id, generation: "00000000-0000-4000-8000-000000000003"))
        let zone = try #require(TimeZone(secondsFromGMT: 0))
        let output = ProcessInfo.processInfo.environment["DJCONNECT_STATUS_SHIPPING_ARTIFACTS"].map { URL(fileURLWithPath: $0) }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        for language in DJConnectStatusLanguage.allCases {
            let view = DJConnectStatusLastObservedView(state: state, language: language, zone: zone)
            let renderer = ImageRenderer(content: view.frame(width: 360, height: 150))
            renderer.scale = 2
            let cg = try #require(renderer.cgImage)
            #expect(cg.width == 720 && cg.height == 300)
            #expect(DJConnectStatusDisplayValue(activity: state).originalObservedMS == 1793052000000)
            if let output {
                let url = output.appendingPathComponent("status-\(language.rawValue).png")
                let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
                CGImageDestinationAddImage(destination, cg, nil)
                #expect(CGImageDestinationFinalize(destination))
            }
        }
    }
}
