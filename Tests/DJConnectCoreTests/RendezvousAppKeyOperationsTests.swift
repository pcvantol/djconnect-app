import XCTest
@testable import DJConnectCore

private actor OperationProbe {
    var events: [String] = []
    private var continuation: CheckedContinuation<Void, Never>?
    private var entered: CheckedContinuation<Void, Never>?
    private var isEntered = false

    func hold() async {
        events.append("sign-1")
        isEntered = true
        entered?.resume()
        entered = nil
        await withCheckedContinuation { continuation = $0 }
        events.append("submit-1-finished")
    }
    func waitUntilEntered() async {
        if !isEntered { await withCheckedContinuation { entered = $0 } }
    }
    func finish() { continuation?.resume(); continuation = nil }
    func record(_ event: String) { events.append(event) }
}

final class RendezvousAppKeyOperationsTests: XCTestCase, @unchecked Sendable {
    private func waitForQueue(_ queue: RendezvousAppKeyOperations, count: Int) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while await queue.waitingOperationCount(for: "key") != count {
            guard ContinuousClock.now < deadline else {
                XCTFail("Operation did not reach queue barrier")
                throw CancellationError()
            }
            await Task.yield()
        }
    }

    func testTwoScreensAndManagementActionWaitForEntireSubmissionInFIFOOrder() async throws {
        let queue = RendezvousAppKeyOperations(), probe = OperationProbe()
        let first = Task { try await queue.perform(keyIdentifier: "key") { await probe.hold() } }
        await probe.waitUntilEntered()
        let second = Task { try await queue.perform(keyIdentifier: "key") { await probe.record("sign-submit-2") } }
        try await waitForQueue(queue, count: 1)
        let deletion = Task { try await queue.perform(keyIdentifier: "key") { await probe.record("delete-key") } }
        try await waitForQueue(queue, count: 2)
        await probe.finish()
        try await first.value; try await second.value; try await deletion.value
        let events = await probe.events
        XCTAssertEqual(events, ["sign-1", "submit-1-finished", "sign-submit-2", "delete-key"])
    }

    func testCancelledWaiterNeverSignsAndDoesNotBlockFollowingAction() async throws {
        let queue = RendezvousAppKeyOperations(), probe = OperationProbe()
        let first = Task { try await queue.perform(keyIdentifier: "key") { await probe.hold() } }
        await probe.waitUntilEntered()
        let cancelled = Task { try await queue.perform(keyIdentifier: "key") { await probe.record("must-not-sign") } }
        try await waitForQueue(queue, count: 1)
        cancelled.cancel()
        do { try await cancelled.value; XCTFail("Cancelled waiter ran") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        let next = Task { try await queue.perform(keyIdentifier: "key") { await probe.record("next") } }
        try await waitForQueue(queue, count: 1)
        await probe.finish()
        try await first.value; try await next.value
        let events = await probe.events
        XCTAssertEqual(events, ["sign-1", "submit-1-finished", "next"])
    }

    func testCancellingOwnerKeepsSlotUntilUncooperativeSubmissionFinishes() async throws {
        let queue = RendezvousAppKeyOperations(), probe = OperationProbe()
        let first = Task { try await queue.perform(keyIdentifier: "key") { await probe.hold() } }
        await probe.waitUntilEntered()
        let next = Task { try await queue.perform(keyIdentifier: "key") { await probe.record("next") } }
        try await waitForQueue(queue, count: 1)
        first.cancel()
        let eventsWhileCancelled = await probe.events
        XCTAssertEqual(eventsWhileCancelled, ["sign-1"])
        await probe.finish()
        try await first.value; try await next.value
        let events = await probe.events
        XCTAssertEqual(events, ["sign-1", "submit-1-finished", "next"])
    }

    func testIndependentKeyProgressesAndFailureReleasesOnlyItsOwnSlot() async throws {
        enum Expected: Error { case failure }
        let queue = RendezvousAppKeyOperations(), probe = OperationProbe()
        let first = Task { try await queue.perform(keyIdentifier: "key") { await probe.hold() } }
        await probe.waitUntilEntered()
        do { try await queue.perform(keyIdentifier: "other") { throw Expected.failure } }
        catch Expected.failure {} catch { XCTFail("Unexpected error: \(error)") }
        let value = try await queue.perform(keyIdentifier: "other") { 42 }
        XCTAssertEqual(value, 42)
        await probe.finish(); try await first.value
        let reused = try await queue.perform(keyIdentifier: "key") { 7 }
        XCTAssertEqual(reused, 7)
    }

    func testAlreadyCancelledAndEmptyKeyNeverInvokeOperation() async throws {
        let queue = RendezvousAppKeyOperations(), probe = OperationProbe()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await queue.perform(keyIdentifier: "key") { await probe.record("must-not-sign") }
        }
        do { try await task.value; XCTFail("Cancelled operation ran") } catch is CancellationError {}
        do {
            try await queue.perform(keyIdentifier: "") { await probe.record("must-not-sign") }
            XCTFail("Empty key admitted")
        } catch RendezvousAppKeyOperations.Failure.emptyKeyIdentifier {}
        let events = await probe.events
        XCTAssertEqual(events, [])
    }
}

private final class TransitionSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    var isSignalled: Bool { lock.withLock { fired } }
    func signal() {
        let ready = lock.withLock {
            fired = true; let result = waiters; waiters = []; return result
        }
        ready.forEach { $0.resume() }
    }
    func wait() async {
        await withCheckedContinuation { continuation in
            let immediate = lock.withLock {
                if fired { return true }; waiters.append(continuation); return false
            }
            if immediate { continuation.resume() }
        }
    }
}

extension RendezvousAppKeyOperationsTests {
    private func awaitSignal(_ signal: TransitionSignal) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !signal.isSignalled {
            guard ContinuousClock.now < deadline else { XCTFail("Transition barrier was not reached"); throw CancellationError() }
            await Task.yield()
        }
    }
    private func awaitWaiters(_ queue: RendezvousAppKeyOperations, key: String, count: Int) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while await queue.waitingOperationCount(for: key) != count {
            guard ContinuousClock.now < deadline else { XCTFail("Expected queue barrier missing"); throw CancellationError() }
            await Task.yield()
        }
    }

    func testInstallationTransitionRefusesBusyKeyWithoutKeyGlobalDeadlock() async throws {
        let keyEntered = TransitionSignal(), installationOwned = TransitionSignal()
        let oldFinished = TransitionSignal(), transitionFinished = TransitionSignal(), probe = OperationProbe()
        let queue = RendezvousAppKeyOperations(onInstallationTransitionAcquired: { installationOwned.signal() })
        let old = Task {
            defer { oldFinished.signal() }
            try await queue.perform(keyIdentifier: "old-key") {
                keyEntered.signal()
                // The transition must own installation before this key owner asks for it.
                await installationOwned.wait()
                try await queue.perform(keyIdentifier: RendezvousAppKeyOperations.installationAdmissionSlot) {
                    await probe.record("old-finished")
                }
            }
        }
        try await awaitSignal(keyEntered)
        let transition = Task {
            defer { transitionFinished.signal() }
            do {
                try await queue.performInstallationTransition(affectedKeys: ["old-key"]) { await probe.record("forbidden-write") }
                XCTFail("Busy key admitted")
            } catch RendezvousAppKeyOperations.Failure.installationTransitionKeyBusy {}
        }
        defer { old.cancel(); transition.cancel(); installationOwned.signal() }
        try await awaitSignal(installationOwned)
        try await awaitSignal(transitionFinished); try await awaitSignal(oldFinished)
        try await transition.value; try await old.value
        let events = await probe.events
        XCTAssertEqual(events, ["old-finished"])
    }

    func testEarlierGlobalWaiterCompletesWhileLaterTransitionRefusesStillOwnedKey() async throws {
        let queue = RendezvousAppKeyOperations(), installation = OperationProbe(), keyEntered = TransitionSignal(), probe = OperationProbe()
        let globalReturned = TransitionSignal(), releaseOld = TransitionSignal()
        let holder = Task { try await queue.perform(keyIdentifier: RendezvousAppKeyOperations.installationAdmissionSlot) { await installation.hold() } }
        await installation.waitUntilEntered()
        let old = Task { try await queue.perform(keyIdentifier: "old") {
            keyEntered.signal()
            try await queue.perform(keyIdentifier: RendezvousAppKeyOperations.installationAdmissionSlot) { await probe.record("old") }
            // Returning the inner global slot does not release the outer key.
            globalReturned.signal(); await releaseOld.wait()
        } }
        defer { releaseOld.signal(); holder.cancel(); old.cancel() }
        try await awaitSignal(keyEntered)
        try await awaitWaiters(queue, key: RendezvousAppKeyOperations.installationAdmissionSlot, count: 1)
        let transition = Task { try await queue.performInstallationTransition(affectedKeys: ["old"]) { XCTFail("A still-owned key entered the transition") } }
        try await awaitWaiters(queue, key: RendezvousAppKeyOperations.installationAdmissionSlot, count: 2)
        await installation.finish(); try await holder.value
        try await awaitSignal(globalReturned)
        do { try await transition.value; XCTFail("Busy key was admitted") }
        catch RendezvousAppKeyOperations.Failure.installationTransitionKeyBusy {}
        // A separate explicit local attempt succeeds only after the old key ends.
        releaseOld.signal(); try await old.value
        try await queue.performInstallationTransition(affectedKeys: ["old"]) { await probe.record("transition") }
        let events = await probe.events; XCTAssertEqual(events, ["old", "transition"])
    }

    func testTwoKeyTransitionDoesNotPartiallyReserveAndCanBorrowOnlyOwnedSlots() async throws {
        let queue = RendezvousAppKeyOperations(), held = OperationProbe()
        let owner = Task { try await queue.perform(keyIdentifier: "b") { await held.hold() } }
        await held.waitUntilEntered()
        do {
            try await queue.performInstallationTransition(affectedKeys: ["a", "b"]) { XCTFail("Partial transition executed") }
            XCTFail("Busy second key admitted")
        } catch RendezvousAppKeyOperations.Failure.installationTransitionKeyBusy {}
        let free = try await queue.perform(keyIdentifier: "a") { 42 }; XCTAssertEqual(free, 42)
        await held.finish(); try await owner.value
        let value = try await queue.performInstallationTransition(affectedKeys: ["b", "a"]) {
            let a = try await queue.perform(keyIdentifier: "a") { 1 }
            let b = try await queue.perform(keyIdentifier: "b") { 2 }
            do { _ = try await queue.perform(keyIdentifier: "unowned") { 99 }; XCTFail("Wrong key borrowed") }
            catch RendezvousAppKeyOperations.Failure.invalidInstallationTransition {}
            return a + b
        }
        XCTAssertEqual(value, 3)
    }

    func testCancelledInstallationTransitionNeverRunsItsBodyOrConsumesKeySlot() async throws {
        let queue = RendezvousAppKeyOperations(), held = OperationProbe()
        let owner = Task { try await queue.perform(keyIdentifier: RendezvousAppKeyOperations.installationAdmissionSlot) { await held.hold() } }
        await held.waitUntilEntered()
        let cancelled = Task { try await queue.performInstallationTransition(affectedKeys: ["a"]) { XCTFail("Cancelled transition ran") } }
        try await awaitWaiters(queue, key: RendezvousAppKeyOperations.installationAdmissionSlot, count: 1)
        cancelled.cancel()
        do { try await cancelled.value; XCTFail("Cancellation ignored") } catch is CancellationError {}
        await held.finish(); try await owner.value
        let value = try await queue.performInstallationTransition(affectedKeys: ["a"]) { 42 }; XCTAssertEqual(value, 42)
    }

    func testTransitionLeaseRefusesConcurrentBorrowAndInheritedTaskAfterClose() async throws {
        let queue = RendezvousAppKeyOperations(), entered = TransitionSignal(), release = TransitionSignal()
        let result = try await queue.performInstallationTransition(affectedKeys: ["a", "b"]) {
            let first = Task { try await queue.perform(keyIdentifier: "a") { entered.signal(); await release.wait(); return 1 } }
            await entered.wait()
            do { _ = try await queue.perform(keyIdentifier: "b") { 2 }; XCTFail("Concurrent descendant borrowed") }
            catch RendezvousAppKeyOperations.Failure.invalidInstallationTransition {}
            release.signal(); return try await first.value
        }
        XCTAssertEqual(result, 1)
        let go = TransitionSignal()
        let late = try await queue.performInstallationTransition(affectedKeys: ["a"]) {
            Task { await go.wait(); return try await queue.perform(keyIdentifier: "a") { 99 } }
        }
        go.signal()
        do { _ = try await late.value; XCTFail("Closed inherited lease revived") }
        catch RendezvousAppKeyOperations.Failure.invalidInstallationTransition {}
    }

    func testUnstructuredBorrowCannotReleaseLogicalExclusionBeforeItDrains() async throws {
        let queue = RendezvousAppKeyOperations(), entered = TransitionSignal(), release = TransitionSignal(), bodyReturned = TransitionSignal(), finished = TransitionSignal()
        let transition = Task {
            defer { finished.signal() }
            do {
                try await queue.performInstallationTransition(affectedKeys: ["a"]) {
                    Task { try? await queue.perform(keyIdentifier: "a") { entered.signal(); await release.wait() } }
                    await entered.wait(); bodyReturned.signal()
                }
                // The borrower may finish after release but before the outer
                // operation resumes its final quiescence check. Either a clean
                // return or the typed rejection is valid then. The assertions
                // below prove the required invariant while the borrower is
                // still held: no terminal result and no successor acquisition.
            } catch RendezvousAppKeyOperations.Failure.invalidInstallationTransition {}
        }
        defer { release.signal(); transition.cancel() }
        try await awaitSignal(bodyReturned)
        let next = Task { try await queue.perform(keyIdentifier: "a") { 42 } }
        try await awaitWaiters(queue, key: "a", count: 1)
        XCTAssertFalse(finished.isSignalled)
        release.signal()
        try await transition.value
        let value = try await next.value; XCTAssertEqual(value, 42)
    }

    func testTransitionRejectsNestedAdmissionDuplicateKeysAndReservedGlobalKey() async throws {
        let queue = RendezvousAppKeyOperations()
        for invalid in [["a", "a"], [""], [RendezvousAppKeyOperations.installationAdmissionSlot], ["a", "b", "c"]] {
            do { try await queue.performInstallationTransition(affectedKeys: invalid) { XCTFail("Invalid set ran") }; XCTFail("Invalid transition admitted") }
            catch RendezvousAppKeyOperations.Failure.invalidInstallationTransition {}
        }
        try await queue.performInstallationTransition(affectedKeys: ["a"]) {
            do { try await queue.performInstallationTransition(affectedKeys: []) { XCTFail("Nested transition ran") }; XCTFail("Nested transition admitted") }
            catch RendezvousAppKeyOperations.Failure.invalidInstallationTransition {}
        }
    }
}

extension RendezvousAppKeyOperationsTests {
    func testInstallationLeaseCannotBorrowThroughAnotherQueueInstance() async throws {
        let ownerQueue = RendezvousAppKeyOperations(), otherQueue = RendezvousAppKeyOperations()
        let held = OperationProbe()
        let originalOwner = Task { try await otherQueue.perform(keyIdentifier: "same-name") { await held.hold() } }
        await held.waitUntilEntered()
        try await ownerQueue.performInstallationTransition(affectedKeys: ["same-name"]) {
            do {
                _ = try await otherQueue.perform(keyIdentifier: "same-name") { 42 }
                XCTFail("A lease from another queue bypassed this queue's owner")
            } catch RendezvousAppKeyOperations.Failure.invalidInstallationTransition {}
        }
        let waiting = await otherQueue.waitingOperationCount(for: "same-name")
        XCTAssertEqual(waiting, 0)
        let events = await held.events; XCTAssertEqual(events, ["sign-1"])
        await held.finish(); try await originalOwner.value
        let value = try await otherQueue.perform(keyIdentifier: "same-name") { 7 }
        XCTAssertEqual(value, 7)
    }
}
