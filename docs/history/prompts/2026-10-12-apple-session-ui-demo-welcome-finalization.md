# Apple Session UI, review Demo and welcome hero — Finalization snapshot

This reconciles the owner-requested UI/Demo/welcome followup to
`DJC-APPLE-SESSION-CONVERSATION-HISTORY-V1-20261008`. It preserves terminal
#95/#96 and the earlier source/history deliveries #97/#98. It starts no Core
lane, Store release or next Apple slice.

## Source and authority

One reused Apple writer and isolated checkout. Source branch
`codex/apple-session-newest-first`, exact base
dfa26059d358846394107abd16a5e89e97144d1d,
[PR99](https://github.com/pcvantol/djconnect-app/pull/99), reviewed head
1b78af9d2aa94176ed79c0337ae3f780894edf38. Owner separately approved exact
e5 source/draft publication, exact1b test-only PR update and exact1b protected
source merge. Official
[Owner Authorization38200426205](https://github.com/pcvantol/djconnect-app/actions/runs/38200426205)
PASS binds repository/pr99/head/main/HIGH_RISK/owner+actorpcvantol. Downloaded
artifact ZIP digest3b4715cff470af5549601c25cdc641eb8f4ffa1f093699066b565a0b4547c52b
matches GitHub metadata; formal fields independently verified. Normal
match-head squash, no admin override or invented status.

Actual merged source-main0e0deed212107b8ab36a7cfa0b3d32ed2c388231,
tree6dae800c84d76b6dd81b430314af284c4cadc4b7, parent equal to the preserved
base. PR/remote/Git readbacks independently agree; tree equals the approved
candidate. Native product source e5d268142ca6f6f9dc23f2d263ff56aeac83832f is
byte-identical to1b product code; only an obsolete demo-consent test changed.
This separate Finalization candidate requires its own exact-head publication
and protected-merge decision before public effects. This text does not claim
those future effects already occurred.

## Native behavior and ownership

The idle Session route has a localized premium native hero, decorative vinyl
artwork, adaptive mood choices and a prominent existing Start action. Artwork
is noninteractive/AX-hidden, headline follows Dynamic Type, and opening the
screen causes no playback or Session mutation. The compact iPhone variant
keeps its full CTA above the tabbar; the wide iPad/Mac variant places artwork
beside the copy. Once active, current native Moment/music stays pinned and
contributions appear newest first with subtle in-card question glyphs.
Toolbar/popover controls preserve handoff and the separate player. Archive
rows use queue-style gradients, honest start/end/duration, guarded toolbar/pull
refresh and loading/result notices. Native archive links own separate rows;
iOS multiline Send dismisses the keyboard explicitly.

Pinned Core491 server mood revisions remain authoritative. Music DNA privacy
copy is localized; output enumeration reloads when advertised capability
becomes available; scoped public provider artwork references are accepted.
Missing Discover producer image fields remain directed to the existing Core
owner in [#1101](https://github.com/pcvantol/djconnect/issues/1101), including
[the targeted receipt](https://github.com/pcvantol/djconnect/issues/1101#issuecomment-6110636425).
No provider lookup, invented server field, local live intelligence or second
Core writer is introduced.

Explicit Demo uses curated localized in-memory typed native Session models:
active Moment/music/conversation plus two readonly previous Sessions, local
search/Open and contextual text or explicitly scripted voice examples. Demo
grants no Profile authority, sends no server requests, preserves ordinary
chat/widget caches and records/uploads no audio. End/restart preserves completed
examples, selected mood and separate demo-player context. Enter/exit invalidates
unfinished voice operations and clears private demo navigation; current
background/reconnect/end guards remain distinct from Demo behavior.

## Measured evidence and exclusions

- General Swift and Mac Xcode suites report473 tests PASS; each hosted suite
  explicitly skips8 environment-gated producer tests. Those skips are not
  represented as live execution. Dedicated paired/native qualification is
  separate. All1061localizationkeys and unsignedMac/iOS builds PASS.
- Native iPhone/iPad complete Demo current/typed/scripted-voice/readonly-archive
  and end→hero→mood→start PASS. The ordinary paired-owner iPhone regression
  separately proves genuine pair, decoded native state/Moment, mood revisions,
  update/reconnect, player navigation and history recovery against pinned
  Core491 with modeled configured source/device slots and synthetic tracks.
- Exact-e5 owner-authorized temporary local Mac ad-hoc bundle proves native
  hero, selected Feest/start, current Moment/music, exact readonly demo-evening
  with Electric Feel/no composer, scripted voice entries7/8 and actual native
  keyboard+Send entries9/10. No certificate or ordinary installed app replaced.
  Initial AX-value setter did not update binding and is excluded from input
  PASS; transient early AX snapshots and wrong Start identifier attempt are
  excluded. Stable later native snapshots/actions are the measured evidence.
- Independent technical exact-product Source GO plus test-only correction GO;
  bounded actual iPhone/iPad/Mac screenshot UX GO. Hash-bound screenshot
  metadata is portable; pixels/raw result packs remain in retained private
  native evidence. The before-image is owner supplied, not independently
  exact-source-qualified. No screenshot/model label alone is claimed as a live
  producer or physical acceptance result.

Initial e5 hosted CI/TDE failed the old microphone-consent expectation. Its
permission-status guard had skipped the obsolete assertions in the prior local
permission environment. Correction runs regardless of permission and verifies
no popup, unchanged permission, no recording and localized scripted response.
Failures are retained; no test is disabled to obtain PASS. Current corrected
Mac473suite and targeted Swift test PASS.

## Exact-main qualification

[Source-mainCI38200531242](https://github.com/pcvantol/djconnect-app/actions/runs/38200531242)
and post-merge coverage PASS. Automatic
[SHA-evidence38200987651](https://github.com/pcvantol/djconnect-app/actions/runs/38200987651)
PASS; internal prerelease
`internal-ha-0e0deed212107b8ab36a7cfa0b3d32ed2c388231` targets exact source-main
and contains one redacted formal JSON decision. File hash
a24573c09e1e1fd64898fefee34c1199f61ffa221cf8051e4f473837d43bd25e equals the
server asset digest. Canonical integrity
3f50ed0f4210d3294bfdd7fee7be5e193eb254a4f687c0c54bc0c892803f1b6c,
12formal required PASS fields, schema and redaction independently validated
with policy ebbb35f038a7a3c7d46c12660968bcd50eb67580 and validator file hash
2419a355e1fb6b85448d362681c061470d59d45936b06f2b9a6249278351a449.
Coverage ZIP digestd5713fe8ad6595a1a5bfa800ff0282f682858bba620ec0c60519dba758900b73
matches metadata and its coverage-main-sha independently equals source-main.
Main runner ZIP42212e56f061c7a2ef8a4af907890d7d7bf57e9dc0bd0af2abd53156e8dfd628
and git_sha binding also verified. Premerge CI preview94d6e868a2eb8852f71f81bf7150a0496be16903
parents independently equal exact base+candidate and its tree equals candidate.

These are audit metadata and unsigned CI artifacts, not installed hardware or
signed distribution receipts. Portable authority/native/main/formal-decision
records are in [session-ui-finalization](../../verification/session-ui-finalization/source-main-readback.json).
The unchanged nonblocking TDE workflow passed app test/coverage but cannot
install TDE1.1.1 with its baseline Python below>=3.11; assessment NOT_RUN. This
known workflow limit is not silently repaired outside this Apple followup.

## Reconciliation, remaining acceptance and cleanup

Source is MERGED_UNRECONCILED until this separate protected Finalization is
published and its exact main/internal evidence read back. Intended repository
state MERGED_RECONCILED; product acceptance remains PARTIAL. No current genuine
physical microphone/STT, VoiceOver, hero XXXL/long-language, real-provider
speaker transfer or Store acceptance is claimed. Earlier owner-reported real
voice remains bound to its older installed source. Last verified physical iPad build is40013 and
MacBook latest installation pending. iPad simulator device/app40014 runs
explicit Demo, but Simulator.app GUI is absent; visible simulator-window
request is unresolved. No installation, HA production/dev or Store/TestFlight
effect follows from this Finalization authority.

Original unrelated WIP, closed assignments, source branch and verified recovery
bundles retained. Only exact own temporary Mac process59283 was stopped after
proof, and own current UI lab8366ede5/loopback18197 stopped after command,
mount, producer pin and port identity checks. Other labs/production and volumes
untouched; native source/log/receipt/screenshot packs retained. Documentation
publishing/readback and any later separately authorized physical effects must
be reported only after execution in owning[#87](https://github.com/pcvantol/djconnect-app/issues/87).
Stop after this selected Apple followup; no new capability or second writer.
