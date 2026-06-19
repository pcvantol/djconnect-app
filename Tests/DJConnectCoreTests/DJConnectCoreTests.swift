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
    var platform: String
    var localURL: String
    var pairCode: String?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientType = "client_type"
        case platform
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
@Test func pairingAuthStaleStopsPollingWithCodeMismatchMessage() throws {
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

    #expect(model.pairingStatus == .stale)
    #expect(model.isPairing == false)
    #expect(model.isTerminalPairingError(.authStale(statusCode: 401, message: nil)))
    #expect(model.pairingMessage?.contains("De app-code klopt niet.") == true)
    #expect(model.pairingMessage?.contains("The pairing code does not match") == false)
}

@MainActor
@Test func authStaleClearsTokenAndReEnablesBonjourPairing() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
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
    #expect(model.isBonjourAdvertisingPreferredForTests == true)
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

    #expect(request.url?.path == "/api/djconnect/status")
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

    #expect(request.url?.path == "/api/djconnect/command")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-ID") == nil)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(json?["client_id"] == nil)
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["client_type"] as? String == "macos")
    #expect(json?["command"] as? String == "set_volume")
    #expect(json?["value"] as? Int == 35)
    #expect(json?["play"] as? Bool == true)
}

@Test func askDJRequestUsesAskEndpointAndMemoryContext() throws {
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
        memoryKey: "djconnect_ios_8F3A2C91B45D"
    ))
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/ask")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["client_type"] as? String == "ios")
    #expect(json?["text"] as? String == "Speel iets rustigers")
    #expect(json?["mood"] as? Int == 20)
    #expect(json?["dj_style"] as? String == "warm_radio_dj")
    #expect(json?["memory_key"] as? String == "djconnect_ios_8F3A2C91B45D")
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
        djStyle: "warm_radio_dj",
        memoryKey: "djconnect_ios_8F3A2C91B45D",
        audioResponse: .auto
    ))
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/ask_dj/message")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(json?["client_message_id"] as? String == "client-message-1")
    #expect(json?["input_type"] as? String == "text")
    #expect(json?["text"] as? String == "Verras me met nieuwe muziek")
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

    #expect(request.url?.path == "/api/djconnect/ask_dj/history/clear")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["client_type"] as? String == "ios")
    #expect(json?["memory_key"] as? String == "djconnect_ios_8F3A2C91B45D")
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

    #expect(request.url?.path == "/api/djconnect/ask_dj/idle_suggestion")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(json?["client_message_id"] as? String == "idle-suggestion-1")
    #expect(json?["client_type"] as? String == "watchos")
    #expect(json?["mood"] as? Int == 72)
    #expect(json?["dj_style"] as? String == "warm_radio_dj")
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
          "role": "user",
          "text": "Welke albums bracht deze artiest uit?",
          "created_at": "2026-06-19T12:34:56Z",
          "client_id": "iphone_peter",
          "client_type": "ios",
          "status": "delivered"
        },
        {
          "id": "server-assistant-message-id",
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
    #expect(userMessage.role == .user)
    #expect(userMessage.messageKind == .assistant)
    #expect(userMessage.origin == nil)
    #expect(userMessage.clientType == .ios)
    #expect(assistantMessage.role == .assistant)
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

        #expect(request.url?.path == "/api/djconnect/command")
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

    #expect(request.url?.path == "/api/djconnect/pair")
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
@Test func localPairingKeepsClientAPIURLStable() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let tokenStore = DJConnectInMemoryTokenStore()
    let model = DJConnectAppModel(defaults: defaults, tokenStore: tokenStore, startBackgroundTasks: false)
    let clientAPIURL = try await waitForLocalDeviceAPIURL(model)
    let advertisedURL = try #require(URL(string: clientAPIURL))
    let advertisedPort = try #require(advertisedURL.port)
    let pairURL = try #require(URL(string: "http://127.0.0.1:\(advertisedPort)/api/device/pair"))
    var request = URLRequest(url: pairURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data(
        """
        {
          "pair_code": "\(model.pairingToken)",
          "device_id": "\(model.identity.deviceID)",
          "device_name": "\(model.identity.deviceName)",
          "client_type": "\(model.identity.clientType.rawValue)",
          "device_language": "nl",
          "device_token": "device-secret",
          "ha_local_url": "http://192.168.1.13:8123"
        }
        """.utf8
    )

    let (_, response) = try await URLSession.shared.data(for: request)
    let httpResponse = try #require(response as? HTTPURLResponse)
    try await Task.sleep(for: .milliseconds(150))

    #expect(httpResponse.statusCode == 200)
    #expect(try tokenStore.loadToken() == "device-secret")
    #expect(model.localDeviceAPIURL == clientAPIURL)
    #expect(defaults.string(forKey: "DJConnectLocalDeviceAPIURL") == clientAPIURL)
    model.stopLocalDeviceAPI()
}

@MainActor
@Test func localDeviceAPIAdvertisesLANURLAndServesDeviceJSON() async throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    defer { model.stopLocalDeviceAPI() }

    let lanBaseURL = try await waitForLocalDeviceAPIURL(model)
    let lanURL = try #require(URL(string: lanBaseURL))
    let port = try #require(lanURL.port)
    let loopbackBaseURL = "http://127.0.0.1:\(port)"

    #expect(lanURL.host != "127.0.0.1")
    #expect(lanURL.host != "localhost")

    let shouldRunLANProbe = ProcessInfo.processInfo.environment["DJCONNECT_RUN_LAN_LOCAL_API_TEST"] == "1"
    for path in ["/api/device/pairing-info", "/api/device/info"] {
        let loopbackPayload = try await localDeviceJSON(from: "\(loopbackBaseURL)\(path)")

        #expect(loopbackPayload.deviceID == model.identity.deviceID)
        #expect(loopbackPayload.clientType == model.identity.clientType.rawValue)
        #expect(loopbackPayload.platform == model.identity.platform.rawValue)
        #expect(loopbackPayload.localURL == lanBaseURL)
        if path == "/api/device/pairing-info" {
            #expect(loopbackPayload.pairCode == model.pairingToken)
        }

        if shouldRunLANProbe {
            let lanPayload: LocalDeviceJSON
            do {
                lanPayload = try await localDeviceJSON(from: "\(lanBaseURL)\(path)")
            } catch {
                Issue.record("LAN local device API request failed for \(path): \(error)\n\(model.diagnosticExportText())")
                throw error
            }
            #expect(lanPayload.deviceID == loopbackPayload.deviceID)
            #expect(lanPayload.clientType == loopbackPayload.clientType)
            #expect(lanPayload.platform == loopbackPayload.platform)
            #expect(lanPayload.localURL == lanBaseURL)
        }
    }
}

@MainActor
@Test func bonjourAdvertisingIsOnlyPreferredWhilePairable() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)

    #expect(model.isBonjourAdvertisingPreferredForTests)

    model.startDemoMode()
    #expect(!model.isBonjourAdvertisingPreferredForTests)

    model.stopDemoMode()
    #expect(model.isBonjourAdvertisingPreferredForTests)

    model.pairingStatus = DJConnectPairingStatus.paired
    #expect(!model.isBonjourAdvertisingPreferredForTests)

    model.pairingStatus = DJConnectPairingStatus.unpaired
    #expect(model.isBonjourAdvertisingPreferredForTests)
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
@Test func iOSLifecyclePausesLocalDeviceAPIInBackground() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: true, startBackgroundTasks: false)
    defer { model.stopLocalDeviceAPI() }

    #expect(model.isLocalDeviceAPIRunningForTests)

    model.markInactiveSession()
    #if os(iOS)
    #expect(!model.isLocalDeviceAPIRunningForTests)
    #else
    #expect(model.isLocalDeviceAPIRunningForTests)
    #endif

    model.markActiveSession()
    #expect(model.isLocalDeviceAPIRunningForTests)
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
        #expect(request.url?.path == "/api/djconnect/pair")
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

    #expect(request.url?.path == "/api/djconnect/voice")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "audio/wav")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-ID") == nil)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
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
        #expect(endpoint == "POST /api/djconnect/command")
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
        #expect(endpoint == "POST /api/djconnect/command")
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

    model.emitUserConnectionNotice(for: .decodingFailed(statusCode: 200, endpoint: "POST /api/djconnect/command", message: "bad shape"))
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
    #expect(updateMessage.contains("3.1.x"))
    #expect(updateMessage.contains(">=3.1.0"))
    #expect(updateMessage.contains("<3.2.0"))
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
        haVersion: "3.1.99",
        playback: DJConnectPlayback(trackName: "Compatible Track")
    ))

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
