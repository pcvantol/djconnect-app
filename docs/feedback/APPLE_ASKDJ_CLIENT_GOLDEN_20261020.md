# Ask DJ real-client Golden integration — 20 October 2026

Owner request: run the existing Core Ask DJ Golden cases through a real native
client and Session, with actual configured model use, as a pre-production check.
Owning Apple issue #158; existing Core owner was explicitly consulted. One Apple
writer; isolated branch `codex/askdj-client-golden` based on main
`e106a467011b9ea84d301a81c4e07251314cc6dd`. PR155/156/157 remain separate.

## Immutable scenario basis

Core main `8b221d07fe2215d9516d18fe92c832332c7a16ab` supplies
`docs/verification/fixtures/askdj_golden_release_matrix_v1.json`:39families167steps.
Derived catalogue SHA256:
`f54eaffb4d3caa7760a2462e6e4f50943b670409581cbdc04a58c70b00dd1359`.
Original matrix digest and source path are in the catalogue. Reproduction from
immutable Git objects is byte-identical. No current Core WIP is imported.

## Delivered Apple preparation

The opt-in hosted XCTest uses the ordinary paired `DJConnectAppModel` composer
send path, captures the real client-message identity, reopens exact server history
and the active Session timeline, and renders the actual `AskDJMessageBubble`.
It rejects absent/stale contexts, changed app binary/build/owner/session/source,
noncanonical or partial/reordered chains, no ordinary prior installation, demo,
monkey, duplicate run and exhausted request/deadline budget. Audio is not silently
reset or enabled. No Session/Profile creation or clearing, no automatic replay.

A separate ignored hosted-project generator and private `.xctestrun` launcher do
not change ordinary app signing/entitlements, release dependencies or installed
apps. Default CI only checks offline orchestration and compiles/skips the unarmed
test. There is no new test endpoint or Apple-owned model execution pipeline.

Client acceptance is explicitly unverified provider evidence. Reconciliation
requires matching native turn/answer/session-entry hashes, completed private
Core/provider receipts, no unbound attempts, model budget, source/install/candidate
binding and actual semantic/effect verdict. A smoke subset never becomes full
release coverage. The full gate requires all167cases on the same candidate.
Native pointer gestures, image pixels, physical audio and product/owner acceptance
remain separate from this model/send/render/readback check.

## Local verification

- Eight pure orchestration regressions PASS: exact inventory, complete chains,
  budget/identity/language rejection, target-specific xctestrun preparation, missing
  or reused/failed provider evidence, candidate mismatch and partial/full coverage.
  These use synthetic parser inputs, not runtime provider proof. A subsequent
  negative regression reproduced a wrong-catalogue full-matrix false PASS; the
  gate now rejects that receipt explicitly, validates exact candidate pin shapes,
  and binds each question digest and model policy to the immutable Core catalogue.
  All eight expanded regressions PASS after the repair.
- Full Swift suite PASS:72XCTest cases with1intentional opt-in SKIP;901Swift Testing
  cases PASS. Subsequent affected native qualification compile/unarmed-skip checks
  cover the final bubble/timeline/installation guard refinements.
- Separate macOS hosted target `build-for-testing CODE_SIGNING_ALLOWED=NO`: PASS.
  The actual generated xctestrun target/environment-path adapter is checked without
  launching the test. No further known-failing Mac runner launch was repeated.
- Armed unhosted/SPM negative probe PASS: rejected at the ordinary-app host pin
  before model construction/network/run-marker/preference access; no output folder
  created. This is a safety rejection, not a real Session/model run.
- HA fixture security, Apple work registers and diff checks PASS.
- No paid model invocation, real Session mutation, installation, signing workaround
  or deployment performed. No runtime E2E PASS or release PASS claimed.

## Remaining joint acceptance — deliberately OPEN

Core confirmed its current inventory is not a qualified native executable consumer
manifest, fixture admission or provider-export API. Its local research40-call grant
is not transferred to this suite. The private reconciliation format is a proposal
for Core's qualified test adapter, not a new assumed production wire contract.
Core must supply reviewed source/export/installation binding, disposable Session
and family preconditions, exact model/budget policy and correlated provider/effect
readbacks. Invocation counter `agent_calls` alone is insufficient.

Some inventory steps require special failure/context/provider fixtures or native
actions. They are not automatically valid arbitrary chat prompts. Actual coverage
remains unqualified until the producer defines executable preconditions/outcomes.
The initial literal questions use the Dutch client; five-language runtime expansion
awaits qualified localized exports. The first joint run and independent answer/
effect quality review remain required. Source/CI success must not close #158.

Runbook: [real-client Golden qualification](../../Tools/qualification/askdj-golden/README.md).


Review hardening (20 October): only canonical `zero` and `one_or_two`
policies have numeric consumer adapters. Every other policy is refused in plan,
native preflight, reconciliation and release aggregation pending qualified Core
adapters. Therefore the complete 167-step gate cannot currently PASS. No prose
policy is interpreted as permission for a model call or assumed local outcome.
Reconciled batch schema 2 retains each provider receipt hash; aggregation rejects
legacy batches, missing/count-mismatched identities and receipts reused across
batches, even with distinct case coverage.

Core also confirmed that agent-call ceilings do not bound transport attempts:
the inspected HA OpenAI SDK defaults to two retries. Fixture admission must prove
and enforce actual SDK/HA transport-attempt bounds before I/O. The client budget
is only an admission declaration, not provider enforcement. No retry setting or
HA installation was changed, and no real provider/session run was performed.

Both P1 counterexamples reproduced against 0b22e71: unsupported `two` with no provider attempts and two disjoint matrix batches reusing one receipt incorrectly passed. Corrected code refuses both. Ten pure regression tests PASS; affected Swift native test compiles and intentionally SKIPs unarmed, with no network/model call.
