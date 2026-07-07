import DJConnectCore
import Foundation

#if os(iOS) && canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
enum TrackInsightLiveActivityController {
    private static let staleInterval: TimeInterval = 12 * 60
    private static let nowPlayingSessionID = "djconnect-now-playing"

    enum SyncResult: Sendable {
        case ended(reason: String)
        case updated
        case requested
        case activitiesDisabled
        case requestFailed(String)

        var logDescription: String {
            switch self {
            case let .ended(reason):
                "ended(\(reason))"
            case .updated:
                "updated"
            case .requested:
                "requested"
            case .activitiesDisabled:
                "activities_disabled"
            case let .requestFailed(message):
                "request_failed(\(message))"
            }
        }
    }

    static func sync(playback: DJConnectPlayback?) async -> SyncResult {
        guard let playback, playback.isPlaying == true else {
            await endAll()
            return .ended(reason: playback == nil ? "no_playback" : "not_playing")
        }
        return await update(with: playback)
    }

    static func update(with playback: DJConnectPlayback) async -> SyncResult {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            await endAll()
            return .activitiesDisabled
        }

        let sessionID = nowPlayingSessionID
        let content = content(for: playback)
        let result: SyncResult
        if let activity = Activity<TrackInsightLiveActivityAttributes>.activities.first(where: { $0.attributes.sessionID == sessionID }) {
            await activity.update(content)
            result = .updated
        } else {
            do {
                _ = try Activity.request(
                    attributes: TrackInsightLiveActivityAttributes(sessionID: sessionID),
                    content: content,
                    pushType: nil
                )
                result = .requested
            } catch {
                return .requestFailed(error.localizedDescription)
            }
        }

        for activity in Activity<TrackInsightLiveActivityAttributes>.activities where activity.attributes.sessionID != sessionID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return result
    }

    static func endAll() async {
        for activity in Activity<TrackInsightLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func content(for playback: DJConnectPlayback) -> ActivityContent<TrackInsightLiveActivityAttributes.ContentState> {
        ActivityContent(
            state: TrackInsightLiveActivityAttributes.ContentState(playback: playback),
            staleDate: Date().addingTimeInterval(staleInterval)
        )
    }
}
#endif
