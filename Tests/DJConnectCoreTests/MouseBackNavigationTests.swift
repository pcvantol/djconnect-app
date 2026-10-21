#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import DJConnectUI

@MainActor private final class MouseBackPath: ObservableObject {
    @Published var path: [String] = []
}

private struct MouseBackNavigationProbe: View {
    @ObservedObject var state: MouseBackPath
    var body: some View {
        NavigationStack(path: $state.path) {
            Text("Root").navigationTitle("Root")
                .navigationDestination(for: String.self) { value in
                    Text(value).navigationTitle(value).djConnectMouseBackNavigation()
                }
        }
    }
}

@Test @MainActor func nativeMouseBackPopsOnePage() async throws {
    _ = NSApplication.shared
    let state = MouseBackPath()
    let host = NSHostingView(rootView: MouseBackNavigationProbe(state: state))
    let window = NSWindow(contentRect: .init(x: -3000, y: -3000, width: 500, height: 400),
                          styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host; window.orderBack(nil)
    defer { window.close() }
    try await Task.sleep(for: .milliseconds(150))
    state.path = ["First"]
    try await Task.sleep(for: .milliseconds(200))
    state.path.append("Second")
    try await Task.sleep(for: .milliseconds(250))
    host.layoutSubtreeIfNeeded()
    func findBackView(_ view: NSView) -> MouseBackView? {
        if let result = view as? MouseBackView, result.window != nil, result.navigationActive { return result }
        return view.subviews.compactMap(findBackView).first
    }
    let back = try #require(findBackView(host))
    #expect(!back.handle(type: .otherMouseDown, button: 2, eventWindow: window))
    #expect(!back.handle(type: .otherMouseDown, button: 4, eventWindow: window))
    #expect(!back.handle(type: .otherMouseDown, button: 3, eventWindow: nil))
    #expect(state.path == ["First", "Second"])
    #expect(back.handle(type: .otherMouseDown, button: 3, eventWindow: window))
    try await Task.sleep(for: .milliseconds(150))
    #expect(state.path == ["First"])
    try await Task.sleep(for: .milliseconds(250))
    let first = try #require(findBackView(host))
    #expect(first.handle(type: .otherMouseDown, button: 3, eventWindow: window))
    try await Task.sleep(for: .milliseconds(150))
    #expect(state.path.isEmpty)
    #expect(findBackView(host) == nil)
}
#endif
