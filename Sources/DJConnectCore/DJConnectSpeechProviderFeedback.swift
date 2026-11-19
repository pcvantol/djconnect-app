import Foundation

/// Functional private-owner feedback, never a provider exception or navigation URL.
public struct DJConnectSpeechNotification: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let code, messageKey, severity, presentation, locale, title, message: String
    public let actions: [String]
    public let retryable: Bool
    public let retryAfterSeconds: Int
    public let preserveText, repeatOriginalRequest: Bool
    enum CodingKeys: String, CodingKey {
        case code, severity, presentation, locale, title, message, actions, retryable
        case schemaVersion = "schema_version", messageKey = "message_key", retryAfterSeconds = "retry_after_seconds"
        case preserveText = "preserve_text", repeatOriginalRequest = "repeat_original_request"
    }
    public var isValid: Bool {
        schemaVersion == 1 && ["tts_configuration_required", "tts_provider_unavailable", "tts_voice_language_unavailable",
            "tts_preparation_failed", "tts_configuration_changed"].contains(code) && messageKey == "speech." + code &&
        severity == "warning" && presentation == "inline" && ["en", "nl", "de", "fr", "es"].contains(locale) &&
        !title.isEmpty && title.unicodeScalars.count <= 160 && !message.isEmpty && message.unicodeScalars.count <= 1024 &&
        Set(actions).count == actions.count && actions.count <= 2 && actions.allSatisfy {
            ["review_ha_tts_configuration", "retry_speech_preparation"].contains($0)
        } && (0...60).contains(retryAfterSeconds) && preserveText && !repeatOriginalRequest
    }
}

public struct DJConnectSpeechProviderStatus: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let configurationState, synthesisState: String
    public let reason, observedAt: String?
    public let retryAfterSeconds: Int
    public let cachePolicy, revision: String
    public let notification: DJConnectSpeechNotification?
    enum CodingKeys: String, CodingKey {
        case reason, revision, notification
        case schemaVersion = "schema_version", configurationState = "configuration_state", synthesisState = "synthesis_state"
        case observedAt = "observed_at", retryAfterSeconds = "retry_after_seconds", cachePolicy = "cache_policy"
    }
    public var isValid: Bool {
        schemaVersion == 1 && ["ready", "unavailable"].contains(configurationState) &&
        ["not_tested", "succeeded", "failed"].contains(synthesisState) && cachePolicy == "private,no-store" &&
        !revision.isEmpty && revision.utf8.count <= 128 && (0...60).contains(retryAfterSeconds) &&
        (notification?.isValid ?? true) && (synthesisState == "not_tested" ? observedAt == nil : observedAt.flatMap(DJConnectHistoryEntry.date) != nil)
    }
    /// Configuration readiness and a successful synthesis observation are different facts.
    public var hasSuccessfulObservation: Bool { isValid && configurationState == "ready" && synthesisState == "succeeded" }
}

public struct DJConnectSpeechProviderIssue: Error, Sendable {
    public let notification: DJConnectSpeechNotification
}

public struct DJConnectSpeechVoiceInventoryEntry: Codable, Equatable, Sendable {
    public let voiceID, name: String
    public let gender: String?
    enum CodingKeys: String, CodingKey { case voiceID = "voice_id", name, gender }
    public var isValid: Bool {
        !voiceID.isEmpty && voiceID.unicodeScalars.count <= 128 && voiceID == voiceID.trimmingCharacters(in: .whitespacesAndNewlines) &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.unicodeScalars.count <= 120 && [voiceID, name].allSatisfy {
            !$0.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
        } && (gender.map { ["male", "female"].contains($0) } ?? true)
    }
}
public struct DJConnectSpeechPreferenceContext: Codable, Equatable, Sendable {
    public let scope, storageOwner, sessionEnd: String
    public let keyFields: [String]
    public let runtimeMutable: Bool
    enum CodingKeys: String, CodingKey {
        case scope, storageOwner = "storage_owner", sessionEnd = "session_end", keyFields = "key_fields", runtimeMutable = "runtime_mutable"
    }
    public var isSupported: Bool {
        scope == "owner_session_device" && storageOwner == "client" && runtimeMutable && sessionEnd == "discard" &&
        keyFields == ["ha_installation", "profile_id", "session_id", "device_id"]
    }
}

func speechLocaleMatches(_ providerLocale: String?, _ referenceLocale: String?) -> Bool {
    guard let providerLocale, let referenceLocale, ["en", "nl", "de", "fr", "es"].contains(referenceLocale),
          providerLocale.utf8.count <= 64 else { return false }
    let parts = providerLocale.lowercased().replacingOccurrences(of: "_", with: "-").split(separator: "-", omittingEmptySubsequences: false)
    return parts.first == Substring(referenceLocale) && parts.allSatisfy {
        !$0.isEmpty && $0.count <= 8 && $0.unicodeScalars.allSatisfy { (97...122).contains($0.value) || (48...57).contains($0.value) }
    }
}
