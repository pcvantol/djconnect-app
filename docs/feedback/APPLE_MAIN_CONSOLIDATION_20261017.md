# Apple source consolidation into main — 17 October 2026

Direct owner instruction: merge the existing Apple work together into main.
This is source consolidation, not acceptance of every open feature, installation
on additional devices, production distribution or a Core/HA deployment.

## Inputs and conflict decisions

- Original checkout: `2fc7fdf173d9ddb9c309e5837f1c7a449e170be9`, 12 tracked
  modifications and six new files. All 18 paths and its Git refs were backed up
  before mutation. Its Moment decoder/contracts, fixture server/generator,
  lifecycle fences and independent Session/player navigation are represented in
  the current, more developed implementation. Old permissive presentation helpers
  are superseded by shared native source/lifetime admission.
- Existing Apple writer: `4fa911527eb02fed8bed71397ee4c95fff2b2daa`, 296 commits
  absent from current protected main, plus 155 WIP paths. Preserve the current
  qualified settings3, TTS, artwork, Session, Watch and UI implementations.
- Recovery: `ffc658845b13d1927f4df787b30e5db73041cbee`, seven divergent commits.
  Its layout/control work is represented or intentionally superseded by current
  responsive headers, white controls, pinned moods and later owner corrections.
  The dummy-output assertion is intentionally obsolete; the current token-bound
  recovery tests replace forced re-pairing. Recovery history is merged into the
  candidate without reverting its current tree.
- Protected main: `be7e63609193561bfd37ee144ecbd8dad04d5609`. Its dependency pins
  are preserved. Current output-generation/no-replay logic and Mac context
  navigation already include or supersede its source fixes. Every upstream
  regression function is retained exactly once.

Both original checkouts remain untouched during candidate preparation. Their
binary Git bundles, WIP archives/manifests and comparison inputs are private.
A dedicated temporary integration checkout carries the candidate. Its parents
include writer, recovery and current main; no direct protected-main write.
The repository uses squash merges, so source inclusion must be proved by exact
PR/tree/merged-SHA evidence rather than post-squash ancestry of every old commit.

## Deliberately retained outside the merge

The duplicate untracked `DJConnectApp 2.xcodeproj` and `DJConnectApp 3.xcodeproj`
are recovery copies, not the canonical project. The uninstalled Base-launchscreen
experiment and its coupled strict packaging-validator change remain preserved in
the original writer and backups. The candidate uses the qualified ordinary40282
root-level launch storyboard and matching validator. The first static screen's
language decision/physical acceptance stays open. No experiment is discarded or
silently presented as delivered.

`project.yml` remains the source of truth; the canonical Xcode project was
regenerated. Two EOF-only blank lines were normalized when previously untracked
Swift files became part of the staged diff. No new runtime behavior is intended
by these formatting repairs or by conflict reconciliation.

## Qualification and delivery boundary

Fresh portable contract/security, localization/brand, ordinary-install hygiene,
work-register checks and native builds are run against this consolidated input.
Final results and PR/merge evidence are recorded below when observed. Prior
784-test/build40282 and physical-device receipts retain their original artifact
bindings; they do not substitute for these fresh source checks.

The existing open-work/requirement registers remain the authority for unresolved
LAN/WS, speech preview/native/provider matrix, Profile isolation, artwork coverage,
VibeCast verifier/scanner, OS surfaces, Watch hardware, production push and
performance/crash acceptance. Source merge must not close them by inference.

Private preparation evidence: `djc-main-consolidation-20261017` contains both
recovery bundles/WIP archives, original/recovery/main disposition records,
qualification input hashes and full command results. No private key/token
signature found in the tracked-input scan; raw App Attest proofs/handles remain
outside Git as before. Public App Attest reports contain sanitized observations.

## Observed fresh candidate results

Full Swift suite: **784 tests / 10 suites PASS (93.044s)**, serial.
Unsigned Mac and iOS builds including Watch/widgets PASS. Contract fixture:
18 WebSocket messages/16 routes and29 HTTP routes; security PASS.1257 keys/five
languages and ordinary launch/brand source PASS. Two ordinary-install hygiene
tests and owning register checks PASS. All291 qualification input file hashes
remain unchanged across these checks. No extra device installation or new
physical UI/audio/production acceptance is claimed.

Original newly added localization keys are all retained in every language.
Current shared admission and lifecycle/target tests cover the evolved original
Moment path; old callbacks and visual assertions are not mechanically restored.
