import DJConnectUI
import SwiftUI

@main
struct DJConnectMacApp: App {
    @StateObject private var model = DJConnectAppModel.preview

    var body: some Scene {
        WindowGroup {
            DJConnectRootView(model: model)
                .frame(minWidth: 820, minHeight: 560)
        }

        Settings {
            DJConnectSettingsView(model: model)
                .frame(width: 460, height: 360)
        }
    }
}
