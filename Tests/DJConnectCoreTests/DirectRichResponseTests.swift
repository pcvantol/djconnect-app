import Foundation
import Testing
@testable import DJConnectCore

@Suite struct DirectRichResponseTests {
    private func fixture() throws -> [String: DirectRichWireJSON] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: DirectRichResponseFixtureAnchor.self)
        #endif
        let url = try #require(bundle.url(forResource: "direct-rich-synthetic-responses", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "direct-rich-synthetic-responses", withExtension: "json"))
        return try #require(DirectRichWireJSON.parse(Data(contentsOf: url), maximumBytes: 65536).object)
    }
    private func request(_ name: String, _ operation: DirectRichRequest.Operation) throws -> DirectRichRequest {
        try DirectRichRequest(operation: operation, originalBody: try #require(fixture()[name]).canonicalData())
    }
    private func authorization() throws -> DirectRichResponse.Active {
        try DirectRichResponse.active(try #require(fixture()["authorize_response"]).canonicalData(), request: request("authorize_request", .authorize))
    }
    private func mutate(_ name: String, _ change: (inout [String: DirectRichWireJSON]) throws -> Void) throws -> Data {
        var fields = try #require(fixture()[name]?.object); try change(&fields)
        return try DirectRichWireJSON.object(fields).canonicalData()
    }

    @Test func fullResearchGraphAndOriginalBoundsSurviveRead() throws {
        let first = try authorization()
        let next = try DirectRichResponse.active(try #require(fixture()["read_response"]).canonicalData(), request: request("read_request", .read), original: first.original)
        let story = try #require(next.frame.contribution)
        #expect(story.sources?.count == 1)
        #expect(story.sources?.first?.revision_url == "https://en.wikipedia.org/w/index.php?oldid=1")
        #expect(story.expression_license?.attribution_required == true)
        #expect(story.expression_license?.adapted == true)
        #expect(!story.rights.external_relay && !story.rights.watch_replication)
        #expect(next.original.issuedMS == first.original.issuedMS && next.original.expiresMS == first.original.expiresMS)
        #expect(next.frame.now_playing?.track.unicodeScalars.map(\.value) == "Track e\u{301} 🎵".unicodeScalars.map(\.value))
    }

    @Test(arguments: ["purpose_id", "operation_id", "request_sha256", "surface", "purpose_issued_at_ms", "purpose_expires_at_ms"])
    func readCannotReplaceOriginalScopeOrDeadline(_ key: String) throws {
        let original = try authorization().original
        let changed = try mutate("read_response") { fields in
            switch fields[key] {
            case .integer(let n): fields[key] = .integer(n + 1)
            default: fields[key] = .string(key == "surface" ? "widget" : "22222222-2222-4222-8222-222222222222")
            }
        }
        #expect(throws: (any Error).self) { _ = try DirectRichResponse.active(changed, request: request("read_request", .read), original: original) }
    }

    @Test func everyFrameObjectRejectsUnknownFieldsAndHashSubstitution() throws {
        let packet = try fixture()
        let response = try #require(packet["authorize_response"]?.object)
        let frame = try #require(response["frame"])
        func altered(_ value: DirectRichWireJSON) -> [DirectRichWireJSON] {
            switch value {
            case .object(let fields):
                var extra = fields; extra["unowned_extra"] = .bool(true)
                var results: [DirectRichWireJSON] = [.object(extra)]
                for (key, child) in fields {
                    for changed in altered(child) { var copy = fields; copy[key] = changed; results.append(.object(copy)) }
                }
                return results
            case .array(let values):
                return values.enumerated().flatMap { index, child in altered(child).map { changed in var copy = values; copy[index] = changed; return .array(copy) } }
            default: return []
            }
        }
        let mutations = altered(frame)
        #expect(mutations.count >= 10)
        for mutation in mutations {
            var fields = try #require(mutation.object)
            fields.removeValue(forKey: "frame_id")
            let hash = try DirectRichWireJSON.object(fields).digest()
            fields["frame_id"] = .string(hash)
            var body = response; body["frame"] = .object(fields)
            #expect(throws: (any Error).self) { _ = try DirectRichResponse.active(DirectRichWireJSON.object(body).canonicalData(), request: request("authorize_request", .authorize)) }
        }
        let alteredHash = try mutate("authorize_response") { root in
            var frame = try #require(root["frame"]?.object); frame["frame_id"] = .string(String(repeating: "a", count: 64)); root["frame"] = .object(frame)
        }
        #expect(throws: (any Error).self) { _ = try DirectRichResponse.active(alteredHash, request: request("authorize_request", .authorize)) }
    }

    @Test func managementIsNotAnActiveReceiptOrCredentialRecovery() throws {
        let data = try #require(fixture()["status_response"]).canonicalData()
        let state = try DirectRichResponse.management(data, request: request("status_request", .status))
        #expect(state.state == "active")
        #expect(throws: (any Error).self) { _ = try DirectRichResponse.active(data, request: request("authorize_request", .authorize)) }
        #expect(throws: (any Error).self) { _ = try DirectRichResponse.management(data, request: request("withdraw_request", .withdraw)) }
        let withdrawn = try mutate("status_response") { $0["state"] = .string("withdrawn") }
        #expect(try DirectRichResponse.management(withdrawn, request: request("withdraw_request", .withdraw)).state == "withdrawn")
    }

    @Test func negativeConsentCannotAcceptActiveAuthorizeReply() throws {
        var intent = try #require(fixture()["authorize_request"]?.object); intent["enabled"] = .bool(false)
        let request = try DirectRichRequest(operation: .authorize, originalBody: DirectRichWireJSON.object(intent).canonicalData())
        let body = try mutate("authorize_response") { $0["request_sha256"] = .string(request.sha256) }
        #expect(throws: (any Error).self) { _ = try DirectRichResponse.active(body, request: request) }
    }

    @Test func sourceExpiryCannotExceedFrameEvenByOneFractionalDigit() throws {
        let changed = try mutate("authorize_response") { root in
            var frame = try #require(root["frame"]?.object)
            var music = try #require(frame["now_playing"]?.object)
            music["observed_at"] = .string("2026-10-31T10:00:01+00:00")
            music["expires_at"] = .string("2026-10-31T10:02:00.000001+00:00")
            frame["now_playing"] = .object(music); frame.removeValue(forKey: "frame_id")
            frame["frame_id"] = .string(try DirectRichWireJSON.object(frame).digest()); root["frame"] = .object(frame)
        }
        #expect(throws: (any Error).self) { _ = try DirectRichResponse.active(changed, request: request("authorize_request", .authorize)) }
    }

    @Test func actualNonWikipediaEmptyRevisionIsPreservedWithoutFabrication() throws {
        let changed = try mutate("authorize_response") { root in
            var frame = try #require(root["frame"]?.object)
            var story = try #require(frame["contribution"]?.object)
            var attribution = try #require(story["source_attribution"]?.object)
            attribution["provider"] = .string("MusicBrainz"); attribution["revision_url"] = .string("")
            story["source_attribution"] = .object(attribution)
            var sources = try #require(story["sources"]?.array)
            var source = try #require(sources[0].object)
            source["provider"] = .string("MusicBrainz"); source["revision_url"] = .string("")
            sources[0] = .object(source); story["sources"] = .array(sources)
            frame["contribution"] = .object(story); frame.removeValue(forKey: "frame_id")
            frame["frame_id"] = .string(try DirectRichWireJSON.object(frame).digest()); root["frame"] = .object(frame)
        }
        let value = try DirectRichResponse.active(changed, request: request("authorize_request", .authorize))
        #expect(value.frame.contribution?.sources?.first?.revision_url == "")
        #expect(value.frame.contribution?.source_attribution["revision_url"] == "")
    }
}
private final class DirectRichResponseFixtureAnchor: NSObject {}
