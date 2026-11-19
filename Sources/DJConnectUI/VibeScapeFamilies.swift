import Foundation
import simd
import DJConnectCore

/// Renderer identities, selected solely from a confirmed active Session value.
/// Neutral means no character authority; it never silently impersonates Home.
enum VibeScapeFamily: UInt32, CaseIterable, Equatable, Sendable {
    case home, radio, club, festival, neutral
    init(persona: DJConnectSessionPersonaValue) {
        switch persona {
        case .homeDJ: self = .home
        case .radioDJ: self = .radio
        case .clubDJ: self = .club
        case .festivalDJ: self = .festival
        }
    }
    var titleKey: String {
        switch self {
        case .home: "ui.vibescape.world.home"
        case .radio: "ui.vibescape.world.radio"
        case .club: "ui.vibescape.world.club"
        case .festival: "ui.vibescape.world.festival"
        case .neutral: "ui.session.persona.unavailable"
        }
    }
    var weights: SIMD4<Float> {
        switch self {
        case .home: SIMD4(1, 0, 0, 0)
        case .radio: SIMD4(0, 1, 0, 0)
        case .club: SIMD4(0, 0, 1, 0)
        case .festival: SIMD4(0, 0, 0, 1)
        case .neutral: .zero
        }
    }
    func baselineMotion(mood: String?) -> Float {
        let atmosphere: Float
        switch mood {
        case "chill": atmosphere = 0.60
        case "energy": atmosphere = 1.20
        case "party": atmosphere = 1.40
        default: atmosphere = 1
        }
        switch self {
        case .home: return 0.30 * atmosphere
        case .radio: return 0.24 * atmosphere
        case .club: return 0.20 * atmosphere
        case .festival: return 0.26 * atmosphere
        case .neutral: return 0.12
        }
    }
}

struct VibeScapeDynamicsSample: Equatable, Sendable {
    var speed: Float
    var excursion: Float
    var evolution: Float
    var parallax: Float
    var complexity: Float
}

/// Artist-defined relative curves, not BPM/energy measurements or GPU quality.
/// All five neutral multipliers are exactly one. Low remains alive, high bounded.
enum VibeScapeDynamics {
    static func sample(_ raw: Float, family: VibeScapeFamily) -> VibeScapeDynamicsSample {
        let value = raw.isFinite && (0...1).contains(raw) ? raw : 0.5
        func curve(_ low: Float, _ high: Float) -> Float {
            let x = value <= 0.5 ? value * 2 : value * 2 - 1
            let eased = x * x * (3 - 2 * x)
            return value <= 0.5 ? low + (1 - low) * eased : 1 + (high - 1) * eased
        }
        switch family {
        case .home:
            return .init(speed: curve(0.24, 2.05), excursion: curve(0.48, 1.65), evolution: curve(0.60, 1.45),
                parallax: curve(0.72, 1.20), complexity: curve(0.78, 1.25))
        case .radio:
            return .init(speed: curve(0.30, 2.20), excursion: curve(0.32, 1.82), evolution: curve(0.40, 1.90),
                parallax: curve(0.80, 1.25), complexity: curve(0.72, 1.35))
        case .club:
            return .init(speed: curve(0.22, 1.75), excursion: curve(0.35, 1.60), evolution: curve(0.55, 1.65),
                parallax: curve(0.35, 1.65), complexity: curve(0.75, 1.30))
        case .festival:
            return .init(speed: curve(0.28, 1.90), excursion: curve(0.35, 1.95), evolution: curve(0.35, 1.85),
                parallax: curve(0.65, 1.35), complexity: curve(0.56, 1.65))
        case .neutral:
            return .init(speed: 1, excursion: 1, evolution: 1, parallax: 1, complexity: 1)
        }
    }
    static func motionRate(_ value: Float, family: VibeScapeFamily = .home) -> Float { sample(value, family: family).speed }
    static func deformation(_ value: Float, family: VibeScapeFamily = .home) -> Float { sample(value, family: family).excursion }
}

/// A fixed-size blend packet. Rapid A→B→C→A transitions retain the currently
/// visible mixture, rather than discarding a source frame or allocating engines.
struct VibeScapeFrame: Equatable, Sendable {
    var home: VibeScapeScene
    var radio: VibeScapeScene
    var club: VibeScapeScene
    var festival: VibeScapeScene
    var weights: SIMD4<Float>
    var phases: SIMD4<Float>
    var dynamics: Float
    var neutralPalette: SIMD3<Float>
    var settled: Bool
    subscript(_ family: VibeScapeFamily) -> VibeScapeScene {
        get {
            switch family {
            case .home, .neutral: home
            case .radio: radio
            case .club: club
            case .festival: festival
            }
        }
        set {
            switch family {
            case .home, .neutral: home = newValue
            case .radio: radio = newValue
            case .club: club = newValue
            case .festival: festival = newValue
            }
        }
    }
    static func single(_ scene: VibeScapeScene, clock: Float, dynamics: Float) -> Self {
        .init(home: scene, radio: scene, club: scene, festival: scene, weights: scene.family.weights,
            phases: SIMD4(repeating: clock), dynamics: dynamics, neutralPalette: scene.palette, settled: true)
    }
}

/// CPU-only presentation integration, shared by the view and actual GPU probe.
/// Never multiply elapsed wall time by a newly selected speed. No persistence.
struct VibeScapeAnimationState {
    private(set) var frame: VibeScapeFrame?
    private var lastTime: TimeInterval?
    mutating func pause() { lastTime = nil }
    mutating func update(target: VibeScapeScene, dynamics: Float, at time: TimeInterval, reduceMotion: Bool) -> VibeScapeFrame {
        let previousTime = lastTime ?? time
        let dt = time.isFinite && time >= previousTime ? min(time - previousTime, 1.0 / 15.0) : 0
        if time.isFinite { lastTime = time }
        guard var next = frame else {
            let safeDynamics = dynamics.isFinite && (0...1).contains(dynamics) ? dynamics : 0.5
            let first = VibeScapeFrame.single(target, clock: 0, dynamics: safeDynamics)
            frame = first; return first
        }
        let a: Float = reduceMotion ? 1 : Float(1 - exp(-dt / 0.28))
        let b: Float = reduceMotion ? 1 : Float(1 - exp(-dt / 0.18))
        let d = dynamics.isFinite && (0...1).contains(dynamics) ? dynamics : 0.5
        next.dynamics += (d - next.dynamics) * b
        if target.family == .neutral {
            // Withdrawn/conflicted authority never crossfades revoked geometry.
            let dynamics = next.dynamics
            next = .single(target, clock: 0, dynamics: dynamics)
        } else {
            next.weights = simd_mix(next.weights, target.family.weights, SIMD4(repeating: a))
            next[target.family] = next[target.family].interpolated(toward: target, fraction: a)
        }
        if !reduceMotion {
            for index in 0..<4 where next.weights[index] > 0.0005 {
                let family = VibeScapeFamily(rawValue: UInt32(index))!
                next.phases[index] += Float(dt) * next[family].motion * VibeScapeDynamics.motionRate(next.dynamics, family: family)
            }
        }
        next.settled = simd_distance(next.weights, target.family.weights) < 0.005
            && abs(next.dynamics - d) < 0.005
            && (target.family == .neutral || next[target.family].distance(to: target) < 0.005)
        frame = next
        return next
    }
}
