import Foundation
import XCTest
#if os(iOS)
import ActivityKit
#endif

/// Synthetic display/codec proposal only; no runtime owner, receiver or grant.
final class RemoteActivityV1PrototypeTests: XCTestCase {
    private let p = "00000000-0000-4000-8000-000000000001"
    private let g = "00000000-0000-4000-8000-000000000002"
    private func object() -> [String: Any] {
        ["contract_version": 1, "presentation_id": p, "presentation_generation": g, "sequence": 2,
         "observed_at_unix_ms": Int64(1_800_000_000_000), "expires_at_unix_ms": Int64(1_800_000_060_000),
         "phase": "active", "theme": "groove", "playback": ["track": "Synthetic track", "artist": "Synthetic artist",
             "album": "Synthetic album", "playback_state": "playing", "source_label": "Synthetic test only"]]
    }
    private func decode(_ body: [String: Any]) throws -> DJConnectRemoteSessionActivityStateV1 {
        try JSONDecoder().decode(DJConnectRemoteSessionActivityStateV1.self, from: JSONSerialization.data(withJSONObject: body))
    }
    private func identity(_ generation: String? = nil) throws -> DJConnectRemoteSessionActivityIdentityV1 {
        try JSONDecoder().decode(DJConnectRemoteSessionActivityIdentityV1.self,
            from: JSONSerialization.data(withJSONObject: ["presentation_id": p, "presentation_generation": generation ?? g]))
    }
    func testExactNewDefaultCodecAndExplicitNullsAreSeparateFromLocalType() throws {
        let state = try decode(object())
        XCTAssertEqual(try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? NSDictionary, object() as NSDictionary)
        XCTAssertEqual(state.observed_at_unix_ms, 1_800_000_000_000) // No Date/2001 conversion.
        var final = object(); final["phase"] = "ended"; final["theme"] = NSNull(); final["playback"] = NSNull()
        let ended = try decode(final)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: JSONEncoder().encode(ended)) as? NSDictionary, final as NSDictionary)
        #if os(iOS)
        let content = ActivityContent<DJConnectRemoteSessionActivityAttributesV1.ContentState>(state: state,
            staleDate: Date(timeIntervalSince1970: Double(state.expires_at_unix_ms)/1000))
        XCTAssertEqual(content.state, state)
        #endif
    }
    func testMissingUnknownNullUnsafeAndForeignClockFieldsReject() throws {
        let original = object()
        for key in original.keys { var b = original; b.removeValue(forKey: key); XCTAssertThrowsError(try decode(b), key) }
        for key in ["receivedUptime", "receivedAt", "C0", "rho_min", "extra"] { var b = original; b[key] = 1; XCTAssertThrowsError(try decode(b), key) }
        for (key, value) in [("contract_version", true as Any), ("sequence", 0 as Any), ("sequence", 9_007_199_254_740_992 as Any),
                             ("observed_at_unix_ms", NSNull()), ("expires_at_unix_ms", Int64(1_800_000_120_001)),
                             ("presentation_generation", "other"), ("phase", "start")] {
            var b = original; b[key] = value; XCTAssertThrowsError(try decode(b), key)
        }
        var b = original; b["phase"] = "ended"; XCTAssertThrowsError(try decode(b)) // No rich final state.
        var playback = try XCTUnwrap(original["playback"] as? [String: Any]); playback["extra"] = true
        b = original; b["playback"] = playback; XCTAssertThrowsError(try decode(b))
    }
    func testDefaultClosedAndTargetStaleEndedAndExpiryBranches() throws {
        let state = try decode(object()), target = try identity()
        XCTAssertEqual(RemoteActivityV1DisplayProbe.project(state, identity: target, isStale: false, nowUnixMS: state.observed_at_unix_ms), .neutral)
        func project(_ s: DJConnectRemoteSessionActivityStateV1, _ t: DJConnectRemoteSessionActivityIdentityV1, _ stale: Bool, _ now: Int64) -> RemoteActivityV1DisplayProbe.Projection {
            RemoteActivityV1DisplayProbe.project(s, identity: t, isStale: stale, nowUnixMS: now, testModelAssumesOSDisplayConsent: true)
        }
        XCTAssertNotEqual(project(state, target, false, state.observed_at_unix_ms), .neutral)
        XCTAssertEqual(project(state, try identity("00000000-0000-4000-8000-000000000003"), false, state.observed_at_unix_ms), .neutral)
        XCTAssertEqual(project(state, target, true, state.observed_at_unix_ms), .neutral)
        XCTAssertEqual(project(state, target, false, state.expires_at_unix_ms), .neutral)
        XCTAssertEqual(project(state, target, false, state.observed_at_unix_ms - 240_000), .neutral)
    }
    func testCounterexamplesRemainOpenForSlowWallClockAndCrossUpdateOrder() throws {
        let state = try decode(object()), target = try identity()
        // At true server t=+241s, a wall clock240s behind still displays t=+1s.
        // Keep this counterexample: this prototype supplies NO expiry/wipe proof.
        XCTAssertNotEqual(RemoteActivityV1DisplayProbe.project(state, identity: target, isStale: false,
            nowUnixMS: state.observed_at_unix_ms + 1000, testModelAssumesOSDisplayConsent: true), .neutral)
        var old = object(); old["sequence"] = 1
        // A stateless renderer cannot know that sequence2 arrived previously.
        XCTAssertNotEqual(RemoteActivityV1DisplayProbe.project(try decode(old), identity: target, isStale: false,
            nowUnixMS: state.observed_at_unix_ms + 1000, testModelAssumesOSDisplayConsent: true), .neutral)
    }
    func testWholeAPNsPayloadBudgetIsSeparateFromNativeContentSize() throws {
        let state = try decode(object())
        let content = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
        let update: [String: Any] = ["aps": ["timestamp": 1_800_000_000, "event": "update", "content-state": content, "stale-date": 1_800_000_060]]
        XCTAssertLessThanOrEqual(try JSONSerialization.data(withJSONObject: update).count, 4096)
    }
}
