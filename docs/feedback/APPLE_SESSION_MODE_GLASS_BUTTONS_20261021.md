# Session mode: two native glass controls — local only

Replaces the segmented Picker and visible “Weergave” label with two separate
native SwiftUI glass buttons: Flow and Vooruitblik. Both use the system interactive
`.glass` button style and capsule shape. Selected mode receives the app accent
glass tint and accessibility selected trait. Both actions still write the same
existing `showsForecast` binding, preserving mutually exclusive selection.
Existing localized titles and screen behavior remain; no new translation keys.
The existing glass preference / Reduce Transparency opaque fallback is retained.

Native Mac module and test compilation PASS. An isolated component host supplied
both selections at 320 and 640 pt. Initial test compilation failed because a
read-only accessibility environment value was being set; the test now respects
the real system setting. Initial offscreen recording and an attempted active
titled-window recording completed, but both hosts were inactive with no key
window. Their captures show dim labels and do not qualify the system glass chrome
or selected appearance. The final probe explicitly records 1 SKIP / 0 FAIL for
INCONCLUSIVE_INACTIVE_NATIVE_HOST, rather than asserting native visual PASS.
No native taps, accessibility/VoiceOver or physical acceptance is claimed.

Base e587fa3 preserves the preceding 16 pt header-alignment correction. This
bounded native control change is LOCAL ONLY; installed build 40402 is unchanged.
No push, PR, merge, backend request, ordinary app start or installation occurred.
Temporary test windows closed. No unchanged green suites were rerun.
Evidence: `/Volumes/Shared Data/tmp/pcvantol/djc-session-mode-glass-20261021/`.
The adjacent JSON records exact source and observation hashes.
