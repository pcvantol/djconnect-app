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
        let destinations = ["Speelt Nu", "Wachtrij", "Afspeellijsten", "Games", "Instellingen", "Over"]
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
            ("05-music-dna", "Music DNA"),
            ("06-playlists", "Afspeellijsten"),
            ("07-games", "Games"),
            ("08-settings", "Instellingen"),
            ("09-logs", "Logs"),
            ("10-about", "Over"),
            ("11-legal", "Juridisch"),
            ("12-privacy", "Privacy")
        ]

        for (name, title) in screens {
            openScreen(title, in: app)
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
            try captureVerifiedScreenshot(named: name, allowDuplicate: name == "01-now-playing")
        }
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
