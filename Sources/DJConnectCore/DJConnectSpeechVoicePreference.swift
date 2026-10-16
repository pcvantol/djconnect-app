import Foundation

/// Backend-confirmed identities only. A URL or a device's Music DNA is not a Profile identity.
public struct DJConnectSpeechVoiceScope: Equatable, Sendable {
    public let installationID: String
    public let profileID: String
    public let sessionID: String
    public let deviceID: String

    public init?(installationID: String, profileID: String, sessionID: String, deviceID: String) {
        let values = [installationID, profileID, sessionID, deviceID]
        guard values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            $0.utf8.count <= 512 && !$0.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) }) else { return nil }
        self.installationID = installationID
        self.profileID = profileID
        self.sessionID = sessionID
        self.deviceID = deviceID
    }
}

/// Ephemeral client presentation preference. No persistence, provider calls or shared Session writes.
/// The owner must bind its confirmed scope before use, discard on Session end/authority withdrawal,
/// and refresh on menu open, foreground, reconnect and before explicit speech preparation.
public struct DJConnectSpeechVoicePreferenceState: Sendable {
    public struct Refresh: Equatable, Sendable {
        fileprivate let generation: UUID
        fileprivate let scope: DJConnectSpeechVoiceScope
    }
    public enum Resolution: Equatable, Sendable {
        case unavailable
        case configuredDefault
        case selected(String)
    }

    public private(set) var scope: DJConnectSpeechVoiceScope?
    public private(set) var selectedVoiceID: String?
    public private(set) var options: DJConnectSpeechVoiceOptions?
    public private(set) var refreshing = false
    private var generation = UUID()

    public init() {}

    /// Changing any identity discards the previous choice; returning to an old Session cannot restore it.
    public mutating func bind(_ newScope: DJConnectSpeechVoiceScope?) {
        guard scope != newScope else { return }
        discard()
        scope = newScope
    }

    public mutating func discard() {
        generation = UUID()
        scope = nil
        selectedVoiceID = nil
        options = nil
        refreshing = false
    }

    /// Invalidates current admission while retaining the user's intent for this scope.
    /// An older concurrent response cannot complete a newer refresh.
    public mutating func beginRefresh() -> Refresh? {
        invalidateInventory()
        guard let scope else { return nil }
        refreshing = true
        return Refresh(generation: generation, scope: scope)
    }

    public func isCurrentRefresh(_ refresh: Refresh) -> Bool {
        refreshing && refresh.generation == generation && refresh.scope == scope
    }

    @discardableResult
    public mutating func completeRefresh(_ refresh: Refresh, options response: DJConnectSpeechVoiceOptions?) -> Bool {
        guard refreshing, refresh.generation == generation, refresh.scope == scope else { return false }
        refreshing = false
        // Legacy metadata can support legacy speech, but cannot admit this scoped concrete-voice flow.
        guard let response, response.isValid, response.preferenceContext?.isSupported == true else { return false }
        options = response
        return true
    }

    /// Call on background/disconnect. Keep intent but never admit preparation from stale inventory.
    public mutating func invalidateInventory() {
        generation = UUID()
        options = nil
        refreshing = false
    }

    /// Local choice only. nil is an explicit return to the configured default, never an automatic fallback.
    @discardableResult
    public mutating func select(_ voiceID: String?) -> Bool {
        guard scope != nil, !refreshing, let options else { return false }
        if let voiceID {
            guard options.supportsVoice(voiceID) else { return false }
        } else {
            guard options.supports(.default) else { return false }
        }
        selectedVoiceID = voiceID
        return true
    }

    public var resolution: Resolution {
        guard scope != nil, !refreshing, let options else { return .unavailable }
        if let selectedVoiceID {
            return options.supportsVoice(selectedVoiceID) ? .selected(selectedVoiceID) : .unavailable
        }
        return options.supports(.default) ? .configuredDefault : .unavailable
    }
}
