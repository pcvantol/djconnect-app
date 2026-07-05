import DJConnectCore
import Foundation

#if os(iOS) && canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
enum TrackInsightLiveActivityController {
    private static let staleInterval: TimeInterval = 12 * 60
    private static let nowPlayingSessionID = "djconnect-now-playing"

    static func sync(playback: DJConnectPlayback?) async {
        guard let playback, playback.isPlaying == true else {
            await endAll()
            return
        }
        await update(with: playback)
    }

    static func update(with playback: DJConnectPlayback) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            await endAll()
            return
        }

        let sessionID = nowPlayingSessionID
        let content = content(for: playback)
        if let activity = Activity<TrackInsightLiveActivityAttributes>.activities.first(where: { $0.attributes.sessionID == sessionID }) {
            await activity.update(content)
        } else {
            do {
                _ = try Activity.request(
                    attributes: TrackInsightLiveActivityAttributes(sessionID: sessionID),
                    content: content,
                    pushType: nil
                )
            } catch {
                return
            }
        }

        for activity in Activity<TrackInsightLiveActivityAttributes>.activities where activity.attributes.sessionID != sessionID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
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
