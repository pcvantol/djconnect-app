import SwiftUI

/// Deterministic vector artwork, rasterized by WidgetKit with the widget snapshot.
/// No clock, animation, renderer loop, randomness or additional refresh is needed.
struct SessionWidgetVibeScapeArtwork: View {
    let colors: [Color]
    private var primary: Color { colors.first ?? .purple }
    private var accent: Color { colors.dropFirst().first ?? .blue }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                liquid(width: size.width * 0.70, height: size.height * 0.90)
                    .rotationEffect(.degrees(-28))
                    .position(x: size.width * 0.97, y: size.height * 0.13)
                    .opacity(0.36)
                liquid(width: size.width * 0.54, height: size.height * 0.56)
                    .rotationEffect(.degrees(28))
                    .position(x: size.width * 0.02, y: size.height * 1.02)
                    .opacity(0.24)
                ForEach(0..<9) { index in
                    wave(in: size, index: index)
                        .stroke(LinearGradient(colors: [accent.opacity(0.02), accent.opacity(0.32), .white.opacity(0.14), primary.opacity(0.06)],
                                               startPoint: .leading, endPoint: .trailing), lineWidth: index == 4 ? 1.1 : 0.7)
                }
                RadialGradient(colors: [.clear, Color.black.opacity(0.18)],
                               center: .topLeading, startRadius: 0, endRadius: max(size.width, size.height))
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func liquid(width: CGFloat, height: CGFloat) -> some View {
        SessionWidgetLiquidShape()
            .fill(RadialGradient(stops: [.init(color: .white.opacity(0.44), location: 0),
                                        .init(color: accent.opacity(0.52), location: 0.20),
                                        .init(color: primary.opacity(0.20), location: 0.48),
                                        .init(color: Color.black.opacity(0.52), location: 0.76),
                                        .init(color: accent.opacity(0.40), location: 1)],
                                 center: .topTrailing, startRadius: 0, endRadius: max(width, height)))
            .overlay {
                SessionWidgetLiquidShape()
                    .stroke(LinearGradient(colors: [.white.opacity(0.42), accent.opacity(0.14), .clear, primary.opacity(0.30)],
                                           startPoint: .topTrailing, endPoint: .bottomLeading), lineWidth: 1.1)
            }
            .frame(width: width, height: height)
    }

    private func wave(in size: CGSize, index: Int) -> Path {
        let shift = CGFloat(index) * size.height * 0.018
        var path = Path()
        path.move(to: CGPoint(x: -size.width * 0.12, y: size.height * 0.88 + shift))
        path.addCurve(to: CGPoint(x: size.width * 1.12, y: size.height * 0.58 + shift),
                      control1: CGPoint(x: size.width * 0.42, y: size.height * 0.40 + shift),
                      control2: CGPoint(x: size.width * 0.54, y: size.height * 1.20 + shift))
        return path
    }
}

private struct SessionWidgetLiquidShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        path.move(to: point(0.36, 0.02))
        path.addCurve(to: point(0.98, 0.34), control1: point(0.68, -0.08), control2: point(0.98, 0.05))
        path.addCurve(to: point(0.71, 0.68), control1: point(0.98, 0.55), control2: point(0.73, 0.48))
        path.addCurve(to: point(0.34, 0.98), control1: point(0.68, 0.92), control2: point(0.62, 1.10))
        path.addCurve(to: point(0.07, 0.48), control1: point(0.05, 0.91), control2: point(0.31, 0.75))
        path.addCurve(to: point(0.36, 0.02), control1: point(-0.08, 0.25), control2: point(0.06, 0.10))
        path.closeSubpath()
        return path
    }
}
