import Foundation
import XCTest
@MainActor final class VisualButtonProbeTests:XCTestCase {
 func testBackgroundAndOwnerWithdrawalStillCloseTheVisit() {
  let a=XCUIApplication();a.launch()
  let status=a.staticTexts["probe-status"]
  let ready=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in status.exists && status.label.contains("ready:1") && status.label.contains("mode:1")},object:nil)
  XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:20),.completed)
  XCUIDevice.shared.press(.home);a.activate()
  XCTAssertTrue(a.staticTexts["probe-closed"].waitForExistence(timeout:10))
  a.terminate();a.launch()
  let again=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in status.exists && status.label.contains("ready:1") && status.label.contains("mode:1")},object:nil)
  XCTAssertEqual(XCTWaiter.wait(for:[again],timeout:20),.completed)
  a.buttons["probe-withdraw-owner"].tap()
  XCTAssertTrue(a.staticTexts["probe-closed"].waitForExistence(timeout:10))
  XCTAssertTrue(status.label.contains("post:0") && status.label.contains("context:0") && status.label.contains("ask:0"))
  a.terminate()
 }
 func testActualVibeScapeButtonsDenyCaptureAndReloadServerHelp() {
  continueAfterFailure=true
  let monitor=addUIInterruptionMonitor(withDescription:"Explicit microphone denial only") {alert in
   let deny=alert.buttons.matching(NSPredicate(format:"label IN %@",["Don’t Allow","Don't Allow","Sta niet toe","Niet toestaan"])).firstMatch
   guard deny.exists else {XCTFail("Unknown alert; never accept automatically");return true};deny.tap();return true
  };defer{removeUIInterruptionMonitor(monitor)}
  let a=XCUIApplication();a.launch()
  defer {
   let image=XCTAttachment(screenshot:a.screenshot());image.name="Actual voice and help";image.lifetime = .keepAlways;add(image)
   let tree=XCTAttachment(string:a.debugDescription);tree.name="Actual voice and help hierarchy";tree.lifetime = .keepAlways;add(tree)
   a.terminate()
  }
  let status=a.staticTexts["probe-status"]
  let ready=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in status.exists && status.label.contains("ready:1")},object:nil)
  XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:20),.completed)
  XCTAssertTrue(status.label.contains("mic:0") && status.label.contains("speech:0"),"Fresh test-only identity must start without audio permission")
  func reveal(){
   let help=a.buttons["vibescape-help"]
   if !help.exists || !help.isHittable { a.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.9)).tap() }
  }
  let mic=a.buttons["vibescape-microphone"]
  for attempt in 1...2 {
   reveal();XCTAssertTrue(mic.waitForExistence(timeout:5));XCTAssertTrue(mic.isEnabled);mic.tap()
   if attempt == 1 {
   a.tap()
   let system=XCUIApplication(bundleIdentifier:"com.apple.springboard");let appAlert=a.alerts.firstMatch;let systemAlert=system.alerts.firstMatch
   let alert=appAlert.waitForExistence(timeout:2) ? appAlert:systemAlert
   if alert.waitForExistence(timeout:1) {let deny=alert.buttons.matching(NSPredicate(format:"label IN %@",["Don’t Allow","Don't Allow","Sta niet toe","Niet toestaan"])).firstMatch;XCTAssertTrue(deny.exists);deny.tap()}
   }
   reveal()
   let denied=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in status.exists && status.label.contains("mic:2") && a.staticTexts["vibescape-voice-status"].exists},object:nil)
   XCTAssertEqual(XCTWaiter.wait(for:[denied],timeout:15),.completed)
   XCTAssertTrue(status.label.contains("mode:1"),status.label)
   XCTAssertTrue(status.label.contains("speech:0") && status.label.contains("post:0") && status.label.contains("context:0") && status.label.contains("ask:0"))
  }
  var previous=""
  for _ in 1...2 {
   reveal();XCTAssertTrue(status.label.contains("mode:1"),status.label)
   let help=a.buttons["vibescape-help"];XCTAssertTrue(help.isHittable);help.tap()
   let example=a.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Probe visual read ")).firstMatch
   XCTAssertTrue(example.waitForExistence(timeout:10));XCTAssertNotEqual(example.label,previous);previous=example.label
   let shot=XCTAttachment(screenshot:a.screenshot());shot.name="Actual VibeScape dynamic help";shot.lifetime = .keepAlways;add(shot)
   a.buttons["Close"].tap()
  }
  XCTAssertTrue(status.label.contains("post:0") && status.label.contains("context:0") && status.label.contains("ask:0"))
  // The defer captures the live screen before terminating this isolated host.
 }
}
