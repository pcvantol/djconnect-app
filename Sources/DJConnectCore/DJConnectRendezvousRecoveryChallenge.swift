import CryptoKit
import Foundation

/// Action-separated management challenge. Recovery does not inherit a new QR's
/// lifetime: the original request clocks and exact server bytes remain binding.
/// Parsing this object grants no repair budget, SDK call or key activation.
public struct DJConnectRendezvousRecoveryChallenge: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let identifier: String
    public let keyIdentifier: String
    public let nonce: Data
    public let originalClientData: Data
    public let clientDataHash: Data
    public let expiresAtMS: Int64
    private let admittedAtMS: Int64
    private let requestedUptime: TimeInterval
    let originalMonotonicDeadline: TimeInterval
    public var description: String { "RendezvousRecoveryChallenge(redacted)" }
    public var debugDescription: String { description }

    static func parse(_ data: Data, keyIdentifier: String, requestedAtMS: Int64,
                      requestedUptime: TimeInterval,
                      nowMS: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
                      uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) throws -> Self {
        guard DJConnectRendezvousSubmitChallenge.canonicalKeyID(keyIdentifier),
              requestedAtMS >= 0, nowMS >= requestedAtMS,
              requestedUptime.isFinite, requestedUptime >= 0,
              uptime.isFinite, uptime >= requestedUptime else { throw DJConnectError.invalidResponse }
        let fields = try RendezvousFlatJSON.parse(data, maximumBytes: 4096)
        guard Set(fields.keys) == ["v", "challenge_id", "challenge", "expires_at", "client_data"],
              fields["v"] == .string("djc-rendezvous/1"),
              case let .string(id)? = fields["challenge_id"], DJConnectRendezvousQR.canonicalToken(id),
              case let .string(challenge)? = fields["challenge"], DJConnectRendezvousQR.canonicalToken(challenge),
              let nonce = decode(challenge), nonce.count == 32,
              case let .integer(expiry)? = fields["expires_at"],
              expiry > nowMS, expiry <= 9_007_199_254_740_991, expiry - requestedAtMS <= 120_000,
              case let .string(encoded)? = fields["client_data"], encoded.utf8.count <= 2731,
              let original = decode(encoded), original.count <= 2048 else { throw DJConnectError.invalidResponse }
        let expected: [String: RendezvousFlatJSON.Value] = [
            "v": .string("djc-rendezvous/1"), "action": .string("recover-key"),
            "service_origin": .string(DJConnectRendezvousQR.serviceOrigin),
            "key_id": .string(keyIdentifier), "challenge_id": .string(id),
            "challenge": .string(challenge), "expires_at": .integer(expiry)
        ]
        guard try RendezvousFlatJSON.parse(original, maximumBytes: 2048) == expected else { throw DJConnectError.invalidResponse }
        let deadline = requestedUptime + Double(expiry - requestedAtMS) / 1000
        guard deadline.isFinite, uptime < deadline else { throw DJConnectError.invalidResponse }
        return .init(identifier: id, keyIdentifier: keyIdentifier, nonce: nonce,
                     originalClientData: original, clientDataHash: Data(SHA256.hash(data: original)),
                     expiresAtMS: expiry, admittedAtMS: nowMS, requestedUptime: requestedUptime,
                     originalMonotonicDeadline: deadline)
    }

    public func isCurrent(at nowMS: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
                          uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        nowMS >= admittedAtMS && nowMS < expiresAtMS && uptime.isFinite
            && uptime >= requestedUptime && uptime < originalMonotonicDeadline
    }

    private static func decode(_ encoded: String) -> Data? {
        guard !encoded.isEmpty, encoded.utf8.allSatisfy({
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        }) else { return nil }
        let text = encoded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: text + String(repeating: "=", count: (4 - text.count % 4) % 4)),
              data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") == encoded else { return nil }
        return data
    }
}
