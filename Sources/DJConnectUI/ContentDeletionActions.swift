import SwiftUI
import DJConnectCore

/// Stable environment identity keeps ordinary row updates from invalidating an
/// already open native context menu merely because a new closure was created.
struct ContentDeleteAction: Equatable {
    let identity: UUID
    let owner: ObjectIdentifier
    let target: DJConnectContentDeleteTarget
    var epoch: UUID? = nil
    var unavailableReasonKey: String? = nil
    var recovery: (@MainActor () -> Void)? = nil
    let perform: @MainActor () -> Void
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.identity == rhs.identity && lhs.owner == rhs.owner && lhs.target == rhs.target &&
        lhs.epoch == rhs.epoch && lhs.unavailableReasonKey == rhs.unavailableReasonKey && (lhs.recovery != nil) == (rhs.recovery != nil)
    }
}

/// Both conversation and Session menus expose the same reason and safe recovery.
struct ContentDeletionMenuItems: View {
    let action: ContentDeleteAction
    let enabled: Bool
    let language: String
    var identifier: String? = nil
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
    var body: some View {
        Button(role: .destructive, action: action.perform) {
            Label(text("ui.content.delete.action"), systemImage: "trash")
        }
        .disabled(!enabled)
        .accessibilityIdentifier(identifier ?? "content-delete-" + action.target.target_id)
        if !enabled, let key = action.unavailableReasonKey { Text(text(key)) }
        if let recover = action.recovery {
            Button(action: recover) {
                Label(text("ui.content.delete.recover_previous"), systemImage: "arrow.clockwise")
            }.accessibilityIdentifier("content-delete-recover-" + action.target.target_id)
        }
    }
}

extension EnvironmentValues {
    @Entry var djContentDeleteAction: ContentDeleteAction? = nil
    @Entry var djContentDeletionEnabled = false
}

extension View {
    func djContentDeletion(model: DJConnectAppModel?, target: DJConnectContentDeleteTarget?, providesContextMenu: Bool = true) -> some View {
        modifier(OptionalContentDeletion(model: model, target: target, providesContextMenu: providesContextMenu))
    }
}

struct ContentDeletionPendingNotice: View {
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject private var history: DJConnectSessionHistoryModel
    init(model: DJConnectAppModel) { self.model = model; history = model.sessionHistory }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(DJConnectLocalization.localized(key: history.contentDeletionNeedsReadback
                ? "ui.content.delete.readback.pending" : "ui.session.history.delete.unconfirmed", language: model.language))
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            if history.contentDeletionBusy {
                ProgressView(DJConnectLocalization.localized(key: "ui.content.delete.checking", language: model.language))
                    .controlSize(.small)
            } else if history.canCheckContentDeletionStatus {
                Button(DJConnectLocalization.localized(key: history.contentDeletionNeedsReadback
                    ? "ui.content.delete.refresh" : "ui.content.delete.status", language: model.language)) {
                    Task { await history.checkContentDeletionStatus() }
                }.buttonStyle(.borderless).accessibilityIdentifier("content-deletion-status")
            }
        }.accessibilityIdentifier("history-deletion-unconfirmed")
    }
}

private extension View {
    @ViewBuilder func contentDeletionContextMenu<Menu: View>(provided: Bool, @ViewBuilder menu: () -> Menu) -> some View {
        if provided { contextMenu(menuItems: menu) }
        else { self }
    }
}

private struct OptionalContentDeletion: ViewModifier {
    let model: DJConnectAppModel?
    let target: DJConnectContentDeleteTarget?
    let providesContextMenu: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if let model, let target { content.modifier(ContentDeletionActions(model: model, target: target, providesContextMenu: providesContextMenu)) }
        else { content }
    }
}

private struct ContentDeletionActions: ViewModifier {
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject private var history: DJConnectSessionHistoryModel
    let target: DJConnectContentDeleteTarget
    let providesContextMenu: Bool
    @State private var actionIdentity = UUID()
    @State private var prepared: DJConnectContentDeleteScope?
    @State private var capturedEpoch = UUID()
    @State private var generation = UUID()
    @State private var preparing = false
    @State private var confirming = false
    @State private var failed = false
    @State private var submitted = false
    @State private var revealed = false
    init(model: DJConnectAppModel, target: DJConnectContentDeleteTarget, providesContextMenu: Bool) {
        self.model = model; history = model.sessionHistory; self.target = target
        self.providesContextMenu = providesContextMenu
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
    private var recoveryAction: (@MainActor () -> Void)? {
        guard history.canCheckContentDeletionStatus, !preparing else { return nil }
        let epoch = history.responseEpoch
        return {
            Task { @MainActor in
                guard history.responseEpoch == epoch else { return }
                _ = await history.checkContentDeletionStatus()
            }
        }
    }
    private var deletionAction: ContentDeleteAction {
        ContentDeleteAction(identity: actionIdentity, owner: ObjectIdentifier(model), target: target,
            epoch: history.responseEpoch, unavailableReasonKey: preparing ? "ui.content.delete.blocked.busy" : history.contentDeletionBlockingReason(for: target),
            recovery: recoveryAction, perform: begin)
    }
    func body(content: Content) -> some View {
        Group {
            if target.kind == "moment", history.contentMomentWasWithdrawn(sessionID: target.session_id, momentID: target.target_id) {
                Text(text("ui.session.history.contribution_unavailable"))
                    .fixedSize(horizontal: false, vertical: true)
            } else { content }
        }
            // Keep the menu item mounted while eligibility changes; begin() still
            // rechecks permission and prepares a fresh server-bound scope.
            .environment(\.djContentDeleteAction, deletionAction)
            .environment(\.djContentDeletionEnabled, enabled)
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
            // Include the glass card's empty space in native long-press targeting.
            .contentShape(Rectangle())
            .contentDeletionContextMenu(provided: providesContextMenu) {
                if history.contentDeletionAvailable {
                    ContentDeletionMenuItems(action: deletionAction, enabled: enabled, language: model.language)
                }
            }
            // The native context menu owns long press and its feedback. Do not
            // install a second recognizer over the same conversation card.
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
            .alert(text(history.hasUnconfirmedDeletion ? "ui.content.delete.unconfirmed" : "ui.content.delete.failed"), isPresented: $failed) {
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


struct ContentRemovalAnimation: ViewModifier {
    @ObservedObject var history: DJConnectSessionHistoryModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: history.contentRemovalRevision)
    }
}
