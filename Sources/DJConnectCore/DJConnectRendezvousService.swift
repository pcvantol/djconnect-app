import Foundation
import CryptoKit

public struct DJConnectRendezvousBrowserKey: Equatable, Sendable {
    public let modulus: Data
    public let thumbprint: String
    static func parse(_ data: Data, for qr: DJConnectRendezvousQR) throws -> Self {
        let value = try RendezvousFlatJSON.parse(data, maximumBytes: 4096)
        guard Set(value.keys) == ["v", "browser_public_key", "browser_key_thumbprint", "generation", "expires_at"],
              value["v"] == .string("djc-rendezvous/1"),
              value["browser_key_thumbprint"] == .string(qr.browserKeyThumbprint),
              value["generation"] == .integer(qr.generation), value["expires_at"] == .integer(qr.expiresAtMS),
              case let .object(jwk)? = value["browser_public_key"], Set(jwk.keys) == ["kty", "n", "e"],
              jwk["kty"] == .string("RSA"), jwk["e"] == .string("AQAB"),
              case let .string(n)? = jwk["n"], n.utf8.count == 342,
              let modulus = Data(base64Encoded: n.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") + "=="),
              modulus.count == 256, modulus.first.map({ $0 & 0x80 != 0 }) == true,
              modulus.last.map({ $0 & 1 == 1 }) == true,
              encode(modulus) == n else { throw DJConnectError.invalidResponse }
        // RFC7638 canonical RSA JWK member order and exact JSON bytes.
        let canonical = Data("{\"e\":\"AQAB\",\"kty\":\"RSA\",\"n\":\"\(n)\"}".utf8)
        guard encode(Data(SHA256.hash(data: canonical))) == qr.browserKeyThumbprint else { throw DJConnectError.invalidResponse }
        return .init(modulus: modulus, thumbprint: qr.browserKeyThumbprint)
    }
    private static func encode(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

private final class RendezvousRedirectGuard: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}

/// Fixed-origin public service. Never receives HA tokens, identity or Profile
/// headers. No redirects, cookies, cache, transport retries or background tasks.
public final class DJConnectRendezvousService: Sendable {
    private let session: URLSession
    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil; configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil; configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 8; configuration.timeoutIntervalForResource = 8
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration, delegate: RendezvousRedirectGuard(), delegateQueue: nil)
    }
    deinit { session.invalidateAndCancel() }
    public func inspect(_ qr: DJConnectRendezvousQR) async throws -> DJConnectRendezvousBrowserKey {
        guard qr.isCurrent() else { throw DJConnectRendezvousQR.Failure.expired }
        let url = URL(string: DJConnectRendezvousQR.serviceOrigin + "/v1/rendezvous/inspect")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["v": "djc-rendezvous/1",
            "transaction_id": qr.transactionID, "generation": qr.generation, "qr_capability": qr.capability])
        let (bytes, response) = try await session.bytes(for: request)
        defer { bytes.task.cancel() }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, http.url == url,
              http.mimeType?.lowercased() == "application/json", http.expectedContentLength <= 4096 else { throw DJConnectError.invalidResponse }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < 4096, qr.isCurrent() else { throw DJConnectError.invalidResponse }
            data.append(byte)
        }
        try Task.checkCancellation()
        guard qr.isCurrent(), http.expectedContentLength < 0 || http.expectedContentLength == data.count else { throw DJConnectError.invalidResponse }
        return try DJConnectRendezvousBrowserKey.parse(data, for: qr)
    }
}
