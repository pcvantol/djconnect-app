import Foundation
import Combine
import simd

/// Renderer-local values, not a proposed Core wire DTO. No Codable, persistence,
/// transcript, media action, preference store or general Ask DJ dependency.
struct VibeScapeScene: Equatable, Sendable {
    var composition: SIMD4<Float>
    var palette: SIMD3<Float>
    var motion: Float
    var depth: Float
    var roughness: Float
    var deformation: Float

    static func autonomous(mood: String?, salt: UInt64) -> Self {
        var rng = VibeScapeRandom(state: salt)
        let tint: SIMD3<Float>
        switch mood {
        case "chill": tint = SIMD3(0.25, 0.65, 0.85)
        case "groove": tint = SIMD3(0.30, 0.85, 0.60)
        case "energy": tint = SIMD3(0.95, 0.55, 0.18)
        case "party": tint = SIMD3(0.75, 0.30, 0.85)
        default: tint = SIMD3(0.60, 0.65, 0.85)
        }
        return Self(composition: SIMD4(rng.unit(), rng.unit(), rng.unit(), rng.unit()),
                    palette: simd_clamp(tint + SIMD3(rng.unit(), rng.unit(), rng.unit()) * 0.18, SIMD3(repeating: 0), SIMD3(repeating: 1)),
                    motion: mood == "chill" ? 0.18 : 0.30, depth: 0.35 + rng.unit() * 0.45,
                    roughness: 0.035 + rng.unit() * 0.09, deformation: 0.25 + rng.unit() * 0.45)
    }
}

private struct VibeScapeRandom {
    var state: UInt64
    mutating func unit() -> Float {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return Float((z ^ (z >> 31)) >> 40) / Float(1 << 24)
    }
}

struct VibeScapePatch: Sendable {
    var palette: SIMD3<Float>?
    var motion: Float?
    var depth: Float?
    var roughness: Float?
    var deformation: Float?
    enum Scope: Sendable { case currentTrack, continuousVisit }
    var scope: Scope = .currentTrack

    var isValid: Bool {
        let values = [motion, depth, roughness, deformation].compactMap { $0 }
        guard values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return false }
        if let palette, !(0..<3).allSatisfy({ palette[$0].isFinite && (0...1).contains(palette[$0]) }) { return false }
        return palette != nil || !values.isEmpty
    }
    func applied(to scene: VibeScapeScene) -> VibeScapeScene {
        var next = scene
        if let palette { next.palette = palette }
        if let motion { next.motion = motion }
        if let depth { next.depth = depth }
        if let roughness { next.roughness = roughness }
        if let deformation { next.deformation = deformation }
        return next
    }
    func merging(_ newer: Self) -> Self {
        Self(palette: newer.palette ?? palette, motion: newer.motion ?? motion,
             depth: newer.depth ?? depth, roughness: newer.roughness ?? roughness,
             deformation: newer.deformation ?? deformation, scope: .continuousVisit)
    }
}

/// The only acknowledgment eligible for an applied toast is a successful GPU
/// completion for this exact visit, occurrence and revision. A parse is not ACK.
struct VibeScapeRenderTicket: Equatable, Sendable {
    let visit: UUID
    let occurrence: String?
    let revision: UInt64
}

@MainActor final class VisualDirectorVisit: ObservableObject {
    @Published private(set) var scene: VibeScapeScene?
    @Published private(set) var ticket: VibeScapeRenderTicket?
    @Published private(set) var appliedRevision: UInt64?
    @Published private(set) var dynamics: Float = 0.5
    private var salt: UInt64 = 0
    private var autonomous: VibeScapeScene?
    private var persistentPatch: VibeScapePatch?
    private struct Checkpoint {
        let scene: VibeScapeScene
        let patch: VibeScapePatch?
        let dynamics: Float
    }
    private var undo: [Checkpoint] = []
    private var turns = 0
    private var deadline: TimeInterval = 0
    private var lastUptime: TimeInterval = 0
    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }

    func enter(mood: String?, occurrence: String?, salt: UInt64 = .random(in: .min ... .max)) {
        revoke()
        self.salt = salt
        let time = now()
        guard time.isFinite, time >= 0,
              Self.validOccurrence(occurrence) else { revoke(); return }
        deadline = time + 1800; lastUptime = time
        let scene = VibeScapeScene.autonomous(mood: mood, salt: salt)
        autonomous = scene; self.scene = scene
        ticket = VibeScapeRenderTicket(visit: UUID(), occurrence: occurrence, revision: 0)
    }
    var isCurrent: Bool {
        let time = now()
        return scene != nil && ticket != nil && time.isFinite && time >= lastUptime && time < deadline
    }
    private func admitted(_ expected: VibeScapeRenderTicket) -> Bool {
        guard isCurrent, ticket == expected else { return false }
        lastUptime = now(); return true
    }
    private func checkpoint() {
        guard let scene else { return }
        undo.append(Checkpoint(scene: scene, patch: persistentPatch, dynamics: dynamics))
        if undo.count > 8 { undo.removeFirst(undo.count - 8) }
    }
    private func advance(_ scene: VibeScapeScene) {
        guard let ticket else { return }
        self.scene = scene
        self.ticket = VibeScapeRenderTicket(visit: ticket.visit, occurrence: ticket.occurrence, revision: ticket.revision + 1)
        appliedRevision = nil
    }
    @discardableResult func apply(_ patch: VibeScapePatch, expected: VibeScapeRenderTicket) -> Bool {
        guard admitted(expected), expected.occurrence != nil, patch.isValid, turns < 32, let scene else { return false }
        checkpoint(); turns += 1
        if patch.scope == .continuousVisit { persistentPatch = persistentPatch?.merging(patch) ?? patch }
        advance(patch.applied(to: scene)); return true
    }
    @discardableResult func setDynamics(_ value: Float) -> Bool {
        guard isCurrent, value.isFinite, (0...1).contains(value), let scene else { return false }
        dynamics = value; advance(scene); return true
    }
    @discardableResult func undoLast(expected: VibeScapeRenderTicket) -> Bool {
        guard admitted(expected), turns < 32, let prior = undo.popLast() else { return false }
        turns += 1; persistentPatch = prior.patch; dynamics = prior.dynamics
        advance(prior.scene); return true
    }
    @discardableResult func resetToDJ(expected: VibeScapeRenderTicket) -> Bool {
        guard admitted(expected), turns < 32, let autonomous else { return false }
        checkpoint(); turns += 1; persistentPatch = nil; dynamics = 0.5
        advance(autonomous); return true
    }
    func trackChanged(mood: String?, occurrence: String?) {
        guard Self.validOccurrence(occurrence) else { revoke(); return }
        guard isCurrent, let ticket, ticket.occurrence != occurrence else { return }
        salt &+= 0x9e3779b97f4a7c15
        let next = VibeScapeScene.autonomous(mood: mood, salt: salt)
        autonomous = next; undo.removeAll()
        self.ticket = VibeScapeRenderTicket(visit: ticket.visit, occurrence: occurrence, revision: ticket.revision + 1)
        scene = persistentPatch?.applied(to: next) ?? next; appliedRevision = nil
    }
    private static func validOccurrence(_ value: String?) -> Bool {
        value.map { !$0.isEmpty && $0.utf8.count <= 256 } ?? true
    }
    @discardableResult func rendererCompleted(_ expected: VibeScapeRenderTicket) -> Bool {
        guard admitted(expected) else { return false }
        appliedRevision = expected.revision; return true
    }
    func revoke() {
        scene = nil; ticket = nil; autonomous = nil; persistentPatch = nil
        undo.removeAll(keepingCapacity: false); dynamics = 0.5; appliedRevision = nil
        salt = 0; turns = 0; deadline = 0; lastUptime = 0
    }
}


/// Local request coordination, NOT a Core request/response DTO or an authority
/// grant. A future qualified adapter must supply the original source deadline
/// and a closure that rechecks the SAME original owner/session/source lease.
/// No transcript, response payload, wire token or durable store lives here.
@MainActor final class VisualDirectorTurnFence {
    struct Turn: Equatable, Sendable {
        let id: UUID
        let scene: VibeScapeRenderTicket
        let deadline: TimeInterval
    }
    private struct Pending {
        let turn: Turn
        let started: TimeInterval
        let isCurrent: () -> Bool
    }
    private let visit: VisualDirectorVisit
    private var pending: Pending?
    private var visitID: UUID?
    private var attempts = 0
    private var subscription: AnyCancellable?
    private var expiryTask: Task<Void, Never>?

    init(visit: VisualDirectorVisit) {
        self.visit = visit
        subscription = visit.$ticket.sink { [weak self] next in
            guard let self else { return }
            if self.visitID != next?.visit {
                self.cancel(); self.visitID = next?.visit; self.attempts = 0
            } else if let pending = self.pending, pending.turn.scene != next {
                self.cancel()
            }
        }
    }

    /// One in-flight turn, at most32 attempts during the same continuous visit.
    /// Thirty seconds is a local maximum, never an extension of a shorter Core
    /// lease or a promise about the producer's eventual wire contract.
    func begin(originalSourceDeadline: TimeInterval,
               isCurrent: @escaping () -> Bool) -> Turn? {
        let time = visit.now()
        guard visit.isCurrent, let scene = visit.ticket, scene.occurrence != nil,
              originalSourceDeadline.isFinite, originalSourceDeadline > time else { return nil }
        if let pending, (time < pending.started || time >= pending.turn.deadline) { cancel() }
        guard pending == nil else { return nil }
        if visitID != scene.visit { visitID = scene.visit; attempts = 0 }
        guard attempts < 32, isCurrent(), visit.isCurrent, visit.ticket == scene, pending == nil else { return nil }
        // Read time again after owner checks: they cannot renew the old lease.
        let admittedAt = visit.now()
        let deadline = min(originalSourceDeadline, time + 30)
        guard admittedAt >= time, admittedAt < deadline else { return nil }
        attempts += 1
        let turn = Turn(id: UUID(), scene: scene, deadline: deadline)
        pending = Pending(turn: turn, started: time, isCurrent: isCurrent)
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(deadline-admittedAt))
            guard !Task.isCancelled, let self, self.pending?.turn == turn else { return }
            self.cancel()
        }
        return turn
    }

    /// The callback is never called for a stale/cancelled/duplicate turn, even
    /// if a replacement request has the same base scene revision. Clearing the
    /// reservation precedes any application; GPU completion remains separate.
    @discardableResult func complete(_ turn: Turn, apply: () -> Bool) -> Bool {
        guard let pending, pending.turn == turn else { return false }
        let time = visit.now()
        guard time.isFinite, time >= pending.started, time < turn.deadline,
              visit.isCurrent, visit.ticket == turn.scene, pending.isCurrent(),
              visit.now() >= time, visit.now() < turn.deadline,
              visit.isCurrent, visit.ticket == turn.scene,
              self.pending?.turn == turn else {
            if self.pending?.turn == turn { cancel() }
            return false
        }
        cancel()
        return apply()
    }

    func cancel() {
        pending = nil
        expiryTask?.cancel(); expiryTask = nil
    }
}
