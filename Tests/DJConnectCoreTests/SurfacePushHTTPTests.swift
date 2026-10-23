import Foundation
import Testing
@testable import DJConnectCore

private final class SurfacePushHTTPWire: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) static private var requests: [URLRequest] = []
    nonisolated(unsafe) static private var response = Data()
    nonisolated(unsafe) static private var code = 200
    nonisolated(unsafe) static private var headerPatch: [String:String] = [:]
    static func setup(_ data: Data, code: Int = 200, headers: [String:String] = [:]) {
        lock.withLock { requests = [];response = data;Self.code = code;headerPatch = headers }
    }
    static var captured: [URLRequest] { lock.withLock { requests } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var captured = request
        if captured.httpBody == nil, let stream = captured.httpBodyStream {
            stream.open(); defer { stream.close() }; var bytes = Data(); var buffer = [UInt8](repeating:0,count:2048)
            while true {
                let count = stream.read(&buffer,maxLength:buffer.count)
                if count <= 0 { break }; bytes.append(contentsOf:buffer.prefix(count))
                if bytes.count > 16384 { break }
            }
            captured.httpBody = bytes
        }
        let (body,code,patch) = Self.lock.withLock { Self.requests.append(captured);return (Self.response,Self.code,Self.headerPatch) }
        var headers = ["Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store","Referrer-Policy":"no-referrer","X-Content-Type-Options":"nosniff"]
        headers.merge(patch) { _, new in new }
        client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:code,httpVersion:nil,headerFields:headers)!,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:body);client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
private func pushHTTPFixture(_ kind: String) throws -> [String:Any] {
    let url = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/surface-push-core-12675bc-http.json")
    let root = try #require(JSONSerialization.jsonObject(with:Data(contentsOf:url)) as? [String:Any])
    return try #require((root["cases"] as? [[String:Any]])?.first { row in
        row["kind"] as? String == kind && row["status"] as? Int == 200
    })
}
private func pushHTTPConfig() -> URLSessionConfiguration {
    let c = URLSessionConfiguration.ephemeral;c.protocolClasses = [SurfacePushHTTPWire.self]
    c.httpAdditionalHeaders = ["Authorization":"Bearer forbidden-ambient-app-token","X-Ambient-Identity":"forbidden"]
    return c
}
@Suite(.serialized) @MainActor struct SurfacePushHTTPTests {
    private func client() -> DJConnectClient {
        let s = URLSession(configuration:pushHTTPConfig())
        return DJConnectClient(baseURL:URL(string:"http://127.0.0.1:18766")!,
            identity:.init(deviceID:"djconnect-ios-ABCDEF123456",deviceName:"Fixture",clientType:.ios,firmware:"4.0.0",platform:.ios),
            tokenStore:DJConnectInMemoryTokenStore(token:"paired-fixture-token"),session:s)
    }
    @Test func backgroundReadUsesOnlyOriginalSeparateCredentialAndClosedRequest() async throws {
        let fixture = try pushHTTPFixture("read"), registered = try pushHTTPFixture("register")
        let registration = try JSONDecoder().decode(DJConnectSurfacePushResponse.self,from:JSONSerialization.data(withJSONObject:registered["response_body"]!))
        let read = try #require(registration.background_read)
        SurfacePushHTTPWire.setup(try JSONSerialization.data(withJSONObject:fixture["response_body"]!))
        let wire = try DJConnectSurfaceBackgroundHTTP(baseURL:URL(string:"http://127.0.0.1:18766")!,configuration:pushHTTPConfig(),nowMS:{0})
        let result = try await wire.read(read,isCurrent:{true})
        #expect(result.success && result.registration.registration_id == read.registration_id)
        let request = try #require(SurfacePushHTTPWire.captured.first)
        #expect(SurfacePushHTTPWire.captured.count == 1)
        #expect(request.url?.path == "/api/djconnect/v1/push/surface/read" && request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField:"Authorization") == "Bearer " + read.credential)
        #expect(request.value(forHTTPHeaderField:"X-Ambient-Identity") == nil)
        #expect(request.value(forHTTPHeaderField:"X-DJConnect-Device-ID") == nil)
        let requestBytes = try #require(request.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with:requestBytes) as? [String:Any])
        #expect(Set(object.keys) == ["contract_version","registration_id"])
    }
    @Test func pairedRegistrationMatchesOriginalCoreRequestWithoutRetryOrRoleCoercion() async throws {
        let fixture = try pushHTTPFixture("register"), raw = try #require(fixture["request_json"] as? [String:Any])
        let c = client()
        let request = try #require(DJConnectSurfacePushRequest(identity:c.identity,sessionID:raw["session_id"] as! String,
            operationID:raw["operation_id"] as! String,platform:"ios",osVersion:"26.0",target:raw["target"] as! [String:String],
            token:Data(repeating:0xaa,count:32),environment:"sandbox",consent:raw["consent"] as! [String:Bool],expected:nil))
        let object = try #require(JSONSerialization.jsonObject(with:request.bytes) as? NSDictionary)
        #expect(object.isEqual(to:raw))
        SurfacePushHTTPWire.setup(try JSONSerialization.data(withJSONObject:fixture["response_body"]!))
        #expect(try await c.registerSurfacePush(request,isCurrent:{true}).success)
        #expect(SurfacePushHTTPWire.captured.count == 1)
        #expect(SurfacePushHTTPWire.captured[0].value(forHTTPHeaderField:"Authorization") == "Bearer paired-fixture-token")
        #expect(SurfacePushHTTPWire.captured[0].value(forHTTPHeaderField:"X-Ambient-Identity") == nil)
        SurfacePushHTTPWire.setup(Data("{}".utf8),code:503)
        await #expect(throws:(any Error).self) { _ = try await c.registerSurfacePush(request,isCurrent:{true}) }
        #expect(SurfacePushHTTPWire.captured.count == 1)
        SurfacePushHTTPWire.setup(Data("{}".utf8))
        await #expect(throws:(any Error).self) { _ = try await c.registerSurfacePush(request,isCurrent:{false}) }
        #expect(SurfacePushHTTPWire.captured.isEmpty)
    }
    @Test func contextAndStatusAreMetadataOnlyAndDoNotRegister() async throws {
        let c = client()
        for kind in ["context","status"] {
            let fixture = try pushHTTPFixture(kind)
            SurfacePushHTTPWire.setup(try JSONSerialization.data(withJSONObject:fixture["response_body"]!))
            if kind == "context" { _ = try await c.surfacePushContext(sessionID:"synthetic-session",isCurrent:{true}) }
            else {
                let r = fixture["response_body"] as! [String:Any], registration = r["registration"] as! [String:Any]
                _ = try await c.surfacePushStatus(sessionID:"synthetic-session",registrationID:registration["registration_id"] as! String,isCurrent:{true})
            }
            #expect(SurfacePushHTTPWire.captured.count == 1 && SurfacePushHTTPWire.captured[0].url?.lastPathComponent == kind)
        }
    }
    @Test func responsePrivacyEncodingAndSizeFailuresNeverRetry() async throws {
        let c = client()
        for patch in [["Cache-Control":"public"],["Content-Encoding":"gzip"],["Content-Type":"text/html"],["Referrer-Policy":"unsafe-url"]] {
            SurfacePushHTTPWire.setup(Data("{}".utf8),headers:patch)
            await #expect(throws:(any Error).self) { _ = try await c.surfacePushContext(sessionID:"synthetic-session",isCurrent:{true}) }
            #expect(SurfacePushHTTPWire.captured.count == 1)
        }
        SurfacePushHTTPWire.setup(Data(repeating:32,count:65537))
        await #expect(throws:(any Error).self) { _ = try await c.surfacePushContext(sessionID:"synthetic-session",isCurrent:{true}) }
        #expect(SurfacePushHTTPWire.captured.count == 1)
    }
    @Test func strictWireRejectsDecodedDuplicateKeysAmbiguousNumbersAndDeepObjects() throws {
        for body in [#"{"success":true,"\u0073uccess":false}"#, #"{"x":{"id":1,"id":2}}"#, #"{"x":[{"id":1,"id":2}]}"#,
                     #"{"x":9007199254740992}"#, #"{"x":1.0}"#, #"{"x":1e2}"#, #"{"x":01}"#, #"{"x":"\ud800"}"#,
                     String(repeating:"{\"x\":",count:18)+"null"+String(repeating:"}",count:18)] {
            #expect(throws:(any Error).self) { try DJConnectSurfacePushJSON.validate(Data(body.utf8)) }
        }
        for kind in ["register","context","status","read","revoke"] {
            try DJConnectSurfacePushJSON.validate(JSONSerialization.data(withJSONObject:pushHTTPFixture(kind)["response_body"]!))
        }
    }
}

@MainActor private final class SurfaceHTTPAuthority { var current = true }
extension SurfacePushHTTPTests {
    @Test func closedRequestRejectsUnconsentedRolesStartAndInvalidNativeTargets() throws {
        let raw = try #require(pushHTTPFixture("register")["request_json"] as? [String:Any])
        let identity = DJConnectIdentity(deviceID:"djconnect-ios-ABCDEF123456",deviceName:"Fixture",clientType:.ios,firmware:"4.0.0",platform:.ios)
        let target = raw["target"] as! [String:String], consent = raw["consent"] as! [String:Bool]
        func request(_ t: [String:String], _ c: [String:Bool], platform: String = "ios", version: String = "26.0", token: Data = Data(repeating:1,count:32)) -> DJConnectSurfacePushRequest? {
            .init(identity:identity,sessionID:raw["session_id"] as! String,operationID:raw["operation_id"] as! String,
                  platform:platform,osVersion:version,target:t,token:token,environment:"sandbox",consent:c,expected:nil)
        }
        #expect(request(target,consent) != nil)
        #expect(request(target,consent,version:"25.0") == nil)
        #expect(request(target,consent,platform:"watchos") == nil)
        #expect(request(target,consent,token:Data([1])) == nil)
        for (flag,value) in [("external_push_content",true),("allow_remote_start",true),("background_read",false),("os_snapshot_cache",false)] {
            var c = consent;c[flag] = value;#expect(request(target,c) == nil)
        }
        let activity = ["instance_id":"original-presentation","app_bundle_id":"dev.djconnect.ios","activity_id":"original-activity","attributes_type":"DJConnectSessionLiveActivityAttributes"]
        #expect(request(activity,consent) == nil) // Widget consent never becomes Activity export consent.
        var export = consent; export["locked_display"] = true;export["external_push_content"] = true
        #expect(request(activity,export) != nil) // Wire support only, not admitted operator rights.
        var start = activity;start.removeValue(forKey:"activity_id")
        #expect(request(start,export) == nil)
    }
    @Test func backgroundReadCannotDispatchAfterWithdrawalOrOriginalExpiry() async throws {
        let raw = try pushHTTPFixture("register")
        let registration = try JSONDecoder().decode(DJConnectSurfacePushResponse.self,from:JSONSerialization.data(withJSONObject:raw["response_body"]!))
        let read = try #require(registration.background_read)
        SurfacePushHTTPWire.setup(Data("{}".utf8))
        let expired = try DJConnectSurfaceBackgroundHTTP(baseURL:URL(string:"http://127.0.0.1:18766")!,configuration:pushHTTPConfig(),nowMS:{read.expires_at_ms})
        await #expect(throws:(any Error).self) { _ = try await expired.read(read,isCurrent:{true}) }
        #expect(SurfacePushHTTPWire.captured.isEmpty)
        let wire = try DJConnectSurfaceBackgroundHTTP(baseURL:URL(string:"http://127.0.0.1:18766")!,configuration:pushHTTPConfig(),nowMS:{0})
        let authority = SurfaceHTTPAuthority()
        await #expect(throws:(any Error).self) {
            _ = try await wire.read(read,isCurrent:{ let captured = authority.current;authority.current = false;return captured })
        }
        #expect(SurfacePushHTTPWire.captured.isEmpty)
    }
    @Test func actualIOSActivityDefaultCodecKeepsOriginalDatesAndOmitsUnadmittedRichContent() throws {
        let file = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/activity-surface-default-ios-20261023.json")
        let root = try #require(JSONSerialization.jsonObject(with:Data(contentsOf:file)) as? [String:Any])
        #expect(root["native_effects"] as? Bool == false)
        let rows = try #require(root["rows"] as? [[String:Any]])
        #expect(rows.count == 3)
        var originalExpiry: Date?
        for row in rows {
            let bytes = Data((try #require(row["default_encoded_utf8"] as? String)).utf8)
            let snapshot = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self,from:bytes)
            #expect(snapshot.rich == nil && row["external_content_admitted"] as? Bool == false)
            #expect(snapshot.expiresAt.timeIntervalSince(snapshot.observedAt) == 120)
            if let originalExpiry { #expect(snapshot.expiresAt == originalExpiry) } else { originalExpiry = snapshot.expiresAt }
            #expect(Int64(floor(snapshot.expiresAt.timeIntervalSince1970 * 1000)) == row["expires_at_ms"] as? Int64)
        }
    }
    @Test func v2HTTPJoinsOriginalContextAndRegistrationWithoutLegacyFallback() async throws {
        let fixture = try pushHTTPFixture("register")
        let raw = try #require(fixture["request_json"] as? [String:Any])
        let sessionID = try #require(raw["session_id"] as? String)
        let operationID = try #require(raw["operation_id"] as? String)
        let target = try #require(raw["target"] as? [String:String])
        let consent = try #require(raw["consent"] as? [String:Bool])
        let request = try #require(DJConnectSurfacePushRequest(
            identity:.init(deviceID:"djconnect-ios-ABCDEF123456",deviceName:"Fixture",clientType:.ios,firmware:"4.0.0",platform:.ios),
            sessionID:sessionID, operationID:operationID, platform:"ios",osVersion:"26.0",target:target,
            token:Data(repeating:1,count:32),environment:"sandbox",consent:consent,expected:nil))
        let attempt = try #require(DJConnectSurfacePushContextAttempt(original:request,installation:"http://127.0.0.1:18766",ownerEpoch:UUID()))
        let expiry = Int64(Date().timeIntervalSince1970 * 1000) + 3_600_000
        let handle = "djcctx_" + String(repeating:"A",count:43), purpose = "djcpref_" + String(repeating:"A",count:43)
        let context: [String:Any] = ["success":true,"contract_version":2,"available":true,"context_handle":handle,
            "operation_id":attempt.operationID,"purpose_ref":purpose,"expires_at_ms":expiry,
            "context_expires_at_ms":attempt.startedMS+30_000,"cache_policy":"private,no-store"]
        SurfacePushHTTPWire.setup(try JSONSerialization.data(withJSONObject:context))
        let c = client(), continuation = try await c.prepareSurfacePush(attempt,isCurrent:{true})
        let originalContextRequest = try #require(SurfacePushHTTPWire.captured.first)
        #expect(originalContextRequest.url?.path == "/api/djconnect/v1/push/surface/context")
        #expect(originalContextRequest.httpBody == attempt.contextBytes)
        var response = try #require(fixture["response_body"] as? [String:Any])
        response["contract_version"] = 2; response["context_handle"] = handle
        response["operation_id"] = attempt.operationID; response["purpose_ref"] = purpose
        var registration = try #require(response["registration"] as? [String:Any])
        registration["expires_at_ms"] = expiry; response["registration"] = registration
        var read = try #require(response["background_read"] as? [String:Any])
        read["expires_at_ms"] = expiry; response["background_read"] = read
        SurfacePushHTTPWire.setup(try JSONSerialization.data(withJSONObject:response))
        let ack = try await c.registerSurfacePush(continuation,isCurrent:{true})
        #expect(ack.success && ack.background_read?.expires_at_ms == expiry)
        #expect(SurfacePushHTTPWire.captured.count == 1)
        let registerRequest = try #require(SurfacePushHTTPWire.captured.first)
        #expect(registerRequest.url?.path == "/api/djconnect/v1/push/surface/register")
        #expect(registerRequest.httpBody == continuation.registerBytes)
        do { _ = try await c.registerSurfacePush(continuation,isCurrent:{false}); Issue.record("Withdrawn continuation dispatched") }
        catch {}
        #expect(SurfacePushHTTPWire.captured.count == 1)
        let expiredAttempt = try #require(DJConnectSurfacePushContextAttempt(original:request,
            installation:"http://127.0.0.1:18766",ownerEpoch:UUID(),previousPurpose:nil,
            nowMS:Int64(Date().timeIntervalSince1970 * 1000)-31_000,
            monotonicNow:ContinuousClock.now.advanced(by:.seconds(-31))))
        do { _ = try await c.prepareSurfacePush(expiredAttempt,isCurrent:{true}); Issue.record("Expired original context attempt dispatched") }
        catch {}
        #expect(SurfacePushHTTPWire.captured.count == 1)
    }

}
