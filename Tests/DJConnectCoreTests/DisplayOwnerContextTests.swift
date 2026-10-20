import Foundation
import Testing
@testable import DJConnectCore

private func ownerContext(_ url: String, trust: String = "paired_owner_response", epoch: String = String(repeating: "A", count: 43)) throws -> DJConnectDisplayOwnerContext {
    let data = try JSONSerialization.data(withJSONObject: ["success": true, "contract_version": 1,
        "display_entry_url": url, "route_trust": trust, "issuer_epoch": epoch,
        "session_id": NSNull(), "limits": ["claim_seconds": 120]])
    return try JSONDecoder().decode(DJConnectDisplayOwnerContext.self, from: data)
}
@Test func rendezvousOwnerRouteRequiresFreshPairedOwnerContract() throws {
    #expect(try ownerContext("https://ha.example.com/djconnect/vibecast/display").isAdmissible)
    #expect(try !ownerContext("https://ha.example.com/djconnect/vibecast/display", trust: "qr").isAdmissible)
    #expect(try !ownerContext("https://ha.example.com/djconnect/vibecast/display", epoch: "old").isAdmissible)
}
@Test(arguments: ["http://ha.example.com/djconnect/vibecast/display", "https://ha.example.com:443/djconnect/vibecast/display",
    "https://user:password@ha.example.com/djconnect/vibecast/display", "https://127.0.0.1/djconnect/vibecast/display",
    "https://ha.local/djconnect/vibecast/display", "https://ha.example.com/djconnect/vibecast/display?token=x",
    "https://ha.example.com/djconnect/vibecast/display#x", "https://ha.example.com/djconnect/vibecast/%64isplay",
    "https://ha.example.com/djconnect/vibecast/display/", "https://xn--ha-9ia.example/djconnect/vibecast/display"])
func rendezvousOwnerRouteRejectsUntrustedDestinations(url: String) throws {
    #expect(try !ownerContext(url).isAdmissible)
}
