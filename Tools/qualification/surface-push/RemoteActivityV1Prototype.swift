// Joint-review prototype ONLY. Excluded from shipping project/package targets.
// No Activity.request, registration, API profile or consent factory is provided.
import Foundation
#if os(iOS)
import ActivityKit
#endif

struct DJConnectRemoteSessionActivityStateV1: Codable, Equatable, Hashable, Sendable {
    struct Playback: Codable, Equatable, Hashable, Sendable {
        let track: String
        let artist: String
        let album: String
        let playback_state: String
        let source_label: String
        init(from decoder: any Decoder) throws {
            let c = try exact(decoder, ["track", "artist", "album", "playback_state", "source_label"])
            track = try c.decode(String.self, forKey: K("track"))
            artist = try c.decode(String.self, forKey: K("artist"))
            album = try c.decode(String.self, forKey: K("album"))
            playback_state = try c.decode(String.self, forKey: K("playback_state"))
            source_label = try c.decode(String.self, forKey: K("source_label"))
            guard bounded(track, 256), bounded(artist, 256), bounded(album, 256, empty: true),
                  bounded(source_label, 128), ["playing", "paused"].contains(playback_state) else { throw invalid() }
        }
    }
    let contract_version: Int
    let presentation_id: String
    let presentation_generation: String
    let sequence: Int64
    let observed_at_unix_ms: Int64
    let expires_at_unix_ms: Int64
    let phase: String
    let theme: String?
    let playback: Playback?

    init(from decoder: any Decoder) throws {
        let c = try exact(decoder, ["contract_version", "presentation_id", "presentation_generation", "sequence",
            "observed_at_unix_ms", "expires_at_unix_ms", "phase", "theme", "playback"])
        contract_version = try c.decode(Int.self, forKey: K("contract_version"))
        presentation_id = try c.decode(String.self, forKey: K("presentation_id"))
        presentation_generation = try c.decode(String.self, forKey: K("presentation_generation"))
        sequence = try c.decode(Int64.self, forKey: K("sequence"))
        observed_at_unix_ms = try c.decode(Int64.self, forKey: K("observed_at_unix_ms"))
        expires_at_unix_ms = try c.decode(Int64.self, forKey: K("expires_at_unix_ms"))
        phase = try c.decode(String.self, forKey: K("phase"))
        theme = try c.decodeIfPresent(String.self, forKey: K("theme"))
        playback = try c.decodeIfPresent(Playback.self, forKey: K("playback"))
        guard contract_version == 1, canonicalUUID(presentation_id), canonicalUUID(presentation_generation),
              (1...9_007_199_254_740_991).contains(sequence),
              (1...9_007_199_254_620_991).contains(observed_at_unix_ms),
              expires_at_unix_ms > observed_at_unix_ms,
              expires_at_unix_ms <= observed_at_unix_ms + 120_000,
              ["active", "ended"].contains(phase),
              theme.map({ ["brand", "chill", "groove", "energy", "party"].contains($0) }) ?? true,
              phase != "ended" || (playback == nil && theme == nil) else { throw invalid() }
    }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(contract_version, forKey: K("contract_version"))
        try c.encode(presentation_id, forKey: K("presentation_id"))
        try c.encode(presentation_generation, forKey: K("presentation_generation"))
        try c.encode(sequence, forKey: K("sequence"))
        try c.encode(observed_at_unix_ms, forKey: K("observed_at_unix_ms"))
        try c.encode(expires_at_unix_ms, forKey: K("expires_at_unix_ms"))
        try c.encode(phase, forKey: K("phase"))
        // Explicit nulls are part of this proposed new codec, unlike local v1.
        try c.encode(theme, forKey: K("theme"))
        try c.encode(playback, forKey: K("playback"))
    }
}

struct DJConnectRemoteSessionActivityIdentityV1: Codable, Equatable, Hashable, Sendable {
    let presentation_id: String
    let presentation_generation: String
    init(from decoder: any Decoder) throws {
        let c = try exact(decoder, ["presentation_id", "presentation_generation"])
        presentation_id = try c.decode(String.self, forKey: K("presentation_id"))
        presentation_generation = try c.decode(String.self, forKey: K("presentation_generation"))
        guard canonicalUUID(presentation_id), canonicalUUID(presentation_generation) else { throw invalid() }
    }
}

#if os(iOS)
struct DJConnectRemoteSessionActivityAttributesV1: ActivityAttributes, Sendable {
    typealias ContentState = DJConnectRemoteSessionActivityStateV1
    let presentation_id: String
    let presentation_generation: String
    init(from decoder: any Decoder) throws {
        let identity = try DJConnectRemoteSessionActivityIdentityV1(from: decoder)
        presentation_id = identity.presentation_id
        presentation_generation = identity.presentation_generation
    }
}
#endif

/// Pure display-data decision under an EXPLICIT test-model consent assumption.
/// This grants no lifetime/rights. A renderer cannot prove wall-clock accuracy,
/// cross-update ordering, APNs delivery, revocation or pixel erasure from a body.
enum RemoteActivityV1DisplayProbe {
    enum Projection: Equatable { case neutral, playback(DJConnectRemoteSessionActivityStateV1.Playback) }
    static func project(_ state: DJConnectRemoteSessionActivityStateV1,
                        identity: DJConnectRemoteSessionActivityIdentityV1,
                        isStale: Bool, nowUnixMS: Int64,
                        testModelAssumesOSDisplayConsent: Bool = false) -> Projection {
        guard testModelAssumesOSDisplayConsent, !isStale, state.phase == "active",
              state.presentation_id == identity.presentation_id,
              state.presentation_generation == identity.presentation_generation,
              nowUnixMS >= state.observed_at_unix_ms, nowUnixMS < state.expires_at_unix_ms,
              let playback = state.playback else { return .neutral }
        return .playback(playback)
    }
}

private struct K: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { return nil }
}
private func exact(_ decoder: any Decoder, _ keys: Set<String>) throws -> KeyedDecodingContainer<K> {
    let container = try decoder.container(keyedBy: K.self)
    guard Set(container.allKeys.map(\.stringValue)) == keys else { throw invalid() }
    return container
}
private func invalid() -> DecodingError { .dataCorrupted(.init(codingPath: [], debugDescription: "Closed remote Activity prototype rejected")) }
private func canonicalUUID(_ text: String) -> Bool { UUID(uuidString: text)?.uuidString.lowercased() == text }
private func bounded(_ text: String, _ bytes: Int, empty: Bool = false) -> Bool {
    (empty || !text.isEmpty) && text.utf8.count <= bytes && !text.unicodeScalars.contains { $0.value < 32 || $0.value == 127 }
}
