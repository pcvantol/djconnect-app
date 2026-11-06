import Foundation

/// Device-local bonus games. Coordinates fill the available Watch playfield.
public enum DJConnectWatchArcadeGame: String, CaseIterable, Identifiable, Sendable {
    case pong, asteroids, fly, pacman
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .pong: "Paddle Rally"
        case .asteroids: "Meteor Run"
        case .fly: "Sky Dash"
        case .pacman: "Maze Chase"
        }
    }
    public var symbol: String {
        switch self {
        case .pong: "tennis.racket"
        case .asteroids: "moon.stars"
        case .fly: "airplane"
        case .pacman: "square.grid.3x3"
        }
    }
    public var mood: String {
        switch self {
        case .pong: "chill"
        case .asteroids: "groove"
        case .fly: "energy"
        case .pacman: "party"
        }
    }
}

public struct DJConnectWatchArcadeState: Sendable {
    public let game: DJConnectWatchArcadeGame
    public private(set) var playing = false
    public private(set) var started = false
    public private(set) var gameOver = false
    public private(set) var soundSequence: UInt64 = 0
    public private(set) var sound: DJConnectArcadeSound = .start
    private mutating func emit(_ cue: DJConnectArcadeSound) { sound = cue; soundSequence &+= 1 }
    public private(set) var score = 0
    public private(set) var elapsed: Double = 0
    public private(set) var control: Double = 0.5
    public private(set) var ball = CGPoint(x: 0.6, y: 0.5)
    private var velocity = CGPoint(x: -0.36, y: 0.23)
    public private(set) var obstacle = CGPoint(x: 0.7, y: 0.08)
    public private(set) var shot: CGPoint?
    public private(set) var player = 21
    public private(set) var ghost = 6
    public private(set) var direction = 1 // clockwise: up, right, down, left
    public private(set) var pellets = Set(0..<49)
    public private(set) var powerRemaining: Double = 0
    private var moveClock: Double = 0
    private var ghostClock: Double = 0
    private var seed: UInt64 = 17

    public init(game: DJConnectWatchArcadeGame) {
        self.game = game
        if game == .fly { obstacle = CGPoint(x: 1.1, y: 0.5) }
        pellets.remove(player)
    }
    public mutating func restart() {
        let previousSequence = soundSequence
        self = Self(game: game)
        soundSequence = previousSequence
        emit(.start)
        playing = true
        started = true
    }
    public mutating func togglePlaying() {
        if !started || gameOver { restart() } else { playing.toggle() }
    }
    public mutating func pause() { playing = false }
    public mutating func moveCrown(by delta: Double) {
        guard delta.isFinite else { return }
        if game == .pacman {
            direction = (direction + (delta > 0 ? 1 : delta < 0 ? 3 : 0)) % 4
        } else {
            control = min(0.9, max(0.1, control + delta))
        }
    }
    public mutating func tap(at location: CGPoint) {
        guard playing else { togglePlaying(); return }
        switch game {
        case .pong:
            control = min(0.9, max(0.1, location.y))
        case .asteroids:
            if shot == nil { shot = CGPoint(x: control, y: 0.84); emit(.fire) }
        case .fly:
            if shot == nil { shot = CGPoint(x: 0.22, y: control); emit(.fire) }
        case .pacman:
            let x = location.x - 0.5, y = location.y - 0.5
            direction = abs(x) > abs(y) ? (x > 0 ? 1 : 3) : (y > 0 ? 2 : 0)
        }
    }
    public mutating func advance(by interval: Double) {
        guard playing, interval.isFinite, interval > 0 else { return }
        let dt = min(interval, 0.05) // no catch-up jump after wrist-down/background
        elapsed += dt
        switch game {
        case .pong: advancePaddle(dt)
        case .asteroids: advanceMeteor(dt)
        case .fly: advanceSky(dt)
        case .pacman: advanceMaze(dt)
        }
    }
    private mutating func finish() { playing = false; gameOver = true; emit(game == .fly ? .crash : .gameOver) }
    private mutating func randomUnit() -> Double {
        seed = seed &* 6364136223846793005 &+ 1
        return Double(seed >> 32) / Double(UInt32.max)
    }
    private mutating func resetObstacle() {
        if game == .asteroids { obstacle = CGPoint(x: 0.12 + randomUnit() * 0.76, y: -0.08) }
        else { obstacle = CGPoint(x: 1.12, y: 0.14 + randomUnit() * 0.72) }
    }
    private mutating func advancePaddle(_ dt: Double) {
        ball.x += velocity.x * dt
        ball.y += velocity.y * dt
        if ball.y <= 0.03 || ball.y >= 0.97 {
            ball.y = min(0.97, max(0.03, ball.y)); velocity.y *= -1; emit(.bounce)
        }
        if ball.x >= 0.97 { ball.x = 0.97; velocity.x = -abs(velocity.x); emit(.bounce) }
        if ball.x <= 0.09 && velocity.x < 0 {
            if abs(ball.y - control) < 0.15 {
                ball.x = 0.09; velocity.x = min(0.7, abs(velocity.x) + 0.015)
                velocity.y = (ball.y - control) * 2.6
                score += 1; emit(.hit)
            } else { finish() }
        }
    }
    private mutating func advanceMeteor(_ dt: Double) {
        obstacle.y += dt * (0.20 + Double(min(score, 20)) * 0.008)
        if var bullet = shot {
            bullet.y -= dt * 1.1
            shot = bullet.y < -0.04 ? nil : bullet
            if hypot(bullet.x - obstacle.x, bullet.y - obstacle.y) < 0.10 {
                score += 1; shot = nil; resetObstacle(); emit(.explosion)
            }
        }
        if obstacle.y > 0.94 { finish() }
    }
    private mutating func advanceSky(_ dt: Double) {
        obstacle.x -= dt * (0.32 + Double(min(score, 20)) * 0.008)
        if var bullet = shot {
            bullet.x += dt * 1.2
            shot = bullet.x > 1.05 ? nil : bullet
            if abs(bullet.x - obstacle.x) < 0.09 && abs(bullet.y - obstacle.y) < 0.14 {
                score += 1; shot = nil; resetObstacle(); emit(.explosion)
            }
        }
        if obstacle.x < -0.1 { score += 1; resetObstacle(); emit(.collect) }
        if abs(obstacle.x - 0.18) < 0.10 && abs(obstacle.y - control) < 0.15 { finish() }
    }
    public static func mazeStep(_ cell: Int, direction: Int) -> Int {
        let column = cell % 7, row = cell / 7
        switch direction {
        case 0: return row > 0 ? cell - 7 : cell
        case 1: return column < 6 ? cell + 1 : cell
        case 2: return row < 6 ? cell + 7 : cell
        case 3: return column > 0 ? cell - 1 : cell
        default: return cell
        }
    }
    private mutating func advanceMaze(_ dt: Double) {
        powerRemaining = max(0, powerRemaining - dt)
        moveClock += dt; ghostClock += dt
        if moveClock >= 0.20 {
            moveClock -= 0.20
            player = Self.mazeStep(player, direction: direction)
            if pellets.remove(player) != nil {
                score += 1; emit(.collect)
                if [0, 6, 42, 48].contains(player) { powerRemaining = 6; emit(.power) }
            }
            if pellets.isEmpty { pellets = Set(0..<49); pellets.remove(player); score += 10; emit(.power) }
        }
        if ghostClock >= 0.48 {
            ghostClock -= 0.48
            let dx = player % 7 - ghost % 7, dy = player / 7 - ghost / 7
            var heading = abs(dx) > abs(dy) ? (dx > 0 ? 1 : 3) : (dy > 0 ? 2 : 0)
            if powerRemaining > 0 { heading = (heading + 2) % 4 }
            ghost = Self.mazeStep(ghost, direction: heading)
        }
        if player == ghost {
            if powerRemaining > 0 { ghost = player < 24 ? 48 : 0; score += 5; emit(.explosion) }
            else { finish() }
        }
    }
}
