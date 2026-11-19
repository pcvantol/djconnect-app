# Native Forecast scroll restoration — 20 October 2026

Local source correction and bounded native macOS qualification, based on `ab36e9bcd34fd2c3973253617bcb10623bb7156e`. No publication or installed-runtime acceptance is implied.

## Reproduced problem and correction

The actual `SessionTimelineScreen` lost Forecast's viewport after switching Forecast → Flow → Forecast. In the negative native run the end position was 246 points and returned to 0, while Flow remained at 0. The end-restoration assertion failed once. The prior text-ID anchor could not retain a viewport whose top edge fell inside the fixed header.

`SessionForecastViewport` now retains the transient native offset across panel removal. Each newly mounted panel initializes `ScrollPosition` from that offset and records scroll geometry. This screen-owned, non-observed object avoids publishing every scroll pixel to the entire Flow. It introduces no persistent Profile state or backend contract changes.

## Final verification

The final native host used the real screen in a dark NavigationStack, an isolated offscreen 600 × 900 AppKit window, and the existing paired GET-only fixture. Moving the actual NSScrollView clip view to its end, selecting Flow, then selecting Forecast restored **246 → 246 points**. Flow retained **0 → 0**. The Ask DJ draft, Session ID and playback value remained unchanged. All three final scroll captures were inspected. The fixture's Flow timeline intentionally returns 404; its unavailable state is not populated-history acceptance.

The final macOS Forecast selection passed: **10 executed test functions**, including **16 lifecycle cases** and **7 canonical artist cases**. One separate opt-in source-Link function was skipped (Swift Testing reports 11 functions total). The three native Command-F transitions and actual text-editor focus also passed. A prior diagnostic run hit the existing asynchronous focus bridge before an editor was attached; the test now waits up to 1.5 seconds for native focus without assigning focus itself. That diagnostic log is retained and is not counted as a passing run.

Final production sources also passed the unsigned iOS Simulator `build-for-testing` using the isolated NativeConsentUI project. This is compilation evidence; no iOS runner or physical installation was performed for this change. `git diff --check` passed.

## Evidence and limits

- Negative run: `/private/tmp/djc-forecast-scroll-20261020.log` and `/private/tmp/djc-forecast-scroll-20261020/`.
- Final macOS run: `/private/tmp/djc-forecast-scroll-qualified-20261020.log`.
- Final metrics and three inspected scroll captures: `/private/tmp/djc-forecast-scroll-qualified-20261020/`.
- Final keyboard captures: `/private/tmp/djc-forecast-scroll-qualified-keyboard-20261020/`.
- Retained focus-timing diagnostic: `/private/tmp/djc-forecast-viewport-final-20261020.log`.
- Final iOS compilation: `/private/tmp/djc-forecast-viewport-ios-build-20261020.log`.

This proves restoration of the semantic end boundary under fixed native geometry through direct clip-view scrolling. Physical wheel/keyboard interaction, arbitrary positions after content reflow, VoiceOver operation, iOS runtime, ordinary installed apps, HA/server/provider and end-user acceptance remain unqualified. The existing GET-only fence rejects command/message effects. No push, PR, merge, deployment or recovery bundle was performed.
