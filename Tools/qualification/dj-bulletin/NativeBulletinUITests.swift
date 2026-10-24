import Foundation
import XCTest

@MainActor final class NativeBulletinUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    func testExistingMomentCardAcrossFiveLocalesAppearanceAndDynamicType() throws {
        let fixtureURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "dj-bulletin-v1-core-12675bc-wire", withExtension: "json"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL)) as? [String: Any])
        let sample = try XCTUnwrap(root["sample"] as? [String: Any])
        let moment = try XCTUnwrap(sample["moment"] as? [String: Any])
        let narration = try XCTUnwrap(moment["content"] as? String)
        let sources = try XCTUnwrap(moment["sources"] as? [[String: Any]])
        let labels = ["nl": "DJ Bulletin", "en": "DJ Bulletin", "de": "DJ-Bulletin", "fr": "Bulletin du DJ", "es": "Boletín del DJ"]
        for language in ["nl", "en", "de", "fr", "es"] {
            for light in [false, true] {
                for large in [false, true] {
                    let app = XCUIApplication()
                    app.launchEnvironment["BULLETIN_LANGUAGE"] = language
                    app.launchEnvironment["BULLETIN_LIGHT"] = light ? "1" : "0"
                    app.launchEnvironment["BULLETIN_LARGE_TEXT"] = large ? "1" : "0"
                    app.launch()
                    XCTAssertTrue(app.staticTexts[labels[language]!].waitForExistence(timeout: 10))
                    let contentMatches = app.staticTexts.allElementsBoundByIndex.filter {
                        $0.label == narration || ($0.value as? String) == narration
                    }
                    if contentMatches.count != 1 {
                        print("BULLETIN_TEXT_DIAGNOSTICS " + app.staticTexts.allElementsBoundByIndex.map {
                            "label=" + $0.label + " value=" + String(describing: $0.value)
                        }.joined(separator: "\n"))
                    }
                    XCTAssertEqual(contentMatches.count, 1)
                    for source in sources {
                        let url = try XCTUnwrap(source["url"] as? String)
                        let link = app.descendants(matching: .any).matching(identifier: "moment-source-" + url).firstMatch
                        XCTAssertTrue(link.exists)
                        let expected = try XCTUnwrap(source["provider"] as? String) + " · " +
                            (try XCTUnwrap(source["title"] as? String)) + " · " + (try XCTUnwrap(source["license"] as? String))
                        XCTAssertTrue(link.label == expected || (link.value as? String) == expected,
                                      "The accessible source names its original headline and license")
                    }
                    // Only the existing Moment component; no source controls,
                    // settings, custom speech player or executable news action.
                    XCTAssertEqual(app.switches.count, 0)
                    XCTAssertEqual(app.textFields.count, 0)
                    #if os(macOS)
                    let screenshot = app.windows.firstMatch.screenshot()
                    #else
                    let screenshot = app.screenshot()
                    #endif
                    let attachment = XCTAttachment(screenshot: screenshot)
                    attachment.name = "bulletin-\(language)-\(light ? "light" : "dark")-\(large ? "accessibility" : "normal")"
                    attachment.lifetime = .keepAlways; add(attachment)
                    app.terminate()
                }
            }
        }
    }
    func testBulletinCurrentFlowExpiryAndWithdrawalUseOriginalProducerAdmission() throws {
        let fixtureURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "dj-bulletin-v1-core-12675bc-wire", withExtension: "json"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL)) as? [String: Any])
        let sample = try XCTUnwrap(root["sample"] as? [String: Any])
        let moment = try XCTUnwrap(sample["moment"] as? [String: Any])
        let narration = try XCTUnwrap(moment["content"] as? String)
        for language in ["nl", "en", "de", "fr", "es"] {
            let app = XCUIApplication()
            app.launchEnvironment["BULLETIN_LANGUAGE"] = language
            app.launchEnvironment["BULLETIN_LIFECYCLE_PROBE"] = "1"
            app.launch()
            for phase in ["current", "flow", "expired", "current", "withdrawn"] {
                let button = app.buttons["bulletin-phase-" + phase]
                XCTAssertTrue(button.waitForExistence(timeout: 10))
                #if os(macOS)
                button.click()
                #else
                button.tap()
                #endif
                let count = ["current", "flow"].contains(phase) ? 1 : 0
                let expected = phase + " · cards " + String(count)
                let status = app.staticTexts["bulletin-lifecycle-status"]
                let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    status.exists && (status.label == expected || (status.value as? String) == expected)
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
                let actual = app.staticTexts.allElementsBoundByIndex.filter {
                    $0.label == narration || ($0.value as? String) == narration
                }
                XCTAssertEqual(actual.count, count, "One published normal bubble, no current/Flow duplicate or expired/withdrawn text")
            }
            app.terminate()
        }
    }

    func testAskDJDeleteContextMenuStaysMountedDuringOrdinaryUpdates() throws {
        let app = XCUIApplication()
        app.launchEnvironment["DELETION_MENU_PROBE"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["deletion-probe-confirmations"].waitForExistence(timeout: 10))
        let text = try XCTUnwrap(app.staticTexts.allElementsBoundByIndex.first {
            $0.label == "Synthetic retained DJ answer" || ($0.value as? String) == "Synthetic retained DJ answer"
        })
        #if os(macOS)
        text.rightClick()
        #else
        text.press(forDuration: 0.8)
        #endif
        let item = app.buttons["content-context-delete"]
        let menuItem = app.menuItems["content-context-delete"]
        XCTAssertTrue(item.waitForExistence(timeout: 3) || menuItem.waitForExistence(timeout: 1))
        // The view keeps generating fresh action closures during these native waits.
        let held = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            item.exists || menuItem.exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [held], timeout: 3), .completed)
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(item.exists || menuItem.exists)
        #if os(macOS)
        if menuItem.exists { menuItem.click() } else { item.click() }
        #else
        item.tap()
        #endif
        XCTAssertTrue(app.staticTexts["Confirmations: 1"].waitForExistence(timeout: 3))
        XCTAssertFalse(item.exists || menuItem.exists)
        app.terminate()
    }

}
