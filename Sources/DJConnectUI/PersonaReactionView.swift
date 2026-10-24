import SwiftUI
import DJConnectCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Native multi-tap recognition dispatches only its final semantic
/// choice. Context menu, VoiceOver and keyboard retain ordinary alternatives.
struct PersonaReactionAvatar<Avatar: View>: View {
    @ObservedObject var model: DJConnectAppModel
    let avatar: Avatar
    var body: some View {
        Group {
            if model.presentsPersonaReactionControl {
                PersonaReactionAvatarInteraction(avatar: avatar, language: model.language,
                    canStart: model.canStartPersonaReaction, request: { model.requestPersonaReaction($0) })
            } else { avatar }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
            model.personaAvatarFrame = frame
        }
    }
}

/// Presentation-only input. The app model rechecks original owner, Session,
/// settings, observation and busy state before every request.
struct PersonaReactionAvatarInteraction<Avatar: View>: View {
    let avatar: Avatar
    let language: String
    let canStart: Bool
    let request: (DJConnectPersonaReactionKind) -> Void
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
    var body: some View {
        avatar
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "hand.tap.fill").font(.system(size: 12)).foregroundStyle(.white)
                    .padding(5).background(.black.opacity(0.55), in: Circle()).accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .overlay { PersonaReactionTapSurface(action: request).accessibilityHidden(true) }
            .contextMenu {
                ForEach(DJConnectPersonaReactionKind.allCases, id: \.self) { kind in
                    Button(text("ui.session.reaction." + kind.rawValue)) { request(kind) }
                        .disabled(!canStart)
                }
            }
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(.return) { request(.checkIn); return .handled }
            .onKeyPress(.space) { request(.checkIn); return .handled }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(text("ui.session.reaction.hint"))
            .accessibilityAction { request(.checkIn) }
            .accessibilityAction(named: text("ui.session.reaction.playful")) { request(.playful) }
            .accessibilityAction(named: text("ui.session.reaction.easter_egg")) { request(.easterEgg) }
            .help(text("ui.session.reaction.hint"))
    }
}

struct PersonaReactionOverlay: View {
    @ObservedObject var controller: PersonaReactionController
    let language: String
    let avatarFrame: CGRect
    var animatesPresentation = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @AccessibilityFocusState private var reading: Bool
    @FocusState private var overlayFocused: Bool
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
    private var usesMotion: Bool {
        animatesPresentation && !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled &&
        [.nominal, .fair].contains(ProcessInfo.processInfo.thermalState)
    }
    var body: some View {
        if let reaction = controller.reaction {
            GeometryReader { geometry in
                let bounds = geometry.frame(in: .global)
                ZStack {
                    Color.black.opacity(0.18).ignoresSafeArea()
                        .onTapGesture { controller.cancel(.dismissed) }.accessibilityHidden(true)
                    let bubble = PersonaReactionBubble(text: reaction.text, notice: controller.notice.map(text), closeLabel: text("ui.close"),
                                                       dismiss: { controller.cancel(.dismissed) })
                    ViewThatFits(in: .vertical) {
                        bubble
                        ScrollView { bubble }
                    }
                        .frame(maxWidth: 440, maxHeight: max(120, geometry.size.height - 48)).padding(24)
                        .scaleEffect(appeared || !usesMotion ? 1 : 0.15)
                        .offset(x: appeared || !usesMotion || avatarFrame.isEmpty ? 0 : avatarFrame.midX - bounds.midX,
                                y: appeared || !usesMotion || avatarFrame.isEmpty ? 0 : avatarFrame.midY - bounds.midY)
                        .accessibilityFocused($reading)
                        .focusable().focused($overlayFocused)
                        .onKeyPress(.escape) { controller.cancel(.dismissed); return .handled }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityIdentifier("persona-reaction-overlay")
            .task(id: reaction.id) {
                appeared = false
                await Task.yield()
                withAnimation(usesMotion ? .easeOut(duration: 0.24) : nil) { appeared = true }
                reading = true; overlayFocused = true
            }
        }
    }
}

struct PersonaReactionBubble: View {
    let text: String
    let notice: String?
    let closeLabel: String
    let dismiss: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                Text(text).font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(action: dismiss) { Image(systemName: "xmark").foregroundStyle(.white) }
                    .djConnectButtonStyle(DJConnectButtonStyle(shape: .icon))
                    .accessibilityLabel(closeLabel)
            }
            if let notice { Text(notice).font(.footnote).foregroundStyle(.white.opacity(0.7)).fixedSize(horizontal: false, vertical: true) }
        }
        .foregroundStyle(.white)
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .djSessionFrostedSurface(currentMomentBorder: true)
    }
}

/// The mapping is presentation only; it confers no permission to request a reaction.
private func personaReactionKind(_ count: Int) -> DJConnectPersonaReactionKind? {
    switch count { case 1: .checkIn; case 2: .playful; case 3: .easterEgg; default: nil }
}

#if os(iOS)
/// Native failure dependencies arbitrate 1/2/3 taps without leaking a lower tap count.
private struct PersonaReactionTapSurface: UIViewRepresentable {
    var action: (DJConnectPersonaReactionKind) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isAccessibilityElement = false
        let recognizers = (1...3).map { count in
            let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
            tap.numberOfTapsRequired = count
            tap.cancelsTouchesInView = false
            view.addGestureRecognizer(tap)
            return tap
        }
        recognizers[0].require(toFail: recognizers[1])
        recognizers[0].require(toFail: recognizers[2])
        recognizers[1].require(toFail: recognizers[2])
        return view
    }
    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.action = action
    }
    @MainActor final class Coordinator: NSObject {
        var action: (DJConnectPersonaReactionKind) -> Void
        init(action: @escaping (DJConnectPersonaReactionKind) -> Void) { self.action = action }
        @objc func tapped(_ tap: UITapGestureRecognizer) {
            if tap.state == .ended, tap.view?.window != nil, let kind = personaReactionKind(tap.numberOfTapsRequired) { action(kind) }
        }
    }
}
#elseif os(macOS)
private struct PersonaReactionTapSurface: NSViewRepresentable {
    var action: (DJConnectPersonaReactionKind) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        for count in 1...3 {
            let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.clicked(_:)))
            click.numberOfClicksRequired = count
            click.delegate = context.coordinator
            view.addGestureRecognizer(click)
        }
        return view
    }
    func updateNSView(_ view: NSView, context: Context) { context.coordinator.action = action }
    @MainActor final class Coordinator: NSObject, NSGestureRecognizerDelegate {
        var action: (DJConnectPersonaReactionKind) -> Void
        init(action: @escaping (DJConnectPersonaReactionKind) -> Void) { self.action = action }
        @objc func clicked(_ click: NSClickGestureRecognizer) {
            if click.state == .ended, click.view?.window != nil, let kind = personaReactionKind(click.numberOfClicksRequired) { action(kind) }
        }
        func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer,
                               shouldRequireFailureOf otherGestureRecognizer: NSGestureRecognizer) -> Bool {
            guard let first = gestureRecognizer as? NSClickGestureRecognizer,
                  let other = otherGestureRecognizer as? NSClickGestureRecognizer,
                  first.view === other.view else { return false }
            return first.numberOfClicksRequired < other.numberOfClicksRequired
        }
    }
}
#endif
