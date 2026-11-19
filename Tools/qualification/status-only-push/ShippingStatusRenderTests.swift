import Foundation
import Testing
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import DJConnectCore
import DJConnectUI
#if os(iOS)
import ActivityKit
import UIKit
#endif

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

    #if os(iOS)
    @Test func actualNativeAttributesAndContentStateRemainSeparateFromLegacy() throws {
        let identityBytes = Data(#"{"presentation_id":"00000000-0000-4000-8000-000000000001","presentation_generation":"00000000-0000-4000-8000-000000000002"}"#.utf8)
        let attributes = try JSONDecoder().decode(DJConnectRemotePlaybackStatusActivityAttributesV1.self, from: identityBytes)
        let identity = try DJConnectStatusActivityIdentity.decodeOriginalWire(identityBytes)
        #expect(String(describing: DJConnectRemotePlaybackStatusActivityAttributesV1.self) == "DJConnectRemotePlaybackStatusActivityAttributesV1")
        let encodedIdentity = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(attributes)) as? [String: Any])
        #expect(Set(encodedIdentity.keys) == ["presentation_id", "presentation_generation"])
        #expect(attributes.presentation_id == identity.presentation_id && attributes.presentation_generation == identity.presentation_generation)
        for playback in ["playing", "paused", "stopped", "unknown"] {
            let bytes = Data("{\"contract_version\":1,\"presentation_id\":\"\(identity.presentation_id)\",\"presentation_generation\":\"\(identity.presentation_generation)\",\"sequence\":1,\"observed_at_unix_ms\":1793052000000,\"display_mode\":\"last_observed\",\"phase\":\"active\",\"playback_state\":\"\(playback)\"}".utf8)
            let state = try DJConnectStatusActivityState.decodeOriginalWire(bytes)
            let nativeState = try JSONDecoder().decode(DJConnectRemotePlaybackStatusActivityAttributesV1.ContentState.self, from: bytes)
            #expect(nativeState == state)
            let content = ActivityContent<DJConnectRemotePlaybackStatusActivityAttributesV1.ContentState>(state: nativeState, staleDate: nil)
            #expect(content.state.matchesPresentation(attributes.presentation_id, generation: attributes.presentation_generation))
            #expect(!content.state.matchesPresentation(attributes.presentation_id, generation: "00000000-0000-4000-8000-000000000003"))
            #expect(content.state.observed_at_unix_ms == 1793052000000)
            #expect(throws: (any Error).self) {
                _ = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: bytes)
            }
        }
        let invalid = Data(#"{"presentation_id":"00000000-0000-4000-8000-000000000001","presentation_generation":"00000000-0000-4000-8000-000000000002","profile_id":"not-a-native-field"}"#.utf8)
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(DJConnectRemotePlaybackStatusActivityAttributesV1.self, from: invalid)
        }
    } // Native value types only: no Activity.request/update/end or token calls.

    @Test func endedNullAndNativeDeviceGeometryRenderWithoutInventingObservation() throws {
        let bytes = Data(#"{"contract_version":1,"presentation_id":"00000000-0000-4000-8000-000000000001","presentation_generation":"00000000-0000-4000-8000-000000000002","sequence":2,"observed_at_unix_ms":1793052000000,"display_mode":"last_observed","phase":"ended","playback_state":null}"#.utf8)
        let state = try DJConnectStatusActivityState.decodeOriginalWire(bytes)
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        #expect(object.count == 8 && object["playback_state"] is NSNull)
        #expect(try JSONDecoder().decode(DJConnectStatusActivityState.self, from: JSONEncoder().encode(state)) == state)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let size = CGSize(width: isPad ? 620 : 360, height: isPad ? 180 : 150)
        let view = DJConnectStatusLastObservedView(state: state, language: .nl, zone: try #require(TimeZone(secondsFromGMT: 0)))
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        let cg = try #require(renderer.cgImage)
        #expect(cg.width == Int(size.width * 2) && cg.height == Int(size.height * 2))
        #expect(DJConnectStatusDisplayValue(activity: state).originalObservedMS == 1793052000000)
        if let path = ProcessInfo.processInfo.environment["DJCONNECT_STATUS_SHIPPING_ARTIFACTS"] {
            let output = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let destination = try #require(CGImageDestinationCreateWithURL(output.appendingPathComponent("status-ended-native.png") as CFURL, UTType.png.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(destination, cg, nil)
            #expect(CGImageDestinationFinalize(destination))
            let info: [String: Any] = ["platform": "iOS Simulator component only", "system_version": UIDevice.current.systemVersion,
                "idiom": isPad ? "iPad" : "iPhone", "native_type": String(describing: DJConnectRemotePlaybackStatusActivityAttributesV1.self),
                "original_observed_at_unix_ms": state.observed_at_unix_ms, "phase": state.phase.rawValue,
                "width": cg.width, "height": cg.height, "native_activity_created": false, "push_delivery_proved": false]
            try JSONSerialization.data(withJSONObject: info, options: [.sortedKeys, .prettyPrinted]).write(to: output.appendingPathComponent("native-device-component.json"))
        }
    }
    #endif
}
