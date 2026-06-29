import DJConnectCore
import Foundation

#if os(iOS) && canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
enum TrackInsightLiveActivityController {
    private static let staleInterval: TimeInterval = 12 * 60
    private static let dismissalInterval: TimeInterval = 20 * 60

    static func sync(currentInsight insight: TrackInsight?, hasActivePlayback: Bool) async {
        guard hasActivePlayback, let insight else {
            await endAll()
            return
        }
        await update(with: insight)
    }

    static func update(with insight: TrackInsight) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            await endAll()
            return
        }

        let content = content(for: insight)
        let state = TrackInsightLiveActivityAttributes.ContentState(insight: insight)
        if let activity = Activity<TrackInsightLiveActivityAttributes>.activities.first(where: { $0.attributes.sessionID == insight.id }) {
            await activity.update(content)
        } else {
            do {
                _ = try Activity.request(
                    attributes: TrackInsightLiveActivityAttributes(sessionID: insight.id),
                    content: content,
                    pushType: nil
                )
            } catch {
                return
            }
        }

        for activity in Activity<TrackInsightLiveActivityAttributes>.activities where activity.attributes.sessionID != insight.id {
            await end(activity, state: state)
        }
    }

    static func endAll() async {
        for activity in Activity<TrackInsightLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func content(for insight: TrackInsight) -> ActivityContent<TrackInsightLiveActivityAttributes.ContentState> {
        ActivityContent(
            state: TrackInsightLiveActivityAttributes.ContentState(insight: insight),
            staleDate: Date().addingTimeInterval(staleInterval)
        )
    }

    private static func end(
        _ activity: Activity<TrackInsightLiveActivityAttributes>,
        state: TrackInsightLiveActivityAttributes.ContentState
    ) async {
        await activity.end(
            ActivityContent(state: state, staleDate: Date()),
            dismissalPolicy: .after(Date().addingTimeInterval(dismissalInterval))
        )
    }
}
#endif
