// Native component qualification only. Synthetic Session data, no networking,
// microphone, playback commands or persistent Profile state.
import SwiftUI
import DJConnectCore
@testable import DJConnectUI

@main struct NativeSessionIdleHost: App {
    var body: some Scene { WindowGroup { IdleProbe() } }
}

private struct IdleProbe: View {
    @State private var original = try! DJConnectDemoSessionData.make(language: "nl").active
    @State private var phase = ProcessInfo.processInfo.arguments.contains("--initial-moment") ? "moment" : "idle"
    @State private var refreshes = 0
    @State private var taps = 0
    @State private var draft = "Unsent draft"
    @State private var reading: String?
    @State private var headerVisible: Bool?
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let interaction = ProcessInfo.processInfo.arguments.contains("--interaction")
    private var language: String {
        ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--language=") })?.split(separator: "=").last.map(String.init) ?? "nl"
    }
    private var session: DJConnectSessionRuntime {
        var value = original
        if phase == "idle" { value.broadcast.nativeDelivery?.currentMomentID = nil; value.broadcast.nativeDelivery?.currentSilenceMomentID = "synthetic-silence" }
        if phase == "partial" { value.broadcast.djMoments = [] }
        if phase == "newpartial" {
            value.sessionID = "synthetic-new-session"; value.broadcast.session.sessionID = value.sessionID
            value.broadcast.nativeDelivery?.sessionID = value.sessionID; value.broadcast.djMoments = []
        }
        if phase == "paused" { value.broadcast.playback?.state = "paused" }
        if phase == "start" { value.broadcast.playback = nil }
        if phase == "ended" { value.runtimeState = "ended"; value.broadcast.session.runtimeState = "ended" }
        return value
    }
    private var moment: DJConnectMoment? { session.broadcast.nativeCurrentMoment(at: Date()) }
    @ViewBuilder private var card: some View {
        if interaction {
            // The exact shared native card and exact native multi-tap/accessibility
            // component; the callback is counted instead of sending a real command.
            SessionCurrentDJCard(sessionID: session.id,
                state: SessionCurrentDJCardState.resolve(session: session, moment: moment,
                    recovering: phase == "recovering", unavailable: phase == "unavailable", at: Date()),
                mood: session.selectedMood) {
                    PersonaReactionAvatarInteraction(
                        avatar: DJPersonaAvatarView(confirmedMood: session.selectedMood, language: language).frame(width: 80, height: 80),
                        language: language, canStart: true, request: { _ in taps += 1 })
                } detail: {
                    if let moment { MomentCard(moment: moment, kind: "Session", presentation: nil, language: language) }
                }
        } else {
            NativeSessionMomentsView(session: session, language: language,
                isRecovering: phase == "recovering", isLiveUnavailable: phase == "unavailable")
                .currentCard(moment)
        }
    }
    var body: some View {
        VStack(spacing: 8) {
            Text("phase:\(phase) refresh:\(refreshes) taps:\(taps) rm:\(reduceMotion ? 1 : 0) anchor:\(reading ?? "none") v:\(headerVisible.map { $0 ? 1 : 0 } ?? -1)")
                .font(.caption).lineLimit(1).minimumScaleFactor(0.4).frame(height: 16).accessibilityIdentifier("probe-status")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    card.onScrollVisibilityChange(threshold: 0.01) { headerVisible = $0 }
                        .accessibilityIdentifier("session-current-card")
                        .frame(maxWidth: .infinity, alignment: .leading).id("current")
                    ForEach(0..<24) { index in
                        MomentCard(moment: original.broadcast.djMoments[0], kind: "Earlier contribution \(index)", presentation: nil, language: language)
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .djSessionFrostedSurface()
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("history-\(index)").id("history-\(index)")
                    }
                }.scrollTargetLayout().padding(16)
            }
            .defaultScrollAnchor(.top, for: .initialOffset)
            .scrollPosition(id: $reading, anchor: .top)
            TextField("Draft", text: $draft).focused($focused).textFieldStyle(.roundedBorder).accessibilityIdentifier("probe-draft")
            ScrollView(.horizontal) {
                HStack {
                    ForEach(["idle", "moment", "partial", "paused", "recovering", "unavailable", "start", "newpartial"], id: \.self) { state in
                        Button(state) { phase = state }.accessibilityIdentifier("probe-" + state)
                    }
                    Button("reading cycle") {
                        Task {
                            try? await Task.sleep(for: .seconds(5)); phase = "moment"
                            try? await Task.sleep(for: .seconds(2)); phase = "partial"
                            try? await Task.sleep(for: .milliseconds(100)); phase = "moment"
                            try? await Task.sleep(for: .seconds(3)); phase = "idle"
                        }
                    }.accessibilityIdentifier("probe-reading-cycle")
                    Button("refresh") { refreshes += 1 }.accessibilityIdentifier("probe-refresh")
                    Button("cycle") {
                        focused = true
                        Task { phase = "idle"; try? await Task.sleep(for: .seconds(1)); phase = "moment"; try? await Task.sleep(for: .seconds(1)); phase = "partial"; try? await Task.sleep(for: .milliseconds(100)); phase = "moment"; try? await Task.sleep(for: .seconds(1)); phase = "idle" }
                    }.accessibilityIdentifier("probe-cycle")
                }.buttonStyle(.bordered)
            }
        }.padding(8).foregroundStyle(.white)
            .background(DJConnectCanvasBackground())
            .environment(\.djConnectScrollingSurface, true)
            .environment(\.locale, Locale(identifier: language))
            .environment(\.dynamicTypeSize, ProcessInfo.processInfo.arguments.contains("--large-text") ? .accessibility3 : .large)
            .task {
                if ProcessInfo.processInfo.arguments.contains("--record-cycle") {
                    try? await Task.sleep(for: .seconds(2)); phase = "moment"
                    try? await Task.sleep(for: .seconds(3)); phase = "idle"
                }
            }
    }
}
