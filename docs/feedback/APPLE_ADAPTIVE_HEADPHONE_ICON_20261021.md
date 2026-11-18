# Adaptive headphone app icon

Owner request: replace the ornate blue glass tile with the simpler purple
headphone from ESP32 and support the system light/dark/tinted icon settings.

## Change

- Exact transparent PNG from ESP32 PR #69, source commit
  `c49d49186951ed3a4eaf3cc50778e48e04cbbef9`, SHA256
  `f69eb72b882f08c0dacbd3efa7e83165a56a01763aaa18e48557c03b65e11322`.
- Native `AppIconAdaptive.icon` document; separate light and dark outer fills,
  system mono/tinted/clear processing, foreground scale 0.64 to preserve margins.
  The headphone artwork includes its magenta ring, navy center and waveform.
- App target icon name and resource wiring updated for iOS/iPadOS, macOS and
  watchOS, including the fixed QA generator and its exact input hash set.
- No alternate-icon runtime API, extra appearance picker, regenerated wordmark,
  or change to the native-text brand banner.
- Historical catalogs and producer manifests retained unchanged; they are no
  longer selected by the app targets. Producer import hashes still validated.

## Actual validation

Xcode 27.1 / 27A9275:

- Apple `ictool` exported Default, Dark, TintedDark and TintedLight iOS previews.
  Reviewed the native masked output; no enlarged low-resolution contact sheet.
- Default and Dark also exported at 60 points, scale 3 (180 x 180 pixels).
- `actool` compiled the real shared catalog and new icon document successfully
  for `iphoneos` (iPhone + iPad), `macosx` and `watchos`, minimum OS 26.0.
- Compiler-produced iPhone/iPad icon plists select `AppIconAdaptive`; generated
  macOS `.icns` and per-platform `Assets.car` outputs were read back.
- XcodeGen regenerated the actual project; the document is a `wrapper.icon`
  resource in all three app targets, and all six app build configurations select it.
- `validate_brand_assets.py`: PASS, including exact ESP32 import and native
  project wiring; original eight imports and 33 legacy PNG hashes unchanged.
- `validate_brand_tagline.py`: PASS, five languages, 1389 keys.
- Fixed QA generator Python compilation and `git diff --check`: PASS.

This is asset/compiler and source qualification. No installation, device Home
Screen screenshot, signed app release or physical-device acceptance is claimed.
The separate VibeCast worktree remains intact.
