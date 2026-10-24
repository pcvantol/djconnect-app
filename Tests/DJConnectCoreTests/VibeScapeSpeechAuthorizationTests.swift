#if canImport(Speech) && (os(iOS) || os(macOS))
import Foundation
@preconcurrency import Speech
import Testing
@testable import DJConnectUI

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
#endif
