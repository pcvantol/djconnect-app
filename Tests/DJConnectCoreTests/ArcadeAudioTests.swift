import Foundation
import Testing
@testable import DJConnectCore

@Test func arcadeCuesAreDistinctBoundedPCMWithSilentEdges() {
    for sound in DJConnectArcadeSound.allCases {
        var recordings = Set<Data>()
        for game in DJConnectWatchArcadeGame.allCases {
            let wav = DJConnectArcadeSynth.wav(game: game, sound: sound)
            #expect(String(decoding: wav.prefix(4), as: UTF8.self) == "RIFF")
            #expect(String(decoding: wav[8..<12], as: UTF8.self) == "WAVE")
            #expect(wav.count > 44 && wav.count < 22_050) // every effect < half a second
            let pcm = Array(wav.dropFirst(44))
            #expect(pcm.count.isMultiple(of: 2))
            var peak = 0
            for i in stride(from: 0, to: pcm.count, by: 2) {
                let sample = Int(Int16(bitPattern: UInt16(pcm[i]) | UInt16(pcm[i + 1]) << 8))
                peak = max(peak, abs(sample))
            }
            #expect(peak > 1_000 && peak <= 9_000)
            #expect(pcm.prefix(2).allSatisfy { $0 == 0 })
            #expect(pcm.suffix(2).allSatisfy { $0 == 0 })
            #expect(wav == DJConnectArcadeSynth.wav(game: game, sound: sound))
            recordings.insert(wav)
        }
        #expect(recordings.count == 4) // no shared generic start/hit/death sound
    }
}

@Test func watchArcadeEmitsEventsOnlyForRealActions() {
    var state = DJConnectWatchArcadeState(game: .asteroids)
    state.restart()
    #expect(state.sound == .start)
    let start = state.soundSequence
    state.tap(at: .zero)
    #expect(state.sound == .fire && state.soundSequence == start + 1)
    state.tap(at: .zero) // an existing shot must not fire a second sound
    #expect(state.soundSequence == start + 1)
    state.pause()
    state.advance(by: 1)
    #expect(state.soundSequence == start + 1)
    state.restart()
    #expect(state.sound == .start && state.soundSequence == start + 2)
}
