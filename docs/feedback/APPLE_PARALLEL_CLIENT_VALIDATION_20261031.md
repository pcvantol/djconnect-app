# Parallel Apple client validation — 2026-10-31

Status: SOURCE_PREPARATION; no protected delivery, installation or physical
acceptance is claimed. Base: `f6eac76ae4a35602616262619623794c1bcdc8d8`.
The separately reviewed selected-context performance commit `92abb2f` is not
part of this tree and retains its own evidence/review boundary.

## Concrete faults and bounded changes

- Independent fixtures previously exhausted the same process-wide two-request
  artwork/JSON and speech pools, producing unrelated `invalidResponse` failures.
  Task-scoped test runtimes isolate those pools and the App Attest installation
  queue. The shipping default still shares one process runtime and the original
  limits. A real transport regression holds two requests in one runtime, denies
  its third request before dispatch, and completes another runtime's request.
- Fixture cases run with eight permits, including each parameterized case.
  Child tasks retain their case's limits. Only native focus/window fixtures use
  the exclusive AppKit permit. No global `--no-parallel`, new skip or assertion
  suppression is used.
- Persona and passive-image races use actual held-response/continuation
  boundaries. The speaker fixture waits for the turn's committed terminal state,
  using its existing bounded wait, rather than the earlier sending flag. The bulk
  delete fixture returns a valid tail-window page when background preparation
  owns the coalesced read; it no longer returns an invalid plain-page response.
- The dispatch test observes the synchronous resume call before the queued owner
  withdrawal. Its original state assertion runs after completion, and stronger
  call-order assertions catch a yield before dispatch. Production leaves both
  internal observation callbacks nil and adds no await to the dispatch segment.
- A proposed Discovery parallel-read change was rejected by independent source
  review: the real WebSocket adapter lacks shared negotiation/exchange exclusion.
  The mock-only test did not prove that prerequisite. AppModel and the new mock
  overlap test are restored/excluded. The rejected immutable snapshot and its
  green test results retain their own scope and are not Source-GO.

## CI execution

The existing `CI` job/check and governance boundaries remain. Tool/dependency
updates precede all parallel phases. The same nine contract/localization/brand/
hygiene/register/Golden validators use four workers. The two Swift packages use
two package workers; the main suite uses parallel cases and the VibeCast XCTest
package also bounds process workers. Unsigned macOS and iOS builds use separate
DerivedData paths and four compiler jobs each, with two platform workers.
The existing public-unsigned-release and TestFlight Swift test gates also use
`--parallel`; their signing/publication/authorization order is unchanged and
neither release workflow is run by this qualification.

Each child retains its original log and actual exit; all children are joined
and any failure fails the phase. Cancellation stops only owned process groups;
not-started cancelled work cannot pass. Native coverage follows successful main
CI in a separate build/result directory. The pre-existing optional Postman
condition is unchanged: both referenced files are absent here, so that check is
not claimed as PASS.

## App-flow concurrency audit

| Flow | Execution decision |
| --- | --- |
| Discovery feed and feedback metadata | Original ordered method restored; real shared WebSocket handshake/result-reader correctness is a separate open prerequisite. |
| Playback devices, queue and playlists collection refresh | Existing three independent reads already use `async let`; preserve result and owner checks. |
| Now Playing manual refresh and discovery regeneration | Existing shared in-flight tasks coalesce repeated UI requests; preserve their context and completion checks. |
| Queue selection and output transfer | Preserve preceding-read/write/confirmed-observation order; an older queued read is not fresh selection authority. |
| Music DNA enable/clear/import and dependent recommendations | Preserve accepted mutation before the dependent read/regeneration; no local intelligence or duplicate writes. |
| Ask DJ/history and archive search | Preserve conversation/receipt ordering and cursor dependencies; independent per-session work retains its existing task ownership. |
| Horizon and Track Insight | Preserve exact subject/owner/revision/capability admission before projection; do not parallelize away those dependencies. |
| Settings, persona/mood/presence and speech | Preserve shared-setting acknowledgement, once semantics, response ownership and one current output. |
| VibeCast App Attest/enrollment/repair | Preserve installation/key exclusion, retained original operations and receipt order; no provider/device action. |
| Widget/Live Activity | Preserve separate role ownership and missing production permission/clock/artwork dependencies; no new positive factory or status-only alternative. |
| Watch companion | Preserve original source/settings double-read fences and independent request cancellation. |
| CI | Independent validators, packages and platform builds run in bounded parallel phases; dependency mutation and post-merge coverage stay ordered. |

This audit does not claim every possible future parallel optimization or physical
performance acceptance. Dependency-bound work is deliberately left ordered.

## Validation scope

Original evidence remains outside the repository under
`/Volumes/Shared Data/tmp/pcvantol/apple-parallel-test-isolation-20261031`.
All failed/interrupted attempts are retained with their own logs/exits; no pass
is retroactively assigned to them. On macOS27.2/Xcode27.2(27B52), r7 completed
1,415 tests/36 suites in31.513s with exit0, and CI-local-r1 completed the same
suite in28.581s while the separate VibeCast package also passed. Both r1 unsigned
platform builds passed (individual observed command durations54.43s/79.43s).
Those runs precede the new Discovery delta and constructor-pool regression;
they do not qualify those later bytes. The latter targeted run r8 passed four
functions, including3Discovery cases and16resource cases, in0.151s.

Independent review of frozen snapshot r1 found the real-adapter prerequisite,
so its 1,417-test green result does not approve that prototype. The current
bounded increment excludes the Discovery delta and keeps the CI/resource fixes.
The extra SDK27.2 simulator build returned0 with stale CoreSimulator support
and an empty compiler diagnostic; it is not counted as a clean simulator PASS.
Xcode first-launch/component readiness is tracked separately from source tests.

Final current-tree full/CI/native results and exact hashes belong to the frozen
source review packet and later original protected receipts. No speedup guarantee,
physical p95/FPS/energy result or installed/provider acceptance follows from
these local runs. Exact commit review, ordinary independent GitHub review,
complete CI and separate Finalization remain required.

## Foreground settings lifecycle correction

The bounded r9 full run (1,416 tests, exit1) exposed a production race: an
old settings GET retained the AppModel Boolean after suspension, so a new
foreground could skip both binding and its current read. The wrapper now owns
a request UUID scoped to the bound paired owner/context. Background, owner and
pairing transitions invalidate that slot; an old defer cannot release a newer
request. Read completion is checked before reducer publication and before UI,
speech or surface follow-up. Completion validation never binds/reactivates an
owner. A current authority denial reconciles surface retirement and returns.

Held URLProtocol requests causally exercise both completion orders, old success
and error, duplicate current reads, paired-owner ABA, and an actual401 denial.
The first withdrawal test correctly failed because surface selection had not
been reconciled (r12 retained); r13 passes all23 native custody functions; the four new functions
exercise six cases (two parameterized functions). This is local client-wire proof, not HA/provider
or physical native acceptance. Xcode first-launch was interrupted after its
own stack remained in administrative authorization; simulator readiness stays
open, independent of these source qualifications.

### Current bounded qualification

After the lifecycle correction, r14 completes1,420tests/36suites in28.830s,
actualexit0 with unchanged source hashes. CI-bounded-r3 runs all nine checks
successfully and both unsigned platform builds concurrently: macOS51.95s and
iOS75.76s, each actualexit0 with unchanged input hashes. This supersedes the
rejected combined candidate only for these current bytes; the VibeCast-only
package's28tests retain their earlier independent unchanged-source scope.
No distribution, installation or clean simulator acceptance is claimed.
