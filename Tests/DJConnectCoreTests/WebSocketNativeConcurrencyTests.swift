#if os(macOS)
import Foundation
import Testing
@testable import DJConnectCore

/// Actual Foundation WebSocket I/O against a loopback HA-protocol fixture.
/// This is transport proof, never real HA pairing, permission or provider acceptance.
@Suite @MainActor struct WebSocketNativeConcurrencyTests {
    @Test(.isolatedClientResources)
    func sharedAuthenticationAndCapabilitiesRouteThreeOutOfOrderCollectionReplies() async throws {
        try await withFixture { f in
            let first = Task { try await f.command("devices") }
            defer { first.cancel() }
            _ = try await f.waitFor { $0.auth == 1 }
            let second = Task { try await f.command("queue") }
            let third = Task { try await f.command("playlists") }
            defer { second.cancel(); third.cancel() }
            _ = try await f.control("auth")
            _ = try await f.waitFor { $0.commands.count == 3 }
            _ = try await f.control("results") // Deliberately reverse the actual replies.
            let values = try await [first.value, second.value, third.value]
            #expect(values.map(\.message) == ["devices", "queue", "playlists"])
            let state = try await f.control("state")
            #expect(state.connections == 1 && state.auth == 1 && state.capabilities == 1)
            #expect(state.premature == 0 && Set(state.commands.map(\.id)).count == 3)
        }
    }

    @Test(.isolatedClientResources)
    func cancelledStartupConsumerDoesNotCancelTheOtherConsumer() async throws {
        try await withFixture { f in
            let first = Task { try await f.command("devices") }; defer { first.cancel() }
            _ = try await f.waitFor { $0.auth == 1 }
            let second = Task { try await f.command("queue") }; defer { second.cancel() }
            try await f.waitForRuntime { $0.startup == 2 }
            first.cancel()
            if case .failure(let error) = await first.result { #expect(error is CancellationError) }
            else { Issue.record("Cancelled startup unexpectedly succeeded") }
            try await f.waitForRuntime { $0.startup == 1 }
            _ = try await f.control("auth")
            _ = try await f.waitFor { $0.commands.count == 1 }
            _ = try await f.control("results")
            #expect(try await second.value.message == "queue")
            let state = try await f.control("state")
            #expect(state.auth == 1 && state.capabilities == 1 && state.connections == 1)
        }
    }

    @Test(.isolatedClientResources)
    func cancelledReplyAndItsLateFrameCannotSatisfyAnotherRequest() async throws {
        try await withFixture { f in
            try await f.ready()
            let first = Task { try await f.command("devices") }; defer { first.cancel() }
            let second = Task { try await f.command("queue") }; defer { second.cancel() }
            _ = try await f.waitFor { $0.commands.count == 2 }
            try await f.waitForRuntime { $0.sending == 0 && $0.requests == 2 }
            first.cancel()
            if case .failure(let error) = await first.result { #expect(error is CancellationError) }
            else { Issue.record("Cancelled request unexpectedly succeeded") }
            _ = try await f.control("results")
            #expect(try await second.value.message == "queue")
            try await f.waitForRuntime { $0.ignored == 1 }
            let third = Task { try await f.command("playlists") }; defer { third.cancel() }
            _ = try await f.waitFor { $0.commands.count == 3 }
            _ = try await f.control("results")
            #expect(try await third.value.message == "playlists")
            #expect(try await f.control("state").connections == 1)
        }
    }

    @Test(.isolatedClientResources)
    func unknownIDIsConsumedWithoutCompletingTheLiveRequest() async throws {
        try await withFixture { f in
            try await f.ready()
            let pending = Task { try await f.command("devices") }; defer { pending.cancel() }
            _ = try await f.waitFor { $0.commands.count == 1 }
            _ = try await f.control("reply?id=999&keep=1")
            try await f.waitForRuntime { $0.ignored == 1 && $0.requests == 1 }
            _ = try await f.control("reply")
            #expect(try await pending.value.message == "devices")
        }
    }

    @Test(.isolatedClientResources, arguments: ["kind=bool", "kind=string", "kind=missing", "type=event"])
    func invalidIDTypesOrEnvelopeTypesCannotAliasTheRequest(query: String) async throws {
        try await withFixture { f in
            try await f.ready()
            let pending = Task { try await f.command("devices") }; defer { pending.cancel() }
            _ = try await f.waitFor { $0.commands.count == 1 }
            _ = try await f.control("reply?" + query)
            if case .failure = await pending.result { } else { Issue.record("Invalid envelope was accepted") }
            #expect(await f.adapter.inFlightCounts.requests == 0)
        }
    }

    @Test(.isolatedClientResources, arguments: [false, true])
    func uncertainWriteDoesNotReplayButSafeReadMayFallback(readOnly: Bool) async throws {
        let clock = NativeWireClock()
        try await withFixture(clock: clock) { f in
            try await f.ready()
            let command = readOnly ? "devices" : "next"
            let client = f.client(), transport = f.transport()
            _ = try client.makeDJConnectIdentity() // Exercise the real client namespace before waiting for a wire event.
            let pending = Task { try await transport.perform { try await $0.sendCommandResponse(.init(identity: f.identity, command: command)) } }
            defer { pending.cancel() }
            _ = try await f.waitFor { $0.commands.count == 1 }
            try await f.waitForRuntime { $0.requests == 1 && $0.sending == 0 }
            try await f.waitForClock(clock, seconds: readOnly ? 5 : 2)
            clock.advance(readOnly ? 5 : 2)
            if readOnly { #expect(try await pending.value.message == "devices") }
            else if case .failure(let error) = await pending.result { #expect(error as? DJConnectHybridTransportError == .deliveryUnknown) }
            else { Issue.record("Unacknowledged write unexpectedly succeeded") }
            let state = try await f.control("state")
            #expect(state.commands.count == 1 && state.httpCommands.count == (readOnly ? 1 : 0))
        }
    }

    @Test(.isolatedClientResources)
    func pendingCapacityIsReservedBeforeAnyNinthNativeSend() async throws {
        try await withFixture { f in
            try await f.ready()
            let tasks = (0..<8).map { _ in Task { try await f.command("queue") } }
            defer { for task in tasks { task.cancel() } }
            _ = try await f.waitFor { $0.commands.count == 8 }
            try await f.waitForRuntime { $0.requests == 8 && $0.sending == 0 }
            do { _ = try await f.command("devices"); Issue.record("Ninth request admitted") }
            catch let error as DJConnectError {
                if case .routeMissing = error { } else { Issue.record("Unexpected capacity error") }
            }
            #expect(try await f.control("state").commands.count == 8)
            _ = try await f.control("results")
            for task in tasks { #expect(try await task.value.message == "queue") }
        }
    }

    @Test(.isolatedClientResources)
    func oversizedNativeReplyRetiresPendingRequestsWithoutAcceptingItsBody() async throws {
        try await withFixture { f in
            try await f.ready()
            let pending = Task { try await f.command("devices") }; defer { pending.cancel() }
            _ = try await f.waitFor { $0.commands.count == 1 }
            _ = try await f.control("oversize")
            if case .failure = await pending.result { } else { Issue.record("Oversized reply accepted") }
            #expect(await f.adapter.inFlightCounts.requests == 0)
            #expect(await f.adapter.diagnostics.websocketConnected == false)
        }
    }

    @Test(.isolatedClientResources)
    func privateRejectionRemainsAuthoritativeAndDoesNotLeakOrRetireAnotherRequest() async throws {
        try await withFixture { f in
            try await f.ready()
            let ordinary = Task { try await f.command("queue") }; defer { ordinary.cancel() }
            _ = try await f.waitFor { $0.commands.count == 1 }
            do {
                _ = try await f.adapter.profileConversationHistory(identity: .init(identity: f.identity, deviceToken: "fixture-only-djc"))
                Issue.record("Authoritative Profile rejection accepted")
            } catch let error as DJConnectError {
                #expect(error == .server(statusCode: 200, message: nil))
            }
            #expect(await f.adapter.diagnostics.lastWebSocketError?.contains("HIDDEN") != true)
            _ = try await f.control("results")
            #expect(try await ordinary.value.message == "queue")
        }
    }

    @Test(.isolatedClientResources)
    func droppingTheAdapterClosesOnlyItsSocketNotTheSuppliedSession() async throws {
        try await withFixture { f in
            try await f.ready()
            weak var weakAdapter = f.adapter
            f.dropAdapter()
            for _ in 0..<200 {
                if weakAdapter == nil { break }
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(weakAdapter == nil)
            _ = try await f.waitFor { $0.openSockets == 0 }
            #expect(try await f.control("state").connections == 1) // The supplied HTTP session remains usable.
        }
    }

    @Test(.isolatedClientResources)
    func startupDeadlineSettlesAllConsumersWithoutRenewalFromANewJoiner() async throws {
        let clock = NativeWireClock()
        try await withFixture(clock: clock) { f in
            let first = Task { try await f.command("devices") }; defer { first.cancel() }
            _ = try await f.waitFor { $0.auth == 1 }
            try await f.waitForClock(clock, seconds: 15)
            let second = Task { try await f.command("queue") }; defer { second.cancel() }
            try await f.waitForRuntime { $0.startup == 2 }
            clock.advance(15)
            if case .failure = await first.result { } else { Issue.record("Expired startup admitted") }
            if case .failure = await second.result { } else { Issue.record("Joining renewed startup") }
            #expect(await f.adapter.inFlightCounts.startup == 0)
            #expect(try await f.control("state").commands.isEmpty)
        }
    }

    @Test(.isolatedClientResources)
    func exhaustedIDsNeverWrapOrReachANativeBusinessSend() async throws {
        try await withFixture(firstRequestID: Int.max) { f in
            _ = try await f.control("auth")
            do { try await f.adapter.prepare(); Issue.record("Exhausted ID allocated") }
            catch let error as DJConnectError {
                if case .routeMissing = error { } else { Issue.record("Unexpected exhaustion error") }
            }
            let state = try await f.control("state")
            #expect(state.capabilities == 0 && state.commands.isEmpty)
        }
    }

    @Test(.isolatedClientResources)
    func lostWriteAcknowledgementDoesNotFallThroughToHTTPOrTheRemoteOrigin() async throws {
        try await withFixture { f in
            try await f.ready()
            let adapter = try #require(f.adapter), identity = f.identity, session = f.httpSession
            let transport = DJConnectHATransportManager(localURL: f.baseURL,
                remoteURL: f.baseURL.appendingPathComponent("remote"), allowsRemoteFallback: true,
                clientFactory: { DJConnectClient(baseURL: $0, identity: identity,
                    tokenStore: DJConnectInMemoryTokenStore(token: "fixture-only-djc"), session: session, webSocketFastPath: adapter) })
            let pending = Task { try await transport.perform { try await $0.sendCommandResponse(.init(identity: identity, command: "next")) } }
            defer { pending.cancel() }
            _ = try await f.waitFor { $0.commands.count == 1 }
            try await f.waitForRuntime { $0.sending == 0 && $0.requests == 1 }
            _ = try await f.control("close")
            if case .failure(let error) = await pending.result { #expect(error as? DJConnectHybridTransportError == .deliveryUnknown) }
            else { Issue.record("Lost write acknowledgement replayed") }
            let state = try await f.control("state")
            #expect(state.commands.count == 1 && state.httpCommands.isEmpty)
        }
    }

    @Test(.isolatedClientResources)
    func aHeldOldNativeFailureCallbackCannotRetireTheReplacementSocket() async throws {
        let clock = NativeWireClock(), gate = NativeReaderFailureGate()
        defer { Task { await gate.release() } }
        try await withFixture(clock: clock, failureGate: gate) { f in
            try await f.ready()
            let first = Task { try await f.command("devices") }; defer { first.cancel() }
            _ = try await f.waitFor { $0.commands.count == 1 }
            try await f.waitForRuntime { $0.sending == 0 && $0.requests == 1 }
            _ = try await f.control("close")
            try await f.waitForAsync { await gate.beforeCount == 1 }
            try await f.waitForClock(clock, seconds: 5)
            clock.advance(5)
            if case .failure = await first.result { } else { Issue.record("Closed socket succeeded") }
            // The old reader's native error is held. A real send to its closed
            // socket retires that era through the independent send failure path.
            let probe = Task { try await f.command("queue") }; defer { probe.cancel() }
            if case .failure = await probe.result { } else { Issue.record("Closed-socket probe succeeded") }
            clock.advance(11)
            let replacement = Task { try await f.command("playlists") }; defer { replacement.cancel() }
            _ = try await f.waitFor { $0.connections == 2 && $0.commands.count == 2 }
            await gate.release()
            try await f.waitForAsync { await gate.afterCount >= 1 }
            #expect(await f.adapter.diagnostics.websocketConnected)
            _ = try await f.control("results")
            #expect(try await replacement.value.message == "playlists")
        }
    }

    @Test(.isolatedClientResources)
    func aHeldTokenLookupHasOneOriginalStartupDeadlineAndNoReplacementCredentialFanout() async throws {
        let clock = NativeWireClock(), tokens = NativeTokenGate()
        defer { Task { await tokens.release() } }
        try await withFixture(clock: clock, tokenGate: tokens) { f in
            let first = Task { try await f.command("devices") }; defer { first.cancel() }
            try await f.waitForAsync { await tokens.calls == 1 }
            try await f.waitForClock(clock, seconds: 15)
            clock.advance(14)
            let second = Task { try await f.command("queue") }; defer { second.cancel() }
            try await f.waitForRuntime { $0.startup == 2 }
            clock.advance(1) // The new consumer cannot renew the original startup budget.
            if case .failure = await first.result { } else { Issue.record("Expired token lookup admitted") }
            if case .failure = await second.result { } else { Issue.record("Joiner renewed token lookup") }
            do { _ = try await f.command("playlists"); Issue.record("A second credential lookup was admitted") }
            catch {
                let failure = (error as? DJConnectWebSocketPreDispatchFailure)?.error ?? error
                if let typed = failure as? DJConnectError {
                    if case .network = typed { } else if case .routeMissing = typed { } else { Issue.record("Unexpected startup failure") }
                } else { Issue.record("Missing pre-dispatch classification") }
            }
            #expect(await tokens.calls == 1)
            #expect(try await f.control("state").connections == 0)
            await tokens.release()
            try await f.waitForAsync { !(await f.adapter.startupIsActive) }
            #expect(try await f.control("state").connections == 0) // Late token did not create a socket.
        }
    }

    @Test(.isolatedClientResources)
    func nativeAuthenticationFailureBeforeBusinessDispatchAllowsOneHTTPAttempt() async throws {
        try await withFixture { f in
            let transport = f.transport()
            let request = Task { try await transport.perform { try await $0.sendCommandResponse(.init(identity: f.identity, command: "pause")) } }
            defer { request.cancel() }
            _ = try await f.waitFor { $0.auth == 1 }
            _ = try await f.control("close") // Actual SDK receive fails before any business request.
            #expect(try await request.value.message == "pause")
            let state = try await f.control("state")
            #expect(state.commands.isEmpty && state.httpCommands == ["pause"])
            #expect(state.connections == 1 && state.capabilities == 0)
        }
    }

    @Test(.isolatedClientResources)
    func cancellingAllStartupConsumersDoesNotSpawnASecondCredentialLookup() async throws {
        let tokens = NativeTokenGate()
        defer { Task { await tokens.release() } }
        try await withFixture(tokenGate: tokens) { f in
            let first = Task { try await f.command("devices") }; defer { first.cancel() }
            try await f.waitForAsync { await tokens.calls == 1 }
            let second = Task { try await f.command("queue") }; defer { second.cancel() }
            try await f.waitForRuntime { $0.startup == 2 }
            first.cancel(); second.cancel()
            for result in [await first.result, await second.result] {
                if case .failure(let error) = result { #expect(error is CancellationError) }
                else { Issue.record("Cancelled startup unexpectedly succeeded") }
            }
            #expect(await f.adapter.startupIsActive)
            do { _ = try await f.command("playlists"); Issue.record("Cancelled credential lookup replaced") }
            catch let error as DJConnectError {
                if case .routeMissing = error { } else { Issue.record("Wrong closed-startup result") }
            }
            #expect(await tokens.calls == 1)
            await tokens.release()
            try await f.waitForAsync { !(await f.adapter.startupIsActive) }
            #expect(try await f.control("state").connections == 0)
        }
    }

    @Test(.isolatedClientResources)
    func outgoingByteCapacityFailsBeforeANativeBusinessSend() async throws {
        try await withFixture { f in
            try await f.ready()
            let payload = DJConnectCommandPayload(identity: f.identity, command: "search_tracks",
                value: .string(String(repeating: "x", count: DJConnectIncomingPayloadLimiter.defaultMaxPayloadBytes + 1)))
            do {
                let _: DJConnectCommandResponse = try await f.adapter.command(payload,
                    identity: .init(identity: f.identity, deviceToken: "fixture-only-djc"), responseType: DJConnectCommandResponse.self)
                Issue.record("Oversized outbound request admitted")
            } catch let error as DJConnectError {
                if case .routeMissing = error { } else { Issue.record("Unexpected outgoing capacity failure") }
            }
            #expect(try await f.control("state").commands.isEmpty)
        }
    }

    private func withFixture(clock: NativeWireClock? = nil, failureGate: NativeReaderFailureGate? = nil, tokenGate: NativeTokenGate? = nil, firstRequestID: Int = 1, _ body: (NativeWebSocketWire) async throws -> Void) async throws {
        let f = try NativeWebSocketWire(clock: clock, failureGate: failureGate, tokenGate: tokenGate, firstRequestID: firstRequestID)
        do {
            try await f.start()
            do { try await body(f) }
            catch {
                if let state = try? await f.control("state") {
                    print("Native wire failure trace: connections=\(state.connections), auth=\(state.auth), capabilities=\(state.capabilities), commands=\(state.commands.count), premature=\(state.premature), http=\(state.httpCommands.count)")
                }
                throw error
            }
            try await f.stop()
        } catch { try? await f.stop(); throw error }
    }
}

@MainActor private final class NativeWebSocketWire {
    struct Command: Decodable { let id: Int; let command: String }
    struct State: Decodable {
        let connections: Int; let auth: Int; let capabilities: Int
        let commands: [Command]; let httpCommands: [String]; let premature: Int; let openSockets: Int
    }
    enum Failure: Error { case startup, conditionTimeout }
    let identity = DJConnectIdentity(deviceID: "djconnect-macos-fixture", deviceName: "Wire fixture", clientType: .macos, firmware: "fixture", platform: .macos)
    private let process = Process()
    private let directory: URL
    private let report: URL
    private let clock: NativeWireClock?
    private let failureGate: NativeReaderFailureGate?
    private let tokenGate: NativeTokenGate?
    private let firstRequestID: Int
    private let session = URLSession(configuration: .ephemeral)
    private(set) var baseURL: URL!
    private(set) var adapter: DJConnectHomeAssistantWebSocketFastPath!
    init(clock: NativeWireClock? = nil, failureGate: NativeReaderFailureGate? = nil, tokenGate: NativeTokenGate? = nil, firstRequestID: Int = 1) throws {
        self.clock = clock; self.failureGate = failureGate; self.tokenGate = tokenGate; self.firstRequestID = firstRequestID
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("native-websocket-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        report = directory.appendingPathComponent("server.json")
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["node", root.appendingPathComponent("Tools/qualification/websocket-fast-path/server.js").path, report.path]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
    }
    func start() async throws {
        try process.run()
        for _ in 0..<200 {
            if let data = try? Data(contentsOf: report),
               let object = try JSONSerialization.jsonObject(with: data) as? [String: Int], let port = object["port"] {
                baseURL = URL(string: "http://127.0.0.1:\(port)")!
                let tokens = tokenGate
                let auth = DJConnectHomeAssistantWebSocketAuth(accessToken: {
                    if let tokens { return await tokens.value() }
                    return "fixture-only-ha"
                })
                if clock != nil || failureGate != nil || tokenGate != nil || firstRequestID != 1 {
                    var timing = DJConnectWebSocketRuntimeTiming.live
                    if let clock { timing.now = { clock.now }; timing.sleep = { try await clock.sleep($0) } }
                    if let failureGate {
                        timing.beforeReaderFailure = { await failureGate.before() }
                        timing.afterReaderFailure = { await failureGate.after() }
                    }
                    adapter = DJConnectHomeAssistantWebSocketFastPath(baseURL: baseURL,
                        homeAssistantAuth: auth, session: session,
                        timing: timing, firstRequestID: firstRequestID)
                } else {
                    adapter = DJConnectHomeAssistantWebSocketFastPath(baseURL: baseURL,
                        homeAssistantAuth: auth, session: session)
                }
                return
            }
            guard process.isRunning else { throw Failure.startup }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw Failure.startup
    }
    func stop() async throws {
        session.invalidateAndCancel()
        if process.isRunning { process.terminate() } // This Node fixture has no child processes.
        for _ in 0..<200 {
            if !process.isRunning {
                try? FileManager.default.removeItem(at: directory)
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw Failure.conditionTimeout
    }
    var httpSession: URLSession { session }
    func dropAdapter() { adapter = nil }
    func waitForAsync(_ predicate: () async -> Bool) async throws {
        for _ in 0..<200 {
            if await predicate() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw Failure.conditionTimeout
    }
    func ready() async throws { _ = try await control("auth"); try await adapter.prepare() }
    func client() -> DJConnectClient {
        DJConnectClient(baseURL: baseURL, identity: identity, tokenStore: DJConnectInMemoryTokenStore(token: "fixture-only-djc"), session: session, webSocketFastPath: adapter)
    }
    func transport() -> DJConnectHATransportManager {
        let capturedIdentity = identity, capturedSession = session, capturedAdapter = adapter
        return DJConnectHATransportManager(localURL: baseURL, remoteURL: baseURL.appendingPathComponent("remote"),
            allowsRemoteFallback: true, clientFactory: {
                DJConnectClient(baseURL: $0, identity: capturedIdentity,
                    tokenStore: DJConnectInMemoryTokenStore(token: "fixture-only-djc"),
                    session: capturedSession, webSocketFastPath: capturedAdapter)
            })
    }
    func waitForRuntime(_ predicate: ((startup: Int, requests: Int, sending: Int, ignored: Int)) -> Bool) async throws {
        for _ in 0..<200 {
            if predicate(await adapter.inFlightCounts) { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw Failure.conditionTimeout
    }
    func waitForClock(_ clock: NativeWireClock, seconds: TimeInterval) async throws {
        for _ in 0..<200 {
            if clock.hasSleep(seconds: seconds) { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw Failure.conditionTimeout
    }
    func command(_ name: String) async throws -> DJConnectCommandResponse {
        try await adapter.command(.init(identity: identity, command: name),
            identity: .init(identity: identity, deviceToken: "fixture-only-djc"), responseType: DJConnectCommandResponse.self)
    }
    func control(_ path: String) async throws -> State {
        var request = URLRequest(url: URL(string: "/_test/" + path, relativeTo: baseURL)!.absoluteURL)
        request.timeoutInterval = 2
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.startup }
        return try JSONDecoder().decode(State.self, from: data)
    }
    func waitFor(_ predicate: (State) -> Bool) async throws -> State {
        for _ in 0..<200 {
            let value = try await control("state")
            if predicate(value) { return value }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw Failure.conditionTimeout
    }
}
/// Advances only local transport deadlines after an observed native wire event.
private final class NativeWireClock: @unchecked Sendable {
    private let lock = NSLock()
    private var elapsed: TimeInterval = 0
    private var cancelled = Set<UUID>()
    private struct Sleep { let end: TimeInterval; let interval: TimeInterval; let value: CheckedContinuation<Void, Error> }
    private var sleeps: [UUID: Sleep] = [:]
    var now: Date { lock.withLock { Date(timeIntervalSince1970: 1_800_000_000 + elapsed) } }
    func hasSleep(seconds: TimeInterval) -> Bool { lock.withLock { sleeps.values.contains { $0.interval == seconds } } }
    func sleep(_ seconds: TimeInterval) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (value: CheckedContinuation<Void, Error>) in
                let stop = lock.withLock {
                    if cancelled.remove(id) != nil || Task.isCancelled { return true }
                    sleeps[id] = Sleep(end: elapsed + seconds, interval: seconds, value: value); return false
                }
                if stop { value.resume(throwing: CancellationError()) }
            }
        } onCancel: {
            let value = self.lock.withLock { self.cancelled.insert(id); return self.sleeps.removeValue(forKey: id)?.value }
            value?.resume(throwing: CancellationError())
        }
    }
    func advance(_ seconds: TimeInterval) {
        let due = lock.withLock {
            elapsed += seconds
            let keys = sleeps.filter { $0.value.end <= elapsed }.map(\.key)
            return keys.compactMap { sleeps.removeValue(forKey: $0)?.value }
        }
        for value in due { value.resume() }
    }
}
private actor NativeReaderFailureGate {
    private(set) var beforeCount = 0
    private(set) var afterCount = 0
    private var released = false
    private var held: CheckedContinuation<Void, Never>?
    func before() async {
        beforeCount += 1
        if beforeCount == 1 && !released { await withCheckedContinuation { held = $0 } }
    }
    func after() { afterCount += 1 }
    func release() { released = true; held?.resume(); held = nil }
}
private actor NativeTokenGate {
    private(set) var calls = 0
    private var released = false
    private var held: [CheckedContinuation<Void, Never>] = []
    func value() async -> String {
        calls += 1
        if !released { await withCheckedContinuation { held.append($0) } }
        return "fixture-only-ha"
    }
    func release() { released = true; let values = held; held.removeAll(); for value in values { value.resume() } }
}
#endif
