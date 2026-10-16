import Foundation

public enum DJConnectSpeechProcessor: String, Codable, Sendable { case localOnDevice = "local_on_device", haConfigured = "ha_configured" }
public enum DJConnectVoicePreference: String, Codable, Sendable { case `default`, male, female }

/// Exactly one accepted contribution; never arbitrary caller text or a URL.
public enum DJConnectSpeechReference: Codable, Hashable, Sendable {
    case turn(String), moment(sessionID: String, momentID: String), entry(sessionID: String, entryID: String)
    enum CodingKeys: String, CodingKey { case turn = "turn_id", session = "session_id", moment = "moment_id", entry = "entry_id" }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let turn = try c.decodeIfPresent(String.self, forKey: .turn)
        let session = try c.decodeIfPresent(String.self, forKey: .session)
        let moment = try c.decodeIfPresent(String.self, forKey: .moment)
        let entry = try c.decodeIfPresent(String.self, forKey: .entry)
        if let turn, session == nil, moment == nil, entry == nil { self = .turn(turn) }
        else if let session, let moment, turn == nil, entry == nil { self = .moment(sessionID: session, momentID: moment) }
        else if let session, let entry, turn == nil, moment == nil { self = .entry(sessionID: session, entryID: entry) }
        else { throw DJConnectError.invalidResponse }
        guard isValid else { throw DJConnectError.invalidResponse }
    }
    public func encode(to encoder: Encoder) throws {
        guard isValid else { throw DJConnectError.invalidResponse }
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .turn(let id): try c.encode(id, forKey: .turn)
        case .moment(let session, let id): try c.encode(session, forKey: .session); try c.encode(id, forKey: .moment)
        case .entry(let session, let id): try c.encode(session, forKey: .session); try c.encode(id, forKey: .entry)
        }
    }
    public var isValid: Bool {
        func valid(_ s: String) -> Bool { !s.isEmpty && s.unicodeScalars.count <= 128 && s == s.trimmingCharacters(in: .whitespacesAndNewlines) && !s.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) } }
        switch self {
        case .turn(let id): return valid(id)
        case .moment(let s, let id), .entry(let s, let id): return valid(s) && valid(id)
        }
    }
    var source: (kind: String, id: String, session: String?) {
        switch self {
        case .turn(let id): return ("accepted_ask_dj", id, nil)
        case .moment(let s, let id): return ("published_dj_moment", id, s)
        case .entry(let s, let id): return ("retained_dj_contribution", id, s)
        }
    }
}

/// Optional ephemeral private-owner descriptor. Never persist or export to
/// widgets, notifications or shared displays. Preparing does not execute a turn.
public struct DJConnectSessionSpeech: Codable, Equatable, Sendable {
    public struct Segment: Codable, Equatable, Sendable {
        public let ordinal: Int
        public let speakerRole: String
        public let text: String
        enum CodingKeys: String, CodingKey { case ordinal, text, speakerRole = "speaker_role" }
    }
    public typealias Attribution = [String: String]
    public struct Voice: Codable, Equatable, Sendable {
        public let processor: DJConnectSpeechProcessor
        public let engine: String
        public let provider: String
        public let voiceID: String
        public let voiceName: String
        public let locale: String
        public let gender: String?
        public let providerVersion: String?
        public let voiceVersion: String?
        enum CodingKeys: String, CodingKey {
            case processor, engine, provider, locale, gender
            case voiceID = "voice_id", voiceName = "voice_name", providerVersion = "provider_version", voiceVersion = "voice_version"
        }
    }
    public struct AudioReference: Codable, Equatable, Sendable {
        public let assetID: String
        public let path: String
        public let method: String
        enum CodingKeys: String, CodingKey { case path, method, assetID = "asset_id" }
        public var isValid: Bool {
            !assetID.isEmpty && assetID.utf8.count <= 128 && assetID.utf8.allSatisfy {
                (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
            } && path == "/api/djconnect/v1/speech/audio" && method == "POST"
        }
    }
    public let schemaVersion: Int
    public let reference: DJConnectSpeechReference
    public let sourceKind: String?
    public let sourceID: String?
    public let sessionID: String?
    public let textRevision: String?
    public let presentationRevision: String?
    public let persona: String?
    public let personaRevision: Int?
    public let locale: String?
    public let segments: [Segment]
    public let state: String
    public let reason: String?
    public let expiresAt: String?
    public let sourceExpiresAt: String?
    public let manualAllowed: Bool
    public let autoplayEligible: Bool
    /// Advertised routes permit only an explicit server qualification attempt.
    public let processorQualificationRequired: Bool?
    public let processors: [DJConnectSpeechProcessor]
    public let cachePolicy: String
    public let attribution: [Attribution]?
    public let audioState: String?
    public let audioReference: AudioReference?
    public let effectiveVoice: Voice?
    public let voicePreference: DJConnectVoicePreference?
    public let notification: DJConnectSpeechNotification?
    enum CodingKeys: String, CodingKey {
        case reference, persona, locale, segments, state, reason, processors, attribution, notification
        case schemaVersion = "schema_version", sourceKind = "source_kind", sourceID = "source_id", sessionID = "session_id"
        case textRevision = "text_revision", presentationRevision = "presentation_revision", personaRevision = "persona_revision"
        case expiresAt = "expires_at", sourceExpiresAt = "source_expires_at", manualAllowed = "manual_allowed", autoplayEligible = "autoplay_eligible"
        case processorQualificationRequired = "processor_qualification_required"
        case cachePolicy = "cache_policy", audioState = "audio_state", audioReference = "audio_reference", effectiveVoice = "effective_voice", voicePreference = "voice_preference"
    }
    public func advertisesPreparationAttempt(_ processor: DJConnectSpeechProcessor) -> Bool {
        // Legacy omission never adds a route absent from its original list.
        processors.contains(processor) && processorQualificationRequired != false
    }

    /// Exact original accepted text and identity are supplied by the existing
    /// semantic UI owner, never inferred from current playback or new Persona.
    public func admits(reference expected: DJConnectSpeechReference, text: String, at now: Date = Date()) -> Bool {
        guard schemaVersion == 1, reference == expected, reference.isValid,
              sourceKind == reference.source.kind, sourceID == reference.source.id,
              reference.source.session == nil || sessionID == reference.source.session,
              state == "available", manualAllowed, cachePolicy == "private,no-store",
              let textRevision, !textRevision.isEmpty, textRevision.utf8.count <= 128,
              let presentationRevision, !presentationRevision.isEmpty, presentationRevision.utf8.count <= 128,
              let locale, ["en", "nl", "de", "fr", "es"].contains(locale),
              let deadline = expiresAt.flatMap(DJConnectHistoryEntry.date), deadline > now,
              !segments.isEmpty, segments.count <= 8, text.unicodeScalars.count <= 4000,
              segments.enumerated().allSatisfy({ $0.element.ordinal == $0.offset + 1 && $0.element.speakerRole == "dj" &&
                  !$0.element.text.isEmpty && $0.element.text.unicodeScalars.count <= 1200 }),
              segments.map(\.text).joined().utf8.elementsEqual(text.utf8) else { return false }
        if let raw = sourceExpiresAt {
            guard let source = DJConnectHistoryEntry.date(raw), deadline <= source else { return false }
        }
        return true
    }
}

public struct DJConnectSpeechVoiceOptions: Decodable, Equatable, Sendable {
    public struct GenderSelection: Decodable, Equatable, Sendable {
        public let available: Bool
        public let values: [DJConnectVoicePreference]
        public let voiceIDs: [String: String]?
        public let reason: String?
        enum CodingKeys: String, CodingKey { case available, values, reason; case voiceIDs = "voice_ids" }
    }
    public struct VoiceSelection: Decodable, Equatable, Sendable {
        public let available: Bool
        public let maximumVoices: Int
        enum CodingKeys: String, CodingKey { case available, maximumVoices = "maximum_voices" }
    }
    public let voices: [DJConnectSpeechVoiceInventoryEntry]?
    public let voiceSelection: VoiceSelection?
    public let preferenceContext: DJConnectSpeechPreferenceContext?
    public let providerStatus: DJConnectSpeechProviderStatus?
    public let notification: DJConnectSpeechNotification?
    public let schemaVersion: Int
    public let authority: String
    public let preferenceScope: String
    public let defaultPreference: DJConnectVoicePreference
    public let defaultAvailable: Bool
    public let supportedPreferences: [DJConnectVoicePreference]
    public let genderSelection: GenderSelection
    public let providerVoice: DJConnectSessionSpeech.Voice?
    public let revision: String
    public let state: String
    public let reason: String?
    public let cachePolicy: String
    enum CodingKeys: String, CodingKey {
        case authority, revision, state, reason, voices, notification
        case voiceSelection = "voice_selection", preferenceContext = "preference_context", providerStatus = "provider_status"
        case schemaVersion = "schema_version", preferenceScope = "preference_scope", defaultPreference = "default_preference"
        case defaultAvailable = "default_available", supportedPreferences = "supported_preferences", genderSelection = "gender_selection"
        case providerVoice = "provider_voice", cachePolicy = "cache_policy"
    }
    public var isValid: Bool {
        schemaVersion == 1 && authority == "configured_ha_assist_pipeline_provider" && preferenceScope == "device_local" &&
            defaultPreference == .default && cachePolicy == "private,no-store" && !revision.isEmpty && revision.utf8.count <= 128 &&
            (notification?.isValid ?? true) && (providerStatus?.isValid ?? true) &&
            (voices.map { $0.count <= 64 && Set($0.map(\.voiceID)).count == $0.count && $0.allSatisfy(\.isValid) } ?? true)
    }
    public var selectableVoices: [DJConnectSpeechVoiceInventoryEntry] {
        guard isValid, state == "available", voiceSelection?.available == true,
              voiceSelection?.maximumVoices == 64, preferenceContext?.isSupported == true else { return [] }
        return voices ?? []
    }
    public func supportsVoice(_ id: String) -> Bool { selectableVoices.contains { $0.voiceID == id } }
    public var selectableGenders: [DJConnectVoicePreference] {
        let values = genderSelection.values
        guard isValid, state == "available", genderSelection.available,
              !values.isEmpty, values.count <= 2, Set(values).count == values.count,
              values.allSatisfy({ $0 != .default && supportedPreferences.contains($0) }),
              let targets = genderSelection.voiceIDs, Set(targets.keys) == Set(values.map(\.rawValue)),
              values.allSatisfy({ preference in
                  selectableVoices.contains { $0.voiceID == targets[preference.rawValue] && $0.gender == preference.rawValue }
              }) else { return [] }
        return values
    }
    public func qualifiedGenderVoiceID(_ preference: DJConnectVoicePreference) -> String? {
        guard selectableGenders.contains(preference) else { return nil }
        return genderSelection.voiceIDs?[preference.rawValue]
    }
    public func admitsGender(_ preference: DJConnectVoicePreference, voiceID: String?) -> Bool {
        guard qualifiedGenderVoiceID(preference) != nil else { return false }
        guard let voiceID else { return true }
        return selectableVoices.contains { $0.voiceID == voiceID && $0.gender == preference.rawValue }
    }
    public func supports(_ preference: DJConnectVoicePreference) -> Bool {
        guard isValid, state == "available" else { return false }
        return preference == .default ? defaultAvailable && supportedPreferences.contains(.default) : selectableGenders.contains(preference)
    }
}

struct DJConnectSpeechContractRequest: Encodable { let contract_version = 1 }
struct DJConnectSpeechPrepareRequest: Encodable {
    let reference: DJConnectSpeechReference
    let processor: DJConnectSpeechProcessor
    let voice_preference: DJConnectVoicePreference
    let voice_id: String?
    let contract_version = 1
}
struct DJConnectSpeechAudioRequest: Encodable { let asset_id: String; let contract_version = 1 }
struct DJConnectSpeechResponse: Decodable { let success: Bool; let session_speech: DJConnectSessionSpeech }
struct DJConnectSpeechVoiceOptionsResponse: Decodable { let success: Bool; let speech_voice_options: DJConnectSpeechVoiceOptions }

/// Narrow speech routes deliberately reject the legacy envelope/nested payload.
struct DJConnectSpeechIdentifiedRequest<T: Encodable>: Encodable {
    let clientType: DJConnectClientType
    let deviceID: String
    let payload: T
    enum CodingKeys: String, CodingKey { case clientType = "client_type", deviceID = "device_id" }
    func encode(to encoder: Encoder) throws {
        try payload.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(clientType, forKey: .clientType); try c.encode(deviceID, forKey: .deviceID)
    }
}
