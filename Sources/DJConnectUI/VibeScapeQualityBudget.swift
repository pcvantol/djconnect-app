import Foundation

/// Measured GPU pressure changes sampling/FPS only, never the artist's Dynamics.
/// Hysteresis prevents quality from oscillating as reduced work becomes faster.
struct VibeScapeQualityBudget {
    private(set) var prefersReducedQuality = false
    private(set) var averageMilliseconds: Double = 0
    private var slowFrames = 0
    private var fastFrames = 0
    mutating func observe(milliseconds: Double) {
        guard milliseconds.isFinite, milliseconds > 0, milliseconds < 1000 else { return }
        averageMilliseconds = averageMilliseconds == 0 ? milliseconds : averageMilliseconds * 0.9 + milliseconds * 0.1
        if averageMilliseconds > 20 {
            slowFrames += 1; fastFrames = 0
            if slowFrames >= 8 { prefersReducedQuality = true }
        } else if averageMilliseconds < 9 {
            fastFrames += 1; slowFrames = 0
            if fastFrames >= 180 { prefersReducedQuality = false }
        } else { slowFrames = 0; fastFrames = 0 }
    }
}
