import Foundation
import Testing
import simd
@testable import DJConnectCore
@testable import DJConnectUI

private let worlds: [VibeScapeFamily] = [.home, .radio, .club, .festival]

@Test(arguments: worlds, ["chill", "groove", "energy", "party"])
func visualWorldHasRelativeDynamicsAtAllThreePositions(_ family: VibeScapeFamily, _ mood: String) {
    let scene = VibeScapeScene.autonomous(mood: mood, salt: 710, family: family)
    #expect(scene.family == family && scene.motion > 0)
    let middle = VibeScapeDynamics.sample(0.5, family: family)
    #expect(middle == .init(speed: 1, excursion: 1, evolution: 1, parallax: 1, complexity: 1))
    let low = VibeScapeDynamics.sample(0, family: family), high = VibeScapeDynamics.sample(1, family: family)
    #expect(low.speed > 0 && low.speed < middle.speed && high.speed > middle.speed && high.speed <= 2.3)
    #expect(low.excursion > 0 && high.excursion > low.excursion && high.excursion <= 2)
    #expect(low.complexity > 0 && high.complexity <= 2)
    let colors = DJConnectSessionMoodTheme(sessionMood: mood).colorValues
    let first = colors[0]
    #expect(scene.palette == SIMD3(Float((first >> 16) & 255), Float((first >> 8) & 255), Float(first & 255)) / 255)
}

@Test(arguments: worlds)
func sceneVariationRetainsItsFamilyAcrossTwentySyntheticOccurrenceInputs(_ family: VibeScapeFamily) {
    let scenes = (0..<20).map { VibeScapeScene.autonomous(mood: "groove", salt: UInt64(812 + $0), family: family) }
    #expect(scenes.allSatisfy { $0.family == family })
    #expect(Set(scenes.map { $0.composition }).count == 20)
    #expect(scenes.allSatisfy { $0.palette == scenes[0].palette })
}

@Test(arguments: worlds)
func dynamicsSweepIntegratesPhaseWithoutElapsedTimeReanchoring(_ family: VibeScapeFamily) {
    var state = VibeScapeAnimationState()
    let scene = VibeScapeScene.autonomous(mood: "groove", salt: 812, family: family)
    var prior = state.update(target: scene, dynamics: 0.5, at: 0, reduceMotion: false)
    for tick in 1...1200 {
        let dynamics = tick < 600 ? Float(tick % 200) / 199 : 0.2
        let next = state.update(target: scene, dynamics: dynamics, at: Double(tick) / 60, reduceMotion: false)
        let index = Int(family.rawValue)
        let delta = next.phases[index] - prior.phases[index]
        #expect(delta >= 0 && delta < 0.03)
        #expect(next.dynamics.isFinite && (0...1).contains(next.dynamics))
        prior = next
    }
    state.pause()
    let resume = state.update(target: scene, dynamics: 0.2, at: 300, reduceMotion: false)
    #expect(resume.phases == prior.phases)
    let staticFrame = state.update(target: scene, dynamics: 1, at: 301, reduceMotion: true)
    #expect(staticFrame.phases == resume.phases && staticFrame.dynamics == 1)
}

@Test func interruptedWorldTransitionsKeepTheVisibleMixtureAndWithdrawNeutralImmediately() {
    var state = VibeScapeAnimationState()
    var scene = VibeScapeScene.autonomous(mood: "chill", salt: 900, family: .home)
    var frame = state.update(target: scene, dynamics: 0.5, at: 0, reduceMotion: false)
    #expect(frame.weights.x == 1)
    for (index, family) in [VibeScapeFamily.radio, .club, .festival, .home].enumerated() {
        scene = .autonomous(mood: "chill", salt: UInt64(910 + index), family: family)
        let before = frame.weights
        frame = state.update(target: scene, dynamics: 0.5, at: Double(index + 1) / 60, reduceMotion: false)
        #expect(simd_distance(frame.weights, before) < 0.12)
        #expect(abs(simd_reduce_add(frame.weights) - 1) < 0.001)
    }
    scene = .autonomous(mood: nil, salt: 1, family: .neutral)
    frame = state.update(target: scene, dynamics: 0.5, at: 1, reduceMotion: false)
    #expect(frame.weights == .zero && frame.home.family == .neutral && frame.radio.family == .neutral)
}

@Test(.isolatedClientResources) @MainActor
func confirmedPersonaRevisionsFenceUndoVoiceAndABAWithoutChangingManualBias() throws {
    let visit = VisualDirectorVisit()
    visit.enter(mood: "chill", occurrence: "fixture-occurrence", salt: 800, family: .home, personaRevision: 1)
    #expect(visit.setDynamics(0.2))
    let voice = try #require(visit.ticket)
    #expect(visit.personaChanged(family: .radio, revision: 2, floor: 2, conflicted: false, mood: "chill"))
    #expect(visit.scene?.family == .radio && visit.dynamics == 0.2)
    #expect(!visit.apply(.init(palette: SIMD3(1, 0, 0)), expected: voice))
    #expect(!visit.personaChanged(family: .home, revision: 1, floor: 1, conflicted: false, mood: "chill"))
    #expect(visit.scene?.family == .radio)
    #expect(visit.personaChanged(family: .home, revision: 3, floor: 3, conflicted: false, mood: "chill"))
    #expect(!visit.undoLast(expected: try #require(visit.ticket)))
    #expect(visit.scene?.family == .home && visit.dynamics == 0.2)
    #expect(visit.personaChanged(family: .club, revision: 3, floor: 3, conflicted: false, mood: "chill"))
    #expect(visit.scene?.family == .neutral)
    #expect(!visit.personaChanged(family: .home, revision: 3, floor: 3, conflicted: false, mood: "chill"))
    #expect(visit.personaChanged(family: .festival, revision: 4, floor: 4, conflicted: false, mood: "chill"))
    #expect(visit.scene?.family == .festival && visit.dynamics == 0.2)
    visit.revoke()
    #expect(!visit.personaChanged(family: .home, revision: 5, floor: 5, conflicted: false, mood: "party"))
}

@Test(.isolatedClientResources) @MainActor
func visualVoiceAndSliderShareOneRelativeBiasAndNewGestureWins() throws {
    let visit = VisualDirectorVisit()
    visit.enter(mood: "groove", occurrence: "synthetic-A", family: .radio, personaRevision: 1)
    let baseline = try #require(visit.scene).motion
    let old = try #require(visit.ticket)
    visit.beginDynamicsAdjustment()
    #expect(!visit.apply(.init(motion: 0.1), expected: old))
    #expect(visit.setDynamics(0.8))
    #expect(visit.apply(.init(motion: 0.2), expected: try #require(visit.ticket)))
    #expect(visit.dynamics == 0.2 && visit.scene?.motion == baseline)
    #expect(visit.apply(.init(depth: 0.9), expected: try #require(visit.ticket)))
    #expect(visit.dynamics == 0.2 && visit.scene?.motion == baseline)
    visit.trackChanged(mood: "groove", occurrence: "synthetic-replay-A")
    #expect(visit.dynamics == 0.8 && !visit.followsTrackIntensity) // Temporary speech expires back to the held slider choice.
    #expect(visit.setDynamics(0.2))
    let composition = visit.scene?.composition
    let lifetime = visit.lifetimeID
    visit.invalidateOccurrence()
    #expect(visit.ticket?.occurrence == nil && visit.scene?.composition == composition)
    #expect(!visit.apply(.init(depth: 0.8), expected: try #require(visit.ticket)))
    visit.trackChanged(mood: "party", occurrence: "synthetic-next")
    visit.moodChanged("chill")
    #expect(visit.dynamics == 0.2 && visit.scene?.family == .radio)
    #expect(visit.personaChanged(family: .festival, revision: 2, floor: 2, conflicted: false, mood: "chill"))
    #expect(visit.dynamics == 0.2 && visit.lifetimeID == lifetime)
    visit.renewServerContext()
    #expect(visit.lifetimeID == lifetime)
    visit.followTrackIntensity()
    #expect(visit.dynamics == 0.5 && visit.followsTrackIntensity)
}

@Test func visualQualityBudgetHasHysteresisIndependentOfDynamics() {
    var budget = VibeScapeQualityBudget()
    for value in [Double.nan, .infinity, -1, 0, 1000] { budget.observe(milliseconds: value) }
    #expect(!budget.prefersReducedQuality && budget.averageMilliseconds == 0)
    for _ in 0..<7 { budget.observe(milliseconds: 25) }
    #expect(!budget.prefersReducedQuality)
    budget.observe(milliseconds: 25)
    #expect(budget.prefersReducedQuality)
    for _ in 0..<179 { budget.observe(milliseconds: 3) }
    #expect(budget.prefersReducedQuality)
    for _ in 0..<60 { budget.observe(milliseconds: 3) }
    #expect(!budget.prefersReducedQuality)
}

@Test(.isolatedClientResources) @MainActor
func neutralAuthorityCannotApplyAnInvisibleDirective() throws {
    let visit = VisualDirectorVisit()
    visit.enter(mood: nil, occurrence: "synthetic-context", family: .neutral)
    let ticket = try #require(visit.ticket)
    #expect(!visit.apply(.init(motion: 0.2, depth: 0.9), expected: ticket))
    #expect(!visit.varyComposition(expected: ticket))
    #expect(!visit.nudge(at: .init(0.5, 0.5), aspect: 1))
    #expect(visit.ticket == ticket && visit.appliedRevision == nil)
    #expect(visit.setDynamics(0.2)) // Local bias can be prepared without character authority.
    let local = try #require(visit.ticket)
    #expect(!visit.resetToDJ(expected: local))
    #expect(!visit.holdExplicitStyle(expected: local))
    #expect(!visit.undoLast(expected: local))
    #expect(visit.ticket == local && visit.appliedRevision == nil)
}

@Test(.isolatedClientResources) @MainActor
func temporarySpokenDynamicsRestoresTheVisitChoiceAndHoldUndoKeepsItsScope() throws {
    let visit = VisualDirectorVisit()
    visit.enter(mood: "groove", occurrence: "synthetic-A", family: .radio, personaRevision: 1)
    #expect(visit.setDynamics(0.8))
    #expect(visit.apply(.init(motion: 0.2), expected: try #require(visit.ticket)))
    #expect(visit.dynamics == 0.2)
    visit.moodChanged("chill")
    #expect(visit.personaChanged(family: .club, revision: 2, floor: 2, conflicted: false, mood: "chill"))
    #expect(visit.dynamics == 0.2)
    visit.trackChanged(mood: "chill", occurrence: "synthetic-B")
    #expect(visit.dynamics == 0.8 && !visit.followsTrackIntensity)
    #expect(visit.apply(.init(motion: 0.3, scope: .continuousVisit), expected: try #require(visit.ticket)))
    #expect(visit.apply(.init(motion: 0.1), expected: try #require(visit.ticket)))
    #expect(visit.holdExplicitStyle(expected: try #require(visit.ticket)))
    #expect(visit.undoLast(expected: try #require(visit.ticket)))
    visit.trackChanged(mood: "chill", occurrence: "synthetic-C")
    #expect(visit.dynamics == 0.3 && !visit.followsTrackIntensity)
    #expect(visit.apply(.init(motion: 0.1), expected: try #require(visit.ticket)))
    #expect(visit.setDynamics(0.6)) // A newer direct choice replaces the track override.
    visit.trackChanged(mood: "chill", occurrence: "synthetic-D")
    #expect(visit.dynamics == 0.6)
    visit.followTrackIntensity()
    visit.trackChanged(mood: "chill", occurrence: "synthetic-E")
    #expect(visit.dynamics == 0.5 && visit.followsTrackIntensity)
    visit.revoke()
    visit.enter(mood: "chill", occurrence: "synthetic-F", family: .home, personaRevision: 3)
    #expect(visit.dynamics == 0.5 && visit.followsTrackIntensity)
}
