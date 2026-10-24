import XCTest
@MainActor final class NativePersonaReactionUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication(); app.launch(); return app
    }
    private func avatar(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "avatar-control").firstMatch
    }
    func testSingleDoubleTripleEachDispatchOnlyFinalChoiceDuringOrdinaryUpdates() {
        let app = launch(); let control = avatar(app)
        XCTAssertTrue(control.waitForExistence(timeout: 10))
        for (count, expected) in [(1,"check_in"),(2,"playful"),(3,"easter_egg"),(2,"playful"),(1,"check_in"),(3,"easter_egg")] {
            app.buttons["clear"].tap()
            control.tap(withNumberOfTaps: count, numberOfTouches: 1)
            let value = app.staticTexts["requests"]
            XCTAssertTrue(value.waitForExistence(timeout: 3))
            let exact = NSPredicate(format: "label == %@", "requests:" + expected)
            expectation(for: exact, evaluatedWith: value)
            waitForExpectations(timeout: 4)
            Thread.sleep(forTimeInterval: 0.7)
            XCTAssertEqual(value.label, "requests:" + expected)
        }
        XCTAssertNotEqual(app.staticTexts["revision"].label,"revision:0")
    }
    func testBusyAndWithdrawalDoNotDispatch() {
        let app = launch(); let control = avatar(app)
        XCTAssertTrue(control.waitForExistence(timeout: 10))
        app.buttons["busy"].tap()
        control.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(app.staticTexts["requests"].label, "requests:")
        app.buttons["busy"].tap(); app.buttons["withdraw"].tap()
        control.tap(); Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(app.staticTexts["requests"].label, "requests:")
    }
    func testNativeContextMenuKeepsPlayfulAlternative() {
        let app = launch(); let control = avatar(app)
        XCTAssertTrue(control.waitForExistence(timeout: 10))
        control.press(forDuration: 1.2)
        let item = app.buttons["Playful reaction"]
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        let value = app.staticTexts["requests"]
        expectation(for: NSPredicate(format: "label == %@", "requests:playful"), evaluatedWith: value)
        waitForExpectations(timeout: 4)
    }

}
