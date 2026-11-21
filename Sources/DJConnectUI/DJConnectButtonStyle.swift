import SwiftUI
import DJConnectCore

/// One family for app actions; system alerts and navigation retain native presentation.
enum DJConnectButtonAppearance {
    static let iconSize: CGFloat = 44
    static let iconFont: Font = .system(size: 18, weight: .semibold)
    static let textFont: Font = .headline.weight(.semibold)
    static let pressedScale: CGFloat = 0.98
}

struct DJConnectButtonStyle: ButtonStyle {
    enum Emphasis { case primary, sessionStart, secondary, tertiary, selected, destructive }
    enum ShapeKind { case capsule, icon, segmented }
    var emphasis: Emphasis = .secondary
    var shape: ShapeKind = .capsule
    var expands = false
    var usesLiveGlass = true
    var usesDestructiveGlass = false
    var iconDiameter: CGFloat = DJConnectButtonAppearance.iconSize
    var showsFocusIndicator = true
    var foregroundColor: Color? = nil
    var selectionTint: Color? = nil
    /// Applied after label padding/expansion, over the complete button shape.
    var selectionFill: Color? = nil
    var sessionStartMood: String? = nil
    var dimsWhenDisabled = true
    @Environment(\.isFocused) private var isFocused
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.djConnectGlassEffectsEnabled) private var glassEnabled

    private var outline: AnyShape {
        switch shape {
        case .segmented: AnyShape(DJConnectCardAppearance.segmentedItemShape)
        case .icon: AnyShape(Circle())
        case .capsule: AnyShape(Capsule())
        }
    }

    private struct LabelLayout {
        let font: Font
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let diameter: CGFloat?

        init(shape: ShapeKind, iconDiameter: CGFloat) {
            switch shape {
            case .icon:
                font = DJConnectButtonAppearance.iconFont
                horizontalPadding = 0
                verticalPadding = 0
                diameter = iconDiameter
            case .capsule:
                font = DJConnectButtonAppearance.textFont
                horizontalPadding = 16
                verticalPadding = 10
                diameter = nil
            case .segmented:
                font = DJConnectButtonAppearance.textFont
                horizontalPadding = 16
                verticalPadding = 0
                diameter = nil
            }
        }
    }

    /// One immutable painting decision for the pressed/focus/accessibility
    /// state. It neither stores interaction state nor changes Button actions.
    private struct InteractionPresentation {
        let pressed: Bool
        let pressedOpacity: Double
        let focusOpacity: Double
        let enabledOpacity: Double
        let scale: CGFloat
        let animation: Animation?

        init(isPressed: Bool, isEnabled: Bool, dimsWhenDisabled: Bool,
             showsFocusIndicator: Bool, isFocused: Bool, reduceMotion: Bool) {
            pressed = isPressed && isEnabled
            pressedOpacity = pressed ? 0.10 : 0
            focusOpacity = showsFocusIndicator && isFocused ? 0.95 : 0
            enabledOpacity = isEnabled || !dimsWhenDisabled ? 1 : 0.40
            scale = pressed && !reduceMotion ? DJConnectButtonAppearance.pressedScale : 1
            animation = reduceMotion ? nil : .easeOut(duration: 0.12)
        }
    }

    private typealias SurfaceOwnership = (primary: Bool, own: Bool)
    private typealias GlassMaterial = (regular: Bool, destructive: Bool, secondaryFallback: Color)

    private func surfaceOwnership(for role: Emphasis) -> SurfaceOwnership {
        let primary = role == .primary || (role == .selected && selectionFill == nil
            && (selectionTint == nil || selectionTint == djConnectAccent))
        return (primary, primary || role == .sessionStart)
    }

    private func resolvedGlassMaterial() -> GlassMaterial {
        let regular = usesLiveGlass && glassEnabled && !reduceTransparency
        return (regular, usesDestructiveGlass && regular,
                glassEnabled && !reduceTransparency ? Color.white.opacity(0.10) : DJConnectGlassAppearance.opaqueSurface)
    }

    private func labelColor(for role: Emphasis) -> Color {
        if role == .primary || role == .sessionStart { return .white }
        if let foregroundColor { return foregroundColor }
        if role == .destructive { return .red }
        return .white.opacity(role == .tertiary ? 0.72 : 1)
    }

    @ViewBuilder private func buttonBackground(role: Emphasis, ownership: SurfaceOwnership,
                                               material: GlassMaterial) -> some View {
        if role == .sessionStart {
            DJConnectSessionStartButtonSurface(shape: outline, mood: sessionStartMood)
        } else if ownership.primary {
            DJConnectPrimaryButtonSurface(shape: outline)
        } else {
            glassBackground(role: role, material: material)
        }
    }

    private func glassBackground(role: Emphasis, material: GlassMaterial) -> some View {
        GlassEffectContainer(spacing: 0) {
            switch role {
            case .primary, .sessionStart:
                EmptyView() // Handled outside the glass compositor.
            case .selected:
                if material.regular {
                    outline.fill(selectionFill ?? (selectionTint ?? djConnectAccent).opacity(0.10))
                        .glassEffect(.regular.tint((selectionTint ?? djConnectAccent).opacity(0.22)).interactive(), in: outline)
                } else { outline.fill(selectionFill ?? (selectionTint ?? djConnectAccent).opacity(0.22)) }
            case .destructive:
                if material.destructive {
                    outline.fill(Color.red.opacity(0.04))
                        .glassEffect(.regular.tint(.red.opacity(0.12)).interactive(), in: outline)
                } else { outline.fill(Color.red.opacity(0.12)) }
            case .secondary:
                if material.regular { outline.fill(.white.opacity(0.04)).glassEffect(.regular.interactive(), in: outline) }
                else { outline.fill(material.secondaryFallback) }
            case .tertiary: Color.clear
            }
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let role: Emphasis = configuration.role == .destructive ? .destructive : emphasis
        let layout = LabelLayout(shape: shape, iconDiameter: iconDiameter)
        let ownership = surfaceOwnership(for: role)
        let interaction = InteractionPresentation(isPressed: configuration.isPressed, isEnabled: isEnabled,
            dimsWhenDisabled: dimsWhenDisabled, showsFocusIndicator: showsFocusIndicator,
            isFocused: isFocused, reduceMotion: reduceMotion)
        return configuration.label
            .font(layout.font)
            .foregroundStyle(labelColor(for: role))
            .symbolRenderingMode(.monochrome)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, layout.verticalPadding)
            .frame(width: layout.diameter, height: layout.diameter)
            .frame(minHeight: DJConnectButtonAppearance.iconSize)
            .frame(maxWidth: expands ? .infinity : nil)
            .background { buttonBackground(role: role, ownership: ownership, material: resolvedGlassMaterial()) }
            .overlay {
                if !ownership.own {
                    outline.stroke(role == .selected ? (selectionTint ?? djConnectAccent).opacity(0.55)
                        : .white.opacity(role == .tertiary ? 0 : 0.12), lineWidth: 1).allowsHitTesting(false)
                }
            }
            .overlay { outline.fill(.white.opacity(interaction.pressedOpacity)).allowsHitTesting(false) }
            .overlay { outline.stroke(.white.opacity(interaction.focusOpacity), lineWidth: 3).allowsHitTesting(false) }
            .contentShape(outline)
            .opacity(interaction.enabledOpacity)
            .scaleEffect(interaction.scale)
            .animation(interaction.animation, value: interaction.pressed)
    }

}

