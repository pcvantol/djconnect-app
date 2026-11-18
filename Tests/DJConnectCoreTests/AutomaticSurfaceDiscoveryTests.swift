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
private func automaticParent() throws -> DJConnectAutomaticSurfaceDescriptor {
    guard case .current(let parent) = try automaticDecode(automaticCurrent()) else { throw DJConnectError.invalidResponse }
    return parent
}
private func automaticChildText(parent: DJConnectAutomaticSurfaceCoordinate, id: String = "00000000-0000-4000-8000-000000000001",
                                revision: Int = 1, outcome: String = "CURRENT", bodyHash: String? = nil) throws -> String {
    // Derive from the independent API canonical fixture, retaining its exact
    // thirteen-field wire order, then bind the selected synthetic parent.
    let original = try #require(automaticVectors().first { $0["kind"] == "child" }?["canonical_utf8"])
    return original
        .replacingOccurrences(of: "\"pairing_epoch\":\"synthetic-pair\"", with: "\"pairing_epoch\":\"\(parent.pairingEpoch)\"")
        .replacingOccurrences(of: "\"push_authority_id\":\"synthetic-authority\"", with: "\"push_authority_id\":\"\(parent.authorityID)\"")
        .replacingOccurrences(of: "\"push_authority_revision\":1", with: "\"push_authority_revision\":\(parent.authorityRevision)")
        .replacingOccurrences(of: "\"original_operation_id\":\"00000000-0000-4000-8000-000000000001\"", with: "\"original_operation_id\":\"\(parent.originalOperationID)\"")
        .replacingOccurrences(of: "\"parent_enrollment_id\":\"00000000-0000-4000-8000-000000000001\"", with: "\"parent_enrollment_id\":\"\(parent.parentID)\"")
        .replacingOccurrences(of: "\"parent_enrollment_generation\":1", with: "\"parent_enrollment_generation\":\(parent.parentGeneration)")
        .replacingOccurrences(of: "\"A_body_sha256\":\"\(String(repeating: "a", count: 64))\"", with: "\"A_body_sha256\":\"\(parent.originalBodySHA256)\"")
        .replacingOccurrences(of: "\"child_id\":\"00000000-0000-4000-8000-000000000001\"", with: "\"child_id\":\"\(id)\"")
        .replacingOccurrences(of: "\"child_revision\":1", with: "\"child_revision\":\(revision)")
        .replacingOccurrences(of: "\"outcome\":\"CURRENT\"", with: "\"outcome\":\"\(outcome)\"")
        .replacingOccurrences(of: "\"B_body_sha256\":\"\(String(repeating: "a", count: 64))\"", with: "\"B_body_sha256\":\"\(bodyHash ?? String(repeating: "a", count: 64))\"")
}
private func automaticChild(_ text: String, parent: DJConnectAutomaticSurfaceCoordinate) throws -> DJConnectAutomaticSurfaceChildState {
    guard case .state(let child) = try DJConnectAutomaticSurfaceChildRead.decode(Data(text.utf8), parent: parent) else { throw DJConnectError.invalidResponse }
    return child
}
private func automaticIndex(_ children: [String], parent: DJConnectAutomaticSurfaceCoordinate) -> String {
    "{\"version\":1,\"state\":\"CHILD_INDEX\",\"pairing_epoch\":\"\(parent.pairingEpoch)\",\"parent_enrollment_id\":\"\(parent.parentID)\",\"parent_enrollment_generation\":\(parent.parentGeneration),\"A_body_sha256\":\"\(parent.originalBodySHA256)\",\"children\":[" + children.joined(separator: ",") + "]}"
}
private func automaticB64(_ bytes: Data) -> String {
    bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}
private func automaticReceipt(body: Data, signature: Data = Data(repeating: 0, count: 64)) -> String {
    "{\"version\":1,\"state\":\"CHILD_RECEIPT\",\"B_body_b64url\":\"\(automaticB64(body))\",\"B_signature_b64url\":\"\(automaticB64(signature))\"}"
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

extension AutomaticSurfaceDiscoveryTests {
    @Test func childStatesKeepAllOriginalParentCoordinatesAndTerminalOutcomes() throws {
        let parent = try automaticParent().coordinate
        for outcome in ["CURRENT", "RETIRED", "EXPIRED", "UNKNOWN", "COMMITTED_BUT_SUPPRESSED"] {
            let child = try automaticChild(automaticChildText(parent: parent, outcome: outcome), parent: parent)
            #expect(child.parent == parent && child.outcome.rawValue == outcome)
            #expect(child.parent.originalOperationID == parent.originalOperationID)
        }
        let original = try automaticChildText(parent: parent)
        for (before, after) in [("\"child_revision\":1", "\"child_revision\":true"),
            ("\"child_revision\":1", "\"child_revision\":1e0"),
            ("\"child_revision\":1", "\"child_revision\":9007199254740992"),
            ("\"outcome\":\"CURRENT\"", "\"outcome\":\"RETRY\""),
            ("\"push_authority_revision\":1", "\"push_authority_revision\":2"),
            ("\"original_operation_id\":\"00000000-0000-4000-8000-000000000001\"", "\"original_operation_id\":\"00000000-0000-4000-8000-000000000002\""),
            ("\"pairing_epoch\":\"\(parent.pairingEpoch)\"", "\"pairing_epoch\":\"different-owner\""),
            ("\"child_id\":", "\"unexpected_child_id\":") ] {
            #expect(original.contains(before))
            #expect(throws: (any Error).self) { try automaticChild(original.replacingOccurrences(of: before, with: after), parent: parent) }
        }
        #expect(try DJConnectAutomaticSurfaceChildRead.decode(Data("{\"version\":1,\"state\":\"UNAVAILABLE\"}".utf8), parent: parent) == .unavailable)
        #expect(throws: (any Error).self) { try automaticChild(" " + original, parent: parent) }
    }

    @Test func indexRequiresFiniteBoundExactParentUniqueOrderAndNoTruncation() throws {
        let parent = try automaticParent().coordinate
        let a = try automaticChildText(parent: parent), b = try automaticChildText(parent: parent, id: "00000000-0000-4000-8000-000000000002")
        let bytes = Data(automaticIndex([a, b], parent: parent).utf8)
        guard case .index(let index) = try DJConnectAutomaticSurfaceChildIndexRead.decode(bytes, parent: parent, maximumChildren: 2) else { Issue.record("Missing index"); return }
        #expect(index.children.count == 2 && index.parent == parent)
        for bound in [0, -1, 1] {
            #expect(throws: (any Error).self) { try DJConnectAutomaticSurfaceChildIndexRead.decode(bytes, parent: parent, maximumChildren: bound) }
        }
        for children in [[b, a], [a, a], [a, try automaticChildText(parent: parent, revision: 2)],
            [a.replacingOccurrences(of: "\"push_authority_revision\":1", with: "\"push_authority_revision\":2")]] {
            #expect(throws: (any Error).self) { try DJConnectAutomaticSurfaceChildIndexRead.decode(Data(automaticIndex(children, parent: parent).utf8), parent: parent, maximumChildren: 2) }
        }
        let empty = try DJConnectAutomaticSurfaceChildIndexRead.decode(Data(automaticIndex([], parent: parent).utf8), parent: parent, maximumChildren: 1)
        guard case .index(let value) = empty else { Issue.record("Known empty index unavailable"); return }
        #expect(value.children.isEmpty)
    }

    @Test func onlyIndexAllowsMoreThanSixteenKiBAndStillHasCompleteResponseCap() async throws {
        let parent = try automaticParent()
        let children = try (1...32).map { try automaticChildText(parent: parent.coordinate, id: String(format: "00000000-0000-4000-8000-%012d", $0)) }
        let large = automaticIndex(children, parent: parent.coordinate)
        #expect(large.utf8.count > 16384 && large.utf8.count < 65536)
        _ = try DJConnectAutomaticSurfaceChildIndexRead.decode(Data(large.utf8), parent: parent.coordinate, maximumChildren: 32)
        #expect(throws: (any Error).self) { try DJConnectAutomaticSurfaceChildRead.decode(Data(large.utf8), parent: parent.coordinate) }
        #expect(throws: (any Error).self) { try DJConnectAutomaticSurfaceChildIndexRead.decode(Data(repeating: 32, count: 65537), parent: parent.coordinate, maximumChildren: 32) }
        let actualParent = try automaticHTTPParent()
        AutomaticSurfaceHTTPWire.setup(automaticIndex(children, parent: actualParent.coordinate))
        guard case .index(let result) = try await client().automaticSurfaceChildIndex(parent: actualParent, maximumChildren: 32, isCurrent: { true }) else { Issue.record("Missing large index response"); return }
        #expect(result.children.count == 32)
    }

    @Test func originalReceiptIsHashJoinedButExplicitlyUnverifiedAndCannotGrantNativeUse() throws {
        let parent = try automaticParent().coordinate
        let body = Data("synthetic-body-not-a-validated-B-grant".utf8)
        let hash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        let child = try automaticChild(automaticChildText(parent: parent, bodyHash: hash), parent: parent)
        let bytes = Data(automaticReceipt(body: body).utf8)
        guard case .data(let result) = try DJConnectAutomaticSurfaceChildReceiptRead.decode(bytes, child: child) else { Issue.record("Missing unverified bytes"); return }
        #expect(result.classification == "UNVERIFIED_RECEIPT_DATA_ONLY")
        #expect(result.body == body && result.signature == Data(repeating: 0, count: 64))
        // Random zero signature is merely bytes, never a verified grant.
        for invalid in [automaticReceipt(body: Data("changed".utf8)), automaticReceipt(body: body, signature: Data(repeating: 0, count: 63)),
            automaticReceipt(body: Data(repeating: 1, count: 8193)),
            automaticReceipt(body: body).replacingOccurrences(of: automaticB64(Data(repeating: 0, count: 64)), with: String(automaticB64(Data(repeating: 0, count: 64)).dropLast()) + "B"),
            automaticReceipt(body: body).replacingOccurrences(of: automaticB64(body), with: automaticB64(body) + "="),
            automaticReceipt(body: body).replacingOccurrences(of: "\"version\":1", with: "\"version\":true"),
            String(repeating: " ", count: 16385)] {
            #expect(throws: (any Error).self) { try DJConnectAutomaticSurfaceChildReceiptRead.decode(Data(invalid.utf8), child: child) }
        }
        let retired = try automaticChild(automaticChildText(parent: parent, outcome: "RETIRED", bodyHash: hash), parent: parent)
        #expect(throws: (any Error).self) { try DJConnectAutomaticSurfaceChildReceiptRead.decode(bytes, child: retired) }
    }

    private func automaticHTTPParent(role: DJConnectAutomaticSurfaceRole = .widget) throws -> DJConnectAutomaticSurfaceDescriptor {
        var text = try automaticCurrent().replacingOccurrences(of: "synthetic-device", with: "djconnect-ios-ABCDEF123456")
            .replacingOccurrences(of: "widget_transport", with: role.rawValue)
        if role == .statusActivity {
            text = text.replacingOccurrences(of: "\"parent_enrollment_id\":\"00000000-0000-4000-8000-000000000001\"", with: "\"parent_enrollment_id\":\"00000000-0000-4000-8000-000000000003\"")
                .replacingOccurrences(of: "\"original_operation_id\":\"00000000-0000-4000-8000-000000000001\"", with: "\"original_operation_id\":\"00000000-0000-4000-8000-000000000004\"")
                .replacingOccurrences(of: "\"A_body_sha256\":\"\(String(repeating: "a", count: 64))\"", with: "\"A_body_sha256\":\"\(String(repeating: "b", count: 64))\"")
        }
        guard case .current(let parent) = try DJConnectAutomaticSurfaceState.decode(Data(text.utf8), role: role,
            scope: automaticScope(device: "djconnect-ios-ABCDEF123456")) else { throw DJConnectError.invalidResponse }
        return parent
    }
    @Test func childHTTPUsesOnlyClosedGETsAndRejectsCrossChildOrTerminalReceiptBeforeDispatch() async throws {
        let parent = try automaticHTTPParent(), c = client()
        let rawChild = try automaticChildText(parent: parent.coordinate)
        let child = try automaticChild(rawChild, parent: parent.coordinate)
        AutomaticSurfaceHTTPWire.setup(rawChild)
        _ = try await c.automaticSurfaceChildState(parent: parent, childID: child.childID, isCurrent: { true })
        #expect(AutomaticSurfaceHTTPWire.captured.first?.url?.path == DJConnectAutomaticSurfaceRole.childStatePath(child.childID))
        #expect(AutomaticSurfaceHTTPWire.captured.first?.httpBody == nil)
        AutomaticSurfaceHTTPWire.setup(rawChild)
        await #expect(throws: (any Error).self) { try await c.automaticSurfaceChildState(parent: parent, childID: "00000000-0000-4000-8000-000000000002", isCurrent: { true }) }
        #expect(AutomaticSurfaceHTTPWire.captured.count == 1)
        for badID in ["../state", child.childID + "?role=other", child.childID.uppercased().replacingOccurrences(of: "4000", with: "7000"), String(repeating: "x", count: 100000)] {
            AutomaticSurfaceHTTPWire.setup(rawChild)
            await #expect(throws: (any Error).self) { try await c.automaticSurfaceChildState(parent: parent, childID: badID, isCurrent: { true }) }
            #expect(AutomaticSurfaceHTTPWire.captured.isEmpty)
        }
        AutomaticSurfaceHTTPWire.setup(rawChild)
        await #expect(throws: (any Error).self) { try await c.automaticSurfaceChildIndex(parent: parent, maximumChildren: 0, isCurrent: { true }) }
        #expect(AutomaticSurfaceHTTPWire.captured.isEmpty)
        let retired = try automaticChild(automaticChildText(parent: parent.coordinate, outcome: "RETIRED"), parent: parent.coordinate)
        await #expect(throws: (any Error).self) { try await c.automaticSurfaceChildReceipt(parent: parent, child: retired, isCurrent: { true }) }
        #expect(AutomaticSurfaceHTTPWire.captured.isEmpty)
    }

    @Test func bothRoleIndexesAndReceiptShareStatusCredentialAndOwnerFences() async throws {
        let c = client()
        for role in DJConnectAutomaticSurfaceRole.allCases {
            let parent = try automaticHTTPParent(role: role)
            AutomaticSurfaceHTTPWire.setup(automaticIndex([], parent: parent.coordinate))
            _ = try await c.automaticSurfaceChildIndex(parent: parent, maximumChildren: 1, isCurrent: { true })
            #expect(AutomaticSurfaceHTTPWire.captured.first?.url?.path == role.childIndexPath)
            #expect(AutomaticSurfaceHTTPWire.captured.first?.value(forHTTPHeaderField: "X-Ambient") == nil)
            AutomaticSurfaceHTTPWire.setup("{\"version\":1,\"state\":\"UNAVAILABLE\"}", status: 503)
            #expect(try await c.automaticSurfaceChildIndex(parent: parent, maximumChildren: 1, isCurrent: { true }) == .unavailable)
            AutomaticSurfaceHTTPWire.setup("{\"version\":1,\"state\":\"UNAVAILABLE\"}", status: 200)
            await #expect(throws: (any Error).self) { try await c.automaticSurfaceChildIndex(parent: parent, maximumChildren: 1, isCurrent: { true }) }
        }
        let parent = try automaticHTTPParent(), body = Data("unverified-fixture".utf8)
        let hash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        let child = try automaticChild(automaticChildText(parent: parent.coordinate, bodyHash: hash), parent: parent.coordinate)
        AutomaticSurfaceHTTPWire.setup(automaticReceipt(body: body))
        guard case .data(let value) = try await c.automaticSurfaceChildReceipt(parent: parent, child: child, isCurrent: { true }) else { Issue.record("Missing receipt"); return }
        #expect(value.classification == "UNVERIFIED_RECEIPT_DATA_ONLY")
        #expect(AutomaticSurfaceHTTPWire.captured.first?.url?.path == DJConnectAutomaticSurfaceRole.childReceiptPath(child.childID))
        AutomaticSurfaceHTTPWire.setup(automaticReceipt(body: body))
        await #expect(throws: (any Error).self) { try await c.automaticSurfaceChildReceipt(parent: parent, child: child, isCurrent: { false }) }
        #expect(AutomaticSurfaceHTTPWire.captured.isEmpty)
    }
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
