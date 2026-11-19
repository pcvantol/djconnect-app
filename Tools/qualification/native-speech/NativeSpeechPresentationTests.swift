import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import DJConnectCore
@testable import DJConnectUI

private final class SpeechNetworkSink: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var count = 0
    static var requests: Int { lock.withLock { count } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.withLock { Self.count += 1 }
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }
    override func stopLoading() {}
}

final class NativeSpeechPresentationTests: XCTestCase {
    @MainActor func testActualIOSSpeechConfigurationPresentation() async throws {
        guard let path = ProcessInfo.processInfo.environment["DJCONNECT_IOS_HA_SPEECH_DIR"] else {
            throw XCTSkip("Native speech presentation recording is opt-in")
        }
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let suite = "ios-speech-presentation-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set("http://speech-presentation.invalid:8123", forKey: "DJConnectHomeAssistantURL")
        defaults.set("http://speech-presentation.invalid:8123", forKey: "DJConnectHALocalURL")
        defaults.set("local", forKey: "DJConnectHAConnectionMode")
        defaults.set("speech-install", forKey: "DJConnectHAInstallID")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SpeechNetworkSink.self]
        let session = URLSession(configuration: config)
        let baseline = SpeechNetworkSink.requests
        let model = DJConnectAppModel(defaults: defaults,
            tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-presentation-token"),
            urlSession: session, startBackgroundTasks: false)
        defer {
            model.markInactiveSession(); session.invalidateAndCancel()
            defaults.removePersistentDomain(forName: suite)
        }
        XCTAssertEqual(model.identity.clientType, .ios)
        let source = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "device-speech-core-604b80f8", withExtension: "json"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: source)) as? [String: Any])
        let cases = try XCTUnwrap(root["cases"] as? [[String: Any]])
        var observations: [[String: Any]] = []
        let samples: [(String, String?, String, CGFloat, DynamicTypeSize)] = [
            ("retry-en-320", "same_owner_recent_failure", "en", 320, .large),
            ("retry-en-320-accessibility5", "same_owner_recent_failure", "en", 320, .accessibility5),
            ("withdrawn-en-720", "speaker_target_withdrawal", "en", 720, .large),
            ("unknown-nl-320-accessibility5", nil, "nl", 320, .accessibility5),
            ("unknown-de-320-accessibility5", nil, "de", 320, .accessibility5)
        ]
        for (name, fixture, language, width, size) in samples {
            model.language = language
            var body: [String: Any] = ["success": true, "ha_install_id": "speech-install"]
            if let fixture {
                body["device_speech"] = try XCTUnwrap(cases.first { $0["case"] as? String == fixture }?["snapshot"])
            }
            let envelope = try JSONDecoder().decode(DJConnectEnvelope<DJConnectPlayback>.self,
                from: JSONSerialization.data(withJSONObject: body))
            _ = model.applyStatusEndpoints(envelope, expectedLocal: model.haLocalURL,
                expectedRemote: model.haRemoteURL, expectedInstall: "speech-install")
            let snapshot = model.haSpeechConfiguration
            XCTAssertEqual(snapshot != nil, fixture != nil)
            let states = [snapshot?.ha_stt, snapshot?.ha_tts, snapshot?.ha_speaker_target]
                .map { HASpeechConfigurationStatus($0).rawValue }
            XCTAssertEqual(states, fixture == nil ? ["unknown", "unknown", "unknown"]
                : fixture == "speaker_target_withdrawal" ? ["configured", "unconfigured", "unavailable"]
                : ["configured", "configured", "unconfigured"])
            let host = UIHostingController(rootView: HASpeechConfigurationView(model: model)
                .frame(width: width - 32, alignment: .leading).padding(16)
                .fixedSize(horizontal: false, vertical: true)
                .dynamicTypeSize(size).foregroundStyle(.white).background(Color.black)
                .preferredColorScheme(.dark))
            host.safeAreaRegions = []
            let fitted = host.sizeThatFits(in: .init(width: width, height: 4000))
            let height = ceil(fitted.height) + 32
            let window = UIWindow(frame: .init(x: 0, y: 0, width: width, height: height))
            window.rootViewController = host; window.isHidden = false
            try await Task.sleep(for: .milliseconds(150))
            window.layoutIfNeeded()
            let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
            let png = renderer.pngData { window.layer.render(in: $0.cgContext) }
            try png.write(to: folder.appendingPathComponent(name + ".png"))
            observations.append(["name": name, "width": width, "height": height,
                "states": states, "snapshot_admitted": snapshot != nil,
                "fixture": fixture ?? "none", "language": language])
            window.isHidden = true; window.rootViewController = nil
            XCTAssertGreaterThan(height, 32); XCTAssertLessThan(height, 4000)
        }
        XCTAssertEqual(SpeechNetworkSink.requests, baseline)
        try JSONSerialization.data(withJSONObject: ["samples": observations,
            "network_requests": SpeechNetworkSink.requests - baseline], options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("observations.json"))
    }
}
