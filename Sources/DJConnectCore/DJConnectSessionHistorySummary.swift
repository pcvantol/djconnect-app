import Foundation

/// Private owner projection only. Never derive these values from loaded timeline rows.
public struct DJConnectSessionHistorySummary: Codable, Equatable, Sendable {
    public struct Metric<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
        public let value: Value?
        public let basis: String
        public let coverage: String
        public let state: String
        fileprivate let revision: SummaryRevision
        public let asOf: String
        public let observationScope: String?
        enum CodingKeys: String, CodingKey {
            case value, basis, coverage, state, revision
            case asOf = "as_of", observationScope = "observation_scope"
        }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            guard c.contains(.value) else {
                throw DecodingError.keyNotFound(CodingKeys.value, .init(codingPath: decoder.codingPath, debugDescription: "Missing summary value"))
            }
            value = try c.decodeIfPresent(Value.self, forKey: .value)
            basis = try c.decode(String.self, forKey: .basis)
            coverage = try c.decode(String.self, forKey: .coverage)
            state = try c.decode(String.self, forKey: .state)
            revision = try c.decode(SummaryRevision.self, forKey: .revision)
            asOf = try c.decode(String.self, forKey: .asOf)
            observationScope = try c.decodeIfPresent(String.self, forKey: .observationScope)
        }
        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(value, forKey: .value)
            try c.encode(basis, forKey: .basis); try c.encode(coverage, forKey: .coverage)
            try c.encode(state, forKey: .state); try c.encode(revision, forKey: .revision)
            try c.encode(asOf, forKey: .asOf); try c.encodeIfPresent(observationScope, forKey: .observationScope)
        }
        fileprivate func coherent(with summary: DJConnectSessionHistorySummary, basis expected: String) -> Bool {
            basis == expected && revision == summary.sessionRevision && asOf == summary.asOf && state == summary.state
                && ["complete", "partial", "unknown", "withdrawn"].contains(coverage)
                && (["unknown", "withdrawn"].contains(coverage) ? value == nil : true)
        }
    }
    public let schemaVersion: String
    fileprivate let sessionRevision: SummaryRevision
    public let asOf: String
    public let state: String
    public let tracksObserved: Metric<Int>
    public let momentsPublished: Metric<Int>
    public let momentsRetained: Metric<Int>?
    public let mood: Metric<String>
    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version", sessionRevision = "session_revision", asOf = "as_of", state
        case tracksObserved = "tracks_observed", momentsPublished = "moments_published"
        case momentsRetained = "moments_retained", mood
    }
    func encodeHeaderRevision(to encoder: Encoder) throws { try sessionRevision.encode(to: encoder) }
    func isCoherent(headerRevision: Decoder, readOnly: Bool) -> Bool {
        guard schemaVersion == "djconnect-session-history-summary/1",
              sessionRevision == (try? SummaryRevision(from: headerRevision)),
              DJConnectHistoryEntry.date(asOf) != nil,
              state == (readOnly ? "final" : "provisional"),
              tracksObserved.coherent(with: self, basis: "accepted_playback_observed_entries"),
              tracksObserved.observationScope == "stage_1_media_identity_changes_not_occurrences",
              momentsPublished.coherent(with: self, basis: "semantic_publication_commit"),
              mood.coherent(with: self, basis: "confirmed_symbolic_mood_elapsed_intervals") else { return false }
        let counts = [tracksObserved, momentsPublished] + (momentsRetained.map { [$0] } ?? [])
        guard counts.allSatisfy({ metric in
            if ["complete", "partial"].contains(metric.coverage) { return metric.value.map { $0 >= 0 } == true }
            return metric.value == nil
        }) else { return false }
        if let retained = momentsRetained,
           !retained.coherent(with: self, basis: "retained_readable_entries") { return false }
        if let value = mood.value {
            return mood.coverage == "complete" && ["chill", "groove", "energy", "party", "mixed"].contains(value)
        }
        return mood.coverage != "complete"
    }
}

/// Preserve scalar type: an opaque string token is never an integer revision.
fileprivate enum SummaryRevision: Codable, Equatable, Sendable {
    case integer(Int), opaque(String)
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let text = try? c.decode(String.self) { self = .opaque(text) }
        else { self = .integer(try c.decode(Int.self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .integer(let value): try c.encode(value); case .opaque(let value): try c.encode(value) }
    }
}
