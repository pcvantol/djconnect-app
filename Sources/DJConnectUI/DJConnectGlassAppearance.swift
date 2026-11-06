import SwiftUI
import DJConnectCore

/// Hardware/UI preference only. Never sent to or stored on a DJConnect Profile.
enum DJConnectGlassAppearance {
    static let storageKey = "DJConnectGlassEffectsEnabled"
    static let composerTint = Color(red: 0.40, green: 0.16, blue: 0.66)
    static let toggleTint = Color(red: 0.84, green: 0.22, blue: 0.96)
    static let opaqueSurface = Color(red: 0.09, green: 0.11, blue: 0.19)
}

#if os(iOS) || os(macOS)
/// Primary actions keep the purple fill and outline of selected DJ settings.
/// Disabling glass removes transparency without removing the button surface.
struct DJConnectPrimaryButtonSurface: View {
    var shape: AnyShape = AnyShape(Capsule())
    var usesLiveGlass = true
    @Environment(\.djConnectGlassEffectsEnabled) private var glassEnabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if usesLiveGlass && glassEnabled && !reduceTransparency {
                shape.fill(djConnectAccent.opacity(0.10))
                    .glassEffect(.regular.tint(djConnectAccent.opacity(0.22)).interactive(), in: shape)
            } else {
                shape.fill(DJConnectGlassAppearance.opaqueSurface)
                    .overlay { shape.fill(DJConnectButtonAppearance.selectedFill) }
            }
        }
        .overlay { shape.stroke(djConnectAccent.opacity(0.55), lineWidth: 1) }
        .clipShape(shape)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#endif

private struct DJConnectGlassEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

private struct DJConnectScrollingSurfaceKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Stable frosted materials for moving page content. Toolbar/popover glass
    /// stays live; this does not change the user's glass-effects preference.
    var djConnectScrollingSurface: Bool {
        get { self[DJConnectScrollingSurfaceKey.self] }
        set { self[DJConnectScrollingSurfaceKey.self] = newValue }
    }

    var djConnectGlassEffectsEnabled: Bool {
        get { self[DJConnectGlassEnabledKey.self] }
        set { self[DJConnectGlassEnabledKey.self] = newValue }
    }
}

/// A disabled effect must resolve to color, never to another blur material.
struct DJConnectMaterial: ShapeStyle {
    let material: Material
    init(_ material: Material) { self.material = material }
    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        if environment.djConnectGlassEffectsEnabled && !environment.accessibilityReduceTransparency {
            AnyShapeStyle(material)
        } else {
            AnyShapeStyle(DJConnectGlassAppearance.opaqueSurface)
        }
    }
}

private struct DJConnectGlassPreference: ViewModifier {
    @AppStorage(DJConnectGlassAppearance.storageKey) private var enabled = true
    func body(content: Content) -> some View {
        content.environment(\.djConnectGlassEffectsEnabled, enabled)
            .toggleStyle(SwitchToggleStyle(tint: DJConnectGlassAppearance.toggleTint))
    }
}

struct DJConnectOptionalGlassEffect: ViewModifier {
    @Environment(\.djConnectGlassEffectsEnabled) private var enabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, watchOS 26, *), enabled && !reduceTransparency {
            content.glassEffect()
        } else { content }
    }
}

private struct DJConnectPresentationSurface: ViewModifier {
    @Environment(\.djConnectGlassEffectsEnabled) private var enabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content: Content) -> some View {
        #if os(iOS) || os(macOS)
        if enabled && !reduceTransparency { content }
        else { content.presentationBackground(DJConnectGlassAppearance.opaqueSurface) }
        #else
        content
        #endif
    }
}

extension View {
    func djConnectGlassPreferences() -> some View { modifier(DJConnectGlassPreference()) }
    func djConnectPresentationSurface() -> some View { modifier(DJConnectPresentationSurface()) }
}

struct DJConnectGlassPreferenceToggle: View {
    let language: String
    @AppStorage(DJConnectGlassAppearance.storageKey) private var enabled = true
    var body: some View {
        Toggle(isOn: $enabled) {
            VStack(alignment: .leading, spacing: 4) {
                Text(DJConnectLocalization.localized(key: "ui.app.glass.effects", language: language))
                Text(DJConnectLocalization.localized(key: "ui.app.glass.effects.description", language: language))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: DJConnectGlassAppearance.toggleTint))
        .accessibilityIdentifier("settings-glass-effects")
    }
}

/// Samples already decoded pixels without fetching or retaining protected artwork.
func averageArtworkColor(from cgImage: CGImage) -> Color? {
    var pixel = [UInt8](repeating: 0, count: 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: &pixel,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }
    context.interpolationQuality = .medium
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    return Color(
        red: Double(pixel[0]) / 255.0,
        green: Double(pixel[1]) / 255.0,
        blue: Double(pixel[2]) / 255.0
    )
}

let djConnectIconGradient = LinearGradient(
    colors: [
        Color(red: 0.12, green: 0.45, blue: 1.00),
        Color(red: 0.84, green: 0.22, blue: 0.96)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

struct DJConnectHeroGlyph: View {
    let systemImage: String
    var assetName: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = ProcessInfo.processInfo.systemUptime

    var body: some View {
        Group {
            if reduceMotion || scenePhase != .active {
                artwork(angle: nil)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
                    let elapsed = max(0, ProcessInfo.processInfo.systemUptime - startedAt)
                    let turn = elapsed.truncatingRemainder(dividingBy: 12) / 12
                    artwork(angle: turn * 360)
                }
            }
        }
        .frame(width: 72, height: 72)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func artwork(angle: Double?) -> some View {
        symbol.foregroundStyle(djConnectIconGradient)
            .overlay {
                if let angle {
                    let light = AngularGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.70),
                        .init(color: .white.opacity(0.04), location: 0.78),
                        .init(color: .white.opacity(0.25), location: 0.90),
                        .init(color: .white.opacity(0.82), location: 0.96),
                        .init(color: .white.opacity(0.18), location: 0.985),
                        .init(color: .clear, location: 1)
                    ], center: .center, startAngle: .degrees(angle), endAngle: .degrees(angle + 360))
                    ZStack {
                        light.mask(symbol.foregroundStyle(.white))
                            .blur(radius: 2).opacity(0.45)
                        light.mask(symbol.foregroundStyle(.white))
                    }
                }
            }
    }

    @ViewBuilder private var symbol: some View {
        if let assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 50, weight: .semibold))
        }
    }
}

/// Desktop dialogs keep a useful minimum; iPhone dialogs must accept the viewport width.
var djConnectDialogMinimumWidth: CGFloat? {
    #if os(macOS)
    360
    #else
    nil
    #endif
}

/// App dialogs use native blocking sheets. Their explicit actions own dismissal;
/// the system retains the presenting page, surrounding edges and transitions.
/// Toolbar status remains a separate anchored native popover.
extension View {
    func djConnectPopup<Popup: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Popup) -> some View {
        sheet(isPresented: isPresented) {
            content().interactiveDismissDisabled()
        }
    }

    func djConnectPopup<Item: Identifiable, Popup: View>(item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Popup) -> some View {
        sheet(item: item) { item in
            content(item).interactiveDismissDisabled()
        }
    }
}
