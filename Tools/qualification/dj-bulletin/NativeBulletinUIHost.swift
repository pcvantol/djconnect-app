import Foundation
import SwiftUI
import DJConnectCore
@testable import DJConnectUI

/// Disposable view-only qualification. No app model, pairing, HTTP, RSS, SDK,
/// audio preparation/output, publication or persisted private state is created.
@main struct NativeBulletinUIHost: App {
    private let moment: DJConnectMoment
    private let language = ProcessInfo.processInfo.environment["BULLETIN_LANGUAGE"] ?? "nl"
    private let largeText = ProcessInfo.processInfo.environment["BULLETIN_LARGE_TEXT"] == "1"
    private let light = ProcessInfo.processInfo.environment["BULLETIN_LIGHT"] == "1"
    init() {
        let url = Bundle.main.url(forResource: "dj-bulletin-v1-core-preparatory-wire", withExtension: "json")!
        let root = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let sample = root["sample"] as! [String: Any]
        moment = try! JSONDecoder().decode(DJConnectMoment.self,
            from: JSONSerialization.data(withJSONObject: sample["moment"]!))
    }
    private var content: some View {
        Group {
            if ProcessInfo.processInfo.environment["DELETION_MENU_PROBE"] == "1" { DeletionMenuProbe() }
            else { bulletinContent }
        }
    }
    private var bulletinContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Synthetic Core fixture — view-only qualification")
                    .font(.caption).accessibilityIdentifier("bulletin-qualification-caption")
                MomentCard(moment: moment,
                    kind: DJConnectLocalization.localized(key: "ui.session.moment.dj_bulletin", language: language),
                    presentation: nil, language: language)
                    .padding(24)
                    .djSessionFrostedSurface(mood: moment.presentationIntent.sourceSessionMood)
                    .accessibilityIdentifier("bulletin-qualified-component")
            }
            .padding(20).frame(maxWidth: 1000)
        }
        .background(LinearGradient(colors: DJConnectSessionMoodPalette(mood: moment.presentationIntent.sourceSessionMood ?? "groove").colors,
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .environment(\.colorScheme, light ? .light : .dark)
        .dynamicTypeSize(largeText ? .accessibility3 : .large)
        .preferredColorScheme(light ? .light : .dark)
    }
    var body: some Scene {
        #if os(macOS)
        Window("Synthetic DJ Bulletin view qualification", id: "bulletin-test") {
            content.frame(width: 700, height: 700)
        }
        .defaultLaunchBehavior(.presented)
        #else
        WindowGroup { content }
        #endif
    }
}

/// Synthetic environment churn only. No delete request, model, owner token or server effect.
@MainActor private struct DeletionMenuProbe: View {
    @State private var revision = 0
    @State private var confirmations = 0
    @State private var identity = UUID()
    @State private var owner = NSObject()
    private let message = DJConnectAskDJMessage(id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
        role: .dj, text: "Synthetic retained DJ answer", createdAt: .distantPast)
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Synthetic menu updates: \(revision)").accessibilityIdentifier("deletion-probe-updates")
            Text("Confirmations: \(confirmations)").accessibilityIdentifier("deletion-probe-confirmations")
            AskDJMessageBubble(message: message, language: "en", isStaleHistory: false,
                isAudioLoading: false, isAudioPlaying: false, isRetryDisabled: true,
                playingActionID: nil, currentMood: nil, isSearchResult: false,
                isActiveSearchResult: false, searchText: "", retryAction: {}, playAction: { _ in },
                audioAction: {}, trackInsightAction: {}, openLink: { _ in }, feedbackAction: { _ in }, setPromptAction: { _ in })
                .environment(\.djContentDeleteAction, ContentDeleteAction(identity: identity,
                    owner: ObjectIdentifier(owner), target: .init(kind: "message", sessionID: "", targetID: "synthetic-retained-message"),
                    perform: { confirmations += 1 }))
                .environment(\.djContentDeletionEnabled, true)
                .accessibilityIdentifier("deletion-probe-bubble")
            Spacer()
        }
        .padding(24).frame(minWidth: 300, minHeight: 400)
        .task {
            for index in 1...60 {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                revision = index
            }
        }
    }
}
