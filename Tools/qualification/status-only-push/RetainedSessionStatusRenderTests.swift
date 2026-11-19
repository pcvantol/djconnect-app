import Foundation
import Testing
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import DJConnectCore
import DJConnectUI
#if os(iOS)
import UIKit
import ActivityKit
#endif

/// Actual Session component and ContentState alias. No native activity, owner,
/// registration, token or push delivery is created by these value/render tests.
@Suite(.serialized) @MainActor struct RetainedSessionStatusRenderTests {
    private let originalMS: Int64 = 1793500000123
    private func snapshot(_ playback: String) throws -> DJConnectSessionSurfaceSnapshot {
        try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self,
            from: Data("{\"playback_state\":\"\(playback)\",\"observed_at_ms\":\(originalMS)}".utf8))
    }
    @Test func actualSessionComponentRendersFiveLanguagesAndNativeGeometry() throws {
        #if os(iOS)
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        #else
        let pad = false
        #endif
        let width = pad ? 620 : 360, height = pad ? 180 : 170
        for language in ["nl", "en", "de", "fr", "es"] {
            let data = try snapshot("paused")
            let observation = try #require(data.playbackObservation)
            let view = DJConnectSessionPlaybackObservationView(observation: observation, language: language)
            let renderer = ImageRenderer(content: view.frame(width: CGFloat(width), height: CGFloat(height)))
            renderer.scale = 2
            let pixels = try #require(renderer.cgImage)
            #expect(pixels.width == width * 2 && pixels.height == height * 2)
            #expect(observation.observedAtMilliseconds == originalMS)
            if let path = ProcessInfo.processInfo.environment["DJCONNECT_STATUS_SHIPPING_ARTIFACTS"] {
                let output = URL(fileURLWithPath: path)
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                let destination = try #require(CGImageDestinationCreateWithURL(
                    output.appendingPathComponent("retained-session-\(language).png") as CFURL,
                    UTType.png.identifier as CFString, 1, nil))
                CGImageDestinationAddImage(destination, pixels, nil)
                #expect(CGImageDestinationFinalize(destination))
            }
        }
    }
    #if os(iOS)
    @Test func actualSessionActivityAliasKeepsOnlyWhitelistedObservation() throws {
        let attributes = DJConnectSessionLiveActivityAttributes(presentationID: UUID().uuidString)
        #expect(String(describing: DJConnectSessionLiveActivityAttributes.self) == "DJConnectSessionLiveActivityAttributes")
        for playback in ["playing", "paused", "stopped", "unknown"] {
            let data: DJConnectSessionLiveActivityAttributes.ContentState = try snapshot(playback)
            let content = ActivityContent<DJConnectSessionLiveActivityAttributes.ContentState>(state: data, staleDate: nil)
            #expect(content.staleDate == nil)
            #expect(content.state.rich == nil && content.state.theme == nil)
            #expect(content.state.playbackObservation?.observedAtMilliseconds == originalMS)
            let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(content.state)) as? [String: Any])
            #expect(Set(object.keys) == ["playback_state", "observed_at_ms"])
            #expect(object["playback_state"] as? String == playback)
            #expect(try JSONDecoder().decode(DJConnectSessionLiveActivityAttributes.ContentState.self,
                                            from: JSONEncoder().encode(data)) == data)
        }
        let identity = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(attributes)) as? [String: Any])
        #expect(Set(identity.keys) == ["presentationID"])
        let mixed = Data("{\"playback_state\":\"playing\",\"observed_at_ms\":\(originalMS),\"title\":\"private\"}".utf8)
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(DJConnectSessionLiveActivityAttributes.ContentState.self, from: mixed)
        }
    }
    #endif
}
