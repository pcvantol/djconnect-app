import Foundation

public enum DJConnectClientType: String, Codable, Sendable {
    case ios
    case macos
    case watchos
    case esp32
    case raspberryPi = "raspberry_pi"
}

public enum DJConnectPlatform: String, Codable, Sendable {
    case ios
    case macos
    case watchos
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
    public var deviceLanguage: String?
    public var language: String?
    public var assistPipelineID: String?

    public var resolvedDeviceToken: String? {
        deviceToken ?? bearerToken ?? token
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
        deviceLanguage: String? = nil,
        language: String? = nil,
        assistPipelineID: String? = nil
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
        self.deviceLanguage = deviceLanguage
        self.language = language
        self.assistPipelineID = assistPipelineID
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
        case deviceLanguage = "device_language"
        case language
        case assistPipelineID = "assist_pipeline_id"
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
    public var localURL: String?
    public var voiceEnabled: Bool?
    public var wakewordEnabled: Bool?
    public var wakewordPhrase: String?
    public var wakewordStatus: String?
    public var mood: Int?
    public var djStyle: String?
    public var memoryKey: String?
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
        localURL: String? = nil,
        voiceEnabled: Bool? = nil,
        wakewordEnabled: Bool? = nil,
        wakewordPhrase: String? = nil,
        wakewordStatus: String? = nil,
        mood: Int? = nil,
        djStyle: String? = nil,
        memoryKey: String? = nil,
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
        self.localURL = localURL
        self.voiceEnabled = voiceEnabled
        self.wakewordEnabled = wakewordEnabled
        self.wakewordPhrase = wakewordPhrase
        self.wakewordStatus = wakewordStatus
        self.mood = mood.map { max(0, min(100, $0)) }
        self.djStyle = djStyle
        self.memoryKey = memoryKey
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
        case localURL = "local_url"
        case voiceEnabled = "voice_enabled"
        case wakewordEnabled = "wakeword_enabled"
        case wakewordPhrase = "wakeword_phrase"
        case wakewordStatus = "wakeword_status"
        case mood
        case djStyle = "dj_style"
        case memoryKey = "memory_key"
        case bootstrapProof = "bootstrap_proof"
    }
}

public struct DJConnectCommandPayload: Codable, Equatable, Sendable {
    public var deviceID: String
    public var clientType: DJConnectClientType
    public var command: String
    public var value: DJConnectCommandValue?
    public var play: Bool?
    public var limit: Int?

    public init(
        identity: DJConnectIdentity,
        command: String,
        value: DJConnectCommandValue? = nil,
        play: Bool? = nil,
        limit: Int? = nil
    ) {
        self.deviceID = identity.deviceID
        self.clientType = identity.clientType
        self.command = command
        self.value = value
        self.play = play
        self.limit = limit
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientType = "client_type"
        case command
        case value
        case play
        case limit
    }
}

public struct DJConnectAskDJRequest: Codable, Equatable, Sendable {
    public enum AudioResponse: String, Codable, Equatable, Sendable {
        case auto
        case always
        case never
    }

    public var deviceID: String
    public var clientType: DJConnectClientType
    public var clientMessageID: String?
    public var text: String
    public var inputType: String?
    public var mood: Int?
    public var djStyle: String?
    public var memoryKey: String?
    public var audioResponse: AudioResponse?
    public var metadata: [String: String]?

    public init(
        identity: DJConnectIdentity,
        text: String,
        clientMessageID: String? = nil,
        inputType: String? = nil,
        mood: Int? = nil,
        djStyle: String? = nil,
        memoryKey: String? = nil,
        audioResponse: AudioResponse? = nil,
        metadata: [String: String]? = nil
    ) {
        self.deviceID = identity.deviceID
        self.clientType = identity.clientType
        self.clientMessageID = clientMessageID
        self.text = text
        self.inputType = inputType
        self.mood = mood.map { max(0, min(100, $0)) }
        self.djStyle = djStyle
        self.memoryKey = memoryKey
        self.audioResponse = audioResponse
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientType = "client_type"
        case clientMessageID = "client_message_id"
        case text
        case inputType = "input_type"
        case mood
        case djStyle = "dj_style"
        case memoryKey = "memory_key"
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
    public var intent: String?
    public var action: String?
    public var itemType: String?

    enum CodingKeys: String, CodingKey {
        case intent
        case action
        case itemType = "item_type"
        case itemTypeCamel = "itemType"
    }

    public init(intent: String? = nil, action: String? = nil, itemType: String? = nil) {
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
            intent: try container.decodeIfPresent(String.self, forKey: .intent),
            action: try container.decodeIfPresent(String.self, forKey: .action),
            itemType: try container.decodeIfPresent(String.self, forKey: .itemType)
                ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .itemTypeCamel)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(intent, forKey: .intent)
        try container.encodeIfPresent(action, forKey: .action)
        try container.encodeIfPresent(itemType, forKey: .itemType)
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

    enum CodingKeys: String, CodingKey {
        case kind
        case title
        case subtitle
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
        playedAtLabel: String? = nil
    ) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.uri = uri
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.playedAt = playedAt
        self.playedAtLabel = playedAtLabel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
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
    public var items: [DJConnectAskDJHistoryItem]

    enum CodingKeys: String, CodingKey {
        case id
        case clientMessageID = "client_message_id"
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
        case items
    }

    public init(
        id: String,
        clientMessageID: String? = nil,
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
        items: [DJConnectAskDJHistoryItem] = []
    ) {
        self.id = id
        self.clientMessageID = clientMessageID
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
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        clientMessageID = try container.decodeIfPresent(String.self, forKey: .clientMessageID)
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
        items = container.decodeLossyArrayIfPresent(DJConnectAskDJHistoryItem.self, forKey: .items) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(clientMessageID, forKey: .clientMessageID)
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
    public var memoryKey: String?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientType = "client_type"
        case memoryKey = "memory_key"
    }

    public init(identity: DJConnectIdentity, memoryKey: String? = nil) {
        self.deviceID = identity.deviceID
        self.clientType = identity.clientType
        self.memoryKey = memoryKey
    }
}

public struct DJConnectAskDJMessageResponse: Codable, Equatable, Sendable {
    public var userMessage: DJConnectAskDJHistoryMessage?
    public var assistantMessage: DJConnectAskDJHistoryMessage?
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
    public var items: [DJConnectAskDJHistoryItem]?

    enum CodingKeys: String, CodingKey {
        case userMessage = "user_message"
        case assistantMessage = "assistant_message"
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
        case items
    }

    public init(
        userMessage: DJConnectAskDJHistoryMessage? = nil,
        assistantMessage: DJConnectAskDJHistoryMessage? = nil,
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
        items: [DJConnectAskDJHistoryItem]? = nil
    ) {
        self.userMessage = userMessage
        self.assistantMessage = assistantMessage
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
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userMessage = try container.decodeIfPresent(DJConnectAskDJHistoryMessage.self, forKey: .userMessage)
        assistantMessage = try container.decodeIfPresent(DJConnectAskDJHistoryMessage.self, forKey: .assistantMessage)
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
                intent: intentInfo?.intent,
                action: intentInfo?.action ?? action,
                itemType: intentInfo?.itemType ?? itemType
            )
        } else if intentInfo == nil, action != nil || itemType != nil {
            intentInfo = DJConnectAskDJIntentInfo(intent: nil, action: action, itemType: itemType)
        }
        items = container.decodeLossyArrayIfPresent(DJConnectAskDJHistoryItem.self, forKey: .items)
        if assistantMessage?.audioURL == nil, let audioURL {
            assistantMessage?.audioURL = audioURL
        }
        if assistantMessage?.intentInfo == nil, let intentInfo {
            assistantMessage?.intentInfo = intentInfo
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
                items: items ?? []
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(userMessage, forKey: .userMessage)
        try container.encodeIfPresent(assistantMessage, forKey: .assistantMessage)
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
        try container.encodeIfPresent(items, forKey: .items)
    }
}

public struct DJConnectAskDJIdleSuggestionRequest: Codable, Equatable, Sendable {
    public var deviceID: String
    public var clientType: DJConnectClientType
    public var clientMessageID: String
    public var mood: Int?
    public var djStyle: String?
    public var memoryKey: String?

    public init(
        identity: DJConnectIdentity,
        clientMessageID: String,
        mood: Int? = nil,
        djStyle: String? = nil,
        memoryKey: String? = nil
    ) {
        self.deviceID = identity.deviceID
        self.clientType = identity.clientType
        self.clientMessageID = clientMessageID
        self.mood = mood.map { max(0, min(100, $0)) }
        self.djStyle = djStyle
        self.memoryKey = memoryKey
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientType = "client_type"
        case clientMessageID = "client_message_id"
        case mood
        case djStyle = "dj_style"
        case memoryKey = "memory_key"
    }
}

public struct DJConnectPushRegistrationRequest: Codable, Equatable, Sendable {
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
        notificationCategories: [String] = ["ask_dj"],
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
        url = try container.decode(URL.self, forKey: .url)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .label)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .description)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        source = try container.decodeIfPresent(String.self, forKey: .source)
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
    public var action: String?
    public var memoryKey: String?

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
        case memoryKey = "memory_key"
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
        action: String? = nil,
        memoryKey: String? = nil
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
        self.action = action
        self.memoryKey = memoryKey
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
        intent = try container.decodeIfPresent(String.self, forKey: .intent)
        action = try container.decodeIfPresent(String.self, forKey: .action)
        memoryKey = try container.decodeIfPresent(String.self, forKey: .memoryKey)
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
        try container.encodeIfPresent(intent, forKey: .intent)
        try container.encodeIfPresent(action, forKey: .action)
        try container.encodeIfPresent(memoryKey, forKey: .memoryKey)
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
        buttonLabel: String? = nil
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
        responseValue = try container.decodeIfPresent(String.self, forKey: .responseValue)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .responseValueCamel)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .value)
        buttonLabel = try container.decodeIfPresent(String.self, forKey: .buttonLabel)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .buttonLabelCamel)
            ?? container.decodeIfPresentIgnoringErrors(String.self, forKey: .label)
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
    }

    public var isOutputAction: Bool {
        kind?.localizedCaseInsensitiveCompare("output") == .orderedSame
    }

    public var outputDeviceID: String? {
        guard isOutputAction else {
            return nil
        }
        let candidate = responseValue ?? deviceID
        let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
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
        case clientType = "client_type"
        case deviceLanguage = "device_language"
        case language
        case playback
        case data
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
        contextURI: String? = nil
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
    }
}

private extension KeyedDecodingContainer where Key == DJConnectPlayback.CodingKeys {
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
    public var playback: DJConnectPlayback?
    public var devices: [DJConnectOutputDevice]?
    public var queue: [DJConnectQueueItem]?
    public var queueContext: String?
    public var playlists: [DJConnectPlaylist]?
    public var askDJClearRequired: Bool?
    public var pushSupported: Bool?
    public var pushRegistered: Bool?
    public var pushEnvironment: DJConnectPushEnvironment?
    public var lastPushError: String?

    public init(
        success: Bool,
        error: String? = nil,
        message: String? = nil,
        backendAvailable: Bool? = nil,
        haVersion: String? = nil,
        haMajorMinor: String? = nil,
        playback: DJConnectPlayback? = nil,
        devices: [DJConnectOutputDevice]? = nil,
        queue: [DJConnectQueueItem]? = nil,
        queueContext: String? = nil,
        playlists: [DJConnectPlaylist]? = nil,
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
        self.playback = playback
        self.devices = devices
        self.queue = queue
        self.queueContext = queueContext
        self.playlists = playlists
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
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(backendAvailable, forKey: .backendAvailable)
        try container.encodeIfPresent(haVersion, forKey: .haVersion)
        try container.encodeIfPresent(haMajorMinor, forKey: .haMajorMinor)
        try container.encodeIfPresent(playback, forKey: .playback)
        try container.encodeIfPresent(devices, forKey: .devices)
        try container.encodeIfPresent(queue, forKey: .queue)
        try container.encodeIfPresent(queueContext, forKey: .queueContext)
        try container.encodeIfPresent(playlists, forKey: .playlists)
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
