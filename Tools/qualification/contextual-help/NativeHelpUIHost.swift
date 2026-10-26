import Foundation
import SwiftUI
import DJConnectCore
@testable import DJConnectUI

/// Disposable view-only host. Synthetic qualification never enters shipping
/// resources; no pairing, network, command send or audio is possible. The optional
/// composer probe uses an isolated tokenless AppModel with background work off.
@main struct NativeHelpUIHost: App {
    var body: some Scene {
        #if os(macOS)
        Window("Synthetic contextual Help qualification", id: "help-test") {
            host.frame(width: 700, height: 800)
        }.defaultLaunchBehavior(.presented)
        #else
        WindowGroup { host }
        #endif
    }
    @ViewBuilder private var host: some View {
        if ProcessInfo.processInfo.environment["HELP_COMPOSER_POPOUT"] == "1" { HelpComposerPopoutProbe() }
        else { HelpProbe() }
    }
}

@MainActor private struct HelpProbe: View {
    private let catalogue: DJConnectAskDJCatalogue?
    private let original: DJConnectAskDJCatalogue.Context
    private let eligibleIDs: Set<String>
    private let language = ProcessInfo.processInfo.environment["HELP_LANGUAGE"] ?? "nl"
    private let surface = DJConnectAskDJCatalogue.Surface(rawValue: ProcessInfo.processInfo.environment["HELP_SURFACE"] ?? "ask_dj")!
    private let large = ProcessInfo.processInfo.environment["HELP_LARGE"] == "1"
    @State private var expiry: Date?
    @State private var available = true
    @State private var session = true
    @State private var presented = false
    @State private var selected = ""
    @State private var composerChoice: DJConnectAskDJCatalogue.HelpItem?
    @State private var composerDismissal = UUID()
    private let interaction = ProcessInfo.processInfo.environment["HELP_INTERACTION"] == "1"
    private let fullCatalogue = ProcessInfo.processInfo.environment["HELP_FULL_CATALOGUE"] == "1"
    init() {
        let url = Bundle.main.url(forResource: "askdj-catalogue-selector-golden-v1", withExtension: "json")!
        let root = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        eligibleIDs = Set(((root["synthetic_catalogue"] as? [String: Any])?["entries"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String })
        let qualified = ProcessInfo.processInfo.environment["HELP_SYNTHETIC"] == "1"
        catalogue = qualified ? try! JSONDecoder().decode(DJConnectAskDJCatalogue.self,
            from: JSONSerialization.data(withJSONObject: root["synthetic_catalogue"]!)) : .bundled
        let raw = (root["cases"] as! [[String: Any]])[0]["context"] as! [String: Any]
        var value = DJConnectAskDJCatalogue.Context()
        value.descriptor = try! JSONDecoder().decode(DJConnectAskDJCatalogue.Descriptor.self,
            from: JSONSerialization.data(withJSONObject: raw["catalogue"]!))
        value.contracts = raw["contracts"] as! [String: Int]
        value.slots = raw["slots"] as! [String: String]
        for (key, flag) in raw where flag is Bool { value.flags[key] = flag as? Bool }
        if ProcessInfo.processInfo.environment["HELP_FULL_CATALOGUE"] == "1",
           let entries = (root["synthetic_catalogue"] as? [String: Any])?["entries"] as? [[String: Any]] {
            for entry in entries {
                for flag in entry["requires"] as? [String] ?? [] { value.flags[flag] = true }
            }
        }
        value.ownerEpoch = "synthetic-owner"; value.sessionID = "synthetic-session"; value.trackID = "synthetic-track"
        original = value
    }
    private func context(at now: Date) -> DJConnectAskDJCatalogue.Context {
        var value = original
        if let expiry, now >= expiry {
            for key in ["current_track", "current_album", "forecast_ready"] { value.flags[key] = false }
            value.trackID = nil; value.slots = [:]
        }
        if !available { value.descriptor = nil; value.ownerEpoch = "withdrawn-owner" }
        if !session { value.flags["active_session"] = false; value.sessionID = nil }
        return value
    }
    var body: some View {
        VStack(spacing: 12) {
            Text("Synthetic reference qualification — no commands or HTTP").font(.caption)
            if fullCatalogue {
                AskDJHelpEntry(surface: surface, language: language, presented: $presented, showsMoreLabel: true, onDismissed: {
                    composerDismissal = UUID()
                }) {
                    AskDJFullCatalogueReference(sections: catalogue?.catalogueSections(context(at: Date()), surface: surface,
                        language: language, eligibleIDs: eligibleIDs) ?? [],
                        busy: false, enabled: available, language: language) { item in
                        selected = (item.requiresInput ? "draft:" : "send:") + item.prompt
                        composerChoice = item
                        presented = false
                    }
                }
                Text(selected).accessibilityIdentifier("help-selected-prompt")
                if ProcessInfo.processInfo.environment["HELP_COMPOSER"] == "1" {
                    HelpComposerProbe(item: composerChoice, dismissal: composerDismissal)
                }
            } else if interaction {
                AskDJHelpEntry(surface: surface, language: language, presented: $presented) { reference }
                AskDJSuggestionRows(suggestions: catalogue?.select(context(at: Date()), surface: surface,
                    language: language, epoch: "fixed-native-visit") ?? [], surface: surface, disabled: presented) {
                    selected = $0.prompt
                }
                Text(selected).accessibilityIdentifier("help-selected-prompt")
            }
            HStack {
                Button("Expire track") { expiry = Date().addingTimeInterval(2) }.accessibilityIdentifier("help-expire-track")
                Button("Withdraw owner") { available = false }.accessibilityIdentifier("help-withdraw-owner")
                Button("End session") { session = false }.accessibilityIdentifier("help-end-session")
            }
            if !interaction && !fullCatalogue { reference }
        }
        .padding(16)
        .environment(\.colorScheme, large ? .light : .dark)
        .preferredColorScheme(large ? .light : .dark)
        .dynamicTypeSize(large ? .accessibility3 : .large)
    }
    private var reference: some View {
        AskDJHelpReference(catalogue: catalogue, surface: surface, language: language,
                           trackExpiresAt: expiry, context: { context(at: $0) })
    }
}

/// Optional real composer only: isolated empty preferences, no token, background
/// tasks disabled and Send/voice disabled. No HTTP or command can be issued.
@MainActor private struct HelpComposerProbe: View {
    let item: DJConnectAskDJCatalogue.HelpItem?
    let dismissal: UUID
    @StateObject private var model: DJConnectAppModel
    @FocusState private var focused: Bool
    @State private var dismissals = 0
    @State private var domain: String
    init(item: DJConnectAskDJCatalogue.HelpItem?, dismissal: UUID) {
        self.item = item
        self.dismissal = dismissal
        let name = "help-composer-probe-" + UUID().uuidString
        _domain = State(initialValue: name)
        _model = StateObject(wrappedValue: DJConnectAppModel(defaults: UserDefaults(suiteName: name)!,
            tokenStore: DJConnectInMemoryTokenStore(token: nil), startBackgroundTasks: false))
    }
    var body: some View {
        VStack {
        Text("dismissals:\(dismissals) range:\(model.askDJCatalogueInputSelection != nil) request:\(model.askDJCatalogueFocusRequest != nil) focus:\(focused)")
            .font(.caption).accessibilityIdentifier("help-composer-diagnostics")
        AskDJInputBar(model: model, canSend: false, canUseVoiceInput: false,
                      isInputFocused: $focused, surfaceColors: nil)
            .onChange(of: item) { _, item in
                guard let item, item.requiresInput else { return }
                model.askDJDraft = item.prompt
                model.askDJCatalogueInputSelection = item.inputRange
            }
            .onChange(of: dismissal) { _, _ in
                dismissals += 1
                if model.askDJCatalogueInputSelection != nil { model.askDJCatalogueFocusRequest = UUID() }
            }
            .onDisappear { UserDefaults.standard.removePersistentDomain(forName: domain) }
        }
    }
}

/// Real production composer, existing-content layouts and real closed shipping
/// catalogue. This test does not fabricate three qualified suggestions.
@MainActor private struct HelpComposerPopoutProbe: View {
    @StateObject private var model: DJConnectAppModel
    @FocusState private var focused: Bool
    private let domain: String
    private let surface = DJConnectAskDJCatalogue.Surface(rawValue: ProcessInfo.processInfo.environment["HELP_SURFACE"] ?? "ask_dj")!
    private let populated = ProcessInfo.processInfo.environment["HELP_POPULATED"] == "1"
    init() {
        let name = "help-composer-popout-" + UUID().uuidString
        domain = name
        let model = DJConnectAppModel(defaults: UserDefaults(suiteName: name)!,
            tokenStore: DJConnectInMemoryTokenStore(token: nil), startBackgroundTasks: false)
        model.language = "en"
        _model = StateObject(wrappedValue: model)
    }
    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            ScrollView {
                VStack(spacing: 22) {
                    Text("UI qualification · closed catalogue · no network").foregroundStyle(.white)
                    if populated {
                        ForEach(0..<8) { number in
                            Text("Synthetic existing conversation item \(number)")
                                .padding(22).frame(maxWidth: .infinity)
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                    Button("Defocus") { focused = false }.accessibilityIdentifier("help-probe-defocus")
                }.padding()
            }
            .safeAreaInset(edge: .bottom) {
                AskDJInputBar(model: model, canSend: false, canUseVoiceInput: false,
                    isInputFocused: $focused, floating: true, helpSurface: surface)
                    .padding(.horizontal, 12)
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { UserDefaults(suiteName: domain)?.removePersistentDomain(forName: domain) }
    }
}
