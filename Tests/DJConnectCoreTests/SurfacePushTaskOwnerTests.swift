import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

/// Every positive case below is an explicitly MODELED original admission with
/// URLProtocol-only paired responses. It is not a native clock/consent factory.
private final class SurfaceOwnerFixtureAnchor: NSObject {}
private final class OwnerGate: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [@Sendable () -> Void] = []
    private var released = false
    func hold(_ body: @escaping @Sendable () -> Void) {
        let now = lock.withLock { if released { return true }; pending.append(body); return false }
        if now { body() }
    }
    func release() { let bodies = lock.withLock { released = true; let p = pending; pending = []; return p }; bodies.forEach { $0() } }
}
private final class OwnerFixture: @unchecked Sendable {
    let host = "pushowner-" + UUID().uuidString.lowercased() + ".test"
    var url: URL { URL(string: "http://" + host)! }
    let gate: OwnerGate?
    let gatedPart: String?
    let uncertain: Bool
    let expiry = Int64(Date().timeIntervalSince1970 * 1000) + 60_000
    private let lock = NSLock()
    private var captures: [URLRequest] = []
    private var cancellations: [String] = []
    init(gatedPart: String? = nil, uncertain: Bool = false) {
        self.gatedPart = gatedPart; self.gate = gatedPart == nil ? nil : OwnerGate(); self.uncertain = uncertain
        OwnerProtocol.add(self)
    }
    func close() { gate?.release(); OwnerProtocol.remove(host) }
    var requests: [URLRequest] { lock.withLock { captures } }
    var stops: [String] { lock.withLock { cancellations } }
    func record(_ r: URLRequest) { lock.withLock { captures.append(r) } }
    func stop(_ r: URLRequest) { lock.withLock { cancellations.append(r.url!.lastPathComponent) } }
    func client() -> DJConnectClient {
        let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [OwnerProtocol.self]
        c.httpAdditionalHeaders = ["X-Ambient": "must-not-leave"]
        return DJConnectClient(baseURL: url, identity: identity(), tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-paired-token"), session: URLSession(configuration: c))
    }
    func identity() -> DJConnectIdentity { .init(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Model", clientType: .ios, firmware: "4.0.0", platform: .ios) }
    func scope(_ binding: String = "model-profile") throws -> DJConnectSurfacePushTaskOwner.Scope {
        try #require(.init(installation: "model-installation", binding: binding, sessionID: "model-session", origin: url,
                          deviceID: identity().deviceID, clientType: "ios"))
    }
    func response(_ request: URLRequest) throws -> (Data, Int) {
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let part = request.url!.lastPathComponent
        let op = body["operation_id"] as? String ?? "00000000-0000-7000-8000-000000000001"
        let context = "djcctx_" + String(repeating: "A", count: 43)
        let purpose = "djcpref_" + String(repeating: "A", count: 43)
        let expected = body["expected_registration"] as? [String: Any]
        let revision = (expected?["revision"] as? Int ?? 0) + 1
        let receipt: [String: Any] = ["registration_id": "model-reg", "generation": "model-generation", "revision": revision,
            "state": "registered", "expires_at_ms": expiry, "token_role": "widget", "platform": "ios", "last_error": NSNull(), "cache_policy": "private,no-store"]
        let operation: [String: Any] = ["contract_version": 1, "operation_id": op, "operation_epoch": "model-epoch",
            "phase": "confirmed", "expires_at_ms": expiry, "result_available": false, "response_status": 200, "error": NSNull()]
        let result: [String: Any]
        switch part {
        case "context": result = ["success": true, "available": true, "contract_version": 3,
            "context_handle": context, "operation_id": op, "purpose_ref": purpose, "expires_at_ms": expiry,
            "context_expires_at_ms": expiry - 30_000, "purpose_remaining_at_original_start_ms": 60_000,
            "context_remaining_at_original_start_ms": 30_000, "cache_policy": "private,no-store"]
        case "register":
            if uncertain { return (Data(#"{"success":false,"error":"model_uncertain"}"#.utf8), 503) }
            result = ["contract_version": 3, "context_handle": context, "operation_id": op, "purpose_ref": purpose,
                "success": true, "replayed": false, "operation": operation, "registration": receipt,
                "background_read": ["credential": "djcsurface_" + String(repeating: "A", count: 43), "expires_at_ms": expiry,
                    "registration_id": "model-reg", "scope": "exact_original_surface_read_only", "cache_policy": "private,no-store"]]
        case "status": result = ["success": true, "contract_version": 1, "registration": receipt]
        case "read":
            #if SWIFT_PACKAGE
            let bundle = Bundle.module
            #else
            let bundle = Bundle(for: SurfaceOwnerFixtureAnchor.self)
            #endif
            let path = try #require(bundle.url(forResource: "surface-push-core-12675bc-http", withExtension: "json", subdirectory: "Fixtures")
                ?? bundle.url(forResource: "surface-push-core-12675bc-http", withExtension: "json"))
            let root = try JSONSerialization.jsonObject(with: Data(contentsOf: path)) as! [String: Any]
            let entry = (root["cases"] as! [[String: Any]]).first { $0["kind"] as? String == "read" && $0["status"] as? Int == 200 }!
            var copied = entry["response_body"] as! [String: Any]
            copied["registration"] = receipt
            result = copied // Synthetic owner model; retained projection times are NOT rewritten.
        default: result = ["success": true, "replayed": false, "operation": operation, "registration": receipt]
        }
        return (try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), 200)
    }
}
private final class OwnerProtocol: URLProtocol, @unchecked Sendable {
    static let registryLock = NSLock()
    nonisolated(unsafe) static var fixtures: [String: OwnerFixture] = [:]
    let stateLock = NSLock(); var stopped = false
    static func add(_ fixture: OwnerFixture) { registryLock.withLock { fixtures[fixture.host] = fixture } }
    static func remove(_ host: String) { _ = registryLock.withLock { fixtures.removeValue(forKey: host) } }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host?.hasPrefix("pushowner-") == true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let fixture = Self.registryLock.withLock({ Self.fixtures[request.url!.host!] }) else { return }
        var captured = request
        if captured.httpBody == nil, let stream = captured.httpBodyStream {
            stream.open(); defer { stream.close() }; var data = Data(), buffer = [UInt8](repeating: 0, count: 1024)
            while true { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(contentsOf: buffer.prefix(n)) }
            captured.httpBody = data
        }
        fixture.record(captured)
        do {
            let (data, code) = try fixture.response(captured)
            let deliver: @Sendable () -> Void = { [self] in
                guard !stateLock.withLock({ stopped }) else { return }
                let headers = ["Content-Type": "application/json", "Cache-Control": "private,no-store", "Referrer-Policy": "no-referrer", "X-Content-Type-Options": "nosniff"]
                client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: headers)!, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
            }
            if fixture.gatedPart == captured.url!.lastPathComponent { fixture.gate!.hold(deliver) } else { deliver() }
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {
        stateLock.withLock { stopped = true }
        Self.registryLock.withLock { Self.fixtures[request.url!.host!]?.stop(request) }
    }
}

@Suite(.serialized) @MainActor struct SurfacePushTaskOwnerTests {
    typealias Owner = DJConnectSurfacePushTaskOwner
    private func candidate(_ byte: UInt8 = 1) throws -> Owner.Candidate {
        try #require(.init(role: .widget, token: Data(repeating: byte, count: 32), platform: "ios", osVersion: "26.0",
            environment: "sandbox", target: ["instance_id": "model-native-instance", "app_bundle_id": "dev.djconnect.ios",
                "extension_bundle_id": "dev.djconnect.ios.track-insight-widget", "widget_kind": "DJConnectSessionWidget"]))
    }
    private func admission(_ lifetime: Int64 = 5_000) -> Owner.Admission {
        .init(modelConsent: ["background_read": true, "os_snapshot_cache": true, "locked_display": false,
            "external_push_content": false, "allow_remote_start": false], current: { true }, modelBounds: { context, start in
                // ASSUMED equal-clock MODEL only, not qualified physical/native rate.
                (start.advanced(by: .milliseconds(min(lifetime, context.purposeRemainingAtOriginalStartMS))),
                 start.advanced(by: .milliseconds(min(lifetime, context.contextRemainingAtOriginalStartMS))))
            })
    }
    private func settle(_ owner: Owner) async throws {
        for _ in 0..<200 where owner.hasOwnedTask { try await Task.sleep(for: .milliseconds(10)) }
        #expect(!owner.hasOwnedTask)
    }
    @Test func publicFactoryAndActivityRoleRemainClosedWithZeroWireCalls() async throws {
        let f = OwnerFixture(); defer { f.close() }
        for role in [Owner.Role.widget, .liveActivityUpdate] {
            let owner = Owner(role: role); owner.bind(try f.scope())
            let c = try candidate()
            if role == .widget { owner.observe(c) } else {
                owner.observe(try #require(.init(role: role, token: c.token, platform: "ios", osVersion: "26.0", environment: "sandbox",
                    target: ["instance_id": "local", "app_bundle_id": "dev.djconnect.ios", "activity_id": "native", "attributes_type": "DJConnectSessionLiveActivityAttributes"])))
            }
            owner.register(using: f.client(), observationGeneration: owner.observationGeneration)
            #expect(owner.phase == (role == .widget ? .admissionUnavailable : .profileUnavailable))
            #expect(!owner.hasReadCustody && !owner.hasOwnedTask)
        }
        #expect(f.requests.isEmpty)
    }
    @Test func modeledV3OneOperationRotationAndOriginalExpiry() async throws {
        let f = OwnerFixture(); defer { f.close() }; let a = admission()
        let owner = Owner(role: .widget, modelProvider: { _,_ in a }); defer { owner.withdrawLocally() }
        owner.bind(try f.scope()); owner.observe(try candidate()); let client = f.client()
        owner.register(using: client, observationGeneration: owner.observationGeneration); try await settle(owner)
        #expect(owner.phase == .registered && owner.hasReadCustody && owner.coordinate?.revision == 1)
        owner.register(using: client, observationGeneration: owner.observationGeneration); try await settle(owner)
        #expect(f.requests.count == 2)
        owner.observe(try candidate(2)); #expect(!owner.hasReadCustody)
        owner.register(using: client, observationGeneration: owner.observationGeneration); try await settle(owner)
        #expect(owner.coordinate?.revision == 2 && owner.hasReadCustody)
        let bodies = try f.requests.map { try #require(JSONSerialization.jsonObject(with: $0.httpBody!) as? [String: Any]) }
        #expect(bodies.allSatisfy { $0["contract_version"] as? Int == 3 })
        #expect(bodies[0]["operation_id"] as? String == bodies[1]["operation_id"] as? String)
        #expect(bodies[2]["operation_id"] as? String == bodies[3]["operation_id"] as? String)
        #expect(bodies[0]["operation_id"] as? String != bodies[2]["operation_id"] as? String)
        #expect((bodies[3]["expected_registration"] as? [String: Any])?["revision"] as? Int == 1)
    }
    @Test(arguments: ["context", "register"]) func modeledWithdrawalCancelsHTTPAndRejectsLateABA(_ part: String) async throws {
        let f = OwnerFixture(gatedPart: part); defer { f.close() }; let a = admission()
        let owner = Owner(role: .widget, modelProvider: { _,_ in a })
        let original = try f.scope(); owner.bind(original); owner.observe(try candidate())
        let old = owner.observationGeneration
        owner.register(using: f.client(), observationGeneration: old)
        for _ in 0..<100 where !f.requests.contains(where: { $0.url!.lastPathComponent == part }) { try await Task.sleep(for: .milliseconds(10)) }
        #expect(f.requests.contains { $0.url!.lastPathComponent == part })
        owner.bind(try f.scope("other")); owner.bind(original)
        #expect(!owner.hasReadCustody && !owner.hasOwnedTask)
        for _ in 0..<100 where !f.stops.contains(part) { try await Task.sleep(for: .milliseconds(10)) }
        #expect(f.stops.contains(part)) // Real Foundation cancellation BEFORE release.
        f.gate!.release(); try await Task.sleep(for: .milliseconds(50))
        #expect(owner.coordinate == nil && !owner.hasReadCustody)
        let count = f.requests.count
        owner.observe(try candidate()); owner.register(using: f.client(), observationGeneration: old)
        try await Task.sleep(for: .milliseconds(30)); #expect(f.requests.count == count)
    }
    @Test func modeledUnknownNeverReplaysOnPollingOrTokenRotation() async throws {
        let f = OwnerFixture(uncertain: true); defer { f.close() }; let a = admission()
        let owner = Owner(role: .widget, modelProvider: { _,_ in a }); defer { owner.withdrawLocally() }
        owner.bind(try f.scope()); owner.observe(try candidate()); let client = f.client()
        owner.register(using: client, observationGeneration: owner.observationGeneration); try await settle(owner)
        #expect(owner.phase == .uncertain && owner.uncertainOperationID != nil && !owner.hasReadCustody)
        for byte in [UInt8(1),2,3] { owner.observe(try candidate(byte)); owner.register(using: client, observationGeneration: owner.observationGeneration) }
        try await Task.sleep(for: .milliseconds(40))
        #expect(f.requests.filter { $0.url!.lastPathComponent == "register" }.count == 1)
    }
    @Test func modeledEarlierPinExpiresInsteadOfRenewingOnRotation() async throws {
        let f = OwnerFixture(); defer { f.close() }; let a = admission(1000)
        let owner = Owner(role: .widget, modelProvider: { _,_ in a })
        owner.bind(try f.scope()); owner.observe(try candidate()); let client = f.client()
        owner.register(using: client, observationGeneration: owner.observationGeneration); try await settle(owner)
        #expect(owner.hasReadCustody)
        try await Task.sleep(for: .milliseconds(450)); owner.observe(try candidate(2))
        owner.register(using: client, observationGeneration: owner.observationGeneration); try await settle(owner)
        try await Task.sleep(for: .milliseconds(600))
        #expect(!owner.hasReadCustody && owner.phase == .withdrawn)
    }
    @Test func modeledRevokeScrubsSynchronouslyAndLateReplyCannotRestore() async throws {
        let f = OwnerFixture(gatedPart: "revoke"); defer { f.close() }; let a = admission()
        let owner = Owner(role: .widget, modelProvider: { _,_ in a })
        owner.bind(try f.scope()); owner.observe(try candidate()); owner.register(using: f.client(), observationGeneration: owner.observationGeneration)
        try await settle(owner); #expect(owner.hasReadCustody)
        owner.revoke(); #expect(!owner.hasReadCustody && owner.coordinate == nil)
        for _ in 0..<100 where !f.requests.contains(where: { $0.url!.lastPathComponent == "revoke" }) { try await Task.sleep(for: .milliseconds(10)) }
        #expect(f.requests.contains { $0.url!.lastPathComponent == "revoke" })
        owner.bind(nil); f.gate!.release(); try await Task.sleep(for: .milliseconds(40))
        #expect(!owner.hasReadCustody && owner.coordinate == nil)
    }
    @Test func modeledStatusAndScopedReadNeverUseAmbientAppAuthorityOrRenew() async throws {
        let f = OwnerFixture(); defer { f.close() }; let a = admission()
        let owner = Owner(role: .widget, modelProvider: { _,_ in a }); defer { owner.withdrawLocally() }
        owner.bind(try f.scope()); owner.observe(try candidate())
        owner.register(using: f.client(), observationGeneration: owner.observationGeneration); try await settle(owner)
        let coordinate = owner.coordinate
        #expect(try await owner.status()?.registration.coordinate == coordinate)
        #expect(try await owner.read()?.registration.coordinate == coordinate)
        let read = try #require(f.requests.first { $0.url!.lastPathComponent == "read" })
        #expect(read.value(forHTTPHeaderField: "Authorization") == "Bearer djcsurface_" + String(repeating: "A", count: 43))
        #expect(read.value(forHTTPHeaderField: "X-Ambient") == nil)
        owner.withdrawLocally()
        #expect(try await owner.status() == nil)
        #expect(try await owner.read() == nil)
        #expect(!owner.hasReadCustody)
    }
    @Test(arguments: ["status", "read"]) func modeledWithdrawalOwnsAndCancelsAuxiliaryReads(_ part: String) async throws {
        let f = OwnerFixture(gatedPart: part); defer { f.close() }; let a = admission()
        let owner = Owner(role: .widget, modelProvider: { _,_ in a })
        owner.bind(try f.scope()); owner.observe(try candidate())
        owner.register(using: f.client(), observationGeneration: owner.observationGeneration); try await settle(owner)
        let request = Task { if part == "status" { _ = try? await owner.status() } else { _ = try? await owner.read() } }
        for _ in 0..<100 where !f.requests.contains(where: { $0.url!.lastPathComponent == part }) { try await Task.sleep(for: .milliseconds(10)) }
        #expect(owner.hasOwnedTask)
        owner.withdrawLocally(); #expect(!owner.hasReadCustody && !owner.hasOwnedTask)
        for _ in 0..<100 where !f.stops.contains(part) { try await Task.sleep(for: .milliseconds(10)) }
        #expect(f.stops.contains(part))
        f.gate!.release(); await request.value
        #expect(!owner.hasReadCustody && owner.coordinate == nil)
    }
    @Test func modeledObservedConsentLossCannotReviveAndCancelledCallerCannotStart() async throws {
        let f = OwnerFixture(); defer { f.close() }
        var current = true
        let a = Owner.Admission(modelConsent: ["background_read": true, "os_snapshot_cache": true,
            "locked_display": false, "external_push_content": false, "allow_remote_start": false], current: { current },
            modelBounds: { _, start in (start.advanced(by: .seconds(5)), start.advanced(by: .seconds(5))) })
        let owner = Owner(role: .widget, modelProvider: { _,_ in a })
        owner.bind(try f.scope()); owner.observe(try candidate()); let client = f.client()
        let cancelled = Task { owner.register(using: client, observationGeneration: owner.observationGeneration) }
        cancelled.cancel(); await cancelled.value
        #expect(f.requests.isEmpty)
        owner.register(using: client, observationGeneration: owner.observationGeneration); try await settle(owner)
        #expect(owner.hasReadCustody)
        current = false; #expect(!owner.hasReadCustody)
        current = true; #expect(!owner.hasReadCustody && owner.phase == .withdrawn)
        #expect(try await owner.read() == nil)
    }
    @Test func modeledDelayedContextCannotReanchorOriginalC0OrRetry() async throws {
        let f = OwnerFixture(gatedPart: "context"); defer { f.close() }; let a = admission(100)
        let owner = Owner(role: .widget, modelProvider: { _,_ in a }); defer { owner.withdrawLocally() }
        owner.bind(try f.scope()); owner.observe(try candidate()); let client = f.client()
        owner.register(using: client, observationGeneration: owner.observationGeneration)
        for _ in 0..<100 where f.requests.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        #expect(f.requests.count == 1)
        try await Task.sleep(for: .milliseconds(150)); f.gate!.release(); try await settle(owner)
        #expect(owner.phase == .uncertain && !owner.hasReadCustody)
        owner.register(using: client, observationGeneration: owner.observationGeneration); try await settle(owner)
        #expect(f.requests.count == 1 && f.requests.allSatisfy { $0.url!.lastPathComponent == "context" })
    }
    @Test func modeledAdmissionCannotGuessMissingEnvironmentOrAnotherPairedDevice() async throws {
        let f = OwnerFixture(); defer { f.close() }; let a = admission()
        let owner = Owner(role: .widget, modelProvider: { _,_ in a })
        let c = try candidate()
        owner.bind(try f.scope())
        owner.observe(try #require(.init(role: .widget, token: c.token, platform: c.platform, osVersion: c.osVersion, environment: nil, target: c.target)))
        owner.register(using: f.client(), observationGeneration: owner.observationGeneration)
        #expect(owner.phase == .admissionUnavailable && !owner.hasOwnedTask)
        owner.bind(try #require(.init(installation: "model-installation", binding: "model-profile", sessionID: "model-session",
            origin: f.url, deviceID: "djconnect-ios-OTHER123456", clientType: "ios")))
        owner.observe(c); owner.register(using: f.client(), observationGeneration: owner.observationGeneration)
        #expect(f.requests.isEmpty)
    }
    @Test(arguments: ["success", "error", "cancel-success", "cancel-error"], [Owner.Role.widget, .liveActivityUpdate])
    func appInventoryFenceRejectsDelayedResultsAndErrors(_ outcome: String, _ role: Owner.Role) async throws {
        let name = "owner-inventory-model-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
        let f = OwnerFixture(); defer { f.close() }
        let owner = role == .widget ? model.nativeWidgetPushOwner : model.nativeActivityPushOwner
        let scope = try f.scope()
        owner.bind(scope)
        let attempt = model.captureNativePushInventoryAttempt()
        #expect(model.isCurrentNativePushInventory(attempt, role: role))
        let gate = OwnerGate()
        var entered = false, published = false
        // Gated SDK-inventory model; exercises the SAME AppModel predicate used
        // after real SDK awaits and in their catch. No native SDK callback claim.
        let pending = Task {
            entered = true
            do {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    gate.hold { continuation.resume() }
                }
                if outcome.hasSuffix("error") { throw DJConnectError.invalidResponse }
                guard model.isCurrentNativePushInventory(attempt, role: role) else { return }
                published = true
            } catch {
                guard model.isCurrentNativePushInventory(attempt, role: role) else { return }
                owner.withdrawLocally()
            }
        }
        while !entered { await Task.yield() }
        if outcome.hasPrefix("cancel") { pending.cancel() }
        else { owner.bind(nil); owner.bind(scope) } // Same visible A after a lost owner.
        let successorGeneration = owner.observationGeneration
        gate.release(); await pending.value
        #expect(!published && owner.observationGeneration == successorGeneration && owner.phase == .idle)
        #expect(f.requests.isEmpty)
    }
    @Test func appBackgroundWithdrawsBothNativeOwnersWithoutHistoryAuthority() throws {
        let name = "owner-model-" + UUID().uuidString; let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
        let f = OwnerFixture(); defer { f.close() }
        model.nativeWidgetPushOwner.bind(try f.scope()); model.nativeWidgetPushOwner.observe(try candidate())
        model.markInactiveSession()
        #expect(model.nativeWidgetPushOwner.phase == .withdrawn && model.nativeActivityPushOwner.phase == .withdrawn)
        #expect(f.requests.isEmpty)
    }
}
