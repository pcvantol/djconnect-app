import Foundation

public struct DJConnectWatchProxyDJResponseRequest: Codable, Sendable {
    public var text: String?
    public var djText: String?
    public var audioURL: String?
    public var audioType: String?

    public init(text: String? = nil, djText: String? = nil, audioURL: String? = nil, audioType: String? = nil) {
        self.text = text
        self.djText = djText
        self.audioURL = audioURL
        self.audioType = audioType
    }

    enum CodingKeys: String, CodingKey {
        case text
        case djText = "dj_text"
        case audioURL = "audio_url"
        case audioType = "audio_type"
    }
}
