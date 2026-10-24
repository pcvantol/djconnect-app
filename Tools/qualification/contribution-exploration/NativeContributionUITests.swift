import XCTest
@MainActor final class ContributionProbeTests:XCTestCase {
 private func launch()->XCUIApplication { let a=XCUIApplication();a.launch();XCTAssertTrue(a.staticTexts["contribution-content"].waitForExistence(timeout:10));return a }
 private func expectCount(_ app:XCUIApplication,_ value:Int) { Thread.sleep(forTimeInterval:1.2);XCTAssertEqual(app.staticTexts["requests"].label,"requests:\(value)") }
 func testSingleTapSendsExactlyOnceAndSiblingControlsKeepOwnActions() {
  let a=launch();a.staticTexts["contribution-content"].tap();expectCount(a,1)
  for name in ["Play","TTS","Artwork","Source","Avatar"] {a.buttons["sibling-"+name].tap()}
  XCTAssertEqual(a.staticTexts["controls"].label,"controls:5");expectCount(a,1)
 }
 func testDoubleTripleAndLongPressSelectWithoutSending() {
  for count in [2,3,0] {
   let a=launch();let text=a.staticTexts["contribution-content"]
   if count==0 {text.press(forDuration:1.2)}else{text.tap(withNumberOfTaps:count,numberOfTouches:1)}
   expectCount(a,0);a.terminate()
  }
 }
 func testGroupedAnswerTextPreservesSingleTapAndSelection() {
  for count in [1,2,3,0] {
   let a=XCUIApplication();a.launchArguments=["--grouped-text"];a.launch()
   let text=a.staticTexts["contribution-content"];XCTAssertTrue(text.waitForExistence(timeout:10))
   if count==0 {text.press(forDuration:1.2)}else{text.tap(withNumberOfTaps:count,numberOfTouches:1)}
   expectCount(a,count==1 ? 1 : 0);a.terminate()
  }
 }
 func testDragAndContextMenuDoNotSend() {
  let a=launch();a.staticTexts["contribution-content"].swipeUp();expectCount(a,0)
  a.terminate();a.launch()
  let menu=a.descendants(matching:.any).matching(identifier:"menu-area").firstMatch
  XCTAssertTrue(menu.waitForExistence(timeout:10));menu.press(forDuration:1.2)
  let remove=a.buttons["Remove contribution"];XCTAssertTrue(remove.waitForExistence(timeout:5));remove.tap()
  XCTAssertEqual(a.staticTexts["controls"].label,"controls:1");expectCount(a,0)
 }
}
