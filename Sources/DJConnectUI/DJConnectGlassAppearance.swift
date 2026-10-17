import SwiftUI
import DJConnectCore

/// Hardware/UI preference only. Never sent to or stored on a DJConnect Profile.
enum DJConnectGlassAppearance {
    static let storageKey = "DJConnectGlassEffectsEnabled"
    static let toggleTint = Color(red: 0.84, green: 0.22, blue: 0.96)
    static let opaqueSurface = Color(red: 0.09, green: 0.11, blue: 0.19)
}

private struct DJConnectGlassEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
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
