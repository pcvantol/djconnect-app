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
    func testFullCatalogueMoreScrollAndCompleteVersusPlaceholderSelection() {
        let app = XCUIApplication()
        app.launchEnvironment = ["HELP_LANGUAGE": "en", "HELP_SURFACE": "ask_dj", "HELP_SYNTHETIC": "1", "HELP_FULL_CATALOGUE": "1"]
        app.launch()
        defer { app.terminate() }
        let more = app.buttons["ask-dj-more-ask_dj"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        activate(more)
        let artist = app.buttons["ask-dj-catalogue-play.artist"]
        XCTAssertTrue(artist.waitForExistence(timeout: 5))
        activate(artist)
        let selected = app.staticTexts["help-selected-prompt"]
        let drafted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            selected.exists && selected.label.hasPrefix("draft:")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [drafted], timeout: 5), .completed, app.debugDescription)
        XCTAssertTrue(app.staticTexts["help-selected-prompt"].label.contains("[artist]"))
        let scroll = app.scrollViews["ask-dj-full-catalogue"]
        XCTAssertTrue(scroll.waitForNonExistence(timeout: 5))
        activate(more)
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in scroll.isHittable }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        let opening = XCTAttachment(screenshot: app.screenshot())
        opening.name = "full-catalogue-before-scroll"
        opening.lifetime = .keepAlways; add(opening)
        let current = app.buttons["ask-dj-catalogue-listen.current"]
        for _ in 0..<8 {
            if current.exists && current.isHittable { break }
            #if os(macOS)
            app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -180)
            #else
            dragCatalogue(scroll, in: app)
            #endif
        }
        XCTAssertTrue(current.isHittable)
        activate(current)
        let sent = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            selected.exists && selected.label == "send:What is playing now?"
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [sent], timeout: 5), .completed, app.debugDescription)
        XCTAssertTrue(scroll.waitForNonExistence(timeout: 5))
        activate(more)
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        let reopened = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in scroll.isHittable }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [reopened], timeout: 5), .completed)
        let last = app.buttons["ask-dj-catalogue-listen.forecast"]
        for _ in 0..<8 {
            if last.exists && last.isHittable { break }
            #if os(macOS)
            app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -180)
            #else
            dragCatalogue(scroll, in: app)
            #endif
        }
        XCTAssertTrue(last.isHittable)
        #if os(macOS)
        let shot = app.windows.firstMatch.screenshot()
        #else
        let shot = app.screenshot()
        #endif
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "full-help-catalogue-bottom"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    #if !os(macOS)
    func testPlaceholderIsSelectedInTheRealNativeComposer() {
        let app = XCUIApplication()
        app.launchEnvironment = ["HELP_LANGUAGE": "en", "HELP_SURFACE": "ask_dj", "HELP_SYNTHETIC": "1", "HELP_FULL_CATALOGUE": "1", "HELP_COMPOSER": "1"]
        app.launch()
        defer { app.terminate() }
        let more = app.buttons["ask-dj-more-ask_dj"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        activate(more)
        let artist = app.buttons["ask-dj-catalogue-play.artist"]
        XCTAssertTrue(artist.waitForExistence(timeout: 5))
        activate(artist)
        let input = app.textViews.firstMatch
        let prepared = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            input.exists && (input.value as? String) == "Play [artist]"
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [prepared], timeout: 8), .completed, app.debugDescription)
        print("COMPOSER_DIAGNOSTICS", app.staticTexts["help-composer-diagnostics"].label)
        input.typeText("ABBA")
        XCTAssertEqual(input.value as? String, "Play ABBA")
        XCTAssertFalse(app.buttons["ask-dj-composer-send"].isEnabled)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "real-composer-placeholder-replaced"
        attachment.lifetime = .keepAlways; add(attachment)
    }
    private func dragCatalogue(_ scroll: XCUIElement, in app: XCUIApplication) {
        // XCTest's swipeUp cannot obtain a visible-frame path for this native
        // glass popover. Drag within its observed on-screen scroll rectangle.
        let frame = scroll.frame.intersection(app.windows.firstMatch.frame)
        XCTAssertFalse(frame.isEmpty, app.debugDescription)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: frame.midX, dy: frame.maxY - 35))
        let end = origin.withOffset(CGVector(dx: frame.midX, dy: frame.minY + 35))
        start.press(forDuration: 0.1, thenDragTo: end)
    }
    #endif
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
