import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

@Test func askDJSourcesCollapseRepeatedDestinationsWithoutLosingDistinctTracks() throws {
    let first = DJConnectResponseLink(url: try #require(URL(string: "https://open.spotify.com/track/first")),
        title: "Spotify", kind: "source", source: "spotify_playback_context")
    var duplicate = first
    duplicate.title = "Spotify playback context"
    var second = first
    second.url = try #require(URL(string: "https://open.spotify.com/track/second"))
    let regular = DJConnectResponseLink(url: try #require(URL(string: "https://example.com/help")), title: "Help", kind: "link")
    let message = DJConnectAskDJMessage(role: .dj, text: "Current track", links: [first, duplicate, second, regular])
    #expect(message.sourceLinksForDisplay == [first, second])
    #expect(message.links == [first, duplicate, second, regular])
}
