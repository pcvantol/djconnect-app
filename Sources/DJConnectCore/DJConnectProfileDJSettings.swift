import Foundation

/// Contract3 private owner settings. These values are never device defaults.
public struct DJConnectProfileDJSettings: Codable, Equatable, Sendable {
    public struct Voice: Codable, Equatable, Sendable {
        public enum Kind: String, Codable, Sendable { case providerDefault = "provider_default", providerVoice = "provider_voice" }
        public let kind: Kind
        public let provider_id: String?
        public let voice_id: String?
        public init(kind: Kind = .providerDefault, providerID: String? = nil, voiceID: String? = nil) {
            self.kind = kind; provider_id = providerID; voice_id = voiceID
        }
        public var isValid: Bool {
            switch kind {
            case .providerDefault: return provider_id == nil && voice_id == nil
            case .providerVoice: return Self.validIdentifier(provider_id) && Self.validIdentifier(voice_id)
            }
        }
        private static func validIdentifier(_ value: String?) -> Bool {
            guard let value else { return false }
            return !value.isEmpty && value.utf8.count <= 128 && value == value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    public let persona: DJConnectSessionPersonaValue
    public let voice: Voice
    public let gender: DJConnectVoicePreference
    public let mood: String
    public let presence: DJConnectSessionPresenceValue
    public let announcement_output: DJAnnouncementOutput
    public var isValid: Bool { voice.isValid && ["chill", "groove", "energy", "party"].contains(mood) }

    public struct Patch: Codable, Equatable, Sendable {
        public var persona: DJConnectSessionPersonaValue?
        public var voice: Voice?
        public var gender: DJConnectVoicePreference?
        public var mood: String?
        public var presence: DJConnectSessionPresenceValue?
        public var announcement_output: DJAnnouncementOutput?
        public init(persona: DJConnectSessionPersonaValue? = nil, voice: Voice? = nil,
                    gender: DJConnectVoicePreference? = nil, mood: String? = nil,
                    presence: DJConnectSessionPresenceValue? = nil, output: DJAnnouncementOutput? = nil) {
            self.persona = persona; self.voice = voice; self.gender = gender; self.mood = mood
            self.presence = presence; announcement_output = output
        }
        public init(_ value: DJConnectProfileDJSettings) {
            self.init(persona: value.persona, voice: value.voice, gender: value.gender,
                      mood: value.mood, presence: value.presence, output: value.announcement_output)
        }
        public var isComplete: Bool { persona != nil && voice != nil && gender != nil && mood != nil && presence != nil && announcement_output != nil }
        public var isValid: Bool {
            (persona != nil || voice != nil || gender != nil || mood != nil || presence != nil || announcement_output != nil) &&
            (voice?.isValid ?? true) && (mood.map { ["chill", "groove", "energy", "party"].contains($0) } ?? true)
        }
    }
}

public struct DJConnectProfileDJSettingsSnapshot: Codable, Equatable, Sendable {
    public struct Session: Codable, Equatable, Sendable {
        public let session_id: String
        public let generation: String
        public let settings: DJConnectProfileDJSettings?
        public let revision: Int
        public let defaults_revision: Int
        public let selection_required: Bool?
        public var isValid: Bool {
            !session_id.isEmpty && !generation.isEmpty && revision >= 0 && defaults_revision >= 0 &&
            (settings?.isValid ?? (selection_required == true))
        }
    }
    public let contract_version: Int
    public let defaults: DJConnectProfileDJSettings
    public let defaults_revision: Int
    public let activated: Bool
    public let output_choice_confirmed: Bool?
    public let accepted_contract_version: Int?
    public let session: Session?
    public var isValid: Bool { contract_version == 3 && defaults_revision >= 0 && defaults.isValid && (session?.isValid ?? true) }
    public var effective: DJConnectProfileDJSettings { session?.settings ?? defaults }
}

/// Additive Core v1 identity. Content and style are authored by Core.
public struct DJConnectSettingsConfirmationIdentity: Codable, Equatable, Sendable {
    public let schema_version: Int
    public let confirmation_id: String
    public let changed_fields: [String]
    public let accepted_at: String
    public var isValid: Bool {
        schema_version == 1 && confirmation_id.utf8.count == 41 && confirmation_id.range(of: "^settings-[a-f0-9]{32}$", options: .regularExpression) != nil &&
        !changed_fields.isEmpty && changed_fields.count <= 3 && Set(changed_fields).count == changed_fields.count &&
        Set(changed_fields).isSubset(of: ["mood", "persona", "presence"]) && DJConnectHistoryEntry.date(accepted_at) != nil
    }
}
public struct DJConnectSettingsConfirmationContract: Codable, Equatable, Sendable {
    public let available: Bool
    public let version: Int
    public let trigger: String
    public let fields: [String]
    public let one_per_operation: Bool
    public let owner_only: Bool
    public let no_session: String
    public let music_only: String
    public let replay: String
    public let speech: String
    public let automatic_mood: String
    public var isSupported: Bool {
        available && version == 1 && trigger == "accepted_user_change" &&
        Set(fields) == Set(["mood", "persona", "presence"]) && one_per_operation && owner_only &&
        no_session == "operation_confirmation_only" && music_only == "confirm_then_silent" &&
        replay == "original_identity_no_new_lease" && automatic_mood == "no_confirmation" &&
        speech == "existing_session_speech_respecting_announcement_output"
    }
}
public struct DJConnectSettingsConfirmation: Codable, Equatable, Sendable {
    public struct Settings: Codable, Equatable, Sendable {
        public let mood: String
        public let persona: DJConnectSessionPersonaValue
        public let presence: DJConnectSessionPresenceValue
    }
    public let schema_version: Int
    public let confirmation_id: String
    public let changed_fields: [String]
    public let accepted_at: String
    public let settings: Settings
    public let locale: String
    public let session_id: String
    public let settings_generation: String
    public let settings_revision: Int?
    public let defaults_revision: Int
    public let moment_id: String?
    public let title: String
    public let text: String
    public func validates(_ snapshot: DJConnectProfileDJSettingsSnapshot) -> Bool {
        let identity = DJConnectSettingsConfirmationIdentity(schema_version: schema_version,
            confirmation_id: confirmation_id, changed_fields: changed_fields, accepted_at: accepted_at)
        guard identity.isValid, ["nl", "en", "de", "fr", "es"].contains(locale),
              !text.isEmpty, text.utf8.count <= 16000, title.utf8.count <= 512,
              settings.mood == snapshot.effective.mood, settings.persona == snapshot.effective.persona,
              settings.presence == snapshot.effective.presence, defaults_revision == snapshot.defaults_revision else { return false }
        if let session = snapshot.session {
            return session_id == session.session_id && settings_generation == session.generation &&
                settings_revision == session.revision && moment_id == "moment-" + String(confirmation_id.dropFirst(9))
        }
        return session_id.isEmpty && settings_generation.isEmpty && settings_revision == nil && moment_id == nil
    }
}

public struct DJConnectProfileDJSettingsResponse: Codable, Equatable, Sendable {
    public struct Allowed: Codable, Equatable, Sendable {
        public struct Voices: Codable, Equatable, Sendable {
            public struct Item: Codable, Equatable, Sendable {
                public let voice_id: String
                public let name: String
                public let gender: String?
            }
            public let kinds: [String]
            public let provider_id: String
            public let voices: [Item]
        }
        public let persona: [String]
        public let mood: [String]
        public let presence: [String]
        public let announcement_output: [String]
        public let voice: Voices
        public let gender: [String]
    }
    public struct Migration: Codable, Equatable, Sendable {
        public let state: String
        public let requires_review: Bool
        public let complete_selection_fields: [String]?
    }
    public struct Availability: Codable, Equatable, Sendable {
        public let available: Bool
        public let reason: String?
    }
    public struct Output: Codable, Equatable, Sendable {
        public struct Choice: Codable, Equatable, Sendable { public let value: String; public let available: Bool }
        public let selected: String
        public let speaker_available: Bool
        public let speaker_reason: String?
        public let outputs: [Choice]
        public let voice_applicability: String
    }
    public let success: Bool
    public let contract_version: Int
    public let snapshot: DJConnectProfileDJSettingsSnapshot
    public let binding: String
    public let scope: String
    public let allowed_values: Allowed
    public let writable_fields: [String]
    public let voice_revision: String
    public let voice_availability: Availability
    public let announcement_output: Output
    public let migration: Migration
    public let cache_policy: String
    public let as_of: String
    public let accepted: Bool?
    public let replayed: Bool?
    public let operation_id: String?
    public let expires_ms: Int?
    public let settings_confirmation_contract: DJConnectSettingsConfirmationContract?
    public let settings_confirmation: DJConnectSettingsConfirmation?
    public static let fields: Set<String> = ["persona", "voice", "gender", "mood", "presence", "announcement_output"]
    public var requiresSelection: Bool { migration.requires_review || snapshot.session?.selection_required == true }
    public var isValid: Bool {
        success && contract_version == 3 && snapshot.isValid && scope == "profile_and_active_session" &&
        binding.utf8.count == 64 && binding.allSatisfy { "0123456789abcdef".contains($0) } &&
        cache_policy == "private,no-store" && Set(writable_fields) == Self.fields &&
        !voice_revision.isEmpty && DJConnectHistoryEntry.date(as_of) != nil &&
        allowed_values.voice.voices.count <= 64 &&
        allowed_values.persona.allSatisfy { DJConnectSessionPersonaValue(rawValue: $0) != nil } &&
        allowed_values.mood.allSatisfy { ["chill", "groove", "energy", "party"].contains($0) } &&
        allowed_values.presence.allSatisfy { DJConnectSessionPresenceValue(rawValue: $0) != nil } &&
        allowed_values.gender.allSatisfy { DJConnectVoicePreference(rawValue: $0) != nil } &&
        allowed_values.announcement_output.allSatisfy { DJAnnouncementOutput(rawValue: $0) != nil }
    }
}

public struct DJConnectProfileDJSettingsOperation: Codable, Sendable {
    public struct Receipt: Codable, Sendable {
        public let accepted: Bool
        public let operation_id: String
        public let snapshot: DJConnectProfileDJSettingsSnapshot
        public let expires_ms: Int
        public let settings_confirmation: DJConnectSettingsConfirmation?
    }
    public let success: Bool
    public let contract_version: Int
    public let phase: String
    public let operation_id: String?
    public let receipt: Receipt?
    public let cache_policy: String
    public func validates(operationID: String) -> Bool {
        guard success, contract_version == 3, cache_policy == "private,no-store" else { return false }
        switch phase {
        case "accepted": return receipt?.operation_id == operationID && receipt?.accepted == true && receipt?.snapshot.isValid == true
        case "not_accepted", "unknown": return operation_id == operationID && receipt == nil
        default: return false
        }
    }
}

public struct DJConnectProfileDJSettingsFailure: Error, Codable, Equatable, Sendable {
    public let error: String
}

private final class DJSettingsRedirectGuard: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}

/// Private bounded JSON transport, independent of cached UI projections.
final class DJConnectProfileDJSettingsTransport: Sendable {
    private let session: URLSession
    init(configuration: URLSessionConfiguration) {
        configuration.urlCache = nil; configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false; configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15; configuration.timeoutIntervalForResource = 20
        session = URLSession(configuration: configuration, delegate: DJSettingsRedirectGuard(), delegateQueue: nil)
    }
    deinit { session.invalidateAndCancel() }
    func read(_ request: URLRequest) async throws -> (Data, Int) {
        let (bytes, response) = try await session.bytes(for: request)
        defer { bytes.task.cancel() }
        guard let response = response as? HTTPURLResponse, response.url == request.url,
              [200, 400, 401, 403, 404, 409, 426, 503].contains(response.statusCode) else { throw DJConnectError.invalidResponse }
        guard response.mimeType == "application/json", response.expectedContentLength <= 65_536 else { throw DJConnectError.invalidResponse }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < 65_536 else { throw DJConnectError.payloadTooLarge(limitBytes: 65_536, actualBytes: nil) }
            data.append(byte)
        }
        guard response.expectedContentLength < 0 || response.expectedContentLength == data.count else { throw DJConnectError.invalidResponse }
        try Task.checkCancellation()
        return (data, response.statusCode)
    }
}

public enum DJConnectSharedSpeechTarget: String, Codable, Sendable { case local, haSpeaker = "ha_speaker", both }
public struct DJConnectSharedSpeechResult: Codable, Sendable {
    public let success: Bool
    public let session_speech: DJConnectSessionSpeech
    public let delivery: [String: String]?
}

extension DJConnectProfileDJSettingsResponse {
    public var speechFence: [DJConnectJSONValue] {
        [.int(snapshot.defaults_revision), snapshot.session.map {
            .array([.string($0.session_id), .string($0.generation), .int($0.revision)])
        } ?? .null]
    }
    public func allowsSpeech(_ target: DJConnectSharedSpeechTarget) -> Bool {
        guard isValid, !requiresSelection, snapshot.effective.announcement_output != .textOnly else { return false }
        if target == .local { return true } // explicit local replay remains valid for speaker-only
        return snapshot.effective.announcement_output != .clientDevice
    }
}
