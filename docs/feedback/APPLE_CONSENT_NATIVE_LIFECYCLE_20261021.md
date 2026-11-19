# Native iOS consent-form lifecycle — 21 October 2026

Tests-only successor to `4debebe94de7ba85db30f8381eab9b2de1c589e2`. Production source is unchanged. The actual form's `onDisappear` cancellation and new-form `onAppear` reset are qualified through real UIKit root-controller replacement.

The complete xcresult has **1 passed, 0 failed, 0 skipped**, no runtime warnings. `actualIOSNativeConsentFormLifecycle()` mounts the real consent form and iOS AppModel in a dark UIKit window on the owned B62 iOS 27.1 simulator, with the existing synthetic URLProtocol. It enters code through the native UITextField delegate and explicitly invokes the model lookup; this is not a native button tap.

The test keeps the original UIHostingController alive, then replaces the window's root controller. The old view's window becomes nil and the production disappearance callback changes ready to unavailable, without any manual model cancellation. A subsequent stale model approval sends no approval POST. A newly created actual form mounts in the same window, resets to idle with six enabled empty fields, and makes no automatic owner lookup. Owner requests remain **2→2→2** and approvals remain zero. Response epoch, Session ID and playback are unchanged. This tests a ready claim, not an in-flight approval or ambiguous-effect teardown.

Three UIKit window-layer renders were inspected: ready confirmation with 000000, empty placeholder hierarchy after removal, and newly mounted empty form with disabled lookup. These are native hierarchy/render/property observations, not OS screenshots, physical close-button taps, interactive sheet gestures, VoiceOver, full-root or installed/server acceptance. The public SwiftUI disabled-trait limitation is unchanged.

Private evidence: `/private/tmp/djc-consent-lifecycle-20261021/final.{log,xcresult}`, `final-summary.json`, `observations/` and the generated private project. Use the existing isolated native-consent generator and pinned JOSE checkout; set private TestAction `shouldUseLaunchSchemeArgsEnv=NO`, explicit `DJCONNECT_CONSENT_LIFECYCLE_DIR`, and exact test selection `NativeConsentTests/DisplayConsentSessionTests/actualIOSNativeConsentFormLifecycle()`.

A read-only lane87 refresh is preserved at `/private/tmp/djc-apple-lane87-readonly-20261021.json`. Its latest comment is 20 October 16:22 UTC and adds no later producer handoff; its older draft/source status is historical and does not override the current local qualification checkpoints. No issue/comment/status report was published.

`git diff --check` passes. Existing legacy host/compiler warnings remain bounded diagnostics. No unchanged green suites were repeated. B62 is Shutdown; other simulators were untouched and no owned command remains active. No push, PR, ordinary app, physical device, deployment, provider/SDK operation or recovery bundle occurred.
