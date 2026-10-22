import DJConnectCore
import DJConnectUI
import AppKit
import SwiftUI
import UserNotifications

@main
struct DJConnectMacApp: App {
    @NSApplicationDelegateAdaptor(DJConnectMacAppDelegate.self) private var appDelegate
    @StateObject private var model = DJConnectMacApp.makeModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("DJConnect", id: "main") {
            DJConnectLaunchContainer(isBusy: model.isRefreshing, content: DJConnectRootView(model: model))
                .frame(minWidth: 960, idealWidth: 1280, minHeight: 800, idealHeight: 1060)
                .background(WindowConfigurator())
                .onAppear {
                    appDelegate.openMainWindow = { openWindow(id: "main") }
                    appDelegate.model = model
                }
        }
        .windowStyle(.titleBar)
        #if DEBUG
        .defaultLaunchBehavior(ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--runtime-fixture") }) ? .presented : .automatic)
        #endif

        Settings {
            DJConnectSettingsView(model: model)
                .frame(width: 520, height: 640)
                .background(MenuWindowCenteringConfigurator())
        }

        Window(localizedAboutTitle(for: model.language), id: "about") {
            DJConnectAboutView(model: model)
                .frame(width: 520, height: 620)
                .background(MenuWindowCenteringConfigurator())
        }
        .defaultSize(width: 520, height: 620)
        .windowResizability(.contentSize)

        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(localizedAboutMenuTitle(for: model.language)) {
                    openWindow(id: "about")
                }
            }
        }
    }

    private static func makeModel() -> DJConnectAppModel {
        #if DEBUG
        let processInfo = ProcessInfo.processInfo
        if processInfo.arguments.contains("--runtime-fixture") || processInfo.arguments.contains(where: { $0.hasPrefix("--runtime-fixture=") }) {
            let suiteName = "dev.djconnect.mac.runtime-tests"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            defaults.set(true, forKey: "DJConnectWelcomeSeen")
            if let url = processInfo.environment["DJCONNECT_UITEST_HA_URL"] { defaults.set(url, forKey: "DJConnectHomeAssistantURL") }
            let fixture = processInfo.environment["DJCONNECT_UITEST_RUNTIME_FIXTURE"] ?? "moment_contract"
            if ["session_history_contract", "paired_owner_contract"].contains(fixture) { defaults.set("ABCDEF123456", forKey: "DJConnectInstallID") }
            let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), homeAssistantWebSocketAuth: fixture == "session_history_contract" ? DJConnectAppModel.sessionHistoryTestWebSocketAuth(token: processInfo.environment["DJCONNECT_UITEST_HA_WS_TOKEN"]) : nil, startBackgroundTasks: false)
            model.applyUITestRuntimeFixture(fixture)
            return model
        }
        if processInfo.arguments.contains("--monkey-testing") {
            let suiteName = "dev.djconnect.mac.monkeytests"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            defaults.set(true, forKey: "DJConnectWelcomeSeen")
            return DJConnectAppModel(
                defaults: defaults,
                tokenStore: DJConnectInMemoryTokenStore(),
                monkeyTestingMode: true
            )
        }
        #endif
        return DJConnectAppModel(
            tokenStore: DJConnectUserDefaultsTokenStore(key: "DJConnectMacDeviceToken")
        )
    }
}

private func localizedAboutTitle(for language: String) -> String {
    DJConnectLocalization.localized(key: "mac.about", language: language)
}

private func localizedAboutMenuTitle(for language: String) -> String {
    DJConnectLocalization.localized(key: "mac.about.djconnect", language: language)
}

private let mainWindowAccessibilityIdentifier = "DJConnectMainWindow"

@MainActor
final class DJConnectMacAppDelegate: NSObject, NSApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    weak var model: DJConnectAppModel? {
        didSet {
            flushPendingPushCallbacks()
            flushPendingURL()
        }
    }
    var openMainWindow: (() -> Void)?
    private var pendingURL: URL?
    private var pendingPush = DJConnectPushStartupBuffer()

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme?.lowercased() == "djconnect" {
            pendingURL = url
            flushPendingURL()
        }
        presentMainWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        presentMainWindow()
        return false
    }

    private func presentMainWindow() {
        // Window(id:) is a singleton; openWindow brings it forward or reopens it.
        if let window = NSApp.windows.first(where: { $0.accessibilityIdentifier() == mainWindowAccessibilityIdentifier }) {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            openMainWindow?()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func flushPendingURL() {
        guard let url = pendingURL, let model else { return }
        pendingURL = nil
        if !model.handleAppNavigationDeepLink(url) { model.handlePairingDeepLink(url) }
    }

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        if let model {
            model.handleRemoteNotificationDeviceToken(deviceToken)
        } else {
            pendingPush.received(token: deviceToken)
        }
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        if let model {
            model.handleRemoteNotificationRegistrationError(error)
        } else {
            pendingPush.failed(error)
        }
    }

    func application(
        _ application: NSApplication,
        didReceiveRemoteNotification userInfo: [String: Any]
    ) {
        Task { @MainActor in
            let payload = userInfo.reduce(into: [AnyHashable: Any]()) { $0[AnyHashable($1.key)] = $1.value }
            if let model { _ = await model.handleRemoteNotificationPayload(payload) }
            else { pendingPush.enqueue(payload) }
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
        NSApp.activate(ignoringOtherApps: true)
        Task { @MainActor [weak self] in
            guard let self else { completionHandler(); return }
            let payload = response.notification.request.content.userInfo
            let handled: Bool
            if let model { handled = await model.handleRemoteNotificationPayload(payload, openedFromTap: true) }
            else { handled = pendingPush.enqueue(payload, openedFromTap: true) }
            if !handled {
                self.model?.performHomeScreenAction(.askDJ)
            }
            completionHandler()
        }
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

private struct WindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.configure(window: nsView.window)
        }
    }

    @MainActor
    final class Coordinator {
        private weak var configuredWindow: NSWindow?

        func configure(window: NSWindow?) {
            guard let window, configuredWindow !== window else {
                return
            }
            configuredWindow = window

            // Native window chrome must not reveal other windows behind the app.
            window.titlebarAppearsTransparent = false
            window.titleVisibility = .hidden
            // Reserve native titlebar/toolbar space, including traffic lights revealed in fullscreen.
            window.styleMask.remove(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.backgroundColor = .windowBackgroundColor
            window.isOpaque = true
            window.toolbarStyle = .unifiedCompact
            // SwiftUI owns the restoration identifier. Replacing it makes saved
            // windows unresolvable by SwiftUI.AppWindowsController on relaunch.
            window.setAccessibilityIdentifier(mainWindowAccessibilityIdentifier)
            // Keep restored windows within the screen instead of centering oversized content.
            if let visible = (window.screen ?? NSScreen.main)?.visibleFrame {
                var frame = window.frame
                frame.size.width = min(frame.width, visible.width)
                frame.size.height = min(frame.height, visible.height)
                frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
                frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
                if frame != window.frame { window.setFrame(frame, display: true) }
            }
        }
    }
}

private struct MenuWindowCenteringConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.center(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.center(window: nsView.window)
        }
    }

    @MainActor
    final class Coordinator {
        private weak var centeredWindow: NSWindow?

        func center(window: NSWindow?) {
            guard let window, centeredWindow !== window else {
                return
            }

            DispatchQueue.main.async {
                guard let parentWindow = NSApp.windows.first(where: { $0.accessibilityIdentifier() == mainWindowAccessibilityIdentifier }) else {
                    return
                }
                window.center(in: parentWindow)
                self.centeredWindow = window
            }
        }
    }
}

private extension NSWindow {
    func center(in parentWindow: NSWindow) {
        let parentFrame = parentWindow.frame
        let ownFrame = frame
        let origin = NSPoint(
            x: parentFrame.midX - ownFrame.width / 2,
            y: parentFrame.midY - ownFrame.height / 2
        )
        setFrameOrigin(origin)
    }
}
