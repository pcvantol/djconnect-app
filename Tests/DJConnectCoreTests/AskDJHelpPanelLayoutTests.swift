import Combine
import SwiftUI
import Testing
@testable import DJConnectUI
#if os(macOS)
import AppKit

@MainActor private final class HelpPanelLayoutState: ObservableObject {
    @Published var expanded = false
    var measured = CGSize.zero
}
private struct HelpPanelLayoutFixture: View {
    @ObservedObject var state: HelpPanelLayoutState
    let maximumHeight: CGFloat
    var body: some View {
        VStack(spacing: 0) {
            AskDJHelpPanel(expanded: $state.expanded, maximumHeight: maximumHeight,
                title: "Help", backLabel: "Suggestions", closeLabel: "Close", close: {}) {
                    VStack(spacing: 8) {
                        ForEach(0..<3) { index in Text("Suggestion \(index)").frame(height: 24) }
                        Text("More").frame(height: 24)
                    }
                } catalogue: {
                    ScrollView {
                        VStack { ForEach(0..<30) { index in Text("Catalogue fixture \(index)").frame(height: 32) } }
                    }
                }
                .onGeometryChange(for: CGSize.self) { $0.size } action: { state.measured = $0 }
            Spacer(minLength: 0)
        }
        .frame(width: 420, height: 700, alignment: .top)
        .environment(\.djConnectGlassEffectsEnabled, false)
    }
}

@Suite(.serialized) @MainActor struct AskDJHelpPanelLayoutTests {
    @Test(arguments: [CGFloat(72), CGFloat(220), CGFloat(560)])
    func onePanelExpandsWithinViewportThenReturnsToItsCompactHeight(_ available: CGFloat) async throws {
        let state = HelpPanelLayoutState()
        let host = NSHostingView(rootView: HelpPanelLayoutFixture(state: state, maximumHeight: available))
        let window = NSWindow(contentRect: .init(x: -3000, y: -3000, width: 420, height: 700),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host; window.orderBack(nil)
        defer { window.close() }
        func settle(_ predicate: () -> Bool) async throws {
            let deadline = ContinuousClock.now.advanced(by: .seconds(2))
            repeat {
                host.layoutSubtreeIfNeeded()
                if predicate() { return }
                try await Task.sleep(for: .milliseconds(10))
            } while ContinuousClock.now < deadline
            try #require(predicate())
        }
        try await settle { state.measured.height > 0 }
        let compact = state.measured.height
        #expect(compact <= available + 1)
        state.expanded = true
        try await settle { abs(state.measured.height - available) < 1 }
        #expect(state.measured.height >= compact)
        if available == 560 { #expect(state.measured.height > compact + 100) }
        #expect(state.measured.width <= 420)
        state.expanded = false
        try await settle { abs(state.measured.height - compact) < 1 }
        #expect(window.sheets.isEmpty)
    } // Shared component geometry only; not an iPhone/iPad native acceptance test.

    @Test func outsideClickClosesHelpWhilePanelComposerAndOtherWindowsStayUntouched() async throws {
        let regions = AskDJHelpTapRegions()
        var closes = 0
        let host = NSHostingView(rootView:
            VStack(spacing: 12) {
                Color.clear.frame(height: 200)
                    .background(AskDJHelpTapRegion(regions: regions, isPanel: true))
                Color.clear.frame(height: 100)
                    .background(AskDJHelpTapRegion(regions: regions, isPanel: false,
                        enabled: true, close: { closes += 1 }))
                Spacer()
            }.frame(width: 420, height: 700))
        let window = NSWindow(contentRect: .init(x: -3000, y: -3000, width: 420, height: 700),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host; window.orderBack(nil)
        defer { window.close() }
        func markers(_ view: NSView) -> [AskDJHelpTapRegion.RegionView] {
            (view as? AskDJHelpTapRegion.RegionView).map { [$0] } ?? view.subviews.flatMap(markers)
        }
        for _ in 0..<100 {
            host.layoutSubtreeIfNeeded()
            if markers(host).count == 2 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let views = markers(host)
        let composer = try #require(views.first { $0.enabled })
        let panel = try #require(views.first { !$0.enabled })
        func click(_ point: CGPoint, windowNumber: Int? = nil) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [],
                timestamp: 0, windowNumber: windowNumber ?? window.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        }
        for view in [panel, composer] {
            let point = view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil)
            let event = try click(point)
            #expect(composer.handle(event) === event) // Never swallow the underlying click.
            #expect(closes == 0)
        }
        let outside = host.convert(CGPoint(x: 20, y: 650), to: nil)
        _ = composer.handle(try click(outside))
        #expect(closes == 1)
        _ = composer.handle(try click(outside, windowNumber: 0))
        #expect(closes == 1)
        composer.enabled = false
        _ = composer.handle(try click(outside))
        #expect(closes == 1)
    }

}
#endif
