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
