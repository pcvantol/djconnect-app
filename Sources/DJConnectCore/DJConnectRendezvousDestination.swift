import Foundation
import CryptoKit
import Security
import JOSESwift

/// Standard JOSE implementation, pinned to the independently qualified library
/// revision. Only a current paired-owner destination and QR-admitted browser key
/// enter plaintext. HA credentials and identity never enter the envelope.
public enum DJConnectRendezvousDestination {
    public struct Envelope: Sendable {
        public let compact: String
        public let digest: String
    }
    public static func encrypt(qr: DJConnectRendezvousQR, browserKey: DJConnectRendezvousBrowserKey,
                               owner: DJConnectDisplayOwnerContext) throws -> Envelope {
        guard qr.isCurrent(), owner.isAdmissible, browserKey.thumbprint == qr.browserKeyThumbprint else { throw DJConnectError.invalidResponse }
        let plaintext = try JSONSerialization.data(withJSONObject: ["v":"djc-rendezvous/1",
            "transaction_id":qr.transactionID, "generation":qr.generation,
            "browser_key_thumbprint":qr.browserKeyThumbprint, "expires_at":qr.expiresAtMS,
            "bootstrap_origin":"https://vibecast.tv", "display_entry_url":owner.displayEntryURL,
            "issuer_epoch":owner.issuerEpoch], options:.sortedKeys)
        guard plaintext.count <= 2048 else { throw DJConnectError.invalidResponse }
        let jwk = RSAPublicKey(modulus: encode(browserKey.modulus), exponent: "AQAB")
        guard try jwk.thumbprint(algorithm:.SHA256) == qr.browserKeyThumbprint else { throw DJConnectError.invalidResponse }
        let key: SecKey = try jwk.converted(to:SecKey.self)
        var header = JWEHeader(keyManagementAlgorithm:.RSAOAEP256, contentEncryptionAlgorithm:.A256GCM)
        header.typ = "djc-rendezvous-destination+jwe"; header.kid = qr.browserKeyThumbprint
        guard let encrypter = Encrypter(keyManagementAlgorithm:.RSAOAEP256, contentEncryptionAlgorithm:.A256GCM, encryptionKey:key) else { throw DJConnectError.invalidResponse }
        let compact = try JWE(header:header, payload:Payload(plaintext), encrypter:encrypter).compactSerializedString
        guard compact.utf8.count <= 8192, qr.isCurrent() else { throw DJConnectError.invalidResponse }
        return Envelope(compact:compact, digest:encode(Data(SHA256.hash(data:Data(compact.utf8)))))
    }
    private static func encode(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")
    }
}
