import DJConnectCore
import Foundation

#if os(iOS) && canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
enum TrackInsightLiveActivityController {
    private static let staleInterval: TimeInterval = 12 * 60
    private static let dismissalInterval: TimeInterval = 20 * 60

    static func sync(playback: DJConnectPlayback?) async {
        guard let playback, playback.hasPlayback == true || playback.isPlaying == true || playback.trackName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
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

        let sessionID = sessionID(for: playback)
        let content = content(for: playback)
        let state = TrackInsightLiveActivityAttributes.ContentState(playback: playback)
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
            await end(activity, state: state)
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

    private static func sessionID(for playback: DJConnectPlayback) -> String {
        let title = playback.trackName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let artist = playback.artistName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let device = playback.device?.id ?? playback.device?.name ?? ""
        let raw = "\(title)|\(artist)|\(device)"
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "djconnect-now-playing" : normalized
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
