import XCTest

@MainActor final class NativeConsentUITests: XCTestCase {
    private func open(_ mode: String = "normal") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["CONSENT_UI_MODE"] = mode
        app.launch()
        let open = app.buttons["consent-harness-open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: open)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 15), .completed)
        open.tap()
        let digit = app.textFields["vibecast-handoff-digit-0"]
        XCTAssertTrue(digit.waitForExistence(timeout: 5))
        digit.tap(); digit.typeText("000000")
        let lookup = app.buttons["display-consent-lookup"]
        XCTAssertTrue(lookup.isEnabled); lookup.tap()
        XCTAssertTrue(app.buttons["display-consent-confirm"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["consent-harness-approvals"].label, "approvals:0")
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testNativeLookupAndExplicitSingleConfirmation() {
        let app = open()
        capture(app, "native-display-consent-ready")
        app.buttons["display-consent-confirm"].tap()
        let one = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "approvals:1"),
                                            object: app.staticTexts["consent-harness-approvals"])
        XCTAssertEqual(XCTWaiter.wait(for: [one], timeout: 10), .completed)
        XCTAssertTrue(app.staticTexts["Screen approved for your current Session."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["display-consent-confirm"].exists)
        capture(app, "native-display-consent-approved")
        app.buttons["display-consent-close"].tap()
        XCTAssertTrue(app.buttons["consent-harness-open"].waitForExistence(timeout: 5))
    }

    func testNativeProfileWithdrawalRemovesConfirmationWithoutEffect() {
        let app = open()
        app.buttons["consent-harness-withdraw"].tap()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                object: app.buttons["display-consent-confirm"])
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 5), .completed)
        XCTAssertTrue(app.staticTexts["The screen code or current Session is no longer available."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["display-consent-lookup"].isEnabled,
                       "Withdrawn Profile authority must also disable the native lookup action")
        XCTAssertEqual(app.staticTexts["consent-harness-approvals"].label, "approvals:0")
        capture(app, "native-display-consent-withdrawn")
    }

    func testNativeUnknownApprovalOffersNoResend() {
        let app = open("unknown")
        app.buttons["display-consent-confirm"].tap()
        let one = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "approvals:1"),
                                            object: app.staticTexts["consent-harness-approvals"])
        XCTAssertEqual(XCTWaiter.wait(for: [one], timeout: 10), .completed)
        XCTAssertTrue(app.staticTexts["Approval was not confirmed. Check the screen before starting a new request."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["display-consent-confirm"].exists)
        XCTAssertFalse(app.buttons["display-consent-lookup"].exists)
        capture(app, "native-display-consent-uncertain")
    }
}
