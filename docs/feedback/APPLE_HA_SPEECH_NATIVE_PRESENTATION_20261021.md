# HA speech configuration — native Mac component qualification

Local Apple follow-up to `255b5595bf92dc32522d8faab5d390fcfe4bf1d0`, based on
`8782f0117b2657734277edaaa30f646fc7f03827`. Tests/evidence only; production source,
shipping projects and backend contracts unchanged. No publication or installation.

## Scope and result

`HASpeechNativePresentationTests.testNativeHASpeechConfigurationLayout` hosts the
actual `HASpeechConfigurationView` with a real `DJConnectAppModel` in an isolated
offscreen AppKit window. Unique defaults and an in-memory synthetic token are used;
background tasks are disabled. A URLProtocol network sink rejects and counts any
accidental request. Final count: **0 HTTP requests**.

The unchanged producer fixture `device-speech-core-604b80f8.json` supplies English
snapshots through the actual `applyStatusEndpoints` admission path. No fixture facts,
timestamps, locale or lease values are rewritten. Six captures cover:

| Sample | Width, pt | Height, pt | Expected input/output/speaker |
| --- | ---: | ---: | --- |
| Configured, EN | 320 | 118 | configured/configured/unconfigured |
| Recent failed synthesis, EN | 320 | 139 | configured/configured/unconfigured + retry explanation |
| Same retry state, EN | 720 | 139 | same |
| Withdrawn speaker, EN | 320 | 118 | configured/unconfigured/unavailable |
| No snapshot, NL | 320 | 118 | unknown/unknown/unknown |
| No snapshot, DE | 320 | 118 | unknown/unknown/unknown |

All six initial bitmaps were visually inspected: full titles, labels, statuses and
retry explanation were visible without ellipsis at these widths. Every final PNG
is byte-identical to its inspected initial counterpart. Bitmap dimensions use the
host's backing scale; table dimensions are layout points. Black host background is
deliberate and does not represent the shipping settings surface.

The final run adds explicit expected-state assertions alongside admission, width,
bounded-height and no-network assertions. **1 test PASS, 0 failures, 0 skips**, 1.246s;
incremental build 6.98s. The initial recorder also completed 1 PASS/0 failures.
Logs retain the SwiftPM native-build-system deprecation warning. No failed test
result is suppressed; the added assertions justified the second bounded run.

## Reproduction and receipts

```sh
DJCONNECT_HA_SPEECH_NATIVE_DIR=/private/tmp/djc-ha-speech-native-20261021/observations-qualified \
swift test --build-system native \
  --scratch-path /private/tmp/djc-native-archive-20261021/mac-native \
  --skip-update --filter HASpeechNativePresentationTests
```

Use a new output path when reproducing; preserve existing receipts. Without the
environment variable this artifact recorder skips. The companion JSON records
source, fixture, logs, observations and all six final PNG hashes. Private evidence:
`/private/tmp/djc-ha-speech-native-20261021/`; logs have the same prefix with
`-initial.log` and `-qualified.log`. All own windows close and defaults are removed.

## Limits and next dependency

This qualifies the actual Mac component's normal-font layout for the listed
English supplied states and Dutch/German unknown presentation. It does not qualify
the whole Profile settings page, arbitrary widths, Dynamic Type, all five translated
configured states, active-session glass chrome, accessibility labels/VoiceOver,
physical devices, iOS runtime, microphone permissions, synthesis, audibility or
speaker operation. A configured route still proves configuration only; the retry
state is displayed independently. No audio, provider or OS permission request was
started. Existing model admission tests are not rerun or counted as new coverage.

The separate individual-deletion and archive-status contract candidates remain
unadopted pending protected producer fixtures and qualified handoff. Existing
unknown deletion journals continue blocking new operation IDs. Publication,
independent review and device installation remain separate decisions.
