import Foundation

/// Ephemeral owner Broadcast content. Never persist or export this projection.
public struct DJConnectMoment: Codable, Equatable, Sendable, Identifiable {
    public var momentID: String
    public var sessionID: String
    public var createdAt: String
    public var type: String
    public var title: String
    public var summary: String
    public var content: String
    public var presentationIntent: PresentationIntent
    public var knowledgeIntent: [String: String]?
    public var visibility: String?
    public var deliveryChannels: [String]?
    public var importance: String?
    public var artwork: Artwork?
    public var actions: [Action]
    public var sourceReferences: [String]
    public var sourceAttribution: [String: String]?
    public var generationMetadata: [String: String]?
    public var playbackItemID: String?
    public var id: String { momentID }

    public struct Artwork: Codable, Equatable, Sendable { public var url: String? }
    public struct Action: Codable, Equatable, Sendable {
        public var actionType: String
        public var label: String
        public var iconHint: String?
        public var priority: Int?
        public var requiredCapability: String?
        public var payload: [String: String]?
        enum CodingKeys: String, CodingKey {
            case label, priority, payload
            case actionType = "action_type", iconHint = "icon_hint", requiredCapability = "required_capability"
        }
    }
    public struct PresentationIntent: Codable, Equatable, Sendable {
        public var sourceSessionMood: String?
        public var djPersona: String?
        public var toneOfVoice: String?
        public var energyLevel: String?
        public var deliveryStyle: String?
        public var voiceStyle: String?
        public var visualTheme: String?
        public var importance: String?
        public var maximumDurationSeconds: Int?
        public var deliveryChannels: [String]?
        public var visibility: String
        enum CodingKeys: String, CodingKey {
            case visibility, importance
            case sourceSessionMood = "source_session_mood", djPersona = "dj_persona", toneOfVoice = "tone_of_voice"
            case energyLevel = "energy_level", deliveryStyle = "delivery_style", voiceStyle = "voice_style"
            case visualTheme = "visual_theme", maximumDurationSeconds = "maximum_duration_seconds", deliveryChannels = "delivery_channels"
        }
    }
    enum CodingKeys: String, CodingKey {
        case type, title, summary, content, artwork, actions
        case momentID = "moment_id", sessionID = "session_id", createdAt = "created_at"
        case presentationIntent = "presentation_intent", sourceReferences = "source_references"
        case knowledgeIntent = "knowledge_intent", visibility, deliveryChannels = "delivery_channels", importance
        case sourceAttribution = "source_attribution", generationMetadata = "generation_metadata", playbackItemID = "playback_item_id"
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        momentID = try c.decode(String.self, forKey: .momentID)
        sessionID = try c.decode(String.self, forKey: .sessionID)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        type = try c.decode(String.self, forKey: .type)
        content = try c.decode(String.self, forKey: .content)
        presentationIntent = try c.decode(PresentationIntent.self, forKey: .presentationIntent)
        knowledgeIntent = try? c.decode([String: String].self, forKey: .knowledgeIntent)
        visibility = try? c.decode(String.self, forKey: .visibility)
        deliveryChannels = try? c.decode([String].self, forKey: .deliveryChannels)
        importance = try? c.decode(String.self, forKey: .importance)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        summary = (try? c.decode(String.self, forKey: .summary)) ?? ""
        artwork = try? c.decode(Artwork.self, forKey: .artwork)
        actions = (try? c.decode([LossyBroadcastValue<Action>].self, forKey: .actions))?.compactMap(\.value) ?? []
        sourceReferences = (try? c.decode([String].self, forKey: .sourceReferences)) ?? []
        // Broken attribution must not turn restricted source content into an
        // apparently unrestricted card. Only this entry is discarded upstream.
        sourceAttribution = try c.decodeIfPresent([String: String].self, forKey: .sourceAttribution)
        generationMetadata = try? c.decode([String: String].self, forKey: .generationMetadata)
        playbackItemID = try? c.decode(String.self, forKey: .playbackItemID)
    }
}

public struct DJConnectSessionPlayback: Codable, Equatable, Sendable {
    public var state: String?
    public var itemID: String?
    public var title: String?
    public var artist: String?
    public var album: String?
    public var artworkURL: String?
    public var durationMS: Int?
    public var positionMS: Int?
    public var updatedAt: String?
    public var sourceURL: String?
    enum CodingKeys: String, CodingKey {
        case state, title, artist, album
        case itemID = "item_id", artworkURL = "artwork_url", durationMS = "duration_ms", positionMS = "position_ms"
        case updatedAt = "updated_at", sourceURL = "source_url"
    }
}

public struct DJConnectPresentation: Codable, Equatable, Sendable, Identifiable {
    public var presentationID: String
    public var momentID: String
    public var momentType: String
    public var visibility: String
    public var speech: Speech?
    public var id: String { presentationID }
    public struct Speech: Codable, Equatable, Sendable {
        public var mode: String
        public var segments: [Segment]
        public struct Segment: Codable, Equatable, Sendable {
            public var ordinal: Int
            public var speakerRole: String
            public var text: String
            enum CodingKeys: String, CodingKey { case ordinal, text; case speakerRole = "speaker_role" }
        }
    }
    enum CodingKeys: String, CodingKey {
        case visibility, speech
        case presentationID = "presentation_id", momentID = "source_moment_id", momentType = "source_moment_type"
    }
}

struct LossyBroadcastValue<Value: Decodable>: Decodable {
    let value: Value?
    init(from decoder: Decoder) throws { value = try? Value(from: decoder) }
}
