import Foundation
import Testing
@testable import DJConnectCore

private func artworkExample(_ name: String) throws -> [String: Any] {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: root.appendingPathComponent("Fixtures/session-artwork-core-5c7ecb79.json"))
    let fixture = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let examples = try #require(fixture["examples"] as? [String: [String: Any]])
    return try #require(examples[name]?["projection"] as? [String: Any])
}

private func decodeArtwork(_ object: [String: Any]) throws -> DJConnectSessionMedia {
    try JSONDecoder().decode(DJConnectSessionMedia.self, from: JSONSerialization.data(withJSONObject: object))
}

private func artworkDate(_ media: DJConnectSessionMedia) throws -> Date {
    try #require(media.artwork.capturedAt.flatMap(DJConnectHistoryEntry.date)).addingTimeInterval(1)
}

@Test func sessionMediaDecodesActualPinnedCorePositiveProjections() throws {
    for name in ["playback_cover", "album_story", "artist_story", "late_artist_after_track_change", "older_entry_refresh"] {
        let media = try decodeArtwork(artworkExample(name))
        let target = try #require(media.target)
        let audience: DJConnectSessionMedia.Audience = media.artwork.historicalDisplayAllowed ? .history : .activeFlow
        let admitted = media.admittedArtwork(session: media.sessionID, target: target, audience: audience, at: try artworkDate(media))
        #expect(admitted != nil, "Actual Core example must remain admitted: \(name)")
        #expect(admitted?.altText?.keys.count == 5)
    }
    let loading = try decodeArtwork(artworkExample("loading"))
    #expect(loading.artwork.state == .loading)
    #expect(loading.admittedArtwork(session: loading.sessionID, target: try #require(loading.target), audience: .activeFlow) == nil)
}

@Test func sessionMediaKeepsTargetAndAudienceIndependentFromCurrentPlayback() throws {
    let media = try decodeArtwork(artworkExample("artist_story"))
    let target = try #require(media.target)
    let now = try artworkDate(media)
    #expect(media.artwork.subject?.uri == "spotify:artist:CCCCCCCCCCCCCCCCCCCCCC")
    #expect(media.admittedArtwork(session: media.sessionID, target: target, audience: .activeFlow, at: now) != nil)
    #expect(media.admittedArtwork(session: media.sessionID, target: target, audience: .current, at: now) == nil)
    #expect(media.admittedArtwork(session: media.sessionID, target: target, audience: .history, at: now) == nil)
    #expect(media.admittedArtwork(session: "another-session", target: target, audience: .activeFlow, at: now) == nil)
    #expect(media.admittedArtwork(session: media.sessionID, target: .moment("another-moment"), audience: .activeFlow, at: now) == nil)
}

@Test func sessionMediaOriginalExpiryDoesNotSlideOnRepeatedReads() throws {
    let media = try decodeArtwork(artworkExample("playback_cover"))
    let expiry = try #require(media.artwork.expiresAt.flatMap(DJConnectHistoryEntry.date))
    let target = try #require(media.target)
    #expect(media.admittedArtwork(session: media.sessionID, target: target, audience: .activeFlow, at: expiry.addingTimeInterval(-0.001)) != nil)
    for now in [expiry, expiry.addingTimeInterval(1), expiry.addingTimeInterval(300)] {
        #expect(media.admittedArtwork(session: media.sessionID, target: target, audience: .activeFlow, at: now) == nil)
    }
}

@Test func sessionMediaRejectsUnmanagedURLsIncompleteProvenanceAndInvalidGeometry() throws {
    let cases: [(String, Any)] = [
        ("url", "https://i.scdn.co/image/abcdef"), ("url", "//evil.invalid/image"),
        ("url", "/api/djconnect/v1/session/media/image/another-session/asset"),
        ("url", "/api/djconnect/v1/session/media/image/session-fixture-1/../asset"),
        ("url", "/api/djconnect/v1/session/media/image/session-fixture-1/%2e%2e"),
        ("url", "/api/djconnect/v1/session/media/image/session-fixture-1/asset?token=x"),
        ("crop_allowed", true), ("requires_device_auth", false), ("cache_policy", "public"),
        ("source_url", "https://open.spotify.com/track/ZZZZZZZZZZZZZZZZZZZZZZ"),
        ("width", 4097), ("height", 0), ("resolution_basis", "observed"),
        ("edition_basis", "not_applicable"), ("usage_basis", "unrestricted"),
        ("media_revision", ""), ("alt_text", ["nl": "Hoes"])
    ]
    for (field, value) in cases {
        var object = try artworkExample("playback_cover")
        var art = try #require(object["artwork"] as? [String: Any]); art[field] = value; object["artwork"] = art
        let media = try decodeArtwork(object)
        #expect(media.admittedArtwork(session: media.sessionID, target: try #require(media.target), audience: .activeFlow, at: try artworkDate(media)) == nil,
                "Unsafe optional field must fail closed: \(field)")
    }
}

@Test func sessionMediaSixStatesAndFutureSchemaRemainTextOnlyWhenNotReady() throws {
    for state in ["loading", "missing", "expired", "withdrawn", "unavailable"] {
        var object = try artworkExample("playback_cover")
        var art = try #require(object["artwork"] as? [String: Any]); art["state"] = state; object["artwork"] = art
        let media = try decodeArtwork(object)
        #expect(media.admittedArtwork(session: media.sessionID, target: try #require(media.target), audience: .activeFlow, at: try artworkDate(media)) == nil)
    }
    var object = try artworkExample("playback_cover"); object["schema_version"] = 2
    let media = try decodeArtwork(object)
    #expect(media.admittedArtwork(session: media.sessionID, target: try #require(media.target), audience: .activeFlow, at: try artworkDate(media)) == nil)
}
