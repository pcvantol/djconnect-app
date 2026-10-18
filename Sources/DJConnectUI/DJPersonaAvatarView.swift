import SwiftUI
import DJConnectCore

/// Repository-owned Session Pulse geometry shared by the rich identity and menu mark.
/// No state, timer, audio inference or network operation belongs in this shape.
struct DJPersonaMark: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        var mark = Path()
        var ring = Path()
        ring.addEllipse(in: CGRect(x: 22, y: 25, width: 56, height: 56))
        mark.addPath(ring.strokedPath(StrokeStyle(lineWidth: 4.5)))
        var headphones = Path()
        headphones.move(to: CGPoint(x: 13, y: 57))
        headphones.addCurve(to: CGPoint(x: 87, y: 57),
                            control1: CGPoint(x: 8, y: -4), control2: CGPoint(x: 92, y: -4))
        mark.addPath(headphones.strokedPath(StrokeStyle(lineWidth: 5, lineCap: .round)))
        for x: CGFloat in [7, 82] {
            mark.addRoundedRect(in: CGRect(x: x, y: 43, width: 11, height: 27), cornerSize: CGSize(width: 5, height: 5))
        }
        let heights: [CGFloat] = [12, 24, 34, 24, 12]
        for (index, height) in heights.enumerated() {
            mark.addRoundedRect(in: CGRect(x: 33 + CGFloat(index) * 7.5, y: 53 - height / 2, width: 4, height: height),
                                cornerSize: CGSize(width: 2, height: 2))
        }
        return mark.applying(CGAffineTransform(scaleX: side / 100, y: side / 100)
            .concatenating(CGAffineTransform(translationX: origin.x, y: origin.y)))
    }
}

/// First admitted graphics slice: a quiet identity, never an activity assertion.
/// Future glyph/motion wiring requires qualified Core lifecycle observations.
struct DJPersonaAvatarView: View {
    let confirmedMood: String?
    let language: String
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var theme: DJConnectSessionMoodTheme {
        switch confirmedMood {
        case "chill": .chill
        case "groove": .groove
        case "energy": .energy
        case "party": .party
        default: .brand
        }
    }

    private var colors: [Color] {
        theme.colorValues.map { value in
            Color(red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255,
                  blue: Double(value & 255) / 255)
        }
    }

    var body: some View {
        DJPersonaGraphic(colors: colors, highContrast: contrast == .increased, opaque: reduceTransparency)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(DJConnectLocalization.localized(key: "ui.session.avatar.label", language: language))
            .accessibilityIdentifier("session-dj-avatar")
    }
}

/// Rendering policy is explicit; actual OS settings are read by the identity view.
struct DJPersonaGraphic: View {
    let colors: [Color]
    let highContrast: Bool
    let opaque: Bool

    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(opaque ? 1 : 0.52)).padding(15)
            DJPersonaMark()
                .fill(LinearGradient(colors: highContrast ? [.white] : colors,
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: opaque || highContrast ? .clear : (colors.first ?? .blue).opacity(0.35), radius: 4)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Concrete menu content avoids opaque-view isolation at native ImageRenderer bridges.
struct DJPersonaMenuSymbol: View {
    var body: some View { DJPersonaMark().fill(.white).frame(width: 26, height: 26) }
}
