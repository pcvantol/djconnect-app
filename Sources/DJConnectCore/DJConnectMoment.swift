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


/// Ephemeral replacement authority supplied by the owner Broadcast route.
public struct DJConnectNativeMomentDelivery: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var sessionID: String
    public var revision: String
    public var currentMomentID: String?
    public var activeFlowMomentIDs: [String]
    public var admissions: [Admission]
    public var revocationScope: String
    public struct Admission: Codable, Equatable, Sendable {
        public var momentID: String
        public var qualification: String
        public var currentDisplayAllowed: Bool
        public var activeFlowDisplayAllowed: Bool
        public var sourceExpiresAt: String?
        public var displayExpiresAt: String?
        public var executableActions: [String]
        public var requiresSpotifyAttribution: Bool
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            guard c.contains(.sourceExpiresAt), c.contains(.displayExpiresAt) else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Incomplete native deadline authority")) }
            momentID = try c.decode(String.self, forKey: .momentID)
            qualification = try c.decode(String.self, forKey: .qualification)
            currentDisplayAllowed = try c.decode(Bool.self, forKey: .currentDisplayAllowed)
            activeFlowDisplayAllowed = try c.decode(Bool.self, forKey: .activeFlowDisplayAllowed)
            sourceExpiresAt = try c.decodeIfPresent(String.self, forKey: .sourceExpiresAt)
            displayExpiresAt = try c.decodeIfPresent(String.self, forKey: .displayExpiresAt)
            executableActions = try c.decode([String].self, forKey: .executableActions)
            requiresSpotifyAttribution = try c.decode(Bool.self, forKey: .requiresSpotifyAttribution)
        }
        enum CodingKeys: String, CodingKey {
            case momentID = "moment_id", qualification
            case currentDisplayAllowed = "current_display_allowed", activeFlowDisplayAllowed = "active_flow_display_allowed"
            case sourceExpiresAt = "source_expires_at", displayExpiresAt = "display_expires_at"
            case executableActions = "executable_actions", requiresSpotifyAttribution = "requires_spotify_attribution"
        }
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard c.contains(.currentMomentID) else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Incomplete native current authority")) }
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        sessionID = try c.decode(String.self, forKey: .sessionID)
        revision = try c.decode(String.self, forKey: .revision)
        currentMomentID = try c.decodeIfPresent(String.self, forKey: .currentMomentID)
        activeFlowMomentIDs = try c.decode([String].self, forKey: .activeFlowMomentIDs)
        admissions = try c.decode([Admission].self, forKey: .admissions)
        revocationScope = try c.decode(String.self, forKey: .revocationScope)
    }
    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version", sessionID = "session_id", revision
        case currentMomentID = "current_moment_id", activeFlowMomentIDs = "active_flow_moment_ids"
        case admissions, revocationScope = "revocation_scope"
    }
}

public extension DJConnectMoment {
    /// Preserve producer references and both recording attributions without inventing URLs.
    var nativeSourceURLs: [URL] {
        let references = sourceReferences + [sourceAttribution?["url"], sourceAttribution?["url_previous"]].compactMap { $0 }
        var seen = Set<String>()
        return references.compactMap { raw in
            guard let url = URL(string: raw), url.scheme == "https", url.host != nil,
                  url.user == nil, url.password == nil, seen.insert(raw).inserted else { return nil }
            return url
        }
    }
}

public extension DJConnectBroadcastState {
    mutating func clearNativeAuthority() {
        nativeDelivery = nil
        djMoments = []
        presentations = []
    }
    func nativeCurrentMoment(at date: Date) -> DJConnectMoment? {
        guard session.runtimeState == "active", playback?.state == "playing",
              let authority = nativeDelivery, authority.schemaVersion == 1,
              authority.sessionID == session.sessionID, authority.revocationScope == "session",
              !authority.revision.isEmpty, let id = authority.currentMomentID,
              let moment = djMoments.first(where: { $0.id == id }),
              moment.playbackItemID == playback?.itemID,
              admitted(moment, authority: authority, at: date, current: true) else { return nil }
        return moment
    }
    func nativeFlowMoments(at date: Date) -> [DJConnectMoment] {
        guard session.runtimeState == "active", let authority = nativeDelivery,
              authority.schemaVersion == 1, authority.sessionID == session.sessionID,
              authority.revocationScope == "session", !authority.revision.isEmpty else { return [] }
        let currentID = nativeCurrentMoment(at: date)?.id
        var seen = Set<String>()
        return authority.activeFlowMomentIDs.compactMap { id in
            guard id != currentID, seen.insert(id).inserted,
                  sessionFlow.items.contains(where: { $0.itemType == "dj_moment" && $0.momentID == id }),
                  let moment = djMoments.first(where: { $0.id == id }),
                  admitted(moment, authority: authority, at: date, current: false) else { return nil }
            return moment
        }
    }
    private func admitted(_ moment: DJConnectMoment, authority: DJConnectNativeMomentDelivery, at date: Date, current: Bool) -> Bool {
        let matches = authority.admissions.filter { $0.momentID == moment.id }
        guard matches.count == 1, let admission = matches.first,
              admission.qualification == "qualified", admission.executableActions.isEmpty,
              moment.sessionID == session.sessionID, !moment.content.isEmpty,
              ["owner_only", "session_shared", "public_broadcast"].contains(moment.presentationIntent.visibility),
              current ? admission.currentDisplayAllowed : admission.activeFlowDisplayAllowed else { return false }
        // This renderer has no qualified Spotify mark asset. Do not silently
        // grant its current-only cards or turn them into CC0 historical recall.
        guard !admission.requiresSpotifyAttribution else { return false }
        if let source = admission.sourceExpiresAt {
            guard let expiry = nativeDeadline(source), date < expiry,
                  let provider = moment.sourceAttribution?["provider"], ["MusicBrainz", "Wikidata"].contains(provider),
                  moment.sourceAttribution?["license"] == "CC0-1.0",
                  let url = moment.sourceAttribution?["url"], moment.nativeSourceURLs.contains(where: { $0.absoluteString == url }) else { return false }
            if let previous = moment.sourceAttribution?["url_previous"], !moment.nativeSourceURLs.contains(where: { $0.absoluteString == previous }) { return false }
        } else {
            guard moment.type == "session", moment.sourceAttribution == nil,
                  moment.sourceReferences == ["session_direction"],
                  moment.knowledgeIntent?["type"] == "session_direction",
                  moment.generationMetadata?["context_source"] == "session_direction",
                  moment.generationMetadata?["validated"] == "true" else { return false }
        }
        if current {
            guard let deadline = admission.displayExpiresAt.flatMap(nativeDeadline), date < deadline else { return false }
        }
        return true
    }
}

private func nativeDeadline(_ value: String) -> Date? {
    let parser = ISO8601DateFormatter()
    parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return parser.date(from: value) ?? ISO8601DateFormatter().date(from: value)
}
