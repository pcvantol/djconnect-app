import Foundation
import Testing
@testable import DJConnectUI

@Test func autoplayBaselineAndHistoryAreSilentButLiveNewContributionPlaysOnce() {
    var state = SessionSpeechAutoplayAdmission()
    #expect(state.observe(sessionID: "session", momentIDs: ["old"], readyIDs: ["old"], enabled: true).isEmpty)
    #expect(state.observe(sessionID: "session", momentIDs: ["old", "new"], readyIDs: ["old", "new"], enabled: true) == ["new"])
    #expect(state.observe(sessionID: "session", momentIDs: ["old", "new"], readyIDs: ["old", "new"], enabled: true).isEmpty)
}
@Test func autoplayWaitsForPrivatePublicationGrantAndPreservesOrder() {
    var state = SessionSpeechAutoplayAdmission()
    _ = state.observe(sessionID: "session", momentIDs: [], readyIDs: [], enabled: true)
    #expect(state.observe(sessionID: "session", momentIDs: ["one", "two"], readyIDs: [], enabled: true).isEmpty)
    #expect(state.observe(sessionID: "session", momentIDs: ["one", "two"], readyIDs: ["one", "two"], enabled: true) == ["one", "two"])
}
@Test func autoplayEnableDoesNotSpeakBacklogAndResumeDoesNotReplay() {
    var state = SessionSpeechAutoplayAdmission()
    _ = state.observe(sessionID: "session", momentIDs: [], readyIDs: [], enabled: false)
    #expect(state.observe(sessionID: "session", momentIDs: ["off"], readyIDs: ["off"], enabled: false).isEmpty)
    #expect(state.observe(sessionID: "session", momentIDs: ["off"], readyIDs: ["off"], enabled: true).isEmpty)
    #expect(state.observe(sessionID: "session", momentIDs: ["off", "on"], readyIDs: ["on"], enabled: true) == ["on"])
    state.reset()
    #expect(state.observe(sessionID: "session", momentIDs: ["off", "on", "background"], readyIDs: ["background"], enabled: true).isEmpty)
}
@Test func autoplayExpiresPendingContributionsAndNewOwnerStartsSilently() {
    var state = SessionSpeechAutoplayAdmission()
    let now = Date()
    _ = state.observe(sessionID: "one", momentIDs: [], readyIDs: [], enabled: true, now: now)
    _ = state.observe(sessionID: "one", momentIDs: ["stale"], readyIDs: [], enabled: true, now: now)
    #expect(state.observe(sessionID: "one", momentIDs: ["stale"], readyIDs: ["stale"], enabled: true, now: now.addingTimeInterval(121)).isEmpty)
    #expect(state.observe(sessionID: "two", momentIDs: ["stale"], readyIDs: ["stale"], enabled: true).isEmpty)
}
