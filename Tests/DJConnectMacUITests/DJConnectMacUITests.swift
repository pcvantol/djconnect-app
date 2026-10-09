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
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/native_reset"))
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["--uitesting", "--runtime-fixture=moment_contract", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
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
        try saveMomentScreenshot(app, "mac-01-moment")
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/advance"))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", "Nora Vale kwamen we eerder tegen bij «Amber Lines», als producer. Bij «Slow Lanterns» staat die naam opnieuw in de producercredits.")).firstMatch.waitForExistence(timeout: 10))
        try saveMomentScreenshot(app, "mac-02-next-moment")
        app.buttons["Speelt Nu"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Slow Lanterns"].firstMatch.waitForExistence(timeout: 6))
        try saveMomentScreenshot(app, "mac-03-player-active-session")
        app.buttons["DJ-sessie"].firstMatch.tap()
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/expire"))
        XCTAssertTrue(app.staticTexts["Slow Lanterns"].firstMatch.waitForExistence(timeout: 10))
        try saveMomentScreenshot(app, "mac-03a-source-expiry")
        _ = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/reconnect"))
        try await Task.sleep(for: .seconds(2))
        XCTAssertTrue(app.staticTexts["Slow Lanterns"].firstMatch.waitForExistence(timeout: 10))
        let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("fixture/metrics"))
        let metrics = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(metrics["playbackMutations"] as? Int, 0)
        XCTAssertEqual(metrics["ended"] as? Bool, false)
        app.buttons["Sessie beëindigen"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Start DJ-sessie"].waitForExistence(timeout: 10))
        app.buttons["Speelt Nu"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Slow Lanterns"].firstMatch.waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Slow Lanterns"].firstMatch.waitForExistence(timeout: 6))
        try saveMomentScreenshot(app, "mac-04-player-ended-session")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Start DJ-sessie"].waitForExistence(timeout: 10))
        app.buttons["Speelt Nu"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Slow Lanterns"].firstMatch.waitForExistence(timeout: 6))
        try saveMomentScreenshot(app, "mac-05-player-no-session")
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

    func testActualCoreConversationArchiveSearchAndIndependentPlayer() async throws {
        let base = URL(string: "http://127.0.0.1:18191")!
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
        var request = URLRequest(url: URL(string: base.absoluteString + "/api/djconnect/v1/session/active?device_id=djconnect-macos-ABCDEF123456&client_type=macos")!)
        request.setValue("Bearer synthetic-fixture-token", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let session = try XCTUnwrap(envelope["session"] as? [String: Any])
        let sessionID = try XCTUnwrap(session["session_id"] as? String)
        request.url = URL(string: base.absoluteString + "/api/djconnect/v1/session/history/" + sessionID + "?device_id=djconnect-macos-ABCDEF123456&client_type=macos&window=tail")!
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
        try saveHistoryScreenshot("mac-history-01-live-moment")
        app.buttons["session-search-toggle"].tap()
        let momentSearch = app.textFields["session-search-field"]
        momentSearch.tap(); momentSearch.typeText("geleidelijk")
        let selected = app.buttons["ask-entry-" + entryID]
        guard selected.waitForExistence(timeout: 15), selected.isHittable else {
            XCTFail("Canonical Moment search/anchor was not reached."); return
        }
        selected.tap()
        app.buttons["Zoeken sluiten"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["session-question-context"].waitForExistence(timeout: 5))
        let input = app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5)); input.tap(); input.typeText("Vertel over deze bijdrage")
        print("CLIENT FLAGS", app.staticTexts["session-history-runtime-diagnostics"].label)
        guard app.buttons["ask-dj-composer-send"].isEnabled else {
            XCTFail("Authorized conversation composer is disabled: " + app.staticTexts["session-history-runtime-diagnostics"].label); return
        }
        app.buttons["ask-dj-composer-send"].tap()
        guard app.staticTexts["Deze bijdrage: " + momentText].firstMatch.waitForExistence(timeout: 15) else {
            XCTFail("No confirmed native reply; diagnostic only, not acceptance."); return
        }
        try saveHistoryScreenshot("mac-history-02-confirmed-text-turn")
        app.buttons["session-search-toggle"].tap()
        let search = app.textFields["session-search-field"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("ONE")
        XCTAssertTrue(app.staticTexts["session-search-count"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["One · Metallica · …And Justice for All"].firstMatch.waitForExistence(timeout: 10))
        try saveHistoryScreenshot("mac-history-03-search-beyond-loaded-page")
        app.buttons["Zoeken sluiten"].firstMatch.tap()
        app.buttons["Speelt Nu"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-now-playing"].waitForExistence(timeout: 5))
        try saveHistoryScreenshot("mac-history-05-player-during-session")
        app.buttons["DJ-sessie"].firstMatch.tap()
        let end = app.buttons["session-end-button"]
        XCTAssertTrue(end.isHittable); end.tap()
        XCTAssertTrue(app.buttons["Start DJ-sessie"].waitForExistence(timeout: 15))
        try await control("restart")
        app.buttons["Eerdere sessies"].firstMatch.tap()
        let saved = app.buttons["saved-session-" + sessionID]
        XCTAssertTrue(saved.waitForExistence(timeout: 10)); saved.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-history-timeline"].waitForExistence(timeout: 10))
        try saveHistoryScreenshot("mac-history-06-readonly-after-server-restart")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Start DJ-sessie"].waitForExistence(timeout: 10))
        app.buttons["Ask DJ"].firstMatch.tap()
        let question = app.textFields.firstMatch
        XCTAssertTrue(question.waitForExistence(timeout: 5)); question.tap(); question.typeText("Wanneer heb ik eerder naar Metallica geluisterd?")
        app.buttons["ask-dj-composer-send"].tap()
        let openButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "open-session-"))
        guard openButtons.firstMatch.waitForExistence(timeout: 15) else {
            XCTFail("No backend-confirmed historical match with Open session action"); return
        }
        guard let open = openButtons.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            XCTFail("No visible historical match action"); return
        }
        let expectedAnchor = String(open.identifier.dropFirst("open-session-".count))
        try saveHistoryScreenshot("mac-history-07-real-historical-matches")
        open.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-history-timeline"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["session-entry-" + expectedAnchor].waitForExistence(timeout: 10))
        let anchorButton = app.buttons["ask-entry-" + expectedAnchor]
        let visibleAnchor = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: anchorButton)
        XCTAssertEqual(XCTWaiter.wait(for: [visibleAnchor], timeout: 8), .completed, "Open session must place its exact backend entry on screen")
        try saveHistoryScreenshot("mac-history-08-open-matched-entry")
    }


    func testActualCoreArchiveAndPlayerNavigationPreservesSessionB() async throws {
        let base = URL(string: "http://127.0.0.1:18191")!
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
        app.buttons["Eerdere sessies"].firstMatch.tap()
        let savedA = app.buttons["saved-session-" + sessionA]
        guard savedA.waitForExistence(timeout: 10) else { XCTFail("Ended Session A missing from real archive"); return }
        savedA.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-history-timeline"].waitForExistence(timeout: 10))
        let readback1 = try await activeID()
        XCTAssertEqual(readback1, sessionB)
        try saveHistoryScreenshot("mac-history-09-readonly-A-while-B-active")
        let dj = app.buttons["DJ-sessie"].firstMatch
        dj.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-session-conversation"].waitForExistence(timeout: 10))
        let readback2 = try await activeID()
        XCTAssertEqual(readback2, sessionB)
        app.buttons["Speelt Nu"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-now-playing"].waitForExistence(timeout: 5))
        let readback3 = try await activeID()
        XCTAssertEqual(readback3, sessionB)
        try saveHistoryScreenshot("mac-history-10-player-preserves-B")
        _ = try await control("end")
        dj.tap()
        XCTAssertTrue(app.buttons["Start DJ-sessie"].waitForExistence(timeout: 15))
        app.buttons["Speelt Nu"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen-now-playing"].waitForExistence(timeout: 5))
        let finalReadback = try await activeID()
        XCTAssertNil(finalReadback)
        try saveHistoryScreenshot("mac-history-11-player-without-session")
    }

    private func saveHistoryScreenshot(_ name: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("build/session-conversation-history/screenshots")
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
