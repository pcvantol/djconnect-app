# In-process iOS consent withdrawal observation — 21 October 2026

Tests-only successor to `5af721f451aef1791f5f44554fd82b6770dc03d9`. Production sources are unchanged. **Visual UIKit evidence after the lookup-disabled correction is now available; the automatic disabled-trait assertion remains unqualified.**

## Different execution route

The graphical Simulator application could not be found here and desktop inventory timed out, so no GUI interaction was attempted. Instead, a new opt-in Swift Testing case uses the previously stable isolated iOS unit-test route, not the stalled UI-testing runner. The owned B62 iOS 27.1 simulator is the only destination. Its post-run state is Shutdown; the other reference simulators were not controlled.

`actualIOSNativeFormWithdrawalObservation()` initializes the real iOS AppModel with the existing synthetic URLProtocol, hosts the actual `VibeCastDisplayConsentForm` in a dark UIKit window, finds all six real UITextFields, and supplies a full synthetic code through their actual delegate. Public accessibility/container and automation metadata is recorded without enabling system VoiceOver or private APIs. Because the SwiftUI lookup element is not exposed in this unit host, lookup uses the explicitly recorded model-method fallback, not a claimed native tap. Profile authority is then suspended through the existing model and presentation refreshed.

## Final results and limits

The final complete result has **1 passed, 0 failed, 0 skipped**. Three final UIKit window-layer renders were inspected (Dutch presentation):

- Six native digits contain 000000 and lookup is blue.
- Ready state offers explicit screen confirmation.
- After withdrawal, confirmation is gone, the unavailable text is visible and lookup is gray.

The actual approval POST count is zero. These are actual UIKit-backed window renders after the correction, not OS screenshots or physical/native tap acceptance. The 56/55/56 recorded public objects contain no lookup identifier, so `INCONCLUSIVE_PUBLIC_UIKIT_ELEMENTS` is preserved. No enabled/disabled AX-trait PASS, VoiceOver acceptance, full-root navigation, installed HA/receiver/provider result or completed XCTest-UI correction assertion is inferred. The three older native UI tap tests remain strictly before the correction.

## Reproduction and evidence

Use the existing isolated-project generator and the pinned local JOSE checkout. In its private NativeConsentTests scheme, set TestAction `shouldUseLaunchSchemeArgsEnv=NO` and supply `DJCONNECT_CONSENT_UIKIT_DIR` as an explicit TestAction environment variable. Select exactly `NativeConsentTests/DisplayConsentSessionTests/actualIOSNativeFormWithdrawalObservation()` (parentheses matter). Shipping schemes are unchanged; the case is opt-in.

Private directory: `/private/tmp/djc-consent-uikit-20261021/`. Final artifacts: `uikit-unit-final.{log,xcresult}`, `final-summary.json`, and `observations-final/` (three inspected renders, metadata and result). Earlier `uikit-unit-initial` selected zero tests; `uikit-unit-selected` skipped because the default scheme inherited launch variables. Neither is a pass. The corrected enabled run also passed once and remains separately preserved. Project-generation sandbox and result-path preflight failures are retained; they did not execute product tests. The final recorder uses the actual approval count and only emits trait qualification if both required traits are observed.

`git diff --check` passes. No unchanged macOS/iOS-model suite was repeated, no ordinary app or physical device was controlled, and no push, PR, deployment, provider/SDK operation or recovery bundle was performed.

Next independent point: qualify native six-digit entry editing/focus through this working UIKit route (full-code paste from a later cell, actual backspace behavior and stability across an admitted model/UI update). Use actual UITextFields and public delegate/control methods; keep all HTTP synthetic and distinguish these methods from physical typing. Do not repeat unavailable desktop/AX routes or the unchanged stalled UI runner.
