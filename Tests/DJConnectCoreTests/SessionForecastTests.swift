import Foundation
import Testing
@testable import DJConnectCore
import SwiftUI
@testable import DJConnectUI
#if os(macOS)
import AppKit
#endif

private func forecastCases() throws -> [[String: Any]] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/session-forecast-core-3cfa5512.json")
    return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
}
private func forecastDecode(_ object: Any) throws -> DJConnectSessionForecast {
    try JSONDecoder().decode(DJConnectSessionForecast.self, from: JSONSerialization.data(withJSONObject: object))
}

@Test(.isolatedClientResources) func forecastActualProducerLocalesAndPersonasDecodeWithOriginalExpiry() throws {
    let cases = try forecastCases()
    #expect(Set(cases.compactMap { $0["language"] as? String }) == ["en", "nl", "de", "fr", "es"])
    #expect(Set(cases.compactMap { $0["persona"] as? String }).count == 4)
    for item in cases {
        let read = try #require(item["owner_read"] as? [String: Any])
        let forecast = try forecastDecode(try #require(read["forecast"]))
        #expect(forecast.structurallyValid)
        let issued = try #require(DJConnectSessionForecast.timestamp(forecast.issued_at))
        let until = try #require(DJConnectSessionForecast.timestamp(forecast.valid_until))
        #expect(forecast.isVisible(sessionID: forecast.session_id, playbackItemID: forecast.current_anchor?.item_id,
                                  playbackSource: forecast.current_anchor?.source_url, at: issued))
        #expect(!forecast.isVisible(sessionID: forecast.session_id, playbackItemID: forecast.current_anchor?.item_id,
                                   playbackSource: forecast.current_anchor?.source_url, at: until))
        #expect(!forecast.isVisible(sessionID: "another-session", playbackItemID: forecast.current_anchor?.item_id,
                                   playbackSource: forecast.current_anchor?.source_url, at: issued))
        #expect(!forecast.isVisible(sessionID: forecast.session_id, playbackItemID: "other-track",
                                   playbackSource: forecast.current_anchor?.source_url, at: issued))
    }
}

@Test(.isolatedClientResources) func forecastRevisionsCannotRestoreWithdrawnOrConflictingContent() throws {
    let item = try #require(forecastCases().first)
    let read = try #require(item["owner_read"] as? [String: Any])
    var object = try #require(read["forecast"] as? [String: Any])
    let latest = try forecastDecode(object)
    var cursor = DJConnectForecastCursor(sessionID: latest.session_id)
    cursor.receive(latest)
    #expect(cursor.projection == latest)
    object["revision"] = latest.revision - 1
    cursor.receive(try forecastDecode(object))
    #expect(cursor.projection == latest)
    object["revision"] = latest.revision
    object["summary"] = "Conflicting equal revision"
    cursor.receive(try forecastDecode(object))
    #expect(cursor.projection == nil)
    cursor.receive(latest)
    #expect(cursor.projection == nil)
    object["revision"] = latest.revision + 1
    let fresh = try forecastDecode(object)
    cursor.receive(fresh)
    #expect(cursor.projection == fresh)
    cursor.withdraw()
    cursor.receive(fresh)
    #expect(cursor.projection == nil)
    #expect(cursor.revisionFloor == fresh.revision)
}

@Test(.isolatedClientResources) func forecastUnknownSchemaAndIntentCannotBecomePlaybackClaims() throws {
    let item = try #require(forecastCases().first)
    let read = try #require(item["owner_read"] as? [String: Any])
    let original = try #require(read["forecast"] as? [String: Any])
    for (key, value) in [("contract_version", 2 as Any), ("nominal_window_seconds", 1200 as Any),
                         ("supported_window_seconds", 901 as Any), ("revision", -1 as Any)] {
        var object = original; object[key] = value
        #expect(try !forecastDecode(object).structurallyValid)
    }
    var object = original
    var sections = try #require(object["sections"] as? [[String: Any]])
    sections[0]["claim_type"] = "guaranteed_upcoming"
    object["sections"] = sections
    #expect(try !forecastDecode(object).structurallyValid)
}

@Test(.isolatedClientResources) func forecastEmptyWithoutTimestampsIsAnHonestWithdrawal() throws {
    let value = try forecastDecode(["contract_version": 1, "session_id": "s", "revision": 0,
        "state": "empty", "nominal_window_seconds": 900, "supported_window_seconds": 0,
        "summary": "", "sections": [], "imagery": []])
    #expect(value.structurallyValid)
    #expect(!value.isVisible(sessionID: "s", playbackItemID: nil, playbackSource: nil, at: Date()))
}

@Test(.isolatedClientResources) func forecastReadUsesExactOrdinaryPairedContractWithoutHistoryLimit() throws {
    let client = DJConnectClient(baseURL: URL(string: "https://fixture.invalid")!,
        identity: .init(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Test", clientType: .ios, firmware: "test", platform: .ios),
        tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-test-only"))
    let request = try client.sessionForecastRequest(sessionID: "fixture-session")
    let url = try #require(request.url)
    #expect(request.httpMethod == "GET")
    #expect(url.path == "/api/djconnect/v1/session/forecast/fixture-session")
    let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    #expect(Set(query.map(\.name)) == ["device_id", "client_type", "contract_version"])
    #expect(query.first { $0.name == "contract_version" }?.value == "1")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-test-only")
    #expect(request.value(forHTTPHeaderField: "Cache-Control") == "no-store")
}

@Test(.isolatedClientResources) func forecastMonotonicLeaseSurvivesFrozenClockAndArtOnlyRevision() throws {
    let read = try #require(forecastCases().first?["owner_read"] as? [String: Any])
    var object = try #require(read["forecast"] as? [String: Any])
    let forecast = try forecastDecode(object)
    let issued = try #require(DJConnectSessionForecast.timestamp(forecast.issued_at))
    var cursor = DJConnectForecastCursor(sessionID: forecast.session_id)
    cursor.receive(forecast, at: issued, uptime: 100)
    #expect(cursor.visible(playbackItemID: forecast.current_anchor?.item_id, playbackSource: forecast.current_anchor?.source_url,
                           at: issued, uptime: 101) != nil)
    object["revision"] = forecast.revision + 1
    // Same original expiry: art changes cannot renew the native lease.
    cursor.receive(try forecastDecode(object), at: issued.addingTimeInterval(10), uptime: 200)
    #expect(cursor.visible(playbackItemID: forecast.current_anchor?.item_id, playbackSource: forecast.current_anchor?.source_url,
                           at: issued.addingTimeInterval(11), uptime: 221) == nil)
    #expect(cursor.visible(playbackItemID: forecast.current_anchor?.item_id, playbackSource: forecast.current_anchor?.source_url,
                           at: issued.addingTimeInterval(-1), uptime: 201) == nil)
}

@Test(.isolatedClientResources) func forecastOptionalArtCannotBecomeHotlinkOrSuppressAuthoredText() throws {
    let read = try #require(forecastCases().first?["owner_read"] as? [String: Any])
    var object = try #require(read["forecast"] as? [String: Any])
    let original = try forecastDecode(object)
    let image = try #require(original.imagery.first)
    let issued = try #require(DJConnectSessionForecast.timestamp(original.issued_at))
    #expect(image.admittedPath(sessionID: original.session_id, at: issued) != nil)
    #expect(image.admittedPath(sessionID: "another-session", at: issued) == nil)
    #expect(image.admittedPath(sessionID: original.session_id, at: Date.distantFuture) == nil)
    let source = try #require((object["imagery"] as? [[String: Any]])?.first)
    for replacement in ["https://untrusted.invalid/art.jpg", "//untrusted.invalid/art.jpg", image.url + "?token=other", image.url + "/../other"] {
        var bad = source; bad["url"] = replacement
        object["imagery"] = [bad]
        let decoded = try forecastDecode(object)
        #expect(decoded.structurallyValid)
        #expect(decoded.summary == original.summary)
        #expect(decoded.imagery.first?.admittedPath(sessionID: original.session_id, at: issued) == nil)
    }
    object["imagery"] = [["broken": true]]
    let decoded = try forecastDecode(object)
    #expect(decoded.structurallyValid && decoded.imagery.isEmpty && decoded.summary == original.summary)
}


@Test(.isolatedClientResources, arguments: ["", "short", String(repeating: "A", count: 23), "../outside", "valid?query=1", "spotify:artist:6eUKZXaKkcviH0Ku9w2n3V", String(repeating: "é", count: 22)])
func forecastOptionalArtRequiresCanonicalArtistIdentity(_ artistID: String) throws {
    let read = try #require(forecastCases().first?["owner_read"] as? [String: Any])
    var object = try #require(read["forecast"] as? [String: Any])
    let original = try forecastDecode(object)
    var image = try #require((object["imagery"] as? [[String: Any]])?.first)
    var subject = try #require(image["subject"] as? [String: Any])
    subject["id"] = "spotify:artist:" + artistID
    image["subject"] = subject
    let url = "https://open.spotify.com/artist/" + artistID.replacingOccurrences(of: "spotify:artist:", with: "")
    image["source_url"] = url
    var attribution = try #require(image["attribution"] as? [String: Any])
    attribution["url"] = url; image["attribution"] = attribution
    object["imagery"] = [image]
    let decoded = try forecastDecode(object)
    let issued = try #require(DJConnectSessionForecast.timestamp(decoded.issued_at))
    #expect(decoded.structurallyValid && decoded.summary == original.summary)
    #expect(decoded.imagery.first?.admittedPath(sessionID: decoded.session_id, at: issued) == nil)
}

#if os(macOS)
@Test(.isolatedClientResources) @MainActor func forecastNativeTextRendersAllAuthoredLocalesAndLargeType() throws {
    for item in try forecastCases() where item["persona"] as? String == "home_dj" {
        let language = try #require(item["language"] as? String)
        let read = try #require(item["owner_read"] as? [String: Any])
        let forecast = try forecastDecode(try #require(read["forecast"]))
        let content = SessionForecastTextView(projection: forecast, language: language)
            .environment(\.dynamicTypeSize, .accessibility2)
            .frame(width: 320).padding(16).foregroundStyle(.white).background(Color.purple)
        let renderer = ImageRenderer(content: content)
        let image = try #require(renderer.nsImage)
        #expect(image.size.width == 352 && image.size.height > 200)
        if let folder = ProcessInfo.processInfo.environment["DJCONNECT_FORECAST_ARTIFACT_DIR"] {
            let directory = URL(fileURLWithPath: folder)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let tiff = try #require(image.tiffRepresentation)
            let bitmap = try #require(NSBitmapImageRep(data: tiff))
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: directory.appendingPathComponent("forecast-" + language + ".png"))
        }
    }
}
#endif
