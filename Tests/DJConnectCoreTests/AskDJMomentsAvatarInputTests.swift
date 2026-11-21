import Foundation
import SwiftUI
import Testing
@testable import DJConnectCore
@testable import DJConnectUI
#if os(macOS)
import AppKit

@MainActor private final class MomentsNativeInputState: ObservableObject {
    @Published var opened = false
    var opens = 0, photos = 0, sources = 0, mounts = 0
    var jokes: [DJConnectPersonaReactionKind] = []
    var regions: [String: CGRect] = [:]
}
private struct MomentsNativeInputFixture: View {
    @ObservedObject var state: MomentsNativeInputState
    let moment: DJConnectMoment
    let inventory: DJConnectAskDJMoments.Inventory
    private var avatar: some View {
        PersonaReactionAvatarInteraction(avatar: DJPersonaAvatarView(confirmedMood: nil, language: "en")
            .frame(width: 28, height: 28).frame(width: 44, height: 44), language: "en", canStart: !state.opened,
            request: { state.jokes.append($0) }, singleAction: { state.opens += 1; state.opened = true }, singleEnabled: !state.opened)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { state.regions["avatar"] = $0 }
    }
    var body: some View {
        SessionCurrentDJCard(sessionID: moment.sessionID, state: .expanded, mood: nil, mediaFirst: !state.opened) {
            Color.clear.frame(width: 80, height: 80)
        } detail: {
            if state.opened {
                AskDJMomentsCatalogue(inventory: inventory, language: "en", unavailableLabel: "Unavailable", select: { _ in })
            } else if let impression = moment.liveImpression {
                VStack {
                    LiveImpressionStoryView(impression: impression, title: moment.title, lead: moment.summary,
                        story: moment.content, language: "en", avatar: AnyView(avatar)) {
                            Button("Declared photo fixture") { state.photos += 1 }
                                .frame(width: 240, height: 100).buttonStyle(.bordered)
                                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { state.regions["photo"] = $0 }
                        }
                    if let url = moment.nativeSourceURLs.first {
                        Link("Original source", destination: url).frame(minHeight: 44)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { state.regions["source"] = $0 }
                    }
                }
            }
        }
        .onAppear { state.mounts += 1 }
        .padding(20).frame(width: 600, height: 800, alignment: .topLeading)
        .environment(\.djConnectGlassEffectsEnabled, false)
        .environment(\.openURL, OpenURLAction { _ in state.sources += 1; return .handled })
    }
}

/// One native input outcome; expected actions stay explicit rather than inferred
/// from the implementation or its callback timing.
private struct MomentsNativeInputOutcome {
    let clickCount: Int
    let opens: Int
    let jokes: [DJConnectPersonaReactionKind]

    static let single = Self(clickCount: 1, opens: 1, jokes: [])
    static let double = Self(clickCount: 2, opens: 0, jokes: [.playful])
    static let triple = Self(clickCount: 3, opens: 0, jokes: [.easterEgg])
}

/// Owns the native window, event delivery and observation for one scenario.
/// The fixture is freshly mounted for every input sequence, as in the original.
@MainActor private final class MomentsNativeInputScenario {
    private let state = MomentsNativeInputState()
    private let host: NSHostingView<MomentsNativeInputFixture>
    private let window: NSWindow

    init(moment: DJConnectMoment, inventory: DJConnectAskDJMoments.Inventory) {
        host = NSHostingView(rootView: MomentsNativeInputFixture(state: state, moment: moment, inventory: inventory))
        window = NSWindow(contentRect: .init(x: -20000, y: -20000, width: 600, height: 800), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderBack(nil)
    }

    func exercise(_ outcome: MomentsNativeInputOutcome) async throws {
        defer { window.close() }
        for _ in 0..<100 {
            host.layoutSubtreeIfNeeded()
            if state.regions.count == 3 { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        try await checkNestedControls()
        try await checkAvatar(outcome)
    }

    private func checkNestedControls() async throws {
        try await click(try #require(state.regions["photo"]), count: 1)
        try await awaitDelivery { self.state.photos == 1 }
        try await observeNoCascade()
        try await click(try #require(state.regions["source"]), count: 1)
        try await awaitDelivery { self.state.sources == 1 }
        try await observeNoCascade()
        #expect(state.photos == 1 && state.sources == 1)
        #expect(state.opens == 0 && state.jokes.isEmpty)
    }

    private func checkAvatar(_ outcome: MomentsNativeInputOutcome) async throws {
        let avatar = try #require(state.regions["avatar"])
        #expect(avatar.width >= 44 && avatar.height >= 44)
        try await click(avatar, count: outcome.clickCount)
        try await awaitDelivery {
            self.state.opens == outcome.opens && self.state.jokes == outcome.jokes
        }
        try await observeNoCascade()
        #expect(state.opens == outcome.opens)
        #expect(state.jokes == outcome.jokes)
        #expect(state.mounts == 1)
    }

    private func click(_ region: CGRect, count: Int) async throws {
        let point = host.convert(CGPoint(x: region.midX, y: region.midY), to: nil)
        for index in 1...count {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil, eventNumber: index, clickCount: index, pressure: type == .leftMouseDown ? 1 : 0))
                window.sendEvent(event)
            }
            try await Task.sleep(for: .milliseconds(40))
        }
    }

    private func awaitDelivery(_ delivered: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !delivered(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    // A native failure dependency may deliver after an async task's fixed
    // grace under MainActor load. Wait for the action, then independently
    // observe a whole click interval so cascaded/duplicate actions fail.
    private func observeNoCascade() async throws {
        try await Task.sleep(for: .seconds(NSEvent.doubleClickInterval + 0.1))
    }
}

/// Real AppKit click events exercise native failure dependencies and hit regions.
/// This is component input evidence, not installed iPhone/VoiceOver acceptance.
@Test(.isolatedAppKitResources) @MainActor func momentsLiveMiniAvatarSeparatesSingleDoubleTripleAndPhotoSourceControls() async throws {
    _ = NSApplication.shared
    let url = try #require(askDJMomentsFixtureURL("live-final"))
    let fixture = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let response = try JSONDecoder().decode(DJConnectAskDJMoments.Response.self,
        from: JSONSerialization.data(withJSONObject: try #require(fixture["accepted_http_response"])))
    let inventory = try JSONDecoder().decode(DJConnectAskDJMoments.Inventory.self,
        from: JSONSerialization.data(withJSONObject: try #require(fixture["inventory"])))
    let moment = try #require(response.result?.moment)
    for outcome in [MomentsNativeInputOutcome.single, .double, .triple] {
        try await MomentsNativeInputScenario(moment: moment, inventory: inventory).exercise(outcome)
    }
}
#endif
