import Foundation
import CryptoKit
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

private func currentInsightWire() throws -> [String: Any] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/current-insight-core-103dc6.json")
    let data = try Data(contentsOf: url)
    #expect(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() == "1cbc1ce62910e1218c8d1ad4caa71841b77611d75b6acbfeccb123f4b4e08e46")
    let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let responses = try #require(root["responses"] as? [String: Any])
    return try #require(responses["current"] as? [String: Any])
}

@Test func currentInsightActualProtectedSubjectDoesNotDecodeAsExplicitMoment() throws {
    let object = try currentInsightWire()
    let response = try JSONDecoder().decode(TrackInsightEndpointResponse.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(response.subject == nil)
    let proof = try #require(response.currentSubject)
    #expect(proof.mode == "current" && proof.schemaVersion == 1)
    let insight = try #require(response.trackInsightValue)
    #expect(insight.title == "Fixture track" && insight.artist == "Fixture artist")
    #expect(insight.energy == nil && insight.danceability == nil && insight.intensity == nil)
    #expect(insight.hasUnavailableAnalysis)
    let expiry = Date(timeIntervalSince1970: proof.expiresAt)
    let start = expiry.addingTimeInterval(-proof.expiresIn)
    #expect(proof.deadline(recording: proof.mediaIdentity, requestedAt: start, at: start.addingTimeInterval(1)) == expiry)
    #expect(proof.deadline(recording: proof.mediaIdentity, requestedAt: start, at: expiry) == nil)
    #expect(proof.deadline(recording: "spotify:track:BBBBBBBBBBBBBBBBBBBBBB", requestedAt: start, at: start) == nil)
}

@Test func currentInsightClosedSelectorCannotCarryLegacyAuthority() throws {
    var request = DJConnectTrackInsightRequest(locale: "nl")
    request.trackInsightSubject = .init()
    let wire = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
    #expect((wire["track_insight_subject"] as? [String: Any])?["mode"] as? String == "current")
    for forbidden in ["track", "title", "artist", "album", "entity_id", "player_id", "music_backend", "uri", "playback"] { #expect(wire[forbidden] == nil) }
    request.title = "same-name recording"
    #expect(throws: EncodingError.self) { try JSONEncoder().encode(request) }
    request.title = nil; request.progressMS = 0
    #expect(throws: EncodingError.self) { try JSONEncoder().encode(request) }
}

@Test func currentInsightOriginalProofAndMalformedVersionsFailClosed() throws {
    let object = try currentInsightWire()
    let original = try #require(object["subject"] as? [String: Any])
    for (key, value) in [("schema_version", 2 as Any), ("mode", "explicit" as Any), ("expires_in", 31 as Any),
                         ("observation_id", "" as Any), ("media_identity", "https://open.spotify.com/track/aaaaaaaaaaaaaaaaaaaaaa" as Any)] {
        var bad = original; bad[key] = value
        let subject = try JSONDecoder().decode(DJConnectCurrentInsightSubject.self, from: JSONSerialization.data(withJSONObject: bad))
        let start = Date(timeIntervalSince1970: subject.expiresAt - 10)
        #expect(subject.deadline(recording: subject.mediaIdentity, requestedAt: start, at: start) == nil)
    }
    let proof = try JSONDecoder().decode(DJConnectCurrentInsightSubject.self, from: JSONSerialization.data(withJSONObject: original))
    let expiry = Date(timeIntervalSince1970: proof.expiresAt)
    let before = expiry.addingTimeInterval(-1)
    // A newly read cached proof cannot slide the server's original deadline.
    #expect(proof.deadline(recording: proof.mediaIdentity, requestedAt: before, at: before) == expiry)
}

@Test func currentPlaybackExactURIIsAdditiveAndRoundTrips() throws {
    for key in ["uri", "current_uri"] {
        let object: [String: Any] = [key: "spotify:track:aaaaaaaaaaaaaaaaaaaaaa", "track_name": "Same name", "artist_name": "Same artist", "is_playing": true]
        let playback = try JSONDecoder().decode(DJConnectPlayback.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(playback.uri == "spotify:track:aaaaaaaaaaaaaaaaaaaaaa")
        #expect(try JSONDecoder().decode(DJConnectPlayback.self, from: JSONEncoder().encode(playback)) == playback)
    }
}

@Test func currentInsightLocalEpochRejectsSameNamedVersionsABAAndPauseSeekOutputChanges() {
    var fence = CurrentTrackInsightObservation()
    var a = DJConnectPlayback(uri: "spotify:track:aaaaaaaaaaaaaaaaaaaaaa", hasPlayback: true, isPlaying: true,
                              trackName: "Same", artistName: "Same", progressMS: 20_000)
    let initial = fence.observe(a); #expect(initial)
    let first = fence.generation
    a.progressMS = 21_000
    let progress = fence.observe(a); #expect(!progress && fence.generation == first)
    var b = a; b.uri = "spotify:track:bbbbbbbbbbbbbbbbbbbbbb"
    let changed = fence.observe(b), back = fence.observe(a)
    #expect(changed && back && fence.generation != first)
    let resumed = fence.generation
    a.isPlaying = false; let paused = fence.observe(a); #expect(paused)
    a.isPlaying = true; let playing = fence.observe(a); #expect(playing && fence.generation != resumed)
    a.progressMS = 10_000; let seek = fence.observe(a); #expect(seek)
    a.device = .init(id: "output-a", name: "Output A")
    let output = fence.observe(a); #expect(output)
    a.device?.volumePercent = 40; let volumeOnly = fence.observe(a); #expect(!volumeOnly)
    a.device?.source = "different-observed-source"; let source = fence.observe(a); #expect(source)
    let removed = fence.observe(nil); #expect(removed)
}

@Test func currentInsightCapabilitiesAreIndependentAndAcceptOriginalOlderEnvelope() throws {
    for (success, version, expected) in [(Optional<Bool>.none, 1, true), (Optional(true), 1, true), (Optional(false), 1, false), (Optional(true), 2, false)] {
        var wire: [String: Any] = ["capabilities": ["current_track_insight_subject_v1": true], "contract_versions": ["current_track_insight_subject": version]]
        if let success { wire["success"] = success }
        let caps = try JSONDecoder().decode(DJConnectCurrentInsightCapabilities.self, from: JSONSerialization.data(withJSONObject: wire))
        #expect(caps.available == expected)
    }
}
