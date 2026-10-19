import Foundation

/// Installation-local renderer preferences only. Never sent to HA or a Profile.
public struct DJConnectDeviceSpeechPreferences: Codable, Equatable, Sendable {
    public static let storageKey = "DJConnectDeviceSpeech.v1"
    public var enabled = false
    public var voiceID: String? = nil
    public var gender: DJConnectVoicePreference = .default
    public var rate: Double = 0.5
    public var pitch: Double = 1
    public init() { }
    public var isValid: Bool {
        rate.isFinite && (0...1).contains(rate) && pitch.isFinite && (0.5...2).contains(pitch) &&
        (voiceID.map { !$0.isEmpty && $0.utf8.count <= 512 && !$0.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) } ?? true)
    }
    public static func load(from defaults: UserDefaults) -> Self {
        guard let data = defaults.data(forKey: storageKey), let value = try? JSONDecoder().decode(Self.self, from: data), value.isValid else { return Self() }
        return value
    }
    public func save(to defaults: UserDefaults) {
        guard isValid, let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

/// The phone/macOS HA-audio path cannot silently substitute native synthesis.
/// Native Watch playback uses an independently prepared settings3 grant below.
/// Preserve an independently requested HA leg.
public enum DJConnectDeviceSpeechRouting {
    public static func serverTarget(for requested: DJConnectSharedSpeechTarget,
                                    nativeOverride: Bool,
                                    settings: DJConnectProfileDJSettingsResponse) -> DJConnectSharedSpeechTarget? {
        guard settings.allowsSpeech(requested) else { return nil }
        guard nativeOverride else { return requested }
        return requested == .local ? nil : .haSpeaker
    }
}

/// Frozen Core local-settings handoff bc6e080e. Preparation grants exact text;
/// it is neither a new publication nor ready audio. Autoplay is checked by its
/// original publication owner, never inferred from prepare.autoplayEligible.
public enum DJConnectNativeSpeechAdmission {
    public static func admits(_ prepared: DJConnectSessionSpeech, reference: DJConnectSpeechReference,
                              text: String, settings: DJConnectProfileDJSettingsResponse,
                              at now: Date = Date()) -> Bool {
        settings.allowsSpeech(.local) && prepared.admits(reference: reference, text: text, at: now) &&
        prepared.processor == .localOnDevice && prepared.advertisesPreparationAttempt(.localOnDevice) &&
        prepared.processorQualificationRequired == true && prepared.audioState == "renderer_pending" &&
        prepared.audioReference == nil && prepared.effectiveVoice == nil && prepared.voicePreference == nil &&
        prepared.settingsContractVersion == 3 && prepared.settingsRevision == settings.speechFence &&
        prepared.expiresAt.flatMap(DJConnectHistoryEntry.date).map { $0.timeIntervalSince(now) <= 300.001 } == true
    }
}

/// Configuration evidence only. This snapshot never grants speech or proves audibility.
/// Unknown versions/states remain decodable but cannot qualify an HA route.
public struct DJConnectDeviceSpeechAvailability: Codable, Equatable, Sendable {
    public struct Route: Codable, Equatable, Sendable {
        public let state: String
        public let configured: Bool?
        public let available: Bool
        public let reason: String?
        public let locale: String?
        public let operational: Operational?
        public let audio: Audio?
        public let configuration_revision: String?
        public let revision: String?
        public struct Audio: Codable, Equatable, Sendable {
            public let format: String
            public let codec: String
            public let sample_rate: Int
            public let sample_width: Int
            public let channels: Int
            public var matchesCapture: Bool {
                format == "wav" && codec == "pcm" && sample_rate == 16000 && sample_width == 2 && channels == 1
            }
        }
        public struct Operational: Codable, Equatable, Sendable {
            public let synthesis_state: String
            public let retry_after_seconds: Int
        }
        public var isAvailable: Bool { state == "available" && configured == true && available }
    }
    public let schema_version: Int
    public let authority: String
    public let locale: String?
    public let revision: String
    public let ha_stt: Route
    public let ha_tts: Route
    public let ha_speaker_target: Route

    public func qualifies(locale requested: String) -> Bool {
        schema_version == 1 && authority == "configured_ha_selection" && !revision.isEmpty &&
        Self.family(locale) != nil && Self.family(locale) == Self.family(requested)
    }
    private static func family(_ value: String?) -> String? {
        guard let value, value.count <= 32,
              let family = value.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-", omittingEmptySubsequences: false).first,
              ["en", "nl", "de", "fr", "es"].contains(String(family)) else { return nil }
        return String(family)
    }
    public func allowsHAInput(locale: String) -> Bool {
        qualifies(locale: locale) && ha_stt.isAvailable && Self.family(ha_stt.locale) == Self.family(locale) &&
        ha_stt.audio?.matchesCapture == true
    }
    public func allowsHAOutput(_ target: DJConnectSharedSpeechTarget, locale: String) -> Bool {
        guard qualifies(locale: locale), ha_tts.isAvailable, Self.family(ha_tts.locale) == Self.family(locale),
              ha_tts.configuration_revision?.isEmpty == false, let operational = ha_tts.operational,
              ["not_tested", "succeeded", "failed"].contains(operational.synthesis_state),
              operational.retry_after_seconds == 0 else { return false }
        return target == .local || (ha_speaker_target.isAvailable && ha_speaker_target.revision?.isEmpty == false)
    }
}
