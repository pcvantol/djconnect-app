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

    private func launchFirstRunApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["--uitesting", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"])
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = "http://127.0.0.1:8123"
        app.launchEnvironment["DJCONNECT_UITEST_SHOW_WELCOME"] = "1"
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
        app.launchArguments.append(contentsOf: ["--uitesting", "--runtime-fixture", "ready", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = "http://127.0.0.1:8123"
        app.launchEnvironment["DJCONNECT_UITEST_RUNTIME_FIXTURE"] = "ready"
        app.terminate()
        app.launch()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        app.terminate()
        app.launch()
        return app
    }

    private func launchRuntimeFixtureApp(_ fixture: String, screen: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.terminate()
        var arguments = [
            "--uitesting",
            "--runtime-fixture",
            fixture,
            "--runtime-fixture=\(fixture)",
            "-DJCONNECTRuntimeFixture",
            fixture,
            "-AppleLanguages",
            "(nl)",
            "-AppleLocale",
            "nl_NL"
        ]
        if let screen {
            arguments.append("--screenshot-screen=\(screen)")
            arguments.append(contentsOf: ["-DJCONNECTScreenshotScreen", screen])
        }
        app.launchArguments = arguments
        app.launchEnvironment = [
            "DJCONNECT_UITEST_HA_URL": "http://127.0.0.1:8123",
            "DJCONNECT_UITEST_RUNTIME_FIXTURE": fixture
        ]
        app.launch()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        app.terminate()
        app.launch()
        return app
    }

    private func enterDemoModeIfNeeded(_ app: XCUIApplication) {
        for dismissTitle in ["Niet nu", "Not now"] {
            let dismissButton = app.buttons[dismissTitle]
            if dismissButton.waitForExistence(timeout: 1), dismissButton.isHittable {
                dismissButton.tap()
                break
            }
        }

        let demoButton = app.buttons["pairing-start-demo-button"]
        if demoButton.waitForExistence(timeout: 1) {
            demoButton.tap()
            XCTAssertTrue(waitForAnyScreen(in: app, titles: ["DJ-sessie", "DJ Session"], timeout: 8))
            return
        }

        for title in ["Demo modus starten", "Start Demo Mode"] {
            let demoButton = app.buttons[title]
            if demoButton.waitForExistence(timeout: 6) {
                demoButton.tap()
                XCTAssertTrue(waitForAnyScreen(in: app, titles: ["DJ-sessie", "DJ Session"], timeout: 8))
                return
            }
        }

        if app.tabBars.firstMatch.waitForExistence(timeout: 2) {
            return
        }
    }

    private func openSettings(_ app: XCUIApplication) {
        tapTabOrMoreItem("Instellingen", in: app)
    }

    private func openNowPlayingTab(_ app: XCUIApplication) {
        tapTabOrMoreItem("Speelt Nu", in: app)
        XCTAssertTrue(app.navigationBars["Speelt Nu"].waitForExistence(timeout: 5))
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

    private func waitForElementValue(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (element.value as? String)?.contains(text) == true {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    private func screenIdentifier(for title: String) -> String? {
        switch title.replacingOccurrences(of: " (demo)", with: "") {
        case "DJ-sessie", "DJ Session":
            return "screen-dj-session"
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
        case "Ontdek", "Discover":
            return "screen-discovery"
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

    private func firstElement(containing text: String, in app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(
            format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@ OR identifier CONTAINS[c] %@",
            text,
            text,
            text
        )
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    private func waitForText(_ text: String, in app: XCUIApplication, timeout: TimeInterval = 3) -> Bool {
        firstElement(containing: text, in: app).waitForExistence(timeout: timeout)
    }

    private func waitForRuntimeFixture(_ app: XCUIApplication, timeout: TimeInterval = 8) -> Bool {
        app.descendants(matching: .any)["uitest-runtime-fixture-active"].waitForExistence(timeout: timeout)
    }

    private func revealManualPairing(in app: XCUIApplication) {
        let manualToggle = app.buttons["pairing-manual-toggle"]
        if manualToggle.waitForExistence(timeout: 3), manualToggle.isHittable {
            manualToggle.tap()
        }
        XCTAssertTrue(app.textFields["pairing-home-assistant-url-field"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["pairing-code-field"].waitForExistence(timeout: 3))
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

        XCTAssertTrue(app.tabBars.buttons["DJ-sessie"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Ask DJ"].exists)
        XCTAssertTrue(app.tabBars.buttons["Track Insight"].exists)
        XCTAssertTrue(app.tabBars.buttons["Ontdek"].exists || app.tabBars.buttons["Discover"].exists)
        XCTAssertTrue(app.tabBars.buttons["Meer"].exists || app.tabBars.buttons["More"].exists)
    }

    func testFirstRunWelcomeDismissesToPairingFlow() {
        let app = launchFirstRunApp()

        XCTAssertTrue(app.descendants(matching: .any)["screen-welcome"].waitForExistence(timeout: 8))

        let dismissButton = app.buttons["welcome-dismiss-button"]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 3))
        dismissButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["screen-pairing"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["pairing-start-demo-button"].exists)
    }

    func testPairingManualEntryUsesLocalFixtureURLAndValidatesCode() {
        let app = launchApp()

        XCTAssertTrue(app.descendants(matching: .any)["screen-pairing"].waitForExistence(timeout: 8))
        revealManualPairing(in: app)

        let urlField = app.textFields["pairing-home-assistant-url-field"]
        XCTAssertEqual(urlField.value as? String, "http://127.0.0.1:8123")

        let codeField = app.textFields["pairing-code-field"]
        codeField.tap()
        codeField.typeText("123456")

        let submitButton = app.buttons["pairing-submit-button"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 3))
        XCTAssertTrue(submitButton.isEnabled)
    }

    func testPairingSuccessFixtureDismissesToRuntime() {
        let app = launchRuntimeFixtureApp("pairing_success")

        XCTAssertTrue(waitForRuntimeFixture(app))
        XCTAssertTrue(app.descendants(matching: .any)["screen-pairing"].waitForExistence(timeout: 8))
        let doneButton = app.buttons["Let's Rock!"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3))
        doneButton.tap()

        openNowPlayingTab(app)
        XCTAssertTrue(app.navigationBars["Speelt Nu"].waitForExistence(timeout: 8))
        XCTAssertTrue(waitForText("Fixture Track", in: app))
        XCTAssertTrue(waitForText("Fixture Artist", in: app))
    }

    func testRuntimeFixtureShowsPlaybackOutputQueueAndPlaylists() {
        let app = launchRuntimeFixtureApp("paired_runtime")

        XCTAssertTrue(waitForRuntimeFixture(app))
        openNowPlayingTab(app)
        XCTAssertTrue(app.navigationBars["Speelt Nu"].waitForExistence(timeout: 8))
        XCTAssertTrue(waitForText("Fixture Track", in: app))
        XCTAssertTrue(waitForText("Fixture Artist", in: app))
        XCTAssertTrue(waitForText("Fixture Living Room", in: app))
        let favoriteButton = app.buttons.matching(identifier: "now-playing-favorite-button")
            .matching(NSPredicate(format: "label == %@", "Zet in favorieten"))
            .firstMatch
        XCTAssertTrue(favoriteButton.waitForExistence(timeout: 3))
        XCTAssertEqual(favoriteButton.label, "Zet in favorieten")

        tapTabOrMoreItem("Wachtrij", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["screen-queue"].waitForExistence(timeout: 8))
        XCTAssertTrue(waitForText("Fixture Next", in: app))
        XCTAssertTrue(waitForText("Fixture Artist Two", in: app))

        tapTabOrMoreItem("Afspeellijsten", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["screen-playlists"].waitForExistence(timeout: 8))
        XCTAssertTrue(waitForText("Fixture Playlist", in: app))
        XCTAssertTrue(waitForText("Fixture Dinner", in: app))
    }

    func testRuntimeFixtureShowsBackendUnavailableRecoveryState() {
        let app = launchRuntimeFixtureApp("backend_unavailable")

        openNowPlayingTab(app)
        XCTAssertTrue(app.navigationBars["Speelt Nu"].waitForExistence(timeout: 8))
        XCTAssertTrue(waitForText("Fixture Track", in: app))
        XCTAssertTrue(waitForText("muziekbackend", in: app))
    }

    func testRuntimeFixtureShowsStaleAuthPairingRecovery() {
        let app = launchRuntimeFixtureApp("stale_auth")

        XCTAssertTrue(app.descendants(matching: .any)["uitest-runtime-fixture-stale_auth"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["screen-pairing"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["pairing-start-demo-button"].exists)
    }

    func testRuntimeFixtureShowsVersionMismatchGate() {
        let app = launchRuntimeFixtureApp("version_mismatch")

        XCTAssertTrue(waitForText("Update vereist", in: app, timeout: 8))
        XCTAssertTrue(waitForText("Fixture update required", in: app))
        XCTAssertTrue(waitForText("Playback, wachtrij", in: app))
    }

    func testRuntimeFixtureShowsVoiceUnavailableStateInAskDJ() {
        let app = launchRuntimeFixtureApp("voice_unavailable")

        openNowPlayingTab(app)
        XCTAssertTrue(app.navigationBars["Speelt Nu"].waitForExistence(timeout: 8))
        tapTabOrMoreItem("Ask DJ", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["screen-ask-dj"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["uitest-runtime-fixture-voice_unavailable"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["uitest-voice-unavailable"].waitForExistence(timeout: 3))
    }

    func testDemoModeCanExitBackToPairingFlow() {
        let app = launchApp()
        enterDemoModeIfNeeded(app)

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        openSettings(app)

        let stopDemoButton = app.buttons["Demo modus stoppen"]
        XCTAssertTrue(stopDemoButton.waitForExistence(timeout: 3))
        stopDemoButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["screen-pairing"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["pairing-start-demo-button"].exists)
    }

    func testRuntimeSettingsExposeCompactPermissionRows() {
        let app = launchApp()
        enterDemoModeIfNeeded(app)

        openSettings(app)

        XCTAssertTrue(app.descendants(matching: .any)["settings-permission-notifications"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["settings-permission-microphone"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings-permission-speech"].exists)
    }

    func testEnglishDeviceLanguageUsesEnglishNavigationAndSettingsCopy() {
        let app = launchEnglishApp()
        enterDemoModeIfNeeded(app)

        XCTAssertTrue(app.tabBars.buttons["DJ Session"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.tabBars.buttons["Ask DJ"].exists)
        XCTAssertTrue(app.tabBars.buttons["Track Insight"].exists)
        XCTAssertTrue(app.tabBars.buttons["More"].exists)
        app.tabBars.buttons["More"].tap()
        XCTAssertTrue(app.buttons["Now Playing"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Queue"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Playlists"].firstMatch.exists)

        tapTabOrMoreItem("Settings", in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["App Language"].exists)
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

    func testGamesSurfaceRespondsToHardwareKeyboardArrowKeys() {
        let app = launchMonkeyApp()
        enterDemoModeIfNeeded(app)

        tapTabOrMoreItem("Games", in: app)

        let state = app.descendants(matching: .any)["games-state"]
        XCTAssertTrue(state.waitForExistence(timeout: 3))
        XCTAssertTrue((state.value as? String)?.contains("game=pong") == true)
        XCTAssertTrue((state.value as? String)?.contains("paddle_y=86") == true)

        let surface = app.descendants(matching: .any)["games-surface"]
        XCTAssertTrue(surface.waitForExistence(timeout: 3))
        surface.tap()
        XCTAssertTrue(waitForElementValue(state, containing: "playing=true", timeout: 3))

        app.typeKey(.upArrow, modifierFlags: [])

        XCTAssertTrue(waitForElementValue(state, containing: "paddle_y=74", timeout: 3))
    }

    func testJumpURLsNavigateToCorrectPagesOnIOS() throws {
        let app = launchMonkeyApp()
        enterDemoModeIfNeeded(app)

        let jumps = [
            ("djconnect://ask-dj", "Ask DJ"),
            ("djconnect://track-insight", "Track Insight"),
            ("djconnect://discover", "Ontdek"),
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
        let tabs = ["DJ-sessie", "Ask DJ", "Track Insight", "Ontdek", "Meer"]
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
            case "Ontdek":
                app.buttons["Ververs Ontdek"].tapIfExists()
            case "Meer":
                app.staticTexts["Wachtrij"].tapIfExists()
                app.buttons.firstMatch.tapIfExists()
                app.tabBars.buttons["Meer"].tapIfExists()
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
            ScreenshotScreen(fileName: "07-discover", title: "Ontdek"),
            ScreenshotScreen(fileName: "08-music-dna", title: "Music DNA"),
            ScreenshotScreen(fileName: "09-settings", title: "Instellingen"),
            ScreenshotScreen(fileName: "10-logs", title: "Logs"),
            ScreenshotScreen(fileName: "11-about", title: "Over"),
            ScreenshotScreen(fileName: "12-legal", title: "Juridisch"),
            ScreenshotScreen(fileName: "13-privacy", title: "Privacy")
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
            "Ontdek",
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
    func testMomentFirstSessionAndIndependentPlayerNavigation() async throws {
        let base = URL(string: "http://127.0.0.1:18787")!
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/native_reset"))
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["--uitesting", "--runtime-fixture", "moment_contract", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = base.absoluteString
        app.launchEnvironment["DJCONNECT_UITEST_RUNTIME_FIXTURE"] = "moment_contract"
        app.launch()
        try await Task.sleep(for: .milliseconds(400))
        app.terminate()
        app.launch()
        guard app.descendants(matching: .any)["uitest-runtime-fixture-active"].waitForExistence(timeout: 10) else {
            XCTFail("The isolated runtime fixture was not activated; no navigation actions performed.")
            return
        }
        XCTAssertTrue(app.staticTexts["Even meekijken in de credits: Nora Vale en Sam Reed zijn hier als producers gecrediteerd."].waitForExistence(timeout: 15))
        try saveMomentScreenshot(app, "ios-01-moment")
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/advance"))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", "Nora Vale kwamen we eerder tegen bij «Amber Lines», als producer. Bij «Slow Lanterns» staat die naam opnieuw in de producercredits.")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["moment-source-https://musicbrainz.org/recording/00000000-0000-0000-0000-000000000002"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["moment-source-https://musicbrainz.org/recording/00000000-0000-0000-0000-000000000001"].exists)
        try saveMomentScreenshot(app, "ios-02-next-moment")
        if app.frame.width > 600 {
            XCUIDevice.shared.orientation = .landscapeLeft
            let landscapeDeadline = Date().addingTimeInterval(8)
            while app.frame.width <= app.frame.height, Date() < landscapeDeadline {
                try await Task.sleep(for: .milliseconds(200))
            }
            XCTAssertGreaterThan(app.frame.width, app.frame.height)
            try await Task.sleep(for: .seconds(1))
            XCTAssertTrue(app.staticTexts["Slow Lanterns"].firstMatch.waitForExistence(timeout: 8))
            XCTAssertTrue(app.buttons["Meer"].firstMatch.isHittable, "Standalone player navigation must remain visible in landscape.")
            try saveMomentScreenshot(app, "ios-02a-moment-landscape")
            XCUIDevice.shared.orientation = .portrait
            let portraitDeadline = Date().addingTimeInterval(8)
            while app.frame.width >= app.frame.height, Date() < portraitDeadline {
                try await Task.sleep(for: .milliseconds(200))
            }
            XCTAssertLessThan(app.frame.width, app.frame.height)
        }
        XCUIDevice.shared.press(.home)
        app.activate()
        try await Task.sleep(for: .seconds(2))
        XCTAssertTrue(app.staticTexts["Slow Lanterns"].firstMatch.waitForExistence(timeout: 10))
        let more = app.tabBars.buttons["Meer"].exists ? app.tabBars.buttons["Meer"] : app.buttons["Meer"].firstMatch
        more.tap()
        app.buttons["Speelt Nu"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Speelt Nu"].waitForExistence(timeout: 6))
        try saveMomentScreenshot(app, "ios-03-player-active-session")
        let sessionTab = app.tabBars.buttons["DJ-sessie"].exists ? app.tabBars.buttons["DJ-sessie"] : app.buttons["DJ-sessie"].firstMatch
        sessionTab.tap()
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/expire"))
        XCTAssertTrue(app.staticTexts["Slow Lanterns"].firstMatch.waitForExistence(timeout: 10))
        try await Task.sleep(for: .seconds(1))
        XCTAssertFalse(app.staticTexts["Even meekijken in de credits: Nora Vale en Sam Reed zijn hier als producers gecrediteerd."].exists)
        XCTAssertFalse(app.descendants(matching: .any)["moment-source-https://musicbrainz.org/recording/00000000-0000-0000-0000-000000000002"].exists)
        try saveMomentScreenshot(app, "ios-03a-source-expiry")
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/reconnect"))
        try await Task.sleep(for: .seconds(2))
        XCTAssertTrue(app.staticTexts["Slow Lanterns"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["moment-source-https://musicbrainz.org/recording/00000000-0000-0000-0000-000000000002"].exists)
        let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/metrics"))
        let metrics = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(metrics["playbackMutations"] as? Int, 0)
        XCTAssertEqual(metrics["ended"] as? Bool, false)
        app.buttons["Sessie beëindigen"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Start DJ-sessie"].waitForExistence(timeout: 10))
        more.tap()
        app.buttons["Speelt Nu"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Speelt Nu"].waitForExistence(timeout: 6))
        try saveMomentScreenshot(app, "ios-04-player-ended-session")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Start DJ-sessie"].waitForExistence(timeout: 10))
        let freshMore = app.tabBars.buttons["Meer"].exists ? app.tabBars.buttons["Meer"] : app.buttons["Meer"].firstMatch
        freshMore.tap()
        app.buttons["Speelt Nu"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Speelt Nu"].waitForExistence(timeout: 6))
        try saveMomentScreenshot(app, "ios-05-player-no-session")
    }

    func testAuthorizedFlowDetailAndOpenSourceExpiry() async throws {
        let base = URL(string: "http://127.0.0.1:18787")!
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/native_reset"))
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["--uitesting", "--runtime-fixture", "moment_contract", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = base.absoluteString
        app.launchEnvironment["DJCONNECT_UITEST_RUNTIME_FIXTURE"] = "moment_contract"
        app.launch()
        try await Task.sleep(for: .milliseconds(400))
        app.terminate()
        app.launch()
        guard app.descendants(matching: .any)["uitest-runtime-fixture-active"].waitForExistence(timeout: 10) else {
            XCTFail("The isolated runtime fixture was not activated; no navigation actions performed.")
            return
        }
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/advance"))
        let secondText = "Nora Vale kwamen we eerder tegen bij «Amber Lines», als producer. Bij «Slow Lanterns» staat die naam opnieuw in de producercredits."
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", secondText)).firstMatch.waitForExistence(timeout: 10))
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Even de credits erbij")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Even meekijken in de credits: Nora Vale en Sam Reed zijn hier als producers gecrediteerd."].waitForExistence(timeout: 5))
        try saveMomentScreenshot(app, "ios-02b-active-flow-recall")
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/expire"))
        try await Task.sleep(for: .seconds(1))
        XCTAssertFalse(app.staticTexts["Even meekijken in de credits: Nora Vale en Sam Reed zijn hier als producers gecrediteerd."].exists)
    }

    func testSpotifyCurrentAttributionAndSourceExpiry() async throws {
        let base = URL(string: "http://127.0.0.1:18787")!
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/spotify_reset"))
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["--uitesting", "--runtime-fixture", "moment_contract", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = base.absoluteString
        app.launchEnvironment["DJCONNECT_UITEST_RUNTIME_FIXTURE"] = "moment_contract"
        app.launch()
        try await Task.sleep(for: .milliseconds(400))
        app.terminate()
        app.launch()
        guard app.descendants(matching: .any)["uitest-runtime-fixture-active"].waitForExistence(timeout: 10) else {
            XCTFail("The isolated runtime fixture was not activated; no navigation actions performed.")
            return
        }
        let body = "A little date beside this edition of Test edition: Spotify lists 2001-03-04."
        XCTAssertTrue(app.staticTexts[body].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "value == %@", "https://open.spotify.com/album/BBBBBBBBBBBBBBBBBBBBBB")).firstMatch.exists)
        try saveMomentScreenshot(app, "ios-06-spotify-current")
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/expire"))
        try await Task.sleep(for: .seconds(1))
        XCTAssertFalse(app.staticTexts[body].exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "value == %@", "https://open.spotify.com/album/BBBBBBBBBBBBBBBBBBBBBB")).firstMatch.exists)
        try saveMomentScreenshot(app, "ios-07-spotify-expired")
    }

    func testNativeLargeTextAccessibilityAudit() async throws {
        let base = URL(string: "http://127.0.0.1:18787")!
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/native_reset"))
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--runtime-fixture", "moment_contract", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = base.absoluteString
        app.launchEnvironment["DJCONNECT_UITEST_RUNTIME_FIXTURE"] = "moment_contract"
        app.terminate(); app.launch()
        try await Task.sleep(for: .milliseconds(400))
        app.terminate(); app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["uitest-runtime-fixture-active"].waitForExistence(timeout: 10))
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/advance"))
        let text = "Nora Vale kwamen we eerder tegen bij «Amber Lines», als producer. Bij «Slow Lanterns» staat die naam opnieuw in de producercredits."
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", text)).firstMatch.waitForExistence(timeout: 10))
        try saveMomentScreenshot(app, "ios-08-large-text")
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .textClipped, .trait])
    }

    func testNativeReduceMotionPreferenceAndFlowNavigation() async throws {
        let base = URL(string: "http://127.0.0.1:18787")!
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/native_reset"))
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["--uitesting", "--uitest-reduce-motion", "--runtime-fixture", "moment_contract", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = base.absoluteString
        app.launchEnvironment["DJCONNECT_UITEST_RUNTIME_FIXTURE"] = "moment_contract"
        app.launch()
        try await Task.sleep(for: .milliseconds(400))
        app.terminate()
        app.launch()
        guard app.descendants(matching: .any)["uitest-runtime-fixture-active"].waitForExistence(timeout: 10) else {
            XCTFail("The isolated runtime fixture was not activated; no navigation actions performed.")
            return
        }
        XCTAssertTrue(app.descendants(matching: .any)["uitest-renderer-reduce-motion-on"].waitForExistence(timeout: 5))
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/advance"))
        let secondText = "Nora Vale kwamen we eerder tegen bij «Amber Lines», als producer. Bij «Slow Lanterns» staat die naam opnieuw in de producercredits."
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", secondText)).firstMatch.waitForExistence(timeout: 10))
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Even de credits erbij")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Even meekijken in de credits: Nora Vale en Sam Reed zijn hier als producers gecrediteerd."].waitForExistence(timeout: 5))
        try saveMomentScreenshot(app, "ios-09-reduced-motion-flow")
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/expire"))
        try await Task.sleep(for: .seconds(1))
        XCTAssertFalse(app.staticTexts["Even meekijken in de credits: Nora Vale en Sam Reed zijn hier als producers gecrediteerd."].exists)
    }

    private func saveMomentScreenshot(_ app: XCUIApplication, _ name: String) throws {
        let name = app.frame.width > 600 ? name.replacingOccurrences(of: "ios-", with: "ipad-") : name
        // Device capture avoids XCTest's landscape application-bounds crop.
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("build/moment-first/screenshots")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try screenshot.pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"))
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

extension DJConnectIOSUITests {
    func testActualCoreConversationArchiveSearchAndIndependentPlayer() async throws {
        let base = URL(string: "http://127.0.0.1:18194")!
        func control(_ operation: String) async throws {
            var request = URLRequest(url: base.appendingPathComponent("__apple_fixture/" + operation))
            request.httpMethod = "POST"; request.setValue("Bearer synthetic-fixture-token", forHTTPHeaderField: "Authorization")
            let (_, response) = try await URLSession.shared.data(for: request)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        }
        var authRequest = URLRequest(url: base.appendingPathComponent("__apple_fixture/state"))
        authRequest.setValue("Bearer synthetic-fixture-token", forHTTPHeaderField: "Authorization")
        let (authData, _) = try await URLSession.shared.data(for: authRequest)
        let labAuth = try XCTUnwrap(JSONSerialization.jsonObject(with: authData) as? [String: Any])
        let websocketToken = try XCTUnwrap(labAuth["websocket_access_token"] as? String)
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["--uitesting", "--runtime-fixture=session_history_contract", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = base.absoluteString
        app.launchEnvironment["DJCONNECT_UITEST_RUNTIME_FIXTURE"] = "session_history_contract"
        app.launchEnvironment["DJCONNECT_UITEST_HA_WS_TOKEN"] = websocketToken
        app.launch()
        try await Task.sleep(for: .milliseconds(400))
        app.terminate()
        try await control("start")
        var request = URLRequest(url: URL(string: base.absoluteString + "/api/djconnect/v1/session/active?device_id=djconnect-ios-ABCDEF123456&client_type=ios")!)
        request.setValue("Bearer synthetic-fixture-token", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let session = try XCTUnwrap(envelope["session"] as? [String: Any])
        let sessionID = try XCTUnwrap(session["session_id"] as? String)
        request.url = URL(string: base.absoluteString + "/api/djconnect/v1/session/history/" + sessionID + "?device_id=djconnect-ios-ABCDEF123456&client_type=ios&window=tail")!
        let (timelineData, _) = try await URLSession.shared.data(for: request)
        let timeline = try XCTUnwrap(JSONSerialization.jsonObject(with: timelineData) as? [String: Any])
        let entries = try XCTUnwrap(timeline["entries"] as? [[String: Any]])
        let moment = try XCTUnwrap(entries.first { $0["kind"] as? String == "dj_moment" })
        let entryID = try XCTUnwrap(moment["entry_id"] as? String)
        let momentText = try XCTUnwrap(moment["text"] as? String)
        app.launch()
        if app.buttons["Niet nu"].waitForExistence(timeout: 2) { app.buttons["Niet nu"].tap() }
        guard app.descendants(matching: .any)["uitest-runtime-fixture-active"].waitForExistence(timeout: 10),
              app.descendants(matching: .any)["screen-session-conversation"].waitForExistence(timeout: 15) else {
            XCTFail("Actual loopback fixture/timeline was not activated; no mock or stale screen acceptance."); return
        }
        XCTAssertTrue(app.staticTexts[momentText].firstMatch.exists)
        try saveHistoryScreenshot("ios-history-01-live-moment")
        app.buttons["session-search-toggle"].tap()
        let momentSearch = app.textFields["session-search-field"]
        momentSearch.tap(); momentSearch.typeText("geleidelijk\n")
        let selected = app.buttons["ask-entry-" + entryID]
        let selectableMoment = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: selected)
        guard selected.waitForExistence(timeout: 15), await XCTWaiter.fulfillment(of: [selectableMoment], timeout: 15) == .completed else {
            XCTFail("Canonical Moment search/anchor was not reached."); return
        }
        selected.tap()
        app.buttons["Zoeken sluiten"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["session-question-context"].waitForExistence(timeout: 5))
        let input = app.textViews.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5)); input.tap(); input.typeText("Vertel over deze bijdrage")
        guard app.buttons["ask-dj-composer-send"].isEnabled else {
            XCTFail("Authorized conversation composer is disabled; native draft: " + (input.value as? String ?? "unavailable")); return
        }
        app.buttons["ask-dj-composer-send"].tap()
        guard app.staticTexts["Deze bijdrage: " + momentText].firstMatch.waitForExistence(timeout: 15) else {
            XCTFail("No confirmed native reply; diagnostic only, not acceptance."); return
        }
        try saveHistoryScreenshot("ios-history-02-confirmed-text-turn")
        app.buttons["session-search-toggle"].tap()
        let search = app.textFields["session-search-field"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("ONE")
        XCTAssertTrue(app.staticTexts["session-search-count"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["One · Metallica · …And Justice for All"].firstMatch.waitForExistence(timeout: 10))
        try saveHistoryScreenshot("ios-history-03-search-beyond-loaded-page")
        app.buttons["Zoeken sluiten"].firstMatch.tap()
        if app.frame.width > 600 {
            XCUIDevice.shared.orientation = .landscapeLeft
            try await Task.sleep(for: .seconds(1))
            try saveHistoryScreenshot("ipad-history-04-landscape")
            XCUIDevice.shared.orientation = .portrait
        }
        let more = app.tabBars.buttons["Meer"].exists ? app.tabBars.buttons["Meer"] : app.buttons["Meer"].firstMatch
        more.tap(); app.buttons["Speelt Nu"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Speelt Nu"].waitForExistence(timeout: 5))
        try saveHistoryScreenshot("ios-history-05-player-during-session")
        let tab = app.tabBars.buttons["DJ-sessie"].exists ? app.tabBars.buttons["DJ-sessie"] : app.buttons["DJ-sessie"].firstMatch
        tab.tap()
        let end = app.buttons["session-end-button"]
        XCTAssertTrue(end.isHittable); end.tap()
        XCTAssertTrue(app.buttons["Start DJ-sessie"].waitForExistence(timeout: 15))
        try await control("restart")
        more.tap(); app.buttons["Eerdere sessies"].firstMatch.tap()
        let saved = app.buttons["saved-session-" + sessionID]
        XCTAssertTrue(saved.waitForExistence(timeout: 10)); saved.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-history-timeline"].waitForExistence(timeout: 10))
        try saveHistoryScreenshot("ios-history-06-readonly-after-server-restart")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Start DJ-sessie"].waitForExistence(timeout: 10))
        let ask = app.tabBars.buttons["Ask DJ"].exists ? app.tabBars.buttons["Ask DJ"] : app.buttons["Ask DJ"].firstMatch
        ask.tap()
        let question = app.textViews.firstMatch
        XCTAssertTrue(question.waitForExistence(timeout: 5))
        let generalQuestion = "Wat heb ik eerder geluisterd? Clientproef " + UUID().uuidString
        question.tap(); question.typeText(generalQuestion)
        app.buttons["ask-dj-composer-send"].tap()
        XCTAssertTrue(app.staticTexts[generalQuestion].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Ik zie geen Spotify tracks die het afgelopen uur zijn afgespeeld."].firstMatch.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Ask DJ offline"].exists)
        try saveHistoryScreenshot("ios-history-14-general-text-without-audio")
        question.tap(); question.typeText("Wanneer heb ik eerder naar Metallica geluisterd?")
        app.buttons["ask-dj-composer-send"].tap()
        let openButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "open-session-"))
        guard openButtons.firstMatch.waitForExistence(timeout: 15) else {
            XCTFail("No backend-confirmed historical match with Open session action"); return
        }
        guard let open = openButtons.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            XCTFail("No visible historical match action"); return
        }
        let expectedAnchor = String(open.identifier.dropFirst("open-session-".count))
        try saveHistoryScreenshot("ios-history-07-real-historical-matches")
        open.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-history-timeline"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["session-entry-" + expectedAnchor].waitForExistence(timeout: 10))
        let anchorButton = app.buttons["ask-entry-" + expectedAnchor]
        let visibleAnchor = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: anchorButton)
        let anchorResult = await XCTWaiter.fulfillment(of: [visibleAnchor], timeout: 8)
        XCTAssertEqual(anchorResult, .completed, "Open session must place its exact backend entry on screen")
        try saveHistoryScreenshot("ios-history-08-open-matched-entry")
    }

    func testActualCoreArchiveAndPlayerNavigationPreservesSessionB() async throws {
        let base = URL(string: "http://127.0.0.1:18194")!
        func control(_ operation: String, method: String = "POST") async throws -> [String: Any] {
            var request = URLRequest(url: base.appendingPathComponent("__apple_fixture/" + operation))
            request.httpMethod = method; request.setValue("Bearer synthetic-fixture-token", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        func activeID() async throws -> String? {
            let state = try await control("state", method: "GET")
            return (state["active"] as? [String: Any])?["session_id"] as? String
        }
        let auth = try await control("state", method: "GET")
        let app = XCUIApplication(); app.terminate()
        app.launchArguments = ["--uitesting", "--runtime-fixture=session_history_contract", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = base.absoluteString
        app.launchEnvironment["DJCONNECT_UITEST_RUNTIME_FIXTURE"] = "session_history_contract"
        app.launchEnvironment["DJCONNECT_UITEST_HA_WS_TOKEN"] = try XCTUnwrap(auth["websocket_access_token"] as? String)
        app.launch(); try await Task.sleep(for: .milliseconds(400)); app.terminate()
        let a = try await control("start")
        let sessionA = try XCTUnwrap((a["active"] as? [String: Any])?["session_id"] as? String)
        _ = try await control("end"); _ = try await control("restart")
        let b = try await control("start")
        let sessionB = try XCTUnwrap((b["active"] as? [String: Any])?["session_id"] as? String)
        XCTAssertNotEqual(sessionA, sessionB)
        app.launch()
        guard app.descendants(matching: .any)["screen-session-conversation"].waitForExistence(timeout: 15) else {
            XCTFail("Actual current Session B was not rendered"); return
        }
        let more = app.tabBars.buttons["Meer"].exists ? app.tabBars.buttons["Meer"] : app.buttons["Meer"].firstMatch
        more.tap(); app.buttons["Eerdere sessies"].firstMatch.tap()
        let savedA = app.buttons["saved-session-" + sessionA]
        guard savedA.waitForExistence(timeout: 10) else { XCTFail("Ended Session A missing from real archive"); return }
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(savedA.waitForExistence(timeout: 15), "Visible archive must reload after background")
        savedA.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-history-timeline"].waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home); app.activate()
        let restoredEntry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ask-entry-")).firstMatch
        XCTAssertTrue(restoredEntry.waitForExistence(timeout: 15), "Visible readonly timeline must reload after background")
        let readback1 = try await activeID()
        XCTAssertEqual(readback1, sessionB)
        try saveHistoryScreenshot("ios-history-09-readonly-A-while-B-active")
        let dj = app.tabBars.buttons["DJ-sessie"].exists ? app.tabBars.buttons["DJ-sessie"] : app.buttons["DJ-sessie"].firstMatch
        dj.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-session-conversation"].waitForExistence(timeout: 10))
        let readback2 = try await activeID()
        XCTAssertEqual(readback2, sessionB)
        more.tap(); app.buttons["Speelt Nu"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Speelt Nu"].waitForExistence(timeout: 5))
        let readback3 = try await activeID()
        XCTAssertEqual(readback3, sessionB)
        try saveHistoryScreenshot("ios-history-10-player-preserves-B")
        _ = try await control("end")
        dj.tap()
        XCTAssertTrue(app.buttons["Start DJ-sessie"].waitForExistence(timeout: 15))
        more.tap(); app.buttons["Speelt Nu"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Speelt Nu"].waitForExistence(timeout: 5))
        let finalReadback = try await activeID()
        XCTAssertNil(finalReadback)
        try saveHistoryScreenshot("ios-history-11-player-without-session")
    }

    func testActualCoreSessionHistoryLongDraftRemainsReachable() async throws {
        let base = URL(string: "http://127.0.0.1:18194")!
        var request = URLRequest(url: base.appendingPathComponent("__apple_fixture/start"))
        request.httpMethod = "POST"
        request.setValue("Bearer synthetic-fixture-token", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--runtime-fixture=session_history_contract", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = base.absoluteString
        app.launchEnvironment["DJCONNECT_UITEST_RUNTIME_FIXTURE"] = "session_history_contract"
        app.launch()
        if app.buttons["Niet nu"].waitForExistence(timeout: 2) { app.buttons["Niet nu"].tap() }
        XCTAssertTrue(app.descendants(matching: .any)["screen-session-conversation"].waitForExistence(timeout: 15))
        let input = app.textViews["ask-dj-composer-input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        let draft = (1...12).map { "Regel \($0) over de bijdrage" }.joined(separator: "\n") + "\nLaatste zichtbare regel"
        input.typeText(draft)
        XCTAssertEqual(input.value as? String, draft)
        XCTAssertTrue(app.buttons["ask-dj-composer-send"].isEnabled)
        try saveHistoryScreenshot("ios-history-13-long-draft-keyboard")
        app.terminate()
        request.url = base.appendingPathComponent("__apple_fixture/end")
        _ = try await URLSession.shared.data(for: request)
    }

    func testActualCoreSessionHistoryNativeAccessibility() async throws {
        let base = URL(string: "http://127.0.0.1:18194")!
        func control(_ operation: String) async throws {
            var request = URLRequest(url: base.appendingPathComponent("__apple_fixture/" + operation))
            request.httpMethod = "POST"; request.setValue("Bearer synthetic-fixture-token", forHTTPHeaderField: "Authorization")
            let (_, response) = try await URLSession.shared.data(for: request)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        }
        var authRequest = URLRequest(url: base.appendingPathComponent("__apple_fixture/state"))
        authRequest.setValue("Bearer synthetic-fixture-token", forHTTPHeaderField: "Authorization")
        let (authData, _) = try await URLSession.shared.data(for: authRequest)
        let labAuth = try XCTUnwrap(JSONSerialization.jsonObject(with: authData) as? [String: Any])
        let websocketToken = try XCTUnwrap(labAuth["websocket_access_token"] as? String)
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["--uitesting", "--runtime-fixture=session_history_contract", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = base.absoluteString
        app.launchEnvironment["DJCONNECT_UITEST_RUNTIME_FIXTURE"] = "session_history_contract"
        app.launchEnvironment["DJCONNECT_UITEST_HA_WS_TOKEN"] = websocketToken
        app.launch()
        try await Task.sleep(for: .milliseconds(400))
        app.terminate()
        try await control("start")
        var request = URLRequest(url: URL(string: base.absoluteString + "/api/djconnect/v1/session/active?device_id=djconnect-ios-ABCDEF123456&client_type=ios")!)
        request.setValue("Bearer synthetic-fixture-token", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let session = try XCTUnwrap(envelope["session"] as? [String: Any])
        let sessionID = try XCTUnwrap(session["session_id"] as? String)
        request.url = URL(string: base.absoluteString + "/api/djconnect/v1/session/history/" + sessionID + "?device_id=djconnect-ios-ABCDEF123456&client_type=ios&window=tail")!
        let (timelineData, _) = try await URLSession.shared.data(for: request)
        let timeline = try XCTUnwrap(JSONSerialization.jsonObject(with: timelineData) as? [String: Any])
        let entries = try XCTUnwrap(timeline["entries"] as? [[String: Any]])
        let moment = try XCTUnwrap(entries.first { $0["kind"] as? String == "dj_moment" })
        let momentText = try XCTUnwrap(moment["text"] as? String)
        app.launch()
        if app.buttons["Niet nu"].waitForExistence(timeout: 2) { app.buttons["Niet nu"].tap() }
        guard app.descendants(matching: .any)["uitest-runtime-fixture-active"].waitForExistence(timeout: 10),
              app.descendants(matching: .any)["screen-session-conversation"].waitForExistence(timeout: 15) else {
            XCTFail("Actual loopback fixture/timeline was not activated; no mock or stale screen acceptance."); return
        }
        XCTAssertTrue(app.staticTexts[momentText].firstMatch.exists)
        try saveHistoryScreenshot("ios-history-12-native-large-text")
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .textClipped, .trait]) { issue in
            print("HISTORY_NATIVE_AUDIT", issue.compactDescription, issue.detailedDescription,
                  issue.element?.identifier ?? "no-id", issue.element?.label ?? "no-label")
            return false
        }
        try await control("end")
    }

    private func saveHistoryScreenshot(_ name: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("build/session-conversation-history/screenshots")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = XCUIApplication().frame.width > 600 ? name.replacingOccurrences(of: "ios-", with: "ipad-") : name
        try screenshot.pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"))
    }
}
