import DJConnectUI
import SwiftUI

@main
struct DJConnectIOSApp: App {
    @StateObject private var model = DJConnectAppModel.preview

    var body: some Scene {
        WindowGroup {
            DJConnectRootView(model: model)
        }
    }
}
