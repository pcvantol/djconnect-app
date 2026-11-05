import Foundation

/// Backend-owned choices. Only VisualRecipe may enter a device model or renderer.
public struct DJConnectForYou: Codable, Equatable, Sendable {
    public struct VisualRecipe: Codable, Equatable, Hashable, Sendable {
        public let schema_version: Int
        public let revision: Int
        public let variation_id: String
        public let genre: String
        public let mood: String
        public let persona: String
        public let artistic_direction: String
        public let illustrative_not_audio_analysis: Bool
        public var isSupported: Bool {
            schema_version == 1 && revision == 1 && illustrative_not_audio_analysis &&
            Self.safe(variation_id, 128) && Self.safe(genre, 160) && Self.safe(persona, 80) &&
            ["chill", "groove", "energy", "party"].contains(mood) &&
            ["layered_dunes", "misty_valley", "mountain_horizon"].contains(artistic_direction)
        }
        fileprivate static func safe(_ value: String, _ limit: Int) -> Bool {
            !value.isEmpty && value.utf8.count <= limit && !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        }
    }
    public struct Option: Codable, Equatable, Identifiable, Sendable {
        public let option_id: String
        public let action_id: String
        public let genre: String
        public let label: String
        public let visual_recipe: VisualRecipe
        public var id: String { option_id }
    }
    public struct Refresh: Codable, Equatable, Sendable {
        public let prompt: String
        public let automatic: Bool
    }
    public let schema_version: Int
    public let offer_id: String
    public let session_id: String
    public let title: String
    public let visible: Bool
    public let state: String
    public let intro: String?
    public let intro_source: String?
    public let options: [Option]
    public let result_set: DJConnectResultSet?
    public let conversation_context: DJConnectConversationContext?
    public let automatic_playback: Bool
    public let queue_effect: String?
    public let actions_available: Bool?
    public let expires_in: Double?
    public let reason: String?
    public let refresh_request: Refresh?

    public var isSupported: Bool {
        guard schema_version == 1, !automatic_playback,
              VisualRecipe.safe(offer_id, 256), VisualRecipe.safe(session_id, 256),
              VisualRecipe.safe(title, 320), (intro?.utf8.count ?? 0) <= 2400,
              ["available", "unavailable", "ready", "attempted", "awaiting_output", "confirmed", "dismissed", "closed", "uncertain"].contains(state),
              options.isEmpty || options.count == 3,
              Set(options.map(\.id)).count == options.count,
              Set(options.map(\.action_id)).count == options.count,
              options.allSatisfy({ VisualRecipe.safe($0.id, 256) && VisualRecipe.safe($0.action_id, 256) &&
                  VisualRecipe.safe($0.label, 320) && $0.genre == $0.visual_recipe.genre && $0.visual_recipe.isSupported }),
              expires_in.map({ $0.isFinite && (0...60).contains($0) }) ?? true else { return false }
        if let context = conversation_context {
            guard context.sessionID == session_id, context.selectedEntry == nil, context.selectedMoment == nil,
                  context.threadID.map({ VisualRecipe.safe($0, 256) }) == true else { return false }
        }
        if actions_available == true {
            guard visible, ["available", "ready"].contains(state), (expires_in ?? 0) > 0,
                  queue_effect == "replace_on_explicit_selection", options.count == 3,
                  conversation_context != nil, let result_set, result_set.resultSetID == offer_id,
                  result_set.admittedPlaybackActions.count == 3,
                  result_set.admittedPlaybackActions.allSatisfy({ $0.kind == "track_mix" }),
                  Set(result_set.admittedPlaybackActions.compactMap(\.actionID)) == Set(options.map(\.action_id)) else { return false }
        }
        if !visible && (!options.isEmpty || actions_available == true) { return false }
        if let refresh_request {
            guard !refresh_request.automatic, VisualRecipe.safe(refresh_request.prompt, 720) else { return false }
        }
        return true
    }
}
