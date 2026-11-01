import Foundation
import Testing
@testable import DJConnectUI

/// Scheduling and payload classification only; no admitted native/read owner.
@Suite @MainActor struct RegisteredHostWakeRefreshTests {
    @Test func acceptsOnlyTheContentFreeBodyWithoutSelectingAnOwner() {
        #expect(RegisteredHostWakeRefreshOwner.isContentFreeHint(["aps": ["content-available": 1]]))
        let invalid: [[AnyHashable: Any]] = [[:], ["aps": ["content-available": true]],
            ["aps": ["content-available": 0]], ["aps": ["content-available": "1"]],
            ["aps": ["content-available": 1, "alert": "text"]],
            ["aps": ["content-available": 1], "event": "direct_rich_refresh"],
            ["aps": ["content-available": 1], "purpose_id": "forged-owner"]]
        for body in invalid { #expect(!RegisteredHostWakeRefreshOwner.isContentFreeHint(body)) }
    }
    @Test func callbacksCoalesceAndTwoOriginalReadsCanRunInParallel() async throws {
        let worker = RegisteredHostWakeRefreshOwner(budget: .seconds(3)), state = State()
        let read: @MainActor @Sendable () async -> Bool = {
            state.entered += 1
            do { try await Task.sleep(for: .seconds(2)); return true } catch { return false }
        }
        // Wait for both starts to prove this is not serial scheduling. The
        // bounded wait prevents a scheduling regression from hanging the suite.
        let first = Task { await worker.run([read, read]) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        while state.entered < 2 && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
        #expect(state.entered == 2)
        let second = Task {
            state.joinEntered = true
            return await worker.run([{ state.extra += 1; return true }])
        }
        while !state.joinEntered && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
        #expect(state.joinEntered)
        #expect(await first.value == 2)
        #expect(await second.value == 2)
        #expect(state.entered == 2 && state.extra == 0)
    }
    @Test func resourceDeadlineCancelsReadsAndCannotReportLateSuccess() async {
        let worker = RegisteredHostWakeRefreshOwner(budget: .milliseconds(30)), state = State()
        let count = await worker.run([{
            state.entered += 1
            do { try await Task.sleep(for: .seconds(2)) } catch { state.cancelled = true }
            return true // Deliberate late result must still be rejected.
        }])
        #expect(count == 0)
        #expect(state.entered <= 1)
        // Under load the original deadline can expire before the child starts.
        // That must do no IO; a child which did start must see cancellation.
        #expect(state.entered == 0 || state.cancelled)
    }
    @Test func deadlineAlreadyPassedBeforeSchedulingDoesNoIO() async {
        let worker = RegisteredHostWakeRefreshOwner(budget: .zero), state = State()
        #expect(await worker.run([{ state.entered += 1; return true }]) == 0)
        #expect(state.entered == 0)
    }
    @Test func absentOwnersAndAnUnboundedSetCannotStartReads() async {
        let worker = RegisteredHostWakeRefreshOwner(), state = State()
        let read: @MainActor @Sendable () async -> Bool = { state.entered += 1; return true }
        #expect(await worker.run([]) == 0)
        #expect(await worker.run([read, read, read]) == 0)
        #expect(state.entered == 0)
    }
    @MainActor private final class State {
        var entered = 0, extra = 0
        var joinEntered = false, cancelled = false
    }
}
