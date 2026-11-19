#if os(iOS)
import ActivityKit
import AppIntents
import DJConnectCore
import Foundation

struct DJConnectSessionNextTrackIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Next track" }
    static var isDiscoverable: Bool { false }
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Session presentation") var presentationID: String
    init() { presentationID = "" }
    init(presentationID: String) { self.presentationID = presentationID }

    @MainActor func perform() async throws -> some IntentResult {
        let now = Date()
        guard UUID(uuidString: presentationID) != nil,
              Activity<DJConnectSessionLiveActivityAttributes>.activities.contains(where: {
                  $0.attributes.presentationID == presentationID && $0.activityState == .active &&
                      $0.content.state.isCurrent(at: now) && ($0.content.staleDate.map { now < $0 } ?? true)
              }), let next = DJConnectSessionPlaybackIntentBridge.nextTrack else { return .result() }
        _ = await next(presentationID)
        return .result()
    }
}
#endif
