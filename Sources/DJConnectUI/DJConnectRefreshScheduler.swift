import Foundation

@MainActor
final class DJConnectRefreshScheduler {
    private var pairedRefreshTask: Task<Void, Never>?
    private var backendRecoveryTask: Task<Void, Never>?
    private var commandRefreshTask: Task<Void, Never>?
    private var pendingCommandRefreshIncludesQueue = false
    private var pendingCommandRefreshCleanup: (@MainActor () -> Void)?
    private var commandRefreshGeneration = 0

    deinit {
        pairedRefreshTask?.cancel()
        backendRecoveryTask?.cancel()
        commandRefreshTask?.cancel()
    }

    func cancelAll() {
        pairedRefreshTask?.cancel()
        pairedRefreshTask = nil
        cancelCommandRefresh()
        cancelBackendRecovery()
    }

    func cancelPairedRefresh() {
        pairedRefreshTask?.cancel()
        pairedRefreshTask = nil
    }

    func cancelBackendRecovery() {
        backendRecoveryTask?.cancel()
        backendRecoveryTask = nil
    }

    func cancelCommandRefresh() {
        commandRefreshTask?.cancel()
        commandRefreshTask = nil
        commandRefreshGeneration += 1
        pendingCommandRefreshIncludesQueue = false
        pendingCommandRefreshCleanup?()
        pendingCommandRefreshCleanup = nil
    }

    func scheduleCommandRefresh(
        delay: Duration = .milliseconds(850),
        includeQueue: Bool = false,
        cleanup: (@MainActor () -> Void)? = nil,
        isStillValid: @escaping @MainActor () -> Bool,
        refresh: @escaping @MainActor (_ includeQueue: Bool) async -> Void
    ) {
        pendingCommandRefreshIncludesQueue = pendingCommandRefreshIncludesQueue || includeQueue
        let previousCleanup = pendingCommandRefreshCleanup
        pendingCommandRefreshCleanup = {
            previousCleanup?()
            cleanup?()
        }
        commandRefreshTask?.cancel()
        commandRefreshGeneration += 1
        let generation = commandRefreshGeneration
        commandRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard self?.commandRefreshGeneration == generation else {
                return
            }
            guard !Task.isCancelled, isStillValid() else {
                self?.pendingCommandRefreshIncludesQueue = false
                self?.pendingCommandRefreshCleanup?()
                self?.pendingCommandRefreshCleanup = nil
                self?.commandRefreshTask = nil
                return
            }
            let includeQueue = self?.pendingCommandRefreshIncludesQueue ?? false
            let cleanup = self?.pendingCommandRefreshCleanup
            self?.pendingCommandRefreshCleanup = nil
            // Keep the invalidation until completion so a later status-only
            // command cannot cancel a waiting queue refresh and lose it.
            await refresh(includeQueue)
            cleanup?()
            if self?.commandRefreshGeneration == generation {
                self?.pendingCommandRefreshIncludesQueue = false
                self?.commandRefreshTask = nil
            }
        }
    }

    func schedulePairedRefresh(
        initialDelay: Duration = .milliseconds(350),
        followUpDelay: Duration = .milliseconds(1_200),
        runFollowUpRefresh: Bool = true,
        isStillValid: @escaping @MainActor () -> Bool,
        refresh: @escaping @MainActor () async -> Void,
        followUpRefresh: @escaping @MainActor () async -> Void
    ) {
        cancelPairedRefresh()
        pairedRefreshTask = Task { @MainActor in
            try? await Task.sleep(for: initialDelay)
            guard !Task.isCancelled, isStillValid() else {
                return
            }
            await refresh()
            guard runFollowUpRefresh else {
                return
            }
            try? await Task.sleep(for: followUpDelay)
            guard !Task.isCancelled, isStillValid() else {
                return
            }
            await followUpRefresh()
        }
    }

    func scheduleBackendRecovery(
        initialDelayNanoseconds: UInt64 = 2_000_000_000,
        maximumDelayNanoseconds: UInt64 = 10_000_000_000,
        isStillNeeded: @escaping @MainActor () -> Bool,
        refresh: @escaping @MainActor () async -> Void
    ) {
        guard backendRecoveryTask == nil else {
            return
        }
        backendRecoveryTask = Task { @MainActor [weak self] in
            var delay = initialDelayNanoseconds
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else {
                    return
                }
                guard isStillNeeded() else {
                    self?.backendRecoveryTask = nil
                    return
                }
                await refresh()
                delay = min(delay * 2, maximumDelayNanoseconds)
            }
        }
    }
}
