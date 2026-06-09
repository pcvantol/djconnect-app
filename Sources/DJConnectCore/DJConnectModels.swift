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
    public var deviceID: String
    public var deviceName: String
    public var clientType: DJConnectClientType
    public var firmware: String
    public var appVersion: String?
    public var platform: DJConnectPlatform

    public init(
        deviceID: String,
        deviceName: String,
        clientType: DJConnectClientType,
        firmware: String,
        appVersion: String? = nil,
        platform: DJConnectPlatform
    ) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.clientType = clientType
        self.firmware = firmware
        self.appVersion = appVersion
        self.platform = platform
    }

    enum CodingKeys: String, CodingKey {
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
    public var localURL: String?

    public init(identity: DJConnectIdentity, pairingToken: String, localURL: String? = nil) {
        self.deviceID = identity.deviceID
        self.deviceName = identity.deviceName
        self.clientType = identity.clientType
        self.firmware = identity.firmware
        self.appVersion = identity.appVersion
        self.platform = identity.platform
        self.pairingToken = pairingToken
        self.localURL = localURL
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case deviceName = "device_name"
        case clientType = "client_type"
        case firmware
        case appVersion = "app_version"
        case platform
        case pairingToken = "pairing_token"
        case localURL = "local_url"
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

    public var resolvedDeviceToken: String? {
        deviceToken ?? bearerToken ?? token
    }

    enum CodingKeys: String, CodingKey {
        case success
        case deviceToken = "device_token"
        case token
        case bearerToken = "bearer_token"
        case message
        case deviceID = "device_id"
        case clientType = "client_type"
    }
}

public struct DJConnectStatusPayload: Codable, Equatable, Sendable {
    public var deviceID: String
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
    public var localURL: String?

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
        localURL: String? = nil
    ) {
        self.deviceID = identity.deviceID
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
        self.localURL = localURL
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
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
        case localURL = "local_url"
    }
}

public struct DJConnectCommandPayload: Codable, Equatable, Sendable {
    public var deviceID: String
    public var clientType: DJConnectClientType
    public var command: String
    public var value: DJConnectCommandValue?
    public var play: Bool?

    public init(
        identity: DJConnectIdentity,
        command: String,
        value: DJConnectCommandValue? = nil,
        play: Bool? = nil
    ) {
        self.deviceID = identity.deviceID
        self.clientType = identity.clientType
        self.command = command
        self.value = value
        self.play = play
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case clientType = "client_type"
        case command
        case value
        case play
    }
}

public enum DJConnectCommandValue: Codable, Equatable, Sendable {
    case bool(Bool)
    case int(Int)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
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
        }
    }
}

public struct DJConnectEnvelope<T: Codable & Sendable>: Codable, Sendable {
    public var success: Bool
    public var error: String?
    public var message: String?
    public var backendAvailable: Bool?
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
        device: DJConnectPlaybackDevice? = nil
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
    }

    enum CodingKeys: String, CodingKey {
        case hasPlayback = "has_playback"
        case isPlaying = "is_playing"
        case trackName = "track_name"
        case artistName = "artist_name"
        case albumImageURL = "album_image_url"
        case progressMS = "progress_ms"
        case durationMS = "duration_ms"
        case volumePercent = "volume_percent"
        case shuffle
        case repeatState = "repeat_state"
        case device
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
        case audioType = "audio_type"
    }
}
