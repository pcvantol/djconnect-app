import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

@Test @MainActor func sessionTransportRecoveryDoesNotHideConfirmedHTTPConnection() {
    var hybrid = DJConnectHybridDiagnostics()
    for state in [DJConnectHybridDiagnostics.State.recoveringOffline, .localDegraded] {
        hybrid.state = state
        #expect(DJConnectAppModel.resolvedConnectionMode(statusMode: .remote, hybrid: hybrid) == .remote)
        #expect(DJConnectAppModel.resolvedConnectionMode(statusMode: .local, hybrid: hybrid) == .local)
        #expect(DJConnectAppModel.resolvedConnectionMode(statusMode: .offline, hybrid: hybrid) == .offline)
    }
    hybrid.state = .terminalAuthorityWithdrawn
    #expect(DJConnectAppModel.resolvedConnectionMode(statusMode: .local, hybrid: hybrid) == .offline)
    hybrid.state = .remoteReady
    #expect(DJConnectAppModel.resolvedConnectionMode(statusMode: .local, hybrid: hybrid) == .remote)
}

@Test func statusUsesBoundedLANReadAndLongerExternalRead() throws {
    let identity = DJConnectIdentity(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Test",
        clientType: .ios, firmware: "4.0.0", appVersion: "4.0.0", platform: .ios)
    let payload = DJConnectStatusPayload(identity: identity, haPairingStatus: .paired,
        language: "nl", logLevel: "info", appBuild: "40238", localAudioSupported: true, voiceSupported: true)
    for (origin, deadline) in [("http://192.168.1.134:8123", 2.0), ("https://remote.example", 8.0), ("https://ha.local", 2.0)] {
        let client = DJConnectClient(baseURL: URL(string: origin)!, identity: identity,
            tokenStore: DJConnectInMemoryTokenStore(token: "test-token"))
        #expect(try client.statusRequest(payload).timeoutInterval == deadline)
    }
}

@Test func publicProxyArtworkFollowsConfirmedRouteWithoutRetargetingProvidersOrOwnerGrants() throws {
    let local = URL(string: "http://192.168.1.134:8123")!
    let remote = URL(string: "https://paired.example")!
    let known = [local, remote]
    let proxy = URL(string: "http://192.168.1.134:8123/api/djconnect/v1/image_proxy/fixture?size=300")!
    let external = try #require(DJConnectArtworkRoute.resolve(proxy, knownOrigins: known, preferredOrigin: remote))
    #expect(external.absoluteString == "https://paired.example/api/djconnect/v1/image_proxy/fixture?size=300")
    #expect(DJConnectArtworkRoute.resolve(external, knownOrigins: known, preferredOrigin: local) == proxy)
    let relative = URL(string: "/api/djconnect/v1/image_proxy/fixture")!
    #expect(DJConnectArtworkRoute.resolve(relative, knownOrigins: known, preferredOrigin: remote)?.host == remote.host)
    for value in ["https://cdn.example/cover.jpg", "https://unknown.example/api/djconnect/v1/image_proxy/fixture",
                  "http://192.168.1.134:8123/api/djconnect/v1/session/media/image/owner/asset",
                  "https://paired.example/api/djconnect/v1/session/surface/image/session/asset"] {
        let url = URL(string: value)!
        #expect(DJConnectArtworkRoute.resolve(url, knownOrigins: known, preferredOrigin: remote) == url)
    }
    #expect(DJConnectArtworkRoute.resolve(URL(string: "//unknown.example/cover"), knownOrigins: known, preferredOrigin: remote) == nil)
    #expect(DJConnectArtworkRoute.resolve(URL(string: "https://secret@paired.example/cover"), knownOrigins: known, preferredOrigin: remote) == nil)
}
