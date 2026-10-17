import XCTest
import UIKit

/// Runs against the already installed ordinary app. No test launch arguments,
/// setting selections, playback commands, preference resets or exported UI tree.
@MainActor
final class VoiceMenuStabilityProbe: XCTestCase {
    private var originalOrientation: UIDeviceOrientation?
    override func setUp() {
        continueAfterFailure = false
        originalOrientation = XCUIDevice.shared.orientation
        // A prior rotation can leave XCTest's app-window snapshot in a different
        // coordinate space from the physical screen. Establish one orientation
        // before testing hit points; do not bypass the real hittability checks.
        XCUIDevice.shared.orientation = .landscapeLeft
    }
    override func tearDown() {
        if let originalOrientation { XCUIDevice.shared.orientation = originalOrientation }
    }

    /// Diagnostic screenshot only, never a positive menu-stability assertion.
    func testCaptureOrdinaryScreen() {
        let app = XCUIApplication(bundleIdentifier: "dev.djconnect.ios")
        app.activate()
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "ordinary-ipad-screen-menu-diagnosis"; shot.lifetime = .keepAlways; add(shot)
    }

    private func openEditor(_ app: XCUIApplication) throws -> XCUIElement {
        app.activate()
        let dismiss = app.buttons["Niet nu"].firstMatch
        if dismiss.waitForExistence(timeout: 1), dismiss.isHittable { dismiss.tap() }
        let editor = app.descendants(matching: .any)["screen-profile-your-dj"].firstMatch
        if editor.exists { return editor }
        let tab = app.buttons["DJ-sessie"].firstMatch
        if tab.exists && tab.isHittable { tab.tap() }
        let more = app.buttons["session-more-menu"].firstMatch
        guard more.waitForExistence(timeout: 15) else { throw XCTSkip("No active ordinary Session menu") }
        more.tap()
        let voice = app.buttons["session-voice-toggle"].firstMatch
        guard voice.waitForExistence(timeout: 5) else { throw XCTSkip("DJ voice menu unavailable") }
        voice.tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        return editor
    }

    private func checkOpenMenu(field: String, labels: [String]) throws {
        let app = XCUIApplication(bundleIdentifier: "dev.djconnect.ios")
        let editor = try openEditor(app)
        let picker = app.descendants(matching: .any)[field].firstMatch
        guard picker.waitForExistence(timeout: 5) else {
            throw XCTSkip("This field is unavailable for the current ordinary output/provider")
        }
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: picker)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 10), .completed)
        let bounds = editor.frame
        picker.tap()
        let option = app.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        let start = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        start.name = field + "-open-start"; start.lifetime = .keepAlways; add(start)
        let began = Date()
        var samples = 0
        while Date().timeIntervalSince(began) < 12 {
            XCTAssertTrue(option.exists && option.isHittable, "Native menu disappeared during ordinary foreground updates")
            XCTAssertEqual(editor.frame.height, bounds.height, accuracy: 1)
            samples += 1
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        let end = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        end.name = field + "-open-end"; end.lifetime = .keepAlways; add(end)
        print("VOICE_MENU_STABILITY field=\(field) samples=\(samples) seconds=\(Date().timeIntervalSince(began)) setting_mutations=0")
        // Outside both menus, on the screen margin. Never select an option.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
    }

    func testOutputMenuSurvivesBackgroundRefresh() throws {
        try checkOpenMenu(field: "dj-settings-output", labels: ["Alleen tekst", "Text only"])
    }

    func testVoiceMenuSurvivesBackgroundRefresh() throws {
        try checkOpenMenu(field: "dj-settings-voice", labels: ["Providerstandaard", "Provider default"])
    }
}
