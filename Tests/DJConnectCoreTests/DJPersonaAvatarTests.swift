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
@Test(arguments: ["moment", "quiet", "paused", "recovering", "unavailable"])
@MainActor func personaCurrentCardRenderingRetainsEveryState(state: String) throws {
    var session = try DJConnectDemoSessionData.make(language: "nl").active
    if state == "quiet" { session.broadcast.djMoments = [] }
    if state == "paused" { session.broadcast.playback?.state = "paused" }
    let current = NativeSessionMomentsView(session: session, language: "nl", isRecovering: state == "recovering", isLiveUnavailable: state == "unavailable")
    let moment = state == "quiet" ? nil : session.broadcast.djMoments.first
    if state == "moment" { #expect(moment != nil) }
    let view = current.currentCard(moment)
        .environment(\.djConnectGlassEffectsEnabled, false)
        .frame(width: 620).padding(20)
        .foregroundStyle(.white).background(Color(red: 0.07, green: 0.06, blue: 0.20))
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    let image = try #require(renderer.nsImage)
    let tiff = try #require(image.tiffRepresentation)
    let rep = try #require(NSBitmapImageRep(data: tiff))
    let png = try #require(rep.representation(using: .png, properties: [:]))
    #expect(image.size.width == 660)
    #expect(image.size.height > 180)
    if let directory = ProcessInfo.processInfo.environment["DJCONNECT_AVATAR_ARTIFACT_DIR"] {
        let folder = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try png.write(to: folder.appendingPathComponent("session-current-" + state + ".png"))
    }
}
#endif
