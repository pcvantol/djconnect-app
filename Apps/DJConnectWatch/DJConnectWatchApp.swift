import SwiftUI
import WatchKit

@main
struct DJConnectWatchApp: App {
    @WKExtensionDelegateAdaptor(DJConnectWatchExtensionDelegate.self) private var extensionDelegate
    @StateObject private var model = DJConnectWatchApp.makeModel()

    var body: some Scene {
        WindowGroup {
            DJConnectWatchRootView()
                .environmentObject(model)
                .onAppear {
                    extensionDelegate.model = model
                }
        }
    }

    private static func makeModel() -> DJConnectWatchModel {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--monkey-testing") {
            return DJConnectWatchModel(monkeyTestingMode: true)
        }
        #endif
        return DJConnectWatchModel()
    }
}

final class DJConnectWatchExtensionDelegate: NSObject, WKExtensionDelegate {
    weak var model: DJConnectWatchModel?

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        model?.handleRemoteNotificationDeviceToken(deviceToken)
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        model?.handleRemoteNotificationRegistrationError(error)
    }

    func didReceiveRemoteNotification(
        _ userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (WKBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            await model?.syncAskDJHistoryFromPush()
            completionHandler(.newData)
        }
    }
}
