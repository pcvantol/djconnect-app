# Apple settings-confirmation Moment adoption — 22 October 2026

Peter requested client adoption of the Core change: actual user edits to Mood,
Persona and Presence receive one Core-authored narrative in the newly accepted
style, including Music-only. Existing Apple writer / draft PR179. Source only;
no build, Swift tests, installation, native gestures or audible acceptance.

## Producer binding

Read-only Core draft PR1290 source at
`a29bdeca54b9b87021c29ccbce7994e81317f68b`,
`docs/product/SETTINGS_CONFIRMATION_MOMENT_V1.md` and
`examples/client_contracts/settings_confirmation_v1/actual-ha-wire.json`.
`settings_confirmation.py` SHA256:
`f697b9695f9e7c3bb027927eb2730e73b899bd4d5bc98d2ab065ede0f915a0fb`.
The checked-in selected decoder fixture preserves original opaque identities,
acceptance times, settings revisions, source text and native display deadlines.
It is isolated Core HA evidence, not an Apple runtime execution.

## Consumer behavior

- Decode additive v1 contract, accepted receipt and live identity projection.
  Recognize the exact capability/version pair. Unknown contracts do not create
  local prose or fallback confirmations. Validate closed changed axes, accepted
  snapshot values, Session/generation/revision and original Moment identity.
- Active Sessions render the original owner-only Moment through native_delivery.
  No additional response card or client-authored Moment is created. Decoder
  Moment IDs and current/Flow selection retain existing deduplication.
- This precise accepted-settings publication may display with paused or absent
  playback, including Music-only. Ordinary music Moments retain playback checks.
  The paused UI no longer covers a valid confirmation with its pause message.
  Existing original admission deadlines, silence and withdrawal still win.
- Speech uses the existing session_speech descriptor, accepted settings/output
  and paired local/HA processor path. Settings confirmations additionally need
  current native admission before autoplay; superseded or expired confirmations
  cannot enter that path. Existing identity baseline/reconnect/ABA dedup remains.
  No response-text speech or unsolicited queue/provider action is introduced.
- Without a Session, only the actual accepted operation or original uncertain
  operation receipt can enqueue its authored acknowledgement. Freshness GETs
  never enqueue it. A current settings readback must still match. iOS/macOS use
  the existing notice presentation; Watch presents the current operation response
  and clears it on foreground/owner/Session changes. No Session is created.
- Legacy explicit settings success reads the authoritative Session once, without
  retrying the write. Manual uncertain-operation reconciliation does the same.
- Historical `runtime_accepted_settings_v1` rows use history v2 on all read/search/
  open/conversation routes. Retention does not supply live display or speech rights.
  Automatic Mood/no-op/rejected changes remain Core-owned and produce no client
  acknowledgement. The only local demo Mood copy remains demo-only.

## Verification boundary

Added unexecuted test source covers the three real Core example decoders,
no playback and paused Music-only, original expiry, missing/invalid owner
admission, current/Flow dedup, unsupported contract and revision mismatch,
GET/replay silence, operation-only acknowledgement, active response no duplicate
card, lost-reply receipt without write replay and speech identity A/B/A.

Static validation: git diff --check, fixture JSON parsing and original
identity/clock/revision linkage checks, work-register validation. These checks
are not compilation, test execution or native acceptance. Compilation and
physical iPhone/iPad/Mac/Watch display/audio verification await Peter's explicit
build instruction; Core merge/install remains separately controlled by him.
