# Apple129: visible HA speech configuration

Local successor to producer-readback checkpoint `6e1c20a`. The existing speech
preferences now include independent read-only rows for HA recognition, speech
output and speaker target. Each distinguishes configured, unconfigured,
temporarily unavailable, unsupported and unknown. The view reads only the
existing RAM snapshot after owner/context and schema/authority/locale admission.
Missing or stale metadata renders unknown; saved Apple/Profile choices are not
rewritten. No new refresh request or audio/OS-permission operation is added.

Configuration is not synthesis success or audibility. A producer-declared failed
synthesis with a positive retry delay shows a separate temporary-pause note,
without rewriting the route's configuration state or permitting an audio action.
The existing input/output admission remains authoritative at execution time.
Ten new resource keys are translated in en/nl/de/fr/es. No new local capability
facts or provider fallback are invented.

Qualification completed:

- New presentation test consumes all 15 original, byte-identical protected Core
  fixture cases and checks all three route states, including independent speaker
  availability without synthesis and historical failure remaining configured.
- The actual-model scoped-metadata test additionally verifies the new read-only
  UI projection appears for admitted metadata and withdraws on locale mismatch
  or missing status, retaining independent Apple input preference.
- Both selected test functions PASS, 0 failures (0.161 seconds). Final macOS
  DJConnectUI compilation PASS after the last retry-note guard (2.72 seconds).
- Final unsigned isolated iOS Simulator build-for-testing PASS, exit 0.
- Localization validator PASS, 1377 keys across all five locales; diff check PASS.

These are source/model and compilation checks, not actual native row rendering,
VoiceOver, physical microphone/STT/TTS/hearing, current installed HA or complete
Apple129 acceptance. No installation/publication, provider call or permission
request. Producer-dependent Apple128/150/152 and Golden158 remain open.

Logs and SHA-256:

- `/private/tmp/djc-apple129-status-presentation-20261021-mac.log`:
  `e302b67b9fe749cd966a436029abdba88334f794000a286bf1c1ead9e8e05144`
- `/private/tmp/djc-apple129-status-presentation-20261021-mac-final.log`:
  `51473716c12020ba2697e8e5983ca05cacbcc6101150e8955211e8c06cf549bd`
- `/private/tmp/djc-apple129-status-presentation-20261021-ios-final.log`:
  `3c63ebfe18924d5b9569d801df3d7cd828f259c9a150bef913be0e475c35f324`

The earlier iOS log is preserved separately. Final source differs only by the
explicit failed-state check before the retry note; the completed model and
state-mapping test logic was unchanged and was not rerun unnecessarily.
