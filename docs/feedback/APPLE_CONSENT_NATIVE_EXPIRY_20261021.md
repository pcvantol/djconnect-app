# Native iOS consent expiry — 21 October 2026

Tests-only successor to `ec33ec8e2fac35afc90f98fcfd9b7b542f6da2ee`. Production source is unchanged. The mounted actual `VibeCastDisplayConsentForm` automatically removes expired claim and receipt presentation through its ordinary 250 ms refresh task.

## Qualified result

The complete qualified xcresult reports **1 passed, 0 failed, 0 skipped**, without runtime warnings. `actualIOSNativeConsentExpiryPresentation()` uses the real iOS AppModel, existing synthetic URLProtocol and existing `short-claim` / `short-receipt` modes, in an isolated dark UIKit window on the owned B62 iOS 27.1 simulator. The existing one-second relative validity is unchanged. The receipt fixture's absolute expiry remains long; production takes the stricter relative bound.

The test waits on real clocks, with no clock injection, owner withdrawal or forced model refresh. It captures the after-expiry window before checking the resulting state. Four qualified UIKit window-layer renders were inspected:

- Claim: ready confirmation → honest unavailable notice; no approval request. Owner requests stay 2→2.
- Receipt: approved notice → honest unavailable notice; exactly one prior synthetic approval. Owner requests stay 4→4.

In both cases, all six native fields change from disabled to enabled, code 000000 stays present, owner admission and response epoch remain current, and Session/playback remain unchanged. The visible lookup is again available because owner authority remains current; expiry does not fabricate owner withdrawal. Explicit model methods perform lookup/approval, not claimed native button taps. No automatic consent lookup/approval/replay occurs during the waiting interval.

## Initial diagnostic and scope

The first probe incorrectly compared **all** model requests across the wait. Existing history/capability/active-Session work continued, so total counts increased. Its four observed expiry renders are useful observations, but the incomplete xcresult never finalized; owned PID37922 was interrupted and then terminated after INT did not finish. It is neither a qualified failing result nor a pass. Preserve `final.{log,xcresult}`, `broad-counter-test-source.swift` and `observations/` as that initial diagnostic; the historical filename `final` does not qualify it.

The corrected test fences `/owner/` routes and records all methods/paths separately. Qualified totals were 12→23 for claim and 15→20 for receipt; the owner subset remained unchanged. Observed routes are existing synthetic active Session, capabilities, Ask DJ history, Session history, transport context and display-owner routes. Nothing reached a real server. The changed assertion and added route evidence justify the second run; no production fix was needed.

This is native UIKit visual/property evidence over synthetic HTTP, not OS screenshots, physical typing/tapping, VoiceOver, public SwiftUI button disabled traits, full-root navigation, installed HA/receiver/provider/SDK or server acceptance. No claim is made about the previously stalled UI-testing runner.

## Reproduction and evidence

Private directory `/private/tmp/djc-consent-expiry-20261021/`. Qualified artifacts are `qualified.{log,xcresult}`, `qualified-summary.json`, and `observations-qualified/` (four inspected renders and native route/property observations). Generate the isolated project using the existing native-consent generator and pinned JOSE checkout. Set private TestAction `shouldUseLaunchSchemeArgsEnv=NO`, explicit `DJCONNECT_CONSENT_EXPIRY_DIR`, and exact selection `NativeConsentTests/DisplayConsentSessionTests/actualIOSNativeConsentExpiryPresentation()`.

`git diff --check` passes. Existing legacy host/compiler warnings are retained. Unchanged green suites were not rerun. B62 is Shutdown and other simulators were untouched; no owned build/test/install command remains active. No push, PR, external report, ordinary app launch, physical device, deployment, provider/SDK operation or recovery bundle occurred.
