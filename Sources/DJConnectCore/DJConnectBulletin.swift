import Foundation

/// Authenticated Core provenance, never an RSS request or a durable news cache.
public struct DJConnectBulletinSource: Codable, Equatable, Sendable {
    public let provider: String
    public let url: String
    public let license: String
    public let title: String
    public let publishedAt: String
    enum CodingKeys: String, CodingKey { case provider, url, license, title, publishedAt = "published_at" }
    public var destination: URL? {
        guard url.utf8.count <= 4096, let value = URL(string: url), value.scheme == "https",
              let host = value.host, !host.isEmpty, value.user == nil, value.password == nil else { return nil }
        return value
    }
    /// Compact visible attribution; VoiceOver also names the supplied headline
    /// so multiple links from one publisher remain distinguishable.
    public var attributionLabel: String { provider + " · " + license }
    public var accessibilityLabel: String { provider + " · " + title + " · " + license }
    var isValid: Bool {
        [provider, license, title].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf8.count <= 4096 }
            && destination != nil && DJConnectHistoryEntry.date(publishedAt) != nil
    }
}

public extension DJConnectMoment {
    var isSupportedNativeType: Bool {
        ["track", "artist", "album", "genre", "session", "transition", "silence"].contains(type) || isBulletinV1
    }
    /// Version recognition is not display or speech authority. Those continue
    /// to require original display admission and separate owner speech rights/deadlines.
    var isBulletinV1: Bool {
        type == "dj_bulletin" && !content.isEmpty && content.unicodeScalars.count <= 1200 &&
            DJConnectHistoryEntry.date(createdAt) != nil && generationMetadata?["bulletin_schema"] == "1" &&
            generationMetadata?["context_source"] == "fixed_rss_metadata_v1" &&
            knowledgeIntent?["type"] == "dj_bulletin" &&
            sourceReferences == ["fixed_rss_metadata_v1"] &&
            hasSupportedBulletinDelivery &&
            settingsConfirmation == nil && sourceAttribution == nil && artwork == nil && actions.isEmpty &&
            (2...32).contains(sources.count) && sources.allSatisfy(\.isValid)
    }
    /// Exact current Core1328 tuple plus the previously qualified private tuple
    /// for older installations. Neither shape grants native display or speech.
    private var hasSupportedBulletinDelivery: Bool {
        let channels: [String]
        switch visibility {
        case "owner_only": channels = ["owner"]
        case "session_shared": channels = ["broadcast", "owner", "shared"]
        default: return false
        }
        return presentationIntent.visibility == visibility && deliveryChannels == channels &&
            presentationIntent.deliveryChannels == channels
    }
    internal func admitsBulletin(_ admission: DJConnectNativeMomentDelivery.Admission, at date: Date, current: Bool) -> Bool {
        guard isBulletinV1, !admission.requiresSpotifyAttribution, admission.executableActions.isEmpty,
              let original = admission.sourceExpiresAt.flatMap(DJConnectHistoryEntry.date), date < original else { return false }
        if current {
            guard let display = admission.displayExpiresAt.flatMap(DJConnectHistoryEntry.date), date < display else { return false }
        }
        return true
    }
}

public extension DJConnectBroadcastState {
    /// Called only alongside the original speech descriptor. Automatic Bulletin
    /// narration additionally requires the currently displayed Moment; manual
    /// replay may use an expressly admitted live Flow item until source expiry.
    func nativeMomentSpeechIsAdmitted(_ reference: DJConnectSpeechReference, at date: Date, automatic: Bool) -> Bool {
        guard case .moment(let sessionID, let momentID) = reference, sessionID == session.sessionID,
              let moment = djMoments.first(where: { $0.id == momentID }), moment.isSupportedNativeType else { return false }
        guard moment.type == "dj_bulletin" else { return true }
        if nativeCurrentMoment(at: date)?.id == momentID { return true }
        return !automatic && nativeFlowMoments(at: date).contains { $0.id == momentID }
    }
}
