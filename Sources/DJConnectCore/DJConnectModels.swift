import Foundation

public enum DJConnectApplicationVersion {
    public static var releaseVersion: String {
        bundleValue(for: "CFBundleShortVersionString")
    }

    public static var buildVersion: String {
        bundleValue(for: "CFBundleVersion")
    }

    private static func bundleValue(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return "unknown"
        }
        return value
    }
}

public enum DJConnectProtocolVersion {
    public static let current = "3.2.33"
}

public enum DJConnectClientType: String, Codable, Sendable {
    case ios
    case macos
    case watchos
    case esp32
    case raspberryPi = "raspberry_pi"
    case windows
}

public enum DJConnectPlatform: String, Codable, Sendable {
    case ios
    case macos
    case watchos
}

public enum DJConnectWatchProxyOperation: String, Codable, Sendable {
    case status
    case command
    case trackInsight = "track_insight"
    case askDJHistory = "ask_dj_history"
    case clearAskDJHistory = "clear_ask_dj_history"
    case askDJMessage = "ask_dj_message"
    case askDJIdleSuggestion = "ask_dj_idle_suggestion"
    case musicDNAProfile = "music_dna_profile"
    case musicDNASettings = "music_dna_settings"
    case clearMusicDNA = "clear_music_dna"
    case musicDiscovery = "music_discovery"
    case musicDiscoveryRefresh = "music_discovery_refresh"
    case musicDiscoveryPlay = "music_discovery_play"
    case voice
    case pushRegister = "push_register"
    case pushUnregister = "push_unregister"
}

public struct DJConnectWatchProxyRequest: Codable, Sendable {
    public var operation: DJConnectWatchProxyOperation
    public var payload: Data?

    public init(operation: DJConnectWatchProxyOperation, payload: Data? = nil) {
        self.operation = operation
        self.payload = payload
    }
}

public struct DJConnectWatchProxyResponse: Codable, Sendable {
    public var success: Bool
    public var payload: Data?
    public var error: String?
    public var message: String?

    public init(success: Bool, payload: Data? = nil, error: String? = nil, message: String? = nil) {
        self.success = success
        self.payload = payload
        self.error = error
        self.message = message
    }
}

public struct DJConnectWatchProxyVoicePayload: Codable, Sendable {
    public var wavData: Data
    public var mood: Int?
    public var djStyle: String?
    public var musicDNAKey: String?
    public var language: String?

    public init(wavData: Data, mood: Int? = nil, djStyle: String? = nil, musicDNAKey: String? = nil, language: String? = nil) {
        self.wavData = wavData
        self.mood = mood
        self.djStyle = djStyle
        self.musicDNAKey = musicDNAKey
        self.language = language
    }
}

public enum DJConnectPushEnvironment: String, Codable, Sendable {
    case sandbox
    case production

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch rawValue {
        case "sandbox", "development", "develop":
            self = .sandbox
        case "production", "prod":
            self = .production
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported push environment: \(rawValue)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public func isCompatible(with responseEnvironment: DJConnectPushEnvironment?) -> Bool {
        guard let responseEnvironment else { return true }
        return self == responseEnvironment
    }
}

public enum DJConnectPairingStatus: String, Codable, Sendable {
    case unpaired
    case pairing
    case waitingForHomeAssistantCompletion = "waiting_for_home_assistant_completion"
    case paired
    case stale
}

public enum DJConnectState: String, Codable, Sendable {
    case online
    case offline
}

public enum DJConnectRepeatState: String, Codable, Sendable {
    case off
    case track
    case context
}

public struct DJConnectIdentity: Codable, Equatable, Sendable {
    public var clientName: String
    public var deviceID: String
    public var deviceName: String
    public var clientType: DJConnectClientType
    public var firmware: String
    public var appVersion: String?
    public var protocolVersion: String?
    public var platform: DJConnectPlatform

    public init(
        clientName: String? = nil,
        deviceID: String,
        deviceName: String,
        clientType: DJConnectClientType,
        firmware: String,
        appVersion: String? = nil,
        protocolVersion: String? = nil,
        platform: DJConnectPlatform
    ) {
        self.clientName = clientName ?? deviceName
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.clientType = clientType
        self.firmware = firmware
        self.appVersion = appVersion
        self.protocolVersion = protocolVersion
        self.platform = platform
    }

    enum CodingKeys: String, CodingKey {
        case clientName = "client_name"
        case deviceID = "device_id"
        case deviceName = "device_name"
        case clientType = "client_type"
        case firmware
        case appVersion = "app_version"
        case protocolVersion = "protocol_version"
        case platform
    }
}

public struct DJConnectAPIIdentity: Codable, Equatable, Sendable {
    public var clientType: DJConnectClientType
    public var clientID: String
    public var deviceID: String
    public var deviceName: String
    public var deviceToken: String?
    public var appVersion: String?
    public var protocolVersion: String?

    public init(identity: DJConnectIdentity, deviceToken: String? = nil) {
        self.clientType = identity.clientType
        self.clientID = identity.deviceID
        self.deviceID = identity.deviceID
        self.deviceName = identity.deviceName
        self.deviceToken = deviceToken
        self.appVersion = identity.appVersion
        self.protocolVersion = identity.protocolVersion ?? identity.firmware
    }

    enum CodingKeys: String, CodingKey {
        case clientType = "client_type"
        case clientID = "client_id"
        case deviceID = "device_id"
        case deviceName = "device_name"
        case deviceToken = "device_token"
        case appVersion = "app_version"
        case protocolVersion = "protocol_version"
    }
}

public enum DJConnectProfileRequestSource: String, Codable, Equatable, Sendable {
    case askDJ = "ask_dj"
    case deviceCommand = "device_command"
    case voice
    case trackInsight = "track_insight"
    case discover
}

public struct DJConnectProfileContext: Codable, Equatable, Sendable {
    public var profileID: String?
    public var sessionID: String?
    public var privateSession: Bool?
    public var requestSource: DJConnectProfileRequestSource?

    public init(
        profileID: String? = nil,
        sessionID: String? = nil,
        privateSession: Bool? = nil,
        requestSource: DJConnectProfileRequestSource? = nil
    ) {
        self.profileID = profileID?.nilIfBlank
        self.sessionID = sessionID?.nilIfBlank
        self.privateSession = privateSession
        self.requestSource = requestSource
    }

    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case sessionID = "session_id"
        case privateSession = "private_session"
        case requestSource = "request_source"
    }
}

public struct DJConnectResolvedProfile: Codable, Equatable, Sendable {
    public var id: String
    public var name: String?
    public var type: String?
    public var privacyMode: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case privacyMode = "privacy_mode"
    }
}

public struct DJConnectProfileResolution: Codable, Equatable, Sendable {
    public var source: String?
    public var fallbackUsed: Bool?

    enum CodingKeys: String, CodingKey {
        case source
        case fallbackUsed = "fallback_used"
    }
}

public protocol DJConnectProfileContextCarrier {
    var profileID: String? { get set }
    var sessionID: String? { get set }
    var privateSession: Bool? { get set }
    var requestSource: DJConnectProfileRequestSource? { get set }
}

public struct DJConnectIdentifiedRequestPayload<Payload: Encodable>: Encodable {
    public var identity: DJConnectAPIIdentity
    public var sourcePayload: Payload
    public var includeNestedPayload: Bool

    public init(identity: DJConnectAPIIdentity, payload: Payload, includeNestedPayload: Bool = true) {
        self.identity = identity
        self.sourcePayload = payload
        self.includeNestedPayload = includeNestedPayload
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DJConnectDynamicCodingKey.self)
        try container.encode(identity, forKey: DJConnectDynamicCodingKey("identity"))
        try container.encode(identity.clientType, forKey: DJConnectDynamicCodingKey("client_type"))
        try container.encode(identity.clientID, forKey: DJConnectDynamicCodingKey("client_id"))
        try container.encode(identity.deviceID, forKey: DJConnectDynamicCodingKey("device_id"))
        try container.encode(identity.deviceName, forKey: DJConnectDynamicCodingKey("device_name"))
        try container.encodeIfPresent(identity.deviceToken, forKey: DJConnectDynamicCodingKey("device_token"))

        let payloadFields = try Self.payloadFields(from: sourcePayload)
        if let profileContext = sourcePayload as? DJConnectProfileContextCarrier {
            try container.encodeIfPresent(profileContext.profileID?.nilIfBlank, forKey: DJConnectDynamicCodingKey("profile_id"))
            try container.encodeIfPresent(profileContext.sessionID?.nilIfBlank, forKey: DJConnectDynamicCodingKey("session_id"))
            try container.encodeIfPresent(profileContext.privateSession, forKey: DJConnectDynamicCodingKey("private_session"))
            try container.encodeIfPresent(profileContext.requestSource, forKey: DJConnectDynamicCodingKey("request_source"))
        }
        for (key, value) in payloadFields where key != "identity" && key != "payload" {
            try container.encode(value, forKey: DJConnectDynamicCodingKey(key))
        }
        if includeNestedPayload {
            try container.encode(
                DJConnectIdentifiedRequestPayload(identity: identity, payload: sourcePayload, includeNestedPayload: false),
                forKey: DJConnectDynamicCodingKey("payload")
            )
        }
    }

    private static func payloadFields(from payload: Payload) throws -> [String: DJConnectJSONValue] {
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(DJConnectJSONValue.self, from: data)
        guard case let .object(fields) = decoded else {
            return ["value": decoded]
        }
        return fields
    }
}

public struct DJConnectWebSocketSessionRequest: Codable, Equatable, Sendable {
    public var requestedCommands: [String]

    enum CodingKeys: String, CodingKey {
        case requestedCommands = "requested_commands"
    }

    public init(requestedCommands: [String] = DJConnectFastPathRoute.allCases.map(\.rawValue)) {
        self.requestedCommands = requestedCommands
    }
}

public struct DJConnectWebSocketSessionResponse: Codable, Equatable, Sendable {
    public var success: Bool
    public var accessToken: String?
    public var expiresAt: String?
    public var websocketURL: String?
    public var commands: [String]
    public var error: String?
    public var message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case accessToken = "access_token"
        case expiresAt = "expires_at"
        case websocketURL = "websocket_url"
        case commands
        case error
        case message
    }

    public init(
        success: Bool,
        accessToken: String? = nil,
        expiresAt: String? = nil,
        websocketURL: String? = nil,
        commands: [String] = [],
        error: String? = nil,
        message: String? = nil
    ) {
        self.success = success
        self.accessToken = accessToken?.nilIfBlank
        self.expiresAt = expiresAt?.nilIfBlank
        self.websocketURL = websocketURL?.nilIfBlank
        self.commands = commands
        self.error = error?.nilIfBlank
        self.message = message?.nilIfBlank
    }

    public var resolvedAccessToken: String? {
        accessToken?.nilIfBlank
    }

    public var resolvedExpiryDate: Date? {
        guard let expiresAt else {
            return nil
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: expiresAt) {
            return date
        }
        return ISO8601DateFormatter().date(from: expiresAt)
    }
}

public struct DJConnectDynamicCodingKey: CodingKey, Hashable, Sendable {
    public var stringValue: String
    public var intValue: Int?

    public init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init?(stringValue: String) {
        self.init(stringValue)
    }

    public init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

public struct DJConnectPairingPayload: Codable, Equatable, Sendable {
    public var deviceID: String
    public var deviceName: String
    public var clientType: DJConnectClientType
    public var firmware: String
    public var appVersion: String?
    public var protocolVersion: String?
    public var platform: DJConnectPlatform
    public var pairingToken: String
    public var pairCode: String
    public var pairingCode: String
    public var haLocalURL: String?
    public var haRemoteURL: String?
    public var assistPipelineID: String?
    public var bootstrapProof: String?

    public init(
        identity: DJConnectIdentity,
        pairingToken: String,
        haLocalURL: String? = nil,
        haRemoteURL: String? = nil,
        assistPipelineID: String? = nil,
        bootstrapProof: String? = nil
    ) {
        self.deviceID = identity.deviceID
        self.deviceName = identity.deviceName
        self.clientType = identity.clientType
        self.firmware = identity.firmware
        self.appVersion = identity.appVersion
        self.protocolVersion = identity.protocolVersion ?? identity.firmware
        self.platform = identity.platform
        self.pairingToken = pairingToken
        self.pairCode = pairingToken
        self.pairingCode = pairingToken
        self.haLocalURL = haLocalURL
        self.haRemoteURL = haRemoteURL
        self.assistPipelineID = assistPipelineID
        self.bootstrapProof = bootstrapProof
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case deviceName = "device_name"
        case clientType = "client_type"
        case firmware
        case appVersion = "app_version"
        case protocolVersion = "protocol_version"
        case platform
        case pairingToken = "pairing_token"
        case pairCode = "pair_code"
        case pairingCode = "pairing_code"
        case haLocalURL = "ha_local_url"
        case haRemoteURL = "ha_remote_url"
        case assistPipelineID = "assist_pipeline_id"
        case bootstrapProof = "bootstrap_proof"
    }
}

public struct DJConnectPairingDeepLink: Equatable, Sendable {
    public static let canonicalPairPath = "/api/djconnect/v1/pair"
    private static let legacyPairPath = "/api/djconnect/pair"

    public var homeAssistantURL: String
    public var pairCode: String
    public var clientType: DJConnectClientType
    public var pairPath: String

    public init(
        homeAssistantURL: String,
        pairCode: String,
        clientType: DJConnectClientType,
        pairPath: String = DJConnectPairingDeepLink.canonicalPairPath
    ) {
        self.homeAssistantURL = homeAssistantURL
        self.pairCode = pairCode
        self.clientType = clientType
        self.pairPath = pairPath
    }

    public static func parse(_ url: URL, expectedClientType: DJConnectClientType) throws -> DJConnectPairingDeepLink {
        guard url.scheme?.lowercased() == "djconnect", url.host?.lowercased() == "pair" else {
            throw DJConnectError.invalidConfiguration("Invalid DJConnect pairing link.")
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw DJConnectError.invalidConfiguration("Invalid DJConnect pairing link.")
        }
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
        guard
            let rawHAURL = items["ha_url"],
            let haURL = URL(string: rawHAURL),
            DJConnectPairingURLPolicy.isAllowedPairingURL(haURL)
        else {
            throw DJConnectError.invalidConfiguration("Missing or invalid local Home Assistant URL.")
        }
        guard let pairCode = items["pair_code"], pairCode.count == 6, pairCode.allSatisfy(\.isNumber) else {
            throw DJConnectError.invalidConfiguration("Missing or invalid 6-digit pair code.")
        }
        guard let rawClientType = items["client_type"], let clientType = DJConnectClientType(rawValue: rawClientType), clientType == expectedClientType else {
            throw DJConnectError.invalidConfiguration("Invalid DJConnect client type.")
        }
        guard let pairPath = items["pair_path"],
              pairPath == Self.canonicalPairPath || pairPath == Self.legacyPairPath else {
            throw DJConnectError.invalidConfiguration("Invalid DJConnect pair path.")
        }
        return DJConnectPairingDeepLink(
            homeAssistantURL: rawHAURL,
            pairCode: pairCode,
            clientType: clientType,
            pairPath: pairPath
        )
    }
}

public enum DJConnectPairingURLPolicy {
    public static func isAllowedPairingURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased(), !host.isEmpty else {
            return false
        }
        if scheme == "http", isPlausibleLocalHomeAssistantHost(host) {
            return true
        }
        return scheme == "https" && isWhitelistedDevelopmentTunnelHost(host)
    }

    public static func isWhitelistedDevelopmentTunnelURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased() else {
            return false
        }
        return scheme == "https" && isWhitelistedDevelopmentTunnelHost(host)
    }

    private static func isWhitelistedDevelopmentTunnelHost(_ host: String) -> Bool {
        host.hasSuffix(".ngrok-free.dev")
    }

    private static func isPlausibleLocalHomeAssistantHost(_ host: String) -> Bool {
        if host == "localhost" {
            return true
        }
        if isValidIPv4Host(host) {
            return true
        }
        if host.hasSuffix(".local") {
            return host.range(of: #"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$"#, options: .regularExpression) != nil
        }
        return host.range(of: #"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+\.[a-z]{2,63}$"#, options: .regularExpression) != nil
    }

    private static func isValidIPv4Host(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else {
            return false
        }
        return parts.allSatisfy { part in
            guard !part.isEmpty, part.allSatisfy(\.isNumber), let value = Int(part) else {
                return false
            }
            return (0...255).contains(value)
        }
    }
}

public struct DJConnectPairingResponse: Codable, Equatable, Sendable {
    public var success: Bool
    public var deviceToken: String?
    public var token: String?
    public var bearerToken: String?
    public var setupPending: Bool?
    public var message: String?
    public var deviceID: String?
    public var clientType: DJConnectClientType?
    public var haLocalURL: String?
    public var haRemoteURL: String?
    public var remoteSupported: Bool?
    public var musicBackend: String?
    public var musicBackendName: String?
    public var musicBackendAvailable: Bool?
    public var musicBackendRevision: Int?
    public var musicBackendCapabilities: DJConnectMusicBackendCapabilities?
    public var musicTargetPlayer: DJConnectMusicTargetPlayer?
    public var musicBackendError: String?
    public var deviceLanguage: String?
    public var language: String?
    public var assistPipelineID: String?
    public var apiBase: String?
    public var voicePath: String?
    public var statusPath: String?
    public var eventPath: String?
    public var bootstrapProof: String?
    public var haInstallID: String?
    public var integrationVersion: String?
    public var pairingSessionID: String?
    public var djAnnouncement: DJAnnouncementCapabilities?
    public var askDJSupported: Bool?
    public var askDJVoiceSupported: Bool?
    public var askDJAudioResponseSupported: Bool?

    public var resolvedDeviceToken: String? {
        deviceToken ?? bearerToken ?? token
    }

    public var musicBackendSummary: DJConnectMusicBackendSummary {
        DJConnectMusicBackendSummary(
            musicBackend: musicBackend,
            musicBackendName: musicBackendName,
            musicBackendAvailable: musicBackendAvailable,
            musicBackendRevision: musicBackendRevision,
            musicBackendCapabilities: musicBackendCapabilities,
            musicTargetPlayer: musicTargetPlayer,
            musicBackendError: musicBackendError
        )
    }

    public init(
        success: Bool,
        deviceToken: String? = nil,
        token: String? = nil,
        bearerToken: String? = nil,
        setupPending: Bool? = nil,
        message: String? = nil,
        deviceID: String? = nil,
        clientType: DJConnectClientType? = nil,
        haLocalURL: String? = nil,
        haRemoteURL: String? = nil,
        remoteSupported: Bool? = nil,
        musicBackend: String? = nil,
        musicBackendName: String? = nil,
        musicBackendAvailable: Bool? = nil,
        musicBackendRevision: Int? = nil,
        musicBackendCapabilities: DJConnectMusicBackendCapabilities? = nil,
        musicTargetPlayer: DJConnectMusicTargetPlayer? = nil,
        musicBackendError: String? = nil,
        deviceLanguage: String? = nil,
        language: String? = nil,
        assistPipelineID: String? = nil,
        apiBase: String? = nil,
        voicePath: String? = nil,
        statusPath: String? = nil,
        eventPath: String? = nil,
        bootstrapProof: String? = nil,
        haInstallID: String? = nil,
        integrationVersion: String? = nil,
        pairingSessionID: String? = nil,
        askDJSupported: Bool? = nil,
        askDJVoiceSupported: Bool? = nil,
        askDJAudioResponseSupported: Bool? = nil,
        djAnnouncement: DJAnnouncementCapabilities? = nil
    ) {
        self.success = success
        self.deviceToken = deviceToken
        self.token = token
        self.bearerToken = bearerToken
        self.setupPending = setupPending
        self.message = message
        self.deviceID = deviceID
        self.clientType = clientType
        self.haLocalURL = haLocalURL
        self.haRemoteURL = haRemoteURL
        self.remoteSupported = remoteSupported
        self.musicBackend = musicBackend
        self.musicBackendName = musicBackendName
        self.musicBackendAvailable = musicBackendAvailable
        self.musicBackendRevision = musicBackendRevision
        self.musicBackendCapabilities = musicBackendCapabilities
        self.musicTargetPlayer = musicTargetPlayer
        self.musicBackendError = musicBackendError
        self.deviceLanguage = deviceLanguage
        self.language = language
        self.assistPipelineID = assistPipelineID
        self.apiBase = apiBase
        self.voicePath = voicePath
        self.statusPath = statusPath
        self.eventPath = eventPath
        self.bootstrapProof = bootstrapProof
        self.haInstallID = haInstallID
        self.integrationVersion = integrationVersion
        self.pairingSessionID = pairingSessionID
        self.askDJSupported = askDJSupported
        self.askDJVoiceSupported = askDJVoiceSupported
        self.askDJAudioResponseSupported = askDJAudioResponseSupported
        self.djAnnouncement = djAnnouncement
    }

    enum CodingKeys: String, CodingKey {
        case success
        case deviceToken = "device_token"
        case token
        case bearerToken = "bearer_token"
        case setupPending = "setup_pending"
        case message
        case deviceID = "device_id"
        case clientType = "client_type"
        case haLocalURL = "ha_local_url"
        case haRemoteURL = "ha_remote_url"
        case remoteSupported = "remote_supported"
        case musicBackend = "music_backend"
        case musicBackendName = "music_backend_name"
        case musicBackendAvailable = "music_backend_available"
        case musicBackendRevision = "music_backend_revision"
        case musicBackendCapabilities = "music_backend_capabilities"
        case musicTargetPlayer = "music_target_player"
        case musicBackendError = "music_backend_error"
        case deviceLanguage = "device_language"
        case language
        case assistPipelineID = "assist_pipeline_id"
        case apiBase = "api_base"
        case voicePath = "voice_path"
        case statusPath = "status_path"
        case eventPath = "event_path"
        case bootstrapProof = "bootstrap_proof"
        case haInstallID = "ha_install_id"
        case integrationVersion = "integration_version"
        case pairingSessionID = "pairing_session_id"
        case askDJSupported = "ask_dj_supported"
        case askDJVoiceSupported = "ask_dj_voice_supported"
        case askDJAudioResponseSupported = "ask_dj_audio_response_supported"
        case djAnnouncement = "dj_announcement"
    }
}

public struct DJConnectMusicBackendCapabilities: Codable, Equatable, Sendable {
    public var supportsSearch: Bool?
    public var supportsQueue: Bool?
    public var supportsOutputs: Bool?
    public var supportsFavorites: Bool?
    public var supportsRecentlyPlayed: Bool?
    public var supportsTopItems: Bool?

    public init(
        supportsSearch: Bool? = nil,
        supportsQueue: Bool? = nil,
        supportsOutputs: Bool? = nil,
        supportsFavorites: Bool? = nil,
        supportsRecentlyPlayed: Bool? = nil,
        supportsTopItems: Bool? = nil
    ) {
        self.supportsSearch = supportsSearch
        self.supportsQueue = supportsQueue
        self.supportsOutputs = supportsOutputs
        self.supportsFavorites = supportsFavorites
        self.supportsRecentlyPlayed = supportsRecentlyPlayed
        self.supportsTopItems = supportsTopItems
    }

    enum CodingKeys: String, CodingKey {
        case supportsSearch = "supports_search"
        case supportsQueue = "supports_queue"
        case supportsOutputs = "supports_outputs"
        case supportsFavorites = "supports_favorites"
        case supportsRecentlyPlayed = "supports_recently_played"
        case supportsTopItems = "supports_top_items"
    }
}

public struct DJConnectMusicTargetPlayer: Codable, Equatable, Sendable {
    public var id: String?
    public var name: String?

    public init(id: String? = nil, name: String? = nil) {
        self.id = id
        self.name = name
    }
}

public struct DJConnectMusicBackendSummary: Codable, Equatable, Sendable {
    public var remoteSupported: Bool?
    public var musicBackend: String?
    public var musicBackendName: String?
    public var musicBackendAvailable: Bool?
    public var musicBackendRevision: Int?
    public var musicBackendCapabilities: DJConnectMusicBackendCapabilities?
    public var musicTargetPlayer: DJConnectMusicTargetPlayer?
    public var musicBackendError: String?

    public init(
        remoteSupported: Bool? = nil,
        musicBackend: String? = nil,
        musicBackendName: String? = nil,
        musicBackendAvailable: Bool? = nil,
        musicBackendRevision: Int? = nil,
        musicBackendCapabilities: DJConnectMusicBackendCapabilities? = nil,
        musicTargetPlayer: DJConnectMusicTargetPlayer? = nil,
        musicBackendError: String? = nil
    ) {
        self.remoteSupported = remoteSupported
        self.musicBackend = musicBackend
        self.musicBackendName = musicBackendName
        self.musicBackendAvailable = musicBackendAvailable
        self.musicBackendRevision = musicBackendRevision
        self.musicBackendCapabilities = musicBackendCapabilities
        self.musicTargetPlayer = musicTargetPlayer
        self.musicBackendError = musicBackendError
    }

    public var displayName: String {
        musicBackendName ?? musicBackend ?? "Unknown"
    }

    enum CodingKeys: String, CodingKey {
        case remoteSupported = "remote_supported"
        case musicBackend = "music_backend"
        case musicBackendName = "music_backend_name"
        case musicBackendAvailable = "music_backend_available"
        case musicBackendRevision = "music_backend_revision"
        case musicBackendCapabilities = "music_backend_capabilities"
        case musicTargetPlayer = "music_target_player"
        case musicBackendError = "music_backend_error"
    }
}

public struct DJConnectStatusPayload: Codable, Equatable, Sendable {
    public var deviceID: String
    public var deviceName: String
    public var clientType: DJConnectClientType
    public var haPairingStatus: DJConnectPairingStatus
    public var firmware: String
    public var appVersion: String?
    public var protocolVersion: String?
    public var state: DJConnectState
    public var status: DJConnectState
    public var batteryPercent: Int?
    public var language: String?
    public var theme: String?
    public var logLevel: String?
    public var platform: DJConnectPlatform?
    public var osVersion: String?
    public var appBuild: String?
    public var localAudioSupported: Bool?
    public var voiceSupported: Bool?
    public var screenState: String?
    public var networkType: String?
    public var haLocalURL: String?
    public var voiceEnabled: Bool?
    public var wakewordEnabled: Bool?
    public var wakewordPhrase: String?
    public var wakewordStatus: String?
    public var mood: Int?
    public var djStyle: String?
    public var musicDNAKey: String?
    public var bootstrapProof: String?

    public init(
        identity: DJConnectIdentity,
        haPairingStatus: DJConnectPairingStatus = .paired,
        state: DJConnectState = .online,
        status: DJConnectState = .online,
        batteryPercent: Int? = nil,
        language: String? = nil,
        theme: String? = nil,
        logLevel: String? = nil,
        osVersion: String? = nil,
        appBuild: String? = nil,
        localAudioSupported: Bool? = nil,
        voiceSupported: Bool? = nil,
        screenState: String? = nil,
        networkType: String? = nil,
        haLocalURL: String? = nil,
        voiceEnabled: Bool? = nil,
        wakewordEnabled: Bool? = nil,
        wakewordPhrase: String? = nil,
        wakewordStatus: String? = nil,
        mood: Int? = nil,
        djStyle: String? = nil,
        musicDNAKey: String? = nil,
        bootstrapProof: String? = nil
    ) {
        self.deviceID = identity.deviceID
        self.deviceName = identity.deviceName
        self.clientType = identity.clientType
        self.haPairingStatus = haPairingStatus
        self.firmware = identity.firmware
        self.appVersion = identity.appVersion
        self.protocolVersion = identity.protocolVersion ?? identity.firmware
        self.state = state
        self.status = status
        self.batteryPercent = batteryPercent
        self.language = language
        self.theme = theme
        self.logLevel = logLevel
        self.platform = identity.platform
        self.osVersion = osVersion
        self.appBuild = appBuild
        self.localAudioSupported = localAudioSupported
        self.voiceSupported = voiceSupported
        self.screenState = screenState
        self.networkType = networkType
        self.haLocalURL = haLocalURL
        self.voiceEnabled = voiceEnabled
        self.wakewordEnabled = wakewordEnabled
        self.wakewordPhrase = wakewordPhrase
        self.wakewordStatus = wakewordStatus
        self.mood = mood.map { max(0, min(100, $0)) }
        self.djStyle = djStyle
        self.musicDNAKey = musicDNAKey
        self.bootstrapProof = bootstrapProof
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case deviceName = "device_name"
        case clientType = "client_type"
        case haPairingStatus = "ha_pairing_status"
        case firmware
        case appVersion = "app_version"
        case protocolVersion = "protocol_version"
        case state
        case status
        case batteryPercent = "battery_percent"
        case language
        case theme
        case logLevel = "log_level"
        case platform
        case osVersion = "os_version"
        case appBuild = "app_build"
        case localAudioSupported = "local_audio_supported"
        case voiceSupported = "voice_supported"
        case screenState = "screen_state"
            case networkType = "network_type"
            case haLocalURL = "ha_local_url"
            case voiceEnabled = "voice_enabled"
        case wakewordEnabled = "wakeword_enabled"
        case wakewordPhrase = "wakeword_phrase"
        case wakewordStatus = "wakeword_status"
        case mood
        case djStyle = "dj_style"
        case musicDNAKey = "music_dna_key"
        case bootstrapProof = "bootstrap_proof"
    }
}

public struct DJConnectCommandPayload: Codable, Equatable, Sendable, DJConnectProfileContextCarrier {
    public var deviceID: String
    public var deviceName: String
    public var clientType: DJConnectClientType
    public var clientID: String
    public var command: String
    public var value: DJConnectCommandValue?
    public var play: Bool?
    public var limit: Int?
    public var musicBackendRevision: Int?
    public var language: String?
    public var mood: Int?
    public var musicDNAKey: String?
    public var djAnnouncementOutput: DJAnnouncementOutput?
    public var profileID: String?
    public var sessionID: String?
    public var privateSession: Bool?
    public var requestSource: DJConnectProfileRequestSource?

    public init(
        identity: DJConnectIdentity,
        command: String,
        value: DJConnectCommandValue? = nil,
        play: Bool? = nil,
        limit: Int? = nil,
        musicBackendRevision: Int? = nil,
        language: String? = nil,
        mood: Int? = nil,
        musicDNAKey: String? = nil,
        djAnnouncementOutput: DJAnnouncementOutput? = nil,
        profileContext: DJConnectProfileContext? = nil
    ) {
        self.deviceID = identity.deviceID
        self.deviceName = identity.deviceName
        self.clientType = identity.clientType
        self.clientID = identity.deviceID
        self.command = command
        self.value = value
        self.play = play
        self.limit = limit
        self.musicBackendRevision = musicBackendRevision
        self.language = language
        self.mood = mood.map { max(0, min(100, $0)) }
        self.musicDNAKey = musicDNAKey
        self.djAnnouncementOutput = djAnnouncementOutput
        self.profileID = profileContext?.profileID
        self.sessionID = profileContext?.sessionID
        self.privateSession = profileContext?.privateSession
        self.requestSource = profileContext?.requestSource ?? .deviceCommand
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case deviceName = "device_name"
        case clientType = "client_type"
        case clientID = "client_id"
        case command
        case value
        case play
        case limit
        case musicBackendRevision = "music_backend_revision"
        case language
        case mood
        case musicDNAKey = "music_dna_key"
        case djAnnouncementOutput = "dj_announcement_output"
        case profileID = "profile_id"
        case sessionID = "session_id"
        case privateSession = "private_session"
        case requestSource = "request_source"
    }
}

public struct DJConnectAskDJRequest: Codable, Equatable, Sendable, DJConnectProfileContextCarrier {
    public enum AudioResponse: String, Codable, Equatable, Sendable {
        case auto
        case always
        case never
    }

    public var deviceID: String
    public var deviceName: String
    public var clientType: DJConnectClientType
    public var clientID: String
    public var clientMessageID: String?
    public var text: String
    public var inputType: String?
    public var mood: Int?
    public var djStyle: String?
    public var musicDNAKey: String?
    public var audioResponse: AudioResponse?
    public var djAnnouncementOutput: DJAnnouncementOutput?
    public var metadata: [String: String]?
    public var language: String?
    public var profileID: String?
    public var sessionID: String?
    public var privateSession: Bool?
    public var requestSource: DJConnectProfileRequestSource?

    public init(
        identity: DJConnectIdentity,
        text: String,
        clientMessageID: String? = nil,
        inputType: String? = nil,
        mood: Int? = nil,
        djStyle: String? = nil,
        musicDNAKey: String? = nil,
        audioResponse: AudioResponse? = nil,
        djAnnouncementOutput: DJAnnouncementOutput? = nil,
        metadata: [String: String]? = nil,
        language: String? = nil,
        profileContext: DJConnectProfileContext? = nil
    ) {
        self.deviceID = identity.deviceID
        self.deviceName = identity.deviceName
        self.clientType = identity.clientType
        self.clientID = identity.deviceID
        self.clientMessageID = clientMessageID
        self.text = text
        self.inputType = inputType
        self.mood = mood.map { max(0, min(100, $0)) }
        self.djStyle = djStyle
        self.musicDNAKey = musicDNAKey
        self.audioResponse = audioResponse
        self.djAnnouncementOutput = djAnnouncementOutput
        self.metadata = metadata
        self.language = language
        self.profileID = profileContext?.profileID
        self.sessionID = profileContext?.sessionID
        self.privateSession = profileContext?.privateSession
        self.requestSource = profileContext?.requestSource ?? .askDJ
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case deviceName = "device_name"
        case clientType = "client_type"
        case clientID = "client_id"
        case clientMessageID = "client_message_id"
        case text
        case inputType = "input_type"
        case mood
        case djStyle = "dj_style"
        case musicDNAKey = "music_dna_key"
        case audioResponse = "audio_response"
        case djAnnouncementOutput = "dj_announcement_output"
        case metadata
        case language
        case profileID = "profile_id"
        case sessionID = "session_id"
        case privateSession = "private_session"
        case requestSource = "request_source"
    }
}

public enum DJAnnouncementOutput: String, Codable, CaseIterable, Equatable, Sendable {
    case clientDevice = "client_device"
    case both
    case haSpeaker = "ha_speaker"
    case textOnly = "text_only"

    public var allowsClientAudio: Bool {
        self == .clientDevice || self == .both
    }
}

public struct DJAnnouncementTarget: Codable, Equatable, Sendable {
    public var kind: String?
    public var entityID: String?
    public var name: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case entityID = "entity_id"
        case name
    }
}

public struct DJAnnouncement: Codable, Equatable, Sendable {
    public var output: DJAnnouncementOutput?
    public var delivery: DJAnnouncementOutput?
    public var audioResponseEffective: DJConnectAskDJRequest.AudioResponse?
    public var audioURL: URL?
    public var audioType: String?
    public var target: DJAnnouncementTarget?
    public var warnings: [String]

    public var clientReplayAudioURL: URL? {
        guard (delivery ?? output)?.allowsClientAudio == true else {
            return nil
        }
        return audioURL
    }

    enum CodingKeys: String, CodingKey {
        case output
        case delivery
        case audioResponseEffective = "audio_response_effective"
        case audioURL = "audio_url"
        case audioUrl
        case audioType = "audio_type"
        case target
        case warnings
    }

    public init(
        output: DJAnnouncementOutput? = nil,
        delivery: DJAnnouncementOutput? = nil,
        audioResponseEffective: DJConnectAskDJRequest.AudioResponse? = nil,
        audioURL: URL? = nil,
        audioType: String? = nil,
        target: DJAnnouncementTarget? = nil,
        warnings: [String] = []
    ) {
        self.output = output
        self.delivery = delivery
        self.audioResponseEffective = audioResponseEffective
        self.audioURL = audioURL
        self.audioType = audioType
        self.target = target
        self.warnings = warnings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        output = try container.decodeIfPresent(DJAnnouncementOutput.self, forKey: .output)
        delivery = try container.decodeIfPresent(DJAnnouncementOutput.self, forKey: .delivery)
        audioResponseEffective = try container.decodeIfPresent(DJConnectAskDJRequest.AudioResponse.self, forKey: .audioResponseEffective)
        audioURL = try container.decodeIfPresent(URL.self, forKey: .audioURL)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .audioUrl)
        audioType = try container.decodeIfPresent(String.self, forKey: .audioType)
        target = try container.decodeIfPresent(DJAnnouncementTarget.self, forKey: .target)
        warnings = try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(output, forKey: .output)
        try container.encodeIfPresent(delivery, forKey: .delivery)
        try container.encodeIfPresent(audioResponseEffective, forKey: .audioResponseEffective)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encodeIfPresent(audioType, forKey: .audioType)
        try container.encodeIfPresent(target, forKey: .target)
        try container.encode(warnings, forKey: .warnings)
    }
}

public struct DJAnnouncementCapabilities: Codable, Equatable, Sendable {
    public var speakerConfigured: Bool?
    public var speakerEntityID: String?
    public var speakerName: String?
    public var supportedOutputs: [DJAnnouncementOutput]
    public var lockedOutputs: [DJAnnouncementOutput]
    public var defaultOutput: DJAnnouncementOutput?
    public var output: DJAnnouncementOutput?

    public init(
        speakerConfigured: Bool? = nil,
        speakerEntityID: String? = nil,
        speakerName: String? = nil,
        supportedOutputs: [DJAnnouncementOutput] = [],
        lockedOutputs: [DJAnnouncementOutput] = [],
        defaultOutput: DJAnnouncementOutput? = nil,
        output: DJAnnouncementOutput? = nil
    ) {
        self.speakerConfigured = speakerConfigured
        self.speakerEntityID = speakerEntityID
        self.speakerName = speakerName
        self.supportedOutputs = supportedOutputs
        self.lockedOutputs = lockedOutputs
        self.defaultOutput = defaultOutput
        self.output = output
    }

    public var isSpeakerConfigured: Bool {
        speakerConfigured ?? false
    }

    public var effectiveSupportedOutputs: [DJAnnouncementOutput] {
        if !supportedOutputs.isEmpty {
            return supportedOutputs
        }
        return isSpeakerConfigured ? DJAnnouncementOutput.allCases : [.clientDevice, .textOnly]
    }

    enum CodingKeys: String, CodingKey {
        case speakerConfigured = "speaker_configured"
        case speakerEntityID = "speaker_entity_id"
        case speakerName = "speaker_name"
        case supportedOutputs = "supported_outputs"
        case lockedOutputs = "locked_outputs"
        case defaultOutput = "default_output"
        case output
    }
}

public enum DJConnectAskDJHistoryRole: String, Codable, Equatable, Sendable {
    case user
    case assistant
    case dj
}

public enum DJConnectAskDJMessageKind: String, Codable, Equatable, Sendable {
    case assistant
    case system
}

public struct DJConnectAskDJIntentInfo: Codable, Equatable, Sendable {
    public var category: String?
    public var intent: String?
    public var action: String?
    public var itemType: String?

    enum CodingKeys: String, CodingKey {
        case category
        case intent
        case action
        case itemType = "item_type"
        case itemTypeCamel = "itemType"
    }

    public init(category: String? = nil, intent: String? = nil, action: String? = nil, itemType: String? = nil) {
        self.category = category
        self.intent = intent
        self.action = action
        self.itemType = itemType
    }

    public init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(intent: value)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            category: try container.decodeIfPresent(String.self, forKey: .category),
            intent: try container.decodeIfPresent(String.self, forKey: .intent),
            action: try container.decodeIfPresent(String.self, forKey: .action),
            itemType: try container.decodeIfPresent(String.self, forKey: .itemType)
                ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .itemTypeCamel)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(intent, forKey: .intent)
        try container.encodeIfPresent(action, forKey: .action)
        try container.encodeIfPresent(itemType, forKey: .itemType)
    }
}

public struct TrackInsight: Codable, Equatable, Sendable, Identifiable {
    public enum MusicDNALabel: String, Codable, Equatable, Sendable {
        case matchesMusicDNA = "matches_music_dna"
        case expandsMusicDNA = "expands_music_dna"
        case outsideMusicDNA = "outside_music_dna"
    }

    public var id: String
    public var timestamp: Date
    public var source: String?
    public var title: String
    public var artist: String
    public var album: String?
    public var artwork: URL?
    public var duration: TimeInterval?
    public var progress: TimeInterval?
    public var isPlaying: Bool?
    public var playerID: String?
    public var entityID: String?
    public var backend: String?
    public var genre: String?
    public var subgenre: String?
    public var energy: Double?
    public var danceability: Double?
    public var intensity: Double?
    public var mood: String?
    public var vibe: String?
    public var texture: String?
    public var emotionalTone: String?
    public var confidence: Double?
    public var confidenceLabel: String?
    public var summary: String
    public var rawAnalysisText: String
    public var productionNotes: [String]
    public var instrumentation: [String]
    public var arrangementNotes: [String]
    public var listeningCues: [String]
    public var similarTracks: [TrackInsightSimilarTrack]
    public var musicDNAMatchPercent: Int?
    public var musicDNALabel: MusicDNALabel?
    public var musicDNASummary: String?
    public var visualProfile: TrackInsightVisualProfile?
    public var sections: [TrackInsightSection]

    public init(
        id: String? = nil,
        timestamp: Date = Date(),
        source: String? = nil,
        title: String,
        artist: String,
        album: String? = nil,
        artwork: URL? = nil,
        duration: TimeInterval? = nil,
        progress: TimeInterval? = nil,
        isPlaying: Bool? = nil,
        playerID: String? = nil,
        entityID: String? = nil,
        backend: String? = nil,
        genre: String? = nil,
        subgenre: String? = nil,
        energy: Double? = nil,
        danceability: Double? = nil,
        intensity: Double? = nil,
        mood: String? = nil,
        vibe: String? = nil,
        texture: String? = nil,
        emotionalTone: String? = nil,
        confidence: Double? = nil,
        confidenceLabel: String? = nil,
        summary: String,
        rawAnalysisText: String,
        productionNotes: [String] = [],
        instrumentation: [String] = [],
        arrangementNotes: [String] = [],
        listeningCues: [String] = [],
        similarTracks: [TrackInsightSimilarTrack] = [],
        musicDNAMatchPercent: Int? = nil,
        musicDNALabel: MusicDNALabel? = nil,
        musicDNASummary: String? = nil,
        visualProfile: TrackInsightVisualProfile? = nil,
        sections: [TrackInsightSection] = []
    ) {
        self.id = id ?? Self.makeStableID(title: title, artist: artist, album: album)
        self.timestamp = timestamp
        self.source = source
        self.title = title
        self.artist = artist
        self.album = album
        self.artwork = artwork
        self.duration = duration
        self.progress = progress
        self.isPlaying = isPlaying
        self.playerID = playerID
        self.entityID = entityID
        self.backend = backend
        self.genre = genre
        self.subgenre = subgenre
        self.energy = energy
        self.danceability = danceability
        self.intensity = intensity
        self.mood = mood
        self.vibe = vibe
        self.texture = texture
        self.emotionalTone = emotionalTone
        self.confidence = confidence
        self.confidenceLabel = confidenceLabel
        self.summary = summary
        self.rawAnalysisText = rawAnalysisText
        self.productionNotes = productionNotes
        self.instrumentation = instrumentation
        self.arrangementNotes = arrangementNotes
        self.listeningCues = listeningCues
        self.similarTracks = similarTracks
        self.musicDNAMatchPercent = musicDNAMatchPercent
        self.musicDNALabel = musicDNALabel
        self.musicDNASummary = musicDNASummary
        self.visualProfile = visualProfile
        self.sections = sections
    }

    private static func makeStableID(title: String, artist: String, album: String?) -> String {
        [title, artist, album ?? ""]
            .joined(separator: "|")
            .lowercased()
            .unicodeScalars
            .reduce(into: 0) { value, scalar in
                value = ((value &* 31) &+ Int(scalar.value)) & 0x7fffffff
            }
            .description
    }
}

public struct DJConnectTrackInsightWidgetSnapshot: Codable, Equatable, Sendable {
    public static let appGroupIdentifier = "group.dev.djconnect"
    public static let storageKey = "DJConnectTrackInsightWidgetSnapshot"
    public static let widgetKind = "DJConnectTrackInsightWidget"

    public var updatedAt: Date
    public var title: String
    public var artist: String
    public var genre: String?
    public var mood: String?
    public var vibe: String?
    public var energy: Double?
    public var danceability: Double?
    public var intensity: Double?
    public var musicDNAMatchPercent: Int?
    public var progress: TimeInterval?
    public var duration: TimeInterval?
    public var artworkURL: URL?
    public var artworkData: Data?
    public var summary: String

    public init(
        updatedAt: Date = Date(),
        title: String,
        artist: String,
        genre: String? = nil,
        mood: String? = nil,
        vibe: String? = nil,
        energy: Double? = nil,
        danceability: Double? = nil,
        intensity: Double? = nil,
        musicDNAMatchPercent: Int? = nil,
        progress: TimeInterval? = nil,
        duration: TimeInterval? = nil,
        artworkURL: URL? = nil,
        artworkData: Data? = nil,
        summary: String
    ) {
        self.updatedAt = updatedAt
        self.title = Self.sanitizedPublic(title, maxLength: 96) ?? ""
        self.artist = Self.sanitizedPublic(artist, maxLength: 96) ?? ""
        self.genre = Self.sanitizedPublic(genre, maxLength: 48)
        self.mood = Self.sanitizedPublic(mood, maxLength: 48)
        self.vibe = Self.sanitizedPublic(vibe, maxLength: 48)
        self.energy = Self.normalizedMetric(energy)
        self.danceability = Self.normalizedMetric(danceability)
        self.intensity = Self.normalizedMetric(intensity)
        self.musicDNAMatchPercent = nil
        self.progress = Self.normalizedTime(progress)
        self.duration = Self.normalizedTime(duration)
        self.artworkURL = artworkURL
        self.artworkData = artworkData
        self.summary = Self.sanitizedPublic(summary, maxLength: 180) ?? ""
    }

    public init(insight: TrackInsight, updatedAt: Date = Date()) {
        self.init(
            updatedAt: updatedAt,
            title: insight.title,
            artist: insight.artist,
            genre: insight.genre,
            mood: insight.mood,
            vibe: insight.vibe,
            energy: insight.energy,
            danceability: insight.danceability,
            intensity: insight.intensity,
            musicDNAMatchPercent: nil,
            progress: insight.progress,
            duration: insight.duration,
            artworkURL: insight.artwork,
            summary: insight.summary
        )
    }

    public func save(to defaults: UserDefaults) throws {
        let data = try JSONEncoder().encode(self)
        defaults.set(data, forKey: Self.storageKey)
    }

    public static func remove(from defaults: UserDefaults) {
        defaults.removeObject(forKey: storageKey)
    }

    public static func load(from defaults: UserDefaults) -> DJConnectTrackInsightWidgetSnapshot? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(DJConnectTrackInsightWidgetSnapshot.self, from: data)
    }

    private static func normalizedMetric(_ value: Double?) -> Double? {
        value.map { max(0, min(1, $0)) }
    }

    private static func normalizedTime(_ value: TimeInterval?) -> TimeInterval? {
        value.map { max(0, $0) }
    }

    public static func sanitizedPublic(_ value: String?, maxLength: Int) -> String? {
        guard let value else {
            return nil
        }
        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else {
            return nil
        }
        if collapsed.count <= maxLength {
            return collapsed
        }
        let end = collapsed.index(collapsed.startIndex, offsetBy: maxLength)
        return String(collapsed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct DJConnectAskDJWidgetSnapshot: Codable, Equatable, Sendable {
    public static let storageKey = "DJConnectAskDJWidgetSnapshot"
    public static let widgetKind = "DJConnectAskDJWidget"

    public var updatedAt: Date
    public var prompt: String
    public var response: String
    public var context: String
    public var trackTitle: String?
    public var artist: String?

    public init(
        updatedAt: Date = Date(),
        prompt: String,
        response: String,
        context: String,
        trackTitle: String? = nil,
        artist: String? = nil
    ) {
        self.updatedAt = updatedAt
        self.prompt = DJConnectTrackInsightWidgetSnapshot.sanitizedPublic(prompt, maxLength: 96) ?? "Ask DJ"
        self.response = DJConnectTrackInsightWidgetSnapshot.sanitizedPublic(response, maxLength: 180) ?? ""
        self.context = DJConnectTrackInsightWidgetSnapshot.sanitizedPublic(context, maxLength: 80) ?? ""
        self.trackTitle = DJConnectTrackInsightWidgetSnapshot.sanitizedPublic(trackTitle, maxLength: 96)
        self.artist = DJConnectTrackInsightWidgetSnapshot.sanitizedPublic(artist, maxLength: 96)
    }

    public func save(to defaults: UserDefaults) throws {
        let data = try JSONEncoder().encode(self)
        defaults.set(data, forKey: Self.storageKey)
    }

    public static func remove(from defaults: UserDefaults) {
        defaults.removeObject(forKey: storageKey)
    }

    public static func load(from defaults: UserDefaults) -> DJConnectAskDJWidgetSnapshot? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(DJConnectAskDJWidgetSnapshot.self, from: data)
    }
}

public struct DJConnectNowPlayingWidgetSnapshot: Codable, Equatable, Sendable {
    public static let storageKey = "DJConnectNowPlayingWidgetSnapshot"
    public static let widgetKind = "DJConnectNowPlayingWidget"

    public var updatedAt: Date
    public var title: String
    public var artist: String
    public var artworkURL: URL?
    public var artworkData: Data?
    public var progressMS: Int?
    public var durationMS: Int?
    public var isPlaying: Bool
    public var deviceName: String?

    public init(
        updatedAt: Date = Date(),
        title: String,
        artist: String,
        artworkURL: URL? = nil,
        artworkData: Data? = nil,
        progressMS: Int? = nil,
        durationMS: Int? = nil,
        isPlaying: Bool,
        deviceName: String? = nil
    ) {
        self.updatedAt = updatedAt
        self.title = DJConnectTrackInsightWidgetSnapshot.sanitizedPublic(title, maxLength: 96) ?? ""
        self.artist = DJConnectTrackInsightWidgetSnapshot.sanitizedPublic(artist, maxLength: 96) ?? ""
        self.artworkURL = artworkURL
        self.artworkData = artworkData
        self.progressMS = progressMS.map { max(0, $0) }
        self.durationMS = durationMS.map { max(0, $0) }
        self.isPlaying = isPlaying
        self.deviceName = DJConnectTrackInsightWidgetSnapshot.sanitizedPublic(deviceName, maxLength: 80)
    }

    public init?(playback: DJConnectPlayback, updatedAt: Date = Date()) {
        guard playback.hasPlayback == true || playback.isPlaying == true || playback.trackName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }
        self.init(
            updatedAt: updatedAt,
            title: playback.trackName ?? "",
            artist: playback.artistName ?? "",
            artworkURL: playback.albumImageURL,
            progressMS: playback.progressMS,
            durationMS: playback.durationMS,
            isPlaying: playback.isPlaying == true,
            deviceName: playback.device?.name
        )
    }

    public func save(to defaults: UserDefaults) throws {
        let data = try JSONEncoder().encode(self)
        defaults.set(data, forKey: Self.storageKey)
    }

    public static func remove(from defaults: UserDefaults) {
        defaults.removeObject(forKey: storageKey)
    }

    public static func load(from defaults: UserDefaults) -> DJConnectNowPlayingWidgetSnapshot? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(DJConnectNowPlayingWidgetSnapshot.self, from: data)
    }
}

public struct DJConnectQueueWidgetItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var artist: String?
    public var album: String?
    public var durationMS: Int?
    public var artworkURL: URL?
    public var artworkData: Data?

    public init(
        id: String,
        title: String,
        artist: String? = nil,
        album: String? = nil,
        durationMS: Int? = nil,
        artworkURL: URL? = nil,
        artworkData: Data? = nil
    ) {
        self.id = DJConnectTrackInsightWidgetSnapshot.sanitizedPublic(id, maxLength: 96) ?? title
        self.title = DJConnectTrackInsightWidgetSnapshot.sanitizedPublic(title, maxLength: 96) ?? ""
        self.artist = DJConnectTrackInsightWidgetSnapshot.sanitizedPublic(artist, maxLength: 96)
        self.album = DJConnectTrackInsightWidgetSnapshot.sanitizedPublic(album, maxLength: 96)
        self.durationMS = durationMS.map { max(0, $0) }
        self.artworkURL = artworkURL
        self.artworkData = artworkData
    }

    public init(item: DJConnectQueueItem) {
        self.init(
            id: item.id,
            title: item.title,
            artist: item.artist,
            album: item.album,
            durationMS: item.durationMS,
            artworkURL: item.albumImageURL
        )
    }
}

public struct DJConnectQueueWidgetSnapshot: Codable, Equatable, Sendable {
    public static let storageKey = "DJConnectQueueWidgetSnapshot"
    public static let widgetKind = "DJConnectQueueWidget"
    public static let maxVisibleItems = 5

    public var updatedAt: Date
    public var items: [DJConnectQueueWidgetItem]
    public var totalCount: Int

    public init(updatedAt: Date = Date(), items: [DJConnectQueueItem]) {
        self.updatedAt = updatedAt
        let sanitizedItems = items.map(DJConnectQueueWidgetItem.init(item:))
            .filter { !$0.title.isEmpty }
        self.items = Array(sanitizedItems.prefix(Self.maxVisibleItems))
        self.totalCount = sanitizedItems.count
    }

    public func save(to defaults: UserDefaults) throws {
        let data = try JSONEncoder().encode(self)
        defaults.set(data, forKey: Self.storageKey)
    }

    public static func remove(from defaults: UserDefaults) {
        defaults.removeObject(forKey: storageKey)
    }

    public static func load(from defaults: UserDefaults) -> DJConnectQueueWidgetSnapshot? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(DJConnectQueueWidgetSnapshot.self, from: data)
    }
}

public struct DJConnectPlaylistWidgetItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var subtitle: String?
    public var imageURL: URL?
    public var imageData: Data?

    public init(id: String, name: String, subtitle: String? = nil, imageURL: URL? = nil, imageData: Data? = nil) {
        self.id = DJConnectTrackInsightWidgetSnapshot.sanitizedPublic(id, maxLength: 96) ?? name
        self.name = DJConnectTrackInsightWidgetSnapshot.sanitizedPublic(name, maxLength: 96) ?? ""
        self.subtitle = DJConnectTrackInsightWidgetSnapshot.sanitizedPublic(subtitle, maxLength: 96)
        self.imageURL = imageURL
        self.imageData = imageData
    }

    public init(playlist: DJConnectPlaylist) {
        self.init(
            id: playlist.id,
            name: playlist.name,
            subtitle: playlist.subtitle,
            imageURL: playlist.imageURL
        )
    }
}

public struct DJConnectPlaylistsWidgetSnapshot: Codable, Equatable, Sendable {
    public static let storageKey = "DJConnectPlaylistsWidgetSnapshot"
    public static let widgetKind = "DJConnectPlaylistsWidget"
    public static let maxVisibleItems = 5

    public var updatedAt: Date
    public var items: [DJConnectPlaylistWidgetItem]
    public var totalCount: Int

    public init(updatedAt: Date = Date(), playlists: [DJConnectPlaylist]) {
        self.updatedAt = updatedAt
        let sanitizedItems = playlists.map(DJConnectPlaylistWidgetItem.init(playlist:))
            .filter { !$0.name.isEmpty }
        self.items = Array(sanitizedItems.prefix(Self.maxVisibleItems))
        self.totalCount = sanitizedItems.count
    }

    public func save(to defaults: UserDefaults) throws {
        let data = try JSONEncoder().encode(self)
        defaults.set(data, forKey: Self.storageKey)
    }

    public static func remove(from defaults: UserDefaults) {
        defaults.removeObject(forKey: storageKey)
    }

    public static func load(from defaults: UserDefaults) -> DJConnectPlaylistsWidgetSnapshot? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(DJConnectPlaylistsWidgetSnapshot.self, from: data)
    }
}

public struct TrackInsightSimilarTrack: Codable, Equatable, Sendable, Identifiable {
    public var id: String { "\(title)|\(artist)|\(reason ?? "")" }
    public var title: String
    public var artist: String
    public var reason: String?

    public init(title: String, artist: String, reason: String? = nil) {
        self.title = title
        self.artist = artist
        self.reason = reason
    }
}

public struct TrackInsightVisualProfile: Codable, Equatable, Sendable {
    public enum MotionStyle: String, Codable, Equatable, Sendable {
        case flowing
        case pulsing
        case sharp
        case minimal
        case organic
        case cinematic
    }

    public enum SpectrumBias: String, Codable, Equatable, Sendable {
        case low
        case mid
        case high
        case balanced
    }

    public var palette: [String]
    public var motionStyle: MotionStyle?
    public var pulseSpeed: Double?
    public var waveAmplitude: Double?
    public var particleDensity: Double?
    public var glowStrength: Double?
    public var spectrumBias: SpectrumBias?
    public var seed: String?

    public init(
        palette: [String] = [],
        motionStyle: MotionStyle? = nil,
        pulseSpeed: Double? = nil,
        waveAmplitude: Double? = nil,
        particleDensity: Double? = nil,
        glowStrength: Double? = nil,
        spectrumBias: SpectrumBias? = nil,
        seed: String? = nil
    ) {
        self.palette = palette
        self.motionStyle = motionStyle
        self.pulseSpeed = pulseSpeed
        self.waveAmplitude = waveAmplitude
        self.particleDensity = particleDensity
        self.glowStrength = glowStrength
        self.spectrumBias = spectrumBias
        self.seed = seed
    }

    enum CodingKeys: String, CodingKey {
        case palette
        case motionStyle = "motion_style"
        case pulseSpeed = "pulse_speed"
        case waveAmplitude = "wave_amplitude"
        case particleDensity = "particle_density"
        case glowStrength = "glow_strength"
        case spectrumBias = "spectrum_bias"
        case seed
    }
}

public struct TrackInsightSection: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var value: String?
    public var summary: String?

    public init(id: String, title: String, value: String? = nil, summary: String? = nil) {
        self.id = id
        self.title = title
        self.value = value
        self.summary = summary
    }
}

public struct TrackVibeProfile: Codable, Equatable, Sendable {
    public enum MotionStyle: String, Codable, Equatable, Sendable {
        case dreamy
        case energetic
        case organic
        case dark
        case balanced
    }

    public var palette: [String]
    public var glow: Double
    public var pulseSpeed: Double
    public var waveform: Double
    public var particleDensity: Double
    public var particleVelocity: Double
    public var animationSpeed: Double
    public var terrainShape: Double
    public var motionStyle: MotionStyle
    public var spectrumProfile: [Double]

    public static func make(for insight: TrackInsight) -> TrackVibeProfile {
        let seed = stableSeed(for: insight)
        let mood = [insight.mood, insight.vibe, insight.genre, insight.texture]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        let energy = clamp(insight.energy ?? normalized(seed, offset: 3), min: 0.05, max: 1.0)
        let danceability = clamp(insight.danceability ?? normalized(seed, offset: 7), min: 0.05, max: 1.0)
        let intensity = clamp(insight.intensity ?? ((energy + danceability) / 2), min: 0.05, max: 1.0)

        let style = motionStyle(for: insight.visualProfile?.motionStyle, mood: mood, energy: energy)
        let visualProfile = insight.visualProfile
        let palette = visualProfile?.palette.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return TrackVibeProfile(
            palette: palette?.isEmpty == false ? palette! : Self.palette(for: style),
            glow: clamp(visualProfile?.glowStrength ?? (0.28 + intensity * 0.58), min: 0.2, max: 0.95),
            pulseSpeed: clamp(visualProfile?.pulseSpeed ?? (0.45 + energy * 1.55), min: 0.35, max: 2.2),
            waveform: clamp(visualProfile?.waveAmplitude ?? (0.25 + intensity * 0.75), min: 0.2, max: 1.0),
            particleDensity: clamp(visualProfile?.particleDensity ?? (0.16 + danceability * 0.72), min: 0.12, max: 0.92),
            particleVelocity: clamp(0.25 + energy * 0.88, min: 0.18, max: 1.18),
            animationSpeed: clamp(0.55 + ((energy + intensity) / 2) * 1.15, min: 0.45, max: 1.9),
            terrainShape: normalized(seed, offset: 11),
            motionStyle: style,
            spectrumProfile: spectrumProfile(seed: seed, intensity: intensity, bias: visualProfile?.spectrumBias)
        )
    }

    private static func motionStyle(for hint: TrackInsightVisualProfile.MotionStyle?, mood: String, energy: Double) -> MotionStyle {
        switch hint {
        case .cinematic, .flowing:
            return .dreamy
        case .sharp, .pulsing:
            return .energetic
        case .organic:
            return .organic
        case .minimal:
            return .balanced
        case nil:
            break
        }
        if mood.contains("dream") || mood.contains("ambient") || mood.contains("soft") {
            return .dreamy
        } else if mood.contains("dark") || mood.contains("minor") || mood.contains("shadow") {
            return .dark
        } else if mood.contains("organic") || mood.contains("acoustic") || mood.contains("warm") {
            return .organic
        } else if energy > 0.72 || mood.contains("energetic") || mood.contains("club") {
            return .energetic
        }
        return .balanced
    }

    private static func spectrumProfile(seed: Int, intensity: Double, bias: TrackInsightVisualProfile.SpectrumBias?) -> [Double] {
        (0..<12).map { index in
            let position = Double(index) / 11.0
            let biasBoost: Double
            switch bias {
            case .low:
                biasBoost = 1.2 - position * 0.45
            case .mid:
                biasBoost = 0.82 + (1.0 - abs(position - 0.5) * 2.0) * 0.45
            case .high:
                biasBoost = 0.78 + position * 0.5
            case .balanced, nil:
                biasBoost = 1.0
            }
            return clamp(
                clamp(0.18 + normalized(seed, offset: index + 17) * 0.82 * (0.55 + intensity * 0.45), min: 0.12, max: 1.0)
                    * biasBoost,
                min: 0.12,
                max: 1.0
            )
        }
    }

    private static func palette(for style: MotionStyle) -> [String] {
        switch style {
        case .dreamy:
            ["#4DA3FF", "#7B61FF", "#D184FF"]
        case .energetic:
            ["#FF6A3D", "#FF2E63", "#FFD166"]
        case .organic:
            ["#2EC4B6", "#8AC926", "#F4A261"]
        case .dark:
            ["#111827", "#4338CA", "#06B6D4"]
        case .balanced:
            ["#2563EB", "#A855F7", "#14B8A6"]
        }
    }

    private static func stableSeed(for insight: TrackInsight) -> Int {
        [insight.title, insight.artist, insight.album ?? "", insight.vibe ?? "", insight.mood ?? ""]
            .joined(separator: "|")
            .unicodeScalars
            .reduce(into: 17) { value, scalar in
                value = ((value &* 33) &+ Int(scalar.value)) & 0x7fffffff
            }
    }

    private static func normalized(_ seed: Int, offset: Int) -> Double {
        let value = (seed &+ offset &* 1103515245) & 0x7fffffff
        return Double(value % 10_000) / 10_000.0
    }

    private static func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.max(minValue, Swift.min(maxValue, value))
    }
}

public enum TrackInsightParser {
    public static func parse(
        data: Data,
        fallbackTitle: String? = nil,
        fallbackArtist: String? = nil,
        fallbackArtwork: URL? = nil
    ) -> TrackInsight? {
        if let payload = try? JSONDecoder().decode(TrackInsightPayload.self, from: data) {
            return makeInsight(from: payload, rawText: String(data: data, encoding: .utf8) ?? "", fallbackTitle: fallbackTitle, fallbackArtist: fallbackArtist, fallbackArtwork: fallbackArtwork)
        }
        return nil
    }

    static func makeInsight(
        from payload: TrackInsightPayload,
        rawText: String,
        fallbackTitle: String?,
        fallbackArtist: String?,
        fallbackArtwork: URL?
    ) -> TrackInsight {
        let track = payload.track
        let analysis = payload.analysis
        let metrics = analysis?.metrics ?? payload.metrics
        let sections = payload.sections
        return TrackInsight(
            id: payload.id,
            timestamp: payload.createdAt ?? Date(),
            source: payload.source,
            title: payload.title ?? fallbackTitle ?? track?.title ?? "Current Track",
            artist: payload.artist ?? fallbackArtist ?? track?.artist ?? "Unknown Artist",
            album: payload.album ?? track?.album,
            artwork: payload.artwork ?? track?.artworkURL ?? fallbackArtwork,
            duration: seconds(fromMilliseconds: payload.durationMS ?? track?.durationMS) ?? payload.duration,
            progress: seconds(fromMilliseconds: track?.progressMS),
            isPlaying: track?.isPlaying,
            playerID: track?.playerID,
            entityID: track?.entityID,
            backend: track?.backend,
            genre: firstNonBlank(analysis?.genre, metrics?.genre, payload.genre, sectionValue(in: sections, ids: ["genre"], titles: ["genre"]), track?.compactGenres),
            subgenre: analysis?.subgenre,
            energy: normalizedMetric(analysis?.energy ?? metrics?.energy ?? payload.energy),
            danceability: normalizedMetric(analysis?.danceability ?? metrics?.danceability ?? payload.danceability),
            intensity: normalizedMetric(analysis?.intensity ?? metrics?.intensity ?? payload.intensity),
            mood: firstNonBlank(analysis?.mood, metrics?.mood, payload.mood, sectionValue(in: sections, ids: ["mood"], titles: ["mood", "stemming"])),
            vibe: firstNonBlank(analysis?.vibe, metrics?.vibe, payload.vibe, sectionValue(in: sections, ids: ["vibe"], titles: ["vibe"])),
            texture: firstNonBlank(analysis?.texture, metrics?.texture, payload.texture, sectionValue(in: sections, ids: ["texture"], titles: ["texture", "textuur"])),
            emotionalTone: analysis?.emotionalTone,
            confidence: normalizedMetric(analysis?.confidence ?? payload.confidence),
            summary: analysis?.summary ?? payload.summary ?? "Track Insight is ready.",
            rawAnalysisText: analysis?.fullText ?? payload.rawAnalysisText ?? rawText,
            productionNotes: analysis?.productionNotes ?? [],
            instrumentation: analysis?.instrumentation ?? [],
            arrangementNotes: analysis?.arrangementNotes ?? [],
            listeningCues: analysis?.listeningCues ?? [],
            similarTracks: analysis?.similarTracks ?? [],
            musicDNAMatchPercent: nil,
            musicDNALabel: nil,
            musicDNASummary: nil,
            visualProfile: payload.visualProfile,
            sections: sections
        )
    }

    private static func seconds(fromMilliseconds value: Int?) -> TimeInterval? {
        value.map { TimeInterval($0) / 1000.0 }
    }

    private static func normalizedMetric(_ value: Double?) -> Double? {
        guard let value else {
            return nil
        }
        if value > 1 {
            return max(0, min(1, value / 100))
        }
        return max(0, min(1, value))
    }

    private static func firstNonBlank(_ values: String?...) -> String? {
        values.lazy.compactMap { $0?.nilIfBlank }.first
    }

    private static func sectionValue(in sections: [TrackInsightSection], ids: Set<String>, titles: Set<String>) -> String? {
        sections.lazy.compactMap { section -> String? in
            let id = section.id.lowercased()
            let title = section.title.lowercased()
            guard ids.contains(id) || titles.contains(title) else {
                return nil
            }
            return firstNonBlank(section.value, section.summary)
        }.first
    }
}

struct TrackInsightPayload: Decodable {
    var id: String?
    var createdAt: Date?
    var source: String?
    var title: String?
    var artist: String?
    var album: String?
    var artwork: URL?
    var duration: TimeInterval?
    var durationMS: Int?
    var genre: String?
    var energy: Double?
    var danceability: Double?
    var intensity: Double?
    var mood: String?
    var vibe: String?
    var texture: String?
    var confidence: Double?
    var summary: String?
    var rawAnalysisText: String?
    var track: Track?
    var analysis: Analysis?
    var musicDNA: MusicDNA?
    var visualProfile: TrackInsightVisualProfile?
    var metrics: Metrics?
    var sections: [TrackInsightSection]

    struct Track: Decodable {
        var title: String?
        var artist: String?
        var album: String?
        var artworkURL: URL?
        var durationMS: Int?
        var progressMS: Int?
        var isPlaying: Bool?
        var playerID: String?
        var entityID: String?
        var backend: String?
        var genres: [String]

        var compactGenres: String? {
            let values = genres.compactMap { $0.nilIfBlank }
            guard !values.isEmpty else {
                return nil
            }
            return values.prefix(3).joined(separator: ", ")
        }

        enum CodingKeys: String, CodingKey {
            case title
            case trackName = "track_name"
            case mediaTitle = "media_title"
            case artist
            case artistName = "artist_name"
            case mediaArtist = "media_artist"
            case album
            case albumName = "album_name"
            case mediaAlbum = "media_album"
            case artworkURL = "artwork_url"
            case imageURL = "image_url"
            case albumImageURL = "album_image_url"
            case durationMS = "duration_ms"
            case progressMS = "progress_ms"
            case isPlaying = "is_playing"
            case playerID = "player_id"
            case entityID = "entity_id"
            case backend
            case genres
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decodeIfPresent(String.self, forKey: .title)
                ?? container.decodeIfPresent(String.self, forKey: .trackName)
                ?? container.decodeIfPresent(String.self, forKey: .mediaTitle)
            artist = try container.decodeIfPresent(String.self, forKey: .artist)
                ?? container.decodeIfPresent(String.self, forKey: .artistName)
                ?? container.decodeIfPresent(String.self, forKey: .mediaArtist)
            album = try container.decodeIfPresent(String.self, forKey: .album)
                ?? container.decodeIfPresent(String.self, forKey: .albumName)
                ?? container.decodeIfPresent(String.self, forKey: .mediaAlbum)
            artworkURL = try container.decodeIfPresent(URL.self, forKey: .artworkURL)
                ?? container.decodeIfPresent(URL.self, forKey: .imageURL)
                ?? container.decodeIfPresent(URL.self, forKey: .albumImageURL)
            durationMS = try container.decodeIfPresent(Int.self, forKey: .durationMS)
            progressMS = try container.decodeIfPresent(Int.self, forKey: .progressMS)
            isPlaying = try container.decodeIfPresent(Bool.self, forKey: .isPlaying)
            playerID = try container.decodeIfPresent(String.self, forKey: .playerID)
            entityID = try container.decodeIfPresent(String.self, forKey: .entityID)
            backend = try container.decodeIfPresent(String.self, forKey: .backend)
            genres = try container.decodeIfPresent([String].self, forKey: .genres) ?? []
        }
    }

    struct Analysis: Decodable {
        var summary: String?
        var fullText: String?
        var genre: String?
        var subgenre: String?
        var mood: String?
        var vibe: String?
        var texture: String?
        var emotionalTone: String?
        var energy: Double?
        var danceability: Double?
        var intensity: Double?
        var confidence: Double?
        var metrics: Metrics?
        var productionNotes: [String]
        var instrumentation: [String]
        var arrangementNotes: [String]
        var listeningCues: [String]
        var similarTracks: [TrackInsightSimilarTrack]

        enum CodingKeys: String, CodingKey {
            case summary
            case fullText = "full_text"
            case genre
            case subgenre
            case mood
            case vibe
            case texture
            case emotionalTone = "emotional_tone"
            case energy
            case danceability
            case intensity
            case confidence
            case metrics
            case audioFeatures = "audio_features"
            case productionNotes = "production_notes"
            case instrumentation
            case arrangementNotes = "arrangement_notes"
            case listeningCues = "listening_cues"
            case similarTracks = "similar_tracks"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            summary = try container.decodeIfPresent(String.self, forKey: .summary)
            fullText = try container.decodeIfPresent(String.self, forKey: .fullText)
            genre = try container.decodeIfPresent(String.self, forKey: .genre)
            subgenre = try container.decodeIfPresent(String.self, forKey: .subgenre)
            mood = try container.decodeIfPresent(String.self, forKey: .mood)
            vibe = try container.decodeIfPresent(String.self, forKey: .vibe)
            texture = try container.decodeIfPresent(String.self, forKey: .texture)
            emotionalTone = try container.decodeIfPresent(String.self, forKey: .emotionalTone)
            energy = try container.decodeIfPresent(Double.self, forKey: .energy)
            danceability = try container.decodeIfPresent(Double.self, forKey: .danceability)
            intensity = try container.decodeIfPresent(Double.self, forKey: .intensity)
            confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
            metrics = try container.decodeIfPresent(Metrics.self, forKey: .metrics)
                ?? container.decodeIfPresent(Metrics.self, forKey: .audioFeatures)
            productionNotes = try container.decodeIfPresent([String].self, forKey: .productionNotes) ?? []
            instrumentation = try container.decodeIfPresent([String].self, forKey: .instrumentation) ?? []
            arrangementNotes = try container.decodeIfPresent([String].self, forKey: .arrangementNotes) ?? []
            listeningCues = try container.decodeIfPresent([String].self, forKey: .listeningCues) ?? []
            similarTracks = try container.decodeIfPresent([TrackInsightSimilarTrack].self, forKey: .similarTracks) ?? []
        }
    }

    struct Metrics: Decodable {
        var genre: String?
        var mood: String?
        var vibe: String?
        var texture: String?
        var energy: Double?
        var danceability: Double?
        var intensity: Double?

        enum CodingKeys: String, CodingKey {
            case genre
            case mood
            case vibe
            case texture
            case energy
            case energyPercent = "energy_percent"
            case danceability
            case danceabilityPercent = "danceability_percent"
            case intensity
            case intensityPercent = "intensity_percent"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            genre = try container.decodeIfPresent(String.self, forKey: .genre)
            mood = try container.decodeIfPresent(String.self, forKey: .mood)
            vibe = try container.decodeIfPresent(String.self, forKey: .vibe)
            texture = try container.decodeIfPresent(String.self, forKey: .texture)
            energy = try container.decodeIfPresent(Double.self, forKey: .energy)
                ?? container.decodeIfPresent(Double.self, forKey: .energyPercent)
            danceability = try container.decodeIfPresent(Double.self, forKey: .danceability)
                ?? container.decodeIfPresent(Double.self, forKey: .danceabilityPercent)
            intensity = try container.decodeIfPresent(Double.self, forKey: .intensity)
                ?? container.decodeIfPresent(Double.self, forKey: .intensityPercent)
        }
    }

    struct MusicDNA: Codable {
        var matchPercent: Int?
        var label: TrackInsight.MusicDNALabel?
        var summary: String?

        enum CodingKeys: String, CodingKey {
            case matchPercent = "match_percent"
            case label
            case summary
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case source
        case title
        case artist
        case album
        case artwork
        case duration
        case durationMS = "duration_ms"
        case genre
        case energy
        case danceability
        case intensity
        case mood
        case vibe
        case texture
        case confidence
        case summary
        case analysis
        case rawAnalysisText = "raw_analysis_text"
        case track
        case musicDNA = "music_dna"
        case visualProfile = "visual_profile"
        case metrics
        case audioFeatures = "audio_features"
        case sections
        case trackInsight = "track_insight"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let nested = try container.decodeIfPresent(TrackInsightPayload.self, forKey: .trackInsight) {
            self = nested
            return
        }
        id = try container.decodeIfPresent(String.self, forKey: .id)
        createdAt = Self.decodeDate(container, key: .createdAt)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        album = try container.decodeIfPresent(String.self, forKey: .album)
        artwork = try container.decodeIfPresent(URL.self, forKey: .artwork)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        durationMS = try container.decodeIfPresent(Int.self, forKey: .durationMS)
        genre = try container.decodeIfPresent(String.self, forKey: .genre)
        energy = try container.decodeIfPresent(Double.self, forKey: .energy)
        danceability = try container.decodeIfPresent(Double.self, forKey: .danceability)
        intensity = try container.decodeIfPresent(Double.self, forKey: .intensity)
        mood = try container.decodeIfPresent(String.self, forKey: .mood)
        vibe = try container.decodeIfPresent(String.self, forKey: .vibe)
        texture = try container.decodeIfPresent(String.self, forKey: .texture)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        rawAnalysisText = try container.decodeIfPresent(String.self, forKey: .rawAnalysisText)
        track = try container.decodeIfPresent(Track.self, forKey: .track)
        analysis = try container.decodeIfPresent(Analysis.self, forKey: .analysis)
        musicDNA = try container.decodeIfPresent(MusicDNA.self, forKey: .musicDNA)
        visualProfile = try container.decodeIfPresent(TrackInsightVisualProfile.self, forKey: .visualProfile)
        metrics = try container.decodeIfPresent(Metrics.self, forKey: .metrics)
            ?? container.decodeIfPresent(Metrics.self, forKey: .audioFeatures)
        sections = try container.decodeIfPresent([TrackInsightSection].self, forKey: .sections) ?? []
    }

    private static func decodeDate<K: CodingKey>(_ container: KeyedDecodingContainer<K>, key: K) -> Date? {
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }
        guard let value = try? container.decode(String.self, forKey: key) else {
            return nil
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) {
            return date
        }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: value)
    }
}

public protocol TrackInsightService: Sendable {
    func insight(for playback: DJConnectPlayback?) async throws -> TrackInsight
}

public struct DJConnectTrackInsightRequest: Codable, Equatable, Sendable, DJConnectProfileContextCarrier {
    public var deviceID: String?
    public var clientID: String?
    public var deviceName: String?
    public var title: String?
    public var artist: String?
    public var album: String?
    public var artworkURL: URL?
    public var durationMS: Int?
    public var progressMS: Int?
    public var entityID: String?
    public var playerID: String?
    public var musicBackend: String?
    public var clientType: String?
    public var forceRefresh: Bool
    public var locale: String?
    public var language: String?
    public var mood: Int?
    public var musicDNAKey: String?
    public var includeVisualProfile: Bool
    public var includeRawResponse: Bool
    public var profileID: String?
    public var sessionID: String?
    public var privateSession: Bool?
    public var requestSource: DJConnectProfileRequestSource?

    public init(
        deviceID: String? = nil,
        clientID: String? = nil,
        deviceName: String? = nil,
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        artworkURL: URL? = nil,
        durationMS: Int? = nil,
        progressMS: Int? = nil,
        entityID: String? = nil,
        playerID: String? = nil,
        musicBackend: String? = nil,
        clientType: String? = nil,
        forceRefresh: Bool = false,
        locale: String? = nil,
        language: String? = nil,
        mood: Int? = nil,
        musicDNAKey: String? = nil,
        includeVisualProfile: Bool = true,
        includeRawResponse: Bool = true,
        profileContext: DJConnectProfileContext? = nil
    ) {
        self.deviceID = deviceID
        self.clientID = clientID
        self.deviceName = deviceName
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.durationMS = durationMS.map { max(0, $0) }
        self.progressMS = progressMS.map { max(0, $0) }
        self.entityID = entityID
        self.playerID = playerID
        self.musicBackend = musicBackend
        self.clientType = clientType
        self.forceRefresh = forceRefresh
        self.locale = locale
        self.language = language
        self.mood = mood.map { max(0, min(100, $0)) }
        self.musicDNAKey = musicDNAKey
        self.includeVisualProfile = includeVisualProfile
        self.includeRawResponse = includeRawResponse
        self.profileID = profileContext?.profileID
        self.sessionID = profileContext?.sessionID
        self.privateSession = profileContext?.privateSession
        self.requestSource = profileContext?.requestSource ?? .trackInsight
    }

    public func normalizedForSend(identity: DJConnectIdentity) -> DJConnectTrackInsightRequest {
        var copy = self
        copy.deviceID = copy.deviceID?.nilIfBlank ?? identity.deviceID
        copy.clientID = copy.clientID?.nilIfBlank ?? identity.deviceID
        copy.deviceName = copy.deviceName?.nilIfBlank ?? identity.deviceName
        copy.clientType = copy.clientType?.nilIfBlank ?? identity.clientType.rawValue
        copy.title = copy.title?.nilIfBlank
        copy.artist = copy.artist?.nilIfBlank
        copy.album = copy.album?.nilIfBlank
        copy.durationMS = copy.durationMS.map { max(0, $0) }
        copy.progressMS = copy.progressMS.map { max(0, $0) }
        copy.locale = copy.locale?.nilIfBlank ?? copy.language?.nilIfBlank
        copy.language = copy.language?.nilIfBlank ?? copy.locale?.nilIfBlank
        copy.mood = copy.mood.map { max(0, min(100, $0)) }
        copy.musicDNAKey = copy.musicDNAKey?.nilIfBlank
        copy.profileID = copy.profileID?.nilIfBlank
        copy.sessionID = copy.sessionID?.nilIfBlank
        copy.requestSource = copy.requestSource ?? .trackInsight
        return copy
    }

    public func normalizedForSend(identity: DJConnectAPIIdentity) -> DJConnectTrackInsightRequest {
        var copy = self
        copy.deviceID = copy.deviceID?.nilIfBlank ?? identity.deviceID
        copy.clientID = copy.clientID?.nilIfBlank ?? identity.clientID
        copy.deviceName = copy.deviceName?.nilIfBlank ?? identity.deviceName
        copy.clientType = copy.clientType?.nilIfBlank ?? identity.clientType.rawValue
        copy.title = copy.title?.nilIfBlank
        copy.artist = copy.artist?.nilIfBlank
        copy.album = copy.album?.nilIfBlank
        copy.durationMS = copy.durationMS.map { max(0, $0) }
        copy.progressMS = copy.progressMS.map { max(0, $0) }
        copy.locale = copy.locale?.nilIfBlank ?? copy.language?.nilIfBlank
        copy.language = copy.language?.nilIfBlank ?? copy.locale?.nilIfBlank
        copy.mood = copy.mood.map { max(0, min(100, $0)) }
        copy.musicDNAKey = copy.musicDNAKey?.nilIfBlank
        copy.profileID = copy.profileID?.nilIfBlank
        copy.sessionID = copy.sessionID?.nilIfBlank
        copy.requestSource = copy.requestSource ?? .trackInsight
        return copy
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientID = "client_id"
        case deviceName = "device_name"
        case title
        case trackName = "track_name"
        case mediaTitle = "media_title"
        case artist
        case artistName = "artist_name"
        case mediaArtist = "media_artist"
        case album
        case albumName = "album_name"
        case mediaAlbum = "media_album"
        case artworkURL = "artwork_url"
        case imageURL = "image_url"
        case albumImageURL = "album_image_url"
        case durationMS = "duration_ms"
        case progressMS = "progress_ms"
        case entityID = "entity_id"
        case playerID = "player_id"
        case musicBackend = "music_backend"
        case clientType = "client_type"
        case forceRefresh = "force_refresh"
        case locale
        case language
        case mood
        case musicDNAKey = "music_dna_key"
        case includeVisualProfile = "include_visual_profile"
        case includeRawResponse = "include_raw_response"
        case profileID = "profile_id"
        case sessionID = "session_id"
        case privateSession = "private_session"
        case requestSource = "request_source"
        case track
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID)
        clientID = try container.decodeIfPresent(String.self, forKey: .clientID)
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .trackName)
            ?? container.decodeIfPresent(String.self, forKey: .mediaTitle)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
            ?? container.decodeIfPresent(String.self, forKey: .artistName)
            ?? container.decodeIfPresent(String.self, forKey: .mediaArtist)
        album = try container.decodeIfPresent(String.self, forKey: .album)
            ?? container.decodeIfPresent(String.self, forKey: .albumName)
            ?? container.decodeIfPresent(String.self, forKey: .mediaAlbum)
        artworkURL = try container.decodeIfPresent(URL.self, forKey: .artworkURL)
            ?? container.decodeIfPresent(URL.self, forKey: .imageURL)
            ?? container.decodeIfPresent(URL.self, forKey: .albumImageURL)
        durationMS = try container.decodeIfPresent(Int.self, forKey: .durationMS).map { max(0, $0) }
        progressMS = try container.decodeIfPresent(Int.self, forKey: .progressMS).map { max(0, $0) }
        entityID = try container.decodeIfPresent(String.self, forKey: .entityID)
        playerID = try container.decodeIfPresent(String.self, forKey: .playerID)
        musicBackend = try container.decodeIfPresent(String.self, forKey: .musicBackend)
        clientType = try container.decodeIfPresent(String.self, forKey: .clientType)
        forceRefresh = try container.decodeIfPresent(Bool.self, forKey: .forceRefresh) ?? false
        locale = try container.decodeIfPresent(String.self, forKey: .locale)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        mood = try container.decodeIfPresent(Int.self, forKey: .mood).map { max(0, min(100, $0)) }
        musicDNAKey = try container.decodeIfPresent(String.self, forKey: .musicDNAKey)
        includeVisualProfile = try container.decodeIfPresent(Bool.self, forKey: .includeVisualProfile) ?? true
        includeRawResponse = try container.decodeIfPresent(Bool.self, forKey: .includeRawResponse) ?? true
        profileID = try container.decodeIfPresent(String.self, forKey: .profileID)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
        privateSession = try container.decodeIfPresent(Bool.self, forKey: .privateSession)
        requestSource = try container.decodeIfPresent(DJConnectProfileRequestSource.self, forKey: .requestSource)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(deviceID, forKey: .deviceID)
        try container.encodeIfPresent(clientID, forKey: .clientID)
        try container.encodeIfPresent(deviceName, forKey: .deviceName)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(title, forKey: .trackName)
        try container.encodeIfPresent(artist, forKey: .artist)
        try container.encodeIfPresent(artist, forKey: .artistName)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encodeIfPresent(album, forKey: .albumName)
        try container.encodeIfPresent(artworkURL, forKey: .artworkURL)
        if title?.nilIfBlank != nil || artist?.nilIfBlank != nil || album?.nilIfBlank != nil || artworkURL != nil {
            try container.encode(TrackPayload(request: self), forKey: .track)
        }
        try container.encodeIfPresent(durationMS, forKey: .durationMS)
        try container.encodeIfPresent(progressMS, forKey: .progressMS)
        try container.encodeIfPresent(entityID, forKey: .entityID)
        try container.encodeIfPresent(playerID, forKey: .playerID)
        try container.encodeIfPresent(musicBackend, forKey: .musicBackend)
        try container.encodeIfPresent(clientType, forKey: .clientType)
        try container.encode(forceRefresh, forKey: .forceRefresh)
        try container.encodeIfPresent(locale, forKey: .locale)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(mood, forKey: .mood)
        try container.encodeIfPresent(musicDNAKey, forKey: .musicDNAKey)
        try container.encode(includeVisualProfile, forKey: .includeVisualProfile)
        try container.encode(includeRawResponse, forKey: .includeRawResponse)
        try container.encodeIfPresent(profileID, forKey: .profileID)
        try container.encodeIfPresent(sessionID, forKey: .sessionID)
        try container.encodeIfPresent(privateSession, forKey: .privateSession)
        try container.encodeIfPresent(requestSource, forKey: .requestSource)
    }

    private struct TrackPayload: Encodable {
        var title: String?
        var artist: String?
        var album: String?
        var artworkURL: URL?
        var durationMS: Int?
        var progressMS: Int?
        var playerID: String?
        var entityID: String?
        var backend: String?

        init(request: DJConnectTrackInsightRequest) {
            title = request.title?.nilIfBlank
            artist = request.artist?.nilIfBlank
            album = request.album?.nilIfBlank
            artworkURL = request.artworkURL
            durationMS = request.durationMS
            progressMS = request.progressMS
            playerID = request.playerID?.nilIfBlank
            entityID = request.entityID?.nilIfBlank
            backend = request.musicBackend?.nilIfBlank
        }

        enum CodingKeys: String, CodingKey {
            case title
            case artist
            case album
            case artworkURL = "artwork_url"
            case durationMS = "duration_ms"
            case progressMS = "progress_ms"
            case playerID = "player_id"
            case entityID = "entity_id"
            case backend
        }
    }
}

public struct TrackInsightEndpointResponse: Decodable, Sendable {
    public var success: Bool?
    public var error: String?
    public var message: String?
    public var text: String?
    public var djText: String?
    private var trackInsightPayload: TrackInsightPayload?

    public var trackInsightValue: TrackInsight? {
        trackInsightValue(fallbackTitle: nil, fallbackArtist: nil, fallbackArtwork: nil)
    }

    public func trackInsightValue(
        fallbackTitle: String?,
        fallbackArtist: String?,
        fallbackArtwork: URL?,
        fallbackDurationMS: Int? = nil,
        fallbackProgressMS: Int? = nil
    ) -> TrackInsight? {
        if let trackInsightPayload {
            return TrackInsightParser.makeInsight(
                from: trackInsightPayload,
                rawText: text ?? djText ?? message ?? "",
                fallbackTitle: fallbackTitle,
                fallbackArtist: fallbackArtist,
                fallbackArtwork: fallbackArtwork
            )
        }
        guard success != false else {
            return nil
        }
        guard let summary = [text, djText, message].compactMap({ $0?.nilIfBlank }).first else {
            return nil
        }
        return TrackInsight(
            source: "track_insight",
            title: fallbackTitle?.nilIfBlank ?? "Current Track",
            artist: fallbackArtist?.nilIfBlank ?? "Unknown Artist",
            artwork: fallbackArtwork,
            duration: fallbackDurationMS.map { TimeInterval(max(0, $0)) / 1000.0 },
            progress: fallbackProgressMS.map { TimeInterval(max(0, $0)) / 1000.0 },
            summary: summary,
            rawAnalysisText: summary
        )
    }

    enum CodingKeys: String, CodingKey {
        case success
        case error
        case message
        case text
        case djText = "dj_text"
        case trackInsight = "track_insight"
        case trackInsightCamel = "trackInsight"
        case data
        case insight
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        djText = try container.decodeIfPresent(String.self, forKey: .djText)
        trackInsightPayload = try container.decodeIfPresent(TrackInsightPayload.self, forKey: .trackInsight)
            ?? container.decodeIfPresent(TrackInsightPayload.self, forKey: .trackInsightCamel)
            ?? container.decodeIfPresent(TrackInsightPayload.self, forKey: .data)
            ?? container.decodeIfPresent(TrackInsightPayload.self, forKey: .insight)
            ?? (try? TrackInsightPayload(from: decoder))
    }
}

public struct DJConnectVibeCastRequest: Codable, Equatable, Sendable {
    public var locale: String?
    public var language: String?
    public var timezone: String?
    public var capabilities: [String]

    public init(
        locale: String? = nil,
        language: String? = nil,
        timezone: String? = nil,
        capabilities: [String] = ["bold", "emphasis", "magnify", "accent", "emoji_safe"]
    ) {
        self.locale = locale?.nilIfBlank
        self.language = language?.nilIfBlank ?? locale?.nilIfBlank
        self.timezone = timezone?.nilIfBlank
        self.capabilities = capabilities
    }

    enum CodingKeys: String, CodingKey {
        case locale
        case language
        case timezone
        case capabilities
    }
}

public struct DJConnectVibeCastResponse: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var reason: String?
    public var revision: Int?
    public var ttlSeconds: Int?
    public var pollAfterSeconds: Int?
    public var context: Context?
    public var items: [Item]
    public var cache: Cache?

    public var artistShoutOutImage: DJConnectVibeCastArtistImage? {
        DJConnectVibeCastArtistImage.selected(from: self)
    }

    public init(
        enabled: Bool,
        reason: String? = nil,
        revision: Int? = nil,
        ttlSeconds: Int? = nil,
        pollAfterSeconds: Int? = nil,
        context: Context? = nil,
        items: [Item] = [],
        cache: Cache? = nil
    ) {
        self.enabled = enabled
        self.reason = reason
        self.revision = revision
        self.ttlSeconds = ttlSeconds
        self.pollAfterSeconds = pollAfterSeconds
        self.context = context
        self.items = items
        self.cache = cache
    }

    public var effectivePollAfterSeconds: Int {
        max(10, min(300, pollAfterSeconds ?? ttlSeconds ?? 30))
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case reason
        case revision
        case ttlSeconds = "ttl_seconds"
        case pollAfterSeconds = "poll_after_seconds"
        case context
        case items
        case cache
    }

    public struct Context: Codable, Equatable, Sendable {
        public var trackID: String?
        public var title: String?
        public var artist: String?
        public var album: String?
        public var musicBackend: String?
        public var musicBackendName: String?
        public var musicBackendRevision: Int?
        public var artistImageURL: URL?
        public var genreBadge: GenreBadge?

        public init(
            trackID: String? = nil,
            title: String? = nil,
            artist: String? = nil,
            album: String? = nil,
            musicBackend: String? = nil,
            musicBackendName: String? = nil,
            musicBackendRevision: Int? = nil,
            artistImageURL: URL? = nil,
            genreBadge: GenreBadge? = nil
        ) {
            self.trackID = trackID
            self.title = title
            self.artist = artist
            self.album = album
            self.musicBackend = musicBackend
            self.musicBackendName = musicBackendName
            self.musicBackendRevision = musicBackendRevision
            self.artistImageURL = artistImageURL
            self.genreBadge = genreBadge
        }

        enum CodingKeys: String, CodingKey {
            case trackID = "track_id"
            case title
            case artist
            case album
            case musicBackend = "music_backend"
            case musicBackendName = "music_backend_name"
            case musicBackendRevision = "music_backend_revision"
            case artistImageURL = "artist_image_url"
            case artistImageUrl
            case genreBadge = "genre_badge"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            trackID = try container.decodeIfPresent(String.self, forKey: .trackID)
            title = try container.decodeIfPresent(String.self, forKey: .title)
            artist = try container.decodeIfPresent(String.self, forKey: .artist)
            album = try container.decodeIfPresent(String.self, forKey: .album)
            musicBackend = try container.decodeIfPresent(String.self, forKey: .musicBackend)
            musicBackendName = try container.decodeIfPresent(String.self, forKey: .musicBackendName)
            musicBackendRevision = try container.decodeIfPresent(Int.self, forKey: .musicBackendRevision)
            artistImageURL = DJConnectVibeCastContext.decodeProxiedImageURL(container, keys: [.artistImageURL, .artistImageUrl])
            genreBadge = try container.decodeIfPresent(GenreBadge.self, forKey: .genreBadge)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(trackID, forKey: .trackID)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encodeIfPresent(artist, forKey: .artist)
            try container.encodeIfPresent(album, forKey: .album)
            try container.encodeIfPresent(musicBackend, forKey: .musicBackend)
            try container.encodeIfPresent(musicBackendName, forKey: .musicBackendName)
            try container.encodeIfPresent(musicBackendRevision, forKey: .musicBackendRevision)
            try container.encodeIfPresent(artistImageURL, forKey: .artistImageURL)
            try container.encodeIfPresent(genreBadge, forKey: .genreBadge)
        }

        public struct GenreBadge: Codable, Equatable, Sendable {
            public var label: String?
            public var genre: String?
            public var placement: String?

            public init(label: String? = nil, genre: String? = nil, placement: String? = nil) {
                self.label = label
                self.genre = genre
                self.placement = placement
            }

            public var displayLabel: String? {
                let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }

            public var canonicalGenre: String? {
                let trimmed = genre?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }

            public var resolvedPlacement: String {
                placement?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "top_trailing"
                    ? "top_trailing"
                    : "top_trailing"
            }
        }
    }

    public struct Item: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        public var kind: Kind
        public var tone: String?
        public var priority: Int?
        public var displaySeconds: Int?
        public var placementHint: String?
        public var text: [TextSegment]
        public var source: Source?

        public init(
            id: String,
            kind: Kind,
            tone: String? = nil,
            priority: Int? = nil,
            displaySeconds: Int? = nil,
            placementHint: String? = nil,
            text: [TextSegment],
            source: Source? = nil
        ) {
            self.id = id
            self.kind = kind
            self.tone = tone
            self.priority = priority
            self.displaySeconds = displaySeconds
            self.placementHint = placementHint
            self.text = text
            self.source = source
        }

        public var plainText: String {
            text.map { $0.type == .lineBreak ? "\n" : $0.value }.joined()
        }

        enum CodingKeys: String, CodingKey {
            case id
            case kind
            case tone
            case priority
            case displaySeconds = "display_seconds"
            case placementHint = "placement_hint"
            case text
            case source
        }
    }

    public enum Kind: Codable, Equatable, Sendable {
        case trackFact
        case artistFact
        case albumFact
        case genreFact
        case trivia
        case listeningTip
        case moodNote
        case productionNote
        case historyNote
        case system
        case unknown(String)

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = switch raw {
            case "track_fact": .trackFact
            case "artist_fact": .artistFact
            case "album_fact": .albumFact
            case "genre_fact": .genreFact
            case "trivia": .trivia
            case "listening_tip": .listeningTip
            case "mood_note": .moodNote
            case "production_note": .productionNote
            case "history_note": .historyNote
            case "system": .system
            default: .unknown(raw)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        public var rawValue: String {
            switch self {
            case .trackFact: "track_fact"
            case .artistFact: "artist_fact"
            case .albumFact: "album_fact"
            case .genreFact: "genre_fact"
            case .trivia: "trivia"
            case .listeningTip: "listening_tip"
            case .moodNote: "mood_note"
            case .productionNote: "production_note"
            case .historyNote: "history_note"
            case .system: "system"
            case let .unknown(value): value
            }
        }
    }

    public struct TextSegment: Codable, Equatable, Sendable, Identifiable {
        public var id: String { "\(type.rawValue)-\(value)" }
        public var type: SegmentType
        public var value: String

        public init(type: SegmentType, value: String) {
            self.type = type
            self.value = value
        }
    }

    public enum SegmentType: Codable, Equatable, Sendable {
        case text
        case strong
        case emphasis
        case emoji
        case magnify
        case accent
        case lineBreak
        case unknown(String)

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = switch raw {
            case "text": .text
            case "strong": .strong
            case "emphasis": .emphasis
            case "emoji": .emoji
            case "magnify": .magnify
            case "accent": .accent
            case "line_break": .lineBreak
            default: .unknown(raw)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        public var rawValue: String {
            switch self {
            case .text: "text"
            case .strong: "strong"
            case .emphasis: "emphasis"
            case .emoji: "emoji"
            case .magnify: "magnify"
            case .accent: "accent"
            case .lineBreak: "line_break"
            case let .unknown(value): value
            }
        }
    }

    public struct Source: Codable, Equatable, Sendable {
        public var kind: String?
        public var confidence: String?

        public init(kind: String? = nil, confidence: String? = nil) {
            self.kind = kind
            self.confidence = confidence
        }
    }

    public struct Cache: Codable, Equatable, Sendable {
        public var hit: Bool?

        public init(hit: Bool? = nil) {
            self.hit = hit
        }
    }
}

public struct DemoTrackInsightService: TrackInsightService {
    public var tracks: [TrackInsight]

    public init(tracks: [TrackInsight] = DemoTrackInsightService.defaultTracks) {
        self.tracks = tracks
    }

    public func insight(for playback: DJConnectPlayback?) async throws -> TrackInsight {
        guard let playback, let title = playback.trackName?.lowercased(), !title.isEmpty else {
            return tracks[0]
        }
        let index = title.unicodeScalars.reduce(into: 0) { value, scalar in
            value = ((value &* 31) &+ Int(scalar.value)) & 0x7fffffff
        } % tracks.count
        return tracks.first { $0.title.lowercased() == title } ?? tracks[index]
    }

    public static let defaultTracks: [TrackInsight] = [
        TrackInsight(title: "Midnight City", artist: "M83", album: "Hurry Up, We're Dreaming", genre: "Synthpop", energy: 0.76, danceability: 0.66, intensity: 0.72, mood: "Nostalgic", vibe: "Nocturnal", texture: "Neon synth leads and gated drums", confidenceLabel: "demo", summary: "A glowing night-drive anthem with a bright synth hook, wide pads and a cinematic rush.", rawAnalysisText: "Demo Track Insight for Midnight City."),
        TrackInsight(title: "Sweet Disposition", artist: "The Temper Trap", album: "Conditions", genre: "Indie rock", energy: 0.82, danceability: 0.58, intensity: 0.76, mood: "Uplifting", vibe: "Anthemic", texture: "Chiming guitars and open-air vocal lift", confidenceLabel: "demo", summary: "An expansive indie build that feels weightless, optimistic and made for big emotional release.", rawAnalysisText: "Demo Track Insight for Sweet Disposition."),
        TrackInsight(title: "Electric Feel", artist: "MGMT", album: "Oracular Spectacular", genre: "Psychedelic pop", energy: 0.70, danceability: 0.86, intensity: 0.54, mood: "Playful", vibe: "Funky", texture: "Rubbery bass, loose percussion and shimmering synth color", confidenceLabel: "demo", summary: "A sly psychedelic groove with elastic bass, playful motion and a warm electric shimmer.", rawAnalysisText: "Demo Track Insight for Electric Feel."),
        TrackInsight(title: "Innerbloom", artist: "RUFUS DU SOL", album: "Bloom", genre: "Melodic house", energy: 0.64, danceability: 0.62, intensity: 0.70, mood: "Dreamy", vibe: "Expansive", texture: "Wide pads and patient percussion", confidenceLabel: "demo", summary: "A slow-blooming electronic piece where restraint makes the emotional release feel huge.", rawAnalysisText: "Demo Track Insight for Innerbloom."),
        TrackInsight(title: "Strobe", artist: "deadmau5", album: "For Lack of a Better Name", genre: "Progressive house", energy: 0.78, danceability: 0.66, intensity: 0.82, mood: "Dreamy", vibe: "Euphoric", texture: "Arpeggiated synths and long-build dynamics", confidenceLabel: "demo", summary: "A progressive build that turns repetition into anticipation and payoff.", rawAnalysisText: "Demo Track Insight for Strobe."),
        TrackInsight(title: "Sun & Moon", artist: "Above & Beyond", genre: "Trance", energy: 0.86, danceability: 0.72, intensity: 0.84, mood: "Energetic", vibe: "Anthemic", texture: "Bright supersaws and vocal lift", confidenceLabel: "demo", summary: "A peak-time anthem shaped around lift, release and communal emotion.", rawAnalysisText: "Demo Track Insight for Above & Beyond."),
        TrackInsight(title: "Beyond Beliefs", artist: "Ben Bohmer", genre: "Melodic techno", energy: 0.58, danceability: 0.60, intensity: 0.52, mood: "Organic", vibe: "Warm", texture: "Soft plucks and rounded low end", confidenceLabel: "demo", summary: "A warm melodic groove that feels detailed without overcrowding the mix.", rawAnalysisText: "Demo Track Insight for Ben Bohmer."),
        TrackInsight(title: "Marea", artist: "Fred again..", genre: "House", energy: 0.80, danceability: 0.88, intensity: 0.72, mood: "Energetic", vibe: "Human", texture: "Vocal chops and kinetic drums", confidenceLabel: "demo", summary: "A club record with an intimate human center, built from voice, rhythm and momentum.", rawAnalysisText: "Demo Track Insight for Fred again."),
        TrackInsight(title: "Hey Now", artist: "London Grammar", genre: "Electronic pop", energy: 0.46, danceability: 0.40, intensity: 0.62, mood: "Dark", vibe: "Haunting", texture: "Sparse percussion and spacious vocal reverb", confidenceLabel: "demo", summary: "A spacious, shadowed production where silence frames the vocal emotion.", rawAnalysisText: "Demo Track Insight for London Grammar."),
        TrackInsight(title: "Giorgio by Moroder", artist: "Daft Punk", genre: "Disco", energy: 0.76, danceability: 0.78, intensity: 0.74, mood: "Organic", vibe: "Cinematic", texture: "Live bass, synth layers and narrative arc", confidenceLabel: "demo", summary: "A history lesson disguised as a groove, expanding from spoken memory into full-band motion.", rawAnalysisText: "Demo Track Insight for Daft Punk."),
        TrackInsight(title: "Sultans of Swing", artist: "Dire Straits", genre: "Rock", energy: 0.65, danceability: 0.56, intensity: 0.58, mood: "Organic", vibe: "Loose", texture: "Clean guitar phrasing and dry rhythmic pocket", confidenceLabel: "demo", summary: "A guitar-led track whose character lives in touch, timing and conversational phrasing.", rawAnalysisText: "Demo Track Insight for Dire Straits."),
        TrackInsight(title: "Master of Puppets", artist: "Metallica", genre: "Metal", energy: 0.96, danceability: 0.42, intensity: 0.98, mood: "Dark", vibe: "Aggressive", texture: "Palm-muted riffs and sharp rhythmic attacks", confidenceLabel: "demo", summary: "A high-intensity metal architecture built from precision, contrast and relentless forward drive.", rawAnalysisText: "Demo Track Insight for Metallica."),
        TrackInsight(title: "Adagio for Strings", artist: "Samuel Barber", genre: "Classical", energy: 0.32, danceability: 0.10, intensity: 0.68, mood: "Dreamy", vibe: "Lamenting", texture: "Slow string suspensions and rising harmonic pressure", confidenceLabel: "demo", summary: "A patient orchestral ascent where tension comes from harmony, breath and restraint.", rawAnalysisText: "Demo Track Insight for orchestral music.")
    ]

    public static func localizedDefaultTracks(language: String) -> [TrackInsight] {
        let normalizedLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedLanguage == "nl" || normalizedLanguage.hasPrefix("nl-") || normalizedLanguage.hasPrefix("nl_") else {
            return defaultTracks
        }

        let localized: [String: (genre: String, mood: String, vibe: String, texture: String, summary: String)] = [
            "Midnight City": (
                "Synthpop",
                "Nostalgisch",
                "Nachtelijk",
                "Neon-synthlijnen en gated drums",
                "Een gloeiend nachtelijke drive-anthem met een heldere synthhook, brede pads en een filmische rush."
            ),
            "Sweet Disposition": (
                "Indierock",
                "Opbeurend",
                "Anthemisch",
                "Rinkelende gitaren en open vocal lift",
                "Een ruime indie-opbouw die gewichtloos, optimistisch en gemaakt voor grote emotionele ontlading voelt."
            ),
            "Electric Feel": (
                "Psychedelische pop",
                "Speels",
                "Funky",
                "Elastische bas, losse percussie en glinsterende synthkleur",
                "Een sluwe psychedelische groove met elastische bas, speelse beweging en een warme elektrische glans."
            ),
            "Innerbloom": (
                "Melodic house",
                "Dromerig",
                "Ruimtelijk",
                "Brede pads en geduldige percussie",
                "Een langzaam openbloeiend elektronisch stuk waarin terughoudendheid de ontlading groots laat voelen."
            ),
            "Strobe": (
                "Progressive house",
                "Dromerig",
                "Euforisch",
                "Arpeggio-synths en lang opgebouwde dynamiek",
                "Een progressieve opbouw die herhaling verandert in verwachting en ontlading."
            ),
            "Sun & Moon": (
                "Trance",
                "Energiek",
                "Anthemisch",
                "Heldere supersaws en vocal lift",
                "Een peak-time anthem rond lift, release en gedeelde emotie."
            ),
            "Beyond Beliefs": (
                "Melodic techno",
                "Organisch",
                "Warm",
                "Zachte plucks en afgeronde low-end",
                "Een warme melodische groove die gedetailleerd voelt zonder de mix vol te zetten."
            ),
            "Marea": (
                "House",
                "Energiek",
                "Menselijk",
                "Vocal chops en kinetische drums",
                "Een clubtrack met een intiem menselijk hart, gebouwd uit stem, ritme en momentum."
            ),
            "Hey Now": (
                "Elektronische pop",
                "Donker",
                "Spookachtig",
                "Spaarzame percussie en ruime vocal reverb",
                "Een ruimtelijke, schaduwrijke productie waarin stilte de vocale emotie omlijst."
            ),
            "Giorgio by Moroder": (
                "Disco",
                "Organisch",
                "Filmisch",
                "Live bas, synthlagen en verhalende boog",
                "Een geschiedenisles vermomd als groove, van gesproken herinnering naar volledige bandbeweging."
            ),
            "Sultans of Swing": (
                "Rock",
                "Organisch",
                "Losjes",
                "Heldere gitaarfrasering en droge ritmische pocket",
                "Een gitaartrack waarvan het karakter leeft in aanslag, timing en converserende frasering."
            ),
            "Master of Puppets": (
                "Metal",
                "Donker",
                "Agressief",
                "Palm-muted riffs en scherpe ritmische aanvallen",
                "Een metalstructuur op hoge intensiteit, gebouwd uit precisie, contrast en meedogenloze voorwaartse drive."
            ),
            "Adagio for Strings": (
                "Klassiek",
                "Dromerig",
                "Klagend",
                "Trage strijkerssuspensies en stijgende harmonische druk",
                "Een geduldige orkestrale klim waarin spanning komt uit harmonie, adem en beheersing."
            )
        ]

        return defaultTracks.map { track in
            guard let copy = localized[track.title] else {
                return track
            }
            var localizedTrack = track
            localizedTrack.genre = copy.genre
            localizedTrack.mood = copy.mood
            localizedTrack.vibe = copy.vibe
            localizedTrack.texture = copy.texture
            localizedTrack.summary = copy.summary
            localizedTrack.rawAnalysisText = "Demo Track Insight voor \(track.title)."
            return localizedTrack
        }
    }
}

public struct DJConnectAskDJHistoryItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String {
        uri ?? "\(kind ?? "item")|\(title)|\(subtitle ?? "")|\(playedAtLabel ?? playedAt ?? "")"
    }

    public var kind: String?
    public var title: String
    public var subtitle: String?
    public var uri: String?
    public var imageURL: URL?
    public var thumbnailURL: URL?
    public var playedAt: String?
    public var playedAtLabel: String?
    public var value: String?
    public var source: String?
    public var confidence: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case title
        case subtitle
        case value
        case source
        case confidence
        case uri
        case imageURL = "image_url"
        case imageUrl
        case thumbnailURL = "thumbnail_url"
        case thumbnailUrl
        case playedAt = "played_at"
        case playedAtCamel = "playedAt"
        case playedAtLabel = "played_at_label"
        case playedAtLabelCamel = "playedAtLabel"
    }

    public init(
        kind: String? = nil,
        title: String,
        subtitle: String? = nil,
        uri: String? = nil,
        imageURL: URL? = nil,
        thumbnailURL: URL? = nil,
        playedAt: String? = nil,
        playedAtLabel: String? = nil,
        value: String? = nil,
        source: String? = nil,
        confidence: String? = nil
    ) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.uri = uri
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.playedAt = playedAt
        self.playedAtLabel = playedAtLabel
        self.value = value
        self.source = source
        self.confidence = confidence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        confidence = try container.decodeIfPresent(String.self, forKey: .confidence)
        uri = try container.decodeIfPresent(String.self, forKey: .uri)
        imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .imageUrl)
        thumbnailURL = try container.decodeIfPresent(URL.self, forKey: .thumbnailURL)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .thumbnailUrl)
        playedAt = try container.decodeIfPresent(String.self, forKey: .playedAt)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .playedAtCamel)
        playedAtLabel = try container.decodeIfPresent(String.self, forKey: .playedAtLabel)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .playedAtLabelCamel)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encodeIfPresent(uri, forKey: .uri)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
        try container.encodeIfPresent(playedAt, forKey: .playedAt)
        try container.encodeIfPresent(playedAtLabel, forKey: .playedAtLabel)
    }
}

public struct DJConnectVibeCastContext: Codable, Equatable, Sendable {
    public var artistImageURL: URL?

    enum CodingKeys: String, CodingKey {
        case artistImageURL = "artist_image_url"
        case artistImageUrl
    }

    public init(artistImageURL: URL? = nil) {
        self.artistImageURL = artistImageURL
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        artistImageURL = Self.decodeProxiedImageURL(container, keys: [.artistImageURL, .artistImageUrl])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(artistImageURL, forKey: .artistImageURL)
    }
}

public struct DJConnectVibeCastItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String {
        "\(kind ?? "item")|\(title ?? text ?? "")|\(imageURL?.absoluteString ?? thumbnailURL?.absoluteString ?? "")"
    }

    public var kind: String?
    public var title: String?
    public var text: String?
    public var imageURL: URL?
    public var thumbnailURL: URL?
    public var imageAlt: String?
    public var imageSource: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case title
        case text
        case imageURL = "image_url"
        case imageUrl
        case thumbnailURL = "thumbnail_url"
        case thumbnailUrl
        case imageAlt = "image_alt"
        case imageSource = "image_source"
    }

    public init(
        kind: String? = nil,
        title: String? = nil,
        text: String? = nil,
        imageURL: URL? = nil,
        thumbnailURL: URL? = nil,
        imageAlt: String? = nil,
        imageSource: String? = nil
    ) {
        self.kind = kind
        self.title = title
        self.text = text
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.imageAlt = imageAlt
        self.imageSource = imageSource
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        imageURL = DJConnectVibeCastContext.decodeProxiedImageURL(container, keys: [.imageURL, .imageUrl])
        thumbnailURL = DJConnectVibeCastContext.decodeProxiedImageURL(container, keys: [.thumbnailURL, .thumbnailUrl])
        imageAlt = try container.decodeIfPresent(String.self, forKey: .imageAlt)
        imageSource = try container.decodeIfPresent(String.self, forKey: .imageSource)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
        try container.encodeIfPresent(imageAlt, forKey: .imageAlt)
        try container.encodeIfPresent(imageSource, forKey: .imageSource)
    }

    var resolvedImageURL: URL? {
        imageURL ?? thumbnailURL
    }

    var isArtistFact: Bool {
        kind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "artist_fact"
    }
}

public struct DJConnectVibeCastArtistImage: Codable, Equatable, Sendable {
    public var url: URL
    public var alt: String?
    public var source: String?

    public init(url: URL, alt: String? = nil, source: String? = nil) {
        self.url = url
        self.alt = alt
        self.source = source
    }

    public static func selected(from response: DJConnectVibeCastResponse) -> DJConnectVibeCastArtistImage? {
        guard let contextURL = response.context?.artistImageURL else {
            return nil
        }
        return DJConnectVibeCastArtistImage(url: contextURL)
    }
}

public struct DJConnectVibeCastRenderState: Equatable, Sendable {
    public var revision: Int?
    public var artistImage: DJConnectVibeCastArtistImage?

    public init(revision: Int? = nil, artistImage: DJConnectVibeCastArtistImage? = nil) {
        self.revision = revision
        self.artistImage = artistImage
    }

    public static func rendered(from response: DJConnectVibeCastResponse) -> DJConnectVibeCastRenderState {
        DJConnectVibeCastRenderState(revision: response.revision, artistImage: response.artistShoutOutImage)
    }
}

extension DJConnectVibeCastContext {
    static func decodeProxiedImageURL<K: CodingKey>(_ container: KeyedDecodingContainer<K>, keys: [K]) -> URL? {
        for key in keys {
            guard let rawValue = try? container.decodeIfPresent(String.self, forKey: key),
                  let url = proxiedDJConnectImageURL(from: rawValue) else {
                continue
            }
            return url
        }
        return nil
    }

    private static func proxiedDJConnectImageURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            return nil
        }
        if url.host == nil {
            return trimmed.hasPrefix("/api/djconnect/") ? url : nil
        }
        return url.path.hasPrefix("/api/djconnect/")
            || url.path.hasPrefix("/local/djconnect/")
            ? url
            : nil
    }
}

public struct DJConnectAskDJHistoryMessage: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var clientMessageID: String?
    public var exchangeID: String?
    public var exchangeOrder: Int?
    public var role: DJConnectAskDJHistoryRole
    public var messageKind: DJConnectAskDJMessageKind
    public var origin: String?
    public var textSource: String?
    public var isGeneratedText: Bool?
    public var mood: Int?
    public var text: String
    public var createdAt: Date
    public var clientID: String?
    public var clientType: DJConnectClientType?
    public var status: String?
    public var images: [DJConnectResponseImage]
    public var links: [DJConnectResponseLink]
    public var sources: [DJConnectResponseLink]
    public var audioURL: URL?
    public var announcement: DJAnnouncement?
    public var playbackActions: [DJConnectAskDJPlaybackAction]
    public var confirmationActions: [DJConnectAskDJPlaybackAction]
    public var intentInfo: DJConnectAskDJIntentInfo?
    public var trackInsight: TrackInsight?
    public var items: [DJConnectAskDJHistoryItem]

    enum CodingKeys: String, CodingKey {
        case id
        case clientMessageID = "client_message_id"
        case exchangeID = "exchange_id"
        case exchangeOrder = "exchange_order"
        case role
        case messageKind = "message_kind"
        case origin
        case textSource = "text_source"
        case isGeneratedText = "is_generated_text"
        case mood
        case moodContext = "mood_context"
        case text
        case djText = "dj_text"
        case message
        case createdAt = "created_at"
        case clientID = "client_id"
        case clientType = "client_type"
        case status
        case images
        case links
        case sources
        case audioURL = "audio_url"
        case audioUrl
        case announcement
        case playbackActions = "playback_actions"
        case confirmationActions = "confirmation_actions"
        case intentInfo = "intent"
        case trackInsight = "track_insight"
        case items
    }

    public init(
        id: String,
        clientMessageID: String? = nil,
        exchangeID: String? = nil,
        exchangeOrder: Int? = nil,
        role: DJConnectAskDJHistoryRole,
        messageKind: DJConnectAskDJMessageKind = .assistant,
        origin: String? = nil,
        textSource: String? = nil,
        isGeneratedText: Bool? = nil,
        mood: Int? = nil,
        text: String,
        createdAt: Date,
        clientID: String? = nil,
        clientType: DJConnectClientType? = nil,
        status: String? = nil,
        images: [DJConnectResponseImage] = [],
        links: [DJConnectResponseLink] = [],
        sources: [DJConnectResponseLink] = [],
        audioURL: URL? = nil,
        announcement: DJAnnouncement? = nil,
        playbackActions: [DJConnectAskDJPlaybackAction] = [],
        confirmationActions: [DJConnectAskDJPlaybackAction] = [],
        intentInfo: DJConnectAskDJIntentInfo? = nil,
        trackInsight: TrackInsight? = nil,
        items: [DJConnectAskDJHistoryItem] = []
    ) {
        self.id = id
        self.clientMessageID = clientMessageID
        self.exchangeID = exchangeID
        self.exchangeOrder = exchangeOrder
        self.role = role
        self.messageKind = messageKind
        self.origin = origin
        self.textSource = textSource
        self.isGeneratedText = isGeneratedText
        self.mood = mood.map { max(0, min(100, $0)) }
        self.text = text
        self.createdAt = createdAt
        self.clientID = clientID
        self.clientType = clientType
        self.status = status
        self.images = images
        self.links = links
        self.sources = sources
        self.announcement = announcement
        self.audioURL = announcement?.clientReplayAudioURL ?? audioURL
        self.playbackActions = playbackActions
        self.confirmationActions = confirmationActions
        self.intentInfo = intentInfo
        self.trackInsight = trackInsight
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        clientMessageID = try container.decodeIfPresent(String.self, forKey: .clientMessageID)
        exchangeID = try container.decodeIfPresent(String.self, forKey: .exchangeID)
        exchangeOrder = try container.decodeIfPresent(Int.self, forKey: .exchangeOrder)
        role = try container.decodeIfPresent(DJConnectAskDJHistoryRole.self, forKey: .role) ?? .assistant
        messageKind = try container.decodeIfPresent(DJConnectAskDJMessageKind.self, forKey: .messageKind) ?? .assistant
        origin = try container.decodeIfPresent(String.self, forKey: .origin)
        textSource = try container.decodeIfPresent(String.self, forKey: .textSource)
        isGeneratedText = try container.decodeIfPresent(Bool.self, forKey: .isGeneratedText)
        mood = Self.decodeMood(container, keys: [.mood, .moodContext])
        text = try container.decodeIfPresent(String.self, forKey: .text)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .djText)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .message)
            ?? ""
        createdAt = Self.decodeDate(container, key: .createdAt) ?? Date()
        clientID = try container.decodeIfPresent(String.self, forKey: .clientID)
        clientType = try container.decodeIfPresent(DJConnectClientType.self, forKey: .clientType)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        images = container.decodeLossyArrayIfPresent(DJConnectResponseImage.self, forKey: .images) ?? []
        let regularLinks = container.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .links) ?? []
        let sourceLinks = container.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .sources) ?? []
        links = regularLinks + sourceLinks
        sources = sourceLinks
        audioURL = try container.decodeIfPresent(URL.self, forKey: .audioURL)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .audioUrl)
        announcement = try container.decodeIfPresent(DJAnnouncement.self, forKey: .announcement)
        if let announcementAudioURL = announcement?.clientReplayAudioURL {
            audioURL = announcementAudioURL
        } else if announcement != nil {
            audioURL = nil
        }
        playbackActions = container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .playbackActions) ?? []
        confirmationActions = container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .confirmationActions) ?? []
        intentInfo = try container.decodeIfPresent(DJConnectAskDJIntentInfo.self, forKey: .intentInfo)
        if let payload = try container.decodeIfPresent(TrackInsightPayload.self, forKey: .trackInsight) {
            trackInsight = TrackInsightParser.makeInsight(from: payload, rawText: text, fallbackTitle: nil, fallbackArtist: nil, fallbackArtwork: nil)
        } else {
            trackInsight = nil
        }
        items = container.decodeLossyArrayIfPresent(DJConnectAskDJHistoryItem.self, forKey: .items) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(clientMessageID, forKey: .clientMessageID)
        try container.encodeIfPresent(exchangeID, forKey: .exchangeID)
        try container.encodeIfPresent(exchangeOrder, forKey: .exchangeOrder)
        try container.encode(role, forKey: .role)
        try container.encode(messageKind, forKey: .messageKind)
        try container.encodeIfPresent(origin, forKey: .origin)
        try container.encodeIfPresent(textSource, forKey: .textSource)
        try container.encodeIfPresent(isGeneratedText, forKey: .isGeneratedText)
        try container.encodeIfPresent(mood, forKey: .mood)
        try container.encode(text, forKey: .text)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(clientID, forKey: .clientID)
        try container.encodeIfPresent(clientType, forKey: .clientType)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encode(images, forKey: .images)
        try container.encode(links, forKey: .links)
        try container.encode(sources, forKey: .sources)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encodeIfPresent(announcement, forKey: .announcement)
        try container.encode(playbackActions, forKey: .playbackActions)
        try container.encode(confirmationActions, forKey: .confirmationActions)
        try container.encodeIfPresent(intentInfo, forKey: .intentInfo)
        try container.encodeIfPresent(trackInsight, forKey: .trackInsight)
        try container.encode(items, forKey: .items)
    }

    private static func decodeMood(_ container: KeyedDecodingContainer<CodingKeys>, keys: [CodingKeys]) -> Int? {
        for key in keys {
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
                return max(0, min(100, value))
            }
            if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
                return max(0, min(100, Int(value.rounded())))
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: key),
               let intValue = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return max(0, min(100, intValue))
            }
            if let value = try? container.decodeIfPresent(DJConnectJSONValue.self, forKey: key),
               let resolved = moodValue(from: value) {
                return resolved
            }
        }
        return nil
    }

    private static func moodValue(from value: DJConnectJSONValue) -> Int? {
        switch value {
        case let .int(value):
            return max(0, min(100, value))
        case let .double(value):
            return max(0, min(100, Int(value.rounded())))
        case let .string(value):
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)).map { max(0, min(100, $0)) }
        case let .object(object):
            for key in ["mood", "value", "current_mood", "score"] {
                if let candidate = object[key], let resolved = moodValue(from: candidate) {
                    return resolved
                }
            }
            return nil
        default:
            return nil
        }
    }

    static func decodeDate<K: CodingKey>(_ container: KeyedDecodingContainer<K>, key: K) -> Date? {
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }
        guard let value = try? container.decode(String.self, forKey: key) else {
            return nil
        }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: value) {
            return date
        }
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: value)
    }
}

public struct DJConnectAskDJHistoryResponse: Codable, Equatable, Sendable {
    public var success: Bool?
    public var cleared: Bool?
    public var userID: String?
    public var historyRevision: Int
    public var clearRevision: Int
    public var askDJClearRequired: Bool?
    public var messages: [DJConnectAskDJHistoryMessage]
    public var serverTime: Date?
    public var historyLimit: Int?
    public var historyTrimmedBefore: Date?
    public var historyTrimmedCount: Int?
    public var profileID: String?
    public var musicDNAKey: String?
    public var resolvedProfile: DJConnectResolvedProfile?
    public var resolution: DJConnectProfileResolution?

    enum CodingKeys: String, CodingKey {
        case success
        case cleared
        case userID = "user_id"
        case historyRevision = "history_revision"
        case clearRevision = "clear_revision"
        case askDJClearRequired = "ask_dj_clear_required"
        case messages
        case serverTime = "server_time"
        case historyLimit = "history_limit"
        case historyTrimmedBefore = "history_trimmed_before"
        case historyTrimmedCount = "history_trimmed_count"
        case profileID = "profile_id"
        case musicDNAKey = "music_dna_key"
        case resolvedProfile = "resolved_profile"
        case resolution
    }

    public init(
        success: Bool? = nil,
        cleared: Bool? = nil,
        userID: String? = nil,
        historyRevision: Int = 0,
        clearRevision: Int = 0,
        askDJClearRequired: Bool? = nil,
        messages: [DJConnectAskDJHistoryMessage] = [],
        serverTime: Date? = nil,
        historyLimit: Int? = nil,
        historyTrimmedBefore: Date? = nil,
        historyTrimmedCount: Int? = nil,
        profileID: String? = nil,
        musicDNAKey: String? = nil,
        resolvedProfile: DJConnectResolvedProfile? = nil,
        resolution: DJConnectProfileResolution? = nil
    ) {
        self.success = success
        self.cleared = cleared
        self.userID = userID
        self.historyRevision = historyRevision
        self.clearRevision = clearRevision
        self.askDJClearRequired = askDJClearRequired
        self.messages = messages
        self.serverTime = serverTime
        self.historyLimit = historyLimit
        self.historyTrimmedBefore = historyTrimmedBefore
        self.historyTrimmedCount = historyTrimmedCount
        self.profileID = profileID?.nilIfBlank
        self.musicDNAKey = musicDNAKey?.nilIfBlank
        self.resolvedProfile = resolvedProfile
        self.resolution = resolution
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success)
        cleared = try container.decodeIfPresent(Bool.self, forKey: .cleared)
        userID = try container.decodeIfPresent(String.self, forKey: .userID)
        historyRevision = try container.decodeIfPresent(Int.self, forKey: .historyRevision) ?? 0
        clearRevision = try container.decodeIfPresent(Int.self, forKey: .clearRevision) ?? 0
        askDJClearRequired = try container.decodeIfPresent(Bool.self, forKey: .askDJClearRequired)
        messages = try container.decodeIfPresent([DJConnectAskDJHistoryMessage].self, forKey: .messages) ?? []
        serverTime = Self.decodeDate(container, key: .serverTime)
        historyLimit = try container.decodeIfPresent(Int.self, forKey: .historyLimit)
        historyTrimmedBefore = Self.decodeDate(container, key: .historyTrimmedBefore)
        historyTrimmedCount = try container.decodeIfPresent(Int.self, forKey: .historyTrimmedCount)
        profileID = try container.decodeIfPresent(String.self, forKey: .profileID)?.nilIfBlank
        musicDNAKey = try container.decodeIfPresent(String.self, forKey: .musicDNAKey)?.nilIfBlank
        resolvedProfile = try container.decodeIfPresent(DJConnectResolvedProfile.self, forKey: .resolvedProfile)
        resolution = try container.decodeIfPresent(DJConnectProfileResolution.self, forKey: .resolution)
    }

    public var isClearAcknowledged: Bool {
        success == true || cleared == true || askDJClearRequired == true
    }

    static func decodeDate<K: CodingKey>(_ container: KeyedDecodingContainer<K>, key: K) -> Date? {
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }
        guard let value = try? container.decode(String.self, forKey: key) else {
            return nil
        }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: value) {
            return date
        }
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: value)
    }
}

public struct DJConnectAskDJClearHistoryRequest: Codable, Equatable, Sendable, DJConnectProfileContextCarrier {
    public var deviceID: String
    public var clientType: DJConnectClientType
    public var clientID: String
    public var deviceName: String
    public var musicDNAKey: String?
    public var profileID: String?
    public var sessionID: String?
    public var privateSession: Bool?
    public var requestSource: DJConnectProfileRequestSource?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientType = "client_type"
        case clientID = "client_id"
        case deviceName = "device_name"
        case musicDNAKey = "music_dna_key"
        case profileID = "profile_id"
        case sessionID = "session_id"
        case privateSession = "private_session"
        case requestSource = "request_source"
    }

    public init(identity: DJConnectIdentity, musicDNAKey: String? = nil, profileContext: DJConnectProfileContext? = nil) {
        self.deviceID = identity.deviceID
        self.clientType = identity.clientType
        self.clientID = identity.deviceID
        self.deviceName = identity.deviceName
        self.musicDNAKey = musicDNAKey
        self.profileID = profileContext?.profileID
        self.sessionID = profileContext?.sessionID
        self.privateSession = profileContext?.privateSession
        self.requestSource = profileContext?.requestSource ?? .askDJ
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceID = try container.decode(String.self, forKey: .deviceID)
        clientType = try container.decode(DJConnectClientType.self, forKey: .clientType)
        clientID = try container.decodeIfPresent(String.self, forKey: .clientID) ?? deviceID
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName) ?? ""
        musicDNAKey = try container.decodeIfPresent(String.self, forKey: .musicDNAKey)
        profileID = try container.decodeIfPresent(String.self, forKey: .profileID)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
        privateSession = try container.decodeIfPresent(Bool.self, forKey: .privateSession)
        requestSource = try container.decodeIfPresent(DJConnectProfileRequestSource.self, forKey: .requestSource)
    }
}

public struct DJConnectMusicDNAIdentityRequest: Codable, Equatable, Sendable, DJConnectProfileContextCarrier {
    public var deviceID: String
    public var clientID: String
    public var clientType: DJConnectClientType
    public var deviceName: String
    public var musicDNAKey: String?
    public var language: String?
    public var locale: String?
    public var mood: Int?
    public var profileID: String?
    public var sessionID: String?
    public var privateSession: Bool?
    public var requestSource: DJConnectProfileRequestSource?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientID = "client_id"
        case clientType = "client_type"
        case deviceName = "device_name"
        case musicDNAKey = "music_dna_key"
        case language
        case locale
        case mood
        case profileID = "profile_id"
        case sessionID = "session_id"
        case privateSession = "private_session"
        case requestSource = "request_source"
    }

    public init(
        identity: DJConnectIdentity,
        mood: Int? = nil,
        musicDNAKey: String? = nil,
        language: String? = nil,
        locale: String? = nil,
        profileContext: DJConnectProfileContext? = nil
    ) {
        self.deviceID = identity.deviceID
        self.clientID = identity.deviceID
        self.clientType = identity.clientType
        self.deviceName = identity.deviceName
        self.musicDNAKey = musicDNAKey?.nilIfBlank
        self.language = language?.nilIfBlank
        self.locale = locale?.nilIfBlank ?? language?.nilIfBlank
        self.mood = mood.map { max(0, min(100, $0)) }
        self.profileID = profileContext?.profileID
        self.sessionID = profileContext?.sessionID
        self.privateSession = profileContext?.privateSession
        self.requestSource = profileContext?.requestSource
    }
}

public struct DJConnectMusicDNASettingsRequest: Codable, Equatable, Sendable, DJConnectProfileContextCarrier {
    public var deviceID: String
    public var clientID: String
    public var clientType: DJConnectClientType
    public var deviceName: String
    public var musicDNAKey: String?
    public var language: String?
    public var locale: String?
    public var enabled: Bool
    public var mood: Int?
    public var profileID: String?
    public var sessionID: String?
    public var privateSession: Bool?
    public var requestSource: DJConnectProfileRequestSource?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientID = "client_id"
        case clientType = "client_type"
        case deviceName = "device_name"
        case musicDNAKey = "music_dna_key"
        case language
        case locale
        case enabled
        case mood
        case profileID = "profile_id"
        case sessionID = "session_id"
        case privateSession = "private_session"
        case requestSource = "request_source"
    }

    public init(
        identity: DJConnectIdentity,
        enabled: Bool,
        mood: Int? = nil,
        musicDNAKey: String? = nil,
        language: String? = nil,
        locale: String? = nil,
        profileContext: DJConnectProfileContext? = nil
    ) {
        self.deviceID = identity.deviceID
        self.clientID = identity.deviceID
        self.clientType = identity.clientType
        self.deviceName = identity.deviceName
        self.musicDNAKey = musicDNAKey?.nilIfBlank
        self.language = language?.nilIfBlank
        self.locale = locale?.nilIfBlank ?? language?.nilIfBlank
        self.enabled = enabled
        self.mood = mood.map { max(0, min(100, $0)) }
        self.profileID = profileContext?.profileID
        self.sessionID = profileContext?.sessionID
        self.privateSession = profileContext?.privateSession
        self.requestSource = profileContext?.requestSource
    }
}

public struct DJConnectMusicDNAImportRequest: Codable, Equatable, Sendable, DJConnectProfileContextCarrier {
    public var deviceID: String
    public var clientID: String
    public var clientType: DJConnectClientType
    public var deviceName: String
    public var musicDNAKey: String?
    public var language: String?
    public var locale: String?
    public var mood: Int?
    public var profile: DJConnectMusicDNAProfileResponse
    public var profileID: String?
    public var sessionID: String?
    public var privateSession: Bool?
    public var requestSource: DJConnectProfileRequestSource?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientID = "client_id"
        case clientType = "client_type"
        case deviceName = "device_name"
        case musicDNAKey = "music_dna_key"
        case language
        case locale
        case mood
        case profile
        case profileID = "profile_id"
        case sessionID = "session_id"
        case privateSession = "private_session"
        case requestSource = "request_source"
    }

    public init(
        identity: DJConnectIdentity,
        profile: DJConnectMusicDNAProfileResponse,
        mood: Int? = nil,
        musicDNAKey: String? = nil,
        language: String? = nil,
        locale: String? = nil,
        profileContext: DJConnectProfileContext? = nil
    ) {
        self.deviceID = identity.deviceID
        self.clientID = identity.deviceID
        self.clientType = identity.clientType
        self.deviceName = identity.deviceName
        self.musicDNAKey = musicDNAKey?.nilIfBlank
        self.language = language?.nilIfBlank
        self.locale = locale?.nilIfBlank ?? language?.nilIfBlank
        self.mood = mood.map { max(0, min(100, $0)) }
        self.profile = profile
        self.profileID = profileContext?.profileID
        self.sessionID = profileContext?.sessionID
        self.privateSession = profileContext?.privateSession
        self.requestSource = profileContext?.requestSource
    }
}

public struct DJConnectAskDJHistoryExportRequest: Codable, Equatable, Sendable {
    public struct Identity: Codable, Equatable, Sendable {
        public var deviceID: String
        public var clientType: DJConnectClientType
        public var deviceName: String

        enum CodingKeys: String, CodingKey {
            case deviceID = "device_id"
            case clientType = "client_type"
            case deviceName = "device_name"
        }

        public init(identity: DJConnectIdentity) {
            self.deviceID = identity.deviceID
            self.clientType = identity.clientType
            self.deviceName = identity.deviceName
        }
    }

    public var identity: Identity
    public var appVersion: String?

    enum CodingKeys: String, CodingKey {
        case identity
        case appVersion = "app_version"
    }

    public init(identity: DJConnectIdentity) {
        self.identity = Identity(identity: identity)
        self.appVersion = identity.appVersion?.nilIfBlank
    }
}

public struct DJConnectMusicDNAExportRequest: Codable, Equatable, Sendable, DJConnectProfileContextCarrier {
    public var deviceID: String
    public var clientID: String
    public var clientType: DJConnectClientType
    public var deviceName: String
    public var musicDNAKey: String?
    public var language: String?
    public var locale: String?
    public var appVersion: String?
    public var profileID: String?
    public var sessionID: String?
    public var privateSession: Bool?
    public var requestSource: DJConnectProfileRequestSource?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientID = "client_id"
        case clientType = "client_type"
        case deviceName = "device_name"
        case musicDNAKey = "music_dna_key"
        case language
        case locale
        case appVersion = "app_version"
        case profileID = "profile_id"
        case sessionID = "session_id"
        case privateSession = "private_session"
        case requestSource = "request_source"
    }

    public init(
        identity: DJConnectIdentity,
        musicDNAKey: String? = nil,
        language: String? = nil,
        locale: String? = nil,
        profileContext: DJConnectProfileContext? = nil
    ) {
        self.deviceID = identity.deviceID
        self.clientID = identity.deviceID
        self.clientType = identity.clientType
        self.deviceName = identity.deviceName
        self.musicDNAKey = musicDNAKey?.nilIfBlank
        self.language = language?.nilIfBlank
        self.locale = locale?.nilIfBlank ?? language?.nilIfBlank
        self.appVersion = identity.appVersion?.nilIfBlank
        self.profileID = profileContext?.profileID
        self.sessionID = profileContext?.sessionID
        self.privateSession = profileContext?.privateSession
        self.requestSource = profileContext?.requestSource
    }
}

public struct DJConnectMusicDNAExportResponse: Codable, Equatable, Sendable {
    public var success: Bool?
    public var format: String
    public var schemaVersion: Int
    public var exportedAt: Date
    public var exportedByClientType: String
    public var appVersion: String?
    public var profile: DJConnectMusicDNAProfileResponse

    enum CodingKeys: String, CodingKey {
        case success
        case format
        case schemaVersion = "schema_version"
        case exportedAt = "exported_at"
        case exportedByClientType = "exported_by_client_type"
        case appVersion = "app_version"
        case profile
    }

    public init(
        success: Bool? = nil,
        format: String,
        schemaVersion: Int,
        exportedAt: Date,
        exportedByClientType: String,
        appVersion: String? = nil,
        profile: DJConnectMusicDNAProfileResponse
    ) {
        self.success = success
        self.format = format
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.exportedByClientType = exportedByClientType
        self.appVersion = appVersion
        self.profile = profile
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let exportedAtValue = try container.decode(String.self, forKey: .exportedAt)
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        guard let exportedAt = fractional.date(from: exportedAtValue) ?? fallback.date(from: exportedAtValue) else {
            throw DecodingError.dataCorruptedError(
                forKey: .exportedAt,
                in: container,
                debugDescription: "Invalid ISO8601 exported_at date"
            )
        }
        self.init(
            success: try container.decodeIfPresent(Bool.self, forKey: .success),
            format: try container.decode(String.self, forKey: .format),
            schemaVersion: try container.decode(Int.self, forKey: .schemaVersion),
            exportedAt: exportedAt,
            exportedByClientType: try container.decode(String.self, forKey: .exportedByClientType),
            appVersion: try container.decodeIfPresent(String.self, forKey: .appVersion),
            profile: try container.decode(DJConnectMusicDNAProfileResponse.self, forKey: .profile)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(success, forKey: .success)
        try container.encode(format, forKey: .format)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(formatter.string(from: exportedAt), forKey: .exportedAt)
        try container.encode(exportedByClientType, forKey: .exportedByClientType)
        try container.encodeIfPresent(appVersion, forKey: .appVersion)
        try container.encode(profile, forKey: .profile)
    }
}

public enum DJConnectMusicDiscoveryItemKind: Codable, Equatable, Sendable {
    case track
    case album
    case artist
    case playlist
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .track:
            return "track"
        case .album:
            return "album"
        case .artist:
            return "artist"
        case .playlist:
            return "playlist"
        case let .unknown(value):
            return value
        }
    }

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "track":
            self = .track
        case "album":
            self = .album
        case "artist":
            self = .artist
        case "playlist":
            self = .playlist
        default:
            self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum DJConnectMusicDiscoveryConfidence: String, Codable, Equatable, Sendable {
    case low
    case medium
    case high
}

public struct DJConnectMusicDiscoveryItem: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var kind: DJConnectMusicDiscoveryItemKind
    public var title: String
    public var subtitle: String?
    public var uri: String?
    public var imageURL: String?
    public var reason: String
    public var reasonSources: [String]
    public var confidence: DJConnectMusicDiscoveryConfidence?
    public var qualityScore: Double?
    public var qualityBand: String?
    public var qualityFactors: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case subtitle
        case uri
        case imageURL = "image_url"
        case imageUrl
        case thumbnailURL = "thumbnail_url"
        case thumbnailUrl
        case albumImageURL = "album_image_url"
        case albumImageUrl
        case albumArtURL = "album_art_url"
        case albumArtUrl
        case artwork
        case reason
        case reasonSources = "reason_sources"
        case confidence
        case qualityScore = "quality_score"
        case qualityBand = "quality_band"
        case qualityFactors = "quality_factors"
    }

    public init(
        id: String,
        kind: DJConnectMusicDiscoveryItemKind,
        title: String,
        subtitle: String? = nil,
        uri: String? = nil,
        imageURL: String? = nil,
        reason: String,
        reasonSources: [String] = [],
        confidence: DJConnectMusicDiscoveryConfidence? = nil,
        qualityScore: Double? = nil,
        qualityBand: String? = nil,
        qualityFactors: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle?.nilIfBlank
        self.uri = uri?.nilIfBlank
        self.imageURL = imageURL?.nilIfBlank
        self.reason = reason
        self.reasonSources = reasonSources
        self.confidence = confidence
        self.qualityScore = qualityScore
        self.qualityBand = qualityBand?.nilIfBlank
        self.qualityFactors = qualityFactors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id).trimmingCharacters(in: .whitespacesAndNewlines)
        kind = try container.decode(DJConnectMusicDiscoveryItemKind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title).trimmingCharacters(in: .whitespacesAndNewlines)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)?.nilIfBlank
        uri = try container.decodeIfPresent(String.self, forKey: .uri)?.nilIfBlank
        imageURL = Self.decodeStringAliasIfPresent(
            container,
            .imageURL,
            .imageUrl,
            .thumbnailURL,
            .thumbnailUrl,
            .albumImageURL,
            .albumImageUrl,
            .albumArtURL,
            .albumArtUrl,
            .artwork
        )
        reason = (try container.decodeIfPresent(String.self, forKey: .reason) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        reasonSources = container.decodeLossyArrayIfPresent(String.self, forKey: .reasonSources) ?? []
        confidence = try container.decodeIfPresent(DJConnectMusicDiscoveryConfidence.self, forKey: .confidence)
        qualityScore = try container.decodeIfPresent(Double.self, forKey: .qualityScore)
        qualityBand = try container.decodeIfPresent(String.self, forKey: .qualityBand)?.nilIfBlank
        qualityFactors = container.decodeLossyArrayIfPresent(String.self, forKey: .qualityFactors) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encodeIfPresent(uri, forKey: .uri)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encode(reason, forKey: .reason)
        try container.encode(reasonSources, forKey: .reasonSources)
        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encodeIfPresent(qualityScore, forKey: .qualityScore)
        try container.encodeIfPresent(qualityBand, forKey: .qualityBand)
        try container.encode(qualityFactors, forKey: .qualityFactors)
    }

    private static func decodeStringAliasIfPresent(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ keys: CodingKeys...
    ) -> String? {
        for key in keys {
            if let value = try? container.decodeIfPresent(String.self, forKey: key)?.nilIfBlank {
                return value
            }
        }
        return nil
    }

    public var isDisplayable: Bool {
        !id.isEmpty
            && !title.isEmpty
    }

    public var isPlayable: Bool {
        uri?.isEmpty == false
    }
}

public struct DJConnectMusicDiscoverySection: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var items: [DJConnectMusicDiscoveryItem]

    public init(id: String, title: String, items: [DJConnectMusicDiscoveryItem]) {
        self.id = id
        self.title = title
        self.items = items
    }

    public var visibleItems: [DJConnectMusicDiscoveryItem] {
        items.filter(\.isDisplayable)
    }

    public var isDisplayable: Bool {
        !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !visibleItems.isEmpty
    }
}

public struct DJConnectMusicDiscoveryResponse: Codable, Equatable, Sendable {
    public struct Cache: Codable, Equatable, Sendable {
        public var hit: Bool?

        public init(hit: Bool? = nil) {
            self.hit = hit
        }
    }

    public var success: Bool
    public var enabled: Bool
    public var reason: String?
    public var revision: Int?
    public var generatedAt: Date?
    public var ttlSeconds: Int?
    public var source: String?
    public var profileID: String?
    public var musicDNAKey: String?
    public var resolvedProfile: DJConnectResolvedProfile?
    public var resolution: DJConnectProfileResolution?
    public var cache: Cache?
    public var sections: [DJConnectMusicDiscoverySection]
    public var error: String?
    public var message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case enabled
        case reason
        case revision
        case generatedAt = "generated_at"
        case ttlSeconds = "ttl_seconds"
        case source
        case profileID = "profile_id"
        case musicDNAKey = "music_dna_key"
        case resolvedProfile = "resolved_profile"
        case resolution
        case cache
        case sections
        case error
        case message
    }

    public init(
        success: Bool = true,
        enabled: Bool = false,
        reason: String? = nil,
        revision: Int? = nil,
        generatedAt: Date? = nil,
        ttlSeconds: Int? = nil,
        source: String? = nil,
        profileID: String? = nil,
        musicDNAKey: String? = nil,
        resolvedProfile: DJConnectResolvedProfile? = nil,
        resolution: DJConnectProfileResolution? = nil,
        cache: Cache? = nil,
        sections: [DJConnectMusicDiscoverySection] = [],
        error: String? = nil,
        message: String? = nil
    ) {
        self.success = success
        self.enabled = enabled
        self.reason = reason?.nilIfBlank
        self.revision = revision
        self.generatedAt = generatedAt
        self.ttlSeconds = ttlSeconds.map { max(0, $0) }
        self.source = source?.nilIfBlank
        self.profileID = profileID?.nilIfBlank
        self.musicDNAKey = musicDNAKey?.nilIfBlank
        self.resolvedProfile = resolvedProfile
        self.resolution = resolution
        self.cache = cache
        self.sections = sections
        self.error = error?.nilIfBlank
        self.message = message?.nilIfBlank
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? true
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        reason = try container.decodeIfPresent(String.self, forKey: .reason)?.nilIfBlank
        revision = try container.decodeIfPresent(Int.self, forKey: .revision)
        generatedAt = DJConnectAskDJHistoryResponse.decodeDate(container, key: .generatedAt)
        ttlSeconds = try container.decodeIfPresent(Int.self, forKey: .ttlSeconds).map { max(0, $0) }
        source = try container.decodeIfPresent(String.self, forKey: .source)?.nilIfBlank
        profileID = try container.decodeIfPresent(String.self, forKey: .profileID)?.nilIfBlank
        musicDNAKey = try container.decodeIfPresent(String.self, forKey: .musicDNAKey)?.nilIfBlank
        resolvedProfile = try container.decodeIfPresent(DJConnectResolvedProfile.self, forKey: .resolvedProfile)
        resolution = try container.decodeIfPresent(DJConnectProfileResolution.self, forKey: .resolution)
        cache = try container.decodeIfPresent(Cache.self, forKey: .cache)
        sections = container.decodeLossyArrayIfPresent(DJConnectMusicDiscoverySection.self, forKey: .sections) ?? []
        error = try container.decodeIfPresent(String.self, forKey: .error)?.nilIfBlank
        message = try container.decodeIfPresent(String.self, forKey: .message)?.nilIfBlank
    }

    public var visibleSections: [DJConnectMusicDiscoverySection] {
        guard enabled else { return [] }
        return sections.filter(\.isDisplayable)
    }

    public var isMusicDNADisabled: Bool {
        enabled == false && reason == "music_dna_disabled"
    }
}

public struct DJConnectMusicDiscoveryPlayRequest: Codable, Equatable, Sendable, DJConnectProfileContextCarrier {
    public var discoveryItemID: String
    public var sectionID: String
    public var deviceID: String
    public var clientID: String?
    public var clientType: DJConnectClientType
    public var musicDNAKey: String?
    public var profileID: String?
    public var sessionID: String?
    public var privateSession: Bool?
    public var requestSource: DJConnectProfileRequestSource?

    enum CodingKeys: String, CodingKey {
        case discoveryItemID = "discovery_item_id"
        case sectionID = "section_id"
        case deviceID = "device_id"
        case clientID = "client_id"
        case clientType = "client_type"
        case musicDNAKey = "music_dna_key"
        case profileID = "profile_id"
        case sessionID = "session_id"
        case privateSession = "private_session"
        case requestSource = "request_source"
    }

    public init(discoveryItemID: String, sectionID: String, identity: DJConnectIdentity, musicDNAKey: String? = nil, profileContext: DJConnectProfileContext? = nil) {
        self.discoveryItemID = discoveryItemID
        self.sectionID = sectionID
        self.deviceID = identity.deviceID
        self.clientID = identity.deviceID.nilIfBlank
        self.clientType = identity.clientType
        self.musicDNAKey = musicDNAKey?.nilIfBlank
        self.profileID = profileContext?.profileID
        self.sessionID = profileContext?.sessionID
        self.privateSession = profileContext?.privateSession
        self.requestSource = profileContext?.requestSource ?? .discover
    }
}

public enum DJConnectMusicDiscoveryFeedback: String, Codable, Equatable, CaseIterable, Sendable {
    case notForMe = "not_for_me"
    case lessLikeThis = "less_like_this"
    case hideArtist = "hide_artist"
}

public struct DJConnectMusicDiscoveryFeedbackRequest: Codable, Equatable, Sendable, DJConnectProfileContextCarrier {
    public var discoveryItemID: String
    public var sectionID: String
    public var feedback: DJConnectMusicDiscoveryFeedback
    public var deviceID: String
    public var clientID: String?
    public var clientType: DJConnectClientType
    public var musicDNAKey: String?
    public var profileID: String?
    public var sessionID: String?
    public var privateSession: Bool?
    public var requestSource: DJConnectProfileRequestSource?

    enum CodingKeys: String, CodingKey {
        case discoveryItemID = "discovery_item_id"
        case sectionID = "section_id"
        case feedback
        case deviceID = "device_id"
        case clientID = "client_id"
        case clientType = "client_type"
        case musicDNAKey = "music_dna_key"
        case profileID = "profile_id"
        case sessionID = "session_id"
        case privateSession = "private_session"
        case requestSource = "request_source"
    }

    public init(
        discoveryItemID: String,
        sectionID: String,
        feedback: DJConnectMusicDiscoveryFeedback,
        identity: DJConnectIdentity,
        musicDNAKey: String? = nil,
        profileContext: DJConnectProfileContext? = nil
    ) {
        self.discoveryItemID = discoveryItemID
        self.sectionID = sectionID
        self.feedback = feedback
        self.deviceID = identity.deviceID
        self.clientID = identity.deviceID.nilIfBlank
        self.clientType = identity.clientType
        self.musicDNAKey = musicDNAKey?.nilIfBlank
        self.profileID = profileContext?.profileID
        self.sessionID = profileContext?.sessionID
        self.privateSession = profileContext?.privateSession
        self.requestSource = profileContext?.requestSource ?? .discover
    }
}

public struct DJConnectMusicDNAProfileResponse: Codable, Equatable, Sendable {
    public var success: Bool
    public var profileID: String?
    public var musicDNAKey: String?
    public var enabled: Bool
    public var generation: Int?
    public var clearRequestedAt: Date?
    public var updatedAt: Date?
    public var profile: DJConnectMusicDNAProfile
    public var sources: [DJConnectResponseLink]
    public var resolvedProfile: DJConnectResolvedProfile?
    public var resolution: DJConnectProfileResolution?
    public var error: String?
    public var message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case profileID = "profile_id"
        case musicDNAKey = "music_dna_key"
        case enabled
        case generation
        case clearRequestedAt = "clear_requested_at"
        case updatedAt = "updated_at"
        case profile
        case sources
        case resolvedProfile = "resolved_profile"
        case resolution
        case error
        case message
    }

    public init(
        success: Bool = true,
        profileID: String? = nil,
        musicDNAKey: String? = nil,
        enabled: Bool = false,
        generation: Int? = nil,
        clearRequestedAt: Date? = nil,
        updatedAt: Date? = nil,
        profile: DJConnectMusicDNAProfile = DJConnectMusicDNAProfile(),
        sources: [DJConnectResponseLink] = [],
        resolvedProfile: DJConnectResolvedProfile? = nil,
        resolution: DJConnectProfileResolution? = nil,
        error: String? = nil,
        message: String? = nil
    ) {
        self.success = success
        self.profileID = profileID?.nilIfBlank
        self.musicDNAKey = musicDNAKey
        self.enabled = enabled
        self.generation = generation
        self.clearRequestedAt = clearRequestedAt
        self.updatedAt = updatedAt
        self.profile = profile
        self.sources = sources
        self.resolvedProfile = resolvedProfile
        self.resolution = resolution
        self.error = error
        self.message = message
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? true
        profileID = try container.decodeIfPresent(String.self, forKey: .profileID)?.nilIfBlank
        musicDNAKey = try container.decodeIfPresent(String.self, forKey: .musicDNAKey)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        generation = try container.decodeIfPresent(Int.self, forKey: .generation)
        clearRequestedAt = DJConnectAskDJHistoryResponse.decodeDate(container, key: .clearRequestedAt)
        updatedAt = DJConnectAskDJHistoryResponse.decodeDate(container, key: .updatedAt)
        profile = try container.decodeIfPresent(DJConnectMusicDNAProfile.self, forKey: .profile) ?? DJConnectMusicDNAProfile()
        sources = container.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .sources) ?? []
        resolvedProfile = try container.decodeIfPresent(DJConnectResolvedProfile.self, forKey: .resolvedProfile)
        resolution = try container.decodeIfPresent(DJConnectProfileResolution.self, forKey: .resolution)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

public struct DJConnectMusicDNAProfile: Codable, Equatable, Sendable {
    public var summary: String?
    public var trackCount: Int?
    public var artistCount: Int?
    public var genreCount: Int?
    public var favoriteGenres: [DJConnectMusicDNANameValue]?
    public var favoriteArtists: [DJConnectMusicDNANameValue]?
    public var recentTracks: [DJConnectMusicDNATrack]?
    public var recentFavoriteTracks: [DJConnectMusicDNATrack]?
    public var topTracksByRange: [String: [DJConnectMusicDNATrack]]
    public var topArtistsByRange: [String: [DJConnectMusicDNANameValue]]
    public var mood: DJConnectMusicDNAMood?
    public var energyProfile: DJConnectMusicDNAEnergyProfile?
    public var playtime: DJConnectMusicDNAPlaytime?
    public var listeningRhythm: DJConnectMusicDNAListeningRhythm?
    public var moodMix: DJConnectMusicDNAMoodMix?
    public var repeatMagnets: DJConnectMusicDNARepeatMagnets?
    public var explicitPositives: DJConnectMusicDNAExplicitPositives?
    public var tasteAnchors: DJConnectMusicDNATasteAnchors?
    public var tasteDirection: String?
    public var basedOn: [DJConnectMusicDNASignal]?
    public var timePatterns: [DJConnectMusicDNASignal]?
    public var recommendationSignals: [DJConnectMusicDNASignal]?
    public var blockedArtists: [DJConnectMusicDNANameValue]?
    public var blockedItems: [DJConnectMusicDNASignal]?
    public var snapshotHistory: [DJConnectMusicDNASnapshot]
    public var discoveryFeedback: DJConnectMusicDNADiscoveryFeedback?
    public var privacyDashboard: DJConnectMusicDNAPrivacyDashboard?
    public var lastProfileRefresh: Date?
    public var consentUpdatedAt: Date?
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case summary
        case trackCount = "track_count"
        case artistCount = "artist_count"
        case genreCount = "genre_count"
        case favoriteGenres = "favorite_genres"
        case favoriteArtists = "favorite_artists"
        case recentTracks = "recent_tracks"
        case recentFavoriteTracks = "recent_favorite_tracks"
        case topTracksByRange = "top_tracks_by_range"
        case topArtistsByRange = "top_artists_by_range"
        case mood
        case moodProfile = "mood_profile"
        case energyProfile = "energy_profile"
        case playtime
        case listeningRhythm = "listening_rhythm"
        case moodMix = "mood_mix"
        case repeatMagnets = "repeat_magnets"
        case explicitPositives = "explicit_positives"
        case tasteAnchors = "taste_anchors"
        case tasteDirection = "taste_direction"
        case basedOn = "based_on"
        case items
        case timePatterns = "time_patterns"
        case recommendationSignals = "recommendation_signals"
        case blockedArtists = "blocked_artists"
        case blockedItems = "blocked_items"
        case snapshotHistory = "snapshot_history"
        case discoveryFeedback = "discovery_feedback"
        case privacyDashboard = "privacy_dashboard"
        case lastProfileRefresh = "last_profile_refresh"
        case consentUpdatedAt = "consent_updated_at"
        case updatedAt = "updated_at"
    }

    public init(
        summary: String? = nil,
        trackCount: Int? = nil,
        artistCount: Int? = nil,
        genreCount: Int? = nil,
        favoriteGenres: [DJConnectMusicDNANameValue]? = nil,
        favoriteArtists: [DJConnectMusicDNANameValue]? = nil,
        recentTracks: [DJConnectMusicDNATrack]? = nil,
        recentFavoriteTracks: [DJConnectMusicDNATrack]? = nil,
        topTracksByRange: [String: [DJConnectMusicDNATrack]] = [:],
        topArtistsByRange: [String: [DJConnectMusicDNANameValue]] = [:],
        mood: DJConnectMusicDNAMood? = nil,
        energyProfile: DJConnectMusicDNAEnergyProfile? = nil,
        playtime: DJConnectMusicDNAPlaytime? = nil,
        listeningRhythm: DJConnectMusicDNAListeningRhythm? = nil,
        moodMix: DJConnectMusicDNAMoodMix? = nil,
        repeatMagnets: DJConnectMusicDNARepeatMagnets? = nil,
        explicitPositives: DJConnectMusicDNAExplicitPositives? = nil,
        tasteAnchors: DJConnectMusicDNATasteAnchors? = nil,
        tasteDirection: String? = nil,
        basedOn: [DJConnectMusicDNASignal]? = nil,
        timePatterns: [DJConnectMusicDNASignal]? = nil,
        recommendationSignals: [DJConnectMusicDNASignal]? = nil,
        blockedArtists: [DJConnectMusicDNANameValue]? = nil,
        blockedItems: [DJConnectMusicDNASignal]? = nil,
        snapshotHistory: [DJConnectMusicDNASnapshot] = [],
        discoveryFeedback: DJConnectMusicDNADiscoveryFeedback? = nil,
        privacyDashboard: DJConnectMusicDNAPrivacyDashboard? = nil,
        lastProfileRefresh: Date? = nil,
        consentUpdatedAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.summary = summary
        self.trackCount = trackCount.map { max(0, $0) }
        self.artistCount = artistCount.map { max(0, $0) }
        self.genreCount = genreCount.map { max(0, $0) }
        self.favoriteGenres = favoriteGenres
        self.favoriteArtists = favoriteArtists
        self.recentTracks = recentTracks
        self.recentFavoriteTracks = recentFavoriteTracks
        self.topTracksByRange = topTracksByRange
        self.topArtistsByRange = topArtistsByRange
        self.mood = mood
        self.energyProfile = energyProfile
        self.playtime = playtime
        self.listeningRhythm = listeningRhythm
        self.moodMix = moodMix
        self.repeatMagnets = repeatMagnets
        self.explicitPositives = explicitPositives
        self.tasteAnchors = tasteAnchors
        self.tasteDirection = tasteDirection
        self.basedOn = basedOn
        self.timePatterns = timePatterns
        self.recommendationSignals = recommendationSignals
        self.blockedArtists = blockedArtists
        self.blockedItems = blockedItems
        self.snapshotHistory = snapshotHistory
        self.discoveryFeedback = discoveryFeedback
        self.privacyDashboard = privacyDashboard
        self.lastProfileRefresh = lastProfileRefresh
        self.consentUpdatedAt = consentUpdatedAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        trackCount = try container.decodeIfPresent(Int.self, forKey: .trackCount).map { max(0, $0) }
        artistCount = try container.decodeIfPresent(Int.self, forKey: .artistCount).map { max(0, $0) }
        genreCount = try container.decodeIfPresent(Int.self, forKey: .genreCount).map { max(0, $0) }
        favoriteGenres = container.decodeLossyArrayIfPresent(DJConnectMusicDNANameValue.self, forKey: .favoriteGenres)
        favoriteArtists = container.decodeLossyArrayIfPresent(DJConnectMusicDNANameValue.self, forKey: .favoriteArtists)
        recentTracks = container.decodeLossyArrayIfPresent(DJConnectMusicDNATrack.self, forKey: .recentTracks)
        recentFavoriteTracks = container.decodeLossyArrayIfPresent(DJConnectMusicDNATrack.self, forKey: .recentFavoriteTracks)
        topTracksByRange = try container.decodeIfPresent([String: [DJConnectMusicDNATrack]].self, forKey: .topTracksByRange) ?? [:]
        topArtistsByRange = try container.decodeIfPresent([String: [DJConnectMusicDNANameValue]].self, forKey: .topArtistsByRange) ?? [:]
        mood = try container.decodeIfPresent(DJConnectMusicDNAMood.self, forKey: .mood)
            ?? container.decodeIfPresentIgnoringErrors(DJConnectMusicDNAMood.self, forKey: .moodProfile)
        energyProfile = try container.decodeIfPresent(DJConnectMusicDNAEnergyProfile.self, forKey: .energyProfile)
        playtime = try container.decodeIfPresent(DJConnectMusicDNAPlaytime.self, forKey: .playtime)
        listeningRhythm = try container.decodeIfPresent(DJConnectMusicDNAListeningRhythm.self, forKey: .listeningRhythm)
        moodMix = try container.decodeIfPresent(DJConnectMusicDNAMoodMix.self, forKey: .moodMix)
        repeatMagnets = try container.decodeIfPresent(DJConnectMusicDNARepeatMagnets.self, forKey: .repeatMagnets)
        explicitPositives = try container.decodeIfPresent(DJConnectMusicDNAExplicitPositives.self, forKey: .explicitPositives)
        tasteAnchors = try container.decodeIfPresent(DJConnectMusicDNATasteAnchors.self, forKey: .tasteAnchors)
        tasteDirection = try container.decodeIfPresent(String.self, forKey: .tasteDirection)
        basedOn = container.decodeLossyArrayIfPresent(DJConnectMusicDNASignal.self, forKey: .basedOn)
            ?? container.decodeLossyArrayIfPresent(DJConnectMusicDNASignal.self, forKey: .items)
        timePatterns = container.decodeLossyArrayIfPresent(DJConnectMusicDNASignal.self, forKey: .timePatterns)
        recommendationSignals = container.decodeLossyArrayIfPresent(DJConnectMusicDNASignal.self, forKey: .recommendationSignals)
        blockedArtists = container.decodeLossyArrayIfPresent(DJConnectMusicDNANameValue.self, forKey: .blockedArtists)
        blockedItems = container.decodeLossyArrayIfPresent(DJConnectMusicDNASignal.self, forKey: .blockedItems)
        snapshotHistory = container.decodeLossyArrayIfPresent(DJConnectMusicDNASnapshot.self, forKey: .snapshotHistory) ?? []
        discoveryFeedback = try container.decodeIfPresent(DJConnectMusicDNADiscoveryFeedback.self, forKey: .discoveryFeedback)
        privacyDashboard = try container.decodeIfPresent(DJConnectMusicDNAPrivacyDashboard.self, forKey: .privacyDashboard)
        lastProfileRefresh = DJConnectAskDJHistoryResponse.decodeDate(container, key: .lastProfileRefresh)
        consentUpdatedAt = DJConnectAskDJHistoryResponse.decodeDate(container, key: .consentUpdatedAt)
        updatedAt = DJConnectAskDJHistoryResponse.decodeDate(container, key: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(trackCount, forKey: .trackCount)
        try container.encodeIfPresent(artistCount, forKey: .artistCount)
        try container.encodeIfPresent(genreCount, forKey: .genreCount)
        try container.encodeIfPresent(favoriteGenres, forKey: .favoriteGenres)
        try container.encodeIfPresent(favoriteArtists, forKey: .favoriteArtists)
        try container.encodeIfPresent(recentTracks, forKey: .recentTracks)
        try container.encodeIfPresent(recentFavoriteTracks, forKey: .recentFavoriteTracks)
        try container.encode(topTracksByRange, forKey: .topTracksByRange)
        try container.encode(topArtistsByRange, forKey: .topArtistsByRange)
        try container.encodeIfPresent(mood, forKey: .mood)
        try container.encodeIfPresent(energyProfile, forKey: .energyProfile)
        try container.encodeIfPresent(playtime, forKey: .playtime)
        try container.encodeIfPresent(listeningRhythm, forKey: .listeningRhythm)
        try container.encodeIfPresent(moodMix, forKey: .moodMix)
        try container.encodeIfPresent(repeatMagnets, forKey: .repeatMagnets)
        try container.encodeIfPresent(explicitPositives, forKey: .explicitPositives)
        try container.encodeIfPresent(tasteAnchors, forKey: .tasteAnchors)
        try container.encodeIfPresent(tasteDirection, forKey: .tasteDirection)
        try container.encodeIfPresent(basedOn, forKey: .basedOn)
        try container.encodeIfPresent(timePatterns, forKey: .timePatterns)
        try container.encodeIfPresent(recommendationSignals, forKey: .recommendationSignals)
        try container.encodeIfPresent(blockedArtists, forKey: .blockedArtists)
        try container.encodeIfPresent(blockedItems, forKey: .blockedItems)
        try container.encode(snapshotHistory, forKey: .snapshotHistory)
        try container.encodeIfPresent(discoveryFeedback, forKey: .discoveryFeedback)
        try container.encodeIfPresent(privacyDashboard, forKey: .privacyDashboard)
        try container.encodeIfPresent(lastProfileRefresh, forKey: .lastProfileRefresh)
        try container.encodeIfPresent(consentUpdatedAt, forKey: .consentUpdatedAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }

    public var isEmpty: Bool {
        let trimmedSummary = summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedSummary.isEmpty
            && (favoriteGenres?.isEmpty ?? true)
            && (favoriteArtists?.isEmpty ?? true)
            && (recentTracks?.isEmpty ?? true)
            && (recentFavoriteTracks?.isEmpty ?? true)
            && topTracksByRange.values.allSatisfy(\.isEmpty)
            && topArtistsByRange.values.allSatisfy(\.isEmpty)
            && mood == nil
            && energyProfile == nil
            && playtime?.isDisplayable != true
            && listeningRhythm?.isDisplayable != true
            && moodMix?.isDisplayable != true
            && repeatMagnets?.isDisplayable != true
            && explicitPositives?.isDisplayable != true
            && tasteAnchors?.isDisplayable != true
            && (tasteDirection?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            && (basedOn?.isEmpty ?? true)
            && ((timePatterns?.count ?? 0) < 3)
            && (recommendationSignals?.isEmpty ?? true)
            && snapshotHistory.isEmpty
            && discoveryFeedback?.isDisplayable != true
            && privacyDashboard?.isDisplayable != true
    }
}

public struct DJConnectMusicDNASnapshot: Codable, Equatable, Sendable, Identifiable {
    public var id: String { [capturedAt?.ISO8601Format(), source, summary].compactMap { $0 }.joined(separator: "|") }
    public var capturedAt: Date?
    public var source: String?
    public var summary: String?
    public var trackCount: Int?
    public var artistCount: Int?
    public var genreCount: Int?
    public var topGenres: [DJConnectMusicDNANameValue]
    public var topArtists: [DJConnectMusicDNANameValue]
    public var topTracks: [DJConnectMusicDNATrack]

    enum CodingKeys: String, CodingKey {
        case capturedAt = "captured_at"
        case createdAt = "created_at"
        case source
        case summary
        case trackCount = "track_count"
        case artistCount = "artist_count"
        case genreCount = "genre_count"
        case topGenres = "top_genres"
        case topArtists = "top_artists"
        case topTracks = "top_tracks"
    }

    public init(
        capturedAt: Date? = nil,
        source: String? = nil,
        summary: String? = nil,
        trackCount: Int? = nil,
        artistCount: Int? = nil,
        genreCount: Int? = nil,
        topGenres: [DJConnectMusicDNANameValue] = [],
        topArtists: [DJConnectMusicDNANameValue] = [],
        topTracks: [DJConnectMusicDNATrack] = []
    ) {
        self.capturedAt = capturedAt
        self.source = source?.nilIfBlank
        self.summary = summary?.nilIfBlank
        self.trackCount = trackCount.map { max(0, $0) }
        self.artistCount = artistCount.map { max(0, $0) }
        self.genreCount = genreCount.map { max(0, $0) }
        self.topGenres = topGenres
        self.topArtists = topArtists
        self.topTracks = topTracks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            capturedAt: DJConnectAskDJHistoryResponse.decodeDate(container, key: .capturedAt)
                ?? DJConnectAskDJHistoryResponse.decodeDate(container, key: .createdAt),
            source: try container.decodeIfPresent(String.self, forKey: .source),
            summary: try container.decodeIfPresent(String.self, forKey: .summary),
            trackCount: try container.decodeIfPresent(Int.self, forKey: .trackCount),
            artistCount: try container.decodeIfPresent(Int.self, forKey: .artistCount),
            genreCount: try container.decodeIfPresent(Int.self, forKey: .genreCount),
            topGenres: container.decodeLossyArrayIfPresent(DJConnectMusicDNANameValue.self, forKey: .topGenres) ?? [],
            topArtists: container.decodeLossyArrayIfPresent(DJConnectMusicDNANameValue.self, forKey: .topArtists) ?? [],
            topTracks: container.decodeLossyArrayIfPresent(DJConnectMusicDNATrack.self, forKey: .topTracks) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(capturedAt, forKey: .capturedAt)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(trackCount, forKey: .trackCount)
        try container.encodeIfPresent(artistCount, forKey: .artistCount)
        try container.encodeIfPresent(genreCount, forKey: .genreCount)
        try container.encode(topGenres, forKey: .topGenres)
        try container.encode(topArtists, forKey: .topArtists)
        try container.encode(topTracks, forKey: .topTracks)
    }
}

public struct DJConnectMusicDNADiscoveryFeedback: Codable, Equatable, Sendable {
    public var acceptedRecommendations: [DJConnectMusicDNAAcceptedRecommendationSignal]
    public var negativeSignals: [DJConnectMusicDNASignal]
    public var hiddenArtists: [DJConnectMusicDNANameValue]
    public var counts: [String: Int]
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case acceptedRecommendations = "accepted_recommendations"
        case acceptedItems = "accepted_items"
        case negativeSignals = "negative_signals"
        case hiddenArtists = "hidden_artists"
        case blockedArtists = "blocked_artists"
        case counts
        case updatedAt = "updated_at"
    }

    public init(
        acceptedRecommendations: [DJConnectMusicDNAAcceptedRecommendationSignal] = [],
        negativeSignals: [DJConnectMusicDNASignal] = [],
        hiddenArtists: [DJConnectMusicDNANameValue] = [],
        counts: [String: Int] = [:],
        updatedAt: Date? = nil
    ) {
        self.acceptedRecommendations = acceptedRecommendations
        self.negativeSignals = negativeSignals
        self.hiddenArtists = hiddenArtists
        self.counts = counts
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            acceptedRecommendations: container.decodeLossyArrayIfPresent(DJConnectMusicDNAAcceptedRecommendationSignal.self, forKey: .acceptedRecommendations)
                ?? container.decodeLossyArrayIfPresent(DJConnectMusicDNAAcceptedRecommendationSignal.self, forKey: .acceptedItems)
                ?? [],
            negativeSignals: container.decodeLossyArrayIfPresent(DJConnectMusicDNASignal.self, forKey: .negativeSignals) ?? [],
            hiddenArtists: container.decodeLossyArrayIfPresent(DJConnectMusicDNANameValue.self, forKey: .hiddenArtists)
                ?? container.decodeLossyArrayIfPresent(DJConnectMusicDNANameValue.self, forKey: .blockedArtists)
                ?? [],
            counts: try container.decodeIfPresent([String: Int].self, forKey: .counts) ?? [:],
            updatedAt: DJConnectAskDJHistoryResponse.decodeDate(container, key: .updatedAt)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(acceptedRecommendations, forKey: .acceptedRecommendations)
        try container.encode(negativeSignals, forKey: .negativeSignals)
        try container.encode(hiddenArtists, forKey: .hiddenArtists)
        try container.encode(counts, forKey: .counts)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }

    public var isDisplayable: Bool {
        !acceptedRecommendations.isEmpty || !negativeSignals.isEmpty || !hiddenArtists.isEmpty || !counts.isEmpty
    }
}

public struct DJConnectMusicDNAPrivacyDashboard: Codable, Equatable, Sendable {
    public var enabled: Bool?
    public var activeDataSources: [String]
    public var controls: [String: Bool]
    public var rawCounts: [String: Int]
    public var retentionLimits: [String: DJConnectMusicDNAValue]
    public var supportsClear: Bool?
    public var supportsExport: Bool?
    public var supportsImport: Bool?
    public var storesRawAudio: Bool?
    public var storesOAuthTokens: Bool?
    public var storesFullPrompts: Bool?
    public var flags: [String: Bool]

    enum CodingKeys: String, CodingKey {
        case enabled
        case activeDataSources = "active_data_sources"
        case dataSources = "data_sources"
        case controls
        case rawCounts = "raw_counts"
        case retentionLimits = "retention_limits"
        case supportsClear = "supports_clear"
        case supportsExport = "supports_export"
        case supportsImport = "supports_import"
        case storesRawAudio = "stores_raw_audio"
        case storesOAuthTokens = "stores_oauth_tokens"
        case storesFullPrompts = "stores_full_prompts"
        case flags
    }

    public init(
        enabled: Bool? = nil,
        activeDataSources: [String] = [],
        controls: [String: Bool] = [:],
        rawCounts: [String: Int] = [:],
        retentionLimits: [String: DJConnectMusicDNAValue] = [:],
        supportsClear: Bool? = nil,
        supportsExport: Bool? = nil,
        supportsImport: Bool? = nil,
        storesRawAudio: Bool? = nil,
        storesOAuthTokens: Bool? = nil,
        storesFullPrompts: Bool? = nil,
        flags: [String: Bool] = [:]
    ) {
        self.enabled = enabled
        self.activeDataSources = activeDataSources
        self.controls = controls
        self.rawCounts = rawCounts
        self.retentionLimits = retentionLimits
        self.supportsClear = supportsClear
        self.supportsExport = supportsExport
        self.supportsImport = supportsImport
        self.storesRawAudio = storesRawAudio
        self.storesOAuthTokens = storesOAuthTokens
        self.storesFullPrompts = storesFullPrompts
        self.flags = flags
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            enabled: try container.decodeIfPresent(Bool.self, forKey: .enabled),
            activeDataSources: (try? container.decodeIfPresent([String].self, forKey: .activeDataSources))
                ?? (try? container.decodeIfPresent([String].self, forKey: .dataSources))
                ?? (container.decodeLossyArrayIfPresent(DJConnectMusicDNADataSource.self, forKey: .dataSources)?.map(\.displayName))
                ?? [],
            controls: try container.decodeIfPresent([String: Bool].self, forKey: .controls) ?? [:],
            rawCounts: try container.decodeIfPresent([String: Int].self, forKey: .rawCounts) ?? [:],
            retentionLimits: try container.decodeIfPresent([String: DJConnectMusicDNAValue].self, forKey: .retentionLimits) ?? [:],
            supportsClear: try container.decodeIfPresent(Bool.self, forKey: .supportsClear),
            supportsExport: try container.decodeIfPresent(Bool.self, forKey: .supportsExport),
            supportsImport: try container.decodeIfPresent(Bool.self, forKey: .supportsImport),
            storesRawAudio: try container.decodeIfPresent(Bool.self, forKey: .storesRawAudio),
            storesOAuthTokens: try container.decodeIfPresent(Bool.self, forKey: .storesOAuthTokens),
            storesFullPrompts: try container.decodeIfPresent(Bool.self, forKey: .storesFullPrompts),
            flags: try container.decodeIfPresent([String: Bool].self, forKey: .flags) ?? [:]
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(enabled, forKey: .enabled)
        try container.encode(activeDataSources, forKey: .activeDataSources)
        try container.encode(controls, forKey: .controls)
        try container.encode(rawCounts, forKey: .rawCounts)
        try container.encode(retentionLimits, forKey: .retentionLimits)
        try container.encodeIfPresent(supportsClear, forKey: .supportsClear)
        try container.encodeIfPresent(supportsExport, forKey: .supportsExport)
        try container.encodeIfPresent(supportsImport, forKey: .supportsImport)
        try container.encodeIfPresent(storesRawAudio, forKey: .storesRawAudio)
        try container.encodeIfPresent(storesOAuthTokens, forKey: .storesOAuthTokens)
        try container.encodeIfPresent(storesFullPrompts, forKey: .storesFullPrompts)
        try container.encode(flags, forKey: .flags)
    }

    public var isDisplayable: Bool {
        enabled != nil || !activeDataSources.isEmpty || !controls.isEmpty || !rawCounts.isEmpty || !retentionLimits.isEmpty || supportsClear != nil || supportsExport != nil || supportsImport != nil || storesRawAudio != nil || storesOAuthTokens != nil || storesFullPrompts != nil || !flags.isEmpty
    }
}

private struct DJConnectMusicDNADataSource: Codable, Equatable, Sendable {
    var id: String?
    var label: String?
    var enabled: Bool?

    var displayName: String {
        let name = label?.nilIfBlank ?? id?.nilIfBlank ?? "unknown"
        guard let enabled else { return name }
        return enabled ? name : "\(name) (disabled)"
    }
}

public struct DJConnectMusicDNAValue: Codable, Equatable, Sendable, CustomStringConvertible {
    public var description: String

    public init(_ description: String) {
        self.description = description
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            description = value
        } else if let value = try? container.decode(Int.self) {
            description = "\(value)"
        } else if let value = try? container.decode(Double.self) {
            description = "\(value)"
        } else if let value = try? container.decode(Bool.self) {
            description = value ? "true" : "false"
        } else {
            description = ""
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

public struct DJConnectMusicDNAPlaytime: Codable, Equatable, Sendable {
    public var totalSeconds: Int
    public var totalHours: Double?
    public var formattedTotal: String?
    public var topArtists: [DJConnectMusicDNAPlaytimeArtist]
    public var topAlbums: [DJConnectMusicDNAPlaytimeArtist]

    public init(
        totalSeconds: Int = 0,
        totalHours: Double? = nil,
        formattedTotal: String? = nil,
        topArtists: [DJConnectMusicDNAPlaytimeArtist] = [],
        topAlbums: [DJConnectMusicDNAPlaytimeArtist] = []
    ) {
        self.totalSeconds = totalSeconds
        self.totalHours = totalHours
        self.formattedTotal = formattedTotal
        self.topArtists = topArtists
        self.topAlbums = topAlbums
    }

    enum CodingKeys: String, CodingKey {
        case totalSeconds = "total_seconds"
        case totalHours = "total_hours"
        case formattedTotal = "formatted_total"
        case topArtists = "top_artists"
        case topAlbums = "top_albums"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            totalSeconds: try container.decodeIfPresent(Int.self, forKey: .totalSeconds) ?? 0,
            totalHours: try container.decodeIfPresent(Double.self, forKey: .totalHours),
            formattedTotal: try container.decodeIfPresent(String.self, forKey: .formattedTotal),
            topArtists: container.decodeLossyArrayIfPresent(DJConnectMusicDNAPlaytimeArtist.self, forKey: .topArtists) ?? [],
            topAlbums: container.decodeLossyArrayIfPresent(DJConnectMusicDNAPlaytimeArtist.self, forKey: .topAlbums) ?? []
        )
    }

    public var isDisplayable: Bool {
        totalSeconds > 0
    }

    public var visibleTopArtists: [DJConnectMusicDNAPlaytimeArtist] {
        Array(topArtists.prefix(3))
    }

    public var visibleTopAlbums: [DJConnectMusicDNAPlaytimeArtist] {
        Array(topAlbums.prefix(3))
    }
}

public struct DJConnectMusicDNAPlaytimeArtist: Codable, Equatable, Sendable, Identifiable {
    public var id: String { name }
    public var name: String
    public var seconds: Int?
    public var hours: Double?
    public var formatted: String?

    public init(name: String, seconds: Int? = nil, hours: Double? = nil, formatted: String? = nil) {
        self.name = name
        self.seconds = seconds
        self.hours = hours
        self.formatted = formatted
    }
}

public struct DJConnectMusicDNAListeningRhythm: Codable, Equatable, Sendable {
    public var sampleCount: Int
    public var topDaypart: String?
    public var topWeekday: String?
    public var dayparts: [DJConnectMusicDNAListeningRhythmItem]
    public var weekdays: [DJConnectMusicDNAListeningRhythmItem]

    public init(
        sampleCount: Int = 0,
        topDaypart: String? = nil,
        topWeekday: String? = nil,
        dayparts: [DJConnectMusicDNAListeningRhythmItem] = [],
        weekdays: [DJConnectMusicDNAListeningRhythmItem] = []
    ) {
        self.sampleCount = max(0, sampleCount)
        self.topDaypart = topDaypart
        self.topWeekday = topWeekday
        self.dayparts = dayparts
        self.weekdays = weekdays
    }

    enum CodingKeys: String, CodingKey {
        case sampleCount = "sample_count"
        case topDaypart = "top_daypart"
        case topWeekday = "top_weekday"
        case dayparts
        case weekdays
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sampleCount: try container.decodeIfPresent(Int.self, forKey: .sampleCount) ?? 0,
            topDaypart: try container.decodeIfPresent(String.self, forKey: .topDaypart),
            topWeekday: try container.decodeIfPresent(String.self, forKey: .topWeekday),
            dayparts: container.decodeLossyArrayIfPresent(DJConnectMusicDNAListeningRhythmItem.self, forKey: .dayparts) ?? [],
            weekdays: container.decodeLossyArrayIfPresent(DJConnectMusicDNAListeningRhythmItem.self, forKey: .weekdays) ?? []
        )
    }

    public var isDisplayable: Bool {
        sampleCount >= 3 && (!dayparts.isEmpty || !weekdays.isEmpty)
    }

    public var visibleWeekdays: [DJConnectMusicDNAListeningRhythmItem] {
        Array(weekdays.prefix(5))
    }
}

public struct DJConnectMusicDNAListeningRhythmItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String { daypart ?? weekday ?? "" }
    public var daypart: String?
    public var weekday: String?
    public var count: Int?
    public var percent: Double?

    public init(daypart: String? = nil, weekday: String? = nil, count: Int? = nil, percent: Double? = nil) {
        self.daypart = daypart
        self.weekday = weekday
        self.count = count
        self.percent = percent
    }
}

public struct DJConnectMusicDNAMoodMix: Codable, Equatable, Sendable {
    public var sampleCount: Int
    public var average: Int?
    public var topZone: String?
    public var zones: [DJConnectMusicDNAMoodMixZone]

    public init(sampleCount: Int = 0, average: Int? = nil, topZone: String? = nil, zones: [DJConnectMusicDNAMoodMixZone] = []) {
        self.sampleCount = max(0, sampleCount)
        self.average = average
        self.topZone = topZone
        self.zones = zones
    }

    enum CodingKeys: String, CodingKey {
        case sampleCount = "sample_count"
        case average
        case topZone = "top_zone"
        case zones
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sampleCount: try container.decodeIfPresent(Int.self, forKey: .sampleCount) ?? 0,
            average: try container.decodeIfPresent(Int.self, forKey: .average),
            topZone: try container.decodeIfPresent(String.self, forKey: .topZone),
            zones: container.decodeLossyArrayIfPresent(DJConnectMusicDNAMoodMixZone.self, forKey: .zones) ?? []
        )
    }

    public var isDisplayable: Bool {
        sampleCount > 0 && !zones.isEmpty
    }
}

public struct DJConnectMusicDNAMoodMixZone: Codable, Equatable, Sendable, Identifiable {
    public var id: String { zone }
    public var zone: String
    public var count: Int?
    public var percent: Double?

    public init(zone: String, count: Int? = nil, percent: Double? = nil) {
        self.zone = zone
        self.count = count
        self.percent = percent
    }
}

public struct DJConnectMusicDNARepeatMagnets: Codable, Equatable, Sendable {
    public var eligible: Bool
    public var reason: String?
    public var items: [DJConnectMusicDNARepeatMagnetItem]

    public init(eligible: Bool = false, reason: String? = nil, items: [DJConnectMusicDNARepeatMagnetItem] = []) {
        self.eligible = eligible
        self.reason = reason
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            eligible: try container.decodeIfPresent(Bool.self, forKey: .eligible) ?? false,
            reason: try container.decodeIfPresent(String.self, forKey: .reason),
            items: container.decodeLossyArrayIfPresent(DJConnectMusicDNARepeatMagnetItem.self, forKey: .items) ?? []
        )
    }

    public var isDisplayable: Bool {
        eligible && !items.isEmpty
    }

    public var visibleItems: [DJConnectMusicDNARepeatMagnetItem] {
        Array(items.prefix(3))
    }
}

public struct DJConnectMusicDNARepeatMagnetItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String { [kind, name].joined(separator: "|") }
    public var kind: String
    public var name: String
    public var count: Int?
    public var seconds: Int?
    public var formatted: String?

    public init(kind: String, name: String, count: Int? = nil, seconds: Int? = nil, formatted: String? = nil) {
        self.kind = kind
        self.name = name
        self.count = count
        self.seconds = seconds
        self.formatted = formatted
    }
}

public struct DJConnectMusicDNAExplicitPositives: Codable, Equatable, Sendable {
    public var eligible: Bool
    public var reason: String?
    public var signalCount: Int?
    public var favoriteTracks: [DJConnectMusicDNAFavoriteTrackSignal]
    public var acceptedRecommendations: [DJConnectMusicDNAAcceptedRecommendationSignal]

    public init(
        eligible: Bool = false,
        reason: String? = nil,
        signalCount: Int? = nil,
        favoriteTracks: [DJConnectMusicDNAFavoriteTrackSignal] = [],
        acceptedRecommendations: [DJConnectMusicDNAAcceptedRecommendationSignal] = []
    ) {
        self.eligible = eligible
        self.reason = reason
        self.signalCount = signalCount.map { max(0, $0) }
        self.favoriteTracks = favoriteTracks
        self.acceptedRecommendations = acceptedRecommendations
    }

    enum CodingKeys: String, CodingKey {
        case eligible
        case reason
        case signalCount = "signal_count"
        case favoriteTracks = "favorite_tracks"
        case acceptedRecommendations = "accepted_recommendations"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            eligible: try container.decodeIfPresent(Bool.self, forKey: .eligible) ?? false,
            reason: try container.decodeIfPresent(String.self, forKey: .reason),
            signalCount: try container.decodeIfPresent(Int.self, forKey: .signalCount),
            favoriteTracks: container.decodeLossyArrayIfPresent(DJConnectMusicDNAFavoriteTrackSignal.self, forKey: .favoriteTracks) ?? [],
            acceptedRecommendations: container.decodeLossyArrayIfPresent(DJConnectMusicDNAAcceptedRecommendationSignal.self, forKey: .acceptedRecommendations) ?? []
        )
    }

    public var isDisplayable: Bool {
        eligible && (!favoriteTracks.isEmpty || !acceptedRecommendations.isEmpty)
    }

    public var visibleFavoriteTracks: [DJConnectMusicDNAFavoriteTrackSignal] {
        Array(favoriteTracks.prefix(3))
    }

    public var visibleAcceptedRecommendations: [DJConnectMusicDNAAcceptedRecommendationSignal] {
        Array(acceptedRecommendations.prefix(3))
    }
}

public struct DJConnectMusicDNAFavoriteTrackSignal: Codable, Equatable, Sendable, Identifiable {
    public var id: String { uri ?? [kind, title, artist].compactMap { $0 }.joined(separator: "|") }
    public var kind: String
    public var title: String
    public var artist: String?
    public var uri: String?

    public init(kind: String = "favorite_track", title: String, artist: String? = nil, uri: String? = nil) {
        self.kind = kind
        self.title = title
        self.artist = artist
        self.uri = uri
    }
}

public struct DJConnectMusicDNAAcceptedRecommendationSignal: Codable, Equatable, Sendable, Identifiable {
    public var id: String { uri ?? [kind, title, subtitle, reason].compactMap { $0 }.joined(separator: "|") }
    public var kind: String
    public var title: String?
    public var subtitle: String?
    public var uri: String?
    public var reason: String?

    public init(
        kind: String = "accepted_recommendation",
        title: String? = nil,
        subtitle: String? = nil,
        uri: String? = nil,
        reason: String? = nil
    ) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.uri = uri
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case title
        case subtitle
        case uri
        case reason
    }

    public init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(title: value)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            kind: try container.decodeIfPresent(String.self, forKey: .kind) ?? "accepted_recommendation",
            title: try container.decodeIfPresent(String.self, forKey: .title),
            subtitle: try container.decodeIfPresent(String.self, forKey: .subtitle),
            uri: try container.decodeIfPresent(String.self, forKey: .uri),
            reason: try container.decodeIfPresent(String.self, forKey: .reason)
        )
    }
}

public struct DJConnectMusicDNATasteAnchors: Codable, Equatable, Sendable {
    public var eligible: Bool
    public var reason: String?
    public var items: [DJConnectMusicDNATasteAnchorItem]

    public init(eligible: Bool = false, reason: String? = nil, items: [DJConnectMusicDNATasteAnchorItem] = []) {
        self.eligible = eligible
        self.reason = reason
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            eligible: try container.decodeIfPresent(Bool.self, forKey: .eligible) ?? false,
            reason: try container.decodeIfPresent(String.self, forKey: .reason),
            items: container.decodeLossyArrayIfPresent(DJConnectMusicDNATasteAnchorItem.self, forKey: .items) ?? []
        )
    }

    public var isDisplayable: Bool {
        eligible && !items.isEmpty
    }

    public var visibleItems: [DJConnectMusicDNATasteAnchorItem] {
        Array(items.prefix(5))
    }
}

public struct DJConnectMusicDNATasteAnchorItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String { [kind, name].joined(separator: "|") }
    public var kind: String
    public var name: String
    public var playCount: Int?
    public var seconds: Int?
    public var formatted: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case name
        case playCount = "play_count"
        case seconds
        case formatted
    }

    public init(kind: String, name: String, playCount: Int? = nil, seconds: Int? = nil, formatted: String? = nil) {
        self.kind = kind
        self.name = name
        self.playCount = playCount
        self.seconds = seconds
        self.formatted = formatted
    }
}

public struct DJConnectMusicDNANameValue: Codable, Equatable, Sendable, Identifiable {
    public var id: String { name }
    public var name: String
    public var value: Double?
    public var count: Int?

    public init(name: String, value: Double? = nil, count: Int? = nil) {
        self.name = name
        self.value = value
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case name
        case title
        case value
        case score
        case count
    }

    public init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(name: value)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? ""
        self.init(
            name: name,
            value: try container.decodeIfPresent(Double.self, forKey: .value)
                ?? container.decodeIfPresent(Double.self, forKey: .score),
            count: try container.decodeIfPresent(Int.self, forKey: .count)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(count, forKey: .count)
    }
}

public struct DJConnectMusicDNATrack: Codable, Equatable, Sendable, Identifiable {
    public var id: String { uri ?? [title, artist, album, createdAt?.ISO8601Format()].compactMap { $0 }.joined(separator: "|") }
    public var title: String?
    public var artist: String?
    public var album: String?
    public var uri: String?
    public var imageURL: String?
    public var createdAt: Date?
    public var genres: [String]

    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        uri: String? = nil,
        imageURL: String? = nil,
        createdAt: Date? = nil,
        genres: [String] = []
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.uri = uri
        self.imageURL = imageURL
        self.createdAt = createdAt
        self.genres = genres
    }

    enum CodingKeys: String, CodingKey {
        case title
        case trackName = "track_name"
        case name
        case artist
        case artistName = "artist_name"
        case album
        case albumName = "album_name"
        case uri
        case imageURL = "image_url"
        case albumImageURL = "album_image_url"
        case createdAt = "created_at"
        case genres
    }

    public init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(title: value)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            title: try container.decodeIfPresent(String.self, forKey: .title)
                ?? container.decodeIfPresent(String.self, forKey: .trackName)
                ?? container.decodeIfPresent(String.self, forKey: .name),
            artist: try container.decodeIfPresent(String.self, forKey: .artist)
                ?? container.decodeIfPresent(String.self, forKey: .artistName),
            album: try container.decodeIfPresent(String.self, forKey: .album)
                ?? container.decodeIfPresent(String.self, forKey: .albumName),
            uri: try container.decodeIfPresent(String.self, forKey: .uri),
            imageURL: try container.decodeIfPresent(String.self, forKey: .imageURL)
                ?? container.decodeIfPresent(String.self, forKey: .albumImageURL),
            createdAt: DJConnectAskDJHistoryResponse.decodeDate(container, key: .createdAt),
            genres: try container.decodeIfPresent([String].self, forKey: .genres) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(artist, forKey: .artist)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encodeIfPresent(uri, forKey: .uri)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        if !genres.isEmpty {
            try container.encode(genres, forKey: .genres)
        }
    }
}

public struct DJConnectMusicDNAMood: Codable, Equatable, Sendable {
    public var value: Int?
    public var zone: String?
    public var promptHint: String?
    public var sampleCount: Int?
    public var average: Int?
    public var averageZone: String?
    public var averagePromptHint: String?
    public var zoneCounts: [String: Int]

    enum CodingKeys: String, CodingKey {
        case value
        case zone
        case promptHint = "prompt_hint"
        case sampleCount = "sample_count"
        case average
        case averageZone = "average_zone"
        case averagePromptHint = "average_prompt_hint"
        case zoneCounts = "zone_counts"
    }

    public init(
        value: Int? = nil,
        zone: String? = nil,
        promptHint: String? = nil,
        sampleCount: Int? = nil,
        average: Int? = nil,
        averageZone: String? = nil,
        averagePromptHint: String? = nil,
        zoneCounts: [String: Int] = [:]
    ) {
        self.value = value.map { max(0, min(100, $0)) }
        self.zone = zone
        self.promptHint = promptHint
        self.sampleCount = sampleCount.map { max(0, $0) }
        self.average = average.map { max(0, min(100, $0)) }
        self.averageZone = averageZone
        self.averagePromptHint = averagePromptHint
        self.zoneCounts = zoneCounts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            value: try container.decodeIfPresent(Int.self, forKey: .value),
            zone: try container.decodeIfPresent(String.self, forKey: .zone),
            promptHint: try container.decodeIfPresent(String.self, forKey: .promptHint),
            sampleCount: try container.decodeIfPresent(Int.self, forKey: .sampleCount),
            average: try container.decodeIfPresent(Int.self, forKey: .average),
            averageZone: try container.decodeIfPresent(String.self, forKey: .averageZone),
            averagePromptHint: try container.decodeIfPresent(String.self, forKey: .averagePromptHint),
            zoneCounts: try container.decodeIfPresent([String: Int].self, forKey: .zoneCounts) ?? [:]
        )
    }
}

public struct DJConnectMusicDNAEnergyProfile: Codable, Equatable, Sendable {
    public var sampleCount: Int?
    public var energy: Double?
    public var energyPercent: Int?
    public var zone: String?
    public var promptHint: String?
    public var danceability: Double?
    public var danceabilityPercent: Int?
    public var intensity: Double?
    public var intensityPercent: Int?
    public var recentSignals: [DJConnectMusicDNAEnergySignal]

    enum CodingKeys: String, CodingKey {
        case sampleCount = "sample_count"
        case energy
        case energyPercent = "energy_percent"
        case zone
        case promptHint = "prompt_hint"
        case danceability
        case danceabilityPercent = "danceability_percent"
        case intensity
        case intensityPercent = "intensity_percent"
        case recentSignals = "recent_signals"
    }

    public init(
        sampleCount: Int? = nil,
        energy: Double? = nil,
        energyPercent: Int? = nil,
        zone: String? = nil,
        promptHint: String? = nil,
        danceability: Double? = nil,
        danceabilityPercent: Int? = nil,
        intensity: Double? = nil,
        intensityPercent: Int? = nil,
        recentSignals: [DJConnectMusicDNAEnergySignal] = []
    ) {
        self.sampleCount = sampleCount.map { max(0, $0) }
        self.energy = energy
        self.energyPercent = energyPercent.map { max(0, min(100, $0)) }
        self.zone = zone
        self.promptHint = promptHint
        self.danceability = danceability
        self.danceabilityPercent = danceabilityPercent.map { max(0, min(100, $0)) }
        self.intensity = intensity
        self.intensityPercent = intensityPercent.map { max(0, min(100, $0)) }
        self.recentSignals = recentSignals
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sampleCount: try container.decodeIfPresent(Int.self, forKey: .sampleCount),
            energy: try container.decodeIfPresent(Double.self, forKey: .energy),
            energyPercent: try container.decodeIfPresent(Int.self, forKey: .energyPercent),
            zone: try container.decodeIfPresent(String.self, forKey: .zone),
            promptHint: try container.decodeIfPresent(String.self, forKey: .promptHint),
            danceability: try container.decodeIfPresent(Double.self, forKey: .danceability),
            danceabilityPercent: try container.decodeIfPresent(Int.self, forKey: .danceabilityPercent),
            intensity: try container.decodeIfPresent(Double.self, forKey: .intensity),
            intensityPercent: try container.decodeIfPresent(Int.self, forKey: .intensityPercent),
            recentSignals: container.decodeLossyArrayIfPresent(DJConnectMusicDNAEnergySignal.self, forKey: .recentSignals) ?? []
        )
    }
}

public struct DJConnectMusicDNAEnergySignal: Codable, Equatable, Sendable, Identifiable {
    public var id: String { [title, artist, album, createdAt].compactMap { $0 }.joined(separator: "|") }
    public var title: String?
    public var artist: String?
    public var album: String?
    public var energy: Double?
    public var danceability: Double?
    public var intensity: Double?
    public var confidence: Double?
    public var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case title
        case artist
        case album
        case energy
        case danceability
        case intensity
        case confidence
        case createdAt = "created_at"
    }

    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        energy: Double? = nil,
        danceability: Double? = nil,
        intensity: Double? = nil,
        confidence: Double? = nil,
        createdAt: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.energy = energy
        self.danceability = danceability
        self.intensity = intensity
        self.confidence = confidence
        self.createdAt = createdAt
    }
}

public struct DJConnectMusicDNASignal: Codable, Equatable, Sendable, Identifiable {
    public var id: String { [title, name, kind, value, artist, album].compactMap { $0 }.joined(separator: "|") }
    public var title: String?
    public var name: String?
    public var artist: String?
    public var album: String?
    public var count: Int?
    public var score: Double?
    public var genres: [String]
    public var kind: String?
    public var value: String?
    public var promptHint: String?

    enum CodingKeys: String, CodingKey {
        case title
        case name
        case artist
        case artistName = "artist_name"
        case album
        case count
        case score
        case genres
        case kind
        case value
        case promptHint = "prompt_hint"
    }

    public init(
        title: String? = nil,
        name: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        count: Int? = nil,
        score: Double? = nil,
        genres: [String] = [],
        kind: String? = nil,
        value: String? = nil,
        promptHint: String? = nil
    ) {
        self.title = title
        self.name = name
        self.artist = artist
        self.album = album
        self.count = count
        self.score = score
        self.genres = genres
        self.kind = kind
        self.value = value
        self.promptHint = promptHint
    }

    public init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(title: value)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            title: try container.decodeIfPresent(String.self, forKey: .title),
            name: try container.decodeIfPresent(String.self, forKey: .name),
            artist: try container.decodeIfPresent(String.self, forKey: .artist)
                ?? container.decodeIfPresent(String.self, forKey: .artistName),
            album: try container.decodeIfPresent(String.self, forKey: .album),
            count: try container.decodeIfPresent(Int.self, forKey: .count),
            score: try container.decodeIfPresent(Double.self, forKey: .score),
            genres: try container.decodeIfPresent([String].self, forKey: .genres) ?? [],
            kind: try container.decodeIfPresent(String.self, forKey: .kind),
            value: try container.decodeIfPresent(String.self, forKey: .value),
            promptHint: try container.decodeIfPresent(String.self, forKey: .promptHint)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(artist, forKey: .artist)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encodeIfPresent(count, forKey: .count)
        try container.encodeIfPresent(score, forKey: .score)
        if !genres.isEmpty {
            try container.encode(genres, forKey: .genres)
        }
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(promptHint, forKey: .promptHint)
    }
}

public struct DJConnectAskDJMessageResponse: Codable, Equatable, Sendable {
    public var userMessage: DJConnectAskDJHistoryMessage?
    public var assistantMessage: DJConnectAskDJHistoryMessage?
    public var messages: [DJConnectAskDJHistoryMessage]
    public var text: String?
    public var djText: String?
    public var message: String?
    public var textSource: String?
    public var isGeneratedText: Bool?
    public var mood: Int?
    public var images: [DJConnectResponseImage]?
    public var links: [DJConnectResponseLink]?
    public var sources: [DJConnectResponseLink]?
    public var playbackActions: [DJConnectAskDJPlaybackAction]?
    public var confirmationActions: [DJConnectAskDJPlaybackAction]?
    public var historyRevision: Int
    public var clearRevision: Int
    public var audioURL: URL?
    public var announcement: DJAnnouncement?
    public var historyLimit: Int?
    public var historyTrimmedBefore: Date?
    public var historyTrimmedCount: Int?
    public var serverTime: Date?
    public var deduplicated: Bool?
    public var intentInfo: DJConnectAskDJIntentInfo?
    public var action: String?
    public var itemType: String?
    public var openScreen: String?
    public var responseType: String?
    public var trackInsight: TrackInsight?
    public var items: [DJConnectAskDJHistoryItem]?

    enum CodingKeys: String, CodingKey {
        case userMessage = "user_message"
        case assistantMessage = "assistant_message"
        case messages
        case text
        case djText = "dj_text"
        case message
        case textSource = "text_source"
        case isGeneratedText = "is_generated_text"
        case mood
        case moodContext = "mood_context"
        case images
        case links
        case sources
        case playbackActions = "playback_actions"
        case confirmationActions = "confirmation_actions"
        case historyRevision = "history_revision"
        case clearRevision = "clear_revision"
        case audioURL = "audio_url"
        case audioUrl
        case responseAudioURL = "response_audio_url"
        case responseAudioUrl
        case announcement
        case historyLimit = "history_limit"
        case historyTrimmedBefore = "history_trimmed_before"
        case historyTrimmedCount = "history_trimmed_count"
        case serverTime = "server_time"
        case deduplicated
        case intentInfo = "intent"
        case action
        case itemType = "item_type"
        case itemTypeCamel = "itemType"
        case openScreen = "open_screen"
        case responseType = "type"
        case trackInsight = "track_insight"
        case items
    }

    public init(
        userMessage: DJConnectAskDJHistoryMessage? = nil,
        assistantMessage: DJConnectAskDJHistoryMessage? = nil,
        messages: [DJConnectAskDJHistoryMessage] = [],
        text: String? = nil,
        djText: String? = nil,
        message: String? = nil,
        textSource: String? = nil,
        isGeneratedText: Bool? = nil,
        mood: Int? = nil,
        images: [DJConnectResponseImage]? = nil,
        links: [DJConnectResponseLink]? = nil,
        sources: [DJConnectResponseLink]? = nil,
        playbackActions: [DJConnectAskDJPlaybackAction]? = nil,
        confirmationActions: [DJConnectAskDJPlaybackAction]? = nil,
        historyRevision: Int = 0,
        clearRevision: Int = 0,
        audioURL: URL? = nil,
        announcement: DJAnnouncement? = nil,
        historyLimit: Int? = nil,
        historyTrimmedBefore: Date? = nil,
        historyTrimmedCount: Int? = nil,
        serverTime: Date? = nil,
        deduplicated: Bool? = nil,
        intentInfo: DJConnectAskDJIntentInfo? = nil,
        action: String? = nil,
        itemType: String? = nil,
        openScreen: String? = nil,
        responseType: String? = nil,
        trackInsight: TrackInsight? = nil,
        items: [DJConnectAskDJHistoryItem]? = nil
    ) {
        self.userMessage = userMessage
        self.assistantMessage = assistantMessage
        self.messages = messages
        self.text = text
        self.djText = djText
        self.message = message
        self.textSource = textSource
        self.isGeneratedText = isGeneratedText
        self.mood = mood.map { max(0, min(100, $0)) }
        self.images = images
        self.links = links
        self.sources = sources
        self.playbackActions = playbackActions
        self.confirmationActions = confirmationActions
        self.historyRevision = historyRevision
        self.clearRevision = clearRevision
        self.announcement = announcement
        self.audioURL = announcement?.clientReplayAudioURL ?? audioURL
        self.historyLimit = historyLimit
        self.historyTrimmedBefore = historyTrimmedBefore
        self.historyTrimmedCount = historyTrimmedCount
        self.serverTime = serverTime
        self.deduplicated = deduplicated
        self.intentInfo = intentInfo
        self.action = action
        self.itemType = itemType
        self.openScreen = openScreen
        self.responseType = responseType
        self.trackInsight = trackInsight
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userMessage = try container.decodeIfPresent(DJConnectAskDJHistoryMessage.self, forKey: .userMessage)
        assistantMessage = try container.decodeIfPresent(DJConnectAskDJHistoryMessage.self, forKey: .assistantMessage)
        messages = try container.decodeIfPresent([DJConnectAskDJHistoryMessage].self, forKey: .messages) ?? []
        text = try container.decodeIfPresent(String.self, forKey: .text)
        djText = try container.decodeIfPresent(String.self, forKey: .djText)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        textSource = try container.decodeIfPresent(String.self, forKey: .textSource)
        isGeneratedText = try container.decodeIfPresent(Bool.self, forKey: .isGeneratedText)
        mood = Self.decodeMood(container, keys: [.mood, .moodContext])
        images = container.decodeLossyArrayIfPresent(DJConnectResponseImage.self, forKey: .images)
        links = container.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .links)
        sources = container.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .sources)
        playbackActions = container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .playbackActions)
        confirmationActions = container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .confirmationActions)
        historyRevision = try container.decodeIfPresent(Int.self, forKey: .historyRevision) ?? 0
        clearRevision = try container.decodeIfPresent(Int.self, forKey: .clearRevision) ?? 0
        audioURL = try container.decodeIfPresent(URL.self, forKey: .audioURL)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .audioUrl)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .responseAudioURL)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .responseAudioUrl)
        announcement = try container.decodeIfPresent(DJAnnouncement.self, forKey: .announcement)
        if let announcement {
            audioURL = announcement.clientReplayAudioURL
        }
        historyLimit = try container.decodeIfPresent(Int.self, forKey: .historyLimit)
        historyTrimmedBefore = DJConnectAskDJHistoryResponse.decodeDate(container, key: .historyTrimmedBefore)
        historyTrimmedCount = try container.decodeIfPresent(Int.self, forKey: .historyTrimmedCount)
        serverTime = DJConnectAskDJHistoryResponse.decodeDate(container, key: .serverTime)
        deduplicated = try container.decodeIfPresent(Bool.self, forKey: .deduplicated)
        intentInfo = try container.decodeIfPresent(DJConnectAskDJIntentInfo.self, forKey: .intentInfo)
        action = try container.decodeIfPresent(String.self, forKey: .action)
        itemType = try container.decodeIfPresent(String.self, forKey: .itemType)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .itemTypeCamel)
        if intentInfo != nil, (intentInfo?.action == nil || intentInfo?.itemType == nil) {
            intentInfo = DJConnectAskDJIntentInfo(
                category: intentInfo?.category,
                intent: intentInfo?.intent,
                action: intentInfo?.action ?? action,
                itemType: intentInfo?.itemType ?? itemType
            )
        } else if intentInfo == nil, action != nil || itemType != nil {
            intentInfo = DJConnectAskDJIntentInfo(intent: nil, action: action, itemType: itemType)
        }
        openScreen = try container.decodeIfPresent(String.self, forKey: .openScreen)
        responseType = try container.decodeIfPresent(String.self, forKey: .responseType)
        if let payload = try container.decodeIfPresent(TrackInsightPayload.self, forKey: .trackInsight) {
            trackInsight = TrackInsightParser.makeInsight(from: payload, rawText: text ?? djText ?? message ?? "", fallbackTitle: nil, fallbackArtist: nil, fallbackArtwork: nil)
        } else {
            trackInsight = nil
        }
        items = container.decodeLossyArrayIfPresent(DJConnectAskDJHistoryItem.self, forKey: .items)
        if assistantMessage?.announcement == nil, let announcement {
            assistantMessage?.announcement = announcement
            assistantMessage?.audioURL = announcement.clientReplayAudioURL
        } else if assistantMessage?.audioURL == nil, let audioURL {
            assistantMessage?.audioURL = audioURL
        }
        if assistantMessage?.textSource == nil, let textSource {
            assistantMessage?.textSource = textSource
        }
        if assistantMessage?.isGeneratedText == nil, let isGeneratedText {
            assistantMessage?.isGeneratedText = isGeneratedText
        }
        if assistantMessage?.intentInfo == nil, let intentInfo {
            assistantMessage?.intentInfo = intentInfo
        }
        if assistantMessage?.trackInsight == nil, let trackInsight {
            assistantMessage?.trackInsight = trackInsight
        }
        if assistantMessage?.mood == nil, let mood {
            assistantMessage?.mood = mood
        }
        if assistantMessage?.items.isEmpty != false, let items, !items.isEmpty {
            assistantMessage?.items = items
        }
        if assistantMessage?.images.isEmpty != false, let images, !images.isEmpty {
            assistantMessage?.images = images
        }
        if assistantMessage?.links.isEmpty != false {
            assistantMessage?.links = (links ?? []) + (sources ?? [])
            assistantMessage?.sources = sources ?? []
        }
        let topLevelActions = playbackActions ?? []
        let topLevelConfirmationActions = confirmationActions ?? []
        if assistantMessage?.playbackActions.isEmpty != false, !topLevelActions.isEmpty {
            assistantMessage?.playbackActions = topLevelActions
        }
        if assistantMessage?.confirmationActions.isEmpty != false, !topLevelConfirmationActions.isEmpty {
            assistantMessage?.confirmationActions = topLevelConfirmationActions
        }
        if assistantMessage == nil, let fallbackText = djText ?? text ?? message, !fallbackText.isEmpty {
            assistantMessage = DJConnectAskDJHistoryMessage(
                id: UUID().uuidString,
                role: .assistant,
                textSource: textSource,
                isGeneratedText: isGeneratedText,
                mood: mood,
                text: fallbackText,
                createdAt: serverTime ?? Date(),
                images: images ?? [],
                links: (links ?? []) + (sources ?? []),
                sources: sources ?? [],
                audioURL: audioURL,
                announcement: announcement,
                playbackActions: playbackActions ?? [],
                confirmationActions: confirmationActions ?? [],
                intentInfo: intentInfo,
                trackInsight: trackInsight,
                items: items ?? []
            )
        }
        if messages.isEmpty {
            messages = [userMessage, assistantMessage].compactMap { $0 }
        } else if textSource != nil || isGeneratedText != nil || audioURL != nil || announcement != nil {
            messages = messages.map { message in
                guard message.role != .user else {
                    return message
                }
                var updated = message
                if updated.announcement == nil, let announcement {
                    updated.announcement = announcement
                    updated.audioURL = announcement.clientReplayAudioURL
                } else if updated.audioURL == nil, let audioURL {
                    updated.audioURL = audioURL
                }
                if updated.textSource == nil, let textSource {
                    updated.textSource = textSource
                }
                if updated.isGeneratedText == nil, let isGeneratedText {
                    updated.isGeneratedText = isGeneratedText
                }
                return updated
            }
        }
        if let mood {
            messages = messages.map { message in
                guard message.role != .user, message.mood == nil else {
                    return message
                }
                var updated = message
                updated.mood = mood
                return updated
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(userMessage, forKey: .userMessage)
        try container.encodeIfPresent(assistantMessage, forKey: .assistantMessage)
        try container.encode(messages, forKey: .messages)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(djText, forKey: .djText)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(textSource, forKey: .textSource)
        try container.encodeIfPresent(isGeneratedText, forKey: .isGeneratedText)
        try container.encodeIfPresent(mood, forKey: .mood)
        try container.encodeIfPresent(images, forKey: .images)
        try container.encodeIfPresent(links, forKey: .links)
        try container.encodeIfPresent(sources, forKey: .sources)
        try container.encodeIfPresent(playbackActions, forKey: .playbackActions)
        try container.encodeIfPresent(confirmationActions, forKey: .confirmationActions)
        try container.encode(historyRevision, forKey: .historyRevision)
        try container.encode(clearRevision, forKey: .clearRevision)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encodeIfPresent(announcement, forKey: .announcement)
        try container.encodeIfPresent(historyLimit, forKey: .historyLimit)
        try container.encodeIfPresent(historyTrimmedBefore, forKey: .historyTrimmedBefore)
        try container.encodeIfPresent(historyTrimmedCount, forKey: .historyTrimmedCount)
        try container.encodeIfPresent(serverTime, forKey: .serverTime)
        try container.encodeIfPresent(deduplicated, forKey: .deduplicated)
        try container.encodeIfPresent(intentInfo, forKey: .intentInfo)
        try container.encodeIfPresent(action, forKey: .action)
        try container.encodeIfPresent(itemType, forKey: .itemType)
        try container.encodeIfPresent(openScreen, forKey: .openScreen)
        try container.encodeIfPresent(responseType, forKey: .responseType)
        try container.encodeIfPresent(trackInsight, forKey: .trackInsight)
        try container.encodeIfPresent(items, forKey: .items)
    }

    private static func decodeMood(_ container: KeyedDecodingContainer<CodingKeys>, keys: [CodingKeys]) -> Int? {
        for key in keys {
            if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
                return max(0, min(100, intValue))
            }
            if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
                return max(0, min(100, Int(doubleValue.rounded())))
            }
            if let stringValue = try? container.decodeIfPresent(String.self, forKey: key),
               let doubleValue = Double(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return max(0, min(100, Int(doubleValue.rounded())))
            }
            if let jsonValue = try? container.decodeIfPresent(DJConnectJSONValue.self, forKey: key),
               let mood = moodValue(from: jsonValue) {
                return mood
            }
        }
        return nil
    }

    private static func moodValue(from value: DJConnectJSONValue) -> Int? {
        switch value {
        case .int(let intValue):
            return max(0, min(100, intValue))
        case .double(let doubleValue):
            return max(0, min(100, Int(doubleValue.rounded())))
        case .string(let stringValue):
            guard let doubleValue = Double(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return nil
            }
            return max(0, min(100, Int(doubleValue.rounded())))
        case .object(let object):
            for key in ["mood", "value", "current_mood", "score"] {
                if let nested = object[key], let mood = moodValue(from: nested) {
                    return mood
                }
            }
            return nil
        default:
            return nil
        }
    }
}

public struct DJConnectAskDJIdleSuggestionRequest: Codable, Equatable, Sendable {
    public var deviceID: String
    public var clientType: DJConnectClientType
    public var clientMessageID: String
    public var mood: Int?
    public var djStyle: String?
    public var musicDNAKey: String?

    public init(
        identity: DJConnectIdentity,
        clientMessageID: String,
        mood: Int? = nil,
        djStyle: String? = nil,
        musicDNAKey: String? = nil
    ) {
        self.deviceID = identity.deviceID
        self.clientType = identity.clientType
        self.clientMessageID = clientMessageID
        self.mood = mood.map { max(0, min(100, $0)) }
        self.djStyle = djStyle
        self.musicDNAKey = musicDNAKey
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientType = "client_type"
        case clientMessageID = "client_message_id"
        case mood
        case djStyle = "dj_style"
        case musicDNAKey = "music_dna_key"
    }
}

public struct DJConnectPushRegistrationRequest: Codable, Equatable, Sendable {
    public static let defaultNotificationCategories = ["ask_dj"]

    public var deviceID: String
    public var clientType: DJConnectClientType
    public var pushToken: String
    public var pushEnvironment: DJConnectPushEnvironment
    public var appBundleID: String
    public var appVersion: String?
    public var protocolVersion: String?
    public var locale: String?
    public var notificationCategories: [String]
    public var bootstrapProof: String?

    public init(
        identity: DJConnectIdentity,
        pushToken: String,
        pushEnvironment: DJConnectPushEnvironment,
        appBundleID: String,
        appVersion: String? = nil,
        locale: String? = nil,
        notificationCategories: [String] = Self.defaultNotificationCategories,
        bootstrapProof: String? = nil
    ) {
        self.deviceID = identity.deviceID
        self.clientType = identity.clientType
        self.pushToken = pushToken
        self.pushEnvironment = pushEnvironment
        self.appBundleID = appBundleID
        self.appVersion = appVersion ?? identity.appVersion
        self.protocolVersion = identity.protocolVersion ?? identity.firmware
        self.locale = locale
        self.notificationCategories = notificationCategories
        self.bootstrapProof = bootstrapProof
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientType = "client_type"
        case pushToken = "push_token"
        case pushEnvironment = "push_environment"
        case appBundleID = "app_bundle_id"
        case appVersion = "app_version"
        case protocolVersion = "protocol_version"
        case locale
        case notificationCategories = "categories"
        case bootstrapProof = "bootstrap_proof"
    }
}

public struct DJConnectPairingBootstrapProofRequest: Codable, Equatable, Sendable {
    public var haInstallID: String?
    public var integration: String
    public var integrationVersion: String?
    public var clientType: DJConnectClientType
    public var deviceID: String
    public var pairingSessionID: String?
    public var djAnnouncement: DJAnnouncementCapabilities?
    public var appBundleID: String
    public var pushEnvironment: DJConnectPushEnvironment

    public init(
        haInstallID: String?,
        integration: String = "djconnect_hacs",
        integrationVersion: String?,
        identity: DJConnectIdentity,
        pairingSessionID: String?,
        appBundleID: String,
        pushEnvironment: DJConnectPushEnvironment
    ) {
        self.haInstallID = haInstallID
        self.integration = integration
        self.integrationVersion = integrationVersion
        self.clientType = identity.clientType
        self.deviceID = identity.deviceID
        self.pairingSessionID = pairingSessionID
        self.appBundleID = appBundleID
        self.pushEnvironment = pushEnvironment
    }

    enum CodingKeys: String, CodingKey {
        case haInstallID = "ha_install_id"
        case integration
        case integrationVersion = "integration_version"
        case clientType = "client_type"
        case deviceID = "device_id"
        case pairingSessionID = "pairing_session_id"
        case appBundleID = "app_bundle_id"
        case pushEnvironment = "push_environment"
    }
}

public struct DJConnectPairingBootstrapProofResponse: Codable, Equatable, Sendable {
    public var success: Bool
    public var error: String?
    public var message: String?
    public var bootstrapProof: String?
    public var expiresAt: String?

    public init(
        success: Bool,
        error: String? = nil,
        message: String? = nil,
        bootstrapProof: String? = nil,
        expiresAt: String? = nil
    ) {
        self.success = success
        self.error = error
        self.message = message
        self.bootstrapProof = bootstrapProof
        self.expiresAt = expiresAt
    }

    enum CodingKeys: String, CodingKey {
        case success
        case error
        case message
        case bootstrapProof = "bootstrap_proof"
        case expiresAt = "expires_at"
    }
}

public struct DJConnectPushUnregistrationRequest: Codable, Equatable, Sendable {
    public var deviceID: String
    public var clientType: DJConnectClientType
    public var pushToken: String?

    public init(
        identity: DJConnectIdentity,
        pushToken: String? = nil
    ) {
        self.deviceID = identity.deviceID
        self.clientType = identity.clientType
        self.pushToken = pushToken
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientType = "client_type"
        case pushToken = "push_token"
    }
}

public struct DJConnectResponseImage: Codable, Equatable, Sendable, Identifiable {
    public var id: String { url.absoluteString }
    public var url: URL
    public var title: String?
    public var subtitle: String?
    public var kind: String?
    public var source: String?
    public var thumbnailURL: URL?

    public init(
        url: URL,
        title: String? = nil,
        subtitle: String? = nil,
        kind: String? = nil,
        source: String? = nil,
        thumbnailURL: URL? = nil
    ) {
        self.url = url
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.source = source
        self.thumbnailURL = thumbnailURL
    }

    enum CodingKeys: String, CodingKey {
        case url
        case title
        case subtitle
        case kind
        case source
        case thumbnailURL = "thumbnail_url"
        case thumbnailUrl
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(URL.self, forKey: .url)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        thumbnailURL = try container.decodeIfPresent(URL.self, forKey: .thumbnailURL)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .thumbnailUrl)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
    }
}

public struct DJConnectResponseLink: Codable, Equatable, Sendable, Identifiable {
    public var id: String { url.absoluteString }
    public var url: URL
    public var title: String?
    public var subtitle: String?
    public var kind: String?
    public var source: String?

    public init(
        url: URL,
        title: String? = nil,
        subtitle: String? = nil,
        kind: String? = nil,
        source: String? = nil
    ) {
        self.url = url
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case url
        case title
        case label
        case subtitle
        case description
        case kind
        case source
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .label)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .description)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        if let decodedURL = try container.decodeIfPresent(URL.self, forKey: .url) {
            url = decodedURL
        } else {
            let fallbackID = (source ?? title ?? kind ?? "source")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "source"
            url = URL(string: "djconnect-source:///\(fallbackID)")!
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(source, forKey: .source)
    }
}

public struct DJConnectAskDJResponse: Codable, Equatable, Sendable {
    public var success: Bool
    public var text: String?
    public var djText: String?
    public var message: String?
    public var audioURL: URL?
    public var images: [DJConnectResponseImage]?
    public var links: [DJConnectResponseLink]?
    public var sources: [DJConnectResponseLink]?
    public var playbackActions: [DJConnectAskDJPlaybackAction]?
    public var confirmationActions: [DJConnectAskDJPlaybackAction]?
    public var intent: String?
    public var intentInfo: DJConnectAskDJIntentInfo?
    public var action: String?
    public var items: [DJConnectAskDJHistoryItem]?
    public var musicDNAKey: String?

    enum CodingKeys: String, CodingKey {
        case success
        case text
        case djText = "dj_text"
        case message
        case audioURL = "audio_url"
        case audioUrl
        case responseAudioURL = "response_audio_url"
        case responseAudioUrl
        case mediaURL = "media_url"
        case mediaUrl
        case images
        case links
        case sources
        case playbackActions = "playback_actions"
        case confirmationActions = "confirmation_actions"
        case intent
        case action
        case items
        case musicDNAKey = "music_dna_key"
    }

    public init(
        success: Bool = true,
        text: String? = nil,
        djText: String? = nil,
        message: String? = nil,
        audioURL: URL? = nil,
        images: [DJConnectResponseImage]? = nil,
        links: [DJConnectResponseLink]? = nil,
        sources: [DJConnectResponseLink]? = nil,
        playbackActions: [DJConnectAskDJPlaybackAction]? = nil,
        confirmationActions: [DJConnectAskDJPlaybackAction]? = nil,
        intent: String? = nil,
        intentInfo: DJConnectAskDJIntentInfo? = nil,
        action: String? = nil,
        items: [DJConnectAskDJHistoryItem]? = nil,
        musicDNAKey: String? = nil
    ) {
        self.success = success
        self.text = text
        self.djText = djText
        self.message = message
        self.audioURL = audioURL
        self.images = images
        self.links = links
        self.sources = sources
        self.playbackActions = playbackActions
        self.confirmationActions = confirmationActions
        self.intent = intent
        self.intentInfo = intentInfo ?? intent.map { DJConnectAskDJIntentInfo(intent: $0, action: action) }
        self.action = action
        self.items = items
        self.musicDNAKey = musicDNAKey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? true
        text = try container.decodeIfPresent(String.self, forKey: .text)
        djText = try container.decodeIfPresent(String.self, forKey: .djText)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        audioURL = try container.decodeIfPresent(URL.self, forKey: .audioURL)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .audioUrl)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .responseAudioURL)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .responseAudioUrl)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .mediaURL)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .mediaUrl)
        images = container.decodeLossyArrayIfPresent(DJConnectResponseImage.self, forKey: .images)
        links = container.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .links)
        sources = container.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .sources)
        playbackActions = container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .playbackActions)
        confirmationActions = container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .confirmationActions)
        intentInfo = try container.decodeIfPresent(DJConnectAskDJIntentInfo.self, forKey: .intent)
        intent = intentInfo?.intent
        action = try container.decodeIfPresent(String.self, forKey: .action)
        if intentInfo != nil, intentInfo?.action == nil, action != nil {
            intentInfo = DJConnectAskDJIntentInfo(
                category: intentInfo?.category,
                intent: intentInfo?.intent,
                action: action,
                itemType: intentInfo?.itemType
            )
        }
        items = container.decodeLossyArrayIfPresent(DJConnectAskDJHistoryItem.self, forKey: .items)
        musicDNAKey = try container.decodeIfPresent(String.self, forKey: .musicDNAKey)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(djText, forKey: .djText)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encodeIfPresent(images, forKey: .images)
        try container.encodeIfPresent(links, forKey: .links)
        try container.encodeIfPresent(sources, forKey: .sources)
        try container.encodeIfPresent(playbackActions, forKey: .playbackActions)
        try container.encodeIfPresent(confirmationActions, forKey: .confirmationActions)
        try container.encodeIfPresent(intentInfo ?? intent.map { DJConnectAskDJIntentInfo(intent: $0, action: action) }, forKey: .intent)
        try container.encodeIfPresent(action, forKey: .action)
        try container.encodeIfPresent(items, forKey: .items)
        try container.encodeIfPresent(musicDNAKey, forKey: .musicDNAKey)
    }
}

public struct DJConnectAskDJPlaybackAction: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var deviceID: String?
    public var deviceName: String?
    public var active: Bool?
    public var cached: Bool?
    public var provider: String?
    public var source: String?
    public var firstSeenAt: String?
    public var lastSeenAt: String?
    public var uri: String?
    public var uris: [String]
    public var contextURI: String?
    public var offsetURI: String?
    public var imageURL: URL?
    public var kind: String?
    public var command: String?
    public var reason: String?
    public var actionStyle: String?
    public var responseValue: String?
    public var buttonLabel: String?
    public var value: DJConnectJSONValue?
    public var toggle: Bool?
    public var toggleState: Bool?
    public var favoriteStatus: Bool?
    public var clientPrompt: String?
    public var musicBackendRevision: Int?
    public var text: String?
    public var prompt: String?
    public var query: String?
    public var askDJText: String?
    public var artist: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case name
        case label
        case subtitle
        case description
        case artist
        case deviceID = "device_id"
        case deviceId
        case deviceName = "device_name"
        case deviceNameCamel = "deviceName"
        case active
        case isActive = "is_active"
        case cached
        case provider
        case source
        case firstSeenAt = "first_seen_at"
        case lastSeenAt = "last_seen_at"
        case uri
        case uris
        case spotifyURI = "spotify_uri"
        case contextURI = "context_uri"
        case contextUri
        case offsetURI = "offset_uri"
        case offsetUri
        case albumImageURL = "album_image_url"
        case albumImageUrl
        case albumArtURL = "album_art_url"
        case albumArtUrl
        case mediaImageURL = "media_image_url"
        case mediaImageUrl
        case imageURL = "image_url"
        case imageUrl
        case thumbnailURL = "thumbnail_url"
        case thumbnailUrl
        case entityPicture = "entity_picture"
        case kind
        case type
        case command
        case reason
        case actionStyle = "action_style"
        case actionStyleCamel = "actionStyle"
        case responseValue = "response_value"
        case responseValueCamel = "responseValue"
        case buttonLabel = "button_label"
        case buttonLabelCamel = "buttonLabel"
        case value
        case toggle
        case toggleState = "toggle_state"
        case toggleStateCamel = "toggleState"
        case favoriteStatus = "favorite_status"
        case favoriteStatusCamel = "favoriteStatus"
        case clientPrompt = "client_prompt"
        case clientPromptCamel = "clientPrompt"
        case musicBackendRevision = "music_backend_revision"
        case text
        case prompt
        case query
        case askDJText = "ask_dj_text"
        case askDJTextCamel = "askDJText"
        case artistName = "artist_name"
        case artistNameCamel = "artistName"
    }

    public init(
        id: String? = nil,
        title: String,
        subtitle: String? = nil,
        deviceID: String? = nil,
        deviceName: String? = nil,
        active: Bool? = nil,
        cached: Bool? = nil,
        provider: String? = nil,
        source: String? = nil,
        firstSeenAt: String? = nil,
        lastSeenAt: String? = nil,
        uri: String? = nil,
        uris: [String] = [],
        contextURI: String? = nil,
        offsetURI: String? = nil,
        imageURL: URL? = nil,
        kind: String? = nil,
        command: String? = nil,
        reason: String? = nil,
        actionStyle: String? = nil,
        responseValue: String? = nil,
        buttonLabel: String? = nil,
        value: DJConnectJSONValue? = nil,
        toggle: Bool? = nil,
        toggleState: Bool? = nil,
        favoriteStatus: Bool? = nil,
        clientPrompt: String? = nil,
        musicBackendRevision: Int? = nil,
        text: String? = nil,
        prompt: String? = nil,
        query: String? = nil,
        askDJText: String? = nil,
        artist: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.active = active
        self.cached = cached
        self.provider = provider
        self.source = source
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.uri = uri
        self.uris = uris
        self.contextURI = contextURI
        self.offsetURI = offsetURI
        self.imageURL = imageURL
        self.kind = kind
        self.command = command
        self.reason = reason
        self.actionStyle = actionStyle
        self.responseValue = responseValue
        self.buttonLabel = buttonLabel
        self.value = value
        self.toggle = toggle
        self.toggleState = toggleState
        self.favoriteStatus = favoriteStatus
        self.clientPrompt = clientPrompt
        self.musicBackendRevision = musicBackendRevision
        self.text = text
        self.prompt = prompt
        self.query = query
        self.askDJText = askDJText
        self.artist = artist
        self.id = id ?? [deviceID, uri, contextURI, title].compactMap { $0 }.joined(separator: "|")
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .name)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .deviceName)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .deviceNameCamel)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .label)
            ?? ""
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .description)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .artist)
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .deviceId)
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .deviceNameCamel)
        active = try container.decodeIfPresent(Bool.self, forKey: .active)
            ?? container.decodeIfPresentIgnoringErrors(Bool.self, forKey: .isActive)
        cached = try container.decodeIfPresent(Bool.self, forKey: .cached)
        provider = try container.decodeIfPresent(String.self, forKey: .provider)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        firstSeenAt = try container.decodeIfPresent(String.self, forKey: .firstSeenAt)
        lastSeenAt = try container.decodeIfPresent(String.self, forKey: .lastSeenAt)
        uri = try container.decodeIfPresent(String.self, forKey: .uri)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .spotifyURI)
        uris = container.decodeLossyArrayIfPresent(String.self, forKey: .uris) ?? []
        contextURI = try container.decodeIfPresent(String.self, forKey: .contextURI)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .contextUri)
        offsetURI = try container.decodeIfPresent(String.self, forKey: .offsetURI)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .offsetUri)
        imageURL = container.decodeURLAliasIfPresent(
            .imageURL,
            .imageUrl,
            .albumImageURL,
            .albumImageUrl,
            .albumArtURL,
            .albumArtUrl,
            .mediaImageURL,
            .mediaImageUrl,
            .thumbnailURL,
            .thumbnailUrl,
            .entityPicture
        )
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .type)
        command = try container.decodeIfPresent(String.self, forKey: .command)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        actionStyle = try container.decodeIfPresent(String.self, forKey: .actionStyle)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .actionStyleCamel)
        value = try container.decodeIfPresent(DJConnectJSONValue.self, forKey: .value)
        responseValue = try container.decodeIfPresent(String.self, forKey: .responseValue)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .responseValueCamel)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .value)
            ?? Self.stringValue(from: value, keys: ["response_value", "responseValue", "text", "prompt", "value"])
        buttonLabel = try container.decodeIfPresent(String.self, forKey: .buttonLabel)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .buttonLabelCamel)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .label)
        toggle = try container.decodeIfPresent(Bool.self, forKey: .toggle)
        toggleState = try container.decodeIfPresent(Bool.self, forKey: .toggleState)
            ?? container.decodeIfPresentIgnoringErrors(Bool.self, forKey: .toggleStateCamel)
        favoriteStatus = try container.decodeIfPresent(Bool.self, forKey: .favoriteStatus)
            ?? container.decodeIfPresentIgnoringErrors(Bool.self, forKey: .favoriteStatusCamel)
        clientPrompt = try container.decodeIfPresent(String.self, forKey: .clientPrompt)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .clientPromptCamel)
        musicBackendRevision = try container.decodeIfPresent(Int.self, forKey: .musicBackendRevision)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
        query = try container.decodeIfPresent(String.self, forKey: .query)
        askDJText = try container.decodeIfPresent(String.self, forKey: .askDJText)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .askDJTextCamel)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .artistName)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .artistNameCamel)
            ?? Self.stringValue(from: value, keys: ["artist", "artist_name", "artistName"])
        let decodedID = try container.decodeIfPresent(String.self, forKey: .id)
        id = decodedID ?? [deviceID, responseValue, uri, contextURI, title].compactMap { $0 }.joined(separator: "|")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encodeIfPresent(deviceID, forKey: .deviceID)
        try container.encodeIfPresent(deviceName, forKey: .deviceName)
        try container.encodeIfPresent(active, forKey: .active)
        try container.encodeIfPresent(cached, forKey: .cached)
        try container.encodeIfPresent(provider, forKey: .provider)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(firstSeenAt, forKey: .firstSeenAt)
        try container.encodeIfPresent(lastSeenAt, forKey: .lastSeenAt)
        try container.encodeIfPresent(uri, forKey: .uri)
        if !uris.isEmpty {
            try container.encode(uris, forKey: .uris)
        }
        try container.encodeIfPresent(contextURI, forKey: .contextURI)
        try container.encodeIfPresent(offsetURI, forKey: .offsetURI)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(command, forKey: .command)
        try container.encodeIfPresent(reason, forKey: .reason)
        try container.encodeIfPresent(actionStyle, forKey: .actionStyle)
        try container.encodeIfPresent(responseValue, forKey: .responseValue)
        try container.encodeIfPresent(buttonLabel, forKey: .buttonLabel)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(toggle, forKey: .toggle)
        try container.encodeIfPresent(toggleState, forKey: .toggleState)
        try container.encodeIfPresent(favoriteStatus, forKey: .favoriteStatus)
        try container.encodeIfPresent(clientPrompt, forKey: .clientPrompt)
        try container.encodeIfPresent(musicBackendRevision, forKey: .musicBackendRevision)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(prompt, forKey: .prompt)
        try container.encodeIfPresent(query, forKey: .query)
        try container.encodeIfPresent(askDJText, forKey: .askDJText)
        try container.encodeIfPresent(artist, forKey: .artist)
    }

    public var isOutputAction: Bool {
        kind?.localizedCaseInsensitiveCompare("output") == .orderedSame
    }

    public var isFavoriteCurrentTrackControlAction: Bool {
        let normalizedCommand = command?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedCommand == "set_current_track_favorite" || normalizedCommand == "save_current_track" else {
            return false
        }
        let normalizedKind = kind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedKind == nil || normalizedKind == "control"
    }

    public var isSaveCurrentTrackControlAction: Bool {
        isFavoriteCurrentTrackControlAction
    }

    public var outputDeviceID: String? {
        guard isOutputAction else {
            return nil
        }
        let candidate = responseValue ?? deviceID ?? Self.stringValue(from: value, keys: ["device_id", "deviceId", "id", "value"])
        if let candidate {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if case let .string(value) = value {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    public var isRecommendationAction: Bool {
        let normalizedKind = kind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["track", "album", "playlist", "artist", "track_mix"].contains(normalizedKind ?? "")
    }

    public var isConfirmationAction: Bool {
        let candidates = [kind, actionStyle, command]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return responseValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || candidates.contains { $0.contains("confirmation") || $0.contains("followup") }
    }

    public var isAskDJMessageAction: Bool {
        let candidates = [command, kind, actionStyle, reason]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return candidates.contains("ask_dj_message")
            || candidates.contains { candidate in
                candidate.contains("ask_dj_follow")
                    || candidate.contains("ask_dj_artist")
                    || candidate.contains("artist_more")
                    || candidate.contains("more_artist")
            }
    }

    public var resolvedAskDJMessageText: String? {
        let explicitCandidates = [
            text,
            prompt,
            query,
            askDJText,
            Self.stringValue(from: value, keys: ["text"]),
            Self.stringValue(from: value, keys: ["prompt"])
        ]
        for candidate in explicitCandidates {
            if let trimmed = Self.trimmedNonGenericAskDJText(candidate) {
                return trimmed
            }
        }
        if let artist = resolvedArtistName {
            return "Meer van \(artist)"
        }
        return "Laat meer muziek van deze artiest zien"
    }

    public var resolvedArtistName: String? {
        let candidates = [
            artist,
            Self.stringValue(from: value, keys: ["artist", "artist_name", "artistName"]),
            subtitle
        ]
        for candidate in candidates {
            if let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    public var commandValue: DJConnectCommandValue? {
        Self.commandValue(from: value)
    }

    public var fullActionCommandValue: DJConnectCommandValue {
        .jsonObject(jsonObjectValue)
    }

    public var jsonObjectValue: [String: DJConnectJSONValue] {
        var value: [String: DJConnectJSONValue] = [
            "id": .string(id),
            "title": .string(title)
        ]
        Self.add(subtitle, as: "subtitle", to: &value)
        Self.add(deviceID, as: "device_id", to: &value)
        Self.add(deviceName, as: "device_name", to: &value)
        if let active {
            value["active"] = .bool(active)
        }
        Self.add(uri, as: "uri", to: &value)
        if !uris.isEmpty {
            value["uris"] = .array(uris.map { .string($0) })
        }
        Self.add(contextURI, as: "context_uri", to: &value)
        Self.add(offsetURI, as: "offset_uri", to: &value)
        Self.add(imageURL?.absoluteString, as: "image_url", to: &value)
        Self.add(kind, as: "kind", to: &value)
        Self.add(command, as: "command", to: &value)
        Self.add(reason, as: "reason", to: &value)
        Self.add(actionStyle, as: "action_style", to: &value)
        Self.add(responseValue, as: "response_value", to: &value)
        Self.add(buttonLabel, as: "button_label", to: &value)
        Self.add(clientPrompt, as: "client_prompt", to: &value)
        if let toggle {
            value["toggle"] = .bool(toggle)
        }
        if let toggleState {
            value["toggle_state"] = .bool(toggleState)
        }
        if let favoriteStatus {
            value["favorite_status"] = .bool(favoriteStatus)
        }
        Self.add(text, as: "text", to: &value)
        Self.add(prompt, as: "prompt", to: &value)
        Self.add(query, as: "query", to: &value)
        Self.add(askDJText, as: "ask_dj_text", to: &value)
        Self.add(artist, as: "artist", to: &value)
        if let actionValue = self.value {
            value["value"] = actionValue
        }
        return value
    }

    private static func add(_ string: String?, as key: String, to value: inout [String: DJConnectJSONValue]) {
        guard let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return
        }
        value[key] = .string(trimmed)
    }

    private static func commandValue(from value: DJConnectJSONValue?) -> DJConnectCommandValue? {
        switch value {
        case let .bool(value):
            .bool(value)
        case let .int(value):
            .int(value)
        case let .double(value) where value.rounded() == value:
            .int(Int(value))
        case let .string(value):
            .string(value)
        case let .object(value):
            .jsonObject(value)
        default:
            nil
        }
    }

    private static func stringValue(from value: DJConnectJSONValue?, keys: [String]) -> String? {
        guard case let .object(object) = value else {
            return nil
        }
        for key in keys {
            if case let .string(candidate)? = object[key] {
                let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private static func trimmedNonGenericAskDJText(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        let normalized = trimmed.lowercased()
        let genericLabels: Set<String> = [
            "meer",
            "play now",
            "speel nu",
            "meer van deze artiest"
        ]
        return genericLabels.contains(normalized) ? nil : trimmed
    }

    public var isActiveOutputAction: Bool {
        isOutputAction && active == true
    }
}

private extension KeyedDecodingContainer where Key == DJConnectAskDJPlaybackAction.CodingKeys {
    func decodeURLAliasIfPresent(_ keys: Key...) -> URL? {
        for key in keys {
            guard let value = try? decodeIfPresent(URL.self, forKey: key) else {
                continue
            }
            return value
        }
        return nil
    }
}

public enum DJConnectCommandValue: Codable, Equatable, Sendable {
    case bool(Bool)
    case int(Int)
    case string(String)
    case object([String: String])
    case jsonObject([String: DJConnectJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode([String: String].self) {
            self = .object(value)
        } else if let value = try? container.decode([String: DJConnectJSONValue].self) {
            self = .jsonObject(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .jsonObject(value):
            try container.encode(value)
        }
    }
}

public enum DJConnectJSONValue: Codable, Equatable, Sendable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([DJConnectJSONValue])
    case object([String: DJConnectJSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([DJConnectJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: DJConnectJSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public struct DJConnectEnvelope<T: Codable & Sendable>: Codable, Sendable {
    public var success: Bool
    public var error: String?
    public var message: String?
    public var backendAvailable: Bool?
    public var haVersion: String?
    public var haMajorMinor: String?
    public var remoteSupported: Bool?
    public var musicBackend: String?
    public var musicBackendName: String?
    public var musicBackendAvailable: Bool?
    public var musicBackendRevision: Int?
    public var musicBackendCapabilities: DJConnectMusicBackendCapabilities?
    public var musicTargetPlayer: DJConnectMusicTargetPlayer?
    public var musicBackendError: String?
    public var clientType: DJConnectClientType?
    public var deviceLanguage: String?
    public var language: String?
    public var playback: DJConnectPlayback?
    public var data: T?
    public var pushSupported: Bool?
    public var pushRegistered: Bool?
    public var pushEnvironment: DJConnectPushEnvironment?
    public var lastPushError: String?
    public var bootstrapProof: String?
    public var bootstrapProofExpiresAt: String?
    public var haInstallID: String?
    public var integrationVersion: String?
    public var pairingSessionID: String?
    public var djAnnouncement: DJAnnouncementCapabilities?

    enum CodingKeys: String, CodingKey {
        case success
        case error
        case message
        case backendAvailable = "backend_available"
        case haVersion = "ha_version"
        case haMajorMinor = "ha_major_minor"
        case remoteSupported = "remote_supported"
        case musicBackend = "music_backend"
        case musicBackendName = "music_backend_name"
        case musicBackendAvailable = "music_backend_available"
        case musicBackendRevision = "music_backend_revision"
        case musicBackendCapabilities = "music_backend_capabilities"
        case musicTargetPlayer = "music_target_player"
        case musicBackendError = "music_backend_error"
        case clientType = "client_type"
        case deviceLanguage = "device_language"
        case language
        case playback
        case data
        case pushSupported = "push_supported"
        case pushRegistered = "push_registered"
        case pushEnvironment = "push_environment"
        case lastPushError = "last_push_error"
        case bootstrapProof = "bootstrap_proof"
        case bootstrapProofExpiresAt = "bootstrap_proof_expires_at"
        case haInstallID = "ha_install_id"
        case integrationVersion = "integration_version"
        case pairingSessionID = "pairing_session_id"
        case djAnnouncement = "dj_announcement"
    }
}

public extension DJConnectEnvelope {
    var musicBackendSummary: DJConnectMusicBackendSummary {
        DJConnectMusicBackendSummary(
            remoteSupported: remoteSupported,
            musicBackend: musicBackend,
            musicBackendName: musicBackendName,
            musicBackendAvailable: musicBackendAvailable,
            musicBackendRevision: musicBackendRevision,
            musicBackendCapabilities: musicBackendCapabilities,
            musicTargetPlayer: musicTargetPlayer,
            musicBackendError: musicBackendError
        )
    }
}

public struct DJConnectPlayback: Codable, Equatable, Sendable {
    public var hasPlayback: Bool?
    public var isPlaying: Bool?
    public var trackName: String?
    public var artistName: String?
    public var albumImageURL: URL?
    public var progressMS: Int?
    public var durationMS: Int?
    public var volumePercent: Int?
    public var shuffle: Bool?
    public var repeatState: DJConnectRepeatState?
    public var device: DJConnectPlaybackDevice?
    public var contextURI: String?
    public var isLiked: Bool?
    public var favoriteStatus: Bool?

    public init(
        hasPlayback: Bool? = nil,
        isPlaying: Bool? = nil,
        trackName: String? = nil,
        artistName: String? = nil,
        albumImageURL: URL? = nil,
        progressMS: Int? = nil,
        durationMS: Int? = nil,
        volumePercent: Int? = nil,
        shuffle: Bool? = nil,
        repeatState: DJConnectRepeatState? = nil,
        device: DJConnectPlaybackDevice? = nil,
        contextURI: String? = nil,
        isLiked: Bool? = nil,
        favoriteStatus: Bool? = nil
    ) {
        self.hasPlayback = hasPlayback
        self.isPlaying = isPlaying
        self.trackName = trackName
        self.artistName = artistName
        self.albumImageURL = albumImageURL
        self.progressMS = progressMS
        self.durationMS = durationMS
        self.volumePercent = volumePercent
        self.shuffle = shuffle
        self.repeatState = repeatState
        self.device = device
        self.contextURI = contextURI
        self.isLiked = isLiked
        self.favoriteStatus = favoriteStatus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasPlayback = try container.decodeIfPresent(Bool.self, forKey: .hasPlayback)
        isPlaying = try container.decodeIfPresent(Bool.self, forKey: .isPlaying)
        trackName = container.decodeStringAliasIfPresent(.trackName, .title, .name)
        artistName = container.decodeStringAliasIfPresent(.artistName, .artist, .artists)
        albumImageURL = container.decodeURLAliasIfPresent(
            .albumImageURL,
            .albumImageUrl,
            .albumArtURL,
            .albumArtUrl,
            .mediaImageURL,
            .mediaImageUrl,
            .imageURL,
            .imageUrl,
            .artwork,
            .thumbnailURL,
            .entityPicture
        )
        progressMS = try container.decodeIfPresent(Int.self, forKey: .progressMS)
        durationMS = try container.decodeIfPresent(Int.self, forKey: .durationMS)
        volumePercent = try container.decodeIfPresent(Int.self, forKey: .volumePercent)
        shuffle = try container.decodeIfPresent(Bool.self, forKey: .shuffle)
        repeatState = try container.decodeIfPresent(DJConnectRepeatState.self, forKey: .repeatState)
        device = try container.decodeIfPresent(DJConnectPlaybackDevice.self, forKey: .device)
        contextURI = container.decodeStringAliasIfPresent(.contextURI, .contextUri, .queueContext)
        isLiked = container.decodeBoolAliasIfPresent(.isLiked, .liked)
        favoriteStatus = container.decodeBoolAliasIfPresent(.favoriteStatus, .favoriteStatusCamel)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(hasPlayback, forKey: .hasPlayback)
        try container.encodeIfPresent(isPlaying, forKey: .isPlaying)
        try container.encodeIfPresent(trackName, forKey: .trackName)
        try container.encodeIfPresent(artistName, forKey: .artistName)
        try container.encodeIfPresent(albumImageURL, forKey: .albumImageURL)
        try container.encodeIfPresent(progressMS, forKey: .progressMS)
        try container.encodeIfPresent(durationMS, forKey: .durationMS)
        try container.encodeIfPresent(volumePercent, forKey: .volumePercent)
        try container.encodeIfPresent(shuffle, forKey: .shuffle)
        try container.encodeIfPresent(repeatState, forKey: .repeatState)
        try container.encodeIfPresent(device, forKey: .device)
        try container.encodeIfPresent(contextURI, forKey: .contextURI)
        try container.encodeIfPresent(isLiked, forKey: .isLiked)
        try container.encodeIfPresent(favoriteStatus, forKey: .favoriteStatus)
    }

    enum CodingKeys: String, CodingKey {
        case hasPlayback = "has_playback"
        case isPlaying = "is_playing"
        case trackName = "track_name"
        case title
        case name
        case artistName = "artist_name"
        case artist
        case artists
        case albumImageURL = "album_image_url"
        case albumImageUrl
        case albumArtURL = "album_art_url"
        case albumArtUrl
        case mediaImageURL = "media_image_url"
        case mediaImageUrl
        case imageURL = "image_url"
        case imageUrl
        case artwork
        case thumbnailURL = "thumbnail_url"
        case entityPicture = "entity_picture"
        case progressMS = "progress_ms"
        case durationMS = "duration_ms"
        case volumePercent = "volume_percent"
        case shuffle
        case repeatState = "repeat_state"
        case device
        case contextURI = "context_uri"
        case contextUri
        case queueContext = "queue_context"
        case isLiked = "is_liked"
        case liked
        case favoriteStatus = "favorite_status"
        case favoriteStatusCamel = "favoriteStatus"
    }

    public var currentTrackFavoriteStatus: Bool? {
        favoriteStatus ?? isLiked
    }
}

public enum DJConnectVolumeNormalizer {
    public static func clampNormalized(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }

    public static func clampBackendPercent(_ value: Int) -> Int {
        min(100, max(0, value))
    }

    public static func backendPercent(fromNormalized value: Double) -> Int {
        clampBackendPercent(Int(round(clampNormalized(value) * 100)))
    }

    public static func normalized(fromBackendPercent value: Int?) -> Double? {
        guard let value = validBackendPercent(value) else {
            return nil
        }
        return Double(value) / 100.0
    }

    public static func validBackendPercent(_ value: Int?) -> Int? {
        guard let value, (0...100).contains(value) else {
            return nil
        }
        return value
    }

    public static func sanitizedPlayback(_ playback: DJConnectPlayback?) -> DJConnectPlayback? {
        guard var playback else {
            return nil
        }
        playback.volumePercent = validBackendPercent(playback.volumePercent)
        if var device = playback.device {
            device.volumePercent = validBackendPercent(device.volumePercent)
            playback.device = device
        }
        return playback
    }
}

private extension KeyedDecodingContainer where Key == DJConnectPlayback.CodingKeys {
    func decodeBoolAliasIfPresent(_ keys: Key...) -> Bool? {
        for key in keys {
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
        }
        return nil
    }

    func decodeStringAliasIfPresent(_ keys: Key...) -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    func decodeURLAliasIfPresent(_ keys: Key...) -> URL? {
        for key in keys {
            guard let rawValue = try? decodeIfPresent(String.self, forKey: key) else {
                continue
            }
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, let url = URL(string: value) else {
                continue
            }
            return url
        }
        return nil
    }
}

public struct DJConnectPlaybackDevice: Codable, Equatable, Sendable {
    public var id: String?
    public var name: String?
    public var type: String?
    public var active: Bool?
    public var cached: Bool?
    public var provider: String?
    public var source: String?
    public var firstSeenAt: String?
    public var lastSeenAt: String?
    public var supportsVolume: Bool?
    public var volumePercent: Int?

    public init(
        id: String? = nil,
        name: String? = nil,
        type: String? = nil,
        active: Bool? = nil,
        cached: Bool? = nil,
        provider: String? = nil,
        source: String? = nil,
        firstSeenAt: String? = nil,
        lastSeenAt: String? = nil,
        supportsVolume: Bool? = nil,
        volumePercent: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.active = active
        self.cached = cached
        self.provider = provider
        self.source = source
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.supportsVolume = supportsVolume
        self.volumePercent = volumePercent
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case active
        case isActive = "is_active"
        case cached
        case provider
        case source
        case firstSeenAt = "first_seen_at"
        case lastSeenAt = "last_seen_at"
        case supportsVolume = "supports_volume"
        case volumePercent = "volume_percent"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        active = try container.decodeIfPresent(Bool.self, forKey: .active)
            ?? container.decodeIfPresentIgnoringErrors(Bool.self, forKey: .isActive)
        cached = try container.decodeIfPresent(Bool.self, forKey: .cached)
        provider = try container.decodeIfPresent(String.self, forKey: .provider)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        firstSeenAt = try container.decodeIfPresent(String.self, forKey: .firstSeenAt)
        lastSeenAt = try container.decodeIfPresent(String.self, forKey: .lastSeenAt)
        supportsVolume = try container.decodeIfPresent(Bool.self, forKey: .supportsVolume)
        volumePercent = try container.decodeIfPresent(Int.self, forKey: .volumePercent)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(active, forKey: .active)
        try container.encodeIfPresent(cached, forKey: .cached)
        try container.encodeIfPresent(provider, forKey: .provider)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(firstSeenAt, forKey: .firstSeenAt)
        try container.encodeIfPresent(lastSeenAt, forKey: .lastSeenAt)
        try container.encodeIfPresent(supportsVolume, forKey: .supportsVolume)
        try container.encodeIfPresent(volumePercent, forKey: .volumePercent)
    }
}

public struct DJConnectOutputDevice: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var type: String?
    public var active: Bool?
    public var cached: Bool?
    public var provider: String?
    public var source: String?
    public var firstSeenAt: String?
    public var lastSeenAt: String?
    public var supportsVolume: Bool?
    public var volumePercent: Int?

    public init(
        id: String? = nil,
        name: String,
        type: String? = nil,
        active: Bool? = nil,
        cached: Bool? = nil,
        provider: String? = nil,
        source: String? = nil,
        firstSeenAt: String? = nil,
        lastSeenAt: String? = nil,
        supportsVolume: Bool? = nil,
        volumePercent: Int? = nil
    ) {
        self.id = id ?? name
        self.name = name
        self.type = type
        self.active = active
        self.cached = cached
        self.provider = provider
        self.source = source
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.supportsVolume = supportsVolume
        self.volumePercent = volumePercent
    }

    public init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(name: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeIfPresent(String.self, forKey: .id)
        let name = try container.decodeIfPresent(String.self, forKey: .name) ?? id ?? "Unknown"
        self.init(
            id: id,
            name: name,
            type: try container.decodeIfPresent(String.self, forKey: .type),
            active: try container.decodeIfPresent(Bool.self, forKey: .active)
                ?? container.decodeIfPresentIgnoringErrors(Bool.self, forKey: .isActive),
            cached: try container.decodeIfPresent(Bool.self, forKey: .cached),
            provider: try container.decodeIfPresent(String.self, forKey: .provider),
            source: try container.decodeIfPresent(String.self, forKey: .source),
            firstSeenAt: try container.decodeIfPresent(String.self, forKey: .firstSeenAt),
            lastSeenAt: try container.decodeIfPresent(String.self, forKey: .lastSeenAt),
            supportsVolume: try container.decodeIfPresent(Bool.self, forKey: .supportsVolume),
            volumePercent: try container.decodeIfPresent(Int.self, forKey: .volumePercent)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(active, forKey: .active)
        try container.encodeIfPresent(cached, forKey: .cached)
        try container.encodeIfPresent(provider, forKey: .provider)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(firstSeenAt, forKey: .firstSeenAt)
        try container.encodeIfPresent(lastSeenAt, forKey: .lastSeenAt)
        try container.encodeIfPresent(supportsVolume, forKey: .supportsVolume)
        try container.encodeIfPresent(volumePercent, forKey: .volumePercent)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case active
        case isActive = "is_active"
        case cached
        case provider
        case source
        case firstSeenAt = "first_seen_at"
        case lastSeenAt = "last_seen_at"
        case supportsVolume = "supports_volume"
        case volumePercent = "volume_percent"
    }

    public var isCachedSpotifyOutput: Bool {
        guard cached == true else {
            return false
        }
        return provider?.localizedCaseInsensitiveCompare("spotify") == .orderedSame
            || source?.localizedCaseInsensitiveCompare("spotify") == .orderedSame
    }

    public func matchesPlaybackDevice(id playbackID: String?, name playbackName: String?) -> Bool {
        let outputID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let outputName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let playbackID, !playbackID.isEmpty, outputID.localizedCaseInsensitiveCompare(playbackID) == .orderedSame {
            return true
        }
        if let playbackName, !playbackName.isEmpty, outputName.localizedCaseInsensitiveCompare(playbackName) == .orderedSame {
            return true
        }
        return false
    }
}

public struct DJConnectQueueItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var artist: String?
    public var album: String?
    public var uri: String?
    public var durationMS: Int?
    public var albumImageURL: URL?

    public var displayTitle: String {
        artist.map { "\(title) - \($0)" } ?? title
    }

    public var displaySubtitle: String? {
        let trimmedArtist = artist?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAlbum = album?.trimmingCharacters(in: .whitespacesAndNewlines)
        let artistValue = trimmedArtist?.isEmpty == false ? trimmedArtist : nil
        let albumValue = trimmedAlbum?.isEmpty == false ? trimmedAlbum : nil
        guard let artistValue else {
            return albumValue
        }
        guard let albumValue,
              albumValue.localizedCaseInsensitiveCompare(artistValue) != .orderedSame else {
            return artistValue
        }
        return "\(artistValue) • \(albumValue)"
    }

    public init(
        id: String? = nil,
        title: String,
        artist: String? = nil,
        album: String? = nil,
        uri: String? = nil,
        durationMS: Int? = nil,
        albumImageURL: URL? = nil
    ) {
        self.id = uri ?? id ?? title
        self.title = title
        self.artist = artist
        self.album = album
        self.uri = uri
        self.durationMS = durationMS
        self.albumImageURL = albumImageURL
    }

    public init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(title: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let uri = try container.decodeIfPresent(String.self, forKey: .uri)
        let id = try container.decodeIfPresent(String.self, forKey: .id)
        let decodedTitle = container.decodeStringAliasIfPresent(.title, .name, .displayTitle, .trackName)
        let title = decodedTitle ?? uri ?? id ?? "Unknown"
        let artist = container.decodeStringAliasIfPresent(.artist, .artistName, .artistNameCamel, .subtitle, .mediaArtist, .mediaArtistCamel, .artists)
        let album = container.decodeStringAliasIfPresent(.album, .albumName, .albumNameCamel, .mediaAlbum, .mediaAlbumCamel)
        let durationMS = try container.decodeIfPresent(Int.self, forKey: .durationMS)
        var albumImageURL = try container.decodeIfPresent(URL.self, forKey: .albumImageURL)
        if albumImageURL == nil {
            albumImageURL = container.decodeIfPresentIgnoringErrors(URL.self, forKey: .albumImageUrl)
        }
        if albumImageURL == nil {
            albumImageURL = container.decodeIfPresentIgnoringErrors(URL.self, forKey: .albumArtURL)
        }
        if albumImageURL == nil {
            albumImageURL = container.decodeIfPresentIgnoringErrors(URL.self, forKey: .albumArtUrl)
        }
        if albumImageURL == nil {
            albumImageURL = container.decodeIfPresentIgnoringErrors(URL.self, forKey: .mediaImageURL)
        }
        if albumImageURL == nil {
            albumImageURL = container.decodeIfPresentIgnoringErrors(URL.self, forKey: .mediaImageUrl)
        }
        if albumImageURL == nil {
            albumImageURL = container.decodeIfPresentIgnoringErrors(URL.self, forKey: .imageURL)
        }
        if albumImageURL == nil {
            albumImageURL = container.decodeIfPresentIgnoringErrors(URL.self, forKey: .imageUrl)
        }
        if albumImageURL == nil {
            albumImageURL = container.decodeIfPresentIgnoringErrors(URL.self, forKey: .thumbnailURL)
        }
        if albumImageURL == nil {
            albumImageURL = container.decodeIfPresentIgnoringErrors(URL.self, forKey: .entityPicture)
        }
        self.init(
            id: id,
            title: title,
            artist: artist,
            album: album,
            uri: uri,
            durationMS: durationMS,
            albumImageURL: albumImageURL
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(artist, forKey: .artist)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encodeIfPresent(uri, forKey: .uri)
        try container.encodeIfPresent(durationMS, forKey: .durationMS)
        try container.encodeIfPresent(albumImageURL, forKey: .albumImageURL)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case name
        case displayTitle = "display_title"
        case trackName = "track_name"
        case artist
        case artistName = "artist_name"
        case artistNameCamel = "artistName"
        case subtitle
        case mediaArtist = "media_artist"
        case mediaArtistCamel = "mediaArtist"
        case artists
        case album
        case albumName = "album_name"
        case albumNameCamel = "albumName"
        case mediaAlbum = "media_album"
        case mediaAlbumCamel = "mediaAlbum"
        case uri
        case durationMS = "duration_ms"
        case albumImageURL = "album_image_url"
        case albumImageUrl
        case albumArtURL = "album_art_url"
        case albumArtUrl
        case mediaImageURL = "media_image_url"
        case mediaImageUrl
        case imageURL = "image_url"
        case imageUrl
        case thumbnailURL = "thumbnail_url"
        case entityPicture = "entity_picture"
    }
}

private extension KeyedDecodingContainer where Key == DJConnectQueueItem.CodingKeys {
    func decodeStringAliasIfPresent(_ keys: Key...) -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                return value
            }
            if let values = try? decodeIfPresent([String].self, forKey: key), !values.isEmpty {
                return values.joined(separator: ", ")
            }
        }
        return nil
    }
}

public struct DJConnectQueueResponse: Codable, Equatable, Sendable {
    public var items: [DJConnectQueueItem]
    public var context: String?

    public init(items: [DJConnectQueueItem] = [], context: String? = nil) {
        self.items = items
        self.context = context
    }

    public init(from decoder: Decoder) throws {
        if let items = try? decoder.singleValueContainer().decode([DJConnectQueueItem].self) {
            self.init(items: items)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            items: try container.decodeIfPresent([DJConnectQueueItem].self, forKey: .items) ?? [],
            context: container.decodeStringAliasIfPresent(.context, .contextURI, .contextUri)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
        try container.encodeIfPresent(context, forKey: .context)
    }

    enum CodingKeys: String, CodingKey {
        case items
        case context
        case contextURI = "context_uri"
        case contextUri
    }
}

private extension KeyedDecodingContainer where Key == DJConnectQueueResponse.CodingKeys {
    func decodeStringAliasIfPresent(_ keys: Key...) -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key),
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }
}

public struct DJConnectPlaylist: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var uri: String?
    public var imageURL: URL?
    public var subtitle: String?

    public var commandValue: String {
        uri ?? id
    }

    public init(id: String? = nil, name: String, uri: String? = nil, imageURL: URL? = nil, subtitle: String? = nil) {
        self.id = id ?? uri ?? name
        self.name = name
        self.uri = uri
        self.imageURL = imageURL
        self.subtitle = subtitle
    }

    public init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(name: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let uri = container.decodeStringAliasIfPresent(.uri, .value, .playlistURI)
        let id = try container.decodeIfPresent(String.self, forKey: .id)
        guard let name = container.decodeStringAliasIfPresent(.name, .title, .displayTitle),
              !(uri ?? id ?? "").isEmpty else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Playlist item requires a title and a playable uri, id, value, or playlist_uri."
                )
            )
        }
        let imageURL = container.decodeURLAliasIfPresent(
            .imageURL,
            .imageUrl,
            .albumImageURL,
            .albumImageUrl,
            .albumArtURL,
            .albumArtUrl,
            .mediaImageURL,
            .mediaImageUrl,
            .thumbnailURL,
            .entityPicture,
            .artwork
        )
        let subtitle = container.decodeStringAliasIfPresent(
            .owner,
            .ownerName,
            .description,
            .artist,
            .artists,
            .subtitle,
            .album
        )
        self.init(
            id: id,
            name: name,
            uri: uri,
            imageURL: imageURL,
            subtitle: subtitle
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(uri, forKey: .uri)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case displayTitle = "display_title"
        case uri
        case value
        case playlistURI = "playlist_uri"
        case owner
        case ownerName = "owner_name"
        case description
        case artist
        case artists
        case subtitle
        case album
        case albumImageURL = "album_image_url"
        case albumImageUrl
        case albumArtURL = "album_art_url"
        case albumArtUrl
        case mediaImageURL = "media_image_url"
        case mediaImageUrl
        case imageURL = "image_url"
        case imageUrl
        case thumbnailURL = "thumbnail_url"
        case entityPicture = "entity_picture"
        case artwork
    }
}

private extension KeyedDecodingContainer where Key == DJConnectPlaylist.CodingKeys {
    func decodeStringAliasIfPresent(_ keys: Key...) -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                return value
            }
            if let values = try? decodeIfPresent([String].self, forKey: key), !values.isEmpty {
                return values.joined(separator: ", ")
            }
        }
        return nil
    }

    func decodeURLAliasIfPresent(_ keys: Key...) -> URL? {
        for key in keys {
            guard let rawValue = try? decodeIfPresent(String.self, forKey: key) else {
                continue
            }
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, let url = URL(string: value) else {
                continue
            }
            return url
        }
        return nil
    }
}

public struct DJConnectCommandResponse: Codable, Equatable, Sendable {
    public var success: Bool
    public var error: String?
    public var message: String?
    public var text: String?
    public var djText: String?
    public var assistantMessage: DJConnectAskDJHistoryMessage?
    public var images: [DJConnectResponseImage]?
    public var links: [DJConnectResponseLink]?
    public var sources: [DJConnectResponseLink]?
    public var items: [DJConnectAskDJHistoryItem]?
    public var audioURL: URL?
    public var announcement: DJAnnouncement?
    public var backendAvailable: Bool?
    public var haVersion: String?
    public var haMajorMinor: String?
    public var remoteSupported: Bool?
    public var musicBackend: String?
    public var musicBackendName: String?
    public var musicBackendAvailable: Bool?
    public var musicBackendRevision: Int?
    public var musicBackendCapabilities: DJConnectMusicBackendCapabilities?
    public var musicTargetPlayer: DJConnectMusicTargetPlayer?
    public var musicBackendError: String?
    public var playback: DJConnectPlayback?
    public var devices: [DJConnectOutputDevice]?
    public var queue: [DJConnectQueueItem]?
    public var queueContext: String?
    public var playlists: [DJConnectPlaylist]?
    public var playbackActions: [DJConnectAskDJPlaybackAction]?
    public var askDJClearRequired: Bool?
    public var pushSupported: Bool?
    public var pushRegistered: Bool?
    public var pushEnvironment: DJConnectPushEnvironment?
    public var lastPushError: String?
    public var bootstrapProof: String?
    public var bootstrapProofExpiresAt: String?
    public var haInstallID: String?
    public var integrationVersion: String?
    public var pairingSessionID: String?

    public var musicBackendSummary: DJConnectMusicBackendSummary {
        DJConnectMusicBackendSummary(
            musicBackend: musicBackend,
            musicBackendName: musicBackendName,
            musicBackendAvailable: musicBackendAvailable,
            musicBackendRevision: musicBackendRevision,
            musicBackendCapabilities: musicBackendCapabilities,
            musicTargetPlayer: musicTargetPlayer,
            musicBackendError: musicBackendError
        )
    }

    public init(
        success: Bool,
        error: String? = nil,
        message: String? = nil,
        text: String? = nil,
        djText: String? = nil,
        assistantMessage: DJConnectAskDJHistoryMessage? = nil,
        images: [DJConnectResponseImage]? = nil,
        links: [DJConnectResponseLink]? = nil,
        sources: [DJConnectResponseLink]? = nil,
        items: [DJConnectAskDJHistoryItem]? = nil,
        audioURL: URL? = nil,
        announcement: DJAnnouncement? = nil,
        backendAvailable: Bool? = nil,
        haVersion: String? = nil,
        haMajorMinor: String? = nil,
        remoteSupported: Bool? = nil,
        musicBackend: String? = nil,
        musicBackendName: String? = nil,
        musicBackendAvailable: Bool? = nil,
        musicBackendRevision: Int? = nil,
        musicBackendCapabilities: DJConnectMusicBackendCapabilities? = nil,
        musicTargetPlayer: DJConnectMusicTargetPlayer? = nil,
        musicBackendError: String? = nil,
        playback: DJConnectPlayback? = nil,
        devices: [DJConnectOutputDevice]? = nil,
        queue: [DJConnectQueueItem]? = nil,
        queueContext: String? = nil,
        playlists: [DJConnectPlaylist]? = nil,
        playbackActions: [DJConnectAskDJPlaybackAction]? = nil,
        askDJClearRequired: Bool? = nil,
        pushSupported: Bool? = nil,
        pushRegistered: Bool? = nil,
        pushEnvironment: DJConnectPushEnvironment? = nil,
        lastPushError: String? = nil,
        bootstrapProof: String? = nil,
        bootstrapProofExpiresAt: String? = nil,
        haInstallID: String? = nil,
        integrationVersion: String? = nil,
        pairingSessionID: String? = nil
    ) {
        self.success = success
        self.error = error
        self.message = message
        self.text = text
        self.djText = djText
        self.assistantMessage = assistantMessage
        self.images = images
        self.links = links
        self.sources = sources
        self.items = items
        self.announcement = announcement
        self.audioURL = announcement?.clientReplayAudioURL ?? audioURL
        self.backendAvailable = backendAvailable
        self.haVersion = haVersion
        self.haMajorMinor = haMajorMinor
        self.remoteSupported = remoteSupported
        self.musicBackend = musicBackend
        self.musicBackendName = musicBackendName
        self.musicBackendAvailable = musicBackendAvailable
        self.musicBackendRevision = musicBackendRevision
        self.musicBackendCapabilities = musicBackendCapabilities
        self.musicTargetPlayer = musicTargetPlayer
        self.musicBackendError = musicBackendError
        self.playback = playback
        self.devices = devices
        self.queue = queue
        self.queueContext = queueContext
        self.playlists = playlists
        self.playbackActions = playbackActions
        self.askDJClearRequired = askDJClearRequired
        self.pushSupported = pushSupported
        self.pushRegistered = pushRegistered
        self.pushEnvironment = pushEnvironment
        self.lastPushError = lastPushError
        self.bootstrapProof = bootstrapProof
        self.bootstrapProofExpiresAt = bootstrapProofExpiresAt
        self.haInstallID = haInstallID
        self.integrationVersion = integrationVersion
        self.pairingSessionID = pairingSessionID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        let result = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .result)

        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? true
        error = try container.decodeIfPresent(String.self, forKey: .error)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        text = try container.decodeIfPresent(String.self, forKey: .text)
            ?? data?.decodeIfPresentIgnoringErrors(String.self, forKey: .text)
            ?? result?.decodeIfPresentIgnoringErrors(String.self, forKey: .text)
        djText = try container.decodeIfPresent(String.self, forKey: .djText)
            ?? data?.decodeIfPresentIgnoringErrors(String.self, forKey: .djText)
            ?? result?.decodeIfPresentIgnoringErrors(String.self, forKey: .djText)
        assistantMessage = try container.decodeIfPresent(DJConnectAskDJHistoryMessage.self, forKey: .assistantMessage)
            ?? data?.decodeIfPresentIgnoringErrors(DJConnectAskDJHistoryMessage.self, forKey: .assistantMessage)
            ?? result?.decodeIfPresentIgnoringErrors(DJConnectAskDJHistoryMessage.self, forKey: .assistantMessage)
        images = container.decodeLossyArrayIfPresent(DJConnectResponseImage.self, forKey: .images)
            ?? data?.decodeLossyArrayIfPresent(DJConnectResponseImage.self, forKey: .images)
            ?? result?.decodeLossyArrayIfPresent(DJConnectResponseImage.self, forKey: .images)
        links = container.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .links)
            ?? data?.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .links)
            ?? result?.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .links)
        sources = container.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .sources)
            ?? data?.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .sources)
            ?? result?.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .sources)
        items = container.decodeLossyArrayIfPresent(DJConnectAskDJHistoryItem.self, forKey: .items)
            ?? data?.decodeLossyArrayIfPresent(DJConnectAskDJHistoryItem.self, forKey: .items)
            ?? result?.decodeLossyArrayIfPresent(DJConnectAskDJHistoryItem.self, forKey: .items)
        audioURL = Self.decodeAudioURL(from: container)
            ?? data.flatMap(Self.decodeAudioURL(from:))
            ?? result.flatMap(Self.decodeAudioURL(from:))
        announcement = (try container.decodeIfPresent(DJAnnouncement.self, forKey: .announcement))
            ?? data?.decodeIfPresentIgnoringErrors(DJAnnouncement.self, forKey: .announcement)
            ?? result?.decodeIfPresentIgnoringErrors(DJAnnouncement.self, forKey: .announcement)
        if let announcement {
            audioURL = announcement.clientReplayAudioURL
        }
        backendAvailable = try container.decodeIfPresent(Bool.self, forKey: .backendAvailable)
        askDJClearRequired = container.decodeBoolAliasIfPresent(.askDJClearRequired, .clearRequired)
            ?? data?.decodeBoolAliasIfPresent(.askDJClearRequired, .clearRequired)
            ?? result?.decodeBoolAliasIfPresent(.askDJClearRequired, .clearRequired)
        pushSupported = container.decodeBoolAliasIfPresent(.pushSupported)
            ?? data?.decodeBoolAliasIfPresent(.pushSupported)
            ?? result?.decodeBoolAliasIfPresent(.pushSupported)
        pushRegistered = container.decodeBoolAliasIfPresent(.pushRegistered)
            ?? data?.decodeBoolAliasIfPresent(.pushRegistered)
            ?? result?.decodeBoolAliasIfPresent(.pushRegistered)
        pushEnvironment = try container.decodeIfPresent(DJConnectPushEnvironment.self, forKey: .pushEnvironment)
            ?? data?.decodeIfPresentIgnoringErrors(DJConnectPushEnvironment.self, forKey: .pushEnvironment)
            ?? result?.decodeIfPresentIgnoringErrors(DJConnectPushEnvironment.self, forKey: .pushEnvironment)
        lastPushError = container.decodeStringAliasIfPresent(.lastPushError)
            ?? data?.decodeStringAliasIfPresent(.lastPushError)
            ?? result?.decodeStringAliasIfPresent(.lastPushError)
        bootstrapProof = container.decodeStringAliasIfPresent(.bootstrapProof)
            ?? data?.decodeStringAliasIfPresent(.bootstrapProof)
            ?? result?.decodeStringAliasIfPresent(.bootstrapProof)
        bootstrapProofExpiresAt = container.decodeStringAliasIfPresent(.bootstrapProofExpiresAt)
            ?? data?.decodeStringAliasIfPresent(.bootstrapProofExpiresAt)
            ?? result?.decodeStringAliasIfPresent(.bootstrapProofExpiresAt)
        haInstallID = container.decodeStringAliasIfPresent(.haInstallID)
            ?? data?.decodeStringAliasIfPresent(.haInstallID)
            ?? result?.decodeStringAliasIfPresent(.haInstallID)
        integrationVersion = container.decodeStringAliasIfPresent(.integrationVersion)
            ?? data?.decodeStringAliasIfPresent(.integrationVersion)
            ?? result?.decodeStringAliasIfPresent(.integrationVersion)
        pairingSessionID = container.decodeStringAliasIfPresent(.pairingSessionID)
            ?? data?.decodeStringAliasIfPresent(.pairingSessionID)
            ?? result?.decodeStringAliasIfPresent(.pairingSessionID)
        haVersion = container.decodeStringAliasIfPresent(.haVersion)
            ?? data?.decodeStringAliasIfPresent(.haVersion)
            ?? result?.decodeStringAliasIfPresent(.haVersion)
        haMajorMinor = container.decodeStringAliasIfPresent(.haMajorMinor)
            ?? data?.decodeStringAliasIfPresent(.haMajorMinor)
            ?? result?.decodeStringAliasIfPresent(.haMajorMinor)
        remoteSupported = try container.decodeIfPresent(Bool.self, forKey: .remoteSupported)
            ?? data?.decodeIfPresentIgnoringErrors(Bool.self, forKey: .remoteSupported)
            ?? result?.decodeIfPresentIgnoringErrors(Bool.self, forKey: .remoteSupported)
        musicBackend = container.decodeStringAliasIfPresent(.musicBackend)
            ?? data?.decodeStringAliasIfPresent(.musicBackend)
            ?? result?.decodeStringAliasIfPresent(.musicBackend)
        musicBackendName = container.decodeStringAliasIfPresent(.musicBackendName)
            ?? data?.decodeStringAliasIfPresent(.musicBackendName)
            ?? result?.decodeStringAliasIfPresent(.musicBackendName)
        musicBackendAvailable = try container.decodeIfPresent(Bool.self, forKey: .musicBackendAvailable)
            ?? data?.decodeIfPresentIgnoringErrors(Bool.self, forKey: .musicBackendAvailable)
            ?? result?.decodeIfPresentIgnoringErrors(Bool.self, forKey: .musicBackendAvailable)
        musicBackendRevision = try container.decodeIfPresent(Int.self, forKey: .musicBackendRevision)
            ?? data?.decodeIfPresentIgnoringErrors(Int.self, forKey: .musicBackendRevision)
            ?? result?.decodeIfPresentIgnoringErrors(Int.self, forKey: .musicBackendRevision)
        musicBackendCapabilities = try container.decodeIfPresent(DJConnectMusicBackendCapabilities.self, forKey: .musicBackendCapabilities)
            ?? data?.decodeIfPresentIgnoringErrors(DJConnectMusicBackendCapabilities.self, forKey: .musicBackendCapabilities)
            ?? result?.decodeIfPresentIgnoringErrors(DJConnectMusicBackendCapabilities.self, forKey: .musicBackendCapabilities)
        musicTargetPlayer = try container.decodeIfPresent(DJConnectMusicTargetPlayer.self, forKey: .musicTargetPlayer)
            ?? data?.decodeIfPresentIgnoringErrors(DJConnectMusicTargetPlayer.self, forKey: .musicTargetPlayer)
            ?? result?.decodeIfPresentIgnoringErrors(DJConnectMusicTargetPlayer.self, forKey: .musicTargetPlayer)
        musicBackendError = container.decodeMusicBackendErrorIfPresent(.musicBackendError)
            ?? data?.decodeMusicBackendErrorIfPresent(.musicBackendError)
            ?? result?.decodeMusicBackendErrorIfPresent(.musicBackendError)
        playback = try container.decodeIfPresent(DJConnectPlayback.self, forKey: .playback)
            ?? data?.decodeIfPresentIgnoringErrors(DJConnectPlayback.self, forKey: .playback)
            ?? result?.decodeIfPresentIgnoringErrors(DJConnectPlayback.self, forKey: .playback)
        var decodedDevices = container.decodeLossyArrayIfPresent(DJConnectOutputDevice.self, forKey: .devices)
        if decodedDevices == nil {
            decodedDevices = container.decodeLossyArrayIfPresent(DJConnectOutputDevice.self, forKey: .availableOutputs)
        }
        if decodedDevices == nil {
            decodedDevices = container.decodeLossyArrayIfPresent(DJConnectOutputDevice.self, forKey: .outputDevices)
        }
        if decodedDevices == nil {
            decodedDevices = container.decodeLossyArrayIfPresent(DJConnectOutputDevice.self, forKey: .outputs)
        }
        if decodedDevices == nil {
            decodedDevices = container.decodeOutputDeviceItemsIfPresent(forKey: .items)
        }
        if decodedDevices == nil {
            decodedDevices = data?.decodeLossyArrayIfPresent(DJConnectOutputDevice.self, forKey: .devices)
        }
        if decodedDevices == nil {
            decodedDevices = data?.decodeLossyArrayIfPresent(DJConnectOutputDevice.self, forKey: .availableOutputs)
        }
        if decodedDevices == nil {
            decodedDevices = data?.decodeLossyArrayIfPresent(DJConnectOutputDevice.self, forKey: .outputDevices)
        }
        if decodedDevices == nil {
            decodedDevices = data?.decodeLossyArrayIfPresent(DJConnectOutputDevice.self, forKey: .outputs)
        }
        if decodedDevices == nil {
            decodedDevices = data?.decodeOutputDeviceItemsIfPresent(forKey: .items)
        }
        if decodedDevices == nil {
            decodedDevices = result?.decodeLossyArrayIfPresent(DJConnectOutputDevice.self, forKey: .devices)
        }
        if decodedDevices == nil {
            decodedDevices = result?.decodeLossyArrayIfPresent(DJConnectOutputDevice.self, forKey: .availableOutputs)
        }
        if decodedDevices == nil {
            decodedDevices = result?.decodeLossyArrayIfPresent(DJConnectOutputDevice.self, forKey: .outputDevices)
        }
        if decodedDevices == nil {
            decodedDevices = result?.decodeLossyArrayIfPresent(DJConnectOutputDevice.self, forKey: .outputs)
        }
        if decodedDevices == nil {
            decodedDevices = result?.decodeOutputDeviceItemsIfPresent(forKey: .items)
        }
        devices = decodedDevices
        let queueResponse = try container.decodeIfPresent(DJConnectQueueResponse.self, forKey: .queue)
            ?? data?.decodeIfPresentIgnoringErrors(DJConnectQueueResponse.self, forKey: .queue)
            ?? result?.decodeIfPresentIgnoringErrors(DJConnectQueueResponse.self, forKey: .queue)
        queue = queueResponse?.items
            ?? container.decodeLossyArrayIfPresent(DJConnectQueueItem.self, forKey: .items)
            ?? data?.decodeIfPresentIgnoringErrors([DJConnectQueueItem].self, forKey: .items)
            ?? result?.decodeLossyArrayIfPresent(DJConnectQueueItem.self, forKey: .items)
        queueContext = queueResponse?.context
            ?? container.decodeStringAliasIfPresent(.queueContext, .contextURI, .contextUri)
            ?? data?.decodeStringAliasIfPresent(.queueContext, .contextURI, .contextUri)
            ?? result?.decodeStringAliasIfPresent(.queueContext, .contextURI, .contextUri)
        playlists = container.decodeLossyArrayIfPresent(DJConnectPlaylist.self, forKey: .playlists)
            ?? container.decodeLossyArrayIfPresent(DJConnectPlaylist.self, forKey: .items)
            ?? data?.decodeLossyArrayIfPresent(DJConnectPlaylist.self, forKey: .playlists)
            ?? data?.decodeLossyArrayIfPresent(DJConnectPlaylist.self, forKey: .items)
            ?? result?.decodeLossyArrayIfPresent(DJConnectPlaylist.self, forKey: .playlists)
            ?? result?.decodeLossyArrayIfPresent(DJConnectPlaylist.self, forKey: .items)
        if let decodedPlaylists = playlists {
            playlists = Array(decodedPlaylists.prefix(100))
        }
        playbackActions = container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .playbackActions)
            ?? data?.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .playbackActions)
            ?? result?.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .playbackActions)
        normalizeAskDJAssistantMessage()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(djText, forKey: .djText)
        try container.encodeIfPresent(assistantMessage, forKey: .assistantMessage)
        try container.encodeIfPresent(images, forKey: .images)
        try container.encodeIfPresent(links, forKey: .links)
        try container.encodeIfPresent(sources, forKey: .sources)
        try container.encodeIfPresent(items, forKey: .items)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encodeIfPresent(announcement, forKey: .announcement)
        try container.encodeIfPresent(backendAvailable, forKey: .backendAvailable)
        try container.encodeIfPresent(haVersion, forKey: .haVersion)
        try container.encodeIfPresent(haMajorMinor, forKey: .haMajorMinor)
        try container.encodeIfPresent(remoteSupported, forKey: .remoteSupported)
        try container.encodeIfPresent(musicBackend, forKey: .musicBackend)
        try container.encodeIfPresent(musicBackendName, forKey: .musicBackendName)
        try container.encodeIfPresent(musicBackendAvailable, forKey: .musicBackendAvailable)
        try container.encodeIfPresent(musicBackendRevision, forKey: .musicBackendRevision)
        try container.encodeIfPresent(musicBackendCapabilities, forKey: .musicBackendCapabilities)
        try container.encodeIfPresent(musicTargetPlayer, forKey: .musicTargetPlayer)
        try container.encodeIfPresent(musicBackendError, forKey: .musicBackendError)
        try container.encodeIfPresent(playback, forKey: .playback)
        try container.encodeIfPresent(devices, forKey: .devices)
        try container.encodeIfPresent(queue, forKey: .queue)
        try container.encodeIfPresent(queueContext, forKey: .queueContext)
        try container.encodeIfPresent(playlists, forKey: .playlists)
        try container.encodeIfPresent(playbackActions, forKey: .playbackActions)
        try container.encodeIfPresent(askDJClearRequired, forKey: .askDJClearRequired)
        try container.encodeIfPresent(pushSupported, forKey: .pushSupported)
        try container.encodeIfPresent(pushRegistered, forKey: .pushRegistered)
        try container.encodeIfPresent(pushEnvironment, forKey: .pushEnvironment)
        try container.encodeIfPresent(lastPushError, forKey: .lastPushError)
        try container.encodeIfPresent(bootstrapProof, forKey: .bootstrapProof)
        try container.encodeIfPresent(bootstrapProofExpiresAt, forKey: .bootstrapProofExpiresAt)
        try container.encodeIfPresent(haInstallID, forKey: .haInstallID)
        try container.encodeIfPresent(integrationVersion, forKey: .integrationVersion)
        try container.encodeIfPresent(pairingSessionID, forKey: .pairingSessionID)
    }

    private mutating func normalizeAskDJAssistantMessage() {
        let topLevelAnnouncement = announcement
        let topLevelAudioURL = topLevelAnnouncement?.clientReplayAudioURL ?? audioURL
        let topLevelImages = images ?? []
        let topLevelLinks = links ?? []
        let topLevelSources = sources ?? []
        let topLevelItems = items ?? []
        let topLevelPlaybackActions = playbackActions ?? []
        let fallbackText = trimmedNonEmpty(assistantMessage?.text)
            ?? trimmedNonEmpty(djText)
            ?? trimmedNonEmpty(text)
            ?? trimmedNonEmpty(message)

        if assistantMessage == nil, let fallbackText {
            assistantMessage = DJConnectAskDJHistoryMessage(
                id: UUID().uuidString,
                role: .assistant,
                origin: "play_now",
                text: fallbackText,
                createdAt: Date(),
                images: topLevelImages,
                links: topLevelLinks + topLevelSources,
                sources: topLevelSources,
                audioURL: topLevelAudioURL,
                announcement: topLevelAnnouncement,
                playbackActions: topLevelPlaybackActions,
                items: topLevelItems
            )
        }

        guard assistantMessage != nil else {
            return
        }
        if let fallbackText, trimmedNonEmpty(assistantMessage?.text) == nil {
            assistantMessage?.text = fallbackText
        }
        if assistantMessage?.announcement == nil, let topLevelAnnouncement {
            assistantMessage?.announcement = topLevelAnnouncement
            assistantMessage?.audioURL = topLevelAnnouncement.clientReplayAudioURL
        } else if assistantMessage?.audioURL == nil {
            assistantMessage?.audioURL = topLevelAudioURL
        }
        if assistantMessage?.origin == nil {
            assistantMessage?.origin = "play_now"
        }
        if assistantMessage?.images.isEmpty != false, !topLevelImages.isEmpty {
            assistantMessage?.images = topLevelImages
        }
        if assistantMessage?.links.isEmpty != false {
            assistantMessage?.links = topLevelLinks + topLevelSources
            assistantMessage?.sources = topLevelSources
        } else if assistantMessage?.sources.isEmpty != false, !topLevelSources.isEmpty {
            assistantMessage?.sources = topLevelSources
        }
        if assistantMessage?.items.isEmpty != false, !topLevelItems.isEmpty {
            assistantMessage?.items = topLevelItems
        }
    }

    private func trimmedNonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private static func decodeAudioURL(from container: KeyedDecodingContainer<CodingKeys>) -> URL? {
        (try? container.decodeIfPresent(URL.self, forKey: .audioURL))
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .audioUrl)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .responseAudioURL)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .responseAudioUrl)
    }

    enum CodingKeys: String, CodingKey {
        case success
        case error
        case message
        case text
        case djText = "dj_text"
        case assistantMessage = "assistant_message"
        case images
        case links
        case sources
        case items
        case announcement
        case audioURL = "audio_url"
        case audioUrl
        case responseAudioURL = "response_audio_url"
        case responseAudioUrl
        case backendAvailable = "backend_available"
        case haVersion = "ha_version"
        case haMajorMinor = "ha_major_minor"
        case remoteSupported = "remote_supported"
        case musicBackend = "music_backend"
        case musicBackendName = "music_backend_name"
        case musicBackendAvailable = "music_backend_available"
        case musicBackendRevision = "music_backend_revision"
        case musicBackendCapabilities = "music_backend_capabilities"
        case musicTargetPlayer = "music_target_player"
        case musicBackendError = "music_backend_error"
        case playback
        case data
        case result
        case devices
        case availableOutputs = "available_outputs"
        case outputDevices = "output_devices"
        case outputs
        case queue
        case queueContext = "queue_context"
        case contextURI = "context_uri"
        case contextUri
        case playlists
        case playbackActions = "playback_actions"
        case askDJClearRequired = "ask_dj_clear_required"
        case clearRequired = "clear_required"
        case pushSupported = "push_supported"
        case pushRegistered = "push_registered"
        case pushEnvironment = "push_environment"
        case lastPushError = "last_push_error"
        case bootstrapProof = "bootstrap_proof"
        case bootstrapProofExpiresAt = "bootstrap_proof_expires_at"
        case haInstallID = "ha_install_id"
        case integrationVersion = "integration_version"
        case pairingSessionID = "pairing_session_id"
    }
}

private extension KeyedDecodingContainer where Key == DJConnectCommandResponse.CodingKeys {
    func decodeBoolAliasIfPresent(_ keys: Key...) -> Bool? {
        for key in keys {
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
        }
        return nil
    }

    func decodeStringAliasIfPresent(_ keys: Key...) -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    func decodeMusicBackendErrorIfPresent(_ keys: Key...) -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                return value
            }
            if let value = try? decodeIfPresent(DJConnectMusicBackendErrorPayload.self, forKey: key) {
                if let message = value.message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                    return message
                }
                if let code = value.code?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty {
                    return code
                }
            }
        }
        return nil
    }

    func decodeOutputDeviceItemsIfPresent(forKey key: Key) -> [DJConnectOutputDevice]? {
        guard let items = decodeLossyArrayIfPresent(DJConnectOutputDeviceCandidate.self, forKey: key) else {
            return nil
        }
        let devices = items.compactMap(\.outputDevice)
        return devices.isEmpty ? nil : devices
    }
}

private struct DJConnectOutputDeviceCandidate: Decodable {
    var outputDevice: DJConnectOutputDevice?

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            outputDevice = DJConnectOutputDevice(name: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let uri = try container.decodeIfPresent(String.self, forKey: .uri)
            ?? container.decodeIfPresent(String.self, forKey: .playlistURI)
            ?? container.decodeIfPresent(String.self, forKey: .contextURI)
        if uri?.hasPrefix("spotify:") == true {
            outputDevice = nil
            return
        }

        let type = try container.decodeIfPresent(String.self, forKey: .type)
        let active = try container.decodeIfPresent(Bool.self, forKey: .active)
            ?? container.decodeIfPresent(Bool.self, forKey: .isActive)
        let cached = try container.decodeIfPresent(Bool.self, forKey: .cached)
        let provider = try container.decodeIfPresent(String.self, forKey: .provider)
        let source = try container.decodeIfPresent(String.self, forKey: .source)
        let firstSeenAt = try container.decodeIfPresent(String.self, forKey: .firstSeenAt)
        let lastSeenAt = try container.decodeIfPresent(String.self, forKey: .lastSeenAt)
        let supportsVolume = try container.decodeIfPresent(Bool.self, forKey: .supportsVolume)
        let volumePercent = try container.decodeIfPresent(Int.self, forKey: .volumePercent)
        let hasOutputShape = type != nil
            || active != nil
            || cached != nil
            || provider != nil
            || source != nil
            || firstSeenAt != nil
            || lastSeenAt != nil
            || supportsVolume != nil
            || volumePercent != nil
        guard hasOutputShape else {
            outputDevice = nil
            return
        }

        outputDevice = try DJConnectOutputDevice(from: decoder)
    }

    enum CodingKeys: String, CodingKey {
        case uri
        case playlistURI = "playlist_uri"
        case contextURI = "context_uri"
        case type
        case active
        case isActive = "is_active"
        case cached
        case provider
        case source
        case firstSeenAt = "first_seen_at"
        case lastSeenAt = "last_seen_at"
        case supportsVolume = "supports_volume"
        case volumePercent = "volume_percent"
    }
}

public struct DJConnectVoiceResponse: Codable, Equatable, Sendable {
    public var success: Bool
    public var text: String?
    public var djText: String?
    public var audioURL: URL?
    public var audioType: String?
    public var images: [DJConnectResponseImage]?
    public var links: [DJConnectResponseLink]?
    public var playbackActions: [DJConnectAskDJPlaybackAction]?

    enum CodingKeys: String, CodingKey {
        case success
        case text
        case djText = "dj_text"
        case audioURL = "audio_url"
        case audioUrl
        case responseAudioURL = "response_audio_url"
        case responseAudioUrl
        case mediaURL = "media_url"
        case mediaUrl
        case audioType = "audio_type"
        case images
        case links
        case playbackActions = "playback_actions"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? true
        text = try container.decodeIfPresent(String.self, forKey: .text)
        djText = try container.decodeIfPresent(String.self, forKey: .djText)
        audioURL = try container.decodeIfPresent(URL.self, forKey: .audioURL)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .audioUrl)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .responseAudioURL)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .responseAudioUrl)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .mediaURL)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .mediaUrl)
        audioType = try container.decodeIfPresent(String.self, forKey: .audioType)
        images = container.decodeLossyArrayIfPresent(DJConnectResponseImage.self, forKey: .images)
        links = container.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .links)
        playbackActions = container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .playbackActions)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(djText, forKey: .djText)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encodeIfPresent(audioType, forKey: .audioType)
        try container.encodeIfPresent(images, forKey: .images)
        try container.encodeIfPresent(links, forKey: .links)
        try container.encodeIfPresent(playbackActions, forKey: .playbackActions)
    }
}

private struct DJConnectMusicBackendErrorPayload: Codable, Equatable, Sendable {
    var code: String?
    var message: String?
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension KeyedDecodingContainer {
    func decodeIfPresentIgnoringErrors<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        try? decodeIfPresent(type, forKey: key)
    }

    func decodeLossyArrayIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) -> [T]? {
        guard contains(key), var container = try? nestedUnkeyedContainer(forKey: key) else {
            return nil
        }
        var values: [T] = []
        while !container.isAtEnd {
            if let value = try? container.decode(T.self) {
                values.append(value)
            } else {
                _ = try? container.decode(DiscardedDecodable.self)
            }
        }
        return values
    }
}

private struct DiscardedDecodable: Decodable {}
