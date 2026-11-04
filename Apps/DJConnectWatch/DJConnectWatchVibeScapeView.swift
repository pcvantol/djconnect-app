import DJConnectCore
import SwiftUI

struct DJConnectWatchVibeScapeView: View {
    let session: DJConnectSessionRuntime
    let isVisible: Bool
    let language: String

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var salt = UInt64.random(in: .min ... .max)
    @State private var dynamics = 0.5
    @State private var followsDJ = true
    @State private var controlsVisit: UUID?
    @State private var showsDynamics = false
    @State private var phaseOrigin = Date()
    @State private var phaseAtOrigin = 0.0

    private var family: VibeScapeFamily {
        session.confirmedPersona.map { VibeScapeFamily(persona: $0.selectedPersona) } ?? .neutral
    }

    private func text(_ key: String) -> String {
        DJConnectLocalization.localized(key: key, language: language)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isVisible {
                let scene = VibeScapeScene.autonomous(mood: session.selectedMood, salt: salt, family: family)
                TimelineView(.animation(minimumInterval: 1.0 / 24,
                                        paused: scenePhase != .active || reduceMotion || showsDynamics || family == .neutral)) { clock in
                    Canvas { context, size in
                        let curve = VibeScapeDynamics.sample(Float(dynamics), family: scene.family)
                        let phase = reduceMotion ? 0 : phaseAtOrigin
                            + max(0, clock.date.timeIntervalSince(phaseOrigin)) * Double(scene.motion * curve.speed)
                        Self.draw(scene, curve: curve, phase: phase, in: context, size: size)
                    }
                }
                .background(.black)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { revealControls() }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("VibeScape")
                .accessibilityValue(text(family.titleKey))
                .accessibilityAction(named: Text(text("ui.vibescape.dynamics"))) { showsDynamics = true }

                if controlsVisit != nil {
                    Button {
                        controlsVisit = nil
                        showsDynamics = true
                    } label: {
                        Image(systemName: "bolt.fill")
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(text("ui.vibescape.dynamics"))
                    .padding(.trailing, 8)
                    .padding(.bottom, 12)
                    .transition(.opacity)
                }
            }
        }
        .task(id: controlsVisit) {
            guard let visit = controlsVisit else { return }
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard controlsVisit == visit else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { controlsVisit = nil }
        }
        .onChange(of: isVisible) { _, visible in
            if !visible {
                controlsVisit = nil
                showsDynamics = false
                dynamics = 0.5
                followsDJ = true
                phaseOrigin = Date()
                phaseAtOrigin = 0
            }
        }
        .sheet(isPresented: $showsDynamics) {
            NavigationStack {
                DJConnectWatchList {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(dynamics, format: .percent.precision(.fractionLength(0)))
                            .font(.headline.monospacedDigit())
                        Text(text(followsDJ ? "ui.vibescape.dynamics.auto" : "ui.vibescape.dynamics.manual"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: Binding(get: { dynamics }, set: { setDynamics($0, followsDJ: false) }),
                               in: 0...1, step: 0.01)
                            .accessibilityLabel(text("ui.vibescape.dynamics"))
                    }
                    Button {
                        setDynamics(0.5, followsDJ: true)
                    } label: {
                        Label(text("ui.vibescape.dynamics.follow"), systemImage: "arrow.uturn.backward")
                    }
                }
                .listStyle(.plain)
                .watchStandardBackground()
                .navigationTitle(text("ui.vibescape.dynamics"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            showsDynamics = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel(text("ui.close"))
                    }
                }
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
            * Double(family.baselineMotion(mood: session.selectedMood) * speed)
        phaseOrigin = now
        dynamics = value
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
            for index in 0..<6 {
                let offset = Double(index) * 1.1 + seed
                let x = center.x + sin(phase + offset) * unit * 0.28 * parallax
                let y = center.y + cos(phase * 0.8 + offset) * unit * 0.32 * parallax
                let radius = unit * (0.21 + 0.055 * excursion * sin(phase * evolution + offset))
                let blob = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: 2 * radius, height: 2 * radius))
                context.fill(blob, with: .radialGradient(.init(colors: [palette[index % 3], palette[index % 3].opacity(0.12), .clear]),
                                                         center: CGPoint(x: x - radius * 0.24, y: y - radius * 0.22),
                                                         startRadius: 0, endRadius: radius * 1.23))
            }
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
}
