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

@Test(.isolatedAppKitResources) @MainActor func nativeFindShortcutDispatchesRepeatedCommandF() async throws {
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
    @ObservedObject var observation: SearchFocusObservation
    @State private var expanded = false
    @State private var request = UUID()
    @FocusState private var composerFocused: Bool
    @FocusState private var searchFocused: Bool
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack {
                    if expanded {
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

@Test(.isolatedAppKitResources) @MainActor
func nativeFindMovesTypingFromComposerToMountedSearchAndRefocuses() async throws {
    _ = NSApplication.shared
    let observation = SearchFocusObservation()
    let host = NSHostingView(rootView: SearchFocusProbe(observation: observation)
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

#if os(macOS)
@MainActor private final class ArchiveSearchNavigationProbe: ObservableObject {
    @Published var openedSession: SavedSessionDestination?
}
private struct ArchiveSearchNavigationHost: View {
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject var probe: ArchiveSearchNavigationProbe
    var body: some View { SavedSessionsView(model: model, openedSession: $probe.openedSession) }
}

@MainActor private func archiveNativeListScrollView(in view: NSView) -> NSScrollView? {
    if let scroll = view as? NSScrollView { return scroll }
    return view.subviews.lazy.compactMap { archiveNativeListScrollView(in: $0) }.first
}

@MainActor private func archiveNativeFields(in view: NSView) -> [NSTextField] {
    (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap { archiveNativeFields(in: $0) }
}

@Test(.isolatedAppKitResources) @MainActor func archiveSearchNativeNavigationKeepsQueryAndMatchingRows() async throws {
    _ = NSApplication.shared
    let suite = "archive-navigation-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
    model.language = "nl"; model.startDemoMode()
    let probe = ArchiveSearchNavigationProbe()
    let host = NSHostingView(rootView: ArchiveSearchNavigationHost(model: model, probe: probe).environment(\.scenePhase, .active))
    let window = NSWindow(contentRect: .init(x: -3000, y: -3000, width: 1000, height: 760), styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host; window.makeKeyAndOrderFront(nil)
    defer { window.close() }
    func wait(_ predicate: () -> Bool) async throws {
        for _ in 0..<100 { host.layoutSubtreeIfNeeded(); if predicate() { return }; try await Task.sleep(for: .milliseconds(50)) }
        #expect(predicate(), "Native navigation state did not settle")
    }
    try await Task.sleep(for: .milliseconds(200))
    for term in ["Electric", "MGMT"] {
        let find = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: "f", charactersIgnoringModifiers: "f", isARepeat: false, keyCode: 3))
        #expect(window.performKeyEquivalent(with: find))
        try await wait { window.firstResponder is NSTextView }
        let editor = try #require(window.firstResponder as? NSTextView)
        editor.setSelectedRange(NSRange(location: 0, length: (editor.string as NSString).length))
        editor.insertText(term, replacementRange: NSRange(location: NSNotFound, length: 0))
        try await wait { model.sessionHistory.archiveSearchQuery == term }
        // The filtered native List contains one result. Click its row in the
        // hosted scroll document, rather than publishing a route from the test.
        let document = try #require(archiveNativeListScrollView(in: host)?.documentView)
        let point = document.convert(NSPoint(x: document.bounds.midX, y: document.bounds.midY), to: nil)
        for kind in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let click = try #require(NSEvent.mouseEvent(with: kind, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: kind == .leftMouseDown ? 1 : 0))
            window.sendEvent(click)
        }
        try await wait { probe.openedSession?.sessionID == "demo-evening" }
        #expect(probe.openedSession?.searchQuery == term)
        try await wait { model.sessionHistory.acceptedSearchQuery == term }
        try await wait { archiveNativeFields(in: host).contains { $0.stringValue == term } }
        #expect(archiveNativeFields(in: host).contains { $0.stringValue == term }, "Destination search bar must be mounted with the inherited term")
        #expect(model.sessionHistory.acceptedSearchSessionID == "demo-evening")
        #expect(model.sessionHistory.acceptedSearchQuery == term)
        #expect(model.sessionHistory.searchMatches.map(\.id) == ["demo-evening-entry-1"])
        probe.openedSession = nil
        try await Task.sleep(for: .milliseconds(250))
    }
}
#endif
