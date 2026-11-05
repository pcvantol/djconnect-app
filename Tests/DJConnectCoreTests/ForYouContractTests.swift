import Foundation
import Testing
@testable import DJConnectCore

private func forYouWire() throws -> [String: Any] {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let envelope = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/session-for-you-v1.json"))) as? [String: Any])
    return try #require(envelope["for_you"] as? [String: Any])
}
private func forYouData(_ wire: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: wire) }

@Test func forYouContractPreservesOriginalChoicesAndThread() throws {
    let wire = try forYouWire()
    let offer = try JSONDecoder().decode(DJConnectForYou.self, from: forYouData(wire))
    #expect(offer.isSupported && offer.options.count == 3)
    #expect(Set(offer.options.map(\.visual_recipe.artistic_direction)).count == 3)
    let context = try #require(offer.conversation_context)
    #expect(context.threadID == "for-you-" + offer.session_id)
    let roundTrip = try JSONDecoder().decode(DJConnectConversationContext.self, from: JSONEncoder().encode(context))
    #expect(roundTrip == context)
    // Only the recipe is serialized for local illustration, no effect/source grant.
    let recipe = String(decoding: try JSONEncoder().encode(offer.options[0].visual_recipe), as: UTF8.self)
    for forbidden in ["action_id", "offer_id", "thread_id", "uri", "profile", "history"] { #expect(!recipe.contains(forbidden)) }
    let dismissal = try JSONSerialization.jsonObject(with: JSONEncoder().encode(DJConnectConversationChoice.dismiss(offerID: offer.offer_id))) as? [String: String]
    #expect(dismissal == ["operation": "dismiss", "result_set_id": offer.offer_id, "action_id": ""])
}

@Test func forYouContractRejectsCrossSessionUnsafeAndFutureOffers() throws {
    for mutation in ["schema", "auto", "context", "recipe", "actions", "deadline", "refresh"] {
        var wire = try forYouWire()
        switch mutation {
        case "schema": wire["schema_version"] = 2
        case "auto": wire["automatic_playback"] = true
        case "context": wire["conversation_context"] = ["session_id": "other", "thread_id": "other"]
        case "recipe":
            var options = wire["options"] as! [[String: Any]]
            var recipe = options[0]["visual_recipe"] as! [String: Any]
            recipe["illustrative_not_audio_analysis"] = false; options[0]["visual_recipe"] = recipe; wire["options"] = options
        case "actions":
            var options = wire["options"] as! [[String: Any]]; options[0]["action_id"] = "invented"; wire["options"] = options
        case "deadline": wire["expires_in"] = 61
        default: wire["refresh_request"] = ["automatic": true, "prompt": "refresh"]
        }
        #expect(try !JSONDecoder().decode(DJConnectForYou.self, from: forYouData(wire)).isSupported)
    }
    for versions in [(1,2), (2,3), (2,4), (3,3)] {
        let caps: [String: Any] = ["capabilities": ["session_start_actions": true, "session_first_play_surprise_mix": true],
            "contract_versions": ["session_start_actions": versions.0, "session_first_play_surprise_mix": versions.1]]
        #expect(try JSONDecoder().decode(DJConnectActiveMoodCapabilities.self, from: forYouData(caps)).forYouAvailable == (versions == (2,3)))
    }
    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self,
        from: forYouData(["success": true, "for_you": ["schema_version": 1, "state": "dismissed", "visible": false]]))
    #expect(response.forYouDismissed && response.forYou == nil)
}
