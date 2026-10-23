# Apple VibeCast implementation and qualification — 22 October 2026

Status: source increment under test, not an integral operational completion.
No physical-device installation, deployment, activation, merge or publication was performed for this increment. Earlier unrelated WIP is preserved.

## Source changes

- Explicit foreground same-key recovery for uncertain enrollment, with retained handle, per-key FIFO, durable repair reservations and original challenge/clientData/deadlines. No automatic retry, key generation, re-attestation, QR renewal or B approval.
- Recovery journal preserves terminal attempt history across bounded explicit attempts and restart; Retry-After only restricts subsequent explicit work.
- UI exposes a separate repair action only under current native admission and paired foreground owner context. Async work rechecks authority and native continuation.
- B consent form observes session-history owner changes, removing confirmation and disabling lookup when authority is withdrawn.
- Disposable qualification generator supports macOS without changing shipping targets. Mac host uses a dedicated platform bundle identity and bounded SwiftUI Window; Mac screenshots use the main screen.

## Verified evidence

Evidence root: `/Volumes/Shared Data/tmp/pcvantol/djc-vibecast-completion-20261022`.

- `rendezvous-verified-tests.log`: 132 selected VibeCast contract, journal, recovery and consent tests passed. These use synthetic services/SDKs.
- `native-iphone-final.xcresult`: all five native consent UI scenarios passed.
- `native-ipad-final.xcresult`: all five native consent UI scenarios passed.
- Scenarios: lookup with separate single approval; Profile withdrawal without approval; explicit stop; uncertain stop without resend; unknown approval without resend. Production form and model, synthetic HTTP and credentials.
- Product-source hashes in `tested-source-inputs.json` identify the inputs used for the 132 regression tests and earlier iOS passes. All product hashes remained unchanged for the final native Mac/iPhone/iPad passes. The final native harness and product inputs are preserved in `source-review-manifest.json` and `source-review-snapshot/`.
- Localization validation passed for all 1,446 keys; syntax and whitespace checks passed before the functional tests.
- `/private/tmp/djc-vibecast-native-mac-v15-20261022.xcresult`: all five native Mac consent scenarios passed, including actual six-digit entry and separate explicit approval/stop. The production form is presented as a native sheet in a disposable SwiftUI Window. Test events use macOS `click()` and static-text `value`; iOS continues to use `tap()` and `label`.
- Earlier failed Mac attempts are retained. OS authentication and removable-volume prompts blocked early attempts. Later missing-field failures were traced to using iOS tap events on Mac; native clicks opened the form. A minimal sheet probe also failed with taps and must not be cited as evidence of a production sheet defect. Separate test-window and host identity changes are limited to the qualification host.

The initial Profile-withdrawal fixture allowed ordinary refresh to restore the synthetic Profile. Its server now returns `profile_access_denied` after withdrawal. The disabled-lookup assertion remains intact.

## Source review and external state

Receiver source `a713ab246465843447966ddfd08e53800e8502ff`, tree `5e00324b7430aa622f27a15d0ff91d8b61c93afa`: source-compatible with no blocking finding; see the separate exact-pin review. This is not permission to publish or real receiver acceptance.

API owner reconfirmed protected main `9ab24315a10b569b84e738d09bf32df6da12e38b`: no new native/admission packet, `current_apple_profile:null`, `operational_admission:null`, `activation_allowed:false`, expired historical 40408 window, guard false/503 and all 22 full-service gates open. Fixed-QA schema SHA256 is `24ab72719195f7971e070e56c52ceea7e67e02ee1bd7c6946eca99883194505f`.

## Remaining work — do not report complete

- Product replacement/rollover orchestration and exact consumer-snapshot review remain open; lifecycle primitives alone do not finish that work. Browser pre-QR replacement is a distinct proposed contract and must not be enabled as same-key recovery.
- A fresh exact app/build/profile selection and separate server/native admission packet with operator authorization are required for genuine native A qualification. Reusing 40408 or extending its allowance is forbidden.
- Genuine public/QA QR A → HA receiver → owner B → physical screen acceptance has not run. Local native form passes do not establish that chain.
- Mac manual six-digit B entry is independent of QR A; it still requires an ordinary authorized paired owner, active Session and qualified external receiver origin.

## Exact uncommitted source review snapshot

`source-review-manifest.json` SHA256 `d09b8c06cb9a2f255623fe249491ca398bbe4c1a96507e7da533e8b8c2924723` identifies 56 preserved review files under `source-review-snapshot/`, relative to base `8c349e7581a13c7700643df0fcf14366feb9e0ae`. This is an explicitly uncommitted review snapshot, not a Git consumer pin or executable runtime admission. API owner has been asked to review the same-key bridge against the exact contract criteria.

## Later receiver protected-source readback

Local Git object comparison confirms protected receiver source `29fd9c576d52d14947ef2ea00e8ff8c75c18c84a` has the identical tree `5e00324b7430aa622f27a15d0ff91d8b61c93afa` as the reviewed `a713ab246465843447966ddfd08e53800e8502ff`; the source review therefore applies to these exact identical source bytes. Later `8685a03` changes only `REPOSITORY_STATUS.md` and the source-finalization receipt. This readback does not independently verify CI artifacts, deployment or operational admission.

## API review corrections and second snapshot

API review of snapshot `d09b8c06cb9a2f255623fe249491ca398bbe4c1a96507e7da533e8b8c2924723` requested changes for two P2 findings. Both are corrected in the second snapshot:

1. Repair budget owns consumed attempts even if a challenge request fails before creating a recovery record. A valid second reservation can now begin a challenge without requiring a first challenge-history entry. No cooldown, counter or durable reservation is reset.
2. Server Retry-After and paused completion now persist in one actor transaction/write. A failed or uncertain write leaves either the original reservation occupied or both pacing and completion committed. The coordinator propagates storage failure and cannot independently release the reservation.

Causal tests cover first challenge failure, restart and exact cooldown boundary, second challenge admission with exhausted third attempt, and both pre-commit and post-commit write failures. A coordinator-level intercepted 429 test verifies no SDK call and no early follow-up admission after uncertain pacing persistence.

`rendezvous-review-fixes-final-tests.log`: 135 tests in 10 suites passed in 2.879 seconds. The 15 passing native B scenarios were run on the first snapshot before these recovery-only corrections; they do not independently test the recovery corrections. B form/model source is unchanged by these corrections.

Second manifest: `source-review-manifest-v2.json`, SHA256 `81c216f8dd89eb31673c83c28126ee194fd3489b38980d6c08f5e21ae13b38aa`, 56 copied files under `source-review-snapshot-v2/`. This snapshot supersedes the first for same-key recovery review only; the first review's changes-requested disposition is not reused as approval. Second owning API review requested.

The corrected second snapshot also passed on the iPhone simulator: `native-recovery-review-fixes.xcresult`, 9 tests in 1 suite, 0.103 seconds, Xcode test exit 0. These exercise the actual Core recovery coordinator and journals over intercepted synthetic responses/in-memory persistence; no genuine native SDK or HA/TV effect.

## Owning API second-review disposition

API writer returned `SOURCE_GO_SAME_KEY_RECOVERY_SLICE` for exact v2 manifest `81c216f8dd89eb31673c83c28126ee194fd3489b38980d6c08f5e21ae13b38aa`: F1/F2 closed, all 56 hashes checked before/after, exactly four changed files reviewed. Its independent memory-journal counterproof confirms second-challenge admission after challenge failure and no early eligibility for before/after-commit pacing-write failures. Receipt: `/Volumes/Shared Data/tmp/pcvantol/djc-api-apple-recovery-review-v2-20261022/receipt.json`; scope/details in adjacent `REVIEW.md`. This is approval of the same-key recovery source slice only, not replacement/rollover, a Git consumer pin, build, runtime admission or whole-app GO.
