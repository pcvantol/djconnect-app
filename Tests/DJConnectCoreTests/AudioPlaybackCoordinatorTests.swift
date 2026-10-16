import Foundation
import Testing
@testable import DJConnectCore

@MainActor
struct AudioPlaybackCoordinatorTests {
    @Test func stopRejectsLatePreparationAndRepeatedStop() throws {
        var stops = 0
        let coordinator = DJConnectAudioPlaybackCoordinator { stops += 1 }
        let ticket = try #require(coordinator.begin())
        coordinator.stop()
        coordinator.stop()
        #expect(!coordinator.isCurrent(ticket))
        #expect(stops == 3)
    }

    @Test func replacementCompletionCannotStopNewOutput() throws {
        var stops = 0
        let coordinator = DJConnectAudioPlaybackCoordinator { stops += 1 }
        let old = try #require(coordinator.begin())
        let new = try #require(coordinator.begin())
        coordinator.finish(old)
        #expect(stops == 2)
        #expect(!coordinator.isCurrent(old))
        #expect(coordinator.isCurrent(new))
        coordinator.finish(new)
        #expect(!coordinator.isCurrent(new))
        #expect(stops == 3)
    }

    @Test func originalDeadlineCannotBeExtendedByLateLoad() throws {
        var now = Date(timeIntervalSince1970: 100)
        var stops = 0
        let coordinator = DJConnectAudioPlaybackCoordinator(now: { now }, stopOutput: { stops += 1 })
        let ticket = try #require(coordinator.begin(deadline: now.addingTimeInterval(20)))
        now = now.addingTimeInterval(20)
        #expect(!coordinator.isCurrent(ticket))
        #expect(stops == 2)
        #expect(coordinator.begin(deadline: now) == nil)
        #expect(coordinator.begin(deadline: now.addingTimeInterval(301)) == nil)
    }

    @Test func stopAcrossSuspensionBlocksLateOutput() async throws {
        let coordinator = DJConnectAudioPlaybackCoordinator(stopOutput: {})
        let ticket = try #require(coordinator.begin())
        var resume: CheckedContinuation<Void, Never>?
        var played = false
        let loading = Task { @MainActor in
            await withCheckedContinuation { resume = $0 }
            guard coordinator.isCurrent(ticket) else { return }
            played = true
        }
        while resume == nil { await Task.yield() }
        coordinator.stop()
        resume?.resume()
        await loading.value
        #expect(!played)
    }

    @Test func stopBeforeQueuedTaskStartsSuppressesOutput() async throws {
        let coordinator = DJConnectAudioPlaybackCoordinator(stopOutput: {})
        let ticket = try #require(coordinator.begin())
        var played = false
        let queued = Task { @MainActor in
            guard coordinator.isCurrent(ticket) else { return }
            played = true
        }
        coordinator.stop()
        await queued.value
        #expect(!played)
    }

    @Test func deadlineStopsOutputWithoutAnotherRead() async throws {
        var stops = 0
        let coordinator = DJConnectAudioPlaybackCoordinator { stops += 1 }
        let ticket = try #require(coordinator.begin(deadline: Date().addingTimeInterval(0.03)))
        for _ in 0..<100 where stops < 2 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(stops == 2)
        #expect(!coordinator.isCurrent(ticket))
    }

    @Test func preparationMayShortenButNeverExtendOriginalDeadline() throws {
        var now = Date(timeIntervalSince1970: 100)
        let coordinator = DJConnectAudioPlaybackCoordinator(now: { now }, stopOutput: {})
        let ticket = try #require(coordinator.begin(deadline: now.addingTimeInterval(30)))
        #expect(coordinator.shortenDeadline(now.addingTimeInterval(10), for: ticket))
        now = now.addingTimeInterval(11)
        #expect(!coordinator.isCurrent(ticket))
        let next = try #require(coordinator.begin(deadline: now.addingTimeInterval(20)))
        #expect(!coordinator.shortenDeadline(now.addingTimeInterval(21), for: next))
        #expect(!coordinator.isCurrent(next))
    }
}
