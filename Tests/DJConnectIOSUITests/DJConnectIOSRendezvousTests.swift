import XCTest

@MainActor
final class DJConnectIOSRendezvousTests: XCTestCase {
    func testSimulatorUsesProductQRAndStopsWhenAppAttestUnsupported() throws {
        #if targetEnvironment(simulator)
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["DJCONNECT_UITEST_RUNTIME_FIXTURE"] = "rendezvous_unsupported"
        let expiry = Int64(Date().timeIntervalSince1970 * 1000) + 120_000
        let qr: [String: Any] = ["type":"djc-rendezvous-qr", "v":"djc-rendezvous/1",
            "service_origin":"https://api.djconnect.dev", "transaction_id":"00000000-0000-4000-8000-000000000001",
            "generation":1, "expires_at":expiry, "browser_key_thumbprint":String(repeating:"A", count:43),
            "qr_capability":String(repeating:"A", count:43)]
        app.launchEnvironment["DJCONNECT_UITEST_RENDEZVOUS_QR"] = String(decoding: try JSONSerialization.data(withJSONObject:qr), as:UTF8.self)
        app.launch()
        let selection = app.switches["vibecast-rendezvous-installation"]
        XCTAssertTrue(selection.waitForExistence(timeout:15))
        let confirm = app.buttons["vibecast-rendezvous-confirm"]
        XCTAssertFalse(confirm.isEnabled)
        selection.tap(); XCTAssertTrue(confirm.isEnabled); confirm.tap()
        let status = app.staticTexts["vibecast-rendezvous-status"]
        XCTAssertTrue(status.waitForExistence(timeout:3))
        XCTAssertEqual(status.label, "This device does not support secure TV linking. No request was sent.")
        let attachment = XCTAttachment(screenshot:app.screenshot()); attachment.lifetime = .keepAlways; add(attachment)
        #else
        throw XCTSkip("Simulator-only, no physical App Attest effects authorized")
        #endif
    }
}
