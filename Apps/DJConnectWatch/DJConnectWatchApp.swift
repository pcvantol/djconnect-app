import AVFoundation
import SwiftUI
import WatchKit
import UserNotifications
import DJConnectCore

@main
struct DJConnectWatchApp: App {
    @WKApplicationDelegateAdaptor(DJConnectWatchApplicationDelegate.self) private var applicationDelegate
    @StateObject private var model = DJConnectWatchApp.makeModel()

    var body: some Scene {
        WindowGroup {
            DJConnectWatchRootView()
                .environmentObject(model)
                .djConnectGlassPreferences()
                .onOpenURL { model.openWatchHome(from: $0) }
                .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
                    guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                          type == AVAudioSession.InterruptionType.began.rawValue else { return }
                    model.interruptWatchQuestionRecording()
                }
                .onAppear {
                    applicationDelegate.model = model
                }
        }
    }

    private static func makeModel() -> DJConnectWatchModel {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--monkey-testing") || arguments.contains(where: { $0.hasPrefix("--screenshot-screen=") }) {
            return DJConnectWatchModel(monkeyTestingMode: true)
        }
        #endif
        return DJConnectWatchModel()
    }
}

final class DJConnectWatchApplicationDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var model: DJConnectWatchModel? {
        didSet { if let pendingOpen { model?.openWatchMoment(pendingOpen); self.pendingOpen = nil } }
    }
    private var pendingOpen: DJConnectWatchMomentOpenIntent?
    func applicationDidFinishLaunching() { UNUserNotificationCenter.current().delegate = self }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Dismiss/custom actions, silent wakes and other token families cannot
        // trigger navigation. Decode before crossing the actor boundary.
        let intent = response.actionIdentifier == UNNotificationDefaultActionIdentifier
            ? try? DJConnectWatchMomentOpenIntent(notification: response.notification.request.content.userInfo) : nil
        Task { @MainActor in
            if let intent {
                if let model = self.model { model.openWatchMoment(intent) }
                else { self.pendingOpen = intent }
            }
        }
        completionHandler()
    }

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
