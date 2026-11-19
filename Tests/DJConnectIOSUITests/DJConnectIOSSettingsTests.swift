import XCTest

@MainActor
final class DJConnectIOSSettingsTests: XCTestCase {
    func testSettingsShowsRepairPairingAction() {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["--uitesting", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"])
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = "http://127.0.0.1:8123"
        app.terminate()
        app.launch()

        enterDemoModeIfNeeded(app)
        openSettings(app)

        XCTAssertTrue(app.staticTexts["Koppeling"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["App opnieuw koppelen"].exists)
    }

    private func enterDemoModeIfNeeded(_ app: XCUIApplication) {
        let demoButton = app.buttons["Demo modus starten"]
        if demoButton.waitForExistence(timeout: 3) {
            demoButton.tap()
        }
    }

    private func openSettings(_ app: XCUIApplication) {
        let tabButton = app.tabBars.buttons["Instellingen"]
        if tabButton.waitForExistence(timeout: 1) {
            tabButton.tap()
            return
        }

        let moreButton = app.tabBars.buttons["Meer"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 3))
        moreButton.tap()

        let settingsItem = app.buttons["Instellingen"].exists
            ? app.buttons["Instellingen"]
            : app.staticTexts["Instellingen"]
        XCTAssertTrue(settingsItem.waitForExistence(timeout: 3))
        settingsItem.tap()
    }
}
