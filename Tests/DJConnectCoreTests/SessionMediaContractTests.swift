import Foundation
import CoreGraphics
import ImageIO
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

@Suite(.serialized) struct SessionMediaTests {

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

private final class ArtworkURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            if request.url?.host?.hasPrefix("prepare") == true {
                #expect(request.httpMethod == "POST")
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-artwork-token")
                var bodyData = request.httpBody ?? Data()
                if bodyData.isEmpty, let stream = request.httpBodyStream {
                    stream.open(); defer { stream.close() }
                    var buffer = [UInt8](repeating: 0, count: 4096)
                    while stream.hasBytesAvailable {
                        let count = stream.read(&buffer, maxLength: buffer.count)
                        if count <= 0 { break }
                        bodyData.append(contentsOf: buffer.prefix(count))
                    }
                }
                let body = try JSONSerialization.jsonObject(with: bodyData) as! [String: Any]
                #expect(body["contract_version"] as? Int == 1)
                #expect(body["session_id"] as? String == "session-fixture-1")
                #expect(body["subject"] == nil && body["url"] == nil && body["text"] == nil)
                var media = try artworkExample("older_entry_refresh")
                if request.url?.host == "preparebad.artwork.invalid" { media["session_id"] = "another-owner-session" }
                let data = try JSONSerialization.data(withJSONObject: ["success": true, "contract_version": 1, "session_media": [media]])
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
                return
            }
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-artwork-token")
            #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-Type") == "ios")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(query.count == 2)
            #expect(query.first(where: { $0.name == "device_id" })?.value == "djconnect-ios-artwork-test")
            #expect(query.first(where: { $0.name == "client_type" })?.value == "ios")
            #expect(request.value(forHTTPHeaderField: "Cache-Control") == "no-store")
            #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
            #expect(request.url?.path.contains("/session/media/image/session-fixture-1/") == true)
            let status = Int(request.url?.host?.split(separator: ".").first ?? "") ?? 200
            let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Fixtures/session-artwork-artist-core-5c7ecb79.png")
            var data = try Data(contentsOf: file)
            if status == 201 { data = Data(repeating: 0, count: 2 * 1024 * 1024 + 1) }
            if status == 202 { data = Data("not an image".utf8) }
            let code = [201, 202, 203].contains(status) ? 200 : status
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": "image/png", "Cache-Control": "no-store"])!
            if status == 203 {
                let bytes = data
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) { [self] in
                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                    client?.urlProtocol(self, didLoad: bytes)
                    client?.urlProtocolDidFinishLoading(self)
                }
            } else {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            }
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

private func liveArtworkExample() throws -> DJConnectSessionMedia {
    var value = try artworkExample("artist_story")
    var art = try #require(value["artwork"] as? [String: Any])
    art["captured_at"] = ISO8601DateFormatter().string(from: Date())
    art["expires_at"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(60))
    value["artwork"] = art
    return try decodeArtwork(value)
}

@Test func sessionMediaAuthenticatedPixelsAndResourceFailuresKeepPairing() async throws {
    let media = try liveArtworkExample()
    let token = DJConnectInMemoryTokenStore(token: "fixture-artwork-token")
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ArtworkURLProtocol.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    for status in [200, 401, 403, 404, 410, 302, 201, 202] {
        let client = DJConnectClient(baseURL: URL(string: "https://\(status).artwork.invalid")!,
                                    identity: .init(deviceID: "djconnect-ios-artwork-test", deviceName: "Fixture", clientType: .ios, firmware: "4.0.0", platform: .ios),
                                    tokenStore: token, session: session)
        do {
            let pixels = try await client.sessionArtwork(media, sessionID: media.sessionID,
                                                        target: try #require(media.target), audience: .activeFlow)
            #expect(status == 200)
            #expect(pixels.image.width == 64 && pixels.image.height == 64)
        } catch let error as DJConnectError {
            switch status {
            case 401: #expect(error == .authStale(statusCode: 401, message: nil))
            case 403: #expect(error == .profile(code: .profileAccessDenied, statusCode: 403, message: nil))
            case 404, 410: #expect(error == .routeMissing(message: nil))
            case 302: #expect(error == .server(statusCode: 302, message: nil))
            case 201: if case .payloadTooLarge = error {} else { Issue.record("Expected bounded stream rejection") }
            case 202: #expect(error == .invalidResponse)
            default: Issue.record("Unexpected image failure: \(error)")
            }
        }
        #expect(try token.loadToken() == "fixture-artwork-token")
    }
}

@Test func sessionMediaDecoderRejectsMIMEGeometryAndContentMismatch() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: root.appendingPathComponent("Fixtures/session-artwork-artist-core-5c7ecb79.png"))
    for (mime, width, height) in [("image/jpeg", 64, 64), ("image/png", 65, 64), ("image/png", 4097, 64), ("image/png", 64, 0)] {
        #expect(throws: DJConnectError.self) {
            try DJConnectSessionArtworkTransport.decode(data, mime: mime, width: width, height: height)
        }
    }
    #expect(throws: DJConnectError.self) {
        try DJConnectSessionArtworkTransport.decode(Data(data.prefix(20)), mime: "image/png", width: 64, height: 64)
    }
}

@Test func sessionMediaOptionalProjectionDoesNotDropMomentOrHistoryText() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/moment-contract-receipt.json"))) as! [String: Any]
    var snapshot = try #require(raw["snapshot"] as? [String: Any])
    let original = try JSONDecoder().decode(DJConnectBroadcastState.self, from: JSONSerialization.data(withJSONObject: snapshot))
    snapshot["session_media"] = [try artworkExample("artist_story"), ["schema_version": "future", "artwork": true]]
    let augmented = try JSONDecoder().decode(DJConnectBroadcastState.self, from: JSONSerialization.data(withJSONObject: snapshot))
    #expect(augmented.djMoments == original.djMoments)
    #expect(augmented.sessionFlow == original.sessionFlow)
    #expect(augmented.sessionMedia.count == 1)
    var withdrawn = augmented; withdrawn.clearNativeAuthority()
    #expect(withdrawn.sessionMedia.isEmpty)

    let history = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/session-history-producer-receipt.json"))) as! [String: Any]
    let timeline = try #require(history["archived_timeline"] as? [String: Any])
    var entry = try #require((timeline["entries"] as? [[String: Any]])?.first)
    let originalEntry = try JSONDecoder().decode(DJConnectHistoryEntry.self, from: JSONSerialization.data(withJSONObject: entry))
    entry["session_media"] = ["schema_version": "unknown", "artwork": false]
    let optional = try JSONDecoder().decode(DJConnectHistoryEntry.self, from: JSONSerialization.data(withJSONObject: entry))
    #expect(optional.sessionMedia == nil)
    #expect(optional.text == originalEntry.text && optional.entryID == originalEntry.entryID)
    #expect(optional.isContractValid == originalEntry.isContractValid)
    entry["session_media"] = try artworkExample("older_entry_refresh")
    let valid = try JSONDecoder().decode(DJConnectHistoryEntry.self, from: JSONSerialization.data(withJSONObject: entry))
    #expect(valid.sessionMedia != nil)
    #expect(valid.text == originalEntry.text && valid.order == originalEntry.order)
}


@Test func sessionMediaLateBytesCannotExtendOriginalExpiry() async throws {
    var value = try artworkExample("artist_story")
    var art = try #require(value["artwork"] as? [String: Any])
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    art["captured_at"] = formatter.string(from: Date().addingTimeInterval(-1))
    art["expires_at"] = formatter.string(from: Date().addingTimeInterval(0.2))
    value["artwork"] = art
    let media = try decodeArtwork(value)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ArtworkURLProtocol.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let client = DJConnectClient(baseURL: URL(string: "https://203.artwork.invalid")!,
        identity: .init(deviceID: "djconnect-ios-artwork-test", deviceName: "Fixture", clientType: .ios, firmware: "4.0.0", platform: .ios),
        tokenStore: DJConnectInMemoryTokenStore(token: "fixture-artwork-token"), session: session)
    #expect(media.admittedArtwork(session: media.sessionID, target: try #require(media.target), audience: .activeFlow) != nil)
    let started = Date()
    await #expect(throws: DJConnectError.invalidResponse) {
        try await client.sessionArtwork(media, sessionID: media.sessionID,
            target: try #require(media.target), audience: .activeFlow)
    }
    #expect(Date().timeIntervalSince(started) >= 0.3)
}


@Test func sessionMediaExplicitPreparationIsBoundedAndCannotSubstituteTargets() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ArtworkURLProtocol.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let original = try decodeArtwork(artworkExample("older_entry_refresh"))
    let target = try #require(original.target)
    func client(_ host: String) -> DJConnectClient {
        DJConnectClient(baseURL: URL(string: "https://" + host)!,
            identity: .init(deviceID: "djconnect-ios-artwork-test", deviceName: "Fixture", clientType: .ios, firmware: "4.0.0", platform: .ios),
            tokenStore: DJConnectInMemoryTokenStore(token: "fixture-artwork-token"), session: session)
    }
    let valid = client("prepare.artwork.invalid")
    let request = try valid.sessionArtworkPreparationRequest(sessionID: "session-fixture-1", targets: [target])
    #expect(request.url?.path == "/api/djconnect/v1/session/media/prepare")
    let result = try await valid.prepareSessionArtwork(sessionID: "session-fixture-1", targets: [target])
    #expect(result == [original])
    for targets: [DJConnectSessionMedia.Target] in [[], [target, target], (0..<9).map { .entry("entry-\($0)") }, [.entry("")]] {
        #expect(throws: DJConnectError.invalidResponse) {
            try valid.sessionArtworkPreparationRequest(sessionID: "session-fixture-1", targets: targets)
        }
    }
    await #expect(throws: DJConnectError.invalidResponse) {
        try await client("preparebad.artwork.invalid").prepareSessionArtwork(sessionID: "session-fixture-1", targets: [target])
    }
}

@Test func sessionMediaLargePixelsAreDownsampledWithoutCropping() throws {
    let context = try #require(CGContext(data: nil, width: 1024, height: 512, bitsPerComponent: 8,
        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let source = try #require(context.makeImage())
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
    CGImageDestinationAddImage(destination, source, nil)
    #expect(CGImageDestinationFinalize(destination))
    let decoded = try DJConnectSessionArtworkTransport.decode(data as Data, mime: "image/png", width: 1024, height: 512)
    #expect(decoded.image.width == 512 && decoded.image.height == 256)
}

}
