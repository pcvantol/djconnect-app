# Native UIKeyInput code entry — 21 October 2026

Successor to `3e07f730440ed59278a9593a3a04135b2e5d2eda`. The iOS six-digit widget now routes public `UITextField.insertText` through the same coordinator insertion logic used by its delegate. Native deletion remains coordinator-owned. Weak callbacks preserve lifecycle; the macOS fallback and backend contracts are unchanged.

## Negative observation and correction

The initial complete xcresult has **0 passed, 1 failed, 0 skipped**. Calling native `insertText` with six separate digits bypassed the delegate in this host: the first field contained 123456, five fields stayed empty and focus remained at index 0. The first negative render was inspected. Later native replacement/backspace observations also exposed stale aggregate state and unfiltered input. These public programmatic methods do not prove a physical keyboard, OS paste or OTP/autofill failure; no such claim is made.

`DigitField.insertText` now forwards through a weak coordinator callback. Both the delegate and UIKeyInput route call one existing ASCII-digit/filter/full-code replacement routine. The routine updates the aggregate binding and focus together, without relying on UIKit to invoke the delegate. No second insertion occurs inside the delegate, which still returns false.

## Qualified results

The final complete xcresult has **2 passed, 0 failed, 0 skipped**, no runtime warnings. The new opt-in `actualIOSNativeCodeUIKeyInput()` uses the actual consent form, real iOS AppModel, existing synthetic URLProtocol and dark UIKit window on owned B62 iOS 27.1. It makes no direct delegate call. Public native methods prove:

- Sequential single digits populate 123456 and focus advances through all six cells.
- Full-code insertion from a later cell replaces all six; selected-cell replacement produces 659321 and advances focus.
- Filled/empty native backspace leaves 6593 plus two empty cells; invalid non-ASCII input changes neither digits nor focus.
- An admitted identical Session broadcast preserves edited digits and Session/playback; consent remains idle and owner endpoint requests stay zero.

The existing delegate/backspace/snapshot test also passes on the changed production source. This rerun is relevant regression coverage for the newly shared insertion routine, rather than a repeat of unchanged green checks. Three qualified UIKeyInput window-layer renders were inspected. Six final renders exist across both selected tests; the other three belong to the delegate regression.

This is public UIKit API/coordinator qualification, not physical typing, system pasteboard, OS OTP/autofill, native lookup/confirmation taps, OS screenshots, VoiceOver, full-root or installed/server acceptance. The existing public SwiftUI lookup-button disabled-trait limitation remains open.

## Evidence and reproduction

Private `/private/tmp/djc-native-keyinput-20261021/` retains the initial historical `final.{log,xcresult}`, `initial-summary.json`, `initial-test-source.swift`, `observations/`, and qualified `qualified.{log,xcresult}`, `qualified-summary.json`, `observations-qualified/`, `delegate-regression/`. The historical name final refers to the negative run, not the qualified result. The scratch compiled products now reflect the correction; initial logs/results/renders remain preserved.

Use the existing isolated native-consent generator and pinned JOSE checkout. In its private scheme set TestAction `shouldUseLaunchSchemeArgsEnv=NO`, explicit `DJCONNECT_NATIVE_KEYINPUT_DIR` plus `DJCONNECT_CONSENT_DIGITS_DIR`, and select exactly `NativeConsentTests/DisplayConsentSessionTests/actualIOSNativeCodeUIKeyInput()` and `NativeConsentTests/DisplayConsentSessionTests/actualIOSNativeCodeEntryEditingAndFocus()`.

`git diff --check` passes. Existing legacy host/compiler warnings remain bounded diagnostics. B62 is Shutdown, other simulators untouched and no owned job remains active. No push, PR, external report, ordinary app, physical device, deployment, provider/SDK operation or recovery bundle occurred.

The current TODO/open-work matrix and qualified summary adoption report were inspected. Next independently executable point: assess native `SessionHistorySummaryView` rendering with existing pinned producer fixtures, including compact/detail and larger Dynamic Type, while retaining its owner-only/non-passive boundary. No actual paired/VoiceOver acceptance follows from a component host.
