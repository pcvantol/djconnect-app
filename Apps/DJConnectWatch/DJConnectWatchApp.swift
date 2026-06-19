import SwiftUI

@main
struct DJConnectWatchApp: App {
    @StateObject private var model = DJConnectWatchModel()

    var body: some Scene {
        WindowGroup {
            DJConnectWatchRootView()
                .environmentObject(model)
        }
    }
}
