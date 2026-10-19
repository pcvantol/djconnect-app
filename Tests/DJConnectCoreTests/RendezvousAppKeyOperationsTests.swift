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
