#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import DJConnectCore
@testable import DJConnectUI

private struct ForecastHeaderMarker: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.identifier = .init("forecast-header-layout-marker")
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.systemPink.cgColor
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {}
}

final class ForecastHeaderAlignmentTests: XCTestCase {
    @MainActor func testNativeSessionModeGlassButtons() async throws {
        guard let path = ProcessInfo.processInfo.environment["DJCONNECT_SESSION_MODE_GLASS_DIR"] else {
            throw XCTSkip("Native mode-button rendering is opt-in")
        }
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency else {
            throw XCTSkip("Native glass rendering follows the system transparency preference")
        }
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        _ = NSApplication.shared
        var interactiveHost = true
        for width: CGFloat in [320, 640] {
            for forecast in [false, true] {
                let host = NSHostingView(rootView:
                    SessionModeToggleButtons(showsForecast: .constant(forecast), language: "nl")
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(LinearGradient(colors: [.green.opacity(0.5), .black],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                        .environment(\.djConnectGlassEffectsEnabled, true)
                        .preferredColorScheme(.dark))
                let window = NSWindow(contentRect: .init(x: 100, y: 100, width: width, height: 100),
                                      styleMask: [.titled], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.title = "DJConnect mode controls — isolated preview"
                window.contentView = host
                window.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate()
                try await Task.sleep(for: .milliseconds(250))
                host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
                interactiveHost = interactiveHost && NSApplication.shared.isActive && window.isKeyWindow
                print("NATIVE_MODE_WINDOW active=\(NSApplication.shared.isActive) key=\(window.isKeyWindow)")
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    .write(to: folder.appendingPathComponent("\(forecast ? "forecast" : "flow")-\(Int(width)).png"))
                window.close()
                XCTAssertEqual(host.bounds.width, width)
            }
        }
        guard interactiveHost else {
            throw XCTSkip("Inactive native host: captures do not qualify glass chrome or selected appearance")
        }
    }

    /// Actual Forecast panel in an isolated native host, with the same supplied
    /// header as a plain scroll view. No ordinary app, paired owner or live HTTP.
    @MainActor func testForecastAddsNoTopInsetToSharedHeader() async throws {
        guard let path = ProcessInfo.processInfo.environment["DJCONNECT_FORECAST_HEADER_LAYOUT_DIR"] else {
            throw XCTSkip("Native geometry qualification is opt-in")
        }
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let suite = "forecast-header-layout-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(),
                                      startBackgroundTasks: false)
        defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
        _ = NSApplication.shared
        func marker(in view: NSView) -> NSView? {
            if view.identifier?.rawValue == "forecast-header-layout-marker" { return view }
            return view.subviews.lazy.compactMap { marker(in: $0) }.first
        }
        func render(_ name: String, width: CGFloat, forecast: Bool) async throws -> CGFloat {
            let header = ForecastHeaderMarker().frame(height: 80)
            let content: AnyView = forecast
                ? AnyView(SessionForecastPanel(model: model, position: .constant(nil), query: .constant("")) { header })
                : AnyView(ScrollView { header })
            let host = NSHostingView(rootView: content.environment(\.scenePhase, .background)
                .foregroundStyle(.white).background(.black))
            let window = NSWindow(contentRect: .init(x: -3000, y: -3000, width: width, height: 640),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderBack(nil)
            defer { window.close() }
            try await Task.sleep(for: .milliseconds(250))
            host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
            let view = try XCTUnwrap(marker(in: host))
            let frame = host.convert(view.bounds, from: view)
            let top = host.isFlipped ? frame.minY - host.bounds.minY : host.bounds.maxY - frame.maxY
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                .write(to: folder.appendingPathComponent(name + ".png"))
            return top
        }
        var observations: [[String: Double]] = []
        for width: CGFloat in [500, 900] {
            let flow = try await render("flow-\(Int(width))", width: width, forecast: false)
            let forecast = try await render("forecast-\(Int(width))", width: width, forecast: true)
            observations.append(["width": width, "flow_top": flow, "forecast_top": forecast,
                                 "difference": forecast - flow])
        }
        try JSONSerialization.data(withJSONObject: observations, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("geometry.json"))
        for row in observations {
            XCTAssertEqual(try XCTUnwrap(row["difference"]), 0, accuracy: 0.5,
                           "Forecast must not add space above the supplied current-track header at width \(row["width"]!)")
        }
    }
}
#endif
