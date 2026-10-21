import CryptoKit
import Foundation
import Testing
@testable import DJConnectCore

private final class RendezvousBuildFixtureBundle: NSObject {}

private func fixedQAContract(_ name: String) throws -> Data {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle(for: RendezvousBuildFixtureBundle.self)
    #endif
    let url = try #require(bundle.url(forResource: name, withExtension: "json") ??
                           bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Suite(.serialized)
struct RendezvousBuildProfileTests {
    @Test func fixedRendezvousBuildMatchesPinnedProducerSchemaAndStorageRealm() throws {
        let data = try fixedQAContract("rendezvous-fixed-qa-wire-3b43332")
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        #expect(digest == "24ab72719195f7971e070e56c52ceea7e67e02ee1bd7c6946eca99883194505f")
        let fixture = try #require(JSONSerialization.jsonObject(with: fixedQAContract("rendezvous-fixed-qa-api-3b43332")) as? [String: Any])
        #expect(fixture["wire_schema_sha256"] as? String == digest)
        #expect(fixture["service"] as? String == "djconnect-api-vibecast-qa")
        let schema = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let definitions = try #require(schema["$defs"] as? [String: Any])
        func constant(_ name: String, _ field: String) throws -> String {
            let definition = try #require(definitions[name] as? [String: Any])
            let properties = try #require(definition["properties"] as? [String: Any])
            let value = try #require(properties[field] as? [String: Any])
            return try #require(value["const"] as? String)
        }
        let service = try #require(fixture["service_origin"] as? String)
        let browser = try #require(fixture["browser_origin"] as? String)
        for name in ["qr_payload", "submit_client_data", "delete_client_data", "recover_client_data"] {
            #expect(try constant(name, "service_origin") == service)
        }
        #expect(try constant("plaintext", "bootstrap_origin") == browser)
        #if DJCONNECT_VIBECAST_FIXED_QA
        #expect(RendezvousBuildProfile.browserOrigin == browser)
        #expect(RendezvousBuildProfile.storageNamespace == "dev.djconnect.rendezvous.fixedqa")
        #else
        #expect(RendezvousBuildProfile.browserOrigin == "https://vibecast.tv")
        #expect(RendezvousBuildProfile.storageNamespace == "dev.djconnect.rendezvous")
        #endif
    }

    @Test func fixedRendezvousBuildAdmitsExactlySelectedOrigin() throws {
        let data = try fixedQAContract("rendezvous-fixed-qa-api-3b43332")
        #expect(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() ==
                "3d99505e746237f111866a611cf3ced950ee07668fdb81040bc7745f663b7085")
        let fixture = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(fixture["source_sha"] as? String == "3b43332bb28ed4aea228938f2d3a61796c8c3f33")
        #expect(fixture["activation_allowed"] as? Bool == false)
        #expect(fixture["current_apple_profile"] is NSNull)
        #expect(fixture["operational_admission"] is NSNull)
        let qa = try #require(fixture["service_origin"] as? String)
        #if DJCONNECT_VIBECAST_FIXED_QA
        let selected = qa
        let other = "https://api.djconnect.dev"
        #else
        let selected = "https://api.djconnect.dev"
        let other = qa
        #endif
        #expect(DJConnectRendezvousQR.serviceOrigin == selected)
        func qr(_ origin: String) throws -> String {
            String(decoding: try JSONSerialization.data(withJSONObject: [
                "type": "djc-rendezvous-qr", "v": "djc-rendezvous/1", "service_origin": origin,
                "transaction_id": "00000000-0000-4000-8000-000000000001", "generation": 1,
                "expires_at": 121000, "browser_key_thumbprint": String(repeating: "A", count: 43),
                "qr_capability": String(repeating: "A", count: 43)]), as: UTF8.self)
        }
        #expect(try DJConnectRendezvousQR.parse(qr(selected), at: 1000, uptime: 10).generation == 1)
        for invalid in [other, selected + "/", selected + "?profile=qa", selected + "#qa",
                        selected + ".evil.invalid", selected.replacingOccurrences(of: "https://", with: "http://"),
                        selected.replacingOccurrences(of: "https://", with: "https://user@"), selected + ":443"] {
            #expect(throws: (any Error).self) {
                try DJConnectRendezvousQR.parse(qr(invalid), at: 1000, uptime: 10)
            }
        }
    }

    @Test @MainActor func fixedRendezvousTransportUsesSelectedHostWithoutOwnerCredentials() async throws {
        func b64(_ bytes: Data) -> String {
            bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        }
        var modulus = Data(repeating: 0x41, count: 256); modulus[0] = 0xC1
        let n = b64(modulus)
        let thumbprint = b64(Data(SHA256.hash(data: Data("{\"e\":\"AQAB\",\"kty\":\"RSA\",\"n\":\"\(n)\"}".utf8))))
        let expiry = Int64(Date().timeIntervalSince1970 * 1000) + 120000
        let object: [String: Any] = ["type": "djc-rendezvous-qr", "v": "djc-rendezvous/1",
            "service_origin": DJConnectRendezvousQR.serviceOrigin, "transaction_id": "00000000-0000-4000-8000-000000000001",
            "generation": 1, "expires_at": expiry, "browser_key_thumbprint": thumbprint,
            "qr_capability": String(repeating: "A", count: 43)]
        let qr = try DJConnectRendezvousQR.parse(String(decoding: JSONSerialization.data(withJSONObject: object), as: UTF8.self))
        let response = try JSONSerialization.data(withJSONObject: ["v": "djc-rendezvous/1", "transaction_id": qr.transactionID,
            "browser_public_key": ["kty": "RSA", "n": n, "e": "AQAB"], "browser_key_thumbprint": thumbprint,
            "generation": 1, "expires_at": expiry])
        FixedOriginWire.install(response)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixedOriginWire.self]
        let result = try await DJConnectRendezvousService(configuration: configuration).inspect(qr)
        #expect(result.thumbprint == thumbprint)
        let request = try #require(FixedOriginWire.request)
        #expect(request.url?.absoluteString == DJConnectRendezvousQR.serviceOrigin + "/v1/rendezvous/inspect")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
        let bodyData = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        #expect(Set(body.keys) == ["v", "transaction_id", "generation", "qr_capability"])
    }

    @Test func fixedRendezvousRecoveryRejectsOtherEnvironmentBeforePersisting() async throws {
        let store = FixedOriginStore(), journal = RendezvousRecoveryJournal(storage: store)
        let key = Data(repeating: 7, count: 32).base64EncodedString()
        let token = String(repeating: "A", count: 43), nonce = Data(repeating: 0, count: 32)
        let other = DJConnectRendezvousQR.serviceOrigin == "https://api.djconnect.dev"
            ? "https://api-vibecast-qa.djconnect.dev" : "https://api.djconnect.dev"
        func bytes(_ origin: String) throws -> Data {
            try JSONSerialization.data(withJSONObject: ["v": "djc-rendezvous/1", "action": "recover-key",
                "service_origin": origin, "key_id": key, "challenge_id": token, "challenge": token, "expires_at": 120000])
        }
        await #expect(throws: (any Error).self) {
            try await journal.begin(keyIdentifier: key, challengeIdentifier: token, nonce: nonce,
                                    clientData: bytes(other), admittedAtMS: 0, deadlineMS: 120000)
        }
        #expect(store.writes == 0)
        let original = try bytes(DJConnectRendezvousQR.serviceOrigin)
        let id = try await journal.begin(keyIdentifier: key, challengeIdentifier: token, nonce: nonce,
                                         clientData: original, admittedAtMS: 0, deadlineMS: 120000)
        let call = try await journal.reserveAssertion(attemptIdentifier: id, at: 1)
        #expect(call.clientDataHash == Data(SHA256.hash(data: original)))
    }
}

private final class FixedOriginStore: RendezvousRepairStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var bytes: Data?
    private var count = 0
    var writes: Int { lock.withLock { count } }
    func read() throws -> Data? { lock.withLock { bytes } }
    func write(_ data: Data) throws { lock.withLock { bytes = data; count += 1 } }
}

private final class FixedOriginWire: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var response = Data()
    nonisolated(unsafe) private static var captured: URLRequest?
    static var request: URLRequest? { lock.withLock { captured } }
    static func install(_ data: Data) { lock.withLock { response = data; captured = nil } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var capturedRequest = request
        // URLSession can expose a POST body as a stream to URLProtocol.
        if capturedRequest.httpBody == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var bytes = Data(), buffer = [UInt8](repeating: 0, count: 512)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count >= 0, bytes.count + count <= 1024 else {
                    client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                    return
                }
                if count == 0 { break }
                bytes.append(contentsOf: buffer.prefix(count))
            }
            capturedRequest.httpBodyStream = nil
            capturedRequest.httpBody = bytes
        }
        let data = Self.lock.withLock { Self.captured = capturedRequest; return Self.response }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
