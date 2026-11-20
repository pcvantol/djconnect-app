import Foundation

/// Foreground placement only. This budget grants no content, source or media rights.
struct AskDJMomentsPresentation: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case idle, choosing, pending, notice
        case presenting(momentID: String, entryID: String?)
    }
    enum Hold: Hashable, Sendable { case reading, expandedText, photo, preparation, narration, accessibility, interaction }
    private(set) var generation = UUID()
    private(set) var phase: Phase = .idle
    private(set) var remainingVisibleSeconds: TimeInterval = 20
    private(set) var visible = false
    private(set) var holds: Set<Hold> = []
    private var lastObserved: TimeInterval?

    var momentID: String? {
        if case .presenting(let id, _) = phase { return id }
        return nil
    }
    var isExpanded: Bool { phase != .idle }
    var isPending: Bool { phase == .pending }

    @discardableResult mutating func choose() -> UUID {
        dismiss()
        phase = .choosing
        return generation
    }
    mutating func request(generation token: UUID) -> Bool {
        guard token == generation, phase == .choosing else { return false }
        phase = .pending
        return true
    }
    mutating func present(momentID: String, entryID: String?, generation token: UUID) -> Bool {
        guard token == generation, phase == .pending || phase == .notice, !momentID.isEmpty else { return false }
        phase = .presenting(momentID: momentID, entryID: entryID)
        remainingVisibleSeconds = 20
        visible = false
        holds = []
        lastObserved = nil
        return true
    }
    mutating func notice(generation token: UUID) {
        guard generation == token, phase == .pending || phase == .choosing else { return }
        phase = .notice
        visible = false
        holds = []
        lastObserved = nil
    }
    mutating func visibility(_ value: Bool, at now: TimeInterval, generation token: UUID) {
        guard generation == token, momentID != nil else { return }
        advance(at: now, generation: token)
        guard generation == token, momentID != nil else { return }
        visible = value
        lastObserved = now
    }
    mutating func hold(_ hold: Hold, active: Bool, at now: TimeInterval, generation token: UUID) {
        guard generation == token, momentID != nil else { return }
        advance(at: now, generation: token)
        guard generation == token, momentID != nil else { return }
        if active { holds.insert(hold) } else { holds.remove(hold) }
        lastObserved = now
    }
    mutating func advance(at now: TimeInterval, generation token: UUID, rightsValid: Bool = true) {
        guard token == generation, momentID != nil else { return }
        guard rightsValid else { dismiss(); return }
        if let previous = lastObserved, visible, holds.isEmpty {
            remainingVisibleSeconds -= max(0, now - previous)
        }
        lastObserved = now
        if remainingVisibleSeconds <= 0 { dismiss() }
    }
    mutating func dismiss() {
        generation = UUID()
        phase = .idle
        remainingVisibleSeconds = 20
        visible = false
        holds = []
        lastObserved = nil
    }
}
