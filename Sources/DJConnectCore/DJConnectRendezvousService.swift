import Foundation
import CryptoKit

public struct DJConnectRendezvousBrowserKey: Equatable, Sendable {
    public let modulus: Data
    public let thumbprint: String
    static func parse(_ data: Data, for qr: DJConnectRendezvousQR) throws -> Self {
        let value = try RendezvousFlatJSON.parse(data, maximumBytes: 4096)
        guard Set(value.keys) == ["v", "transaction_id", "browser_public_key", "browser_key_thumbprint", "generation", "expires_at"],
              value["v"] == .string("djc-rendezvous/1"),
              value["transaction_id"] == .string(qr.transactionID),
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
    public enum Failure: Error, Sendable { case retryAfter(notBeforeMS: Int64) }
    /// Server pacing can only delay an explicit retry. Malformed pacing on a
    /// rejection closes this repair window; it never grants an earlier attempt.
    static func retryNotBefore(_ header: String?, status: Int, at now: Int64) -> Int64? {
        guard [429, 503].contains(status), let header else { return nil }
        let value = header.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }),
           let seconds = Int64(value), seconds <= 31 * 86_400 {
            return now + seconds * 1000
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"; formatter.isLenient = false
        if let date = formatter.date(from: value), date.timeIntervalSince1970.isFinite,
           date.timeIntervalSince1970 <= Double(now) / 1000 + 31 * 86_400 {
            return max(now, Int64(date.timeIntervalSince1970 * 1000))
        }
        return now + 86_400_000
    }

    private let session: URLSession
    private let taskCreated:(@MainActor @Sendable (URLSessionDataTask)->Void)?
    public convenience init() { self.init(configuration:.ephemeral) }
    // Module-internal configuration seam for isolated qualification URLProtocol.
    // Product callers have only the fixed-origin, ephemeral public initializer.
    init(configuration:URLSessionConfiguration, taskCreated:(@MainActor @Sendable (URLSessionDataTask)->Void)? = nil) {
        self.taskCreated = taskCreated
        configuration.urlCache = nil; configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil; configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 8; configuration.timeoutIntervalForResource = 8
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration, delegate: RendezvousRedirectGuard(), delegateQueue: nil)
    }
    deinit { session.invalidateAndCancel() }
    public func inspect(_ qr: DJConnectRendezvousQR) async throws -> DJConnectRendezvousBrowserKey {
        guard qr.isCurrent() else { throw DJConnectRendezvousQR.Failure.expired }
        let body = try JSONSerialization.data(withJSONObject: ["v": "djc-rendezvous/1",
            "transaction_id": qr.transactionID, "generation": qr.generation, "qr_capability": qr.capability])
        let data = try await post(path:"inspect",body:body,status:200,qr:qr)
        return try DJConnectRendezvousBrowserKey.parse(data, for: qr)
    }
    public func registrationChallenge(keyID:String, qr:DJConnectRendezvousQR) async throws -> DJConnectRendezvousEnrollmentChallenge {
        guard DJConnectRendezvousSubmitChallenge.canonicalKeyID(keyID) else { throw DJConnectError.invalidResponse }
        let requested = Int64(Date().timeIntervalSince1970 * 1000), up = ProcessInfo.processInfo.systemUptime
        let body = try JSONSerialization.data(withJSONObject:["v":"djc-rendezvous/1","key_id":keyID,"action":"register"])
        let data = try await post(path:"attestation/challenge",body:body,status:200,qr:qr)
        return try .parse(data,requestedAtMS:requested,requestedUptime:up)
    }
    public func register(originalBody:Data, qr:DJConnectRendezvousQR) async throws -> Int64 {
        try await register(originalBody:originalBody,qr:qr,beforeDispatch:{})
    }
    // The enrollment coordinator rechecks owner/challenge authority after the
    // executor hop, immediately before the fixed-origin transport dispatch.
    func register(originalBody:Data,qr:DJConnectRendezvousQR,
                  beforeDispatch:@escaping @MainActor @Sendable () throws -> Void,
                  isResponseCurrent:@escaping @Sendable () -> Bool = {true}) async throws -> Int64 {
        guard originalBody.count <= 65536 else { throw DJConnectError.invalidResponse }
        let data = try await post(path:"attestation/register",body:originalBody,status:201,qr:qr,
                                  beforeDispatch:beforeDispatch,bodyCurrent:isResponseCurrent)
        let fields = try RendezvousFlatJSON.parse(data,maximumBytes:4096)
        guard Set(fields.keys) == ["v","key_expires_at"], fields["v"] == .string("djc-rendezvous/1"),
              case let .integer(expiry)? = fields["key_expires_at"], expiry > Int64(Date().timeIntervalSince1970 * 1000) else { throw DJConnectError.invalidResponse }
        return expiry
    }
    public func submitChallenge(qr:DJConnectRendezvousQR,keyID:String,envelope:DJConnectRendezvousDestination.Envelope) async throws -> DJConnectRendezvousSubmitChallenge {
        guard DJConnectRendezvousSubmitChallenge.canonicalKeyID(keyID) else { throw DJConnectError.invalidResponse }
        let requested = Int64(Date().timeIntervalSince1970 * 1000), up = ProcessInfo.processInfo.systemUptime
        let body = try JSONSerialization.data(withJSONObject:["v":"djc-rendezvous/1","transaction_id":qr.transactionID,
            "generation":qr.generation,"qr_capability":qr.capability,"key_id":keyID,"envelope_digest":envelope.digest])
        let data = try await post(path:"submit-challenge",body:body,status:200,qr:qr)
        return try .parse(data,qr:qr,keyID:keyID,envelopeDigest:envelope.digest,requestedAtMS:requested,requestedUptime:up)
    }
    public func submit(originalBody:Data, qr:DJConnectRendezvousQR, challenge:DJConnectRendezvousSubmitChallenge) async throws {
        try await submit(originalBody:originalBody,qr:qr,challenge:challenge,beforeDispatch:{})
    }
    func submit(originalBody:Data, qr:DJConnectRendezvousQR, challenge:DJConnectRendezvousSubmitChallenge,
                beforeDispatch:@escaping @MainActor @Sendable () throws -> Void) async throws {
        guard originalBody.count <= 32768, challenge.isCurrent() else { throw DJConnectError.invalidResponse }
        let data = try await post(path:"submit",body:originalBody,status:202,qr:qr,beforeDispatch:{
            try beforeDispatch()
            guard challenge.isCurrent() else { throw DJConnectError.invalidResponse }
        },bodyCurrent:{challenge.isCurrent()})
        let fields = try RendezvousFlatJSON.parse(data,maximumBytes:4096)
        guard Set(fields.keys) == ["v","accepted","operation_id"], fields["v"] == .string("djc-rendezvous/1"),
              fields["accepted"] == .bool(true), fields["operation_id"] == .string(challenge.identifier),
              challenge.isCurrent() else { throw DJConnectError.invalidResponse }
    }
    /// Management recovery is independent of a scanned browser transaction.
    /// The caller must already hold the full per-key queue and explicit budget.
    @MainActor func recoveryChallenge(keyID: String,
        isCurrent: @escaping @MainActor @Sendable () -> Bool) async throws -> DJConnectRendezvousRecoveryChallenge {
        try Task.checkCancellation()
        guard isCurrent(), DJConnectRendezvousSubmitChallenge.canonicalKeyID(keyID) else { throw DJConnectError.invalidResponse }
        let clock = RendezvousManagementRequestClock()
        let body = try JSONSerialization.data(withJSONObject: ["v": "djc-rendezvous/1", "key_id": keyID, "action": "recover-key"])
        let data = try await fixedPost(path: "attestation/challenge", body: body, status: 200,
            beforeDispatch: {
                guard isCurrent(), clock.isCurrent() else { throw DJConnectError.invalidResponse }
            }, bodyCurrent: { clock.isCurrent() })
        guard isCurrent() else { throw DJConnectError.invalidResponse }
        return try .parse(data, keyIdentifier: keyID, requestedAtMS: clock.requestedAtMS,
                          requestedUptime: clock.requestedUptime)
    }

    @MainActor func recover(originalBody: Data, challenge: DJConnectRendezvousRecoveryChallenge,
        expectedOriginalExpiryMS: Int64?, isCurrent: @escaping @MainActor @Sendable () -> Bool) async throws -> Int64 {
        try Task.checkCancellation()
        guard isCurrent(), challenge.isCurrent(), originalBody.count <= 16_384 else { throw DJConnectError.invalidResponse }
        let fields = try RendezvousFlatJSON.parse(originalBody, maximumBytes: 16_384)
        let original = Self.base64URL(challenge.originalClientData)
        guard Set(fields.keys) == ["v", "key_id", "challenge_id", "client_data", "assertion"],
              fields["v"] == .string("djc-rendezvous/1"), fields["key_id"] == .string(challenge.keyIdentifier),
              fields["challenge_id"] == .string(challenge.identifier), fields["client_data"] == .string(original),
              case let .string(proof)? = fields["assertion"], Self.isBoundedAssertion(proof) else { throw DJConnectError.invalidResponse }
        let data = try await fixedPost(path: "attestation/recover", body: originalBody, status: 200,
            beforeDispatch: {
                guard isCurrent(), challenge.isCurrent() else { throw DJConnectError.invalidResponse }
            }, bodyCurrent: { challenge.isCurrent() })
        guard isCurrent(), challenge.isCurrent() else { throw DJConnectError.invalidResponse }
        let receipt = try RendezvousFlatJSON.parse(data, maximumBytes: 4096)
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        guard Set(receipt.keys) == ["v", "key_expires_at"], receipt["v"] == .string("djc-rendezvous/1"),
              case let .integer(expiry)? = receipt["key_expires_at"], expiry > now,
              expiry - now <= 30 * 86_400_000,
              expectedOriginalExpiryMS.map({ $0 == expiry }) ?? true else { throw DJConnectError.invalidResponse }
        return expiry
    }
    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    private static func isBoundedAssertion(_ encoded: String) -> Bool {
        guard !encoded.isEmpty, encoded.utf8.count <= 5462,
              encoded.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }) else { return false }
        let text = encoded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: text + String(repeating: "=", count: (4 - text.count % 4) % 4)) else { return false }
        return !data.isEmpty && data.count <= 4096 && base64URL(data) == encoded
    }
    @MainActor private func post(path:String,body:Data,status:Int,qr:DJConnectRendezvousQR,
                      beforeDispatch:(@MainActor @Sendable () throws -> Void)? = nil,
                      bodyCurrent:(@Sendable ()->Bool)? = nil) async throws -> Data {
        try Task.checkCancellation()
        guard qr.isCurrent() else { throw DJConnectRendezvousQR.Failure.expired }
        return try await fixedPost(path: path, body: body, status: status, beforeDispatch: {
            try beforeDispatch?()
            guard qr.isCurrent() else { throw DJConnectRendezvousQR.Failure.expired }
        }, bodyCurrent: { qr.isCurrent() && (bodyCurrent?() ?? true) })
    }

    @MainActor private func fixedPost(path: String, body: Data, status: Int,
        beforeDispatch: @escaping @MainActor @Sendable () throws -> Void,
        bodyCurrent: @escaping @Sendable () -> Bool) async throws -> Data {
        try Task.checkCancellation()
        guard bodyCurrent() else { throw DJConnectError.invalidResponse }
        let url = URL(string:DJConnectRendezvousQR.serviceOrigin + "/v1/rendezvous/" + path)!
        var request = URLRequest(url:url)
        request.httpMethod = "POST"; request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.setValue("application/json",forHTTPHeaderField:"Accept")
        request.setValue("identity",forHTTPHeaderField:"Accept-Encoding")
        request.httpBody = body
        let response = try await DJConnectBoundedHTTPTransport.send(request,using:session,maximumBytes:4096,
            beforeDispatch: beforeDispatch, isBodyCurrent: bodyCurrent, taskCreated:taskCreated,validateResponse:{ http in
                if let until = Self.retryNotBefore(http.value(forHTTPHeaderField: "Retry-After"), status: http.statusCode,
                                                  at: Int64(Date().timeIntervalSince1970 * 1000)) {
                    throw Failure.retryAfter(notBeforeMS: until)
                }
                guard http.statusCode == status,http.mimeType?.lowercased() == "application/json",
                      http.value(forHTTPHeaderField:"Content-Encoding") == nil else { throw DJConnectError.invalidResponse }
                return "application/json"
            })
        return response.data
    }
}

/// Local management request upper bound. Never reconstructed from a newer QR.
private struct RendezvousManagementRequestClock: Sendable {
    let requestedAtMS = Int64(Date().timeIntervalSince1970 * 1000)
    let requestedUptime = ProcessInfo.processInfo.systemUptime
    func isCurrent() -> Bool {
        let now = Int64(Date().timeIntervalSince1970 * 1000), uptime = ProcessInfo.processInfo.systemUptime
        return now >= requestedAtMS && now - requestedAtMS < 120_000
            && uptime.isFinite && uptime >= requestedUptime && uptime - requestedUptime < 120
    }
}
