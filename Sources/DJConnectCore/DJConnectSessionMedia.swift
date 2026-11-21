import Foundation

/// Optional owner-only media. This projection and its grant must never be persisted.
/// Unknown/invalid optional media is discarded independently of the original text.
public struct DJConnectSessionMedia: Codable, Equatable, Sendable {
    public enum Audience: Equatable, Sendable { case current, activeFlow, history, reply }
    public enum Target: Hashable, Sendable { case moment(String), entry(String) }
    public enum State: String, Codable, Sendable {
        case ready, loading, missing, expired, withdrawn, unavailable
    }
    public struct Subject: Codable, Equatable, Sendable {
        public let provider: String
        public let type: String
        public let uri: String
        public let albumURI: String?
        enum CodingKeys: String, CodingKey { case provider, type, uri; case albumURI = "album_uri" }
    }
    public struct Attribution: Codable, Equatable, Sendable {
        public let provider: String
        public let mark: String
        public let url: String
    }
    public struct Artwork: Codable, Equatable, Sendable {
        public let state: State
        public let reason: String?
        public let subject: Subject?
        public let role: String?
        public let resolutionBasis: String?
        public let editionBasis: String?
        public let sourceURL: String?
        public let attribution: Attribution?
        public let usageBasis: String?
        public let capturedAt: String?
        public let expiresAt: String?
        public let currentDisplayAllowed: Bool
        public let activeFlowDisplayAllowed: Bool
        public let replyDisplayAllowed: Bool?
        public let historicalDisplayAllowed: Bool
        public let cachePolicy: String?
        public let cropAllowed: Bool?
        public let upscaleAllowed: Bool?
        public let requiresDeviceAuth: Bool?
        public let width: Int?
        public let height: Int?
        public let altText: [String: String]?
        public let url: String?
        public let mediaRevision: String?
        enum CodingKeys: String, CodingKey {
            case upscaleAllowed = "upscale_allowed"
            case state, reason, subject, role, attribution, width, height, url
            case resolutionBasis = "resolution_basis", editionBasis = "edition_basis"
            case sourceURL = "source_url", usageBasis = "usage_basis", capturedAt = "captured_at", expiresAt = "expires_at"
            case currentDisplayAllowed = "current_display_allowed", activeFlowDisplayAllowed = "active_flow_display_allowed"
            case replyDisplayAllowed = "reply_display_allowed"
            case historicalDisplayAllowed = "historical_display_allowed", cachePolicy = "cache_policy", cropAllowed = "crop_allowed"
            case requiresDeviceAuth = "requires_device_auth", altText = "alt_text", mediaRevision = "media_revision"
        }
    }
    public let schemaVersion: Int
    public let sessionID: String
    public let momentID: String?
    public let entryID: String?
    public let photoID: String?
    /// Equality token only. Neither revision is an ordering clock.
    public let revision: String
    public let artwork: Artwork
    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version", sessionID = "session_id", momentID = "moment_id", entryID = "entry_id"
        case photoID = "photo_id"
        case revision, artwork
    }

    public var target: Target? {
        if let momentID, !momentID.isEmpty, entryID == nil { return .moment(momentID) }
        if let entryID, !entryID.isEmpty, momentID == nil { return .entry(entryID) }
        return nil
    }

    /// Checks a grant against the caller's existing authorized context. This does
    /// not establish Profile authority or fetch/prepare/renew any resource.
    public func admittedArtwork(session expectedSession: String, target expectedTarget: Target,
                                audience: Audience, at now: Date = Date()) -> Artwork? {
        guard let subject = admittedArtworkSubject(session: expectedSession, target: expectedTarget, at: now) else { return nil }
        if artwork.role == "captured_reply_subject" {
            return admittedReplyArtwork(subject: subject, audience: audience)
        }
        guard artworkAllowsAudience(audience), contextualArtworkSubjectIsValid(subject) else { return nil }
        return artwork
    }

    private func admittedArtworkSubject(session expectedSession: String, target expectedTarget: Target, at now: Date) -> Subject? {
        guard schemaVersion == 1, !sessionID.isEmpty, sessionID == expectedSession, target == expectedTarget,
              !revision.isEmpty, revision.utf8.count <= 128, artwork.state == .ready,
              artwork.cachePolicy == "no-store", artwork.cropAllowed == false, artwork.requiresDeviceAuth == true,
              artwork.usageBasis == "spotify_temporary_owner_display", artwork.resolutionBasis == "resolved_now",
              let mediaRevision = artwork.mediaRevision, !mediaRevision.isEmpty, mediaRevision.utf8.count <= 128,
              let captured = artwork.capturedAt.flatMap(DJConnectHistoryEntry.date),
              let expires = artwork.expiresAt.flatMap(DJConnectHistoryEntry.date),
              captured <= now, expires > now, expires > captured, expires.timeIntervalSince(captured) <= 300.001,
              let width = artwork.width, let height = artwork.height,
              width > 0, height > 0, width <= 4096, height <= 4096, width * height <= 16_000_000,
              let subject = artwork.subject, subject.provider == "spotify",
              let exactSource = Self.spotifySource(subject.uri, type: subject.type),
              artwork.sourceURL == exactSource, artwork.attribution?.url == exactSource,
              artwork.attribution?.provider == "Spotify", artwork.attribution?.mark == "spotify",
              let rawURL = artwork.url, Self.isManagedPath(rawURL, session: sessionID),
              let alt = artwork.altText, ["en", "nl", "de", "fr", "es"].allSatisfy({ alt[$0]?.isEmpty == false })
        else { return nil }
        return subject
    }

    private func admittedReplyArtwork(subject: Subject, audience: Audience) -> Artwork? {
        guard case .entry = target, artwork.replyDisplayAllowed == true,
              !artwork.currentDisplayAllowed, !artwork.activeFlowDisplayAllowed else { return nil }
        switch audience {
        case .reply: break
        case .history: guard artwork.historicalDisplayAllowed else { return nil }
        case .current, .activeFlow: return nil
        }
        guard replyArtworkSubjectIsValid(subject) else { return nil }
        return artwork
    }

    private func replyArtworkSubjectIsValid(_ subject: Subject) -> Bool {
        switch subject.type {
        case "track":
            guard artwork.editionBasis == "original_bound", let album = subject.albumURI,
                  Self.spotifySource(album, type: "album") != nil else { return false }
        case "album":
            guard artwork.editionBasis == "original_bound", (subject.albumURI == nil || subject.albumURI == subject.uri) else { return false }
        case "artist":
            guard artwork.editionBasis == "not_applicable", subject.albumURI == nil else { return false }
        default: return false
        }
        return true
    }

    private func artworkAllowsAudience(_ audience: Audience) -> Bool {
        switch audience {
        case .reply: return false
        case .current: guard artwork.currentDisplayAllowed else { return false }
        case .activeFlow: guard artwork.activeFlowDisplayAllowed else { return false }
        case .history: guard artwork.historicalDisplayAllowed else { return false }
        }
        return true
    }

    private func contextualArtworkSubjectIsValid(_ subject: Subject) -> Bool {
        switch subject.type {
        case "artist":
            guard artwork.role == "contextual_artist", artwork.editionBasis == "not_applicable", subject.albumURI == nil else { return false }
        case "album":
            guard artwork.role == "cover", artwork.editionBasis == "original_bound" else { return false }
        case "track":
            guard ["cover", "playback_thumbnail"].contains(artwork.role ?? ""),
                  ["original_bound", "provider_resolved_now"].contains(artwork.editionBasis ?? "") else { return false }
            if let album = subject.albumURI, Self.spotifySource(album, type: "album") == nil { return false }
            if artwork.editionBasis == "original_bound", subject.albumURI == nil { return false }
        default: return false
        }
        return true
    }

    /// Version 3 is scoped to an original licensed event photo, never Spotify artwork.
    public func admittedLivePhoto(_ photo: DJConnectLiveImpression.Photo, session expectedSession: String,
                                  target expectedTarget: Target, audience: Audience, at now: Date = Date()) -> Artwork? {
        guard schemaVersion == 3, sessionID == expectedSession, target == expectedTarget,
              photoID == photo.photoID, photo.isValid, !revision.isEmpty, revision.utf8.count <= 128,
              artwork.state == .ready, artwork.role == "live_impression",
              artwork.usageBasis == "licensed_event_image_owner_display",
              artwork.subject?.provider == "public_research", artwork.subject?.type == "event_photo",
              artwork.subject?.uri == photo.photoID, artwork.subject?.albumURI == nil,
              artwork.mediaRevision == photo.revision, artwork.sourceURL == photo.sourceURL,
              artwork.width == photo.width, artwork.height == photo.height,
              artwork.cachePolicy == "no-store", artwork.requiresDeviceAuth == true,
              artwork.cropAllowed == false, artwork.upscaleAllowed == false,
              let captured = artwork.capturedAt.flatMap(DJConnectHistoryEntry.date),
              let expires = artwork.expiresAt.flatMap(DJConnectHistoryEntry.date),
              captured <= now, expires > now, expires > captured, expires.timeIntervalSince(captured) <= 300.001,
              let raw = artwork.url, Self.isManagedPath(raw, session: sessionID) else { return nil }
        switch audience {
        case .current: guard artwork.currentDisplayAllowed else { return nil }
        case .activeFlow: guard artwork.activeFlowDisplayAllowed else { return nil }
        case .history: guard artwork.historicalDisplayAllowed else { return nil }
        case .reply: return nil
        }
        return artwork
    }

    /// Audience comes from this entry grant, never from the currently playing track.
    public var entryAudience: Audience {
        if artwork.historicalDisplayAllowed { return .history }
        return artwork.role == "captured_reply_subject" ? .reply : .activeFlow
    }

    private static func spotifySource(_ uri: String, type: String) -> String? {
        let parts = uri.split(separator: ":", omittingEmptySubsequences: false)
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".utf8)
        guard ["track", "album", "artist"].contains(type), parts.count == 3,
              parts[0] == "spotify", parts[1] == type, parts[2].utf8.count == 22,
              parts[2].utf8.allSatisfy({ allowed.contains($0) }) else { return nil }
        return "https://open.spotify.com/\(type)/\(parts[2])"
    }

    private static func isManagedPath(_ raw: String, session: String) -> Bool {
        guard let components = URLComponents(string: raw), components.scheme == nil, components.host == nil,
              components.user == nil, components.password == nil, components.query == nil, components.fragment == nil,
              !raw.contains("%"), !raw.contains("\\") else { return false }
        let parts = raw.split(separator: "/", omittingEmptySubsequences: false)
        let prefix = "/api/djconnect/v1/session/media/image/\(session)/"
        return raw.hasPrefix(prefix) && parts.count == 9 &&
            parts.last?.isEmpty == false && parts.last != "." && parts.last != ".."
    }
}

/// Malformed optional media must not suppress an otherwise valid history row.
struct DJConnectOptionalSessionMedia: Codable, Equatable, Sendable {
    let value: DJConnectSessionMedia?
    init(value: DJConnectSessionMedia?) { self.value = value }
    init(from decoder: Decoder) throws { value = try? DJConnectSessionMedia(from: decoder) }
    func encode(to encoder: Encoder) throws {
        if let value { try value.encode(to: encoder) }
        else { var container = encoder.singleValueContainer(); try container.encodeNil() }
    }
}


struct DJConnectSessionMediaPrepareRequest: Encodable {
    let sessionID: String
    let targets: [[String: String]]
    let contractVersion = 1
    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id", targets, contractVersion = "contract_version"
    }
}
struct DJConnectSessionMediaPrepareResponse: Decodable {
    let success: Bool
    let contractVersion: Int
    let media: [DJConnectSessionMedia]
    enum CodingKeys: String, CodingKey { case success, contractVersion = "contract_version", media = "session_media" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decode(Bool.self, forKey: .success)
        contractVersion = try c.decode(Int.self, forKey: .contractVersion)
        media = (try c.decode([LossyBroadcastValue<DJConnectSessionMedia>].self, forKey: .media)).compactMap(\.value)
    }
}
