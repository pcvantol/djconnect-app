import DJConnectUI
import SwiftUI

@main
struct DJConnectIOSApp: App {
    @StateObject private var model = DJConnectAppModel()

    var body: some Scene {
        WindowGroup {
            DJConnectLaunchContainer {
                DJConnectRootView(model: model)
            }
        }
    }
}
