# Native consent input enablement — 21 October 2026

Successor to `317cbfd42365e9527eea6464518cc3a963d92159`. The production iOS six-digit widget now assigns each UITextField's `isEnabled` from `context.environment.isEnabled` in `updateUIView`. This makes the native control status follow the existing SwiftUI form policy, shared by both VibeCast code-entry consumers. Backend contracts and authority are unchanged.

## Observation and final proof

The initial in-process observation recorded all six native fields enabled even in ready, approved and uncertain states. SwiftUI removed first responder in those states; this is **not proof that touch/typing could bypass the SwiftUI gate**. The initial test also incorrectly expected an uncertain outcome to become unavailable after owner withdrawal. Existing production semantics deliberately retain uncertainty; the test was corrected accordingly, without changing model behavior.

All eight initial observations were written, but Xcode did not finish its result bundle. The owned xcodebuild PID27294 was interrupted, then terminated after INT did not finish. That incomplete run is neither a qualified failing xcresult nor a pass. Its log, test source and renders remain preserved. No unchanged stalled runner was retried: the final run includes the native enablement mapping and corrected uncertainty expectation.

The final complete xcresult has **1 passed, 0 failed, 0 skipped**, no runtime warnings. `actualIOSNativeInputConsentStates()` hosts the actual consent form and real iOS AppModel in a dark UIKit window on the owned B62 iOS 27.1 simulator, using the existing synthetic URLProtocol in normal and unknown-approval modes. Deliberate model methods cause transitions; no native button taps are claimed.

| State | Six native fields | Entered code |
| --- | --- | --- |
| Idle, both modes | Enabled | 000000 retained |
| Ready, both modes | Disabled | 000000 retained |
| Approved | Disabled | 000000 retained |
| Uncertain approval | Disabled | 000000 retained |
| Owner withdrawn after approval | Enabled, lookup admission false | 000000 retained |
| Owner withdrawn after uncertainty | Disabled, lookup admission false | 000000 retained |

The test asserts exactly one approval request per mode after a second model confirmation call, and unchanged Session/playback through withdrawal. These approvals are synthetic HTTP only. Four final UIKit window-layer renders were inspected: normal ready, approved, withdrawn and unknown withdrawn. Eight final renders and native property observations are preserved. This qualifies the actual UITextField property, not the previously unavailable public SwiftUI lookup-button disabled trait, OS screenshots, physical typing/tapping, VoiceOver, full-root, installed HA/provider/SDK or receiver acceptance.

## Reproduction and receipts

Private directory `/private/tmp/djc-consent-input-states-20261021/` contains initial/final logs, incomplete initial and complete final xcresults, `initial-test-source.swift`, `final-summary.json`, and `observations/` plus `observations-final/`. Generate the isolated project using the existing native-consent generator and pinned JOSE checkout. Set private TestAction `shouldUseLaunchSchemeArgsEnv=NO`, explicit `DJCONNECT_CONSENT_INPUT_STATES_DIR`, and select exactly `NativeConsentTests/DisplayConsentSessionTests/actualIOSNativeInputConsentStates()`.

The test builds actual Core/UI sources; unchanged green suites were not repeated. Existing legacy UIKit host/actor warnings remain compiler diagnostics, not new product failures. A sandbox-only xcresulttool cache-write error was resolved by allowing the readback tool its normal TestReport cache access; no test rerun was needed. `git diff --check` passes. B62 is Shutdown; other simulators were untouched. No owned build/test/install job remains. No push, PR, external report, ordinary app, physical device, deployment, provider/SDK operation or recovery bundle occurred.
