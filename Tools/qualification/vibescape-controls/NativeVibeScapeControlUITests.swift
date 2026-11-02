import Foundation
import XCTest
@MainActor final class VisualButtonProbeTests:XCTestCase {
 func testAbsentSettingsFenceRefusesVoiceBeforeMicrophonePermission() {
  let a=XCUIApplication();a.launchArguments=["--uitesting","--without-settings-fence"];a.launch();defer{a.terminate()}
  let status=a.staticTexts["probe-status"]
  let ready=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in status.exists && status.label.contains("ready:1")},object:nil)
  XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:20),.completed)
  a.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.9)).tap()
  let mic=a.buttons["vibescape-microphone"];XCTAssertTrue(mic.waitForExistence(timeout:5));mic.tap()
  let failed=a.staticTexts["vibescape-voice-status"]
  // Hidden chrome may consume the first tap only to reveal its controls.
  if !failed.waitForExistence(timeout:1) { mic.tap() }
  XCTAssertTrue(failed.waitForExistence(timeout:5))
  XCTAssertTrue(status.label.contains("mic:0") && status.label.contains("speech:0"),status.label)
  XCTAssertTrue(status.label.contains("post:0") && status.label.contains("ask:0"),status.label)
  XCTAssertFalse(a.alerts.firstMatch.exists)
 }
 func testAcceptedCharacterControlsChangeTheLiveWorld() {
  let a=XCUIApplication();a.launchArguments=["--uitesting","--worlds"];a.launch();defer{a.terminate()}
  let screen=a.otherElements["screen-vibescape"]
  XCTAssertTrue(screen.waitForExistence(timeout:20))
  for (persona,title) in [("radio_dj","Kinetic atelier"),("club_dj","Light architecture"),("festival_dj","Cosmic bloom"),("home_dj","Liquid world")] {
   let button=a.buttons["session-persona-"+persona];XCTAssertTrue(button.waitForExistence(timeout:10));XCTAssertTrue(button.isEnabled);button.tap()
   let changed=XCTNSPredicateExpectation(predicate:NSPredicate{_,_ in (screen.value as? String)==title},object:nil)
   XCTAssertEqual(XCTWaiter.wait(for:[changed],timeout:10),.completed)
   Thread.sleep(forTimeInterval:2)
   let image=XCTAttachment(screenshot:a.screenshot());image.name="Live accepted world "+persona;image.lifetime = .keepAlways;add(image)
  }
  XCTAssertTrue(a.staticTexts["probe-status"].label.contains("post:4"))
  XCTAssertTrue(a.staticTexts["probe-status"].label.contains("ask:0"))
 }
 func testRejectedCharacterSaveRetainsTheConfirmedWorld() {
  let a=XCUIApplication();a.launchArguments=["--uitesting","--worlds","--reject-persona"];a.launch();defer{a.terminate()}
  let screen=a.otherElements["screen-vibescape"]
  XCTAssertTrue(screen.waitForExistence(timeout:20))
  let button=a.buttons["session-persona-radio_dj"];XCTAssertTrue(button.waitForExistence(timeout:10));button.tap()
  let rejected=XCTNSPredicateExpectation(predicate:NSPredicate{_,_ in a.staticTexts["probe-status"].label.contains("post:1") && button.isEnabled},object:nil)
  XCTAssertEqual(XCTWaiter.wait(for:[rejected],timeout:10),.completed)
  XCTAssertEqual(screen.value as? String,"Liquid world")
 }
 func testFiveLanguagesLargeTextAndReduceMotionKeepDynamicsAccessible() {
  let settings=XCUIApplication(bundleIdentifier:"com.apple.Preferences");settings.launch()
  let accessibility=settings.staticTexts.matching(NSPredicate(format:"label IN %@",["Accessibility","Toegankelijkheid"])).firstMatch
  for _ in 0..<6 where !accessibility.isHittable {settings.swipeUp()}
  XCTAssertTrue(accessibility.waitForExistence(timeout:10));accessibility.tap()
  let motion=settings.staticTexts.matching(NSPredicate(format:"label IN %@",["Motion","Beweging"])).firstMatch;XCTAssertTrue(motion.waitForExistence(timeout:10));motion.tap()
  let reduced=settings.switches.matching(NSPredicate(format:"label IN %@",["Reduce Motion","Verminder beweging"])).firstMatch;XCTAssertTrue(reduced.waitForExistence(timeout:10))
  if (reduced.value as? String) != "1" {reduced.coordinate(withNormalizedOffset:CGVector(dx:0.92,dy:0.5)).tap()}
  let enabled=XCTNSPredicateExpectation(predicate:NSPredicate{_,_ in (reduced.value as? String)=="1"},object:nil)
  XCTAssertEqual(XCTWaiter.wait(for:[enabled],timeout:5),.completed);settings.terminate()
  for (language,label,follow) in [("en","Dynamics","Follow DJ"),("nl","Dynamiek","Volg DJ"),("de","Dynamik","DJ folgen"),("fr","Dynamique","Suivre le DJ"),("es","Dinámica","Seguir al DJ")] {
   let a=XCUIApplication();a.launchArguments=["--uitesting","--probe-language",language,"--reduce-motion","--large-text"];a.launch()
   let slider=a.sliders["vibescape-dynamics"]
   XCTAssertTrue(slider.waitForExistence(timeout:20));XCTAssertEqual(slider.label,label)
   XCTAssertTrue(a.staticTexts["probe-status"].label.contains("rm:1"),"Owned simulator must have actual system Reduce Motion enabled")
   slider.adjust(toNormalizedSliderPosition:0.2)
   let reset=a.buttons.matching(NSPredicate(format:"label == %@",follow)).firstMatch
   XCTAssertTrue(reset.exists);reset.tap()
   let image=XCTAttachment(screenshot:a.screenshot());image.name="Large text Reduce Motion "+language;image.lifetime = .keepAlways;add(image)
   a.terminate()
  }
 }
 func testBackgroundAndOwnerWithdrawalStillCloseTheVisit() {
  let a=XCUIApplication();a.launchArguments=["--uitesting"];a.launch()
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
  XCTAssertTrue(status.label.contains("post:0") && status.label.contains("ask:0"))
  a.terminate()
 }
 func testActualVibeScapeButtonsDenyCaptureAndReloadServerHelp() {
  continueAfterFailure=true
  let monitor=addUIInterruptionMonitor(withDescription:"Explicit microphone denial only") {alert in
   let deny=alert.buttons.matching(NSPredicate(format:"label IN %@",["Don’t Allow","Don't Allow","Sta niet toe","Niet toestaan"])).firstMatch
   guard deny.exists else {XCTFail("Unknown alert; never accept automatically");return true};deny.tap();return true
  };defer{removeUIInterruptionMonitor(monitor)}
  let a=XCUIApplication();a.launchArguments=["--uitesting"];a.launch()
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
   // AX may retain a cached element while its controls are fading. Touch the
   // actual bottom control area before every action, including cached buttons.
   a.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.9)).tap()
  }
  let mic=a.buttons["vibescape-microphone"]
  for attempt in 1...2 {
   reveal();XCTAssertTrue(mic.waitForExistence(timeout:5));XCTAssertTrue(mic.isEnabled);mic.tap()
   // A tap delivered while the chrome is hidden reveals it. Do not confuse
   // a cached AX element with an already submitted voice request.
   if !a.staticTexts["vibescape-voice-status"].waitForExistence(timeout:1) {mic.tap()}
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
   XCTAssertTrue(status.label.contains("speech:0") && status.label.contains("post:0") && status.label.contains("ask:0"))
  }
  var previous=""
  for _ in 1...2 {
   reveal();XCTAssertTrue(status.label.contains("mode:1"),status.label)
   let help=a.buttons["vibescape-help"];XCTAssertTrue(help.isHittable);help.tap()
   if !a.staticTexts["VibeScape help"].waitForExistence(timeout:1) {help.tap()}
   let example=a.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Probe visual read ")).firstMatch
   XCTAssertTrue(example.waitForExistence(timeout:10));XCTAssertNotEqual(example.label,previous);previous=example.label
   let shot=XCTAttachment(screenshot:a.screenshot());shot.name="Actual VibeScape dynamic help";shot.lifetime = .keepAlways;add(shot)
   a.buttons["Close"].tap()
  }
  XCTAssertTrue(status.label.contains("post:0") && status.label.contains("ask:0"))
  // The defer captures the live screen before terminating this isolated host.
 }
}
