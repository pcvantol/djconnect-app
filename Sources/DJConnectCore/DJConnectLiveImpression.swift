import Foundation

/// Core-owned original event/photo identity. Contains no image URL or display grant.
public struct DJConnectLiveImpression: Codable, Equatable, Sendable {
    public struct Source: Codable, Equatable, Sendable {
        public let provider: String
        public let url: String
        public let license: String
        public let title: String
        public var destination: URL? { DJConnectLiveImpression.sourceURL(url) }
        public var attributionLabel: String { [provider, license].joined(separator: " · ") }
        public var accessibilityLabel: String { [provider, title, license].joined(separator: " · ") }
    }
    public struct Event: Codable, Equatable, Sendable {
        public let eventID: String
        public let artist: String
        public let date: String
        public let datePrecision: String
        public let venue: String
        public let city: String
        public let relationship: String
        enum CodingKeys: String, CodingKey {
            case artist, date, venue, city, relationship
            case eventID = "event_id", datePrecision = "date_precision"
        }
        public var displayLine: String { [artist, venue, city, date].filter { !$0.isEmpty }.joined(separator: " · ") }
    }
    public struct Photo: Codable, Equatable, Sendable, Identifiable {
        public let photoID: String
        public let revision: String
        public let caption: String
        public let altText: [String: String]
        public let width: Int
        public let height: Int
        public let sourceURL: String
        public let author: String
        public let credit: String
        public let license: String
        public let licenseURL: String
        public var id: String { photoID }
        enum CodingKeys: String, CodingKey {
            case revision, caption, width, height, author, credit, license
            case photoID = "photo_id", altText = "alt_text", sourceURL = "source_url", licenseURL = "license_url"
        }
        public func accessibilityText(language: String) -> String { altText[language] ?? altText["en"] ?? caption }
        var isValid: Bool {
            [photoID, revision, caption, author, credit, license].allSatisfy { DJConnectLiveImpression.validText($0) }
                && width > 0 && height > 0 && width <= 4096 && height <= 4096 && width * height <= 16_000_000
                && revision.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
                && DJConnectLiveImpression.sourceURL(sourceURL) != nil && DJConnectLiveImpression.sourceURL(licenseURL) != nil
                && ["nl", "en", "de", "fr", "es"].allSatisfy { DJConnectLiveImpression.validText(altText[$0] ?? "") }
        }
    }
    public let schemaVersion: Int
    public let event: Event
    public let photos: [Photo]
    enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version", event, photos }
    public var isValid: Bool {
        schemaVersion == 1 && (1...3).contains(photos.count) && Set(photos.map(\.photoID)).count == photos.count
            && photos.allSatisfy(\.isValid)
            && [event.eventID, event.artist, event.venue].allSatisfy(Self.validText)
            && event.city.utf8.count <= 4096
            && ["same_artist", "song_performed", "exact_recording"].contains(event.relationship)
            && validEventDate
    }
    private var validEventDate: Bool {
        let pattern: String
        switch event.datePrecision {
        case "year": pattern = "^[0-9]{4}$"
        case "month": pattern = "^[0-9]{4}-(0[1-9]|1[0-2])$"
        case "day": pattern = "^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$"
        default: return false
        }
        guard event.date.range(of: pattern, options: .regularExpression) != nil else { return false }
        let parts = event.date.split(separator: "-").compactMap { Int($0) }
        guard let year = parts.first, year > 0 else { return false }
        if parts.count == 3 {
            let calendar = Calendar(identifier: .gregorian)
            let components = DateComponents(year: year, month: parts[1], day: parts[2])
            guard let date = calendar.date(from: components), calendar.dateComponents([.year, .month, .day], from: date) == components else { return false }
        }
        return true
    }
    static func validText(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= 4096 &&
            !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) && $0 != "\n" && $0 != "\t" }
    }
    public static func sourceURL(_ raw: String) -> URL? {
        guard raw.utf8.count <= 4096, let url = URL(string: raw), url.scheme == "https", url.host?.isEmpty == false,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
}

public extension DJConnectMoment {
    var isLiveImpressionV1: Bool {
        type == "live_impression" && liveImpression?.isValid == true && !title.isEmpty && !summary.isEmpty &&
            !content.isEmpty && content.unicodeScalars.count <= 4000 && knowledgeIntent?["type"] == "live_impression" &&
            artwork == nil && actions.isEmpty && settingsConfirmation == nil
    }
}

/// Invalid optional event/media metadata cannot erase an accepted historical narrative.
struct DJConnectOptionalLiveImpression: Codable, Equatable, Sendable {
    let value: DJConnectLiveImpression?
    init(value: DJConnectLiveImpression?) { self.value = value }
    init(from decoder: Decoder) throws { value = try? DJConnectLiveImpression(from: decoder) }
    func encode(to encoder: Encoder) throws {
        if let value { try value.encode(to: encoder) }
        else { var c = encoder.singleValueContainer(); try c.encodeNil() }
    }
}

public enum DJConnectLiveImpressionMediaError: Error, Equatable, Sendable { case withdrawn }
