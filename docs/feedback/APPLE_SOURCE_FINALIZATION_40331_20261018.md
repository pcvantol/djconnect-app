# Apple source delivery and finalization preparation — build 40331

Owner requested finalization of all delivered work after all-device installation.
One existing Apple writer and branch are retained. Source scope includes the 29
local commits after protected main `f6b0a71b3d8a2076539a2aea5e853626558b04ad`,
plus the subsequent delivered work through immediate Ask DJ example submission.
No protected merge or exact-main reconciliation is claimed by this preparation.

## Included behavior

Session and Now Playing presentation, artwork cache/tint/transitions/gesture
feedback, toolbar layout, conversation positioning and failures, welcome controls,
four Presence choices, shared device-speech preferences and the Watch Session
speech consumer, passive-surface diagnostic events, localized feedback drafts,
saved-session search and immediate example submission are included as source.
The standalone VibeCast native binding qualification package is included only as
a diagnostic tool; it is not a shipping runtime dependency or approval to use an
unfrozen producer contract.

Saved-session search covers loaded server summaries (date/time/duration/status).
Explicit Load more remains available during filtering. First-play suggestions
are local presentation controls invoking the existing Core Ask DJ request; no
client-generated recommendations, music facts or opening narration are added.

## Validation and installation

The exact production source for ordinary build40331 was hash-compared across the
276-input clean staging manifest. Native iOS (embedded Watch/widgets) and macOS
builds and strict/deep signatures passed before installation. iPhone/iPad actual
bundle versions and launch readback, MacBook/Mac mini actual installed versions,
processes and signatures confirm40331. No physical visual/audio or performance
acceptance is inferred. See [installation receipt](APPLE_BUILD_40331_INSTALL_20261018.json).

Latest complete source regression: **821tests/10suites PASS90.555s**, serial.
Ten standalone VibeCast tests and all seven required local validation groups PASS.
The first run failed five tests because validation-only workflow/release inputs
were absent from the clean test copy;29unchanged repository files were added
and all821tests rerun. No assertion was removed. Hashes/results are recorded in
the adjacent [finalization JSON](APPLE_SOURCE_FINALIZATION_40331_20261018.json). Previous bounded
native tests remain their own receipts: six iPhone and one iPad simulator case
(40324), saved-session search native test(40329), and first-play lifecycle test.
They do not qualify all40331 screens or physical providers.

## Explicit remaining work

- Watch installation: not confirmed; network tunnel/authentication failure,
  owner unlock/nearby-device request pending. No pairing reset or Watch TTS claim.
- Physical iPhone CPU/GPU/memory and long-session scrolling: USB run deferred by
  owner. Simulator/fixture profiling is not physical performance acceptance.
- Original Session history404 and rich widget continuity: Core diagnostics and
  original-reference/root-cause proof remain separate from client fixes.
- Queue recurrence after Discover: still open; prior identity/source diagnostic
  evidence does not prove the user's real upstream queue contents.
- Native device speech: shipped source/preferences and Watch consumer are bounded;
  actual all-platform accepted narration and physical Watch audio remain open.
- VibeCast runtime/owner onboarding: producer contract and physical joint gates
  remain open; isolated crypto binding tests are not admission proof.
- Core playback locale/artist-search fixes and the requested special opening
  DJMoment are owned by the existing Core writer. They are not app delivery claims.

## Recovery and delivery gates

Seven recovery duplicate paths remain outside the source candidate and are not
deleted. A private binary patch, selected-WIP archive and pre-finalization hash
manifest preserve the original checkout state under `/private/tmp/djc-finalization-40331`.
No generic add-all or cleanup of unrelated files is used.

A concrete source PR, required CI/Trusted Delivery and exact candidate Owner
Authorization precede protected merge. Documentary post-merge Finalization has
its own candidate and exact-main readback; neither approval is inferred from an
old source SHA or from successful private installation. Current full independent
technical/UX review is NOT_RUN; prior bounded reviews remain limited to their own
source. Product acceptance remains PARTIAL until the explicit open items qualify.
