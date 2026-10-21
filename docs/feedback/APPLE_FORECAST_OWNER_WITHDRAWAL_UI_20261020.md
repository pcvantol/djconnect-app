# Forecast owner withdrawal and retry admission — 20 October 2026

Local production correction and native macOS panel evidence based on `2e182e1e5dcd9e54dec49018a0240900b74e211b`.

## Observed behavior and correction

With the actual Forecast panel mounted over the existing synthetic paired-owner fixture, `sessionHistory.suspend()` removed the authored summary and cards. The unavailable notice appeared and no further Forecast read occurred (2 → 2). However, the retry remained visually active: its UI checked only generic foreground/paired readiness while `refreshSessionForecast()` also required an authorized owner and qualified runtime.

The new internal `canRefreshSessionForecast` shares the existing read-admission conditions between the retry, visible-projection admission and read entry: authorized owner, paired foreground client, compatible runtime, active Session, online route and no recovery/live-unavailable state. It does not grant authority or change backend contracts. Expired/missing projections remain refreshable when that admission is valid.

## Final evidence

`DJCONNECT_FORECAST_WITHDRAWAL_DIR` mounts the actual `SessionForecastPanel` with an empty header in its own dark 600 × 1000 offscreen AppKit window. It has no unrelated composer or ordinary installed-app effects. The panel cache has transparent background; the captures are not full-root canvas or contrast qualification.

Three final native captures were inspected:

1. Authorized: producer summary and all three authored sections are present.
2. Owner suspended: summary/cards disappear; honest unavailable notice and dimmed retry label appear. The shared read gate is false; Forecast reads remain 2 → 2.
3. Owner restored through the existing synthetic `sessionHistory.prepare()`: read admission becomes true and the authored summary/cards return.

The draft, Session ID and playback value remain unchanged before and after recovery. The existing fixture fence permits only GET and rejects command/message effects. The custom SwiftUI retry style exposes no NSButton bridge in this host, so this is source admission plus native visual-state evidence, not an AX enabled-state assertion or physical tap qualification. The initial NSButton-selector prerequisite failed with two issues; it is preserved as a host-probe failure, not product counterproof. The adapted before-fix native presentation run passed 16 fixture cases and exposed the active-looking retry for source review.

Final macOS Forecast selection: **10 executed functions, one opt-in source-Link function skipped** (Swift Testing reports 11 total), including **16 lifecycle cases and seven canonical artist cases**, PASS. Unsigned isolated iOS Simulator `build-for-testing` on final production sources: PASS. This did not rerun the stalled iOS UI runner or install an ordinary/physical app. `git diff --check`: PASS.

## Private evidence and limits

- Initial native-bridge prerequisite: `/private/tmp/djc-forecast-withdrawal-before-20261020.log` and directory.
- Before-fix presentation: `/private/tmp/djc-forecast-withdrawal-presentation-20261020.log` and directory.
- Final macOS log, three inspected captures and read metrics: `/private/tmp/djc-forecast-withdrawal-final-20261020.log` and directory.
- Final iOS compilation: `/private/tmp/djc-forecast-withdrawal-ios-build-20261020.log`.

The receipt hashes source, fixture and private evidence. These checks do not qualify physical input, VoiceOver, full-root navigation, iOS runtime, ordinary installed apps or current HA/server/provider acceptance. No push, PR, merge, deployment, SDK action or recovery bundle was performed.

Next independent point: inspect actual native Forecast expiry presentation using the existing authored fixture with a bounded synthetic lease. Distinguish visible expiry from model/source checks; keep owner/draft/Session/playback and GET-only fences. Do not repeat unchanged successful owner/filter/scroll/keyboard checks or unchanged failed AX/iOS runner probes.
