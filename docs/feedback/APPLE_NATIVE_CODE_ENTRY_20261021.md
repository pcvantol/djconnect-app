# Native iOS six-digit entry correction — 21 October 2026

Successor to `5f16dab8fa89fc3e98af86e61046099b8782ae41`. A real UIKit backspace sequence reproduced a production bug: after pasting 123456, deleting the last digit and then deleting from that empty cell restored the stale 6. The negative complete result has **0 passed, 1 failed, 0 skipped**, with actual native fields `[1,2,3,4,"",6]` instead of `[1,2,3,4,"",""]`. The negative second render was inspected.

## Correction and qualification

The iOS `VibeCastCodeEntry` coordinator now handles deletion from filled as well as empty cells, keeping its six-digit array and aggregate binding synchronized. Previously, UIKit's filled-cell deletion could bypass the delegate and leave the coordinator's digit unchanged. Both existing VibeCast form consumers share this widget; the macOS fallback and backend contracts are unchanged.

The opt-in `actualIOSNativeCodeEntryEditingAndFocus()` hosts the actual production consent form with the real iOS AppModel, existing synthetic URLProtocol and an isolated dark UIKit window. On the owned B62 iOS 27.1 simulator, the final complete xcresult has **1 passed, 0 failed, 0 skipped**, without runtime warnings. It checks:

- Full-code paste from cell index 3 populates all six cells and focuses index 5.
- Actual `UITextField.deleteBackward()` twice leaves 1234 plus two empty cells and focuses index 4.
- Mixed ASCII paste filters to 654321; non-ASCII/invalid input leaves the code and selected focus unchanged.
- An admitted identical Session broadcast preserves the same six native field instances, digits, focused cell, Session and playback.

All three final UIKit window-layer renders were inspected. No owner endpoint requests were made; consent remains idle. These are public UIKit methods and delegate calls, not physical typing, OS screenshots, native button taps, accessibility/VoiceOver acceptance, full-root or installed/server qualification. The older disabled-trait UI assertion remains unqualified.

## Evidence and reproduction

Private directory `/private/tmp/djc-consent-digits-20261021/` retains `initial.{log,xcresult}`, `initial-summary.json`, negative `observations/`, `final.{log,xcresult}`, `final-summary.json` and `observations-final/`. The final scratch build replaced its earlier compiled products; the negative result/log/renders remain separately preserved. The JSON receipt hashes both runs and final source/products.

Generate a fresh isolated project with `Tools/qualification/vibecast-product/prepare_native_consent_tests.py` and the existing pinned JOSE checkout. In its private NativeConsentTests scheme use TestAction `shouldUseLaunchSchemeArgsEnv=NO`, explicit `DJCONNECT_CONSENT_DIGITS_DIR`, and exact selection `NativeConsentTests/DisplayConsentSessionTests/actualIOSNativeCodeEntryEditingAndFocus()`. Shipping schemes are unchanged. The successful test builds the actual Core/UI sources; unchanged green suites were not rerun.

`git diff --check` passes. B62 is Shutdown after the run; other simulators were untouched. No push, PR, external report, ordinary app launch, physical device, provider/SDK operation, deployment or recovery bundle occurred. Restricted process inventory was unavailable; both owned test commands have returned terminal results and no owned command session remains active.
