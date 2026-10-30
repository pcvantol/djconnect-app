import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

@Suite @MainActor struct SessionSurfaceNativeCustodyTests {
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
