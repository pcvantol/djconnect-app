#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import DJConnectUI

@MainActor private final class FindShortcutObservation: ObservableObject {
    @Published var requests = 0
}

private struct FindShortcutProbe: View {
    @ObservedObject var observation: FindShortcutObservation
    var body: some View {
        Text("Search host")
            .frame(width: 320, height: 120)
            .djConnectFindShortcut { observation.requests += 1 }
    }
}

@Test @MainActor func nativeFindShortcutDispatchesRepeatedCommandF() async throws {
    _ = NSApplication.shared
    let observation = FindShortcutObservation()
    let host = NSHostingView(rootView: FindShortcutProbe(observation: observation))
    let window = NSWindow(contentRect: .init(x: -3000, y: -3000, width: 320, height: 120),
                          styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = host
    window.orderBack(nil)
    defer { window.close() }
    try await Task.sleep(for: .milliseconds(150))
    host.layoutSubtreeIfNeeded()
    let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
        timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "f",
        charactersIgnoringModifiers: "f", isARepeat: false, keyCode: 3))
    #expect(window.performKeyEquivalent(with: event))
    #expect(observation.requests == 1)
    #expect(window.performKeyEquivalent(with: event))
    #expect(observation.requests == 2)
}
#endif
