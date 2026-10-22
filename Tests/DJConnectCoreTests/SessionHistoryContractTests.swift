import Foundation
import Combine
import Testing
import CryptoKit
import CoreGraphics
import ImageIO
import Combine
@testable import DJConnectCore
@testable import DJConnectUI
#if os(macOS)
import AppKit
import SwiftUI
#endif

@Test @MainActor func sessionHistoryPhysicalTestEndpointRequiresExplicitBoundedLaunch() {
    let host = "192.168.1.134"
    let environment = ["DJCONNECT_UITEST_PHYSICAL_HISTORY_HOST": host]
    let arguments = ["--physical-session-history-test"]
    #expect(DJConnectAppModel.allowsSessionHistoryTestEndpoint("http://127.0.0.1:18191", environment: [:], arguments: []))
    #expect(DJConnectAppModel.allowsSessionHistoryTestEndpoint("http://" + host + ":18192", environment: environment, arguments: arguments))
    for rejected in ["http://" + host + ":8123", "http://" + host + ":18191", "https://" + host + ":18192", "http://example.com:18192", "http://8.8.8.8:18192", "http://user:password@" + host + ":18192"] {
        #expect(!DJConnectAppModel.allowsSessionHistoryTestEndpoint(rejected, environment: environment, arguments: arguments))
    }
    #expect(!DJConnectAppModel.allowsSessionHistoryTestEndpoint("http://" + host + ":18192", environment: [:], arguments: arguments))
    #expect(!DJConnectAppModel.allowsSessionHistoryTestEndpoint("http://" + host + ":18192", environment: environment, arguments: []))
    let spoof = "192.168.1.134.example.com"
    #expect(!DJConnectAppModel.allowsSessionHistoryTestEndpoint("http://" + spoof + ":18192", environment: ["DJCONNECT_UITEST_PHYSICAL_HISTORY_HOST": spoof], arguments: arguments))
}

private func historyFixture(_ name: String = "producer-receipt") throws -> Data {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try Data(contentsOf: root.appendingPathComponent("Fixtures/session-history-" + name + ".json"))
}
private func historyObject(_ name: String = "producer-receipt") throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: historyFixture(name)) as? [String: Any])
}
private func historyData(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value) }

@Test(arguments: ["missing", "wrong_session", "withdrawn", "known"])
@MainActor func artworkSpeakerChoiceUsesScopedConversationAndPreservesDraft(_ state: String) async throws {
    let receipt = try historyObject()
    let sessionID = try #require(receipt["session_id"] as? String)
    let timeline = try historyData(try #require(receipt["archived_timeline"]))
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    var runtime = try #require(JSONSerialization.jsonObject(with: activeMoodRuntimeWire()) as? [String: Any])
    var session = try #require(runtime["session"] as? [String: Any]); session["session_id"] = sessionID
    var broadcast = try #require(session["broadcast"] as? [String: Any])
    var sessionFields = try #require(broadcast["session"] as? [String: Any]); sessionFields["session_id"] = sessionID
    broadcast["session"] = sessionFields; session["broadcast"] = broadcast; runtime["session"] = session
    let runtimeData = try historyData(runtime)
    var answer = try #require(receipt["text_turn"] as? [String: Any])
    let historyBody = try #require(receipt["later_historical_answer"] as? [String: Any])
    answer["history_revision"] = (historyBody["history_revision"] as? Int ?? 0) + 1
    answer["clear_revision"] = historyBody["clear_revision"]
    var conversation = try #require(answer["conversation"] as? [String: Any])
    conversation["context"] = ["session_id": sessionID]
    conversation["entry_ids"] = []
    answer["conversation"] = conversation
    let output: [String: Any] = ["id":"speaker-choice", "title":"Speaker A", "kind":"output", "command":"set_output", "value":["device_id":"speaker-a"]]
    var assistant = try #require(answer["assistant_message"] as? [String: Any]); assistant["playback_actions"] = [output]
    answer["assistant_message"] = assistant; answer["playback_actions"] = [output]
    answer["messages"] = (answer["messages"] as? [[String: Any]] ?? []).map { message in
        var message = message
        if message["role"] as? String == "assistant" { message["playback_actions"] = [output] }
        return message
    }
    let response = try historyData(answer)
    let fixture = HistoryWireFixture { request in
        let path = request.url!.path
        if path.hasSuffix("/capabilities") { return (200, activeMoodCapsWire, 0) }
        if path.hasSuffix("/session/active") { return (200, runtimeData, 0) }
        if path.hasSuffix("/ask_dj/message") { return (200, response, 0) }
        if path.contains("/session/history") { return (200, timeline, 0) }
        return (200, profile, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare(); await model.refreshActiveDJSession()
    model.isConnected = true
    model.askDJDraft = "Keep this unsent draft"
    let selected = DJConnectSessionEntryReference(sessionID: sessionID, entryID: "selected-context")
    model.sessionHistory.selectedEntry = selected
    if state == "withdrawn" { model.sessionHistory.suspend() }
    if state == "known" {
        model.isConnected = true
        model.apply(playback: try JSONDecoder().decode(DJConnectPlayback.self, from: Data(#"{"device":{"id":"speaker-a","name":"Speaker A","active":true},"is_playing":true}"#.utf8)))
    }
    let accepted = model.sessionHistory.requestSessionSpeakerChoice(sessionID: state == "wrong_session" ? "other-session" : sessionID)
    #expect(accepted == (state == "missing"))
    if accepted {
        #expect(!model.sessionHistory.requestSessionSpeakerChoice(sessionID: sessionID))
        let turn = try #require(model.sessionHistory.pendingTurns.first)
        #expect(turn.context.sessionID == sessionID && turn.context.selectedEntry == nil)
        for _ in 0..<100 where model.isSendingAskDJText { try await Task.sleep(for: .milliseconds(20)) }
        let posts = fixture.requests.filter { $0.httpMethod == "POST" && $0.url!.path.hasSuffix("/ask_dj/message") }
        #expect(posts.count == 1)
        let post = try #require(posts.first)
        let body = try #require(JSONSerialization.jsonObject(with: presenceRequestBody(post)) as? [String: Any])
        #expect(body["text"] as? String == DJConnectLocalization.localized(key: "ui.session.playback.speaker_question", language: model.language))
        #expect(model.sessionHistory.responseEpoch == turn.requestEpoch)
        #expect(model.sessionHistory.hasAuthorizedOwner)
        #expect(model.sessionHistory.pendingTurns.isEmpty, "Pending failure: \(model.sessionHistory.pendingTurns.map { $0.failureKey ?? "none" })")
        #expect(model.askDJMessages.contains { $0.playbackActions.contains(where: \.isOutputAction) })
    } else {
        #expect(!fixture.requests.contains { $0.url!.path.hasSuffix("/ask_dj/message") })
    }
    #expect(model.askDJDraft == "Keep this unsent draft")
    #expect(!fixture.requests.contains { $0.httpMethod == "POST" && $0.url!.path.hasSuffix("/command") })
}

@Test(arguments: ["text", "voice", "setting_feedback", "unknown", "", "SETTING_FEEDBACK"])
func sessionTimelineRecognizesOnlyQualifiedConversationInputTypes(_ input: String) throws {
    let receipt = try historyObject()
    var body = try #require(receipt["archived_timeline"] as? [String: Any])
    var rows = try #require(body["entries"] as? [[String: Any]])
    var count = 0
    for index in rows.indices where ["conversation_user", "conversation_dj"].contains(rows[index]["kind"] as? String ?? "") {
        rows[index]["input_type"] = input
        count += 1
    }
    #expect(count >= 2)
    body["entries"] = rows
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: historyData(body))
    let valid = ["text", "voice", "setting_feedback"].contains(input)
    #expect(page.entries.allSatisfy(\.isContractValid) == valid)
    #expect(page.entries.count == rows.count)
}

/// Optional local readback; personal response bytes never become a fixture or test output.
@Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_CAPTURED_TIMELINE_FILE"] != nil))
func sessionTimelineValidatesPrivateCapturedReadback() throws {
    let path = try #require(ProcessInfo.processInfo.environment["DJCONNECT_CAPTURED_TIMELINE_FILE"])
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    #expect(page.success && page.session.isContractValid)
    #expect(page.entries.count <= 50)
    #expect(page.entries.allSatisfy { $0.sessionID == page.session.id && $0.isContractValid })
}

@Test func askDJAnswerContextUsesRetainedServerIdentityOnly() throws {
    let receipt = try historyObject()
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self,
        from: historyData(try #require(receipt["archived_timeline"])))
    let answer = try #require(page.entries.first { $0.kind == .conversationDJ })
    let now = try #require(DJConnectHistoryEntry.date(answer.occurredAt)).addingTimeInterval(1)
    var message = DJConnectAskDJMessage(serverID: answer.originMessageID, role: .dj, text: answer.text ?? "")
    #expect(DJConnectSessionHistoryModel.contextEntry(for: message, entries: page.entries, at: now)?.reference == answer.reference)
    // The same entry can be present in both a timeline and historical matches.
    #expect(DJConnectSessionHistoryModel.contextEntry(for: message, entries: [answer, answer], at: now)?.reference == answer.reference)
    let expired = try #require(DJConnectHistoryEntry.date(answer.retainedUntil))
    #expect(DJConnectSessionHistoryModel.contextEntry(for: message, entries: page.entries, at: expired) == nil)
    message.serverID = "unconfirmed-answer"
    #expect(DJConnectSessionHistoryModel.contextEntry(for: message, entries: page.entries, at: now) == nil)
    message.serverID = answer.originMessageID
    message.role = .user
    #expect(DJConnectSessionHistoryModel.contextEntry(for: message, entries: page.entries, at: now) == nil)
    message.role = .dj
    message.messageKind = .system
    #expect(DJConnectSessionHistoryModel.contextEntry(for: message, entries: page.entries, at: now) == nil)
}

@Test func sessionHistoryPinnedProducerBytesAndConfirmedOrder() throws {
    #expect(SHA256.hash(data: try historyFixture()).map { String(format: "%02x", $0) }.joined() == "d4b901aa3d6ec7d7e93767c2efc538dddc5f92dc2e3cbaa9213e03b0da471f93")
    let receipt = try historyObject()
    let timeline = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: historyData(try #require(receipt["archived_timeline"])))
    #expect(timeline.schemaVersion == 1 && timeline.session.readOnly)
    #expect(timeline.entries.map(\.order) == [1, 2, 3, 4, 5, 6])
    #expect(timeline.entries.allSatisfy { $0.isContractValid })
    let voice = try JSONDecoder().decode(DJConnectSessionConversationResponse.self, from: historyData(try #require(receipt["voice_derived_turn"])))
    #expect(voice.conversation.inputType == "voice")
    #expect(voice.conversation.entryIDs == Array(timeline.entries.suffix(2)).map(\.id))
    #expect(voice.conversation.context.selectedEntry?.entryID == timeline.entries[1].id)
    #expect(voice.ownerScope == "profile-a")
    let later = try JSONDecoder().decode(DJConnectSessionConversationResponse.self, from: historyData(try #require(receipt["later_historical_answer"])))
    #expect(later.conversation.context.sessionID == nil)
    #expect(later.historicalMatches.first?.playback?.artist == "Metallica")
    #expect(later.historicalMatches.first?.openAction?.reference == timeline.entries[0].reference)
}

@Test func sessionHistoryPinnedWindowIsNotFullTimelineCoverage() throws {
    #expect(SHA256.hash(data: try historyFixture("window-producer-receipt")).map { String(format: "%02x", $0) }.joined() == "93b7c9ee23b396605e0b3c671d06884cff42a0cc814993e3fbff22612d07e74f")
    let receipt = try historyObject("window-producer-receipt")
    let tail = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: historyData(try #require(receipt["tail_window"])))
    #expect(tail.entries.map(\.order) == [24, 25, 26])
    #expect(tail.window == "tail" && tail.nextCursor == nil && tail.scanComplete == false)
    let anchor = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: historyData(try #require(receipt["anchor_window"])))
    #expect(anchor.entries.first?.id == anchor.anchorEntryID)
    #expect(anchor.entries.map(\.order) == [11, 12, 13])
}

@Test func sessionHistoryUTF16RangesNeverSplitUnicodeClustersOrOverflow() {
    let text = "🎧 e\u{301} 👩‍👩‍👧‍👦 Straße"
    #expect(DJConnectHistoryHighlight(startUTF16: 0, lengthUTF16: 2).safeRange(in: text) != nil)
    #expect(DJConnectHistoryHighlight(startUTF16: 1, lengthUTF16: 1).safeRange(in: text) == nil)
    #expect(DJConnectHistoryHighlight(startUTF16: 3, lengthUTF16: 1).safeRange(in: text) == nil)
    #expect(DJConnectHistoryHighlight(startUTF16: 3, lengthUTF16: 2).safeRange(in: text) != nil)
    #expect(DJConnectHistoryHighlight(startUTF16: 6, lengthUTF16: 2).safeRange(in: text) == nil)
    #expect(DJConnectHistoryHighlight(startUTF16: -1, lengthUTF16: 3).safeRange(in: text) == nil)
    #expect(DJConnectHistoryHighlight(startUTF16: Int.max, lengthUTF16: Int.max).safeRange(in: text) == nil)
}

private final class HistoryWireFixture: @unchecked Sendable {
    let hostname = "history-" + UUID().uuidString.lowercased() + ".test"
    var baseURL: URL { URL(string: "http://" + hostname + ":8123")! }
    private let lock = NSLock()
    private var captured: [URLRequest] = []
    let cacheControl: String
    let reply: @Sendable (URLRequest) throws -> (Int, Data, TimeInterval)
    init(cacheControl: String = "no-store", reply: @escaping @Sendable (URLRequest) throws -> (Int, Data, TimeInterval)) {
        self.cacheControl = cacheControl; self.reply = reply; HistoryWireProtocol.register(self)
    }
    func close() { HistoryWireProtocol.unregister(hostname) }
    func record(_ request: URLRequest) { lock.withLock { captured.append(request) } }
    var requests: [URLRequest] { lock.withLock { captured } }
    func client(historyContractVersion: Int = 1) -> DJConnectClient {
        DJConnectClient(baseURL: baseURL, identity: .init(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Test", clientType: .ios, firmware: "4.0.0-rc.1", platform: .ios),
                        tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-fixture-token"), session: session(), historyContractVersion: historyContractVersion)
    }
    func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [HistoryWireProtocol.self]
        return URLSession(configuration: config)
    }
    @MainActor func model(remoteURL: URL? = nil) -> (DJConnectAppModel, UserDefaults, String) {
        let name = "session-history-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.set(baseURL.absoluteString, forKey: "DJConnectHomeAssistantURL")
        defaults.set(baseURL.absoluteString, forKey: "DJConnectHALocalURL")
        defaults.set("local", forKey: "DJConnectHAConnectionMode")
        if let remoteURL { defaults.set(remoteURL.absoluteString, forKey: "DJConnectHARemoteURL") }
        return (DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-fixture-token"),
                                 urlSession: session(), startBackgroundTasks: false), defaults, name)
    }
}

private struct HistoryWireDelayedFailure: Error {
    let error: URLError
    let delay: TimeInterval
}
private final class HistoryComposerOfflineSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var callback: (@Sendable () -> Void)?
    func install(_ action: @escaping @Sendable () -> Void) { lock.withLock { callback = action } }
    func signal() { lock.withLock { callback }?() }
}

private final class HistoryWireResponseGate: @unchecked Sendable {
    private let lock = NSLock()
    private var released = false
    private var deliveries: [@Sendable () -> Void] = []
    func hold(_ delivery: @escaping @Sendable () -> Void) {
        let deliverNow = lock.withLock {
            if released { return true }
            deliveries.append(delivery); return false
        }
        if deliverNow { delivery() }
    }
    func release() {
        let pending = lock.withLock {
            released = true
            let pending = deliveries; deliveries = []; return pending
        }
        pending.forEach { $0() }
    }
}
private struct HistoryWireHeldResponse: Error {
    let data: Data
    let gate: HistoryWireResponseGate
}

private final class HistoryWireProtocol: URLProtocol, @unchecked Sendable {
    private static let registryLock = NSLock()
    nonisolated(unsafe) private static var fixtures: [String: HistoryWireFixture] = [:]
    private let stateLock = NSLock()
    private var stopped = false
    static func register(_ fixture: HistoryWireFixture) { registryLock.withLock { fixtures[fixture.hostname] = fixture } }
    static func unregister(_ host: String) { _ = registryLock.withLock { fixtures.removeValue(forKey: host) } }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host?.hasPrefix("history-") == true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let host = request.url?.host, let fixture = Self.registryLock.withLock({ Self.fixtures[host] }) else { return }
        fixture.record(request)
        do {
            let (status, data, delay) = try fixture.reply(request)
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [self] in
                guard !stateLock.withLock({ stopped }), let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                    headerFields: ["Content-Type": "application/json", "Cache-Control": fixture.cacheControl]) else { return }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
            }
        } catch let held as HistoryWireHeldResponse {
            held.gate.hold { [self] in
                guard !stateLock.withLock({ stopped }), let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                    httpVersion: nil, headerFields: ["Content-Type": "application/json", "Cache-Control": "no-store"]) else { return }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: held.data); client?.urlProtocolDidFinishLoading(self)
            }
        } catch let error as HistoryWireDelayedFailure {
            DispatchQueue.global().asyncAfter(deadline: .now() + error.delay) { [self] in
                guard !stateLock.withLock({ stopped }) else { return }
                client?.urlProtocol(self, didFailWithError: error.error)
            }
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { stateLock.withLock { stopped = true } }
}

@Test func sessionHistoryAuthenticatedNoStoreReadAndValidatedNavigation() async throws {
    let receipt = try historyObject()
    let timeline = try historyData(try #require(receipt["archived_timeline"]))
    let opened = try historyData(try #require(receipt["validated_open_target"]))
    let fixture = HistoryWireFixture { request in (200, request.url!.path.hasSuffix("/open") ? opened : timeline, 0) }
    defer { fixture.close() }
    let client = fixture.client()
    let id = try #require(receipt["session_id"] as? String)
    let page = try await client.sessionTimeline(sessionID: id)
    let action = DJConnectSessionOpenAction(reference: page.entries[0].reference)
    let result = try await client.openSavedSession(action)
    #expect(result.navigationOnly && result.readOnly && result.entry.id == action.entryID)
    let request = try #require(fixture.requests.first)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-fixture-token")
    #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    #expect(request.value(forHTTPHeaderField: "Cache-Control") == "no-store")
    #expect(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.contains(.init(name: "client_type", value: "ios")) == true)
    #expect(fixture.requests.allSatisfy { !$0.url!.path.contains("playback") && !$0.url!.path.hasSuffix("/start") })
}

@Test(arguments: ["owner_metadata_narration_v1", "public_artist_narration_v1"])
func sessionHistoryAcceptsCorePublishedNarrationWithoutLosingOtherEntries(basis: String) async throws {
    let receipt = try historyObject()
    var timeline = try #require(receipt["archived_timeline"] as? [String: Any])
    var entries = try #require(timeline["entries"] as? [[String: Any]])
    let index = try #require(entries.firstIndex { $0["kind"] as? String == "dj_moment" })
    entries[index]["archive_basis"] = basis
    timeline["entries"] = entries
    let data = try historyData(timeline)
    let fixture = HistoryWireFixture { _ in (200, data, 0) }
    defer { fixture.close() }
    let page = try await fixture.client().sessionTimeline(sessionID: try #require(receipt["session_id"] as? String))
    #expect(page.entries.count == entries.count)
    #expect(page.entries[index].archiveBasis == basis)
    #expect(page.entries.allSatisfy { $0.isContractValid })
    #expect(page.entries[index].historicalViewOnly == true)
    #expect(page.entries[index].currentDisplayAllowed == false)
    #expect(fixture.requests.first?.value(forHTTPHeaderField: "Cache-Control") == "no-store")
}

@Test func sessionHistoryNarrationStillRequiresKnownBasisAndOwnerHistoryFences() throws {
    let receipt = try historyObject()
    let timeline = try #require(receipt["archived_timeline"] as? [String: Any])
    let entries = try #require(timeline["entries"] as? [[String: Any]])
    var moment = try #require(entries.first { $0["kind"] as? String == "dj_moment" })
    for basis in ["unqualified_future_basis", "", "spotify_owner_local_read_v1"] {
        moment["archive_basis"] = basis
        #expect(try !JSONDecoder().decode(DJConnectHistoryEntry.self, from: historyData(moment)).isContractValid)
    }
    moment["archive_basis"] = "owner_metadata_narration_v1"
    for mutation: [String: Any] in [["historical_view_only": false], ["current_display_allowed": true], ["text": ""]] {
        let invalid = moment.merging(mutation) { _, new in new }
        #expect(try !JSONDecoder().decode(DJConnectHistoryEntry.self, from: historyData(invalid)).isContractValid)
    }
}

@Test func sessionHistoryPinnedCoreNarrationAndReceiptPageLoadsAsOneWindow() async throws {
    let raw = try historyFixture("retention-bases-v2")
    #expect(SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined() == "da5d8674dc49adb1cc0fabcca51d4f8b730d31f1179462160d1f68aa97e19b14")
    let receipt = try historyObject("retention-bases-v2")
    let data = try historyData(try #require(receipt["tail_window"]))
    let fixture = HistoryWireFixture { _ in (200, data, 0) }
    defer { fixture.close() }
    let page = try await fixture.client(historyContractVersion: 2).sessionTimeline(sessionID: "session-basis-contract", window: .tail)
    #expect(page.entries.count == 6)
    #expect(page.entries.allSatisfy { $0.isContractValid })
    #expect(page.entries.map(\.kind) == [.djMoment, .djMoment, .djMoment, .djMoment, .djPublication, .djSilence])
    #expect(page.entries[3].sources?.count == 2)
    #expect(page.entries[3].sources?.first?["revision_url"] == "https://en.wikipedia.org/w/index.php?oldid=1")
    for entry in page.entries.suffix(2) {
        #expect(entry.text == nil && entry.sessionSpeech == nil && entry.sessionMedia == nil && entry.speechAvailable == false)
    }
}

@Test @MainActor func sessionHistoryWithdrawalReplacesAcceptedTextWithSameIdentityReceipt() throws {
    let receipt = try historyObject("retention-bases-v2")
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: historyData(try #require(receipt["tail_window"])))
    let withdrawn = try JSONDecoder().decode(DJConnectHistoryEntry.self, from: historyData(try #require(receipt["withdrawn_same_identity"])))
    let original = try #require(page.entries.first { $0.id == withdrawn.id })
    #expect(original.text?.isEmpty == false && original.kind == .djMoment)
    #expect(withdrawn.order == original.order && withdrawn.isContractValid && withdrawn.isPublicationReceipt)
    let cache = SessionTimelineRenderCache()
    let epoch = UUID()
    _ = cache.snapshot([original], sessionID: original.sessionID, epoch: epoch)
    let replacement = cache.snapshot([withdrawn], sessionID: original.sessionID, epoch: epoch)
    #expect(replacement.count == 1 && replacement[0].id == original.id)
    #expect(replacement[0].entry.text == nil && replacement[0].message.text.isEmpty)
    #expect(replacement[0].entry.sources == nil && replacement[0].entry.sessionSpeech == nil && replacement[0].entry.sessionMedia == nil)
}

@Test func sessionHistoryPublicationReceiptsCannotSmuggleContentOrSpeech() throws {
    let receipt = try historyObject("retention-bases-v2")
    let page = try #require(receipt["tail_window"] as? [String: Any])
    let entries = try #require(page["entries"] as? [[String: Any]])
    for entry in entries.suffix(2) {
        for mutation: [String: Any] in [["text": "Unqualified content"], ["speech_available": true],
                                        ["sources": [["provider": "unqualified"]]], ["historical_view_only": false],
                                        ["current_display_allowed": true], ["content_state": "available"]] {
            let invalid = entry.merging(mutation) { _, new in new }
            #expect(try !JSONDecoder().decode(DJConnectHistoryEntry.self, from: historyData(invalid)).isContractValid)
        }
    }
}

@Test @MainActor func sessionHistoryNegotiationDropsOldCursorsAndRecoversAfterTypedUpgrade() async throws {
    let receipt = try historyObject()
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    var timeline = try #require(receipt["archived_timeline"] as? [String: Any])
    timeline["schema_version"] = 2; timeline["history_contract_version"] = 2
    let version2 = try historyData(timeline)
    let upgrade = try historyData(["success": false, "error": "history_contract_upgrade_required",
        "required_history_contract_version": 2, "supported_history_contract_versions": [1, 2]])
    let gate = HistoryAuthorityGate()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") {
            var versions = ["session_conversation_history": 1, "session_flow_text_search": 1]
            if gate.denied { versions["session_history_entries"] = 2 }
            return (200, try historyData(["capabilities": ["session_conversation_history": true, "session_flow_text_search": true], "contract_versions": versions]), 0)
        }
        if request.url!.path.contains("/session/history/") { return gate.denied ? (200, version2, 0) : (409, upgrade, 0) }
        return (200, profile, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    let id = try #require(receipt["session_id"] as? String)
    await model.sessionHistory.loadTimeline(id)
    #expect(model.sessionHistory.historyNeedsUpgrade)
    #expect(model.pairingStatus == .paired)
    #expect(model.sessionHistory.timelines[id]?.errorKey == "ui.session.history.update_required")
    let attempts = fixture.requests.filter { $0.url!.path.contains("/session/history/") }.count
    await model.sessionHistory.loadTimeline(id)
    #expect(fixture.requests.filter { $0.url!.path.contains("/session/history/") }.count == attempts)
    gate.denied = true
    await model.sessionHistory.prepare()
    #expect(model.sessionHistory.historyContractVersion == 2 && !model.sessionHistory.historyNeedsUpgrade)
    #expect(model.sessionHistory.timelines.isEmpty && model.sessionHistory.listNextCursor == nil)
    await model.sessionHistory.loadTimeline(id)
    #expect(model.sessionHistory.timelines[id]?.errorKey == nil)
    #expect(model.sessionHistory.timelines[id]?.entries.isEmpty == false)
    let request = try #require(fixture.requests.last { $0.url!.path.contains("/session/history/") })
    #expect(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.contains(.init(name: "history_contract_version", value: "2")) == true)
}

@Test func sessionHistoryVersionTwoStaysOnHistoryRoutesAndRequiresExactResponseVersion() async throws {
    let receipt = try historyObject()
    var opened = try #require(receipt["validated_open_target"] as? [String: Any])
    opened["schema_version"] = 2; opened["history_contract_version"] = 2
    let data = try historyData(opened)
    let fixture = HistoryWireFixture { _ in (200, data, 0) }; defer { fixture.close() }
    let client = fixture.client(historyContractVersion: 2)
    for route in ["session/history", "session/history/synthetic", "session/history/synthetic/search"] {
        let request = try client.sessionHistoryReadRequest(route: route)
        #expect(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.contains(.init(name: "history_contract_version", value: "2")) == true)
    }
    for route in ["capabilities", "ask_dj/history"] {
        let request = try client.sessionHistoryReadRequest(route: route)
        #expect(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.contains { $0.name == "history_contract_version" } == false)
    }
    let response = try JSONDecoder().decode(DJConnectSessionOpenResponse.self, from: data)
    _ = try await client.openSavedSession(.init(reference: response.entry.reference))
    let request = try #require(fixture.requests.last)
    let requestBody = try presenceRequestBody(request)
    let payload = try #require(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
    #expect(payload["history_contract_version"] as? Int == 2)
    await #expect(throws: DJConnectError.invalidResponse) {
        try await fixture.client().openSavedSession(.init(reference: response.entry.reference))
    }
}

@Test func sessionHistoryVoiceUsesWavAndCapturedServerContext() async throws {
    let receipt = try historyObject()
    let responseData = try historyData(try #require(receipt["voice_derived_turn"]))
    let decoded = try JSONDecoder().decode(DJConnectSessionConversationResponse.self, from: responseData)
    let fixture = HistoryWireFixture { _ in (200, responseData, 0) }; defer { fixture.close() }
    let wav = Data([82, 73, 70, 70, 0, 0, 0, 0])
    _ = try await fixture.client().sendSessionVoice(wavData: wav, context: decoded.conversation.context, clientMessageID: "question-1", language: "nl")
    let request = try #require(fixture.requests.first)
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "audio/wav")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Conversation-Scope") == "profile")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Entry-ID") == decoded.conversation.context.selectedEntry?.entryID)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Session-ID") == decoded.conversation.context.sessionID)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-Message-ID") == "question-1")
    // Header/decoder acceptance only: these bytes are not a microphone/STT proof.
}

@Test @MainActor func sessionHistoryScopeClearsLegacyDiskCacheAndWithdrawnMessages() async throws {
    let data = try historyData(try #require(historyObject()["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in (200, request.url!.path.hasSuffix("/capabilities") ? caps : data, 0) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(Data("old private cache".utf8), forKey: "DJConnectAskDJMessages")
    await model.sessionHistory.prepare()
    #expect(model.sessionHistory.available && model.sessionHistory.profileScopeActive)
    #expect(defaults.data(forKey: "DJConnectAskDJMessages") == nil)
    #expect(model.askDJMessages.count == 2)
    let current = model.askDJMessages
    let empty = DJConnectAskDJHistoryResponse(success: true, userID: "profile:profile-a", historyRevision: 4, clearRevision: 0, messages: [])
    model.applyProfileConversationHistory(empty)
    #expect(model.askDJMessages.isEmpty)
    let old = DJConnectAskDJHistoryResponse(success: true, userID: "profile:profile-a", historyRevision: 3, clearRevision: 0,
        messages: try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: data).messages)
    #expect(model.applyProfileConversationHistory(old) == false)
    #expect(model.askDJMessages.isEmpty && current.count == 2)
    #expect(defaults.object(forKey: "DJConnectAskDJHistoryRevision") == nil)
}

@Test @MainActor func sessionHistorySearchRejectsStaleQueryAndWrongScopeWithoutMutations() async throws {
    let receipt = try historyObject()
    let timeline = try #require(receipt["archived_timeline"] as? [String: Any])
    let entries = try #require(timeline["entries"] as? [[String: Any]])
    let sessionID = try #require(receipt["session_id"] as? String)
    let history = try historyData(try #require(receipt["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let oldSearch = try historyData(["success":true,"schema_version":1,"session_id":sessionID,"query":"old","revision":"6:0:0",
        "matches":entries,"returned_count":entries.count,"total_count":entries.count,"complete":true,"normalization":"NFKC-casefold","highlight_units":"utf16"])
    let newSearch = try historyData(["success":true,"schema_version":1,"session_id":sessionID,"query":"new","revision":"6:0:0",
        "matches":[],"returned_count":0,"total_count":0,"complete":true,"normalization":"NFKC-casefold","highlight_units":"utf16"])
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/search") {
            let q = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "q" })?.value
            return (200, q == "old" ? oldSearch : newSearch, q == "old" ? 0.6 : 0)
        }
        if request.url!.path.hasSuffix("/open") { return (404, Data(#"{"success":false,"error":"history_unavailable"}"#.utf8), 0) }
        return (200, history, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    model.sessionHistory.search(sessionID: sessionID, query: "old")
    try await Task.sleep(for: .milliseconds(400))
    model.sessionHistory.search(sessionID: sessionID, query: "new")
    try await Task.sleep(for: .seconds(1))
    #expect(model.sessionHistory.acceptedSearchQuery == "new")
    #expect(model.sessionHistory.searchMatches.isEmpty && model.sessionHistory.searchComplete)
    let action = DJConnectSessionOpenAction(reference: .init(sessionID: sessionID, entryID: "withdrawn"))
    await model.sessionHistory.open(action)
    #expect(model.sessionHistory.openTarget == nil && model.sessionHistory.navigationErrorKey != nil)
    #expect(fixture.requests.allSatisfy { !$0.url!.path.contains("playback") && !$0.url!.path.hasSuffix("/start") && !$0.url!.path.hasSuffix("/end") })
}

@Test @MainActor func sessionHistorySearchRejectsOwnerlessReadUntilRequalified() async throws {
    let receipt = try historyObject()
    let timeline = try #require(receipt["archived_timeline"] as? [String: Any])
    let entries = try #require(timeline["entries"] as? [[String: Any]])
    let sessionID = try #require(receipt["session_id"] as? String)
    let history = try historyData(try #require(receipt["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    // Synthetic search envelope reuses the unchanged retained producer entries.
    let search = try historyData(["success":true,"schema_version":1,"session_id":sessionID,"query":"old","revision":"6:0:0",
        "matches":entries,"returned_count":entries.count,"total_count":entries.count,"complete":true,"normalization":"NFKC-casefold","highlight_units":"utf16"])
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/search") { return (200, search, 0) }
        return (200, history, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    model.sessionHistory.search(sessionID: sessionID, query: "old")
    try await Task.sleep(for: .milliseconds(600))
    let admittedIDs = model.sessionHistory.searchMatches.map(\.id)
    try #require(admittedIDs.count == entries.count && model.sessionHistory.searchComplete)
    model.sessionHistory.suspend()
    try #require(!model.sessionHistory.hasAuthorizedOwner && model.sessionHistory.searchMatches.isEmpty)
    let requestCount = fixture.requests.count
    model.sessionHistory.search(sessionID: sessionID, query: "old")
    #expect(!model.sessionHistory.searchLoading)
    try await Task.sleep(for: .milliseconds(600))
    #expect(fixture.requests.count == requestCount)
    #expect(model.sessionHistory.searchMatches.isEmpty)
    #expect(model.sessionHistory.acceptedSearchQuery.isEmpty)
    #expect(!model.sessionHistory.searchLoading)
    await model.sessionHistory.prepare()
    try #require(model.sessionHistory.hasAuthorizedOwner)
    model.sessionHistory.search(sessionID: sessionID, query: "old")
    try await Task.sleep(for: .milliseconds(600))
    #expect(model.sessionHistory.searchMatches.map(\.id) == admittedIDs)
    #expect(model.sessionHistory.searchComplete && !model.sessionHistory.searchLoading)
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
}

@Test @MainActor func sessionHistoryWindowsKeepLoadedCanonicalEntriesAndFindTailBeyondPage() async throws {
    let receipt = try historyObject("window-producer-receipt")
    let first = try historyData(try #require(receipt["first_page"]))
    let tail = try historyData(try #require(receipt["tail_window"]))
    let anchor = try historyData(try #require(receipt["anchor_window"]))
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: first)
    let window = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: anchor)
    let history = try historyData(try #require(historyObject()["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("ask_dj/history") { return (200, history, 0) }
        let mode = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "window" })?.value
        return (200, mode == "tail" ? tail : mode == "anchor" ? anchor : first, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    await model.sessionHistory.loadTimeline(page.session.id)
    let readID = page.entries[10].id
    await model.sessionHistory.loadTimeline(page.session.id, window: .tail, limit: 3)
    #expect(model.sessionHistory.timelines[page.session.id]?.entries.count == 23)
    #expect(model.sessionHistory.timelines[page.session.id]?.entries.last?.order == 26)
    #expect(model.sessionHistory.timelines[page.session.id]?.entries.contains(where: { $0.id == readID }) == true)
    #expect(model.sessionHistory.timelines[page.session.id]?.windowed == true)
    await model.sessionHistory.loadTimeline(page.session.id, window: .anchor, anchorEntryID: window.anchorEntryID, limit: 3)
    #expect(model.sessionHistory.timelines[page.session.id]?.entries.count == 23)
    #expect(model.sessionHistory.timelines[page.session.id]?.entries.map(\.order) == Array(1...20) + [24, 25, 26])
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
}

private final class HistoryReplySequence: @unchecked Sendable {
    private let lock = NSLock()
    private var index = 0
    let values: [Data]
    init(_ values: [Data]) { self.values = values }
    func next() -> Data { lock.withLock { let i = min(index, values.count - 1); index += 1; return values[i] } }
}

@Test @MainActor func sessionHistoryOpenRejectsOwnerlessReadUntilRequalified() async throws {
    let receipt = try historyObject()
    let history = try historyData(try #require(receipt["later_historical_answer"]))
    let opened = try historyData(try #require(receipt["validated_open_target"]))
    let answer = try JSONDecoder().decode(DJConnectSessionConversationResponse.self, from: history)
    let action = try #require(answer.historicalMatches.first?.openAction)
    let target = try JSONDecoder().decode(DJConnectSessionOpenResponse.self, from: opened)
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/open") { return (200, opened, 0) }
        return (200, history, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    let admitted = await model.sessionHistory.open(action)
    try #require(admitted && model.sessionHistory.openTarget == action.reference)
    try #require(model.sessionHistory.timelines[action.sessionID]?.entries.map(\.id) == [target.entry.id])
    model.sessionHistory.suspend()
    try #require(!model.sessionHistory.hasAuthorizedOwner && model.sessionHistory.timelines.isEmpty)
    let requestCount = fixture.requests.count
    let ownerless = await model.sessionHistory.open(action)
    #expect(!ownerless)
    #expect(fixture.requests.count == requestCount)
    #expect(model.sessionHistory.openTarget == nil && model.sessionHistory.timelines.isEmpty)
    await model.sessionHistory.prepare()
    try #require(model.sessionHistory.hasAuthorizedOwner)
    let restored = await model.sessionHistory.open(action)
    #expect(restored && model.sessionHistory.openTarget == action.reference)
    #expect(model.sessionHistory.timelines[action.sessionID]?.entries.map(\.id) == [target.entry.id])
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" || ($0.httpMethod == "POST" && $0.url!.path.hasSuffix("/session/history/open")) })
}

@Test @MainActor func sessionHistoryProfileChangeDiscardsLatePreviouslyAuthorizedOpen() async throws {
    let receipt = try historyObject()
    let original = try historyData(try #require(receipt["later_historical_answer"]))
    let nextProfile = Data(#"{"success":true,"owner_profile_id":"profile-b","user_id":null,"history_revision":0,"clear_revision":0,"messages":[]}"#.utf8)
    let sequence = HistoryReplySequence([original, nextProfile])
    let opened = try historyData(try #require(receipt["validated_open_target"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/open") { return (200, opened, 0.4) }
        return (200, sequence.next(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    let answer = try JSONDecoder().decode(DJConnectSessionConversationResponse.self, from: original)
    let action = try #require(answer.historicalMatches.first?.openAction)
    let pending = Task { await model.sessionHistory.open(action) }
    try await Task.sleep(for: .milliseconds(50))
    await model.sessionHistory.refreshConversation()
    _ = await pending.value
    #expect(model.askDJMessages.isEmpty)
    #expect(model.sessionHistory.openTarget == nil && model.sessionHistory.timelines.isEmpty)
    #expect(model.sessionHistory.historicalMatches.values.allSatisfy { $0.isEmpty })
}

@Test @MainActor func sessionHistoryBackgroundEpochDiscardsInflightPrivateTimeline() async throws {
    let receipt = try historyObject()
    let history = try historyData(try #require(receipt["later_historical_answer"]))
    let timeline = try historyData(try #require(receipt["archived_timeline"]))
    let id = try #require(receipt["session_id"] as? String)
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.contains("session/history") { return (200, timeline, 0.3) }
        return (200, history, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    let pending = Task { await model.sessionHistory.loadTimeline(id) }
    try await Task.sleep(for: .milliseconds(40))
    model.markInactiveSession()
    await pending.value
    #expect(model.sessionHistory.timelines.isEmpty && model.askDJMessages.isEmpty)
    #expect(model.sessionHistory.searchMatches.isEmpty && model.sessionHistory.selectedEntry == nil)
    #expect(defaults.data(forKey: "DJConnectAskDJMessages") == nil)
}

@Test @MainActor func sessionHistoryEmptySearchCancelsBusyState() async throws {
    let receipt = try historyObject()
    let data = try historyData(try #require(receipt["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in (200, request.url!.path.hasSuffix("/capabilities") ? caps : data, 0) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    model.sessionHistory.search(sessionID: "selected", query: "Metallica")
    #expect(model.sessionHistory.searchLoading)
    model.sessionHistory.search(sessionID: "selected", query: " ")
    #expect(!model.sessionHistory.searchLoading && model.sessionHistory.searchMatches.isEmpty)
    try await Task.sleep(for: .milliseconds(400))
    #expect(fixture.requests.allSatisfy { !$0.url!.path.hasSuffix("/search") })
}

@Test @MainActor func sessionHistoryNewerOpenRejectsOlderTimelineResponse() async throws {
    let receipt = try historyObject()
    let timelineData = try historyData(try #require(receipt["archived_timeline"]))
    var opened = try #require(receipt["validated_open_target"] as? [String: Any])
    var entry = try #require(opened["entry"] as? [String: Any]); entry["text"] = "newly validated canonical body"; opened["entry"] = entry
    let openData = try historyData(opened)
    let history = try historyData(try #require(receipt["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/open") { return (200, openData, 0) }
        if request.url!.path.contains("/session/history/") { return (200, timelineData, 0.4) }
        return (200, history, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    let action = try JSONDecoder().decode(DJConnectSessionOpenResponse.self, from: openData).entry.openAction
        ?? DJConnectSessionOpenAction(reference: try JSONDecoder().decode(DJConnectSessionOpenResponse.self, from: openData).entry.reference)
    let pending = Task { await model.sessionHistory.loadTimeline(action.sessionID) }
    try await Task.sleep(for: .milliseconds(50))
    #expect(await model.sessionHistory.open(action))
    await pending.value
    #expect(model.sessionHistory.timelines[action.sessionID]?.entries.first?.text == "newly validated canonical body")
    #expect(model.sessionHistory.timelines[action.sessionID]?.loading == false)
}

@Test func sessionHistoryArchiveCannotGrantCurrentPresentation() throws {
    var receipt = try historyObject()
    var timeline = try #require(receipt["archived_timeline"] as? [String: Any])
    var entries = try #require(timeline["entries"] as? [[String: Any]])
    entries[0]["current_display_allowed"] = true
    timeline["entries"] = entries; receipt["archived_timeline"] = timeline
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: historyData(timeline))
    #expect(!page.entries[0].isContractValid)
}

@Test @MainActor func sessionHistoryOldVoiceFailureCannotCancelNewCapture() async throws {
    let receipt = try historyObject()
    let history = try historyData(try #require(receipt["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let speechRoot = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/device-speech-core-604b80f8.json"))) as? [String: Any])
    let speechCases = try #require(speechRoot["cases"] as? [[String: Any]])
    let speech = try historyData(["success": true, "ha_install_id": "speech-install", "device_speech": try #require(speechCases.first { $0["case"] as? String == "configuration_stt_True_tts_True" }?["snapshot"])])
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/status") { return (200, speech, 0) }
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/voice") { return (500, Data(#"{"success":false,"error":"voice_failed"}"#.utf8), 0.4) }
        return (200, history, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    defaults.set("speech-install", forKey: "DJConnectHAInstallID")
    model.language = "en"
    await model.sessionHistory.prepare()
    model.sessionHistory.captureVoiceContext()
    let operation = model.voiceOperationID
    let epoch = model.sessionHistory.responseEpoch
    // Synthetic WAV transport only, never microphone/STT acceptance.
    let oldUpload = Task { await model.uploadRecordedVoiceWAV(Data([82,73,70,70]), operation: operation, historyEpoch: epoch) }
    try await Task.sleep(for: .milliseconds(50))
    #expect(model.voiceStatus == .processing && !model.isRecordingVoice)
    model.markInactiveSession()
    #expect(model.voiceStatus == .idle)
    model.sessionHistory.captureVoiceContext()
    let newOperation = model.voiceOperationID
    let newStatus = model.voiceStatus
    await oldUpload.value
    #expect(model.voiceOperationID == newOperation && model.voiceStatus == newStatus)
    #expect(model.voiceErrorMessage == nil)
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/voice") }.count == 1)
    #expect(model.askDJMessages.isEmpty)
}

@Test @MainActor func sessionHistoryProfileQuestionsRemainAvailableWithoutPlaybackBackend() async throws {
    let receipt = try historyObject()
    let history = try historyData(try #require(receipt["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in (200, request.url!.path.hasSuffix("/capabilities") ? caps : history, 0) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    model.apply(error: .backendUnavailable(message: "No playback provider"))
    #expect(!model.canUsePlaybackFeatures)
    #expect(model.canUseProfileConversation && model.canUseAskDJFeatures)
    #expect(model.activeDJSession == nil)
    model.markInactiveSession()
    #expect(!model.canUseProfileConversation)
}

@Test func sessionHistoryWebSocketCapabilitiesAcceptActualOperationMapsAndLegacyArrays() throws {
    let actual = try JSONDecoder().decode(DJConnectWebSocketFallback.self, from: Data(#"{"http_paths":{"history":"/api/djconnect/v1/ask_dj/history","clear":"/api/djconnect/v1/ask_dj/history/clear"}}"#.utf8))
    #expect(actual.hasHTTPPath)
    #expect(actual.httpPaths == ["/api/djconnect/v1/ask_dj/history/clear", "/api/djconnect/v1/ask_dj/history"])
    let legacy = try JSONDecoder().decode(DJConnectWebSocketFallback.self, from: Data(#"{"http_paths":["/api/djconnect/v1/music_dna/profile"]}"#.utf8))
    #expect(legacy.hasHTTPPath)
    let empty = try JSONDecoder().decode(DJConnectWebSocketFallback.self, from: Data(#"{"http_paths":{"history":""}}"#.utf8))
    #expect(!empty.hasHTTPPath)
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(DJConnectWebSocketFallback.self, from: Data(#"{"http_paths":{"history":true}}"#.utf8))
    }
}

@Test func sessionHistoryWebSocketRequestEncodesProfileScope() throws {
    let identity = DJConnectIdentity(clientName: "Contract iPhone", deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Contract iPhone", clientType: .ios, firmware: "3.4.0", appVersion: "4.0.0", protocolVersion: "3.4.0", platform: .ios)
    let message = DJConnectWebSocketProfileHistoryMessage(id: 17, identity: DJConnectAPIIdentity(identity: identity, deviceToken: "synthetic-fixture-token"))
    let data = try JSONEncoder().encode(message)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect((object["payload"] as? [String: String])?["conversation_scope"] == "profile")
    #expect(object["type"] as? String == "djconnect/ask_dj/history")
    #expect((object["identity"] as? [String: Any])?["device_id"] as? String == identity.deviceID)
}

@Test func sessionHistoryPrivateWebSocketFailureNeverExportsConversationText() async throws {
    let transport = DJConnectHomeAssistantWebSocketFastPath(baseURL: URL(string: "http://127.0.0.1:18191")!, homeAssistantAuth: DJConnectHomeAssistantWebSocketAuth { nil })
    let privateText = "private-question-7d94f60b"
    let wire = Data(("{\"error\":{\"code\":\"invalid_context\",\"message\":\"" + privateText + "\"}}").utf8)
    let envelope = try #require(JSONSerialization.jsonObject(with: wire) as? [String: Any])
    let error = try #require(envelope["error"] as? [String: String])
    let safe = await transport.recordTransportFailure(DJConnectError.server(statusCode: 200, message: error["message"]), privateResponse: true)
    let diagnostics = await transport.diagnostics
    #expect(diagnostics.lastWebSocketError == "Scoped Profile history request failed")
    #expect(!String(describing: safe).contains(privateText))
    #expect(!String(describing: diagnostics).contains(privateText))
    #expect(safe as? DJConnectError == .server(statusCode: 200, message: nil))
    let cancelled = await transport.recordTransportFailure(CancellationError(), privateResponse: true)
    #expect(cancelled is CancellationError)
}

@Test func sessionHistoryCorrectiveHTTPProducerUsesStrictProfileNamespace() async throws {
    let bytes = try historyFixture("http-scope-fix-producer-receipt")
    #expect(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() == "2462f35a06413716e41734be7fd03ac9181e717c857877765e1493a5148537bc")
    let receipt = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    let requests = try #require(receipt["requests"] as? [[String: Any]])
    let profileRead = try #require(requests.first { r in
        r["path"] as? String == "/api/djconnect/v1/ask_dj/history" && r["status"] as? Int == 200 &&
        (r["query"] as? [String: Any])?["conversation_scope"] as? String == "profile"
    })
    let body = try historyData(try #require(profileRead["body"]))
    let fixture = HistoryWireFixture { _ in (200, body, 0) }; defer { fixture.close() }
    let decoded = try await fixture.client().profileConversationHistory()
    #expect(decoded.ownerScope == "profile-a" && decoded.base.userID == nil)
    #expect(decoded.base.messages.count == 2)
    let responseBody = try #require(profileRead["body"] as? [String: Any])
    #expect(decoded.base.historyLimit == responseBody["history_limit"] as? Int)
    let wire = try #require(fixture.requests.first)
    #expect(URLComponents(url: wire.url!, resolvingAgainstBaseURL: false)?.queryItems?.contains(.init(name: "conversation_scope", value: "profile")) == true)
    let legacy = try #require(requests.first { r in
        r["path"] as? String == "/api/djconnect/v1/ask_dj/history" && r["status"] as? Int == 200 &&
        (r["query"] as? [String: Any])?["conversation_scope"] == nil
    })
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(DJConnectProfileConversationHistory.self, from: historyData(try #require(legacy["body"])))
    }
}

private final class HistoryAuthorityGate: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var denied: Bool { get { lock.withLock { value } } set { lock.withLock { value = newValue } } }
}

@Test(arguments: ["refresh", "list", "timeline", "search", "open", "fetch", "send", "voice", "clear"])
@MainActor func sessionHistoryProfileFailureWithdrawsAllPrivateStateAndRecovers(_ operation: String) async throws {
    let receipt = try historyObject()
    let timelineObject = try #require(receipt["archived_timeline"] as? [String: Any])
    let timeline = try historyData(timelineObject)
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: timeline)
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    let sessions = try historyData(["success": true, "schema_version": 1, "sessions": [try #require(timelineObject["session"])],
        "revision": try #require(timelineObject["revision"]), "retention_days": 30])
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    var tail = timelineObject
    tail["window"] = "tail"; tail["window_limit"] = 20
    tail["scan_complete"] = true; tail["next_cursor"] = NSNull()
    tail["scanned_order_min"] = page.entries.map(\.order).min()
    tail["scanned_order_max"] = page.entries.map(\.order).max()
    let tailData = try historyData(tail)
    let gate = HistoryAuthorityGate()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if gate.denied { return (403, Data(#"{"success":false,"error":"invalid_profile","message":"Private denied detail"}"#.utf8), 0) }
        if request.url!.path.hasSuffix("ask_dj/history") { return (200, profile, 0) }
        if request.url!.path.hasSuffix("/session/history") { return (200, sessions, 0) }
        if URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == "window" && $0.value == "tail" }) == true {
            return (200, tailData, 0)
        }
        return (200, timeline, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    await model.sessionHistory.loadSessions()
    await model.sessionHistory.loadTimeline(page.session.id)
    #expect(model.sessionHistory.hasAuthorizedOwner)
    #expect(!model.sessionHistory.timelines.isEmpty && !model.sessionHistory.sessions.isEmpty)
    model.sessionHistory.selectedEntry = page.entries[0].reference
    gate.denied = true
    switch operation {
    case "refresh": await model.sessionHistory.refreshConversation()
    case "list": await model.sessionHistory.loadSessions()
    case "timeline": await model.sessionHistory.loadTimeline(page.session.id)
    case "search": model.sessionHistory.search(sessionID: page.session.id, query: "One"); try await Task.sleep(for: .milliseconds(500))
    case "open": _ = await model.sessionHistory.open(.init(reference: page.entries[0].reference))
    case "fetch": _ = try? await model.sessionHistory.fetchExistingHistory()
    case "send": _ = try? await model.sessionHistory.sendExistingText("Question", clientMessageID: "authority-test")
    case "voice": model.sessionHistory.captureVoiceContext(); try? await model.sessionHistory.uploadVoice(Data([82, 73, 70, 70]))
    default: try? await model.sessionHistory.clearExistingHistory()
    }
    #expect(!model.sessionHistory.hasAuthorizedOwner)
    #expect(model.sessionHistory.timelines.isEmpty && model.sessionHistory.sessions.isEmpty)
    #expect(model.sessionHistory.searchMatches.isEmpty && model.sessionHistory.historicalMatches.isEmpty)
    #expect(model.sessionHistory.selectedEntry == nil && model.sessionHistory.openTarget == nil)
    #expect(model.askDJMessages.isEmpty && !model.canUseProfileConversation)
    gate.denied = false
    await model.sessionHistory.restoreVisibleSessions()
    #expect(model.sessionHistory.hasAuthorizedOwner && !model.sessionHistory.sessions.isEmpty)
    await model.sessionHistory.restoreVisibleTimeline(page.session.id, active: false, anchor: nil)
    #expect(model.sessionHistory.timelines[page.session.id]?.entries.count == page.entries.count)
    #expect(fixture.requests.last?.url?.query?.contains("window=tail") == true)
}

@Test @MainActor func sessionHistoryQueuedTurnCannotSendAfterSynchronousBackground() async throws {
    let profile = try historyData(try #require(historyObject()["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in (200, request.url!.path.hasSuffix("/capabilities") ? caps : profile, 0) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    model.askDJDraft = "Must never leave this client after background"
    model.sessionHistory.sendText()
    #expect(model.sessionHistory.pendingTurns.count == 1)
    model.markInactiveSession()
    try await Task.sleep(for: .milliseconds(100))
    #expect(fixture.requests.allSatisfy { $0.httpMethod != "POST" })
    #expect(model.sessionHistory.pendingTurns.isEmpty && model.askDJMessages.isEmpty)
    #expect(!model.sessionHistory.hasAuthorizedOwner && !model.isSendingAskDJText)
    model.markActiveSession()
    await model.sessionHistory.prepare()
    #expect(model.sessionHistory.hasAuthorizedOwner)
}

@Test @MainActor func pairedProfileRecoveryCannotReadSessionAfterBackgroundDuringPreparation() async throws {
    let profile = try historyData(try #require(historyObject()["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        (200, request.url!.path.hasSuffix("/capabilities") ? caps : profile,
         request.url!.path.hasSuffix("/capabilities") ? 0.2 : 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    let recovery = Task { await model.recoverAfterPairedAuthorityWithdrawal("profile_changed") }
    for _ in 0..<100 where fixture.requests.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
    #expect(fixture.requests.contains { $0.url!.path.hasSuffix("/capabilities") })
    model.markInactiveSession()
    await recovery.value
    await model.refreshActiveDJSession()
    #expect(fixture.requests.allSatisfy { $0.url!.path.hasSuffix("/capabilities") })
    #expect(!model.sessionHistory.hasAuthorizedOwner && !model.sessionHistory.profileScopeActive)
    #expect(model.activeDJSession == nil && model.askDJMessages.isEmpty)
}

@Test @MainActor func pairedProfileRecoveryClearsPendingSendingAndIgnoresOldReply() async throws {
    let receipt = try historyObject()
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    let response = try historyData(try #require(receipt["voice_derived_turn"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.httpMethod == "POST" { return (200, response, 0.3) }
        if request.url!.path.hasSuffix("/session/active") { return (200, Data(#"{"success":true,"session":null}"#.utf8), 0) }
        return (200, profile, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    model.askDJDraft = "Pending old-owner question"
    model.sessionHistory.sendText()
    for _ in 0..<100 where !fixture.requests.contains(where: { $0.httpMethod == "POST" }) {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(model.isSendingAskDJText && fixture.requests.contains { $0.httpMethod == "POST" })
    let oldEpoch = model.sessionHistory.responseEpoch
    let recovery = Task { await model.recoverAfterPairedAuthorityWithdrawal("profile_changed") }
    for _ in 0..<100 where model.sessionHistory.responseEpoch == oldEpoch || !model.sessionHistory.hasAuthorizedOwner {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(model.sessionHistory.hasAuthorizedOwner && !model.isSendingAskDJText)
    #expect(model.sessionHistory.responseEpoch != oldEpoch && model.sessionHistory.pendingTurns.isEmpty)
    recovery.cancel()
    await recovery.value
    let recoveredMessages = model.askDJMessages.map(\.id)
    try await Task.sleep(for: .milliseconds(400))
    #expect(model.askDJMessages.map(\.id) == recoveredMessages)
    #expect(!model.isSendingAskDJText && model.sessionHistory.pendingTurns.isEmpty)
}

@Test @MainActor func sessionHistoryReadingAnchorsRemainPresentationOnlyAndClearWithAuthority() async throws {
    let profile = try historyData(try #require(historyObject()["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in (200, request.url!.path.hasSuffix("/capabilities") ? caps : profile, 0) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    let count = fixture.requests.count
    model.sessionHistory.rememberReadingAnchor("entry-a", sessionID: "session-a")
    model.sessionHistory.rememberReadingAnchor("entry-b", sessionID: "session-b")
    model.sessionHistory.rememberReadingAnchor("pending-unconfirmed", sessionID: "session-a")
    #expect(model.sessionHistory.readingAnchor(sessionID: "session-a") == "entry-a")
    #expect(model.sessionHistory.readingAnchor(sessionID: "session-b") == "entry-b")
    #expect(fixture.requests.count == count)
    model.sessionHistory.suspend()
    await model.sessionHistory.prepare()
    #expect(model.sessionHistory.readingAnchor(sessionID: "session-a") == nil)
    model.sessionHistory.rememberReadingAnchor("entry-a", sessionID: "session-a")
    model.sessionHistory.reset()
    await model.sessionHistory.prepare()
    #expect(model.sessionHistory.readingAnchor(sessionID: "session-a") == nil)
}

@Test @MainActor func sessionHistoryQueuedTurnOfflineBeforeDispatchFailsAndCanRetry() async throws {
    let profile = try historyData(try #require(historyObject()["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in (200, request.url!.path.hasSuffix("/capabilities") ? caps : profile, 0) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    let selected = DJConnectSessionEntryReference(sessionID: "session-a", entryID: "entry-a")
    model.sessionHistory.selectedEntry = selected
    model.askDJDraft = "  "
    model.sessionHistory.sendText()
    #expect(model.sessionHistory.selectedEntry == selected)
    model.askDJDraft = "Queued before connection loss"
    model.sessionHistory.sendText()
    #expect(model.sessionHistory.selectedEntry == nil)
    #expect(model.sessionHistory.pendingTurns.first?.context.selectedEntry == selected)
    model.recordConnectionMode(.offline, baseURL: fixture.baseURL)
    try await Task.sleep(for: .milliseconds(100))
    #expect(fixture.requests.allSatisfy { $0.httpMethod != "POST" })
    #expect(!model.isSendingAskDJText && model.sessionHistory.hasAuthorizedOwner)
    let turn = try #require(model.sessionHistory.pendingTurns.first)
    #expect(turn.failed && !turn.contextChanged)
    model.recordConnectionMode(.local, baseURL: fixture.baseURL)
    model.sessionHistory.retry(turn)
    #expect(model.sessionHistory.pendingTurns.first?.context.selectedEntry == selected)
    #expect(model.sessionHistory.selectedEntry == nil)
    model.recordConnectionMode(.offline, baseURL: fixture.baseURL)
    try await Task.sleep(for: .milliseconds(100))
    #expect(fixture.requests.allSatisfy { $0.httpMethod != "POST" })
    #expect(!model.isSendingAskDJText && model.sessionHistory.pendingTurns.first?.failed == true)
}

@Test(arguments: ["profile", "network"]) @MainActor
func sessionHistoryActualComposerHandlesFailureAfterTransportGoesOffline(_ failure: String) async throws {
    let receipt = try historyObject()
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    let timeline = try historyData(try #require(receipt["archived_timeline"]))
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: timeline)
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let offlineSignal = HistoryComposerOfflineSignal()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.httpMethod == "POST" && request.url!.path.hasSuffix("/ask_dj/message") {
            offlineSignal.signal()
            if failure == "network" { throw HistoryWireDelayedFailure(error: URLError(.notConnectedToInternet), delay: 0.1) }
            return (403, Data(#"{"success":false,"error":"invalid_profile"}"#.utf8), 0.1)
        }
        return (200, request.url!.path.hasSuffix("/ask_dj/history") ? profile : timeline, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare(); await model.sessionHistory.loadTimeline(page.session.id)
    let baseURL = fixture.baseURL
    offlineSignal.install { [weak model] in
        Task { @MainActor in model?.recordConnectionMode(.offline, baseURL: baseURL) }
    }
    var offlineWhileSending = false
    let connectionObservation = model.$haConnectionMode.sink { mode in
        if mode == .offline && model.isSendingAskDJText { offlineWhileSending = true }
    }
    defer { connectionObservation.cancel() }
    model.askDJDraft = "Actual composer failure"
    model.sessionHistory.sendText()
    #expect(model.isSendingAskDJText && model.sessionHistory.pendingTurns.count == 1)
    for _ in 0..<200 where model.isSendingAskDJText { try await Task.sleep(for: .milliseconds(50)) }
    #expect(fixture.requests.contains(where: { $0.httpMethod == "POST" && $0.url!.path.hasSuffix("/ask_dj/message") }))
    #expect(offlineWhileSending)
    #expect(!model.isSendingAskDJText)
    if failure == "profile" {
        #expect(!model.sessionHistory.hasAuthorizedOwner)
        #expect(model.sessionHistory.timelines.isEmpty && model.sessionHistory.pendingTurns.isEmpty && model.askDJMessages.isEmpty)
    } else {
        #expect(model.sessionHistory.pendingTurns.count == 1 && model.sessionHistory.pendingTurns.first?.failed == true)
    }
}

@Test(arguments: ["502", "503", "decode", "409"]) @MainActor
func conversationFailureUsesAskDJCopyAndPreservesQuestionMetadata(_ failure: String) async throws {
    let receipt = try historyObject()
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    let timeline = try historyData(try #require(receipt["archived_timeline"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.httpMethod == "POST", request.url!.path.hasSuffix("/ask_dj/message") {
            return failure == "decode" ? (200, Data("{}".utf8), 0) : (Int(failure)!, Data(#"{"success":false,"error":"server"}"#.utf8), 0)
        }
        return (200, request.url!.path.hasSuffix("/ask_dj/history") ? profile : timeline, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    model.askDJDraft = "Fixture question"
    model.sessionHistory.sendText()
    let initial = try #require(model.sessionHistory.pendingTurns.first)
    for _ in 0..<100 where model.isSendingAskDJText { try await Task.sleep(for: .milliseconds(20)) }
    let turn = try #require(model.sessionHistory.pendingTurns.first)
    let expected = failure == "409" ? "ui.ask_dj.answer.context_changed" : "ui.ask_dj.answer.unavailable"
    #expect(turn.failed && turn.failureKey == expected)
    #expect(turn.contextChanged == (failure == "409"))
    #expect(model.askDJErrorMessage == DJConnectLocalization.localized(key: expected, language: model.language))
    #expect(turn.id == initial.id && turn.payload == initial.payload)
    let original = try #require(model.askDJMessages.first { $0.id == turn.localMessageID })
    #expect(turn.questionMessage(in: model.askDJMessages) == original)
    var voice = original
    voice.origin = "voice"; voice.text = "Stemverzoek"
    voice.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    #expect(turn.questionMessage(in: [voice]) == voice)
    let fallback = turn.questionMessage(in: [])
    #expect(fallback.id == turn.localMessageID && fallback.createdAt == initial.createdAt)
    #expect(fixture.requests.filter { $0.httpMethod == "POST" && $0.url!.path.hasSuffix("/ask_dj/message") }.count == 1)
}

@Test @MainActor func conversationErrorKeysKeepTransportAndUncertainDeliveryDistinct() {
    #expect(DJConnectSessionHistoryModel.conversationErrorKey(URLError(.timedOut)) == "ui.ask_dj.answer.connection")
    #expect(DJConnectSessionHistoryModel.conversationErrorKey(DJConnectError.network(message: "fixture")) == "ui.ask_dj.answer.connection")
    #expect(DJConnectSessionHistoryModel.conversationErrorKey(DJConnectHybridTransportError.deliveryUnknown) == DJConnectHybridTransportError.deliveryUnknown.localizationKey)
}

@Test @MainActor func sessionHistoryPeriodicReadCannotSupersedeExplicitOpen() async throws {
    let receipt = try historyObject()
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    let timeline = try historyData(try #require(receipt["archived_timeline"]))
    let opened = try historyData(try #require(receipt["validated_open_target"]))
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: timeline)
    let target = try JSONDecoder().decode(DJConnectSessionOpenResponse.self, from: opened)
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/ask_dj/history") { return (200, profile, 0) }
        if request.url!.path.hasSuffix("/history/open") { return (200, opened, 0.15) }
        return (200, timeline, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare(); await model.sessionHistory.loadTimeline(page.session.id)
    let action = DJConnectSessionOpenAction(reference: target.entry.reference)
    let navigation = Task { await model.sessionHistory.open(action) }
    try await Task.sleep(for: .milliseconds(30))
    let readsBefore = fixture.requests.filter { $0.httpMethod == "GET" && $0.url!.path.contains("/session/history/") }.count
    await model.sessionHistory.refreshVisibleTimeline(page.session.id, anchor: nil)
    #expect(fixture.requests.filter { $0.httpMethod == "GET" && $0.url!.path.contains("/session/history/") }.count == readsBefore)
    #expect(await navigation.value)
    #expect(model.sessionHistory.openTarget == target.entry.reference)
}

@Test func sessionHistoryGeneralReplyWithoutAudioPreservesConfirmedText() throws {
    let receipt = try historyObject("generic-no-audio-response")
    let response = try JSONDecoder().decode(DJConnectSessionConversationResponse.self,
        from: historyData(try #require(receipt["response"])))
    #expect(response.ownerScope == "profile-a")
    #expect(response.conversation.context.sessionID == nil)
    #expect(response.conversation.inputType == "text")
    #expect(response.base.userMessage?.text == "Wat heb ik eerder geluisterd?")
    #expect(response.base.assistantMessage?.text == "Ik zie geen Spotify tracks die het afgelopen uur zijn afgespeeld.")
    #expect(response.historicalMatches.isEmpty)
    #expect(response.base.announcement?.audioResponseEffective == .unavailable)
    #expect(response.base.announcement?.clientReplayAudioURL == nil)
    var announcement = try #require(response.base.announcement)
    announcement.audioURL = URL(string: "https://example.test/response.wav")
    #expect(announcement.clientReplayAudioURL == nil)
    #expect(DJConnectAskDJRequest.AudioResponse(rawValue: "unavailable") == nil)
}

@Test func sessionHistoryServerOnlyAudioOutcomeCannotReplayOnClient() throws {
    var object = try #require(try historyObject("generic-no-audio-response")["response"] as? [String: Any])
    var announcement = try #require(object["announcement"] as? [String: Any])
    announcement["audio_response_effective"] = "server_only"
    announcement["audio_url"] = "https://example.test/response.wav"
    object["announcement"] = announcement
    object["audio_url"] = "https://example.test/top-level.wav"
    let response = try JSONDecoder().decode(DJConnectSessionConversationResponse.self, from: historyData(object))
    #expect(response.base.announcement?.audioResponseEffective == .serverOnly)
    #expect(response.base.announcement?.clientReplayAudioURL == nil)
    #expect(response.base.audioURL == nil)
    #expect(DJConnectAskDJRequest.AudioResponse(rawValue: "server_only") == nil)
    announcement["audio_response_effective"] = "unavailable"
    object["announcement"] = announcement
    let unavailable = try JSONDecoder().decode(DJConnectSessionConversationResponse.self, from: historyData(object))
    #expect(unavailable.base.audioURL == nil)
}

@Test func sessionHistoryNestedAudioDenialWinsOverTopLevelReplayFallback() throws {
    let receipt = try historyObject("generic-no-audio-response")
    for outcome in ["unavailable", "server_only"] {
        var object = try #require(receipt["response"] as? [String: Any])
        var announcement = try #require(object.removeValue(forKey: "announcement") as? [String: Any])
        announcement["audio_response_effective"] = outcome
        announcement["audio_url"] = "https://example.test/nested.wav"
        object["audio_url"] = "https://example.test/top-level.wav"
        var assistant = try #require(object["assistant_message"] as? [String: Any])
        assistant["announcement"] = announcement
        assistant["audio_url"] = "https://example.test/message.wav"
        object["assistant_message"] = assistant
        object["messages"] = [try #require(object["user_message"] as? [String: Any]), assistant]
        let data = try historyData(object)
        let response = try JSONDecoder().decode(DJConnectSessionConversationResponse.self, from: data)
        #expect(response.base.assistantMessage?.audioURL == nil)
        #expect(response.base.messages.filter { $0.role != .user }.allSatisfy { $0.audioURL == nil })
        #expect(response.base.assistantMessage?.announcement?.audioResponseEffective?.rawValue == outcome)
        let command = try JSONDecoder().decode(DJConnectCommandResponse.self, from: data)
        #expect(command.assistantMessage?.audioURL == nil)
        #expect(command.assistantMessage?.announcement?.audioResponseEffective?.rawValue == outcome)
    }
}

@Test @MainActor func sessionHistoryActualProviderErrorPreservesReachableProfileConversation() async throws {
    let history = try historyData(try #require(historyObject()["later_historical_answer"]))
    let backendError = try historyData(try #require(historyObject("backend-unavailable-response")["response"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true},"contract_versions":{"session_conversation_history":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        (200, request.url!.path.hasSuffix("/command") ? backendError : (request.url!.path.hasSuffix("/capabilities") ? caps : history), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    let command = DJConnectCommandPayload(identity: model.identity, command: "refresh")
    do {
        _ = try await model.withHomeAssistantClient { try await $0.sendCommandResponse(command) }
        Issue.record("Expected the actual music-provider error")
    } catch let error as DJConnectError {
        guard case .backendUnavailable = error else { throw error }
        model.apply(error: error)
    }
    try await Task.sleep(for: .milliseconds(100))
    #expect(model.haConnectionMode == .local)
    #expect(!model.backendAvailable && !model.canUsePlaybackFeatures)
    #expect(model.canUseProfileConversation && model.canUseAskDJFeatures)
    #expect(fixture.requests.contains { $0.url!.path.hasSuffix("/command") })
    model.markInactiveSession()
    #expect(!model.canUseProfileConversation)
}

@Test @MainActor func sessionHistoryTestAuthRequiresActualCredential() async throws {
    #expect(DJConnectAppModel.sessionHistoryTestWebSocketAuth(token: nil) == nil)
    #expect(DJConnectAppModel.sessionHistoryTestWebSocketAuth(token: "  ") == nil)
    let auth = try #require(DJConnectAppModel.sessionHistoryTestWebSocketAuth(token: "fixture-issued-credential"))
    #expect(try await auth.accessToken() == "fixture-issued-credential")
}

@Test @MainActor func sessionHistoryServiceFailuresKeepHAReachableAndNeverConfirmConsent() async throws {
    let history = try historyData(try #require(historyObject()["later_historical_answer"]))
    let dnaError = try historyData(try #require(historyObject("music-dna-unavailable-response")["response"]))
    let sttError = try historyData(try #require(historyObject("stt-failed-response")["response"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true},"contract_versions":{"session_conversation_history":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/settings") { return (503, dnaError, 0) }
        if request.url!.path.hasSuffix("/voice") { return (422, sttError, 0) }
        return (200, request.url!.path.hasSuffix("/capabilities") ? caps : history, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    model.showMusicDNAOptInPrompt()
    await model.acceptMusicDNAOptInPrompt()
    #expect(model.isShowingMusicDNAOptInPrompt)
    #expect(!defaults.bool(forKey: "DJConnectMusicDNAOptInPromptSeen"))
    try await Task.sleep(for: .milliseconds(100))
    #expect(model.musicDNAErrorMessage == DJConnectLocalization.localized(key: "ui.music.dna.temporarily_unavailable", language: model.language))
    #expect(model.musicDNAProfileResponse?.enabled != true)
    #expect(!model.isUpdatingMusicDNA && model.haConnectionMode == .local)
    #expect(model.canUseProfileConversation)
    let failedVoice = DJConnectConversationContext(sessionID: nil)
    do {
        _ = try await model.withHomeAssistantClient {
            try await $0.sendSessionVoice(wavData: Data([82,73,70,70]), context: failedVoice, clientMessageID: "failed-stt-attempt", language: "nl")
        }
        Issue.record("The real STT failure must remain a failure")
    } catch let error as DJConnectError {
        guard case .server(statusCode: 422, message: _) = error else { throw error }
    }
    try await Task.sleep(for: .milliseconds(100))
    #expect(model.haConnectionMode == .local && model.canUseProfileConversation)
}

@Test @MainActor func sessionHistoryMissingLiveAuthPreservesSessionAndStopsSpinner() async throws {
    let active = try historyData(try #require(historyObject("active-session-before-auth-failure")["response"]))
    let fixture = HistoryWireFixture { _ in (200, active, 0) }; defer { fixture.close() }
    let name = "session-auth-missing-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    defaults.set(fixture.baseURL.absoluteString, forKey: "DJConnectHomeAssistantURL")
    defaults.set("local", forKey: "DJConnectHAConnectionMode")
    defer { defaults.removePersistentDomain(forName: name) }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-fixture-token"),
        urlSession: fixture.session(), homeAssistantWebSocketAuth: DJConnectHomeAssistantWebSocketAuth { nil }, startBackgroundTasks: false)
    await model.refreshActiveDJSession()
    let sessionID = try #require(model.activeDJSession?.id)
    try await Task.sleep(for: .milliseconds(200))
    #expect(model.activeDJSession?.id == sessionID)
    #expect(model.djSessionLiveUnavailable && !model.djSessionIsRecovering)
    #expect(model.activeDJSession?.broadcast.nativeDelivery == nil)
    await model.retryDJSessionConnection()
    try await Task.sleep(for: .milliseconds(200))
    #expect(model.activeDJSession?.id == sessionID && model.djSessionLiveUnavailable && !model.djSessionIsRecovering)
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/active") }.count == 2)
    #expect(fixture.requests.allSatisfy { !$0.url!.path.hasSuffix("/start") && !$0.url!.path.hasSuffix("/end") })
    model.markInactiveSession()
}


private func pairedCapabilityWire() throws -> Data {
    try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/paired-owner-live-capability-v1.json"))
}

@Test func pairedLiveRejectsOverbroadOrForeignDiscovery() throws {
    let wire = try pairedCapabilityWire()
    let valid = try #require(JSONDecoder().decode(DJConnectPairedOwnerLiveDiscovery.self, from: wire).sessionBroadcast?.pairedOwnerWebsocket)
    let url = try valid.websocketURL(baseURL: URL(string: "https://trusted.invalid/?credential=forbidden#fragment")!, clientType: .ios)
    #expect(url.absoluteString == "wss://trusted.invalid/api/djconnect/v1/session/broadcast/paired")
    #expect(throws: (any Error).self) { try valid.websocketURL(baseURL: URL(string: "https://user:secret@trusted.invalid")!, clientType: .ios) }
    for (key, value) in ["version": 2, "path": "https://foreign.invalid/live", "ha_credentials_issued": true,
                         "audience": "admin", "lease_seconds": 301, "commands": ["homeassistant/services/call"]] as [String: Any] {
        var root = try #require(JSONSerialization.jsonObject(with: wire) as? [String: Any])
        var broadcast = try #require(root["session_broadcast"] as? [String: Any])
        var cap = try #require(broadcast["paired_owner_websocket"] as? [String: Any]); cap[key] = value
        broadcast["paired_owner_websocket"] = cap; root["session_broadcast"] = broadcast
        let denied = try #require(JSONDecoder().decode(DJConnectPairedOwnerLiveDiscovery.self,
            from: JSONSerialization.data(withJSONObject: root)).sessionBroadcast?.pairedOwnerWebsocket)
        #expect(throws: (any Error).self) { try denied.websocketURL(baseURL: URL(string: "https://trusted.invalid")!, clientType: .ios) }
    }
}

@Test func pairedLiveDiscoveryNeverCarriesIdentityOrConfiguredAuthorization() async throws {
    let wire = try pairedCapabilityWire()
    let fixture = HistoryWireFixture { _ in (200, wire, 0) }; defer { fixture.close() }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [HistoryWireProtocol.self]
    configuration.httpAdditionalHeaders = ["Authorization": "Bearer must-not-leave", "X-DJConnect-Device-ID": "must-not-leave"]
    let client = DJConnectClient(baseURL: URL(string: fixture.baseURL.absoluteString + "?secret=must-not-leave")!,
        identity: .init(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Fixture", clientType: .ios, firmware: "4.0.0", platform: .ios),
        tokenStore: DJConnectInMemoryTokenStore(token: "must-not-leave"), session: URLSession(configuration: configuration))
    let cap = try await client.pairedOwnerLiveCapability()
    #expect(cap?.available == true)
    let request = try #require(fixture.requests.last)
    #expect(request.url?.query == nil && request.url?.user == nil)
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == nil)
}

@Test func pairedLiveAuthAndCommandExcludeCallerAuthorityAndURLSecrets() throws {
    let auth = DJConnectPairedOwnerAuthRequest(deviceID: "djconnect-ios-ABCDEF123456", clientType: .ios, deviceToken: "fixture-paired-secret")
    let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(auth)) as? [String: Any])
    #expect(Set(object.keys) == ["type", "protocol_version", "device_id", "client_type", "device_token"])
    #expect((object["protocol_version"] as? NSNumber)?.objCType.pointee != 99) // NSNumber Bool uses c; protocol must be integer.
    let command = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(DJConnectPairedOwnerSubscribeRequest(sessionID: "session-a"))) as? [String: Any])
    #expect(Set(command.keys) == ["id", "type", "session_id"])
    #expect(command["owner_profile_id"] == nil && command["device_token"] == nil)
}

private actor HTTPBroadcastRecoveryProbe {
    var requests = 0
    var snapshots: [DJConnectBroadcastState] = []
    var ended = false
    let snapshot: DJConnectBroadcastState
    init(snapshot: DJConnectBroadcastState) { self.snapshot = snapshot }
    func recover() throws -> DJConnectBroadcastState? {
        requests += 1
        if requests == 1 { throw DJConnectError.network(message: "Transient remote connection failure") }
        return requests <= 3 ? snapshot : nil
    }
    func received(_ snapshot: DJConnectBroadcastState) { snapshots.append(snapshot) }
    func finish() { ended = true }
}

private final class HTTPRecoveryActiveReadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func next() -> Int { lock.withLock { count += 1; return count } }
    var value: Int { lock.withLock { count } }
}

@Test(arguments: ["unauthorized", "invalid_profile"])
@MainActor func sessionHTTPRecoveryWithdrawsPrivateOwnerState(_ denial: String) async throws {
    let receipt = try historyObject()
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    let archive = try historyData(try #require(receipt["archived_timeline"]))
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: archive)
    let active = try historyData(try #require(historyObject("active-session-before-auth-failure")["response"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let counter = HTTPRecoveryActiveReadCounter()
    let historyCounter = HTTPRecoveryActiveReadCounter()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/status") { return (401, Data(#"{"success":false,"error":"unauthorized"}"#.utf8), 0) }
        if request.url!.path.hasSuffix("/session/active") {
            if counter.next() == 1 { return (200, active, 0) }
            return (denial == "unauthorized" ? 401 : 403,
                Data("{\"success\":false,\"error\":\"\(denial)\"}".utf8), 0)
        }
        if request.url!.path.hasSuffix("/timeline") { return (200, archive, 0) }
        return (200, profile, historyCounter.next() == 1 ? 0 : 0.4)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { defaults.removePersistentDomain(forName: name); model.markInactiveSession() }
    await model.sessionHistory.prepare()
    await model.sessionHistory.loadTimeline(page.session.id)
    #expect(model.sessionHistory.hasAuthorizedOwner && !model.askDJMessages.isEmpty)
    #expect(model.sessionHistory.timelines[page.session.id] != nil)
    let lateHistory = Task { try? await model.sessionHistory.fetchExistingHistory() }
    try await Task.sleep(for: .milliseconds(30))
    let epoch = model.sessionHistory.responseEpoch
    #expect(await model.refreshActiveDJSession())
    for _ in 0..<100 where model.sessionHistory.responseEpoch == epoch {
        try await Task.sleep(for: .milliseconds(20))
    }
    #expect(model.sessionHistory.responseEpoch != epoch)
    #expect(!model.sessionHistory.hasAuthorizedOwner && !model.sessionHistory.profileScopeActive)
    #expect(model.activeDJSession == nil && model.askDJMessages.isEmpty && !model.isSendingAskDJText)
    #expect(model.sessionHistory.pendingTurns.isEmpty && model.sessionHistory.timelines.isEmpty)
    _ = await lateHistory.value
    try await Task.sleep(for: .milliseconds(100))
    #expect(model.askDJMessages.isEmpty && model.activeDJSession == nil)
    #expect(fixture.requests.allSatisfy { $0.httpMethod != "POST" || $0.url!.path.hasSuffix("/status") })
    if denial == "unauthorized" { #expect(model.pairingStatus == .stale) }
}

@Test func sessionBroadcastAutomaticallyRecoversHTTPWhenLocalWebSocketIsUnavailable() async throws {
    let response = try JSONDecoder().decode(DJConnectSessionResponse.self,
        from: historyData(try #require(historyObject("active-session-before-auth-failure")["response"])))
    let snapshot = try #require(response.resolvedSession?.broadcast)
    let probe = HTTPBroadcastRecoveryProbe(snapshot: snapshot)
    let identity = DJConnectAPIIdentity(identity: DJConnectIdentity(deviceID: "djconnect-ios-ABCDEF123456",
        deviceName: "HTTP recovery fixture", clientType: .ios, firmware: "4.0.0-rc.1", platform: .ios))
    let transport = DJConnectSessionBroadcastTransport(baseURL: URL(string: "http://127.0.0.1:18196")!,
        discover: { nil }, pairedToken: { "synthetic-fixture-token" },
        httpRecovery: { try await probe.recover() })
    await transport.start(sessionID: snapshot.session.sessionID, identity: identity,
        onSnapshot: { _ in Issue.record("Unavailable WebSocket cannot provide a snapshot") },
        onEvent: { _ in Issue.record("Unavailable WebSocket cannot provide an event") },
        onTerminated: { await probe.finish() }, onHTTPSnapshot: { await probe.received($0) })
    for _ in 0..<90 {
        if await probe.ended { break }
        try await Task.sleep(for: .milliseconds(100))
    }
    #expect(await probe.ended)
    #expect(await probe.snapshots.count == 2)
    #expect(await probe.snapshots.allSatisfy { $0 == snapshot })
    #expect(await probe.requests == 4)
    await transport.stop()
    try await Task.sleep(for: .milliseconds(100))
    #expect(await probe.requests == 4)
}

private actor PairedProducerProbe {
    private var snapshots: [DJConnectSessionBroadcastSubscription] = []
    private var events: [DJConnectSessionBroadcastEvent] = []
    private var unavailable = false
    private var ended = false
    private var authorityCode: String?
    func authority(_ code: String) { authorityCode = code }
    func withdrawnCode() -> String? { authorityCode }
    func snapshot(_ value: DJConnectSessionBroadcastSubscription) { snapshots.append(value) }
    func event(_ value: DJConnectSessionBroadcastEvent) { events.append(value) }
    func withdraw() { unavailable = true }
    func end() { ended = true }
    func hasSnapshot(_ id: String) -> Bool { snapshots.contains { $0.sessionID == id && $0.success } }
    func hasUpdate() -> Bool { events.contains { $0.payload.playback?.title == "Paired native update" } }
    func isEnded() -> Bool { ended }
    func isUnavailable() -> Bool { unavailable }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_TEST_PAIRED_PRODUCER"] == "1"))
func pairedLiveActualProducerPairsWithoutHAUserThenStreamsAndEnds() async throws {
    let base = URL(string: "http://127.0.0.1:18196")!
    func control(_ name: String) async throws -> [String: Any] {
        var request = URLRequest(url: base.appendingPathComponent("__apple_paired_fixture/" + name))
        request.httpMethod = name == "state" ? "GET" : "POST"
        request.setValue("Bearer apple-paired-fixture-control", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
    _ = try await control("start")
    let identity = DJConnectIdentity(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Native transport proof", clientType: .ios, firmware: "4.0.0-rc.1", platform: .ios)
    let store = DJConnectInMemoryTokenStore()
    let client = DJConnectClient(baseURL: base, identity: identity, tokenStore: store)
    _ = try await client.pair(DJConnectPairingPayload(identity: identity, pairingToken: "123456"))
    #expect(try store.loadToken()?.isEmpty == false)
    let state = try await control("state")
    #expect((state["ha_refresh_tokens"] as? Int) == (state["initial_ha_refresh_tokens"] as? Int))
    #expect((state["ha_users"] as? Int) == (state["initial_ha_users"] as? Int))
    let active = try #require(state["active"] as? [String: Any])
    let id = try #require(active["session_id"] as? String)
    let probe = PairedProducerProbe()
    let transport = DJConnectSessionBroadcastTransport(baseURL: base,
        discover: { try await client.pairedOwnerLiveCapability() }, pairedToken: { try store.loadToken() })
    await transport.start(sessionID: id, identity: DJConnectAPIIdentity(identity: identity),
        onSnapshot: { await probe.snapshot($0) }, onEvent: { await probe.event($0) }, onTerminated: { await probe.end() },
        onUnavailable: { await probe.withdraw() }, onConnectionUnavailable: { await probe.withdraw() })
    for _ in 0..<100 { if await probe.hasSnapshot(id) { break }; try await Task.sleep(for: .milliseconds(100)) }
    #expect(await probe.hasSnapshot(id))
    #expect(await !probe.isUnavailable())
    _ = try await control("update")
    for _ in 0..<100 { if await probe.hasUpdate() { break }; try await Task.sleep(for: .milliseconds(100)) }
    #expect(await probe.hasUpdate())
    _ = try await control("end")
    for _ in 0..<100 { if await probe.isEnded() { break }; try await Task.sleep(for: .milliseconds(100)) }
    #expect(await probe.isEnded())
    await transport.stop()
}


@Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_TEST_PAIRED_PRODUCER"] == "1"))
func pairedLiveActualProducerWithdrawsChangedProfileAndRejectsInvalidToken() async throws {
    let base = URL(string: "http://127.0.0.1:18196")!
    func control(_ name: String) async throws {
        var request = URLRequest(url: base.appendingPathComponent("__apple_paired_fixture/" + name))
        request.httpMethod = "POST"
        request.setValue("Bearer apple-paired-fixture-control", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
    }
    try await control("restore_profile"); try await control("start")
    let identity = DJConnectIdentity(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Native negative proof", clientType: .ios, firmware: "4.0.0-rc.1", platform: .ios)
    let store = DJConnectInMemoryTokenStore()
    let client = DJConnectClient(baseURL: base, identity: identity, tokenStore: store)
    _ = try await client.pair(DJConnectPairingPayload(identity: identity, pairingToken: "123456"))
    let sessionID = try #require(try await client.activeSession().resolvedSession?.sessionID)
    let probe = PairedProducerProbe()
    let transport = DJConnectSessionBroadcastTransport(baseURL: base,
        discover: { try await client.pairedOwnerLiveCapability() }, pairedToken: { try store.loadToken() })
    await transport.start(sessionID: sessionID, identity: DJConnectAPIIdentity(identity: identity),
        onSnapshot: { await probe.snapshot($0) }, onEvent: { await probe.event($0) }, onTerminated: { await probe.end() },
        onUnavailable: { await probe.withdraw() }, onConnectionUnavailable: { await probe.withdraw() },
        onAuthorityWithdrawn: { await probe.authority($0) })
    for _ in 0..<100 { if await probe.hasSnapshot(sessionID) { break }; try await Task.sleep(for: .milliseconds(50)) }
    #expect(await probe.hasSnapshot(sessionID))
    try await control("switch_profile")
    for _ in 0..<100 { if await probe.withdrawnCode() != nil { break }; try await Task.sleep(for: .milliseconds(50)) }
    #expect(await probe.withdrawnCode() == "profile_changed")
    await transport.stop()
    try await control("restore_profile")
    let denied = PairedProducerProbe()
    let invalid = DJConnectSessionBroadcastTransport(baseURL: base,
        discover: { try await client.pairedOwnerLiveCapability() }, pairedToken: { "synthetic-invalid-token" })
    await invalid.start(sessionID: sessionID, identity: DJConnectAPIIdentity(identity: identity),
        onSnapshot: { await denied.snapshot($0) }, onEvent: { await denied.event($0) }, onTerminated: { await denied.end() },
        onUnavailable: { await denied.withdraw() }, onConnectionUnavailable: { await denied.withdraw() },
        onAuthorityWithdrawn: { await denied.authority($0) })
    for _ in 0..<100 { if await denied.withdrawnCode() != nil { break }; try await Task.sleep(for: .milliseconds(50)) }
    #expect(await denied.withdrawnCode() == "unauthorized")
    #expect(await !denied.hasSnapshot(sessionID))
    #expect(await !denied.hasUpdate())
    await invalid.stop()
}

@Test func pairedLivePairingRetainsBackendFailureWithoutRejectingCredential() throws {
    let wire = Data(#"{"success":true,"device_token":"synthetic-paired-secret","client_type":"ios","music_backend_available":false,"music_backend_error":{"code":"music_backend_not_configured","message":"Kies een muziekbackend"}}"#.utf8)
    let paired = try JSONDecoder().decode(DJConnectPairingResponse.self, from: wire)
    #expect(paired.success && paired.resolvedDeviceToken != nil)
    #expect(paired.musicBackendAvailable == false && paired.musicBackendError == "Kies een muziekbackend")
    let malformed = Data(#"{"success":true,"device_token":42,"client_type":"ios"}"#.utf8)
    #expect(throws: (any Error).self) { try JSONDecoder().decode(DJConnectPairingResponse.self, from: malformed) }
}


@Test func pairedLiveUpgradeRejectsRedirectAndIdentityButAllowsFoundationHTTPMapping() {
    let expected = URL(string: "wss://trusted.invalid/api/djconnect/v1/session/broadcast/paired")!
    #expect(pairedLiveUpgradeMatches(URL(string: "https://trusted.invalid:443/api/djconnect/v1/session/broadcast/paired"), expected: expected))
    for denied in ["http://trusted.invalid/api/djconnect/v1/session/broadcast/paired", "https://foreign.invalid/api/djconnect/v1/session/broadcast/paired", "https://trusted.invalid/other", "https://trusted.invalid/api/djconnect/v1/session/broadcast/paired?token=forbidden", "https://user:secret@trusted.invalid/api/djconnect/v1/session/broadcast/paired"] {
        #expect(!pairedLiveUpgradeMatches(URL(string: denied), expected: expected))
    }
}

@Test func pairedLiveDiscoveryRejectsRealRedirectBeforeDestinationOrCredentialExposure() async throws {
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("paired-redirect-" + UUID().uuidString + ".json")
    let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process.arguments = [repo.appendingPathComponent("Tools/paired_discovery_http_fixture.py").path, file.path]
    let output = Pipe(); process.standardOutput = output; process.standardError = Pipe()
    try process.run()
    defer { process.terminate(); process.waitUntilExit(); try? FileManager.default.removeItem(at: file) }
    var line = Data()
    while let byte = try output.fileHandleForReading.read(upToCount: 1), !byte.isEmpty {
        if byte == Data([10]) { break }; line.append(byte)
    }
    let ports = try #require(JSONSerialization.jsonObject(with: line) as? [String: Int])
    let port = try #require(ports["source_port"])
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpAdditionalHeaders = ["Authorization": "fixture-must-not-leave", "X-DJConnect-Device-ID": "fixture-must-not-leave"]
    let client = DJConnectClient(baseURL: URL(string: "http://127.0.0.1:\(port)/?identity=fixture-must-not-leave")!,
        identity: .init(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Fixture", clientType: .ios, firmware: "4.0.0", platform: .ios),
        tokenStore: DJConnectInMemoryTokenStore(token: "fixture-must-not-leave"), session: URLSession(configuration: configuration))
    do { _ = try await client.pairedOwnerLiveCapability(); Issue.record("A redirect must not supply live discovery") }
    catch let error as DJConnectError { guard case .routeMissing = error else { throw error } }
    let records = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    #expect((records["source_requests"] as? Int) == 1)
    #expect((records["target_requests"] as? Int) == 0)
    #expect((records["authorization_present"] as? Bool) == false)
    #expect((records["identity_present"] as? Bool) == false)
    #expect((records["query_present"] as? Bool) == false)
}

@Test func sessionArchiveSummaryUsesActualTimezoneDurationAndBothDates() throws {
    let session = try JSONDecoder().decode(DJConnectSavedSession.self, from: Data(#"{"session_id":"summary","lifecycle_status":"ENDED","created_at":"2026-10-11T10:00:00Z","started_at":"2026-10-11T10:00:00Z","ended_at":"2026-10-11T16:00:00Z","interrupted_at":"","revision":"r1","read_only":true,"history_coverage":"retained"}"#.utf8))
    let text = SessionArchiveSummary.text(session, language: "nl", timeZone: try #require(TimeZone(identifier: "Europe/Amsterdam")))
    #expect(text.contains("11 oktober 2026"))
    #expect(text.contains("6 uur"))
    #expect(text.contains("12:00 – 18:00"))
    #expect(!text.hasPrefix("ma")) // The example date is actually Sunday.
}

@Test func sessionArchiveSummaryNeverInventsMissingOrInvalidEnd() throws {
    for end in ["", "2026-10-11T09:00:00Z"] {
        let json: [String: Any] = ["session_id":"summary", "lifecycle_status":"ENDED", "created_at":"2026-10-11T10:00:00Z", "started_at":"2026-10-11T10:00:00Z", "ended_at":end, "interrupted_at":"", "revision":"r1", "read_only":true, "history_coverage":"retained"]
        let session = try JSONDecoder().decode(DJConnectSavedSession.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(SessionArchiveSummary.text(session, language: "nl").contains("eindtijd onbekend"))
    }
}

@Test(arguments: ["saved", "end-failed", "archive-failed", "history-reset"])
@MainActor func sessionEndDoesNotShowSavedToastOrFetchArchive(outcome: String) async throws {
    var archive = try #require(historyObject()["archived_timeline"] as? [String: Any])
    let saved = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: historyData(archive)).session
    archive["entries"] = []
    let archiveData = try historyData(archive)
    let demo = try DJConnectDemoSessionData.make(language: "nl")
    var runtime = demo.active
    runtime.sessionID = saved.id
    runtime.broadcast.session.sessionID = saved.id
    let runtimeObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(runtime))
    let activeData = try historyData(["success": true, "active_session": runtimeObject])
    let success = Data(#"{"success":true}"#.utf8)
    let failure = Data(#"{"success":false,"error":"temporary_unavailable"}"#.utf8)
    let fixture = HistoryWireFixture { request in
        let path = request.url!.path
        if path.hasSuffix("/session/active") { return (200, activeData, 0) }
        if path.hasSuffix("/session/end") { return outcome == "end-failed" ? (503, failure, 0) : (200, success, outcome == "history-reset" ? 0.2 : 0) }
        if path.contains("/session/history/") { return outcome == "archive-failed" ? (503, failure, 0) : (200, archiveData, 0) }
        return (404, failure, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    model.language = "nl"
    #expect(await model.refreshActiveDJSession())
    if outcome == "history-reset" {
        let ending = Task { @MainActor in await model.endDJSession() }
        for _ in 0..<100 where !fixture.requests.contains(where: { $0.url!.path.hasSuffix("/session/end") }) {
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(fixture.requests.contains { $0.url!.path.hasSuffix("/session/end") })
        model.sessionHistory.reset()
        await ending.value
        #expect(!fixture.requests.contains { $0.url!.path.contains("/session/history/") })
    } else { await model.endDJSession() }
    #expect(model.userNotice == nil)
    #expect(!fixture.requests.contains { $0.url!.path.contains("/session/history/") })
    #expect((model.activeDJSession == nil) == (outcome != "end-failed"))
    #expect(!model.isLoadingDJSession)
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/session/end") }.count == 1)
}

@Test @MainActor func sessionHistoryNewestWindowSurvivesEarlierPagingAndRestore() async throws {
    let receipt = try historyObject("window-producer-receipt")
    var tail = try #require(receipt["tail_window"] as? [String: Any])
    tail["window_limit"] = 20
    let tailData = try historyData(tail)
    let firstData = try historyData(try #require(receipt["first_page"]))
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: tailData)
    let profile = try historyData(try #require(try historyObject()["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("ask_dj/history") { return (200, profile, 0) }
        return (200, request.url!.query?.contains("window=tail") == true ? tailData : firstData, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    await model.sessionHistory.loadTimeline(page.session.id, window: .tail)
    let newest = try #require(page.entries.last?.id)
    #expect(model.sessionHistory.timelines[page.session.id]?.entries.last?.id == newest)
    await model.sessionHistory.loadTimeline(page.session.id, preserveLoadedEntries: true)
    #expect(model.sessionHistory.timelines[page.session.id]?.entries.last?.id == newest)
    #expect((model.sessionHistory.timelines[page.session.id]?.entries.count ?? 0) > page.entries.count)
    await model.sessionHistory.refreshVisibleTimeline(page.session.id, anchor: nil)
    await model.sessionHistory.restoreVisibleTimeline(page.session.id, active: false, anchor: nil)
    #expect(model.sessionHistory.timelines[page.session.id]?.entries.last?.id == newest)
    #expect(fixture.requests.last?.url?.query?.contains("window=tail") == true)
}

@Test func sessionArchiveSummaryShowsEndDateForOvernightSessions() throws {
    let session = try JSONDecoder().decode(DJConnectSavedSession.self, from: Data(#"{"session_id":"overnight","lifecycle_status":"ENDED","created_at":"2026-10-10T21:00:00Z","started_at":"2026-10-10T21:00:00Z","ended_at":"2026-10-11T04:00:00Z","interrupted_at":"","revision":"r1","read_only":true,"history_coverage":"retained"}"#.utf8))
    let text = SessionArchiveSummary.text(session, language: "nl", timeZone: try #require(TimeZone(identifier: "Europe/Amsterdam")))
    #expect(text.contains("10 oktober 2026") && text.contains("11 oktober 2026"))
    #expect(text.contains("7 uur") && text.contains("23:00") && text.contains("06:00"))
}

@Test func musicDNAPrivacyUsesLocalizedClaimsWithoutInventingUnknownAssurances() throws {
    let wire = Data(#"{"enabled":true,"data_sources":[{"label":"Ask DJ playback context","enabled":false}],"controls":{"clear_supported":true,"export_supported":false,"import_supported":true,"opt_out_preserves_clear":true},"stores_raw_audio":false,"stores_oauth_tokens":false,"stores_full_prompts":true,"flags":{"unknown_internal_flag":true}}"#.utf8)
    let dashboard = try JSONDecoder().decode(DJConnectMusicDNAPrivacyDashboard.self, from: wire)
    let text = MusicDNAPrivacySummary.text(dashboard, language: "nl")
    #expect(text.contains("Music DNA staat aan."))
    #expect(text.contains("Stemopnames worden niet bewaard."))
    #expect(text.contains("Volledige vragen worden bewaard."))
    #expect(text.contains("Downloaden is momenteel niet beschikbaar."))
    for raw in ["enabled:", "disabled", "OAuth", "clear supported", "unknown_internal_flag", "Ask DJ playback context"] { #expect(!text.contains(raw)) }
    let unknown = MusicDNAPrivacySummary.text(.init(flags: ["unknown": false]), language: "nl")
    #expect(unknown == "Privacy-informatie is momenteel niet beschikbaar.")
    for language in ["nl", "en", "de", "fr", "es"] {
        #expect(!MusicDNAPrivacySummary.text(dashboard, language: language).contains("ui.music.dna."))
    }
}

@Test @MainActor func sessionArchiveExplicitRefreshSupersedesSlowOldFailure() async throws {
    let receipt = try historyObject()
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    let timeline = try #require(receipt["archived_timeline"] as? [String: Any])
    let sessions = try historyData(["success": true, "schema_version": 1, "sessions": [try #require(timeline["session"])],
                                  "revision": try #require(timeline["revision"]), "retention_days": 30])
    let caps = Data(#"{"capabilities":{"session_conversation_history":true},"contract_versions":{"session_conversation_history":1}}"#.utf8)
    let sequence = ArchiveRefreshSequence()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("ask_dj/history") { return (200, profile, 0) }
        if sequence.next() == 1 { return (503, Data(#"{"success":false,"error":"unavailable"}"#.utf8), 0.2) }
        return (200, sessions, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    let old = Task { await model.sessionHistory.loadSessions() }
    try await Task.sleep(for: .milliseconds(40))
    #expect(model.sessionHistory.listLoading)
    #expect(await model.sessionHistory.loadSessions())
    #expect(!(await old.value))
    #expect(!model.sessionHistory.sessions.isEmpty)
    #expect(model.sessionHistory.listErrorKey == nil && !model.sessionHistory.listLoading)
}
private final class ArchiveRefreshSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func next() -> Int { lock.withLock { count += 1; return count } }
}

private let activeMoodCapsWire = Data(#"{"capabilities":{"active_session_mood":true,"session_conversation_history":true},"contract_versions":{"active_session_mood":1,"session_conversation_history":1},"active_session_mood":{"available":true,"version":1,"path":"/api/djconnect/v1/session/mood","method":"POST","authentication":"paired_device_bearer","moods":["chill","groove","energy","party"],"ordering":"expected_mood_revision","scope":"active_device_bound_owner_session"}}"#.utf8)
private func activeMoodRuntimeWire() throws -> Data {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/moment-contract-receipt.json"))) as? [String: Any])
    var runtime = try #require(object["runtime"] as? [String: Any])
    runtime["mood_revision"] = 0
    var broadcast = try #require(runtime["broadcast"] as? [String: Any])
    var session = try #require(broadcast["session"] as? [String: Any]); session["mood_revision"] = 0
    broadcast["session"] = session; runtime["broadcast"] = broadcast
    return try historyData(["success":true,"session":runtime])
}

@Test func activeMoodRequestUsesExactlyOwnerContractAndPinnedCapability() throws {
    let fixture = HistoryWireFixture { _ in (200, Data(), 0) }; defer { fixture.close() }
    let client = fixture.client()
    let request = try client.sessionMoodRequest(sessionID: "current", mood: "energy", expectedRevision: 3)
    let requestData = try #require(request.httpBody)
    let body = try #require(JSONSerialization.jsonObject(with: requestData) as? [String: Any])
    #expect(Set(body.keys) == ["contract_version","client_type","device_id","session_id","selected_mood","expected_mood_revision"])
    #expect(request.url?.path == "/api/djconnect/v1/session/mood" && request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-fixture-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == "djconnect-ios-ABCDEF123456")
    #expect(try JSONDecoder().decode(DJConnectActiveMoodCapabilities.self, from: activeMoodCapsWire).available)
    #expect(!(try JSONDecoder().decode(DJConnectActiveMoodCapabilities.self, from: Data(#"{"capabilities":{"active_session_mood":true},"contract_versions":{"active_session_mood":1}}"#.utf8))).available)
}

@Test(arguments: ["mood", "capabilities"])
@MainActor func activeMoodAuthorityDenialWithdrawsLoadedProfile(_ route: String) async throws {
    let profile = try historyData(try #require(historyObject()["later_historical_answer"]))
    let runtime = try activeMoodRuntimeWire()
    let denial = HistoryAuthorityGate()
    let fixture = HistoryWireFixture { request in
        if denial.denied && request.url!.path.hasSuffix("/" + route) { return (403, Data(#"{"success":false,"error":"invalid_profile"}"#.utf8), 0) }
        if request.url!.path.hasSuffix("/capabilities") { return (200, activeMoodCapsWire, 0) }
        if request.url!.path.hasSuffix("/session/active") { return (200, runtime, 0) }
        if request.url!.path.hasSuffix("ask_dj/history") { return (200, profile, 0) }
        return (404, Data(#"{"success":false}"#.utf8), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare(); await model.refreshActiveDJSession(); await model.refreshActiveMoodCapability()
    #expect(model.sessionHistory.hasAuthorizedOwner && model.activeMoodAvailable && model.activeDJSession != nil)
    denial.denied = true
    if route == "mood" { await model.changeActiveSessionMood("party") } else { await model.refreshActiveMoodCapability() }
    #expect(!model.sessionHistory.hasAuthorizedOwner && model.askDJMessages.isEmpty)
    #expect(model.sessionHistory.pendingTurns.isEmpty && model.activeDJSession == nil)
    #expect(!model.activeMoodPending && !model.activeMoodAvailable && model.activeMoodError == nil)
}

@Test @MainActor func activeMoodLateFailureAfterBackgroundCannotRestoreOldStatus() async throws {
    let runtime = try activeMoodRuntimeWire()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, activeMoodCapsWire, 0) }
        if request.url!.path.hasSuffix("/session/active") { return (200, runtime, 0) }
        if request.url!.path.hasSuffix("/session/mood") { return (409, Data(#"{"success":false,"error":"mood_revision_conflict"}"#.utf8), 0.15) }
        return (404, Data(#"{"success":false}"#.utf8), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshActiveDJSession(); await model.refreshActiveMoodCapability()
    let pending = Task { await model.changeActiveSessionMood("party") }
    try await Task.sleep(for: .milliseconds(30))
    #expect(model.activeMoodPending)
    model.markInactiveSession()
    #expect(!model.activeMoodPending && !model.activeMoodAvailable && model.activeMoodError == nil)
    await pending.value
    #expect(!model.activeMoodPending && model.activeMoodError == nil)
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/session/mood") }.count == 1)
    model.markActiveSession()
    for _ in 0..<200 {
        if model.activeMoodAvailable { break }
        try await Task.sleep(for: .milliseconds(20))
    }
    #expect(model.activeMoodAvailable && !model.activeMoodPending && model.activeMoodError == nil)
}

@Test func sessionArchiveDoesNotInventDurationFromCreationWhenStartIsMissing() throws {
    let session = try JSONDecoder().decode(DJConnectSavedSession.self, from: Data(#"{"session_id":"unknown-start","lifecycle_status":"ENDED","created_at":"2026-10-11T10:00:00Z","started_at":"","ended_at":"2026-10-11T16:00:00Z","interrupted_at":"","revision":"1","read_only":true,"history_coverage":"retained_visible"}"#.utf8))
    let text = SessionArchiveSummary.text(session, language: "nl")
    #expect(text.contains("begintijd onbekend"))
    #expect(!text.contains("6 uur"))
}

@Test @MainActor func reviewDemoSessionsUseNativeModelsAndNeverBecomeLiveAuthority() async throws {
    let name = "demo-session-test-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    model.startDemoMode()
    let active = try #require(model.activeDJSession)
    #expect(active.id.hasPrefix("demo-active-"))
    #expect(active.broadcast.nativeCurrentMoment(at: Date())?.content.isEmpty == false)
    #expect(model.sessionHistory.available && !model.sessionHistory.profileScopeActive && !model.sessionHistory.hasAuthorizedOwner)
    #expect(!model.canRefreshSessionHistory && !model.canUseProfileConversation)
    #expect(model.sessionHistory.sessions.count == 2)
    #expect(model.sessionHistory.sessions.allSatisfy { $0.readOnly && $0.isContractValid })
    #expect(model.sessionHistory.timelines.values.allSatisfy { $0.entries.count == 6 && $0.entries.allSatisfy { $0.isContractValid && $0.isRetained() } })
    let archive = try #require(model.sessionHistory.sessions.first)
    let original = model.sessionHistory.timelines[archive.id]
    model.sessionHistory.search(sessionID: archive.id, query: "Electric Feel")
    #expect(model.sessionHistory.searchMatches.count == 1)
    await model.sessionHistory.loadSessions()
    await model.sessionHistory.loadTimeline(archive.id)
    #expect(model.sessionHistory.timelines[archive.id] == original)
    let entry = try #require(original?.entries.first)
    model.sessionHistory.rememberReadingAnchor(entry.id, sessionID: archive.id)
    #expect(model.sessionHistory.readingAnchor(sessionID: archive.id) == entry.id)
    let action = try JSONDecoder().decode(DJConnectSessionOpenAction.self, from: JSONSerialization.data(withJSONObject: [
        "kind": "open_session", "session_id": archive.id, "entry_id": entry.id, "navigation_only": true]))
    #expect(await model.sessionHistory.open(action))
    #expect(model.activeDJSession == active)
    model.askDJDraft = "Demo question"
    model.sessionHistory.sendText()
    #expect(model.sessionHistory.timelines[active.id]?.entries.count == 8)
    #expect(model.sessionHistory.timelines[archive.id] == original)
    #expect(model.askDJDraft.isEmpty && model.askDJMessages.count == 2)
    await model.changeActiveSessionMood("party")
    #expect(model.activeDJSession?.selectedMood == "party")
    #expect(model.activeDJSession?.broadcast.playback == active.broadcast.playback)
    model.markInactiveSession()
    model.markActiveSession()
    #expect(model.sessionHistory.sessions.count == 2)
    #expect(model.sessionHistory.timelines[active.id]?.entries.count == 8)
    #expect(model.activeDJSession?.broadcast.nativeCurrentMoment(at: Date()) != nil)
    await model.endDJSession()
    #expect(model.activeDJSession == nil)
    #expect(model.sessionHistory.sessions.first?.id == active.id && model.sessionHistory.sessions.first?.readOnly == true)
    #expect(model.userNotice == nil)
    #expect(model.playback?.trackName == "Midnight City")
    model.sendPlaybackCommand("next")
    for _ in 0..<20 where model.playback?.trackName != "Sweet Disposition" { await Task.yield() }
    model.selectedSessionMood = "party"
    await model.startDJSession()
    #expect(model.activeDJSession?.selectedMood == "party")
    #expect(model.activeDJSession?.broadcast.session.selectedMood == "party")
    #expect(model.activeDJSession?.broadcast.playback?.title == model.playback?.trackName)
    #expect(model.activeDJSession?.broadcast.playback?.title == "Sweet Disposition")
    #expect(model.sessionHistory.sessions.contains { $0.id == active.id && $0.readOnly })
    model.stopDemoMode()
    #expect(!model.sessionHistory.available && model.sessionHistory.sessions.isEmpty && model.activeDJSession == nil)
    #expect(model.sessionHistory.selectedEntry == nil && model.sessionHistory.openTarget == nil)
    #expect(model.sessionHistory.readingAnchor(sessionID: archive.id) == nil)
}

@Test @MainActor func demoExamplesCannotInstallOutsideDemoAndAreLocalized() throws {
    let name = "demo-off-test-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name)); defer { defaults.removePersistentDomain(forName: name) }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    for language in ["nl", "en", "de", "fr", "es"] {
        let data = try DJConnectDemoSessionData.make(language: language)
        #expect(data.active.broadcast.nativeCurrentMoment(at: Date())?.content == DJConnectLocalization.localized(key: "demo.session.direction", language: language))
        model.sessionHistory.installDemo(data)
        #expect(!model.sessionHistory.available && model.sessionHistory.timelines.isEmpty)
    }
}

@Test @MainActor func demoInputNeverPersistsAndCannotUploadCapturedVoice() async throws {
    let name = "demo-private-test-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name)); defer { defaults.removePersistentDomain(forName: name) }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    let oldOperation = model.voiceOperationID; let oldEpoch = model.sessionHistory.responseEpoch
    model.isRecordingVoice = true
    model.startDemoMode()
    #expect(!model.isRecordingVoice && model.voiceOperationID != oldOperation)
    model.askDJDraft = "PRIVATE DEMO INPUT"
    model.sendAskDJText()
    model.startVoiceRecording()
    #expect(!model.isRecordingVoice && model.voiceStatus == .idle)
    #expect(model.sessionHistory.timelines[model.activeDJSession?.id ?? ""]?.entries.count == 10)
    #expect(model.sessionHistory.timelines.values.flatMap(\.entries).suffix(2).contains { $0.inputType == "voice" })
    await model.uploadRecordedVoiceWAV(Data([0, 1, 2]), operation: model.voiceOperationID, historyEpoch: model.sessionHistory.responseEpoch)
    #expect(model.voiceStatus == .idle && model.voiceErrorMessage == nil)
    model.stopDemoMode()
    #expect(model.askDJMessages.isEmpty)
    await model.uploadRecordedVoiceWAV(Data([0, 1, 2]), operation: oldOperation, historyEpoch: oldEpoch)
    #expect(model.voiceStatus == .idle && model.voiceErrorMessage == nil)
    let next = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    #expect(next.askDJMessages.isEmpty && next.activeDJSession == nil && !next.sessionHistory.available)
}

@Test @MainActor func reviewDemoAllActionsStayOfflineAndPreserveNormalChatCache() async throws {
    let wire = HistoryWireFixture { _ in (503, Data(), 0) }; defer { wire.close() }
    let name = "demo-cache-test-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name)); defer { defaults.removePersistentDomain(forName: name) }
    let saved = try JSONEncoder().encode([DJConnectAskDJMessage(role: .user, text: "Existing ordinary chat")])
    defaults.set(saved, forKey: "DJConnectAskDJMessages")
    defaults.set(wire.baseURL.absoluteString, forKey: "DJConnectHomeAssistantURL")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), urlSession: wire.session(), startBackgroundTasks: false)
    model.startDemoMode()
    await model.refreshActiveDJSession(); await model.refreshActiveMoodCapability(); await model.changeActiveSessionMood("party")
    await model.sessionHistory.prepare(); await model.sessionHistory.loadSessions()
    await model.sessionHistory.refreshConversation()
    if let id = model.activeDJSession?.id { await model.sessionHistory.loadTimeline(id) }
    model.askDJDraft = "Private demo-only question"; model.sendAskDJText(); model.startVoiceRecording()
    await model.uploadRecordedVoiceWAV(Data([1]), operation: model.voiceOperationID, historyEpoch: model.sessionHistory.responseEpoch)
    await model.endDJSession(); await model.startDJSession()
    model.stopDemoMode()
    #expect(wire.requests.isEmpty)
    #expect(defaults.data(forKey: "DJConnectAskDJMessages") == saved)
    let next = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), urlSession: wire.session(), startBackgroundTasks: false)
    #expect(next.askDJMessages.map(\.text) == ["Existing ordinary chat"])
}

@Test func sessionTimelineRefreshHonorsExactExpiryBetweenMinuteTicks() {
    let start = Date(timeIntervalSince1970: 120)
    let expires = start.addingTimeInterval(7.125)
    let schedule = SessionEntryRefreshSchedule(deadlines: [expires, expires, start.addingTimeInterval(-1)])
    let dates = Array(schedule.entries(from: start, mode: .normal).prefix(4))
    #expect(dates == [start, expires, start.addingTimeInterval(60), start.addingTimeInterval(120)])
}

@Test func sessionTimelineMinuteBoundaryExpiryDoesNotDuplicateTicks() {
    let start = Date(timeIntervalSince1970: 119)
    let boundary = Date(timeIntervalSince1970: 120)
    let schedule = SessionEntryRefreshSchedule(deadlines: [boundary, boundary])
    #expect(Array(schedule.entries(from: start, mode: .normal).prefix(3)) == [start, boundary, boundary.addingTimeInterval(60)])
    #expect(sessionPlaybackTime(-1) == "0:00")
    #expect(sessionPlaybackTime(67000) == "1:07")
    #expect(sessionPlaybackTime(3601000) == "60:01")
}

@Test @MainActor func activeMoodBoundIntentDoesNotTargetReplacementSession() async throws {
    let runtime = try activeMoodRuntimeWire()
    let object = try #require(JSONSerialization.jsonObject(with: runtime) as? [String: Any])
    let session = try #require(object["session"] as? [String: Any])
    let sessionID = try #require(session["session_id"] as? String)
    let replacementWire = Data(String(decoding: runtime, as: UTF8.self).replacingOccurrences(of: sessionID, with: sessionID + "-replacement").utf8)
    let switched = HistoryAuthorityGate()
    let activeReads = HTTPRecoveryActiveReadCounter()
    let initialRecovery = HistoryWireResponseGate()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, activeMoodCapsWire, 0) }
        if request.url!.path.hasSuffix("/session/active") {
            // Hold A's first background recovery until the explicit B read has
            // finished. A late A response must not change B or its mood intent.
            if activeReads.next() == 2 {
                throw HistoryWireHeldResponse(data: runtime, gate: initialRecovery)
            }
            return (200, switched.denied ? replacementWire : runtime, 0)
        }
        return (404, Data(), 0)
    }
    defer { initialRecovery.release(); fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    await model.refreshActiveDJSession(); await model.refreshActiveMoodCapability()
    // Wait for the held recovery request, not nativeDelivery: this legacy
    // receipt has no native grant and can never satisfy that old wait condition.
    for _ in 0..<300 where activeReads.value < 2 {
        try await Task.sleep(for: .milliseconds(10))
    }
    try #require(activeReads.value == 2)
    let prior = try #require(model.activeDJSession)
    let epoch = model.sessionHistory.responseEpoch
    switched.denied = true
    await model.refreshActiveDJSession()
    #expect(model.activeDJSession?.id == prior.id + "-replacement")
    initialRecovery.release()
    await model.refreshActiveMoodCapability()
    #expect(model.activeMoodAvailable)
    #expect(model.activeDJSession?.confirmedMoodRevision != nil)
    await model.changeActiveSessionMood("party", expectedSessionID: prior.id, expectedEpoch: epoch)
    #expect(fixture.requests.allSatisfy { !$0.url!.path.hasSuffix("/session/mood") })
    #expect(model.activeDJSession?.selectedMood == prior.selectedMood)
    let replacement = try #require(model.activeDJSession)
    await model.changeActiveSessionMood("party", expectedSessionID: replacement.id, expectedEpoch: model.sessionHistory.responseEpoch)
    let writes = fixture.requests.filter { $0.url!.path.hasSuffix("/session/mood") }
    #expect(writes.count == 1, "Positive control proves B can dispatch; only stale A was blocked")
    #expect(model.activeDJSession?.id == replacement.id)
}

@Test func pairedConnectionIndicatorDoesNotTreatPairingAsLiveHealth() {
    #expect(SessionConnectionStatus.resolve(demo: false, pairing: .paired, mode: .offline, backendAvailable: true, recovering: false, liveUnavailable: false) == .offline)
    #expect(SessionConnectionStatus.resolve(demo: false, pairing: .paired, mode: .local, backendAvailable: true, recovering: true, liveUnavailable: false) == .recovering)
    #expect(SessionConnectionStatus.resolve(demo: false, pairing: .paired, mode: .remote, backendAvailable: true, recovering: false, liveUnavailable: true) == .liveUnavailable)
    #expect(SessionConnectionStatus.resolve(demo: false, pairing: .paired, mode: .local, backendAvailable: false, recovering: true, liveUnavailable: true) == .backendUnavailable)
    #expect(SessionConnectionStatus.resolve(demo: false, pairing: .paired, mode: .remote, backendAvailable: true, recovering: false, liveUnavailable: false) == .remote)
    #expect(SessionConnectionStatus.resolve(demo: true, pairing: .unpaired, mode: .offline, backendAvailable: false, recovering: false, liveUnavailable: false) == .demo)
}

@Test @MainActor func reviewDemoExitRestoresRequiredPairingGateAndCanRestartDemo() throws {
    let defaults = try #require(UserDefaults(suiteName: "demo-exit-gate-" + UUID().uuidString))
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    model.applyUITestRuntimeFixture("review_demo")
    #expect(model.isDemoMode)
    #expect(!model.shouldShowPairingScreen)
    model.stopDemoMode()
    #expect(model.pairingStatus == .unpaired)
    #expect(model.shouldShowPairingScreen)
    model.completePairingScreen()
    #expect(model.shouldShowPairingScreen, "Cannot dismiss before pairing")
    model.startDemoMode()
    #expect(model.isDemoMode)
    #expect(!model.shouldShowPairingScreen)
}

@Test @MainActor func playbackSurfacesFollowConfirmedSessionMoodInsteadOfLegacyAskDJMood() async throws {
    let name = "playback-mood-test-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    model.askDJMood = 0
    #expect(model.playbackMoodStepIndex == 1)
    #expect(model.confirmedSessionMoodInt == nil)
    model.startDemoMode()
    for (index, mood) in ["chill", "groove", "energy", "party"].enumerated() {
        await model.changeActiveSessionMood(mood)
        #expect(model.playbackMoodStepIndex == index)
        #expect(model.confirmedSessionMoodInt == [0, 35, 70, 100][index])
        let payload = model.profileConversationPayload(text: "question", clientMessageID: UUID().uuidString, context: DJConnectConversationContext(sessionID: model.activeDJSession?.id))
        #expect(payload.mood == [0, 35, 70, 100][index])
        #expect(model.askDJMood == 0)
    }
    // An unconfirmed start-session choice must not recolour the current Session.
    model.selectedSessionMood = "chill"
    #expect(model.playbackMoodStepIndex == 3)
    await model.endDJSession()
    #expect(model.playbackMoodStepIndex == 1)
    #expect(model.confirmedSessionMoodInt == nil)
    let payload = model.profileConversationPayload(text: "question", clientMessageID: UUID().uuidString, context: DJConnectConversationContext(sessionID: nil))
    #expect(payload.mood == nil)
}

@Test @MainActor func sessionRenderCacheKeepsStableRowsAndHonorsExactExpiryAndEpoch() throws {
    let data = try DJConnectDemoSessionData.make(language: "nl")
    let entries = try #require(data.timelines[data.active.id]?.entries)
    let cache = SessionTimelineRenderCache(); let epoch = UUID()
    let first = cache.snapshot(entries, sessionID: data.active.id, epoch: epoch)
    #expect(!first.isEmpty)
    let same = cache.snapshot(entries, sessionID: data.active.id, epoch: epoch)
    #expect(first == same)
    let deadline = try #require(first.first?.deadline)
    let expired = cache.snapshot([first[0].entry], sessionID: data.active.id, epoch: epoch, at: deadline)
    #expect(expired.isEmpty)
    #expect(cache.snapshot([], sessionID: data.active.id, epoch: epoch).isEmpty)
    let replaced = cache.snapshot(entries, sessionID: data.active.id, epoch: UUID())
    #expect(replaced.first?.message.id != first.first?.message.id)
    cache.clear()
    #expect(cache.snapshot([], sessionID: data.active.id, epoch: epoch).isEmpty)
}

@Test @MainActor func sessionEquatableRowsInvalidateForContextSearchAndLanguage() throws {
    let data = try DJConnectDemoSessionData.make(language: "nl")
    let entry = try #require(data.timelines[data.active.id]?.entries.first)
    let base = SessionEntryView(entry: entry, language: "nl", contextEpoch: UUID(), opensActiveComposer: true)
    var changed = base; changed.contextEpoch = UUID(); #expect(base != changed)
    changed = base; changed.opensActiveComposer = false; #expect(base != changed)
    changed = base; changed.highlights = [.init(startUTF16: 0, lengthUTF16: 1)]; #expect(base != changed)
    changed = base; changed.selected = true; #expect(base != changed)
    #expect(base != SessionEntryView(entry: entry, language: "en", contextEpoch: base.contextEpoch, opensActiveComposer: true))
}

#if os(macOS)
/// Presentation only; supplied callback grants no history playback authority.
@Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_ENTRY_PLAY_NATIVE_DIR"] != nil)) @MainActor
func sessionPlaybackEntryShowsWhitePlayControl() async throws {
    let directory = try #require(ProcessInfo.processInfo.environment["DJCONNECT_ENTRY_PLAY_NATIVE_DIR"])
    let folder = URL(fileURLWithPath: directory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let data = try DJConnectDemoSessionData.make(language: "nl")
    let entry = try #require(data.timelines.values.flatMap(\.entries).first { $0.kind == .playbackObserved })
    _ = NSApplication.shared
    for width: CGFloat in [320, 720] {
        for active in [true, false] {
            let view = SessionEntryView(entry: entry, language: "nl", opensActiveComposer: active,
                                        replayAction: {})
                .padding(16).foregroundStyle(.white)
                .background(LinearGradient(colors: [.purple, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                .preferredColorScheme(.dark)
            let host = NSHostingView(rootView: view)
            let window = NSWindow(contentRect: .init(x: -3000, y: -3000, width: width, height: 500),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.contentView = host; window.orderBack(nil)
            try await Task.sleep(for: .milliseconds(150))
            host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
            let image = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: image)
            try #require(image.representation(using: .png, properties: [:]))
                .write(to: folder.appendingPathComponent("\(active ? "current" : "archive")-\(Int(width)).png"))
            window.close()
        }
    }
}
#endif

@Test func outputDevicesKeepRowsWithNumericObservedTimestamps() throws {
    let data = Data(#"{"success":true,"devices":[{"id":"speaker-1","name":"Living Room","active":true,"first_seen_at":1791882000.25,"last_seen_at":1791883000.5},{"id":"speaker-2","name":"Kitchen","cached":true,"provider":"spotify","first_seen_at":"2026-10-13T08:00:00Z","last_seen_at":null}]}"#.utf8)
    let response = try JSONDecoder().decode(DJConnectCommandResponse.self, from: data)
    #expect(response.devices?.count == 2)
    #expect(response.devices?.first?.active == true)
    #expect(response.devices?.first?.firstSeenAt == "2026-10-13T09:00:00Z")
    #expect(response.devices?.last?.isCachedSpotifyOutput == true)
    #expect(response.devices?.last?.lastSeenAt == nil)
}

@Test func localizationBundleCacheKeepsConcurrentLanguageSelectionAndFallback() async {
    let expected: [String: String] = ["nl": "Verstuur", "en": "Send", "de": "Send", "fr": "Send", "es": "Send"]
    await withTaskGroup(of: Bool.self) { group in
        for index in 0..<100 {
            let language = DJConnectLocalization.supportedLanguageCodes[index % 5]
            group.addTask { DJConnectLocalization.localized(key: "ui.send", language: language) == expected[language] }
        }
        for await matches in group { #expect(matches) }
    }
    #expect(DJConnectLocalization.localized(key: "a.missing.resource.key", language: "nl") == "a.missing.resource.key")
    #expect(DJConnectLocalization.localized(key: "ui.search.value", language: "nl", arguments: "Music") == "Zoek in Music")
}

@Test @MainActor func composerEditorKeepsDraftWithoutRepublishingEveryCharacter() throws {
    let fixture = HistoryWireFixture { _ in (200, Data("{}".utf8), 0) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    var publications = 0
    let subscription = model.objectWillChange.sink { publications += 1 }
    defer { subscription.cancel() }
    model.setAskDJDraftFromEditor("A")
    #expect(publications == 1)
    for index in 0..<100 { model.setAskDJDraftFromEditor("A question \(index)") }
    #expect(publications == 1)
    #expect(model.askDJDraft == "A question 99")
    #expect(model.askDJDraftRevision == 0)
    model.setAskDJDraftFromEditor(" \n")
    #expect(publications == 2)
    model.askDJDraft = "A suggested prompt"
    model.askDJDraft = "A different suggested prompt"
    #expect(publications == 4)
    #expect(model.askDJDraft == "A different suggested prompt")
    #expect(model.askDJDraftRevision == 2)
}

@Test @MainActor func sessionHistoryNavigationCancellationPreservesLoadedContentAndConnection() async throws {
    let receipt = try historyObject()
    let timelineObject = try #require(receipt["archived_timeline"] as? [String: Any])
    let timelineData = try historyData(timelineObject)
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: timelineData)
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    let sessions = try historyData(["success": true, "schema_version": 1,
        "sessions": [try #require(timelineObject["session"])], "revision": try #require(timelineObject["revision"]), "retention_days": 30])
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let gate = HistoryAuthorityGate()
    let fixture = HistoryWireFixture { request in
        if gate.denied { throw URLError(.cancelled) }
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("ask_dj/history") { return (200, profile, 0) }
        if request.url!.path.hasSuffix("/session/history") { return (200, sessions, 0) }
        return (200, timelineData, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    #expect(await model.sessionHistory.loadSessions())
    await model.sessionHistory.loadTimeline(page.session.id)
    let sessionIDs = model.sessionHistory.sessions.map(\.id)
    let entryIDs = model.sessionHistory.timelines[page.session.id]?.entries.map(\.id)
    #expect(!sessionIDs.isEmpty && entryIDs?.isEmpty == false)
    gate.denied = true
    await model.sessionHistory.loadTimeline(page.session.id)
    #expect(!(await model.sessionHistory.loadSessions()))
    await model.sessionHistory.refreshConversation()
    await model.sessionHistory.prepare()
    await Task.yield()
    #expect(model.sessionHistory.sessions.map(\.id) == sessionIDs)
    #expect(model.sessionHistory.timelines[page.session.id]?.entries.map(\.id) == entryIDs)
    #expect(model.sessionHistory.timelines[page.session.id]?.errorKey == nil)
    #expect(model.sessionHistory.listErrorKey == nil)
    #expect(model.sessionHistory.hasAuthorizedOwner)
    #expect(model.haConnectionMode == .local)
}

private final class MusicDNARecoveryAttempts: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.withLock { value += 1; return value } }
}

@Test(arguments: [false, true]) @MainActor func musicDNAProfileAutomaticallyRecoversTransientReadFailure(backendUnavailable: Bool) async throws {
    let attempts = MusicDNARecoveryAttempts()
    let fixture = HistoryWireFixture { _ in
        let attempt = attempts.next()
        if attempt < 3 {
            let body = backendUnavailable ? #"{"success":false,"error":"backend_unavailable"}"# : #"{"success":false,"error":"temporary_failure"}"#
            return (503, Data(body.utf8), 0)
        }
        return (200, Data(#"{"success":true,"enabled":true,"profile":{"summary":"Recovered"}}"#.utf8), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshMusicDNAProfile(retryDelays: [.milliseconds(1), .milliseconds(1)])
    #expect(model.musicDNAProfileResponse?.profile.summary == "Recovered")
    #expect(!model.musicDNAProfileNeedsRecovery && model.musicDNAErrorMessage == nil && !model.isLoadingMusicDNA)
    #expect(fixture.requests.count == 3)
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "POST" && $0.url?.path.hasSuffix("/music_dna/profile") == true })
}

@Test @MainActor func musicDNAProfileRetryIsBoundedAndRetainsLastLoadedProfile() async throws {
    let gate = HistoryAuthorityGate()
    let fixture = HistoryWireFixture { _ in
        if gate.denied { return (503, Data(#"{"success":false,"error":"temporary_failure"}"#.utf8), 0) }
        return (200, Data(#"{"success":true,"enabled":true,"profile":{"summary":"Existing profile"}}"#.utf8), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    #expect(await model.refreshMusicDNAProfile(retryDelays: []))
    gate.denied = true
    #expect(await model.refreshMusicDNAProfile(retryDelays: [.milliseconds(1), .milliseconds(1)]) == false)
    #expect(fixture.requests.count == 4)
    #expect(model.musicDNAProfileResponse?.profile.summary == "Existing profile")
    #expect(model.musicDNAProfileNeedsRecovery && !model.isLoadingMusicDNA)
    #expect(model.musicDNAErrorMessage == DJConnectLocalization.localized(key: "ui.music.dna.recovering", language: model.language))
}

@Test @MainActor func musicDNAProfileCancellationDoesNotBecomeRecoveryError() async throws {
    let fixture = HistoryWireFixture { _ in throw URLError(.cancelled) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshMusicDNAProfile(retryDelays: [.milliseconds(1)])
    #expect(fixture.requests.count == 1)
    #expect(!model.musicDNAProfileNeedsRecovery && model.musicDNAErrorMessage == nil && !model.isLoadingMusicDNA)
}

@Test @MainActor func musicDNAProfileAccessDenialDoesNotRetry() async throws {
    let fixture = HistoryWireFixture { _ in (403, Data(#"{"success":false,"error":"invalid_profile","message":"Profile denied"}"#.utf8), 0) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshMusicDNAProfile(retryDelays: [.milliseconds(1)])
    #expect(fixture.requests.count == 1)
    #expect(!model.musicDNAProfileNeedsRecovery && model.musicDNAProfileResponse == nil)
    #expect(model.musicDNAErrorMessage == DJConnectLocalization.localized(key: "ui.music.dna.profile_access", language: model.language))
}

// Pinned actual producer receipts. Scripted URLProtocol controller cases below are
// software qualification; the connected native lab is qualified separately.
private func presenceRuntimeWire(value: String = "balanced", revision: Int = 0, suffix: String = "") throws -> Data {
    var object = try #require(JSONSerialization.jsonObject(with: activeMoodRuntimeWire()) as? [String: Any])
    var runtime = try #require(object["session"] as? [String: Any])
    runtime["selected_presence"] = value; runtime["presence_revision"] = revision
    runtime["session_id"] = (runtime["session_id"] as! String) + suffix
    var broadcast = runtime["broadcast"] as! [String: Any]
    var session = broadcast["session"] as! [String: Any]
    session["session_id"] = runtime["session_id"]
    session["selected_presence"] = value; session["presence_revision"] = revision
    broadcast["session"] = session; runtime["broadcast"] = broadcast; object["session"] = runtime
    return try historyData(object)
}
private let presenceCapsWire = Data(#"{"capabilities":{"active_session_presence":true},"contract_versions":{"active_session_presence":1},"active_session_presence":{"available":true,"version":1,"path":"/api/djconnect/v1/session/presence","method":"POST","authentication":"paired_device_bearer","values":["music_only","occasional","balanced","talkative","presenter"],"default":"balanced","ordering":"expected_presence_revision","scope":"active_device_bound_owner_session"}}"#.utf8)

@Test func presenceProducerPinAndExactSixFieldOwnerRequest() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let bytes = try Data(contentsOf: root.appendingPathComponent("Fixtures/session-presence-core-b5c25f7-transport.json"))
    #expect(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() == "e42956b4f544878e4a0840a4b54d5f6bbb3a5d70ab83da52c02127f74a8ae40e")
    let entries = try #require(JSONSerialization.jsonObject(with: bytes) as? [[String: Any]])
    #expect(entries.count == 34)
    let fixture = HistoryWireFixture { _ in (200, Data(), 0) }; defer { fixture.close() }
    for value in DJConnectSessionPresenceValue.allCases {
        let request = try fixture.client().sessionPresenceRequest(sessionID: "exact", presence: value, expectedRevision: 8)
        let body = try #require(JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any])
        #expect(Set(body.keys) == ["contract_version", "client_type", "device_id", "session_id", "selected_presence", "expected_presence_revision"])
        #expect(body["selected_presence"] as? String == value.rawValue && body["expected_presence_revision"] as? Int == 8)
        #expect(request.url?.path == "/api/djconnect/v1/session/presence" && request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-fixture-token")
        #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == "djconnect-ios-ABCDEF123456")
    }
    #expect(throws: DJConnectError.self) { try fixture.client().sessionPresenceRequest(sessionID: "exact", presence: .balanced, expectedRevision: -1) }
    #expect(try JSONDecoder().decode(DJConnectActiveMoodCapabilities.self, from: presenceCapsWire).presenceAvailable)
    for replacement in ["paired_live_bearer", "receiver", "expected_mood_revision", "active_profile", "/wrong"] {
        let bad = String(decoding: presenceCapsWire, as: UTF8.self).replacingOccurrences(of: replacement == "/wrong" ? "/api/djconnect/v1/session/presence" : replacement == "expected_mood_revision" ? "expected_presence_revision" : replacement == "active_profile" ? "active_device_bound_owner_session" : "paired_device_bearer", with: replacement)
        #expect(!(try JSONDecoder().decode(DJConnectActiveMoodCapabilities.self, from: Data(bad.utf8))).presenceAvailable)
    }
    #expect(!(try JSONDecoder().decode(DJConnectActiveMoodCapabilities.self, from: Data(#"{"capabilities":{"active_session_presence":true},"contract_versions":{"active_session_presence":1}}"#.utf8))).presenceAvailable)
}

@Test(arguments: [0,1,2,3,4,5,20,21,22,23,24,25,26,27,28,29,30,31,32,33])
func presenceActualProducerResponses(_ index: Int) async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let entries = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/session-presence-core-b5c25f7-transport.json"))) as? [[String: Any]])
    let row = entries[index], request = row["request"] as! [String: Any]
    let response = try historyData(row["response"]!), status = row["status"] as! Int
    let fixture = HistoryWireFixture { _ in (status, response, 0) }; defer { fixture.close() }
    do {
        let value = try #require(DJConnectSessionPresenceValue(rawValue: request["selected_presence"] as! String))
        let received = try await fixture.client().updateSessionPresence(sessionID: request["session_id"] as! String, presence: value, expectedRevision: request["expected_presence_revision"] as! Int)
        #expect(status == 200 && received.presenceRevision == (row["response"] as! [String: Any])["presence_revision"] as? Int)
    } catch let conflict as DJConnectSessionPresenceConflict {
        #expect(status == 409 && conflict.current.sessionID == request["session_id"] as? String)
    } catch let error as DJConnectError {
        #expect(status == 401 || status == 404)
        if status == 401 { #expect(error.invalidatesSessionAuthority) }
    }
}

@Test func presenceReducerOrdersIndependentlyAndPreserves40021Projection() throws {
    let runtime = try #require(JSONDecoder().decode(DJConnectSessionResponse.self, from: presenceRuntimeWire()).resolvedSession)
    let original = runtime.broadcast
    let newest = runtime.applying(presence: .init(sessionID: runtime.id, selectedPresence: .musicOnly, presenceRevision: 4))
    #expect(newest.applying(presence: .init(sessionID: runtime.id, selectedPresence: .talkative, presenceRevision: 3)) == newest)
    #expect(newest.applying(presence: .init(sessionID: runtime.id, selectedPresence: .presenter, presenceRevision: 4)) == newest)
    #expect(newest.applying(presence: .init(sessionID: "old", selectedPresence: .presenter, presenceRevision: 99)) == newest)
    let recovered = newest.applying(broadcastState: original)
    #expect(recovered.confirmedPresence == newest.confirmedPresence)
    #expect(recovered.selectedMood == runtime.selectedMood && recovered.moodRevision == runtime.moodRevision)
    #expect(recovered.broadcast.sessionFlow == original.sessionFlow && recovered.broadcast.djMoments == original.djMoments)
    #expect(recovered.broadcast.delivery == original.delivery && recovered.broadcast.playback == original.playback)
    var newerEvent = original
    newerEvent.session.selectedPresence = .occasional; newerEvent.session.presenceRevision = 5
    #expect(newest.applying(broadcastState: newerEvent).confirmedPresence?.selectedPresence == .occasional)
    var equalConflict = original
    equalConflict.session.selectedPresence = .presenter; equalConflict.session.presenceRevision = 4
    #expect(newest.applying(broadcastState: equalConflict).confirmedPresence == newest.confirmedPresence)
    var partial = original; partial.session.selectedPresence = .presenter; partial.session.presenceRevision = nil
    #expect(newest.applying(broadcastState: partial).confirmedPresence == newest.confirmedPresence)
    var contradiction = newest
    contradiction.broadcast.session.selectedPresence = .presenter
    #expect(contradiction.confirmedPresence == nil && contradiction.presenceRevisionFloor == 4)
    #expect(contradiction.applying(presence: .init(sessionID: runtime.id, selectedPresence: .talkative, presenceRevision: 3)) == contradiction)
    #expect(contradiction.applying(broadcastState: original).confirmedPresence == nil)
    #expect(contradiction.applying(broadcastState: original).presenceRevisionFloor == 4)
    #expect(contradiction.applying(broadcastState: newerEvent).confirmedPresence?.presenceRevision == 5)
}

private final class PresenceScript: @unchecked Sendable {
    private let lock = NSLock()
    private var writeNumber = 0
    func nextWrite() -> Int { lock.withLock { writeNumber += 1; return writeNumber } }
    var writes: Int { lock.withLock { writeNumber } }
}

@Test @MainActor func presenceRapidIntentsHaveOnePendingWriteAndLatestQueue() async throws {
    let runtime = try presenceRuntimeWire(), script = PresenceScript()
    let firstReplyGate = DispatchSemaphore(value: 0)
    defer { firstReplyGate.signal() }
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, presenceCapsWire, 0) }
        if request.url!.path.hasSuffix("/session/active") { return (200, runtime, 0) }
        if request.url!.path.hasSuffix("/session/presence") {
            let number = script.nextWrite()
            let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as! [String: Any]
            #expect(body["expected_presence_revision"] as? Int == number - 1)
            if number == 1 { _ = firstReplyGate.wait(timeout: .now() + 15) }
            return (200, try historyData(["success":true,"contract_version":1,"session_id":body["session_id"]!,"selected_presence":body["selected_presence"]!,"presence_revision":number,"changed":true]), 0)
        }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshActiveDJSession(); await model.refreshActiveMoodCapability()
    let id = try #require(model.activeDJSession?.id), epoch = model.sessionHistory.responseEpoch
    model.selectActiveSessionPresence(.talkative, expectedSessionID: id, expectedEpoch: epoch)
    for _ in 0..<120 where script.writes == 0 {
        try await Task.sleep(for: .milliseconds(25))
    }
    #expect(model.activePresencePending && model.activeDJSession?.confirmedPresence?.selectedPresence == .balanced)
    model.selectActiveSessionPresence(.occasional, expectedSessionID: id, expectedEpoch: epoch)
    model.selectActiveSessionPresence(.musicOnly, expectedSessionID: id, expectedEpoch: epoch)
    model.selectActiveSessionPresence(.presenter, expectedSessionID: id, expectedEpoch: epoch)
    #expect(script.writes == 1 && model.activePresenceDesired == .presenter)
    firstReplyGate.signal()
    for _ in 0..<50 { if !model.activePresencePending { break }; try await Task.sleep(for: .milliseconds(20)) }
    #expect(script.writes == 2 && !model.activePresencePending && model.activePresenceDesired == nil)
    #expect(model.activeDJSession?.confirmedPresence?.selectedPresence == .presenter && model.activeDJSession?.confirmedPresence?.presenceRevision == 2)
    let writes = fixture.requests.filter { $0.url!.path.hasSuffix("/session/presence") }
    #expect(writes.count == 2)
    #expect(model.activeDJSession?.selectedMood == (try JSONDecoder().decode(DJConnectSessionResponse.self, from: runtime).resolvedSession?.selectedMood))
}

@Test(arguments: ["conflict", "lost", "denial", "background", "replacement"])
@MainActor func presenceStopsAfterUnknownOrWithdrawnOutcome(_ scenario: String) async throws {
    let runtime = try presenceRuntimeWire(), script = PresenceScript()
    let after = try presenceRuntimeWire(value: "music_only", revision: 4, suffix: scenario == "replacement" ? "-new" : "")
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, presenceCapsWire, 0) }
        if request.url!.path.hasSuffix("/session/active") { return (200, script.writes > 0 ? after : runtime, 0) }
        if request.url!.path.hasSuffix("/session/presence") {
            _ = script.nextWrite()
            if scenario == "lost" { throw HistoryWireDelayedFailure(error: URLError(.networkConnectionLost), delay: 0.08) }
            let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as! [String: Any]
            if scenario == "denial" { return (401, Data(#"{"success":false,"error":"unauthorized"}"#.utf8), 0.08) }
            if scenario == "conflict" { return (409, try historyData(["success":false,"error":"presence_revision_conflict","current":["session_id":body["session_id"]!,"selected_presence":"music_only","presence_revision":4]]), 0.08) }
            return (200, try historyData(["success":true,"contract_version":1,"session_id":body["session_id"]!,"selected_presence":"presenter","presence_revision":1,"changed":true]), 0.08)
        }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshActiveDJSession(); await model.refreshActiveMoodCapability()
    let id = try #require(model.activeDJSession?.id), epoch = model.sessionHistory.responseEpoch
    model.selectActiveSessionPresence(.presenter, expectedSessionID: id, expectedEpoch: epoch)
    try await Task.sleep(for: .milliseconds(20))
    if scenario == "background" { model.markInactiveSession() }
    if scenario == "replacement" { await model.refreshActiveDJSession() }
    for _ in 0..<50 { if !model.activePresencePending { break }; try await Task.sleep(for: .milliseconds(20)) }
    try await Task.sleep(for: .milliseconds(110))
    #expect(script.writes == 1 && !model.activePresencePending)
    if scenario == "denial" { #expect(model.activeDJSession == nil && !model.activePresenceAvailable && model.askDJMessages.isEmpty) }
    if scenario == "conflict" || scenario == "lost" {
        #expect(model.activePresenceRequiresDecision && model.activePresenceDesired == .presenter)
        #expect(model.activeDJSession?.confirmedPresence?.presenceRevision == 4 && model.activeDJSession?.confirmedPresence?.selectedPresence == .musicOnly)
        model.acceptCurrentSessionPresence(expectedSessionID: id, expectedEpoch: epoch)
        #expect(!model.activePresenceRequiresDecision && model.activePresenceDesired == nil)
    }
    if scenario == "background" { #expect(!model.activePresenceAvailable && model.activePresenceDesired == nil) }
    if scenario == "replacement" {
        #expect(model.activeDJSession?.id == id + "-new" && model.activeDJSession?.confirmedPresence?.presenceRevision == 4)
        #expect(model.activePresenceDesired == nil && !model.activePresenceRequiresDecision)
        model.selectActiveSessionPresence(.talkative, expectedSessionID: id, expectedEpoch: epoch)
        #expect(script.writes == 1)
    }
}

private func presenceRequestBody(_ request: URLRequest) throws -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { throw DJConnectError.invalidResponse }
    stream.open(); defer { stream.close() }
    var result = Data(), buffer = [UInt8](repeating: 0, count: 4096)
    while true {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count < 0 { throw stream.streamError ?? DJConnectError.invalidResponse }
        if count == 0 { return result }
        result.append(buffer, count: count)
    }
}

@Test @MainActor func presenceSingleAttemptDoesNotReplayMutationOnRemoteRoute() async throws {
    let fixture = HistoryWireFixture { _ in (200, Data(), 0) }; defer { fixture.close() }
    let manager = DJConnectHATransportManager(localURL: URL(string: "http://local.test"), remoteURL: URL(string: "https://remote.test"), allowsRemoteFallback: true, clientFactory: { _ in fixture.client() })
    var attempts = 0
    do {
        _ = try await manager.perform(allowsOperationReplay: false) { _ -> Bool in attempts += 1; throw DJConnectError.network(message: "reply lost") }
        Issue.record("Lost mutation must remain unknown")
    } catch { #expect(attempts == 1) }
    attempts = 0
    let read = try await manager.perform { _ -> Bool in
        attempts += 1
        if attempts == 1 { throw DJConnectError.network(message: "LAN unavailable") }
        return true
    }
    #expect(read && attempts == 2, "Ordinary recovery reads still retain the existing HTTP fallback")
}

@Test @MainActor func presenceActualActiveReadRetainsRevisionFloorThroughContradiction() async throws {
    var first = try #require(JSONSerialization.jsonObject(with: presenceRuntimeWire(value: "balanced", revision: 4)) as? [String: Any])
    var session = first["session"] as! [String: Any], broadcast = session["broadcast"] as! [String: Any]
    var metadata = broadcast["session"] as! [String: Any]
    metadata["selected_presence"] = "presenter"; broadcast["session"] = metadata; session["broadcast"] = broadcast; first["session"] = session
    let contradiction = try historyData(first), older = try presenceRuntimeWire(value: "talkative", revision: 3), newer = try presenceRuntimeWire(value: "occasional", revision: 5)
    let script = PresenceScript(), phase = PresenceReadPhase()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/session/active") {
            _ = script.nextWrite()
            // Broadcast HTTP recovery may also read active state. Each phase
            // describes server state, rather than advancing for each reader.
            let index = phase.value
            return (200, index == 0 ? contradiction : index == 1 ? older : newer, 0)
        }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshActiveDJSession()
    #expect(model.activeDJSession?.confirmedPresence == nil && model.activeDJSession?.presenceRevisionFloor == 4, "Active HTTP reads=\(script.writes); floor=\(String(describing: model.activeDJSession?.presenceRevisionFloor)); confirmed=\(String(describing: model.activeDJSession?.confirmedPresence?.selectedPresence))")
    phase.value = 1; await model.refreshActiveDJSession()
    #expect(model.activeDJSession?.confirmedPresence == nil && model.activeDJSession?.presenceRevisionFloor == 4, "Active HTTP reads=\(script.writes); floor=\(String(describing: model.activeDJSession?.presenceRevisionFloor)); confirmed=\(String(describing: model.activeDJSession?.confirmedPresence?.selectedPresence))")
    phase.value = 2; await model.refreshActiveDJSession()
    #expect(model.activeDJSession?.confirmedPresence?.selectedPresence == .occasional && model.activeDJSession?.presenceRevisionFloor == 5)
}

@Test @MainActor func presenceCompleteHTTPRuntimeCannotConfirmOneHalfOfNewerContradiction() async throws {
    let first = try presenceRuntimeWire(value: "balanced", revision: 4)
    var contradiction = try #require(JSONSerialization.jsonObject(with: presenceRuntimeWire(value: "talkative", revision: 5)) as? [String: Any])
    var root = contradiction["session"] as! [String: Any], broadcast = root["broadcast"] as! [String: Any]
    var tuple = broadcast["session"] as! [String: Any]; tuple["selected_presence"] = "presenter"
    broadcast["session"] = tuple; root["broadcast"] = broadcast; contradiction["session"] = root
    let conflictingBytes = try historyData(contradiction), last = try presenceRuntimeWire(value: "occasional", revision: 6)
    let phase = PresenceReadPhase()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/session/active") {
            let index = phase.value
            return (200, index == 0 || index == 2 ? first : index == 1 ? conflictingBytes : last, 0)
        }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshActiveDJSession()
    #expect(model.activeDJSession?.confirmedPresence?.presenceRevision == 4)
    phase.value = 1; await model.refreshActiveDJSession()
    #expect(model.activeDJSession?.confirmedPresence == nil && model.activeDJSession?.presenceRevisionFloor == 5)
    phase.value = 2; await model.refreshActiveDJSession()
    #expect(model.activeDJSession?.confirmedPresence == nil && model.activeDJSession?.presenceRevisionFloor == 5)
    phase.value = 3; await model.refreshActiveDJSession()
    #expect(model.activeDJSession?.confirmedPresence?.selectedPresence == .occasional && model.activeDJSession?.presenceRevisionFloor == 6)
    // Same projection is forwarded by the existing HTTP Broadcast recovery.
    let initial = try #require(JSONDecoder().decode(DJConnectSessionResponse.self, from: first).resolvedSession)
    let incoming = try #require(JSONDecoder().decode(DJConnectSessionResponse.self, from: conflictingBytes).resolvedSession)
    let recovery = initial.applying(broadcastState: incoming.presenceSafeBroadcast)
    #expect(recovery.confirmedPresence == nil && recovery.presenceRevisionFloor == 5)
    let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(recovery.broadcast)) as! [String: Any]
    #expect(encoded["presenceConflictRevision"] == nil && encoded["presence_conflict_revision"] == nil)
}

private final class PresenceReadPhase: @unchecked Sendable {
    private let lock = NSLock()
    private var phase = 0
    var value: Int {
        get { lock.withLock { phase } }
        set { lock.withLock { phase = newValue } }
    }
}

private final class PresenceModes: @unchecked Sendable {
    private let lock = NSLock()
    private var modes: [DJConnectHAConnectionMode] = []
    func record(_ value: DJConnectHAConnectionMode) { lock.withLock { modes.append(value) } }
    var values: [DJConnectHAConnectionMode] { lock.withLock { modes } }
}

@Test(arguments: [DJConnectHAConnectionMode.local, .remote])
@MainActor func presenceTypedCASConflictKeepsReachableRoute(_ mode: DJConnectHAConnectionMode) async throws {
    let fixture = HistoryWireFixture { _ in (409, Data(#"{"success":false,"error":"presence_revision_conflict","current":{"session_id":"current","selected_presence":"music_only","presence_revision":4}}"#.utf8), 0) }
    defer { fixture.close() }
    let modes = PresenceModes()
    let manager = DJConnectHATransportManager(localURL: mode == .local ? fixture.baseURL : nil, remoteURL: mode == .remote ? fixture.baseURL : URL(string: "https://remote.test"), allowsRemoteFallback: true, clientFactory: { _ in fixture.client() }, modeReporter: { value, _ in modes.record(value) })
    do {
        _ = try await manager.perform(allowsOperationReplay: false) { try await $0.updateSessionPresence(sessionID: "current", presence: .presenter, expectedRevision: 3) }
        Issue.record("Expected authorized conflict")
    } catch let conflict as DJConnectSessionPresenceConflict {
        #expect(conflict.current.presenceRevision == 4)
    }
    #expect(modes.values == [mode] && fixture.requests.count == 1)
}

@Test @MainActor func presenceConflictRetainsOwnerGrantAndExplicitDecision() async throws {
    var caps = try #require(JSONSerialization.jsonObject(with: activeMoodCapsWire) as? [String: Any])
    let presence = try #require(JSONSerialization.jsonObject(with: presenceCapsWire) as? [String: Any])
    var booleans = caps["capabilities"] as! [String: Bool], versions = caps["contract_versions"] as! [String: Int]
    booleans["active_session_presence"] = true; versions["active_session_presence"] = 1
    caps["capabilities"] = booleans; caps["contract_versions"] = versions; caps["active_session_presence"] = presence["active_session_presence"]
    let capabilities = try historyData(caps), runtime = try presenceRuntimeWire()
    let history = try historyData(try #require(historyObject()["later_historical_answer"]))
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, capabilities, 0) }
        if request.url!.path.hasSuffix("/session/active") { return (200, runtime, 0) }
        if request.url!.path.hasSuffix("ask_dj/history") { return (200, history, 0) }
        if request.url!.path.hasSuffix("/session/presence") {
            let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as! [String: Any]
            return (409, try historyData(["success":false,"error":"presence_revision_conflict","current":["session_id":body["session_id"]!,"selected_presence":"music_only","presence_revision":4]]), 0)
        }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare(); await model.refreshActiveDJSession(); await model.refreshActiveMoodCapability()
    #expect(model.sessionHistory.hasAuthorizedOwner && model.activeMoodAvailable)
    let epoch = model.sessionHistory.responseEpoch, id = try #require(model.activeDJSession?.id)
    model.selectActiveSessionPresence(.presenter, expectedSessionID: id, expectedEpoch: epoch)
    for _ in 0..<30 { if !model.activePresencePending { break }; try await Task.sleep(for: .milliseconds(20)) }
    await Task.yield()
    #expect(model.activePresenceRequiresDecision && model.activePresenceDesired == .presenter)
    #expect(model.sessionHistory.hasAuthorizedOwner && model.sessionHistory.responseEpoch == epoch)
    #expect(model.haConnectionMode == .local && model.pairingStatus == .paired && model.activeMoodAvailable)
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/session/presence") }.count == 1)
}

@Test @MainActor func queueSelectionRefreshesQueueWhileStatusRefreshIsBusy() async throws {
    let wire = HistoryWireFixture { request in
        let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any]
        switch body?["command"] as? String {
        case "play_context_at": return (200, Data(#"{"success":true}"#.utf8), 0)
        case "queue": return (200, Data(#"{"success":true,"queue":[{"title":"Next track","uri":"spotify:track:next"}]}"#.utf8), 0)
        default: return (404, Data(), 0)
        }
    }
    defer { wire.close() }
    let (model, defaults, name) = wire.model()
    defer { defaults.removePersistentDomain(forName: name) }
    model.pairingStatus = .paired
    model.isRefreshing = true
    let selected = DJConnectQueueItem(title: "Selected track", uri: "spotify:track:selected")
    model.queueItems = [selected]
    model.startQueueItem(selected, at: 0)
    for _ in 0..<100 {
        // Rows publish before the scheduled refresh's completion callback clears
        // loading. Wait for the operation we assert below, not its first effect.
        if model.queueItems.first?.title == "Next track", model.loadingQueueItemIndex == nil { break }
        try await Task.sleep(for: .milliseconds(25))
    }
    #expect(model.queueItems.map(\.title) == ["Next track"])
    #expect(model.loadingQueueItemIndex == nil)
    let commands = try wire.requests.compactMap { request in
        (try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any])?["command"] as? String
    }
    #expect(commands == ["play_context_at", "queue"])
    #expect(model.isRefreshing) // Queue refresh does not take over the status refresh.
}

@Test @MainActor func queueSelectionWaitsForOlderQueueReadThenFetchesFreshRows() async throws {
    let counter = HTTPRecoveryActiveReadCounter()
    let wire = HistoryWireFixture { request in
        let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any]
        switch body?["command"] as? String {
        case "play_context_at": return (200, Data(#"{"success":true}"#.utf8), 0)
        case "queue":
            if counter.next() == 1 {
                return (200, Data(#"{"success":true,"queue":[{"title":"Old queue","uri":"spotify:track:old"}]}"#.utf8), 1.6)
            }
            return (200, Data(#"{"success":true,"queue":[{"title":"Fresh queue","uri":"spotify:track:fresh"}]}"#.utf8), 0)
        default: return (404, Data(), 0)
        }
    }
    defer { wire.close() }
    let (model, defaults, name) = wire.model()
    defer { defaults.removePersistentDomain(forName: name) }
    model.pairingStatus = .paired
    model.isRefreshing = true
    let selected = DJConnectQueueItem(title: "Selected track", uri: "spotify:track:selected")
    model.queueItems = [selected]
    let olderRead = Task { await model.refreshQueue() }
    for _ in 0..<30 {
        if model.isLoadingQueue { break }
        try await Task.sleep(for: .milliseconds(20))
    }
    #expect(model.isLoadingQueue)
    model.startQueueItem(selected, at: 0)
    for _ in 0..<140 {
        // Rows publish before the command-refresh task finishes its cleanup.
        // Observe completion as well; keep the final loading-state assertion.
        if model.queueItems.first?.title == "Fresh queue", model.loadingQueueItemIndex == nil { break }
        try await Task.sleep(for: .milliseconds(25))
    }
    _ = await olderRead.value
    #expect(model.queueItems.map(\.title) == ["Fresh queue"])
    #expect(model.loadingQueueItemIndex == nil)
    let commands = try wire.requests.compactMap { request in
        (try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any])?["command"] as? String
    }
    #expect(commands == ["queue", "play_context_at", "queue"])
}

@Test(arguments: ["track", "playlist"]) @MainActor
func activeSessionProjectsLivePlayNowWithoutPromotingArchivedActions(kind: String) async throws {
    let receipt = try historyObject()
    let sessionID = try #require(receipt["session_id"] as? String)
    let timelineData = try historyData(try #require(receipt["archived_timeline"]))
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: timelineData)
    let entry = try #require(page.entries.first { $0.kind == .conversationDJ })
    var responseObject = try #require(receipt["text_turn"] as? [String: Any])
    let playbackCommand = kind == "playlist" ? "start_playlist" : "play_track"
    let actionObject: [String: Any] = ["id":"live-play-now", "title":"Play offered " + kind,
        "kind":kind, "uri":"spotify:" + kind + ":0123456789abcdefghijkL", "command":playbackCommand]
    var assistant = try #require(responseObject["assistant_message"] as? [String: Any])
    assistant["playback_actions"] = [actionObject]
    responseObject["assistant_message"] = assistant
    responseObject["playback_actions"] = [actionObject]
    responseObject["history_revision"] = 4
    var confirmation = try #require(responseObject["conversation"] as? [String: Any])
    confirmation["entry_ids"] = [] // This case tests live delivery independent of anchor opening.
    confirmation["context"] = ["session_id": sessionID]
    responseObject["conversation"] = confirmation
    let responseData = try historyData(responseObject)
    let profileHistory = try historyData(try #require(receipt["later_historical_answer"]))
    var runtimeObject = try #require(JSONSerialization.jsonObject(with: activeMoodRuntimeWire()) as? [String: Any])
    var runtime = try #require(runtimeObject["session"] as? [String: Any])
    runtime["session_id"] = sessionID
    var broadcast = try #require(runtime["broadcast"] as? [String: Any])
    var broadcastSession = try #require(broadcast["session"] as? [String: Any])
    broadcastSession["session_id"] = sessionID; broadcast["session"] = broadcastSession
    runtime["broadcast"] = broadcast; runtimeObject["session"] = runtime
    let runtimeData = try historyData(runtimeObject)
    let wire = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, activeMoodCapsWire, 0) }
        if request.url!.path.hasSuffix("/session/active") { return (200, runtimeData, 0) }
        if request.url!.path.hasSuffix("/ask_dj/message") { return (200, responseData, 0) }
        if request.url!.path.hasSuffix("/command") {
            let command = (try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any])?["command"] as? String
            if command == "status" {
                return (200, Data(#"{"success":true,"playback":{"track_name":"Offered track","is_playing":true}}"#.utf8), 0)
            }
            return (200, Data(#"{"success":true}"#.utf8), 0)
        }
        if request.url!.path.contains("session/history") { return (200, timelineData, 0) }
        return (200, profileHistory, 0)
    }
    defer { wire.close() }
    let (model, defaults, name) = wire.model()
    defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    await model.refreshActiveDJSession()
    #expect(model.sessionHistory.liveMessage(for: entry, activeSessionID: sessionID) == nil)
    _ = try await model.sessionHistory.sendExistingText("Offer a track", clientMessageID: "question-0")
    let projected = try #require(model.sessionHistory.liveMessage(for: entry, activeSessionID: sessionID))
    let offered = try #require(projected.renderablePlaybackActions.first)
    #expect(offered.id == "live-play-now" && offered.kind == kind && offered.isRecommendationAction)
    #expect(model.sessionHistory.liveMessage(for: entry, activeSessionID: nil) == nil)
    #expect(model.sessionHistory.liveMessage(for: entry, activeSessionID: "another-session") == nil)
    var wrongText = entry; wrongText.text = "Unrelated answer"
    #expect(model.sessionHistory.liveMessage(for: wrongText, activeSessionID: sessionID) == nil)
    let capturedEpoch = model.sessionHistory.responseEpoch
    var forged = offered; forged.uri = "spotify:track:another"
    model.sessionHistory.playLiveAction(forged, for: entry, expectedEpoch: capturedEpoch)
    #expect(model.playingAskDJActionID == nil)
    model.sessionHistory.playLiveAction(offered, for: entry, expectedEpoch: UUID())
    #expect(model.playingAskDJActionID == nil)
    #expect(!wire.requests.contains { $0.url!.path.hasSuffix("/command") })
    model.sessionHistory.playLiveAction(offered, for: entry, expectedEpoch: capturedEpoch)
    #expect(model.playingAskDJActionID == offered.id)
    for _ in 0..<120 {
        if model.playingAskDJActionID == nil { break }
        try await Task.sleep(for: .milliseconds(25))
    }
    #expect(model.playingAskDJActionID == nil)
    let commands = try wire.requests.filter { $0.url!.path.hasSuffix("/command") }.compactMap {
        (try JSONSerialization.jsonObject(with: presenceRequestBody($0)) as? [String: Any])?["command"] as? String
    }
    #expect(commands.filter { $0 == playbackCommand }.count == 1)
    #expect(commands.contains("status"))
    let requestCount = wire.requests.count
    model.markInactiveSession()
    #expect(model.sessionHistory.liveMessage(for: entry, activeSessionID: sessionID) == nil)
    model.sessionHistory.playLiveAction(offered, for: entry, expectedEpoch: capturedEpoch)
    #expect(model.playingAskDJActionID == nil)
    #expect(wire.requests.count == requestCount)
    let archiveOnly = SessionTimelineRenderCache().snapshot([entry], sessionID: sessionID, epoch: UUID())
    #expect(archiveOnly.first?.message.playbackActions.isEmpty == true)
}

@Test(arguments: [true, false]) @MainActor
func sessionPlayNowWithdrawalFencesDispatchAndLateResponse(beforeDispatch: Bool) async throws {
    let replyGate = DispatchSemaphore(value: 0)
    defer { replyGate.signal() }
    let wire = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/command") {
            if !beforeDispatch { _ = replyGate.wait(timeout: .now() + 15) }
            return (200, Data(#"{"success":true,"assistant_message":{"id":"late-answer","role":"assistant","text":"Stale playback answer","created_at":"2026-10-14T00:00:00Z"}}"#.utf8), 0)
        }
        return (404, Data(), 0)
    }
    defer { wire.close() }
    let (model, defaults, name) = wire.model()
    defer { defaults.removePersistentDomain(forName: name) }
    model.pairingStatus = .paired
    let offered = try JSONDecoder().decode(DJConnectAskDJPlaybackAction.self,
        from: Data(#"{"id":"scoped-play","title":"Play track","kind":"track","command":"play_track","uri":"spotify:track:0123456789abcdefghijkL"}"#.utf8))
    model.playAskDJRecommendation(offered, isStillValid: { true })
    if !beforeDispatch {
        for _ in 0..<120 {
            if wire.requests.contains(where: { $0.url!.path.hasSuffix("/command") }) { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(wire.requests.contains { $0.url!.path.hasSuffix("/command") })
    }
    model.sessionHistory.suspend()
    let newerResponse = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self,
        from: Data(#"{"history_revision":1,"clear_revision":0,"assistant_message":{"id":"new-answer","role":"assistant","text":"New owner display","created_at":"2026-10-14T00:00:00Z"}}"#.utf8))
    #expect(model.applyProfileConversationResponse(newerResponse, fallback: nil))
    let newer = model.askDJMessages
    #expect(newer.first?.text == "New owner display")
    replyGate.signal()
    try await Task.sleep(for: .milliseconds(250))
    #expect(model.askDJMessages == newer)
    #expect(model.playingAskDJActionID == nil)
    #expect(model.askDJErrorMessage == nil)
    #expect(wire.requests.filter { $0.url!.path.hasSuffix("/command") }.count == (beforeDispatch ? 0 : 1))
}

@Test(arguments: ["status", "devices"], [false, true]) @MainActor
func sessionPlayNowFollowUpReadsDoNotApplyAfterWithdrawal(stage: String, fail: Bool) async throws {
    let replyGate = DispatchSemaphore(value: 0)
    defer { replyGate.signal() }
    let wire = HistoryWireFixture { request in
        let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any]
        let command = body?["command"] as? String
        if command == stage {
            _ = replyGate.wait(timeout: .now() + 15)
            if fail { return (503, Data(#"{"success":false,"error":"backend_unavailable"}"#.utf8), 0) }
        }
        if command == "status" {
            return (200, Data(#"{"success":true,"playback":{"track_name":"Stale track","is_playing":true}}"#.utf8), 0)
        }
        if command == "devices" {
            return (200, Data(#"{"success":true,"devices":[{"id":"old-output","name":"Old output"}]}"#.utf8), 0)
        }
        if command == "queue" { return (200, Data(#"{"success":true,"queue":[{"title":"Old queue"}]}"#.utf8), 0) }
        if command == "playlists" { return (200, Data(#"{"success":true,"playlists":[]}"#.utf8), 0) }
        return (200, Data(#"{"success":true}"#.utf8), 0)
    }
    defer { wire.close() }
    let (model, defaults, name) = wire.model()
    defer { defaults.removePersistentDomain(forName: name) }
    model.pairingStatus = .paired
    let offered = try JSONDecoder().decode(DJConnectAskDJPlaybackAction.self,
        from: Data(#"{"id":"followup-play","title":"Play track","kind":"track","command":"play_track","uri":"spotify:track:0123456789abcdefghijkL"}"#.utf8))
    model.playAskDJRecommendation(offered, isStillValid: { true })
    func commands() throws -> [String] {
        try wire.requests.compactMap {
            (try JSONSerialization.jsonObject(with: presenceRequestBody($0)) as? [String: Any])?["command"] as? String
        }
    }
    for _ in 0..<120 {
        if try commands().contains(stage) { break }
        try await Task.sleep(for: .milliseconds(25))
    }
    #expect(try commands().contains(stage))
    model.sessionHistory.suspend()
    let freshPlayback = try JSONDecoder().decode(DJConnectPlayback.self,
        from: Data(#"{"track_name":"New owner track","is_playing":false}"#.utf8))
    model.apply(playback: freshPlayback)
    model.queueItems = [DJConnectQueueItem(title: "New owner queue")]
    replyGate.signal()
    try await Task.sleep(for: .milliseconds(250))
    #expect(model.playback == freshPlayback)
    #expect(model.queueItems.map(\.title) == ["New owner queue"])
    #expect(model.pairingStatus == .paired && model.backendAvailable)
    #expect(model.askDJErrorMessage == nil && model.playingAskDJActionID == nil)
    if stage == "status" {
        #expect(try commands() == ["play_track", "status"])
    }
}

@Test func askDJNewestFirstSearchKeepsSelectedMessageWhenReplyIsPrepended() {
    let oldA = UUID(), oldB = UUID(), newReply = UUID()
    let results = [newReply, oldA, oldB]
    let index = askDJSearchResultIndex(preserving: oldB, fallback: 1, in: results)
    #expect(results[index] == oldB)
    #expect(index == 2)
    #expect(askDJSearchResultIndex(preserving: oldB, fallback: 1, in: [newReply, oldA]) == 1)
    #expect(askDJSearchResultIndex(preserving: nil, fallback: 0, in: results) == 0)
    #expect(askDJSearchResultIndex(preserving: oldB, fallback: 1, in: []) == 0)
}

@Test @MainActor func presenceCapabilityReadFailureIsTransientAndRetryRetainsRevisionZero() async throws {
    let gate = HistoryAuthorityGate()
    let runtime = try presenceRuntimeWire()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/session/active") { return (200, runtime, 0) }
        if request.url!.path.hasSuffix("/capabilities") {
            return gate.denied ? (503, Data(#"{"error":"temporarily_unavailable"}"#.utf8), 0) : (200, presenceCapsWire, 0)
        }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshActiveDJSession()
    let initial = try #require(model.activeDJSession?.confirmedPresence)
    #expect(initial.selectedPresence == .balanced && initial.presenceRevision == 0)
    await model.refreshActiveMoodCapability()
    #expect(model.activePresenceCapabilityStatus == .supported && model.activePresenceAvailable)
    gate.denied = true
    await model.refreshActiveMoodCapability()
    #expect(model.activePresenceCapabilityStatus == .temporarilyUnavailable && !model.activePresenceAvailable)
    #expect(model.activeDJSession?.confirmedPresence == initial)
    gate.denied = false
    await model.refreshActiveMoodCapability()
    #expect(model.activePresenceCapabilityStatus == .supported && model.activePresenceAvailable)
    #expect(model.activeDJSession?.confirmedPresence == initial)
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
}

@Test @MainActor func presenceCapabilityLateReadCannotOverrideNewerUnsupportedState() async throws {
    let gate = HistoryAuthorityGate()
    let runtime = try presenceRuntimeWire()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/session/active") { return (200, runtime, 0) }
        if request.url!.path.hasSuffix("/capabilities") {
            return gate.denied ? (200, Data(#"{}"#.utf8), 0) : (200, presenceCapsWire, 0.2)
        }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshActiveDJSession()
    let initial = model.activeDJSession?.confirmedPresence
    let first = Task { await model.refreshActiveMoodCapability() }
    for _ in 0..<100 where !fixture.requests.contains(where: { $0.url?.path.hasSuffix("/capabilities") == true }) {
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(model.activePresenceCapabilityStatus == .loading)
    gate.denied = true
    await model.refreshActiveMoodCapability()
    #expect(model.activePresenceCapabilityStatus == .unsupported)
    await first.value
    #expect(model.activePresenceCapabilityStatus == .unsupported && !model.activePresenceAvailable)
    #expect(model.activeDJSession?.confirmedPresence == initial)
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
}

@Test @MainActor func presenceCapabilityMalformedResponseIsNotUnsupportedOrConfirmed() async throws {
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") {
            return (200, Data(#"{"capabilities":{"active_session_presence":"yes"}}"#.utf8), 0)
        }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshActiveMoodCapability()
    #expect(model.activePresenceCapabilityStatus == .incompatibleResponse)
    #expect(!model.activePresenceAvailable && model.activeDJSession?.confirmedPresence == nil)
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
}

@Test(arguments: [false, true]) @MainActor
func outputSelectionImmediatelyReadsConfirmedDevicesAfterAcceptance(acceptanceIncludesOldDevices: Bool) async throws {
    let wire = HistoryWireFixture { request in
        let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any]
        switch body?["command"] as? String {
        case "set_output":
            let reply = acceptanceIncludesOldDevices
                ? #"{"success":true,"devices":[{"id":"old","name":"Old speaker","active":true}]}"#
                : #"{"success":true}"#
            return (200, Data(reply.utf8), 0)
        case "devices": return (200, Data(#"{"success":true,"devices":[{"id":"old","name":"Old speaker","active":false},{"id":"new","name":"New speaker","active":true}]}"#.utf8), 0)
        default: return (404, Data(), 0)
        }
    }
    defer { wire.close() }
    let (model, defaults, name) = wire.model()
    defer { defaults.removePersistentDomain(forName: name) }
    model.pairingStatus = .paired
    model.isRefreshing = true
    model.apply(playback: DJConnectPlayback(device: DJConnectPlaybackDevice(id: "old", name: "Old speaker")))
    model.selectOutput(DJConnectOutputDevice(id: "new", name: "New speaker"))
    for _ in 0..<40 {
        if model.availableOutputs.first(where: { $0.id == "new" })?.active == true { break }
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(model.availableOutputs.filter { $0.active == true }.map(\.id) == ["new"])
    let commands = try wire.requests.compactMap { request in
        (try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any])?["command"] as? String
    }
    #expect(commands == ["set_output", "devices"])
    #expect(model.isRefreshing) // Device confirmation is independent of a busy status refresh.
}

@Test @MainActor func outputTransferOneTapSurvivesDelayedConfirmationWithoutGlobalRefresh() async throws {
    let reads = HTTPRecoveryActiveReadCounter()
    let wire = HistoryWireFixture { request in
        let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any]
        switch body?["command"] as? String {
        case "set_output":
            #expect(body?["value"] as? String == "new") // Stable ID, never the display label.
            return (200, Data(#"{"success":true}"#.utf8), 0.1)
        case "devices":
            if reads.next() == 1 {
                return (200, Data(#"{"success":true,"devices":[{"id":"old","name":"Old speaker","active":true},{"id":"new","name":"New speaker","active":false}]}"#.utf8), 0)
            }
            return (200, Data(#"{"success":true,"devices":[{"id":"old","name":"Old speaker","active":false},{"id":"new","name":"New speaker","active":true}]}"#.utf8), 0)
        case "status": return (200, Data(#"{"success":true,"playback":{"device":{"id":"old","name":"Old speaker"}}}"#.utf8), 0)
        default: return (404, Data(), 0)
        }
    }
    defer { wire.close() }
    let (model, defaults, name) = wire.model(); defer { defaults.removePersistentDomain(forName: name) }
    model.pairingStatus = .paired
    model.apply(commandResponse: DJConnectCommandResponse(success: true, devices: [
        DJConnectOutputDevice(id: "old", name: "Old speaker", active: true),
        DJConnectOutputDevice(id: "new", name: "New speaker", active: false)
    ]))
    let output = DJConnectOutputDevice(id: "new", name: "New speaker")
    model.selectOutput(output)
    #expect(model.pendingOutputSelectionID == "new") // Synchronous local feedback.
    #expect(model.availableOutputs.first(where: { $0.id == "new" })?.active != true)
    model.selectOutput(output) // Duplicate tap must never replay the transfer write.
    for _ in 0..<150 {
        #expect(!model.isRefreshing)
        if model.pendingOutputSelectionID == nil { break }
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(model.pendingOutputSelectionID == nil)
    #expect(model.selectedOutput == "New speaker")
    #expect(model.availableOutputs.filter { $0.active == true }.map(\.id) == ["new"])
    let commands = try wire.requests.compactMap { request in
        (try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any])?["command"] as? String
    }
    #expect(commands == ["set_output", "devices", "status", "devices"])
}

@Test @MainActor func rejectedOutputTransferClearsPendingAndKeepsConfirmedSpeaker() async throws {
    let wire = HistoryWireFixture { _ in (200, Data(#"{"success":false,"error":"transfer_failed"}"#.utf8), 0.05) }
    defer { wire.close() }
    let (model, defaults, name) = wire.model(); defer { defaults.removePersistentDomain(forName: name) }
    model.pairingStatus = .paired
    model.apply(commandResponse: DJConnectCommandResponse(success: true, devices: [
        DJConnectOutputDevice(id: "old", name: "Old speaker", active: true),
        DJConnectOutputDevice(id: "new", name: "New speaker", active: false)
    ]))
    model.selectOutput(DJConnectOutputDevice(id: "new", name: "New speaker"))
    for _ in 0..<60 where model.pendingOutputSelectionID != nil { try await Task.sleep(for: .milliseconds(10)) }
    #expect(model.pendingOutputSelectionID == nil)
    #expect(model.selectedOutput == "Old speaker")
    #expect(model.availableOutputs.filter { $0.active == true }.map(\.id) == ["old"])
    #expect(model.userNotice != nil)
    #expect(!model.isRefreshing)
    #expect(wire.requests.count == 1)
}

@Test @MainActor func unconfirmedOutputTransferStopsWaitingWithoutReplayingWrite() async throws {
    let wire = HistoryWireFixture { request in
        let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any]
        if body?["command"] as? String == "set_output" { return (200, Data(#"{"success":true}"#.utf8), 0) }
        return (200, Data(#"{"success":true,"playback":{"device":{"id":"old","name":"Old speaker"}},"devices":[{"id":"old","name":"Old speaker","active":true},{"id":"new","name":"New speaker","active":false}]}"#.utf8), 0)
    }
    defer { wire.close() }
    let (model, defaults, name) = wire.model(); defer { defaults.removePersistentDomain(forName: name) }
    model.pairingStatus = .paired
    model.apply(commandResponse: DJConnectCommandResponse(success: true, devices: [
        DJConnectOutputDevice(id: "old", name: "Old speaker", active: true)
    ]))
    model.selectOutput(DJConnectOutputDevice(id: "new", name: "New speaker"))
    for _ in 0..<200 where model.pendingOutputSelectionID != nil {
        #expect(!model.isRefreshing)
        try await Task.sleep(for: .milliseconds(20))
    }
    #expect(model.pendingOutputSelectionID == nil)
    #expect(model.selectedOutput == "Old speaker")
    #expect(model.userNotice?.text == DJConnectLocalization.localized(key: "ui.output.switch.unconfirmed", language: model.language))
    let commands = try wire.requests.compactMap { request in
        (try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any])?["command"] as? String
    }
    #expect(commands.filter { $0 == "set_output" }.count == 1)
    #expect(commands.filter { $0 == "devices" }.count == 4)
}

@Test @MainActor func outputTransferRejectsStatusSnapshotStartedBeforeSelection() async throws {
    let reads = HTTPRecoveryActiveReadCounter()
    let wire = HistoryWireFixture { request in
        let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any]
        switch body?["command"] as? String {
        case "status":
            _ = reads.next()
            return (200, Data(#"{"success":true,"playback":{"device":{"id":"old","name":"Old speaker"}},"devices":[{"id":"old","name":"Old speaker","active":true}]}"#.utf8), 0.25)
        case "set_output": return (200, Data(#"{"success":true}"#.utf8), 0)
        case "devices": return (200, Data(#"{"success":true,"devices":[{"id":"new","name":"New speaker","active":true}]}"#.utf8), 0)
        default: return (404, Data(), 0)
        }
    }
    defer { wire.close() }
    let (model, defaults, name) = wire.model(); defer { defaults.removePersistentDomain(forName: name) }
    model.pairingStatus = .paired
    let staleRefresh = Task { await model.refreshNowPlaying() }
    for _ in 0..<40 where reads.value == 0 { try await Task.sleep(for: .milliseconds(5)) }
    #expect(reads.value == 1)
    model.selectOutput(DJConnectOutputDevice(id: "new", name: "New speaker"))
    for _ in 0..<60 where model.pendingOutputSelectionID != nil { try await Task.sleep(for: .milliseconds(5)) }
    _ = await staleRefresh.value
    #expect(model.selectedOutput == "New speaker")
    #expect(model.availableOutputs.filter { $0.active == true }.map(\.id) == ["new"])
    #expect(model.backendAvailable)
    #expect(model.pairingStatus == .paired)
    #expect(!model.isRefreshing)
}

@Test @MainActor func structuredOutputActionKeepsBackendTargetAndSingleConfirmationRead() async throws {
    let wire = HistoryWireFixture { request in
        let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any]
        if body?["command"] as? String == "set_output" { return (200, Data(#"{"success":true}"#.utf8), 0) }
        return (200, Data(#"{"success":true,"devices":[{"id":"new","name":"New speaker","active":true}]}"#.utf8), 0)
    }
    defer { wire.close() }
    let (model, defaults, name) = wire.model(); defer { defaults.removePersistentDomain(forName: name) }
    model.pairingStatus = .paired
    model.apply(playback: DJConnectPlayback(device: DJConnectPlaybackDevice(id: "old", name: "Old speaker")))
    model.sendPlaybackCommand("set_output", value: .object(["device_id": "new"]), play: true)
    for _ in 0..<100 where model.availableOutputs.first(where: { $0.id == "new" })?.active != true {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(model.availableOutputs.first(where: { $0.id == "new" })?.active == true)
    try await Task.sleep(for: .milliseconds(400))
    let commands = try wire.requests.compactMap { request in
        (try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any])?["command"] as? String
    }
    #expect(commands == ["set_output", "devices"])
    let request = try #require(wire.requests.first)
    let payload = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any]
    #expect((payload?["value"] as? [String: String])?["device_id"] == "new")
    #expect(!model.isRefreshing)
}

@Test @MainActor func lateOutputConfirmationCannotReplaceNewerSelection() async throws {
    let reads = HTTPRecoveryActiveReadCounter()
    let wire = HistoryWireFixture { request in
        let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any]
        switch body?["command"] as? String {
        case "set_output": return (200, Data(#"{"success":true}"#.utf8), 0)
        case "devices":
            if reads.next() == 1 {
                return (200, Data(#"{"success":true,"devices":[{"id":"a","name":"A","active":true},{"id":"b","name":"B","active":false}]}"#.utf8), 0.2)
            }
            return (200, Data(#"{"success":true,"devices":[{"id":"a","name":"A","active":false},{"id":"b","name":"B","active":true}]}"#.utf8), 0)
        default: return (404, Data(), 0)
        }
    }
    defer { wire.close() }
    let (model, defaults, name) = wire.model()
    defer { defaults.removePersistentDomain(forName: name) }
    model.pairingStatus = .paired
    model.isRefreshing = true
    model.selectOutput(DJConnectOutputDevice(id: "a", name: "A"))
    for _ in 0..<40 {
        if reads.value >= 1 { break }
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(reads.value == 1)
    model.selectOutput(DJConnectOutputDevice(id: "b", name: "B"))
    // Wait for completion, not merely the second read being dispatched.
    for _ in 0..<100 where model.availableOutputs.filter({ $0.active == true }).map(\.id) != ["b"] {
        try await Task.sleep(for: .milliseconds(20))
    }
    #expect(reads.value == 2)
    #expect(model.selectedOutput == "B")
    #expect(model.availableOutputs.filter { $0.active == true }.map(\.id) == ["b"])
}

@Test @MainActor func supersededOutputSelectionCannotReplayOnRemoteFallback() async throws {
    let attempts = HTTPRecoveryActiveReadCounter()
    let local = HistoryWireFixture { request in
        let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any]
        if body?["command"] as? String == "set_output", body?["value"] as? String == "a" {
            _ = attempts.next()
            throw HistoryWireDelayedFailure(error: URLError(.cannotConnectToHost), delay: 0.15)
        }
        return (200, Data(#"{"success":true,"devices":[{"id":"b","name":"B","active":true}]}"#.utf8), 0)
    }
    let remote = HistoryWireFixture { _ in (200, Data(#"{"success":true}"#.utf8), 0) }
    defer { local.close(); remote.close() }
    let (model, defaults, name) = local.model(remoteURL: remote.baseURL)
    defer { defaults.removePersistentDomain(forName: name) }
    model.pairingStatus = .paired
    model.isRefreshing = true
    model.selectOutput(DJConnectOutputDevice(id: "a", name: "A"))
    for _ in 0..<40 {
        if attempts.value > 0 { break }
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(attempts.value == 1)
    model.selectOutput(DJConnectOutputDevice(id: "b", name: "B"))
    // Wait for accepted B output readback under parallel-suite load, rather than
    // treating 250ms as proof its asynchronous transport has finished.
    for _ in 0..<100 where model.availableOutputs.filter({ $0.active == true }).map(\.id) != ["b"] {
        try await Task.sleep(for: .milliseconds(20))
    }
    // Retain the original late-A failure settling interval and no-replay assertions.
    try await Task.sleep(for: .milliseconds(250))
    #expect(remote.requests.isEmpty)
    #expect(model.selectedOutput == "B")
    #expect(model.availableOutputs.filter { $0.active == true }.map(\.id) == ["b"])
}


@Test @MainActor func foregroundPollDiscoversAndReplacesProfileSessionWithoutPlaybackOrManualRefresh() async throws {
    let phase = PresenceReadPhase()
    let first = try presenceRuntimeWire(), successor = try presenceRuntimeWire(suffix: "-successor")
    let none = Data(#"{"success":true,"session":null}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/session/active") {
            return (200, phase.value == 0 || phase.value == 2 ? none : phase.value == 1 ? first : successor, 0)
        }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    // Allow the model's pre-existing startup status/command tasks to finish;
    // assertions below measure only the foreground coordinator's requests.
    try await Task.sleep(for: .milliseconds(100))
    model.backendAvailable = false
    let baseline = fixture.requests.count
    // No playback, manual refresh, or session-start action.
    #expect(model.activeDJSession == nil && model.playback == nil)
    await model.refreshForegroundStateFromPollTimer()
    #expect(model.activeDJSession == nil)
    phase.value = 1
    await model.refreshForegroundStateFromPollTimer()
    let discovered = try #require(model.activeDJSession?.sessionID)
    phase.value = 2
    await model.refreshForegroundStateFromPollTimer()
    #expect(model.activeDJSession == nil)
    phase.value = 3
    await model.refreshForegroundStateFromPollTimer()
    #expect(model.activeDJSession?.sessionID == discovered + "-successor")
    #expect(fixture.requests.dropFirst(baseline).allSatisfy { ($0.httpMethod ?? "GET") == "GET" }, "Without playback/backend availability, session discovery performs only reads")
    model.markInactiveSession()
    let before = fixture.requests.count
    await model.refreshForegroundStateFromPollTimer()
    #expect(fixture.requests.count == before, "Background devices must not keep polling")
}


@Test func artworkNoStoreIsNotRetainedByAppCache() async throws {
    let fixture = HistoryWireFixture { _ in (200, Data([1, 2, 3]), 0) }
    defer { fixture.close() }
    let cache = DJConnectArtworkDataCache(session: fixture.session())
    let url = fixture.baseURL.appendingPathComponent("artwork")
    #expect(try await cache.data(for: url) == Data([1, 2, 3]))
    #expect(try await cache.data(for: url) == Data([1, 2, 3]))
    #expect(fixture.requests.count == 2, "Protected no-store image grants must not become 24-hour cache entries")
}


@Test func musicDNAArtworkUsesOnlyExactUnexpiredSameProfileGrant() throws {
    let now = Date(timeIntervalSince1970: 1000)
    func feed(profile: String = "profile-a", expires: Double = 1100, kind: String = "artist", conflicting: Bool = false) throws -> DJConnectMusicDiscoveryResponse {
        var items: [[String: Any]] = [["id":"a", "kind":kind, "title":"Same display name", "uri":"spotify:artist:exact", "reason":"Profile evidence", "image_url":"/api/djconnect/v1/artwork/grant-a", "image_expires_at":expires]]
        if conflicting { var other = items[0]; other["id"] = "b"; other["image_url"] = "/api/djconnect/v1/artwork/grant-b"; items.append(other) }
        return try JSONDecoder().decode(DJConnectMusicDiscoveryResponse.self, from: historyData([
            "success":true,"enabled":true,"profile_id":profile,
            "sections":[["id":"artists","title":"Artists","items":items]]]))
    }
    let accepted = try feed()
    #expect(accepted.sections.first?.items.first?.imageExpiresAt == Date(timeIntervalSince1970: 1100))
    #expect(currentMusicDNAArtworkReference(discovery: accepted, profileID: "profile-a", uri: "spotify:artist:exact", artist: true, at: now) == "/api/djconnect/v1/artwork/grant-a")
    #expect(currentMusicDNAArtworkReference(discovery: accepted, profileID: "profile-b", uri: "spotify:artist:exact", artist: true, at: now) == nil)
    #expect(currentMusicDNAArtworkReference(discovery: accepted, profileID: "profile-a", uri: "spotify:artist:other", artist: true, at: now) == nil)
    #expect(currentMusicDNAArtworkReference(discovery: accepted, profileID: "profile-a", uri: nil, artist: true, at: now) == nil)
    #expect(currentMusicDNAArtworkReference(discovery: try feed(expires: 999), profileID: "profile-a", uri: "spotify:artist:exact", artist: true, at: now) == nil)
    #expect(currentMusicDNAArtworkReference(discovery: try feed(kind: "track"), profileID: "profile-a", uri: "spotify:artist:exact", artist: true, at: now) == nil)
    #expect(currentMusicDNAArtworkReference(discovery: try feed(conflicting: true), profileID: "profile-a", uri: "spotify:artist:exact", artist: true, at: now) == nil)
}

@Test func musicDNAArtistContractPreservesExactIdentityAndPublicImageReference() throws {
    let value = try JSONDecoder().decode(DJConnectMusicDNANameValue.self, from: Data(#"{"name":"An artist","uri":"spotify:artist:exact","image_url":"/api/djconnect/v1/artwork/lease"}"#.utf8))
    #expect(value.uri == "spotify:artist:exact")
    #expect(value.imageURL == "/api/djconnect/v1/artwork/lease")
}


@Test @MainActor func transientHistoryRefreshRetainsConfirmedListAndConversationButDenialWithdraws() async throws {
    let receipt = try historyObject()
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    let timelineObject = try #require(receipt["archived_timeline"] as? [String: Any])
    let sessions = try historyData(["success":true,"schema_version":1,"sessions":[try #require(timelineObject["session"])],"revision":try #require(timelineObject["revision"]),"retention_days":30])
    let caps = Data(#"{"capabilities":{"session_conversation_history":true},"contract_versions":{"session_conversation_history":1}}"#.utf8)
    let phase = PresenceReadPhase()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if phase.value == 1 { throw URLError(.cannotConnectToHost) }
        if phase.value == 2 { return (403, Data(#"{"success":false,"error":"invalid_profile"}"#.utf8), 0) }
        if request.url!.path.hasSuffix("/session/history") { return (200, sessions, 0) }
        return (200, profile, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    #expect(await model.sessionHistory.loadSessions())
    let confirmedSessions = model.sessionHistory.sessions
    let confirmedMessages = model.askDJMessages
    #expect(!confirmedSessions.isEmpty && !confirmedMessages.isEmpty)
    phase.value = 1
    #expect(!(await model.sessionHistory.loadSessions()))
    await model.sessionHistory.refreshConversation()
    #expect(model.sessionHistory.sessions == confirmedSessions)
    #expect(model.askDJMessages == confirmedMessages)
    #expect(model.sessionHistory.listErrorKey != nil)
    phase.value = 2
    #expect(!(await model.sessionHistory.loadSessions()))
    #expect(model.sessionHistory.sessions.isEmpty && model.askDJMessages.isEmpty)
}


@Test func speakerActionPreservesNumericObservationTimesAndFrozenChoiceIdentity() throws {
    let data = Data(#"{"id":"speaker-a","title":"Speaker A","kind":"output","command":"set_output","first_seen_at":1000.25,"last_seen_at":1100,"result_set_id":"set-a","action_id":"action-a","value":{"device_id":"speaker-a"}}"#.utf8)
    let action = try JSONDecoder().decode(DJConnectAskDJPlaybackAction.self, from: data)
    #expect(action.firstSeenAt?.hasPrefix("1970-01-01") == true)
    #expect(action.lastSeenAt?.hasPrefix("1970-01-01") == true)
    #expect(action.hasConsistentResultIdentity)
    #expect(action.jsonObjectValue["result_set_id"] == .string("set-a"))
    #expect(action.jsonObjectValue["action_id"] == .string("action-a"))
    guard case let .jsonObject(value) = action.commandValue else { Issue.record("Compound action value missing"); return }
    #expect(value["result_set_id"] == .string("set-a") && value["action_id"] == .string("action-a"))
    var conflicting = action; conflicting.value = .object(["result_set_id":.string("other-set"),"action_id":.string("action-a")])
    #expect(!conflicting.hasConsistentResultIdentity)
}

@Test(arguments: ["expiry", "suspend", "invalid"])
@MainActor func currentRichReplySurvivesReducedHistoryOnlyWithinOriginalGrant(scenario: String) async throws {
    let receipt = try historyObject()
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true},"contract_versions":{"session_conversation_history":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        (200, request.url!.path.hasSuffix("/capabilities") ? caps : profile, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    let assistant: [String: Any] = ["id":"current-answer","role":"assistant","text":"Choose an output","created_at":"2026-10-14T00:00:00Z"]
    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: historyData([
        "history_revision":1000,"clear_revision":0,"messages":[assistant],
        "images":[["url":"/api/djconnect/image_proxy/current","title":"Current artist"]],
        "playback_actions":[["id":"speaker-a","title":"Speaker A","kind":"output","command":"set_output","value":["device_id":"speaker-a"],"result_set_id":"set-a","action_id":"action-a"]],
        "result_set":["schema_version":scenario == "invalid" ? 2 : 1,"result_set_id":"set-a","expires_in":0.4]
    ]))
    #expect(response.messages.first?.images.count == 1, "Top-level rich data must reach the actual messages[] renderer")
    #expect(model.applyProfileConversationResponse(response, fallback: nil))
    let history = try JSONDecoder().decode(DJConnectAskDJHistoryResponse.self, from: historyData([
        "history_revision":1001,"clear_revision":0,"messages":[assistant]
    ]))
    #expect(model.applyProfileConversationHistory(history))
    if scenario != "invalid" {
        #expect(model.askDJMessages.first?.images.count == 1)
        #expect(model.askDJMessages.first?.playbackActions.count == 1)
    }
    if scenario == "expiry" { try await Task.sleep(for: .milliseconds(550)) }
    if scenario == "suspend" { model.sessionHistory.suspend() }
    #expect(model.askDJMessages.first?.text == "Choose an output")
    #expect(model.askDJMessages.first?.images.isEmpty == true)
    #expect(model.askDJMessages.first?.playbackActions.isEmpty == true)
    #expect(model.applyProfileConversationHistory(history))
    #expect(model.askDJMessages.first?.images.isEmpty == true, "Reduced history cannot renew a withdrawn presentation")
}


@Test(arguments: ["newer", "background"])
@MainActor func obsoleteDiscoveryFeedCannotRestoreOldArtwork(scenario: String) async throws {
    func feed(_ revision: Int) throws -> Data {
        try historyData(["success":true,"enabled":true,"revision":revision,"profile_id":"profile-a",
            "sections":[["id":"tracks","title":"Tracks","items":[["id":"track","kind":"track","title":"Track","uri":"spotify:track:exact","image_url":"/api/djconnect/artwork/grant-"+String(revision),"reason":"Source"]]]]])
    }
    let old = try feed(1), new = try feed(2)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/music_discovery/refresh") { return (200, new, 0) }
        if request.url!.path.hasSuffix("/music_discovery") { return (200, old, 0.2) }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    let stale = Task { await model.loadMusicDiscovery(force: true) }
    for _ in 0..<100 where !fixture.requests.contains(where: { $0.url!.path.hasSuffix("/music_discovery") }) {
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(fixture.requests.contains { $0.url!.path.hasSuffix("/music_discovery") })
    if scenario == "newer" { #expect(await model.refreshMusicDiscovery()) }
    else { model.markInactiveSession() }
    await stale.value
    if scenario == "newer" {
        #expect(model.musicDiscoveryResponse?.revision == 2)
        #expect(model.musicDiscoveryResponse?.sections.first?.items.first?.imageURL?.hasSuffix("grant-2") == true)
    } else { #expect(model.musicDiscoveryResponse == nil) }
    #expect(!model.isLoadingMusicDiscovery && !model.isRefreshingMusicDiscovery)
}

@Test(arguments: [false, true]) @MainActor func discoveryArtworkLeaseRenewsByReadWithoutRegeneratingRecommendations(producerKeepsExpired: Bool) async throws {
    let count = PresenceReadPhase()
    let fixture = HistoryWireFixture { request in
        guard request.url!.path.hasSuffix("/music_discovery") else { return (404, Data(), 0) }
        count.value += 1
        let n = count.value
        return (200, try historyData(["success":true,"enabled":true,"revision":n,"profile_id":"profile-a",
            "generated_at":Date().ISO8601Format(),"ttl_seconds":86400,
            "sections":[["id":"tracks","title":"Tracks","items":[["id":"track","kind":"track","title":"Track","uri":"spotify:track:exact","reason":"Source","image_url":"/api/djconnect/artwork/grant-"+String(n),"image_expires_at":Date().addingTimeInterval(n == 1 || producerKeepsExpired ? -1 : 3600).timeIntervalSince1970]]]]]), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    await model.loadMusicDiscovery()
    for _ in 0..<200 where model.musicDiscoveryResponse?.revision != 2 { try await Task.sleep(for: .milliseconds(20)) }
    if producerKeepsExpired { try await Task.sleep(for: .milliseconds(1200)) }
    #expect(count.value == 2, "Repeated expired producer replies must not cause an unbounded renewal loop")
    #expect(model.musicDiscoveryResponse?.revision == 2)
    #expect(!fixture.requests.contains { $0.url!.path.hasSuffix("/music_discovery/refresh") }, "Artwork renewal must only GET the feed, not regenerate recommendations")
}


@Test(arguments: ["lost-reply", "wrong-session", "successor"])
@MainActor func vibeCastApprovalNeverReplaysOrConfirmsAnotherSession(scenario: String) async throws {
    let first = try presenceRuntimeWire(), next = try presenceRuntimeWire(suffix: "-next")
    let sessionID = try #require(try JSONDecoder().decode(DJConnectSessionResponse.self, from: first).resolvedSession?.id)
    let phase = PresenceReadPhase()
    let remote = HistoryWireFixture { _ in
        (200, try historyData(["success":true,"handoff":"approved","session_id":sessionID]), 0)
    }
    defer { remote.close() }
    let local = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/session/active") { return (200, phase.value == 0 ? first : next, 0) }
        if request.url!.path.hasSuffix("/handoff/approve") {
            if scenario == "lost-reply" { throw URLError(.cannotConnectToHost) }
            return (200, try historyData(["success":true,"handoff":"approved","session_id":scenario == "wrong-session" ? "other" : sessionID]), scenario == "successor" ? 0.3 : 0)
        }
        return (404, Data(), 0)
    }
    defer { local.close() }
    let (model, defaults, name) = local.model(remoteURL: remote.baseURL)
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    #expect(await model.refreshActiveDJSession())
    let approval = Task { await model.approveVibeCastHandoff(code: "123456") }
    if scenario == "successor" {
        for _ in 0..<100 where !local.requests.contains(where: { $0.url!.path.hasSuffix("/handoff/approve") }) {
            try await Task.sleep(for: .milliseconds(5))
        }
        phase.value = 1
        #expect(await model.refreshActiveDJSession())
        #expect(model.activeDJSession?.id == sessionID + "-next")
    }
    await approval.value
    #expect(!model.vibeCastHandoffApproved)
    #expect(!model.isLoadingVibeCastHandoff)
    #expect(local.requests.filter { $0.url!.path.hasSuffix("/handoff/approve") }.count == 1)
    #expect(remote.requests.filter { $0.url!.path.hasSuffix("/handoff/approve") }.isEmpty)
    if scenario != "successor" { #expect(model.vibeCastHandoffFailed && model.vibeCastHandoffErrorKey == "ui.vibecast.handoff.unconfirmed") }
    else { #expect(!model.vibeCastHandoffFailed) }
}

@Test(arguments: [false, true]) @MainActor func musicDNAContextChangeWithdrawsOldProjectionAndRecoversWithinBound(permanent: Bool) async throws {
    let attempts = MusicDNARecoveryAttempts()
    let fixture = HistoryWireFixture { _ in
        let attempt = attempts.next()
        if attempt == 2 || (permanent && attempt > 2) {
            return (409, Data(#"{"success":false,"error":"music_dna_context_changed"}"#.utf8), 0)
        }
        return (200, Data(#"{"success":true,"enabled":true,"profile":{"summary":"Current authorized profile"}}"#.utf8), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshMusicDNAProfile(retryDelays: [])
    #expect(model.musicDNAProfileResponse?.enabled == true)
    await model.refreshMusicDNAProfile(retryDelays: [.milliseconds(1), .milliseconds(1)])
    #expect(fixture.requests.count == (permanent ? 4 : 3))
    #expect(!model.isLoadingMusicDNA)
    if permanent {
        #expect(model.musicDNAProfileResponse == nil && model.musicDiscoveryResponse == nil)
        #expect(model.musicDNAProfileNeedsRecovery)
        #expect(model.musicDNAErrorMessage == DJConnectLocalization.localized(key: "ui.music.dna.recovering", language: model.language))
    } else {
        #expect(model.musicDNAProfileResponse?.enabled == true)
        #expect(!model.musicDNAProfileNeedsRecovery && model.musicDNAErrorMessage == nil)
    }
}

@Test @MainActor func unrelatedMusicDNAConflictIsNotAutomaticallyRetried() async throws {
    let fixture = HistoryWireFixture { _ in (409, Data(#"{"success":false,"error":"another_conflict"}"#.utf8), 0) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshMusicDNAProfile(retryDelays: [.milliseconds(1), .milliseconds(1)])
    #expect(fixture.requests.count == 1)
    #expect(!model.musicDNAProfileNeedsRecovery && !model.isLoadingMusicDNA)
}

@Test @MainActor func currentArtistProducerReplyIsAcceptedAfterExistingHistoryRevision() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: root.appendingPathComponent("Fixtures/current-artist-identification-producer.json"))
    #expect(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() == "6fac84203cc3ce18c380895a5e59dcbcf93dc038034bc9f4be8f5c5ca8e14536")
    let receipt = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let cases = try #require(receipt["cases"] as? [[String: Any]])
    for name in ["artist-standalone-0-text", "artist-standalone-0-voice", "artist-session-0-text", "artist-session-0-voice"] {
        let body = try #require(cases.first { $0["case"] as? String == name }?["response"])
        let response = try JSONDecoder().decode(DJConnectSessionConversationResponse.self, from: historyData(body))
        let caps = Data(#"{"capabilities":{"session_conversation_history":true},"contract_versions":{"session_conversation_history":1}}"#.utf8)
        let history = Data(#"{"success":true,"owner_profile_id":"profile-a","history_revision":42,"clear_revision":3,"messages":[]}"#.utf8)
        let fixture = HistoryWireFixture { request in (200, request.url!.path.hasSuffix("/capabilities") ? caps : history, 0) }; defer { fixture.close() }
        let (model, defaults, defaultsName) = fixture.model(); defer { defaults.removePersistentDomain(forName: defaultsName) }
        await model.sessionHistory.prepare()
        #expect(model.sessionHistory.profileScopeActive)
        #expect(model.applyProfileConversationResponse(response.base, fallback: nil))
        #expect(model.askDJMessages.last?.text == response.base.djText)
        #expect(model.askDJMessages.last?.playbackActions.isEmpty == true)
        let currentID = try #require(model.askDJMessages.last?.id)
        await model.sessionHistory.refreshConversation()
        #expect(model.askDJMessages.last?.id == currentID)
        #expect(model.askDJMessages.last?.text == response.base.djText)
        // Current-only delivery must not reset the existing history revision or
        // make a later stale history snapshot authoritative.
        #expect(!model.applyProfileConversationHistory(.init(historyRevision: 41, clearRevision: 3, messages: [])))
        #expect(!model.applyProfileConversationResponse(.init(text: "Unversioned ordinary answer"), fallback: nil))
        let roundTrip = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: JSONEncoder().encode(response.base))
        #expect(roundTrip.isPrivateEphemeralResponse)
        #expect(defaults.data(forKey: "DJConnectAskDJMessages") == nil)
        model.sessionHistory.suspend()
        #expect(!model.askDJMessages.contains { $0.id == currentID })
        #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
    }
}

@Test func privateCurrentResponseCannotMasqueradeAsAHistorySnapshot() throws {
    for marker in ["", "\"history_persisted\":false,"] {
        let wire = "{\"success\":true,\"text\":\"Current answer\"," + marker + "\"conversation\":{\"schema_version\":1,\"history_scope\":\"private_ephemeral\"}}"
        #expect(try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: Data(wire.utf8)).isPrivateEphemeralResponse)
    }
    for wire in [
        #"{"success":true,"conversation":{"history_scope":"private_ephemeral"}}"#,
        #"{"success":true,"conversation":{"schema_version":2,"history_scope":"private_ephemeral"}}"#,
        #"{"success":false,"conversation":{"schema_version":1,"history_scope":"private_ephemeral"}}"#,
        #"{"success":true,"history_persisted":true,"conversation":{"schema_version":1,"history_scope":"private_ephemeral"}}"#,
        #"{"success":true,"conversation":{"schema_version":1,"history_scope":"profile"}}"#,
        #"{"success":true,"conversation":{"schema_version":1,"history_scope":"private_ephemeral"},"history_revision":0,"clear_revision":0}"#
    ] {
        #expect(try !JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: Data(wire.utf8)).isPrivateEphemeralResponse)
    }
}

@Test func currentResponseCodecPreservesOriginalResultGrant() throws {
    let wire = Data(#"{"text":"Current reply","result_set":{"schema_version":1,"result_set_id":"original-result","expires_in":0.125}}"#.utf8)
    let original = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: wire)
    let decoded = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: JSONEncoder().encode(original))
    #expect(decoded.resultSet == original.resultSet)
    #expect(decoded.resultSet?.expiresIn == 0.125)
}

@Test(arguments: ["playing", "paused", "empty", "failure"])
@MainActor func trackInsightScreenEntryLoadsOnceAndReusesCurrentAnalysis(_ scenario: String) async throws {
    let fixture = HistoryWireFixture { request in
        #expect(request.url!.path.hasSuffix("/track_insight"))
        let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any]
        #expect(body?["force_refresh"] as? Bool != true)
        if scenario == "failure" { return (503, Data(#"{"success":false,"error":"backend_unavailable"}"#.utf8), 0.1) }
        return (200, Data(#"{"success":true,"track":{"title":"Track A","artist":"Artist A"},"analysis":{"summary":"Supplied analysis","full_text":"Supplied analysis"}}"#.utf8), 0.1)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    model.pairingStatus = .paired
    model.apply(playback: scenario == "empty" ? nil : DJConnectPlayback(isPlaying: scenario != "paused", trackName: "Track A", artistName: "Artist A"))
    let first = Task { await model.loadTrackInsightOnOpen() }
    for _ in 0..<100 where scenario != "paused" && scenario != "empty" && fixture.requests.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
    // Another appearance while the request is pending must join the visible load.
    await model.loadTrackInsightOnOpen()
    await first.value
    let shouldLoad = scenario == "playing" || scenario == "failure"
    #expect(fixture.requests.count == (shouldLoad ? 1 : 0))
    #expect(!model.isLoadingTrackInsight && model.trackInsightNavigationRequestID == nil)
    if scenario == "playing" {
        #expect(model.currentTrackInsight?.title == "Track A")
        await model.loadTrackInsightOnOpen()
        #expect(fixture.requests.count == 1)
    } else if scenario == "failure" {
        #expect(model.currentTrackInsight == nil && model.trackInsightErrorMessage != nil)
    } else { #expect(model.currentTrackInsight == nil) }
}

@Test(arguments: ["track-change", "background", "cancel"])
@MainActor func trackInsightScreenEntryRejectsLateResultsAfterContextChanges(_ scenario: String) async throws {
    let fixture = HistoryWireFixture { request in
        #expect(request.url!.path.hasSuffix("/track_insight"))
        return (200, Data(#"{"success":true,"track":{"title":"Track A","artist":"Artist A"},"analysis":{"summary":"Supplied analysis","full_text":"Supplied analysis"}}"#.utf8), 0.2)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    model.pairingStatus = .paired
    model.apply(playback: DJConnectPlayback(isPlaying: true, trackName: "Track A", artistName: "Artist A"))
    let load = Task { await model.loadTrackInsightOnOpen() }
    for _ in 0..<100 where fixture.requests.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
    #expect(fixture.requests.count == 1)
    if scenario == "track-change" { model.apply(playback: DJConnectPlayback(isPlaying: true, trackName: "Track B", artistName: "Artist B")) }
    if scenario == "background" { model.markInactiveSession() }
    if scenario == "cancel" { load.cancel() }
    await load.value
    #expect(model.currentTrackInsight == nil && model.trackInsightHistory.isEmpty)
    #expect(model.trackInsightErrorMessage == nil && !model.isLoadingTrackInsight)
    #expect(fixture.requests.count == 1)
}

private func momentInsightProducerCase() throws -> [String: Any] {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let bytes = try Data(contentsOf: root.appendingPathComponent("Fixtures/moment-insight-core-producer.json"))
    #expect(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() == "9be892d55c8aaee4871e54ac68ed04945fb0676ce5472e2091a83ee66b2151a8")
    let producer = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    return try #require((producer["fixtures"] as? [[String: Any]])?.first { $0["case"] as? String == "active-detail-miss" })
}

private func momentInsightRuntimeWire(movedOn: Bool = false, successor: Bool = false) throws -> Data {
    let body = try #require(momentInsightProducerCase()["body"] as? [String: Any])
    let subject = try #require(body["subject"] as? [String: Any]), ref = try #require(subject["reference"] as? [String: Any])
    let sid = try #require(ref["session_id"] as? String), mid = try #require(ref["moment_id"] as? String)
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let native = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/native-moment-receipt.json"))) as? [String: Any])
    let after = try #require(native["after"] as? [String: Any]), initial = try #require(after["http_initial"] as? [String: Any])
    var broadcast = try #require(initial["snapshot"] as? [String: Any])
    let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var session = broadcast["session"] as! [String: Any]; session["session_id"] = sid
    var moments = broadcast["dj_moments"] as! [[String: Any]]
    moments[0]["session_id"] = sid; moments[0]["moment_id"] = mid; moments[0]["created_at"] = iso.string(from: Date().addingTimeInterval(-2))
    var nativeDelivery = broadcast["native_delivery"] as! [String: Any]
    nativeDelivery["session_id"] = sid; nativeDelivery["current_moment_id"] = movedOn ? NSNull() : mid as Any
    nativeDelivery["active_flow_moment_ids"] = [mid]
    var admissions = nativeDelivery["admissions"] as! [[String: Any]]
    admissions[0]["moment_id"] = mid; admissions[0]["current_display_allowed"] = !movedOn
    admissions[0]["source_expires_at"] = iso.string(from: Date().addingTimeInterval(180))
    admissions[0]["display_expires_at"] = iso.string(from: Date().addingTimeInterval(120))
    admissions[0]["navigation_actions"] = [["schema_version":1,"kind":"navigation","target":"track_insight", "action_id": ref["action_id"]!,
        "label":"Bekijk Track Insight","required_capability":"moment_track_insight_navigation_v1","reference":ref]]
    nativeDelivery["admissions"] = admissions
    if movedOn {
        var playback = broadcast["playback"] as! [String: Any]; playback["item_id"] = "recording-B"; playback["title"] = "Other recording B"; broadcast["playback"] = playback
    }
    broadcast["session"] = session; broadcast["dj_moments"] = moments; broadcast["native_delivery"] = nativeDelivery
    var delivery = broadcast["broadcast"] as! [String: Any]; delivery["snapshot_watermark"] = movedOn ? 9002 : 9001; broadcast["broadcast"] = delivery
    var envelope = try #require(JSONSerialization.jsonObject(with: activeMoodRuntimeWire()) as? [String: Any])
    var runtime = envelope["session"] as! [String: Any]
    if successor {
        let nextID = sid + "-successor"
        session["session_id"] = nextID
        for index in moments.indices { moments[index]["session_id"] = nextID }
        nativeDelivery["session_id"] = nextID
        broadcast["session"] = session; broadcast["dj_moments"] = moments; broadcast["native_delivery"] = nativeDelivery
    }
    runtime["session_id"] = successor ? sid + "-successor" : sid
    runtime["selected_mood"] = session["selected_mood"]; runtime["broadcast"] = broadcast
    envelope["session"] = runtime
    return try historyData(envelope)
}

@Test func momentInsightNavigationIsInertExactAndBounded() throws {
    let wire = try momentInsightRuntimeWire()
    let response = try JSONDecoder().decode(DJConnectSessionResponse.self, from: wire)
    var broadcast = try #require(response.session?.broadcast)
    let offer = try #require(broadcast.nativeCurrentInsightNavigation(at: Date()))
    #expect(offer.isValid && offer.reference.isValid)
    #expect(broadcast.originalInsightDeadline(for: offer.reference)! < Date().addingTimeInterval(181))
    broadcast.nativeDelivery?.admissions[0].navigationActions.append(offer)
    #expect(broadcast.nativeCurrentInsightNavigation(at: Date()) == nil)
    broadcast.nativeDelivery?.admissions[0].navigationActions = [offer]
    broadcast.nativeDelivery?.admissions[0].qualification = "expired"
    #expect(broadcast.nativeCurrentInsightNavigation(at: Date()) == nil)
    let capabilities = try JSONDecoder().decode(DJConnectSessionHistoryCapabilities.self, from: Data(#"{"capabilities":{"moment_track_insight_navigation_v1":true},"contract_versions":{"moment_track_insight_navigation_v1":2}}"#.utf8))
    #expect(!capabilities.momentInsightAvailable)
}

@Test(arguments: ["valid", "foreign", "missing", "expired", "excessive", "wrong-mode", "unqualified-debug"])
func momentInsightOwnerRouteRequiresExactSubjectAndNeverUsesPlaybackFallback(_ variant: String) async throws {
    let producer = try momentInsightProducerCase()
    var body = try #require(producer["body"] as? [String: Any])
    var subject = body["subject"] as! [String: Any]
    let reference = try JSONDecoder().decode(DJConnectMomentInsightReference.self, from: historyData(subject["reference"]!))
    switch variant {
    case "foreign": var ref = subject["reference"] as! [String: Any]; ref["session_id"] = "other-owner"; subject["reference"] = ref
    case "missing": body.removeValue(forKey: "subject")
    case "expired": subject["expires_in"] = 0
    case "excessive": subject["expires_in"] = 601
    case "wrong-mode": subject["mode"] = "current"
    case "unqualified-debug": var analysis = body["analysis"] as! [String: Any]; analysis.removeValue(forKey: "source_attribution"); body["analysis"] = analysis
    default: break
    }
    if variant != "missing" { body["subject"] = subject }
    let data = try historyData(body)
    let fixture = HistoryWireFixture { _ in (200, data, 0) }; defer { fixture.close() }
    do {
        let result = try await fixture.client().momentTrackInsight(reference, language: "en", mood: nil)
        #expect(variant == "valid")
        #expect(result.insight.title == "Synthetic live recording")
        #expect(result.subject.reference == reference)
        #expect(result.insight.energy == nil && result.insight.danceability == nil && result.insight.intensity == nil)
        #expect(result.insight.verifiedCredit?.context == "The composition behind this recording credits Brian Eno.")
        #expect(result.insight.summary == result.insight.verifiedCredit?.context)
        #expect(!result.insight.rawAnalysisText.contains("{'en':"))
    } catch { #expect(variant != "valid") }
    let request = try #require(fixture.requests.first)
    let payload = try #require(JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any])
    #expect(request.httpMethod == "POST" && request.url?.path == "/api/djconnect/v1/track_insight")
    #expect(payload["track_insight_target"] != nil && payload["title"] == nil && payload["artist"] == nil && payload["track"] == nil)
    #expect(fixture.requests.count == 1)
}

@Test(arguments: ["plain", "object-text", "unknown-basis", "missing-source", "unsafe-source", "unqualified-context"])
func momentInsightCreditProvenanceDoesNotInventAnalysisOrParseDebugObjects(_ variant: String) throws {
    var body = try #require(momentInsightProducerCase()["body"] as? [String: Any])
    var analysis = body["analysis"] as! [String: Any]
    let plain = "A composer credit identifies authorship; it does not identify the performer."
    switch variant {
    case "plain": analysis["summary"] = plain; analysis["full_text"] = plain
    case "unknown-basis": analysis["basis"] = "unknown"
    case "missing-source": analysis.removeValue(forKey: "source_attribution")
    case "unsafe-source": var source = analysis["source_attribution"] as! [String: Any]; source["url"] = "javascript:alert(1)"; analysis["source_attribution"] = source
    case "unqualified-context": analysis["verified_context"] = "{'en': 'Not normalized prose'}"
    default: break
    }
    body["analysis"] = analysis
    let insight = try #require(TrackInsightParser.parse(data: historyData(body)))
    let qualifies = variant == "plain" || variant == "object-text"
    #expect((insight.verifiedCredit != nil) == qualifies)
    if qualifies {
        let credit = try #require(insight.verifiedCredit)
        #expect(insight.summary == (variant == "plain" ? plain : credit.context))
        #expect(insight.energy == nil && insight.danceability == nil && insight.intensity == nil)
        #expect(credit.source.provider == "MusicBrainz" && credit.source.license == "CC0-1.0")
        let restored = try JSONDecoder().decode(TrackInsight.self, from: JSONEncoder().encode(insight))
        #expect(restored.verifiedCredit == credit)
    }
}

@Test(arguments: ["advance", "successor", "background", "expired", "forbidden"])
@MainActor func explicitMomentInsightKeepsAWhileBPlaysAndWithdrawsOnAuthorityLoss(_ scenario: String) async throws {
    let phase = PresenceReadPhase()
    let first = try momentInsightRuntimeWire(), moved = try momentInsightRuntimeWire(movedOn: true), next = try momentInsightRuntimeWire(successor: true)
    var body = try #require(momentInsightProducerCase()["body"] as? [String: Any])
    if scenario == "expired" { var subject = body["subject"] as! [String: Any]; subject["expires_in"] = 0.15; body["subject"] = subject }
    let detail = try historyData(body)
    let caps = Data(#"{"capabilities":{"moment_track_insight_navigation_v1":true},"contract_versions":{"moment_track_insight_navigation_v1":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/session/active") { return (200, phase.value == 0 ? first : scenario == "successor" ? next : moved, 0) }
        if request.url!.path.hasSuffix("/track_insight") {
            if scenario == "forbidden" { return (410, Data(#"{"success":false,"error":"track_insight_target_withdrawn"}"#.utf8), 0.1) }
            return (200, detail, scenario == "expired" ? 0 : 0.2)
        }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare(); await model.refreshActiveDJSession()
    // Settle the real controller's initial HTTP recovery before choosing a
    // current action; a missing WebSocket capability first withdraws its snapshot.
    for _ in 0..<300 where fixture.requests.filter({ $0.url!.path.hasSuffix("/session/active") }).count < 2 || model.activeDJSession?.broadcast.nativeDelivery == nil {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(model.sessionHistory.momentInsightAvailable)
    let offer = try #require(model.activeDJSession?.broadcast.nativeCurrentInsightNavigation(at: Date()))
    model.askDJDraft = "Keep my draft"
    let before = fixture.requests.count
    #expect(!fixture.requests.contains { $0.url!.path.hasSuffix("/track_insight") })
    model.openMomentTrackInsight(offer)
    for _ in 0..<200 where !fixture.requests.contains(where: { $0.url!.path.hasSuffix("/track_insight") }) { try await Task.sleep(for: .milliseconds(10)) }
    if scenario == "advance" || scenario == "successor" { phase.value = 1; await model.refreshActiveDJSession() }
    if scenario == "background" { model.markInactiveSession() }
    for _ in 0..<200 where model.isLoadingMomentTrackInsight { try await Task.sleep(for: .milliseconds(10)) }
    if scenario == "advance" {
        #expect(model.activeDJSession?.broadcast.playback?.title == "Other recording B")
        #expect(model.momentTrackInsight?.title == "Synthetic live recording")
        #expect(model.currentTrackInsight == nil && model.trackInsightHistory.isEmpty)
        #expect(model.askDJDraft == "Keep my draft")
    } else if scenario == "expired" {
        try await Task.sleep(for: .milliseconds(250))
        #expect(model.momentTrackInsight == nil && !model.canRetryMomentTrackInsight)
        #expect(model.momentTrackInsightErrorMessage != nil)
    } else if scenario == "forbidden" {
        #expect(model.momentTrackInsight == nil && !model.canRetryMomentTrackInsight)
    } else {
        try await Task.sleep(for: .milliseconds(250))
        #expect(model.momentTrackInsightTarget == nil && model.momentTrackInsight == nil)
        if scenario == "successor" {
            #expect(model.activeDJSession?.id.hasSuffix("-successor") == true)
        }
    }
    #expect(fixture.requests.dropFirst(before).filter { $0.httpMethod == "POST" }.allSatisfy { $0.url!.path.hasSuffix("/track_insight") })
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/track_insight") }.count == 1)
}

@Test(arguments: [false, true]) @MainActor func momentInsightUnavailableRuntimeNeverLeavesAQueuedSpinner(changesAfterOpen: Bool) async throws {
    let runtime = try momentInsightRuntimeWire()
    let caps = Data(#"{"capabilities":{"moment_track_insight_navigation_v1":true},"contract_versions":{"moment_track_insight_navigation_v1":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/session/active") { return (200, runtime, 0) }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare(); await model.refreshActiveDJSession()
    for _ in 0..<300 where fixture.requests.filter({ $0.url!.path.hasSuffix("/session/active") }).count < 2 || model.activeDJSession?.broadcast.nativeDelivery == nil { try await Task.sleep(for: .milliseconds(10)) }
    let offer = try #require(model.activeDJSession?.broadcast.nativeCurrentInsightNavigation(at: Date()))
    if !changesAfterOpen { model.updateRequiredMessage = "Runtime unavailable" }
    model.openMomentTrackInsight(offer)
    if changesAfterOpen { model.updateRequiredMessage = "Runtime unavailable" }
    // Yield to the queued open without waiting for the original source expiry.
    try await Task.sleep(for: .milliseconds(100))
    #expect(!model.isLoadingMomentTrackInsight)
    #expect(model.momentTrackInsight == nil && !model.canRetryMomentTrackInsight)
    #expect(!fixture.requests.contains { $0.url!.path.hasSuffix("/track_insight") })
    if changesAfterOpen { #expect(model.momentTrackInsightErrorMessage != nil) }
    else { #expect(model.momentTrackInsightTarget == nil) }
}

@Test @MainActor func lateMissingOptionalLiveCapabilityCannotWithdrawAuthenticatedHTTPMomentDetail() async throws {
    let runtime = try momentInsightRuntimeWire(), detail = try historyData(momentInsightProducerCase()["body"]!)
    let caps = Data(#"{"capabilities":{"moment_track_insight_navigation_v1":true},"contract_versions":{"moment_track_insight_navigation_v1":1}}"#.utf8)
    let capabilityReads = HTTPRecoveryActiveReadCounter()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, capabilityReads.next() == 1 ? 0 : 0.3) }
        if request.url!.path.hasSuffix("/session/active") { return (200, runtime, 0) }
        if request.url!.path.hasSuffix("/track_insight") { return (200, detail, 0) }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare(); await model.refreshActiveDJSession()
    let offer = try #require(model.activeDJSession?.broadcast.nativeCurrentInsightNavigation(at: Date()))
    model.openMomentTrackInsight(offer)
    for _ in 0..<200 where model.isLoadingMomentTrackInsight { try await Task.sleep(for: .milliseconds(10)) }
    #expect(model.momentTrackInsight?.title == "Synthetic live recording")
    try await Task.sleep(for: .milliseconds(500))
    #expect(capabilityReads.value >= 2)
    #expect(model.activeDJSession?.broadcast.nativeCurrentInsightNavigation(at: Date()) == offer)
    #expect(model.momentTrackInsightTarget == offer.reference && model.momentTrackInsight != nil)
    #expect(!model.djSessionLiveUnavailable)
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/track_insight") }.count == 1)
    #expect(fixture.requests.filter { $0.httpMethod == "POST" }.allSatisfy { $0.url!.path.hasSuffix("/track_insight") })
}

@Test(arguments: [false, true]) @MainActor func momentInsightRetryCannotRenewDeadlineOrChangeRecording(changedRecording: Bool) async throws {
    let first = try momentInsightRuntimeWire()
    let attempts = MusicDNARecoveryAttempts()
    let original = try #require(momentInsightProducerCase()["body"] as? [String: Any])
    var firstBody = original, firstSubject = original["subject"] as! [String: Any]
    firstSubject["expires_in"] = 0.4; firstBody["subject"] = firstSubject
    let firstDetail = try historyData(firstBody)
    var laterBody = original, laterSubject = original["subject"] as! [String: Any]
    laterSubject["expires_in"] = 599.0
    if changedRecording { laterSubject["media_identity"] = "spotify:track:2222222222222222222222" }
    laterBody["subject"] = laterSubject
    let laterDetail = try historyData(laterBody)
    let caps = Data(#"{"capabilities":{"moment_track_insight_navigation_v1":true},"contract_versions":{"moment_track_insight_navigation_v1":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/session/active") { return (200, first, 0) }
        if request.url!.path.hasSuffix("/track_insight") {
            let attempt = attempts.next()
            return (200, attempt == 1 ? firstDetail : laterDetail, 0)
        }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare(); await model.refreshActiveDJSession()
    for _ in 0..<300 where fixture.requests.filter({ $0.url!.path.hasSuffix("/session/active") }).count < 2 || model.activeDJSession?.broadcast.nativeDelivery == nil { try await Task.sleep(for: .milliseconds(10)) }
    let offer = try #require(model.activeDJSession?.broadcast.nativeCurrentInsightNavigation(at: Date()))
    model.openMomentTrackInsight(offer)
    for _ in 0..<200 where model.isLoadingMomentTrackInsight { try await Task.sleep(for: .milliseconds(10)) }
    #expect(model.momentTrackInsight != nil)
    #expect(await model.refreshMomentTrackInsight() == !changedRecording)
    try await Task.sleep(for: .milliseconds(500))
    #expect(model.momentTrackInsight == nil && !model.canRetryMomentTrackInsight)
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/track_insight") }.count == 2)
}

@Test(arguments: ["selected", "repeat", "unknown"])
@MainActor func frozenConversationChoicesKeepOriginalLeaseAcrossSelection(_ scenario: String) async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let producer = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/moment-insight-core-producer.json"))) as? [String: Any])
    let cases = try #require(producer["fixtures"] as? [[String: Any]])
    var first = try #require(cases.first { $0["case"] as? String == "standalone-refine" }?["body"] as? [String: Any])
    var set = first["result_set"] as! [String: Any]; set["expires_in"] = 0.35; first["result_set"] = set
    let iso = ISO8601DateFormatter(); first["server_time"] = iso.string(from: Date())
    var selected = try #require(cases.first { $0["case"] as? String == "standalone-select" }?["body"] as? [String: Any])
    if scenario == "repeat" {
        selected = first; set["expires_in"] = 600.0; selected["result_set"] = set
        selected["server_time"] = iso.string(from: Date())
    }
    let caps = Data(#"{"capabilities":{"session_conversation_history":true},"contract_versions":{"session_conversation_history":1}}"#.utf8)
    let history = Data(#"{"success":true,"owner_profile_id":"profile-a","history_revision":0,"clear_revision":0,"messages":[]}"#.utf8)
    let fixture = HistoryWireFixture { request in (200, request.url!.path.hasSuffix("/capabilities") ? caps : history, 0) }; defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { model.sessionHistory.suspend(); defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    first["server_time"] = iso.string(from: Date())
    selected["server_time"] = iso.string(from: Date())
    let firstResponse = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: historyData(first))
    let selectedResponse = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: historyData(selected))
    if scenario != "unknown" { #expect(model.applyProfileConversationResponse(firstResponse, fallback: nil)) }
    #expect(model.applyProfileConversationResponse(selectedResponse, fallback: nil))
    if scenario != "unknown" { #expect(model.askDJMessages.contains { !$0.playbackActions.isEmpty }) }
    try await Task.sleep(for: .milliseconds(450))
    #expect(model.askDJMessages.allSatisfy { $0.playbackActions.isEmpty }, "A selection reply cannot renew or invent its frozen result grant")
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
}

@Test @MainActor func frozenConversationExpiryCannotBeRestoredByLaterSelectionOrScopeChange() throws {
    let fixture = HistoryWireFixture { _ in (500, Data(), 0) }; defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    let valid = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: Data(#"{"result_set":{"schema_version":1,"result_set_id":"set-a","expires_in":30}}"#.utf8))
    let revoked = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: Data(#"{"result_set":{"schema_version":1,"result_set_id":"set-a","expires_in":0}}"#.utf8))
    let selected = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: Data(#"{"playback_actions":[{"id":"a","title":"A","result_set_id":"set-a","action_id":"a"}]}"#.utf8))
    let now = Date(timeIntervalSince1970: 1000)
    #expect(model.resolveConversationPresentationDeadline(valid, now: now) == now.addingTimeInterval(30))
    #expect(model.resolveConversationPresentationDeadline(revoked, now: now.addingTimeInterval(1)) == .distantPast)
    #expect(model.resolveConversationPresentationDeadline(selected, now: now.addingTimeInterval(2)) == .distantPast)
    #expect(model.resolveConversationPresentationDeadline(valid, now: now.addingTimeInterval(3)) == .distantPast)
    model.sessionHistory.suspend()
    #expect(model.resolveConversationPresentationDeadline(selected, now: now.addingTimeInterval(4)) == .distantPast)
}

@Test @MainActor func liveRuntimeReplacementRevalidatesHTTPBeforeWithdrawingPairing() async throws {
    let fixture = HistoryWireFixture { request in
        #expect(request.url!.path.hasSuffix("/status"))
        return (200, Data(#"{"success":true}"#.utf8), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    model.askDJDraft = "Keep this unsent draft"
    await model.recoverAfterPairedAuthorityWithdrawal("pairing_revoked")
    #expect(model.pairingStatus == .paired)
    #expect(model.isConnected)
    #expect(model.askDJDraft == "Keep this unsent draft")
    #expect(fixture.requests.count == 1)
    #expect(model.activeDJSession == nil && model.askDJMessages.isEmpty)
}

@Test @MainActor func liveRuntimeReplacementOnlyRevokesAfterQualifiedHTTPRefusal() async throws {
    let fixture = HistoryWireFixture { _ in (401, Data(#"{"success":false,"error":"unauthorized"}"#.utf8), 0) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.recoverAfterPairedAuthorityWithdrawal("pairing_revoked")
    #expect(fixture.requests.count == 1)
    #expect(model.pairingStatus == .stale)
}

@Test @MainActor func liveRuntimeReplacementPreservesPairingOnUnqualifiedProxy401() async throws {
    let fixture = HistoryWireFixture { _ in (401, Data("<html>Proxy authentication required</html>".utf8), 0) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.recoverAfterPairedAuthorityWithdrawal("pairing_revoked")
    #expect(model.pairingStatus == .paired)
    #expect(!model.isConnected)
    #expect(fixture.requests.count == 1)
    #expect(model.activeDJSession == nil)
}

@Test @MainActor func liveRuntimeReplacementCancelsValidationWhenBackgrounded() async throws {
    let fixture = HistoryWireFixture { _ in (200, Data(#"{"success":true}"#.utf8), 0.2) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    let work = Task { await model.recoverAfterPairedAuthorityWithdrawal("pairing_revoked") }
    for _ in 0..<100 where fixture.requests.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
    model.markInactiveSession()
    await work.value
    #expect(model.pairingStatus == .paired)
    #expect(!model.isConnected)
    #expect(model.activeDJSession == nil)
}

@Test @MainActor func liveRuntimeReplacement503RecoveryIsBoundedAndRetainsPairing() async throws {
    let fixture = HistoryWireFixture { _ in (503, Data(#"{"success":false,"error":"not_configured"}"#.utf8), 0) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.recoverAfterPairedAuthorityWithdrawal("pairing_revoked")
    #expect(model.pairingStatus == .paired && !model.isConnected)
    #expect(fixture.requests.count == 3)
    #expect(fixture.requests.allSatisfy { $0.url!.path.hasSuffix("/status") })
}

@Test @MainActor func obsoleteLiveRecoveryCannotWithdrawReplacementCredential() async throws {
    let fixture = HistoryWireFixture { _ in (401, Data(#"{"success":false,"error":"unauthorized"}"#.utf8), 0.2) }
    defer { fixture.close() }
    let name = "paired-recovery-replacement-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name)); defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(fixture.baseURL.absoluteString, forKey: "DJConnectHomeAssistantURL")
    let store = DJConnectInMemoryTokenStore(token: "old-synthetic-token")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: store, urlSession: fixture.session(), startBackgroundTasks: false)
    let work = Task { await model.recoverAfterPairedAuthorityWithdrawal("pairing_revoked") }
    for _ in 0..<100 where fixture.requests.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
    try store.saveToken("replacement-synthetic-token")
    await work.value
    #expect(model.pairingStatus == .paired)
    #expect(try store.loadToken() == "replacement-synthetic-token")
}

@Test @MainActor func obsoleteLiveRecoveryCannotWithdrawAfterHAConfigurationChange() async throws {
    let fixture = HistoryWireFixture { _ in (401, Data(#"{"success":false,"error":"unauthorized"}"#.utf8), 0.2) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    let work = Task { await model.recoverAfterPairedAuthorityWithdrawal("pairing_revoked") }
    for _ in 0..<100 where fixture.requests.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
    model.homeAssistantURL = "https://replacement-installation.example"
    await work.value
    #expect(model.pairingStatus == .paired && !model.isConnected)
}

private final class HistoryArtworkDenialSwitch: @unchecked Sendable {
    private let lock = NSLock()
    private var denied = false
    func deny() { lock.withLock { denied = true } }
    var isDenied: Bool { lock.withLock { denied } }
}

@Test @MainActor func sessionHistoryArtworkVisibilityPreparesOnceAndDenialClearsOnlyPixels() async throws {
    let receipt = try historyObject()
    let timelineData = try historyData(try #require(receipt["archived_timeline"]))
    let timeline = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: timelineData)
    let original = try #require(timeline.entries.first)
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let artFixture = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/session-artwork-core-5c7ecb79.json"))) as! [String: Any]
    let examples = try #require(artFixture["examples"] as? [String: [String: Any]])
    var projection = try #require(examples["older_entry_refresh"]?["projection"] as? [String: Any])
    projection["session_id"] = original.sessionID; projection["entry_id"] = original.entryID
    var art = try #require(projection["artwork"] as? [String: Any])
    art["captured_at"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1))
    art["expires_at"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(60))
    art["url"] = "/api/djconnect/v1/session/media/image/\(original.sessionID)/synthetic-history-cover"
    projection["artwork"] = art
    let prepared = try historyData(["success": true, "contract_version": 1, "session_media": [projection]])
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_artwork":true},"contract_versions":{"session_conversation_history":1,"session_artwork":1}}"#.utf8)
    let conversation = try historyData(try #require(receipt["later_historical_answer"]))
    let denial = HistoryArtworkDenialSwitch()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/session/media/prepare") {
            return denial.isDenied ? (403, Data(), 0) : (200, prepared, 0)
        }
        if request.url!.path.contains("/session/history/") { return (200, timelineData, 0) }
        return (200, conversation, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    await model.sessionHistory.loadTimeline(original.sessionID)
    #expect(model.sessionHistory.artworkAvailable)
    #expect(!fixture.requests.contains { $0.url!.path.hasSuffix("/session/media/prepare") })
    // A viewport event starts loading without any action button. Coalesce rapid
    // scroll notifications while the same row is already queued/in flight.
    for _ in 0..<5 { model.sessionHistory.prefetchArtwork(sessionID: original.sessionID, visibleIDs: [original.id]) }
    for _ in 0..<200 {
        if model.sessionHistory.timelines[original.sessionID]?.entries.first?.sessionMedia?.artwork.state == .ready { break }
        try await Task.sleep(for: .milliseconds(10))
    }
    model.sessionHistory.prefetchArtwork(sessionID: original.sessionID, visibleIDs: [original.id])
    let ready = try #require(model.sessionHistory.timelines[original.sessionID]?.entries.first)
    #expect(ready.sessionMedia?.artwork.state == .ready)
    #expect(ready.text == original.text && ready.order == original.order && ready.id == original.id)
    denial.deny()
    await model.sessionHistory.refreshArtwork(for: ready)
    let withdrawn = try #require(model.sessionHistory.timelines[original.sessionID]?.entries.first)
    #expect(withdrawn.sessionMedia == nil)
    #expect(withdrawn.text == original.text && withdrawn.order == original.order)
    #expect(model.pairingStatus == .paired)
    #expect(model.sessionHistory.artworkFailed.contains(original.reference))
    let originalPreparations = fixture.requests.filter { request in
        guard request.url!.path.hasSuffix("/session/media/prepare"), let data = try? presenceRequestBody(request),
              let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let targets = body["targets"] as? [[String: String]] else { return false }
        return targets.contains { $0["entry_id"] == original.id }
    }
    #expect(originalPreparations.count == 2)
    try await Task.sleep(for: .milliseconds(50))
    let preparationCount = fixture.requests.filter { $0.url!.path.hasSuffix("/session/media/prepare") }.count
    for _ in 0..<5 { model.sessionHistory.prefetchArtwork(sessionID: original.sessionID, visibleIDs: [original.id]) }
    try await Task.sleep(for: .milliseconds(50))
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/session/media/prepare") }.count == preparationCount)
    model.sessionHistory.suspend()
    model.sessionHistory.prefetchArtwork(sessionID: original.sessionID, visibleIDs: [original.id])
    #expect(model.sessionHistory.artworkPreparing.isEmpty)
    #expect(!fixture.requests.contains { $0.url!.path.contains("/command") || $0.url!.path.hasSuffix("/start") })
}

// Active Persona uses the already delivered Core8757 CAS route, not Profile defaults.
private func activePersonaCapsWire() throws -> Data {
    var caps = try #require(JSONSerialization.jsonObject(with: activeMoodCapsWire) as? [String: Any])
    caps["capabilities"] = ["active_session_persona":true,"active_session_mood":true,"session_conversation_history":true]
    caps["contract_versions"] = ["active_session_persona":1,"active_session_mood":1,"session_conversation_history":1]
    caps["active_session_persona"] = ["available":true,"version":1,"path":"/api/djconnect/v1/session/persona",
        "method":"POST","authentication":"paired_device_bearer","values":["home_dj","radio_dj","club_dj","festival_dj"],
        "ordering":"expected_persona_revision","scope":"active_device_bound_owner_session"] as [String:Any]
    return try historyData(caps)
}
private func activePersonaRuntimeWire() throws -> Data {
    var response = try #require(JSONSerialization.jsonObject(with: activeMoodRuntimeWire()) as? [String:Any])
    var runtime = try #require(response["session"] as? [String:Any])
    runtime["dj_persona"] = "home_dj"; runtime["persona_revision"] = 0
    var broadcast = try #require(runtime["broadcast"] as? [String:Any])
    var session = try #require(broadcast["session"] as? [String:Any])
    session["dj_persona"] = "home_dj"; session["persona_revision"] = 0
    broadcast["session"] = session; runtime["broadcast"] = broadcast; response["session"] = runtime
    return try historyData(response)
}

@Test func activePersonaExactRequestAndRealProducerResponses() throws {
    let fixture = HistoryWireFixture { _ in (200,Data(),0) }; defer {fixture.close()}
    let request = try fixture.client().sessionPersonaRequest(sessionID:"current",persona:.radioDJ,expectedRevision:0)
    let requestBody = try #require(request.httpBody)
    let body = try #require(JSONSerialization.jsonObject(with: requestBody) as? [String:Any])
    #expect(Set(body.keys) == ["contract_version","client_type","device_id","session_id","selected_persona","expected_persona_revision"])
    #expect(request.url?.path == "/api/djconnect/v1/session/persona" && request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField:"Authorization") == "Bearer synthetic-fixture-token")
    #expect(request.value(forHTTPHeaderField:"Cache-Control") == "no-store")
    #expect(throws:DJConnectError.invalidResponse) {try fixture.client().sessionPersonaRequest(sessionID:"",persona:.homeDJ,expectedRevision:0)}
    #expect(throws:DJConnectError.invalidResponse) {try fixture.client().sessionPersonaRequest(sessionID:"current",persona:.homeDJ,expectedRevision:-1)}
    let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
    let wire = try #require(JSONSerialization.jsonObject(with: Data(contentsOf:root.appendingPathComponent("Fixtures/session-persona-core8757.json"))) as? [String:Any])
    let first = try JSONDecoder().decode(DJConnectSessionPersonaResponse.self,from:historyData(#require(wire["persona"])))
    let next = try JSONDecoder().decode(DJConnectSessionPersonaResponse.self,from:historyData(#require(wire["persona_change"])))
    #expect(first.success && first.selectedPersona == .radioDJ && first.personaRevision == 1)
    #expect(next.selectedPersona == .festivalDJ && next.personaRevision == 2)
    #expect(try JSONDecoder().decode(DJConnectActiveMoodCapabilities.self,from:activePersonaCapsWire()).personaAvailable)
    #expect(!(try JSONDecoder().decode(DJConnectActiveMoodCapabilities.self,from:activeMoodCapsWire).personaAvailable))
}

@Test func activePersonaRejectsStaleAndConflictingRevisionsWithoutRewritingMoments() throws {
    let runtime = try #require(JSONDecoder().decode(DJConnectSessionResponse.self,from:activePersonaRuntimeWire()).session)
    let first = runtime.applying(persona:.init(sessionID:runtime.id,selectedPersona:.radioDJ,personaRevision:1))
    var late = runtime.broadcast; late.delivery = .init(snapshotWatermark:999)
    let unchanged = first.applying(broadcastState:late)
    #expect(unchanged.confirmedPersona?.selectedPersona == .radioDJ)
    #expect(unchanged.broadcast.djMoments == runtime.broadcast.djMoments && unchanged.broadcast.presentations == runtime.broadcast.presentations)
    #expect(unchanged.selectedMood == runtime.selectedMood && unchanged.selectedPresence == runtime.selectedPresence)
    let conflict = unchanged.applying(persona:.init(sessionID:runtime.id,selectedPersona:.clubDJ,personaRevision:1))
    #expect(conflict.confirmedPersona == nil && conflict.personaRevisionFloor == 1)
    let recovered = conflict.applying(persona:.init(sessionID:runtime.id,selectedPersona:.festivalDJ,personaRevision:2))
    #expect(recovered.confirmedPersona?.selectedPersona == .festivalDJ)
    #expect(recovered.applying(persona:.init(sessionID:"other",selectedPersona:.homeDJ,personaRevision:100)) == recovered)
    var event = DJConnectSessionBroadcastEvent(eventType:"persona_changed",sessionID:runtime.id,payload:.init(session:.init(sessionID:runtime.id,runtimeState:"active",selectedMood:runtime.selectedMood,selectedPersona:.clubDJ,personaRevision:3)))
    event.deliverySequence = 1000
    #expect(recovered.applying(broadcastEvent:event).confirmedPersona?.selectedPersona == .clubDJ)
}

@Test(arguments:[200,409,403], [false,true]) @MainActor
func activePersonaConfirmedConflictAndAuthorityHandling(_ status:Int, _ background:Bool) async throws {
    let runtime = try activePersonaRuntimeWire(), caps = try activePersonaCapsWire()
    let sessionID = try #require(JSONDecoder().decode(DJConnectSessionResponse.self,from:runtime).session).id
    let profile = try historyData(try #require(historyObject()["later_historical_answer"]))
    let reply = try historyData(status == 200 ? ["success":true,"contract_version":1,"session_id":sessionID,"selected_persona":"radio_dj","persona_revision":1,"changed":true] :
        status == 409 ? ["success":false,"error":"persona_revision_conflict","current":["session_id":sessionID,"selected_persona":"club_dj","persona_revision":2]] : ["success":false,"error":"invalid_profile"])
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") {return(200,caps,0)}
        if request.url!.path.hasSuffix("/session/active") {return(200,runtime,0)}
        if request.url!.path.hasSuffix("ask_dj/history") {return(200,profile,0)}
        if request.url!.path.hasSuffix("/session/persona") {return(status,reply,0.08)}
        return(404,Data(#"{"success":false}"#.utf8),0)
    };defer{fixture.close()}
    let(model,defaults,name)=fixture.model();defer{defaults.removePersistentDomain(forName:name)}
    await model.sessionHistory.prepare();await model.refreshActiveDJSession();await model.refreshActiveMoodCapability()
    #expect(model.activePersonaAvailable && model.sessionHistory.hasAuthorizedOwner)
    let pending = Task {await model.changeActiveSessionPersona(.radioDJ,expectedSessionID:sessionID,expectedEpoch:model.sessionHistory.responseEpoch)}
    try await Task.sleep(for:.milliseconds(25))
    #expect(model.activePersonaPending && model.activeDJSession?.confirmedPersona?.selectedPersona == .homeDJ)
    if background {model.markInactiveSession()}
    await pending.value
    #expect(!model.activePersonaPending)
    #expect(fixture.requests.filter{$0.url!.path.hasSuffix("/session/persona")}.count == 1)
    if background {
        #expect(model.activePersonaError == nil && !model.activePersonaAvailable)
        #expect(model.activeDJSession?.confirmedPersona?.selectedPersona == .homeDJ)
        return
    }
    if status == 200 {#expect(model.activeDJSession?.confirmedPersona?.selectedPersona == .radioDJ && model.activePersonaError == nil)}
    if status == 409 {#expect(model.activeDJSession?.confirmedPersona?.selectedPersona == .clubDJ && model.activePersonaError != nil)}
    if status == 403 {#expect(!model.sessionHistory.hasAuthorizedOwner && model.activeDJSession == nil && !model.activePersonaAvailable)}
}

@Test(arguments:["jump","wrong-session","wrong-value","false-success"])
func activePersonaRejectsUnconfirmedMutationReplies(_ fault:String) async throws {
    var body:[String:Any] = ["success":true,"contract_version":1,"session_id":"current","selected_persona":"radio_dj","persona_revision":1,"changed":true]
    if fault == "jump" {body["persona_revision"] = 9}
    if fault == "wrong-session" {body["session_id"] = "other"}
    if fault == "wrong-value" {body["selected_persona"] = "club_dj"}
    if fault == "false-success" {body["success"] = false}
    let data = try historyData(body)
    let fixture = HistoryWireFixture {_ in (200,data,0)};defer{fixture.close()}
    await #expect(throws:DJConnectError.invalidResponse) {
        try await fixture.client().updateSessionPersona(sessionID:"current",persona:.radioDJ,expectedRevision:0)
    }
    #expect(fixture.requests.count == 1)
}

@Test @MainActor func activePersonaSessionEndImmediatelyInvalidatesPendingReply() async throws {
    let runtime = try activePersonaRuntimeWire(), caps = try activePersonaCapsWire()
    let id = try #require(JSONDecoder().decode(DJConnectSessionResponse.self,from:runtime).session).id
    var ended = try #require(JSONSerialization.jsonObject(with:runtime) as? [String:Any])
    var session = try #require(ended["session"] as? [String:Any]);session["runtime_state"] = "ended"
    var broadcast = try #require(session["broadcast"] as? [String:Any])
    var state = try #require(broadcast["session"] as? [String:Any]);state["runtime_state"] = "ended"
    broadcast["session"] = state;session["broadcast"] = broadcast;ended["session"] = session
    let endedData = try historyData(ended)
    let profile = try historyData(try #require(historyObject()["later_historical_answer"]))
    let reply = try historyData(["success":true,"contract_version":1,"session_id":id,"selected_persona":"radio_dj","persona_revision":1,"changed":true])
    let gate = HistoryAuthorityGate()
    let fixture = HistoryWireFixture {request in
        if request.url!.path.hasSuffix("/capabilities") {return(200,caps,0)}
        if request.url!.path.hasSuffix("/session/active") {return(200,gate.denied ? endedData : runtime,0)}
        if request.url!.path.hasSuffix("ask_dj/history") {return(200,profile,0)}
        if request.url!.path.hasSuffix("/session/persona") {return(200,reply,0.15)}
        return(404,Data(#"{"success":false}"#.utf8),0)
    };defer{fixture.close()}
    let(model,defaults,name)=fixture.model();defer{defaults.removePersistentDomain(forName:name)}
    await model.sessionHistory.prepare();await model.refreshActiveDJSession();await model.refreshActiveMoodCapability()
    let epoch=model.sessionHistory.responseEpoch
    let pending=Task{await model.changeActiveSessionPersona(.radioDJ,expectedSessionID:id,expectedEpoch:epoch)}
    try await Task.sleep(for:.milliseconds(25));#expect(model.activePersonaPending)
    gate.denied=true;await model.refreshActiveDJSession()
    #expect(model.activeDJSession?.runtimeState == "ended" && !model.activePersonaPending && !model.activePersonaAvailable)
    await pending.value
    #expect(model.activeDJSession?.confirmedPersona?.selectedPersona == .homeDJ && model.activePersonaError == nil)
    #expect(fixture.requests.filter{$0.url!.path.hasSuffix("/session/persona")}.count == 1)
}

private func genericTTS6eceFixture() throws -> [String:Any] {
    let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try #require(JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("Fixtures/generic-ha-tts-core6ece.http.json"))) as? [String:Any])
}
private func genericTTS6ecePrepared(_ row:[String:Any], voiceID:String? = nil) throws -> [String:Any] {
    var envelope=try #require(row["prepared"] as? [String:Any])
    var speech=try #require(envelope["session_speech"] as? [String:Any])
    // Explicit modeled clock renewal for client scheduling tests only; canonical fixture remains byte-exact.
    speech["expires_at"] = ISO8601DateFormatter().string(from:Date().addingTimeInterval(120))
    if let voiceID {
        var voice=try #require(speech["effective_voice"] as? [String:Any]);voice["voice_id"]=voiceID
        speech["effective_voice"]=voice
    }
    envelope["session_speech"]=speech;return envelope
}

// Respect the production two-transfer budget; these independent fixture cases are serial.
@Suite(.serialized) struct GenericTTS6eceContractTests {
@Test func genericTTS6eceActualFiveLanguageInventoryAndReadiness() throws {
    let rows=try #require(try genericTTS6eceFixture()["rows"] as? [[String:Any]])
    #expect(rows.count == 5)
    for row in rows {
        let options=try JSONDecoder().decode(DJConnectSpeechVoiceOptionsResponse.self,from:historyData(#require(row["voice_options"]))).speech_voice_options
        #expect(options.isValid && options.selectableVoices.count == 13)
        #expect(options.preferenceContext?.isSupported == true && options.supportsVoice("cedar"))
        #expect(options.selectableGenders.isEmpty && options.selectableVoices.allSatisfy{$0.gender == nil})
        #expect(options.providerStatus?.configurationState == "ready" && options.providerStatus?.synthesisState == "not_tested")
        #expect(options.providerStatus?.hasSuccessfulObservation == false)
        let speech=try JSONDecoder().decode(DJConnectSpeechResponse.self,from:historyData(genericTTS6ecePrepared(row))).session_speech
        #expect(speechLocaleMatches(speech.effectiveVoice?.locale,speech.locale))
    }
    #expect(!speechLocaleMatches("en//US","en") && !speechLocaleMatches("fr-FR","nl"))
}

@Test(arguments:["scope","duplicate","control","count"])
func genericTTS6eceRejectsUnqualifiedVoiceInventory(_ fault:String) throws {
    let rows=try #require(try genericTTS6eceFixture()["rows"] as? [[String:Any]])
    var envelope=try #require(rows[0]["voice_options"] as? [String:Any])
    var options=try #require(envelope["speech_voice_options"] as? [String:Any])
    var voices=try #require(options["voices"] as? [[String:Any]])
    if fault == "scope" {var c=try #require(options["preference_context"] as? [String:Any]);c["scope"]="global";options["preference_context"]=c}
    if fault == "duplicate" {voices.append(voices[0])}
    if fault == "control" {voices[0]["voice_id"]="injected\nvoice"}
    if fault == "count" {voices=(0..<65).map{["voice_id":"v\($0)","name":"voice"]}}
    options["voices"]=voices;envelope["speech_voice_options"]=options
    let decoded=try JSONDecoder().decode(DJConnectSpeechVoiceOptionsResponse.self,from:historyData(envelope)).speech_voice_options
    #expect(decoded.selectableVoices.isEmpty)
}

@Test(arguments:["code","action","repeat","backoff","version"])
func genericTTS6eceSafeNotificationsFailClosed(_ fault:String) throws {
    let fixture=try genericTTS6eceFixture()
    let failure=try #require(fixture["runtime_failure_fixture"] as? [String:Any])
    let change=try #require(failure["configuration_change_audio"] as? [String:Any])
    var notice=try #require(change["notification"] as? [String:Any])
    #expect(try JSONDecoder().decode(DJConnectSpeechNotification.self,from:historyData(notice)).isValid)
    if fault == "code" {notice["code"]="raw_provider_exception"}
    if fault == "action" {notice["actions"]=["execute_original_request"]}
    if fault == "repeat" {notice["repeat_original_request"]=true}
    if fault == "backoff" {notice["retry_after_seconds"]=300}
    if fault == "version" {notice["schema_version"]=2}
    #expect(!(try JSONDecoder().decode(DJConnectSpeechNotification.self,from:historyData(notice))).isValid)
}

@Test func genericTTS6eceRuntimeFailureAndPrivateAudio409RemainFunctional() async throws {
    let wire=try genericTTS6eceFixture(), rows=try #require(wire["rows"] as? [[String:Any]])
    let failure=try #require(wire["runtime_failure_fixture"] as? [String:Any])
    let options=try JSONDecoder().decode(DJConnectSpeechVoiceOptionsResponse.self,from:historyData(#require(failure["provider_status"]))).speech_voice_options
    #expect(options.isValid && options.providerStatus?.synthesisState == "failed" && options.providerStatus?.hasSuccessfulObservation == false)
    #expect(options.notification?.retryAfterSeconds == 60 && options.notification?.repeatOriginalRequest == false)
    let unavailable=try JSONDecoder().decode(DJConnectSpeechResponse.self,from:historyData(#require(failure["failed_prepare"]))).session_speech
    #expect(unavailable.state == "unavailable" && unavailable.segments.isEmpty && unavailable.notification?.isValid == true)
    let prepared=try JSONDecoder().decode(DJConnectSpeechResponse.self,from:historyData(genericTTS6ecePrepared(rows[0]))).session_speech
    let data=try historyData(#require(failure["configuration_change_audio"]))
    let fixture=HistoryWireFixture{_ in (409,data,0)};defer{fixture.close()}
    do {
        _=try await fixture.client().speechAudio(prepared,acceptedText:prepared.segments.map(\.text).joined())
        Issue.record("Expected functional audio withdrawal")
    } catch let issue as DJConnectSpeechProviderIssue {
        #expect(issue.notification.code == "tts_configuration_changed" && issue.notification.isValid)
    }
    #expect(fixture.requests.count == 1)
}

@Test(arguments:[true,false]) func genericTTS6eceExplicitVoiceIsBoundToInventoryAndConfirmation(_ correctVoice:Bool) async throws {
    let rows=try #require(try genericTTS6eceFixture()["rows"] as? [[String:Any]])
    let row=rows[1]
    let options=try JSONDecoder().decode(DJConnectSpeechVoiceOptionsResponse.self,from:historyData(#require(row["voice_options"]))).speech_voice_options
    let originalEnvelope=try genericTTS6ecePrepared(row)
    let original=try JSONDecoder().decode(DJConnectSpeechResponse.self,from:historyData(originalEnvelope)).session_speech
    var responseEnvelope=originalEnvelope
    var responseSpeech=try #require(responseEnvelope["session_speech"] as? [String:Any])
    var responseVoice=try #require(responseSpeech["effective_voice"] as? [String:Any])
    responseVoice["voice_id"]=correctVoice ? "cedar" : "alloy"
    responseSpeech["effective_voice"]=responseVoice;responseEnvelope["session_speech"]=responseSpeech
    let response=try historyData(responseEnvelope)
    let fixture=HistoryWireFixture{_ in (200,response,0)};defer{fixture.close()}
    let text=original.segments.map(\.text).joined()
    #expect(original.admits(reference:original.reference,text:text) && original.advertisesPreparationAttempt(.haConfigured))
    #expect(options.supportsVoice("cedar"))
    if correctVoice {
        do {
            let prepared=try await fixture.client().prepareSpeech(original,acceptedText:text,processor:.haConfigured,voiceOptions:options,selectedVoiceID:"cedar")
            #expect(prepared.effectiveVoice?.voiceID == "cedar")
        } catch { Issue.record("Prepare phase rejected qualified modeled voice: \(error)");return }
    } else {
        await #expect(throws:DJConnectError.invalidResponse) {
            try await fixture.client().prepareSpeech(original,acceptedText:text,processor:.haConfigured,voiceOptions:options,selectedVoiceID:"cedar")
        }
    }
    let request=try #require(fixture.requests.first)
    let requestBody=try presenceRequestBody(request)
    let body=try #require(JSONSerialization.jsonObject(with:requestBody) as? [String:Any])
    #expect(body["voice_id"] as? String == "cedar" && body["voice_preference"] as? String == "default")
    #expect(body["engine"] == nil && body["provider"] == nil && body["text"] == nil)
    let count=fixture.requests.count
    await #expect(throws:DJConnectError.invalidResponse) {
        try await fixture.client().prepareSpeech(original,acceptedText:text,processor:.haConfigured,voiceOptions:options,selectedVoiceID:"unknown")
    }
    #expect(fixture.requests.count == count)
}

}


private func scopedVoiceOptions(removing voiceID: String? = nil) throws -> DJConnectSpeechVoiceOptions {
    let rows = try #require(try genericTTS6eceFixture()["rows"] as? [[String: Any]])
    let envelope = try #require(rows.first?["voice_options"] as? [String: Any])
    var payload = try #require(envelope["speech_voice_options"] as? [String: Any])
    if let voiceID {
        let voices = try #require(payload["voices"] as? [[String: Any]])
        payload["voices"] = voices.filter { $0["voice_id"] as? String != voiceID }
    }
    return try JSONDecoder().decode(DJConnectSpeechVoiceOptions.self, from: historyData(payload))
}

@Test func speechVoicePreferenceRequiresEveryConfirmedIdentity() throws {
    for index in 0..<4 {
        for invalid in ["", "   ", "a\nb", String(repeating: "x", count: 513)] {
            var fields = ["ha", "profile", "session", "device"]
            fields[index] = invalid
            #expect(DJConnectSpeechVoiceScope(installationID: fields[0], profileID: fields[1],
                sessionID: fields[2], deviceID: fields[3]) == nil)
        }
    }
    var state = DJConnectSpeechVoicePreferenceState()
    #expect({ state.beginRefresh() == nil }())
    #expect({ !state.select("cedar") && state.resolution == .unavailable }())
}

@Test func speechVoicePreferenceDiscardsAcrossEveryScopeDimension() throws {
    let base = try #require(DJConnectSpeechVoiceScope(installationID: "ha", profileID: "profile", sessionID: "session", deviceID: "device"))
    let options = try scopedVoiceOptions()
    for index in 0..<4 {
        var state = DJConnectSpeechVoicePreferenceState()
        state.bind(base)
        let refresh = try #require({ state.beginRefresh() }())
        #expect({ state.completeRefresh(refresh, options: options) }())
        #expect({ state.select("cedar") && state.resolution == .selected("cedar") }())
        state.bind(base)
        #expect(state.resolution == .selected("cedar"))
        var fields = ["ha", "profile", "session", "device"]
        fields[index] += "-other"
        state.bind(try #require(DJConnectSpeechVoiceScope(installationID: fields[0], profileID: fields[1], sessionID: fields[2], deviceID: fields[3])))
        #expect(state.selectedVoiceID == nil && state.options == nil && state.resolution == .unavailable)
        state.bind(base)
        #expect(state.selectedVoiceID == nil && state.options == nil)
        #expect({ !state.completeRefresh(refresh, options: options) }())
    }
    // Structured fields do not alias when opaque identifiers contain separators.
    #expect(DJConnectSpeechVoiceScope(installationID: "a|b", profileID: "c", sessionID: "s", deviceID: "d") !=
        DJConnectSpeechVoiceScope(installationID: "a", profileID: "b|c", sessionID: "s", deviceID: "d"))
}

@Test func speechVoicePreferenceRemovedVoiceNeverFallsBackSilently() throws {
    var state = DJConnectSpeechVoicePreferenceState()
    state.bind(try #require(DJConnectSpeechVoiceScope(installationID: "ha", profileID: "profile", sessionID: "session", deviceID: "device")))
    let options = try scopedVoiceOptions()
    let initialRefresh = try #require({ state.beginRefresh() }())
    #expect({ state.completeRefresh(initialRefresh, options: options) }())
    #expect(state.resolution == .configuredDefault)
    #expect({ state.select("cedar") }())
    let refresh = try #require({ state.beginRefresh() }())
    #expect(state.resolution == .unavailable && state.selectedVoiceID == "cedar")
    #expect({ !state.select("alloy") }())
    let removedOptions = try scopedVoiceOptions(removing: "cedar")
    #expect({ state.completeRefresh(refresh, options: removedOptions) }())
    #expect(state.selectedVoiceID == "cedar" && state.resolution == .unavailable)
    #expect({ !state.select("unknown") && state.selectedVoiceID == "cedar" }())
    #expect({ state.select(nil) && state.resolution == .configuredDefault }())
}

@Test func speechVoicePreferenceRefreshFencesBackgroundAndSessionEnd() throws {
    var state = DJConnectSpeechVoicePreferenceState()
    let scope = try #require(DJConnectSpeechVoiceScope(installationID: "ha", profileID: "profile", sessionID: "session", deviceID: "device"))
    state.bind(scope)
    let options = try scopedVoiceOptions()
    let first = try #require({ state.beginRefresh() }())
    let second = try #require({ state.beginRefresh() }())
    #expect({ !state.completeRefresh(first, options: options) && state.refreshing }())
    #expect({ state.completeRefresh(second, options: options) }())
    #expect({ !state.completeRefresh(second, options: options) }())
    #expect({ state.select("cedar") }())
    let background = try #require({ state.beginRefresh() }())
    state.invalidateInventory()
    #expect({ !state.completeRefresh(background, options: options) }())
    #expect(state.selectedVoiceID == "cedar" && state.resolution == .unavailable)
    let failed = try #require({ state.beginRefresh() }())
    #expect({ !state.completeRefresh(failed, options: nil) }())
    #expect(state.selectedVoiceID == "cedar" && state.resolution == .unavailable && !state.refreshing)
    let ended = try #require({ state.beginRefresh() }())
    state.discard()
    state.bind(scope)
    #expect({ !state.completeRefresh(ended, options: options) }())
    #expect(state.selectedVoiceID == nil && state.options == nil)
}

@Suite(.serialized) struct ActiveVoiceMenuIntegrationTests {
@Test @MainActor func activeVoiceMenuReadsOnlyAndAutoplayKeepsExistingPreference() async throws {
    let runtime = try activePersonaRuntimeWire(), caps = try activePersonaCapsWire()
    let profile = try historyData(try #require(historyObject()["later_historical_answer"]))
    let rows = try #require(try genericTTS6eceFixture()["rows"] as? [[String: Any]])
    let voices = try historyData(try #require(rows.first?["voice_options"]))
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/session/active") { return (200, runtime, 0) }
        if request.url!.path.hasSuffix("ask_dj/history") { return (200, profile, 0) }
        if request.url!.path.hasSuffix("/voice-options") { return (200, voices, 0) }
        return (404, Data(#"{"success":false}"#.utf8), 0)
    }; defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    defaults.set("test-installation", forKey: "DJConnectHAInstallID")
    await model.sessionHistory.prepare(); await model.refreshActiveDJSession()
    await model.refreshActiveVoiceOptions()
    let scope = try #require(model.activeVoicePreference.scope)
    #expect(scope.profileID == model.sessionHistory.authorizedProfileID && model.activeVoiceIsCurrent)
    #expect(model.activeVoicePreference.options?.selectableVoices.count == 13)
    let sessionID = try #require(model.activeDJSession?.id)
    let recoveryPaths: Set<String> = [
        "/api/djconnect/v1/capabilities", "/api/djconnect/v1/session/active",
        "/api/djconnect/v1/ask_dj/history", "/api/djconnect/v1/session/history/" + sessionID
    ]
    func menuRequestCount() -> Int {
        fixture.requests.filter { !($0.httpMethod == "GET" && recoveryPaths.contains($0.url!.path)) }.count
    }
    let count = menuRequestCount(), epoch = model.sessionHistory.responseEpoch
    #expect(count == 1, "Only the original POST voice-inventory read is outside recovery GETs")
    let requestOffset = fixture.requests.count
    // Force a concurrent, permitted recovery read through the same fixture.
    // Whole-fixture counts incorrectly attributed this independent work to UI actions.
    let concurrentRead = Task { try await fixture.client().activeSession() }
    model.selectActiveVoice("cedar", expectedScope: scope, expectedEpoch: epoch)
    #expect(model.activeVoicePreference.resolution == .selected("cedar"))
    model.selectActiveVoice("alloy", expectedScope: scope, expectedEpoch: UUID())
    #expect(model.activeVoicePreference.resolution == .selected("cedar"))
    model.localResponseAudioEnabled = true
    #expect(defaults.bool(forKey: "DJConnectLocalResponseAudioEnabled"))
    model.localResponseAudioEnabled = false
    #expect(!defaults.bool(forKey: "DJConnectLocalResponseAudioEnabled"))
    _ = try await concurrentRead.value
    #expect(menuRequestCount() == count)
    #expect(fixture.requests.count > requestOffset, "Positive control: independent recovery changed the whole-fixture count")
    #expect(fixture.requests.dropFirst(requestOffset).allSatisfy { $0.httpMethod == "GET" })
    #expect(fixture.requests.allSatisfy { !$0.url!.path.hasSuffix("/prepare") && !$0.url!.path.hasSuffix("/audio") && !$0.url!.path.contains("/operation/execute") })
    model.sessionHistory.suspend(preservingVoicePreference: true)
    #expect(model.activeVoicePreference.selectedVoiceID == "cedar" && model.activeVoicePreference.options == nil)
    await model.sessionHistory.refreshConversation()
    await model.refreshActiveVoiceOptions()
    #expect(model.activeVoicePreference.resolution == .selected("cedar"))
    model.sessionHistory.suspend()
    #expect(model.activeVoicePreference.scope == nil && model.activeVoicePreference.selectedVoiceID == nil)
}

@Test(arguments: ["background", "owner", "installation", "end"])
@MainActor func activeVoiceMenuRejectsLateInventory(_ change: String) async throws {
    let runtime = try activePersonaRuntimeWire(), caps = try activePersonaCapsWire()
    var profileObject = try #require(historyObject()["later_historical_answer"] as? [String: Any])
    let profile = try historyData(profileObject)
    profileObject["owner_profile_id"] = "other-confirmed-owner"
    let otherProfile = try historyData(profileObject)
    var ended = try #require(JSONSerialization.jsonObject(with: runtime) as? [String: Any])
    var endedSession = try #require(ended["session"] as? [String: Any]); endedSession["runtime_state"] = "ended"
    var endedBroadcast = try #require(endedSession["broadcast"] as? [String: Any])
    var endedState = try #require(endedBroadcast["session"] as? [String: Any]); endedState["runtime_state"] = "ended"
    endedBroadcast["session"] = endedState; endedSession["broadcast"] = endedBroadcast
    ended["session"] = endedSession
    let endedData = try historyData(ended)
    let rows = try #require(try genericTTS6eceFixture()["rows"] as? [[String: Any]])
    let voices = try historyData(try #require(rows.first?["voice_options"]))
    let changed = HistoryAuthorityGate()
    let replyGate = HistoryWireResponseGate()
    defer { replyGate.release() }
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/session/active") { return (200, changed.denied && change == "end" ? endedData : runtime, 0) }
        if request.url!.path.hasSuffix("ask_dj/history") { return (200, changed.denied && change == "owner" ? otherProfile : profile, 0) }
        if request.url!.path.hasSuffix("/voice-options") {
            throw HistoryWireHeldResponse(data: voices, gate: replyGate)
        }
        return (404, Data(#"{"success":false}"#.utf8), 0)
    }; defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare(); await model.refreshActiveDJSession()
    // No HA installation identity means no scoped voice read, even with an authorized owner.
    await model.refreshActiveVoiceOptions()
    #expect(!fixture.requests.contains { $0.url!.path.hasSuffix("/voice-options") })
    defaults.set("test-installation", forKey: "DJConnectHAInstallID")
    let pending = Task { await model.refreshActiveVoiceOptions() }
    for _ in 0..<120 where !fixture.requests.contains(where: { $0.url!.path.hasSuffix("/voice-options") }) {
        try await Task.sleep(for: .milliseconds(25))
    }
    #expect(model.activeVoicePreference.refreshing)
    changed.denied = true
    switch change {
    case "background": model.markInactiveSession()
    case "owner": await model.sessionHistory.refreshConversation()
    case "installation": defaults.set("other-installation", forKey: "DJConnectHAInstallID"); model.invalidateActiveVoiceInventory()
    default: await model.refreshActiveDJSession()
    }
    replyGate.release()
    await pending.value
    #expect(model.activeVoicePreference.options == nil && model.activeVoiceError == nil)
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/voice-options") }.count == 1)
}
}

private func providerGenderRows() throws -> [[String: Any]] {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/provider-voice-gender-coreff507c8.http.json"))) as? [String: Any])
    return try #require(object["rows"] as? [[String: Any]])
}
private func providerGenderOptions(_ row: [String: Any]) throws -> DJConnectSpeechVoiceOptions {
    try JSONDecoder().decode(DJConnectSpeechVoiceOptionsResponse.self, from: historyData(#require(row["options"]))).speech_voice_options
}

@Suite(.serialized) struct ProviderQualifiedVoiceGenderTests {
    @Test func fiveLanguageProducerMappingsAdmitOnlyExplicitMetadata() throws {
        let rows = try providerGenderRows()
        #expect(rows.count == 5)
        for row in rows {
            let options = try providerGenderOptions(row)
            #expect(options.isValid && Set(options.selectableGenders) == [.male, .female])
            for gender in [DJConnectVoicePreference.male, .female] {
                let voiceID = try #require(options.qualifiedGenderVoiceID(gender))
                #expect(options.admitsGender(gender, voiceID: voiceID))
                #expect(options.selectableVoices.contains { $0.voiceID == voiceID && $0.gender == gender.rawValue })
                let opposite = try #require(options.qualifiedGenderVoiceID(gender == .male ? .female : .male))
                #expect(!options.admitsGender(gender, voiceID: opposite))
            }
        }
    }

    @Test(arguments: ["missing-map", "wrong-target", "missing-voice", "unknown-key", "duplicate", "no-metadata", "disabled"])
    func malformedOrWithdrawnGenderHidesButtonsWithoutInventingValues(_ fault: String) throws {
        let row = try #require(providerGenderRows().first)
        let envelope = try #require(row["options"] as? [String: Any])
        var options = try #require(envelope["speech_voice_options"] as? [String: Any])
        var gender = try #require(options["gender_selection"] as? [String: Any])
        var targets = try #require(gender["voice_ids"] as? [String: String])
        switch fault {
        case "missing-map": gender.removeValue(forKey: "voice_ids")
        case "wrong-target": targets["male"] = targets["female"]; gender["voice_ids"] = targets
        case "missing-voice": targets["male"] = "not-in-current-inventory"; gender["voice_ids"] = targets
        case "unknown-key": targets["guessed"] = "GuyNeural"; gender["voice_ids"] = targets
        case "duplicate": gender["values"] = ["male", "male"]
        case "disabled": gender["available"] = false
        default:
            var voices = try #require(options["voices"] as? [[String: Any]])
            for index in voices.indices { voices[index]["gender"] = NSNull() }
            options["voices"] = voices
        }
        options["gender_selection"] = gender
        let decoded = try JSONDecoder().decode(DJConnectSpeechVoiceOptions.self, from: historyData(options))
        #expect(decoded.isValid && !decoded.selectableVoices.isEmpty)
        #expect(decoded.selectableGenders.isEmpty && !decoded.supports(.male) && !decoded.supports(.female))
        #expect(decoded.qualifiedGenderVoiceID(.male) == nil)
    }

    @Test func localGenderIntentUsesProducerTargetAndSurvivesWithdrawalUntilExplicitReset() throws {
        let options = try providerGenderOptions(#require(providerGenderRows().first))
        let male = try #require(options.qualifiedGenderVoiceID(.male)), female = try #require(options.qualifiedGenderVoiceID(.female))
        let scope = try #require(DJConnectSpeechVoiceScope(installationID: "ha", profileID: "profile", sessionID: "session", deviceID: "device"))
        var state = DJConnectSpeechVoicePreferenceState(); state.bind(scope)
        let refresh = try #require({ state.beginRefresh() }())
        #expect({ state.completeRefresh(refresh, options: options) }())
        #expect({ state.selectGender(.male) }())
        #expect(state.selectedGender == .male && state.resolution == .selected(male))
        #expect({ state.select(female) }())
        #expect(state.selectedGender == .female && state.resolution == .selected(female))
        #expect({ state.selectGender(.male) }())
        #expect(state.selectedVoiceID == male && state.selectedGender == .male)
        let unknownGenderOptions = try scopedVoiceOptions()
        let withdrawn = try #require({ state.beginRefresh() }())
        #expect({ state.completeRefresh(withdrawn, options: unknownGenderOptions) }())
        #expect(state.selectedGender == .male && state.selectedVoiceID == male && state.resolution == .unavailable)
        #expect({ !state.selectGender(.female) }())
        #expect(state.selectedGender == .male && state.selectedVoiceID == male)
        #expect({ state.select(nil) }())
        #expect(state.selectedGender == .default && state.resolution == .configuredDefault)
        let restored = try #require({ state.beginRefresh() }())
        #expect({ state.completeRefresh(restored, options: options) }())
        #expect({ state.selectGender(.female) }())
        state.discard()
        #expect(state.selectedGender == .default && state.selectedVoiceID == nil && state.scope == nil)
    }

    @Test func prepareRejectsConflictingGenderBeforeAnyRequest() async throws {
        let row = try #require(providerGenderRows().first), options = try providerGenderOptions(row)
        let renewed = try genericTTS6ecePrepared(row)
        let original = try JSONDecoder().decode(DJConnectSpeechResponse.self, from: historyData(renewed)).session_speech
        let fixture = HistoryWireFixture { _ in (200, Data(), 0) }; defer { fixture.close() }
        let female = try #require(options.qualifiedGenderVoiceID(.female))
        #expect(original.admits(reference: original.reference, text: original.segments.map(\.text).joined()) && original.advertisesPreparationAttempt(.haConfigured))
        await #expect(throws: DJConnectError.invalidResponse) {
            try await fixture.client().prepareSpeech(original, acceptedText: original.segments.map(\.text).joined(),
                processor: .haConfigured, preference: .male, voiceOptions: options, selectedVoiceID: female)
        }
        #expect(fixture.requests.isEmpty)
    }
    @Test(arguments: ["valid", "unknown-voice", "different-qualified-voice"])
    func prepareConfirmsExactAdvertisedGenderTarget(_ outcome: String) async throws {
        let row = try #require(providerGenderRows().first)
        var options = try providerGenderOptions(row)
        let renewed = try genericTTS6ecePrepared(row)
        let original = try JSONDecoder().decode(DJConnectSpeechResponse.self, from: historyData(renewed)).session_speech
        let male = try #require(options.qualifiedGenderVoiceID(.male))
        if outcome == "different-qualified-voice" {
            // Explicit modeled provider metadata: this historical Cloud fixture has only one
            // qualified male target. Model a second advertised male voice without changing its
            // exact producer-default target. Canonical fixture bytes remain untouched.
            let envelope = try #require(row["options"] as? [String: Any])
            var payload = try #require(envelope["speech_voice_options"] as? [String: Any])
            var voices = try #require(payload["voices"] as? [[String: Any]])
            let index = try #require(voices.firstIndex { ($0["gender"] as? String) == nil })
            voices[index]["gender"] = "male"; payload["voices"] = voices
            options = try JSONDecoder().decode(DJConnectSpeechVoiceOptions.self, from: historyData(payload))
        }
        var reply = renewed
        if outcome != "valid" {
            var speech = try #require(reply["session_speech"] as? [String: Any])
            var voice = try #require(speech["effective_voice"] as? [String: Any])
            voice["voice_id"] = outcome == "unknown-voice" ? "not-in-inventory" :
                try #require(options.selectableVoices.first { $0.gender == "male" && $0.voiceID != male }).voiceID
            speech["effective_voice"] = voice; reply["session_speech"] = speech
        }
        let data = try historyData(reply)
        let fixture = HistoryWireFixture { _ in (200, data, 0) }; defer { fixture.close() }
        if outcome == "valid" {
            let prepared = try await fixture.client().prepareSpeech(original, acceptedText: original.segments.map(\.text).joined(),
                processor: .haConfigured, preference: .male, voiceOptions: options)
            #expect(prepared.effectiveVoice?.voiceID == male && prepared.effectiveVoice?.gender == "male")
        } else {
            await #expect(throws: DJConnectError.invalidResponse) {
                try await fixture.client().prepareSpeech(original, acceptedText: original.segments.map(\.text).joined(),
                    processor: .haConfigured, preference: .male, voiceOptions: options)
            }
        }
        #expect(fixture.requests.count == 1)
    }

}

@Test @MainActor func sessionTimelineRejectsOwnerlessReadUntilRequalified() async throws {
    let receipt = try historyObject()
    let page = try historyData(try #require(receipt["archived_timeline"]))
    let decoded = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: page)
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") {
            return (200, Data(#"{"capabilities":{"session_conversation_history":true},"contract_versions":{"session_conversation_history":1}}"#.utf8), 0)
        }
        return (200, request.url!.path.hasSuffix("ask_dj/history") ? profile : page, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    let history = model.sessionHistory
    await history.prepare()
    #expect(await history.loadTimeline(decoded.session.id))
    let admitted = try #require(history.timelines[decoded.session.id])
    try #require(!admitted.entries.isEmpty)
    history.suspend()
    let count = fixture.requests.count
    #expect(!(await history.loadTimeline(decoded.session.id)))
    #expect(fixture.requests.count == count)
    #expect(history.authorizedProfileID == nil && history.timelines.isEmpty)
    await history.prepare()
    #expect(await history.loadTimeline(decoded.session.id))
    #expect(history.timelines[decoded.session.id]?.entries.map(\.id) == admitted.entries.map(\.id))
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
}

@Test @MainActor func savedSessionsRejectOwnerlessReadsUntilRequalified() async throws {
    let receipt = try historyObject()
    let timeline = try #require(receipt["archived_timeline"] as? [String: Any])
    let row = try #require(timeline["session"] as? [String: Any])
    let page = try historyData(["success": true, "schema_version": 1, "sessions": [row],
        "revision": try #require(timeline["revision"]), "retention_days": 30])
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") {
            return (200, Data(#"{"capabilities":{"session_conversation_history":true},"contract_versions":{"session_conversation_history":1}}"#.utf8), 0)
        }
        return (200, request.url!.path.hasSuffix("/session/history") ? page : profile, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    let history = model.sessionHistory
    await history.prepare()
    #expect(await history.loadSessions())
    let admitted = history.sessions
    #expect(admitted.count == 1)
    history.suspend()
    let count = fixture.requests.count
    #expect(!(await history.loadSessions()))
    #expect(fixture.requests.count == count)
    #expect(history.authorizedProfileID == nil && history.sessions.isEmpty)
    await history.restoreVisibleSessions()
    #expect(history.authorizedProfileID != nil)
    #expect(history.sessions == admitted)
}

@Test @MainActor func savedSessionsLazyPagingAppendsOnceAndStopsAtEnd() async throws {
    let receipt = try historyObject()
    let timeline = try #require(receipt["archived_timeline"] as? [String: Any])
    let original = try #require(timeline["session"] as? [String: Any])
    var older = original; older["session_id"] = "older-session"
    let revision = try #require(timeline["revision"])
    let first = try historyData(["success":true,"schema_version":1,"sessions":[original],"revision":revision,"retention_days":30,"next_cursor":"page-two"])
    let next = try historyData(["success":true,"schema_version":1,"sessions":[original,older],"revision":revision,"retention_days":30])
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    let gate = HistoryWireResponseGate(); defer { gate.release() }
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") {
            return (200, Data(#"{"capabilities":{"session_conversation_history":true},"contract_versions":{"session_conversation_history":1}}"#.utf8), 0)
        }
        if request.url!.path.hasSuffix("/session/history") {
            if URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == "cursor" }) == true {
                throw HistoryWireHeldResponse(data: next, gate: gate)
            }
            return (200, first, 0)
        }
        return (200, profile, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    let history = model.sessionHistory
    await history.prepare()
    #expect(await history.loadSessions())
    let initialIDs = history.sessions.map(\.id)
    #expect(initialIDs.count == 1)
    #expect(!(await history.loadNextSessionsPage(expectedCursor: "stale-footer")))
    let loading = Task { await history.loadNextSessionsPage(expectedCursor: "page-two") }
    for _ in 0..<1000 where !history.listLoading { await Task.yield() }
    #expect(history.listLoading)
    #expect(!(await history.loadNextSessionsPage(expectedCursor: "page-two")))
    gate.release()
    #expect(await loading.value)
    #expect(history.sessions.map(\.id) == initialIDs + ["older-session"])
    #expect(history.listNextCursor == nil && !history.listLoading)
    #expect(!(await history.loadNextSessionsPage(expectedCursor: "page-two")))
    let reads = fixture.requests.filter { $0.url?.path.hasSuffix("/session/history") == true }
    #expect(reads.count == 2)
}

@Test(arguments: ["transient", "repeated_cursor", "revision_change"])
@MainActor func savedSessionsLazyPagingFailurePreservesRowsAndDoesNotRetry(_ failure: String) async throws {
    let receipt = try historyObject()
    let timeline = try #require(receipt["archived_timeline"] as? [String: Any])
    let original = try #require(timeline["session"] as? [String: Any])
    let revision = try #require(timeline["revision"])
    let first = try historyData(["success":true,"schema_version":1,"sessions":[original],"revision":revision,"retention_days":30,"next_cursor":"page-two"])
    let next = try historyData(["success":true,"schema_version":1,"sessions":[],"revision":failure == "revision_change" ? "changed" : revision,"retention_days":30,"next_cursor":"page-two"])
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") {
            return (200, Data(#"{"capabilities":{"session_conversation_history":true},"contract_versions":{"session_conversation_history":1}}"#.utf8), 0)
        }
        if request.url!.path.hasSuffix("/session/history") {
            let more = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == "cursor" }) == true
            return more ? (failure == "transient" ? 503 : 200, next, 0) : (200, first, 0)
        }
        return (200, profile, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    let history = model.sessionHistory
    await history.prepare()
    #expect(await history.loadSessions())
    let confirmed = history.sessions
    #expect(!(await history.loadNextSessionsPage(expectedCursor: "page-two")))
    #expect(history.sessions == confirmed && history.listErrorKey != nil && !history.listLoading)
    #expect(!(await history.loadNextSessionsPage(expectedCursor: "page-two")))
    #expect(fixture.requests.filter { $0.url?.path.hasSuffix("/session/history") == true }.count == 2)
    // Explicit refresh clears the error and admits the new first-page cursor.
    #expect(await history.loadSessions())
    #expect(history.listErrorKey == nil && history.listNextCursor == "page-two")
}


@Test(arguments: [false, true]) @MainActor
func cancelledPresenceMenuReadPreservesConfirmedState(capabilityRead: Bool) async throws {
    let phase = HistoryAuthorityGate()
    let runtime = try presenceRuntimeWire()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/session/active") {
            return (200, phase.denied && !capabilityRead ? Data(#"{"success":false}"#.utf8) : runtime, phase.denied ? 0.2 : 0)
        }
        if request.url!.path.hasSuffix("/capabilities") {
            return (200, phase.denied ? Data(#"{}"#.utf8) : presenceCapsWire, phase.denied ? 0.2 : 0)
        }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshActiveDJSession(); await model.refreshActiveMoodCapability()
    let confirmed = try #require(model.activeDJSession?.confirmedPresence)
    #expect(model.activePresenceAvailable && model.activePresenceCapabilityStatus == .supported)
    let count = fixture.requests.count
    phase.denied = true
    let pending = Task {
        if capabilityRead { await model.refreshActiveMoodCapability() }
        else { await model.refreshActiveDJSession() }
    }
    for _ in 0..<100 where fixture.requests.count == count { try await Task.sleep(for: .milliseconds(5)) }
    #expect(fixture.requests.count > count)
    pending.cancel()
    await pending.value
    #expect(model.activeDJSession?.confirmedPresence == confirmed)
    #expect(model.djSessionErrorMessage == nil)
    #expect(model.activePresenceAvailable && model.activePresenceCapabilityStatus == .supported)
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
}

@Test @MainActor func cancelledPresenceMenuReadCannotRestoreOverNewerCapabilityRead() async throws {
    let phase = PresenceReadPhase()
    let fixture = HistoryWireFixture { request in
        guard request.url!.path.hasSuffix("/capabilities") else { return (404, Data(), 0) }
        return phase.value == 1 ? (200, presenceCapsWire, 0.2) : (200, Data(#"{}"#.utf8), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    phase.value = 1
    let pending = Task { await model.refreshActiveMoodCapability() }
    for _ in 0..<100 where fixture.requests.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
    #expect(!fixture.requests.isEmpty)
    phase.value = 2
    await model.refreshActiveMoodCapability()
    pending.cancel(); await pending.value
    #expect(!model.activePresenceAvailable && model.activePresenceCapabilityStatus == .unsupported)
}

@Test @MainActor func sessionIntroductionOnlyFollowsFirstSuccessfulExplicitStart() async throws {
    let name = "session-introduction-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    #expect(!model.isSessionIntroductionPresented)
    await model.startDJSession()
    #expect(!model.isSessionIntroductionPresented, "An unpaired/failed start must not consume the introduction")
    model.startDemoMode()
    #expect(!model.isSessionIntroductionPresented, "Restoring or displaying a demo session is not an explicit start")
    await model.startDJSession()
    #expect(model.isSessionIntroductionPresented)
    model.dismissSessionIntroduction()
    await model.endDJSession()
    await model.startDJSession()
    #expect(!model.isSessionIntroductionPresented)
    let relaunched = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    relaunched.startDemoMode()
    await relaunched.startDJSession()
    #expect(!relaunched.isSessionIntroductionPresented, "Completion/skip survives app relaunch for this installation")
}

@Test(arguments: [0, 6]) @MainActor func currentOnlyConversationKeepsQuestionAndSessionReplyAcrossHistoryRefresh(choiceCount: Int) async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: root.appendingPathComponent("Fixtures/current-artist-identification-producer.json"))
    let receipt = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let cases = try #require(receipt["cases"] as? [[String: Any]])
    var body = try #require(cases.first { $0["case"] as? String == "artist-session-0-text" }?["response"] as? [String: Any])
    if choiceCount > 0 {
        let producer = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/moment-insight-core-producer.json"))) as? [String: Any])
        let choices = try #require(producer["fixtures"] as? [[String: Any]])
        let choiceBody = try #require(choices.first { $0["case"] as? String == "standalone-refine" }?["body"] as? [String: Any])
        let seed = try #require((choiceBody["playback_actions"] as? [[String: Any]])?.first)
        let actions = (0..<choiceCount).map { index -> [String: Any] in
            var action = seed
            let uri = "spotify:track:" + String(repeating: String(index), count: 22)
            action["id"] = uri; action["uri"] = uri; action["action_id"] = "synthetic-choice-\(index)"
            action["title"] = "Synthetic recording \(index + 1)"
            action["value"] = ["uri": uri, "title": "Synthetic recording \(index + 1)", "subtitle": "Synthetic performer"]
            return action
        }
        body["items"] = actions; body["playback_actions"] = actions
        var result = try #require(choiceBody["result_set"] as? [String: Any]); result["expires_in"] = 60
        body["result_set"] = result
        body["server_time"] = ISO8601DateFormatter().string(from: Date())
    }
    let response = try JSONDecoder().decode(DJConnectSessionConversationResponse.self, from: historyData(body))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true},"contract_versions":{"session_conversation_history":1}}"#.utf8)
    let history = Data(#"{"success":true,"owner_profile_id":"profile-a","history_revision":42,"clear_revision":3,"messages":[]}"#.utf8)
    let fixture = HistoryWireFixture { request in (200, request.url!.path.hasSuffix("/capabilities") ? caps : history, 0) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    let question = try #require(model.beginProfileConversationText(text: "Welke artiest speelt er?", clientMessageID: "current-question"))
    #expect(model.applyProfileConversationResponse(response.base, fallback: question, sessionID: "current-session"))
    await model.sessionHistory.refreshConversation()
    let visible = model.currentSessionConversationMessages(sessionID: "current-session")
    #expect(visible.count == 2)
    #expect(visible.contains { $0.id == question && $0.role == .user && $0.text == "Welke artiest speelt er?" })
    #expect(visible.contains { $0.role == .dj && $0.text == response.base.djText })
    #expect(visible.first { $0.role == .dj }?.items.count == choiceCount)
    #expect(visible.first { $0.role == .dj }?.playbackActions.count == choiceCount)
    #expect(model.currentSessionConversationMessages(sessionID: "another-session").isEmpty)
    #expect(defaults.data(forKey: "DJConnectAskDJMessages") == nil)
    model.sessionHistory.suspend()
    #expect(model.currentSessionConversationMessages(sessionID: "current-session").isEmpty)
    #expect(!model.askDJMessages.contains { $0.id == question })
}

@Test @MainActor func demoPresenceChoicesStayLocalAndRespectSessionScope() async throws {
    let fixture = HistoryWireFixture { _ in (500, Data(), 0) }; defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    model.startDemoMode()
    let session = try #require(model.activeDJSession)
    let epoch = model.sessionHistory.responseEpoch
    #expect(model.activePresenceAvailable && session.confirmedPresence?.selectedPresence == .balanced)
    await model.refreshActiveMoodCapability()
    #expect(model.activePresenceCapabilityStatus == .supported)
    for value in DJConnectSessionPresenceValue.allCases {
        model.selectActiveSessionPresence(value, expectedSessionID: session.id, expectedEpoch: epoch)
        #expect(model.activeDJSession?.confirmedPresence?.selectedPresence == value)
    }
    model.selectActiveSessionPresence(.musicOnly, expectedSessionID: "wrong-session", expectedEpoch: epoch)
    model.selectActiveSessionPresence(.musicOnly, expectedSessionID: session.id, expectedEpoch: UUID())
    #expect(model.activeDJSession?.confirmedPresence?.selectedPresence == .presenter)
    #expect(!model.activePresencePending && fixture.requests.isEmpty)
}

@Test func sharedBrandTaglineUsesExactApprovedCopyInEveryLanguage() {
    let expected = [
        "en": "Your music. Your DJ.",
        "nl": "Jouw muziek. Jouw DJ.",
        "de": "Deine Musik. Dein DJ.",
        "fr": "Votre musique. Votre DJ.",
        "es": "Tu música. Tu DJ."
    ]
    for language in DJConnectLocalization.supportedLanguageCodes {
        #expect(DJConnectLocalization.localized(key: "brand.tagline", language: language) == expected[language])
        #expect(DJConnectLocalization.localized(key: "ui.device_speech.sample", language: language).hasPrefix((expected[language] ?? "") + " "))
    }
    #expect(DJConnectLocalization.localized(key: "brand.tagline", language: "nl-NL") == expected["nl"])
    #expect(DJConnectLocalization.localized(key: "brand.tagline", language: "unsupported") == expected["en"])
}

@Test @MainActor func sessionArtworkPrefetchWindowIsVisibleFirstAndBounded() throws {
    let receipt = try historyObject()
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: historyData(try #require(receipt["archived_timeline"])))
    let rows = page.entries
    let now = try #require(DJConnectHistoryEntry.date(rows[0].occurredAt)).addingTimeInterval(1)
    let eligible = rows.filter { [.playbackObserved, .djMoment].contains($0.kind) && $0.isRetained(at: now) }
    let middle = try #require(eligible.dropFirst().first)
    let window = DJConnectSessionHistoryModel.artworkWindow(entries: rows, visibleIDs: [middle.id], at: now)
    #expect(window.first == middle.reference)
    #expect(window.count <= 3 && Set(window).count == window.count)
    #expect(!window.contains { ref in rows.first(where: { $0.reference == ref })?.kind == .conversationUser })
    #expect(DJConnectSessionHistoryModel.artworkWindow(entries: rows, visibleIDs: [], at: now).isEmpty)
    #expect(DJConnectSessionHistoryModel.artworkWindow(entries: rows, visibleIDs: ["not-loaded"], at: now).isEmpty)
    #expect(DJConnectSessionHistoryModel.artworkWindow(entries: rows, visibleIDs: [middle.id], at: .distantFuture).isEmpty)
}

@Test @MainActor func sessionHistoryActiveForegroundIgnoresOldBubbleAnchorWhileArchiveRetainsIt() async throws {
    let receipt = try historyObject("window-producer-receipt")
    // The foreground API requests its ordinary 20-row window. Adapt only the
    // fixture's request echo; retain its canonical identities, entries and order.
    var tailObject = try #require(receipt["tail_window"] as? [String: Any])
    var anchorObject = try #require(receipt["anchor_window"] as? [String: Any])
    tailObject["window_limit"] = 20; anchorObject["window_limit"] = 20
    let tail = try historyData(tailObject)
    let anchored = try historyData(anchorObject)
    let anchorPage = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: anchored)
    let oldAnchor = try #require(anchorPage.anchorEntryID)
    let profile = try historyData(try #require(historyObject()["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true},"contract_versions":{"session_conversation_history":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("ask_dj/history") { return (200, profile, 0) }
        let window = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "window" })?.value
        return (200, window == "anchor" ? anchored : tail, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.restoreVisibleTimeline(anchorPage.session.id, active: true, anchor: oldAnchor)
    let activeReads = fixture.requests.filter { $0.url!.path.contains("/session/history/") }
    #expect(!activeReads.isEmpty)
    #expect(activeReads.allSatisfy {
        URLComponents(url: $0.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "window" })?.value == "tail"
    })
    #expect(model.sessionHistory.openTarget == nil)
    #expect(model.sessionHistory.timelines[anchorPage.session.id]?.entries.last?.order == 26)
    await model.sessionHistory.restoreVisibleTimeline(anchorPage.session.id, active: false, anchor: oldAnchor)
    #expect(fixture.requests.contains {
        URLComponents(url: $0.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "window" })?.value == "anchor"
    })
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
}

@Test @MainActor func sessionContributionRecoveryRetainsRowsRetriesTransientReadAndWithdrawsOnDenial() async throws {
    let receipt = try historyObject("window-producer-receipt")
    var tailObject = try #require(receipt["tail_window"] as? [String: Any])
    tailObject["window_limit"] = 20
    let tail = try historyData(tailObject)
    let first = try historyData(try #require(receipt["first_page"]))
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: first)
    let profile = try historyData(try #require(historyObject()["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true},"contract_versions":{"session_conversation_history":1}}"#.utf8)
    let phase = PresenceReadPhase()
    let attempts = HTTPRecoveryActiveReadCounter()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("ask_dj/history") { return (200, profile, 0) }
        if phase.value == 1 { throw URLError(.cannotConnectToHost) }
        if phase.value == 2 { return (403, Data(#"{"success":false,"error":"invalid_profile"}"#.utf8), 0) }
        if phase.value == 3, attempts.next() == 1 { return (503, Data(), 0) }
        return (200, request.url!.query?.contains("window=tail") == true ? tail : first, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    let history = model.sessionHistory
    await history.prepare(); await history.loadTimeline(page.session.id)
    let confirmed = try #require(history.timelines[page.session.id]?.entries)
    #expect(!confirmed.isEmpty)
    phase.value = 1
    await history.loadTimeline(page.session.id, window: .tail)
    #expect(history.timelines[page.session.id]?.entries == confirmed)
    #expect(history.timelines[page.session.id]?.errorKey != nil)
    phase.value = 3
    #expect(await history.recoverContributions(page.session.id))
    #expect(history.timelines[page.session.id]?.errorKey == nil)
    #expect(history.timelines[page.session.id]?.entries.last?.order == 26)
    #expect(history.openTarget == nil)
    phase.value = 2
    #expect(!(await history.recoverContributions(page.session.id)))
    #expect(history.timelines.isEmpty)
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
}

@Test @MainActor func statusEndpointUpdatesBothRoutesPersistsAndRejectsStaleOrInvalidValues() throws {
    let fixture = HistoryWireFixture { _ in (200, Data(), 0) }; defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set("same-install", forKey: "DJConnectHAInstallID")
    func response(_ fields: [String: Any]) throws -> DJConnectEnvelope<DJConnectPlayback> {
        var object: [String: Any] = ["success": true, "ha_install_id": "same-install"]
        object.merge(fields) { _, new in new }
        return try JSONDecoder().decode(DJConnectEnvelope<DJConnectPlayback>.self, from: historyData(object))
    }
    let oldLocal = model.haLocalURL, oldRemote = model.haRemoteURL
    let updated = try response(["ha_local_url": "http://192.168.1.134:8123/", "ha_remote_url": "https://new-endpoint.example/", "remote_supported": true])
    #expect(model.applyStatusEndpoints(updated, expectedLocal: oldLocal, expectedRemote: oldRemote, expectedInstall: "same-install"))
    #expect(model.haLocalURL == "http://192.168.1.134:8123")
    #expect(model.haRemoteURL == "https://new-endpoint.example")
    #expect(model.homeAssistantURL == model.haLocalURL)
    #expect(defaults.string(forKey: "DJConnectHALocalURL") == model.haLocalURL)
    #expect(defaults.string(forKey: "DJConnectHARemoteURL") == model.haRemoteURL)
    model.recordConnectionMode(.local, baseURL: fixture.baseURL)
    #expect(model.haLocalURL == "http://192.168.1.134:8123", "Late old route reporter cannot restore the old endpoint")
    let local = model.haLocalURL, remote = model.haRemoteURL
    #expect(!model.applyStatusEndpoints(updated, expectedLocal: oldLocal, expectedRemote: oldRemote, expectedInstall: "same-install"))
    for fields in [[String: Any](), ["ha_local_url": "file:///tmp/test"], ["ha_remote_url": "http://external.example"],
        ["ha_remote_url": "https://user:password@example.com"], ["ha_local_url": "https://example.com/?token=secret"],
        ["ha_install_id": "another-install", "ha_remote_url": "https://wrong.example"]] {
        #expect(!model.applyStatusEndpoints(try response(fields), expectedLocal: local, expectedRemote: remote, expectedInstall: "same-install"))
        #expect(model.haLocalURL == local && model.haRemoteURL == remote)
    }
    #expect(model.applyStatusEndpoints(try response(["remote_supported": false]), expectedLocal: local, expectedRemote: remote, expectedInstall: "same-install"))
    #expect(model.haRemoteURL.isEmpty && !model.remoteSupported)
}

@Test @MainActor func connectionEndpointHeartbeatReadsStatusOnceAndPreservesPairing() async throws {
    let data = Data(#"{"success":true,"ha_install_id":"same-install","ha_local_url":"http://192.168.1.134:8123","ha_remote_url":"https://new-endpoint.example","remote_supported":true}"#.utf8)
    let fixture = HistoryWireFixture { request in
        #expect(request.url?.path.hasSuffix("/status") == true)
        #expect(request.httpMethod == "POST")
        return (200, data, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set("same-install", forKey: "DJConnectHAInstallID")
    try await model.refreshConnectionEndpointsIfNeeded(client: fixture.client())
    try await model.refreshConnectionEndpointsIfNeeded(client: fixture.client())
    #expect(fixture.requests.count == 1)
    #expect(model.haLocalURL == "http://192.168.1.134:8123")
    #expect(model.haRemoteURL == "https://new-endpoint.example")
    #expect(model.pairingStatus == .paired)
}

@Test @MainActor func earlierSessionManualSpeechCanRegenerateWithoutAnOldAudioGrant() async throws {
    let receipt = try historyObject()
    let timeline = try historyData(try #require(receipt["archived_timeline"]))
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: timeline)
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true},"contract_versions":{"session_conversation_history":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("ask_dj/history") { return (200, profile, 0) }
        return (200, timeline, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare(); await model.sessionHistory.loadTimeline(page.session.id)
    let entry = try #require(model.sessionHistory.timelines[page.session.id]?.entries.first { $0.kind == .djMoment && $0.text?.isEmpty == false })
    #expect(entry.sessionSpeech == nil)
    let observed = try #require(model.sessionHistory.timelines[page.session.id]?.entries.first { $0.kind == .playbackObserved })
    #expect(!model.retainedSpeechSourceIsCurrent(observed), "Playback observations are not immutable DJ speech sources")
    #expect(model.retainedSpeechSourceIsCurrent(entry), "No cached asset is necessary for an explicit prepare3 attempt")
    #expect(!fixture.requests.contains { $0.url!.path.contains("/speech/") }, "Opening history never synthesizes")
    model.sessionHistory.suspend()
    #expect(!model.retainedSpeechSourceIsCurrent(entry), "Old Profile/epoch data cannot be used after withdrawal")
}

@Test(arguments: [DJConnectHAConnectionMode.local, .remote])
func missingOptionalSpeechRouteKeepsReachableOriginAndNeverReplays(_ mode: DJConnectHAConnectionMode) async throws {
    let fixture = HistoryWireFixture { _ in (404, Data(#"{"success":false,"error":"not_found"}"#.utf8), 0) }
    defer { fixture.close() }
    let modes = PresenceModes()
    let manager = DJConnectHATransportManager(localURL: mode == .local ? fixture.baseURL : nil,
        remoteURL: mode == .remote ? fixture.baseURL : URL(string: "https://unused.test"), allowsRemoteFallback: true,
        clientFactory: { _ in fixture.client() }, modeReporter: { value, _ in modes.record(value) })
    do {
        _ = try await manager.perform(allowsOperationReplay: false) { try await $0.speechVoiceOptions() }
        Issue.record("Expected optional route refusal")
    } catch let error as DJConnectError {
        guard case .routeMissing = error else { Issue.record("Unexpected classification"); return }
    }
    #expect(modes.values == [mode])
    #expect(fixture.requests.count == 1)
}

@Test @MainActor func sessionOwnedTransportRecoveryDoesNotLeakGenericToastOrReplay() async throws {
    let fixture = HistoryWireFixture { _ in Issue.record("No HTTP request is expected"); return (500, Data(), 0) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { defaults.removePersistentDomain(forName: name) }
    do {
        let _: Bool = try await model.withHomeAssistantClient(allowsOperationReplay: false, notifiesTransportFailure: false) { _ in
            throw DJConnectHybridTransportError.deliveryUnknown
        }
        Issue.record("An uncertain operation must remain uncertain")
    } catch DJConnectHybridTransportError.deliveryUnknown { }
    #expect(model.userNotice == nil, "The owning screen reconciles state before deciding what the user should see")
    #expect(fixture.requests.isEmpty, "Never replay a potentially accepted operation")
}


@Test @MainActor func missingOrFailedOutputDoesNotDisableAllPlayback() async throws {
    for status in [404, 500, 200] {
        let wire = HistoryWireFixture { request in
            let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any]
            #expect(body?["command"] as? String == "set_output")
            #expect(body?["value"] as? String == "spotify-phone-stable-id")
            return (status, Data(#"{"success":false,"error":"backend_unavailable","backend_available":false,"message":"Spotify API failed: Device not found"}"#.utf8), 0.04)
        }
        defer { wire.close() }
        let (model, defaults, name) = wire.model(); defer { defaults.removePersistentDomain(forName: name) }
        model.apply(commandResponse: DJConnectCommandResponse(success: true, backendAvailable: true, devices: [
            .init(id: "healthy-speaker", name: "Living Room", active: true),
            .init(id: "spotify-phone-stable-id", name: "iPhone", cached: true, provider: "spotify")]))
        let phone = try #require(model.availableOutputs.first { $0.id == "spotify-phone-stable-id" })
        model.selectOutput(phone)
        // Repeating the same target tap cannot create a second transfer effect.
        model.selectOutput(phone)
        for _ in 0..<200 where model.pendingOutputSelectionID != nil { try await Task.sleep(for: .milliseconds(10)) }
        #expect(model.pendingOutputSelectionID == nil)
        #expect(model.backendAvailable && model.pairingStatus == .paired)
        #expect(model.selectedOutput == "Living Room")
        #expect(model.availableOutputs.filter { $0.active == true }.map(\.id) == ["healthy-speaker"])
        #expect(model.userNotice?.text == DJConnectLocalization.localized(key: "appModel.cached.spotify.output.unavailable", language: model.language))
        #expect(wire.requests.count == 1)
    }
}

@Test @MainActor func sameNameDifferentDeviceCannotConfirmOutputTransfer() async throws {
    let wire = HistoryWireFixture { request in
        let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any]
        if body?["command"] as? String == "set_output" {
            #expect(body?["value"] as? String == "new-iphone")
            return (200, Data(#"{"success":true}"#.utf8), 0)
        }
        return (200, Data(#"{"success":true,"devices":[{"id":"old-iphone","name":"iPhone","active":true},{"id":"new-iphone","name":"iPhone","active":false}]}"#.utf8), 0)
    }
    defer { wire.close() }
    let (model, defaults, name) = wire.model(); defer { defaults.removePersistentDomain(forName: name) }
    model.apply(commandResponse: DJConnectCommandResponse(success: true, devices: [.init(id: "old-iphone", name: "iPhone", active: true)]))
    model.selectOutput(.init(id: "new-iphone", name: "iPhone"))
    for _ in 0..<250 where model.pendingOutputSelectionID != nil { try await Task.sleep(for: .milliseconds(20)) }
    #expect(model.pendingOutputSelectionID == nil)
    #expect(model.availableOutputs.filter { $0.active == true }.map(\.id) == ["old-iphone"])
    #expect(model.userNotice?.text == DJConnectLocalization.localized(key: "ui.output.switch.unconfirmed", language: model.language))
    let commands = try wire.requests.compactMap { (try JSONSerialization.jsonObject(with: presenceRequestBody($0)) as? [String: Any])?["command"] as? String }
    #expect(commands.filter { $0 == "set_output" }.count == 1)
    #expect(commands.filter { $0 == "devices" }.count == 4)
}


@Test @MainActor func outputListDeduplicatesStableIDsAndDoesNotActivateSameNamePhone() async throws {
    let fixture = HistoryWireFixture { _ in (200, Data(#"{"success":true}"#.utf8), 0) }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    model.apply(playback: .init(device: .init(id: "phone-current", name: "iPhone")))
    model.apply(commandResponse: DJConnectCommandResponse(success: true, devices: [
        .init(id: "phone-stale", name: "iPhone", cached: true, provider: "spotify"),
        .init(id: "phone-current", name: "iPhone", cached: true, provider: "spotify"),
        .init(id: "phone-current", name: "iPhone", cached: false, provider: "spotify")]))
    #expect(model.availableOutputs.count == 2)
    #expect(model.availableOutputs.first { $0.id == "phone-current" }?.cached == false)
    #expect(model.availableOutputs.filter { $0.active == true }.map(\.id) == ["phone-current"])
    #expect(!DJConnectOutputDevice(id: "stale", name: "iPhone").matchesPlaybackDevice(id: "current", name: "iPhone"))
    #expect(DJConnectOutputDevice(name: "iPhone").matchesPlaybackDevice(id: nil, name: "iPhone"))
}


@Test @MainActor func externalPlaybackChangeUpdatesOutputRowsAndSameSnapshotWinsOverOldFlags() async throws {
    let wire = HistoryWireFixture { _ in (200, Data(#"{"success":true}"#.utf8), 0) }; defer { wire.close() }
    let (model, defaults, name) = wire.model(); defer { defaults.removePersistentDomain(forName: name) }
    let oldRows: [DJConnectOutputDevice] = [.init(id: "phone", name: "iPhone", active: true), .init(id: "mac", name: "MacBook", active: false)]
    model.apply(commandResponse: .init(success: true, devices: oldRows))
    model.apply(playback: .init(device: .init(id: "mac", name: "MacBook")))
    #expect(model.selectedOutput == "MacBook")
    #expect(model.availableOutputs.filter { $0.active == true }.map(\.id) == ["mac"])
    model.apply(commandResponse: .init(success: true, playback: .init(device: .init(id: "mac", name: "MacBook")), devices: oldRows))
    #expect(model.selectedOutput == "MacBook")
    #expect(model.availableOutputs.filter { $0.active == true }.map(\.id) == ["mac"])
}

@Test @MainActor func outputRefreshReadsActualPlaybackWithoutTransferOrGlobalRefresh() async throws {
    let wire = HistoryWireFixture { request in
        let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any]
        if body?["command"] as? String == "devices" {
            return (200, Data(#"{"success":true,"devices":[{"id":"phone","name":"iPhone","active":true},{"id":"mac","name":"MacBook","active":false}]}"#.utf8), 0.05)
        }
        if body?["command"] as? String == "status" {
            return (200, Data(#"{"success":true,"playback":{"device":{"id":"mac","name":"MacBook"}}}"#.utf8), 0)
        }
        return (200, Data(#"{"success":true}"#.utf8), 0)
    }; defer { wire.close() }
    let (model, defaults, name) = wire.model(); defer { defaults.removePersistentDomain(forName: name) }
    model.isRefreshing = true // An unrelated full refresh cannot swallow the button action.
    model.apply(playback: .init(device: .init(id: "phone", name: "iPhone")))
    let work = Task { await model.refreshOutputDevicesAndPlayback() }
    for _ in 0..<100 where !model.isLoadingOutputs { try await Task.sleep(for: .milliseconds(5)) }
    #expect(!(await model.refreshOutputDevicesAndPlayback())) // Coalesced duplicate refresh.
    #expect(await work.value)
    #expect(!model.isLoadingOutputs && model.isRefreshing)
    #expect(model.selectedOutput == "MacBook")
    #expect(model.availableOutputs.filter { $0.active == true }.map(\.id) == ["mac"])
    let commands = try wire.requests.compactMap { (try JSONSerialization.jsonObject(with: presenceRequestBody($0)) as? [String: Any])?["command"] as? String }
    #expect(commands == ["devices", "status"])
    #expect(!commands.contains("set_output"))
}

@Test @MainActor func delayedDeviceInventoryCannotUndoNewerPlaybackOutput() async throws {
    let wire = HistoryWireFixture { _ in
        (200, Data(#"{"success":true,"devices":[{"id":"phone","name":"iPhone","active":true},{"id":"mac","name":"MacBook","active":false}]}"#.utf8), 0.15)
    }; defer { wire.close() }
    let (model, defaults, name) = wire.model(); defer { defaults.removePersistentDomain(forName: name) }
    model.apply(playback: .init(device: .init(id: "phone", name: "iPhone")))
    model.loadOutputs()
    for _ in 0..<100 where wire.requests.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
    model.apply(playback: .init(device: .init(id: "mac", name: "MacBook")))
    for _ in 0..<100 where model.isLoadingOutputs { try await Task.sleep(for: .milliseconds(5)) }
    #expect(model.selectedOutput == "MacBook")
    #expect(model.availableOutputs.filter { $0.active == true }.map(\.id) == ["mac"])
}

@Test func historyRowPlaybackRequiresOneExplicitServerAction() {
    let item = DJConnectAskDJHistoryItem(kind: "track", title: "Thank U", uri: "spotify:track:example", playedAtLabel: "20:26")
    var message = DJConnectAskDJMessage(role: .dj, text: "Recently played", items: [item, item])
    #expect(message.playbackAction(forHistoryItem: item) == nil)
    let action = DJConnectAskDJPlaybackAction(id: "replay", title: item.title, uri: item.uri, kind: "track")
    message.playbackActions = [action]
    #expect(message.playbackAction(forHistoryItem: item) == action)
    #expect(message.items.count == 2)
    #expect(message.items.allSatisfy { $0.playedAtLabel == "20:26" })
    var different = item; different.uri = "spotify:track:other"
    #expect(message.playbackAction(forHistoryItem: different) == nil)
    different = item; different.kind = "technical_metric"
    #expect(message.playbackAction(forHistoryItem: different) == nil)
    message.playbackActions = [action, action]
    #expect(message.playbackAction(forHistoryItem: item) == nil)
    var invalid = action; invalid.resultSetID = "set-without-action"
    message.playbackActions = [invalid]
    #expect(message.playbackAction(forHistoryItem: item) == nil)
}

@Test(arguments: [false, true]) @MainActor
func profileConversationClearPreservesSendingAndRejectsOldHistory(_ remoteClear: Bool) async throws {
    let original = try #require(historyObject()["later_historical_answer"] as? [String: Any])
    let initial = try historyData(original)
    var cleared = original
    cleared["messages"] = []; cleared["historical_matches"] = []
    cleared["user_message"] = NSNull(); cleared["assistant_message"] = NSNull()
    cleared["history_revision"] = 4; cleared["clear_revision"] = 1; cleared["cleared"] = true
    let clearData = try historyData(cleared)
    var next = original; next["history_revision"] = 5; next["clear_revision"] = 1
    let nextData = try historyData(next)
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/clear") { return (200, clearData, 0) }
        if request.httpMethod == "POST" { return (200, nextData, 0) }
        return (200, initial, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    #expect(model.canUseProfileConversation)
    #expect(!model.askDJMessages.isEmpty)
    let oldEpoch = model.sessionHistory.responseEpoch
    if remoteClear {
        let response = try JSONDecoder().decode(DJConnectAskDJHistoryResponse.self, from: clearData)
        #expect(model.applyProfileConversationHistory(response))
    } else {
        model.clearAskDJHistory()
        for _ in 0..<100 where model.isClearingAskDJHistory { try await Task.sleep(for: .milliseconds(10)) }
        #expect(!model.isClearingAskDJHistory)
    }
    #expect(model.askDJMessages.isEmpty)
    #expect(model.sessionHistory.responseEpoch != oldEpoch)
    #expect(model.sessionHistory.hasAuthorizedOwner && model.canUseProfileConversation)
    #expect(!model.applyProfileConversationHistory(try JSONDecoder().decode(DJConnectAskDJHistoryResponse.self, from: initial)))
    #expect(model.askDJMessages.isEmpty)
    let response = try await model.sessionHistory.sendExistingText("New question after clear", clientMessageID: "after-clear")
    #expect(response.clearRevision == 1)
    #expect(fixture.requests.contains { request in
        request.httpMethod == "POST" && !(request.url!.path.hasSuffix("/clear"))
    })
    #expect(model.canUseProfileConversation)
}

@Test @MainActor func sessionCoverUsesConfirmedArtworkRouteInsteadOfPinnedLAN() throws {
    let remote = try #require(URL(string: "https://paired.example"))
    let fixture = HistoryWireFixture { _ in (500, Data(), 0) }; defer { fixture.close() }
    let (model, defaults, name) = fixture.model(remoteURL: remote)
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    let path = "/api/djconnect/v1/image_proxy/cover?size=600"
    let local = try #require(URL(string: path, relativeTo: fixture.baseURL)?.absoluteURL)
    model.recordConnectionMode(.remote, baseURL: remote)
    let resolved = try #require(model.resolvedArtworkURL(local))
    #expect(resolved.host == remote.host && resolved.scheme == "https")
    #expect(resolved.path == local.path && resolved.query == local.query)
    #expect(model.resolvedArtworkURL(URL(string: path)) == resolved)
    model.recordConnectionMode(.local, baseURL: fixture.baseURL)
    #expect(model.resolvedArtworkURL(resolved) == local)
    let provider = URL(string: "https://images.example/actual-album.jpg")
    #expect(model.resolvedArtworkURL(provider) == provider)
    #expect(model.resolvedArtworkURL(nil) == nil)
    for bad in ["file:///tmp/cover.jpg", "https://user:secret@paired.example/cover", "//unknown.example/cover"] {
        #expect(model.resolvedArtworkURL(URL(string: bad)) == nil)
    }
    #expect(fixture.requests.isEmpty)
}

@Test @MainActor func askDJArtworkRestorationUsesConfirmedRouteAndPreservesResponseIdentity() throws {
    let remote = try #require(URL(string: "https://paired.example"))
    let fixture = HistoryWireFixture { _ in (500, Data(), 0) }; defer { fixture.close() }
    let (model, defaults, name) = fixture.model(remoteURL: remote)
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    for prefix in ["/api/djconnect/v1/image_proxy/", "/api/djconnect/image_proxy/"] {
        let path = prefix + "album/cover?size=600"
        let local = try #require(URL(string: path, relativeTo: fixture.baseURL)?.absoluteURL)
        let relative = try #require(URL(string: path))
        let action = try JSONDecoder().decode(DJConnectAskDJPlaybackAction.self, from: historyData([
            "id":"replay", "title":"Your House", "kind":"track", "command":"play_uri",
            "uri":"spotify:track:fixture", "image_url":local.absoluteString,
            "result_set_id":"set-a", "action_id":"action-a"
        ]))
        let wire = DJConnectAskDJHistoryMessage(id: "answer", role: .assistant, text: "Your House",
            createdAt: Date(timeIntervalSince1970: 1000),
            images: [.init(url: relative, title: "Your House", thumbnailURL: local)],
            playbackActions: [action], items: [.init(title: "Your House", imageURL: local, thumbnailURL: relative)])
        model.recordConnectionMode(.local, baseURL: fixture.baseURL)
        #expect(model.sessionResponseMessage(wire).images.first?.url == local)
        model.recordConnectionMode(.remote, baseURL: remote)
        // Re-decoding represents a fresh history read after leaving/reopening the screen.
        let restored = try JSONDecoder().decode(DJConnectAskDJHistoryMessage.self, from: JSONEncoder().encode(wire))
        let projected = model.sessionResponseMessage(restored)
        let expected = try #require(URL(string: path, relativeTo: remote)?.absoluteURL)
        #expect(projected.images.first?.url == expected)
        #expect(projected.images.first?.thumbnailURL == expected)
        #expect(projected.items.first?.imageURL == expected)
        #expect(projected.items.first?.thumbnailURL == expected)
        #expect(projected.playbackActions.first?.imageURL == expected)
        var expectedAction = action; expectedAction.imageURL = expected
        #expect(projected.playbackActions == [expectedAction], "Artwork routing must preserve action authority and identity")
        #expect(projected.serverID == wire.id && projected.text == wire.text)
    }
    let rejected = DJConnectAskDJHistoryMessage(id: "unsafe", role: .assistant, text: "No untrusted art", createdAt: Date(),
        images: [.init(url: URL(string: "file:///tmp/cover")!), .init(url: URL(string: "https://unpaired.example/cover")!)])
    #expect(model.sessionResponseMessage(rejected).images.isEmpty)
    #expect(fixture.requests.isEmpty)
}

@Test(arguments: ["nl", "en", "de", "fr", "es"])
func sessionStartMetadataUsesServerStartLocalTimeAndTranslatedFullDate(language: String) throws {
    let zone = try #require(TimeZone(identifier: "Europe/Amsterdam"))
    let text = try #require(SessionStartMetadata.text(startedAt: "2026-10-10T15:30:00Z", language: language, timeZone: zone))
    #expect(text.contains("17:30") && text.contains("2026"))
    #expect(!text.contains("ui.session.") && !text.contains("%@"))
    if language == "nl" { #expect(text == "DJ-sessie gestart om 17:30 op 10 oktober 2026") }
    #expect(SessionStartMetadata.text(startedAt: "", language: language, timeZone: zone) == nil)
    #expect(SessionStartMetadata.text(startedAt: "unknown", language: language, timeZone: zone) == nil)
    let winter = try #require(SessionStartMetadata.text(startedAt: "2026-12-10T16:30:00Z", language: language, timeZone: zone))
    #expect(winter.contains("17:30"))
}

@Test @MainActor func albumBorderTintIsImmediatelyReusableAcrossScreensWithoutExtendingLifetime() throws {
    let cache = DJConnectArtworkTintCache()
    let now = Date(timeIntervalSince1970: 1000)
    let cover = try #require(URL(string: "https://paired.example/api/djconnect/v1/image_proxy/cover-a"))
    let nextCover = try #require(URL(string: "https://paired.example/api/djconnect/v1/image_proxy/cover-b"))
    let tint = DJConnectArtworkTintSnapshot(color: .purple, expiresAt: now.addingTimeInterval(10))
    cache.store(tint, for: cover, at: now)
    // Separate synchronous reads model initial state on two independently mounted screens.
    let session = try #require(cache.value(for: cover, at: now.addingTimeInterval(1)))
    let player = try #require(cache.value(for: cover, at: now.addingTimeInterval(2)))
    #expect(session.color == player.color && session.expiresAt == player.expiresAt)
    #expect(player.expiresAt == tint.expiresAt)
    #expect(cache.value(for: nextCover, at: now) == nil, "A previous cover must not tint the next track")
    #expect(cache.value(for: cover, at: tint.expiresAt) == nil)
    cache.store(tint, for: cover, at: tint.expiresAt)
    #expect(cache.value(for: cover, at: tint.expiresAt) == nil, "Remounting cannot renew expired tint")
}

@Test(arguments: ["no-store", "no-cache", "public, max-age=0"])
func protectedArtworkCannotPopulateTheSharedBorderTint(cacheControl: String) async throws {
    let fixture = HistoryWireFixture(cacheControl: cacheControl) { _ in (200, Data([1, 2, 3]), 0) }
    defer { fixture.close() }
    let cache = DJConnectArtworkDataCache(session: fixture.session())
    let url = fixture.baseURL.appendingPathComponent("artwork")
    _ = await cache.tint(for: url, fallback: .purple)
    #expect(await cache.cachedTint(for: url) == nil, "The synchronous border cache may only inherit retained HTTP lifetime")
    #expect(fixture.requests.count == 1)
}

@Test @MainActor func albumBorderTintWarmDownloadIsImmediatelyAvailableOnBothScreens() async throws {
    let png = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII="))
    let fixture = HistoryWireFixture(cacheControl: "public, max-age=60") { _ in (200, png, 0) }
    defer { fixture.close() }
    let imageCache = DJConnectArtworkDataCache(session: fixture.session())
    let presentation = DJConnectArtworkTintCache()
    let url = fixture.baseURL.appendingPathComponent("album")
    let color = await imageCache.tint(for: url, fallback: .purple)
    let sample = try #require(await imageCache.cachedTint(for: url))
    presentation.store(sample, for: url)
    #expect(try #require(presentation.value(for: url)).color == color)
    #expect(try #require(presentation.value(for: url)).color == color)
    #expect(sample.expiresAt.timeIntervalSinceNow <= 60)
    #expect(presentation.value(for: url, at: sample.expiresAt) == nil)
    #expect(await imageCache.cachedTint(for: url, at: sample.expiresAt) == nil)
    #expect(fixture.requests.count == 1, "Opening another screen must not refetch or resample the cover")
}

@Test @MainActor func submittedQuestionScrollTracksPendingRetainedAndCurrentOnlyIdentity() throws {
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self,
        from: historyData(try #require(historyObject()["archived_timeline"])))
    let entry = try #require(page.entries.first(where: { $0.kind == .conversationUser }))
    let client = try #require(entry.clientMessageID)
    let now = try #require(DJConnectHistoryEntry.date(entry.occurredAt)).addingTimeInterval(1)
    let localID = UUID()
    let question = SessionSubmittedQuestion(sessionID: entry.sessionID, localID: localID, clientID: client)
    let identity = DJConnectIdentity(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Test", clientType: .ios, firmware: "4.0.0", platform: .ios)
    let pending = DJConnectSessionHistoryModel.PendingTurn(id: client, text: entry.text ?? "", context: .init(sessionID: entry.sessionID),
        localMessageID: localID, payload: DJConnectAskDJRequest(identity: identity, text: entry.text ?? "", clientMessageID: client),
        requestEpoch: UUID(), ownerScope: "profile-a")
    #expect(question.target(sessionID: entry.sessionID, pending: [pending], entries: [], current: [], at: now) == "pending-" + client)
    #expect(question.target(sessionID: entry.sessionID, pending: [pending], entries: page.entries, current: [], at: now) == entry.id)
    #expect(question.target(sessionID: entry.sessionID, pending: [], entries: page.entries, current: [], at: now) == entry.id)
    let ephemeral = DJConnectAskDJMessage(id: localID, clientMessageID: client, role: .user, text: entry.text ?? "")
    #expect(question.target(sessionID: entry.sessionID, pending: [], entries: [], current: [ephemeral], at: now) == "current-conversation-" + localID.uuidString)
    #expect(question.target(sessionID: "another-session", pending: [pending], entries: page.entries, current: [ephemeral], at: now) == nil)
    var invalid = entry; invalid.context = nil
    #expect(question.target(sessionID: entry.sessionID, pending: [], entries: [invalid], current: [], at: now) == nil)
    let unrelated = DJConnectAskDJMessage(role: .user, text: entry.text ?? "")
    let assistant = DJConnectAskDJMessage(id: localID, clientMessageID: client, role: .dj, text: "An answer")
    #expect(question.target(sessionID: entry.sessionID, pending: [], entries: [], current: [unrelated, assistant], at: now) == nil)
    let expired = try #require(DJConnectHistoryEntry.date(entry.retainedUntil))
    #expect(question.target(sessionID: entry.sessionID, pending: [], entries: page.entries, current: [], at: expired) == nil)
}

@Test func playbackFieldHighlightsPreserveUnicodeOffsetsAndIgnoreOtherFields() {
    let source = "🎧 Titel · Artiest · Album"
    let title = "🎧 Titel"
    let artist = "Artiest"
    let titleRange = (source as NSString).range(of: title)
    let artistRange = (source as NSString).range(of: artist)
    let highlights = [DJConnectHistoryHighlight(startUTF16: titleRange.location, lengthUTF16: titleRange.length),
                      DJConnectHistoryHighlight(startUTF16: artistRange.location, lengthUTF16: artistRange.length)]
    let projectedTitle = SessionPlaybackHighlights.project(highlights, source: source, field: title)
    #expect(projectedTitle == [.init(startUTF16: 0, lengthUTF16: title.utf16.count)])
    #expect(SessionPlaybackHighlights.project(highlights, source: source, field: artist) == [.init(startUTF16: 0, lengthUTF16: artist.utf16.count)])
    #expect(SessionPlaybackHighlights.project(highlights, source: source, field: "Album").isEmpty)
    #expect(SessionPlaybackHighlights.project(highlights, source: source, field: "Absent").isEmpty)
    #expect(SessionPlaybackHighlights.project(highlights, source: source, field: "").isEmpty)
}

@Test(arguments: ["public, max-age=60", "no-store", "no-cache", "public, max-age=0"])
@MainActor func decodedArtworkReusesPixelsOnlyWithinHTTPLifetime(cacheControl: String) async throws {
    let context = try #require(CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
    let pixels = try #require(context.makeImage()); let bytes = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(bytes, "public.png" as CFString, 1, nil))
    CGImageDestinationAddImage(destination, pixels, nil); #expect(CGImageDestinationFinalize(destination))
    let png = bytes as Data
    let fixture = HistoryWireFixture(cacheControl: cacheControl) { _ in (200, png, 0) }
    defer { fixture.close() }
    let source = DJConnectArtworkDataCache(session: fixture.session())
    let decoded = DJConnectDecodedArtworkCache()
    let url = fixture.baseURL.appendingPathComponent("cacheable-cover")
    let first = try await loadDecodedArtwork(for: url, using: source, decoded: decoded)
    let again = try await loadDecodedArtwork(for: url, using: source, decoded: decoded)
    let cacheable = cacheControl == "public, max-age=60"
    #expect((first === again) == cacheable)
    #expect(fixture.requests.count == (cacheable ? 1 : 2))
    #expect(decoded.value(for: url, expiresAt: first.expiresAt, at: first.expiresAt) == nil)
    #expect(first.byteCost >= 8 * 8 * 4)
}

@Test func historyTimestampParserPreservesFractionalWholeOffsetAndConcurrentResults() async {
    let samples = ["2026-10-18T00:00:00Z", "2026-10-18T00:00:00.123Z", "2026-10-18T02:00:00+02:00", "", "not-a-date"]
    let expected = samples.map { text in
        let parser = ISO8601DateFormatter(); parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return parser.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
    await withTaskGroup(of: Bool.self) { group in
        for _ in 0..<100 {
            group.addTask { samples.enumerated().allSatisfy { DJConnectHistoryEntry.date($0.element) == expected[$0.offset] } }
        }
        for await matches in group { #expect(matches) }
    }
}

@Test @MainActor func longHistoryArtworkWindowMatchesRetentionFilteredReference() throws {
    let demo = try DJConnectDemoSessionData.make(language: "nl")
    let original = try #require(demo.timelines[demo.active.id]?.entries.first(where: { [.playbackObserved, .djMoment].contains($0.kind) }))
    let prototype = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
    let now = Date(); let formatter = ISO8601DateFormatter()
    let rows = try (0..<1000).map { index in
        var value = prototype; value["entry_id"] = "row-\(index)"; value["order"] = index + 1
        value["retained_until"] = formatter.string(from: now.addingTimeInterval(index % 3 == 0 ? -60 : 600))
        return try JSONDecoder().decode(DJConnectHistoryEntry.self, from: JSONSerialization.data(withJSONObject: value))
    }
    let visible = Set(rows[495..<505].map(\.id))
    let retained = rows.filter { $0.isRetained(at: now) }
    let positions = retained.indices.filter { visible.contains(retained[$0].id) }
    var expected = positions
    if let first = positions.first, first > 0 { expected.append(first - 1) }
    if let last = positions.last, last + 1 < retained.count { expected.append(last + 1) }
    #expect(DJConnectSessionHistoryModel.artworkWindow(entries: rows, visibleIDs: visible, at: now) == expected.map { retained[$0].reference })
    #expect(DJConnectSessionHistoryModel.artworkWindow(entries: rows, visibleIDs: visible, at: now.addingTimeInterval(1000)).isEmpty)
}

@Test @MainActor func timelineRefreshKeepsFailureVisibleUntilReadActuallySucceeds() async throws {
    let first = try historyData(try #require(historyObject("window-producer-receipt")["first_page"]))
    let page = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: first)
    let profile = try historyData(try #require(historyObject()["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true},"contract_versions":{"session_conversation_history":1}}"#.utf8)
    let phase = PresenceReadPhase()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("ask_dj/history") { return (200, profile, 0) }
        if phase.value == 1 || phase.value == 2 {
            return (404, Data(#"{"success":false,"error":"session_not_found"}"#.utf8), phase.value == 2 ? 0.15 : 0)
        }
        return (200, first, phase.value == 3 ? 0.15 : 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    let history = model.sessionHistory
    await history.prepare(); #expect(await history.loadTimeline(page.session.id))
    let confirmed = try #require(history.timelines[page.session.id]?.entries)
    phase.value = 1
    #expect(await history.loadTimeline(page.session.id) == false)
    let error = try #require(history.timelines[page.session.id]?.errorKey)
    for mode in [2, 3] {
        phase.value = mode
        let retry = Task { await history.loadTimeline(page.session.id) }
        for _ in 0..<100 where history.timelines[page.session.id]?.loading != true { await Task.yield() }
        #expect(history.timelines[page.session.id]?.loading == true)
        #expect(history.timelines[page.session.id]?.errorKey == error, "Starting a background read cannot remove the error block and shift the feed")
        #expect(history.timelines[page.session.id]?.entries == confirmed)
        #expect(await retry.value == (mode == 3))
    }
    #expect(history.timelines[page.session.id]?.errorKey == nil)
    #expect(history.timelines[page.session.id]?.entries == confirmed)
    #expect(history.hasAuthorizedOwner)
}

@Test @MainActor func firstPlayHelperUsesSessionMusicHistoryAndStaysDismissedAfterPlaybackClears() throws {
    let name = "first-play-helper-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    model.startDemoMode()
    var session = try #require(model.activeDJSession)
    let playing = try #require(session.broadcast.playback)
    session.broadcast.playback = nil
    // Existing observed music still hides the helper when the current snapshot disappears.
    #expect(model.sessionHistory.hasPlaybackForFirstPlayHelper(session))
    session.sessionID = "new-empty-session"
    // Opening moments by themselves are not music: a fresh Session still needs the helper.
    #expect(!session.broadcast.djMoments.isEmpty)
    #expect(!model.sessionHistory.hasPlaybackForFirstPlayHelper(session))
    session.broadcast.playback = playing
    #expect(model.sessionHistory.hasPlaybackForFirstPlayHelper(session))
    session.broadcast.playback?.state = "paused"
    #expect(model.sessionHistory.hasPlaybackForFirstPlayHelper(session))
    model.sessionHistory.rememberObservedPlayback(sessionID: session.id)
    session.broadcast.playback = nil
    #expect(model.sessionHistory.hasPlaybackForFirstPlayHelper(session))
    session.sessionID = "another-new-session"
    #expect(!model.sessionHistory.hasPlaybackForFirstPlayHelper(session))
    session.sessionID = "new-empty-session"
    model.sessionHistory.reset()
    #expect(!model.sessionHistory.hasPlaybackForFirstPlayHelper(session))
}

@Test(arguments: [0, 1, 2]) func sessionArchiveDeletionCapabilityRequiresExactVersion(_ version: Int) throws {
    let data = try historyData(["capabilities": ["session_conversation_history": true, "session_history_delete": true],
                                "contract_versions": ["session_conversation_history": 1, "session_history_delete": version]])
    let capabilities = try JSONDecoder().decode(DJConnectSessionHistoryCapabilities.self, from: data)
    #expect(capabilities.deletionAvailable == (version == 1))
}

@Test(arguments: ["ok", "owner", "target", "operation", "schema", "deleted", "success"])
func sessionArchiveDeletionAcknowledgementBindsOwnerOperationAndTarget(_ mutation: String) throws {
    let action = DJConnectSessionDeleteRequest(sessionID: "archive-a", expectedRevision: "opaque-r1")
    var object: [String: Any] = ["success": true, "schema_version": 1, "operation_id": action.operationID,
                               "owner_profile_id": "profile-a", "deleted_session_id": action.sessionID, "deleted": true]
    switch mutation {
    case "owner": object["owner_profile_id"] = "profile-b"
    case "target": object["deleted_session_id"] = "archive-b"
    case "operation": object["operation_id"] = UUID().uuidString
    case "schema": object["schema_version"] = 2
    case "deleted": object["deleted"] = false
    case "success": object["success"] = false
    default: break
    }
    let receipt = try JSONDecoder().decode(DJConnectSessionDeleteResponse.self, from: historyData(object))
    #expect(receipt.admits(action, owner: "profile-a") == (mutation == "ok"))
}

@Test(arguments: ["completed", "pending", "wrong_receipt", "conflict", "withdrawn",
                  "status_completed", "status_pending", "status_unknown", "status_expired_unknown"])
@MainActor func contentDeletionUsesFlatBoundWireAndNeverRenewsUnknown(_ outcome: String) async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let wire = try #require(JSONSerialization.jsonObject(with: Data(contentsOf:
        root.appendingPathComponent("Fixtures/content-deletion-core-58561f97.json"))) as? [String: Any])
    let examples = try #require(wire["examples"] as? [String: Any])
    var preview = try #require(examples["prepare_response"] as? [String: Any])
    // Only confirmation clocks are rebased for this explicitly synthetic current-time client.
    preview["created_at"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1))
    preview["expires_at"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(240))
    let previewData = try historyData(preview)
    let scope = try JSONDecoder().decode(DJConnectContentDeleteScope.self, from: previewData)
    let receiptTemplateData = try historyData(try #require(examples["delete_response"]))
    let statusTemplateData = try historyData(try #require(examples["completed_status_response"]))
    let pending = try historyData(try #require(examples["pending_response"]))
    let producer = try historyObject()
    let profile = try historyData(try #require(producer["later_historical_answer"]))
    let caps = try historyData(["capabilities": ["session_conversation_history": true,
        "session_content_delete": true, "session_history_delete": true, "session_history_bulk_delete": true],
        "contract_versions": ["session_conversation_history": 1, "session_content_delete": 1,
                              "session_history_delete": 1, "session_history_bulk_delete": 1]])
    let oldTimeline = try #require(producer["archived_timeline"] as? [String: Any])
    let oldHeader = try #require(oldTimeline["session"] as? [String: Any])
    let oldID = try #require(oldHeader["session_id"] as? String)
    // Independent retained rows are supplied by the existing history regression.
    // Rebind only its Session ID to the new fixture's opaque Session for readback.
    func rebound(_ value: Any) -> Any {
        if let s = value as? String { return s == oldID ? scope.unit.session_id : s }
        if let d = value as? [String: Any] { return d.mapValues(rebound) }
        if let a = value as? [Any] { return a.map(rebound) }
        return value
    }
    let detail = try historyData(rebound(oldTimeline))
    let independent = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: detail)
    let list = try historyData(["success": true, "schema_version": 1,
        "sessions": [rebound(oldHeader)], "revision": "content-readback", "retention_days": 30])
    let fixture = HistoryWireFixture { request in
        let path = request.url!.path
        if path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if path.hasSuffix("/ask_dj/history") { return (200, profile, 0) }
        if path.hasSuffix("/session/history") { return (200, list, 0) }
        if path.hasSuffix("/session/content/delete/prepare") { return (200, previewData, 0) }
        if path.hasSuffix("/session/content/delete/status") {
            var status = try #require(JSONSerialization.jsonObject(with: statusTemplateData) as? [String: Any])
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            let id = try #require(query.first { $0.name == "operation_id" }?.value)
            status["operation_id"] = id
            let state = outcome.replacingOccurrences(of: "status_", with: "")
            status["state"] = state; status["definitive"] = state == "completed"
            if state == "completed" {
                var receipt = try #require(status["receipt"] as? [String: Any])
                receipt["operation_id"] = id; status["receipt"] = receipt
            } else { status.removeValue(forKey: "receipt") }
            return (200, try historyData(status), 0)
        }
        if path.hasSuffix("/session/content/delete") {
            if outcome == "pending" || outcome.hasPrefix("status_") { return (503, pending, 0) }
            if outcome == "conflict" { return (409, Data(), 0) }
            var receipt = try #require(JSONSerialization.jsonObject(with: receiptTemplateData) as? [String: Any])
            let body = try #require(JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any])
            receipt["operation_id"] = body["operation_id"]
            if outcome == "wrong_receipt" { receipt["request_digest"] = "wrong" }
            return (200, try historyData(receipt), outcome == "withdrawn" ? 0.1 : 0)
        }
        return (200, detail, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    let history = model.sessionHistory
    await history.prepare()
    #expect(await history.loadSessions())
    #expect(await history.loadTimeline(scope.unit.session_id))
    let epoch = history.responseEpoch
    let archiveEpoch = history.archiveResponseEpoch
    let navigation = DJConnectSessionEntryReference(sessionID: scope.unit.session_id, entryID: independent.entries[0].id)
    history.openTarget = navigation
    let prepared = try #require(await history.prepareContentDeletion(scope.target, expectedEpoch: epoch))
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/session/content/delete") }.isEmpty)
    if outcome == "withdrawn" {
        let task = Task { @MainActor in await history.deleteContent(prepared, expectedEpoch: epoch) }
        for _ in 0..<100 where !fixture.requests.contains(where: { $0.url!.path.hasSuffix("/session/content/delete") }) {
            try await Task.sleep(for: .milliseconds(2))
        }
        #expect(!model.canUseProfileConversation)
        model.askDJDraft = "Keep this unrelated unsent question"
        history.sendText()
        #expect(model.askDJDraft == "Keep this unrelated unsent question")
        #expect(!fixture.requests.contains { $0.url!.path.hasSuffix("/ask_dj/message") })
        history.suspend()
        #expect(history.archiveResponseEpoch != archiveEpoch && history.openTarget == nil)
        #expect(await task.value == false)
        await history.prepare()
    } else {
        #expect(await history.deleteContent(prepared, expectedEpoch: epoch) == (outcome == "completed"))
    }
    let mutations = fixture.requests.filter { $0.url!.path.hasSuffix("/session/content/delete") }
    #expect(mutations.count == 1)
    let mutation = try #require(mutations.first)
    let body = try #require(JSONSerialization.jsonObject(with: presenceRequestBody(mutation)) as? [String: Any])
    #expect(Set(body.keys) == ["device_id", "client_type", "contract_version", "confirmation_id", "operation_id", "confirmed"])
    let preparation = try #require(fixture.requests.first { $0.url!.path.hasSuffix("/session/content/delete/prepare") })
    let prepareBody = try #require(JSONSerialization.jsonObject(with: presenceRequestBody(preparation)) as? [String: Any])
    #expect(Set(prepareBody.keys) == ["device_id", "client_type", "contract_version", "target"])
    #expect(mutations.first?.value(forHTTPHeaderField: "Cache-Control") == "no-store")
    #expect(mutations.first?.value(forHTTPHeaderField: "Referrer-Policy") == "no-referrer")
    let unknown = ["pending", "wrong_receipt", "withdrawn"].contains(outcome) || outcome.hasPrefix("status_")
    #expect(history.hasUnconfirmedDeletion == unknown)
    #if os(macOS)
    if outcome == "pending", let directory = ProcessInfo.processInfo.environment["DJCONNECT_CONTENT_DELETE_NATIVE_DIR"] {
        let folder = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        _ = NSApplication.shared
        let entry = try #require(independent.entries.first)
        let host = NSHostingView(rootView: VStack(alignment: .leading, spacing: 16) {
            ContentDeletionPendingNotice(model: model)
            SessionEntryView(entry: entry, language: model.language, artworkModel: model)
        }.padding(20).foregroundStyle(.white).background(Color.black).preferredColorScheme(.dark))
        let window = NSWindow(contentRect: .init(x: -3000, y: -3000, width: 430, height: 700),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host; window.orderBack(nil)
        defer { window.close() }
        for width: CGFloat in [430, 320] {
            window.setContentSize(.init(width: width, height: 700))
            try await Task.sleep(for: .milliseconds(200))
            host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try #require(bitmap.representation(using: .png, properties: [:]))
                .write(to: folder.appendingPathComponent("pending-\(Int(width)).png"))
        }
        // Public AppKit bridge only; absence is a host limit, never a fake click.
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let title = DJConnectLocalization.localized(key: "ui.content.delete.status", language: model.language)
        let buttons = descendants(host).compactMap { $0 as? NSButton }.filter { $0.title == title }
        let before = fixture.requests.count
        if buttons.count == 1 {
            buttons[0].performClick(nil)
            for _ in 0..<100 where fixture.requests.count == before { try await Task.sleep(for: .milliseconds(5)) }
            #expect(fixture.requests.dropFirst(before).contains { $0.httpMethod == "GET" && $0.url!.path.hasSuffix("/session/content/delete/status") })
        }
        try JSONSerialization.data(withJSONObject: ["native_status_button_bridges": buttons.count,
            "request_count_before": before, "request_count_after": fixture.requests.count,
            "pending_retained": history.hasUnconfirmedDeletion], options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("native-observations.json"))
    }
    #endif
    if unknown {
        let stored = try #require(model.contentDeletionJournalData)
        let journal = try JSONDecoder().decode([String: DJConnectSessionHistoryModel.PendingContentDeletion].self, from: stored)
        let saved = try #require(journal.values.first)
        #expect(saved.request.operation_id == body["operation_id"] as? String)
        #expect(!String(decoding: stored, as: UTF8.self).contains("synthetic-fixture-token"))
        #expect(!history.canPrepareBulkDeletion)
        #expect(await history.prepareContentDeletion(scope.target, expectedEpoch: history.responseEpoch) == nil)
        let reopened = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-fixture-token"),
            urlSession: fixture.session(), startBackgroundTasks: false)
        await reopened.sessionHistory.prepare()
        #expect(reopened.sessionHistory.hasUnconfirmedDeletion)
        #expect(!reopened.sessionHistory.canDeleteContent(scope.target))
        if outcome == "pending" {
            defaults.set("changed-after-unknown", forKey: "DJConnectHAInstallID")
            #expect(reopened.sessionHistory.hasUnconfirmedDeletion)
            #expect(!reopened.sessionHistory.canCheckContentDeletionStatus)
            let count = fixture.requests.count
            #expect(await reopened.sessionHistory.checkContentDeletionStatus() == false)
            #expect(fixture.requests.count == count)
        }
        if outcome.hasPrefix("status_") {
            #expect(await reopened.sessionHistory.checkContentDeletionStatus() == (outcome == "status_completed"))
            #expect(reopened.sessionHistory.hasUnconfirmedDeletion == (outcome != "status_completed"))
            let statusRead = try #require(fixture.requests.first { $0.url!.path.hasSuffix("/session/content/delete/status") })
            #expect(statusRead.httpMethod == "GET")
            let query = try #require(URLComponents(url: statusRead.url!, resolvingAgainstBaseURL: false)?.queryItems)
            #expect(Set(query.map(\.name)) == ["device_id", "client_type", "contract_version", "operation_id", "confirmation_id"])
            #expect(query.first { $0.name == "operation_id" }?.value == saved.request.operation_id)
            #expect(query.first { $0.name == "confirmation_id" }?.value == saved.request.confirmation_id)
        }
        #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/session/content/delete") }.count == 1)
    } else if outcome == "completed" {
        #expect(history.responseEpoch != epoch)
        #expect(history.archiveResponseEpoch == archiveEpoch)
        #expect(history.openTarget == navigation)
        #expect(history.sessions.map(\.id) == [scope.unit.session_id])
        #expect(history.timelines[scope.unit.session_id]?.entries == independent.entries)
    }
}

@Test(arguments: ["malformed", "oversized", "content-malformed", "content-oversized"])
@MainActor func invalidDeletionJournalCannotEnableAnotherMutation(_ mode: String) async throws {
    let producer = try historyObject()
    let archiveData = try historyData(try #require(producer["archived_timeline"]))
    let archive = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: archiveData).session
    let profile = try historyData(try #require(producer["later_historical_answer"]))
    let caps = try historyData(["capabilities": ["session_conversation_history": true,
        "session_history_delete": true, "session_history_bulk_delete": true],
        "contract_versions": ["session_conversation_history": 1,"session_history_delete": 1,"session_history_bulk_delete": 1]])
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/ask_dj/history") { return (200, profile, 0) }
        return (200, archiveData, 0)
    }
    defer { fixture.close() }
    let (original, defaults, name) = fixture.model()
    defer { defaults.removePersistentDomain(forName: name) }
    let invalidData = mode.hasSuffix("malformed") ? Data("bad-json".utf8) : Data(repeating: 0, count: 262_145)
    if mode.hasPrefix("content-") { original.storeContentDeletionJournal(invalidData) }
    else { original.storeHistoryDeletionJournal(invalidData) }
    let reopened = DJConnectAppModel(defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-fixture-token"),
        urlSession: fixture.session(), startBackgroundTasks: false)
    let history = reopened.sessionHistory
    await history.prepare(); #expect(await history.loadTimeline(archive.id))
    #expect(history.hasUnconfirmedDeletion)
    #expect(!history.canPrepareBulkDeletion && !history.canDeleteSession(archive.id))
    #expect(await history.deleteSession(archive.id, expectedRevision: archive.revision.value, expectedEpoch: history.responseEpoch) == false)
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
}

#if os(macOS)
@Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_PENDING_ARCHIVE_NATIVE_DIR"] != nil))
@MainActor func nativeArchiveRetainsUnconfirmedDeletionNoticeAcrossReadRefresh() async throws {
    let directory = try #require(ProcessInfo.processInfo.environment["DJCONNECT_PENDING_ARCHIVE_NATIVE_DIR"])
    let folder = URL(fileURLWithPath: directory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let producer = try historyObject()
    let timeline = try #require(producer["archived_timeline"] as? [String: Any])
    let detail = try historyData(timeline)
    let archive = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: detail).session
    let list = try historyData(["success": true, "schema_version": 1,
        "sessions": [try #require(timeline["session"])],
        "revision": try #require(timeline["revision"]), "retention_days": 30])
    let profile = try historyData(try #require(producer["later_historical_answer"]))
    let caps = try historyData(["capabilities": ["session_conversation_history": true,
        "session_history_delete": true, "session_history_bulk_delete": true],
        "contract_versions": ["session_conversation_history": 1, "session_history_delete": 1,
                              "session_history_bulk_delete": 1]])
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/archive-deletion-core-bbb7a23d.json")
    let wire = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: source)) as? [String: Any])
    let examples = try #require(wire["examples"] as? [String: Any])
    let pending = try historyData(try #require(examples["pending_response"]))
    let fixture = HistoryWireFixture { request in
        let path = request.url!.path
        if path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if path.hasSuffix("/ask_dj/history") { return (200, profile, 0) }
        if path.hasSuffix("/session/history/delete") { return (503, pending, 0) }
        if path.hasSuffix("/session/history") { return (200, list, 0) }
        return (200, detail, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    model.language = "nl"
    let history = model.sessionHistory
    await history.restoreVisibleSessions()
    #expect(await history.loadTimeline(archive.id))
    #expect(history.sessions.map(\.id) == [archive.id])
    #expect(history.canDeleteSession(archive.id))
    _ = NSApplication.shared
    let host = NSHostingView(rootView: SavedSessionsView(model: model, embedsNavigationStack: false)
        .environment(\.scenePhase, .background).preferredColorScheme(.dark))
    let window = NSWindow(contentRect: .init(x: -3000, y: -3000, width: 430, height: 640),
        styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.isReleasedWhenClosed = false; window.contentView = host; window.orderBack(nil)
    defer { window.close() }
    var observations: [[String: Any]] = []
    func capture(_ label: String, width: CGFloat) async throws {
        window.setContentSize(.init(width: width, height: 640))
        try await Task.sleep(for: .milliseconds(250))
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try #require(bitmap.representation(using: .png, properties: [:]))
            .write(to: folder.appendingPathComponent(label + ".png"))
        observations.append(["name": label, "width": width, "height": 640,
            "unconfirmed": history.hasUnconfirmedDeletion, "owner": history.authorizedProfileID ?? "none",
            "session_ids": history.sessions.map(\.id), "preparing": history.preparing,
            "list_loading": history.listLoading,
            "posts": fixture.requests.filter { $0.httpMethod == "POST" }.count])
    }
    try await capture("authorized-before", width: 430)
    #expect(!history.hasUnconfirmedDeletion)
    #expect(await history.deleteSession(archive.id, expectedRevision: archive.revision.value,
                                        expectedEpoch: history.responseEpoch) == false)
    #expect(history.hasUnconfirmedDeletion)
    let journal = try #require(model.historyDeletionJournalData)
    try await capture("pending-430", width: 430)
    await history.restoreVisibleSessions() // Ordinary read refresh, not operation reconciliation.
    #expect(history.hasUnconfirmedDeletion && !history.canDeleteSession(archive.id))
    #expect(!history.canPrepareBulkDeletion)
    #expect(history.sessions.map(\.id) == [archive.id])
    #expect(model.historyDeletionJournalData == journal)
    try await capture("pending-after-refresh-430", width: 430)
    try await capture("pending-after-refresh-320", width: 320)
    #expect(fixture.requests.filter { $0.httpMethod == "POST" }.count == 1)
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" ||
        ($0.httpMethod == "POST" && $0.url!.path.hasSuffix("/session/history/delete")) })
    try JSONSerialization.data(withJSONObject: ["observations": observations,
        "requests": fixture.requests.map { ["method": $0.httpMethod ?? "", "path": $0.url!.path] }],
        options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("observations.json"))
}
#endif

@Test(arguments: ["single", "bulk"])
@MainActor func deletionJournalBlocksNewOperationAfterUnknownResult(_ outcome: String) async throws {
    let producer = try historyObject()
    let archiveData = try historyData(try #require(producer["archived_timeline"]))
    let archive = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: archiveData).session
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let wire = try #require(JSONSerialization.jsonObject(with: Data(contentsOf:
        root.appendingPathComponent("Fixtures/archive-deletion-core-bbb7a23d.json"))) as? [String: Any])
    let examples = try #require(wire["examples"] as? [String: Any])
    let pendingData = try historyData(try #require(examples["pending_response"]))
    var snapshot = try #require(examples["snapshot_response"] as? [String: Any])
    snapshot["created_at"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1))
    snapshot["expires_at"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(240))
    let snapshotData = try historyData(snapshot)
    let caps = try historyData(["capabilities": ["session_conversation_history": true,
        "session_history_delete": true, "session_history_bulk_delete": true],
        "contract_versions": ["session_conversation_history": 1,"session_history_delete": 1,"session_history_bulk_delete": 1]])
    let profile = try historyData(try #require(producer["later_historical_answer"]))
    let fixture = HistoryWireFixture { request in
        let path = request.url!.path
        if path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if path.hasSuffix("/ask_dj/history") { return (200, profile, 0) }
        if path.hasSuffix("/delete_snapshot") { return (200, snapshotData, 0) }
        if request.httpMethod == "POST" { return (503, pendingData, 0) }
        return (200, archiveData, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { defaults.removePersistentDomain(forName: name) }
    let history = model.sessionHistory
    await history.prepare(); #expect(await history.loadTimeline(archive.id))
    // Both operation kinds must survive the same ambiguous producer response.
    let bulk = outcome == "bulk"
    if bulk {
        let prepared = try #require(await history.prepareBulkDeletion(expectedEpoch: history.responseEpoch))
        #expect(await history.deleteAllSessions(prepared, expectedEpoch: history.responseEpoch) == false)
    } else {
        #expect(await history.deleteSession(archive.id, expectedRevision: archive.revision.value, expectedEpoch: history.responseEpoch) == false)
    }
    #expect(history.hasUnconfirmedDeletion)
    defaults.set("synthetic-resolved-installation", forKey: "DJConnectHAInstallID")
    #expect(history.hasUnconfirmedDeletion)
    let stored = try #require(model.historyDeletionJournalData)
    let records = try JSONDecoder().decode([String: DJConnectSessionHistoryModel.PendingDeletion].self, from: stored)
    let saved = try #require(records.values.first)
    #expect(saved.owner == "profile-a")
    #expect(saved.single?.expectedRevision == (bulk ? nil : archive.revision.value))
    #expect(saved.bulk?.snapshotID == (bulk ? snapshot["snapshot_id"] as? String : nil))
    let storedText = String(decoding: stored, as: UTF8.self)
    #expect(!storedText.contains("synthetic-fixture-token") && !storedText.contains(fixture.baseURL.absoluteString))
    #expect(await history.prepareSessionDeletion(archive.id, expectedEpoch: history.responseEpoch) == nil)
    #expect(await history.prepareBulkDeletion(expectedEpoch: history.responseEpoch) == nil)
    #expect(await history.deleteSession(archive.id, expectedRevision: archive.revision.value, expectedEpoch: history.responseEpoch) == false)
    // Reconstruct the actual model from the same installation-local preferences.
    let reopened = DJConnectAppModel(defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-fixture-token"),
        urlSession: fixture.session(), startBackgroundTasks: false)
    await reopened.sessionHistory.prepare()
    #expect(reopened.sessionHistory.hasUnconfirmedDeletion)
    #expect(!reopened.sessionHistory.canPrepareBulkDeletion)
    #expect(model.historyDeletionJournalData == stored)
    let posts = fixture.requests.filter { $0.httpMethod == "POST" }
    #expect(posts.count == 1)
    let post = try #require(posts.first)
    let body = try #require(JSONSerialization.jsonObject(with: presenceRequestBody(post)) as? [String: Any])
    #expect(body["operation_id"] as? String == saved.operationID)
    // An old/expired recorded operation remains unresolved; age must never mint a new ID.
    let oldID = DJConnectOperationIdentity.uuidV7(milliseconds: Int(Date().addingTimeInterval(-600).timeIntervalSince1970 * 1000))
    let oldSingle = saved.single.map { DJConnectSessionDeleteRequest(sessionID: $0.sessionID,
        expectedRevision: $0.expectedRevision, operationID: oldID) }
    let old = DJConnectSessionHistoryModel.PendingDeletion(owner: saved.owner, scope: saved.scope,
        binding: saved.binding, operationID: oldID, single: oldSingle, bulk: saved.bulk)
    model.storeHistoryDeletionJournal(try JSONEncoder().encode([saved.scope: old]))
    let expired = DJConnectAppModel(defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-fixture-token"),
        urlSession: fixture.session(), startBackgroundTasks: false)
    await expired.sessionHistory.prepare()
    #expect(expired.sessionHistory.hasUnconfirmedDeletion)
    #expect(!expired.sessionHistory.canPrepareBulkDeletion)
    #expect(!expired.sessionHistory.canDeleteSession(archive.id))
    #expect(fixture.requests.filter { $0.httpMethod == "POST" }.count == 1)
}

@Test(arguments: ["fresh", "failure", "withdrawn", "became-active"])
@MainActor func archiveDeletionConfirmationRequiresFreshDetail(_ outcome: String) async throws {
    let producer = try historyObject()
    let initial = try #require(producer["archived_timeline"] as? [String: Any])
    let initialData = try historyData(initial)
    let archive = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: initialData).session
    var updated = initial
    var header = try #require(updated["session"] as? [String: Any])
    header["revision"] = archive.revision.value + "-fresh"
    if outcome == "became-active" { header["lifecycle_status"] = "ACTIVE"; header["read_only"] = false }
    updated["session"] = header
    let freshData = try historyData(updated)
    let caps = try historyData(["capabilities": ["session_conversation_history": true, "session_history_delete": true],
        "contract_versions": ["session_conversation_history": 1, "session_history_delete": 1]])
    let profile = try historyData(try #require(producer["later_historical_answer"]))
    let reads = HTTPRecoveryActiveReadCounter()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/ask_dj/history") { return (200, profile, 0) }
        let count = reads.next()
        if count == 1 { return (200, initialData, 0) }
        if outcome == "failure" { return (503, Data(), 0) }
        return (200, freshData, outcome == "withdrawn" ? 0.1 : 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { defaults.removePersistentDomain(forName: name) }
    let history = model.sessionHistory
    await history.prepare()
    #expect(await history.loadTimeline(archive.id))
    let epoch = history.responseEpoch
    let task = Task { @MainActor in await history.prepareSessionDeletion(archive.id, expectedEpoch: epoch) }
    if outcome == "withdrawn" {
        for _ in 0..<100 where reads.value < 2 { try await Task.sleep(for: .milliseconds(2)) }
        history.suspend()
    }
    let revision = await task.value
    #expect(revision == (outcome == "fresh" ? archive.revision.value + "-fresh" : nil))
    #expect(reads.value == 2)
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
}

@Test(arguments: ["ok", "failure", "conflict", "owner", "epoch", "stale-revision", "unsupported", "active"])
@MainActor func sessionArchiveDeletionPreservesFailuresAndFencesStaleConfirmation(_ outcome: String) async throws {
    let fixtureObject = try historyObject()
    var archiveObject = try #require(fixtureObject["archived_timeline"] as? [String: Any])
    if outcome == "active" {
        var header = try #require(archiveObject["session"] as? [String: Any])
        header["lifecycle_status"] = "ACTIVE"; header["read_only"] = false
        archiveObject["session"] = header
    }
    let archiveData = try historyData(archiveObject)
    let archive = try JSONDecoder().decode(DJConnectSessionTimelinePage.self, from: archiveData).session
    let profile = try historyData(try #require(fixtureObject["later_historical_answer"]))
    let caps = try historyData(["capabilities": ["session_conversation_history": true, "session_history_delete": outcome != "unsupported"],
                               "contract_versions": ["session_conversation_history": 1, "session_history_delete": 1]])
    let emptyList = try historyData(["success":true,"schema_version":1,"sessions":[],"revision":"after-delete","retention_days":30])
    let fixture = HistoryWireFixture { request in
        let path = request.url!.path
        if path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if path.hasSuffix("/ask_dj/history") { return (200, profile, 0) }
        if path.hasSuffix("/session/history/delete") {
            let body = try #require(JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any])
            #expect(body["device_id"] as? String != nil)
            #if os(macOS)
            #expect(body["client_type"] as? String == "macos")
            #else
            #expect(body["client_type"] as? String == "ios")
            #endif
            #expect(body["confirmed"] as? Bool == true)
            #expect(body["session_id"] as? String == archive.id)
            #expect(body["expected_revision"] as? String == archive.revision.value)
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Cache-Control") == "no-store")
            #expect(request.value(forHTTPHeaderField: "Referrer-Policy") == "no-referrer")
            if outcome == "failure" { return (503, Data(#"{"success":false,"error":"history_delete_outcome_unknown"}"#.utf8), 0) }
            if outcome == "conflict" { return (409, Data(#"{"success":false,"error":"history_revision_conflict"}"#.utf8), 0) }
            let response = try historyData(["success":true,"schema_version":1,"operation_id":body["operation_id"]!,
                                           "owner_profile_id":outcome == "owner" ? "profile-b" : "profile-a",
                                           "deleted_session_id":archive.id,"deleted":true])
            return (200, response, outcome == "epoch" ? 0.15 : 0)
        }
        if path.hasSuffix("/session/history") { return (200, emptyList, 0) }
        return (200, archiveData, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    let history = model.sessionHistory
    await history.prepare(); await history.loadTimeline(archive.id)
    let original = history.timelines[archive.id]
    let before = history.responseEpoch
    let task = Task { @MainActor in await history.deleteSession(archive.id,
        expectedRevision: archive.revision.value + (outcome == "stale-revision" ? "-changed" : ""), expectedEpoch: before) }
    if outcome == "epoch" {
        for _ in 0..<100 where !fixture.requests.contains(where: { $0.url!.path.hasSuffix("/delete") }) {
            try await Task.sleep(for: .milliseconds(2))
        }
        history.reset()
    }
    let result = await task.value
    #expect(result == (outcome == "ok"))
    #expect(history.deletingSessionID == nil)
    if ["ok", "conflict"].contains(outcome) { #expect(!history.hasUnconfirmedDeletion) }
    if ["failure", "owner"].contains(outcome) { #expect(history.hasUnconfirmedDeletion) }
    if outcome == "ok" {
        #expect(history.timelines[archive.id] == nil && history.responseEpoch != before)
        // Let the explicitly read-only refresh settle before retiring the fixture.
        for _ in 0..<100 { await Task.yield() }
    } else if outcome != "epoch" {
        #expect(history.timelines[archive.id] == original && history.responseEpoch == before)
    }
    let requests = fixture.requests.filter { $0.url!.path.hasSuffix("/session/history/delete") }
    #expect(requests.count == (["stale-revision", "unsupported", "active"].contains(outcome) ? 0 : 1))
    for request in requests {
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-fixture-token")
    }
    #expect(!fixture.requests.contains { $0.url!.path.hasSuffix("/session/end") || $0.url!.path.hasSuffix("/session/start") })
}

@Test(arguments: [0, 1, 2]) func sessionBulkDeletionRequiresItsOwnCapability(_ version: Int) throws {
    let data = try historyData(["capabilities":["session_conversation_history":true,"session_history_bulk_delete":true],
                               "contract_versions":["session_conversation_history":1,"session_history_bulk_delete":version]])
    let caps = try JSONDecoder().decode(DJConnectSessionHistoryCapabilities.self, from: data)
    #expect(caps.bulkDeletionAvailable == (version == 1))
    #expect(!caps.deletionAvailable)
}

@Test(arguments: ["ok", "expired", "future", "unbounded", "negative", "owner", "schema"])
func sessionBulkDeletionSnapshotRequiresOwnerAndBoundedExpiry(_ change: String) throws {
    let now = Date(timeIntervalSince1970: 1_792_320_000)
    let formatter = ISO8601DateFormatter()
    var object: [String:Any] = ["success":true,"schema_version":1,"owner_profile_id":"profile-a","snapshot_id":"opaque-snapshot",
        "target_count":2,"created_at":formatter.string(from: now),"expires_at":formatter.string(from: now.addingTimeInterval(300))]
    switch change {
    case "expired": object["expires_at"] = formatter.string(from: now)
    case "future": object["created_at"] = formatter.string(from: now.addingTimeInterval(60))
    case "unbounded": object["expires_at"] = formatter.string(from: now.addingTimeInterval(301))
    case "negative": object["target_count"] = -1
    case "owner": object["owner_profile_id"] = "profile-b"
    case "schema": object["schema_version"] = 2
    default: break
    }
    let snapshot = try JSONDecoder().decode(DJConnectSessionDeleteSnapshot.self, from: historyData(object))
    #expect(snapshot.admits(owner:"profile-a",at:now) == (change == "ok"))
    #expect(!DJConnectSessionDeleteRequest(sessionID:"a",expectedRevision:"r",operationID:UUID().uuidString).isValid)
}

private final class HistoryBulkDeleteFixtureState: @unchecked Sendable {
    private let lock = NSLock()
    private var erased = false
    private var holdNext = false
    private var readHeld = false
    var completed: Bool { lock.withLock { erased } }
    var hasHeldRead: Bool { lock.withLock { readHeld } }
    func armRead() { lock.withLock { holdNext = true; readHeld = false } }
    func takeReadHold() -> Bool { lock.withLock {
        guard holdNext else { return false }
        holdNext = false; readHeld = true; return true
    } }
    func complete() { lock.withLock { erased = true } }
}

@Test(arguments: ["ok", "failure", "conflict", "network", "owner", "count", "snapshot", "epoch", "zero", "expired", "unsupported"])
@MainActor func sessionBulkDeletionIsOneSnapshotBoundOperationPreservingActiveFlow(_ outcome: String) async throws {
    let fixtureObject = try historyObject()
    let archiveObject = try #require(fixtureObject["archived_timeline"] as? [String: Any])
    let archiveData = try historyData(archiveObject)
    let archive = try JSONDecoder().decode(DJConnectSessionTimelinePage.self,from:archiveData).session
    var newHeader = try #require(archiveObject["session"] as? [String:Any]); newHeader["session_id"] = "after-snapshot"
    var activeHeader = newHeader; activeHeader["session_id"] = "active-preserved"; activeHeader["lifecycle_status"] = "ACTIVE"; activeHeader["read_only"] = false
    var activePage = archiveObject; activePage["session"] = activeHeader; activePage["entries"] = []
    let activePageData = try historyData(activePage)
    let initialList = try historyData(["success":true,"schema_version":1,"sessions":[archiveObject["session"]!],"revision":"before","next_cursor":"unloaded-page","retention_days":30])
    let refreshedList = try historyData(["success":true,"schema_version":1,"sessions":[newHeader],"revision":"after","retention_days":30])
    var profileObject = try #require(fixtureObject["later_historical_answer"] as? [String:Any]); profileObject["historical_matches"] = []; profileObject["messages"] = []
    let profile = try historyData(profileObject)
    let caps = try historyData(["capabilities":["session_conversation_history":true,"session_history_bulk_delete":outcome != "unsupported"],
                               "contract_versions":["session_conversation_history":1,"session_history_bulk_delete":1]])
    let formatter = ISO8601DateFormatter(), now = Date()
    let snapshotData = try historyData(["success":true,"schema_version":1,"owner_profile_id":"profile-a","snapshot_id":"opaque-all-pages",
        "target_count":outcome == "zero" ? 0 : 2,"created_at":formatter.string(from:now),
        "expires_at":formatter.string(from:now.addingTimeInterval(outcome == "expired" ? -1 : 300))])
    let demo = try DJConnectDemoSessionData.make(language:"nl")
    var active = demo.active; active.sessionID = "active-preserved"; active.broadcast.session.sessionID = active.sessionID
    let activeObject = try JSONSerialization.jsonObject(with:JSONEncoder().encode(active))
    let activeData = try historyData(["success":true,"active_session":activeObject])
    let state = HistoryBulkDeleteFixtureState()
    let fixture = HistoryWireFixture { request in
        let path = request.url!.path
        if path.hasSuffix("/capabilities") { return (200,caps,0) }
        if path.hasSuffix("/ask_dj/history") { return (200,profile,0) }
        if path.hasSuffix("/session/active") { return (200,activeData,0) }
        if path.hasSuffix("/delete_snapshot") {
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField:"Cache-Control") == "no-store")
            return (200,snapshotData,0)
        }
        if path.hasSuffix("/delete_all") {
            let body = try #require(JSONSerialization.jsonObject(with:presenceRequestBody(request)) as? [String:Any])
            // The shared paired transport also carries its existing identity envelope.
            #expect(Set(["device_id","client_type","snapshot_id","operation_id","confirmed"]).isSubset(of:Set(body.keys)))
            #expect(body["session_ids"] == nil && body["query"] == nil && body["cursor"] == nil)
            #expect(body["snapshot_id"] as? String == "opaque-all-pages" && body["confirmed"] as? Bool == true)
            let operation = try #require(body["operation_id"] as? String)
            #expect(operation.split(separator:"-")[2].hasPrefix("7"))
            #expect(request.httpMethod == "POST" && request.value(forHTTPHeaderField:"Cache-Control") == "no-store")
            #expect(request.value(forHTTPHeaderField:"Referrer-Policy") == "no-referrer")
            if outcome == "network" { throw URLError(.timedOut) }
            if outcome == "failure" { return (503,Data(#"{"success":false,"error":"history_delete_outcome_unknown"}"#.utf8),0) }
            if outcome == "conflict" { return (409,Data(#"{"success":false,"error":"history_delete_snapshot_conflict"}"#.utf8),0) }
            let ack = try historyData(["success":true,"schema_version":1,"operation_id":operation,
                "owner_profile_id":outcome == "owner" ? "profile-b" : "profile-a",
                "snapshot_id":outcome == "snapshot" ? "another-set" : "opaque-all-pages",
                "deleted":true,"deleted_session_count":outcome == "count" ? 3 : 2])
            if outcome == "ok" { state.complete() }
            return (200,ack,outcome == "epoch" ? 0.15 : 0)
        }
        if path.hasSuffix("/session/history") { return (200,state.completed ? refreshedList : initialList,0) }
        if path.hasSuffix("/active-preserved") { return (200,activePageData,0) }
        return (200,archiveData,0)
    }
    defer { fixture.close() }
    let (model,defaults,name) = fixture.model(); defer { defaults.removePersistentDomain(forName:name) }
    let history = model.sessionHistory
    #expect(await model.refreshActiveDJSession())
    await history.prepare(); await history.loadSessions(); await history.loadTimeline(archive.id)
    let activeReadLoaded = await history.loadTimeline(active.id)
    #expect(activeReadLoaded)
    #expect(history.timelines[active.id]?.loading == false)
    print("BULK_ACTIVE_BASELINE outcome=\(outcome) loaded=\(activeReadLoaded) loading=\(String(describing: history.timelines[active.id]?.loading))")
    let activeBefore = model.activeDJSession
    let liveBefore = history.timelines[active.id]
    let epoch = history.responseEpoch
    let archiveEpoch = history.archiveResponseEpoch
    let snapshot = await history.prepareBulkDeletion(expectedEpoch:epoch)
    if ["expired","unsupported"].contains(outcome) { #expect(snapshot == nil); return }
    let prepared = try #require(snapshot)
    #expect(prepared.targetCount == (outcome == "zero" ? 0 : 2)) // The server set includes an unloaded page.
    let operation = Task { @MainActor in await history.deleteAllSessions(prepared,expectedEpoch:epoch) }
    if outcome == "epoch" {
        for _ in 0..<100 where !fixture.requests.contains(where: { $0.url!.path.hasSuffix("/delete_all") }) { try await Task.sleep(for:.milliseconds(2)) }
        history.reset()
    }
    let success = await operation.value
    #expect(success == (outcome == "ok"))
    #expect(!history.bulkDeletionBusy)
    if ["ok", "conflict"].contains(outcome) { #expect(!history.hasUnconfirmedDeletion) }
    if ["failure", "network", "owner", "count", "snapshot"].contains(outcome) { #expect(history.hasUnconfirmedDeletion) }
    if outcome == "ok" {
        for _ in 0..<200 where !history.sessions.contains(where: { $0.id == "after-snapshot" }) { try await Task.sleep(for:.milliseconds(2)) }
        #expect(history.sessions.map(\.id) == ["after-snapshot"])
        #expect(history.timelines[archive.id] == nil)
        #expect(history.historicalMatches.values.flatMap { $0 }.allSatisfy { $0.sessionID == active.id })
        #expect(history.archiveResponseEpoch != archiveEpoch)
        #expect(history.responseEpoch == epoch) // Active grants and pending intents keep their authority.
        if history.timelines[active.id] != liveBefore {
            let after = history.timelines[active.id]
            print("BULK_ACTIVE_DIAGNOSTIC loading=\(String(describing: liveBefore?.loading))->\(String(describing: after?.loading)) entries=\(liveBefore?.entries.count ?? -1)->\(after?.entries.count ?? -1) revision=\(String(describing: liveBefore?.revision))->\(String(describing: after?.revision)) windowed=\(String(describing: liveBefore?.windowed))->\(String(describing: after?.windowed)) headerEqual=\(liveBefore?.session == after?.session) cursorEqual=\(liveBefore?.nextCursor == after?.nextCursor) errorEqual=\(liveBefore?.errorKey == after?.errorKey)")
        }
        #expect(model.activeDJSession == activeBefore && history.timelines[active.id] == liveBefore)
    } else if outcome != "epoch" { #expect(history.timelines[archive.id] != nil) }
    let posts = fixture.requests.filter { $0.url!.path.hasSuffix("/delete_all") }
    #expect(posts.count == (outcome == "zero" ? 0 : 1))
    #expect(!fixture.requests.contains { $0.url!.path.hasSuffix("/session/end") || $0.url!.path.hasSuffix("/session/start") || $0.url!.path.hasSuffix("/session/history/delete") })
}

@Test(arguments:["timeline","conversation-history"])
@MainActor func sessionBulkDeletionRejectsPreAcknowledgementArchiveCallbacks(_ read: String) async throws {
    let object = try historyObject()
    let timelineData = try historyData(try #require(object["archived_timeline"]))
    let archive = try JSONDecoder().decode(DJConnectSessionTimelinePage.self,from:timelineData).session
    let oldProfileObject = try #require(object["later_historical_answer"] as? [String:Any])
    let oldProfile = try historyData(oldProfileObject)
    var newProfileObject = oldProfileObject; newProfileObject["messages"] = []
    let newProfile = try historyData(newProfileObject)
    let decoded = try JSONDecoder().decode(DJConnectProfileConversationHistory.self,from:oldProfile)
    #expect(!decoded.historicalMatches.values.flatMap { $0 }.isEmpty)
    let caps = try historyData(["capabilities":["session_conversation_history":true,"session_history_bulk_delete":true],
        "contract_versions":["session_conversation_history":1,"session_history_bulk_delete":1]])
    let list = try historyData(["success":true,"schema_version":1,"sessions":[],"revision":"after","retention_days":30])
    let date = ISO8601DateFormatter(), now = Date()
    let snapshotData = try historyData(["success":true,"schema_version":1,"owner_profile_id":"profile-a","snapshot_id":"old-set",
        "target_count":1,"created_at":date.string(from:now),"expires_at":date.string(from:now.addingTimeInterval(300))])
    let state = HistoryBulkDeleteFixtureState(), gate = HistoryWireResponseGate()
    defer { gate.release() }
    let fixture = HistoryWireFixture { request in
        let path = request.url!.path
        if path.hasSuffix("/capabilities") { return (200,caps,0) }
        if path.hasSuffix("/delete_snapshot") { return (200,snapshotData,0) }
        if path.hasSuffix("/delete_all") {
            let body = try #require(JSONSerialization.jsonObject(with:presenceRequestBody(request)) as? [String:Any])
            state.complete()
            return (200,try historyData(["success":true,"schema_version":1,"operation_id":body["operation_id"]!,
                "owner_profile_id":"profile-a","snapshot_id":"old-set","deleted":true,"deleted_session_count":1]),0)
        }
        if path.hasSuffix("/session/history") { return (200,list,0) }
        let isProfile = path.hasSuffix("/ask_dj/history")
        if (read == "conversation-history" && isProfile || read == "timeline" && path.hasSuffix("/" + archive.id)), state.takeReadHold() {
            throw HistoryWireHeldResponse(data:isProfile ? oldProfile : timelineData,gate:gate)
        }
        return (200,isProfile ? (state.completed ? newProfile : oldProfile) : timelineData,0)
    }
    defer { fixture.close() }
    let (model,defaults,name) = fixture.model(); defer { defaults.removePersistentDomain(forName:name) }
    let history = model.sessionHistory
    await history.prepare(); await history.loadTimeline(archive.id)
    state.armRead()
    let oldRead = Task { @MainActor in
        if read == "timeline" { await history.loadTimeline(archive.id) }
        else { await history.refreshConversation() }
    }
    for _ in 0..<200 where !state.hasHeldRead { try await Task.sleep(for:.milliseconds(2)) }
    #expect(state.hasHeldRead)
    let epoch = history.responseEpoch
    let snapshot = try #require(await history.prepareBulkDeletion(expectedEpoch:epoch))
    #expect(await history.deleteAllSessions(snapshot,expectedEpoch:epoch))
    gate.release(); await oldRead.value
    for _ in 0..<100 { await Task.yield() }
    #expect(history.responseEpoch == epoch)
    #expect(history.timelines[archive.id] == nil)
    #expect(history.historicalMatches.values.flatMap { $0 }.isEmpty)
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/delete_all") }.count == 1)
}

@Test @MainActor func deviceSTTSubmitsOneTextTurnAndNeverAnAudioRequest() async throws {
    let receipt = try historyObject()
    let history = try historyData(try #require(receipt["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.httpMethod == "POST" { return (503, Data(), 0) }
        return (200, history, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    model.deviceSTTEnabled = true
    let context = DJConnectConversationContext(sessionID: model.activeDJSession?.sessionID, selectedEntry: model.sessionHistory.selectedEntry)
    let operation = model.voiceOperationID
    model.acceptDeviceSTTTranscript("  Speel Nirvana  ", operation: operation,
        historyEpoch: model.sessionHistory.responseEpoch, context: context, originalDraft: "", captureLanguage: model.language)
    try await Task.sleep(for: .milliseconds(150))
    let posts = fixture.requests.filter { $0.httpMethod == "POST" }
    #expect(posts.count == 1)
    let body = try presenceRequestBody(#require(posts.first))
    let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(payload["text"] as? String == "Speel Nirvana")
    #expect(posts.allSatisfy { !$0.url!.path.hasSuffix("/voice") && $0.value(forHTTPHeaderField: "Content-Type")?.contains("json") == true })
    #expect(model.askDJDraft.isEmpty)
    let before = fixture.requests.count
    model.acceptDeviceSTTTranscript("Speel Nirvana", operation: operation, historyEpoch: model.sessionHistory.responseEpoch,
        context: context, originalDraft: "", captureLanguage: model.language)
    await model.uploadRecordedVoiceWAV(Data([82,73,70,70]), operation: model.voiceOperationID, historyEpoch: model.sessionHistory.responseEpoch)
    #expect(fixture.requests.count == before)
}

@Test @MainActor func deviceSTTRejectsStaleContextEmptyOrEditedDraftWithoutSending() async throws {
    let fixture = HistoryWireFixture { _ in (503, Data(), 0) }; defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    model.deviceSTTEnabled = true
    let context = DJConnectConversationContext(sessionID: model.activeDJSession?.sessionID, selectedEntry: model.sessionHistory.selectedEntry)
    let operation = model.voiceOperationID, epoch = model.sessionHistory.responseEpoch, language = model.language
    model.askDJDraft = "Keep this draft"
    model.acceptDeviceSTTTranscript("Recognized", operation: operation, historyEpoch: epoch,
        context: context, originalDraft: "", captureLanguage: language)
    #expect(model.askDJDraft == "Keep this draft")
    for (text, op, ep, ctx, lang) in [
        (" ", operation, epoch, context, language),
        ("Recognized", UUID(), epoch, context, language),
        ("Recognized", operation, UUID(), context, language),
        ("Recognized", operation, epoch, DJConnectConversationContext(sessionID: "different-session"), language),
        ("Recognized", operation, epoch, context, "changed-language")
    ] {
        model.acceptDeviceSTTTranscript(text, operation: op, historyEpoch: ep, context: ctx,
            originalDraft: "Keep this draft", captureLanguage: lang)
    }
    model.deviceSTTEnabled = false
    model.acceptDeviceSTTTranscript("Recognized", operation: model.voiceOperationID, historyEpoch: epoch,
        context: context, originalDraft: "Keep this draft", captureLanguage: language)
    #expect(model.askDJDraft == "Keep this draft")
    #expect(fixture.requests.isEmpty)
}

@Test(arguments: [false, true]) @MainActor
func sessionSearchAutomaticPagingFencesOldFootersAndRepeatedCursors(repeatsCursor: Bool) async throws {
    let receipt = try historyObject()
    let timeline = try #require(receipt["archived_timeline"] as? [String: Any])
    let entries = try #require(timeline["entries"] as? [[String: Any]])
    let sessionID = try #require(receipt["session_id"] as? String)
    let profile = try historyData(try #require(receipt["later_historical_answer"]))
    let caps = Data(#"{"capabilities":{"session_conversation_history":true,"session_flow_text_search":true},"contract_versions":{"session_conversation_history":1,"session_flow_text_search":1}}"#.utf8)
    let first = try historyData(["success":true,"schema_version":1,"session_id":sessionID,"query":"music","revision":"6:0:0",
        "matches":[],"returned_count":0,"complete":false,"next_cursor":"next-search-page","normalization":"NFKC-casefold","highlight_units":"utf16"])
    var final: [String: Any] = ["success":true,"schema_version":1,"session_id":sessionID,"query":"music","revision":"6:0:0",
        "matches":entries,"returned_count":entries.count,"complete":!repeatsCursor,"normalization":"NFKC-casefold","highlight_units":"utf16"]
    if repeatsCursor { final["next_cursor"] = "next-search-page" }
    let finalData = try historyData(final)
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/search") {
            let cursor = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "cursor" })?.value
            return (200, cursor == nil ? first : finalData, 0)
        }
        return (200, profile, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    let history = model.sessionHistory
    await history.prepare()
    history.search(sessionID: sessionID, query: "music")
    for _ in 0..<200 {
        if !history.searchLoading { break }
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(history.searchNextCursor == "next-search-page")
    await history.moreSearch(expectedCursor: "old-footer")
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/search") }.count == 1)
    await history.moreSearch(expectedCursor: "next-search-page")
    if repeatsCursor {
        #expect(history.searchErrorKey != nil && history.searchNextCursor == nil)
    } else {
        #expect(history.searchComplete && !history.searchMatches.isEmpty && history.searchNextCursor == nil)
    }
    await history.moreSearch(expectedCursor: "next-search-page")
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/search") }.count == 2)
}

@Test @MainActor func manualRefreshSharesResultAndSurvivesGestureCancellation() async throws {
    let reads = HTTPRecoveryActiveReadCounter()
    let wire = HistoryWireFixture { request in
        let body = try? JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any]
        if body?["command"] as? String == "status" {
            _ = reads.next()
            return (200, Data(#"{"success":true,"playback":{"is_playing":false},"backend_available":true}"#.utf8), 0.15)
        }
        return (200, Data(#"{"success":true}"#.utf8), 0)
    }
    defer { wire.close() }
    let (model, defaults, name) = wire.model(); defer { defaults.removePersistentDomain(forName: name) }
    model.pairingStatus = .paired
    let gesture = Task { await model.refreshNowPlaying() }
    for _ in 0..<100 where reads.value == 0 { try await Task.sleep(for: .milliseconds(5)) }
    #expect(reads.value == 1)
    gesture.cancel()
    let toolbar = Task { await model.refreshNowPlaying() }
    #expect(await gesture.value)
    #expect(await toolbar.value)
    #expect(reads.value == 1)
    #expect(!model.isRefreshing)
    #expect(model.pairingStatus == .paired)
}

@Test @MainActor func manualRefreshWaitsForBusyRefreshInsteadOfReportingFailure() async throws {
    let wire = HistoryWireFixture { _ in (200, Data(#"{"success":true}"#.utf8), 0) }
    defer { wire.close() }
    let (model, defaults, name) = wire.model(); defer { defaults.removePersistentDomain(forName: name) }
    model.isDemoMode = true
    model.isRefreshing = true
    let refresh = Task { await model.refreshNowPlaying() }
    await Task.yield()
    model.isRefreshing = false
    #expect(await refresh.value)
    #expect(!model.isRefreshing)
}

@Test @MainActor func manualRefreshStillReportsRealTransportFailure() async throws {
    let wire = HistoryWireFixture { _ in throw URLError(.cannotConnectToHost) }
    defer { wire.close() }
    let (model, defaults, name) = wire.model(); defer { defaults.removePersistentDomain(forName: name) }
    model.pairingStatus = .paired
    #expect(await model.refreshNowPlaying() == false)
    #expect(!model.isRefreshing)
}

@Test @MainActor func discoveryManualRefreshSurvivesCancelledGestureAndSharesToolbarRequest() async throws {
    let reads = HTTPRecoveryActiveReadCounter()
    let wire = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/music_discovery/refresh") {
            _ = reads.next()
            return (200, Data(#"{"success":true,"enabled":true,"revision":42,"sections":[{"id":"tracks","title":"Tracks","items":[{"id":"track","kind":"track","title":"Backend recommendation","uri":"spotify:track:exact","reason":"Source"}]}]}"#.utf8), 0.15)
        }
        return (404, Data(), 0)
    }
    defer { wire.close() }
    let (model, defaults, name) = wire.model(); defer { defaults.removePersistentDomain(forName: name) }
    let gesture = Task { await model.refreshMusicDiscovery() }
    for _ in 0..<100 where reads.value == 0 { try await Task.sleep(for: .milliseconds(5)) }
    #expect(reads.value == 1)
    gesture.cancel()
    let toolbar = Task { await model.refreshMusicDiscovery() }
    #expect(await gesture.value)
    #expect(await toolbar.value)
    #expect(reads.value == 1)
    #expect(model.musicDiscoveryResponse?.revision == 42)
    #expect(model.musicDiscoveryResponse?.visibleSections.first?.visibleItems.first?.title == "Backend recommendation")
    #expect(model.musicDiscoveryErrorMessage == nil)
    #expect(!model.isRefreshingMusicDiscovery)
}

@Test @MainActor func discoveryCancelledGestureStillRejectsResponseAfterSuspension() async throws {
    let reads = HTTPRecoveryActiveReadCounter()
    let wire = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/music_discovery/refresh") {
            _ = reads.next()
            return (200, Data(#"{"success":true,"enabled":true,"revision":42,"sections":[]}"#.utf8), 0.15)
        }
        return (404, Data(), 0)
    }
    defer { wire.close() }
    let (model, defaults, name) = wire.model(); defer { defaults.removePersistentDomain(forName: name) }
    let gesture = Task { await model.refreshMusicDiscovery() }
    for _ in 0..<100 where reads.value == 0 { try await Task.sleep(for: .milliseconds(5)) }
    #expect(reads.value == 1)
    gesture.cancel()
    model.markInactiveSession()
    #expect(await gesture.value == false)
    #expect(model.musicDiscoveryResponse == nil)
    #expect(!model.isRefreshingMusicDiscovery)
}

@Test @MainActor func unifiedManualRefreshShowsBothPhasesAndSharesCancelledGesture() async throws {
    let controller = DJConnectManualRefreshController()
    var calls = 0
    let gesture = Task {
        await controller.run(language: "nl", systemImage: "arrow.clockwise") {
            calls += 1
            try? await Task.sleep(for: .milliseconds(150))
            return "Bijgewerkt"
        }
    }
    for _ in 0..<100 where calls == 0 { try await Task.sleep(for: .milliseconds(5)) }
    #expect(controller.notice?.text == "Bijwerken…")
    #expect(controller.isRefreshing)
    gesture.cancel()
    let toolbar = Task {
        await controller.run(language: "nl", systemImage: "arrow.clockwise") {
            calls += 1
            return "Wrong duplicate result"
        }
    }
    await gesture.value
    await toolbar.value
    #expect(calls == 1)
    #expect(controller.notice?.text == "Bijgewerkt")
    #expect(!controller.isRefreshing)
    await controller.run(language: "nl", systemImage: "arrow.clockwise") { "Bijwerken mislukt" }
    #expect(controller.notice?.text == "Bijwerken mislukt")
}

@Test @MainActor func unifiedManualRefreshWaitsForBackgroundWorkAndRejectsChangedOwner() async throws {
    let controller = DJConnectManualRefreshController()
    var busy = true
    var current = true
    var calls = 0
    let gesture = Task {
        await controller.run(language: "nl", systemImage: "heart", isCurrent: { current }, isBusy: { busy }) {
            calls += 1
            return "Bijgewerkt"
        }
    }
    for _ in 0..<100 where !controller.isRefreshing { try await Task.sleep(for: .milliseconds(5)) }
    #expect(controller.notice?.text == "Bijwerken…")
    #expect(calls == 0)
    gesture.cancel()
    current = false
    busy = false
    await gesture.value
    #expect(calls == 0)
    #expect(controller.notice == nil)
    #expect(!controller.isRefreshing)
    current = true
    busy = true
    let retry = Task {
        await controller.run(language: "nl", systemImage: "heart", isBusy: { busy }) {
            calls += 1
            return "Bijgewerkt"
        }
    }
    for _ in 0..<100 where !controller.isRefreshing { try await Task.sleep(for: .milliseconds(5)) }
    busy = false
    await retry.value
    #expect(calls == 1)
    #expect(controller.notice?.text == "Bijgewerkt")
}

@Test @MainActor func unifiedManualRefreshCannotPublishCompletionAfterContextChanges() async throws {
    let controller = DJConnectManualRefreshController()
    var current = true
    var started = false
    let refresh = Task {
        await controller.run(language: "nl", systemImage: "heart", isCurrent: { current }) {
            started = true
            try? await Task.sleep(for: .milliseconds(100))
            return "Stale result"
        }
    }
    for _ in 0..<100 where !started { try await Task.sleep(for: .milliseconds(5)) }
    current = false
    await refresh.value
    #expect(controller.notice == nil)
    #expect(!controller.isRefreshing)
}


@Test(arguments: ["cancelled", "transient", "incompatible"]) @MainActor
func personaTouchCapabilityRefreshWithdrawsStaleSupportExceptCancellation(fault: String) async throws {
    let phase = HistoryAuthorityGate()
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/persona-touch-discovery-installed-20261019.json")
    let discovery = try Data(contentsOf: url)
    let fixture = HistoryWireFixture { request in
        guard request.url!.path.hasSuffix("/capabilities") else { return (404, Data(), 0) }
        if !phase.denied { return (200, discovery, 0) }
        if fault == "transient" { return (503, Data(#"{"error":"temporarily_unavailable"}"#.utf8), 0) }
        if fault == "incompatible" { return (200, Data(#"{"active_session_persona":false}"#.utf8), 0) }
        return (200, discovery, 0.2)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshActiveMoodCapability()
    #expect(model.activePersonaReactionAvailable)
    let count = fixture.requests.count
    phase.denied = true
    if fault == "cancelled" {
        let pending = Task { await model.refreshActiveMoodCapability() }
        for _ in 0..<100 where fixture.requests.count == count { try await Task.sleep(for: .milliseconds(5)) }
        #expect(fixture.requests.count > count && !model.activePersonaReactionAvailable)
        pending.cancel(); await pending.value
        #expect(model.activePersonaReactionAvailable)
    } else {
        await model.refreshActiveMoodCapability()
        #expect(!model.activePersonaReactionAvailable)
        phase.denied = false
        await model.refreshActiveMoodCapability()
        #expect(model.activePersonaReactionAvailable)
    }
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
}

@Test @MainActor func deviceSpeechStatusIsEphemeralScopedAndNeverOverridesApplePreference() throws {
    let fixture = HistoryWireFixture { _ in (200, Data(), 0) }; defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set("speech-install", forKey: "DJConnectHAInstallID")
    model.language = "en"
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/device-speech-core-604b80f8.json")
    let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: source)) as? [String: Any])
    let cases = try #require(root["cases"] as? [[String: Any]])
    let snapshot = try #require(cases.first { $0["case"] as? String == "configuration_stt_True_tts_True" }?["snapshot"] as? [String: Any])
    func apply(_ value: Any?, install: String = "speech-install") throws {
        var body: [String: Any] = ["success": true, "ha_install_id": install]
        body["device_speech"] = value
        let status = try JSONDecoder().decode(DJConnectEnvelope<DJConnectPlayback>.self, from: historyData(body))
        _ = model.applyStatusEndpoints(status, expectedLocal: model.haLocalURL, expectedRemote: model.haRemoteURL, expectedInstall: "speech-install")
    }
    #expect(!model.canUseVoiceInputRoute && !model.canUseHASpeechOutput(.local))
    try apply(snapshot)
    #expect(model.haSpeechConfiguration != nil)
    #expect(model.canUseVoiceInputRoute && model.canUseHASpeechOutput(.local))
    #expect(!model.canUseHASpeechOutput(.haSpeaker))
    model.language = "fr"
    #expect(model.haSpeechConfiguration == nil)
    #expect(!model.canUseVoiceInputRoute && !model.canUseHASpeechOutput(.local))
    model.language = try #require(snapshot["locale"] as? String)
    try apply(nil)
    #expect(model.haSpeechConfiguration == nil)
    #expect(!model.canUseVoiceInputRoute && !model.canUseHASpeechOutput(.local))
    try apply(snapshot, install: "wrong-install")
    #expect(!model.canUseVoiceInputRoute)
    model.deviceSTTEnabled = true
    #expect(model.canUseVoiceInputRoute)
    try apply(nil)
    #expect(model.deviceSTTEnabled && model.canUseVoiceInputRoute)
    #expect(!model.canUseHASpeechOutput(.local))
}

@Test(arguments: [DJConnectClientType.ios, .watchos])
func deviceSpeechFreshReadUsesStatusWithoutAudioAndRequiresSameInstallation(clientType: DJConnectClientType) async throws {
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/device-speech-core-604b80f8.json")
    let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: source)) as? [String: Any])
    let cases = try #require(root["cases"] as? [[String: Any]])
    let snapshot = try #require(cases.first?["snapshot"] as? [String: Any])
    let body = try historyData(["success": true, "ha_install_id": "speech-install", "device_speech": snapshot])
    let fixture = HistoryWireFixture { request in
        #expect(request.url?.path == "/api/djconnect/v1/status")
        #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-Type") == clientType.rawValue)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        return (200, body, 0)
    }; defer { fixture.close() }
    let identity = DJConnectIdentity(deviceID: clientType == .watchos ? "djconnect-watchos-ABCDEF123456" : "djconnect-ios-ABCDEF123456",
        deviceName: "Fixture", clientType: clientType, firmware: "4.0.0", platform: clientType == .watchos ? .watchos : .ios)
    let client = DJConnectClient(baseURL: fixture.baseURL, identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-fixture-token"), session: fixture.session())
    #expect(try await client.currentDeviceSpeech(language: "en", expectedInstallationID: "speech-install") != nil)
    #expect(try await client.currentDeviceSpeech(language: "en", expectedInstallationID: "wrong-install") == nil)
    #expect(try await client.currentDeviceSpeech(language: "fr", expectedInstallationID: "speech-install") == nil)
    #expect(fixture.requests.count == 3)
}

@Test @MainActor func deviceSpeechUnknownMetadataBlocksHAUploadWithoutSwitchingAppleInput() async throws {
    let body = Data(#"{"success":true,"ha_install_id":"speech-install","voice_supported":true,"ask_dj_voice_supported":true}"#.utf8)
    let fixture = HistoryWireFixture { _ in (200, body, 0) }; defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    defaults.set("speech-install", forKey: "DJConnectHAInstallID")
    await model.uploadRecordedVoiceWAV(Data([82, 73, 70, 70]), operation: model.voiceOperationID, historyEpoch: model.sessionHistory.responseEpoch)
    #expect(fixture.requests.count == 1)
    #expect(fixture.requests.allSatisfy { $0.url?.path.hasSuffix("/status") == true })
    #expect(!model.deviceSTTEnabled && !model.canUseVoiceInputRoute)
    model.deviceSTTEnabled = true
    await model.uploadRecordedVoiceWAV(Data([82, 73, 70, 70]), operation: model.voiceOperationID, historyEpoch: model.sessionHistory.responseEpoch)
    #expect(fixture.requests.count == 1)
    #expect(model.deviceSTTEnabled && model.canUseVoiceInputRoute)
}

@Test @MainActor func legacyAskDJTextNeverRequestsInlineSynthesisDespiteSavedAudioPreference() async throws {
    let body = Data(#"{"success":true,"text":"Synthetic answer","dj_text":"Synthetic answer"}"#.utf8)
    let fixture = HistoryWireFixture { request in
        #expect(request.url?.path == "/api/djconnect/v1/ask_dj/message")
        let payload = try #require(JSONSerialization.jsonObject(with: presenceRequestBody(request)) as? [String: Any])
        #expect(payload["audio_response"] as? String == "never")
        #expect(payload["client_message_id"] as? String == "fixed-legacy-text")
        return (200, body, 0)
    }; defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    defaults.set("always", forKey: "DJConnectAskDJAudioResponseMode")
    model.localResponseAudioEnabled = true
    let response = try await model.sendAskDJTextWithFallback("Synthetic question", clientMessageID: "fixed-legacy-text")
    #expect(response.text == "Synthetic answer" && fixture.requests.count == 1)
    #expect(defaults.string(forKey: "DJConnectAskDJAudioResponseMode") == "always")
    #expect(model.localResponseAudioEnabled)
}

@Test @MainActor func switchingBackFromAppleSTTRequalifiesHAInputWithoutSendingAudio() async throws {
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/device-speech-core-604b80f8.json")
    let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: source)) as? [String: Any])
    let cases = try #require(root["cases"] as? [[String: Any]])
    let snapshot = try #require(cases.first { $0["case"] as? String == "configuration_stt_True_tts_True" }?["snapshot"])
    let bytes = try historyData(["success": true, "ha_install_id": "speech-install", "device_speech": snapshot])
    let fixture = HistoryWireFixture { request in
        #expect(request.url?.path == "/api/djconnect/v1/status")
        return (200, bytes, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set("speech-install", forKey: "DJConnectHAInstallID")
    model.language = "en"
    model.deviceSTTEnabled = true
    #expect(model.canUseVoiceInputRoute)
    model.deviceSTTEnabled = false
    #expect(!model.canUseVoiceInputRoute)
    #expect(await model.refreshHAInputAvailabilityIfNeeded())
    #expect(model.canUseVoiceInputRoute && !model.deviceSTTEnabled)
    #expect(!fixture.requests.isEmpty)
    #expect(fixture.requests.allSatisfy { $0.url?.path == "/api/djconnect/v1/status" })
}


@Test @MainActor func avatarAuthorityDoesNotDependOnPlaybackBackendAvailability() async throws {
    let profile = try historyData(try #require(historyObject()["later_historical_answer"]))
    let runtime = try activeMoodRuntimeWire()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, activeMoodCapsWire, 0) }
        if request.url!.path.hasSuffix("/session/active") { return (200, runtime, 0) }
        if request.url!.path.hasSuffix("ask_dj/history") { return (200, profile, 0) }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model()
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    await model.sessionHistory.prepare()
    await model.refreshActiveDJSession()
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/profile-settings3-core-1329ad1.json")
    let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let rows = try #require(object["cases"] as? [[String: Any]])
    let settings = try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self,
        from: historyData(try #require(rows.first { $0["case"] as? String == "paired_no_session_all_five" }?["response"])))
    model.profileDJSettings.bind(owner: "avatar-fixture", active: true)
    await model.profileDJSettings.refresh(.init(read: { settings }, update: { _, _, _ in throw CancellationError() }, receipt: { _, _ in throw CancellationError() }))
    model.isConnected = true
    model.backendAvailable = false
    let session = try #require(model.activeDJSession)
    let evidence = model.personaEvidence(for: session, admittedMoment: nil)
    #expect(evidence.authorized)
    #expect(!evidence.capturing && !evidence.speaking) // backend recovery alone never fabricates activity
    #expect(DJPersonaActivity.resolve(evidence) == .resting)
    model.isConnected = false
    #expect(!model.personaEvidence(for: session, admittedMoment: nil).authorized)
    model.isConnected = true
    model.sessionHistory.suspend()
    #expect(!model.personaEvidence(for: session, admittedMoment: nil).authorized)
}

@Test @MainActor func unavailableBackendMetadataSchedulesRecoveryWithoutManualRefresh() async throws {
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/status") { return (200, Data(#"{"success":true,"backend_available":true}"#.utf8), 0) }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let name = "backend-recovery-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name))
    defaults.set(fixture.baseURL.absoluteString, forKey: "DJConnectHomeAssistantURL")
    defaults.set(fixture.baseURL.absoluteString, forKey: "DJConnectHALocalURL")
    defaults.set("local", forKey: "DJConnectHAConnectionMode")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-fixture-token"),
        urlSession: fixture.session(), startBackgroundTasks: true)
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: name) }
    // Finish the normal startup reads first, then simulate metadata-only failure.
    try await Task.sleep(for: .seconds(2))
    model.isConnected = true
    model.pairingStatus = .paired
    let baseline = fixture.requests.filter { $0.url!.path.hasSuffix("/status") }.count
    model.apply(musicBackendSummary: .init(musicBackendAvailable: false))
    #expect(!model.backendAvailable)
    // This is below the independent 10-second poll: only the recovery task can repair it.
    for _ in 0..<250 where !model.backendAvailable { try await Task.sleep(for: .milliseconds(20)) }
    #expect(model.backendAvailable)
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/status") }.count > baseline)
    // A version mismatch is not a transient music failure. It cancels an
    // already scheduled retry and prevents new retries until compatibility returns.
    model.apply(musicBackendSummary: .init(musicBackendAvailable: false))
    model.updateRequiredMessage = "Update required"
    let beforeMismatchWait = fixture.requests.filter { $0.url!.path.hasSuffix("/status") }.count
    try await Task.sleep(for: .milliseconds(2300))
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/status") }.count == beforeMismatchWait)
    #expect(!model.backendAvailable)
    model.updateRequiredMessage = nil
    for _ in 0..<250 where !model.backendAvailable { try await Task.sleep(for: .milliseconds(20)) }
    #expect(model.backendAvailable)
    #expect(fixture.requests.filter { $0.url!.path.hasSuffix("/status") }.count > beforeMismatchWait)
}

private final class ForecastWireDataSlot: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Data
    private var reads = 0
    func isFirstRead() -> Bool { lock.withLock { reads += 1; return reads == 1 } }
    init(_ value: Data) { self.value = value }
    func read() -> Data { lock.withLock { value } }
    func replace(_ next: Data) { lock.withLock { value = next } }
}

// Native Forecast crosses ordinary paired transport; all replies here are explicit fixtures.
@Test(arguments: ["current", "background", "owner-reset", "context-same", "context-older", "persona-conflict", "unsequenced-live", "unsequenced-live-during-read", "context-locale", "context-direction", "context-read-replacement", "transport-recovery", "disconnect-during-read", "sequenced-event-withdrawal", "sequenced-snapshot-withdrawal", "sequenced-withdrawal-equal-read"]) @MainActor
func forecastNativeOwnerReadRetainsDraftAndFencesLateBackgroundResponse(fence: String) async throws {
    let fixtureRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let rows = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: fixtureRoot.appendingPathComponent("Fixtures/session-forecast-core-3cfa5512.json"))) as? [[String: Any]])
    var response = try #require(rows.first?["owner_read"] as? [String: Any])
    var projection = try #require(response["forecast"] as? [String: Any])
    var runtimeBody = try #require(JSONSerialization.jsonObject(with: activePersonaRuntimeWire()) as? [String: Any])
    var runtime = try #require(runtimeBody["session"] as? [String: Any])
    let id = try #require(runtime["session_id"] as? String)
    projection["session_id"] = id; response["session_id"] = id
    projection["issued_at"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1))
    let nativeExpiryProbe = fence == "current" && ProcessInfo.processInfo.environment["DJCONNECT_FORECAST_EXPIRY_DIR"] != nil
    projection["valid_until"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(nativeExpiryProbe ? 6 : 90))
    projection["imagery"] = [] // Byte transport is qualified separately; no fabricated photo in this test.
    response["forecast"] = projection
    var forecastReply = try historyData(response)
    let anchor = try #require(projection["current_anchor"] as? [String: Any])
    var broadcast = try #require(runtime["broadcast"] as? [String: Any])
    broadcast["playback"] = ["state": "playing", "item_id": anchor["item_id"]!, "source_url": anchor["source_url"]!]
    runtime["broadcast"] = broadcast; runtimeBody["session"] = runtime
    var runtimeReply = try historyData(runtimeBody)
    let history = try historyData(try #require(historyObject()["later_historical_answer"]))
    let capability: [String: Any] = ["available": true, "version": 1,
        "path": "/api/djconnect/v1/session/forecast/{session_id}", "method": "GET",
        "authentication": "paired_device_bearer", "scope": "active_device_bound_owner_session",
        "live_field": "session_forecast", "live_event": "forecast_changed", "nominal_window_seconds": 900,
        "history": false, "emitted_imagery_roles": ["current"], "qualified_upcoming_media": false]
    let populatedFlowProbe = fence == "current" && ProcessInfo.processInfo.environment["DJCONNECT_POPULATED_FLOW_DIR"] != nil
    let populatedFlowReply: Data?
    let populatedFlowPageReply: Data?
    if populatedFlowProbe {
        let producer = try historyObject("retention-bases-v2")
        let tail = try #require(producer["tail_window"] as? [String: Any])
        let producerSession = try #require((tail["session"] as? [String: Any])?["session_id"] as? String)
        // Preserve authored rows, retention bases and window metadata. Only bind
        // this qualified synthetic response to the current test runtime identity.
        func rebind(_ value: Any) -> Any {
            if let text = value as? String, text == producerSession { return id }
            if let object = value as? [String: Any] { return object.mapValues(rebind) }
            if let array = value as? [Any] { return array.map(rebind) }
            return value
        }
        let rebound = try #require(rebind(tail) as? [String: Any])
        populatedFlowReply = try historyData(rebound)
        // The screen also prefetches an ordinary page. Derive only its envelope
        // from the same six admitted rows; do not fabricate additional entries.
        var ordinary = rebound
        for key in ["window", "anchor_entry_id", "window_limit", "scanned_order_min", "scanned_order_max", "scan_complete"] {
            ordinary.removeValue(forKey: key)
        }
        populatedFlowPageReply = try historyData(ordinary)
    } else { populatedFlowReply = nil; populatedFlowPageReply = nil }
    let keyboardProbe = fence == "current" && ProcessInfo.processInfo.environment["DJCONNECT_FORECAST_KEYBOARD_DIR"] != nil
    var historyVersions = ["session_conversation_history": 1, "session_forecast": 1, "session_flow_text_search": 1]
    if populatedFlowProbe { historyVersions["session_history_entries"] = 2 }
    let caps = try historyData(["capabilities": ["session_conversation_history": true, "session_forecast": true,
        "session_flow_text_search": keyboardProbe],
        "contract_versions": historyVersions, "session_forecast": capability])
    let originalRuntimeReply = runtimeReply
    let originalForecastReply = forecastReply
    var changed = runtime
    var live = try #require(changed["broadcast"] as? [String: Any])
    var tuple = try #require(live["session"] as? [String: Any])
    if fence == "context-locale" || fence == "context-read-replacement" {
        tuple["locale"] = "fr"
    } else if fence == "context-direction" {
        var planner = try #require(live["planner"] as? [String: Any])
        planner["current_direction"] = "building_energy"
        var direction = try #require(planner["session_direction"] as? [String: Any])
        direction["direction"] = "building_energy"
        planner["session_direction"] = direction
        live["planner"] = planner
    } else if fence == "persona-conflict" {
        tuple["dj_persona"] = "club_dj" // Contradicts retained home_dj at revision0.
    } else {
        changed["selected_mood"] = "changed-context"; changed["mood_revision"] = 1
        tuple["selected_mood"] = "changed-context"; tuple["mood_revision"] = 1
    }
    live["session"] = tuple; changed["broadcast"] = live
    runtimeBody["session"] = changed; runtimeReply = try historyData(runtimeBody)
    if fence == "context-older" {
        projection["revision"] = max(0, (projection["revision"] as? Int ?? 1) - 1)
        response["forecast"] = projection; forecastReply = try historyData(response)
    }
    let runtimeReplies = ForecastWireDataSlot(originalRuntimeReply)
    let forecastReplies = ForecastWireDataSlot(originalForecastReply)
    let gate = HistoryWireResponseGate()
    defer { gate.release() }
    let fixture = HistoryWireFixture { request in
        let path = request.url!.path
        if path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if path.hasSuffix("/session/active") { return (200, runtimeReplies.read(), 0) }
        if path.hasSuffix("/session/forecast/" + id) {
            let reply = forecastReplies.read()
            if ["context-read-replacement", "disconnect-during-read"].contains(fence), forecastReplies.isFirstRead() {
                throw HistoryWireHeldResponse(data: reply, gate: gate)
            }
            if ["background", "owner-reset", "unsequenced-live-during-read", "sequenced-event-withdrawal", "sequenced-snapshot-withdrawal"].contains(fence) { throw HistoryWireHeldResponse(data: reply, gate: gate) }
            return (200, reply, 0)
        }
        if path.hasSuffix("/session/history/" + id), let populatedFlowReply, let populatedFlowPageReply {
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            guard request.httpMethod == "GET", query.contains(URLQueryItem(name: "limit", value: "20")),
                  query.contains(URLQueryItem(name: "history_contract_version", value: "2")) else { return (400, Data(), 0) }
            if query.contains(URLQueryItem(name: "window", value: "tail")) { return (200, populatedFlowReply, 0) }
            if !query.contains(where: { $0.name == "window" || $0.name == "cursor" }) { return (200, populatedFlowPageReply, 0) }
            return (404, Data(), 0)
        }
        if path.hasSuffix("/ask_dj/history") { return (200, history, 0) }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    let panel = SessionForecastContent(model: model, query: .constant(""), searchExpanded: .constant(false),
                                       searchBoundsChanged: { _ in })
    let beforeOwner = panel.contextKey
    await model.sessionHistory.prepare()
    if fence == "current" {
        #expect(model.sessionHistory.hasAuthorizedOwner)
        if populatedFlowProbe { #expect(beforeOwner.ownerEpoch != panel.contextKey.ownerEpoch) }
        else { #expect(beforeOwner.ownerEpoch == panel.contextKey.ownerEpoch) }
        #expect(beforeOwner != panel.contextKey, "Owner readiness must restart the panel task without waiting thirty seconds")
    }
    await model.refreshActiveDJSession()
    // This fixture drives snapshots explicitly; cancel automatic live fallback
    // before testing controlled owner reads and held-response ordering.
    let initialSnapshot = try #require(model.activeDJSession).broadcast
    model.stopSessionBroadcast()
    model.applySessionBroadcastSnapshot(initialSnapshot)
    #expect(model.sessionHistory.hasAuthorizedOwner && model.activeDJSession?.id == id)
    model.askDJDraft = "Keep this unsent question"
    let task = Task { await model.refreshSessionForecast() }
    for _ in 0..<100 where !fixture.requests.contains(where: { $0.url?.path.hasSuffix("/session/forecast/" + id) == true }) {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(fixture.requests.contains { $0.url?.path.hasSuffix("/session/forecast/" + id) == true })
    if fence == "sequenced-event-withdrawal" || fence == "sequenced-snapshot-withdrawal" {
        let watermark = model.activeDJSession?.broadcast.delivery?.snapshotWatermark ?? 0
        let originalAuthority = model.forecastAuthorityGeneration
        if fence == "sequenced-event-withdrawal" {
            var event = DJConnectSessionBroadcastEvent(eventType: "forecast_changed", sessionID: id, payload: .init())
            event.deliverySequence = watermark + 1
            model.applySessionBroadcastEvent(event)
        } else {
            var snapshot = try #require(model.activeDJSession).broadcast
            snapshot.delivery = .init(snapshotWatermark: watermark + 1)
            snapshot.sessionForecast = nil
            model.applySessionBroadcastSnapshot(snapshot)
        }
        #expect(model.forecastAuthorityGeneration != originalAuthority)
        gate.release(); await task.value
        #expect(model.visibleSessionForecast(at: Date()) == nil, "A held owner read cannot undo newer live withdrawal")
        #expect(model.askDJDraft == "Keep this unsent question")
        #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
        return
    }
    if fence == "disconnect-during-read" {
        let snapshot = try #require(model.activeDJSession).broadcast
        model.sessionBroadcastDidDisconnect()
        model.applySessionBroadcastSnapshot(snapshot)
        await model.refreshSessionForecast()
        #expect(fixture.requests.filter { $0.url?.path.hasSuffix("/session/forecast/" + id) == true }.count == 2)
        #expect(model.visibleSessionForecast(at: Date()) != nil)
        gate.release(); await task.value
        #expect(model.visibleSessionForecast(at: Date()) != nil)
        #expect(model.askDJDraft == "Keep this unsent question")
        #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
        return
    }
    if fence == "context-read-replacement" {
        runtimeReplies.replace(runtimeReply)
        projection["revision"] = (projection["revision"] as? Int ?? 0) + 1
        response["forecast"] = projection
        forecastReplies.replace(try historyData(response))
        let latest = try await fixture.client().activeSession()
        model.applySessionBroadcastSnapshot(try #require(latest.resolvedSession).personaSafeBroadcast)
        await model.refreshSessionForecast()
        #expect(fixture.requests.filter { $0.url?.path.hasSuffix("/session/forecast/" + id) == true }.count == 2)
        #expect(model.visibleSessionForecast(at: Date())?.revision == projection["revision"] as? Int)
        gate.release(); await task.value
        #expect(model.visibleSessionForecast(at: Date())?.revision == projection["revision"] as? Int)
        #expect(model.askDJDraft == "Keep this unsent question")
        #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
        return
    }
    if fence == "background" { model.markInactiveSession(); gate.release() }
    if fence == "owner-reset" { model.sessionHistory.reset(); gate.release() }
    if fence == "unsequenced-live-during-read" {
        model.applySessionBroadcastEvent(.init(eventType: "playback_updated", sessionID: id, payload: .init()))
        gate.release()
    }
    await task.value
    #expect(model.askDJDraft == "Keep this unsent question")
    #expect((model.visibleSessionForecast(at: Date()) == nil) == ["background", "owner-reset", "unsequenced-live-during-read"].contains(fence))
    if fence == "sequenced-withdrawal-equal-read" {
        let floor = try #require(model.forecastCursor?.revisionFloor)
        let watermark = model.activeDJSession?.broadcast.delivery?.snapshotWatermark ?? 0
        var event = DJConnectSessionBroadcastEvent(eventType: "forecast_changed", sessionID: id, payload: .init())
        event.deliverySequence = watermark + 1
        model.applySessionBroadcastEvent(event)
        let deniedAuthority = model.forecastAuthorityGeneration
        await model.refreshSessionForecast()
        #expect(model.forecastCursor?.revisionFloor == floor)
        #expect(model.visibleSessionForecast(at: Date()) == nil)
        #expect(model.forecastAuthorityGeneration == deniedAuthority, "An equal owner reply must not restart the task repeatedly")
        #expect(!model.forecastLoading)
    }
    if fence == "transport-recovery" {
        let original = try #require(model.visibleSessionForecast(at: Date()))
        let snapshot = try #require(model.activeDJSession).broadcast
        model.stopSessionBroadcast()
        #expect(model.visibleSessionForecast(at: Date()) == nil)
        model.applySessionBroadcastSnapshot(snapshot)
        await model.refreshSessionForecast()
        #expect(model.visibleSessionForecast(at: Date()) == original)
    }
    if fence == "unsequenced-live" {
        model.applySessionBroadcastEvent(.init(eventType: "playback_updated", sessionID: id, payload: .init()))
        #expect(model.forecastCursor?.projection == nil)
        #expect(model.visibleSessionForecast(at: Date()) == nil)
        #expect(model.askDJDraft == "Keep this unsent question")
    }
    if fence.hasPrefix("context-") || fence == "persona-conflict" {
        runtimeReplies.replace(runtimeReply)
        let latest = try await fixture.client().activeSession()
        model.applySessionBroadcastSnapshot(try #require(latest.resolvedSession).personaSafeBroadcast)
        #expect(model.activeDJSession?.id == id)
        if fence == "persona-conflict" { #expect(model.activeDJSession?.confirmedPersona == nil) }
        #expect(model.visibleSessionForecast(at: Date()) == nil)
        forecastReplies.replace(forecastReply)
        await model.refreshSessionForecast()
        #expect(model.visibleSessionForecast(at: Date()) == nil)
        if fence.hasPrefix("context-") {
            projection["revision"] = (try #require((try JSONSerialization.jsonObject(with: originalForecastReply) as? [String: Any])?["forecast"] as? [String: Any])["revision"] as? Int ?? 0) + 1
            response["forecast"] = projection
            forecastReplies.replace(try historyData(response))
            await model.refreshSessionForecast()
            #expect(model.visibleSessionForecast(at: Date()) != nil)
        }
        #expect(model.askDJDraft == "Keep this unsent question")
    }
    #if os(macOS)
    if fence == "current", let directory = ProcessInfo.processInfo.environment["DJCONNECT_FORECAST_NATIVE_DIR"] {
        try await qualifyForecastNativeSwitch(model: model, directory: directory)
    }
    if keyboardProbe, let directory = ProcessInfo.processInfo.environment["DJCONNECT_FORECAST_KEYBOARD_DIR"] {
        try await qualifyForecastNativeKeyboard(model: model, directory: directory)
    }
    if fence == "current", let directory = ProcessInfo.processInfo.environment["DJCONNECT_FORECAST_SCROLL_DIR"] {
        try await qualifyForecastNativeScroll(model: model, directory: directory)
    }
    if fence == "current", let directory = ProcessInfo.processInfo.environment["DJCONNECT_FORECAST_ACCESSIBILITY_DIR"] {
        try await recordForecastNativeAccessibility(model: model, directory: directory)
    }
    if fence == "current", let directory = ProcessInfo.processInfo.environment["DJCONNECT_FORECAST_FILTER_DIR"] {
        try await qualifyForecastNativeFilter(model: model, directory: directory)
    }
    if fence == "current", let directory = ProcessInfo.processInfo.environment["DJCONNECT_FORECAST_WITHDRAWAL_DIR"] {
        try await qualifyForecastNativeWithdrawal(model: model, directory: directory,
            readCount: { fixture.requests.filter { $0.url!.path.contains("/session/forecast/") }.count })
    }
    if nativeExpiryProbe, let directory = ProcessInfo.processInfo.environment["DJCONNECT_FORECAST_EXPIRY_DIR"] {
        try await qualifyForecastNativeExpiry(model: model, directory: directory,
            readCount: { fixture.requests.filter { $0.url!.path.contains("/session/forecast/") }.count })
    }
    if populatedFlowProbe, let directory = ProcessInfo.processInfo.environment["DJCONNECT_POPULATED_FLOW_DIR"] {
        try await recordPopulatedFlowNativePosition(model: model, directory: directory)
    }
    #endif
    #expect(fixture.requests.allSatisfy { $0.httpMethod == "GET" && !$0.url!.path.contains("/command") && !$0.url!.path.contains("/message") })
}

#if os(macOS)
/// Own offscreen test window can receive native key-equivalent dispatch without
/// injecting system keyboard events or opening an ordinary installed app.
@MainActor private final class ForecastKeyboardWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

@MainActor private func qualifyForecastNativeKeyboard(model: DJConnectAppModel, directory: String) async throws {
    let session = try #require(model.activeDJSession)
    #expect(model.sessionHistory.searchAvailable)
    _ = NSApplication.shared
    let view = NavigationStack { ForecastNativeHost(model: model, sessionID: session.id) }
        .environment(\.scenePhase, .active).environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark).frame(width: 600, height: 900)
    let host = NSHostingView(rootView: view)
    let window = ForecastKeyboardWindow(contentRect: CGRect(x: -2000, y: -2000, width: 600, height: 900),
        styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.isReleasedWhenClosed = false; window.contentView = host
    window.orderBack(nil); window.makeKey()
    defer { window.close() }
    let folder = URL(fileURLWithPath: directory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    func field(_ key: String) -> NSTextField? {
        let prompt = DJConnectLocalization.localized(key: key, language: model.language)
        return descendants(host).compactMap { $0 as? NSTextField }.first { $0.placeholderString == prompt }
    }
    func capture(_ name: String) throws {
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        let image = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: image)
        try #require(image.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent(name + ".png"))
    }
    func commandF() throws {
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: "f", charactersIgnoringModifiers: "f", isARepeat: false, keyCode: 3))
        #expect(window.performKeyEquivalent(with: event), "The native window must handle Command-F")
    }
    try await Task.sleep(for: .milliseconds(500))
    host.layoutSubtreeIfNeeded()
    let picker = try #require(descendants(host).compactMap { $0 as? NSSegmentedControl }.first { $0.segmentCount == 2 })
    let action = try #require(picker.action)
    picker.selectedSegment = 1
    #expect(NSApp.sendAction(action, to: picker.target, from: picker))
    for _ in 0..<30 where field("ui.session.forecast.search") == nil { try await Task.sleep(for: .milliseconds(50)) }
    let forecast = try #require(field("ui.session.forecast.search"))
    forecast.stringValue = "Catalog"
    forecast.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: forecast))
    try capture("keyboard-01-forecast")
    try commandF()
    for _ in 0..<30 where picker.selectedSegment != 0 || field("ui.session.history.search") == nil {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(picker.selectedSegment == 0)
    let flow = try #require(field("ui.session.history.search"), "Command-F must expose the actual Flow search field")
    // Mounting the field may precede AppKit's asynchronous focus bridge.
    for _ in 0..<30 where flow.currentEditor() == nil || window.firstResponder !== flow.currentEditor() {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(flow.currentEditor() != nil && window.firstResponder === flow.currentEditor(), "Visible Flow search must own native text focus")
    #expect(model.askDJDraft == "Keep this unsent question")
    try capture("keyboard-02-flow-search")
    picker.selectedSegment = 1
    #expect(NSApp.sendAction(action, to: picker.target, from: picker))
    for _ in 0..<30 where field("ui.session.forecast.search") == nil { try await Task.sleep(for: .milliseconds(50)) }
    #expect(field("ui.session.forecast.search")?.stringValue == "Catalog")
    try commandF() // An already-open Flow search must be restored, not closed.
    for _ in 0..<30 where picker.selectedSegment != 0 { try await Task.sleep(for: .milliseconds(50)) }
    #expect(picker.selectedSegment == 0 && field("ui.session.history.search") != nil)
    try commandF() // In Flow, the same shortcut retains its ordinary close action.
    for _ in 0..<30 where field("ui.session.history.search") != nil { try await Task.sleep(for: .milliseconds(50)) }
    #expect(field("ui.session.history.search") == nil)
    #expect(model.askDJDraft == "Keep this unsent question")
    #expect(model.activeDJSession?.id == session.id)
    #expect(model.activeDJSession?.broadcast.playback == session.broadcast.playback)
    try capture("keyboard-03-flow-search-closed")
}

/// Native end-of-content restoration is a semantic boundary check, not an
/// arbitrary pixel-offset promise or physical wheel/trackpad qualification.
@MainActor private func qualifyForecastNativeScroll(model: DJConnectAppModel, directory: String) async throws {
    let session = try #require(model.activeDJSession)
    _ = NSApplication.shared
    let view = ForecastNativeHost(model: model, sessionID: session.id)
        .environment(\.scenePhase, .active).environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark).frame(width: 600, height: 900)
    let host = NSHostingView(rootView: view)
    let window = NSWindow(contentRect: CGRect(x: -2000, y: -2000, width: 600, height: 900),
        styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.isReleasedWhenClosed = false; window.contentView = host; window.orderBack(nil)
    defer { window.close() }
    let folder = URL(fileURLWithPath: directory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    func forecastField() -> NSTextField? {
        let prompt = DJConnectLocalization.localized(key: "ui.session.forecast.search", language: model.language)
        return descendants(host).compactMap { $0 as? NSTextField }.first { $0.placeholderString == prompt }
    }
    func capture(_ name: String) throws {
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        let image = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: image)
        try #require(image.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent(name + ".png"))
    }
    func limit(_ scroll: NSScrollView) -> CGFloat {
        max(0, (scroll.documentView?.bounds.height ?? 0) - scroll.contentView.bounds.height)
    }
    try await Task.sleep(for: .milliseconds(400))
    host.layoutSubtreeIfNeeded()
    let picker = try #require(descendants(host).compactMap { $0 as? NSSegmentedControl }.first { $0.segmentCount == 2 })
    let action = try #require(picker.action)
    let flow = try #require(descendants(host).compactMap { $0 as? NSScrollView }
        .filter { !($0.documentView is NSTextView) }.max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height })
    let originalFlowOffset = flow.contentView.bounds.origin
    picker.selectedSegment = 1
    #expect(NSApp.sendAction(action, to: picker.target, from: picker))
    for _ in 0..<30 where forecastField() == nil { try await Task.sleep(for: .milliseconds(50)) }
    let scroll = try #require(forecastField()?.enclosingScrollView, "Locate the Forecast's actual native scroll container")
    host.layoutSubtreeIfNeeded()
    let bottom = limit(scroll)
    #expect(bottom > 100, "The fixture must have genuinely scrollable Forecast content")
    scroll.contentView.scroll(to: NSPoint(x: 0, y: bottom))
    scroll.reflectScrolledClipView(scroll.contentView)
    try await Task.sleep(for: .milliseconds(250))
    #expect(scroll.contentView.bounds.origin.y >= bottom - 4)
    try capture("scroll-01-forecast-end")
    picker.selectedSegment = 0
    #expect(NSApp.sendAction(action, to: picker.target, from: picker))
    for _ in 0..<30 where forecastField() != nil { try await Task.sleep(for: .milliseconds(50)) }
    #expect(abs(flow.contentView.bounds.origin.y - originalFlowOffset.y) < 4)
    #expect(model.askDJDraft == "Keep this unsent question")
    try capture("scroll-02-flow-independent")
    picker.selectedSegment = 1
    #expect(NSApp.sendAction(action, to: picker.target, from: picker))
    for _ in 0..<30 where forecastField() == nil { try await Task.sleep(for: .milliseconds(50)) }
    let restored = try #require(forecastField()?.enclosingScrollView)
    for _ in 0..<30 where restored.contentView.bounds.origin.y < limit(restored) - 4 {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(limit(restored) > 100)
    #expect(restored.contentView.bounds.origin.y >= limit(restored) - 4,
            "Returning to Forecast must restore its end-of-content position")
    #expect(model.askDJDraft == "Keep this unsent question")
    #expect(model.activeDJSession?.id == session.id)
    #expect(model.activeDJSession?.broadcast.playback == session.broadcast.playback)
    try capture("scroll-03-forecast-restored")
    let metrics: [String: Any] = ["forecast_max_offset": Double(bottom),
        "forecast_original_end": Double(scroll.contentView.bounds.origin.y),
        "forecast_restored_offset": Double(restored.contentView.bounds.origin.y),
        "forecast_restored_max": Double(limit(restored)),
        "flow_initial_offset": Double(originalFlowOffset.y), "flow_return_offset": Double(flow.contentView.bounds.origin.y)]
    try JSONSerialization.data(withJSONObject: metrics, options: [.sortedKeys, .prettyPrinted])
        .write(to: folder.appendingPathComponent("native-scroll-metrics.json"))
}

/// Retained producer rows render natively, but synthetic wheel input may be
/// unavailable offscreen. Zero offset must never count as a position PASS.
@MainActor private func recordPopulatedFlowNativePosition(model: DJConnectAppModel, directory: String) async throws {
    let session = try #require(model.activeDJSession)
    _ = NSApplication.shared
    let view = ForecastNativeHost(model: model, sessionID: session.id)
        .environment(\.scenePhase, .active).environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark).frame(width: 600, height: 900)
    let host = NSHostingView(rootView: view)
    let window = NSWindow(contentRect: CGRect(x: -2000, y: -2000, width: 600, height: 900),
        styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.isReleasedWhenClosed = false; window.contentView = host; window.orderBack(nil)
    defer { window.close() }
    let folder = URL(fileURLWithPath: directory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    func search() -> NSTextField? {
        let prompt = DJConnectLocalization.localized(key: "ui.session.forecast.search", language: model.language)
        return descendants(host).compactMap { $0 as? NSTextField }.first { $0.placeholderString == prompt }
    }
    func capture(_ name: String) throws {
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        let image = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: image)
        try #require(image.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent(name + ".png"))
    }
    for _ in 0..<40 where model.sessionHistory.timelines[session.id]?.entries.count != 6 {
        try await Task.sleep(for: .milliseconds(50))
    }
    let timeline = try #require(model.sessionHistory.timelines[session.id])
    #expect(timeline.entries.count == 6 && timeline.errorKey == nil)
    #expect(timeline.entries.allSatisfy { $0.isRetained() })
    let entries = timeline.entries.map(\.id)
    try await Task.sleep(for: .milliseconds(200))
    host.layoutSubtreeIfNeeded()
    let flow = try #require(descendants(host).compactMap { $0 as? NSScrollView }
        .filter { !($0.documentView is NSTextView) }.max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height })
    let maximum = max(0, (flow.documentView?.bounds.height ?? 0) - flow.contentView.bounds.height)
    #expect(maximum > 150, "The admitted populated Flow must be genuinely scrollable")
    let wheel = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
        wheel1: -400, wheel2: 0, wheel3: 0))
    wheel.location = CGPoint(x: 300, y: 450)
    let event = try #require(NSEvent(cgEvent: wheel))
    window.sendEvent(event)
    try await Task.sleep(for: .milliseconds(250))
    let position = flow.contentView.bounds.origin.y
    let inputAvailable = position > 100
    try capture("populated-flow-01-before-switch")
    let picker = try #require(descendants(host).compactMap { $0 as? NSSegmentedControl }.first { $0.segmentCount == 2 })
    let action = try #require(picker.action)
    picker.selectedSegment = 1
    #expect(NSApp.sendAction(action, to: picker.target, from: picker))
    for _ in 0..<30 where search() == nil { try await Task.sleep(for: .milliseconds(50)) }
    _ = try #require(search())
    try capture("populated-flow-02-forecast")
    picker.selectedSegment = 0
    #expect(NSApp.sendAction(action, to: picker.target, from: picker))
    for _ in 0..<30 where search() != nil { try await Task.sleep(for: .milliseconds(50)) }
    try await Task.sleep(for: .milliseconds(150))
    let returnedFlow = try #require(descendants(host).compactMap { $0 as? NSScrollView }
        .filter { !($0.documentView is NSTextView) }.max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height })
    if inputAvailable { #expect(abs(returnedFlow.contentView.bounds.origin.y - position) < 4) }
    #expect(model.sessionHistory.timelines[session.id]?.entries.map(\.id) == entries)
    #expect(model.sessionHistory.timelines[session.id]?.errorKey == nil)
    #expect(model.askDJDraft == "Keep this unsent question")
    #expect(model.activeDJSession?.id == session.id)
    #expect(model.activeDJSession?.broadcast.playback == session.broadcast.playback)
    try capture("populated-flow-03-return")
    try JSONSerialization.data(withJSONObject: ["qualification": inputAvailable ? "NONZERO_POSITION_CHECK_AVAILABLE" : "INCONCLUSIVE_NATIVE_WHEEL_INPUT",
        "synthetic_wheel_window_number": event.windowNumber, "host_window_number": window.windowNumber,
        "scrolling_delta_y": event.scrollingDeltaY, "entry_ids": entries, "maximum_offset": Double(maximum),
        "reading_offset": Double(position), "return_offset": Double(returnedFlow.contentView.bounds.origin.y), "same_native_container": returnedFlow === flow],
        options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("native-populated-flow-metrics.json"))
}

/// Let the production panel's expiry schedule run against an actual short
/// synthetic lease. No clock injection, forced refresh, or owner withdrawal.
@MainActor private func qualifyForecastNativeExpiry(model: DJConnectAppModel, directory: String, readCount: () -> Int) async throws {
    let session = try #require(model.activeDJSession)
    let projection = try #require(model.visibleSessionForecast(at: Date()))
    let validity = try #require(projection.valid_until)
    let deadline = try #require(DJConnectSessionForecast.timestamp(validity))
    let epoch = model.sessionHistory.responseEpoch
    _ = NSApplication.shared
    let view = SessionForecastPanel(model: model, viewport: SessionForecastViewport(), query: .constant("")) { EmptyView() }
        .background(DJConnectCanvasBackground())
        .environment(\.scenePhase, .active).environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark).frame(width: 600, height: 1000)
    let host = NSHostingView(rootView: view)
    let window = NSWindow(contentRect: CGRect(x: -2000, y: -2000, width: 600, height: 1000),
        styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.isReleasedWhenClosed = false; window.contentView = host; window.orderBack(nil)
    defer { window.close() }
    let folder = URL(fileURLWithPath: directory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    func capture(_ name: String) throws {
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        let image = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: image)
        try #require(image.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent(name + ".png"))
    }
    try await Task.sleep(for: .milliseconds(400))
    #expect(Date() < deadline)
    #expect(model.visibleSessionForecast(at: Date()) != nil)
    try capture("expiry-01-current")
    let reads = readCount()
    let wait = deadline.timeIntervalSinceNow + 0.4
    #expect(wait > 0 && wait < 8, "The native expiry probe must stay bounded")
    try await Task.sleep(for: .seconds(max(0.2, min(8, wait))))
    // Capture first: the assertion below must not be responsible for changing
    // the panel from authored content to its expired/unavailable presentation.
    try capture("expiry-02-expired")
    #expect(Date() > deadline)
    #expect(model.visibleSessionForecast(at: Date()) == nil)
    #expect(model.sessionHistory.hasAuthorizedOwner && model.canRefreshSessionForecast)
    #expect(model.sessionHistory.responseEpoch == epoch)
    #expect(readCount() == reads)
    #expect(model.askDJDraft == "Keep this unsent question")
    #expect(model.activeDJSession?.id == session.id)
    #expect(model.activeDJSession?.broadcast.playback == session.broadcast.playback)
    try JSONSerialization.data(withJSONObject: ["valid_until": validity,
        "captured_after": ISO8601DateFormatter().string(from: Date()), "owner_retained": model.sessionHistory.hasAuthorizedOwner,
        "refresh_admitted": model.canRefreshSessionForecast, "forecast_reads_before": reads, "forecast_reads_after": readCount()],
        options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("native-expiry-metrics.json"))
}

/// Actual production panel and native captures of owner withdrawal. Its custom
/// SwiftUI retry style has no NSButton bridge; do not claim native AX state.
@MainActor private func qualifyForecastNativeWithdrawal(model: DJConnectAppModel, directory: String, readCount: () -> Int) async throws {
    let session = try #require(model.activeDJSession)
    #expect(model.sessionHistory.hasAuthorizedOwner)
    #expect(model.canRefreshSessionForecast)
    #expect(model.visibleSessionForecast(at: Date()) != nil)
    _ = NSApplication.shared
    let view = SessionForecastPanel(model: model, viewport: SessionForecastViewport(), query: .constant("")) { EmptyView() }
        .environment(\.scenePhase, .active).environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark).frame(width: 600, height: 1000)
    let host = NSHostingView(rootView: view)
    let window = NSWindow(contentRect: CGRect(x: -2000, y: -2000, width: 600, height: 1000),
        styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.isReleasedWhenClosed = false; window.contentView = host; window.orderBack(nil)
    defer { window.close() }
    let folder = URL(fileURLWithPath: directory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    func capture(_ name: String) throws {
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        let image = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: image)
        try #require(image.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent(name + ".png"))
    }
    try await Task.sleep(for: .milliseconds(400))
    try capture("withdrawal-01-authorized")
    let reads = readCount()
    model.sessionHistory.suspend()
    #expect(!model.sessionHistory.hasAuthorizedOwner)
    #expect(!model.canRefreshSessionForecast)
    #expect(model.visibleSessionForecast(at: Date()) == nil)
    try await Task.sleep(for: .milliseconds(250))
    host.layoutSubtreeIfNeeded()
    try capture("withdrawal-02-owner-suspended")
    let nativeControls = descendants(host).compactMap { view -> [String: Any]? in
        guard let control = view as? NSControl else { return nil }
        return ["type": String(describing: type(of: control)), "enabled": control.isEnabled]
    }
    try JSONSerialization.data(withJSONObject: ["read_admitted_after_withdrawal": model.canRefreshSessionForecast, "native_controls": nativeControls, "forecast_reads_before": reads,
        "forecast_reads_after": readCount()], options: [.prettyPrinted, .sortedKeys])
        .write(to: folder.appendingPathComponent("native-withdrawal-metrics.json"))
    #expect(readCount() == reads)
    #expect(model.askDJDraft == "Keep this unsent question")
    #expect(model.activeDJSession?.id == session.id)
    #expect(model.activeDJSession?.broadcast.playback == session.broadcast.playback)
    await model.sessionHistory.prepare()
    for _ in 0..<30 where model.visibleSessionForecast(at: Date()) == nil { try await Task.sleep(for: .milliseconds(50)) }
    #expect(model.canRefreshSessionForecast)
    #expect(model.visibleSessionForecast(at: Date()) != nil)
    #expect(model.askDJDraft == "Keep this unsent question")
    #expect(model.activeDJSession?.id == session.id)
    #expect(model.activeDJSession?.broadcast.playback == session.broadcast.playback)
    try capture("withdrawal-03-owner-restored")
}

/// Filter only authored presentation; the producer projection and playback
/// remain unchanged. Native screenshots complement the text-selection bridges.
@MainActor private func qualifyForecastNativeFilter(model: DJConnectAppModel, directory: String) async throws {
    let session = try #require(model.activeDJSession)
    let projection = try #require(model.visibleSessionForecast(at: Date()))
    _ = NSApplication.shared
    let view = ForecastNativeHost(model: model, sessionID: session.id)
        .environment(\.scenePhase, .active).environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark).frame(width: 600, height: 1400)
    let host = NSHostingView(rootView: view)
    let window = NSWindow(contentRect: CGRect(x: -2000, y: -2000, width: 600, height: 1400),
        styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.isReleasedWhenClosed = false; window.contentView = host; window.orderBack(nil)
    defer { window.close() }
    let folder = URL(fileURLWithPath: directory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    func search() -> NSTextField? {
        let prompt = DJConnectLocalization.localized(key: "ui.session.forecast.search", language: model.language)
        return descendants(host).compactMap { $0 as? NSTextField }.first { $0.placeholderString == prompt }
    }
    func capture(_ name: String) throws {
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        let image = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: image)
        try #require(image.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent(name + ".png"))
        let nativeText = descendants(host).compactMap { view -> String? in
            if let text = view as? NSTextView { return text.string }
            return nil
        }
        try JSONSerialization.data(withJSONObject: ["query": search()?.stringValue ?? "", "native_selectable_text": nativeText], options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent(name + ".json"))
    }
    try await Task.sleep(for: .milliseconds(400))
    let picker = try #require(descendants(host).compactMap { $0 as? NSSegmentedControl }.first { $0.segmentCount == 2 })
    let action = try #require(picker.action)
    picker.selectedSegment = 1
    #expect(NSApp.sendAction(action, to: picker.target, from: picker))
    for _ in 0..<30 where search() == nil { try await Task.sleep(for: .milliseconds(50)) }
    _ = try #require(search())
    try capture("filter-01-all")
    for (query, name) in [("STEADY", "filter-02-body-match"), ("MINUTES", "filter-03-title-match"), ("zz-no-authored-match-zz", "filter-04-none"), ("", "filter-05-cleared")] {
        let field = try #require(search())
        field.stringValue = query
        field.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: field))
        try await Task.sleep(for: .milliseconds(150))
        #expect(search()?.stringValue == query)
        #expect(model.visibleSessionForecast(at: Date()) == projection)
        #expect(model.askDJDraft == "Keep this unsent question")
        #expect(model.activeDJSession?.id == session.id)
        #expect(model.activeDJSession?.broadcast.playback == session.broadcast.playback)
        try capture(name)
    }
}

/// Read this isolated host's public accessibility tree, without system VoiceOver
/// or cross-process accessibility access. Spoken traversal remains unqualified.
@MainActor private func recordForecastNativeAccessibility(model: DJConnectAppModel, directory: String) async throws {
    let session = try #require(model.activeDJSession)
    _ = NSApplication.shared
    let view = ForecastNativeHost(model: model, sessionID: session.id)
        .environment(\.scenePhase, .active).environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark).frame(width: 600, height: 900)
    let host = NSHostingView(rootView: view)
    let window = NSWindow(contentRect: CGRect(x: -2000, y: -2000, width: 600, height: 900),
        styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.isReleasedWhenClosed = false; window.contentView = host; window.orderBack(nil)
    defer { window.close() }
    let folder = URL(fileURLWithPath: directory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    func snapshot(_ name: String) throws {
        host.layoutSubtreeIfNeeded()
        var seen = Set<ObjectIdentifier>()
        func tree(_ object: AnyObject, depth: Int = 0) -> [[String: Any]] {
            guard depth < 40, seen.insert(ObjectIdentifier(object)).inserted else { return [] }
            var row: [String: Any] = ["depth": depth, "type": String(describing: type(of: object))]
            // SwiftUI's virtual accessibility nodes need not declare the complete
            // AppKit protocol. Query only public object-valued selectors they expose.
            func attribute(_ name: String) -> Any? {
                guard let node = object as? NSObject else { return nil }
                let selector = NSSelectorFromString(name)
                guard node.responds(to: selector) else { return nil }
                return node.perform(selector)?.takeUnretainedValue()
            }
            for key in ["Role", "Label", "Value", "Identifier"] {
                row[key.lowercased()] = attribute("accessibility" + key).map { String(describing: $0) }
            }
            let children = attribute("accessibilityChildren") as? [AnyObject] ?? []
            row["child_count"] = children.count
            return [row] + children.flatMap { tree($0, depth: depth + 1) }
        }
        let rows = tree(host)
        // A test-only offscreen hosting view may not vend virtual SwiftUI
        // children. Preserve that limitation rather than claiming full traversal.
        let controls: [[String: Any]] = descendants(host).compactMap { view in
            guard view is NSControl else { return nil }
            var row: [String: Any] = ["type": String(describing: type(of: view)),
                "role": view.accessibilityRole()?.rawValue ?? "", "label": view.accessibilityLabel() ?? "",
                "exposed": view.isAccessibilityElement(), "hidden": view.isHiddenOrHasHiddenAncestor]
            if let field = view as? NSTextField {
                row["placeholder"] = field.placeholderString ?? ""
                row["text"] = field.stringValue
            }
            if let segmented = view as? NSSegmentedControl {
                row["segments"] = (0..<segmented.segmentCount).map { segmented.label(forSegment: $0) ?? "" }
                row["selection"] = segmented.selectedSegment
            }
            return row
        }
        try JSONSerialization.data(withJSONObject: ["qualification": "INCONCLUSIVE_HOST_ACCESSIBILITY_TREE", "public_tree": rows, "native_controls": controls], options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent(name + ".json"))
    }
    try await Task.sleep(for: .milliseconds(400))
    try snapshot("accessibility-01-flow")
    let picker = try #require(descendants(host).compactMap { $0 as? NSSegmentedControl }.first { $0.segmentCount == 2 })
    picker.selectedSegment = 1
    #expect(NSApp.sendAction(try #require(picker.action), to: picker.target, from: picker))
    try await Task.sleep(for: .milliseconds(300))
    try snapshot("accessibility-02-forecast")
    picker.selectedSegment = 0
    #expect(NSApp.sendAction(try #require(picker.action), to: picker.target, from: picker))
    try await Task.sleep(for: .milliseconds(150))
    try snapshot("accessibility-03-flow-return")
    #expect(model.askDJDraft == "Keep this unsent question")
    #expect(model.activeDJSession?.id == session.id)
    #expect(model.activeDJSession?.broadcast.playback == session.broadcast.playback)
}

@MainActor private final class ForecastNativeOpenedURLs {
    var values: [URL] = []
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_FORECAST_NATIVE_DIR"] != nil)) @MainActor
func forecastNativeSourceLinkOpensOnlyProducerDestination() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let rows = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/session-forecast-core-3cfa5512.json"))) as? [[String: Any]])
    let response = try JSONDecoder().decode(DJConnectSessionForecastResponse.self,
        from: historyData(try #require(rows.first?["owner_read"])))
    let projection = response.forecast
    #expect(projection.structurallyValid)
    let urls = projection.sections.compactMap { $0.source_url.flatMap(URL.init(string:)) }
    #expect(urls.count == 1)
    let opened = ForecastNativeOpenedURLs()
    _ = NSApplication.shared
    let view = SessionForecastTextView(projection: projection, language: "en")
        .environment(\.openURL, OpenURLAction { url in
            opened.values.append(url)
            return .handled // No system/browser launch or external request.
        })
        .environment(\.colorScheme, .dark).preferredColorScheme(.dark)
        .foregroundStyle(.white).padding(20).frame(width: 430, height: 900)
    let host = NSHostingView(rootView: view)
    let window = NSWindow(contentRect: CGRect(x: -2000, y: -2000, width: 430, height: 900),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.isReleasedWhenClosed = false; window.contentView = host; window.orderBack(nil)
    defer { window.close() }
    try await Task.sleep(for: .milliseconds(350))
    host.layoutSubtreeIfNeeded()
    func descendants(_ root: NSView) -> [NSView] { [root] + root.subviews.flatMap(descendants) }
    // This isolated component contains exactly one Link and no other buttons.
    // Its sole native bridge is identifiable without guessing an empty label.
    let buttons = descendants(host).compactMap { $0 as? NSButton }
    #expect(buttons.count == urls.count)
    let source = try #require(buttons.count == 1 ? buttons.first : nil)
    source.performClick(nil)
    for _ in 0..<30 where opened.values.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
    #expect(opened.values == urls)
    let directory = try #require(ProcessInfo.processInfo.environment["DJCONNECT_FORECAST_NATIVE_DIR"])
    let folder = URL(fileURLWithPath: directory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let image = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: image)
    try #require(image.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent("isolated-source-link.png"))
}

@MainActor private struct ForecastNativeHost: View {
    @ObservedObject var model: DJConnectAppModel
    let sessionID: String
    var body: some View {
        SessionTimelineScreen(model: model, sessionID: sessionID, activeSession: model.activeDJSession)
    }
}

/// Explicit local test window with synthetic paired transport; no ordinary app launch.
@MainActor private func qualifyForecastNativeSwitch(model: DJConnectAppModel, directory: String) async throws {
    let session = try #require(model.activeDJSession)
    let folder = URL(fileURLWithPath: directory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    _ = NSApplication.shared
    let view = ForecastNativeHost(model: model, sessionID: session.id)
        .environment(\.scenePhase, .active).environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .frame(width: 430, height: 900)
    let host = NSHostingView(rootView: view)
    let window = NSWindow(contentRect: CGRect(x: -2000, y: -2000, width: 430, height: 900),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.isReleasedWhenClosed = false; window.contentView = host; window.orderBack(nil)
    defer { window.close() }
    func descendants(_ root: NSView) -> [NSView] { [root] + root.subviews.flatMap(descendants) }
    func forecastSearch() -> NSTextField? {
        let placeholder = DJConnectLocalization.localized(key: "ui.session.forecast.search", language: model.language)
        return descendants(host).compactMap { $0 as? NSTextField }.first { $0.placeholderString == placeholder }
    }
    func hasPanel() -> Bool { forecastSearch() != nil }
    func capture(_ name: String) throws {
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        let image = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: image)
        let data = try #require(image.representation(using: .png, properties: [:]))
        try data.write(to: folder.appendingPathComponent(name + ".png"))
    }
    try await Task.sleep(for: .milliseconds(350))
    host.layoutSubtreeIfNeeded()
    let picker = try #require(descendants(host).compactMap { $0 as? NSSegmentedControl }.first { $0.segmentCount == 2 })
    #expect(picker.selectedSegment == 0 && !hasPanel())
    try capture("flow-before")
    picker.selectedSegment = 1
    let action = try #require(picker.action)
    #expect(NSApp.sendAction(action, to: picker.target, from: picker))
    for _ in 0..<30 where !hasPanel() { try await Task.sleep(for: .milliseconds(50)) }
    #expect(picker.selectedSegment == 1 && hasPanel())
    let search = try #require(forecastSearch())
    search.stringValue = "Catalog"
    search.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: search))
    #expect(model.askDJDraft == "Keep this unsent question")
    try capture("forecast-selected")
    picker.selectedSegment = 0
    #expect(NSApp.sendAction(action, to: picker.target, from: picker))
    for _ in 0..<30 where hasPanel() { try await Task.sleep(for: .milliseconds(50)) }
    #expect(picker.selectedSegment == 0 && !hasPanel())
    #expect(model.askDJDraft == "Keep this unsent question")
    try capture("flow-returned")
    picker.selectedSegment = 1
    #expect(NSApp.sendAction(action, to: picker.target, from: picker))
    for _ in 0..<30 where !hasPanel() { try await Task.sleep(for: .milliseconds(50)) }
    #expect(forecastSearch()?.stringValue == "Catalog")
    #expect(model.askDJDraft == "Keep this unsent question")
    try capture("forecast-restored-search")
    model.applySessionBroadcastEvent(.init(eventType: "runtime_ended", sessionID: session.id, payload: .init()))
    for _ in 0..<30 where hasPanel() { try await Task.sleep(for: .milliseconds(50)) }
    try await Task.sleep(for: .milliseconds(150))
    #expect(model.activeDJSession == nil && !hasPanel())
    #expect(!descendants(host).compactMap { $0 as? NSSegmentedControl }.contains { $0.segmentCount == 2 })
    try capture("ended-session-flow")
}
#endif
