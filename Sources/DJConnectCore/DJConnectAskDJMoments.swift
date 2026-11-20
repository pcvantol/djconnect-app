import Foundation

/// Additive original-owner adapter. Inventory content and order are Core-owned.
public enum DJConnectAskDJMoments {
    public enum Read: String, Sendable { case inventory = "ask_dj/moments", status = "ask_dj/moments/status" }
    public enum Action: String, Sendable { case request = "ask_dj/moments/request", cancel = "ask_dj/moments/cancel" }
    static let languages: Set<String> = ["en", "nl", "de", "fr", "es"]
    static func bounded(_ value: String, maximum: Int = 256) -> Bool {
        !value.isEmpty && value.utf8.count <= maximum && value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
        !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    }
    static func operationID(_ value: String) -> Bool {
        value.range(of: "^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", options: .regularExpression) != nil
    }
    public struct Capability: Codable, Equatable, Sendable {
        public let available: Bool
        public let contractVersion: Int
        public let inventoryOperation, requestOperation, statusOperation, cancelOperation: String
        public let readPath, operationPath: String
        public let ownerOnly: Bool
        public let clientTypes, languageFamilies: [String]
        public let requiresActiveSession, inventoryHasProviderEffects: Bool
        public let maximumPending: Int
        public let queue: Bool
        public let typeIDs: [String]
        enum CodingKeys: String, CodingKey {
            case available, queue
            case contractVersion = "contract_version", inventoryOperation = "inventory_operation", requestOperation = "request_operation"
            case statusOperation = "status_operation", cancelOperation = "cancel_operation", readPath = "read_path", operationPath = "operation_path"
            case ownerOnly = "owner_only", clientTypes = "client_types", languageFamilies = "language_families"
            case requiresActiveSession = "requires_active_session", inventoryHasProviderEffects = "inventory_has_provider_effects"
            case maximumPending = "maximum_pending_per_profile_session", typeIDs = "type_ids"
        }
        public func admits(client: DJConnectClientType) -> Bool {
            available && contractVersion == 1 && [.ios, .macos].contains(client) && ownerOnly &&
            clientTypes.contains(client.rawValue) && inventoryOperation == Read.inventory.rawValue && statusOperation == Read.status.rawValue &&
            requestOperation == Action.request.rawValue && cancelOperation == Action.cancel.rawValue &&
            readPath == "/api/djconnect/v1/transport/read" && operationPath == "/api/djconnect/v1/transport/operation" &&
            requiresActiveSession && !inventoryHasProviderEffects && maximumPending == 1 && !queue &&
            Set(languageFamilies) == languages && !typeIDs.isEmpty && typeIDs.count <= 64 &&
            Set(typeIDs).count == typeIDs.count && typeIDs.allSatisfy { bounded($0) }
        }
    }
    public struct Subject: Codable, Equatable, Sendable {
        public let reference, kind, title, subtitle: String
        enum CodingKeys: String, CodingKey { case kind, title, subtitle; case reference = "subject_ref" }
        var isValid: Bool { bounded(reference, maximum: 512) && bounded(kind) && bounded(title, maximum: 4096) && subtitle.utf8.count <= 4096 }
    }
    public struct Item: Codable, Equatable, Sendable, Identifiable {
        public let typeID: String
        public let order: Int
        public let label: [String: String]
        public let available: Bool
        public let reason: String?
        public let reasonText: String?
        public let reasonLabels: [String: String]?
        public let subject: Subject
        public let pendingText: String
        public let momentType: String?
        public var id: String { typeID }
        enum CodingKeys: String, CodingKey {
            case order, label, available, reason, subject
            case reasonLabels = "reason_labels", reasonText = "reason_text", typeID = "type_id", pendingText = "pending_text", momentType = "moment_type"
        }
        public func title(language: String) -> String { label[language] ?? label["en"] ?? typeID }
        public func unavailableReason(language: String) -> String? { reasonLabels?[language] ?? reasonText }
        var isValid: Bool {
            bounded(typeID) && order >= 0 && order <= 10_000 && Set(label.keys) == languages &&
            label.values.allSatisfy { bounded($0) } && (reasonText == nil || reasonText.map { bounded($0, maximum: 4096) } == true) &&
            (reasonLabels == nil || (Set(reasonLabels?.keys.map { $0 } ?? []) == languages && reasonLabels?.values.allSatisfy { bounded($0, maximum: 4096) } == true)) && subject.isValid && bounded(pendingText, maximum: 4096) &&
            (!available || (reason == nil && momentType.map { bounded($0) } == true))
        }
    }
    public struct Inventory: Codable, Equatable, Sendable {
        public let success: Bool
        public let contractVersion: Int
        public let sessionID, language, title: String
        public let types: [Item]
        enum CodingKeys: String, CodingKey { case success, language, title, types; case contractVersion = "contract_version", sessionID = "session_id" }
        public func admits(session: String, capability: Capability) -> Bool {
            success && contractVersion == 1 && sessionID == session && bounded(session) && languages.contains(language) &&
            title == "Ask DJ: Moments" && types.count == capability.typeIDs.count &&
            Set(types.map(\.typeID)) == Set(capability.typeIDs) && Set(types.map(\.order)).count == types.count && types.allSatisfy(\.isValid)
        }
        public var orderedTypes: [Item] { types.sorted { $0.order < $1.order } }
    }
    public struct Request: Codable, Equatable, Sendable {
        public let contractVersion = 1
        public let sessionID, typeID, subjectReference: String
        public init(sessionID: String, item: Item) { self.sessionID = sessionID; typeID = item.typeID; subjectReference = item.subject.reference }
        enum CodingKeys: String, CodingKey { case contractVersion = "contract_version", sessionID = "session_id", typeID = "type_id", subjectReference = "subject_ref" }
    }
    public struct Provenance: Codable, Equatable, Sendable {
        public let contractVersion: Int
        public let operationID, typeID, subjectReference: String
        public let playbackItemID: String?
        enum CodingKeys: String, CodingKey {
            case contractVersion = "contract_version", operationID = "operation_id", typeID = "type_id", subjectReference = "subject_ref", playbackItemID = "playback_item_id"
        }
    }
    public struct PresentationAdmission: Codable, Equatable, Sendable {
        public let contractVersion: Int
        public let momentID: String
        public let ownerOnly, displayAllowed: Bool
        public let expiresAt: String
        enum CodingKeys: String, CodingKey { case contractVersion = "contract_version", momentID = "moment_id", ownerOnly = "owner_only", displayAllowed = "display_allowed", expiresAt = "expires_at" }
        public func admits(moment: DJConnectMoment, at now: Date) -> Bool {
            contractVersion == 1 && ownerOnly && displayAllowed && momentID == moment.id &&
            DJConnectHistoryEntry.date(expiresAt).map { $0 > now } == true
        }
    }
    public struct Result: Codable, Equatable, Sendable {
        public let moment: DJConnectMoment
        public let entryID: String?
        public let retention: String
        public let historyState: String
        public let admission: PresentationAdmission
        public let sessionMedia: [DJConnectSessionMedia]
        public let sessionSpeech: SpeechGrant?
        public struct SpeechGrant: Codable, Equatable, Sendable {
            public let schemaVersion: Int
            public let moments: [DJConnectSessionSpeech]
            enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version", moments }
        }
        public var speech: DJConnectSessionSpeech? {
            guard sessionSpeech?.schemaVersion == 1 else { return nil }
            return sessionSpeech?.moments.first { $0.reference == .moment(sessionID: moment.sessionID, momentID: moment.id) && $0.admits(reference: .moment(sessionID: moment.sessionID, momentID: moment.id), text: moment.content) }
        }
        enum CodingKeys: String, CodingKey { case moment, retention; case historyState = "history_state", entryID = "entry_id", admission = "presentation_admission", sessionMedia = "session_media", sessionSpeech = "session_speech" }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            moment = try c.decode(DJConnectMoment.self, forKey: .moment)
            entryID = try c.decodeIfPresent(String.self, forKey: .entryID)
            retention = try c.decode(String.self, forKey: .retention)
            historyState = try c.decode(String.self, forKey: .historyState)
            admission = try c.decode(PresentationAdmission.self, forKey: .admission)
            // Optional image/audio transport failures cannot erase committed text.
            sessionMedia = Array(((try? c.decode([DJConnectSessionMedia].self, forKey: .sessionMedia)) ?? []).prefix(3))
            sessionSpeech = try? c.decode(SpeechGrant.self, forKey: .sessionSpeech)
        }
        public func admits(request: Request, item: Item, operationID id: String, at now: Date) -> Bool {
            guard item.available, item.typeID == request.typeID, item.subject.reference == request.subjectReference,
                  moment.sessionID == request.sessionID, !moment.content.isEmpty, moment.content.utf8.count <= 64_000,
                  moment.type == item.momentType, moment.presentationIntent.visibility == "owner_only", moment.visibility == "owner_only",
                  let provenance = moment.userRequested, provenance.contractVersion == 1, provenance.operationID == id,
                  provenance.typeID == request.typeID, provenance.subjectReference == request.subjectReference,
                  admission.admits(moment: moment, at: now),
                  (retention == "retained" && historyState == "content_retained" && entryID.map { bounded($0) } == true) || (retention == "not_retained" && ((historyState == "not_retained" && entryID == nil) || (historyState == "receipt_only" && entryID.map { bounded($0) } == true))) else { return false }
            if moment.type == "live_impression" { return moment.isLiveImpressionV1 }
            if moment.type == "dj_bulletin" { return moment.isBulletinV1 }
            return !["silence", "transition", "session", "music_announcement"].contains(moment.type)
        }
    }
    public enum State: String, Codable, Sendable {
        case pending, accepted, notFound = "not_found", temporarilyUnavailable = "temporarily_unavailable", denied, cancelled
        case acceptedResultUnavailable = "accepted_result_unavailable"
    }
    public struct Response: Codable, Equatable, Sendable {
        public let success: Bool
        public let contractVersion: Int
        public let sessionID, operationID, typeID, language: String
        public let state: State
        public let pendingText: String
        public let result: Result?
        public let error: String?
        public let message: String?
        public let receipt: DJConnectOperationReceipt?
        enum CodingKeys: String, CodingKey {
            case success, language, state, result, error, message
            case contractVersion = "contract_version", sessionID = "session_id", operationID = "operation_id", typeID = "type_id", pendingText = "pending_text", receipt = "operation_receipt"
        }
        public func matches(_ request: Request, originalID: String, checksReceipt: Bool = true) -> Bool {
            contractVersion == 1 && sessionID == request.sessionID && operationID == originalID && DJConnectAskDJMoments.operationID(operationID) &&
            typeID == request.typeID && languages.contains(language) && pendingText.utf8.count <= 4096 &&
            (!checksReceipt || receipt == nil || receipt?.operationID == originalID)
        }
    }
}

/// Malformed optional provenance cannot erase an otherwise valid retained story.
struct DJConnectOptionalRequestedMoment: Codable, Equatable, Sendable {
    let value: DJConnectAskDJMoments.Provenance?
    init(value: DJConnectAskDJMoments.Provenance) { self.value = value }
    init(from decoder: Decoder) throws { value = try? DJConnectAskDJMoments.Provenance(from: decoder) }
    func encode(to encoder: Encoder) throws {
        if let value { try value.encode(to: encoder) }
        else { var container = encoder.singleValueContainer(); try container.encodeNil() }
    }
}
