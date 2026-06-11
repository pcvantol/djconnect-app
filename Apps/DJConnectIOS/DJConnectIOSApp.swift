import DJConnectCore
import DJConnectUI
import SwiftUI

@main
struct DJConnectIOSApp: App {
    @StateObject private var model = DJConnectIOSApp.makeModel()

    var body: some Scene {
        WindowGroup {
            DJConnectLaunchContainer(content: DJConnectRootView(model: model))
        }
    }

    private static func makeModel() -> DJConnectAppModel {
        #if DEBUG
        let processInfo = ProcessInfo.processInfo
        if processInfo.arguments.contains("--uitesting") {
            let suiteName = "nl.pcvantol.djconnect.uitests"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            defaults.set("nl", forKey: "DJConnectLanguage")
            defaults.set(true, forKey: "DJConnectWelcomeSeen")
            if let homeAssistantURL = processInfo.environment["DJCONNECT_UITEST_HA_URL"], !homeAssistantURL.isEmpty {
                defaults.set(homeAssistantURL, forKey: "DJConnectHomeAssistantURL")
            }
            return DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore())
        }
        #endif
        return DJConnectAppModel()
    }
}
