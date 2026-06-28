import DJConnectCore
import Foundation

#if os(iOS) && canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
enum TrackInsightLiveActivityController {
    static func update(with insight: TrackInsight) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            await endAll()
            return
        }

        let state = TrackInsightLiveActivityAttributes.ContentState(insight: insight)
        if let activity = Activity<TrackInsightLiveActivityAttributes>.activities.first {
            await activity.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(30 * 60)))
        } else {
            do {
                _ = try Activity.request(
                    attributes: TrackInsightLiveActivityAttributes(sessionID: insight.id),
                    content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(30 * 60)),
                    pushType: nil
                )
            } catch {
                return
            }
        }

        for activity in Activity<TrackInsightLiveActivityAttributes>.activities.dropFirst() {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    static func endAll() async {
        for activity in Activity<TrackInsightLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
#endif
