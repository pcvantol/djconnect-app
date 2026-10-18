import XCTest
import DJConnectCore
@testable import DJConnectUI

/// Explicit physical qualification only. Uses the installed app's own credential
/// store; emits contract counts, never credentials, text, URLs or owner IDs.
@MainActor final class SessionHistoryQualification: XCTestCase {
    private func pairedModel() throws -> DJConnectAppModel {
        #if os(macOS)
        let key = "DJConnectMacDeviceToken"
        #else
        let key = "DJConnectIOSDeviceToken"
        #endif
        let model = DJConnectAppModel(tokenStore: DJConnectUserDefaultsTokenStore(key: key), startBackgroundTasks: false)
        guard !model.isDemoMode, model.pairingStatus == .paired else {
            throw XCTSkip("No ordinary paired app context; not positive qualification")
        }
        return model
    }

    func testCurrentSessionHistoryReadsAndReopens() async throws {
        let model = try pairedModel()
        let refreshed = await model.refreshActiveDJSession()
        XCTAssertTrue(refreshed)
        let session = try XCTUnwrap(model.activeDJSession)
        await model.sessionHistory.prepare()
        XCTAssertTrue(model.sessionHistory.available)
        await model.sessionHistory.loadTimeline(session.id, window: .tail)
        let timeline = try XCTUnwrap(model.sessionHistory.timelines[session.id])
        XCTAssertNil(timeline.errorKey)
        XCTAssertNotNil(timeline.session)
        XCTAssertFalse(timeline.entries.isEmpty)
        XCTAssertTrue(timeline.entries.allSatisfy { $0.isContractValid && $0.sessionID == session.id })
        let entries = timeline.entries
        await model.sessionHistory.loadTimeline(session.id, window: .tail)
        let reopened = try XCTUnwrap(model.sessionHistory.timelines[session.id])
        XCTAssertNil(reopened.errorKey)
        XCTAssertEqual(Set(reopened.entries.map(\.id)).count, reopened.entries.count)
        let report: [String: Any] = [
            "bundle_id": Bundle.main.bundleIdentifier ?? "unknown",
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "history_available": model.sessionHistory.available,
            "entry_count": entries.count, "reopened_entry_count": reopened.entries.count,
            "new_narration_count": entries.filter { ["owner_metadata_narration_v1", "public_artist_narration_v1"].contains($0.archiveBasis ?? "") }.count,
            "all_contract_valid": entries.allSatisfy { $0.isContractValid },
            "duplicate_ids": reopened.entries.count - Set(reopened.entries.map(\.id)).count,
            "read_only": true
        ]
        print("SESSION_HISTORY_QUALIFICATION", String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
    }

    func testExplicitlyAuthorizedSessionStopStartArchiveAndResume() async throws {
        guard ProcessInfo.processInfo.environment["DJC_SESSION_LIFECYCLE_CONSENT"] == "explicit-owner-consent-20261018" else {
            throw XCTSkip("Session lifecycle changes require separate explicit owner consent and a coordinated producer window")
        }
        let model = try pairedModel()
        let refreshed = await model.refreshNowPlaying()
        XCTAssertTrue(refreshed)
        XCTAssertTrue(model.canUsePlaybackFeatures)
        _ = await model.refreshActiveDJSession()
        if model.activeDJSession != nil {
            await model.endDJSession()
            XCTAssertNil(model.activeDJSession)
        }
        await model.startDJSession()
        let started = try XCTUnwrap(model.activeDJSession)
        await model.sessionHistory.prepare()
        await model.sessionHistory.loadTimeline(started.id, window: .tail)
        XCTAssertNil(model.sessionHistory.timelines[started.id]?.errorKey)
        XCTAssertNotNil(model.sessionHistory.timelines[started.id]?.session)
        await model.endDJSession()
        XCTAssertNil(model.activeDJSession)
        await model.sessionHistory.loadTimeline(started.id, window: .tail)
        let archived = try XCTUnwrap(model.sessionHistory.timelines[started.id])
        XCTAssertNil(archived.errorKey)
        XCTAssertEqual(archived.session?.readOnly, true)
        XCTAssertEqual(archived.session?.lifecycleStatus, "ENDED")
        await model.startDJSession()
        let resumed = try XCTUnwrap(model.activeDJSession)
        XCTAssertNotEqual(resumed.id, started.id)
        await model.sessionHistory.loadTimeline(resumed.id, window: .tail)
        XCTAssertNil(model.sessionHistory.timelines[resumed.id]?.errorKey)
        print("SESSION_LIFECYCLE_QUALIFICATION", "stop_start_archive_resume=true active_history_loaded=true left_new_session_active=true")
    }
}
