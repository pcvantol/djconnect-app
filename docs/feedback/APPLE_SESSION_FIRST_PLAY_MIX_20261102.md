# Apple lane — Session first-play “Verras me” mix

Current user instruction on 2026-11-02 selects integral Apple-lane delivery.
Continue in the existing Apple writer and draft PR295. This selection does not
create a second Core writer or authorize installation/merge of the open batch.

## Product scope

The authoritative placement correction is
[Apple #128, dedicated first-play CTA](https://github.com/pcvantol/djconnect-app/issues/128#issuecomment-6366101740).
The detailed producer requirements are
[Core #1210, first-play mix](https://github.com/pcvantol/djconnect/issues/1210#issuecomment-6365235562).
Earlier wording placing this action among the three chat suggestions is superseded.

The specified action belongs to an already active Session with no prior music.
It is separate from the three contextual Ask DJ questions and their dismissal.
It must not create a Session, start on screen entry/Mood changes, or replace a
paused queue. The owner's current clarification question about starting the
Session itself is pending; no additional Session-creation behavior is assumed.

One explicit CTA request goes through the authenticated Session conversation.
Core offers a speaker first when necessary, without playback. It then supplies
exactly three supported Mood-fit genre actions. One explicit genre tap starts
the exact bound ordered mix, without another Play Now tap. No local genre,
track, Music DNA, provider-access or mix-availability inference is permitted.

## Fresh source readback

- Apple batch before this intake: `719771bdc072cd7c206220be6b60adc691d8c920`.
- Core remote main, verified through GitHub on 2026-11-02:
  `6959d1ab61ed5a3c2ec9386900ff5e8a42eda202`.
- Core `custom_components/djconnect/ask_dj/examples_v1.json` is `qualified_v1`,
  but contains no `session_first_play_surprise_mix` route/entry.
- Core `custom_components/djconnect/mood_music_steering.py` still prepares a
  mix action whose label uses `COPY[locale]['now']`: genre interpretation offers
  a later Play Now action. This does not establish genre-tap playback.
- The existing Core worktree belongs to its current Track Insight writer.
  No changes to that worktree, Core main, provider state or credentials were made.

The existing generic mix/recommendation route is therefore not evidence that
this first-play contract is delivered. A successful client build or catalogue
compatibility check cannot qualify the missing first-play action.

## Existing Apple integration seams

| Concern | Existing implementation | Required adoption |
| --- | --- | --- |
| Active, never-played Session | `SessionTimelineScreen.showsFirstPlayHelper`, `DJConnectSessionHistoryModel.hasPlaybackForFirstPlayHelper` | Preserve pause/history/recovery exclusion and owner-scoped observed-playback latch. The current predicate has no rendered CTA. |
| Executable example qualification | `DJConnectAskDJCatalogue.compatible`, eligibility and pinned catalogue; `DJConnectAppModel.askDJExampleContext` | Adopt the actual Core-qualified first-play publication and exact prompt. Do not turn a draft or hardcoded translation into an executable action. |
| Text submission | Existing Session composer / `DJConnectSessionHistoryModel` conversation path | Preserve original operation identity, Profile/Session context and duplicate-send suppression. Do not overwrite a draft or submit a second surprise request after output choice. |
| Output presentation | Session output popover; `needsSessionPlaybackOutputSelection` | Render Core's authorized request-bound choice. A cached name or local output selection is not a producer decision. No autoplay on speaker selection. |
| Genre actions | Existing `DJConnectAskDJPlaybackAction.resultSetID` / `actionID` and ordinary action renderer/dispatcher | Render precisely the original three offered actions; preserve opaque identities and execute the chosen action once. No client-generated URIs or automatic secondary Play Now press. |
| Lifecycle | Existing Profile response epochs, Session identity, foreground and retention fences | Withdraw pending choices on owner/Session/Mood/output revision, TTL, permissions, new playback, navigation cancellation or end. |

## Concrete Core handoff required before executable Swift adoption

1. Protected source pin and qualified first-play catalogue entry/prompt, with
   exact existing capability/version negotiation and supported locale evidence.
2. Original no-output → output choice → three genre actions fixtures/traces;
   choosing the output resumes the original request and has zero playback effect.
3. Original valid-output → three genres trace, bound to actual owner, Session,
   confirmed Mood revision, output, result-set/action identities and validity.
4. A genre action that itself authorizes the exact frozen playable mix and
   produces the normal receipt/readback. It must not merely return another Play
   Now action. Include double-tap, lost acknowledgement and replay behavior.
5. Truthful unavailable/limited results for fewer than three supported choices,
   provider/recommendations unavailability, no speaker, paused playback and
   expired/replaced owner/Session/Mood/output. No fabricated Spotify mix claim.

This is a consumer dependency request, not an invented wire schema. Required
producer contract changes belong in Core's canonical docs and SYNC_PROMPTS first.
This document has not been sent as a message or posted to another lane.

## Apple completion and acceptance after that handoff

Implement one independent CTA and its pending/choice/error presentation in the
existing Session surface, using the existing authenticated message/action paths.
Do not change the ordinary Start Session action or the three-question panel.

Qualify all four Moods, five locales, music_only, draft/keyboard/VoiceOver/Dynamic
Type, speaker known/missing/cached/expired/zero, no music versus paused/history,
exactly-three/fewer-than-three choices, action expiry, output/owner/Mood/Session
changes, double taps, background/reconnect and uncertain delivery. Confirm that
CTA and speaker taps cause no play, and one genre tap causes exactly one original
mix play. Native iPhone/iPad/Mac and installed HA/provider playback remain
separate from source fixtures and CI.

## Delivery boundary

`APPLE_INTAKE_AND_INTEGRATION_AUDIT = COMPLETE`

`CORE_FIRST_PLAY_PRODUCER = NOT_DELIVERED_ON_VERIFIED_MAIN`

`APPLE_FIRST_PLAY_IMPLEMENTATION = NOT_IMPLEMENTED_PENDING_PRODUCER_HANDOFF`

`NATIVE_INSTALLED_FIRST_PLAY_ACCEPTANCE = NOT_RUN`

No first-play implementation or operational mix start is claimed by this
checkpoint. The existing Apple batch remains open; no fake executable CTA,
backend contract, capability flag, genre selection or provider result was added.
