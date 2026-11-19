import Foundation

/// Internal read clock for deterministic original-lease race tests. Production
/// always uses the live clocks; no launch argument or persisted override exists.
@MainActor
struct CurrentInsightReadClock {
    var wallNow: () -> Date = { Date() }
    var monotonicNow: () -> ContinuousClock.Instant = { .now }
}
