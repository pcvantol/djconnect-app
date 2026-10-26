import Foundation
import XCTest
import WidgetKit
import DJConnectCore
#if os(iOS)
import ActivityKit
#endif

/// Actual SDK type/codec qualification only. No token request, push, HA,
/// Activity.request/update/end, credential import or installed snapshot access.
final class NativeSurfacePushSDKTests: XCTestCase {
    private func vectors() throws -> [String: [String: Any]] {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: "session-activity-local-codec-profile-v1", withExtension: "json"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return try XCTUnwrap(root["vectors"] as? [String: [String: Any]])
    }
    func testWidget26CallbackAndTimelineSignaturesHaveNoWakePayload() {
        // These references are compiled against the installed native SDK.
        // They are not a simulated callback/token-delivery receipt.
        let token: (WidgetPushInfo) -> Data = { $0.token }
        let configurations: (WidgetInfo) -> (String, WidgetFamily) = { ($0.kind, $0.family) }
        let context: (TimelineProviderContext) -> (Bool, WidgetFamily, CGSize) = { ($0.isPreview, $0.family, $0.displaySize) }
        let current: () async -> WidgetPushInfo? = { await WidgetCenter.shared.currentPushInfo }
        _ = (token, configurations, context, current, SignatureOnlyPushHandler.self)
    }
    func testLegacyContentStateDateOptionalAndUptimeVectors() throws {
        for object in try vectors().values {
            let bytes = try JSONSerialization.data(withJSONObject: object)
            let state = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: bytes)
            XCTAssertEqual(state.observedAt.timeIntervalSince1970, 1_800_000_000)
            let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? NSDictionary
            XCTAssertEqual(encoded, object as NSDictionary)
            if let rich = state.rich {
                XCTAssertTrue(rich.isCurrent(at: state.observedAt.addingTimeInterval(1), uptime: 1001))
                XCTAssertFalse(rich.isCurrent(at: state.observedAt.addingTimeInterval(1), uptime: 900_000))
            }
            #if os(iOS)
            let content = ActivityContent<DJConnectSessionLiveActivityAttributes.ContentState>(state: state, staleDate: state.expiresAt)
            XCTAssertEqual(content.state, state)
            #endif
        }
        var neutral = try XCTUnwrap(vectors()["neutral"])
        neutral["theme"] = NSNull(); neutral["rich"] = NSNull()
        let decoded = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self,
            from: JSONSerialization.data(withJSONObject: neutral))
        let normalized = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any])
        XCTAssertEqual(Set(normalized.keys), ["observedAt", "expiresAt"])
    }
    #if os(iOS)
    func testActivityAttributesAndTerminalStatesUseActualSDKTypes() throws {
        let id = "00000000-0000-4000-8000-000000000001"
        let attributes = DJConnectSessionLiveActivityAttributes(presentationID: id)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(attributes)) as? [String: String])
        XCTAssertEqual(body, ["presentationID": id])
        let decoded = try JSONDecoder().decode(DJConnectSessionLiveActivityAttributes.self, from: JSONEncoder().encode(attributes))
        XCTAssertEqual(decoded.presentationID, id)
        // Distinct SDK states; no guarantee of immediate pixel erasure.
        XCTAssertNotEqual(ActivityState.stale, ActivityState.ended)
        XCTAssertNotEqual(ActivityState.ended, ActivityState.dismissed)
    }
    #endif
}
private struct SignatureOnlyPushHandler: WidgetPushHandler {
    init() {}
    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {}
}
