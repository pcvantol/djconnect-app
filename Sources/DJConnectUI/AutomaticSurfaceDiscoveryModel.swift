import DJConnectCore
import Foundation

/// Device-only, in-memory comparison state. No Session/Profile, persisted grant,
/// native token/SDK service or registration action exists in this model.
@MainActor final class AutomaticSurfaceDiscoveryModel {
    struct Owner: Equatable, Sendable {
        let scope: DJConnectAutomaticSurfaceScope
        let origin: URL
        let pairingAttempt: UUID
    }
    typealias Read = @MainActor @Sendable (
        DJConnectAutomaticSurfaceRole, DJConnectAutomaticSurfaceScope,
        @escaping @MainActor @Sendable () -> Bool
    ) async throws -> DJConnectAutomaticSurfaceState

    private(set) var owner: Owner?
    private(set) var states: [DJConnectAutomaticSurfaceRole: DJConnectAutomaticSurfaceState] = [:]
    private var epoch = UUID()
    private var tasks: [DJConnectAutomaticSurfaceRole: Task<Void, Never>] = [:]
    private var attemptedAt: [DJConnectAutomaticSurfaceRole: Date] = [:]
    private let now: () -> Date
    init(now: @escaping () -> Date = Date.init) { self.now = now }

    func bind(_ value: Owner?) {
        guard owner != value else { return }
        epoch = UUID()
        for task in tasks.values { task.cancel() }
        tasks.removeAll(); states.removeAll(); attemptedAt.removeAll()
        owner = value
    }

    @discardableResult
    func refresh(isCurrent: @escaping @MainActor @Sendable () -> Bool, read: @escaping Read) -> [Task<Void, Never>] {
        guard let owner else { return [] }
        guard isCurrent() else { bind(nil); return [] }
        let roles: [DJConnectAutomaticSurfaceRole]
        switch owner.scope.platform {
        case "ios", "ipados": roles = [.widget, .statusActivity]
        case "macos": roles = [.widget]
        default: roles = [] // Watch role enumeration never qualifies support.
        }
        let capturedEpoch = epoch
        for role in roles {
            guard tasks[role] == nil,
                  attemptedAt[role].map({ now().timeIntervalSince($0) >= 30 }) ?? true else { continue }
            attemptedAt[role] = now() // Read throttling, never an authority lease.
            tasks[role] = Task { [weak self] in
                guard let self else { return }
                let accepts: @MainActor @Sendable () -> Bool = { [weak self] in
                    guard let self else { return false }
                    return !Task.isCancelled && self.epoch == capturedEpoch && self.owner == owner && isCurrent()
                }
                defer { if epoch == capturedEpoch { tasks[role] = nil } }
                guard accepts() else {
                    if epoch == capturedEpoch { bind(nil) }
                    return
                }
                do {
                    let result = try await read(role, owner.scope, accepts)
                    guard accepts() else {
                        if epoch == capturedEpoch { bind(nil) }
                        return
                    }
                    states[role] = result
                } catch {
                    guard accepts() else {
                        if epoch == capturedEpoch { bind(nil) }
                        return
                    }
                    // Missing/not-yet-installed route or auth failure cannot
                    // change ordinary pairing, retry another wire or start SDK.
                    states[role] = .unavailable
                }
            }
        }
        return Array(tasks.values)
    }
}
