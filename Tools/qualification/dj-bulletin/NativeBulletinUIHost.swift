import Foundation
import SwiftUI
import DJConnectCore
@testable import DJConnectUI

/// Disposable view-only qualification. No app model, pairing, HTTP, RSS, SDK,
/// audio preparation/output, publication or persisted private state is created.
@main struct NativeBulletinUIHost: App {
    private let moment: DJConnectMoment
    private let broadcast: DJConnectBroadcastState
    private let language = ProcessInfo.processInfo.environment["BULLETIN_LANGUAGE"] ?? "nl"
    private let largeText = ProcessInfo.processInfo.environment["BULLETIN_LARGE_TEXT"] == "1"
    private let light = ProcessInfo.processInfo.environment["BULLETIN_LIGHT"] == "1"
    init() {
        let url = Bundle.main.url(forResource: "dj-bulletin-v1-core-12675bc-wire", withExtension: "json")!
        let root = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let sample = root["sample"] as! [String: Any]
        moment = try! JSONDecoder().decode(DJConnectMoment.self,
            from: JSONSerialization.data(withJSONObject: sample["moment"]!))
        broadcast = try! JSONDecoder().decode(DJConnectBroadcastState.self,
            from: JSONSerialization.data(withJSONObject: sample["owner_snapshot"]!))
    }
    private var content: some View {
        Group {
            if ProcessInfo.processInfo.environment["DELETION_MENU_PROBE"] == "1" { DeletionMenuProbe() }
            else if ProcessInfo.processInfo.environment["BULLETIN_LIFECYCLE_PROBE"] == "1" {
                BulletinLifecycleProbe(original: broadcast, language: language)
            } else { bulletinContent }
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

/// Controlled fixture clock in a disposable host only. Uses the production
/// admission, chronological merge and MomentCard; no app/audio/HTTP side effects.
@MainActor private struct BulletinLifecycleProbe: View {
    let original: DJConnectBroadcastState
    let language: String
    @State private var stage = "current"
    private var broadcast: DJConnectBroadcastState {
        var value = original
        if stage == "withdrawn" { value.clearNativeAuthority() }
        return value
    }
    private var now: Date {
        let source = original.djMoments[0]
        let admission = original.nativeDelivery!.admissions.first { $0.momentID == source.id }!
        switch stage {
        case "flow": return DJConnectHistoryEntry.date(admission.displayExpiresAt!)!
        case "expired": return DJConnectHistoryEntry.date(admission.sourceExpiresAt!)!
        default: return DJConnectHistoryEntry.date(source.createdAt)!.addingTimeInterval(1)
        }
    }
    private func card(_ moment: DJConnectMoment) -> some View {
        MomentCard(moment: moment, kind: DJConnectLocalization.localized(key: "ui.session.moment.dj_bulletin", language: language),
                   presentation: nil, language: language)
            .padding(24).djSessionFrostedSurface(mood: moment.presentationIntent.sourceSessionMood)
            .accessibilityIdentifier("bulletin-lifecycle-moment")
    }
    var body: some View {
        let value = broadcast
        let current = value.nativeCurrentMoment(at: now)
        let rows = SessionTimelineLiveRow.merge(retained: [], bulletins: value.nativeFlowMoments(at: now), at: now,
                                              omittingMomentIDs: Set([current?.id].compactMap { $0 }))
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Synthetic Core publication and clock — no audio or HTTP").font(.caption)
                HStack {
                    ForEach(["current", "flow", "expired", "withdrawn"], id: \.self) { phase in
                        Button(phase) { stage = phase }.accessibilityIdentifier("bulletin-phase-" + phase)
                    }
                }
                Text(stage + " · cards " + String((current == nil ? 0 : 1) + rows.count))
                    .accessibilityIdentifier("bulletin-lifecycle-status")
                if let current { card(current) }
                ForEach(rows) { row in
                    if case .bulletin(let moment) = row { card(moment) }
                }
            }.padding(20)
        }
    }
}
