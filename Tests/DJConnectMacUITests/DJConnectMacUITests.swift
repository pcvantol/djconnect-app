import XCTest

@MainActor
final class DJConnectMacUITests: XCTestCase {
    private var lastScreenshotPNG: Data?

    private func launchMonkeyApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["--monkey-testing", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"])
        app.launch()
        return app
    }

    private func openScreen(_ title: String, in app: XCUIApplication, timeout: TimeInterval = 6) {
        let button = app.buttons[title]
        if button.waitForExistence(timeout: 2), button.isHittable {
            button.tap()
        } else {
            app.staticTexts[title].tapIfExists()
        }
        XCTAssertTrue(waitForScreen(title, in: app, timeout: timeout), "Expected \(title) to be visible after navigation.")
    }

    private func waitForScreen(_ title: String, in app: XCUIApplication, timeout: TimeInterval = 6) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.windows.firstMatch.exists
                && (app.staticTexts[title].exists
                    || app.buttons[title].exists
                    || app.groups[title].exists) {
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

    func testMonkeyModeSafeNavigationSmoke() {
        let app = launchMonkeyApp()
        let duration = TimeInterval(ProcessInfo.processInfo.environment["DJCONNECT_MONKEY_SECONDS"] ?? "20") ?? 20
        let deadline = Date().addingTimeInterval(duration)
        let destinations = ["Speelt Nu", "Wachtrij", "Ask DJ", "Track Insight", "Ontdek", "Afspeellijsten", "Games", "Instellingen", "Over"]
        var index = 0

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 12))

        while Date() < deadline {
            let title = destinations[index % destinations.count]
            app.buttons[title].tapIfExists()
            app.staticTexts[title].tapIfExists()

            switch title {
            case "Speelt Nu":
                app.buttons["Volgend nummer"].tapIfExists()
                app.buttons["Afspelen"].tapIfExists()
            case "Wachtrij":
                app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Midnight City")).firstMatch.tapIfExists()
            case "Ontdek":
                app.buttons["Ververs Ontdek"].tapIfExists()
            case "Afspeellijsten":
                app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "DJConnect")).firstMatch.tapIfExists()
            case "Games":
                app.buttons["Tik om te spelen"].tapIfExists()
                app.buttons["Meteor Run"].tapIfExists()
                app.buttons["Tik om te spelen"].tapIfExists()
            case "Instellingen", "Over":
                break
            default:
                break
            }

            index += 1
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        XCTAssertTrue(app.windows.firstMatch.exists)
    }

    func testSettingsShowsRepairPairingAction() {
        let app = launchMonkeyApp()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 12))
        openScreen("Instellingen", in: app)

        XCTAssertTrue(app.staticTexts["Koppeling"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["App opnieuw koppelen"].exists)
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

    func testCaptureDemoScreenshots() throws {
        let app = launchMonkeyApp()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 12))
        lastScreenshotPNG = nil
        try cleanScreenshotDirectory()

        let screens = [
            ("01-now-playing", "Speelt Nu"),
            ("02-queue", "Wachtrij"),
            ("03-ask-dj", "Ask DJ"),
            ("04-track-insight", "Track Insight"),
            ("05-discover", "Ontdek"),
            ("06-music-dna", "Music DNA"),
            ("07-playlists", "Afspeellijsten"),
            ("08-games", "Games"),
            ("09-settings", "Instellingen"),
            ("10-logs", "Logs"),
            ("11-about", "Over"),
            ("12-legal", "Juridisch"),
            ("12-privacy", "Privacy")
        ]

        for (name, title) in screens {
            openScreen(title, in: app)
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
            try captureVerifiedScreenshot(named: name, allowDuplicate: name == "01-now-playing")
        }
    }
    func testMomentFirstSessionAndIndependentPlayerNavigation() async throws {
        let base = URL(string: "http://127.0.0.1:18787")!
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/reset"))
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
        XCTAssertTrue(app.staticTexts["De genrecontext bij Current van Artist is soul."].waitForExistence(timeout: 15))
        try saveMomentScreenshot(app, "mac-01-moment")
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/advance"))
        XCTAssertTrue(app.staticTexts["The bass and percussion leave space for the melody."].waitForExistence(timeout: 10))
        try saveMomentScreenshot(app, "mac-02-next-moment")
        app.buttons["Speelt Nu"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Current"].firstMatch.waitForExistence(timeout: 6))
        try saveMomentScreenshot(app, "mac-03-player-active-session")
        app.buttons["DJ-sessie"].firstMatch.tap()
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/reconnect"))
        try await Task.sleep(for: .seconds(2))
        XCTAssertTrue(app.staticTexts["The bass and percussion leave space for the melody."].waitForExistence(timeout: 10))
        let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/metrics"))
        let metrics = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(metrics["playbackMutations"] as? Int, 0)
        XCTAssertEqual(metrics["ended"] as? Bool, false)
        app.buttons["Sessie beëindigen"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Start DJ-sessie"].waitForExistence(timeout: 10))
        app.buttons["Speelt Nu"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Current"].firstMatch.waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Current"].firstMatch.waitForExistence(timeout: 6))
        try saveMomentScreenshot(app, "mac-04-player-ended-session")
    }

    private func saveMomentScreenshot(_ app: XCUIApplication, _ name: String) throws {
        let screenshot = app.screenshot()
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
        .appendingPathComponent("screenshots")
        .appendingPathComponent("macos-local")
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
