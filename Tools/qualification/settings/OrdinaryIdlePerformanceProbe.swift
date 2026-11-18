import XCTest

/// A first foreground-idle sample of the already installed ordinary app.
/// No injected launch arguments, preferences, audio commands or backend writes.
/// This does not qualify cold launch, playback, scrolling, energy or long sessions.
@MainActor
final class OrdinaryIdlePerformanceProbe: XCTestCase {
    func testForegroundSessionIdleCPUAndPhysicalMemory() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.djconnect.ios")
        app.activate()
        XCTAssertEqual(app.state, .runningForeground)
        guard app.buttons["session-more-menu"].firstMatch.waitForExistence(timeout: 15) else {
            throw XCTSkip("No ordinary active Session available for the idle sample")
        }
        // Dismiss a left-open popover without choosing an option.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.4)).tap()
        XCTAssertFalse(app.descendants(matching: .any)["screen-profile-your-dj"].firstMatch.exists)
        let options = XCTMeasureOptions()
        options.iterationCount = 3 // XCTest also runs one unrecorded warmup.
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)],
                options: options) {
            RunLoop.current.run(until: Date().addingTimeInterval(5))
        }
        XCTAssertEqual(app.state, .runningForeground)
        print("ORDINARY_IDLE_PERFORMANCE samples=3 interval_seconds=5 no_baseline_comparison=true")
    }
}
