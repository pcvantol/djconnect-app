import XCTest
import UIKit

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
        XCTAssertTrue(app.tabBars.buttons["Speelt Nu"].exists)
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
        XCTAssertTrue(app.tabBars.buttons["Speelt Nu"].exists)
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
        let app = launchSessionUIDemo()

        tapTabOrMoreItem("Games", in: app)

        XCTAssertTrue(app.navigationBars["Games"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Paddle Rally"].exists || app.staticTexts["Paddle Rally"].exists)
        XCTAssertTrue(app.buttons["Meteor Run"].exists || app.staticTexts["Meteor Run"].exists)
        XCTAssertTrue(app.buttons["Sky Dash"].exists || app.staticTexts["Sky Dash"].exists)
        XCTAssertTrue(app.buttons["Maze Chase"].exists || app.staticTexts["Maze Chase"].exists)
        XCTAssertTrue(app.buttons["Tik om te spelen"].exists || app.staticTexts["Tik om te spelen"].exists)
        let first = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        first.name = "game-selector-first-rounded-inset"; first.lifetime = .keepAlways; add(first)
        let maze = app.buttons["Maze Chase"].firstMatch
        maze.tap()
        let state = app.descendants(matching: .any)["games-state"].firstMatch
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (state.value as? String)?.contains("game=pacman") == true
        }, object: state)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
        let last = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        last.name = "game-selector-last-rounded-inset"; last.lifetime = .keepAlways; add(last)
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
        .appendingPathComponent("ask-dj-screenshots")
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
        more.tap()
        if !app.navigationBars["Speelt Nu"].exists { app.buttons["Speelt Nu"].firstMatch.tap() }
        XCTAssertTrue(app.navigationBars["Speelt Nu"].waitForExistence(timeout: 5))
        try saveHistoryScreenshot("ios-history-05-player-during-session")
        let tab = app.tabBars.buttons["DJ-sessie"].exists ? app.tabBars.buttons["DJ-sessie"] : app.buttons["DJ-sessie"].firstMatch
        tab.tap()
        let end = app.buttons["session-end-button"]
        XCTAssertTrue(end.isHittable); end.tap()
        app.alerts.buttons["session-end-confirm"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Start DJ-sessie"].waitForExistence(timeout: 15))
        try await control("restart")
        more.tap(); app.buttons["Eerdere sessies"].firstMatch.tap()
        let saved = app.buttons["saved-session-" + sessionID]
        XCTAssertTrue(saved.waitForExistence(timeout: 10)); saved.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-history-timeline"].waitForExistence(timeout: 10))
        try saveHistoryScreenshot("ios-history-06-readonly-after-server-restart")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Start DJ-sessie"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Meer"].tap()
        let ask = app.buttons["Ask DJ"].firstMatch
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

    func testActualPairedOwnerLiveNativeSnapshotUpdateReconnectAndPlayer() async throws {
        let base = URL(string: ProcessInfo.processInfo.environment["DJC_APPLE_PAIRED_UI_BASE"] ?? "http://127.0.0.1:18197")!
        func control(_ operation: String, method: String = "POST") async throws -> [String: Any] {
            var request = URLRequest(url: base.appendingPathComponent("__apple_paired_fixture/" + operation))
            request.httpMethod = method
            request.setValue("Bearer apple-paired-fixture-control", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        _ = try await control("restore_profile")
        let before = try await control("start")
        let sessionID = try XCTUnwrap((before["active"] as? [String: Any])?["session_id"] as? String)
        let app = XCUIApplication(); app.terminate()
        app.launchArguments = ["--uitesting", "--runtime-fixture=paired_owner_contract", "-DJCONNECTRuntimeFixture", "paired_owner_contract", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = base.absoluteString
        app.launchEnvironment["DJCONNECT_UITEST_RUNTIME_FIXTURE"] = "paired_owner_contract"
        // Actual POST /pair from an empty local store; no HA/SDK token injected.
        app.launch()
        try await Task.sleep(for: .milliseconds(400))
        app.terminate(); app.launch()
        if app.buttons["Niet nu"].waitForExistence(timeout: 2) { app.buttons["Niet nu"].tap() }
        XCTAssertTrue(app.descendants(matching: .any)["screen-session-conversation"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["We voeren de energie geleidelijk op."].firstMatch.waitForExistence(timeout: 15))
        let pinned = app.descendants(matching: .any)["session-pinned-current"].firstMatch
        XCTAssertTrue(pinned.exists)
        XCTAssertFalse(app.buttons["Terug naar de actuele bijdrage"].exists)
        app.buttons["session-mood-toggle"].tap()
        let mood = app.descendants(matching: .any)["active-session-mood"].firstMatch
        guard mood.waitForExistence(timeout: 10) else {
            print(app.debugDescription)
            try saveHistoryScreenshot("paired-ui-missing-mood-control")
            XCTFail("Native active mood control not exposed"); return
        }
        if base.port == 18197 {
            let party = mood.buttons["Feest"]
            XCTAssertTrue(party.isEnabled)
            party.tap()
            var afterMood = try await control("state", method: "GET")
            for _ in 0..<25 {
                if (afterMood["active"] as? [String: Any])?["selected_mood"] as? String == "party" { break }
                try await Task.sleep(for: .milliseconds(200))
                afterMood = try await control("state", method: "GET")
            }
            XCTAssertEqual((afterMood["active"] as? [String: Any])?["selected_mood"] as? String, "party")
            XCTAssertEqual((afterMood["active"] as? [String: Any])?["session_id"] as? String, sessionID)
            XCTAssertEqual((afterMood["active"] as? [String: Any])?["mood_revision"] as? Int, 1)
            XCTAssertEqual((afterMood["active"] as? [String: Any])?["now_playing"] as? NSDictionary,
                           (before["active"] as? [String: Any])?["now_playing"] as? NSDictionary)
            try saveHistoryScreenshot("paired-ui-confirmed-active-mood")
        }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7)).tap()
        let beforeMenu = try await control("state", method: "GET")
        let handoff = app.buttons["session-handoff-toggle"]
        XCTAssertTrue(handoff.isHittable); handoff.tap()
        XCTAssertTrue(app.textFields["vibecast-handoff-digit-0"].waitForExistence(timeout: 5))
        try saveHistoryScreenshot("paired-ui-handoff-dialog")
        XCTAssertTrue(app.buttons["session-handoff-not-now"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7)).tap()
        XCTAssertTrue(app.textFields["vibecast-handoff-digit-0"].exists, "Backdrop does not dismiss the blocking dialog")
        app.buttons["session-handoff-not-now"].tap()
        let handoffDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.textFields["vibecast-handoff-digit-0"])
        XCTAssertEqual(XCTWaiter.wait(for: [handoffDismissed], timeout: 5), .completed)
        let afterMenu = try await control("state", method: "GET")
        XCTAssertEqual((beforeMenu["active"] as? NSDictionary), (afterMenu["active"] as? NSDictionary))
        let draft = app.textViews.firstMatch
        XCTAssertTrue(draft.isHittable); draft.tap(); draft.typeText("Layoutproef")
        XCTAssertLessThan(pinned.frame.maxY, draft.frame.minY + 1)
        XCTAssertLessThan(pinned.frame.height, app.frame.height * 0.6)
        try saveHistoryScreenshot("paired-ui-pinned-with-keyboard")
        draft.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 11))
        app.buttons["session-search-toggle"].tap()
        app.buttons["Zoeken sluiten"].firstMatch.tap()
        try saveHistoryScreenshot("paired-ios-01-authorized-native-snapshot")
        _ = try await control("update")
        XCTAssertTrue(app.staticTexts["Paired native update"].firstMatch.waitForExistence(timeout: 10))
        try saveHistoryScreenshot("paired-ios-02-native-live-update")
        XCUIDevice.shared.press(.home)
        _ = try await control("resume_update")
        app.activate()
        XCTAssertTrue(app.staticTexts["Paired resume update"].firstMatch.waitForExistence(timeout: 15))
        try saveHistoryScreenshot("paired-ios-03-authorized-reconnect")
        let navigationBefore = try await control("state", method: "GET")
        let more = app.tabBars.buttons["Meer"].exists ? app.tabBars.buttons["Meer"] : app.buttons["Meer"].firstMatch
        more.tap()
        if !app.navigationBars["Speelt Nu"].exists { app.buttons["Speelt Nu"].firstMatch.tap() }
        XCTAssertTrue(app.navigationBars["Speelt Nu"].waitForExistence(timeout: 5))
        let after = try await control("state", method: "GET")
        XCTAssertEqual((after["active"] as? [String: Any])?["session_id"] as? String, sessionID)
        XCTAssertEqual((after["active"] as? [String: Any])?["now_playing"] as? NSDictionary,
                       (navigationBefore["active"] as? [String: Any])?["now_playing"] as? NSDictionary)
        XCTAssertEqual(after["ha_refresh_tokens"] as? Int, after["initial_ha_refresh_tokens"] as? Int)
        try saveHistoryScreenshot("paired-ios-04-player-preserves-session")
        _ = try await control("end")
        let dj = app.tabBars.buttons["DJ-sessie"].exists ? app.tabBars.buttons["DJ-sessie"] : app.buttons["DJ-sessie"].firstMatch
        dj.tap()
        XCTAssertTrue(app.buttons["Start DJ-sessie"].waitForExistence(timeout: 15))
        more.tap()
        if !app.navigationBars["Speelt Nu"].exists { app.buttons["Speelt Nu"].firstMatch.tap() }
        XCTAssertTrue(app.navigationBars["Speelt Nu"].waitForExistence(timeout: 5))
        try saveHistoryScreenshot("paired-ios-05-player-after-session-end")
        let moreBack = app.navigationBars["Speelt Nu"].buttons["Meer"]
        if moreBack.exists { moreBack.tap() } else { more.tap() }
        let earlierSessions = app.descendants(matching: .any)["Eerdere sessies"].firstMatch
        try saveHistoryScreenshot("paired-ui-more-before-archive")
        guard earlierSessions.waitForExistence(timeout: 10) else {
            print(app.debugDescription)
            XCTFail("Native earlier-session destination not present"); return
        }
        earlierSessions.tap()
        XCTAssertTrue(app.buttons["saved-session-" + sessionID].waitForExistence(timeout: 10))
        let refresh = app.buttons["saved-sessions-refresh"]
        XCTAssertTrue(refresh.exists)
        _ = try await control("history_fail_once")
        refresh.tap()
        XCTAssertTrue(app.staticTexts["Sessies laden"].firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Opnieuw"].waitForExistence(timeout: 10))
        try saveHistoryScreenshot("paired-ui-archive-transient-error")
        let savedList = app.descendants(matching: .any)["saved-sessions-list"].firstMatch
        print("Saved-list native frame: " + String(describing: savedList.frame))
        let errorText = app.staticTexts["De sessiehistorie is niet beschikbaar. Probeer opnieuw."].firstMatch
        XCTAssertTrue(errorText.exists)
        errorText.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1,
            thenDragTo: savedList.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
        if !app.buttons["saved-session-" + sessionID].waitForExistence(timeout: 10) {
            print(app.debugDescription)
            XCTFail("Native pull-to-refresh did not recover the archived Session")
        }
        try saveHistoryScreenshot("paired-ui-archive-dates-gradient")
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
        more.tap()
        if !app.navigationBars["Speelt Nu"].exists { app.buttons["Speelt Nu"].firstMatch.tap() }
        XCTAssertTrue(app.navigationBars["Speelt Nu"].waitForExistence(timeout: 5))
        let readback3 = try await activeID()
        XCTAssertEqual(readback3, sessionB)
        try saveHistoryScreenshot("ios-history-10-player-preserves-B")
        _ = try await control("end")
        dj.tap()
        XCTAssertTrue(app.buttons["Start DJ-sessie"].waitForExistence(timeout: 15))
        more.tap()
        if !app.navigationBars["Speelt Nu"].exists { app.buttons["Speelt Nu"].firstMatch.tap() }
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

extension DJConnectIOSUITests {
    private func launchSessionUIDemo(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--runtime-fixture=review_demo", "-DJCONNECTRuntimeFixture", "review_demo", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launchArguments.append(contentsOf: additionalArguments)
        app.launchEnvironment = ["DJCONNECT_UITEST_HA_URL": "", "DJCONNECT_UITEST_RUNTIME_FIXTURE": "review_demo"]
        app.terminate(); app.launch()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        app.terminate(); app.launch()
        let tab = app.tabBars.buttons["DJ-sessie"]
        if tab.exists { tab.tap() }
        return app
    }

    func testPausedPlaybackHasDistinctSessionPresentationAndResumes() {
        let app = launchSessionUIDemo()
        XCTAssertTrue(app.buttons["session-end-button"].waitForExistence(timeout: 10))
        tapTabOrMoreItem("Speelt Nu", in: app)
        let pause = app.buttons["Pauze"].firstMatch
        XCTAssertTrue(pause.waitForExistence(timeout: 5)); pause.tap()
        XCTAssertTrue(app.buttons["Afspelen"].firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons["DJ-sessie"].tap()
        let paused = app.staticTexts["Gepauzeerd"].firstMatch
        XCTAssertTrue(paused.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Gepauzeerd"].exists)
        XCTAssertTrue(app.buttons["session-end-button"].isEnabled)
        XCTAssertTrue(app.descendants(matching: .any)["session-playback-output"].firstMatch.exists)
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "native-session-playback-paused"; image.lifetime = .keepAlways; add(image)
        app.tabBars.buttons["Meer"].tap()
        if !app.navigationBars["Speelt Nu"].exists { tapTabOrMoreItem("Speelt Nu", in: app) }
        let play = app.buttons["Afspelen"].firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 5)); play.tap()
        XCTAssertTrue(app.buttons["Pauze"].firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons["DJ-sessie"].tap()
        let resumed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: paused)
        XCTAssertEqual(XCTWaiter.wait(for: [resumed], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["session-end-button"].isEnabled)
    }

    func testSessionMenuReturnScrollsCurrentBackToTop() {
        let app = launchSessionUIDemo()
        let title = app.staticTexts["Een avond met de DJ"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let initialTop = title.frame.minY
        let scroll = app.scrollViews.firstMatch
        scroll.swipeUp(); scroll.swipeUp()
        tapTabOrMoreItem("Speelt Nu", in: app)
        tapTabOrMoreItem("DJ-sessie", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(title.isHittable)
        XCTAssertEqual(title.frame.minY, initialTop, accuracy: 3)
    }

    func testRapidIdleSessionMoodChangesKeepAppRunning() {
        let app = launchSessionUIDemo()
        XCTAssertTrue(app.buttons["session-end-button"].waitForExistence(timeout: 10))
        app.buttons["session-end-button"].tap()
        let confirm = app.alerts.buttons["session-end-confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        let moods = ["Rustig", "Energie", "Groove", "Feest"]
        XCTAssertTrue(app.buttons["Rustig"].waitForExistence(timeout: 10))
        let points = moods.map { app.buttons[$0].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)) }
        for _ in 0..<15 {
            for point in points { point.tap() }
        }
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(app.buttons["Feest"].isSelected)
        XCTAssertTrue(app.buttons["Start DJ-sessie"].isHittable)
    }

    func testSessionMoodToolbarAndPlaybackTimes() {
        let app = launchSessionUIDemo()
        let connection = app.buttons["session-connection-toggle"]
        XCTAssertTrue(connection.waitForExistence(timeout: 5))
        connection.tap()
        XCTAssertTrue(app.staticTexts["Verbindingsstatus"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["session-connection-close"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7)).tap()
        XCTAssertFalse(app.staticTexts["Verbindingsstatus"].firstMatch.exists)
        let toggle = app.buttons["session-mood-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["active-session-mood"].firstMatch.exists)
        let times = app.staticTexts["Verstreken tijd en totale duur"].firstMatch
        XCTAssertTrue(times.exists)
        XCTAssertTrue((times.value as? String)?.contains(" / ") == true)
        XCTAssertFalse(app.staticTexts["Resterende tijd"].firstMatch.exists)
        let output = app.descendants(matching: .any)["session-playback-output"].firstMatch
        XCTAssertTrue(output.waitForExistence(timeout: 5))
        XCTAssertEqual(output.value as? String, "Woonkamer")
        XCTAssertGreaterThanOrEqual(output.frame.minY, times.frame.maxY)
        let volume = app.descendants(matching: .any)["session-playback-volume"].firstMatch
        XCTAssertTrue(volume.exists)
        XCTAssertEqual(volume.value as? String, "42%")
        XCTAssertLessThan(abs(volume.frame.midY - output.frame.midY), 5)
        let favorite = app.buttons["session-favorite-button"].firstMatch
        XCTAssertTrue(favorite.isHittable)
        XCTAssertLessThan(favorite.frame.minX, times.frame.minX)
        XCTAssertLessThan(abs(favorite.frame.midY - times.frame.midY), 3)
        let unselected = XCTAttachment(screenshot: app.screenshot()); unselected.name = "session-unselected-white-heart"; unselected.lifetime = .keepAlways; add(unselected)
        let initialFavoriteLabel = favorite.label
        favorite.tap()
        let favoriteChanged = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            favorite.label != initialFavoriteLabel
        }, object: favorite)
        XCTAssertEqual(XCTWaiter.wait(for: [favoriteChanged], timeout: 5), .completed)
        let pinned = app.descendants(matching: .any)["session-pinned-current"].firstMatch
        let music = app.descendants(matching: .any)["session-music-context"].firstMatch
        let card = app.descendants(matching: .any)["session-current-card"].firstMatch
        XCTAssertLessThanOrEqual(pinned.frame.maxY - max(music.frame.maxY, card.frame.maxY), 32,
                                 "Pinned header should hug its content instead of reserving blank viewport height")
        let userLabel = app.staticTexts["ask-dj-user-label"].firstMatch
        XCTAssertTrue(userLabel.exists)
        XCTAssertEqual(userLabel.label, "Jij")
        toggle.tap()
        let party = app.buttons["session-mood-option-3"]
        XCTAssertTrue(party.waitForExistence(timeout: 5))
        let menu = XCTAttachment(screenshot: app.screenshot()); menu.name = "native-session-mood-popover"; menu.lifetime = .keepAlways; add(menu)
        party.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7)).tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "Feest")
        XCTAssertFalse(app.buttons["session-mood-option-3"].exists)
        let glyph = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ask-entry-")).firstMatch
        XCTAssertTrue(glyph.waitForExistence(timeout: 5))
        XCTAssertTrue(glyph.isHittable)
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "native-session-glass-times-top-glyph"; image.lifetime = .keepAlways; add(image)
        glyph.tap()
        XCTAssertTrue(app.staticTexts["Geselecteerde bijdrage"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(glyph.value as? String, "Geselecteerde bijdrage")
        let selected = XCTAttachment(screenshot: app.screenshot()); selected.name = "native-visible-glyph-selected-context"; selected.lifetime = .keepAlways; add(selected)
        let clear = app.buttons["clear-session-question-context"].firstMatch
        XCTAssertTrue(clear.isHittable)
        clear.tap()
        XCTAssertFalse(app.staticTexts["Geselecteerde bijdrage"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["ask-dj-composer-input"].firstMatch.exists)
    }

    func testConfirmedMoodPalettesInPinnedSessionHeader() {
        let app = launchSessionUIDemo()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let toggle = app.buttons["session-mood-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        for (index, label) in ["Rustig", "Groove", "Energie", "Feest"].enumerated() {
            toggle.tap()
            let option = app.buttons["session-mood-option-\(index)"]
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            option.tap()
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7)).tap()
            XCTAssertEqual(toggle.value as? String, label)
            XCTAssertTrue(app.descendants(matching: .any)["session-music-context"].firstMatch.exists)
            XCTAssertTrue(app.descendants(matching: .any)["session-current-card"].firstMatch.exists)
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "confirmed-pinned-mood-\(index)-\(label)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }

    func testIPadNativeBottomNavigationPreservesExpandedSession() throws {
        let app = launchRuntimeFixtureApp("review_demo")
        guard app.frame.width > 600 else { throw XCTSkip("iPad navigation qualification") }
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(bar.frame.minY, app.frame.height * 0.75)
        XCTAssertTrue(bar.buttons["DJ-sessie"].isSelected)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "ipad-native-liquid-glass-bottom-navigation"
        screenshot.lifetime = .keepAlways; add(screenshot)
        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.frame.width > app.frame.height && bar.frame.minY > app.frame.height * 0.75
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed)
        let landscape = XCTAttachment(screenshot: app.screenshot())
        landscape.name = "ipad-native-liquid-glass-landscape"; landscape.lifetime = .keepAlways; add(landscape)
        bar.buttons["Meer"].tap()
        app.buttons["Ask DJ"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-ask-dj"].waitForExistence(timeout: 5))
        let consent = app.descendants(matching: .any)["music-dna-opt-in-prompt"].firstMatch
        if consent.waitForExistence(timeout: 3) {
            let later = app.buttons["Niet nu"].firstMatch
            XCTAssertTrue(later.waitForExistence(timeout: 5)); later.tap()
        }
        print("Native More before tap: frame=\(bar.buttons["Meer"].frame) hittable=\(bar.buttons["Meer"].isHittable) selected=\(bar.buttons["Meer"].isSelected)")
        let menuReady = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: bar.buttons["Meer"])
        XCTAssertEqual(XCTWaiter.wait(for: [menuReady], timeout: 5), .completed)
        bar.buttons["Meer"].tap()
        XCTAssertTrue(bar.buttons["Meer"].isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["Wachtrij"].firstMatch.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
    }

    func testNativeBottomMoreRoutesAndOfflineRemainReachable() throws {
        for (screen, identifier) in [
            ("now-playing", "screen-now-playing"),
            ("queue", "screen-queue"),
            ("playlists", "screen-playlists")
        ] {
            let app = launchRuntimeFixtureApp("ready", screen: screen)
            if !app.descendants(matching: .any)[identifier].waitForExistence(timeout: 10) {
                print(app.debugDescription); XCTFail(screen); return
            }
        }
        let offline = launchRuntimeFixtureApp("offline_network", screen: "dj-session")
        let bar = offline.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 10))
        let notice = offline.staticTexts["Apparaat offline"].firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertLessThan(notice.frame.maxY, bar.frame.minY)
        bar.buttons["Meer"].tap()
        offline.buttons["Ask DJ"].firstMatch.tap()
        XCTAssertTrue(bar.buttons["Meer"].isSelected)
        bar.buttons["Meer"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(bar.buttons["Meer"].isSelected)
        XCTAssertTrue(offline.descendants(matching: .any)["Wachtrij"].firstMatch.waitForExistence(timeout: 5))
    }

    func testIPhoneSessionHeroScrollsAwayAndJumpReturns() throws {
        guard UIDevice.current.userInterfaceIdiom == .phone else { throw XCTSkip("iPhone-only scrolling header") }
        XCUIDevice.shared.orientation = .portrait
        let app = launchSessionUIDemo()
        let title = app.staticTexts["Midnight City"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let jump = app.buttons["session-jump-top"]
        XCTAssertFalse(jump.exists)
        for _ in 0..<5 where !jump.exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.76))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.26)))
        }
        XCTAssertTrue(jump.waitForExistence(timeout: 5) && jump.isHittable)
        let away = XCTAttachment(screenshot: app.screenshot()); away.name = "iphone-hero-offscreen-jump-top"; away.lifetime = .keepAlways; add(away)
        jump.tap()
        let returned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: jump)
        XCTAssertEqual(XCTWaiter.wait(for: [returned], timeout: 5), .completed)
        XCTAssertTrue(title.isHittable)
        let top = XCTAttachment(screenshot: app.screenshot()); top.name = "iphone-fullwidth-current-after-jump"; top.lifetime = .keepAlways; add(top)
    }

    func testIPhonePlaybackButtonsHaveCircularBounds() throws {
        guard UIDevice.current.userInterfaceIdiom == .phone else { throw XCTSkip("iPhone playback controls") }
        let app = launchSessionUIDemo()
        tapTabOrMoreItem("Speelt Nu", in: app)
        for label in ["Vorig nummer", "Pauze", "Volgend nummer"] {
            let button = app.buttons[label].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 10), label)
            XCTAssertEqual(button.frame.width, button.frame.height, accuracy: 1, label)
            XCTAssertGreaterThanOrEqual(button.frame.width, label == "Pauze" ? 66 : 54)
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "iphone-circular-playback-controls"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testSessionRefreshIsRightmostToolbarAction() {
        let app = launchSessionUIDemo()
        let refresh = app.buttons["screen-refresh"].firstMatch
        let search = app.buttons["session-search-toggle"].firstMatch
        XCTAssertTrue(refresh.waitForExistence(timeout: 10))
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(refresh.frame.midX, search.frame.midX)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "session-refresh-rightmost"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testOneTapOutputChoiceUpdatesConfirmedRowAndKeepsControlsAvailable() {
        let app = launchRuntimeFixtureApp("review_demo", screen: "now-playing")
        XCTAssertTrue(app.descendants(matching: .any)["screen-now-playing"].waitForExistence(timeout: 10))
        let kitchen = app.buttons["output-device-demo-kitchen"]
        guard kitchen.waitForExistence(timeout: 10) else { XCTFail("Speaker row is missing on Now Playing"); return }
        for _ in 0..<5 where !kitchen.isHittable { app.swipeUp() }
        XCTAssertTrue(kitchen.isHittable)
        XCTAssertFalse(kitchen.isSelected)
        kitchen.tap()
        let confirmed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: kitchen)
        XCTAssertEqual(XCTWaiter.wait(for: [confirmed], timeout: 5), .completed)
        XCTAssertTrue(kitchen.isEnabled)
        XCTAssertTrue(app.buttons["output-devices-refresh"].isEnabled)
        XCTAssertTrue(app.buttons["Pauze"].firstMatch.isEnabled)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "one-tap-confirmed-output-choice"; shot.lifetime = .keepAlways; add(shot)
    }

    func testPrimaryNowPlayingTabAndAskDJInMore() {
        let app = launchRuntimeFixtureApp("review_demo")
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.buttons["Speelt Nu"].waitForExistence(timeout: 10))
        XCTAssertFalse(bar.buttons["Ask DJ"].exists)
        bar.buttons["Speelt Nu"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-now-playing"].waitForExistence(timeout: 6))
        bar.buttons["Meer"].tap()
        let ask = app.buttons["Ask DJ"].firstMatch
        XCTAssertTrue(ask.waitForExistence(timeout: 6)); ask.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-ask-dj"].waitForExistence(timeout: 6))
    }

    func testIPhoneAskDJFloatingComposerAndSearch() throws {
        guard UIDevice.current.userInterfaceIdiom == .phone else { throw XCTSkip("iPhone composer layout") }
        let app = launchRuntimeFixtureApp("review_demo")
        XCTAssertTrue(app.tabBars.buttons["Meer"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Meer"].tap()
        let ask = app.buttons["Ask DJ"].firstMatch
        XCTAssertTrue(ask.waitForExistence(timeout: 6)); ask.tap()
        let consent = app.descendants(matching: .any)["music-dna-opt-in-prompt"].firstMatch
        if consent.waitForExistence(timeout: 3) {
            app.buttons["Niet nu"].firstMatch.tap()
        }
        let input = app.textViews["ask-dj-composer-input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        XCTAssertLessThanOrEqual(input.frame.maxY, app.tabBars.firstMatch.frame.minY - 8)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "ask-dj-floating-composer"; screenshot.lifetime = .keepAlways; add(screenshot)
        let search = app.buttons["Zoek in Ask DJ"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(input.exists)
    }

    func testSessionMoreMenuRemainsOpenAcrossPlaybackTicks() throws {
        guard UIDevice.current.userInterfaceIdiom == .phone else { throw XCTSkip("iPad exposes actions directly") }
        let app = launchSessionUIDemo(additionalArguments: ["--uitest-vibecast-dialog"])
        let menu = app.buttons["session-more-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        let toolbarIDs = ["session-connection-toggle", "session-mood-toggle", "session-presence-toggle",
                          "session-end-button", "session-search-toggle", "session-more-menu"]
        for identifier in toolbarIDs {
            XCTAssertTrue(app.buttons[identifier].exists && app.buttons[identifier].isHittable, identifier)
        }
        let toolbarBefore = XCTAttachment(screenshot: app.screenshot())
        toolbarBefore.name = "session-full-toolbar-before-opening-menu"; toolbarBefore.lifetime = .keepAlways; add(toolbarBefore)
        menu.tap()
        let refresh = app.buttons["screen-refresh"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["session-handoff-toggle"].exists)
        let originalFrame = refresh.frame
        let initial = XCTAttachment(screenshot: app.screenshot())
        initial.name = "session-menu-open-before-playback-ticks"; initial.lifetime = .keepAlways; add(initial)
        // Demo uses the same one-second native playback-progress updates, with
        // provider calls disabled. This is native UI stability, not live HA proof.
        for _ in 0..<8 {
            RunLoop.current.run(until: Date().addingTimeInterval(1))
            XCTAssertTrue(refresh.exists)
            XCTAssertEqual(refresh.label, "Vernieuwen")
            XCTAssertFalse(refresh.isEnabled, "Demo permission remains stable while playback advances")
            XCTAssertEqual(refresh.frame, originalFrame)
        }
        let settled = XCTAttachment(screenshot: app.screenshot())
        settled.name = "session-menu-open-after-playback-ticks"; settled.lifetime = .keepAlways; add(settled)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.65)).tap()
        XCTAssertTrue(refresh.waitForNonExistence(timeout: 5))
        XCTAssertTrue(menu.isHittable)
        for identifier in toolbarIDs {
            XCTAssertTrue(app.buttons[identifier].exists && app.buttons[identifier].isHittable, identifier)
        }
        let toolbarAfter = XCTAttachment(screenshot: app.screenshot())
        toolbarAfter.name = "session-full-toolbar-after-closing-menu"; toolbarAfter.lifetime = .keepAlways; add(toolbarAfter)
    }

    func testIPadSessionToolbarSplitsActionsWithoutOverflow() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad toolbar layout") }
        let app = launchSessionUIDemo()
        defer { XCUIDevice.shared.orientation = .portrait }
        let identifiers = ["session-connection-toggle", "session-search-toggle", "session-mood-toggle",
                           "session-presence-toggle", "session-end-button", "screen-refresh"]
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            let landscape = orientation == .landscapeLeft
            let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let frame = app.frame
                return landscape ? frame.width > frame.height : frame.height > frame.width
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
            // Accessibility geometry can settle before the screenshot compositor.
            RunLoop.current.run(until: Date().addingTimeInterval(2))
            XCTAssertTrue(app.buttons["screen-refresh"].waitForExistence(timeout: 10))
            for identifier in identifiers {
                XCTAssertTrue(app.buttons[identifier].exists && app.buttons[identifier].isHittable, identifier)
            }
            XCTAssertFalse(app.buttons["session-more-menu"].exists)
            let search = app.buttons["session-search-toggle"].frame
            let mood = app.buttons["session-mood-toggle"].frame
            let refresh = app.buttons["screen-refresh"].frame
            XCTAssertLessThan(search.maxX, app.frame.midX)
            XCTAssertGreaterThan(mood.minX, app.frame.midX)
            XCTAssertGreaterThan(refresh.minX, app.buttons["session-end-button"].frame.minX)
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = orientation == .portrait ? "ipad-split-toolbar-portrait" : "ipad-split-toolbar-landscape"
            shot.lifetime = .keepAlways; add(shot)
        }
    }

    func testVibeCastCenteredBlockingDialogAndGenericCopy() {
        let app = launchSessionUIDemo(additionalArguments: ["--uitest-vibecast-dialog"])
        let handoff = app.buttons["session-handoff-toggle"]
        if !handoff.exists {
            app.buttons["session-more-menu"].tap()
        }
        XCTAssertTrue(handoff.waitForExistence(timeout: 5)); handoff.tap()
        let dialog = app.descendants(matching: .any)["vibecast-session-start-dialog"].firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 10))
        if app.frame.width >= 700 {
            XCTAssertEqual(dialog.frame.midY, app.frame.midY, accuracy: 36, "Native iPad sheet stays centered")
        }
        XCTAssertFalse(app.buttons["session-handoff-close"].exists)
        XCTAssertEqual(app.buttons["session-handoff-not-now"].label, "Niet nu")
        for index in 0..<6 {
            XCTAssertTrue(app.textFields["vibecast-handoff-digit-\(index)"].exists)
        }
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "VibeCast sessie starten")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "op de Pi")).firstMatch.exists)
        XCTAssertFalse(app.buttons["session-end-button"].isHittable)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "vibecast-centered-cast-hero"; screenshot.lifetime = .keepAlways; add(screenshot)
        let outside = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let code = app.textFields["vibecast-handoff-digit-0"]
        XCTAssertTrue(code.isEnabled && code.isHittable)
        code.tap()
        app.typeText("123456")
        RunLoop.current.run(until: Date().addingTimeInterval(4))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let inputScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        inputScreenshot.name = "vibecast-six-digits-numeric-keyboard"; inputScreenshot.lifetime = .keepAlways; add(inputScreenshot)
        for index in 0..<6 {
            let digit = app.textFields["vibecast-handoff-digit-\(index)"]
            XCTAssertEqual(digit.value as? String, String(index + 1), "Typing advances focus to the next cell")
            XCTAssertGreaterThanOrEqual(digit.frame.width, 44)
            XCTAssertGreaterThanOrEqual(digit.frame.height, 60)
        }
        XCTAssertFalse(app.keyboards.firstMatch.keys["a"].exists, "Code uses the numeric keyboard")
        app.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue)
        XCTAssertEqual(app.textFields["vibecast-handoff-digit-4"].value as? String, "")
        app.typeText("56")
        XCTAssertEqual(app.textFields["vibecast-handoff-digit-5"].value as? String, "6")
        XCTAssertGreaterThan(app.buttons["session-handoff-not-now"].frame.minY,
                             app.buttons["vibecast-handoff-approve"].frame.maxY)
        XCTAssertFalse(app.buttons["vibecast-handoff-approve"].isEnabled, "Demo presentation grants no handoff authority")
        outside.tap()
        XCTAssertTrue(dialog.exists)
        if !app.buttons["session-handoff-not-now"].isHittable { app.swipeDown() }
        app.buttons["session-handoff-not-now"].tap()
        XCTAssertTrue(dialog.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["session-end-button"].isHittable)
    }

    func testSessionMoodGlassChoicesAndSelection() {
        let app = launchSessionUIDemo()
        let toggle = app.buttons["session-mood-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10)); toggle.tap()
        let labels = ["Rustig", "Groove", "Energie", "Feest"]
        for (index, label) in labels.enumerated() {
            let choice = app.buttons["session-mood-option-" + String(index)]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            XCTAssertEqual(choice.label, label)
            XCTAssertGreaterThanOrEqual(choice.frame.width, 44)
            XCTAssertGreaterThanOrEqual(choice.frame.height, 44)
        }
        let party = app.buttons["session-mood-option-3"]
        XCTAssertTrue(party.isEnabled); party.tap()
        let selected = app.staticTexts["session-popover-selected-mood"]
        let confirmation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Feest"), object: selected)
        XCTAssertEqual(XCTWaiter.wait(for: [confirmation], timeout: 5), .completed)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "ipad-mood-glass-choice-popover"; screenshot.lifetime = .keepAlways; add(screenshot)
    }

    func testAskDJOutsideTapDismissesKeyboardWithoutLosingDraft() {
        let app = launchRuntimeFixtureApp("review_demo")
        XCTAssertTrue(app.tabBars.buttons["Meer"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Meer"].tap()
        let ask = app.buttons["Ask DJ"].firstMatch
        XCTAssertTrue(ask.waitForExistence(timeout: 6)); ask.tap()
        let consent = app.descendants(matching: .any)["music-dna-opt-in-prompt"].firstMatch
        if consent.waitForExistence(timeout: 3) { app.buttons["Niet nu"].firstMatch.tap() }
        assertOutsideTapDismissal(in: app)
    }

    func testSessionOutsideTapDismissesKeyboardWithoutLosingDraft() {
        assertOutsideTapDismissal(in: launchSessionUIDemo())
    }

    private func assertOutsideTapDismissal(in app: XCUIApplication) {
        let input = app.textViews["ask-dj-composer-input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        let send = app.buttons["ask-dj-composer-send"]
        let compactHeight = input.frame.height
        XCTAssertLessThan(abs(send.frame.midY - input.frame.midY), 8, "Unfocused composer stays in one row")
        input.tap()
        let expanded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            input.frame.height > compactHeight + 12 && send.frame.minY >= input.frame.maxY - 2
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 5), .completed, "Focus expands text above a separate action row")
        input.typeText("Bewaar dit concept")
        let expandedShot = XCTAttachment(screenshot: app.screenshot())
        expandedShot.name = "focused-two-row-ask-dj-composer"; expandedShot.lifetime = .keepAlways; add(expandedShot)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Tapping inside the composer keeps editing active")
        // Tap an inert heading; a suggested-question button intentionally
        // replaces the draft and cannot stand in for an outside background tap.
        let demoHeading = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Voorbeeldsessies")).firstMatch
        let background = demoHeading.exists ? demoHeading : app.staticTexts["Ask DJ"].firstMatch
        XCTAssertTrue(background.isHittable)
        background.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, "Bewaar dit concept")
        let collapsed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(send.frame.midY - input.frame.midY) < 8
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [collapsed], timeout: 5), .completed, "Dismissal restores the compact action row")
        input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Editing can resume after dismissal")
    }

    func testIPhoneSessionFloatingComposerAndScopedSearch() throws {
        guard UIDevice.current.userInterfaceIdiom == .phone else { throw XCTSkip("iPhone floating composer") }
        let app = launchSessionUIDemo()
        let input = app.textViews.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.exists)
        XCTAssertLessThan(input.frame.maxY, tabs.frame.minY - 8)
        input.tap()
        input.typeText("Een vraag over deze bijdrage")
        XCTAssertTrue(app.buttons["ask-dj-composer-send"].isHittable)
        app.buttons["ask-dj-composer-send"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        app.buttons["session-search-toggle"].tap()
        let search = app.textFields["session-search-field"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertEqual(search.placeholderValue, "Zoek in deze sessie")
        XCTAssertFalse(input.exists, "Searching hides the composer completely")
        search.typeText("groove\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "iphone-floating-composer-session-search"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Zoeken sluiten"].tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
    }

    func testSessionComposerTypingProfileWorkload() throws {
        guard ProcessInfo.processInfo.environment["DJC_TYPING_PROFILER_SYNC"] == "1" else {
            throw XCTSkip("Manual Instruments workload; requires synchronized profiler")
        }
        let app = launchSessionUIDemo()
        let input = app.textViews.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        let control = FileManager.default.temporaryDirectory.appendingPathComponent("djc-profiler-" + UUID().uuidString + ".ready")
        defer { try? FileManager.default.removeItem(at: control) }
        print("DJC_TYPING_PROFILE_READY control_file=\(control.path)")
        let deadline = Date().addingTimeInterval(60)
        while !FileManager.default.fileExists(atPath: control.path) && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        guard FileManager.default.fileExists(atPath: control.path) else {
            XCTFail("The actual profiler never signalled recording start"); return
        }
        let draft = String(repeating: "Vertel iets over het ritme en de muzikanten in deze bijdrage. ", count: 5)
        let started = Date()
        print("DJC_TYPING_PROFILE_BEGIN epoch=\(started.timeIntervalSince1970)")
        input.typeText(draft)
        print("DJC_TYPING_PROFILE_FINISHED epoch=\(Date().timeIntervalSince1970) seconds=\(Date().timeIntervalSince(started))")
        XCTAssertEqual(input.value as? String, draft)
        RunLoop.current.run(until: Date().addingTimeInterval(20))
    }

    func testComposerGrowsWhilePlaybackPausedAndSendsCompleteDraft() {
        let app = launchSessionUIDemo()
        tapTabOrMoreItem("Speelt Nu", in: app)
        let pause = app.buttons["Pauze"].firstMatch
        XCTAssertTrue(pause.waitForExistence(timeout: 5)); pause.tap()
        XCTAssertTrue(app.buttons["Afspelen"].firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons["DJ-sessie"].tap()
        XCTAssertTrue(app.staticTexts["Gepauzeerd"].waitForExistence(timeout: 5))
        let input = app.textViews.firstMatch
        input.tap(); input.typeText("Beginning End")
        input.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.5)).tap()
        input.typeText("X"); input.typeText("Y")
        let edited = input.value as? String ?? ""
        XCTAssertTrue(edited.contains("XY") && edited.hasSuffix(" End"), "Native edits must keep the insertion point instead of jumping to the end")
        app.buttons["ask-dj-composer-send"].tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap(); input.typeText("Regel een")
        let oneLineHeight = input.frame.height
        let extra = "\nRegel twee\nRegel drie\nRegel vier"
        input.typeText(extra)
        XCTAssertGreaterThan(input.frame.height, oneLineHeight + 10)
        XCTAssertEqual(input.value as? String, "Regel een" + extra)
        XCTAssertTrue(app.buttons["ask-dj-composer-send"].isHittable)
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "paused-local-editor-multiline"; image.lifetime = .keepAlways; add(image)
        app.buttons["ask-dj-composer-send"].tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, "")
        let message = app.staticTexts["Regel een" + extra].firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5))
    }

    func testSessionTimelineScrollBenchmark() {
        let app = launchSessionUIDemo()
        XCTAssertTrue(app.staticTexts["Midnight City"].firstMatch.waitForExistence(timeout: 10))
        for index in 0..<10 {
            let composer = app.textViews.firstMatch
            composer.tap(); composer.typeText("Scroll \(index)")
            app.buttons["ask-dj-composer-send"].tap()
        }
        let options = XCTMeasureOptions(); options.iterationCount = 3
        func scrollSequence() {
            let lower = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82))
            let upper = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
            lower.press(forDuration: 0.1, thenDragTo: upper)
            lower.press(forDuration: 0.1, thenDragTo: upper)
            upper.press(forDuration: 0.1, thenDragTo: lower)
            upper.press(forDuration: 0.1, thenDragTo: lower)
        }
        scrollSequence()
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)], options: options) {
            scrollSequence()
        }
    }

    func testSessionCurrentStoryBelowFullWidthMusic() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--runtime-fixture=review_demo", "-DJCONNECTRuntimeFixture", "review_demo", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launchEnvironment = ["DJCONNECT_UITEST_HA_URL": "", "DJCONNECT_UITEST_RUNTIME_FIXTURE": "review_demo"]
        app.terminate(); app.launch()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        app.terminate(); app.launch()
        let tab = app.tabBars.buttons["DJ-sessie"]
        if tab.exists { tab.tap() }
        let music = app.descendants(matching: .any)["session-music-context"].firstMatch
        let card = app.descendants(matching: .any)["session-current-card"].firstMatch
        guard music.waitForExistence(timeout: 10), card.waitForExistence(timeout: 10) else {
            XCTFail("Native current music/card should be exposed independently")
            return
        }
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCTAssertGreaterThan(music.frame.width, app.frame.width * 0.75)
            XCTAssertEqual(music.frame.minX, card.frame.minX, accuracy: 2)
            XCTAssertEqual(music.frame.width, card.frame.width, accuracy: 2)
            XCTAssertGreaterThanOrEqual(card.frame.minY, music.frame.maxY)
        } else {
            XCTAssertEqual(music.frame.minX, card.frame.minX, accuracy: 2)
            XCTAssertEqual(music.frame.width, card.frame.width, accuracy: 2)
            XCTAssertGreaterThanOrEqual(card.frame.minY, music.frame.maxY)
        }
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "session-music-above-full-width-story"; image.lifetime = .keepAlways; add(image)
    }

    func testReviewDemoActiveAndReadonlySessionsWithoutHomeAssistant() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--runtime-fixture=review_demo", "-DJCONNECTRuntimeFixture", "review_demo", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launchEnvironment = ["DJCONNECT_UITEST_HA_URL": "", "DJCONNECT_UITEST_RUNTIME_FIXTURE": "review_demo"]
        app.terminate(); app.launch()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        app.terminate(); app.launch()
        let sessionTab = app.tabBars.buttons["DJ-sessie"]
        if sessionTab.exists { sessionTab.tap() }
        XCTAssertTrue(app.staticTexts["Een avond met de DJ"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["session-demo-notice"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Midnight City"].firstMatch.exists)
        let overviewBeforeTyping = XCTAttachment(screenshot: app.screenshot()); overviewBeforeTyping.name = "demo-native-overview-before-keyboard"; overviewBeforeTyping.lifetime = .keepAlways; add(overviewBeforeTyping)
        let composer = app.textViews.firstMatch
        XCTAssertTrue(composer.exists)
        composer.tap(); composer.typeText("Demo vraag")
        app.buttons["ask-dj-composer-send"].tap()
        XCTAssertTrue(app.staticTexts["Demo vraag"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.keyboards.firstMatch.exists, "Explicit Send should dismiss the multiline editor keyboard")
        app.buttons["ask-dj-composer-microphone"].press(forDuration: 0.2)
        let voiceEntry = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@", "session-entry-demo-active-", "-entry-10")).firstMatch
        XCTAssertTrue(voiceEntry.waitForExistence(timeout: 5), "The demo voice example must appear in the actual Session timeline")
        let active = XCTAttachment(screenshot: app.screenshot()); active.name = "demo-native-active-session"; active.lifetime = .keepAlways; add(active)
        let more = app.tabBars.buttons["Meer"].exists ? app.tabBars.buttons["Meer"] : app.buttons["Meer"].firstMatch
        more.tap()
        let moreBack = app.navigationBars.buttons["Meer"].firstMatch
        if moreBack.exists && moreBack.isHittable { moreBack.tap() }
        let archive = app.buttons["Eerdere sessies"].firstMatch
        if archive.waitForExistence(timeout: 5) { archive.tap() }
        else { app.staticTexts["Eerdere sessies"].firstMatch.tap() }
        let row = app.descendants(matching: .any)["saved-session-demo-evening"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["saved-sessions-refresh"].firstMatch.exists)
        let overview = XCTAttachment(screenshot: app.screenshot()); overview.name = "demo-native-saved-session-overview"; overview.lifetime = .keepAlways; add(overview)
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-history-timeline"].firstMatch.waitForExistence(timeout: 5))
        let observed = app.descendants(matching: .any)["session-entry-demo-evening-entry-1"].firstMatch
        for _ in 0..<6 where !observed.exists {
            if let timelineScroll = app.scrollViews.allElementsBoundByIndex.first(where: { $0.frame.height > 300 }) { timelineScroll.swipeUp() }
        }
        let diagnostic = XCTAttachment(screenshot: app.screenshot()); diagnostic.name = "demo-native-readonly-before-assertion"; diagnostic.lifetime = .keepAlways; add(diagnostic)
        XCTAssertTrue(observed.exists)
        XCTAssertTrue(app.staticTexts["Electric Feel · MGMT"].firstMatch.exists)
        XCTAssertFalse(app.textViews.firstMatch.exists)
        let readonly = XCTAttachment(screenshot: app.screenshot()); readonly.name = "demo-native-readonly-session"; readonly.lifetime = .keepAlways; add(readonly)
        let dj = app.tabBars.buttons["DJ-sessie"].exists ? app.tabBars.buttons["DJ-sessie"] : app.buttons["DJ-sessie"].firstMatch
        dj.tap()
        app.buttons["session-end-button"].tap()
        XCTAssertTrue(app.alerts.buttons["session-end-confirm"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Annuleren"].tap()
        XCTAssertTrue(app.buttons["session-end-button"].exists)
        XCTAssertFalse(app.buttons["Start DJ-sessie"].firstMatch.exists)
        app.buttons["session-end-button"].tap()
        app.alerts.buttons["session-end-confirm"].firstMatch.tap()
        let restart = app.buttons["Start DJ-sessie"].firstMatch
        XCTAssertTrue(restart.waitForExistence(timeout: 5) && restart.isEnabled)
        XCTAssertTrue(app.staticTexts["Jouw muziek.\nJouw moment."].firstMatch.exists)
        let welcome = XCTAttachment(screenshot: app.screenshot()); welcome.name = "demo-native-idle-welcome-hero"; welcome.lifetime = .keepAlways; add(welcome)
        if !restart.isHittable { app.scrollViews.firstMatch.swipeUp() }
        app.buttons["Feest"].firstMatch.tap(); restart.tap()
        XCTAssertTrue(app.staticTexts["Een avond met de DJ"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["session-mood-toggle"].value as? String, "Feest")
        let restarted = XCTAttachment(screenshot: app.screenshot()); restarted.name = "demo-native-restarted-selected-mood"; restarted.lifetime = .keepAlways; add(restarted)
    }
}

extension DJConnectIOSUITests {
    func testReviewDemoExitShowsBlockingPairingAndDemoCanRestart() {
        let app = launchSessionUIDemo()
        let more = app.tabBars.buttons["Meer"].exists ? app.tabBars.buttons["Meer"] : app.buttons["Meer"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 5)); more.tap()
        let settings = app.buttons["Instellingen"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5)); settings.tap()
        let stop = app.buttons["settings-stop-demo"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        let pairing = app.descendants(matching: .any)["screen-pairing"].firstMatch
        XCTAssertTrue(pairing.waitForExistence(timeout: 8))
        let demo = app.buttons["pairing-start-demo-button"]
        XCTAssertTrue(demo.exists && demo.isEnabled)
        if app.frame.width > 600 { app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.8)).tap() }
        else { app.swipeDown() }
        XCTAssertTrue(pairing.exists, "Required pairing must not dismiss interactively")
        let blocked = XCTAttachment(screenshot: app.screenshot()); blocked.name = "review-demo-exit-blocking-pairing"; blocked.lifetime = .keepAlways; add(blocked)
        demo.tap()
        let tab = app.tabBars.buttons["DJ-sessie"].exists ? app.tabBars.buttons["DJ-sessie"] : app.buttons["DJ-sessie"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5)); tab.tap()
        XCTAssertTrue(app.staticTexts["Een avond met de DJ"].firstMatch.waitForExistence(timeout: 10))
    }
}

extension DJConnectIOSUITests {
    /// Connected immutable Core SDK/router/CAS/Broadcast qualification. Synthetic
    /// music only; screenshots do not claim installed device or microphone proof.
    func testActualPairedPresenceFivePositionsAndNativeConfirmation() async throws {
        let base = URL(string: ProcessInfo.processInfo.environment["DJC_APPLE_PRESENCE_UI_BASE"] ?? "http://127.0.0.1:18213")!
        func control(_ operation: String) async throws -> [String: Any] {
            var request = URLRequest(url: base.appendingPathComponent("__apple_paired_fixture/" + operation))
            request.httpMethod = "POST"
            request.setValue("Bearer apple-paired-fixture-control", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        _ = try await control("select_ios_pairing")
        let before = try await control("start")
        let original = try XCTUnwrap(before["active"] as? [String: Any])
        let language = ProcessInfo.processInfo.environment["DJC_APPLE_PRESENCE_LANGUAGE"] ?? "nl"
        if ProcessInfo.processInfo.environment["DJC_APPLE_PRESENCE_LANDSCAPE"] == "1" {
            XCUIDevice.shared.orientation = .landscapeLeft
        } else { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication(); app.terminate()
        app.launchArguments = ["--uitesting", "--runtime-fixture=paired_owner_contract", "-DJCONNECTRuntimeFixture", "paired_owner_contract", "-AppleLanguages", "(\(language))", "-AppleLocale", language]
        app.launchEnvironment["DJCONNECT_UITEST_HA_URL"] = base.absoluteString
        app.launchEnvironment["DJCONNECT_UITEST_RUNTIME_FIXTURE"] = "paired_owner_contract"
        app.launch()
        XCTAssertTrue(app.buttons["session-presence-toggle"].waitForExistence(timeout: 25))
        app.buttons["session-presence-toggle"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["active-session-presence"].firstMatch.waitForExistence(timeout: 10))
        let placement = XCTAttachment(screenshot: app.screenshot())
        placement.name = "presence-native-placement-before-selection"
        placement.lifetime = .keepAlways; add(placement)
        let values = ["music_only", "occasional", "balanced", "talkative", "presenter"]
        let anchors = ["nl":["Alleen muziek","Af en toe","Gebalanceerd","Praatgraag","Presentator"],"en":["Music only","Occasionally","Balanced","Talkative","Presenter"],"de":["Nur Musik","Gelegentlich","Ausgewogen","Gesprächig","Moderator"],"fr":["Musique uniquement","De temps en temps","Équilibré","Bavard","Présentateur"],"es":["Solo música","De vez en cuando","Equilibrado","Conversador","Presentador"]]
        for (offset, value) in values.enumerated() {
            let button = app.buttons["session-presence-choice-" + value]
            let viewport = app.scrollViews["session-presence-scroll"]
            // Inspect native bounds first: XCTest may throw when asking hittability
            // for a wholly clipped activation point at accessibility text sizes.
            for _ in 0..<10 {
                if button.exists {
                    let bounds = button.frame
                    if bounds.height > 0 && viewport.frame.insetBy(dx: 0, dy: 8).contains(CGPoint(x: bounds.midX, y: bounds.midY)) { break }
                }
                // A full-page flick can skip an entire large-text option. Use a
                // short deliberate native drag; do not bypass its hit target.
                viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
                    .press(forDuration: 0.2, thenDragTo: viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)),
                           withVelocity: .slow, thenHoldForDuration: 0.2)
            }
            let reachable = XCTAttachment(screenshot: app.screenshot())
            reachable.name = "presence-native-reachable-\(value)"
            reachable.lifetime = .keepAlways; add(reachable)
            XCTAssertTrue(button.exists && button.isEnabled && button.isHittable)
            if offset == 0 { _ = try await control("presence_delay_once") }
            button.tap()
            if offset == 0 {
                XCTAssertFalse(app.descendants(matching: .any)["session-presence-pending"].firstMatch.exists, "Selection feedback stays in the selector; no duplicate pending footer")
                XCTAssertTrue(((app.descendants(matching: .any)["session-presence-slider"].firstMatch.value as? String) ?? "").contains(anchors[language]![2]),
                              "Pending intent must not replace the confirmed server value")
                let pending = XCTAttachment(screenshot: app.screenshot())
                pending.name = "presence-\(language)-pending-distinct-from-confirmed"
                pending.lifetime = .keepAlways; add(pending)
            }
            var current: [String: Any] = [:]
            for _ in 0..<40 {
                let readback = try await control("state")
                current = try XCTUnwrap(readback["active"] as? [String: Any])
                if current["selected_presence"] as? String == value { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            XCTAssertEqual(current["selected_presence"] as? String, value)
            XCTAssertEqual(current["presence_revision"] as? Int, offset + 1)
            XCTAssertEqual(current["session_id"] as? String, original["session_id"] as? String)
            XCTAssertEqual(current["selected_mood"] as? String, original["selected_mood"] as? String)
            XCTAssertEqual(current["mood_revision"] as? Int, original["mood_revision"] as? Int)
            XCTAssertEqual(current["now_playing"] as? NSDictionary, original["now_playing"] as? NSDictionary)
            let confirmed = app.descendants(matching: .any)["session-presence-slider"].firstMatch
            XCTAssertTrue(confirmed.waitForExistence(timeout: 10))
            let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", anchors[language]![offset]), object: confirmed)
            let visibleResult = await XCTWaiter.fulfillment(of: [visible], timeout: 10)
            XCTAssertEqual(visibleResult, .completed, "The control value must confirm the actual server-selected position")
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "presence-\(language)-\(value)-confirmed"
            screenshot.lifetime = .keepAlways; add(screenshot)
        }
        XCTAssertTrue(app.descendants(matching: .any)["session-presence-slider"].firstMatch.exists, "The discrete accessible control is exposed")
        XCTAssertFalse(app.descendants(matching: .any)["session-presence-error"].firstMatch.exists)
        let paused = try await control("pause")
        let pausedRuntime = try XCTUnwrap(paused["active"] as? [String: Any])
        let pausedChoice = app.buttons["session-presence-choice-balanced"]
        let pausedViewport = app.scrollViews["session-presence-scroll"]
        for _ in 0..<10 {
            if pausedChoice.exists {
                let bounds = pausedChoice.frame
                if pausedViewport.frame.insetBy(dx: 0, dy: 8).contains(CGPoint(x: bounds.midX, y: bounds.midY)) { break }
            }
            pausedViewport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
                .press(forDuration: 0.2, thenDragTo: pausedViewport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)),
                       withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(pausedChoice.isHittable)
        pausedChoice.tap()
        let pausedConfirmation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", anchors[language]![2]), object: app.descendants(matching: .any)["session-presence-slider"].firstMatch)
        let pausedResult = await XCTWaiter.fulfillment(of: [pausedConfirmation], timeout: 10)
        XCTAssertEqual(pausedResult, .completed)
        let final = try await control("state")
        let finalRuntime = try XCTUnwrap(final["active"] as? [String: Any])
        XCTAssertEqual(finalRuntime["presence_revision"] as? Int, 6)
        XCTAssertEqual(finalRuntime["selected_presence"] as? String, "balanced")
        XCTAssertEqual(finalRuntime["now_playing"] as? NSDictionary, pausedRuntime["now_playing"] as? NSDictionary,
                       "Changing presence while paused must preserve actual playback")
        let pausedScreenshot = XCTAttachment(screenshot: app.screenshot())
        pausedScreenshot.name = "presence-\(language)-paused-confirmed"
        pausedScreenshot.lifetime = .keepAlways; add(pausedScreenshot)
        XCTAssertEqual(final["ha_refresh_tokens"] as? Int, final["initial_ha_refresh_tokens"] as? Int)
        XCTAssertEqual(final["ha_users"] as? Int, final["initial_ha_users"] as? Int)
        app.terminate()
    }
}
