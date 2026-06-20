import DJConnectCore
import DJConnectUI
import SwiftUI

@main
struct DJConnectIOSApp: App {
    @StateObject private var model = DJConnectIOSApp.makeModel()

    var body: some Scene {
        WindowGroup {
            DJConnectLaunchContainer(isBusy: model.isRefreshing, content: DJConnectRootView(model: model))
        }
    }

    private static func makeModel() -> DJConnectAppModel {
        #if DEBUG
        let processInfo = ProcessInfo.processInfo
        if processInfo.arguments.contains("--uitesting") || processInfo.arguments.contains("--monkey-testing") {
            let suiteName = "dev.djconnect.uitests"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            defaults.set(true, forKey: "DJConnectWelcomeSeen")
            if let homeAssistantURL = processInfo.environment["DJCONNECT_UITEST_HA_URL"], !homeAssistantURL.isEmpty {
                defaults.set(homeAssistantURL, forKey: "DJConnectHomeAssistantURL")
            }
            let model = DJConnectAppModel(
                defaults: defaults,
                tokenStore: DJConnectInMemoryTokenStore(),
                monkeyTestingMode: processInfo.arguments.contains("--monkey-testing")
            )
            if processInfo.arguments.contains("--on-air-demo-feed") {
                model.seedAskDJPartyDemoMessagesForTesting()
            }
            return model
        }
        #endif
        return DJConnectAppModel(
            tokenStore: DJConnectUserDefaultsTokenStore(key: "DJConnectIOSDeviceToken")
        )
    }
}
