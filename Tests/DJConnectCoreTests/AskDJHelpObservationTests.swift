import Foundation
import Testing
@testable import DJConnectCore

private final class HelpObservationWire: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var body = Data()
    nonisolated(unsafe) private static var requests: [URLRequest] = []
    nonisolated(unsafe) private static var current = true
    nonisolated(unsafe) private static var invalidateOnReply = false
    static func setup(_ bytes: Data, invalidate: Bool) {
        lock.withLock { body = bytes; requests = []; current = true; invalidateOnReply = invalidate }
    }
    static var isCurrent: Bool { lock.withLock { current } }
    static var captured: [URLRequest] { lock.withLock { requests } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let data = Self.lock.withLock { Self.requests.append(request); return Self.body }
        let headers = ["Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store",
                       "Referrer-Policy": "no-referrer", "X-Content-Type-Options": "nosniff"]
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: headers)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        Self.lock.withLock { if Self.invalidateOnReply { Self.current = false } }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func helpBody(_ q: DJConnectAskDJHelpObservation.Request) -> [String: Any] {
    ["schema_version": 1, "request_id": q.id, "surface": q.surface.rawValue, "language": q.language,
     "session_id": q.sessionID as Any? ?? NSNull(), "track_id": NSNull(),
     "catalogue": ["schema_version": 1, "catalogue_id": "ask_dj_examples_v1", "revision": 2,
                   "sha256": DJConnectAskDJCatalogue.pinnedSHA256, "qualified": true],
     "available": true, "observation_id": UUID().uuidString.lowercased(), "eligible_entry_ids": []]
}

@Test(.isolatedClientResources) func helpObservationUsesExactLanguageSessionAndEscapedPlus() throws {
    let q = try DJConnectAskDJHelpObservation.Request(surface: .session, language: "nl", sessionID: "own+a/b")
    #expect(q.query().contains("session_id=own%2Ba%2Fb"))
    #expect(q.query().split(separator: "&").count == 8)
    #expect(throws: (any Error).self) { try DJConnectAskDJHelpObservation.Request(surface: .session, language: "nl", sessionID: nil) }
    #expect(throws: (any Error).self) { try DJConnectAskDJHelpObservation.Request(surface: .askDJ, language: "nl-NL", sessionID: nil) }
}

@Test(.isolatedClientResources) func helpObservationClosedDecoderRejectsShapeEchoPinAndLexicalMutations() throws {
    let catalogue = try #require(DJConnectAskDJCatalogue.bundled)
    let q = try DJConnectAskDJHelpObservation.Request(surface: .askDJ, language: "en", sessionID: nil)
    let base = helpBody(q)
    func bytes(_ value: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: value, options: .sortedKeys) }
    #expect(try DJConnectAskDJHelpObservation.decode(bytes(base), matching: q, catalogue: catalogue).available)
    var mutations: [[String: Any]] = []
    for (key, value) in [("language", "nl" as Any), ("schema_version", true), ("available", 1),
                         ("surface", "active_session"), ("session_id", "foreign"), ("track_id", "foreign"),
                         ("observation_id", "not-uuid"), ("eligible_entry_ids", ["unknown"]) ] {
        var bad = base; bad[key] = value; mutations.append(bad)
    }
    var extra = base; extra["unknown"] = true; mutations.append(extra)
    var missing = base; missing.removeValue(forKey: "track_id"); mutations.append(missing)
    for field in ["revision", "sha256", "qualified"] {
        var bad = base, descriptor = base["catalogue"] as! [String: Any]
        descriptor[field] = field == "revision" ? 1 : field == "qualified" ? false : "wrong"
        bad["catalogue"] = descriptor; mutations.append(bad)
    }
    for bad in mutations {
        #expect(throws: (any Error).self) { try DJConnectAskDJHelpObservation.decode(bytes(bad), matching: q, catalogue: catalogue) }
    }
    let raw = String(decoding: try bytes(base), as: UTF8.self)
    for altered in [raw.replacingOccurrences(of: "\"schema_version\":1", with: "\"schema_version\":1.0"),
                    raw.replacingOccurrences(of: "\"schema_version\":1", with: "\"schema_version\":1e0"),
                    "{\"available\":false," + raw.dropFirst()] {
        #expect(throws: (any Error).self) { try DJConnectAskDJHelpObservation.decode(Data(altered.utf8), matching: q, catalogue: catalogue) }
    }
    var closed = base; closed["available"] = false; closed["observation_id"] = NSNull()
    #expect(try !DJConnectAskDJHelpObservation.decode(bytes(closed), matching: q, catalogue: catalogue).available)
}

@Test(.isolatedClientResources) func helpObservationCanonicalOrderAndPerEntryMaskPreservePendingLocales() throws {
    let catalogue = try #require(DJConnectAskDJCatalogue.bundled)
    let q = try DJConnectAskDJHelpObservation.Request(surface: .askDJ, language: "nl", sessionID: nil)
    let ids = catalogue.entries.filter { !$0.requires.contains("current_track") }.map(\.id)
    var body = helpBody(q); body["eligible_entry_ids"] = ids
    let result = try DJConnectAskDJHelpObservation.decode(JSONSerialization.data(withJSONObject: body), matching: q, catalogue: catalogue)
    for badIDs in [ids + [ids[0]], Array(ids.reversed())] {
        body["eligible_entry_ids"] = badIDs
        #expect(throws: (any Error).self) { try DJConnectAskDJHelpObservation.decode(JSONSerialization.data(withJSONObject: body), matching: q, catalogue: catalogue) }
    }
    var context = DJConnectAskDJCatalogue.Context()
    context.descriptor = .init(schema_version: 1, qualified: true, catalogue_id: "ask_dj_examples_v1", revision: 2, sha256: DJConnectAskDJCatalogue.pinnedSHA256)
    context.contracts = ["ask_dj_examples": 1, "ask_dj": 1]
    for entry in catalogue.entries {
        for flag in entry.requires { context.flags[flag] = true }
        for (key, version) in entry.contracts { context.contracts[key] = version }
    }
    context.flags["agent_available"] = false
    #expect(catalogue.select(context, surface: .askDJ, language: "nl", epoch: "without-observation").isEmpty)
    context.serverEligibleIDs = result.eligibleIDs
    #expect(!catalogue.catalogueSections(context, surface: .askDJ, language: "nl", eligibleIDs: result.eligibleIDs).isEmpty)
    for language in ["de", "fr", "es"] {
        #expect(catalogue.catalogueSections(context, surface: .askDJ, language: language, eligibleIDs: result.eligibleIDs).isEmpty)
    }
}

@Test(.isolatedClientResources) func helpObservationConsumesOriginalCoreActualHAWireCases() throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/askdj-help-r5-core-wire.json")
    let fixture = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let cases = try #require(fixture["cases"] as? [[String: Any]])
    let catalogue = try #require(DJConnectAskDJCatalogue.bundled)
    #expect(cases.count == 18)
    for row in cases {
        if row["status"] as? Int != 200 {
            let request = try DJConnectAskDJHelpObservation.Request(surface: .askDJ, language: "nl", sessionID: nil)
            let response = try #require(row["response_body"] as? [String: Any])
            #expect(throws: (any Error).self) { try DJConnectAskDJHelpObservation.decode(JSONSerialization.data(withJSONObject: response), matching: request, catalogue: catalogue) }
            continue
        }
        let query = try #require(row["synthetic_request"] as? [String: Any])
        let surfaceName = try #require(query["surface"] as? String)
        let surface = try #require(DJConnectAskDJCatalogue.Surface(rawValue: surfaceName))
        let language = try #require(query["language"] as? String)
        let request = try DJConnectAskDJHelpObservation.Request(surface: surface,
            language: language, sessionID: query["session_id"] as? String)
        var response = try #require(row["response_body"] as? [String: Any])
        // Only replace the fixture's correlation UUID with this actual request;
        // eligibility, subjects, descriptor and all other wire fields are original.
        response["request_id"] = request.id
        let value = try DJConnectAskDJHelpObservation.decode(JSONSerialization.data(withJSONObject: response), matching: request, catalogue: catalogue)
        #expect(value.available == row["available"] as? Bool)
        #expect(value.eligibleIDs == Set(response["eligible_entry_ids"] as? [String] ?? []))
    }
}

@Suite(.serialized) @MainActor struct HelpObservationHTTPTests {
    @Test(.isolatedClientResources) func exactGETDoesNotBorrowAmbientHeadersAndLateReplyCannotRestoreAuthority() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HelpObservationWire.self]
        configuration.httpAdditionalHeaders = ["X-Ambient-Secret": "forbidden", "Authorization": "Bearer forbidden"]
        let client = DJConnectClient(baseURL: URL(string: "https://paired.example")!,
            identity: .init(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Test", clientType: .ios, firmware: "4", platform: .ios),
            tokenStore: DJConnectInMemoryTokenStore(token: "original-paired-test-token"), session: URLSession(configuration: configuration))
        let catalogue = try #require(DJConnectAskDJCatalogue.bundled)
        for invalidated in [false, true] {
            let request = try DJConnectAskDJHelpObservation.Request(surface: .askDJ, language: "nl", sessionID: nil)
            HelpObservationWire.setup(try JSONSerialization.data(withJSONObject: helpBody(request)), invalidate: invalidated)
            if invalidated {
                await #expect(throws: (any Error).self) { try await client.askDJHelpObservation(request, catalogue: catalogue, isCurrent: { HelpObservationWire.isCurrent }) }
            } else {
                let response = try await client.askDJHelpObservation(request, catalogue: catalogue, isCurrent: { HelpObservationWire.isCurrent })
                #expect(response.available)
            }
            let sent = try #require(HelpObservationWire.captured.first)
            #expect(HelpObservationWire.captured.count == 1)
            #expect(sent.httpMethod == "GET" && sent.httpBody == nil)
            #expect(sent.url?.path == "/api/djconnect/v1/ask_dj/help-context")
            #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer original-paired-test-token")
            #expect(sent.value(forHTTPHeaderField: "X-Ambient-Secret") == nil)
        }
    }
}
