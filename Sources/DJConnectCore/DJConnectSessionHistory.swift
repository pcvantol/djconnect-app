import Foundation

/// Temporary owner projections from Core's versioned history contract.
/// These models grant no local archival storage or playback authority.
public struct DJConnectHistoryRevision: Codable, Equatable, Sendable {
    public let value: String
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let text = try? c.decode(String.self) { value = text }
        else { value = String(try c.decode(Int.self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer(); try c.encode(value)
    }
}

public struct DJConnectSessionEntryReference: Codable, Equatable, Sendable {
    public var sessionID: String
    public var entryID: String
    public init(sessionID: String, entryID: String) { self.sessionID = sessionID; self.entryID = entryID }
    enum CodingKeys: String, CodingKey { case sessionID = "session_id", entryID = "entry_id" }
}

public struct DJConnectConversationContext: Codable, Equatable, Sendable {
    public var sessionID: String?
    public var selectedEntry: DJConnectSessionEntryReference?
    public init(sessionID: String?, selectedEntry: DJConnectSessionEntryReference? = nil) {
        self.sessionID = sessionID; self.selectedEntry = selectedEntry
    }
    enum CodingKeys: String, CodingKey { case sessionID = "session_id", selectedEntry = "selected_entry" }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let sessionID { try c.encode(sessionID, forKey: .sessionID) }
        else { try c.encodeNil(forKey: .sessionID) }
        try c.encodeIfPresent(selectedEntry, forKey: .selectedEntry)
    }
}

public struct DJConnectSessionOpenAction: Codable, Equatable, Sendable {
    public let kind: String
    public let sessionID: String
    public let entryID: String
    public let navigationOnly: Bool
    public init(reference: DJConnectSessionEntryReference) {
        kind = "open_session"; sessionID = reference.sessionID; entryID = reference.entryID; navigationOnly = true
    }
    enum CodingKeys: String, CodingKey {
        case kind, sessionID = "session_id", entryID = "entry_id", navigationOnly = "navigation_only"
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(String.self, forKey: .kind)
        sessionID = try c.decode(String.self, forKey: .sessionID)
        entryID = try c.decode(String.self, forKey: .entryID)
        navigationOnly = try c.decode(Bool.self, forKey: .navigationOnly)
        guard kind == "open_session", navigationOnly, !sessionID.isEmpty, !entryID.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "Invalid navigation action")
        }
    }
    public var reference: DJConnectSessionEntryReference { .init(sessionID: sessionID, entryID: entryID) }
}

public struct DJConnectSavedSession: Codable, Equatable, Sendable, Identifiable {
    public let sessionID: String
    public let lifecycleStatus: String
    public let createdAt: String
    public let startedAt: String
    public let endedAt: String
    public let interruptedAt: String
    public let revision: DJConnectHistoryRevision
    public let readOnly: Bool
    public let historyCoverage: String
    public var id: String { sessionID }
    public var isContractValid: Bool {
        !sessionID.isEmpty && !revision.value.isEmpty && DJConnectHistoryEntry.date(createdAt) != nil &&
        ["OPENING", "ACTIVE", "ENDED", "INTERRUPTED"].contains(lifecycleStatus) &&
        readOnly == ["ENDED", "INTERRUPTED"].contains(lifecycleStatus)
    }
    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id", lifecycleStatus = "lifecycle_status", createdAt = "created_at"
        case startedAt = "started_at", endedAt = "ended_at", interruptedAt = "interrupted_at"
        case revision, readOnly = "read_only", historyCoverage = "history_coverage"
    }
}

public struct DJConnectHistoryPlayback: Codable, Equatable, Sendable {
    public let title: String?
    public let artist: String?
    public let album: String?
    public let provider: String?
    public let sourceURL: String?
    public let coverage: String
    enum CodingKeys: String, CodingKey { case title, artist, album, provider, coverage; case sourceURL = "source_url" }
}

public struct DJConnectHistoryHighlight: Codable, Equatable, Sendable {
    public let startUTF16: Int
    public let lengthUTF16: Int
    public init(startUTF16: Int, lengthUTF16: Int) { self.startUTF16 = startUTF16; self.lengthUTF16 = lengthUTF16 }
    enum CodingKeys: String, CodingKey { case startUTF16 = "start_utf16", lengthUTF16 = "length_utf16" }
    public func safeRange(in text: String) -> NSRange? {
        let count = (text as NSString).length
        guard startUTF16 >= 0, lengthUTF16 > 0, startUTF16 <= count,
              lengthUTF16 <= count - startUTF16 else { return nil }
        let range = NSRange(location: startUTF16, length: lengthUTF16)
        guard Range(range, in: text) != nil,
              (text as NSString).rangeOfComposedCharacterSequences(for: range) == range else { return nil }
        return range
    }
}

public struct DJConnectHistoryEntry: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case playbackObserved = "playback_observed", djMoment = "dj_moment"
        case conversationUser = "conversation_user", conversationDJ = "conversation_dj"
    }
    public let entryID: String
    public let sessionID: String
    public let order: Int
    public let kind: Kind
    public let occurredAt: String
    public let retainedUntil: String
    public var text: String?
    public var playback: DJConnectHistoryPlayback?
    public var turnID: String?
    public var clientMessageID: String?
    public var originMessageID: String?
    public var role: String?
    public var inputType: String?
    public var context: DJConnectConversationContext?
    public var momentID: String?
    public var momentType: String?
    public var persona: String?
    public var summary: String?
    public var archiveBasis: String?
    public var sourceAttribution: [String: String]?
    public var historicalViewOnly: Bool?
    public var currentDisplayAllowed: Bool?
    public var requiresSpotifyAttribution: Bool?
    public var openAction: DJConnectSessionOpenAction?
    public var highlights: [DJConnectHistoryHighlight]?
    public var id: String { entryID }
    public var reference: DJConnectSessionEntryReference { .init(sessionID: sessionID, entryID: entryID) }
    public var isContractValid: Bool {
        guard historicalViewOnly == true, currentDisplayAllowed == false,
              !entryID.isEmpty, !sessionID.isEmpty, order > 0,
              Self.date(occurredAt) != nil, Self.date(retainedUntil) != nil else { return false }
        if let openAction, openAction.reference != reference { return false }
        switch kind {
        case .playbackObserved:
            guard playback?.coverage == "observed_playing_not_full_listen" else { return false }
            if playback?.provider == "Spotify" {
                guard requiresSpotifyAttribution == true, let raw = playback?.sourceURL,
                      let url = URL(string: raw), url.scheme == "https", url.host == "open.spotify.com",
                      url.user == nil, url.password == nil else { return false }
            }
            return true
        case .djMoment:
            return ["cc0_normalized_fields_v1", "runtime_authored_direction_v1"].contains(archiveBasis ?? "") && text?.isEmpty == false
        case .conversationUser, .conversationDJ:
            return turnID?.isEmpty == false && originMessageID?.isEmpty == false && clientMessageID?.isEmpty == false &&
                ["text", "voice"].contains(inputType ?? "") && context?.sessionID == sessionID &&
                role == (kind == .conversationUser ? "user" : "assistant")
        }
    }
    public func isRetained(at date: Date = Date()) -> Bool {
        guard !entryID.isEmpty, !sessionID.isEmpty, order > 0,
              Self.date(occurredAt) != nil, let deadline = Self.date(retainedUntil) else { return false }
        return deadline > date
    }
    public static func date(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter(); fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
    enum CodingKeys: String, CodingKey {
        case historicalViewOnly = "historical_view_only", currentDisplayAllowed = "current_display_allowed"
        case entryID = "entry_id", sessionID = "session_id", order, kind, occurredAt = "occurred_at", retainedUntil = "retained_until"
        case text, playback, turnID = "turn_id", clientMessageID = "client_message_id", originMessageID = "origin_message_id"
        case role, inputType = "input_type", context, momentID = "moment_id", momentType = "moment_type", persona, summary
        case archiveBasis = "archive_basis", sourceAttribution = "source_attribution"
        case requiresSpotifyAttribution = "requires_spotify_attribution", openAction = "open_action", highlights
    }
}

public struct DJConnectSessionHistoryPage: Decodable, Equatable, Sendable {
    public let success: Bool
    public let schemaVersion: Int
    public let sessions: [DJConnectSavedSession]
    public let revision: DJConnectHistoryRevision
    public let nextCursor: String?
    public let retentionDays: Int
    enum CodingKeys: String, CodingKey { case success, sessions, revision; case schemaVersion = "schema_version", nextCursor = "next_cursor", retentionDays = "retention_days" }
}

public struct DJConnectSessionTimelinePage: Decodable, Equatable, Sendable {
    public let success: Bool
    public let schemaVersion: Int
    public let session: DJConnectSavedSession
    public let entries: [DJConnectHistoryEntry]
    public let revision: DJConnectHistoryRevision
    public let nextCursor: String?
    public let window: String?
    public let anchorEntryID: String?
    public let windowLimit: Int?
    public let scannedOrderMin: Int?
    public let scannedOrderMax: Int?
    public let scanComplete: Bool?
    enum CodingKeys: String, CodingKey {
        case success, session, entries, revision, window
        case schemaVersion = "schema_version", nextCursor = "next_cursor", anchorEntryID = "anchor_entry_id"
        case windowLimit = "window_limit", scannedOrderMin = "scanned_order_min", scannedOrderMax = "scanned_order_max", scanComplete = "scan_complete"
    }
}

public enum DJConnectHistoryWindow: String, Sendable { case tail, anchor }

public struct DJConnectSessionSearchPage: Decodable, Equatable, Sendable {
    public let success: Bool
    public let schemaVersion: Int
    public let sessionID: String
    public let query: String
    public let revision: DJConnectHistoryRevision
    public let matches: [DJConnectHistoryEntry]
    public let returnedCount: Int
    public let totalCount: Int?
    public let complete: Bool
    public let nextCursor: String?
    public let normalization: String
    public let highlightUnits: String
    enum CodingKeys: String, CodingKey {
        case success, query, revision, matches, complete, normalization
        case schemaVersion = "schema_version", sessionID = "session_id", returnedCount = "returned_count"
        case totalCount = "total_count", nextCursor = "next_cursor", highlightUnits = "highlight_units"
    }
}

public struct DJConnectSessionOpenResponse: Decodable, Equatable, Sendable {
    public let success: Bool
    public let schemaVersion: Int
    public let session: DJConnectSavedSession
    public let entry: DJConnectHistoryEntry
    public let readOnly: Bool
    public let navigationOnly: Bool
    enum CodingKeys: String, CodingKey {
        case success, session, entry, schemaVersion = "schema_version", readOnly = "read_only", navigationOnly = "navigation_only"
    }
}

public struct DJConnectConversationConfirmation: Decodable, Equatable, Sendable {
    public let schemaVersion: Int
    public let turnID: String
    public let context: DJConnectConversationContext
    public let entryIDs: [String]
    public let inputType: String
    enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version", turnID = "turn_id", context, entryIDs = "entry_ids", inputType = "input_type" }
}

public struct DJConnectSessionConversationResponse: Decodable, Sendable {
    public let base: DJConnectAskDJMessageResponse
    public let conversation: DJConnectConversationConfirmation
    public let historicalMatches: [DJConnectHistoryEntry]
    public let transcript: String?
    public let ownerScope: String
    enum CodingKeys: String, CodingKey { case conversation, historicalMatches = "historical_matches", transcript, recognizedText = "recognized_text", ownerScope = "owner_profile_id" }
    public init(from decoder: Decoder) throws {
        base = try DJConnectAskDJMessageResponse(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        conversation = try c.decode(DJConnectConversationConfirmation.self, forKey: .conversation)
        ownerScope = try c.decode(String.self, forKey: .ownerScope)
        historicalMatches = try c.decodeIfPresent([DJConnectHistoryEntry].self, forKey: .historicalMatches) ?? []
        transcript = try c.decodeIfPresent(String.self, forKey: .transcript) ?? c.decodeIfPresent(String.self, forKey: .recognizedText)
    }
}

public struct DJConnectProfileConversationHistory: Decodable, Sendable {
    public let base: DJConnectAskDJHistoryResponse
    public let historicalMatches: [String: [DJConnectHistoryEntry]]
    public let ownerScope: String
    private struct Message: Decodable {
        let id: String
        let historicalMatches: [DJConnectHistoryEntry]?
        enum CodingKeys: String, CodingKey { case id, historicalMatches = "historical_matches" }
    }
    private enum CodingKeys: String, CodingKey { case messages, ownerScope = "owner_profile_id" }
    public init(from decoder: Decoder) throws {
        base = try DJConnectAskDJHistoryResponse(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ownerScope = try c.decode(String.self, forKey: .ownerScope)
        let messages = try c.decodeIfPresent([Message].self, forKey: .messages) ?? []
        historicalMatches = Dictionary(messages.map { ($0.id, $0.historicalMatches ?? []) }, uniquingKeysWith: { _, latest in latest })
    }
}

public struct DJConnectSessionHistoryCapabilities: Decodable, Sendable {
    public let capabilities: [String: Bool]?
    public let contractVersions: [String: Int]?
    public var available: Bool {
        capabilities?["session_conversation_history"] == true && contractVersions?["session_conversation_history"] == 1
    }
    public var searchAvailable: Bool {
        available && capabilities?["session_flow_text_search"] == true && contractVersions?["session_flow_text_search"] == 1
    }
    enum CodingKeys: String, CodingKey { case capabilities, contractVersions = "contract_versions" }
}
