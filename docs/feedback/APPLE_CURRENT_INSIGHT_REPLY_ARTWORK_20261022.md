# Current recording Track Insight and captured reply artwork — 22 October 2026

Consumer WIP in the existing Apple lane, branch `codex/apple-avatar-focus-ring`, base `8c349e7581a13c7700643df0fcf14366feb9e0ae`. Prior WIP remains intact. No backend edits, provider/model calls, installation, protected delivery or physical acceptance are claimed.

## Exact producer binding

Core reports protected `103dc6c58862b9ef277fbaa02d59039d5f13eefe` as the existing producer (before its separate overnight source hold). Apple independently read these exact Git blobs and matched their hashes:

- `docs/product/CURRENT_TRACK_INSIGHT_SUBJECT_V1.md`: `7d26e430b9bf88183bfbc8b0216463f412168d81bee9bcdd246a3188633676a4`.
- `examples/client_contracts/track_insight/current-subject-v1-core-consolidation-20261022.json`: `1cbc1ce62910e1218c8d1ad4caa71841b77611d75b6acbfeccb123f4b4e08e46`.
- `examples/client_contracts/history_playback_reply_artwork_v1/actual-ha-wire-current-cover-20261022.json`: `7e58b912c55d72e4697f207213d5f79fba3ef6145d252a9f7e4216d03df07089`.

The last two are imported byte-identically as test fixtures. Their declared isolated HA/synthetic provider boundaries remain intact. This is independent blob verification, not an Apple requalification of Core CI, installed HA or live providers. New uncommitted Core push/news fixtures are not consumer pins.

## Current recording

- Decode the actual additive `uri`/`current_uri` playback field. A title or artist is never an exact recording identity.
- Negotiate capability `current_track_insight_subject_v1` and version1; then send the closed `track_insight_subject` selector. The encoder rejects simultaneous catalog/player/Moment overrides. Unsupported older Core retains its legacy read route; failure of a supported current request does not fall back to another recording or last Moment.
- Decode current proof separately from explicit Moment proof. Previously, the explicit-only subject decoder could reject an ordinary current response. Existing explicit Moment selection remains unchanged.
- Capture original owner, transport, Session, settings, language, local playback and selection context before capability/analysis waits. Recheck before the second request and on completion. Same-name versions, observed A→B→A, pause/resume, backward seek over5seconds, output/provider/source change and owner/background withdrawal close the request. Normal progress and volume alone do not.
- Require exact response recording, supported schema/mode, bounded opaque observation and original absolute/relative lifetime. Request start conservatively anchors the relative budget; a monotonic deadline prevents local rereading from renewing it. Proof is RAM-only, omitted from persisted insight/history/widget DTOs and cleared on background/observed context change/expiry.
- Missing measured attributes remain missing. This work cannot supply energy, danceability, intensity or narrative interpretation that Core has not actually qualified.

## Captured answer artwork

- Recognize only the existing `captured_reply_subject` role and explicit `reply_display_allowed` flag, under its independent version1 capability and existing artwork capability.
- Admit only the exact retained assistant entry, its own recording and original album edition; albums bind themselves by URI. Current/active-Flow display flags cannot grant a reply image. No Now Playing cover, title matching, provider URL fetch or stored pixel fallback.
- Reuse the existing authenticated relative-image/no-store/expiry/geometry/attribution transport and `SessionArtworkView`. Session assistant cards and already matched Ask DJ replies use the same renderer. Profile replies without a matching loaded retained server entry remain text-only; no invented entry identity or whole-history scan/fetch is introduced.
- Existing viewport preparation and visible matched replies share one bounded queue. Six simultaneous visible replies cannot be discarded merely because an earlier request is busy. Valid grants coalesce; owner withdrawal cancels the queue and rejects late preparation. Ordinary history reads remain passive; there is no new backend route, periodic preparation or renewal on image expiry.

## Validation and remaining qualification

Canonical-root host verification: MATCH/exit0. Protected fixture/codec/lifetime/closed-selection tests passed. Actual AppModel synthetic transport tests cover ten delayed current-result scenarios plus owner withdrawal during capability detection. Captured media tests cover exact subject/edition/audience/expiry and independent capability; a real history-model synthetic transport test covers six visible replies, missing capability and owner withdrawal. Existing media decoding/authenticated transport tests remain exercised.

Focused latest run:18 test functions PASS4.796s (`insight-artwork-fourth.log`). The first broad run executed1,175 tests/24 suites and failed on three older request mocks expecting no capability read (11 assertions); evidence retained. Those mocks now explicitly provide an unsupported older capability envelope, preserving their original HTML-error/localization/auto-analysis assertions. The corrected complete suite passed: **1,177 tests in24 suites PASS122.745s**, exit0, `full-lane-tests-insight-artwork-second.log`. Opt-in native/network tests remain explicitly skipped.

Evidence directory: `/private/tmp/djc-apple-night-20261022`. Independent consumer source review, ordinary native builds, actual paired/runtime response and physical/user acceptance remain open. The missing musical-analysis source remains open. Historical immediate playback with preserved remaining queue is a separate contract and is not enabled by this increment.

Native compilation checkpoint: regenerated isolated projects include the new Core/UI files. Both `insight-artwork-native-mac.xcresult` and `insight-artwork-native-ios.xcresult` report TEST SUCCEEDED (one existing Bulletin renderer test looping20variants per platform). This verifies native compilation plus unchanged component smoke; it does not exercise the new TrackInsight transport or captured-reply pixels as native UI end-to-end, and does not establish installed acceptance. Initial regeneration into an existing evidence directory was correctly refused; new distinct project directories were used without deleting earlier evidence.

## Independent settings review correction

Core's first bounded review of manifest `affdf16f0366f384e2f38efc2a4be38b137be2d6c7d1eee2eff6c93078c47d09` found one P2: comparing the selected Mood value alone allowed confirmed Persona/Presence changes or Mood A→B→A revisions to accept an old response, and accepted proof was not withdrawn. Corrected with captured three-axis values/revision floors, Profile binding/full revision-bearing snapshot/voice revision, and a synchronous RAM generation latch in accepted Session/Profile observers. Both pending completion and accepted current display require the original generation. Normal progress/volume remain outside settings identity.

The same AppModel regression has24 cases (three axes, with/without ABA, Session/Profile-only, pending/already accepted). A derived temporary source copy restores exactly two pre-fix product files from the immutable first snapshot, without reverting root WIP: RED34 assertions/5.122s. Fixed source: GREEN24cases/5.066s and rerun5.024s. Evidence and source substitutions are recorded under `current-insight-settings-causal-baseline*`. Core independently verified immutable3-file manifest `54bc28a283667284b4efc0bcb38a2a33e82a56225612a6bcd9c9b5648f35fff4` and actual RED/GREEN log hashes, read the complete delta and returned `BOUNDED_SETTINGS_P2_REMEDIATION_NO_BLOCKERS`. Receipt remains `/Volumes/Shared Data/tmp/pcvantol/core-window-20261021-12h/apple-current-insight-settings-root-bounded-review2.json`. This closes that bounded finding only, not whole-app/native/installed/provider acceptance.


## Consolidation checkpoint — 23 October

The latest coherent full suite, including the settings correction and VibeCast
child storage regressions, passed **1,195 Swift Testing tests in24 suites**,
129.386s, exit0 (`full-lane-tests-childstore.log`). Ordinary generated iOS,
Watch, widget and macOS targets compile with code signing disabled
(`ordinary-native-ios-watch-v2.log`, `ordinary-native-mac-v2.log`). The first
ordinary build failed because the external project lacked its relative Apps
path; the qualification directory now links the original Apps directory. No
product source was changed to resolve that path. These are version-template
40021 compile artifacts, not a new installed release or native end-to-end
Track Insight/artwork qualification.
