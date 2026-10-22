#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import DJConnectCore
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
@MainActor private final class SearchFocusObservation: ObservableObject {
    @Published var query = ""
    @Published var draft = "Unsent question"
    @Published var composerRequest = 0
}

private struct SearchFocusProbe: View {
    let model: DJConnectAppModel
    let forecast: Bool
    @ObservedObject var observation: SearchFocusObservation
    @State private var expanded = false
    @State private var request = UUID()
    @FocusState private var composerFocused: Bool
    @FocusState private var searchFocused: Bool
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack {
                    if forecast {
                        SessionForecastContent(model: model, query: $observation.query, searchExpanded: $expanded,
                            focusRequest: request, searchBoundsChanged: { _ in })
                    } else if expanded {
                        AskDJSearchBar(language: "nl", focusRequest: request, text: $observation.query,
                            isFocused: $searchFocused, resultCount: 0, selectedIndex: 0,
                            previousAction: {}, nextAction: {}, closeAction: { expanded = false })
                    }
                }
            }
            TextField("Composer", text: $observation.draft).focused($composerFocused)
        }
        .djConnectFindShortcut {
            composerFocused = false; searchFocused = false
            expanded = true; request = UUID()
        }
        .onChange(of: observation.composerRequest) { composerFocused = true }
    }
}

@Test(arguments: [false, true]) @MainActor
func nativeFindMovesTypingFromComposerToMountedSearchAndRefocuses(_ forecast: Bool) async throws {
    _ = NSApplication.shared
    let suite = "find-focus-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
    let observation = SearchFocusObservation()
    let host = NSHostingView(rootView: SearchFocusProbe(model: model, forecast: forecast, observation: observation)
        .environment(\.scenePhase, .background))
    let window = NSWindow(contentRect: .init(x: -3000, y: -3000, width: 640, height: 480),
                          styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    window.makeKeyAndOrderFront(nil)
    defer { window.close() }
    let find = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
        timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "f",
        charactersIgnoringModifiers: "f", isARepeat: false, keyCode: 3))
    // Mount the observer before requesting initial composer focus.
    try await Task.sleep(for: .milliseconds(150))
    host.layoutSubtreeIfNeeded()
    for index in 1...2 {
        observation.composerRequest += 1
        try await Task.sleep(for: .milliseconds(150))
        let composer = try #require(window.firstResponder as? NSTextView)
        #expect(composer.string == observation.draft)
        #expect(window.performKeyEquivalent(with: find))
        try await Task.sleep(for: .milliseconds(200))
        let editor = try #require(window.firstResponder as? NSTextView)
        editor.insertText("find\(index)", replacementRange: NSRange(location: NSNotFound, length: 0))
        try await Task.sleep(for: .milliseconds(50))
        #expect(observation.query.contains("find\(index)"))
        #expect(observation.draft == "Unsent question")
    }
}
#endif
