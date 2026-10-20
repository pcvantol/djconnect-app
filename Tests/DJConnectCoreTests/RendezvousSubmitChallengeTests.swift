import Foundation
import CryptoKit
import Testing
@testable import DJConnectCore

@Test func rendezvousSubmitChallengeBindsEveryCapturedFieldAndOriginalBytes() throws {
    func b64(_ data:Data)->String { data.base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"") }
    let token = String(repeating:"A",count:43), key = Data(repeating:0,count:32).base64EncodedString()
    let qrObject: [String:Any] = ["type":"djc-rendezvous-qr","v":"djc-rendezvous/1","service_origin":DJConnectRendezvousQR.serviceOrigin,
        "transaction_id":"00000000-0000-4000-8000-000000000001","generation":1,"expires_at":121000,
        "browser_key_thumbprint":token,"qr_capability":token]
    let qr = try DJConnectRendezvousQR.parse(String(decoding:JSONSerialization.data(withJSONObject:qrObject),as:UTF8.self),at:1000,uptime:10)
    let fields: [String:Any] = ["v":"djc-rendezvous/1","action":"submit","service_origin":DJConnectRendezvousQR.serviceOrigin,
        "transaction_id":qr.transactionID,"generation":1,"browser_key_thumbprint":token,
        "expires_at":120000,"key_id":key,"challenge_id":token,"challenge":token,"envelope_digest":token]
    func response(_ original:Data)->Data {
        try! JSONSerialization.data(withJSONObject:["v":"djc-rendezvous/1","challenge_id":token,"challenge":token,"expires_at":120000,"client_data":b64(original)])
    }
    func parse(_ data:Data) throws -> DJConnectRendezvousSubmitChallenge {
        try .parse(data,qr:qr,keyID:key,envelopeDigest:token,requestedAtMS:1100,requestedUptime:10.1,nowMS:2000,uptime:11)
    }
    let original = try JSONSerialization.data(withJSONObject:fields,options:.sortedKeys)
    let admitted = try parse(response(original))
    #expect(admitted.originalClientData == b64(original))
    #expect(admitted.clientDataHash == Data(SHA256.hash(data:original)))
    #expect(admitted.isCurrent(at:2001,uptime:11.1))
    #expect(!admitted.isCurrent(at:1999,uptime:11.1))
    #expect(!admitted.isCurrent(at:2001,uptime:129.1))
    #expect(!admitted.isCurrent(at:2001,uptime:10))
    for name in fields.keys {
        var changed = fields
        changed[name] = name == "generation" || name == "expires_at" ? 2 : "changed"
        let data = try JSONSerialization.data(withJSONObject:changed)
        #expect(throws:(any Error).self) { try parse(response(data)) }
    }
    let spaced = Data((" \n"+String(decoding:original,as:UTF8.self)+"\t").utf8)
    let other = try parse(response(spaced))
    #expect(other.clientDataHash != admitted.clientDataHash)
    #expect(other.clientDataHash == Data(SHA256.hash(data:spaced)))
    let duplicate = Data(String(decoding:original,as:UTF8.self).replacingOccurrences(of:"\"action\":\"submit\"",with:"\"action\":\"submit\",\"act\\u0069on\":\"submit\"").utf8)
    #expect(throws:(any Error).self) { try parse(response(duplicate)) }
    #expect(DJConnectRendezvousSubmitChallenge.canonicalKeyID(key))
    #expect(!DJConnectRendezvousSubmitChallenge.canonicalKeyID(token))
}
