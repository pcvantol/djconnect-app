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

private struct DJConnectProfileContextRequestsFixture: Decodable {
    var contractVersion: Int
    var requests: [String: DJConnectJSONValue]

    enum CodingKeys: String, CodingKey {
        case contractVersion = "contract_version"
        case requests
    }
}

private struct DJConnectProfileContextResponsesFixture: Decodable {
    var contractVersion: Int
    var responses: [String: DJConnectMusicDNAProfileResponse]

    enum CodingKeys: String, CodingKey {
        case contractVersion = "contract_version"
        case responses
    }
}

private struct DJConnectProfileContextErrorsFixture: Decodable {
    var contractVersion: Int
    var errors: [String: DJConnectProfileContextErrorFixture]

    enum CodingKeys: String, CodingKey {
        case contractVersion = "contract_version"
        case errors
    }
}

private struct DJConnectProfileContextErrorFixture: Decodable {
    var error: String
    var message: String
    var httpStatus: Int
    var retryable: Bool

    enum CodingKeys: String, CodingKey {
        case error
        case message
        case httpStatus = "http_status"
        case retryable
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
            "ask_dj.recently_played_history.json",
            "profile_context.requests.json",
            "profile_context.responses.json",
            "profile_context.errors.json"
        ])

        for fixture in manifest.fixtures {
            let data = try Self.fixtureData(fixture.file)
            let object = try JSONSerialization.jsonObject(with: data)
            #expect(object is [String: Any], "Fixture \(fixture.file) must be a JSON object.")
        }
    }

    @Test("Profile context fixtures decode canonical request, response and error contracts")
    func profileContextFixturesDecode() throws {
        let requests = try Self.decode(DJConnectProfileContextRequestsFixture.self, file: "profile_context.requests.json")
        #expect(requests.contractVersion == 1)
        guard case let .object(appleRequest) = try #require(requests.requests["apple_explicit_profile"]) else {
            Issue.record("Expected apple_explicit_profile object")
            return
        }
        #expect(appleRequest["profile_id"] == .string("profile-peter"))
        #expect(appleRequest["device_id"] == .string("djconnect-ios-ABCDEF123456"))
        #expect(appleRequest["client_type"] == .string("ios"))
        #expect(appleRequest["private_session"] == .bool(false))
        #expect(appleRequest["request_source"] == .string("ask_dj"))

        let responses = try Self.decode(DJConnectProfileContextResponsesFixture.self, file: "profile_context.responses.json")
        let personal = try #require(responses.responses["personal_profile"])
        #expect(personal.profileID == "profile-peter")
        #expect(personal.musicDNAKey == "profile:profile-peter")
        #expect(personal.resolvedProfile?.privacyMode == "normal")
        #expect(personal.resolution?.source == "device_mapping")
        #expect(personal.resolution?.fallbackUsed == false)

        let errors = try Self.decode(DJConnectProfileContextErrorsFixture.self, file: "profile_context.errors.json")
        #expect(errors.contractVersion == 1)
        #expect(errors.errors["profile_required"]?.error == "profile_required")
        #expect(errors.errors["device_not_mapped"]?.error == "device_not_mapped")
        #expect(errors.errors["private_session_restriction"]?.retryable == false)
    }

    @Test("Profile-aware requests generate canonical context envelope for Apple and watchOS")
    func profileAwareRequestsGenerateCanonicalEnvelope() throws {
        let tokenStore = DJConnectInMemoryTokenStore(token: "test-token")
        let identity = DJConnectIdentity(
            deviceID: "djconnect-ios-ABCDEF123456",
            deviceName: "DJConnect iPhone",
            clientType: .ios,
            firmware: "3.3.0",
            platform: .ios
        )
        let client = DJConnectClient(baseURL: URL(string: "http://ha.local:8123")!, identity: identity, tokenStore: tokenStore)
        let profileContext = DJConnectProfileContext(
            profileID: "profile-peter",
            sessionID: "session-apple-1",
            privateSession: true,
            requestSource: .askDJ
        )
        let askRequest = DJConnectAskDJRequest(
            identity: identity,
            text: "Wat past nu?",
            profileContext: profileContext
        )
        let request = try client.askDJMessageRequest(askRequest)
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["profile_id"] as? String == "profile-peter")
        #expect(json["device_id"] as? String == "djconnect-ios-ABCDEF123456")
        #expect(json["client_type"] as? String == "ios")
        #expect(json["session_id"] as? String == "session-apple-1")
        #expect(json["private_session"] as? Bool == true)
        #expect(json["request_source"] as? String == "ask_dj")

        let feedRequest = try client.musicDiscoveryFeedRequest(
            musicDNAKey: "profile:profile-peter",
            language: "nl-NL",
            profileContext: DJConnectProfileContext(profileID: "profile-peter", privateSession: true, requestSource: .discover)
        )
        let feedURL = try #require(feedRequest.url)
        let components = try #require(URLComponents(url: feedURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in item.value.map { (item.name, $0) } })
        #expect(query["profile_id"] == "profile-peter")
        #expect(query["private_session"] == "true")
        #expect(query["request_source"] == "discover")
        #expect(feedRequest.value(forHTTPHeaderField: "X-DJConnect-Profile-ID") == "profile-peter")
        #expect(feedRequest.value(forHTTPHeaderField: "X-DJConnect-Private-Session") == "true")

        let watchIdentity = DJConnectIdentity(
            deviceID: "djconnect-watchos-ABCDEF123456",
            deviceName: "DJConnect Watch",
            clientType: .watchos,
            firmware: "3.3.0",
            platform: .watchos
        )
        let watchPayload = DJConnectMusicDNAIdentityRequest(
            identity: watchIdentity,
            profileContext: DJConnectProfileContext(profileID: "profile-peter", privateSession: false, requestSource: .discover)
        )
        let encoded = try JSONEncoder().encode(watchPayload)
        let decoded = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        #expect(decoded?["device_id"] as? String == "djconnect-watchos-ABCDEF123456")
        #expect(decoded?["client_type"] as? String == "watchos")
        #expect(decoded?["profile_id"] as? String == "profile-peter")
        #expect(decoded?["private_session"] as? Bool == false)
        #expect(decoded?["request_source"] as? String == "discover")
    }

    @Test("Profile platform errors classify into typed non-auth failures")
    func profilePlatformErrorsClassify() throws {
        let client = DJConnectClient(
            baseURL: URL(string: "http://ha.local:8123")!,
            identity: DJConnectIdentity(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "iPhone", clientType: .ios, firmware: "3.3.0", platform: .ios),
            tokenStore: DJConnectInMemoryTokenStore(token: "test-token")
        )

        let required = client.classify(statusCode: 428, body: Data(#"{"success":false,"error":"profile_required","message":"A DJConnect Profile is required."}"#.utf8))
        #expect(required == .profile(code: .profileRequired, statusCode: 428, message: "A DJConnect Profile is required."))

        let mapped = client.classify(statusCode: 409, body: Data(#"{"success":false,"error":"device_not_mapped","message":"Device is not mapped to a profile."}"#.utf8))
        #expect(mapped == .profile(code: .deviceNotMapped, statusCode: 409, message: "Device is not mapped to a profile."))

        let privateSession = client.classify(statusCode: 409, body: Data(#"{"success":false,"error":"private_session_restriction","message":"This action is not available during a private session."}"#.utf8))
        #expect(privateSession == .profile(code: .privateSessionRestriction, statusCode: 409, message: "This action is not available during a private session."))
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
