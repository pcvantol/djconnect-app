import Foundation
import CryptoKit

/// Distinct v2 background read. It never changes the foreground v1 grant or
/// imports an app bearer. These wire fields are not independent owner authority.
public struct DJConnectBackgroundSession: Codable, Sendable {
    public struct Status: Codable, Sendable {
        public let state: String
        public let reason: String
        var isValid: Bool {
            ["available", "unavailable", "suppressed", "stale", "withdrawn"].contains(state) &&
            !reason.isEmpty && reason.utf8.count <= 128 &&
            reason.range(of: "^[a-z_]+$", options: .regularExpression) != nil
        }
    }
    public struct Rights: Codable, Sendable {
        public let passive_cache: Bool
        public let os_snapshot: Bool
        public let external_relay: Bool
        public let watch_replication: Bool
        var isValid: Bool { passive_cache && os_snapshot && !external_relay && !watch_replication }
    }
    public struct ExpressionLicense: Codable, Sendable {
        public let id: String
        public let url: String
        public let adapted: Bool
        public let attribution_required: Bool
    }
    public struct Contribution: Codable, Sendable {
        public let rights: Rights
        public let sources: [[String: String]]?
        public let expression_license: ExpressionLicense?
        func validates(_ content: DJConnectPassiveSession.Contribution) -> Bool {
            guard rights.isValid else { return false }
            if content.usage_basis != "public_artist_narration_v1" {
                return sources == nil && expression_license == nil
            }
            guard let sources, (1...3).contains(sources.count), let license = expression_license,
                  license.id == "CC-BY-SA-4.0", license.url == "https://creativecommons.org/licenses/by-sa/4.0/",
                  license.adapted, license.attribution_required,
                  sources.contains(where: { $0["provider"] == "Wikipedia" }) else { return false }
            return sources.allSatisfy { source in
                guard let provider = source["provider"], let license = source["license"],
                      let address = source["url"], let url = URLComponents(string: address),
                      url.scheme == "https", url.user == nil, url.password == nil,
                      let title = source["title"], !title.isEmpty, title.unicodeScalars.count <= 1024,
                      source["kind"] == "source", source["claim_scope"] == "fetched_public_music_reference",
                      let hash = source["content_hash"], hash.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
                else { return false }
                switch provider {
                case "Wikipedia":
                    guard license == "CC-BY-SA-4.0", let revision = source["revision_url"],
                          let revisionURL = URLComponents(string: revision) else { return false }
                    return ["en.wikipedia.org", "nl.wikipedia.org", "de.wikipedia.org", "fr.wikipedia.org", "es.wikipedia.org"].contains(url.host ?? "") &&
                        url.path.hasPrefix("/wiki/") && revisionURL.scheme == "https" && revisionURL.host == url.host &&
                        revisionURL.user == nil && revisionURL.password == nil && revisionURL.path == "/w/index.php" &&
                        revisionURL.queryItems?.contains(where: { $0.name == "oldid" && $0.value?.range(of: "^[1-9][0-9]*$", options: .regularExpression) != nil }) == true
                case "MusicBrainz": return license == "CC0-1.0" && url.host == "musicbrainz.org"
                case "Wikidata": return license == "CC0-1.0" && url.host == "www.wikidata.org"
                default: return false
                }
            }
        }
    }
    public let fields: DJConnectPassiveSession
    public let contribution_status: Status
    public let now_playing_status: Status
    public let artwork_status: Status
    public let contribution: Contribution?
    enum CodingKeys: String, CodingKey { case contribution_status, now_playing_status, artwork_status, contribution }
    public init(from decoder: Decoder) throws {
        fields = try DJConnectPassiveSession(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contribution_status = try container.decode(Status.self, forKey: .contribution_status)
        now_playing_status = try container.decode(Status.self, forKey: .now_playing_status)
        artwork_status = try container.decode(Status.self, forKey: .artwork_status)
        contribution = try container.decodeIfPresent(Contribution.self, forKey: .contribution)
    }
    public func encode(to encoder: Encoder) throws {
        try fields.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contribution_status, forKey: .contribution_status)
        try container.encode(now_playing_status, forKey: .now_playing_status)
        try container.encode(artwork_status, forKey: .artwork_status)
        // Preserve the complete original contribution and additive v2 rights.
        if let contribution, let original = fields.contribution {
            let nested = container.superEncoder(forKey: .contribution)
            try original.encode(to: nested)
            try contribution.encode(to: nested)
        }
    }
    // Shape/rights validation is distinct from current display eligibility. An
    // expired projection cannot display, but does not revoke its longer-lived
    // original registration or prevent a later push from reading fresh content.
    var hasValidFields: Bool {
        guard fields.schema_version == 2, fields.surface == .widget,
              fields.hasValidFields(allowPublicResearch: true), Int64(fields.delivery_sequence) <= 9_007_199_254_740_991,
              Int64(fields.mood.revision) <= 9_007_199_254_740_991, fields.artwork.isEmpty,
              contribution_status.isValid, now_playing_status.isValid, artwork_status.isValid,
              (fields.contribution == nil) == (contribution_status.state != "available"),
              (fields.now_playing == nil) == (now_playing_status.state != "available"),
              let observed = DJConnectHistoryEntry.date(fields.observed_at),
              let readAt = DJConnectHistoryEntry.date(fields.as_of), observed <= readAt else { return false }
        if let content = fields.contribution {
            guard contribution_status.reason == "qualified", contribution?.validates(content) == true else { return false }
        } else if contribution != nil { return false }
        return fields.now_playing == nil || now_playing_status.reason == "qualified"
    }
    public func isCurrent(at now: Date, originalGrantExpiry: Date) -> Bool {
        guard hasValidFields, fields.state == "active",
              let readAt = DJConnectHistoryEntry.date(fields.as_of),
              let expiry = DJConnectHistoryEntry.date(fields.expires_at),
              readAt <= now, now < min(expiry, originalGrantExpiry) else { return false }
        return (fields.contribution == nil || fields.contribution?.isCurrent(at: now) == true) &&
            (fields.now_playing == nil || fields.now_playing?.isCurrent(at: now) == true)
    }
    /// Read-clock changes cannot create a new semantic sequence or renew a pin.
    public var semanticDigest: Data? {
        guard let data = try? JSONEncoder().encode(self),
              var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        object.removeValue(forKey: "as_of")
        guard let canonical = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return nil }
        return Data(SHA256.hash(data: canonical))
    }
}

public struct DJConnectSurfacePushReadResponse: Decodable, Sendable {
    public let success: Bool
    public let contract_version: Int
    public let registration: DJConnectSurfacePushReceipt
    public let passive_session: DJConnectBackgroundSession
    public let cache_policy: String
}
