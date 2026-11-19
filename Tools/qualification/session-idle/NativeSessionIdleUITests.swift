import XCTest
import UIKit

@MainActor final class NativeSessionIdleUITests: XCTestCase {
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = arguments; app.launch(); return app
    }
    private func card(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["session-current-card"].firstMatch
    }
    private func wait(_ assertion: @escaping () -> Bool) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in assertion() }, object: nil)], timeout: 8), .completed)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
        let tree = XCTAttachment(string: app.debugDescription); tree.name = name + "-accessibility"; tree.lifetime = .keepAlways; add(tree)
    }
    private func olderRow(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[UIDevice.current.userInterfaceIdiom == .pad ? "history-10" : "history-5"].firstMatch
    }
    private func revealOlderRowWithHeaderOffscreen(_ app: XCUIApplication) -> XCUIElement {
        let row = olderRow(app)
        for _ in 0..<12 {
            if row.isHittable && app.staticTexts["probe-status"].label.contains("v:0") { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(row.isHittable)
        XCTAssertTrue(app.staticTexts["probe-status"].label.contains("v:0"), "An offscreen test requires the current header to be outside the viewport")
        return row
    }
    func testNativeIdleTransitionsAndPartialRefreshKeepOneAvatar() {
        let app = launch(); defer { app.terminate() }
        let current = card(app); XCTAssertTrue(current.waitForExistence(timeout: 10))
        wait { abs(current.frame.width - 112) < 2 && abs(current.frame.height - 112) < 2 }
        let avatar = app.descendants(matching: .any)["session-dj-avatar"].firstMatch
        let origin = avatar.frame.origin
        XCTAssertFalse(app.staticTexts["De DJ luistert met je mee."].exists)
        capture(app, "idle-avatar-only")
        app.buttons["probe-moment"].tap()
        wait { current.frame.width > 250 }
        let expanded = current.frame
        XCTAssertEqual(avatar.frame.minX, origin.x, accuracy: 1)
        XCTAssertEqual(avatar.frame.minY, origin.y, accuracy: 1)
        XCTAssertTrue(app.descendants(matching: .any)["session-current-moment"].exists)
        capture(app, "valid-text-without-tts")
        for _ in 0..<5 {
            app.buttons["probe-refresh"].tap()
            XCTAssertEqual(current.frame.height, expanded.height, accuracy: 1)
            XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "session-dj-avatar").count, 1)
        }
        app.buttons["probe-partial"].tap()
        wait { abs(current.frame.height - expanded.height) < 2 && abs(current.frame.width - expanded.width) < 2 }
        XCTAssertFalse(app.descendants(matching: .any)["session-current-moment"].exists, "Geometry cannot preserve withdrawn/unadmitted text")
        app.buttons["probe-moment"].tap()
        wait { app.descendants(matching: .any)["session-current-moment"].exists }
        app.buttons["probe-idle"].tap()
        wait { abs(current.frame.width - 112) < 2 }
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "session-dj-avatar").count, 1)
        capture(app, "returned-idle")
        XCTAssertTrue(app.descendants(matching: .any)["history-0"].exists)
    }
    func testOperationalFeedbackAndDraftStayDistinctFromIdle() {
        let app = launch(); defer { app.terminate() }
        XCTAssertTrue(card(app).waitForExistence(timeout: 10))
        for phase in ["paused", "recovering", "unavailable", "start"] {
            app.buttons["probe-" + phase].tap()
            wait { self.card(app).frame.width > 250 }
            capture(app, "feedback-" + phase)
        }
        XCTAssertEqual(app.textFields["probe-draft"].value as? String, "Unsent draft")
        app.buttons["probe-cycle"].tap()
        wait { app.staticTexts["probe-status"].label.contains("phase:moment") }
        wait { app.staticTexts["probe-status"].label.contains("phase:idle") }
        XCTAssertEqual(app.textFields["probe-draft"].value as? String, "Unsent draft")
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Programmatic presentation changes keep chat focus")
    }
    func testExistingAvatarTapWorksInBothCardFormats() {
        let app = launch(["--interaction"]); defer { app.terminate() }
        XCTAssertTrue(card(app).waitForExistence(timeout: 10))
        let avatar = app.descendants(matching: .any)["session-dj-avatar"].firstMatch
        XCTAssertFalse(avatar.label.isEmpty)
        avatar.tap(); wait { app.staticTexts["probe-status"].label.contains("taps:1") }
        app.buttons["probe-moment"].tap(); wait { self.card(app).frame.width > 250 }
        avatar.tap(); wait { app.staticTexts["probe-status"].label.contains("taps:2") }
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "session-dj-avatar").count, 1)
        capture(app, "interactive-avatar-expanded")
    }
    func testReadingPositionSurvivesCardResizing() {
        let app = launch(); defer { app.terminate() }
        XCTAssertTrue(card(app).waitForExistence(timeout: 10))
        let row = revealOlderRowWithHeaderOffscreen(app)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: row.identifier).count, 1)
        // Record a no-op control separately: an incoming contribution must be
        // measured without any tap/focus action during the actual transition.
        let beforeControl = row.frame.minY
        app.buttons["probe-refresh"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        print("HOST_NOOP_ROW5 before=\(beforeControl) after=\(row.frame.minY)")
        app.buttons["probe-reading-cycle"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        var before = row.frame.minY
        for _ in 0..<5 {
            Thread.sleep(forTimeInterval: 0.2)
            let next = row.frame.minY
            if abs(next - before) < 0.5 { break }
            before = next
        }
        let status = app.staticTexts["probe-status"]
        let readID = status.label.components(separatedBy: "anchor:").last?.components(separatedBy: " ").first
        capture(app, "reading-position-before-autonomous-delivery")
        wait { status.label.contains("phase:moment") }
        wait { abs(row.frame.minY - before) < 2 }
        XCTAssertEqual(row.frame.minY, before, accuracy: 2, "Reading row after autonomous expansion")
        XCTAssertEqual(status.label.components(separatedBy: "anchor:").last?.components(separatedBy: " ").first, readID)
        print("AUTONOMOUS_EXPANDED_ROW5 before=\(before) after=\(row.frame.minY)")
        capture(app, "reading-position-expanded-autonomously")
        wait { status.label.contains("phase:idle") }
        wait { abs(row.frame.minY - before) < 2 }
        XCTAssertEqual(row.frame.minY, before, accuracy: 2, "Reading row after autonomous compaction")
        XCTAssertEqual(status.label.components(separatedBy: "anchor:").last?.components(separatedBy: " ").first, readID)
        print("AUTONOMOUS_COMPACT_ROW5 before=\(before) after=\(row.frame.minY)")
        XCTAssertTrue(row.isHittable)
        capture(app, "reading-position-retained")
        for _ in 0..<12 where !self.card(app).isHittable { app.scrollViews.firstMatch.swipeDown() }
        wait { abs(self.card(app).frame.width - 112) < 2 }
        capture(app, "reading-return-current-idle")
    }
    func testNewSessionDoesNotBorrowAnOldCompactFormat() {
        let app = launch(); defer { app.terminate() }
        XCTAssertTrue(card(app).waitForExistence(timeout: 10))
        wait { abs(self.card(app).frame.width - 112) < 2 }
        app.buttons["probe-newpartial"].tap()
        wait { self.card(app).frame.width > 250 }
        XCTAssertFalse(app.descendants(matching: .any)["session-current-moment"].exists)
    }
    func testOffscreenExpandedCardReturnsAsCurrentCompactTile() {
        let app = launch(["--initial-moment"]); defer { app.terminate() }
        XCTAssertTrue(card(app).waitForExistence(timeout: 10))
        wait { self.card(app).frame.width > 250 }
        let row = revealOlderRowWithHeaderOffscreen(app)
        Thread.sleep(forTimeInterval: 0.3)
        let before = row.frame.minY
        app.buttons["probe-idle"].tap()
        wait { abs(row.frame.minY - before) < 2 }
        for _ in 0..<12 where !self.card(app).isHittable { app.scrollViews.firstMatch.swipeDown() }
        wait { abs(self.card(app).frame.width - 112) < 2 && abs(self.card(app).frame.height - 112) < 2 }
        XCTAssertTrue(self.card(app).isHittable)
        XCTAssertFalse(app.descendants(matching: .any)["session-current-moment"].exists)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "session-dj-avatar").count, 1)
        capture(app, "offscreen-expanded-returns-compact")
    }
    func testIPadRotationKeepsIntrinsicTileAndFitsUpdatedPane() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad rotation coverage") }
        let app = launch(["--initial-moment"]); defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(card(app).waitForExistence(timeout: 10))
        _ = revealOlderRowWithHeaderOffscreen(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        wait { app.frame.width > app.frame.height }
        app.buttons["probe-idle"].tap()
        for _ in 0..<12 where !self.card(app).isHittable { app.scrollViews.firstMatch.swipeDown() }
        wait { abs(self.card(app).frame.width - 112) < 2 }
        XCTAssertLessThanOrEqual(self.card(app).frame.maxX, app.frame.maxX)
        capture(app, "ipad-landscape-returned-idle")
        app.buttons["probe-moment"].tap()
        wait { self.card(app).frame.width > 600 }
        XCTAssertLessThanOrEqual(self.card(app).frame.maxX, app.frame.maxX)
        capture(app, "ipad-landscape-valid-contribution")
    }
    func testLargeTextAndActualSystemReduceMotion() {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences"); settings.launch()
        let accessibility = settings.staticTexts.matching(NSPredicate(format: "label IN %@", ["Accessibility", "Toegankelijkheid"])).firstMatch
        for _ in 0..<6 where !accessibility.isHittable { settings.swipeUp() }
        XCTAssertTrue(accessibility.waitForExistence(timeout: 10)); accessibility.tap()
        let motion = settings.staticTexts.matching(NSPredicate(format: "label IN %@", ["Motion", "Beweging"])).firstMatch
        XCTAssertTrue(motion.waitForExistence(timeout: 10)); motion.tap()
        let reduced = settings.switches.matching(NSPredicate(format: "label IN %@", ["Reduce Motion", "Verminder beweging"])).firstMatch
        XCTAssertTrue(reduced.waitForExistence(timeout: 10))
        if (reduced.value as? String) != "1" { reduced.coordinate(withNormalizedOffset: .init(dx: 0.92, dy: 0.5)).tap() }
        wait { (reduced.value as? String) == "1" }; settings.terminate()
        let app = launch(["--large-text", "--language=de"]); defer { app.terminate() }
        XCTAssertTrue(card(app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["probe-status"].label.contains("rm:1"))
        wait { abs(self.card(app).frame.width - 112) < 2 }
        app.buttons["probe-moment"].tap(); wait { self.card(app).frame.width > 250 }
        XCTAssertTrue(app.descendants(matching: .any)["session-current-moment"].exists)
        capture(app, "large-text-system-reduce-motion")
    }
}
