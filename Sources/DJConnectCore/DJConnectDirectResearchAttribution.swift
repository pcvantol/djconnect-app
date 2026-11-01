import Foundation

/// Local presentation metadata for the explicitly selected direct-local-v2
/// codec. This is not source permission and is always inside the rich budget.
public struct DJConnectDirectResearchAttribution: Codable, Equatable, Hashable, Sendable {
    public struct Source: Codable, Equatable, Hashable, Sendable {
        public let provider: String; public let title: String; public let url: String; public let kind: String
        public let language: String; public let fetched_at: String; public let expires_at: String
        public let license: String; public let revision_url: String; public let wikidata_id: String
        public let content_hash: String; public let claim_scope: String
    }
    public struct ExpressionLicense: Codable, Equatable, Hashable, Sendable {
        public let id: String; public let url: String; public let adapted: Bool; public let attribution_required: Bool
    }
    public let momentID: String
    public let sources: [Source]
    public let expressionLicense: ExpressionLicense

    public func matches(_ contribution: DJConnectPassiveSession.Contribution) -> Bool {
        guard contribution.usage_basis == "public_artist_narration_v1", momentID == contribution.moment_id,
              (1...3).contains(sources.count), expressionLicense.id == "CC-BY-SA-4.0",
              expressionLicense.url == "https://creativecommons.org/licenses/by-sa/4.0/",
              expressionLicense.adapted, expressionLicense.attribution_required else { return false }
        for source in sources {
            guard source.kind == "source", source.claim_scope == "fetched_public_music_reference",
                  ["en", "nl", "de", "fr", "es"].contains(source.language),
                  DirectRichRequest.matches(source.content_hash, "[a-f0-9]{64}"),
                  [source.provider, source.title, source.license, source.wikidata_id].allSatisfy({ $0.utf8.count <= 2048 }),
                  Self.url(source.url), source.revision_url.isEmpty || Self.url(source.revision_url),
                  source.provider != "Wikipedia" || !source.revision_url.isEmpty,
                  (try? DirectRichWireInstant(source.fetched_at)) != nil,
                  (try? DirectRichWireInstant(source.expires_at)) != nil else { return false }
        }
        return true
    }
    private static func url(_ text: String) -> Bool {
        guard text.utf8.count <= 2048, let value = URLComponents(string: text) else { return false }
        return value.scheme == "https" && value.host?.isEmpty == false && value.user == nil && value.password == nil
    }
}
