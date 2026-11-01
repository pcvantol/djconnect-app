#if canImport(Speech) && (os(iOS) || os(macOS))
import Foundation
@preconcurrency import Speech
import Testing
@testable import DJConnectUI
@testable import DJConnectCore

// Model the legacy SDK's unannotated callback type, rather than changing the
// injected request to Sendable and accidentally fixing the bug in the test.
private final class LegacySpeechAuthorizationCallback: @unchecked Sendable {
    let callback: (SFSpeechRecognizerAuthorizationStatus) -> Void
    init(_ callback: @escaping (SFSpeechRecognizerAuthorizationStatus) -> Void) {
        self.callback = callback
    }
}

@Test @MainActor func visualSpeechAuthorizationAcceptsBackgroundSDKCompletion() async {
    for status in [SFSpeechRecognizerAuthorizationStatus.authorized, .denied, .restricted, .notDetermined] {
        let actual = await VibeScapeSpeechAuthorization.request { completion in
            let original = LegacySpeechAuthorizationCallback(completion)
            DispatchQueue.global().async {
                #expect(!Thread.isMainThread)
                original.callback(status)
            }
        }
        MainActor.assertIsolated()
        #expect(actual == status)
    }
}

@Test @MainActor func visualSpeechAuthorizationAcceptsImmediateSDKCompletion() async {
    let actual = await VibeScapeSpeechAuthorization.request { $0(.authorized) }
    MainActor.assertIsolated()
    #expect(actual == .authorized)
}

@Test @MainActor func visualVoiceReadinessWaitsForObservationWithoutRequiringAnotherTap() async throws {
    var calls = 0, waits = 0
    var clock: TimeInterval = 100
    let lease = try await VibeScapeVoiceReadiness.read(isCurrent: { true }, now: { clock },
        wait: { waits += 1; clock += 1 }) {
            calls += 1
            if calls < 3 { throw DJConnectVisualContextError.awaitingObservation }
            return "original-issued-lease"
        }
    #expect(lease == "original-issued-lease")
    #expect(calls == 3 && waits == 2)
}

@Test @MainActor func visualVoiceReadinessNeverRetriesAmbiguousOrRejectedRequests() async {
    for error in [DJConnectError.network(message: "synthetic"), .server(statusCode: 503, message: nil),
                  .authStale(statusCode: 401, message: nil), .invalidResponse] {
        var calls = 0, waits = 0
        do {
            let _: Int = try await VibeScapeVoiceReadiness.read(isCurrent: { true },
                wait: { waits += 1 }) { calls += 1; throw error }
            Issue.record("A failed request unexpectedly succeeded")
        } catch { #expect((error as? DJConnectError) != nil) }
        #expect(calls == 1 && waits == 0)
    }
}

@Test @MainActor func visualVoiceReadinessStopsOnOwnerLossAndCannotExtendItsWaitBudget() async {
    for mode in ["owner", "clock", "attempts", "late-success", "cancel"] {
        var current = true, calls = 0, waits = 0
        var clock: TimeInterval = 100
        do {
            let _: Int = try await VibeScapeVoiceReadiness.read(isCurrent: { current }, now: { clock }, wait: {
                waits += 1
                if mode == "cancel" { throw CancellationError() }
                if mode == "owner" { current = false }
                if mode == "clock" { clock += 9 }
            }) {
                calls += 1
                if mode == "late-success" { current = false; return 1 }
                throw DJConnectVisualContextError.awaitingObservation
            }
            Issue.record("Stale or indefinitely unavailable context was accepted")
        } catch {}
        #expect(calls == (mode == "attempts" ? 6 : 1))
        #expect(waits == (mode == "attempts" ? 5 : mode == "late-success" ? 0 : 1))
    }
}
#endif
