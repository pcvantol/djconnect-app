import CryptoKit
import Foundation
import Testing
@testable import DJConnectCore

@Suite struct RendezvousRecoveryChallengeTests {
    private let key = Data(repeating: 8, count: 32).base64EncodedString()
    private let token = String(repeating: "A", count: 43)
    private func b64(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    private var fields: [String: Any] {
        ["v": "djc-rendezvous/1", "action": "recover-key", "service_origin": DJConnectRendezvousQR.serviceOrigin,
         "key_id": key, "challenge_id": token, "challenge": token, "expires_at": 120000]
    }
    private func response(_ bytes: Data, expiry: Int64 = 120000) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["v": "djc-rendezvous/1", "challenge_id": token,
            "challenge": token, "expires_at": expiry, "client_data": b64(bytes)])
    }
    private func parse(_ data: Data, now: Int64 = 2000, uptime: TimeInterval = 11) throws -> DJConnectRendezvousRecoveryChallenge {
        try .parse(data, keyIdentifier: key, requestedAtMS: 1000, requestedUptime: 10, nowMS: now, uptime: uptime)
    }
    @Test func originalBytesNonceAndClocksArePreserved() throws {
        let original = Data((" \n" + String(decoding: try JSONSerialization.data(withJSONObject: fields, options: .sortedKeys), as: UTF8.self) + "\t").utf8)
        let result = try parse(response(original))
        #expect(result.originalClientData == original)
        #expect(result.clientDataHash == Data(SHA256.hash(data: original)))
        #expect(result.nonce == Data(repeating: 0, count: 32))
        #expect(result.originalMonotonicDeadline == 129)
        #expect(result.isCurrent(at: 2001, uptime: 12))
        #expect(!result.isCurrent(at: 1999, uptime: 12))
        #expect(!result.isCurrent(at: 2001, uptime: 9))
        #expect(!result.isCurrent(at: 120000, uptime: 12))
        #expect(!result.isCurrent(at: 2001, uptime: 129))
        #expect(!result.isCurrent(at: 2001, uptime: .nan))
        #expect(!result.description.contains(key))
    }
    @Test func allCapturedFieldsAndActionAreBound() throws {
        for field in fields.keys {
            var changed = fields
            changed[field] = field == "expires_at" ? 119999 : "changed"
            let bytes = try JSONSerialization.data(withJSONObject: changed)
            #expect(throws: (any Error).self) { try parse(response(bytes)) }
        }
        for action in ["submit", "register", "delete-key"] {
            var changed = fields; changed["action"] = action
            let bytes = try JSONSerialization.data(withJSONObject: changed)
            #expect(throws: (any Error).self) { try parse(response(bytes)) }
        }
    }
    @Test func malformedDuplicateAndExtraFieldsAreRejected() throws {
        let original = try JSONSerialization.data(withJSONObject: fields, options: .sortedKeys)
        let duplicate = Data(String(decoding: original, as: UTF8.self).replacingOccurrences(
            of: "\"action\":\"recover-key\"", with: "\"action\":\"recover-key\",\"act\\u0069on\":\"recover-key\"").utf8)
        #expect(throws: (any Error).self) { try parse(response(duplicate)) }
        var extra = fields; extra["transaction_id"] = "new-qr-does-not-grant-recovery"
        #expect(throws: (any Error).self) { try parse(response(JSONSerialization.data(withJSONObject: extra))) }
        var outer = try #require(JSONSerialization.jsonObject(with: response(original)) as? [String: Any])
        outer["client_data"] = b64(original) + "="
        #expect(throws: (any Error).self) { try parse(JSONSerialization.data(withJSONObject: outer)) }
        outer["client_data"] = "_x" // Non-zero unused base64 bits.
        #expect(throws: (any Error).self) { try parse(JSONSerialization.data(withJSONObject: outer)) }
        #expect(throws: (any Error).self) { try parse(Data(repeating: 0, count: 4097)) }
    }
    @Test func expiredExtendedAndRolledBackAdmissionIsRejected() throws {
        let original = try JSONSerialization.data(withJSONObject: fields)
        #expect(throws: (any Error).self) { try parse(response(original), now: 120000) }
        #expect(throws: (any Error).self) { try parse(response(original), now: 999) }
        #expect(throws: (any Error).self) { try parse(response(original), uptime: 129) }
        #expect(throws: (any Error).self) { try parse(response(original), uptime: .infinity) }
        #expect(throws: (any Error).self) { try parse(response(original), uptime: 9) }
        var extended = fields; extended["expires_at"] = 121001
        #expect(throws: (any Error).self) { try parse(response(JSONSerialization.data(withJSONObject: extended), expiry: 121001)) }
    }
}

private final class RecoveryTransportWire: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var expiry: Int64 = 0
    nonisolated(unsafe) private static var requests: [(String, Data)] = []
    static func reset(expiry: Int64) { lock.withLock { Self.expiry = expiry; requests = [] } }
    static var captured: [(String, Data)] { lock.withLock { requests } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            var body = request.httpBody ?? Data()
            if let stream = request.httpBodyStream, body.isEmpty {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 512)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    guard count >= 0, body.count + count <= 16384 else { throw URLError(.badServerResponse) }
                    if count == 0 { break }; body.append(contentsOf: buffer.prefix(count))
                }
            }
            let path = try #require(request.url?.path)
            let expiry = Self.lock.withLock { Self.requests.append((path, body)); return Self.expiry }
            #expect(request.url?.host == URL(string: DJConnectRendezvousQR.serviceOrigin)?.host)
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
            let fields = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let response: Data
            if path.hasSuffix("/attestation/challenge") {
                #expect(Set(fields.keys) == ["v", "key_id", "action"])
                #expect(fields["action"] as? String == "recover-key")
                let token = String(repeating: "A", count: 43)
                let now = Int64(Date().timeIntervalSince1970 * 1000)
                let original = try JSONSerialization.data(withJSONObject: ["v": "djc-rendezvous/1",
                    "action": "recover-key", "service_origin": DJConnectRendezvousQR.serviceOrigin,
                    "key_id": try #require(fields["key_id"]), "challenge_id": token,
                    "challenge": token, "expires_at": now + 60000], options: .sortedKeys)
                response = try JSONSerialization.data(withJSONObject: ["v": "djc-rendezvous/1",
                    "challenge_id": token, "challenge": token, "expires_at": now + 60000,
                    "client_data": submissionB64(original)])
            } else {
                #expect(path.hasSuffix("/attestation/recover"))
                response = try JSONSerialization.data(withJSONObject: ["v": "djc-rendezvous/1", "key_expires_at": expiry])
            }
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200,
                httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@Suite(.serialized) @MainActor struct RendezvousRecoveryTransportTests {
    private func service() -> DJConnectRendezvousService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecoveryTransportWire.self]
        return .init(configuration: configuration)
    }
    @Test func exactJournalBytesRecoverWithoutAnyBrowserQR() async throws {
        let expiry = submissionNow() + 20 * 86400000
        RecoveryTransportWire.reset(expiry: expiry)
        let service = service(), key = Data(repeating: 3, count: 32).base64EncodedString()
        let challenge = try await service.recoveryChallenge(keyID: key, isCurrent: { true })
        let journal = RendezvousRecoveryJournal(storage: SubmissionStore())
        let attempt = try await journal.begin(keyIdentifier: key, challengeIdentifier: challenge.identifier,
            nonce: challenge.nonce, clientData: challenge.originalClientData,
            admittedAtMS: submissionNow(), deadlineMS: challenge.expiresAtMS)
        let call = try await journal.reserveAssertion(attemptIdentifier: attempt, at: submissionNow())
        #expect(call.clientDataHash == challenge.clientDataHash)
        try await journal.completeAssertion(attemptIdentifier: attempt, reservation: call.reservation,
            result: .received(Data([1, 2, 3])), at: submissionNow()) // Synthetic, no SDK effect.
        let request = try await journal.reserveSubmission(attemptIdentifier: attempt, at: submissionNow())
        let received = try await service.recover(originalBody: request.body, challenge: challenge,
            expectedOriginalExpiryMS: expiry, isCurrent: { true })
        #expect(received == expiry)
        #expect(RecoveryTransportWire.captured.last?.1 == request.body)
        try await journal.completeSubmission(attemptIdentifier: attempt, reservation: request.reservation,
            outcome: .succeeded, at: submissionNow())
        #expect(try await journal.snapshot(at: submissionNow())?.phase == .completed)
    }
    @Test func staleOwnerMismatchedBodyAndChangedExpiryCannotBeAdopted() async throws {
        let expiry = submissionNow() + 20 * 86400000
        RecoveryTransportWire.reset(expiry: expiry)
        let service = service(), key = Data(repeating: 3, count: 32).base64EncodedString()
        var checks = 0
        await #expect(throws: (any Error).self) {
            _ = try await service.recoveryChallenge(keyID: key, isCurrent: { checks += 1; return checks < 2 })
        }
        #expect(RecoveryTransportWire.captured.isEmpty)
        let challenge = try await service.recoveryChallenge(keyID: key, isCurrent: { true })
        let valid: [String: Any] = ["v": "djc-rendezvous/1", "key_id": key,
            "challenge_id": challenge.identifier, "client_data": submissionB64(challenge.originalClientData), "assertion": "AQID"]
        let original = try JSONSerialization.data(withJSONObject: valid)
        for field in valid.keys {
            var changed = valid; changed[field] = "changed"
            let body = try JSONSerialization.data(withJSONObject: changed)
            await #expect(throws: (any Error).self) {
                _ = try await service.recover(originalBody: body, challenge: challenge,
                                              expectedOriginalExpiryMS: expiry, isCurrent: { true })
            }
        }
        #expect(RecoveryTransportWire.captured.count == 1)
        await #expect(throws: (any Error).self) {
            _ = try await service.recover(originalBody: original, challenge: challenge,
                                          expectedOriginalExpiryMS: expiry + 1, isCurrent: { true })
        }
        #expect(RecoveryTransportWire.captured.count == 2)
    }
}
