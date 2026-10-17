# Session TTS autoplay repair, 2026-10-17

Owner: autoplay toggle ON but newly arriving bubbles remain silent. Same sole
Apple writer; no backend model or provider configuration change.

Root causes:
- Local autoplay preference was persisted but only consulted by the legacy
  response.audioURL path. Shared reference-based Session TTS had manual actions
  and no new-publication/accepted-response autoplay trigger.
- Broadcast Payload decoder discarded private session_speech descriptors. Full
  snapshots had them, but a new-publication event could not supply its autoplay
  grant to the renderer.
- Profile conversation requests always used audio_response=never and omitted
  speech_contract_version. Core correctly declined automatic audio admission.

Repair:
- Decode bounded private owner speech grants from live event Payload, retain them
  through runtime applying, omit from encoded output as with private snapshots.
- Foreground baseline and per-session new-ID admission: initial/read/restore stays
  silent; delayed fresh grants can qualify new text; duplicates/revisions do not
  repeat; pending admission expires120s and is bounded. Server autoplay_eligible
  and exact live text/source validation are mandatory.
- One bounded RAM-only queue (maximum16 contributions) serializes prepared speech;
  it respects local autoplay, confirmed client/both output, Profile/session/voice
  fences and original expiry. Text-only/speaker-only do not start client autoplay.
  Background, stop, settings change and owner/session withdrawal cancel work;
  no payloads, private grants or outcomes are persisted/exported.
- Accepted conversation replies use the same shared speech path. Negotiated
  settings3 requests explicitly advertise speech_contract_version=3 and use
  audio_response=always only for an enabled, allowed local autoplay target.
  OFF remains never; manual replay remains separately authorized by Core.
- The autoplay switch tint is again purple as explicitly requested by the owner.

Qualification: first733-test suite PASS before explicit speech version request
field. New private-event decode/non-export, silent baseline, delayed grant,
ordered/deduplicated publication, toggle/resume/no-backlog and stale scope tests
PASS. Final full suite734 tests and installed iPhone real accepted-reply test are
recorded below once complete. No fixture or UI click is labelled audible proof.

Final autoplay source qualification40244:734tests/10suites PASS85.938s;
both native builds/signatures PASS. Physical test produced the expected new
neutral reply but no autoplay while confirmed output was text_only. Human
screenshot confirms that global output; it is not an audio PASS. Human then
explicitly selected client_device for further acceptance. No provider or voice
choice is changed by Apple qualification.

Follow-up owner UI requirements in40247: no settings shortcut in any bubble;
text_only hides all bubble speech actions, voice/gender selection and autoplay.
White preserved-voice explanation remains. Popover content is measured and
height follows visible controls, capped620pt for large content. Native iOS/Mac
builds PASS; device acceptance recorded below after readback.

Voice Preview is a separate new producer dependency. Human explicitly authorized
forwarding the fixed neutral-text/current-profile-voice/target-aware API request
to the existing Core writer01a120e2-b557-76c3-8568-129dbce2f2d2; message sent.
No dummy turn, old-bubble replay or invented preview endpoint is used.

Native40247 test did not reach settings acceptance: the test attempted to open an
already changing popup and could not resolve session-voice-toggle. No output
preference was mutated by that run. Its test body failed; xcodebuild then stalled
in artifact finalization and was interrupted using SIGINT on its verified own
PID14590. Test navigation now tolerates an already open editor/overflow. This
failure is not recast as a layout or playback PASS.
Core writer acknowledged the new Preview request and added it to its inventory
and design; wire implementation/handoff remains pending.

Installed40248 acceptance, 2026-10-17:
- Ordinary signed iOS/Mac builds PASS;40248 installed/read back on iPhone,
  iPad and Mac mini. No test bundle was embedded in the ordinary application.
- Physical iPhone test `testTextOnlyHidesVoiceAndShrinksThenRestoresChosenClientOutput`
  PASS26.743s, xcresult `textonly40248b-ui.xcresult`. It selected text_only,
  asserted no voice picker/label, no hittable autoplay switch and no bubble audio
  or settings actions, and verified the editor height decreased. Exported
  screenshot visually confirms a compact popover with only output and white
  preserved-voice explanation. It restored the owner's client_device choice and
  verified the voice control reappeared. iPad layout was not separately qualified.
- The preceding navigation attempt did not reach the editor; the successful
  probe explicitly opens DJ-sessie before the overflow. That failed attempt is
  not counted as product acceptance.
- Separate actual iPhone log at11:39:52 records automatic preparation of a new
  accepted reply, followed at11:39:54 by playback through the configured HA
  provider without a play tap. The corresponding test body failed its offscreen
  stop-button assertion; this is log evidence of playback start, not an audible
  acceptance or a successful end-to-end UI probe. Latest copy did not contain a
  completion line for that automatic playback. Full source suite remains734
  tests PASS on40244; subsequent changes are UI visibility/height only, covered
  by native builds and this physical UI check. Preview remains producer-gated.
