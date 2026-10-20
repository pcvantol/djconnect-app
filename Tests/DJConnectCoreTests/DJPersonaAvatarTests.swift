import DJConnectCore
import Testing
import SwiftUI
@testable import DJConnectUI
#if os(macOS)
import AppKit
#endif

@Test(arguments: [CGFloat(16), CGFloat(20), CGFloat(24), CGFloat(80)])
func personaMarkRemainsWithinSquareAndWideIconBounds(size: CGFloat) {
    for rect in [CGRect(x: 0, y: 0, width: size, height: size), CGRect(x: 3, y: 5, width: size * 2, height: size)] {
        let path = DJPersonaMark().path(in: rect)
        #expect(!path.isEmpty)
        #expect(rect.contains(path.boundingRect))
        #expect(path.boundingRect.width > size * 0.8)
        #expect(path.boundingRect.height > size * 0.6)
    }
}

#if os(macOS)
@Test @MainActor func personaNativeRenderingSupportsMoodAccessibilityAndMenuSizes() throws {
    let preview = VStack(alignment: .leading, spacing: 24) {
        HStack(spacing: 24) {
            ForEach(["brand", "chill", "groove", "energy", "party"], id: \.self) { mood in
                VStack {
                    DJPersonaAvatarView(confirmedMood: mood, language: "nl").frame(width: 80, height: 80)
                    Text(mood).font(.caption)
                }
            }
        }
        HStack(spacing: 24) {
            ForEach([CGFloat(16), 20, 24], id: \.self) { size in
                DJPersonaMark().fill(.white).frame(width: size, height: size)
            }
            DJConnectFeatureSymbols.image(DJConnectFeatureSymbols.djSession)
            DJConnectFeatureSymbols.image("music.note")
            Text("Statisch menu / verhoogd contrast").font(.caption)
            DJPersonaGraphic(colors: [.blue, .purple, .pink], highContrast: true, opaque: true)
                .frame(width: 80, height: 80)
        }
    }
    .foregroundStyle(.white).padding(24)
    .background(Color(red: 0.07, green: 0.06, blue: 0.20))
    let renderer = ImageRenderer(content: preview)
    renderer.scale = 2
    let image = try #require(renderer.nsImage)
    let tiff = try #require(image.tiffRepresentation)
    let rep = try #require(NSBitmapImageRep(data: tiff))
    let png = try #require(rep.representation(using: .png, properties: [:]))
    #expect(image.size.width > 400 && image.size.height > 160)
    #expect(png.count > 1000)
    if let directory = ProcessInfo.processInfo.environment["DJCONNECT_AVATAR_ARTIFACT_DIR"] {
        let folder = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try png.write(to: folder.appendingPathComponent("session-pulse-native-preview.png"))
    }
}
#endif

#if os(macOS)
@Test(arguments: ["moment", "quiet", "paused", "recovering", "unavailable"], [CGFloat(320), CGFloat(620)])
@MainActor func personaCurrentCardRenderingRetainsEveryState(state: String, width: CGFloat) throws {
    var session = try DJConnectDemoSessionData.make(language: "nl").active
    if state == "quiet" { session.broadcast.djMoments = [] }
    if state == "paused" { session.broadcast.playback?.state = "paused" }
    let current = NativeSessionMomentsView(session: session, language: "nl", isRecovering: state == "recovering", isLiveUnavailable: state == "unavailable")
    let moment = state == "quiet" ? nil : session.broadcast.djMoments.first
    if state == "moment" { #expect(moment != nil) }
    let view = current.currentCard(moment)
        .environment(\.djConnectGlassEffectsEnabled, false)
        .frame(width: width).padding(20)
        .foregroundStyle(.white).background(Color(red: 0.07, green: 0.06, blue: 0.20))
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    let image = try #require(renderer.nsImage)
    let tiff = try #require(image.tiffRepresentation)
    let rep = try #require(NSBitmapImageRep(data: tiff))
    let png = try #require(rep.representation(using: .png, properties: [:]))
    #expect(image.size.width == width + 40)
    // The compact side-by-side card must still fit the avatar and its insets.
    #expect(image.size.height >= 168)
    if let directory = ProcessInfo.processInfo.environment["DJCONNECT_AVATAR_ARTIFACT_DIR"] {
        let folder = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try png.write(to: folder.appendingPathComponent("session-current-" + state + "-\(Int(width)).png"))
    }
}
#endif

@Test func personaActivityRequiresAuthorityAndActualOutput() {
    var evidence = DJPersonaActivity.Evidence()
    evidence.capturing = true; evidence.pending = true; evidence.speaking = true
    #expect(DJPersonaActivity.resolve(evidence) == .resting)
    evidence.authorized = true
    #expect(DJPersonaActivity.resolve(evidence) == .listening)
    evidence.capturing = false
    #expect(DJPersonaActivity.resolve(evidence) == .preparing)
    evidence.pending = false
    #expect(DJPersonaActivity.resolve(evidence) == .speaking)
    evidence.speaking = false
    #expect(DJPersonaActivity.resolve(evidence) == .resting)
}

@Test func personaCurrentAnnouncementDoesNotMaskNewExplicitInteraction() {
    var evidence = DJPersonaActivity.Evidence()
    evidence.authorized = true; evidence.announcementID = "old-moment"
    #expect(DJPersonaActivity.resolve(evidence) == .announcement)
    evidence.speaking = true; evidence.spokenMomentID = "old-moment"
    #expect(DJPersonaActivity.resolve(evidence) == .announcement)
    evidence.spokenMomentID = nil
    #expect(DJPersonaActivity.resolve(evidence) == .speaking)
    evidence.speaking = false; evidence.explicitReply = true
    #expect(DJPersonaActivity.resolve(evidence) == .text)
    evidence.pending = true
    #expect(DJPersonaActivity.resolve(evidence) == .preparing)
    evidence.capturing = true
    #expect(DJPersonaActivity.resolve(evidence) == .listening)
}

@Test func personaSilenceRestsUnlessActualInteractionHasPriority() {
    var evidence = DJPersonaActivity.Evidence()
    evidence.authorized = true
    #expect(DJPersonaActivity.resolve(evidence) == .resting)
    evidence.speaking = true
    #expect(DJPersonaActivity.resolve(evidence) == .speaking)
    evidence.speaking = false
    #expect(DJPersonaActivity.resolve(evidence) == .resting)
}

@Test func personaTrackStoryAloneIsNotAnAnnouncement() throws {
    var moment = try #require(DJConnectDemoSessionData.make(language: "nl").active.broadcast.djMoments.first)
    moment.type = "track"
    moment.knowledgeIntent = ["type": "track_context"]
    moment.generationMetadata = ["context_source": "observed_playback"]
    moment.sourceReferences = ["spotify_playback_status"]
    #expect(DJPersonaActivity.isObservedAnnouncement(moment))
    moment.sourceReferences.append("unqualified_source")
    #expect(!DJPersonaActivity.isObservedAnnouncement(moment))
    moment.sourceReferences = ["spotify_playback_status"]
    moment.generationMetadata = ["context_source": "track_story"]
    #expect(!DJPersonaActivity.isObservedAnnouncement(moment))
}

#if os(macOS)
@Test @MainActor func personaEveryActivityRendersInFixedGeometry() throws {
    let preview = HStack(spacing: 16) {
        ForEach(DJPersonaActivity.allCases, id: \.rawValue) { activity in
            VStack {
                DJPersonaGraphic(colors: [.blue, .purple, .pink], highContrast: false, opaque: false,
                                 activity: activity).frame(width: 80, height: 80)
                Text(activity.rawValue).font(.caption)
            }
        }
    }.padding(24).foregroundStyle(.white).background(Color.black)
    let renderer = ImageRenderer(content: preview)
    renderer.scale = 2
    let image = try #require(renderer.nsImage)
    #expect(image.size.width > 500)
    if let directory = ProcessInfo.processInfo.environment["DJCONNECT_AVATAR_ARTIFACT_DIR"] {
        let tiff = try #require(image.tiffRepresentation)
        let rep = try #require(NSBitmapImageRep(data: tiff))
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("session-activity-glyphs.png"))
    }
}
#endif

@Test func personaNativeSilenceIdentitySurvivesDecodingWithoutBecomingCurrentContent() throws {
    let data = Data(#"{"schema_version":1,"session_id":"session","revision":"rev","current_moment_id":null,"current_silence_moment_id":"silence-1","active_flow_moment_ids":[],"admissions":[],"revocation_scope":"session"}"#.utf8)
    let delivery = try JSONDecoder().decode(DJConnectNativeMomentDelivery.self, from: data)
    #expect(delivery.currentMomentID == nil)
    #expect(delivery.currentSilenceMomentID == "silence-1")
    #expect(try JSONDecoder().decode(DJConnectNativeMomentDelivery.self, from: JSONEncoder().encode(delivery)) == delivery)
    var legacy = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    legacy.removeValue(forKey: "current_silence_moment_id")
    let older = try JSONDecoder().decode(DJConnectNativeMomentDelivery.self, from: JSONSerialization.data(withJSONObject: legacy))
    #expect(older.currentSilenceMomentID == nil)
}

@Test @MainActor func personaOptimisticCaptureAndHistoricalDemoConferNoLiveAuthority() throws {
    let suite = "persona-authorization-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    let session = try DJConnectDemoSessionData.make(language: "nl").active
    model.isRecordingVoice = true
    model.voiceStatus = .listening
    let evidence = model.personaEvidence(for: session, admittedMoment: session.broadcast.djMoments.first)
    #expect(!evidence.authorized && !evidence.capturing && !evidence.speaking)
    #expect(DJPersonaActivity.resolve(evidence) == .resting)
    model.cancelVoiceRecording()
}

@Test func personaConflictingSilenceCannotRetainAnAnnouncement() throws {
    var broadcast = try DJConnectDemoSessionData.make(language: "nl").active.broadcast
    let now = Date()
    #expect(broadcast.nativeCurrentMoment(at: now, spotifyAttributionAvailable: true) != nil)
    broadcast.nativeDelivery?.currentSilenceMomentID = "conflicting-silence"
    #expect(broadcast.nativeCurrentMoment(at: now, spotifyAttributionAvailable: true) == nil)
}
