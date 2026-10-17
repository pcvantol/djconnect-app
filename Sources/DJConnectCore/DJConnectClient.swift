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
    private let hybridTransport: DJConnectHybridTransport?
    private let settingsTransport: DJConnectProfileDJSettingsTransport
    private let speechTransport: DJConnectSpeechTransport
    private let sessionArtworkTransport: DJConnectSessionArtworkTransport
    private let sessionProjectionSession: URLSession
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
        hybridTransport: DJConnectHybridTransport? = nil,
        webSocketFastPath: (any DJConnectWebSocketFastPathTransport)? = nil,
        responseLogger: (@Sendable (_ requestSummary: String, _ statusCode: Int) -> Void)? = nil,
        failureLogger: (@Sendable (_ details: DJConnectAPIFailureLogDetails) -> Void)? = nil
    ) {
        self.baseURL = baseURL
        self.identity = identity
        self.tokenStore = tokenStore
        self.session = session
        self.hybridTransport = hybridTransport
        // Owner Session responses contain ephemeral Moment text. Keep this
        // transport out of URLCache/cookies even if a server omits no-store.
        let projectionConfiguration = session.configuration
        projectionConfiguration.urlCache = nil
        projectionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        projectionConfiguration.httpCookieStorage = nil
        projectionConfiguration.httpShouldSetCookies = false
        projectionConfiguration.urlCredentialStorage = nil
        self.sessionProjectionSession = URLSession(configuration: projectionConfiguration, delegate: session.delegate, delegateQueue: session.delegateQueue)
        self.speechTransport = DJConnectSpeechTransport(configuration: session.configuration)
        self.settingsTransport = DJConnectProfileDJSettingsTransport(configuration: session.configuration)
        self.sessionArtworkTransport = DJConnectSessionArtworkTransport(configuration: session.configuration)
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.webSocketFastPath = webSocketFastPath
        self.responseLogger = responseLogger
        self.failureLogger = failureLogger
    }

    deinit { sessionProjectionSession.invalidateAndCancel() }

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
        try Task.checkCancellation()
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

    public func clearAskDJHistory(musicDNAKey: String? = nil, profileContext: DJConnectProfileContext? = nil) async throws -> DJConnectAskDJHistoryResponse {
        if let response = try await webSocketClearAskDJHistoryIfSupported(musicDNAKey: musicDNAKey) {
            return response
        }
        let request = try clearAskDJHistoryRequest(musicDNAKey: musicDNAKey, profileContext: profileContext)
        return try await decodedResponse(for: request)
    }

    public func exportAskDJHistoryData() async throws -> Data {
        let request = try exportAskDJHistoryRequest()
        return try await dataResponse(for: request)
    }

    public func musicDNAProfile(mood: Int? = nil, musicDNAKey: String? = nil, language: String? = nil, profileContext: DJConnectProfileContext? = nil) async throws -> DJConnectMusicDNAProfileResponse {
        if let response = try await webSocketMusicDNAProfileIfSupported(mood: mood, musicDNAKey: musicDNAKey, language: language) {
            return response
        }
        let request = try musicDNAProfileRequest(mood: mood, musicDNAKey: musicDNAKey, language: language, profileContext: profileContext)
        return try await decodedResponse(for: request)
    }

    public func setMusicDNAEnabled(_ enabled: Bool, mood: Int? = nil, musicDNAKey: String? = nil, language: String? = nil, profileContext: DJConnectProfileContext? = nil) async throws -> DJConnectMusicDNAProfileResponse {
        if let response = try await webSocketMusicDNASettingsIfSupported(enabled, mood: mood, musicDNAKey: musicDNAKey, language: language) {
            return response
        }
        let request = try musicDNASettingsRequest(enabled: enabled, mood: mood, musicDNAKey: musicDNAKey, language: language, profileContext: profileContext)
        return try await decodedResponse(for: request)
    }

    public func clearMusicDNA(mood: Int? = nil, musicDNAKey: String? = nil, language: String? = nil, profileContext: DJConnectProfileContext? = nil) async throws -> DJConnectMusicDNAProfileResponse {
        if let response = try await webSocketMusicDNAClearIfSupported(mood: mood, musicDNAKey: musicDNAKey, language: language) {
            return response
        }
        let request = try clearMusicDNARequest(mood: mood, musicDNAKey: musicDNAKey, language: language, profileContext: profileContext)
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

    public func musicDiscoveryFeed(musicDNAKey: String? = nil, language: String? = nil, profileContext: DJConnectProfileContext? = nil) async throws -> DJConnectMusicDiscoveryResponse {
        if let response = try await webSocketMusicDiscoveryFeedIfSupported(musicDNAKey: musicDNAKey, language: language) {
            return response
        }
        let request = try musicDiscoveryFeedRequest(musicDNAKey: musicDNAKey, language: language, profileContext: profileContext)
        return try await decodedResponse(for: request)
    }

    public func refreshMusicDiscovery(musicDNAKey: String? = nil, language: String? = nil) async throws -> DJConnectMusicDiscoveryResponse {
        if let response = try await webSocketMusicDiscoveryRefreshIfSupported(musicDNAKey: musicDNAKey, language: language) {
            return response
        }
        let request = try refreshMusicDiscoveryRequest(musicDNAKey: musicDNAKey, language: language)
        return try await decodedResponse(for: request)
    }

    public func playMusicDiscoveryItem(_ payload: DJConnectMusicDiscoveryPlayRequest) async throws -> DJConnectCommandResponse {
        if let response = try await webSocketMusicDiscoveryPlayIfSupported(payload) {
            return response
        }
        let request = try musicDiscoveryPlayRequest(payload)
        return try await decodedResponse(for: request)
    }

    public func sendMusicDiscoveryFeedback(_ payload: DJConnectMusicDiscoveryFeedbackRequest) async throws -> DJConnectCommandResponse {
        if let response = try await webSocketMusicDiscoveryFeedbackIfSupported(payload) {
            return response
        }
        let request = try musicDiscoveryFeedbackRequest(payload)
        return try await decodedResponse(for: request)
    }

    public func supportsMusicDiscoveryFeedback() async -> Bool {
        guard let webSocketFastPath else {
            return false
        }
        do {
            try await webSocketFastPath.prepare()
            return await webSocketFastPath.supports(.musicDiscoveryFeedback)
        } catch {
            return false
        }
    }

    public func webSocketSession() async throws -> DJConnectWebSocketSessionResponse {
        let request = try webSocketSessionRequest()
        let response: DJConnectWebSocketSessionResponse = try await decodedResponse(for: request)
        guard response.success, response.resolvedAccessToken != nil else {
            throw DJConnectError.authStale(
                statusCode: 401,
                message: response.message ?? response.error ?? "Home Assistant WebSocket session unavailable"
            )
        }
        return response
    }

    public func askDJIdleSuggestion(_ payload: DJConnectAskDJIdleSuggestionRequest) async throws -> DJConnectAskDJMessageResponse {
        let request = try askDJIdleSuggestionRequest(payload)
        return try await decodedResponse(for: request)
    }

    /// Uses the same owner endpoint and backend service, without current-playback fallback.
    public func momentTrackInsight(_ reference: DJConnectMomentInsightReference, language: String, mood: Int?) async throws -> DJConnectMomentInsightDetail {
        guard reference.isValid else { throw DJConnectError.invalidResponse }
        var payload = DJConnectTrackInsightRequest(locale: language, mood: mood)
        payload.trackInsightTarget = reference
        let response: TrackInsightEndpointResponse = try await decodedResponse(for: trackInsightRequest(payload))
        guard response.success != false, let subject = response.subject, subject.matches(reference),
              let insight = response.trackInsightValue,
              TrackInsightVerifiedCredit.displayText(insight.summary) != nil else { throw DJConnectError.invalidResponse }
        return .init(insight: insight, subject: subject)
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

    public func startSession(_ payload: DJConnectSessionStartRequest) async throws -> DJConnectSessionResponse {
        let request = try sessionStartRequest(payload)
        return try await decodedResponse(for: request, using: sessionProjectionSession)
    }

    public func activeSession() async throws -> DJConnectSessionResponse {
        let request = try activeSessionRequest()
        return try await decodedResponse(for: request, using: sessionProjectionSession)
    }

    public func activeSessionMoodCapabilities() async throws -> DJConnectActiveMoodCapabilities {
        try await decodedResponse(for: sessionHistoryReadRequest(route: "capabilities"), using: sessionProjectionSession)
    }

    public func sessionMoodRequest(sessionID: String, mood: String, expectedRevision: Int) throws -> URLRequest {
        guard !sessionID.isEmpty, expectedRevision >= 0, ["chill", "groove", "energy", "party"].contains(mood) else {
            throw DJConnectError.invalidResponse
        }
        // This contract requires exactly six fields; the generic identified envelope adds fields.
        var request = try authenticatedRequest(path: Self.apiV1Path("session/mood"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "contract_version": 1, "client_type": identity.clientType.rawValue, "device_id": identity.deviceID,
            "session_id": sessionID, "selected_mood": mood, "expected_mood_revision": expectedRevision
        ])
        return request
    }

    public func updateSessionMood(sessionID: String, mood: String, expectedRevision: Int) async throws -> DJConnectSessionMoodResponse {
        let result: DJConnectSessionMoodResponse = try await decodedResponse(
            for: sessionMoodRequest(sessionID: sessionID, mood: mood, expectedRevision: expectedRevision), using: sessionProjectionSession)
        guard result.success, result.contractVersion == 1, result.sessionID == sessionID, result.moodRevision >= expectedRevision,
              result.selectedMood == mood,
              result.moodRevision - expectedRevision == (result.changed ? 1 : 0) else { throw DJConnectError.invalidResponse }
        return result
    }

    public func endSession(_ payload: DJConnectSessionEndRequest) async throws -> DJConnectSessionResponse {
        let request = try sessionEndRequest(payload)
        return try await decodedResponse(for: request, using: sessionProjectionSession)
    }

    public func sessionPresenceRequest(sessionID: String, presence: DJConnectSessionPresenceValue, expectedRevision: Int) throws -> URLRequest {
        guard !sessionID.isEmpty, expectedRevision >= 0 else { throw DJConnectError.invalidResponse }
        var request = try authenticatedRequest(path: Self.apiV1Path("session/presence"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "contract_version": 1, "client_type": identity.clientType.rawValue, "device_id": identity.deviceID,
            "session_id": sessionID, "selected_presence": presence.rawValue, "expected_presence_revision": expectedRevision
        ])
        return request
    }

    public func updateSessionPresence(sessionID: String, presence: DJConnectSessionPresenceValue, expectedRevision: Int) async throws -> DJConnectSessionPresenceResponse {
        let (data, status) = try await dataAndStatusCodeResponse(
            for: sessionPresenceRequest(sessionID: sessionID, presence: presence, expectedRevision: expectedRevision),
            using: sessionProjectionSession, acceptingStatuses: [409])
        if status == 409 {
            struct ConflictBody: Decodable { let success: Bool; let error: String; let current: DJConnectSessionPresenceSnapshot }
            let conflict = try decoder.decode(ConflictBody.self, from: data)
            guard !conflict.success, conflict.error == "presence_revision_conflict", conflict.current.sessionID == sessionID else {
                throw DJConnectError.invalidResponse
            }
            throw DJConnectSessionPresenceConflict(current: conflict.current)
        }
        let result = try decoder.decode(DJConnectSessionPresenceResponse.self, from: data)
        guard status == 200, result.success, result.contractVersion == 1, result.sessionID == sessionID,
              result.selectedPresence == presence, result.presenceRevision >= expectedRevision,
              result.presenceRevision - expectedRevision == (result.changed ? 1 : 0) else { throw DJConnectError.invalidResponse }
        return result
    }

    public func sessionPersonaRequest(sessionID: String, persona: DJConnectSessionPersonaValue, expectedRevision: Int) throws -> URLRequest {
        guard !sessionID.isEmpty, expectedRevision >= 0 else { throw DJConnectError.invalidResponse }
        var request = try authenticatedRequest(path: Self.apiV1Path("session/persona"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "contract_version": 1, "client_type": identity.clientType.rawValue, "device_id": identity.deviceID,
            "session_id": sessionID, "selected_persona": persona.rawValue, "expected_persona_revision": expectedRevision
        ])
        return request
    }

    public func updateSessionPersona(sessionID: String, persona: DJConnectSessionPersonaValue, expectedRevision: Int) async throws -> DJConnectSessionPersonaResponse {
        let (data, status) = try await dataAndStatusCodeResponse(
            for: sessionPersonaRequest(sessionID: sessionID, persona: persona, expectedRevision: expectedRevision),
            using: sessionProjectionSession, acceptingStatuses: [409])
        if status == 409 {
            struct ConflictBody: Decodable { let success: Bool; let error: String; let current: DJConnectSessionPersonaSnapshot }
            let conflict = try decoder.decode(ConflictBody.self, from: data)
            guard !conflict.success, conflict.error == "persona_revision_conflict", conflict.current.sessionID == sessionID else {
                throw DJConnectError.invalidResponse
            }
            throw DJConnectSessionPersonaConflict(current: conflict.current)
        }
        let result = try decoder.decode(DJConnectSessionPersonaResponse.self, from: data)
        guard status == 200, result.success, result.contractVersion == 1, result.sessionID == sessionID,
              result.selectedPersona == persona, result.personaRevision >= expectedRevision,
              result.personaRevision - expectedRevision == (result.changed ? 1 : 0) else { throw DJConnectError.invalidResponse }
        return result
    }

    public func approveVibeCastHandoff(_ payload: DJConnectVibeCastHandoffApprovalRequest) async throws -> DJConnectVibeCastHandoffApprovalResponse {
        let request = try vibeCastHandoffApprovalRequest(payload)
        return try await decodedResponse(for: request)
    }

    public func pairedOwnerLiveCapability() async throws -> DJConnectPairedOwnerLiveCapability? {
        // Public discovery carries no identity or bearer and must not redirect.
        guard var origin = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              ["https", "http"].contains(origin.scheme), origin.host != nil,
              origin.user == nil, origin.password == nil else { throw DJConnectError.invalidResponse }
        origin.path = "/api/djconnect/v1/capabilities"; origin.query = nil; origin.fragment = nil
        guard let url = origin.url else { throw DJConnectError.invalidResponse }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        let discovery = pairedLiveCredentialFreeSession(from: session)
        defer { discovery.invalidateAndCancel() }
        let (data, response) = try await discovery.data(for: request)
        guard let response = response as? HTTPURLResponse, response.url == url else { throw DJConnectError.invalidResponse }
        if response.statusCode >= 500 { throw DJConnectError.server(statusCode: response.statusCode, message: nil) }
        guard response.statusCode == 200 else { throw DJConnectError.routeMissing(message: "Paired live discovery unavailable") }
        try DJConnectIncomingPayloadLimiter.validate(data)
        guard let decoded = try? decoder.decode(DJConnectPairedOwnerLiveDiscovery.self, from: data) else {
            throw DJConnectError.routeMissing(message: "Paired live discovery contract unsupported")
        }
        return decoded.sessionBroadcast?.pairedOwnerWebsocket
    }

    public func sessionHistoryCapabilities() async throws -> DJConnectSessionHistoryCapabilities {
        try await decodedResponse(for: sessionHistoryReadRequest(route: "capabilities"), using: sessionProjectionSession)
    }

    public func profileDJSettings() async throws -> DJConnectProfileDJSettingsResponse {
        var request = try profileDJSettingsRequest()
        request.httpMethod = "GET"
        var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "contract_version", value: "3"),
            URLQueryItem(name: "device_id", value: identity.deviceID),
            URLQueryItem(name: "client_type", value: identity.clientType.rawValue)]
        request.url = components.url
        return try await profileDJSettingsResponse(request)
    }

    public func updateProfileDJSettings(_ current: DJConnectProfileDJSettingsResponse,
        patch: DJConnectProfileDJSettings.Patch, operationID: String) async throws -> DJConnectProfileDJSettingsResponse {
        guard current.isValid, patch.isValid, !current.requiresSelection || patch.isComplete,
              UUID(uuidString: operationID) != nil else { throw DJConnectError.invalidResponse }
        var request = try profileDJSettingsRequest()
        request.httpMethod = "PATCH"
        let patchJSON = try JSONSerialization.jsonObject(with: encoder.encode(patch))
        let expected: Any = current.snapshot.session.map {
            ["session_id": $0.session_id, "generation": $0.generation, "revision": $0.revision] as [String: Any]
        } ?? NSNull()
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "contract_version": 3, "device_id": identity.deviceID, "client_type": identity.clientType.rawValue,
            "binding": current.binding, "operation_id": operationID, "patch": patchJSON,
            "expected_defaults_revision": current.snapshot.defaults_revision, "expected_session": expected])
        let response = try await profileDJSettingsResponse(request)
        guard response.accepted == true, response.operation_id == operationID,
              response.binding == current.binding else { throw DJConnectError.invalidResponse }
        return response
    }

    public func profileDJSettingsOperation(binding: String, operationID: String) async throws -> DJConnectProfileDJSettingsOperation {
        var request = try profileDJSettingsRequest(suffix: "/operation")
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: ["contract_version": 3,
            "device_id": identity.deviceID, "client_type": identity.clientType.rawValue,
            "binding": binding, "operation_id": operationID])
        let (data, status) = try await settingsTransport.read(request)
        if status != 200 {
            if [400, 409, 426].contains(status) { throw try decoder.decode(DJConnectProfileDJSettingsFailure.self, from: data) }
            throw classify(statusCode: status, body: nil) ?? DJConnectError.invalidResponse
        }
        let result = try decoder.decode(DJConnectProfileDJSettingsOperation.self, from: data)
        guard result.validates(operationID: operationID) else { throw DJConnectError.invalidResponse }
        return result
    }

    private func profileDJSettingsRequest(suffix: String = "") throws -> URLRequest {
        _ = try makeDJConnectIdentity()
        var request = try authenticatedRequest(path: "/api/djconnect/v1/profile/settings" + suffix)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        return request
    }

    private func profileDJSettingsResponse(_ request: URLRequest) async throws -> DJConnectProfileDJSettingsResponse {
        let (data, status) = try await settingsTransport.read(request)
        if status != 200 {
            if [400, 409, 426].contains(status) { throw try decoder.decode(DJConnectProfileDJSettingsFailure.self, from: data) }
            throw classify(statusCode: status, body: nil) ?? DJConnectError.invalidResponse
        }
        let response = try decoder.decode(DJConnectProfileDJSettingsResponse.self, from: data)
        guard response.isValid else { throw DJConnectError.invalidResponse }
        return response
    }

    public func prepareSharedDJSpeech(reference: DJConnectSpeechReference, acceptedText: String,
        settings: DJConnectProfileDJSettingsResponse, target: DJConnectSharedSpeechTarget = .local,
        automatic: Bool = false) async throws -> DJConnectSharedSpeechResult {
        guard reference.isValid, settings.allowsSpeech(target),
              !automatic || (target == .local && settings.snapshot.effective.announcement_output.allowsClientAudio) else { throw DJConnectError.invalidResponse }
        struct SharedPrepare: Encodable {
            let contract_version = 3
            let processor = "ha_configured"
            let intent: String
            let reference: DJConnectSpeechReference
            let target: DJConnectSharedSpeechTarget
        }
        let payload = SharedPrepare(intent: automatic ? "automatic" : "manual", reference: reference, target: target)
        let result: DJConnectSharedSpeechResult
        if target == .local {
            let request = try speechJSONRequest(path: "prepare", payload: payload)
            result = try decoder.decode(DJConnectSharedSpeechResult.self, from: await speechTransport.data(for: request))
        } else {
            guard case .moment = reference, hybridTransport != nil else { throw DJConnectError.invalidResponse }
            var request = try authenticatedRequest(path: "/api/djconnect/v1/session/speech/play")
            request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(DJConnectSpeechIdentifiedRequest(clientType: identity.clientType, deviceID: identity.deviceID, payload: payload))
            result = try await decodedResponse(for: request, using: sessionProjectionSession)
        }
        guard result.success, result.session_speech.reference == reference else { throw DJConnectError.invalidResponse }
        let prepared = result.session_speech
        if ["unavailable", "withdrawn", "expired"].contains(prepared.state) && !prepared.manualAllowed && prepared.audioReference == nil { return result }
        guard prepared.admits(reference: reference, text: acceptedText), prepared.audioState == "ready",
              prepared.settingsContractVersion == 3, prepared.settingsRevision == settings.speechFence,
              prepared.effectiveVoice?.hasQualifiedSelection == true,
              prepared.effectiveVoice?.processor == .haConfigured,
              speechLocaleMatches(prepared.effectiveVoice?.locale, prepared.locale),
              prepared.audioReference?.isValid == true else { throw DJConnectError.invalidResponse }
        if settings.snapshot.effective.voice.kind == .providerVoice {
            guard prepared.effectiveVoice?.engine == settings.snapshot.effective.voice.provider_id,
                  prepared.effectiveVoice?.voiceID == settings.snapshot.effective.voice.voice_id else { throw DJConnectError.invalidResponse }
        }
        return result
    }

    public func speechVoiceOptions() async throws -> DJConnectSpeechVoiceOptions {
        let request = try speechJSONRequest(path: "voice-options", payload: DJConnectSpeechContractRequest())
        let response = try decoder.decode(DJConnectSpeechVoiceOptionsResponse.self, from: await speechTransport.data(for: request))
        guard response.success, response.speech_voice_options.isValid else { throw DJConnectError.invalidResponse }
        return response.speech_voice_options
    }

    public func prepareSpeech(_ original: DJConnectSessionSpeech, acceptedText: String,
                              processor: DJConnectSpeechProcessor, preference: DJConnectVoicePreference = .default,
                              voiceOptions: DJConnectSpeechVoiceOptions? = nil, selectedVoiceID: String? = nil) async throws -> DJConnectSessionSpeech {
        guard original.admits(reference: original.reference, text: acceptedText), original.advertisesPreparationAttempt(processor),
              preference == .default || voiceOptions?.admitsGender(preference, voiceID: selectedVoiceID) == true,
              selectedVoiceID == nil || (processor == .haConfigured && voiceOptions?.supportsVoice(selectedVoiceID!) == true)
        else { throw DJConnectError.invalidResponse }
        let request = try speechJSONRequest(path: "prepare", payload: DJConnectSpeechPrepareRequest(
            reference: original.reference, processor: processor, voice_preference: preference, voice_id: selectedVoiceID))
        let response = try decoder.decode(DJConnectSpeechResponse.self, from: await speechTransport.data(for: request))
        let prepared = response.session_speech
        guard response.success, prepared.schemaVersion == 1, prepared.reference == original.reference, prepared.notification?.isValid ?? true else { throw DJConnectError.invalidResponse }
        if ["unavailable", "expired", "withdrawn"].contains(prepared.state), !prepared.manualAllowed, !prepared.autoplayEligible {
            guard prepared.processors.isEmpty, prepared.segments.isEmpty, prepared.audioReference == nil else { throw DJConnectError.invalidResponse }
            return prepared
        }
        guard prepared.admits(reference: original.reference, text: acceptedText),
              prepared.advertisesPreparationAttempt(processor),
              (original.processorQualificationRequired != true || prepared.processorQualificationRequired == true),
              prepared.textRevision == original.textRevision, prepared.presentationRevision == original.presentationRevision,
              prepared.persona == original.persona, prepared.personaRevision == original.personaRevision,
              prepared.locale == original.locale, prepared.attribution == original.attribution,
              let expiry = prepared.expiresAt.flatMap(DJConnectHistoryEntry.date),
              let originalExpiry = original.expiresAt.flatMap(DJConnectHistoryEntry.date),
              expiry <= originalExpiry, expiry.timeIntervalSinceNow <= 300.001,
              processor == .localOnDevice ? prepared.audioState == "renderer_pending" : prepared.audioState == "ready"
        else { throw DJConnectError.invalidResponse }
        if processor == .haConfigured {
            guard prepared.effectiveVoice?.processor == processor, speechLocaleMatches(prepared.effectiveVoice?.locale, prepared.locale),
                  preference == .default || prepared.effectiveVoice?.gender == preference.rawValue,
                  selectedVoiceID == nil || prepared.effectiveVoice?.voiceID == selectedVoiceID else { throw DJConnectError.invalidResponse }
            if preference != .default {
                guard let expected = selectedVoiceID ?? voiceOptions?.qualifiedGenderVoiceID(preference),
                      prepared.effectiveVoice?.voiceID == expected,
                      voiceOptions?.admitsGender(preference, voiceID: expected) == true else { throw DJConnectError.invalidResponse }
            }
        } else {
            guard prepared.audioReference == nil, prepared.effectiveVoice == nil, prepared.voicePreference == preference else { throw DJConnectError.invalidResponse }
        }
        return prepared
    }

    public func speechAudio(_ prepared: DJConnectSessionSpeech, acceptedText: String) async throws -> Data {
        guard prepared.admits(reference: prepared.reference, text: acceptedText), prepared.audioState == "ready",
              prepared.effectiveVoice?.processor == .haConfigured,
              speechLocaleMatches(prepared.effectiveVoice?.locale, prepared.locale),
              prepared.effectiveVoice?.hasQualifiedSelection == true,
              let resource = prepared.audioReference, resource.isValid else { throw DJConnectError.invalidResponse }
        let request = try speechJSONRequest(path: "audio", payload: DJConnectSpeechAudioRequest(asset_id: resource.assetID))
        let bytes = try await speechTransport.data(for: request, audio: true)
        guard prepared.admits(reference: prepared.reference, text: acceptedText) else { throw DJConnectError.invalidResponse }
        return bytes
    }

    private func speechJSONRequest<T: Encodable>(path: String, payload: T) throws -> URLRequest {
        _ = try makeDJConnectIdentity()
        var request = try authenticatedRequest(path: "/api/djconnect/v1/speech/" + path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(DJConnectSpeechIdentifiedRequest(
            clientType: identity.clientType, deviceID: identity.deviceID, payload: payload))
        request.cachePolicy = .reloadIgnoringLocalCacheData; request.timeoutInterval = 22
        return request
    }

    /// Explicit user-authorized preparation only. Never call from a pure
    /// timeline/search/open read, image failure or expiry callback.
    public func prepareSessionArtwork(sessionID: String, targets: [DJConnectSessionMedia.Target]) async throws -> [DJConnectSessionMedia] {
        let request = try sessionArtworkPreparationRequest(sessionID: sessionID, targets: targets)
        let data = try await sessionArtworkTransport.prepare(request)
        let response = try decoder.decode(DJConnectSessionMediaPrepareResponse.self, from: data)
        guard response.success, response.contractVersion == 1, response.media.count <= targets.count else {
            throw DJConnectError.invalidResponse
        }
        var seen = Set<DJConnectSessionMedia.Target>()
        for media in response.media {
            guard media.schemaVersion == 1, media.sessionID == sessionID, let target = media.target,
                  targets.contains(target), seen.insert(target).inserted else { throw DJConnectError.invalidResponse }
        }
        return response.media
    }

    public func sessionArtworkPreparationRequest(sessionID: String, targets: [DJConnectSessionMedia.Target]) throws -> URLRequest {
        func valid(_ value: String) -> Bool {
            !value.isEmpty && value.utf8.count <= 512 && !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
        }
        guard valid(sessionID), !targets.isEmpty, targets.count <= 8, Set(targets).count == targets.count else {
            throw DJConnectError.invalidResponse
        }
        let values: [[String: String]] = try targets.map { target in
            switch target {
            case .moment(let id): guard valid(id) else { throw DJConnectError.invalidResponse }; return ["moment_id": id]
            case .entry(let id): guard valid(id) else { throw DJConnectError.invalidResponse }; return ["entry_id": id]
            }
        }
        var request = try jsonRequest(path: "/api/djconnect/v1/session/media/prepare",
            payload: DJConnectSessionMediaPrepareRequest(sessionID: sessionID, targets: values))
        request.timeoutInterval = 22
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    /// Owner-only optional media read. No preparation, provider lookup or retry
    /// of an effectful operation. Resource absence never becomes pairing loss.
    public func sessionArtwork(_ media: DJConnectSessionMedia, sessionID: String,
                               target: DJConnectSessionMedia.Target,
                               audience: DJConnectSessionMedia.Audience) async throws -> DJConnectSessionArtworkImage {
        guard let artwork = media.admittedArtwork(session: sessionID, target: target, audience: audience),
              let path = artwork.url, let width = artwork.width, let height = artwork.height else {
            throw DJConnectError.invalidResponse
        }
        var request = try pairedOwnerReadRequest(path: path)
        request.timeoutInterval = 8
        request.setValue("image/png, image/jpeg", forHTTPHeaderField: "Accept")
        let image = try await sessionArtworkTransport.load(request, width: width, height: height)
        try Task.checkCancellation()
        // Decode/transfer time cannot extend the original grant.
        guard media.admittedArtwork(session: sessionID, target: target, audience: audience) != nil else {
            throw DJConnectError.invalidResponse
        }
        return image
    }

    public func savedSessions(cursor: String? = nil) async throws -> DJConnectSessionHistoryPage {
        let page: DJConnectSessionHistoryPage = try await decodedResponse(
            for: sessionHistoryReadRequest(route: "session/history", cursor: cursor), using: sessionProjectionSession)
        guard page.success, page.schemaVersion == 1, page.sessions.count <= 50,
              page.sessions.allSatisfy(\.isContractValid) else { throw DJConnectError.invalidResponse }
        return page
    }

    public func sessionTimeline(sessionID: String, cursor: String? = nil, window: DJConnectHistoryWindow? = nil,
                                anchorEntryID: String? = nil, limit: Int = 20) async throws -> DJConnectSessionTimelinePage {
        guard window == nil || cursor == nil else { throw DJConnectError.invalidResponse }
        var query: [URLQueryItem] = []
        if let window { query.append(URLQueryItem(name: "window", value: window.rawValue)) }
        if let anchorEntryID { query.append(URLQueryItem(name: "anchor_entry_id", value: anchorEntryID)) }
        let page: DJConnectSessionTimelinePage = try await decodedResponse(
            for: sessionHistoryReadRequest(route: "session/history/" + historyPathComponent(sessionID), cursor: cursor, queryItems: query, limit: limit), using: sessionProjectionSession)
        guard page.success, page.schemaVersion == 1, page.session.isContractValid, page.session.id == sessionID,
              page.window == window?.rawValue, page.anchorEntryID == anchorEntryID,
              page.entries.count <= 50, page.entries.allSatisfy({ $0.sessionID == sessionID && $0.isContractValid }) else {
            throw DJConnectError.invalidResponse
        }
        if window != nil {
            guard page.windowLimit == limit, page.scanComplete != nil, page.nextCursor == nil else { throw DJConnectError.invalidResponse }
            if !page.entries.isEmpty {
                guard let lower = page.scannedOrderMin, let upper = page.scannedOrderMax, lower <= upper,
                      page.entries.allSatisfy({ $0.order >= lower && $0.order <= upper }) else { throw DJConnectError.invalidResponse }
            }
        }
        return page
    }

    public func searchSession(sessionID: String, query: String, cursor: String? = nil) async throws -> DJConnectSessionSearchPage {
        let page: DJConnectSessionSearchPage = try await decodedResponse(for: sessionHistoryReadRequest(
            route: "session/history/" + historyPathComponent(sessionID) + "/search", cursor: cursor,
            queryItems: [URLQueryItem(name: "q", value: query)]), using: sessionProjectionSession)
        guard page.success, page.schemaVersion == 1, page.sessionID == sessionID, page.query == query,
              page.normalization == "NFKC-casefold", page.highlightUnits == "utf16",
              page.matches.count <= 50, page.returnedCount == page.matches.count,
              page.matches.allSatisfy({ $0.sessionID == sessionID && $0.isContractValid }),
              page.complete == (page.nextCursor == nil),
              page.totalCount == nil || (page.complete && cursor == nil && page.totalCount == page.returnedCount) else {
            throw DJConnectError.invalidResponse
        }
        return page
    }

    public func openSavedSession(_ action: DJConnectSessionOpenAction) async throws -> DJConnectSessionOpenResponse {
        let payload = HistoryOpenPayload(deviceID: identity.deviceID, clientType: identity.clientType, action: action)
        let response: DJConnectSessionOpenResponse = try await decodedResponse(
            for: jsonRequest(path: Self.apiV1Path("session/history/open"), payload: payload), using: sessionProjectionSession)
        guard response.success, response.schemaVersion == 1, response.navigationOnly,
              response.session.isContractValid, response.entry.isContractValid, response.readOnly == response.session.readOnly,
              response.session.id == action.sessionID, response.entry.sessionID == action.sessionID,
              response.entry.id == action.entryID else { throw DJConnectError.invalidResponse }
        return response
    }

    public func sendSessionConversation(_ payload: DJConnectAskDJRequest) async throws -> DJConnectSessionConversationResponse {
        guard let context = payload.conversationContext, payload.clientMessageID?.isEmpty == false else { throw DJConnectError.invalidResponse }
        let response: DJConnectSessionConversationResponse = try await decodedResponse(
            for: askDJMessageRequest(payload), using: sessionProjectionSession)
        try validateConversation(response, context: context, inputType: "text")
        return response
    }

    public func profileConversationHistory() async throws -> DJConnectProfileConversationHistory {
        let response: DJConnectProfileConversationHistory
        if let scoped = try await webSocketFastPathResult({ fastPath, token in
            try await fastPath.profileConversationHistory(identity: makeDJConnectIdentity(deviceToken: token))
        }) { response = scoped }
        else {
            response = try await decodedResponse(for: sessionHistoryReadRequest(route: "ask_dj/history",
                queryItems: [URLQueryItem(name: "conversation_scope", value: "profile")]), using: sessionProjectionSession)
        }
        guard response.base.success == true, !response.ownerScope.isEmpty,
              response.base.messages.count <= 1000, response.historicalMatches.values.joined().allSatisfy(\.isContractValid) else {
            throw DJConnectError.invalidResponse
        }
        return response
    }

    public func clearProfileConversationHistory() async throws -> DJConnectProfileConversationHistory {
        try await decodedResponse(for: jsonRequest(path: Self.apiV1Path("ask_dj/history/clear"), payload: [
            "device_id": identity.deviceID, "client_type": identity.clientType.rawValue, "conversation_scope": "profile"
        ]), using: sessionProjectionSession)
    }

    public func sendSessionVoice(wavData: Data, context: DJConnectConversationContext,
                                 clientMessageID: String, language: String, mood: Int? = nil,
                                 djStyle: String? = nil, musicDNAKey: String? = nil) async throws -> DJConnectSessionConversationResponse {
        var request = try voiceRequest(wavData: wavData, mood: mood, djStyle: djStyle, musicDNAKey: musicDNAKey, language: language)
        request.setValue("profile", forHTTPHeaderField: "X-DJConnect-Conversation-Scope")
        request.setValue(clientMessageID, forHTTPHeaderField: "X-DJConnect-Client-Message-ID")
        request.setValue(context.sessionID, forHTTPHeaderField: "X-DJConnect-Session-ID")
        request.setValue(context.selectedEntry?.entryID, forHTTPHeaderField: "X-DJConnect-Entry-ID")
        request.setValue(context.selectedEntry?.sessionID, forHTTPHeaderField: "X-DJConnect-Reference-Session-ID")
        let response: DJConnectSessionConversationResponse = try await decodedResponse(for: request, using: sessionProjectionSession)
        try validateConversation(response, context: context, inputType: "voice")
        return response
    }

    public func sessionHistoryReadRequest(route: String, cursor: String? = nil,
                                         queryItems: [URLQueryItem] = [], limit: Int = 20) throws -> URLRequest {
        guard (1...50).contains(limit) else { throw DJConnectError.invalidResponse }
        var items = queryItems
        if route != "capabilities" { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try pairedOwnerReadRequest(path: Self.apiV1Path(route), queryItems: items)
    }

    /// Resource and projection GETs share the complete paired request identity.
    /// Identity headers alone do not satisfy the Core profile-context contract.
    private func pairedOwnerReadRequest(path: String, queryItems: [URLQueryItem] = []) throws -> URLRequest {
        var components = URLComponents(url: endpoint(path: path), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "device_id", value: identity.deviceID),
                                 URLQueryItem(name: "client_type", value: identity.clientType.rawValue)] + queryItems
        var request = try authenticatedRequest(url: components.url!)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        return request
    }

    private func historyPathComponent(_ id: String) throws -> String {
        guard !id.isEmpty, id.count <= 512, let encoded = id.addingPercentEncoding(
            withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))) else {
            throw DJConnectError.invalidResponse
        }
        return encoded
    }

    private func validateConversation(_ response: DJConnectSessionConversationResponse,
                                      context: DJConnectConversationContext, inputType: String) throws {
        guard response.conversation.schemaVersion == 1, !response.conversation.turnID.isEmpty,
              !response.ownerScope.isEmpty, response.historicalMatches.allSatisfy(\.isContractValid),
              response.conversation.context == context, response.conversation.inputType == inputType else {
            throw DJConnectError.invalidResponse
        }
    }

    private struct HistoryOpenPayload: Encodable {
        let deviceID: String
        let clientType: DJConnectClientType
        let action: DJConnectSessionOpenAction
        enum CodingKeys: String, CodingKey { case deviceID = "device_id", clientType = "client_type", action }
    }

    public var fastPathDiagnostics: DJConnectFastPathDiagnostics {
        get async {
            await webSocketFastPath?.diagnostics ?? DJConnectFastPathDiagnostics()
        }
    }

    public func prepareFastPath() async throws {
        try await webSocketFastPath?.prepare()
    }

    /// A live socket can lose its runtime during a config-entry reload. Verify
    /// the existing paired identity through canonical HTTP before deleting it.
    /// An HTML/proxy401 is not an authoritative DJConnect credential refusal.
    public func validatePairedIdentity() async throws {
        let request = try statusRequest(DJConnectStatusPayload(identity: identity, haPairingStatus: .paired))
        let (data, status) = try await dataAndStatusCodeResponse(for: request, acceptingStatuses: [401, 403])
        if status == 401 || status == 403 {
            let body = try? JSONDecoder().decode([String: DJConnectJSONValue].self, from: data)
            if body?["success"] == .bool(false),
               body?["error"] == .string("unauthorized") || body?["error"] == .string("pairing_revoked") {
                throw DJConnectError.authStale(statusCode: status, message: "Paired identity rejected by Home Assistant")
            }
            throw DJConnectError.server(statusCode: status, message: "Unqualified paired identity response")
        }
        let response = try JSONDecoder().decode(DJConnectEnvelope<DJConnectPlayback>.self, from: data)
        guard response.success else { throw DJConnectError.invalidResponse }
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
        language: String? = nil,
        profileContext: DJConnectProfileContext? = nil
    ) async throws -> DJConnectVoiceResponse {
        let request = try voiceRequest(wavData: wavData, mood: mood, djStyle: djStyle, musicDNAKey: musicDNAKey, language: language, profileContext: profileContext)
        return try await decodedResponse(for: request)
    }

    public func statusRequest(_ payload: DJConnectStatusPayload) throws -> URLRequest {
        var request = try jsonRequest(path: Self.apiV1Path("status"), payload: payload)
        // Status is a replayable reachability read. An unreachable LAN must not
        // hold startup/resume behind the generic API timeout before TLS fallback.
        request.timeoutInterval = (DJConnectHybridTransport.isLocalTransportCandidate(baseURL) ||
            DJConnectHomeAssistantWebSocketFastPath.isLocalHomeAssistantURL(baseURL)) ? 2 : 8
        return request
    }

    public func pairingRequest(_ payload: DJConnectPairingPayload) throws -> URLRequest {
        guard Self.deviceID(payload.deviceID, matches: payload.clientType, allowLegacyRaspberryPiPrefix: false) else {
            throw DJConnectError.invalidConfiguration("DJConnect pairing identity mismatch: device_id prefix does not match client_type.")
        }
        var request = URLRequest(url: endpoint(path: Self.apiV1Path("pair")))
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
        var request = try jsonRequest(path: Self.apiV1Path("command"), payload: payload)
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
        var request = try jsonRequest(path: Self.apiV1Path("ask"), payload: payload)
        request.timeoutInterval = 15
        return request
    }

    public func askDJMessageRequest(_ payload: DJConnectAskDJRequest) throws -> URLRequest {
        var request = try jsonRequest(path: Self.apiV1Path("ask_dj/message"), payload: payload)
        request.timeoutInterval = 30
        return request
    }

    public func askDJHistoryRequest(sinceRevision: Int? = nil) throws -> URLRequest {
        var components = URLComponents(url: endpoint(path: Self.apiV1Path("ask_dj/history")), resolvingAgainstBaseURL: false)
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

    public func clearAskDJHistoryRequest(musicDNAKey: String? = nil, profileContext: DJConnectProfileContext? = nil) throws -> URLRequest {
        try jsonRequest(
            path: Self.apiV1Path("ask_dj/history/clear"),
            payload: DJConnectAskDJClearHistoryRequest(identity: identity, musicDNAKey: musicDNAKey, profileContext: profileContext)
        )
    }

    public func exportAskDJHistoryRequest() throws -> URLRequest {
        try jsonRequest(
            path: Self.apiV1Path("ask_dj/history/export"),
            payload: DJConnectAskDJHistoryExportRequest(identity: identity)
        )
    }

    public func musicDNAProfileRequest(mood: Int? = nil, musicDNAKey: String? = nil, language: String? = nil, profileContext: DJConnectProfileContext? = nil) throws -> URLRequest {
        try musicDNARequest(
            path: Self.apiV1Path("music_dna/profile"),
            payload: DJConnectMusicDNAIdentityRequest(identity: identity, mood: mood, musicDNAKey: musicDNAKey, language: language, profileContext: profileContext),
            mood: mood,
            musicDNAKey: musicDNAKey,
            language: language
        )
    }

    public func musicDNASettingsRequest(enabled: Bool, mood: Int? = nil, musicDNAKey: String? = nil, language: String? = nil, profileContext: DJConnectProfileContext? = nil) throws -> URLRequest {
        try musicDNARequest(
            path: Self.apiV1Path("music_dna/settings"),
            payload: DJConnectMusicDNASettingsRequest(identity: identity, enabled: enabled, mood: mood, musicDNAKey: musicDNAKey, language: language, profileContext: profileContext),
            mood: mood,
            musicDNAKey: musicDNAKey,
            language: language
        )
    }

    public func clearMusicDNARequest(mood: Int? = nil, musicDNAKey: String? = nil, language: String? = nil, profileContext: DJConnectProfileContext? = nil) throws -> URLRequest {
        try musicDNARequest(
            path: Self.apiV1Path("music_dna/clear"),
            payload: DJConnectMusicDNAIdentityRequest(identity: identity, mood: mood, musicDNAKey: musicDNAKey, language: language, profileContext: profileContext),
            mood: mood,
            musicDNAKey: musicDNAKey,
            language: language
        )
    }

    public func importMusicDNARequest(_ profile: DJConnectMusicDNAProfileResponse, mood: Int? = nil, musicDNAKey: String? = nil, language: String? = nil) throws -> URLRequest {
        try musicDNARequest(
            path: Self.apiV1Path("music_dna/import"),
            payload: DJConnectMusicDNAImportRequest(identity: identity, profile: profile, mood: mood, musicDNAKey: musicDNAKey, language: language),
            mood: mood,
            musicDNAKey: musicDNAKey,
            language: language
        )
    }

    public func exportMusicDNARequest(musicDNAKey: String? = nil, language: String? = nil) throws -> URLRequest {
        try musicDNARequest(
            path: Self.apiV1Path("music_dna/export"),
            payload: DJConnectMusicDNAExportRequest(identity: identity, musicDNAKey: musicDNAKey, language: language),
            mood: nil,
            musicDNAKey: musicDNAKey,
            language: language
        )
    }

    public func musicDiscoveryFeedRequest(musicDNAKey: String? = nil, language: String? = nil, profileContext: DJConnectProfileContext? = nil) throws -> URLRequest {
        let endpoint = endpointWithProfileContext(path: Self.apiV1Path("music_discovery"), profileContext: profileContext)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw DJConnectError.invalidConfiguration("Invalid Discover endpoint")
        }
        if let musicDNAKey, !musicDNAKey.isEmpty {
            var query = components.queryItems ?? []
            query.removeAll { $0.name == "music_dna_key" }
            query.append(URLQueryItem(name: "music_dna_key", value: musicDNAKey))
            components.queryItems = query
        }
        guard let url = components.url else { throw DJConnectError.invalidConfiguration("Invalid Discover endpoint") }
        var request = try authenticatedRequest(url: url)
        request.httpMethod = "GET"
        applyMusicDNAHeaders(to: &request, mood: nil, musicDNAKey: musicDNAKey, language: language)
        applyProfileContextHeaders(to: &request, profileContext: profileContext)
        return request
    }

    public func refreshMusicDiscoveryRequest(musicDNAKey: String? = nil, language: String? = nil) throws -> URLRequest {
        try musicDNARequest(
            path: Self.apiV1Path("music_discovery/refresh"),
            payload: DJConnectMusicDNAIdentityRequest(identity: identity, musicDNAKey: musicDNAKey, language: language),
            mood: nil,
            musicDNAKey: musicDNAKey,
            language: language
        )
    }

    public func musicDiscoveryPlayRequest(_ payload: DJConnectMusicDiscoveryPlayRequest) throws -> URLRequest {
        try musicDNARequest(
            path: Self.apiV1Path("music_discovery/play"),
            payload: payload,
            mood: nil,
            musicDNAKey: payload.musicDNAKey,
            language: nil
        )
    }

    public func musicDiscoveryFeedbackRequest(_ payload: DJConnectMusicDiscoveryFeedbackRequest) throws -> URLRequest {
        try musicDNARequest(
            path: Self.apiV1Path("music_discovery/feedback"),
            payload: payload,
            mood: nil,
            musicDNAKey: payload.musicDNAKey,
            language: nil
        )
    }

    public func webSocketSessionRequest() throws -> URLRequest {
        var request = try jsonRequest(
            path: Self.apiV1Path("websocket/session"),
            payload: DJConnectWebSocketSessionRequest()
        )
        request.timeoutInterval = 8
        return request
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
        var request = try jsonRequest(path: Self.apiV1Path("ask_dj/idle_suggestion"), payload: payload)
        request.timeoutInterval = 15
        return request
    }

    public func trackInsightRequest(_ payload: DJConnectTrackInsightRequest) throws -> URLRequest {
        let normalizedPayload = payload.normalizedForSend(identity: identity)
        var request = try jsonRequest(path: Self.apiV1Path("track_insight"), payload: normalizedPayload)
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
        var components = URLComponents(url: endpoint(path: Self.apiV1Path("vibecast")), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "device_id", value: identity.deviceID),
            URLQueryItem(name: "client_id", value: identity.deviceID),
            URLQueryItem(name: "client_type", value: identity.clientType.rawValue),
            URLQueryItem(name: "device_name", value: identity.deviceName),
            URLQueryItem(name: "app_version", value: identity.appVersion),
            URLQueryItem(name: "protocol_version", value: identity.protocolVersion ?? identity.firmware)
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
        request.setValue(identity.protocolVersion ?? identity.firmware, forHTTPHeaderField: "X-DJConnect-Protocol-Version")
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

    public func sessionStartRequest(_ payload: DJConnectSessionStartRequest) throws -> URLRequest {
        try jsonRequest(path: Self.apiV1Path("session/start"), payload: payload)
    }

    public func activeSessionRequest() throws -> URLRequest {
        var components = URLComponents(url: endpoint(path: Self.apiV1Path("session/active")), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "device_id", value: identity.deviceID),
            URLQueryItem(name: "client_type", value: identity.clientType.rawValue)
        ]
        guard let url = components?.url else {
            throw DJConnectError.invalidConfiguration("Invalid Session URL.")
        }
        var request = try authenticatedRequest(url: url)
        request.httpMethod = "GET"
        return request
    }

    public func sessionEndRequest(_ payload: DJConnectSessionEndRequest) throws -> URLRequest {
        try jsonRequest(path: Self.apiV1Path("session/end"), payload: payload)
    }

    public func vibeCastHandoffApprovalRequest(_ payload: DJConnectVibeCastHandoffApprovalRequest) throws -> URLRequest {
        try jsonRequest(path: Self.apiV1Path("session/broadcast/handoff/approve"), payload: payload)
    }

    public func pushRegisterRequest(_ payload: DJConnectPushRegistrationRequest) throws -> URLRequest {
        try jsonRequest(path: Self.apiV1Path("push/register"), payload: payload)
    }

    public func pushUnregisterRequest(_ payload: DJConnectPushUnregistrationRequest) throws -> URLRequest {
        try jsonRequest(path: Self.apiV1Path("push/unregister"), payload: payload)
    }

    public func voiceRequest(
        wavData: Data,
        mood: Int? = nil,
        djStyle: String? = nil,
        musicDNAKey: String? = nil,
        language: String? = nil,
        profileContext: DJConnectProfileContext? = nil
    ) throws -> URLRequest {
        guard wavData.count <= DJConnectAudioFileLoader.defaultMaxVoiceWAVBytes else {
            throw DJConnectError.invalidConfiguration("Voice recording is too large. Try a shorter Ask DJ recording.")
        }
        var request = try authenticatedRequest(path: Self.apiV1Path("voice"))
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
        applyProfileContextHeaders(to: &request, profileContext: profileContext)
        request.httpBody = wavData
        return request
    }

    private func endpointWithProfileContext(path: String, profileContext: DJConnectProfileContext?) -> URL {
        let url = endpoint(path: path)
        guard let profileContext else {
            return url
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        if let profileID = Self.nonBlankLanguage(profileContext.profileID) {
            queryItems.append(URLQueryItem(name: "profile_id", value: profileID))
        }
        if let sessionID = Self.nonBlankLanguage(profileContext.sessionID) {
            queryItems.append(URLQueryItem(name: "session_id", value: sessionID))
        }
        if let privateSession = profileContext.privateSession {
            queryItems.append(URLQueryItem(name: "private_session", value: privateSession ? "true" : "false"))
        }
        if let requestSource = profileContext.requestSource {
            queryItems.append(URLQueryItem(name: "request_source", value: requestSource.rawValue))
        }
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        return components?.url ?? url
    }

    private func applyProfileContextHeaders(to request: inout URLRequest, profileContext: DJConnectProfileContext?) {
        guard let profileContext else {
            return
        }
        if let profileID = Self.nonBlankLanguage(profileContext.profileID) {
            request.setValue(profileID, forHTTPHeaderField: "X-DJConnect-Profile-ID")
        }
        if let sessionID = Self.nonBlankLanguage(profileContext.sessionID) {
            request.setValue(sessionID, forHTTPHeaderField: "X-DJConnect-Session-ID")
        }
        if let privateSession = profileContext.privateSession {
            request.setValue(privateSession ? "true" : "false", forHTTPHeaderField: "X-DJConnect-Private-Session")
        }
        if let requestSource = profileContext.requestSource {
            request.setValue(requestSource.rawValue, forHTTPHeaderField: "X-DJConnect-Request-Source")
        }
    }

    public func classify(statusCode: Int, body: Data? = nil, networkError: Error? = nil) -> DJConnectError? {
        if let networkError {
            return .network(message: networkError.localizedDescription)
        }

        let envelope = body.flatMap { try? decoder.decode(DJConnectErrorEnvelope.self, from: $0) }
        let message = Self.redactedDiagnosticText(envelope?.message) ?? body.flatMap(Self.redactedResponseBodyMessage(from:))

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

        if let rawError = envelope?.error,
           let profileCode = DJConnectError.ProfileCode(rawValue: rawError) {
            return .profile(code: profileCode, statusCode: statusCode, message: message)
        }

        if statusCode == 401 || statusCode == 403 {
            return .authStale(statusCode: statusCode, message: message)
        }

        // A typed backend failure can carry an upstream device/resource 404.
        // It does not mean that the Home Assistant API route is absent.
        if envelope?.error == "backend_unavailable" || envelope?.error == "playback_backend_unavailable" || envelope?.backendAvailable == false {
            return .backendUnavailable(message: message)
        }

        if statusCode == 404 {
            return .routeMissing(message: message)
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
        let redacted = redactedDiagnosticText(rawBody) ?? rawBody
        return String(redacted.prefix(500))
    }

    private static func redactedDiagnosticText(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return DJConnectLogRedactor.redactText(value)
    }

    private static func nonBlankLanguage(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func decodedResponse<T: Decodable>(for request: URLRequest, using requestSession: URLSession? = nil) async throws -> T {
        let (data, statusCode) = try await dataAndStatusCodeResponse(for: request, using: requestSession)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw DJConnectError.decodingFailed(
                statusCode: statusCode,
                endpoint: Self.requestSummary(request),
                message: requestSession == nil ? Self.decodingFailureMessage(error: error, body: data) : "Session projection decode failed; response_body=<omitted>"
            )
        }
    }

    private func dataResponse(for request: URLRequest) async throws -> Data {
        let (data, _) = try await dataAndStatusCodeResponse(for: request)
        return data
    }

    private func dataAndStatusCodeResponse(for request: URLRequest, using requestSession: URLSession? = nil,
                                          acceptingStatuses: Set<Int> = []) async throws -> (Data, Int) {
        if let hybridTransport, DJConnectHybridTransport.operation(for: request) != nil || DJConnectHybridTransport.isActiveRead(request) {
            do {
                let (data, status) = try await hybridTransport.perform(request)
                if !acceptingStatuses.contains(status), let error = classify(statusCode: status, body: data) { throw error }
                return (data, status)
            } catch DJConnectHybridTransportError.authority(let code) {
                if ["unauthorized", "pairing_revoked"].contains(code) { throw DJConnectError.authStale(statusCode: 401, message: code) }
                throw DJConnectError.profile(code: .profileAccessDenied, statusCode: 403, message: code)
            }
        }
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await (requestSession ?? session).data(for: request)
        } catch {
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            if !DJConnectHybridTransport.canReplayLegacy(request) { throw DJConnectHybridTransportError.deliveryUnknown }
            throw DJConnectError.network(message: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DJConnectError.invalidResponse
        }
        responseLogger?(Self.requestSummary(request), httpResponse.statusCode)
        try DJConnectIncomingPayloadLimiter.validate(contentLength: httpResponse.expectedContentLength)
        try DJConnectIncomingPayloadLimiter.validate(data)

        if !acceptingStatuses.contains(httpResponse.statusCode), let error = classify(statusCode: httpResponse.statusCode, body: data) {
            let safeError = requestSession == nil ? error : Self.sessionProjectionError(error)
            logAPIFailure(request: request, statusCode: httpResponse.statusCode, body: requestSession == nil ? data : Data(), error: safeError)
            throw safeError
        }

        return (data, httpResponse.statusCode)
    }

    private static func sessionProjectionError(_ error: DJConnectError) -> DJConnectError {
        switch error {
        case .backendUnavailable: return .backendUnavailable(message: nil)
        case let .authStale(status, _): return .authStale(statusCode: status, message: nil)
        case .notConfigured: return .notConfigured(message: nil)
        case .routeMissing: return .routeMissing(message: nil)
        case let .server(status, _): return .server(statusCode: status, message: nil)
        case let .profile(code, status, _): return .profile(code: code, statusCode: status, message: nil)
        default: return error
        }
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

    private func webSocketMusicDNAProfileIfSupported(mood: Int?, musicDNAKey: String?, language: String?) async throws -> DJConnectMusicDNAProfileResponse? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.musicDNAProfile(
                identity: makeDJConnectIdentity(deviceToken: token),
                mood: mood,
                musicDNAKey: musicDNAKey,
                language: language
            )
        }
    }

    private func webSocketMusicDNASettingsIfSupported(_ enabled: Bool, mood: Int?, musicDNAKey: String?, language: String?) async throws -> DJConnectMusicDNAProfileResponse? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.setMusicDNAEnabled(
                enabled,
                identity: makeDJConnectIdentity(deviceToken: token),
                mood: mood,
                musicDNAKey: musicDNAKey,
                language: language
            )
        }
    }

    private func webSocketMusicDNAClearIfSupported(mood: Int?, musicDNAKey: String?, language: String?) async throws -> DJConnectMusicDNAProfileResponse? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.clearMusicDNA(
                identity: makeDJConnectIdentity(deviceToken: token),
                mood: mood,
                musicDNAKey: musicDNAKey,
                language: language
            )
        }
    }

    private func webSocketMusicDiscoveryRefreshIfSupported(musicDNAKey: String?, language: String?) async throws -> DJConnectMusicDiscoveryResponse? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.refreshMusicDiscovery(
                identity: makeDJConnectIdentity(deviceToken: token),
                musicDNAKey: musicDNAKey,
                language: language
            )
        }
    }

    private func webSocketMusicDiscoveryFeedIfSupported(musicDNAKey: String?, language: String?) async throws -> DJConnectMusicDiscoveryResponse? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.musicDiscoveryFeed(
                identity: makeDJConnectIdentity(deviceToken: token),
                musicDNAKey: musicDNAKey,
                language: language
            )
        }
    }

    private func webSocketMusicDiscoveryPlayIfSupported(_ payload: DJConnectMusicDiscoveryPlayRequest) async throws -> DJConnectCommandResponse? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.playMusicDiscoveryItem(payload, identity: makeDJConnectIdentity(deviceToken: token))
        }
    }

    private func webSocketMusicDiscoveryFeedbackIfSupported(_ payload: DJConnectMusicDiscoveryFeedbackRequest) async throws -> DJConnectCommandResponse? {
        try await webSocketFastPathResult { fastPath, token in
            try await fastPath.sendMusicDiscoveryFeedback(payload, identity: makeDJConnectIdentity(deviceToken: token))
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
        try Task.checkCancellation()
        do {
            let result = try await operation(webSocketFastPath, loadedToken())
            try Task.checkCancellation()
            return result
        } catch {
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            // A rejected operation is an authoritative answer, not a transport
            // failure. Replaying it over HTTP can duplicate a write or hide a
            // Profile/authentication rejection.
            if let error = error as? DJConnectError {
                switch error {
                case .routeMissing, .network, .invalidResponse:
                    return nil
                default:
                    throw error
                }
            }
            if error is URLError { return nil }
            throw error
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
            serverMessage: Self.redactedDiagnosticText(envelope?.message) ?? Self.redactedResponseBodyMessage(from: body),
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
        if path.hasPrefix("/api/djconnect/v1/session/history/") && !path.hasSuffix("/open") {
            return "\(method) /api/djconnect/v1/session/history/{session_id}" + (path.hasSuffix("/search") ? "/search" : "")
        }
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
        case .payloadTooLarge:
            return "payload_too_large"
        case let .profile(code, _, _):
            return code.rawValue
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

    private static func apiV1Path(_ route: String) -> String {
        "/api/djconnect/v1/" + route.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

// MARK: - Explicit passive Session presentation (frozen v1)
public extension DJConnectClient {
    func passiveSurfaceAvailable() async throws -> Bool {
        struct Capability: Decodable {
            struct Descriptor: Decodable {
                let version: Int
                let owner_only: Bool
                let authentication: String
                let authorize_path: String
                let read_path: String
                let surfaces: [String]
                let explicit_consent_required: Bool
                let max_cache_seconds: Int
                let read_side_effects: Bool
                let background_delivery: Bool
                let watch_replication: Bool
            }
            let success: Bool
            let passive_session_surface: Descriptor?
        }
        let request = try sessionHistoryReadRequest(route: "capabilities")
        let response = try decoder.decode(Capability.self, from: await sessionArtworkTransport.prepare(request))
        guard response.success, let c = response.passive_session_surface else { return false }
        return c.version == 1 && c.owner_only && c.authentication == "paired_device_bearer" &&
            c.authorize_path == "/api/djconnect/v1/session/surface/authorize" &&
            c.read_path == "/api/djconnect/v1/session/surface/read" &&
            Set(c.surfaces) == Set(DJConnectPassiveSurface.allCases.map(\.rawValue)) && c.explicit_consent_required &&
            c.max_cache_seconds == 120 && !c.read_side_effects && !c.background_delivery && !c.watch_replication
    }

    /// Call only for an explicit foreground choice bound to the current Session.
    /// A lost authorize response must not be replayed: it replaces the generation.
    func authorizePassiveSurface(sessionID: String, surface: DJConnectPassiveSurface, enabled: Bool) async throws -> DJConnectPassiveSurfaceResponse? {
        guard DJConnectPassiveSession.identifier(sessionID), [.ios, .macos].contains(identity.clientType) else { throw DJConnectError.invalidResponse }
        let body: [String: Any] = ["contract_version": 1, "device_id": identity.deviceID, "client_type": identity.clientType.rawValue,
            "session_id": sessionID, "surface": surface.rawValue, "enabled": enabled,
            "os_snapshot_cache": enabled, "locked_display": enabled]
        let request = try passiveSurfacePOST(path: "authorize", body: body)
        let data = try await sessionArtworkTransport.prepare(request)
        if !enabled {
            struct Disabled: Decodable { let success: Bool; let contract_version: Int; let state: String }
            let r = try decoder.decode(Disabled.self, from: data)
            guard r.success, r.contract_version == 1, r.state == "disabled" else { throw DJConnectError.invalidResponse }
            return nil
        }
        let r = try decoder.decode(DJConnectPassiveSurfaceResponse.self, from: data)
        guard r.validates(sessionID: sessionID, surface: surface) else { throw DJConnectError.invalidResponse }
        return r
    }

    func readPassiveSurface(sessionID: String, surface: DJConnectPassiveSurface, grantID: String) async throws -> DJConnectPassiveSurfaceResponse {
        guard DJConnectPassiveSession.identifier(sessionID), DJConnectPassiveSession.identifier(grantID) else { throw DJConnectError.invalidResponse }
        let request = try passiveSurfacePOST(path: "read", body: ["contract_version": 1, "device_id": identity.deviceID,
            "client_type": identity.clientType.rawValue, "session_id": sessionID, "surface": surface.rawValue, "grant_id": grantID])
        let r = try decoder.decode(DJConnectPassiveSurfaceResponse.self, from: await sessionArtworkTransport.prepare(request))
        guard r.validates(sessionID: sessionID, surface: surface), r.grant_id == grantID else { throw DJConnectError.invalidResponse }
        return r
    }

    func passiveSurfaceImage(_ artwork: DJConnectPassiveSession.Artwork, response: DJConnectPassiveSurfaceResponse) async throws -> DJConnectSessionArtworkImage {
        let p = response.passive_session
        guard response.validates(sessionID: p.session_id, surface: p.surface), p.isCurrent(at: Date()),
              p.currentArtwork(slot: artwork.slot, at: Date()) == artwork else { throw DJConnectError.invalidResponse }
        let request = try pairedOwnerReadRequest(path: artwork.image_path, queryItems: [
            .init(name: "contract_version", value: "1"), .init(name: "surface", value: p.surface.rawValue),
            .init(name: "grant_id", value: response.grant_id)])
        return try await sessionArtworkTransport.load(request, width: artwork.width, height: artwork.height)
    }

    private func passiveSurfacePOST(path: String, body: [String: Any]) throws -> URLRequest {
        var request = try authenticatedRequest(path: "/api/djconnect/v1/session/surface/" + path)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}
