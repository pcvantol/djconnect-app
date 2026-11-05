import DJConnectCore
import SwiftUI

struct DJConnectWatchVibeScapeView: View {
    let mood: String?
    let family: VibeScapeFamily
    let isVisible: Bool
    let language: String

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var salt = UInt64.random(in: .min ... .max)
    @State private var dynamics = 0.5
    @State private var followsDJ = true
    @State private var controlsVisit: UUID?
    @State private var crownPosition = 0.0
    @FocusState private var crownFocused: Bool
    @State private var phaseOrigin = Date()
    @State private var phaseAtOrigin = 0.0

    private func text(_ key: String) -> String {
        DJConnectLocalization.localized(key: key, language: language)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Keep a still frame ready during the interactive page transition.
            let scene = VibeScapeScene.autonomous(mood: mood, salt: salt, family: family)
            TimelineView(.animation(minimumInterval: 1.0 / 24,
                                    paused: !isVisible || scenePhase != .active || reduceMotion || family == .neutral)) { clock in
                Canvas { context, size in
                    let curve = VibeScapeDynamics.sample(Float(dynamics), family: scene.family)
                    let phase = reduceMotion || !isVisible ? 0 : phaseAtOrigin
                        + max(0, clock.date.timeIntervalSince(phaseOrigin)) * Double(scene.motion * curve.speed)
                    Self.draw(scene, curve: curve, phase: phase, in: context, size: size)
                }
            }
            .background(.black)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { toggleControls() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("VibeScape")
            .accessibilityValue(text(family.titleKey))
            .accessibilityAction(named: Text(text("ui.vibescape.dynamics"))) {
                toggleControls()
            }

            if isVisible && controlsVisit != nil {
                dynamicsOverlay
                    .padding(.horizontal, watchRowInset)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .focusable(acceptsCrown)
        .focusEffectDisabled()
        .focused($crownFocused)
        .digitalCrownRotation(
            Binding(get: { crownPosition }, set: { value in
                guard acceptsCrown else { return }
                let delta = value - crownPosition
                crownPosition = value
                setDynamics(dynamics + delta, followsDJ: false)
                revealControls()
            }),
            from: -1_000, through: 1_000, by: 0.01,
            sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true
        )
        .defaultFocus($crownFocused, acceptsCrown)
        .task(id: acceptsCrown) {
            guard acceptsCrown else { crownFocused = false; return }
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            crownFocused = true
        }
        .task(id: controlsVisit) {
            guard let visit = controlsVisit else { return }
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard controlsVisit == visit else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { controlsVisit = nil }
        }
        .onChange(of: isVisible) { _, visible in
            phaseOrigin = Date()
            phaseAtOrigin = 0
            if !visible {
                controlsVisit = nil
                dynamics = 0.5
                followsDJ = true
            }
        }
    }

    private var acceptsCrown: Bool { isVisible && scenePhase == .active }

    private var dynamicsOverlay: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dynamics, format: .percent.precision(.fractionLength(0)))
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityLabel(text(followsDJ ? "ui.vibescape.dynamics.auto" : "ui.vibescape.dynamics.manual"))
                GeometryReader { geometry in
                    let width = max(0, geometry.size.width - 10)
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.24)).frame(height: 4)
                        Capsule().fill(.white).frame(width: width * dynamics + 5, height: 4)
                        Circle().fill(.white).frame(width: 10, height: 10)
                            .offset(x: width * dynamics)
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            setDynamics((gesture.location.x - 5) / max(width, 1), followsDJ: false)
                            revealControls()
                        })
                }
                .frame(height: 20)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text("ui.vibescape.dynamics"))
                .accessibilityValue(Text(dynamics, format: .percent.precision(.fractionLength(0))))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: setDynamics(dynamics + 0.05, followsDJ: false)
                    case .decrement: setDynamics(dynamics - 0.05, followsDJ: false)
                    @unknown default: return
                    }
                    revealControls()
                }
            }
            Button {
                setDynamics(0.5, followsDJ: true)
                revealControls()
                crownFocused = true
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(text("ui.vibescape.dynamics.follow"))
        }
        .padding(.horizontal, watchListItemPadding)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func toggleControls() {
        guard acceptsCrown else { return }
        if controlsVisit == nil {
            revealControls()
        } else {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                controlsVisit = nil
            }
        }
    }

    private func revealControls() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { controlsVisit = UUID() }
    }

    private func setDynamics(_ value: Double, followsDJ: Bool) {
        let now = Date()
        let speed = VibeScapeDynamics.sample(Float(dynamics), family: family).speed
        phaseAtOrigin += max(0, now.timeIntervalSince(phaseOrigin))
            * Double(family.baselineMotion(mood: mood) * speed)
        phaseOrigin = now
        dynamics = min(max(value, 0), 1)
        self.followsDJ = followsDJ
    }

    private static func draw(_ scene: VibeScapeScene, curve: VibeScapeDynamicsSample,
                             phase: Double, in context: GraphicsContext, size: CGSize) {
        let palette = [scene.palette, scene.secondaryPalette, scene.accentPalette].map {
            Color(red: Double($0.x), green: Double($0.y), blue: Double($0.z))
        }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let unit = min(size.width, size.height)
        let bounds = Path(CGRect(origin: .zero, size: size))
        context.fill(bounds, with: .radialGradient(.init(colors: [palette[0].opacity(0.24), .black]),
                                                   center: center, startRadius: 0, endRadius: unit * 0.72))
        let seed = Double(scene.composition.x) * 2 * .pi
        let excursion = Double(curve.excursion)
        let evolution = Double(curve.evolution)
        let parallax = Double(curve.parallax)
        let detail = Double(curve.complexity)

        switch scene.family {
        case .home:
            drawLiquidGlass(palette, phase: phase * evolution + seed, excursion: excursion,
                            parallax: parallax, in: context, size: size)
        case .radio, .club, .festival:
            let strandCount = Int(8 * detail)
            for index in 0..<strandCount {
                let offset = Double(index) / Double(strandCount) * 2 * .pi
                var path = Path()
                for step in 0...48 {
                    let angle = Double(step) / 48 * 2 * .pi
                    let spin = phase * evolution + offset + seed
                    let point: CGPoint
                    switch scene.family {
                    case .radio:
                        let radius = unit * (0.23 + 0.055 * excursion * cos(3 * angle + spin))
                        point = CGPoint(x: center.x + cos(angle + spin) * radius,
                                        y: center.y + sin(angle + spin) * radius * (0.75 + 0.19 * sin(spin) * parallax))
                    case .club:
                        let edge = cos(angle).magnitude + sin(angle).magnitude
                        let radius = unit * (0.16 + Double(index) * 0.013 * excursion) / edge
                        point = CGPoint(x: center.x + cos(angle + spin) * radius,
                                        y: center.y + sin(angle + spin) * radius + sin(spin) * unit * 0.14 * parallax)
                    default:
                        let radius = unit * (0.23 + 0.065 * excursion * cos(3 * angle + spin))
                        point = CGPoint(x: center.x + cos(angle + offset) * radius,
                                        y: center.y + sin(angle + offset) * radius + sin(2 * angle + spin) * unit * 0.12 * parallax)
                    }
                    if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                let color = palette[index % 3]
                context.stroke(path, with: .color(color.opacity(0.17)), lineWidth: 4)
                context.stroke(path, with: .color(color.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 1, dash: scene.family == .festival ? [1, 2] : []))
            }
        case .neutral:
            break
        }
    }

    private static func drawLiquidGlass(_ palette: [Color], phase: Double, excursion: Double,
                                        parallax: Double, in context: GraphicsContext, size: CGSize) {
        let unit = min(size.width, size.height)
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.48)
        let tilt = -0.42 + 0.18 * sin(phase * 0.36) * parallax
        func point(onRim angle: Double, scale: Double = 1) -> CGPoint {
            let ripple = 1 + excursion * (0.16 * cos(3 * angle - phase)
                                         + 0.09 * sin(2 * angle + phase * 0.65))
            let x = cos(angle) * unit * 0.27 * ripple * scale
            let y = sin(angle) * unit * 0.43 * ripple * scale
            return CGPoint(x: center.x + x * cos(tilt) - y * sin(tilt),
                           y: center.y + x * sin(tilt) + y * cos(tilt))
        }

        var glass = Path()
        glass.move(to: point(onRim: 0))
        for step in 1...96 {
            glass.addLine(to: point(onRim: Double(step) * 2 * .pi / 96))
        }
        glass.closeSubpath()

        func ribbons(in context: GraphicsContext, bent: Bool) {
            for band in 0..<5 {
                var ribbon = Path()
                for step in 0...32 {
                    let x = Double(step) / 32
                    let bend = bent ? 0.13 * sin(x * .pi) : 0
                    let y = 0.66 + Double(band) * 0.026
                        + 0.065 * sin(x * 5 + phase * 0.35) - bend
                    let point = CGPoint(x: x * size.width, y: y * size.height)
                    if step == 0 { ribbon.move(to: point) } else { ribbon.addLine(to: point) }
                }
                let color = palette[band % palette.count]
                context.stroke(ribbon, with: .color(color.opacity(bent ? 0.30 : 0.09)),
                               lineWidth: bent ? 1.5 : 0.75)
            }
        }

        ribbons(in: context, bent: false)
        context.fill(glass, with: .linearGradient(
            .init(colors: [palette[0].opacity(0.42), .black.opacity(0.77), palette[1].opacity(0.38)]),
            startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
        var interior = context
        interior.clip(to: glass)
        ribbons(in: interior, bent: true)
        for (index, color) in palette.enumerated() {
            let offset = phase * 0.43 + Double(index) * 2.1
            let light = CGPoint(x: center.x + cos(offset) * unit * 0.27,
                                y: center.y + sin(offset) * unit * 0.36)
            interior.fill(glass, with: .radialGradient(
                .init(colors: [.white.opacity(0.64), color.opacity(0.52), .clear]),
                center: light, startRadius: 0, endRadius: unit * 0.24))
        }

        // Studio reflections follow the changing contour, with a soft halo inside the glass.
        for (index, color) in [palette[0], palette[1]].enumerated() {
            let start = Double(index) * .pi - 1.5 + 0.28 * sin(phase * 0.45 + Double(index))
            let sweep = 1.15 + 0.25 * sin(phase * 0.40 + Double(index))
            var reflection = Path()
            reflection.move(to: point(onRim: start, scale: 0.94))
            for step in 1...24 {
                let angle = start + Double(step) / 24 * sweep
                reflection.addLine(to: point(onRim: angle, scale: 0.94))
            }
            var halo = interior
            halo.addFilter(.blur(radius: unit * 0.022))
            let stroke = StrokeStyle(lineWidth: unit * 0.020, lineCap: .round)
            halo.stroke(reflection, with: .color(color.opacity(0.85)), style: stroke)
            interior.stroke(reflection, with: .linearGradient(
                .init(colors: [color.opacity(0.08), .white.opacity(0.82), color.opacity(0.12)]),
                startPoint: point(onRim: start), endPoint: point(onRim: start + sweep)),
                style: StrokeStyle(lineWidth: unit * 0.008, lineCap: .round))
        }

        let rim = Gradient(stops: [
            .init(color: .white.opacity(0.85), location: 0.05),
            .init(color: palette[0].opacity(0.52), location: 0.25),
            .init(color: .clear, location: 0.49),
            .init(color: palette[1].opacity(0.78), location: 0.75),
            .init(color: .white.opacity(0.72), location: 0.98)
        ])
        context.stroke(glass, with: .linearGradient(rim, startPoint: .zero,
            endPoint: CGPoint(x: size.width, y: size.height)), lineWidth: 1.2)
    }

}
