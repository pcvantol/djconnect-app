import XCTest
@testable import DJConnectCore

final class RendezvousRepairJournalTests: XCTestCase {
    private final class Storage: RendezvousRepairStorage, @unchecked Sendable {
        enum Failure: Error { case unavailable }
        private let lock = NSLock()
        private var bytes: Data?
        private var readFailure = false
        private var writeFailure = false
        private var failureAfterCommit = false
        func configure(read: Bool = false, write: Bool = false, afterCommit: Bool = false) {
            lock.withLock { readFailure = read; writeFailure = write; failureAfterCommit = afterCommit }
        }
        func replace(_ value: Data) { lock.withLock { bytes = value } }
        func read() throws -> Data? {
            try lock.withLock { if readFailure { throw Failure.unavailable }; return bytes }
        }
        func write(_ value: Data) throws {
            try lock.withLock {
                if writeFailure { throw Failure.unavailable }
                bytes = value
                if failureAfterCommit { throw Failure.unavailable }
            }
        }
    }

    func testReconstructedJournalPreservesOriginalWindowAndReservation() async throws {
        let store = Storage(), key = "synthetic"
        let first = RendezvousRepairJournal(storage: store)
        _ = try await first.beginPause(keyIdentifier: key, at: 0)
        let id = try await first.reserveExplicitRecovery(keyIdentifier: key, at: 60_000)
        let restored = RendezvousRepairJournal(storage: store)
        let state = try await restored.beginPause(keyIdentifier: key, at: 100_000)
        XCTAssertEqual(state.reservation, id)
        XCTAssertEqual(state.pausedAtMS, 0)
        do { _ = try await restored.reserveExplicitRecovery(keyIdentifier: key, at: 120_000); XCTFail() } catch {}
        try await restored.complete(keyIdentifier: key, reservation: id, outcome: .paused, at: 120_001)
        _ = try await restored.reserveExplicitRecovery(keyIdentifier: key, at: 120_001)
        let last = try await restored.snapshot()
        XCTAssertEqual(last?.attemptsStarted, 2)
    }

    func testFailedWriteCannotReturnPermissionForExternalWork() async throws {
        let store = Storage()
        // Missing state never silently begins a new ledger.
        let subject = RendezvousRepairJournal(storage: store)
        do { _ = try await subject.reserveExplicitRecovery(keyIdentifier: "synthetic", at: 60_000); XCTFail() } catch {}
        _ = try await subject.beginPause(keyIdentifier: "synthetic", at: 0)
        store.configure(write: true)
        var externalCalls = 0
        do { _ = try await subject.reserveExplicitRecovery(keyIdentifier: "synthetic", at: 60_000); externalCalls += 1; XCTFail() } catch {}
        XCTAssertEqual(externalCalls, 0)
        store.configure()
        let state = try await subject.snapshot()
        XCTAssertEqual(state?.attemptsStarted, 0)
    }

    func testAmbiguousCommittedWriteRetainsReservationAndBlocksReplay() async throws {
        let store = Storage(), key = "synthetic"
        let journal = RendezvousRepairJournal(storage: store)
        _ = try await journal.beginPause(keyIdentifier: key, at: 0)
        store.configure(afterCommit: true)
        do { _ = try await journal.reserveExplicitRecovery(keyIdentifier: key, at: 60_000); XCTFail() } catch {}
        store.configure()
        let restored = RendezvousRepairJournal(storage: store)
        let state = try await restored.snapshot()
        XCTAssertNotNil(state?.reservation)
        XCTAssertEqual(state?.attemptsStarted, 1)
        do { _ = try await restored.reserveExplicitRecovery(keyIdentifier: key, at: 120_000); XCTFail() } catch {}
    }

    func testReadFailureAndCorruptionNeverCreateFreshState() async throws {
        let store = Storage()
        let subject = RendezvousRepairJournal(storage: store)
        _ = try await subject.beginPause(keyIdentifier: "synthetic", at: 0)
        store.configure(read: true)
        do { _ = try await subject.beginPause(keyIdentifier: "synthetic", at: 100_000); XCTFail() } catch {}
        store.configure()
        for bytes in [Data(), Data("bad json".utf8), Data(repeating: 1, count: 16_385)] {
            store.replace(bytes)
            do { _ = try await subject.beginPause(keyIdentifier: "synthetic", at: 100_000); XCTFail() } catch {}
        }
    }

    func testWrongKeyAndRepeatedPauseCannotReplaceOrReplenishState() async throws {
        let store = Storage()
        let subject = RendezvousRepairJournal(storage: store)
        _ = try await subject.beginPause(keyIdentifier: "first", at: 0)
        for start: Int64 in [60_000, 120_000] {
            let id = try await subject.reserveExplicitRecovery(keyIdentifier: "first", at: start)
            try await subject.complete(keyIdentifier: "first", reservation: id, outcome: .paused, at: start)
        }
        let repeated = try await subject.beginPause(keyIdentifier: "first", at: 86_400_000)
        XCTAssertEqual(repeated.attemptsStarted, 2)
        XCTAssertEqual(repeated.pausedAtMS, 0)
        do { _ = try await subject.beginPause(keyIdentifier: "other", at: 86_400_000); XCTFail() } catch {}
        do { try await subject.delayRecovery(keyIdentifier: "other", until: 90_000_000, at: 86_400_000); XCTFail() } catch {}
    }

    func testCompletionWriteFailureLeavesOriginalInFlightState() async throws {
        let store = Storage()
        let journal = RendezvousRepairJournal(storage: store)
        _ = try await journal.beginPause(keyIdentifier: "synthetic", at: 0)
        let id = try await journal.reserveExplicitRecovery(keyIdentifier: "synthetic", at: 60_000)
        store.configure(write: true)
        do { try await journal.complete(keyIdentifier: "synthetic", reservation: id, outcome: .recovered, at: 60_001); XCTFail() } catch {}
        store.configure()
        let saved = try await journal.snapshot()
        XCTAssertEqual(saved?.reservation, id)
        XCTAssertFalse(saved!.isResolved)
    }

    func testConcurrentReservationsHaveOnePersistedWinner() async throws {
        let store = Storage()
        let subject = RendezvousRepairJournal(storage: store)
        _ = try await subject.beginPause(keyIdentifier: "synthetic", at: 0)
        let winners = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    do { _ = try await subject.reserveExplicitRecovery(keyIdentifier: "synthetic", at: 60_000); return true }
                    catch { return false }
                }
            }
            var count = 0
            for await won in group { if won { count += 1 } }
            return count
        }
        XCTAssertEqual(winners, 1)
        let state = try await subject.snapshot()
        XCTAssertEqual(state?.attemptsStarted, 1)
    }

    func testInitialWriteFailureAndOversizeDoNotCreateState() async throws {
        let store = Storage(), key = "synthetic"
        let journal = RendezvousRepairJournal(storage: store)
        store.configure(write: true)
        do { _ = try await journal.beginPause(keyIdentifier: key, at: 0); XCTFail() } catch {}
        store.configure()
        let absent = try await journal.snapshot()
        XCTAssertNil(absent)
        do { _ = try await journal.beginPause(keyIdentifier: String(repeating: "x", count: 20_000), at: 0); XCTFail() } catch {}
        let stillAbsent = try await journal.snapshot()
        XCTAssertNil(stillAbsent)
    }

    func testServerDelaySurvivesJournalReconstruction() async throws {
        let store = Storage(), key = "synthetic"
        let first = RendezvousRepairJournal(storage: store)
        _ = try await first.beginPause(keyIdentifier: key, at: 0)
        try await first.delayRecovery(keyIdentifier: key, until: 200_000, at: 0)
        let restored = RendezvousRepairJournal(storage: store)
        _ = try await restored.beginPause(keyIdentifier: key, at: 100_000)
        do { _ = try await restored.reserveExplicitRecovery(keyIdentifier: key, at: 199_999); XCTFail() } catch {}
        _ = try await restored.reserveExplicitRecovery(keyIdentifier: key, at: 200_000)
    }

    func testWrongKeyCannotReserveOrCompleteAnotherKey() async throws {
        let store = Storage(), key = "synthetic"
        let journal = RendezvousRepairJournal(storage: store)
        _ = try await journal.beginPause(keyIdentifier: key, at: 0)
        do { _ = try await journal.reserveExplicitRecovery(keyIdentifier: "other", at: 60_000); XCTFail() } catch {}
        let id = try await journal.reserveExplicitRecovery(keyIdentifier: key, at: 60_000)
        do { try await journal.complete(keyIdentifier: "other", reservation: id, outcome: .recovered, at: 60_001); XCTFail() } catch {}
        let saved = try await journal.snapshot()
        XCTAssertEqual(saved?.reservation, id)
        XCTAssertEqual(saved?.attemptsStarted, 1)
        XCTAssertFalse(saved!.isResolved)
    }
}
