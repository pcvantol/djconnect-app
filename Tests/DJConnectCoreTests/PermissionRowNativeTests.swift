#if os(macOS)
import AppKit
import SwiftUI
import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

@Test(.isolatedAppKitResources, .enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_MAC_PERMISSION_DIR"] != nil))
@MainActor func permissionRowsRenderInNativeMacHost() async throws {
    let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["DJCONNECT_MAC_PERMISSION_DIR"]))
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    _ = NSApplication.shared
    let cases: [(String, CGFloat, String, DJConnectPermissionStatus)] = [
        ("mac-permission-01-narrow", 320, "nl", .unknown),
        ("mac-permission-02-wide", 720, "nl", .unknown),
        ("mac-permission-03-german", 320, "de", .restricted)]
    var observations: [[String: Any]] = []
    for (name, width, language, status) in cases {
        let title = DJConnectLocalization.localized(key: "ui.speech.recognition", language: language)
        let detail = DJConnectLocalization.localized(key: "ui.needed.for.the.foreground.wake.phrase", language: language)
        let view = PermissionStatusRow(title: title, detail: detail, status: status, language: language)
            .frame(width: width - 32, alignment: .leading).padding(16)
            .environment(\.colorScheme, .dark)
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        #expect(size.width.isFinite && size.height.isFinite && size.width <= width + 0.5)
        #expect(size.height > 0 && size.height < 2000)
        let window = NSWindow(contentRect: CGRect(x: -3000, y: -3000, width: width, height: max(180, size.height + 64)),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .black; window.contentView = host
        host.frame = CGRect(origin: .zero, size: window.contentLayoutRect.size)
        window.orderBack(nil)
        try await Task.sleep(for: .milliseconds(150)); host.layoutSubtreeIfNeeded()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent(name + ".png"))
        observations.append(["stage": name, "width": width, "fitting_height": size.height,
            "height": host.bounds.height, "language": language, "title": title, "detail": detail])
        window.orderOut(nil); window.close()
    }
    try JSONSerialization.data(withJSONObject: observations, options: [.prettyPrinted, .sortedKeys])
        .write(to: folder.appendingPathComponent("native-mac-permission-layout.json"))
}
#endif
