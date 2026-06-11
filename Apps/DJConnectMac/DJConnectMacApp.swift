import DJConnectUI
import SwiftUI

@main
struct DJConnectMacApp: App {
    @StateObject private var model = DJConnectAppModel()

    var body: some Scene {
        WindowGroup {
            DJConnectLaunchContainer {
                DJConnectRootView(model: model)
            }
                .frame(minWidth: 980, idealWidth: 1120, minHeight: 640, idealHeight: 760)
        }

        Settings {
            DJConnectSettingsView(model: model)
                .frame(width: 460, height: 360)
        }
    }
}
