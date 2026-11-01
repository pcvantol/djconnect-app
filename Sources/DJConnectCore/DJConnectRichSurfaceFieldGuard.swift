import Foundation

public extension DJConnectPassiveSession {
    /// A read/as_of update is not a new source observation. Compare the whole
    /// original frame, independently of the read timestamp and expired fields.
    func hasSameOriginalObservation(as other: Self, at now: Date) -> Bool {
        let a = removingExpiredFields(at: now), b = other.removingExpiredFields(at: now)
        return a.schema_version == b.schema_version && a.surface == b.surface &&
            a.binding_id == b.binding_id && a.generation == b.generation && a.session_id == b.session_id &&
            a.revision == b.revision && a.delivery_sequence == b.delivery_sequence && a.state == b.state &&
            a.playback_state == b.playback_state && a.observed_at == b.observed_at && a.expires_at == b.expires_at &&
            a.cache_policy == b.cache_policy && a.mood == b.mood && a.presence == b.presence &&
            a.persona == b.persona && a.navigation == b.navigation && a.contribution == b.contribution &&
            a.now_playing == b.now_playing && a.artwork == b.artwork
    }
}

/// Necessary last-use checks for the existing foreground state. These retain
/// its original receive pin; they are NOT a cross-clock/permission adapter for
/// a newly encountered remote state or cold-process restoration.
public extension DJConnectPassiveActivityContent {
    func currentContribution(at now: Date, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> DJConnectPassiveSession.Contribution? {
        guard let contribution, contribution.isCurrent(at: now),
              fieldIsCurrent(until: contribution.expires_at, at: now, uptime: uptime) else { return nil }
        if directLocalVersion != nil || researchAttribution != nil {
            guard directLocalVersion == 2 else { return nil }
            if contribution.usage_basis == "public_artist_narration_v1" {
                guard researchAttribution?.matches(contribution) == true else { return nil }
            } else if researchAttribution != nil { return nil }
        }
        return contribution
    }
    func currentResearchAttribution(at now: Date, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> DJConnectDirectResearchAttribution? {
        guard directLocalVersion == 2, let contribution = currentContribution(at: now, uptime: uptime),
              researchAttribution?.matches(contribution) == true else { return nil }
        return researchAttribution
    }
    func currentPlayback(at now: Date, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> DJConnectPassiveSession.NowPlaying? {
        guard let nowPlaying, nowPlaying.isCurrent(at: now),
              fieldIsCurrent(until: nowPlaying.expires_at, at: now, uptime: uptime) else { return nil }
        return nowPlaying
    }
    private func fieldIsCurrent(until expiry: String, at now: Date, uptime: TimeInterval) -> Bool {
        guard isCurrent(at: now, uptime: uptime), receivedUptime.isFinite, uptime.isFinite,
              let end = DJConnectHistoryEntry.date(expiry) else { return false }
        return uptime - receivedUptime < end.timeIntervalSince(receivedAt)
    }
}
