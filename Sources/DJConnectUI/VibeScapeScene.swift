import Foundation
import Combine
import simd
import DJConnectCore

struct VibeScapeTouch: Equatable, Sendable {
    let position: SIMD2<Float>
    let startedAt: TimeInterval
    var strength: Float = 1
}

/// Renderer-local values, not a proposed Core wire DTO. No Codable, persistence,
/// transcript, media action, preference store or general Ask DJ dependency.
struct VibeScapeScene: Equatable, Sendable {
    var family: VibeScapeFamily = .home
    var composition: SIMD4<Float>
    var palette: SIMD3<Float>
    var secondaryPalette: SIMD3<Float>
    var accentPalette: SIMD3<Float>
    var motion: Float
    var depth: Float
    var roughness: Float
    var deformation: Float

    var isValid: Bool {
        for i in 0..<4 where !composition[i].isFinite || !(0...1).contains(composition[i]) { return false }
        for i in 0..<3 {
            for color in [palette[i], secondaryPalette[i], accentPalette[i]] where !color.isFinite || !(0...1).contains(color) { return false }
        }
        return motion.isFinite && (0...1).contains(motion) && depth.isFinite && (0...1).contains(depth)
            && roughness.isFinite && (0...1).contains(roughness) && deformation.isFinite && (0...1).contains(deformation)
    }
    static func autonomous(mood: String?, salt: UInt64, family: VibeScapeFamily = .home) -> Self {
        var rng = VibeScapeRandom(state: salt)
        let colors = moodColors(mood)
        return Self(family: family, composition: SIMD4(rng.unit(), rng.unit(), rng.unit(), rng.unit()),
                    palette: colors[0], secondaryPalette: colors[1], accentPalette: colors[2],
                    motion: family.baselineMotion(mood: mood), depth: 0.35 + rng.unit() * 0.45,
                    roughness: (family == .radio ? 0.20 : family == .club ? 0.13 : 0.035) + rng.unit() * 0.09, deformation: 0.25 + rng.unit() * 0.45)
    }

    // Exact Session palette, kept Foundation-only for the native GPU probe.
    static func moodTint(_ mood: String?) -> SIMD3<Float> { moodColors(mood)[0] }
    static func moodColors(_ mood: String?) -> [SIMD3<Float>] {
        let values = DJConnectSessionMoodTheme(sessionMood: mood).colorValues
        return values.map { rgb in
            SIMD3(Float((rgb >> 16) & 255), Float((rgb >> 8) & 255), Float(rgb & 255)) / 255
        }
    }

    func interpolated(toward target: Self, fraction: Float) -> Self {
        var next = self
        next.family = target.family
        next.composition = simd_mix(composition, target.composition, SIMD4(repeating: fraction))
        next.palette = simd_mix(palette, target.palette, SIMD3(repeating: fraction))
        next.secondaryPalette = simd_mix(secondaryPalette, target.secondaryPalette, SIMD3(repeating: fraction))
        next.accentPalette = simd_mix(accentPalette, target.accentPalette, SIMD3(repeating: fraction))
        next.motion += (target.motion - motion) * fraction
        next.depth += (target.depth - depth) * fraction
        next.roughness += (target.roughness - roughness) * fraction
        next.deformation += (target.deformation - deformation) * fraction
        return next
    }
    func distance(to target: Self) -> Float {
        max(simd_distance(composition, target.composition), simd_distance(palette, target.palette),
            simd_distance(secondaryPalette, target.secondaryPalette), simd_distance(accentPalette, target.accentPalette),
            abs(motion - target.motion), abs(depth - target.depth), abs(roughness - target.roughness), abs(deformation - target.deformation))
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
    @Published private(set) var followsTrackIntensity = true
    private var trackIntensity: Float?
    private var dynamicsScope: VibeScapePatch.Scope?
    // Restoration value only: a temporary track command replaces the single
    // effective slider value; it never stacks a second speed multiplier.
    private var visitDynamics: Float?
    private(set) var personaRevision: Int?
    private var personaFloor = -1
    private var familyAtFloor: VibeScapeFamily?
    private var personaConflict = false
    @Published private(set) var touches: [VibeScapeTouch] = []
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
        let followsTrackIntensity: Bool
        let dynamicsScope: VibeScapePatch.Scope?
        let visitDynamics: Float?
    }
    private var undo: [Checkpoint] = []
    private(set) var lifetimeID: UUID?
    private var turns = 0
    private var deadline: TimeInterval = 0
    private var lastUptime: TimeInterval = 0
    private var touchExpiryTask: Task<Void, Never>?
    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }

    // Default Home is for standalone renderer fixtures. The production Screen
    // always supplies its confirmed Session family or explicit neutral.
    func enter(mood: String?, occurrence: String?, salt: UInt64 = .random(in: .min ... .max),
               family: VibeScapeFamily = .home, personaRevision: Int? = nil) {
        revoke()
        self.salt = salt
        let time = now()
        guard time.isFinite, time >= 0,
              Self.validOccurrence(occurrence) else { revoke(); return }
        deadline = time + 1800; lastUptime = time; lifetimeID = UUID()
        let scene = VibeScapeScene.autonomous(mood: mood, salt: salt, family: family)
        self.personaRevision = personaRevision
        personaFloor = personaRevision ?? -1; familyAtFloor = personaRevision == nil ? nil : family
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
                               autonomous: autonomous, dynamics: dynamics, followsTrackIntensity: followsTrackIntensity, dynamicsScope: dynamicsScope, visitDynamics: visitDynamics))
        if undo.count > 8 { undo.removeFirst(undo.count - 8) }
    }
    private func advance(_ scene: VibeScapeScene, renewServerVisit: Bool = false) {
        guard let ticket else { return }
        self.scene = scene
        self.ticket = VibeScapeRenderTicket(visit: renewServerVisit ? UUID() : ticket.visit,
            occurrence: ticket.occurrence, revision: ticket.revision + 1)
        appliedRevision = nil
    }
    @discardableResult func apply(_ patch: VibeScapePatch, expected: VibeScapeRenderTicket) -> Bool {
        guard admitted(expected), expected.occurrence != nil, patch.isValid, turns < 32, let scene, scene.family != .neutral else { return false }
        // The director's motion field is the SAME relative control as the slider.
        // It never replaces or stacks another multiplier over autonomous motion.
        var geometry = patch; geometry.motion = nil
        var nextPersistent = persistentPatch
        var nextTrack = trackPatch
        if geometry.isValid {
            if patch.scope == .continuousVisit {
                nextPersistent = persistentPatch?.merging(geometry) ?? geometry
                nextTrack = trackPatch?.removingFields(overriddenBy: geometry)
            } else { nextTrack = trackPatch?.merging(geometry, scope: .currentTrack) ?? geometry }
        }
        let nextScene = geometry.applied(to: scene)
        let changesDynamics = patch.motion.map { $0 != dynamics || followsTrackIntensity || dynamicsScope != patch.scope } ?? false
        guard nextScene != scene || nextPersistent != persistentPatch || nextTrack != trackPatch || changesDynamics else { return false }
        checkpoint(); turns += 1; persistentPatch = nextPersistent; trackPatch = nextTrack
        if let motion = patch.motion {
            dynamics = motion; followsTrackIntensity = false; dynamicsScope = patch.scope
            if patch.scope == .continuousVisit { visitDynamics = motion }
        }
        advance(nextScene); return true
    }
    @discardableResult func setDynamics(_ value: Float) -> Bool {
        guard isCurrent, value.isFinite, (0...1).contains(value), let scene else { return false }
        let changed = value != dynamics || followsTrackIntensity || dynamicsScope != .continuousVisit
        followsTrackIntensity = false; dynamicsScope = .continuousVisit; visitDynamics = value
        guard changed else { return false }
        dynamics = value; advance(scene); return true
    }
    func beginDynamicsAdjustment() {
        guard isCurrent, let scene else { return }
        // A newer direct gesture wins even if its first value equals the thumb.
        advance(scene)
    }
    func updateTrackIntensity(_ value: Float?) {
        guard isCurrent, let scene else { return }
        trackIntensity = value.flatMap { $0.isFinite && (0...1).contains($0) ? $0 : nil }
        let next = trackIntensity ?? 0.5
        guard followsTrackIntensity, dynamics != next else { return }
        dynamics = next; advance(scene)
    }
    func followTrackIntensity() {
        guard isCurrent else { return }
        let changed = !followsTrackIntensity
        followsTrackIntensity = true; dynamicsScope = nil; visitDynamics = nil
        let prior = ticket
        updateTrackIntensity(trackIntensity)
        if changed, ticket == prior, let scene { advance(scene) }
    }
    @discardableResult func nudge(at point: SIMD2<Float>, aspect: Float, strength: Float = 1) -> Bool {
        guard isCurrent, let scene, scene.family != .neutral, point.x.isFinite, point.y.isFinite,
              (0...1).contains(point.x), (0...1).contains(point.y),
              aspect.isFinite, aspect > 0, aspect <= 8,
              strength.isFinite, (0.5...2.5).contains(strength) else { return false }
        let time = now()
        touches.removeAll { time - $0.startedAt >= 2.6 }
        touches.append(VibeScapeTouch(position: SIMD2((point.x*2-1)*aspect, 1-point.y*2), startedAt: time, strength: strength))
        if touches.count > 4 { touches.removeFirst(touches.count-4) }
        advance(scene)
        touchExpiryTask?.cancel()
        touchExpiryTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2.6)) } catch { return }
            guard !Task.isCancelled, let self, self.touches.last?.startedAt == time else { return }
            self.touches.removeAll()
            if self.isCurrent, let scene = self.scene { self.advance(scene) }
        }
        return true
    }
    func moodChanged(_ mood: String?) {
        guard isCurrent, var scene, var baseline = autonomous else { return }
        let tint = VibeScapeScene.moodTint(mood)
        guard baseline.palette != tint else { return }
        let colors = VibeScapeScene.moodColors(mood)
        baseline.palette = tint; baseline.secondaryPalette = colors[1]; baseline.accentPalette = colors[2]
        baseline.motion = baseline.family.baselineMotion(mood: mood)
        scene.motion = baseline.motion
        autonomous = baseline
        // A confirmed mood refresh must not undo an explicit visual palette.
        if trackPatch?.palette == nil && persistentPatch?.palette == nil {
            scene.palette = tint; scene.secondaryPalette = colors[1]; scene.accentPalette = colors[2]
        }
        undo.removeAll()
        if self.scene != scene { advance(scene) }
    }
    @discardableResult func undoLast(expected: VibeScapeRenderTicket) -> Bool {
        guard admitted(expected), expected.occurrence != nil, turns < 32, let prior = undo.last,
              prior.scene.family == scene?.family, prior.scene.family != .neutral else { return false }
        undo.removeLast()
        turns += 1; persistentPatch = prior.patch; trackPatch = prior.trackPatch
        autonomous = prior.autonomous; followsTrackIntensity = prior.followsTrackIntensity; dynamicsScope = prior.dynamicsScope
        visitDynamics = prior.visitDynamics
        dynamics = followsTrackIntensity ? (trackIntensity ?? 0.5) : prior.dynamics
        advance(prior.scene); return true
    }
    @discardableResult func resetToDJ(expected: VibeScapeRenderTicket) -> Bool {
        guard admitted(expected), expected.occurrence != nil, turns < 32, let autonomous, autonomous.family != .neutral,
              scene != autonomous || persistentPatch != nil || trackPatch != nil || dynamics != (trackIntensity ?? 0.5) || !followsTrackIntensity else { return false }
        checkpoint(); turns += 1; persistentPatch = nil; trackPatch = nil
        followsTrackIntensity = true; dynamicsScope = nil; visitDynamics = nil; dynamics = trackIntensity ?? 0.5
        advance(autonomous); return true
    }
    /// Hold promotes only previously explicit current-track fields. Generated
    /// palette/material/motion defaults never become an implicit style mask.
    @discardableResult func holdExplicitStyle(expected: VibeScapeRenderTicket) -> Bool {
        guard admitted(expected), expected.occurrence != nil, turns < 32,
              trackPatch != nil || dynamicsScope == .currentTrack, let scene, scene.family != .neutral else { return false }
        checkpoint(); turns += 1
        if let explicit = trackPatch { persistentPatch = persistentPatch?.merging(explicit) ?? VibeScapePatch().merging(explicit) }
        if dynamicsScope == .currentTrack { dynamicsScope = .continuousVisit; visitDynamics = dynamics }
        trackPatch = nil
        advance(scene); return true
    }
    /// Only composition changes; explicit fields, slider and material stay.
    /// Undo restores the previous autonomous baseline as well as user masks.
    @discardableResult func varyComposition(expected: VibeScapeRenderTicket) -> Bool {
        guard admitted(expected), expected.occurrence != nil, turns < 32,
              var scene, scene.family != .neutral, var baseline = autonomous else { return false }
        checkpoint(); turns += 1; salt &+= 0x9e3779b97f4a7c15
        baseline.composition = VibeScapeScene.autonomous(mood: nil, salt: salt, family: baseline.family).composition
        scene.composition = baseline.composition; autonomous = baseline
        advance(scene); return true
    }
    /// Retire source tickets immediately without treating an item ID as a new
    /// server occurrence or manufacturing a new composition.
    func invalidateOccurrence() {
        guard isCurrent, let ticket, let scene else { return }
        self.ticket = VibeScapeRenderTicket(visit: UUID(), occurrence: nil, revision: ticket.revision + 1)
        appliedRevision = nil; undo.removeAll(); touches.removeAll()
        self.scene = scene
    }
    /// A revoked server visit cannot be reused. This does not renew the local
    /// visit deadline, clear user choices, or reset its bounded patch budget.
    func renewServerContext() {
        guard isCurrent, let scene else { return }
        advance(scene, renewServerVisit: true)
    }
    func trackChanged(mood: String?, occurrence: String?, renewServerVisit: Bool = false) {
        guard Self.validOccurrence(occurrence) else { revoke(); return }
        // A playback change may arrive before a qualified server occurrence.
        // Still refresh the autonomous scene, retaining only visit-wide fields.
        guard isCurrent, let ticket, ticket.occurrence != occurrence || occurrence == nil || renewServerVisit else { return }
        salt &+= 0x9e3779b97f4a7c15
        let next = VibeScapeScene.autonomous(mood: mood, salt: salt, family: scene?.family ?? .neutral)
        autonomous = next; trackPatch = nil; undo.removeAll(); touches.removeAll()
        trackIntensity = nil
        if dynamicsScope == .currentTrack, let held = visitDynamics {
            dynamics = held; followsTrackIntensity = false; dynamicsScope = .continuousVisit
        } else if followsTrackIntensity || dynamicsScope == .currentTrack {
            dynamics = 0.5; followsTrackIntensity = true; dynamicsScope = nil
        }
        touchExpiryTask?.cancel(); touchExpiryTask = nil
        // Voice cancellation revokes the old server visit. Rotate its client
        // identifier without renewing the local lifetime or dropping held fields.
        self.ticket = VibeScapeRenderTicket(visit: renewServerVisit ? UUID() : ticket.visit,
            occurrence: occurrence, revision: ticket.revision + 1)
        scene = persistentPatch?.applied(to: next) ?? next; appliedRevision = nil
    }
    /// Consume the already confirmed Session projection, never a pending button.
    /// Revisions and conflicts cannot roll the visual world back during A→B→A.
    @discardableResult func personaChanged(family: VibeScapeFamily, revision: Int?, floor: Int?, conflicted: Bool,
                                         mood: String?) -> Bool {
        guard isCurrent, let current = scene else { return false }
        if let floor, floor > personaFloor { personaFloor = floor; familyAtFloor = nil; personaConflict = false }
        var accepted = family
        if conflicted { personaConflict = true; accepted = .neutral }
        if accepted != .neutral {
            guard let revision, revision >= personaFloor,
                  !personaConflict || revision > personaFloor else { return false }
            if revision == personaFloor, let known = familyAtFloor, known != accepted {
                personaConflict = true; accepted = .neutral
            } else {
                if revision > personaFloor { personaConflict = false }
                personaFloor = revision; familyAtFloor = accepted
            }
        }
        let nextRevision = accepted == .neutral ? nil : revision
        guard current.family != accepted || personaRevision != nextRevision else { return false }
        personaRevision = nextRevision
        salt &+= 0x9e3779b97f4a7c15
        var next = VibeScapeScene.autonomous(mood: accepted == .neutral ? nil : mood, salt: salt, family: accepted)
        autonomous = next
        // A colour preference is portable. Topology/material/depth masks and
        // undo from a previous character cannot reinstate that old character.
        if accepted != .neutral {
            persistentPatch = persistentPatch?.palette.map { VibeScapePatch(palette: $0, scope: .continuousVisit) }
            trackPatch = trackPatch?.palette.map { VibeScapePatch(palette: $0, scope: .currentTrack) }
            if let persistentPatch { next = persistentPatch.applied(to: next) }
            if let trackPatch { next = trackPatch.applied(to: next) }
        } else { persistentPatch = nil; trackPatch = nil }
        undo.removeAll(); touches.removeAll()
        touchExpiryTask?.cancel(); touchExpiryTask = nil
        advance(next, renewServerVisit: true)
        return true
    }
    private static func validOccurrence(_ value: String?) -> Bool {
        value.map { !$0.isEmpty && $0.utf8.count <= 256 } ?? true
    }
    @discardableResult func rendererCompleted(_ expected: VibeScapeRenderTicket) -> Bool {
        guard admitted(expected) else { return false }
        appliedRevision = expected.revision; return true
    }
    func revoke() {
        lifetimeID = nil
        scene = nil; ticket = nil; autonomous = nil; persistentPatch = nil; trackPatch = nil
        undo.removeAll(keepingCapacity: false); dynamics = 0.5; appliedRevision = nil
        followsTrackIntensity = true; trackIntensity = nil; dynamicsScope = nil; visitDynamics = nil
        personaRevision = nil; personaFloor = -1; familyAtFloor = nil; personaConflict = false
        touches.removeAll(keepingCapacity: false)
        touchExpiryTask?.cancel(); touchExpiryTask = nil
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
            if self.visitID != self.visit.lifetimeID {
                self.cancel(); self.visitID = self.visit.lifetimeID; self.attempts = 0
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
        if visitID != visit.lifetimeID { visitID = visit.lifetimeID; attempts = 0 }
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
