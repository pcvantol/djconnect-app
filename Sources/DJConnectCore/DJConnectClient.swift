import Foundation

public final class DJConnectClient: Sendable {
    public let baseURL: URL
    public let identity: DJConnectIdentity
    public let tokenStore: DJConnectTokenStore

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let responseLogger: (@Sendable (_ requestSummary: String, _ statusCode: Int) -> Void)?

    public init(
        baseURL: URL,
        identity: DJConnectIdentity,
        tokenStore: DJConnectTokenStore,
        session: URLSession = .shared,
        responseLogger: (@Sendable (_ requestSummary: String, _ statusCode: Int) -> Void)? = nil
    ) {
        self.baseURL = baseURL
        self.identity = identity
        self.tokenStore = tokenStore
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.responseLogger = responseLogger
    }

    public func postStatus(_ payload: DJConnectStatusPayload) async throws -> DJConnectEnvelope<DJConnectPlayback> {
        let request = try statusRequest(payload)
        return try await decodedResponse(for: request)
    }

    public func pair(_ payload: DJConnectPairingPayload) async throws -> DJConnectPairingResponse {
        let request = try pairingRequest(payload)
        let response: DJConnectPairingResponse = try await decodedResponse(for: request)
        guard response.success, let token = response.resolvedDeviceToken, !token.isEmpty else {
            throw DJConnectError.pairingFailed(message: response.message)
        }
        try tokenStore.saveToken(token)
        return response
    }

    public func sendCommand(_ payload: DJConnectCommandPayload) async throws -> DJConnectEnvelope<DJConnectPlayback> {
        let request = try commandRequest(payload)
        return try await decodedResponse(for: request)
    }

    public func sendCommandResponse(_ payload: DJConnectCommandPayload) async throws -> DJConnectCommandResponse {
        let request = try commandRequest(payload)
        return try await decodedResponse(for: request)
    }

    public func sendVoice(wavData: Data) async throws -> DJConnectVoiceResponse {
        let request = try voiceRequest(wavData: wavData)
        return try await decodedResponse(for: request)
    }

    public func statusRequest(_ payload: DJConnectStatusPayload) throws -> URLRequest {
        try jsonRequest(path: "/api/djconnect/status", payload: payload)
    }

    public func pairingRequest(_ payload: DJConnectPairingPayload) throws -> URLRequest {
        var request = URLRequest(url: endpoint(path: "/api/djconnect/pair"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(payload.deviceID, forHTTPHeaderField: "X-DJConnect-Device-ID")
        request.httpBody = try encoder.encode(payload)
        return request
    }

    public func commandRequest(_ payload: DJConnectCommandPayload) throws -> URLRequest {
        try jsonRequest(path: "/api/djconnect/command", payload: payload)
    }

    public func voiceRequest(wavData: Data) throws -> URLRequest {
        var request = try authenticatedRequest(path: "/api/djconnect/voice")
        request.httpMethod = "POST"
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.httpBody = wavData
        return request
    }

    public func classify(statusCode: Int, body: Data? = nil, networkError: Error? = nil) -> DJConnectError? {
        if let networkError {
            return .network(message: networkError.localizedDescription)
        }

        guard !(200...299).contains(statusCode) else {
            return nil
        }

        let envelope = body.flatMap { try? decoder.decode(DJConnectErrorEnvelope.self, from: $0) }
        let message = envelope?.message ?? body.flatMap(Self.redactedResponseBodyMessage(from:))

        if statusCode == 426 || envelope?.error == "version_mismatch" {
            return .versionMismatch(
                DJConnectVersionMismatch(
                    message: message,
                    haVersion: envelope?.haVersion,
                    haMajorMinor: envelope?.haMajorMinor,
                    firmware: envelope?.firmware,
                    firmwareMajorMinor: envelope?.firmwareMajorMinor
                )
            )
        }

        if statusCode == 401 || statusCode == 403 {
            return .authStale(statusCode: statusCode, message: message)
        }

        if statusCode == 404 {
            return .routeMissing(message: message)
        }

        if envelope?.error == "backend_unavailable" || envelope?.backendAvailable == false {
            return .backendUnavailable(message: message)
        }

        if envelope?.error == "not_configured" {
            return .notConfigured(message: message)
        }

        return .server(statusCode: statusCode, message: message)
    }

    private static func redactedResponseBodyMessage(from body: Data) -> String? {
        guard let rawBody = String(data: body, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !rawBody.isEmpty else {
            return nil
        }
        let redacted = rawBody
            .replacingOccurrences(
                of: #"Bearer\s+[A-Za-z0-9._~+/=-]+"#,
                with: "Bearer [redacted]",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #""(device_token|bearer_token|token|access_token|refresh_token|client_secret|password)"\s*:\s*"[^"]*""#,
                with: #""$1":"[redacted]""#,
                options: .regularExpression
            )
        return String(redacted.prefix(500))
    }

    private func decodedResponse<T: Decodable>(for request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DJConnectError.network(message: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DJConnectError.invalidResponse
        }
        responseLogger?(Self.requestSummary(request), httpResponse.statusCode)

        if let error = classify(statusCode: httpResponse.statusCode, body: data) {
            throw error
        }

        return try decoder.decode(T.self, from: data)
    }

    private func jsonRequest<T: Encodable>(path: String, payload: T) throws -> URLRequest {
        var request = try authenticatedRequest(path: path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)
        return request
    }

    private func authenticatedRequest(path: String) throws -> URLRequest {
        guard let token = try tokenStore.loadToken(), !token.isEmpty else {
            throw DJConnectError.missingToken
        }

        var request = URLRequest(url: endpoint(path: path))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(identity.deviceID, forHTTPHeaderField: "X-DJConnect-Device-ID")
        return request
    }

    private func endpoint(path: String) -> URL {
        baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    private static func requestSummary(_ request: URLRequest) -> String {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path.isEmpty == false ? request.url?.path ?? "/" : "/"
        return "\(method) \(path)"
    }
}
