import Foundation
import CryptoKit
import Testing
@testable import DJConnectCore

@Test func rendezvousInspectBindsExactBrowserKeyGenerationAndOriginalDeadline() throws {
    func b64(_ data: Data) -> String { data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
    // Synthetic RSA-shaped modulus; no private key or real browser authority.
    var bytes = Data(repeating: 0x41, count: 256); bytes[0] = 0xC1
    let n = b64(bytes)
    let canonical = Data("{\"e\":\"AQAB\",\"kty\":\"RSA\",\"n\":\"\(n)\"}".utf8)
    let thumbprint = b64(Data(SHA256.hash(data: canonical)))
    let qrObject: [String: Any] = ["type":"djc-rendezvous-qr", "v":"djc-rendezvous/1", "service_origin":DJConnectRendezvousQR.serviceOrigin,
        "transaction_id":"00000000-0000-4000-8000-000000000001", "generation":1, "expires_at":121000,
        "browser_key_thumbprint":thumbprint, "qr_capability":String(repeating:"A",count:43)]
    let qr = try DJConnectRendezvousQR.parse(String(decoding: JSONSerialization.data(withJSONObject: qrObject), as: UTF8.self), at:1000, uptime:10)
    let response: [String: Any] = ["v":"djc-rendezvous/1", "transaction_id":qr.transactionID, "browser_public_key":["kty":"RSA", "n":n, "e":"AQAB"], "browser_key_thumbprint":thumbprint,
        "generation":1, "expires_at":121000]
    let data = try JSONSerialization.data(withJSONObject: response, options:.sortedKeys)
    #expect(try DJConnectRendezvousBrowserKey.parse(data, for:qr).modulus == bytes)
    let text = String(decoding:data,as:UTF8.self)
    for bad in [text.replacingOccurrences(of:"\"transaction_id\":\"\(qr.transactionID)\",",with:""),
                text.replacingOccurrences(of:"\"v\":",with:"\"unexpected\":0,\"v\":"),
                text.replacingOccurrences(of:qr.transactionID,with:"00000000-0000-4000-8000-000000000002"),
                text.replacingOccurrences(of:"\"generation\":1",with:"\"generation\":2"),
                text.replacingOccurrences(of:"121000",with:"121001"),
                text.replacingOccurrences(of:"AQAB",with:"Aw"),
                text.replacingOccurrences(of:"\"kty\":\"RSA\"",with:"\"kty\":\"RSA\",\"kt\\u0079\":\"RSA\""),
                text.replacingOccurrences(of:n,with:String(n.dropLast())+"B")] {
        #expect(throws: (any Error).self) { try DJConnectRendezvousBrowserKey.parse(Data(bad.utf8),for:qr) }
    }
}
