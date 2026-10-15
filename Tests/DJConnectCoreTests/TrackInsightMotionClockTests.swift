import Foundation
import Testing
@testable import DJConnectUI

struct TrackInsightMotionClockTests {
    @Test func rateChangeNeverRepositionsExistingParticles() {
        var clock = TrackInsightMotionClock()
        clock.update(running: true, rate: 0.58, at: 800_000_000)
        let before = clock.frame(at: 800_000_010)
        clock.update(running: true, rate: 1.42, at: 800_000_010)
        #expect(clock.frame(at: 800_000_010) == before)
        let after = clock.frame(at: 800_000_011)
        #expect(abs(after.travel - before.travel - 1.42) < 0.000001)
        #expect(after.elapsed == 11)
    }

    @Test func routineViewUpdatesCannotResetPhase() {
        var clock = TrackInsightMotionClock()
        clock.update(running: true, rate: 0.8, at: 10)
        for second in 1...30 { clock.update(running: true, rate: 0.8, at: Double(10 + second)) }
        #expect(abs(clock.frame(at: 40).travel - 24) < 0.000001)
        #expect(clock.frame(at: 40).elapsed == 30)
    }

    @Test func pauseBackgroundAndReducedMotionFreezeThenResume() {
        var clock = TrackInsightMotionClock()
        clock.update(running: true, rate: 1, at: 10)
        clock.update(running: false, rate: 1, at: 15)
        let frozen = clock.frame(at: 15)
        #expect(clock.frame(at: 1000) == frozen)
        clock.update(running: true, rate: 1, at: 1000)
        #expect(clock.frame(at: 1000) == frozen)
        #expect(clock.frame(at: 1001).travel == frozen.travel + 1)
    }

    @Test func wrappedParticleIsInvisibleOnBothSidesOfSeam() {
        for seam in [-1000.0, 0, 1, 1000] {
            #expect(TrackInsightParticleWrap(seam).opacity == 0)
            #expect(TrackInsightParticleWrap(seam - 0.0001).opacity < 0.0001)
            #expect(TrackInsightParticleWrap(seam + 0.0001).opacity < 0.0001)
        }
        #expect(TrackInsightParticleWrap(0.5).opacity == 1)
        #expect(abs(TrackInsightParticleWrap(-0.25).position - 0.75) < 0.000001)
        #expect(TrackInsightParticleWrap(.infinity).opacity == 0)
    }

    @Test func populationChangesFadeInsteadOfPoppingWholeSparks() {
        #expect(TrackInsightParticleWrap.populationOpacity(index: 8, population: 8) == 0)
        #expect(TrackInsightParticleWrap.populationOpacity(index: 8, population: 8.25) == 0.25)
        #expect(TrackInsightParticleWrap.populationOpacity(index: 8, population: 9) == 1)
    }
}
