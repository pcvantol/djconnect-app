import DJConnectCore
import Foundation

#if os(iOS) && canImport(ActivityKit)
// The SDK's Activity reference predates Sendable annotations. Our bookkeeping
// and state observation stay on MainActor; lifecycle calls are serialized by
// the app model and await ActivityKit's own asynchronous implementation.
@preconcurrency import ActivityKit
import UIKit

/// Called serially by the app model. Widget, Lock Screen and Island consume
/// exactly the same admitted snapshot. Playback alone can never start it.
@available(iOS 16.1, *)
@MainActor
enum DJConnectSessionSurfaceActivityController {
    /// Native side of the future receiving port. Only an actual request result
    /// can create this object. It supplies no rich-start/read/relay permission,
    /// no rate qualification and no cold-process adoption.
    @MainActor final class NativeTarget: SessionSurfaceRetirableHandle {
        private let activity: Activity<DJConnectSessionLiveActivityAttributes>
        let originalAttributes: Data
        let dispatchCapture: DJConnectNativeSurfaceClockCapture
        private let custody: SessionSurfaceNativeCustody.Ticket
        private let statusOrigin: DJConnectDirectStatusObservationOrigin?
        private(set) var isRetired = false
        var activityID: String { activity.id }
        var presentationID: String { activity.attributes.presentationID }
        fileprivate init(activity: Activity<DJConnectSessionLiveActivityAttributes>, attributes: Data,
                         custody: SessionSurfaceNativeCustody.Ticket, capture: DJConnectNativeSurfaceClockCapture,
                         statusOrigin: DJConnectDirectStatusObservationOrigin? = nil) {
            self.activity = activity; originalAttributes = attributes; self.custody = custody
            dispatchCapture = capture
            self.statusOrigin = statusOrigin
        }
        var isCurrent: Bool {
            guard !isRetired, custody.isOwnerCurrent,
                  activity.activityState == .active || activity.activityState == .stale,
                  (try? JSONEncoder().encode(activity.attributes)) == originalAttributes else { return false }
            let inventory = Activity<DJConnectSessionLiveActivityAttributes>.activities.filter { $0.id == activity.id }
            return inventory.count == 1 && inventory[0].attributes.presentationID == presentationID
        }
        func retire() { isRetired = true }
        fileprivate func carriesStatusOrigin(_ origin: DJConnectDirectStatusObservationOrigin) -> Bool {
            isCurrent && statusOrigin === origin && origin.isCurrent
        }
        fileprivate func updateStatus(from origin: DJConnectDirectStatusObservationOrigin) async throws -> Bool {
            guard carriesStatusOrigin(origin), origin.surfaceData == "live_activity",
                  let snapshot = origin.currentSnapshotData, snapshot.playbackObservation != nil else { throw CancellationError() }
            await activity.update(ActivityContent(state: snapshot, staleDate: nil))
            return isCurrent && origin.isCurrent
        }
        fileprivate func endOwnedStatus() async {
            isRetired = true
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
    @MainActor final class StatusCarry {
        private let origin: DJConnectDirectStatusObservationOrigin
        private let target: NativeTarget
        private var retired = false
        private var cleanup: Task<Void, Never>?
        fileprivate init(origin: DJConnectDirectStatusObservationOrigin, target: NativeTarget) {
            self.origin = origin; self.target = target
        }
        var isCurrent: Bool { !retired && origin.isCurrent && target.isCurrent }
        func publish() async throws -> Bool {
            guard isCurrent else { throw CancellationError() }
            return try await target.updateStatus(from: origin)
        }
        func retire() {
            guard !retired else { return }; retired = true
            nativeTargets.retire(target, id: target.activityID)
            let target = target, origin = origin
            cleanup = Task {
                await target.endOwnedStatus() // Exact owned handle only, never replacement inventory.
                await origin.withdrawOriginalRead()
            }
        }
    }
    private static let nativeTargets = SessionSurfaceNativeHandleRegistry<NativeTarget>()
    private static var statusRequestAttempts: [ObjectIdentifier: DJConnectDirectStatusObservationOrigin] = [:]

    /// Joins genuine original source ownership to a real foreground native
    /// target. No status DTO, defaults bit or cold inventory constructs a carry.
    static func adoptStatus(origin: DJConnectDirectStatusObservationOrigin, presentationID: String,
        publication: SessionSurfaceNativeCustody.Ticket) async throws -> StatusCarry? {
        guard !DJConnectLocalization.isQualificationProcess, origin.isCurrent, origin.surfaceData == "live_activity",
              origin.currentSnapshotData != nil, publication.canStartStatus,
              UIApplication.shared.applicationState == .active, UIApplication.shared.isProtectedDataAvailable,
              ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        if let target = currentCapturedTarget(presentationID: presentationID), target.carriesStatusOrigin(origin) {
            return StatusCarry(origin: origin, target: target)
        }
        guard statusRequestAttempts[ObjectIdentifier(origin)] == nil else { return nil }
        // Cold inventory is negative cleanup only, never positive adoption.
        for old in Activity<DJConnectSessionLiveActivityAttributes>.activities {
            guard origin.isCurrent, publication.canStartStatus else { throw CancellationError() }
            DJConnectSessionSurfacePresentation.applicationEnded(old.attributes.presentationID,
                wasDismissed: old.activityState == .dismissed, activityID: old.id, in: .standard)
            withdrawPush(old)
            await old.end(nil, dismissalPolicy: .immediate)
            guard origin.isCurrent, publication.canStartStatus else { throw CancellationError() }
        }
        let id = ObjectIdentifier(origin)
        guard statusRequestAttempts[id] == nil, statusRequestAttempts.count < 64, nativeTargets.hasCapacity,
              let capture = publication.dispatchCapture, let snapshot = origin.currentSnapshotData,
              DJConnectSessionSurfacePresentation.canRequest(presentationID,
                build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown", in: .standard) else { return nil }
        let attributes = DJConnectSessionLiveActivityAttributes(presentationID: presentationID)
        let bytes = try JSONEncoder().encode(attributes)
        guard origin.isCurrent, publication.canStartStatus else { throw CancellationError() }
        statusRequestAttempts[id] = origin // Once before SDK; an unknown request never retries.
        // The admitted push channel is host wake. No second ActivityKit APNs
        // token/registration is synthesized for this status adoption.
        let activity = try Activity.request(attributes: attributes,
            content: ActivityContent(state: snapshot, staleDate: nil), pushType: nil)
        let target = NativeTarget(activity: activity, attributes: bytes, custody: publication, capture: capture, statusOrigin: origin)
        guard nativeTargets.insert(target, id: activity.id) else {
            await target.endOwnedStatus(); return nil
        }
        DJConnectSessionSurfacePresentation.requested(presentationID,
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown", activityID: activity.id, in: .standard)
        return StatusCarry(origin: origin, target: target)
    }
    /// Negative cleanup only. No cold SDK object becomes a positive target.
    static func retirePrivateContentForStatusMode() async {
        for old in Activity<DJConnectSessionLiveActivityAttributes>.activities where old.content.state.playbackObservation == nil {
            DJConnectSessionSurfacePresentation.applicationEnded(old.attributes.presentationID,
                wasDismissed: old.activityState == .dismissed, activityID: old.id, in: .standard)
            withdrawPush(old)
            await old.end(nil, dismissalPolicy: .immediate)
        }
    }
    static func currentCapturedTarget(presentationID: String) -> NativeTarget? {
        let matching = nativeTargets.values.filter { $0.presentationID == presentationID && $0.isCurrent }
        return matching.count == 1 ? matching[0] : nil
    }
    private static let pushRequestedKey = "DJConnectSessionActivity.pushRequestedID.v1"
    private static var stateObservers: [String: Task<Void, Never>] = [:]
    private static var tokenObservers: [String: Task<Void, Never>] = [:]
    private static var nativePushChanged: (@MainActor (DJConnectActivityPushToken?, String) -> Void)?
    private static func withdrawPush(_ activity: Activity<DJConnectSessionLiveActivityAttributes>) {
        withdrawPush(activity, target: nativeTargets[activity.id])
    }
    private static func withdrawPush(_ activity: Activity<DJConnectSessionLiveActivityAttributes>, target: NativeTarget?) {
        if let target { nativeTargets.retire(target, id: activity.id) }
        nativePushChanged?(nil, activity.id) // The model fences removal by exact native activity ID.
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
        if (try? DJConnectActivityPushToken.recordIfCurrent(pending, in: .standard)) == true {
            nativePushChanged?(pending, activity.id)
        }
    }
    private static func observe(_ activity: Activity<DJConnectSessionLiveActivityAttributes>) {
        guard stateObservers[activity.id] == nil else { return }
        let originalTarget = nativeTargets[activity.id]
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
            withdrawPush(activity, target: originalTarget)
            stateObservers[activity.id] = nil
        }
    }
    // Fresh actual SDK inventory only. Never restore authority from a pending
    // token saved by a previous process or from a different Activity instance.
    static func currentNativePushToken(presentationID: String?) -> DJConnectActivityPushToken? {
        guard let presentationID else { return nil }
        let inventory = Activity<DJConnectSessionLiveActivityAttributes>.activities.filter {
            $0.attributes.presentationID == presentationID && ($0.activityState == .active || $0.activityState == .stale)
        }
        guard inventory.count == 1, let activity = inventory.first, let token = activity.pushToken,
              DJConnectSessionSurfacePresentation.ownsPushToken(presentationID: presentationID,
                  activityID: activity.id, in: .standard) else { return nil }
        return DJConnectActivityPushToken(token: token, activityID: activity.id, presentationID: presentationID)
    }
    private static func endCurrentActivities(publication: SessionSurfaceNativeCustody.Ticket, reason: String) async -> String? {
        // Negative current-owner work does not require a positive content lease.
        let activities = Activity<DJConnectSessionLiveActivityAttributes>.activities
        for activity in activities {
            guard publication.isCurrent else { return nil }
            DJConnectSessionSurfacePresentation.applicationEnded(activity.attributes.presentationID,
                wasDismissed: activity.activityState == .dismissed, activityID: activity.id, in: .standard)
            withdrawPush(activity)
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return activities.isEmpty ? nil : "Session Live Activity ended by app; reason=\(reason)"
    }
    static func sync(snapshot: DJConnectSessionSurfaceSnapshot?, presentationID: String?,
                     canStart: Bool, publication: SessionSurfaceNativeCustody.Ticket, endReason: String,
                     nativePushChanged: (@MainActor (DJConnectActivityPushToken?, String) -> Void)? = nil) async -> String? {
        guard publication.isCurrent, !publication.privateFieldsSuppressed else { return nil }
        self.nativePushChanged = nativePushChanged
        let defaults = UserDefaults.standard
        // Retire the old fixed playback-only activity, including after upgrade.
        for old in Activity<TrackInsightLiveActivityAttributes>.activities {
            guard publication.isCurrent else { return nil }
            await old.end(nil, dismissalPolicy: .immediate)
        }
        guard publication.isCurrent else { return nil }
        var activities = Activity<DJConnectSessionLiveActivityAttributes>.activities
        for activity in activities { observe(activity) }
        guard let snapshot, snapshot.isCurrent(at: Date()), publication.canPublish(), let presentationID else {
            return await endCurrentActivities(publication: publication, reason: endReason)
        }
        // Existing pre-push instances cannot acquire an ActivityKit update token.
        // Migrate only a still-visible, admitted presentation in foreground;
        // dismissed instances retain the existing user-dismissal fence.
        for activity in activities where canStart && activity.attributes.presentationID == presentationID &&
            (activity.activityState == .active || activity.activityState == .stale) &&
            defaults.string(forKey: pushRequestedKey) != activity.id {
            guard publication.isCurrent else { return nil }
            DJConnectSessionSurfacePresentation.applicationEnded(presentationID,
                wasDismissed: false, activityID: activity.id, in: defaults)
            withdrawPush(activity)
            await activity.end(nil, dismissalPolicy: .immediate)
            guard publication.isCurrent else { return nil }
            activities.removeAll { $0.id == activity.id }
        }
        for activity in activities where activity.attributes.presentationID != presentationID {
            guard publication.isCurrent else { return nil }
            DJConnectSessionSurfacePresentation.applicationEnded(activity.attributes.presentationID,
                wasDismissed: activity.activityState == .dismissed, activityID: activity.id, in: defaults)
            withdrawPush(activity)
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        guard publication.canPublish() else { return await endCurrentActivities(publication: publication, reason: "snapshot_expired") }
        let content = ActivityContent(state: snapshot, staleDate: snapshot.expiresAt)
        let matching = activities.filter { $0.attributes.presentationID == presentationID && $0.activityState != .ended && $0.activityState != .dismissed }
        guard matching.count <= 1 else { return nil } // Ambiguous inventory is never first-match adoption.
        if let current = matching.first {
            guard publication.canPublish() else { return await endCurrentActivities(publication: publication, reason: "snapshot_expired") }
            await current.update(content)
        } else if canStart, publication.canStart, ActivityAuthorizationInfo().areActivitiesEnabled,
                  DJConnectSessionSurfacePresentation.canRequest(presentationID,
                    build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown", in: defaults) {
            // Persist only a random local marker. Respect user/OS dismissal
            // across app resumes; do not create an activity on every live tick.
            do {
                let attributes = DJConnectSessionLiveActivityAttributes(presentationID: presentationID)
                let attributesBytes = try JSONEncoder().encode(attributes)
                guard publication.canPublish() else { return await endCurrentActivities(publication: publication, reason: "snapshot_expired") }
                guard nativeTargets.hasCapacity, publication.canStart, let capture = publication.dispatchCapture else { return nil }
                let activity = try Activity.request(attributes: attributes,
                                         content: content, pushType: .token)
                let target = NativeTarget(activity: activity, attributes: attributesBytes, custody: publication, capture: capture)
                guard nativeTargets.insert(target, id: activity.id) else { target.retire(); return nil }
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
