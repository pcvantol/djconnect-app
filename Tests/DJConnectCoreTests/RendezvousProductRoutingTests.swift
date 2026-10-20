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
