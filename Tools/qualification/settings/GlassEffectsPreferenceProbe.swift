import XCTest

/// External runner against the ordinary signed app. Changes only the local
/// appearance preference, verifies relaunch persistence, then restores it.
@MainActor
final class GlassEffectsPreferenceProbe: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func openSettings(_ app: XCUIApplication) throws -> XCUIElement {
        app.activate()
        let dismiss = app.buttons.matching(NSPredicate(format: "label IN %@", ["Niet nu", "Not now"])).firstMatch
        if dismiss.waitForExistence(timeout: 1), dismiss.isHittable { dismiss.tap() }
        let toggle = app.switches["settings-glass-effects"].firstMatch
        if toggle.exists && toggle.isHittable { return toggle }
        let more = app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["Meer", "More"])).firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 15))
        more.tap()
        let settings = app.buttons.matching(NSPredicate(format: "label IN %@", ["Instellingen", "Settings"])).firstMatch
        if settings.waitForExistence(timeout: 3) { settings.tap() }
        else {
            let text = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["Instellingen", "Settings"])).firstMatch
            XCTAssertTrue(text.waitForExistence(timeout: 5)); text.tap()
        }
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        if !toggle.isHittable { app.swipeDown() }
        XCTAssertTrue(toggle.isHittable)
        return toggle
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    func testGlassPreferenceSurvivesOrdinaryRelaunch() throws {
        let app = XCUIApplication(bundleIdentifier: "dev.djconnect.ios")
        var toggle = try openSettings(app)
        let original = try XCTUnwrap(toggle.value as? String)
        defer {
            if let restored = try? openSettings(app), restored.value as? String != original { restored.tap() }
        }
        capture(app, "glass-original")
        toggle.tap()
        let changed = try XCTUnwrap(toggle.value as? String)
        XCTAssertNotEqual(changed, original)
        capture(app, "glass-toggled-immediately")
        app.terminate()
        app.launch()
        toggle = try openSettings(app)
        XCTAssertEqual(toggle.value as? String, changed)
        capture(app, "glass-preserved-after-ordinary-relaunch")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, original)
        capture(app, "glass-original-restored")
    }
}
