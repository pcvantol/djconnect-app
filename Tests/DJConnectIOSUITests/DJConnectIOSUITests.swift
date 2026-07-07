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
        app.launchArguments.append(contentsOf: ["--uitesting", "--monkey-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = "http://127.0.0.1:8123"
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
            XCTAssertTrue(waitForAnyScreen(in: app, titles: ["Speelt Nu", "Now Playing"], timeout: 8))
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

        if app.tabBars.firstMatch.waitForExistence(timeout: 2) {
            return
        }
    }

    private func openSettings(_ app: XCUIApplication) {
        tapTabOrMoreItem("Instellingen", in: app)
    }

    private func openNowPlayingTab(_ app: XCUIApplication) {
        let nowPlaying = app.tabBars.buttons["Speelt Nu"]
        if nowPlaying.waitForExistence(timeout: 5) {
            nowPlaying.tap()
        }
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

        XCTAssertTrue(app.tabBars.buttons["Speelt Nu"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Ask DJ"].exists)
        XCTAssertTrue(app.tabBars.buttons["Track Insight"].exists)
        XCTAssertTrue(app.tabBars.buttons["Ontdek"].exists || app.tabBars.buttons["Discover"].exists)
        XCTAssertTrue(app.tabBars.buttons["Meer"].exists || app.tabBars.buttons["More"].exists)

        let moreButton = app.tabBars.buttons["Meer"].exists ? app.tabBars.buttons["Meer"] : app.tabBars.buttons["More"]
        moreButton.tap()
        XCTAssertTrue(app.descendants(matching: .any)["Wachtrij"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["Games"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["Instellingen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["Over"].exists)
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

        XCTAssertTrue(app.descendants(matching: .any)["screen-now-playing"].waitForExistence(timeout: 8))
        openNowPlayingTab(app)
        XCTAssertTrue(waitForText("Fixture Track", in: app))
        XCTAssertTrue(waitForText("Fixture Artist", in: app))
    }

    func testRuntimeFixtureShowsPlaybackOutputQueueAndPlaylists() {
        let app = launchRuntimeFixtureApp("paired_runtime")

        XCTAssertTrue(waitForRuntimeFixture(app))
        XCTAssertTrue(app.descendants(matching: .any)["screen-now-playing"].waitForExistence(timeout: 8))
        openNowPlayingTab(app)
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

        XCTAssertTrue(app.descendants(matching: .any)["screen-now-playing"].waitForExistence(timeout: 8))
        openNowPlayingTab(app)
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

        XCTAssertTrue(app.descendants(matching: .any)["screen-now-playing"].waitForExistence(timeout: 8))
        openNowPlayingTab(app)
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
        let tabs = ["Speelt Nu", "Ask DJ", "Track Insight", "Ontdek", "Meer"]
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
