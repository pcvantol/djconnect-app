import Foundation
import CryptoKit
import Security
import JOSESwift
import Testing
@testable import DJConnectCore

@Test func rendezvousDestinationUsesStandardJOSEAndOnlyTrustedRouteFields() throws {
    #expect(DJConnectThirdPartyNotices.joseSwiftLicense.contains("TERMS AND CONDITIONS FOR USE"))
    var failure: Unmanaged<CFError>?
    let privateKey = try #require(SecKeyCreateRandomKey([kSecAttrKeyType:kSecAttrKeyTypeRSA,
        kSecAttrKeySizeInBits:2048,kSecAttrIsPermanent:false] as CFDictionary,&failure))
    let publicKey = try #require(SecKeyCopyPublicKey(privateKey))
    let jwk = try RSAPublicKey(publicKey:publicKey)
    let thumbprint = try jwk.thumbprint(algorithm:.SHA256)
    let expiry = Int64(Date().timeIntervalSince1970 * 1000)+120000
    let qrObject: [String:Any] = ["type":"djc-rendezvous-qr","v":"djc-rendezvous/1","service_origin":DJConnectRendezvousQR.serviceOrigin,
        "transaction_id":"00000000-0000-4000-8000-000000000001","generation":1,"expires_at":expiry,
        "browser_key_thumbprint":thumbprint,"qr_capability":String(repeating:"A",count:43)]
    let qr = try DJConnectRendezvousQR.parse(String(decoding:JSONSerialization.data(withJSONObject:qrObject),as:UTF8.self))
    let response: [String:Any] = ["v":"djc-rendezvous/1","browser_public_key":["kty":"RSA","n":jwk.modulus,"e":"AQAB"],
        "browser_key_thumbprint":thumbprint,"generation":1,"expires_at":expiry]
    let browserKey = try DJConnectRendezvousBrowserKey.parse(JSONSerialization.data(withJSONObject:response),for:qr)
    let owner = try JSONDecoder().decode(DJConnectDisplayOwnerContext.self,from:JSONSerialization.data(withJSONObject:[
        "success":true,"contract_version":1,"display_entry_url":"https://ha.example.com/djconnect/vibecast/display",
        "route_trust":"paired_owner_response","issuer_epoch":String(repeating:"A",count:43)]))
    let first = try DJConnectRendezvousDestination.encrypt(qr:qr,browserKey:browserKey,owner:owner)
    let second = try DJConnectRendezvousDestination.encrypt(qr:qr,browserKey:browserKey,owner:owner)
    #expect(first.compact != second.compact)
    let decrypter = try #require(Decrypter(keyManagementAlgorithm:.RSAOAEP256,contentEncryptionAlgorithm:.A256GCM,decryptionKey:privateKey))
    let decoded = try JWE(compactSerialization:first.compact).decrypt(using:decrypter).data()
    let fields = try #require(JSONSerialization.jsonObject(with:decoded) as? [String:Any])
    #expect(Set(fields.keys) == ["v","transaction_id","generation","browser_key_thumbprint","expires_at","bootstrap_origin","display_entry_url","issuer_epoch"])
    #expect(fields["display_entry_url"] as? String == owner.displayEntryURL)
    #expect(fields["bootstrap_origin"] as? String == "https://vibecast.tv")
    #expect((fields["expires_at"] as? NSNumber)?.int64Value == expiry)
    let header = try JWE(compactSerialization:first.compact).header
    #expect(header.typ == "djc-rendezvous-destination+jwe")
    #expect(header.kid == thumbprint)
    let digest = Data(SHA256.hash(data:Data(first.compact.utf8))).base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")
    #expect(first.digest == digest)
}
