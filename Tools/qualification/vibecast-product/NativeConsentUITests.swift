import XCTest

@MainActor final class NativeConsentUITests: XCTestCase {
    private var textAttribute: String {
        #if os(macOS)
        "value"
        #else
        "label"
        #endif
    }
    private func open(_ mode: String = "normal") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["CONSENT_UI_MODE"] = mode
        app.launch()
        let open = app.buttons["consent-harness-open"]
        let opened = open.waitForExistence(timeout: 10)
        if !opened { print("CONSENT_OPEN_TREE " + app.debugDescription); capture(app, "missing-host-window") }
        XCTAssertTrue(opened)
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: open)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 15), .completed)
        open.consentActivate()
        let digit = app.textFields["vibecast-handoff-digit-0"]
        let found = digit.waitForExistence(timeout: 5)
        if !found { print("CONSENT_FORM_TREE " + app.debugDescription); capture(app, "missing-code-entry") }
        XCTAssertTrue(found)
        digit.consentActivate(); digit.typeText("000000")
        let lookup = app.buttons["display-consent-lookup"]
        XCTAssertTrue(lookup.isEnabled); lookup.consentActivate()
        XCTAssertTrue(app.buttons["display-consent-confirm"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["consent-harness-approvals"].consentText, "approvals:0")
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        #if os(macOS)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        #else
        let attachment = XCTAttachment(screenshot: app.screenshot())
        #endif
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testNativeLookupAndExplicitSingleConfirmation() {
        let app = open()
        capture(app, "native-display-consent-ready")
        app.buttons["display-consent-confirm"].consentActivate()
        let one = XCTNSPredicateExpectation(predicate: NSPredicate(format: "%K == %@", textAttribute, "approvals:1"),
                                            object: app.staticTexts["consent-harness-approvals"])
        XCTAssertEqual(XCTWaiter.wait(for: [one], timeout: 10), .completed)
        XCTAssertTrue(app.staticTexts["Screen approved for your current Session."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["display-consent-confirm"].exists)
        capture(app, "native-display-consent-approved")
        app.buttons["display-consent-close"].consentActivate()
        XCTAssertTrue(app.buttons["consent-harness-open"].waitForExistence(timeout: 5))
    }

    func testNativeProfileWithdrawalRemovesConfirmationWithoutEffect() {
        let app = open()
        app.buttons["consent-harness-withdraw"].consentActivate()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                object: app.buttons["display-consent-confirm"])
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 5), .completed)
        XCTAssertTrue(app.staticTexts["The screen code or current Session is no longer available."].waitForExistence(timeout: 5))
        let disabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"),
                                                object: app.buttons["display-consent-lookup"])
        let outcome = XCTWaiter.wait(for: [disabled], timeout: 5)
        if outcome != .completed {
            print("PROFILE_WITHDRAWAL_MODEL " + app.staticTexts["consent-harness-allowed"].consentText)
            print(app.debugDescription)
        }
        XCTAssertEqual(outcome, .completed,
                       "Withdrawn Profile authority must also disable the native lookup action")
        XCTAssertEqual(app.staticTexts["consent-harness-approvals"].consentText, "approvals:0")
        capture(app, "native-display-consent-withdrawn")
    }

    func testNativeUnknownApprovalOffersNoResend() {
        let app = open("unknown")
        app.buttons["display-consent-confirm"].consentActivate()
        let one = XCTNSPredicateExpectation(predicate: NSPredicate(format: "%K == %@", textAttribute, "approvals:1"),
                                            object: app.staticTexts["consent-harness-approvals"])
        XCTAssertEqual(XCTWaiter.wait(for: [one], timeout: 10), .completed)
        XCTAssertTrue(app.staticTexts["Approval was not confirmed. Check the screen before starting a new request."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["display-consent-confirm"].exists)
        XCTAssertFalse(app.buttons["display-consent-lookup"].exists)
        capture(app, "native-display-consent-uncertain")
    }
    func testNativeStopRevokesOnlyAfterExplicitTap() {
        let app = open()
        app.buttons["display-consent-confirm"].consentActivate()
        let stop = app.buttons["display-consent-stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 10))
        XCTAssertTrue(stop.isEnabled)
        stop.consentActivate()
        XCTAssertTrue(app.staticTexts["Screen sharing stopped. Your DJ session continues."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["display-consent-stop"].exists)
        XCTAssertEqual(app.staticTexts["consent-harness-approvals"].consentText, "approvals:1")
        capture(app, "native-display-consent-stopped")
    }

    func testNativeUncertainStopDoesNotOfferAutomaticResend() {
        let app = open("unknown-revoke")
        app.buttons["display-consent-confirm"].consentActivate()
        let stop = app.buttons["display-consent-stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 10)); stop.consentActivate()
        XCTAssertTrue(app.staticTexts["Stopping screen sharing could not be confirmed. Check the screen before continuing."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["display-consent-stop"].exists)
        XCTAssertFalse(app.buttons["display-consent-lookup"].exists)
        capture(app, "native-display-consent-stop-uncertain")
    }

    func testRendezvousScreenTransitionsToSeparateConsentWithoutLateCancellation() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["CONSENT_UI_ROUTE"] = "rendezvous"
        app.launch()
        let entry = app.buttons["consent-harness-open"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: entry)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 15), .completed)
        entry.consentActivate()
        let codeEntry = app.buttons["vibecast-rendezvous-tv-code"]
        XCTAssertTrue(codeEntry.waitForExistence(timeout: 10))
        XCTAssertTrue(codeEntry.isEnabled)
        codeEntry.consentActivate()
        let digit = app.textFields["vibecast-handoff-digit-0"]
        XCTAssertTrue(digit.waitForExistence(timeout: 10))
        digit.consentActivate(); digit.typeText("000000")
        app.buttons["display-consent-lookup"].consentActivate()
        let confirm = app.buttons["display-consent-confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        app.buttons["consent-harness-obsolete-rendezvous-close"].consentActivate()
        XCTAssertTrue(confirm.exists)
        XCTAssertEqual(app.staticTexts["consent-harness-approvals"].consentText, "approvals:0")
        confirm.consentActivate()
        XCTAssertTrue(app.staticTexts["Screen approved for your current Session."].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["consent-harness-approvals"].consentText, "approvals:1")
        capture(app, "native-rendezvous-to-explicit-consent")
        app.terminate()
    }

    func testReopenedRendezvousSurvivesOldRootNilAndReconstructionThenCloses() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["CONSENT_UI_ROUTE"] = "rendezvous"
        app.launch()
        let entry = app.buttons["consent-harness-open"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: entry)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 15), .completed)
        entry.consentActivate()
        let codeEntry = app.buttons["vibecast-rendezvous-tv-code"]
        XCTAssertTrue(codeEntry.waitForExistence(timeout: 10))
        codeEntry.consentActivate()
        XCTAssertTrue(app.textFields["vibecast-handoff-digit-0"].waitForExistence(timeout: 10))
        app.buttons["consent-harness-reopen-rendezvous"].consentActivate()
        let qr = app.switches["vibecast-rendezvous-installation"]
        XCTAssertTrue(qr.waitForExistence(timeout: 10))
        app.buttons["consent-harness-obsolete-root-close"].consentActivate()
        XCTAssertTrue(qr.exists)
        app.buttons["consent-harness-reconstruct"].consentActivate()
        XCTAssertTrue(qr.exists)
        capture(app, "native-reopened-rendezvous-preserved")
        app.buttons["vibecast-rendezvous-close"].consentActivate()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: qr)
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 10), .completed)
        XCTAssertTrue(entry.isHittable)
        app.terminate()
    }

}

@MainActor private extension XCUIElement {
    var consentText: String {
        #if os(macOS)
        (value as? String) ?? label
        #else
        label
        #endif
    }
    func consentActivate() {
        #if os(macOS)
        click()
        #else
        tap()
        #endif
    }
}
