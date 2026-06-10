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
@Test func resetPairingRotatesLocalIdentityAndCode() throws {
    let suiteName = "DJConnectTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set("manual-code", forKey: "DJConnectPairingToken")
    let tokenStore = DJConnectInMemoryTokenStore(token: "secret-token")
    let model = DJConnectAppModel(defaults: defaults, tokenStore: tokenStore)
    let originalDeviceID = model.identity.deviceID
    let originalPairingToken = model.pairingToken

    model.resetPairing()

    #expect(model.identity.deviceID != originalDeviceID)
    #expect(model.identity.deviceID.hasPrefix("djconnect-"))
    #expect(model.pairingToken != originalPairingToken)
    #expect(try tokenStore.loadToken() == nil)
}

@Test func statusRequestIncludesContractFieldsAndHeaders() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.0",
        appVersion: "3.1.0",
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
        haRemoteURL: "https://example.ui.nabu.casa",
        haActiveURL: "http://192.168.1.10:8123"
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
    #expect(json?["firmware"] as? String == "3.1.0")
    #expect(json?["app_version"] as? String == "3.1.0")
    #expect(json?["ha_local_url"] as? String == "http://192.168.1.10:8123")
    #expect(json?["ha_remote_url"] as? String == "https://example.ui.nabu.casa")
    #expect(json?["ha_active_url"] as? String == "http://192.168.1.10:8123")
}

@Test func commandRequestSupportsTypedValues() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-macos-8F3A2C91B45D",
        deviceName: "DJConnect Mac",
        clientType: .macos,
        firmware: "3.1.0",
        appVersion: "3.1.0",
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
                  {"uri":"spotify:track:1","title":"Track One","artist":"Artist One"},
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
    #expect(response.playlists?.map(\.commandValue) == ["spotify:playlist:1", "Liked Proxy"])
}

@Test func pairingRequestUsesPairEndpointWithoutBearerToken() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-macos-8F3A2C91B45D",
        deviceName: "DJConnect Mac",
        clientType: .macos,
        firmware: "3.1.0",
        appVersion: "3.1.0",
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
    #expect(json?["firmware"] as? String == "3.1.0")
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
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore())
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
        language: "en"
    )

    model.apply(pairingResponse: response, fallbackBaseURL: try #require(URL(string: "http://fallback.local:8123")))

    #expect(model.homeAssistantURL == "http://192.168.1.13:8123")
    #expect(model.haLocalURL == "http://192.168.1.13:8123")
    #expect(model.haRemoteURL == "https://remote.ui.nabu.casa")
    #expect(model.haActiveURL == "http://192.168.1.13:8123")
    #expect(model.language == "nl")
}

@Test func pairSuccessStoresReturnedBearerToken() async throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.1.0",
        appVersion: "3.1.0",
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
        firmware: "3.1.0",
        appVersion: "3.1.0",
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
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(token: "secret-token"))

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
        firmware: "3.1.0",
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
            firmware: "3.1.0",
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
          "ha_version": "3.1.0",
          "ha_major_minor": "3.1",
          "firmware": "3.1.0",
          "firmware_major_minor": "3.0"
        }
        """.utf8
    )

    let error = client.classify(statusCode: 426, body: body)

    #expect(error == .versionMismatch(
        DJConnectVersionMismatch(
            message: "DJConnect Home Assistant integration and device firmware major.minor versions must match.",
            haVersion: "3.1.0",
            haMajorMinor: "3.1",
            firmware: "3.1.0",
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
            firmware: "3.1.0",
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
            firmware: "3.1.0",
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
