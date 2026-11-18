import Foundation
import Security
import JOSESwift

// Test-only profile oracle. Trusted expected plaintext is supplied by the isolated
// harness, never by QR/network input. This is not an HA route/owner validator.
enum DestinationJOSE {
    static func key() throws -> SecKey {
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey([kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: 2048, kSecAttrIsPermanent: false] as CFDictionary, &error) else { throw BindingFailure.rejected }
        return key
    }
    static func publicJWK(_ key: SecKey) throws -> RSAPublicKey {
        guard let publicKey = SecKeyCopyPublicKey(key) else { throw BindingFailure.rejected }
        return try RSAPublicKey(publicKey: publicKey)
    }
    static func encrypt(_ plaintext: Data, to jwk: RSAPublicKey) throws -> String {
        let key: SecKey = try jwk.converted(to: SecKey.self)
        let kid = try jwk.thumbprint(algorithm: .SHA256)
        var header = JWEHeader(keyManagementAlgorithm: .RSAOAEP256, contentEncryptionAlgorithm: .A256GCM)
        header.typ = "djc-rendezvous-destination+jwe"; header.kid = kid
        guard let encrypter = Encrypter(keyManagementAlgorithm: .RSAOAEP256, contentEncryptionAlgorithm: .A256GCM, encryptionKey: key) else { throw BindingFailure.rejected }
        return try JWE(header: header, payload: Payload(plaintext), encrypter: encrypter).compactSerializedString
    }
    static func decrypt(_ envelope: String, with key: SecKey, expected: Data, nowMS: Int64) throws -> Data {
        guard envelope.utf8.count <= 8192, envelope.utf8.allSatisfy({ $0 < 128 }) else { throw BindingFailure.rejected }
        let segments = envelope.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 5 else { throw BindingFailure.rejected }
        let data = try segments.map { segment -> Data in
            let text = String(segment)
            guard !text.isEmpty, text.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { throw BindingFailure.rejected }
            let padded = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") + String(repeating: "=", count: (4 - text.count % 4) % 4)
            guard let bytes = Data(base64Encoded: padded), base64url(bytes) == text else { throw BindingFailure.rejected }
            return bytes
        }
        guard data[1].count == 256, data[2].count == 12, data[3].count <= 2048, data[4].count == 16 else { throw BindingFailure.rejected }
        let kid = try publicJWK(key).thumbprint(algorithm: .SHA256)
        guard try FlatObject.parse(data[0]) == ["alg": .string("RSA-OAEP-256"), "enc": .string("A256GCM"),
            "typ": .string("djc-rendezvous-destination+jwe"), "kid": .string(kid)] else { throw BindingFailure.rejected }
        guard let decrypter = Decrypter(keyManagementAlgorithm: .RSAOAEP256, contentEncryptionAlgorithm: .A256GCM, decryptionKey: key) else { throw BindingFailure.rejected }
        let plaintext = try JWE(compactSerialization: envelope).decrypt(using: decrypter).data()
        let fields = try FlatObject.parse(expected)
        guard case .integer(let expiry) = fields["expires_at"], nowMS >= 0, nowMS < expiry,
              try FlatObject.parse(plaintext) == fields else { throw BindingFailure.rejected }
        return plaintext
    }
}
