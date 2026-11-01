import Foundation
import CoreFoundation

/// Bounded scheduling only. Every read closure still requires its independently
/// retained registered original. Neither a hint nor this worker selects a scope.
@MainActor final class RegisteredHostWakeRefreshOwner {
    private var work: Task<Int, Never>?
    private let budget: Duration
    init(budget: Duration = .seconds(25)) { self.budget = budget }
    deinit { work?.cancel() }

    static func isContentFreeHint(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard userInfo.count == 1, let aps = userInfo["aps"] as? [AnyHashable: Any], aps.count == 1,
              let value = aps["content-available"] as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(), value == 1 else { return false }
        return true
    }
    func run(_ reads: [@MainActor @Sendable () async -> Bool]) async -> Int {
        if let work { return await work.value } // Join; never overlap a callback's reads.
        guard !Task.isCancelled, !reads.isEmpty, reads.count <= 2 else { return 0 }
        // Independent OS callback resource budget, captured before task creation.
        // This is not a renewed purpose/field/SDK lifetime.
        let deadline = ContinuousClock.now.advanced(by: budget)
        let operation = Task { @MainActor in
            await withTaskGroup(of: Bool.self, returning: Int.self) { group in
                for read in reads {
                    group.addTask {
                        guard !Task.isCancelled, ContinuousClock.now < deadline else { return false }
                        let received = await read()
                        return received && !Task.isCancelled && ContinuousClock.now < deadline
                    }
                }
                var count = 0
                for await received in group where received { count += 1 }
                return Task.isCancelled ? 0 : count
            }
        }
        work = operation
        let watchdog = Task {
            do { try await Task.sleep(until: deadline, clock: .continuous) } catch { return }
            operation.cancel() // URLSession cancellation propagates through the original read owner.
        }
        defer { watchdog.cancel(); work = nil }
        return await operation.value
    }
}
