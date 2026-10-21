#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import DJConnectCore
@testable import DJConnectUI

/// A network sink makes accidental I/O observable and cannot reach a server.
private final class SpeechPresentationNetworkSink: URLProtocol, @unchecked Sendable {
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

final class HASpeechNativePresentationTests: XCTestCase {
    /// Records the actual production component, not a reconstructed text mock.
    /// Bitmap inspection qualifies layout only; no glass, AX or audio claim.
    @MainActor func testNativeHASpeechConfigurationLayout() async throws {
        guard let path = ProcessInfo.processInfo.environment["DJCONNECT_HA_SPEECH_NATIVE_DIR"] else {
            throw XCTSkip("Native HA speech presentation recording is opt-in")
        }
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let suite = "ha-speech-native-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set("http://speech-presentation.invalid:8123", forKey: "DJConnectHomeAssistantURL")
        defaults.set("http://speech-presentation.invalid:8123", forKey: "DJConnectHALocalURL")
        defaults.set("local", forKey: "DJConnectHAConnectionMode")
        defaults.set("speech-install", forKey: "DJConnectHAInstallID")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SpeechPresentationNetworkSink.self]
        let session = URLSession(configuration: config)
        let baseline = SpeechPresentationNetworkSink.requests
        let model = DJConnectAppModel(defaults: defaults,
            tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-presentation-token"),
            urlSession: session, startBackgroundTasks: false)
        defer {
            model.markInactiveSession()
            session.invalidateAndCancel()
            defaults.removePersistentDomain(forName: suite)
        }
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Fixtures/device-speech-core-604b80f8.json")
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: source)) as? [String: Any])
        let cases = try XCTUnwrap(root["cases"] as? [[String: Any]])
        _ = NSApplication.shared
        var observations: [[String: Any]] = []
        // Qualified English snapshots are kept byte-for-byte semantically intact.
        // NL/DE deliberately have no snapshot: unknown must stay translated.
        let samples: [(String, String?, String, CGFloat)] = [
            ("configured-en-320", "configuration_stt_True_tts_True", "en", 320),
            ("retry-en-320", "same_owner_recent_failure", "en", 320),
            ("retry-en-720", "same_owner_recent_failure", "en", 720),
            ("withdrawn-speaker-en-320", "speaker_target_withdrawal", "en", 320),
            ("unknown-nl-320", nil, "nl", 320),
            ("unknown-de-320", nil, "de", 320)
        ]
        for (name, fixture, language, width) in samples {
            model.language = language
            var body: [String: Any] = ["success": true, "ha_install_id": "speech-install"]
            if let fixture {
                body["device_speech"] = try XCTUnwrap(cases.first { $0["case"] as? String == fixture }?["snapshot"])
            }
            let envelope = try JSONDecoder().decode(DJConnectEnvelope<DJConnectPlayback>.self,
                from: JSONSerialization.data(withJSONObject: body))
            _ = model.applyStatusEndpoints(envelope, expectedLocal: model.haLocalURL,
                expectedRemote: model.haRemoteURL, expectedInstall: "speech-install")
            XCTAssertEqual(model.haSpeechConfiguration != nil, fixture != nil)
            let snapshot = model.haSpeechConfiguration
            let states = [snapshot?.ha_stt, snapshot?.ha_tts, snapshot?.ha_speaker_target]
                .map { HASpeechConfigurationStatus($0).rawValue }
            let expected = fixture == nil ? ["unknown", "unknown", "unknown"]
                : fixture == "speaker_target_withdrawal" ? ["configured", "unconfigured", "unavailable"]
                : ["configured", "configured", "unconfigured"]
            XCTAssertEqual(states, expected)
            let host = NSHostingView(rootView: HASpeechConfigurationView(model: model)
                .frame(width: width - 32).padding(16)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.white).background(Color.black)
                .preferredColorScheme(.dark))
            let window = NSWindow(contentRect: .init(x: -3000, y: -3000, width: width, height: 400),
                styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderBack(nil)
            try await Task.sleep(for: .milliseconds(150))
            host.layoutSubtreeIfNeeded()
            let height = ceil(host.fittingSize.height)
            window.setContentSize(.init(width: width, height: height))
            host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                .write(to: folder.appendingPathComponent(name + ".png"))
            observations.append(["name": name, "fixture": fixture ?? "none", "language": language,
                "width": width, "height": height, "states": states,
                "snapshot_admitted": snapshot != nil])
            window.close()
            XCTAssertEqual(host.bounds.width, width, accuracy: 0.5)
            XCTAssertGreaterThan(height, 32)
            XCTAssertLessThan(height, 400)
        }
        XCTAssertEqual(SpeechPresentationNetworkSink.requests, baseline, "Presentation must not initiate HTTP")
        try JSONSerialization.data(withJSONObject: ["samples": observations,
            "network_requests": SpeechPresentationNetworkSink.requests - baseline],
            options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("observations.json"))
    }
}
#endif
