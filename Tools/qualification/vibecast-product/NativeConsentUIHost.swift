import Foundation
import SwiftUI
import DJConnectCore
@testable import DJConnectUI

/// Disposable simulator host for the production native form. All HTTP responses
/// and owner credentials are synthetic. Never part of a shipping target.
@MainActor final class NativeConsentUIHarness: ObservableObject {
    let model: DJConnectAppModel
    let defaults: UserDefaults
    @Published var ready = false
    @Published var failed = false

    init() {
        defaults = UserDefaults(suiteName: "native-consent-ui-" + UUID().uuidString)!
        defaults.set("http://127.0.0.1:18801", forKey: "DJConnectHomeAssistantURL")
        defaults.set("http://127.0.0.1:18801", forKey: "DJConnectHALocalURL")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ConsentWire.self]
        model = DJConnectAppModel(defaults: defaults,
            tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-owner"),
            urlSession: URLSession(configuration: config), startBackgroundTasks: false)
        model.language = "en"
    }

    func prepare() async {
        do {
            func fixture(_ name: String) throws -> [String: Any] {
                let url = Bundle.main.url(forResource: name, withExtension: "json")!
                return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
            }
            let response = try fixture("session-history-active-session-before-auth-failure")["response"] as! [String: Any]
            let session = response["session"] as! [String: Any]
            let originalID = session["session_id"] as! String
            func rebind(_ value: Any) -> Any {
                if let text = value as? String, text == originalID { return "fixture-session" }
                if let dict = value as? [String: Any] { return dict.mapValues(rebind) }
                if let array = value as? [Any] { return array.map(rebind) }
                return value
            }
            let history = try fixture("session-history-producer-receipt")["later_historical_answer"]!
            let caps: [String: Any] = ["capabilities": ["session_conversation_history": true, "session_flow_text_search": true],
                "contract_versions": ["session_conversation_history": 1, "session_flow_text_search": 1]]
            ConsentWire.reset(ProcessInfo.processInfo.environment["CONSENT_UI_MODE"] ?? "normal")
            ConsentWire.installBootstrap(try [
                "/api/djconnect/v1/session/active": JSONSerialization.data(withJSONObject: rebind(response)),
                "/api/djconnect/v1/capabilities": JSONSerialization.data(withJSONObject: caps),
                "/api/djconnect/v1/ask_dj/history": JSONSerialization.data(withJSONObject: history)])
            model.pairingStatus = .paired
            guard await model.refreshActiveDJSession() else { failed = true; return }
            await model.sessionHistory.prepare()
            defaults.set("fixture-install", forKey: "DJConnectHAInstallID")
            ready = model.canResolveDisplayConsent
            failed = !ready
        } catch { failed = true }
    }
}

struct NativeConsentUIRoot: View {
    @ObservedObject var harness: NativeConsentUIHarness
    @State private var showingForm = false
    var body: some View {
        VStack {
            Text("Isolated synthetic consent qualification")
            if harness.failed { Text("setup-failed").accessibilityIdentifier("consent-harness-failed") }
            Button("Open native form") {
                showingForm = true
            }
            .disabled(!harness.ready).accessibilityIdentifier("consent-harness-open")
        }
        .task { await harness.prepare() }
        .sheet(isPresented: $showingForm) { NativeConsentFormHarness(harness: harness) }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
    }
}

struct NativeConsentFormHarness: View {
    @ObservedObject var harness: NativeConsentUIHarness
    @State private var approvals = 0
    @State private var canResolve = false
    var body: some View {
        VStack {
            Text("approvals:\(approvals)").accessibilityIdentifier("consent-harness-approvals")
            Button("Withdraw synthetic Profile") {
                ConsentWire.withdrawOwner()
                harness.model.sessionHistory.suspend()
            }
            .accessibilityIdentifier("consent-harness-withdraw")
            Text("allowed:" + String(canResolve)).accessibilityIdentifier("consent-harness-allowed")
            VibeCastDisplayConsentForm(model: harness.model)
        }
        #if os(macOS)
        .frame(width: 560, height: 560)
        #endif
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .task {
            while !Task.isCancelled {
                canResolve = harness.model.canResolveDisplayConsent
                approvals = ConsentWire.requests.filter { $0.url?.path.hasSuffix("/owner/approve") == true }.count
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}

@main struct NativeConsentUIHost: App {
    @StateObject private var harness = NativeConsentUIHarness()
    var body: some Scene {
        #if os(macOS)
        Window("Synthetic VibeCast qualification", id: "native-consent") {
            NativeConsentUIRoot(harness: harness).frame(width: 640, height: 640)
        }
        .defaultLaunchBehavior(.presented)
        #else
        WindowGroup { NativeConsentUIRoot(harness: harness) }
        #endif
    }
}
