import SwiftUI
import DJConnectCore

extension EnvironmentValues {
    @Entry var djContentDeleteAction: (@MainActor () -> Void)? = nil
}

extension View {
    func djContentDeletion(model: DJConnectAppModel?, target: DJConnectContentDeleteTarget?) -> some View {
        modifier(OptionalContentDeletion(model: model, target: target))
    }
}

struct ContentDeletionPendingNotice: View {
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject private var history: DJConnectSessionHistoryModel
    init(model: DJConnectAppModel) { self.model = model; history = model.sessionHistory }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(DJConnectLocalization.localized(key: "ui.session.history.delete.unconfirmed", language: model.language))
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            if history.canCheckContentDeletionStatus {
                Button(DJConnectLocalization.localized(key: "ui.content.delete.status", language: model.language)) {
                    Task { await history.checkContentDeletionStatus() }
                }.buttonStyle(.borderless).accessibilityIdentifier("content-deletion-status")
            }
        }.accessibilityIdentifier("history-deletion-unconfirmed")
    }
}

private struct OptionalContentDeletion: ViewModifier {
    let model: DJConnectAppModel?
    let target: DJConnectContentDeleteTarget?
    @ViewBuilder func body(content: Content) -> some View {
        if let model, let target { content.modifier(ContentDeletionActions(model: model, target: target)) }
        else { content }
    }
}

private struct ContentDeletionActions: ViewModifier {
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject private var history: DJConnectSessionHistoryModel
    let target: DJConnectContentDeleteTarget
    @State private var prepared: DJConnectContentDeleteScope?
    @State private var capturedEpoch = UUID()
    @State private var generation = UUID()
    @State private var preparing = false
    @State private var confirming = false
    @State private var failed = false
    @State private var submitted = false
    @State private var revealed = false
    init(model: DJConnectAppModel, target: DJConnectContentDeleteTarget) {
        self.model = model; history = model.sessionHistory; self.target = target
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    private var enabled: Bool { !preparing && history.canDeleteContent(target) }
    private func begin() {
        guard enabled else { return }
        revealed = false; preparing = true
        let token = UUID(), epoch = history.responseEpoch
        generation = token; capturedEpoch = epoch
        Task { @MainActor in
            let scope = await history.prepareContentDeletion(target, expectedEpoch: epoch)
            guard generation == token else { return }
            preparing = false
            guard history.responseEpoch == epoch, !Task.isCancelled else { return }
            guard let scope else { failed = true; return }
            prepared = scope; confirming = true
        }
    }
    private var deletionButton: some View {
        Button(role: .destructive, action: begin) {
            Label(text("ui.content.delete.action"), systemImage: "trash")
        }.disabled(!enabled).accessibilityIdentifier("content-delete-" + target.target_id)
    }
    func body(content: Content) -> some View {
        Group {
            if target.kind == "moment", history.contentMomentWasWithdrawn(sessionID: target.session_id, momentID: target.target_id) {
                Text(text("ui.session.history.contribution_unavailable"))
                    .fixedSize(horizontal: false, vertical: true)
            } else { content }
        }
            .environment(\.djContentDeleteAction, enabled ? begin : nil)
            .offset(x: revealed ? -64 : 0)
            .background(alignment: .trailing) {
                if revealed {
                    Button(role: .destructive, action: begin) {
                        Image(systemName: "trash").frame(width: 56, height: 56)
                    }.buttonStyle(.borderless).foregroundStyle(.red)
                    .background {
                        ContentSwipeTapDismissal {
                            withAnimation(.easeOut(duration: 0.2)) { revealed = false }
                        }
                    }
                    .accessibilityLabel(text("ui.content.delete.action"))
                    .accessibilityIdentifier("content-swipe-delete-" + target.target_id)
                }
            }
            .clipped()
            .contextMenu { if history.contentDeletionAvailable { deletionButton } }
            // Rows live in LazyVStack/ScrollView, where native List.swipeActions
            // does not operate. Horizontal reveal leaves vertical scrolling intact.
            .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { value in
                guard enabled, abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                if value.translation.width < -64 { withAnimation { revealed = true } }
                else if value.translation.width > 32 { withAnimation { revealed = false } }
            })
            .alert(text("ui.content.delete.confirm"), isPresented: $confirming, presenting: prepared) { scope in
                Button(text("ui.cancel"), role: .cancel) { prepared = nil }
                Button(text("ui.content.delete.action"), role: .destructive) {
                    let token = generation, epoch = capturedEpoch
                    prepared = nil; submitted = true
                    Task { @MainActor in
                        let deleted = await history.deleteContent(scope, expectedEpoch: epoch)
                        guard token == generation else { return }
                        submitted = false
                        if !deleted { failed = true }
                    }
                }.accessibilityIdentifier("content-delete-confirm")
            } message: { _ in Text(text("ui.content.delete.playback")) }
            .alert(text(history.hasUnconfirmedDeletion ? "ui.session.history.delete.unconfirmed" : "ui.session.history.delete.failed"), isPresented: $failed) {
                Button(text("ui.close"), role: .cancel) {}
            }
            .onChange(of: history.responseEpoch) { _, _ in
                if submitted { prepared = nil; confirming = false; revealed = false }
                else { reset() }
            }
            .onChange(of: target) { _, _ in reset() }
            .onDisappear { reset() }
    }
    private func reset() {
        generation = UUID(); preparing = false; prepared = nil; confirming = false; revealed = false; failed = false; submitted = false
    }
}

// Mounted only while the trash action is revealed. Observe the window without
// covering other controls; the trash button itself remains actionable.
#if os(iOS)
import UIKit

struct ContentSwipeTapDismissal: UIViewRepresentable {
    let dismiss: () -> Void
    func makeUIView(context: Context) -> TapProbe {
        let view = TapProbe()
        view.isUserInteractionEnabled = false
        view.dismiss = dismiss
        return view
    }
    func updateUIView(_ view: TapProbe, context: Context) { view.dismiss = dismiss }
    static func dismantleUIView(_ view: TapProbe, coordinator: ()) { view.detach() }

    final class TapProbe: UIView, UIGestureRecognizerDelegate {
        var dismiss: (() -> Void)?
        private weak var observedWindow: UIWindow?
        private lazy var tap: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            return recognizer
        }()
        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            if let window { observedWindow = window; window.addGestureRecognizer(tap) }
        }
        func detach() {
            observedWindow?.removeGestureRecognizer(tap)
            observedWindow = nil
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let window else { return false }
            return !convert(bounds, to: window).contains(touch.location(in: window))
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
        @objc private func tapped() { dismiss?() }
    }
}
#elseif os(macOS)
import AppKit

struct ContentSwipeTapDismissal: NSViewRepresentable {
    let dismiss: () -> Void
    func makeNSView(context: Context) -> TapProbe {
        let view = TapProbe(); view.dismiss = dismiss; return view
    }
    func updateNSView(_ view: TapProbe, context: Context) { view.dismiss = dismiss }
    static func dismantleNSView(_ view: TapProbe, coordinator: ()) { view.detach() }

    final class TapProbe: NSView {
        var dismiss: (() -> Void)?
        private var monitor: Any?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            detach()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.observe(event)
                return event
            }
        }
        func observe(_ event: NSEvent) {
            guard let window, event.window === window,
                  !bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
            dismiss?()
        }
        func detach() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
#endif
