import Foundation
import CryptoKit

/// Presentation only. Execution always sends the displayed text through Ask DJ.
public struct DJConnectAskDJCatalogue: Decodable, Sendable {
    public static let pinnedSHA256 = "dfaa98a1659ef5673037da26f98136314b314beea8afe8e31af4ffd5bd6ac4e7"
    public enum Surface: String, Sendable { case askDJ = "ask_dj", session = "active_session" }
    public struct Descriptor: Decodable, Equatable, Sendable {
        public let schema_version: Int
        public let qualified: Bool
        public let catalogue_id: String
        public let revision: Int
        public let sha256: String
    }
    public struct Capabilities: Decodable, Sendable {
        public let success: Bool
        public let capabilities: [String: Bool]?
        public let contract_versions: [String: Int]?
        public let ask_dj_examples: Descriptor?
        enum CodingKeys: String, CodingKey { case success, capabilities, contract_versions, ask_dj_examples }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            success = try c.decode(Bool.self, forKey: .success)
            capabilities = try? c.decode([String: Bool].self, forKey: .capabilities)
            contract_versions = try? c.decode([String: Int].self, forKey: .contract_versions)
            // An additive incompatible descriptor must not break normal status/settings.
            ask_dj_examples = try? c.decode(Descriptor.self, forKey: .ask_dj_examples)
        }
    }
    public struct Context: Equatable, Sendable {
        public var descriptor: Descriptor?
        public var contracts: [String: Int] = [:]
        public var flags: [String: Bool] = [:]
        public var slots: [String: String] = [:]
        /// Installation/runtime scope only; never persisted as user intelligence.
        public var ownerEpoch = ""
        public var sessionID: String?
        public var trackID: String?
        public var settingsIdentity = ""
        public init() {}
    }
    struct Qualification: Decodable, Sendable { let state: String }
    struct Entry: Decodable, Sendable {
        let id: String
        let intent: String
        let group: String
        let surfaces: [String]
        let requires: [String]
        let contracts: [String: Int]
        let slots: [String]
        let contextual: Bool
        let help_rank: Int
        let publication: String
        let templates: [String: String]
        let qualification: [String: Qualification]
    }
    struct Group: Decodable, Sendable { let id: String; let labels: [String: String] }
    public struct Suggestion: Equatable, Sendable, Identifiable {
        public let id: String
        public let intent: String
        public let group: String
        public let prompt: String
        let ownerEpoch: String
        let sessionID: String?
        let trackID: String?
    }
    public struct HelpSection: Equatable, Sendable, Identifiable {
        public let id: String
        public let title: String
        public let examples: [String]
    }
    let schema_version: Int
    let catalogue_id: String
    let revision: Int
    let language_families: [String]
    let status: String
    let groups: [Group]
    let slot_labels: [String: [String: String]]
    let intro: [String: String]
    let unavailable: [String: String]
    let entries: [Entry]

    public static let bundled: Self? = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: AskDJCatalogueBundleToken.self)
        #endif
        guard let url = bundle.url(forResource: "ask_dj_examples_v1", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return verified(data: data)
    }()

    public static func verified(data: Data) -> Self? {
        guard hash(data) == pinnedSHA256 else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private func locale(_ language: String) -> String? {
        let family = language.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-").first.map(String.init) ?? ""
        return language_families.contains(family) ? family : nil
    }
    public func compatible(_ context: Context) -> Bool {
        guard status == "qualified_v1", let d = context.descriptor, d.qualified else { return false }
        return d.schema_version == schema_version && d.catalogue_id == catalogue_id &&
            d.revision == revision && d.sha256 == Self.pinnedSHA256 && context.contracts["ask_dj_examples"] == 1
    }
    static func safeSlot(_ value: String?) -> Bool {
        guard let value, !value.isEmpty, value.unicodeScalars.count <= 160,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !value.unicodeScalars.contains { $0.value < 32 || "{}[]".unicodeScalars.contains($0) }
    }
    private func eligible(_ context: Context, surface: Surface, language: String, help: Bool = false) -> [Entry] {
        guard let language = locale(language), compatible(context),
              surface != .session || context.flags["active_session"] == true else { return [] }
        return entries.filter { e in
            e.publication == "qualified_v1" && e.qualification[language]?.state == "qualified_owner_route" &&
                e.surfaces.contains(surface.rawValue) && e.requires.allSatisfy { context.flags[$0] == true } &&
                e.contracts.allSatisfy { context.contracts[$0.key] == $0.value } &&
                (help || e.slots.allSatisfy { Self.safeSlot(context.slots[$0]) })
        }
    }
    private func prompt(_ entry: Entry, language: String, slots: [String: String], help: Bool = false) -> String? {
        guard let language = locale(language), var value = entry.templates[language] else { return nil }
        for slot in entry.slots {
            guard let replacement = help ? slot_labels[slot]?[language] : slots[slot] else { return nil }
            value = value.replacingOccurrences(of: "{" + slot + "}", with: replacement)
        }
        // Never expose an unresolved executable template.
        guard !value.contains("{"), !value.contains("}"), help || (!value.contains("[") && !value.contains("]")) else { return nil }
        return value
    }
    public func select(_ context: Context, surface: Surface, language: String, epoch: String, recent: [String] = []) -> [Suggestion] {
        let recent = Set(recent.suffix(6))
        func rank(_ entry: Entry) -> (Int, String) {
            (recent.contains(entry.id) ? 1 : 0, Self.hash(Data((String(epoch.prefix(128)) + ":" + entry.id).utf8)))
        }
        let candidates = eligible(context, surface: surface, language: language).sorted { rank($0) < rank($1) }
        var chosen: [Entry] = []
        if let contextual = candidates.first(where: \.contextual) { chosen.append(contextual) }
        while chosen.count < 3 {
            let usedGroups = Set(chosen.map(\.group))
            let rest = candidates.filter { entry in !chosen.contains { $0.id == entry.id || $0.intent == entry.intent } }.sorted {
                let left = (usedGroups.contains($0.group) ? 1 : 0, rank($0).0, rank($0).1)
                let right = (usedGroups.contains($1.group) ? 1 : 0, rank($1).0, rank($1).1)
                return left < right
            }
            guard let next = rest.first else { break }; chosen.append(next)
        }
        let result = chosen.compactMap { entry -> Suggestion? in
            guard let text = prompt(entry, language: language, slots: context.slots) else { return nil }
            return Suggestion(id: entry.id, intent: entry.intent, group: entry.group, prompt: text,
                              ownerEpoch: context.ownerEpoch, sessionID: surface == .session ? context.sessionID : nil,
                              trackID: entry.contextual || !entry.slots.isEmpty ? context.trackID : nil)
        }
        return result.count == 3 ? result : []
    }
    public func retains(_ suggestion: Suggestion, context: Context, surface: Surface, language: String) -> Bool {
        guard suggestion.ownerEpoch == context.ownerEpoch,
              surface != .session || suggestion.sessionID == context.sessionID,
              suggestion.trackID == nil || suggestion.trackID == context.trackID else { return false }
        return eligible(context, surface: surface, language: language).contains {
            $0.id == suggestion.id && prompt($0, language: language, slots: context.slots) == suggestion.prompt
        }
    }
    public func helpSections(_ context: Context, surface: Surface = .askDJ, language: String) -> [HelpSection] {
        guard let language = locale(language) else { return [] }
        let candidates = eligible(context, surface: surface, language: language, help: true)
        var sections = groups.prefix(3).compactMap { group -> HelpSection? in
            let examples = candidates.filter { $0.group == group.id }.sorted {
                ($0.help_rank, $0.id) < ($1.help_rank, $1.id)
            }.prefix(2).compactMap { prompt($0, language: language, slots: [:], help: true) }
            guard !examples.isEmpty, let title = group.labels[language] else { return nil }
            return HelpSection(id: group.id, title: title, examples: examples)
        }
        if context.flags["active_session"] == true && context.flags["current_track"] == true,
           let i = sections.firstIndex(where: { $0.id == groups.last?.id }) {
            sections.insert(sections.remove(at: i), at: 0)
        }
        return sections
    }
    public func unavailableText(language: String) -> String { unavailable[locale(language) ?? "en"] ?? "" }
}
private final class AskDJCatalogueBundleToken {}

/// A viewing epoch, not a timer. During editing/reading only revoke invalid rows.
public struct DJConnectAskDJSuggestionCursor: Sendable {
    public private(set) var suggestions: [DJConnectAskDJCatalogue.Suggestion] = []
    private var recent: [String] = []
    private var context: DJConnectAskDJCatalogue.Context?
    private var language: String?
    private var pendingSelection = false
    public init() {}
    public mutating func update(catalogue: DJConnectAskDJCatalogue?, context next: DJConnectAskDJCatalogue.Context,
                                surface: DJConnectAskDJCatalogue.Surface, language: String, frozen: Bool,
                                visit: Bool = false, refresh: Bool = false, epoch: String = UUID().uuidString) {
        let ownerChanged = context?.ownerEpoch != next.ownerEpoch
        let changed = context != next || self.language != language
        guard visit || refresh || changed || pendingSelection else { return }
        if ownerChanged { suggestions = []; recent = [] }
        suggestions = suggestions.filter { catalogue?.retains($0, context: next, surface: surface, language: language) == true }
        context = next; self.language = language
        if frozen { pendingSelection = pendingSelection || visit || refresh || changed; return }
        pendingSelection = false
        guard let catalogue else { suggestions = []; return }
        let selected = catalogue.select(next, surface: surface, language: language, epoch: epoch, recent: recent)
        if selected.count == 3 { recent = Array((recent + selected.map(\.id)).suffix(6)) }
        suggestions = selected
    }
}
