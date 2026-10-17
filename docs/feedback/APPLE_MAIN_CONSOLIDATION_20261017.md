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

## PR111: concrete CI findings repaired

Initial published/owner-approved head664c8aad failed two checks; failures remain
recorded rather than relabeled. Native coverage could not compile two
Bundle.module references in the passive fixture loader. The native branch now
uses the same source-relative fixture strategy as other contract tests; SwiftPM
keeps its resource bundle. Separately, the original-deadline speech test observed
preparing after exactly two scheduler yields, with zero plays. It now awaits
observable idle completion and retains both the no-audio and expiry assertions.
Only these two test files changed; no production-code behavior or assertion was
removed. The fixes are part of completing the already authorized protected PR.

Fresh validation after both fixes:42 relevant tests PASS2.208s; full Swift suite
784tests/10suites PASS92.029s; full native Core suite with coverage784tests/10suites
PASS87.554s. xccov JSON export PASS. The first local native attempt stalled in
bundle directory opening before any test; it was gracefully interrupted. The
newly built products and generated test plan were copied with verified identical
bytes/modes/symlinks to a private temporary directory. The unchanged plan then
completed; no SDK repair, signing/entitlement change or runtime-security bypass.
The original cache-open limitation is preserved as infrastructure evidence.

PR: https://github.com/pcvantol/djconnect-app/pull/111. Fresh protected checks and
Owner Authorization must bind the updated PR head; the old head's status is not
reused. All functional acceptance boundaries above remain unchanged.

## PR111: deterministic replacement-session regression

The next native coverage run reached all784 tests but reported four assertions
in activeMoodBoundIntentDoesNotTargetReplacementSession. Its setup incorrectly
waited for nativeDelivery in a legacy receipt that has no native grant; the
background HTTP recovery could then observe replacement B while still bound to
A and correctly withdraw A. The test now holds the first A recovery response,
finishes the explicit B read, and releases late A. It still asserts B's identity,
revision and selected mood, zero stale-A writes and exactly one valid B write.
Fixture cleanup cancels the model's background work. No app code or assertion
was removed. Targeted test PASS; ten repeated executions PASS. Full updated
protected Swift/native coverage checks remain required.

## Protected source merged; exact-main qualification

[PR111](https://github.com/pcvantol/djconnect-app/pull/111) merged as
`b47d17a3bd7aade005787206785578bee585096b`, reviewed head
`0688cf6529358ba72660cb5c0da28d296df84463`, exact common tree
`422cf1173bc48e660931b0a5beb5f4264a03b973`. All premerge checks and official
Owner Authorization39060691226 PASS. Latest portable784tests PASS89.368s and
native784tests PASS82.596s. Main CI39061192756, native coverage and unsigned
Apple builds PASS. Coverage/runner artifact digests and embedded main SHA were
independently read and verified; see the portable source-main receipt.

Both original checkouts now clean main;18/155WIP paths preserved in stashes,
hash-verified archives and complete Git bundles. Three exact-proven local
branches removed, zero worktrees; remote only main. Excluded experiments remain
recoverable. Only the completed temporary Swift cache was removed after open-file
inspection; build products/logs/recovery were preserved.

Formal reconciliation39061762379 failed before durable publication. The pinned
central collector reads commit.data.files without pagination:300 paths versus
369 in the PR, full paginated commit API and local Git. Complete sets are equal.
The durable builder correctly refused the unqualified record; cancellation was
too late and no invalid record was published. Existing Core-writer owns the
collector fix and immutable producer pin. No Core modification or manual green
status by Apple. Documentary Finalization cannot substitute for corrected
exact-main formal evidence.

TDE observe ran successfully but its assessment and repository qualification
failed:3CRITICAL/174HIGH complexity findings, no regression baseline. These are
registered for triage/refactor, not suppressed. No new independent full
technical/UX review was run for this complete candidate.23 active functional/
acceptance requirements and all installed/hardware/provider boundaries remain
open as stated; this merge closes only the source inclusion.

## Finalization follow-up: voice-menu fixture concurrency

Draft PR112's first full Swift run39062016112 reported one issue: the menu test
compared whole-fixture request counts6 versus5 while independent Session recovery
was still allowed. The test now excludes only exact known recovery GET routes
from that menu counter and forces an independent active-session GET as a positive
control. Total fixture count must increase; all other request counts stay fixed.
Only the original POST voice-inventory read is outside recovery GETs; new
requests after that baseline must be GETs. Existing no-prepare/audio/execute,
voice selection, stale epoch, autoplay persistence and scope invalidation
assertions remain. Model background work is cancelled at cleanup. No app code
changes. The first local revision also rejected the original POST inventory
read; that failed run is retained and its contract expectation corrected.

Three original branches and two temporary qualification branches are archived
and removed; only main in the original checkouts and the active PR112 branch in
the temporary clone remain. All18/155stash file hashes were verified. Complete
bundles now live in stable ignored workspace recovery storage; original private
paths are preserved as symlinks, without duplicating1.3GB on the shared disk.

Fresh follow-up validation: targeted2tests/1suite PASS0.395s; ten repeated
voice-menu suites PASS; full Swift784tests/10suites PASS89.048s. Updated
protected native/build checks remain pending. Source-mainb47d17a3 evidence
retains its original binding.
