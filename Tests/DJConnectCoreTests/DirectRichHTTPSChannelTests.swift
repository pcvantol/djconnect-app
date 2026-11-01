import Foundation
import CryptoKit
import Testing
@testable import DJConnectCore

private final class DirectRichHTTPFixture: @unchecked Sendable {
    let host = "rich-" + UUID().uuidString.lowercased() + ".invalid"
    let status: Int; let data: Data; let headers: [String: String]
    let replies: [String: [(Int, Data)]]
    let assetGate: DirectRichAssetGate?
    let readGate: DirectRichAssetGate?
    let withdrawGate: DirectRichAssetGate?
    let assetMIME: String?
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    private var current = true
    var requests: [URLRequest] { lock.withLock { recorded } }
    var isCurrent: Bool { lock.withLock { current } }
    func invalidate() { lock.withLock { current = false } }
    func record(_ request: URLRequest) { lock.withLock { recorded.append(request) } }
    init(status: Int = 200, data: Data = Data("{}".utf8), headers: [String: String]? = nil, replies: [String: [(Int, Data)]] = [:],
         assetGate: DirectRichAssetGate? = nil, assetMIME: String? = nil, readGate: DirectRichAssetGate? = nil,
         withdrawGate: DirectRichAssetGate? = nil) {
        self.status = status; self.data = data
        self.replies = replies
        self.assetGate = assetGate; self.assetMIME = assetMIME
        self.readGate = readGate
        self.withdrawGate = withdrawGate
        self.headers = headers ?? ["Content-Type": "application/json", "Cache-Control": "private,no-store", "X-Content-Type-Options": "nosniff", "Referrer-Policy": "no-referrer"]
        DirectRichHTTPProtocol.add(self)
    }
    func response(for request: URLRequest) -> (Int, Data) {
        lock.withLock {
            let path = request.url!.lastPathComponent
            guard let options = replies[path], !options.isEmpty else { return (status, data) }
            let index = recorded.filter { $0.url?.lastPathComponent == path }.count - 1
            return options[min(max(index, 0), options.count - 1)]
        }
    }
    @MainActor func channel() throws -> DirectRichHTTPSChannel {
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [DirectRichHTTPProtocol.self]
        return try DirectRichHTTPSChannel(testOrigin: URL(string: "https://" + host)!, testSession: URLSession(configuration: configuration))
    }
    func close() { DirectRichHTTPProtocol.remove(host) }
}

private final class DirectRichAssetGate: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [@Sendable () -> Void] = []
    private var released = false
    var isReleased: Bool { lock.withLock { released } }
    func hold(_ callback: @escaping @Sendable () -> Void) {
        let ready = lock.withLock { if released { return true }; pending.append(callback); return false }
        if ready { callback() }
    }
    func release() {
        let callbacks = lock.withLock { released = true; let values = pending; pending = []; return values }
        for callback in callbacks { callback() }
    }
}

private final class DirectRichHTTPProtocol: URLProtocol, @unchecked Sendable {
    private let stateLock = NSLock(); private var stopped = false
    private static let lock = NSLock()
    nonisolated(unsafe) private static var fixtures: [String: DirectRichHTTPFixture] = [:]
    static func add(_ fixture: DirectRichHTTPFixture) { lock.withLock { fixtures[fixture.host] = fixture } }
    static func remove(_ host: String) { _ = lock.withLock { fixtures.removeValue(forKey: host) } }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host?.hasPrefix("rich-") == true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let host = request.url?.host, let fixture = Self.lock.withLock({ Self.fixtures[host] }) else { return }
        fixture.record(request)
        let (status, data) = fixture.response(for: request)
        var headers = fixture.headers
        if request.url?.lastPathComponent == "asset", let mime = fixture.assetMIME { headers["Content-Type"] = mime }
        let responseHeaders = headers
        let deliver: @Sendable () -> Void = { [self] in
            guard !stateLock.withLock({ stopped }) else { return }
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: responseHeaders)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
        if request.url?.lastPathComponent == "asset", let gate = fixture.assetGate { gate.hold(deliver) }
        else if request.url?.lastPathComponent == "read", let gate = fixture.readGate { gate.hold(deliver) }
        else if request.url?.lastPathComponent == "withdraw", let gate = fixture.withdrawGate { gate.hold(deliver) }
        else { deliver() }
    }
    override func stopLoading() { stateLock.withLock { stopped = true } }
}

private final class DirectRichCustodyFixtureAnchor: NSObject {}
@MainActor private final class DirectRichModelFlags { var owner = true; var pair = true; var frameEpoch = 0 }
@MainActor private final class DirectRichWaiterState { var invalid = false; var entered = false }
private enum DirectRichModelTaskContext { @TaskLocal static var waiter: DirectRichWaiterState? }

/// Synthetic transport/owner model only. It never mints a genuine HTTPS
/// ReceivingContext, native clock qualification or actual SDK ownership.
@Suite @MainActor struct DirectRichReadCustodyTests {
    private func packet() throws -> [String: DirectRichWireJSON] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: DirectRichCustodyFixtureAnchor.self)
        #endif
        let url = try #require(bundle.url(forResource: "direct-rich-synthetic-responses", withExtension: "json", subdirectory: "Fixtures") ?? bundle.url(forResource: "direct-rich-synthetic-responses", withExtension: "json"))
        return try #require(DirectRichWireJSON.parse(Data(contentsOf: url), maximumBytes: 65536).object)
    }
    private func wire(reads: [(Int, Data)]? = nil, statusState: String = "active", readGate: DirectRichAssetGate? = nil,
                      withdrawGate: DirectRichAssetGate? = nil, withdrawError: DirectRichServerError? = nil) throws -> DirectRichHTTPFixture {
        let packet = try packet()
        let authorize = try #require(packet["authorize_response"]).canonicalData()
        let read = try #require(packet["read_response"]).canonicalData()
        var state = try #require(packet["status_response"]?.object); state["state"] = .string(statusState)
        let status = try DirectRichWireJSON.object(state).canonicalData()
        var withdrawn = try #require(packet["status_response"]?.object); withdrawn["state"] = .string("withdrawn")
        let withdrawal = try withdrawError.map { error in
            try DirectRichWireJSON.object(["success": .bool(false), "contract_version": .integer(1), "error": .string(error.rawValue)]).canonicalData()
        } ?? DirectRichWireJSON.object(withdrawn).canonicalData()
        return DirectRichHTTPFixture(replies: ["authorize": [(200, authorize)], "read": reads ?? [(200, read)],
            "status": [(200, status)], "withdraw": [(withdrawError?.status ?? 200, withdrawal)]], readGate: readGate, withdrawGate: withdrawGate)
    }
    private func artworkWire(corrupt: Bool = false, gate: DirectRichAssetGate? = nil) throws -> (DirectRichHTTPFixture, Data) {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: DirectRichCustodyFixtureAnchor.self)
        #endif
        let url = try #require(bundle.url(forResource: "session-artwork-cover-core-5c7ecb79", withExtension: "png", subdirectory: "Fixtures") ?? bundle.url(forResource: "session-artwork-cover-core-5c7ecb79", withExtension: "png"))
        let pixels = try Data(contentsOf: url)
        let digest = SHA256.hash(data: pixels).map { String(format: "%02x", $0) }.joined()
        var response = try #require(packet()["authorize_response"]?.object)
        var frame = try #require(response["frame"]?.object)
        let music = try #require(frame["now_playing"]?.object)
        let rights: DirectRichWireJSON = .object(["passive_cache": .bool(true), "os_snapshot": .bool(true), "external_relay": .bool(false), "watch_replication": .bool(false)])
        let art: [DirectRichWireJSON] = ["contribution", "now_playing"].enumerated().map { index, slot in
            .object(["slot": .string(slot), "asset_id": .string(String(repeating: index == 0 ? "a" : "b", count: 32)),
                "subject": .object(["provider": .string("spotify"), "type": .string("track"), "uri": music["subject_uri"]!]),
                "role": .string(index == 0 ? "contextual_cover" : "current_cover"), "media_revision": .string(String(repeating: "a", count: 24)),
                "captured_at": music["observed_at"]!, "expires_at": music["expires_at"]!, "source_url": music["source_url"]!,
                "attribution": music["attribution"]!, "alt_text": .object(Dictionary(uniqueKeysWithValues: ["en", "nl", "de", "fr", "es"].map { ($0, .string("Synthetic cover")) })),
                "width": .integer(64), "height": .integer(64), "crop_allowed": .bool(false), "usage_basis": .string("spotify_temporary_passive_cover"),
                "rights": rights, "bytes_sha256": .string(digest), "byte_length": .integer(Int64(pixels.count)), "mime_type": .string("image/png")])
        }
        frame["artwork"] = .array(art); frame["artwork_status"] = .object(["state": .string("available"), "reason": .string("qualified")])
        frame.removeValue(forKey: "frame_id"); frame["frame_id"] = .string(try DirectRichWireJSON.object(frame).digest())
        response["frame"] = .object(frame)
        let bytes = try DirectRichWireJSON.object(response).canonicalData()
        let fixture = DirectRichHTTPFixture(replies: ["authorize": [(200, bytes)], "asset": [(200, corrupt ? Data(pixels.dropLast()) : pixels)]], assetGate: gate, assetMIME: "image/png")
        return (fixture, pixels)
    }
    private func waitForTwoAssets(_ fixture: DirectRichHTTPFixture) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while fixture.requests.filter({ $0.url?.lastPathComponent == "asset" }).count < 2, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(fixture.requests.filter({ $0.url?.lastPathComponent == "asset" }).count == 2)
    }
    private func owner(_ fixture: DirectRichHTTPFixture, flags: DirectRichModelFlags, store: DJConnectInMemoryTokenStore = .init(token: "paired-original")) throws -> DirectRichReadCustody {
        let request = try DirectRichRequest(operation: .authorize, originalBody: #require(packet()["authorize_request"]).canonicalData())
        return try DirectRichReadCustody(testChannel: fixture.channel(), originalAuthorization: request, testTokenStore: store,
            pairedIsCurrent: { flags.pair }, ownerIsCurrent: { flags.owner && DirectRichModelTaskContext.waiter?.invalid != true }, captureAttempt: {
                let epoch = flags.frameEpoch
                return { flags.frameEpoch == epoch }
            })
    }

    private func changedRead(_ edit: (inout [String: DirectRichWireJSON]) throws -> Void) throws -> Data {
        var response = try #require(packet()["read_response"]?.object)
        var frame = try #require(response["frame"]?.object)
        try edit(&frame)
        frame.removeValue(forKey: "frame_id"); frame["frame_id"] = .string(try DirectRichWireJSON.object(frame).digest())
        response["frame"] = .object(frame)
        return try DirectRichWireJSON.object(response).canonicalData()
    }

    @Test func genuineSameContentObservationMayKeepBroadcastSequence() async throws {
        let response = try changedRead { frame in
            frame["observed_at_ms"] = .integer(1793440801000)
            frame["expires_at_ms"] = .integer(1793440921000)
            var music = try #require(frame["now_playing"]?.object)
            music["observed_at"] = .string("2026-10-31T10:00:01+00:00")
            music["expires_at"] = .string("2026-10-31T10:02:01+00:00")
            frame["now_playing"] = .object(music)
        }
        let fixture = try wire(reads: [(200, response)]); defer { fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags())
        let first = try await owner.authorize(), originalPin = first.originalCapture?.continuousTicks
        let old = try #require(first.frame)
        let next = try await owner.read(), new = try #require(next.frame)
        #expect(old.delivery_sequence == new.delivery_sequence && old.frame_id != new.frame_id)
        #expect(old.now_playing?.track == new.now_playing?.track && old.now_playing?.subject_uri == new.now_playing?.subject_uri)
        #expect(new.observed_at_ms > old.observed_at_ms)
        #expect(next.originalCapture?.continuousTicks == originalPin && first.frame == nil)
        #expect(next.nativeQualificationInputs == nil) // New DATA is not a qualified clock/source permit.
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "authorize" }.count == 1)
    }

    @Test func syntheticFacadeSuspendsAndReadsSameOriginalWithoutReauthorization() async throws {
        let fixture = try wire(); defer { fixture.close() }
        let custody = try owner(fixture, flags: DirectRichModelFlags())
        let runtime = DJConnectDirectSessionRuntime(testCustody: custody)
        try await runtime.begin()
        #expect(runtime.phase == .active)
        #expect(runtime.originalPurposeContext == nil && runtime.nativeQualificationInputs == nil)
        runtime.suspend()
        #expect(runtime.phase == .suspended)
        do { try await runtime.begin(); Issue.record("Suspension reauthorized original") } catch {}
        try await runtime.read()
        #expect(runtime.phase == .active)
        runtime.retire()
        do { try await runtime.read(); Issue.record("Retired facade read content") } catch {}
        do { try await runtime.begin(); Issue.record("Retired facade minted new original") } catch {}
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "authorize" }.count == 1)
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "read" }.count == 1)
        #expect(runtime.phase == .closed && runtime.originalPurposeContext == nil)
    }

    @Test func syntheticFacadeSuspensionCancelsHeldReadBeforeReplyAndCannotPublishLate() async throws {
        let gate = DirectRichAssetGate(), fixture = try wire(readGate: gate)
        defer { gate.release(); fixture.close() }
        let runtime = DJConnectDirectSessionRuntime(testCustody: try owner(fixture, flags: DirectRichModelFlags()))
        try await runtime.begin()
        let read = Task { () -> Bool in do { try await runtime.read(); return true } catch { return false } }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while fixture.requests.filter({ $0.url?.lastPathComponent == "read" }).isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "read" }.count == 1)
        runtime.suspend()
        let watchdog = Task { try? await Task.sleep(for: .seconds(3)); if !Task.isCancelled { gate.release() } }
        defer { watchdog.cancel() }
        #expect(await read.value == false)
        #expect(!gate.isReleased && runtime.phase == .suspended)
        gate.release()
        #expect(runtime.nativeQualificationInputs == nil && runtime.originalPurposeContext == nil)
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "authorize" }.count == 1)
    }

    @Test func syntheticFacadeOwnerReleaseCancelsActualReadAndFencesCandidateBeforeReply() async throws {
        let gate = DirectRichAssetGate(), fixture = try wire(readGate: gate)
        defer { gate.release(); fixture.close() }
        let custody = try owner(fixture, flags: DirectRichModelFlags())
        let original = try await custody.authorize()
        let runtime = DJConnectDirectSessionRuntime(testCustody: custody)
        let read = Task { () -> Bool in do { try await runtime.read(); return true } catch { return false } }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while fixture.requests.filter({ $0.url?.lastPathComponent == "read" }).isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "read" }.count == 1)
        runtime.cancelOwnedResources()
        // No actor turn or reply release can hide a missing fence check here.
        #expect(original.frame == nil && original.originalCapture == nil)
        let watchdog = Task { try? await Task.sleep(for: .seconds(3)); if !Task.isCancelled { gate.release() } }
        defer { watchdog.cancel() }
        #expect(await read.value == false && !gate.isReleased)
        gate.release()
        do { try await runtime.read(); Issue.record("Released owner made another read") } catch {}
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "read" }.count == 1)
        #expect(runtime.originalPurposeContext == nil && runtime.nativeQualificationInputs == nil)
    }
    @Test func syntheticFacadeWithdrawsOriginalAfterOwnerLossWithoutCreatingPushChildOrRetry() async throws {
        let fixture = try wire(); defer { fixture.close() }
        let flags = DirectRichModelFlags(), runtime = DJConnectDirectSessionRuntime(testCustody: try owner(fixture, flags: flags))
        try await runtime.begin()
        flags.owner = false // Session/positive owner ended; original pairing remains valid for negative cleanup.
        try await runtime.withdraw()
        try await runtime.withdraw()
        #expect(runtime.phase == .closed && runtime.originalPurposeContext == nil)
        #expect(fixture.requests.map { $0.url!.lastPathComponent } == ["authorize", "withdraw"])
    }
    @Test func syntheticFacadeNeverAttemptsRemoteWithdrawalForAnUnstartedOwner() async throws {
        let fixture = try wire(); defer { fixture.close() }
        let runtime = DJConnectDirectSessionRuntime(testCustody: try owner(fixture, flags: DirectRichModelFlags()))
        try await runtime.withdraw()
        try await runtime.withdraw()
        #expect(runtime.phase == .closed && fixture.requests.isEmpty)
    }
    @Test func syntheticFacadeRetainsFailedWithdrawalWithoutAutomaticReplay() async throws {
        let fixture = try wire(withdrawError: .unavailable); defer { fixture.close() }
        let runtime = DJConnectDirectSessionRuntime(testCustody: try owner(fixture, flags: DirectRichModelFlags()))
        try await runtime.begin()
        for _ in 0..<3 {
            do { try await runtime.withdraw(); Issue.record("Failed cleanup acknowledged") }
            catch { #expect(error as? DirectRichServerError == .unavailable) }
        }
        #expect(fixture.requests.map { $0.url!.lastPathComponent } == ["authorize", "withdraw"])
        do { try await runtime.begin(); Issue.record("Failed cleanup reauthorized") } catch {}
    }
    @Test func syntheticFacadeCancellationKeepsOneUnknownWithdrawalAndCannotReauthorize() async throws {
        let gate = DirectRichAssetGate(), fixture = try wire(withdrawGate: gate)
        defer { gate.release(); fixture.close() }
        let runtime = DJConnectDirectSessionRuntime(testCustody: try owner(fixture, flags: DirectRichModelFlags()))
        try await runtime.begin()
        let first = Task { () -> Bool in do { try await runtime.withdraw(); return true } catch { return false } }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while fixture.requests.filter({ $0.url?.lastPathComponent == "withdraw" }).isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "withdraw" }.count == 1)
        #expect(runtime.phase == .closed)
        first.cancel()
        let watchdog = Task { try? await Task.sleep(for: .seconds(3)); if !Task.isCancelled { gate.release() } }
        defer { watchdog.cancel() }
        #expect(await first.value == false && !gate.isReleased)
        do { try await runtime.withdraw(); Issue.record("Unknown cleanup acknowledged") } catch {}
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "withdraw" }.count == 1)
        gate.release()
        do { try await runtime.begin(); Issue.record("Canceled cleanup reauthorized") } catch {}
    }
    @Test func syntheticFacadeCanceledCompetingOffCannotCancelOriginalWithdrawal() async throws {
        let gate = DirectRichAssetGate(), fixture = try wire(withdrawGate: gate)
        defer { gate.release(); fixture.close() }
        let runtime = DJConnectDirectSessionRuntime(testCustody: try owner(fixture, flags: DirectRichModelFlags()))
        try await runtime.begin()
        let first = Task { () -> Bool in do { try await runtime.withdraw(); return true } catch { return false } }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while fixture.requests.filter({ $0.url?.lastPathComponent == "withdraw" }).isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "withdraw" }.count == 1)
        let state = DirectRichWaiterState()
        let second = Task { () -> Bool in
            state.entered = true
            do { try await runtime.withdraw(); return true } catch { return false }
        }
        while !state.entered { await Task.yield() }
        // Either async-entry cancellation ordering must preserve the primary.
        // This marker is caller entry, not a claimed SDK/parent runtime witness.
        second.cancel()
        gate.release()
        let firstSucceeded = await first.value, secondSucceeded = await second.value
        #expect(firstSucceeded && !secondSucceeded)
        try await runtime.withdraw() // Retained original success, no replay.
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "withdraw" }.count == 1)
    }

    @Test func sameSequenceChangedFrameIsNotItselfNewPermission() async throws {
        // Sub-millisecond source observations can share the represented frame
        // millisecond. Source qualification remains required outside this DATA
        // guard; neither sequence nor hash is an observation authority.
        let response = try changedRead { frame in
            var music = try #require(frame["now_playing"]?.object)
            music["observed_at"] = .string("2026-10-31T10:00:00.000001+00:00")
            frame["now_playing"] = .object(music)
        }
        let fixture = try wire(reads: [(200, response)]); defer { fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags()), first = try await owner.authorize()
        let original = try #require(first.frame)
        let next = try await owner.read(), frame = try #require(next.frame)
        #expect(frame.observed_at_ms == original.observed_at_ms && frame.delivery_sequence == original.delivery_sequence)
        #expect(frame.frame_id != original.frame_id && next.nativeQualificationInputs == nil)
    }

    @Test func broadcastRollbackStillClosesPurpose() async throws {
        let response = try changedRead { $0["delivery_sequence"] = .integer(0) }
        let fixture = try wire(reads: [(200, response)]); defer { fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags()), first = try await owner.authorize()
        do { _ = try await owner.read(); Issue.record("Broadcast rollback accepted") } catch {}
        #expect(owner.state == .unknown && first.frame == nil)
    }

    @Test func originalObservationRollbackStillClosesPurpose() async throws {
        let response = try changedRead { frame in
            frame["observed_at_ms"] = .integer(1793440799999)
            frame["expires_at_ms"] = .integer(1793440919999)
            for key in ["contribution", "now_playing"] {
                var value = try #require(frame[key]?.object)
                value["expires_at"] = .string("2026-10-31T10:01:59.999+00:00")
                frame[key] = .object(value)
            }
        }
        let fixture = try wire(reads: [(200, response)]); defer { fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags()), first = try await owner.authorize()
        do { _ = try await owner.read(); Issue.record("Original observation rollback accepted") } catch {}
        #expect(owner.state == .unknown && first.frame == nil)
    }

    @Test(arguments: [false, true])
    func staleObservationRequiresNewOriginalObservationToBecomeActive(_ fresh: Bool) async throws {
        let stale = try changedRead { frame in
            frame["state"] = .string("stale"); frame["contribution"] = .null; frame["now_playing"] = .null
            frame["artwork"] = .array([])
            for key in ["contribution_status", "now_playing_status", "artwork_status"] {
                frame[key] = .object(["state": .string("stale"), "reason": .string("original_snapshot_expired")])
            }
        }
        let active: Data
        if fresh {
            active = try changedRead { frame in
                frame["observed_at_ms"] = .integer(1793440930000); frame["expires_at_ms"] = .integer(1793441050000)
                frame["contribution"] = .null
                frame["contribution_status"] = .object(["state": .string("unavailable"), "reason": .string("original_deadline_expired")])
                var music = try #require(frame["now_playing"]?.object)
                music["observed_at"] = .string("2026-10-31T10:02:10+00:00"); music["expires_at"] = .string("2026-10-31T10:04:10+00:00")
                frame["now_playing"] = .object(music)
            }
        } else { active = try #require(packet()["read_response"]).canonicalData() }
        let fixture = try wire(reads: [(200, stale), (200, active)]); defer { fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags())
        let first = try await owner.authorize(), pin = first.originalCapture?.continuousTicks
        let old = try await owner.read()
        #expect(old.frame?.state == "stale")
        if fresh {
            let next = try await owner.read()
            #expect(next.frame?.state == "active" && next.originalCapture?.continuousTicks == pin && old.frame == nil)
        } else {
            do { _ = try await owner.read(); Issue.record("Expired original observation revived") } catch {}
            #expect(owner.state == .unknown && old.frame == nil)
        }
    }

    @Test(arguments: ["cancel", "currentness"])
    func joinedReadWaiterCannotPublishButDoesNotCancelOwner(_ failure: String) async throws {
        let gate = DirectRichAssetGate(), fixture = try wire(readGate: gate)
        defer { gate.release(); fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags())
        _ = try await owner.authorize()
        let primary = Task { try await owner.read() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while fixture.requests.filter({ $0.url?.lastPathComponent == "read" }).isEmpty, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
        let waiterState = DirectRichWaiterState()
        let waiter = Task { await DirectRichModelTaskContext.$waiter.withValue(waiterState) {
            waiterState.entered = true
            do { _ = try await owner.read(); return true } catch { return false }
        } }
        while !waiterState.entered { await Task.yield() }
        if failure == "cancel" { waiter.cancel() } else { waiterState.invalid = true }
        gate.release()
        let result = try await primary.value
        #expect(result.frame != nil && owner.state == .active)
        #expect(await waiter.value == false)
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "read" }.count == 1)
    }

    @Test(arguments: ["cancel", "currentness"])
    func joinedArtworkWaiterCannotReceivePixelsButOwnerContinues(_ failure: String) async throws {
        let gate = DirectRichAssetGate(), (fixture, pixels) = try artworkWire(gate: gate)
        defer { gate.release(); fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags()), candidate = try await owner.authorize()
        let primary = Task { await owner.artwork(for: candidate) }
        try await waitForTwoAssets(fixture)
        let waiterState = DirectRichWaiterState()
        let waiter = Task { await DirectRichModelTaskContext.$waiter.withValue(waiterState) {
            waiterState.entered = true
            return await owner.artwork(for: candidate)
        } }
        while !waiterState.entered { await Task.yield() }
        if failure == "cancel" { waiter.cancel() } else { waiterState.invalid = true }
        gate.release()
        let result = await primary.value
        #expect(result.count == 2 && result["now_playing"] == pixels)
        #expect(await waiter.value.isEmpty)
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "asset" }.count == 2)
    }

    @Test(arguments: ["read", "artwork"])
    func cancelledJoinReturnsBeforeSharedNetworkReply(_ kind: String) async throws {
        let gate = DirectRichAssetGate()
        let fixture: DirectRichHTTPFixture
        if kind == "artwork" { fixture = try artworkWire(gate: gate).0 }
        else { fixture = try wire(readGate: gate) }
        defer { gate.release(); fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags()), candidate = try await owner.authorize()
        let primary = Task { () -> Bool in
            if kind == "artwork" { return await owner.artwork(for: candidate).count == 2 }
            do { return try await owner.read().frame != nil } catch { return false }
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        let path = kind == "artwork" ? "asset" : "read", required = kind == "artwork" ? 2 : 1
        while fixture.requests.filter({ $0.url?.lastPathComponent == path }).count < required, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        let state = DirectRichWaiterState()
        let waiter = Task { () -> Bool in
            state.entered = true
            if kind == "artwork" { return await owner.artwork(for: candidate).isEmpty }
            do { _ = try await owner.read(); return false } catch is CancellationError { return true } catch { return false }
        }
        while !state.entered { await Task.yield() }
        waiter.cancel()
        // A broken join cannot hang this test indefinitely. The assertion is
        // causal (before reply release), not a fragile elapsed-time threshold.
        let watchdog = Task { try? await Task.sleep(for: .seconds(2)); if !Task.isCancelled { gate.release() } }
        defer { watchdog.cancel() }
        #expect(await waiter.value)
        #expect(!gate.isReleased)
        #expect(owner.state == .active)
        gate.release()
        #expect(await primary.value)
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == path }.count == required)
    }

    @Test func pendingReadWaitersAreBoundedAndCancellationReleasesCapacity() async throws {
        let gate = DirectRichAssetGate(), fixture = try wire(readGate: gate)
        defer { gate.release(); fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags())
        _ = try await owner.authorize()
        let primary = Task { try await owner.read() }
        let requestDeadline = ContinuousClock.now.advanced(by: .seconds(3))
        while fixture.requests.filter({ $0.url?.lastPathComponent == "read" }).isEmpty, ContinuousClock.now < requestDeadline { try await Task.sleep(for: .milliseconds(5)) }
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "read" }.count == 1)
        let waiters = (0..<64).map { _ in Task { () -> Bool in
            do { _ = try await owner.read(); return true } catch { return false }
        } }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while owner.pendingReadWaiterCount < 64, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
        #expect(owner.pendingReadWaiterCount == 64)
        do { _ = try await owner.read(); Issue.record("Unbounded waiter admitted") } catch {}
        #expect(owner.state == .active && owner.pendingReadWaiterCount == 64)
        let watchdog = Task { try? await Task.sleep(for: .seconds(5)); if !Task.isCancelled { gate.release() } }
        defer { watchdog.cancel() }
        waiters[0].cancel()
        #expect(await waiters[0].value == false)
        #expect(owner.pendingReadWaiterCount == 63 && !gate.isReleased)
        let replacement = Task { () -> Bool in do { _ = try await owner.read(); return true } catch { return false } }
        let replacementDeadline = ContinuousClock.now.advanced(by: .seconds(3))
        while owner.pendingReadWaiterCount < 64, ContinuousClock.now < replacementDeadline { try await Task.sleep(for: .milliseconds(5)) }
        #expect(owner.pendingReadWaiterCount == 64)
        gate.release()
        let candidate = try await primary.value
        #expect(candidate.frame != nil)
        for waiter in waiters.dropFirst() { #expect(await waiter.value) }
        #expect(await replacement.value)
        #expect(owner.pendingReadWaiterCount == 0)
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "read" }.count == 1)
    }

    @Test func retirementResolvesPendingJoinersBeforeNetworkReply() async throws {
        let gate = DirectRichAssetGate(), fixture = try wire(readGate: gate)
        defer { gate.release(); fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags())
        _ = try await owner.authorize()
        let primary = Task { () -> Bool in do { _ = try await owner.read(); return true } catch { return false } }
        let requestDeadline = ContinuousClock.now.advanced(by: .seconds(3))
        while fixture.requests.filter({ $0.url?.lastPathComponent == "read" }).isEmpty, ContinuousClock.now < requestDeadline { try await Task.sleep(for: .milliseconds(5)) }
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "read" }.count == 1)
        let waiters = (0..<8).map { _ in Task { () -> Bool in do { _ = try await owner.read(); return true } catch { return false } } }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while owner.pendingReadWaiterCount < 8, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
        #expect(owner.pendingReadWaiterCount == 8)
        let watchdog = Task { try? await Task.sleep(for: .seconds(5)); if !Task.isCancelled { gate.release() } }
        defer { watchdog.cancel() }
        owner.retire()
        for waiter in waiters { #expect(await waiter.value == false) }
        #expect(await primary.value == false)
        #expect(owner.state == .closed && owner.pendingReadWaiterCount == 0 && !gate.isReleased)
    }

    @Test func concurrentCancellationAndCompletionLeaveNoJoinedWaiters() async throws {
        for _ in 0..<16 {
            let gate = DirectRichAssetGate(), fixture = try wire(readGate: gate)
            defer { gate.release(); fixture.close() }
            let owner = try owner(fixture, flags: DirectRichModelFlags())
            _ = try await owner.authorize()
            let primary = Task { try await owner.read() }
            let requestDeadline = ContinuousClock.now.advanced(by: .seconds(3))
            while fixture.requests.filter({ $0.url?.lastPathComponent == "read" }).isEmpty, ContinuousClock.now < requestDeadline { try await Task.sleep(for: .milliseconds(5)) }
            #expect(fixture.requests.filter { $0.url?.lastPathComponent == "read" }.count == 1)
            let waiters = (0..<4).map { _ in Task { do { _ = try await owner.read() } catch {} } }
            let joinDeadline = ContinuousClock.now.advanced(by: .seconds(3))
            while owner.pendingReadWaiterCount < 4, ContinuousClock.now < joinDeadline { try await Task.sleep(for: .milliseconds(5)) }
            #expect(owner.pendingReadWaiterCount == 4)
            let cancellation = Task.detached { waiters[0].cancel(); waiters[2].cancel() }
            let completion = Task.detached { gate.release() }
            await cancellation.value; await completion.value
            let candidate = try await primary.value
            for waiter in waiters { await waiter.value }
            // A racing waiter may have completed before cancellation. Either
            // ordering must resolve exactly once and leave the owner intact.
            #expect(candidate.frame != nil && owner.state == .active && owner.pendingReadWaiterCount == 0)
            #expect(fixture.requests.filter { $0.url?.lastPathComponent == "read" }.count == 1)
            owner.retire()
        }
    }

    @Test func shippingChannelAndPairedIdentityAloneCannotCreateOriginalParent() throws {
        let client = DJConnectClient(baseURL: URL(string: "https://original-parent.invalid")!,
            identity: .init(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Synthetic no-IO fixture", clientType: .ios, firmware: "test", platform: .ios),
            tokenStore: DJConnectInMemoryTokenStore(token: "fixture-only-paired-token"))
        let owner = try DirectRichReadCustody(client: client, sessionID: "fixture-session", surface: .widget, lockedDisplay: false,
            pairedIsCurrent: { true }, ownerIsCurrent: { true }, captureAttempt: { { true } })
        // A real shipping URLSession object is necessary but insufficient.
        // No HTTP task is started and no original Core response has arrived.
        #expect(owner.state == .idle && owner.pendingReadWaiterCount == 0 && owner.originalPurposeContext == nil)
        owner.retire()
        #expect(owner.state == .closed && owner.originalPurposeContext == nil)
    }

    @Test(arguments: ["owner", "pair"])
    func observedOwnerLossBeforeFirstParentAccessCannotReopenAfterABA(_ kind: String) async throws {
        let fixture = try wire(); defer { fixture.close() }
        let flags = DirectRichModelFlags(), owner = try owner(fixture, flags: flags)
        let candidate = try await owner.authorize()
        if kind == "owner" { flags.owner = false } else { flags.pair = false }
        #expect(owner.originalPurposeContext == nil && owner.state == .closed)
        flags.owner = true; flags.pair = true
        #expect(owner.originalPurposeContext == nil && candidate.frame == nil)
        do { _ = try await owner.read(); Issue.record("Observed owning loss revived original purpose") } catch {}
        #expect(fixture.requests.count == 1)
    }

    @Test func oneOriginalOperationAndClosedStatusCannotRestoreSecrets() async throws {
        let fixture = try wire(); defer { fixture.close() }
        let flags = DirectRichModelFlags(), owner = try owner(fixture, flags: flags)
        let first = try await owner.authorize()
        #expect(first.frame != nil && first.genuineReceivingContext == nil && first.nativeQualificationInputs == nil)
        #expect(owner.originalPurposeContext == nil) // Synthetic HTTP cannot mint the warm original-parent port either.
        do { _ = try await owner.authorize(); Issue.record("Second authorize dispatched") } catch {}
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "authorize" }.count == 1)
        flags.owner = false; owner.retire()
        #expect(first.frame == nil && first.originalCapture == nil)
        #expect(try await owner.status().state == "active")
        #expect(owner.state == .closed && first.frame == nil && owner.originalPurposeContext == nil)
        let negative = try await owner.withdraw()
        #expect(negative.state == "withdrawn" && owner.state == .closed)
    }

    @Test func temporaryFrameClosureRetainsOriginalPurposeWithoutReauthorize() async throws {
        let reply = try #require(packet()["read_response"]).canonicalData()
        let temporary = Data(#"{"success":false,"contract_version":1,"error":"rich_frame_unavailable"}"#.utf8)
        let fixture = try wire(reads: [(503, temporary), (200, reply)]); defer { fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags())
        let first = try await owner.authorize(), pin = first.originalCapture?.continuousTicks
        do { _ = try await owner.read(); Issue.record("Temporary error accepted") } catch {}
        #expect(owner.state == .suspended && first.frame == nil)
        let next = try await owner.read()
        #expect(owner.state == .active && next.frame != nil && next.originalCapture?.continuousTicks == pin)
        #expect(owner.originalPurposeContext == nil) // Recovery DATA never creates a genuine shipping parent.
        #expect(first.frame == nil) // Even the same frame hash cannot revive an old candidate.
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "authorize" }.count == 1)
    }

    @Test func terminalErrorAndActiveHistoryNeverRearmRead() async throws {
        let terminal = Data(#"{"success":false,"contract_version":1,"error":"rich_unavailable"}"#.utf8)
        let fixture = try wire(reads: [(503, terminal)]); defer { fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags())
        let first = try await owner.authorize()
        do { _ = try await owner.read(); Issue.record("Terminal error accepted") } catch {}
        #expect(owner.state == .unknown && first.frame == nil)
        #expect(try await owner.status().state == "active")
        do { _ = try await owner.read(); Issue.record("History rearmed read") } catch {}
        #expect(owner.state == .unknown)
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "read" }.count == 1)
    }

    @Test(arguments: ["withdrawn", "expired", "unknown"])
    func originalNegativeStatusImmediatelyRetiresTheLiveScope(_ negative: String) async throws {
        let fixture = try wire(statusState: negative); defer { fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags()), candidate = try await owner.authorize()
        #expect(candidate.frame != nil)
        #expect(try await owner.status().state == negative)
        #expect(candidate.frame == nil && candidate.nativeQualificationInputs == nil)
        #expect(owner.state == (negative == "unknown" ? .unknown : .closed))
        do { _ = try await owner.read(); Issue.record("Negative history rearmed read") } catch {}
        let reads = fixture.requests.filter { $0.url?.lastPathComponent == "read" }
        #expect(reads.isEmpty)
    }

    @Test(arguments: ["withdrawn", "expired", "unknown"])
    func negativeHistoryClosesPendingReadAndJoinBeforeNetworkRelease(_ negative: String) async throws {
        let gate = DirectRichAssetGate(), fixture = try wire(statusState: negative, readGate: gate)
        defer { gate.release(); fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags())
        let original = try await owner.authorize()
        let primary = Task { () -> Bool in
            do { _ = try await owner.read(); return true } catch { return false }
        }
        let requestDeadline = ContinuousClock.now.advanced(by: .seconds(2))
        while fixture.requests.filter({ $0.url?.lastPathComponent == "read" }).isEmpty, ContinuousClock.now < requestDeadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "read" }.count == 1)
        let join = Task { () -> Bool in
            do { _ = try await owner.read(); return true } catch { return false }
        }
        let joinDeadline = ContinuousClock.now.advanced(by: .seconds(2))
        while owner.pendingReadWaiterCount != 1, ContinuousClock.now < joinDeadline { await Task.yield() }
        #expect(owner.pendingReadWaiterCount == 1)
        #expect(try await owner.status().state == negative)
        // The negative management reply must release both callers without
        // waiting for content. A later content reply cannot revive custody.
        let watchdog = Task { try? await Task.sleep(for: .seconds(2)); if !Task.isCancelled { gate.release() } }
        defer { watchdog.cancel() }
        #expect(await primary.value == false)
        #expect(await join.value == false)
        #expect(!gate.isReleased && owner.pendingReadWaiterCount == 0)
        #expect(original.frame == nil && original.originalCapture == nil && original.nativeQualificationInputs == nil)
        gate.release()
        await Task.yield()
        #expect(owner.state == (negative == "unknown" ? .unknown : .closed))
        do { _ = try await owner.read(); Issue.record("Late content rearmed original purpose") } catch {}
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "read" }.count == 1)
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "authorize" }.count == 1)
    }

    @Test func ordinaryFrameChangeDoesNotRenewOriginalPurpose() async throws {
        let fixture = try wire(); defer { fixture.close() }
        let flags = DirectRichModelFlags(), owner = try owner(fixture, flags: flags)
        let first = try await owner.authorize(), pin = first.originalCapture?.continuousTicks
        flags.frameEpoch += 1
        #expect(first.frame == nil)
        let next = try await owner.read()
        #expect(next.frame != nil && next.originalCapture?.continuousTicks == pin)
        #expect(fixture.requests.filter { $0.url?.lastPathComponent == "authorize" }.count == 1)
    }

    @Test func pairTokenReplacementPermanentlyClosesOriginalRead() async throws {
        let fixture = try wire(); defer { fixture.close() }
        let flags = DirectRichModelFlags(), store = DJConnectInMemoryTokenStore(token: "paired-original")
        let owner = try owner(fixture, flags: flags, store: store)
        let first = try await owner.authorize()
        try store.saveToken("paired-replacement")
        do { _ = try await owner.read(); Issue.record("Replacement token adopted") } catch {}
        try store.saveToken("paired-original")
        do { _ = try await owner.read(); Issue.record("ABA token rearmed original") } catch {}
        #expect(owner.state == .closed && first.frame == nil)
        #expect(fixture.requests.count == 1)
    }

    @Test func twoOriginalAssetsDispatchBeforeEitherReplyAndRemainByteIdentical() async throws {
        let gate = DirectRichAssetGate(), (fixture, pixels) = try artworkWire(gate: gate)
        defer { gate.release(); fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags()), candidate = try await owner.authorize()
        let task = Task { await owner.artwork(for: candidate) }
        try await waitForTwoAssets(fixture)
        #expect(!gate.isReleased)
        gate.release()
        let slots = await task.value
        #expect(slots.count == 2 && slots["contribution"] == pixels && slots["now_playing"] == pixels)
    }

    @Test func invalidOriginalPixelsRemoveOnlyArtworkAndKeepText() async throws {
        let (fixture, _) = try artworkWire(corrupt: true); defer { fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags()), candidate = try await owner.authorize()
        #expect(await owner.artwork(for: candidate).isEmpty)
        #expect(owner.state == .active && candidate.frame?.now_playing != nil && candidate.frame?.contribution != nil)
    }

    @Test func retirementCancelsAssetsWithoutWaitingForTheirReplies() async throws {
        let gate = DirectRichAssetGate(), (fixture, _) = try artworkWire(gate: gate)
        defer { gate.release(); fixture.close() }
        let owner = try owner(fixture, flags: DirectRichModelFlags()), candidate = try await owner.authorize()
        let task = Task { await owner.artwork(for: candidate) }
        try await waitForTwoAssets(fixture)
        let releaseWatchdog = Task { try? await Task.sleep(for: .seconds(2)); if !Task.isCancelled { gate.release() } }
        defer { releaseWatchdog.cancel() }
        owner.retire()
        #expect(candidate.frame == nil)
        #expect(await task.value.isEmpty)
        #expect(!gate.isReleased) // Completion came from cancellation, not bytes.
    }
}

@Suite @MainActor struct DirectRichHTTPSChannelTests {
    private func read() throws -> DirectRichRequest {
        try DirectRichRequest(operation: .read, originalBody: Data(#"{"contract_version":1,"purpose_id":"63506d46-eeaf-409c-8d82-e6d01cc9e2fb"}"#.utf8))
    }
    private let credential = "djcrichread_" + String(repeating: "A", count: 43)

    @Test func exactHTTPSRequestAndNoAuthorityInTransportReply() async throws {
        let fixture = DirectRichHTTPFixture(); defer { fixture.close() }
        let channel = try fixture.channel()
        let reply = try await channel.send(read(), credential: credential, beforeDispatch: {}, isCurrent: { fixture.isCurrent })
        #expect(reply.bytes == Data("{}".utf8)) // Only raw bytes: not an active permit.
        let sent = try #require(fixture.requests.first)
        #expect(sent.url?.absoluteString == "https://\(fixture.host)/api/djconnect/v1/session/rich/read")
        #expect(sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer " + credential)
        #expect(sent.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == nil)
        #expect(sent.value(forHTTPHeaderField: "X-DJConnect-Client-Type") == nil)
        #expect(fixture.requests.count == 1)
    }

    @Test func pairedManagementHeadersMatchOriginalBody() async throws {
        let fixture = DirectRichHTTPFixture(); defer { fixture.close() }
        let intent = try DirectRichRequest(operation: .status, originalBody: Data(#"{"contract_version":1,"operation_id":"4cf66d62-d59f-4093-9e39-4c101ee0351b","device_id":"djconnect-ios-ABCDEF012345","client_type":"ios","session_id":"s","surface":"live_activity"}"#.utf8))
        _ = try await fixture.channel().send(intent, credential: "original-paired-token", beforeDispatch: {}, isCurrent: { fixture.isCurrent })
        let sent = try #require(fixture.requests.first)
        #expect(sent.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == "djconnect-ios-ABCDEF012345")
        #expect(sent.value(forHTTPHeaderField: "X-DJConnect-Client-Type") == "ios")
        #expect(fixture.requests.count == 1)
    }

    @Test(arguments: ["http://ha.invalid", "https://user:pass@ha.invalid", "https://ha.invalid/path", "https://ha.invalid?q=secret", "https://ha.invalid/#x"])
    func configuredURLAloneCannotSelectAnotherChannel(_ text: String) throws {
        #expect(throws: (any Error).self) { _ = try DirectRichHTTPSChannel(pairedHTTPSOrigin: #require(URL(string: text))) }
    }

    @Test func revokedOwnerAndDispatchFailureSendNothing() async throws {
        let fixture = DirectRichHTTPFixture(); defer { fixture.close() }
        let channel = try fixture.channel()
        do {
            _ = try await channel.send(read(), credential: credential, beforeDispatch: { throw CancellationError() }, isCurrent: { fixture.isCurrent })
            Issue.record("Dispatch unexpectedly succeeded")
        } catch {}
        fixture.invalidate()
        do {
            _ = try await channel.send(read(), credential: credential, beforeDispatch: {}, isCurrent: { fixture.isCurrent })
            Issue.record("Revoked owner dispatched")
        } catch {}
        #expect(fixture.requests.isEmpty)
    }

    @Test(arguments: ["paired-token", "djcrichasset_" + String(repeating: "A", count: 43), "djcrichread_" + String(repeating: "A", count: 42) + "B", "djcrichread_abc\r\nInjected: secret"])
    func credentialRolesNeverFallback(_ token: String) async throws {
        let fixture = DirectRichHTTPFixture(); defer { fixture.close() }
        do {
            _ = try await fixture.channel().send(read(), credential: token, beforeDispatch: {}, isCurrent: { fixture.isCurrent })
            Issue.record("Wrong credential role dispatched")
        } catch {}
        #expect(fixture.requests.isEmpty)
    }

    @Test func serverDenialIsTypedAndNeverRetriedOrUnpaired() async throws {
        let fixture = DirectRichHTTPFixture(status: 503, data: Data(#"{"success":false,"contract_version":1,"error":"rich_frame_unavailable"}"#.utf8))
        defer { fixture.close() }
        do {
            _ = try await fixture.channel().send(read(), credential: credential, beforeDispatch: {}, isCurrent: { fixture.isCurrent })
            Issue.record("Error response accepted")
        } catch let error as DirectRichServerError { #expect(error == .frameUnavailable) }
        #expect(fixture.requests.count == 1)
    }

    @Test(arguments: ["Cache-Control", "X-Content-Type-Options", "Referrer-Policy", "Content-Type"])
    func missingRequiredResponseHeaderRejects(_ header: String) async throws {
        var headers = ["Content-Type": "application/json", "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff", "Referrer-Policy": "no-referrer"]
        headers.removeValue(forKey: header)
        let fixture = DirectRichHTTPFixture(headers: headers); defer { fixture.close() }
        do {
            _ = try await fixture.channel().send(read(), credential: credential, beforeDispatch: {}, isCurrent: { fixture.isCurrent })
            Issue.record("Missing required response header accepted")
        } catch {}
        #expect(fixture.requests.count == 1)
    }
}
