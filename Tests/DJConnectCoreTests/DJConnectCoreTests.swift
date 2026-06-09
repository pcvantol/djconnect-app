import Foundation
import Testing
@testable import DJConnectCore

@Test func statusRequestIncludesContractFieldsAndHeaders() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.0.0",
        appVersion: "3.0.0",
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
        logLevel: "info"
    )

    let request = try client.statusRequest(payload)
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

    #expect(request.url?.path == "/api/djconnect/status")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["client_type"] as? String == "ios")
    #expect(json?["firmware"] as? String == "3.0.0")
    #expect(json?["app_version"] as? String == "3.0.0")
}

@Test func commandRequestSupportsTypedValues() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-macos-8F3A2C91B45D",
        deviceName: "DJConnect Mac",
        clientType: .macos,
        firmware: "3.0.0",
        appVersion: "3.0.0",
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
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["client_type"] as? String == "macos")
    #expect(json?["command"] as? String == "set_volume")
    #expect(json?["value"] as? Int == 35)
    #expect(json?["play"] as? Bool == true)
}

@Test func pairingRequestUsesPairEndpointWithoutBearerToken() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-macos-8F3A2C91B45D",
        deviceName: "DJConnect Mac",
        clientType: .macos,
        firmware: "3.0.0",
        appVersion: "3.0.0",
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
    #expect(request.value(forHTTPHeaderField: "X-DJConnect-Device-ID") == identity.deviceID)
    #expect(json?["device_id"] as? String == identity.deviceID)
    #expect(json?["client_type"] as? String == "macos")
    #expect(json?["pairing_token"] as? String == "123456")
    #expect(json?["firmware"] as? String == "3.0.0")
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

@Test func voiceRequestUsesRawWavContentType() throws {
    let identity = DJConnectIdentity(
        deviceID: "djconnect-ios-8F3A2C91B45D",
        deviceName: "DJConnect iPhone",
        clientType: .ios,
        firmware: "3.0.0",
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
    #expect(request.httpBody == wav)
}

@Test func versionMismatchIsClassifiedWithoutClearingPairing() throws {
    let client = DJConnectClient(
        baseURL: try #require(URL(string: "http://homeassistant.local:8123")),
        identity: DJConnectIdentity(
            deviceID: "djconnect-ios-8F3A2C91B45D",
            deviceName: "DJConnect iPhone",
            clientType: .ios,
            firmware: "3.0.0",
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
          "firmware": "3.0.0",
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
            firmware: "3.0.0",
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
            firmware: "3.0.0",
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
