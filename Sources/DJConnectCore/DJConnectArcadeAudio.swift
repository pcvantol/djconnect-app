import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

public enum DJConnectArcadeSound: CaseIterable, Hashable, Sendable {
    case start, move, fire, bounce, hit, collect, power, explosion, crash, gameOver
}

/// Original, synthesized arcade cues: each game has its own oscillator, envelope and melody.
/// No audio-session/category changes: game effects do not take ownership of music playback.
public enum DJConnectArcadeSynth {
    private static func mazeNotes(_ sound: DJConnectArcadeSound) -> [(Double, Double)] {
        switch sound {
        case .collect, .move: [(950, 0.026), (300, 0.030)]
        case .start: [(523, 0.055), (784, 0.055), (1_047, 0.08), (784, 0.055)]
        case .power: [(523, 0.035), (659, 0.035), (784, 0.035), (1_047, 0.07)]
        case .explosion: [(440, 0.05), (880, 0.06), (1_320, 0.08)]
        case .gameOver, .crash: [(784, 0.06), (622, 0.06), (440, 0.07), (196, 0.12)]
        case .fire: [(880, 0.04), (440, 0.045)]
        case .bounce: [(330, 0.035)]
        case .hit: [(660, 0.04), (990, 0.05)]
        }
    }

    public static func wav(game: DJConnectWatchArcadeGame, sound: DJConnectArcadeSound) -> Data {
        let rate = 22_050
        let notes: [(Double, Double)]
        if game == .pacman { notes = mazeNotes(sound) }
        else { notes = switch sound {
        case .start: [(262, 0.07), (392, 0.07), (524, 0.12)]
        case .move: [(220, 0.025)]
        case .fire: [(1_400, 0.10)]
        case .bounce: [(280, 0.045)]
        case .hit: [(560, 0.065)]
        case .collect: [(660, 0.06)]
        case .power: [(440, 0.055), (660, 0.055), (880, 0.11)]
        case .explosion: [(150, 0.20)]
        case .crash: [(220, 0.23)]
        case .gameOver: [(392, 0.09), (294, 0.09), (196, 0.18)]
        } }
        var samples = [Int16]()
        var random: UInt32 = 0xA7C4_1309
        var phase = 0.0
        for (noteIndex, note) in notes.enumerated() {
            let (frequency, duration) = note
            let count = Int(duration * Double(rate))
            for i in 0..<count {
                let t = Double(i) / Double(count - 1)
                let attack = min(1, Double(i) / 45)
                let release = min(1, Double(count - 1 - i) / 160)
                let envelope = attack * release * (1 - 0.45 * t)
                random = random &* 1_664_525 &+ 1_013_904_223
                let noise = Double(random >> 8) / 8_388_607.5 - 1
                let destructive = sound == .explosion || sound == .crash || sound == .gameOver
                let pitch: Double
                switch game {
                case .pong: pitch = frequency * (sound == .fire ? 0.5 : 1)
                case .asteroids: pitch = frequency * pow(destructive ? 0.16 : 0.24, t) * 1.3
                case .fly: pitch = frequency * (destructive ? (1 - t * 0.85) : (0.65 + t * 1.4))
                case .pacman:
                    switch sound {
                    case .collect, .move:
                        // Two tiny mouth strokes: close (wa), open (ka), never a long whistle.
                        pitch = noteIndex.isMultiple(of: 2) ? 950 - 650 * t : 300 + 550 * t
                    case .gameOver, .crash:
                        pitch = frequency * (1 - t * 0.3) * (1 + 0.06 * sin(t * .pi * 8))
                    case .explosion: pitch = frequency * (1 + t * 0.8)
                    default: pitch = frequency
                    }
                }
                phase += pitch / Double(rate)
                let p = phase.truncatingRemainder(dividingBy: 1)
                let value: Double
                switch game {
                case .pong: // dry, hollow console blips
                    value = (p < 0.5 ? 0.75 : -0.75) + 0.15 * sin(phase * .pi)
                case .asteroids: // falling pulse lasers and crunchy impact noise
                    value = destructive ? noise * 0.7 + sin(phase * 2 * .pi) * 0.3 : (p < 0.18 ? 0.85 : -0.3)
                case .fly: // brighter triangle chirps, with an airy crash
                    let triangle = 1 - 4 * abs(p - 0.5)
                    value = triangle * 0.75 + (destructive ? noise * 0.25 : sin(phase * 4 * .pi) * 0.2)
                case .pacman: // hollow arcade mouth pulses; discrete pitched bonus arpeggios
                    value = sin(phase * 2 * .pi) * 0.76 + sin(phase * 6 * .pi) * 0.18
                }
                samples.append(Int16(max(-1, min(1, value * envelope)) * 9_000))
            }
            samples.append(contentsOf: repeatElement(0, count: rate / 250))
        }
        var data = Data()
        func ascii(_ text: String) { data.append(contentsOf: text.utf8) }
        func u16(_ value: UInt16) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        func u32(_ value: UInt32) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        ascii("RIFF"); u32(UInt32(36 + samples.count * 2)); ascii("WAVEfmt ")
        u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        ascii("data"); u32(UInt32(samples.count * 2))
        for sample in samples { u16(UInt16(bitPattern: sample)) }
        return data
    }
}

/// A bounded serial bank, shared by the native and Watch renderers. Collision bursts
/// coalesce to one pending cue; leaving/pausing a game stops all active effects.
public final class DJConnectArcadeAudio: @unchecked Sendable {
    public static let shared = DJConnectArcadeAudio()
    private struct Cue: Hashable { let game: DJConnectWatchArcadeGame; let sound: DJConnectArcadeSound }
    private let queue = DispatchQueue(label: "dev.djconnect.arcade-sound", qos: .userInitiated)
    private let lock = NSLock()
    private var pending: Cue?
    private var running = false
    #if canImport(AVFoundation)
    private var players: [Cue: AVAudioPlayer] = [:]
    #endif
    public func play(_ sound: DJConnectArcadeSound, game: DJConnectWatchArcadeGame) {
        let start = lock.withLock {
            pending = Cue(game: game, sound: sound)
            if running { return false }
            running = true; return true
        }
        if start { queue.async { self.drain() } }
    }
    public func stop() {
        lock.withLock { pending = nil }
        queue.async {
            #if canImport(AVFoundation)
            for player in self.players.values { player.stop() }
            #endif
        }
    }
    private func drain() {
        while let cue = lock.withLock({ () -> Cue? in
            guard let cue = pending else { running = false; return nil }
            pending = nil; return cue
        }) {
            #if canImport(AVFoundation)
            let player: AVAudioPlayer
            if let cached = players[cue] { player = cached }
            else {
                guard let created = try? AVAudioPlayer(data: DJConnectArcadeSynth.wav(game: cue.game, sound: cue.sound)) else { continue }
                created.volume = 0.24; created.prepareToPlay(); players[cue] = created; player = created
            }
            player.currentTime = 0; player.play()
            #endif
        }
    }
}
