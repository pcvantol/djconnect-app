import Foundation
import CoreFoundation

/// Detached presentation data from Core's R5 design, wire schema version 1.
/// Never a command, execution receipt, pairing repair or catalogue adoption offer.
public struct DJConnectAskDJHelpObservation: Sendable {
    public struct Request: Sendable {
        public let id: String
        public let surface: DJConnectAskDJCatalogue.Surface
        public let language: String
        public let sessionID: String?
        public init(surface: DJConnectAskDJCatalogue.Surface, language: String, sessionID: String?) throws {
            guard ["en", "nl", "de", "fr", "es"].contains(language),
                  sessionID.map({ Self.identifier($0, limit: 256) }) ?? (surface == .askDJ) else { throw DJConnectError.invalidResponse }
            id = UUID().uuidString.lowercased(); self.surface = surface
            self.language = language; self.sessionID = sessionID
        }
        static func identifier(_ value: String, limit: Int) -> Bool {
            !value.isEmpty && value.utf8.count <= limit && value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
                !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) || $0.properties.generalCategory == .format }
        }
        func query() -> String {
            var fields = [("schema_version", "1"), ("request_id", id), ("surface", surface.rawValue),
                          ("language", language), ("catalogue_id", "ask_dj_examples_v1"),
                          ("catalogue_revision", "2"), ("catalogue_sha256", DJConnectAskDJCatalogue.pinnedSHA256)]
            if let sessionID { fields.append(("session_id", sessionID)) }
            let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
            return fields.map { $0.0 + "=" + $0.1.addingPercentEncoding(withAllowedCharacters: allowed)! }.joined(separator: "&")
        }
    }
    public let available: Bool
    public let trackID: String?
    public let eligibleIDs: Set<String>

    public static func decode(_ bytes: Data, matching request: Request, catalogue: DJConnectAskDJCatalogue) throws -> Self {
        guard bytes.count <= 16384 else { throw DJConnectError.invalidResponse }
        // Reuse the bounded integer-only lexical recognizer before dictionaries
        // can erase duplicate keys or Foundation can coerce numeric lexemes.
        try DJConnectSurfacePushJSON.validate(bytes)
        guard let o = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              Set(o.keys) == ["schema_version", "request_id", "surface", "language", "session_id", "track_id", "catalogue", "available", "observation_id", "eligible_entry_ids"],
              let version = o["schema_version"] as? NSNumber, version.intValue == 1, CFGetTypeID(version) != CFBooleanGetTypeID(),
              o["request_id"] as? String == request.id, o["surface"] as? String == request.surface.rawValue,
              o["language"] as? String == request.language,
              request.sessionID.map({ o["session_id"] as? String == $0 }) ?? (o["session_id"] is NSNull),
              let flag = o["available"] as? NSNumber, CFGetTypeID(flag) == CFBooleanGetTypeID(),
              let ids = o["eligible_entry_ids"] as? [String], ids.count <= 14 else { throw DJConnectError.invalidResponse }
        var descriptor: DJConnectAskDJCatalogue.Descriptor?
        if let d = o["catalogue"] as? [String: Any] {
            guard Set(d.keys) == ["schema_version", "catalogue_id", "revision", "sha256", "qualified"],
                  let qualified = d["qualified"] as? NSNumber, CFGetTypeID(qualified) == CFBooleanGetTypeID() else { throw DJConnectError.invalidResponse }
            descriptor = try JSONDecoder().decode(DJConnectAskDJCatalogue.Descriptor.self, from: JSONSerialization.data(withJSONObject: d))
            guard let descriptor, descriptor.schema_version == 1, descriptor.revision == 2,
                  descriptor.catalogue_id == "ask_dj_examples_v1", descriptor.sha256 == DJConnectAskDJCatalogue.pinnedSHA256 else { throw DJConnectError.invalidResponse }
        } else if !(o["catalogue"] is NSNull) { throw DJConnectError.invalidResponse }
        let available = flag.boolValue
        guard available else {
            guard ids.isEmpty, o["track_id"] is NSNull, o["observation_id"] is NSNull else { throw DJConnectError.invalidResponse }
            return .init(available: false, trackID: nil, eligibleIDs: [])
        }
        guard descriptor?.qualified == true, let observation = o["observation_id"] as? String,
              observation.range(of: "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", options: .regularExpression) != nil,
              Set(ids).count == ids.count, catalogue.entries.map(\.id).filter({ ids.contains($0) }) == ids else { throw DJConnectError.invalidResponse }
        let track = o["track_id"] as? String
        guard track.map({ request.sessionID != nil && Request.identifier($0, limit: 1024) }) ?? (o["track_id"] is NSNull),
              track != nil || !catalogue.entries.contains(where: { ids.contains($0.id) && $0.requires.contains("current_track") }) else { throw DJConnectError.invalidResponse }
        return .init(available: true, trackID: track, eligibleIDs: Set(ids))
    }
}
