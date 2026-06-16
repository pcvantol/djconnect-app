import Foundation

public enum DJConnectClientType: String, Codable, Sendable {
    case ios
    case macos
    case esp32
}

public enum DJConnectPlatform: String, Codable, Sendable {
    case ios
    case macos
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

    public init(
        identity: DJConnectIdentity,
        pairingToken: String,
        haLocalURL: String? = nil,
        haRemoteURL: String? = nil,
        assistPipelineID: String? = nil
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
        wakewordStatus: String? = nil
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

public enum DJConnectCommandValue: Codable, Equatable, Sendable {
    case bool(Bool)
    case int(Int)
    case string(String)
    case object([String: String])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode([String: String].self) {
            self = .object(value)
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
        playlists: [DJConnectPlaylist]? = nil
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
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        let result = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .result)

        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? true
        error = try container.decodeIfPresent(String.self, forKey: .error)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        backendAvailable = try container.decodeIfPresent(Bool.self, forKey: .backendAvailable)
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
    }
}

private extension KeyedDecodingContainer where Key == DJConnectCommandResponse.CodingKeys {
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
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(djText, forKey: .djText)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encodeIfPresent(audioType, forKey: .audioType)
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
