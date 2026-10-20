import Foundation
import CryptoKit

public struct DJConnectRendezvousEnrollmentChallenge: Sendable {
    public let identifier:String
    public let nonce:Data
    public let expiresAtMS:Int64
    private let admittedAtMS:Int64
    private let requestedUptime:TimeInterval
    private let monotonicDeadline:TimeInterval
    static func parse(_ data:Data,requestedAtMS:Int64,requestedUptime:TimeInterval,
                      nowMS:Int64 = Int64(Date().timeIntervalSince1970 * 1000),
                      uptime:TimeInterval = ProcessInfo.processInfo.systemUptime) throws -> Self {
        let fields = try RendezvousFlatJSON.parse(data,maximumBytes:4096)
        guard requestedAtMS >= 0, nowMS >= requestedAtMS, requestedUptime.isFinite, requestedUptime >= 0,
              uptime.isFinite, uptime >= requestedUptime,
              Set(fields.keys) == ["v","challenge_id","challenge","expires_at"], fields["v"] == .string("djc-rendezvous/1"),
              case let .string(id)? = fields["challenge_id"], DJConnectRendezvousQR.canonicalToken(id),
              case let .string(encoded)? = fields["challenge"], DJConnectRendezvousQR.canonicalToken(encoded),
              let nonce = Data(base64Encoded:encoded.replacingOccurrences(of:"-",with:"+").replacingOccurrences(of:"_",with:"/")+"="),
              case let .integer(expiry)? = fields["expires_at"], expiry > nowMS, expiry - requestedAtMS <= 120000 else { throw DJConnectError.invalidResponse }
        let deadline = requestedUptime + Double(expiry - requestedAtMS)/1000
        guard uptime < deadline else { throw DJConnectError.invalidResponse }
        return .init(identifier:id,nonce:nonce,expiresAtMS:expiry,admittedAtMS:nowMS,requestedUptime:requestedUptime,monotonicDeadline:deadline)
    }
    // Internal callback bound; never refreshed when an SDK wait begins.
    var originalMonotonicDeadline: TimeInterval { monotonicDeadline }
    public func isCurrent(at nowMS:Int64 = Int64(Date().timeIntervalSince1970 * 1000),
                          uptime:TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        nowMS >= admittedAtMS && nowMS < expiresAtMS && uptime.isFinite && uptime >= requestedUptime && uptime < monotonicDeadline
    }
}
