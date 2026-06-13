import XCTest

@MainActor
final class DJConnectMacUITests: XCTestCase {
    private func launchMonkeyApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--monkey-testing")
        app.launch()
        return app
    }

    func testMonkeyModeSafeNavigationSmoke() {
        let app = launchMonkeyApp()
        let duration = TimeInterval(ProcessInfo.processInfo.environment["DJCONNECT_MONKEY_SECONDS"] ?? "20") ?? 20
        let deadline = Date().addingTimeInterval(duration)
        let destinations = ["Speelt Nu", "Wachtrij", "Afspeellijsten", "Games", "Instellingen", "Over"]
        var index = 0

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 8))

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
                app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Gelikete nummers")).firstMatch.tapIfExists()
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
}

private extension XCUIElement {
    func tapIfExists() {
        if exists && isHittable {
            tap()
        }
    }
}
