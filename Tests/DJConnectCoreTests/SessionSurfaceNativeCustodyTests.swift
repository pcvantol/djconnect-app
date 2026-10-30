import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

@Suite @MainActor struct SessionSurfaceNativeCustodyTests {
    @MainActor private final class Handle: SessionSurfaceRetirableHandle {
        private(set) var isRetired = false
        func retire() { isRetired = true }
    }
    @Test func nativeHandleRegistryBoundsLiveEntriesWithoutALifetimeStartLimitOrRetiredRevival() {
        let registry = SessionSurfaceNativeHandleRegistry<Handle>()
        var old: [Handle] = []
        for index in 0..<512 {
            let handle = Handle(), id = "inert-handle-\(index)"
            #expect(registry.insert(handle, id: id) && registry.count == 1)
            #expect(registry.retire(handle, id: id) && registry.count == 0 && handle.isRetired)
            #expect(!registry.insert(handle, id: id))
            old.append(handle)
        }
        for handle in old { #expect(handle.isRetired) }
        for index in 0..<128 { #expect(registry.insert(Handle(), id: "simultaneous-\(index)")) }
        #expect(registry.count == 128 && !registry.hasCapacity)
        #expect(!registry.insert(Handle(), id: "overflow") && registry.count == 128)
        #expect(registry.values.allSatisfy { !$0.isRetired }) // No pressure-driven eviction.
    }
    @Test func nativeHandleRegistryLateRetirementCannotRemoveOrRetireTheReplacement() {
        let registry = SessionSurfaceNativeHandleRegistry<Handle>()
        let original = Handle(), replacement = Handle()
        #expect(registry.insert(original, id: "same-test-slot"))
        #expect(!registry.insert(replacement, id: "same-test-slot"))
        #expect(registry.retire(original, id: "same-test-slot"))
        #expect(registry.insert(replacement, id: "same-test-slot"))
        #expect(!registry.retire(original, id: "same-test-slot"))
        #expect(registry["same-test-slot"] === replacement && !replacement.isRetired && original.isRetired)
        // Inert objects exercise the production registry; they are not SDK results.
    }
    private func appModel(_ body: (DJConnectAppModel, DJConnectProfileDJSettingsResponse) async throws -> Void) async throws {
        let name = "native-surface-model-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let fixture = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Fixtures/profile-settings3-core-1329ad1.json"))) as? [String: Any])
        let cases = try #require(fixture["cases"] as? [[String: Any]])
        let object = try #require(cases.first(where: { $0["case"] as? String == "active_atomic_all_five_and_replay" })?["response"])
        let response = try JSONDecoder().decode(DJConnectProfileDJSettingsResponse.self, from: JSONSerialization.data(withJSONObject: object))
        model.pairingStatus = .paired // Isolated runtime input, not a real pairing or native grant.
        model.bindProfileDJSettings(active: true)
        await model.profileDJSettings.refresh(.init(read: { response }, update: { _, _, _ in throw CancellationError() }, receipt: { _, _ in throw CancellationError() }))
        try await body(model, response)
    }
    private func publication(_ model: DJConnectAppModel, snapshot: DJConnectSessionSurfaceSnapshot,
                             foreground: Bool = true, observed: Bool = false) -> SessionSurfaceNativeCustody.Ticket {
        model.prepareSessionSurfacePublication(confirmed: true, sessionID: "test-session", identity: "test-presentation",
            snapshot: snapshot, foreground: foreground, observedSession: observed)
    }
    @Test func actualAppModelQueuesRetirementForInactiveOrWithdrawnSettingsWithTheSameRawFrame() async throws {
        for withdrawAuthority in [false, true] {
            try await appModel { model, _ in
                let snapshot = DJConnectSessionSurfaceSnapshot(observedAt: Date())
                let original = publication(model, snapshot: snapshot, observed: true)
                var selected: [Bool] = []
                let first = try #require(model.scheduleSessionSurfaceActivity(publication: original, identity: "test-presentation", canStart: true) { value, _, _, _ in
                    selected.append(value != nil) // Inert observer, not an ActivityKit success.
                })
                await first.value
                if withdrawAuthority { model.profileDJSettings.withdrawAuthority() }
                else { model.bindProfileDJSettings(active: false) }
                let negative = publication(model, snapshot: snapshot)
                #expect(negative.isCurrent && negative.currentSnapshot() == nil && !original.isOwnerCurrent)
                let end = try #require(model.scheduleSessionSurfaceActivity(publication: negative, identity: "test-presentation", canStart: true) { value, _, start, ticket in
                    selected.append(value != nil); #expect(!start && ticket.isCurrent)
                })
                await end.value
                #expect(selected == [true, false])
            }
        }
    }
    @Test func actualAppModelWithdrawalDuringPreviousTaskAwaitAndCachedABAStayNegative() async throws {
        try await appModel { model, _ in
            let snapshot = DJConnectSessionSurfaceSnapshot(observedAt: Date())
            let original = publication(model, snapshot: snapshot, observed: true)
            var release: CheckedContinuation<Void, Never>?
            var selected: [Bool] = []
            let first = try #require(model.scheduleSessionSurfaceActivity(publication: original, identity: "test-presentation", canStart: true) { value, _, _, _ in
                selected.append(value != nil)
                await withCheckedContinuation { release = $0 }
            })
            while release == nil { await Task.yield() }
            model.bindProfileDJSettings(active: false)
            let negative = publication(model, snapshot: snapshot)
            let end = try #require(model.scheduleSessionSurfaceActivity(publication: negative, identity: "test-presentation", canStart: true) { value, _, _, ticket in
                selected.append(value != nil); #expect(ticket.isCurrent)
            })
            model.bindProfileDJSettings(active: true) // Cached response alone cannot rebuild a scope.
            let cached = publication(model, snapshot: snapshot)
            #expect(cached.currentSnapshot() == nil && !cached.canStart && !original.isCurrent)
            release?.resume(); await first.value; await end.value
            #expect(selected == [true, false])
            let reconfirmed = publication(model, snapshot: snapshot, observed: true)
            #expect(reconfirmed.canStart && !original.isCurrent && !negative.isCurrent)
        }
    }
    @Test func actualAppModelExpiryDuringPreviousTaskAwaitSelectsRetirement() async throws {
        try await appModel { model, _ in
            let original = publication(model, snapshot: .init(observedAt: Date()), observed: true)
            var release: CheckedContinuation<Void, Never>?
            let first = try #require(model.scheduleSessionSurfaceActivity(publication: original, identity: "test-presentation", canStart: true) { _, _, _, _ in
                await withCheckedContinuation { release = $0 }
            })
            while release == nil { await Task.yield() }
            let expiring = publication(model, snapshot: .init(observedAt: Date().addingTimeInterval(-119.5)))
            var retired = false
            let next = try #require(model.scheduleSessionSurfaceActivity(publication: expiring, identity: "test-presentation", canStart: true) { value, _, _, ticket in
                retired = value == nil; #expect(ticket.isCurrent)
            })
            try await Task.sleep(for: .milliseconds(700))
            model.markInactiveSession()
            let background = publication(model, snapshot: .init(observedAt: Date().addingTimeInterval(-121)), foreground: false)
            let currentEnd = try #require(model.scheduleSessionSurfaceActivity(publication: background, identity: "test-presentation", canStart: false) { value, _, _, ticket in
                retired = value == nil; #expect(ticket.isCurrent)
            })
            release?.resume(); await first.value; await next.value; await currentEnd.value
            #expect(retired)
        }
    }
    @Test func actualAppModelLateRetirementCannotDispatchAfterNewerReconfirmation() async throws {
        try await appModel { model, _ in
            let snapshot = DJConnectSessionSurfaceSnapshot(observedAt: Date())
            let original = publication(model, snapshot: snapshot, observed: true)
            var release: CheckedContinuation<Void, Never>?
            var selected: [Bool] = []
            let first = try #require(model.scheduleSessionSurfaceActivity(publication: original, identity: "test-presentation", canStart: true) { value, _, _, _ in
                selected.append(value != nil)
                await withCheckedContinuation { release = $0 }
            })
            while release == nil { await Task.yield() }
            model.bindProfileDJSettings(active: false)
            let withdrawn = publication(model, snapshot: snapshot)
            let oldEnd = try #require(model.scheduleSessionSurfaceActivity(publication: withdrawn, identity: "test-presentation", canStart: false) { _, _, _, _ in
                selected.append(false) // Must not reach a stale end invocation.
            })
            model.bindProfileDJSettings(active: true)
            let newer = publication(model, snapshot: snapshot, observed: true)
            let replacement = try #require(model.scheduleSessionSurfaceActivity(publication: newer, identity: "test-presentation", canStart: true) { value, _, _, ticket in
                selected.append(value != nil); #expect(ticket.isCurrent)
            })
            release?.resume(); await first.value; await oldEnd.value; await replacement.value
            #expect(selected == [true, true] && !withdrawn.isCurrent && !original.isCurrent)
        }
    }
    @Test func actualMarkInactiveSessionFencesStartsAndResumeDoesNotRecreatePositiveCustodyFromCachedSettings() async throws {
        try await appModel { model, _ in
            let snapshot = DJConnectSessionSurfaceSnapshot(observedAt: Date())
            let original = publication(model, snapshot: snapshot, observed: true)
            #expect(original.canStart)
            model.markInactiveSession()
            #expect(!original.isCurrent && !original.canStart && original.isOwnerCurrent)
            let background = publication(model, snapshot: snapshot, foreground: false)
            #expect(background.currentSnapshot() == snapshot && background.dispatchCapture == nil && !background.canStart)
            model.bindProfileDJSettings(active: true)
            let resumed = publication(model, snapshot: snapshot)
            #expect(resumed.currentSnapshot() == snapshot && !resumed.canStart && resumed.dispatchCapture == nil)
            let reconfirmed = publication(model, snapshot: snapshot, observed: true)
            #expect(reconfirmed.canStart && !original.isCurrent && !resumed.isCurrent)
            model.markInactiveSession(); model.profileDJSettings.withdrawAuthority()
            let withdrawn = publication(model, snapshot: snapshot, foreground: false)
            #expect(withdrawn.currentSnapshot() == nil && !reconfirmed.isOwnerCurrent && withdrawn.dispatchCapture == nil)
        }
    }
    private func scope(_ revision: Int = 1) -> SessionSurfaceNativeCustody.Scope {
        .init(installation: "test-installation", binding: "test-binding", session: "test-session",
              settingsGeneration: "test-generation", settingsRevision: revision)
    }
    @Test func actualNativeClockSamplesDoNotConferRatePermissionOrRestore() {
        let a = DJConnectNativeSurfaceClockCapture.capture(), b = DJConnectNativeSurfaceClockCapture.capture()
        #expect(a.continuous <= b.continuous); #expect(a.uptime <= b.uptime)
        #expect(a.process == b.process); #expect(a.missingQualifications.count == 3)
        if let x = a.continuousTicks, let y = b.continuousTicks { #expect(x <= y) }
        if let numerator = a.timebaseNumerator { #expect(numerator > 0) }
        if let denominator = a.timebaseDenominator { #expect(denominator > 0) }
        // Optional native boot data may be unavailable on a platform. Neither
        // a sample nor equality mints an original source/rate/restore witness.
    }
    @Test func warmCounterConversionFloorsExactRationalsAndRejectsOverflow() {
        #expect(DJConnectNativeSurfaceClockCapture.nanosecondsFloor(ticks: 1, numerator: 1, denominator: 3) == 0)
        #expect(DJConnectNativeSurfaceClockCapture.nanosecondsFloor(ticks: 2, numerator: 125, denominator: 3) == 83)
        #expect(DJConnectNativeSurfaceClockCapture.nanosecondsFloor(ticks: 3, numerator: 125, denominator: 3) == 125)
        #expect(DJConnectNativeSurfaceClockCapture.nanosecondsFloor(ticks: .max, numerator: 1, denominator: 1) == UInt64.max)
        #expect(DJConnectNativeSurfaceClockCapture.nanosecondsFloor(ticks: .max, numerator: .max, denominator: .max) == UInt64.max)
        #expect(DJConnectNativeSurfaceClockCapture.nanosecondsFloor(ticks: .max, numerator: .max, denominator: 1) == nil)
        #expect(DJConnectNativeSurfaceClockCapture.nanosecondsFloor(ticks: 1, numerator: 1, denominator: 0) == nil)
        #expect(DJConnectNativeSurfaceClockCapture.nanosecondsFloor(ticks: 1, numerator: 0, denominator: 1) == nil)
    }
    @Test func actualWarmCounterBracketsYieldOnlyALocalMeasurement() async throws {
        let a = DJConnectNativeSurfaceClockCapture.capture()
        try await Task.sleep(for: .milliseconds(20))
        let b = DJConnectNativeSurfaceClockCapture.capture()
        switch a.localCounterElapsedFloor(to: b) {
        case .measuredNanoseconds(let ns):
            let duration = a.continuous.duration(to: b.continuous).components
            let measured = UInt64(duration.seconds) * 1_000_000_000 + UInt64(duration.attoseconds / 1_000_000_000)
            #expect(ns > 0 && ns <= measured) // This runtime probe is not a general cross-clock ratio guarantee.
            #expect(b.localCounterElapsedFloor(to: a) == .unavailable(.counterRollback))
        case .unavailable(let reason):
            #expect(reason == .bootIdentityUnavailable) // A truthful unsupported platform is not restored from DATA.
        }
        #expect(a.missingQualifications.count == 3) // Still no cross-machine rho/permission/restore.
    }
    @Test func ownerSettingsABAAndWithdrawAreTerminalForCapturedDispatch() async {
        let owner = SessionSurfaceNativeCustody(), now = Date()
        let snapshot = DJConnectSessionSurfaceSnapshot(observedAt: now)
        owner.bind(scope: scope(), presentationID: "test-presentation", snapshot: snapshot)
        let original = owner.capture()
        #expect(original.canPublish(at: now)) // Necessary synthetic dispatch guard, not real permission.
        await Task.yield()
        owner.bind(scope: scope(2), presentationID: "test-presentation", snapshot: snapshot)
        owner.bind(scope: scope(), presentationID: "test-presentation", snapshot: snapshot)
        #expect(!original.isOwnerCurrent && !original.canPublish(at: now))
        let next = owner.capture(); owner.withdraw()
        #expect(!next.isCurrent && !next.canPublish(at: now))
    }
    @Test func frameReplacementFencesSDKDispatchAfterAwaitButKeepsNativeOwnerSeparate() async {
        let owner = SessionSurfaceNativeCustody(), now = Date()
        let first = DJConnectSessionSurfaceSnapshot(observedAt: now, theme: .chill)
        owner.bind(scope: scope(), presentationID: "test-presentation", snapshot: first)
        let ticket = owner.capture()
        var release: CheckedContinuation<Void, Never>?
        var calls = 0
        let pending = Task {
            await withCheckedContinuation { release = $0 }
            if ticket.canPublish() { calls += 1 }
        }
        while release == nil { await Task.yield() }
        owner.bind(scope: scope(), presentationID: "test-presentation",
            snapshot: .init(observedAt: now, theme: .party))
        release?.resume(); await pending.value
        #expect(calls == 0 && !ticket.isCurrent && ticket.isOwnerCurrent)
    }
    @Test func cancelledQueuedSDKDispatchAndExpiredFramesAreClosed() async {
        let owner = SessionSurfaceNativeCustody(), now = Date()
        owner.bind(scope: scope(), presentationID: "test-presentation", snapshot: .init(observedAt: now))
        let ticket = owner.capture()
        var release: CheckedContinuation<Void, Never>?
        let pending = Task {
            await withCheckedContinuation { release = $0 }
            return ticket.canPublish()
        }
        while release == nil { await Task.yield() }
        pending.cancel(); release?.resume()
        #expect(await pending.value == false)
        #expect(!ticket.canPublish(at: now.addingTimeInterval(120)))
        owner.bind(scope: nil, presentationID: nil, snapshot: nil)
        #expect(!owner.capture().canPublish())
    }
    @Test func backgroundTransitionClosesAQueuedForegroundStartWithoutRetiringItsNativeOwner() {
        let owner = SessionSurfaceNativeCustody(), snapshot = DJConnectSessionSurfaceSnapshot(observedAt: Date())
        owner.bind(scope: scope(), presentationID: "test-presentation", snapshot: snapshot, foreground: true)
        let queued = owner.capture()
        #expect(queued.canStart)
        owner.bind(scope: scope(), presentationID: "test-presentation", snapshot: snapshot, foreground: false)
        #expect(!queued.isCurrent && !queued.canStart && queued.isOwnerCurrent)
        #expect(!owner.capture().canStart)
    }
    @Test func rendererChecksNestedSourceAndOriginalUptimeAtActualUse() throws {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: NativeCustodyFixtureAnchor.self)
        #endif
        let url = try #require(bundle.url(forResource: "rich-surface-original-encoder-v1", withExtension: "json", subdirectory: "Fixtures") ?? bundle.url(forResource: "rich-surface-original-encoder-v1", withExtension: "json"))
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let files = try #require(object["files"] as? [String: [String: String]])
        let encoded = try #require(files["state_same_pin_extended_deadline_codec_only.json"]?["utf8_b64"])
        let bytes = try #require(Data(base64Encoded: encoded))
        let state = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: bytes)
        let rich = try #require(state.rich)
        #expect(rich.isCurrent(at: rich.receivedAt.addingTimeInterval(45), uptime: rich.receivedUptime + 45))
        #expect(rich.currentContribution(at: rich.receivedAt.addingTimeInterval(45), uptime: rich.receivedUptime + 45) == nil)
        #expect(rich.currentPlayback(at: rich.receivedAt.addingTimeInterval(45), uptime: rich.receivedUptime + 45) != nil)
        #expect(rich.currentPlayback(at: rich.receivedAt.addingTimeInterval(1), uptime: rich.receivedUptime + 61) == nil)
    }
}

private final class NativeCustodyFixtureAnchor: NSObject {}
