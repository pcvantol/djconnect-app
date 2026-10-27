import Foundation
import CryptoKit
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

private func automaticVectors() throws -> [[String: String]] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/automatic-surface-registration-core-v1-data.json")
    let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    return try #require(root["vectors"] as? [[String: String]])
}
private func automaticCurrent() throws -> String { try #require(automaticVectors().first { $0["name"] == "current-ipados-data-not-capability" }?["canonical_utf8"]) }
private func automaticScope(platform: String = "ipados", device: String = "synthetic-device") -> DJConnectAutomaticSurfaceScope {
    .init(installationID: "synthetic-installation_id", deviceID: device,
          clientType: platform == "macos" ? "macos" : "ios", platform: platform,
          applicationID: "synthetic-application_id")!
}
private func automaticDecode(_ text: String, role: DJConnectAutomaticSurfaceRole = .widget) throws -> DJConnectAutomaticSurfaceState {
    try .decode(Data(text.utf8), role: role, scope: automaticScope())
}

private final class AutomaticSurfaceHTTPWire: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var body = Data()
    nonisolated(unsafe) private static var status = 200
    nonisolated(unsafe) private static var patch: [String: String] = [:]
    nonisolated(unsafe) private static var requests: [URLRequest] = []
    nonisolated(unsafe) private static var onLoad: (@Sendable () -> Void)?
    static func setup(_ text: String, status: Int = 200, headers: [String: String] = [:], onLoad: (@Sendable () -> Void)? = nil) {
        lock.withLock { body = Data(text.utf8); Self.status = status; patch = headers; requests = []; Self.onLoad = onLoad }
    }
    static var captured: [URLRequest] { lock.withLock { requests } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (body, status, patch, action) = Self.lock.withLock {
            Self.requests.append(request); return (Self.body, Self.status, Self.patch, Self.onLoad)
        }
        action?()
        var headers = ["Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store"]
        headers.merge(patch) { _, new in new }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status,
            httpVersion: nil, headerFields: headers)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor private final class AutomaticDiscoveryRecorder {
    var roles: [DJConnectAutomaticSurfaceRole] = []
    var pending: CheckedContinuation<DJConnectAutomaticSurfaceState, Never>?
    var eligible = true
}

@Suite(.serialized) @MainActor struct AutomaticSurfaceDiscoveryTests {
    @Test func sharedSyntheticCanonicalBytesAndOpaqueCredentialGeneration() throws {
        for v in try automaticVectors() {
            let bytes = Data(try #require(v["canonical_utf8"]).utf8)
            #expect(bytes.map { String(format: "%02x", $0) }.joined() == v["hex"])
            #expect(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() == v["sha256"])
            if v["kind"] == "role" { _ = try DJConnectAutomaticSurfaceState.decode(bytes, role: .widget, scope: automaticScope()) }
        }
        guard case .current(let descriptor) = try automaticDecode(automaticCurrent()) else { Issue.record("Missing data descriptor"); return }
        #expect(descriptor.authGeneration == "synthetic-auth-generation")
        #expect(descriptor.scope.platform == "ipados" && descriptor.scope.clientType == "ios")
        #expect(descriptor.role == .widget && descriptor.parentExpiryMS == 150)
    }

    @Test func strictShapeLexicalTypesScopeAndRoleRejectBeforeDataAdoption() throws {
        let original = try automaticCurrent()
        let mutations = [
            ("\"auth_generation\":\"synthetic-auth-generation\"", "\"auth_generation\":1"),
            ("\"device_platform\":\"ipados\"", "\"device_platform\":[]"),
            ("\"operation_deadline_unix_ms\":100", "\"operation_deadline_unix_ms\":\"100\""),
            ("\"push_authority_revision\":1", "\"push_authority_revision\":true"),
            ("\"version\":1", "\"version\":1.0"),
            ("\"version\":1", "\"version\":1e0"),
            ("\"version\":1", "\"version\":1,\"version\":1"),
            ("\"client_id\":\"synthetic-device\"", "\"client_id\":\"other-device\""),
            ("\"installation_id\":\"synthetic-installation_id\"", "\"installation_id\":\"other-installation\""),
            ("\"application_id\":\"synthetic-application_id\"", "\"application_id\":null"),
            ("\"client_type\":\"ios\"", "\"client_type\":\"macos\""),
            ("\"transport_role\":\"widget_transport\"", "\"transport_role\":\"status_activity_transport\""),
            ("\"operation_deadline_unix_ms\":100", "\"operation_deadline_unix_ms\":151"),
            ("\"issued_at_unix_ms\":1", "\"issued_at_unix_ms\":100"),
            ("4000-8000", "7000-8000"),
            ("\"auth_generation\":\"synthetic-auth-generation\"", "\"auth_generation\":\"invalid/generation\""),
            ("\"version\":1,\"state\":\"AUTHORITY_CURRENT\"", "\"state\":\"AUTHORITY_CURRENT\",\"version\":1")
        ]
        for (before, after) in mutations {
            #expect(original.contains(before))
            #expect(throws: (any Error).self) { try automaticDecode(original.replacingOccurrences(of: before, with: after)) }
        }
        for text in [" " + original, original + " ", original + "{}", String(original.dropLast()) + ",\"session_id\":\"fake\"}", String(repeating: " ", count: 16385)] {
            #expect(throws: (any Error).self) { try automaticDecode(text) }
        }
        #expect(throws: (any Error).self) { try automaticDecode(original, role: .statusActivity) }
        #expect(throws: (any Error).self) { try DJConnectAutomaticSurfaceState.decode(Data([255]), role: .widget, scope: automaticScope()) }
        #expect(automaticScope().deviceID == "synthetic-device")
        #expect(DJConnectAutomaticSurfaceScope(installationID: "i", deviceID: "d", clientType: "ipados", platform: "ipados", applicationID: "a") == nil)
    }

    private func client(store: DJConnectInMemoryTokenStore = .init(token: "paired-fixture")) -> DJConnectClient {
        let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [AutomaticSurfaceHTTPWire.self]
        c.httpAdditionalHeaders = ["Authorization": "Bearer forbidden", "X-Ambient": "forbidden"]
        return .init(baseURL: URL(string: "http://127.0.0.1:18767")!,
            identity: .init(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Fixture", clientType: .ios, firmware: "4.0.0", platform: .ios),
            tokenStore: store, session: URLSession(configuration: c))
    }
    @Test func twoExactPairedGETsHaveNoSessionBodyAmbientCredentialsOrSDKAction() async throws {
        let c = client(), scope = automaticScope(device: "djconnect-ios-ABCDEF123456")
        AutomaticSurfaceHTTPWire.setup("{\"version\":1,\"state\":\"WAITING_AUTHORITY\"}")
        for role in DJConnectAutomaticSurfaceRole.allCases {
            let result = try await c.automaticSurfaceRegistrationState(role: role, scope: scope, isCurrent: { true })
            #expect(result == .waitingAuthority)
        }
        let requests = AutomaticSurfaceHTTPWire.captured
        #expect(requests.count == 2)
        #expect(Set(requests.compactMap { $0.url?.path }) == Set(DJConnectAutomaticSurfaceRole.allCases.map(\.statePath)))
        for r in requests {
            #expect(r.httpMethod == "GET" && r.httpBody == nil && r.httpBodyStream == nil && r.url?.query == nil)
            #expect(r.value(forHTTPHeaderField: "Authorization") == "Bearer paired-fixture")
            #expect(r.value(forHTTPHeaderField: "X-Ambient") == nil)
            #expect(r.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == scope.deviceID)
            #expect(r.value(forHTTPHeaderField: "X-DJConnect-Client-Type") == "ios")
        }
    }

    @Test func HTTPStatusShapeCacheAndTokenReplacementRemainClosed() async throws {
        let scope = automaticScope(device: "djconnect-ios-ABCDEF123456"), c = client()
        AutomaticSurfaceHTTPWire.setup("{\"version\":1,\"state\":\"UNAVAILABLE\"}", status: 503)
        #expect(try await c.automaticSurfaceRegistrationState(role: .widget, scope: scope, isCurrent: { true }) == .unavailable)
        for (status, body, headers) in [(200, "{\"version\":1,\"state\":\"UNAVAILABLE\"}", [:]),
            (503, "{\"version\":1,\"state\":\"WAITING_AUTHORITY\"}", [:]),
            (404, "{}", [:]), (401, "{}", [:]), (403, "{}", [:]),
            (200, "{\"version\":1,\"state\":\"WAITING_AUTHORITY\"}", ["Cache-Control": "public"]),
            (200, String(repeating: "x", count: 16385), [:])] {
            AutomaticSurfaceHTTPWire.setup(body, status: status, headers: headers)
            await #expect(throws: (any Error).self) { try await c.automaticSurfaceRegistrationState(role: .widget, scope: scope, isCurrent: { true }) }
            #expect(AutomaticSurfaceHTTPWire.captured.count == 1)
        }
        AutomaticSurfaceHTTPWire.setup("{\"version\":1,\"state\":\"WAITING_AUTHORITY\"}")
        await #expect(throws: (any Error).self) { try await c.automaticSurfaceRegistrationState(role: .widget, scope: scope, isCurrent: { false }) }
        #expect(AutomaticSurfaceHTTPWire.captured.isEmpty)
        let store = DJConnectInMemoryTokenStore(token: "original"), rotating = client(store: store)
        AutomaticSurfaceHTTPWire.setup("{\"version\":1,\"state\":\"WAITING_AUTHORITY\"}", onLoad: { try? store.saveToken("replacement") })
        await #expect(throws: (any Error).self) { try await rotating.automaticSurfaceRegistrationState(role: .widget, scope: scope, isCurrent: { true }) }
        #expect(AutomaticSurfaceHTTPWire.captured.count == 1)
    }

    private func settle(_ predicate: () -> Bool) async {
        let cutoff = ContinuousClock.now + .seconds(3)
        while !predicate(), ContinuousClock.now < cutoff { await Task.yield() }
        #expect(predicate())
    }
    @Test func deviceOnlyDiscoveryHasIndependentRolesWithoutAnyActiveSession() async throws {
        let model = AutomaticSurfaceDiscoveryModel(), record = AutomaticDiscoveryRecorder()
        model.bind(.init(scope: automaticScope(), origin: URL(string: "http://localhost:8123")!, pairingAttempt: UUID()))
        model.refresh(isCurrent: { true }, read: { role, _, current in
            #expect(current()); record.roles.append(role); return .waitingAuthority
        })
        await settle { model.states.count == 2 }
        #expect(Set(record.roles) == Set([.widget, .statusActivity]))
        model.refresh(isCurrent: { true }, read: { _, _, _ in Issue.record("Unthrottled duplicate read"); return .unavailable })
        await Task.yield()
        #expect(record.roles.count == 2)
        model.bind(nil); #expect(model.states.isEmpty)
    }
    @Test func delayedReplyCannotSurviveNilReturnABAOrExternalCredentialLoss() async throws {
        let model = AutomaticSurfaceDiscoveryModel(), record = AutomaticDiscoveryRecorder()
        let owner = AutomaticSurfaceDiscoveryModel.Owner(scope: automaticScope(platform: "macos"),
            origin: URL(string: "http://localhost:8123")!, pairingAttempt: UUID())
        model.bind(owner)
        let oldReads = model.refresh(isCurrent: { record.eligible }, read: { _, _, _ in
            await withCheckedContinuation { record.pending = $0 }
        })
        await settle { record.pending != nil }
        model.bind(nil); model.bind(owner)
        model.refresh(isCurrent: { true }, read: { _, _, _ in .waitingAuthority })
        await settle { model.states[.widget] == .waitingAuthority }
        record.pending?.resume(returning: .unavailable); record.pending = nil
        for task in oldReads { await task.value }
        #expect(model.states[.widget] == .waitingAuthority)
        model.bind(nil); model.bind(owner)
        let revokedReads = model.refresh(isCurrent: { record.eligible }, read: { _, _, _ in
            await withCheckedContinuation { record.pending = $0 }
        })
        await settle { record.pending != nil }
        record.eligible = false
        record.pending?.resume(returning: .unavailable); record.pending = nil
        for task in revokedReads { await task.value }
        #expect(model.states.isEmpty && model.owner == nil)
    }
}
