import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

@MainActor @Test func rendezvousProductQRDoesNotUnpairAndUnsupportedDoesNotSend() async throws {
    let suite = "djc-rendezvous-product-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName:suite))
    defer { defaults.removePersistentDomain(forName:suite) }
    let model = DJConnectAppModel(defaults:defaults, tokenStore:DJConnectInMemoryTokenStore(), startBackgroundTasks:false)
    model.pairingStatus = .paired
    let expiry = Int64(Date().timeIntervalSince1970 * 1000) + 120000
    let object: [String:Any] = ["type":"djc-rendezvous-qr", "v":"djc-rendezvous/1", "service_origin":DJConnectRendezvousQR.serviceOrigin,
        "transaction_id":"00000000-0000-4000-8000-000000000001", "generation":1, "expires_at":expiry,
        "browser_key_thumbprint":String(repeating:"A",count:43), "qr_capability":String(repeating:"A",count:43)]
    let qr = String(decoding:try JSONSerialization.data(withJSONObject:object),as:UTF8.self)
    #expect(!model.handlePairingQRCode(qr)) // false means no HA-pairing confirmation
    #expect(model.pairingStatus == .paired)
    #expect(model.rendezvousHasQR)
    #expect(model.isShowingRendezvous)
    #if os(macOS)
    #expect(!model.rendezvousAttestationSupported)
    await model.prepareRendezvousDestination()
    #expect(model.rendezvousStatusKey == "ui.rendezvous.unsupported")
    #expect(!model.rendezvousBusy)
    #endif
    _ = model.handlePairingQRCode("{invalid}")
    #expect(model.pairingStatus == .paired)
    #expect(!model.rendezvousHasQR)
    #expect(model.rendezvousStatusKey == "ui.rendezvous.invalid")
    _ = model.handlePairingQRCode(qr)
    let previousURL = model.homeAssistantURL
    model.homeAssistantURL = "https://other.example.com"
    model.homeAssistantURL = previousURL
    #expect(!model.rendezvousHasQR) // ABA cannot resurrect the scanned capability
    _ = model.handlePairingQRCode(qr)
    model.markInactiveSession()
    #expect(!model.rendezvousHasQR)
    _ = model.handlePairingQRCode(qr)
    model.pairingStatus = .unpaired
    #expect(!model.rendezvousHasQR)
}

private final class NativeConsentRejectionWire: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var count = 0
    static func reset() { lock.withLock { count = 0 } }
    static var requests: Int { lock.withLock { count } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.withLock { Self.count += 1 }
        client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
    }
    override func stopLoading() {}
}
@MainActor @Test func nativeDisplayConsentNeverDispatchesWithoutCurrentSession() async throws {
    let suite = "djc-native-consent-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [NativeConsentRejectionWire.self]
    NativeConsentRejectionWire.reset()
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-owner"),
        urlSession: URLSession(configuration: configuration), startBackgroundTasks: false)
    model.homeAssistantURL = "https://ha.example.com"
    for paired in [false, true] {
        model.pairingStatus = paired ? .paired : .unpaired
        model.resetDisplayConsent()
        #expect(model.displayConsentState == .idle && !model.canResolveDisplayConsent)
        await model.resolveDisplayConsent(code: "000000")
        await model.approveDisplayConsent()
        #expect(model.displayConsentState == .unavailable)
        #expect(NativeConsentRejectionWire.requests == 0)
    }
    model.markInactiveSession()
    await model.resolveDisplayConsent(code: "000000")
    #expect(!model.canResolveDisplayConsent && NativeConsentRejectionWire.requests == 0)
}
