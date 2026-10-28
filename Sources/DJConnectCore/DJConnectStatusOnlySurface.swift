// Inactive status-only DATA/component types, Core af201 / profile090b8c9c.
// No registration, presentation producer or native admission is installed.
// Network callers MUST use decodeOriginalWire before materializing parsed DATA.
// ActivityKit supplies a Decoder without original APS bytes: its value decoder
// cannot establish lexical validity, ordering, original authority or delivery.
import Foundation

public enum DJConnectStatusOnlyProfile {
    public static let profileID = "remote-playback-status-v1"
    public static let identitySHA256 = "090b8c9cd0d0b74622cd8ce00accaaecd816feb9d762f0554a9709bbf6342517"
    static let safeMaximum: Int64 = 9_007_199_254_740_991
    public enum Phase: String, Codable, Hashable, Sendable { case active, ended }
    public enum Playback: String, Codable, Hashable, CaseIterable, Sendable { case playing, paused, stopped, unknown }

    static func uuid(_ text: String) -> Bool {
        guard text.utf8.count == 36 else { return false }
        let bytes = Array(text.utf8)
        return bytes[14] == 52 && [56, 57, 97, 98].contains(bytes[19]) &&
            UUID(uuidString: text)?.uuidString.lowercased() == text
    }
    static func invalid() -> DecodingError {
        .dataCorrupted(.init(codingPath: [], debugDescription: "Invalid private status candidate shape"))
    }
    struct Key: CodingKey, Hashable {
        public let stringValue: String
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

public struct DJConnectStatusActivityIdentity: Codable, Equatable, Hashable, Sendable {
    /// Original producer/B-network bytes only. Parsed dictionaries cannot be supplied.
    /// Shape validity is DATA, never registration, signature or native authority.
    public static func decodeOriginalWire(_ bytes: Data) throws -> Self {
        guard !bytes.isEmpty, bytes.count <= 4096 else { throw DJConnectError.invalidResponse }
        try DJConnectSurfacePushJSON.validate(bytes)
        return try JSONDecoder().decode(Self.self, from: bytes)
    }
    public let presentation_id: String
    public let presentation_generation: String
    public init(from decoder: any Decoder) throws {
        let c = try DJConnectStatusOnlyProfile.exact(decoder, ["presentation_id", "presentation_generation"])
        presentation_id = try c.decode(String.self, forKey: .init("presentation_id"))
        presentation_generation = try c.decode(String.self, forKey: .init("presentation_generation"))
        guard DJConnectStatusOnlyProfile.uuid(presentation_id), DJConnectStatusOnlyProfile.uuid(presentation_generation) else {
            throw DJConnectStatusOnlyProfile.invalid()
        }
    }
}

public struct DJConnectStatusActivityState: Codable, Equatable, Hashable, Sendable {
    /// Original producer/B-network bytes only. Parsed dictionaries cannot be supplied.
    /// Shape validity is DATA, never registration, signature or native authority.
    public static func decodeOriginalWire(_ bytes: Data) throws -> Self {
        guard !bytes.isEmpty, bytes.count <= 4096 else { throw DJConnectError.invalidResponse }
        try DJConnectSurfacePushJSON.validate(bytes)
        return try JSONDecoder().decode(Self.self, from: bytes)
    }
    public let contract_version: Int
    public let presentation_id: String
    public let presentation_generation: String
    public let sequence: Int64
    public let observed_at_unix_ms: Int64
    public let display_mode: String
    public let phase: DJConnectStatusOnlyProfile.Phase
    public let playback_state: DJConnectStatusOnlyProfile.Playback?
    public init(from decoder: any Decoder) throws {
        let c = try DJConnectStatusOnlyProfile.exact(decoder, ["contract_version", "presentation_id", "presentation_generation",
            "sequence", "observed_at_unix_ms", "display_mode", "phase", "playback_state"])
        contract_version = try c.decode(Int.self, forKey: .init("contract_version"))
        presentation_id = try c.decode(String.self, forKey: .init("presentation_id"))
        presentation_generation = try c.decode(String.self, forKey: .init("presentation_generation"))
        sequence = try c.decode(Int64.self, forKey: .init("sequence"))
        observed_at_unix_ms = try c.decode(Int64.self, forKey: .init("observed_at_unix_ms"))
        display_mode = try c.decode(String.self, forKey: .init("display_mode"))
        phase = try c.decode(DJConnectStatusOnlyProfile.Phase.self, forKey: .init("phase"))
        playback_state = try c.decodeIfPresent(DJConnectStatusOnlyProfile.Playback.self, forKey: .init("playback_state"))
        guard contract_version == 1, display_mode == "last_observed",
              DJConnectStatusOnlyProfile.uuid(presentation_id), DJConnectStatusOnlyProfile.uuid(presentation_generation),
              (1...DJConnectStatusOnlyProfile.safeMaximum).contains(sequence),
              (1...DJConnectStatusOnlyProfile.safeMaximum).contains(observed_at_unix_ms) else { throw DJConnectStatusOnlyProfile.invalid() }
        try DJConnectStatusOnlyProfile.validate(phase: phase, playback: playback_state)
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: DJConnectStatusOnlyProfile.Key.self)
        try c.encode(contract_version, forKey: .init("contract_version"))
        try c.encode(presentation_id, forKey: .init("presentation_id"))
        try c.encode(presentation_generation, forKey: .init("presentation_generation"))
        try c.encode(sequence, forKey: .init("sequence"))
        try c.encode(observed_at_unix_ms, forKey: .init("observed_at_unix_ms"))
        try c.encode(display_mode, forKey: .init("display_mode"))
        try c.encode(phase, forKey: .init("phase"))
        try c.encode(playback_state, forKey: .init("playback_state")) // Explicit null for ended.
    }
    public func matchesIdentity(_ identity: DJConnectStatusActivityIdentity) -> Bool {
        matchesPresentation(identity.presentation_id, generation: identity.presentation_generation)
    } // Data identity only, never an ownership/consent/order check.
    public func matchesPresentation(_ id: String, generation: String) -> Bool {
        presentation_id == id && presentation_generation == generation
    }
}

public struct DJConnectStatusWidgetResponse: Decodable, Equatable, Sendable {
    /// Original producer/B-network bytes only. Parsed dictionaries cannot be supplied.
    /// Shape validity is DATA, never registration, signature or native authority.
    public static func decodeOriginalWire(_ bytes: Data) throws -> Self {
        guard !bytes.isEmpty, bytes.count <= 8192 else { throw DJConnectError.invalidResponse }
        try DJConnectSurfacePushJSON.validate(bytes)
        return try JSONDecoder().decode(Self.self, from: bytes)
    }
    public struct Observation: Decodable, Equatable, Sendable {
        public let grant_epoch: String
        public let target_generation: String
        public let source_generation: String
        public let observed_at_unix_ms: Int64
        public let phase: DJConnectStatusOnlyProfile.Phase
        public let playback_state: DJConnectStatusOnlyProfile.Playback?
        public init(from decoder: any Decoder) throws {
            let c = try DJConnectStatusOnlyProfile.exact(decoder, ["grant_epoch", "target_generation", "source_generation",
                "observed_at_unix_ms", "phase", "playback_state"])
            grant_epoch = try c.decode(String.self, forKey: .init("grant_epoch"))
            target_generation = try c.decode(String.self, forKey: .init("target_generation"))
            source_generation = try c.decode(String.self, forKey: .init("source_generation"))
            observed_at_unix_ms = try c.decode(Int64.self, forKey: .init("observed_at_unix_ms"))
            phase = try c.decode(DJConnectStatusOnlyProfile.Phase.self, forKey: .init("phase"))
            playback_state = try c.decodeIfPresent(DJConnectStatusOnlyProfile.Playback.self, forKey: .init("playback_state"))
            guard [grant_epoch, target_generation, source_generation].allSatisfy(DJConnectStatusOnlyProfile.uuid),
                  (1...DJConnectStatusOnlyProfile.safeMaximum).contains(observed_at_unix_ms) else { throw DJConnectStatusOnlyProfile.invalid() }
            try DJConnectStatusOnlyProfile.validate(phase: phase, playback: playback_state)
        }
    }
    public let contract_version: Int
    public let request_id: String
    public let available: Bool
    public let observation: Observation?
    public let cache_policy: String
    public init(from decoder: any Decoder) throws {
        let c = try DJConnectStatusOnlyProfile.exact(decoder, ["contract_version", "request_id", "available", "observation", "cache_policy"])
        contract_version = try c.decode(Int.self, forKey: .init("contract_version"))
        request_id = try c.decode(String.self, forKey: .init("request_id"))
        available = try c.decode(Bool.self, forKey: .init("available"))
        observation = try c.decodeIfPresent(Observation.self, forKey: .init("observation"))
        cache_policy = try c.decode(String.self, forKey: .init("cache_policy"))
        guard contract_version == 1, DJConnectStatusOnlyProfile.uuid(request_id), cache_policy == "private,no-store",
              available == (observation != nil) else { throw DJConnectStatusOnlyProfile.invalid() }
    }
}

/// Display data only. A widget observation never fabricates Activity identities
/// or sequence numbers to reuse the renderer. No grant/currentness is implied.
public struct DJConnectStatusDisplayValue: Equatable, Sendable {
    public let playback: DJConnectStatusOnlyProfile.Playback?
    public let originalObservedMS: Int64
    public init(activity: DJConnectStatusActivityState) {
        playback = activity.playback_state; originalObservedMS = activity.observed_at_unix_ms
    }
    public init(observation: DJConnectStatusWidgetResponse.Observation) {
        playback = observation.playback_state; originalObservedMS = observation.observed_at_unix_ms
    }
}

#if os(iOS)
import ActivityKit
public struct DJConnectRemotePlaybackStatusActivityAttributesV1: ActivityAttributes, Sendable {
    public typealias ContentState = DJConnectStatusActivityState
    public let presentation_id: String
    public let presentation_generation: String
    public init(from decoder: any Decoder) throws {
        let identity = try DJConnectStatusActivityIdentity(from: decoder)
        presentation_id = identity.presentation_id
        presentation_generation = identity.presentation_generation
    }
}
#endif
