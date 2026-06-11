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

    func testPrimaryTabsAreAvailable() {
        let app = launchApp()

        XCTAssertTrue(app.tabBars.buttons["Speelt Nu"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.tabBars.buttons["Wachtrij"].exists)
        XCTAssertTrue(app.tabBars.buttons["Afspeellijsten"].exists)
        XCTAssertTrue(app.tabBars.buttons["Instellingen"].exists)
        XCTAssertTrue(app.tabBars.buttons["Over"].exists)
    }

    func testSettingsUsesMockHomeAssistantURLFixture() {
        let app = launchApp()

        app.tabBars.buttons["Instellingen"].tap()

        XCTAssertTrue(app.staticTexts["Home Assistant"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["URL"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields["URL"].value as? String, "http://127.0.0.1:8123")
    }
}
