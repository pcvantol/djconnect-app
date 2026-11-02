# Apple Session startup: Verras me / Selecteer playlist

The owner-selected scope is the separate first-play flow after ordinary Session
start. This stays in the existing Apple batch PR295. The welcome screen and the
three contextual Ask DJ suggestions do not start this flow.

## Producer and presentation

Core PR1423 (`b33ea880`, included in main `e91690a2`) supplies
`docs/product/SESSION_START_ACTIONS_DNA_V2.md`. Its v2 Music DNA contract supersedes
the earlier v1 producer dependency notes. Apple requires both capability flags
and exact versions: session_start_actions=1 / session_first_play_surprise_mix=2.
The active Session response supplies the two localized startup items.

- Verras me sends the exact supplied localized prompt through the existing
  authenticated Session conversation. It never creates another Session.
- Core can first supply output choices. Choosing the original opaque output
  action continues the same flow; Apple does not issue a separate play command.
- Core supplies exactly three Music DNA genre actions. A deliberate genre tap
  sends its original result_set_id/action_id with operation=select through the
  same conversation. There is no additional Play Now step.
- Selecteer playlist opens the existing playlist screen, without conversation,
  Session start or playback commands.

Genres, ordered Spotify catalogue tracks, availability and provider decisions
remain Core-owned. Apple does not generate genres or seed from personal
playlists. Missing DNA disables the surprise item while retaining the separate
playlist route when Core advertises it.

## Client safeguards

The retained coordinator binds Profile/epoch, active Session, language, configured
origins, material Mood/persona/presence revisions and observed output. The exact
selected output is the only permitted output transition during continuation.
Scope changes retire old choices. Actual playing withdraws the startup card.
The composer draft survives these sends.

A synchronous latch admits one send per explicit tap. Output/genre choices retain
the original bounded 60-second wall and monotonic deadline, shortened by the
accepted response/result lease. Continuations never renew it. Unknown effects
finish locally without automatic retry or fresh UUID replay. Opaque identities
are sent directly; Apple never rebuilds URI lists or mix actions.

Malformed additive startup metadata cannot break decoding an otherwise ordinary
Session response. The two-item menu and first-play envelope have strict version,
no-autoplay, localization, source and selection-effect checks.

## Evidence boundary

`Tests/Fixtures/session-startup-v2.json` contains reduced original Core wire fields,
with source pin and SHA256 provenance. Contract and authenticated conversation
regressions cover rendering reads, original prompt/context, speaker then genres,
exact opaque select packets, duplicate taps, draft retention, unavailable DNA,
expiry before and after output continuation, context withdrawal and unknown
outcomes. These are synthetic producer fixtures, not live Spotify acceptance.

Final validation on unchanged source: 1,662 Swift tests in 60 suites pass
(`startup-full-r2`), all nine repository check groups pass
(`startup-validation-r1`), and unsigned Mac (`startup-mac-build-r1`) and
iOS/iPadOS plus embedded Watch (`startup-ios-build-r3`) builds pass.
The targeted producer/conversation run (`startup-tests-r11`) passes both test
declarations, including seven integrated scenarios. Source hashes are retained
in `startup-final-source-hashes.json` in the external batch evidence directory.
Earlier failing test runs are retained: the initial synthetic timeline lacked
the required tail-window bounds; correcting that fixture leaves the production
owner/transport checks intact. No installed Home Assistant/Spotify playback or audible mix
acceptance is claimed here; that requires the matching Core producer installed
and a deliberate owner device test.
