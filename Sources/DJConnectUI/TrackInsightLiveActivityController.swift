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
    private static let pushRequestedKey = "DJConnectSessionActivity.pushRequestedID.v1"
    private static var stateObservers: [String: Task<Void, Never>] = [:]
    private static var tokenObservers: [String: Task<Void, Never>] = [:]
    private static func withdrawPush(_ activity: Activity<DJConnectSessionLiveActivityAttributes>) {
        tokenObservers.removeValue(forKey: activity.id)?.cancel()
        DJConnectActivityPushToken.withdraw(activityID: activity.id, in: .standard)
        if UserDefaults.standard.string(forKey: pushRequestedKey) == activity.id {
            UserDefaults.standard.removeObject(forKey: pushRequestedKey)
        }
    }
    private static func recordPush(_ token: Data, for activity: Activity<DJConnectSessionLiveActivityAttributes>) {
        guard activity.activityState == .active || activity.activityState == .stale,
              let pending = DJConnectActivityPushToken(token: token, activityID: activity.id,
                  presentationID: activity.attributes.presentationID) else { return }
        try? DJConnectActivityPushToken.recordIfCurrent(pending, in: .standard)
    }
    private static func observe(_ activity: Activity<DJConnectSessionLiveActivityAttributes>) {
        guard stateObservers[activity.id] == nil else { return }
        if let token = activity.pushToken { recordPush(token, for: activity) }
        tokenObservers[activity.id] = Task {
            for await token in activity.pushTokenUpdates {
                guard !Task.isCancelled else { break }
                recordPush(token, for: activity)
            }
        }
        stateObservers[activity.id] = Task {
            for await state in activity.activityStateUpdates {
                if state == .dismissed {
                    DJConnectSessionSurfacePresentation.userDismissed(activity.attributes.presentationID, activityID: activity.id, in: .standard)
                    break
                }
                if state == .ended { break }
            }
            withdrawPush(activity)
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
        var activities = Activity<DJConnectSessionLiveActivityAttributes>.activities
        for activity in activities { observe(activity) }
        guard let snapshot, snapshot.isCurrent(at: Date()), let presentationID else {
            for activity in activities {
                DJConnectSessionSurfacePresentation.applicationEnded(activity.attributes.presentationID,
                    wasDismissed: activity.activityState == .dismissed, activityID: activity.id, in: defaults)
                withdrawPush(activity)
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return activities.isEmpty ? nil : "Session Live Activity ended by app; reason=\(endReason)"
        }
        // Existing pre-push instances cannot acquire an ActivityKit update token.
        // Migrate only a still-visible, admitted presentation in foreground;
        // dismissed instances retain the existing user-dismissal fence.
        for activity in activities where canStart && activity.attributes.presentationID == presentationID &&
            (activity.activityState == .active || activity.activityState == .stale) &&
            defaults.string(forKey: pushRequestedKey) != activity.id {
            DJConnectSessionSurfacePresentation.applicationEnded(presentationID,
                wasDismissed: false, activityID: activity.id, in: defaults)
            withdrawPush(activity)
            await activity.end(nil, dismissalPolicy: .immediate)
            activities.removeAll { $0.id == activity.id }
        }
        for activity in activities where activity.attributes.presentationID != presentationID {
            DJConnectSessionSurfacePresentation.applicationEnded(activity.attributes.presentationID,
                wasDismissed: activity.activityState == .dismissed, activityID: activity.id, in: defaults)
            withdrawPush(activity)
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
                                         content: content, pushType: .token)
                defaults.set(activity.id, forKey: pushRequestedKey)
                DJConnectSessionSurfacePresentation.requested(presentationID,
                    build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown", activityID: activity.id, in: defaults)
                // Establish exact native ownership before consuming an already
                // available token; its stream need not emit that token again.
                observe(activity)
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
