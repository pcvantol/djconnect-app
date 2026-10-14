import SwiftUI

extension View {
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
