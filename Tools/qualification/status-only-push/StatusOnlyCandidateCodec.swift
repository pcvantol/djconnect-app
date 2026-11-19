// PRIVATE R6 PREPARATION ONLY. Not a shipping profile, grant or registration.
// Codable validates values; original lexical bytes need producer/B-HTTP preflight.
import Foundation

enum StatusOnlyCandidate {
    static let profileID = "remote-playback-status-v1"
    static let identitySHA256 = "090b8c9cd0d0b74622cd8ce00accaaecd816feb9d762f0554a9709bbf6342517"
    static let safeMaximum: Int64 = 9_007_199_254_740_991
    enum Phase: String, Codable, Hashable, Sendable { case active, ended }
    enum Playback: String, Codable, Hashable, CaseIterable, Sendable { case playing, paused, stopped, unknown }

    static func uuid(_ text: String) -> Bool {
        let bytes = Array(text.utf8)
        return bytes.count == 36 && bytes[14] == 52 && [56, 57, 97, 98].contains(bytes[19]) &&
            UUID(uuidString: text)?.uuidString.lowercased() == text
    }
    static func invalid() -> DecodingError {
        .dataCorrupted(.init(codingPath: [], debugDescription: "Invalid private status candidate shape"))
    }
    struct Key: CodingKey, Hashable {
        let stringValue: String
        var intValue: Int? { nil }
        init(_ value: String) { stringValue = value }
        init?(stringValue: String) { self.init(stringValue) }
        init?(intValue: Int) { return nil }
    }
    static func exact(_ decoder: any Decoder, _ keys: Set<String>) throws -> KeyedDecodingContainer<Key> {
        let c = try decoder.container(keyedBy: Key.self)
        guard Set(c.allKeys.map(\.stringValue)) == keys else { throw invalid() }
        return c // Does NOT recover duplicate members or original numeric lexemes.
    }
    static func validate(phase: Phase, playback: Playback?) throws {
        guard phase == .ended ? playback == nil : playback != nil else { throw invalid() }
    }
}

struct StatusOnlyActivityIdentity: Codable, Equatable, Hashable, Sendable {
    let presentation_id: String
    let presentation_generation: String
    init(from decoder: any Decoder) throws {
        let c = try StatusOnlyCandidate.exact(decoder, ["presentation_id", "presentation_generation"])
        presentation_id = try c.decode(String.self, forKey: .init("presentation_id"))
        presentation_generation = try c.decode(String.self, forKey: .init("presentation_generation"))
        guard StatusOnlyCandidate.uuid(presentation_id), StatusOnlyCandidate.uuid(presentation_generation) else {
            throw StatusOnlyCandidate.invalid()
        }
    }
}

struct StatusOnlyActivityState: Codable, Equatable, Hashable, Sendable {
    let contract_version: Int
    let presentation_id: String
    let presentation_generation: String
    let sequence: Int64
    let observed_at_unix_ms: Int64
    let display_mode: String
    let phase: StatusOnlyCandidate.Phase
    let playback_state: StatusOnlyCandidate.Playback?
    init(from decoder: any Decoder) throws {
        let c = try StatusOnlyCandidate.exact(decoder, ["contract_version", "presentation_id", "presentation_generation",
            "sequence", "observed_at_unix_ms", "display_mode", "phase", "playback_state"])
        contract_version = try c.decode(Int.self, forKey: .init("contract_version"))
        presentation_id = try c.decode(String.self, forKey: .init("presentation_id"))
        presentation_generation = try c.decode(String.self, forKey: .init("presentation_generation"))
        sequence = try c.decode(Int64.self, forKey: .init("sequence"))
        observed_at_unix_ms = try c.decode(Int64.self, forKey: .init("observed_at_unix_ms"))
        display_mode = try c.decode(String.self, forKey: .init("display_mode"))
        phase = try c.decode(StatusOnlyCandidate.Phase.self, forKey: .init("phase"))
        playback_state = try c.decodeIfPresent(StatusOnlyCandidate.Playback.self, forKey: .init("playback_state"))
        guard contract_version == 1, display_mode == "last_observed",
              StatusOnlyCandidate.uuid(presentation_id), StatusOnlyCandidate.uuid(presentation_generation),
              (1...StatusOnlyCandidate.safeMaximum).contains(sequence),
              (1...StatusOnlyCandidate.safeMaximum).contains(observed_at_unix_ms) else { throw StatusOnlyCandidate.invalid() }
        try StatusOnlyCandidate.validate(phase: phase, playback: playback_state)
    }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: StatusOnlyCandidate.Key.self)
        try c.encode(contract_version, forKey: .init("contract_version"))
        try c.encode(presentation_id, forKey: .init("presentation_id"))
        try c.encode(presentation_generation, forKey: .init("presentation_generation"))
        try c.encode(sequence, forKey: .init("sequence"))
        try c.encode(observed_at_unix_ms, forKey: .init("observed_at_unix_ms"))
        try c.encode(display_mode, forKey: .init("display_mode"))
        try c.encode(phase, forKey: .init("phase"))
        try c.encode(playback_state, forKey: .init("playback_state")) // Explicit null for ended.
    }
    func matchesIdentity(_ identity: StatusOnlyActivityIdentity) -> Bool {
        presentation_id == identity.presentation_id && presentation_generation == identity.presentation_generation
    } // Data identity only, never an ownership/consent/order check.
}

struct StatusOnlyWidgetResponse: Decodable, Equatable, Sendable {
    struct Observation: Decodable, Equatable, Sendable {
        let grant_epoch: String
        let target_generation: String
        let source_generation: String
        let observed_at_unix_ms: Int64
        let phase: StatusOnlyCandidate.Phase
        let playback_state: StatusOnlyCandidate.Playback?
        init(from decoder: any Decoder) throws {
            let c = try StatusOnlyCandidate.exact(decoder, ["grant_epoch", "target_generation", "source_generation",
                "observed_at_unix_ms", "phase", "playback_state"])
            grant_epoch = try c.decode(String.self, forKey: .init("grant_epoch"))
            target_generation = try c.decode(String.self, forKey: .init("target_generation"))
            source_generation = try c.decode(String.self, forKey: .init("source_generation"))
            observed_at_unix_ms = try c.decode(Int64.self, forKey: .init("observed_at_unix_ms"))
            phase = try c.decode(StatusOnlyCandidate.Phase.self, forKey: .init("phase"))
            playback_state = try c.decodeIfPresent(StatusOnlyCandidate.Playback.self, forKey: .init("playback_state"))
            guard [grant_epoch, target_generation, source_generation].allSatisfy(StatusOnlyCandidate.uuid),
                  (1...StatusOnlyCandidate.safeMaximum).contains(observed_at_unix_ms) else { throw StatusOnlyCandidate.invalid() }
            try StatusOnlyCandidate.validate(phase: phase, playback: playback_state)
        }
    }
    let contract_version: Int
    let request_id: String
    let available: Bool
    let observation: Observation?
    let cache_policy: String
    init(from decoder: any Decoder) throws {
        let c = try StatusOnlyCandidate.exact(decoder, ["contract_version", "request_id", "available", "observation", "cache_policy"])
        contract_version = try c.decode(Int.self, forKey: .init("contract_version"))
        request_id = try c.decode(String.self, forKey: .init("request_id"))
        available = try c.decode(Bool.self, forKey: .init("available"))
        observation = try c.decodeIfPresent(Observation.self, forKey: .init("observation"))
        cache_policy = try c.decode(String.self, forKey: .init("cache_policy"))
        guard contract_version == 1, StatusOnlyCandidate.uuid(request_id), cache_policy == "private,no-store",
              available == (observation != nil) else { throw StatusOnlyCandidate.invalid() }
    }
}

/// Display data only. A widget observation never fabricates Activity identities
/// or sequence numbers to reuse the renderer. No grant/currentness is implied.
struct StatusOnlyDisplayValue: Equatable, Sendable {
    let playback: StatusOnlyCandidate.Playback?
    let originalObservedMS: Int64
    init(activity: StatusOnlyActivityState) {
        playback = activity.playback_state; originalObservedMS = activity.observed_at_unix_ms
    }
    init(observation: StatusOnlyWidgetResponse.Observation) {
        playback = observation.playback_state; originalObservedMS = observation.observed_at_unix_ms
    }
}

#if os(iOS)
import ActivityKit
struct DJConnectRemotePlaybackStatusActivityAttributesV1: ActivityAttributes, Sendable {
    typealias ContentState = StatusOnlyActivityState
    let presentation_id: String
    let presentation_generation: String
    init(from decoder: any Decoder) throws {
        let identity = try StatusOnlyActivityIdentity(from: decoder)
        presentation_id = identity.presentation_id
        presentation_generation = identity.presentation_generation
    }
}
#endif
