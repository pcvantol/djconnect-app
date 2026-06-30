import Foundation

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
    case askDJHistory = "ask_dj_history"
    case clearAskDJHistory = "clear_ask_dj_history"
    case askDJIdleSuggestion = "ask_dj_idle_suggestion"
    case musicDNAProfile = "music_dna_profile"
    case musicDNASettings = "music_dna_settings"
    case clearMusicDNA = "clear_music_dna"
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

    public init(wavData: Data, mood: Int? = nil, djStyle: String? = nil, musicDNAKey: String? = nil) {
        self.wavData = wavData
        self.mood = mood
        self.djStyle = djStyle
        self.musicDNAKey = musicDNAKey
    }
}

public enum DJConnectPushEnvironment: String, Codable, Sendable {
    case sandbox
    case production
}

public enum DJConnectPairingStatus: String, Codable, Sendable {
    case unpaired
    case pairing
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
    public var platform: DJConnectPlatform

    public init(
        clientName: String? = nil,
        deviceID: String,
        deviceName: String,
        clientType: DJConnectClientType,
        firmware: String,
        appVersion: String? = nil,
        platform: DJConnectPlatform
    ) {
        self.clientName = clientName ?? deviceName
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.clientType = clientType
        self.firmware = firmware
        self.appVersion = appVersion
        self.platform = platform
    }

    enum CodingKeys: String, CodingKey {
        case clientName = "client_name"
        case deviceID = "device_id"
        case deviceName = "device_name"
        case clientType = "client_type"
        case firmware
        case appVersion = "app_version"
        case platform
    }
}

public struct DJConnectPairingPayload: Codable, Equatable, Sendable {
    public var deviceID: String
    public var deviceName: String
    public var clientType: DJConnectClientType
    public var firmware: String
    public var appVersion: String?
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
    public var homeAssistantURL: String
    public var pairCode: String
    public var clientType: DJConnectClientType
    public var pairPath: String

    public init(
        homeAssistantURL: String,
        pairCode: String,
        clientType: DJConnectClientType,
        pairPath: String = "/api/djconnect/pair"
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
        guard let rawHAURL = items["ha_url"], let haURL = URL(string: rawHAURL), let scheme = haURL.scheme?.lowercased(), scheme == "http", haURL.host?.isEmpty == false else {
            throw DJConnectError.invalidConfiguration("Missing or invalid local Home Assistant URL.")
        }
        guard let pairCode = items["pair_code"], pairCode.count == 6, pairCode.allSatisfy(\.isNumber) else {
            throw DJConnectError.invalidConfiguration("Missing or invalid 6-digit pair code.")
        }
        guard let rawClientType = items["client_type"], let clientType = DJConnectClientType(rawValue: rawClientType), clientType == expectedClientType else {
            throw DJConnectError.invalidConfiguration("Invalid DJConnect client type.")
        }
        guard items["pair_path"] == "/api/djconnect/pair" else {
            throw DJConnectError.invalidConfiguration("Invalid DJConnect pair path.")
        }
        return DJConnectPairingDeepLink(
            homeAssistantURL: rawHAURL,
            pairCode: pairCode,
            clientType: clientType,
            pairPath: "/api/djconnect/pair"
        )
    }
}

public struct DJConnectPairingResponse: Codable, Equatable, Sendable {
    public var success: Bool
    public var deviceToken: String?
    public var token: String?
    public var bearerToken: String?
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
        askDJSupported: Bool? = nil,
        askDJVoiceSupported: Bool? = nil,
        askDJAudioResponseSupported: Bool? = nil
    ) {
        self.success = success
        self.deviceToken = deviceToken
        self.token = token
        self.bearerToken = bearerToken
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
        self.askDJSupported = askDJSupported
        self.askDJVoiceSupported = askDJVoiceSupported
        self.askDJAudioResponseSupported = askDJAudioResponseSupported
    }

    enum CodingKeys: String, CodingKey {
        case success
        case deviceToken = "device_token"
        case token
        case bearerToken = "bearer_token"
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
        case askDJSupported = "ask_dj_supported"
        case askDJVoiceSupported = "ask_dj_voice_supported"
        case askDJAudioResponseSupported = "ask_dj_audio_response_supported"
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

public struct DJConnectCommandPayload: Codable, Equatable, Sendable {
    public var deviceID: String
    public var deviceName: String
    public var clientType: DJConnectClientType
    public var clientID: String
    public var command: String
    public var value: DJConnectCommandValue?
    public var play: Bool?
    public var limit: Int?
    public var musicBackendRevision: Int?

    public init(
        identity: DJConnectIdentity,
        command: String,
        value: DJConnectCommandValue? = nil,
        play: Bool? = nil,
        limit: Int? = nil,
        musicBackendRevision: Int? = nil
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
    }
}

public struct DJConnectAskDJRequest: Codable, Equatable, Sendable {
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
    public var metadata: [String: String]?

    public init(
        identity: DJConnectIdentity,
        text: String,
        clientMessageID: String? = nil,
        inputType: String? = nil,
        mood: Int? = nil,
        djStyle: String? = nil,
        musicDNAKey: String? = nil,
        audioResponse: AudioResponse? = nil,
        metadata: [String: String]? = nil
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
        self.metadata = metadata
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
        case metadata
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
    public var bpm: Double?
    public var key: String?
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
        bpm: Double? = nil,
        key: String? = nil,
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
        self.bpm = bpm
        self.key = key
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
    public var bpm: Int?
    public var key: String?
    public var energy: Double?
    public var danceability: Double?
    public var intensity: Double?
    public var musicDNAMatchPercent: Int?
    public var summary: String

    public init(
        updatedAt: Date = Date(),
        title: String,
        artist: String,
        genre: String? = nil,
        mood: String? = nil,
        vibe: String? = nil,
        bpm: Int? = nil,
        key: String? = nil,
        energy: Double? = nil,
        danceability: Double? = nil,
        intensity: Double? = nil,
        musicDNAMatchPercent: Int? = nil,
        summary: String
    ) {
        self.updatedAt = updatedAt
        self.title = Self.sanitizedPublic(title, maxLength: 96) ?? ""
        self.artist = Self.sanitizedPublic(artist, maxLength: 96) ?? ""
        self.genre = Self.sanitizedPublic(genre, maxLength: 48)
        self.mood = Self.sanitizedPublic(mood, maxLength: 48)
        self.vibe = Self.sanitizedPublic(vibe, maxLength: 48)
        self.bpm = bpm.map { max(0, min(320, $0)) }
        self.key = Self.sanitizedPublic(key, maxLength: 32)
        self.energy = Self.normalizedMetric(energy)
        self.danceability = Self.normalizedMetric(danceability)
        self.intensity = Self.normalizedMetric(intensity)
        self.musicDNAMatchPercent = musicDNAMatchPercent.map { max(0, min(100, $0)) }
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
            bpm: insight.bpm.map { Int($0.rounded()) },
            key: insight.key,
            energy: insight.energy,
            danceability: insight.danceability,
            intensity: insight.intensity,
            musicDNAMatchPercent: insight.musicDNAMatchPercent,
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
        let musicDNA = payload.musicDNA
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
            bpm: analysis?.bpm ?? payload.bpm,
            key: analysis?.key ?? payload.key,
            genre: analysis?.genre ?? payload.genre,
            subgenre: analysis?.subgenre,
            energy: normalizedMetric(analysis?.energy ?? payload.energy),
            danceability: normalizedMetric(analysis?.danceability ?? payload.danceability),
            intensity: normalizedMetric(analysis?.intensity ?? payload.intensity),
            mood: analysis?.mood ?? payload.mood,
            vibe: analysis?.vibe ?? payload.vibe,
            texture: analysis?.texture ?? payload.texture,
            emotionalTone: analysis?.emotionalTone,
            confidence: normalizedMetric(analysis?.confidence ?? payload.confidence),
            summary: analysis?.summary ?? payload.summary ?? "Track Insight is ready.",
            rawAnalysisText: analysis?.fullText ?? payload.rawAnalysisText ?? rawText,
            productionNotes: analysis?.productionNotes ?? [],
            instrumentation: analysis?.instrumentation ?? [],
            arrangementNotes: analysis?.arrangementNotes ?? [],
            listeningCues: analysis?.listeningCues ?? [],
            similarTracks: analysis?.similarTracks ?? [],
            musicDNAMatchPercent: musicDNA?.matchPercent,
            musicDNALabel: musicDNA?.label,
            musicDNASummary: musicDNA?.summary,
            visualProfile: payload.visualProfile,
            sections: payload.sections
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
    var bpm: Double?
    var key: String?
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
    var sections: [TrackInsightSection]

    struct Track: Codable {
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

        enum CodingKeys: String, CodingKey {
            case title
            case artist
            case album
            case artworkURL = "artwork_url"
            case durationMS = "duration_ms"
            case progressMS = "progress_ms"
            case isPlaying = "is_playing"
            case playerID = "player_id"
            case entityID = "entity_id"
            case backend
        }
    }

    struct Analysis: Codable {
        var summary: String?
        var fullText: String?
        var bpm: Double?
        var key: String?
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
        var productionNotes: [String]
        var instrumentation: [String]
        var arrangementNotes: [String]
        var listeningCues: [String]
        var similarTracks: [TrackInsightSimilarTrack]

        enum CodingKeys: String, CodingKey {
            case summary
            case fullText = "full_text"
            case bpm
            case key
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
            bpm = try container.decodeIfPresent(Double.self, forKey: .bpm)
            key = try container.decodeIfPresent(String.self, forKey: .key)
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
            productionNotes = try container.decodeIfPresent([String].self, forKey: .productionNotes) ?? []
            instrumentation = try container.decodeIfPresent([String].self, forKey: .instrumentation) ?? []
            arrangementNotes = try container.decodeIfPresent([String].self, forKey: .arrangementNotes) ?? []
            listeningCues = try container.decodeIfPresent([String].self, forKey: .listeningCues) ?? []
            similarTracks = try container.decodeIfPresent([TrackInsightSimilarTrack].self, forKey: .similarTracks) ?? []
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
        case bpm
        case key
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
        bpm = try container.decodeIfPresent(Double.self, forKey: .bpm)
        key = try container.decodeIfPresent(String.self, forKey: .key)
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

public struct DJConnectTrackInsightRequest: Codable, Equatable, Sendable {
    public var title: String?
    public var artist: String?
    public var album: String?
    public var entityID: String?
    public var playerID: String?
    public var musicBackend: String?
    public var forceRefresh: Bool
    public var locale: String?
    public var includeVisualProfile: Bool
    public var includeRawResponse: Bool

    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        entityID: String? = nil,
        playerID: String? = nil,
        musicBackend: String? = nil,
        forceRefresh: Bool = false,
        locale: String? = nil,
        includeVisualProfile: Bool = true,
        includeRawResponse: Bool = true
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.entityID = entityID
        self.playerID = playerID
        self.musicBackend = musicBackend
        self.forceRefresh = forceRefresh
        self.locale = locale
        self.includeVisualProfile = includeVisualProfile
        self.includeRawResponse = includeRawResponse
    }

    enum CodingKeys: String, CodingKey {
        case title
        case artist
        case album
        case entityID = "entity_id"
        case playerID = "player_id"
        case musicBackend = "music_backend"
        case forceRefresh = "force_refresh"
        case locale
        case includeVisualProfile = "include_visual_profile"
        case includeRawResponse = "include_raw_response"
    }
}

public struct TrackInsightEndpointResponse: Decodable, Sendable {
    public var success: Bool?
    public var error: String?
    public var message: String?
    private var trackInsightPayload: TrackInsightPayload?

    public var trackInsightValue: TrackInsight? {
        if let trackInsightPayload {
            return TrackInsightParser.makeInsight(from: trackInsightPayload, rawText: "", fallbackTitle: nil, fallbackArtist: nil, fallbackArtwork: nil)
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case success
        case error
        case message
        case trackInsight = "track_insight"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        trackInsightPayload = try container.decodeIfPresent(TrackInsightPayload.self, forKey: .trackInsight)
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
        TrackInsight(title: "Midnight City", artist: "M83", album: "Hurry Up, We're Dreaming", bpm: 105, key: "B minor", genre: "Synthpop", energy: 0.76, danceability: 0.66, intensity: 0.72, mood: "Nostalgic", vibe: "Nocturnal", texture: "Neon synth leads and gated drums", confidenceLabel: "demo", summary: "A glowing night-drive anthem with a bright synth hook, wide pads and a cinematic rush.", rawAnalysisText: "Demo Track Insight for Midnight City."),
        TrackInsight(title: "Sweet Disposition", artist: "The Temper Trap", album: "Conditions", bpm: 129, key: "D major", genre: "Indie rock", energy: 0.82, danceability: 0.58, intensity: 0.76, mood: "Uplifting", vibe: "Anthemic", texture: "Chiming guitars and open-air vocal lift", confidenceLabel: "demo", summary: "An expansive indie build that feels weightless, optimistic and made for big emotional release.", rawAnalysisText: "Demo Track Insight for Sweet Disposition."),
        TrackInsight(title: "Electric Feel", artist: "MGMT", album: "Oracular Spectacular", bpm: 103, key: "A minor", genre: "Psychedelic pop", energy: 0.70, danceability: 0.86, intensity: 0.54, mood: "Playful", vibe: "Funky", texture: "Rubbery bass, loose percussion and shimmering synth color", confidenceLabel: "demo", summary: "A sly psychedelic groove with elastic bass, playful motion and a warm electric shimmer.", rawAnalysisText: "Demo Track Insight for Electric Feel."),
        TrackInsight(title: "Innerbloom", artist: "RUFUS DU SOL", album: "Bloom", bpm: 122, key: "D minor", genre: "Melodic house", energy: 0.64, danceability: 0.62, intensity: 0.70, mood: "Dreamy", vibe: "Expansive", texture: "Wide pads and patient percussion", confidenceLabel: "demo", summary: "A slow-blooming electronic piece where restraint makes the emotional release feel huge.", rawAnalysisText: "Demo Track Insight for Innerbloom."),
        TrackInsight(title: "Strobe", artist: "deadmau5", album: "For Lack of a Better Name", bpm: 128, key: "C# minor", genre: "Progressive house", energy: 0.78, danceability: 0.66, intensity: 0.82, mood: "Dreamy", vibe: "Euphoric", texture: "Arpeggiated synths and long-build dynamics", confidenceLabel: "demo", summary: "A progressive build that turns repetition into anticipation and payoff.", rawAnalysisText: "Demo Track Insight for Strobe."),
        TrackInsight(title: "Sun & Moon", artist: "Above & Beyond", bpm: 132, key: "A major", genre: "Trance", energy: 0.86, danceability: 0.72, intensity: 0.84, mood: "Energetic", vibe: "Anthemic", texture: "Bright supersaws and vocal lift", confidenceLabel: "demo", summary: "A peak-time anthem shaped around lift, release and communal emotion.", rawAnalysisText: "Demo Track Insight for Above & Beyond."),
        TrackInsight(title: "Beyond Beliefs", artist: "Ben Bohmer", bpm: 123, key: "F minor", genre: "Melodic techno", energy: 0.58, danceability: 0.60, intensity: 0.52, mood: "Organic", vibe: "Warm", texture: "Soft plucks and rounded low end", confidenceLabel: "demo", summary: "A warm melodic groove that feels detailed without overcrowding the mix.", rawAnalysisText: "Demo Track Insight for Ben Bohmer."),
        TrackInsight(title: "Marea", artist: "Fred again..", bpm: 126, key: "G minor", genre: "House", energy: 0.80, danceability: 0.88, intensity: 0.72, mood: "Energetic", vibe: "Human", texture: "Vocal chops and kinetic drums", confidenceLabel: "demo", summary: "A club record with an intimate human center, built from voice, rhythm and momentum.", rawAnalysisText: "Demo Track Insight for Fred again."),
        TrackInsight(title: "Hey Now", artist: "London Grammar", bpm: 120, key: "E minor", genre: "Electronic pop", energy: 0.46, danceability: 0.40, intensity: 0.62, mood: "Dark", vibe: "Haunting", texture: "Sparse percussion and spacious vocal reverb", confidenceLabel: "demo", summary: "A spacious, shadowed production where silence frames the vocal emotion.", rawAnalysisText: "Demo Track Insight for London Grammar."),
        TrackInsight(title: "Giorgio by Moroder", artist: "Daft Punk", bpm: 113, key: "A minor", genre: "Disco", energy: 0.76, danceability: 0.78, intensity: 0.74, mood: "Organic", vibe: "Cinematic", texture: "Live bass, synth layers and narrative arc", confidenceLabel: "demo", summary: "A history lesson disguised as a groove, expanding from spoken memory into full-band motion.", rawAnalysisText: "Demo Track Insight for Daft Punk."),
        TrackInsight(title: "Sultans of Swing", artist: "Dire Straits", bpm: 149, key: "D minor", genre: "Rock", energy: 0.65, danceability: 0.56, intensity: 0.58, mood: "Organic", vibe: "Loose", texture: "Clean guitar phrasing and dry rhythmic pocket", confidenceLabel: "demo", summary: "A guitar-led track whose character lives in touch, timing and conversational phrasing.", rawAnalysisText: "Demo Track Insight for Dire Straits."),
        TrackInsight(title: "Master of Puppets", artist: "Metallica", bpm: 220, key: "E minor", genre: "Metal", energy: 0.96, danceability: 0.42, intensity: 0.98, mood: "Dark", vibe: "Aggressive", texture: "Palm-muted riffs and sharp rhythmic attacks", confidenceLabel: "demo", summary: "A high-intensity metal architecture built from precision, contrast and relentless forward drive.", rawAnalysisText: "Demo Track Insight for Metallica."),
        TrackInsight(title: "Adagio for Strings", artist: "Samuel Barber", bpm: 72, key: "B-flat minor", genre: "Classical", energy: 0.32, danceability: 0.10, intensity: 0.68, mood: "Dreamy", vibe: "Lamenting", texture: "Slow string suspensions and rising harmonic pressure", confidenceLabel: "demo", summary: "A patient orchestral ascent where tension comes from harmony, breath and restraint.", rawAnalysisText: "Demo Track Insight for orchestral music.")
    ]
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

public struct DJConnectAskDJHistoryMessage: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var clientMessageID: String?
    public var exchangeID: String?
    public var exchangeOrder: Int?
    public var role: DJConnectAskDJHistoryRole
    public var messageKind: DJConnectAskDJMessageKind
    public var origin: String?
    public var text: String
    public var createdAt: Date
    public var clientID: String?
    public var clientType: DJConnectClientType?
    public var status: String?
    public var images: [DJConnectResponseImage]
    public var links: [DJConnectResponseLink]
    public var sources: [DJConnectResponseLink]
    public var audioURL: URL?
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
        case playbackActions = "playback_actions"
        case confirmationActions = "confirmation_actions"
        case recommendationActions = "recommendation_actions"
        case recommendations
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
        text: String,
        createdAt: Date,
        clientID: String? = nil,
        clientType: DJConnectClientType? = nil,
        status: String? = nil,
        images: [DJConnectResponseImage] = [],
        links: [DJConnectResponseLink] = [],
        sources: [DJConnectResponseLink] = [],
        audioURL: URL? = nil,
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
        self.text = text
        self.createdAt = createdAt
        self.clientID = clientID
        self.clientType = clientType
        self.status = status
        self.images = images
        self.links = links
        self.sources = sources
        self.audioURL = audioURL
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
        playbackActions = container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .playbackActions)
            ?? container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .recommendationActions)
            ?? container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .recommendations)
            ?? []
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
        try container.encode(text, forKey: .text)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(clientID, forKey: .clientID)
        try container.encodeIfPresent(clientType, forKey: .clientType)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encode(images, forKey: .images)
        try container.encode(links, forKey: .links)
        try container.encode(sources, forKey: .sources)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encode(playbackActions, forKey: .playbackActions)
        try container.encode(confirmationActions, forKey: .confirmationActions)
        try container.encodeIfPresent(intentInfo, forKey: .intentInfo)
        try container.encodeIfPresent(trackInsight, forKey: .trackInsight)
        try container.encode(items, forKey: .items)
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
    public var userID: String?
    public var historyRevision: Int
    public var clearRevision: Int
    public var messages: [DJConnectAskDJHistoryMessage]
    public var serverTime: Date?
    public var historyLimit: Int?
    public var historyTrimmedBefore: Date?
    public var historyTrimmedCount: Int?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case historyRevision = "history_revision"
        case clearRevision = "clear_revision"
        case messages
        case serverTime = "server_time"
        case historyLimit = "history_limit"
        case historyTrimmedBefore = "history_trimmed_before"
        case historyTrimmedCount = "history_trimmed_count"
    }

    public init(
        userID: String? = nil,
        historyRevision: Int = 0,
        clearRevision: Int = 0,
        messages: [DJConnectAskDJHistoryMessage] = [],
        serverTime: Date? = nil,
        historyLimit: Int? = nil,
        historyTrimmedBefore: Date? = nil,
        historyTrimmedCount: Int? = nil
    ) {
        self.userID = userID
        self.historyRevision = historyRevision
        self.clearRevision = clearRevision
        self.messages = messages
        self.serverTime = serverTime
        self.historyLimit = historyLimit
        self.historyTrimmedBefore = historyTrimmedBefore
        self.historyTrimmedCount = historyTrimmedCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decodeIfPresent(String.self, forKey: .userID)
        historyRevision = try container.decodeIfPresent(Int.self, forKey: .historyRevision) ?? 0
        clearRevision = try container.decodeIfPresent(Int.self, forKey: .clearRevision) ?? 0
        messages = try container.decodeIfPresent([DJConnectAskDJHistoryMessage].self, forKey: .messages) ?? []
        serverTime = Self.decodeDate(container, key: .serverTime)
        historyLimit = try container.decodeIfPresent(Int.self, forKey: .historyLimit)
        historyTrimmedBefore = Self.decodeDate(container, key: .historyTrimmedBefore)
        historyTrimmedCount = try container.decodeIfPresent(Int.self, forKey: .historyTrimmedCount)
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

public struct DJConnectAskDJClearHistoryRequest: Codable, Equatable, Sendable {
    public var deviceID: String
    public var clientType: DJConnectClientType
    public var musicDNAKey: String?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientType = "client_type"
        case musicDNAKey = "music_dna_key"
    }

    public init(identity: DJConnectIdentity, musicDNAKey: String? = nil) {
        self.deviceID = identity.deviceID
        self.clientType = identity.clientType
        self.musicDNAKey = musicDNAKey
    }
}

public struct DJConnectMusicDNAIdentityRequest: Codable, Equatable, Sendable {
    public var deviceID: String
    public var clientType: DJConnectClientType

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientType = "client_type"
    }

    public init(identity: DJConnectIdentity) {
        self.deviceID = identity.deviceID
        self.clientType = identity.clientType
    }
}

public struct DJConnectMusicDNASettingsRequest: Codable, Equatable, Sendable {
    public var deviceID: String
    public var clientType: DJConnectClientType
    public var enabled: Bool

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientType = "client_type"
        case enabled
    }

    public init(identity: DJConnectIdentity, enabled: Bool) {
        self.deviceID = identity.deviceID
        self.clientType = identity.clientType
        self.enabled = enabled
    }
}

public struct DJConnectMusicDNAProfileResponse: Codable, Equatable, Sendable {
    public var success: Bool
    public var musicDNAKey: String?
    public var enabled: Bool
    public var generation: Int?
    public var clearRequestedAt: Date?
    public var updatedAt: Date?
    public var profile: DJConnectMusicDNAProfile
    public var sources: [DJConnectResponseLink]
    public var error: String?
    public var message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case musicDNAKey = "music_dna_key"
        case enabled
        case generation
        case clearRequestedAt = "clear_requested_at"
        case updatedAt = "updated_at"
        case profile
        case sources
        case error
        case message
    }

    public init(
        success: Bool = true,
        musicDNAKey: String? = nil,
        enabled: Bool = false,
        generation: Int? = nil,
        clearRequestedAt: Date? = nil,
        updatedAt: Date? = nil,
        profile: DJConnectMusicDNAProfile = DJConnectMusicDNAProfile(),
        sources: [DJConnectResponseLink] = [],
        error: String? = nil,
        message: String? = nil
    ) {
        self.success = success
        self.musicDNAKey = musicDNAKey
        self.enabled = enabled
        self.generation = generation
        self.clearRequestedAt = clearRequestedAt
        self.updatedAt = updatedAt
        self.profile = profile
        self.sources = sources
        self.error = error
        self.message = message
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? true
        musicDNAKey = try container.decodeIfPresent(String.self, forKey: .musicDNAKey)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        generation = try container.decodeIfPresent(Int.self, forKey: .generation)
        clearRequestedAt = DJConnectAskDJHistoryResponse.decodeDate(container, key: .clearRequestedAt)
        updatedAt = DJConnectAskDJHistoryResponse.decodeDate(container, key: .updatedAt)
        profile = try container.decodeIfPresent(DJConnectMusicDNAProfile.self, forKey: .profile) ?? DJConnectMusicDNAProfile()
        sources = container.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .sources) ?? []
        error = try container.decodeIfPresent(String.self, forKey: .error)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

public struct DJConnectMusicDNAProfile: Codable, Equatable, Sendable {
    public var summary: String?
    public var favoriteGenres: [DJConnectMusicDNANameValue]
    public var favoriteArtists: [DJConnectMusicDNANameValue]
    public var recentTracks: [DJConnectMusicDNATrack]
    public var topTracksByRange: [String: [DJConnectMusicDNATrack]]
    public var topArtistsByRange: [String: [DJConnectMusicDNANameValue]]
    public var mood: DJConnectMusicDNAMood?
    public var timePatterns: [DJConnectMusicDNASignal]
    public var recommendationSignals: [DJConnectMusicDNASignal]
    public var blockedArtists: [DJConnectMusicDNANameValue]
    public var blockedItems: [DJConnectMusicDNASignal]
    public var lastProfileRefresh: Date?
    public var consentUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case summary
        case favoriteGenres = "favorite_genres"
        case favoriteArtists = "favorite_artists"
        case recentTracks = "recent_tracks"
        case topTracksByRange = "top_tracks_by_range"
        case topArtistsByRange = "top_artists_by_range"
        case mood
        case timePatterns = "time_patterns"
        case recommendationSignals = "recommendation_signals"
        case blockedArtists = "blocked_artists"
        case blockedItems = "blocked_items"
        case lastProfileRefresh = "last_profile_refresh"
        case consentUpdatedAt = "consent_updated_at"
    }

    public init(
        summary: String? = nil,
        favoriteGenres: [DJConnectMusicDNANameValue] = [],
        favoriteArtists: [DJConnectMusicDNANameValue] = [],
        recentTracks: [DJConnectMusicDNATrack] = [],
        topTracksByRange: [String: [DJConnectMusicDNATrack]] = [:],
        topArtistsByRange: [String: [DJConnectMusicDNANameValue]] = [:],
        mood: DJConnectMusicDNAMood? = nil,
        timePatterns: [DJConnectMusicDNASignal] = [],
        recommendationSignals: [DJConnectMusicDNASignal] = [],
        blockedArtists: [DJConnectMusicDNANameValue] = [],
        blockedItems: [DJConnectMusicDNASignal] = [],
        lastProfileRefresh: Date? = nil,
        consentUpdatedAt: Date? = nil
    ) {
        self.summary = summary
        self.favoriteGenres = favoriteGenres
        self.favoriteArtists = favoriteArtists
        self.recentTracks = recentTracks
        self.topTracksByRange = topTracksByRange
        self.topArtistsByRange = topArtistsByRange
        self.mood = mood
        self.timePatterns = timePatterns
        self.recommendationSignals = recommendationSignals
        self.blockedArtists = blockedArtists
        self.blockedItems = blockedItems
        self.lastProfileRefresh = lastProfileRefresh
        self.consentUpdatedAt = consentUpdatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        favoriteGenres = container.decodeLossyArrayIfPresent(DJConnectMusicDNANameValue.self, forKey: .favoriteGenres) ?? []
        favoriteArtists = container.decodeLossyArrayIfPresent(DJConnectMusicDNANameValue.self, forKey: .favoriteArtists) ?? []
        recentTracks = container.decodeLossyArrayIfPresent(DJConnectMusicDNATrack.self, forKey: .recentTracks) ?? []
        topTracksByRange = try container.decodeIfPresent([String: [DJConnectMusicDNATrack]].self, forKey: .topTracksByRange) ?? [:]
        topArtistsByRange = try container.decodeIfPresent([String: [DJConnectMusicDNANameValue]].self, forKey: .topArtistsByRange) ?? [:]
        mood = try container.decodeIfPresent(DJConnectMusicDNAMood.self, forKey: .mood)
        timePatterns = container.decodeLossyArrayIfPresent(DJConnectMusicDNASignal.self, forKey: .timePatterns) ?? []
        recommendationSignals = container.decodeLossyArrayIfPresent(DJConnectMusicDNASignal.self, forKey: .recommendationSignals) ?? []
        blockedArtists = container.decodeLossyArrayIfPresent(DJConnectMusicDNANameValue.self, forKey: .blockedArtists) ?? []
        blockedItems = container.decodeLossyArrayIfPresent(DJConnectMusicDNASignal.self, forKey: .blockedItems) ?? []
        lastProfileRefresh = DJConnectAskDJHistoryResponse.decodeDate(container, key: .lastProfileRefresh)
        consentUpdatedAt = DJConnectAskDJHistoryResponse.decodeDate(container, key: .consentUpdatedAt)
    }

    public var isEmpty: Bool {
        let trimmedSummary = summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedSummary.isEmpty
            && favoriteGenres.isEmpty
            && favoriteArtists.isEmpty
            && recentTracks.isEmpty
            && topTracksByRange.values.allSatisfy(\.isEmpty)
            && topArtistsByRange.values.allSatisfy(\.isEmpty)
            && mood == nil
            && timePatterns.isEmpty
            && recommendationSignals.isEmpty
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
}

public struct DJConnectMusicDNATrack: Codable, Equatable, Sendable, Identifiable {
    public var id: String { [title, artist].compactMap { $0 }.joined(separator: "|") }
    public var title: String?
    public var artist: String?

    public init(title: String? = nil, artist: String? = nil) {
        self.title = title
        self.artist = artist
    }
}

public struct DJConnectMusicDNAMood: Codable, Equatable, Sendable {
    public var value: Int?
    public var zone: String?
    public var promptHint: String?

    enum CodingKeys: String, CodingKey {
        case value
        case zone
        case promptHint = "prompt_hint"
    }

    public init(value: Int? = nil, zone: String? = nil, promptHint: String? = nil) {
        self.value = value.map { max(0, min(100, $0)) }
        self.zone = zone
        self.promptHint = promptHint
    }
}

public struct DJConnectMusicDNASignal: Codable, Equatable, Sendable, Identifiable {
    public var id: String { [title, name, kind, value].compactMap { $0 }.joined(separator: "|") }
    public var title: String?
    public var name: String?
    public var kind: String?
    public var value: String?
    public var promptHint: String?

    enum CodingKeys: String, CodingKey {
        case title
        case name
        case kind
        case value
        case promptHint = "prompt_hint"
    }

    public init(title: String? = nil, name: String? = nil, kind: String? = nil, value: String? = nil, promptHint: String? = nil) {
        self.title = title
        self.name = name
        self.kind = kind
        self.value = value
        self.promptHint = promptHint
    }
}

public struct DJConnectAskDJMessageResponse: Codable, Equatable, Sendable {
    public var userMessage: DJConnectAskDJHistoryMessage?
    public var assistantMessage: DJConnectAskDJHistoryMessage?
    public var messages: [DJConnectAskDJHistoryMessage]
    public var text: String?
    public var djText: String?
    public var message: String?
    public var images: [DJConnectResponseImage]?
    public var links: [DJConnectResponseLink]?
    public var sources: [DJConnectResponseLink]?
    public var playbackActions: [DJConnectAskDJPlaybackAction]?
    public var confirmationActions: [DJConnectAskDJPlaybackAction]?
    public var historyRevision: Int
    public var clearRevision: Int
    public var audioURL: URL?
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
        case images
        case links
        case sources
        case playbackActions = "playback_actions"
        case confirmationActions = "confirmation_actions"
        case recommendationActions = "recommendation_actions"
        case recommendations
        case historyRevision = "history_revision"
        case clearRevision = "clear_revision"
        case audioURL = "audio_url"
        case audioUrl
        case responseAudioURL = "response_audio_url"
        case responseAudioUrl
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
        images: [DJConnectResponseImage]? = nil,
        links: [DJConnectResponseLink]? = nil,
        sources: [DJConnectResponseLink]? = nil,
        playbackActions: [DJConnectAskDJPlaybackAction]? = nil,
        confirmationActions: [DJConnectAskDJPlaybackAction]? = nil,
        historyRevision: Int = 0,
        clearRevision: Int = 0,
        audioURL: URL? = nil,
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
        self.images = images
        self.links = links
        self.sources = sources
        self.playbackActions = playbackActions
        self.confirmationActions = confirmationActions
        self.historyRevision = historyRevision
        self.clearRevision = clearRevision
        self.audioURL = audioURL
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
        images = container.decodeLossyArrayIfPresent(DJConnectResponseImage.self, forKey: .images)
        links = container.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .links)
        sources = container.decodeLossyArrayIfPresent(DJConnectResponseLink.self, forKey: .sources)
        playbackActions = container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .playbackActions)
            ?? container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .recommendationActions)
            ?? container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .recommendations)
        confirmationActions = container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .confirmationActions)
        historyRevision = try container.decodeIfPresent(Int.self, forKey: .historyRevision) ?? 0
        clearRevision = try container.decodeIfPresent(Int.self, forKey: .clearRevision) ?? 0
        audioURL = try container.decodeIfPresent(URL.self, forKey: .audioURL)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .audioUrl)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .responseAudioURL)
            ?? container.decodeIfPresentIgnoringErrors(URL.self, forKey: .responseAudioUrl)
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
        if assistantMessage?.audioURL == nil, let audioURL {
            assistantMessage?.audioURL = audioURL
        }
        if assistantMessage?.intentInfo == nil, let intentInfo {
            assistantMessage?.intentInfo = intentInfo
        }
        if assistantMessage?.trackInsight == nil, let trackInsight {
            assistantMessage?.trackInsight = trackInsight
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
                text: fallbackText,
                createdAt: serverTime ?? Date(),
                images: images ?? [],
                links: (links ?? []) + (sources ?? []),
                sources: sources ?? [],
                audioURL: audioURL,
                playbackActions: playbackActions ?? [],
                confirmationActions: confirmationActions ?? [],
                intentInfo: intentInfo,
                trackInsight: trackInsight,
                items: items ?? []
            )
        }
        if messages.isEmpty {
            messages = [userMessage, assistantMessage].compactMap { $0 }
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
        try container.encodeIfPresent(images, forKey: .images)
        try container.encodeIfPresent(links, forKey: .links)
        try container.encodeIfPresent(sources, forKey: .sources)
        try container.encodeIfPresent(playbackActions, forKey: .playbackActions)
        try container.encodeIfPresent(confirmationActions, forKey: .confirmationActions)
        try container.encode(historyRevision, forKey: .historyRevision)
        try container.encode(clearRevision, forKey: .clearRevision)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
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
    public static let defaultNotificationCategories = ["ask_dj_response", "ask_dj_confirm"]

    public var deviceID: String
    public var clientType: DJConnectClientType
    public var pushToken: String
    public var pushEnvironment: DJConnectPushEnvironment
    public var appBundleID: String
    public var appVersion: String?
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
        case locale
        case notificationCategories = "notification_categories"
        case bootstrapProof = "bootstrap_proof"
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
        case recommendationActions = "recommendation_actions"
        case recommendations
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
            ?? container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .recommendationActions)
            ?? container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .recommendations)
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
    }

    public init(
        id: String? = nil,
        title: String,
        subtitle: String? = nil,
        deviceID: String? = nil,
        deviceName: String? = nil,
        active: Bool? = nil,
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
        musicBackendRevision: Int? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.active = active
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
    public var supportsVolume: Bool?
    public var volumePercent: Int?

    public init(
        id: String? = nil,
        name: String? = nil,
        type: String? = nil,
        active: Bool? = nil,
        supportsVolume: Bool? = nil,
        volumePercent: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.active = active
        self.supportsVolume = supportsVolume
        self.volumePercent = volumePercent
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case active
        case supportsVolume = "supports_volume"
        case volumePercent = "volume_percent"
    }
}

public struct DJConnectOutputDevice: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var type: String?
    public var active: Bool?
    public var supportsVolume: Bool?
    public var volumePercent: Int?

    public init(
        id: String? = nil,
        name: String,
        type: String? = nil,
        active: Bool? = nil,
        supportsVolume: Bool? = nil,
        volumePercent: Int? = nil
    ) {
        self.id = id ?? name
        self.name = name
        self.type = type
        self.active = active
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
            active: try container.decodeIfPresent(Bool.self, forKey: .active),
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
        try container.encodeIfPresent(supportsVolume, forKey: .supportsVolume)
        try container.encodeIfPresent(volumePercent, forKey: .volumePercent)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case active
        case supportsVolume = "supports_volume"
        case volumePercent = "volume_percent"
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

    public init(
        id: String? = nil,
        title: String,
        artist: String? = nil,
        album: String? = nil,
        uri: String? = nil,
        durationMS: Int? = nil,
        albumImageURL: URL? = nil
    ) {
        self.id = id ?? uri ?? title
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
        let artist = container.decodeStringAliasIfPresent(.artist, .artists)
        let album = try container.decodeIfPresent(String.self, forKey: .album)
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
        case artists
        case album
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
            context: try container.decodeIfPresent(String.self, forKey: .context)
        )
    }

    enum CodingKeys: String, CodingKey {
        case items
        case context
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
        lastPushError: String? = nil
    ) {
        self.success = success
        self.error = error
        self.message = message
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
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        let result = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .result)

        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? true
        error = try container.decodeIfPresent(String.self, forKey: .error)
        message = try container.decodeIfPresent(String.self, forKey: .message)
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
            decodedDevices = container.decodeLossyArrayIfPresent(DJConnectOutputDevice.self, forKey: .outputs)
        }
        if decodedDevices == nil {
            decodedDevices = container.decodeOutputDeviceItemsIfPresent(forKey: .items)
        }
        if decodedDevices == nil {
            decodedDevices = data?.decodeLossyArrayIfPresent(DJConnectOutputDevice.self, forKey: .devices)
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
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encodeIfPresent(message, forKey: .message)
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
    }

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
        case playback
        case data
        case result
        case devices
        case outputs
        case queue
        case queueContext = "queue_context"
        case contextURI = "context_uri"
        case contextUri
        case playlists
        case playbackActions = "playback_actions"
        case items
        case askDJClearRequired = "ask_dj_clear_required"
        case clearRequired = "clear_required"
        case pushSupported = "push_supported"
        case pushRegistered = "push_registered"
        case pushEnvironment = "push_environment"
        case lastPushError = "last_push_error"
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
        let supportsVolume = try container.decodeIfPresent(Bool.self, forKey: .supportsVolume)
        let volumePercent = try container.decodeIfPresent(Int.self, forKey: .volumePercent)
        let hasOutputShape = type != nil
            || active != nil
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
        case recommendationActions = "recommendation_actions"
        case recommendations
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
            ?? container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .recommendationActions)
            ?? container.decodeLossyArrayIfPresent(DJConnectAskDJPlaybackAction.self, forKey: .recommendations)
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
