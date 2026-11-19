# PR169 source delivery, installation and cleanup

[PR169](https://github.com/pcvantol/djconnect-app/pull/169) merged candidate
`d2b14822599963d7b6e5f3f32b8007db7b0d50fb` as main
`9980279fbfb458b0a34aa0347c4c534b9a330026`, with identical trees. All pending
day and earlier night-lane source changes are included; obsolete duplicate
header/form structures were reconciled with the later shared presentation.

The integrated local Swift suite passed 1,035 tests. The isolated native iOS
consent suite passed 19 tests with 9 explicit skips and no failures; the initial
shared-volume XCTest launcher was stopped before tests ran, and the same test
products succeeded from a local temporary directory. Offline VibeCast passed 28
tests. Localization 1,389 keys, brand/work registers, ordinary install regressions
and HTTP/WebSocket/security fixtures passed. These are bounded checks, not
physical button/audio/VoiceOver or full backend acceptance.

PR CI 39624471464 and main CI/coverage 39626856219 PASS. Formal reconciliation
39628569024 published the canonical qualification asset. Its file and canonical
integrity digests,12/12 required checks, exact runner/main SHA and coverage
ZIP/main SHA binding were independently verified. The earlier main CI was
superseded by another push run for the same exact SHA, not counted as green.
TDE-observe's workflow succeeded, but its substantive assessment remained
BLOCKED (`store requires validated canonical evidence`); no TDE assessment or
independent source review is claimed.

Development-signed 4.0.0 build 40405 was built from source main 9980279. All 210
compiled source/resource/project/dependency inputs match that commit. The
existing signing profiles cover the requested iPhone, iPad and Watch. No new
provisioning, TestFlight, App Store or public binary publication was requested.

| Device | Verified outcome |
| --- | --- |
| Mac mini | 40405 installed; strict signature, full bundle bytes/modes/symlinks and launch PASS |
| iPad | Install connection closed; version readback then failed; installation unconfirmed |
| iPhone | Owner deferred availability until tomorrow |
| Apple Watch | Owner deferred availability until tomorrow |
| MacBook | Existing host-key-verified Bonjour SSH route unavailable; deferred |

App data and pairings are preserved. The Mac installation retained its previous
app during replacement. After 40405 readback and launch, that temporary backup
was removed only after a fresh full-bundle match to the retained 40404 product.

The owner separately approved preservation of original history followed by
removal of 79 stale local branches. All original commits remain reachable through
`archive/apple-oct21-source-history` and
`archive/apple-pr167-finalization-history`, both local only. There was one
worktree and no stashes to remove. The source PR branch is also absent remotely;
no Git objects or reflogs were pruned. One owned test simulator and one proven
duplicate temporary test-products directory were removed. Deleted allocated
file bytes total367,980,544; that is not an attributable APFS free-space delta.
The 18 unique old app products and two Git history bundles were retained because
their content/object redundancy was not proven. Unique test evidence remains.

Music DNA artwork, current Track Insight binding/unavailable measured data,
sparse automatic contributions, exact historical-track playback authority and
genuine VibeCast SDK/fixed-QA/full-chain acceptance remain separate open work.
The Core owner is handling its contribution correction and HA-dev deployment;
this Apple finalization changed no HA installation or backend setting.

The adjacent [portable receipt](APPLE_OCT21_MAIN_DELIVERY_20261021.json) binds
artifacts, source, canonical evidence and private install/cleanup records by
digest. This documentary Finalization changes no compiled inputs. Source-main
is qualified; final documentary delivery/readback is pending this PR. Device
installation and product acceptance remain partial as stated above.
