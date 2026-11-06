import Testing
@testable import DJConnectCore
@testable import DJConnectUI

@Test(arguments: [DJConnectSessionMoodTheme.chill, .groove, .energy, .party])
func forYouRelatedRockGenresKeepDifferentSilhouettesWithinTheSameMood(_ theme: DJConnectSessionMoodTheme) {
    let genres = ["alternative rock", "rock", "classic rock"]
    let style = ForYouMoodLandscapeStyle(theme: theme)
    let profiles = genres.map { genre in
        (0...24).map { step in
            style.elevation(x: Double(step) / 24, layer: 1, seed: 0.3,
                direction: "mountain_horizon", genre: genre, horizon: 0.44, depth: 0.2, phase: 0)
        }
    }
    #expect(Set(profiles).count == 3)
    // A phase/seed-only difference is not enough: large-scale silhouettes differ.
    for pair in [(0, 1), (0, 2), (1, 2)] {
        let difference = zip(profiles[pair.0], profiles[pair.1]).map { abs($0 - $1) }.reduce(0, +) / 25
        #expect(difference > 0.025)
    }
}

@Test func forYouMoodsHaveDistinctTerrainAndMotion() {
    let themes: [DJConnectSessionMoodTheme] = [.chill, .groove, .energy, .party]
    let signatures = themes.map { theme in
        let style = ForYouMoodLandscapeStyle(theme: theme)
        return (0...12).map { step in
            style.elevation(x: Double(step) / 12, layer: 1, seed: 0.37,
                direction: "layered_dunes", horizon: 0.44, depth: 0.2, phase: 0)
        }
    }
    #expect(Set(signatures).count == 4)
    let speeds = themes.map { ForYouMoodLandscapeStyle(theme: $0).speed }
    #expect(zip(speeds, speeds.dropFirst()).allSatisfy { $0 < $1 })
}

@Test(arguments: [DJConnectSessionMoodTheme.chill, .groove, .energy, .party])
func forYouLandscapeMovesLocallyAndKeepsEveryTerrainBounded(_ theme: DJConnectSessionMoodTheme) {
    let style = ForYouMoodLandscapeStyle(theme: theme)
    func samples(_ phase: Double, _ direction: String) -> [Double] {
        (0...20).map { style.elevation(x: Double($0) / 20, layer: 2, seed: 0.23,
            direction: direction, horizon: 0.44, depth: 0.4, phase: phase) }
    }
    let directions = ["layered_dunes", "misty_valley", "mountain_horizon"]
    #expect(Set(directions.map { samples(0, $0) }).count == 3)
    #expect(samples(0, directions[0]) != samples(1, directions[0]))
    for phase in [0.0, 1, 100_000] {
        for direction in directions {
            #expect(samples(phase, direction).allSatisfy { $0.isFinite && (0.16...0.94).contains($0) })
        }
    }
}
