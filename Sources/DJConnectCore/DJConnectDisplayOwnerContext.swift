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
    enum CodingKeys: String, CodingKey {
        case success, contractVersion = "contract_version", sessionID = "session_id"
        case displayEntryURL = "display_entry_url", routeTrust = "route_trust", issuerEpoch = "issuer_epoch"
        case shareID = "share_id", shareGeneration = "share_generation", expiresAt = "expires_at", expiresIn = "expires_in"
    }
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
