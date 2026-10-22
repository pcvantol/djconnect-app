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

@MainActor private final class ForecastSearchGeometry: ObservableObject {
    var field = CGRect.zero
    var viewport = CGRect.zero
}

private struct ForecastSearchOpeningHarness: View {
    let model: DJConnectAppModel
    let geometry: ForecastSearchGeometry
    @State private var position: String? = "current"
    @State private var expanded = false
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                Color.clear.frame(height: 1400).id("current")
                SessionForecastContent(model: model, query: .constant(""), searchExpanded: $expanded,
                    searchBoundsChanged: { bounds in
                        geometry.field = bounds
                        position = SessionForecastSearchPosition.target(fieldBounds: bounds)
                    })
                    .id("forecast-content")
                Color.clear.frame(height: 800).id("after-forecast")
            }.scrollTargetLayout()
        }
        .scrollPosition(id: $position, anchor: .top)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { geometry.viewport = $0 }
        .task {
            expanded = true
            position = SessionForecastSearchPosition.target(fieldBounds: .zero)
        }
    }
}

final class ForecastHeaderAlignmentTests: XCTestCase {
    @MainActor func testOpeningSearchMountsOffscreenForecastAndRevealsField() async throws {
        let suite = "forecast-search-layout-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
        defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
        _ = NSApplication.shared
        let measured = ForecastSearchGeometry()
        let host = NSHostingView(rootView: ForecastSearchOpeningHarness(model: model, geometry: measured)
            .environment(\.scenePhase, .background))
        let window = NSWindow(contentRect: .init(x: -3000, y: -3000, width: 640, height: 400),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host; window.orderBack(nil)
        defer { window.close() }
        for _ in 0..<30 {
            try await Task.sleep(for: .milliseconds(50))
            host.layoutSubtreeIfNeeded()
            if !measured.field.isEmpty, abs(measured.field.minY-measured.viewport.minY) <= 2 { break }
        }
        XCTAssertFalse(measured.field.isEmpty, "Opening must materialize the offscreen Forecast search field")
        XCTAssertTrue(measured.viewport.intersects(measured.field), "Search must be visible after opening beyond a tall playback header")
        XCTAssertEqual(measured.field.minY, measured.viewport.minY, accuracy: 2,
                       "The nested search target must reach the viewport top after Forecast mounts")
    }

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

    @MainActor func testForecastContentAddsNoScrollHost() async throws {
        let suite = "forecast-content-layout-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(),
                                      startBackgroundTasks: false)
        defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
        _ = NSApplication.shared
        let host = NSHostingView(rootView:
            SessionForecastContent(model: model, query: .constant(""), searchExpanded: .constant(false),
                                   searchBoundsChanged: { _ in })
                .environment(\.scenePhase, .background).frame(width: 640, height: 300))
        let window = NSWindow(contentRect: .init(x: -3000, y: -3000, width: 640, height: 300),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderBack(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(150))
        host.layoutSubtreeIfNeeded()
        func scrollHosts(_ view: NSView) -> Int {
            (view is NSScrollView ? 1 : 0) + view.subviews.reduce(0) { $0 + scrollHosts($1) }
        }
        XCTAssertEqual(scrollHosts(host), 0, "The lower Forecast content must share the Session's scroll host")
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
                ? AnyView(SessionForecastPanel(model: model, viewport: SessionForecastViewport(), query: .constant("")) { header })
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
