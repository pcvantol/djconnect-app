import Foundation
import Testing
#if os(iOS)
import XCTest
@testable import DJConnectUI
#endif
@testable import DJConnectCore

private let consentEpoch = String(repeating: "A", count: 43)
private let consentShare = String(repeating: "D", count: 42) + "A"
private final class ConsentAuthority: @unchecked Sendable {
    private let lock = NSLock(); private var value = true
    func get() -> Bool { lock.withLock { value } }
    func withdraw() { lock.withLock { value = false } }
    func restore() { lock.withLock { value = true } }
}
private final class ConsentWire: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var bootstrap: [String: Data] = [:]
    static func installBootstrap(_ responses: [String: Data]) { lock.withLock { bootstrap = responses } }
    nonisolated(unsafe) private static var mode = "normal"
    nonisolated(unsafe) private static var calls: [URLRequest] = []
    nonisolated(unsafe) private static var ownerReads = 0
    nonisolated(unsafe) private static var approvalAt: Date?
    nonisolated(unsafe) private static var approvalAction: (@Sendable () -> Void)?
    static func reset(_ mode: String = "normal") { lock.withLock { Self.mode = mode; bootstrap = [:]; calls = []; ownerReads = 0; approvalAction = nil; approvalAt = nil } }
    static var approvalStartedAt: Date? { lock.withLock { approvalAt } }
    static func onApproval(_ action: @escaping @Sendable () -> Void) { lock.withLock { approvalAction = action } }
    static var requests: [URLRequest] { lock.withLock { calls } }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "127.0.0.1" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        let (mode, count) = Self.lock.withLock {
            Self.calls.append(request)
            if path.hasSuffix("/owner/context") { Self.ownerReads += 1 }
            return (Self.mode, Self.ownerReads)
        }
        if let bytes = Self.lock.withLock({ Self.bootstrap[path] }) {
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200,
                httpVersion: nil, headerFields: ["Content-Type": "application/json", "Cache-Control": "no-store"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: bytes); client?.urlProtocolDidFinishLoading(self)
            return
        }
        var value: [String: Any] = ["success": true, "contract_version": 1]
        var status = 200
        func expiry(_ seconds: Double) -> String {
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.string(from: Date().addingTimeInterval(seconds))
        }
        if path.hasSuffix("/transport/context") {
            value.merge(["ha_install_id": "fixture-install", "requires_authenticated_tls": false,
                "operation_lifetime_ms": 300000, "operation_epoch": "fixture", "server_time_ms": 1000,
                "transport_security": ["policy_version": 1, "deployment_qualification_required": true,
                    "external": "authenticated_tls", "local_plaintext": "qualified_direct_only",
                    "peer_policy": "enabled_interface_subnet_or_loopback", "internal_origin_required": true,
                    "forwarded_plaintext": "forbidden", "mode": "qualified_direct_http"]]) { _, new in new }
            if mode == "wrong-install" { value["ha_install_id"] = "other" }
        } else if path.hasSuffix("/owner/context") {
            value.merge(["session_id": mode == "no-session" || (mode == "changed-session" && count > 1) ? "other-session" : "fixture-session",
                "display_entry_url": "https://ha.example.com/djconnect/vibecast/display", "route_trust": "paired_owner_response",
                "issuer_epoch": mode == "changed-epoch" && count > 1 ? String(repeating: "E", count: 42) + "A" : consentEpoch]) { _, new in new }
            if mode == "existing" || (mode == "new-share" && count > 1) {
                value.merge(["share_id": consentShare, "share_generation": 1, "expires_in": 3600.0, "expires_at": expiry(3600)]) { _, new in new }
            }
        } else if path.hasSuffix("/owner/resolve") {
            value.merge(["claim_id": String(repeating: "B", count: 42) + "A",
                "browser_generation": String(repeating: "C", count: 42) + "A", "issuer_epoch": consentEpoch,
                "expires_in": mode == "short-claim" ? 1.0 : 90.0, "expires_at": expiry(mode == "short-claim" ? 1.0 : 90)]) { _, new in new }
        } else if path.hasSuffix("/owner/approve") {
            Self.lock.withLock { Self.approvalAt = Date(); return Self.approvalAction }?()
            if mode == "unknown" { status = 503; value = [:] }
            else {
                value.merge(["state": "approved", "display_id": String(repeating: "F", count: 42) + "A",
                    "session_id": mode == "bad-receipt" ? "other-session" : "fixture-session",
                    "share_id": consentShare, "share_generation": 1,
                    "share_expires_in": mode == "short-receipt" ? 1.0 : 3599.0, "share_expires_at": expiry(mode == "short-absolute-receipt" ? 1.0 : 3599)]) { _, new in new }
            }
        } else { status = 404 }
        let bytes = try! JSONSerialization.data(withJSONObject: value)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status,
            httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: bytes); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@Suite(.serialized) @MainActor struct DisplayConsentSessionTests {
    private func make(_ mode: String = "normal") throws -> (DJConnectDisplayConsentSession, DJConnectInMemoryTokenStore, ConsentAuthority) {
        ConsentWire.reset(mode)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [ConsentWire.self]
        let store = DJConnectInMemoryTokenStore(token: "synthetic-owner")
        let origin = URL(string: "http://127.0.0.1:18801")!
        let client = DJConnectClient(baseURL: origin,
            identity: DJConnectIdentity(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Fixture", clientType: .ios, firmware: "test", platform: .ios),
            tokenStore: store, session: URLSession(configuration: config))
        let authority = ConsentAuthority()
        let flow = try DJConnectDisplayConsentSession(client: client, installationID: "fixture-install",
            sessionID: "fixture-session", pairedLocalOrigin: origin, isCurrent: { authority.get() })
        return (flow, store, authority)
    }
    @Test func lookupDoesNotApproveAndExplicitConfirmationSendsOneEffect() async throws {
        let (flow, _, _) = try make()
        try await flow.resolve(code: "000000")
        #expect(flow.state == .ready && flow.resolvedClaim != nil)
        #expect(ConsentWire.requests.count == 3)
        #expect(!ConsentWire.requests.contains { $0.url!.path.hasSuffix("/approve") })
        let receipt = try await flow.approve(share: .createTwoHours)
        #expect(flow.state == .approved && receipt.sessionID == "fixture-session")
        #expect(ConsentWire.requests.count == 6)
        #expect(ConsentWire.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-owner" })
        await #expect(throws: (any Error).self) { _ = try await flow.approve(share: .createTwoHours) }
        #expect(ConsentWire.requests.count == 6)
    }
    @Test func unknownOrMismatchedApprovalNeverReplays() async throws {
        for mode in ["unknown", "bad-receipt"] {
            let (flow, _, _) = try make(mode); try await flow.resolve(code: "000000")
            await #expect(throws: (any Error).self) { _ = try await flow.approve(share: .createTwoHours) }
            #expect(flow.state == .uncertain && flow.receipt == nil)
            let count = ConsentWire.requests.count
            await #expect(throws: (any Error).self) { _ = try await flow.approve(share: .createTwoHours) }
            #expect(ConsentWire.requests.count == count)
            #expect(ConsentWire.requests.filter { $0.url!.path.hasSuffix("/approve") }.count == 1)
        }
    }
    @Test func freshContextChangeCannotApproveOldClaim() async throws {
        for mode in ["changed-session", "changed-epoch", "new-share"] {
            let (flow, _, _) = try make(mode); try await flow.resolve(code: "000000")
            await #expect(throws: (any Error).self) { _ = try await flow.approve(share: .createTwoHours) }
            #expect(flow.state == .unavailable)
            #expect(!ConsentWire.requests.contains { $0.url!.path.hasSuffix("/approve") })
        }
    }
    @Test func existingShareRequiresExactOfferedBinding() async throws {
        let (flow, _, _) = try make("existing"); try await flow.resolve(code: "000000")
        #expect(flow.existingShare?.identifier == consentShare)
        let receipt = try await flow.approve(share: .existing(id: consentShare, generation: 1))
        #expect(receipt.shareID == consentShare)
        for choice: DJConnectDisplayClaim.Share in [.createTwoHours, .existing(id: consentShare, generation: 2)] {
            let (other, _, _) = try make("existing"); try await other.resolve(code: "000000")
            await #expect(throws: (any Error).self) { _ = try await other.approve(share: choice) }
            #expect(!ConsentWire.requests.contains { $0.url!.path.hasSuffix("/approve") })
        }
    }
    @Test func ownerTokenAndDismissalWithdrawBeforeAnyMoreIO() async throws {
        for kind in ["owner", "token", "dismiss"] {
            let (flow, store, authority) = try make(); try await flow.resolve(code: "000000")
            if kind == "owner" { authority.withdraw() }
            if kind == "token" { try store.saveToken("replacement") }
            if kind == "dismiss" { flow.withdraw() }
            let count = ConsentWire.requests.count
            await #expect(throws: (any Error).self) { _ = try await flow.approve(share: .createTwoHours) }
            #expect(ConsentWire.requests.count == count)
        }
    }
    @Test func ownerWithdrawalAfterPossibleApprovalWithholdsReceipt() async throws {
        let (flow, _, authority) = try make(); try await flow.resolve(code: "000000")
        ConsentWire.onApproval { authority.withdraw() }
        await #expect(throws: (any Error).self) { _ = try await flow.approve(share: .createTwoHours) }
        #expect(flow.state == .uncertain && flow.receipt == nil && flow.resolvedClaim == nil)
        #expect(ConsentWire.requests.filter { $0.url!.path.hasSuffix("/approve") }.count == 1)
    }
    @Test func expiredClaimWithdrawsWithoutOwnerReadOrApproval() async throws {
        let (flow, _, _) = try make("short-claim"); try await flow.resolve(code: "000000")
        let count = ConsentWire.requests.count
        try await Task.sleep(for: .milliseconds(1200))
        await #expect(throws: (any Error).self) { _ = try await flow.approve(share: .createTwoHours) }
        #expect(flow.state == .unavailable && flow.resolvedClaim == nil)
        #expect(ConsentWire.requests.count == count)
    }
    @Test func reportedRemainingLifetimeBoundsReceipt() async throws {
        let (flow, _, _) = try make("short-receipt"); try await flow.resolve(code: "000000")
        let receipt = try await flow.approve(share: .createTwoHours)
        let dispatched = try #require(ConsentWire.approvalStartedAt)
        #expect(receipt.expiresAt <= dispatched.addingTimeInterval(1))
        #expect(receipt.isCurrent())
        #expect(!receipt.isCurrent(now: receipt.expiresAt, uptime: ProcessInfo.processInfo.systemUptime))
        #expect(!receipt.isCurrent(now: Date().addingTimeInterval(-10), uptime: ProcessInfo.processInfo.systemUptime))
        #expect(!receipt.isCurrent(now: Date(), uptime: ProcessInfo.processInfo.systemUptime + 2))
        #expect(!receipt.isCurrent(now: Date(), uptime: 0))
        #expect(!receipt.isCurrent(now: Date(), uptime: .infinity))
        try await Task.sleep(for: .milliseconds(1100))
        #expect(!receipt.isCurrent())
        #expect(flow.receipt == nil)
    }
    @Test func earlierAbsoluteReceiptExpiryAlsoBoundsMonotonicTime() async throws {
        let (flow, _, _) = try make("short-absolute-receipt")
        try await flow.resolve(code: "000000")
        let receipt = try await flow.approve(share: .createTwoHours)
        let originalWall = Date(), originalTick = ProcessInfo.processInfo.systemUptime
        #expect(receipt.isCurrent())
        // Wall clock restored inside the original valid interval after the
        // shorter absolute expiry has passed in monotonic time.
        #expect(!receipt.isCurrent(now: originalWall, uptime: originalTick + 2))
    }
    @Test func completedReceiptCannotOutliveOwnerOrToken() async throws {
        for kind in ["owner", "token", "dismiss"] {
            let (flow, store, authority) = try make(); try await flow.resolve(code: "000000")
            let retained = try await flow.approve(share: .createTwoHours)
            #expect(flow.receipt != nil && retained.isCurrent())
            if kind == "owner" { authority.withdraw() }
            if kind == "token" { try store.saveToken("replacement") }
            if kind == "dismiss" { flow.withdraw() }
            #expect(!retained.isCurrent())
            #expect(flow.receipt == nil)
            if kind == "owner" { authority.restore() }
            if kind == "token" { try store.saveToken("synthetic-owner") }
            #expect(!retained.isCurrent())
            #expect(flow.receipt == nil && flow.state == .unavailable)
        }
    }
    @Test func concurrentConfirmationsCannotSendTwoApprovals() async throws {
        let (flow, _, _) = try make(); try await flow.resolve(code: "000000")
        let first = Task { try await flow.approve(share: .createTwoHours) }
        for _ in 0..<100 where flow.state == .ready { await Task.yield() }
        #expect(flow.state == .approving || flow.state == .approved)
        await #expect(throws: (any Error).self) { _ = try await flow.approve(share: .createTwoHours) }
        _ = try await first.value
        #expect(ConsentWire.requests.filter { $0.url!.path.hasSuffix("/approve") }.count == 1)
    }
    @Test func badCodeOrWrongInstallationAndSessionCannotResolve() async throws {
        let (flow, _, _) = try make()
        await #expect(throws: (any Error).self) { try await flow.resolve(code: "１２３４５６") }
        #expect(ConsentWire.requests.isEmpty)
        for mode in ["wrong-install", "no-session"] {
            let (other, _, _) = try make(mode)
            await #expect(throws: (any Error).self) { try await other.resolve(code: "000000") }
            #expect(other.resolvedClaim == nil)
            #expect(!ConsentWire.requests.contains { $0.url!.path.hasSuffix("/resolve") })
        }
    }
}

@Test func displayWireDatesAcceptFractionalAndWholeSecondISO() {
    #expect(displayWireDate("2026-10-20T16:00:00+00:00") != nil)
    #expect(displayWireDate("2026-10-20T16:00:00.123456+00:00") != nil)
    #expect(displayWireDate("not-a-date") == nil)
}

#if os(iOS)
private final class NativeConsentFixtureBundle: NSObject {}

/// Actual iOS AppModel over a URLProtocol wire. Synthetic isolated owner/HTTP
/// responses, not installed HA, native taps, App Attest or physical acceptance.
extension DisplayConsentSessionTests {
    private func makeNativeModel(_ mode: String = "normal") async throws -> (DJConnectAppModel, UserDefaults, String, DJConnectInMemoryTokenStore) {
        ConsentWire.reset(mode)
        func fixture(_ name: String) throws -> [String: Any] {
            let url = try #require(Bundle(for: NativeConsentFixtureBundle.self).url(forResource: name, withExtension: "json"))
            return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        }
        var session = try #require(fixture("session-history-active-session-before-auth-failure")["response"] as? [String: Any])
        // The fixture's producer bytes stay unchanged on disk. Only the wire's
        // synthetic Session identifier is rebound to the existing consent fixture.
        func rebind(_ value: Any) -> Any {
            if let text = value as? String, text.hasPrefix("session-6cf3c555") { return "fixture-session" }
            if let dict = value as? [String: Any] { return dict.mapValues(rebind) }
            if let array = value as? [Any] { return array.map(rebind) }
            return value
        }
        session = try #require(rebind(session) as? [String: Any])
        let history = try #require(fixture("session-history-producer-receipt")["later_historical_answer"])
        let caps: [String: Any] = ["capabilities": ["session_conversation_history": true, "session_flow_text_search": true],
            "contract_versions": ["session_conversation_history": 1, "session_flow_text_search": 1]]
        ConsentWire.installBootstrap(try ["/api/djconnect/v1/session/active": JSONSerialization.data(withJSONObject: session),
            "/api/djconnect/v1/capabilities": JSONSerialization.data(withJSONObject: caps),
            "/api/djconnect/v1/ask_dj/history": JSONSerialization.data(withJSONObject: history)])
        let suite = "native-display-consent-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.set("http://127.0.0.1:18801", forKey: "DJConnectHomeAssistantURL")
        defaults.set("http://127.0.0.1:18801", forKey: "DJConnectHALocalURL")
        let store = DJConnectInMemoryTokenStore(token: "synthetic-owner")
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [ConsentWire.self]
        let model = DJConnectAppModel(defaults: defaults, tokenStore: store,
            urlSession: URLSession(configuration: config), startBackgroundTasks: false)
        model.pairingStatus = .paired
        #expect(model.identity.clientType == .ios)
        #expect(await model.refreshActiveDJSession())
        await model.sessionHistory.prepare()
        #expect(model.activeDJSession?.id == "fixture-session")
        #expect(model.sessionHistory.authorizedProfileID == "profile-a")
        defaults.set("fixture-install", forKey: "DJConnectHAInstallID")
        #expect(model.canResolveDisplayConsent)
        return (model, defaults, suite, store)
    }

    @Test func actualIOSModelLookupThenExplicitConfirmation() async throws {
        let (model, defaults, suite, _) = try await makeNativeModel()
        defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
        await model.resolveDisplayConsent(code: "000000")
        #expect(model.displayConsentState == .ready)
        #expect(!ConsentWire.requests.contains { $0.url?.path.hasSuffix("/owner/approve") == true })
        await model.approveDisplayConsent()
        #expect(model.displayConsentState == .approved)
        await model.approveDisplayConsent()
        #expect(ConsentWire.requests.filter { $0.url?.path.hasSuffix("/owner/approve") == true }.count == 1)
    }

    @Test func actualIOSModelWithdrawalPreventsLateApproval() async throws {
        for reason in ["dismiss", "background", "profile", "token", "route", "installation", "pairing", "session"] {
            let (model, defaults, suite, store) = try await makeNativeModel()
            defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
            await model.resolveDisplayConsent(code: "000000")
            #expect(model.displayConsentState == .ready)
            switch reason {
            case "session":
                ConsentWire.installBootstrap(["/api/djconnect/v1/session/active": Data(#"{"success":true,"session":null}"#.utf8)])
                #expect(await model.refreshActiveDJSession())
                #expect(model.activeDJSession == nil)
            case "dismiss": model.cancelDisplayConsent()
            case "background": model.markInactiveSession()
            case "profile": model.sessionHistory.suspend()
            case "token": try store.saveToken("replacement")
            case "route": model.homeAssistantURL = "https://different.invalid"
            case "installation": defaults.set("replacement-install", forKey: "DJConnectHAInstallID")
            default: model.pairingStatus = .unpaired
            }
            await model.approveDisplayConsent()
            #expect(model.displayConsentState != .approved)
            #expect(!ConsentWire.requests.contains { $0.url?.path.hasSuffix("/owner/approve") == true })
        }
    }

    @Test func actualIOSModelUnknownApprovalDoesNotReplay() async throws {
        let (model, defaults, suite, _) = try await makeNativeModel("unknown")
        defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
        await model.resolveDisplayConsent(code: "000000")
        #expect(model.displayConsentState == .ready)
        await model.approveDisplayConsent()
        #expect(model.displayConsentState == .uncertain)
        await model.approveDisplayConsent()
        #expect(ConsentWire.requests.filter { $0.url?.path.hasSuffix("/owner/approve") == true }.count == 1)
    }

    @Test func actualIOSModelExistingSharePreservesOriginalChoice() async throws {
        let (model, defaults, suite, _) = try await makeNativeModel("existing")
        defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
        await model.resolveDisplayConsent(code: "000000")
        #expect(model.displayConsentState == .ready)
        #expect(model.displayConsentExistingShare?.identifier == consentShare)
        #expect(model.displayConsentExistingShare?.generation == 1)
        await model.approveDisplayConsent()
        #expect(model.displayConsentState == .approved)
        #expect(ConsentWire.requests.filter { $0.url?.path.hasSuffix("/owner/approve") == true }.count == 1)
    }

    @Test func actualIOSModelApprovedPresentationWithdrawsWithOwner() async throws {
        let (model, defaults, suite, _) = try await makeNativeModel()
        defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
        await model.resolveDisplayConsent(code: "000000")
        await model.approveDisplayConsent()
        #expect(model.displayConsentState == .approved)
        model.sessionHistory.suspend()
        model.refreshDisplayConsentPresentation()
        #expect(model.displayConsentState == .unavailable)
        #expect(model.displayConsentExistingShare == nil)
        await model.approveDisplayConsent()
        #expect(ConsentWire.requests.filter { $0.url?.path.hasSuffix("/owner/approve") == true }.count == 1)
    }

}
#endif
