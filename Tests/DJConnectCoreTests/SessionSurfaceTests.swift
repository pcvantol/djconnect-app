import Foundation
import Testing
@testable import DJConnectCore
import DJConnectUI

@Test @MainActor func sessionActivitySkipRejectsInvalidAndDemoRequestsWithoutPlaybackChanges() async throws {
    let name = "session-action-model-test-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    #expect(await !model.skipTrackFromLiveActivity(presentationID: "not-a-presentation"))
    model.isDemoMode = true
    let playback = model.playback
    #expect(await !model.skipTrackFromLiveActivity(presentationID: UUID().uuidString))
    #expect(model.playback == playback)
}

@Test func liveActivityActionPresentationMatchIsReadOnlyAndCannotRetargetAnotherSession() throws {
    let suite = "session-action-test-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let first = DJConnectSessionSurfacePresentation.identity(for: "session-a", in: defaults)
    let before = defaults.dictionaryRepresentation() as NSDictionary
    #expect(DJConnectSessionSurfacePresentation.matches(first, sessionID: "session-a", in: defaults))
    #expect(!DJConnectSessionSurfacePresentation.matches(first, sessionID: "session-b", in: defaults))
    #expect(!DJConnectSessionSurfacePresentation.matches(UUID().uuidString, sessionID: "session-a", in: defaults))
    #expect(!DJConnectSessionSurfacePresentation.matches("", sessionID: "session-a", in: defaults))
    #expect(!DJConnectSessionSurfacePresentation.matches(first, sessionID: "", in: defaults))
    #expect(before == defaults.dictionaryRepresentation() as NSDictionary)
    let replacement = DJConnectSessionSurfacePresentation.identity(for: "session-b", in: defaults)
    #expect(!DJConnectSessionSurfacePresentation.matches(first, sessionID: "session-b", in: defaults))
    #expect(DJConnectSessionSurfacePresentation.matches(replacement, sessionID: "session-b", in: defaults))
    DJConnectSessionSurfacePresentation.end(in: defaults)
    #expect(!DJConnectSessionSurfacePresentation.matches(replacement, sessionID: "session-b", in: defaults))
}

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
    try DJConnectSessionSurfaceSnapshot.replace(snapshot, in: defaults, now: { now }, uptime: { 0 })
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
        try DJConnectSessionSurfaceSnapshot.replace(snapshot, in: defaults, now: { now }, uptime: { 0 })
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

@Test func widgetPaletteUsesSessionThenTrackInsightThenProfileWithoutExportingContent() throws {
    #expect(DJConnectWidgetPaletteSnapshot.resolve(session: "party", trackInsight: .groove, profile: "chill") == .party)
    #expect(DJConnectWidgetPaletteSnapshot.resolve(session: nil, trackInsight: .groove, profile: "chill") == .groove)
    #expect(DJConnectWidgetPaletteSnapshot.resolve(session: nil, trackInsight: nil, profile: "energy") == .energy)
    #expect(DJConnectWidgetPaletteSnapshot.resolve(session: "unknown", trackInsight: nil, profile: "unknown") == .brand)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let palette = DJConnectWidgetPaletteSnapshot(theme: .groove, at: now)
    #expect(palette.renderingTheme(at: now.addingTimeInterval(119)) == .groove)
    #expect(palette.renderingTheme(at: now.addingTimeInterval(120)) == .brand)
    #expect(palette.renderingTheme(at: now.addingTimeInterval(-1)) == .brand)
    let encoded = try JSONEncoder().encode(palette)
    let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect(Set(object.keys) == ["observedAt", "theme"])
    let name = "widget-palette-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(encoded, forKey: DJConnectWidgetPaletteSnapshot.storageKey)
    #expect(DJConnectWidgetPaletteSnapshot.load(from: defaults, at: now)?.theme == .groove)
    #expect(DJConnectWidgetPaletteSnapshot.load(from: defaults, at: now.addingTimeInterval(120)) == nil)
    #expect(DJConnectSessionSurfaceSnapshot.load(from: defaults, at: now) == nil, "A palette never asserts an active Session")
}

@Test func sessionSurfaceApplicationEndAllowsRestartButUserDismissalSurvives() throws {
    let suite = "surface-request-marker-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let first = DJConnectSessionSurfacePresentation.identity(for: "session-a", in: defaults)
    defaults.set(first, forKey: DJConnectSessionSurfacePresentation.requestedKey)
    DJConnectSessionSurfacePresentation.applicationEnded(first, wasDismissed: true, in: defaults)
    #expect(defaults.string(forKey: DJConnectSessionSurfacePresentation.requestedKey) == first)
    #expect(DJConnectSessionSurfacePresentation.identity(for: "session-a", in: defaults) == first)
    DJConnectSessionSurfacePresentation.applicationEnded("other", wasDismissed: false, in: defaults)
    #expect(defaults.string(forKey: DJConnectSessionSurfacePresentation.requestedKey) == first)
    DJConnectSessionSurfacePresentation.applicationEnded(first, wasDismissed: false, in: defaults)
    #expect(defaults.string(forKey: DJConnectSessionSurfacePresentation.requestedKey) == nil)
    #expect(DJConnectSessionSurfacePresentation.identity(for: "session-a", in: defaults) == first)
}

@Test func sessionSurfaceUpgradeRestoresOSRetirementButNeverKnownUserDismissal() throws {
    let suite = "surface-upgrade-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let identity = DJConnectSessionSurfacePresentation.identity(for: "a", in: defaults)
    #expect(DJConnectSessionSurfacePresentation.canRequest(identity, build: "1", in: defaults))
    DJConnectSessionSurfacePresentation.requested(identity, build: "1", in: defaults)
    #expect(!DJConnectSessionSurfacePresentation.canRequest(identity, build: "1", in: defaults))
    #expect(DJConnectSessionSurfacePresentation.canRequest(identity, build: "2", in: defaults))
    DJConnectSessionSurfacePresentation.requested(identity, build: "2", in: defaults)
    DJConnectSessionSurfacePresentation.userDismissed(identity, in: defaults)
    #expect(!DJConnectSessionSurfacePresentation.canRequest(identity, build: "2", in: defaults))
    #expect(!DJConnectSessionSurfacePresentation.canRequest(identity, build: "3", in: defaults))
    let next = DJConnectSessionSurfacePresentation.identity(for: "b", in: defaults)
    #expect(DJConnectSessionSurfacePresentation.canRequest(next, build: "3", in: defaults))
}

@Test func sessionSurfaceLateDismissalFromAppRetirementCannotDismissReplacement() throws {
    let suite = "surface-instance-fence-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let identity = DJConnectSessionSurfacePresentation.identity(for: "a", in: defaults)
    DJConnectSessionSurfacePresentation.requested(identity, build: "1", activityID: "old", in: defaults)
    DJConnectSessionSurfacePresentation.applicationEnded(identity, wasDismissed: false, activityID: "old", in: defaults)
    DJConnectSessionSurfacePresentation.userDismissed(identity, activityID: "old", in: defaults)
    #expect(DJConnectSessionSurfacePresentation.canRequest(identity, build: "1", in: defaults))
    DJConnectSessionSurfacePresentation.requested(identity, build: "1", activityID: "new", in: defaults)
    DJConnectSessionSurfacePresentation.userDismissed(identity, activityID: "old", in: defaults)
    DJConnectSessionSurfacePresentation.applicationEnded(identity, wasDismissed: false, activityID: "old", in: defaults)
    #expect(!DJConnectSessionSurfacePresentation.canRequest(identity, build: "1", in: defaults))
    #expect(DJConnectSessionSurfacePresentation.canRequest(identity, build: "2", in: defaults))
    DJConnectSessionSurfacePresentation.userDismissed(identity, activityID: "new", in: defaults)
    #expect(!DJConnectSessionSurfacePresentation.canRequest(identity, build: "2", in: defaults))
}

@Test func confirmedSessionMoodImmediatelyOutranksOlderRichWidgetPalette() throws {
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    let before = DJConnectSessionSurfaceSnapshot(observedAt: now, theme: .chill)
    let changed = DJConnectSessionSurfaceSnapshot(observedAt: now.addingTimeInterval(1), theme: .party)
    let readback = now.addingTimeInterval(1)
    #expect(DJConnectSessionSurfaceSnapshot.widgetTheme(confirmedSession: changed, passiveMood: "chill", fallback: .groove, at: readback) == .party)
    #expect(DJConnectSessionSurfaceSnapshot.needsWidgetReload(current: changed, previous: before,
        lastReloadAt: now, at: readback))
    #expect(!DJConnectSessionSurfaceSnapshot.needsWidgetReload(current: before, previous: before,
        lastReloadAt: now, at: readback))
    #expect(DJConnectSessionSurfaceSnapshot.widgetTheme(confirmedSession: changed, passiveMood: "groove", fallback: .brand,
        at: now.addingTimeInterval(122)) == .groove)
    #expect(DJConnectSessionSurfaceSnapshot.widgetTheme(confirmedSession: nil, passiveMood: nil, fallback: .energy, at: now) == .energy)
    #expect(changed.expiresAt == changed.observedAt.addingTimeInterval(120))
}

@Test func widgetPushTokenIsSeparateBoundedRotatableAndCannotGrantContent() throws {
    let suite = "widget-push-token-test-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let kind = DJConnectSessionSurfaceSnapshot.widgetKind
    let token = try #require(DJConnectWidgetPushToken(token: Data([1, 2, 3]),
        extensionBundleID: "dev.djconnect.mac.track-insight-widget", widgetKinds: [kind]))
    try DJConnectWidgetPushToken.replace(token, in: defaults)
    #expect(DJConnectWidgetPushToken.load(from: defaults) == token)
    #expect(DJConnectSessionSurfaceSnapshot.load(from: defaults) == nil)
    #expect(DJConnectPassiveSurfaceCache.load(surface: .widget, from: defaults) == nil)
    #expect(DJConnectWidgetPushToken(token: Data(), extensionBundleID: token.extensionBundleID, widgetKinds: [kind]) == nil)
    #expect(DJConnectWidgetPushToken(token: Data(repeating: 1, count: 4097), extensionBundleID: token.extensionBundleID, widgetKinds: [kind]) == nil)
    #expect(DJConnectWidgetPushToken(token: token.token, extensionBundleID: "dev.djconnect.mac", widgetKinds: [kind]) == nil)
    #expect(DJConnectWidgetPushToken(token: token.token, extensionBundleID: token.extensionBundleID, widgetKinds: []) == nil)
    let rotated = try #require(DJConnectWidgetPushToken(token: Data([4, 5]), extensionBundleID: token.extensionBundleID, widgetKinds: [kind]))
    try DJConnectWidgetPushToken.replace(rotated, in: defaults)
    #expect(DJConnectWidgetPushToken.load(from: defaults)?.token == rotated.token)
    try DJConnectWidgetPushToken.replace(nil, in: defaults)
    #expect(DJConnectWidgetPushToken.load(from: defaults) == nil)
}

@Test func iOSWidgetAndActivityTokensRemainSeparateAndOldActivityCannotClearReplacement() throws {
    let name = "surface-push-test-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let widget = try #require(DJConnectWidgetPushToken(token: Data([1]),
        extensionBundleID: "dev.djconnect.ios.track-insight-widget",
        widgetKinds: [DJConnectSessionSurfaceSnapshot.widgetKind]))
    try DJConnectWidgetPushToken.replace(widget, in: defaults)
    let first = try #require(DJConnectActivityPushToken(token: Data([2]), activityID: "activity-a", presentationID: "presentation-a"))
    try DJConnectActivityPushToken.replace(first, in: defaults)
    #expect(DJConnectActivityPushToken.load(from: defaults) == first)
    let rotated = try #require(DJConnectActivityPushToken(token: Data([3]), activityID: "activity-b", presentationID: "presentation-b"))
    try DJConnectActivityPushToken.replace(rotated, in: defaults)
    DJConnectActivityPushToken.withdraw(activityID: first.activityID, in: defaults)
    #expect(DJConnectActivityPushToken.load(from: defaults) == rotated)
    #expect(DJConnectWidgetPushToken.load(from: defaults) == widget)
    #expect(DJConnectSessionSurfaceSnapshot.load(from: defaults) == nil)
    #expect(DJConnectActivityPushToken(token: Data(), activityID: "a", presentationID: "p") == nil)
    #expect(DJConnectActivityPushToken(token: Data(repeating: 1, count: 4097), activityID: "a", presentationID: "p") == nil)
    #expect(DJConnectActivityPushToken(token: Data([1]), activityID: "", presentationID: "p") == nil)
    DJConnectActivityPushToken.withdraw(activityID: rotated.activityID, in: defaults)
    #expect(DJConnectActivityPushToken.load(from: defaults) == nil)
    #expect(DJConnectWidgetPushToken.load(from: defaults) == widget)
}

@Test func activityTokenCallbacksCannotOverwriteSuccessorOrRestoreWithdrawnPresentation() throws {
    let name = "activity-push-owner-test-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let firstID = DJConnectSessionSurfacePresentation.identity(for: "session-a", in: defaults)
    DJConnectSessionSurfacePresentation.requested(firstID, build: "test", activityID: "activity-a", in: defaults)
    let first = try #require(DJConnectActivityPushToken(token: Data([1]), activityID: "activity-a", presentationID: firstID))
    #expect(try DJConnectActivityPushToken.recordIfCurrent(first, in: defaults))
    let secondID = DJConnectSessionSurfacePresentation.identity(for: "session-b", in: defaults)
    DJConnectSessionSurfacePresentation.requested(secondID, build: "test", activityID: "activity-b", in: defaults)
    let second = try #require(DJConnectActivityPushToken(token: Data([2]), activityID: "activity-b", presentationID: secondID))
    #expect(try DJConnectActivityPushToken.recordIfCurrent(second, in: defaults))
    #expect(try !DJConnectActivityPushToken.recordIfCurrent(first, in: defaults))
    #expect(DJConnectActivityPushToken.load(from: defaults) == second)
    let rotated = try #require(DJConnectActivityPushToken(token: Data([3]), activityID: "activity-b", presentationID: secondID))
    #expect(try DJConnectActivityPushToken.recordIfCurrent(rotated, in: defaults))
    #expect(DJConnectActivityPushToken.load(from: defaults) == rotated)
    DJConnectSessionSurfacePresentation.userDismissed(secondID, activityID: "activity-b", in: defaults)
    DJConnectActivityPushToken.withdraw(activityID: "activity-b", in: defaults)
    #expect(try !DJConnectActivityPushToken.recordIfCurrent(second, in: defaults))
    #expect(DJConnectActivityPushToken.load(from: defaults) == nil)
    let thirdID = DJConnectSessionSurfacePresentation.identity(for: "session-c", in: defaults)
    DJConnectSessionSurfacePresentation.requested(thirdID, build: "test", activityID: "activity-c", in: defaults)
    let third = try #require(DJConnectActivityPushToken(token: Data([4]), activityID: "activity-c", presentationID: thirdID))
    #expect(try DJConnectActivityPushToken.recordIfCurrent(third, in: defaults))
    DJConnectSessionSurfacePresentation.requested(thirdID, build: "test", activityID: "activity-c2", in: defaults)
    #expect(try !DJConnectActivityPushToken.recordIfCurrent(third, in: defaults))
    let replacement = try #require(DJConnectActivityPushToken(token: Data([5]), activityID: "activity-c2", presentationID: thirdID))
    #expect(try DJConnectActivityPushToken.recordIfCurrent(replacement, in: defaults))
    DJConnectActivityPushToken.withdraw(activityID: third.activityID, in: defaults)
    #expect(DJConnectActivityPushToken.load(from: defaults) == replacement)
    DJConnectSessionSurfacePresentation.end(in: defaults)
    DJConnectActivityPushToken.withdraw(activityID: replacement.activityID, in: defaults)
    #expect(try !DJConnectActivityPushToken.recordIfCurrent(replacement, in: defaults))
    #expect(DJConnectActivityPushToken.load(from: defaults) == nil)
}
