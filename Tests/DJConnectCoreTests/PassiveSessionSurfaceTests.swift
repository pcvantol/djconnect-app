import Foundation
import CoreGraphics
import ImageIO
import Testing
import DJConnectCore
@testable import DJConnectUI

private func passiveOriginal() throws -> [String: Any] {
    #if SWIFT_PACKAGE
    let url = try #require(Bundle.module.url(forResource: "passive-session-core-2cb87cb7", withExtension: "json", subdirectory: "Fixtures") ?? Bundle.module.url(forResource: "passive-session-core-2cb87cb7", withExtension: "json"))
    #else
    // Match the other native contract fixtures: Xcode does not synthesize
    // SwiftPM's Bundle.module accessor for this macOS unit-test target.
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Fixtures/passive-session-core-2cb87cb7.json")
    #endif
    let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let rows = try #require(root["rows"] as? [[String: Any]])
    return try #require(rows.first?["response"] as? [String: Any])
}
private func passiveDecode(_ json: [String: Any]) throws -> DJConnectPassiveSurfaceResponse {
    try JSONDecoder().decode(DJConnectPassiveSurfaceResponse.self, from: JSONSerialization.data(withJSONObject: json))
}
private func passiveCurrent(surface: DJConnectPassiveSurface = .widget, mutation: (inout [String: Any]) -> Void = { _ in }) throws -> DJConnectPassiveSurfaceResponse {
    var root = try passiveOriginal()
    var p = try #require(root["passive_session"] as? [String: Any])
    let old = try #require((p["as_of"] as? String).flatMap(DJConnectHistoryEntry.date))
    let shift = Date().timeIntervalSince(old) - 0.02
    func shifted(_ value: Any) -> Any {
        if let object = value as? [String: Any] {
            return object.mapValues { shifted($0) }
        }
        if let list = value as? [Any] { return list.map(shifted) }
        if let string = value as? String, let date = DJConnectHistoryEntry.date(string), string.contains("T") {
            return ISO8601DateFormatter().string(from: date.addingTimeInterval(shift))
        }
        return value
    }
    p = try #require(shifted(p) as? [String: Any])
    p["surface"] = surface.rawValue
    var policy = try #require(p["cache_policy"] as? [String: Any]); policy["locked_display"] = surface == .liveActivity; p["cache_policy"] = policy
    mutation(&p); root["passive_session"] = p
    return try passiveDecode(root)
}

@Test @MainActor func passiveHomeWidgetAcceptsItsOwnGrantWithoutLockedScreenPermission() async throws {
    let response = try passiveCurrent()
    #expect(response.passive_session.cache_policy.locked_display == false)
    #expect(response.validates(sessionID: response.passive_session.session_id, surface: .widget))
    let model = PassiveSessionSurfaceModel()
    let services = PassiveSessionSurfaceModel.Services(available: { true }, authorize: { _, _, _ in response },
        read: { _, _, _ in response }, image: { _, _ in Data() })
    model.bind(owner: "profile-A", sessionID: response.passive_session.session_id, foreground: true)
    await model.discover(services)
    await model.setEnabled(true, surface: .widget, services: services)
    #expect(model.enabled(.widget))
    #expect(model.caches[.widget]?.projection.currentContribution(at: Date())?.text == response.passive_session.contribution?.text)
}

@Test @MainActor func passiveLiveActivityStillRejectsMissingLockedScreenPermission() async throws {
    let response = try passiveCurrent(surface: .liveActivity) { p in
        var policy = p["cache_policy"] as! [String: Any]; policy["locked_display"] = false; p["cache_policy"] = policy
    }
    let model = PassiveSessionSurfaceModel()
    let services = PassiveSessionSurfaceModel.Services(available: { true }, authorize: { _, _, _ in response },
        read: { _, _, _ in response }, image: { _, _ in Data() })
    model.bind(owner: "profile-A", sessionID: response.passive_session.session_id, foreground: true)
    await model.discover(services); await model.setEnabled(true, surface: .liveActivity, services: services)
    #expect(!model.enabled(.liveActivity) && model.caches[.liveActivity] == nil)
}

@Test @MainActor func passivePublicationHintDuringImageLoadStillReadsNewestContribution() async throws {
    let first = try passiveCurrent()
    let newest = try passiveCurrent { p in
        p["delivery_sequence"] = (p["delivery_sequence"] as! Int) + 1
        var c = p["contribution"] as! [String: Any]
        c["moment_id"] = "new-publication"; c["text"] = "Tweede voorbeeldbijdrage."; p["contribution"] = c
    }
    var releaseImage: CheckedContinuation<Data, Never>?
    var imageCalls = 0, reads = 0, authorizes = 0
    let services = PassiveSessionSurfaceModel.Services(available: { true }, authorize: { _, _, _ in
        authorizes += 1; return first
    }, read: { _, _, _ in reads += 1; return newest }, image: { _, _ in
        imageCalls += 1
        if imageCalls == 1 { return await withCheckedContinuation { releaseImage = $0 } }
        return Data()
    })
    let model = PassiveSessionSurfaceModel()
    model.bind(owner: "A", sessionID: first.passive_session.session_id, foreground: true)
    await model.discover(services)
    let authorization = Task { await model.setEnabled(true, surface: .widget, services: services) }
    for _ in 0..<100 where releaseImage == nil { try await Task.sleep(for: .milliseconds(5)) }
    #expect(releaseImage != nil)
    model.invalidate(sequence: newest.passive_session.delivery_sequence, services: services)
    try await Task.sleep(for: .milliseconds(350))
    #expect(reads == 0) // The first permitted image is still in flight.
    releaseImage?.resume(returning: Data())
    await authorization.value
    try await Task.sleep(for: .milliseconds(400))
    #expect(reads == 1 && authorizes == 1)
    #expect(model.caches[.widget]?.projection.contribution?.moment_id == "new-publication")
    #expect(model.caches[.widget]?.projection.contribution?.expires_at == newest.passive_session.contribution?.expires_at)
    model.bind(owner: nil, sessionID: nil, foreground: false)
}

@Test func pinnedPassiveProjectionPreservesTextSubjectDeadlinesAndNoGrantInCache() throws {
    let response = try passiveDecode(passiveOriginal())
    let p = response.passive_session
    let now = try #require(DJConnectHistoryEntry.date(p.as_of)).addingTimeInterval(0.001)
    #expect(response.validates(sessionID: p.session_id, surface: .widget))
    #expect(p.isCurrent(at: now))
    #expect(p.currentContribution(at: now)?.text == "Northline ontstond in 1991 als groep.")
    #expect(p.currentArtwork(slot: "now_playing", at: now)?.subject.uri == p.now_playing?.subject_uri)
    let cache = try DJConnectPassiveSurfaceCache(projection: p, at: now, uptime: 1_000)
    let encoded = String(decoding: try JSONEncoder().encode(cache), as: UTF8.self)
    #expect(!encoded.contains(response.grant_id) && !encoded.contains("grant_id") && !encoded.contains("device_id"))
    #expect(!cache.isCurrent(at: now.addingTimeInterval(-1), uptime: 1_001))
    #expect(!cache.isCurrent(at: now, uptime: 999))
    #expect(!cache.isCurrent(at: now, uptime: 1_121)) // Wall-clock rollback cannot renew expired evidence.
    let withoutContribution = cache.removingExpiredFields(at: now.addingTimeInterval(41))
    #expect(withoutContribution.projection.contribution == nil)
    #expect(withoutContribution.projection.now_playing != nil)
    #expect(withoutContribution.receivedAt == cache.receivedAt && withoutContribution.receivedUptime == cache.receivedUptime)
    #expect(p.currentContribution(at: now.addingTimeInterval(41)) == nil)
    #expect(p.currentArtwork(slot: "now_playing", at: now.addingTimeInterval(85)) == nil)
    #expect(!p.isCurrent(at: now.addingTimeInterval(121)))
}

@Test(arguments: ["ttl", "subject", "role", "rights", "path", "crop", "alt", "presence", "private", "long_text"])
func passiveRejectsRightsSubjectClockOrContentSubstitution(_ fault: String) throws {
    var root = try passiveOriginal(), p = try #require(root["passive_session"] as? [String: Any])
    if fault == "ttl" { p["expires_at"] = "2030-01-01T00:00:00Z" }
    if fault == "presence" { p["presence"] = "music_only" }
    if ["private", "long_text"].contains(fault) {
        var c = try #require(p["contribution"] as? [String: Any])
        c[fault == "private" ? "usage_basis" : "text"] = fault == "private" ? "private_owner_answer" : String(repeating: "x", count: 641)
        p["contribution"] = c
    }
    if ["subject", "role", "rights", "path", "crop", "alt"].contains(fault) {
        var art = try #require(p["artwork"] as? [[String: Any]])
        if fault == "subject" {
            var subject = try #require(art[0]["subject"] as? [String: Any]); subject["uri"] = "spotify:track:ZZZZZZZZZZZZZZZZZZZZZZ"; art[0]["subject"] = subject
        }
        if fault == "role" { art[0]["role"] = "contextual_cover" }
        if fault == "path" { art[0]["image_path"] = "https://untrusted.example/image" }
        if fault == "crop" { art[0]["crop_allowed"] = true }
        if fault == "alt" { art[0]["alt_text"] = ["en": "Only English"] }
        if fault == "rights" {
            var rights = try #require(art[0]["rights"] as? [String: Any]); rights["watch_replication"] = true; art[0]["rights"] = rights
        }
        p["artwork"] = art
    }
    root["passive_session"] = p
    #expect(try passiveDecode(root).passive_session.isValid == false)
}

@Test func passiveCacheWithdrawsExpiredAndLimitsPixelsAndPurpose() throws {
    let r = try passiveCurrent()
    let now = Date(), suite = "passive-test-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
    let cache = try DJConnectPassiveSurfaceCache(projection: r.passive_session, at: now, uptime: 5)
    try DJConnectPassiveSurfaceCache.replace(cache, surface: .widget, in: defaults)
    #expect(DJConnectPassiveSurfaceCache.load(surface: .widget, from: defaults, at: now, uptime: 6) != nil)
    #expect(DJConnectPassiveSurfaceCache.load(surface: .liveActivity, from: defaults, at: now, uptime: 6) == nil)
    #expect(DJConnectPassiveSurfaceCache.load(surface: .widget, from: defaults, at: now.addingTimeInterval(121), uptime: 126) == nil)
    #expect(defaults.object(forKey: DJConnectPassiveSurfaceCache.key(.widget)) == nil)
    #expect(throws: DJConnectError.self) {
        try DJConnectPassiveSurfaceCache(projection: r.passive_session, pixels: ["now_playing": Data(repeating: 0, count: 256_001)])
    }
    #expect(throws: DJConnectError.self) {
        try DJConnectPassiveSurfaceCache(projection: r.passive_session, pixels: ["contribution": Data([1])])
    }
}

@Test func passiveActivityPayloadIsSmallPurposeBoundAndUsesOriginalEarliestExpiry() throws {
    let r = try passiveCurrent(surface: .liveActivity), now = Date()
    let cache = try DJConnectPassiveSurfaceCache(projection: r.passive_session, at: now)
    let rich = try #require(DJConnectPassiveActivityContent(cache: cache, at: now))
    #expect(try JSONEncoder().encode(rich).count <= 2_800)
    let state = DJConnectSessionSurfaceSnapshot(observedAt: now, theme: .groove, rich: rich)
    #expect(try JSONEncoder().encode(state).count + 128 < 4_096)
    #expect(rich.contribution?.text == r.passive_session.contribution?.text)
    #expect(rich.expiresAt == r.passive_session.deadlines.min())
    #expect(rich.isCurrent(at: now))
    #expect(!rich.isCurrent(at: rich.expiresAt))
    #expect(!String(decoding: try JSONEncoder().encode(rich), as: UTF8.self).contains(r.grant_id))
    let widget = try passiveCurrent()
    #expect(DJConnectPassiveActivityContent(cache: try DJConnectPassiveSurfaceCache(projection: widget.passive_session)) == nil)
}

@Test func passiveActivityFieldExpiryKeepsOriginalNeutralSessionAndOtherCurrentField() throws {
    let now = Date()
    let r = try passiveCurrent(surface: .liveActivity) { p in
        var contribution = p["contribution"] as! [String: Any]
        contribution["expires_at"] = ISO8601DateFormatter().string(from: now.addingTimeInterval(3))
        p["contribution"] = contribution
        var playback = p["now_playing"] as! [String: Any]
        playback["expires_at"] = ISO8601DateFormatter().string(from: now.addingTimeInterval(60))
        p["now_playing"] = playback
        p["expires_at"] = ISO8601DateFormatter().string(from: now.addingTimeInterval(100))
        p["artwork"] = []
    }
    let cache = try DJConnectPassiveSurfaceCache(projection: r.passive_session, at: now)
    let rich = try #require(DJConnectPassiveActivityContent(cache: cache, at: now))
    let state = DJConnectSessionSurfaceSnapshot(observedAt: now, theme: .groove, rich: rich)
    let later = now.addingTimeInterval(5)
    #expect(!state.isCurrent(at: later))
    let neutral = try #require(state.neutral(at: later))
    #expect(neutral.rich == nil && neutral.theme == .groove)
    #expect(neutral.observedAt == now && neutral.expiresAt == now.addingTimeInterval(120))
    #expect(neutral.neutral(at: now.addingTimeInterval(120)) == nil)
    let remaining = try #require(DJConnectPassiveActivityContent(cache: cache, at: later))
    #expect(remaining.contribution == nil && remaining.nowPlaying != nil)
    #expect(remaining.expiresAt == r.passive_session.now_playing.flatMap { DJConnectHistoryEntry.date($0.expires_at) })
    #expect(remaining.isCurrent(at: later))
}

@Test @MainActor func passiveConsentIsExplicitReadsCoalesceAndABARejectsLateCompletion() async throws {
    let model = PassiveSessionSurfaceModel(), r = try passiveCurrent()
    var authorizes = 0, reads = 0
    let services = PassiveSessionSurfaceModel.Services(available: { true }, authorize: { _, _, enabled in
        authorizes += 1
        try await Task.sleep(for: .milliseconds(60))
        return enabled ? r : nil
    }, read: { _, _, _ in reads += 1; try await Task.sleep(for: .milliseconds(30)); return r }, image: { _, _ in Data() })
    model.bind(owner: "profileA", sessionID: r.passive_session.session_id, foreground: true)
    await model.discover(services)
    model.refresh(services)
    #expect(authorizes == 0 && reads == 0 && model.caches.isEmpty)
    await model.setEnabled(true, surface: .widget, services: services)
    #expect(model.enabled(.widget) && model.caches[.widget]?.projection.contribution != nil)
    model.refresh(services); model.refresh(services)
    try await Task.sleep(for: .milliseconds(80))
    #expect(reads == 1 && authorizes == 1)
    model.suspend()
    #expect(model.caches[.widget] != nil) // Only original expiry survives suspension.
    model.bind(owner: "profileA", sessionID: r.passive_session.session_id, foreground: true)
    let task = Task { await model.setEnabled(true, surface: .widget, services: services) }
    try await Task.sleep(for: .milliseconds(10))
    model.bind(owner: "profileB", sessionID: r.passive_session.session_id, foreground: true)
    model.bind(owner: "profileA", sessionID: r.passive_session.session_id, foreground: true)
    await task.value
    #expect(model.caches.isEmpty && !model.enabled(.widget))
}

@Test @MainActor func passiveReadFailureDoesNotRenewAndRevocationClearsOnlySurface() async throws {
    let model = PassiveSessionSurfaceModel(), r = try passiveCurrent()
    let normal = PassiveSessionSurfaceModel.Services(available: { true }, authorize: { _, _, enabled in enabled ? r : nil },
        read: { _, _, _ in throw URLError(.notConnectedToInternet) }, image: { _, _ in Data() })
    model.bind(owner: "profileA", sessionID: r.passive_session.session_id, foreground: true)
    await model.discover(normal); await model.setEnabled(true, surface: .widget, services: normal)
    let old = try #require(model.caches[.widget])
    model.refresh(normal, force: true)
    try await Task.sleep(for: .milliseconds(30))
    #expect(model.caches[.widget]?.receivedAt == old.receivedAt)
    let deny = PassiveSessionSurfaceModel.Services(available: { true }, authorize: normal.authorize,
        read: { _, _, _ in throw DJConnectError.profile(code: .profileAccessDenied, statusCode: 403, message: nil) }, image: normal.image)
    model.refresh(deny, force: true)
    try await Task.sleep(for: .milliseconds(30))
    #expect(model.caches.isEmpty && !model.enabled(.widget))
    await model.setEnabled(true, surface: .widget, services: normal)
    await model.setEnabled(false, surface: .widget, services: normal)
    #expect(model.caches.isEmpty && !model.enabled(.widget))
}

private final class PassiveWire: @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var wires: [String: PassiveWire] = [:]
    let host = UUID().uuidString.lowercased() + ".invalid"
    let handler: @Sendable (URLRequest) throws -> (Int, String, Data)
    init(_ handler: @escaping @Sendable (URLRequest) throws -> (Int, String, Data)) {
        self.handler = handler; Self.lock.withLock { Self.wires[host] = self }
    }
    func close() { _ = Self.lock.withLock { Self.wires.removeValue(forKey: host) } }
    func client() -> DJConnectClient {
        let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [PassiveURLProtocol.self]
        return DJConnectClient(baseURL: URL(string: "https://" + host)!, identity: .init(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Fixture", clientType: .ios, firmware: "4.0.0", platform: .ios), tokenStore: DJConnectInMemoryTokenStore(token: "fixture-passive-token"), session: URLSession(configuration: c))
    }
}
private final class PassiveURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { PassiveWire.lock.withLock { PassiveWire.wires[request.url?.host ?? ""] != nil } }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let wire = PassiveWire.lock.withLock({ PassiveWire.wires[request.url?.host ?? ""] }) else { return }
        do {
            let (status, mime, data) = try wire.handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": mime, "Content-Length": String(data.count)])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
private func passiveBody(_ request: URLRequest) throws -> [String: Any] {
    var data = request.httpBody ?? Data()
    if data.isEmpty, let stream = request.httpBodyStream {
        stream.open(); defer { stream.close() }; var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(contentsOf: buffer.prefix(n))
        }
    }
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}
private func passivePNG() throws -> Data {
    let context = try #require(CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 256, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.8, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
    let bytes = NSMutableData(), image = try #require(context.makeImage())
    let destination = try #require(CGImageDestinationCreateWithData(bytes, "public.png" as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil); #expect(CGImageDestinationFinalize(destination)); return bytes as Data
}
@Test func passiveTransportUsesExactOwnerAndPurposeWithoutPrivateURLFetch() async throws {
    let response = try passiveCurrent(), p = response.passive_session
    let bytes = try passivePNG()
    var root = try passiveOriginal(); root["passive_session"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(p))
    let payload = try JSONSerialization.data(withJSONObject: root)
    let wire = PassiveWire { request in
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-passive-token")
        #expect(request.value(forHTTPHeaderField: "Cache-Control") == "no-store")
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        if request.httpMethod == "GET" {
            let q = Dictionary(uniqueKeysWithValues: URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value ?? "") })
            #expect(Set(q.keys) == ["device_id", "client_type", "contract_version", "surface", "grant_id"])
            #expect(q["grant_id"] == response.grant_id && q["client_type"] == "ios" && q["device_id"] == "djconnect-ios-ABCDEF123456")
            #expect(request.url?.path == p.artwork[0].image_path)
            return (200, "image/png", bytes)
        }
        let body = try passiveBody(request)
        #expect(body["device_id"] as? String == "djconnect-ios-ABCDEF123456" && body["client_type"] as? String == "ios")
        #expect(body["session_id"] as? String == p.session_id)
        if body["surface"] as? String == "live_activity" { return (200, "application/json", payload) } // Deliberate wrong-purpose response.
        #expect(body["surface"] as? String == "widget")
        #expect(body["contract_version"] as? Int == 1 && body["text"] == nil && body["url"] == nil)
        if request.url?.path.hasSuffix("authorize") == true {
            #expect(Set(body.keys) == ["device_id", "client_type", "contract_version", "session_id", "surface", "enabled", "os_snapshot_cache", "locked_display"])
            #expect(body["os_snapshot_cache"] as? Bool == true && body["locked_display"] as? Bool == false)
        } else {
            #expect(Set(body.keys) == ["device_id", "client_type", "contract_version", "session_id", "surface", "grant_id"])
            #expect(body["grant_id"] as? String == response.grant_id)
        }
        return (200, "application/json", payload)
    }
    defer { wire.close() }
    let client = wire.client()
    _ = try await client.authorizePassiveSurface(sessionID: p.session_id, surface: .widget, enabled: true)
    _ = try await client.readPassiveSurface(sessionID: p.session_id, surface: .widget, grantID: response.grant_id)
    let image = try await client.passiveSurfaceImage(p.artwork[0], response: response)
    #expect(image.image.width == 64)
    await #expect(throws: DJConnectError.invalidResponse) {
        try await client.readPassiveSurface(sessionID: p.session_id, surface: .liveActivity, grantID: response.grant_id)
    }
}

@Test @MainActor func passiveOldImageCannotRestoreARevokedProfileAndNoConsentSurvivesNewModel() async throws {
    let model = PassiveSessionSurfaceModel(), r = try passiveCurrent(), image = try passivePNG()
    let services = PassiveSessionSurfaceModel.Services(available: { true }, authorize: { _, _, _ in r }, read: { _, _, _ in r }, image: { _, _ in
        try? await Task.sleep(for: .milliseconds(80)); return image
    })
    model.bind(owner: "A", sessionID: r.passive_session.session_id, foreground: true); await model.discover(services)
    let action = Task { await model.setEnabled(true, surface: .widget, services: services) }
    try await Task.sleep(for: .milliseconds(20))
    #expect(model.caches[.widget]?.projection.contribution != nil)
    model.bind(owner: nil, sessionID: nil, foreground: true)
    await action.value
    #expect(model.caches.isEmpty && !model.enabled(.widget))
    let restarted = PassiveSessionSurfaceModel()
    restarted.bind(owner: "A", sessionID: r.passive_session.session_id, foreground: true)
    await restarted.discover(services); restarted.refresh(services)
    #expect(restarted.caches.isEmpty && !restarted.enabled(.widget))
}


@Test func passiveGrantIsFullyRedactedAndOwnerHintNeverReencoded() throws {
    let grant = "abcdefghijklmnopqrstuvwx_1234567"
    let raw = "https://fixture.invalid/path?grant_id=\(grant)&surface=widget"
    #expect(!DJConnectLogRedactor.redactText(raw).contains(grant))
    #expect(!DJConnectLogRedactor.redactText("{\"grant_id\":\"\(grant)\"}").contains(grant))
    #expect(DJConnectLogRedactor.sanitizedJSONString(["grant_id": grant]).contains("[redacted]"))
    let json = #"{"event_type":"state_changed","session_id":"session-test","delivery_sequence":10,"payload":{"passive_surface":{"version":1,"session_id":"session-test","delivery_sequence":10,"invalidation_only":true}}}"#
    let event = try JSONDecoder().decode(DJConnectSessionBroadcastEvent.self, from: Data(json.utf8))
    #expect(event.payload.passiveSurfaceInvalidation?.validates(sessionID: "session-test") == true)
    #expect(event.payload.passiveSurfaceInvalidation?.validates(sessionID: "another-session") == false)
    #expect(!String(decoding: try JSONEncoder().encode(event), as: UTF8.self).contains("passive_surface"))
}

@Test @MainActor func passiveHintBurstOnlyRereadsExistingGrantOnceAndNeverAuthorizes() async throws {
    let model = PassiveSessionSurfaceModel(), r = try passiveCurrent()
    var reads = 0, authorizes = 0
    let services = PassiveSessionSurfaceModel.Services(available: { true }, authorize: { _, _, _ in authorizes += 1; return r },
        read: { _, _, _ in reads += 1; return r }, image: { _, _ in Data() })
    model.bind(owner: "A", sessionID: r.passive_session.session_id, foreground: true); await model.discover(services)
    for n in 1...20 { model.invalidate(sequence: n, services: services) }
    try await Task.sleep(for: .milliseconds(300))
    #expect(reads == 0 && authorizes == 0)
    await model.setEnabled(true, surface: .widget, services: services)
    for n in 21...40 { model.invalidate(sequence: n, services: services) }
    try await Task.sleep(for: .milliseconds(400))
    #expect(reads == 1 && authorizes == 1)
}

@Test @MainActor func passiveResumeRevalidatesOriginalGrantWithoutRestoringOldHistoryEpoch() async throws {
    let model = PassiveSessionSurfaceModel(), r = try passiveCurrent()
    var authorizes = 0, reads = 0
    let services = PassiveSessionSurfaceModel.Services(available: { true }, authorize: { _, _, _ in authorizes += 1; return r },
        read: { _, _, _ in reads += 1; return r }, image: { _, _ in Data() })
    model.bind(owner: "stable-core-binding", sessionID: r.passive_session.session_id, foreground: true)
    await model.discover(services); await model.setEnabled(true, surface: .widget, services: services)
    model.refresh(services); try await Task.sleep(for: .milliseconds(30))
    model.suspend()
    #expect(model.caches[.widget] != nil)
    model.pauseForRevalidation()
    #expect(model.caches.isEmpty && model.enabled(.widget))
    let before = reads
    model.bind(owner: "stable-core-binding", sessionID: r.passive_session.session_id, foreground: true)
    model.refresh(services)
    try await Task.sleep(for: .milliseconds(30))
    #expect(reads == before + 1 && authorizes == 1)
    #expect(model.caches[.widget] != nil)
    model.bind(owner: "new-core-binding", sessionID: r.passive_session.session_id, foreground: true)
    #expect(model.caches.isEmpty && !model.enabled(.widget))
}

@Test @MainActor func passiveAutomaticConfigurationAuthorizesOnceAndRevalidatesWithoutAnotherSwitch() async throws {
    let widget = try passiveCurrent(), activity = try passiveCurrent(surface: .liveActivity)
    let model = PassiveSessionSurfaceModel()
    var writes: [String] = [], reads = 0
    let services = PassiveSessionSurfaceModel.Services(available: { true }, authorize: { _, surface, enabled in
        writes.append(surface.rawValue + (enabled ? ":on" : ":off"))
        return enabled ? (surface == .widget ? widget : activity) : nil
    }, read: { _, surface, _ in reads += 1; return surface == .widget ? widget : activity }, image: { _, _ in Data() })
    await model.reconcileAutomatic(surfaces: [.widget, .liveActivity], services: services)
    #expect(writes.isEmpty)
    model.bind(owner: "A", sessionID: widget.passive_session.session_id, foreground: true)
    await model.reconcileAutomatic(surfaces: [.widget, .liveActivity], services: services)
    for _ in 0..<10 { await model.reconcileAutomatic(surfaces: [.widget, .liveActivity], services: services) }
    #expect(writes == ["widget:on", "live_activity:on"])
    model.suspend()
    model.bind(owner: "A", sessionID: widget.passive_session.session_id, foreground: true)
    await model.reconcileAutomatic(surfaces: [.widget, .liveActivity], services: services)
    model.refresh(services, force: true)
    try await Task.sleep(for: .milliseconds(30))
    #expect(reads == 2 && writes.count == 2)
    await model.reconcileAutomatic(surfaces: [.liveActivity], services: services)
    #expect(!model.enabled(.widget) && model.enabled(.liveActivity))
    #expect(writes.last == "widget:off")
    await model.reconcileAutomatic(surfaces: [.widget, .liveActivity], services: services)
    #expect(writes.last == "widget:on")
}

@Test @MainActor func passiveAutomaticUncertainAuthorizationIsNotReplayedByResumeOrTicks() async throws {
    let model = PassiveSessionSurfaceModel(), response = try passiveCurrent()
    var writes = 0
    let services = PassiveSessionSurfaceModel.Services(available: { true }, authorize: { _, _, _ in
        writes += 1; throw URLError(.timedOut)
    }, read: { _, _, _ in response }, image: { _, _ in Data() })
    model.bind(owner: "A", sessionID: response.passive_session.session_id, foreground: true)
    for _ in 0..<5 { await model.reconcileAutomatic(surfaces: [.widget], services: services) }
    model.suspend(); model.bind(owner: "A", sessionID: response.passive_session.session_id, foreground: true)
    await model.reconcileAutomatic(surfaces: [.widget], services: services)
    #expect(writes == 1 && model.caches.isEmpty)
    model.bind(owner: "B", sessionID: response.passive_session.session_id, foreground: true)
    await model.reconcileAutomatic(surfaces: [.widget], services: services)
    #expect(writes == 2)
}

@Test @MainActor func passiveAutomaticOSRemovalFencesLateImageAndRevokesImmediately() async throws {
    let model = PassiveSessionSurfaceModel(), response = try passiveCurrent(), png = try passivePNG()
    var disabled = 0
    let services = PassiveSessionSurfaceModel.Services(available: { true }, authorize: { _, _, enabled in
        if !enabled { disabled += 1; return nil }; return response
    }, read: { _, _, _ in response }, image: { _, _ in
        try? await Task.sleep(for: .milliseconds(80)); return png
    })
    model.bind(owner: "A", sessionID: response.passive_session.session_id, foreground: true)
    let preparation = Task { await model.reconcileAutomatic(surfaces: [.widget], services: services) }
    try await Task.sleep(for: .milliseconds(20))
    await model.reconcileAutomatic(surfaces: [], services: services)
    await preparation.value
    #expect(disabled == 1 && !model.enabled(.widget) && model.caches[.widget] == nil)
}

@Test @MainActor func passiveDiagnosticsIdentifyWidgetWithdrawalWithoutLeakingPrivateFieldsOrRetryingWrites() async throws {
    let response = try passiveCurrent(), model = PassiveSessionSurfaceModel()
    var events: [String] = [], writes = 0
    model.onDiagnostic = { events.append($0) }
    model.bind(owner: "SECRET_OWNER", sessionID: response.passive_session.session_id, foreground: true)
    let services = PassiveSessionSurfaceModel.Services(available: { true }, authorize: { _, _, _ in
        writes += 1; return response
    }, read: { _, _, _ in throw DJConnectError.routeMissing(message: "SECRET_SERVER_MESSAGE") }, image: { _, _ in Data() })
    await model.reconcileAutomatic(surfaces: [.widget], services: services)
    #expect(model.enabled(.widget) && model.caches[.widget] != nil)
    model.refresh(services, force: true)
    for _ in 0..<100 where model.busy(.widget) { await Task.yield() }
    #expect(!model.enabled(.widget) && model.caches[.widget] == nil)
    await model.reconcileAutomatic(surfaces: [.widget], services: services)
    #expect(writes == 1)
    #expect(events.contains("configuration widget=true live_activity=false"))
    #expect(events.contains("read_failed surface=widget withdraws=true reason=route_missing"))
    let log = events.joined()
    for forbidden in ["SECRET", response.grant_id, response.passive_session.session_id, response.passive_session.binding_id] {
        #expect(!log.contains(forbidden))
    }
}
