import DJConnectCore
import DJConnectUI
import SwiftUI
import UIKit
import UserNotifications

@main
struct DJConnectIOSApp: App {
    @UIApplicationDelegateAdaptor(DJConnectIOSAppDelegate.self) private var appDelegate
    @StateObject private var model = DJConnectIOSApp.makeModel()

    var body: some Scene {
        WindowGroup {
            DJConnectLaunchContainer(isBusy: model.isRefreshing, content: DJConnectRootView(model: model))
                .onAppear {
                    appDelegate.model = model
                    appDelegate.updateVibeCastSignal()
                }
                .onChange(of: model.currentTrackInsight) {
                    appDelegate.updateVibeCastSignal()
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

final class DJConnectIOSAppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    private let vibeCastOutputController = VibeCastExternalDisplayController()

    weak var model: DJConnectAppModel? {
        didSet {
            Task { @MainActor in
                flushPendingHomeScreenAction()
            }
            vibeCastOutputController.model = model
            updateVibeCastSignal()
        }
    }
    private var pendingHomeScreenAction: DJConnectHomeScreenAction?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        vibeCastOutputController.start()
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

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

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            await model?.refreshAskDJHistory()
            pendingHomeScreenAction = .askDJ
            flushPendingHomeScreenAction()
            completionHandler()
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
        if let url = options.urlContexts.first?.url {
            handle(url)
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            configuration.delegateClass = VibeCastExternalDisplaySceneDelegate.self
        }
        return configuration
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

    @discardableResult
    private func handle(_ url: URL) -> Bool {
        guard let action = DJConnectHomeScreenAction(deepLinkURL: url) else {
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
        model.performHomeScreenAction(action)
    }

    func updateVibeCastSignal() {
        vibeCastOutputController.update()
    }
}

@MainActor
private final class VibeCastExternalDisplaySceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        VibeCastExternalDisplayController.updateActiveController()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        VibeCastExternalDisplayController.updateActiveController()
    }
}

@MainActor
private final class VibeCastExternalDisplayController {
    private static weak var activeController: VibeCastExternalDisplayController?

    weak var model: DJConnectAppModel?
    private var outputWindows: [String: UIWindow] = [:]
    private var observers: [NSObjectProtocol] = []

    init() {
        Self.activeController = self
    }

    static func updateActiveController() {
        activeController?.update()
    }

    func start() {
        guard observers.isEmpty else {
            return
        }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.update() }
        })
        observers.append(center.addObserver(forName: UIScene.didDisconnectNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.update() }
        })
        update()
    }

    func update() {
        guard let model, model.currentTrackInsight != nil else {
            clear()
            return
        }
        let scenes = externalWindowScenes
        guard !scenes.isEmpty else {
            clear()
            return
        }
        let activeSessionIDs = Set(scenes.map { $0.session.persistentIdentifier })
        for staleID in outputWindows.keys where !activeSessionIDs.contains(staleID) {
            outputWindows[staleID]?.isHidden = true
            outputWindows[staleID] = nil
        }
        for scene in scenes {
            let sessionID = scene.session.persistentIdentifier
            let window = outputWindows[sessionID] ?? UIWindow(windowScene: scene)
            window.rootViewController = UIHostingController(rootView: VibeCastOutputView(model: model))
            window.windowLevel = .normal
            window.isHidden = false
            outputWindows[sessionID] = window
        }
    }

    private var externalWindowScenes: [UIWindowScene] {
        UIApplication.shared.connectedScenes.compactMap { scene in
            guard let windowScene = scene as? UIWindowScene,
                  windowScene.session.role == .windowExternalDisplayNonInteractive else {
                return nil
            }
            return windowScene
        }
    }

    private func clear() {
        outputWindows.values.forEach { $0.isHidden = true }
        outputWindows.removeAll()
    }

}
