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
