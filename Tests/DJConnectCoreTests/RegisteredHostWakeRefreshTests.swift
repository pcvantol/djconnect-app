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
        let (events, entered) = AsyncStream<Void>.makeStream()
        let (release, heldReads) = AsyncStream<Void>.makeStream()
        defer { entered.finish(); heldReads.finish() }
        let read: @MainActor @Sendable () async -> Bool = {
            state.entered += 1
            entered.yield(())
            for await _ in release { }
            return !Task.isCancelled
        }
        // Both original reads must enter before either is released. The
        // worker's unchanged budget cancels a stuck/serial scheduling regression
        // and finishes the event stream, so missing events cannot hang the test.
        let first = Task {
            let count = await worker.run([read, read])
            entered.finish()
            return count
        }
        var arrivals = events.makeAsyncIterator()
        #expect(await arrivals.next() != nil)
        #expect(await arrivals.next() != nil)
        #expect(state.entered == 2)
        let second = Task {
            state.joinEntered = true
            entered.yield(())
            return await worker.run([{ state.extra += 1; return true }])
        }
        #expect(await arrivals.next() != nil)
        #expect(state.joinEntered)
        heldReads.finish()
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
