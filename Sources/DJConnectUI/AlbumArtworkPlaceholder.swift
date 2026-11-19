import SwiftUI

/// A fixed pivot, counterweight, bent metal arm and cartridge above the spinning record.
private struct AlbumArtworkTonearm: View {
    let recordDiameter: CGFloat

    var body: some View {
        Canvas { context, size in
            let d = recordDiameter
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: center.x + x * d, y: center.y + y * d)
            }
            let pivot = point(0.44, -0.38)
            let base = CGRect(x: pivot.x - d * 0.055, y: pivot.y - d * 0.055,
                              width: d * 0.11, height: d * 0.11)
            context.fill(Path(ellipseIn: base), with: .linearGradient(
                Gradient(colors: [Color(white: 0.28), Color(white: 0.08)]),
                startPoint: CGPoint(x: base.minX, y: base.minY), endPoint: CGPoint(x: base.maxX, y: base.maxY)))
            context.stroke(Path(ellipseIn: base), with: .color(.white.opacity(0.35)), lineWidth: d * 0.004)

            let weight = CGRect(x: pivot.x - d * 0.028, y: pivot.y - d * 0.105,
                                width: d * 0.065, height: d * 0.07)
            context.fill(Path(roundedRect: weight, cornerRadius: d * 0.012), with: .color(Color(white: 0.55)))
            var arm = Path()
            arm.move(to: point(0.45, -0.08 - 0.38))
            arm.addLine(to: pivot)
            arm.addLine(to: point(0.38, 0.035))
            arm.addLine(to: point(0.18, 0.185))
            var shadow = context
            shadow.translateBy(x: d * 0.012, y: d * 0.014)
            shadow.stroke(arm, with: .color(.black.opacity(0.45)),
                          style: StrokeStyle(lineWidth: d * 0.028, lineCap: .round, lineJoin: .round))
            context.stroke(arm, with: .color(Color(white: 0.18)),
                           style: StrokeStyle(lineWidth: d * 0.028, lineCap: .round, lineJoin: .round))
            context.stroke(arm, with: .linearGradient(Gradient(colors: [.white.opacity(0.95), Color(white: 0.48)]),
                                                     startPoint: pivot, endPoint: point(0.18, 0.185)),
                           style: StrokeStyle(lineWidth: d * 0.016, lineCap: .round, lineJoin: .round))
            context.fill(Path(ellipseIn: CGRect(x: pivot.x - d * 0.022, y: pivot.y - d * 0.022,
                                                width: d * 0.044, height: d * 0.044)), with: .color(Color(white: 0.7)))

            var cartridge = Path()
            cartridge.move(to: point(0.215, 0.17))
            cartridge.addLine(to: point(0.177, 0.13))
            cartridge.addLine(to: point(0.112, 0.207))
            cartridge.addLine(to: point(0.15, 0.245))
            cartridge.closeSubpath()
            context.fill(cartridge, with: .color(Color(red: 0.18, green: 0.16, blue: 0.25)))
            context.stroke(cartridge, with: .color(.white.opacity(0.55)), lineWidth: d * 0.004)
            var stylus = Path()
            stylus.move(to: point(0.13, 0.225))
            stylus.addLine(to: point(0.113, 0.25))
            context.stroke(stylus, with: .color(.white.opacity(0.9)),
                           style: StrokeStyle(lineWidth: d * 0.006, lineCap: .round))
        }
        .allowsHitTesting(false)
    }
}

/// Vinyl content when artwork is absent or unavailable. The parent artwork
/// renderer supplies the same card and inset used for a downloaded cover.
struct AlbumArtworkPlaceholder: View {
    let tint: Color
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var elapsedBeforePause: TimeInterval = 0
    @State private var spinningSince: Date?

    private var shouldSpin: Bool {
        isPlaying && !reduceMotion && scenePhase == .active
    }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let record = side * 0.66
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [tint.opacity(0.30), .clear],
                                         center: .center, startRadius: 0, endRadius: side * 0.46))
                    .frame(width: side * 0.92, height: side * 0.92)
                    .blur(radius: side * 0.06)
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !shouldSpin)) { context in
                    let elapsed = elapsedBeforePause + (spinningSince.map { max(0, context.date.timeIntervalSince($0)) } ?? 0)
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color(red: 0.12, green: 0.13, blue: 0.20),
                                                          Color(red: 0.025, green: 0.03, blue: 0.07)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: record, height: record)
                        ForEach([0.78, 0.90], id: \.self) { scale in
                            Circle().stroke(.white.opacity(0.045), lineWidth: 1)
                                .frame(width: record * scale, height: record * scale)
                        }
                        // The reflection turns with the record; the tonearm stays fixed.
                        Circle().trim(from: 0.04, to: 0.18)
                            .stroke(.white.opacity(0.14), style: StrokeStyle(lineWidth: record * 0.012, lineCap: .round))
                            .frame(width: record * 0.84, height: record * 0.84)
                        Circle()
                            .fill(LinearGradient(colors: [Color(red: 0.12, green: 0.45, blue: 1.00),
                                                        Color(red: 0.84, green: 0.22, blue: 0.96)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: record * 0.26, height: record * 0.26)
                            .opacity(0.85)
                        Circle().fill(Color(red: 0.035, green: 0.04, blue: 0.09))
                            .frame(width: record * 0.045, height: record * 0.045)
                    }
                    .rotationEffect(.degrees(elapsed.truncatingRemainder(dividingBy: 12) * 30))
                    .shadow(color: .black.opacity(0.18), radius: side * 0.06, y: side * 0.035)
                }
                AlbumArtworkTonearm(recordDiameter: record)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: shouldSpin, initial: true) { _, spinning in
            let now = Date()
            if spinning {
                spinningSince = now
            } else if let started = spinningSince {
                elapsedBeforePause += max(0, now.timeIntervalSince(started))
                spinningSince = nil
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
