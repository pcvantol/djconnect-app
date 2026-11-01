import Foundation
import Testing
@testable import DJConnectCore

@Suite struct DirectRichWireTests {
    @Test func originalCoreOperationVectors() throws {
        struct Packet: Decodable { let vectors: [Vector] }
        struct Vector: Decodable {
            let id: String; let kind: String; let raw_utf8: String
            let expected: String; let canonical_sha256: String?
        }
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: DirectRichFixtureAnchor.self)
        #endif
        let url = try #require(bundle.url(forResource: "direct-rich-request-core-r8", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "direct-rich-request-core-r8", withExtension: "json"))
        let packet = try JSONDecoder().decode(Packet.self, from: Data(contentsOf: url))
        #expect(packet.vectors.count == 13)
        for vector in packet.vectors {
            let decode = { () throws -> DirectRichRequest in
                guard let operation = DirectRichRequest.Operation(rawValue: vector.kind) else { throw DJConnectError.invalidResponse }
                return try DirectRichRequest(operation: operation, originalBody: Data(vector.raw_utf8.utf8))
            }
            if vector.expected == "ACCEPT_INTENTION_ONLY" {
                let request = try decode()
                #expect(request.sha256 == vector.canonical_sha256, Comment(rawValue: vector.id))
                #expect(request.body == Data(vector.raw_utf8.utf8))
            } else {
                #expect(throws: (any Error).self) { _ = try decode() }
            }
        }
    }

    @Test(arguments: ["1.0", "1e0", "true", "9007199254740992", "-9007199254740992"])
    func lexicalVersionsAreNeverCoerced(_ version: String) {
        let raw = "{\"contract_version\":\(version),\"purpose_id\":\"63506d46-eeaf-409c-8d82-e6d01cc9e2fb\"}"
        #expect(throws: (any Error).self) { _ = try DirectRichRequest(operation: .read, originalBody: Data(raw.utf8)) }
    }

    @Test func rawPreflightPrecedesNormalizedDictionary() {
        for raw in [#"{"x":1,"\u0078":2}"#, #"{"x":{"y":1,"y":2}}"#,
                    #"{"x":"\ud800"}"#, #"{"é":1}"#, #"{"x":1}{}"#,
                    "{\"x\":" + String(repeating: "[", count: 8) + "0" + String(repeating: "]", count: 8) + "}"] {
            #expect(throws: (any Error).self) { _ = try DirectRichWireJSON.parse(Data(raw.utf8), maximumBytes: 16384) }
        }
        #expect(throws: (any Error).self) { _ = try DirectRichWireJSON.parse(Data([123, 34, 120, 34, 58, 34, 255, 34, 125]), maximumBytes: 16384) }
        #expect(throws: (any Error).self) { _ = try DirectRichWireJSON.parse(Data("{}".utf8), maximumBytes: 1) }
    }

    @Test func canonicalBytesPreserveOriginalUnicodeAndPythonEscapes() throws {
        let original = #"{"z":"e\u0301/🎵\u2028","a":"\b\t\n\f\r\u0000\u001f\"\\"}"#
        let value = try DirectRichWireJSON.parse(Data(original.utf8), maximumBytes: 16384)
        let canonical = try value.canonicalData()
        let expected = "{\"a\":\"\\b\\t\\n\\f\\r\\u0000\\u001f\\\"\\\\\",\"z\":\"e\u{301}/🎵\u{2028}\"}"
        #expect(canonical == Data(expected.utf8))
        let nfc = DirectRichWireJSON.object(["z": .string("é/🎵\u{2028}"), "a": .string("\u{8}\t\n\u{c}\r\u{0}\u{1f}\"\\")])
        #expect(try canonical != nfc.canonicalData())
    }

    @Test func exactOperationSelectionAndIdentityAreMandatory() throws {
        let read = Data(#"{"contract_version":1,"purpose_id":"63506d46-eeaf-409c-8d82-e6d01cc9e2fb"}"#.utf8)
        for operation in DirectRichRequest.Operation.allCases where operation != .read {
            #expect(throws: (any Error).self) { _ = try DirectRichRequest(operation: operation, originalBody: read) }
        }
        let raw = #"{"contract_version":1,"operation_id":"4cf66d62-d59f-4093-9e39-4c101ee0351b","device_id":"djconnect-ios-ABCDEF012345","client_type":"macos","session_id":"s","surface":"widget"}"#
        #expect(throws: (any Error).self) { _ = try DirectRichRequest(operation: .status, originalBody: Data(raw.utf8)) }
    }

    @Test func errorsAreClosedAndStatusBoundWithoutUnpairFallback() throws {
        for error in DirectRichServerError.allCases {
            let body = Data("{\"success\":false,\"contract_version\":1,\"error\":\"\(error.rawValue)\"}".utf8)
            #expect(try DirectRichServerError.decode(body, status: error.status) == error)
            #expect(throws: (any Error).self) { _ = try DirectRichServerError.decode(body, status: 200) }
            let extra = Data("{\"success\":false,\"contract_version\":1,\"error\":\"\(error.rawValue)\",\"message\":\"private\"}".utf8)
            #expect(throws: (any Error).self) { _ = try DirectRichServerError.decode(extra, status: error.status) }
        }
    }
}
private final class DirectRichFixtureAnchor: NSObject {}
