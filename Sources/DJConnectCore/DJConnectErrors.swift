import Foundation

public enum DJConnectError: Error, Equatable, Sendable {
    case backendUnavailable(message: String?)
    case authStale(statusCode: Int, message: String?)
    case routeMissing(message: String?)
    case versionMismatch(DJConnectVersionMismatch)
    case notConfigured(message: String?)
    case server(statusCode: Int, message: String?)
    case decodingFailed(statusCode: Int, endpoint: String, message: String?)
    case network(message: String)
    case invalidResponse
    case invalidConfiguration(String)
    case missingToken
    case pairingFailed(message: String?)
    case clientTypeMismatch(message: String?, expectedClientType: String?, receivedClientType: String?)
    case trackInsightUnavailable(code: String?, message: String?)
}

public enum DJConnectErrorPresentationContext: Sendable {
    case general
    case pairing(expectedPairingFlowName: String)
}

public enum DJConnectErrorPresentation {
    public static func userMessage(
        for error: DJConnectError,
        language: String,
        context: DJConnectErrorPresentationContext = .general
    ) -> String? {
        switch error {
        case .clientTypeMismatch:
            return localizedPairingMessage(
                key: "pairing.error.clientTypeMismatch",
                language: language,
                context: context
            )
        case let .authStale(statusCode, message):
            if containsAny(message, ["invalid_pair_code", "invalid pair code"]) || statusCode == 401 || statusCode == 403 {
                return DJConnectLocalization.localized(
                    key: "pairing.error.invalidPairCode",
                    language: language
                )
            }
            return DJConnectLocalization.localized(
                key: "pairing.error.staleAuth",
                language: language
            )
        case let .notConfigured(message):
            if containsAny(message, ["invalid_pair_code", "invalid pair code"]) {
                return DJConnectLocalization.localized(
                    key: "pairing.error.invalidPairCode",
                    language: language
                )
            }
            if case .pairing = context {
                return DJConnectLocalization.localized(
                    key: "pairing.error.invalidPairCode",
                    language: language
                )
            }
            return DJConnectLocalization.localized(
                key: "pairing.error.notConfigured",
                language: language
            )
        case .routeMissing:
            return nil
        case let .server(statusCode, message):
            return userMessage(forStatusCode: statusCode, message: message, language: language, context: context)
        case let .pairingFailed(message):
            if containsAny(message, ["invalid_client_type", "client_type_mismatch", "client type"]) {
                return localizedPairingMessage(
                    key: "pairing.error.invalidClientType",
                    language: language,
                    context: context
                )
            }
            if containsAny(message, ["invalid_pair_code", "invalid code", "pair code"]) {
                return DJConnectLocalization.localized(
                    key: "pairing.error.invalidPairCode",
                    language: language
                )
            }
            return DJConnectLocalization.localized(
                key: "pairing.error.generic",
                language: language
            )
        case .missingToken:
            return DJConnectLocalization.localized(
                key: "pairing.error.staleAuth",
                language: language
            )
        default:
            return nil
        }
    }

    private static func userMessage(
        forStatusCode statusCode: Int,
        message: String?,
        language: String,
        context: DJConnectErrorPresentationContext
    ) -> String? {
        if containsAny(message, ["client_type_mismatch"]) {
            return localizedPairingMessage(
                key: "pairing.error.clientTypeMismatch",
                language: language,
                context: context
            )
        }
        if containsAny(message, ["invalid_client_type", "client type", "client_type"]) {
            return localizedPairingMessage(
                key: "pairing.error.invalidClientType",
                language: language,
                context: context
            )
        }
        if containsAny(message, ["invalid_pair_code", "invalid code", "pair code"]) || statusCode == 401 || statusCode == 403 {
            return DJConnectLocalization.localized(
                key: "pairing.error.invalidPairCode",
                language: language
            )
        }
        if containsAny(message, ["not_configured", "not configured", "setup flow", "config flow"]) {
            if case .pairing = context {
                return DJConnectLocalization.localized(
                    key: "pairing.error.invalidPairCode",
                    language: language
                )
            }
            return DJConnectLocalization.localized(
                key: "pairing.error.notConfigured",
                language: language
            )
        }
        if containsAny(message, ["unauthorized", "forbidden", "bearer", "token"]) {
            return DJConnectLocalization.localized(
                key: "pairing.error.unauthorized",
                language: language
            )
        }
        return nil
    }

    private static func localizedPairingMessage(
        key: String,
        language: String,
        context: DJConnectErrorPresentationContext
    ) -> String {
        let flowName: String
        switch context {
        case .general:
            flowName = "iPhone/iPad"
        case let .pairing(expectedPairingFlowName):
            flowName = expectedPairingFlowName
        }
        return DJConnectLocalization.localized(key: key, language: language, arguments: flowName)
    }

    private static func containsAny(_ message: String?, _ needles: [String]) -> Bool {
        guard let message else {
            return false
        }
        let normalized = message.lowercased()
        return needles.contains { normalized.contains($0) }
    }
}

public struct DJConnectVersionMismatch: Codable, Equatable, Sendable {
    public var message: String?
    public var haVersion: String?
    public var haMajorMinor: String?
    public var firmware: String?
    public var firmwareMajorMinor: String?

    public init(
        message: String? = nil,
        haVersion: String? = nil,
        haMajorMinor: String? = nil,
        firmware: String? = nil,
        firmwareMajorMinor: String? = nil
    ) {
        self.message = message
        self.haVersion = haVersion
        self.haMajorMinor = haMajorMinor
        self.firmware = firmware
        self.firmwareMajorMinor = firmwareMajorMinor
    }

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
    var expectedClientType: String?
    var receivedClientType: String?

    enum CodingKeys: String, CodingKey {
        case success
        case error
        case message
        case backendAvailable = "backend_available"
        case haVersion = "ha_version"
        case haMajorMinor = "ha_major_minor"
        case firmware
        case firmwareMajorMinor = "firmware_major_minor"
        case expectedClientType = "expected_client_type"
        case receivedClientType = "received_client_type"
    }
}
