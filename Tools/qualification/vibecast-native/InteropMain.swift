import Foundation
import JOSESwift

// Bounded stdio software-test adapter. No private key is ever serialized/exported.
@main struct InteropMain {
    static func main() throws {
        let key = try DestinationJOSE.key(), jwk = try DestinationJOSE.publicJWK(key)
        func output(_ object: [String: Any]) throws {
            FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) + Data([10]))
        }
        try output(["jwk": jwk.requiredParameters, "thumbprint": try jwk.thumbprint(algorithm: .SHA256)])
        for _ in 0..<64 {
            guard let line = readLine(), line.utf8.count <= 16384 else { return }
            do {
                let input = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
                guard let input, let mode = input["mode"] as? String else { throw BindingFailure.rejected }
                if mode == "encrypt", let publicObject = input["jwk"] as? [String: Any], let encoded = input["plaintext"] as? String,
                   let plaintext = Data(base64Encoded: encoded) {
                    let recipient = try RSAPublicKey(data: JSONSerialization.data(withJSONObject: publicObject))
                    try output(["envelope": try DestinationJOSE.encrypt(plaintext, to: recipient)])
                } else if mode == "decrypt", let envelope = input["envelope"] as? String,
                          let encoded = input["expected"] as? String, let expected = Data(base64Encoded: encoded), let now = input["now"] as? Int64 {
                    try output(["plaintext": try DestinationJOSE.decrypt(envelope, with: key, expected: expected, nowMS: now).base64EncodedString()])
                } else { throw BindingFailure.rejected }
            } catch { try output(["rejected": true]) }
        }
    }
}
