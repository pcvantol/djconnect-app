import Foundation
import XCTest
import CryptoKit
import SwiftUI
import DJConnectCore
@testable import DJConnectUI

/// Manual hosted qualification. Absent admission is a SKIP, never live PASS.
/// No test endpoint, alternate model client, token export, or fake transport.
@MainActor
final class AskDJGoldenIntegrationTests: XCTestCase {
    private let catalogHash = "f54eaffb4d3caa7760a2462e6e4f50943b670409581cbdc04a58c70b00dd1359"
    private let coreCommit = "8b221d07fe2215d9516d18fe92c832332c7a16ab"
    private enum Gate: Error { case invalid(String) }
    private func require(_ condition: Bool, _ code: String) throws {
        if !condition { throw Gate.invalid(code) }
    }
    private func sha(_ value: String) -> String { sha(Data(value.utf8)) }
    private func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func privateJSON(_ url: URL) throws -> [String: Any] {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        try require(attributes[.type] as? FileAttributeType == .typeRegular &&
                    ((attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0o777) & 0o077 == 0,
                    "private_regular_file_required")
        try require(((attributes[.size] as? NSNumber)?.intValue ?? Int.max) <= 2_000_000, "input_bound")
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    func testRealPairedSessionGolden() async throws {
        guard let path = ProcessInfo.processInfo.environment["DJCONNECT_ASKDJ_GOLDEN_PLAN"],
              let output = ProcessInfo.processInfo.environment["DJCONNECT_ASKDJ_GOLDEN_OUTPUT"] else {
            throw XCTSkip("Opt-in real-client/model qualification not armed; no release acceptance")
        }
        let admitted = try admitGoldenPlan(URL(fileURLWithPath: path))
        let plan = admitted.raw, steps = admitted.steps
        let report = try prepareGoldenReport(admitted, output: output)
        let folder = report.folder
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30; configuration.timeoutIntervalForResource = 120
        configuration.urlCache = nil; configuration.httpCookieStorage = nil
        let network = URLSession(configuration: configuration)
        let wallStop = Task {
            try await Task.sleep(for: .seconds(admitted.wall))
            network.invalidateAndCancel()
        }
        defer { wallStop.cancel(); network.invalidateAndCancel() }
        let model = try makeGoldenModel(network: network, folder: folder)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(admitted.wall))
        do {
            let owner = try await prepareGoldenOwner(model, plan: plan)
            for step in steps {
                try await exerciseGoldenStep(step, admitted: admitted, model: model, owner: owner,
                    clock: clock, deadline: deadline, report: report)
            }
            report.value["status"] = "CLIENT_EXERCISED_NOT_RELEASE_PASS"
            try report.checkpoint()
            // An exercised client must never become a paid-model/semantic PASS
            // merely because the test method completed. Reconcile Core receipts.
            throw XCTSkip("Client exercised; Core/provider/effects reconciliation still required")
        } catch {
            if error is XCTSkip { throw error }
            report.value["status"] = "FAIL_OR_UNCERTAIN_NO_AUTOMATIC_RETRY"
            try report.checkpoint()
            throw Gate.invalid("native_run_failed_see_private_receipt")
        }
    }

    private struct AdmittedGoldenPlan {
        let raw: [String: Any]
        let runID: String
        let steps: [[String: Any]]
        let attempts: Int
        let maxCalls: Int
        let timeout: Int
        let wall: Int
        let ids: [String]
    }

    private struct GoldenOwner {
        let sessionID: String
        let profile: String
    }

    @MainActor private final class GoldenReport {
        let folder: URL
        let reportURL: URL
        var value: [String: Any]

        init(folder: URL, value: [String: Any]) {
            self.folder = folder
            self.reportURL = folder.appendingPathComponent("native-run.json")
            self.value = value
        }

        func checkpoint() throws {
            try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted]).write(to: reportURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: reportURL.path)
        }
    }

    private func admitGoldenPlan(_ url: URL) throws -> AdmittedGoldenPlan {
        let plan = try privateJSON(url)
        try require(plan["execute"] as? Bool == true && plan["fixture_admission"] as? String == "QUALIFIED_DISPOSABLE_SESSION", "not_armed")
        try require(plan["core_commit"] as? String == coreCommit && plan["catalog_sha256"] as? String == catalogHash, "producer_pin")
        let runID = try XCTUnwrap(plan["run_id"] as? String)
        try require(UUID(uuidString: runID) != nil, "run_identity")
        let steps = try XCTUnwrap(plan["steps"] as? [[String: Any]])
        let budget = try admitGoldenBudget(plan, steps: steps)
        let ids = try admitGoldenCatalog(steps)
        try admitGoldenHost(plan)
        return AdmittedGoldenPlan(raw: plan, runID: runID, steps: steps, attempts: budget.attempts,
            maxCalls: budget.maxCalls, timeout: budget.timeout, wall: budget.wall, ids: ids)
    }

    private func admitGoldenBudget(_ plan: [String: Any], steps: [[String: Any]]) throws -> (attempts: Int, maxCalls: Int, timeout: Int, wall: Int) {
        let requestLimit = try XCTUnwrap(plan["request_limit"] as? Int)
        let maxCalls = try XCTUnwrap(plan["max_model_calls"] as? Int)
        let attempts = try XCTUnwrap(plan["model_attempts_per_turn"] as? Int)
        try require(steps.allSatisfy { ["zero", "one_or_two"].contains($0["model_policy"] as? String ?? "") }, "unhandled_core_model_policy")
        let reservedCalls = steps.reduce(0) { $0 + (($1["model_policy"] as? String) == "zero" ? 0 : attempts) }
        try require(!steps.isEmpty && steps.count <= requestLimit && requestLimit <= 40 &&
                    (1...2).contains(attempts) && reservedCalls <= maxCalls && (1...40).contains(maxCalls), "budget")
        let timeout = try XCTUnwrap(plan["timeout_seconds"] as? Int)
        let wall = try XCTUnwrap(plan["wall_seconds"] as? Int)
        try require((1...120).contains(timeout) && (1...600).contains(wall), "deadline")
        return (attempts, maxCalls, timeout, wall)
    }

    private func admitGoldenCatalog(_ steps: [[String: Any]]) throws -> [String] {
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalogData = try Data(contentsOf: source.appendingPathComponent("Tools/qualification/askdj-golden/core-catalog.json"))
        try require(sha(catalogData) == catalogHash, "catalog_drift")
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: catalogData) as? [String: Any])
        let families = try XCTUnwrap(catalog["families"] as? [[String: Any]])
        let allSteps = families.flatMap { ($0["steps"] as? [[String: Any]]) ?? [] }
        let ids = steps.compactMap { $0["id"] as? String }
        try require(ids.count == steps.count && Set(ids).count == ids.count, "case_identity")
        for step in steps {
            let original = allSteps.first { $0["id"] as? String == step["id"] as? String }
            try require(original != nil && original?["question"] as? String == step["question"] as? String &&
                        original?["model_policy"] as? String == step["model_policy"] as? String, "noncanonical_step")
        }
        try admitGoldenFamilyOrder(steps, families: families, ids: ids)
        return ids
    }

    private func admitGoldenFamilyOrder(_ steps: [[String: Any]], families: [[String: Any]], ids: [String]) throws {
        // Prevent partial/reordered chains from being labelled as the Core family.
        var selectedFamilies: [String] = []
        for step in steps {
            let family = try XCTUnwrap(step["family"] as? String)
            if selectedFamilies.last != family { selectedFamilies.append(family) }
        }
        let expectedIDs = selectedFamilies.flatMap { family in
            (families.first { $0["id"] as? String == family }?["steps"] as? [[String: Any]])?.compactMap { $0["id"] as? String } ?? []
        }
        try require(Set(selectedFamilies).count == selectedFamilies.count && ids == expectedIDs, "incomplete_or_reordered_family")
    }

    private func admitGoldenHost(_ plan: [String: Any]) throws {
        try require(Bundle.main.bundleIdentifier == plan["bundle_id"] as? String &&
                    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String == plan["app_build"] as? String, "hosted_ordinary_app_required")
        let executable = try XCTUnwrap(Bundle.main.executableURL)
        try require(sha(try Data(contentsOf: executable)) == plan["app_executable_sha256"] as? String, "app_binary_pin")

    }

    private func prepareGoldenReport(_ admitted: AdmittedGoldenPlan, output: String) throws -> GoldenReport {
        let plan = admitted.raw, runID = admitted.runID, ids = admitted.ids
        let attempts = admitted.attempts, maxCalls = admitted.maxCalls
        let folder = URL(fileURLWithPath: output).appendingPathComponent(runID)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let started = folder.appendingPathComponent("started")
        try Data(runID.utf8).write(to: started, options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: started.path)
        var report: [String: Any] = ["schema_version": 1, "run_id": runID, "core_commit": coreCommit,
            "catalog_sha256": catalogHash, "expected_case_ids": ids, "cases": [[String: Any]](),
            "model_attempts_per_turn": attempts, "max_model_calls": maxCalls,
            "status": "RUNNING", "provider_status": "UNVERIFIED", "native_ui_gestures": "NOT_RUN"]
        for key in ["profile_sha256", "session_sha256", "app_executable_sha256", "core_install_receipt_sha256"] {
            report[key] = plan[key]
        }
        let receipt = GoldenReport(folder: folder, value: report)
        try receipt.checkpoint()
        return receipt
    }

    private func makeGoldenModel(network: URLSession, folder: URL) throws -> DJConnectAppModel {
        #if os(macOS)
        let tokenKey = "DJConnectMacDeviceToken"
        let installKey = "DJConnectInstallID-macOS"
        #else
        let tokenKey = "DJConnectIOSDeviceToken"
        let installKey = "DJConnectInstallID-iOS"
        #endif
        // Model bootstrap creates installation identity and clears an orphaned
        // token on first use. Reject that context before constructing the model.
        let store = DJConnectUserDefaultsTokenStore(key: tokenKey)
        let existingToken = try store.loadToken()
        try require([installKey, "DJConnectInstallID"].contains {
            UserDefaults.standard.string(forKey: $0)?.isEmpty == false
        } && existingToken?.isEmpty == false, "existing_paired_installation_required")
        return DJConnectAppModel(tokenStore: store,
                                      urlSession: network, startBackgroundTasks: false,
                                      diagnosticLogDirectory: folder)
    }

    private func prepareGoldenOwner(_ model: DJConnectAppModel, plan: [String: Any]) async throws -> GoldenOwner {
        try require(!model.isDemoMode && !model.isMonkeyTestingMode && model.pairingStatus == .paired, "ordinary_pairing")
        try require(!model.localResponseAudioEnabled || plan["allow_audio"] as? Bool == true, "audio_not_admitted")
        try require(plan["language"] as? String == "nl" && model.language == "nl", "localized_consumer_export_pending_or_client_language_mismatch")
        _ = await model.refreshNowPlaying()
        _ = await model.refreshActiveDJSession()
        await model.sessionHistory.prepare()
        try require(model.sessionHistory.profileScopeActive && model.canUseProfileConversation, "session_conversation_unavailable")
        let session = try XCTUnwrap(model.activeDJSession)
        let profile = try XCTUnwrap(model.sessionHistory.authorizedProfileID)
        try require(sha(session.id) == plan["session_sha256"] as? String && sha(profile) == plan["profile_sha256"] as? String, "test_owner_session_mismatch")
        return GoldenOwner(sessionID: session.id, profile: profile)
    }

    private func exerciseGoldenStep(_ step: [String: Any], admitted: AdmittedGoldenPlan,
        model: DJConnectAppModel, owner: GoldenOwner, clock: ContinuousClock,
        deadline: ContinuousClock.Instant, report: GoldenReport) async throws {
        let plan = admitted.raw, timeout = admitted.timeout
        let profile = owner.profile
        try require(clock.now < deadline && !model.isSendingAskDJText, "run_expired_or_busy")
        try require(model.activeDJSession?.id == owner.sessionID && model.sessionHistory.authorizedProfileID == profile, "owner_session_changed")
        let question = try XCTUnwrap(step["question"] as? String)
        let caseID = try XCTUnwrap(step["id"] as? String)
        try await selectGoldenSource(plan, caseID: caseID, model: model)
        let clientID = try submitGoldenQuestion(question, model: model)
        var rows = (report.value["cases"] as? [[String: Any]]) ?? []
        rows.append(["id": caseID, "question_sha256": sha(question), "client_message_sha256": sha(clientID),
                     "model_policy": step["model_policy"] ?? "unknown", "status": "SENT_OUTCOME_UNCERTAIN"])
        report.value["cases"] = rows; try report.checkpoint()
        let (assistant, serverID) = try await awaitGoldenAnswer(model, owner: owner,
            clientID: clientID, clock: clock, deadline: deadline, timeout: timeout)
        let (historyRevision, entryID) = try await readGoldenTurnBack(model, owner: owner,
            assistant: assistant, clientID: clientID, serverID: serverID)
        try renderGoldenAnswer(assistant, model: model)
        var row = rows.removeLast()
        row["server_turn_sha256"] = sha(serverID); row["answer_sha256"] = sha(assistant.text)
        row["history_revision"] = historyRevision
        row["native_bubble_rendered"] = true
        row["session_entry_sha256"] = sha(entryID)
        row["status"] = "CLIENT_ACCEPTED_PROVIDER_UNVERIFIED"
        rows.append(row); report.value["cases"] = rows; try report.checkpoint()
    }

    private func selectGoldenSource(_ plan: [String: Any], caseID: String, model: DJConnectAppModel) async throws {
        if let targets = plan["selected_entries"] as? [String: [String: String]], let target = targets[caseID] {
            let sid = try XCTUnwrap(target["session_id"]), eid = try XCTUnwrap(target["entry_id"])
            await model.sessionHistory.loadTimeline(sid, window: .tail)
            let reference = DJConnectSessionEntryReference(sessionID: sid, entryID: eid)
            try require(model.sessionHistory.timelines[sid]?.entries.contains { $0.reference == reference && $0.isRetained() } == true,
                        "selected_source_unavailable")
            model.sessionHistory.selectedEntry = reference
        } else { model.sessionHistory.selectedEntry = nil }
    }

    private func submitGoldenQuestion(_ question: String, model: DJConnectAppModel) throws -> String {
        let before = Set(model.askDJMessages.map(\.id))
        model.askDJDraft = question
        model.sendAskDJText() // Same method invoked by the ordinary composer.
        let user = try XCTUnwrap(model.askDJMessages.first { !before.contains($0.id) && $0.role == .user })
        let clientID = try XCTUnwrap(user.clientMessageID)
        return clientID
    }

    private func awaitGoldenAnswer(_ model: DJConnectAppModel, owner: GoldenOwner, clientID: String,
        clock: ContinuousClock, deadline: ContinuousClock.Instant, timeout: Int) async throws -> (DJConnectAskDJMessage, String) {
        let profile = owner.profile
        let turnDeadline = min(deadline, clock.now.advanced(by: .seconds(timeout)))
        while model.isSendingAskDJText && clock.now < turnDeadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        try require(!model.isSendingAskDJText, "turn_timeout_no_replay")
        try require(model.activeDJSession?.id == owner.sessionID && model.sessionHistory.authorizedProfileID == profile, "owner_session_changed")
        try require(model.askDJErrorMessage == nil, "client_turn_failed")
        let assistant = try XCTUnwrap(model.askDJMessages.last { $0.role == .dj && $0.clientMessageID == clientID })
        let serverID = try XCTUnwrap(assistant.serverID)
        try require(!assistant.text.isEmpty && !serverID.isEmpty, "no_server_answer")
        return (assistant, serverID)
    }

    private func readGoldenTurnBack(_ model: DJConnectAppModel, owner: GoldenOwner,
        assistant: DJConnectAskDJMessage, clientID: String, serverID: String) async throws -> (Int, String) {
        let profile = owner.profile
        // A second ordinary server history read must still contain this exact turn.
        let reopened = await model.sessionHistory.refreshConversation()
        try require(reopened && model.askDJMessages.contains { $0.serverID == serverID && $0.clientMessageID == clientID && $0.text == assistant.text }, "server_history_readback")
        let history = try await model.withHomeAssistantClient { try await $0.profileConversationHistory() }
        try require(history.ownerScope == profile && history.base.messages.filter { $0.id == serverID && $0.clientMessageID == clientID }.count == 1, "server_turn_binding")
        await model.sessionHistory.loadTimeline(owner.sessionID, window: .tail)
        let timeline = try XCTUnwrap(model.sessionHistory.timelines[owner.sessionID])
        let entry = try XCTUnwrap(timeline.entries.first {
            $0.kind == .conversationDJ && $0.originMessageID == serverID && $0.sessionID == owner.sessionID
        })
        try require(timeline.errorKey == nil, "session_timeline_readback")
        return (history.base.historyRevision, entry.id)
    }

    private func renderGoldenAnswer(_ assistant: DJConnectAskDJMessage, model: DJConnectAppModel) throws {
        try require(assistant.text.utf8.count <= 64_000, "answer_render_bound")
        let bubble = AskDJMessageBubble(message: assistant, language: model.language,
            isStaleHistory: false, isAudioLoading: false, isAudioPlaying: false,
            isRetryDisabled: true, playingActionID: nil, currentMood: assistant.mood,
            isSearchResult: false, isActiveSearchResult: false, searchText: "",
            retryAction: {}, playAction: { _ in }, audioAction: {}, trackInsightAction: {},
            openLink: { _ in }, feedbackAction: { _ in }, setPromptAction: { _ in })
        let renderer = ImageRenderer(content: bubble.frame(width: 600, height: 600, alignment: .top).clipped())
        try require(renderer.cgImage != nil, "native_bubble_render_failed")
    }

}
