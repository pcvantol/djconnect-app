import Foundation
import Testing
@testable import DJConnectCore

@Suite struct CoreHostWakeProxyReplyDataTests {
    private struct Vector: Decodable { let route: String; let request: DirectRichWireJSON; let reply: DirectRichWireJSON }
    private struct Packet: Decodable { let positive_shape_vectors: [Vector] }
    private func vectors() throws -> [Vector] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: CoreProxyReplyAnchor.self)
        #endif
        let url = try #require(bundle.url(forResource: "host-wake-core-proxy-reply-v5", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "host-wake-core-proxy-reply-v5", withExtension: "json"))
        return try JSONDecoder().decode(Packet.self, from: Data(contentsOf: url)).positive_shape_vectors
    }
    private func request(_ v: Vector) throws -> CoreHostWakeProxyRequest {
        try .init(operation: #require(CoreHostWakeProxyRequest.Operation(rawValue: v.route)), originalBody: v.request.canonicalData())
    }
    private func prepared() throws -> CoreHostWakeProxyReplyData {
        let v = try #require(vectors().first { $0.route == "prepare" })
        return try .decode(v.reply.canonicalData(), status: 200, request: request(v))
    }
    @Test func sevenClosedCoreRepliesCorrelateWithoutProvidingNativePermission() throws {
        let values = try vectors(), original = try prepared(); #expect(values.count == 7)
        for v in values {
            let request = try request(v)
            let value = try CoreHostWakeProxyReplyData.decode(v.reply.canonicalData(), status: 200, request: request,
                prepared: request.operation == .prepare ? nil : original)
            #expect(value.state == v.reply.object?["state"]?.string)
            #expect(value.operation == request.operation)
            if request.operation == .nativeChallenge {
                let transcript = try #require(value.transcript)
                #expect(value.proofKind == original.proofKind)
                try transcript.compareData(originalCanonicalBytes: #require(original.original).canonicalData(), nativeToken: Data(0..<32),
                    advertisedHash: #require(v.reply.object?["client_data_sha256"]?.string))
            }
            var fields = try #require(v.reply.object); fields["extra"] = .bool(true)
            #expect(throws: (any Error).self) { _ = try CoreHostWakeProxyReplyData.decode(DirectRichWireJSON.object(fields).canonicalData(), status: 200, request: request, prepared: original) }
            fields.removeValue(forKey: "extra"); fields.removeValue(forKey: "request_sha256")
            #expect(throws: (any Error).self) { _ = try CoreHostWakeProxyReplyData.decode(DirectRichWireJSON.object(fields).canonicalData(), status: 200, request: request, prepared: original) }
        }
    }

    @Test(arguments: ["native/complete", "native/status", "register", "status", "withdraw", "native/challenge"])
    func registeredAndNativeVerifiedAreNotInterchangeable(_ route: String) throws {
        let v = try #require(vectors().first { $0.route == route }), request = try request(v), original = try prepared()
        var fields = try #require(v.reply.object)
        fields["state"] = .string(["register", "status"].contains(route) ? "native_verified" : "registered")
        #expect(throws: (any Error).self) { _ = try CoreHostWakeProxyReplyData.decode(DirectRichWireJSON.object(fields).canonicalData(), status: 200, request: request, prepared: original) }
        if route == "withdraw" {
            fields["state"] = .string("native_verified")
            #expect(throws: (any Error).self) { _ = try CoreHostWakeProxyReplyData.decode(DirectRichWireJSON.object(fields).canonicalData(), status: 200, request: request, prepared: original) }
        }
    }

    @Test(arguments: ["proofKind", "hash", "transcript", "purpose", "generation", "revision", "expiry", "requestHash"])
    func challengeCannotReplacePreparedTupleOrSigningBytes(_ variant: String) throws {
        let v = try #require(vectors().first { $0.route == "native/challenge" }), request = try request(v), original = try prepared()
        var fields = try #require(v.reply.object)
        switch variant {
        case "proofKind": fields["native_proof_kind"] = .string(original.proofKind == "app_attest_attestation" ? "app_attest_assertion" : "app_attest_attestation")
        case "hash": fields["client_data_sha256"] = .string(String(repeating: "0", count: 64))
        case "transcript": fields["canonical_transcript_utf8"] = .string(" " + (fields["canonical_transcript_utf8"]?.string ?? ""))
        case "purpose": fields["purpose_id"] = .string("33333333-3333-4333-8333-333333333333")
        case "generation": fields["generation"] = .string("another-generation")
        case "revision": fields["revision"] = .integer(2)
        case "expiry": fields["original_wake_expires_at_ms"] = .integer(1800003599999)
        default: fields["request_sha256"] = .string(try #require(vectors().first { $0.route == "status" }) .reply.object!["request_sha256"]!.string!)
        }
        #expect(throws: (any Error).self) { _ = try CoreHostWakeProxyReplyData.decode(DirectRichWireJSON.object(fields).canonicalData(), status: 200, request: request, prepared: original) }
        #expect(throws: (any Error).self) { _ = try CoreHostWakeProxyReplyData.decode(v.reply.canonicalData(), status: 200, request: request) }
    }

    @Test func errorsStayFixedAndCannotInstructParentUnpairOrExposePrivateData() throws {
        let v = try #require(vectors().first { $0.route == "status" }), request = try request(v)
        for error in CoreHostWakeProxyServerError.allCases {
            let fields: [String: DirectRichWireJSON] = ["success": .bool(false), "contract_version": .integer(1), "error": .string(error.rawValue)]
            let bytes = try DirectRichWireJSON.object(fields).canonicalData()
            do { _ = try CoreHostWakeProxyReplyData.decode(bytes, status: error.status, request: request); Issue.record("Error returned positive DATA") }
            catch let actual as CoreHostWakeProxyServerError { #expect(actual == error) }
            #expect(throws: (any Error).self) { _ = try CoreHostWakeProxyReplyData.decode(bytes, status: 200, request: request) }
            var privateData = fields; privateData["message"] = .string("private detail")
            #expect(throws: (any Error).self) { _ = try CoreHostWakeProxyServerError.decode(.object(privateData), status: error.status) }
        }
    }

    @Test func newRouteRejectsLexicalMinusZeroWhilePreservingStringsAndOldWire() throws {
        let zero = Data(#"{"x":0,"s":"escaped\"-0/label"}"#.utf8)
        _ = try CoreHostWakeProxyDataJSON.parse(zero)
        let negative = Data(#"{"x":-0,"s":"escaped\"-0/label"}"#.utf8)
        #expect(throws: (any Error).self) { _ = try CoreHostWakeProxyDataJSON.parse(negative) }
        _ = try DirectRichWireJSON.parse(negative, maximumBytes: 16384) // No silent legacy grammar change.
        for raw in [#"{"x":1.0}"#, #"{"x":1e0}"#, #"{"x":9007199254740992}"#, #"{"x":1,"\u0078":1}"#] {
            #expect(throws: (any Error).self) { _ = try CoreHostWakeProxyDataJSON.parse(Data(raw.utf8)) }
        }
    }
}
private final class CoreProxyReplyAnchor: NSObject {}
