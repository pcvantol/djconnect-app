# Consistent Now Playing controls

Local successor to `59f336d`. Now Playing's favorite button now uses the same
44-point label and selected/secondary DJConnectButtonStyle as shuffle and
repeat, with a magenta active glyph and dimmed white inactive glyph. Queue's
inactive glyph opacity also matches the row. Track Insight already uses the
same selected/secondary style. The session header's separate neutral native
glass favorite presentation remains preserved.

Both iOS and macOS play/pause controls now supply a solid djConnectAccent
primary fill. Other primary buttons retain their existing gradient through the
new optional style parameter's default. Playback actions, favorite mutations,
capability gates and accessibility labels are unchanged.

Validation: unsigned isolated iOS Simulator build-for-testing completed with
exit 0 / TEST BUILD SUCCEEDED. Native macOS DJConnectUI target build completed
with exit 0 in 47.61 seconds. git diff --check passed. This is compilation and
source evidence, without runtime visual qualification, installation or publication.

Build logs and SHA-256:

- `/private/tmp/djc-playback-magenta-controls-20261021-ios.log`:
  `09f0314c07e8bf73794b825d0eb12f38cb884adc07891cf137eb5354aec76187`
- `/private/tmp/djc-playback-magenta-controls-20261021-mac.log`:
  `f6179026ddf72a68fdd702cbc805160b11821842683b7d774dd85bc703f000a0`
