import Foundation

/// A destination supplied only by a current authenticated selected-HA response.
/// This is routing information, never display/Session consent or a bearer grant.
public struct DJConnectDisplayOwnerContext: Decodable, Equatable, Sendable {
    public let success: Bool
    public let contractVersion: Int
    public let sessionID: String?
    public let displayEntryURL: String
    public let routeTrust: String
    public let issuerEpoch: String
    public let shareID: String?
    public let shareGeneration: Int?
    public let expiresAt: String?
    public let expiresIn: Double?
    private let liveDisplayStatus: LiveDisplays?
    enum CodingKeys: String, CodingKey {
        case success, contractVersion = "contract_version", sessionID = "session_id"
        case displayEntryURL = "display_entry_url", routeTrust = "route_trust", issuerEpoch = "issuer_epoch"
        case shareID = "share_id", shareGeneration = "share_generation", expiresAt = "expires_at", expiresIn = "expires_in"
        case liveDisplayStatus = "live_display_status"
    }
    public struct Display: Decodable, Equatable, Sendable, Identifiable {
        public let id: String
        public let shareID: String
        public let connectionGeneration: Int64
        enum CodingKeys: String, CodingKey {
            case id = "display_id", shareID = "share_id", connectionGeneration = "connection_generation"
        }
    }

    public struct DisplayObservation: Equatable, Sendable {
        public let sessionID: String
        public let issuerEpoch: String
        public let revision: Int64
        public let displays: [Display]
        public let screenSlot: ScreenSlot?
    }

    public struct ScreenSlot: Decodable, Equatable, Sendable {
        public enum State: String, Decodable, Sendable { case available, reserved, live, unavailable }
        let version: Int
        public let state: State
        public let display: Display?

        func qualifies(liveDisplays: [Display]) -> Bool {
            guard version == 1 else { return false }
            switch state {
            case .available, .unavailable:
                return display == nil && liveDisplays.isEmpty
            case .live:
                return liveDisplays.count == 1 && display == liveDisplays.first
            case .reserved:
                guard let display else { return false }
                return liveDisplays.isEmpty && DJConnectRendezvousQR.canonicalToken(display.id) &&
                    DJConnectRendezvousQR.canonicalToken(display.shareID) &&
                    (0...9_007_199_254_740_991).contains(display.connectionGeneration)
            }
        }
    }

    private struct LiveDisplays: Decodable, Equatable, Sendable {
        let version: Int
        let observationRevision: Int64
        let displays: [Display]
        let screenSlot: ScreenSlot?
        enum CodingKeys: String, CodingKey {
            case version, observationRevision = "observation_revision", displays, screenSlot = "screen_slot"
        }
    }

    /// An absent or unsupported observation is unknown, including on older HA installations.
    public var displayObservation: DisplayObservation? {
        guard isAdmissible, let sessionID, !sessionID.isEmpty,
              let status = liveDisplayStatus, status.version == 1,
              (1...9_007_199_254_740_991).contains(status.observationRevision),
              status.displays.count <= 64,
              Set(status.displays.map(\.id)).count == status.displays.count,
              status.displays.allSatisfy({
                  DJConnectRendezvousQR.canonicalToken($0.id) &&
                  DJConnectRendezvousQR.canonicalToken($0.shareID) &&
                  (1...9_007_199_254_740_991).contains($0.connectionGeneration)
              }) else { return nil }
        return DisplayObservation(sessionID: sessionID, issuerEpoch: issuerEpoch,
            revision: status.observationRevision, displays: status.displays,
            screenSlot: status.screenSlot.flatMap { $0.qualifies(liveDisplays: status.displays) ? $0 : nil })
    }

    public var advertisesDisplayStatus: Bool { liveDisplayStatus != nil }

    public var isAdmissible: Bool {
        guard success, contractVersion == 1, routeTrust == "paired_owner_response",
              DJConnectRendezvousQR.canonicalToken(issuerEpoch),
              displayEntryURL.utf8.allSatisfy({ $0 < 128 }),
              let parts = URLComponents(string: displayEntryURL),
              parts.scheme == "https", parts.port == nil, parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil,
              parts.percentEncodedPath == "/djconnect/vibecast/display",
              let host = parts.host, host == host.lowercased(), host.contains("."),
              !host.hasSuffix(".local"), !host.hasSuffix(".localhost"), !host.hasSuffix(".internal"),
              !host.contains(":"), !host.hasPrefix("xn--"), !host.contains(".xn--"),
              !host.utf8.allSatisfy({ (48...57).contains($0) || $0 == 46 }),
              host.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({ label in
                  !label.isEmpty && label.count <= 63 && label.first != "-" && label.last != "-" &&
                  label.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 })
              }),
              parts.url?.absoluteString == displayEntryURL else { return false }
        return true
    }
}
