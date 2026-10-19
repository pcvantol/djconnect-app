import SwiftUI
import DJConnectCore

/// Exclusive native multi-tap recognition dispatches only its final semantic
/// choice. Context menu, VoiceOver and keyboard retain ordinary alternatives.
struct PersonaReactionAvatar<Avatar: View>: View {
    @ObservedObject var model: DJConnectAppModel
    let avatar: Avatar
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    var body: some View {
        Group {
            if model.presentsPersonaReactionControl {
                avatar
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "hand.tap.fill").font(.system(size: 12)).foregroundStyle(.white)
                            .padding(5).background(.black.opacity(0.55), in: Circle()).accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                    .gesture(TapGesture(count: 3).exclusively(before: TapGesture(count: 2).exclusively(before: TapGesture(count: 1)))
                        .onEnded { result in
                            switch result {
                            case .first: model.requestPersonaReaction(.easterEgg)
                            case .second(.first): model.requestPersonaReaction(.playful)
                            case .second(.second): model.requestPersonaReaction(.checkIn)
                            }
                        })
                    .contextMenu {
                        ForEach(DJConnectPersonaReactionKind.allCases, id: \.self) { kind in
                            Button(text("ui.session.reaction." + kind.rawValue)) { model.requestPersonaReaction(kind) }
                                .disabled(!model.canStartPersonaReaction)
                        }
                    }
                    .focusable()
                    .onKeyPress(.return) { model.requestPersonaReaction(.checkIn); return .handled }
                    .onKeyPress(.space) { model.requestPersonaReaction(.checkIn); return .handled }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(text("ui.session.reaction.hint"))
                    .accessibilityAction { model.requestPersonaReaction(.checkIn) }
                    .accessibilityAction(named: text("ui.session.reaction.playful")) { model.requestPersonaReaction(.playful) }
                    .accessibilityAction(named: text("ui.session.reaction.easter_egg")) { model.requestPersonaReaction(.easterEgg) }
                    .help(text("ui.session.reaction.hint"))
            } else { avatar }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
            model.personaAvatarFrame = frame
        }
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
