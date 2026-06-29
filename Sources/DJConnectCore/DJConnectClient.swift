import Foundation

public final class DJConnectClient: Sendable {
    public let baseURL: URL
    public let identity: DJConnectIdentity
    public let tokenStore: DJConnectTokenStore

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let responseLogger: (@Sendable (_ requestSummary: String, _ statusCode: Int) -> Void)?
    private let webSocketFastPath: (any DJConnectWebSocketFastPathTransport)?

    public init(
        baseURL: URL,
        identity: DJConnectIdentity,
        tokenStore: DJConnectTokenStore,
        session: URLSession = .shared,
        webSocketFastPath: (any DJConnectWebSocketFastPathTransport)? = nil,
        responseLogger: (@Sendable (_ requestSummary: String, _ statusCode: Int) -> Void)? = nil
    ) {
        self.baseURL = baseURL
        self.identity = identity
        self.tokenStore = tokenStore
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.webSocketFastPath = webSocketFastPath
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
        if let response: DJConnectEnvelope<DJConnectPlayback> = try await webSocketCommandIfSupported(payload) {
            return response
        }
        let request = try commandRequest(payload)
        return try await decodedResponse(for: request)
    }

    public func sendCommandResponse(_ payload: DJConnectCommandPayload) async throws -> DJConnectCommandResponse {
        if let response: DJConnectCommandResponse = try await webSocketCommandIfSupported(payload) {
            return response
        }
        let request = try commandRequest(payload)
        return try await decodedResponse(for: request)
    }

    public func sendAskDJ(_ payload: DJConnectAskDJRequest) async throws -> DJConnectAskDJResponse {
        let request = try askDJRequest(payload)
        return try await decodedResponse(for: request)
    }

    public func sendAskDJMessage(_ payload: DJConnectAskDJRequest) async throws -> DJConnectAskDJMessageResponse {
        if let response = try await webSocketAskDJMessageIfSupported(payload) {
            return response
        }
        let request = try askDJMessageRequest(payload)
        return try await decodedResponse(for: request)
    }

    public func askDJHistory(sinceRevision: Int? = nil) async throws -> DJConnectAskDJHistoryResponse {
        if let response = try await webSocketAskDJHistoryIfSupported(sinceRevision: sinceRevision) {
            return response
        }
        let request = try askDJHistoryRequest(sinceRevision: sinceRevision)
        return try await decodedResponse(for: request)
    }

    public func clearAskDJHistory(musicDNAKey: String? = nil) async throws -> DJConnectAskDJHistoryResponse {
        if let response = try await webSocketClearAskDJHistoryIfSupported(musicDNAKey: musicDNAKey) {
            return response
        }
        let request = try clearAskDJHistoryRequest(musicDNAKey: musicDNAKey)
        return try await decodedResponse(for: request)
    }

    public func askDJIdleSuggestion(_ payload: DJConnectAskDJIdleSuggestionRequest) async throws -> DJConnectAskDJMessageResponse {
        let request = try askDJIdleSuggestionRequest(payload)
        return try await decodedResponse(for: request)
    }

    public func trackInsight(_ payload: DJConnectTrackInsightRequest) async throws -> TrackInsight {
        if let insight = try await webSocketTrackInsightIfSupported(payload) {
            return insight
        }
        let request = try trackInsightRequest(payload)
        let data: TrackInsightEndpointResponse = try await decodedResponse(for: request)
        guard data.success != false, let insight = data.trackInsightValue else {
            throw DJConnectError.trackInsightUnavailable(code: data.error, message: data.message)
        }
        return insight
    }

    public var fastPathDiagnostics: DJConnectFastPathDiagnostics {
        get async {
            await webSocketFastPath?.diagnostics ?? DJConnectFastPathDiagnostics()
        }
    }

    public func registerPushNotifications(_ payload: DJConnectPushRegistrationRequest) async throws -> DJConnectCommandResponse {
        let request = try pushRegisterRequest(payload)
        return try await decodedResponse(for: request)
    }

    public func unregisterPushNotifications(_ payload: DJConnectPushUnregistrationRequest) async throws -> DJConnectCommandResponse {
        let request = try pushUnregisterRequest(payload)
        return try await decodedResponse(for: request)
    }

    public func sendVoice(
        wavData: Data,
        mood: Int? = nil,
        djStyle: String? = nil,
        musicDNAKey: String? = nil
    ) async throws -> DJConnectVoiceResponse {
        let request = try voiceRequest(wavData: wavData, mood: mood, djStyle: djStyle, musicDNAKey: musicDNAKey)
        return try await decodedResponse(for: request)
    }

    public func statusRequest(_ payload: DJConnectStatusPayload) throws -> URLRequest {
        try jsonRequest(path: "/api/djconnect/status", payload: payload)
    }

    public func pairingRequest(_ payload: DJConnectPairingPayload) throws -> URLRequest {
        var request = URLRequest(url: endpoint(path: "/api/djconnect/pair"))
        request.timeoutInterval = 10
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(payload.deviceID, forHTTPHeaderField: "X-DJConnect-Device-ID")
        request.httpBody = try encoder.encode(payload)
        return request
    }

    public func commandRequest(_ payload: DJConnectCommandPayload) throws -> URLRequest {
        try jsonRequest(path: "/api/djconnect/command", payload: payload)
    }

    public func askDJRequest(_ payload: DJConnectAskDJRequest) throws -> URLRequest {
        try jsonRequest(path: "/api/djconnect/ask", payload: payload)
    }

    public func askDJMessageRequest(_ payload: DJConnectAskDJRequest) throws -> URLRequest {
        try jsonRequest(path: "/api/djconnect/ask_dj/message", payload: payload)
    }

    public func askDJHistoryRequest(sinceRevision: Int? = nil) throws -> URLRequest {
        var components = URLComponents(url: endpoint(path: "/api/djconnect/ask_dj/history"), resolvingAgainstBaseURL: false)
        if let sinceRevision {
            components?.queryItems = [URLQueryItem(name: "since_revision", value: "\(sinceRevision)")]
        }
        guard let url = components?.url else {
            throw DJConnectError.invalidConfiguration("Invalid Ask DJ history endpoint")
        }
        var request = try authenticatedRequest(url: url)
        request.httpMethod = "GET"
        return request
    }

    public func clearAskDJHistoryRequest(musicDNAKey: String? = nil) throws -> URLRequest {
        var request = try authenticatedRequest(path: "/api/djconnect/ask_dj/history/clear")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(DJConnectAskDJClearHistoryRequest(identity: identity, musicDNAKey: musicDNAKey))
        return request
    }

    public func askDJIdleSuggestionRequest(_ payload: DJConnectAskDJIdleSuggestionRequest) throws -> URLRequest {
        try jsonRequest(path: "/api/djconnect/ask_dj/idle_suggestion", payload: payload)
    }

    public func trackInsightRequest(_ payload: DJConnectTrackInsightRequest) throws -> URLRequest {
        try jsonRequest(path: "/api/djconnect/track_insight", payload: payload)
    }

    public func pushRegisterRequest(_ payload: DJConnectPushRegistrationRequest) throws -> URLRequest {
        try jsonRequest(path: "/api/djconnect/push/register", payload: payload)
    }

    public func pushUnregisterRequest(_ payload: DJConnectPushUnregistrationRequest) throws -> URLRequest {
        try jsonRequest(path: "/api/djconnect/push/unregister", payload: payload)
    }

    public func voiceRequest(
        wavData: Data,
        mood: Int? = nil,
        djStyle: String? = nil,
        musicDNAKey: String? = nil
    ) throws -> URLRequest {
        var request = try authenticatedRequest(path: "/api/djconnect/voice")
        request.httpMethod = "POST"
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.setValue(identity.clientType.rawValue, forHTTPHeaderField: "X-DJConnect-Client-Type")
        request.setValue(identity.deviceName, forHTTPHeaderField: "X-DJConnect-Device-Name")
        request.setValue(identity.deviceID, forHTTPHeaderField: "X-DJConnect-Client-ID")
        if let mood {
            request.setValue("\(max(0, min(100, mood)))", forHTTPHeaderField: "X-DJConnect-Mood")
        }
        if let djStyle, !djStyle.isEmpty {
            request.setValue(djStyle, forHTTPHeaderField: "X-DJConnect-DJ-Style")
        }
        if let musicDNAKey, !musicDNAKey.isEmpty {
            request.setValue(musicDNAKey, forHTTPHeaderField: "X-DJConnect-Music-DNA-Key")
        }
        request.httpBody = wavData
        return request
    }

    public func classify(statusCode: Int, body: Data? = nil, networkError: Error? = nil) -> DJConnectError? {
        if let networkError {
            return .network(message: networkError.localizedDescription)
        }

        let envelope = body.flatMap { try? decoder.decode(DJConnectErrorEnvelope.self, from: $0) }
        let message = envelope?.message ?? body.flatMap(Self.redactedResponseBodyMessage(from:))

        if (200...299).contains(statusCode) {
            guard let envelope else {
                return nil
            }
            if envelope.error == "backend_unavailable"
                || envelope.error == "playback_backend_unavailable"
                || envelope.backendAvailable == false {
                return .backendUnavailable(message: message)
            }
            return nil
        }

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
                of: #""(device_token|push_token|bearer_token|token|access_token|refresh_token|client_secret|password)"\s*:\s*"[^"]*""#,
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

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw DJConnectError.decodingFailed(
                statusCode: httpResponse.statusCode,
                endpoint: Self.requestSummary(request),
                message: Self.decodingFailureMessage(error: error, body: data)
            )
        }
    }

    private func webSocketCommandIfSupported<T: Decodable & Sendable>(_ payload: DJConnectCommandPayload) async throws -> T? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.command(payload, token: token, responseType: T.self)
        }
    }

    private func webSocketAskDJMessageIfSupported(_ payload: DJConnectAskDJRequest) async throws -> DJConnectAskDJMessageResponse? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.askDJMessage(payload, token: token)
        }
    }

    private func webSocketAskDJHistoryIfSupported(sinceRevision: Int?) async throws -> DJConnectAskDJHistoryResponse? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.askDJHistory(identity: identity, sinceRevision: sinceRevision, token: token)
        }
    }

    private func webSocketClearAskDJHistoryIfSupported(musicDNAKey: String?) async throws -> DJConnectAskDJHistoryResponse? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.clearAskDJHistory(identity: identity, musicDNAKey: musicDNAKey, token: token)
        }
    }

    private func webSocketTrackInsightIfSupported(_ payload: DJConnectTrackInsightRequest) async throws -> TrackInsight? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.trackInsight(payload, identity: identity, token: token)
        }
    }

    private func webSocketFastPathResult<T: Sendable>(
        _ operation: (any DJConnectWebSocketFastPathTransport, String) async throws -> T
    ) async throws -> T? {
        guard let webSocketFastPath else {
            return nil
        }
        do {
            return try await operation(webSocketFastPath, loadedToken())
        } catch {
            return nil
        }
    }

    private func jsonRequest<T: Encodable>(path: String, payload: T) throws -> URLRequest {
        var request = try authenticatedRequest(path: path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)
        return request
    }

    private func authenticatedRequest(path: String) throws -> URLRequest {
        try authenticatedRequest(url: endpoint(path: path))
    }

    private func authenticatedRequest(url: URL) throws -> URLRequest {
        let token = try loadedToken()

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(identity.deviceID, forHTTPHeaderField: "X-DJConnect-Device-ID")
        return request
    }

    private func loadedToken() throws -> String {
        guard let token = try tokenStore.loadToken(), !token.isEmpty else {
            throw DJConnectError.missingToken
        }
        return token
    }

    private func endpoint(path: String) -> URL {
        baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    private static func requestSummary(_ request: URLRequest) -> String {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path.isEmpty == false ? request.url?.path ?? "/" : "/"
        return "\(method) \(path)"
    }

    private static func decodingFailureMessage(error: Error, body: Data) -> String {
        if String(data: body, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            return "DJConnect contract error: playback command returned HTTP 2xx with an empty JSON body; response_body=<empty response body>"
        }
        let bodyMessage = redactedResponseBodyMessage(from: body) ?? "<empty response body>"
        return "\(detailedDecodingMessage(for: error)); response_body=\(bodyMessage)"
    }

    private static func detailedDecodingMessage(for error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }

        func path(_ context: DecodingError.Context) -> String {
            let value = context.codingPath.map(\.stringValue).joined(separator: ".")
            return value.isEmpty ? "<root>" : value
        }

        switch decodingError {
        case let .typeMismatch(type, context):
            return "typeMismatch(\(type)) codingPath=\(path(context)) debug=\(context.debugDescription)"
        case let .valueNotFound(type, context):
            return "valueNotFound(\(type)) codingPath=\(path(context)) debug=\(context.debugDescription)"
        case let .keyNotFound(key, context):
            return "keyNotFound(\(key.stringValue)) codingPath=\(path(context)) debug=\(context.debugDescription)"
        case let .dataCorrupted(context):
            return "dataCorrupted codingPath=\(path(context)) debug=\(context.debugDescription)"
        @unknown default:
            return decodingError.localizedDescription
        }
    }
}
