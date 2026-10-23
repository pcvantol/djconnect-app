import Foundation
import Testing
@testable import DJConnectCore

@MainActor private final class SurfaceReadProbe {
    var body: [String: Any]
    let registration: DJConnectSurfacePushResponse
    let original: DJConnectSurfacePushWitness
    var now: Date
    var mono: ContinuousClock.Instant
    var currentOwner = true
    var foreground = true
    var calls = 0
    var onAuthority: (() -> Void)?
    var action: (() async throws -> DJConnectSurfacePushReadResponse)?

    init() throws {
        let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/surface-push-core-12675bc-http.json")
        let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        let cases = try #require(root["cases"] as? [[String: Any]])
        body = try #require(cases.first { $0["kind"] as? String == "read" && $0["status"] as? Int == 200 }?["response_body"] as? [String: Any])
        let response = try Self.decode(body)
        let registered = try #require(cases.first { row in
            guard row["kind"] as? String == "register", row["status"] as? Int == 200,
                  let result = row["response_body"] as? [String: Any] else { return false }
            return result["success"] as? Bool == true
        }?["response_body"])
        registration = try JSONDecoder().decode(DJConnectSurfacePushResponse.self, from: JSONSerialization.data(withJSONObject: registered))
        now = try #require(DJConnectHistoryEntry.date(response.passive_session.fields.observed_at)).addingTimeInterval(1)
        mono = ContinuousClock.now
        let expiry = Double(response.registration.expires_at_ms) / 1000
        original = .init(installation: "original-install", ownerEpoch: UUID(), session: response.passive_session.fields.session_id,
                         purposeGeneration: "original-owner-purpose-witness", targetInstance: "original-target",
                         platform: response.registration.platform, tokenRole: "widget", tokenDigest: Data([1]),
                         originalExpiryMS: response.registration.expires_at_ms,
                         originalMonotonicDeadline: mono.advanced(by: .seconds(expiry - now.timeIntervalSince1970)))
    }
    static func decode(_ object: [String: Any]) throws -> DJConnectSurfacePushReadResponse {
        try JSONDecoder().decode(DJConnectSurfacePushReadResponse.self, from: JSONSerialization.data(withJSONObject: object))
    }
    var services: DJConnectSurfaceBackgroundAdmission.Services {
        .init(isCurrent: { witness in
            self.onAuthority?()
            return self.currentOwner && witness == self.original
        }, canBootstrap: { $0 == self.original && self.foreground }, now: { self.now }, monotonicNow: { self.mono }, read: { read in
            #expect(read.credential == self.registration.background_read?.credential)
            #expect(read.registration_id == self.registration.registration?.registration_id)
            self.calls += 1
            if let action = self.action { return try await action() }
            return try Self.decode(self.body)
        })
    }
    func owner() throws -> DJConnectSurfaceBackgroundAdmission {
        try #require(DJConnectSurfaceBackgroundAdmission(original: original, registration: registration))
    }
    func frame(_ change: (inout [String: Any]) -> Void) throws {
        var frame = try #require(body["passive_session"] as? [String: Any]); change(&frame); body["passive_session"] = frame
    }
    func advance(_ seconds: Double) {
        now = now.addingTimeInterval(seconds); mono = mono.advanced(by: .seconds(seconds))
    }
}

@MainActor private final class PendingSurfaceRead {
    var continuation: CheckedContinuation<DJConnectSurfacePushReadResponse, Error>?
    func read() async throws -> DJConnectSurfacePushReadResponse {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func finish(_ response: DJConnectSurfacePushReadResponse) {
        continuation?.resume(returning: response); continuation = nil
    }
}

@Test @MainActor func originalSurfaceReadPinsActualCoreFrameWithoutEquatingGenerationDomains() async throws {
    let p = try SurfaceReadProbe(), owner = try p.owner()
    #expect(await owner.refresh(services: p.services) == nil && p.calls == 0)
    let accepted = try #require(await owner.bootstrap(services: p.services))
    #expect(accepted.registration == p.registration.registration?.coordinate)
    #expect(accepted.projection.fields.generation != accepted.registration.generation)
    #expect(accepted.projection.fields.generation != p.original.purposeGeneration)
    #expect(owner.state == .ready && p.calls == 1)
    #expect(await owner.bootstrap(services: p.services) == nil && p.calls == 1)
    p.foreground = false // Already-pinned reads do not borrow a new foreground grant.
    #expect(await owner.refresh(services: p.services) != nil && p.calls == 2)
}

@Test @MainActor func originalSurfaceReadCannotBootstrapWithoutOriginalForegroundAuthority() async throws {
    let p = try SurfaceReadProbe(), owner = try p.owner(); p.foreground = false
    #expect(await owner.bootstrap(services: p.services) == nil)
    #expect(owner.state == .withdrawn && p.calls == 0)
    p.foreground = true
    #expect(await owner.bootstrap(services: p.services) == nil && p.calls == 0)
}

@Test @MainActor func originalSurfaceReadRejectsChangedReceiptSessionOrReadContract() async throws {
    for change in ["id", "generation", "revision", "expiry", "platform", "role", "receipt-cache", "session", "version", "cache", "success"] {
        let p = try SurfaceReadProbe(), owner = try p.owner()
        var receipt = try #require(p.body["registration"] as? [String: Any])
        switch change {
        case "id": receipt["registration_id"] = "another-registration"
        case "generation": receipt["generation"] = "another-transport-generation"
        case "revision": receipt["revision"] = 2
        case "expiry": receipt["expires_at_ms"] = p.original.originalExpiryMS + 1
        case "platform": receipt["platform"] = "macos"
        case "role": receipt["token_role"] = "live_activity_update"
        case "receipt-cache": receipt["cache_policy"] = "public"
        case "session": try p.frame { $0["session_id"] = "other-session" }
        case "version": p.body["contract_version"] = 2
        case "cache": p.body["cache_policy"] = "public"
        default: p.body["success"] = false
        }
        p.body["registration"] = receipt
        #expect(await owner.bootstrap(services: p.services) == nil, Comment(rawValue: change))
        #expect(owner.state == .withdrawn)
    }
}

@Test @MainActor func originalSurfaceReadSuppressesLateOwnerForegroundWithdrawalAndCancellation() async throws {
    for change in ["owner", "foreground", "withdraw", "cancel", "wall-expiry", "monotonic-expiry"] {
        let p = try SurfaceReadProbe(), owner = try p.owner(), pending = PendingSurfaceRead()
        let response = try SurfaceReadProbe.decode(p.body)
        p.action = { try await pending.read() }
        let task = Task { await owner.bootstrap(services: p.services) }
        while pending.continuation == nil { await Task.yield() }
        switch change {
        case "owner": p.currentOwner = false
        case "foreground": p.foreground = false
        case "withdraw": owner.withdraw()
        case "cancel": task.cancel()
        case "wall-expiry": p.now = Date(timeIntervalSince1970: Double(p.original.originalExpiryMS) / 1000)
        default: p.mono = p.original.originalMonotonicDeadline
        }
        pending.finish(response)
        #expect(await task.value == nil, Comment(rawValue: change))
        #expect(owner.state == .withdrawn && owner.current(services: p.services) == nil)
    }
}

@Test @MainActor func originalSurfaceReadCannotRenewExpiredMonotonicLeaseWithLaggingWallClock() async throws {
    let p = try SurfaceReadProbe(), owner = try p.owner()
    let response = try SurfaceReadProbe.decode(p.body)
    let expiry = try #require(DJConnectHistoryEntry.date(response.passive_session.fields.expires_at))
    let pending = PendingSurfaceRead(); p.action = { try await pending.read() }
    let task = Task { await owner.bootstrap(services: p.services) }
    while pending.continuation == nil { await Task.yield() }
    p.mono = p.mono.advanced(by: .seconds(expiry.timeIntervalSince(p.now)))
    pending.finish(response)
    #expect(await task.value == nil && owner.state == .withdrawn)
}

@Test @MainActor func originalSurfaceReadDuplicateKeepsOriginalFrameAndDeadline() async throws {
    let p = try SurfaceReadProbe(), owner = try p.owner()
    let first = try #require(await owner.bootstrap(services: p.services))
    p.advance(10)
    try p.frame { $0["as_of"] = ISO8601DateFormatter().string(from: p.now) }
    let duplicate = try #require(await owner.refresh(services: p.services))
    #expect(duplicate.monotonicDeadline == first.monotonicDeadline)
    #expect(duplicate.projection.fields.as_of == first.projection.fields.as_of)
    p.mono = first.monotonicDeadline
    #expect(owner.current(services: p.services) == nil)
    #expect(owner.state == .ready) // Display expiry is not registration withdrawal.
}

@Test @MainActor func originalSurfaceReadRejectsReboundPinsAndAlteredOrRegressedSequence() async throws {
    for change in ["binding", "purpose", "same-sequence-change", "regression"] {
        let p = try SurfaceReadProbe(), owner = try p.owner()
        let first = try #require(await owner.bootstrap(services: p.services))
        try p.frame {
            switch change {
            case "binding": $0["binding_id"] = "another-binding"
            case "purpose": $0["generation"] = "another-purpose"
            case "same-sequence-change": $0["persona"] = "home_dj"; $0["presence"] = "music_only"
            default: $0["delivery_sequence"] = first.projection.fields.delivery_sequence - 1
            }
        }
        #expect(await owner.refresh(services: p.services) == nil, Comment(rawValue: change))
        #expect(owner.state == .withdrawn)
    }
}

@Test @MainActor func originalSurfaceReadNewSequenceCannotReanchorSameExpiryAfterClockRollback() async throws {
    let p = try SurfaceReadProbe(), owner = try p.owner()
    let first = try #require(await owner.bootstrap(services: p.services))
    p.mono = p.mono.advanced(by: .seconds(10)); p.now = p.now.addingTimeInterval(-0.5)
    try p.frame { $0["delivery_sequence"] = first.projection.fields.delivery_sequence + 1; $0["presence"] = "music_only" }
    let next = try #require(await owner.refresh(services: p.services))
    #expect(next.monotonicDeadline == first.monotonicDeadline)
}

@Test @MainActor func originalSurfaceReadAcceptsFreshSequenceAfterProjectionExpiresWithoutNewRegistration() async throws {
    let p = try SurfaceReadProbe(), owner = try p.owner()
    let first = try #require(await owner.bootstrap(services: p.services))
    let frameExpiry = try #require(DJConnectHistoryEntry.date(first.projection.fields.expires_at))
    p.advance(frameExpiry.timeIntervalSince(p.now) + 1)
    #expect(owner.current(services: p.services) == nil && owner.state == .ready)
    try p.frame {
        $0["state"] = "stale"; $0["delivery_sequence"] = first.projection.fields.delivery_sequence + 1
        $0["as_of"] = ISO8601DateFormatter().string(from: p.now)
    }
    #expect(await owner.refresh(services: p.services) == nil && owner.state == .ready)
    try p.frame {
        $0["state"] = "active"; $0["delivery_sequence"] = first.projection.fields.delivery_sequence + 2
        $0["observed_at"] = ISO8601DateFormatter().string(from: p.now)
        $0["as_of"] = $0["observed_at"]
        $0["expires_at"] = ISO8601DateFormatter().string(from: p.now.addingTimeInterval(120))
    }
    #expect(await owner.refresh(services: p.services) != nil && p.calls == 3)
}

@Test @MainActor func originalSurfaceReadAuthorityCallbackCannotResurrectWithdrawnPin() async throws {
    let p = try SurfaceReadProbe(), owner = try p.owner()
    p.onAuthority = { if p.calls > 0 { owner.withdraw() } }
    #expect(await owner.bootstrap(services: p.services) == nil && owner.state == .withdrawn)
    let q = try SurfaceReadProbe(), cached = try q.owner()
    #expect(await cached.bootstrap(services: q.services) != nil)
    q.onAuthority = { cached.withdraw() }
    #expect(cached.current(services: q.services) == nil && cached.state == .withdrawn)
}

@Test @MainActor func originalSurfaceReadTransientFailurePreservesOnlyOriginalPinWithoutRetry() async throws {
    let p = try SurfaceReadProbe(), owner = try p.owner()
    let first = try #require(await owner.bootstrap(services: p.services))
    p.action = { throw URLError(.networkConnectionLost) }
    let cached = try #require(await owner.refresh(services: p.services))
    #expect(p.calls == 2 && cached.monotonicDeadline == first.monotonicDeadline)
    p.action = { throw DJConnectError.authStale(statusCode: 403, message: nil) }
    #expect(await owner.refresh(services: p.services) == nil && owner.state == .withdrawn)
    let q = try SurfaceReadProbe(), initial = try q.owner(); q.action = { throw URLError(.timedOut) }
    #expect(await initial.bootstrap(services: q.services) == nil && initial.state == .withdrawn && q.calls == 1)
}

@Test @MainActor func originalSurfaceReadPerFieldMonotonicExpiryCannotHideBehindFreshOuterFrame() async throws {
    for field in ["contribution", "now_playing"] {
        let p = try SurfaceReadProbe(), owner = try p.owner()
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fieldExpiry = p.now.addingTimeInterval(1)
        try p.frame { frame in
            var content: [String: Any]
            if field == "now_playing" {
                content = ["item_id":"fixture-track", "subject_uri":"spotify:track:AAAAAAAAAAAAAAAAAAAAAA",
                           "track":"Fixture", "artist":"Artist", "album":"Album",
                           "source_url":"https://open.spotify.com/track/AAAAAAAAAAAAAAAAAAAAAA",
                           "attribution":["provider":"Spotify"], "usage_basis":"spotify_temporary_passive_metadata",
                           "observed_at":frame["observed_at"]!]
            } else {
                content = ["moment_id":"fixture-moment", "published_at":frame["observed_at"]!, "text":"Fixture text",
                           "persona":"home_dj", "source_attribution":[:], "usage_basis":"runtime_authored_direction",
                           "rights":["passive_cache":true,"os_snapshot":true,"external_relay":false,"watch_replication":false]]
            }
            content["expires_at"] = formatter.string(from: fieldExpiry)
            frame[field] = content
            frame[field == "now_playing" ? "now_playing_status" : "contribution_status"] = ["state":"available", "reason":"qualified"]
        }
        let pending = PendingSurfaceRead(); p.action = { try await pending.read() }
        let response = try SurfaceReadProbe.decode(p.body)
        #expect(response.passive_session.isCurrent(at: p.now, originalGrantExpiry: p.now.addingTimeInterval(600)))
        let task = Task { await owner.bootstrap(services: p.services) }
        while pending.continuation == nil { await Task.yield() }
        let originalExpiry = try #require(field == "contribution" ? response.passive_session.fields.contribution?.expires_at : response.passive_session.fields.now_playing?.expires_at)
        let exactExpiry = try #require(DJConnectHistoryEntry.date(originalExpiry))
        p.mono = p.mono.advanced(by: .seconds(exactExpiry.timeIntervalSince(p.now))) // Exact equality; wall deliberately lags.
        pending.finish(response)
        #expect(await task.value == nil && owner.state == .withdrawn, Comment(rawValue: field))
    }
}

@Test @MainActor func originalSurfaceReadDoesNotIssueConcurrentOrAlreadyCancelledRequests() async throws {
    let p = try SurfaceReadProbe(), owner = try p.owner(), pending = PendingSurfaceRead()
    p.action = { try await pending.read() }
    let task = Task { await owner.bootstrap(services: p.services) }
    while pending.continuation == nil { await Task.yield() }
    #expect(await owner.bootstrap(services: p.services) == nil)
    #expect(await owner.refresh(services: p.services) == nil && p.calls == 1)
    pending.finish(try SurfaceReadProbe.decode(p.body))
    #expect(await task.value != nil)
    let q = try SurfaceReadProbe(), cancelled = try q.owner()
    let cancelledTask = Task { await cancelled.bootstrap(services: q.services) }
    cancelledTask.cancel()
    #expect(await cancelledTask.value == nil && q.calls == 0)
}
