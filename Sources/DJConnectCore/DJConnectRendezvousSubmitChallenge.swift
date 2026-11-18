import Foundation
import CryptoKit

/// Exact server-saved bytes, validated against the independently captured QR,
/// app-key address and already-encrypted destination. Never reserialize to sign.
public struct DJConnectRendezvousSubmitChallenge: Sendable {
    public let identifier: String
    public let originalClientData: String
    public let clientDataHash: Data
    public let expiresAtMS: Int64
    private let admittedAtMS: Int64
    private let requestedUptime: TimeInterval
    private let monotonicDeadline: TimeInterval
    var originalMonotonicDeadline: TimeInterval { monotonicDeadline }
    public static func parse(_ data: Data, qr: DJConnectRendezvousQR, keyID: String, envelopeDigest: String,
                             requestedAtMS: Int64, requestedUptime: TimeInterval,
                             nowMS: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
                             uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) throws -> Self {
        guard canonicalKeyID(keyID), DJConnectRendezvousQR.canonicalToken(envelopeDigest),
              qr.isCurrent(at:nowMS,uptime:uptime), requestedAtMS >= 0, nowMS >= requestedAtMS,
              requestedUptime.isFinite, requestedUptime >= 0, uptime.isFinite, uptime >= requestedUptime else { throw DJConnectError.invalidResponse }
        let fields = try RendezvousFlatJSON.parse(data,maximumBytes:4096)
        guard Set(fields.keys) == ["v","challenge_id","challenge","expires_at","client_data"],
              fields["v"] == .string("djc-rendezvous/1"),
              case let .string(id)? = fields["challenge_id"], DJConnectRendezvousQR.canonicalToken(id),
              case let .string(nonce)? = fields["challenge"], DJConnectRendezvousQR.canonicalToken(nonce),
              case let .integer(expiry)? = fields["expires_at"], expiry > nowMS, expiry <= qr.expiresAtMS,
              expiry - requestedAtMS <= 120000,
              case let .string(encoded)? = fields["client_data"], encoded.count <= 2731,
              !encoded.isEmpty, encoded.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }),
              let original = decode(encoded), original.count <= 2048, encode(original) == encoded else { throw DJConnectError.invalidResponse }
        let expected: [String:RendezvousFlatJSON.Value] = ["v":.string("djc-rendezvous/1"),"action":.string("submit"),
            "service_origin":.string(DJConnectRendezvousQR.serviceOrigin),"transaction_id":.string(qr.transactionID),
            "generation":.integer(qr.generation),"browser_key_thumbprint":.string(qr.browserKeyThumbprint),
            "expires_at":.integer(expiry),"key_id":.string(keyID),"challenge_id":.string(id),
            "challenge":.string(nonce),"envelope_digest":.string(envelopeDigest)]
        guard try RendezvousFlatJSON.parse(original,maximumBytes:2048) == expected else { throw DJConnectError.invalidResponse }
        let deadline = requestedUptime + Double(expiry - requestedAtMS)/1000
        guard uptime < deadline else { throw DJConnectError.invalidResponse }
        return .init(identifier:id,originalClientData:encoded,clientDataHash:Data(SHA256.hash(data:original)),
            expiresAtMS:expiry,admittedAtMS:nowMS,requestedUptime:requestedUptime,monotonicDeadline:deadline)
    }
    public func isCurrent(at nowMS: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
                          uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        nowMS >= admittedAtMS && nowMS < expiresAtMS && uptime.isFinite && uptime >= requestedUptime && uptime < monotonicDeadline
    }
    public static func canonicalKeyID(_ value: String) -> Bool {
        guard value.utf8.count == 44, let bytes = Data(base64Encoded:value), bytes.count == 32 else { return false }
        return bytes.base64EncodedString() == value
    }
    private static func decode(_ value: String) -> Data? {
        Data(base64Encoded:value.replacingOccurrences(of:"-",with:"+").replacingOccurrences(of:"_",with:"/") + String(repeating:"=",count:(4-value.count%4)%4))
    }
    private static func encode(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")
    }
}
