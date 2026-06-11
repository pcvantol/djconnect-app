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
    #expect(model.pairingMessage?.contains("Vul de app-code die hier staat opnieuw in Home Assistant in.") == true)
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
        localURL: "http://192.168.1.105:51193"
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
                  {"id":"playlist-1","name":"Warmup","uri":"spotify:playlist:1"},
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
    #expect(response.playlists?.map(\.commandValue) == ["spotify:playlist:1", "Liked Proxy"])
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
@Test func pairingResponseStoresHALocalURLAndLanguage() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false, startBackgroundTasks: false)
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
    #expect(model.language == "nl")
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
    let pairURL = try #require(URL(string: "\(clientAPIURL)/api/device/pair"))
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

    let request = try client.voiceRequest(wavData: wav)

    #expect(request.url?.path == "/api/djconnect/voice")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "audio/wav")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-ID") == nil)
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
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

@MainActor
@Test func djAnnouncementExtractsMessageFromServerJSON() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startLocalAPI: false)

    model.apply(localDJResponse: DJConnectLocalDJResponseRequest(
        text: #"Spotify API failed HTTP 400: {"error":{"status":400,"message":"Can't have offset for context type: ARTIST"}}"#,
        djText: nil,
        audioURL: nil,
        audioType: nil
    ))

    #expect(model.djResponseText == "Can't have offset for context type: ARTIST")
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

    #expect(model.updateRequiredMessage == "Werk de DJConnect Home Assistant-integratie bij naar 3.1.x (>=3.1.0, <3.2.0).")
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
