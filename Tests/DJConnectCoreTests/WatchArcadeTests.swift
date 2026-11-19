import Foundation
import Testing
@testable import DJConnectCore

@Test func watchArcadeStopsWhenPausedAndDoesNotCatchUpAfterBackground() {
    var game = DJConnectWatchArcadeState(game: .pong)
    game.restart()
    game.advance(by: 20)
    #expect(game.elapsed == 0.05)
    let ball = game.ball
    game.pause()
    game.advance(by: 1)
    #expect(game.ball == ball)
    #expect(!game.playing)
}

@Test func watchArcadeCrownControlsStayInsideThePlayfield() {
    for kind in [DJConnectWatchArcadeGame.pong, .asteroids, .fly] {
        var game = DJConnectWatchArcadeState(game: kind)
        game.moveCrown(by: 1_000)
        #expect(game.control == 0.9)
        game.moveCrown(by: -1_000)
        #expect(game.control == 0.1)
        game.moveCrown(by: .nan)
        #expect(game.control == 0.1)
    }
}

@Test func watchMazeCrownAndTapChooseDirectionsWithoutWrappingRows() {
    var game = DJConnectWatchArcadeState(game: .pacman)
    game.restart()
    game.moveCrown(by: 1)
    #expect(game.direction == 2)
    game.tap(at: CGPoint(x: 0, y: 0.5))
    #expect(game.direction == 3)
    for _ in 0..<8 { game.advance(by: 0.05) }
    #expect(game.player == 21) // left edge stays inside the same row
    game.tap(at: CGPoint(x: 1, y: 0.5))
    for _ in 0..<4 { game.advance(by: 0.05) }
    #expect(game.player == 22)
    #expect(!game.pellets.contains(22))
    #expect(game.score == 1)
    #expect(DJConnectWatchArcadeState.mazeStep(6, direction: 1) == 6)
    #expect(DJConnectWatchArcadeState.mazeStep(42, direction: 2) == 42)
}

@Test func watchMeteorShotHitsAndAwardsScore() {
    var game = DJConnectWatchArcadeState(game: .asteroids)
    game.restart()
    game.moveCrown(by: 0.2)
    game.tap(at: .zero)
    #expect(game.shot != nil)
    for _ in 0..<30 { game.advance(by: 0.03) }
    #expect(game.score == 1)
    #expect(game.playing)
    #expect(game.shot == nil)
}

@Test func watchSkyAvoidingAnObstacleScoresAndRestartResetsTheRound() {
    var game = DJConnectWatchArcadeState(game: .fly)
    game.restart()
    game.moveCrown(by: -1)
    for _ in 0..<80 { game.advance(by: 0.05) }
    #expect(game.score >= 1)
    #expect(game.playing)
    game.restart()
    #expect(game.score == 0)
    #expect(game.control == 0.5)
    #expect(game.shot == nil)
}
