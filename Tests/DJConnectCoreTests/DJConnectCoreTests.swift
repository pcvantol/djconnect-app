import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handlers: [String: (URLRequest) throws -> (HTTPURLResponse, Data)] = [:]
    private static let lock = NSLock()

    static func setHandler(
        for host: String,
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) {
        lock.lock()
        handlers[host] = handler
        lock.unlock()
    }

    static func handler(for host: String) -> ((URLRequest) throws -> (HTTPURLResponse, Data))? {
        lock.lock()
        let handler = handlers[host]
        lock.unlock()
        return handler
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let host = request.url?.host, let handler = Self.handler(for: host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class ConnectionModeRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [DJConnectHAConnectionMode] = []

    func append(_ mode: DJConnectHAConnectionMode) {
        lock.lock()
        values.append(mode)
        lock.unlock()
    }

    var modes: [DJConnectHAConnectionMode] {
        lock.lock()
        let snapshot = values
        lock.unlock()
        return snapshot
    }
}

private final class RequestPathRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    func append(_ value: String) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    var paths: [String] {
        lock.lock()
        let snapshot = values
        lock.unlock()
        return snapshot
    }
}

private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.withLock { value += 1 }
    }

    var count: Int {
        lock.withLock { value }
    }
}

private final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URLRequest] = []

    func append(_ request: URLRequest) {
        lock.withLock { storage.append(request) }
    }

    var requests: [URLRequest] {
        lock.withLock { storage }
    }
}

private final class SequenceTokenStore: DJConnectTokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var loadResults: [Result<String?, Error>]

    init(loadResults: [Result<String?, Error>]) {
        self.loadResults = loadResults
    }

    func loadToken() throws -> String? {
        try lock.withLock {
            guard !loadResults.isEmpty else {
                return nil
            }
            return try loadResults.removeFirst().get()
        }
    }

    func saveToken(_ token: String) throws {}
    func clearToken() throws {}
}

private actor MockWebSocketFastPathTransport: DJConnectWebSocketFastPathTransport {
    var supportedRoutes: Set<DJConnectFastPathRoute>
    var commandError: Error?
    var askDJError: Error?
    var trackInsightError: Error?
    var vibeCastError: Error?
    var commandCalls = 0
    var askDJCalls = 0
    var askDJHistoryCalls = 0
    var clearAskDJHistoryCalls = 0
    var musicDiscoveryRefreshCalls = 0
    var trackInsightCalls = 0
    var vibeCastCalls = 0
    var receivedTokens: [String] = []
    var receivedCommandPayload: DJConnectCommandPayload?
    var receivedCommandIdentity: DJConnectAPIIdentity?
    var receivedAskPayload: DJConnectAskDJRequest?
    var receivedAskIdentity: DJConnectAPIIdentity?
    var receivedHistorySinceRevision: Int?
    var receivedHistoryIdentity: DJConnectAPIIdentity?
    var receivedClearMusicDNAKey: String?
    var receivedClearIdentity: DJConnectAPIIdentity?
    var receivedMusicDiscoveryMusicDNAKey: String?
    var receivedMusicDiscoveryLanguage: String?
    var receivedMusicDiscoveryIdentity: DJConnectAPIIdentity?
    var receivedTrackPayload: DJConnectTrackInsightRequest?
    var receivedTrackIdentity: DJConnectAPIIdentity?
    var receivedVibeCastPayload: DJConnectVibeCastRequest?
    var receivedVibeCastIdentity: DJConnectAPIIdentity?
    var clearAskDJHistoryResponse = DJConnectAskDJHistoryResponse(historyRevision: 0, clearRevision: 1, messages: [])

    init(supportedRoutes: Set<DJConnectFastPathRoute>) {
        self.supportedRoutes = supportedRoutes
    }

    func setAskDJError(_ error: Error?) {
        askDJError = error
    }

    func setCommandError(_ error: Error?) {
        commandError = error
    }

    func setTrackInsightError(_ error: Error?) {
        trackInsightError = error
    }

    func setVibeCastError(_ error: Error?) {
        vibeCastError = error
    }

    func setClearAskDJHistoryResponse(_ response: DJConnectAskDJHistoryResponse) {
        clearAskDJHistoryResponse = response
    }

    var diagnostics: DJConnectFastPathDiagnostics {
        DJConnectFastPathDiagnostics(
            fastPathTransport: "websocket",
            websocketConnected: true,
            websocketCommands: supportedRoutes.map(\.rawValue).sorted()
        )
    }

    func supports(_ route: DJConnectFastPathRoute) async -> Bool {
        supportedRoutes.contains(route)
    }

    func prepare() async throws {}

    func command<T>(_ payload: DJConnectCommandPayload, identity: DJConnectAPIIdentity, responseType: T.Type) async throws -> T where T: Decodable, T: Sendable {
        commandCalls += 1
        receivedTokens.append(identity.deviceToken ?? "")
        receivedCommandPayload = payload
        receivedCommandIdentity = identity
        if let commandError {
            throw commandError
        }
        guard supportedRoutes.contains(.command) else {
            throw DJConnectError.routeMissing(message: "missing websocket command capability")
        }
        let response = DJConnectCommandResponse(success: true, playback: DJConnectPlayback(hasPlayback: true, isPlaying: true, trackName: "WebSocket Track"))
        let data = try JSONEncoder().encode(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func askDJMessage(_ payload: DJConnectAskDJRequest, identity: DJConnectAPIIdentity) async throws -> DJConnectAskDJMessageResponse {
        askDJCalls += 1
        receivedTokens.append(identity.deviceToken ?? "")
        receivedAskPayload = payload
        receivedAskIdentity = identity
        if let askDJError {
            throw askDJError
        }
        guard supportedRoutes.contains(.askDJMessage) else {
            throw DJConnectError.routeMissing(message: "missing websocket ask dj capability")
        }
        return DJConnectAskDJMessageResponse(
            assistantMessage: DJConnectAskDJHistoryMessage(id: "fast-assistant", role: .assistant, text: "Fast answer", createdAt: Date()),
            text: "Fast answer",
            historyRevision: 12,
            clearRevision: 3
        )
    }

    func askDJHistory(identity: DJConnectAPIIdentity, sinceRevision: Int?) async throws -> DJConnectAskDJHistoryResponse {
        askDJHistoryCalls += 1
        receivedTokens.append(identity.deviceToken ?? "")
        receivedHistorySinceRevision = sinceRevision
        receivedHistoryIdentity = identity
        guard supportedRoutes.contains(.askDJHistory) else {
            throw DJConnectError.routeMissing(message: "missing websocket ask dj history capability")
        }
        return DJConnectAskDJHistoryResponse(historyRevision: sinceRevision ?? 0, clearRevision: 0, messages: [])
    }

    func clearAskDJHistory(identity: DJConnectAPIIdentity, musicDNAKey: String?) async throws -> DJConnectAskDJHistoryResponse {
        clearAskDJHistoryCalls += 1
        receivedTokens.append(identity.deviceToken ?? "")
        receivedClearIdentity = identity
        receivedClearMusicDNAKey = musicDNAKey
        guard supportedRoutes.contains(.askDJHistoryClear) else {
            throw DJConnectError.routeMissing(message: "missing websocket ask dj clear history capability")
        }
        return clearAskDJHistoryResponse
    }

    func refreshMusicDiscovery(identity: DJConnectAPIIdentity, musicDNAKey: String?, language: String?) async throws -> DJConnectMusicDiscoveryResponse {
        musicDiscoveryRefreshCalls += 1
        receivedTokens.append(identity.deviceToken ?? "")
        receivedMusicDiscoveryIdentity = identity
        receivedMusicDiscoveryMusicDNAKey = musicDNAKey
        receivedMusicDiscoveryLanguage = language
        guard supportedRoutes.contains(.musicDiscoveryRefresh) else {
            throw DJConnectError.routeMissing(message: "missing websocket music discovery refresh capability")
        }
        return DJConnectMusicDiscoveryResponse(
            success: true,
            enabled: true,
            revision: 22,
            sections: [
                DJConnectMusicDiscoverySection(
                    id: "fast",
                    title: "Fast",
                    items: [
                        DJConnectMusicDiscoveryItem(
                            id: "fast-track",
                            kind: .track,
                            title: "Fast Discovery",
                            subtitle: "WebSocket",
                            uri: "spotify:track:fast",
                            reason: "Fast path"
                        )
                    ]
                )
            ]
        )
    }

    func trackInsight(_ payload: DJConnectTrackInsightRequest, identity: DJConnectAPIIdentity) async throws -> TrackInsight {
        trackInsightCalls += 1
        receivedTokens.append(identity.deviceToken ?? "")
        receivedTrackPayload = payload
        receivedTrackIdentity = identity
        if let trackInsightError {
            throw trackInsightError
        }
        guard supportedRoutes.contains(.trackInsight) else {
            throw DJConnectError.routeMissing(message: "missing websocket track insight capability")
        }
        return TrackInsight(
            title: payload.title ?? "Fast Track",
            artist: payload.artist ?? "Fast Artist",
            genre: "House",
            summary: "Fast insight",
            rawAnalysisText: "Fast insight"
        )
    }

    func vibeCast(_ payload: DJConnectVibeCastRequest, identity: DJConnectAPIIdentity) async throws -> DJConnectVibeCastResponse {
        vibeCastCalls += 1
        receivedTokens.append(identity.deviceToken ?? "")
        receivedVibeCastPayload = payload
        receivedVibeCastIdentity = identity
        if let vibeCastError {
            throw vibeCastError
        }
        guard supportedRoutes.contains(.vibeCast) else {
            throw DJConnectError.routeMissing(message: "missing websocket vibecast capability")
        }
        return DJConnectVibeCastResponse(
            enabled: true,
            revision: 7,
            ttlSeconds: 45,
            pollAfterSeconds: 20,
            context: .init(trackID: "fast-track", title: "Fast Track", artist: "Fast Artist", musicBackend: "music_assistant"),
            items: [
                .init(
                    id: "fast-fact",
                    kind: .trackFact,
                    tone: "playful",
                    priority: 80,
                    displaySeconds: 8,
                    placementHint: "side",
                    text: [.init(type: .strong, value: "Fast fact")]
                )
            ],
            cache: .init(hit: true)
        )
    }
}

private struct FailingTrackInsightFastPathTransport: DJConnectWebSocketFastPathTransport {
    let error: Error

    var diagnostics: DJConnectFastPathDiagnostics {
        DJConnectFastPathDiagnostics(
            fastPathTransport: "websocket",
            websocketConnected: true,
            websocketCommands: [DJConnectFastPathRoute.trackInsight.rawValue]
        )
    }

    func supports(_ route: DJConnectFastPathRoute) async -> Bool {
        route == .trackInsight
    }

    func prepare() async throws {}

    func command<T>(_ payload: DJConnectCommandPayload, identity: DJConnectAPIIdentity, responseType: T.Type) async throws -> T where T: Decodable, T: Sendable {
        throw DJConnectError.routeMissing(message: "command unsupported")
    }

    func askDJMessage(_ payload: DJConnectAskDJRequest, identity: DJConnectAPIIdentity) async throws -> DJConnectAskDJMessageResponse {
        throw DJConnectError.routeMissing(message: "ask dj unsupported")
    }

    func askDJHistory(identity: DJConnectAPIIdentity, sinceRevision: Int?) async throws -> DJConnectAskDJHistoryResponse {
        throw DJConnectError.routeMissing(message: "ask dj history unsupported")
    }

    func clearAskDJHistory(identity: DJConnectAPIIdentity, musicDNAKey: String?) async throws -> DJConnectAskDJHistoryResponse {
        throw DJConnectError.routeMissing(message: "ask dj clear unsupported")
    }

    func refreshMusicDiscovery(identity: DJConnectAPIIdentity, musicDNAKey: String?, language: String?) async throws -> DJConnectMusicDiscoveryResponse {
        throw DJConnectError.routeMissing(message: "music discovery unsupported")
    }

    func trackInsight(_ payload: DJConnectTrackInsightRequest, identity: DJConnectAPIIdentity) async throws -> TrackInsight {
        throw error
    }

    func vibeCast(_ payload: DJConnectVibeCastRequest, identity: DJConnectAPIIdentity) async throws -> DJConnectVibeCastResponse {
        throw DJConnectError.routeMissing(message: "vibecast unsupported")
    }
}

private enum TokenStoreTestError: Error {
    case denied
}

private func mockSession(
    host: String,
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
) -> URLSession {
    MockURLProtocol.setHandler(for: host, handler: handler)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
}

private func httpResponse(for request: URLRequest, statusCode: Int) throws -> HTTPURLResponse {
    guard let url = request.url, let response = HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    ) else {
        throw URLError(.badURL)
    }
    return response
}

private func testIOSIdentity(deviceID: String = "djconnect-ios-8F3A2C91B45D", deviceName: String = "iPhone") -> DJConnectIdentity {
    DJConnectIdentity(
        deviceID: deviceID,
        deviceName: deviceName,
        clientType: .ios,
        firmware: "3.2.2",
        appVersion: "3.2.2",
        platform: .ios
    )
}

private func testDefaults() throws -> UserDefaults {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

private func musicDiscoveryPushPayload() -> [AnyHashable: Any] {
    [
        "event_type": "music_discovery_ready",
        "open_target": "music_discovery",
        "refresh_target": "music_discovery",
        "deeplink": "djconnect://music-discovery",
        "title": "DJConnect",
        "body": "Je nieuwe aanbevelingen staan klaar!",
        "sections": [
            [
                "id": "push-section",
                "title": "Push section must be ignored",
                "items": [
                    [
                        "id": "push-track",
                        "kind": "track",
                        "title": "Push payload track must be ignored",
                        "uri": "spotify:track:push",
                        "reason": "Push payload reason must be ignored"
                    ]
                ]
            ]
        ],
        "aps": [
            "alert": [
                "title": "DJConnect",
                "body": "Je nieuwe aanbevelingen staan klaar!"
            ]
        ]
    ]
}

@MainActor
private func makePairedMusicDNAModel(defaults: UserDefaults, host: String, session: URLSession) -> DJConnectAppModel {
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"),
        urlSession: session,
        startBackgroundTasks: false
    )
    model.homeAssistantURL = "http://\(host):8123"
    model.pairingStatus = .paired
    return model
}

@Test func userDefaultsTokenStorePersistsAndClearsToken() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let store = DJConnectUserDefaultsTokenStore(defaults: defaults, key: "DJConnectTestDeviceToken")

    #expect(try store.loadToken() == nil)

    try store.saveToken("secret-token")
    #expect(defaults.string(forKey: "DJConnectTestDeviceToken") == "secret-token")
    #expect(try store.loadToken() == "secret-token")

    try store.clearToken()
    #expect(try store.loadToken() == nil)
}

@MainActor
@Test func tokenStorageFailureShowsPairingRecoveryWithoutKeychainPrompt() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let tokenStore = SequenceTokenStore(loadResults: [
        .failure(TokenStoreTestError.denied),
        .success("secret-token")
    ])
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: tokenStore,
        startBackgroundTasks: false
    )

    #expect(model.isShowingTokenStorageError == true)
    #expect(model.shouldShowPairingScreen == false)
    #expect(model.canUsePlaybackFeatures == false)

    model.retryTokenStorageAccess()

    #expect(model.isShowingTokenStorageError == false)
    #expect(model.pairingStatus == .paired)
    #expect(model.isConnected == true)
}

@MainActor
@Test func resetPairingRotatesLocalIdentityAndClearsPairCode() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set("manual-code", forKey: "DJConnectPairingToken")
    let tokenStore = DJConnectInMemoryTokenStore(token: "secret-token")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: tokenStore, startBackgroundTasks: false)
    let originalDeviceID = model.identity.deviceID

    model.resetPairing()

    #expect(model.identity.deviceID != originalDeviceID)
    #expect(model.identity.deviceID.hasPrefix("djconnect-"))
    #expect(model.pairingToken.isEmpty)
    #expect(defaults.string(forKey: "DJConnectPairingToken") == nil)
    #expect(try tokenStore.loadToken() == nil)
}

@MainActor
@Test func freshInstallIgnoresOrphanedPersistentDeviceToken() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let tokenStore = DJConnectUserDefaultsTokenStore(defaults: defaults, key: "DJConnectTestDeviceToken")
    try tokenStore.saveToken("orphaned-token")

    let model = DJConnectAppModel(defaults: defaults, tokenStore: tokenStore, startBackgroundTasks: false)

    #expect(model.pairingStatus == .unpaired)
    #expect(model.isConnected == false)
    #expect(try tokenStore.loadToken() == nil)
    #expect(defaults.string(forKey: "DJConnectInstallID")?.isEmpty == false)
}

@MainActor
@Test func freshInstallDoesNotGenerateLocalPairCode() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )

    #expect(model.pairingToken.isEmpty)
    #expect(defaults.string(forKey: "DJConnectPairingToken") == nil)
    #expect(model.pairingStatus == DJConnectPairingStatus.unpaired)
}

@MainActor
@Test func pairingAuthStaleShowsPairCodeRetryWithoutLocalDiscovery() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set("PAIR42", forKey: "DJConnectPairingToken")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    model.language = "nl"

    model.applyPairingWait(
        error: .authStale(
            statusCode: 401,
            message: "The pairing code does not match this DJConnect setup."
        ),
        pairingToken: "PAIR42"
    )

    #expect(model.pairingStatus == .unpaired)
    #expect(model.isPairing == false)
    #expect(!model.isTerminalPairingError(.authStale(statusCode: 401, message: nil)))
    #expect(model.pairingMessage?.contains("code") == true)
    #expect(model.pairingMessage?.contains("The pairing code does not match") == false)
}

@MainActor
@Test func pairingNetworkErrorsAreLocalizedWithoutRawSystemText() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    model.language = "nl"

    model.applyPairingWait(
        error: .network(message: "The resource could not be loaded because the App Transport Security policy requires the use of a secure connection."),
        pairingToken: "123456"
    )

    #expect(model.pairingMessage?.contains("iOS/macOS-beveiliging") == true)
    #expect(model.pairingMessage?.contains("App Transport Security") == false)
    #expect(model.pairingMessage?.contains("secure connection") == false)
}

@MainActor
@Test func pairingHTTPStatusErrorsAreLocalized() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    model.language = "nl"

    model.applyPairingWait(error: .server(statusCode: 404, message: "HTTP 404 Not Found"), pairingToken: "123456")
    #expect(model.pairingMessage == "DJConnect is niet gevonden in Home Assistant. Open eerst de DJConnect setup-flow.")

    model.applyPairingWait(error: .server(statusCode: 500, message: "HTTP 500 Internal Server Error"), pairingToken: "123456")
    #expect(model.pairingMessage == "Home Assistant kreeg een interne fout tijdens het koppelen. Controleer Home Assistant en probeer opnieuw.")
}

@MainActor
@Test func pairingNotConfiguredDuringManualPairingShowsInvalidCode() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    model.language = "nl"

    model.applyPairingWait(error: .notConfigured(message: "DJConnect is not configured."), pairingToken: "353312")
    #expect(model.pairingMessage == "Koppelcode klopt niet. Controleer de code in Home Assistant.")

    model.applyPairingWait(error: .server(statusCode: 503, message: #"{"error":"not_configured","message":"DJConnect is not configured."}"#), pairingToken: "353312")
    #expect(model.pairingMessage == "Koppelcode klopt niet. Controleer de code in Home Assistant.")
}

@MainActor
@Test func pairingClientTypeMismatchShowsWrongAppType() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    model.language = "nl"

    model.applyPairingWait(error: .server(statusCode: 400, message: #"{"error":"invalid_client_type","message":"Selected iOS pairing flow does not match macOS client_type."}"#), pairingToken: "503901")

    #expect(model.pairingMessage?.contains("Verkeerd app-type gekozen") == true)
    #expect(model.pairingMessage?.contains("setup-flow") == true)
    #expect(model.pairingMessage?.contains("invalid_client_type") == false)
}

@MainActor
@Test func pairingOfficialClientTypeMismatchKeepsInputsAndShowsRequestedMessage() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    model.language = "nl"
    model.homeAssistantURL = "https://victory-curvy-refold.ngrok-free.dev"
    model.pairingToken = "503901"

    model.applyPairingWait(
        error: .clientTypeMismatch(
            message: "Selected iOS setup flow does not match this macOS app.",
            expectedClientType: "macos",
            receivedClientType: "ios"
        ),
        pairingToken: "503901"
    )

    #expect(model.homeAssistantURL == "https://victory-curvy-refold.ngrok-free.dev")
    #expect(model.pairingToken == "503901")
    #expect(model.isPairing == false)
    #expect(model.pairingStatus == .unpaired)
    #expect(model.pairingMessage == "Het gekozen app-type in Home Assistant klopt niet met deze app. Kies in Home Assistant de DJConnect macOS setup-flow en probeer opnieuw.")
}

@MainActor
@Test func authStaleClearsTokenAndReopensPairing() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(true, forKey: "DJConnectWelcomeSeen")
    defaults.set("651161", forKey: "DJConnectPairingToken")
    let tokenStore = DJConnectInMemoryTokenStore(token: "stale-token")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: tokenStore, startBackgroundTasks: false)
    defer {
        model.stopPairingWait()
    }

    #expect(model.pairingStatus == .paired)

    model.apply(error: .authStale(statusCode: 401, message: "The DJConnect device token is missing or invalid."))

    #expect(model.pairingStatus == .pairing || model.pairingStatus == .stale)
    #expect(model.isPairingScreenDismissed == false)
    #expect(model.pairingToken.isEmpty)
    #expect(defaults.string(forKey: "DJConnectPairingToken") == nil)
    #expect(try tokenStore.loadToken() == nil)
}

@MainActor
@Test func notConfiguredClearsStalePairCodeAndReopensPairing() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(true, forKey: "DJConnectWelcomeSeen")
    defaults.set("651161", forKey: "DJConnectPairingToken")
    let tokenStore = DJConnectInMemoryTokenStore(token: "stale-token")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: tokenStore, startBackgroundTasks: false)
    defer {
        model.stopPairingWait()
    }

    #expect(model.pairingStatus == .paired)
    #expect(model.pairingToken == "651161")

    model.apply(error: .notConfigured(message: "DJConnect is not configured."))

    #expect(model.pairingStatus == .stale)
    #expect(model.isPairingScreenDismissed == false)
    #expect(model.pairingToken.isEmpty)
    #expect(defaults.string(forKey: "DJConnectPairingToken") == nil)
    #expect(try tokenStore.loadToken() == nil)
    #expect(model.pairingMessage == "DJConnect is not configured.")
}

@MainActor
@Test func notConfiguredDuringActivePairingKeepsEnteredPairCode() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(true, forKey: "DJConnectWelcomeSeen")
    let tokenStore = DJConnectInMemoryTokenStore(token: "pairing-token")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: tokenStore, startBackgroundTasks: false)
    defer {
        model.stopPairingWait()
    }
    model.language = "nl"
    model.pairingStatus = .pairing
    model.isPairing = true
    model.pairingToken = "651161"

    model.apply(error: .notConfigured(message: "DJConnect is not configured."))

    #expect(model.pairingStatus == .pairing)
    #expect(model.isPairing == true)
    #expect(model.isPairingScreenDismissed == false)
    #expect(model.pairingToken == "651161")
    #expect(defaults.string(forKey: "DJConnectPairingToken") == "651161")
    #expect(try tokenStore.loadToken() == "pairing-token")
    #expect(model.pairingMessage == "Wacht op afronden in Home Assistant.")
}

@Test func statusRequestIncludesContractFieldsAndHeaders() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.7",
        appVersion: "3.1.7",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let payload = DJConnectStatusPayload(
        identity: identity,
        batteryPercent: 85,
        language: "nl",
        theme: "dark",
        logLevel: "info",
        haLocalURL: "http://192.168.1.10:8123",
        voiceEnabled: true,
        wakewordEnabled: true,
        wakewordPhrase: "Okay Nabu",
        wakewordStatus: "listening",
        mood: 75,
        djStyle: "warm_radio_dj",
        musicDNAKey: "user:peter"
    )

    let request = try client.statusRequest(payload)
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/v1/status")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-ID") == identity.deviceID)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(json?["client_id"] as? String == identity.deviceID)
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["device_name"] as? String == identity.deviceName)
    #expect(json?["client_type"] as? String == "ios")
    #expect(json?["firmware"] as? String == "3.1.7")
    #expect(json?["app_version"] as? String == "3.1.7")
    #expect(json?["ha_local_url"] as? String == "http://192.168.1.10:8123")
    #expect(json?["ha_remote_url"] == nil)
    #expect(json?["ha_active_url"] == nil)
    #expect(json?["local_url"] == nil)
    #expect(json?["voice_enabled"] as? Bool == true)
    #expect(json?["wakeword_enabled"] as? Bool == true)
    #expect(json?["wakeword_phrase"] as? String == "Okay Nabu")
    #expect(json?["wakeword_status"] as? String == "listening")
    #expect(json?["mood"] as? Int == 75)
    #expect(json?["dj_style"] as? String == "warm_radio_dj")
    #expect(json?["music_dna_key"] as? String == "user:peter")
}

@Test func homeAssistantClientRoutesUseCanonicalV1Prefix() throws {
    let checkedRoots = ["Sources", "Apps"]
    let legacyRoutes = [
        "/api/djconnect/pair",
        "/api/djconnect/command",
        "/api/djconnect/voice",
        "/api/djconnect/status",
        "/api/djconnect/ask",
        "/api/djconnect/ask_dj/message",
        "/api/djconnect/ask_dj/history",
        "/api/djconnect/ask_dj/history/clear",
        "/api/djconnect/ask_dj/idle_suggestion",
        "/api/djconnect/track_insight",
        "/api/djconnect/music_dna/profile",
        "/api/djconnect/music_dna/settings",
        "/api/djconnect/music_dna/clear",
        "/api/djconnect/music_dna/export",
        "/api/djconnect/music_dna/import",
        "/api/djconnect/music_discovery",
        "/api/djconnect/music_discovery/refresh",
        "/api/djconnect/music_discovery/play",
        "/api/djconnect/vibecast",
        "/api/djconnect/push/register",
        "/api/djconnect/push/unregister"
    ]
    let fileManager = FileManager.default
    let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
    var offenders: [String] = []

    for checkedRoot in checkedRoots {
        let rootURL = root.appendingPathComponent(checkedRoot)
        guard let enumerator = fileManager.enumerator(at: rootURL, includingPropertiesForKeys: nil) else {
            continue
        }
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            for (lineNumber, line) in contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                if line.contains("legacyPairPath") {
                    continue
                }
                for route in legacyRoutes where line.contains(route) && !line.contains("/api/djconnect/v1") {
                    offenders.append("\(fileURL.path):\(lineNumber + 1): \(route)")
                }
            }
        }
    }

    #expect(offenders == [])
}

@Test func commandRequestSupportsTypedValues() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-macos-8F3A2C91B45D",
        deviceName: "DJConnect Mac",
        clientType: .macos,
        firmware: "3.1.7",
        appVersion: "3.1.7",
        platform: .macos
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.commandRequest(
        DJConnectCommandPayload(
            identity: identity,
            command: "set_volume",
            value: .int(35),
            play: true,
            language: "nl-NL",
            mood: 70,
            musicDNAKey: "user:peter"
        )
    )
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/v1/command")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-ID") == identity.deviceID)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Language") == "nl-NL")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Locale") == "nl-NL")
    #expect(request.value(forHTTPHeaderField: "Accept-Language") == "nl-NL")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Mood") == "70")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Music-DNA-Key") == "user:peter")
    #expect(json?["client_id"] as? String == identity.deviceID)
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["device_name"] as? String == identity.deviceName)
    #expect(json?["client_type"] as? String == "macos")
    #expect(json?["command"] as? String == "set_volume")
    #expect(json?["value"] as? Int == 35)
    #expect(json?["language"] as? String == "nl-NL")
    #expect(json?["mood"] as? Int == 70)
    #expect(json?["music_dna_key"] as? String == "user:peter")
    #expect(json?["play"] as? Bool == true)
    #expect(json?["mood"] as? Int == 70)
}

@Test func askDJRequestUsesAskEndpointAndMusicDNAContext() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.7",
        appVersion: "3.1.7",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.askDJRequest(DJConnectAskDJRequest(
        identity: identity,
        text: "Speel iets rustigers",
        mood: 20,
        djStyle: "warm_radio_dj",
        musicDNAKey: "djconnect_ios_8F3A2C91B45D",
        language: "nl-NL"
    ))
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/v1/ask")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["device_name"] as? String == identity.deviceName)
    #expect(json?["client_type"] as? String == "ios")
    #expect(json?["client_id"] as? String == identity.deviceID)
    let topIdentity = json?["identity"] as? [String: Any]
    let payload = json?["payload"] as? [String: Any]
    let payloadIdentity = payload?["identity"] as? [String: Any]
    #expect(topIdentity?["device_id"] as? String == identity.deviceID)
    #expect(topIdentity?["client_id"] as? String == identity.deviceID)
    #expect(topIdentity?["client_type"] as? String == "ios")
    #expect(topIdentity?["device_token"] as? String == "secret-token")
    #expect(payload?["text"] as? String == "Speel iets rustigers")
    #expect(payloadIdentity?["device_id"] as? String == identity.deviceID)
    #expect(payloadIdentity?["device_token"] as? String == "secret-token")
    #expect(json?["text"] as? String == "Speel iets rustigers")
    #expect(json?["mood"] as? Int == 20)
    #expect(json?["dj_style"] as? String == "warm_radio_dj")
    #expect(json?["music_dna_key"] as? String == "djconnect_ios_8F3A2C91B45D")
    #expect(json?["language"] as? String == "nl-NL")
}

@Test func askDJMessageRequestUsesSyncedHistoryEndpointAndClientMessageID() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.36",
        appVersion: "3.1.36",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.askDJMessageRequest(DJConnectAskDJRequest(
        identity: identity,
        text: "Verras me met nieuwe muziek",
        clientMessageID: "client-message-1",
        inputType: "text",
        mood: 70,
        djStyle: "warm_radio_dj",
        musicDNAKey: "djconnect_ios_8F3A2C91B45D",
        audioResponse: .auto,
        language: "nl-NL"
    ))
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/v1/ask_dj/message")
    #expect(request.timeoutInterval == 30)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["device_name"] as? String == identity.deviceName)
    #expect(json?["client_type"] as? String == "ios")
    #expect(json?["client_id"] as? String == identity.deviceID)
    let topIdentity = json?["identity"] as? [String: Any]
    let payload = json?["payload"] as? [String: Any]
    let payloadIdentity = payload?["identity"] as? [String: Any]
    #expect(topIdentity?["device_id"] as? String == identity.deviceID)
    #expect(topIdentity?["client_id"] as? String == identity.deviceID)
    #expect(topIdentity?["client_type"] as? String == "ios")
    #expect(topIdentity?["device_token"] as? String == "secret-token")
    #expect(payload?["client_message_id"] as? String == "client-message-1")
    #expect(payloadIdentity?["device_id"] as? String == identity.deviceID)
    #expect(payloadIdentity?["device_token"] as? String == "secret-token")
    #expect(json?["client_message_id"] as? String == "client-message-1")
    #expect(json?["input_type"] as? String == "text")
    #expect(json?["text"] as? String == "Verras me met nieuwe muziek")
    #expect(json?["mood"] as? Int == 70)
    #expect(json?["audio_response"] as? String == "auto")
    #expect(json?["language"] as? String == "nl-NL")
}

@Test func clearAskDJHistoryRequestIncludesClientIdentityAndMusicDNAKey() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.36",
        appVersion: "3.1.36",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.clearAskDJHistoryRequest(musicDNAKey: "djconnect_ios_8F3A2C91B45D")
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/v1/ask_dj/history/clear")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["client_id"] as? String == identity.deviceID)
    #expect(json?["client_type"] as? String == "ios")
    #expect(json?["device_name"] as? String == identity.deviceName)
    let topIdentity = json?["identity"] as? [String: Any]
    let payload = json?["payload"] as? [String: Any]
    let payloadIdentity = payload?["identity"] as? [String: Any]
    #expect(topIdentity?["device_id"] as? String == identity.deviceID)
    #expect(topIdentity?["device_token"] as? String == "secret-token")
    #expect(payload?["music_dna_key"] as? String == "djconnect_ios_8F3A2C91B45D")
    #expect(payloadIdentity?["device_id"] as? String == identity.deviceID)
    #expect(payloadIdentity?["device_token"] as? String == "secret-token")
    #expect(json?["music_dna_key"] as? String == "djconnect_ios_8F3A2C91B45D")
}

@Test func clearAskDJHistoryMacOSRequestIncludesFullClientIdentity() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-macos-8F3A2C91B45D",
        deviceName: "DJConnect Mac",
        clientType: .macos,
        firmware: "3.2.8",
        appVersion: "3.2.8",
        platform: .macos
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.clearAskDJHistoryRequest(musicDNAKey: "music-dna")
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/v1/ask_dj/history/clear")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(json?["device_id"] as? String == "djconnect-macos-8F3A2C91B45D")
    #expect(json?["client_id"] as? String == "djconnect-macos-8F3A2C91B45D")
    #expect(json?["client_type"] as? String == "macos")
    #expect(json?["device_name"] as? String == "DJConnect Mac")
}

@Test func exportAskDJHistoryRequestUsesHTTPAndNestedIdentityEnvelope() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.2.15",
        appVersion: "3.2.15",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.exportAskDJHistoryRequest()
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
    let exportIdentity = json?["identity"] as? [String: Any]
    let payload = json?["payload"] as? [String: Any]
    let payloadIdentity = payload?["identity"] as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/v1/ask_dj/history/export")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(exportIdentity?["device_id"] as? String == identity.deviceID)
    #expect(exportIdentity?["device_token"] as? String == "secret-token")
    #expect(payloadIdentity?["device_id"] as? String == identity.deviceID)
    #expect(payloadIdentity?["client_type"] as? String == "ios")
    #expect(payloadIdentity?["device_name"] as? String == identity.deviceName)
    #expect(payload?["app_version"] as? String == "3.2.15")
    #expect(payload?["music_dna_key"] == nil)
}

@Test func musicDNARequestsUseBearerIdentityAndCanonicalClientType() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-macos-8F3A2C91B45D",
        deviceName: "DJConnect Mac",
        clientType: .macos,
        firmware: "3.2.3",
        appVersion: "3.2.3",
        platform: .macos
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let profile = try client.musicDNAProfileRequest()
    let settings = try client.musicDNASettingsRequest(enabled: true)
    let clear = try client.clearMusicDNARequest()
    let moodProfile = try client.musicDNAProfileRequest(mood: 70, musicDNAKey: "user:abc123", language: "nl")
    let moodSettings = try client.musicDNASettingsRequest(enabled: false, mood: 85, musicDNAKey: "user:abc123", language: "nl")
    let moodClear = try client.clearMusicDNARequest(mood: -10, musicDNAKey: "user:abc123", language: "nl")
    let export = try client.exportMusicDNARequest(musicDNAKey: "user:abc123", language: "nl")
    let importedProfile = DJConnectMusicDNAProfileResponse(
        enabled: true,
        generation: 4,
        profile: DJConnectMusicDNAProfile(summary: "Imported taste", trackCount: 9)
    )
    let moodImport = try client.importMusicDNARequest(importedProfile, mood: 35, musicDNAKey: "user:abc123", language: "nl")

    for request in [profile, settings, clear, moodImport] {
        let body = try #require(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
        #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(json?["device_id"] as? String == identity.deviceID)
        #expect(json?["client_id"] as? String == identity.deviceID)
        #expect(json?["client_type"] as? String == "macos")
        #expect(json?["device_name"] as? String == identity.deviceName)
        let topIdentity = json?["identity"] as? [String: Any]
        let payload = json?["payload"] as? [String: Any]
        let payloadIdentity = payload?["identity"] as? [String: Any]
        #expect(topIdentity?["device_id"] as? String == identity.deviceID)
        #expect(topIdentity?["client_id"] as? String == identity.deviceID)
        #expect(topIdentity?["client_type"] as? String == "macos")
        #expect(topIdentity?["device_token"] as? String == "secret-token")
        #expect(payloadIdentity?["device_id"] as? String == identity.deviceID)
        #expect(payloadIdentity?["device_token"] as? String == "secret-token")
    }
    #expect(profile.url?.path == "/api/djconnect/v1/music_dna/profile")
    #expect(settings.url?.path == "/api/djconnect/v1/music_dna/settings")
    #expect(clear.url?.path == "/api/djconnect/v1/music_dna/clear")
    #expect(moodImport.url?.path == "/api/djconnect/v1/music_dna/import")
    #expect(export.url?.path == "/api/djconnect/v1/music_dna/export")

    let settingsBody = try #require(settings.httpBody)
    let settingsJSON = try JSONSerialization.jsonObject(with: settingsBody) as? [String: Any]
    #expect(settingsJSON?["enabled"] as? Bool == true)

    let moodProfileBody = try #require(moodProfile.httpBody)
    let moodProfileJSON = try JSONSerialization.jsonObject(with: moodProfileBody) as? [String: Any]
    #expect(moodProfileJSON?["mood"] as? Int == 70)
    #expect(moodProfileJSON?["music_dna_key"] as? String == "user:abc123")
    #expect(moodProfileJSON?["language"] as? String == "nl")
    #expect(moodProfileJSON?["locale"] as? String == "nl")
    #expect(moodProfile.value(forHTTPHeaderField: "X-DJConnect-Mood") == "70")
    #expect(moodProfile.value(forHTTPHeaderField: "X-DJConnect-Music-DNA-Key") == "user:abc123")
    #expect(moodProfile.value(forHTTPHeaderField: "X-DJConnect-Language") == "nl")

    let moodSettingsBody = try #require(moodSettings.httpBody)
    let moodSettingsJSON = try JSONSerialization.jsonObject(with: moodSettingsBody) as? [String: Any]
    #expect(moodSettingsJSON?["enabled"] as? Bool == false)
    #expect(moodSettingsJSON?["mood"] as? Int == 85)
    #expect(moodSettingsJSON?["music_dna_key"] as? String == "user:abc123")

    let moodClearBody = try #require(moodClear.httpBody)
    let moodClearJSON = try JSONSerialization.jsonObject(with: moodClearBody) as? [String: Any]
    #expect(moodClearJSON?["mood"] as? Int == 0)
    #expect(moodClearJSON?["music_dna_key"] as? String == "user:abc123")

    let moodImportBody = try #require(moodImport.httpBody)
    let moodImportJSON = try JSONSerialization.jsonObject(with: moodImportBody) as? [String: Any]
    let importProfile = moodImportJSON?["profile"] as? [String: Any]
    let importProfileBody = importProfile?["profile"] as? [String: Any]
    #expect(moodImportJSON?["mood"] as? Int == 35)
    #expect(moodImportJSON?["music_dna_key"] as? String == "user:abc123")
    #expect(moodImport.value(forHTTPHeaderField: "X-DJConnect-Mood") == "35")
    #expect(importProfile?["enabled"] as? Bool == true)
    #expect(importProfile?["generation"] as? Int == 4)
    #expect(importProfileBody?["summary"] as? String == "Imported taste")
    #expect(importProfileBody?["track_count"] as? Int == 9)

    let exportBody = try #require(export.httpBody)
    let exportJSON = try JSONSerialization.jsonObject(with: exportBody) as? [String: Any]
    let exportIdentity = exportJSON?["identity"] as? [String: Any]
    let exportPayload = exportJSON?["payload"] as? [String: Any]
    #expect(export.httpMethod == "POST")
    #expect(export.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(export.value(forHTTPHeaderField: "X-DJConnect-Music-DNA-Key") == "user:abc123")
    #expect(export.value(forHTTPHeaderField: "X-DJConnect-Language") == "nl")
    #expect(exportJSON?["device_id"] as? String == identity.deviceID)
    #expect(exportJSON?["client_type"] as? String == "macos")
    #expect(exportJSON?["device_name"] as? String == identity.deviceName)
    #expect(exportJSON?["music_dna_key"] as? String == "user:abc123")
    #expect(exportJSON?["language"] as? String == "nl")
    #expect(exportJSON?["app_version"] as? String == "3.2.3")
    #expect(exportIdentity?["device_id"] as? String == identity.deviceID)
    #expect(exportPayload?["music_dna_key"] as? String == "user:abc123")
    #expect(exportPayload?["app_version"] as? String == "3.2.3")
}

@Test func musicDNAExportDownloadsExactBackendEnvelopeOverHTTP() async throws {
    let host = "musicdna-export.local"
    let recorder = RequestRecorder()
    let exportedBody = Data("""
    {
      "success": true,
      "format": "djconnect.music_dna.export",
      "schema_version": 1,
      "exported_at": "2026-07-04T20:21:00.123Z",
      "exported_by_client_type": "ios",
      "app_version": "3.2.3",
      "profile": {
        "success": true,
        "music_dna_key": "user:abc123",
        "enabled": true,
        "generation": 12,
        "updated_at": "2026-07-04T20:20:00Z",
        "profile": {"summary": "Server-built export", "track_count": 42},
        "sources": [{"source": "djconnect_music_dna", "kind": "source", "title": "Music DNA"}]
      }
    }
    """.utf8)
    let session = mockSession(host: host) { request in
        recorder.append(request)
        return (try httpResponse(for: request, statusCode: 200), exportedBody)
    }
    let identity = testIOSIdentity()
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://\(host):8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"),
        session: session
    )

    let data = try await client.exportMusicDNAData(musicDNAKey: "user:abc123", language: "nl")
    let decoded = try await client.exportMusicDNA(musicDNAKey: "user:abc123", language: "nl")
    let requests = recorder.requests

    #expect(data == exportedBody)
    #expect(decoded.format == "djconnect.music_dna.export")
    #expect(decoded.schemaVersion == 1)
    #expect(decoded.profile.musicDNAKey == "user:abc123")
    #expect(decoded.profile.profile.summary == "Server-built export")
    #expect(requests.count == 2)
    for request in requests {
        #expect(request.url?.path == "/api/djconnect/v1/music_dna/export")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
        #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
        #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-Type") == "ios")
        #expect(request.value(forHTTPHeaderField: "X-DJConnect-Music-DNA-Key") == "user:abc123")
        #expect(request.value(forHTTPHeaderField: "X-DJConnect-Language") == "nl")
    }
}

@Test func musicDiscoveryRequestsUseDedicatedEndpointsAndIdentity() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "iPhone",
        clientType: .ios,
        firmware: "3.2.3",
        appVersion: "3.2.3",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let feed = try client.musicDiscoveryFeedRequest(musicDNAKey: "user:abc123", language: "nl")
    let refresh = try client.refreshMusicDiscoveryRequest(musicDNAKey: "user:abc123", language: "nl")
    let play = try client.musicDiscoveryPlayRequest(DJConnectMusicDiscoveryPlayRequest(
        discoveryItemID: "disc-track-1",
        sectionID: "because_you_like",
        identity: identity,
        musicDNAKey: "user:abc123"
    ))

    #expect(feed.httpMethod == "GET")
    #expect(feed.url?.path == "/api/djconnect/v1/music_discovery")
    #expect(feed.value(forHTTPHeaderField: "X-DJConnect-Music-DNA-Key") == "user:abc123")
    #expect(feed.value(forHTTPHeaderField: "X-DJConnect-Language") == "nl")
    #expect(refresh.httpMethod == "POST")
    #expect(refresh.url?.path == "/api/djconnect/v1/music_discovery/refresh")
    #expect(play.httpMethod == "POST")
    #expect(play.url?.path == "/api/djconnect/v1/music_discovery/play")

    let playBody = try #require(play.httpBody)
    let playJSON = try #require(JSONSerialization.jsonObject(with: playBody) as? [String: Any])
    #expect(playJSON["discovery_item_id"] as? String == "disc-track-1")
    #expect(playJSON["section_id"] as? String == "because_you_like")
    #expect(playJSON["device_id"] as? String == "djconnect-ios-8F3A2C91B45D")
    #expect(playJSON["client_type"] as? String == "ios")
    #expect(playJSON["music_dna_key"] as? String == "user:abc123")
}

@Test func authenticatedRequestsRejectClientTypeDeviceIDPrefixMismatch() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect Mac",
        clientType: .macos,
        firmware: "3.2.3",
        appVersion: "3.2.3",
        platform: .macos
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    #expect(throws: DJConnectError.invalidConfiguration("DJConnect identity mismatch: device_id prefix does not match client_type.")) {
        _ = try client.musicDNAProfileRequest()
    }
}

@Test func musicDNAProfileDecodesPopulatedEmptyAndDisabledStates() throws {
    let populated = try JSONDecoder().decode(
        DJConnectMusicDNAProfileResponse.self,
        from: Data("""
        {
          "success": true,
          "music_dna_key": "user:abc123",
          "enabled": true,
          "generation": 2,
          "updated_at": "2026-06-29T12:00:00+00:00",
          "profile": {
            "summary": "Warm late-night electronic taste.",
            "favorite_genres": [{"name": "ambient"}],
            "favorite_artists": [{"name": "The xx"}],
            "recent_tracks": [{"title": "Intro", "artist": "The xx", "album": "xx"}],
            "recent_favorite_tracks": [
              {
                "track_name": "Favorite One",
                "artist_name": "Asha",
                "album_name": "Night Drive",
                "uri": "spotify:track:favorite-one",
                "album_image_url": "https://example.test/favorite-one.jpg",
                "created_at": "2026-07-04T05:45:00Z"
              },
              {
                "title": "Favorite Two",
                "artist": "Miro",
                "album": "Dawn",
                "image_url": "https://example.test/favorite-two.jpg"
              }
            ],
            "playtime": {
              "total_seconds": 5400,
              "total_hours": 1.5,
              "formatted_total": "1u 30m",
              "top_artists": [
                {"name": "The xx", "seconds": 2400, "hours": 0.67, "formatted": "40m"},
                {"name": "Asha", "seconds": 1800, "hours": 0.5, "formatted": "30m"},
                {"name": "Miro", "seconds": 900, "hours": 0.25, "formatted": "15m"},
                {"name": "Fourth", "seconds": 300, "hours": 0.08, "formatted": "5m"}
              ],
              "top_albums": [
                {"name": "xx", "seconds": 2100, "hours": 0.58, "formatted": "35m"},
                {"name": "Night Drive", "seconds": 1500, "hours": 0.42, "formatted": "25m"},
                {"name": "Dawn", "seconds": 900, "hours": 0.25, "formatted": "15m"},
                {"name": "Overflow Album", "seconds": 300, "hours": 0.08, "formatted": "5m"}
              ]
            },
            "listening_rhythm": {
              "sample_count": 3,
              "top_daypart": "avond",
              "top_weekday": "vrijdag",
              "dayparts": [
                {"daypart": "avond", "count": 2, "percent": 66.7},
                {"daypart": "middag", "count": 1, "percent": 33.3}
              ],
              "weekdays": [
                {"weekday": "vrijdag", "count": 2, "percent": 66.7},
                {"weekday": "zaterdag", "count": 1, "percent": 33.3}
              ]
            },
            "mood_mix": {
              "sample_count": 4,
              "average": 57,
              "top_zone": "groove",
              "zones": [
                {"zone": "chill", "count": 1, "percent": 25},
                {"zone": "groove", "count": 2, "percent": 50},
                {"zone": "energy", "count": 1, "percent": 25}
              ]
            },
            "repeat_magnets": {
              "eligible": true,
              "items": [
                {"kind": "artist", "name": "The xx", "count": 4},
                {"kind": "album", "name": "xx", "seconds": 2400, "formatted": "40m"},
                {"kind": "artist", "name": "Asha", "count": 2},
                {"kind": "album", "name": "Overflow", "formatted": "5m"}
              ]
            },
            "explicit_positives": {
              "eligible": true,
              "signal_count": 3,
              "favorite_tracks": [
                {"kind": "favorite_track", "title": "Favorite One", "artist": "Asha", "uri": "spotify:track:favorite-one"}
              ],
              "accepted_recommendations": [
                {"kind": "accepted_recommendation", "title": "Try This", "subtitle": "Warm groove", "uri": "spotify:track:try-this", "reason": "matched_mood"}
              ]
            },
            "taste_anchors": {
              "eligible": true,
              "items": [
                {"kind": "artist", "name": "The xx", "play_count": 6, "formatted": "1u"},
                {"kind": "genre", "name": "ambient"},
                {"kind": "genre", "name": "melodic house"},
                {"kind": "artist", "name": "Asha", "seconds": 1200, "formatted": "20m"},
                {"kind": "genre", "name": "indie electronic"},
                {"kind": "genre", "name": "overflow"}
              ]
            },
            "mood": {
              "value": 90,
              "zone": "party",
              "prompt_hint": "maximale energie",
              "sample_count": 3,
              "average": 57,
              "average_zone": "groove",
              "average_prompt_hint": "vloeiend, ritmisch",
              "zone_counts": {
                "chill": 1,
                "groove": 0,
                "energy": 1,
                "party": 1
              }
            },
            "energy_profile": {
              "sample_count": 2,
              "energy": 0.70,
              "energy_percent": 70,
              "zone": "energy",
              "prompt_hint": "hoge energie",
              "danceability": 0.54,
              "danceability_percent": 54,
              "intensity": 0.62,
              "intensity_percent": 62,
              "recent_signals": [
                {
                  "title": "Dream On",
                  "artist": "Scala",
                  "album": "Dream On",
                  "energy": 0.81,
                  "danceability": 0.62,
                  "intensity": 0.74,
                  "confidence": 0.9,
                  "created_at": "2026-06-29T11:59:00+00:00"
                }
              ]
            },
            "recommendation_signals": [{"title": "soft vocals"}]
          },
          "sources": [{"source": "djconnect_music_dna", "kind": "source", "title": "Music DNA"}]
        }
        """.utf8)
    )
    let empty = try JSONDecoder().decode(
        DJConnectMusicDNAProfileResponse.self,
        from: Data(#"{"success":true,"enabled":true,"profile":{}}"#.utf8)
    )
    let disabled = try JSONDecoder().decode(
        DJConnectMusicDNAProfileResponse.self,
        from: Data(#"{"success":true,"enabled":false,"profile":{}}"#.utf8)
    )
    let summaryOnly = try JSONDecoder().decode(
        DJConnectMusicDNAProfileResponse.self,
        from: Data(#"{"success":true,"enabled":true,"profile":{"summary":"Compact Music DNA summary."}}"#.utf8)
    )
    let zeroPlaytime = try JSONDecoder().decode(
        DJConnectMusicDNAProfileResponse.self,
        from: Data(#"{"success":true,"enabled":true,"profile":{"playtime":{"total_seconds":0,"total_hours":0,"formatted_total":"0m","top_artists":[{"name":"Silent","seconds":0,"hours":0,"formatted":"0m"}]}}}"#.utf8)
    )
    let emptyDashboardBlocks = try JSONDecoder().decode(
        DJConnectMusicDNAProfileResponse.self,
        from: Data(#"{"success":true,"enabled":true,"profile":{"listening_rhythm":{"sample_count":0,"top_daypart":"avond","dayparts":[]},"mood_mix":{"sample_count":0,"top_zone":"groove","zones":[]}}}"#.utf8)
    )
    let lowSampleListeningRhythm = try JSONDecoder().decode(
        DJConnectMusicDNAProfileResponse.self,
        from: Data(#"{"success":true,"enabled":true,"profile":{"summary":"Short profile.","listening_rhythm":{"sample_count":2,"top_daypart":"avond","dayparts":[{"daypart":"avond","count":2,"percent":100}]}}}"#.utf8)
    )
    let ineligibleConditionalBlocks = try JSONDecoder().decode(
        DJConnectMusicDNAProfileResponse.self,
        from: Data(#"{"success":true,"enabled":true,"profile":{"repeat_magnets":{"eligible":false,"reason":"insufficient_repeat_signals","items":[{"kind":"artist","name":"Hidden","count":4}]},"explicit_positives":{"eligible":false,"reason":"no_explicit_positive_signals","signal_count":0,"favorite_tracks":[{"kind":"favorite_track","title":"Hidden"}],"accepted_recommendations":[]},"taste_anchors":{"eligible":false,"reason":"insufficient_anchor_signals","items":[{"kind":"genre","name":"hidden"}]}}}"#.utf8)
    )
    let eligibleEmptyConditionalBlocks = try JSONDecoder().decode(
        DJConnectMusicDNAProfileResponse.self,
        from: Data(#"{"success":true,"enabled":true,"profile":{"repeat_magnets":{"eligible":true,"items":[]},"explicit_positives":{"eligible":true,"favorite_tracks":[],"accepted_recommendations":[]},"taste_anchors":{"eligible":true,"items":[]}}}"#.utf8)
    )

    #expect(populated.enabled == true)
    #expect(populated.profile.isEmpty == false)
    #expect(populated.musicDNAKey == "user:abc123")
    #expect(populated.profile.favoriteGenres?.first?.name == "ambient")
    #expect(populated.profile.favoriteArtists?.first?.name == "The xx")
    #expect(populated.profile.recentTracks?.first?.title == "Intro")
    #expect(populated.profile.recentTracks?.first?.album == "xx")
    #expect(populated.profile.recentFavoriteTracks?.count == 2)
    #expect(populated.profile.recentFavoriteTracks?.first?.title == "Favorite One")
    #expect(populated.profile.recentFavoriteTracks?.first?.artist == "Asha")
    #expect(populated.profile.recentFavoriteTracks?.first?.album == "Night Drive")
    #expect(populated.profile.recentFavoriteTracks?.first?.uri == "spotify:track:favorite-one")
    #expect(populated.profile.recentFavoriteTracks?.first?.imageURL == "https://example.test/favorite-one.jpg")
    #expect(populated.profile.recentFavoriteTracks?.first?.createdAt != nil)
    #expect(populated.profile.recentFavoriteTracks?.dropFirst().first?.title == "Favorite Two")
    #expect(populated.profile.recentFavoriteTracks?.dropFirst().first?.imageURL == "https://example.test/favorite-two.jpg")
    #expect(populated.profile.playtime?.totalSeconds == 5400)
    #expect(populated.profile.playtime?.totalHours == 1.5)
    #expect(populated.profile.playtime?.formattedTotal == "1u 30m")
    #expect(populated.profile.playtime?.isDisplayable == true)
    #expect(populated.profile.playtime?.visibleTopArtists.map(\.name) == ["The xx", "Asha", "Miro"])
    #expect(populated.profile.playtime?.visibleTopArtists.map(\.formatted) == ["40m", "30m", "15m"])
    #expect(populated.profile.playtime?.visibleTopAlbums.map(\.name) == ["xx", "Night Drive", "Dawn"])
    #expect(populated.profile.playtime?.visibleTopAlbums.map(\.formatted) == ["35m", "25m", "15m"])
    #expect(populated.profile.listeningRhythm?.sampleCount == 3)
    #expect(populated.profile.listeningRhythm?.topDaypart == "avond")
    #expect(populated.profile.listeningRhythm?.topWeekday == "vrijdag")
    #expect(populated.profile.listeningRhythm?.dayparts.map(\.daypart) == ["avond", "middag"])
    #expect(populated.profile.listeningRhythm?.dayparts.map(\.percent) == [66.7, 33.3])
    #expect(populated.profile.listeningRhythm?.visibleWeekdays.map(\.weekday) == ["vrijdag", "zaterdag"])
    #expect(populated.profile.listeningRhythm?.isDisplayable == true)
    #expect(populated.profile.moodMix?.sampleCount == 4)
    #expect(populated.profile.moodMix?.average == 57)
    #expect(populated.profile.moodMix?.topZone == "groove")
    #expect(populated.profile.moodMix?.zones.map(\.zone) == ["chill", "groove", "energy"])
    #expect(populated.profile.moodMix?.zones.map(\.percent) == [25, 50, 25])
    #expect(populated.profile.moodMix?.isDisplayable == true)
    #expect(populated.profile.repeatMagnets?.isDisplayable == true)
    #expect(populated.profile.repeatMagnets?.visibleItems.map(\.kind) == ["artist", "album", "artist"])
    #expect(populated.profile.repeatMagnets?.visibleItems.map(\.name) == ["The xx", "xx", "Asha"])
    #expect(populated.profile.repeatMagnets?.visibleItems.first?.count == 4)
    #expect(populated.profile.repeatMagnets?.visibleItems.dropFirst().first?.formatted == "40m")
    #expect(populated.profile.explicitPositives?.isDisplayable == true)
    #expect(populated.profile.explicitPositives?.signalCount == 3)
    #expect(populated.profile.explicitPositives?.visibleFavoriteTracks.first?.title == "Favorite One")
    #expect(populated.profile.explicitPositives?.visibleFavoriteTracks.first?.artist == "Asha")
    #expect(populated.profile.explicitPositives?.visibleAcceptedRecommendations.first?.title == "Try This")
    #expect(populated.profile.explicitPositives?.visibleAcceptedRecommendations.first?.subtitle == "Warm groove")
    #expect(populated.profile.explicitPositives?.visibleAcceptedRecommendations.first?.reason == "matched_mood")
    #expect(populated.profile.tasteAnchors?.isDisplayable == true)
    #expect(populated.profile.tasteAnchors?.visibleItems.map(\.kind) == ["artist", "genre", "genre", "artist", "genre"])
    #expect(populated.profile.tasteAnchors?.visibleItems.map(\.name) == ["The xx", "ambient", "melodic house", "Asha", "indie electronic"])
    #expect(populated.profile.tasteAnchors?.visibleItems.first?.playCount == 6)
    #expect(populated.profile.mood?.value == 90)
    #expect(populated.profile.mood?.zone == "party")
    #expect(populated.profile.mood?.sampleCount == 3)
    #expect(populated.profile.mood?.average == 57)
    #expect(populated.profile.mood?.averageZone == "groove")
    #expect(populated.profile.mood?.zoneCounts["party"] == 1)
    #expect(populated.profile.energyProfile?.sampleCount == 2)
    #expect(populated.profile.energyProfile?.energyPercent == 70)
    #expect(populated.profile.energyProfile?.zone == "energy")
    #expect(populated.profile.energyProfile?.danceabilityPercent == 54)
    #expect(populated.profile.energyProfile?.intensityPercent == 62)
    #expect(populated.profile.energyProfile?.recentSignals.first?.title == "Dream On")
    #expect(populated.profile.energyProfile?.recentSignals.first?.artist == "Scala")
    #expect(populated.profile.energyProfile?.recentSignals.first?.album == "Dream On")
    #expect(populated.sources.first?.title == "Music DNA")
    #expect(empty.enabled == true)
    #expect(empty.profile.isEmpty == true)
    #expect(empty.profile.recentFavoriteTracks == nil)
    #expect(empty.profile.playtime == nil)
    #expect(disabled.enabled == false)
    #expect(disabled.profile.isEmpty == true)
    #expect(summaryOnly.enabled == true)
    #expect(summaryOnly.profile.summary == "Compact Music DNA summary.")
    #expect(summaryOnly.profile.isEmpty == false)
    #expect(summaryOnly.profile.favoriteGenres == nil)
    #expect(summaryOnly.profile.favoriteArtists == nil)
    #expect(summaryOnly.profile.recentTracks == nil)
    #expect(summaryOnly.profile.playtime == nil)
    #expect(zeroPlaytime.profile.playtime?.isDisplayable == false)
    #expect(zeroPlaytime.profile.isEmpty == true)
    #expect(emptyDashboardBlocks.profile.listeningRhythm?.isDisplayable == false)
    #expect(emptyDashboardBlocks.profile.moodMix?.isDisplayable == false)
    #expect(emptyDashboardBlocks.profile.isEmpty == true)
    #expect(lowSampleListeningRhythm.profile.isEmpty == false)
    #expect(lowSampleListeningRhythm.profile.listeningRhythm?.isDisplayable == false)
    #expect(ineligibleConditionalBlocks.profile.repeatMagnets?.isDisplayable == false)
    #expect(ineligibleConditionalBlocks.profile.repeatMagnets?.reason == "insufficient_repeat_signals")
    #expect(ineligibleConditionalBlocks.profile.explicitPositives?.isDisplayable == false)
    #expect(ineligibleConditionalBlocks.profile.explicitPositives?.reason == "no_explicit_positive_signals")
    #expect(ineligibleConditionalBlocks.profile.tasteAnchors?.isDisplayable == false)
    #expect(ineligibleConditionalBlocks.profile.tasteAnchors?.reason == "insufficient_anchor_signals")
    #expect(ineligibleConditionalBlocks.profile.isEmpty == true)
    #expect(eligibleEmptyConditionalBlocks.profile.repeatMagnets?.isDisplayable == false)
    #expect(eligibleEmptyConditionalBlocks.profile.explicitPositives?.isDisplayable == false)
    #expect(eligibleEmptyConditionalBlocks.profile.tasteAnchors?.isDisplayable == false)
    #expect(eligibleEmptyConditionalBlocks.profile.isEmpty == true)
}

@Test func musicDiscoveryResponseParsesDisabledFeedAndFiltersInvalidItems() throws {
    let disabled = try JSONDecoder().decode(
        DJConnectMusicDiscoveryResponse.self,
        from: Data(#"{"success":true,"enabled":false,"reason":"music_dna_disabled","sections":[]}"#.utf8)
    )
    let feed = try JSONDecoder().decode(
        DJConnectMusicDiscoveryResponse.self,
        from: Data("""
        {
          "success": true,
          "enabled": true,
          "revision": 12,
          "generated_at": "2026-07-04T12:00:00+00:00",
          "ttl_seconds": 86400,
          "source": "music_dna",
          "sections": [
            {
              "id": "because_you_like",
              "title": "Omdat je dit vaak luistert",
              "items": [
                {
                  "id": "disc-track-1",
                  "kind": "track",
                  "title": "Intro",
                  "subtitle": "The xx",
                  "uri": "spotify:track:intro",
                  "image_url": "/api/djconnect/image_proxy/intro",
                  "reason": "Past bij je smaakankers.",
                  "reason_sources": ["taste_anchors", "favorite_genres"],
                  "confidence": "medium"
                },
                {
                  "id": "missing-reason",
                  "kind": "track",
                  "title": "Hidden",
                  "uri": "spotify:track:hidden",
                  "reason": ""
                },
                {
                  "id": "missing-uri",
                  "kind": "album",
                  "title": "Hidden Album",
                  "reason": "No play uri."
                }
              ]
            },
            {
              "id": "empty",
              "title": "Empty",
              "items": []
            }
          ]
        }
        """.utf8)
    )

    #expect(disabled.enabled == false)
    #expect(disabled.isMusicDNADisabled == true)
    #expect(disabled.visibleSections.isEmpty)
    #expect(feed.enabled == true)
    #expect(feed.revision == 12)
    #expect(feed.generatedAt != nil)
    #expect(feed.ttlSeconds == 86400)
    #expect(feed.source == "music_dna")
    #expect(feed.visibleSections.map(\.id) == ["because_you_like"])
    let item = try #require(feed.visibleSections.first?.visibleItems.first)
    #expect(item.id == "disc-track-1")
    #expect(item.kind == .track)
    #expect(item.title == "Intro")
    #expect(item.subtitle == "The xx")
    #expect(item.imageURL == "/api/djconnect/image_proxy/intro")
    #expect(item.reasonSources == ["taste_anchors", "favorite_genres"])
    #expect(item.confidence == .medium)
    #expect(feed.sections.first?.items.count == 3)
    #expect(feed.sections.first?.visibleItems.count == 1)
}

@MainActor
@Test func musicDNAProfileLoadsPopulatedBackendProfile() async throws {
    let defaults = try testDefaults()
    let recorder = RequestRecorder()
    let session = mockSession(host: "musicdna-populated.local") { request in
        recorder.append(request)
        return (try httpResponse(for: request, statusCode: 200), Data("""
        {
          "success": true,
          "music_dna_key": "user:abc123",
          "enabled": true,
          "generation": 2,
          "updated_at": "2026-07-04T05:00:00Z",
          "profile": {
            "summary": "Warm late-night electronic taste.",
            "track_count": 12,
            "artist_count": 4,
            "genre_count": 3,
            "favorite_genres": ["ambient", {"name": "melodic house", "count": 2}],
            "favorite_artists": ["The xx"],
            "recent_tracks": [{"title": "Intro", "artist": "The xx", "genres": ["indie"]}],
            "recent_favorite_tracks": [{"title": "Favorited", "artist": "Nala", "album": "Late Set"}],
            "playtime": {
              "total_seconds": 7260,
              "total_hours": 2.02,
              "formatted_total": "2u 1m",
              "top_artists": [
                {"name": "The xx", "seconds": 3600, "hours": 1.0, "formatted": "1u"},
                {"name": "Nala", "seconds": 2400, "hours": 0.67, "formatted": "40m"},
                {"name": "Ben Bohmer", "seconds": 900, "hours": 0.25, "formatted": "15m"},
                {"name": "Overflow", "seconds": 360, "hours": 0.1, "formatted": "6m"}
              ],
              "top_albums": [
                {"name": "xx", "seconds": 3300, "hours": 0.92, "formatted": "55m"},
                {"name": "Late Set", "seconds": 1800, "hours": 0.5, "formatted": "30m"}
              ]
            },
            "listening_rhythm": {
              "sample_count": 5,
              "top_daypart": "avond",
              "top_weekday": "vrijdag",
              "dayparts": [
                {"daypart": "avond", "count": 4, "percent": 80},
                {"daypart": "middag", "count": 1, "percent": 20}
              ],
              "weekdays": [
                {"weekday": "vrijdag", "count": 3, "percent": 60},
                {"weekday": "zaterdag", "count": 2, "percent": 40}
              ]
            },
            "mood_mix": {
              "sample_count": 3,
              "average": 57,
              "top_zone": "groove",
              "zones": [
                {"zone": "groove", "count": 2, "percent": 66.7},
                {"zone": "energy", "count": 1, "percent": 33.3}
              ]
            },
            "repeat_magnets": {
              "eligible": true,
              "items": [
                {"kind": "artist", "name": "The xx", "count": 5},
                {"kind": "album", "name": "xx", "formatted": "55m"}
              ]
            },
            "explicit_positives": {
              "eligible": true,
              "signal_count": 2,
              "favorite_tracks": [{"kind": "favorite_track", "title": "Favorited", "artist": "Nala"}],
              "accepted_recommendations": [{"kind": "accepted_recommendation", "title": "Accepted", "subtitle": "Warm"}]
            },
            "taste_anchors": {
              "eligible": true,
              "items": [
                {"kind": "artist", "name": "The xx", "play_count": 7},
                {"kind": "genre", "name": "ambient"}
              ]
            },
            "mood_profile": {"average": 57, "average_zone": "groove", "sample_count": 3},
            "taste_direction": "Warm electronic",
            "based_on": ["soft vocals", {"title": "Intro", "artist": "The xx", "genres": ["indie"]}],
            "updated_at": "2026-07-04T05:01:00Z"
          }
        }
        """.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "musicdna-populated.local", session: session)

    await model.refreshMusicDNAProfile()

    #expect(model.musicDNAProfileResponse?.enabled == true)
    #expect(model.musicDNAProfileResponse?.profile.isEmpty == false)
    #expect(model.musicDNAProfileResponse?.profile.summary == "Warm late-night electronic taste.")
    #expect(model.musicDNAProfileResponse?.profile.favoriteGenres?.first?.name == "ambient")
    #expect(model.musicDNAProfileResponse?.profile.favoriteGenres?.dropFirst().first?.count == 2)
    #expect(model.musicDNAProfileResponse?.profile.favoriteArtists?.first?.name == "The xx")
    #expect(model.musicDNAProfileResponse?.profile.trackCount == 12)
    #expect(model.musicDNAProfileResponse?.profile.recentFavoriteTracks?.map(\.title) == ["Favorited"])
    #expect(model.musicDNAProfileResponse?.profile.playtime?.isDisplayable == true)
    #expect(model.musicDNAProfileResponse?.profile.playtime?.formattedTotal == "2u 1m")
    #expect(model.musicDNAProfileResponse?.profile.playtime?.visibleTopArtists.map(\.name) == ["The xx", "Nala", "Ben Bohmer"])
    #expect(model.musicDNAProfileResponse?.profile.playtime?.visibleTopArtists.map(\.formatted) == ["1u", "40m", "15m"])
    #expect(model.musicDNAProfileResponse?.profile.playtime?.visibleTopAlbums.map(\.name) == ["xx", "Late Set"])
    #expect(model.musicDNAProfileResponse?.profile.playtime?.visibleTopAlbums.map(\.formatted) == ["55m", "30m"])
    #expect(model.musicDNAProfileResponse?.profile.listeningRhythm?.isDisplayable == true)
    #expect(model.musicDNAProfileResponse?.profile.listeningRhythm?.topDaypart == "avond")
    #expect(model.musicDNAProfileResponse?.profile.listeningRhythm?.topWeekday == "vrijdag")
    #expect(model.musicDNAProfileResponse?.profile.moodMix?.isDisplayable == true)
    #expect(model.musicDNAProfileResponse?.profile.moodMix?.topZone == "groove")
    #expect(model.musicDNAProfileResponse?.profile.moodMix?.average == 57)
    #expect(model.musicDNAProfileResponse?.profile.repeatMagnets?.isDisplayable == true)
    #expect(model.musicDNAProfileResponse?.profile.repeatMagnets?.visibleItems.map(\.name) == ["The xx", "xx"])
    #expect(model.musicDNAProfileResponse?.profile.explicitPositives?.isDisplayable == true)
    #expect(model.musicDNAProfileResponse?.profile.explicitPositives?.visibleFavoriteTracks.map(\.title) == ["Favorited"])
    #expect(model.musicDNAProfileResponse?.profile.explicitPositives?.visibleAcceptedRecommendations.map(\.title) == ["Accepted"])
    #expect(model.musicDNAProfileResponse?.profile.tasteAnchors?.isDisplayable == true)
    #expect(model.musicDNAProfileResponse?.profile.tasteAnchors?.visibleItems.map(\.name) == ["The xx", "ambient"])
    #expect(model.musicDNAProfileResponse?.profile.mood?.averageZone == "groove")
    #expect(model.musicDNAProfileResponse?.profile.tasteDirection == "Warm electronic")
    #expect(model.musicDNAProfileResponse?.profile.basedOn?.map { $0.title ?? $0.name ?? "" } == ["soft vocals", "Intro"])
    #expect(model.musicDNAProfileResponse?.profile.updatedAt != nil)
    #expect(recorder.requests.map { $0.url?.path } == ["/api/djconnect/v1/music_dna/profile"])
}

@MainActor
@Test func musicDNAProfileLoadsEnabledEmptyState() async throws {
    let defaults = try testDefaults()
    let session = mockSession(host: "musicdna-empty.local") { request in
        (try httpResponse(for: request, statusCode: 200), Data(#"{"success":true,"enabled":true,"profile":{}}"#.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "musicdna-empty.local", session: session)

    await model.refreshMusicDNAProfile()

    #expect(model.musicDNAProfileResponse?.enabled == true)
    #expect(model.musicDNAProfileResponse?.profile.isEmpty == true)
    #expect(model.musicDNAProfileResponse?.profile.recentFavoriteTracks == nil)
    #expect(model.musicDNAProfileResponse?.profile.playtime == nil)
    #expect(model.musicDNAProfileResponse?.profile.listeningRhythm == nil)
    #expect(model.musicDNAProfileResponse?.profile.moodMix == nil)
    #expect(model.musicDNAProfileResponse?.profile.repeatMagnets == nil)
    #expect(model.musicDNAProfileResponse?.profile.explicitPositives == nil)
    #expect(model.musicDNAProfileResponse?.profile.tasteAnchors == nil)
}

@MainActor
@Test func musicDNAProfileLoadsDisabledOptInStateWithoutLocalProfile() async throws {
    let defaults = try testDefaults()
    let session = mockSession(host: "musicdna-disabled.local") { request in
        (try httpResponse(for: request, statusCode: 200), Data(#"{"success":true,"enabled":false,"profile":{}}"#.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "musicdna-disabled.local", session: session)

    await model.refreshMusicDNAProfile()

    #expect(model.musicDNAProfileResponse?.enabled == false)
    #expect(model.musicDNAProfileResponse?.profile.isEmpty == true)
}

@MainActor
@Test func musicDiscoveryLoadsDisabledFeedAndEnabledRecommendations() async throws {
    let defaults = try testDefaults()
    let recorder = RequestRecorder()
    var enabled = false
    let session = mockSession(host: "discovery-feed.local") { request in
        recorder.append(request)
        if enabled {
            return (try httpResponse(for: request, statusCode: 200), Data("""
            {
              "success": true,
              "enabled": true,
              "revision": 7,
              "generated_at": "2026-07-04T12:00:00+00:00",
              "ttl_seconds": 86400,
              "source": "music_dna",
              "sections": [
                {
                  "id": "because_you_like",
                  "title": "Omdat je dit vaak luistert",
                  "items": [
                    {"id":"disc-track-1","kind":"track","title":"Intro","subtitle":"The xx","uri":"spotify:track:intro","reason":"Past bij je smaakankers.","confidence":"high"}
                  ]
                }
              ]
            }
            """.utf8))
        }
        return (try httpResponse(for: request, statusCode: 200), Data(#"{"success":true,"enabled":false,"reason":"music_dna_disabled","sections":[]}"#.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "discovery-feed.local", session: session)

    await model.loadMusicDiscovery(force: true)
    #expect(model.musicDiscoveryResponse?.isMusicDNADisabled == true)
    #expect(model.musicDiscoveryResponse?.visibleSections.isEmpty == true)

    enabled = true
    await model.loadMusicDiscovery(force: true)
    #expect(model.musicDiscoveryResponse?.enabled == true)
    #expect(model.musicDiscoveryResponse?.visibleSections.first?.visibleItems.first?.title == "Intro")
    #expect(recorder.requests.map { $0.url?.path } == [
        "/api/djconnect/v1/music_discovery",
        "/api/djconnect/v1/music_discovery"
    ])
}

@MainActor
@Test func musicDiscoveryRefreshAndPlayUseDedicatedEndpoints() async throws {
    let defaults = try testDefaults()
    let recorder = RequestRecorder()
    let session = mockSession(host: "discovery-actions.local") { request in
        recorder.append(request)
        switch request.url?.path {
        case "/api/djconnect/v1/music_discovery/refresh":
            return (try httpResponse(for: request, statusCode: 200), Data("""
            {
              "success": true,
              "enabled": true,
              "revision": 8,
              "sections": [
                {
                  "id": "fresh",
                  "title": "Fresh",
                  "items": [
                    {"id":"disc-track-2","kind":"track","title":"Angel","subtitle":"Massive Attack","uri":"spotify:track:angel","reason":"Past bij je donkere groove-signalen."}
                  ]
                }
              ]
            }
            """.utf8))
        case "/api/djconnect/v1/music_discovery":
            return (try httpResponse(for: request, statusCode: 200), Data(#"{"success":true,"enabled":true,"sections":[]}"#.utf8))
        case "/api/djconnect/v1/music_discovery/play":
            return (try httpResponse(for: request, statusCode: 200), Data(#"{"success":true}"#.utf8))
        default:
            return (try httpResponse(for: request, statusCode: 404), Data(#"{"success":false}"#.utf8))
        }
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "discovery-actions.local", session: session)

    await model.refreshMusicDiscovery()
    let item = try #require(model.musicDiscoveryResponse?.visibleSections.first?.visibleItems.first)
    await model.playMusicDiscoveryItem(item, sectionID: "fresh")

    #expect(recorder.requests.map { $0.url?.path } == [
        "/api/djconnect/v1/music_discovery/refresh",
        "/api/djconnect/v1/music_discovery/play"
    ])
}

@MainActor
@Test func musicDiscoveryRateLimitedRefreshFallsBackToFeed() async throws {
    let defaults = try testDefaults()
    let recorder = RequestRecorder()
    let session = mockSession(host: "discovery-rate-limited.local") { request in
        recorder.append(request)
        switch request.url?.path {
        case "/api/djconnect/v1/music_discovery/refresh":
            return (
                try httpResponse(for: request, statusCode: 429),
                Data(#"{"success":false,"error":"rate_limited","message":"Please wait"}"#.utf8)
            )
        case "/api/djconnect/v1/music_discovery":
            return (try httpResponse(for: request, statusCode: 200), Data("""
            {
              "success": true,
              "enabled": true,
              "revision": 9,
              "sections": [
                {
                  "id": "cached",
                  "title": "Cached",
                  "items": [
                    {"id":"disc-track-cache","kind":"track","title":"Cached recommendation","subtitle":"DJConnect","uri":"spotify:track:cached","reason":"Cached backend feed."}
                  ]
                }
              ]
            }
            """.utf8))
        default:
            return (try httpResponse(for: request, statusCode: 404), Data())
        }
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "discovery-rate-limited.local", session: session)

    let didRefresh = await model.refreshMusicDiscovery()

    #expect(didRefresh == true)
    #expect(model.musicDiscoveryResponse?.visibleSections.first?.visibleItems.first?.title == "Cached recommendation")
    #expect(recorder.requests.map { $0.url?.path } == [
        "/api/djconnect/v1/music_discovery/refresh",
        "/api/djconnect/v1/music_discovery"
    ])
}

@MainActor
@Test func musicDiscoveryDisabledRefreshDoesNotUseLocalFallbackRecommendations() async throws {
    let defaults = try testDefaults()
    let session = mockSession(host: "discovery-disabled.local") { request in
        #expect(request.url?.path == "/api/djconnect/v1/music_discovery/refresh")
        return (
            try httpResponse(for: request, statusCode: 200),
            Data(#"{"success":true,"enabled":false,"reason":"music_dna_disabled","sections":[]}"#.utf8)
        )
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "discovery-disabled.local", session: session)

    let didRefresh = await model.refreshMusicDiscovery()

    #expect(didRefresh == true)
    #expect(model.musicDiscoveryResponse?.isMusicDNADisabled == true)
    #expect(model.musicDiscoveryResponse?.visibleSections.isEmpty == true)
}

@MainActor
@Test func musicDiscoveryPushReceivedInBackgroundRefreshesBackend() async throws {
    let defaults = try testDefaults()
    let recorder = RequestRecorder()
    let session = mockSession(host: "discovery-push-background.local") { request in
        recorder.append(request)
        #expect(request.url?.path == "/api/djconnect/v1/music_discovery/refresh")
        return (try httpResponse(for: request, statusCode: 200), Data("""
        {
          "success": true,
          "enabled": true,
          "sections": [
            {
              "id": "daily",
              "title": "Daily",
              "items": [
                {"id":"daily-1","kind":"track","title":"Backend only","subtitle":"No push content","uri":"spotify:track:daily","reason":"Daily backend recommendation."}
              ]
            }
          ]
        }
        """.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "discovery-push-background.local", session: session)

    let handled = await model.handleRemoteNotificationPayload(musicDiscoveryPushPayload())

    #expect(handled == true)
    #expect(model.musicDiscoveryResponse?.visibleSections.first?.visibleItems.first?.title == "Backend only")
    #expect(model.musicDiscoveryResponse?.visibleSections.first?.visibleItems.first?.reason == "Daily backend recommendation.")
    #expect(model.musicDiscoveryResponse?.visibleSections.first?.visibleItems.first?.title != "Push payload track must be ignored")
    #expect(recorder.requests.count == 1)
}

@MainActor
@Test func musicDiscoveryPushTapNavigatesToDiscover() async throws {
    let defaults = try testDefaults()
    let session = mockSession(host: "discovery-push-tap.local") { request in
        #expect(request.url?.path == "/api/djconnect/v1/music_discovery/refresh")
        return (try httpResponse(for: request, statusCode: 200), Data(#"{"success":true,"enabled":true,"sections":[]}"#.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "discovery-push-tap.local", session: session)

    let handled = await model.handleRemoteNotificationPayload(musicDiscoveryPushPayload(), openedFromTap: true)

    #expect(handled == true)
    #expect(model.homeScreenActionRequest?.action == .discovery)
    #expect(DJConnectHomeScreenAction(deepLinkURL: try #require(URL(string: "djconnect://music-discovery"))) == .discovery)
}

@MainActor
@Test func musicDiscoveryPushNestedDataPayloadRefreshesBackend() async throws {
    let defaults = try testDefaults()
    let recorder = RequestRecorder()
    let session = mockSession(host: "discovery-push-nested.local") { request in
        recorder.append(request)
        #expect(request.url?.path == "/api/djconnect/v1/music_discovery/refresh")
        return (try httpResponse(for: request, statusCode: 200), Data(#"{"success":true,"enabled":true,"sections":[]}"#.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "discovery-push-nested.local", session: session)
    let nestedPayload: [AnyHashable: Any] = [
        "data": [
            "event_type": "music_discovery_ready",
            "open_target": "music_discovery",
            "refresh_target": "music_discovery",
            "deeplink": "djconnect://music-discovery"
        ],
        "aps": [
            "alert": [
                "title": "DJConnect",
                "body": "Je nieuwe aanbevelingen staan klaar!"
            ]
        ]
    ]

    let handled = await model.handleRemoteNotificationPayload(nestedPayload)

    #expect(handled == true)
    #expect(recorder.requests.count == 1)
}

@MainActor
@Test func musicDiscoveryPushReceiveAndTapCoalesceRefreshes() async throws {
    let defaults = try testDefaults()
    let recorder = RequestRecorder()
    let session = mockSession(host: "discovery-push-coalesce.local") { request in
        recorder.append(request)
        #expect(request.url?.path == "/api/djconnect/v1/music_discovery/refresh")
        return (try httpResponse(for: request, statusCode: 200), Data(#"{"success":true,"enabled":true,"sections":[]}"#.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "discovery-push-coalesce.local", session: session)

    _ = await model.handleRemoteNotificationPayload(musicDiscoveryPushPayload())
    _ = await model.handleRemoteNotificationPayload(musicDiscoveryPushPayload(), openedFromTap: true)

    #expect(recorder.requests.count == 1)
    #expect(model.homeScreenActionRequest?.action == .discovery)
}

@MainActor
@Test func clearMusicDNAUsesClearEndpointAndRefreshesProfile() async throws {
    let defaults = try testDefaults()
    let recorder = RequestRecorder()
    let session = mockSession(host: "musicdna-clear.local") { request in
        recorder.append(request)
        if request.url?.path == "/api/djconnect/v1/music_dna/clear" {
            return (try httpResponse(for: request, statusCode: 200), Data(#"{"success":true,"enabled":true,"profile":{}}"#.utf8))
        }
        return (try httpResponse(for: request, statusCode: 200), Data(#"{"success":true,"enabled":true,"profile":{}}"#.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "musicdna-clear.local", session: session)

    await model.clearMusicDNA()

    #expect(recorder.requests.map { $0.url?.path } == [
        "/api/djconnect/v1/music_dna/clear",
        "/api/djconnect/v1/music_dna/profile"
    ])
    #expect(model.musicDNAProfileResponse?.enabled == true)
    #expect(model.musicDNAProfileResponse?.profile.isEmpty == true)
}

@MainActor
@Test func optOutMusicDNAUsesSettingsEndpointAndRefreshesDisabledProfile() async throws {
    let defaults = try testDefaults()
    let recorder = RequestRecorder()
    let session = mockSession(host: "musicdna-optout.local") { request in
        recorder.append(request)
        return (try httpResponse(for: request, statusCode: 200), Data(#"{"success":true,"enabled":false,"profile":{}}"#.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "musicdna-optout.local", session: session)

    await model.setMusicDNAEnabled(false)

    #expect(recorder.requests.map { $0.url?.path } == [
        "/api/djconnect/v1/music_dna/settings",
        "/api/djconnect/v1/music_dna/profile"
    ])
    #expect(model.musicDNAProfileResponse?.enabled == false)
    #expect(model.musicDNAProfileResponse?.profile.isEmpty == true)
}

@MainActor
@Test func musicDNAOptInPromptWaitsForExplicitDisabledStatus() throws {
    let defaults = try testDefaults()
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )

    model.presentMusicDNAOptInPromptIfNeeded()
    #expect(model.isShowingMusicDNAOptInPrompt == false)

    model.pairingStatus = .paired
    model.presentMusicDNAOptInPromptIfNeeded()
    #expect(model.isShowingMusicDNAOptInPrompt == false)

    model.dismissMusicDNAOptInPrompt()
    #expect(model.isShowingMusicDNAOptInPrompt == false)

    model.presentMusicDNAOptInPromptIfNeeded()
    #expect(model.isShowingMusicDNAOptInPrompt == false)
}

@MainActor
@Test func optInMusicDNAUsesSettingsEndpointAndRefreshesProfile() async throws {
    let defaults = try testDefaults()
    let recorder = RequestRecorder()
    let session = mockSession(host: "musicdna-optin.local") { request in
        recorder.append(request)
        return (try httpResponse(for: request, statusCode: 200), Data("""
        {"success":true,"enabled":true,"profile":{"summary":"Newly enabled profile"}}
        """.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "musicdna-optin.local", session: session)

    await model.setMusicDNAEnabled(true)

    #expect(recorder.requests.map { $0.url?.path } == [
        "/api/djconnect/v1/music_dna/settings",
        "/api/djconnect/v1/music_dna/profile"
    ])
    #expect(model.musicDNAProfileResponse?.enabled == true)
    #expect(model.musicDNAProfileResponse?.profile.summary == "Newly enabled profile")
}

@MainActor
@Test func musicDNAOptInSurvivesStaleProfileRefresh() async throws {
    let defaults = try testDefaults()
    let recorder = RequestRecorder()
    let session = mockSession(host: "musicdna-stale-optin.local") { request in
        recorder.append(request)
        if request.url?.path == "/api/djconnect/v1/music_dna/settings" {
            return (try httpResponse(for: request, statusCode: 200), Data(#"{"success":true,"enabled":true,"profile":{"summary":"Enabled locally"}}"#.utf8))
        }
        return (try httpResponse(for: request, statusCode: 200), Data(#"{"success":true,"enabled":false,"profile":{}}"#.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "musicdna-stale-optin.local", session: session)

    await model.setMusicDNAEnabled(true)
    #expect(model.musicDNAProfileResponse?.enabled == true)
    #expect(model.musicDNAProfileResponse?.profile.summary == "Enabled locally")

    await model.refreshMusicDNAProfile()

    #expect(recorder.requests.map { $0.url?.path } == [
        "/api/djconnect/v1/music_dna/settings",
        "/api/djconnect/v1/music_dna/profile",
        "/api/djconnect/v1/music_dna/profile"
    ])
    #expect(model.musicDNAProfileResponse?.enabled == true)
    #expect(model.musicDNAProfileResponse?.profile.summary == "Enabled locally")
}

@MainActor
@Test func demoModeRequiresLocalMusicDNAOptInAndSupportsClear() async throws {
    let defaults = try testDefaults()
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )

    model.startDemoMode()

    #expect(model.isDemoMode == true)
    #expect(model.demoMusicDNAEnabled == false)
    #expect(model.musicDNAProfileResponse?.enabled == false)
    #expect(model.musicDNAProfileResponse?.profile.isEmpty == true)

    await model.setMusicDNAEnabled(true)

    #expect(model.demoMusicDNAEnabled == true)
    #expect(model.musicDNAProfileResponse?.enabled == true)
    #expect(model.musicDNAProfileResponse?.profile.summary == DJConnectLocalization.localized(key: "demo.music.dna.summary"))
    #expect(model.musicDNAProfileResponse?.profile.favoriteArtists?.map(\.name).contains("Luna Vale") == true)
    #expect(model.musicDNAProfileResponse?.profile.recentTracks?.map(\.title).contains("Glass Avenue") == true)
    #expect(model.musicDNAProfileResponse?.profile.recentFavoriteTracks?.isEmpty == false)
    #expect(model.musicDNAProfileResponse?.profile.playtime?.isDisplayable == true)
    #expect(model.musicDNAProfileResponse?.profile.listeningRhythm?.isDisplayable == true)
    #expect(model.musicDNAProfileResponse?.profile.moodMix?.isDisplayable == true)
    #expect(model.musicDNAProfileResponse?.profile.energyProfile?.sampleCount ?? 0 > 0)
    #expect(model.musicDNAProfileResponse?.profile.repeatMagnets?.isDisplayable == true)
    #expect(model.musicDNAProfileResponse?.profile.explicitPositives?.isDisplayable == true)
    #expect(model.musicDNAProfileResponse?.profile.tasteAnchors?.isDisplayable == true)
    #expect((model.musicDNAProfileResponse?.profile.timePatterns?.count ?? 0) >= 3)

    await model.clearMusicDNA()

    #expect(model.musicDNAProfileResponse?.enabled == true)
    #expect(model.musicDNAProfileResponse?.profile.favoriteArtists?.map(\.name).contains("Luna Vale") == true)
    #expect(model.musicDNAProfileResponse?.profile.recentTracks?.map(\.title).contains("Glass Avenue") == true)

    await model.setMusicDNAEnabled(false)

    #expect(model.demoMusicDNAEnabled == false)
    #expect(model.musicDNAProfileResponse?.enabled == false)
    #expect(model.musicDNAProfileResponse?.profile.isEmpty == true)
}

@MainActor
@Test func authFailureClearsMusicDNALocalDisplay() async throws {
    let defaults = try testDefaults()
    let recorder = RequestRecorder()
    let session = mockSession(host: "musicdna-auth.local") { request in
        recorder.append(request)
        if recorder.requests.count == 1 {
            return (try httpResponse(for: request, statusCode: 200), Data("""
            {"success":true,"enabled":true,"profile":{"summary":"Cached server display"}}
            """.utf8))
        }
        return (try httpResponse(for: request, statusCode: 401), Data(#"{"success":false,"error":"auth_stale"}"#.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "musicdna-auth.local", session: session)

    await model.refreshMusicDNAProfile()
    #expect(model.musicDNAProfileResponse?.profile.summary == "Cached server display")

    await model.refreshMusicDNAProfile()

    #expect(model.musicDNAProfileResponse == nil)
}

@MainActor
@Test func musicDNAExportAuthFailureUsesPairingRecoveryAndClearsLocalDisplay() async throws {
    let defaults = try testDefaults()
    let recorder = RequestRecorder()
    let session = mockSession(host: "musicdna-export-auth.local") { request in
        recorder.append(request)
        if request.url?.path == "/api/djconnect/v1/music_dna/profile" {
            return (try httpResponse(for: request, statusCode: 200), Data("""
            {"success":true,"enabled":true,"profile":{"summary":"Cached server display"}}
            """.utf8))
        }
        return (try httpResponse(for: request, statusCode: 403), Data(#"{"success":false,"error":"auth_stale","message":"Pair again"}"#.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "musicdna-export-auth.local", session: session)
    model.isConnected = true

    await model.refreshMusicDNAProfile()
    #expect(model.musicDNAProfileResponse?.profile.summary == "Cached server display")

    await #expect(throws: DJConnectError.self) {
        _ = try await model.exportMusicDNAProfileData()
    }

    #expect(recorder.requests.map { $0.url?.path } == [
        "/api/djconnect/v1/music_dna/profile",
        "/api/djconnect/v1/music_dna/export"
    ])
    #expect(model.musicDNAProfileResponse == nil)
    #expect(model.pairingStatus == .stale)
    #expect(model.pairingMessage?.isEmpty == false)
}

@Test func askDJIdleSuggestionRequestUsesDedicatedEndpoint() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-watchos-8F3A2C91B45D",
        deviceName: "Apple Watch",
        clientType: .watchos,
        firmware: "3.1.36",
        appVersion: "3.1.36",
        platform: .watchos
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.askDJIdleSuggestionRequest(DJConnectAskDJIdleSuggestionRequest(
        identity: identity,
        clientMessageID: "idle-suggestion-1",
        mood: 72,
        djStyle: "warm_radio_dj",
        musicDNAKey: "djconnect_watchos_8F3A2C91B45D"
    ))
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/v1/ask_dj/idle_suggestion")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(json?["client_message_id"] as? String == "idle-suggestion-1")
    #expect(json?["client_type"] as? String == "watchos")
    #expect(json?["mood"] as? Int == 72)
    #expect(json?["dj_style"] as? String == "warm_radio_dj")
}

@Test func pushRegisterRequestUsesAuthenticatedEndpointAndSandboxEnvironment() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.66",
        appVersion: "3.1.66",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.pushRegisterRequest(DJConnectPushRegistrationRequest(
        identity: identity,
        pushToken: "abcdef123456",
        pushEnvironment: .sandbox,
        appBundleID: "dev.djconnect.ios",
        locale: "nl-NL"
    ))
    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

    #expect(request.url?.path == "/api/djconnect/v1/push/register")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(json["device_id"] as? String == identity.deviceID)
    #expect(json["client_type"] as? String == "ios")
    #expect(json["push_token"] as? String == "abcdef123456")
    #expect(json["push_environment"] as? String == "sandbox")
    #expect(json["app_bundle_id"] as? String == "dev.djconnect.ios")
    #expect(json["locale"] as? String == "nl-NL")
    #expect(json["notification_categories"] as? [String] == ["ask_dj_response", "ask_dj_confirm"])
}

@Test func iOSPushRegisterRequestUsesCanonicalIdentityAndBootstrapProofWhenProvided() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.66",
        appVersion: "3.1.66",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.pushRegisterRequest(DJConnectPushRegistrationRequest(
        identity: identity,
        pushToken: "abcdef123456",
        pushEnvironment: .sandbox,
        appBundleID: "dev.djconnect.ios",
        locale: "nl-NL",
        bootstrapProof: "short-lived-proof"
    ))
    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

    #expect(request.url?.path == "/api/djconnect/v1/push/register")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(json["device_id"] as? String == "djconnect-ios-8F3A2C91B45D")
    #expect(json["client_type"] as? String == "ios")
    #expect(json["push_token"] as? String == "abcdef123456")
    #expect(json["push_environment"] as? String == "sandbox")
    #expect(json["app_bundle_id"] as? String == "dev.djconnect.ios")
    #expect(json["app_version"] as? String == "3.1.66")
    #expect(json["locale"] as? String == "nl-NL")
    #expect(json["notification_categories"] as? [String] == ["ask_dj_response", "ask_dj_confirm"])
    #expect(json["bootstrap_proof"] as? String == "short-lived-proof")
}

@Test func macOSPushRegisterRequestUsesCanonicalIdentityAndBootstrapProofWhenProvided() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-macos-8F3A2C91B45D",
        deviceName: "DJConnect Mac",
        clientType: .macos,
        firmware: "3.1.66",
        appVersion: "3.1.66",
        platform: .macos
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.pushRegisterRequest(DJConnectPushRegistrationRequest(
        identity: identity,
        pushToken: "abcdef123456",
        pushEnvironment: .sandbox,
        appBundleID: "dev.djconnect.mac",
        locale: "nl-NL",
        bootstrapProof: "short-lived-proof"
    ))
    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

    #expect(request.url?.path == "/api/djconnect/v1/push/register")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(json["device_id"] as? String == "djconnect-macos-8F3A2C91B45D")
    #expect(json["client_type"] as? String == "macos")
    #expect(json["push_token"] as? String == "abcdef123456")
    #expect(json["push_environment"] as? String == "sandbox")
    #expect(json["app_bundle_id"] as? String == "dev.djconnect.mac")
    #expect(json["app_version"] as? String == "3.1.66")
    #expect(json["locale"] as? String == "nl-NL")
    #expect(json["notification_categories"] as? [String] == ["ask_dj_response", "ask_dj_confirm"])
    #expect(json["bootstrap_proof"] as? String == "short-lived-proof")
}

@Test func pushEnvironmentResolvesDevelopmentEntitlementToSandbox() {
    #expect(DJConnectAppModel.pushEnvironment(apsEnvironment: "development") == .sandbox)
    #expect(DJConnectAppModel.pushEnvironment(apsEnvironment: "sandbox") == .sandbox)
    #expect(DJConnectAppModel.pushEnvironment(apsEnvironment: "production") == .production)
}

@Test func watchOSPushRegisterRequestUsesCanonicalIdentityAndBootstrapProofWhenProvided() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-watchos-8F3A2C91B45D",
        deviceName: "DJConnect Watch",
        clientType: .watchos,
        firmware: "3.1.66",
        appVersion: "3.1.66",
        platform: .watchos
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.pushRegisterRequest(DJConnectPushRegistrationRequest(
        identity: identity,
        pushToken: "abcdef123456",
        pushEnvironment: .sandbox,
        appBundleID: "dev.djconnect.watch",
        locale: "nl-NL",
        bootstrapProof: "short-lived-proof"
    ))
    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

    #expect(request.url?.path == "/api/djconnect/v1/push/register")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(json["device_id"] as? String == "djconnect-watchos-8F3A2C91B45D")
    #expect(json["client_type"] as? String == "watchos")
    #expect(json["push_token"] as? String == "abcdef123456")
    #expect(json["push_environment"] as? String == "sandbox")
    #expect(json["app_bundle_id"] as? String == "dev.djconnect.watch")
    #expect(json["app_version"] as? String == "3.1.66")
    #expect(json["locale"] as? String == "nl-NL")
    #expect(json["notification_categories"] as? [String] == ["ask_dj_response", "ask_dj_confirm"])
    #expect(json["bootstrap_proof"] as? String == "short-lived-proof")
}

@Test func pushLogRedactionRedactsSecretsRecursively() throws {
    let sanitized = DJConnectLogRedactor.sanitizeForLog([
        "push_token": "abcdef1234567890",
        "bootstrap_proof": "djcbootstrapproof1234567890",
        "Authorization": "Bearer secret-token-value",
        "nested": [
            "password": "super-secret-password",
            "safe": "visible"
        ]
    ]) as? [String: Any]

    #expect(sanitized?["push_token"] as? String == "abcdef...567890 (len=16)")
    #expect(sanitized?["bootstrap_proof"] as? String == "djcboo...567890 (len=27)")
    #expect(sanitized?["Authorization"] as? String == "Bearer...-value (len=25)")
    let nested = try #require(sanitized?["nested"] as? [String: Any])
    #expect(nested["password"] as? String == "super-...ssword (len=21)")
    #expect(nested["safe"] as? String == "visible")

    let rendered = DJConnectLogRedactor.sanitizedJSONString([
        "push_token": "abcdef1234567890",
        "Authorization": "Bearer secret-token-value"
    ])
    #expect(!rendered.contains("abcdef1234567890"))
    #expect(!rendered.contains("secret-token-value"))
}

@Test func pushUnregisterRequestUsesAuthenticatedEndpoint() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-macos-8F3A2C91B45D",
        deviceName: "DJConnect Mac",
        clientType: .macos,
        firmware: "3.1.66",
        appVersion: "3.1.66",
        platform: .macos
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.pushUnregisterRequest(DJConnectPushUnregistrationRequest(
        identity: identity,
        pushToken: "abcdef123456"
    ))
    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

    #expect(request.url?.path == "/api/djconnect/v1/push/unregister")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(json["device_id"] as? String == identity.deviceID)
    #expect(json["client_type"] as? String == "macos")
    #expect(json["push_token"] as? String == "abcdef123456")
}

@Test func commandResponseDecodesPushRegistrationStatusFields() throws {
    let json = """
    {
      "success": false,
      "error": "missing_bootstrap_proof",
      "data": {
        "push_supported": true,
        "push_registered": false,
        "push_environment": "sandbox",
        "last_push_error": "missing_bootstrap_proof"
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectCommandResponse.self, from: json)

    #expect(response.success == false)
    #expect(response.error == "missing_bootstrap_proof")
    #expect(response.pushSupported == true)
    #expect(response.pushRegistered == false)
    #expect(response.pushEnvironment == .sandbox)
    #expect(response.lastPushError == "missing_bootstrap_proof")
}

@Test func commandResponseDecodesDevelopmentPushEnvironmentAsSandbox() throws {
    let json = """
    {
      "success": true,
      "data": {
        "push_supported": true,
        "push_registered": true,
        "push_environment": "development"
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectCommandResponse.self, from: json)

    #expect(response.pushRegistered == true)
    #expect(response.pushEnvironment == .sandbox)
}

@MainActor
@Test func macOSDevelopmentPushRegistrationAcceptsCanonicalSandboxResponse() async throws {
    let defaults = try testDefaults()
    let recorder = RequestRecorder()
    let session = mockSession(host: "push-sandbox.local") { request in
        recorder.append(request)
        return (try httpResponse(for: request, statusCode: 200), Data("""
        {
          "success": true,
          "push_supported": true,
          "push_registered": true,
          "push_environment": "sandbox"
        }
        """.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "push-sandbox.local", session: session)

    model.handleRemoteNotificationDeviceToken(Data([0xab, 0xcd, 0xef, 0x12]))
    for _ in 0..<100 where defaults.string(forKey: "DJConnectPushEnvironmentStatus") == nil {
        try await Task.sleep(for: .milliseconds(100))
    }

    #expect(recorder.requests.map { $0.url?.path } == ["/api/djconnect/v1/push/register"])
    #expect(defaults.bool(forKey: "DJConnectPushRegistered") == true)
    #expect(defaults.string(forKey: "DJConnectPushEnvironmentStatus") == "sandbox")
    #expect(defaults.string(forKey: "DJConnectLastPushError") == nil)
}

@MainActor
@Test func macOSPushInvalidBootstrapProofMarksTemporaryRecoveryWithoutClearingPairing() async throws {
    let defaults = try testDefaults()
    let recorder = RequestRecorder()
    let session = mockSession(host: "push-invalid-bootstrap.local") { request in
        recorder.append(request)
        return (try httpResponse(for: request, statusCode: 200), Data("""
        {
          "success": false,
          "error": "invalid_bootstrap_proof",
          "push_supported": true,
          "push_registered": false,
          "push_environment": "sandbox",
          "last_push_error": "invalid_bootstrap_proof"
        }
        """.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "push-invalid-bootstrap.local", session: session)

    model.handleRemoteNotificationDeviceToken(Data([0xab, 0xcd, 0xef, 0x34]))
    for _ in 0..<100 where defaults.string(forKey: "DJConnectLastPushError") == nil {
        try await Task.sleep(for: .milliseconds(100))
    }

    #expect(recorder.requests.map { $0.url?.path } == ["/api/djconnect/v1/push/register"])
    #expect(defaults.bool(forKey: "DJConnectPushRegistered") == false)
    #expect(defaults.string(forKey: "DJConnectRegisteredPushSignature") == nil)
    #expect(defaults.string(forKey: "DJConnectLastPushError") == "invalid_bootstrap_proof")
    #expect(model.pairingStatus == .paired)
}

@MainActor
@Test func sandboxPushRegistrationRejectsProductionResponseEnvironment() async throws {
    let defaults = try testDefaults()
    let recorder = RequestRecorder()
    let session = mockSession(host: "push-production-mismatch.local") { request in
        recorder.append(request)
        return (try httpResponse(for: request, statusCode: 200), Data("""
        {
          "success": true,
          "push_supported": true,
          "push_registered": true,
          "push_environment": "production"
        }
        """.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: "push-production-mismatch.local", session: session)

    model.handleRemoteNotificationDeviceToken(Data([0xab, 0xcd, 0xef, 0x56]))
    for _ in 0..<100 where defaults.string(forKey: "DJConnectLastPushError") == nil {
        try await Task.sleep(for: .milliseconds(100))
    }

    #expect(recorder.requests.map { $0.url?.path } == ["/api/djconnect/v1/push/register"])
    #expect(defaults.bool(forKey: "DJConnectPushRegistered") == false)
    #expect(defaults.string(forKey: "DJConnectRegisteredPushSignature") == nil)
    #expect(defaults.string(forKey: "DJConnectLastPushError") == "push_environment_mismatch")
}

@Test func askDJHistoryResponseDecodesRevisionAndRichMessages() throws {
    let json = """
    {
      "user_id": "ha-user-1",
      "history_revision": 42,
      "clear_revision": 7,
      "server_time": "2026-06-19T12:35:00Z",
      "messages": [
        {
          "id": "server-user-message-id",
          "client_message_id": "client-message-1",
          "exchange_id": "exchange-1",
          "exchange_order": 0,
          "role": "user",
          "text": "Welke albums bracht deze artiest uit?",
          "created_at": "2026-06-19T12:34:56Z",
          "client_id": "iphone_peter",
          "client_type": "ios",
          "status": "delivered"
        },
        {
          "id": "server-assistant-message-id",
          "exchange_id": "exchange-1",
          "exchange_order": 1,
          "role": "assistant",
          "text": "Hier zijn een paar albums.",
          "created_at": "2026-06-19T12:34:58Z",
          "images": [
            {
              "url": "http://homeassistant.local:8123/api/djconnect/image_proxy/album/123",
              "title": "Album Title"
            }
          ],
          "links": [
            {
              "url": "https://example.com/discography",
              "title": "Discografie"
            }
          ],
          "sources": [
            {
              "url": "https://example.com/source",
              "title": "Bron"
            }
          ],
          "audio_url": "http://homeassistant.local:8123/api/djconnect/audio/response-123.mp3",
          "playback_actions": [
            {
              "id": "spotify:album:123",
              "title": "Album Title",
              "context_uri": "spotify:album:123",
              "kind": "album"
            }
          ]
        }
      ]
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJHistoryResponse.self, from: json)
    let userMessage = try #require(response.messages.first)
    let assistantMessage = try #require(response.messages.last)

    #expect(response.userID == "ha-user-1")
    #expect(response.historyRevision == 42)
    #expect(response.clearRevision == 7)
    #expect(response.serverTime != nil)
    #expect(userMessage.clientMessageID == "client-message-1")
    #expect(userMessage.exchangeID == "exchange-1")
    #expect(userMessage.exchangeOrder == 0)
    #expect(userMessage.role == .user)
    #expect(userMessage.messageKind == .assistant)
    #expect(userMessage.origin == nil)
    #expect(userMessage.clientType == .ios)
    #expect(assistantMessage.role == .assistant)
    #expect(assistantMessage.exchangeID == "exchange-1")
    #expect(assistantMessage.exchangeOrder == 1)
    #expect(assistantMessage.messageKind == .assistant)
    #expect(assistantMessage.origin == nil)
    #expect(assistantMessage.images.count == 1)
    #expect(assistantMessage.links.count == 2)
    #expect(assistantMessage.sources.count == 1)
    #expect(assistantMessage.audioURL?.path == "/api/djconnect/audio/response-123.mp3")
    #expect(assistantMessage.playbackActions.first?.contextURI == "spotify:album:123")
}

@Test func askDJHistoryResponseDecodesRaspberryPiClientType() throws {
    let json = """
    {
      "history_revision": 35,
      "messages": [
        {
          "id": "server-rpi-message-id",
          "role": "user",
          "text": "Stemverzoek",
          "created_at": "2026-06-19T21:38:00Z",
          "client_id": "djconnect-rpi-livingroom",
          "client_type": "raspberry_pi",
          "status": "delivered"
        }
      ]
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJHistoryResponse.self, from: json)
    let message = try #require(response.messages.first)

    #expect(message.clientType == .raspberryPi)
}

@Test func askDJHistoryResponseDecodesSystemAmbientMessageWithoutUser() throws {
    let json = """
    {
      "history_revision": 50,
      "clear_revision": 8,
      "messages": [
        {
          "id": "ambient-1",
          "role": "assistant",
          "message_kind": "system",
          "origin": "spotify_playback_context",
          "text": "Leuk feitje over OK Computer.",
          "created_at": "2026-06-19T12:40:00Z",
          "audio_url": null
        }
      ]
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJHistoryResponse.self, from: json)
    let message = try #require(response.messages.first)

    #expect(response.historyRevision == 50)
    #expect(response.clearRevision == 8)
    #expect(message.role == .assistant)
    #expect(message.messageKind == .system)
    #expect(message.origin == "spotify_playback_context")
    #expect(message.audioURL == nil)
}

@Test func askDJLocalMessageDefaultsMissingMessageKindToAssistant() throws {
    let json = """
    {
      "role": "dj",
      "text": "Normaal antwoord zonder expliciete message_kind."
    }
    """.data(using: .utf8)!

    let message = try JSONDecoder().decode(DJConnectAskDJMessage.self, from: json)

    #expect(message.role == .dj)
    #expect(message.messageKind == .assistant)
    #expect(message.origin == nil)
    #expect(message.audioURL == nil)
}

@Test func askDJMessageResponseAcceptsInformationalTextWithoutAudioURL() throws {
    let json = """
    {
      "history_revision": 43,
      "clear_revision": 7,
      "assistant_message": {
        "id": "server-assistant-text-only",
        "role": "assistant",
        "text": "M83 is een Franse elektronische band uit Antibes.",
        "created_at": "2026-06-19T12:35:00Z"
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)

    #expect(response.historyRevision == 43)
    #expect(response.clearRevision == 7)
    #expect(response.audioURL == nil)
    #expect(response.assistantMessage?.messageKind == .assistant)
    #expect(response.assistantMessage?.text == "M83 is een Franse elektronische band uit Antibes.")
    #expect(response.assistantMessage?.audioURL == nil)
}

@Test func askDJMessageResponseDecodesMoodMetadataForAssistantRendering() throws {
    let payload = Data("""
    {
      "dj_text": "Dit past bij de energie van nu.",
      "mood_context": {
        "value": 82,
        "zone": "energy"
      },
      "assistant_message": {
        "id": "server-assistant-mood",
        "role": "assistant",
        "text": "Energy bubble.",
        "created_at": "2026-07-03T20:00:00Z"
      },
      "messages": [
        {
          "id": "server-user-mood",
          "role": "user",
          "text": "Wat past hierbij?",
          "created_at": "2026-07-03T19:59:58Z"
        },
        {
          "id": "server-assistant-list-mood",
          "role": "assistant",
          "text": "Energy bubble.",
          "created_at": "2026-07-03T20:00:00Z"
        }
      ]
    }
    """.utf8)

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: payload)

    #expect(response.mood == 82)
    #expect(response.assistantMessage?.mood == 82)
    #expect(response.messages.first(where: { $0.role == .user })?.mood == nil)
    #expect(response.messages.first(where: { $0.role == .assistant })?.mood == 82)
}

@Test func askDJHistoryMessageDecodesOwnMoodMetadata() throws {
    let payload = Data("""
    {
      "id": "assistant-party",
      "role": "assistant",
      "text": "Party bubble.",
      "mood": 94,
      "created_at": "2026-07-03T20:00:00Z"
    }
    """.utf8)

    let message = try JSONDecoder().decode(DJConnectAskDJHistoryMessage.self, from: payload)

    #expect(message.mood == 94)
}

@Test func trackInsightRequestUsesDirectEndpointAndPayload() throws {
    let client = DJConnectClient(
        baseURL: URL(string: "http://homeassistant.local:8123")!,
        identity: DJConnectIdentity(
            deviceID: "djconnect-ios-8F3A2C91B45D",
            deviceName: "iPhone",
            clientType: .ios,
            firmware: "3.2.0",
            appVersion: "3.2.0",
            platform: .ios
        ),
        tokenStore: DJConnectInMemoryTokenStore(token: "token")
    )

    let request = try client.trackInsightRequest(DJConnectTrackInsightRequest(
        title: "Innerbloom",
        artist: "RUFUS DU SOL",
        album: "Bloom",
        artworkURL: URL(string: "https://example.com/innerbloom.jpg"),
        durationMS: 544_000,
        progressMS: 123_000,
        entityID: "media_player.living_room",
        playerID: "spotify-player",
        musicBackend: "spotify",
        clientType: "ios",
        forceRefresh: true,
        locale: "nl",
        mood: 70,
        musicDNAKey: "djconnect_ios_djconnect-ios-8F3A2C91B45D",
        includeVisualProfile: true,
        includeRawResponse: true
    ))
    let body = try #require(request.httpBody)
    let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.httpMethod == "POST")
    #expect(request.url?.path == "/api/djconnect/v1/track_insight")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Language") == "nl")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Locale") == "nl")
    #expect(request.value(forHTTPHeaderField: "Accept-Language") == "nl")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Mood") == "70")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Music-DNA-Key") == "djconnect_ios_djconnect-ios-8F3A2C91B45D")
    #expect((object?["device_id"] as? String) == "djconnect-ios-8F3A2C91B45D")
    #expect((object?["client_id"] as? String) == "djconnect-ios-8F3A2C91B45D")
    #expect((object?["device_name"] as? String) == "iPhone")
    #expect((object?["client_type"] as? String) == "ios")
    let topIdentity = object?["identity"] as? [String: Any]
    let payload = object?["payload"] as? [String: Any]
    let payloadIdentity = payload?["identity"] as? [String: Any]
    #expect(topIdentity?["device_id"] as? String == "djconnect-ios-8F3A2C91B45D")
    #expect(topIdentity?["client_id"] as? String == "djconnect-ios-8F3A2C91B45D")
    #expect(topIdentity?["client_type"] as? String == "ios")
    #expect(topIdentity?["device_token"] as? String == "token")
    #expect(payload?["track_name"] as? String == "Innerbloom")
    #expect(payloadIdentity?["device_id"] as? String == "djconnect-ios-8F3A2C91B45D")
    #expect(payloadIdentity?["device_token"] as? String == "token")
    #expect((object?["title"] as? String) == "Innerbloom")
    #expect((object?["track_name"] as? String) == "Innerbloom")
    #expect((object?["artist"] as? String) == "RUFUS DU SOL")
    #expect((object?["artist_name"] as? String) == "RUFUS DU SOL")
    #expect((object?["album"] as? String) == "Bloom")
    #expect((object?["album_name"] as? String) == "Bloom")
    #expect((object?["artwork_url"] as? String) == "https://example.com/innerbloom.jpg")
    let track = object?["track"] as? [String: Any]
    #expect(track?["title"] as? String == "Innerbloom")
    #expect(track?["artist"] as? String == "RUFUS DU SOL")
    #expect(track?["album"] as? String == "Bloom")
    #expect(track?["artwork_url"] as? String == "https://example.com/innerbloom.jpg")
    #expect(track?["duration_ms"] as? Int == 544_000)
    #expect(track?["progress_ms"] as? Int == 123_000)
    #expect(track?["entity_id"] as? String == "media_player.living_room")
    #expect(track?["player_id"] as? String == "spotify-player")
    #expect(track?["backend"] as? String == "spotify")
    #expect((object?["duration_ms"] as? Int) == 544_000)
    #expect((object?["progress_ms"] as? Int) == 123_000)
    #expect((object?["entity_id"] as? String) == "media_player.living_room")
    #expect((object?["player_id"] as? String) == "spotify-player")
    #expect((object?["music_backend"] as? String) == "spotify")
    #expect((object?["force_refresh"] as? Bool) == true)
    #expect((object?["locale"] as? String) == "nl")
    #expect((object?["language"] as? String) == "nl")
    #expect((object?["mood"] as? Int) == 70)
    #expect((object?["music_dna_key"] as? String) == "djconnect_ios_djconnect-ios-8F3A2C91B45D")
    #expect((object?["include_visual_profile"] as? Bool) == true)
    #expect((object?["include_raw_response"] as? Bool) == true)
}

@Test func trackInsightRequestUsesMacOSIdentityAliases() throws {
    let client = DJConnectClient(
        baseURL: URL(string: "http://homeassistant-mac.local:8123")!,
        identity: DJConnectIdentity(
            deviceID: "djconnect-macos-8F3A2C91B45D",
            deviceName: "DJConnect Mac",
            clientType: .macos,
            firmware: "3.2.0",
            appVersion: "3.2.0",
            platform: .macos
        ),
        tokenStore: DJConnectInMemoryTokenStore(token: "token")
    )

    let request = try client.trackInsightRequest(DJConnectTrackInsightRequest(
        title: "Natural Blues",
        artist: "Moby",
        forceRefresh: false,
        includeVisualProfile: true
    ))
    let body = try #require(request.httpBody)
    let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect((object?["device_id"] as? String) == "djconnect-macos-8F3A2C91B45D")
    #expect((object?["client_id"] as? String) == "djconnect-macos-8F3A2C91B45D")
    #expect((object?["device_name"] as? String) == "DJConnect Mac")
    #expect((object?["client_type"] as? String) == "macos")
    #expect((object?["title"] as? String) == "Natural Blues")
    #expect((object?["track_name"] as? String) == "Natural Blues")
    #expect((object?["artist"] as? String) == "Moby")
    #expect((object?["artist_name"] as? String) == "Moby")
}

@Test func vibeCastResponseDecodesSuccessAndStructuredText() throws {
    let json = Data(#"""
    {
      "enabled": true,
      "revision": 12,
      "ttl_seconds": 45,
      "poll_after_seconds": 20,
      "context": {
        "track_id": "track-1",
        "title": "Song Title",
        "artist": "Artist Name",
        "album": "Album Name",
        "music_backend": "music_assistant",
        "music_backend_name": "Music Assistant",
        "music_backend_revision": 2,
        "genre_badge": {
          "label": "melodic techno",
          "genre": "melodic-techno",
          "placement": "top_trailing"
        }
      },
      "items": [
        {
          "id": "fact-1",
          "kind": "track_fact",
          "tone": "playful",
          "priority": 50,
          "display_seconds": 8,
          "placement_hint": "side",
          "text": [
            { "type": "emoji", "value": "♪ ♫ " },
            { "type": "text", "value": "This track rides on " },
            { "type": "strong", "value": "space and pulse" },
            { "type": "text", "value": "." }
          ],
          "source": { "kind": "generated", "confidence": "medium" }
        }
      ],
      "cache": { "hit": false }
    }
    """#.utf8)

    let response = try JSONDecoder().decode(DJConnectVibeCastResponse.self, from: json)

    #expect(response.enabled == true)
    #expect(response.revision == 12)
    #expect(response.effectivePollAfterSeconds == 20)
    #expect(response.context?.musicBackend == "music_assistant")
    #expect(response.context?.genreBadge?.displayLabel == "melodic techno")
    #expect(response.context?.genreBadge?.canonicalGenre == "melodic-techno")
    #expect(response.context?.genreBadge?.resolvedPlacement == "top_trailing")
    #expect(response.items.first?.kind == .trackFact)
    #expect(response.items.first?.text[0].type == .emoji)
    #expect(response.items.first?.text[2].type == .strong)
    #expect(response.items.first?.plainText == "♪ ♫ This track rides on space and pulse.")
}

@Test func vibeCastGenreBadgeHidesWhenMissingOrLabelIsEmptyAndSupportsLongLabels() throws {
    let missing = try JSONDecoder().decode(
        DJConnectVibeCastResponse.self,
        from: Data(#"{"enabled":true,"context":{"track_id":"track-1"},"items":[]}"#.utf8)
    )
    #expect(missing.context?.genreBadge == nil)

    let empty = try JSONDecoder().decode(
        DJConnectVibeCastResponse.self,
        from: Data(#"{"enabled":true,"context":{"genre_badge":{"label":"   ","genre":"ambient-dub","placement":"middle"}},"items":[]}"#.utf8)
    )
    #expect(empty.context?.genreBadge?.displayLabel == nil)
    #expect(empty.context?.genreBadge?.canonicalGenre == "ambient-dub")
    #expect(empty.context?.genreBadge?.resolvedPlacement == "top_trailing")

    let long = try JSONDecoder().decode(
        DJConnectVibeCastResponse.self,
        from: Data(#"{"enabled":true,"context":{"genre_badge":{"label":"deep progressive melodic techno with organic house textures","genre":"deep-progressive-melodic-techno","placement":"sideways"}},"items":[]}"#.utf8)
    )
    #expect(long.context?.genreBadge?.displayLabel == "deep progressive melodic techno with organic house textures")
    #expect(long.context?.genreBadge?.canonicalGenre == "deep-progressive-melodic-techno")
    #expect(long.context?.genreBadge?.resolvedPlacement == "top_trailing")
}

@Test func vibeCastResponseDecodesDisabledAndUnknownSegmentsGracefully() throws {
    let disabled = try JSONDecoder().decode(
        DJConnectVibeCastResponse.self,
        from: Data(#"{"enabled":false,"reason":"no_active_playback","ttl_seconds":30,"poll_after_seconds":30,"items":[]}"#.utf8)
    )
    #expect(disabled.enabled == false)
    #expect(disabled.reason == "no_active_playback")
    #expect(disabled.items.isEmpty)

    let unknown = try JSONDecoder().decode(
        DJConnectVibeCastResponse.self,
        from: Data(#"{"enabled":true,"items":[{"id":"x","kind":"future_kind","text":[{"type":"sparkle","value":"safe fallback"}]}]}"#.utf8)
    )
    #expect(unknown.items.first?.kind == .unknown("future_kind"))
    #expect(unknown.items.first?.text.first?.type == .unknown("sparkle"))
    #expect(unknown.items.first?.plainText == "safe fallback")
}

@Test func vibeCastResponseDecodesOnlyProxiedContextArtistImage() throws {
    let response = try JSONDecoder().decode(
        DJConnectVibeCastResponse.self,
        from: Data(#"{"enabled":true,"revision":3,"context":{"artist_image_url":"/api/djconnect/v1/proxy/images/artist.jpg"},"items":[]}"#.utf8)
    )

    #expect(response.context?.artistImageURL?.absoluteString == "/api/djconnect/v1/proxy/images/artist.jpg")
    #expect(response.artistShoutOutImage?.url.absoluteString == "/api/djconnect/v1/proxy/images/artist.jpg")
    #expect(DJConnectVibeCastRenderState.rendered(from: response).artistImage?.url.absoluteString == "/api/djconnect/v1/proxy/images/artist.jpg")

    let external = try JSONDecoder().decode(
        DJConnectVibeCastResponse.self,
        from: Data(#"{"enabled":true,"context":{"artistImageUrl":"https://images.example.com/artist.jpg"},"items":[]}"#.utf8)
    )

    #expect(external.context?.artistImageURL == nil)
    #expect(external.artistShoutOutImage == nil)
}

@Test func vibeCastResponseDecodesEmojiOnlyBubbleSegments() throws {
    let single = try JSONDecoder().decode(
        DJConnectVibeCastResponse.self,
        from: Data(#"{"enabled":true,"items":[{"id":"single-emoji","kind":"mood_note","text":[{"type":"emoji","value":"🎧 "}]}]}"#.utf8)
    )
    #expect(single.items.first?.text.map(\.type) == [.emoji])
    #expect(single.items.first?.plainText == "🎧 ")

    let response = try JSONDecoder().decode(
        DJConnectVibeCastResponse.self,
        from: Data(#"{"enabled":true,"items":[{"id":"emoji","kind":"mood_note","text":[{"type":"emoji","value":"♪ ♫ "},{"type":"emoji","value":"✨ "},{"type":"emoji","value":"🎧 "}]}]}"#.utf8)
    )

    #expect(response.items.first?.text.map(\.type) == [.emoji, .emoji, .emoji])
    #expect(response.items.first?.plainText == "♪ ♫ ✨ 🎧 ")
}

@Test func vibeCastResponseStillDecodesLegacyStructuredTextWithoutEmoji() throws {
    let response = try JSONDecoder().decode(
        DJConnectVibeCastResponse.self,
        from: Data(#"{"enabled":true,"items":[{"id":"legacy","kind":"track_fact","text":[{"type":"text","value":"This track rides on "},{"type":"strong","value":"space and pulse"},{"type":"text","value":"."}]}]}"#.utf8)
    )

    #expect(response.items.first?.text.map(\.type) == [.text, .strong, .text])
    #expect(response.items.first?.plainText == "This track rides on space and pulse.")
}

@Test func vibeCastRequestsUseEquivalentIOSAndMacOSMetadata() throws {
    let iosClient = DJConnectClient(
        baseURL: URL(string: "http://homeassistant.local:8123")!,
        identity: DJConnectIdentity(
            deviceID: "djconnect-ios-8F3A2C91B45D",
            deviceName: "iPhone",
            clientType: .ios,
            firmware: "3.2.12",
            appVersion: "3.2.12",
            platform: .ios
        ),
        tokenStore: DJConnectInMemoryTokenStore(token: "token")
    )
    let macClient = DJConnectClient(
        baseURL: URL(string: "http://homeassistant.local:8123")!,
        identity: DJConnectIdentity(
            deviceID: "djconnect-macos-8F3A2C91B45D",
            deviceName: "Mac",
            clientType: .macos,
            firmware: "3.2.12",
            appVersion: "3.2.12",
            platform: .macos
        ),
        tokenStore: DJConnectInMemoryTokenStore(token: "token")
    )

    let payload = DJConnectVibeCastRequest(locale: "nl-NL", timezone: "Europe/Oslo")
    let iosRequest = try iosClient.vibeCastRequest(payload)
    let macRequest = try macClient.vibeCastRequest(payload)
    let iosURL = try #require(iosRequest.url)
    let macURL = try #require(macRequest.url)
    let iosQuery = try #require(URLComponents(url: iosURL, resolvingAgainstBaseURL: false)?.queryItems)
    let macQuery = try #require(URLComponents(url: macURL, resolvingAgainstBaseURL: false)?.queryItems)

    #expect(iosRequest.httpMethod == "GET")
    #expect(macRequest.httpMethod == "GET")
    #expect(iosRequest.url?.path == "/api/djconnect/v1/vibecast")
    #expect(macRequest.url?.path == "/api/djconnect/v1/vibecast")
    #expect(iosRequest.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    #expect(macRequest.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    #expect(iosRequest.value(forHTTPHeaderField: "X-DJConnect-Locale") == "nl-NL")
    #expect(macRequest.value(forHTTPHeaderField: "X-DJConnect-Locale") == "nl-NL")
    #expect(iosRequest.value(forHTTPHeaderField: "X-DJConnect-Render-Capabilities") == macRequest.value(forHTTPHeaderField: "X-DJConnect-Render-Capabilities"))
    #expect(iosRequest.value(forHTTPHeaderField: "X-DJConnect-Render-Capabilities")?.split(separator: ",").contains("emoji_safe") == true)
    #expect(iosQuery.first(where: { $0.name == "client_type" })?.value == "ios")
    #expect(macQuery.first(where: { $0.name == "client_type" })?.value == "macos")
    #expect(iosQuery.first(where: { $0.name == "capabilities" })?.value == macQuery.first(where: { $0.name == "capabilities" })?.value)
    #expect(iosQuery.first(where: { $0.name == "capabilities" })?.value?.split(separator: ",").contains("emoji_safe") == true)
    #expect(iosQuery.first(where: { $0.name == "locale" })?.value == macQuery.first(where: { $0.name == "locale" })?.value)
    #expect(iosQuery.first(where: { $0.name == "timezone" })?.value == macQuery.first(where: { $0.name == "timezone" })?.value)
}

@Test func musicDiscoveryRefreshUsesWebSocketFastPathWhenAdvertised() async throws {
    let fastPath = MockWebSocketFastPathTransport(supportedRoutes: [.musicDiscoveryRefresh])
    let client = DJConnectClient(
        baseURL: URL(string: "http://homeassistant.local:8123")!,
        identity: testIOSIdentity(deviceID: "djconnect-ios-discovery-fast"),
        tokenStore: DJConnectInMemoryTokenStore(token: "fast-token"),
        session: mockSession(host: "homeassistant.local") { _ in
            Issue.record("HTTP should not be used when WebSocket Music Discovery refresh succeeds")
            return (HTTPURLResponse(), Data())
        },
        webSocketFastPath: fastPath
    )

    let response = try await client.refreshMusicDiscovery(musicDNAKey: "music-dna-key", language: "nl")

    #expect(response.visibleSections.first?.visibleItems.first?.title == "Fast Discovery")
    #expect(await fastPath.musicDiscoveryRefreshCalls == 1)
    #expect(await fastPath.receivedTokens == ["fast-token"])
    #expect(await fastPath.receivedMusicDiscoveryIdentity?.deviceID == "djconnect-ios-discovery-fast")
    #expect(await fastPath.receivedMusicDiscoveryIdentity?.clientType == .ios)
    #expect(await fastPath.receivedMusicDiscoveryMusicDNAKey == "music-dna-key")
    #expect(await fastPath.receivedMusicDiscoveryLanguage == "nl")
}

@Test func vibeCastRequestCanOmitEmojiSafeCapabilityWithoutCrashing() throws {
    let client = DJConnectClient(
        baseURL: URL(string: "http://homeassistant.local:8123")!,
        identity: testIOSIdentity(deviceID: "djconnect-ios-no-emoji"),
        tokenStore: DJConnectInMemoryTokenStore(token: "token")
    )

    let request = try client.vibeCastRequest(DJConnectVibeCastRequest(capabilities: ["bold", "accent"]))
    let capabilities = request.value(forHTTPHeaderField: "X-DJConnect-Render-Capabilities")?.split(separator: ",")

    #expect(capabilities?.contains("emoji_safe") == false)
    #expect(capabilities?.contains("bold") == true)
    #expect(capabilities?.contains("accent") == true)
}

@Test func vibeCastWebSocketFastPathSucceedsWithoutHTTP() async throws {
    let fastPath = MockWebSocketFastPathTransport(supportedRoutes: [.vibeCast])
    let client = DJConnectClient(
        baseURL: URL(string: "http://vibecast-fast.local:8123")!,
        identity: testIOSIdentity(deviceID: "djconnect-ios-8F3A2C91B45D"),
        tokenStore: DJConnectInMemoryTokenStore(token: "device-token"),
        session: mockSession(host: "vibecast-fast.local") { request in
            Issue.record("HTTP should not be used when WebSocket VibeCast succeeds")
            return (try httpResponse(for: request, statusCode: 500), Data())
        },
        webSocketFastPath: fastPath
    )

    let response = try await client.vibeCast(DJConnectVibeCastRequest(locale: "nl-NL", timezone: "Europe/Oslo"))

    #expect(response.enabled == true)
    #expect(response.revision == 7)
    #expect(response.context?.trackID == "fast-track")
    #expect(response.items.first?.plainText == "Fast fact")
    #expect(await fastPath.vibeCastCalls == 1)
    #expect(await fastPath.receivedVibeCastIdentity?.clientType == .ios)
    #expect(await fastPath.receivedVibeCastIdentity?.deviceID == "djconnect-ios-8F3A2C91B45D")
    #expect(await fastPath.receivedVibeCastPayload?.locale == "nl-NL")
    #expect(await fastPath.receivedVibeCastPayload?.timezone == "Europe/Oslo")
    #expect(await fastPath.receivedTokens == ["device-token"])
}

@Test func vibeCastWebSocketFailureFallsBackToHTTPExactlyOnce() async throws {
    let fastPath = MockWebSocketFastPathTransport(supportedRoutes: [.vibeCast])
    await fastPath.setVibeCastError(DJConnectError.network(message: "timeout"))
    final class Counter: @unchecked Sendable {
        let lock = NSLock()
        var value = 0
        func increment() { lock.withLock { value += 1 } }
        var count: Int { lock.withLock { value } }
    }
    let counter = Counter()
    let client = DJConnectClient(
        baseURL: URL(string: "http://vibecast-fallback.local:8123")!,
        identity: testIOSIdentity(),
        tokenStore: DJConnectInMemoryTokenStore(token: "device-token"),
        session: mockSession(host: "vibecast-fallback.local") { request in
            counter.increment()
            #expect(request.url?.path == "/api/djconnect/v1/vibecast")
            return (
                try httpResponse(for: request, statusCode: 200),
                Data(#"{"enabled":true,"revision":8,"poll_after_seconds":30,"context":{"track_id":"http-track"},"items":[{"id":"http-fact","kind":"trivia","text":[{"type":"text","value":"HTTP fact"}]}]}"#.utf8)
            )
        },
        webSocketFastPath: fastPath
    )

    let response = try await client.vibeCast(DJConnectVibeCastRequest(locale: "en-US"))

    #expect(response.revision == 8)
    #expect(response.context?.trackID == "http-track")
    #expect(response.items.first?.plainText == "HTTP fact")
    #expect(await fastPath.vibeCastCalls == 1)
    #expect(counter.count == 1)
}

@Test func appleClientCodeDoesNotReferenceRemovedDJConnectHAPlaybackEntities() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let scannedRoots = ["Sources", "Apps"].map { repositoryRoot.appendingPathComponent($0) }
    let removedEntities = [
        "djconnect_volume",
        "djconnect_shuffle",
        "djconnect_repeat_state",
        "djconnect_sound_output",
        "djconnect_spotify_status",
        "djconnect_playback_available",
        "djconnect_queue",
        "djconnect_playlists",
        "djconnect_outputs",
        "sensor.djconnect_",
        "number.djconnect_volume",
        "select.djconnect_sound_output",
        "switch.djconnect_shuffle"
    ]
    let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey]
    let sourceExtensions = Set(["swift", "strings"])

    for root in scannedRoots {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            continue
        }
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: resourceKeys)
            if values.isDirectory == true {
                continue
            }
            guard values.isRegularFile == true, sourceExtensions.contains(fileURL.pathExtension) else {
                continue
            }
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            for entity in removedEntities {
                #expect(contents.contains(entity) == false, "\(fileURL.path) references removed HA playback entity \(entity)")
            }
        }
    }
}

@Test func commandWebSocketFastPathSucceedsWithoutHTTP() async throws {
    let fastPath = MockWebSocketFastPathTransport(supportedRoutes: [.command])
    let client = DJConnectClient(
        baseURL: URL(string: "http://fast-path.local:8123")!,
        identity: testIOSIdentity(deviceID: "djconnect-ios-8F3A2C91B45D"),
        tokenStore: DJConnectInMemoryTokenStore(token: "device-token"),
        session: mockSession(host: "fast-path.local") { request in
            Issue.record("HTTP should not be used when WebSocket command succeeds")
            return (try httpResponse(for: request, statusCode: 500), Data(#"{"success":false}"#.utf8))
        },
        webSocketFastPath: fastPath
    )

    let response = try await client.sendCommandResponse(DJConnectCommandPayload(
        identity: testIOSIdentity(deviceID: "djconnect-ios-8F3A2C91B45D"),
        command: "play",
        language: "en-GB"
    ))

    #expect(response.success == true)
    #expect(response.playback?.trackName == "WebSocket Track")
    #expect(await fastPath.commandCalls == 1)
    #expect(await fastPath.receivedTokens == ["device-token"])
    #expect(await fastPath.receivedCommandPayload?.clientType == .ios)
    #expect(await fastPath.receivedCommandPayload?.deviceID == "djconnect-ios-8F3A2C91B45D")
    #expect(await fastPath.receivedCommandPayload?.language == "en-GB")
}

@Test func homeAssistantWebSocketURLUsesNativeAPIPath() throws {
    let local = try DJConnectHomeAssistantWebSocketFastPath.websocketURL(from: #require(URL(string: "http://homeassistant.local:8123")))
    let secure = try DJConnectHomeAssistantWebSocketFastPath.websocketURL(from: #require(URL(string: "https://ha.example.com/lovelace?x=1")))

    #expect(local.absoluteString == "ws://homeassistant.local:8123/api/websocket")
    #expect(secure.absoluteString == "wss://ha.example.com/api/websocket")
}

@Test func missingWebSocketCapabilityFallsBackToHTTPCommand() async throws {
    let fastPath = MockWebSocketFastPathTransport(supportedRoutes: [])
    final class Counter: @unchecked Sendable {
        let lock = NSLock()
        var value = 0
        func increment() { lock.withLock { value += 1 } }
        var count: Int { lock.withLock { value } }
    }
    let counter = Counter()
    let client = DJConnectClient(
        baseURL: URL(string: "http://fallback.local:8123")!,
        identity: testIOSIdentity(deviceID: "djconnect-ios-8F3A2C91B45D"),
        tokenStore: DJConnectInMemoryTokenStore(token: "device-token"),
        session: mockSession(host: "fallback.local") { request in
            counter.increment()
            #expect(request.url?.path == "/api/djconnect/v1/command")
            return (try httpResponse(for: request, statusCode: 200), Data(#"{"success":true,"playback":{"has_playback":true,"is_playing":false,"track_name":"HTTP Track"}}"#.utf8))
        },
        webSocketFastPath: fastPath
    )

    let response = try await client.sendCommandResponse(DJConnectCommandPayload(
        identity: testIOSIdentity(deviceID: "djconnect-ios-8F3A2C91B45D"),
        command: "pause"
    ))

    #expect(response.playback?.trackName == "HTTP Track")
    #expect(await fastPath.commandCalls == 1)
    #expect(counter.count == 1)
}

@Test func commandWebSocketFailureFallsBackToHTTPExactlyOnce() async throws {
    let fastPath = MockWebSocketFastPathTransport(supportedRoutes: [.command])
    await fastPath.setCommandError(DJConnectError.network(message: "timeout"))
    final class Counter: @unchecked Sendable {
        let lock = NSLock()
        var value = 0
        func increment() { lock.withLock { value += 1 } }
        var count: Int { lock.withLock { value } }
    }
    let counter = Counter()
    let client = DJConnectClient(
        baseURL: URL(string: "http://command-fallback.local:8123")!,
        identity: testIOSIdentity(),
        tokenStore: DJConnectInMemoryTokenStore(token: "device-token"),
        session: mockSession(host: "command-fallback.local") { request in
            counter.increment()
            #expect(request.url?.path == "/api/djconnect/v1/command")
            return (try httpResponse(for: request, statusCode: 200), Data(#"{"success":true,"playback":{"has_playback":true,"is_playing":false,"track_name":"HTTP Command Track"}}"#.utf8))
        },
        webSocketFastPath: fastPath
    )

    let response = try await client.sendCommandResponse(DJConnectCommandPayload(
        identity: testIOSIdentity(),
        command: "pause"
    ))

    #expect(response.playback?.trackName == "HTTP Command Track")
    #expect(await fastPath.commandCalls == 1)
    #expect(counter.count == 1)
}

@Test func askDJMessageWebSocketFastPathDecodesMessagesAndRevisions() async throws {
    let fastPath = MockWebSocketFastPathTransport(supportedRoutes: [.askDJMessage])
    let client = DJConnectClient(
        baseURL: URL(string: "http://ask-fast.local:8123")!,
        identity: testIOSIdentity(),
        tokenStore: DJConnectInMemoryTokenStore(token: "device-token"),
        session: mockSession(host: "ask-fast.local") { request in
            Issue.record("HTTP should not be used when WebSocket Ask DJ succeeds")
            return (try httpResponse(for: request, statusCode: 500), Data())
        },
        webSocketFastPath: fastPath
    )

    let response = try await client.sendAskDJMessage(DJConnectAskDJRequest(
        identity: testIOSIdentity(),
        text: "Tell me about this track",
        clientMessageID: "client-message-1",
        mood: 72,
        musicDNAKey: "music-dna",
        audioResponse: .auto,
        language: "de-DE"
    ))

    #expect(response.historyRevision == 12)
    #expect(response.clearRevision == 3)
    #expect(response.assistantMessage?.text == "Fast answer")
    #expect(await fastPath.askDJCalls == 1)
    #expect(await fastPath.receivedAskPayload?.musicDNAKey == "music-dna")
    #expect(await fastPath.receivedAskPayload?.language == "de-DE")
    #expect(await fastPath.receivedTokens == ["device-token"])
}

@Test func trackInsightWebSocketFastPathSucceeds() async throws {
    let fastPath = MockWebSocketFastPathTransport(supportedRoutes: [.trackInsight])
    let client = DJConnectClient(
        baseURL: URL(string: "http://insight-fast.local:8123")!,
        identity: testIOSIdentity(deviceID: "djconnect-ios-8F3A2C91B45D"),
        tokenStore: DJConnectInMemoryTokenStore(token: "device-token"),
        session: mockSession(host: "insight-fast.local") { request in
            Issue.record("HTTP should not be used when WebSocket Track Insight succeeds")
            return (try httpResponse(for: request, statusCode: 500), Data())
        },
        webSocketFastPath: fastPath
    )

    let insight = try await client.trackInsight(DJConnectTrackInsightRequest(
        title: "Innerbloom",
        artist: "RUFUS DU SOL",
        album: "Bloom",
        artworkURL: URL(string: "https://example.com/innerbloom.jpg"),
        durationMS: 544_000,
        progressMS: 123_000,
        mood: 70
    ))

    #expect(insight.title == "Innerbloom")
    #expect(insight.artist == "RUFUS DU SOL")
    #expect(await fastPath.trackInsightCalls == 1)
    #expect(await fastPath.receivedTrackIdentity?.clientType == .ios)
    #expect(await fastPath.receivedTrackIdentity?.deviceID == "djconnect-ios-8F3A2C91B45D")
    #expect(await fastPath.receivedTrackPayload?.deviceID == "djconnect-ios-8F3A2C91B45D")
    #expect(await fastPath.receivedTrackPayload?.clientID == "djconnect-ios-8F3A2C91B45D")
    #expect(await fastPath.receivedTrackPayload?.clientType == "ios")
    #expect(await fastPath.receivedTrackPayload?.title == "Innerbloom")
    #expect(await fastPath.receivedTrackPayload?.artist == "RUFUS DU SOL")
    #expect(await fastPath.receivedTrackPayload?.album == "Bloom")
    #expect(await fastPath.receivedTrackPayload?.artworkURL?.absoluteString == "https://example.com/innerbloom.jpg")
    #expect(await fastPath.receivedTrackPayload?.durationMS == 544_000)
    #expect(await fastPath.receivedTrackPayload?.progressMS == 123_000)
    #expect(await fastPath.receivedTrackPayload?.mood == 70)
    #expect(await fastPath.receivedTokens == ["device-token"])
}

@Test func trackInsightWebSocketFastPathUsesMacOSIdentity() async throws {
    let fastPath = MockWebSocketFastPathTransport(supportedRoutes: [.trackInsight])
    let client = DJConnectClient(
        baseURL: URL(string: "http://insight-fast-mac.local:8123")!,
        identity: DJConnectIdentity(
            deviceID: "djconnect-macos-8F3A2C91B45D",
            deviceName: "DJConnect Mac",
            clientType: .macos,
            firmware: "3.2.0",
            appVersion: "3.2.0",
            platform: .macos
        ),
        tokenStore: DJConnectInMemoryTokenStore(token: "device-token"),
        session: mockSession(host: "insight-fast-mac.local") { request in
            Issue.record("HTTP should not be used when WebSocket Track Insight succeeds")
            return (try httpResponse(for: request, statusCode: 500), Data())
        },
        webSocketFastPath: fastPath
    )

    let insight = try await client.trackInsight(DJConnectTrackInsightRequest(title: "Natural Blues", artist: "Moby"))

    #expect(insight.title == "Natural Blues")
    #expect(insight.artist == "Moby")
    #expect(await fastPath.trackInsightCalls == 1)
    #expect(await fastPath.receivedTrackIdentity?.clientType == .macos)
    #expect(await fastPath.receivedTrackIdentity?.deviceID == "djconnect-macos-8F3A2C91B45D")
    #expect(await fastPath.receivedTrackPayload?.deviceID == "djconnect-macos-8F3A2C91B45D")
    #expect(await fastPath.receivedTrackPayload?.clientID == "djconnect-macos-8F3A2C91B45D")
    #expect(await fastPath.receivedTrackPayload?.deviceName == "DJConnect Mac")
    #expect(await fastPath.receivedTrackPayload?.clientType == "macos")
    #expect(await fastPath.receivedTokens == ["device-token"])
}

@Test func trackInsightWebSocketFailureFallsBackToHTTPExactlyOnce() async throws {
    let fastPath = FailingTrackInsightFastPathTransport(error: DJConnectError.network(message: "timeout"))
    final class Counter: @unchecked Sendable {
        let lock = NSLock()
        var value = 0
        func increment() { lock.withLock { value += 1 } }
        var count: Int { lock.withLock { value } }
    }
    let counter = Counter()
    let client = DJConnectClient(
        baseURL: URL(string: "http://insight-fallback.local:8123")!,
        identity: testIOSIdentity(),
        tokenStore: DJConnectInMemoryTokenStore(token: "device-token"),
        session: mockSession(host: "insight-fallback.local") { request in
            counter.increment()
            #expect(request.url?.path == "/api/djconnect/v1/track_insight")
            return (
                try httpResponse(for: request, statusCode: 200),
                Data(
                    """
                    {
                      "success": true,
                      "track_insight": {
                        "title": "HTTP Insight",
                        "artist": "HTTP Artist",
                        "track": {
                          "title": "HTTP Insight",
                          "artist": "HTTP Artist"
                        },
                        "analysis": {
                          "summary": "Fallback insight",
                          "full_text": "Fallback insight"
                        }
                      }
                    }
                    """.utf8
                )
            )
        },
        webSocketFastPath: fastPath
    )

    let insight = try await client.trackInsight(DJConnectTrackInsightRequest(title: "Innerbloom", artist: "RUFUS DU SOL"))

    #expect(insight.title == "HTTP Insight")
    #expect(insight.artist == "HTTP Artist")
    #expect(counter.count == 1)
}

@Test func fastPathDiagnosticsExposeAdvertisedCapabilities() async throws {
    let fastPath = MockWebSocketFastPathTransport(supportedRoutes: [.askDJMessage, .trackInsight])
    let client = DJConnectClient(
        baseURL: URL(string: "http://diagnostics-fast.local:8123")!,
        identity: testIOSIdentity(),
        tokenStore: DJConnectInMemoryTokenStore(token: "device-token"),
        webSocketFastPath: fastPath
    )

    let diagnostics = await client.fastPathDiagnostics

    #expect(diagnostics.fastPathTransport == "websocket")
    #expect(diagnostics.websocketConnected)
    #expect(diagnostics.websocketCommands == ["djconnect/ask_dj/message", "djconnect/track_insight"])
}

@Test func webSocketFailureFallsBackToHTTPExactlyOnce() async throws {
    let fastPath = MockWebSocketFastPathTransport(supportedRoutes: [.askDJMessage])
    await fastPath.setAskDJError(DJConnectError.network(message: "timeout"))
    final class Counter: @unchecked Sendable {
        let lock = NSLock()
        var value = 0
        func increment() { lock.withLock { value += 1 } }
        var count: Int { lock.withLock { value } }
    }
    let counter = Counter()
    let client = DJConnectClient(
        baseURL: URL(string: "http://ask-fallback.local:8123")!,
        identity: testIOSIdentity(),
        tokenStore: DJConnectInMemoryTokenStore(token: "device-token"),
        session: mockSession(host: "ask-fallback.local") { request in
            counter.increment()
            #expect(request.url?.path == "/api/djconnect/v1/ask_dj/message")
            return (try httpResponse(for: request, statusCode: 200), Data(#"{"history_revision":9,"clear_revision":1,"assistant_message":{"role":"assistant","text":"HTTP answer"}}"#.utf8))
        },
        webSocketFastPath: fastPath
    )

    let response = try await client.sendAskDJMessage(DJConnectAskDJRequest(
        identity: testIOSIdentity(),
        text: "hidden prompt"
    ))

    #expect(response.assistantMessage?.text == "HTTP answer")
    #expect(await fastPath.askDJCalls == 1)
    #expect(counter.count == 1)
}

@Test func remoteOnlyClientStaysHTTPWithoutFastPath() async throws {
    final class Counter: @unchecked Sendable {
        let lock = NSLock()
        var value = 0
        func increment() { lock.withLock { value += 1 } }
        var count: Int { lock.withLock { value } }
    }
    let counter = Counter()
    let client = DJConnectClient(
        baseURL: URL(string: "https://remote.ui.nabu.casa")!,
        identity: testIOSIdentity(),
        tokenStore: DJConnectInMemoryTokenStore(token: "device-token"),
        session: mockSession(host: "remote.ui.nabu.casa") { request in
            counter.increment()
            return (try httpResponse(for: request, statusCode: 200), Data(#"{"success":true,"playback":{"has_playback":false,"is_playing":false}}"#.utf8))
        }
    )

    _ = try await client.sendCommandResponse(DJConnectCommandPayload(
        identity: testIOSIdentity(),
        command: "status"
    ))

    #expect(counter.count == 1)
}

@Test func askDJHistoryWebSocketFastPathSucceedsWhenAdvertised() async throws {
    let fastPath = MockWebSocketFastPathTransport(supportedRoutes: [.askDJHistory])
    let client = DJConnectClient(
        baseURL: URL(string: "http://history-fast.local:8123")!,
        identity: testIOSIdentity(),
        tokenStore: DJConnectInMemoryTokenStore(token: "device-token"),
        session: mockSession(host: "history-fast.local") { request in
            Issue.record("HTTP should not be used when WebSocket Ask DJ history succeeds")
            return (try httpResponse(for: request, statusCode: 500), Data())
        },
        webSocketFastPath: fastPath
    )

    let response = try await client.askDJHistory(sinceRevision: 44)

    #expect(response.historyRevision == 44)
    #expect(await fastPath.askDJHistoryCalls == 1)
    #expect(await fastPath.receivedHistorySinceRevision == 44)
    #expect(await fastPath.receivedTokens == ["device-token"])
}

@Test func clearAskDJHistoryWebSocketFailureFallsBackToHTTPExactlyOnce() async throws {
    let fastPath = MockWebSocketFastPathTransport(supportedRoutes: [])
    final class Counter: @unchecked Sendable {
        let lock = NSLock()
        var value = 0
        func increment() { lock.withLock { value += 1 } }
        var count: Int { lock.withLock { value } }
    }
    let counter = Counter()
    let client = DJConnectClient(
        baseURL: URL(string: "http://clear-history-fallback.local:8123")!,
        identity: testIOSIdentity(),
        tokenStore: DJConnectInMemoryTokenStore(token: "device-token"),
        session: mockSession(host: "clear-history-fallback.local") { request in
            counter.increment()
            #expect(request.url?.path == "/api/djconnect/v1/ask_dj/history/clear")
            return (try httpResponse(for: request, statusCode: 200), Data(#"{"messages":[],"history_revision":0,"clear_revision":7}"#.utf8))
        },
        webSocketFastPath: fastPath
    )

    let response = try await client.clearAskDJHistory(musicDNAKey: "music-dna")

    #expect(response.clearRevision == 7)
    #expect(await fastPath.clearAskDJHistoryCalls == 1)
    #expect(counter.count == 1)
}

@MainActor
@Test func httpClearAskDJHistoryResponseWithClearedTrueClearsLocalCacheImmediately() async throws {
    let defaults = try testDefaults()
    defaults.set(true, forKey: "DJConnectWelcomeSeen")
    let staleMessage = DJConnectAskDJMessage(
        role: .user,
        text: "oude vraag",
        status: .delivered,
        createdAt: Date(timeIntervalSince1970: 100)
    )
    defaults.set(try JSONEncoder().encode([staleMessage]), forKey: "DJConnectAskDJMessages")
    defaults.set(4, forKey: "DJConnectAskDJClearRevision")
    let host = "clear-http.local"
    let session = mockSession(host: host) { request in
        #expect(request.url?.path == "/api/djconnect/v1/ask_dj/history/clear")
        return (
            try httpResponse(for: request, statusCode: 200),
            Data(#"{"success":true,"cleared":true,"messages":[],"history_revision":22,"clear_revision":5,"ask_dj_clear_required":true,"server_time":"2026-07-02T10:00:00Z","user_id":"ha-user"}"#.utf8)
        )
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: host, session: session)

    model.clearAskDJHistory()
    for _ in 0..<20 where model.isClearingAskDJHistory {
        try await Task.sleep(for: .milliseconds(100))
    }

    #expect(model.askDJMessages.isEmpty)
    #expect(defaults.integer(forKey: "DJConnectAskDJClearRevision") == 5)
    #expect(defaults.integer(forKey: "DJConnectAskDJHistoryRevision") == 22)
}

@MainActor
@Test func webSocketClearAskDJHistoryResponseWithClearedTrueClearsLocalCacheImmediately() async throws {
    let defaults = try testDefaults()
    let staleMessage = DJConnectAskDJMessage(
        role: .dj,
        text: "oud antwoord",
        status: .sent,
        createdAt: Date(timeIntervalSince1970: 200)
    )
    defaults.set(try JSONEncoder().encode([staleMessage]), forKey: "DJConnectAskDJMessages")
    defaults.set(6, forKey: "DJConnectAskDJClearRevision")
    let fastPath = MockWebSocketFastPathTransport(supportedRoutes: [.askDJHistoryClear])
    await fastPath.setClearAskDJHistoryResponse(DJConnectAskDJHistoryResponse(
        success: true,
        cleared: true,
        userID: "ha-user",
        historyRevision: 33,
        clearRevision: 7,
        askDJClearRequired: true,
        messages: []
    ))
    let host = "clear-ws.local"
    let identity = DJConnectIdentity(
        deviceID: "djconnect-macos-8F3A2C91B45D",
        deviceName: "DJConnect Mac",
        clientType: .macos,
        firmware: "3.2.8",
        appVersion: "3.2.8",
        platform: .macos
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://\(host):8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "device-token"),
        session: mockSession(host: host) { request in
            Issue.record("HTTP should not be used when WebSocket clear succeeds")
            return (try httpResponse(for: request, statusCode: 500), Data())
        },
        webSocketFastPath: fastPath
    )
    let response = try await client.clearAskDJHistory(musicDNAKey: "music-dna")
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )

    model.applyAskDJHistory(response, forceClear: response.isClearAcknowledged)

    #expect(model.askDJMessages.isEmpty)
    #expect(defaults.integer(forKey: "DJConnectAskDJClearRevision") == 7)
    #expect(defaults.integer(forKey: "DJConnectAskDJHistoryRevision") == 33)
    #expect(await fastPath.clearAskDJHistoryCalls == 1)
    #expect(await fastPath.receivedClearIdentity?.deviceID == "djconnect-macos-8F3A2C91B45D")
    #expect(await fastPath.receivedClearIdentity?.clientType == .macos)
    #expect(await fastPath.receivedClearIdentity?.deviceName == "DJConnect Mac")
}

@Test func homeAssistantWebSocketFastPathAllowsOnlyLocalURLs() {
    #expect(DJConnectHomeAssistantWebSocketFastPath.isLocalHomeAssistantURL(URL(string: "http://homeassistant.local:8123")!))
    #expect(DJConnectHomeAssistantWebSocketFastPath.isLocalHomeAssistantURL(URL(string: "http://192.168.1.10:8123")!))
    #expect(DJConnectHomeAssistantWebSocketFastPath.isLocalHomeAssistantURL(URL(string: "http://172.20.1.10:8123")!))
    #expect(!DJConnectHomeAssistantWebSocketFastPath.isLocalHomeAssistantURL(URL(string: "https://remote.ui.nabu.casa")!))
}

@Test func fastPathPolicyRequiresOptInAuthAndMatchingLocalURL() {
    let localURL = URL(string: "http://homeassistant.local:8123")!
    let remoteURL = URL(string: "https://remote.ui.nabu.casa")!
    let auth = DJConnectHomeAssistantWebSocketAuth { "ha-token" }

    #expect(DJConnectFastPathPolicy.makeFastPath(
        baseURL: localURL,
        localURL: localURL,
        configuration: DJConnectTransportConfiguration(webSocketFastPathEnabled: false, homeAssistantWebSocketAuth: auth)
    ) == nil)
    #expect(DJConnectFastPathPolicy.makeFastPath(
        baseURL: localURL,
        localURL: localURL,
        configuration: DJConnectTransportConfiguration(webSocketFastPathEnabled: true)
    ) == nil)
    #expect(DJConnectFastPathPolicy.makeFastPath(
        baseURL: remoteURL,
        localURL: localURL,
        configuration: DJConnectTransportConfiguration(webSocketFastPathEnabled: true, homeAssistantWebSocketAuth: auth)
    ) == nil)
    #expect(DJConnectFastPathPolicy.makeFastPath(
        baseURL: localURL,
        localURL: localURL,
        configuration: DJConnectTransportConfiguration(webSocketFastPathEnabled: true, homeAssistantWebSocketAuth: auth)
    ) != nil)
}

@Test func trackInsightEndpointResponseDecodesNormalizedBackendContract() throws {
    let json = """
    {
      "success": true,
      "track_insight": {
        "id": "insight-innerbloom",
        "source": "track_insight",
        "track": {
          "title": "Innerbloom",
          "artist": "RUFUS DU SOL",
          "album": "Bloom",
          "duration_ms": 596000,
          "progress_ms": 120000,
          "is_playing": true,
          "player_id": "spotify-player",
          "entity_id": "media_player.living_room",
          "backend": "spotify"
        },
        "analysis": {
          "summary": "A slow-blooming electronic journey.",
          "full_text": "Full Track Insight text.",
          "genre": "Deep House",
          "subgenre": "Melodic House",
          "mood": "Dreamy",
          "vibe": "Cinematic",
          "texture": "Glowing synth textures",
          "emotional_tone": "Euphoric",
          "energy": 0.65,
          "danceability": 0.72,
          "intensity": 0.58,
          "confidence": 0.91,
          "production_notes": ["Wide pads"],
          "instrumentation": ["Synth arpeggio"],
          "arrangement_notes": ["Slow build"],
          "listening_cues": ["Wait for the lift"],
          "similar_tracks": [
            { "title": "Underwater", "artist": "RUFUS DU SOL", "reason": "Shared atmosphere" }
          ]
        },
        "music_dna": {
          "match_percent": 96,
          "label": "matches_music_dna",
          "summary": "This matches your Music DNA."
        },
        "visual_profile": {
          "palette": ["#4DA3FF", "#D184FF"],
          "motion_style": "cinematic",
          "pulse_speed": 0.8,
          "wave_amplitude": 0.7,
          "particle_density": 0.6,
          "glow_strength": 0.9,
          "spectrum_bias": "mid",
          "seed": "innerbloom"
        },
        "sections": [
          { "id": "intro", "title": "Intro", "summary": "Soft opening" },
          { "id": "lift", "title": "Lift", "summary": "Energy rises" }
        ]
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(TrackInsightEndpointResponse.self, from: json)
    let insight = try #require(response.trackInsightValue)

    #expect(insight.id == "insight-innerbloom")
    #expect(insight.title == "Innerbloom")
    #expect(insight.artist == "RUFUS DU SOL")
    #expect(insight.duration == 596)
    #expect(insight.progress == 120)
    #expect(insight.isPlaying == true)
    #expect(insight.playerID == "spotify-player")
    #expect(insight.entityID == "media_player.living_room")
    #expect(insight.genre == "Deep House")
    #expect(insight.subgenre == "Melodic House")
    #expect(insight.emotionalTone == "Euphoric")
    #expect(insight.confidence == 0.91)
    #expect(insight.productionNotes == ["Wide pads"])
    #expect(insight.similarTracks.first?.title == "Underwater")
    #expect(insight.musicDNAMatchPercent == nil)
    #expect(insight.musicDNALabel == nil)
    #expect(insight.visualProfile?.motionStyle == .cinematic)
    #expect(insight.visualProfile?.spectrumBias == .mid)
    #expect(insight.sections.map(\.title) == ["Intro", "Lift"])
}

@Test func trackInsightEndpointResponseDecodesCamelCaseWrapper() throws {
    let json = """
    {
      "success": true,
      "trackInsight": {
        "track": {
          "title": "Camel Song",
          "artist": "Camel Artist"
        },
        "analysis": {
          "summary": "Camel-case wrapper insight."
        }
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(TrackInsightEndpointResponse.self, from: json)
    let insight = try #require(response.trackInsightValue)

    #expect(insight.title == "Camel Song")
    #expect(insight.artist == "Camel Artist")
    #expect(insight.summary == "Camel-case wrapper insight.")
}

@Test func trackInsightEndpointResponseDecodesCanonicalStandalonePayload() throws {
    let json = """
    {
      "id": "track_insight_direct",
      "created_at": "2026-07-03T16:00:00Z",
      "source": "http",
      "track": {
        "title": "Direct Song",
        "artist": "Direct Artist",
        "album": "Direct Album",
        "artwork_url": "https://example.test/direct.jpg",
        "duration_ms": 240000,
        "progress_ms": 42000,
        "is_playing": true,
        "player_id": "media_player.direct",
        "entity_id": "media_player.direct",
        "backend": "music_assistant"
      },
      "analysis": {
        "summary": "Canonical standalone insight.",
        "full_text": "Canonical standalone full text.",
        "mood": "Focused",
        "vibe": "Late-night",
        "texture": "Warm",
        "emotional_tone": "Calm",
        "energy": 0.44,
        "danceability": 0.35,
        "intensity": 0.41,
        "confidence": 0.82,
        "production_notes": [],
        "instrumentation": [],
        "arrangement_notes": [],
        "listening_cues": [],
        "similar_tracks": []
      },
      "music_dna": {
        "match_percent": 99,
        "label": "matches_music_dna",
        "summary": "Must not be exposed."
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(TrackInsightEndpointResponse.self, from: json)
    let insight = try #require(response.trackInsightValue)

    #expect(insight.id == "track_insight_direct")
    #expect(insight.title == "Direct Song")
    #expect(insight.artist == "Direct Artist")
    #expect(insight.backend == "music_assistant")
    #expect(insight.summary == "Canonical standalone insight.")
    #expect(insight.rawAnalysisText == "Canonical standalone full text.")
    #expect(insight.musicDNAMatchPercent == nil)
    #expect(insight.musicDNALabel == nil)
    #expect(insight.musicDNASummary == nil)
}

@Test func trackInsightEndpointResponseBuildsInsightFromSuccessfulTextContract() throws {
    let json = """
    {
      "success": true,
      "text": "Deze track werkt door spanning en release.",
      "dj_text": "Deze track werkt door spanning en release.",
      "message": "Deze track werkt door spanning en release.",
      "action": "track_insight",
      "analysis": {
        "mode": "knowledge_plus_metadata",
        "confidence": "medium",
        "limitations": [
          "Exact section timestamps are unavailable."
        ]
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(TrackInsightEndpointResponse.self, from: json)
    let insight = try #require(response.trackInsightValue(
        fallbackTitle: "Innerbloom",
        fallbackArtist: "RUFUS DU SOL",
        fallbackArtwork: URL(string: "https://example.com/art.jpg"),
        fallbackDurationMS: 596000,
        fallbackProgressMS: 120000
    ))

    #expect(insight.title == "Innerbloom")
    #expect(insight.artist == "RUFUS DU SOL")
    #expect(insight.artwork?.absoluteString == "https://example.com/art.jpg")
    #expect(insight.duration == 596)
    #expect(insight.progress == 120)
    #expect(insight.summary == "Deze track werkt door spanning en release.")
}

@Test func askDJMessageResponseDecodesTrackInsightMetadataAndOpenScreen() throws {
    let json = """
    {
      "history_revision": 44,
      "clear_revision": 7,
      "text": "Ik heb Track Insight geopend.",
      "open_screen": "track_insight",
      "type": "track_insight",
      "intent": {
        "category": "informational",
        "intent": "track_insight",
        "action": "track_insight"
      },
      "track_insight": {
        "track": { "title": "Adagio for Strings", "artist": "Samuel Barber" },
        "analysis": {
          "summary": "A patient orchestral ascent.",
          "genre": "Classical",
          "mood": "Lamenting",
          "vibe": "Slow string suspense",
          "energy": 0.32
        },
        "music_dna": { "match_percent": 74, "label": "expands_music_dna" }
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)
    let assistantMessage = try #require(response.assistantMessage)
    let insight = try #require(response.trackInsight)

    #expect(response.openScreen == "track_insight")
    #expect(response.responseType == "track_insight")
    #expect(response.intentInfo?.intent == "track_insight")
    #expect(insight.title == "Adagio for Strings")
    #expect(insight.musicDNAMatchPercent == nil)
    #expect(assistantMessage.trackInsight?.artist == "Samuel Barber")
}

@Test func askDJMessageResponseFallsBackToTopLevelAudioURL() throws {
    let json = """
    {
      "history_revision": 44,
      "clear_revision": 7,
      "audio_url": "http://homeassistant.local:8123/api/djconnect/audio/response-456.mp3",
      "assistant_message": {
        "id": "server-assistant-with-fallback-audio",
        "role": "assistant",
        "text": "Ik zet iets energiekers voor je klaar.",
        "created_at": "2026-06-19T12:36:00Z"
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)

    #expect(response.audioURL?.path == "/api/djconnect/audio/response-456.mp3")
    #expect(response.assistantMessage?.audioURL?.path == "/api/djconnect/audio/response-456.mp3")
}

@Test func askDJResponseDecodesImageAttachments() throws {
    let json = """
    {
      "success": true,
      "dj_text": "Dit zijn albums uit die periode.",
      "audio_url": "http://homeassistant.local:8123/api/djconnect/audio/response-123.mp3",
      "intent": "info",
      "action": "none",
      "images": [
        {
          "url": "http://homeassistant.local:8123/api/djconnect/image_proxy/album/123",
          "thumbnail_url": "http://homeassistant.local:8123/api/djconnect/image_proxy/album/123/thumb",
          "title": "Album Title",
          "subtitle": "Artist Name",
          "kind": "album_art",
          "source": "spotify"
        },
        {
          "url": "http://homeassistant.local:8123/api/djconnect/image_proxy/album/456",
          "title": "Second Album",
          "subtitle": "Artist Name",
          "kind": "album_art",
          "source": "spotify"
        }
      ],
      "links": [
        {
          "url": "https://www.songkick.com/artists/123-artist",
          "title": "Concert data",
          "subtitle": "Bekijk komende concerten",
          "kind": "concerts",
          "source": "songkick"
        },
        {
          "url": "https://www.discogs.com/artist/123",
          "label": "Discografie",
          "description": "Albums en releases"
        }
      ]
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJResponse.self, from: json)

    #expect(response.images?.count == 2)
    #expect(response.audioURL?.path == "/api/djconnect/audio/response-123.mp3")
    #expect(response.images?.first?.title == "Album Title")
    #expect(response.images?.first?.kind == "album_art")
    #expect(response.images?.first?.thumbnailURL?.path == "/api/djconnect/image_proxy/album/123/thumb")
    #expect(response.images?.last?.title == "Second Album")
    #expect(response.links?.count == 2)
    #expect(response.links?.first?.title == "Concert data")
    #expect(response.links?.first?.kind == "concerts")
    #expect(response.links?.last?.title == "Discografie")
    #expect(response.links?.last?.subtitle == "Albums en releases")
}

@Test func askDJResponseDecodesPlaybackActions() throws {
    let json = """
    {
      "success": true,
      "intent": "personal_music_recommendations",
      "dj_text": "Deze passen goed bij je profiel.",
      "playback_actions": [
        {
          "id": "spotify:track:123",
          "title": "Track Title",
          "subtitle": "Artist Name",
          "uri": "spotify:track:123",
          "context_uri": "spotify:album:456",
          "offset_uri": "spotify:track:123",
          "kind": "track",
          "image_url": "http://homeassistant.local:8123/api/djconnect/image_proxy/album/456",
          "reason": "Past bij je recente melodic house profiel."
        }
      ]
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJResponse.self, from: json)
    let action = try #require(response.playbackActions?.first)

    #expect(response.playbackActions?.count == 1)
    #expect(action.id == "spotify:track:123")
    #expect(action.title == "Track Title")
    #expect(action.subtitle == "Artist Name")
    #expect(action.uri == "spotify:track:123")
    #expect(action.contextURI == "spotify:album:456")
    #expect(action.offsetURI == "spotify:track:123")
    #expect(action.kind == "track")
    #expect(action.imageURL?.path == "/api/djconnect/image_proxy/album/456")
    #expect(action.reason == "Past bij je recente melodic house profiel.")
}

@Test func askDJPlaybackActionsDecodeAlbumArtAliases() throws {
    let json = """
    {
      "success": true,
      "playback_actions": [
        {
          "title": "Track met art",
          "subtitle": "Artist",
          "uri": "spotify:track:123",
          "kind": "track",
          "album_art_url": "https://example.test/album-art.jpg"
        },
        {
          "title": "Track met media art",
          "uri": "spotify:track:456",
          "kind": "track",
          "media_image_url": "https://example.test/media-art.jpg"
        },
        {
          "title": "Track met entity picture",
          "uri": "spotify:track:789",
          "kind": "track",
          "entity_picture": "https://example.test/entity-picture.jpg"
        }
      ]
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJResponse.self, from: json)
    let actions = try #require(response.playbackActions)

    #expect(actions.map { $0.imageURL?.absoluteString } == [
        "https://example.test/album-art.jpg",
        "https://example.test/media-art.jpg",
        "https://example.test/entity-picture.jpg"
    ])
}

@Test func askDJResponseDecodesOutputPlaybackActions() throws {
    let json = """
    {
      "success": true,
      "dj_text": "Kies een uitvoer.",
      "playback_actions": [
        {
          "kind": "output",
          "command": "set_output",
          "value": "spotify-device-1",
          "device_id": "spotify-device-1",
          "device_name": "Woonkamer",
          "title": "Woonkamer",
          "subtitle": "Actieve uitvoer",
          "active": true,
          "reason": "Spotify Connect uitvoer wijzigen vanuit Ask DJ."
        }
      ]
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJResponse.self, from: json)
    let action = try #require(response.playbackActions?.first)

    #expect(action.isOutputAction == true)
    #expect(action.command == "set_output")
    #expect(action.outputDeviceID == "spotify-device-1")
    #expect(action.deviceID == "spotify-device-1")
    #expect(action.deviceName == "Woonkamer")
    #expect(action.title == "Woonkamer")
    #expect(action.subtitle == "Actieve uitvoer")
    #expect(action.isActiveOutputAction == true)
}

@Test func askDJMessageResponseDecodesTrimMetadataAndConfirmationActions() throws {
    let json = """
    {
      "history_revision": 45,
      "clear_revision": 9,
      "deduplicated": true,
      "history_limit": 50,
      "history_trimmed_before": "2026-06-19T12:00:00Z",
      "history_trimmed_count": 12,
      "server_time": "2026-06-19T12:37:00Z",
      "assistant_message": {
        "id": "server-assistant-confirm",
        "role": "assistant",
        "text": "Wil je dat ik deze trackmix nu start?",
        "created_at": "2026-06-19T12:36:30Z",
        "confirmation_actions": [
          {
            "title": "Ja",
            "kind": "confirmation",
            "action_style": "primary_confirmation",
            "command": "ask_dj_followup_response",
            "response_value": "yes"
          },
          {
            "title": "Nee",
            "kind": "confirmation",
            "action_style": "secondary_confirmation",
            "command": "ask_dj_followup_response",
            "response_value": "no"
          }
        ]
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)
    let message = try #require(response.assistantMessage)
    let yesAction = try #require(message.confirmationActions.first)

    #expect(response.historyRevision == 45)
    #expect(response.clearRevision == 9)
    #expect(response.deduplicated == true)
    #expect(response.historyLimit == 50)
    #expect(response.historyTrimmedBefore != nil)
    #expect(response.historyTrimmedCount == 12)
    #expect(response.serverTime != nil)
    #expect(message.confirmationActions.count == 2)
    #expect(yesAction.command == "ask_dj_followup_response")
    #expect(yesAction.responseValue == "yes")
    #expect(yesAction.actionStyle == "primary_confirmation")
}

@Test func askDJActionDecodesAndPreservesObjectValue() throws {
    let json = """
    {
      "history_revision": 47,
      "assistant_message": {
        "id": "server-assistant-more-artist",
        "role": "assistant",
        "text": "Meer van Kebu?",
        "created_at": "2026-06-19T12:36:30Z",
        "playback_actions": [
          {
            "id": "more-kebu",
            "title": "Meer van Kebu",
            "kind": "artist",
            "command": "ask_dj_message",
            "value": {
              "text": "Meer van Kebu",
              "artist": "Kebu"
            }
          }
        ]
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)
    let action = try #require(response.assistantMessage?.playbackActions.first)

    #expect(action.command == "ask_dj_message")
    #expect(action.responseValue == "Meer van Kebu")
    #expect(action.value == .object([
        "text": .string("Meer van Kebu"),
        "artist": .string("Kebu")
    ]))
    #expect(action.isAskDJMessageAction)
    #expect(action.resolvedAskDJMessageText == "Meer van Kebu")
    #expect(action.resolvedArtistName == "Kebu")
}

@Test func askDJMessageActionConstructsArtistPromptWhenLabelIsGeneric() throws {
    let json = """
    {
      "id": "more-artist",
      "title": "Meer van deze artiest",
      "kind": "artist_more",
      "command": "ask_dj_message",
      "button_label": "Meer van deze artiest",
      "artist_name": "Charly Lownoise & Mental Theo"
    }
    """.data(using: .utf8)!

    let action = try JSONDecoder().decode(DJConnectAskDJPlaybackAction.self, from: json)

    #expect(action.isAskDJMessageAction)
    #expect(action.title == "Meer van deze artiest")
    #expect(action.buttonLabel == "Meer van deze artiest")
    #expect(action.artist == "Charly Lownoise & Mental Theo")
    #expect(action.resolvedAskDJMessageText == "Meer van Charly Lownoise & Mental Theo")
}

@Test func askDJMessageActionFallsBackToSafePromptInsteadOfEmptyText() throws {
    let json = """
    {
      "id": "more-artist",
      "title": "Meer",
      "kind": "artist_more",
      "command": "ask_dj_message",
      "text": "Meer"
    }
    """.data(using: .utf8)!

    let action = try JSONDecoder().decode(DJConnectAskDJPlaybackAction.self, from: json)

    #expect(action.isAskDJMessageAction)
    #expect(action.resolvedAskDJMessageText == "Laat meer muziek van deze artiest zien")
}

@Test func askDJMessageResponsePrefersAssistantMessageImages() throws {
    let json = """
    {
      "history_revision": 46,
      "clear_revision": 3,
      "images": [
        {
          "url": "/api/djconnect/image_proxy/top",
          "thumbnail_url": "/api/djconnect/image_proxy/top/thumb",
          "title": "Top Level",
          "kind": "album_art"
        }
      ],
      "assistant_message": {
        "id": "assistant-image-message",
        "role": "assistant",
        "text": "Dit speelt nu.",
        "images": [
          {
            "url": "/api/djconnect/image_proxy/assistant",
            "thumbnail_url": "/api/djconnect/image_proxy/assistant/thumb",
            "title": "FORZ4",
            "subtitle": "t e s t p r e s s",
            "kind": "album_art",
            "source": "spotify"
          }
        ],
        "links": [],
        "sources": [],
        "playback_actions": []
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)
    let image = try #require(response.assistantMessage?.images.first)

    #expect(response.images?.first?.title == "Top Level")
    #expect(image.url.path == "/api/djconnect/image_proxy/assistant")
    #expect(image.thumbnailURL?.path == "/api/djconnect/image_proxy/assistant/thumb")
    #expect(image.title == "FORZ4")
    #expect(image.subtitle == "t e s t p r e s s")
    #expect(image.kind == "album_art")
    #expect(image.source == "spotify")
}

@Test func askDJMessageResponseFallsBackToTopLevelImages() throws {
    let json = """
    {
      "history_revision": 47,
      "clear_revision": 3,
      "images": [
        {
          "url": "/api/djconnect/image_proxy/top",
          "thumbnail_url": "/api/djconnect/image_proxy/top/thumb",
          "title": "FORZ4",
          "subtitle": "t e s t p r e s s",
          "kind": "album_art",
          "source": "spotify"
        }
      ],
      "assistant_message": {
        "id": "assistant-image-fallback-message",
        "role": "assistant",
        "text": "Dit speelt nu.",
        "images": [],
        "links": [],
        "sources": [],
        "playback_actions": []
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)
    let image = try #require(response.assistantMessage?.images.first)

    #expect(image.url.path == "/api/djconnect/image_proxy/top")
    #expect(image.thumbnailURL?.path == "/api/djconnect/image_proxy/top/thumb")
    #expect(image.kind == "album_art")
}

@Test func askDJHistoryResponseDecodesTrackMixUrisAndTrimMetadata() throws {
    let json = """
    {
      "history_revision": 46,
      "history_limit": 50,
      "history_trimmed_before": "2026-06-19T12:00:00Z",
      "history_trimmed_count": 3,
      "messages": [
        {
          "id": "track-mix-message",
          "role": "assistant",
          "text": "Ik heb een korte mix voor je.",
          "created_at": "2026-06-19T12:38:00Z",
          "playback_actions": [
            {
              "title": "Late night track mix",
              "kind": "track_mix",
              "uris": [
                "spotify:track:1",
                "spotify:track:2",
                "spotify:track:3"
              ],
              "reason": "Drie tracks die bij deze vibe passen."
            }
          ]
        }
      ]
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJHistoryResponse.self, from: json)
    let action = try #require(response.messages.first?.playbackActions.first)

    #expect(response.historyLimit == 50)
    #expect(response.historyTrimmedBefore != nil)
    #expect(response.historyTrimmedCount == 3)
    #expect(action.kind == "track_mix")
    #expect(action.uris == ["spotify:track:1", "spotify:track:2", "spotify:track:3"])
    #expect(action.uri == nil)
    #expect(action.contextURI == nil)
}

@Test func commandResponseDecodesAskDJClearFlagFromEnvelope() throws {
    let json = """
    {
      "success": true,
      "data": {
        "ask_dj_clear_required": true
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectCommandResponse.self, from: json)

    #expect(response.askDJClearRequired == true)
}

@Test func commandResponseDecodesPlayNowAssistantMessage() throws {
    let json = """
    {
      "success": true,
      "message": "Playing now",
      "audio_url": "https://example.test/audio/top.mp3",
      "assistant_message": {
        "id": "play-now-assistant-1",
        "role": "assistant",
        "origin": "play_now",
        "text": "Ik zet Winner nu voor je aan.",
        "audio_url": "https://example.test/audio/assistant.mp3",
        "images": [
          { "url": "https://example.test/winner.jpg", "title": "Winner" }
        ],
        "links": [
          { "title": "Open playlist", "url": "https://example.test/playlist" }
        ],
        "sources": [
          { "title": "Ask DJ", "url": "https://example.test/source" }
        ],
        "playback_actions": []
      },
      "playback_actions": [
        {
          "id": "old-action",
          "label": "Play old",
          "command": "ask_dj_play_recommendation",
          "uri": "spotify:track:old"
        }
      ]
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectCommandResponse.self, from: json)
    let assistant = try #require(response.assistantMessage)

    #expect(assistant.text == "Ik zet Winner nu voor je aan.")
    #expect(assistant.origin == "play_now")
    #expect(assistant.audioURL?.absoluteString == "https://example.test/audio/assistant.mp3")
    #expect(assistant.images.count == 1)
    #expect(assistant.links.count == 2)
    #expect(assistant.sources.count == 1)
    #expect(assistant.playbackActions.isEmpty)
    #expect(response.playbackActions?.count == 1)
}

@Test func commandResponseBuildsPlayNowAssistantMessageFromTopLevelFallbacks() throws {
    let json = """
    {
      "success": true,
      "dj_text": "Deze playlist start nu.",
      "audio_url": "https://example.test/audio/fallback.mp3",
      "images": [
        { "url": "https://example.test/cover.jpg", "title": "Cover" }
      ],
      "links": [
        { "title": "Open", "url": "https://example.test/open" }
      ],
      "sources": [
        { "title": "Library", "url": "https://example.test/library" }
      ],
      "playback_actions": []
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectCommandResponse.self, from: json)
    let assistant = try #require(response.assistantMessage)

    #expect(assistant.text == "Deze playlist start nu.")
    #expect(assistant.origin == "play_now")
    #expect(assistant.audioURL?.absoluteString == "https://example.test/audio/fallback.mp3")
    #expect(assistant.images.count == 1)
    #expect(assistant.links.count == 2)
    #expect(assistant.sources.count == 1)
    #expect(assistant.playbackActions.isEmpty)
}

@Test func playbackCommandRequestsUsePlaybackEndpointAndIdentity() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.7",
        appVersion: "3.1.7",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    for command in ["play", "pause", "next", "previous"] {
        let request = try client.commandRequest(
            DJConnectCommandPayload(
                identity: identity,
                command: command
            )
        )
        let body = try #require(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

        #expect(request.url?.path == "/api/djconnect/v1/command")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
        #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
        #expect(json?["device_id"] as? String == identity.deviceID)
        #expect(json?["client_type"] as? String == "ios")
        #expect(json?["command"] as? String == command)
    }
}

@Test func queueCommandPayloadRequestsOneHundredItems() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.13",
        appVersion: "3.1.13",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.commandRequest(
        DJConnectCommandPayload(
            identity: identity,
            command: "queue",
            limit: 100
        )
    )
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(json?["command"] as? String == "queue")
    #expect(json?["limit"] as? Int == 100)
}

@Test func volumeNormalizerMapsNormalizedSliderToBackendPercent() {
    #expect(DJConnectVolumeNormalizer.backendPercent(fromNormalized: 0.0) == 0)
    #expect(DJConnectVolumeNormalizer.backendPercent(fromNormalized: 0.5) == 50)
    #expect(DJConnectVolumeNormalizer.backendPercent(fromNormalized: 1.0) == 100)
    #expect(DJConnectVolumeNormalizer.backendPercent(fromNormalized: -0.25) == 0)
    #expect(DJConnectVolumeNormalizer.backendPercent(fromNormalized: 1.25) == 100)
    #expect(DJConnectVolumeNormalizer.normalized(fromBackendPercent: 50) == 0.5)
}

@Test func invalidBackendVolumeIsUnavailable() {
    #expect(DJConnectVolumeNormalizer.normalized(fromBackendPercent: nil) == nil)
    #expect(DJConnectVolumeNormalizer.normalized(fromBackendPercent: -1) == nil)
    #expect(DJConnectVolumeNormalizer.normalized(fromBackendPercent: 101) == nil)

    let playback = DJConnectPlayback(
        volumePercent: -1,
        device: DJConnectPlaybackDevice(name: "Spotify", volumePercent: 150)
    )
    let sanitized = DJConnectVolumeNormalizer.sanitizedPlayback(playback)
    #expect(sanitized?.volumePercent == nil)
    #expect(sanitized?.device?.volumePercent == nil)
}

@Test func watchVolumeCommandUsesBackendSpotifyPercent() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-watchos-8F3A2C91B45D",
        deviceName: "DJConnect Watch",
        clientType: .watchos,
        firmware: "3.1.51",
        appVersion: "3.1.51",
        platform: .watchos
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )
    let request = try client.commandRequest(
        DJConnectCommandPayload(
            identity: identity,
            command: "set_volume",
            value: .int(DJConnectVolumeNormalizer.backendPercent(fromNormalized: 0.5)),
            play: true
        )
    )
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(json?["client_id"] as? String == identity.deviceID)
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["client_type"] as? String == "watchos")
    #expect(json?["command"] as? String == "set_volume")
    #expect(json?["value"] as? Int == 50)
    #expect(json?["play"] as? Bool == true)
}

@Test func saveCurrentTrackCommandUsesDirectCommandPayload() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-watchos-8F3A2C91B45D",
        deviceName: "DJConnect Watch",
        clientType: .watchos,
        firmware: "3.1.51",
        appVersion: "3.1.51",
        platform: .watchos
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )
    let request = try client.commandRequest(DJConnectCommandPayload(
        identity: identity,
        command: "save_current_track",
        language: "fr-FR"
    ))
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["client_type"] as? String == "watchos")
    #expect(json?["command"] as? String == "save_current_track")
    #expect(json?["language"] as? String == "fr-FR")
    #expect(json?["value"] == nil)
}

@Test func setCurrentTrackFavoriteCommandUsesBooleanValuePayload() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.51",
        appVersion: "3.1.51",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )
    let request = try client.commandRequest(DJConnectCommandPayload(
        identity: identity,
        command: "set_current_track_favorite",
        value: .bool(false)
    ))
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/v1/command")
    #expect(json?["command"] as? String == "set_current_track_favorite")
    #expect(json?["value"] as? Bool == false)
}

@Test func askDJSaveCurrentTrackControlActionIsRecognized() throws {
    let json = """
    {
      "id": "fav-current",
      "kind": "control",
      "command": "save_current_track",
      "title": "Favoriet",
      "button_label": "Zet in favorieten"
    }
    """.data(using: .utf8)!

    let action = try JSONDecoder().decode(DJConnectAskDJPlaybackAction.self, from: json)

    #expect(action.isSaveCurrentTrackControlAction)
    #expect(action.buttonLabel == "Zet in favorieten")
    #expect(action.imageURL == nil)
}

@Test func askDJFavoriteControlActionDecodesToggleMetadata() throws {
    let json = """
    {
      "id": "fav-current",
      "kind": "control",
      "command": "set_current_track_favorite",
      "title": "Haal uit favorieten",
      "toggle": true,
      "toggle_state": true,
      "favorite_status": true,
      "value": false,
      "client_prompt": "haal huidig nummer uit favorieten"
    }
    """.data(using: .utf8)!

    let action = try JSONDecoder().decode(DJConnectAskDJPlaybackAction.self, from: json)

    #expect(action.isFavoriteCurrentTrackControlAction)
    #expect(action.toggle == true)
    #expect(action.toggleState == true)
    #expect(action.favoriteStatus == true)
    #expect(action.value == .bool(false))
    #expect(action.clientPrompt == "haal huidig nummer uit favorieten")
}

@Test func askDJRecommendationActionUsesOnlySupportedPlaybackKinds() throws {
    let track = DJConnectAskDJPlaybackAction(
        title: "Lithium",
        uri: "spotify:track:lithium",
        kind: "track"
    )
    let textOnlyLink = DJConnectAskDJPlaybackAction(
        title: "Artist website",
        uri: "https://example.com",
        kind: "link"
    )

    #expect(track.isRecommendationAction)
    #expect(!textOnlyLink.isRecommendationAction)
}

@Test func askDJActionFullValuePreservesBackendMetadata() throws {
    let action = DJConnectAskDJPlaybackAction(
        id: "mix-1",
        title: "Pearl Jam x Metallica",
        uris: ["spotify:track:1", "spotify:track:2"],
        kind: "track_mix",
        command: "ask_dj_play_recommendation",
        reason: "Backend-built mix",
        value: .object([
            "server_context_id": .string("ctx-123"),
            "original_request": .string("maak een mix van Pearl Jam en Metallica")
        ])
    )

    guard case let .jsonObject(value) = action.fullActionCommandValue else {
        Issue.record("Expected full action object")
        return
    }

    #expect(value["id"] == .string("mix-1"))
    #expect(value["kind"] == .string("track_mix"))
    #expect(value["command"] == .string("ask_dj_play_recommendation"))
    #expect(value["uris"] == .array([.string("spotify:track:1"), .string("spotify:track:2")]))
    #expect(value["value"] == .object([
        "server_context_id": .string("ctx-123"),
        "original_request": .string("maak een mix van Pearl Jam en Metallica")
    ]))
}

@Test func commandResponseDecodesNoActiveOutputPlaybackActions() throws {
    let json = """
    {
      "success": false,
      "error": "no_active_output",
      "action": "select_output",
      "message": "Kies een speaker.",
      "playback_actions": [
        {
          "id": "speaker-living",
          "title": "Woonkamer",
          "kind": "output",
          "command": "ask_dj_play_recommendation_on_output",
          "value": {
            "device_id": "woonkamer",
            "request_id": "req-123"
          }
        }
      ]
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectCommandResponse.self, from: json)
    let action = try #require(response.playbackActions?.first)

    #expect(response.success == false)
    #expect(response.error == "no_active_output")
    #expect(action.isOutputAction)
    #expect(action.outputDeviceID == "woonkamer")
    #expect(action.commandValue == .jsonObject([
        "device_id": .string("woonkamer"),
        "request_id": .string("req-123")
    ]))
}

@Test func playbackDecodesFavoriteStatusAliases() throws {
    let favoriteJSON = """
    {
      "has_playback": true,
      "track_name": "Midnight City",
      "favorite_status": true
    }
    """.data(using: .utf8)!
    let likedJSON = """
    {
      "has_playback": true,
      "track_name": "Electric Feel",
      "is_liked": false
    }
    """.data(using: .utf8)!

    let favoritePlayback = try JSONDecoder().decode(DJConnectPlayback.self, from: favoriteJSON)
    let likedPlayback = try JSONDecoder().decode(DJConnectPlayback.self, from: likedJSON)

    #expect(favoritePlayback.currentTrackFavoriteStatus == true)
    #expect(likedPlayback.currentTrackFavoriteStatus == false)
}

@MainActor
@Test func appCommandsUseSpotifySafeCollectionLimits() {
    #expect(DJConnectAppModel.commandLimit(for: "queue") == 100)
    #expect(DJConnectAppModel.commandLimit(for: "playlists") == 100)
    #expect(DJConnectAppModel.commandLimit(for: "status") == nil)
    #expect(DJConnectAppModel.commandLimit(for: "play") == nil)
}

@Test func commandPayloadsDoNotSendRemovedHAOverrideOptions() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-test",
        deviceName: "Test iPhone",
        clientType: .ios,
        firmware: "3.1.28",
        appVersion: "3.1.28",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.commandRequest(
        DJConnectCommandPayload(
            identity: identity,
            command: "start_liked_proxy",
            play: true
        )
    )
    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

    #expect(json["spotify_source"] == nil)
    #expect(json["liked_proxy_playlist_uri"] == nil)
}

@MainActor
@Test func wakeWordCandidatesIncludeCommonPronunciationVariants() {
    let djCandidates = Set(DJConnectAppModel.normalizedWakeWordCandidates(for: "Hey DJ"))
    #expect(djCandidates.contains("hey dj"))
    #expect(djCandidates.contains("hey dee jay"))
    #expect(djCandidates.contains("hey deejay"))
    #expect(djCandidates.contains("hey d j"))

    let nabuCandidates = Set(DJConnectAppModel.normalizedWakeWordCandidates(for: "Okay Nabu"))
    #expect(nabuCandidates.contains("okay nabu"))
    #expect(nabuCandidates.contains("ok nabu"))
    #expect(nabuCandidates.contains("oke nabu"))
    #expect(nabuCandidates.contains("okay naboo"))
    #expect(nabuCandidates.contains("okay na boo"))
    #expect(nabuCandidates.contains("okay nah boo"))
}

@Test func commandRequestSupportsPlayContextAtObjectValues() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.7",
        appVersion: "3.1.7",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.commandRequest(
        DJConnectCommandPayload(
            identity: identity,
            command: "play_context_at",
            value: .object([
                "context_uri": "spotify:playlist:context",
                "uri": "spotify:track:1",
                "offset_uri": "spotify:track:1",
                "title": "Track One",
                "artist": "Artist One",
                "index": "0"
            ]),
            play: true
        )
    )
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
    let value = json?["value"] as? [String: String]

    #expect(json?["command"] as? String == "play_context_at")
    #expect(value?["context_uri"] == "spotify:playlist:context")
    #expect(value?["uri"] == "spotify:track:1")
    #expect(value?["offset_uri"] == "spotify:track:1")
    #expect(value?["title"] == "Track One")
    #expect(value?["artist"] == "Artist One")
    #expect(value?["index"] == "0")
    #expect(json?["play"] as? Bool == true)
}

@Test func commandRequestSupportsAskDJJsonObjectValues() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.66",
        appVersion: "3.1.66",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.commandRequest(
        DJConnectCommandPayload(
            identity: identity,
            command: "ask_dj_play_recommendation",
            value: .jsonObject([
                "title": .string("Late night track mix"),
                "kind": .string("track_mix"),
                "uris": .array([
                    .string("spotify:track:1"),
                    .string("spotify:track:2")
                ]),
                "music_dna_key": .string("djconnect_ios_8F3A2C91B45D")
            ]),
            play: true
        )
    )
    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    let value = try #require(json["value"] as? [String: Any])
    let uris = try #require(value["uris"] as? [String])

    #expect(json["command"] as? String == "ask_dj_play_recommendation")
    #expect(value["kind"] as? String == "track_mix")
    #expect(uris == ["spotify:track:1", "spotify:track:2"])
    #expect(json["play"] as? Bool == true)
}

@Test func commandRequestSupportsAskDJFollowupResponseValues() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-watchos-8F3A2C91B45D",
        deviceName: "Apple Watch",
        clientType: .watchos,
        firmware: "3.1.66",
        appVersion: "3.1.66",
        platform: .watchos
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.commandRequest(
        DJConnectCommandPayload(
            identity: identity,
            command: "ask_dj_followup_response",
            value: .jsonObject([
                "title": .string("Ja"),
                "response_value": .string("yes"),
                "music_dna_key": .string("djconnect_watchos_8F3A2C91B45D")
            ]),
            play: false
        )
    )
    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    let value = try #require(json["value"] as? [String: Any])

    #expect(json["command"] as? String == "ask_dj_followup_response")
    #expect(value["response_value"] as? String == "yes")
    #expect(json["play"] as? Bool == false)
}

@Test func commandRequestForwardsAskDJOutputActionPayload() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.66",
        appVersion: "3.1.66",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.commandRequest(
        DJConnectCommandPayload(
            identity: identity,
            command: "set_output",
            value: .jsonObject([
                "id": .string("output-action-1"),
                "title": .string("Woonkamer"),
                "kind": .string("output"),
                "device_id": .string("spotify-device-1"),
                "device_name": .string("Woonkamer"),
                "command": .string("set_output"),
                "response_value": .string("spotify-device-1"),
                "music_dna_key": .string("djconnect_ios_8F3A2C91B45D")
            ])
        )
    )
    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    let value = try #require(json["value"] as? [String: Any])

    #expect(request.url?.path == "/api/djconnect/v1/command")
    #expect(json["command"] as? String == "set_output")
    #expect(value["kind"] as? String == "output")
    #expect(value["device_id"] as? String == "spotify-device-1")
    #expect(value["response_value"] as? String == "spotify-device-1")
    #expect(json["device_id"] as? String == identity.deviceID)
    #expect(json["device_name"] as? String == identity.deviceName)
    #expect(json["client_type"] as? String == "ios")
    #expect(json["client_id"] as? String == identity.deviceID)
    #expect(json["play"] == nil)
}

@MainActor
@Test func transportFallsBackFromLocalToRemoteAfterPairing() async throws {
    let localURL = try #require(URL(string: "http://192.168.1.13:8123"))
    let remoteURL = try #require(URL(string: "https://example.ui.nabu.casa"))
    let recorder = ConnectionModeRecorder()
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.2.0",
        platform: .ios
    )
    let transport = DJConnectHATransportManager(
        localURL: localURL,
        remoteURL: remoteURL,
        allowsRemoteFallback: true,
        clientFactory: { baseURL in
            DJConnectClient(baseURL: baseURL, identity: identity, tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"))
        },
        modeReporter: { mode, _ in recorder.append(mode) }
    )

    let result = try await transport.perform { client in
        if client.baseURL == localURL {
            throw DJConnectError.network(message: "local timeout")
        }
        return client.baseURL.absoluteString
    }

    #expect(result == "https://example.ui.nabu.casa")
    #expect(recorder.modes == [.remote])
}

@MainActor
@Test func transportReportsOfflineWhenNoURLIsReachable() async throws {
    let recorder = ConnectionModeRecorder()
    let identity = DJConnectIdentity(
        deviceID: "djconnect-macos-8F3A2C91B45D",
        deviceName: "DJConnect Mac",
        clientType: .macos,
        firmware: "3.2.0",
        platform: .macos
    )
    let transport = DJConnectHATransportManager(
        localURL: URL(string: "http://192.168.1.13:8123"),
        remoteURL: URL(string: "https://example.ui.nabu.casa"),
        allowsRemoteFallback: true,
        clientFactory: { baseURL in
            DJConnectClient(baseURL: baseURL, identity: identity, tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"))
        },
        modeReporter: { mode, _ in recorder.append(mode) }
    )

    do {
        _ = try await transport.perform { _ in
            throw DJConnectError.network(message: "unreachable")
        } as String
        Issue.record("Expected transport to throw when local and remote are unreachable")
    } catch let error as DJConnectError {
        #expect(error == .network(message: "unreachable"))
    }

    #expect(recorder.modes == [.offline])
}

@Test func pairingAndCommandResponsesDecodeMusicBackendSummary() throws {
    let decoder = JSONDecoder()
    let pairing = try decoder.decode(
        DJConnectPairingResponse.self,
        from: Data(
            """
            {
              "success": true,
              "device_token": "device-secret",
              "ha_local_url": "http://192.168.1.13:8123",
              "ha_remote_url": "https://example.ui.nabu.casa",
              "remote_supported": true,
              "music_backend": "music_assistant",
              "music_backend_name": "Music Assistant",
              "music_backend_available": true,
              "music_backend_revision": 4,
              "music_backend_capabilities": {
                "supports_search": true,
                "supports_queue": true,
                "supports_outputs": true,
                "supports_favorites": false,
                "supports_recently_played": true,
                "supports_top_items": false
              },
              "music_target_player": {
                "id": "media_player.mass_woonkamer",
                "name": "Woonkamer"
              }
            }
            """.utf8
        )
    )
    let command = try decoder.decode(
        DJConnectCommandResponse.self,
        from: Data(
            """
            {
              "success": true,
              "music_backend": "spotify_direct",
              "music_backend_name": "Spotify Direct",
              "music_backend_available": false,
              "music_backend_error": "Backend unavailable"
            }
            """.utf8
        )
    )

    #expect(pairing.haRemoteURL == "https://example.ui.nabu.casa")
    #expect(pairing.remoteSupported == true)
    #expect(pairing.musicBackend == "music_assistant")
    #expect(pairing.musicBackendCapabilities?.supportsFavorites == false)
    #expect(pairing.musicTargetPlayer?.id == "media_player.mass_woonkamer")
    #expect(command.musicBackendName == "Spotify Direct")
    #expect(command.musicBackendAvailable == false)
    #expect(command.musicBackendError == "Backend unavailable")
}

@Test func commandPayloadPreservesMusicAssistantActionValueAndRevision() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.2.0",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.commandRequest(DJConnectCommandPayload(
        identity: identity,
        command: "ask_dj_play_recommendation",
        value: .jsonObject([
            "item_id": .string("track-123"),
            "provider": .string("library"),
            "media_type": .string("track"),
            "target_player_id": .string("media_player.mass_woonkamer")
        ]),
        play: true,
        musicBackendRevision: 4
    ))
    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    let value = try #require(json["value"] as? [String: Any])

    #expect(value["item_id"] as? String == "track-123")
    #expect(value["provider"] as? String == "library")
    #expect(value["media_type"] as? String == "track")
    #expect(value["target_player_id"] as? String == "media_player.mass_woonkamer")
    #expect(value["uri"] == nil)
    #expect(json["music_backend_revision"] as? Int == 4)
}

@MainActor
@Test func outputDevicesIncludeNoOutputBeforeBackendDevices() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    model.language = "nl"

    model.apply(commandResponse: DJConnectCommandResponse(
        success: true,
        backendAvailable: true,
        devices: [
            DJConnectOutputDevice(id: "speaker", name: "Woonkamer", active: true)
        ]
    ))

    let noOutputName = DJConnectLocalization.localized(key: "ui.no.output.device.selected", language: "nl")
    #expect(model.availableOutputs.map(\.name).prefix(2) == [noOutputName, "Woonkamer"])
    #expect(model.selectedOutput == "Woonkamer")

    model.selectOutput(model.availableOutputs[0])
    #expect(model.selectedOutput == noOutputName)
    #expect(model.availableOutputs[0].active == true)
    #expect(model.availableOutputs[1].active == false)
}

@MainActor
@Test func playNowCommandResponseAppendsAssistantBubbleWithoutReusingOldActions() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    let oldAction = DJConnectAskDJPlaybackAction(
        id: "old-action",
        title: "Play old",
        uri: "spotify:track:old",
        command: "ask_dj_play_recommendation"
    )
    model.applyAskDJMessageResponse(DJConnectAskDJMessageResponse(
        assistantMessage: DJConnectAskDJHistoryMessage(
            id: "previous-assistant",
            role: .assistant,
            text: "Eerdere suggestie",
            createdAt: Date(timeIntervalSince1970: 1),
            playbackActions: [oldAction]
        )
    ), fallbackUserMessageID: nil)

    let response = DJConnectCommandResponse(
        success: true,
        message: "Playing now",
        assistantMessage: DJConnectAskDJHistoryMessage(
            id: "play-now-assistant",
            role: .assistant,
            origin: "play_now",
            text: "Ik zet Winner nu aan.",
            createdAt: Date(timeIntervalSince1970: 2),
            audioURL: URL(string: "https://example.test/audio/play-now.mp3"),
            playbackActions: []
        ),
        playbackActions: []
    )

    #expect(model.applyAskDJPlayNowCommandResponse(response) == true)

    #expect(model.askDJMessages.count == 2)
    let previous = model.askDJMessages[0]
    let playNow = model.askDJMessages[1]
    #expect(previous.playbackActions.map(\.id) == ["old-action"])
    #expect(playNow.role == .dj)
    #expect(playNow.serverID == "play-now-assistant")
    #expect(playNow.origin == "play_now")
    #expect(playNow.text == "Ik zet Winner nu aan.")
    #expect(playNow.audioURL?.absoluteString == "https://example.test/audio/play-now.mp3")
    #expect(playNow.playbackActions.isEmpty)
}

@MainActor
@Test func appStartsWithNoOutputSelected() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)

    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )
    await Task.yield()

    #expect(model.selectedOutput == DJConnectLocalization.localized(key: "ui.no.output.device.selected", language: model.language))
}

@MainActor
@Test func defaultLanguageUsesDeviceLanguageUntilAppOverrideIsSet() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let sharedDefaults = try #require(UserDefaults(suiteName: DJConnectLocalization.appGroupIdentifier))
    let oldSharedOverride = sharedDefaults.string(forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
    sharedDefaults.removeObject(forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
    defer {
        if let oldSharedOverride {
            sharedDefaults.set(oldSharedOverride, forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
        } else {
            sharedDefaults.removeObject(forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
        }
    }

    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )

    #expect(model.language == DJConnectLocalization.preferredLanguageCode())
    #expect(model.appLanguageOverrideCode == "")

    model.setAppLanguageOverride("nl")
    #expect(model.language == "nl")
    #expect(model.appLanguageOverrideCode == "nl")
    #expect(defaults.string(forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey) == "nl")
    #expect(sharedDefaults.string(forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey) == "nl")

    model.setAppLanguageOverride("")
    #expect(model.language == DJConnectLocalization.preferredLanguageCode())
    #expect(model.appLanguageOverrideCode == "")
    #expect(defaults.string(forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey) == nil)
    #expect(sharedDefaults.string(forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey) == nil)
}

@MainActor
@Test func noOutputSelectionBlocksPlaybackStartCommands() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"),
        startBackgroundTasks: false
    )
    model.language = "nl"

    model.apply(commandResponse: DJConnectCommandResponse(
        success: true,
        backendAvailable: true,
        devices: [DJConnectOutputDevice(id: "speaker", name: "Woonkamer", active: false)]
    ))
    model.selectOutput(model.availableOutputs[0])
    model.sendPlaybackCommand("play")

    #expect(model.selectedOutput == DJConnectLocalization.localized(key: "ui.no.output.device.selected", language: "nl"))
    #expect(model.userNotice?.text == "Kies eerst een uitvoerapparaat")
}

@Test func queueContractDecodesItemsContextAndImageAliases() throws {
    let response = try JSONDecoder().decode(
        DJConnectCommandResponse.self,
        from: Data(
            """
            {
              "success": true,
              "queue": {
                "items": [
                  {
                    "title": "Song title",
                    "artist_name": "Artist name",
                    "album_name": "Album name",
                    "uri": "spotify:track:1",
                    "duration_ms": 213000,
                    "media_image_url": "https://example.test/media.jpg"
                  },
                  {
                    "title": "Song two",
                    "entity_picture": "https://example.test/entity.jpg"
                  }
                ],
                "context": "spotify:playlist:context"
              }
            }
            """.utf8
        )
    )

    #expect(response.success)
    #expect(response.queueContext == "spotify:playlist:context")
    #expect(response.queue?.count == 2)
    #expect(response.queue?.first?.artist == "Artist name")
    #expect(response.queue?.first?.album == "Album name")
    #expect(response.queue?.first?.durationMS == 213000)
    #expect(response.queue?.first?.albumImageURL?.absoluteString == "https://example.test/media.jpg")
    #expect(response.queue?.last?.albumImageURL?.absoluteString == "https://example.test/entity.jpg")
}

@Test func queueContractDecodesFlatHAQueueContextURI() throws {
    let response = try JSONDecoder().decode(
        DJConnectCommandResponse.self,
        from: Data(
            """
            {
              "success": true,
              "queue": [
                {
                  "title": "Next Song",
                  "artist": "Artist name",
                  "uri": "spotify:track:next",
                  "album_image_url": "https://example.test/queue.jpg"
                }
              ],
              "context_uri": "spotify:playlist:abc"
            }
            """.utf8
        )
    )

    #expect(response.success)
    #expect(response.queueContext == "spotify:playlist:abc")
    #expect(response.queue?.count == 1)
    #expect(response.queue?.first?.uri == "spotify:track:next")
    #expect(response.queue?.first?.albumImageURL?.absoluteString == "https://example.test/queue.jpg")
}

@Test func queueContractDecodesArtistSubtitleFallbackAndNestedContextURI() throws {
    let response = try JSONDecoder().decode(
        DJConnectCommandResponse.self,
        from: Data(
            """
            {
              "success": true,
              "queue": {
                "context_uri": "spotify:playlist:nested",
                "items": [
                  {
                    "id": "backend-row-1",
                    "uri": "spotify:track:nothing-else-matters",
                    "title": "Nothing Else Matters",
                    "subtitle": "Scala & Kolacny Brothers",
                    "album_name": "Scala on the Rocks",
                    "image_url": "https://example.test/nothing.jpg"
                  },
                  {
                    "id": "spotify:track:id-only",
                    "title": "ID Only",
                    "artist_name": "Artist Name",
                    "thumbnail_url": "https://example.test/thumb.jpg"
                  }
                ]
              }
            }
            """.utf8
        )
    )

    #expect(response.queueContext == "spotify:playlist:nested")
    #expect(response.queue?.count == 2)
    #expect(response.queue?.first?.id == "spotify:track:nothing-else-matters")
    #expect(response.queue?.first?.artist == "Scala & Kolacny Brothers")
    #expect(response.queue?.first?.album == "Scala on the Rocks")
    #expect(response.queue?.first?.displaySubtitle == "Scala & Kolacny Brothers • Scala on the Rocks")
    #expect(response.queue?.first?.albumImageURL?.absoluteString == "https://example.test/nothing.jpg")
    #expect(response.queue?.last?.id == "spotify:track:id-only")
    #expect(response.queue?.last?.artist == "Artist Name")
    #expect(response.queue?.last?.albumImageURL?.absoluteString == "https://example.test/thumb.jpg")
}

@MainActor
@Test func emptyBackendQueueClearsRenderedQueueItems() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)

    model.apply(commandResponse: DJConnectCommandResponse(
        success: true,
        queue: [DJConnectQueueItem(title: "Old queued track", uri: "spotify:track:old")]
    ))
    #expect(model.queueItems.count == 1)

    model.apply(commandResponse: DJConnectCommandResponse(success: true, queue: []))

    #expect(model.queueItems.isEmpty)
    #expect(model.queue.isEmpty)
}

@MainActor
@Test func repeatedBackendQueueItemsAreRenderedOnce() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    let repeatedItem = DJConnectQueueItem(
        title: "Summer Of 69",
        artist: "Bryan Adams",
        album: "Reckless",
        uri: "spotify:track:summer-of-69",
        durationMS: 216_000,
        albumImageURL: URL(string: "https://example.test/summer.jpg")
    )

    model.apply(commandResponse: DJConnectCommandResponse(
        success: true,
        queue: Array(repeating: repeatedItem, count: 7) + [
            DJConnectQueueItem(
                title: "Summer Of 69",
                artist: "Bryan Adams",
                album: "Reckless",
                uri: "spotify:track:summer-of-69",
                durationMS: 216_000,
                albumImageURL: URL(string: "https://example.test/summer-alt.jpg")
            )
        ]
    ))

    #expect(model.queueItems.count == 1)
    #expect(model.queueItems.first?.title == "Summer Of 69")
    #expect(model.queue == ["Summer Of 69 - Bryan Adams"])
}

@MainActor
@Test func playlistsCommandDoesNotOverwriteQueueWithPlaylistItems() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(DJConnectHAConnectionMode.local.rawValue, forKey: "DJConnectHAConnectionMode")
    let host = "playlist-items-are-not-queue.local"
    let session = mockSession(host: host) { request in
        if request.url?.path == "/api/djconnect/v1/music_dna/profile" {
            return (
                try httpResponse(for: request, statusCode: 200),
                Data(#"{"enabled":true,"profile":{}}"#.utf8)
            )
        }
        #expect(request.url?.path == "/api/djconnect/v1/command")
        let json = """
        {
          "success": true,
          "items": [
            {"id":"playlist-1","name":"Acid Trip","uri":"spotify:playlist:acid"},
            {"id":"playlist-2","name":"Lucy","uri":"spotify:playlist:lucy"}
          ]
        }
        """
        return (try httpResponse(for: request, statusCode: 200), Data(json.utf8))
    }
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"),
        urlSession: session,
        startBackgroundTasks: false
    )
    model.homeAssistantURL = "http://\(host):8123"
    model.pairingStatus = .paired
    model.apply(commandResponse: DJConnectCommandResponse(
        success: true,
        queue: [DJConnectQueueItem(title: "Real queued track", artist: "Real Artist", uri: "spotify:track:real")]
    ))
    let existingQueueSnapshot = DJConnectQueueWidgetSnapshot.load(from: defaults)

    let didLoad = await model.refreshPlaylists()

    #expect(didLoad)
    #expect(model.playlistItems.map(\.name) == ["Acid Trip", "Lucy"])
    #expect(model.queueItems.map(\.title) == ["Real queued track"])
    #expect(model.queue == ["Real queued track - Real Artist"])
    #expect(DJConnectQueueWidgetSnapshot.load(from: defaults) == existingQueueSnapshot)
}

@MainActor
@Test func queueEpisodeItemsCanStartWithoutPlaybackContext() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    let episode = DJConnectQueueItem(
        title: "Podcast Episode",
        artist: "Podcast",
        uri: "spotify:episode:episode-id"
    )

    #expect(model.canStartQueueItem(episode))
}

@Test func playlistContractDecodesArtworkAliases() throws {
    let response = try JSONDecoder().decode(
        DJConnectCommandResponse.self,
        from: Data(
            """
            {
              "success": true,
              "playlists": [
                {"id":"playlist-1","name":"Image URL","uri":"spotify:playlist:1","image_url":"https://example.test/image.jpg"},
                {"id":"playlist-2","name":"Album Image","uri":"spotify:playlist:2","album_image_url":"https://example.test/album.jpg"},
                {"id":"playlist-3","name":"Media Image","uri":"spotify:playlist:3","media_image_url":"https://example.test/media.jpg"},
                {"id":"playlist-4","name":"Entity Picture","uri":"spotify:playlist:4","entity_picture":"https://example.test/entity.jpg"}
              ]
            }
            """.utf8
        )
    )

    #expect(response.success)
    #expect(response.playlists?.map { $0.imageURL?.absoluteString } == [
        "https://example.test/image.jpg",
        "https://example.test/album.jpg",
        "https://example.test/media.jpg",
        "https://example.test/entity.jpg"
    ])
}

@Test func statusCommandResponseDecodesRichPlaybackSnapshot() throws {
    let response = try JSONDecoder().decode(
        DJConnectCommandResponse.self,
        from: Data(
            """
            {
              "success": true,
              "data": {
                "playback": {
                  "has_playback": true,
                  "is_playing": false,
                  "track_name": "Track One",
                  "artist_name": "Artist One",
                  "album_image_url": "https://example.test/art.jpg",
                  "progress_ms": 12000,
                  "duration_ms": 180000,
                  "volume_percent": 41,
                  "queue_context": "spotify:playlist:abc",
                  "device": {"name":"Living Room","active":true,"volume_percent":41}
                }
              }
            }
            """.utf8
        )
    )

    #expect(response.success)
    #expect(response.playback?.isPlaying == false)
    #expect(response.playback?.trackName == "Track One")
    #expect(response.playback?.albumImageURL?.absoluteString == "https://example.test/art.jpg")
    #expect(response.playback?.contextURI == "spotify:playlist:abc")
    #expect(response.playback?.device?.name == "Living Room")
}

@Test func commandResponseDecodesEmptyPlaybackSnapshotWithNullFields() throws {
    let response = try JSONDecoder().decode(
        DJConnectCommandResponse.self,
        from: Data(
            """
            {
              "success": true,
              "playback": {
                "has_playback": false,
                "is_playing": false,
                "title": null,
                "track_name": null,
                "artist": "",
                "artist_name": null,
                "album_name": null,
                "uri": null,
                "context_uri": null,
                "queue_context": null,
                "album_image_url": null,
                "media_image_url": null,
                "image_url": null,
                "entity_picture": null,
                "progress_ms": null,
                "duration_ms": null,
                "volume_percent": null,
                "device": {
                  "name": "",
                  "active": false,
                  "volume_percent": null
                }
              }
            }
            """.utf8
        )
    )

    #expect(response.success)
    #expect(response.playback?.hasPlayback == false)
    #expect(response.playback?.isPlaying == false)
    #expect(response.playback?.trackName == nil)
    #expect(response.playback?.artistName == nil)
    #expect(response.playback?.albumImageURL == nil)
    #expect(response.playback?.progressMS == nil)
    #expect(response.playback?.durationMS == nil)
    #expect(response.playback?.volumePercent == nil)
    #expect(response.playback?.contextURI == nil)
    #expect(response.playback?.device?.volumePercent == nil)
}

@Test func commandResponseDecodesBackendCollectionsFromDataEnvelope() throws {
    let response = try JSONDecoder().decode(
        DJConnectCommandResponse.self,
        from: Data(
            """
            {
              "success": true,
              "backend_available": true,
              "data": {
                "devices": [
                  {"id":"speaker-1","name":"Living Room","active":true,"supports_volume":true,"volume_percent":42},
                  "Kitchen"
                ],
                "queue": [
                  {"uri":"spotify:track:1","title":"Track One","artist":"Artist One","album_image_url":"https://example.test/track-one.jpg"},
                  "Track Two"
                ],
                "playlists": [
                  {"id":"playlist-1","name":"Warmup","uri":"spotify:playlist:1","image_url":"https://example.test/warmup.jpg"},
                  {"id":"playlist-2","name":"Dinner","uri":"spotify:playlist:2","album_image_url":"https://example.test/dinner.jpg"},
                  "Liked Proxy"
                ]
              }
            }
            """.utf8
        )
    )

    #expect(response.success)
    #expect(response.backendAvailable == true)
    #expect(response.devices?.map(\.name) == ["Living Room", "Kitchen"])
    #expect(response.devices?.first?.supportsVolume == true)
    #expect(response.queue?.map(\.displayTitle) == ["Track One - Artist One", "Track Two"])
    #expect(response.queue?.first?.albumImageURL?.absoluteString == "https://example.test/track-one.jpg")
    #expect(response.playlists?.map(\.commandValue) == ["spotify:playlist:1", "spotify:playlist:2", "Liked Proxy"])
    #expect(response.playlists?.first?.imageURL?.absoluteString == "https://example.test/warmup.jpg")
    #expect(response.playlists?[1].imageURL?.absoluteString == "https://example.test/dinner.jpg")
}

@Test func playlistCollectionsDecodeFromSupportedContractShapes() throws {
    let shapes = [
        #"{ "success": true, "playlists": [{"name":"Top","uri":"spotify:playlist:top"}] }"#,
        #"{ "success": true, "items": [{"name":"Top","uri":"spotify:playlist:top"}] }"#,
        #"{ "success": true, "data": { "playlists": [{"name":"Top","uri":"spotify:playlist:top"}] } }"#,
        #"{ "success": true, "data": { "items": [{"name":"Top","uri":"spotify:playlist:top"}] } }"#,
        #"{ "success": true, "result": { "playlists": [{"name":"Top","uri":"spotify:playlist:top"}] } }"#,
        #"{ "success": true, "result": { "items": [{"name":"Top","uri":"spotify:playlist:top"}] } }"#
    ]

    for shape in shapes {
        let response = try JSONDecoder().decode(DJConnectCommandResponse.self, from: Data(shape.utf8))
        #expect(response.playlists?.map(\.commandValue) == ["spotify:playlist:top"])
        #expect(response.playlists?.map(\.name) == ["Top"])
        #expect(response.devices == nil)
    }
}

@Test func playlistItemsDoNotDecodeAsOutputDevices() throws {
    let response = try JSONDecoder().decode(
        DJConnectCommandResponse.self,
        from: Data(
            """
            {
              "success": true,
              "items": [
                {"id":"playlist-1","name":"Acid Trip","uri":"spotify:playlist:1"},
                {"id":"playlist-2","name":"Lucy","playlist_uri":"spotify:playlist:2"}
              ]
            }
            """.utf8
        )
    )

    #expect(response.playlists?.map(\.name) == ["Acid Trip", "Lucy"])
    #expect(response.devices == nil)
}

@Test func playlistItemsDecodeAliasesForTitleValueSubtitleAndArtwork() throws {
    let response = try JSONDecoder().decode(
        DJConnectCommandResponse.self,
        from: Data(
            """
            {
              "success": true,
              "playlists": [
                {
                  "title": "Title Alias",
                  "value": "spotify:playlist:value",
                  "owner_name": "Owner Alias",
                  "imageUrl": "https://example.test/image-url.jpg"
                },
                {
                  "display_title": "Display Alias",
                  "playlist_uri": "spotify:playlist:playlist-uri",
                  "artists": ["Artist One", "Artist Two"],
                  "album_art_url": "https://example.test/album-art.jpg"
                },
                {
                  "name": "Thumbnail Alias",
                  "id": "playlist-id",
                  "subtitle": "Subtitle Alias",
                  "thumbnail_url": "https://example.test/thumb.jpg"
                }
              ]
            }
            """.utf8
        )
    )

    #expect(response.playlists?.map(\.name) == ["Title Alias", "Display Alias", "Thumbnail Alias"])
    #expect(response.playlists?.map(\.commandValue) == [
        "spotify:playlist:value",
        "spotify:playlist:playlist-uri",
        "playlist-id"
    ])
    #expect(response.playlists?.map(\.subtitle) == ["Owner Alias", "Artist One, Artist Two", "Subtitle Alias"])
    #expect(response.playlists?.map { $0.imageURL?.absoluteString } == [
        "https://example.test/image-url.jpg",
        "https://example.test/album-art.jpg",
        "https://example.test/thumb.jpg"
    ])
}

@Test func emptyPlaylistsResponseDecodesWithoutCrash() throws {
    let response = try JSONDecoder().decode(
        DJConnectCommandResponse.self,
        from: Data(#"{ "success": true, "backend_available": true, "playlists": [] }"#.utf8)
    )

    #expect(response.success)
    #expect(response.backendAvailable == true)
    #expect(response.playlists == [])
}

@Test func playlistsDecodeAtMostOneHundredItems() throws {
    let items = (0..<120)
        .map { #"{"name":"Playlist \#($0)","uri":"spotify:playlist:\#($0)"}"# }
        .joined(separator: ",")
    let response = try JSONDecoder().decode(
        DJConnectCommandResponse.self,
        from: Data(#"{ "success": true, "playlists": [\#(items)] }"#.utf8)
    )

    #expect(response.playlists?.count == 100)
    #expect(response.playlists?.first?.name == "Playlist 0")
    #expect(response.playlists?.last?.name == "Playlist 99")
}

@Test func queueDecodesOneHundredItemsFromTopLevelItems() throws {
    let items = (0..<100)
        .map { #"{"title":"Track \#($0)","artist":"Artist","uri":"spotify:track:\#($0)"}"# }
        .joined(separator: ",")
    let response = try JSONDecoder().decode(
        DJConnectCommandResponse.self,
        from: Data(#"{ "success": true, "items": [\#(items)] }"#.utf8)
    )

    #expect(response.queue?.count == 100)
    #expect(response.queue?.first?.displayTitle == "Track 0 - Artist")
    #expect(response.queue?.last?.uri == "spotify:track:99")
}

@Test func devicesDecodeFromOutputsAndItemsWithOptionalFields() throws {
    let outputsResponse = try JSONDecoder().decode(
        DJConnectCommandResponse.self,
        from: Data(#"{ "success": true, "outputs": [{ "name": "Living Room" }] }"#.utf8)
    )
    let itemsResponse = try JSONDecoder().decode(
        DJConnectCommandResponse.self,
        from: Data(#"{ "success": true, "items": [{ "id": "speaker-id", "type": "speaker", "active": false }] }"#.utf8)
    )

    #expect(outputsResponse.devices?.first?.name == "Living Room")
    #expect(outputsResponse.devices?.first?.id == "Living Room")
    #expect(itemsResponse.devices?.first?.id == "speaker-id")
    #expect(itemsResponse.devices?.first?.name == "speaker-id")
}

@Test func pairingRequestUsesPairEndpointWithoutBearerToken() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-macos-8F3A2C91B45D",
        deviceName: "DJConnect Mac",
        clientType: .macos,
        firmware: "3.1.7",
        appVersion: "3.1.7",
        platform: .macos
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore()
    )

    let request = try client.pairingRequest(
        DJConnectPairingPayload(identity: identity, pairingToken: "123456")
    )
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/v1/pair")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-ID") == nil)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-Type") == "macos")
    #expect(json?["client_id"] == nil)
    #expect(json?["client_name"] == nil)
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["device_name"] as? String == identity.deviceName)
    #expect(json?["client_type"] as? String == "macos")
    #expect(json?["pair_code"] as? String == "123456")
    #expect(json?["pairing_code"] as? String == "123456")
    #expect(json?["pairing_token"] as? String == "123456")
    #expect(json?["firmware"] as? String == "3.1.7")
}

@Test func appleAppInfoPlistsDeclareOnlySupportedBonjourServices() throws {
    let iOSPlist = try loadRepositoryPlist("Apps/DJConnectIOS/Info.plist")
    let macPlist = try loadRepositoryPlist("Apps/DJConnectMac/Info.plist")
    let iOSBonjourServices = try #require(iOSPlist["NSBonjourServices"] as? [String])
    let macBonjourServices = try #require(macPlist["NSBonjourServices"] as? [String])

    #expect(iOSBonjourServices == ["_home-assistant._tcp."])
    #expect(macBonjourServices == ["_home-assistant._tcp."])
    #expect(String(describing: iOSPlist).contains("_djconnect") == false)
    #expect(String(describing: macPlist).contains("_djconnect") == false)
}

@Test func iOSPairingRequestUsesPairEndpointWithoutLocalCallbackFields() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.2.3",
        appVersion: "3.2.3",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore()
    )

    let request = try client.pairingRequest(DJConnectPairingPayload(identity: identity, pairingToken: "123456"))
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/v1/pair")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == "djconnect-ios-8F3A2C91B45D")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-Type") == "ios")
    #expect(json?["device_id"] as? String == "djconnect-ios-8F3A2C91B45D")
    #expect(json?["device_name"] as? String == "DJConnect iPhone")
    #expect(json?["client_type"] as? String == "ios")
    #expect(json?["pair_code"] as? String == "123456")
    #expect(json?["callback_url"] == nil)
    #expect(json?["local_url"] == nil)
    #expect(json?["pair_path"] == nil)
}

@Test func iOSPairingDeepLinkParsesHomeAssistantPayload() throws {
    let url = try #require(URL(string: "djconnect://pair?ha_url=http%3A%2F%2Fhomeassistant.local%3A8123&pair_code=123456&client_type=ios&pair_path=%2Fapi%2Fdjconnect%2Fv1%2Fpair"))

    let payload = try DJConnectPairingDeepLink.parse(url, expectedClientType: .ios)

    #expect(payload.homeAssistantURL == "http://homeassistant.local:8123")
    #expect(payload.pairCode == "123456")
    #expect(payload.clientType == .ios)
    #expect(payload.pairPath == "/api/djconnect/v1/pair")
}

@Test func iOSPairingDeepLinkStillParsesLegacyPairPath() throws {
    let url = try #require(URL(string: "djconnect://pair?ha_url=http%3A%2F%2Fhomeassistant.local%3A8123&pair_code=123456&client_type=ios&pair_path=%2Fapi%2Fdjconnect%2Fpair"))

    let payload = try DJConnectPairingDeepLink.parse(url, expectedClientType: .ios)

    #expect(payload.homeAssistantURL == "http://homeassistant.local:8123")
    #expect(payload.pairCode == "123456")
    #expect(payload.clientType == .ios)
    #expect(payload.pairPath == "/api/djconnect/pair")
}

@Test func pairingURLPolicyAllowsNgrokFreeDevelopmentTunnel() throws {
    let url = try #require(URL(string: "https://victory-curvy-refold.ngrok-free.dev"))
    let pairingLink = try #require(URL(string: "djconnect://pair?ha_url=https%3A%2F%2Fvictory-curvy-refold.ngrok-free.dev&pair_code=123456&client_type=ios&pair_path=%2Fapi%2Fdjconnect%2Fv1%2Fpair"))

    #expect(DJConnectPairingURLPolicy.isAllowedPairingURL(url))
    #expect(DJConnectPairingURLPolicy.isWhitelistedDevelopmentTunnelURL(url))

    let payload = try DJConnectPairingDeepLink.parse(pairingLink, expectedClientType: .ios)

    #expect(payload.homeAssistantURL == "https://victory-curvy-refold.ngrok-free.dev")
    #expect(payload.pairCode == "123456")
}

@Test func pairingURLPolicyRequiresPlausibleHomeAssistantHostSyntax() throws {
    let localMDNS = try #require(URL(string: "http://homeassistant.local:8123"))
    let localIP = try #require(URL(string: "http://192.168.1.10:8123"))
    let localhost = try #require(URL(string: "http://localhost:8123"))
    let bareWord = try #require(URL(string: "http://ddd"))
    let partialIP = try #require(URL(string: "http://192."))
    let bareWordPairingLink = try #require(URL(string: "djconnect://pair?ha_url=http%3A%2F%2Fddd&pair_code=123456&client_type=ios&pair_path=%2Fapi%2Fdjconnect%2Fv1%2Fpair"))

    #expect(DJConnectPairingURLPolicy.isAllowedPairingURL(localMDNS))
    #expect(DJConnectPairingURLPolicy.isAllowedPairingURL(localIP))
    #expect(DJConnectPairingURLPolicy.isAllowedPairingURL(localhost))
    #expect(!DJConnectPairingURLPolicy.isAllowedPairingURL(bareWord))
    #expect(!DJConnectPairingURLPolicy.isAllowedPairingURL(partialIP))
    #expect(throws: DJConnectError.self) {
        _ = try DJConnectPairingDeepLink.parse(bareWordPairingLink, expectedClientType: .ios)
    }
}

@Test func pairingURLPolicyRejectsNonWhitelistedRemoteHTTPS() throws {
    let nabuCasa = try #require(URL(string: "https://example.ui.nabu.casa"))

    #expect(!DJConnectPairingURLPolicy.isAllowedPairingURL(nabuCasa))
    #expect(!DJConnectPairingURLPolicy.isWhitelistedDevelopmentTunnelURL(nabuCasa))
}

@Test func iOSPairingDeepLinkRejectsInvalidPayloads() throws {
    let missingURL = try #require(URL(string: "djconnect://pair?pair_code=123456&client_type=ios&pair_path=%2Fapi%2Fdjconnect%2Fv1%2Fpair"))
    let remoteURL = try #require(URL(string: "djconnect://pair?ha_url=https%3A%2F%2Fexample.ui.nabu.casa&pair_code=123456&client_type=ios&pair_path=%2Fapi%2Fdjconnect%2Fv1%2Fpair"))
    let badCode = try #require(URL(string: "djconnect://pair?ha_url=http%3A%2F%2Fhomeassistant.local%3A8123&pair_code=12AB56&client_type=ios&pair_path=%2Fapi%2Fdjconnect%2Fv1%2Fpair"))
    let wrongClient = try #require(URL(string: "djconnect://pair?ha_url=http%3A%2F%2Fhomeassistant.local%3A8123&pair_code=123456&client_type=macos&pair_path=%2Fapi%2Fdjconnect%2Fv1%2Fpair"))
    let wrongPath = try #require(URL(string: "djconnect://pair?ha_url=http%3A%2F%2Fhomeassistant.local%3A8123&pair_code=123456&client_type=ios&pair_path=%2Fapi%2Fdevice%2Fpair"))

    for url in [missingURL, remoteURL, badCode, wrongClient, wrongPath] {
        #expect(throws: DJConnectError.self) {
            _ = try DJConnectPairingDeepLink.parse(url, expectedClientType: .ios)
        }
    }
}

@Test func watchPairingDeepLinkParsesHomeAssistantPayload() throws {
    let url = try #require(URL(string: "djconnect://pair?ha_url=http%3A%2F%2Fhomeassistant.local%3A8123&pair_code=123456&client_type=watchos&pair_path=%2Fapi%2Fdjconnect%2Fv1%2Fpair"))

    let payload = try DJConnectPairingDeepLink.parse(url, expectedClientType: .watchos)

    #expect(payload.homeAssistantURL == "http://homeassistant.local:8123")
    #expect(payload.pairCode == "123456")
    #expect(payload.clientType == .watchos)
    #expect(payload.pairPath == "/api/djconnect/v1/pair")
}

@Test func watchPairingDeepLinkRejectsWrongClientTypeAndPairPath() throws {
    let wrongClient = try #require(URL(string: "djconnect://pair?ha_url=http%3A%2F%2Fhomeassistant.local%3A8123&pair_code=123456&client_type=ios&pair_path=%2Fapi%2Fdjconnect%2Fv1%2Fpair"))
    let wrongPath = try #require(URL(string: "djconnect://pair?ha_url=http%3A%2F%2Fhomeassistant.local%3A8123&pair_code=123456&client_type=watchos&pair_path=%2Fapi%2Fdevice%2Fpair"))

    #expect(throws: DJConnectError.self) {
        _ = try DJConnectPairingDeepLink.parse(wrongClient, expectedClientType: .watchos)
    }
    #expect(throws: DJConnectError.self) {
        _ = try DJConnectPairingDeepLink.parse(wrongPath, expectedClientType: .watchos)
    }
}

@Test func watchPairingRequestUsesHomeAssistantPairEndpoint() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-watchos-8F3A2C91B45D",
        deviceName: "Apple Watch van Peter",
        clientType: .watchos,
        firmware: "3.2.3",
        appVersion: "3.2.3",
        platform: .watchos
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore()
    )

    let request = try client.pairingRequest(DJConnectPairingPayload(identity: identity, pairingToken: "123456"))
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/v1/pair")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == "djconnect-watchos-8F3A2C91B45D")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-Type") == "watchos")
    #expect(json?["device_id"] as? String == "djconnect-watchos-8F3A2C91B45D")
    #expect(json?["device_name"] as? String == "Apple Watch van Peter")
    #expect(json?["client_type"] as? String == "watchos")
    #expect(json?["pair_code"] as? String == "123456")
    #expect(json?["callback_url"] == nil)
    #expect(json?["local_url"] == nil)
    #expect(json?["pair_path"] == nil)
}

@Test func iPhoneWatchProxyPairRequestPreservesWatchIdentity() async throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-watchos-8F3A2C91B45D",
        deviceName: "Apple Watch van Peter",
        clientType: .watchos,
        firmware: "3.2.3",
        appVersion: "3.2.3",
        platform: .watchos
    )
    let tokenStore = DJConnectInMemoryTokenStore()
    let host = "watch-pair-proxy.local"
    let session = mockSession(host: host) { request in
        #expect(request.url?.path == "/api/djconnect/v1/pair")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == "djconnect-watchos-8F3A2C91B45D")
        #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-Type") == "watchos")
        return (
            try httpResponse(for: request, statusCode: 200),
            Data(
                """
                {
                  "success": true,
                  "client_type": "watchos",
                  "device_token": "watch-secret",
                  "ha_local_url": "http://\(host):8123",
                  "api_base": "/api/djconnect/v1",
                  "voice_path": "/api/djconnect/v1/voice",
                  "status_path": "/api/djconnect/v1/status",
                  "event_path": "/api/djconnect/event",
                  "ask_dj_supported": true,
                  "ask_dj_voice_supported": true,
                  "ask_dj_audio_response_supported": true
                }
                """.utf8
            )
        )
    }
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://\(host):8123")),
        identity: identity,
        tokenStore: tokenStore,
        session: session
    )

    let response = try await client.pair(DJConnectPairingPayload(identity: identity, pairingToken: "123456"))

    #expect(response.success)
    #expect(response.clientType == .watchos)
    #expect(response.apiBase == "/api/djconnect/v1")
    #expect(response.askDJVoiceSupported == true)
    #expect(try tokenStore.loadToken() == "watch-secret")
}

@Test func pairingRequestRejectsMismatchedClientTypeAndDeviceIDPrefix() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect Mac",
        clientType: .macos,
        firmware: "3.2.3",
        appVersion: "3.2.3",
        platform: .macos
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore()
    )

    #expect(throws: DJConnectError.invalidConfiguration("DJConnect pairing identity mismatch: device_id prefix does not match client_type.")) {
        _ = try client.pairingRequest(DJConnectPairingPayload(identity: identity, pairingToken: "123456"))
    }
}

@Test func pairingResponseAcceptsCommonTokenFieldNames() throws {
    let decoder = JSONDecoder()

    let deviceToken = try decoder.decode(
        DJConnectPairingResponse.self,
        from: Data(#"{"success":true,"device_token":"device-secret"}"#.utf8)
    )
    let bearerToken = try decoder.decode(
        DJConnectPairingResponse.self,
        from: Data(#"{"success":true,"bearer_token":"bearer-secret"}"#.utf8)
    )
    let token = try decoder.decode(
        DJConnectPairingResponse.self,
        from: Data(#"{"success":true,"token":"plain-secret"}"#.utf8)
    )

    #expect(deviceToken.resolvedDeviceToken == "device-secret")
    #expect(bearerToken.resolvedDeviceToken == "bearer-secret")
    #expect(token.resolvedDeviceToken == "plain-secret")
}

@MainActor
@Test func pairingResponseStoresHALocalURLAndKeepsDeviceLanguage() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    model.language = "en"
    let response = DJConnectPairingResponse(
        success: true,
        deviceToken: "device-secret",
        token: nil,
        bearerToken: nil,
        message: nil,
        deviceID: model.identity.deviceID,
        clientType: model.identity.clientType,
        haLocalURL: "http://192.168.1.13:8123",
        haRemoteURL: "https://remote.ui.nabu.casa",
        deviceLanguage: "nl",
        language: "en",
        assistPipelineID: "preferred",
        apiBase: "/api/djconnect/v1",
        voicePath: "/api/djconnect/v1/voice",
        statusPath: "/api/djconnect/v1/status",
        eventPath: "/api/djconnect/event",
        askDJSupported: true,
        askDJVoiceSupported: true,
        askDJAudioResponseSupported: true
    )

    model.apply(pairingResponse: response, fallbackBaseURL: try #require(URL(string: "http://fallback.local:8123")))

    #expect(model.homeAssistantURL == "http://192.168.1.13:8123")
    #expect(model.haLocalURL == "http://192.168.1.13:8123")
    #expect(model.haRemoteURL == "https://remote.ui.nabu.casa")
    #expect(model.language == "en")
    #expect(model.assistPipelineID == "preferred")
    #expect(model.apiBase == "/api/djconnect/v1")
    #expect(model.voicePath == "/api/djconnect/v1/voice")
    #expect(model.statusPath == "/api/djconnect/v1/status")
    #expect(model.eventPath == "/api/djconnect/event")
    #expect(model.askDJSupported)
    #expect(model.askDJVoiceSupported)
    #expect(model.askDJAudioResponseSupported)
    #expect(defaults.string(forKey: "DJConnectHARemoteURL") == "https://remote.ui.nabu.casa")
    #expect(defaults.string(forKey: "DJConnectAPIBase") == "/api/djconnect/v1")
}

@MainActor
@Test func macOSPairingPostsOnlyToHomeAssistantPairEndpoint() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(true, forKey: "DJConnectWelcomeSeen")
    defaults.set("ABCDEF1234567890", forKey: "DJConnectInstallID")
    let tokenStore = DJConnectInMemoryTokenStore()
    let host = "pair-macos.local"
    let recorder = RequestPathRecorder()
    let session = mockSession(host: host) { request in
        recorder.append(request.url?.path ?? "")
        #expect(request.url?.path == "/api/djconnect/v1/pair")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == "djconnect-macos-ABCDEF123456")
        return (
            try httpResponse(for: request, statusCode: 200),
            Data(
                """
                {
                  "success": true,
                  "client_type": "macos",
                  "device_token": "device-secret",
                  "ha_local_url": "http://\(host):8123",
                  "ha_remote_url": "https://example.ui.nabu.casa",
                  "api_base": "/api/djconnect/v1",
                  "voice_path": "/api/djconnect/v1/voice",
                  "status_path": "/api/djconnect/v1/status",
                  "event_path": "/api/djconnect/event",
                  "ask_dj_supported": true,
                  "ask_dj_voice_supported": true,
                  "ask_dj_audio_response_supported": true
                }
                """.utf8
            )
        )
    }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: tokenStore, urlSession: session, startBackgroundTasks: false)
    defer {
        model.stopPairingWait()
    }
    model.homeAssistantURL = "http://\(host):8123"
    model.pairingToken = "123456"

    model.confirmPairingHomeAssistantURL()

    for _ in 0..<20 where model.pairingStatus != .waitingForHomeAssistantCompletion {
        try await Task.sleep(for: .milliseconds(100))
    }

    #expect(model.pairingStatus == .waitingForHomeAssistantCompletion)
    #expect(model.pairingMessage?.contains("Home Assistant") == true)
    #expect(model.pairingMessage?.contains("setup") == true)
    #expect(recorder.paths == ["/api/djconnect/v1/pair"])
    #expect(!recorder.paths.contains { $0.hasPrefix("/api/device/") })
    #expect(try tokenStore.loadToken() == "device-secret")
    #expect(model.haRemoteURL == "https://example.ui.nabu.casa")
    #expect(model.apiBase == "/api/djconnect/v1")
    #expect(model.askDJSupported)
}

@MainActor
@Test func macOSPairingCompletesOnlyAfterAuthenticatedStatusSucceeds() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(true, forKey: "DJConnectWelcomeSeen")
    defaults.set("ABCDEF1234567890", forKey: "DJConnectInstallID")
    let tokenStore = DJConnectInMemoryTokenStore()
    let host = "pair-status-macos.local"
    let recorder = RequestPathRecorder()
    let session = mockSession(host: host) { request in
        recorder.append(request.url?.path ?? "")
        if request.url?.path == "/api/djconnect/v1/status" {
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer device-secret")
            return (
                try httpResponse(for: request, statusCode: 200),
                Data(#"{"success":true,"ha_major_minor":"3.2","playback":{"has_playback":false},"music_backend_available":true}"#.utf8)
            )
        }
        if request.url?.path == "/api/djconnect/v1/command" {
            return (
                try httpResponse(for: request, statusCode: 200),
                Data(#"{"success":true,"ha_major_minor":"3.2","playback":{"has_playback":false},"music_backend_available":true}"#.utf8)
            )
        }
        if request.url?.path == "/api/djconnect/v1/music_dna/profile" {
            return (
                try httpResponse(for: request, statusCode: 200),
                Data(#"{"enabled":true,"profile":{}}"#.utf8)
            )
        }
        #expect(request.url?.path == "/api/djconnect/v1/pair")
        return (
            try httpResponse(for: request, statusCode: 200),
            Data(
                """
                {
                  "success": true,
                  "setup_pending": true,
                  "client_type": "macos",
                  "device_token": "device-secret",
                  "ha_local_url": "http://\(host):8123"
                }
                """.utf8
            )
        )
    }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: tokenStore, urlSession: session, startBackgroundTasks: true)
    defer {
        model.stopPairingWait()
    }
    model.homeAssistantURL = "http://\(host):8123"
    model.pairingToken = "123456"

    model.confirmPairingHomeAssistantURL()

    for _ in 0..<30 where model.pairingStatus != .paired {
        try await Task.sleep(for: .milliseconds(100))
    }

    #expect(model.pairingStatus == .paired)
    #expect(model.pairingMessage == "Pairing complete." || model.pairingMessage == "Koppeling voltooid.")
    #expect(recorder.paths.contains("/api/djconnect/v1/pair"))
    #expect(recorder.paths.contains("/api/djconnect/v1/status"))
}

@MainActor
@Test func appLifecycleTracksForegroundStateForBatterySensitiveWork() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)

    #expect(model.isAppInForegroundForTests)

    model.markInactiveSession()
    #expect(!model.isAppInForegroundForTests)

    model.markActiveSession()
    #expect(model.isAppInForegroundForTests)
}

@Test func pairSuccessStoresReturnedBearerToken() async throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.7",
        appVersion: "3.1.7",
        platform: .ios
    )
    let tokenStore = DJConnectInMemoryTokenStore()
    let host = "pair-success.local"
    let session = mockSession(host: host) { request in
        #expect(request.url?.path == "/api/djconnect/v1/pair")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-ID") == nil)
        #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
        return (
            try httpResponse(for: request, statusCode: 200),
            Data(#"{"success":true,"device_token":"client-secret","ha_local_url":"http://192.168.1.13:8123","language":"nl"}"#.utf8)
        )
    }
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://\(host):8123")),
        identity: identity,
        tokenStore: tokenStore,
        session: session
    )

    let response = try await client.pair(DJConnectPairingPayload(identity: identity, pairingToken: "123456"))

    #expect(response.success)
    #expect(try tokenStore.loadToken() == "client-secret")
}

@Test func pairPendingResponseDoesNotStoreToken() async throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-macos-8F3A2C91B45D",
        deviceName: "DJConnect Mac",
        clientType: .macos,
        firmware: "3.1.7",
        appVersion: "3.1.7",
        platform: .macos
    )
    let tokenStore = DJConnectInMemoryTokenStore()
    let host = "pair-pending.local"
    let session = mockSession(host: host) { request in
        (
            try httpResponse(for: request, statusCode: 200),
            Data(#"{"success":false,"message":"Waiting for setup"}"#.utf8)
        )
    }
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://\(host):8123")),
        identity: identity,
        tokenStore: tokenStore,
        session: session
    )

    await #expect(throws: DJConnectError.pairingFailed(message: "Waiting for setup")) {
        try await client.pair(DJConnectPairingPayload(identity: identity, pairingToken: "123456"))
    }
    #expect(try tokenStore.loadToken() == nil)
}

@MainActor
@Test func diagnosticsExportRedactsPairingCodesAndTokenState() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set("123456", forKey: "DJConnectPairingToken")
    defaults.set("http://user:password@homeassistant.local:8123/path?token=secret", forKey: "DJConnectHomeAssistantURL")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"), startBackgroundTasks: false)

    let export = model.diagnosticExportText()

    #expect(export.contains("bearer_token: present"))
    #expect(export.contains("bundle_id:"))
    #expect(export.contains("locale:"))
    #expect(export.contains("app_store_review_demo_available: true"))
    #expect(export.contains("ha_connection_mode: offline"))
    #expect(export.contains("playback_features_enabled:"))
    #expect(export.contains("fast_path_transport:"))
    #expect(export.contains("fast_path_websocket_connected:"))
    #expect(export.contains("fast_path_websocket_commands:"))
    #expect(export.contains("fast_path_last_error:"))
    #expect(export.contains("output_count:"))
    #expect(export.contains("microphone_permission:"))
    #expect(export.contains("speech_permission:"))
    #expect(export.contains("notification_permission:"))
    #expect(export.contains("local_network_permission:"))
    #expect(!export.contains("secret-token"))
    #expect(!export.contains("user:password"))
    #expect(!export.contains("token=secret"))
    #expect(!export.contains("123456"))
}

@MainActor
@Test func diagnosticLogsPersistAcrossModelLaunches() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let logDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("DJConnectTests-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: logDirectory)
    }

    _ = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false,
        diagnosticLogDirectory: logDirectory
    )

    let logFile = logDirectory.appendingPathComponent("djconnect.log")
    let persisted = try String(contentsOf: logFile, encoding: .utf8)
    #expect(persisted.contains("App started without DJConnect bearer token"))

    let relaunched = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false,
        diagnosticLogDirectory: logDirectory
    )

    #expect(relaunched.diagnosticLogLines.contains { $0.text.contains("App started without DJConnect bearer token") })
}

@MainActor
@Test func clearingDiagnosticLogsClearsPersistentLogHistory() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let logDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("DJConnectTests-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: logDirectory)
    }

    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false,
        diagnosticLogDirectory: logDirectory
    )
    model.clearDiagnosticLog()

    let logFile = logDirectory.appendingPathComponent("djconnect.log")
    let clearedLog = try String(contentsOf: logFile, encoding: .utf8)
    #expect(!clearedLog.contains("App started without DJConnect bearer token"))
    #expect(clearedLog.contains("Diagnostic log cleared"))

    let relaunched = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false,
        diagnosticLogDirectory: logDirectory
    )

    #expect(relaunched.diagnosticLogLines.contains { $0.text.contains("Diagnostic log cleared") })
}

@Test func voiceRequestUsesRawWavContentType() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.7",
        platform: .ios
    )
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )
    let wav = Data([0x52, 0x49, 0x46, 0x46])

    let request = try client.voiceRequest(
        wavData: wav,
        mood: 120,
        djStyle: "warm_radio_dj",
        musicDNAKey: "djconnect-watchos-8F3A2C91B45D",
        language: "es-ES"
    )

    #expect(request.url?.path == "/api/djconnect/v1/voice")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "audio/wav")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-ID") == identity.deviceID)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-Name") == identity.deviceName)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-Type") == "ios")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Mood") == "100")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-DJ-Style") == "warm_radio_dj")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Music-DNA-Key") == "djconnect-watchos-8F3A2C91B45D")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Language") == "es-ES")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Locale") == "es-ES")
    #expect(request.httpBody == wav)
}

@Test func versionMismatchIsClassifiedWithoutClearingPairing() throws {
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: DJConnectIdentity(
            deviceID: "djconnect-ios-8F3A2C91B45D",
            deviceName: "DJConnect iPhone",
            clientType: .ios,
            firmware: "3.1.7",
            platform: .ios
        ),
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )
    let body = Data(
        """
        {
          "success": false,
          "error": "version_mismatch",
          "message": "DJConnect Home Assistant integration and device firmware major.minor versions must match.",
          "ha_version": "3.1.7",
          "ha_major_minor": "3.1",
          "firmware": "3.1.7",
          "firmware_major_minor": "3.0"
        }
        """.utf8
    )

    let error = client.classify(statusCode: 426, body: body)

    #expect(error == .versionMismatch(
        DJConnectVersionMismatch(
            message: "DJConnect Home Assistant integration and device firmware major.minor versions must match.",
            haVersion: "3.1.7",
            haMajorMinor: "3.1",
            firmware: "3.1.7",
            firmwareMajorMinor: "3.0"
        )
    ))
}

@Test func clientTypeMismatchIsClassifiedBeforeGenericBadRequest() throws {
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: DJConnectIdentity(
            deviceID: "djconnect-macos-8F3A2C91B45D",
            deviceName: "DJConnect Mac",
            clientType: .macos,
            firmware: "3.1.7",
            platform: .macos
        ),
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )
    let body = Data(
        """
        {
          "success": false,
          "error": "client_type_mismatch",
          "message": "Selected iOS pairing flow does not match this macOS app.",
          "expected_client_type": "macos",
          "received_client_type": "ios"
        }
        """.utf8
    )

    let error = client.classify(statusCode: 400, body: body)

    #expect(error == .clientTypeMismatch(
        message: "Selected iOS pairing flow does not match this macOS app.",
        expectedClientType: "macos",
        receivedClientType: "ios"
    ))
}

@Test func backendUnavailableIsNotAuthStale() throws {
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: DJConnectIdentity(
            deviceID: "djconnect-ios-8F3A2C91B45D",
            deviceName: "DJConnect iPhone",
            clientType: .ios,
            firmware: "3.1.7",
            platform: .ios
        ),
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )
    let body = Data(
        """
        {
          "success": false,
          "error": "backend_unavailable",
          "message": "Spotify authorization has expired or was revoked.",
          "backend_available": false,
          "playback": {}
        }
        """.utf8
    )

    let error = client.classify(statusCode: 503, body: body)

    #expect(error == .backendUnavailable(message: "Spotify authorization has expired or was revoked."))
}

@Test func twoHundredBackendUnavailableIsNotAuthStale() throws {
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: DJConnectIdentity(
            deviceID: "djconnect-ios-8F3A2C91B45D",
            deviceName: "DJConnect iPhone",
            clientType: .ios,
            firmware: "3.1.7",
            platform: .ios
        ),
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )
    let body = Data(
        """
        {
          "success": false,
          "backend_available": false,
          "error": "playback_backend_unavailable",
          "message": "Playback backend unavailable",
          "playlists": []
        }
        """.utf8
    )

    let error = client.classify(statusCode: 200, body: body)

    #expect(error == .backendUnavailable(message: "Playback backend unavailable"))
}

@Test func authAndRouteErrorsAreClassifiedAsStaleSetupStates() throws {
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: DJConnectIdentity(
            deviceID: "djconnect-macos-8F3A2C91B45D",
            deviceName: "DJConnect Mac",
            clientType: .macos,
            firmware: "3.1.7",
            platform: .macos
        ),
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let unauthorized = client.classify(
        statusCode: 401,
        body: Data(#"{"success":false,"message":"Token expired"}"#.utf8)
    )
    let missingRoute = client.classify(
        statusCode: 404,
        body: Data(#"{"success":false,"message":"Route missing"}"#.utf8)
    )

    #expect(unauthorized == .authStale(statusCode: 401, message: "Token expired"))
    #expect(missingRoute == .routeMissing(message: "Route missing"))
}

@Test func serverErrorsIncludeRedactedResponseBodyForDiagnostics() throws {
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: DJConnectIdentity(
            deviceID: "djconnect-macos-8F3A2C91B45D",
            deviceName: "DJConnect Mac",
            clientType: .macos,
            firmware: "3.1.7",
            platform: .macos
        ),
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let error = client.classify(
        statusCode: 500,
        body: Data(#"{"error":"server_error","device_token":"secret-token","detail":"entity setup failed"}"#.utf8)
    )

    #expect(error == .server(
        statusCode: 500,
        message: #"{"error":"server_error","device_token":"[redacted]","detail":"entity setup failed"}"#
    ))
}

@Test func decodeFailuresIncludeRedactedResponseBodyForDiagnostics() async throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-5ECE7DF8D495",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.13",
        platform: .ios
    )
    let host = "decode-failure.local"
    let session = mockSession(host: host) { request in
        (
            try httpResponse(for: request, statusCode: 200),
            Data(#"{"success":true,"playback":"not-an-object","device_token":"secret-token"}"#.utf8)
        )
    }
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://\(host):8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"),
        session: session
    )

    do {
        _ = try await client.sendCommandResponse(DJConnectCommandPayload(
            identity: identity,
            command: "next"
        ))
        Issue.record("Expected a decoding failure")
    } catch let error as DJConnectError {
        guard case let .decodingFailed(statusCode, endpoint, message) = error else {
            Issue.record("Expected decodingFailed, got \(error)")
            return
        }
        #expect(statusCode == 200)
        #expect(endpoint == "POST /api/djconnect/v1/command")
        #expect(message?.contains("response_body=") == true)
        #expect(message?.contains(#""device_token":"[redacted]""#) == true)
        #expect(message?.contains("secret-token") == false)
    } catch {
        Issue.record("Expected DJConnectError.decodingFailed, got \(error)")
    }
}

@Test func emptySuccessfulCommandBodyIsReportedAsContractError() async throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-5ECE7DF8D495",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.13",
        platform: .ios
    )
    let host = "empty-command-response.local"
    let session = mockSession(host: host) { request in
        (
            try httpResponse(for: request, statusCode: 200),
            Data()
        )
    }
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://\(host):8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"),
        session: session
    )

    do {
        _ = try await client.sendCommandResponse(DJConnectCommandPayload(
            identity: identity,
            command: "status"
        ))
        Issue.record("Expected a decoding failure")
    } catch let error as DJConnectError {
        guard case let .decodingFailed(statusCode, endpoint, message) = error else {
            Issue.record("Expected decodingFailed, got \(error)")
            return
        }
        #expect(statusCode == 200)
        #expect(endpoint == "POST /api/djconnect/v1/command")
        #expect(message?.contains("contract error") == true)
        #expect(message?.contains("<empty response body>") == true)
    } catch {
        Issue.record("Expected DJConnectError.decodingFailed, got \(error)")
    }
}

@MainActor
@Test func userInitiatedBackendErrorsShowConnectionNotice() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)

    model.emitUserConnectionNotice(for: .decodingFailed(statusCode: 200, endpoint: "POST /api/djconnect/v1/command", message: "bad shape"))
    #expect(["Geen verbinding met Home Assistant", "No connection to Home Assistant"].contains(model.userNotice?.text ?? ""))

    model.userNotice = nil
    model.emitUserConnectionNotice(for: .network(message: "offline"))
    #expect(["Geen verbinding met Home Assistant", "No connection to Home Assistant"].contains(model.userNotice?.text ?? ""))

    model.userNotice = nil
    model.emitUserConnectionNotice(for: .authStale(statusCode: 401, message: "stale"))
    #expect(model.userNotice == nil)
}

@MainActor
@Test func djAnnouncementExtractsMessageFromServerJSON() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore())
    model.language = "nl"

    model.apply(watchProxyDJResponse: DJConnectWatchProxyDJResponseRequest(
        text: #"Spotify API failed HTTP 400: {"error":{"status":400,"message":"Can't have offset for context type: ARTIST"}}"#,
        djText: nil,
        audioURL: nil,
        audioType: nil
    ))

    #expect(model.djResponseText == "Can't have offset for context type: ARTIST")
}

@MainActor
@Test func djAnnouncementMapsNoActiveDeviceServerMessage() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore())
    model.language = "nl"

    model.apply(watchProxyDJResponse: DJConnectWatchProxyDJResponseRequest(
        text: "Player command failed. No active device found",
        djText: nil,
        audioURL: nil,
        audioType: nil
    ))

    #expect(model.djResponseText == "Geen actief afspeelapparaat gevonden")
}

@MainActor
@Test func djAnnouncementMapsPlaybackRestrictionServerMessage() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore())
    model.language = "nl"

    model.apply(watchProxyDJResponse: DJConnectWatchProxyDJResponseRequest(
        text: #"Spotify API failed HTTP 403: {"error":{"status":403,"message":"Player command failed: Restriction violated","reason":"UNKNOWN"}}"#,
        djText: nil,
        audioURL: nil,
        audioType: nil
    ))

    #expect(model.djResponseText == "De actieve speler staat deze opdracht nu niet toe")
}

@MainActor
@Test func shuffleCommandRestrictionShowsSpecificUserNotice() async throws {
    let defaults = try testDefaults()
    let host = "shuffle-restricted.local"
    let session = mockSession(host: host) { request in
        #expect(request.url?.path == "/api/djconnect/v1/command")
        return (try httpResponse(for: request, statusCode: 200), Data("""
        {
          "success": false,
          "error": "backend_unavailable",
          "message": "Spotify API failed HTTP 403: {\\\"error\\\":{\\\"status\\\":403,\\\"message\\\":\\\"Player command failed: Restriction violated\\\",\\\"reason\\\":\\\"UNKNOWN\\\"}}"
        }
        """.utf8))
    }
    let model = makePairedMusicDNAModel(defaults: defaults, host: host, session: session)
    model.language = "nl"
    model.isConnected = true

    model.setShuffle(true)
    for _ in 0..<100 where model.userNotice == nil {
        try await Task.sleep(for: .milliseconds(100))
    }

    #expect(model.userNotice?.text == "De actieve speler staat deze opdracht nu niet toe")
}

@MainActor
@Test func djAnnouncementSuppressesHTMLBackendErrorPages() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore())
    model.language = "nl"

    model.apply(watchProxyDJResponse: DJConnectWatchProxyDJResponseRequest(
        text: """
        <!DOCTYPE html>
        <html class="h-full" lang="en-US" dir="ltr">
        <head><link rel="preload" href="https://assets.ngrok.com/fonts/euclid-square/EuclidSquare-Regular-WebS.woff"></head>
        <body>Home Assistant tunnel unavailable</body>
        </html>
        """,
        djText: nil,
        audioURL: nil,
        audioType: nil
    ))

    #expect(model.djResponseText == "Geen verbinding met Home Assistant")
}

@MainActor
@Test func trackInsightSuppressesHTMLBackendErrorPages() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(DJConnectHAConnectionMode.local.rawValue, forKey: "DJConnectHAConnectionMode")
    let host = "track-insight-html.local"
    let session = mockSession(host: host) { request in
        #expect(request.url?.path == "/api/djconnect/v1/track_insight")
        let html = """
        <!DOCTYPE html>
        <html class="h-full" lang="en-US" dir="ltr">
        <head><link rel="preload" href="https://assets.ngrok.com/fonts/euclid-square/EuclidSquare-Regular-WebS.woff"></head>
        <body>Home Assistant tunnel unavailable</body>
        </html>
        """
        return (try httpResponse(for: request, statusCode: 502), Data(html.utf8))
    }
    let model = DJConnectAppModel(
        playback: DJConnectPlayback(trackName: "Midnight City", artistName: "M83"),
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"),
        urlSession: session,
        startBackgroundTasks: false
    )
    model.language = "nl"
    model.homeAssistantURL = "http://\(host):8123"
    model.pairingStatus = .paired
    model.apply(commandResponse: DJConnectCommandResponse(
        success: true,
        backendAvailable: true,
        playback: DJConnectPlayback(trackName: "Midnight City", artistName: "M83")
    ))

    model.analyzeCurrentTrack(open: false)

    for _ in 0..<20 where model.isLoadingTrackInsight {
        try await Task.sleep(for: .milliseconds(50))
    }

    #expect(model.trackInsightErrorMessage == "Geen verbinding met Home Assistant")
    #expect(model.trackInsightErrorMessage?.contains("<!DOCTYPE html>") != true)
    #expect(model.trackInsightErrorMessage?.contains("assets.ngrok.com") != true)
}

@MainActor
@Test func trackInsightLocalizesNoCurrentlyPlayingBackendMessage() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(DJConnectHAConnectionMode.local.rawValue, forKey: "DJConnectHAConnectionMode")
    let host = "track-insight-no-current.local"
    let session = mockSession(host: host) { request in
        #expect(request.url?.path == "/api/djconnect/v1/track_insight")
        let json = """
        {
          "success": false,
          "error": "no_track_playing",
          "message": "No currently playing track could be resolved."
        }
        """
        return (try httpResponse(for: request, statusCode: 200), Data(json.utf8))
    }
    let model = DJConnectAppModel(
        playback: DJConnectPlayback(trackName: "Midnight City", artistName: "M83"),
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"),
        urlSession: session,
        startBackgroundTasks: false
    )
    model.language = "nl"
    model.homeAssistantURL = "http://\(host):8123"
    model.pairingStatus = .paired
    model.apply(commandResponse: DJConnectCommandResponse(
        success: true,
        backendAvailable: true,
        playback: DJConnectPlayback(trackName: "Midnight City", artistName: "M83")
    ))

    model.analyzeCurrentTrack(open: false)

    for _ in 0..<20 where model.isLoadingTrackInsight {
        try await Task.sleep(for: .milliseconds(50))
    }

    #expect(model.trackInsightErrorMessage == "Start eerst een nummer voordat je Track Insight opent.")
    #expect(model.trackInsightErrorMessage?.contains("No currently playing") != true)
}

@MainActor
@Test func activeVibeCastAutoAnalyzesCurrentAndNextTrackInsight() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(DJConnectHAConnectionMode.local.rawValue, forKey: "DJConnectHAConnectionMode")
    final class Recorder: @unchecked Sendable {
        let lock = NSLock()
        var trackInsightTitles: [String] = []
        func append(_ value: String) {
            lock.withLock { trackInsightTitles.append(value) }
        }
        var titles: [String] {
            lock.withLock { trackInsightTitles }
        }
    }
    let recorder = Recorder()
    let host = "vibecast-auto-insight.local"
    let session = mockSession(host: host) { request in
        switch request.url?.path {
        case "/api/djconnect/v1/vibecast":
            return (
                try httpResponse(for: request, statusCode: 200),
                Data(#"{"enabled":true,"revision":1,"poll_after_seconds":30,"items":[]}"#.utf8)
            )
        case "/api/djconnect/v1/track_insight":
            let object = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let fallbackTitle = recorder.titles.isEmpty ? "Track One" : "Track Two"
            let title = (object?["track_name"] as? String) ?? fallbackTitle
            let artist = (object?["artist"] as? String) ?? title.replacingOccurrences(of: "Track", with: "Artist")
            recorder.append(title)
            let json = """
            {
              "success": true,
              "track_insight": {
                "title": "\(title)",
                "artist": "\(artist)",
                "analysis": {
                  "summary": "Auto insight for \(title)",
                  "full_text": "Auto insight for \(title)"
                }
              }
            }
            """
            return (try httpResponse(for: request, statusCode: 200), Data(json.utf8))
        case "/api/djconnect/v1/music_dna/profile":
            return (
                try httpResponse(for: request, statusCode: 200),
                Data(#"{"enabled":false,"profile":null,"items":[]}"#.utf8)
            )
        default:
            Issue.record("Unexpected route \(request.url?.path ?? "nil")")
            return (try httpResponse(for: request, statusCode: 404), Data(#"{"error":"not_found"}"#.utf8))
        }
    }
    let model = DJConnectAppModel(
        playback: DJConnectPlayback(hasPlayback: true, isPlaying: true, trackName: "Track One", artistName: "Artist One"),
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"),
        urlSession: session,
        startBackgroundTasks: false
    )
    model.homeAssistantURL = "http://\(host):8123"
    model.pairingStatus = .paired

    let pollingTask = Task { await model.runVibeCastPolling() }
    defer { pollingTask.cancel() }

    for _ in 0..<60 where recorder.titles.count < 1 || model.currentTrackInsight?.title != "Track One" {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(recorder.titles == ["Track One"])
    #expect(model.currentTrackInsight?.title == "Track One")

    model.apply(playback: DJConnectPlayback(hasPlayback: true, isPlaying: true, trackName: "Track Two", artistName: "Artist Two"))

    for _ in 0..<60 where recorder.titles.count < 2 || model.currentTrackInsight?.title != "Track Two" {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(recorder.titles == ["Track One", "Track Two"])
    #expect(model.currentTrackInsight?.title == "Track Two")

    model.apply(playback: DJConnectPlayback(hasPlayback: true, isPlaying: true, trackName: "Track Two", artistName: "Artist Two"))
    try await Task.sleep(for: .milliseconds(150))
    #expect(recorder.titles == ["Track One", "Track Two"])

    pollingTask.cancel()
    for _ in 0..<20 where model.isVibeCastStreamingActive {
        try await Task.sleep(for: .milliseconds(50))
    }
    model.apply(playback: DJConnectPlayback(hasPlayback: true, isPlaying: true, trackName: "Track Three", artistName: "Artist Three"))
    try await Task.sleep(for: .milliseconds(200))
    #expect(recorder.titles == ["Track One", "Track Two"])
    #expect(model.currentTrackInsight == nil)
}

@MainActor
@Test func vibeCastRefreshUpdatesItemsWhenTextChangesWithoutRevisionChange() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(DJConnectHAConnectionMode.local.rawValue, forKey: "DJConnectHAConnectionMode")

    final class Counter: @unchecked Sendable {
        let lock = NSLock()
        var value = 0
        func next() -> Int {
            lock.withLock {
                value += 1
                return value
            }
        }
    }

    let counter = Counter()
    let host = "vibecast-same-revision.local"
    let session = mockSession(host: host) { request in
        #expect(request.url?.path == "/api/djconnect/v1/vibecast")
        let call = counter.next()
        let textSegments = call == 1
            ? #"[{"type":"text","value":"Deze track leunt op "},{"type":"strong","value":"ritme en ruimte"},{"type":"text","value":"."}]"#
            : #"[{"type":"emoji","value":"♪ ♫ "},{"type":"text","value":"Deze track leunt op "},{"type":"strong","value":"ritme en ruimte"},{"type":"text","value":"."}]"#
        let json = """
        {
          "enabled": true,
          "revision": 7,
          "poll_after_seconds": 30,
          "context": { "track_id": "track-1", "title": "Strobe", "artist": "deadmau5" },
          "items": [
            { "id": "fact-1", "kind": "track_fact", "text": \(textSegments) }
          ]
        }
        """
        return (try httpResponse(for: request, statusCode: 200), Data(json.utf8))
    }

    let model = DJConnectAppModel(
        playback: DJConnectPlayback(hasPlayback: true, isPlaying: true, trackName: "Strobe", artistName: "deadmau5"),
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"),
        urlSession: session,
        startBackgroundTasks: false
    )
    model.homeAssistantURL = "http://\(host):8123"
    model.pairingStatus = .paired

    _ = await model.refreshVibeCastFeed()
    #expect(model.vibeCastItems.first?.plainText == "Deze track leunt op ritme en ruimte.")

    _ = await model.refreshVibeCastFeed()
    #expect(model.vibeCastItems.first?.plainText == "♪ ♫ Deze track leunt op ritme en ruimte.")
    #expect(model.vibeCastItems.first?.text.first?.type == .emoji)
}

@MainActor
@Test func vibeCastRefreshClearsGenreBadgeWhenNextResponseOmitsIt() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(DJConnectHAConnectionMode.local.rawValue, forKey: "DJConnectHAConnectionMode")

    final class Counter: @unchecked Sendable {
        let lock = NSLock()
        var value = 0
        func next() -> Int {
            lock.withLock {
                value += 1
                return value
            }
        }
    }

    let counter = Counter()
    let host = "vibecast-genre-badge.local"
    let session = mockSession(host: host) { request in
        #expect(request.url?.path == "/api/djconnect/v1/vibecast")
        let context = counter.next() == 1
            ? #""context":{"track_id":"track-1","genre_badge":{"label":"melodic techno","genre":"melodic-techno","placement":"top_trailing"}},"#
            : #""context":{"track_id":"track-1"},"#
        let json = """
        {
          "enabled": true,
          "revision": 7,
          "poll_after_seconds": 30,
          \(context)
          "items": [
            { "id": "fact-1", "kind": "track_fact", "text": [{ "type": "text", "value": "Vibe fact." }] }
          ]
        }
        """
        return (try httpResponse(for: request, statusCode: 200), Data(json.utf8))
    }

    let model = DJConnectAppModel(
        playback: DJConnectPlayback(hasPlayback: true, isPlaying: true, trackName: "Strobe", artistName: "deadmau5"),
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"),
        urlSession: session,
        startBackgroundTasks: false
    )
    model.homeAssistantURL = "http://\(host):8123"
    model.pairingStatus = .paired

    _ = await model.refreshVibeCastFeed()
    #expect(model.vibeCastResponse?.context?.genreBadge?.displayLabel == "melodic techno")

    _ = await model.refreshVibeCastFeed()
    #expect(model.vibeCastResponse?.context?.genreBadge == nil)
    #expect(model.vibeCastItems.first?.plainText == "Vibe fact.")
}

@MainActor
@Test func demoVibeCastFeedIncludesGenreBadgeFromDemoTrackInsight() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        playback: DJConnectPlayback(hasPlayback: true, isPlaying: true, trackName: "Midnight City", artistName: "M83"),
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: nil),
        startBackgroundTasks: false
    )
    model.startDemoMode()

    let refreshedInsight = await model.refreshTrackInsight(open: false)
    #expect(refreshedInsight == true)

    _ = await model.refreshVibeCastFeed()

    #expect(model.vibeCastResponse?.context?.genreBadge?.displayLabel == "Synthpop")
    #expect(model.vibeCastResponse?.context?.genreBadge?.canonicalGenre == "synthpop")
    #expect(model.vibeCastResponse?.context?.genreBadge?.resolvedPlacement == "top_trailing")
    #expect(model.vibeCastItems.allSatisfy { $0.text.filter { $0.type == .emoji }.count == 1 })
    #expect(model.vibeCastItems.allSatisfy { $0.text.first?.type == .emoji })
}

@MainActor
@Test func haVersionOutsideAppMinorRangeDisablesRuntimeControls() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        playback: DJConnectPlayback(trackName: "Old Track"),
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    model.apply(commandResponse: DJConnectCommandResponse(
        success: true,
        message: nil,
        backendAvailable: true,
        haVersion: "3.0.99",
        playback: DJConnectPlayback(trackName: "New Track"),
        devices: [DJConnectOutputDevice(id: "speaker", name: "Speaker", active: true)],
        queue: [DJConnectQueueItem(title: "Queued")],
        playlists: [DJConnectPlaylist(name: "Playlist", uri: "spotify:playlist:1")]
    ))

    let updateMessage = try #require(model.updateRequiredMessage)
    #expect(updateMessage.contains("3.2.x"))
    #expect(updateMessage.contains(">=3.2.0"))
    #expect(updateMessage.contains("<3.3.0"))
    #expect(model.canUsePlaybackFeatures == false)
    #expect(model.backendAvailable == false)
    #expect(model.playback == nil)
    #expect(model.availableOutputs.isEmpty)
    #expect(model.queueItems.isEmpty)
    #expect(model.playlistItems.isEmpty)
}

@MainActor
@Test func haVersionWithinAppMinorRangeKeepsRuntimeEnabled() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    model.apply(commandResponse: DJConnectCommandResponse(
        success: true,
        backendAvailable: true,
        haVersion: "3.2.99",
        playback: DJConnectPlayback(trackName: "Compatible Track")
    ))
    model.apply(musicBackendSummary: DJConnectMusicBackendSummary(remoteSupported: true))

    #expect(model.updateRequiredMessage == nil)
    #expect(model.backendAvailable == true)
    #expect(model.playback?.trackName == "Compatible Track")
}

@MainActor
@Test func recoverableSpotifyVoiceMessageClearsWhenBackendRecovers() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"),
        startBackgroundTasks: false
    )
    model.language = "nl"

    model.apply(watchProxyDJResponse: DJConnectWatchProxyDJResponseRequest(
        text: "Spotify authorization has expired or was revoked.",
        djText: nil,
        audioURL: nil,
        audioType: nil
    ))
    #expect(model.djResponseText == "Controleer de muziekdienst-autorisatie in Home Assistant")

    model.apply(commandResponse: DJConnectCommandResponse(
        success: true,
        backendAvailable: true,
        playback: DJConnectPlayback(hasPlayback: false, isPlaying: false)
    ))

    #expect(model.backendAvailable == true)
    #expect(model.djResponseText.isEmpty)
    #expect(model.voiceStatus == .idle)
}

@MainActor
@Test func startingVoiceRecordingClearsExistingDJResponseImmediately() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"),
        startBackgroundTasks: false
    )

    model.djResponseText = "Nog bezig met praten"
    model.startVoiceRecording()

    #expect(model.djResponseText.isEmpty)
}

@MainActor
@Test func demoVoiceRecordingShowsMicrophoneConsentBeforeDemoResponse() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )
    model.startDemoMode()
    guard model.microphonePermissionStatus == .unknown else {
        return
    }

    model.startVoiceRecording()

    #expect(model.isShowingPermissionExplanation == true)
    #expect(model.permissionExplanationKind == .microphone)
    #expect(model.askDJMessages.contains { $0.text == "Voice request" } == false)
    #expect(model.djResponseText.isEmpty)
}

@MainActor
@Test func welcomeScreenIsShownOncePerInstall() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)

    let firstLaunch = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    #expect(firstLaunch.isShowingWelcome == true)

    firstLaunch.dismissWelcome()
    #expect(firstLaunch.isShowingWelcome == false)

    let secondLaunch = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    #expect(secondLaunch.isShowingWelcome == false)
}

@Test func onboardingTourPromotesDiscoverInsteadOfMiniGames() throws {
    let source = try loadRepositoryText("Sources/DJConnectUI/DJConnectRootView.swift")
    let stepsStart = try #require(source.range(of: "static func steps(language: String) -> [WelcomeTourStep]"))
    let stepsEnd = try #require(source[stepsStart.lowerBound...].range(of: "private struct WelcomeTourPreview"))
    let stepsSource = String(source[stepsStart.lowerBound..<stepsEnd.lowerBound])

    #expect(stepsSource.contains("id: .discovery"))
    #expect(stepsSource.contains("id: .games") == false)
    #expect(stepsSource.contains("ui.mini.games") == false)
}

@MainActor
@Test func whatsNewDoesNotAppearOnFirstInstall() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)

    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)

    #expect(model.isShowingWhatsNew == false)
    #expect(defaults.string(forKey: "DJConnectLastSeenAppVersion") == model.version)
}

@MainActor
@Test func whatsNewAppearsAfterInstalledVersionChanges() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(true, forKey: "DJConnectWelcomeSeen")
    defaults.set("3.1.17", forKey: "DJConnectLastSeenAppVersion")

    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)

    #expect(model.isShowingWhatsNew == true)
    #expect(model.whatsNewTitle.contains(model.version))
    model.dismissWhatsNew()
    #expect(model.isShowingWhatsNew == false)
    #expect(defaults.string(forKey: "DJConnectLastSeenAppVersion") == model.version)
}

@Test func whatsNewReleaseTagsArePlatformSpecific() throws {
    #expect(DJConnectAppModel.publicReleaseTag(version: "3.1.20", clientType: .ios) == "ios/v3.1.20")
    #expect(DJConnectAppModel.publicReleaseTag(version: "3.1.20", clientType: .macos) == "macos/v3.1.20")
}

@Test func whatsNewReleaseURLsEncodePlatformTags() throws {
    let iosURL = try #require(DJConnectAppModel.publicReleaseNotesURL(version: "3.1.20", clientType: .ios))
    let macURL = try #require(DJConnectAppModel.publicReleaseNotesURL(version: "3.1.20", clientType: .macos))
    let iosDutchURL = try #require(DJConnectAppModel.publicReleaseNotesURL(version: "3.1.20", clientType: .ios, language: "nl"))
    let macEnglishURL = try #require(DJConnectAppModel.publicReleaseNotesURL(version: "3.1.20", clientType: .macos, language: "en-US"))
    let iosGermanURL = try #require(DJConnectAppModel.publicReleaseNotesURL(version: "3.1.20", clientType: .ios, language: "de-DE"))
    let macFrenchURL = try #require(DJConnectAppModel.publicReleaseNotesURL(version: "3.1.20", clientType: .macos, language: "fr-FR"))
    let iosSpanishURL = try #require(DJConnectAppModel.publicReleaseNotesURL(version: "3.1.20", clientType: .ios, language: "es-ES"))

    #expect(iosURL.absoluteString == "https://djconnect.dev/release-notes/ios/v3.1.20.json")
    #expect(macURL.absoluteString == "https://djconnect.dev/release-notes/macos/v3.1.20.json")
    #expect(iosDutchURL.absoluteString == "https://djconnect.dev/release-notes/ios/nl/v3.1.20.json")
    #expect(macEnglishURL.absoluteString == "https://djconnect.dev/release-notes/macos/en/v3.1.20.json")
    #expect(iosGermanURL.absoluteString == "https://djconnect.dev/release-notes/ios/de/v3.1.20.json")
    #expect(macFrenchURL.absoluteString == "https://djconnect.dev/release-notes/macos/fr/v3.1.20.json")
    #expect(iosSpanishURL.absoluteString == "https://djconnect.dev/release-notes/ios/es/v3.1.20.json")
    #expect(DJConnectAppModel.normalizedReleaseNotesLanguageCode("nl-NL") == "nl")
    #expect(DJConnectAppModel.normalizedReleaseNotesLanguageCode("de") == "de")
    #expect(DJConnectAppModel.normalizedReleaseNotesLanguageCode("fr-CA") == "fr")
    #expect(DJConnectAppModel.normalizedReleaseNotesLanguageCode("es-MX") == "es")
    #expect(DJConnectAppModel.normalizedReleaseNotesLanguageCode("it") == "en")
}

@Test func whatsNewGitHubFallbackReleaseURLsEncodePlatformTags() throws {
    let iosURL = try #require(DJConnectAppModel.githubReleaseNotesURL(version: "3.1.20", clientType: .ios))
    let macURL = try #require(DJConnectAppModel.githubReleaseNotesURL(version: "3.1.20", clientType: .macos))

    #expect(iosURL.absoluteString.hasSuffix("/releases/tags/ios%2Fv3.1.20"))
    #expect(macURL.absoluteString.hasSuffix("/releases/tags/macos%2Fv3.1.20"))
}

@Test func whatsNewFallbackDownloadLinksArePlatformSpecific() throws {
    let iosURL = try #require(DJConnectAppModel.publicDownloadsURL(clientType: .ios))
    let macURL = try #require(DJConnectAppModel.publicDownloadsURL(clientType: .macos))

    #expect(iosURL.absoluteString == "https://djconnect.dev/ios#downloads")
    #expect(macURL.absoluteString == "https://djconnect.dev/macos#downloads")
}

@MainActor
@Test func crashPromptAppearsAfterUncleanPreviousSession() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)

    let firstLaunch = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    #expect(firstLaunch.isShowingCrashReportPrompt == false)
    firstLaunch.markActiveSession()

    let secondLaunch = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    #expect(secondLaunch.isShowingCrashReportPrompt == true)
    #expect(secondLaunch.crashIssueURL()?.host == "github.com")
    #expect(secondLaunch.crashIssueURL()?.path == "/pcvantol/djconnect/issues/new")

    secondLaunch.dismissCrashReportPrompt()
    let thirdLaunch = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    #expect(thirdLaunch.isShowingCrashReportPrompt == false)
}

@MainActor
@Test func wakeWordPromptDoesNotAppearAutomaticallyAfterFreshPairing() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)

    model.pairingStatus = .paired
    model.presentWakeWordActivationPromptAfterPairing()
    #expect(model.isShowingWakeWordActivationPrompt == false)

    model.completePairingScreen()

    #expect(model.isShowingWakeWordActivationPrompt == false)
}

@MainActor
@Test func wakeWordPromptAppearsWhenVoiceActivationIsEnabledFromSettings() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)

    model.pairingStatus = .paired
    model.setWakeWordEnabled(true)

    #expect(model.isShowingWakeWordActivationPrompt == true)
    #expect(model.wakeWordEnabled == false)
}

@MainActor
@Test func wakeWordPromptActivationEnablesWakeWord() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)

    model.pairingStatus = .paired
    model.setWakeWordEnabled(true)
    model.activateWakeWordFromPrompt()

    #expect(model.isShowingWakeWordActivationPrompt == false)
    #expect(model.wakeWordEnabled == true)
}

@MainActor
@Test func pairingScreenBlocksUnpairedRuntimeUntilPairingSucceeds() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)

    #expect(model.shouldShowPairingScreen == false)

    model.dismissWelcome()

    #expect(model.shouldShowPairingScreen == true)

    model.pairingStatus = .paired

    #expect(model.shouldShowPairingScreen == false)

    model.resetPairing()
    model.dismissWelcome()
    #expect(model.shouldShowPairingScreen == true)

    model.startDemoMode()

    #expect(model.isDemoMode == true)
    #expect(model.shouldShowPairingScreen == false)
    #expect(model.canUsePlaybackFeatures == true)
    #expect(model.playback?.trackName == "Midnight City")
    #expect(model.queueItems.isEmpty == false)
    #expect(model.playlistItems.isEmpty == false)

    model.stopDemoMode()

    #expect(model.isDemoMode == false)
    #expect(model.canUsePlaybackFeatures == false)
    #expect(model.shouldShowPairingScreen == true)
}

@MainActor
@Test func demoModeAskDJTextStaysLocalUntilPaired() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )

    model.startDemoMode()
    model.askDJDraft = "Waarom koos je dit nummer?"
    model.sendAskDJText()

    #expect(model.askDJDraft.isEmpty)
    #expect(model.askDJMessages.count == 2)
    #expect(model.askDJMessages[0].role == .user)
    #expect(model.askDJMessages[0].status == .sent)
    #expect(model.askDJMessages[1].role == .dj)
    #expect(model.askDJMessages[1].text.contains("Home Assistant"))
}

@MainActor
@Test func manualAskDJRefreshCallsBackendEvenWhenForegroundFlagIsStale() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(DJConnectHAConnectionMode.local.rawValue, forKey: "DJConnectHAConnectionMode")
    let host = "manual-ask-dj-refresh.local"
    let recorder = RequestPathRecorder()
    let session = mockSession(host: host) { request in
        let path = request.url?.path ?? ""
        recorder.append(path)
        if path == "/api/djconnect/v1/ask_dj/history" {
            return (
                try httpResponse(for: request, statusCode: 200),
                Data(#"{"history_revision":12,"clear_revision":0,"messages":[]}"#.utf8)
            )
        }
        if path == "/api/djconnect/v1/ask_dj/idle_suggestion" {
            return (
                try httpResponse(for: request, statusCode: 200),
                Data(#"{"history_revision":12,"clear_revision":0,"messages":[]}"#.utf8)
            )
        }
        return (
            try httpResponse(for: request, statusCode: 404),
            Data(#"{"success":false,"error":"unexpected_path"}"#.utf8)
        )
    }
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"),
        urlSession: session,
        startBackgroundTasks: false
    )
    model.homeAssistantURL = "http://\(host):8123"
    model.pairingStatus = .paired
    model.markInactiveSession()

    #expect(model.isAppInForegroundForTests == false)

    await model.refreshAskDJHistory()

    #expect(recorder.paths.contains("/api/djconnect/v1/ask_dj/history"))
    #expect(model.isCheckingAskDJHistoryState == false)
}

@MainActor
@Test func askDJFeedbackDraftIncludesContextWithoutLocalIdentifiers() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let clientMessageID = "client-message-\(UUID().uuidString)"
    let userMessage = DJConnectAskDJMessage(
        id: UUID(),
        clientMessageID: clientMessageID,
        exchangeID: "exchange-feedback",
        exchangeOrder: 0,
        role: .user,
        text: "Waarom past dit nummer bij de avond?",
        status: .sent,
        createdAt: Date(timeIntervalSince1970: 100)
    )
    let answerMessage = DJConnectAskDJMessage(
        id: UUID(),
        clientMessageID: clientMessageID,
        exchangeID: "exchange-feedback",
        exchangeOrder: 1,
        role: .dj,
        text: "Omdat de warme synths en rustige drums goed passen.",
        status: .delivered,
        createdAt: Date(timeIntervalSince1970: 101)
    )
    defaults.set(try JSONEncoder().encode([userMessage, answerMessage]), forKey: "DJConnectAskDJMessages")
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"),
        startBackgroundTasks: false
    )

    let body = model.askDJFeedbackIssueBody(for: answerMessage, userNote: "Het antwoord miste de context van mijn vraag.")

    #expect(body.contains("Het antwoord miste de context van mijn vraag."))
    #expect(body.contains("Waarom past dit nummer bij de avond?"))
    #expect(body.contains("Omdat de warme synths en rustige drums goed passen."))
    #expect(body.contains(#""client_type""#))
    #expect(!body.contains(model.identity.deviceID))
    #expect(!body.contains("secret-token"))
    #expect(!body.contains(#""device_id""#))
}

@MainActor
@Test func demoModeNextCommandAdvancesThroughQueue() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )

    model.startDemoMode()

    #expect(model.playback?.trackName == "Midnight City")

    model.sendPlaybackCommand("next")
    await Task.yield()
    #expect(model.playback?.trackName == "Sweet Disposition")
    #expect(model.playback?.progressMS == 0)

    model.sendPlaybackCommand("next")
    await Task.yield()
    #expect(model.playback?.trackName == "Electric Feel")
    #expect(model.playback?.progressMS == 0)

    model.sendPlaybackCommand("next")
    await Task.yield()
    #expect(model.playback?.trackName == "Electric Feel")

    model.sendPlaybackCommand("previous")
    await Task.yield()
    #expect(model.playback?.trackName == "Sweet Disposition")
    #expect(model.playback?.progressMS == 0)
}

@MainActor
@Test func demoModeVibeCastAutoAnalyzesNextTrack() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )

    model.startDemoMode()
    let pollingTask = Task { await model.runVibeCastPolling() }
    defer { pollingTask.cancel() }

    for _ in 0..<30 where model.currentTrackInsight?.title != "Midnight City" {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(model.currentTrackInsight?.title == "Midnight City")

    model.sendPlaybackCommand("next")

    for _ in 0..<30 where model.currentTrackInsight?.title != "Sweet Disposition" {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(model.playback?.trackName == "Sweet Disposition")
    #expect(model.currentTrackInsight?.title == "Sweet Disposition")
    #expect(model.vibeCastResponse?.context?.genreBadge?.displayLabel == model.currentTrackInsight?.genre)
}

@MainActor
@Test func demoModeSeekSetsExactPlaybackPosition() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )

    model.startDemoMode()

    model.commitSeek(to: 96_000)
    #expect(model.playback?.progressMS == 96_000)

    model.commitSeek(to: 999_000)
    #expect(model.playback?.progressMS == model.playback?.durationMS)
}

@MainActor
@Test func demoModeSeekRelativeMovesPlaybackPosition() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )

    model.startDemoMode()

    model.seekRelative(milliseconds: 15_000)
    #expect(model.playback?.progressMS == 63_000)

    model.seekRelative(milliseconds: -15_000)
    #expect(model.playback?.progressMS == 48_000)

    model.seekRelative(milliseconds: -999_000)
    #expect(model.playback?.progressMS == 0)
}

@MainActor
@Test func askDJGeneratedTextMetadataMapsToLocalAssistantMessage() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )
    let assistantMessage = DJConnectAskDJHistoryMessage(
        id: "assistant-generated",
        role: .assistant,
        textSource: "generated",
        isGeneratedText: true,
        text: "Pearl Jam komt binnen alsof de festivalweide net wakker wordt.",
        createdAt: Date(timeIntervalSince1970: 20)
    )

    model.applyAskDJMessageResponse(DJConnectAskDJMessageResponse(
        assistantMessage: assistantMessage,
        historyRevision: 1
    ), fallbackUserMessageID: nil)

    let message = try #require(model.askDJMessages.first)
    #expect(message.role == .dj)
    #expect(message.textSource == "generated")
    #expect(message.isGeneratedText == true)
}

@MainActor
@Test func askDJMoodMetadataMapsToLocalAssistantMessage() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )
    let assistantMessage = DJConnectAskDJHistoryMessage(
        id: "assistant-energy",
        role: .assistant,
        mood: 72,
        text: "Dit antwoord krijgt de energy-kleurstelling.",
        createdAt: Date(timeIntervalSince1970: 20)
    )

    model.applyAskDJMessageResponse(DJConnectAskDJMessageResponse(
        assistantMessage: assistantMessage,
        historyRevision: 1
    ), fallbackUserMessageID: nil)

    let message = try #require(model.askDJMessages.first)
    #expect(message.role == .dj)
    #expect(message.mood == 72)
}

@MainActor
@Test func askDJTopLevelGeneratedTextMetadataIsUsedOnlyForSyntheticAssistantMessage() throws {
    let payload = Data("""
    {
      "dj_text": "Pearl Jam komt binnen alsof de festivalweide net wakker wordt.",
      "text_source": "generated",
      "is_generated_text": true
    }
    """.utf8)
    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: payload)
    let assistantMessage = try #require(response.assistantMessage)

    #expect(response.textSource == "generated")
    #expect(response.isGeneratedText == true)
    #expect(assistantMessage.textSource == "generated")
    #expect(assistantMessage.isGeneratedText == true)
}

@MainActor
@Test func askDJTopLevelGeneratedTextMetadataFillsMissingAssistantMessageMetadata() throws {
    let payload = Data("""
    {
      "dj_text": "Top-level generated text.",
      "text_source": "generated",
      "is_generated_text": true,
      "assistant_message": {
        "id": "assistant-without-metadata",
        "role": "assistant",
        "text": "Assistant text zonder metadata.",
        "created_at": "2026-07-03T20:00:00Z"
      }
    }
    """.utf8)
    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: payload)
    let assistantMessage = try #require(response.assistantMessage)

    #expect(response.isGeneratedText == true)
    #expect(assistantMessage.textSource == "generated")
    #expect(assistantMessage.isGeneratedText == true)
}

@MainActor
@Test func askDJGeneratedWatSpeeltErResponseKeepsAssistantAudioAndGeneratedMetadata() throws {
    let payload = Data("""
    {
      "dj_text": "Je luistert nu naar Alive van Pearl Jam.",
      "text_source": "generated",
      "is_generated_text": true,
      "audio_url": "/api/djconnect/audio/wat-speelt-er.mp3",
      "audio_type": "tts",
      "assistant_message": {
        "id": "assistant-wat-speelt-er",
        "role": "assistant",
        "text": "Je luistert nu naar Alive van Pearl Jam.",
        "text_source": "generated",
        "is_generated_text": true,
        "audio_url": "/api/djconnect/audio/wat-speelt-er.mp3",
        "audio_type": "tts",
        "created_at": "2026-07-04T10:00:00Z"
      }
    }
    """.utf8)
    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: payload)
    let assistantMessage = try #require(response.assistantMessage)

    #expect(response.textSource == "generated")
    #expect(response.isGeneratedText == true)
    #expect(response.audioURL?.path == "/api/djconnect/audio/wat-speelt-er.mp3")
    #expect(assistantMessage.textSource == "generated")
    #expect(assistantMessage.isGeneratedText == true)
    #expect(assistantMessage.audioURL?.path == "/api/djconnect/audio/wat-speelt-er.mp3")
}

@MainActor
@Test func askDJNonGeneratedAssistantMessageKeepsAudioReplayMetadata() throws {
    let payload = Data("""
    {
      "assistant_message": {
        "id": "assistant-audio-fallback",
        "role": "assistant",
        "text": "Ask DJ gaf een vaste fallback met audio.",
        "text_source": "fallback",
        "is_generated_text": false,
        "audio_url": "https://example.test/audio/fallback.mp3",
        "created_at": "2026-07-04T10:05:00Z"
      }
    }
    """.utf8)
    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: payload)
    let assistantMessage = try #require(response.assistantMessage)

    #expect(assistantMessage.textSource == "fallback")
    #expect(assistantMessage.isGeneratedText == false)
    #expect(assistantMessage.audioURL?.absoluteString == "https://example.test/audio/fallback.mp3")
}

@MainActor
@Test func askDJLegacyTopLevelFallbackFieldsHydrateSyntheticAssistantMessage() throws {
    let payload = Data("""
    {
      "dj_text": "Legacy top-level antwoord met TTS.",
      "text_source": "generated",
      "is_generated_text": true,
      "audio_url": "https://example.test/audio/legacy.mp3"
    }
    """.utf8)
    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: payload)
    let assistantMessage = try #require(response.assistantMessage)

    #expect(assistantMessage.text == "Legacy top-level antwoord met TTS.")
    #expect(assistantMessage.textSource == "generated")
    #expect(assistantMessage.isGeneratedText == true)
    #expect(assistantMessage.audioURL?.absoluteString == "https://example.test/audio/legacy.mp3")
}

@MainActor
@Test func askDJFallbackTextMetadataMapsWithoutGeneratedFlag() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )
    let assistantMessage = DJConnectAskDJHistoryMessage(
        id: "assistant-fallback",
        role: .assistant,
        textSource: "fallback",
        isGeneratedText: false,
        text: "Ask DJ is even niet bereikbaar.",
        createdAt: Date(timeIntervalSince1970: 20)
    )

    model.applyAskDJMessageResponse(DJConnectAskDJMessageResponse(
        assistantMessage: assistantMessage,
        historyRevision: 1
    ), fallbackUserMessageID: nil)

    let message = try #require(model.askDJMessages.first)
    #expect(message.role == .dj)
    #expect(message.textSource == "fallback")
    #expect(message.isGeneratedText == false)
}

@MainActor
@Test func askDJResponseWithoutUserMessageKeepsLocalUserBubble() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let clientMessageID = "client-message-\(UUID().uuidString)"
    let userMessageID = UUID()
    let localUserMessage = DJConnectAskDJMessage(
        id: userMessageID,
        serverID: nil,
        clientMessageID: clientMessageID,
        role: .user,
        text: "speel metallica, one.",
        status: .sending,
        createdAt: Date(timeIntervalSince1970: 10)
    )
    let encodedMessages = try JSONEncoder().encode([localUserMessage])
    defaults.set(encodedMessages, forKey: "DJConnectAskDJMessages")
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )
    let serverUserMessage = DJConnectAskDJHistoryMessage(
        id: "user-1",
        clientMessageID: clientMessageID,
        role: .user,
        text: "",
        createdAt: Date(timeIntervalSince1970: 11)
    )
    let assistantMessage = DJConnectAskDJHistoryMessage(
        id: "assistant-1",
        clientMessageID: clientMessageID,
        role: .assistant,
        text: "Ik zet Metallica - One voor je klaar.",
        createdAt: Date(timeIntervalSince1970: 20)
    )
    let trimmedBeforeLocalMessage = Date(timeIntervalSince1970: 15)

    model.applyAskDJMessageResponse(DJConnectAskDJMessageResponse(
        userMessage: serverUserMessage,
        assistantMessage: assistantMessage,
        historyRevision: 1,
        historyTrimmedBefore: trimmedBeforeLocalMessage,
        deduplicated: true
    ), fallbackUserMessageID: userMessageID)
    model.applyAskDJHistory(DJConnectAskDJHistoryResponse(
        historyRevision: 2,
        messages: [serverUserMessage, assistantMessage, serverUserMessage, assistantMessage],
        historyTrimmedBefore: trimmedBeforeLocalMessage
    ))

    #expect(model.askDJMessages.count == 2)
    #expect(model.askDJMessages[0].id == userMessageID)
    #expect(model.askDJMessages[0].serverID == "user-1")
    #expect(model.askDJMessages[0].clientMessageID == clientMessageID)
    #expect(model.askDJMessages[0].role == .user)
    #expect(model.askDJMessages[0].text == "speel metallica, one.")
    #expect(model.askDJMessages[0].status == .delivered)
    #expect(model.askDJMessages[1].clientMessageID == clientMessageID)
    #expect(model.askDJMessages[1].role == .dj)
    #expect(model.askDJMessages[1].text == "Ik zet Metallica - One voor je klaar.")
}

@MainActor
@Test func askDJHistorySyncHigherClearRevisionClearsLocalCacheBeforeMerge() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let clientMessageID = "client-message-\(UUID().uuidString)"
    let localUserID = UUID()
    let localUserMessage = DJConnectAskDJMessage(
        id: localUserID,
        clientMessageID: clientMessageID,
        role: .user,
        text: "wat speelt er nu?",
        status: .sending,
        createdAt: Date(timeIntervalSince1970: 100)
    )
    let assistantMessage = DJConnectAskDJHistoryMessage(
        id: "assistant-now-playing",
        clientMessageID: clientMessageID,
        role: .assistant,
        text: "Dit klinkt als een warme, melodische house track.",
        createdAt: Date(timeIntervalSince1970: 101)
    )

    defaults.set(try JSONEncoder().encode([localUserMessage]), forKey: "DJConnectAskDJMessages")
    let hydratedModel = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )
    hydratedModel.applyAskDJMessageResponse(DJConnectAskDJMessageResponse(
        assistantMessage: assistantMessage,
        historyRevision: 4,
        clearRevision: 0
    ), fallbackUserMessageID: localUserID)

    hydratedModel.applyAskDJHistory(DJConnectAskDJHistoryResponse(
        historyRevision: 5,
        clearRevision: 1,
        messages: []
    ))

    #expect(hydratedModel.askDJMessages.isEmpty)
    #expect(defaults.integer(forKey: "DJConnectAskDJClearRevision") == 1)
    #expect(defaults.integer(forKey: "DJConnectAskDJHistoryRevision") == 5)
}

@MainActor
@Test func askDJHistorySyncEmptyMessagesAfterClearDoesNotRestoreOldLocalMessages() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let staleMessage = DJConnectAskDJMessage(
        role: .dj,
        text: "oude chat",
        status: .sent,
        createdAt: Date(timeIntervalSince1970: 100)
    )
    defaults.set(try JSONEncoder().encode([staleMessage]), forKey: "DJConnectAskDJMessages")
    defaults.set(3, forKey: "DJConnectAskDJClearRevision")
    let hydratedModel = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )

    hydratedModel.applyAskDJHistory(DJConnectAskDJHistoryResponse(
        historyRevision: 12,
        clearRevision: 4,
        messages: []
    ))

    #expect(hydratedModel.askDJMessages.isEmpty)
    #expect(defaults.integer(forKey: "DJConnectAskDJClearRevision") == 4)
    #expect(defaults.integer(forKey: "DJConnectAskDJHistoryRevision") == 12)
}

@MainActor
@Test func askDJMessageExchangeOrderKeepsUserQuestionAboveAssistantAnswer() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let clientMessageID = "client-message-\(UUID().uuidString)"
    let localUserID = UUID()
    let localUserMessage = DJConnectAskDJMessage(
        id: localUserID,
        clientMessageID: clientMessageID,
        role: .user,
        text: "heb je playlists van snowpatrol",
        status: .sending,
        createdAt: Date(timeIntervalSince1970: 100)
    )
    let encodedMessages = try JSONEncoder().encode([localUserMessage])
    defaults.set(encodedMessages, forKey: "DJConnectAskDJMessages")
    let hydratedModel = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: false
    )
    let serverUserMessage = DJConnectAskDJHistoryMessage(
        id: "server-user-snowpatrol",
        clientMessageID: clientMessageID,
        exchangeID: "exchange-snowpatrol",
        exchangeOrder: 0,
        role: .user,
        text: "heb je playlists van snowpatrol",
        createdAt: Date(timeIntervalSince1970: 200)
    )
    let serverAssistantMessage = DJConnectAskDJHistoryMessage(
        id: "server-assistant-snowpatrol",
        clientMessageID: clientMessageID,
        exchangeID: "exchange-snowpatrol",
        exchangeOrder: 1,
        role: .assistant,
        text: "Zeker, ik kan een paar Snow Patrol playlists voorstellen.",
        createdAt: Date(timeIntervalSince1970: 150)
    )

    hydratedModel.applyAskDJMessageResponse(DJConnectAskDJMessageResponse(
        messages: [serverUserMessage, serverAssistantMessage],
        historyRevision: 10
    ), fallbackUserMessageID: localUserID)
    hydratedModel.applyAskDJHistory(DJConnectAskDJHistoryResponse(
        historyRevision: 11,
        messages: [serverAssistantMessage, serverUserMessage]
    ))

    #expect(hydratedModel.askDJMessages.count == 2)
    #expect(hydratedModel.askDJMessages[0].id == localUserID)
    #expect(hydratedModel.askDJMessages[0].role == .user)
    #expect(hydratedModel.askDJMessages[0].serverID == "server-user-snowpatrol")
    #expect(hydratedModel.askDJMessages[0].exchangeOrder == 0)
    #expect(hydratedModel.askDJMessages[1].role == .dj)
    #expect(hydratedModel.askDJMessages[1].serverID == "server-assistant-snowpatrol")
    #expect(hydratedModel.askDJMessages[1].exchangeOrder == 1)
}

@MainActor
@Test func monkeyTestingModeStartsSafeLocalDemoWithoutPairing() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startBackgroundTasks: true,
        monkeyTestingMode: true
    )

    #expect(model.isMonkeyTestingMode == true)
    #expect(model.isDemoMode == true)
    #expect(model.shouldShowPairingScreen == false)
    #expect(model.isShowingWelcome == false)
    #expect(model.isShowingCrashReportPrompt == false)
    #expect(model.canUsePlaybackFeatures == true)
    #expect(model.playback?.trackName == "Midnight City")
    #expect(model.queueItems.isEmpty == false)
    #expect(model.playlistItems.isEmpty == false)
    #expect(model.currentTrackInsight == nil)
    model.openTrackInsight()
    #expect(model.currentTrackInsight == nil)
}

@MainActor
@Test func permissionRequestActionPromptsWhenPermissionsAreUnknown() {
    #expect(DJConnectAppModel.permissionRequestAction(
        microphone: .unknown,
        speech: .unknown
    ) == .requestSystemPrompt)
}

@MainActor
@Test func permissionRequestActionSkipsWhenPermissionsAreAlreadyGranted() {
    #expect(DJConnectAppModel.permissionRequestAction(
        microphone: .granted,
        speech: .granted
    ) == .alreadyGranted)
}

@MainActor
@Test func permissionRequestActionOpensSettingsWhenMicrophoneWasDenied() {
    #expect(DJConnectAppModel.permissionRequestAction(
        microphone: .denied,
        speech: .granted
    ) == .openSystemSettings)
}

@MainActor
@Test func permissionRequestActionOpensSettingsWhenSpeechPermissionWasRevoked() {
    #expect(DJConnectAppModel.permissionRequestAction(
        microphone: .granted,
        speech: .denied
    ) == .openSystemSettings)
}

@MainActor
@Test func permissionRequestActionOpensSettingsWhenPermissionIsRestricted() {
    #expect(DJConnectAppModel.permissionRequestAction(
        microphone: .restricted,
        speech: .unknown
    ) == .openSystemSettings)
}

@Test func watchProxyRequestEncodesBackendAgnosticMusicAssistantAction() throws {
    let actionValue: DJConnectCommandValue = .object([
        "item_id": "track-123",
        "provider": "music_assistant",
        "media_type": "track",
        "target_player_id": "media_player.mass_woonkamer"
    ])
    let payload = DJConnectCommandPayload(
        identity: DJConnectIdentity(
            deviceID: "djconnect-watchos-ABC123",
            deviceName: "DJConnect Watch",
            clientType: .watchos,
            firmware: "3.2.0",
            appVersion: "3.2.0",
            platform: .watchos
        ),
        command: "ask_dj_play_recommendation",
        value: actionValue,
        play: true,
        musicBackendRevision: 4
    )
    let payloadData = try JSONEncoder().encode(payload)
    let request = DJConnectWatchProxyRequest(operation: .command, payload: payloadData)
    let decodedRequest = try JSONDecoder().decode(DJConnectWatchProxyRequest.self, from: JSONEncoder().encode(request))
    let decodedPayload = try #require(decodedRequest.payload)
    let decodedCommand = try JSONDecoder().decode(DJConnectCommandPayload.self, from: decodedPayload)

    #expect(decodedRequest.operation == .command)
    #expect(decodedCommand.clientType == .watchos)
    #expect(decodedCommand.command == "ask_dj_play_recommendation")
    #expect(decodedCommand.musicBackendRevision == 4)
    if case let .object(value) = decodedCommand.value {
        #expect(value["item_id"] == "track-123")
        #expect(value["provider"] == "music_assistant")
        #expect(value["target_player_id"] == "media_player.mass_woonkamer")
    } else {
        Issue.record("Expected Music Assistant object action value")
    }
}

@Test func watchProxyVoicePayloadCarriesAudioWithoutPersistentURL() throws {
    let payload = DJConnectWatchProxyVoicePayload(
        wavData: Data([0x52, 0x49, 0x46, 0x46]),
        mood: 70,
        djStyle: "warm_radio_dj",
        musicDNAKey: "djconnect-watchos-ABC123",
        language: "nl-NL"
    )
    let request = DJConnectWatchProxyRequest(operation: .voice, payload: try JSONEncoder().encode(payload))
    let decodedRequest = try JSONDecoder().decode(DJConnectWatchProxyRequest.self, from: JSONEncoder().encode(request))
    let decodedPayload = try JSONDecoder().decode(DJConnectWatchProxyVoicePayload.self, from: try #require(decodedRequest.payload))

    #expect(decodedRequest.operation == .voice)
    #expect(decodedPayload.wavData == Data([0x52, 0x49, 0x46, 0x46]))
    #expect(decodedPayload.mood == 70)
    #expect(decodedPayload.djStyle == "warm_radio_dj")
    #expect(decodedPayload.language == "nl-NL")
}

@Test func watchProxyAskDJMessagePayloadCarriesTextContext() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-watchos-ABC123",
        deviceName: "DJConnect Watch",
        clientType: .watchos,
        firmware: "3.2.3",
        appVersion: "3.2.3",
        platform: .watchos
    )
    let payload = DJConnectAskDJRequest(
        identity: identity,
        text: "Meer van Charly Lownoise & Mental Theo",
        clientMessageID: "watch-message-1",
        inputType: "text",
        mood: 70,
        musicDNAKey: "djconnect_watchos_ABC123",
        audioResponse: .auto,
        language: "nl-NL"
    )
    let request = DJConnectWatchProxyRequest(operation: .askDJMessage, payload: try JSONEncoder().encode(payload))
    let decodedRequest = try JSONDecoder().decode(DJConnectWatchProxyRequest.self, from: JSONEncoder().encode(request))
    let decodedPayload = try JSONDecoder().decode(DJConnectAskDJRequest.self, from: try #require(decodedRequest.payload))

    #expect(decodedRequest.operation == .askDJMessage)
    #expect(decodedPayload.text == "Meer van Charly Lownoise & Mental Theo")
    #expect(decodedPayload.clientMessageID == "watch-message-1")
    #expect(decodedPayload.mood == 70)
    #expect(decodedPayload.musicDNAKey == "djconnect_watchos_ABC123")
    #expect(decodedPayload.audioResponse == .auto)
    #expect(decodedPayload.language == "nl-NL")
}

@Test func watchProxyMusicDNASettingsPayloadUsesWatchIdentity() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-watchos-ABC123",
        deviceName: "DJConnect Watch",
        clientType: .watchos,
        firmware: "3.2.3",
        appVersion: "3.2.3",
        platform: .watchos
    )
    let payload = DJConnectMusicDNASettingsRequest(identity: identity, enabled: true, mood: 70)
    let request = DJConnectWatchProxyRequest(operation: .musicDNASettings, payload: try JSONEncoder().encode(payload))
    let decodedRequest = try JSONDecoder().decode(DJConnectWatchProxyRequest.self, from: JSONEncoder().encode(request))
    let decodedPayload = try JSONDecoder().decode(DJConnectMusicDNASettingsRequest.self, from: try #require(decodedRequest.payload))

    #expect(decodedRequest.operation == .musicDNASettings)
    #expect(decodedPayload.deviceID == "djconnect-watchos-ABC123")
    #expect(decodedPayload.clientType == .watchos)
    #expect(decodedPayload.enabled == true)
    #expect(decodedPayload.mood == 70)
}

@Test func watchProxyMusicDNASettingsPayloadSupportsWatchOptOut() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-watchos-ABC123",
        deviceName: "DJConnect Watch",
        clientType: .watchos,
        firmware: "3.2.3",
        appVersion: "3.2.3",
        platform: .watchos
    )
    let payload = DJConnectMusicDNASettingsRequest(identity: identity, enabled: false)
    let request = DJConnectWatchProxyRequest(operation: .musicDNASettings, payload: try JSONEncoder().encode(payload))
    let decodedRequest = try JSONDecoder().decode(DJConnectWatchProxyRequest.self, from: JSONEncoder().encode(request))
    let decodedPayload = try JSONDecoder().decode(DJConnectMusicDNASettingsRequest.self, from: try #require(decodedRequest.payload))

    #expect(decodedRequest.operation == .musicDNASettings)
    #expect(decodedPayload.deviceID == "djconnect-watchos-ABC123")
    #expect(decodedPayload.clientType == .watchos)
    #expect(decodedPayload.enabled == false)
}

@Test func watchProxyMusicDNAProfileOperationRoundTrips() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-watchos-ABC123",
        deviceName: "DJConnect Watch",
        clientType: .watchos,
        firmware: "3.2.3",
        appVersion: "3.2.3",
        platform: .watchos
    )
    let payload = DJConnectMusicDNAIdentityRequest(identity: identity, mood: 40)
    let request = DJConnectWatchProxyRequest(operation: .musicDNAProfile, payload: try JSONEncoder().encode(payload))
    let decodedRequest = try JSONDecoder().decode(DJConnectWatchProxyRequest.self, from: JSONEncoder().encode(request))
    let decodedPayload = try JSONDecoder().decode(DJConnectMusicDNAIdentityRequest.self, from: try #require(decodedRequest.payload))

    #expect(decodedRequest.operation == .musicDNAProfile)
    #expect(decodedPayload.deviceID == "djconnect-watchos-ABC123")
    #expect(decodedPayload.clientType == .watchos)
    #expect(decodedPayload.mood == 40)
}

@Test func watchProxyMusicDNAClearOperationRoundTrips() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-watchos-ABC123",
        deviceName: "DJConnect Watch",
        clientType: .watchos,
        firmware: "3.2.3",
        appVersion: "3.2.3",
        platform: .watchos
    )
    let payload = DJConnectMusicDNAIdentityRequest(identity: identity, mood: 100)
    let request = DJConnectWatchProxyRequest(operation: .clearMusicDNA, payload: try JSONEncoder().encode(payload))
    let decodedRequest = try JSONDecoder().decode(DJConnectWatchProxyRequest.self, from: JSONEncoder().encode(request))
    let decodedPayload = try JSONDecoder().decode(DJConnectMusicDNAIdentityRequest.self, from: try #require(decodedRequest.payload))

    #expect(decodedRequest.operation == .clearMusicDNA)
    #expect(decodedPayload.deviceID == "djconnect-watchos-ABC123")
    #expect(decodedPayload.clientType == .watchos)
    #expect(decodedPayload.mood == 100)
}

@Test func watchProxyMusicDiscoveryOperationsRoundTripWithWatchIdentity() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-watchos-ABC123",
        deviceName: "DJConnect Watch",
        clientType: .watchos,
        firmware: "3.2.24",
        appVersion: "3.2.24",
        platform: .watchos
    )
    let feedPayload = DJConnectMusicDNAIdentityRequest(
        identity: identity,
        mood: 70,
        musicDNAKey: "djconnect-watchos-ABC123",
        language: "nl",
        locale: "nl-NL"
    )
    let feedRequest = DJConnectWatchProxyRequest(operation: .musicDiscovery, payload: try JSONEncoder().encode(feedPayload))
    let refreshRequest = DJConnectWatchProxyRequest(operation: .musicDiscoveryRefresh, payload: try JSONEncoder().encode(feedPayload))
    let playPayload = DJConnectMusicDiscoveryPlayRequest(
        discoveryItemID: "watch-reco-1",
        sectionID: "because_you_like",
        identity: identity,
        musicDNAKey: "djconnect-watchos-ABC123"
    )
    let playRequest = DJConnectWatchProxyRequest(operation: .musicDiscoveryPlay, payload: try JSONEncoder().encode(playPayload))

    let decodedFeed = try JSONDecoder().decode(DJConnectWatchProxyRequest.self, from: JSONEncoder().encode(feedRequest))
    let decodedRefresh = try JSONDecoder().decode(DJConnectWatchProxyRequest.self, from: JSONEncoder().encode(refreshRequest))
    let decodedPlay = try JSONDecoder().decode(DJConnectWatchProxyRequest.self, from: JSONEncoder().encode(playRequest))
    let decodedFeedPayload = try JSONDecoder().decode(DJConnectMusicDNAIdentityRequest.self, from: try #require(decodedFeed.payload))
    let decodedPlayPayload = try JSONDecoder().decode(DJConnectMusicDiscoveryPlayRequest.self, from: try #require(decodedPlay.payload))

    #expect(decodedFeed.operation == .musicDiscovery)
    #expect(decodedRefresh.operation == .musicDiscoveryRefresh)
    #expect(decodedPlay.operation == .musicDiscoveryPlay)
    #expect(decodedFeedPayload.deviceID == "djconnect-watchos-ABC123")
    #expect(decodedFeedPayload.clientType == .watchos)
    #expect(decodedFeedPayload.mood == 70)
    #expect(decodedFeedPayload.musicDNAKey == "djconnect-watchos-ABC123")
    #expect(decodedFeedPayload.language == "nl")
    #expect(decodedFeedPayload.locale == "nl-NL")
    #expect(decodedPlayPayload.discoveryItemID == "watch-reco-1")
    #expect(decodedPlayPayload.sectionID == "because_you_like")
    #expect(decodedPlayPayload.clientType == .watchos)
    #expect(decodedPlayPayload.musicDNAKey == "djconnect-watchos-ABC123")
}

@Test func commandResponseExposesBackendSummaryForWatchSync() throws {
    let json = """
    {
      "success": true,
      "music_backend": "music_assistant",
      "music_backend_name": "Music Assistant",
      "music_backend_available": true,
      "music_backend_revision": 4,
      "music_backend_capabilities": {
        "supports_search": true,
        "supports_queue": true,
        "supports_outputs": true
      },
      "music_target_player": {
        "id": "media_player.mass_woonkamer",
        "name": "Woonkamer"
      },
      "remote_supported": true
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectCommandResponse.self, from: json)
    let summary = response.musicBackendSummary

    #expect(summary.musicBackend == "music_assistant")
    #expect(summary.displayName == "Music Assistant")
    #expect(summary.musicBackendRevision == 4)
    #expect(summary.musicBackendCapabilities?.supportsOutputs == true)
    #expect(summary.musicTargetPlayer?.name == "Woonkamer")
    #expect(response.remoteSupported == true)
}

@Test func commandResponseDecodesObjectMusicBackendError() throws {
    let json = """
    {
      "success": false,
      "error": "unsupported_backend_capability",
      "music_backend": "music_assistant",
      "music_backend_error": {
        "code": "supports_recently_played",
        "message": "The selected music backend does not provide recent listening history."
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectCommandResponse.self, from: json)

    #expect(response.error == "unsupported_backend_capability")
    #expect(response.musicBackend == "music_assistant")
    #expect(response.musicBackendError == "The selected music backend does not provide recent listening history.")
    #expect(response.musicBackendSummary.musicBackendError == response.musicBackendError)
}

@Test func commandResponseDecodesNestedMusicBackendErrorObjectFallbackCode() throws {
    let json = """
    {
      "success": false,
      "data": {
        "music_backend_error": {
          "code": "music_assistant_unavailable"
        }
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectCommandResponse.self, from: json)

    #expect(response.musicBackendError == "music_assistant_unavailable")
}

@Test func sharedClientTypeDecodesWindowsForCrossRepoContract() throws {
    let json = """
    {
      "success": true,
      "device_token": "device-token",
      "client_type": "windows",
      "device_id": "djconnect-windows-ABCDEF123456"
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectPairingResponse.self, from: json)

    #expect(response.clientType == .windows)
    #expect(response.deviceID == "djconnect-windows-ABCDEF123456")
}

@Test func trackInsightParserDecodesStructuredJSON() throws {
    let json = """
    {
      "title": "Innerbloom",
      "artist": "RUFUS DU SOL",
      "album": "Bloom",
      "genre": "Melodic house",
      "energy": 0.64,
      "danceability": 0.62,
      "intensity": 0.70,
      "mood": "Dreamy",
      "vibe": "Expansive",
      "texture": "Wide pads",
      "confidence": 0.95,
      "summary": "A slow-blooming electronic piece."
    }
    """.data(using: .utf8)!

    let insight = try #require(TrackInsightParser.parse(data: json))

    #expect(insight.title == "Innerbloom")
    #expect(insight.artist == "RUFUS DU SOL")
    #expect(insight.energy == 0.64)
    #expect(insight.summary == "A slow-blooming electronic piece.")
}

@Test func trackInsightUsesTrackGenresWhenAnalysisGenreIsMissing() throws {
    let json = """
    {
      "success": true,
      "track_insight": {
        "track": {
          "title": "Genre Fallback",
          "artist": "Backend",
          "genres": ["dream pop", "ambient", "electronic", "extra"]
        },
        "analysis": {
          "summary": "Genre comes from track context."
        }
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(TrackInsightEndpointResponse.self, from: json)
    let insight = try #require(response.trackInsightValue)

    #expect(insight.genre == "dream pop, ambient, electronic")
}

@Test func trackInsightWidgetSnapshotKeepsOnlySafeVisibleFields() throws {
    let insight = TrackInsight(
        title: "  Innerbloom\n",
        artist: "RUFUS DU SOL",
        duration: 200,
        progress: 138,
        genre: "Deep House",
        energy: 1.4,
        danceability: -0.2,
        intensity: 0.58,
        mood: "Dreamy",
        vibe: "Euphoric",
        summary: String(repeating: "glow ", count: 80),
        rawAnalysisText: "raw backend details should not be copied",
        musicDNAMatchPercent: 140
    )

    let snapshot = DJConnectTrackInsightWidgetSnapshot(insight: insight)

    #expect(snapshot.title == "Innerbloom")
    #expect(snapshot.artist == "RUFUS DU SOL")
    #expect(snapshot.energy == 1)
    #expect(snapshot.danceability == 0)
    #expect(snapshot.intensity == 0.58)
    #expect(snapshot.musicDNAMatchPercent == nil)
    #expect(snapshot.progress == 138)
    #expect(snapshot.duration == 200)
    #expect(snapshot.summary.count <= 180)
    #expect(!snapshot.summary.contains("\n"))
}

@Test func trackInsightWidgetSnapshotStoresAndLoadsFromSharedDefaults() throws {
    let suiteName = "DJConnectWidgetSnapshotTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let snapshot = DJConnectTrackInsightWidgetSnapshot(
        title: "Adagio for Strings",
        artist: "Samuel Barber",
        genre: "Classical",
        mood: "Dreamy",
        vibe: "Lamenting",
        energy: 0.32,
        danceability: 0.10,
        intensity: 0.68,
        musicDNAMatchPercent: 84,
        summary: "A patient orchestral ascent."
    )

    try snapshot.save(to: defaults)
    let loaded = try #require(DJConnectTrackInsightWidgetSnapshot.load(from: defaults))

    #expect(loaded == snapshot)
}

@Test func askDJWidgetSnapshotStoresOnlyCompactVisibleText() throws {
    let suiteName = "DJConnectAskDJWidgetSnapshotTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let snapshot = DJConnectAskDJWidgetSnapshot(
        prompt: "  Tell me about this track\n",
        response: String(repeating: "warm ", count: 80),
        context: "Innerbloom - RUFUS DU SOL",
        trackTitle: "Innerbloom",
        artist: "RUFUS DU SOL"
    )

    try snapshot.save(to: defaults)
    let loaded = try #require(DJConnectAskDJWidgetSnapshot.load(from: defaults))

    #expect(loaded.prompt == "Tell me about this track")
    #expect(loaded.response.count <= 180)
    #expect(!loaded.response.contains("\n"))
    #expect(loaded.context == "Innerbloom - RUFUS DU SOL")
    #expect(loaded.trackTitle == "Innerbloom")
    #expect(loaded.artist == "RUFUS DU SOL")
}

@Test func nowPlayingWidgetSnapshotKeepsOnlySafeVisibleFields() throws {
    let playback = DJConnectPlayback(
        hasPlayback: true,
        isPlaying: true,
        trackName: "  Midnight City\n",
        artistName: "M83",
        albumImageURL: URL(string: "https://example.com/artwork.jpg"),
        progressMS: -100,
        durationMS: 244_000,
        device: DJConnectPlaybackDevice(
            id: "private-device-id",
            name: "  Living Room\n",
            type: "speaker",
            volumePercent: 50
        ),
        contextURI: "spotify:private:context"
    )

    let snapshot = try #require(DJConnectNowPlayingWidgetSnapshot(playback: playback))

    #expect(snapshot.title == "Midnight City")
    #expect(snapshot.artist == "M83")
    #expect(snapshot.artworkURL == URL(string: "https://example.com/artwork.jpg"))
    #expect(snapshot.progressMS == 0)
    #expect(snapshot.durationMS == 244_000)
    #expect(snapshot.isPlaying)
    #expect(snapshot.deviceName == "Living Room")
}

@Test func nowPlayingWidgetSnapshotStoresAndLoadsFromSharedDefaults() throws {
    let suiteName = "DJConnectNowPlayingWidgetSnapshotTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let snapshot = DJConnectNowPlayingWidgetSnapshot(
        title: "Sweet Disposition",
        artist: "The Temper Trap",
        artworkURL: URL(string: "https://example.com/sweet.jpg"),
        artworkData: Data([0x89, 0x50, 0x4e, 0x47]),
        progressMS: 42_000,
        durationMS: 232_000,
        isPlaying: true,
        deviceName: "Studio"
    )

    try snapshot.save(to: defaults)
    let loaded = try #require(DJConnectNowPlayingWidgetSnapshot.load(from: defaults))

    #expect(loaded == snapshot)
}

@Test func nowPlayingWidgetSnapshotKeepsProgressClockInputs() throws {
    let updatedAt = Date(timeIntervalSince1970: 1_000)
    let snapshot = DJConnectNowPlayingWidgetSnapshot(
        updatedAt: updatedAt,
        title: "Natural Blues",
        artist: "Moby",
        progressMS: 180_000,
        durationMS: 240_000,
        isPlaying: true
    )

    try #require(snapshot.progressMS == 180_000)
    try #require(snapshot.durationMS == 240_000)
    #expect(snapshot.updatedAt == updatedAt)
    #expect(snapshot.isPlaying)
}

@Test func queueWidgetSnapshotKeepsOnlySafeVisibleItems() throws {
    let items = (0..<7).map { index in
        DJConnectQueueItem(
            id: "private-\(index)",
            title: "  Track \(index)\n",
            artist: "Artist \(index)",
            album: "Album \(index)",
            uri: "spotify:track:private-\(index)",
            durationMS: -100 + index,
            albumImageURL: URL(string: "https://example.com/art-\(index).jpg")
        )
    }

    let snapshot = DJConnectQueueWidgetSnapshot(items: items)

    #expect(snapshot.items.count == 5)
    #expect(snapshot.totalCount == 7)
    #expect(snapshot.items.first?.title == "Track 0")
    #expect(snapshot.items.first?.artist == "Artist 0")
    #expect(snapshot.items.first?.album == "Album 0")
    #expect(snapshot.items.first?.durationMS == 0)
    #expect(snapshot.items.first?.artworkURL == URL(string: "https://example.com/art-0.jpg"))

    var cachedArtworkItem = snapshot.items[0]
    cachedArtworkItem.artworkData = Data([0x89, 0x50, 0x4e, 0x47])
    #expect(cachedArtworkItem.artworkData == Data([0x89, 0x50, 0x4e, 0x47]))
}

@Test func queueWidgetSnapshotStoresAndLoadsFromSharedDefaults() throws {
    let suiteName = "DJConnectQueueWidgetSnapshotTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let snapshot = DJConnectQueueWidgetSnapshot(items: [
        DJConnectQueueItem(title: "Innerbloom", artist: "RUFUS DU SOL", album: "Bloom", durationMS: 540_000),
        DJConnectQueueItem(title: "Strobe", artist: "deadmau5", album: "For Lack of a Better Name", durationMS: 633_000)
    ])

    try snapshot.save(to: defaults)
    let loaded = try #require(DJConnectQueueWidgetSnapshot.load(from: defaults))

    #expect(loaded == snapshot)
}

@Test func playlistsWidgetSnapshotKeepsOnlySafeVisibleItems() throws {
    let playlists = (0..<7).map { index in
        DJConnectPlaylist(
            id: "private-playlist-\(index)",
            name: "  Playlist \(index)\n",
            uri: "spotify:playlist:private-\(index)",
            imageURL: URL(string: "https://example.com/playlist-\(index).jpg"),
            subtitle: "Owner \(index)"
        )
    }

    let snapshot = DJConnectPlaylistsWidgetSnapshot(playlists: playlists)

    #expect(snapshot.items.count == 5)
    #expect(snapshot.totalCount == 7)
    #expect(snapshot.items.first?.name == "Playlist 0")
    #expect(snapshot.items.first?.subtitle == "Owner 0")
    #expect(snapshot.items.first?.imageURL == URL(string: "https://example.com/playlist-0.jpg"))
}

@Test func playlistsWidgetSnapshotStoresAndLoadsFromSharedDefaults() throws {
    let suiteName = "DJConnectPlaylistsWidgetSnapshotTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let snapshot = DJConnectPlaylistsWidgetSnapshot(playlists: [
        DJConnectPlaylist(name: "Friday Night", uri: "spotify:playlist:friday", subtitle: "DJConnect"),
        DJConnectPlaylist(name: "Dinner Vibes", uri: "spotify:playlist:dinner", subtitle: "Home")
    ])
    var snapshotWithArtwork = snapshot
    snapshotWithArtwork.items[0].imageData = Data([0x89, 0x50, 0x4e, 0x47])

    try snapshotWithArtwork.save(to: defaults)
    let loaded = try #require(DJConnectPlaylistsWidgetSnapshot.load(from: defaults))

    #expect(loaded == snapshotWithArtwork)
    #expect(loaded.items.first?.imageData == Data([0x89, 0x50, 0x4e, 0x47]))
}

@Test func localizationNormalizesDutchLanguageVariants() {
    #expect(DJConnectLocalization.localized(key: "About", language: "nl") == "Over")
    #expect(DJConnectLocalization.localized(key: "About", language: "nl-NL") == "Over")
    #expect(DJConnectLocalization.localized(key: "About", language: "NL") == "Over")
    #expect(DJConnectLocalization.localized(key: "About", language: "en") == "About")
    #expect(DJConnectLocalization.localized(key: "About", language: "de-DE") == "Info")
    #expect(DJConnectLocalization.localized(key: "About", language: "fr-FR") == "A propos")
    #expect(DJConnectLocalization.localized(key: "About", language: "es-ES") == "Acerca de")
    #expect(DJConnectLocalization.localized(key: "About", language: "") == "About")
    #expect(DJConnectLocalization.preferredLanguageCode(["nl-NL", "en-US"]) == "nl")
    #expect(DJConnectLocalization.preferredLanguageCode(["NL", "en-US"]) == "nl")
    #expect(DJConnectLocalization.preferredLanguageCode(["de-DE", "en-US"]) == "de")
    #expect(DJConnectLocalization.preferredLanguageCode(["fr-FR", "en-US"]) == "fr")
    #expect(DJConnectLocalization.preferredLanguageCode(["es-ES", "en-US"]) == "es")
    #expect(DJConnectLocalization.preferredLanguageCode(["en-US", "nl-NL"]) == "en")
    #expect(DJConnectLocalization.preferredLanguageCode([]) == "en")
}

@Test func localizationNormalizesEscapedNewlines() {
    let message = DJConnectLocalization.localized(
        key: "ui.playback.is.unavailable.ncheck.the.spotify.authorization.in.home.assistant",
        language: "nl"
    )
    #expect(message.contains("\n"))
    #expect(!message.contains("\\n"))
}

@Test func localizationResolvesWatchScreenKeys() {
    let dutchExpectations = [
        "watch.settings": "Instellingen",
        "watch.legal": "Juridisch",
        "watch.privacy": "Privacy",
        "watch.feedback": "Feedback",
        "watch.demo.mode.active": "Demo modus actief",
        "watch.app.language": "App-taal"
    ]

    for (key, value) in dutchExpectations {
        #expect(DJConnectLocalization.localized(key: key, language: "nl") == value)
        #expect(DJConnectLocalization.localized(key: key, language: "nl") != key)
    }

    #expect(DJConnectLocalization.localized(key: "watch.settings", language: "en") == "Settings")
    #expect(DJConnectLocalization.localized(key: "watch.legal", language: "en") == "Legal")
    #expect(DJConnectLocalization.localized(key: "watch.app.language", language: "en") == "App Language")
}

@Test func watchAppTargetsEmbedSharedLocalizableStrings() throws {
    let project = try loadRepositoryText("project.yml")
    #expect(project.contains("""
  DJConnectWatch:
    type: application
    platform: watchOS
    sources:
      - path: Apps/DJConnectWatch
      - path: Apps/Shared/Assets.xcassets
      - path: Sources/DJConnectCore/Resources
"""))
    #expect(project.contains("""
  DJConnectWatchComplications:
    type: app-extension
    platform: watchOS
    sources:
      - path: Apps/DJConnectWatchComplications
      - path: Sources/DJConnectCore/Resources
"""))

    let pbxproj = try loadRepositoryText("DJConnectApp.xcodeproj/project.pbxproj")
    let watchResources = try #require(pbxproj.pbxResourcesBuildPhase(named: "12C9797D02B6425447348CA2"))
    let complicationResources = try #require(pbxproj.pbxResourcesBuildPhase(named: "964A461C623039EE319842A2"))
    #expect(watchResources.contains("Localizable.strings in Resources"))
    #expect(complicationResources.contains("Localizable.strings in Resources"))
}

@Test func defaultDisplayLanguageUsesSharedAppLanguageOverrideForWidgets() throws {
    let sharedDefaults = try #require(UserDefaults(suiteName: DJConnectLocalization.appGroupIdentifier))
    let oldSharedOverride = sharedDefaults.string(forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
    defer {
        if let oldSharedOverride {
            sharedDefaults.set(oldSharedOverride, forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
        } else {
            sharedDefaults.removeObject(forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
        }
    }

    sharedDefaults.set("de", forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
    #expect(DJConnectLocalization.defaultDisplayLanguageCode(preferredLanguages: ["nl-NL"]) == "de")
    #expect(DJConnectLocalization.localized(key: "About") == "Info")

    sharedDefaults.removeObject(forKey: DJConnectLocalization.appLanguageOverrideDefaultsKey)
    #expect(DJConnectLocalization.defaultDisplayLanguageCode(preferredLanguages: ["nl-NL"]) == "nl")
}

@Test func localizationMapsClientLanguagesToBCP47Locales() {
    #expect(DJConnectLocalization.bcp47LocaleIdentifier(for: "nl") == "nl-NL")
    #expect(DJConnectLocalization.bcp47LocaleIdentifier(for: "en-GB") == "en-GB")
    #expect(DJConnectLocalization.bcp47LocaleIdentifier(for: "de_DE") == "de-DE")
    #expect(DJConnectLocalization.bcp47LocaleIdentifier(for: "fr") == "fr-FR")
    #expect(DJConnectLocalization.bcp47LocaleIdentifier(for: "es") == "es-ES")
    #expect(DJConnectLocalization.bcp47LocaleIdentifier(for: "") == "en-US")
}

@Test func pairingErrorPresentationLocalizesKnownHTTPCodes() {
    let context = DJConnectErrorPresentationContext.pairing(expectedPairingFlowName: "iPhone/iPad")

    let clientMismatch = DJConnectError.clientTypeMismatch(
        message: "client_type_mismatch",
        expectedClientType: "ios",
        receivedClientType: "watchos"
    )
    #expect(
        DJConnectErrorPresentation.userMessage(for: clientMismatch, language: "nl", context: context)?
            .contains("app-type") == true
    )
    #expect(
        DJConnectErrorPresentation.userMessage(for: clientMismatch, language: "de", context: context)?
            .contains("App-Typ") == true
    )

    let invalidPairCode = DJConnectError.server(statusCode: 400, message: #"{"error":"invalid_pair_code"}"#)
    #expect(
        DJConnectErrorPresentation.userMessage(for: invalidPairCode, language: "fr", context: context)?
            .contains("code d'association") == true
    )

    let notConfigured = DJConnectError.notConfigured(message: #"{"error":"not_configured"}"#)
    #expect(
        DJConnectErrorPresentation.userMessage(for: notConfigured, language: "es", context: .general)?
            .contains("configurado") == true
    )
}

@Test func homeScreenActionsDecodeWidgetAndShortcutDeepLinks() throws {
    #expect(DJConnectHomeScreenAction(deepLinkURL: try #require(URL(string: "djconnect://now-playing"))) == .nowPlaying)
    #expect(DJConnectHomeScreenAction(deepLinkURL: try #require(URL(string: "djconnect://queue"))) == .queue)
    #expect(DJConnectHomeScreenAction(deepLinkURL: try #require(URL(string: "djconnect://ask-dj"))) == .askDJ)
    #expect(DJConnectHomeScreenAction(deepLinkURL: try #require(URL(string: "djconnect://track-insight"))) == .trackInsight)
    #expect(DJConnectHomeScreenAction(deepLinkURL: try #require(URL(string: "djconnect://discover"))) == .discovery)
    #expect(DJConnectHomeScreenAction(deepLinkURL: try #require(URL(string: "djconnect://music-discovery"))) == .discovery)
    #expect(DJConnectHomeScreenAction(deepLinkURL: try #require(URL(string: "djconnect://ontdek"))) == .discovery)
    #expect(DJConnectHomeScreenAction(deepLinkURL: try #require(URL(string: "djconnect://playlists"))) == .playlists)
    #expect(DJConnectHomeScreenAction(deepLinkURL: try #require(URL(string: "djconnect:///queue"))) == .queue)
    #expect(DJConnectHomeScreenAction(deepLinkURL: try #require(URL(string: "https://djconnect.dev/queue"))) == nil)
    #expect(DJConnectHomeScreenAction(deepLinkURL: try #require(URL(string: "djconnect://unknown"))) == nil)
}

@Test func homeScreenActionRequestsAreUniqueEventsForRepeatedActions() {
    let first = DJConnectHomeScreenActionRequest(action: .askDJ)
    let second = DJConnectHomeScreenActionRequest(action: .askDJ)

    #expect(first.action == second.action)
    #expect(first != second)
}

@Test func iOSInfoPlistContainsCameraConsentAndNavigationMetadata() throws {
    let plist = try loadRepositoryPlist("Apps/DJConnectIOS/Info.plist")
    let cameraUsage = try #require(plist["NSCameraUsageDescription"] as? String)
    let urlTypes = try #require(plist["CFBundleURLTypes"] as? [[String: Any]])
    let shortcutItems = try #require(plist["UIApplicationShortcutItems"] as? [[String: Any]])

    #expect(cameraUsage.localizedCaseInsensitiveContains("camera"))
    #expect(cameraUsage.localizedCaseInsensitiveContains("QR"))
    #expect(urlTypes.contains { type in
        (type["CFBundleURLSchemes"] as? [String])?.contains("djconnect") == true
    })
    let shortcutTypes = shortcutItems.compactMap { $0["UIApplicationShortcutItemType"] as? String }
    #expect(shortcutTypes == [
        "dev.djconnect.action.now-playing",
        "dev.djconnect.action.ask-dj",
        "dev.djconnect.action.track-insight",
        "dev.djconnect.action.discovery",
        "dev.djconnect.action.queue"
    ])
    let askDJShortcut = try #require(shortcutItems.first {
        $0["UIApplicationShortcutItemType"] as? String == "dev.djconnect.action.ask-dj"
    })
    #expect(askDJShortcut["UIApplicationShortcutItemSubtitle"] as? String == "Ask for music")
    let discoveryShortcut = try #require(shortcutItems.first {
        $0["UIApplicationShortcutItemType"] as? String == "dev.djconnect.action.discovery"
    })
    #expect(discoveryShortcut["UIApplicationShortcutItemIconSymbolName"] as? String == "sparkles")
    #expect(discoveryShortcut["UIApplicationShortcutItemTitle"] as? String == "Discover")
    #expect(discoveryShortcut["UIApplicationShortcutItemSubtitle"] as? String == "Music DNA recommendations")

    let iPhoneOrientations = try #require(plist["UISupportedInterfaceOrientations~iphone"] as? [String])
    #expect(iPhoneOrientations == [
        "UIInterfaceOrientationPortrait",
        "UIInterfaceOrientationLandscapeLeft",
        "UIInterfaceOrientationLandscapeRight"
    ])
}

@Test func iOSInfoPlistLocalizesDiscoverShortcutStrings() throws {
    let expectedTitles = [
        "en": "Discover",
        "nl": "Ontdek",
        "de": "Entdecken",
        "fr": "Decouvrir",
        "es": "Descubrir"
    ]
    for (locale, title) in expectedTitles {
        let strings = try loadRepositoryText("Apps/DJConnectIOS/\(locale).lproj/InfoPlist.strings")
        #expect(strings.contains(#""Discover" = "\#(title)";"#))
        #expect(strings.contains(#""Music DNA recommendations" = "#))
    }
}

@Test func musicDNAIPhonePanelsStayTallAndInternallyScrollable() throws {
    let source = try loadRepositoryText("Sources/DJConnectUI/DJConnectRootView.swift")

    #expect(source.contains("private let musicDNAIPhoneDashboardPanelHeight: CGFloat = 320"))
    #expect(source.contains("private let musicDNAIPhoneLandscapeDashboardPanelHeight: CGFloat = 260"))
    #expect(source.contains(".frame(height: usesHorizontalRows ? horizontalPanelHeight : nil, alignment: .top)"))
    #expect(source.contains("ScrollView(.vertical, showsIndicators: false)"))
    #expect(source.contains(".scrollBounceBehavior(.basedOnSize)"))
}

@Test func gamesCanvasIsCappedOnIPadLandscapeOnly() throws {
    let source = try loadRepositoryText("Sources/DJConnectUI/DJConnectRootView.swift")

    #expect(source.contains("private func gameCanvasMaxHeight(for size: CGSize) -> CGFloat?"))
    #expect(source.contains("guard horizontalSizeClass == .regular, size.width > size.height else"))
    #expect(source.contains("return min(560, max(360, size.height * 0.42))"))
    #expect(source.contains("maxCanvasHeight: gameCanvasMaxHeight(for: proxy.size)"))
    #expect(source.contains(".frame(maxHeight: maxCanvasHeight)"))
}

@Test func publicReleaseWorkflowPublishesFiveLocalizedReleaseNoteJSONFiles() throws {
    let workflow = try loadRepositoryText(".github/workflows/public-unsigned-release.yml")
    let readme = try loadRepositoryText("README.md")
    let releaseDocs = try loadRepositoryText("docs/RELEASE.md")

    #expect(workflow.contains("languages=(en nl de fr es)"))
    #expect(workflow.contains("for lang in en nl de fr es; do"))
    #expect(workflow.contains("RELEASE_JSON_PATH=\"${localized_dir}/v${version}.json\""))
    #expect(workflow.contains("cp \"${localized_dir}/v${version}.json\" \"${localized_dir}/latest.json\""))
    #expect(readme.contains("Supported static What's New languages are"))
    #expect(readme.contains("`en`, `nl`, `de`, `fr`, and `es`"))
    #expect(releaseDocs.contains("{en|nl|de|fr|es}"))
    #expect(DJConnectAppModel.normalizedReleaseNotesLanguageCode("de-DE") == "de")
    #expect(DJConnectAppModel.normalizedReleaseNotesLanguageCode("fr-FR") == "fr")
    #expect(DJConnectAppModel.normalizedReleaseNotesLanguageCode("es-ES") == "es")
}

@Test func logsCopyToolbarIconStaysWhiteOnIOS() throws {
    let source = try loadRepositoryText("Sources/DJConnectUI/DJConnectRootView.swift")
    let copyLogsRange = try #require(source.range(of: #"Image(systemName: "doc.on.doc")"#))
    let copyLogsSnippet = String(source[copyLogsRange.lowerBound...].prefix(220))

    #expect(copyLogsSnippet.contains(".symbolRenderingMode(.monochrome)"))
    #expect(copyLogsSnippet.contains(".foregroundStyle(.white)"))
    #expect(copyLogsSnippet.contains(".tint(.white)"))
}

@Test func trackInsightSharePreviewUsesFormatSpecificSpacing() throws {
    let source = try loadRepositoryText("Sources/DJConnectUI/TrackInsightShareViews.swift")

    #expect(source.contains("private var actionStackTopPadding: CGFloat"))
    #expect(source.contains("case .square:\n            8"))
    #expect(source.contains(".padding(.bottom, 14)"))
    #expect(source.contains("let previewWidth = min(availableWidth, maxHeight * aspectRatio)"))
    #expect(source.contains("horizontalSizeClass == .compact ? 380 : 620"))
}

@MainActor
@Test func trackInsightShareTextStaysCompactAndPublic() {
    let insight = TrackInsight(
        title: "Innerbloom",
        artist: "RUFUS DU SOL",
        genre: "Deep House",
        mood: "Dreamy",
        vibe: "Euphoric",
        summary: "A slow-building journey with glowing synth textures.",
        rawAnalysisText: "Visible summary only.",
        musicDNAMatchPercent: 96
    )

    let text = TrackInsightShareService.shareText(for: insight)

    #expect(text.contains("Currently vibing to Innerbloom by RUFUS DU SOL."))
    #expect(text.contains("Inspired by your Music DNA."))
    #expect(text.contains("#DJConnect #TrackInsight"))
    #expect(!text.localizedCaseInsensitiveContains("token"))
    #expect(!text.localizedCaseInsensitiveContains("entity_id"))
    #expect(!text.localizedCaseInsensitiveContains("home assistant"))
}

private func loadRepositoryPlist(_ relativePath: String) throws -> [String: Any] {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(relativePath)
    let data = try Data(contentsOf: url)
    let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    return try #require(object as? [String: Any])
}

private func loadRepositoryText(_ relativePath: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

private extension String {
    func pbxResourcesBuildPhase(named identifier: String) -> String? {
        guard let start = range(of: "\(identifier) /* Resources */ = {"),
              let end = self[start.upperBound...].range(of: "\n\t\t};") else {
            return nil
        }
        return String(self[start.lowerBound..<end.upperBound])
    }
}

@MainActor
@Test func trackInsightShareCleanupKeepsRecentExportsAndRemovesOldExports() throws {
    let directory = TrackInsightShareRenderer.temporaryOutputDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let oldURL = directory.appendingPathComponent("old-\(UUID().uuidString).mp4")
    let recentURL = directory.appendingPathComponent("recent-\(UUID().uuidString).mp4")
    try Data("old".utf8).write(to: oldURL)
    try Data("recent".utf8).write(to: recentURL)
    let now = Date()
    try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-3_600)], ofItemAtPath: oldURL.path)
    try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: recentURL.path)

    try TrackInsightShareRenderer.cleanupTemporaryExports(olderThan: 60, now: now)

    #expect(!FileManager.default.fileExists(atPath: oldURL.path))
    #expect(FileManager.default.fileExists(atPath: recentURL.path))
    try? FileManager.default.removeItem(at: recentURL)
}

@Test func trackVibeProfileIsDeterministicForSameInsight() {
    let insight = TrackInsight(
        title: "Marea",
        artist: "Fred again..",
        genre: "House",
        energy: 0.8,
        danceability: 0.88,
        intensity: 0.72,
        mood: "Energetic",
        vibe: "Human",
        texture: "Vocal chops",
        summary: "A club record with an intimate human center.",
        rawAnalysisText: "Demo"
    )

    #expect(TrackVibeProfile.make(for: insight) == TrackVibeProfile.make(for: insight))
}

@Test func demoTrackInsightServiceMapsDemoQueueTracksToDistinctInsights() async throws {
    let service = DemoTrackInsightService()
    let demoTracks = [
        DJConnectPlayback(trackName: "Midnight City", artistName: "M83"),
        DJConnectPlayback(trackName: "Sweet Disposition", artistName: "The Temper Trap"),
        DJConnectPlayback(trackName: "Electric Feel", artistName: "MGMT")
    ]

    var insights: [TrackInsight] = []
    for playback in demoTracks {
        insights.append(try await service.insight(for: playback))
    }

    #expect(insights.map(\.title) == ["Midnight City", "Sweet Disposition", "Electric Feel"])
    #expect(Set(insights.map(\.genre)).count == 3)
    let profiles = insights.map { TrackVibeProfile.make(for: $0) }
    #expect(profiles[0] != profiles[1])
    #expect(profiles[1] != profiles[2])
    #expect(profiles[0] != profiles[2])
}

@Test func demoTrackInsightServiceLocalizesDutchDemoCopy() async throws {
    let service = DemoTrackInsightService(
        tracks: DemoTrackInsightService.localizedDefaultTracks(language: "nl")
    )

    let insight = try await service.insight(for: DJConnectPlayback(trackName: "Midnight City", artistName: "M83"))

    #expect(insight.genre == "Synthpop")
    #expect(insight.mood == "Nostalgisch")
    #expect(insight.vibe == "Nachtelijk")
    #expect(insight.texture == "Neon-synthlijnen en gated drums")
    #expect(insight.summary == "Een gloeiend nachtelijke drive-anthem met een heldere synthhook, brede pads en een filmische rush.")
}

@Test func releaseScriptPinsRemoteBasePushAndVersionScopedNotes() throws {
    let script = try loadRepositoryText("release.sh")

    #expect(script.contains("git fetch origin main"))
    #expect(script.contains("git merge-base --is-ancestor origin/main HEAD"))
    #expect(script.contains("run git push origin HEAD:main"))
    #expect(script.contains("write_changelog_release_notes"))
    #expect(script.contains(#"$0 ~ "^## " version "($| - )" { capture=1; next }"#))
    #expect(!script.contains("See CHANGELOG.md for details."))
}
