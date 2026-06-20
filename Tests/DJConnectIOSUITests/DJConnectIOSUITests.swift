import XCTest

@MainActor
final class DJConnectIOSUITests: XCTestCase {
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["--uitesting", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"])
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = "http://127.0.0.1:8123"
        app.launch()
        return app
    }

    private func launchMonkeyApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["--monkey-testing", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"])
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = "http://127.0.0.1:8123"
        app.launch()
        return app
    }

    private func launchAskDJAirPlayDemoApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: [
            "--monkey-testing",
            "--on-air-demo-feed",
            "-AppleLanguages",
            "(nl)",
            "-AppleLocale",
            "nl_NL"
        ])
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = "http://127.0.0.1:8123"
        app.launch()
        return app
    }

    private func launchEnglishApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["--monkey-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = "http://127.0.0.1:8123"
        app.launch()
        return app
    }

    private func enterDemoModeIfNeeded(_ app: XCUIApplication) {
        for title in ["Demo modus starten", "Start Demo Mode"] {
            let demoButton = app.buttons[title]
            if demoButton.waitForExistence(timeout: 3) {
                demoButton.tap()
                return
            }
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

        let moreButton = app.tabBars.buttons["Meer"].exists ? app.tabBars.buttons["Meer"] : app.tabBars.buttons["More"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 3))
        moreButton.tap()

        let moreItem = app.buttons[title].exists ? app.buttons[title] : app.staticTexts[title]
        XCTAssertTrue(moreItem.waitForExistence(timeout: 3))
        moreItem.tap()
    }

    func testPrimaryTabsAreAvailable() {
        let app = launchApp()
        enterDemoModeIfNeeded(app)

        XCTAssertTrue(app.tabBars.buttons["Speelt Nu"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.tabBars.buttons["Wachtrij"].exists)
        XCTAssertTrue(app.tabBars.buttons["Afspeellijsten"].exists)
        XCTAssertTrue(app.tabBars.buttons["Meer"].exists || app.tabBars.buttons["More"].exists)

        let moreButton = app.tabBars.buttons["Meer"].exists ? app.tabBars.buttons["Meer"] : app.tabBars.buttons["More"]
        moreButton.tap()
        XCTAssertTrue(app.descendants(matching: .any)["Games"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["Instellingen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["Over"].exists)
    }

    func testEnglishDeviceLanguageUsesEnglishNavigationAndSettingsCopy() {
        let app = launchEnglishApp()

        XCTAssertTrue(app.tabBars.buttons["Now Playing"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.tabBars.buttons["Queue"].exists)
        XCTAssertTrue(app.tabBars.buttons["Playlists"].exists)
        XCTAssertTrue(app.tabBars.buttons["More"].exists)

        tapTabOrMoreItem("Settings", in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Language"].exists)
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

        tapTabOrMoreItem("Games", in: app)

        XCTAssertTrue(app.navigationBars["Games"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Paddle Rally"].exists || app.staticTexts["Paddle Rally"].exists)
        XCTAssertTrue(app.buttons["Meteor Run"].exists || app.staticTexts["Meteor Run"].exists)
        XCTAssertTrue(app.buttons["Sky Dash"].exists || app.staticTexts["Sky Dash"].exists)
        XCTAssertTrue(app.buttons["Maze Chase"].exists || app.staticTexts["Maze Chase"].exists)
        XCTAssertTrue(app.buttons["Tik om te spelen"].exists || app.staticTexts["Tik om te spelen"].exists)
    }

    func testAskDJAirPlayOutputInDemoModeScreenshots() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launchAskDJAirPlayDemoApp()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        tapTabOrMoreItem("Ask DJ", in: app)

        XCTAssertTrue(app.navigationBars["Ask DJ (demo)"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any)["AskDJAirPlayButton"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Verras de woonkamer met een track"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Ask DJ is On Air! Midnight City speelt in de woonkamer en Ask DJ is klaar voor het volgende verzoek."].waitForExistence(timeout: 4))

        try attachAndWriteScreenshot(app.screenshot(), named: "ask-dj-airplay-button")
        try attachAndWriteScreenshot(app.screenshot(), named: "ask-dj-live-feed")
    }

    func testMonkeyModeSafeNavigationSmoke() {
        let app = launchMonkeyApp()
        let argumentDuration = ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("--monkey-seconds=") }?
            .split(separator: "=", maxSplits: 1)
            .last
            .flatMap { TimeInterval($0) }
        let duration = argumentDuration
            ?? TimeInterval(ProcessInfo.processInfo.environment["DJCONNECT_MONKEY_SECONDS"] ?? "20")
            ?? 20
        let deadline = Date().addingTimeInterval(duration)
        let tabs = ["Speelt Nu", "Wachtrij", "Afspeellijsten", "Games", "Meer"]
        var index = 0

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))

        while Date() < deadline {
            let title = tabs[index % tabs.count]
            if app.tabBars.buttons[title].exists {
                app.tabBars.buttons[title].tap()
            }

            switch title {
            case "Speelt Nu":
                app.buttons.matching(identifier: "Druk op het microfoon icoon om een voorbeeld aankondiging te beluisteren").firstMatch.tapIfExists()
                app.buttons["Afspelen"].tapIfExists()
                app.buttons["Volgend nummer"].tapIfExists()
            case "Wachtrij":
                app.buttons["Tik om te spelen"].tapIfExists()
            case "Afspeellijsten":
                app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "DJConnect")).firstMatch.tapIfExists()
            case "Games":
                app.buttons["Tik om te spelen"].tapIfExists()
                app.buttons["Sky Dash"].tapIfExists()
                app.buttons["Tik om te spelen"].tapIfExists()
            case "Meer":
                app.staticTexts["Instellingen"].tapIfExists()
                app.buttons.firstMatch.tapIfExists()
                app.tabBars.buttons["Meer"].tapIfExists()
                app.staticTexts["Over"].tapIfExists()
                app.buttons.firstMatch.tapIfExists()
            default:
                break
            }

            index += 1
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        XCTAssertTrue(app.state == .runningForeground)
    }
}

private func attachAndWriteScreenshot(_ screenshot: XCUIScreenshot, named name: String) throws {
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    XCTContext.runActivity(named: name) { activity in
        activity.add(attachment)
    }

    let directory = ProcessInfo.processInfo.environment["DJCONNECT_SCREENSHOT_DIR"]
        .map(URL.init(fileURLWithPath:))
        ?? defaultScreenshotDirectory
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
}

private var defaultScreenshotDirectory: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("tmp")
        .appendingPathComponent("ask-dj-airplay-screenshots")
}

private extension XCUIElement {
    func tapIfExists() {
        if exists && isHittable {
            tap()
        }
    }
}
