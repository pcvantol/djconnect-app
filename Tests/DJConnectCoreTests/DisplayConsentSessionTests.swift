import Foundation
import Testing
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
    nonisolated(unsafe) private static var mode = "normal"
    nonisolated(unsafe) private static var calls: [URLRequest] = []
    nonisolated(unsafe) private static var ownerReads = 0
    nonisolated(unsafe) private static var approvalAt: Date?
    nonisolated(unsafe) private static var approvalAction: (@Sendable () -> Void)?
    static func reset(_ mode: String = "normal") { lock.withLock { Self.mode = mode; calls = []; ownerReads = 0; approvalAction = nil; approvalAt = nil } }
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
                    "share_expires_in": mode == "short-receipt" ? 1.0 : 3599.0, "share_expires_at": expiry(3599)]) { _, new in new }
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
        #expect(!receipt.isCurrent(now: receipt.expiresAt))
        #expect(!receipt.isCurrent(now: Date().addingTimeInterval(-10)))
        #expect(!receipt.isCurrent(uptime: ProcessInfo.processInfo.systemUptime + 2))
        #expect(!receipt.isCurrent(uptime: 0))
        #expect(!receipt.isCurrent(uptime: .infinity))
    }
    @Test func completedReceiptCannotOutliveOwnerOrToken() async throws {
        for kind in ["owner", "token", "dismiss"] {
            let (flow, store, authority) = try make(); try await flow.resolve(code: "000000")
            _ = try await flow.approve(share: .createTwoHours)
            #expect(flow.receipt != nil)
            if kind == "owner" { authority.withdraw() }
            if kind == "token" { try store.saveToken("replacement") }
            if kind == "dismiss" { flow.withdraw() }
            #expect(flow.receipt == nil)
            if kind == "owner" { authority.restore() }
            if kind == "token" { try store.saveToken("synthetic-owner") }
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
