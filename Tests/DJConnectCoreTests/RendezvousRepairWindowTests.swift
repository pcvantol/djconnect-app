import XCTest
@testable import DJConnectCore

final class RendezvousRepairWindowTests: XCTestCase {
    private func restored(_ value: RendezvousRepairWindow) throws -> RendezvousRepairWindow {
        try JSONDecoder().decode(RendezvousRepairWindow.self, from: JSONEncoder().encode(value))
    }

    func testTwoExplicitAttemptsPreserveOriginalPauseAndSpacingAcrossRestarts() throws {
        var state = try RendezvousRepairWindow(keyIdentifier: "synthetic-handle", pausedAtMS: 1_000)
        XCTAssertThrowsError(try state.reserveExplicitRecovery(at: 60_999))
        let first = try state.reserveExplicitRecovery(at: 61_000)
        state = try restored(state)
        XCTAssertThrowsError(try state.reserveExplicitRecovery(at: 61_001))
        try state.complete(first, outcome: .paused, at: 61_100)
        state = try restored(state)
        XCTAssertThrowsError(try state.reserveExplicitRecovery(at: 120_999))
        let second = try state.reserveExplicitRecovery(at: 121_000)
        try state.complete(second, outcome: .paused, at: 121_100)
        state = try restored(state)
        XCTAssertThrowsError(try state.reserveExplicitRecovery(at: 200_000))
        XCTAssertEqual(state.attemptsStarted, 2)
        XCTAssertEqual(state.pausedAtMS, 1_000)
        XCTAssertEqual(state.windowEndsAtMS, 86_401_000)
        XCTAssertEqual(state.keyIdentifier, "synthetic-handle")
    }

    func testServerDelayPersistsAndCannotBeReduced() throws {
        var state = try RendezvousRepairWindow(keyIdentifier: "synthetic", pausedAtMS: 0)
        try state.delayRecovery(until: 200_000, at: 0)
        try state.delayRecovery(until: 1, at: 1)
        state = try restored(state)
        XCTAssertThrowsError(try state.reserveExplicitRecovery(at: 199_999))
        let id = try state.reserveExplicitRecovery(at: 200_000)
        try state.complete(id, outcome: .paused, at: 200_100)
        try state.delayRecovery(until: 900_000, at: 200_100)
        state = try restored(state)
        XCTAssertThrowsError(try state.reserveExplicitRecovery(at: 899_999))
        _ = try state.reserveExplicitRecovery(at: 900_000)
    }

    func testExpiryEqualityNeverCreatesNewBudgetOrReplacement() throws {
        var state = try RendezvousRepairWindow(keyIdentifier: "synthetic", pausedAtMS: 0)
        state = try restored(state)
        XCTAssertThrowsError(try state.reserveExplicitRecovery(at: 86_400_000))
        XCTAssertThrowsError(try state.reserveExplicitRecovery(at: 172_800_000))
        XCTAssertEqual(state.attemptsStarted, 0)
        XCTAssertEqual(state.windowEndsAtMS, 86_400_000)
    }

    func testRecoveredResultClosesWindowWithoutRenewingDates() throws {
        var state = try RendezvousRepairWindow(keyIdentifier: "synthetic", pausedAtMS: 0)
        let id = try state.reserveExplicitRecovery(at: 86_399_999)
        // The repair cooldown is not a remote challenge/key expiry.
        try state.complete(id, outcome: .recovered, at: 86_400_001)
        state = try restored(state)
        XCTAssertTrue(state.isResolved)
        XCTAssertNil(state.reservation)
        XCTAssertThrowsError(try state.reserveExplicitRecovery(at: 86_400_002))
        XCTAssertEqual(state.windowEndsAtMS, 86_400_000)
    }

    func testWrongAndDuplicateCompletionCannotReleaseReservation() throws {
        var state = try RendezvousRepairWindow(keyIdentifier: "synthetic", pausedAtMS: 0)
        let id = try state.reserveExplicitRecovery(at: 60_000)
        XCTAssertThrowsError(try state.complete(UUID(), outcome: .paused, at: 60_001))
        XCTAssertEqual(state.reservation, id)
        try state.complete(id, outcome: .paused, at: 60_002)
        XCTAssertThrowsError(try state.complete(id, outcome: .recovered, at: 60_003))
        XCTAssertFalse(state.isResolved)
    }

    func testLongFirstAttemptPreventsOverlapAndRequiresCompletion() throws {
        var state = try RendezvousRepairWindow(keyIdentifier: "synthetic", pausedAtMS: 0)
        let first = try state.reserveExplicitRecovery(at: 60_000)
        XCTAssertThrowsError(try state.reserveExplicitRecovery(at: 180_000))
        try state.complete(first, outcome: .paused, at: 180_001)
        _ = try state.reserveExplicitRecovery(at: 180_001)
        _ = try restored(state)
    }

    func testInvalidTimesIdentifiersAndOverflowFailClosed() throws {
        XCTAssertThrowsError(try RendezvousRepairWindow(keyIdentifier: "", pausedAtMS: 0))
        XCTAssertThrowsError(try RendezvousRepairWindow(keyIdentifier: "synthetic", pausedAtMS: -1))
        XCTAssertThrowsError(try RendezvousRepairWindow(keyIdentifier: "synthetic", pausedAtMS: .max))
        var state = try RendezvousRepairWindow(keyIdentifier: "synthetic", pausedAtMS: 1)
        XCTAssertThrowsError(try state.delayRecovery(until: -1, at: 1))
        XCTAssertThrowsError(try state.reserveExplicitRecovery(at: 0))
        let id = try state.reserveExplicitRecovery(at: 60_001)
        XCTAssertThrowsError(try state.complete(id, outcome: .paused, at: 60_000))
        XCTAssertEqual(state.reservation, id)
    }

    func testAllLegalPhasesRoundTripAtBoundaryTimes() throws {
        var state = try RendezvousRepairWindow(keyIdentifier: "synthetic", pausedAtMS: 3)
        _ = try restored(state)
        for time: Int64 in [60_003, 120_003] {
            let id = try state.reserveExplicitRecovery(at: time)
            state = try restored(state)
            try state.complete(id, outcome: .paused, at: time)
            state = try restored(state)
        }
    }

    func testMalformedPersistenceCannotRefillOverlapOrShortenBudget() throws {
        var state = try RendezvousRepairWindow(keyIdentifier: "synthetic", pausedAtMS: 0)
        let first = try state.reserveExplicitRecovery(at: 60_000)
        try state.complete(first, outcome: .paused, at: 60_001)
        _ = try state.reserveExplicitRecovery(at: 120_000)
        let original = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
        func rejects(_ change: (inout [String: Any]) -> Void) throws {
            var value = original
            change(&value)
            let data = try JSONSerialization.data(withJSONObject: value)
            XCTAssertThrowsError(try JSONDecoder().decode(RendezvousRepairWindow.self, from: data))
        }
        try rejects { $0["schemaVersion"] = 2 }
        try rejects { $0["keyIdentifier"] = "" }
        try rejects { $0["windowEndsAtMS"] = 86_400_001 }
        try rejects { $0["lastObservedMS"] = -1 }
        try rejects { $0["serverNotBeforeMS"] = -1 }
        for kind in 0..<7 {
            try rejects { value in
                var attempts = value["attempts"] as! [[String: Any]]
                switch kind {
                case 0: attempts.append(attempts[1])
                case 1: attempts[1]["id"] = attempts[0]["id"]
                case 2: attempts[1]["startedAtMS"] = 119_999
                case 3: attempts[0].removeValue(forKey: "completedAtMS")
                case 4: attempts[0]["completedAtMS"] = 120_001
                case 5: attempts[0]["outcome"] = "recovered"
                default: attempts[1]["startedAtMS"] = 86_400_000
                }
                value["attempts"] = attempts
            }
        }
    }
}
