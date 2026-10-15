# Apple feedback worklist — 2026-10-14

Existing sole writer: codex/apple-dj-presence-v1, recovery/source.
Starting HEAD3c89327; merged baseline446ff15. Preserve original root WIP.
User authorized all fixes; explicitly paused CI/delivery. Local focused tests,
unsigned builds and isolated native checks are development validation, not delivery.
No new installation, HA update, pairing change, protected merge or Finalization.

- [ ] Discover detail Play now does nothing; retain visible progress/failure and valid backend action.
- [ ] Music DNA artwork missing on top tracks/artists.
- [ ] Discover section content in individual glass cards (Rediscover / Artists to explore).
- [ ] Track Insight measurements absent: trace response/decoder/qualification, do not fabricate.
- [ ] Hero glyphs subtly animate; respect Reduce Motion.
- [ ] Mood non-selected labels/icons/track/dots white.
- [ ] Discover loses thumbnails until refresh.
- [ ] Ask DJ speaker choices disappear after initially rendering.
- [ ] Internal ask_dj_play_request_on_output string leaks into user conversation.
- [ ] Ask DJ artwork appears then disappears.
- [ ] DJMoment artwork missing in DJ-session.
- [ ] Now Playing album-derived background on Mac and iPhone; actual warm brown/cream cover must not use green/purple mood palette.
- [ ] Presence selector same compact discrete glyph/label control as Mood, five choices.
- [ ] Remove Presence Confirmed row and music-only explanation footer.
- [ ] Idle-session connection pill at far right; active-session pill immediately before Close.
- [ ] Saved Sessions pull-to-refresh errors session history unavailable.
- [ ] Seek in Now Playing immediately reflected in DJ-session progress (pending vs confirmed retained).
- [ ] No substantive DJMoments in Presenter and other modes; observed playback is not a DJMoment. Trace producer→delivery→admission→render independently.
- [ ] Carry previous slider vertical jump fix into current candidate and verify compact selector.

Never promote archived actions to live, bypass archive/expiry filters, generate
local Moments/recommendations/analysis, or guess an unauthorised server state.

- [ ] Cross-device active-session discovery while already foreground: same bounded
  10-second coordinator as playback, independent of playback/backend availability;
  discover nil-to-active, ended-to-nil and successor without session-start writes.
  Source regression added; physical multi-device acceptance still required.
- [ ] Splash lower illustration reuses DJ Session welcome artwork.
- [ ] Selected output subtitle shows current volume instead of Actief.
- [ ] Combine pairing/connection/capability status into one labelled coloured icon.
- [ ] VibeCast Pi handoff fails despite displayed code; diagnose before new handoff.

## Cross-device acceptance and evidence

One active session belongs to the server-resolved Profile. Never merge profiles,
re-pair devices or end a session to guess at a discrepancy.

Compare per device: HA installation identity; actual internal Profile ID;
active-session response ID; published Moments/presentations/admissions;
confirmed conversation, Mood and Presence; response versus visible projection.
A same display name or Spotify account is not identity evidence.
Already-open nil-to-active discovery, foreground resume, end-to-nil, successor,
foreign Profile, and obsolete responses are separate acceptance cases. Opening a
client must not create a session, start another DJ runtime or transfer playback.
Draft text and scroll position remain device-local.

Local regression: foregroundPollDiscoversAndReplacesProfileSessionWithoutPlaybackOrManualRefresh
passed (2026-10-14). No known session, playback or available music backend is
required. Every discovery request in that scenario is GET. Background tick does
not issue requests. The existing foreground timer invokes this coordinator every
10 seconds after the preceding tick completes; there is no new polling loop.
Physical Mac/iPhone/iPad acceptance remains NOT RUN on the new source.

The two separately authorized Mac active-session attempts were consumed:
Mac mini transport failed; MacBook HTTP 200 had 2 Moments, 2 presentations and
2 native admissions. These observations do not establish identical Profile IDs
or session IDs across the devices. No pairing or production mutation performed.

Local Swift validation: full suite 525 tests passed in 29.365 seconds, including
foreground session discovery and protected artwork no-store regression.
Log: /private/tmp/djc-feedback-all-tests.log. This is source validation only.

## Combined connection presentation

First applicable row wins. Pairing is retained during an outage; it is not a
second green health signal. Text and icon carry meaning independently of colour.

| State | Dutch label | SF Symbol | Colour |
| --- | --- | --- | --- |
| Demo | Demomodus | play.rectangle.fill | Purple |
| Unpaired | Niet gekoppeld | link.badge.plus | Secondary |
| Pairing | Koppelen… | arrow.triangle.2.circlepath | Blue |
| Awaiting HA confirmation | Bevestig in Home Assistant | person.crop.circle.badge.exclamationmark | Amber |
| Stale pairing | Opnieuw koppelen nodig | lock.trianglebadge.exclamationmark | Amber |
| Paired, device offline | Geen netwerk | wifi.slash | Red |
| Paired, incompatible runtime | Update nodig | arrow.down.app.fill | Amber |
| HA unreachable, retrying | Verbinding herstellen… | arrow.triangle.2.circlepath | Blue |
| HA unreachable | Home Assistant niet bereikbaar | wifi.exclamationmark | Red |
| HA connected, music unavailable | Verbonden · muziek niet beschikbaar | music.note.slash | Amber |
| HA connected, session unavailable | Verbonden · sessie niet beschikbaar | exclamationmark.bubble.fill | Amber |
| HA connected, session recovering | Verbonden · sessie wordt bijgewerkt | arrow.triangle.2.circlepath | Amber |
| Connected remotely | Verbonden · extern | globe | Teal |
| Connected locally | Verbonden · lokaal | house.fill | Green |

The same resolved status drives toolbar, Setup and iOS connection card. Toolbar
accessibility value and help expose the full label; there is no contradictory
second dot. Native visual acceptance remains open.

Unsigned compile verification after the source changes: Mac build-for-testing
SUCCEEDED and DJConnectIOS generic iOS build SUCCEEDED. No ordinary app was
installed or launched. Logs: /private/tmp/djc-feedback-mac-build.log and
/private/tmp/djc-feedback-ios-build.log. git diff --check passed.

## Unexpected Mac mini Session layout

Read-only installed comparison: both running executable paths are
/Applications/DJConnect.app/Contents/MacOS/DJConnect, version 4.0.0 / 40058;
SHA-256 on both Macs is 35d35b42ac4f290688e70f34d219befd2c3d02f0c6c726dd582378a4fbf6a7d1.
This disproves different installed executable bytes as the explanation.
The source selected ActiveDJSessionView when history.available was false,
exposing session flow detail sheets and inline VibeCast form. The underlying
capability/read failure on the mini has not yet been established.

Removed that alternate route and renderer flow/detail-sheet implementation.
Any active Session uses SessionTimelineScreen, independently of history health.
Unavailable history shows a retry notice without fabricating entries or rights.
VibeCastHandoffForm is separate and only presented by the explicit handoff UI.
Updated native fixture acceptance to reject the obsolete layout and inline form.
No ordinary app replacement/restart, pairing change or production request made.

Session-layout validation: 525 Swift tests PASS (29.215s), unsigned Mac test
build and unsigned iOS build PASS. Direct isolated native AX/screenshot confirms
normal session, history-unavailable notice and retry, no Sessieverloop, no
return-to-current detail popup and no inline VibeCast code form. Screenshot:
/private/tmp/djc-feedback-layout-native.png; AX state:
/private/tmp/djc-feedback-layout-native-state.txt. Full XCTest runner stalled
before app startup and was interrupted; no automated native PASS claimed.
Optional extended native Moment sequence could not run: pinned Core object
3d17994d is unavailable to git archive in the current clone; fixture stopped.
The own temporary app was terminated. Ordinary app PID/path was untouched.

## Push registration finding DJC-MAC-PUSH-REGISTRATION-STATUS-20261014

Read the actual Apple #87 assignment. Fresh installed mini readback: registered
false; last error missing_bootstrap_proof; no trusted issuer base URL in the
bundle; signed APS environment development. Existing bounded log contains APNs
token receipt events (19), no system-registration failure events, repeated
missing_bootstrap_proof events (57), and no push_registered=true event. No token
contents read or stored. These are historical local receipts, not current OS
permission or delivery proof. No server registration/testpush/settings mutation.

Source now distinguishes configuration failure from permission/APNs/transport
failure. The About push status opens details with an appropriate settings or
retry action. Configuration failures do not suggest pairing again or blindly
retry an unconfigured issuer. Missing issuer records trusted_issuer_not_configured;
APNs callbacks and generic register failures update visible failure state.
Both initial and bootstrap-retry acceptance require push_registered == true.
A generic HTTP success without explicit registration is not green.

OPEN DEPENDENCY: authoritative trusted issuer deployment/configuration must be
qualified before choosing a production endpoint. No guessed endpoint, embedded
issuer/relay secret, APNs provider key or trust bypass introduced. Live APNs
registration and real notification delivery remain NOT RUN.

Push changes final local validation: full Swift suite 528 tests PASS; unsigned
Mac build-for-testing PASS; unsigned iOS build PASS; git diff --check PASS.
Logs: /private/tmp/djc-feedback-push-tests-final.log,
/private/tmp/djc-feedback-push-mac-build.log, /private/tmp/djc-feedback-push-ios-build.log.
No new installation, APNs registration, issuer request, testpush or CI was run.

## Local iteration — 2026-10-14, continued

Checkboxes above denote end-to-end acceptance, not absence of local changes.
No source-only result is an installed or provider delivery claim.

Owner correction6176090179 was fully read: device sharing works after matching
Profiles; scope is automatic foreground discovery, not a general broken Core
session-sharing claim or another Profile audit. No new production read performed.
Also fully read current-artist text/voice finding6175886912 and linked artwork
consumer scope6176720597. No second source writer or Core changes introduced.

Additional source fixes and regressions:
- Music DNA artist rows now load permitted artwork; track rows resolve relative
  references through the safe loader. Same-Profile, exact URI/kind, unexpired and
  unambiguous current Discovery references may populate the dashboard. Names do
  not authorize artwork; missing identity/reference remains a placeholder.
- The shared expiry decoder was interpreting numeric image_expires_at using the
  2001 Apple Date reference instead of Unix seconds. Reproduced expired-grant
  acceptance, then fixed numeric/fractional Unix decoding and invalid-value denial.
- Lease renewal performs a feed GET; it does not regenerate recommendations.
  An already-expired reply gets one bounded renewal; repeated expired replies do
  not create an infinite loop. Resume restores the single foreground schedule.
  Old GET/refresh/capability replies cannot overwrite a newer feed or background
  state. No per-card polling or provider lookups introduced.
- Transient history reads preserve confirmed readonly lists and conversation;
  explicit authority refusal still withdraws all private projections. A superseded
  pull-to-refresh read no longer supplies a false failure toast; genuine errors
  remain visible with retry alongside retained rows.
- Rich current replies survive reduced-history reads in RAM, with original result
  lifetime, epoch and exact message identity. Invalid/expired grants and scope
  withdrawal remove images/actions; a history read cannot renew them. Top-level
  rich content is normalized into the actual messages[] renderer.
- Numeric speaker observation times no longer drop the entire choice in lossy
  decoding. Frozen result_set_id/action_id survive the full and compound payloads;
  conflicting identifiers are refused. Frozen expired actions are not dispatched.
  Playback commands do not automatically replay after a transport failure.
- VibeCast approval is sent once, never replayed on remote fallback; only the
  exact returned Session can be confirmed. A late old-Session response cannot
  alter successor status. Unavailable code and unconfirmed outcome are distinct.
  Session start/end/mood also keep no-replay mutation semantics.
- The compact Presence selector remains adjustable for accessibility. Native test
  expectations read the confirmed value from the control, preserving all server
  revision/session/playback checks without restoring the removed Confirmed footer.

Validation: full local Swift suite 536 tests PASS28.965s;
localization validator PASS1117keys/five languages; git diff --check PASS.
Log: /private/tmp/djc-feedback-iteration-complete-tests.log.

Still open / separately qualified:
- Physical multi-device acceptance and native custom-selector motion/accessibility.
- Real DJMoment absence in Presenter/other modes: two published/admitted Moments
  were seen on one authorized MacBook read; live causal diagnosis remains unproven.
- Track Insight missing qualified measurements and Apple explicit-Moment navigation
  adoption. The closed producer contract exists; do not fabricate measured values
  or substitute current B for an explicit older A.
- Subject-bound Session/Moment/history artwork: selected/queued Core producer;
  exact early schema, qualified assets, fixtures/checksums and producer pin needed.
  Music DNA/Discovery fixes do not qualify this separate consumer slice.
- Trusted push issuer deployment/configuration and actual APNs delivery.
- Actual Pi handoff with a current receiver code; no old code was reused and no
  handoff, Pi restart, production update, installation, push, merge or CI was run.


## Additional iteration: Music DNA context refusal and current private replies

Owner diagnostics (installed40058) report repeated POST music_dna/profile409
music_dna_context_changed. This is a server context-fence rejection, not proof
that opt-in is disabled. No new Music DNA production request was performed.
The Apple refresh now withdraws old Profile/Discovery projections on this exact
code and retries within the existing bounded schedule. Permanent refusal retains
recovery status; unrelated409 and explicit Profile refusals do not retry.
Unknown state uses the existing checking copy rather than claiming opt-out.
This is client recovery, not proof that the server predicate causing repeated409
has been repaired. A server response must reauthorize data before redisplay.

The explicit new one-shot authorization call4803 was consumed once on the Mac
mini at2026-10-14T20:18:23Z: GET session/active, HTTP200, runtime active,
playback playing, selected presence balanced. Projection contained two Moments,
two presentations and ten admissions (two qualified/eight expired), with no
current_moment_id and no current_display_allowed admission. These are a single
projection snapshot, not a publication ledger, Presenter-mode measurement or
explanation of the planner's silence. No source/admission rule was weakened.
Only hashed identities and technical counts/deadlines were retained in the
private temporary report. No further request, POST, re-pair or restart.

Read the complete new Core checkpoint6177548854. Its local producer is
 d035dd95fc364f32cbccc4a4e2170533c259a13f (not published/installed).
Imported its exact26-case sanitized fixture into
Tests/Fixtures/current-artist-identification-producer.json; SHA256
f20d8c0eef1656aa8fa10e16b391b1d1831962080e65cf22610b906cd9745b27.
This is producer fixture adoption only, not live microphone/provider acceptance.

A new Apple compatibility regression was reproduced: after confirmed Profile
history revision42/clear3, current-only artist replies lacking history revisions
were rejected as stale revision0. The decoder now distinguishes the exact
history_persisted=false + conversation.history_scope=private_ephemeral shape,
with absent history/clear revision fields. Only that direct current response can
be accepted independently of history versions. Ordinary snapshots keep all
revision checks. Existing captured owner/epoch guards remain at text/voice reply
acceptance. The current private reply remains in RAM through same-scope history
refresh, never acquires archive/export rights, and is removed on the next current
reply, original expiry (if supplied), scope withdrawal or suspend. It does not
change history counters, send a playback command or add a local intent parser.
Exact producer text/voice standalone/Session cases are exercised after an older
confirmed history, plus refresh, stale-history refusal, no disk cache, codec
round-trip and withdrawal. Incomplete/mixed privacy markers cannot bypass versions.

Earlier unsigned Mac/iOS builds and538-test suite passed after the Music DNA
change. Full suite and both unsigned builds are requalified after the additional
private-response fix. All ordinary installed apps remain40058 and unchanged.

The full540-test run exposed a slow-response push coalescing failure: receive
recorded the window before an awaited refresh; when that read took over8seconds,
the subsequent tap regenerated again. Coalescing now records successful completion
for the same source/foreground context too. The next full540-test run passed.
A final Codable audit found result_set was decoded but omitted by the response
encoder; it now preserves the original ID/version/relative lifetime, with a codec
regression. Final541-test suite and unsigned builds are recorded below when done.

### Open acceptance boundaries after local source corrections

| Finding | Local status | Remaining evidence/dependency |
| --- | --- | --- |
| Music DNA status409 | Exact-code withdrawal/recovery and honest unknown hero | Core must establish which context/authority predicate rejects installed requests; no opt-out, reset or relink as workaround |
| Current artist text/STT | Exact d035dd95 producer fixture adopted; stale history-version rejection reproduced/fixed | Core candidate is not installed; actual microphone and visible reply acceptance remain open |
| DJMoment absence | Authorized one-shot admission snapshot retained | No current Moment/grant at that instant; planner/publication causality and sufficient actual contributions remain open |
| Moment/Session artwork | Existing subject-bound adoption design only | Early authoritative schema, assets, fixtures/checksums and exact producer pin remain queued with Core |
| Track Insight missing metrics | Unknown values remain unknown | Qualified producer measurements/analysis and explicit-Moment consumer adoption remain open |
| Push | Configuration/APNs distinctions, safe details/retry, duplicate-refresh fix | Missing trusted issuer configuration and real delivery acceptance remain open |
| Pi VibeCast | No replay, exact Session acknowledgement, precise failure state | Current valid receiver code and actual handoff/receiver acceptance remain open |
| All visual/navigation/polling fixes | Source regressions/unsigned builds; limited isolated native layout proof | Current ordinary installed clients remain40058; joint multi-device/native acceptance not performed |

This table is not a whole-task PASS. CI/publication/installation/production-update
pause remains in effect. No new external message, protected merge, test push,
re-pair, configuration change or restart was performed during this iteration.

Final local verification for this iteration:
- Full Swift suite:541 tests PASS,30.024s; log
  /private/tmp/djc-feedback-verified-final-tests.log.
- Mac unsigned build-for-testing: TEST BUILD SUCCEEDED; log
  /private/tmp/djc-feedback-verified-final-mac.log.
- iOS unsigned generic-device build: BUILD SUCCEEDED; log
  /private/tmp/djc-feedback-verified-final-ios.log.
- Localization:1117keys/five languages PASS; git diff --check PASS.
- Disposable build input: all70 Sources/Tests files matched authoritative writer
  bytes before both final builds. No app installation was performed.
- Existing root WIP and extra untracked Xcode projects retained.


Current disposition, final producer pins, build40060 and the later explicitly authorized four-device installation are recorded in [APPLE_FEEDBACK_STATUS_20261015.md](APPLE_FEEDBACK_STATUS_20261015.md). Earlier counts and installation-pause statements above are chronological evidence, not the current device state.
