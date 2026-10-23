import Foundation
import Testing
@testable import DJConnectCore
@MainActor final class Pending {
 var continuation: CheckedContinuation<DJConnectSurfacePushResponse,Error>?
 func read() async throws -> DJConnectSurfacePushResponse {
  try await withCheckedThrowingContinuation { continuation = $0 }
 }
 func finish(_ response: DJConnectSurfacePushResponse) { continuation?.resume(returning:response); continuation=nil }
}
private enum SurfacePushProbe {
 @MainActor static func response(revision: Int = 1, generation: String = "generation-A", expiry: Int64 = 120000,
                                 credential: String = "djcsurface_" + String(repeating:"a",count:43)) throws -> DJConnectSurfacePushResponse {
  let value:[String:Any] = ["success":true,"replayed":false,"operation":["phase":"confirmed"],
   "registration":["registration_id":"registration-A","generation":generation,"revision":revision,
    "state":"registered","expires_at_ms":expiry,"token_role":"widget","platform":"macos","cache_policy":"private,no-store"],
   "background_read":["credential":credential,"expires_at_ms":expiry,"registration_id":"registration-A",
    "scope":"exact_original_surface_read_only","cache_policy":"private,no-store"]]
  return try JSONDecoder().decode(DJConnectSurfacePushResponse.self,from:JSONSerialization.data(withJSONObject:value))
 }
 @MainActor static func witness(epoch:UUID = UUID(), token:UInt8 = 1, deadline:ContinuousClock.Instant? = nil) -> DJConnectSurfacePushWitness {
  .init(installation:"install-A",ownerEpoch:epoch,session:"session-A",purposeGeneration:"purpose-A",
        targetInstance:"target-A",platform:"macos",tokenRole:"widget",tokenDigest:Data([token]),originalExpiryMS:120000, originalMonotonicDeadline: deadline ?? ContinuousClock.now.advanced(by:.seconds(20)))
 }
 @MainActor static func run() async throws {
  var passed=0
  var mono=ContinuousClock.now
  func check(_ condition:Bool,_ name:String) { #expect(condition, Comment(rawValue: name)); passed += 1 }
  let first=witness(); var current=true; var now:Int64=100000; var writes=0
  var published:DJConnectSurfaceBackgroundRead?; var calls=0; var receivedExpected:DJConnectSurfacePushCoordinate?
  var reply=try response()
  let service=DJConnectSurfacePushRegistration.Services(isCurrent:{_ in current},nowMS:{now},monotonicNow:{mono},register:{_,expected in
   calls += 1; receivedExpected=expected; return reply
  },revoke:{_,_ in writes += 1;return reply},publishBackgroundRead:{published=$0})
  let owner=DJConnectSurfacePushRegistration()
  await owner.register(first,services:service)
  check(owner.state == .registered && published != nil && calls == 1,"valid exact registration publishes scoped credential")
  await owner.register(first,services:service)
  check(calls == 1,"same admitted token does not replay write")
  reply=try response(revision:2,generation:"generation-A")
  await owner.register(witness(epoch:first.ownerEpoch,token:2,deadline:first.originalMonotonicDeadline),services:service)
  check(owner.coordinate?.revision == 2 && receivedExpected?.revision == 1,"rotation carries original CAS coordinate")
  await owner.register(witness(),services:service)
  check(calls == 2,"different owner cannot rotate predecessor")
  await owner.withdraw(services:service)
  check(owner.state == .withdrawn && published == nil && writes == 1,"withdraw scrubs then revokes original registration")
  let invalid=DJConnectSurfacePushRegistration(); reply=try response(credential:"ordinary-app-bearer")
  await invalid.register(first,services:service)
  check(invalid.state == .outcomeUnknown && published == nil,"ordinary app bearer cannot become background credential")
  let before=calls; await invalid.register(first,services:service)
  check(calls == before,"unknown write outcome is not automatically retried")
  let expired=DJConnectSurfacePushRegistration(); reply=try response(expiry:130000)
  await expired.register(first,services:service)
  check(expired.state == .outcomeUnknown && published == nil,"server cannot extend original purpose expiry")
  now=120000
  let notDispatched=DJConnectSurfacePushRegistration();let beforeExpiry=calls
  await notDispatched.register(first,services:service)
  check(calls == beforeExpiry,"equality expiry blocks before network")
  now=100000; current=true
  let pending=Pending();let late=DJConnectSurfacePushRegistration()
  let delayed=DJConnectSurfacePushRegistration.Services(isCurrent:{_ in current},nowMS:{now},monotonicNow:{mono},register:{_,_ in try await pending.read()},
   revoke:{_,_ in writes += 1;return reply},publishBackgroundRead:{published=$0})
  let task=Task { await late.register(first,services:delayed) }
  while pending.continuation == nil { await Task.yield() }
  current=false;pending.finish(try response());await task.value
  check(late.state == .withdrawn && published == nil,"late success after owner loss cannot publish")
  current=true
  let pending2=Pending();let withdrawn=DJConnectSurfacePushRegistration()
  let delayed2=DJConnectSurfacePushRegistration.Services(isCurrent:{_ in current},nowMS:{now},monotonicNow:{mono},register:{_,_ in try await pending2.read()},
   revoke:{_,_ in writes += 1;return reply},publishBackgroundRead:{published=$0})
  let task2=Task { await withdrawn.register(first,services:delayed2) }
  while pending2.continuation == nil { await Task.yield() }
  await withdrawn.withdraw(services:delayed2);pending2.finish(try response());await task2.value
  check(withdrawn.state == .withdrawn && published == nil,"late registration ACK cannot resurrect explicit withdrawal")
  let pending3=Pending();let short=DJConnectSurfacePushRegistration()
  let delayed3=DJConnectSurfacePushRegistration.Services(isCurrent:{_ in current},nowMS:{now},monotonicNow:{mono},register:{_,_ in try await pending3.read()},
   revoke:{_,_ in writes += 1;return reply},publishBackgroundRead:{published=$0})
  let task3=Task { await short.register(first,services:delayed3) }
  while pending3.continuation == nil { await Task.yield() }
  mono=first.originalMonotonicDeadline;pending3.finish(try response());await task3.value
  check(short.state == .withdrawn && published == nil,"original monotonic equality expiry rejects despite unchanged wall time")
  mono=ContinuousClock.now
  for poison in [0,-1,Int.max,9_007_199_254_740_991] {
   let poisoned=DJConnectSurfacePushRegistration();reply=try response(revision:poison)
   await poisoned.register(first,services:service)
   check(poisoned.state == .outcomeUnknown && published == nil,"invalid revision \(poison) rejected before adoption")
  }
  let upper=DJConnectSurfacePushRegistration();reply=try response(revision:9_007_199_254_740_990)
  await upper.register(first,services:service)
  let beforeUpper=calls
  await upper.register(witness(epoch:first.ownerEpoch,token:2,deadline:first.originalMonotonicDeadline),services:service)
  check(calls == beforeUpper,"highest valid revision cannot overflow or dispatch invalid next revision")
  let cancelled=DJConnectSurfacePushRegistration();reply=try response();let beforeCancel=calls
  let cancelledTask=Task { await cancelled.register(first,services:service) }
  cancelledTask.cancel();await cancelledTask.value
  check(calls == beforeCancel && cancelled.state == .idle,"already cancelled registration makes zero service calls")
  let revokeCancelled=DJConnectSurfacePushRegistration();await revokeCancelled.register(first,services:service)
  let beforeRevoke=writes
  let revokeTask=Task { await revokeCancelled.withdraw(services:service) }
  revokeTask.cancel();await revokeTask.value
  check(writes == beforeRevoke && published == nil && revokeCancelled.state == .withdrawn,"cancelled revoke still scrubs locally and makes zero writes")
  let callbackCancelled=DJConnectSurfacePushRegistration();let beforeCallback=calls
  let callbackService=DJConnectSurfacePushRegistration.Services(isCurrent:{_ in current},nowMS:{now},monotonicNow:{mono},
   register:{_,_ in calls += 1;return reply},revoke:{_,_ in writes += 1;return reply},
   publishBackgroundRead:{ value in published=value; withUnsafeCurrentTask { $0?.cancel() } })
  let callbackTask=Task { await callbackCancelled.register(first,services:callbackService) }
  await callbackTask.value
  check(calls == beforeCallback && callbackCancelled.state == .withdrawn,"cancellation from pre-dispatch callback blocks service effect")
  let callbackPost=DJConnectSurfacePushRegistration();var checks=0
  let callbackPostService=DJConnectSurfacePushRegistration.Services(isCurrent:{_ in
    checks += 1;if checks == 3 { withUnsafeCurrentTask { $0?.cancel() } };return true
   },nowMS:{now},monotonicNow:{mono},register:{_,_ in calls += 1;return reply},
   revoke:{_,_ in writes += 1;return reply},publishBackgroundRead:{published=$0})
  let callbackPostTask=Task { await callbackPost.register(first,services:callbackPostService) }
  await callbackPostTask.value
  check(callbackPost.state == .withdrawn && published == nil,"post-ACK authority callback cancellation cannot publish")
  print("TOTAL \(passed) PASS; synthetic injected services; no HTTP/APNs/device effects")
 }
}

@Test @MainActor func surfacePushRegistrationUsesOriginalAuthorityAndRejectsLateEffects() async throws {
    try await SurfacePushProbe.run()
}

private func surfaceActualGolden() throws -> [[String: Any]] {
    let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/surface-push-core-12675bc-http.json")
    let data = try Data(contentsOf: path)
    let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    return try #require(root["cases"] as? [[String: Any]])
}

@Test func surfacePushActualCoreResponsesDecodeWithoutInventedOperationOrGeneration() throws {
    let cases = try surfaceActualGolden()
    #expect(cases.count == 26)
    var receipts: [DJConnectSurfacePushResponse] = []
    for item in cases where item["kind"] as? String == "register" && item["status"] as? Int == 200 {
        let data = try JSONSerialization.data(withJSONObject: #require(item["response_body"]))
        let response = try JSONDecoder().decode(DJConnectSurfacePushResponse.self, from: data)
        receipts.append(response)
        if response.success {
            #expect(response.operation.phase == "confirmed")
            let registration = try #require(response.registration)
            #expect(registration.coordinate.isValid && response.background_read?.matches(registration) == true)
        } else { #expect(response.operation.phase == "unknown" && response.background_read == nil) }
    }
    #expect(receipts.count == 6)
    #expect(receipts[0].registration?.generation == receipts[2].registration?.generation)
    #expect(receipts[2].registration?.revision == 2)
    #expect(receipts[0].registration?.expires_at_ms == receipts[2].registration?.expires_at_ms)
}

@Test func surfaceBackgroundV2OriginalReadCannotBecomeForegroundV1OrRenewObservation() throws {
    let cases = try surfaceActualGolden()
    let body = try #require(cases[15]["response_body"] as? [String: Any])
    let data = try JSONSerialization.data(withJSONObject: body)
    let response = try JSONDecoder().decode(DJConnectSurfacePushReadResponse.self, from: data)
    let original = response.passive_session
    #expect(!original.fields.isValid) // v1 stays closed to v2.
    let observed = try #require(DJConnectHistoryEntry.date(original.fields.observed_at))
    let expiry = try #require(DJConnectHistoryEntry.date(original.fields.expires_at))
    let grant = Date(timeIntervalSince1970: Double(response.registration.expires_at_ms) / 1000)
    #expect(original.isCurrent(at: observed.addingTimeInterval(1), originalGrantExpiry: grant))
    #expect(!original.isCurrent(at: expiry, originalGrantExpiry: grant))
    #expect(!original.isCurrent(at: observed.addingTimeInterval(1), originalGrantExpiry: observed))
    let encoded = try JSONEncoder().encode(original)
    let roundtrip = try JSONDecoder().decode(DJConnectBackgroundSession.self, from: encoded)
    #expect(roundtrip.semanticDigest == original.semanticDigest)
    for mutation in ["version", "state", "read-clock", "status", "sequence", "artwork"] {
        var bad = try #require(body["passive_session"] as? [String: Any])
        switch mutation {
        case "version": bad["schema_version"] = 1
        case "state": bad["state"] = "future_state"
        case "read-clock": bad["as_of"] = "2099-01-01T00:00:00Z"
        case "status": bad["now_playing_status"] = ["state":"available","reason":"qualified"]
        case "sequence": bad["delivery_sequence"] = Int.max
        default: bad["artwork"] = [["unknown":"not-an-authorized-asset"]]
        }
        let bytes = try JSONSerialization.data(withJSONObject: bad)
        let parsed = try? JSONDecoder().decode(DJConnectBackgroundSession.self, from: bytes)
        #expect(parsed?.isCurrent(at: observed.addingTimeInterval(1), originalGrantExpiry: grant) != true)
    }
}

@Test func surfaceBackgroundV2NeverCopiesExpiredOrFutureFieldsFromFreshFrame() throws {
    let cases = try surfaceActualGolden()
    let body = try #require(cases[15]["response_body"] as? [String: Any])
    let base = try #require(body["passive_session"] as? [String: Any])
    let observed = try #require((base["observed_at"] as? String).flatMap(DJConnectHistoryEntry.date))
    let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let grant = observed.addingTimeInterval(120)
    for field in ["contribution", "now_playing"] {
        var frame = base
        var content: [String: Any]
        if field == "now_playing" {
            content = ["item_id":"fixture-track", "subject_uri":"spotify:track:AAAAAAAAAAAAAAAAAAAAAA",
                "track":"Fixture", "artist":"Artist", "album":"Album", "source_url":"https://open.spotify.com/track/AAAAAAAAAAAAAAAAAAAAAA",
                "attribution":["provider":"Spotify"], "usage_basis":"spotify_temporary_passive_metadata",
                "observed_at":formatter.string(from: observed)]
        } else {
            content = ["moment_id":"fixture-moment", "published_at":formatter.string(from: observed), "text":"Fixture text",
                "persona":"home_dj", "source_attribution":[:], "usage_basis":"runtime_authored_direction",
                "rights":["passive_cache":true,"os_snapshot":true,"external_relay":false,"watch_replication":false]]
        }
        let statusKey = field == "now_playing" ? "now_playing_status" : "contribution_status"
        frame[statusKey] = ["state":"available", "reason":"qualified"]
        content["expires_at"] = formatter.string(from: observed.addingTimeInterval(1))
        frame[field] = content
        func decode(_ value: [String: Any]) throws -> DJConnectBackgroundSession {
            try JSONDecoder().decode(DJConnectBackgroundSession.self, from: JSONSerialization.data(withJSONObject: value))
        }
        let original = try decode(frame)
        #expect(original.isCurrent(at: observed.addingTimeInterval(0.5), originalGrantExpiry: grant))
        #expect(!original.isCurrent(at: observed.addingTimeInterval(1), originalGrantExpiry: grant))
        #expect(!original.isCurrent(at: observed.addingTimeInterval(2), originalGrantExpiry: grant))
        frame["as_of"] = formatter.string(from: observed.addingTimeInterval(2))
        #expect(try !decode(frame).isCurrent(at: observed.addingTimeInterval(2), originalGrantExpiry: grant))
        content[field == "now_playing" ? "observed_at" : "published_at"] = formatter.string(from: observed.addingTimeInterval(5))
        content["expires_at"] = formatter.string(from: observed.addingTimeInterval(20))
        frame[field] = content
        #expect(try !decode(frame).isCurrent(at: observed.addingTimeInterval(2), originalGrantExpiry: grant))
    }
}
