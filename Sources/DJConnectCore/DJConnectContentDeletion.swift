import Foundation
import CryptoKit

/// Exact producer identity; a blank Session is explicit standalone Profile scope.
public struct DJConnectContentDeleteTarget: Codable, Equatable, Sendable {
    public let kind: String
    public let session_id: String
    public let target_id: String
    public init(kind: String, sessionID: String, targetID: String) {
        self.kind = kind; session_id = sessionID; target_id = targetID
    }
    public var isValid: Bool {
        ["entry", "moment", "message", "request"].contains(kind) && !target_id.isEmpty &&
        target_id.utf8.count <= 512 && session_id.utf8.count <= 512 &&
        (!session_id.isEmpty || ["message", "request"].contains(kind))
    }
}

public struct DJConnectContentDeleteScope: Codable, Equatable, Sendable {
    public struct Unit: Codable, Equatable, Sendable {
        public let kind, session_id, target_id: String
    }
    public struct Entry: Codable, Equatable, Sendable {
        public let session_id, entry_id, disposition: String
    }
    public struct Moment: Codable, Equatable, Sendable {
        public let session_id, moment_id: String
    }
    public let success: Bool
    public let schema_version: Int
    public let owner_profile_id, confirmation_id: String
    public let target: DJConnectContentDeleteTarget
    public let unit: Unit
    public let affected_entries: [Entry]
    public let removed_message_ids, unavailable_message_ids: [String]
    public let affected_moments: [Moment]
    public let fenced_request_count: Int
    public let music_playback_undone: Bool
    public let created_at, expires_at: String

    public func admits(target requested: DJConnectContentDeleteTarget, owner: String, at now: Date = Date()) -> Bool {
        guard success, schema_version == 1, !owner.isEmpty, owner_profile_id == owner,
              target == requested, target.isValid, !confirmation_id.isEmpty, confirmation_id.count <= 512,
              !music_playback_undone, fenced_request_count >= 0, fenced_request_count <= 1000,
              unit.session_id == target.session_id, !unit.target_id.isEmpty,
              let created = DJConnectHistoryEntry.date(created_at), let expiry = DJConnectHistoryEntry.date(expires_at),
              created <= now.addingTimeInterval(30), expiry > now,
              expiry > created, expiry.timeIntervalSince(created) <= 300.001 else { return false }
        switch target.kind {
        case "moment": guard unit.kind == "moment", unit.target_id == target.target_id else { return false }
        case "message": guard unit.kind == "exchange" else { return false }
        case "request": guard ["attempt", "exchange"].contains(unit.kind) else { return false }
        case "entry": guard ["moment", "exchange"].contains(unit.kind) else { return false }
        default: return false
        }
        let total = affected_entries.count + removed_message_ids.count + unavailable_message_ids.count + affected_moments.count
        return total <= 1000 && affected_entries.allSatisfy {
            !$0.session_id.isEmpty && !$0.entry_id.isEmpty && ["remove", "unavailable"].contains($0.disposition)
        } && affected_moments.allSatisfy { !$0.session_id.isEmpty && !$0.moment_id.isEmpty }
          && (removed_message_ids + unavailable_message_ids).allSatisfy { !$0.isEmpty }
          && Set(removed_message_ids).isDisjoint(with: unavailable_message_ids)
    }
    public var requestDigest: String {
        // confirmation IDs are producer base64url; JSONSerialization binds exact bytes.
        let data = try! JSONSerialization.data(withJSONObject: ["confirmation_id": confirmation_id], options: [.sortedKeys, .withoutEscapingSlashes])
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// Flat, closed-allowlist authenticated body. Persist before dispatch, never renew.
public struct DJConnectContentDeleteRequest: Codable, Equatable, Sendable {
    public let device_id, client_type: String
    public let contract_version: Int
    public let confirmation_id, operation_id: String
    public let confirmed: Bool
    public init(identity: DJConnectIdentity, confirmationID: String,
                operationID: String = DJConnectOperationIdentity.uuidV7(milliseconds: Int(Date().timeIntervalSince1970 * 1000))) {
        device_id = identity.deviceID; client_type = identity.clientType.rawValue
        contract_version = 1; confirmation_id = confirmationID; operation_id = operationID; confirmed = true
    }
    public var isValid: Bool {
        !device_id.isEmpty && !client_type.isEmpty && contract_version == 1 && confirmed &&
        !confirmation_id.isEmpty && historyDeletionOperationIsValid(operation_id)
    }
}

public struct DJConnectContentDeleteReceipt: Decodable, Equatable, Sendable {
    public let success, deleted: Bool
    public let schema_version: Int
    public let owner_profile_id, confirmation_id, operation_id, state, request_digest: String
    public let unit: DJConnectContentDeleteScope.Unit
    public let affected_entries: [DJConnectContentDeleteScope.Entry]
    public let removed_message_ids, unavailable_message_ids: [String]
    public let music_playback_undone: Bool
    public func admits(scope: DJConnectContentDeleteScope, request: DJConnectContentDeleteRequest, owner: String) -> Bool {
        success && deleted && schema_version == 1 && state == "completed" && !music_playback_undone &&
        !owner.isEmpty && owner_profile_id == owner && owner == scope.owner_profile_id &&
        confirmation_id == scope.confirmation_id && confirmation_id == request.confirmation_id &&
        request.isValid && operation_id == request.operation_id && request_digest == scope.requestDigest &&
        unit == scope.unit && affected_entries == scope.affected_entries &&
        removed_message_ids == scope.removed_message_ids && unavailable_message_ids == scope.unavailable_message_ids
    }
}

public struct DJConnectContentDeleteStatus: Decodable, Sendable {
    public let success, definitive: Bool
    public let schema_version: Int
    public let owner_profile_id, operation_id, confirmation_id, request_digest, state: String
    public let receipt: DJConnectContentDeleteReceipt?
    public func admits(scope: DJConnectContentDeleteScope, request: DJConnectContentDeleteRequest, owner: String) -> Bool {
        guard request.isValid, success, schema_version == 1, owner_profile_id == owner, owner == scope.owner_profile_id,
              confirmation_id == request.confirmation_id, confirmation_id == scope.confirmation_id,
              operation_id == request.operation_id, request_digest == scope.requestDigest,
              ["unknown", "pending", "completed", "expired_unknown"].contains(state) else { return false }
        if state == "completed" { return definitive && receipt?.admits(scope: scope, request: request, owner: owner) == true }
        return !definitive && receipt == nil
    }
}
