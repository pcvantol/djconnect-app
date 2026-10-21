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
        for _ in 0..<32 { #expect(visit.apply(VibeScapePatch(depth:0.2),expected:try #require(visit.ticket))) }
        #expect(!visit.apply(VibeScapePatch(depth:0.3),expected:try #require(visit.ticket)))
        time = 1811
        #expect(!visit.rendererCompleted(try #require(visit.ticket)))
        #expect(!visit.setDynamics(0.4))
    }
    @Test func absentOccurrenceCannotAuthorizeInterpretedPatches() throws {
        let visit = VisualDirectorVisit(); visit.enter(mood:"chill",occurrence:nil,salt:0)
        #expect(!visit.apply(VibeScapePatch(depth:1),expected:try #require(visit.ticket)))
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
