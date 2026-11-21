import Foundation
import DJConnectCore

/// Immutable client presentation only. Localization and logging stay with the
/// caller; this catalog neither stores nor authorizes platform state.
struct ClientFailurePresentation: Sendable {
    enum InsightCopy: Sendable {
        case producer(String?, String?)
        case http(Int, String?)
        case parsed(String?, fallback: String)
        case clientType
        case localized(String)
        case network(String)
        case verbatim(String)
        case optionalMessage(String?, fallback: String)
    }

    let code: String
    let message: String
    let diagnostic: String
    let insightCode: String
    let insightDiagnosticMessage: String?
    let httpStatus: String?
    let insightCopy: InsightCopy

    private static let unrecognized = Self(code: "failed", message: "iPhone kon Home Assistant niet bereiken.",
        diagnostic: "failed", insightCode: "unknown", insightDiagnosticMessage: nil, httpStatus: nil,
        insightCopy: .localized("appModel.track.insight.is.unavailable.for.this.track"))

    static func make(_ error: DJConnectError) -> Self {
        switch error {
        case .backendUnavailable, .routeMissing, .network, .server, .decodingFailed, .invalidResponse:
            return transport(error)
        case .authStale, .notConfigured, .missingToken, .pairingFailed, .clientTypeMismatch:
            return pairing(error)
        case .versionMismatch, .invalidConfiguration:
            return configuration(error)
        case .trackInsightUnavailable, .payloadTooLarge, .profile:
            return capability(error)
        }
    }

    private static func transport(_ error: DJConnectError) -> Self {
        switch error {
        case let .backendUnavailable(message):
            return .init(code: "backend_unavailable", message: "Home Assistant gaf geen antwoord.", diagnostic: "backend unavailable\(message.map { ": \($0)" } ?? "")",
                insightCode: "backend_unavailable", insightDiagnosticMessage: message, httpStatus: nil,
                insightCopy: .parsed(message, fallback: "appModel.the.music.backend.in.home.assistant.is.not.available"))
        case let .routeMissing(message):
            return .init(code: "route_missing", message: "Ask DJ niet bereikbaar.", diagnostic: "route missing\(message.map { ": \($0)" } ?? "")",
                insightCode: "route_missing", insightDiagnosticMessage: message, httpStatus: nil,
                insightCopy: .parsed(message, fallback: "appModel.track.insight.is.not.available.in.this.home.assistant"))
        case let .network(message):
            return .init(code: "network", message: "Ask DJ niet bereikbaar.", diagnostic: "network: \(message)",
                insightCode: "network", insightDiagnosticMessage: message, httpStatus: nil,
                insightCopy: .network(message))
        case let .server(statusCode, message):
            return .init(code: "server", message: "Home Assistant gaf geen antwoord.", diagnostic: "server HTTP \(statusCode)\(message.map { ": \($0)" } ?? "")",
                insightCode: "server", insightDiagnosticMessage: message, httpStatus: String(statusCode),
                insightCopy: .http(statusCode, message))
        case let .decodingFailed(statusCode, endpoint, message):
            return .init(code: "server", message: "Home Assistant gaf geen antwoord.", diagnostic: "decode failed HTTP \(statusCode) \(endpoint)\(message.map { ": \($0)" } ?? "")",
                insightCode: "decoding_failed", insightDiagnosticMessage: message, httpStatus: String(statusCode),
                insightCopy: .localized(message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? "appModel.home.assistant.returned.an.unexpected.track.insight.response" : "appModel.home.assistant.returned.an.unreadable.track.insight.response"))
        case .invalidResponse:
            return .init(code: "server", message: "Home Assistant gaf geen antwoord.", diagnostic: "invalid response",
                insightCode: "invalid_response", insightDiagnosticMessage: "invalid_response", httpStatus: nil,
                insightCopy: .localized("appModel.home.assistant.returned.an.invalid.track.insight.response"))
        default: return .unrecognized
        }
    }

    private static func pairing(_ error: DJConnectError) -> Self {
        switch error {
        case let .authStale(statusCode, message):
            return .init(code: "auth_stale", message: "Koppel opnieuw via iPhone.", diagnostic: "auth stale HTTP \(statusCode)\(message.map { ": \($0)" } ?? "")",
                insightCode: "auth_stale", insightDiagnosticMessage: message, httpStatus: String(statusCode),
                insightCopy: .localized("appModel.pair.with.home.assistant.again.before.using.track.insight"))
        case let .notConfigured(message):
            return .init(code: "not_configured", message: "Ask DJ niet bereikbaar.", diagnostic: "not configured\(message.map { ": \($0)" } ?? "")",
                insightCode: "not_configured", insightDiagnosticMessage: message, httpStatus: nil,
                insightCopy: .parsed(message, fallback: "appModel.finish.the.djconnect.setup.in.home.assistant.before.using"))
        case .missingToken:
            return .init(code: "missing_token", message: "Koppel opnieuw via iPhone.", diagnostic: "missing DJConnect bearer token",
                insightCode: "missing_token", insightDiagnosticMessage: "missing_token", httpStatus: nil,
                insightCopy: .localized("appModel.pair.with.home.assistant.again.before.using.track.insight"))
        case let .pairingFailed(message):
            return .init(code: "pairing_failed", message: message ?? "Koppelen via iPhone is nog niet klaar.", diagnostic: "pairing pending\(message.map { ": \($0)" } ?? "")",
                insightCode: "pairing_failed", insightDiagnosticMessage: message, httpStatus: nil,
                insightCopy: .optionalMessage(message, fallback: "appModel.pair.with.home.assistant.before.using.track.insight"))
        case let .clientTypeMismatch(message, expectedClientType, receivedClientType):
            return .init(code: "client_type_mismatch", message: message ?? "Verkeerd app-type gekozen in Home Assistant.", diagnostic: "client type mismatch expected=\(expectedClientType ?? "?") received=\(receivedClientType ?? "?")\(message.map { ": \($0)" } ?? "")",
                insightCode: "client_type_mismatch", insightDiagnosticMessage: message, httpStatus: nil,
                insightCopy: .clientType)
        default: return .unrecognized
        }
    }

    private static func configuration(_ error: DJConnectError) -> Self {
        switch error {
        case let .versionMismatch(mismatch):
            return .init(code: "version_mismatch", message: mismatch.message ?? "Werk DJConnect bij.", diagnostic: "version mismatch HA \(mismatch.haMajorMinor ?? "?") app \(mismatch.firmwareMajorMinor ?? "?")",
                insightCode: "version_mismatch", insightDiagnosticMessage: "version_mismatch", httpStatus: nil,
                insightCopy: .optionalMessage(mismatch.message, fallback: "appModel.update.the.djconnect.app.or.home.assistant.integration.before"))
        case let .invalidConfiguration(message):
            return .init(code: "invalid_configuration", message: message, diagnostic: "invalid configuration: \(message)",
                insightCode: "invalid_configuration", insightDiagnosticMessage: message, httpStatus: nil,
                insightCopy: .verbatim(message))
        default: return .unrecognized
        }
    }

    private static func capability(_ error: DJConnectError) -> Self {
        switch error {
        case let .trackInsightUnavailable(code, message):
            return .init(code: "track_insight_unavailable", message: "Track Insight is niet beschikbaar voor dit nummer.", diagnostic: "track insight unavailable\(code.map { " \($0)" } ?? "")\(message.map { ": \($0)" } ?? "")",
                insightCode: nonEmpty(code) ?? "track_insight_unavailable", insightDiagnosticMessage: message, httpStatus: nil,
                insightCopy: .producer(code, message))
        case let .payloadTooLarge(limitBytes, actualBytes):
            return .init(code: "payload_too_large", message: "Home Assistant gaf te veel data terug.", diagnostic: "payload too large limit=\(limitBytes) actual=\(actualBytes.map(String.init) ?? "unknown")",
                insightCode: "payload_too_large", insightDiagnosticMessage: "payload_too_large limit=\(limitBytes) actual=\(actualBytes.map(String.init) ?? "unknown")", httpStatus: nil,
                insightCopy: .localized("appModel.home.assistant.returned.an.unexpected.track.insight.response"))
        case let .profile(code, statusCode, message):
            return .init(code: "profile_error", message: message ?? "Profielinstellingen ontbreken in Home Assistant.", diagnostic: "profile \(code.rawValue) HTTP \(statusCode)\(message.map { ": \($0)" } ?? "")",
                insightCode: code.rawValue, insightDiagnosticMessage: message, httpStatus: nil,
                insightCopy: .parsed(message, fallback: "appModel.track.insight.is.unavailable.for.this.track"))
        default: return .unrecognized
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
