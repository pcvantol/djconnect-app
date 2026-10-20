import Foundation

/// A resolved Core B claim is lookup information only. It never approves a
/// display, starts a Session, or carries the browser's collection secret.
public struct DJConnectDisplayClaim: Sendable {
    public let claimID: String
    public let browserGeneration: String
    public let issuerEpoch: String
    public let expiresAt: Date
    private let code: String
    private let admittedAt: Date
    private let requestedUptime: TimeInterval
    private let monotonicDeadline: TimeInterval

    private struct Wire: Decodable {
        let success: Bool
        let contract_version: Int
        let claim_id: String
        let browser_generation: String
        let issuer_epoch: String
        let expires_in: Double
        let expires_at: String
    }

    // Only the paired transport may construct a resolved claim. Capture request
    // clocks before I/O; parsing or displaying a lookup must not restart120s.
    static func parse(_ data: Data, code: String, expectedIssuerEpoch: String,
                      requestedAt: Date, requestedUptime: TimeInterval,
                      now: Date, uptime: TimeInterval) throws -> Self {
        guard data.count <= 4096, code.utf8.count == 6,
              code.utf8.allSatisfy({ (48...57).contains($0) }),
              requestedAt.timeIntervalSince1970.isFinite, now.timeIntervalSince1970.isFinite,
              requestedUptime.isFinite, requestedUptime >= 0, uptime.isFinite, uptime >= requestedUptime,
              now >= requestedAt else { throw DJConnectError.invalidResponse }
        let wire = try JSONDecoder().decode(Wire.self, from: data)
        guard wire.success, wire.contract_version == 1,
              DJConnectRendezvousQR.canonicalToken(wire.claim_id),
              DJConnectRendezvousQR.canonicalToken(wire.browser_generation),
              DJConnectRendezvousQR.canonicalToken(wire.issuer_epoch),
              wire.issuer_epoch == expectedIssuerEpoch,
              wire.expires_in.isFinite, wire.expires_in > 0, wire.expires_in <= 120,
              let expiry = displayWireDate(wire.expires_at), expiry > now,
              expiry.timeIntervalSince(requestedAt) <= 120 else { throw DJConnectError.invalidResponse }
        let deadline = requestedUptime + min(wire.expires_in, expiry.timeIntervalSince(requestedAt))
        guard deadline.isFinite, uptime < deadline else { throw DJConnectError.invalidResponse }
        return Self(claimID: wire.claim_id, browserGeneration: wire.browser_generation,
                    issuerEpoch: wire.issuer_epoch, expiresAt: expiry, code: code, admittedAt: now,
                    requestedUptime: requestedUptime, monotonicDeadline: deadline)
    }

    public func isCurrent(now: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        now.timeIntervalSince1970.isFinite && now >= admittedAt && now < expiresAt &&
        uptime.isFinite && uptime >= requestedUptime && uptime < monotonicDeadline
    }

    public enum Share: Sendable {
        /// The caller must obtain an explicit user confirmation for this choice.
        case createTwoHours
        /// Existing-share mode never renews or extends that share's deadline.
        case existing(id: String, generation: Int)
    }

    // Source-only request construction. The future transport must independently
    // re-read the selected installation/owner/currentSession and recheck the UI
    // consent, token, epoch and this original deadline at synchronous dispatch.
    // Constructing bytes grants no dispatch authority and permits no auto-replay.
    func approvalBody(identity: DJConnectIdentity, sessionID: String, currentIssuerEpoch: String,
                      share: Share, now: Date, uptime: TimeInterval) throws -> Data {
        guard isCurrent(now: now, uptime: uptime), currentIssuerEpoch == issuerEpoch,
              identity.clientType == .ios, !identity.deviceID.isEmpty, identity.deviceID.utf8.count <= 128,
              identity.deviceID.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
              identity.deviceID == identity.deviceID.trimmingCharacters(in: .whitespacesAndNewlines),
              !sessionID.isEmpty, sessionID.utf8.count <= 128,
              sessionID.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
              sessionID == sessionID.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw DJConnectError.invalidResponse
        }
        let choice: [String: Any]
        switch share {
        case .createTwoHours:
            choice = ["mode": "create", "consent": true, "lifetime_seconds": 7200]
        case let .existing(id, generation):
            guard DJConnectRendezvousQR.canonicalToken(id), generation > 0 else { throw DJConnectError.invalidResponse }
            choice = ["mode": "existing", "share_id": id, "share_generation": generation]
        }
        return try JSONSerialization.data(withJSONObject: [
            "contract_version": 1, "identity": ["device_id": identity.deviceID, "client_type": "ios"],
            "session_id": sessionID, "issuer_epoch": issuerEpoch, "claim_id": claimID,
            "browser_generation": browserGeneration, "code": code, "share": choice
        ], options: [.sortedKeys])
    }
}

// Core's datetime.isoformat can omit the fraction when microseconds are zero.
func displayWireDate(_ text: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let value = formatter.date(from: text) { return value }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: text)
}
