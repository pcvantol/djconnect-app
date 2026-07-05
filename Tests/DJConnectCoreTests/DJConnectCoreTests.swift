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
        startLocalAPI: false,
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
private func waitForLocalDeviceAPIURL(_ model: DJConnectAppModel) async throws -> String {
    for _ in 0..<30 {
        if let url = model.localDeviceAPIURL, !url.isEmpty {
            return url
        }
        try await Task.sleep(for: .milliseconds(100))
    }
    throw URLError(.timedOut)
}

private struct LocalDeviceJSON: Decodable, Sendable {
    var deviceID: String
    var clientType: String
    var version: String
    var firmware: String
    var appVersion: String
    var platform: String
    var status: String
    var pairingStatus: String
    var localURL: String
    var pairCode: String?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientType = "client_type"
        case version
        case firmware
        case appVersion = "app_version"
        case platform
        case status
        case pairingStatus = "pairing_status"
        case localURL = "local_url"
        case pairCode = "pair_code"
    }
}

private func localDeviceJSON(from urlString: String) async throws -> LocalDeviceJSON {
    let url = try #require(URL(string: urlString))
    let (data, response) = try await URLSession.shared.data(from: url)
    let httpResponse = try #require(response as? HTTPURLResponse)
    #expect(httpResponse.statusCode == 200)
    return try JSONDecoder().decode(LocalDeviceJSON.self, from: data)
}

@MainActor
@Test func resetPairingRotatesLocalIdentityAndCode() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set("manual-code", forKey: "DJConnectPairingToken")
    let tokenStore = DJConnectInMemoryTokenStore(token: "secret-token")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: tokenStore, startLocalAPI: false, startBackgroundTasks: false)
    let originalDeviceID = model.identity.deviceID
    let originalPairingToken = model.pairingToken

    model.resetPairing()

    #expect(model.identity.deviceID != originalDeviceID)
    #expect(model.identity.deviceID.hasPrefix("djconnect-"))
    #expect(model.pairingToken != originalPairingToken)
    #expect(try tokenStore.loadToken() == nil)
}

@MainActor
@Test func freshInstallIgnoresOrphanedPersistentDeviceToken() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let tokenStore = DJConnectUserDefaultsTokenStore(defaults: defaults, key: "DJConnectTestDeviceToken")
    try tokenStore.saveToken("orphaned-token")

    let model = DJConnectAppModel(defaults: defaults, tokenStore: tokenStore, startLocalAPI: false, startBackgroundTasks: false)

    #expect(model.pairingStatus == .unpaired)
    #expect(model.isConnected == false)
    #expect(try tokenStore.loadToken() == nil)
    #expect(defaults.string(forKey: "DJConnectInstallID")?.isEmpty == false)
}

@MainActor
@Test func pairingAuthStaleKeepsLocalDiscoveryActive() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set("PAIR42", forKey: "DJConnectPairingToken")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)
    model.language = "nl"

    model.applyPairingWait(
        error: .authStale(
            statusCode: 401,
            message: "The pairing code does not match this DJConnect setup."
        ),
        pairingToken: "PAIR42"
    )

    #expect(model.pairingStatus == .pairing)
    #expect(model.isPairing == true)
    #expect(!model.isTerminalPairingError(.authStale(statusCode: 401, message: nil)))
    #expect(model.pairingMessage?.contains("Lokale discovery blijft actief.") == true)
    #expect(model.pairingMessage?.contains("Open DJConnect in Home Assistant") == true)
    #expect(model.pairingMessage?.contains("The pairing code does not match") == false)
}

@MainActor
@Test func authStaleClearsTokenAndReopensPairingWithoutBonjour() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(true, forKey: "DJConnectWelcomeSeen")
    defaults.set("http://192.168.1.104:55046", forKey: "DJConnectLocalDeviceAPIURL")
    let tokenStore = DJConnectInMemoryTokenStore(token: "stale-token")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: tokenStore, startLocalAPI: false, startBackgroundTasks: false)
    defer {
        model.stopPairingWait()
        model.stopLocalDeviceAPI()
    }

    #expect(model.pairingStatus == .paired)
    #expect(model.isBonjourAdvertisingPreferredForTests == false)

    model.apply(error: .authStale(statusCode: 401, message: "The DJConnect device token is missing or invalid."))

    #expect(model.pairingStatus == .pairing || model.pairingStatus == .stale)
    #expect(model.isPairingScreenDismissed == false)
    #expect(model.isBonjourAdvertisingPreferredForTests == false)
    #expect(model.localDeviceAPIURL == nil)
    #expect(defaults.string(forKey: "DJConnectLocalDeviceAPIURL") == nil)
    #expect(try tokenStore.loadToken() == nil)
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
        localURL: "http://192.168.1.105:51193",
        voiceEnabled: true,
        wakewordEnabled: true,
        wakewordPhrase: "Okay Nabu",
        wakewordStatus: "listening",
        mood: 75,
        djStyle: "warm_radio_dj",
        memoryKey: "user:peter"
    )

    let request = try client.statusRequest(payload)
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/v1/status")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-ID") == nil)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(json?["client_id"] == nil)
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["device_name"] as? String == identity.deviceName)
    #expect(json?["client_type"] as? String == "ios")
    #expect(json?["firmware"] as? String == "3.1.7")
    #expect(json?["app_version"] as? String == "3.1.7")
    #expect(json?["ha_local_url"] as? String == "http://192.168.1.10:8123")
    #expect(json?["ha_remote_url"] == nil)
    #expect(json?["ha_active_url"] == nil)
    #expect(json?["local_url"] as? String == "http://192.168.1.105:51193")
    #expect(json?["voice_enabled"] as? Bool == true)
    #expect(json?["wakeword_enabled"] as? Bool == true)
    #expect(json?["wakeword_phrase"] as? String == "Okay Nabu")
    #expect(json?["wakeword_status"] as? String == "listening")
    #expect(json?["mood"] as? Int == 75)
    #expect(json?["dj_style"] as? String == "warm_radio_dj")
    #expect(json?["memory_key"] as? String == "user:peter")
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
            play: true
        )
    )
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/v1/command")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-ID") == nil)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(json?["client_id"] as? String == identity.deviceID)
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["device_name"] as? String == identity.deviceName)
    #expect(json?["client_type"] as? String == "macos")
    #expect(json?["command"] as? String == "set_volume")
    #expect(json?["value"] as? Int == 35)
    #expect(json?["play"] as? Bool == true)
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
        memoryKey: "djconnect_ios_8F3A2C91B45D",
        audioResponse: .auto
    ))
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/v1/ask_dj/message")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["device_name"] as? String == identity.deviceName)
    #expect(json?["client_type"] as? String == "ios")
    #expect(json?["client_id"] as? String == identity.deviceID)
    #expect(json?["client_message_id"] as? String == "client-message-1")
    #expect(json?["input_type"] as? String == "text")
    #expect(json?["text"] as? String == "Verras me met nieuwe muziek")
    #expect(json?["mood"] as? Int == 70)
    #expect(json?["audio_response"] as? String == "auto")
}

@Test func clearAskDJHistoryRequestIncludesClientIdentityAndMemoryKey() throws {
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

    let request = try client.clearAskDJHistoryRequest(memoryKey: "djconnect_ios_8F3A2C91B45D")
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/v1/ask_dj/history/clear")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["client_type"] as? String == "ios")
    #expect(json?["memory_key"] as? String == "djconnect_ios_8F3A2C91B45D")
}

@Test func askDJHistoryRequestUsesCanonicalV1EndpointAndSinceRevision() throws {
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

    let request = try client.askDJHistoryRequest(sinceRevision: 42)
    let requestURL = try #require(request.url)
    let components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))

    #expect(request.httpMethod == "GET")
    #expect(components.path == "/api/djconnect/v1/ask_dj/history")
    #expect(components.queryItems == [URLQueryItem(name: "since_revision", value: "42")])
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
}

@Test func vibeCastRequestUsesCanonicalV1Endpoint() throws {
    let identity = DJConnectIdentity(deviceID: "djconnect-ios-test", deviceName: "iPhone", clientType: .ios, firmware: "3.2.0", platform: .ios)
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://ha.local:8123")),
        identity: identity,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token")
    )

    let request = try client.vibeCastRequest()

    #expect(request.httpMethod == "GET")
    #expect(request.url?.path == "/api/djconnect/v1/vibecast")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
}

@Test func vibeCastArtistImageUsesArtistFactImageURL() throws {
    let data = Data("""
    {
      "revision": 12,
      "ttl_seconds": 30,
      "poll_after_seconds": 10,
      "context": {
        "artist_image_url": "/api/djconnect/v1/proxy/images/context-artist.jpg"
      },
      "items": [
        {
          "kind": "artist_fact",
          "title": "Artist shout-out",
          "text": "A precise artist fact.",
          "image_url": "/api/djconnect/v1/proxy/images/artist-fact.jpg",
          "thumbnail_url": "/api/djconnect/v1/proxy/images/artist-thumb.jpg",
          "image_alt": "Portrait of Example Artist",
          "image_source": "musicbrainz"
        }
      ]
    }
    """.utf8)

    let response = try JSONDecoder().decode(DJConnectVibeCastResponse.self, from: data)
    let renderState = DJConnectVibeCastRenderState.rendered(from: response)

    #expect(response.revision == 12)
    #expect(response.ttlSeconds == 30)
    #expect(response.pollAfterSeconds == 10)
    #expect(renderState.artistImage?.url.absoluteString == "/api/djconnect/v1/proxy/images/artist-fact.jpg")
    #expect(renderState.artistImage?.alt == "Portrait of Example Artist")
    #expect(renderState.artistImage?.source == "musicbrainz")
}

@Test func vibeCastArtistImageFallsBackToContextArtistImageURL() throws {
    let data = Data("""
    {
      "revision": 13,
      "context": {
        "artist_image_url": "/api/djconnect/v1/proxy/images/context-artist.jpg"
      },
      "items": [
        {
          "kind": "artist_fact",
          "title": "Artist shout-out",
          "text": "No item image on this response."
        }
      ]
    }
    """.utf8)

    let response = try JSONDecoder().decode(DJConnectVibeCastResponse.self, from: data)
    let renderState = DJConnectVibeCastRenderState.rendered(from: response)

    #expect(renderState.revision == 13)
    #expect(renderState.artistImage?.url.absoluteString == "/api/djconnect/v1/proxy/images/context-artist.jpg")
}

@Test func vibeCastMissingImageFieldsKeepTextOnlyRendering() throws {
    let data = Data("""
    {
      "revision": 14,
      "items": [
        {
          "kind": "artist_fact",
          "title": "Artist shout-out",
          "text": "Still render the text exactly as before.",
          "unknown_future_field": {"ignored": true}
        }
      ]
    }
    """.utf8)

    let response = try JSONDecoder().decode(DJConnectVibeCastResponse.self, from: data)
    let renderState = DJConnectVibeCastRenderState.rendered(from: response)

    #expect(response.items.first?.text == "Still render the text exactly as before.")
    #expect(renderState.artistImage == nil)
}

@Test func vibeCastIgnoresDirectExternalArtistImageURLs() throws {
    let data = Data("""
    {
      "revision": 15,
      "context": {
        "artist_image_url": "https://images.example-catalog.test/artist.jpg"
      },
      "items": [
        {
          "kind": "artist_fact",
          "title": "Artist shout-out",
          "image_url": "https://open.spotify.com/image/direct.jpg",
          "thumbnail_url": "https://wikipedia.org/thumb/direct.jpg"
        }
      ]
    }
    """.utf8)

    let response = try JSONDecoder().decode(DJConnectVibeCastResponse.self, from: data)
    let renderState = DJConnectVibeCastRenderState.rendered(from: response)

    #expect(response.items.first?.imageURL == nil)
    #expect(response.items.first?.thumbnailURL == nil)
    #expect(response.context?.artistImageURL == nil)
    #expect(renderState.artistImage == nil)
}

@Test func vibeCastTextOnlyResponseClearsPreviousArtistImageState() throws {
    let imageResponse = DJConnectVibeCastResponse(
        revision: 20,
        items: [
            DJConnectVibeCastItem(
                kind: "artist_fact",
                title: "Artist shout-out",
                imageURL: URL(string: "/api/djconnect/v1/proxy/images/artist.jpg")
            )
        ]
    )
    let textOnlyResponse = DJConnectVibeCastResponse(
        revision: 21,
        items: [
            DJConnectVibeCastItem(kind: "artist_fact", title: "Artist shout-out", text: "Text-only refresh.")
        ]
    )

    let imageState = DJConnectVibeCastRenderState.rendered(from: imageResponse)
    let textOnlyState = DJConnectVibeCastRenderState.rendered(from: textOnlyResponse)

    #expect(imageState.artistImage?.url.absoluteString == "/api/djconnect/v1/proxy/images/artist.jpg")
    #expect(textOnlyState.revision == 21)
    #expect(textOnlyState.artistImage == nil)
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
        memoryKey: "djconnect_watchos_8F3A2C91B45D"
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

@Test func clientCallRoutesUseCanonicalV1Prefix() throws {
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
    let statusPayload = DJConnectStatusPayload(identity: identity)
    let commandPayload = DJConnectCommandPayload(identity: identity, command: "status")
    let askPayload = DJConnectAskDJRequest(
        identity: identity,
        text: "Welke track draait dit?",
        clientMessageID: "client-message-1"
    )
    let pushRegister = DJConnectPushRegistrationRequest(
        identity: identity,
        pushToken: "abcdef123456",
        pushEnvironment: .sandbox,
        appBundleID: "dev.djconnect.ios"
    )
    let pushUnregister = DJConnectPushUnregistrationRequest(
        identity: identity,
        pushToken: "abcdef123456"
    )

    let paths = try [
        client.statusRequest(statusPayload),
        client.commandRequest(commandPayload),
        client.askDJMessageRequest(askPayload),
        client.askDJHistoryRequest(sinceRevision: 1),
        client.clearAskDJHistoryRequest(),
        client.askDJIdleSuggestionRequest(DJConnectAskDJIdleSuggestionRequest(
            identity: identity,
            clientMessageID: "idle-suggestion-1"
        )),
        client.pushRegisterRequest(pushRegister),
        client.pushUnregisterRequest(pushUnregister),
        client.voiceRequest(wavData: Data())
    ].map { try #require($0.url?.path) }

    for path in paths {
        #expect(path.hasPrefix("/api/djconnect/v1/"))
        #expect(!path.hasPrefix("/api/djconnect/v1/ask_dj/") || path != "/api/djconnect/v1/ask_dj")
    }
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

@Test func askDJMessageResponseDecodesTechnicalTrackAnalysisContract() throws {
    let json = """
    {
      "history_revision": 44,
      "clear_revision": 7,
      "text": "Deze track werkt door de strakke 128 BPM puls en geleidelijke laag-opbouw.",
      "dj_text": "Deze track werkt door de strakke 128 BPM puls en geleidelijke laag-opbouw.",
      "action": "track_analysis",
      "intent": {
        "category": "informational",
        "intent": "technical_track_analysis",
        "action": "track_analysis"
      },
      "analysis": {
        "mode": "measured_plus_knowledge",
        "confidence": "high",
        "track": {
          "title": "Strobe",
          "artist": "deadmau5",
          "album": "For Lack of a Better Name",
          "uri": "spotify:track:123"
        },
        "measured": {
          "bpm": 128,
          "key": "C minor",
          "time_signature": 4,
          "sections": [
            {
              "label": "intro",
              "index": 1,
              "start_ms": 0,
              "duration_ms": 32000,
              "confidence": 0.7
            }
          ],
          "features": {
            "energy": 0.82,
            "danceability": 0.71
          }
        },
        "inferred": {
          "provider": "ha_conversation",
          "structure": "Lange intro, laag-opbouw, climax/drop en outro.",
          "instrumentation": "Synthpads, basdruk en subtiele percussie.",
          "melodic_build": "Herhaling bouwt spanning op.",
          "energy_curve": "Geleidelijk stijgend.",
          "mix_notes": "Brede pads met ruimte voor de kick."
        },
        "limitations": [
          "Exact section labels are inferred, not measured."
        ],
        "sources": [
          "spotify_playback_context",
          "spotify_audio_features"
        ]
      },
      "items": [
        {
          "kind": "technical_metric",
          "title": "BPM",
          "value": "128",
          "source": "spotify_audio_features",
          "confidence": "high"
        },
        {
          "kind": "arrangement",
          "title": "Opbouw",
          "value": "Lange intro, geleidelijke laag-opbouw, climax/drop, outro",
          "source": "ha_conversation"
        }
      ],
      "images": [],
      "links": [],
      "sources": [
        {
          "source": "spotify_playback_context",
          "title": "Spotify playback context",
          "kind": "source"
        }
      ],
      "playback_actions": [],
      "confirmation_actions": []
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)
    let assistantMessage = try #require(response.assistantMessage)

    #expect(response.intentInfo?.category == "informational")
    #expect(response.intentInfo?.intent == "technical_track_analysis")
    #expect(response.intentInfo?.action == "track_analysis")
    #expect(response.analysis?.mode == "measured_plus_knowledge")
    #expect(response.analysis?.measured?.bpm == 128)
    #expect(response.analysis?.measured?.key == "C minor")
    #expect(response.analysis?.measured?.sections.first?.label == "intro")
    #expect(response.analysis?.measured?.sections.first?.index == 1)
    #expect(response.analysis?.inferred?.provider == "ha_conversation")
    #expect(response.analysis?.inferred?.mixNotes == "Brede pads met ruimte voor de kick.")
    #expect(response.analysis?.sources == ["spotify_playback_context", "spotify_audio_features"])
    #expect(response.items?.first?.kind == "technical_metric")
    #expect(response.items?.first?.value == "128")
    #expect(response.items?.first?.source == "spotify_audio_features")
    #expect(response.items?.first?.confidence == "high")
    #expect(response.sources?.first?.url.scheme == "djconnect-source")
    #expect(response.sources?.first?.source == "spotify_playback_context")
    #expect(response.playbackActions?.isEmpty == true)
    #expect(response.confirmationActions?.isEmpty == true)
    #expect(assistantMessage.intentInfo?.intent == "technical_track_analysis")
    #expect(assistantMessage.analysis?.confidence == "high")
    #expect(assistantMessage.items.count == 2)
    #expect(assistantMessage.sources.first?.url.scheme == "djconnect-source")
    #expect(assistantMessage.playbackActions.isEmpty)
    #expect(assistantMessage.confirmationActions.isEmpty)
    #expect(assistantMessage.images.isEmpty)
}

@Test func localAskDJTechnicalTrackAnalysisPreservesExplicitRenderableActions() throws {
    let message = DJConnectAskDJMessage(
        role: .dj,
        text: "Technische trackanalyse.",
        playbackActions: [
            DJConnectAskDJPlaybackAction(
                title: "Unexpected Play",
                uri: "spotify:track:unexpected",
                kind: "track"
            )
        ],
        intentInfo: DJConnectAskDJIntentInfo(
            category: "informational",
            intent: "technical_track_analysis",
            action: "track_analysis"
        ),
        analysis: try JSONDecoder().decode(
            DJConnectAskDJTrackAnalysis.self,
            from: Data(
                #"""
                {
                  "mode": "knowledge_plus_metadata",
                  "confidence": "low",
                  "limitations": [
                    "Exact intro, verse, chorus, drop or outro timestamps were not measured."
                  ]
                }
                """#.utf8
            )
        ),
        items: [
            DJConnectAskDJHistoryItem(
                kind: "technical_metric",
                title: "Energy",
                value: "0.82",
                source: "spotify_audio_features",
                confidence: "high"
            )
        ]
    )

    let encoded = try JSONEncoder().encode(message)
    let decoded = try JSONDecoder().decode(DJConnectAskDJMessage.self, from: encoded)

    #expect(decoded.isTechnicalTrackAnalysis)
    #expect(decoded.playbackActions.count == 1)
    #expect(decoded.renderablePlaybackActions.count == 1)
    #expect(decoded.analysis?.mode == "knowledge_plus_metadata")
    #expect(decoded.analysis?.limitations.first == "Exact intro, verse, chorus, drop or outro timestamps were not measured.")
    #expect(decoded.items.first?.confidence == "high")
}

@Test func askDJMessageResponseDecodesTechnicalTrackAnalysisV2SectionsTimelineAndTips() throws {
    let json = """
    {
      "text": "Technische analyse, zonder timestamps in prose.",
      "action": "track_analysis",
      "intent": {
        "intent": "technical_track_analysis",
        "action": "track_analysis"
      },
      "analysis": {
        "contract_version": 2,
        "mode": "measured_plus_knowledge",
        "confidence": "medium",
        "sections": [
          {
            "id": "rhythm_bpm",
            "kind": "technical_metric",
            "title": "Rhythm / BPM",
            "value": "128 BPM",
            "summary": "Steady four-on-the-floor pulse.",
            "source": "measured",
            "confidence": "high",
            "items": [
              {
                "kind": "technical_metric",
                "title": "BPM",
                "value": "128",
                "source": "measured",
                "confidence": "high"
              }
            ]
          },
          {
            "id": "energy_curve",
            "kind": "shape",
            "title": "Energy curve",
            "summary": "Builds gradually into a brighter peak.",
            "source": "inferred",
            "confidence": "low"
          }
        ],
        "timeline": [
          {
            "id": "intro",
            "label": "Intro",
            "kind": "intro",
            "start_ms": 0,
            "end_ms": 32000,
            "summary": "Filtered opening.",
            "source": "measured",
            "confidence": "medium"
          }
        ],
        "dj_tips": [
          {
            "id": "mix_in",
            "kind": "transition",
            "title": "Mix in",
            "text": "Start mixing over the first 16 bars.",
            "source": "inferred",
            "confidence": "low"
          }
        ],
        "providers": [
          {
            "provider_id": "spotify_measured",
            "display_name": "Spotify measured",
            "status": "used",
            "requires_config": false
          },
          {
            "provider_id": "ha_conversation",
            "display_name": "Home Assistant conversation",
            "status": "skipped",
            "reason": "Not needed for measured fields."
          },
          {
            "provider_id": "local_fallback",
            "display_name": "Local fallback",
            "status": "used"
          }
        ],
        "limitations": [
          "Energy labels are inferred."
        ],
        "sources": ["spotify_audio_features", "inferred"]
      },
      "items": [
        {
          "kind": "technical_metric",
          "title": "Energy",
          "value": "0.82",
          "source": "measured",
          "confidence": "medium"
        }
      ],
      "images": []
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)
    let analysis = try #require(response.analysis)
    let assistantMessage = try #require(response.assistantMessage)

    #expect(response.intentInfo?.intent == "technical_track_analysis")
    #expect(response.action == "track_analysis")
    #expect(analysis.contractVersion == 2)
    #expect(analysis.sections.count == 2)
    #expect(analysis.sections.first?.id == "rhythm_bpm")
    #expect(analysis.sections.first?.items.first?.title == "BPM")
    #expect(analysis.sections.last?.source == "inferred")
    #expect(analysis.sections.last?.confidence == "low")
    #expect(analysis.timeline.first?.startMS == 0)
    #expect(analysis.timeline.first?.endMS == 32000)
    #expect(analysis.djTips.first?.kind == "transition")
    #expect(analysis.providers.count == 3)
    #expect(analysis.providers.first?.providerID == "spotify_measured")
    #expect(analysis.providers.first?.status == "used")
    #expect(analysis.providers.first?.requiresConfig == false)
    #expect(analysis.providers[1].providerID == "ha_conversation")
    #expect(analysis.providers[1].status == "skipped")
    #expect(analysis.providers[1].reason == "Not needed for measured fields.")
    #expect(analysis.providers[2].providerID == "local_fallback")
    #expect(analysis.limitations == ["Energy labels are inferred."])
    #expect(assistantMessage.analysis?.contractVersion == 2)
    #expect(assistantMessage.analysis?.sections.count == 2)
    #expect(assistantMessage.analysis?.providers.count == 3)
    #expect(assistantMessage.items.first?.title == "Energy")
    #expect(assistantMessage.images.isEmpty)
    #expect(assistantMessage.playbackActions.isEmpty)
}

@Test func askDJMessageResponseDecodesTechnicalTrackAnalysisV2WithoutTimeline() throws {
    let json = """
    {
      "dj_text": "Technische analyse zonder timeline.",
      "intent": {
        "intent": "technical_track_analysis"
      },
      "analysis": {
        "contract_version": 2,
        "mode": "knowledge_plus_metadata",
        "sections": [
          {
            "id": "instrumentation",
            "kind": "description",
            "title": "Instrumentation",
            "summary": "Pads and restrained percussion.",
            "source": "inferred",
            "confidence": "medium"
          }
        ],
        "dj_tips": [
          {
            "kind": "cueing",
            "text": "Use the pad tail for a smooth transition.",
            "source": "inferred"
          }
        ]
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)

    #expect(response.analysis?.contractVersion == 2)
    #expect(response.analysis?.sections.first?.id == "instrumentation")
    #expect(response.analysis?.timeline.isEmpty == true)
    #expect(response.analysis?.djTips.first?.text == "Use the pad tail for a smooth transition.")
    #expect(response.analysis?.providers.isEmpty == true)
}

@Test func askDJMessageResponseDecodesTechnicalTrackAnalysisMetaBrainzMetadataContext() throws {
    let json = """
    {
      "text": "Technische analyse met open metadata-context.",
      "intent": {
        "intent": "technical_track_analysis",
        "action": "track_analysis"
      },
      "analysis": {
        "contract_version": 2,
        "mode": "measured_plus_knowledge",
        "confidence": "medium",
        "sections": [
          {
            "id": "rhythm_bpm",
            "kind": "technical_metric",
            "title": "Rhythm / BPM",
            "value": "126 BPM",
            "source": "spotify_audio_features",
            "confidence": "high"
          },
          {
            "id": "metadata_context",
            "kind": "metadata_context",
            "title": "Open metadata",
            "summary": "Public MusicBrainz and ListenBrainz context, not DSP analysis.",
            "source": "metabrainz_metadata",
            "confidence": "medium"
          }
        ],
        "timeline": [
          {
            "id": "measured_segment_1",
            "label": "Segment 1",
            "start_ms": 0,
            "source": "spotify_audio_analysis"
          }
        ],
        "dj_tips": [
          {
            "id": "mix_tip",
            "text": "Use the measured BPM for beat matching.",
            "source": "spotify_audio_features"
          }
        ],
        "metadata": {
          "musicbrainz_recording_id": "mb-recording-123",
          "match_score": 93,
          "recording_title": "Example Track",
          "artist": "Example Artist",
          "first_release_date": "1999-04-01",
          "release": {
            "title": "Example Release",
            "date": "1999",
            "country": "NL",
            "status": "official"
          },
          "genres": ["house", "techno"],
          "tags": ["club", "classic"],
          "listenbrainz_listen_count": 12345,
          "future_metadata_field": "ignored"
        },
        "providers": [
          {
            "provider_id": "spotify_measured",
            "display_name": "Spotify measured",
            "status": "used"
          },
          {
            "provider_id": "metabrainz_metadata",
            "display_name": "MusicBrainz / ListenBrainz",
            "status": "used"
          }
        ],
        "limitations": [
          "MusicBrainz and ListenBrainz metadata is contextual and is not audio DSP analysis."
        ],
        "sources": [
          "spotify_playback_context",
          "spotify_audio_features",
          "spotify_audio_analysis",
          "metabrainz_metadata"
        ]
      },
      "playback_actions": []
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)
    let analysis = try #require(response.analysis)
    let metadata = try #require(analysis.metadata)

    #expect(analysis.sections.count == 2)
    #expect(analysis.sections[0].id == "rhythm_bpm")
    #expect(analysis.sections[1].id == "metadata_context")
    #expect(analysis.sections[1].source == "metabrainz_metadata")
    #expect(analysis.timeline.count == 1)
    #expect(analysis.timeline.first?.label == "Segment 1")
    #expect(metadata.musicBrainzRecordingID == "mb-recording-123")
    #expect(metadata.matchScore == 93)
    #expect(metadata.recordingTitle == "Example Track")
    #expect(metadata.artist == "Example Artist")
    #expect(metadata.firstReleaseDate == "1999-04-01")
    #expect(metadata.release?.title == "Example Release")
    #expect(metadata.release?.country == "NL")
    #expect(metadata.genres == ["house", "techno"])
    #expect(metadata.tags == ["club", "classic"])
    #expect(metadata.listenBrainzListenCount == 12345)
    #expect(analysis.providers.contains { $0.providerID == "metabrainz_metadata" && $0.status == "used" })
    #expect(analysis.sources.contains("metabrainz_metadata"))
    #expect(analysis.limitations.first?.contains("contextual") == true)
    #expect(response.assistantMessage?.playbackActions.isEmpty == true)
}

@Test func askDJMessageResponseDecodesMetaBrainzProviderSkippedRateLimited() throws {
    let json = """
    {
      "text": "Analyse zonder externe metadata.",
      "intent": {
        "intent": "technical_track_analysis"
      },
      "analysis": {
        "contract_version": 2,
        "sections": [
          {
            "id": "rhythm_bpm",
            "value": "126 BPM"
          }
        ],
        "providers": [
          {
            "provider_id": "metabrainz_metadata",
            "display_name": "MusicBrainz / ListenBrainz",
            "status": "skipped",
            "reason": "rate_limited"
          }
        ]
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)
    let provider = try #require(response.analysis?.providers.first)

    #expect(response.analysis?.metadata == nil)
    #expect(response.analysis?.sections.first?.id == "rhythm_bpm")
    #expect(provider.providerID == "metabrainz_metadata")
    #expect(provider.status == "skipped")
    #expect(provider.reason == "rate_limited")
}

@Test func askDJMessageResponseDecodesMetaBrainzProviderErrorWithoutBreakingAnalysis() throws {
    let json = """
    {
      "text": "Analyse met providerfout.",
      "intent": {
        "intent": "technical_track_analysis"
      },
      "analysis": {
        "contract_version": 2,
        "sections": [
          {
            "id": "energy_curve",
            "summary": "Energy still comes from the normal analysis payload."
          }
        ],
        "providers": [
          {
            "provider_id": "metabrainz_metadata",
            "status": "error",
            "reason": "lookup_failed"
          }
        ]
      },
      "playback_actions": []
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)

    #expect(response.analysis?.sections.first?.id == "energy_curve")
    #expect(response.analysis?.providers.first?.providerID == "metabrainz_metadata")
    #expect(response.analysis?.providers.first?.status == "error")
    #expect(response.analysis?.providers.first?.reason == "lookup_failed")
    #expect(response.assistantMessage?.playbackActions.isEmpty == true)
}

@Test func askDJTechnicalTrackAnalysisMetadataContextDoesNotCreateFakeTimelineLabels() throws {
    let json = """
    {
      "text": "Metadata-context beschrijft release-informatie.",
      "intent": {
        "intent": "technical_track_analysis"
      },
      "analysis": {
        "contract_version": 2,
        "sections": [
          {
            "id": "metadata_context",
            "kind": "metadata_context",
            "title": "Open metadata",
            "summary": "Known public metadata mentions intro and club tags, but no measured arrangement was returned.",
            "source": "metabrainz_metadata"
          }
        ],
        "metadata": {
          "musicbrainz_recording_id": "mb-recording-456",
          "tags": ["intro", "club"]
        },
        "sources": ["metabrainz_metadata"]
      },
      "playback_actions": []
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)
    let analysis = try #require(response.analysis)

    #expect(analysis.sections.first?.id == "metadata_context")
    #expect(analysis.metadata?.tags == ["intro", "club"])
    #expect(analysis.timeline.isEmpty)
    #expect(analysis.measured?.sections.isEmpty != false)
    #expect(response.assistantMessage?.playbackActions.isEmpty == true)
}

@Test func askDJMessageResponseDecodesUnknownTechnicalTrackAnalysisProviders() throws {
    let json = """
    {
      "text": "Future provider analysis.",
      "intent": {
        "intent": "technical_track_analysis"
      },
      "analysis": {
        "contract_version": 2,
        "mode": "measured_plus_knowledge",
        "sections": [
          {
            "id": "rhythm_bpm",
            "kind": "technical_metric",
            "title": "Rhythm / BPM",
            "value": "128 BPM"
          }
        ],
        "timeline": [
          {
            "id": "intro",
            "label": "Intro",
            "start_ms": 0
          }
        ],
        "dj_tips": [
          {
            "id": "mix_in",
            "text": "Keep the intro clean."
          }
        ],
        "providers": [
          {
            "provider_id": "future_provider",
            "display_name": "Future provider",
            "status": "warming_up",
            "requires_config": true,
            "reason": "future_reason",
            "ignored_field": "ignored"
          }
        ]
      },
      "playback_actions": []
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)
    let analysis = try #require(response.analysis)

    #expect(analysis.sections.first?.value == "128 BPM")
    #expect(analysis.timeline.first?.label == "Intro")
    #expect(analysis.djTips.first?.text == "Keep the intro clean.")
    #expect(analysis.providers.count == 1)
    #expect(analysis.providers.first?.providerID == "future_provider")
    #expect(analysis.providers.first?.displayName == "Future provider")
    #expect(analysis.providers.first?.status == "warming_up")
    #expect(analysis.providers.first?.requiresConfig == true)
    #expect(analysis.providers.first?.reason == "future_reason")
    #expect(response.assistantMessage?.playbackActions.isEmpty == true)
}

@Test func askDJMessageResponseDecodesUnavailableTechnicalTrackAnalysisV2() throws {
    let json = """
    {
      "text": "Ik kan nu geen track analyseren.",
      "action": "track_analysis",
      "intent": {
        "intent": "technical_track_analysis",
        "action": "track_analysis"
      },
      "analysis": {
        "contract_version": 2,
        "mode": "unavailable",
        "confidence": "low",
        "limitations": [
          "No active Spotify playback context is available."
        ],
        "sources": ["unavailable"],
        "providers": [
          {
            "provider_id": "spotify_measured",
            "status": "skipped",
            "reason": "No active playback context."
          },
          {
            "provider_id": "ha_conversation",
            "status": "skipped",
            "reason": "No track metadata available."
          }
        ]
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)

    #expect(response.analysis?.contractVersion == 2)
    #expect(response.analysis?.mode == "unavailable")
    #expect(response.analysis?.confidence == "low")
    #expect(response.analysis?.sections.isEmpty == true)
    #expect(response.analysis?.limitations.first == "No active Spotify playback context is available.")
    #expect(response.analysis?.providers.allSatisfy { $0.status == "skipped" } == true)
}

@Test func askDJMessageResponseDecodesUnknownTechnicalTrackAnalysisV2Values() throws {
    let json = """
    {
      "text": "Future analysis payload.",
      "intent": {
        "intent": "technical_track_analysis"
      },
      "analysis": {
        "contract_version": 2,
        "sections": [
          {
            "id": "future_section",
            "kind": "spectral_flux",
            "title": "Spectral Flux",
            "value": "Wide",
            "source": "local_fallback",
            "confidence": "low"
          }
        ],
        "timeline": [
          {
            "kind": "mystery_segment",
            "label": "Unknown part",
            "start_ms": 64000,
            "source": "future_source"
          }
        ],
        "dj_tips": [
          {
            "kind": "future_tip",
            "text": "Treat this as a generic tip.",
            "source": "local_fallback"
          }
        ]
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)

    #expect(response.analysis?.sections.first?.id == "future_section")
    #expect(response.analysis?.sections.first?.kind == "spectral_flux")
    #expect(response.analysis?.sections.first?.source == "local_fallback")
    #expect(response.analysis?.timeline.first?.kind == "mystery_segment")
    #expect(response.analysis?.timeline.first?.source == "future_source")
    #expect(response.analysis?.djTips.first?.kind == "future_tip")
}

@Test func askDJMessageResponseWithoutPlaybackActionsDoesNotReusePreviousActions() throws {
    let previous = DJConnectAskDJMessage(
        serverID: "same-server-id",
        role: .dj,
        text: "Previous answer",
        playbackActions: [
            DJConnectAskDJPlaybackAction(title: "Play previous", uri: "spotify:track:previous", kind: "track")
        ]
    )
    let json = """
    {
      "assistant_message": {
        "id": "same-server-id",
        "role": "assistant",
        "text": "Read-only analysis.",
        "intent": {
          "intent": "technical_track_analysis",
          "action": "track_analysis"
        },
        "analysis": {
          "contract_version": 2,
          "mode": "measured",
          "sections": [
            {
              "id": "rhythm_bpm",
              "value": "128 BPM"
            }
          ]
        }
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)
    let message = DJConnectAskDJMessage(
        serverID: response.assistantMessage?.id,
        role: .dj,
        text: response.assistantMessage?.text ?? "",
        playbackActions: response.assistantMessage?.playbackActions ?? [],
        intentInfo: response.assistantMessage?.intentInfo,
        analysis: response.assistantMessage?.analysis
    )

    #expect(previous.playbackActions.count == 1)
    #expect(message.isTechnicalTrackAnalysis)
    #expect(message.playbackActions.isEmpty)
    #expect(message.renderablePlaybackActions.isEmpty)
}

@Test func askDJMessageResponseIgnoresLegacyRecommendationActionAliases() throws {
    let json = """
    {
      "history_revision": 44,
      "clear_revision": 7,
      "assistant_message": {
        "id": "server-assistant-text-only",
        "role": "assistant",
        "text": "Ik heb drie suggesties, maar start niets zonder expliciete actie.",
        "created_at": "2026-06-19T12:35:00Z",
        "recommendation_actions": [
          {
            "id": "legacy-action",
            "title": "Play legacy recommendation",
            "uri": "spotify:track:legacy",
            "kind": "track"
          }
        ]
      },
      "recommendations": [
        {
          "id": "legacy-top-level",
          "title": "Play legacy top-level recommendation",
          "uri": "spotify:track:legacy-top-level",
          "kind": "track"
        }
      ]
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)

    #expect(response.playbackActions == nil)
    #expect(response.assistantMessage?.playbackActions.isEmpty == true)
}

@Test func recentlyPlayedHistoryResponseDecodesItemsWithoutImplicitPlaybackActions() throws {
    let json = """
    {
      "history_revision": 51,
      "clear_revision": 7,
      "intent": {
        "intent": "recently_played_history",
        "item_type": "tracks"
      },
      "items": [
        {
          "kind": "track",
          "title": "Midnight City",
          "subtitle": "M83",
          "uri": "spotify:track:recent",
          "source": "spotify_recently_played"
        }
      ],
      "assistant_message": {
        "id": "recent-history",
        "role": "assistant",
        "text": "Dit draaide je net.",
        "created_at": "2026-06-19T12:35:00Z",
        "items": [
          {
            "kind": "track",
            "title": "Midnight City",
            "subtitle": "M83",
            "source": "spotify_recently_played"
          }
        ]
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: json)

    #expect(response.intentInfo?.intent == "recently_played_history")
    #expect(response.intentInfo?.itemType == "tracks")
    #expect(response.items?.first?.source == "spotify_recently_played")
    #expect(response.assistantMessage?.items.first?.title == "Midnight City")
    #expect(response.playbackActions == nil)
    #expect(response.assistantMessage?.playbackActions.isEmpty == true)
}

@Test func askDJResponseDecodesObjectIntentForTechnicalTrackAnalysis() throws {
    let json = """
    {
      "success": true,
      "dj_text": "Er speelt nu geen track die ik kan analyseren.",
      "action": "track_analysis",
      "intent": {
        "category": "informational",
        "intent": "technical_track_analysis",
        "action": "track_analysis"
      },
      "analysis": {
        "mode": "unavailable",
        "confidence": "low",
        "limitations": ["No current track is available."],
        "sources": ["spotify_playback_context"]
      },
      "playback_actions": []
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DJConnectAskDJResponse.self, from: json)

    #expect(response.success)
    #expect(response.intent == "technical_track_analysis")
    #expect(response.intentInfo?.category == "informational")
    #expect(response.action == "track_analysis")
    #expect(response.analysis?.mode == "unavailable")
    #expect(response.playbackActions?.isEmpty == true)
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
        command: "save_current_track"
    ))
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["client_type"] as? String == "watchos")
    #expect(json?["command"] as? String == "save_current_track")
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
                "memory_key": .string("djconnect_ios_8F3A2C91B45D")
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
                "memory_key": .string("djconnect_watchos_8F3A2C91B45D")
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
                "memory_key": .string("djconnect_ios_8F3A2C91B45D")
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
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)
    model.language = "nl"

    model.apply(commandResponse: DJConnectCommandResponse(
        success: true,
        backendAvailable: true,
        devices: [
            DJConnectOutputDevice(id: "speaker", name: "Woonkamer", active: true)
        ]
    ))

    #expect(model.availableOutputs.map(\.name).prefix(2) == ["Geen", "Woonkamer"])
    #expect(model.selectedOutput == "Woonkamer")

    model.selectOutput(model.availableOutputs[0])
    #expect(model.selectedOutput == "Geen")
    #expect(model.availableOutputs[0].active == true)
    #expect(model.availableOutputs[1].active == false)
}

@MainActor
@Test func appStartsWithNoOutputSelected() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)

    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startLocalAPI: false,
        startBackgroundTasks: false
    )
    model.language = "nl"

    await Task.yield()

    #expect(["Geen", "None"].contains(model.selectedOutput))
}

@MainActor
@Test func storedLanguagePreferenceDoesNotOverrideDeviceLanguage() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set("nl", forKey: "DJConnectLanguage")

    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startLocalAPI: false,
        startBackgroundTasks: false
    )

    #expect(model.language == DJConnectAppModel.normalizedReleaseNotesLanguageCode(Locale.preferredLanguages.first ?? "en"))
}

@MainActor
@Test func noOutputSelectionBlocksPlaybackStartCommands() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"),
        startLocalAPI: false,
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

    #expect(model.selectedOutput == "Geen")
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
                    "artist": "Artist name",
                    "album": "Album name",
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

@MainActor
@Test func emptyBackendQueueClearsRenderedQueueItems() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)

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
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)
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
        queue: Array(repeating: repeatedItem, count: 8)
    ))

    #expect(model.queueItems.count == 1)
    #expect(model.queueItems.first?.title == "Summer Of 69")
    #expect(model.queue == ["Summer Of 69 - Bryan Adams"])
}

@MainActor
@Test func queueEpisodeItemsCanStartWithoutPlaybackContext() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)
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
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)
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
        assistPipelineID: "preferred"
    )

    model.apply(pairingResponse: response, fallbackBaseURL: try #require(URL(string: "http://fallback.local:8123")))

    #expect(model.homeAssistantURL == "http://192.168.1.13:8123")
    #expect(model.haLocalURL == "http://192.168.1.13:8123")
    #expect(model.language == "en")
    #expect(model.assistPipelineID == "preferred")
}

@Test func localPairRequestAcceptsHomeAssistantCallbackPayload() throws {
    let request = try JSONDecoder().decode(
        DJConnectLocalPairRequest.self,
        from: Data(
            """
            {
              "pair_code": 555293,
              "device_id": "djconnect-macos-68B74487726D",
              "device_name": "DJConnect Mac",
              "client_type": "macos",
              "device_language": "nl",
              "language": "nl",
              "device_token": "device-secret",
              "ha_local_url": "http://192.168.1.13:8123",
              "ha_remote_url": "https://remote.ui.nabu.casa",
              "assist_pipeline_id": "preferred"
            }
            """.utf8
        )
    )

    #expect(request.resolvedPairCode == "555293")
    #expect(request.deviceID == "djconnect-macos-68B74487726D")
    #expect(request.clientType == .macos)
    #expect(request.resolvedDeviceToken == "device-secret")
    #expect(request.haLocalURL == "http://192.168.1.13:8123")
    #expect(request.haRemoteURL == "https://remote.ui.nabu.casa")
    #expect(request.assistPipelineID == "preferred")
}

@MainActor
@Test func appDoesNotStartClientHostedLocalAPIForPairing() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let tokenStore = DJConnectInMemoryTokenStore()
    let model = DJConnectAppModel(defaults: defaults, tokenStore: tokenStore, startBackgroundTasks: false)

    try await Task.sleep(for: .milliseconds(150))
    #expect(model.isLocalDeviceAPIRunningForTests == false)
    #expect(model.localDeviceAPIURL == nil)
    #expect(defaults.string(forKey: "DJConnectLocalDeviceAPIURL") == nil)
    #expect(try tokenStore.loadToken() == nil)
    model.stopLocalDeviceAPI()
}

@MainActor
@Test func localDeviceAPIAndBonjourAreInactiveForAppleClients() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    defer { model.stopLocalDeviceAPI() }

    try await Task.sleep(for: .milliseconds(150))
    #expect(model.isLocalDeviceAPIRunningForTests == false)
    #expect(model.isBonjourAdvertisingPreferredForTests == false)
    #expect(model.localDeviceAPIURL == nil)
}

@Test func bonjourTXTRecordIncludesWatchOSDiscoveryContract() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-watchos-8F3A2C91B45D",
        deviceName: "DJConnect Watch",
        clientType: .watchos,
        firmware: "3.1.49",
        appVersion: "3.1.49",
        platform: .watchos
    )
    let info = DJConnectLocalDeviceAPIInfo(
        identity: identity,
        pairingToken: "123456",
        pairingStatus: .pairing
    )
    let txtRecord = DJConnectLocalDeviceAPI.bonjourTXTRecord(
        for: info,
        localURL: "http://192.168.1.105:55805"
    ).mapValues { String(decoding: $0, as: UTF8.self) }

    #expect(txtRecord["device_id"] == "djconnect-watchos-8F3A2C91B45D")
    #expect(txtRecord["device_id"]?.hasPrefix("djconnect-watchos-") == true)
    #expect(txtRecord["client_type"] == "watchos")
    #expect(txtRecord["platform"] == "watchos")
    #expect(txtRecord["pairing_status"] == "pairing")
    #expect(txtRecord["paired"] == "false")
    #expect(txtRecord["pair_code"] == "123456")
    #expect(txtRecord["pairing_code"] == "123456")
    #expect(txtRecord["pairing_token"] == "123456")
    #expect(txtRecord["local_url"] == "http://192.168.1.105:55805")
    #expect(txtRecord["path"] == "/api/device/info")
    #expect(txtRecord["pairing_path"] == "/api/device/pairing-info")
    #expect(txtRecord["pair_path"] == "/api/device/pair")
}

@Test func bonjourTXTRecordIncludesIOSDiscoveryContract() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.49",
        appVersion: "3.1.49",
        platform: .ios
    )
    let info = DJConnectLocalDeviceAPIInfo(
        identity: identity,
        pairingToken: "654321",
        pairingStatus: .unpaired
    )
    let txtRecord = DJConnectLocalDeviceAPI.bonjourTXTRecord(
        for: info,
        localURL: "http://192.168.1.106:55806"
    ).mapValues { String(decoding: $0, as: UTF8.self) }

    #expect(txtRecord["device_id"] == "djconnect-ios-8F3A2C91B45D")
    #expect(txtRecord["device_id"]?.hasPrefix("djconnect-ios-") == true)
    #expect(txtRecord["client_type"] == "ios")
    #expect(txtRecord["platform"] == "ios")
    #expect(txtRecord["pairing_status"] == "unpaired")
    #expect(txtRecord["paired"] == "false")
    #expect(txtRecord["pair_code"] == "654321")
    #expect(txtRecord["local_url"] == "http://192.168.1.106:55806")
}

@MainActor
@Test func bonjourAdvertisingIsDisabledForAppleClients() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)

    #expect(!model.isBonjourAdvertisingPreferredForTests)

    model.dismissWelcome()
    #expect(!model.isBonjourAdvertisingPreferredForTests)

    model.startDemoMode()
    #expect(!model.isBonjourAdvertisingPreferredForTests)

    model.stopDemoMode()
    #expect(!model.isBonjourAdvertisingPreferredForTests)

    model.pairingStatus = DJConnectPairingStatus.paired
    #expect(!model.isBonjourAdvertisingPreferredForTests)

    model.pairingStatus = DJConnectPairingStatus.unpaired
    #expect(!model.isBonjourAdvertisingPreferredForTests)
}

@MainActor
@Test func appLifecycleTracksForegroundStateForBatterySensitiveWork() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)

    #expect(model.isAppInForegroundForTests)

    model.markInactiveSession()
    #expect(!model.isAppInForegroundForTests)

    model.markActiveSession()
    #expect(model.isAppInForegroundForTests)
}

@MainActor
@Test func appLifecycleKeepsClientHostedLocalAPIOff() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: true, startBackgroundTasks: false)
    defer { model.stopLocalDeviceAPI() }

    #expect(!model.isLocalDeviceAPIRunningForTests)

    model.markInactiveSession()
    #expect(!model.isLocalDeviceAPIRunningForTests)

    model.markActiveSession()
    #expect(!model.isLocalDeviceAPIRunningForTests)
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
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"), startLocalAPI: false, startBackgroundTasks: false)

    let export = model.diagnosticExportText()

    #expect(export.contains("bearer_token: present"))
    #expect(export.contains("bundle_id:"))
    #expect(export.contains("locale:"))
    #expect(export.contains("app_store_review_demo_available: true"))
    #expect(export.contains("ha_connection_mode: offline"))
    #expect(export.contains("playback_features_enabled:"))
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
        startLocalAPI: false,
        startBackgroundTasks: false,
        diagnosticLogDirectory: logDirectory
    )

    let logFile = logDirectory.appendingPathComponent("djconnect.log")
    let persisted = try String(contentsOf: logFile, encoding: .utf8)
    #expect(persisted.contains("App started without DJConnect bearer token"))

    let relaunched = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startLocalAPI: false,
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
        startLocalAPI: false,
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
        startLocalAPI: false,
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
        memoryKey: "djconnect-watchos-8F3A2C91B45D"
    )

    #expect(request.url?.path == "/api/djconnect/v1/voice")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "audio/wav")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-ID") == identity.deviceID)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-Name") == identity.deviceName)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-Type") == "ios")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Mood") == "100")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-DJ-Style") == "warm_radio_dj")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Memory-Key") == "djconnect-watchos-8F3A2C91B45D")
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
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)

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
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false)
    model.language = "nl"

    model.apply(localDJResponse: DJConnectLocalDJResponseRequest(
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
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false)
    model.language = "nl"

    model.apply(localDJResponse: DJConnectLocalDJResponseRequest(
        text: "Player command failed. No active device found",
        djText: nil,
        audioURL: nil,
        audioType: nil
    ))

    #expect(model.djResponseText == "Geen actief afspeelapparaat gevonden")
}

@MainActor
@Test func djAnnouncementSuppressesHTMLBackendErrorPages() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false)
    model.language = "nl"

    model.apply(localDJResponse: DJConnectLocalDJResponseRequest(
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
        startLocalAPI: false,
        startBackgroundTasks: false
    )
    model.language = "nl"

    model.apply(localDJResponse: DJConnectLocalDJResponseRequest(
        text: "Spotify authorization has expired or was revoked.",
        djText: nil,
        audioURL: nil,
        audioType: nil
    ))
    #expect(model.djResponseText == "Ververs Spotify koppeling in Home Assistant")

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
        startLocalAPI: false,
        startBackgroundTasks: false
    )

    model.djResponseText = "Nog bezig met praten"
    model.startVoiceRecording()

    #expect(model.djResponseText.isEmpty)
}

@MainActor
@Test func welcomeScreenIsShownOncePerInstall() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)

    let firstLaunch = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)
    #expect(firstLaunch.isShowingWelcome == true)

    firstLaunch.dismissWelcome()
    #expect(firstLaunch.isShowingWelcome == false)

    let secondLaunch = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)
    #expect(secondLaunch.isShowingWelcome == false)
}

@MainActor
@Test func whatsNewDoesNotAppearOnFirstInstall() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)

    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)

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

    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)

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

    #expect(iosURL.absoluteString == "https://djconnect.dev/release-notes/ios/v3.1.20.json")
    #expect(macURL.absoluteString == "https://djconnect.dev/release-notes/macos/v3.1.20.json")
    #expect(iosDutchURL.absoluteString == "https://djconnect.dev/release-notes/ios/nl/v3.1.20.json")
    #expect(macEnglishURL.absoluteString == "https://djconnect.dev/release-notes/macos/en/v3.1.20.json")
    #expect(DJConnectAppModel.normalizedReleaseNotesLanguageCode("nl-NL") == "nl")
    #expect(DJConnectAppModel.normalizedReleaseNotesLanguageCode("de") == "en")
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

    let firstLaunch = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)
    #expect(firstLaunch.isShowingCrashReportPrompt == false)
    firstLaunch.markActiveSession()

    let secondLaunch = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)
    #expect(secondLaunch.isShowingCrashReportPrompt == true)
    #expect(secondLaunch.crashIssueURL()?.host == "github.com")
    #expect(secondLaunch.crashIssueURL()?.path == "/pcvantol/djconnect/issues/new")

    secondLaunch.dismissCrashReportPrompt()
    let thirdLaunch = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)
    #expect(thirdLaunch.isShowingCrashReportPrompt == false)
}

@MainActor
@Test func wakeWordPromptAppearsAfterFreshPairingWhenDisabled() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)

    model.pairingStatus = .paired
    model.presentWakeWordActivationPromptAfterPairing()
    #expect(model.isShowingWakeWordActivationPrompt == false)

    model.completePairingScreen()

    #expect(model.isShowingWakeWordActivationPrompt == true)
}

@MainActor
@Test func wakeWordPromptDismissalIsRememberedUntilPairingReset() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)

    model.pairingStatus = .paired
    model.presentWakeWordActivationPromptAfterPairing()
    model.completePairingScreen()
    model.dismissWakeWordActivationPrompt()
    model.presentWakeWordActivationPromptAfterPairing()

    #expect(model.isShowingWakeWordActivationPrompt == false)

    model.resetPairing()
    model.pairingStatus = .paired
    model.presentWakeWordActivationPromptAfterPairing()
    model.completePairingScreen()

    #expect(model.isShowingWakeWordActivationPrompt == true)
}

@MainActor
@Test func wakeWordPromptActivationEnablesWakeWord() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)

    model.pairingStatus = .paired
    model.presentWakeWordActivationPromptAfterPairing()
    model.completePairingScreen()
    model.activateWakeWordFromPrompt()

    #expect(model.isShowingWakeWordActivationPrompt == false)
    #expect(model.wakeWordEnabled == true)
}

@MainActor
@Test func pairingScreenBlocksUnpairedRuntimeUntilPairingSucceeds() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)

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
        startLocalAPI: false,
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
        startLocalAPI: false,
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
        startLocalAPI: false,
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
@Test func monkeyTestingModeStartsSafeLocalDemoWithoutPairingOrLocalAPI() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(
        defaults: defaults,
        tokenStore: DJConnectInMemoryTokenStore(),
        startLocalAPI: true,
        startBackgroundTasks: true,
        monkeyTestingMode: true
    )

    #expect(model.isMonkeyTestingMode == true)
    #expect(model.isDemoMode == true)
    #expect(model.shouldShowPairingScreen == false)
    #expect(model.isShowingWelcome == false)
    #expect(model.isShowingCrashReportPrompt == false)
    #expect(model.localDeviceAPIURL == nil)
    #expect(model.canUsePlaybackFeatures == true)
    #expect(model.playback?.trackName == "Midnight City")
    #expect(model.queueItems.isEmpty == false)
    #expect(model.playlistItems.isEmpty == false)
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
        memoryKey: "djconnect-watchos-ABC123"
    )
    let request = DJConnectWatchProxyRequest(operation: .voice, payload: try JSONEncoder().encode(payload))
    let decodedRequest = try JSONDecoder().decode(DJConnectWatchProxyRequest.self, from: JSONEncoder().encode(request))
    let decodedPayload = try JSONDecoder().decode(DJConnectWatchProxyVoicePayload.self, from: try #require(decodedRequest.payload))

    #expect(decodedRequest.operation == .voice)
    #expect(decodedPayload.wavData == Data([0x52, 0x49, 0x46, 0x46]))
    #expect(decodedPayload.mood == 70)
    #expect(decodedPayload.djStyle == "warm_radio_dj")
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
