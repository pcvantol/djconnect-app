import DJConnectCore
import Testing
import SwiftUI
@testable import DJConnectUI
#if os(macOS)
import AppKit
#endif

@Test(.isolatedClientResources, arguments: [CGFloat(16), CGFloat(20), CGFloat(24), CGFloat(80)])
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
@Test(.isolatedClientResources) @MainActor func personaNativeRenderingSupportsMoodAccessibilityAndMenuSizes() throws {
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
    // Deliberately bright violet: the identity must remain readable on the
    // mood glass surface, rather than only on a near-black preview canvas.
    .background(Color(red: 0.36, green: 0.18, blue: 0.60))
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
@Test(.isolatedClientResources, arguments: ["moment", "quiet", "paused", "recovering", "unavailable"], [CGFloat(320), CGFloat(620)])
@MainActor func personaCurrentCardRenderingRetainsEveryState(state: String, width: CGFloat) throws {
    var session = try DJConnectDemoSessionData.make(language: "nl").active
    if state == "quiet" { session.broadcast.nativeDelivery?.currentMomentID = nil }
    if state == "paused" { session.broadcast.playback?.state = "paused" }
    let current = NativeSessionMomentsView(session: session, language: "nl", isRecovering: state == "recovering", isLiveUnavailable: state == "unavailable")
    let moment = state == "quiet" ? nil : session.broadcast.djMoments.first
    if state == "moment" { #expect(moment != nil) }
    let view = current.currentCard(moment)
        .environment(\.djConnectGlassEffectsEnabled, false)
        .frame(width: width, alignment: .leading).padding(20)
        .foregroundStyle(.white).background(Color(red: 0.07, green: 0.06, blue: 0.20))
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    let image = try #require(renderer.nsImage)
    let tiff = try #require(image.tiffRepresentation)
    let rep = try #require(NSBitmapImageRep(data: tiff))
    let png = try #require(rep.representation(using: .png, properties: [:]))
    #expect(image.size.width == width + 40)
    if state == "quiet" {
        #expect(image.size.height == 80 + 2 * DJConnectCardAppearance.currentDJInset + 40)
    } else {
        #expect(image.size.height >= 80 + 2 * DJConnectCardAppearance.currentDJInset + 40)
    }
    if let directory = ProcessInfo.processInfo.environment["DJCONNECT_AVATAR_ARTIFACT_DIR"] {
        let folder = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try png.write(to: folder.appendingPathComponent("session-current-" + state + "-\(Int(width)).png"))
    }
}
#endif

@Test(.isolatedClientResources) func personaActivityRequiresAuthorityAndActualOutput() {
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

@Test(.isolatedClientResources) func personaCurrentAnnouncementDoesNotMaskNewExplicitInteraction() {
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

@Test(.isolatedClientResources) func personaSilenceRestsUnlessActualInteractionHasPriority() {
    var evidence = DJPersonaActivity.Evidence()
    evidence.authorized = true
    #expect(DJPersonaActivity.resolve(evidence) == .resting)
    evidence.speaking = true
    #expect(DJPersonaActivity.resolve(evidence) == .speaking)
    evidence.speaking = false
    #expect(DJPersonaActivity.resolve(evidence) == .resting)
}

@Test(.isolatedClientResources) func personaTrackStoryAloneIsNotAnAnnouncement() throws {
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
@Test(.isolatedClientResources) @MainActor func personaEveryActivityRendersInFixedGeometry() throws {
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

@Test(.isolatedClientResources) func personaNativeSilenceIdentitySurvivesDecodingWithoutBecomingCurrentContent() throws {
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

@Test(.isolatedClientResources) @MainActor func personaOptimisticCaptureAndHistoricalDemoConferNoLiveAuthority() throws {
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

@Test(.isolatedClientResources) func personaConflictingSilenceCannotRetainAnAnnouncement() throws {
    var broadcast = try DJConnectDemoSessionData.make(language: "nl").active.broadcast
    let now = Date()
    #expect(broadcast.nativeCurrentMoment(at: now, spotifyAttributionAvailable: true) != nil)
    broadcast.nativeDelivery?.currentSilenceMomentID = "conflicting-silence"
    #expect(broadcast.nativeCurrentMoment(at: now, spotifyAttributionAvailable: true) == nil)
}

#if os(macOS)
@Test(.isolatedClientResources) @MainActor func personaOpaqueBackingCoversOuterHeadsetOnBrightMood() throws {
    for activity in DJPersonaActivity.allCases {
        let view = DJPersonaGraphic(colors: [.pink, .purple], highContrast: false, opaque: true,
                                    activity: activity)
            .frame(width: 200, height: 200).background(Color(red: 0.7, green: 0.3, blue: 0.9))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let tiff = try #require(renderer.nsImage?.tiffRepresentation)
        let rep = try #require(NSBitmapImageRep(data: tiff))
        // Inside the full-size backing, outside both central disc and headset.
        let pixel = try #require(rep.colorAt(x: 10, y: 100)?.usingColorSpace(.deviceRGB))
        #expect(pixel.redComponent < 0.05 && pixel.greenComponent < 0.05 && pixel.blueComponent < 0.05)
    }
}
#endif


@Test(.isolatedClientResources, arguments: ["idle", "silence", "moment", "missing-body", "missing-delivery", "missing-admission", "duplicate-admission", "reordered-admissions", "unqualified", "malformed-deadline", "wrong-session", "conflict", "empty-silence", "expired-display", "expired-source", "withdrawn", "paused", "recovering", "unavailable", "no-playback", "ended"])
@MainActor func personaIdleGeometryRequiresConfirmedPresentation(_ state: String) throws {
    let now = Date()
    var session = try DJConnectDemoSessionData.make(language: "nl", now: now).active
    let original = try #require(session.broadcast.nativeCurrentMoment(at: now))
    var expected = SessionCurrentDJCardState.unresolved
    if ["idle", "silence", "empty-silence"].contains(state) { session.broadcast.nativeDelivery?.currentMomentID = nil }
    if state == "silence" { session.broadcast.nativeDelivery?.currentSilenceMomentID = "silence-1" }
    if state == "empty-silence" { session.broadcast.nativeDelivery?.currentSilenceMomentID = " " }
    if state == "conflict" { session.broadcast.nativeDelivery?.currentSilenceMomentID = "silence-1" }
    if state == "missing-body" { session.broadcast.djMoments = [] }
    if state == "missing-delivery" { session.broadcast.nativeDelivery = nil }
    if state == "missing-admission" { session.broadcast.nativeDelivery?.admissions = [] }
    if ["duplicate-admission", "reordered-admissions"].contains(state) {
        var duplicate = try #require(session.broadcast.nativeDelivery?.admissions.first)
        duplicate.displayExpiresAt = ISO8601DateFormatter().string(from: now.addingTimeInterval(-1))
        session.broadcast.nativeDelivery?.admissions.append(duplicate)
        if state == "reordered-admissions" { session.broadcast.nativeDelivery?.admissions.reverse() }
    }
    if state == "unqualified" { session.broadcast.nativeDelivery?.admissions[0].qualification = "unknown" }
    if state == "malformed-deadline" {
        session.broadcast.nativeDelivery?.admissions[0].displayExpiresAt = "invalid"
        session.broadcast.nativeDelivery?.admissions[0].sourceExpiresAt = ISO8601DateFormatter().string(from: now.addingTimeInterval(-1))
    }
    if state == "wrong-session" { session.broadcast.nativeDelivery?.sessionID = "other" }
    if state == "expired-display" { session.broadcast.nativeDelivery?.admissions[0].displayExpiresAt = ISO8601DateFormatter().string(from: now.addingTimeInterval(-1)) }
    if state == "expired-source" { session.broadcast.nativeDelivery?.admissions[0].sourceExpiresAt = ISO8601DateFormatter().string(from: now.addingTimeInterval(-1)) }
    if state == "paused" { session.broadcast.playback?.state = "paused" }
    if state == "no-playback" { session.broadcast.playback = nil }
    if state == "ended" { session.runtimeState = "ended"; session.broadcast.session.runtimeState = "ended" }
    if ["idle", "silence", "expired-display", "expired-source", "withdrawn"].contains(state) { expected = .compact }
    if ["moment", "paused", "recovering", "unavailable", "no-playback", "ended"].contains(state) { expected = .expanded }
    let moment = state == "withdrawn" ? nil : session.broadcast.nativeCurrentMoment(at: now)
    #expect(SessionCurrentDJCardState.resolve(session: session, moment: moment,
        recovering: state == "recovering", unavailable: state == "unavailable", withdrawn: state == "withdrawn", at: now) == expected)
    if state == "moment" {
        // Geometry never reads audio settings or playback completion. An admitted
        // text-only contribution remains expanded on every unchanged refresh.
        for _ in 0..<20 {
            #expect(session.broadcast.nativeCurrentMoment(at: now)?.id == original.id)
            #expect(SessionCurrentDJCardState.resolve(session: session, moment: moment, recovering: false, unavailable: false, at: now) == .expanded)
        }
    }
}

#if os(macOS)
@Test(.isolatedClientResources, arguments: [CGFloat(280), CGFloat(620), CGFloat(1200)])
@MainActor func personaIdleTileHasIntrinsicGeometryAndLeftAnchor(width: CGFloat) throws {
    var session = try DJConnectDemoSessionData.make(language: "nl").active
    session.broadcast.nativeDelivery?.currentMomentID = nil
    let native = NativeSessionMomentsView(session: session, language: "nl")
    let renderer = ImageRenderer(content: native.currentCard(nil).environment(\.djConnectGlassEffectsEnabled, false))
    renderer.proposedSize = .init(width: width, height: nil)
    let image = try #require(renderer.nsImage)
    #expect(image.size == CGSize(width: 112, height: 112))
    // The real container places its intrinsic second child at topLeading;
    // this full-pane wrapper must leave the card's far edge unpainted.
    let pane = ImageRenderer(content: native.currentCard(nil).environment(\.djConnectGlassEffectsEnabled, false)
        .frame(width: width, alignment: .leading).background(Color.black))
    pane.scale = 1
    let tiff = try #require(pane.nsImage?.tiffRepresentation)
    let rep = try #require(NSBitmapImageRep(data: tiff))
    let pixel = try #require(rep.colorAt(x: Int(width) - 2, y: 56)?.usingColorSpace(.deviceRGB))
    #expect(pixel.redComponent < 0.01 && pixel.greenComponent < 0.01 && pixel.blueComponent < 0.01)
}
#endif

#if os(macOS)
@Test(.isolatedClientResources, arguments: [CGFloat(0), 0.25, 0.5, 0.75, 1])
@MainActor func personaNumericTransitionHasFiniteSizeAndUnclippedAvatar(_ fraction: CGFloat) throws {
    let session = try DJConnectDemoSessionData.make(language: "nl").active
    let moment = try #require(session.broadcast.djMoments.first)
    func render(_ progress: CGFloat) -> NSImage? {
        let renderer = ImageRenderer(content: SessionCurrentDJCardLayout(sessionID: session.id, expansion: progress, hasDetail: true, heldSize: nil) {
            DJPersonaAvatarView(confirmedMood: "groove", language: "nl").frame(width: 80, height: 80)
            MomentCard(moment: moment, kind: "Session", presentation: nil, language: "nl")
        }.background(Color.red).clipShape(DJConnectCardAppearance.shape)
            .frame(width: 620, alignment: .leading).foregroundStyle(.white))
        renderer.scale = 1
        return renderer.nsImage
    }
    let expanded = try #require(render(1))
    let image = try #require(render(fraction))
    #expect(image.size.width == 620)
    let cardWidth = 112 + (620 - 112) * fraction
    #expect(abs(image.size.height - (112 + (expanded.size.height - 112) * fraction)) <= 1)
    #expect(image.size.width >= 112 && image.size.height >= 112)
    let tiff = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiff))
    if let directory = ProcessInfo.processInfo.environment["DJCONNECT_AVATAR_ARTIFACT_DIR"],
       let png = bitmap.representation(using: .png, properties: [:]) {
        try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("numeric-transition-\(fraction).png"))
    }
    let center = try #require(bitmap.colorAt(x: 56, y: 56))
    #expect(center.alphaComponent > 0.9 && center.redComponent < 0.5,
            "The same dark/teal avatar stays at (56,56) over the red measurement surface")
    let inside = try #require(bitmap.colorAt(x: Int(cardWidth) - 2, y: 56))
    #expect(inside.alphaComponent > 0.9)
    if fraction < 1 {
        let outside = try #require(bitmap.colorAt(x: Int(cardWidth) + 2, y: 56))
        #expect(outside.alphaComponent < 0.01, "No invisible full-width frame or escaped detail")
    }
}

@Test(.isolatedClientResources) @MainActor func personaOffscreenGeometryFitsANarrowerPaneWithoutBorrowingOldWidth() throws {
    let renderer = ImageRenderer(content: SessionCurrentDJCardLayout(sessionID: "current", expansion: 1, hasDetail: false,
        heldSize: CGSize(width: 1000, height: 240)) {
        DJPersonaAvatarView(confirmedMood: "groove", language: "nl").frame(width: 80, height: 80)
    })
    renderer.proposedSize = .init(width: 280, height: nil)
    let image = try #require(renderer.nsImage)
    #expect(image.size == CGSize(width: 280, height: 240))
}
#endif
