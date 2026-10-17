import Foundation

/// Device-local decorative animation time, independent of server playback
/// snapshots and wall-clock corrections. Rate changes preserve travelled phase.
struct TrackInsightMotionClock {
    struct Frame: Equatable {
        let elapsed: TimeInterval
        let travel: Double
    }
    private var elapsed: TimeInterval = 0
    private var travel: Double = 0
    private var startedAt: TimeInterval?
    private var rate: Double = 1

    mutating func update(running: Bool, rate nextRate: Double, at uptime: TimeInterval) {
        guard uptime.isFinite else { return }
        let frame = frame(at: uptime)
        elapsed = frame.elapsed
        travel = frame.travel
        rate = nextRate.isFinite ? min(max(nextRate, 0), 4) : 0
        startedAt = running ? uptime : nil
    }

    func frame(at uptime: TimeInterval) -> Frame {
        let delta = startedAt.map { uptime.isFinite ? max(0, uptime - $0) : 0 } ?? 0
        return Frame(elapsed: elapsed + delta, travel: travel + delta * rate)
    }
}

/// Particles disappear at a seam before wrapping, then fade back in. The
/// position may wrap; visible opacity cannot jump from one edge to the other.
struct TrackInsightParticleWrap {
    let position: Double
    let opacity: Double

    init(_ phase: Double) {
        guard phase.isFinite else { position = 0; opacity = 0; return }
        position = phase - floor(phase)
        let edgeDistance = min(position, 1 - position)
        let blend = min(max(edgeDistance / 0.04, 0), 1)
        opacity = blend * blend * (3 - 2 * blend)
    }

    static func populationOpacity(index: Int, population: Double) -> Double {
        min(max(population - Double(index), 0), 1)
    }
}
