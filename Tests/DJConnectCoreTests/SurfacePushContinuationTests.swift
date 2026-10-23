import Foundation
import Testing
import CryptoKit
@testable import DJConnectCore

@Suite @MainActor struct SurfacePushContinuationTests {
    private let wall: Int64 = 1_700_000_000_000
    private let owner = UUID()
    private let mono = ContinuousClock.now
    private let operation = "018bcfe5-6800-7000-8000-000000000001"
    private let purpose = "djcpref_" + String(repeating: "A", count: 43)
    private func request(token: UInt8 = 1, operation: String? = nil) throws -> DJConnectSurfacePushRequest {
        try #require(.init(identity: .init(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Fixture", clientType: .ios, firmware: "4.0.0", platform: .ios),
            sessionID: "fixture-session", operationID: operation ?? self.operation, platform: "ios", osVersion: "26.0",
            target: ["instance_id":"fixture-widget", "app_bundle_id":"dev.djconnect.ios", "extension_bundle_id":"dev.djconnect.ios.track-insight-widget", "widget_kind":"DJConnectSessionWidget"],
            token: Data(repeating:token,count:32), environment: "sandbox",
            consent: ["background_read":true, "os_snapshot_cache":true, "locked_display":true, "external_push_content":false, "allow_remote_start":false], expected:nil))
    }
    private func attempt(token: UInt8 = 1, operation: String? = nil,
                         previous: DJConnectSurfacePushPurposePin? = nil,
                         wall: Int64? = nil, mono: ContinuousClock.Instant? = nil) throws -> DJConnectSurfacePushContextAttempt {
        try #require(.init(original:request(token:token,operation:operation), installation:"https://fixture.example", ownerEpoch:owner,
            previousPurpose:previous, nowMS:wall ?? self.wall, monotonicNow:mono ?? self.mono))
    }
    private func context(_ attempt: DJConnectSurfacePushContextAttempt, expiry: Int64? = nil,
                         submit: Int64? = nil, reference: String? = nil) throws -> Data {
        try JSONSerialization.data(withJSONObject:["success":true,"contract_version":2,"available":true,
            "context_handle":"djcctx_" + String(repeating:"A",count:43), "operation_id":attempt.operationID,
            "purpose_ref":reference ?? purpose,"expires_at_ms":expiry ?? wall + 28_800_000,
            "context_expires_at_ms":submit ?? attempt.startedMS + 30_000,"cache_policy":"private,no-store"])
    }
    private func registered(_ c: DJConnectSurfacePushContinuation, success: Bool = true) throws -> [String:Any] {
        var b: [String:Any] = ["contract_version":2,"context_handle":c.contextHandle,"operation_id":c.attempt.operationID,
            "purpose_ref":purpose,"success":success,"replayed":false,"operation":["phase":success ? "confirmed":"pending"],"registration":NSNull()]
        if success {
            b["registration"] = ["registration_id":"fixture-registration","generation":"fixture-generation","revision":1,"state":"registered",
                "expires_at_ms":c.purpose.originalExpiryMS,"token_role":"widget","platform":"ios","cache_policy":"private,no-store"]
            b["background_read"] = ["credential":"djcsurface_" + String(repeating:"A",count:43),"expires_at_ms":c.purpose.originalExpiryMS,
                "registration_id":"fixture-registration","scope":"exact_original_surface_read_only","cache_policy":"private,no-store"]
        }
        return b
    }
    @Test func contextAndRegisterRetainOriginalOperationTokenAndOwner() throws {
        let a = try attempt(), c = try a.admit(context(a),nowMS:wall,monotonicNow:mono)
        let q = try #require(JSONSerialization.jsonObject(with:a.contextBytes) as? [String:Any])
        #expect(Set(q.keys) == ["contract_version","device_id","client_type","session_id","operation_id"])
        #expect(q["operation_id"] as? String == operation && q["contract_version"] as? Int == 2)
        let register = try #require(JSONSerialization.jsonObject(with:c.registerBytes) as? [String:Any])
        #expect(register["operation_id"] as? String == operation && register["context_handle"] as? String == c.contextHandle)
        #expect(register["contract_version"] as? Int == 2)
        #expect(c.witness.ownerEpoch == owner && c.witness.purposeGeneration == purpose)
        #expect(c.witness.tokenDigest == Data(SHA256.hash(data:Data(repeating:1,count:32))))
    }
    @Test func tokenRotationAndWallRollbackKeepOriginalPurposeDeadlineExactly() throws {
        let a = try attempt(), first = try a.admit(context(a),nowMS:wall,monotonicNow:mono)
        let later = mono.advanced(by:.seconds(10)), rollback = wall - 500
        let b = try attempt(token:2,operation:"018bcfe5-6800-7000-8000-000000000002",previous:first.purpose,wall:rollback,mono:later)
        let second = try b.admit(context(b),nowMS:rollback,monotonicNow:later)
        #expect(first.purpose == second.purpose)
        #expect(first.witness.originalMonotonicDeadline == second.witness.originalMonotonicDeadline)
        #expect(first.witness.tokenDigest != second.witness.tokenDigest)
        #expect(first.witness.originalExpiryMS == second.witness.originalExpiryMS)
    }
    @Test func changedPurposeOrExpiryCannotRotateTheOriginalGrant() throws {
        let a = try attempt(), first = try a.admit(context(a),nowMS:wall,monotonicNow:mono)
        let b = try attempt(previous:first.purpose)
        #expect(throws:DJConnectError.self) { try b.admit(context(b,reference:"djcpref_" + String(repeating:"B",count:42) + "A"),nowMS:wall,monotonicNow:mono) }
        #expect(throws:DJConnectError.self) { try b.admit(context(b,expiry:first.purpose.originalExpiryMS+1),nowMS:wall,monotonicNow:mono) }
        #expect(DJConnectSurfacePushContextAttempt(original:try request(),installation:"https://other.example",ownerEpoch:owner,previousPurpose:first.purpose,nowMS:wall,monotonicNow:mono) == nil)
    }
    @Test func shortContextDeadlineDoesNotReplaceRegisteredPurposeLease() throws {
        let a = try attempt(), c = try a.admit(context(a),nowMS:wall,monotonicNow:mono)
        #expect(c.purpose.originalExpiryMS == wall + 28_800_000)
        #expect(!c.canSubmit(nowMS:wall+30_000,monotonicNow:mono.advanced(by:.seconds(30))))
        #expect(c.witness.originalMonotonicDeadline > mono.advanced(by:.seconds(30)))
        let good = try JSONSerialization.data(withJSONObject:registered(c))
        let admitted = try c.admitRegistration(good)
        #expect(admitted.registration?.expires_at_ms == c.purpose.originalExpiryMS)
        var wrong = try registered(c), receipt = wrong["registration"] as! [String:Any]
        receipt["expires_at_ms"] = c.contextExpiryMS; wrong["registration"] = receipt
        #expect(throws:DJConnectError.self) { try c.admitRegistration(JSONSerialization.data(withJSONObject:wrong)) }
    }
    @Test func contextBudgetIsOriginalEvenAfterLatencyOrMalformedLongWindow() throws {
        let a = try attempt()
        #expect(throws:DJConnectError.self) { try a.admit(context(a,submit:wall+90_000),nowMS:wall+1000,monotonicNow:mono.advanced(by:.seconds(31))) }
        let c = try a.admit(context(a,submit:wall+90_000),nowMS:wall,monotonicNow:mono)
        #expect(!c.canSubmit(nowMS:wall+1000,monotonicNow:mono.advanced(by:.seconds(30))))
        #expect(throws:DJConnectError.self) { try a.admit(context(a),nowMS:wall-1,monotonicNow:mono) }
    }
    @Test func registrationRequiresExactEchoedTripleAndClosedVariant() throws {
        let a = try attempt(), c = try a.admit(context(a),nowMS:wall,monotonicNow:mono)
        for key in ["context_handle","operation_id","purpose_ref"] {
            var b = try registered(c); b[key] = "wrong"
            #expect(throws:DJConnectError.self) { try c.admitRegistration(JSONSerialization.data(withJSONObject:b)) }
        }
        var extra = try registered(c); extra["unknown"] = true
        #expect(throws:DJConnectError.self) { try c.admitRegistration(JSONSerialization.data(withJSONObject:extra)) }
        let failed = try c.admitRegistration(JSONSerialization.data(withJSONObject:registered(c,success:false)))
        #expect(!failed.success && failed.background_read == nil)
        var forged = try registered(c,success:false); forged["background_read"] = (try registered(c))["background_read"]
        #expect(throws:DJConnectError.self) { try c.admitRegistration(JSONSerialization.data(withJSONObject:forged)) }
    }
    @Test func contextDoesNotAcceptMetadataOnlyLegacyOrUnexpectedAliases() throws {
        let a = try attempt()
        #expect(throws:DJConnectError.self) { try a.admit(Data("{\"success\":true,\"contract_version\":1,\"available\":true,\"expires_at_ms\":1700028800000,\"cache_policy\":\"private,no-store\"}".utf8),nowMS:wall,monotonicNow:mono) }
        var b = try #require(JSONSerialization.jsonObject(with:context(a)) as? [String:Any]); b["unknown"] = true
        #expect(throws:DJConnectError.self) { try a.admit(JSONSerialization.data(withJSONObject:b),nowMS:wall,monotonicNow:mono) }
    }
}
