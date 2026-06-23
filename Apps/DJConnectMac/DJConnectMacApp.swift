import DJConnectCore
import DJConnectUI
import AppKit
import SwiftUI

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
        }

        Window(localizedAboutTitle(for: model.language), id: "about") {
            DJConnectAboutView(model: model)
                .frame(width: 520, height: 620)
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
    language == "nl" ? "Over" : "About"
}

private func localizedAboutMenuTitle(for language: String) -> String {
    language == "nl" ? "Over DJConnect" : "About DJConnect"
}

final class DJConnectMacAppDelegate: NSObject, NSApplicationDelegate {
    weak var model: DJConnectAppModel?

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        model?.handleRemoteNotificationDeviceToken(deviceToken)
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        model?.handleRemoteNotificationRegistrationError(error)
    }

    func application(
        _ application: NSApplication,
        didReceiveRemoteNotification userInfo: [String: Any]
    ) {
        Task { @MainActor in
            await model?.refreshAskDJHistory()
        }
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else {
            return
        }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.toolbarStyle = .unifiedCompact
    }
}
