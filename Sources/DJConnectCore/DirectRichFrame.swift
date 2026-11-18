import Foundation

/// Original direct response data, preserving the complete rights/research
/// graph. Decoding this value never creates original clock/owner permission.
struct DirectRichFrame: Decodable, Sendable {
    struct Rights: Decodable, Sendable {
        let passive_cache: Bool; let os_snapshot: Bool
        let external_relay: Bool; let watch_replication: Bool
    }
    typealias ResearchSource = DJConnectDirectResearchAttribution.Source
    typealias ExpressionLicense = DJConnectDirectResearchAttribution.ExpressionLicense
    struct Contribution: Decodable, Sendable {
        let moment_id: String; let published_at: String; let text: String; let persona: String
        let source_attribution: [String: String]; let usage_basis: String; let expires_at: String
        let rights: Rights
        let sources: [ResearchSource]?
        let expression_license: ExpressionLicense?
    }
    struct Artwork: Decodable, Sendable {
        let slot: String; let asset_id: String
        let subject: DJConnectPassiveSession.Artwork.Subject
        let role: String; let media_revision: String
        let captured_at: String; let expires_at: String; let source_url: String
        let attribution: [String: String]; let alt_text: [String: String]
        let width: Int; let height: Int; let crop_allowed: Bool
        let usage_basis: String; let rights: Rights
        let bytes_sha256: String; let byte_length: Int; let mime_type: String
    }
    struct FieldStatus: Decodable, Sendable { let state: String; let reason: String }
    struct Mood: Decodable, Sendable { let value: String?; let revision: Int64 }
    let schema_version: Int
    let binding_id: String; let generation: String; let session_id: String
    let delivery_sequence: Int64; let frame_id: String; let state: String
    let observed_at_ms: Int64; let expires_at_ms: Int64; let playback_state: String
    let mood: Mood; let presence: String; let persona: String
    let contribution: Contribution?
    let now_playing: DJConnectPassiveSession.NowPlaying?
    let artwork: [Artwork]
    let contribution_status: FieldStatus; let now_playing_status: FieldStatus; let artwork_status: FieldStatus
}

/// Closed shape, byte and equality checks for the R8 direct profile. Original
/// native clock mapping, source admission and current SDK custody are separate.
enum DirectRichFrameShape {
    typealias Node = DirectRichWireJSON
    private static let personas = ["home_dj", "radio_dj", "club_dj", "festival_dj"]

    static func validate(_ node: Node, purpose: String, session: String, purposeExpiry: Int64) throws -> DirectRichFrame {
        let fields = try object(node, ["schema_version", "binding_id", "generation", "session_id", "delivery_sequence", "frame_id", "state", "observed_at_ms", "expires_at_ms", "playback_state", "mood", "presence", "persona", "contribution", "now_playing", "artwork", "contribution_status", "now_playing_status", "artwork_status"])
        guard fields["schema_version"] == .integer(1), fields["binding_id"] == .string(purpose),
              fields["session_id"] == .string(session), DirectRichRequest.isUUID(fields["generation"]?.string) else { throw invalid() }
        _ = try integer(fields["delivery_sequence"], minimum: 0)
        let observed = try integer(fields["observed_at_ms"], minimum: 0)
        let expires = try integer(fields["expires_at_ms"], minimum: 0)
        guard expires > observed, expires - observed <= 120000, expires <= purposeExpiry else { throw invalid() }
        try choice(fields["state"], ["active", "stale"])
        try choice(fields["playback_state"], ["playing", "paused", "stopped", "unknown"])
        try choice(fields["presence"], ["music_only", "occasional", "balanced", "presenter"])
        try choice(fields["persona"], personas)
        let mood = try object(fields["mood"], ["value", "revision"])
        if mood["value"] != .null { try choice(mood["value"], ["chill", "groove", "energy", "party"]) }
        _ = try integer(mood["revision"], minimum: 0)
        for key in ["contribution_status", "now_playing_status", "artwork_status"] { try status(fields[key]) }
        if fields["contribution"] != .null { try contribution(fields["contribution"]) }
        if fields["now_playing"] != .null { try nowPlaying(fields["now_playing"]) }
        for (field, start) in [("contribution", "published_at"), ("now_playing", "observed_at")] {
            if let value = fields[field]?.object { try originalInterval(value, start: start, frameExpiry: expires) }
        }
        guard let artwork = fields["artwork"]?.array, artwork.count <= 2 else { throw invalid() }
        var slots = Set<String>()
        for item in artwork {
            try cover(item)
            try originalInterval(item.object!, start: "captured_at", frameExpiry: expires)
            guard let slot = item.object?["slot"]?.string, slots.insert(slot).inserted else { throw invalid() }
        }
        let stale = fields["state"] == .string("stale")
        for (field, statusKey) in [("contribution", "contribution_status"), ("now_playing", "now_playing_status")] {
            let available = fields[statusKey]?.object?["state"] == .string("available")
            guard available == (fields[field] != .null) else { throw invalid() }
        }
        guard (fields["artwork_status"]?.object?["state"] == .string("available")) == !artwork.isEmpty else { throw invalid() }
        if fields["presence"] == .string("music_only"), fields["contribution"] != .null { throw invalid() }
        if stale {
            guard fields["contribution"] == .null, fields["now_playing"] == .null, artwork.isEmpty else { throw invalid() }
            for key in ["contribution_status", "now_playing_status", "artwork_status"] {
                guard fields[key]?.object?["state"] == .string("stale") else { throw invalid() }
            }
        }
        var hashFields = fields; hashFields.removeValue(forKey: "frame_id")
        guard fields["frame_id"] == .string(try Node.object(hashFields).digest()) else { throw invalid() }
        return try JSONDecoder().decode(DirectRichFrame.self, from: node.canonicalData())
    }

    private static func contribution(_ node: Node?) throws {
        guard let node, let usage = node.object?["usage_basis"]?.string else { throw invalid() }
        let research = usage == "public_artist_narration_v1"
        let keys: Set<String> = ["moment_id", "published_at", "text", "persona", "source_attribution", "usage_basis", "expires_at", "rights"]
        let fields = try object(node, research ? keys.union(["sources", "expression_license"]) : keys)
        try pattern(fields["moment_id"], "[A-Za-z0-9_-]{1,128}")
        try date(fields["published_at"]); try date(fields["expires_at"])
        try text(fields["text"], scalars: 640, bytes: 2560); try choice(fields["persona"], personas)
        try rights(fields["rights"])
        switch usage {
        case "runtime_authored_direction": _ = try object(fields["source_attribution"], [])
        case "cc0_facts_authored_expression", "public_artist_narration_v1":
            let attribution = try object(fields["source_attribution"], research ? ["provider", "url", "license", "revision_url"] : ["provider", "url", "license"])
            try text(attribution["provider"]); try text(attribution["license"])
            try url(attribution["url"])
            if research, attribution["revision_url"] != .string("") { try url(attribution["revision_url"]) }
        default: throw invalid()
        }
        if research {
            guard let sources = fields["sources"]?.array, (1...3).contains(sources.count) else { throw invalid() }
            for source in sources {
                let s = try object(source, ["provider", "title", "url", "kind", "language", "fetched_at", "expires_at", "license", "revision_url", "wikidata_id", "content_hash", "claim_scope"])
                for key in ["provider", "title", "license", "wikidata_id"] { try text(s[key], scalars: 2048, bytes: 2048) }
                try url(s["url"])
                if s["revision_url"] != .string("") { try url(s["revision_url"]) }
                if s["provider"] == .string("Wikipedia"), s["revision_url"] == .string("") { throw invalid() }
                try date(s["fetched_at"]); try date(s["expires_at"])
                try choice(s["language"], ["en", "nl", "de", "fr", "es"])
                try pattern(s["content_hash"], "[a-f0-9]{64}")
                guard s["kind"] == .string("source"), s["claim_scope"] == .string("fetched_public_music_reference") else { throw invalid() }
            }
            let license = try object(fields["expression_license"], ["id", "url", "adapted", "attribution_required"])
            guard license["id"] == .string("CC-BY-SA-4.0"), license["url"] == .string("https://creativecommons.org/licenses/by-sa/4.0/"),
                  license["adapted"] == .bool(true), license["attribution_required"] == .bool(true) else { throw invalid() }
        }
    }

    private static func nowPlaying(_ node: Node?) throws {
        let fields = try object(node, ["item_id", "subject_uri", "track", "artist", "album", "observed_at", "expires_at", "source_url", "attribution", "usage_basis"])
        try pattern(fields["item_id"], "[a-f0-9]{24}"); try pattern(fields["subject_uri"], "spotify:track:[A-Za-z0-9]{22}")
        for key in ["track", "artist", "album"] { try text(fields[key]) }
        try date(fields["observed_at"]); try date(fields["expires_at"])
        try url(fields["source_url"]); try spotifyAttribution(fields["attribution"])
        guard fields["usage_basis"] == .string("spotify_temporary_passive_metadata") else { throw invalid() }
    }

    private static func cover(_ node: Node) throws {
        let fields = try object(node, ["slot", "asset_id", "subject", "role", "media_revision", "captured_at", "expires_at", "source_url", "attribution", "alt_text", "width", "height", "crop_allowed", "usage_basis", "rights", "bytes_sha256", "byte_length", "mime_type"])
        try choice(fields["slot"], ["contribution", "now_playing"])
        try pattern(fields["asset_id"], "[A-Za-z0-9_-]{32}"); try pattern(fields["media_revision"], "[a-f0-9]{24}")
        let subject = try object(fields["subject"], ["provider", "uri", "type"], optional: ["album_uri"])
        guard subject["provider"] == .string("spotify"), let type = subject["type"]?.string, ["track", "album"].contains(type) else { throw invalid() }
        try pattern(subject["uri"], "spotify:\(type):[A-Za-z0-9]{22}")
        if let album = subject["album_uri"] { try pattern(album, "spotify:album:[A-Za-z0-9]{22}") }
        guard fields["role"] == .string(fields["slot"] == .string("contribution") ? "contextual_cover" : "current_cover") else { throw invalid() }
        try date(fields["captured_at"]); try date(fields["expires_at"])
        try url(fields["source_url"]); try spotifyAttribution(fields["attribution"])
        let alt = try object(fields["alt_text"], ["en", "nl", "de", "fr", "es"])
        for value in alt.values { try text(value) }
        let width = try integer(fields["width"], minimum: 1, maximum: 4096)
        let height = try integer(fields["height"], minimum: 1, maximum: 4096)
        guard width * height <= 16000000, fields["crop_allowed"] == .bool(false),
              fields["usage_basis"] == .string("spotify_temporary_passive_cover") else { throw invalid() }
        try rights(fields["rights"]); try pattern(fields["bytes_sha256"], "[a-f0-9]{64}")
        _ = try integer(fields["byte_length"], minimum: 1, maximum: 256000)
        try choice(fields["mime_type"], ["image/png", "image/jpeg"])
    }

    private static func status(_ node: Node?) throws {
        let fields = try object(node, ["state", "reason"])
        let reasons: [String]
        switch fields["state"]?.string {
        case "available": reasons = ["qualified"]
        case "suppressed": reasons = ["presence_music_only", "intentional_silence"]
        case "stale": reasons = ["original_snapshot_expired"]
        case "unavailable": reasons = ["source_not_qualified", "original_deadline_expired", "copy_too_long", "representation_not_supported", "no_publication", "no_observation", "subject_changed", "playback_inactive", "no_eligible_context", "not_prepared", "no_matching_subject", "asset_not_supported"]
        default: throw invalid()
        }
        try choice(fields["reason"], reasons)
    }
    private static func rights(_ node: Node?) throws {
        let r = try object(node, ["passive_cache", "os_snapshot", "external_relay", "watch_replication"])
        guard r["passive_cache"] == .bool(true), r["os_snapshot"] == .bool(true),
              r["external_relay"] == .bool(false), r["watch_replication"] == .bool(false) else { throw invalid() }
    }
    private static func spotifyAttribution(_ node: Node?) throws {
        let a = try object(node, ["provider", "mark", "url"])
        guard a["provider"] == .string("Spotify"), a["mark"] == .string("spotify") else { throw invalid() }
        try url(a["url"])
    }
    static func object(_ node: Node?, _ required: Set<String>, optional: Set<String> = []) throws -> [String: Node] {
        guard let fields = node?.object, required.isSubset(of: Set(fields.keys)), Set(fields.keys).isSubset(of: required.union(optional)) else { throw invalid() }
        return fields
    }
    static func integer(_ node: Node?, minimum: Int64, maximum: Int64 = 9007199254740991) throws -> Int64 {
        guard let number = node?.integer, (minimum...maximum).contains(number) else { throw invalid() }; return number
    }
    private static func text(_ node: Node?, scalars: Int = 512, bytes: Int = 512) throws {
        guard let string = node?.string, string.unicodeScalars.count <= scalars, string.utf8.count <= bytes else { throw invalid() }
    }
    private static func pattern(_ node: Node?, _ pattern: String) throws {
        guard DirectRichRequest.matches(node?.string, pattern) else { throw invalid() }
    }
    private static func choice(_ node: Node?, _ values: [String]) throws {
        guard let string = node?.string, values.contains(string) else { throw invalid() }
    }
    private static func date(_ node: Node?) throws {
        guard let string = node?.string else { throw invalid() }
        _ = try DirectRichWireInstant(string)
    }
    private static func originalInterval(_ fields: [String: Node], start: String, frameExpiry: Int64) throws {
        guard let first = fields[start]?.string, let last = fields["expires_at"]?.string else { throw invalid() }
        let a = try DirectRichWireInstant(first), b = try DirectRichWireInstant(last)
        guard a.intervalEndsWithin120Seconds(b), b.ceilMilliseconds <= frameExpiry,
              a.ceilMilliseconds < b.floorMilliseconds else { throw invalid() }
    }
    private static func url(_ node: Node?) throws {
        guard let string = node?.string, string.utf8.count <= 2048,
              let url = URLComponents(string: string), url.scheme == "https", url.host?.isEmpty == false,
              url.user == nil, url.password == nil else { throw invalid() }
    }
    private static func invalid() -> DJConnectError { .invalidResponse }
}
