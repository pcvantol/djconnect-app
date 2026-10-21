# Forecast shared-header alignment — local correction

User screenshots show the current-track area lower in Vooruitblik than Flow.
Both modes call the same `scrollingCurrent(activeSession)` header. Flow adds no
outer top inset; Forecast wrapped that header in another 16 pt vertical padding.
The correction removes only the extra top padding, retaining 16 pt at the bottom.

A new opt-in native component regression measured the same supplied 80 pt marker
header in SessionForecastPanel and a plain ScrollView control. At 500 and 900 pt
width, unchanged production source completed one test with two assertion failures:
Forecast top 16 / control top 0. After correction, the same test completed
1 PASS / 0 failures in 1.405 seconds: both tops 0 at both widths. The incremental
native Mac build completed in 3.61 seconds. All four after bitmaps were inspected;
the extra top band is gone. Before source/logs/geometry/images remain preserved.
The owned shared scratch binary now contains corrected source; the negative binary
is not retained. No unchanged model suites or stalled native runners were rerun.

This is offscreen NSHostingView/NSWindow component evidence with isolated
unpaired model/defaults, supplied header, background scene and no ordinary-app
launch. It is not full SessionTimelineScreen/currentHeader, physical switching,
VoiceOver or iOS runtime acceptance. No backend contract, permission or SDK change.

Base `0510045`; branch `codex/apple-forecast-header-alignment`, LOCAL ONLY.
Existing installed build 40402, earlier branches and unique evidence remain
unchanged. No push, PR, merge or installation occurred. Evidence:
`/Volumes/Shared Data/tmp/pcvantol/djc-forecast-header-alignment-20261021/`.
Exact file hashes and geometry are in the adjacent JSON receipt.
