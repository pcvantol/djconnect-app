import Foundation
import Testing
#if os(iOS)
import UIKit
import SwiftUI
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
            // Opt-in lifecycle probe only: retain the ordinary approval receipt.
            if mode == "delayed-approval" { Thread.sleep(forTimeInterval: 2) }
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
    private func makeNativeModel(_ mode: String = "normal", summaryArchive: Bool = false) async throws -> (DJConnectAppModel, UserDefaults, String, DJConnectInMemoryTokenStore) {
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
        var caps: [String: Any] = ["capabilities": ["session_conversation_history": true, "session_flow_text_search": true],
            "contract_versions": ["session_conversation_history": 1, "session_flow_text_search": 1]]
        if summaryArchive {
            var flags = try #require(caps["capabilities"] as? [String: Any])
            var versions = try #require(caps["contract_versions"] as? [String: Any])
            flags["session_history_summary"] = true; versions["session_history_summary"] = 1
            caps["capabilities"] = flags; caps["contract_versions"] = versions
        }
        var bootstrap = try ["/api/djconnect/v1/session/active": JSONSerialization.data(withJSONObject: session),
            "/api/djconnect/v1/capabilities": JSONSerialization.data(withJSONObject: caps),
            "/api/djconnect/v1/ask_dj/history": JSONSerialization.data(withJSONObject: history)]
        if summaryArchive {
            bootstrap["/api/djconnect/v1/session/history"] = try JSONSerialization.data(withJSONObject:
                #require(fixture("session-history-summary-final-list")["body"] as? [String: Any]))
        }
        ConsentWire.installBootstrap(bootstrap)
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

    /// Bounded visual observation of the actual withdrawn archive's empty copy.
    /// It does not replace the separate, incomplete full archive qualification.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_ARCHIVE_EMPTY_COPY_DIR"] != nil))
    func actualIOSNativeWithdrawnArchiveCopy() async throws {
        let (model, defaults, suite, _) = try await makeNativeModel(summaryArchive: true)
        defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
        #expect(await model.sessionHistory.loadSessions())
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["DJCONNECT_ARCHIVE_EMPTY_COPY_DIR"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let controller = UIHostingController(rootView: SavedSessionsView(model: model)
            .environment(\.colorScheme, .dark).preferredColorScheme(.dark))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 932))
        window.backgroundColor = .black; window.overrideUserInterfaceStyle = .dark
        window.rootViewController = controller; window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(650))
        model.sessionHistory.suspend()
        try await Task.sleep(for: .milliseconds(450))
        #expect(model.sessionHistory.authorizedProfileID == nil)
        #expect(model.sessionHistory.sessions.isEmpty && !model.sessionHistory.summaryAvailable)
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in window.layer.render(in: context.cgContext) }
        try #require(image.pngData()).write(to: folder.appendingPathComponent("archive-withdrawn-copy.png"))
        let routes = ConsentWire.requests.map { ($0.httpMethod ?? "GET") + " " + ($0.url?.path ?? "") }
        try JSONSerialization.data(withJSONObject: ["owner": model.sessionHistory.authorizedProfileID ?? "",
            "sessions": model.sessionHistory.sessions.count, "summary_available": model.sessionHistory.summaryAvailable,
            "preparing": model.sessionHistory.preparing, "request_routes": routes], options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("archive-withdrawn-copy.json"))
    }

    /// Actual archive list over the qualified owner and unchanged summary fixture.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_NATIVE_ARCHIVE_DIR"] != nil))
    func actualIOSNativeArchiveSummaryWithdrawal() async throws {
        let (model, defaults, suite, _) = try await makeNativeModel(summaryArchive: true)
        defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
        let session = try #require(model.activeDJSession)
        #expect(await model.sessionHistory.loadSessions())
        let saved = try #require(model.sessionHistory.sessions.first)
        let admitted = try #require(saved.summary)
        #expect(model.sessionHistory.summaryAvailable && model.sessionHistory.authorizedProfileID == "profile-a")
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["DJCONNECT_NATIVE_ARCHIVE_DIR"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let controller = UIHostingController(rootView: SavedSessionsView(model: model)
            .environment(\.colorScheme, .dark).preferredColorScheme(.dark))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 932))
        window.backgroundColor = .black; window.overrideUserInterfaceStyle = .dark
        window.rootViewController = controller; window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        func archiveReads() -> [URLRequest] {
            ConsentWire.requests.filter { $0.url?.path == "/api/djconnect/v1/session/history" }
        }
        var observations: [[String: Any]] = []
        func capture(_ name: String) throws {
            window.layoutIfNeeded()
            observations.append(["stage": name, "summary_available": model.sessionHistory.summaryAvailable,
                "owner": model.sessionHistory.authorizedProfileID ?? "", "session_count": model.sessionHistory.sessions.count,
                "archive_reads": archiveReads().count, "preparing": model.sessionHistory.preparing])
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in window.layer.render(in: context.cgContext) }
            try #require(image.pngData()).write(to: folder.appendingPathComponent(name + ".png"))
        }
        try await Task.sleep(for: .milliseconds(650))
        #expect(model.sessionHistory.sessions.count == 1)
        #expect(model.sessionHistory.sessions.first?.summary == admitted)
        try capture("archive-01-authorized")
        let readsBefore = archiveReads().count
        model.sessionHistory.suspend()
        #expect(!(await model.sessionHistory.loadSessions()), "Ownerless archive reads must not restart after suspension")
        try await Task.sleep(for: .milliseconds(350))
        #expect(model.sessionHistory.authorizedProfileID == nil && !model.sessionHistory.summaryAvailable)
        #expect(model.sessionHistory.sessions.isEmpty)
        #expect(archiveReads().count == readsBefore)
        try capture("archive-02-withdrawn")
        // Explicit synthetic owner requalification; no automatic retry is claimed.
        await model.sessionHistory.restoreVisibleSessions()
        try await Task.sleep(for: .milliseconds(200))
        #expect(model.sessionHistory.authorizedProfileID == "profile-a" && model.sessionHistory.summaryAvailable)
        #expect(model.sessionHistory.sessions.first?.id == saved.id)
        #expect(model.sessionHistory.sessions.first?.summary == admitted)
        #expect(archiveReads().allSatisfy { $0.httpMethod == "GET" })
        #expect(!ConsentWire.requests.contains { $0.httpMethod != "GET" })
        #expect(model.activeDJSession?.id == session.id)
        #expect(model.activeDJSession?.broadcast.playback == session.broadcast.playback)
        try capture("archive-03-reauthorized")
        try JSONSerialization.data(withJSONObject: observations, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("native-archive-withdrawal.json"))
    }

    /// Public UIKeyInput insertion, without directly invoking the delegate.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_NATIVE_KEYINPUT_DIR"] != nil))
    func actualIOSNativeCodeUIKeyInput() async throws {
        let (model, defaults, suite, _) = try await makeNativeModel()
        defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
        let session = try #require(model.activeDJSession)
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["DJCONNECT_NATIVE_KEYINPUT_DIR"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let controller = UIHostingController(rootView: VibeCastDisplayConsentForm(model: model)
            .environment(\.colorScheme, .dark).preferredColorScheme(.dark))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 932))
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = controller; window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        try await Task.sleep(for: .milliseconds(350))
        let fields = descendants(controller.view).compactMap { $0 as? UITextField }
            .filter { $0.accessibilityIdentifier?.hasPrefix("vibecast-handoff-digit-") == true }.sorted { $0.tag < $1.tag }
        try #require(fields.count == 6)
        var observations: [[String: Any]] = []
        func capture(_ name: String) throws {
            window.layoutIfNeeded()
            observations.append(["stage": name, "digits": fields.map { $0.text ?? "" },
                "focused_index": fields.firstIndex { $0.isFirstResponder } ?? -1])
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in window.layer.render(in: context.cgContext) }
            try #require(image.pngData()).write(to: folder.appendingPathComponent(name + ".png"))
        }
        fields[0].becomeFirstResponder()
        for (index, digit) in "123456".enumerated() {
            let focused = try #require(fields.first { $0.isFirstResponder })
            focused.insertText(String(digit))
            try await Task.sleep(for: .milliseconds(60))
            #expect(fields[index].text == String(digit))
            #expect(fields[min(5, index + 1)].isFirstResponder)
        }
        #expect(fields.map { $0.text ?? "" } == ["1", "2", "3", "4", "5", "6"])
        try capture("keyinput-01-sequential")
        fields[3].becomeFirstResponder(); fields[3].insertText("654321")
        try await Task.sleep(for: .milliseconds(100))
        #expect(fields.map { $0.text ?? "" } == ["6", "5", "4", "3", "2", "1"])
        #expect(fields[5].isFirstResponder)
        fields[2].becomeFirstResponder()
        fields[2].selectedTextRange = fields[2].textRange(from: fields[2].beginningOfDocument, to: fields[2].endOfDocument)
        fields[2].insertText("9")
        try await Task.sleep(for: .milliseconds(100))
        #expect(fields.map { $0.text ?? "" } == ["6", "5", "9", "3", "2", "1"])
        #expect(fields[3].isFirstResponder)
        try capture("keyinput-02-replaced")
        fields[5].deleteBackward(); fields[5].deleteBackward()
        try await Task.sleep(for: .milliseconds(100))
        #expect(fields.map { $0.text ?? "" } == ["6", "5", "9", "3", "", ""])
        #expect(fields[4].isFirstResponder)
        fields[4].insertText("９x")
        try await Task.sleep(for: .milliseconds(80))
        #expect(fields.map { $0.text ?? "" } == ["6", "5", "9", "3", "", ""])
        #expect(fields[4].isFirstResponder)
        model.applySessionBroadcastSnapshot(session.broadcast)
        try await Task.sleep(for: .milliseconds(100))
        #expect(fields.map { $0.text ?? "" } == ["6", "5", "9", "3", "", ""])
        #expect(model.activeDJSession?.id == session.id)
        #expect(model.activeDJSession?.broadcast.playback == session.broadcast.playback)
        #expect(model.displayConsentState == .idle)
        #expect(!ConsentWire.requests.contains { $0.url?.path.contains("/owner/") == true })
        try capture("keyinput-03-backspace-invalid-and-update")
        try JSONSerialization.data(withJSONObject: observations, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("native-keyinput.json"))
    }

    /// Real native hierarchy removal must run the production disappearance fence.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_CONSENT_LIFECYCLE_DIR"] != nil))
    func actualIOSNativeConsentFormLifecycle() async throws {
        let (model, defaults, suite, _) = try await makeNativeModel()
        defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
        let session = try #require(model.activeDJSession)
        let epoch = model.sessionHistory.responseEpoch
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["DJCONNECT_CONSENT_LIFECYCLE_DIR"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        func makeController() -> UIViewController {
            UIHostingController(rootView: VibeCastDisplayConsentForm(model: model)
                .environment(\.colorScheme, .dark).preferredColorScheme(.dark))
        }
        let firstController = makeController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 932))
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = firstController; window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        func fields() -> [UITextField] {
            descendants(window).compactMap { $0 as? UITextField }
                .filter { $0.accessibilityIdentifier?.hasPrefix("vibecast-handoff-digit-") == true }.sorted { $0.tag < $1.tag }
        }
        var observations: [[String: Any]] = []
        func capture(_ name: String) throws {
            window.layoutIfNeeded()
            observations.append(["stage": name, "state": String(describing: model.displayConsentState),
                "field_count": fields().count, "digits": fields().map { $0.text ?? "" },
                "owner_request_count": ConsentWire.requests.filter { $0.url?.path.contains("/owner/") == true }.count])
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in window.layer.render(in: context.cgContext) }
            try #require(image.pngData()).write(to: folder.appendingPathComponent(name + ".png"))
        }
        try await Task.sleep(for: .milliseconds(350))
        let first = try #require(fields().first)
        _ = first.delegate?.textField?(first, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "000000")
        try await Task.sleep(for: .milliseconds(100))
        await model.resolveDisplayConsent(code: "000000") // Explicit model lookup, not a native button tap.
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.displayConsentState == .ready)
        try capture("lifecycle-01-ready")
        let ownerRequests = ConsentWire.requests.filter { $0.url?.path.contains("/owner/") == true }.count
        // Keep the old controller alive: cancellation must follow disappearance,
        // not rely on its deallocation or a manual model cancellation call.
        window.rootViewController = UIViewController()
        try await Task.sleep(for: .milliseconds(350))
        #expect(firstController.view.window == nil)
        #expect(model.displayConsentState == .unavailable)
        #expect(fields().isEmpty)
        try capture("lifecycle-02-removed")
        await model.approveDisplayConsent()
        #expect(!ConsentWire.requests.contains { $0.url?.path.hasSuffix("/owner/approve") == true })
        let secondController = makeController()
        window.rootViewController = secondController
        try await Task.sleep(for: .milliseconds(350))
        #expect(model.displayConsentState == .idle && model.canResolveDisplayConsent)
        #expect(fields().count == 6 && fields().allSatisfy(\.isEnabled))
        #expect(fields().allSatisfy { ($0.text ?? "").isEmpty })
        #expect(ConsentWire.requests.filter { $0.url?.path.contains("/owner/") == true }.count == ownerRequests)
        #expect(model.sessionHistory.responseEpoch == epoch)
        #expect(model.activeDJSession?.id == session.id)
        #expect(model.activeDJSession?.broadcast.playback == session.broadcast.playback)
        try capture("lifecycle-03-remounted")
        try JSONSerialization.data(withJSONObject: observations, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("native-consent-lifecycle.json"))
    }

    /// Hierarchy disappearance while a synthetic approval acknowledgement is delayed.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_CONSENT_INFLIGHT_DIR"] != nil))
    func actualIOSNativeConsentInflightLifecycle() async throws {
        let (model, defaults, suite, _) = try await makeNativeModel("delayed-approval")
        defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
        let session = try #require(model.activeDJSession)
        let epoch = model.sessionHistory.responseEpoch
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["DJCONNECT_CONSENT_INFLIGHT_DIR"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        func makeController() -> UIViewController {
            UIHostingController(rootView: VibeCastDisplayConsentForm(model: model)
                .environment(\.colorScheme, .dark).preferredColorScheme(.dark))
        }
        let firstController = makeController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 932))
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = firstController; window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        func fields() -> [UITextField] {
            descendants(window).compactMap { $0 as? UITextField }
                .filter { $0.accessibilityIdentifier?.hasPrefix("vibecast-handoff-digit-") == true }.sorted { $0.tag < $1.tag }
        }
        var observations: [[String: Any]] = []
        var approvalCompleted = false
        func capture(_ name: String) throws {
            window.layoutIfNeeded()
            observations.append(["stage": name, "state": String(describing: model.displayConsentState),
                "approval_completed": approvalCompleted, "digits": fields().map { $0.text ?? "" },
                "enabled": fields().map(\.isEnabled),
                "approval_posts": ConsentWire.requests.filter { $0.url?.path.hasSuffix("/owner/approve") == true }.count])
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { window.layer.render(in: $0.cgContext) }
            try #require(image.pngData()).write(to: folder.appendingPathComponent(name + ".png"))
        }
        try await Task.sleep(for: .milliseconds(350))
        let first = try #require(fields().first)
        first.insertText("000000")
        try await Task.sleep(for: .milliseconds(100))
        await model.resolveDisplayConsent(code: "000000") // Model method, not a native tap.
        try #require(model.displayConsentState == .ready)
        let approval = Task { await model.approveDisplayConsent(); approvalCompleted = true }
        for _ in 0..<50 where ConsentWire.approvalStartedAt == nil { try await Task.sleep(for: .milliseconds(10)) }
        try #require(ConsentWire.approvalStartedAt != nil && !approvalCompleted)
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.displayConsentState == .approving)
        try capture("inflight-01-approving")
        window.rootViewController = UIViewController() // Keep the first controller alive.
        try await Task.sleep(for: .milliseconds(150))
        #expect(firstController.view.window == nil && model.displayConsentState == .uncertain)
        #expect(!approvalCompleted && fields().isEmpty)
        try capture("inflight-02-removed")
        window.rootViewController = makeController()
        try await Task.sleep(for: .milliseconds(350))
        #expect(!approvalCompleted && model.displayConsentState == .idle)
        #expect(fields().count == 6 && fields().allSatisfy { ($0.text ?? "").isEmpty && $0.isEnabled })
        try capture("inflight-03-remounted-before-ack")
        await approval.value
        try await Task.sleep(for: .milliseconds(100))
        #expect(approvalCompleted && model.displayConsentState == .idle)
        await model.approveDisplayConsent()
        #expect(ConsentWire.requests.filter { $0.url?.path.hasSuffix("/owner/approve") == true }.count == 1)
        #expect(ConsentWire.requests.filter { $0.url?.path.hasSuffix("/owner/resolve") == true }.count == 1)
        #expect(model.sessionHistory.responseEpoch == epoch && model.activeDJSession?.id == session.id)
        #expect(model.activeDJSession?.broadcast.playback == session.broadcast.playback)
        #expect(fields().allSatisfy { ($0.text ?? "").isEmpty })
        try capture("inflight-04-late-ack-ignored")
        try JSONSerialization.data(withJSONObject: observations, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("native-consent-inflight.json"))
    }

    /// The production form refresh task must remove expired claim/receipt UI.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_CONSENT_EXPIRY_DIR"] != nil))
    func actualIOSNativeConsentExpiryPresentation() async throws {
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["DJCONNECT_CONSENT_EXPIRY_DIR"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var observations: [[String: Any]] = []
        for mode in ["short-claim", "short-receipt"] {
            let (model, defaults, suite, _) = try await makeNativeModel(mode)
            defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
            let session = try #require(model.activeDJSession)
            let epoch = model.sessionHistory.responseEpoch
            let root = VibeCastDisplayConsentForm(model: model)
                .environment(\.colorScheme, .dark).preferredColorScheme(.dark)
            let controller = UIHostingController(rootView: root)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 932))
            window.overrideUserInterfaceStyle = .dark
            window.rootViewController = controller; window.makeKeyAndVisible()
            defer { window.isHidden = true; window.rootViewController = nil }
            func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
            func fields() -> [UITextField] {
                descendants(controller.view).compactMap { $0 as? UITextField }
                    .filter { $0.accessibilityIdentifier?.hasPrefix("vibecast-handoff-digit-") == true }.sorted { $0.tag < $1.tag }
            }
            func capture(_ stage: String) throws -> [UITextField] {
                window.layoutIfNeeded()
                let values = fields()
                observations.append(["mode": mode, "stage": stage, "time": Date().timeIntervalSince1970,
                    "state": String(describing: model.displayConsentState), "enabled": values.map(\.isEnabled),
                    "digits": values.map { $0.text ?? "" }, "request_count": ConsentWire.requests.count,
                    "request_routes": ConsentWire.requests.map { ($0.httpMethod ?? "GET") + " " + ($0.url?.path ?? "") },
                    "owner_request_count": ConsentWire.requests.filter { $0.url?.path.contains("/owner/") == true }.count])
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in window.layer.render(in: context.cgContext) }
                try #require(image.pngData()).write(to: folder.appendingPathComponent(mode + "-" + stage + ".png"))
                return values
            }
            try await Task.sleep(for: .milliseconds(350))
            let first = try #require(fields().first)
            _ = first.delegate?.textField?(first, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "000000")
            try await Task.sleep(for: .milliseconds(100))
            // Explicit model transitions, not native button taps.
            await model.resolveDisplayConsent(code: "000000")
            #expect(model.displayConsentState == .ready)
            if mode == "short-receipt" { await model.approveDisplayConsent() }
            try await Task.sleep(for: .milliseconds(100))
            #expect(model.displayConsentState == (mode == "short-claim" ? .ready : .approved))
            let before = try capture("before-expiry")
            #expect(before.count == 6 && before.allSatisfy { !$0.isEnabled })
            let requestsBefore = ConsentWire.requests.filter { $0.url?.path.contains("/owner/") == true }.count
            // Real clocks only; the mounted production form's 250 ms task
            // performs its ordinary refresh. No model refresh/getter injection.
            try await Task.sleep(for: .milliseconds(1500))
            let after = try capture("after-expiry")
            #expect(model.displayConsentState == .unavailable)
            #expect(after.count == 6 && after.allSatisfy(\.isEnabled))
            #expect(after.map { $0.text ?? "" } == Array(repeating: "0", count: 6))
            #expect(ConsentWire.requests.filter { $0.url?.path.contains("/owner/") == true }.count == requestsBefore)
            #expect(ConsentWire.requests.filter { $0.url?.path.hasSuffix("/owner/approve") == true }.count == (mode == "short-claim" ? 0 : 1))
            #expect(model.canResolveDisplayConsent)
            #expect(model.sessionHistory.responseEpoch == epoch)
            #expect(model.activeDJSession?.id == session.id)
            #expect(model.activeDJSession?.broadcast.playback == session.broadcast.playback)
        }
        try JSONSerialization.data(withJSONObject: observations, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("native-consent-expiry.json"))
    }

    /// Native input controls must follow the production form's disabled states.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_CONSENT_INPUT_STATES_DIR"] != nil))
    func actualIOSNativeInputConsentStates() async throws {
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["DJCONNECT_CONSENT_INPUT_STATES_DIR"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var observations: [[String: Any]] = []
        for mode in ["normal", "unknown"] {
            let (model, defaults, suite, _) = try await makeNativeModel(mode)
            defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
            let session = try #require(model.activeDJSession)
            let root = VibeCastDisplayConsentForm(model: model)
                .environment(\.colorScheme, .dark).preferredColorScheme(.dark)
            let controller = UIHostingController(rootView: root)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 932))
            window.overrideUserInterfaceStyle = .dark
            window.rootViewController = controller; window.makeKeyAndVisible()
            defer { window.isHidden = true; window.rootViewController = nil }
            func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
            func fields() -> [UITextField] {
                descendants(controller.view).compactMap { $0 as? UITextField }
                    .filter { $0.accessibilityIdentifier?.hasPrefix("vibecast-handoff-digit-") == true }.sorted { $0.tag < $1.tag }
            }
            func capture(_ stage: String, enabled: Bool) throws {
                window.layoutIfNeeded()
                let values = fields()
                #expect(values.count == 6)
                #expect(values.allSatisfy { $0.isEnabled == enabled }, "Native UITextField enablement must match the form's state")
                #expect(values.map { $0.text ?? "" } == Array(repeating: "0", count: 6))
                observations.append(["mode": mode, "stage": stage, "state": String(describing: model.displayConsentState), "enabled": values.map(\.isEnabled),
                    "first_responder": values.map(\.isFirstResponder), "digits": values.map { $0.text ?? "" }])
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in window.layer.render(in: context.cgContext) }
                try #require(image.pngData()).write(to: folder.appendingPathComponent(mode + "-" + stage + ".png"))
            }
            try await Task.sleep(for: .milliseconds(350))
            let first = try #require(fields().first)
            _ = first.delegate?.textField?(first, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "000000")
            try await Task.sleep(for: .milliseconds(100))
            try capture("idle", enabled: true)
            // Deliberate model transition, not a claimed native button tap.
            await model.resolveDisplayConsent(code: "000000")
            try await Task.sleep(for: .milliseconds(150))
            #expect(model.displayConsentState == .ready)
            try capture("ready", enabled: false)
            await model.approveDisplayConsent()
            try await Task.sleep(for: .milliseconds(150))
            #expect(model.displayConsentState == (mode == "normal" ? .approved : .uncertain))
            try capture("terminal", enabled: false)
            await model.approveDisplayConsent()
            #expect(ConsentWire.requests.filter { $0.url?.path.hasSuffix("/owner/approve") == true }.count == 1)
            model.sessionHistory.suspend(); model.refreshDisplayConsentPresentation()
            try await Task.sleep(for: .milliseconds(150))
            #expect(model.displayConsentState == (mode == "normal" ? .unavailable : .uncertain))
            #expect(!model.canResolveDisplayConsent)
            try capture("withdrawn", enabled: mode == "normal")
            #expect(model.activeDJSession?.id == session.id)
            #expect(model.activeDJSession?.broadcast.playback == session.broadcast.playback)
        }
        try JSONSerialization.data(withJSONObject: observations, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("native-input-states.json"))
    }

    /// Exercise actual UIKit fields and coordinator callbacks; no physical
    /// typing, backend lookup, approval, or accessibility bridge is required.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_CONSENT_DIGITS_DIR"] != nil))
    func actualIOSNativeCodeEntryEditingAndFocus() async throws {
        let (model, defaults, suite, _) = try await makeNativeModel()
        defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
        let session = try #require(model.activeDJSession)
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["DJCONNECT_CONSENT_DIGITS_DIR"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let root = VibeCastDisplayConsentForm(model: model)
            .environment(\.colorScheme, .dark).preferredColorScheme(.dark)
        let controller = UIHostingController(rootView: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 932))
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = controller; window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        func currentFields() -> [UITextField] {
            descendants(controller.view).compactMap { $0 as? UITextField }
                .filter { $0.accessibilityIdentifier?.hasPrefix("vibecast-handoff-digit-") == true }.sorted { $0.tag < $1.tag }
        }
        var observations: [[String: Any]] = []
        func capture(_ name: String) throws {
            window.layoutIfNeeded()
            let fields = currentFields()
            observations.append(["stage": name, "digits": fields.map { $0.text ?? "" },
                "focused_index": fields.firstIndex { $0.isFirstResponder } ?? -1])
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in window.layer.render(in: context.cgContext) }
            try #require(image.pngData()).write(to: folder.appendingPathComponent(name + ".png"))
        }
        try await Task.sleep(for: .milliseconds(350))
        let fields = currentFields()
        try #require(fields.count == 6)
        func insert(_ text: String, at index: Int) {
            let accepted = fields[index].delegate?.textField?(fields[index], shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: text)
            #expect(accepted == false, "The native coordinator owns the aggregate six-digit edit")
        }
        insert("123456", at: 3)
        try await Task.sleep(for: .milliseconds(100))
        #expect(fields.map { $0.text ?? "" } == ["1", "2", "3", "4", "5", "6"])
        #expect(fields[5].isFirstResponder)
        try capture("digits-01-paste-from-later-cell")
        fields[5].deleteBackward()
        try await Task.sleep(for: .milliseconds(80))
        #expect(fields.map { $0.text ?? "" } == ["1", "2", "3", "4", "5", ""])
        #expect(fields[5].isFirstResponder)
        fields[5].deleteBackward()
        try await Task.sleep(for: .milliseconds(80))
        #expect(fields.map { $0.text ?? "" } == ["1", "2", "3", "4", "", ""])
        #expect(fields[4].isFirstResponder)
        try capture("digits-02-empty-backspace")
        insert("x654321y", at: 4)
        try await Task.sleep(for: .milliseconds(100))
        #expect(fields.map { $0.text ?? "" } == ["6", "5", "4", "3", "2", "1"])
        #expect(fields[5].isFirstResponder)
        fields[2].becomeFirstResponder()
        insert("９x", at: 2)
        try await Task.sleep(for: .milliseconds(80))
        #expect(fields.map { $0.text ?? "" } == ["6", "5", "4", "3", "2", "1"])
        #expect(fields[2].isFirstResponder)
        let identities = fields.map(ObjectIdentifier.init)
        model.applySessionBroadcastSnapshot(session.broadcast)
        try await Task.sleep(for: .milliseconds(150))
        #expect(currentFields().map(ObjectIdentifier.init) == identities)
        #expect(fields.map { $0.text ?? "" } == ["6", "5", "4", "3", "2", "1"])
        #expect(fields[2].isFirstResponder)
        #expect(model.activeDJSession?.id == session.id)
        #expect(model.activeDJSession?.broadcast.playback == session.broadcast.playback)
        #expect(model.displayConsentState == .idle)
        #expect(!ConsentWire.requests.contains { $0.url?.path.contains("/owner/") == true })
        try capture("digits-03-snapshot-preserves-input")
        try JSONSerialization.data(withJSONObject: ["stages": observations,
            "owner_requests": ConsentWire.requests.filter { $0.url?.path.contains("/owner/") == true }.count],
            options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("native-digits-result.json"))
    }

    /// Opt-in in-process UIKit observation, independent of the UI-testing runner.
    /// Public automation/container metadata may be unavailable in a unit host;
    /// preserve that limitation rather than manufacturing an enabled-state PASS.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_CONSENT_UIKIT_DIR"] != nil))
    func actualIOSNativeFormWithdrawalObservation() async throws {
        let (model, defaults, suite, _) = try await makeNativeModel()
        defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
        let directory = try #require(ProcessInfo.processInfo.environment["DJCONNECT_CONSENT_UIKIT_DIR"])
        let folder = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let root = VibeCastDisplayConsentForm(model: model)
            .environment(\.colorScheme, .dark).preferredColorScheme(.dark)
        let controller = UIHostingController(rootView: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 932))
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = controller; window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        func nodes() -> [NSObject] {
            var seen = Set<ObjectIdentifier>()
            func visit(_ node: NSObject, depth: Int = 0) -> [NSObject] {
                guard depth < 35, seen.insert(ObjectIdentifier(node)).inserted else { return [] }
                var children = node.accessibilityElements ?? []
                children += node.automationElements ?? []
                let count = node.accessibilityElementCount()
                if count > 0 && count < 200 {
                    children += (0..<count).compactMap { node.accessibilityElement(at: $0) }
                }
                if let view = node as? UIView { children += view.subviews }
                return [node] + children.compactMap { $0 as? NSObject }.flatMap { visit($0, depth: depth + 1) }
            }
            return visit(window)
        }
        func identifier(_ node: NSObject) -> String? { (node as? UIAccessibilityIdentification)?.accessibilityIdentifier }
        func capture(_ name: String) throws -> [NSObject] {
            controller.view.layoutIfNeeded(); window.layoutIfNeeded()
            let values = nodes()
            let rows: [[String: Any]] = values.map { node in
                ["type": String(describing: type(of: node)), "identifier": identifier(node) ?? "",
                 "label": node.accessibilityLabel ?? "", "traits": node.accessibilityTraits.rawValue,
                 "exposed": node.isAccessibilityElement]
            }
            try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
                .write(to: folder.appendingPathComponent(name + ".json"))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in window.layer.render(in: context.cgContext) }
            try #require(image.pngData()).write(to: folder.appendingPathComponent(name + ".png"))
            return values
        }
        try await Task.sleep(for: .milliseconds(350))
        let fields = descendants(controller.view).compactMap { $0 as? UITextField }
            .filter { $0.accessibilityIdentifier?.hasPrefix("vibecast-handoff-digit-") == true }.sorted { $0.tag < $1.tag }
        #expect(fields.count == 6)
        let first = try #require(fields.first)
        _ = first.delegate?.textField?(first, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "000000")
        try await Task.sleep(for: .milliseconds(150))
        let before = try capture("uikit-01-code")
        let lookupBefore = before.first { identifier($0) == "display-consent-lookup" }
        let beforeLookupEnabled = lookupBefore.map { !$0.accessibilityTraits.contains(.notEnabled) }
        if let beforeLookupEnabled { #expect(beforeLookupEnabled) }
        // Model fallback remains explicitly separate from native activation.
        let activated = lookupBefore?.accessibilityActivate() ?? false
        if activated {
            for _ in 0..<30 where model.displayConsentState != .ready { try await Task.sleep(for: .milliseconds(50)) }
        } else { await model.resolveDisplayConsent(code: "000000") }
        #expect(model.displayConsentState == .ready)
        _ = try capture("uikit-02-ready")
        model.sessionHistory.suspend(); model.refreshDisplayConsentPresentation()
        try await Task.sleep(for: .milliseconds(300))
        let after = try capture("uikit-03-withdrawn")
        let lookupAfter = after.first { identifier($0) == "display-consent-lookup" }
        let afterLookupDisabled = lookupAfter.map { $0.accessibilityTraits.contains(.notEnabled) }
        if let afterLookupDisabled { #expect(afterLookupDisabled) }
        #expect(model.displayConsentState == .unavailable && !model.canResolveDisplayConsent)
        let approvalPosts = ConsentWire.requests.filter { $0.url?.path.hasSuffix("/owner/approve") == true }.count
        #expect(approvalPosts == 0)
        let qualified = beforeLookupEnabled == true && afterLookupDisabled == true
        try JSONSerialization.data(withJSONObject: ["qualification": qualified ? "PUBLIC_UIKIT_DISABLED_TRAIT_OBSERVED" : "INCONCLUSIVE_PUBLIC_UIKIT_ELEMENTS",
            "native_lookup_activated": activated, "before_lookup_found": lookupBefore != nil,
            "after_lookup_found": lookupAfter != nil, "approval_posts": approvalPosts], options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("uikit-consent-result.json"))
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
