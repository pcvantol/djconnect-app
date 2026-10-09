import Foundation
import Testing
import CryptoKit
import Combine
@testable import DJConnectCore
@testable import DJConnectUI

private func historyFixture(_ name: String = "producer-receipt") throws -> Data {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try Data(contentsOf: root.appendingPathComponent("Fixtures/session-history-" + name + ".json"))
}
private func historyObject(_ name: String = "producer-receipt") throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: historyFixture(name)) as? [String: Any])
}
private func historyData(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value) }

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
    let reply: @Sendable (URLRequest) throws -> (Int, Data, TimeInterval)
    init(reply: @escaping @Sendable (URLRequest) throws -> (Int, Data, TimeInterval)) {
        self.reply = reply; HistoryWireProtocol.register(self)
    }
    func close() { HistoryWireProtocol.unregister(hostname) }
    func record(_ request: URLRequest) { lock.withLock { captured.append(request) } }
    var requests: [URLRequest] { lock.withLock { captured } }
    func client() -> DJConnectClient {
        DJConnectClient(baseURL: baseURL, identity: .init(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Test", clientType: .ios, firmware: "4.0.0-rc.1", platform: .ios),
                        tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-fixture-token"), session: session())
    }
    func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [HistoryWireProtocol.self]
        return URLSession(configuration: config)
    }
    @MainActor func model() -> (DJConnectAppModel, UserDefaults, String) {
        let name = "session-history-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.set(baseURL.absoluteString, forKey: "DJConnectHomeAssistantURL")
        defaults.set(baseURL.absoluteString, forKey: "DJConnectHALocalURL")
        defaults.set("local", forKey: "DJConnectHAConnectionMode")
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
                    headerFields: ["Content-Type": "application/json", "Cache-Control": "no-store"]) else { return }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
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
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if request.url!.path.hasSuffix("/voice") { return (500, Data(#"{"success":false,"error":"voice_failed"}"#.utf8), 0.4) }
        return (200, history, 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
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
    let gate = HistoryAuthorityGate()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, caps, 0) }
        if gate.denied { return (403, Data(#"{"success":false,"error":"invalid_profile","message":"Private denied detail"}"#.utf8), 0) }
        if request.url!.path.hasSuffix("ask_dj/history") { return (200, profile, 0) }
        if request.url!.path.hasSuffix("/session/history") { return (200, sessions, 0) }
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
