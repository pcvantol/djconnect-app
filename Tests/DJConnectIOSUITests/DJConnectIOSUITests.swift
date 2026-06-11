import XCTest

@MainActor
final class DJConnectIOSUITests: XCTestCase {
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = "http://127.0.0.1:8123"
        app.launch()
        return app
    }

    private func enterDemoModeIfNeeded(_ app: XCUIApplication) {
        let demoButton = app.buttons["Demo modus starten"]
        if demoButton.waitForExistence(timeout: 2) {
            demoButton.tap()
        }
    }

    private func openSettings(_ app: XCUIApplication) {
        tapTabOrMoreItem("Instellingen", in: app)
    }

    private func tapTabOrMoreItem(_ title: String, in app: XCUIApplication) {
        let tabButton = app.tabBars.buttons[title]
        if tabButton.waitForExistence(timeout: 1) {
            tabButton.tap()
            return
        }

        let moreButton = app.tabBars.buttons["More"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 3))
        moreButton.tap()

        let moreItem = app.descendants(matching: .any)[title]
        XCTAssertTrue(moreItem.waitForExistence(timeout: 3))
        moreItem.tap()
    }

    func testPrimaryTabsAreAvailable() {
        let app = launchApp()
        enterDemoModeIfNeeded(app)

        XCTAssertTrue(app.tabBars.buttons["Speelt Nu"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.tabBars.buttons["Wachtrij"].exists)
        XCTAssertTrue(app.tabBars.buttons["Afspeellijsten"].exists)
        XCTAssertTrue(app.tabBars.buttons["Games"].exists)
        XCTAssertTrue(app.tabBars.buttons["More"].exists)

        app.tabBars.buttons["More"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Instellingen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["Over"].exists)
    }

    func testSettingsUsesMockHomeAssistantURLFixture() {
        let app = launchApp()
        enterDemoModeIfNeeded(app)

        openSettings(app)

        XCTAssertTrue(app.staticTexts["Home Assistant"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["URL"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields["URL"].value as? String, "http://127.0.0.1:8123")
    }

    func testGamesTabShowsLocalGameChoices() {
        let app = launchApp()
        enterDemoModeIfNeeded(app)

        app.tabBars.buttons["Games"].tap()

        XCTAssertTrue(app.navigationBars["Games (Demo modus)"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Pong"].exists || app.staticTexts["Pong"].exists)
        XCTAssertTrue(app.buttons["Asteroids"].exists || app.staticTexts["Asteroids"].exists)
        XCTAssertTrue(app.buttons["Fly"].exists || app.staticTexts["Fly"].exists)
    }
}
