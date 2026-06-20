import DJConnectCore
import DJConnectUI
import SwiftUI
import UIKit

@main
struct DJConnectIOSApp: App {
    @UIApplicationDelegateAdaptor(DJConnectIOSAppDelegate.self) private var appDelegate
    @StateObject private var model = DJConnectIOSApp.makeModel()

    var body: some Scene {
        WindowGroup {
            DJConnectLaunchContainer(isBusy: model.isRefreshing, content: DJConnectRootView(model: model))
                .onAppear {
                    appDelegate.model = model
                }
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
                model.seedAskDJOnAirDemoMessagesForTesting()
            }
            return model
        }
        #endif
        return DJConnectAppModel(
            tokenStore: DJConnectUserDefaultsTokenStore(key: "DJConnectIOSDeviceToken")
        )
    }
}

final class DJConnectIOSAppDelegate: NSObject, UIApplicationDelegate {
    weak var model: DJConnectAppModel?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        model?.handleRemoteNotificationDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        model?.handleRemoteNotificationRegistrationError(error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            await model?.refreshAskDJHistory()
            completionHandler(.newData)
        }
    }
}
