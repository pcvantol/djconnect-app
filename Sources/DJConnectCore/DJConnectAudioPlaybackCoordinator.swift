import Foundation

/// Device-local, single-output ownership. A ticket survives neither Stop nor a
/// replacement, even when both requests refer to the same contribution or URL.
/// Callers must recheck it after every suspension and before starting output.
@MainActor
public final class DJConnectAudioPlaybackCoordinator {
    public struct Ticket: Equatable, Sendable { fileprivate let id = UUID() }
    private var current: Ticket?
    private var deadline: Date?
    private var expiryTask: Task<Void, Never>?
    private let now: () -> Date
    private let stopOutput: () -> Void

    public init(now: @escaping () -> Date = Date.init, stopOutput: @escaping () -> Void) {
        self.now = now
        self.stopOutput = stopOutput
    }

    /// Use the original server deadline for qualified speech, never a renewed
    /// deadline derived from a late prepare/download. No content is retained.
    public func begin(deadline: Date? = nil) -> Ticket? {
        stop()
        guard deadline.map({ $0 > now() }) ?? true else { return nil }
        let ticket = Ticket()
        current = ticket
        self.deadline = deadline
        if let deadline {
            let remaining = deadline.timeIntervalSince(now())
            guard remaining > 0, remaining <= 300 else { stop(); return nil }
            expiryTask = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(remaining)) } catch { return }
                self?.finish(ticket)
            }
        }
        return ticket
    }

    public func isCurrent(_ ticket: Ticket) -> Bool {
        guard current == ticket else { return false }
        if let deadline, deadline <= now() { stop(); return false }
        return true
    }

    public func finish(_ ticket: Ticket) {
        guard current == ticket else { return }
        stop()
    }

    /// Also call on Profile/session authority loss. Invalidates pending work
    /// before stopping output, so a late completion cannot reclaim ownership.
    public func stop() {
        current = nil
        deadline = nil
        expiryTask?.cancel()
        expiryTask = nil
        stopOutput()
    }
}
