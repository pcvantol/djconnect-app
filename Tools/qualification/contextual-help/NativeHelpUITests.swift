import Foundation
import XCTest

@MainActor final class NativeHelpUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    private func launch(language: String = "en", surface: String = "ask_dj", large: Bool = false, synthetic: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["HELP_LANGUAGE": language, "HELP_SURFACE": surface,
                                 "HELP_LARGE": large ? "1" : "0", "HELP_SYNTHETIC": synthetic ? "1" : "0"]
        app.launch()
        XCTAssertTrue(app.staticTexts["ask-dj-help-title"].waitForExistence(timeout: 10))
        return app
    }
    private func activate(_ element: XCUIElement) {
        #if os(macOS)
        element.click()
        #else
        element.tap()
        #endif
    }
    func testReferenceInFiveLocalesBothSurfacesAndTextSizes() throws {
        for language in ["nl", "en", "de", "fr", "es"] {
            for surface in ["ask_dj", "active_session"] {
                for large in [false, true] {
                    let app = launch(language: language, surface: surface, large: large)
                    XCTAssertTrue(app.staticTexts["ask-dj-help-group-listen"].exists)
                    XCTAssertTrue(app.staticTexts["ask-dj-help-group-play"].exists)
                    XCTAssertTrue(app.staticTexts["ask-dj-help-group-discover"].exists)
                    let examples = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ask-dj-help-example-"))
                    XCTAssertEqual(examples.count, 6)
                    XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ask-dj-help-example-")).count, 0)
                    XCTAssertFalse(app.staticTexts["ask-dj-help-unavailable"].exists)
                    #if os(macOS)
                    let screenshot = app.windows.firstMatch.screenshot()
                    #else
                    let screenshot = app.screenshot()
                    #endif
                    let attachment = XCTAttachment(screenshot: screenshot)
                    attachment.name = "help-\(language)-\(surface)-\(large ? "light-accessibility" : "dark-normal")"
                    attachment.lifetime = .keepAlways; add(attachment)
                    app.terminate()
                }
            }
        }
    }
    func testIdleTrackExpiryAndOwnerWithdrawalRevalidateOpenReference() {
        let app = launch(surface: "active_session")
        let current = app.staticTexts["“What is playing now?”"]
        XCTAssertTrue(current.exists)
        activate(app.buttons["help-expire-track"])
        let expired = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !current.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expired], timeout: 8), .completed)
        XCTAssertTrue(app.staticTexts["ask-dj-help-group-play"].exists)
        activate(app.buttons["help-withdraw-owner"])
        XCTAssertTrue(app.staticTexts["ask-dj-help-unavailable"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["ask-dj-help-group-play"].exists)
        app.terminate()
    }
    func testSessionEndsAndShippingDraftNeverAdvertisesCommands() {
        let app = launch(surface: "active_session")
        activate(app.buttons["help-end-session"])
        XCTAssertTrue(app.staticTexts["ask-dj-help-unavailable"].waitForExistence(timeout: 5))
        app.terminate()
        for surface in ["ask_dj", "active_session"] {
            let shipping = launch(surface: surface, synthetic: false)
            XCTAssertTrue(shipping.staticTexts["ask-dj-help-unavailable"].exists)
            XCTAssertEqual(shipping.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ask-dj-help-example-")).count, 0)
            shipping.terminate()
        }
    }
    func testThreeSuggestionsAndNativeHelpPopoverOnBothSurfaces() {
        for surface in ["ask_dj", "active_session"] {
            let app = XCUIApplication()
            app.launchEnvironment = ["HELP_LANGUAGE": "nl", "HELP_SURFACE": surface,
                                     "HELP_SYNTHETIC": "1", "HELP_INTERACTION": "1"]
            app.launch()
            let entry = app.buttons["ask-dj-help-" + surface]
            XCTAssertTrue(entry.waitForExistence(timeout: 10))
            let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ask-dj-suggestion-" + surface + "-"))
            XCTAssertEqual(rows.count, 3)
            let first = rows.element(boundBy: 0)
            let prompt = first.label
            activate(first)
            XCTAssertEqual(app.staticTexts["help-selected-prompt"].label, prompt)
            activate(entry)
            XCTAssertTrue(app.staticTexts["ask-dj-help-title"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ask-dj-help-example-")).count, 6)
            #if os(macOS)
            let screenshot = app.windows.firstMatch.screenshot()
            #else
            let screenshot = app.screenshot()
            #endif
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "help-native-popover-three-suggestions-" + surface
            attachment.lifetime = .keepAlways
            add(attachment)
            activate(app.buttons["ask-dj-help-close"])
            let closed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !app.staticTexts["ask-dj-help-title"].exists
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
            XCTAssertEqual(rows.count, 3)
            XCTAssertEqual(rows.element(boundBy: 0).label, prompt)
            app.terminate()
        }
    }
}
