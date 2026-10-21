import Testing
import Foundation
import DJConnectCore
@testable import DJConnectUI

@Suite @MainActor struct VibeScapeVisitTests {
    @Test func patchesPreserveFieldsAndRequireActualRendererAcknowledgment() throws {
        let visit = VisualDirectorVisit()
        visit.enter(mood:"chill",occurrence:"track-A",salt:12)
        let initial = try #require(visit.scene)
        let old = try #require(visit.ticket)
        #expect(visit.apply(VibeScapePatch(motion:0.1),expected:old))
        #expect(visit.scene?.palette == initial.palette)
        #expect(visit.appliedRevision == nil)
        #expect(!visit.rendererCompleted(old))
        let calm = try #require(visit.ticket)
        #expect(visit.apply(VibeScapePatch(palette:SIMD3(0.9,0.7,0.2)),expected:calm))
        #expect(visit.scene?.motion == 0.1)
        #expect(!visit.apply(VibeScapePatch(depth:0.8),expected:calm))
        #expect(visit.rendererCompleted(try #require(visit.ticket)))
        #expect(visit.appliedRevision == visit.ticket?.revision)
    }
    @Test func trackScopeUndoAndReset() throws {
        let visit = VisualDirectorVisit(); visit.enter(mood:"groove",occurrence:"A",salt:1)
        #expect(visit.apply(VibeScapePatch(depth:0.9,scope:.continuousVisit),expected:try #require(visit.ticket)))
        #expect(visit.apply(VibeScapePatch(motion:0.01),expected:try #require(visit.ticket)))
        let stale = try #require(visit.ticket)
        visit.trackChanged(mood:"groove",occurrence:"B")
        #expect(visit.scene?.depth == 0.9)
        #expect(visit.scene?.motion != 0.01)
        #expect(!visit.rendererCompleted(stale))
        #expect(!visit.undoLast(expected:try #require(visit.ticket)))
        let before = visit.scene
        #expect(visit.apply(VibeScapePatch(roughness:0.8),expected:try #require(visit.ticket)))
        #expect(visit.undoLast(expected:try #require(visit.ticket)))
        #expect(visit.scene == before)
        #expect(visit.resetToDJ(expected:try #require(visit.ticket)))
        #expect(visit.scene?.depth != 0.9)
    }
    @Test func revokedVisitCannotBeResurrectedAndReentryIsFresh() throws {
        let visit = VisualDirectorVisit(); visit.enter(mood:"party",occurrence:"A",salt:1)
        let stale = try #require(visit.ticket)
        visit.revoke()
        #expect(visit.scene == nil && visit.ticket == nil && visit.appliedRevision == nil)
        #expect(!visit.apply(VibeScapePatch(depth:1),expected:stale))
        #expect(!visit.rendererCompleted(stale))
        #expect(!visit.setDynamics(1))
        visit.enter(mood:"party",occurrence:"A",salt:2)
        #expect(visit.ticket?.visit != stale.visit)
        #expect(!visit.rendererCompleted(stale))
        #expect(visit.dynamics == 0.5)
    }
    @Test func invalidUnboundedAndExpiredChangesAreNoEffect() throws {
        let visit = VisualDirectorVisit()
        var time: TimeInterval = 10
        visit.now = { time }; visit.enter(mood:nil,occurrence:"qualified-fixture",salt:0)
        let start = try #require(visit.ticket); let original = visit.scene
        for patch in [VibeScapePatch(motion:.nan),VibeScapePatch(depth:1.01),VibeScapePatch(palette:SIMD3(-0.1,0,0)),VibeScapePatch()] {
            #expect(!visit.apply(patch,expected:start))
            #expect(visit.scene == original)
        }
        #expect(!visit.setDynamics(.infinity))
        for n in 0..<32 { #expect(visit.apply(VibeScapePatch(depth:n.isMultiple(of:2) ? 0.2 : 0.3),expected:try #require(visit.ticket))) }
        #expect(!visit.apply(VibeScapePatch(depth:0.4),expected:try #require(visit.ticket)))
        time = 1811
        #expect(!visit.rendererCompleted(try #require(visit.ticket)))
        #expect(!visit.setDynamics(0.4))
    }
    @Test func absentOccurrenceCannotAuthorizeInterpretedPatches() throws {
        let visit = VisualDirectorVisit(); visit.enter(mood:"chill",occurrence:nil,salt:0)
        #expect(!visit.apply(VibeScapePatch(depth:1),expected:try #require(visit.ticket)))
        #expect(!visit.holdExplicitStyle(expected:try #require(visit.ticket)))
        #expect(!visit.varyComposition(expected:try #require(visit.ticket)))
        #expect(!visit.resetToDJ(expected:try #require(visit.ticket)))
        #expect(visit.setDynamics(0.2)) // Local slider is not a server directive.
        visit.enter(mood:nil,occurrence:String(repeating:"a",count:257))
        #expect(visit.scene == nil && visit.ticket == nil)
    }
    @Test(arguments: ["",String(repeating:"a",count:257),String(repeating:"🎵",count:65)])
    func invalidTrackOccurrenceRevokesInsteadOfRetainingOrAcknowledging(_ invalid: String) throws {
        let visit = VisualDirectorVisit(); visit.enter(mood:"chill",occurrence:"A",salt:1)
        let old = try #require(visit.ticket)
        visit.trackChanged(mood:"party",occurrence:invalid)
        #expect(visit.scene == nil && visit.ticket == nil)
        #expect(!visit.rendererCompleted(old))
        #expect(!visit.apply(VibeScapePatch(depth:0.9),expected:old))
    }
    @Test func twentyTrackCompositionsAndRepeatedPlaybackVaryWithoutInventedMusicFacts() {
        let visit = VisualDirectorVisit(); visit.enter(mood:"groove",occurrence:"0",salt:10)
        var scenes: [VibeScapeScene] = []
        for n in 0..<20 {
            visit.trackChanged(mood:n < 10 ? "groove" : "chill",occurrence:String(n))
            if let scene = visit.scene { scenes.append(scene) }
        }
        #expect(scenes.count == 20)
        for n in 1..<scenes.count { #expect(scenes[n].composition != scenes[n-1].composition) }
        let first = VibeScapeScene.autonomous(mood:"groove",salt:1)
        let replay = VibeScapeScene.autonomous(mood:"groove",salt:2)
        #expect(first.composition != replay.composition)
    }
    @Test func visibleVisualsCannotFallThroughToGeneralAskDJOrRecording() throws {
        let name = "vibescape-negative-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName:name))
        defer { defaults.removePersistentDomain(forName:name) }
        let model = DJConnectAppModel(defaults:defaults,tokenStore:DJConnectInMemoryTokenStore(),startBackgroundTasks:false)
        model.isDemoMode = true
        let originalMessages = model.askDJMessages
        let originalDefaults = defaults.persistentDomain(forName:name) as NSDictionary?
        model.isShowingVibeScape = true
        for utterance in ["Speel Pink Floyd","zet het harder","welke artiest is dit?","meer goud"] {
            model.askDJDraft = utterance
            model.sendAskDJText()
            #expect(model.askDJDraft == utterance)
        }
        model.startVoiceRecording()
        model.stopVoiceRecordingAndUpload()
        #expect(!model.isRecordingVoice && !model.isSendingAskDJText)
        #expect(!model.canUseAskDJFeatures)
        #expect(model.askDJMessages == originalMessages)
        #expect((defaults.persistentDomain(forName:name) as NSDictionary?) == originalDefaults)
        model.isShowingVibeScape = false
    }
}

@Suite @MainActor struct VibeScapeStyleStateTests {
    @Test func fourTurnCorrectionHoldAndTrackHandoverRetainOnlyExplicitStyle() throws {
        let visit = VisualDirectorVisit(); visit.enter(mood:"groove",occurrence:"A",salt:7)
        let identity = try #require(visit.ticket).visit
        let baseline = try #require(visit.scene)
        #expect(visit.apply(VibeScapePatch(motion:0.1),expected:try #require(visit.ticket)))
        #expect(visit.apply(VibeScapePatch(palette:SIMD3(0.9,0.7,0.2)),expected:try #require(visit.ticket)))
        let corrected = SIMD3<Float>(0.6,0.7,0.3)
        #expect(visit.apply(VibeScapePatch(palette:corrected,depth:0.9),expected:try #require(visit.ticket)))
        #expect(visit.holdExplicitStyle(expected:try #require(visit.ticket)))
        visit.trackChanged(mood:"groove",occurrence:"B")
        #expect(visit.ticket?.visit == identity)
        #expect(visit.scene?.palette == corrected && visit.scene?.motion == 0.1 && visit.scene?.depth == 0.9)
        #expect(visit.scene?.roughness != baseline.roughness || visit.scene?.deformation != baseline.deformation)
        #expect(visit.apply(VibeScapePatch(palette:SIMD3(0.1,0.3,0.8)),expected:try #require(visit.ticket)))
        visit.trackChanged(mood:"chill",occurrence:"C")
        #expect(visit.scene?.palette == corrected)
        #expect(visit.ticket?.visit == identity)
    }
    @Test func visitScopeSupersedesOldTrackFieldsWithoutPromotingBaseline() throws {
        let visit = VisualDirectorVisit(); visit.enter(mood:"chill",occurrence:"A",salt:8)
        #expect(visit.apply(VibeScapePatch(palette:SIMD3(0.1,0.2,0.9)),expected:try #require(visit.ticket)))
        let gold = SIMD3<Float>(0.9,0.7,0.2)
        #expect(visit.apply(VibeScapePatch(palette:gold,scope:.continuousVisit),expected:try #require(visit.ticket)))
        #expect(!visit.holdExplicitStyle(expected:try #require(visit.ticket)))
        visit.trackChanged(mood:"party",occurrence:"B")
        #expect(visit.scene?.palette == gold)
        #expect(visit.scene?.motion == 0.3)
        #expect(visit.resetToDJ(expected:try #require(visit.ticket)))
        #expect(visit.scene?.palette != gold)
    }
    @Test func undoHoldRestoresTrackScopeRatherThanKeepingPromotedFields() throws {
        let visit = VisualDirectorVisit(); visit.enter(mood:"groove",occurrence:"A",salt:9)
        #expect(visit.apply(VibeScapePatch(motion:0.1),expected:try #require(visit.ticket)))
        #expect(visit.holdExplicitStyle(expected:try #require(visit.ticket)))
        #expect(visit.undoLast(expected:try #require(visit.ticket)))
        #expect(visit.scene?.motion == 0.1)
        visit.trackChanged(mood:"groove",occurrence:"B")
        #expect(visit.scene?.motion == 0.3)
    }
    @Test func variantChangesOnlyCompositionAndUndoRestoresOriginalDJBaseline() throws {
        let visit = VisualDirectorVisit(); visit.enter(mood:"party",occurrence:"A",salt:91)
        let baseline = try #require(visit.scene)
        #expect(visit.apply(VibeScapePatch(palette:SIMD3(0.9,0.7,0.2),motion:0.1),expected:try #require(visit.ticket)))
        #expect(visit.setDynamics(0.8))
        let styled = try #require(visit.scene)
        let old = try #require(visit.ticket)
        #expect(visit.varyComposition(expected:old))
        #expect(visit.scene?.composition != styled.composition)
        #expect(visit.scene?.palette == styled.palette && visit.scene?.motion == styled.motion)
        #expect(visit.scene?.roughness == styled.roughness && visit.dynamics == 0.8)
        #expect(visit.appliedRevision == nil && !visit.rendererCompleted(old))
        #expect(visit.undoLast(expected:try #require(visit.ticket)))
        #expect(visit.scene == styled && visit.dynamics == 0.8)
        #expect(visit.resetToDJ(expected:try #require(visit.ticket)))
        #expect(visit.scene == baseline && visit.dynamics == 0.5)
    }
    @Test func noEffectDoesNotCreateNewRevisionOrEarnAppliedAcknowledgment() throws {
        let visit = VisualDirectorVisit(); visit.enter(mood:"groove",occurrence:"A",salt:10)
        let initial = try #require(visit.ticket)
        #expect(!visit.holdExplicitStyle(expected:initial))
        #expect(!visit.resetToDJ(expected:initial))
        #expect(!visit.setDynamics(0.5))
        #expect(visit.ticket == initial)
        // An equal value can still establish an explicit scope constraint once.
        let motion = try #require(visit.scene).motion
        #expect(visit.apply(VibeScapePatch(motion:motion),expected:initial))
        let explicit = try #require(visit.ticket)
        #expect(!visit.apply(VibeScapePatch(motion:motion),expected:explicit))
        #expect(visit.ticket == explicit && visit.appliedRevision == nil)
    }
    @Test func variantAndHoldRespectOriginalVisitBudgetAndRevocation() throws {
        let visit = VisualDirectorVisit(); visit.enter(mood:"chill",occurrence:"A",salt:11)
        for _ in 0..<32 { #expect(visit.varyComposition(expected:try #require(visit.ticket))) }
        let exhausted = try #require(visit.ticket)
        #expect(!visit.varyComposition(expected:exhausted))
        visit.revoke()
        #expect(!visit.holdExplicitStyle(expected:exhausted))
        #expect(!visit.varyComposition(expected:exhausted))
    }
}


@Suite @MainActor struct VibeScapeTurnFenceTests {
    @Test func cancelledTurnCannotReplaceNewTurnAtSameSceneRevision() throws {
        let visit = VisualDirectorVisit(); visit.enter(mood:"groove",occurrence:"A",salt:1)
        let fence = VisualDirectorTurnFence(visit:visit)
        let old = try #require(fence.begin(originalSourceDeadline:visit.now()+10,isCurrent:{true}))
        fence.cancel()
        let next = try #require(fence.begin(originalSourceDeadline:visit.now()+10,isCurrent:{true}))
        #expect(old.scene == next.scene && old.id != next.id)
        var applications = 0
        #expect(!fence.complete(old) { applications += 1; return true })
        #expect(fence.complete(next) { applications += 1; return true })
        #expect(!fence.complete(next) { applications += 1; return true })
        #expect(applications == 1)
        #expect(visit.appliedRevision == nil) // Interpretation is not GPU ACK.
    }
    @Test func originalLeaseCannotBeExtendedByLaterContextOrClockRollback() throws {
        let visit = VisualDirectorVisit(); var time:TimeInterval = 100
        visit.now = {time}; visit.enter(mood:nil,occurrence:"A",salt:1)
        let fence = VisualDirectorTurnFence(visit:visit)
        let old = try #require(fence.begin(originalSourceDeadline:105,isCurrent:{true}))
        time = 106
        let fresh = try #require(fence.begin(originalSourceDeadline:200,isCurrent:{true}))
        #expect(fresh.deadline == 136)
        #expect(!fence.complete(old) { Issue.record("Expired source renewed"); return true })
        time = 99
        #expect(!fence.complete(fresh) { Issue.record("Clock rollback accepted"); return true })
    }
    @Test func sceneChangeRevokeAndOwnerLossPreventCallback() throws {
        let visit = VisualDirectorVisit(); visit.enter(mood:nil,occurrence:"A",salt:1)
        let fence = VisualDirectorTurnFence(visit:visit)
        var owner = true
        let old = try #require(fence.begin(originalSourceDeadline:visit.now()+10,isCurrent:{owner}))
        _ = visit.setDynamics(0.2)
        #expect(!fence.complete(old) { Issue.record("Old revision applied"); return true })
        let next = try #require(fence.begin(originalSourceDeadline:visit.now()+10,isCurrent:{owner}))
        owner = false
        #expect(!fence.complete(next) { Issue.record("Revoked owner applied"); return true })
        owner = true
        let last = try #require(fence.begin(originalSourceDeadline:visit.now()+10,isCurrent:{owner}))
        visit.revoke()
        #expect(!fence.complete(last) { Issue.record("Exited visit applied"); return true })
    }
    @Test func rejectedOrCancelledTurnsConsumeBoundedAttemptBudget() throws {
        let visit = VisualDirectorVisit(); visit.enter(mood:nil,occurrence:"A",salt:1)
        let fence = VisualDirectorTurnFence(visit:visit)
        for _ in 0..<32 {
            _ = try #require(fence.begin(originalSourceDeadline:visit.now()+10,isCurrent:{true}))
            #expect(fence.begin(originalSourceDeadline:visit.now()+10,isCurrent:{true}) == nil)
            fence.cancel()
        }
        #expect(fence.begin(originalSourceDeadline:visit.now()+10,isCurrent:{true}) == nil)
        visit.trackChanged(mood:nil,occurrence:"B")
        #expect(fence.begin(originalSourceDeadline:visit.now()+10,isCurrent:{true}) == nil)
        visit.enter(mood:nil,occurrence:"B",salt:2)
        #expect(fence.begin(originalSourceDeadline:visit.now()+10,isCurrent:{true}) != nil)
        fence.cancel()
    }
    @Test func exitImmediatelyReleasesCapturedOriginalContext() throws {
        final class Context {}
        let visit = VisualDirectorVisit(); visit.enter(mood:nil,occurrence:"A",salt:1)
        let fence = VisualDirectorTurnFence(visit:visit)
        var context: Context? = Context()
        weak var retained = context
        let turn = fence.begin(originalSourceDeadline:visit.now()+10,isCurrent:{ [context] in context != nil })
        _ = try #require(turn)
        context = nil
        #expect(retained != nil)
        visit.revoke()
        #expect(retained == nil)
    }
    @Test func unknownOccurrenceOrInvalidSourceDeadlineCannotStart() {
        let visit = VisualDirectorVisit(); visit.enter(mood:nil,occurrence:nil,salt:1)
        let fence = VisualDirectorTurnFence(visit:visit)
        #expect(fence.begin(originalSourceDeadline:visit.now()+10,isCurrent:{true}) == nil)
        visit.enter(mood:nil,occurrence:"A",salt:1)
        for deadline in [TimeInterval.nan,.infinity,visit.now()-1] {
            #expect(fence.begin(originalSourceDeadline:deadline,isCurrent:{true}) == nil)
        }
        #expect(fence.begin(originalSourceDeadline:visit.now()+10,isCurrent:{false}) == nil)
    }
}
