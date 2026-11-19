import Foundation
import XCTest

@MainActor final class NativeHelpUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    /// Explicit pixel regression for the shipping renderer's visibility lifecycle.
    /// No provider calls; not part of ordinary PR CI.
    func testForYouAnimationStopsAndReplaysAfterViewportAndPageReturn() {
        let app = XCUIApplication()
        app.launchEnvironment = ["FOR_YOU_ANIMATION_PROBE": "1"]
        app.launch()
        let landscape = app.descendants(matching: .any)["for-you-animation-landscape"].firstMatch
        XCTAssertTrue(landscape.waitForExistence(timeout: 10))
        func wait(_ seconds: TimeInterval) {
            let done = expectation(description: "Animation observation window")
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
            self.wait(for: [done], timeout: seconds + 2)
        }
        func image() -> Data { landscape.screenshot().pngRepresentation }
        wait(2.5)
        let frozen = image()
        wait(0.6)
        XCTAssertEqual(frozen, image(), "Landscape must stop after two seconds")
        activate(app.buttons["animation-scroll-away"])
        wait(0.3)
        XCTAssertFalse(landscape.isHittable)
        activate(app.buttons["animation-scroll-back"])
        let returned = image()
        XCTAssertNotEqual(returned, frozen, "Scrolling back must restart animation")
        wait(0.4)
        XCTAssertNotEqual(returned, image(), "Returned landscape must move")
        wait(2.3)
        let frozenAgain = image()
        wait(0.5)
        XCTAssertEqual(frozenAgain, image(), "Replay must also stop")
        activate(app.buttons["animation-toggle-page"])
        XCTAssertTrue(landscape.waitForNonExistence(timeout: 5))
        activate(app.buttons["animation-toggle-page"])
        XCTAssertTrue(landscape.waitForExistence(timeout: 5))
        let pageReturn = image()
        wait(0.4)
        XCTAssertNotEqual(pageReturn, image(), "Returning to the page must animate again")
        app.terminate()
    }
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
    /// Real published catalogue and Core wire; verifies every native selection,
    /// not a backend/provider verdict. Run explicitly, outside ordinary PR CI.
    func testEveryPublishedNLENHelpOptionForwardsItsOriginalPromptOnBothSurfaces() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "ask_dj_examples_v1", withExtension: "json"))
        let catalogue = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let entries = try XCTUnwrap(catalogue["entries"] as? [[String: Any]])
        XCTAssertEqual(entries.count, 14)
        for language in ["nl", "en"] {
            for surface in ["ask_dj", "active_session"] {
                let app = XCUIApplication()
                app.launchEnvironment = ["HELP_LANGUAGE": language, "HELP_SURFACE": surface,
                    "HELP_CURRENT_CATALOGUE": "1", "HELP_FULL_CATALOGUE": "1"]
                app.launch()
                let more = app.buttons["ask-dj-more-" + surface]
                XCTAssertTrue(more.waitForExistence(timeout: 10))
                for entry in entries {
                    let id = try XCTUnwrap(entry["id"] as? String)
                    let template = try XCTUnwrap((entry["templates"] as? [String: String])?[language])
                    let slots = try XCTUnwrap(entry["slots"] as? [String])
                    var expected = template
                    for slot in slots {
                        let label = try XCTUnwrap(((catalogue["slot_labels"] as? [String: [String: String]])?[slot])?[language])
                        expected = expected.replacingOccurrences(of: "{" + slot + "}", with: label)
                    }
                    activate(more)
                    let scroll = app.scrollViews["ask-dj-full-catalogue"]
                    XCTAssertTrue(scroll.waitForExistence(timeout: 5))
                    let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in scroll.isHittable }, object: nil)
                    XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 5), .completed)
                    let item = app.buttons["ask-dj-catalogue-" + id]
                    for _ in 0..<12 {
                        if item.exists && item.isHittable { break }
                        #if os(macOS)
                        scroll.scroll(byDeltaX: 0, deltaY: -180)
                        #else
                        scroll.swipeUp()
                        #endif
                    }
                    XCTAssertTrue(item.isHittable, "Missing option: \(language)/\(surface)/\(id)")
                    XCTAssertTrue(item.isEnabled)
                    activate(item)
                    let selected = app.staticTexts["help-selected-prompt"]
                    let expectedSelection = (slots.isEmpty ? "send:" : "draft:") + expected
                    let forwarded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                        selected.exists && selected.label == expectedSelection
                    }, object: nil)
                    XCTAssertEqual(XCTWaiter.wait(for: [forwarded], timeout: 5), .completed,
                        "Wrong forwarded prompt: \(language)/\(surface)/\(id)")
                    XCTAssertTrue(scroll.waitForNonExistence(timeout: 5))
                }
                app.terminate()
            }
        }
    }
    func testCurrentCatalogueSuggestionsForwardExactlyTheDisplayedText() {
        for language in ["nl", "en"] {
            for surface in ["ask_dj", "active_session"] {
                let app = XCUIApplication()
                app.launchEnvironment = ["HELP_LANGUAGE": language, "HELP_SURFACE": surface,
                    "HELP_CURRENT_CATALOGUE": "1", "HELP_INTERACTION": "1"]
                app.launch()
                let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ask-dj-suggestion-" + surface + "-"))
                XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
                XCTAssertEqual(rows.count, 3)
                let ids = (0..<3).map { rows.element(boundBy: $0).identifier }
                XCTAssertEqual(Set(ids).count, 3)
                for id in ids {
                    let row = app.buttons[id]
                    let prompt = row.label
                    XCTAssertFalse(prompt.contains("{"))
                    activate(row)
                    XCTAssertEqual(app.staticTexts["help-selected-prompt"].label, prompt)
                    XCTAssertEqual((0..<3).map { rows.element(boundBy: $0).identifier }, ids)
                }
                app.terminate()
            }
        }
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
    func testHelpClickShowsAnchoredPopoutWhileFocusAndTypingDoNot() {
        for surface in ["ask_dj", "active_session"] {
            for populated in [false, true] {
                let app = XCUIApplication()
                app.launchEnvironment = ["HELP_COMPOSER_POPOUT": "1", "HELP_SURFACE": surface, "HELP_POPULATED": populated ? "1" : "0"]
                app.launch()
                #if os(macOS)
                let field = app.textFields.firstMatch
                #else
                let field = app.textViews.firstMatch
                #endif
                XCTAssertTrue(field.waitForExistence(timeout: 5))
                let initialHelp = app.buttons["ask-dj-help-" + surface]
                XCTAssertTrue(initialHelp.waitForExistence(timeout: 3), app.debugDescription)
                #if os(macOS)
                let initialShot = app.windows.firstMatch.screenshot()
                #else
                let initialShot = app.screenshot()
                #endif
                let initialAttachment = XCTAttachment(screenshot: initialShot)
                initialAttachment.name = "manual-help-empty-composer-\(surface)-\(populated ? "populated" : "empty")"
                initialAttachment.lifetime = .keepAlways; add(initialAttachment)
                activate(field)
                let close = app.buttons["ask-dj-suggestions-close"]
                let help = app.buttons["ask-dj-help-" + surface]
                XCTAssertFalse(close.exists, "Focus must not automatically open suggestions")
                XCTAssertTrue(help.waitForExistence(timeout: 5), app.debugDescription)
                XCTAssertGreaterThan(help.frame.midX, field.frame.midX)
                activate(help)
                XCTAssertTrue(close.waitForExistence(timeout: 5), app.debugDescription)
                let more = app.buttons["ask-dj-more-" + surface]
                XCTAssertTrue(more.exists)
                XCTAssertLessThan(more.frame.maxY, field.frame.minY)
                activate(close)
                XCTAssertTrue(close.waitForNonExistence(timeout: 3))
                XCTAssertFalse(app.buttons["For this session"].exists)
                XCTAssertFalse(app.buttons["Always"].exists)
                activate(field)
                XCTAssertFalse(close.exists, "Refocusing must not reopen Help")
                activate(help)
                XCTAssertTrue(close.waitForExistence(timeout: 3))
                #if os(macOS)
                var shot = app.windows.firstMatch.screenshot()
                #else
                var shot = app.screenshot()
                #endif
                var attachment = XCTAttachment(screenshot: shot)
                attachment.name = "composer-help-\(surface)-\(populated ? "populated" : "empty")"
                attachment.lifetime = .keepAlways; add(attachment)
                activate(more)
                XCTAssertTrue(app.buttons["ask-dj-help-close"].waitForExistence(timeout: 3))
                #if os(macOS)
                shot = app.windows.firstMatch.screenshot()
                #else
                shot = app.screenshot()
                #endif
                attachment = XCTAttachment(screenshot: shot)
                attachment.name = "composer-more-closed-catalogue-\(surface)-\(populated ? "populated" : "empty")"
                attachment.lifetime = .keepAlways; add(attachment)
                activate(app.buttons["ask-dj-help-close"])
                activate(help)
                XCTAssertTrue(close.waitForExistence(timeout: 3))
                activate(field)
                field.typeText("x")
                XCTAssertTrue(help.waitForNonExistence(timeout: 3), app.debugDescription)
                XCTAssertTrue(close.waitForNonExistence(timeout: 3), app.debugDescription)
                field.typeText(XCUIKeyboardKey.delete.rawValue)
                XCTAssertTrue(help.waitForExistence(timeout: 3), app.debugDescription)
                XCTAssertFalse(close.exists, "Clearing the draft must not reopen suggestions")
                app.terminate()
            }
        }
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
    func testSessionEndsAndMissingCurrentObservationNeverAdvertisesCommands() {
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
