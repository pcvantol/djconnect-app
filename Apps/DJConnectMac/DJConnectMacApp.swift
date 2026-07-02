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
        WindowGroup {
            DJConnectLaunchContainer(isBusy: model.isRefreshing, content: DJConnectRootView(model: model))
                .frame(minWidth: 1120, idealWidth: 1280, minHeight: 880, idealHeight: 1060)
                .background(WindowConfigurator())
                .onAppear {
                    appDelegate.model = model
                }
        }
        .windowStyle(.hiddenTitleBar)

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

        Window("VibeCast", id: "vibecast") {
            VibeCastOutputView(model: model)
                .frame(minWidth: 960, idealWidth: 1280, minHeight: 540, idealHeight: 720)
                .background(Color.black)
        }
        .defaultSize(width: 1280, height: 720)
        .windowStyle(.hiddenTitleBar)
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

private let mainWindowIdentifier = NSUserInterfaceItemIdentifier("DJConnectMainWindow")

@MainActor
final class DJConnectMacAppDelegate: NSObject, NSApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    weak var model: DJConnectAppModel? {
        didSet {
            flushPendingRemoteNotificationRegistration()
        }
    }
    private var pendingRemoteNotificationDeviceToken: Data?
    private var pendingRemoteNotificationRegistrationError: Error?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        if let model {
            model.handleRemoteNotificationDeviceToken(deviceToken)
        } else {
            pendingRemoteNotificationDeviceToken = deviceToken
            pendingRemoteNotificationRegistrationError = nil
        }
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        if let model {
            model.handleRemoteNotificationRegistrationError(error)
        } else {
            pendingRemoteNotificationRegistrationError = error
            pendingRemoteNotificationDeviceToken = nil
        }
    }

    func application(
        _ application: NSApplication,
        didReceiveRemoteNotification userInfo: [String: Any]
    ) {
        Task { @MainActor in
            await model?.refreshAskDJHistory()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NSApp.activate(ignoringOtherApps: true)
        model?.performHomeScreenAction(.askDJ)
        Task { @MainActor [weak self] in
            await self?.model?.refreshAskDJHistory()
        }
        completionHandler()
    }

    private func flushPendingRemoteNotificationRegistration() {
        guard let model else {
            return
        }
        if let pendingRemoteNotificationDeviceToken {
            self.pendingRemoteNotificationDeviceToken = nil
            model.handleRemoteNotificationDeviceToken(pendingRemoteNotificationDeviceToken)
        }
        if let pendingRemoteNotificationRegistrationError {
            self.pendingRemoteNotificationRegistrationError = nil
            model.handleRemoteNotificationRegistrationError(pendingRemoteNotificationRegistrationError)
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

            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.toolbarStyle = .unifiedCompact
            window.identifier = mainWindowIdentifier
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
                guard let parentWindow = NSApp.windows.first(where: { $0.identifier == mainWindowIdentifier }) else {
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
