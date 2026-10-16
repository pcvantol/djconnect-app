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
        let controller = KeyboardAwareTabBarController()
        controller.introductionAnchors = context.environment.sessionIntroductionAnchors
        controller.overrideUserInterfaceStyle = .dark
        controller.mode = .tabBar
        controller.traitOverrides.horizontalSizeClass = .compact
        controller.tabBar.tintColor = UIColor(djConnectAccent)
        controller.delegate = context.coordinator
        context.coordinator.hosts = screens.enumerated().map { index, screen in
            let host = UIHostingController(rootView: hostedScreen(screen, anchors: context.environment.sessionIntroductionAnchors))
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
        (controller as? KeyboardAwareTabBarController)?.introductionAnchors = context.environment.sessionIntroductionAnchors
        controller.view.setNeedsLayout()
        for (index, host) in context.coordinator.hosts.enumerated() {
            host.rootView = hostedScreen(screens[index], anchors: context.environment.sessionIntroductionAnchors)
            host.tabBarItem.title = titles[index]
        }
        if controller.selectedIndex != selection { controller.selectedIndex = selection }
    }

    private func hostedScreen(_ screen: AnyView, anchors: SessionIntroductionAnchors?) -> AnyView {
        AnyView(screen.environment(\.sessionIntroductionAnchors, anchors).environment(\.colorScheme, .dark)
            .environment(\.scenePhase, scenePhase).tint(djConnectAccent))
    }

    /// UIKit also updates the content safe area when hiding its tab bar, so
    /// the composer moves down into the space released above the keyboard.
    @MainActor final class KeyboardAwareTabBarController: UITabBarController {
        weak var introductionAnchors: SessionIntroductionAnchors?
        override func viewDidLoad() {
            super.viewDidLoad()
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardFrameChanged(_:)),
                name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)),
                name: UIResponder.keyboardWillHideNotification, object: nil)
        }

        deinit { NotificationCenter.default.removeObserver(self) }

        @objc private func keyboardFrameChanged(_ notification: Notification) {
            guard let window = viewIfLoaded?.window,
                  notification.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool != false,
                  let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let windowFrame = window.convert(frame, from: window.screen.coordinateSpace)
            // SwiftUI may already have reduced this controller's frame above
            // the keyboard. The window still covers the complete scene.
            let overlap = window.bounds.intersection(windowFrame)
            setTabBarHidden(!overlap.isNull && overlap.height > 1, animated: true)
        }

        @objc private func keyboardWillHide(_ notification: Notification) {
            guard viewIfLoaded?.window != nil else { return }
            setTabBarHidden(false, animated: true)
        }
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
