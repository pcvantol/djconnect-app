import Foundation

public enum DJConnectError: Error, Equatable, Sendable {
    case backendUnavailable(message: String?)
    case authStale(statusCode: Int, message: String?)
    case routeMissing(message: String?)
    case versionMismatch(DJConnectVersionMismatch)
    case notConfigured(message: String?)
    case server(statusCode: Int, message: String?)
    case network(message: String)
    case invalidResponse
    case invalidConfiguration(String)
    case missingToken
    case pairingFailed(message: String?)
}

public struct DJConnectVersionMismatch: Codable, Equatable, Sendable {
    public var message: String?
    public var haVersion: String?
    public var haMajorMinor: String?
    public var firmware: String?
    public var firmwareMajorMinor: String?

    enum CodingKeys: String, CodingKey {
        case message
        case haVersion = "ha_version"
        case haMajorMinor = "ha_major_minor"
        case firmware
        case firmwareMajorMinor = "firmware_major_minor"
    }
}

struct DJConnectErrorEnvelope: Codable {
    var success: Bool?
    var error: String?
    var message: String?
    var backendAvailable: Bool?
    var haVersion: String?
    var haMajorMinor: String?
    var firmware: String?
    var firmwareMajorMinor: String?

    enum CodingKeys: String, CodingKey {
        case success
        case error
        case message
        case backendAvailable = "backend_available"
        case haVersion = "ha_version"
        case haMajorMinor = "ha_major_minor"
        case firmware
        case firmwareMajorMinor = "firmware_major_minor"
    }
}
