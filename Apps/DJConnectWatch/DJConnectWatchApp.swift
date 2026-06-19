import SwiftUI

@main
struct DJConnectWatchApp: App {
    @StateObject private var model = DJConnectWatchApp.makeModel()

    var body: some Scene {
        WindowGroup {
            DJConnectWatchRootView()
                .environmentObject(model)
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
