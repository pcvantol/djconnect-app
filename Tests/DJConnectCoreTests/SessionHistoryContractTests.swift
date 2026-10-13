import Foundation
import Combine
import Testing
import CryptoKit
import Combine
@testable import DJConnectCore
@testable import DJConnectUI

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
    model.askDJDraft = "Queued before connection loss"
    model.sessionHistory.sendText()
    model.recordConnectionMode(.offline, baseURL: fixture.baseURL)
    try await Task.sleep(for: .milliseconds(100))
    #expect(fixture.requests.allSatisfy { $0.httpMethod != "POST" })
    #expect(!model.isSendingAskDJText && model.sessionHistory.hasAuthorizedOwner)
    let turn = try #require(model.sessionHistory.pendingTurns.first)
    #expect(turn.failed && !turn.contextChanged)
    model.recordConnectionMode(.local, baseURL: fixture.baseURL)
    model.sessionHistory.retry(turn)
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
    #expect(fixture.requests.allSatisfy { $0.httpMethod != "POST" })
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
    for _ in 0..<20 {
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
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, activeMoodCapsWire, 0) }
        if request.url!.path.hasSuffix("/session/active") { return (200, switched.denied ? replacementWire : runtime, 0) }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshActiveDJSession(); await model.refreshActiveMoodCapability()
    let prior = try #require(model.activeDJSession)
    let epoch = model.sessionHistory.responseEpoch
    switched.denied = true
    await model.refreshActiveDJSession()
    #expect(model.activeDJSession?.id == prior.id + "-replacement")
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
    #expect(SessionConnectionStatus.resolve(demo: false, pairing: .paired, mode: .remote, backendAvailable: true, recovering: false, liveUnavailable: false) == .connected)
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
    await model.refreshMusicDNAProfile(retryDelays: [])
    gate.denied = true
    await model.refreshMusicDNAProfile(retryDelays: [.milliseconds(1), .milliseconds(1)])
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
        let body = try #require(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
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
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/capabilities") { return (200, presenceCapsWire, 0) }
        if request.url!.path.hasSuffix("/session/active") { return (200, runtime, 0) }
        if request.url!.path.hasSuffix("/session/presence") {
            let number = script.nextWrite()
            let body = try JSONSerialization.jsonObject(with: presenceRequestBody(request)) as! [String: Any]
            #expect(body["expected_presence_revision"] as? Int == number - 1)
            return (200, try historyData(["success":true,"contract_version":1,"session_id":body["session_id"]!,"selected_presence":body["selected_presence"]!,"presence_revision":number,"changed":true]), 0.10)
        }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshActiveDJSession(); await model.refreshActiveMoodCapability()
    let id = try #require(model.activeDJSession?.id), epoch = model.sessionHistory.responseEpoch
    model.selectActiveSessionPresence(.talkative, expectedSessionID: id, expectedEpoch: epoch)
    try await Task.sleep(for: .milliseconds(20))
    #expect(model.activePresencePending && model.activeDJSession?.confirmedPresence?.selectedPresence == .balanced)
    model.selectActiveSessionPresence(.occasional, expectedSessionID: id, expectedEpoch: epoch)
    model.selectActiveSessionPresence(.musicOnly, expectedSessionID: id, expectedEpoch: epoch)
    model.selectActiveSessionPresence(.presenter, expectedSessionID: id, expectedEpoch: epoch)
    #expect(script.writes == 1 && model.activePresenceDesired == .presenter)
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
    let script = PresenceScript()
    let fixture = HistoryWireFixture { request in
        if request.url!.path.hasSuffix("/session/active") {
            let read = script.nextWrite()
            return (200, read == 1 ? contradiction : read == 2 ? older : newer, 0)
        }
        return (404, Data(), 0)
    }
    defer { fixture.close() }
    let (model, defaults, name) = fixture.model(); defer { defaults.removePersistentDomain(forName: name) }
    await model.refreshActiveDJSession()
    #expect(model.activeDJSession?.confirmedPresence == nil && model.activeDJSession?.presenceRevisionFloor == 4)
    await model.refreshActiveDJSession()
    #expect(model.activeDJSession?.confirmedPresence == nil && model.activeDJSession?.presenceRevisionFloor == 4)
    await model.refreshActiveDJSession()
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
