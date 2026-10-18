# Empty Session playback hint

Owner requests removal of the loose Nothing Playing label and the DJConnect
tagline inside the quiet bubble when no music is playing.

Native Session music details no longer synthesize `ui.nothing.playing` for a
missing/blank track title. The quiet card uses existing five-language
`brand.tagline` unless playback is playing, where the listening copy remains.
Explicit paused/recovering/unavailable and admitted Moment branches retain their
existing presentation. This is UI copy only, not a new backend Moment.

Diff/brand validator(native system launch plus1258 matching keys across five
languages)/native signed iOS40306 build/strict deep signature/ordinary-app checks
PASS. iPhone installation, independent40306 readback and normal launch succeeded. No new
tests for the bounded copy change; no physical viewport acceptance claimed.
iPad/Mac source updated but not installed under current iPhone-only scope.

Evidence: `/private/tmp/djc-idle-tagline-40306-ios-build.log` and
`/private/tmp/djc-idle-tagline-40306/`.
