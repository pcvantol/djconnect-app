# Watch companion V2 — implementation in progress, 3 November 2026

Assignment DJC-WATCH-COMPANION-V2-20261102; Apple #297, Core #1426, API #193.
Existing Apple sole writer `codex/watch-companion-v2-20261102`, base a57e016.
This is an incomplete source candidate, not a release, installation or closure.

## Implemented in the existing app

- Active Session: horizontal Session / Moments / More. Confirmed no Session:
  Ask DJ / More. Unknown/expired owner state withdraws Session controls.
- Compact home with the existing BrandHeadset, current track, playback and text/
  Sound entry points. Explicit avatar tap starts recording; navigation/push/widget
  does not. Legacy automatic wake listening no longer starts on the Watch.
- Removed Session start from Watch UI/model, foreground action and the phone's
  legacy proxy operation. Existing confirmed ending and uncertain-outcome reads
  remain. Server-side denial of free-form Watch start intents still needs Core.
- Frozen text/voice Session or general context through the existing validated
  conversation APIs; selected Moment text uses its original reference. Voice
  selected-Moment requests fail closed until Core selects the existing wire.
- Watch recording now uses 16kHz mono PCM16. The old nested base64 transport made
  four-second recordings exceed its42KB bound. Bounded ordered16KB raw companion
  chunks admit at most200KB/six seconds; one original request after completion.
  No automatic operation replay, partial dispatch or duplicate final dispatch.
  One partial stream/20 seconds and256 spent identities per owner are bounded.
- Explicit original Moment reader, existing admitted native Listen/Stop and text
  question; no generated summaries. Visible eight-item window has a newest
  indicator rather than automatically jumping the reader to incoming content.
- Reused queue, playlists, Discover, track favorite/Insight and device selection.
  Track question prefill preserves original recording metadata and requires Send.
  Output transfer while playing asks confirmation; paused selection stays silent.
- API PR194 proposal `djc-watch-moment/1` has a strict, tested original-locator
  decoder. One ordinary notification tap retains only bounded navigation intent
  through cold startup/pairing. No arbitrary URL, text grant, mic, TTS or playback.
  Current exact native-admitted Moment lookup works; older detail lookup is open.
- Separate Watch notification category preference `dj_moments_v1` is sent through
  existing registration. Serial registration, category signature and original
  owner/token checks reject stale completions. This is not live fanout proof.
- Existing ordinary WidgetKit kinds/aliases remain. Neutral copy is now Ask DJ;
  tap is navigation only. No phone grant is copied into Watch's separate group.

## Evidence and its limits

- Full Swift run:1669 tests/60 suites passed. Seventeen targeted Watch cases cover
  retained no-start/end uncertainty, exact context, locator denials, full-size
  audio assembly, reordered/expired/owner-change/invalid/duplicate denial.
- Watch, iOS simulator and macOS builds pass; final candidate checks are
  recorded under the task's external evidence directory, bound after commit.
- Nine existing contract/localization/brand/hygiene checks passed. Updated
  translations cover nl/en/de/fr/es; final localization validation is repeated.
- Native Series11 42mm and46mm:25 home captures each (four modeled Moods and
  neutral idle across five languages). Compact active42mm was visually corrected
  to preserve artwork/title/artist. These use explicitly modeled native input.
- `simctl ui content_size` returns45 on both Watch simulators. System Dynamic
  Type, VoiceOver, Reduce Motion/Transparency and actual touch/Crown acceptance
  remain unqualified; no screenshot proves those system behaviors.
- Reproducible disposable native-host/capture tools live under
  Tools/qualification/watch-v2. Fixture injection exists only in the generated
  external copy, never the shipping target. Original failed logs are retained.
- Owner reference was actually downloaded, byte/hash verified and inspected;
  docs/design/assets/watch-companion-v2 records provenance. #297 functional
  decisions override illustrated inconsistencies.

## Required continuation; do not close #297

1. Core: select Session-only Mood update without Profile-default mutation.
   Current settings3 scope is `profile_and_active_session`; the dedicated new
   Mood list is intentionally read-only until this conflict is resolved.
2. Core: original authenticated older Moment-by-ID read and context/grants;
   eight is a UI window, not history authority. Never substitute the latest.
3. Core: general reply + Moment HA-generated audio playable on this Watch,
   explicit source-exclusive Apple/HA selection, silence-preserving migration,
   separate automatic read switch, manual replay and actual original leases.
   Existing native Moment preparation is reused; it does not fill these gaps.
4. Core/API: actual committed publication, authorized current recipient/pair/
   preference/revoke/external_relay binding and deployed generic alert producer.
   Exact proposal e245258 / SHA256236f9a840015463e8d2f6962c7f759bb6bc24999c373ec697a076b9632da982c
   is pinned as an expired example fixture, not an adopted live producer or native receipt.
5. Watch passive producer: actual admitted Session widget/Stack state. Existing
   snapshot fallback stays neutral in its absence; no fabricated status grant.
6. Complete original-recording Insight binding, larger text and full native
   interaction/audio/route interruption tests, then independent exact-head review,
   protected source delivery and installed real Watch/HA/APNs acceptance.

The previous signed five-device build40456 is independent and unchanged. This
Watch V2 work has not been merged or installed on physical devices.
