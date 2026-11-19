import Foundation

/// Closed successor DATA preflight, not a permission, clock, native owner or
/// enabled transport. No production factory or old profile delegates to this.
/// The original fragments survive intact; decoding never reserializes them.
enum DJConnectRichSurfaceFragments {
    struct Value: Sendable {
        let attributes: Data
        let contentState: Data
        let snapshot: DJConnectSessionSurfaceSnapshot
        let sourceObservedMS: Int64
        let sourceExpiresMS: Int64
    }

    static func decode(_ data: Data) throws -> Value {
        let root = try RichJSON.parse(data, limit: 16_384)
        let object = try root.object(required: ["schema_version", "profile_id", "attributes_utf8_b64u",
            "content_state_utf8_b64u", "source_observed_at_ms", "source_expires_at_ms"])
        guard try object["schema_version"]!.integer() == 1,
              try object["profile_id"]!.string() == "djconnect-session-rich-v1" else { throw invalid() }
        let observed = try object["source_observed_at_ms"]!.integer()
        let expires = try object["source_expires_at_ms"]!.integer()
        guard observed >= 0, observed < expires else { throw invalid() }
        let attributes = try base64(object["attributes_utf8_b64u"]!.string())
        let state = try base64(object["content_state_utf8_b64u"]!.string())
        let snapshot = try preflight(attributes: attributes, state: state)
        return Value(attributes: attributes, contentState: state, snapshot: snapshot,
                     sourceObservedMS: observed, sourceExpiresMS: expires)
    }

    /// Format checks only. Original UTC source bounds and native creation bytes
    /// MUST be independently matched at actual use; DATA cannot establish either.
    static func preflight(attributes: Data, state: Data) throws -> DJConnectSessionSurfaceSnapshot {
        guard attributes.count + state.count <= 4096 else { throw invalid() }
        let attrs = try RichJSON.parse(attributes, limit: 4096).object(required: ["presentationID"])
        _ = try attrs["presentationID"]!.string()
        let root = try RichJSON.parse(state, limit: 4096)
        let body = try root.object(required: ["observedAt", "expiresAt"], optional: ["theme", "rich"])
        _ = try body["observedAt"]!.number(); _ = try body["expiresAt"]!.number()
        if let theme = body["theme"] {
            guard DJConnectSessionMoodTheme(rawValue: try theme.string()) != nil else { throw invalid() }
        }
        if let rich = body["rich"] { try validateRich(rich) }
        let snapshot = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: state)
        guard snapshot.isCurrent(at: snapshot.observedAt) else { throw invalid() }
        if let rich = snapshot.rich {
            guard DJConnectPassiveSession.identifier(rich.bindingID), DJConnectPassiveSession.identifier(rich.generation),
                  rich.receivedUptime >= 0, rich.receivedAt <= snapshot.observedAt,
                  rich.isCurrent(at: snapshot.observedAt, uptime: rich.receivedUptime),
                  rich.expiresAt.timeIntervalSince(rich.receivedAt) <= 120,
                  snapshot.expiresAt <= rich.expiresAt,
                  rich.contribution != nil || rich.nowPlaying != nil else { throw invalid() }
            // Necessary per-field checks, independent of the aggregate lease.
            // Original owner/source bounds are a separate, mandatory comparison.
            for end in [rich.contribution?.expires_at, rich.nowPlaying?.expires_at].compactMap({ $0 }) {
                guard let date = DJConnectHistoryEntry.date(end), rich.expiresAt <= date else { throw invalid() }
            }
            if let field = rich.contribution {
                guard field.isCurrent(at: snapshot.observedAt) else { throw invalid() }
            }
            if let field = rich.nowPlaying {
                guard field.isCurrent(at: snapshot.observedAt) else { throw invalid() }
            }
            if let playback = rich.playbackState {
                guard rich.nowPlaying != nil, ["idle", "stopped", "playing", "paused"].contains(playback) else { throw invalid() }
            }
        }
        return snapshot
    }

    private static func validateRich(_ node: RichJSON) throws {
        guard node.range.count <= 2800 else { throw invalid() }
        let rich = try node.object(required: ["bindingID", "generation", "sequence", "receivedAt", "receivedUptime", "expiresAt"],
                                   optional: ["contribution", "nowPlaying", "playbackState"])
        for key in ["bindingID", "generation"] { _ = try rich[key]!.string() }
        guard try rich["sequence"]!.integer() >= 0 else { throw invalid() }
        for key in ["receivedAt", "receivedUptime", "expiresAt"] { _ = try rich[key]!.number() }
        if let state = rich["playbackState"] { _ = try state.string() }
        if let field = rich["contribution"] {
            let value = try field.object(required: ["moment_id", "published_at", "text", "persona", "source_attribution", "usage_basis", "expires_at"])
            try strings(value, except: "source_attribution"); try dictionary(value["source_attribution"]!)
        }
        if let field = rich["nowPlaying"] {
            let value = try field.object(required: ["item_id", "subject_uri", "track", "artist", "album", "observed_at", "expires_at", "source_url", "attribution", "usage_basis"])
            try strings(value, except: "attribution"); try dictionary(value["attribution"]!)
        }
    }
    private static func strings(_ object: [String: RichJSON], except: String) throws {
        for (key, value) in object where key != except { _ = try value.string() }
    }
    private static func dictionary(_ node: RichJSON) throws {
        guard case .object(let fields) = node.kind else { throw invalid() }
        for value in fields.values { _ = try value.string() }
    }
    private static func base64(_ value: String) throws -> Data {
        guard !value.isEmpty, value.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }),
              value.utf8.count % 4 != 1 else { throw invalid() }
        let padded = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            + String(repeating: "=", count: (4 - value.utf8.count % 4) % 4)
        guard let bytes = Data(base64Encoded: padded), !bytes.isEmpty,
              bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") == value else { throw invalid() }
        return bytes
    }
    private static func invalid() -> DJConnectError { .invalidResponse }
}

/// Bounded JSON syntax tree retaining original byte ranges. Unlike the frozen
/// integer-only v3 recognizer, Foundation Date numbers may be fractional. Null,
/// bool and arrays remain distinct and cannot become numbers or omitted fields.
private struct RichJSON {
    indirect enum Kind { case object([String: RichJSON]), array, string(String), number(String), other }
    let kind: Kind
    let range: Range<Int>
    func object(required: Set<String>, optional: Set<String> = []) throws -> [String: RichJSON] {
        guard case .object(let fields) = kind, required.isSubset(of: Set(fields.keys)),
              Set(fields.keys).isSubset(of: required.union(optional)) else { throw DJConnectError.invalidResponse }
        return fields
    }
    func string() throws -> String {
        guard case .string(let value) = kind else { throw DJConnectError.invalidResponse }; return value
    }
    func number() throws -> Double {
        guard case .number(let token) = kind, let value = Double(token), value.isFinite else { throw DJConnectError.invalidResponse }; return value
    }
    func integer() throws -> Int64 {
        guard case .number(let token) = kind, token.utf8.allSatisfy({ (48...57).contains($0) }), let value = Int64(token),
              (-9_007_199_254_740_991...9_007_199_254_740_991).contains(value) else { throw DJConnectError.invalidResponse }; return value
    }
    static func parse(_ data: Data, limit: Int) throws -> Self {
        guard !data.isEmpty, data.count <= limit, String(data: data, encoding: .utf8) != nil else { throw DJConnectError.invalidResponse }
        var parser = Parser(bytes: Array(data)); let node = try parser.value(depth: 0)
        parser.space(); guard parser.index == data.count else { throw DJConnectError.invalidResponse }; return node
    }
    private struct Parser {
        let bytes: [UInt8]
        var index = 0
        mutating func space() { while index < bytes.count && [9, 10, 13, 32].contains(bytes[index]) { index += 1 } }
        mutating func take(_ byte: UInt8) throws {
            space(); guard index < bytes.count, bytes[index] == byte else { throw DJConnectError.invalidResponse }; index += 1
        }
        mutating func string() throws -> String {
            space(); let start = index; try take(34)
            while index < bytes.count {
                if bytes[index] == 92 { index += 2; continue }
                if bytes[index] == 34 {
                    index += 1
                    return try JSONDecoder().decode(String.self, from: Data(bytes[start..<index]))
                }
                index += 1
            }
            throw DJConnectError.invalidResponse
        }
        mutating func value(depth: Int) throws -> RichJSON {
            space(); let start = index
            guard depth <= 16, index < bytes.count else { throw DJConnectError.invalidResponse }
            let kind: Kind
            switch bytes[index] {
            case 123:
                index += 1; space(); var fields: [String: RichJSON] = [:]
                if index < bytes.count, bytes[index] != 125 {
                    while true {
                        let key = try string(); guard fields[key] == nil else { throw DJConnectError.invalidResponse }
                        try take(58); fields[key] = try value(depth: depth + 1); space()
                        if index < bytes.count, bytes[index] == 125 { break }; try take(44)
                    }
                }
                try take(125); kind = .object(fields)
            case 91:
                index += 1; space()
                if index < bytes.count, bytes[index] != 93 {
                    while true {
                        _ = try value(depth: depth + 1); space()
                        if index < bytes.count, bytes[index] == 93 { break }; try take(44)
                    }
                }
                try take(93); kind = .array
            case 34: kind = .string(try string())
            case 116, 102, 110:
                let literal = Array((bytes[index] == 116 ? "true" : bytes[index] == 102 ? "false" : "null").utf8)
                guard index + literal.count <= bytes.count, Array(bytes[index..<index + literal.count]) == literal else { throw DJConnectError.invalidResponse }
                index += literal.count; kind = .other
            default:
                // JSONDecoder validates the entire numeric lexeme (leading zero,
                // exponent/fraction grammar); Double additionally rejects overflow.
                while index < bytes.count, ![9, 10, 13, 32, 44, 93, 125].contains(bytes[index]) { index += 1 }
                guard index > start else { throw DJConnectError.invalidResponse }
                let raw = Data(bytes[start..<index])
                let number = try JSONDecoder().decode(Double.self, from: raw)
                guard number.isFinite else { throw DJConnectError.invalidResponse }
                kind = .number(String(decoding: raw, as: UTF8.self))
            }
            return RichJSON(kind: kind, range: start..<index)
        }
    }
}
