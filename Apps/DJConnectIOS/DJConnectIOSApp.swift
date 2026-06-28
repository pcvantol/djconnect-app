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
            return model
        }
        #endif
        return DJConnectAppModel(
            tokenStore: DJConnectUserDefaultsTokenStore(key: "DJConnectIOSDeviceToken")
        )
    }
}

final class DJConnectIOSAppDelegate: NSObject, UIApplicationDelegate {
    weak var model: DJConnectAppModel? {
        didSet {
            flushPendingHomeScreenAction()
        }
    }
    private var pendingHomeScreenAction: DJConnectHomeScreenAction?

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

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            handle(shortcutItem)
        }
        return UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(handle(shortcutItem))
    }

    @discardableResult
    private func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = DJConnectHomeScreenAction(rawValue: shortcutItem.type) else {
            return false
        }
        pendingHomeScreenAction = action
        flushPendingHomeScreenAction()
        return true
    }

    private func flushPendingHomeScreenAction() {
        guard let action = pendingHomeScreenAction, let model else {
            return
        }
        pendingHomeScreenAction = nil
        Task { @MainActor in
            model.performHomeScreenAction(action)
        }
    }
}
