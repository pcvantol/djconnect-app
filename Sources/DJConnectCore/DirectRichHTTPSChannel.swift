import Foundation

/// Fixed paired-HTTPS transport only. Received bytes are not permission, a
/// clock mapping or a native target. The owning runtime must retain its actual
/// pre-await capture and validate the original response before publication.
@MainActor final class DirectRichHTTPSChannel {
    struct Reply: Sendable { let bytes: Data; let mime: String }
    /// Actual shipping-session object custody, never decoded from metadata.
    /// Even this witness supplies transport only, not native clock permission.
    @MainActor final class ReceivingContext {
        private weak var channel: DirectRichHTTPSChannel?
        fileprivate init(channel: DirectRichHTTPSChannel) { self.channel = channel }
        var isLive: Bool { channel != nil }
        var pairedOrigin: URL? { channel?.origin }
    }
    private(set) var receivingContext: ReceivingContext?
    private let origin: URL
    private let session: URLSession

    init(pairedHTTPSOrigin: URL) throws {
        origin = try Self.checkedOrigin(pairedHTTPSOrigin)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil; configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil; configuration.httpAdditionalHeaders = [:]
        configuration.timeoutIntervalForRequest = 15; configuration.timeoutIntervalForResource = 20
        // No session delegate/custom trust handler: Foundation validates the
        // real TLS chain and hostname. Per-task redirect rejection is shared.
        session = URLSession(configuration: configuration)
        receivingContext = ReceivingContext(channel: self)
    }

    /// Test transport injection remains internal, separate from runtime owner
    /// admission. It cannot manufacture a qualified original response/permit.
    init(testOrigin: URL, testSession: URLSession) throws {
        origin = try Self.checkedOrigin(testOrigin); session = testSession
        receivingContext = nil // Synthetic transport cannot mint this witness.
    }

    deinit { session.invalidateAndCancel() }

    private static func checkedOrigin(_ url: URL) throws -> URL {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "https", let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil, components.query == nil,
              components.fragment == nil, ["", "/"].contains(components.percentEncodedPath),
              components.port == nil || (1...65535).contains(components.port!) else { throw DJConnectError.invalidResponse }
        return url
    }

    func send(_ intention: DirectRichRequest, credential: String,
              beforeDispatch: @escaping @MainActor @Sendable () throws -> Void,
              isCurrent: @escaping @Sendable () -> Bool,
              onServerError: (@MainActor @Sendable (DirectRichServerError) -> Void)? = nil) async throws -> Reply {
        try Task.checkCancellation()
        guard isCurrent(), Self.credential(credential, matches: intention.operation) else { throw DJConnectError.invalidResponse }
        let url = origin.appendingPathComponent("api/djconnect/v1/session/rich")
            .appendingPathComponent(intention.operation.rawValue)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"; request.httpBody = intention.body
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer " + credential, forHTTPHeaderField: "Authorization")
        if [.authorize, .status, .withdraw].contains(intention.operation) {
            // The authenticated paired identity must match both exact headers
            // and the closed body. Role reads/assets receive neither header.
            request.setValue(intention.fields["device_id"]!.string!, forHTTPHeaderField: "X-DJConnect-Device-ID")
            request.setValue(intention.fields["client_type"]!.string!, forHTTPHeaderField: "X-DJConnect-Client-Type")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(intention.operation == .asset ? "image/png, image/jpeg, application/json" : "application/json", forHTTPHeaderField: "Accept")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        let metadata = ResponseStatus()
        let asset = intention.operation == .asset
        let reply = try await DJConnectBoundedHTTPTransport.send(request, using: session,
            maximumBytes: asset ? 256000 : 16384, beforeDispatch: beforeDispatch,
            isBodyCurrent: isCurrent, validateResponse: { response in
                guard response.value(forHTTPHeaderField: "Cache-Control")?.lowercased().split(separator: ",")
                        .map({ $0.trimmingCharacters(in: .whitespaces) }).contains("no-store") == true,
                      response.value(forHTTPHeaderField: "X-Content-Type-Options")?.lowercased() == "nosniff",
                      response.value(forHTTPHeaderField: "Referrer-Policy")?.lowercased() == "no-referrer",
                      response.value(forHTTPHeaderField: "Content-Encoding") == nil || response.value(forHTTPHeaderField: "Content-Encoding")?.lowercased() == "identity",
                      let mime = response.mimeType?.lowercased(),
                      response.statusCode == 200 || DirectRichServerError.allCases.contains(where: { $0.status == response.statusCode }),
                      mime == "application/json" || (asset && response.statusCode == 200 && ["image/png", "image/jpeg"].contains(mime)),
                      !(asset && response.statusCode == 200 && mime == "application/json"),
                      metadata.capture(response.statusCode) else { throw DJConnectError.invalidResponse }
                if mime == "application/json", response.expectedContentLength > 16384 { throw DJConnectError.invalidResponse }
                return mime
            })
        try Task.checkCancellation()
        guard isCurrent(), let status = metadata.value else { throw DJConnectError.invalidResponse }
        if status != 200 {
            let error = try DirectRichServerError.decode(reply.data, status: status)
            onServerError?(error) // Negative owner fencing without another await.
            throw error
        }
        return Reply(bytes: reply.data, mime: reply.mime)
    }

    private static func credential(_ value: String, matches operation: DirectRichRequest.Operation) -> Bool {
        switch operation {
        case .read, .asset:
            let family = operation == .read ? "read" : "asset"
            guard value.hasPrefix("djcrich\(family)_"),
                  DirectRichRequest.matches(String(value.dropFirst("djcrich\(family)_".count)), "[A-Za-z0-9_-]{43}"),
                  let last = value.last, "AEIMQUYcgkosw048".contains(last) else { return false }
            return true
        case .authorize, .status, .withdraw:
            // A rich role credential can never fall back to paired auth. The
            // actual paired token is supplied only by its existing RAM owner.
            return !value.hasPrefix("djcrich") && !value.isEmpty && value.utf8.count <= 4096 &&
                value.utf8.allSatisfy { (33...126).contains($0) }
        }
    }
}

private final class ResponseStatus: @unchecked Sendable {
    private let lock = NSLock()
    private var status: Int?
    var value: Int? { lock.withLock { status } }
    func capture(_ value: Int) -> Bool {
        lock.withLock { guard status == nil else { return false }; status = value; return true }
    }
}
