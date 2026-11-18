import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

@Suite struct RecentHistoryPresentationTests {
    private let intent = DJConnectAskDJIntentInfo(intent: "recently_played_history", action: "recently_played", itemType: "tracks")
    @Test func removesOnlyDuplicatedRowsAndPreservesNarrativeAndUnrepresentedItems() {
        let item = DJConnectAskDJHistoryItem(kind: "track", title: "Have A Little Faith", subtitle: "Son Mieux", uri: "spotify:track:a")
        let original = "Dit heb je het afgelopen uur afgespeeld:\n- Son Mieux - Have A Little Faith\n- Son Mieux - Other recording\n- ... en nog 7 items.\nEen toelichting."
        var message = DJConnectAskDJMessage(role: .dj, text: original, intentInfo: intent, items: [item, item])
        #expect(message.catalogueTextForDisplay == "Dit heb je het afgelopen uur afgespeeld:\n- Son Mieux - Other recording\n- ... en nog 7 items.\nEen toelichting.")
        #expect(message.text == original && message.items.count == 2)
        message.items = []
        #expect(message.catalogueTextForDisplay == original)
        message.items = [item]; message.intentInfo = nil
        #expect(message.catalogueTextForDisplay == original)
    }
    @Test func originalBackendActionIsUsedForEveryRepeatedListenWithoutInventingAnAction() throws {
        let item = DJConnectAskDJHistoryItem(kind: "track", title: "Old Love", subtitle: "Son Mieux", uri: "spotify:track:a")
        var message = DJConnectAskDJMessage(role: .dj, text: "- Son Mieux - Old Love", intentInfo: intent, items: [item, item])
        #expect(message.playbackAction(forHistoryItem: item) == nil)
        let action = DJConnectAskDJPlaybackAction(id: "server-action", title: item.title, uri: item.uri, kind: "track", command: "ask_dj_play_recommendation")
        message.playbackActions = [action]
        #expect(message.items.allSatisfy { message.playbackAction(forHistoryItem: $0) == action })
        let restored = try JSONDecoder().decode(DJConnectAskDJMessage.self, from: JSONEncoder().encode(message))
        #expect(restored.playbackAction(forHistoryItem: item) == action)
        #expect(restored.catalogueTextForDisplay.isEmpty)
    }
    @Test func albumHistoryUsesTheProducerTitleThenArtistOrder() {
        let album = DJConnectAskDJHistoryItem(kind: "album", title: "Album", subtitle: "Artist")
        let message = DJConnectAskDJMessage(role: .dj, text: "Albums:\n- Album - Artist",
            intentInfo: .init(intent: "recently_played_history", action: "recently_played", itemType: "albums"), items: [album])
        #expect(message.catalogueTextForDisplay == "Albums:")
    }
    @Test func otherMessagesAndDistinctEditionsKeepTheirText() {
        let item = DJConnectAskDJHistoryItem(kind: "track", title: "Old Love", subtitle: "Son Mieux")
        var message = DJConnectAskDJMessage(role: .user, text: "- Son Mieux - Old Love", intentInfo: intent, items: [item])
        #expect(message.catalogueTextForDisplay == message.text)
        message.role = .dj; message.text = "- Son Mieux - Old Love (Live)"
        #expect(message.catalogueTextForDisplay == message.text)
    }
}
