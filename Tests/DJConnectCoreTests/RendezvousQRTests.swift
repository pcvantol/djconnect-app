import Foundation
import Testing
@testable import DJConnectCore

private let rendezvousQRFixture = #"{"type":"djc-rendezvous-qr","v":"djc-rendezvous/1","service_origin":"https://api.djconnect.dev","transaction_id":"00000000-0000-4000-8000-000000000001","generation":1,"expires_at":121000,"browser_key_thumbprint":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","qr_capability":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}"#

@Test func rendezvousQRPreservesOriginalWallAndMonotonicExpiry() throws {
    let value = try DJConnectRendezvousQR.parse(rendezvousQRFixture, at: 1000, uptime: 10)
    #expect(value.isCurrent(at: 1001, uptime: 11))
    #expect(value.originalMonotonicDeadline == 130)
    #expect(!value.isCurrent(at: 121000, uptime: 11))
    #expect(!value.isCurrent(at: 999, uptime: 11))
    #expect(!value.isCurrent(at: 1001, uptime: 130))
    #expect(!value.isCurrent(at: 1001, uptime: 9))
    #expect(!value.description.contains(value.capability))
    #expect(throws: DJConnectRendezvousQR.Failure.self) { try DJConnectRendezvousQR.parse(rendezvousQRFixture, at: 999, uptime: 10) }
}

@Test(arguments: [
    ("00000000-0000-4000-8000-000000000001", "00000000-0000-4000-8000-000000000001\\n"),
    ("\"generation\":1", "\"generation\":true"),
    ("\"generation\":1", "\"generation\":1.0"),
    ("\"generation\":1", "\"generation\":01"),
    ("\"generation\":1", "\"generation\":2147483648"),
    ("\"generation\":1", "\"generation\":0"),
    ("\"generation\":1", "\"generation\":1,\"generat\\u0069on\":1"),
    ("https://api.djconnect.dev", "https://api.djconnect.dev.evil.test"),
    ("https://api.djconnect.dev", "https://api.djconnect.dev/"),
    ("\"expires_at\":121000", "\"expires_at\":9007199254740992"),
    ("\"expires_at\":121000", "\"expires_at\":1000"),
    ("\"qr_capability\":\"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\"", "\"qr_capability\":\"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB\""),
    ("\"generation\":1", "\"generation\":1,\"url\":\"https://evil.test\"")
])
func rendezvousQRRejectsMalformedOrAmbiguousFields(change: (String, String)) {
    let bad = rendezvousQRFixture.replacingOccurrences(of: change.0, with: change.1)
    #expect(throws: DJConnectRendezvousQR.Failure.self) { try DJConnectRendezvousQR.parse(bad, at: 1000, uptime: 10) }
}

@Test func rendezvousQRRejectsFramingAndDoesNotActAsDeepLink() {
    for bad in [rendezvousQRFixture + "{}", "https://vibecast.tv/#" + rendezvousQRFixture,
                String(repeating: " ", count: 1025) + rendezvousQRFixture,
                rendezvousQRFixture.replacingOccurrences(of: "\"generation\":1", with: "\"generation\":{}"),
                rendezvousQRFixture.replacingOccurrences(of: "djc-rendezvous-qr", with: "pairing") ] {
        #expect(throws: DJConnectRendezvousQR.Failure.self) { try DJConnectRendezvousQR.parse(bad, at: 1000, uptime: 10) }
    }
}
