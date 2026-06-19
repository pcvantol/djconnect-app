import DJConnectCore
import DJConnectUI
import AppKit
import SwiftUI

@main
struct DJConnectMacApp: App {
    @StateObject private var model = DJConnectMacApp.makeModel()

    var body: some Scene {
        WindowGroup {
            DJConnectLaunchContainer(isBusy: model.isRefreshing, content: DJConnectRootView(model: model))
                .frame(minWidth: 1120, idealWidth: 1280, minHeight: 880, idealHeight: 1060)
                .background(WindowConfigurator())
        }
        .windowStyle(.hiddenTitleBar)

        Settings {
            DJConnectSettingsView(model: model)
                .frame(width: 460, height: 360)
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
