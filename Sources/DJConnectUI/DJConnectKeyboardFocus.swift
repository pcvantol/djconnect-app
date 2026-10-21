import SwiftUI
#if os(macOS)
import AppKit
#endif

extension View {
    func djConnectMouseBackNavigation() -> some View {
        modifier(DJConnectMouseBackNavigation())
    }
    func djConnectButtonStyle(_ style: DJConnectButtonStyle) -> some View {
        buttonStyle(style)
    }
    func djConnectPlainButtonStyle() -> some View {
        #if os(macOS)
        buttonStyle(.borderless)
        #else
        buttonStyle(.plain)
        #endif
    }
}

private struct DJConnectMouseBackNavigation: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var isActive = false
    func body(content: Content) -> some View {
        #if os(macOS)
        content.background(MouseBackEventView(isActive: isActive, action: { dismiss() }).allowsHitTesting(false))
            .onAppear { isActive = true }
            .onDisappear { isActive = false }
        #else
        content
        #endif
    }
}

#if os(macOS)
private struct MouseBackEventView: NSViewRepresentable {
    let isActive: Bool
    let action: () -> Void
    func makeNSView(context: Context) -> MouseBackView {
        let view = MouseBackView(action: action); view.navigationActive = isActive; return view
    }
    func updateNSView(_ view: MouseBackView, context: Context) {
        view.action = action; view.navigationActive = isActive
    }
    static func dismantleNSView(_ view: MouseBackView, coordinator: ()) { view.stopMonitoring() }
}

final class MouseBackView: NSView {
    var action: () -> Void
    var navigationActive = false
    private var monitor: Any?
    private var consumedPress = false
    init(action: @escaping () -> Void) { self.action = action; super.init(frame: .zero) }
    required init?(coder: NSCoder) { nil }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown, .otherMouseUp]) { [weak self] event in
            guard let self else { return event }
            return self.handle(type: event.type, button: event.buttonNumber, eventWindow: event.window) ? nil : event
        }
    }
    func handle(type: NSEvent.EventType, button: Int, eventWindow: NSWindow?) -> Bool {
        guard navigationActive, !isHiddenOrHasHiddenAncestor,
              button == 3, let window, eventWindow === window else { return false }
        if type == .otherMouseUp {
            let consumed = consumedPress; consumedPress = false
            return consumed
        }
        guard type == .otherMouseDown, window.attachedSheet == nil else { return false }
        consumedPress = true
        action()
        return true
    }
    func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil; consumedPress = false
    }
}
#endif
