import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

private struct DJConnectContractManifest: Decodable {
    var fixtures: [Fixture]

    struct Fixture: Decodable {
        var id: String
        var file: String
        var contract: String
        var state: String?
        var intent: String?
    }
}

private struct DJConnectCapabilitiesFixture: Decodable {
    var websocketSupported: Bool
    var commands: [String]
    var features: Features
    var fallbacks: [String: Fallback]

    enum CodingKeys: String, CodingKey {
        case websocketSupported = "websocket_supported"
        case commands
        case features
        case fallbacks
    }

    struct Features: Decodable {
        var musicDNA: Bool
        var musicDiscovery: Bool
        var musicDiscoveryFeedback: Bool

        enum CodingKeys: String, CodingKey {
            case musicDNA = "music_dna"
            case musicDiscovery = "music_discovery"
            case musicDiscoveryFeedback = "music_discovery_feedback"
        }
    }

    struct Fallback: Decodable {
        var available: Bool
        var preferredTransport: String?
        var httpPath: String?
        var httpPaths: [String: String]?
        var missingBehavior: String?

        enum CodingKeys: String, CodingKey {
            case available
            case preferredTransport = "preferred_transport"
            case httpPath = "http_path"
            case httpPaths = "http_paths"
            case missingBehavior = "missing_behavior"
        }

        var hasHTTPFallback: Bool {
            httpPath?.isEmpty == false || httpPaths?.isEmpty == false
        }
    }
}

@Suite("DJConnect HA Client Contract Fixtures")
struct DJConnectClientContractFixtureTests {
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    @Test("Manifest lists and loads every exported HA client contract fixture")
    func manifestLoadsEveryFixture() throws {
        let manifest = try Self.manifest()
        #expect(manifest.fixtures.map(\.file) == [
            "capabilities.websocket.json",
            "music_dna.profile.disabled.json",
            "music_dna.profile.empty.json",
            "music_dna.profile.rich.json",
            "music_discovery.feed.json",
            "ask_dj.recently_played_history.json"
        ])

        for fixture in manifest.fixtures {
            let data = try Self.fixtureData(fixture.file)
            let object = try JSONSerialization.jsonObject(with: data)
            #expect(object is [String: Any], "Fixture \(fixture.file) must be a JSON object.")
        }
    }

    @Test("Capabilities fixture advertises WebSocket routes and HTTP fallbacks without version gating")
    func capabilitiesFixtureDecodesRoutesAndFallbacks() throws {
        let capabilities = try Self.decode(DJConnectCapabilitiesFixture.self, file: "capabilities.websocket.json")
        #expect(capabilities.websocketSupported)
        #expect(capabilities.features.musicDNA)
        #expect(capabilities.features.musicDiscovery)
        #expect(capabilities.features.musicDiscoveryFeedback)

        let commandSet = Set(capabilities.commands)
        let requiredRoutes: Set<DJConnectFastPathRoute> = [
            .musicDNAProfile,
            .musicDNASettings,
            .musicDNAClear,
            .musicDNAImport,
            .musicDNAExport,
            .musicDiscoveryFeed,
            .musicDiscoveryRefresh,
            .musicDiscoveryPlay,
            .musicDiscoveryFeedback
        ]
        #expect(requiredRoutes.allSatisfy { commandSet.contains($0.rawValue) })
        #expect(Set(DJConnectFastPathRoute.allCases.map(\.rawValue)).isSuperset(of: commandSet))

        #expect(capabilities.fallbacks["music_dna"]?.hasHTTPFallback == true)
        #expect(capabilities.fallbacks["music_discovery"]?.hasHTTPFallback == true)
        #expect(capabilities.fallbacks["music_discovery_feedback"]?.httpPath == "/api/djconnect/v1/music_discovery/feedback")
        #expect(capabilities.fallbacks["music_discovery_feedback"]?.missingBehavior == "hide_negative_feedback_controls")
    }

    @Test("Music DNA fixtures decode disabled, empty and rich profile states")
    func musicDNAFixturesDecodeBackendOwnedState() throws {
        let disabled = try Self.decode(DJConnectMusicDNAProfileResponse.self, file: "music_dna.profile.disabled.json")
        #expect(disabled.enabled == false)
        #expect(disabled.musicDNAKey == "user:ha-user-1")
        #expect(disabled.profile.isEmpty)
        #expect(disabled.profile.recentTracks?.isEmpty != false)

        let empty = try Self.decode(DJConnectMusicDNAProfileResponse.self, file: "music_dna.profile.empty.json")
        #expect(empty.enabled)
        #expect(empty.profile.summary == "Music DNA staat aan, maar er is nog niet genoeg luistercontext.")
        #expect(empty.profile.recentTracks?.isEmpty != false)
        #expect(empty.profile.topTracksByRange.isEmpty)
        #expect(empty.profile.snapshotHistory.isEmpty)
        let emptyPrivacy = try #require(empty.profile.privacyDashboard)
        #expect(emptyPrivacy.enabled == true)
        #expect(emptyPrivacy.activeDataSources == ["Recent tracks (disabled)"])
        #expect(emptyPrivacy.controls == ["clear_supported": true])
        #expect(emptyPrivacy.storesRawAudio == false)
        #expect(emptyPrivacy.storesOAuthTokens == false)
        #expect(emptyPrivacy.storesFullPrompts == false)

        let rich = try Self.decode(DJConnectMusicDNAProfileResponse.self, file: "music_dna.profile.rich.json")
        #expect(rich.enabled)
        #expect(rich.profile.summary == "Je Music DNA leunt naar indie, ambient en artiesten als The xx.")
        #expect(rich.profile.recentTracks?.map(\.title) == ["Intro"])
        #expect(rich.profile.topTracksByRange["short_term"]?.first?.uri == "spotify:track:intro")
        #expect(rich.profile.topArtistsByRange["short_term"]?.first?.name == "The xx")
        #expect(rich.profile.snapshotHistory.first?.topTracks.first?.title == "Intro")
        #expect(rich.profile.discoveryFeedback?.acceptedRecommendations.first?.title == "Discovery Track")
        #expect(rich.profile.discoveryFeedback?.hiddenArtists.first?.name == "Blocked Artist")
        let richPrivacy = try #require(rich.profile.privacyDashboard)
        #expect(richPrivacy.activeDataSources == [
            "Spotify recent/top profile snapshots",
            "Recommendation feedback",
            "Negative feedback"
        ])
        #expect(richPrivacy.controls == ["clear_supported": true])
        #expect(richPrivacy.storesRawAudio == false)
        #expect(richPrivacy.storesOAuthTokens == false)
        #expect(richPrivacy.storesFullPrompts == false)
    }

    @Test("Music Discovery fixture renders backend sections and item quality fields in order")
    func musicDiscoveryFixturePreservesBackendOwnedFeed() throws {
        let feed = try Self.decode(DJConnectMusicDiscoveryResponse.self, file: "music_discovery.feed.json")
        #expect(feed.enabled)
        #expect(feed.revision == 1)
        #expect(feed.cache?.hit == false)
        #expect(feed.musicDNAKey == "user:ha-user-1")
        #expect(feed.sections.map(\.id) == ["new_for_you"])
        #expect(feed.visibleSections.map(\.id) == ["new_for_you"])

        let section = try #require(feed.sections.first)
        #expect(section.title == "Nieuw voor jou")
        #expect(section.items.map(\.id) == ["disc-example"])
        let item = try #require(section.items.first)
        #expect(item.kind == .track)
        #expect(item.title == "Fresh Discovery")
        #expect(item.subtitle == "New Artist")
        #expect(item.uri == "spotify:track:fresh-discovery")
        #expect(item.imageURL == "/api/djconnect/v1/image_proxy/example")
        #expect(item.reason == "Omdat je vaak naar The xx luistert en indie in je Music DNA zit.")
        #expect(item.reasonSources == [
            "spotify_recommendations",
            "djconnect_music_dna",
            "music_dna_artists",
            "music_dna_genres"
        ])
        #expect(item.confidence == .medium)
        #expect(item.qualityScore == 88)
        #expect(item.qualityBand == "high")
        #expect(item.qualityFactors == [
            "spotify_recommendation",
            "fresh_candidate",
            "has_artwork"
        ])

        let identity = DJConnectIdentity(
            deviceID: "djconnect-ios-contract",
            deviceName: "iPhone",
            clientType: .ios,
            firmware: "iOS",
            platform: .ios
        )
        let play = DJConnectMusicDiscoveryPlayRequest(discoveryItemID: item.id, sectionID: section.id, identity: identity, musicDNAKey: feed.musicDNAKey)
        #expect(play.sectionID == "new_for_you")
        #expect(play.discoveryItemID == "disc-example")
        #expect(play.musicDNAKey == "user:ha-user-1")

        let feedback = DJConnectMusicDiscoveryFeedbackRequest(discoveryItemID: item.id, sectionID: section.id, feedback: .notForMe, identity: identity, musicDNAKey: feed.musicDNAKey)
        #expect(feedback.sectionID == "new_for_you")
        #expect(feedback.discoveryItemID == "disc-example")
        #expect(feedback.feedback == DJConnectMusicDiscoveryFeedback.notForMe)
    }

    @Test("Ask DJ recently played fixture renders informational items without stale playback actions")
    @MainActor
    func askDJRecentlyPlayedFixtureMapsCurrentResponseOnly() throws {
        let response = try Self.decode(DJConnectAskDJMessageResponse.self, file: "ask_dj.recently_played_history.json")
        #expect(response.intentInfo?.intent == "recently_played_history")
        #expect(response.intentInfo?.action == "recently_played")
        #expect(response.items?.map(\.title) == ["Bella"])
        #expect(response.items?.first?.imageURL?.absoluteString == "/api/djconnect/v1/image_proxy/example")
        #expect(response.items?.first?.thumbnailURL?.absoluteString == "/api/djconnect/v1/image_proxy/example")
        #expect(response.playbackActions == [])
        #expect(response.confirmationActions == [])

        let model = DJConnectAppModel(
            defaults: UserDefaults(suiteName: "DJConnectClientContractFixtureTests.\(UUID().uuidString)")!,
            startBackgroundTasks: false,
            monkeyTestingMode: true
        )
        model.applyAskDJMessageResponse(
            DJConnectAskDJMessageResponse(
                assistantMessage: DJConnectAskDJHistoryMessage(
                    id: "old-response",
                    role: .assistant,
                    text: "Oude bubble",
                    createdAt: Date(timeIntervalSince1970: 1),
                    images: [
                        DJConnectResponseImage(url: URL(string: "https://example.test/old-artwork.jpg")!)
                    ],
                    playbackActions: [
                        DJConnectAskDJPlaybackAction(id: "old-play", title: "Old play", uri: "spotify:track:old")
                    ]
                )
            ),
            fallbackUserMessageID: nil
        )

        model.applyAskDJMessageResponse(response, fallbackUserMessageID: nil)

        let latest = try #require(model.askDJMessages.last)
        #expect(latest.intentInfo?.intent == "recently_played_history")
        #expect(latest.items.map(\.title) == ["Bella"])
        #expect(latest.items.first?.imageURL?.path == "/api/djconnect/v1/image_proxy/example")
        #expect(latest.images.map(\.url.path) == ["/api/djconnect/v1/image_proxy/example"])
        #expect(latest.playbackActions.isEmpty)
        #expect(!latest.images.contains { $0.url.absoluteString == "https://example.test/old-artwork.jpg" })
    }

    private static func manifest() throws -> DJConnectContractManifest {
        try decode(DJConnectContractManifest.self, file: "manifest.json")
    }

    private static func decode<T: Decodable>(_ type: T.Type, file: String) throws -> T {
        try decoder.decode(T.self, from: fixtureData(file))
    }

    private static func fixtureData(_ file: String) throws -> Data {
        let fixtureURL = try #require(
            Bundle.module.url(forResource: file, withExtension: nil, subdirectory: "DJConnectContracts")
                ?? Bundle.module.url(forResource: file, withExtension: nil, subdirectory: "Fixtures/DJConnectContracts")
        )
        return try Data(contentsOf: fixtureURL)
    }
}
