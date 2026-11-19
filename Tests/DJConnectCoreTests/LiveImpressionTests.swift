import Foundation
import CoreGraphics
import SwiftUI
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

private func liveImpressionFixture() throws -> [String: Any] {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/live-impression-v1.json"))) as? [String: Any])
}
private func liveDecode<T: Decodable>(_ value: Any, as type: T.Type = T.self) throws -> T {
    try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: value))
}
private func liveMoment(_ descriptor: [String: Any]) -> [String: Any] {
    ["moment_id": "test-moment", "session_id": "test-session", "created_at": "2026-11-19T10:00:00Z",
     "type": "live_impression", "title": "Original concert story", "summary": "Original lead.", "content": "Original lead. Original accepted story.",
     "presentation_intent": ["visibility": "owner_only"], "knowledge_intent": ["type": "live_impression"],
     "live_impression": descriptor, "source_references": ["https://example.org/original-story"]]
}
private func liveMedia(_ photo: DJConnectLiveImpression.Photo) -> [String: Any] {
    ["schema_version": 3, "session_id": "test-session", "moment_id": "test-moment", "photo_id": photo.photoID, "revision": "projection-one",
     "artwork": ["state": "ready", "role": "live_impression", "usage_basis": "licensed_event_image_owner_display",
        "subject": ["provider": "public_research", "type": "event_photo", "uri": photo.photoID],
        "media_revision": photo.revision, "source_url": photo.sourceURL, "width": photo.width, "height": photo.height,
        "captured_at": "2026-11-19T10:00:00Z", "expires_at": "2026-11-19T10:05:00Z", "cache_policy": "no-store",
        "requires_device_auth": true, "crop_allowed": false, "upscale_allowed": false,
        "current_display_allowed": true, "active_flow_display_allowed": true, "historical_display_allowed": false,
        "url": "/api/djconnect/v1/session/media/image/test-session/original-photo"]]
}
@Suite("LiveImpression") struct LiveImpressionTests {
    @Test func originalDescriptorAndSourcesSurviveWithoutArtistOrCurrentArtworkFallback() throws {
        let value: DJConnectLiveImpression = try liveDecode(liveImpressionFixture())
        #expect(value.isValid)
        let moment: DJConnectMoment = try liveDecode(liveMoment(liveImpressionFixture()))
        #expect(moment.isLiveImpressionV1)
        #expect(moment.nativeSourceURLs.map(\.absoluteString) == ["https://example.org/original-story"])
        #expect(moment.artwork == nil)
        #expect(moment.liveImpression?.event.date == "2020-07-12")
        var optional = liveMoment(try liveImpressionFixture()); optional["live_impression"] = ["schema_version": 99]
        let fallback: DJConnectMoment = try liveDecode(optional)
        #expect(fallback.content == moment.content)
        #expect(!fallback.isSupportedNativeType)
    }
    @Test(arguments: ["bad_digest", "wrong_event_date", "missing_credit", "unknown_version", "duplicate_photo"])
    func malformedOrUnboundOptionalPhotoCannotBecomeLiveImpression(failure: String) throws {
        var value = try liveImpressionFixture()
        var photos = try #require(value["photos"] as? [[String: Any]])
        switch failure {
        case "bad_digest": photos[0]["revision"] = "not-original-bytes"
        case "wrong_event_date": var event = try #require(value["event"] as? [String: Any]); event["date"] = "2020-02-31"; value["event"] = event
        case "missing_credit": photos[0]["credit"] = ""
        case "unknown_version": value["schema_version"] = 2
        default: photos.append(photos[0])
        }
        value["photos"] = photos
        let decoded: DJConnectLiveImpression = try liveDecode(value)
        #expect(!decoded.isValid)
    }
    @Test func imageLeaseMatchesOriginalPhotoAndTargetWithoutChangingNarrativeRights() throws {
        let value: DJConnectLiveImpression = try liveDecode(liveImpressionFixture())
        let photo = try #require(value.photos.first)
        let media: DJConnectSessionMedia = try liveDecode(liveMedia(photo))
        let now = try #require(DJConnectHistoryEntry.date("2026-11-19T10:01:00Z"))
        #expect(media.admittedLivePhoto(photo, session: "test-session", target: .moment("test-moment"), audience: .current, at: now) != nil)
        #expect(media.admittedArtwork(session: "test-session", target: .moment("test-moment"), audience: .current, at: now) == nil)
        #expect(media.admittedLivePhoto(photo, session: "other-session", target: .moment("test-moment"), audience: .current, at: now) == nil)
        #expect(media.admittedLivePhoto(photo, session: "test-session", target: .entry("test-moment"), audience: .history, at: now) == nil)
        for (field, replacement) in [("url", "https://example.org/image"), ("url", "/api/djconnect/v1/session/media/image/other-session/id"), ("media_revision", String(repeating: "b", count: 64)), ("expires_at", "2026-11-19T10:06:00Z")] {
            var object = liveMedia(photo)
            var art = try #require(object["artwork"] as? [String: Any]); art[field] = replacement; object["artwork"] = art
            let rejected: DJConnectSessionMedia = try liveDecode(object)
            #expect(rejected.admittedLivePhoto(photo, session: "test-session", target: .moment("test-moment"), audience: .current, at: now) == nil)
        }
    }
    @Test func historyKeepsSameStoryEventAndPhotoWithoutTransportGrant() throws {
        let object: [String: Any] = ["entry_id": "test-entry", "session_id": "test-session", "order": 1, "kind": "dj_moment",
            "occurred_at": "2026-11-19T10:00:00Z", "retained_until": "2099-01-01T00:00:00Z", "historical_view_only": true,
            "current_display_allowed": false, "moment_id": "test-moment", "moment_type": "live_impression",
            "title": "Original concert story", "summary": "Original lead.", "text": "Original lead. Original accepted story.",
            "archive_basis": "public_live_impression_v1", "live_impression": try liveImpressionFixture()]
        let entry: DJConnectHistoryEntry = try liveDecode(object)
        #expect(entry.isContractValid)
        let restored = try JSONDecoder().decode(DJConnectHistoryEntry.self, from: JSONEncoder().encode(entry))
        #expect(restored.liveImpression == entry.liveImpression)
        #expect(restored.title == entry.title && restored.text == entry.text)
        #expect(restored.sessionMedia == nil)
        var malformed = object
        malformed["live_impression"] = ["schema_version": 1]
        let safeFallback: DJConnectHistoryEntry = try liveDecode(malformed)
        #expect(safeFallback.isContractValid && safeFallback.text == entry.text)
        #expect(safeFallback.liveImpression == nil)
    }
    @Test func liveDisplayNeedsIndependentAdmissionAndKeepsOriginalTrackContext() throws {
        let original = liveMoment(try liveImpressionFixture())
        let base: [String: Any] = ["session": ["session_id": "test-session", "runtime_state": "active", "selected_mood": "chill"],
            "planner": ["planning_state": "ready", "planning_horizon_minutes": 15, "current_direction": "test"],
            "session_flow": ["flow_id": "test-flow", "planning_horizon_minutes": 15, "created_at": "2026-11-19T10:00:00Z", "items": []],
            "playback": ["state": "playing", "item_id": "original-track"], "dj_moments": [original],
            "native_delivery": ["schema_version": 1, "session_id": "test-session", "revision": "one", "current_moment_id": "test-moment",
                "current_silence_moment_id": NSNull(), "active_flow_moment_ids": [], "revocation_scope": "session",
                "admissions": [["moment_id": "test-moment", "qualification": "qualified", "current_display_allowed": true,
                    "active_flow_display_allowed": true, "source_expires_at": NSNull(), "display_expires_at": "2026-11-19T10:00:20Z",
                    "executable_actions": [], "requires_spotify_attribution": false]]]]
        var object = base; var moment = original; moment["playback_item_id"] = "original-track"; object["dj_moments"] = [moment]
        let snapshot: DJConnectBroadcastState = try liveDecode(object)
        let now = try #require(DJConnectHistoryEntry.date("2026-11-19T10:00:01Z"))
        #expect(snapshot.nativeCurrentMoment(at: now)?.id == "test-moment")
        var changed = snapshot; changed.playback?.itemID = "different-track"
        #expect(changed.nativeCurrentMoment(at: now) == nil)
        #expect(snapshot.nativeCurrentMoment(at: now.addingTimeInterval(30)) == nil)
        var revoked = snapshot; revoked.clearNativeAuthority()
        #expect(revoked.nativeCurrentMoment(at: now) == nil)
    }
    @MainActor @Test func lateOldPhotoCompletionAndCleanupCannotClearNewPixelsOrViewer() throws {
        let context = try #require(CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = DJConnectSessionArtworkImage(image: try #require(context.makeImage()))
        var state = LiveImpressionPhotoState()
        let old = state.begin()
        let current = state.begin()
        state.complete(image, generation: current); state.showsPhoto = true
        state.finish(generation: old)
        state.complete(image, generation: old)
        #expect(state.pixels != nil && state.showsPhoto && !state.isLoading)
        state.finish(generation: current)
        #expect(state.pixels == nil && !state.showsPhoto && !state.isLoading)
    }
}

#if os(macOS)
import AppKit

@MainActor @Test func liveImpressionNativeLayoutFitsCompactWideAndLargeTextWithoutNetwork() throws {
    let descriptor: DJConnectLiveImpression = try liveDecode(liveImpressionFixture())
    let suite = "live-impression-layout-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    let output = ProcessInfo.processInfo.environment["DJCONNECT_LIVE_IMPRESSION_PREVIEW_DIR"].map { URL(fileURLWithPath: $0) }
    if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
    for language in ["nl", "en", "de", "fr", "es"] {
        for width in [390, 960] {
            let renderer = ImageRenderer(content: LiveImpressionContentView(impression: descriptor,
                title: "Original concert story — native layout fixture", lead: "A short opening that remains readable while the original photo is unavailable.",
                story: "A short opening that remains readable while the original photo is unavailable. The complete original story stays here.",
                language: language, sessionID: "test-session", target: .moment("test-moment"), model: model)
                .padding(20).background(Color(red: 0.07, green: 0.06, blue: 0.18))
                .environment(\.scenePhase, .inactive).environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, width == 390 ? .accessibility1 : .large)
                .environment(\.djConnectGlassEffectsEnabled, false))
            renderer.proposedSize = .init(width: CGFloat(width), height: nil)
            let image = try #require(renderer.cgImage)
            #expect(image.width == width)
            #expect(image.height > 200 && image.height < 2000)
            if let output {
                let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
                try png.write(to: output.appendingPathComponent("live-impression-\(language)-\(width).png"))
            }
        }
    }
}
#endif

import CryptoKit
import ImageIO

private final class LiveImpressionPhotoWire: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if request.url?.host == "must-not-dispatch.live.invalid" {
            Issue.record("A revoked original owner must not dispatch an image request")
        }
        do {
            if request.url?.host?.contains("withdrawn") == true {
                let wrong = request.url?.host == "wrong-withdrawn.live.invalid"
                let body: [String: Any] = ["success": true, "contract_version": 3, "session_media": [[
                    "schema_version": 3, "session_id": wrong ? "foreign-session" : "test-session", "moment_id": "test-moment", "photo_id": "test-photo",
                    "artwork": ["state": "withdrawn", "reason": "source_withdrawn", "current_display_allowed": false,
                        "active_flow_display_allowed": false, "historical_display_allowed": false]]]]
                let data = try JSONSerialization.data(withJSONObject: body)
                let url = try #require(request.url)
                let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]))
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
                return
            }
            let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            let data = try Data(contentsOf: root.appendingPathComponent("Fixtures/session-artwork-artist-core-5c7ecb79.png"))
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "image/png", "Cache-Control": "no-store"]))
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@MainActor @Test(.isolatedClientResources) func liveImpressionTransportRejectsReplacementBytesAndFencesRevokedOwnerBeforeDispatch() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: root.appendingPathComponent("Fixtures/session-artwork-artist-core-5c7ecb79.png"))
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    let attributes = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    let width = try #require(attributes[kCGImagePropertyPixelWidth] as? Int)
    let height = try #require(attributes[kCGImagePropertyPixelHeight] as? Int)
    var object = try liveImpressionFixture()
    var photos = try #require(object["photos"] as? [[String: Any]])
    photos[0]["width"] = width; photos[0]["height"] = height
    photos[0]["revision"] = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    object["photos"] = photos
    let descriptor: DJConnectLiveImpression = try liveDecode(object)
    let photo = try #require(descriptor.photos.first)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [LiveImpressionPhotoWire.self]
    let transport = DJConnectSessionArtworkTransport(configuration: configuration)
    let request = URLRequest(url: try #require(URL(string: "https://original.live.invalid/image")))
    let image = try await transport.loadLivePhoto(request, photo: photo, isCurrent: { true })
    #expect(image.image.width == width && image.image.height == height)
    var bad = photos[0]; bad["revision"] = String(repeating: "0", count: 64)
    let replacement: DJConnectLiveImpression.Photo = try liveDecode(bad)
    await #expect(throws: DJConnectError.self) { try await transport.loadLivePhoto(request, photo: replacement, isCurrent: { true }) }
    let blocked = URLRequest(url: try #require(URL(string: "https://must-not-dispatch.live.invalid/image")))
    await #expect(throws: CancellationError.self) { try await transport.loadLivePhoto(blocked, photo: photo, isCurrent: { false }) }
}

#if os(macOS)
@MainActor @Test func liveImpressionNativePositiveHeroAndStoryUseSameProductionPresentation() throws {
    let descriptor: DJConnectLiveImpression = try liveDecode(liveImpressionFixture())
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let bytes = try Data(contentsOf: root.appendingPathComponent("Fixtures/session-artwork-artist-core-5c7ecb79.png"))
    let source = try #require(CGImageSourceCreateWithData(bytes as CFData, nil))
    let image = DJConnectSessionArtworkImage(image: try #require(CGImageSourceCreateImageAtIndex(source, 0, nil)))
    let photo = try #require(descriptor.photos.first)
    let output = ProcessInfo.processInfo.environment["DJCONNECT_LIVE_IMPRESSION_PREVIEW_DIR"].map { URL(fileURLWithPath: $0) }
    var heights: [Int] = []
    for width in [390, 960] {
        let renderer = ImageRenderer(content: LiveImpressionStoryView(impression: descriptor,
            title: "Synthetic native render fixture", lead: "Original accepted introduction, shown next to the original photo on a wide screen.",
            story: "Original accepted introduction, shown next to the original photo on a wide screen. The full accepted story remains available.", language: "nl") {
                LiveImpressionPhotoPresentation(photo: photo, pixels: image, isLoading: false, allowsRetry: false, language: "nl")
            }.padding(20).background(Color(red: 0.07, green: 0.06, blue: 0.18))
            .environment(\.colorScheme, .dark).environment(\.djConnectGlassEffectsEnabled, false))
        renderer.proposedSize = .init(width: CGFloat(width), height: nil)
        let rendered = try #require(renderer.cgImage)
        #expect(rendered.width == width && rendered.height > 200 && rendered.height < 1600)
        heights.append(rendered.height)
        if let output {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let png = try #require(NSBitmapImageRep(cgImage: rendered).representation(using: .png, properties: [:]))
            try png.write(to: output.appendingPathComponent("live-impression-positive-fixture-\(width).png"))
        }
    }
    #expect(heights[1] < heights[0] * 2, "Wide view keeps photo and narrative beside each other")
}
#endif

@Test func liveImpressionDecodesActualCoreProducerRuntimeHistoryMediaAndSpeechFixture() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let raw = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/live-impression-core-candidate.json"))) as? [String: Any])
    let moment: DJConnectMoment = try liveDecode(try #require(raw["moment"]))
    let history: DJConnectHistoryEntry = try liveDecode(try #require(raw["history"]))
    let media: DJConnectSessionMedia = try liveDecode(try #require(raw["media"]))
    let speech: DJConnectSessionSpeech = try liveDecode(try #require(raw["speech"]))
    let value = try #require(moment.liveImpression)
    let photo = try #require(value.photos.first)
    #expect(moment.isLiveImpressionV1 && history.isContractValid)
    #expect(moment.playbackItemID?.isEmpty == false)
    #expect(history.liveImpression == value && history.text == moment.content && history.title == moment.title)
    #expect(moment.liveSources.count == 1 && moment.liveSources.first?.license == photo.license)
    let roundTrip = try JSONDecoder().decode(DJConnectMoment.self, from: JSONEncoder().encode(moment))
    #expect(roundTrip.liveSources == moment.liveSources && roundTrip.liveImpression == value)
    #expect(moment.nativeSourceURLs.contains { $0.absoluteString == photo.sourceURL })
    let instant = try #require(media.artwork.capturedAt.flatMap(DJConnectHistoryEntry.date)).addingTimeInterval(1)
    #expect(media.admittedLivePhoto(photo, session: moment.sessionID, target: .moment(moment.id), audience: .current, at: instant) != nil)
    #expect(speech.admits(reference: .moment(sessionID: moment.sessionID, momentID: moment.id), text: moment.content, at: instant))
    #expect(speech.autoplayEligible == false && speech.manualAllowed)
}

@MainActor @Test(.isolatedClientResources) func liveImpressionWithdrawalIsTypedOnlyForOriginalTargetAndLeavesStoryIntact() async throws {
    let value: DJConnectLiveImpression = try liveDecode(liveImpressionFixture())
    let photo = try #require(value.photos.first)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [LiveImpressionPhotoWire.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    func client(_ host: String) throws -> DJConnectClient {
        DJConnectClient(baseURL: try #require(URL(string: "https://" + host)),
            identity: .init(deviceID: "djconnect-ios-live-fixture", deviceName: "Fixture", clientType: .ios, firmware: "4.1.0", platform: .ios),
            tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-live-impression-token"), session: session)
    }
    let original = try client("withdrawn.live.invalid")
    await #expect(throws: DJConnectLiveImpressionMediaError.withdrawn) {
        try await original.prepareLiveImpressionPhoto(sessionID: "test-session", target: .moment("test-moment"), photo: photo, audience: .current, isCurrent: { true })
    }
    let foreign = try client("wrong-withdrawn.live.invalid")
    await #expect(throws: DJConnectError.invalidResponse) {
        try await foreign.prepareLiveImpressionPhoto(sessionID: "test-session", target: .moment("test-moment"), photo: photo, audience: .current, isCurrent: { true })
    }
    var state = LiveImpressionPhotoState()
    let old = state.begin(); let current = state.begin()
    state.fail(generation: old, withdrawn: true)
    #expect(!state.withdrawn && state.isLoading)
    state.fail(generation: current, withdrawn: true); state.finish(generation: current)
    #expect(state.withdrawn && state.pixels == nil && !state.isLoading)
    #expect(value.isValid && value.event.eventID == "test-event")
}
