import DJConnectCore
import Foundation

#if os(iOS) && canImport(ActivityKit)
// The SDK's Activity reference predates Sendable annotations. Our bookkeeping
// and state observation stay on MainActor; lifecycle calls are serialized by
// the app model and await ActivityKit's own asynchronous implementation.
@preconcurrency import ActivityKit

/// Called serially by the app model. Widget, Lock Screen and Island consume
/// exactly the same admitted snapshot. Playback alone can never start it.
@available(iOS 16.1, *)
@MainActor
enum DJConnectSessionSurfaceActivityController {
    private static var stateObservers: [String: Task<Void, Never>] = [:]
    private static func observe(_ activity: Activity<DJConnectSessionLiveActivityAttributes>) {
        guard stateObservers[activity.id] == nil else { return }
        stateObservers[activity.id] = Task {
            for await state in activity.activityStateUpdates {
                if state == .dismissed {
                    DJConnectSessionSurfacePresentation.userDismissed(activity.attributes.presentationID, activityID: activity.id, in: .standard)
                    break
                }
                if state == .ended { break }
            }
            stateObservers[activity.id] = nil
        }
    }
    static func sync(snapshot: DJConnectSessionSurfaceSnapshot?, presentationID: String?,
                     canStart: Bool, endReason: String) async -> String? {
        let defaults = UserDefaults.standard
        // Retire the old fixed playback-only activity, including after upgrade.
        for old in Activity<TrackInsightLiveActivityAttributes>.activities {
            await old.end(nil, dismissalPolicy: .immediate)
        }
        let activities = Activity<DJConnectSessionLiveActivityAttributes>.activities
        for activity in activities { observe(activity) }
        guard let snapshot, snapshot.isCurrent(at: Date()), let presentationID else {
            for activity in activities {
                DJConnectSessionSurfacePresentation.applicationEnded(activity.attributes.presentationID,
                    wasDismissed: activity.activityState == .dismissed, activityID: activity.id, in: defaults)
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return activities.isEmpty ? nil : "Session Live Activity ended by app; reason=\(endReason)"
        }
        for activity in activities where activity.attributes.presentationID != presentationID {
            DJConnectSessionSurfacePresentation.applicationEnded(activity.attributes.presentationID,
                wasDismissed: activity.activityState == .dismissed, activityID: activity.id, in: defaults)
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        let content = ActivityContent(state: snapshot, staleDate: snapshot.expiresAt)
        if let current = activities.first(where: { $0.attributes.presentationID == presentationID && $0.activityState != .ended && $0.activityState != .dismissed }) {
            await current.update(content)
        } else if canStart, ActivityAuthorizationInfo().areActivitiesEnabled,
                  DJConnectSessionSurfacePresentation.canRequest(presentationID,
                    build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown", in: defaults) {
            // Persist only a random local marker. Respect user/OS dismissal
            // across app resumes; do not create an activity on every live tick.
            do {
                let activity = try Activity.request(attributes: DJConnectSessionLiveActivityAttributes(presentationID: presentationID),
                                         content: content, pushType: nil)
                observe(activity)
                DJConnectSessionSurfacePresentation.requested(presentationID,
                    build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown", activityID: activity.id, in: defaults)
                return "Session Live Activity started; state=\(activity.activityState); count=\(Activity<DJConnectSessionLiveActivityAttributes>.activities.count)"
            } catch {
                let error = error as NSError
                return "Session Live Activity request failed; domain=\(error.domain); code=\(error.code)"
            }
        }
        return nil
    }
}
#endif
