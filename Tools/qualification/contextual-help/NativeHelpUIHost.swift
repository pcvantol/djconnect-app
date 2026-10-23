import Foundation
import SwiftUI
import DJConnectCore
@testable import DJConnectUI

/// Disposable view-only host. Synthetic qualification never enters shipping
/// resources or AppModel; no pairing, network, command send or audio is possible.
@main struct NativeHelpUIHost: App {
    var body: some Scene {
        #if os(macOS)
        Window("Synthetic contextual Help qualification", id: "help-test") {
            HelpProbe().frame(width: 700, height: 800)
        }.defaultLaunchBehavior(.presented)
        #else
        WindowGroup { HelpProbe() }
        #endif
    }
}

@MainActor private struct HelpProbe: View {
    private let catalogue: DJConnectAskDJCatalogue?
    private let original: DJConnectAskDJCatalogue.Context
    private let language = ProcessInfo.processInfo.environment["HELP_LANGUAGE"] ?? "nl"
    private let surface = DJConnectAskDJCatalogue.Surface(rawValue: ProcessInfo.processInfo.environment["HELP_SURFACE"] ?? "ask_dj")!
    private let large = ProcessInfo.processInfo.environment["HELP_LARGE"] == "1"
    @State private var expiry: Date?
    @State private var available = true
    @State private var session = true
    init() {
        let url = Bundle.main.url(forResource: "askdj-catalogue-selector-golden-v1", withExtension: "json")!
        let root = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
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
            HStack {
                Button("Expire track") { expiry = Date().addingTimeInterval(2) }.accessibilityIdentifier("help-expire-track")
                Button("Withdraw owner") { available = false }.accessibilityIdentifier("help-withdraw-owner")
                Button("End session") { session = false }.accessibilityIdentifier("help-end-session")
            }
            AskDJHelpReference(catalogue: catalogue, surface: surface, language: language,
                               trackExpiresAt: expiry, context: { context(at: $0) })
        }
        .padding(16)
        .environment(\.colorScheme, large ? .light : .dark)
        .preferredColorScheme(large ? .light : .dark)
        .dynamicTypeSize(large ? .accessibility3 : .large)
    }
}
