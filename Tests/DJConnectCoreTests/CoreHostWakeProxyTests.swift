import Foundation
import Testing
@testable import DJConnectCore

@Suite @MainActor struct CoreHostWakeProxyTests {
    private struct Vector: Decodable {
        let route: String; let request: DirectRichWireJSON; let preimage_utf8: String; let request_sha256: String
    }
    private struct Packet: Decodable { let vectors: [Vector] }
    private func vectors() throws -> [Vector] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: CoreProxyFixtureAnchor.self)
        #endif
        let url = try #require(bundle.url(forResource: "host-wake-core-proxy-request-vectors", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "host-wake-core-proxy-request-vectors", withExtension: "json"))
        return try JSONDecoder().decode(Packet.self, from: Data(contentsOf: url)).vectors
    }
    private func request(_ operation: CoreHostWakeProxyRequest.Operation = .status) throws -> CoreHostWakeProxyRequest {
        let v = try #require(vectors().first { $0.route == operation.rawValue })
        return try CoreHostWakeProxyRequest(operation: operation, originalBody: v.request.canonicalData())
    }
    private var identity: DJConnectIdentity {
        .init(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Synthetic fixture", clientType: .ios, firmware: "test", platform: .ios)
    }
    private func channel(_ wire: CoreProxyWireFixture, store: DJConnectInMemoryTokenStore = .init(token: "original-paired-token")) throws -> CoreHostWakeProxyChannel {
        try CoreHostWakeProxyChannel(testOrigin: wire.origin, session: wire.session(), tokenStore: store, identity: identity)
    }

    @Test func sevenOriginalCoreRequestPreimagesMatchAndRoutesCannotAlias() throws {
        let values = try vectors(); #expect(values.count == 7)
        for v in values {
            let operation = try #require(CoreHostWakeProxyRequest.Operation(rawValue: v.route))
            let request = try CoreHostWakeProxyRequest(operation: operation, originalBody: v.request.canonicalData())
            #expect(request.correlationPreimage == Data(v.preimage_utf8.utf8))
            #expect(request.sha256 == v.request_sha256)
            var extra = try #require(v.request.object); extra["unexpected"] = .bool(true)
            #expect(throws: (any Error).self) { _ = try CoreHostWakeProxyRequest(operation: operation, originalBody: DirectRichWireJSON.object(extra).canonicalData()) }
            extra.removeValue(forKey: "unexpected"); extra.removeValue(forKey: "purpose_id")
            #expect(throws: (any Error).self) { _ = try CoreHostWakeProxyRequest(operation: operation, originalBody: DirectRichWireJSON.object(extra).canonicalData()) }
            // The JSON Schema validation envelope is deliberately NOT HTTP wire.
            let envelope = DirectRichWireJSON.object(["method": .string("POST"), "path": .string(operation.path), "direction": .string("request"), "body": v.request])
            #expect(throws: (any Error).self) { _ = try CoreHostWakeProxyRequest(operation: operation, originalBody: envelope.canonicalData()) }
        }
        #expect(try request(.status).body == request(.withdraw).body)
        #expect(try request(.status).sha256 != request(.withdraw).sha256)
        #expect(try request(.status).sha256 != request(.nativeChallenge).sha256)
    }

    @Test(arguments: ["macos", "readCredential", "unsafeVersion", "proofKind", "emptyProof", "padBits", "tokenURL", "challenge", "keyURL"])
    func requestSemanticBoundariesRejectInvalidIntentions(_ variant: String) throws {
        let operation: CoreHostWakeProxyRequest.Operation = ["proofKind", "emptyProof", "padBits"].contains(variant) ? .nativeComplete : variant == "tokenURL" ? .register : variant == "keyURL" ? .prepare : .nativeStatus
        var fields = try request(operation).fields
        switch variant {
        case "macos": fields["client_type"] = .string("macos")
        case "readCredential": fields["read_credential"] = .string("not-a-push-input")
        case "unsafeVersion": fields["contract_version"] = .integer(2)
        case "proofKind": fields["native_proof"] = .object(["kind": .string("widget"), "bytes_b64": .string("YQ==")])
        case "emptyProof": fields["native_proof"] = .object(["kind": .string("app_attest_assertion"), "bytes_b64": .string("")])
        case "padBits": fields["native_proof"] = .object(["kind": .string("app_attest_assertion"), "bytes_b64": .string("YR==")])
        case "tokenURL": fields["native_token_b64"] = .string(String(repeating: "_", count: 43))
        case "keyURL": fields["native_key_id_b64"] = .string("-_8")
        default: fields["challenge_id"] = .string("11111111-1111-1111-8111-111111111111")
        }
        #expect(throws: (any Error).self) { _ = try CoreHostWakeProxyRequest(operation: operation, originalBody: DirectRichWireJSON.object(fields).canonicalData()) }
    }

    @Test func exactPairedCoreHTTPBodyHeadersAndNoAutomaticReplay() async throws {
        let wire = CoreProxyWireFixture(); defer { wire.close() }
        let request = try request(), channel = try channel(wire)
        let reply = try await channel.send(request, beforeDispatch: {}, isCurrent: { true })
        #expect(reply.status == 200 && reply.body == wire.bytes) // DATA receipt only, not a registered/native permit.
        let captured = try #require(wire.requests.first)
        #expect(captured.httpMethod == "POST" && captured.url?.path == request.operation.path && captured.httpBody == request.body)
        #expect(captured.value(forHTTPHeaderField: "Authorization") == "Bearer original-paired-token")
        #expect(captured.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
        #expect(captured.value(forHTTPHeaderField: "X-DJConnect-Client-Type") == "ios")
        #expect(captured.value(forHTTPHeaderField: "Cookie") == nil && captured.value(forHTTPHeaderField: "Origin") == nil)
        #expect(wire.requests.count == 1)
    }

    @Test(arguments: ["currentness", "token", "device", "dispatch"])
    func originalNegativeBeforeDispatchMakesNoRequest(_ variant: String) async throws {
        let wire = CoreProxyWireFixture(); defer { wire.close() }
        let store = DJConnectInMemoryTokenStore(token: "original-paired-token"), channel = try channel(wire, store: store)
        var request = try request()
        if variant == "token" { try store.saveToken("replacement-paired-token") }
        if variant == "device" {
            var f = request.fields; f["device_id"] = .string("djconnect-ios-ZZZZZZ123456")
            request = try CoreHostWakeProxyRequest(operation: .status, originalBody: DirectRichWireJSON.object(f).canonicalData())
        }
        do {
            _ = try await channel.send(request, beforeDispatch: { if variant == "dispatch" { throw CancellationError() } }, isCurrent: { variant != "currentness" })
            Issue.record("Closed original dispatched")
        } catch {}
        #expect(wire.requests.isEmpty)
    }

    @Test(arguments: ["token", "currentness", "cancel"])
    func lateReplyCannotSurviveOriginalOwnerLoss(_ variant: String) async throws {
        let wire = CoreProxyWireFixture(hold: true); defer { wire.release(); wire.close() }
        let store = DJConnectInMemoryTokenStore(token: "original-paired-token"), channel = try channel(wire, store: store)
        let request = try request()
        let pending = Task { () -> Bool in
            do { _ = try await channel.send(request, beforeDispatch: {}, isCurrent: { wire.isCurrent }); return true } catch { return false }
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while wire.requests.isEmpty, ContinuousClock.now < deadline { await Task.yield() }
        #expect(wire.requests.count == 1)
        if variant == "token" { try store.saveToken("replacement-paired-token") }
        else if variant == "currentness" { wire.invalidate() }
        else { pending.cancel() }
        wire.release()
        #expect(await pending.value == false && wire.requests.count == 1)
    }

    @Test(arguments: ["cache", "mime", "size", "encoding", "duplicate", "utf8", "status"])
    func boundedHTTPMetadataAndRawJSONRemainMandatory(_ variant: String) async throws {
        let wire = CoreProxyWireFixture(variant: variant); defer { wire.close() }
        do { _ = try await channel(wire).send(request(), beforeDispatch: {}, isCurrent: { true }); Issue.record("Invalid Core response accepted") } catch {}
        #expect(wire.requests.count == 1)
    }
}
private final class CoreProxyFixtureAnchor: NSObject {}

private final class CoreProxyWireFixture: @unchecked Sendable {
    let origin = URL(string: "https://proxy-" + UUID().uuidString.lowercased() + ".invalid")!
    let bytes: Data; let headers: [String: String]; let status: Int
    private let lock = NSLock(); private var recorded: [URLRequest] = []; private var pending: [@Sendable () -> Void] = []
    private var held: Bool; private var current = true
    var requests: [URLRequest] { lock.withLock { recorded } }
    var isCurrent: Bool { lock.withLock { current } }
    func invalidate() { lock.withLock { current = false } }
    init(hold: Bool = false, variant: String = "") {
        held = hold
        var h = ["Content-Type": "application/json", "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff", "Referrer-Policy": "no-referrer"]
        if variant == "cache" { h.removeValue(forKey: "Cache-Control") }
        if variant == "mime" { h["Content-Type"] = "text/html" }
        if variant == "encoding" { h["Content-Encoding"] = "gzip" }
        if variant == "size" { h["Content-Length"] = "16385" }
        headers = h; status = variant == "status" ? 302 : 200
        bytes = variant == "duplicate" ? Data(#"{"success":true,"success":true}"#.utf8) : variant == "utf8" ? Data([0xff]) : Data(#"{"success":true}"#.utf8)
        CoreProxyWire.install(self)
    }
    func accept(_ request: URLRequest, deliver: @escaping @Sendable () -> Void) {
        let ready = lock.withLock { recorded.append(request); if held { pending.append(deliver); return false }; return true }
        if ready { deliver() }
    }
    func release() { let callbacks = lock.withLock { held = false; let v = pending; pending = []; return v }; for f in callbacks { f() } }
    func session() -> URLSession { let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [CoreProxyWire.self]; return URLSession(configuration: c) }
    func close() { CoreProxyWire.remove(self) }
}
private final class CoreProxyWire: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var fixtures: [String: CoreProxyWireFixture] = [:]
    private let stateLock = NSLock(); private var stopped = false
    static func install(_ f: CoreProxyWireFixture) { lock.withLock { fixtures[f.origin.host!] = f } }
    static func remove(_ f: CoreProxyWireFixture) { _ = lock.withLock { fixtures.removeValue(forKey: f.origin.host!) } }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host?.hasPrefix("proxy-") == true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let host = request.url?.host, let f = Self.lock.withLock({ Self.fixtures[host] }) else { return }
        // URLSession may move an HTTP body into a stream before URLProtocol.
        // Observe those actual bytes rather than replacing a missing body with
        // the expected fixture payload or weakening the body assertion.
        var captured = request
        if captured.httpBody == nil, let stream = captured.httpBodyStream {
            stream.open(); defer { stream.close() }
            var bytes = Data(), buffer = [UInt8](repeating: 0, count: 1024)
            while bytes.count <= 16384 {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                bytes.append(contentsOf: buffer.prefix(count))
            }
            captured.httpBody = bytes
        }
        f.accept(captured) { [self] in
            guard !stateLock.withLock({ stopped }) else { return }
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: f.status, httpVersion: nil, headerFields: f.headers)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: f.bytes); client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() { stateLock.withLock { stopped = true } }
}
