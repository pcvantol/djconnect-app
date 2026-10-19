import XCTest
@testable import DJConnectCore

final class RendezvousRetryWindowTests: XCTestCase {
    func testSDKUnavailableRetriesTwiceWithOriginalDeadlineAndTwoThenFiveSecondBackoff() throws {
        var window = try RendezvousRetryWindow(kind: .appleAttestation, startedAtMS: 1_000, deadlineMS: 121_000)
        let first = try window.reserve(at: 1_000)
        XCTAssertThrowsError(try window.reserve(at: 1_001))
        try window.complete(first, outcome: .appleServerUnavailable, at: 1_100)
        XCTAssertThrowsError(try window.reserve(at: 3_099))
        let second = try window.reserve(at: 3_100)
        try window.complete(second, outcome: .appleServerUnavailable, at: 3_200)
        XCTAssertThrowsError(try window.reserve(at: 8_199))
        let third = try window.reserve(at: 8_200)
        try window.complete(third, outcome: .appleServerUnavailable, at: 8_300)
        XCTAssertThrowsError(try window.reserve(at: 120_000))
        XCTAssertEqual(window.callsStarted, 3)
        XCTAssertEqual(window.deadlineMS, 121_000)
    }

    func testRegistrationAndRecoveryResponseLossRetriesAreBounded() throws {
        for kind: RendezvousRetryWindow.Kind in [.registration, .recovery] {
            var window = try RendezvousRetryWindow(kind: kind, startedAtMS: 0, deadlineMS: 120_000)
            let first = try window.reserve(at: 0)
            try window.complete(first, outcome: .responseLost, at: 100)
            let second = try window.reserve(at: 2_100)
            try window.complete(second, outcome: .responseLost, at: 2_200)
            let third = try window.reserve(at: 7_200)
            try window.complete(third, outcome: .responseLost, at: 7_300)
            XCTAssertThrowsError(try window.reserve(at: 10_000))
        }
    }

    func testWrongFailureKindAndSuccessAreTerminal() throws {
        for kind: RendezvousRetryWindow.Kind in [.appleAttestation, .registration, .recovery] {
            for outcome: RendezvousRetryWindow.Outcome in [.terminalFailure, .succeeded] {
                var window = try RendezvousRetryWindow(kind: kind, startedAtMS: 0, deadlineMS: 120_000)
                let first = try window.reserve(at: 0)
                try window.complete(first, outcome: outcome, at: 1)
                XCTAssertThrowsError(try window.reserve(at: 10_000))
            }
            var window = try RendezvousRetryWindow(kind: kind, startedAtMS: 0, deadlineMS: 120_000)
            let first = try window.reserve(at: 0)
            try window.complete(first, outcome: kind == .appleAttestation ? .responseLost : .appleServerUnavailable, at: 1)
            XCTAssertTrue(window.isClosed)
        }
    }

    func testServerDelayNeverBringsRetryForwardAndDeadlineEqualityRejectsLateResult() throws {
        var window = try RendezvousRetryWindow(kind: .recovery, startedAtMS: 0, deadlineMS: 120_000)
        let first = try window.reserve(at: 0)
        try window.complete(first, outcome: .responseLost, at: 100, retryNotBeforeMS: 9_000)
        XCTAssertThrowsError(try window.reserve(at: 8_999))
        let second = try window.reserve(at: 9_000)
        XCTAssertThrowsError(try window.complete(second, outcome: .succeeded, at: 120_000))
        XCTAssertTrue(window.isClosed)
        XCTAssertThrowsError(try window.reserve(at: 120_000))
    }

    func testEncodedInFlightAndBackoffSurviveRestartWithoutReplenishingBudget() throws {
        var window = try RendezvousRetryWindow(kind: .registration, startedAtMS: 0, deadlineMS: 120_000)
        let first = try window.reserve(at: 0)
        window = try JSONDecoder().decode(RendezvousRetryWindow.self, from: JSONEncoder().encode(window))
        XCTAssertThrowsError(try window.reserve(at: 1))
        try window.complete(first, outcome: .responseLost, at: 100)
        window = try JSONDecoder().decode(RendezvousRetryWindow.self, from: JSONEncoder().encode(window))
        XCTAssertEqual(window.callsStarted, 1)
        XCTAssertThrowsError(try window.reserve(at: 2_099))
        _ = try window.reserve(at: 2_100)
        XCTAssertEqual(window.callsStarted, 2)
    }

    func testLateOrDuplicateCompletionCannotReleaseDifferentReservation() throws {
        var window = try RendezvousRetryWindow(kind: .registration, startedAtMS: 0, deadlineMS: 120_000)
        let first = try window.reserve(at: 0)
        XCTAssertThrowsError(try window.complete(UUID(), outcome: .responseLost, at: 1))
        try window.complete(first, outcome: .responseLost, at: 100)
        let second = try window.reserve(at: 2_100)
        XCTAssertThrowsError(try window.complete(first, outcome: .succeeded, at: 2_101))
        XCTAssertEqual(window.reservation, second)
    }

    func testRollbackAndMalformedStoredBudgetFailClosed() throws {
        var window = try RendezvousRetryWindow(kind: .registration, startedAtMS: 1_000, deadlineMS: 121_000)
        let first = try window.reserve(at: 1_001)
        XCTAssertThrowsError(try window.complete(first, outcome: .responseLost, at: 1_000))
        XCTAssertEqual(window.reservation, first)
        var data = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(window)) as? [String: Any])
        data["callsStarted"] = -1
        XCTAssertThrowsError(try JSONDecoder().decode(RendezvousRetryWindow.self, from: JSONSerialization.data(withJSONObject: data)))
        data["callsStarted"] = 1
        data["schemaVersion"] = 2
        XCTAssertThrowsError(try JSONDecoder().decode(RendezvousRetryWindow.self, from: JSONSerialization.data(withJSONObject: data)))
        XCTAssertThrowsError(try RendezvousRetryWindow(kind: .recovery, startedAtMS: -1, deadlineMS: 100))
        XCTAssertThrowsError(try RendezvousRetryWindow(kind: .recovery, startedAtMS: 0, deadlineMS: 120_001))
    }
}
