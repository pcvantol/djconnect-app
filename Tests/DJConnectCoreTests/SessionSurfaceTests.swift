import Foundation
import Testing
import DJConnectCore
import DJConnectUI

@Test func sessionSurfaceRequiresConfirmedAuthorizedActiveSession() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    #expect(DJConnectSessionSurfaceSnapshot.observe(runtimeState: "active", authorized: true, isDemo: false, at: now) != nil)
    for state: String? in [nil, "ended", "interrupted", "opening", "unknown"] {
        #expect(DJConnectSessionSurfaceSnapshot.observe(runtimeState: state, authorized: true, isDemo: false, at: now) == nil)
    }
    #expect(DJConnectSessionSurfaceSnapshot.observe(runtimeState: "active", authorized: false, isDemo: false, at: now) == nil)
    #expect(DJConnectSessionSurfaceSnapshot.observe(runtimeState: "active", authorized: true, isDemo: true, at: now) == nil)
}

@Test func sessionSurfaceLeaseCannotSlideOnReadOrShowFutureOrExpiredStatus() throws {
    let suite = "session-surface-test-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let snapshot = DJConnectSessionSurfaceSnapshot(observedAt: now)
    try DJConnectSessionSurfaceSnapshot.replace(snapshot, in: defaults)
    for seconds in [0.0, 60, 119.999] {
        #expect(DJConnectSessionSurfaceSnapshot.load(from: defaults, at: now.addingTimeInterval(seconds)) == snapshot)
    }
    for seconds in [-1.0, 120, 300] {
        #expect(DJConnectSessionSurfaceSnapshot.load(from: defaults, at: now.addingTimeInterval(seconds)) == nil)
    }
    let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
    #expect(Set(object.keys) == ["observedAt", "expiresAt"])
    var forged = object
    forged["expiresAt"] = snapshot.expiresAt.timeIntervalSinceReferenceDate + 600
    defaults.set(try JSONSerialization.data(withJSONObject: forged), forKey: DJConnectSessionSurfaceSnapshot.storageKey)
    #expect(DJConnectSessionSurfaceSnapshot.load(from: defaults, at: now) == nil)
}

@Test func sessionSurfaceMigrationRemovesOnlyRetiredTransientCachesAndDeduplicatesWrites() throws {
    let suite = "session-surface-test-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let retired = [DJConnectNowPlayingWidgetSnapshot.storageKey, DJConnectQueueWidgetSnapshot.storageKey,
                   DJConnectTrackInsightWidgetSnapshot.storageKey, DJConnectAskDJWidgetSnapshot.storageKey,
                   DJConnectPlaylistsWidgetSnapshot.storageKey]
    for key in retired { defaults.set(Data("PRIVATE OLD PAYLOAD".utf8), forKey: key) }
    defaults.set("keep history", forKey: "AskDJMessages")
    defaults.set(75, forKey: "DJConnectAskDJMood")
    let snapshot = DJConnectSessionSurfaceSnapshot(observedAt: Date())
    #expect(try DJConnectSessionSurfaceSnapshot.replace(snapshot, in: defaults))
    #expect(try !DJConnectSessionSurfaceSnapshot.replace(snapshot, in: defaults))
    for key in retired { #expect(defaults.object(forKey: key) == nil) }
    #expect(defaults.string(forKey: "AskDJMessages") == "keep history")
    #expect(defaults.integer(forKey: "DJConnectAskDJMood") == 75)
    #expect(try DJConnectSessionSurfaceSnapshot.replace(nil, in: defaults))
    #expect(defaults.object(forKey: DJConnectSessionSurfaceSnapshot.storageKey) == nil)
    #expect(defaults.string(forKey: "AskDJMessages") == "keep history")
}

@Test func sessionSurfaceNavigationIsExplicitAndDoesNotRetargetLegacyDestinations() throws {
    #expect(DJConnectHomeScreenAction(deepLinkURL: try #require(URL(string: "djconnect://dj-session"))) == .djSession)
    #expect(DJConnectHomeScreenAction(deepLinkURL: try #require(URL(string: "djconnect://ask-dj"))) == .askDJ)
    #expect(DJConnectHomeScreenAction(deepLinkURL: try #require(URL(string: "djconnect://now-playing"))) == .nowPlaying)
    #expect(DJConnectHomeScreenAction(deepLinkURL: try #require(URL(string: "djconnect://unknown-session-action"))) == nil)
}


@Test func sessionSurfaceDismissalIdentitySurvivesResumeButNotSessionReplacementOrEnd() {
    let suite = "session-surface-test-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let first = DJConnectSessionSurfacePresentation.identity(for: "session-a", in: defaults)
    let restartedDefaults = UserDefaults(suiteName: suite)!
    #expect(DJConnectSessionSurfacePresentation.identity(for: "session-a", in: restartedDefaults) == first)
    let successor = DJConnectSessionSurfacePresentation.identity(for: "session-b", in: defaults)
    #expect(first != successor)
    DJConnectSessionSurfacePresentation.end(in: defaults)
    #expect(DJConnectSessionSurfacePresentation.identity(for: "session-b", in: defaults) != successor)
}


@Test func sessionSurfaceCopyExistsInAllFiveLanguages() {
    for language in DJConnectLocalization.supportedLanguageCodes {
        for key in ["surface.session.active", "surface.session.open", "surface.session.open.app", "surface.session.description"] {
            #expect(DJConnectLocalization.localized(key: key, language: language) != key)
        }
    }
}

@Test func sessionSurfacePaletteFollowsConfirmedMoodAndExpiresWithoutChangingContentRights() throws {
    let suite = "session-surface-theme-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    for mood in ["chill", "groove", "energy", "party"] {
        let snapshot = try #require(DJConnectSessionSurfaceSnapshot.observe(runtimeState: "active", authorized: true,
            isDemo: false, confirmedMood: mood, at: now))
        try DJConnectSessionSurfaceSnapshot.replace(snapshot, in: defaults)
        let restored = try #require(DJConnectSessionSurfaceSnapshot.load(from: defaults, at: now))
        #expect(restored.renderingTheme(at: now).rawValue == mood)
        #expect(restored.renderingTheme(at: snapshot.expiresAt) == .brand)
        #expect(restored.expiresAt == now.addingTimeInterval(120))
        let object = try #require(JSONSerialization.jsonObject(with: defaults.data(forKey: DJConnectSessionSurfaceSnapshot.storageKey)!) as? [String: Any])
        #expect(Set(object.keys) == ["observedAt", "expiresAt", "theme"], "Only a closed renderer palette token is added; no content or raw Profile data")
    }
    #expect(DJConnectSessionMoodTheme(sessionMood: "private arbitrary text") == .brand)
    #expect(DJConnectSessionSurfaceSnapshot(observedAt: now).renderingTheme(at: now) == .brand)
    #expect(DJConnectSessionSurfaceSnapshot.observe(runtimeState: "ended", authorized: true, isDemo: false, confirmedMood: "party", at: now) == nil)
}

@Test func sessionSurfaceMoodChangeRequestsImmediateReloadWithoutHeartbeatSpam() throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let previous = DJConnectSessionSurfaceSnapshot(observedAt: now, theme: .chill)
    let heartbeat = DJConnectSessionSurfaceSnapshot(observedAt: now.addingTimeInterval(10), theme: .chill)
    let changed = DJConnectSessionSurfaceSnapshot(observedAt: now.addingTimeInterval(10), theme: .party)
    #expect(!DJConnectSessionSurfaceSnapshot.needsWidgetReload(current: heartbeat, previous: previous, lastReloadAt: now, at: now.addingTimeInterval(10)))
    #expect(DJConnectSessionSurfaceSnapshot.needsWidgetReload(current: changed, previous: previous, lastReloadAt: now, at: now.addingTimeInterval(10)))
    let repeatedlyRenewed = DJConnectSessionSurfaceSnapshot(observedAt: now.addingTimeInterval(60), theme: .chill)
    #expect(DJConnectSessionSurfaceSnapshot.needsWidgetReload(current: repeatedlyRenewed, previous: heartbeat, lastReloadAt: now, at: now.addingTimeInterval(60)), "New cache observations must not postpone timeline renewal forever")
    #expect(DJConnectSessionSurfaceSnapshot.needsWidgetReload(current: nil, previous: changed, lastReloadAt: now, at: now.addingTimeInterval(11)))
    #expect(!DJConnectSessionSurfaceSnapshot.needsWidgetReload(current: nil, previous: nil, lastReloadAt: now, at: now.addingTimeInterval(61)))
}
