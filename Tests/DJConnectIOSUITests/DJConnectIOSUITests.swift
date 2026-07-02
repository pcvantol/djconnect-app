import XCTest

@MainActor
final class DJConnectIOSUITests: XCTestCase {
    private var lastScreenshotPNG: Data?

    private struct ScreenshotScreen {
        let fileName: String
        let title: String
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["--uitesting", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"])
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = "http://127.0.0.1:8123"
        app.terminate()
        app.launch()
        return app
    }

    private func launchMonkeyApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["--uitesting", "--monkey-testing", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"])
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = "http://127.0.0.1:8123"
        app.terminate()
        app.launch()
        return app
    }

    private func launchEnglishApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["--uitesting", "--monkey-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = "http://127.0.0.1:8123"
        app.terminate()
        app.launch()
        return app
    }

    private func enterDemoModeIfNeeded(_ app: XCUIApplication) {
        if app.tabBars.firstMatch.waitForExistence(timeout: 3) {
            return
        }

        for dismissTitle in ["Niet nu", "Not now"] {
            let dismissButton = app.buttons[dismissTitle]
            if dismissButton.waitForExistence(timeout: 1), dismissButton.isHittable {
                dismissButton.tap()
                break
            }
        }

        if app.tabBars.firstMatch.waitForExistence(timeout: 2) {
            return
        }

        for title in ["Demo modus starten", "Start Demo Mode"] {
            let demoButton = app.buttons[title]
            if demoButton.waitForExistence(timeout: 6) {
                demoButton.tap()
                XCTAssertTrue(waitForAnyScreen(in: app, titles: ["Speelt Nu", "Now Playing"], timeout: 8))
                return
            }
        }
    }

    private func openSettings(_ app: XCUIApplication) {
        tapTabOrMoreItem("Instellingen", in: app)
    }

    private func tapTabOrMoreItem(_ title: String, in app: XCUIApplication) {
        returnToTabRoot(in: app)

        let tabButton = app.tabBars.buttons[title]
        if tabButton.waitForExistence(timeout: 2) {
            tabButton.tap()
            XCTAssertTrue(waitForScreen(title, in: app), "Expected \(title) to be visible after tapping its tab.")
            return
        }

        let moreButton = app.tabBars.buttons["Meer"].exists ? app.tabBars.buttons["Meer"] : app.tabBars.buttons["More"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 5))
        moreButton.tap()
        XCTAssertTrue(
            firstExistingElement(named: "Instellingen", in: app).waitForExistence(timeout: 5)
                || firstExistingElement(named: "Settings", in: app).waitForExistence(timeout: 5),
            "Expected More content to be visible before opening \(title)."
        )

        let moreScrollView = app.scrollViews.firstMatch
        if moreScrollView.waitForExistence(timeout: 1) {
            moreScrollView.swipeDown()
        }
        let moreItem = firstExistingElement(named: title, in: app)
        XCTAssertTrue(moreItem.waitForExistence(timeout: 5), "Expected \(title) to be available from More.")
        moreItem.tap()
        XCTAssertTrue(waitForScreen(title, in: app), "Expected \(title) to be visible after tapping it from More.")
    }

    private func returnToTabRoot(in app: XCUIApplication) {
        for _ in 0..<5 {
            if app.tabBars.firstMatch.exists {
                return
            }

            let navigationBackButton = app.navigationBars.buttons.element(boundBy: 0)
            if navigationBackButton.exists && navigationBackButton.isHittable {
                navigationBackButton.tap()
                RunLoop.current.run(until: Date().addingTimeInterval(0.35))
                continue
            }

            let backButton = app.buttons.matching(NSPredicate(format: "label IN %@", ["Back", "Terug"])).firstMatch
            if backButton.exists && backButton.isHittable {
                backButton.tap()
                RunLoop.current.run(until: Date().addingTimeInterval(0.35))
                continue
            }

            return
        }
    }

    private func waitForScreen(_ title: String, in app: XCUIApplication, timeout: TimeInterval = 6) -> Bool {
        waitForAnyScreen(in: app, titles: [title, "\(title) (demo)"], timeout: timeout)
    }

    private func waitForAnyScreen(in app: XCUIApplication, titles: [String], timeout: TimeInterval = 6) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for title in titles {
                if let identifier = screenIdentifier(for: title),
                   app.descendants(matching: .any)[identifier].exists {
                    return true
                }
                if app.navigationBars[title].exists
                    || app.staticTexts[title].exists
                    || app.otherElements[title].exists {
                    return true
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    private func screenIdentifier(for title: String) -> String? {
        switch title.replacingOccurrences(of: " (demo)", with: "") {
        case "Speelt Nu", "Now Playing":
            return "screen-now-playing"
        case "Wachtrij", "Queue":
            return "screen-queue"
        case "Afspeellijsten", "Playlists":
            return "screen-playlists"
        case "Ask DJ":
            return "screen-ask-dj"
        case "Track Insight":
            return "screen-track-insight"
        case "Music DNA":
            return "screen-music-dna"
        case "Games":
            return "screen-games"
        case "Instellingen", "Settings":
            return "screen-settings"
        case "Logs":
            return "screen-logs"
        case "Over", "About":
            return "screen-about"
        case "Juridisch", "Legal":
            return "screen-legal"
        case "Privacy":
            return "screen-privacy"
        default:
            return nil
        }
    }

    private func firstExistingElement(named title: String, in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons[title]
        if button.exists { return button }
        let staticText = app.staticTexts[title]
        if staticText.exists { return staticText }
        return app.descendants(matching: .any)[title]
    }

    private func waitForScreenshotScreen(_ screen: ScreenshotScreen, in app: XCUIApplication, timeout: TimeInterval = 8) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let demoTitle = "\(screen.title) (demo)"
            let titleVisible = app.navigationBars[screen.title].exists
                || app.staticTexts[screen.title].exists
                || app.navigationBars[demoTitle].exists
                || app.staticTexts[demoTitle].exists
            if titleVisible {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    private func captureVerifiedScreenshot(named name: String, allowDuplicate: Bool = false) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let png = screenshot.pngRepresentation
        if !allowDuplicate, let previous = lastScreenshotPNG {
            XCTAssertNotEqual(png, previous, "Screenshot \(name) is identical to the previous capture; navigation likely did not reach a new screen.")
        }
        try attachAndWriteScreenshot(screenshot, named: name)
        lastScreenshotPNG = png
    }

    func testPrimaryTabsAreAvailable() {
        let app = launchApp()
        enterDemoModeIfNeeded(app)

        XCTAssertTrue(app.tabBars.buttons["Speelt Nu"].waitForExistence(timeout: 10))
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

    func testJumpURLsNavigateToCorrectPagesOnIOS() throws {
        let app = launchMonkeyApp()
        enterDemoModeIfNeeded(app)

        let jumps = [
            ("djconnect://ask-dj", "Ask DJ"),
            ("djconnect://track-insight", "Track Insight"),
            ("djconnect://playlists", "Afspeellijsten"),
            ("djconnect://queue", "Wachtrij")
        ]

        for (url, title) in jumps {
            XCUIApplication().open(try XCTUnwrap(URL(string: url)))
            XCTAssertTrue(waitForScreen(title, in: app, timeout: 8), "Expected \(url) to open \(title).")
        }
    }

    func testScreenshotCleanupRemovesOnlyPNGFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let staleScreenshot = directory.appendingPathComponent("old-screen.png")
        let uppercaseScreenshot = directory.appendingPathComponent("old-screen.PNG")
        let metadata = directory.appendingPathComponent("README.md")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: staleScreenshot)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: uppercaseScreenshot)
        try Data("keep".utf8).write(to: metadata)

        try cleanScreenshotDirectory(at: directory)

        XCTAssertFalse(FileManager.default.fileExists(atPath: staleScreenshot.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: uppercaseScreenshot.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadata.path))
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

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 12))

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

    func testCaptureDemoScreenshots() throws {
        let app = launchMonkeyApp()
        enterDemoModeIfNeeded(app)

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 12))
        lastScreenshotPNG = nil
        try cleanScreenshotDirectory()

        let primaryScreens = [
            ScreenshotScreen(fileName: "01-now-playing", title: "Speelt Nu"),
            ScreenshotScreen(fileName: "02-queue", title: "Wachtrij"),
            ScreenshotScreen(fileName: "03-playlists", title: "Afspeellijsten"),
            ScreenshotScreen(fileName: "04-games", title: "Games")
        ]

        for screen in primaryScreens {
            tapTabOrMoreItem(screen.title, in: app)
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
            try captureVerifiedScreenshot(named: screen.fileName, allowDuplicate: screen.fileName == "01-now-playing")
        }

        let secondaryScreens = [
            ScreenshotScreen(fileName: "05-ask-dj", title: "Ask DJ"),
            ScreenshotScreen(fileName: "06-track-insight", title: "Track Insight"),
            ScreenshotScreen(fileName: "07-music-dna", title: "Music DNA"),
            ScreenshotScreen(fileName: "08-settings", title: "Instellingen"),
            ScreenshotScreen(fileName: "09-logs", title: "Logs"),
            ScreenshotScreen(fileName: "10-about", title: "Over"),
            ScreenshotScreen(fileName: "11-legal", title: "Juridisch"),
            ScreenshotScreen(fileName: "12-privacy", title: "Privacy")
        ]

        for screen in secondaryScreens {
            tapTabOrMoreItem(screen.title, in: app)
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
            try captureVerifiedScreenshot(named: screen.fileName)
        }
    }

    func testWalkDemoScreensForExternalScreenshots() {
        let app = launchMonkeyApp()
        enterDemoModeIfNeeded(app)

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 12))

        let screens = [
            "Speelt Nu",
            "Wachtrij",
            "Afspeellijsten",
            "Games",
            "Ask DJ",
            "Track Insight",
            "Music DNA",
            "Instellingen",
            "Logs",
            "Over",
            "Juridisch",
            "Privacy"
        ]

        for title in screens {
            tapTabOrMoreItem(title, in: app)
            RunLoop.current.run(until: Date().addingTimeInterval(3.0))
        }

        XCTAssertTrue(app.state == .runningForeground)
    }
}

@MainActor
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

@MainActor
private func cleanScreenshotDirectory() throws {
    let directory = ProcessInfo.processInfo.environment["DJCONNECT_SCREENSHOT_DIR"]
        .map(URL.init(fileURLWithPath:))
        ?? defaultScreenshotDirectory
    try cleanScreenshotDirectory(at: directory)
}

@MainActor
private func cleanScreenshotDirectory(at directory: URL) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let files = try fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    )
    for file in files where file.pathExtension.lowercased() == "png" {
        try fileManager.removeItem(at: file)
    }
}

private extension XCUIElement {
    func tapIfExists() {
        if exists && isHittable {
            tap()
        }
    }
}
