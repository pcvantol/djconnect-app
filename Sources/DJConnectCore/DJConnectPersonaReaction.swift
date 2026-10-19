import Foundation

/// Explicit ephemeral interaction, never an Ask DJ/Moment/history source.
public enum DJConnectPersonaReactionKind: String, Codable, CaseIterable, Sendable {
    case checkIn = "check_in", playful, easterEgg = "easter_egg"
}
public enum DJConnectPersonaReactionCancellation: String, Codable, Sendable {
    case completed, dismissed, background, askDJForeground = "ask_dj_foreground", speechConflict = "speech_conflict"
}
public enum DJConnectPersonaReactionOperation: String, Sendable {
    case request = "session/persona/reaction", cancel = "session/persona/reaction/cancel"
}
public struct DJConnectPersonaReactionContext: Codable, Equatable, Sendable {
    public let session_id: String
    public let generation: String
    public let revision: Int
    public init(_ session: DJConnectProfileDJSettingsSnapshot.Session) {
        session_id = session.session_id; generation = session.generation; revision = session.revision
    }
    public var isValid: Bool {
        [session_id, generation].allSatisfy { !$0.isEmpty && $0.utf8.count <= 128 &&
            $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines) && !$0.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) } && revision >= 0
    }
}
public struct DJConnectPersonaReactionRequest: Encodable, Sendable {
    public let contract_version = 1
    public let session: DJConnectPersonaReactionContext
    public let kind: DJConnectPersonaReactionKind
    public let language: String
    public let processor: DJConnectSpeechProcessor
    public init(settings: DJConnectProfileDJSettingsResponse, kind: DJConnectPersonaReactionKind, language: String, processor: DJConnectSpeechProcessor) throws {
        guard settings.isValid, !settings.requiresSelection, settings.snapshot.activated, settings.snapshot.accepted_contract_version == 3,
              settings.snapshot.output_choice_confirmed == true, let current = settings.snapshot.session,
              current.isValid, DJConnectPersonaReactionContext(current).isValid, ["en", "nl", "de", "fr", "es"].contains(language) else { throw DJConnectError.invalidResponse }
        session = .init(current); self.kind = kind; self.language = language; self.processor = processor
    }
}
public struct DJConnectPersonaReactionCapability: Decodable, Sendable {
    let available: Bool
    let version: Int
    let operation, cancel_operation, path, authentication: String
    let owner_only, requires_confirmed_settings, session_required, local_target, ha_speaker_target: Bool
    let settings_contract_version, maximum_seconds, maximum_pending_or_playing: Int
    let kinds, language_families, processors: [String]
    let history_publication, queue, actual_audio_start_required, client_cancel_on_lifecycle_required: Bool
    let cache_policy: String
    public var isSupported: Bool {
        available && version == 1 && operation == DJConnectPersonaReactionOperation.request.rawValue &&
        cancel_operation == DJConnectPersonaReactionOperation.cancel.rawValue && path == "/api/djconnect/v1/transport/operation" &&
        authentication == "paired_device_bearer" && owner_only && requires_confirmed_settings && session_required &&
        settings_contract_version == 3 && maximum_seconds == 30 && maximum_pending_or_playing == 1 &&
        local_target && !ha_speaker_target && !history_publication && !queue && actual_audio_start_required &&
        client_cancel_on_lifecycle_required && cache_policy == "private,no-store" &&
        Set(kinds) == Set(DJConnectPersonaReactionKind.allCases.map(\.rawValue)) &&
        Set(processors) == ["local_on_device", "ha_configured"] && Set(language_families) == ["en", "nl", "de", "fr", "es"]
    }
}
public struct DJConnectPersonaReaction: Decodable, Equatable, Sendable, Identifiable {
    public let schema_version: Int
    public let reaction_id: String
    public let session: DJConnectPersonaReactionContext
    public let text, locale: String
    public let kind: DJConnectPersonaReactionKind
    public let persona: DJConnectSessionPersonaValue
    public let mood: String
    public let persona_revision, mood_revision: Int
    public let expires_at, content_basis, cache_policy: String
    public let history_publication: Bool
    public let speech: Speech
    public var id: String { reaction_id }
    public var deadline: Date? { DJConnectHistoryEntry.date(expires_at) }
    public struct Speech: Decodable, Equatable, Sendable {
        public struct Reference: Decodable, Equatable, Sendable { public let reaction_id, session_id: String }
        public let state: String
        public let reason: String?
        public let schema_version: Int?
        public let reference: Reference?
        public let source_id, source_kind, text_revision, presentation_revision, locale, expires_at, cache_policy: String?
        public let persona: DJConnectSessionPersonaValue?
        public let persona_revision, mood_revision: Int?
        public let mood: String?
        public let segments: [DJConnectSessionSpeech.Segment]
        public let processors: [DJConnectSpeechProcessor]
        public let manual_allowed, autoplay_eligible: Bool?
        public let settings_contract_version: Int?
        public let settings_revision: [DJConnectJSONValue]?
        public let processor: DJConnectSpeechProcessor?
        public let audio_state: String?
        public let audio_reference: DJConnectSessionSpeech.AudioReference?
        public let effective_voice: DJConnectSessionSpeech.Voice?
    }
    /// Original admitted identities and deadline, not a refreshed local content lease.
    public func admits(request: DJConnectPersonaReactionRequest, settings: DJConnectProfileDJSettingsResponse,
                       receipt: DJConnectOperationReceipt, started: Date, at now: Date = Date()) -> Bool {
        schema_version == 1 && session == request.session && session.isValid && kind == request.kind && locale == request.language &&
        persona == settings.snapshot.effective.persona && mood == settings.snapshot.effective.mood && persona_revision >= 0 && mood_revision >= 0 &&
        !text.isEmpty && text.unicodeScalars.count <= 1200 && !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) && $0 != "\n" }) &&
        content_basis == "core_owned_curated_reaction_v1" && cache_policy == "private,no-store" && !history_publication &&
        receipt.contractVersion == 1 && receipt.phase == "confirmed" && receipt.resultAvailable && receipt.responseStatus == 200 &&
        !receipt.operationEpoch.isEmpty && receipt.operationID == reaction_id &&
        UUID(uuidString: reaction_id) != nil && deadline.map { now >= started && $0 > now && $0 <= now.addingTimeInterval(30) &&
            $0.timeIntervalSince1970 * 1000 <= Double(receipt.expiresAtMS) } == true
    }
    public func admitsSpeech(request: DJConnectPersonaReactionRequest, settings: DJConnectProfileDJSettingsResponse, at now: Date = Date()) -> Bool {
        guard settings.snapshot.effective.announcement_output.allowsClientAudio,
              deadline.map({ $0 > now }) == true, speech.state == "available", speech.schema_version == 1,
              speech.reference?.reaction_id == reaction_id, speech.reference?.session_id == session.session_id,
              speech.source_id == reaction_id, speech.source_kind == "core_owned_persona_reaction",
              speech.persona == persona, speech.persona_revision == persona_revision, speech.mood == mood, speech.mood_revision == mood_revision,
              speech.locale == locale, speech.expires_at == expires_at, speech.cache_policy == cache_policy,
              speech.manual_allowed == true, speech.autoplay_eligible == false,
              speech.settings_contract_version == 3, speech.settings_revision == settings.speechFence,
              speech.text_revision?.isEmpty == false, (speech.text_revision?.utf8.count ?? 129) <= 128,
              speech.presentation_revision?.isEmpty == false, (speech.presentation_revision?.utf8.count ?? 129) <= 128,
              !speech.segments.isEmpty, speech.segments.count <= 8,
              speech.segments.enumerated().allSatisfy({ $0.element.ordinal == $0.offset + 1 && $0.element.speakerRole == "dj" && !$0.element.text.isEmpty }),
              speech.segments.map(\.text).joined().utf8.elementsEqual(text.utf8), speech.processors.contains(request.processor) else { return false }
        if request.processor == .localOnDevice {
            return speech.processor == .localOnDevice && speech.audio_state == "renderer_pending" && speech.audio_reference == nil && speech.effective_voice == nil
        }
        guard speech.audio_state == "ready", speech.audio_reference?.isValid == true,
              speech.processor == nil || speech.processor == .haConfigured,
              speech.effective_voice?.processor == .haConfigured, speechLocaleMatches(speech.effective_voice?.locale, locale),
              speech.effective_voice?.hasQualifiedSelection == true else { return false }
        if settings.snapshot.effective.voice.kind == .providerVoice {
            return speech.effective_voice?.engine == settings.snapshot.effective.voice.provider_id && speech.effective_voice?.voiceID == settings.snapshot.effective.voice.voice_id
        }
        return true
    }
}
public struct DJConnectPersonaReactionResult: Decodable, Sendable {
    public let success: Bool
    public let persona_reaction: DJConnectPersonaReaction
    public let operation_receipt: DJConnectOperationReceipt
    public let delivery: [String: String]
}
