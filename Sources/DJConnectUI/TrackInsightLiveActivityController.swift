import DJConnectCore
import Foundation

#if os(iOS) && canImport(ActivityKit)
import ActivityKit

/// Called serially by the app model. Widget, Lock Screen and Island consume
/// exactly the same admitted snapshot. Playback alone can never start it.
@available(iOS 16.1, *)
enum DJConnectSessionSurfaceActivityController {
    static func sync(snapshot: DJConnectSessionSurfaceSnapshot?, presentationID: String?,
                     canStart: Bool) async {
        let defaults = UserDefaults.standard
        // Retire the old fixed playback-only activity, including after upgrade.
        for old in Activity<TrackInsightLiveActivityAttributes>.activities {
            await old.end(nil, dismissalPolicy: .immediate)
        }
        let activities = Activity<DJConnectSessionLiveActivityAttributes>.activities
        guard let snapshot, snapshot.isCurrent(at: Date()), let presentationID else {
            for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
            return
        }
        for activity in activities where activity.attributes.presentationID != presentationID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        let content = ActivityContent(state: snapshot, staleDate: snapshot.expiresAt)
        if let current = activities.first(where: { $0.attributes.presentationID == presentationID }) {
            await current.update(content)
        } else if canStart, ActivityAuthorizationInfo().areActivitiesEnabled,
                  defaults.string(forKey: "DJConnectSessionSurface.requested") != presentationID {
            // Persist only a random local marker. Respect user/OS dismissal
            // across app resumes; do not create an activity on every live tick.
            do {
                _ = try Activity.request(attributes: DJConnectSessionLiveActivityAttributes(presentationID: presentationID),
                                         content: content, pushType: nil)
                defaults.set(presentationID, forKey: "DJConnectSessionSurface.requested")
            } catch { NSLog("DJConnect Session Activity request failed: %@", error.localizedDescription) }
        }
    }
}
#endif
