#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import DJConnectUI

/// Opt-in native frame sampling. Does not launch/replace the ordinary app or
/// play audio; explicit local activity is not real speech/server acceptance.
final class NativeAvatarMotionQualificationTests: XCTestCase {
    @MainActor func testSpeakingFramesMoveOnlyInActiveScene() async throws {
        guard let path = ProcessInfo.processInfo.environment["DJCONNECT_NATIVE_MOTION_DIR"] else {
            throw XCTSkip("Native window frame sampling is an explicit local qualification")
        }
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        _ = NSApplication.shared
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              !ProcessInfo.processInfo.isLowPowerModeEnabled,
              [.nominal, .fair].contains(ProcessInfo.processInfo.thermalState) else {
            throw XCTSkip("Active motion requires actual system motion/power admission")
        }
        func content(scene: ScenePhase, activity: DJPersonaActivity) -> some View {
            DJPersonaAvatarView(confirmedMood: "party", language: "nl", activity: activity, speechIsPlaying: activity == .speaking)
                .frame(width: 120, height: 120).padding(20).background(Color.black)
                .environment(\.scenePhase, scene)
        }
        let host = NSHostingView(rootView: content(scene: .active, activity: .speaking))
        let window = NSWindow(contentRect: CGRect(x: -2000, y: -2000, width: 160, height: 160),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderBack(nil)
        defer { window.close() }
        let states: [(String, ScenePhase, DJPersonaActivity, Bool)] = [
            ("speaking-active", .active, .speaking, true),
            ("speaking-inactive", .background, .speaking, false),
            ("speaking-resumed", .active, .speaking, true),
            ("listening-active", .active, .listening, true),
            ("resting", .active, .resting, false)
        ]
        for (name, scene, activity, active) in states {
            host.rootView = content(scene: scene, activity: activity)
            try await Task.sleep(for: .milliseconds(300))
            var frames: Set<Data> = []
            for index in 0..<6 {
                try await Task.sleep(for: .milliseconds(180))
                host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
                let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: rep)
                let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
                frames.insert(png)
                try png.write(to: folder.appendingPathComponent("\(name)-\(index).png"))
                XCTAssertEqual(host.bounds.size, CGSize(width: 160, height: 160))
            }
            print("NATIVE_AVATAR_FRAMES \(name) unique=\(frames.count)")
            if active { XCTAssertGreaterThan(frames.count, 1, "Native active frames must show actual motion") }
            else { XCTAssertEqual(frames.count, 1, "Inactive or resting scenes must stop the native animation") }
        }
    }

}
#endif
