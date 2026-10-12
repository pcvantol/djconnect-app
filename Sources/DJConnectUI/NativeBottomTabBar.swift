#if os(iOS)
import SwiftUI
import UIKit

/// UIKit owns the floating tab bar and hit testing; screen content stays SwiftUI.
struct NativeBottomTabBar: UIViewControllerRepresentable {
    var screens: [AnyView]
    var titles: [String]
    var symbols: [String]
    var scenePhase: ScenePhase
    @Binding var selection: Int

    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }

    func makeUIViewController(context: Context) -> UITabBarController {
        let controller = UITabBarController()
        controller.overrideUserInterfaceStyle = .dark
        controller.mode = .tabBar
        controller.traitOverrides.horizontalSizeClass = .compact
        controller.tabBar.tintColor = UIColor(djConnectAccent)
        controller.delegate = context.coordinator
        context.coordinator.hosts = screens.enumerated().map { index, screen in
            let host = UIHostingController(rootView: hostedScreen(screen))
            host.view.backgroundColor = .clear
            host.tabBarItem = UITabBarItem(title: titles[index], image: UIImage(systemName: symbols[index]), tag: index)
            return host
        }
        controller.setViewControllers(context.coordinator.hosts, animated: false)
        controller.selectedIndex = selection
        return controller
    }

    func updateUIViewController(_ controller: UITabBarController, context: Context) {
        context.coordinator.selection = $selection
        for (index, host) in context.coordinator.hosts.enumerated() {
            host.rootView = hostedScreen(screens[index])
            host.tabBarItem.title = titles[index]
        }
        if controller.selectedIndex != selection { controller.selectedIndex = selection }
    }

    private func hostedScreen(_ screen: AnyView) -> AnyView {
        AnyView(screen.environment(\.colorScheme, .dark)
            .environment(\.scenePhase, scenePhase).tint(djConnectAccent))
    }

    @MainActor final class Coordinator: NSObject, UITabBarControllerDelegate {
        var selection: Binding<Int>
        var hosts: [UIHostingController<AnyView>] = []
        init(selection: Binding<Int>) { self.selection = selection }
        func tabBarController(_ controller: UITabBarController, didSelect viewController: UIViewController) {
            selection.wrappedValue = controller.selectedIndex
        }
    }
}
#endif
