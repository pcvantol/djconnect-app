import Foundation
import Combine
import simd

/// Relative local bias: midpoint preserves the DJ scene's baseline motion.
enum VibeScapeDynamics {
    static func motionRate(_ value: Float) -> Float { 0.04 + 3.84 * value * value }
    static func deformation(_ value: Float) -> Float { 0.15 + 1.7 * value }
}

/// Renderer-local values, not a proposed Core wire DTO. No Codable, persistence,
/// transcript, media action, preference store or general Ask DJ dependency.
struct VibeScapeScene: Equatable, Sendable {
    var composition: SIMD4<Float>
    var palette: SIMD3<Float>
    var secondaryPalette: SIMD3<Float>
    var accentPalette: SIMD3<Float>
    var motion: Float
    var depth: Float
    var roughness: Float
    var deformation: Float

    static func autonomous(mood: String?, salt: UInt64) -> Self {
        var rng = VibeScapeRandom(state: salt)
        let colors = moodColors(mood)
        return Self(composition: SIMD4(rng.unit(), rng.unit(), rng.unit(), rng.unit()),
                    palette: colors[0], secondaryPalette: colors[1], accentPalette: colors[2],
                    motion: mood == "chill" ? 0.18 : 0.30, depth: 0.35 + rng.unit() * 0.45,
                    roughness: 0.035 + rng.unit() * 0.09, deformation: 0.25 + rng.unit() * 0.45)
    }

    // Exact Session palette, kept Foundation-only for the native GPU probe.
    static func moodTint(_ mood: String?) -> SIMD3<Float> { moodColors(mood)[0] }
    static func moodColors(_ mood: String?) -> [SIMD3<Float>] {
        let values: [UInt32]
        switch mood {
        case "chill": values = [0x4DA3FF, 0x7B61FF, 0xD184FF]
        case "groove": values = [0x06C7AD, 0x169BC8, 0x10B981]
        case "energy": values = [0xDDFF00, 0x00B8FF, 0x39FF78]
        case "party": values = [0xFF287F, 0xAA38F5, 0xF43DCE]
        default: values = [0x3285FF, 0x843DF5, 0xCB27F5]
        }
        return values.map { rgb in
            SIMD3(Float((rgb >> 16) & 255), Float((rgb >> 8) & 255), Float(rgb & 255)) / 255
        }
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

struct VibeScapePatch: Equatable, Sendable {
    var palette: SIMD3<Float>?
    var motion: Float?
    var depth: Float?
    var roughness: Float?
    var deformation: Float?
    enum Scope: Equatable, Sendable { case currentTrack, continuousVisit }
    var scope: Scope = .currentTrack

    var isValid: Bool {
        let values = [motion, depth, roughness, deformation].compactMap { $0 }
        guard values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return false }
        if let palette, !(0..<3).allSatisfy({ palette[$0].isFinite && (0...1).contains(palette[$0]) }) { return false }
        return palette != nil || !values.isEmpty
    }
    func applied(to scene: VibeScapeScene) -> VibeScapeScene {
        var next = scene
        if let palette {
            next.palette = palette
            // A future explicit RGB patch owns the whole visual color family;
            // autonomous mood accents must not leak through a held color.
            next.secondaryPalette = palette * 0.65
            next.accentPalette = simd_mix(palette, SIMD3(repeating: 1), SIMD3(repeating: 0.20))
        }
        if let motion { next.motion = motion }
        if let depth { next.depth = depth }
        if let roughness { next.roughness = roughness }
        if let deformation { next.deformation = deformation }
        return next
    }
    func merging(_ newer: Self, scope: Scope = .continuousVisit) -> Self {
        Self(palette: newer.palette ?? palette, motion: newer.motion ?? motion,
             depth: newer.depth ?? depth, roughness: newer.roughness ?? roughness,
             deformation: newer.deformation ?? deformation, scope: scope)
    }
    func removingFields(overriddenBy newer: Self) -> Self? {
        let remaining = Self(palette: newer.palette == nil ? palette : nil,
                             motion: newer.motion == nil ? motion : nil,
                             depth: newer.depth == nil ? depth : nil,
                             roughness: newer.roughness == nil ? roughness : nil,
                             deformation: newer.deformation == nil ? deformation : nil,
                             scope: scope)
        return remaining.isValid ? remaining : nil
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
    private var trackPatch: VibeScapePatch?
    private struct Checkpoint {
        let scene: VibeScapeScene
        let patch: VibeScapePatch?
        let trackPatch: VibeScapePatch?
        let autonomous: VibeScapeScene?
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
        undo.append(Checkpoint(scene: scene, patch: persistentPatch, trackPatch: trackPatch,
                               autonomous: autonomous, dynamics: dynamics))
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
        var nextPersistent = persistentPatch
        var nextTrack = trackPatch
        if patch.scope == .continuousVisit {
            nextPersistent = persistentPatch?.merging(patch) ?? patch
            nextTrack = trackPatch?.removingFields(overriddenBy: patch)
        } else {
            nextTrack = trackPatch?.merging(patch, scope: .currentTrack) ?? patch
        }
        let nextScene = patch.applied(to: scene)
        guard nextScene != scene || nextPersistent != persistentPatch || nextTrack != trackPatch else { return false }
        checkpoint(); turns += 1; persistentPatch = nextPersistent; trackPatch = nextTrack
        advance(nextScene); return true
    }
    @discardableResult func setDynamics(_ value: Float) -> Bool {
        guard isCurrent, value.isFinite, (0...1).contains(value), value != dynamics, let scene else { return false }
        dynamics = value; advance(scene); return true
    }
    func moodChanged(_ mood: String?) {
        guard isCurrent, var scene, var baseline = autonomous else { return }
        let tint = VibeScapeScene.moodTint(mood)
        guard baseline.palette != tint else { return }
        let colors = VibeScapeScene.moodColors(mood)
        baseline.palette = tint; baseline.secondaryPalette = colors[1]; baseline.accentPalette = colors[2]
        autonomous = baseline
        // A confirmed mood refresh must not undo an explicit visual palette.
        if trackPatch?.palette == nil && persistentPatch?.palette == nil {
            scene.palette = tint; scene.secondaryPalette = colors[1]; scene.accentPalette = colors[2]
        }
        undo.removeAll()
        if self.scene != scene { advance(scene) }
    }
    @discardableResult func undoLast(expected: VibeScapeRenderTicket) -> Bool {
        guard admitted(expected), expected.occurrence != nil, turns < 32, let prior = undo.popLast() else { return false }
        turns += 1; persistentPatch = prior.patch; trackPatch = prior.trackPatch
        autonomous = prior.autonomous; dynamics = prior.dynamics
        advance(prior.scene); return true
    }
    @discardableResult func resetToDJ(expected: VibeScapeRenderTicket) -> Bool {
        guard admitted(expected), expected.occurrence != nil, turns < 32, let autonomous,
              scene != autonomous || persistentPatch != nil || trackPatch != nil || dynamics != 0.5 else { return false }
        checkpoint(); turns += 1; persistentPatch = nil; trackPatch = nil; dynamics = 0.5
        advance(autonomous); return true
    }
    /// Hold promotes only previously explicit current-track fields. Generated
    /// palette/material/motion defaults never become an implicit style mask.
    @discardableResult func holdExplicitStyle(expected: VibeScapeRenderTicket) -> Bool {
        guard admitted(expected), expected.occurrence != nil, turns < 32,
              let explicit = trackPatch, let scene else { return false }
        checkpoint(); turns += 1
        persistentPatch = persistentPatch?.merging(explicit) ?? VibeScapePatch().merging(explicit)
        trackPatch = nil
        advance(scene); return true
    }
    /// Only composition changes; explicit fields, slider and material stay.
    /// Undo restores the previous autonomous baseline as well as user masks.
    @discardableResult func varyComposition(expected: VibeScapeRenderTicket) -> Bool {
        guard admitted(expected), expected.occurrence != nil, turns < 32,
              var scene, var baseline = autonomous else { return false }
        checkpoint(); turns += 1; salt &+= 0x9e3779b97f4a7c15
        baseline.composition = VibeScapeScene.autonomous(mood: nil, salt: salt).composition
        scene.composition = baseline.composition; autonomous = baseline
        advance(scene); return true
    }
    func trackChanged(mood: String?, occurrence: String?) {
        guard Self.validOccurrence(occurrence) else { revoke(); return }
        guard isCurrent, let ticket, ticket.occurrence != occurrence else { return }
        salt &+= 0x9e3779b97f4a7c15
        let next = VibeScapeScene.autonomous(mood: mood, salt: salt)
        autonomous = next; trackPatch = nil; undo.removeAll()
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
        scene = nil; ticket = nil; autonomous = nil; persistentPatch = nil; trackPatch = nil
        undo.removeAll(keepingCapacity: false); dynamics = 0.5; appliedRevision = nil
        salt = 0; turns = 0; deadline = 0; lastUptime = 0
    }
}


/// A submitted frame is not an applied frame. Reservations distinguish GPU
/// callbacks even when a failed frame is retried for the same scene revision.
@MainActor final class VibeScapeFrameFence {
    struct Frame: Equatable, Sendable {
        let id: UUID
        let scene: VibeScapeRenderTicket
    }
    private let visit: VisualDirectorVisit
    private var pending: Frame?
    private var acknowledged: VibeScapeRenderTicket?
    private var subscription: AnyCancellable?

    init(visit: VisualDirectorVisit) {
        self.visit = visit
        subscription = visit.$ticket.sink { [weak self] _ in
            self?.pending = nil
            self?.acknowledged = nil
        }
    }

    func begin(_ scene: VibeScapeRenderTicket) -> Frame? {
        guard visit.isCurrent, visit.ticket == scene, pending == nil,
              acknowledged != scene else { return nil }
        let frame = Frame(id: UUID(), scene: scene)
        pending = frame
        return frame
    }

    @discardableResult func complete(_ frame: Frame, succeeded: Bool) -> Bool {
        guard pending == frame else { return false }
        pending = nil
        guard succeeded, visit.rendererCompleted(frame.scene) else { return false }
        acknowledged = frame.scene
        return true
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
