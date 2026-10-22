import DJConnectCore
import DJConnectUI
import SwiftUI
import UIKit
import UserNotifications

@main
struct DJConnectIOSApp: App {
    @UIApplicationDelegateAdaptor(DJConnectIOSAppDelegate.self) private var appDelegate
    @StateObject private var model: DJConnectAppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Eager registration also covers an intent that cold-launches the app
        // before SwiftUI first evaluates the root content.
        let model = Self.makeRegisteredModel()
        _model = StateObject(wrappedValue: model)
    }

    private static func makeRegisteredModel() -> DJConnectAppModel {
        let model = makeModel()
        DJConnectSessionPlaybackIntentBridge.nextTrack = { [weak model] presentationID in
            await model?.skipTrackFromLiveActivity(presentationID: presentationID) ?? false
        }
        return model
    }

    var body: some Scene {
        // SwiftUI may evaluate the scene content builder on its async render thread.
        // Read actor-isolated app state here, before the nonisolated builder runs.
        let content = DJConnectLaunchContainer(isBusy: model.isRefreshing, content: DJConnectRootView(model: model))
            .onAppear {
                appDelegate.model = model
                updateSessionShortcut()
            }
            .onChange(of: model.homeScreenSessionActionTitle) { updateSessionShortcut() }
            .onChange(of: scenePhase) { updateSessionShortcut() }
        return WindowGroup { @Sendable in
            content
        }
    }

    private func updateSessionShortcut() {
        DJConnectIOSAppDelegate.setSessionShortcut(title: model.homeScreenSessionActionTitle)
    }

    private static func makeModel() -> DJConnectAppModel {
        #if DEBUG
        let processInfo = ProcessInfo.processInfo
        let bundledPhysicalTestURL = Bundle.main.object(forInfoDictionaryKey: "DJConnectPhysicalHistoryTestURL") as? String
        let bundledPhysicalTest = Bundle.main.object(forInfoDictionaryKey: "DJConnectPhysicalHistoryTestEnabled") as? Bool == true
        if processInfo.arguments.contains("--uitesting") || processInfo.arguments.contains("--monkey-testing") || bundledPhysicalTest {
            let suiteName = "dev.djconnect.uitests"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            let shouldShowWelcome = processInfo.environment["DJCONNECT_UITEST_SHOW_WELCOME"] == "1"
            defaults.set(!shouldShowWelcome, forKey: "DJConnectWelcomeSeen")
            if let homeAssistantURL = bundledPhysicalTest ? bundledPhysicalTestURL : processInfo.environment["DJCONNECT_UITEST_HA_URL"], !homeAssistantURL.isEmpty {
                defaults.set(homeAssistantURL, forKey: "DJConnectHomeAssistantURL")
            }
            let runtimeFixture = bundledPhysicalTest ? "session_history_contract" : processInfo.environment["DJCONNECT_UITEST_RUNTIME_FIXTURE"]
                ?? launchArgumentValue(named: "--runtime-fixture", arguments: processInfo.arguments)
                ?? launchArgumentValue(named: "-DJCONNECTRuntimeFixture", arguments: processInfo.arguments)
            if let runtimeFixture, ["session_history_contract", "paired_owner_contract"].contains(runtimeFixture) {
                defaults.set("ABCDEF123456", forKey: "DJConnectInstallID")
            }
            let tokenStore = DJConnectInMemoryTokenStore(
                token: nil
            )
            let model = DJConnectAppModel(
                defaults: defaults,
                tokenStore: tokenStore,
                homeAssistantWebSocketAuth: runtimeFixture == "session_history_contract" ? DJConnectAppModel.sessionHistoryTestWebSocketAuth(token: processInfo.environment["DJCONNECT_UITEST_HA_WS_TOKEN"]) : nil,
                startBackgroundTasks: runtimeFixture == nil,
                monkeyTestingMode: processInfo.arguments.contains("--monkey-testing")
            )
            if let runtimeFixture, !runtimeFixture.isEmpty {
                model.applyUITestRuntimeFixture(runtimeFixture,
                    physicalTestHost: bundledPhysicalTest ? bundledPhysicalTestURL.flatMap { URL(string: $0)?.host } : nil)
            }
            #if targetEnvironment(simulator)
            // Test-owned preferences/token store above. Inject raw QR through
            // the shipping dispatcher; this is not optical camera qualification.
            if let qr = processInfo.environment["DJCONNECT_UITEST_RENDEZVOUS_QR"] {
                _ = model.handlePairingQRCode(qr)
            }
            #endif
            return model
        }
        #endif
        return DJConnectAppModel(
            tokenStore: DJConnectUserDefaultsTokenStore(key: "DJConnectIOSDeviceToken")
        )
    }

    private static func launchArgumentValue(named name: String, arguments: [String]) -> String? {
        let prefix = "\(name)="
        if let value = arguments.first(where: { $0.hasPrefix(prefix) })?.dropFirst(prefix.count),
           !value.isEmpty {
            return String(value)
        }
        guard let index = arguments.firstIndex(of: name),
              arguments.indices.contains(arguments.index(after: index)) else {
            return nil
        }
        let value = arguments[arguments.index(after: index)]
        return value.isEmpty ? nil : value
    }

}

final class DJConnectIOSAppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {

    weak var model: DJConnectAppModel? {
        didSet {
            Task { @MainActor in
                flushPendingPushCallbacks()
                flushPendingHomeScreenAction()
            }
        }
    }
    private var pendingHomeScreenAction: DJConnectHomeScreenAction?
    private var pendingPush = DJConnectPushStartupBuffer()

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Dynamic only: static entries are additive and would leave duplicate actions.
        Self.setSessionShortcut(title: DJConnectLocalization.localized(key: "ui.session.start"))
        return true
    }

    static func setSessionShortcut(title: String) {
        UIApplication.shared.shortcutItems = [UIApplicationShortcutItem(
            type: DJConnectHomeScreenAction.djSession.rawValue,
            localizedTitle: title,
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "headphones"),
            userInfo: nil
        )]
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        if let model { model.handleRemoteNotificationDeviceToken(deviceToken) }
        else { pendingPush.received(token: deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        if let model { model.handleRemoteNotificationRegistrationError(error) }
        else { pendingPush.failed(error) }
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            guard let model else {
                pendingPush.enqueue(userInfo)
                completionHandler(.noData)
                return
            }
            let handled = await model.handleRemoteNotificationPayload(userInfo)
            completionHandler(handled ? .newData : .noData)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            let payload = notification.request.content.userInfo
            if let model { _ = await model.handleRemoteNotificationPayload(payload) }
            else { pendingPush.enqueue(payload) }
            completionHandler([.banner, .list, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            let payload = response.notification.request.content.userInfo
            let handled: Bool
            if let model { handled = await model.handleRemoteNotificationPayload(payload, openedFromTap: true) }
            else { handled = pendingPush.enqueue(payload, openedFromTap: true) }
            if !handled {
                pendingHomeScreenAction = .askDJ
            }
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
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = DJConnectIOSSceneDelegate.self
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
    func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = DJConnectHomeScreenAction(rawValue: shortcutItem.type) else {
            return false
        }
        pendingHomeScreenAction = action
        flushPendingHomeScreenAction()
        return true
    }

    @discardableResult
    func handle(_ url: URL) -> Bool {
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


    private func flushPendingPushCallbacks() {
        guard let model else { return }
        let batch = pendingPush.drain()
        if let token = batch.token { model.handleRemoteNotificationDeviceToken(token) }
        if let error = batch.error { model.handleRemoteNotificationRegistrationError(error) }
        guard !batch.deliveries.isEmpty else { return }
        Task { @MainActor [weak model] in
            for delivery in batch.deliveries {
                guard let model else { return }
                _ = await model.handleRemoteNotificationPayload(delivery.userInfo, openedFromTap: delivery.openedFromTap)
            }
        }
    }
}

final class DJConnectIOSSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let shortcutItem = connectionOptions.shortcutItem {
            _ = appDelegate?.handle(shortcutItem)
        }
        if let url = connectionOptions.urlContexts.first?.url {
            _ = appDelegate?.handle(url)
        }
        refreshSupportedOrientations(in: scene)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        refreshSupportedOrientations(in: scene)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(appDelegate?.handle(shortcutItem) ?? false)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }
        _ = appDelegate?.handle(url)
    }

    private var appDelegate: DJConnectIOSAppDelegate? {
        UIApplication.shared.delegate as? DJConnectIOSAppDelegate
    }

    private func refreshSupportedOrientations(in scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }
        for window in windowScene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        if #available(iOS 16.0, *) {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .allButUpsideDown))
        }
    }
}
