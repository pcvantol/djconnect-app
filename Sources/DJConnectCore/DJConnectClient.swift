import Foundation

public struct DJConnectAPIFailureLogDetails: Equatable, Sendable {
    public var route: String
    public var httpStatus: Int?
    public var websocketCode: String?
    public var serverError: String
    public var serverMessage: String?
    public var identityPresent: Bool
    public var tokenPresent: Bool
    public var clientType: String
    public var redactedClientID: String
}

public final class DJConnectClient: Sendable {
    public let baseURL: URL
    public let identity: DJConnectIdentity
    public let tokenStore: DJConnectTokenStore

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let responseLogger: (@Sendable (_ requestSummary: String, _ statusCode: Int) -> Void)?
    private let failureLogger: (@Sendable (_ details: DJConnectAPIFailureLogDetails) -> Void)?
    private let webSocketFastPath: (any DJConnectWebSocketFastPathTransport)?

    public init(
        baseURL: URL,
        identity: DJConnectIdentity,
        tokenStore: DJConnectTokenStore,
        session: URLSession = .shared,
        webSocketFastPath: (any DJConnectWebSocketFastPathTransport)? = nil,
        responseLogger: (@Sendable (_ requestSummary: String, _ statusCode: Int) -> Void)? = nil,
        failureLogger: (@Sendable (_ details: DJConnectAPIFailureLogDetails) -> Void)? = nil
    ) {
        self.baseURL = baseURL
        self.identity = identity
        self.tokenStore = tokenStore
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.webSocketFastPath = webSocketFastPath
        self.responseLogger = responseLogger
        self.failureLogger = failureLogger
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

    public func exportAskDJHistoryData() async throws -> Data {
        let request = try exportAskDJHistoryRequest()
        return try await dataResponse(for: request)
    }

    public func musicDNAProfile(mood: Int? = nil, musicDNAKey: String? = nil, language: String? = nil) async throws -> DJConnectMusicDNAProfileResponse {
        let request = try musicDNAProfileRequest(mood: mood, musicDNAKey: musicDNAKey, language: language)
        return try await decodedResponse(for: request)
    }

    public func setMusicDNAEnabled(_ enabled: Bool, mood: Int? = nil, musicDNAKey: String? = nil, language: String? = nil) async throws -> DJConnectMusicDNAProfileResponse {
        let request = try musicDNASettingsRequest(enabled: enabled, mood: mood, musicDNAKey: musicDNAKey, language: language)
        return try await decodedResponse(for: request)
    }

    public func clearMusicDNA(mood: Int? = nil, musicDNAKey: String? = nil, language: String? = nil) async throws -> DJConnectMusicDNAProfileResponse {
        let request = try clearMusicDNARequest(mood: mood, musicDNAKey: musicDNAKey, language: language)
        return try await decodedResponse(for: request)
    }

    public func importMusicDNA(_ profile: DJConnectMusicDNAProfileResponse, mood: Int? = nil, musicDNAKey: String? = nil, language: String? = nil) async throws -> DJConnectMusicDNAProfileResponse {
        let request = try importMusicDNARequest(profile, mood: mood, musicDNAKey: musicDNAKey, language: language)
        return try await decodedResponse(for: request)
    }

    public func exportMusicDNA(musicDNAKey: String? = nil, language: String? = nil) async throws -> DJConnectMusicDNAExportResponse {
        let request = try exportMusicDNARequest(musicDNAKey: musicDNAKey, language: language)
        return try await decodedResponse(for: request)
    }

    public func exportMusicDNAData(musicDNAKey: String? = nil, language: String? = nil) async throws -> Data {
        let request = try exportMusicDNARequest(musicDNAKey: musicDNAKey, language: language)
        return try await dataResponse(for: request)
    }

    public func musicDiscoveryFeed(musicDNAKey: String? = nil, language: String? = nil) async throws -> DJConnectMusicDiscoveryResponse {
        let request = try musicDiscoveryFeedRequest(musicDNAKey: musicDNAKey, language: language)
        return try await decodedResponse(for: request)
    }

    public func refreshMusicDiscovery(musicDNAKey: String? = nil, language: String? = nil) async throws -> DJConnectMusicDiscoveryResponse {
        let request = try refreshMusicDiscoveryRequest(musicDNAKey: musicDNAKey, language: language)
        return try await decodedResponse(for: request)
    }

    public func playMusicDiscoveryItem(_ payload: DJConnectMusicDiscoveryPlayRequest) async throws -> DJConnectCommandResponse {
        let request = try musicDiscoveryPlayRequest(payload)
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
        guard data.success != false, let insight = data.trackInsightValue(
            fallbackTitle: payload.title,
            fallbackArtist: payload.artist,
            fallbackArtwork: payload.artworkURL,
            fallbackDurationMS: payload.durationMS,
            fallbackProgressMS: payload.progressMS
        ) else {
            throw DJConnectError.trackInsightUnavailable(code: data.error, message: data.message)
        }
        return insight
    }

    public func vibeCast(_ payload: DJConnectVibeCastRequest) async throws -> DJConnectVibeCastResponse {
        if let response = try await webSocketVibeCastIfSupported(payload) {
            return response
        }
        let request = try vibeCastRequest(payload)
        return try await decodedResponse(for: request)
    }

    public var fastPathDiagnostics: DJConnectFastPathDiagnostics {
        get async {
            await webSocketFastPath?.diagnostics ?? DJConnectFastPathDiagnostics()
        }
    }

    public func prepareFastPath() async throws {
        try await webSocketFastPath?.prepare()
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
        musicDNAKey: String? = nil,
        language: String? = nil
    ) async throws -> DJConnectVoiceResponse {
        let request = try voiceRequest(wavData: wavData, mood: mood, djStyle: djStyle, musicDNAKey: musicDNAKey, language: language)
        return try await decodedResponse(for: request)
    }

    public func statusRequest(_ payload: DJConnectStatusPayload) throws -> URLRequest {
        try jsonRequest(path: "/api/djconnect/status", payload: payload)
    }

    public func pairingRequest(_ payload: DJConnectPairingPayload) throws -> URLRequest {
        guard Self.deviceID(payload.deviceID, matches: payload.clientType, allowLegacyRaspberryPiPrefix: false) else {
            throw DJConnectError.invalidConfiguration("DJConnect pairing identity mismatch: device_id prefix does not match client_type.")
        }
        var request = URLRequest(url: endpoint(path: "/api/djconnect/pair"))
        request.timeoutInterval = 10
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(payload.deviceID, forHTTPHeaderField: "X-DJConnect-Device-ID")
        request.setValue(payload.clientType.rawValue, forHTTPHeaderField: "X-DJConnect-Client-Type")
        request.httpBody = try encoder.encode(payload)
        return request
    }

    private static func deviceID(_ deviceID: String, matches clientType: DJConnectClientType) -> Bool {
        Self.deviceID(deviceID, matches: clientType, allowLegacyRaspberryPiPrefix: false)
    }

    private static func deviceID(
        _ deviceID: String,
        matches clientType: DJConnectClientType,
        allowLegacyRaspberryPiPrefix: Bool
    ) -> Bool {
        return switch clientType {
        case .ios:
            deviceID.hasPrefix("djconnect-ios-")
        case .macos:
            deviceID.hasPrefix("djconnect-macos-")
        case .watchos:
            deviceID.hasPrefix("djconnect-watchos-")
        case .windows:
            deviceID.hasPrefix("djconnect-windows-")
        case .esp32:
            deviceID.hasPrefix("djconnect-esp32-")
        case .raspberryPi:
            deviceID.hasPrefix("djconnect-raspberry-pi-")
                || (allowLegacyRaspberryPiPrefix && deviceID.hasPrefix("djconnect-rpi-"))
        }
    }

    public func commandRequest(_ payload: DJConnectCommandPayload) throws -> URLRequest {
        var request = try jsonRequest(path: "/api/djconnect/command", payload: payload)
        if let language = Self.nonBlankLanguage(payload.language) {
            request.setValue(language, forHTTPHeaderField: "X-DJConnect-Language")
            request.setValue(language, forHTTPHeaderField: "X-DJConnect-Locale")
            request.setValue(language, forHTTPHeaderField: "Accept-Language")
        }
        if let mood = payload.mood {
            request.setValue(String(mood), forHTTPHeaderField: "X-DJConnect-Mood")
        }
        if let musicDNAKey = payload.musicDNAKey?.trimmingCharacters(in: .whitespacesAndNewlines),
           !musicDNAKey.isEmpty {
            request.setValue(musicDNAKey, forHTTPHeaderField: "X-DJConnect-Music-DNA-Key")
        }
        return request
    }

    public func askDJRequest(_ payload: DJConnectAskDJRequest) throws -> URLRequest {
        var request = try jsonRequest(path: "/api/djconnect/ask", payload: payload)
        request.timeoutInterval = 15
        return request
    }

    public func askDJMessageRequest(_ payload: DJConnectAskDJRequest) throws -> URLRequest {
        var request = try jsonRequest(path: "/api/djconnect/ask_dj/message", payload: payload)
        request.timeoutInterval = 30
        return request
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
        try jsonRequest(
            path: "/api/djconnect/ask_dj/history/clear",
            payload: DJConnectAskDJClearHistoryRequest(identity: identity, musicDNAKey: musicDNAKey)
        )
    }

    public func exportAskDJHistoryRequest() throws -> URLRequest {
        try jsonRequest(
            path: "/api/djconnect/ask_dj/history/export",
            payload: DJConnectAskDJHistoryExportRequest(identity: identity)
        )
    }

    public func musicDNAProfileRequest(mood: Int? = nil, musicDNAKey: String? = nil, language: String? = nil) throws -> URLRequest {
        try musicDNARequest(
            path: "/api/djconnect/music_dna/profile",
            payload: DJConnectMusicDNAIdentityRequest(identity: identity, mood: mood, musicDNAKey: musicDNAKey, language: language),
            mood: mood,
            musicDNAKey: musicDNAKey,
            language: language
        )
    }

    public func musicDNASettingsRequest(enabled: Bool, mood: Int? = nil, musicDNAKey: String? = nil, language: String? = nil) throws -> URLRequest {
        try musicDNARequest(
            path: "/api/djconnect/music_dna/settings",
            payload: DJConnectMusicDNASettingsRequest(identity: identity, enabled: enabled, mood: mood, musicDNAKey: musicDNAKey, language: language),
            mood: mood,
            musicDNAKey: musicDNAKey,
            language: language
        )
    }

    public func clearMusicDNARequest(mood: Int? = nil, musicDNAKey: String? = nil, language: String? = nil) throws -> URLRequest {
        try musicDNARequest(
            path: "/api/djconnect/music_dna/clear",
            payload: DJConnectMusicDNAIdentityRequest(identity: identity, mood: mood, musicDNAKey: musicDNAKey, language: language),
            mood: mood,
            musicDNAKey: musicDNAKey,
            language: language
        )
    }

    public func importMusicDNARequest(_ profile: DJConnectMusicDNAProfileResponse, mood: Int? = nil, musicDNAKey: String? = nil, language: String? = nil) throws -> URLRequest {
        try musicDNARequest(
            path: "/api/djconnect/music_dna/import",
            payload: DJConnectMusicDNAImportRequest(identity: identity, profile: profile, mood: mood, musicDNAKey: musicDNAKey, language: language),
            mood: mood,
            musicDNAKey: musicDNAKey,
            language: language
        )
    }

    public func exportMusicDNARequest(musicDNAKey: String? = nil, language: String? = nil) throws -> URLRequest {
        try musicDNARequest(
            path: "/api/djconnect/music_dna/export",
            payload: DJConnectMusicDNAExportRequest(identity: identity, musicDNAKey: musicDNAKey, language: language),
            mood: nil,
            musicDNAKey: musicDNAKey,
            language: language
        )
    }

    public func musicDiscoveryFeedRequest(musicDNAKey: String? = nil, language: String? = nil) throws -> URLRequest {
        var request = try authenticatedRequest(path: "/api/djconnect/music_discovery")
        request.httpMethod = "GET"
        applyMusicDNAHeaders(to: &request, mood: nil, musicDNAKey: musicDNAKey, language: language)
        return request
    }

    public func refreshMusicDiscoveryRequest(musicDNAKey: String? = nil, language: String? = nil) throws -> URLRequest {
        try musicDNARequest(
            path: "/api/djconnect/music_discovery/refresh",
            payload: DJConnectMusicDNAIdentityRequest(identity: identity, musicDNAKey: musicDNAKey, language: language),
            mood: nil,
            musicDNAKey: musicDNAKey,
            language: language
        )
    }

    public func musicDiscoveryPlayRequest(_ payload: DJConnectMusicDiscoveryPlayRequest) throws -> URLRequest {
        try musicDNARequest(
            path: "/api/djconnect/music_discovery/play",
            payload: payload,
            mood: nil,
            musicDNAKey: payload.musicDNAKey,
            language: nil
        )
    }

    private func musicDNARequest<T: Encodable>(
        path: String,
        payload: T,
        mood: Int?,
        musicDNAKey: String?,
        language: String?
    ) throws -> URLRequest {
        var request = try jsonRequest(path: path, payload: payload)
        applyMusicDNAHeaders(to: &request, mood: mood, musicDNAKey: musicDNAKey, language: language)
        return request
    }

    private func applyMusicDNAHeaders(to request: inout URLRequest, mood: Int?, musicDNAKey: String?, language: String?) {
        if let language = Self.nonBlankLanguage(language) {
            request.setValue(language, forHTTPHeaderField: "X-DJConnect-Language")
            request.setValue(language, forHTTPHeaderField: "X-DJConnect-Locale")
            request.setValue(language, forHTTPHeaderField: "Accept-Language")
        }
        if let mood {
            request.setValue("\(max(0, min(100, mood)))", forHTTPHeaderField: "X-DJConnect-Mood")
        }
        if let musicDNAKey, !musicDNAKey.isEmpty {
            request.setValue(musicDNAKey, forHTTPHeaderField: "X-DJConnect-Music-DNA-Key")
        }
    }

    public func askDJIdleSuggestionRequest(_ payload: DJConnectAskDJIdleSuggestionRequest) throws -> URLRequest {
        var request = try jsonRequest(path: "/api/djconnect/ask_dj/idle_suggestion", payload: payload)
        request.timeoutInterval = 15
        return request
    }

    public func trackInsightRequest(_ payload: DJConnectTrackInsightRequest) throws -> URLRequest {
        let normalizedPayload = payload.normalizedForSend(identity: identity)
        var request = try jsonRequest(path: "/api/djconnect/track_insight", payload: normalizedPayload)
        if let language = Self.nonBlankLanguage(normalizedPayload.language ?? normalizedPayload.locale) {
            request.setValue(language, forHTTPHeaderField: "X-DJConnect-Language")
            request.setValue(language, forHTTPHeaderField: "X-DJConnect-Locale")
            request.setValue(language, forHTTPHeaderField: "Accept-Language")
        }
        if let mood = normalizedPayload.mood {
            request.setValue("\(max(0, min(100, mood)))", forHTTPHeaderField: "X-DJConnect-Mood")
        }
        if let musicDNAKey = normalizedPayload.musicDNAKey, !musicDNAKey.isEmpty {
            request.setValue(musicDNAKey, forHTTPHeaderField: "X-DJConnect-Music-DNA-Key")
        }
        return request
    }

    public func vibeCastRequest(_ payload: DJConnectVibeCastRequest = DJConnectVibeCastRequest()) throws -> URLRequest {
        var components = URLComponents(url: endpoint(path: "/api/djconnect/vibecast"), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "device_id", value: identity.deviceID),
            URLQueryItem(name: "client_id", value: identity.deviceID),
            URLQueryItem(name: "client_type", value: identity.clientType.rawValue),
            URLQueryItem(name: "device_name", value: identity.deviceName),
            URLQueryItem(name: "app_version", value: identity.appVersion)
        ]
        if let locale = Self.nonBlankLanguage(payload.locale ?? payload.language) {
            queryItems.append(URLQueryItem(name: "locale", value: locale))
            queryItems.append(URLQueryItem(name: "language", value: locale))
        }
        if let timezone = payload.timezone?.trimmingCharacters(in: .whitespacesAndNewlines), !timezone.isEmpty {
            queryItems.append(URLQueryItem(name: "timezone", value: timezone))
        }
        if !payload.capabilities.isEmpty {
            queryItems.append(URLQueryItem(name: "capabilities", value: payload.capabilities.joined(separator: ",")))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw DJConnectError.invalidConfiguration("Invalid VibeCast endpoint")
        }
        var request = try authenticatedRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(identity.appVersion, forHTTPHeaderField: "X-DJConnect-App-Version")
        request.setValue(payload.capabilities.joined(separator: ","), forHTTPHeaderField: "X-DJConnect-Render-Capabilities")
        if let locale = Self.nonBlankLanguage(payload.locale ?? payload.language) {
            request.setValue(locale, forHTTPHeaderField: "X-DJConnect-Language")
            request.setValue(locale, forHTTPHeaderField: "X-DJConnect-Locale")
            request.setValue(locale, forHTTPHeaderField: "Accept-Language")
        }
        if let timezone = payload.timezone?.trimmingCharacters(in: .whitespacesAndNewlines), !timezone.isEmpty {
            request.setValue(timezone, forHTTPHeaderField: "X-DJConnect-Timezone")
        }
        return request
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
        musicDNAKey: String? = nil,
        language: String? = nil
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
        if let language, !language.isEmpty {
            request.setValue(language, forHTTPHeaderField: "X-DJConnect-Language")
            request.setValue(language, forHTTPHeaderField: "X-DJConnect-Locale")
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

        if envelope?.error == "client_type_mismatch" {
            return .clientTypeMismatch(
                message: message,
                expectedClientType: envelope?.expectedClientType,
                receivedClientType: envelope?.receivedClientType
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

    private static func nonBlankLanguage(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func decodedResponse<T: Decodable>(for request: URLRequest) async throws -> T {
        let (data, statusCode) = try await dataAndStatusCodeResponse(for: request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw DJConnectError.decodingFailed(
                statusCode: statusCode,
                endpoint: Self.requestSummary(request),
                message: Self.decodingFailureMessage(error: error, body: data)
            )
        }
    }

    private func dataResponse(for request: URLRequest) async throws -> Data {
        let (data, _) = try await dataAndStatusCodeResponse(for: request)
        return data
    }

    private func dataAndStatusCodeResponse(for request: URLRequest) async throws -> (Data, Int) {
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
            logAPIFailure(request: request, statusCode: httpResponse.statusCode, body: data, error: error)
            throw error
        }

        return (data, httpResponse.statusCode)
    }

    private func webSocketCommandIfSupported<T: Decodable & Sendable>(_ payload: DJConnectCommandPayload) async throws -> T? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.command(payload, identity: makeDJConnectIdentity(deviceToken: token), responseType: T.self)
        }
    }

    private func webSocketAskDJMessageIfSupported(_ payload: DJConnectAskDJRequest) async throws -> DJConnectAskDJMessageResponse? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.askDJMessage(payload, identity: makeDJConnectIdentity(deviceToken: token))
        }
    }

    private func webSocketAskDJHistoryIfSupported(sinceRevision: Int?) async throws -> DJConnectAskDJHistoryResponse? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.askDJHistory(identity: makeDJConnectIdentity(deviceToken: token), sinceRevision: sinceRevision)
        }
    }

    private func webSocketClearAskDJHistoryIfSupported(musicDNAKey: String?) async throws -> DJConnectAskDJHistoryResponse? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.clearAskDJHistory(identity: makeDJConnectIdentity(deviceToken: token), musicDNAKey: musicDNAKey)
        }
    }

    private func webSocketTrackInsightIfSupported(_ payload: DJConnectTrackInsightRequest) async throws -> TrackInsight? {
        let normalizedPayload = payload.normalizedForSend(identity: identity)
        return try await webSocketFastPathResult { fastPath, token in
            try await fastPath.trackInsight(normalizedPayload, identity: makeDJConnectIdentity(deviceToken: token))
        }
    }

    private func webSocketVibeCastIfSupported(_ payload: DJConnectVibeCastRequest) async throws -> DJConnectVibeCastResponse? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.vibeCast(payload, identity: makeDJConnectIdentity(deviceToken: token))
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
        let token = try loadedToken()
        let apiIdentity = try makeDJConnectIdentity(deviceToken: token)
        var request = makeAuthenticatedRequest(url: endpoint(path: path), token: token)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(DJConnectIdentifiedRequestPayload(identity: apiIdentity, payload: payload))
        return request
    }

    private func authenticatedRequest(path: String) throws -> URLRequest {
        try authenticatedRequest(url: endpoint(path: path))
    }

    private func authenticatedRequest(url: URL) throws -> URLRequest {
        let token = try loadedToken()
        _ = try makeDJConnectIdentity(deviceToken: token)
        return makeAuthenticatedRequest(url: url, token: token)
    }

    public func makeDJConnectIdentity(deviceToken: String? = nil) throws -> DJConnectAPIIdentity {
        guard Self.deviceID(identity.deviceID, matches: identity.clientType, allowLegacyRaspberryPiPrefix: false) else {
            throw DJConnectError.invalidConfiguration("DJConnect identity mismatch: device_id prefix does not match client_type.")
        }
        return DJConnectAPIIdentity(identity: identity, deviceToken: deviceToken)
    }

    private func makeAuthenticatedRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(identity.deviceID, forHTTPHeaderField: "X-DJConnect-Device-ID")
        request.setValue(identity.deviceID, forHTTPHeaderField: "X-DJConnect-Client-ID")
        request.setValue(identity.clientType.rawValue, forHTTPHeaderField: "X-DJConnect-Client-Type")
        request.setValue(identity.deviceName, forHTTPHeaderField: "X-DJConnect-Device-Name")
        return request
    }

    private func loadedToken() throws -> String {
        guard let token = try tokenStore.loadToken(), !token.isEmpty else {
            throw DJConnectError.missingToken
        }
        return token
    }

    private func logAPIFailure(request: URLRequest, statusCode: Int, body: Data, error: DJConnectError) {
        guard let failureLogger else {
            return
        }
        let envelope = try? decoder.decode(DJConnectErrorEnvelope.self, from: body)
        failureLogger(DJConnectAPIFailureLogDetails(
            route: Self.requestSummary(request),
            httpStatus: statusCode,
            websocketCode: nil,
            serverError: envelope?.error ?? Self.errorCode(for: error),
            serverMessage: envelope?.message ?? Self.redactedResponseBodyMessage(from: body),
            identityPresent: true,
            tokenPresent: request.value(forHTTPHeaderField: "Authorization")?.isEmpty == false,
            clientType: identity.clientType.rawValue,
            redactedClientID: Self.redactedIdentifier(identity.deviceID)
        ))
    }

    private func endpoint(path: String) -> URL {
        baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    private static func requestSummary(_ request: URLRequest) -> String {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path.isEmpty == false ? request.url?.path ?? "/" : "/"
        return "\(method) \(path)"
    }

    private static func errorCode(for error: DJConnectError) -> String {
        switch error {
        case .backendUnavailable:
            return "backend_unavailable"
        case .authStale:
            return "auth_stale"
        case .routeMissing:
            return "route_missing"
        case .versionMismatch:
            return "version_mismatch"
        case .notConfigured:
            return "not_configured"
        case .server:
            return "server"
        case .decodingFailed:
            return "decoding_failed"
        case .network:
            return "network"
        case .invalidResponse:
            return "invalid_response"
        case .invalidConfiguration:
            return "invalid_configuration"
        case .missingToken:
            return "missing_token"
        case .pairingFailed:
            return "pairing_failed"
        case .clientTypeMismatch:
            return "client_type_mismatch"
        case let .trackInsightUnavailable(code, _):
            return code ?? "track_insight_unavailable"
        }
    }

    private static func redactedIdentifier(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else {
            return trimmed.isEmpty ? "missing" : "[redacted]"
        }
        return "\(trimmed.prefix(18))...[redacted]"
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
