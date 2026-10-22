import Foundation

/// Closed current-recording selection. Display metadata is never recording authority.
public struct DJConnectCurrentInsightSelection: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let mode: String
    public init() { schemaVersion = 1; mode = "current" }
    public var isValid: Bool { schemaVersion == 1 && mode == "current" }
    enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version", mode }
}

/// Ephemeral proof from the owner endpoint. Never put this observation in history or widgets.
public struct DJConnectCurrentInsightSubject: Decodable, Equatable, Sendable {
    public let schemaVersion: Int
    public let mode: String
    public let mediaIdentity: String
    public let observationID: String
    public let expiresIn: Double
    public let expiresAt: Double
    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version", mode, mediaIdentity = "media_identity"
        case observationID = "observation_id", expiresIn = "expires_in", expiresAt = "expires_at"
    }
    public static func isRecordingURI(_ raw: String?) -> Bool {
        guard let raw else { return false }
        let parts = raw.split(separator: ":", omittingEmptySubsequences: false)
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".utf8)
        return parts.count == 3 && parts[0] == "spotify" && parts[1] == "track"
            && parts[2].utf8.count == 22 && parts[2].utf8.allSatisfy { allowed.contains($0) }
    }
    /// Request start anchors the relative budget conservatively; rereading cannot renew it.
    public func deadline(recording: String, requestedAt: Date, at now: Date) -> Date? {
        guard schemaVersion == 1, mode == "current", Self.isRecordingURI(recording), mediaIdentity == recording,
              !observationID.isEmpty, observationID.utf8.count <= 512,
              expiresIn.isFinite, expiresIn > 0, expiresIn <= 30,
              expiresAt.isFinite, requestedAt <= now else { return nil }
        let original = min(requestedAt.addingTimeInterval(expiresIn), Date(timeIntervalSince1970: expiresAt))
        return original > now ? original : nil
    }
}

public struct DJConnectCurrentInsightDetail: Sendable {
    public let insight: TrackInsight
    public let subject: DJConnectCurrentInsightSubject
}

/// Additive capability read does not depend on the separate Ask DJ catalogue schema.
struct DJConnectCurrentInsightCapabilities: Decodable {
    let success: Bool?
    let capabilities: [String: Bool]?
    let versions: [String: Int]?
    var available: Bool {
        success != false && capabilities?["current_track_insight_subject_v1"] == true
            && versions?["current_track_insight_subject"] == 1
    }
    enum CodingKeys: String, CodingKey { case success, capabilities, versions = "contract_versions" }
}
