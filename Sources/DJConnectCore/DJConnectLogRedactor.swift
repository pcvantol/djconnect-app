import Foundation

public enum DJConnectLogRedactor {
    public static func redactText(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "<missing>"
        }
        return value
            .replacingOccurrences(
                of: #"Bearer\s+[A-Za-z0-9._~+/=-]+"#,
                with: "Bearer [redacted]",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)"(device_token|push_token|bearer_token|token|access_token|refresh_token|client_secret|password|authorization|bootstrap_proof|proof|audio_url|audioUrl|response_audio_url|responseAudioUrl)"\s*:\s*"[^"]*""#,
                with: #""$1":"[redacted]""#,
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)\b(device_token|push_token|bearer_token|token|access_token|refresh_token|client_secret|password|authorization|bootstrap_proof|proof|audio_url|audioUrl|response_audio_url|responseAudioUrl)=\\?"?[^,\s&"]+\\?"?"#,
                with: "$1=[redacted]",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(djci_[A-Za-z0-9._~+/=-]+|[A-Fa-f0-9]{32,}|[A-Za-z0-9_-]{80,})"#,
                with: "[redacted]",
                options: .regularExpression
            )
    }

    public static func redactSecret(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "<missing>"
        }
        let prefix = String(value.prefix(6))
        let suffix = String(value.suffix(6))
        return "\(prefix)...\(suffix) (len=\(value.count))"
    }

    public static func sanitizeForLog(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, entry in
                if shouldRedact(key: entry.key) {
                    result[entry.key] = redactSecret(stringValue(entry.value))
                } else {
                    result[entry.key] = sanitizeForLog(entry.value)
                }
            }
        }
        if let array = value as? [Any] {
            return array.map(sanitizeForLog)
        }
        return value
    }

    public static func sanitizedJSONString(_ value: Any) -> String {
        let sanitized = sanitizeForLog(value)
        guard JSONSerialization.isValidJSONObject(sanitized),
              let data = try? JSONSerialization.data(withJSONObject: sanitized, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "\(sanitized)"
        }
        return string
    }

    private static func shouldRedact(key: String) -> Bool {
        let normalized = key.lowercased()
        return normalized.contains("token")
            || normalized.contains("proof")
            || normalized.contains("secret")
            || normalized.contains("password")
            || normalized.contains("authorization")
            || normalized == "audio_url"
            || normalized == "audiourl"
            || normalized == "response_audio_url"
            || normalized == "responseaudiourl"
    }

    private static func stringValue(_ value: Any) -> String? {
        if let value = value as? String {
            return value
        }
        if value is NSNull {
            return nil
        }
        return "\(value)"
    }
}
